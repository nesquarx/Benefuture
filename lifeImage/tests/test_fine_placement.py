"""Placing fine domains inside their main parent's arc: the angle-stability invariants (order kept, drift bounded).

The red baseline is the existing strict-link layout: adding one child re-splits the parent's arc and moves every
sibling, which is the drift these tests forbid.
"""
import pytest

from lifeimage import layout as L
from lifeimage.fine.placement import add_fine, place_fine

from conftest import link, make_card

PARENT = {"c.a": (100.0, 130.0), "c.b": (130.0, 140.0), "c.c": (140.0, 200.0)}


def fine(id, parent="c.a", weight=1.0, others=()):
    return {"id": id, "parents": [(parent, weight), *others]}


def centre(arc):
    return L.arc_centre(arc)


@pytest.mark.xfail(strict=True, reason="counterexample: the strict-link layout re-splits the arc and moves siblings")
def test_baseline_strict_layout_moves_old_children_when_one_is_added():
    """What the placement must not do: re-split the parent's arc (existing layout with strict links)."""
    def cards(n):
        out = [make_card("c.a", links=[], axes={"abstract_tangible": 1.0, "personal_global": 0.0})]
        out += [make_card(f"f.{i}", links=[link("c.a", strict=True)], axes={"abstract_tangible": 1.0, "personal_global": 0.1 * i})
                for i in range(n)]
        return out
    first, second = L.layout(cards(4), free_arcs={"c.a": (100.0, 130.0)}), L.layout(cards(5), free_arcs={"c.a": (100.0, 130.0)})
    drift = max(L.circ_diff(centre(first[f"f.{i}"]), centre(second[f"f.{i}"])) for i in range(4))
    assert drift < L.EPSILON, f"old children drifted {drift:.2f} deg when one child was added"


def test_children_sit_inside_the_main_parents_arc_and_tile_it():
    arcs = place_fine(PARENT, [fine("f.x"), fine("f.y"), fine("f.z")])
    for a in arcs.values():
        assert L.arc_inside(a, PARENT["c.a"])
    assert sum(L.width(a) for a in arcs.values()) == pytest.approx(30.0)
    assert not any(L.arcs_overlap(arcs[i], arcs[j]) for i in arcs for j in arcs if i < j)


def test_a_child_leans_toward_its_second_parent():
    kids = [fine("f.toward_c", others=[("c.c", 0.4)]), fine("f.alone"), fine("f.toward_none_but_b", others=[("c.b", 0.1)])]
    arcs = place_fine(PARENT, kids)
    order = sorted(arcs, key=lambda i: centre(arcs[i]))
    # c.a sits at 100-130; c.b (135) and c.c (170) lie ahead of it, so children lean forward in the order of the pull.
    assert order == ["f.alone", "f.toward_none_but_b", "f.toward_c"]


def test_placement_is_deterministic_and_input_order_free():
    kids = [fine("f.x", others=[("c.c", 0.2)]), fine("f.y"), fine("f.z", others=[("c.b", 0.3)])]
    assert place_fine(PARENT, kids) == place_fine(PARENT, list(reversed(kids)))


def test_fine_domains_leave_every_coarse_arc_untouched():
    arcs = place_fine(PARENT, [fine("f.x"), fine("f.y", parent="c.b"), fine("f.z", parent="c.c")])
    old = L.Version("v0", dict(PARENT))
    new = L.Version("v1", {**PARENT, **arcs}, strict={i: [p] for i, p in {"f.x": "c.a", "f.y": "c.b", "f.z": "c.c"}.items()})
    assert L.check_invariants(old, new) == []


def test_adding_fine_domains_later_keeps_order_and_bounds_drift():
    kids = [fine(f"f.{i}", others=[("c.c", 0.05 * i)]) for i in range(1, 7)]
    arcs = place_fine(PARENT, kids)
    order = sorted(arcs, key=lambda i: centre(arcs[i]))
    new_arcs = add_fine(arcs, PARENT, kids, [fine("f.new", others=[("c.c", 0.12)])])
    old, new = L.Version("v1", dict(arcs)), L.Version("v2", dict(new_arcs))
    assert L.check_invariants(old, new) == []  # order, drift, no removal
    assert [i for i in sorted(new_arcs, key=lambda i: centre(new_arcs[i])) if i != "f.new"] == order
    assert L.arc_inside(new_arcs["f.new"], PARENT["c.a"])
    drift = max(L.circ_diff(centre(arcs[i]), centre(new_arcs[i])) for i in arcs)
    assert drift < L.EPSILON


def test_added_fine_lands_between_the_siblings_it_resembles():
    kids = [fine("f.1"), fine("f.2", others=[("c.c", 0.2)]), fine("f.3", others=[("c.c", 0.6)])]
    new = add_fine(place_fine(PARENT, kids), PARENT, kids, [fine("f.mid", others=[("c.c", 0.4)])])
    order = sorted(new, key=lambda i: centre(new[i]))
    assert order == ["f.1", "f.2", "f.mid", "f.3"]


def test_many_additions_in_a_row_never_breach_the_bound_between_versions():
    kids = [fine(f"f.{i}", others=[("c.c", 0.1 * i)]) for i in range(1, 5)]
    arcs = place_fine(PARENT, kids)
    for n in range(10):
        before, added = arcs, fine(f"f.n{n}", others=[("c.c", 0.05 + 0.07 * n)])
        arcs = add_fine(arcs, PARENT, kids, [added])
        kids.append(added)
        assert L.check_invariants(L.Version("a", dict(before)), L.Version("b", dict(arcs))) == [], n
        assert all(L.arc_inside(a, PARENT["c.a"]) for a in arcs.values())


def test_adversarial_inputs_are_rejected_not_placed_silently():
    with pytest.raises(ValueError, match="not a coarse domain"):
        place_fine(PARENT, [fine("f.x", parent="c.nope")])
    with pytest.raises(ValueError, match="duplicate"):
        place_fine(PARENT, [fine("f.x"), fine("f.x")])
    with pytest.raises(ValueError, match="no parent"):
        place_fine(PARENT, [{"id": "f.x", "parents": []}])
    with pytest.raises(ValueError, match="already placed"):
        add_fine(place_fine(PARENT, [fine("f.x")]), PARENT, [fine("f.x")], [fine("f.x")])
    with pytest.raises(ValueError, match="not a coarse domain"):
        add_fine({}, PARENT, [], [fine("f.x", parent="c.nope")])
    with pytest.raises(ValueError, match="has no arc"):
        add_fine({}, PARENT, [fine("f.known")], [fine("f.x")])
