"""Metrics of the confirming battery (layers A, B, D on the combined answers, production on the consumed-versus-
produced pairs, outcome against the counterfactual): a markdown report on stdout.

Usage: python3 lifeImage/tools/confirm_metrics.py data/batches/confirm.v1.var*.answers.jsonl
Each answers file is read with its batch file beside it (same name without `.answers`; parts as
confirm.v1.var<i>.p<j>). Items and expectations come from data/gold/confirm_items_v0.jsonl, minimal pairs from
data/gold/minimal_pairs_v0.jsonl.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lifeimage.confirm import load_confirm_items, load_confirm_records  # noqa: E402
from lifeimage.confirm_metrics import compute_confirm, render_confirm  # noqa: E402
from lifeimage.membership import load_pairs  # noqa: E402

if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    sys.stdout.write(render_confirm(compute_confirm(load_confirm_records(args), load_confirm_items(), load_pairs())))
