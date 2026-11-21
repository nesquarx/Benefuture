"""Graded round-trip v2 batches (no model is run). Writes into data/batches (gitignored):

- roundtrip.A3S.v2.L{1..4}.jsonl + .key.jsonl, decoys from the annotated 273-item pool (merged v2 A3S answers);
  per-item backfill counts are printed per level (a level too few items qualify for is filled from the easier one,
  marked in the key's `decoy_levels`);
- membership.A3S.v2.l5.var{0,1,2}.jsonl: the L5 true and decoy texts, to be annotated first (step 1);
- roundtrip.A3S.v2.L5.jsonl + .key.jsonl once their answers exist (step 2, `--l5-answers`).

Usage (from the repository root):
  python3 lifeImage/tools/build_roundtrip_graded.py                      # step 1: L1-L4 and the L5 annotation batches
  python3 lifeImage/tools/build_roundtrip_graded.py --l5-answers lifeImage/data/batches/membership.A3S.v2.l5.var*.answers.jsonl
Score: python3 lifeImage/tools/roundtrip_score.py --graded lifeImage/data/batches/roundtrip.A3S.v2.L*.key.jsonl
"""
import argparse
import json
from collections import Counter
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.cache import AnswerCache  # noqa: E402
from lifeimage.membership import (DEFAULT_GOLD, DEFAULT_OUT, DEFAULT_PACK, build_membership_batches,  # noqa: E402
                                  load_items_v2, write_batch_file)
from lifeimage.roundtrip import merged_annotations  # noqa: E402
from lifeimage.roundtrip_graded import (MODEL, build_graded_batch, build_l5_batch, l5_annotations, l5_items,  # noqa: E402
                                        load_l5)

VOCAB = "A3S"


def write_pair(out, level, lines, keys):
    base = Path(out) / f"roundtrip.{VOCAB}.v2.L{level}"
    batch = write_batch_file(Path(f"{base}.jsonl"), lines)
    key = write_batch_file(Path(f"{base}.key.jsonl"), [json.dumps(k, sort_keys=True) for k in keys])
    return batch, key


def build(out=DEFAULT_OUT, l5_answers=(), gold=DEFAULT_GOLD, say=print):
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    items = load_items_v2(gold)
    texts = {i["id"]: i["text"] for i in items}
    anns = merged_annotations(VOCAB, items, pack, AnswerCache(), model=MODEL, prompt_version=2)
    report = []
    for level in (1, 2, 3, 4):
        lines, keys = build_graded_batch(VOCAB, level, anns, texts)
        write_pair(out, level, lines, keys)
        back = [k for k in keys if k["backfilled"]]
        full = len(keys) - len(back)
        src = Counter(v for k in keys for v in k["decoy_levels"].values())
        say(f"L{level}: {len(keys)} tasks of {len(anns)} items; {full} fully at level, {len(back)} backfilled; "
            f"decoys by source level {dict(sorted(src.items()))}")
        for k in back:
            report.append({"level": level, "item": k["item"], "backfilled": k["backfilled"],
                           "from": dict(sorted(Counter(v for v in k["decoy_levels"].values() if v < level).items()))})
    write_batch_file(Path(out) / f"roundtrip.{VOCAB}.v2.fill_report.jsonl", [json.dumps(r, sort_keys=True) for r in report])
    say(f"per-item backfill report: roundtrip.{VOCAB}.v2.fill_report.jsonl ({len(report)} backfilled item-levels)")
    rows = load_l5(gold)
    for v, lines in sorted(build_membership_batches(VOCAB, l5_items(rows), pack, prompt_version=2).items()):
        p = write_batch_file(Path(out) / f"membership.{VOCAB}.v2.l5.var{v}.jsonl", lines)
        say(f"{p.name}: {len(lines) - 1} tasks")
    if l5_answers:
        answers = [json.loads(l) for p in l5_answers for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]
        l5a = l5_annotations(VOCAB, l5_items(rows), pack, answers)
        lines, keys = build_l5_batch(VOCAB, rows, l5a)
        write_pair(out, 5, lines, keys)
        ident = sum(v for k in keys for v in k["a_identical"].values())
        say(f"L5: {len(keys)} tasks; {ident} of {4 * len(keys)} decoys have an A annotation identical to the true one")
    else:
        say("L5: not built (annotate the l5 membership batches, then rerun with --l5-answers)")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--l5-answers", nargs="*", default=[], help="answers files of the l5 membership batches")
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    a = ap.parse_args()
    build(a.out, a.l5_answers)
