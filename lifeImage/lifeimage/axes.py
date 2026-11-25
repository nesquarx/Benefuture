"""The axes task: each field is scored on two axes, -2..+2 each; batches, parsing and the extreme-score share.

A task is one card (id, label, description, the labels of its sector upstream domains, heaviest first) and no
candidates. The input is the same in every variant, so the k variants differ only in task id and variant number.
`extreme_share` measures how much of the scoring sits at the poles (±2): prompt v1 scored 53% of scores at a pole,
v2 asks for ±2 only when a domain is clearly at the pole.
"""
import json
from pathlib import Path

from .canonical import canonical_json, content_hash
from .packs import is_sector
from .tasks import DEFAULT_K, DEFAULT_PROMPTS, read_prefix

SCORES = (-2, -1, 0, 1, 2)


def fmt(n):
    return "0" if n == 0 else f"{n:+d}"


ALLOWED = [f"{fmt(a)},{fmt(b)}" for a in SCORES for b in SCORES]


def sector_labels(card, by_id):
    ups = sorted((l for l in card["links"] if l["rel"] == "upstream" and l["id"] in by_id and is_sector(by_id[l["id"]])),
                 key=lambda l: (-l["weight"], l["id"]))
    return [by_id[l["id"]]["label"] for l in ups]


def axes_input(card, by_id):
    return {"candidates": [], "card": {"id": card["id"], "label": card["label"], "description": card["description"],
                                       "sectors": sector_labels(card, by_id)}}


def build_axes_batches(cards, *, model, prompt_version=2, prompts_dir=DEFAULT_PROMPTS, k=DEFAULT_K, cache=None):
    """{variant: [header, task lines...]}, fields in card order; cached (field, variant) pairs are skipped."""
    prefix = read_prefix("axes", prompt_version, prompts_dir)
    by_id = {c["id"]: c for c in cards}
    header = json.dumps({"kind": "header", "task_type": "axes", "model": model, "prompt_version": prompt_version,
                         "prefix": prefix}, sort_keys=True, ensure_ascii=False)
    batches = {}
    for v in range(k):
        lines = []
        for c in cards:
            if is_sector(c):
                continue
            inp = axes_input(c, by_id)
            h = content_hash(inp)
            if cache is not None and cache.has("axes", h, model, prompt_version, v):
                continue
            lines.append(canonical_json({
                "kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": "axes", "prompt_version": prompt_version,
                "input_hash": h, "variant": v, "k": k, "input": inp, "allowed_verdicts": ALLOWED}))
        if lines:
            batches[v] = [header] + lines
    return batches


def write_axes_batches(batches, out_dir, prompt_version=2):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for v, lines in sorted(batches.items()):
        p = out / f"axes.v{prompt_version}.var{v}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    return paths


def parse_scores(verdict):
    """(axis 1, axis 2) of a verdict such as "-2,+1"."""
    if verdict not in ALLOWED:
        raise ValueError(f"not an axes verdict: {verdict!r}")
    a, b = verdict.split(",")
    return int(a), int(b)


def extreme_share(answers):
    """Share of scores at a pole (|score| = 2) over both axes, per axis, and the share of items extreme on both."""
    pairs = [parse_scores(a["verdict"]) for a in answers]
    n = len(pairs)
    if not n:
        return {"items": 0, "scores": 0, "extreme": 0, "share": 0.0, "axis1": 0.0, "axis2": 0.0, "both_extreme_items": 0.0}
    e1, e2 = sum(abs(a) == 2 for a, _ in pairs), sum(abs(b) == 2 for _, b in pairs)
    return {"items": n, "scores": 2 * n, "extreme": e1 + e2, "share": (e1 + e2) / (2 * n), "axis1": e1 / n, "axis2": e2 / n,
            "both_extreme_items": sum(abs(a) == 2 and abs(b) == 2 for a, b in pairs) / n}
