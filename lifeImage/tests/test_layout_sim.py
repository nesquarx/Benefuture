"""Layout simulation (LI.55): fields sort themselves by attraction while the axes stay the prior.

Outcome tests, red first against a stub whose `relax` returns the axes angles unchanged (the muddled outcome: planted
clusters stay interleaved). Acceptance: the simulation reunites two planted clusters scrambled by noisy axes while every
node stays within a stated shift of its axes angle; the real data tiles, deterministically. Counterexamples: with every
attraction zero the result is the axes order (the simulation invents no structure); malformed inputs are rejected.
"""
import json
import math
import random
from pathlib import Path

import numpy as np
import pytest

from lifeimage import layout_sim as ls
from lifeimage.governed import GOVERNED, governed
from lifeimage.layout import circ_diff
from lifeimage.layout_sim import wrap
from lifeimage.render.basemap import slice_ring

ROOT = Path(__file__).resolve().parent.parent
N = 24
SAME_SHARE_AFTER = 0.85  # smallest adjacent same-cluster share after the simulation (random interleaving gives about 0.5)
SAME_SHARE_BEFORE_MAX = 0.8  # the scrambled axes order must be this muddled for the test to mean anything
SHIFT_LIMIT = 85.0  # degrees any node may move from its axes angle


def planted(n=N, seed=3, links_per=5, noise=30.0, width=4.0):
    """Two clusters of n/2 nodes, truly 60 degrees apart (centres 30 and 90), whose axes angles carry Gaussian noise (sd
    `noise` degrees) so they interleave along the boundary. Returns prior angles, cluster labels, attraction, widths."""
    rng = random.Random(seed)
    h = n // 2
    cluster = [0] * h + [1] * (n - h)
    true = [(k + 0.5) * 60 / h for k in range(h)] + [60 + (k + 0.5) * 60 / (n - h) for k in range(n - h)]
    prior = np.array([x + rng.gauss(0, noise) for x in true])
    attract = np.zeros((n, n))
    for i in range(n):
        same = [j for j in range(n) if j != i and cluster[j] == cluster[i]]
        for j in rng.sample(same, links_per):
            attract[i, j] = attract[j, i] = 1.0
    return prior, cluster, ls.normalise_attraction(attract), np.full(n, width)


def same_share(angles, cluster):
    order = np.argsort(np.asarray(angles) % 360, kind="stable")
    pairs = [(order[k], order[(k + 1) % len(order)]) for k in range(len(order))]
    return sum(cluster[a] == cluster[b] for a, b in pairs) / len(pairs)


def shifts(angles, prior):
    return [circ_diff(a, p) for a, p in zip(angles, prior)]


def test_scrambled_axes_are_muddled_before():
    prior, cluster, _, _ = planted(seed=6)
    assert same_share(prior, cluster) < SAME_SHARE_BEFORE_MAX


@pytest.mark.parametrize("seed", [3, 5, 6, 7])
def test_simulation_reunites_planted_clusters_within_shift_limit(seed):
    prior, cluster, attract, widths = planted(seed=seed)
    out = ls.relax(prior, attract, widths)
    assert same_share(out, cluster) >= SAME_SHARE_AFTER
    assert max(shifts(out, prior)) <= SHIFT_LIMIT


def test_zero_attraction_keeps_the_axes_order_and_invents_no_structure():
    prior, cluster, attract, widths = planted()
    prior = np.sort(prior) + np.arange(N) * 5.0  # spaced beyond their widths: nothing pushes either
    out = ls.relax(prior, np.zeros_like(attract), widths)
    assert list(np.argsort(out % 360)) == list(np.argsort(prior % 360))
    assert np.allclose(out, prior % 360, atol=1e-6)


def test_zero_attraction_keeps_order_when_slices_crowd():
    rng = random.Random(1)
    prior = np.array(sorted(rng.uniform(0, 20) for _ in range(30)))  # 30 nodes in 20 degrees, widths overlap heavily
    out = ls.relax(prior, np.zeros((30, 30)), np.full(30, 3.0))
    flat = wrap(out - prior.mean())  # unwrapped around the stretch (spreading may cross 0)
    assert list(np.argsort(flat, kind="stable")) == list(range(30))  # repulsion spreads them, never reorders
    assert np.diff(flat).min() > 0
    assert max(shifts(out, prior)) <= governed("layout_sim.shift_max")


def test_stronger_polar_spring_holds_nodes_closer_to_the_axes():
    prior, cluster, attract, widths = planted()
    loose = ls.relax(prior, attract, widths, k_polar=0.3)
    stiff = ls.relax(prior, attract, widths, k_polar=5.0)
    assert np.mean(shifts(stiff, prior)) < np.mean(shifts(loose, prior))


def test_hard_shift_limit_holds_under_overwhelming_attraction():
    prior, cluster, attract, widths = planted()
    out = ls.relax(prior, attract * 100, widths, k_polar=0.01, shift_max=10.0)
    assert max(shifts(out, prior)) <= 10.0 + 1e-9


def test_relax_is_deterministic():
    prior, cluster, attract, widths = planted()
    assert np.array_equal(ls.relax(prior, attract, widths), ls.relax(prior, attract, widths))


@pytest.mark.parametrize("bad", ["asym", "neg", "nan", "shape", "width0", "prior_nan"])
def test_relax_rejects_malformed_input(bad):
    prior, cluster, attract, widths = planted(n=6, links_per=2)
    if bad == "asym":
        attract[0, 1] = attract[1, 0] + 1
    elif bad == "neg":
        attract[0, 1] = attract[1, 0] = -1
    elif bad == "nan":
        attract[0, 1] = attract[1, 0] = float("nan")
    elif bad == "shape":
        attract = attract[:5]
    elif bad == "width0":
        widths = widths.copy()
        widths[2] = 0
    else:
        prior = prior.copy()
        prior[0] = float("nan")
    with pytest.raises(ValueError):
        ls.relax(prior, attract, widths)


def test_governed_values_are_listed_with_sources_and_the_polar_stiffness_is_derived():
    names = [n for n in GOVERNED if n.startswith("layout_sim.")]
    assert len(names) >= 15 and all(GOVERNED[n]["source"].strip() for n in names)
    assert math.isclose(governed("layout_sim.k_polar"), governed("layout_sim.pull_cap") / governed("layout_sim.shift_budget"))


# ---- signals ----

def _cards():
    from conftest import link, make_card
    mk = lambda i, label, desc, links: make_card(i, label=label, description=desc, aliases=[], links=links, axes=None)
    return [
        mk("s.a", "Sector", "d", []),
        mk("c.one", "Cooking food", "Preparing meals and food at home", [link("s.a"), link("c.two", "overlap")]),
        mk("c.two", "Nutrition diet", "Eating food and diet", [link("s.a")]),
        mk("c.three", "Quantum physics", "Particles and fields", [link("s.a")]),
        mk("c.four", "Statistics", "Data and inference", [link("c.three")]),
    ]


def _fine():
    from conftest import link, make_card
    return [make_card("f.x", label="Meal planning", description="x", aliases=[], links=[link("c.one"), link("c.two")], level="fine"),
            make_card("f.y", label="Lone", description="y", aliases=[], links=[link("c.three")], level="fine")]


def test_signal_sources_count_pairs_and_report_coverage():
    comem = [{"a": "c.one", "b": "c.two", "p": 0.4, "support": 5, "type_i": "x", "type_j": "y"},
             {"a": "c.one", "b": "c.three", "p": 0.9, "support": 2, "type_i": "x", "type_j": "y"}]  # below the support floor
    sig = ls.signals(_cards(), _fine(), comem)
    ids = sig.ids
    assert ids == ["c.four", "c.one", "c.three", "c.two"]
    i = {k: n for n, k in enumerate(ids)}
    assert sig.sources["overlap"][i["c.one"], i["c.two"]] > 0 and sig.sources["overlap"][i["c.two"], i["c.one"]] > 0
    assert sig.sources["upstream"][i["c.four"], i["c.three"]] > 0
    assert sig.sources["comembership"][i["c.one"], i["c.two"]] > 0
    assert sig.sources["comembership"][i["c.one"], i["c.three"]] == 0  # support 2 < floor
    assert sig.sources["fine"][i["c.one"], i["c.two"]] > 0 and sig.sources["fine"][i["c.one"], i["c.three"]] == 0
    assert sig.sources["text"][i["c.one"], i["c.two"]] > sig.sources["text"][i["c.one"], i["c.three"]]  # food with food
    assert set(sig.coverage) == {"overlap", "upstream", "comembership", "fine", "text", "judged"}
    assert sig.coverage["overlap"]["pairs"] == 1 and sig.coverage["fine"]["pairs"] == 1
    assert [g[0] for g in sig.groups] == [[i["c.one"], i["c.three"], i["c.two"]]] or len(sig.groups) == 1
    assert np.allclose(sig.combined, sig.combined.T) and np.all(np.diag(sig.combined) == 0)


def test_signals_are_deterministic():
    a, b = ls.signals(_cards(), _fine(), []), ls.signals(_cards(), _fine(), [])
    assert np.array_equal(a.combined, b.combined)


# ---- the real coarse map ----

@pytest.fixture(scope="module")
def result():
    return ls.compute(ROOT)


def test_real_result_tiles_the_circle(result):
    items = sorted(((i, v["angle"]) for i, v in result["fields"].items()), key=lambda kv: kv[1])
    assert [i for i, _ in items] == result["order"]
    tiles = slice_ring(items, {i: 1.0 for i, _ in items}, 0.25)
    assert math.isclose(sum(w for _, w in tiles.values()), 360.0, abs_tol=1e-6)
    assert len(tiles) == len(result["fields"]) == 247


def test_real_result_is_deterministic(result):
    assert json.dumps(ls.compute(ROOT), sort_keys=True) == json.dumps(result, sort_keys=True)


def test_real_result_stays_near_the_axes_and_does_not_fragment_more(result):
    st = result["metrics"]["stability"]
    assert st["max_state_shift"] <= governed("layout_sim.shift_max") + 1e-9
    assert st["fragmentation"]["after"]["sectors_split"] <= st["fragmentation"]["before"]["sectors_split"]


def test_real_result_brings_signal_pairs_closer(result):
    # Restated (lead, 2026-11-25): with the 1503-card fine level the relaxed order no longer beats the shipped order on
    # mean adjacent similarity (0.301 -> 0.276) or no-signal share (0.733 -> 0.781). The shipped build breaks its 178
    # tied fields by parent angle (+0.079 over an id tie-break); the relaxation beats the id-tie-broken prior (0.221 ->
    # 0.276) but not that. Recorded in data/gold/layout_sim_predictions.md; the simulated layout is not adopted.
    m = result["metrics"]["coherence"]
    assert m["after"]["mean_rank_distance"] < m["before"]["mean_rank_distance"]


def test_coverage_is_reported_per_source(result):
    cov = result["coverage"]
    assert set(cov) == {"overlap", "upstream", "comembership", "fine", "text", "judged"}
    assert all(0 < c["pairs"] and 0 < c["fields"] <= 247 for k, c in cov.items() if k != "judged")  # judged: empty until answers exist
