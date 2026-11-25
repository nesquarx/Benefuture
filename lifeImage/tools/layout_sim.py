"""Run the layout simulation (LI.55, LI.58) on the coarse map and write its products; the default build is untouched.

Writes `data/coarse/layout_sim_v0.json` (angles, order, coverage, metrics, named outliers, movers), the before/after list of
the biggest movers `data/images/review/coarse_layout_sim_movers.md`, and (unless --no-batches) the blinded adjacency batches
`data/batches/adjacency.v1.*` with their key. No model is run. Render the sheet with
`python3 tools/render_coarse_review.py --layout-sim --png`.

    python3 tools/layout_sim.py [--k-polar X] [--no-holdout] [--no-batches] [--out PATH]
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lifeimage import layout_sim as ls  # noqa: E402
from lifeimage.adjacency import build_adjacency_batches, write_adjacency_batches  # noqa: E402
from lifeimage.render import basemap as bm  # noqa: E402

MODEL = "haiku-runner"


def movers_md(res):
    lines = ["# Coarse layout: biggest movers (axes placement to simulation)", "",
             f"{res['version']}; angle shift of the simulation's state from the axes angle, neighbours are the two beside it in the ring.", "",
             "| field | axes angle | sim angle | shift | neighbours before | neighbours after |", "|---|---|---|---|---|---|"]
    for m in res["movers"]:
        lines.append(f"| {m['label']} | {m['axes_angle']} | {m['angle']} | {m['shift']} | {' / '.join(m['before'])} | {' / '.join(m['after'])} |")
    lines += ["", "## Named outliers", "", "| field | similarity to neighbours before | after | neighbours before | neighbours after |", "|---|---|---|---|---|"]
    for i, d in sorted(res["named"].items(), key=lambda kv: (kv[1]["group"], kv[0])):
        near = lambda s: " / ".join(x["label"] for x in d[s][1:3])
        lines.append(f"| {d['label']} ({d['group']}) | {d['before_similarity']:.3f} | {d['after_similarity']:.3f} | {near('before')} | {near('after')} |")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--k-polar", type=float)
    ap.add_argument("--no-holdout", action="store_true")
    ap.add_argument("--no-batches", action="store_true")
    ap.add_argument("--out", default=str(ROOT / "data/coarse/layout_sim_v0.json"))
    args = ap.parse_args()
    params = ls.Params(k_polar=args.k_polar)
    res = ls.compute(ROOT, params, holdout=not args.no_holdout)
    Path(args.out).write_text(json.dumps(res, sort_keys=True, indent=1) + "\n", encoding="utf-8")
    print(args.out)
    if args.out.endswith("layout_sim_v0.json"):
        d = ROOT / "data/images/review"
        d.mkdir(parents=True, exist_ok=True)
        (d / "coarse_layout_sim_movers.md").write_text(movers_md(res), encoding="utf-8")
        if not args.no_batches:
            cards = bm.load_cards()
            batches, key = build_adjacency_batches(cards, res["ring_order"]["before"], res["ring_order"]["after"], model=MODEL)
            for p in write_adjacency_batches(batches, key, ROOT / "data/batches"):
                print(p)
    m = res["metrics"]
    print(json.dumps({"coverage": res["coverage"], "any": res["coverage_any"], "coherence": m["coherence"],
                      "stability": m["stability"], "holdout": m["holdout"]}, indent=1))


if __name__ == "__main__":
    main()
