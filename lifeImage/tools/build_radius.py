"""Write the radius (LI.26) into the cards: seed_v2 -> seed_v3 (coarse), fine_v0 -> fine_v1 (fine); v2 and v0 stay.

Usage (from the repository root): python3 lifeImage/tools/build_radius.py [--report FILE]
No model is called. Prints the coverage of every proxy, the correlations among the three, and the nodes where they
disagree most. Deterministic.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage import radius as rd  # noqa: E402


def read(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def write(path, cards, sort_keys):
    Path(path).write_text("".join(json.dumps(c, sort_keys=sort_keys, ensure_ascii=False) + "\n" for c in cards),
                          encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", default=None, help="also write the report as JSON")
    args = ap.parse_args(argv)
    coarse = read(ROOT / "data/coarse/seed_v2.jsonl")
    fine = read(ROOT / "data/fine/fine_v0.jsonl")
    rows = read(ROOT / "data/coarse/comembership_v0.jsonl")
    res = rd.compute(coarse, fine, rows)
    for cards, out, sk in ((coarse, "data/coarse/seed_v3.jsonl", False), (fine, "data/fine/fine_v1.jsonl", True)):
        write(ROOT / out, [{**c, "radius": res.radius[c["id"]]} for c in cards], sk)
    rep = res.report
    print(f"nodes {rep['nodes']}; confidence {rep['confidence']}")
    print("axis coverage", {k: round(v, 3) for k, v in rep["coverage"].items()})
    print("by level", {k: {a: round(x, 3) for a, x in v.items()} for k, v in rep["coverage_by_level"].items()})
    print("component coverage", {k: round(v, 3) for k, v in rep["component_coverage"].items()})
    print("difficulty source", rep["difficulty_source"])
    for (a, b), (rho, n) in rep["correlations"].items():
        print(f"spearman {a}~{b}: {rho if rho is None else round(rho, 3)} (n={n})")
    print("negative pairs", rep["negative_pairs"] or "none")
    for d in rep["disagreement"][:12]:
        print(f"  {d['spread']:.2f} {d['id']} {d['label']!r} {d['proxies']}")
    if args.report:
        Path(args.report).write_text(json.dumps({**rep, "correlations": {f"{a}~{b}": v for (a, b), v in rep["correlations"].items()}},
                                                indent=1, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
