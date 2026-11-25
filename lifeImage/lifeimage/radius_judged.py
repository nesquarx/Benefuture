"""Judged radius (LI.26): one 0-10 verdict per coarse field, "how advanced and specialised as most people meet it".

The mechanical proxies of `radius.py` do not correlate as ruled (PLAN, "Radius proxies, mechanical"), so coarse fields
are also judged directly, by the axes v3 method: one card per task, at most `MAX_TASKS` tasks per batch file (parts
balanced in size), `K` = 2 variants in different hash-determined orders, a prompt (`prompts/radius.v1.md`) naming
complexity, difficulty and specificity as the aspects to weigh, and a verdict string "0" (elementary) to "10" (highly
specialised). `radius_report` measures variant agreement, the share at a pole, the Spearman with each mechanical proxy
and the domains where judged and mechanical disagree most. `radius.compute(judged=...)` takes the scores into the composite.
"""
import json
import math
from itertools import combinations
from pathlib import Path

from .axes import axes_input
from .axes_v3 import SCALE, balanced_parts, parse_scale
from .canonical import canonical_json, content_hash
from .packs import is_sector
from .radius import rank_unit, spearman
from .tasks import DEFAULT_PROMPTS, read_prefix
import hashlib

TASK_TYPE = "radius"
PROMPT_VERSION = 1
K = 2
MAX_TASKS = 50  # governed: tasks per batch file, small enough that a runner judges each one
PROXIES = ("complexity", "difficulty", "specificity", "composite")
DISAGREEMENT_N = 10


def _order_key(h, v):
    return hashlib.sha256(f"{h}:{v}:radius-order".encode()).hexdigest()


def judged_fields(cards):
    """[(input hash, input)] for the coarse fields (not sectors); the input is the axes card input."""
    by = {c["id"]: c for c in cards}
    return [(content_hash(axes_input(c, by)), axes_input(c, by)) for c in cards if not is_sector(c)]


def build_batches(cards, *, model, prompts_dir=DEFAULT_PROMPTS, k=K, max_tasks=MAX_TASKS, cache=None):
    """{(variant, part): [header, task lines...]}; cached (field, variant) votes are skipped."""
    header = json.dumps({"kind": "header", "task_type": TASK_TYPE, "model": model, "prompt_version": PROMPT_VERSION,
                         "prefix": read_prefix(TASK_TYPE, PROMPT_VERSION, prompts_dir)}, sort_keys=True, ensure_ascii=False)
    fields = judged_fields(cards)
    out = {}
    for v in range(k):
        todo = [(h, inp) for h, inp in sorted(fields, key=lambda f: (_order_key(f[0], v), f[0]))
                if cache is None or not cache.has(TASK_TYPE, h, model, PROMPT_VERSION, v)]
        for n, part in enumerate(balanced_parts(todo, max_tasks)):
            out[(v, n)] = [header] + [canonical_json({
                "kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": TASK_TYPE, "prompt_version": PROMPT_VERSION,
                "input_hash": h, "variant": v, "k": k, "input": inp, "allowed_verdicts": SCALE}) for h, inp in part]
    return out


def write_batches(batches, out_dir):
    """Write radius.v1.var<v>.part<n>.jsonl files; returns the paths in key order."""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for (v, n), lines in sorted(batches.items()):
        p = out / f"radius.v{PROMPT_VERSION}.var{v}.part{n}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    return paths


def judged_means(answers, owner):
    """{field id: mean score 0..10} over the answers, matched by input hash through `owner` {hash: id}."""
    acc = {}
    for a in answers:
        if a["input_hash"] in owner:
            acc.setdefault(owner[a["input_hash"]], []).append(parse_scale(a["verdict"]))
    return {i: math.fsum(v) / len(v) for i, v in sorted(acc.items())}


def owners(cards):
    return {h: inp["card"]["id"] for h, inp in judged_fields(cards)}


def radius_report(answers, cards):
    """Variant agreement, pole share, Spearman with each proxy of the cards' `radius`, largest judged/mechanical gaps."""
    owner = owners(cards)
    by_v, scores = {}, []
    for a in answers:
        if a["input_hash"] in owner:
            s = parse_scale(a["verdict"])
            scores.append(s)
            by_v.setdefault(a["variant"], {})[owner[a["input_hash"]]] = s
    sp, mad = [], []
    for a, b in combinations(sorted(by_v), 2):
        common = sorted(set(by_v[a]) & set(by_v[b]))
        if len(common) > 1:
            sp.append(spearman([by_v[a][i] for i in common], [by_v[b][i] for i in common]))
            mad.append(math.fsum(abs(by_v[a][i] - by_v[b][i]) for i in common) / len(common))
    mean = lambda xs: math.fsum(xs) / len(xs) if xs else None
    means = judged_means(answers, owner)
    by = {c["id"]: c for c in cards}
    corr = {}
    for p in PROXIES:
        common = sorted(i for i in means if (by[i].get("radius") or {}).get(p) is not None)
        corr[p] = spearman([means[i] for i in common], [by[i]["radius"][p] for i in common]) if len(common) > 1 else None
    both = sorted(i for i in means if (by[i].get("radius") or {}).get("composite") is not None)
    rj = rank_unit({i: means[i] for i in both})
    rm = rank_unit({i: by[i]["radius"]["composite"] for i in both})
    gap = sorted(({"id": i, "label": by[i]["label"], "judged": round(means[i], 2), "mechanical": round(by[i]["radius"]["composite"], 4),
                   "gap": round(abs(rj[i] - rm[i]), 4)} for i in both), key=lambda d: (-d["gap"], d["id"]))
    return {"fields": len(means), "variants": len(by_v), "answers": len(scores),
            "share_poles": sum(s in (0, 10) for s in scores) / len(scores) if scores else None,
            "variant_spearman": mean(sp), "variant_mad": mean(mad), "spearman": corr, "disagreement": gap[:DISAGREEMENT_N]}
