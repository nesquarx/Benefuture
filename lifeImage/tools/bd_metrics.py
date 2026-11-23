"""Metrics of battery BD (layers B and D): a markdown report on stdout.

Usage: python3 lifeImage/tools/bd_metrics.py data/batches/participation.v1.var*.answers.jsonl \
           data/batches/events.v1.var*.answers.jsonl
Each answers file is read with its batch file beside it (same name without `.answers`). Items and minimal pairs
come from data/gold.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lifeimage.bd_metrics import compute, load_bd_records, render  # noqa: E402
from lifeimage.membership import load_pairs  # noqa: E402
from lifeimage.participation import load_bd_items  # noqa: E402

if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    sys.stdout.write(render(compute(load_bd_records(args), load_bd_items(), load_pairs())))
