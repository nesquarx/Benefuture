import math

import pytest

from lifeimage.projection import DEFAULT, Entry, Governed, fold, project

from conftest import link, make_card, make_row, membership


def graph():
    return [
        make_card("a", links=[link("u", weight=1.0), link("o", "overlap", 0.5)]),
        make_card("u", links=[link("g", weight=1.0)]),  # a's upstream has its own upstream: one step only
        make_card("g"),
        make_card("o"),  # overlap neighbour of a
        make_card("two", links=[link("u", weight=0.75), link("g", weight=0.25)]),
        make_card("loop1", links=[link("loop2")]),
        make_card("loop2", links=[link("loop1")]),
        make_card("cinema"),
        make_card("film"),
    ]


def val(out, entity, domain, channel="positive"):
    return out.get(entity, {}).get(domain, {}).get(channel, 0.0)


def total(out, entity="person:1", channel="positive"):
    return math.fsum(ch.get(channel, 0.0) for ch in out.get(entity, {}).values())


def test_governed_defaults_live_in_one_place():
    assert DEFAULT.bleed_fraction == 0.1
    assert DEFAULT.table[("impacted", "*")].cap == 0.1
    assert DEFAULT.table[("causal", "*")].cap is None and DEFAULT.table[("communicative", "*")].cap is None
    assert DEFAULT.table[("causal", "*")].weight == 1.0 and DEFAULT.table[("communicative", "*")].weight == 1.0


def test_outputs_count_fully_in_their_own_domain_less_the_bleed():
    out = project([make_row(magnitude=2.0)], graph())
    assert val(out, "person:1", "a") == pytest.approx(1.8)
    assert val(out, "person:1", "u") == pytest.approx(0.2)


def test_communicative_outputs_count_like_causal():
    c = project([make_row(relation="communicative", magnitude=2.0)], graph())
    k = project([make_row(relation="causal", magnitude=2.0)], graph())
    assert c == k


def test_colour_never_goes_to_overlap_links():
    out = project([make_row(magnitude=5.0)], graph())
    assert "o" not in out["person:1"]


def test_bleed_splits_across_upstream_by_weight():
    out = project([make_row(memberships=[membership("two")], magnitude=1.0)], graph())
    assert val(out, "person:1", "two") == pytest.approx(0.9)
    assert val(out, "person:1", "u") == pytest.approx(0.075)
    assert val(out, "person:1", "g") == pytest.approx(0.025)


def test_bleed_is_one_step_only():
    out = project([make_row(magnitude=1.0)], graph())
    assert val(out, "person:1", "g") == 0.0  # u's own upstream gets nothing from a


def test_bleed_terminates_on_cycles_and_conserves():
    out = project([make_row(memberships=[membership("loop1")], magnitude=1.0)], graph())
    assert val(out, "person:1", "loop1") == pytest.approx(0.9) and val(out, "person:1", "loop2") == pytest.approx(0.1)
    assert total(out) == pytest.approx(1.0)


def test_domain_without_upstream_keeps_everything():
    out = project([make_row(memberships=[membership("g")], magnitude=3.0)], graph())
    assert out["person:1"] == {"g": {"positive": pytest.approx(3.0)}}


def test_per_relation_totals_are_conserved_by_the_bleed():
    rows = [make_row(memberships=[membership("a", "content", 0.6), membership("two", "content", 0.4),
                                  membership("loop1", "purpose", 1.0)], magnitude=2.5),
            make_row(relation="impacted", memberships=[membership("a", "content", 1.0)], magnitude=40.0)]
    with_bleed = fold(rows, graph())
    without = fold(rows, graph(), Governed(bleed_fraction=0.0, table=DEFAULT.table))
    assert set(with_bleed) == set(without)
    for key in without:
        assert math.fsum(with_bleed[key].values()) == pytest.approx(math.fsum(without[key].values())), key
    # a row's two relation types each count once: 2.5 for content and 2.5 for purpose
    causal = {k: v for k, v in with_bleed.items() if k[1] == "causal"}
    assert {k[2]: math.fsum(v.values()) for k, v in causal.items()} == pytest.approx({"content": 2.5, "purpose": 2.5})


def test_upstream_domain_listed_in_the_row_is_not_double_counted():
    rows = [make_row(memberships=[membership("a", "content", 0.5), membership("u", "content", 0.5)], magnitude=1.0)]
    assert total(project(rows, graph())) == pytest.approx(1.0)


def test_passive_consumption_is_capped_however_much_of_it_there_is():
    rows = [make_row(relation="impacted", memberships=[membership("cinema", "content", 1.0)], magnitude=1.0,
                     date=f"20{i % 100:02d}") for i in range(1000)]
    out = project(rows, graph())
    assert val(out, "person:1", "cinema") <= 0.1 + 1e-9
    assert val(out, "person:1", "cinema") == pytest.approx(0.1)


def test_passive_consumption_below_the_cap_counts_as_is():
    out = project([make_row(relation="impacted", memberships=[membership("cinema")], magnitude=0.04)], graph())
    assert val(out, "person:1", "cinema") == pytest.approx(0.04)


def test_cap_is_per_domain_and_a_single_output_beats_a_thousand_views():
    views = [make_row(relation="impacted", memberships=[membership("film")], magnitude=1.0) for _ in range(1000)]
    review = [make_row(relation="communicative", memberships=[membership("film")], magnitude=1.0)]
    assert val(project(views + review, graph()), "person:1", "film") == pytest.approx(0.1 + 1.0)
    assert val(project(review, graph()), "person:1", "film") > 8 * val(project(views, graph()), "person:1", "film")


def test_cap_applies_before_the_bleed_so_it_binds_what_leaks_upstream_too():
    rows = [make_row(relation="impacted", memberships=[membership("a")], magnitude=100.0)]
    out = project(rows, graph())
    assert total(out) == pytest.approx(0.1)
    assert val(out, "person:1", "u") == pytest.approx(0.01)


def test_cap_is_per_entity():
    rows = [make_row(entity=e, relation="impacted", memberships=[membership("cinema")], magnitude=9.0)
            for e in ("person:1", "person:2")]
    out = project(rows, graph())
    assert val(out, "person:1", "cinema") == pytest.approx(0.1) and val(out, "person:2", "cinema") == pytest.approx(0.1)


def test_table_and_fraction_are_overridable():
    gov = Governed(bleed_fraction=0.5, table={**DEFAULT.table, ("impacted", "*"): Entry(1.0, None)})
    out = project([make_row(relation="impacted", memberships=[membership("a")], magnitude=10.0)], graph(), gov)
    assert val(out, "person:1", "a") == pytest.approx(5.0) and val(out, "person:1", "u") == pytest.approx(5.0)


def test_membership_specific_table_entry_beats_wildcard():
    gov = Governed(bleed_fraction=0.0, table={**DEFAULT.table, ("causal", "purpose"): Entry(0.2, None)})
    rows = [make_row(memberships=[membership("g", "purpose", 1.0)], magnitude=1.0),
            make_row(memberships=[membership("g", "content", 1.0)], magnitude=1.0)]
    assert val(project(rows, graph(), gov), "person:1", "g") == pytest.approx(1.2)


def test_revoked_rows_do_nothing_and_signed_rows_subtract():
    rows = [make_row(magnitude=4.0, revoked=True),
            make_row(memberships=[membership("g")], magnitude=1.0),
            make_row(memberships=[membership("g")], magnitude=0.25, sign=-1, channel="negative")]
    out = project(rows, graph())
    assert val(out, "person:1", "g") == pytest.approx(1.0) and "a" not in out["person:1"]
    assert val(out, "person:1", "g", "negative") == pytest.approx(-0.25)


def test_input_order_does_not_matter():
    rows = [make_row(relation="impacted", memberships=[membership("cinema")], magnitude=0.07, date=f"20{i:02d}")
            for i in range(5)] + [make_row(memberships=[membership("a")], magnitude=1.0)]
    assert project(rows, graph()) == project(list(reversed(rows)), graph())


@pytest.mark.parametrize("row,match", [
    (make_row(memberships=[membership("nowhere")]), "nowhere"),
    (make_row(relation="bystander"), "bystander"),
    (make_row(memberships=[membership("a", "vibe", 1.0)]), "vibe"),
])
def test_unknown_domains_relations_and_membership_rels_are_loud_not_dropped(row, match):
    with pytest.raises(ValueError, match=match):
        project([row], graph())


def test_unknown_upstream_target_in_the_graph_is_loud():
    cards = [make_card("a", links=[link("ghost")])]
    with pytest.raises(ValueError, match="ghost"):
        project([make_row()], cards)
