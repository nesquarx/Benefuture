"""Write the axes v3 batches for the seed cards (no model is run); batches are gitignored.

Usage (from the repository root): python3 lifeImage/tools/build_v3_batches.py
Files: data/batches/axes.v3.<at|pg>.var{0,1,2}.part{n}.jsonl, at most 60 tasks each (one card per task, a different card
order per variant), verdicts the strings "0".."10". Run each file on a runner agent, one runner per file, then compare
with tools/axes_compare.py.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.axes_v3 import build_v3_batches, write_v3_batches  # noqa: E402

MODEL = "haiku-runner"

if __name__ == "__main__":
    cards = [json.loads(l) for l in (ROOT / "data/coarse/seed_v0.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    for p in write_v3_batches(build_v3_batches(cards, model=MODEL), ROOT / "data/batches"):
        n = len(p.read_text(encoding="utf-8").splitlines()) - 1
        print(f"{p.name}: {n} tasks, file ~{-(-p.stat().st_size // 4)} tokens")
