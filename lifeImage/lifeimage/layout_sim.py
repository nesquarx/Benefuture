"""Placement by a polar force simulation (LI.55, LI.58): the coarse fields sort themselves so thematic neighbours sit
together while the prior (the judged axes, later the previous layout) stays the stability term of LI.25.

State per field: an angle on the circle and a radius. Forces:
- a weak angular spring to the prior angle (`layout_sim.k_polar`; the angle may bend a good deal) and a strict radial spring to
  the prior radius, the judged one of LI.26 (`layout_sim.k_radial`);
- attraction, a Huber pull (linear to `pull_cap` degrees, constant beyond) along every pair with signal, whose strength is the
  weighted sum of the sources (`signals`): overlap links, field-to-field upstream links, learnt co-membership (conditional p,
  both directions, max; rows with support below `support_floor` are not signal), shared fine children, textual nearness (TF-IDF
  cosine, deterministic, no network); and the pull of a field toward the circular mean of its sector (upstream links);
- short-range repulsion between fields closer than the sum of their half-widths (pressure widths) plus `rep_floor`.
Two phases (LI.58): first the angles settle with repulsion off (springs and attraction only), then repulsion switches on so
the slices tessellate. Dynamics are overdamped (each step moves a field by its force over its local stiffness, half a step),
deterministic: no randomness, fixed iteration counts with a convergence tolerance, ties by index.

Sectors have no axes of their own (LI.24), so they are not independent nodes: a sector sits at the circular mean of the fields
under it, recomputed each iteration (its pull on its fields is the sector attraction) and finally by `basemap.build`.

`update_layout` is the reusable step: cards' signals and a prior layout in, a layout and diagnostics out. The first version takes
the axes as the prior; a later version takes the previous layout, so the prior spring is the stability term (LI.25). `compute`
runs it on the repository's data and measures the result against the axes placement; nothing here changes the default build.
Without any attraction the prior order is returned (the simulation invents no structure).
"""
import math
import re
from collections import defaultdict
from dataclasses import dataclass, field, replace
from pathlib import Path

import numpy as np

from .governed import governed
from .layout import circ_diff
from .packs import is_sector

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ("overlap", "upstream", "comembership", "fine", "text")
STEP = 0.5  # fraction of the local force-over-stiffness step taken per iteration (overdamped)
SETTLE_ITERATIONS = 300  # phase 1: repulsion off
TESSELLATE_ITERATIONS = 300  # phase 2: repulsion on
TOLERANCE = 1e-4  # degrees: a phase stops when no field moves more
VERSION = "layout_sim_v0"
STOP = frozenset("a an the and or of in on to for with by at from as is are be this that it its their about into over under "
                 "between across using use used other than more such also not any all can may".split())


@dataclass(frozen=True)
class Params:
    k_polar: float = None
    k_radial: float = None
    pull_cap: float = None
    k_repel: float = None
    rep_floor: float = None
    shift_max: float = None
    radial_pull: float = None
    weights: dict = None  # source name -> weight
    w_sector: float = None
    support_floor: float = None
    weight_cap: float = None
    text_floor: float = None
    text_topk: int = None
    inherited_stiffness: float = None

    def resolved(self):
        g = lambda n: governed("layout_sim." + n)
        w = {s: g("w_" + {"fine": "fine", "text": "text"}.get(s, s)) for s in SOURCES}
        base = {n: g(n) for n in ("k_polar", "k_radial", "pull_cap", "k_repel", "rep_floor", "shift_max", "radial_pull",
                                  "w_sector", "support_floor", "weight_cap", "text_floor", "text_topk", "inherited_stiffness")}
        base["weights"] = w
        return Params(**{**base, **{k: v for k, v in self.__dict__.items() if v is not None}})


def wrap(d):
    return (d + 180.0) % 360.0 - 180.0


def _check(prior, attract, widths):
    prior, attract, widths = np.asarray(prior, float), np.asarray(attract, float), np.asarray(widths, float)
    n = len(prior)
    if prior.ndim != 1 or attract.shape != (n, n) or widths.shape != (n,):
        raise ValueError("prior, attract and widths must be shaped (n,), (n, n) and (n,)")
    if not (np.isfinite(prior).all() and np.isfinite(attract).all() and np.isfinite(widths).all()):
        raise ValueError("non-finite input")
    if (attract < 0).any() or not np.allclose(attract, attract.T):
        raise ValueError("attraction must be symmetric and non-negative")
    if (widths <= 0).any():
        raise ValueError("widths must be positive")
    return prior, attract, widths


def attraction_scale(attract, extra=None):
    """1 / the median, over fields with any attraction, of a field's total attraction (pairs plus `extra`, the per-field
    group strengths), so the polar and repulsion stiffnesses are relative to the median field's pull."""
    tot = np.asarray(attract, float).sum(1) + (0 if extra is None else np.asarray(extra, float))
    pos = tot[tot > 0]
    return 1.0 / float(np.median(pos)) if len(pos) else 1.0


def normalise_attraction(attract, extra=None):
    return np.asarray(attract, float) * attraction_scale(attract, extra)


def _circ_mean(angles, weights):
    x = float(np.sum(weights * np.cos(np.radians(angles))))
    y = float(np.sum(weights * np.sin(np.radians(angles))))
    return None if math.hypot(x, y) < 1e-9 else math.degrees(math.atan2(y, x))


def relax(prior, attract, widths, groups=(), stiffness=None, *, k_polar=None, pull_cap=None, k_repel=None, rep_floor=None,
          shift_max=None, settle=SETTLE_ITERATIONS, tessellate=TESSELLATE_ITERATIONS):
    """Angles (degrees, array) after the two phases. `attract` is symmetric, non-negative, already normalised
    (`normalise_attraction`); `groups` [(member index list, member weights, strength)] pull members toward their circular
    mean; `stiffness` per-field multiplier of the polar spring. Each field stays within `shift_max` of its prior."""
    prior, attract, widths = _check(prior, attract, widths)
    g = lambda n, v: governed("layout_sim." + n) if v is None else v
    k_polar, cap, k_rep = g("k_polar", k_polar), g("pull_cap", pull_cap), g("k_repel", k_repel)
    floor, smax = g("rep_floor", rep_floor), g("shift_max", shift_max)
    n = len(prior)
    k = np.full(n, k_polar) * (1.0 if stiffness is None else np.asarray(stiffness, float))
    rest = (widths[:, None] + widths[None, :]) / 2 + floor
    order = np.arange(n)
    tie = np.sign(order[None, :] - order[:, None]).astype(float)
    delta = np.zeros(n)
    for repel, iters in ((0.0, settle), (k_rep, tessellate)):
        for _ in range(iters):
            th = prior + delta
            d = wrap(th[None, :] - th[:, None])  # d[i, j]: from i to j
            force = -k * delta + (attract * np.clip(d, -cap, cap)).sum(1)
            stiff = k + attract.sum(1)
            for idx, w, strength in groups:
                idx, w = np.asarray(idx, int), np.asarray(w, float)
                if not len(idx):
                    continue
                centre = _circ_mean(th[idx], w)
                if centre is not None:
                    force[idx] += strength * w * np.clip(wrap(centre - th[idx]), -cap, cap)
                stiff[idx] += strength * w
            if repel > 0:
                depth = rest - np.abs(d)
                near = (depth > 0) & (order[:, None] != order[None, :])
                sign = np.where(d == 0, tie, np.sign(d))
                force += -(repel * depth * sign * near).sum(1)
                stiff += repel * near.sum(1)
            step = STEP * force / stiff
            new = np.clip(delta + step, -smax, smax)
            moved = float(np.abs(new - delta).max()) if n else 0.0
            delta = new
            if moved < TOLERANCE:
                break
    return (prior + delta) % 360.0


def relax_radius(prior, attract, *, k_radial=None, radial_pull=None):
    """Radii after the strict radial spring and a small radial share of the attraction (a diagnostic: the build keeps the judged
    radius). Closed form of the fixed point: each radius is the blend of its prior and its weighted neighbours' radii."""
    prior = np.asarray(prior, float)
    kr = governed("layout_sim.k_radial") if k_radial is None else k_radial
    pull = governed("layout_sim.radial_pull") if radial_pull is None else radial_pull
    r = prior.copy()
    for _ in range(200):
        new = (kr * prior + pull * attract @ r) / (kr + pull * attract.sum(1))
        if float(np.abs(new - r).max()) < 1e-9:
            break
        r = new
    return r


# ---- signals ----

def _tokens(text):
    out = []
    for t in re.findall(r"[a-z]+", text.lower()):
        if len(t) > 2 and t not in STOP:
            out.append(t[:-1] if t.endswith("s") and not t.endswith("ss") and len(t) > 3 else t)
    return out


def _tfidf_cosine(docs):
    toks = [_tokens(d) for d in docs]
    vocab = sorted({t for ts in toks for t in ts})
    col = {t: i for i, t in enumerate(vocab)}
    x = np.zeros((len(docs), len(vocab)))
    for r, ts in enumerate(toks):
        for t in ts:
            x[r, col[t]] += 1
    df = (x > 0).sum(0)
    x = np.where(x > 0, 1 + np.log(np.where(x > 0, x, 1)), 0) * (np.log((1 + len(docs)) / (1 + df)) + 1)
    norm = np.linalg.norm(x, axis=1, keepdims=True)
    x = x / np.where(norm == 0, 1, norm)
    c = x @ x.T
    np.fill_diagonal(c, 0.0)
    return c


def _sym_max(m):
    return np.maximum(m, m.T)


def _normalised(m, cap):
    pos = m[m > 0]
    if not len(pos):
        return m
    return np.minimum(m / float(np.median(pos)), cap)


@dataclass
class Signals:
    ids: list  # field ids, sorted
    sources: dict  # source -> symmetric matrix, each source's weights over its median, capped (unweighted)
    combined: np.ndarray  # sum of source weight * source matrix
    groups: list  # [(member indices, member weights, sector id)]
    coverage: dict = field(default_factory=dict)
    params: Params = None


def signals(cards, fine_cards, comem_rows, params=None):
    """The attraction between fields from every source, per-source coverage, and the sector groups."""
    P = (params or Params()).resolved()
    fields = sorted(c["id"] for c in cards if not is_sector(c))
    ix = {i: n for n, i in enumerate(fields)}
    n = len(fields)
    by = {c["id"]: c for c in cards}
    raw = {s: np.zeros((n, n)) for s in SOURCES}
    for c in cards:
        if c["id"] not in ix:
            continue
        for l in c["links"]:
            if l["id"] in ix and l["id"] != c["id"]:
                key = "overlap" if l["rel"] == "overlap" else "upstream" if l["rel"] == "upstream" else None
                if key:
                    a, b = ix[c["id"]], ix[l["id"]]
                    raw[key][a, b] = max(raw[key][a, b], l["weight"])
    directed = np.zeros((n, n))
    for r in comem_rows:
        if r["a"] in ix and r["b"] in ix and r["support"] >= P.support_floor:
            a, b = ix[r["a"]], ix[r["b"]]
            directed[a, b] = max(directed[a, b], r["p"])
    raw["comembership"] = directed
    for f in fine_cards:
        kin = sorted({ix[l["id"]] for l in f["links"] if l["id"] in ix})
        for a in range(len(kin)):
            for b in range(a + 1, len(kin)):
                raw["fine"][kin[a], kin[b]] += 1
                raw["fine"][kin[b], kin[a]] += 1
    docs = []
    kids = defaultdict(list)
    for f in fine_cards:
        for l in f["links"]:
            if l["id"] in ix:
                kids[l["id"]].append(f["label"])
    for i in fields:
        c = by[i]
        docs.append(" ".join([c["label"], c["label"], *[a["text"] for a in c.get("aliases", [])], c["description"], *sorted(kids[i])]))
    cos = _tfidf_cosine(docs)
    keep = np.zeros((n, n), bool)
    for r in range(n):
        top = np.argsort(-cos[r], kind="stable")[:P.text_topk]
        keep[r, top] = True
    raw["text"] = np.where((cos >= P.text_floor) & (keep | keep.T), cos, 0.0)
    src = {s: _normalised(_sym_max(m), P.weight_cap) for s, m in raw.items()}
    combined = sum(P.weights[s] * src[s] for s in SOURCES)
    np.fill_diagonal(combined, 0.0)
    groups = []
    for c in cards:
        if is_sector(c):
            mem = sorted((ix[k["id"]], l["weight"]) for k in cards if k["id"] in ix for l in k["links"]
                         if l["rel"] == "upstream" and l["id"] == c["id"])
            if mem:
                groups.append(([m for m, _ in mem], [w for _, w in mem], c["id"]))
    pair_any = np.zeros((n, n), int)
    for s in SOURCES:
        pair_any += src[s] > 0
    cov = {}
    iu = np.triu_indices(n, 1)
    for s in SOURCES:
        m = src[s] > 0
        total = int(m[iu].sum())
        cov[s] = {"pairs": total, "fields": int(m.any(1).sum()),
                  "pair_share": total / len(iu[0]) if len(iu[0]) else 0.0,
                  "pairs_also_in_another_source": int(((pair_any > 1) & m)[iu].sum())}
    cov["any"] = {"pairs": int((pair_any > 0)[iu].sum()), "fields": int((pair_any > 0).any(1).sum()),
                  "pairs_in_two_or_more_sources": int((pair_any > 1)[iu].sum())}
    sig = Signals(fields, src, combined, groups, {k: v for k, v in cov.items() if k != "any"}, P)
    sig.any_coverage = cov["any"]
    return sig


# ---- the reusable step ----

def update_layout(sig, prior_angles, prior_radius, widths, params=None, stiffness=None):
    """The layout step: `sig` (`signals`), the prior layout (angle and radius per field id, the axes and judged radius now, the
    previous version's later), pressure `widths` per field id. Returns {"angles", "radius", "diagnostics"}; the angular prior
    spring is the stability term of LI.25 (weak), the radial one is strict."""
    P = (params or sig.params or Params()).resolved()
    ids = sig.ids
    prior = np.array([prior_angles[i] for i in ids], float)
    r0 = np.array([prior_radius[i] for i in ids], float)
    w = np.array([widths[i] for i in ids], float)
    extra = np.zeros(len(ids))
    for idx, ws, _ in sig.groups:
        extra[idx] += P.w_sector * np.asarray(ws)
    scale = attraction_scale(sig.combined, extra)
    attract = sig.combined * scale
    groups = [(idx, ws, P.w_sector * scale) for idx, ws, _ in sig.groups]
    ang = relax(prior, attract, w, groups, stiffness, k_polar=P.k_polar, pull_cap=P.pull_cap, k_repel=P.k_repel,
                rep_floor=P.rep_floor, shift_max=P.shift_max)
    rad = relax_radius(r0, attract, k_radial=P.k_radial, radial_pull=P.radial_pull)
    shift = np.array([circ_diff(a, p) for a, p in zip(ang, prior)])
    diag = {"attraction_scale": scale, "mean_state_shift": float(shift.mean()), "max_state_shift": float(shift.max()),
            "at_shift_limit": int((shift >= P.shift_max - 1e-6).sum()), "max_radius_drift": float(np.abs(rad - r0).max())}
    return {"angles": dict(zip(ids, ang.tolist())), "radius": dict(zip(ids, rad.tolist())), "diagnostics": diag}


# ---- measurement ----

def adjacent_pairs(order):
    return [(order[k], order[(k + 1) % len(order)]) for k in range(len(order))]


def coherence(order, sig, source=None):
    """Mean similarity of circularly adjacent fields, the share with no signal, and the mean circular rank distance of the pairs
    with signal; `source` restricts to one source."""
    ix = {i: n for n, i in enumerate(sig.ids)}
    m = sig.combined if source is None else sig.sources[source]
    vals = [m[ix[a], ix[b]] for a, b in adjacent_pairs(order)]
    n = len(order)
    pos = np.array([order.index(i) for i in sig.ids])
    gap = np.abs(pos[:, None] - pos[None, :])
    rank = np.minimum(gap, n - gap)
    iu = np.triu_indices(n, 1)
    has = m[iu] > 0
    return {"mean_similarity": float(np.mean(vals)), "no_signal_share": float(np.mean([v == 0 for v in vals])),
            "mean_rank_distance": float(rank[iu][has].mean()) if has.any() else None}


def main_sector(cid, by, seen=()):
    ups = sorted((l for l in by[cid]["links"] if l["rel"] == "upstream"), key=lambda l: (-l["weight"], l["id"]))
    for l in ups:
        if l["id"].startswith("s."):
            return l["id"]
    for l in ups:
        if l["id"] in by and l["id"] not in seen and (s := main_sector(l["id"], by, seen + (cid,))):
            return s
    return None


def fragmentation(order, sector_of):
    """Runs of one main sector around the circular field order: {"sectors_split", "extra_runs", "runs"}."""
    seq = [sector_of[i] for i in order]
    runs = defaultdict(int)
    for k, s in enumerate(seq):
        if s != seq[k - 1]:
            runs[s] += 1
    runs = {s: r or 1 for s, r in runs.items()}
    for s in set(seq) - set(runs):
        runs[s] = 1
    return {"sectors_split": sum(r > 1 for r in runs.values()), "extra_runs": sum(r - 1 for r in runs.values()),
            "runs": sum(runs.values())}


NAMED = {"arts": "arts", "religion": "relig", "mathematics": "mathematics", "statistics": "statistics",
         "housing": "housing", "agriculture": "agri"}


def _neighbours(order, i, k=2):
    n, p = len(order), order.index(i)
    return [order[(p + o) % n] for o in [x for x in range(-k, k + 1) if x]]


def compute(root=ROOT, params=None, holdout=True):
    """The simulation on the repository's coarse map, measured against the axes placement. Returns the result dict
    (`data/coarse/layout_sim_v0.json`)."""
    from .render import basemap as bm
    from .fine.cards import coarsen_rows, load_fine
    root = Path(root)
    cards = bm.load_cards(root / "data/coarse/seed_v3.jsonl")
    fine_cards = load_fine(root / "data/fine/fine_v1.jsonl")
    by = {c["id"]: c for c in cards}
    axes = bm.axes_means(cards, root / "data/answers/axes.jsonl", [root / f"data/coarse/seed_v{v}.jsonl" for v in (0, 1, 2)],
                         [root / "data/answers/axis_at.jsonl", root / "data/answers/axis_pg.jsonl"])
    comem = bm.read_jsonl(root / "data/coarse/comembership_v0.jsonl")
    rows = coarsen_rows(bm.evidence_rows(root), fine_cards)
    log = []
    base = bm.build(cards, axes, rows, cards[0]["basemap_version"], log=log)
    prior, source, _ = bm.place_angles(cards, axes)
    fields = sorted(i for i in by if not is_sector(by[i]))
    bands, _ = bm.radial_bands(cards, {i: "sector" if is_sector(by[i]) else "field" for i in by}, log)
    prior_r = {i: (bands[i][0] + bands[i][1]) / 2 for i in fields}
    widths = {i: base.slices[i].width for i in fields}
    sig = signals(cards, fine_cards, comem, params)
    P = sig.params
    stiff = np.array([1.0 if source[i] == "axes" else P.inherited_stiffness for i in sig.ids])
    out = update_layout(sig, {i: prior[i] for i in fields}, prior_r, widths, P, stiff)

    def tiled(angles):
        ax = {i: {**axes[i], "abstract_tangible": math.cos(math.radians(angles[i])),
                  "personal_global": math.sin(math.radians(angles[i]))} for i in fields}
        return bm.build(cards, ax, rows, cards[0]["basemap_version"], log=[])

    after = tiled(out["angles"])
    order_of = lambda b: [i for i, _ in sorted(((i, s.start) for i, s in b.slices.items() if s.ring == "field"), key=lambda t: t[1])]
    before_order, after_order = order_of(base), order_of(after)
    sector_of = {i: main_sector(i, by) for i in fields}
    shifts = lambda b: np.array([circ_diff(b.slices[i].angle, prior[i]) for i in fields])
    sb, sa = shifts(base), shifts(after)
    state = np.array([circ_diff(out["angles"][i], prior[i]) for i in fields])
    stability = {
        "before": {"mean_shift": float(sb.mean()), "p95_shift": float(np.percentile(sb, 95)), "max_shift": float(sb.max())},
        "after": {"mean_shift": float(sa.mean()), "p95_shift": float(np.percentile(sa, 95)), "max_shift": float(sa.max())},
        "mean_state_shift": float(state.mean()), "max_state_shift": float(state.max()),
        "at_shift_limit": out["diagnostics"]["at_shift_limit"],
        "fragmentation": {"before": fragmentation(before_order, sector_of), "after": fragmentation(after_order, sector_of)},
    }
    coh = {"before": coherence(before_order, sig), "after": coherence(after_order, sig)}
    per_source = {s: {"before": coherence(before_order, sig, s), "after": coherence(after_order, sig, s)} for s in SOURCES}
    held = {}
    if holdout:
        for s in SOURCES:
            w = dict(sig.params.weights)
            w[s] = 0.0
            p2 = replace(sig.params, weights=w)
            s2 = signals(cards, fine_cards, comem, p2)
            o2 = update_layout(s2, {i: prior[i] for i in fields}, prior_r, widths, p2, stiff)
            order2 = [i for i, _ in sorted(o2["angles"].items(), key=lambda t: (t[1], t[0]))]
            order0 = [i for i, _ in sorted(((i, prior[i]) for i in fields), key=lambda t: (t[1], t[0]))]
            held[s] = {"before": coherence(order0, sig, s), "after_without_source": coherence(order2, sig, s),
                       "after_with_source": per_source[s]["after"]}
    named = {}
    for name, key in NAMED.items():
        for i in fields:
            if key in i:
                named[i] = {"group": name, "label": by[i]["label"],
                            "before": [{"id": j, "label": by[j]["label"]} for j in _neighbours(before_order, i)],
                            "after": [{"id": j, "label": by[j]["label"]} for j in _neighbours(after_order, i)]}
    ix = {i: n for n, i in enumerate(sig.ids)}
    for i, d in named.items():
        for side in ("before", "after"):
            near = [ix[j["id"]] for j in d[side][1:3]]  # the two immediate neighbours (offsets -1 and +1)
            d[side + "_similarity"] = float(np.mean([sig.combined[ix[i], j] for j in near]))
    movers = sorted(fields, key=lambda i: (-circ_diff(out["angles"][i], prior[i]), i))[:25]
    movers = [{"id": i, "label": by[i]["label"], "axes_angle": round(prior[i], 2), "angle": round(out["angles"][i], 2),
               "shift": round(circ_diff(out["angles"][i], prior[i]), 2),
               "before": [by[j]["label"] for j in _neighbours(before_order, i, 1)],
               "after": [by[j]["label"] for j in _neighbours(after_order, i, 1)]} for i in movers]
    sector_angles = {i: s.axes_angle for i, s in after.slices.items() if s.ring == "sector"}
    angles = {**{i: round(out["angles"][i], 4) for i in fields}, **{i: round(a, 4) for i, a in sector_angles.items()}}
    return {
        "version": VERSION,
        "params": {k: v for k, v in sig.params.__dict__.items()},
        "coverage": sig.coverage, "coverage_any": sig.any_coverage,
        "diagnostics": out["diagnostics"],
        "angles": angles,
        "order": [i for i, _ in sorted(((i, out["angles"][i]) for i in fields), key=lambda t: (t[1], t[0]))],
        "fields": {i: {"axes_angle": round(prior[i], 4), "angle": round(out["angles"][i], 4), "radius_prior": round(prior_r[i], 5),
                       "radius": round(out["radius"][i], 5), "centre": round(after.slices[i].angle, 4)} for i in fields},
        "metrics": {"coherence": coh, "coherence_by_source": per_source, "holdout": held, "stability": stability},
        "ring_order": {"before": before_order, "after": after_order},
        "named": named, "movers": movers,
        "degraded": sorted({d for d in map(str, log)}),
    }


def tiled_slices(result, root=ROOT):
    """{id: Slice} of the simulation's layout tiled by `basemap.build` (angles enter as unit axes vectors, so the build's
    widths, radial bands and sector placement are reused unchanged); the default build is not touched."""
    from .render import basemap as bm
    from .fine.cards import coarsen_rows, load_fine
    root = Path(root)
    cards = bm.load_cards(root / "data/coarse/seed_v3.jsonl")
    axes = bm.axes_means(cards, root / "data/answers/axes.jsonl", [root / f"data/coarse/seed_v{v}.jsonl" for v in (0, 1, 2)],
                         [root / "data/answers/axis_at.jsonl", root / "data/answers/axis_pg.jsonl"])
    rows = coarsen_rows(bm.evidence_rows(root), load_fine(root / "data/fine/fine_v1.jsonl"))
    ax = {i: {**a, "abstract_tangible": math.cos(math.radians(result["angles"][i])),
              "personal_global": math.sin(math.radians(result["angles"][i]))} for i, a in axes.items()}
    return bm.build(cards, ax, rows, cards[0]["basemap_version"], log=[]).slices
