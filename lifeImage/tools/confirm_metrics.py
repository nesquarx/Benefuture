"""Metrics of the confirming battery (layers A, B, D on the combined answers, production on the consumed-versus-
produced pairs, outcome against the counterfactual): a markdown report on stdout.

Usage: python3 lifeImage/tools/confirm_metrics.py data/batches/confirm.v1.var*.answers.jsonl
Compare v1 with v2 on the rerun set (the review items plus the self-defence items):
  python3 lifeImage/tools/confirm_metrics.py data/batches/confirm.v1.var*.answers.jsonl --vs data/batches/confirm.v2.var*.answers.jsonl
prints agreement per field, zero-run flags, production nulls and responsibility on coercion and self-defence items for
both versions on the same items (only items both answered, self-defence rows aside).
Each answers file is read with its batch file beside it (same name without `.answers`; parts as
confirm.v1.var<i>.p<j>). Items and expectations come from data/gold/confirm_items_v0.jsonl, minimal pairs from
data/gold/minimal_pairs_v0.jsonl.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lifeimage.confirm import load_confirm_items, load_confirm_records  # noqa: E402
from lifeimage.confirm_metrics import compare_versions, compute_confirm, render_compare, render_confirm  # noqa: E402
from lifeimage.confirm_rerun import rerun_items  # noqa: E402
from lifeimage.membership import load_pairs  # noqa: E402

def main(args):
    if "--vs" in args:
        k = args.index("--vs")
        v1, v2 = args[:k], args[k + 1:]
        if not v1 or not v2:
            sys.exit(__doc__)
        items = rerun_items()
        sys.stdout.write(render_compare(compare_versions(load_confirm_records(v1), load_confirm_records(v2), items,
                                                         [i["id"] for i in items])))
    elif args:
        sys.stdout.write(render_confirm(compute_confirm(load_confirm_records(args), load_confirm_items(), load_pairs())))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
