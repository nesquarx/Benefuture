"""Write the confirming battery into data/batches (gitignored; no model is run).

Step 1 (no answers needed): confirm.v1.var{0,1,2}.jsonl over `data/gold/confirm_items_v0.jsonl`, one combined task per
item (A, B and D); a variant over ~40k tokens is split into confirm.v1.var<i>.p<j>.jsonl parts.
Rerun (confirm v2): `--rerun` writes confirm.v2.var{0,1,2}.jsonl over only the items of `data/gold/review_v1.md` (the
disputed items and the round-trip misses, deduplicated) plus the four self-defence items, with `prompts/confirm.v2.md`.
Step 2 (after the confirm answers exist): round-trip v3 from them:
  python3 lifeImage/tools/build_battery_confirm.py --from-answers lifeImage/data/batches/confirm.v1.var*.answers.jsonl
writes roundtrip.v3.var0.jsonl + roundtrip.v3.key.jsonl and the text-only control roundtrip.v3.control.var0.jsonl +
roundtrip.v3.control.key.jsonl (parts when over 40k tokens). The decoy pool is the annotated confirm items plus the
other items of the 273 set annotated in the cached A3S v2 answers (the earlier prompt's annotation, used only to rank
decoys); `--pool-only` restricts it to the confirm items. Keys flag every task whose wording could not be equalised.
Score: python3 lifeImage/tools/roundtrip_score.py --v3 --key ...key.jsonl --answers ... --control-key ... --control-answers ...
Metrics: python3 lifeImage/tools/confirm_metrics.py lifeImage/data/batches/confirm.v1.var*.answers.jsonl
Compare: add `--vs lifeImage/data/batches/confirm.v2.var*.answers.jsonl` (see confirm_metrics.py).
"""
import argparse
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.cache import AnswerCache  # noqa: E402
from lifeimage.confirm import DEFAULT_ITEMS, build_confirm_batches, load_confirm_items, write_confirm_batches  # noqa: E402
from lifeimage.confirm_rerun import rerun_items  # noqa: E402
from lifeimage.confirm_roundtrip import roundtrip_from_answers, write_roundtrip_v3  # noqa: E402
from lifeimage.membership import DEFAULT_OUT, DEFAULT_PACK, load_items_v2  # noqa: E402
from lifeimage.roundtrip import merged_annotations  # noqa: E402


def report(p):
    n = len(p.read_text(encoding="utf-8").splitlines()) - 1
    print(p.name, n, "tasks", f"~{len(p.read_bytes()) // 4} tokens")


def cached_pool(pack):
    """(annotations, texts) of the 273-item pool from the cached A3S v2 answers."""
    items = load_items_v2()
    return (merged_annotations("A3S", items, pack, AnswerCache(), model="haiku-subagent-low", prompt_version=2),
            {i["id"]: i["text"] for i in items})


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--from-answers", nargs="*", default=None, help="confirm answers files (step 2)")
    ap.add_argument("--rerun", action="store_true", help="confirm v2 batches over the review items and the self-defence items")
    ap.add_argument("--pool-only", action="store_true", help="decoys from the confirm items only")
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    a = ap.parse_args()
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    items = load_confirm_items(DEFAULT_ITEMS)
    if a.rerun:
        rerun = rerun_items(items)
        print(len(rerun), "items", dict(Counter(i["source"] for i in rerun)))
        for p in write_confirm_batches(build_confirm_batches(rerun, pack, prompt_version=2), a.out, prompt_version=2):
            report(p)
    elif a.from_answers is None:
        print(len(items), "items", dict(Counter(i["source"] for i in items)))
        for p in write_confirm_batches(build_confirm_batches(items, pack), a.out):
            report(p)
    else:
        lines, keys, clines, ckeys = roundtrip_from_answers(a.from_answers, items, pack,
                                                            extra_pool=None if a.pool_only else cached_pool(pack))
        for p in write_roundtrip_v3(lines, keys, clines, ckeys, a.out):
            report(p)
        sims = sorted(k["nearest_decoy_similarity"] for k in keys)
        print(f"{len(keys)} tasks; nearest-decoy similarity min {sims[0]:.2f} median {sims[len(sims) // 2]:.2f} "
              f"max {sims[-1]:.2f}; wording not equalised {sum(not k['equalised'] for k in keys)}; "
              f"true text still the plainest {sum(k['true_plainest'] for k in keys)}")
