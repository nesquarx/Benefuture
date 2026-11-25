import math
import statistics
import xml.etree.ElementTree as ET
from functools import lru_cache

import pytest

from lifeimage.render import basemap as bmod
from lifeimage.render import image as im

from conftest import make_card, make_row, membership, link


@lru_cache(maxsize=1)
def world():
    return bmod.build_v0(), im.load_entities()


def cards_by_id(bm):
    return bmod.load_all_cards()


def red_share(cv):
    t = im.totals(cv)
    s = t["red"] + t["green"] + t["blue"]
    return t["red"] / s if s else 0.0


def colour_domains(cv):
    return {d for layer in cv.values() for d, ch in layer.items() if any(v > 0 for v in ch.values())}


# ---------- basemap ----------

def test_every_coarse_field_is_placed_once_with_an_angle_and_a_ring():
    bm = bmod.build_v0()
    cards = bmod.load_cards()
    assert set(bm.slices) == {c["id"] for c in cards}
    for s in bm.slices.values():
        assert 0 <= s.angle < 360 and s.width > 0 and 0 <= s.r0 < s.r1 <= 1.0


def test_fields_sit_at_the_angle_of_their_mean_axes_position():
    bm, cards = bmod.build_v0(), bmod.load_cards()
    ax = bmod.axes_means(cards)
    checked = 0
    for i, a in ax.items():
        if i in bm.inherited:
            continue
        want = math.degrees(math.atan2(a["personal_global"], a["abstract_tangible"])) % 360
        assert bm.slices[i].axes_angle == pytest.approx(want, abs=1e-6)
        checked += 1
    assert checked > 150


def test_circular_order_of_fields_follows_axes_angle():
    bm = bmod.build_v0()
    fields = [s for s in bm.slices.values() if s.ring == "field"]
    seq = [s.axes_angle for s in sorted(fields, key=lambda s: s.start)]
    k = seq.index(min(seq))
    seq = seq[k:] + seq[:k]  # ties (equal angles) may stand in any order; the angles never go back
    assert seq == sorted(seq)


def test_rings_tile_the_circle_without_overlap():
    bm = bmod.build_v0()
    for ring in ("sector", "field"):
        ss = sorted((s for s in bm.slices.values() if s.ring == ring), key=lambda s: s.start)
        assert math.fsum(s.width for s in ss) == pytest.approx(360, abs=1e-6)
        for a, b in zip(ss, ss[1:] + ss[:1]):
            assert (b.start - (a.start + a.width)) % 360 == pytest.approx(0, abs=1e-6) or \
                   (b.start - (a.start + a.width)) % 360 == pytest.approx(360, abs=1e-6)


def test_sectors_are_the_inner_ring_fields_the_outer():
    bm = bmod.build_v0()
    inner = max(s.r1 for s in bm.slices.values() if s.ring == "sector")
    outer = min(s.r0 for s in bm.slices.values() if s.ring == "field")
    assert inner <= outer


def test_heavier_pressure_gives_wider_slices():
    bm = bmod.build_v0()
    fields = sorted((s for s in bm.slices.values() if s.ring == "field"), key=lambda s: s.pressure)
    lo, hi = fields[:50], fields[-50:]
    assert statistics.mean(s.width for s in hi) > 3 * statistics.mean(s.width for s in lo)
    assert all(s.width >= bmod.MIN_FIELD_SLICE - 1e-9 for s in fields)  # a domain without evidence keeps a slice


def test_undefined_angles_take_the_upstream_mean_and_are_reported():
    bm, cards = bmod.build_v0(), bmod.load_cards()
    by = {c["id"]: c for c in cards}
    assert all(bm.slices[i].source == "upstream" for i in bm.inherited)
    for i in bm.inherited:
        ups = [l["id"] for l in by[i]["links"] if l["rel"] == "upstream"]
        assert ups, i  # never placed from nothing
    assert any("[OPEN]" in n and "complexity" in n for n in bm.notes)


def test_basemap_is_deterministic():
    a, b = bmod.build_v0(), bmod.build_v0()
    assert {i: (s.start, s.width, s.r0, s.r1) for i, s in a.slices.items()} == \
           {i: (s.start, s.width, s.r0, s.r1) for i, s in b.slices.items()}


# ---------- channels ----------

def cards():
    return bmod.load_all_cards()


def _row(channel, domain, magnitude, over):
    kw = dict(channel=channel, memberships=[membership(domain, r) for r in ("form", "content", "outcome")],
              magnitude=magnitude, valid_time="2026-11")
    kw.update(over)
    return make_row(**kw)


def prediction_row(domain, magnitude, **over):
    return _row("prediction", domain, magnitude, over)


def done_row(domain, magnitude, **over):
    return _row("positive", domain, magnitude, over)


def test_over_estimator_is_redder_than_a_calibrated_entity_with_the_same_record():
    doms = ["c.sleep", "c.physics", "c.eldercare"]
    rec = [done_row(d, 0.4, tier="attested") for d in doms]
    over = rec + [prediction_row(d, 0.9, tier="claimed") for d in doms]
    well = rec + [prediction_row(d, 0.4, tier="claimed") for d in doms]
    assert red_share(im.channel_values(over, cards())) > red_share(im.channel_values(well, cards())) + 0.1


def test_over_personas_are_red_dominant_relative_to_well_calibrated_and_under_ones():
    bm, ents = world()
    by = {}
    for e in ents:
        if e["kind"] == "person":
            by.setdefault(e["calibration"], []).append(red_share(im.channel_values(e["rows"], cards())))
    over, well, under = (statistics.mean(by[k]) for k in ("over", "well", "under"))
    assert over > well + 0.03 and well > under + 0.02, (over, well, under)


def test_no_colour_in_a_domain_without_a_row_or_an_upstream_link_to_one():
    bm, ents = world()
    by = {c["id"]: c for c in cards()}
    for e in ents:
        direct = {m["domain"] for r in e["rows"] for m in r["memberships"]}
        allowed = set(direct) | {l["id"] for d in direct for l in by[d]["links"] if l["rel"] == "upstream"}
        assert colour_domains(im.channel_values(e["rows"], cards())) <= allowed, e["id"]


def test_overlap_neighbours_get_no_colour_even_when_strongly_linked():
    by = {c["id"]: c for c in cards()}
    d = "c.sleep"
    neigh = {l["id"] for l in by[d]["links"] if l["rel"] == "overlap"}
    assert neigh
    cv = im.channel_values([done_row(d, 5.0)], cards())
    assert not (colour_domains(cv) & neigh)
    assert d in colour_domains(cv)


def test_colour_stays_in_the_rows_domain_for_each_channel():
    cv = im.channel_values([done_row("c.sleep", 1.0, tier="attested")], cards())
    ch = cv["solid"]["c.sleep"]
    assert ch["green"] > 0 and ch["blue"] > 0 and ch["red"] == 0  # done work colours expertise and impact, never potential
    cv = im.channel_values([prediction_row("c.sleep", 1.0)], cards())
    ch = cv["claimed"]["c.sleep"]
    assert ch["red"] > 0 and ch["green"] == 0 and ch["blue"] == 0


def test_negative_and_revoked_rows_do_not_colour_the_predicted_measured_image():
    rows = [done_row("c.sleep", 1.0, channel="negative", sign=-1), done_row("c.physics", 1.0, revoked=True)]
    assert colour_domains(im.channel_values(rows, cards())) == set()


def test_unknown_domain_is_rejected():
    with pytest.raises(ValueError):
        im.channel_values([done_row("c.nope", 1.0)], cards())


def test_every_tier_goes_to_the_solid_layer_and_only_predictions_make_grain():
    done = im.channel_values([done_row("c.sleep", 1.0, tier="claimed"), done_row("c.physics", 1.0, tier="attested"),
                              done_row("c.eldercare", 1.0, tier="measured")], cards())
    assert {"c.sleep", "c.physics", "c.eldercare"} <= colour_domains({"x": done["solid"]})
    assert colour_domains({"x": done.get("claimed", {})}) == set()
    guess = im.channel_values([prediction_row("c.sleep", 0.8)], cards())
    assert "c.sleep" in colour_domains({"x": guess["claimed"]}) and colour_domains({"x": guess.get("solid", {})}) == set()


def test_older_rows_are_dimmed_by_the_half_life():
    old = done_row("c.physics", 1.0, valid_time="1996-11", tier="attested")
    new = done_row("c.physics", 1.0, valid_time="2026-11", tier="attested")
    gov = im.Governed(half_life_years=15.0)
    t_old = im.totals(im.channel_values([old, new], cards(), gov, asof="2026-11", legacy=True))["green"]  # raw sums, legacy projection
    t_new = im.totals(im.channel_values([new], cards(), gov, asof="2026-11", legacy=True))["green"]
    t_old_only = t_old - t_new
    assert 0 < t_old_only < t_new
    assert t_old_only == pytest.approx(t_new * 0.25, rel=0.02)  # 30 years = two half-lives


def test_dimming_is_relative_to_the_entitys_latest_row_when_no_date_is_given():
    rows = [done_row("c.physics", 1.0, valid_time="1750-01", tier="attested"),
            done_row("c.chemistry", 1.0, valid_time="1750-01", tier="attested")]
    assert im.totals(im.channel_values(rows, cards()))["green"] > 0  # a figure's own career is not dimmed to nothing


def test_intensity_is_log_scaled_monotone_and_bounded():
    g = im.DEFAULT
    xs = [0, 0.01, 0.1, 1, 10, 1e6]
    ys = [im.intensity(x, g) for x in xs]
    assert ys[0] == 0 and ys == sorted(ys) and ys[-1] == 1.0
    assert im.intensity(g.v_ref / 2, g) > 0.5  # a log scale lifts small values above a linear one


# ---------- svg ----------

def render(e, bm):
    return im.render_svg(e["label"], im.channel_values(e["rows"], cards()), bm)


def test_svg_is_well_formed_with_flange_notch_slot_and_basemap_version():
    bm, ents = world()
    svg = render(ents[0], bm)
    root = ET.fromstring(svg)
    ids = {el.get("id") for el in root.iter() if el.get("id")}
    assert {"flange", "notches", "wedges"} <= ids
    assert bm.version in svg
    assert next(el for el in root.iter() if el.get("id") == "notches").findall("*") == []  # no notches yet


def test_same_input_gives_byte_identical_svg():
    bm, ents = world()
    e = next(e for e in ents if e["id"] == "p010")
    assert render(e, bm).encode() == render(e, bm).encode()


def test_grain_is_drawn_for_predictions_only_and_a_claimed_event_is_drawn_solid_but_pale():
    bm, _ = world()
    claimed = im.render_svg("c", im.channel_values([done_row("c.sleep", 1.0, tier="claimed")], cards()), bm)
    measured = im.render_svg("s", im.channel_values([done_row("c.sleep", 1.0, tier="measured")], cards()), bm)
    guess = im.render_svg("p", im.channel_values([prediction_row("c.sleep", 0.8)], cards()), bm)
    assert 'mask="url(#grain)"' not in claimed and 'mask="url(#grain)"' not in measured
    assert 'mask="url(#grain)"' in guess

    def fill(svg):
        root = ET.fromstring(svg)
        w = next(el for el in root.iter() if el.get("id") == "wedges")
        f = next(p.get("fill") for p in w if p.find("{http://www.w3.org/2000/svg}title") is not None and p.find("{http://www.w3.org/2000/svg}title").text == "c.sleep")
        return tuple(int(f[i:i + 2], 16) for i in (1, 3, 5))
    sat = lambda c: (max(c) - min(c)) / max(c)
    assert sat(fill(claimed)) < sat(fill(measured)) - 0.2


def test_a_claimed_colour_is_less_saturated_than_the_same_attested_colour():
    g = im.DEFAULT
    full, grain = im.rgb({"red": 0.0, "green": 3.0, "blue": 0.0}, g), im.rgb({"red": 0.0, "green": 3.0, "blue": 0.0}, g, claimed=True)
    sat = lambda c: (max(c) - min(c)) / max(c)
    assert sat(grain) < sat(full)


def test_an_entity_with_no_rows_renders_an_empty_disc_not_a_crash():
    bm, _ = world()
    root = ET.fromstring(im.render_svg("nobody", im.channel_values([], cards()), bm))
    assert root is not None


def test_every_entity_set_is_loaded():
    _, ents = world()
    kinds = [e["kind"] for e in ents]
    assert kinds.count("person") == 40 and kinds.count("organisation") == 6 and kinds.count("public") == 10


def test_axes_less_field_takes_the_weighted_mean_of_its_upstream_and_is_reported():
    cs = [make_card("s.a", axes=None), make_card("s.b", axes=None),
          make_card("c.x", axes={"abstract_tangible": 1.0, "personal_global": 0.0}, links=[link("s.a")]),
          make_card("c.y", axes={"abstract_tangible": 0.0, "personal_global": 1.0}, links=[link("s.b")]),
          make_card("c.z", axes=None, links=[link("s.a", weight=0.75), link("s.b", weight=0.25)])]
    axes = {c["id"]: c["axes"] for c in cs if c["axes"]}
    angle, source, inherited = bmod.place_angles(cs, axes)
    assert inherited == ["c.z"] and source["c.z"] == "upstream"
    assert angle["s.a"] == pytest.approx(0) and angle["s.b"] == pytest.approx(90)
    assert 0 < angle["c.z"] < 45  # nearer the heavier upstream
    cs.append(make_card("c.orphan", axes=None))
    with pytest.raises(ValueError):
        bmod.place_angles(cs, axes)
