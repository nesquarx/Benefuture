"""Adjacency judging (LI.55): which of two layouts puts the thematically closer neighbours beside a field, judged blind.

A task shows one field and two sets of its two circular neighbours, one from each layout, as `set_1` and `set_2` without
saying which is which; the verdict is "1", "2" or "equal". Fields whose neighbour sets agree in both layouts are not asked.
The input hash covers the field and the two sets sorted, so it does not depend on presentation; variant 0 puts layout A first
when the hash's parity says so (randomised across fields), variant 1 reverses it, so a position bias adds a win to each layout.
The key (which layout was set 1, per task) is written beside the batches, never in a task line. `adjacency_report` maps
verdicts back through the key.
"""
import hashlib
import json
import math
from pathlib import Path

from .axes import axes_input
from .axes_v3 import balanced_parts
from .canonical import canonical_json, content_hash
from .packs import is_sector
from .tasks import DEFAULT_PROMPTS, read_prefix

TASK_TYPE = "adjacency"
PROMPT_VERSION = 1
VERDICTS = ["1", "2", "equal"]
MAX_TASKS = 50  # governed: tasks per batch file (the runner judges each one)
K = 2


def neighbour_sets(order):
    """{id: frozenset of the two circular neighbours}."""
    n = len(order)
    return {order[p]: frozenset((order[p - 1], order[(p + 1) % n])) for p in range(n)}


def _short(c):
    return {"id": c["id"], "label": c["label"], "description": c["description"]}


def build_adjacency_batches(cards, order_a, order_b, *, model, prompts_dir=DEFAULT_PROMPTS, k=K, max_tasks=MAX_TASKS):
    """({(variant, part): [header, task lines...]}, key). Layouts A and B are lists of field ids in ring order."""
    for name, o in (("A", order_a), ("B", order_b)):
        if len(o) < 4 or len(set(o)) != len(o):
            raise ValueError(f"layout {name} needs at least 4 distinct fields")
    if set(order_a) != set(order_b):
        raise ValueError("the layouts must order the same fields")
    by = {c["id"]: c for c in cards}
    missing = sorted(set(order_a) - set(by))
    if missing:
        raise ValueError(f"no card for {missing[:3]}")
    na, nb = neighbour_sets(order_a), neighbour_sets(order_b)
    items = []
    for f in sorted(order_a):
        if na[f] == nb[f]:
            continue
        card = axes_input(by[f], by)["card"]
        sets = {"A": sorted(na[f]), "B": sorted(nb[f])}
        h = content_hash({"card": card, "sets": sorted([sets["A"], sets["B"]])})
        swap = int(hashlib.sha256(f"{h}:order".encode()).hexdigest()[0], 16) % 2 == 1
        items.append((f, card, sets, h, swap))
    key = {"fields": {f: {"A": s["A"], "B": s["B"]} for f, _, s, _, _ in items}, "tasks": {}, "A": "axes placement", "B": "simulation"}
    if not items:
        return {}, key
    header = json.dumps({"kind": "header", "task_type": TASK_TYPE, "model": model, "prompt_version": PROMPT_VERSION,
                         "prefix": read_prefix(TASK_TYPE, PROMPT_VERSION, prompts_dir)}, sort_keys=True, ensure_ascii=False)
    out = {}
    for v in range(k):
        todo = sorted(items, key=lambda it: (hashlib.sha256(f"{it[3]}:{v}:adjacency-order".encode()).hexdigest(), it[0]))
        lines = []
        for f, card, sets, h, swap in todo:
            first = ("B", "A") if swap else ("A", "B")
            if v % 2 == 1:
                first = first[::-1]
            tid = f"{h[:16]}-v{v}"
            key["tasks"][tid] = {"field": f, "set_1": first[0], "variant": v}
            lines.append(canonical_json({
                "kind": "task", "task_id": tid, "task_type": TASK_TYPE, "prompt_version": PROMPT_VERSION, "input_hash": h,
                "variant": v, "k": k,
                "input": {"card": card, "candidates": [],
                          "set_1": [_short(by[i]) for i in sets[first[0]]], "set_2": [_short(by[i]) for i in sets[first[1]]]},
                "allowed_verdicts": VERDICTS}))
        for n, part in enumerate(balanced_parts(lines, max_tasks)):
            out[(v, n)] = [header] + part
    return out, key


def write_adjacency_batches(batches, key, out_dir):
    """adjacency.v1.var<v>.part<n>.jsonl files and adjacency.v1.key.json (keep the key from the runner); returns the paths."""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for (v, n), lines in sorted(batches.items()):
        p = out / f"adjacency.v{PROMPT_VERSION}.var{v}.part{n}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    kp = out / f"adjacency.v{PROMPT_VERSION}.key.json"
    kp.write_text(json.dumps(key, sort_keys=True, indent=1), encoding="utf-8")
    return paths + [kp]


def adjacency_report(answers, key):
    """Counts of verdicts mapped back to layouts: decisive judgements, share for layout B among them, the position bias (share of
    decisive verdicts naming set 1), the sign-test z of B against A, and ties."""
    b = a = tie = first = 0
    for ans in answers:
        t = key["tasks"][ans["task_id"]]
        v = ans["verdict"]
        if v == "equal":
            tie += 1
            continue
        first += v == "1"
        chosen = t["set_1"] if v == "1" else ("B" if t["set_1"] == "A" else "A")
        b += chosen == "B"
        a += chosen == "A"
    n = a + b
    return {"answers": len(answers), "decisive": n, "ties": tie, "wins_a": a, "wins_b": b,
            "share_b_of_decisive": b / n if n else None, "position_bias": first / n if n else None,
            "z_b_over_a": (b - n / 2) / (math.sqrt(n) / 2) if n else None}
