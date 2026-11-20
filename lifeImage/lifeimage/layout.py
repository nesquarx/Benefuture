"""Angular layout of the basemap and the invariants that keep angles stable between versions.

An arc is (start, end) in degrees, start in [0, 360), width end - start in (0, 360]; arcs may run past 360.
Angle 0 is tangible (right), 90 global (top), 180 abstract (left), 270 personal (bottom).

Layout is mechanical: coarse arcs tile the circle around each node's own axes angle; a child's arc lies inside its
parent's arc, widths split by membership weight, and a child with several parents gets one segment per parent.
Between versions, stability beats optimality: containment, circular order, centre-angle drift below a governed
epsilon, and tombstones that keep their gap. Without these checks a refinement silently rotates old images.
"""
import math
from dataclasses import dataclass, field

EPSILON = 2.0  # governed: maximum centre-angle drift (degrees) between versions
INSERT_WIDTH = 3.0  # governed: default arc width (degrees) of a node inserted between neighbours
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


def coarse_arcs(cards):
    """Tile the circle: each root's arc spans halfway to its angular neighbours, so its centre is its own angle."""
    nodes = sorted(((angle_from_axes(c["axes"]), c["id"]) for c in cards))
    n = len(nodes)
    out = {}
    for i, (a, id_) in enumerate(nodes):
        prev = (a - nodes[i - 1][0]) % 360 if n > 1 else 360
        nxt = (nodes[(i + 1) % n][0] - a) % 360 if n > 1 else 360
        if prev == 0 or nxt == 0:
            raise ValueError(f"{id_}: coincides in angle with a neighbour; axes need separating")
        out[id_] = _norm(a - prev / 2, prev / 2 + nxt / 2)
    return out


def place_children(parent_arc, children):
    """children: ordered [(id, weight)]; arcs inside parent_arc, widths proportional to weight."""
    total = math.fsum(w for _, w in children)
    out, pos = {}, parent_arc[0]
    for id_, w in children:
        wd = width(parent_arc) * w / total
        out[id_] = _norm(pos, wd)
        pos += wd
    return out


def layout(cards, root_arcs=None):
    """{id: {parent_id or "": arc}} for all cards; parents' arcs are placed before their children's."""
    by_id = {c["id"]: c for c in cards}
    for c in cards:
        for p in c["parents"]:
            if p["id"] not in by_id:
                raise ValueError(f"{c['id']}: parent {p['id']} is not in the card set")
    roots = [c for c in cards if not c["parents"]]
    arcs = {}
    for id_, a in (root_arcs if root_arcs is not None else coarse_arcs(roots)).items():
        arcs[id_] = {"": a}
    pending = {c["id"] for c in cards if c["parents"]}
    while pending:
        ready = {i for i in pending if all(p["id"] in arcs and i != p["id"] for p in by_id[i]["parents"])}
        if not ready:
            raise ValueError(f"parent cycle among {sorted(pending)}")
        children_of = {}
        for i in ready:
            for p in by_id[i]["parents"]:
                children_of.setdefault(p["id"], []).append((i, p["weight"]))
        for parent, kids in children_of.items():
            pa = next(iter(arcs[parent].values()))  # primary segment: the parent's first
            def key(kw):
                ax = by_id[kw[0]]["axes"]
                off = (angle_from_axes(ax) - pa[0]) % 360 if ax else 0
                return (off, kw[0])
            for id_, a in place_children(pa, sorted(kids, key=key)).items():
                arcs.setdefault(id_, {})[parent] = a
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
    arcs: dict  # {id: {parent_id or "": arc}}
    tombstones: dict = field(default_factory=dict)  # {id: [successor ids]}


@dataclass
class Violation:
    kind: str  # containment | order | drift | gap | removal | successor
    id: str
    detail: str = ""


def _groups(v):
    g = {}
    for id_, segs in v.arcs.items():
        for key, arc in segs.items():
            g.setdefault(key, {})[id_] = arc
    return g


def check_invariants(old, new, epsilon=EPSILON):
    out = []
    for id_, segs in new.arcs.items():
        for parent, arc in segs.items():
            if parent and not any(arc_inside(arc, p) for p in new.arcs.get(parent, {}).values()):
                out.append(Violation("containment", id_, f"outside {parent}"))
    og, ng = _groups(old), _groups(new)
    for key in ng:
        common = [i for i in ng[key] if i in og.get(key, {})]
        if len(common) > 2:
            seq = lambda g: [i for i in sorted(g, key=lambda i: (arc_centre(g[i]), i)) if i in common]
            a, b = seq(og[key]), seq(ng[key])
            k = b.index(a[0])
            if b[k:] + b[:k] != a:
                out.append(Violation("order", key, f"{a} became {b}"))
        for i in common:
            d = circ_diff(arc_centre(og[key][i]), arc_centre(ng[key][i]))
            if d >= epsilon:
                out.append(Violation("drift", i, f"{d:.2f} deg under {key or 'root'}"))
    for id_ in old.arcs:
        if id_ not in new.arcs and id_ not in new.tombstones:
            out.append(Violation("removal", id_, "gone without a tombstone"))
    for id_, succ in new.tombstones.items():
        if not succ or any(s not in new.arcs or s in new.tombstones for s in succ):
            out.append(Violation("successor", id_, f"successors {succ} missing, empty or tombstoned"))
        if id_ not in new.arcs:
            out.append(Violation("gap", id_, "tombstone lost its arc"))
            continue
        for key, arc in new.arcs[id_].items():
            was = old.arcs.get(id_, {}).get(key)
            if was is not None and (circ_diff(was[0], arc[0]) > TOL or abs(width(was) - width(arc)) > TOL):
                out.append(Violation("gap", id_, "tombstone arc changed"))
            for other, a in ng[key].items():
                if other != id_ and other not in new.tombstones and arcs_overlap(arc, a):
                    out.append(Violation("gap", id_, f"{other} closes the gap"))
    return out
