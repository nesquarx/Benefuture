"""Write the axes_pair v1 batch parts for both axes from seed_v0 and the cached axes v1/v2 answers (no model is run).

Usage (from the repository root): python3 lifeImage/tools/build_axes_pair_batches.py
Batches are gitignored: data/batches/axes_pair.<axis>.v1.part{n}.jsonl, at most 35k tokens each.
"""
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
    batches = ROOT / "data/batches"
    cards = read([ROOT / "data/coarse/seed_v0.jsonl"])
    answers = [read(sorted(batches.glob(f"axes.v{v}.var*.answers.jsonl"))) for v in (1, 2)]
    means = axis_means(cards, answers)
    for axis in AXES:
        parts = build_pair_batches(cards, means[axis], axis, model=MODEL)
        print(f"{axis}: anchors {choose_anchors(means[axis])}")
        for p in write_pair_batches(parts, batches, axis):
            lines = p.read_text(encoding="utf-8").splitlines()
            print(f"{p.name}: {len(lines) - 1} tasks, file ~{-(-p.stat().st_size // 4)} tokens")
