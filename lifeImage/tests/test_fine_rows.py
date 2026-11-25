"""Evidence at the fine level: rows name fine domains, levels land on them and aggregate upward, the basemap and the
renderers show them (LI.51).

Red first, on the outcome: a row that names a fine domain must light that fine slice and not its siblings; a coarse level
must be the re-saturated sum of what its children hold; evidence must reach the fine level wherever the field has fine
children; adding fine domains must not move a coarse arc.

Predictions written before the first measurement (stated here, judged by the tests): of the event rows of generated
personas, 45-75% name a fine domain (93 of the 144 coarse domains the templates use have fine children), every row that
could name one does, and the chosen fine domain fits the event's wording better than a random child by at least 3
combined standard errors.
"""
import json
import math
import statistics as st
from collections import defaultdict
from functools import lru_cache
from pathlib import Path

import pytest

from lifeimage import characterise as ch
from lifeimage import layout as L
from lifeimage import levels as lv
from lifeimage.generators import life
from lifeimage.generators.params import ARCHETYPES
from lifeimage.render import basemap as bmod
from lifeimage.render import image as im

from conftest import link, make_card, make_row, membership

ROOT = Path(__file__).resolve().parent.parent


def jl(path):
    return [json.loads(l) for l in (ROOT / path).read_text(encoding="utf-8").splitlines() if l.strip()]


@lru_cache(maxsize=1)
def fine_cards():
    return tuple(jl("data/fine/fine_v1.jsonl"))


@lru_cache(maxsize=1)
def coarse_cards():
    return tuple(jl("data/coarse/seed_v3.jsonl"))


def children():
    """{coarse id: [fine card, ...]} by upstream link."""
    out = defaultdict(list)
    for c in fine_cards():
        for l in c["links"]:
            if l["rel"] == "upstream":
                out[l["id"]].append(c)
    return out


def upstream_of(card):
    return {l["id"]: l["weight"] for l in card["links"] if l["rel"] == "upstream"}


FINE_BY_ID = lambda: {c["id"]: c for c in fine_cards()}  # noqa: E731

# ---------- the small world for levels ----------

def small_world():
    s = make_card("s.x", links=[], axes=None)
    a = make_card("c.a", links=[link("s.x", weight=1.0)])
    b = make_card("c.b", links=[link("s.x", weight=1.0)])
    c = make_card("c.c", links=[link("s.x", weight=1.0)])
    f = lambda i, links: make_card(i, level="fine", axes=None, links=links)  # noqa: E731
    return [s, a, b, c, f("f.a1", [link("c.a")]), f("f.a2", [link("c.a")]),
            f("f.ab", [link("c.a", weight=0.5), link("c.b", weight=0.5)]), f("f.ov", [link("c.b", rel="overlap")])]


def fine_row(domain, magnitude=0.3, **over):
    over.setdefault("memberships", [membership(domain, "form"), membership(domain, "content")])
    return make_row(magnitude=magnitude, production="produced", valid_time="2026-01", record_time="2026-01", tier="measured", **over)


def level(world, rows):
    return lv.channel_levels(rows, world, lv.DEFAULT, asof="2026-06")["solid"]


def raw(world, rows):
    return lv.raw_sums(rows, world, lv.DEFAULT, asof="2026-06")["solid"]


# ---------- levels: imprints land on the named fine domain ----------

def test_a_row_naming_a_fine_domain_lights_that_domain_and_not_its_siblings_or_neighbours():
    got = level(small_world(), [fine_row("f.a1")])
    assert got["f.a1"]["green"] > 0
    assert "f.a2" not in got and "f.ab" not in got, "a sibling lit without being named"
    assert "c.b" not in got and "c.c" not in got, "colour bled to a neighbour"
    assert got["c.a"]["green"] > 0, "the upstream coarse field is lit by what its child holds"


def test_the_fine_level_keeps_the_imprint_less_the_bleed_to_its_coarse_field():
    w = small_world()
    r = raw(w, [fine_row("f.a1")])
    bleed = lv.DEFAULT.projection.bleed_fraction
    # the whole imprint reaches the coarse field, once: the child keeps 1 - bleed, the field gets the bleed plus what the child holds
    assert r["c.a"]["green"] == pytest.approx(r["f.a1"]["green"] / (1 - bleed), rel=1e-9)
    assert r["f.a1"]["green"] > 0 and r["c.a"]["green"] > r["f.a1"]["green"]


# ---------- levels: coarse aggregates its children ----------

def test_a_coarse_level_is_the_resaturated_sum_of_its_children_and_its_own_imprints():
    w = small_world()
    own = fine_row("c.a", 0.3)
    rows = [fine_row("f.a1", 0.5), fine_row("f.a2", 0.4), own]
    bleed = lv.DEFAULT.projection.bleed_fraction
    r = raw(w, rows)
    own_only = raw(w, [own])["c.a"]["green"]
    assert r["c.a"]["green"] == pytest.approx(own_only + (r["f.a1"]["green"] + r["f.a2"]["green"]) / (1 - bleed), rel=1e-9)
    got = level(w, rows)
    assert got["c.a"]["green"] == pytest.approx(lv.tone(r["c.a"]["green"]), rel=1e-9)
    assert got["c.a"]["green"] <= 1.0
    assert got["c.a"]["green"] < got["f.a1"]["green"] + got["f.a2"]["green"] + raw_level_of(own_only), "levels were added instead of luminosities"


def raw_level_of(s):
    return lv.tone(s)


def test_the_coarse_aggregate_is_exactly_the_children_sum_when_only_children_are_named():
    w = small_world()
    bleed = lv.DEFAULT.projection.bleed_fraction
    rows = [fine_row("f.a1", 0.5), fine_row("f.a2", 0.4)]
    r = raw(w, rows)
    # fine keeps 1 - bleed of each imprint; the coarse field receives the bleed plus the children's sums = all of it
    assert r["c.a"]["green"] == pytest.approx((r["f.a1"]["green"] + r["f.a2"]["green"]) / (1 - bleed), rel=1e-9)


def test_a_child_with_two_parents_gives_each_its_link_weight_and_overlap_gives_nothing():
    w = small_world()
    r = raw(w, [fine_row("f.ab", 0.5)])
    assert r["c.a"]["green"] == pytest.approx(r["c.b"]["green"], rel=1e-9), "equal link weights give equal shares"
    assert r["c.a"]["green"] == pytest.approx(r["f.ab"]["green"] / (1 - lv.DEFAULT.projection.bleed_fraction) * 0.5, rel=1e-9)
    ov = raw(w, [fine_row("f.ov", 0.5)])
    assert set(ov) == {"f.ov"}, "an overlap link neither bleeds nor aggregates"


def test_levels_stay_below_one_however_much_evidence_the_children_hold():
    w = small_world()
    rows = [fine_row("f.a1", 1.0) for _ in range(400)] + [fine_row("f.a2", 1.0) for _ in range(400)]
    for d, ch_ in level(w, rows).items():
        assert max(ch_["red"], ch_["green"], ch_["blue"]) <= 1.0, d


def test_an_unknown_fine_domain_is_refused():
    with pytest.raises(ValueError):
        level(small_world(), [fine_row("f.nope")])


# ---------- generator: events name fine domains ----------

POP = [("student", 19, 1), ("shift_worker", 41, 2), ("carer", 47, 3), ("small_business_owner", 46, 4), ("researcher", 43, 5),
       ("retiree", 75, 6), ("career_changer", 42, 7), ("generalist", 48, 8)]


@lru_cache(maxsize=None)
def persona(arch, age, seed, fine=True):
    return life.generate_persona(seed, arch, age, fine=fine) if not fine else life.generate_persona(seed, arch, age)


def event_rows(p):
    return [r for r in p.rows if r["channel"] != "prediction"]


def test_every_event_row_names_a_fine_domain_wherever_the_field_has_fine_children():
    kids = children()
    left_coarse = []
    for arch, age, seed in POP:
        for r in event_rows(persona(arch, age, seed)):
            left_coarse += [m["domain"] for m in r["memberships"] if m["domain"] in kids]
    assert left_coarse == [], f"{len(left_coarse)} memberships stay at a coarse field that has fine children: {sorted(set(left_coarse))[:5]}"


def test_a_fair_share_of_event_rows_names_a_fine_domain_and_the_rest_keep_coarse_fields():
    fine_ids = {c["id"] for c in fine_cards()}
    rows = [r for arch, age, seed in POP for r in event_rows(persona(arch, age, seed))]
    named = sum(any(m["domain"] in fine_ids for m in r["memberships"]) for r in rows)
    share = named / len(rows)
    assert share >= 0.45, f"{share:.2f} of {len(rows)} event rows name a fine domain"  # predicted 0.45-0.75; measured 0.96 (missed high: the templates use common fields)
    coarse_only = [r for r in rows if not any(m["domain"] in fine_ids for m in r["memberships"])]
    # Coarse-only rows were a transitional state: LI.54 (every field fine) makes an empty set the target, so the
    # invariant is conditional (lead, 2026-11-25, after the gap set left no template field without a fine child).
    known = {c["id"] for c in coarse_cards()}
    assert all(m["domain"] in known for r in coarse_only for m in r["memberships"])


def test_the_named_fine_domain_keeps_the_events_coarse_field_as_its_upstream():
    by = FINE_BY_ID()
    checked = 0
    for arch, age, seed in POP:
        p = persona(arch, age, seed)
        for e in p.events:
            for coarse, fine in e.get("fine", {}).items():
                assert coarse in upstream_of(by[fine]), (e["id"], coarse, fine)
                checked += 1
        evented = {f for e in p.events for f in e.get("fine", {}).values()}
        used = {m["domain"] for r in event_rows(p) for m in r["memberships"] if m["domain"] in by}
        assert used <= evented, "a row names a fine domain its event does not record"
    assert checked > 100


def test_rows_of_one_event_agree_on_the_fine_domain_and_weights_still_sum_to_one_per_relation():
    for arch, age, seed in POP:
        p = persona(arch, age, seed)
        for r in p.rows:
            by_rel = defaultdict(float)
            seen = set()
            for m in r["memberships"]:
                by_rel[m["rel"]] += m["weight"]
                assert (m["domain"], m["rel"]) not in seen
                seen.add((m["domain"], m["rel"]))
            assert all(abs(v - 1.0) < 1e-4 for v in by_rel.values()), by_rel
        for e in p.events:
            sets = {json.dumps(sorted((m["domain"], m["rel"]) for m in p.rows[i]["memberships"])) for i in e["rows"]}
            assert len(sets) <= 1, f"{e['id']}: its rows disagree on their memberships"


def test_the_choice_is_deterministic_by_seed_and_varies_across_seeds():
    a, b = life.generate_persona(31, "researcher", 43), life.generate_persona(31, "researcher", 43)
    assert a.rows == b.rows and a.events == b.events
    pick = lambda p: tuple(sorted({f for e in p.events for f in e.get("fine", {}).values()}))  # noqa: E731
    assert len({pick(life.generate_persona(s, "researcher", 43)) for s in range(31, 37)}) > 3


def test_naming_fine_domains_changes_nothing_but_the_memberships():
    for arch, age, seed in POP[:4]:
        on, off = persona(arch, age, seed), persona(arch, age, seed, fine=False)
        assert on.texts == off.texts and len(on.rows) == len(off.rows)
        strip = lambda rs: [{k: v for k, v in r.items() if k != "memberships"} for r in rs]  # noqa: E731
        assert strip(on.rows) == strip(off.rows), "magnitudes, tiers or dates moved when fine domains were named"
        assert [r["magnitude"] for r in on.rows] == [r["magnitude"] for r in off.rows]


def test_self_assessments_stay_at_coarse_fields_and_the_extraction_truth_is_read_at_the_coarse_level():
    from lifeimage.extract_metrics import load_synthetic
    from lifeimage.fine.cards import coarsen_rows, load_fine
    fine_ids = {c["id"] for c in fine_cards()}
    for arch, age, seed in POP[:4]:
        p = persona(arch, age, seed)
        assert not any(m["domain"] in fine_ids for r in p.rows if r["channel"] == "prediction" for m in r["memberships"])
    _personas, truth, _texts, _corro = load_synthetic(ROOT / "data/synthetic")
    assert not any(m["domain"] in fine_ids for rows in truth.values() for r in rows for m in r["memberships"]), \
        "a resume names what the text says: a field, so the truth is scored at the coarse level"
    stored = jl("data/synthetic/truth/p004.jsonl")
    assert any(m["domain"] in fine_ids for r in stored for m in r["memberships"]), "the stored truth is the claimed rows as they are"
    assert coarsen_rows(stored, load_fine()) == truth["p004"]


def tokens(s):
    import re
    return {w.rstrip("s") for w in re.findall(r"[a-z]{3,}", s.lower())} - {"and", "for", "the", "with", "other", "not", "except"}


def test_the_chosen_fine_domain_fits_the_events_wording_better_than_a_random_child():
    """Hypothesis: the chosen child shares more words with the event than the mean child of that field (direction: more;
    smallest effect that matters 0.02 words-share; z = 3 combined standard errors; paired by event)."""
    by, kids = FINE_BY_ID(), children()
    diffs = []
    for arch, age, seed in [(a, g, s) for a, g, s in POP] + [(a, g, s + 20) for a, g, s in POP]:
        p = life.generate_persona(seed, arch, age)
        for e in p.events:
            words = tokens(e["label"] + " " + " ".join(str(v) for v in e["detail"].values()))
            for coarse, fine in e.get("fine", {}).items():
                fit = lambda c: len(tokens(c["label"] + " " + c["description"]) & words) / max(1, len(tokens(c["label"])))  # noqa: E731
                cand = kids[coarse]
                if len(cand) > 1:
                    diffs.append(fit(by[fine]) - st.mean(fit(c) for c in cand))
    assert len(diffs) > 150
    m, se = st.mean(diffs), st.stdev(diffs) / math.sqrt(len(diffs))
    assert m > 0.02 and m > 3 * se, f"fit gain {m:.3f} (se {se:.3f}, n={len(diffs)})"


def test_the_persona_s_archetype_pulls_the_choice_toward_its_own_domains():
    """Two archetypes living the same event kind pick differently: over many seeds the chosen fine domains of a researcher
    and a shift worker differ in distribution (distinct sets for at least a tenth of the shared fields)."""
    sets = {a: defaultdict(set) for a in ("researcher", "shift_worker")}
    for a in sets:
        lo, hi = ARCHETYPES[a]["age_range"]
        for seed in range(60, 76):
            p = life.generate_persona(seed, a, (lo + hi) // 2)
            for e in p.events:
                for coarse, fine in e.get("fine", {}).items():
                    sets[a][coarse].add(fine)
    shared = set(sets["researcher"]) & set(sets["shift_worker"])
    assert shared
    differing = [c for c in shared if sets["researcher"][c] != sets["shift_worker"][c]]
    assert len(differing) >= 0.1 * len(shared)


# ---------- basemap: fine domains inside their main parent's arc, coarse arcs untouched ----------

@lru_cache(maxsize=1)
def worlds():
    return bmod.build_v0(), bmod.build_v0(fine=False)


def test_fine_domains_sit_inside_the_arc_of_their_main_parent_and_tile_it():
    with_fine, _ = worlds()
    placed = with_fine.fine
    assert len(placed) == len(fine_cards()) == len(set(placed)), "every fine domain is placed once"
    by = FINE_BY_ID()
    from lifeimage.fine.placement import main_parent
    groups = defaultdict(list)
    for i, s in placed.items():
        card = by[i]
        links = [(l["id"], l["weight"]) for l in card["links"] if l["rel"] == "upstream"] or [(l["id"], l["weight"]) for l in card["links"] if l["rel"] == "overlap"]
        parent = with_fine.slices[main_parent({"parents": links})]
        assert s.ring == "fine"
        assert L.arc_inside((s.start, s.start + s.width), (parent.start, parent.start + parent.width)), i
        groups[parent.id].append(s)
    for pid, ss in groups.items():
        p = with_fine.slices[pid]
        assert math.fsum(s.width for s in ss) == pytest.approx(p.width, rel=1e-6), f"{pid}: children do not tile the parent's arc"


def test_adding_the_fine_level_leaves_every_coarse_arc_where_it_was():
    with_fine, without = worlds()
    assert set(with_fine.slices) == set(without.slices)
    for i, s in without.slices.items():
        t = with_fine.slices[i]
        assert (t.start, t.width, t.r0, t.r1) == pytest.approx((s.start, s.width, s.r0, s.r1), abs=1e-9), i


def test_fine_slices_lie_outside_the_coarse_rim_in_their_own_rings_and_take_a_radial_band():
    with_fine, _ = worlds()
    rim = max(s.r1 for s in with_fine.slices.values())
    assert all(s.r0 >= rim for s in with_fine.fine.values()), "a fine slice overlaps the coarse rings"
    assert with_fine.extent > max(s.r1 for s in with_fine.fine.values())
    assert len({round(s.r0, 3) for s in with_fine.fine.values()}) > 20, "fine radii must follow the composite, not one band"
    log = []
    bmod.build_v0(log=log)
    assert any(d["mechanism"] == "radius_judged" for d in log), "mechanical fine radii are logged"


def test_angle_stability_holds_when_a_fine_domain_is_added_later():
    from lifeimage.fine.placement import add_fine
    with_fine, _ = worlds()
    parent_arcs = {i: (s.start, s.start + s.width) for i, s in with_fine.slices.items()}
    arcs = {i: (s.start, s.start + s.width) for i, s in with_fine.fine.items()}
    known = [{"id": i, "parents": [(l["id"], l["weight"]) for l in c["links"] if l["rel"] == "upstream"]} for i, c in FINE_BY_ID().items()
             if i in arcs and any(l["rel"] == "upstream" for l in c["links"])]
    arcs = {i: a for i, a in arcs.items() if i in {k["id"] for k in known}}
    new = [{"id": "f.new_arrival", "parents": [("c.physics", 1.0)]}]
    after = add_fine(arcs, parent_arcs, known, new)
    for i, a in arcs.items():
        assert L.circ_diff(L.arc_centre(a), L.arc_centre(after[i])) < L.EPSILON, i
    assert L.arc_inside(after["f.new_arrival"], parent_arcs["c.physics"])


# ---------- renderers: evidence at the fine level is visible ----------

def a_fine_pair():
    """Two sibling fine domains with the same single parent that has a fine child at all."""
    for coarse, kids in sorted(children().items()):
        single = [c["id"] for c in kids if list(upstream_of(c)) == [coarse] and coarse.startswith("c.")]
        if len(single) >= 2:
            return coarse, single[0], single[1]
    raise AssertionError("no field with two single-parent fine children")


def all_cards():
    return list(coarse_cards()) + list(fine_cards())


def drawn(svg, ident):
    import re
    m = re.search(r'<path d="[^"]+" fill="(#[0-9a-f]{6})"><title>' + re.escape(ident) + "</title></path>", svg)
    return m.group(1) if m else None


def test_the_static_image_lights_the_named_fine_slice_and_not_its_sibling():
    coarse, a, b = a_fine_pair()
    rows = [fine_row(a, 0.6, memberships=[membership(a, "form"), membership(a, "content")])]
    bm = bmod.build_v0()
    cv = im.channel_values(rows, all_cards(), asof="2026-06")
    svg = im.render_svg("fine", cv, bm)
    assert drawn(svg, a) not in (None, "#000000"), f"{a} is not drawn lit"
    assert drawn(svg, b) is None, "a sibling was drawn lit without being named"
    assert drawn(svg, coarse) not in (None, "#000000"), "the parent field shows what its child holds"


def test_the_static_image_makes_room_for_the_outer_ring():
    bm = bmod.build_v0()
    svg = im.render_svg("x", {}, bm)
    import re
    vb = [float(x) for x in re.search(r'viewBox="([^"]+)"', svg).group(1).split()]
    assert -vb[0] >= bm.extent and vb[2] >= 2 * bm.extent, "the viewBox clips the fine ring"


def test_the_image_state_carries_fine_slices_and_marks_the_named_one_touched():
    coarse, a, b = a_fine_pair()
    rows = [fine_row(a, 0.6)]
    st_ = ch.image_state(rows, ch.world_basemap(), asof="2026-06")
    sl = {s.id: s for s in st_.slices}
    assert sl[a].ring == "fine" and sl[a].touched and max(sl[a].solid) > 0
    assert not sl[b].touched and max(sl[b].solid) == 0
    assert sl[coarse].touched, "a field is touched when a child of it is named"


def test_features_of_the_coarse_image_do_not_depend_on_the_fine_ring():
    p = persona("researcher", 43, 5)
    rows, asof = p.rows, p.as_of
    full = ch.record_for({"id": "t"}, rows, asof)[0]
    bm = ch.world_basemap()
    base = ch.image_state(rows, bm, asof)
    coarse_only = ch.State([s for s in base.slices if s.ring != "fine"], base.asof)
    again = ch.features(coarse_only)
    for k in set(ch.BASE_FEATURES) - {"dimmed_share"}:
        a, b = full[k], again[k]
        assert (math.isnan(a) and math.isnan(b)) or a == pytest.approx(b, rel=1e-12), k


def test_fine_descriptors_see_the_fine_ring_only():
    p = persona("researcher", 43, 5)
    rec = ch.record_for({"id": "t"}, p.rows, p.as_of)[0]
    assert 0 < rec["fine_lit_share"] <= 1 and rec["fine_n_lit"] > 0
    empty = ch.record_for({"id": "t"}, [r for r in p.rows if r["channel"] == "prediction"], p.as_of)[0]
    assert empty["fine_n_lit"] == 0


# ---------- the interactive viewer: coarse, fine, rows ----------

@lru_cache(maxsize=1)
def ictx():
    from lifeimage.render import interactive as it
    return it.context()


def model_of(spec, disclosure):
    import re
    from lifeimage.render import interactive as it
    html = it.build_viewer(spec, ictx(), disclosure)
    return json.loads(re.search(r'<script id="data" type="application/json">(.*?)</script>', html, re.S).group(1))


def test_rows_attach_at_the_fine_slice_they_name_and_the_zoom_path_goes_coarse_fine_rows():
    from lifeimage.render import interactive as it
    m = model_of(it.spec_single(ictx(), "p023"), "full")
    fine_idx = [i for i, s in enumerate(m["slices"]) if s["r"] == 2 and s["q"] >= 0 and str(i) in m["rows"]]
    assert fine_idx, "no evidence row sits at a fine slice"
    i = fine_idx[0]
    s = m["slices"][i]
    assert s["p"] >= 0 and m["slices"][s["p"]]["r"] == 0, "a fine slice names its sector"
    path = it.zoom_path(m, str(i))
    assert [p["depth"] for p in path] == [0, 1, 2, 3, 4, 5]  # disc, sector, field, fine, evidence, row
    assert path[3]["slice"]["r"] == 2 and path[2]["slice"]["r"] == 1
    # the field still lists every row of its children, so its contributions sum to its level
    field = path[2]["slice"]
    j = m["slices"].index(field)
    assert str(j) in m["rows"] and len(m["rows"][str(j)]) >= len(m["rows"][str(i)])


def test_the_none_file_carries_the_fine_ring_as_pattern_only():
    from lifeimage.render import interactive as it
    m = model_of(it.spec_single(ictx(), "p023"), "none")
    assert any(s["r"] == 2 for s in m["slices"])
    assert all(set(s) <= {"r", "a", "w", "i0", "i1"} for s in m["slices"])
    assert m["ext"] > 1.25


def test_contributions_at_a_fine_slice_sum_to_its_level():
    from lifeimage.render import interactive as it
    m = model_of(it.spec_single(ictx(), "p023"), "full")
    view = m["views"][0]["lv"]
    checked = 0
    for idx, rows in m["rows"].items():
        if m["slices"][int(idx)]["r"] != 2:
            continue
        for ch_, k in (("red", 0), ("green", 1), ("blue", 2)):
            assert math.fsum(r["v"].get(ch_, 0.0) for r in rows) == pytest.approx(view[idx][k], abs=2e-3), (idx, ch_)
        checked += 1
    assert checked >= 5


def test_the_live_viewer_walks_field_fine_domain_rows_in_a_browser(tmp_path):
    import re
    import shutil
    import subprocess
    from lifeimage.render import interactive as it
    chrome = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser")
    if chrome is None:
        pytest.skip("no headless browser")
    spec = it.spec_single(ictx(), "p023")
    html = it.build_viewer(spec, ictx(), "full")
    m = json.loads(re.search(r'<script id="data" type="application/json">(.*?)</script>', html, re.S).group(1))
    i = next(k for k, s in enumerate(m["slices"]) if s["r"] == 2 and s["q"] >= 0 and str(k) in m["rows"])
    js = ("<script>(function(){var N=window.__li.nav,R={};N.select(%d);R.fine=N.depth();R.state=N.state().fine;N.up();R.field=N.depth();"
          "N.select(%d);N.down();R.rows=N.depth();N.down();R.row=N.depth();N.up();R.back=N.depth();N.sync();"
          "var pre=document.createElement('pre');pre.id='selftest';pre.textContent=JSON.stringify(R);document.body.appendChild(pre)})()</script></body>") % (i, i)
    page = tmp_path / "v.html"
    page.write_text(html.replace("</body>", js), encoding="utf-8")
    out = subprocess.run([chrome, "--headless=new", "--no-sandbox", "--disable-gpu", "--virtual-time-budget=4000", "--dump-dom", f"file://{page}"],
                         capture_output=True, text=True, timeout=90).stdout
    got = json.loads(re.search(r'<pre id="selftest">(.*?)</pre>', out, re.S).group(1).replace("&quot;", '"'))
    assert got["fine"] == 3 and got["state"] == i and got["field"] == 2 and got["rows"] == 4 and got["row"] == 5 and got["back"] == 4, got
