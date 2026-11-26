"""Circular seriation (LI.60): the global ring order maximising adjacent similarity under a displacement price and guard.

Outcome tests, red first on the current code: the shipped order has the named outliers of LI.55 adjacent (arts beside statistics,
housing beside crop farming), and the seriation removes them. Counterexamples: with a very large lambda the order stays the prior
order (the arms cannot invent displacement); with lambda 0 it is free, bounded only by the guard.
"""
import math
from pathlib import Path

import numpy as np
import pytest

from lifeimage import seriation as sr
from lifeimage.governed import GOVERNED, governed
from lifeimage.layout import circ_diff

ROOT = Path(__file__).resolve().parent.parent
N = 24


def ring(n=N, gap=15.0, link=0.0):
    """n slots `gap` degrees apart, the prior equal to the slots (identity order, zero displacement); in each block of 8 fields i and
    i + 4 are similar (strength 1), so adjacency can only rise by displacing fields (up to 3 slots, 45 degrees)."""
    slots = np.arange(n) * gap
    D = np.array([[circ_diff(slots[p], slots[i]) for p in range(n)] for i in range(n)])
    S = np.zeros((n, n))
    for i in range(n):
        if i % 8 < 4:
            S[i, i + 4] = S[i + 4, i] = 1.0
    S[0, 1] = S[1, 0] = link
    return S, D


def displacement(order, D):
    return np.array([D[f, p] for p, f in enumerate(order)])


def test_the_identity_order_has_no_adjacent_similarity_before():
    S, D = ring()
    assert sr.cost(list(range(N)), S, sr.price(D, 0.0, 180.0)) == 0.0  # no adjacent pair is similar: the muddled outcome to fix


def test_a_free_lambda_zero_order_gathers_similar_fields_within_the_guard():
    S, D = ring()
    o, info = sr.seriate(S, D, list(range(N)), lam=0.0, guard=90.0, restarts=3)
    assert -sr.cost(o, S, sr.price(D, 0.0, 90.0)) >= 9  # most of the 12 similar pairs end up adjacent
    d = displacement(o, D)
    assert d.max() <= 90.0 + 1e-9 and d.max() > 15.0  # free to move, but only within the guard


def test_lambda_zero_with_a_wide_guard_is_unbounded_by_price():
    S, D = ring()
    o, _ = sr.seriate(S, D, list(range(N)), lam=0.0, guard=180.0, restarts=3)
    assert displacement(o, D).max() > 15.0


def test_a_very_large_lambda_keeps_the_prior_order():
    S, D = ring()
    o, _ = sr.seriate(S, D, list(range(N)), lam=1e6, guard=180.0, restarts=3)
    assert o == list(range(N))


def test_guard_is_never_exceeded():
    S, D = ring()
    for guard in (15.0, 30.0, 60.0):
        o, _ = sr.seriate(S, D, list(range(N)), lam=0.0, guard=guard, restarts=3)
        assert displacement(o, D).max() <= guard + 1e-9


def test_the_split_limit_holds():
    S, D = ring()
    first_half = lambda o: sum(1 for p, f in enumerate(o) if (f < N // 2) != (p < N // 2))  # fields leaving their half
    o, _ = sr.seriate(S, D, list(range(N)), lam=0.0, guard=180.0, restarts=3, split_of=first_half, split_limit=0)
    assert first_half(o) == 0


def test_seriation_is_deterministic():
    S, D = ring(link=0.5)
    a, ia = sr.seriate(S, D, list(range(N)), lam=0.002, guard=120.0, restarts=5)
    b, ib = sr.seriate(S, D, list(range(N)), lam=0.002, guard=120.0, restarts=5)
    assert a == b and ia == ib


def test_named_outliers_are_found_in_a_ring_order():
    order = ["c.x", "c.statistics_data", "c.arts_humanities_studies", "c.housing_search", "c.horticulture_farming", "c.y"]
    out = sr.named_outliers(order)
    assert out["arts_religion_math_stats"] == [("c.statistics_data", "c.arts_humanities_studies")]
    assert out["housing_agriculture"] == [("c.housing_search", "c.horticulture_farming")]
    assert sr.named_outliers(["c.mathematics", "c.x", "c.visual_arts", "c.y"]) == {"arts_religion_math_stats": [], "housing_agriculture": []}


def test_governed_values_are_listed_with_sources():
    names = [n for n in GOVERNED if n.startswith("layout_sim.seriation_")]
    assert len(names) == 4 and all(GOVERNED[n]["source"].strip() for n in names)
    assert governed("layout_sim.seriation_guard") == governed("layout_sim.shift_max")
    assert math.isclose(governed("layout_sim.seriation_lambda") * governed("layout_sim.seriation_guard"), 1.0)  # a guard-sized shift costs one adjacency


# ---- the real coarse map ----

@pytest.fixture(scope="module")
def real():
    ctx = sr.context(ROOT)
    angles, order_c, tiled, info = sr.run_arm(ctx)
    return ctx, angles, order_c, tiled, info


def test_shipped_order_has_the_named_outliers_adjacent_now(real):
    ctx = real[0]
    out = sr.named_outliers(ctx["shipped_order"])
    assert out["arts_religion_math_stats"] == [("c.statistics_data", "c.arts_humanities_studies")]
    assert out["housing_agriculture"] == [("c.horticulture_farming", "c.housing_search")]  # the undesired outcome holds on the shipped build


def test_seriation_removes_the_named_outliers(real):
    out = sr.named_outliers(real[2])
    assert out == {"arts_religion_math_stats": [], "housing_agriculture": []}


def test_seriation_raises_adjacent_similarity_and_covers_more_pairs(real):
    ctx, _, order_c, _, _ = real
    a, c = sr.coherence(ctx["shipped_order"], ctx["sig"]), sr.coherence(order_c, ctx["sig"])
    assert c["mean_similarity"] >= 1.2 * a["mean_similarity"]
    assert c["no_signal_share"] <= 0.9 * a["no_signal_share"]


def test_seriation_covers_every_field_once_and_tiles(real):
    ctx, angles, order_c, tiled, _ = real
    assert sorted(order_c) == sorted(ctx["fields"]) and len(set(order_c)) == 247
    assert math.isclose(sum(s.width for s in tiled.slices.values() if s.ring == "field"), 360.0, abs_tol=1e-6)
    by_angle = sorted(angles, key=lambda k: angles[k])
    k = order_c.index(by_angle[0])
    assert order_c[k:] + order_c[:k] == by_angle  # tiling keeps the seriated ring order (up to where the ring starts)


def test_seriation_keeps_slots_within_the_guard_and_sectors_not_split_more(real):
    ctx, angles, order_c, tiled, info = real
    slot_shift = [circ_diff(angles[i], ctx["prior"][i]) for i in ctx["fields"]]
    assert max(slot_shift) <= governed("layout_sim.seriation_guard") + 1e-9
    st = sr.stability(tiled.slices, order_c, ctx)
    assert st["fragmentation"]["sectors_split"] <= sr.fragmentation(ctx["shipped_order"], ctx["sector_of"])["sectors_split"]


def test_real_seriation_never_costs_more_than_the_shipped_start(real):
    info = real[4]
    start = next(r for r in info["runs"] if r["start"] == "shipped")
    assert info["cost"] <= start["cost"] + 1e-9
