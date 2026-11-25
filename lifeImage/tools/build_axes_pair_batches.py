"""Write the axes_pair v1 batch parts for both axes from seed_v0 and the cached axes v1/v2 answers (no model is run).

Usage (from the repository root):
  python3 lifeImage/tools/build_axes_pair_batches.py
  python3 lifeImage/tools/build_axes_pair_batches.py --axis abstract_tangible --comparisons 4 --single-order
Batches are gitignored: data/batches/axes_pair.<axis>.v1.part{n}.jsonl, at most 35k tokens each. With --single-order each
pair is asked once, the field shown first balanced per field, and the parts are named axes_pair.<axis>.pilot.part{n}.jsonl;
--comparisons sets the pairs each field initiates (6 by default, 4 for the pilot); --axis limits the build to one axis.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.axes_pair import AXES, axis_means, build_pair_batches, choose_anchors, write_pair_batches  # noqa: E402

MODEL = "haiku-runner"


def read(paths):
    return [json.loads(l) for p in paths for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--axis", choices=AXES, default=None)
    ap.add_argument("--comparisons", type=int, default=None)
    ap.add_argument("--single-order", action="store_true")
    a = ap.parse_args()
    batches = ROOT / "data/batches"
    cards = read([ROOT / "data/coarse/seed_v0.jsonl"])
    answers = [read(sorted(batches.glob(f"axes.v{v}.var*.answers.jsonl"))) for v in (1, 2)]
    means = axis_means(cards, answers)
    for axis in [a.axis] if a.axis else AXES:
        parts = build_pair_batches(cards, means[axis], axis, model=MODEL, comparisons=a.comparisons, single_order=a.single_order)
        print(f"{axis}: anchors {choose_anchors(means[axis])}")
        for p in write_pair_batches(parts, batches, axis, tag="pilot" if a.single_order else None):
            lines = p.read_text(encoding="utf-8").splitlines()
            print(f"{p.name}: {len(lines) - 1} tasks, file ~{-(-p.stat().st_size // 4)} tokens")
