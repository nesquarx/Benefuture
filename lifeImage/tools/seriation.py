"""Run the circular seriation arm (LI.60) and write its products; the default build is untouched. No model is run.

Writes `data/coarse/seriation_v0.json` (order, angles, metrics of arms A shipped, B force simulation, C seriation, sensitivity),
the blinded adjacency batches A (shipped) against C (seriation) in `data/batches/seriation/` (gitignored) and their key in
`data/ephemeral/seriation/` (gitignored, out of the runners' reach). Render the sheet with
`python3 tools/render_coarse_review.py --seriation --png`.

    python3 tools/seriation.py [--no-sweep] [--no-batches]
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lifeimage import seriation as sr  # noqa: E402
from lifeimage.adjacency import build_adjacency_batches, write_adjacency_batches  # noqa: E402
from lifeimage.render import basemap as bm  # noqa: E402

MODEL = "haiku-runner"
SWEEP = (0, 0.25, 4, 1000)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-sweep", action="store_true")
    ap.add_argument("--no-batches", action="store_true")
    args = ap.parse_args()
    res = sr.compute(ROOT, sweep=() if args.no_sweep else SWEEP)
    out = ROOT / "data/coarse/seriation_v0.json"
    sr.write(res, out)
    print(out)
    if not args.no_batches:
        cards = bm.load_cards()
        batches, key = build_adjacency_batches(cards, res["ring_order"]["A"], res["ring_order"]["C"], model=MODEL)
        key["A"], key["B"] = "shipped order (axes placement)", "circular seriation"
        # batches carry no key; the key is written beside neither the batches nor anything the runners read
        paths = write_adjacency_batches(batches, key, ROOT / "data/ephemeral/seriation")
        bdir = ROOT / "data/batches/seriation"
        bdir.mkdir(parents=True, exist_ok=True)
        for p in paths:
            if p.name.endswith(".key.json"):
                print("key:", p)
            else:
                dest = bdir / p.name
                dest.write_text(p.read_text(encoding="utf-8"), encoding="utf-8")
                p.unlink()
                print(dest)
    print(json.dumps({k: {"coherence": a["coherence"], "stability": a["stability"], "named_outliers": a["named_outliers"]}
                      for k, a in res["arms"].items()}, indent=1))


if __name__ == "__main__":
    main()
