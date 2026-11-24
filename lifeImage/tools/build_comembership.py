"""Write data/coarse/comembership_v0.jsonl from the cached membership and confirm answers (no model is run).

Usage (from the repository root): python3 lifeImage/tools/build_comembership.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.comembership import (comembership, fields_with_links, load_answers, merge_items,  # noqa: E402
                                    specialisation_view, write_rows)

MIN_STORED_SUPPORT = 2

if __name__ == "__main__":
    answers = load_answers(ROOT / "data/answers")
    items = merge_items(answers)
    rows = comembership(items)
    kept = [r for r in rows if r["support"] >= MIN_STORED_SUPPORT]  # support-1 rows are noise and 80% of the bytes
    write_rows(kept, ROOT / "data/coarse/comembership_v0.jsonl")
    seed = [json.loads(l) for l in (ROOT / "data/coarse/seed_v0.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    fields = [c["id"] for c in seed if not c["id"].startswith("s.")]
    print(f"answers {len(answers)}, items {len(items)}, rows {len(rows)}, stored (support >= {MIN_STORED_SUPPORT}) {len(kept)}")
    for s in (1, 3, 5):
        print(f"seed fields with a data-learnt link of support >= {s}: {len(fields_with_links(rows, fields, s))} of {len(fields)}")
    for s in specialisation_view(rows, 3)[:8]:
        print("specialises:", s["a"], "->", s["b"], s["type"], round(s["asymmetry"], 2), s["support"])
