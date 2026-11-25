"""Relatedness judging (LI.55): build the batches, or ingest and report answers. No model is run here.

    python3 tools/relatedness.py build [--cap N]     select pairs, write data/batches/relatedness.v1.* and the tracked pair list
    python3 tools/relatedness.py ingest              validate the runners' answers beside the batches, write data/answers/relatedness.jsonl,
                                                     print the calibration (predicted gap 3 points) and the order bias

Prediction (stated before the first run): controls with existing signal score at least 3 points above random far-apart pairs
on average; confidence 0.8. The answers feed `layout_sim` as the optional 'judged' source once `data/answers/relatedness.jsonl` exists.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lifeimage import layout_sim as ls  # noqa: E402
from lifeimage import relatedness as rel  # noqa: E402
from lifeimage.fine.cards import load_fine  # noqa: E402
from lifeimage.render import basemap as bm  # noqa: E402
from lifeimage.validate import validate_answers  # noqa: E402

MODEL = "haiku-runner"
BATCHES = ROOT / "data/batches"
PAIRS = ROOT / "data/coarse/relatedness_pairs_v1.json"
ANSWERS = ROOT / "data/answers/relatedness.jsonl"


def build(cap):
    cards = bm.load_cards(ROOT / "data/coarse/seed_v3.jsonl")
    fine = load_fine(ROOT / "data/fine/fine_v1.jsonl")
    comem = bm.read_jsonl(ROOT / "data/coarse/comembership_v0.jsonl")
    order = json.loads((ROOT / "data/coarse/layout_sim_v0.json").read_text())["ring_order"]
    sig = ls.signals(cards, fine, comem, ls.Params(weights={**ls.Params().resolved().weights, "judged": 0.0}))
    sel = rel.select_pairs(sig.ids, sig.combined, order["before"], order["after"], cap=cap)
    batches, key = rel.build_relatedness_batches(cards, fine, sel["kind"], model=MODEL)
    paths = rel.write_relatedness_batches(batches, key, BATCHES)
    PAIRS.write_text(json.dumps({"cap": cap, "counts": sel["counts"], "available": sel["available"],
                                 "kind": {f"{a}|{b}": k for (a, b), k in sel["kind"].items()}}, sort_keys=True, indent=1) + "\n", encoding="utf-8")
    print(json.dumps({"counts": sel["counts"], "available": sel["available"], "cap": cap, "batch_files": len(paths) - 1}, indent=1))
    print(paths[0], "...", paths[-2], paths[-1], PAIRS)


def ingest():
    key = json.loads((BATCHES / f"relatedness.v{rel.PROMPT_VERSION}.key.json").read_text())
    rows, errors = [], []
    for bp in sorted(BATCHES.glob(f"relatedness.v{rel.PROMPT_VERSION}.var*.part*.jsonl")):
        ap = bp.with_suffix(".answers.jsonl")
        if not ap.exists():
            continue
        e = validate_answers(bp.read_text().splitlines(), ap.read_text().splitlines())
        errors += [f"{ap.name}: {x}" for x in e]
        if not e:
            rows += rel.answer_rows([json.loads(l) for l in ap.read_text().splitlines()], key)
    if errors:
        print("\n".join(errors[:20]))
    ANSWERS.parent.mkdir(parents=True, exist_ok=True)
    ANSWERS.write_text("".join(json.dumps(r, sort_keys=True) + "\n" for r in rows), encoding="utf-8")
    kind = {tuple(k.split("|")): v for k, v in json.loads(PAIRS.read_text())["kind"].items()}
    print(json.dumps({"rows": len(rows), "calibration": rel.calibration(rows, kind), "order_bias": rel.order_bias(rows)}, indent=1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["build", "ingest"])
    ap.add_argument("--cap", type=int, default=rel.CAP)
    args = ap.parse_args()
    build(args.cap) if args.cmd == "build" else ingest()


if __name__ == "__main__":
    main()
