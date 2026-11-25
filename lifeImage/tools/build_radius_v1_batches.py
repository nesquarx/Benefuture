"""Write the radius v1 batches for the coarse fields (no model is run); batches are gitignored.

Usage (from the repository root): python3 lifeImage/tools/build_radius_v1_batches.py
Files: data/batches/radius.v1.var{0,1}.part{n}.jsonl, at most 50 tasks each, verdicts "0".."10". Run each file on a
runner agent, one runner per file, then compare with tools/radius_compare.py.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.radius_judged import build_batches, write_batches  # noqa: E402

MODEL = "haiku-runner"

if __name__ == "__main__":
    cards = [json.loads(l) for l in (ROOT / "data/coarse/seed_v3.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    for p in write_batches(build_batches(cards, model=MODEL), ROOT / "data/batches"):
        n = len(p.read_text(encoding="utf-8").splitlines()) - 1
        print(f"{p.name}: {n} tasks, file ~{-(-p.stat().st_size // 4)} tokens")
