import pytest

from lifeimage.layout import (Version, angle_from_axes, arc_centre, arc_inside, check_invariants, coarse_arcs,
                              insert_between, layout, place_children, resolve_angles, strict_links)

from conftest import link, make_card


def ax(t, g):
    return {"abstract_tangible": t, "personal_global": g}


def kinds(vs):
    return {v.kind for v in vs}


def circ(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


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


def test_coincident_angles_share_their_slice_instead_of_collapsing():
    cards = four() + [make_card("twin", axes=ax(1, 0))]
    arcs = coarse_arcs(cards)
    assert sum(b - a for a, b in arcs.values()) == pytest.approx(360)
    assert all(b - a > 1 for a, b in arcs.values())
    assert not arc_inside(arcs["twin"], arcs["tang"]) and not arc_inside(arcs["tang"], arcs["twin"])


def test_place_children_splits_by_weight_inside_parent():
    out = place_children((100, 200), [("a", 3), ("b", 1)])
    assert out["a"] == pytest.approx((100, 175)) and out["b"] == pytest.approx((175, 200))


def test_place_children_across_wrap():
    out = place_children((350, 450), [("a", 1), ("b", 1)])
    assert arc_inside(out["a"], (350, 450)) and arc_inside(out["b"], (350, 450))
    assert out["a"][1] == pytest.approx(400)


# ---- angles: axes first, else the circular weighted mean of upstream domains ------------------------------------

def angles(cards):
    got, unresolved = resolve_angles(cards)
    return got, unresolved


def test_axes_give_the_angle_even_when_upstream_domains_point_elsewhere():
    cards = four() + [make_card("x", axes=ax(0, -1), links=[link("tang")])]
    got, _ = angles(cards)
    assert got["x"] == pytest.approx(270)


def test_axes_less_domain_sits_at_the_weighted_mean_of_all_its_upstream_domains():
    cards = four() + [make_card("mid", axes=None, links=[link("tang", weight=0.5), link("glob", weight=0.5)]),
                      make_card("lean", axes=None, links=[link("tang", weight=0.75), link("glob", weight=0.25)])]
    got, unresolved = angles(cards)
    assert unresolved == []
    assert got["mid"] == pytest.approx(45)  # first-link-only placement gives 0
    assert got["lean"] == pytest.approx(18.4349, abs=1e-3)


def test_upstream_mean_is_circular_across_the_wrap():
    cards = [make_card("n", axes=ax(1, -0.176)), make_card("p", axes=ax(1, 0.176)),
             make_card("m", axes=None, links=[link("n", weight=0.5), link("p", weight=0.5)])]
    got, _ = angles(cards)
    assert circ(got["m"], 0) < 1e-6  # an arithmetic mean would give 180


def test_near_zero_axes_fall_back_to_the_upstream_mean():
    cards = four() + [make_card("faint", axes=ax(0.001, -0.001), links=[link("glob")])]
    got, _ = angles(cards)
    assert got["faint"] == pytest.approx(90)


def test_overlap_links_never_place_a_domain():
    cards = four() + [make_card("nb", axes=None, links=[link("tang", rel="overlap", weight=0.5)])]
    got, unresolved = angles(cards)
    assert unresolved == ["nb"] and "nb" not in got


def test_domain_with_neither_axes_nor_upstream_is_reported_and_never_silently_placed():
    cards = four() + [make_card("lost", axes=None), make_card("lost2", axes=ax(0, 0))]
    got, unresolved = angles(cards)
    assert sorted(unresolved) == ["lost", "lost2"]
    assert "lost" not in got and "lost2" not in got
    with pytest.raises(ValueError, match="lost"):
        layout(cards)


def test_cycles_terminate_and_resolve_from_whatever_has_axes():
    cards = [make_card("a", axes=ax(1, 0), links=[link("b")]), make_card("b", axes=None, links=[link("a")])]
    got, unresolved = angles(cards)
    assert unresolved == [] and got["b"] == pytest.approx(0)
    ring = [make_card("r1", axes=ax(0, 1), links=[link("r3")]), make_card("r2", axes=None, links=[link("r1")]),
            make_card("r3", axes=None, links=[link("r2")])]
    got, unresolved = angles(ring)
    assert unresolved == [] and all(got[i] == pytest.approx(90) for i in ("r1", "r2", "r3"))


def test_a_cycle_with_no_axes_anywhere_is_reported_not_looped():
    cards = [make_card("a", axes=None, links=[link("b")]), make_card("b", axes=None, links=[link("a")])]
    got, unresolved = angles(cards)
    assert sorted(unresolved) == ["a", "b"] and got == {}


def test_a_domain_resolves_from_the_upstream_that_resolves_when_another_never_does():
    cards = four() + [make_card("ghostly", axes=None, links=[link("ghostly2", weight=0.5), link("glob", weight=0.5)]),
                      make_card("ghostly2", axes=None, links=[link("ghostly")])]
    got, unresolved = angles(cards)
    assert got["ghostly"] == pytest.approx(90) and got["ghostly2"] == pytest.approx(90) and unresolved == []


# ---- layout: each domain once -----------------------------------------------------------------------------------

def tree(card=make_card):
    cards = four(card)
    cards += [
        card("tang.1", level="fine", axes=ax(1, 0.3), links=[link("tang", strict=True)]),
        card("tang.2", level="fine", axes=ax(1, -0.3), links=[link("tang", strict=True)]),
        card("both", level="fine", axes=ax(0.5, 0.5), links=[link("tang", weight=0.5), link("glob", weight=0.5)]),
        card("tang.1.x", level="finer", axes=ax(1, 0.3), links=[link("tang.1", strict=True)]),
    ]
    return cards


def test_every_domain_is_placed_once_where_it_is_closest_not_under_its_first_link():
    arcs = layout(tree())
    assert set(arcs) == {c["id"] for c in tree()}
    assert all(isinstance(a, tuple) and len(a) == 2 for a in arcs.values())
    assert arc_centre(arcs["both"]) == pytest.approx(45)  # between tang and glob, outside tang's arc
    assert not arc_inside(arcs["both"], arcs["tang"])
    assert not arc_inside(arcs["both"], arcs["glob"])


def test_free_domains_tile_the_circle_without_overlap():
    arcs = layout(tree())
    free = [arcs[i] for i in ("tang", "glob", "abs", "pers", "both")]
    assert sum(b - a for a, b in free) == pytest.approx(360)


def test_strict_links_nest_the_child_in_the_container_in_axes_order():
    arcs = layout(tree())
    assert arc_inside(arcs["tang.1"], arcs["tang"]) and arc_inside(arcs["tang.2"], arcs["tang"])
    assert arc_inside(arcs["tang.1.x"], arcs["tang.1"])
    off = lambda i: (arcs[i][0] - arcs["tang"][0]) % 360
    assert off("tang.2") < off("tang.1")
    cards = tree()
    v = Version("1", arcs, strict=strict_links(cards))
    assert check_invariants(v, v) == []


def test_non_strict_upstream_does_not_contain():
    cards = four() + [make_card("loose", axes=ax(0, -1), links=[link("tang")])]
    arcs = layout(cards)
    assert not arc_inside(arcs["loose"], arcs["tang"])
    v = Version("1", arcs, strict=strict_links(cards))
    assert check_invariants(v, v) == []


def test_layout_is_independent_of_card_order():
    assert layout(tree()) == layout(list(reversed(tree())))


def test_layout_rejects_strict_cycles_and_missing_targets(card):
    with pytest.raises(ValueError, match="cycle"):
        layout([card("a", links=[link("b", strict=True)]), card("b", links=[link("a", strict=True)])])
    with pytest.raises(ValueError, match="ghost"):
        layout([card("a", links=[link("ghost")])])


def test_non_strict_cycles_lay_out(card):
    arcs = layout([card("a", axes=ax(1, 0), links=[link("b")]), card("b", axes=ax(-1, 0), links=[link("a")])])
    assert set(arcs) == {"a", "b"}


def base_version():
    cards = tree()
    return Version("1", layout(cards), strict=strict_links(cards))


def free_group(v):
    return {i: a for i, a in v.arcs.items() if i not in v.strict}


def test_identical_versions_pass():
    v = base_version()
    assert check_invariants(v, v) == []


def test_insertion_between_neighbours_keeps_every_invariant():
    cards = tree()
    old = Version("1", layout(cards), strict=strict_links(cards))
    group = free_group(old)
    new_group, _ = insert_between(group, "new", "tang", "both")
    cards = cards + [make_card("new", axes=ax(0.9, 0.4))]
    new = Version("2", layout(cards, free_arcs=new_group), strict=strict_links(cards))
    assert check_invariants(old, new, epsilon=2.0) == []
    ids = sorted(new_group, key=lambda i: arc_centre(new_group[i]))
    k = ids.index("tang")
    assert (ids[k:] + ids[:k]) == ["tang", "new", "both", "glob", "abs", "pers"]
    assert {i: new_group[i] for i in ("abs", "pers", "glob")} == {i: group[i] for i in ("abs", "pers", "glob")}


def test_insertion_requires_adjacent_neighbours():
    group = free_group(base_version())
    with pytest.raises(ValueError):
        insert_between(group, "new", "tang", "abs")


def clone(v, version="2"):
    return Version(version, dict(v.arcs), dict(v.tombstones), dict(v.strict))


def test_counterexample_strict_child_outside_container_is_rejected():
    old = base_version()
    new = clone(old)
    new.arcs["tang.1"] = (100, 120)  # far outside tang's arc
    assert "containment" in kinds(check_invariants(old, new, epsilon=1000))


def test_counterexample_non_strict_link_outside_its_target_is_not_a_violation():
    old = base_version()
    new = clone(old)
    assert "both" not in new.strict
    assert not arc_inside(new.arcs["both"], new.arcs["tang"])
    assert "containment" not in kinds(check_invariants(old, new))


def test_counterexample_swapping_neighbours_is_rejected():
    old = base_version()
    new = clone(old)
    new.arcs["glob"], new.arcs["abs"] = new.arcs["abs"], new.arcs["glob"]
    assert "order" in kinds(check_invariants(old, new, epsilon=1000))


def test_counterexample_centre_drift_beyond_epsilon_is_rejected():
    old = base_version()
    new = clone(old)
    s, e = new.arcs["pers"]
    new.arcs["pers"] = (s + 5, e + 5)
    assert "drift" in kinds(check_invariants(old, new, epsilon=2.0))
    assert "drift" not in kinds(check_invariants(old, new, epsilon=6.0))


def test_drift_just_inside_epsilon_passes():
    old = base_version()
    new = clone(old)
    s, e = new.arcs["pers"]
    new.arcs["pers"] = (s + 1.9, e + 1.9)
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
    s, e = new.arcs["pers"]
    new.arcs["pers"] = (s - 40, e)  # spills into the tombstone's arc
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
