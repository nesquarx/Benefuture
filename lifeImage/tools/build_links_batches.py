"""Write the coarse pack and the three links batch files for the seed cards (no model is run).

Usage (from the repository root): python3 lifeImage/tools/build_links_batches.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.cache import AnswerCache  # noqa: E402
from lifeimage.links import build_links_batches, write_links_batches  # noqa: E402
from lifeimage.packs import write_pack  # noqa: E402

MODEL = "haiku-subagent-low"

if __name__ == "__main__":
    cards = [json.loads(l) for l in (ROOT / "data/coarse/seed_v0.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    print(write_pack(cards, ROOT / "data/packs"))
    for p in write_links_batches(build_links_batches(cards, cache=AnswerCache(), model=MODEL), ROOT / "data/batches"):
        print(p, len(p.read_text(encoding="utf-8").splitlines()) - 1, "tasks")
