"""Metrics of the membership battery: a markdown report on stdout.

Usage: python3 lifeImage/tools/membership_metrics.py data/batches/membership.*.answers.jsonl
Each answers file is read with its batch file beside it (same name without `.answers`).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lifeimage.membership_metrics import compute, load_records, render  # noqa: E402

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.stdout.write(render(compute(load_records(sys.argv[1:]))))
