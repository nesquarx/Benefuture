"""Write the links.v2 and axes.v2 batch files for the seed cards (no model is run); batches are gitignored.

Usage (from the repository root): python3 lifeImage/tools/build_v2_batches.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.axes import build_axes_batches, write_axes_batches  # noqa: E402
from lifeimage.links import build_links_batches, write_links_batches  # noqa: E402

MODEL = "haiku-runner"

if __name__ == "__main__":
    cards = [json.loads(l) for l in (ROOT / "data/coarse/seed_v0.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    paths = write_links_batches(build_links_batches(cards, model=MODEL, prompt_version=2, ungrouped=True), ROOT / "data/batches", 2)
    paths += write_axes_batches(build_axes_batches(cards, model=MODEL, prompt_version=2), ROOT / "data/batches", 2)
    for p in paths:
        lines = p.read_text(encoding="utf-8").splitlines()
        prefix = len(json.loads(lines[0])["prefix"])
        print(f"{p.name}: {len(lines) - 1} tasks, prefix ~{-(-prefix // 4)} tokens, file ~{-(-p.stat().st_size // 4)} tokens")
