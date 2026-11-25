"""Placement plan for fine domains: each inside the arc of its main parent, ordered by similarity, angles stable.

A fine domain is placed once, inside the arc of its main parent (the heaviest parent weight, then id). Within that arc
the children are ordered by their pull toward their other parents: the signed angle (degrees, along the arc's
direction) from the main parent's centre to the weighted circular mean of all the child's parents' centres. A child
with one parent has pull 0; one that also sits under a parent further along the circle lies further along the arc, so
neighbours in the arc are neighbours in meaning. Widths are equal.

Stability. Coarse arcs are never touched: fine arcs nest inside them, so coarse order and centres hold by
construction. A later release adds children with `add_fine`, which never re-tiles: the existing arcs keep their order
and stay where they are except the one or two neighbours of an insertion, which give up a share of at most half of
`INSERT_WIDTH` (so a centre moves by less than `layout.EPSILON`), and the new child lands where its pull falls among
the siblings' pulls. Re-placing everything with `place_fine` after each addition would re-split the arc and move every
sibling (drift of several degrees in a wide parent): that is the failure `add_fine` exists to prevent.
"""
import math

from .. import layout as L


def _validate(parent_arcs, fines):
    seen = set()
    for f in fines:
        if f["id"] in seen:
            raise ValueError(f"duplicate fine id {f['id']}")
        seen.add(f["id"])
        if not f["parents"]:
            raise ValueError(f"{f['id']}: no parent")
        for p, w in f["parents"]:
            if p not in parent_arcs:
                raise ValueError(f"{f['id']}: parent {p} is not a coarse domain with an arc")
            if w <= 0:
                raise ValueError(f"{f['id']}: parent weight {w} must be positive")


def main_parent(fine):
    return min(fine["parents"], key=lambda pw: (-pw[1], pw[0]))[0]


def pull(parent_arcs, fine):
    """Signed degrees from the main parent's centre toward the weighted mean of the child's parents (0 for one parent)."""
    main = main_parent(fine)
    centre = L.arc_centre(parent_arcs[main])
    mean = L._mean_angle([(L.arc_centre(parent_arcs[p]), w) for p, w in fine["parents"]])
    return 0.0 if mean is None else ((mean - centre + 180) % 360) - 180


def _key(parent_arcs, fine):
    return (round(pull(parent_arcs, fine), 9), fine["id"])


def place_fine(parent_arcs, fines):
    """{fine id: arc}: children of each coarse parent tile its arc in order of pull. Raises on a duplicate id, a child
    with no parent, or a parent that has no arc."""
    _validate(parent_arcs, fines)
    by_parent = {}
    for f in fines:
        by_parent.setdefault(main_parent(f), []).append(f)
    out = {}
    for p, kids in by_parent.items():
        kids.sort(key=lambda f: _key(parent_arcs, f))
        out.update(L.place_children(parent_arcs[p], [(f["id"], 1.0) for f in kids]))
    return out


def _children(arcs, parent_arc):
    kids = [i for i, a in arcs.items() if L.arc_inside(a, parent_arc)]
    return sorted(kids, key=lambda i: ((arcs[i][0] - parent_arc[0]) % 360, i))


def _insert(arcs, parent_arc, new_id, index, order):
    """Insert new_id so that it is the index-th child of `order` (existing children in arc order); return arcs."""
    out = dict(arcs)
    left = order[index - 1] if index > 0 else None
    right = order[index] if index < len(order) else None
    near = [n for n in (left, right) if n is not None]
    w = min(L.INSERT_WIDTH, 0.5 * min(L.width(arcs[n]) for n in near))
    take = w / len(near)
    if left is not None:
        a = arcs[left]
        out[left] = (a[0], a[1] - take)
    if right is not None:
        a = arcs[right]
        out[right] = L._norm(a[0] + take, L.width(a) - take)
    start = (arcs[left][1] if left is not None else arcs[right][0] - 0) - (take if left is not None else 0)
    if left is None:
        start = arcs[right][0]
    out[new_id] = L._norm(start, w)
    return out


def add_fine(arcs, parent_arcs, known, new):
    """Fine arcs after adding `new` specs to the placed `arcs` (whose specs are `known`, for their pulls).
    Existing children keep their order; only an insertion's neighbours narrow. A parent with no children yet is tiled
    like `place_fine`. Raises when a new id is already placed or a known one has no arc."""
    for f in new:
        if f["id"] in arcs:
            raise ValueError(f"{f['id']} is already placed")
    _validate(parent_arcs, [*known, *new])
    for f in known:
        if f["id"] not in arcs:
            raise ValueError(f"known {f['id']} has no arc")
    spec = {f["id"]: f for f in known}
    out = dict(arcs)
    for f in sorted(new, key=lambda f: (main_parent(f), _key(parent_arcs, f))):
        p = main_parent(f)
        order = _children(out, parent_arcs[p])
        if not order:
            out.update(L.place_children(parent_arcs[p], [(f["id"], 1.0)]))
        else:
            keys = [_key(parent_arcs, spec[i]) for i in order]
            index = sum(k < _key(parent_arcs, f) for k in keys)
            out = _insert(out, parent_arcs[p], f["id"], index, order)
        spec[f["id"]] = f
    return out
