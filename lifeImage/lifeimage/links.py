"""The links task: each field card is answered against the coarse pack; k variants are merged by vote.

Batches: one per variant. The header prefix is the instructions then the pack ordered for that variant (static, so
every task in the batch shares it); a task is one field's id, label and description only, so current guessed links
never anchor the answer. The input carries the pack's hash, so a changed graph misses the answer cache.
"""
import itertools
import json
from collections import Counter
from pathlib import Path

from .canonical import canonical_json, content_hash
from .packs import coarse_pack, is_sector, ungrouped_pack
from .tasks import DEFAULT_K, DEFAULT_PROMPTS, read_prefix
from .validate import LINKS_MAX_OVERLAP, validate_links_answer  # noqa: F401  (re-exported)

QUORUM = 2  # votes (of k=3) needed to keep an upstream or overlap id


def links_inputs(cards, ungrouped=False):
    """{field id: task input}: id, label, description and the pack hash; sectors are not classified."""
    pack_hash = content_hash({"pack": (ungrouped_pack if ungrouped else coarse_pack)(cards)})[:16]
    return {c["id"]: {"card": {"id": c["id"], "label": c["label"], "description": c["description"]}, "pack": pack_hash}
            for c in sorted(cards, key=lambda c: c["id"]) if not is_sector(c)}


def build_links_batches(cards, *, cache=None, model, prompt_version=1, prompts_dir=DEFAULT_PROMPTS, k=DEFAULT_K, ungrouped=False):
    """{variant: [header, task lines...]} for the (field, variant) pairs not yet cached. With `ungrouped` (links.v2)
    the pack lists sectors then all fields with no grouping, shuffled per variant."""
    instructions = read_prefix("links", prompt_version, prompts_dir)
    inputs = links_inputs(cards, ungrouped)
    pack = ungrouped_pack if ungrouped else coarse_pack
    batches = {}
    for v in range(k):
        header = json.dumps({"kind": "header", "task_type": "links", "model": model, "prompt_version": prompt_version,
                             "prefix": instructions.rstrip("\n") + "\n\n" + pack(cards, v)},
                            sort_keys=True, ensure_ascii=False)
        lines = []
        for inp in inputs.values():
            h = content_hash(inp)
            if cache is not None and cache.has("links", h, model, prompt_version, v):
                continue
            lines.append(canonical_json({
                "kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": "links", "prompt_version": prompt_version,
                "input_hash": h, "variant": v, "k": k, "input": inp, "allowed_verdicts": ["links"]}))
        if lines:
            batches[v] = [header] + lines
    return batches


def write_links_batches(batches, out_dir, prompt_version=1):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for v, lines in sorted(batches.items()):
        p = out / f"links.v{prompt_version}.var{v}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    return paths


def _check_votes(votes, k):
    if sorted(votes) != list(range(k)):
        raise ValueError(f"need exactly the {k} variants 0..{k - 1}, got {sorted(votes)}")


def merge_links(votes, field_id, k=DEFAULT_K, log_path=None):
    """votes: {variant: answer with upstream and overlap}. Upstream ids named by >= 2 variants are kept, weights
    averaged over the variants that named them then renormalised; if none reaches 2 the most-named (then heaviest
    mean, then id) is kept alone and the escalation is logged. Overlaps named by >= 2 are kept (at most 6, most-named
    first), each with weight = share of variants naming it."""
    _check_votes(votes, k)
    named = Counter(i for a in votes.values() for i in a["upstream"])
    mean = {i: sum(a["upstream"][i] for a in votes.values() if i in a["upstream"]) / n for i, n in named.items()}
    kept = [i for i, n in named.items() if n >= QUORUM]
    escalated = not kept
    if escalated:
        kept = [min(named, key=lambda i: (-named[i], -mean[i], i))]
    total = sum(mean[i] for i in kept)
    upstream = {i: mean[i] / total for i in sorted(kept)}
    on = Counter(i for a in votes.values() for i in set(a["overlap"]))
    overlap = sorted((i for i, n in on.items() if n >= QUORUM), key=lambda i: (-on[i], i))[:LINKS_MAX_OVERLAP]
    if escalated and log_path is not None:
        rec = {"task_type": "links", "field": field_id, "reason": "no upstream id named by >= 2 variants",
               "kept": sorted(kept), "votes": {str(v): a["upstream"] for v, a in sorted(votes.items())}}
        Path(log_path).parent.mkdir(parents=True, exist_ok=True)
        with Path(log_path).open("a", encoding="utf-8") as f:
            f.write(canonical_json(rec) + "\n")
    return {"upstream": upstream, "overlap": sorted(overlap), "overlap_weights": {i: on[i] / k for i in overlap},
            "escalated": escalated}


def jaccard(a, b):
    a, b = set(a), set(b)
    return 1.0 if not a and not b else len(a & b) / len(a | b)


def field_agreement(votes):
    """Mean pairwise Jaccard of the variants' upstream id sets (1 = identical structure)."""
    pairs = list(itertools.combinations(votes.values(), 2))
    return sum(jaccard(x["upstream"], y["upstream"]) for x, y in pairs) / len(pairs)


def agreement_stats(per_field_votes):
    """Share of fields with >= 1 upstream id named by every variant; mean pairwise Jaccard of overlap sets."""
    n = len(per_field_votes)
    full = sum(bool(set.intersection(*(set(a["upstream"]) for a in v.values()))) for v in per_field_votes.values())
    js = [jaccard(x["overlap"], y["overlap"]) for v in per_field_votes.values()
          for x, y in itertools.combinations(v.values(), 2)]
    return {"fields": n, "upstream_all_agree": full / n if n else 0.0,
            "overlap_jaccard": sum(js) / len(js) if js else 0.0}
