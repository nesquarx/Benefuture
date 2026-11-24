"""Compare the share of extreme (±2) axes scores between prompt versions.

Usage (from the repository root):
    python3 lifeImage/tools/axes_compare.py [--v1 FILES...] [--v2 FILES...]
Defaults: data/batches/axes.v1.var*.answers.jsonl against data/batches/axes.v2.var*.answers.jsonl (v2 answers appear
once the batches are run). Prints, for each version, the share of scores at a pole overall, per axis and the share
of items extreme on both axes, and the drop from v1 to v2.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.axes import extreme_share  # noqa: E402


def read(paths):
    return [json.loads(l) for p in paths for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]


def compare(v1_paths, v2_paths):
    a, b = extreme_share(read(v1_paths)), extreme_share(read(v2_paths))
    return {"v1": a, "v2": b, "drop": a["share"] - b["share"]}


def report(s):
    rows = [f"{k}: {s[k]['items']} items, extreme scores {s[k]['share']:.1%} (axis 1 {s[k]['axis1']:.1%}, axis 2 "
            f"{s[k]['axis2']:.1%}), both axes extreme {s[k]['both_extreme_items']:.1%}" for k in ("v1", "v2")]
    return "\n".join(rows + [f"drop in extreme share, v1 to v2: {s['drop']:+.1%}"])


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--v1", nargs="+", default=sorted((ROOT / "data/batches").glob("axes.v1.var*.answers.jsonl")))
    ap.add_argument("--v2", nargs="+", default=sorted((ROOT / "data/batches").glob("axes.v2.var*.answers.jsonl")))
    a = ap.parse_args()
    if not a.v2:
        sys.exit("no axes.v2 answers yet: run data/batches/axes.v2.var{0,1,2}.jsonl first")
    print(report(compare(a.v1, a.v2)))
