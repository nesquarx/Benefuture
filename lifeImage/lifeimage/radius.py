"""Radius (LI.26): complexity, difficulty and specificity from mechanical proxies, combined monotonically.

Outward means more of all three. No model is called; every proxy reads a source file or the learnt co-membership.

Proxies (confidence is the author-facing trust in the proxy as a stand-in for the quantity, not a probability):
  specificity  information content, -ln of the smoothed share of co-membership support under the node (coarse nodes
               by their own support, sectors by the sum of their fields, fine nodes by their parent's support split
               over its fine children by link weight); ESCO reuse level (confidence 0.3: a group-level ordinal from
               the skill group, the per-skill ESCO field is not in the fetched data; an ISCO occupation group is
               occupation-specific by definition). Depth (sector 0, coarse 1, fine 2) is constant inside a group and
               enters through the level lift below.
  difficulty   ISCO-08 skill level (1 to 4) of the major group in an ISCO anchor (confidence 0.6: ISCO defines the
               levels by major group); a node without an own ISCO anchor takes the mean of its descendants' (bottom-up,
               reported as aggregated). Education level is not stated in any fetched source, so it is not used; the
               descriptions' education words name the students' level, not the node's, and are ignored.
  complexity   the number of distinct upstream ancestors (confidence 0.5: it counts links the classifier chose), and
               prerequisite depth from co-membership direction (confidence 0.4): `a` sits inside `b` when, within a
               type, p(b|a) exceeds p(a|b) by `PREREQ_MARGIN` on at least `PREREQ_SUPPORT_MIN` items; the depth is the
               longest chain of such insides, bounded by `PREREQ_CAP` so a cycle cannot run away. A fine node takes the
               largest depth of its parents.

Combination: each component is rank-normalised (average ranks) within its group, the nodes of one level under one
primary sector (the sectors form one group); an axis is the mean of its available components, re-ranked; the
composite is the mean of the available axes, re-ranked. A missing proxy is left out, never read as zero. The group
rank is then lifted by level so that a child is never inside its parent: a sector's composite is `SECTOR_CAP` times
its rank, a node's is `p + (1 - p) (STEP_FLOOR + STEP_SPAN q)` with p the largest composite among its parents (the
sector for a field with no parent of a lower level).
"""
import math
from collections import defaultdict
from dataclasses import dataclass, field

from .degradation import record_degradation
from .packs import is_sector

SMOOTHING = 1.0          # governed: additive co-membership support, so a node with none keeps a finite information content
PREREQ_MARGIN = 0.1      # governed: least inclusion asymmetry p(b|a) - p(a|b) that gives a direction
PREREQ_SUPPORT_MIN = 2   # governed: least items behind both directions of a pair
PREREQ_CAP = 4           # governed: bound on prerequisite depth
SECTOR_CAP = 0.4         # governed: the composite a sector's top rank reaches; fields lift outward from it
STEP_FLOOR = 0.1         # governed: the least share of the remaining radius a child moves outward of its parent
STEP_SPAN = 0.8          # governed: the share of the remaining radius its own rank spans (floor + span < 1)
NEGATIVE_RHO = 0.0       # governed: a pair of proxies with rank correlation below this is flagged
AXES = ("complexity", "difficulty", "specificity")

# ISCO-08 skill level (1 to 4) by major group; armed forces by sub-major group (01 officers 4, 02 NCOs 2, 03 other 1).
ISCO_LEVEL = {"1": 3.5, "2": 4.0, "3": 3.0, "4": 2.0, "5": 2.0, "6": 2.0, "7": 2.0, "8": 2.0, "9": 1.0,
              "0": (4 + 2 + 1) / 3, "01": 4.0, "02": 2.0, "03": 1.0}
# ESCO skill groups S1..S8 as a reuse ordinal: 0 transversal, 0.25 cross-sectoral, 0.5 sector-specific,
# 0.75 and 1 occupation-specific (handling, constructing, machinery).
SKILL_REUSE = {"S1": 0.0, "S2": 0.0, "S4": 0.25, "S5": 0.25, "S3": 0.5, "S6": 0.75, "S7": 0.75, "S8": 1.0}
CONFIDENCE = {"information_content": 0.5, "reuse_level": 0.3, "isco_skill_level": 0.6, "distinct_upstream": 0.5,
              "prerequisite_depth": 0.4}


def isco_difficulty(code):
    """ISCO-08 skill level of `code` scaled to [0, 1]; ValueError for a code that is not an ISCO group."""
    code = str(code)
    if not code.isdigit():
        raise ValueError(f"not an ISCO code: {code!r}")
    level = ISCO_LEVEL.get(code[:2]) if code[0] == "0" and len(code) > 1 else ISCO_LEVEL.get(code[0])
    if level is None:
        raise ValueError(f"not an ISCO code: {code!r}")
    return (level - 1) / 3


def level_of(card):
    return 0 if is_sector(card) else 2 if card.get("level") == "fine" else 1


def _upstream(card):
    return [l["id"] for l in card["links"] if l["rel"] == "upstream"]


def _weights(card):
    return [(l["id"], l["weight"]) for l in card["links"] if l["rel"] == "upstream"]


def sector_of(cards):
    """{id: id of its primary sector}: the heaviest upstream link, followed until a sector (a cycle stops at the
    first repeat and the node takes the heaviest sector reached otherwise). Nodes with no sector map to None."""
    by = {c["id"]: c for c in cards}
    out = {}

    def find(i, seen):
        if i in out:
            return out[i]
        if is_sector(by[i]):
            return i
        for u, _ in sorted(_weights(by[i]), key=lambda t: (-t[1], t[0])):
            if u in by and u not in seen:
                s = find(u, seen | {u})
                if s:
                    return s
        return None

    for i in sorted(by):
        out[i] = find(i, {i})
    return out


def ancestors(cards):
    """{id: set of upstream ancestors, transitive, cycle-safe}."""
    by = {c["id"]: c for c in cards}
    memo = {}

    def go(i, seen):
        if i in memo:
            return memo[i]
        acc = set()
        for u in _upstream(by[i]):
            if u in by and u not in seen:
                acc |= {u} | go(u, seen | {u})
        return acc

    for i in sorted(by):
        memo[i] = go(i, {i})
    return memo


def distinct_upstream(cards):
    return {i: len(a - {i}) for i, a in ancestors(cards).items()}


def information_content(cards, fine, rows, smoothing=SMOOTHING):
    """{id: nats}: -ln of the smoothed share of co-membership support under the node (see module doc)."""
    cards = list(cards)
    sector = sector_of(cards)
    own = defaultdict(float)
    for r in rows:
        own[r["a"]] += r["support"]
        own[r["b"]] += r["support"]
    mass = {c["id"]: own.get(c["id"], 0.0) + smoothing for c in cards if not is_sector(c)}
    total = math.fsum(mass.values())
    for c in cards:
        if is_sector(c):
            mass[c["id"]] = math.fsum(m for i, m in mass.items() if sector.get(i) == c["id"] and not i.startswith("s."))
    kids = defaultdict(float)
    for f in fine:
        for u, w in _weights(f):
            kids[u] += w
    for f in fine:
        ws = _weights(f)
        wsum = math.fsum(w for u, w in ws if u in mass)
        mass[f["id"]] = (math.fsum(w / wsum * mass[u] * w / kids[u] for u, w in ws if u in mass) if wsum else smoothing)
    return {i: -math.log(max(m, 1e-12) / total) for i, m in mass.items()}


def reuse_level(card):
    """ESCO reuse ordinal in [0, 1] for a node from ESCO (skill group or ISCO occupation group), else None."""
    levels = []
    for a in card["anchors"]:
        if a["source"] == "esco_isco":
            levels.append(1.0)
        elif a["source"] == "esco_skills":
            g = SKILL_REUSE.get(a["code"].split(".")[0])
            if g is not None:
                levels.append(g)
    return math.fsum(levels) / len(levels) if levels else None


def own_difficulty(card):
    vals = []
    for a in card["anchors"]:
        if a["source"] in ("esco_isco", "isco08"):
            try:
                vals.append(isco_difficulty(a["code"]))
            except ValueError:
                pass
    return math.fsum(vals) / len(vals) if vals else None


def prerequisite_depth(rows, ids, margin=PREREQ_MARGIN, support_min=PREREQ_SUPPORT_MIN, cap=PREREQ_CAP):
    """{id: bounded longest chain of nodes it sits inside}, from within-type inclusion asymmetry."""
    p, s = {}, {}
    for r in rows:
        if r["type_i"] == r["type_j"]:
            p[(r["a"], r["b"], r["type_i"])] = r["p"]
            s[(r["a"], r["b"], r["type_i"])] = r["support"]
    asym = defaultdict(list)
    for (a, b, t), v in p.items():
        if (b, a, t) in p and min(s[(a, b, t)], s[(b, a, t)]) >= support_min:
            asym[(a, b)].append(v - p[(b, a, t)])
    inside = defaultdict(set)
    for (a, b), d in sorted(asym.items()):
        if math.fsum(d) / len(d) >= margin:
            inside[a].add(b)
    depth = {i: 0 for i in ids}
    for _ in range(cap):
        new = {i: min(cap, max([depth[i]] + [1 + depth.get(b, 0) for b in inside.get(i, ())])) for i in depth}
        if new == depth:
            break
        depth = new
    return depth


def rank_unit(values):
    """{key: average rank scaled to [0, 1]} over the entries that are not None; a lone entry is 0.5."""
    items = sorted(((v, k) for k, v in values.items() if v is not None), key=lambda t: (t[0], t[1]))
    n = len(items)
    out, i = {}, 0
    while i < n:
        j = i
        while j + 1 < n and items[j + 1][0] == items[i][0]:
            j += 1
        for k in range(i, j + 1):
            out[items[k][1]] = 0.5 if n == 1 else ((i + j) / 2) / (n - 1)
        i = j + 1
    return out


def combine(parts):
    """Mean of the proxies that are present (monotone in each); None when none is."""
    vals = [v for v in parts.values() if v is not None]
    return math.fsum(vals) / len(vals) if vals else None


def spearman(x, y):
    """Spearman rank correlation with average ranks; None when either side has no variation or fewer than 2 pairs."""
    if len(x) != len(y) or len(x) < 2:
        return None
    rx, ry = rank_unit(dict(enumerate(x))), rank_unit(dict(enumerate(y)))
    n = len(x)
    mx, my = math.fsum(rx.values()) / n, math.fsum(ry.values()) / n
    sx = math.fsum((rx[i] - mx) ** 2 for i in range(n))
    sy = math.fsum((ry[i] - my) ** 2 for i in range(n))
    if sx == 0 or sy == 0:
        return None
    return math.fsum((rx[i] - mx) * (ry[i] - my) for i in range(n)) / math.sqrt(sx * sy)


def proxy_correlations(table):
    """{(a, b): (rho, n)} over the axis pairs, on the nodes carrying both. table: {id: {axis: value or None}}."""
    out = {}
    for i, a in enumerate(AXES):
        for b in AXES[i + 1:]:
            pairs = [(t[a], t[b]) for t in table.values() if t.get(a) is not None and t.get(b) is not None]
            out[(a, b)] = (spearman([p[0] for p in pairs], [p[1] for p in pairs]), len(pairs))
    return out


def negative_pairs(corr, floor=NEGATIVE_RHO):
    """The axis pairs whose correlation is below `floor`: proxies that should rise together and do not."""
    return [k for k, (rho, _) in corr.items() if rho is not None and rho < floor]


def hierarchy_violations(cards, radius):
    """[(child, parent)] where a child's composite is not strictly outside a parent of a lower level."""
    by = {c["id"]: c for c in cards}
    out = []
    for c in cards:
        for u in _upstream(c):
            if u in by and level_of(by[u]) < level_of(c) and c["id"] in radius and u in radius \
                    and radius[c["id"]]["composite"] <= radius[u]["composite"]:
                out.append((c["id"], u))
    return out


@dataclass
class Result:
    radius: dict = field(default_factory=dict)   # id -> {complexity, difficulty, specificity, composite}
    raw: dict = field(default_factory=dict)      # id -> raw proxy values and their sources
    report: dict = field(default_factory=dict)
    degraded: list = field(default_factory=list)


def compute(coarse, fine, rows, log=None):
    cards = list(coarse) + list(fine)
    by = {c["id"]: c for c in cards}
    sector = sector_of(cards)
    lvl = {i: level_of(c) for i, c in by.items()}
    group = {i: (lvl[i], sector.get(i) if lvl[i] else "") for i in by}
    result = Result(degraded=log if log is not None else [])

    ic = information_content(coarse, fine, rows)
    measured = {r[k] for r in rows for k in ("a", "b")}
    up = distinct_upstream(cards)
    ids_c = [c["id"] for c in coarse if not is_sector(c)]
    prereq = prerequisite_depth(rows, ids_c)
    for f in fine:  # a fine node takes its parents' deepest chain
        parents = [prereq[u] for u in _upstream(f) if u in prereq]
        prereq[f["id"]] = max(parents) if parents else None
    for c in coarse:
        if is_sector(c):
            prereq[c["id"]] = None

    diff = {i: own_difficulty(c) for i, c in by.items()}
    diff_source = {i: "own" for i, v in diff.items() if v is not None}
    for level in (1, 0):  # bottom-up: a node without its own takes the mean of its children's
        for i in sorted(by):
            if lvl[i] == level and diff[i] is None:
                kids = [diff[k] for k in by if lvl[k] == level + 1 and i in _upstream(by[k]) and diff[k] is not None]
                if level == 0:
                    kids = [diff[k] for k in by if lvl[k] > 0 and sector.get(k) == i and diff[k] is not None]
                if kids:
                    diff[i], diff_source[i] = math.fsum(kids) / len(kids), "aggregated"
    comp = {i: {"information_content": ic[i], "reuse_level": reuse_level(by[i]), "isco_skill_level": diff[i],
                "distinct_upstream": float(up[i]), "prerequisite_depth": prereq[i]} for i in by}
    unmeasured = sorted(i for i in ids_c if i not in measured)
    if unmeasured:
        record_degradation(f"information_content: {', '.join(unmeasured[:5])}" + (f" and {len(unmeasured) - 5} more" if len(unmeasured) > 5 else ""),
                           "information_content", "smoothed support only",
                           f"{len(unmeasured)} coarse fields have no co-membership rows", result.degraded)

    by_group = defaultdict(list)
    for i in sorted(by):
        by_group[group[i]].append(i)

    def ranked(values):
        out = {}
        for ids in by_group.values():
            out.update(rank_unit({i: values[i] for i in ids}))
        return out

    rk = {k: ranked({i: comp[i][k] for i in by}) for k in CONFIDENCE}
    axis_in = {"specificity": ("information_content", "reuse_level"), "difficulty": ("isco_skill_level",),
               "complexity": ("distinct_upstream", "prerequisite_depth")}
    axis = {}
    for a, ks in axis_in.items():
        axis[a] = ranked({i: combine({k: rk[k].get(i) for k in ks}) for i in by})
    q = ranked({i: combine({a: axis[a].get(i) for a in AXES}) for i in by})

    composite = {}
    for level in (0, 1, 2):
        for i in sorted(by):
            if lvl[i] != level:
                continue
            if level == 0:
                composite[i] = SECTOR_CAP * q[i]
                continue
            parents = [u for u in _upstream(by[i]) if u in composite and lvl[u] < level]
            if not parents and sector.get(i) in composite:
                parents = [sector[i]]
            p = max((composite[u] for u in parents), default=0.0)
            composite[i] = p + (1 - p) * (STEP_FLOOR + STEP_SPAN * q[i])
    for i in sorted(by):
        result.radius[i] = {**{a: (round(axis[a][i], 6) if i in axis[a] else None) for a in AXES},
                            "composite": round(composite[i], 6)}
    result.raw = {i: {"group": list(group[i]), **comp[i], "depth": lvl[i], "difficulty_source": diff_source.get(i)}
                  for i in by}

    n = len(by)
    cov = {a: sum(1 for i in by if i in axis[a]) / n for a in AXES}
    component_cov = {k: sum(1 for i in by if comp[i][k] is not None) / n for k in CONFIDENCE}
    component_cov["information_content_measured"] = sum(1 for i in by if i in measured or lvl[i] != 1) / n
    by_level = {name: {a: (sum(1 for i in by if lvl[i] == L and i in axis[a]) / max(1, sum(1 for i in by if lvl[i] == L)))
                       for a in AXES} for L, name in enumerate(("sector", "coarse", "fine"))}
    table = {i: {a: axis[a].get(i) for a in AXES} for i in by}
    spread = []
    for i, t in table.items():
        vals = {a: v for a, v in t.items() if v is not None}
        if len(vals) >= 2:
            spread.append({"id": i, "label": by[i]["label"], "spread": round(max(vals.values()) - min(vals.values()), 4),
                           "proxies": {a: round(v, 3) for a, v in vals.items()}})
    spread.sort(key=lambda s: (-s["spread"], s["id"]))
    result.report = {"nodes": n, "coverage": cov, "coverage_by_level": by_level, "component_coverage": component_cov,
                     "difficulty_source": {s: sum(1 for v in diff_source.values() if v == s) for s in ("own", "aggregated")},
                     "correlations": proxy_correlations(table), "disagreement": spread[:25],
                     "confidence": dict(CONFIDENCE)}
    result.report["negative_pairs"] = negative_pairs(result.report["correlations"])
    return result
