"""Circular seriation (LI.60): the global ring order of the coarse fields, as a comparison arm against the shipped order (A) and the
force simulation (B, `layout_sim`).

Objective: over circular orders of the n fields, minimise
    cost = -sum of combined similarity of circularly adjacent fields + lambda x sum of displacement,
where the displacement of a field is the circular distance between the axes-prior angle and the angle of the ring slot it
is placed in. The slots are the shipped order's tiled slice centres (a field at ring position p takes slot p), so the ring
keeps the shipped geometry and the axes stay the prior, as in the force simulation. Constraints: displacement within the guard
(`layout_sim.seriation_guard`) and sectors split no more than in the shipped order. The order enters `basemap.build` as unit
axes vectors (like `layout_sim.tiled_slices`), so widths and radii are unchanged.

Heuristic (deterministic): the shipped order and further starts (greedy chains, seeded local double-bridge kicks of the best
order so far) each improved by first-improvement 2-opt and Or-opt on a window of positions, with slot rotations; the best
feasible cost wins. A slot is a position, so a move re-prices every field it shifts. Nothing here changes the default build.
"""
import json
import math
import random
from pathlib import Path

import numpy as np

from .governed import governed
from .layout import circ_diff
from .layout_sim import adjacent_pairs, coherence, fragmentation, main_sector, signals, wrap  # noqa: F401

ROOT = Path(__file__).resolve().parent.parent
VERSION = "seriation_v0"
WINDOW = 40  # positions a move may span (the guard keeps larger moves infeasible in practice)
BIG = 10.0  # cost of one guard violation: more than any similarity gain, so a move never creates one
EPS = 1e-12

ARTS_RELIGION = ("c.arts_humanities_studies", "c.visual_arts", "c.performing_arts", "c.religion_worship", "c.religious_community")
MATH_STATS = ("c.mathematics", "c.statistics_data")
AGRICULTURE = ("c.horticulture_farming", "c.agricultural_science", "c.agri_forestry_fishing_work", "c.fishing_hunting_foraging")
HOUSING = "c.housing_search"


def named_outliers(order):
    """The undesired adjacencies of LI.55 in a ring order: arts or religion fields beside mathematics or statistics, and housing
    beside an agriculture field. Returns {"arts_religion_math_stats": [(a, b)], "housing_agriculture": [(a, b)]}."""
    arts = [(a, b) for a, b in adjacent_pairs(order)
            if (a in ARTS_RELIGION and b in MATH_STATS) or (b in ARTS_RELIGION and a in MATH_STATS)]
    house = [(a, b) for a, b in adjacent_pairs(order)
             if (a == HOUSING and b in AGRICULTURE) or (b == HOUSING and a in AGRICULTURE)]
    return {"arts_religion_math_stats": arts, "housing_agriculture": house}


# ---- the optimiser (indices only) ----

def price(D, lam, guard):
    """Cost matrix C[i, p] of putting field i in slot p: lambda x displacement, plus BIG when the displacement exceeds the guard
    (more than any similarity gain, so a move never creates a violation; independent of lambda, so it holds at lambda 0)."""
    D = np.asarray(D, float)
    return lam * D + np.where(D > guard + 1e-9, BIG, 0.0)


def cost(order, S, C):
    o = np.asarray(order)
    return float(-S[o, np.roll(o, -1)].sum() + C[o, np.arange(len(o))].sum())


def _window_delta(o, lo, hi, new, S, C):
    """Cost change of replacing positions lo..hi (inclusive, not the whole ring) of `o` by `new` (same fields)."""
    n = len(o)
    left, right = o[(lo - 1) % n], o[(hi + 1) % n]
    old = o[lo:hi + 1]
    seq_o = [left, *old, right]
    seq_n = [left, *new, right]
    ds = sum(S[seq_n[k]][seq_n[k + 1]] for k in range(len(seq_n) - 1)) - sum(S[seq_o[k]][seq_o[k + 1]] for k in range(len(seq_o) - 1))
    dd = sum(C[f][lo + k] for k, f in enumerate(new)) - sum(C[f][lo + k] for k, f in enumerate(old))
    return -ds + dd


def _splits(order, sector_of, ids):
    return fragmentation([ids[i] for i in order], sector_of)["sectors_split"]


def improve(order, S, C, split_of, split_limit, window=WINDOW):
    """First-improvement 2-opt (reversal of a window of positions), Or-opt (move a segment of 1-3 fields, optionally reversed, within
    the window) and slot rotations until none improves. A move is rejected when it would split more sectors than
    max(split_limit, the current order's). `split_of(order)` counts split sectors."""
    o = list(map(int, order))
    n = len(o)
    S = S.tolist() if isinstance(S, np.ndarray) else S
    Cl = C.tolist() if isinstance(C, np.ndarray) else C
    cap = max(split_limit, split_of(o))
    improved = True
    while improved:
        improved = False
        for a in range(n):
            for b in range(a + 1, min(n, a + window)):
                if a == 0 and b == n - 1:
                    continue
                if _window_delta(o, a, b, o[a:b + 1][::-1], S, Cl) < -EPS:
                    cand = o[:a] + o[a:b + 1][::-1] + o[b + 1:]
                    if split_of(cand) <= max(cap, split_of(o)):
                        o, improved = cand, True
        for L in (1, 2, 3):
            for s in range(n - L + 1):
                seg = o[s:s + L]
                for t in range(max(0, s - window), min(n, s + L + window)):
                    if s <= t < s + L:
                        continue
                    for rev in (False, True) if L > 1 else (False,):
                        piece = seg[::-1] if rev else seg
                        if t > s:  # move forward: block o[s..t] becomes o[s+L..t] + seg
                            lo, hi, new = s, t, o[s + L:t + 1] + piece
                        else:  # move backward: block o[t..s+L-1] becomes seg + o[t..s-1]
                            lo, hi, new = t, s + L - 1, piece + o[t:s]
                        if lo == 0 and hi == n - 1:
                            continue
                        if _window_delta(o, lo, hi, new, S, Cl) < -EPS:
                            cand = o[:lo] + new + o[hi + 1:]
                            if split_of(cand) <= max(cap, split_of(o)):
                                o, improved = cand, True
                                break
                    else:
                        continue
                    break
        base = _cost(o, S, Cl)
        for r in [x for x in range(-6, 7) if x]:
            cand = o[r:] + o[:r]  # rotate by r positions
            if _cost(cand, S, Cl) < base - EPS and split_of(cand) <= max(cap, split_of(o)):
                o, improved, base = cand, True, _cost(cand, S, Cl)
    return o


def _cost(o, S, Cl):
    n = len(o)
    return -sum(S[o[k]][o[(k + 1) % n]] for k in range(n)) + sum(Cl[o[k]][k] for k in range(n))


def greedy(S, C, first):
    """Greedy chain: position p takes the unused field with the least -similarity to the previous one + lambda x displacement."""
    n = len(S)
    used = np.zeros(n, bool)
    o = [first]
    used[first] = True
    for p in range(1, n):
        c = -S[o[-1]] + C[:, p]
        c = np.where(used, np.inf, c)
        j = int(np.argmin(c))
        o.append(j)
        used[j] = True
    return o


def kick(order, rng, span=30):
    """Local double-bridge: A B C D -> A C B D inside a window of at most `span` positions."""
    n = len(order)
    span = min(span, n)
    lo = rng.randrange(0, n - span + 1)
    cuts = sorted(rng.sample(range(lo + 1, lo + span), 3))
    i, j, k = cuts
    return list(order[:lo]) + list(order[lo:i]) + list(order[j:k]) + list(order[i:j]) + list(order[k:])


def seriate(S, D, start, lam=None, guard=None, restarts=None, seed=None, split_of=None, split_limit=None, log=None):
    """The best order found: indices over the rows of `S`; `D[i, p]` the displacement of field i in slot p; `start` the prior order
    (the shipped one). Deterministic. Returns (order, info)."""
    lam = governed("layout_sim.seriation_lambda") if lam is None else lam
    guard = governed("layout_sim.seriation_guard") if guard is None else guard
    restarts = governed("layout_sim.seriation_restarts") if restarts is None else restarts
    seed = governed("layout_sim.seriation_kick_seed") if seed is None else seed
    S, D = np.asarray(S, float), np.asarray(D, float)
    n = len(S)
    C = price(D, lam, guard)
    over = lambda o: int((D[o, np.arange(len(o))] > guard + 1e-9).sum())
    split_of = split_of or (lambda o: 0)
    split_limit = split_of(list(start)) if split_limit is None else split_limit
    rng = random.Random(seed)
    runs = []

    def run(name, o0):
        o = improve(o0, S, C, split_of, split_limit)
        feasible = split_of(o) <= split_limit and over(o) <= over(list(start))
        runs.append({"start": name, "cost": cost(o, S, C), "feasible": bool(feasible), "order": o})
        return o

    run("shipped", list(start))
    firsts = [int(i) for i in np.argsort(D[:, 0], kind="stable")[:3]]
    for g in range(min(3, restarts)):
        run(f"greedy{g}", greedy(S, C, firsts[g]))
    for k in range(max(0, restarts - 3)):
        best = min((r for r in runs if r["feasible"]), key=lambda r: r["cost"])
        run(f"kick{k}", kick(best["order"], rng))
    ok = [r for r in runs if r["feasible"]]
    best = min(ok, key=lambda r: (r["cost"], r["start"]))
    info = {"lambda": lam, "guard": guard, "split_limit": split_limit, "cost": best["cost"], "best_start": best["start"],
            "runs": [{k: v for k, v in r.items() if k != "order"} for r in runs]}
    return best["order"], info


# ---- on the repository's data ----

def context(root=ROOT, params=None):
    """Everything the arms share: cards, signals, prior angles, the shipped (axes) tiled build and a tiling function."""
    from .render import basemap as bm
    from .fine.cards import coarsen_rows, load_fine
    from .packs import is_sector
    from .relatedness import judged_signal, read_rows
    root = Path(root)
    cards = bm.load_cards(root / "data/coarse/seed_v3.jsonl")
    fine_cards = load_fine(root / "data/fine/fine_v1.jsonl")
    by = {c["id"]: c for c in cards}
    axes = bm.axes_means(cards, root / "data/answers/axes.jsonl", [root / f"data/coarse/seed_v{v}.jsonl" for v in (0, 1, 2)],
                         [root / "data/answers/axis_at.jsonl", root / "data/answers/axis_pg.jsonl"])
    comem = bm.read_jsonl(root / "data/coarse/comembership_v0.jsonl")
    rows = coarsen_rows(bm.evidence_rows(root), fine_cards)
    version = cards[0]["basemap_version"]
    base = bm.build(cards, axes, rows, version, log=[])
    prior, _source, _ = bm.place_angles(cards, axes)
    judged = judged_signal(read_rows(root / "data/answers/relatedness.jsonl"))
    sig = signals(cards, fine_cards, comem, params, judged=judged, log=[])
    fields = sig.ids
    order_of = lambda b: [i for i, _ in sorted(((i, s.start) for i, s in b.slices.items() if s.ring == "field"), key=lambda t: t[1])]

    def tiled(angles):
        ax = {i: {**a, "abstract_tangible": math.cos(math.radians(angles[i])), "personal_global": math.sin(math.radians(angles[i]))}
              for i, a in axes.items()}
        return bm.build(cards, ax, rows, version, log=[])

    return {"cards": cards, "by": by, "sig": sig, "fields": fields, "prior": {i: prior[i] for i in fields}, "base": base,
            "shipped_order": order_of(base), "tiled": tiled, "order_of": order_of,
            "sector_of": {i: main_sector(i, by) for i in fields}, "is_sector": is_sector}


def stability(slices, order, ctx):
    fields = ctx["fields"]
    sh = np.array([circ_diff(slices[i].angle, ctx["prior"][i]) for i in fields])
    return {"mean_shift": float(sh.mean()), "p95_shift": float(np.percentile(sh, 95)), "max_shift": float(sh.max()),
            "fragmentation": fragmentation(order, ctx["sector_of"])}


def run_arm(ctx, lam=None, guard=None, restarts=None):
    """Seriation on the context: ({field id: angle}, ring order after tiling, info). The slots are the shipped slice centres."""
    fields, sig = ctx["fields"], ctx["sig"]
    ix = {i: n for n, i in enumerate(fields)}
    ship = ctx["shipped_order"]
    slots = [ctx["base"].slices[i].angle % 360.0 for i in ship]
    D = np.array([[circ_diff(slots[p], ctx["prior"][i]) for p in range(len(ship))] for i in fields])
    split_of = lambda o: fragmentation([fields[k] for k in o], ctx["sector_of"])["sectors_split"]
    best, info = seriate(sig.combined, D, [ix[i] for i in ship], lam, guard, restarts, split_of=split_of)
    angles = {fields[k]: slots[p] for p, k in enumerate(best)}
    tiled = ctx["tiled"](angles)
    return angles, ctx["order_of"](tiled), tiled, info


def compute(root=ROOT, lam=None, guard=None, restarts=None, sweep=()):
    """Arms A (shipped), B (force simulation), C (seriation) on one set of signals; the result dict (`data/coarse/seriation_v0.json`)."""
    from . import layout_sim
    ctx = context(root)
    sig, by = ctx["sig"], ctx["by"]
    sim = layout_sim.compute(root, holdout=False)
    order_a, order_b = sim["ring_order"]["before"], sim["ring_order"]["after"]
    assert order_a == ctx["shipped_order"]
    angles, order_c, tiled, info = run_arm(ctx, lam, guard, restarts)
    arms = {"A": order_a, "B": order_b, "C": order_c}
    slices_b = layout_sim.tiled_slices(sim, root)
    slices = {"A": ctx["base"].slices, "B": slices_b, "C": tiled.slices}
    out = {"version": VERSION, "info": info, "angles": {**{i: round(a, 4) for i, a in angles.items()},
                                                          **{i: round(s.axes_angle, 4) for i, s in tiled.slices.items() if s.ring == "sector"}},
           "order": order_c, "ring_order": arms, "arms": {}}
    for name, order in arms.items():
        out["arms"][name] = {"coherence": coherence(order, sig), "stability": stability(slices[name], order, ctx),
                             "named_outliers": {k: [list(p) for p in v] for k, v in named_outliers(order).items()}}
    if sweep:
        out["sensitivity"] = {}
        for f in sweep:
            lam_f = governed("layout_sim.seriation_lambda") * f if lam is None else lam * f
            a, o, t, inf = run_arm(ctx, lam_f, guard, restarts)
            out["sensitivity"][str(f)] = {"lambda": lam_f, "coherence": coherence(o, sig), "stability": stability(t.slices, o, ctx),
                                          "named_outliers": {k: [list(p) for p in v] for k, v in named_outliers(o).items()}}
    return out


def write(result, path):
    Path(path).write_text(json.dumps(result, sort_keys=True, indent=1) + "\n", encoding="utf-8")
