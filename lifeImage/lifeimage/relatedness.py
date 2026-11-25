"""Pairwise relatedness judging (LI.55): how thematically related are two coarse fields, 0 to 10, one card per pair.

The layout simulation's signal covers few field pairs (1,127 of 30,381), and the pairs a layout puts side by side are the ones
it most needs signal for. This task grows the signal where it is missing, cheaply: one card per pair (both fields with label,
description and up to `CHILDREN` fine-children labels), a fixed prefix with three calibration examples (stable, so a runner
reuses it, LI.11), a 0-10 verdict. Variant 0 shows the pair in canonical id order and variant 1 reversed, so the order bias is
measurable and the mean over variants cancels it.

Pairs (`select_pairs`), over the fields' ids, the simulation's combined signal and the two layouts' ring orders:
- near: every pair within `NEAR` positions in either layout with no signal (all of them, unless they exceed the cap);
- wide: pairs within `WIDE` positions in either layout with no signal, taken closest first (smallest nearer-layout distance, then
  smallest sum of both distances, then a hash) until the total of near and wide reaches `CAP`;
- control: `CONTROLS` pairs whose signal is at least the median of the signals present, sampled by hash;
- random: `RANDOMS` pairs with no signal that are at least a quarter of the ring apart in both layouts, sampled by hash.
Controls and randoms calibrate the scale against the existing signal: the prediction (stated before any run) is that controls
score at least `PREDICTED_GAP` points above random pairs on average (confidence 0.8). Nothing in a task line says which kind a
pair is; the key beside the batches does.

`judged_signal` turns answers into the simulation's 'judged' source: per pair the mean verdict over variants scaled to [0, 1]
and the variants' agreement as confidence (1 minus their range over the scale; a single variant gets `SINGLE_CONFIDENCE`).
"""
import hashlib
import json
from collections import defaultdict
from pathlib import Path

import numpy as np

from .axes_v3 import balanced_parts
from .canonical import canonical_json, content_hash
from .tasks import DEFAULT_PROMPTS, read_prefix

TASK_TYPE = "relatedness"
PROMPT_VERSION = 1
VERDICTS = [str(i) for i in range(11)]
SCALE = 10.0
K = 2  # variants: canonical order, reversed
MAX_TASKS = 50  # governed: tasks per batch file (the runner judges each one)
CHILDREN = 5  # fine-children labels shown per field
NEAR = 2  # positions: adjacent pairs, the ones a layout puts side by side
WIDE = 5  # positions: the wider neighbourhood
CAP = 2500  # governed: most near + wide pairs to judge (about 2.5k tasks, 5k with both variants)
CONTROLS = 150
RANDOMS = 150
FAR_FRACTION = 0.25  # random pairs are at least this share of the ring apart in both layouts
PREDICTED_GAP = 3.0  # points: controls over randoms; confidence 0.8, stated before the first run
SINGLE_CONFIDENCE = 0.5  # one variant answered: no agreement to measure


def _h(*parts):
    return hashlib.sha256(":".join(map(str, parts)).encode()).hexdigest()


def _ring(order):
    n = len(order)
    pos = {i: p for p, i in enumerate(order)}
    return pos, n


def select_pairs(ids, combined, order_a, order_b, *, cap=CAP, near=NEAR, wide=WIDE, controls=CONTROLS, randoms=RANDOMS):
    """{"kind": {(a, b): kind with a < b, in sorted order}, "counts", "available", "cap"} (see the module docstring)."""
    ids = list(ids)
    ix = {i: n for n, i in enumerate(ids)}
    m = np.asarray(combined, float)
    if set(order_a) != set(ids) or set(order_b) != set(ids):
        raise ValueError("both layouts must order exactly the fields")
    pa, na = _ring(order_a)
    pb, nb = _ring(order_b)
    dist = lambda p, n, a, b: min((p[a] - p[b]) % n, (p[b] - p[a]) % n)
    near_l, wide_l, strong, far = [], [], [], []
    pos_vals = m[np.triu_indices(len(ids), 1)]
    pos_vals = pos_vals[pos_vals > 0]
    strong_floor = float(np.median(pos_vals)) if len(pos_vals) else float("inf")
    far_min = max(wide + 1, int(FAR_FRACTION * len(ids)))
    srt = sorted(ids)
    for x in range(len(srt)):
        for y in range(x + 1, len(srt)):
            a, b = srt[x], srt[y]
            da, db = dist(pa, na, a, b), dist(pb, nb, a, b)
            lo = min(da, db)
            v = m[ix[a], ix[b]]
            if v > 0:
                if v >= strong_floor:
                    strong.append((a, b))
            elif lo <= near:
                near_l.append(((a, b), lo, da + db))
            elif lo <= wide:
                wide_l.append(((a, b), lo, da + db))
            elif min(da, db) >= far_min:
                far.append((a, b))
    prio = lambda t: (t[1], t[2], _h(*t[0], "wide"))
    near_l.sort(key=prio)
    wide_l.sort(key=prio)
    take_near = near_l[:cap]
    take_wide = wide_l[:max(0, cap - len(take_near))]
    pick = lambda pairs, k, tag: sorted(pairs, key=lambda p: _h(*p, tag))[:k]
    kind = {}
    for p, *_ in take_near:
        kind[p] = "near"
    for p, *_ in take_wide:
        kind[p] = "wide"
    for p in pick(strong, controls, "control"):
        kind[p] = "control"
    for p in pick(far, randoms, "random"):
        kind[p] = "random"
    kind = dict(sorted(kind.items()))
    counts = defaultdict(int)
    for k in kind.values():
        counts[k] += 1
    return {"kind": kind, "counts": dict(counts), "cap": cap,
            "available": {"near": len(near_l), "wide": len(wide_l), "control": len(strong), "random": len(far)}}


def field_card(card, children):
    kids = sorted(children.get(card["id"], []), key=lambda t: (-t[0], t[1]))
    return {"id": card["id"], "label": card["label"], "description": card["description"],
            "children": [label for _, label in kids[:CHILDREN]]}


def fine_children(fine_cards):
    """{field id: [(link weight, label)]} from the fine cards' links."""
    out = defaultdict(list)
    for f in fine_cards:
        for l in f.get("links", []):
            out[l["id"]].append((float(l.get("weight", 0.0)), f["label"]))
    return out


def build_relatedness_batches(cards, fine_cards, pairs, *, model, prompts_dir=DEFAULT_PROMPTS, k=K, max_tasks=MAX_TASKS):
    """({(variant, part): [header, task lines...]}, key). `pairs` is {(a, b): kind} (or any iterable of pairs; kind then None).
    The key maps each task to its pair, kind, variant and the field shown first."""
    kinds = dict(pairs) if isinstance(pairs, dict) else {p: None for p in pairs}
    by = {c["id"]: c for c in cards}
    kids = fine_children(fine_cards)
    items = []
    for (a, b), kd in sorted(kinds.items()):
        if a == b:
            raise ValueError(f"a pair needs two fields, not {a} twice")
        if a > b:
            a, b = b, a
        if a not in by or b not in by:
            raise ValueError(f"no card for {a if a not in by else b}")
        ca, cb = field_card(by[a], kids), field_card(by[b], kids)
        items.append((a, b, kd, ca, cb, content_hash({"pair": [ca, cb]})))
    key = {"tasks": {}, "pairs": {f"{a}|{b}": kd for a, b, kd, *_ in items}, "prompt_version": PROMPT_VERSION}
    if not items:
        return {}, key
    header = json.dumps({"kind": "header", "task_type": TASK_TYPE, "model": model, "prompt_version": PROMPT_VERSION,
                         "prefix": read_prefix(TASK_TYPE, PROMPT_VERSION, prompts_dir)}, sort_keys=True, ensure_ascii=False)
    out = {}
    for v in range(k):
        lines = []
        for a, b, kd, ca, cb, h in sorted(items, key=lambda it: (_h(it[5], v, "relatedness-order"), it[0], it[1])):
            first, second = (ca, cb) if v % 2 == 0 else (cb, ca)
            tid = f"{h[:16]}-v{v}"
            key["tasks"][tid] = {"pair": [a, b], "kind": kd, "variant": v, "first": first["id"]}
            lines.append(canonical_json({
                "kind": "task", "task_id": tid, "task_type": TASK_TYPE, "prompt_version": PROMPT_VERSION, "input_hash": h,
                "variant": v, "k": k, "input": {"first": first, "second": second}, "allowed_verdicts": VERDICTS}))
        for n, part in enumerate(balanced_parts(lines, max_tasks)):
            out[(v, n)] = [header] + part
    return out, key


def write_relatedness_batches(batches, key, out_dir):
    """relatedness.v1.var<v>.part<n>.jsonl files and relatedness.v1.key.json (keep the key); returns the paths."""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for (v, n), lines in sorted(batches.items()):
        p = out / f"relatedness.v{PROMPT_VERSION}.var{v}.part{n}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    kp = out / f"relatedness.v{PROMPT_VERSION}.key.json"
    kp.write_text(json.dumps(key, sort_keys=True, indent=1), encoding="utf-8")
    return paths + [kp]


def answer_rows(answers, key):
    """Self-describing rows {task_id, pair, variant, first, verdict, model, prompt_version} from runner answers and the key."""
    rows = []
    for a in answers:
        t = key["tasks"][a["task_id"]]
        rows.append({"task_id": a["task_id"], "pair": t["pair"], "variant": t["variant"], "first": t["first"],
                     "verdict": a["verdict"], "model": a.get("model"), "prompt_version": a.get("prompt_version", PROMPT_VERSION)})
    return rows


def read_rows(path):
    p = Path(path)
    if not p.exists():
        return []
    return [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()]


def _by_pair(rows):
    g = defaultdict(dict)
    for r in rows:
        g[tuple(sorted(r["pair"]))][r["variant"]] = int(r["verdict"])
    return g


def judged_signal(rows):
    """{(a, b) with a < b: {"score": mean verdict over variants / 10, "confidence": agreement, "n": variants}}."""
    out = {}
    for p, votes in sorted(_by_pair(rows).items()):
        v = list(votes.values())
        conf = SINGLE_CONFIDENCE if len(v) == 1 else 1.0 - (max(v) - min(v)) / SCALE
        out[p] = {"score": sum(v) / len(v) / SCALE, "confidence": conf, "n": len(v)}
    return out


def order_bias(rows):
    """Canonical (variant 0) against reversed (variant 1) over pairs answered in both: the mean signed difference, the share
    within one point, and the correlation."""
    both = [(v[0], v[1]) for v in _by_pair(rows).values() if 0 in v and 1 in v]
    if not both:
        return {"pairs": 0, "mean_reversed_minus_canonical": None, "agree_within_1": None, "correlation": None}
    x, y = np.array(both, float).T
    corr = float(np.corrcoef(x, y)[0, 1]) if x.std() > 0 and y.std() > 0 else None
    return {"pairs": len(both), "mean_reversed_minus_canonical": float((y - x).mean()),
            "agree_within_1": float((np.abs(y - x) <= 1).mean()), "correlation": corr}


def calibration(rows, kind):
    """Mean score (0-10) of controls and random pairs, their gap, and whether the predicted gap was met."""
    means = defaultdict(list)
    for p, votes in _by_pair(rows).items():
        kd = kind.get(p)
        if kd in ("control", "random"):
            means[kd].append(sum(votes.values()) / len(votes))
    c, r = means["control"], means["random"]
    cm = float(np.mean(c)) if c else None
    rm = float(np.mean(r)) if r else None
    gap = None if cm is None or rm is None else cm - rm
    return {"control_mean": cm, "random_mean": rm, "gap": gap, "controls": len(c), "randoms": len(r),
            "predicted_gap": PREDICTED_GAP, "prediction_met": gap is not None and gap >= PREDICTED_GAP}
