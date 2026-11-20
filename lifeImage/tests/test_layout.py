import pytest

from lifeimage.layout import (Version, angle_from_axes, arc_centre, arc_inside, check_invariants, coarse_arcs,
                              insert_between, layout, place_children)

from conftest import make_card


def ax(t, g):
    return {"abstract_tangible": t, "personal_global": g}


def kinds(vs):
    return {v.kind for v in vs}


@pytest.mark.parametrize("axes,deg", [((1, 0), 0), ((0, 1), 90), ((-1, 0), 180), ((0, -1), 270), ((1, 1), 45),
                                      ((1, -1), 315)])
def test_angle_from_axes(axes, deg):
    assert angle_from_axes(ax(*axes)) == pytest.approx(deg)


def four(card=make_card):
    return [card("tang", axes=ax(1, 0)), card("glob", axes=ax(0, 1)), card("abs", axes=ax(-1, 0)),
            card("pers", axes=ax(0, -1))]


def test_coarse_arcs_tile_the_circle_in_angle_order_around_their_angles():
    arcs = coarse_arcs(four())
    assert arcs["tang"] == pytest.approx((315, 405))
    assert arcs["glob"] == pytest.approx((45, 135))
    for id_, deg in [("tang", 0), ("glob", 90), ("abs", 180), ("pers", 270)]:
        assert arc_centre(arcs[id_]) == pytest.approx(deg)
    assert sum(b - a for a, b in arcs.values()) == pytest.approx(360)


def test_coarse_arcs_independent_of_input_order():
    assert coarse_arcs(four()) == coarse_arcs(list(reversed(four())))


def test_place_children_splits_by_weight_inside_parent():
    out = place_children((100, 200), [("a", 3), ("b", 1)])
    assert out["a"] == pytest.approx((100, 175)) and out["b"] == pytest.approx((175, 200))


def test_place_children_across_wrap():
    out = place_children((350, 450), [("a", 1), ("b", 1)])
    assert arc_inside(out["a"], (350, 450)) and arc_inside(out["b"], (350, 450))
    assert out["a"][1] == pytest.approx(400)


def tree(card=make_card):
    cards = four(card)
    cards += [
        card("tang.1", level="fine", axes=ax(1, 0.3), parents=[{"id": "tang", "weight": 1.0}]),
        card("tang.2", level="fine", axes=ax(1, -0.3), parents=[{"id": "tang", "weight": 1.0}]),
        card("both", level="fine", axes=ax(0.5, 0.5),
             parents=[{"id": "tang", "weight": 0.5}, {"id": "glob", "weight": 0.5}]),
        card("tang.1.x", level="finer", axes=ax(1, 0.3), parents=[{"id": "tang.1", "weight": 1.0}]),
    ]
    return cards


def test_layout_nests_children_in_parents_with_one_segment_per_parent():
    arcs = layout(tree())
    assert set(arcs["both"]) == {"tang", "glob"}
    for id_, segs in arcs.items():
        for parent, arc in segs.items():
            if parent:
                assert any(arc_inside(arc, p) for p in arcs[parent].values()), (id_, parent)
    # siblings run counter-clockwise from the parent's start in axes-angle order: tang.2 (below axis) first
    off = lambda i: (arcs[i]["tang"][0] - arcs["tang"][""][0]) % 360
    assert off("tang.2") < off("tang.1") < off("both")
    v = Version("1", arcs)
    assert check_invariants(v, v) == []


def test_layout_rejects_cycles_and_missing_parents(card):
    with pytest.raises(ValueError):
        layout([card("a", parents=[{"id": "b", "weight": 1.0}]), card("b", parents=[{"id": "a", "weight": 1.0}])])
    with pytest.raises(ValueError):
        layout([card("a", parents=[{"id": "ghost", "weight": 1.0}])])


def base_version():
    return Version("1", layout(tree()))


def test_identical_versions_pass():
    v = base_version()
    assert check_invariants(v, v) == []


def test_insertion_between_neighbours_keeps_every_invariant():
    cards = tree()
    old = Version("1", layout(cards))
    group = {i: segs[""] for i, segs in old.arcs.items() if "" in segs}
    new_group, new_arc = insert_between(group, "new", "tang", "glob")
    cards = cards + [make_card("new", axes=ax(0.6, 0.8))]
    new = Version("2", layout(cards, root_arcs=new_group))  # descendants re-split inside their parents' arcs
    assert check_invariants(old, new, epsilon=2.0) == []
    ids = sorted(new_group, key=lambda i: arc_centre(new_group[i]))
    k = ids.index("tang")
    assert (ids[k:] + ids[:k]) == ["tang", "new", "glob", "abs", "pers"]
    assert {i: new_group[i] for i in ("abs", "pers")} == {i: group[i] for i in ("abs", "pers")}


def test_insertion_requires_adjacent_neighbours():
    old = base_version()
    group = {i: segs[""] for i, segs in old.arcs.items() if "" in segs}
    with pytest.raises(ValueError):
        insert_between(group, "new", "tang", "abs")


def clone(v, version="2"):
    return Version(version, {i: dict(s) for i, s in v.arcs.items()}, dict(v.tombstones))


def test_counterexample_child_outside_ancestor_is_rejected():
    old = base_version()
    new = clone(old)
    new.arcs["tang.1"]["tang"] = (100, 120)  # far outside tang's arc
    assert "containment" in kinds(check_invariants(old, new))


def test_counterexample_swapping_neighbours_is_rejected():
    old = base_version()
    new = clone(old)
    a, b = new.arcs["glob"][""], new.arcs["abs"][""]
    new.arcs["glob"][""], new.arcs["abs"][""] = b, a
    assert "order" in kinds(check_invariants(old, new, epsilon=1000))


def test_counterexample_centre_drift_beyond_epsilon_is_rejected():
    old = base_version()
    new = clone(old)
    s, e = new.arcs["pers"][""]
    new.arcs["pers"][""] = (s + 5, e + 5)
    assert "drift" in kinds(check_invariants(old, new, epsilon=2.0))
    assert "drift" not in kinds(check_invariants(old, new, epsilon=6.0))


def test_drift_just_inside_epsilon_passes():
    old = base_version()
    new = clone(old)
    s, e = new.arcs["pers"][""]
    new.arcs["pers"][""] = (s + 1.9, e + 1.9)
    assert "drift" not in kinds(check_invariants(old, new, epsilon=2.0))


def tombstoned():
    old = base_version()
    new = clone(old)
    new.tombstones["abs"] = ["glob"]
    return old, new


def test_tombstone_keeps_its_gap():
    old, new = tombstoned()
    assert check_invariants(old, new) == []


def test_counterexample_neighbour_closing_tombstone_gap_is_rejected():
    old, new = tombstoned()
    s, e = new.arcs["pers"][""]
    new.arcs["pers"][""] = (s - 40, e)  # spills into the tombstone's arc
    assert "gap" in kinds(check_invariants(old, new, epsilon=1000))


def test_counterexample_tombstone_arc_dropped_or_moved_is_rejected():
    old, new = tombstoned()
    del new.arcs["abs"]
    assert "gap" in kinds(check_invariants(old, new))


def test_counterexample_silent_removal_and_bad_successors_rejected():
    old = base_version()
    new = clone(old)
    del new.arcs["tang.2"]
    assert "removal" in kinds(check_invariants(old, new))
    old, new = tombstoned()
    new.tombstones["abs"] = []
    assert "successor" in kinds(check_invariants(old, new))
    new.tombstones["abs"] = ["ghost"]
    assert "successor" in kinds(check_invariants(old, new))
