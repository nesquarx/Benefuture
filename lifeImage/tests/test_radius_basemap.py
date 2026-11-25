"""The basemap places each domain's radial band by its radius composite (LI.26); depth is the logged fallback."""
import warnings

import pytest

from lifeimage import degradation
from lifeimage.render import basemap as bmod

from conftest import make_card, link


def _cards(composites):
    out = [make_card("s.a", axes=None, links=[], radius=None if composites is None else {
        "complexity": 0.1, "difficulty": 0.1, "specificity": 0.1, "composite": 0.1})]
    for n, c in enumerate(composites or [None, None, None]):
        r = None if c is None else {"complexity": c, "difficulty": c, "specificity": c, "composite": c}
        out.append(make_card(f"c.f{n}", links=[link("s.a")], radius=r,
                             axes={"abstract_tangible": 0.5 - 0.4 * n, "personal_global": 0.3 * n - 0.3}))
    return out


def _build(cards):
    axes = {c["id"]: {**c["axes"], "votes": 3, "source": "v3"} for c in cards if c["axes"]}
    return bmod.build(cards, axes, [])


def test_fields_with_a_higher_composite_sit_further_out():
    bm = _build(_cards([0.1, 0.5, 0.9]))
    r0 = [bm.slices[f"c.f{n}"].r0 for n in range(3)]
    assert r0[0] < r0[1] < r0[2], f"fields collapsed onto one band: {r0}"


def test_the_shipped_basemap_spreads_its_fields_over_the_ring():
    bm = bmod.build_v0()
    fields = [s for s in bm.slices.values() if s.ring == "field"]
    assert len({round(s.r0, 4) for s in fields}) > 10, "every field sits on the same band: no radius from composite"


def test_a_band_stays_inside_its_ring():
    bm = _build(_cards([0.0, 0.5, 1.0]))
    for s in bm.slices.values():
        lo, hi = bmod.FIELD_RING if s.ring == "field" else bmod.SECTOR_RING
        assert lo - 1e-9 <= s.r0 < s.r1 <= hi + 1e-9


def test_missing_composites_fall_back_to_depth_and_say_so():
    degradation.reset_warned()
    log = []
    cards = _cards(None)
    axes = {c["id"]: {**c["axes"], "votes": 3, "source": "v3"} for c in cards if c["axes"]}
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        bm = bmod.build(cards, axes, [], log=log)
    assert {(s.r0, s.r1) for s in bm.slices.values() if s.ring == "field"} == {bmod.FIELD_RING}
    assert any(d["mechanism"] == "radius_composite" for d in log), "the depth fallback was silent"
