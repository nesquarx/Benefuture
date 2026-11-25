"""The `fine_parent` task: each candidate card is answered against the ungrouped coarse pack; k variants are merged.

Batches are small (at most 50 cards, the size at which runners judge each card instead of building a lookup table), one
set per variant. The header prefix is the instructions then the pack in that variant's fixed shuffle (static, so every
task of a file shares it); a task carries its card and the pack's hash only, so a change elsewhere leaves its hash and
its cached answer alone. The card shows the label its own source files it under (`broader_in_source`) as a hint, never a
coarse parent.

Answer: verdict `upstream` (the candidate is part of, a kind of, or a specialisation of the named coarse domains),
`overlap` (it shares ground with them without being contained) or `new_field` (no coarse domain holds it); `weights`
{coarse id: weight} (1 to 3 ids, sum 1) for the first two, none for `new_field`, whose reason names the missing field.
"""
import itertools
import json
from collections import Counter
from pathlib import Path

from ..canonical import canonical_json, content_hash
from ..packs import is_sector, pack_ids, ungrouped_pack
from ..tasks import DEFAULT_K, DEFAULT_PROMPTS, read_prefix
from ..validate import validate_answers

TASK = "fine_parent"
VERDICTS = ["upstream", "overlap", "new_field"]
MAX_CARDS_PER_BATCH = 50
MAX_PARENTS = 3
QUORUM = 2  # votes (of k = 3) needed to keep a parent id
CONF_FLOOR, CONF_SPAN = 0.2, 0.7  # confidence = floor + span x agreement, in [0.2, 0.9]: never 1


def card_view(c):
    return {"id": c["id"], "label": c["label"], "aliases": list(c.get("aliases", []))[:5], "description": c.get("description", ""),
            "kinds": list(c["kinds"]), "broader_in_source": list(c.get("broader_in_source", []))}


def _order(cands, variant):
    if variant == 0:
        return sorted(cands, key=lambda c: c["id"])
    import hashlib
    return sorted(cands, key=lambda c: hashlib.sha256(f"{variant}:{c['id']}".encode()).hexdigest())


def build_fine_batches(cands, coarse_cards, *, cache=None, model, prompt_version=1, prompts_dir=DEFAULT_PROMPTS, k=DEFAULT_K,
                       max_cards=MAX_CARDS_PER_BATCH):
    """{(variant, part): [header, task lines...]} for the (candidate, variant) pairs not yet cached."""
    if max_cards > MAX_CARDS_PER_BATCH:
        raise ValueError(f"at most {MAX_CARDS_PER_BATCH} cards per batch")
    instructions = read_prefix(TASK, prompt_version, prompts_dir)
    pack_hash = content_hash({"pack": ungrouped_pack(coarse_cards)})[:16]
    inputs = {c["id"]: {"card": card_view(c), "pack": pack_hash} for c in cands}
    out = {}
    for v in range(k):
        header = json.dumps({"kind": "header", "task_type": TASK, "model": model, "prompt_version": prompt_version,
                             "prefix": instructions.rstrip("\n") + "\n\n" + ungrouped_pack(coarse_cards, v)},
                            sort_keys=True, ensure_ascii=False)
        lines = []
        for c in _order(cands, v):
            inp = inputs[c["id"]]
            h = content_hash(inp)
            if cache is not None and cache.has(TASK, h, model, prompt_version, v):
                continue
            lines.append(canonical_json({"kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": TASK,
                                         "prompt_version": prompt_version, "input_hash": h, "variant": v, "k": k,
                                         "input": inp, "allowed_verdicts": VERDICTS}))
        for n, i in enumerate(range(0, len(lines), max_cards)):
            out[(v, n)] = [header] + lines[i:i + max_cards]
    return out


def write_fine_batches(batches, out_dir, prompt_version=1, tag=None):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for (v, n), lines in sorted(batches.items()):
        p = out / f"{TASK}.v{prompt_version}{f'.{tag}' if tag else ''}.var{v}.part{n}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    return paths


def validate_fine_answers(batch_lines, answer_lines):
    """Errors (empty when valid): the generic checks of `validate_answers`, plus 1 to 3 parent ids from the pack for
    `upstream` and `overlap`, and no weights for `new_field`."""
    errors = validate_answers(batch_lines, answer_lines)
    ids = pack_ids(json.loads(batch_lines[0])["prefix"])
    for n, line in enumerate(answer_lines, 1):
        try:
            a = json.loads(line)
        except ValueError:
            continue
        w = a.get("weights")
        if a.get("verdict") == "new_field":
            if w:
                errors.append(f"line {n}: new_field takes no weights")
        elif a.get("verdict") in ("upstream", "overlap"):
            if not w:
                errors.append(f"line {n}: {a['verdict']} needs weights over 1-{MAX_PARENTS} parents")
                continue
            if len(w) > MAX_PARENTS:
                errors.append(f"line {n}: {len(w)} parents, expected 1-{MAX_PARENTS} parents")
            errors += [f"line {n}: {i} is not in the pack" for i in w if i not in ids]
    return errors


def _jaccard(a, b):
    return 1.0 if not a and not b else len(a & b) / len(a | b)


def merge_fine(votes, k=DEFAULT_K):
    """votes: {variant: answer}. Verdict by strict majority; parents named by >= 2 variants (weights averaged over the
    namers, renormalised); agreement is the mean pairwise Jaccard of the variants' parent sets (`new_field` counting as
    its own set) and confidence = 0.2 + 0.7 x agreement. Escalated: no verdict majority, a `new_field` that is not
    unanimous, or no parent named twice (the most named is then kept alone)."""
    if sorted(votes) != list(range(k)):
        raise ValueError(f"need exactly the {k} variants 0..{k - 1}, got {sorted(votes)}")
    verdicts = Counter(a["verdict"] for a in votes.values())
    (top, n), *rest = verdicts.most_common()
    majority = top if n * 2 > k else None
    reasons, escalated = [], majority is None
    why = "no verdict majority" if majority is None else ""
    new_field = majority == "new_field"
    if new_field:
        escalated |= n < k
        why = why or ("new_field not unanimous" if n < k else "")
        parents, relation = {}, None
        for v in sorted(votes):
            if votes[v]["verdict"] == "new_field" and votes[v]["reason"] not in reasons:
                reasons.append(votes[v]["reason"])
    else:
        voters = {v: a for v, a in votes.items() if a["verdict"] != "new_field"}
        named = Counter(i for a in voters.values() for i in a["weights"])
        mean = {i: sum(a["weights"][i] for a in voters.values() if i in a["weights"]) / c for i, c in named.items()}
        kept = [i for i, c in named.items() if c >= QUORUM]
        if not kept:
            kept, escalated, why = [min(named, key=lambda i: (-named[i], -mean[i], i))], True, why or "no parent named by >= 2 variants"
        total = sum(mean[i] for i in kept)
        parents = {i: mean[i] / total for i in sorted(kept)}
        rels = Counter(a["verdict"] for a in voters.values())
        relation = majority if majority else ("upstream" if rels["upstream"] > rels["overlap"] else "overlap")
    sets = [frozenset(a["weights"]) if a["verdict"] != "new_field" else frozenset({"__new_field__"}) for a in votes.values()]
    pairs = list(itertools.combinations(sets, 2))
    agreement = sum(_jaccard(x, y) for x, y in pairs) / len(pairs)
    main = min(parents, key=lambda i: (-parents[i], i)) if parents else None
    return {"parents": parents, "relation": relation, "new_field": new_field, "new_field_reasons": reasons, "main": main,
            "agreement": agreement, "confidence": CONF_FLOOR + CONF_SPAN * agreement, "escalated": escalated,
            "escalation_reason": why, "votes": {str(v): votes[v]["verdict"] for v in sorted(votes)}}
