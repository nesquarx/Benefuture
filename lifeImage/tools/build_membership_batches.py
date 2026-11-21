"""Write the membership battery: 4 vocabularies x 3 variants = 12 batch files in data/batches (no model is run).

Usage (from the repository root): python3 lifeImage/tools/build_membership_batches.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.membership import (DEFAULT_GOLD, DEFAULT_OUT, DEFAULT_PACK, VOCABS, build_membership_batches,  # noqa: E402
                                  load_items, write_membership_batches)

if __name__ == "__main__":
    items = load_items(DEFAULT_GOLD)
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    for vocab in VOCABS:
        for p in write_membership_batches(vocab, build_membership_batches(vocab, items, pack), DEFAULT_OUT):
            size = len(p.read_bytes())
            print(p.name, len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks", f"~{size // 4} tokens")
