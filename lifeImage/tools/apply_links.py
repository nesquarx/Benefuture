"""Merge the three links answer files into data/coarse/seed_v1.jsonl and cache the answers.

Usage (from the repository root):
    python3 lifeImage/tools/apply_links.py ANSWERS_VAR0 ANSWERS_VAR1 ANSWERS_VAR2
The answers are validated against the batches rebuilt from the seed cards, so a stale or malformed answers file
fails loudly. Prints agreement statistics and the share of the seed's guessed upstream links retained.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.cache import AnswerCache  # noqa: E402
from lifeimage.canonical import canonical_json, content_hash  # noqa: E402
from lifeimage.links import (agreement_stats, build_links_batches, field_agreement, links_inputs,  # noqa: E402
                             merge_links)
from lifeimage.packs import is_sector  # noqa: E402
from lifeimage.validate import validate_answers, validate_card  # noqa: E402

MODEL = "haiku-subagent-low"
SOURCE = "haiku-subagent-low x3, links.v1"
CONF_FLOOR, CONF_SPAN = 0.2, 0.7  # confidence = floor + span * mean pairwise Jaccard of the upstream sets: in [0.2, 0.9]


def read_jsonl(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def apply(seed_path, answer_paths, out_path, cache, esc_log, model=MODEL, prompt_version=1, ungrouped=False,
          prompts_dir=None, source=SOURCE):
    cards = read_jsonl(seed_path)
    extra = {"prompts_dir": prompts_dir} if prompts_dir is not None else {}
    batches = build_links_batches(cards, model=model, prompt_version=prompt_version, ungrouped=ungrouped, **extra)
    answers = []
    for v, path in enumerate(answer_paths):
        lines = [l for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]
        errs = validate_answers(batches[v], lines)
        if errs:
            raise SystemExit(f"{path}: {len(errs)} invalid, first: {errs[0]}")
        answers += [json.loads(l) for l in lines]
    by_hash = {content_hash(inp): fid for fid, inp in links_inputs(cards, ungrouped).items()}
    votes = {}
    for a in answers:
        votes.setdefault(by_hash[a["input_hash"]], {})[a["variant"]] = a
    merged = {f: merge_links(v, f, k=len(answer_paths), log_path=esc_log) for f, v in sorted(votes.items())}
    cache.put_all(answers)
    out, kept, total, escalated = [], 0, 0, 0
    for c in cards:
        if is_sector(c):
            out.append(c)
            continue
        m = merged[c["id"]]
        old = {l["id"] for l in c["links"] if l["rel"] == "upstream"}
        total += len(old)
        kept += len(old & set(m["upstream"]))
        escalated += m["escalated"]
        links = [{"id": i, "rel": "upstream", "weight": round(w, 6)} for i, w in m["upstream"].items()]
        links += [{"id": i, "rel": "overlap", "weight": round(m["overlap_weights"][i], 6)} for i in m["overlap"]]
        conf = CONF_FLOOR + CONF_SPAN * field_agreement(votes[c["id"]])
        prov = dict(c["provenance"], links={"source": source, "confidence": round(conf, 3)})
        out.append(validate_card(dict(c, links=links, provenance=prov)))
    Path(out_path).write_text("".join(json.dumps(c, ensure_ascii=False) + "\n" for c in out), encoding="utf-8")
    stats = agreement_stats(votes)
    stats.update(escalated=escalated, v0_upstream_retained=kept / total if total else 0.0, v0_upstream_links=total)
    return stats


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("answers", nargs=3, help="answers files for variants 0, 1, 2 (in order)")
    ap.add_argument("--seed", default=ROOT / "data/coarse/seed_v0.jsonl")
    ap.add_argument("--out", default=ROOT / "data/coarse/seed_v1.jsonl")
    a = ap.parse_args(argv)
    s = apply(a.seed, a.answers, a.out, AnswerCache(), ROOT / "data/answers/escalations.links.jsonl")
    print(f"fields: {s['fields']}")
    print(f"fields with an upstream agreed by all 3 variants: {s['upstream_all_agree']:.1%}")
    print(f"mean Jaccard of overlap sets across variants: {s['overlap_jaccard']:.3f}")
    print(f"escalated (no upstream named twice): {s['escalated']}")
    print(f"seed_v0 guessed upstream links retained: {s['v0_upstream_retained']:.1%} of {s['v0_upstream_links']}")
    print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
