"""Metrics of the membership battery: a markdown report on stdout.

Usage: python3 lifeImage/tools/membership_metrics.py [--pairs] data/batches/membership.*.answers.jsonl
Each answers file is read with its batch file beside it (same name without `.answers`). With --pairs the
minimal-pair collision rates are added (the answers must cover the pair texts, as the v2 batches do).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lifeimage.membership import load_items_v2, load_pairs  # noqa: E402
from lifeimage.membership_metrics import compute, load_records, render  # noqa: E402

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--pairs"]
    if not args:
        sys.exit(__doc__)
    extra = {"pairs": load_pairs(), "items": load_items_v2()} if "--pairs" in sys.argv else {}
    sys.stdout.write(render(compute(load_records(args), **extra)))
