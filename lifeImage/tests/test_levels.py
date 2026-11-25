"""LI.36 (levels) and LI.37 (channel split), stated as outcomes of the image state.

Red first: each assertion names the outcome the rulings promise (what colour a kind of row makes, what a thousand
viewings add up to, what a claim of a level looks like next to the same level done), never the presence of a function.
"""
import math

import pytest

from lifeimage.generators import life
from lifeimage.render import basemap as bmod
from lifeimage.render import image as im

from conftest import make_row, membership

D = "c.physics"
RELS = ("form", "content", "outcome")


def cards():
    return bmod.load_cards()


def row(domain=D, magnitude=0.5, **over):
    kw = dict(channel="positive", memberships=[membership(domain, r) for r in RELS], magnitude=magnitude, valid_time="2026-11",
              tier="attested", relation="causal", production="produced")
    kw.update(over)
    return make_row(**kw)


def cv(rows, **kw):
    return im.channel_values(rows, cards(), **kw)


def level(rows, channel, layer="solid", domain=D, **kw):
    return cv(rows, **kw).get(layer, {}).get(domain, {}).get(channel, 0.0)


# ---------- LI.37: which row makes which channel ----------

def test_a_row_taking_in_makes_red_not_green():
    r = row(relation="impacted", production="consumed")
    assert level([r], "red") > 0.05 and level([r], "green") == 0.0 and level([r], "blue") == 0.0


def test_a_row_producing_makes_green_and_blue_not_red():
    r = row()
    assert level([r], "green") > 0.05 and level([r], "blue") > 0.05 and level([r], "red") == 0.0


def test_a_claim_of_doing_is_grainy_red_never_solid_and_never_green():
    r = row(tier="claimed")
    c = cv([r])
    assert level([r], "red", "claimed") > 0.05
    assert D not in c.get("solid", {}) and level([r], "green", "claimed") == 0.0 and level([r], "green") == 0.0


def test_a_test_of_knowing_makes_solid_red_by_tier_and_a_claimed_one_makes_grainy_red():
    k = row(test_kind="knowing", tier="attested")
    assert level([k], "red") > 0.05 and level([k], "green") == 0.0
    kc = row(test_kind="knowing", tier="claimed")
    assert level([kc], "red", "claimed") > 0.05 and level([kc], "red") == 0.0


def test_an_assessment_of_doing_makes_green_not_red():
    d = row(test_kind="doing", tier="measured")
    assert level([d], "green") > 0.05 and level([d], "red") == 0.0


def test_knowing_and_doing_the_same_thing_show_red_with_green_beside_it_while_red_alone_means_not_doing():
    knowing = [row(test_kind="knowing")]
    both = knowing + [row(test_kind="doing")]
    assert level(both, "green") > 0.05 and level(knowing, "green") == 0.0
    assert level(both, "red") == pytest.approx(level(knowing, "red"), abs=1e-9)


def test_self_assessment_and_prediction_are_red_and_grainy():
    p = make_row(channel="prediction", memberships=[membership(D, "form"), membership(D, "content")], magnitude=0.6, valid_time="2026-11",
                 tier="claimed")
    assert level([p], "red", "claimed") > 0.05 and level([p], "green", "claimed") == 0.0 and level([p], "red") == 0.0


# ---------- LI.36: levels from imprints ----------

def test_a_level_is_a_number_in_zero_one_however_much_is_added():
    heap = [row(magnitude=5.0) for _ in range(300)]
    v = level(heap, "green")
    assert 0.95 < v <= 1.0


def test_imprints_add_per_channel_and_saturate_like_light():
    a, b = row(magnitude=0.4), row(magnitude=0.7)
    la, lb, lab = level([a], "green"), level([b], "green"), level([a, b], "green")
    assert lab == pytest.approx(1 - (1 - la) * (1 - lb), abs=1e-6)  # exposures compose as 1 - prod(1 - level)
    assert max(la, lb) < lab < 1.0


def test_a_thousand_viewings_never_reach_one_review():
    viewings = [row(relation="impacted", production="consumed", magnitude=0.05, memberships=[membership(D, "content")]) for _ in range(1000)]
    review = row(magnitude=1.0, memberships=[membership(D, "form"), membership(D, "content")])
    assert level(viewings, "red") < 1.0
    assert level([review], "green") > level(viewings[:5], "red") and level([review], "green") > 0.2


def test_luminosity_is_weight_times_decay_so_a_fifteen_year_old_row_is_half_an_imprint():
    new = row(valid_time="2026-11")
    old = row(valid_time="2011-11")
    ln, lo = level([new], "green", asof="2026-11"), level([old], "green", asof="2026-11")
    assert lo == pytest.approx(1 - (1 - ln) ** 0.5, abs=1e-3)


def test_a_claim_of_a_level_imprints_that_level_so_red_matches_the_same_level_done():
    done = row(magnitude=1.0, memberships=[membership(D, "form"), membership(D, "content")])
    lv = level([done], "green")
    claim = make_row(channel="prediction", memberships=[membership(D, "form"), membership(D, "content")], magnitude=lv, valid_time="2026-11",
                     tier="claimed")
    assert level([claim], "red", "claimed") == pytest.approx(lv, abs=0.05)  # the claimed level, less the bleed to upstream that every imprint loses


def test_a_claim_above_the_record_reads_as_red_beyond_green():
    done = row(magnitude=0.4)
    claim = make_row(channel="prediction", memberships=[membership(D, "form"), membership(D, "content")], magnitude=0.95, valid_time="2026-11",
                     tier="claimed")
    c = cv([done, claim])
    assert c["claimed"][D]["red"] > c["solid"][D]["green"] + 0.3


def test_colour_still_stays_in_the_rows_domain_with_a_little_upstream_bleed_and_none_to_neighbours():
    by = {c["id"]: c for c in cards()}
    d = "c.sleep"
    neigh = {l["id"] for l in by[d]["links"] if l["rel"] == "overlap"}
    ups = {l["id"] for l in by[d]["links"] if l["rel"] == "upstream"}
    c = cv([row(d, 3.0)])["solid"]
    assert neigh and not (set(c) & neigh)
    assert c[d]["green"] > 0 and all(c[u]["green"] < c[d]["green"] for u in ups if u in c)


def test_the_governed_constants_live_in_one_place_with_defaults():
    g = im.DEFAULT.levels
    assert 0 < g.tone_k and 0 < g.consumed_weight <= 1 and g.half_life_years == 15.0


def test_the_legacy_projection_stays_reachable_for_comparison():
    r = row(relation="impacted", production="consumed")
    legacy = im.channel_values([r], cards(), legacy=True)
    assert legacy["solid"][D]["green"] > 0 and legacy["solid"][D]["red"] == 0  # the old split: consumption was green, capped


# ---------- the generator's flags ----------

def _rows(pid, archetype, age, key):
    p = life.generate_persona(seed=pid, archetype=archetype, age=age, pid=f"t{pid}")
    return [r for e in p.events if e["key"] == key for i in e["rows"] for r in [p.rows[i]]]


def test_exam_rows_are_tests_of_knowing_and_the_driving_test_is_a_test_of_doing():
    ex = [r for s in range(1, 15) for r in _rows(s, "student", 22, "exam")]
    dr = [r for s in range(1, 25) for r in _rows(s, "generalist", 40, "driving_licence")]
    assert ex and dr
    assert {r.get("test_kind") for r in ex} == {"knowing"} and {r.get("test_kind") for r in dr} == {"doing"}


def test_only_tests_carry_a_test_kind_and_every_generated_row_says_produced_or_consumed():
    p = life.generate_persona(seed=3, archetype="generalist", age=50, pid="t3")
    kinds = {r.get("test_kind") for r in p.rows}
    assert kinds <= {None, "knowing", "doing"}
    assert all(r["production"] in ("produced", "consumed") for r in p.rows if r["channel"] != "prediction")
    school = [r for e in p.events if e["key"] == "school" for i in e["rows"] for r in [p.rows[i]]]
    assert school and all(r["production"] == "consumed" for r in school)


def test_a_persona_with_a_knowing_test_shows_solid_red_where_the_exam_is():
    p = None
    for s in range(1, 30):
        q = life.generate_persona(seed=s, archetype="student", age=22, pid=f"t{s}")
        if any(r.get("test_kind") == "knowing" and r["tier"] == "attested" for r in q.rows):
            p = q
            break
    assert p is not None
    c = im.channel_values(p.rows, cards())
    assert level(p.rows, "red", domain="c.exams_assessment") > 0 or c["solid"].get("c.school_education", {}).get("red", 0) > 0
