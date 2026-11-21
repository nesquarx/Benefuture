"""Angular layout of the basemap and the invariants that keep angles stable between versions.

An arc is (start, end) in degrees, start in [0, 360), width end - start in (0, 360]; arcs may run past 360.
Angle 0 is tangible (right), 90 global (top), 180 abstract (left), 270 personal (bottom).

Domains form a network, so each is placed once, where it is closest: at the angle of its own axes; else at the
circular mean of its upstream domains' angles, weighted by link weight. A domain with neither is reported, never
silently placed. Overlap links place nothing. Layout is mechanical: domains not strictly contained tile the circle
around their angles; a domain with a `strict` link nests inside that container's arc (the heaviest strict link
places it), widths split by link weight. Containment is checked only for strict links. Between versions, stability
beats optimality: circular order, centre-angle drift below a governed epsilon, strict containment, and tombstones
that keep their gap. Without these checks a refinement silently rotates old images.

Resolution and nesting iterate over rounds, never recursing, so cycles among non-strict links are harmless; strict
cycles are rejected.
"""
import math
from dataclasses import dataclass, field

from .vocab import UPSTREAM

EPSILON = 2.0  # governed: maximum centre-angle drift (degrees) between versions
INSERT_WIDTH = 3.0  # governed: default arc width (degrees) of a node inserted between neighbours
AXES_MIN = 0.05  # governed: axes shorter than this carry no direction and defer to the upstream domains
MEAN_MIN = 1e-9  # upstream directions that cancel out give no mean
TOL = 1e-6


def angle_from_axes(axes):
    return math.degrees(math.atan2(axes["personal_global"], axes["abstract_tangible"])) % 360


def _norm(start, width):
    return (start % 360, start % 360 + width)


def width(arc):
    return arc[1] - arc[0]


def arc_centre(arc):
    return ((arc[0] + arc[1]) / 2) % 360


def circ_diff(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def arc_inside(inner, outer, tol=TOL):
    off = (inner[0] - outer[0]) % 360
    if off > 360 - tol:
        off -= 360
    return off >= -tol and off + width(inner) <= width(outer) + tol


def arcs_overlap(a, b, tol=TOL):
    d = (b[0] - a[0]) % 360
    e = (a[0] - b[0]) % 360
    return min(width(a) - d, width(b)) > tol or min(width(b) - e, width(a)) > tol


def tile_arcs(angles):
    """Tile the circle: {id: angle} -> {id: arc}. Each arc spans halfway to the angular neighbours, so its centre is
    the node's angle. Nodes sharing an angle split one slice equally, in id order."""
    groups = {}
    for id_, a in angles.items():
        key = round(a % 360 / TOL)
        groups.setdefault(key, []).append(id_)
    keys = sorted(groups)
    n = len(keys)
    out = {}
    for i, k in enumerate(keys):
        a = k * TOL
        prev = (a - keys[i - 1] * TOL) % 360 if n > 1 else 360
        nxt = (keys[(i + 1) % n] * TOL - a) % 360 if n > 1 else 360
        start, span = a - prev / 2, prev / 2 + nxt / 2
        ids = sorted(groups[k])
        for j, id_ in enumerate(ids):
            out[id_] = _norm(start + span * j / len(ids), span / len(ids))
    return out


def coarse_arcs(cards):
    return tile_arcs({c["id"]: angle_from_axes(c["axes"]) for c in cards})


def _links(card, rel=UPSTREAM):
    return [l for l in card["links"] if l["rel"] == rel]


def _own_angle(card):
    ax = card["axes"]
    if ax and math.hypot(ax["abstract_tangible"], ax["personal_global"]) >= AXES_MIN:
        return angle_from_axes(ax)
    return None


def _mean_angle(pairs):
    x = math.fsum(w * math.cos(math.radians(a)) for a, w in pairs)
    y = math.fsum(w * math.sin(math.radians(a)) for a, w in pairs)
    if math.hypot(x, y) < MEAN_MIN:
        return None
    return math.degrees(math.atan2(y, x)) % 360


def resolve_angles(cards):
    """({id: degrees}, [unresolved ids]). Own axes first; else the weighted circular mean of the upstream domains,
    once all of them are placed. Where upstream domains wait on each other (a cycle), the placed ones decide."""
    by_id = {c["id"]: c for c in cards}
    got = {c["id"]: a for c in cards if (a := _own_angle(c)) is not None}
    pending = sorted(i for i in by_id if i not in got)

    def step(complete):
        fresh = {}
        for i in pending:
            ups = [(l["id"], l["weight"]) for l in _links(by_id[i]) if l["id"] in by_id]
            known = [(got[u], w) for u, w in ups if u in got]
            if known and (not complete or len(known) == len(ups)) and (m := _mean_angle(known)) is not None:
                fresh[i] = m
        return fresh

    while pending and (fresh := step(True) or step(False)):
        got.update(fresh)
        pending = [i for i in pending if i not in got]
    return got, sorted(i for i in by_id if i not in got)


def strict_links(cards):
    """{id: [container ids]} for the links marked strict."""
    return {c["id"]: sorted(l["id"] for l in c["links"] if l.get("strict")) for c in cards
            if any(l.get("strict") for l in c["links"])}


def place_children(parent_arc, children):
    """children: ordered [(id, weight)]; arcs inside parent_arc, widths proportional to weight."""
    total = math.fsum(w for _, w in children)
    out, pos = {}, parent_arc[0]
    for id_, w in children:
        wd = width(parent_arc) * w / total
        out[id_] = _norm(pos, wd)
        pos += wd
    return out


def layout(cards, free_arcs=None):
    """{id: arc}, one arc per domain. `free_arcs` fixes the arcs of the domains that are not strictly contained
    (for refinements that keep them); the others nest inside them."""
    by_id = {c["id"]: c for c in cards}
    for c in cards:
        for l in c["links"]:
            if l["id"] not in by_id:
                raise ValueError(f"{c['id']}: link target {l['id']} is not in the card set")
    angles, unresolved = resolve_angles(cards)
    if unresolved:
        raise ValueError(f"no axes and no placed upstream domain for {unresolved}")
    container = {}
    for c in cards:
        s = [l for l in c["links"] if l.get("strict")]
        if s:
            container[c["id"]] = max(s, key=lambda l: (l["weight"], l["id"]))
    free = {i: a for i, a in angles.items() if i not in container}
    arcs = dict(free_arcs) if free_arcs is not None else tile_arcs(free)
    if set(arcs) != set(free):
        raise ValueError(f"free arcs cover {sorted(arcs)}, expected {sorted(free)}")
    pending = set(container)
    while pending:
        ready = {i for i in pending if container[i]["id"] in arcs}
        if not ready:
            raise ValueError(f"strict link cycle among {sorted(pending)}")
        kids = {}
        for i in ready:
            kids.setdefault(container[i]["id"], []).append((i, container[i]["weight"]))
        for parent, ks in kids.items():
            pa = arcs[parent]
            ks.sort(key=lambda kw: ((angles[kw[0]] - pa[0]) % 360, kw[0]))
            arcs.update(place_children(pa, ks))
        pending -= ready
    return arcs


def insert_between(group, new_id, left, right, new_width=INSERT_WIDTH):
    """Insert new_id between circularly adjacent siblings left and right ({id: arc} in, same out plus the new arc).
    Takes the free gap if there is one, else carves half from each neighbour; no other node moves or reorders."""
    order = sorted(group, key=lambda i: (arc_centre(group[i]), i))
    if len(order) < 2 or order[(order.index(left) + 1) % len(order)] != right:
        raise ValueError(f"{right} does not directly follow {left}")
    l, r = group[left], group[right]
    gap = (r[0] - l[1]) % 360
    out = dict(group)
    if gap >= new_width:
        new = _norm(l[1] + (gap - new_width) / 2, new_width)
    else:
        c = (new_width - gap) / 2
        out[left] = (l[0], l[1] - c)
        out[right] = _norm(r[0] + c, width(r) - c)
        new = _norm(l[1] - c, gap + 2 * c)
    out[new_id] = new
    return out, new


@dataclass
class Version:
    version: str
    arcs: dict  # {id: arc}
    tombstones: dict = field(default_factory=dict)  # {id: [successor ids]}
    strict: dict = field(default_factory=dict)  # {id: [container ids]}, from strict_links


@dataclass
class Violation:
    kind: str  # containment | order | drift | gap | removal | successor
    id: str
    detail: str = ""


def _related(v, a, b):
    return b in v.strict.get(a, ()) or a in v.strict.get(b, ())


def check_invariants(old, new, epsilon=EPSILON):
    out = []
    for id_, containers in new.strict.items():
        for c in containers:
            if id_ in new.arcs and c in new.arcs and not arc_inside(new.arcs[id_], new.arcs[c]):
                out.append(Violation("containment", id_, f"outside strict container {c}"))
    common = [i for i in new.arcs if i in old.arcs]
    if len(common) > 2:
        seq = lambda g: [i for i in sorted(g, key=lambda i: (arc_centre(g[i]), i)) if i in common]
        a, b = seq(old.arcs), seq(new.arcs)
        k = b.index(a[0])
        if b[k:] + b[:k] != a:
            out.append(Violation("order", "", f"{a} became {b}"))
    for i in common:
        d = circ_diff(arc_centre(old.arcs[i]), arc_centre(new.arcs[i]))
        if d >= epsilon:
            out.append(Violation("drift", i, f"{d:.2f} deg"))
    for id_ in old.arcs:
        if id_ not in new.arcs and id_ not in new.tombstones:
            out.append(Violation("removal", id_, "gone without a tombstone"))
    for id_, succ in new.tombstones.items():
        if not succ or any(s not in new.arcs or s in new.tombstones for s in succ):
            out.append(Violation("successor", id_, f"successors {succ} missing, empty or tombstoned"))
        if id_ not in new.arcs:
            out.append(Violation("gap", id_, "tombstone lost its arc"))
            continue
        arc, was = new.arcs[id_], old.arcs.get(id_)
        if was is not None and (circ_diff(was[0], arc[0]) > TOL or abs(width(was) - width(arc)) > TOL):
            out.append(Violation("gap", id_, "tombstone arc changed"))
        for other, a in new.arcs.items():
            if other != id_ and other not in new.tombstones and not _related(new, id_, other) and arcs_overlap(arc, a):
                out.append(Violation("gap", id_, f"{other} closes the gap"))
    return out
