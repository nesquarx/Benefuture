"""Write battery v2 (layer A) into data/batches (gitignored; no model is run).

- membership.A3.v2.var{0,1,2}.jsonl and membership.A3S.v2.var{0,1,2}.jsonl over the 192 items plus the
  minimal-pair texts (deduplicated);
- membership.A3.v2.sonnet.jsonl: a 50-item stratified subset of A3 v2 for a stronger model ("sonnet-subagent", k=1);
- roundtrip.<A4|ACP>.v1.var0.jsonl (+ .key.jsonl) from the cached v1 answers (k=1).
Round-trip over v2 answers once they exist: python3 lifeImage/tools/build_battery_v2.py --roundtrip-v2

Usage (from the repository root): python3 lifeImage/tools/build_battery_v2.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.cache import AnswerCache  # noqa: E402
from lifeimage.membership import (DEFAULT_GOLD, DEFAULT_OUT, DEFAULT_PACK, build_membership_batches, load_items,  # noqa: E402
                                  load_items_v2, load_pairs, stratified_subset, write_batch_file,
                                  write_membership_batches)
from lifeimage.roundtrip import build_roundtrip_batch, merged_annotations, write_roundtrip  # noqa: E402

SONNET = "sonnet-subagent"


def report(p):
    n = len(p.read_text(encoding="utf-8").splitlines()) - 1
    print(p.name, n, "tasks", f"~{len(p.read_bytes()) // 4} tokens")


if __name__ == "__main__":
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    items = load_items_v2(DEFAULT_GOLD)
    for vocab in ("A3", "A3S"):
        for p in write_membership_batches(vocab, build_membership_batches(vocab, items, pack, prompt_version=2),
                                          DEFAULT_OUT, prompt_version=2):
            report(p)
    sub = stratified_subset(items, load_pairs(DEFAULT_GOLD))
    b = build_membership_batches("A3", sub, pack, prompt_version=2, model=SONNET, k=1)
    report(write_batch_file(DEFAULT_OUT / "membership.A3.v2.sonnet.jsonl", b[0]))
    texts = {i["id"]: i["text"] for i in load_items(DEFAULT_GOLD)}
    cache = AnswerCache()
    versions = [("A4", "haiku-subagent-low", 1), ("ACP", "haiku-subagent-low", 1)]
    if "--roundtrip-v2" in sys.argv:
        texts = {i["id"]: i["text"] for i in items}
        versions = [("A3", "haiku-subagent-low", 2), ("A3S", "haiku-subagent-low", 2)]
    for vocab, model, pv in versions:
        anns = merged_annotations(vocab, load_items(DEFAULT_GOLD) if pv == 1 else items, pack, cache, model=model,
                                  prompt_version=pv)
        lines, keys = build_roundtrip_batch(vocab, anns, texts, model=model)
        batch, key = write_roundtrip(vocab, lines, keys, DEFAULT_OUT)
        report(batch)
        print(key.name, len(keys), "keys")
