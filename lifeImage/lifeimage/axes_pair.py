"""The axes_pair task: which of two domains is further toward the named pole of one axis.

One task is a pair of domain cards and an axis, context-free. Its input hash covers the axis and the two cards sorted
by id, so it does not depend on presentation; the k = 2 variants show the two orders, the first fixed by the hash and
the second its reverse, so a position bias adds one win to each side. A verdict "a" or "b" names the presented slot.

Design: anchors are about 12 fields spread across the v1/v2 means of the axis; every field meets the 2 nearest
anchors below and the 2 nearest above its own mean, plus 2 random fields, a pair appearing once. `comparisons`
sets the number each field initiates (anchors split over the two sides, 2 random fields): 6 is the default design,
4 the pilot's.

Single order (the pilot): each pair is asked once and the order is an Euler orientation of the pair graph, so every
field is shown first at most once more or less often than second: a position bias adds as many wins as losses to a
field and cancels across the set without the second order's cost.
"""
import hashlib
import json
from collections import defaultdict
from pathlib import Path

from .axes import axes_input, parse_scores
from .canonical import canonical_json, content_hash
from .packs import is_sector
from .tasks import DEFAULT_PROMPTS, read_prefix

AXES = ("abstract_tangible", "personal_global")
TOWARD = {"abstract_tangible": "tangible", "personal_global": "global and professional"}
VERDICTS = ["a", "b", "tie"]
TASK_TYPE = "axes_pair"
K = 2


def _digest(s):
    return hashlib.sha256(s.encode()).hexdigest()


def pair_hash(axis, cards):
    return content_hash({"axis": axis, "cards": sorted(cards, key=lambda c: c["id"])})


def presented(pair, input_hash, variant):
    """(first, second) ids shown in the variant: variant 0 by the hash's parity, variant 1 the reverse."""
    lo, hi = sorted(pair)
    swap = int(_digest(f"{input_hash}:order")[0], 16) % 2 == 1
    first, second = (hi, lo) if swap else (lo, hi)
    return (first, second) if variant == 0 else (second, first)


def axis_means(cards, answer_sets):
    """{axis: {field id: mean score}}: per version the mean over variants, then the mean over versions."""
    by_id = {c["id"]: c for c in cards}
    owner = {content_hash(axes_input(c, by_id)): c["id"] for c in cards if not is_sector(c)}
    per_version = []
    for answers in answer_sets:
        acc = defaultdict(lambda: [[], []])
        for a in answers:
            s = parse_scores(a["verdict"])
            for ax in (0, 1):
                acc[owner[a["input_hash"]]][ax].append(s[ax])
        per_version.append(acc)
    out = {}
    for ax, name in enumerate(AXES):
        ids = set().union(*(set(v) for v in per_version))
        out[name] = {i: sum(sum(v[i][ax]) / len(v[i][ax]) for v in per_version if i in v) / sum(i in v for v in per_version)
                     for i in sorted(ids)}
    return out


def choose_anchors(means, n=12):
    """n distinct fields whose means are nearest to evenly spaced targets from the lowest to the highest mean."""
    lo, hi = min(means.values()), max(means.values())
    chosen = []
    for k in range(n):
        target = lo + (hi - lo) * k / (n - 1)
        chosen.append(min((i for i in sorted(means) if i not in chosen), key=lambda i: (abs(means[i] - target), i)))
    return chosen


def design_pairs(means, anchors, near=2, n_random=2, seed=0, comparisons=None):
    """Sorted unordered pairs: per field the `near` nearest anchors on each side of its mean (the other side fills
    in when one is short) and n_random random fields not yet met. `comparisons` (at least 4) replaces near and
    n_random: near = (comparisons - 2) // 2 anchors a side, the rest random."""
    if comparisons is not None:
        if comparisons < 4:
            raise ValueError("comparisons must be at least 4 (one anchor a side and two random fields)")
        near = (comparisons - 2) // 2
        n_random = comparisons - 2 * near
    opponents = {f: set() for f in means}
    pairs = set()

    def meet(f, x):
        opponents[f].add(x)
        opponents[x].add(f)
        pairs.add(tuple(sorted((f, x))))

    for f in sorted(means):
        cands = [a for a in anchors if a != f]
        below = sorted((a for a in cands if means[a] <= means[f]), key=lambda a: (means[f] - means[a], a))[:near]
        above = sorted((a for a in cands if means[a] > means[f]), key=lambda a: (means[a] - means[f], a))[:near]
        pick = below + above
        rest = sorted((a for a in cands if a not in pick), key=lambda a: (abs(means[a] - means[f]), a))
        pick += rest[:2 * near - len(pick)]
        for a in pick:
            meet(f, a)
        need = n_random
        for x in sorted((x for x in means if x != f), key=lambda x: _digest(f"{seed}:{f}:{x}")):
            if need == 0:
                break
            if x not in opponents[f]:
                meet(f, x)
                need -= 1
    return sorted(pairs)


def orient_single(pairs):
    """{pair: (first, second)}: each pair in one order such that every field is first at most once more or less
    often than second (an Euler orientation of the pair graph: odd-degree fields are joined to a dummy field so
    every field has even degree, then each circuit is walked and each edge oriented along the walk)."""
    adj = defaultdict(list)  # field -> [(neighbour, edge id)], sorted for determinism
    edges = []
    for pair in sorted(pairs):
        e = len(edges)
        edges.append(pair)
        adj[pair[0]].append((pair[1], e))
        adj[pair[1]].append((pair[0], e))
    dummy = None
    for f in sorted(adj):
        if len(adj[f]) % 2:
            dummy = dummy or "\x00dummy"
            e = len(edges)
            edges.append((f, dummy))
            adj[f].append((dummy, e))
            adj[dummy].append((f, e))
    used, out = [False] * len(edges), {}
    for start in sorted(adj):
        stack = [start]
        while stack:
            v = stack[-1]
            while adj[v] and used[adj[v][-1][1]]:
                adj[v].pop()
            if not adj[v]:
                stack.pop()
                continue
            w, e = adj[v].pop()
            used[e] = True
            if dummy not in (v, w):
                out[edges[e]] = (v, w)
            stack.append(w)
    return out


def _card(card, by_id):
    return axes_input(card, by_id)["card"]


def build_pair_batches(cards, means, axis, *, model, prompt_version=1, prompts_dir=DEFAULT_PROMPTS, max_tokens=35000,
                       cache=None, anchors=None, n_anchors=12, seed=0, comparisons=None, single_order=False):
    """Batch parts (each a header line plus task lines, at most max_tokens at 4 bytes a token) for the axis: both
    orders of every designed pair (one balanced order each with single_order), cached (pair, variant) votes skipped.
    means: {field id: mean} for this axis; comparisons: per-field design size (default design when None)."""
    by_id = {c["id"]: c for c in cards}
    anchors = anchors if anchors is not None else choose_anchors(means, n_anchors)
    prefix = read_prefix(TASK_TYPE, prompt_version, prompts_dir)
    header = json.dumps({"kind": "header", "task_type": TASK_TYPE, "model": model, "prompt_version": prompt_version,
                         "prefix": prefix}, sort_keys=True, ensure_ascii=False)
    cost = lambda line: len(line.encode("utf-8")) + 1
    parts, lines, used = [], [], cost(header)
    pairs = design_pairs(means, anchors, seed=seed, comparisons=comparisons)
    k = 1 if single_order else K
    order = orient_single(pairs) if single_order else None
    for pair in pairs:
        cp = {i: _card(by_id[i], by_id) for i in pair}
        h = pair_hash(axis, list(cp.values()))
        for v in range(k):
            if cache is not None and cache.has(TASK_TYPE, h, model, prompt_version, v):
                continue
            a, b = order[pair] if single_order else presented(pair, h, v)
            line = canonical_json({
                "kind": "task", "task_id": f"{h[:16]}-{'s' if single_order else 'v'}{v}", "task_type": TASK_TYPE,
                "prompt_version": prompt_version, "input_hash": h, "variant": v, "k": k,
                "input": {"axis": axis, "toward": TOWARD[axis], "a": cp[a], "b": cp[b]}, "allowed_verdicts": VERDICTS})
            if lines and used + cost(line) > max_tokens * 4:
                parts.append([header] + lines)
                lines, used = [], cost(header)
            lines.append(line)
            used += cost(line)
    if lines:
        parts.append([header] + lines)
    return parts


def write_pair_batches(parts, out_dir, axis, prompt_version=1, tag=None):
    """Write the parts as axes_pair.<axis>.<tag>.part<n>.jsonl; the tag defaults to v<prompt_version>."""
    tag = tag or f"v{prompt_version}"
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for n, lines in enumerate(parts):
        p = out / f"{TASK_TYPE}.{axis}.{tag}.part{n}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    return paths


def comparisons_from_answers(answers, tasks):
    """(first, second, outcome) for each answer: the presented slots' field ids and "a", "b" or "tie"."""
    by_key = {(t["input_hash"], t["variant"]): t for t in tasks}
    out = []
    for a in answers:
        t = by_key.get((a["input_hash"], a["variant"]))
        if t is None:
            continue
        if a["verdict"] not in VERDICTS:
            raise ValueError(f"not an axes_pair verdict: {a['verdict']!r}")
        out.append((t["input"]["a"]["id"], t["input"]["b"]["id"], a["verdict"]))
    return out
