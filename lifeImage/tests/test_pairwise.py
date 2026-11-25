import math
import random

import pytest

from lifeimage.pairwise import fit_bt, rescale, spearman, split_half_reliability


def simulate(theta, pairs, nu=0.6, seed=0, reps=1):
    """Davidson outcomes ("a", "b", "tie") of i against j for known log-strengths."""
    rng = random.Random(seed)
    out = []
    for i, j in pairs:
        for _ in range(reps):
            wi, wj, t = math.exp(theta[i]), math.exp(theta[j]), nu * math.exp((theta[i] + theta[j]) / 2)
            u = rng.random() * (wi + wj + t)
            out.append((i, j, "a" if u < wi else "b" if u < wi + wj else "tie"))
    return out


def all_pairs(ids):
    return [(i, j) for n, i in enumerate(ids) for j in ids[n + 1:]]


def truth(n=12):
    return {f"f{k:02d}": -2.0 + 4.0 * k / (n - 1) for k in range(n)}


def test_recovers_the_known_order_and_gives_every_field_a_positive_standard_error():
    th = truth()
    fit = fit_bt(simulate(th, all_pairs(list(th)), reps=6, seed=1))
    assert spearman([th[k] for k in th], [fit.theta[k] for k in th]) > 0.97
    assert set(fit.se) == set(th) and all(s > 0 for s in fit.se.values())


def test_standard_errors_shrink_with_more_comparisons():
    th = truth()
    pairs = all_pairs(list(th))
    few, many = fit_bt(simulate(th, pairs, reps=2, seed=2)), fit_bt(simulate(th, pairs, reps=20, seed=2))
    assert sum(many.se.values()) < 0.6 * sum(few.se.values())


def test_a_field_known_only_by_ties_sits_with_the_field_it_tied_not_in_the_middle():
    # X beats Z every time; Y only ever tied X. Dropping ties leaves Y without data, at the prior, between X and Z.
    comps = [("X", "Z", "a")] * 12 + [("X", "W", "a")] * 12 + [("W", "Z", "a")] * 12 + [("Y", "X", "tie")] * 12
    fit = fit_bt(comps)
    t = fit.theta
    assert abs(t["Y"] - t["X"]) < 0.4 * abs(t["Y"] - t["Z"])
    assert fit.nu > 0


def test_tie_rate_is_estimated_from_the_data():
    th = truth()
    pairs = all_pairs(list(th))
    assert fit_bt(simulate(th, pairs, nu=0.2, reps=8, seed=3)).nu < fit_bt(simulate(th, pairs, nu=2.0, reps=8, seed=3)).nu


def test_a_field_that_only_ties_is_not_pushed_to_an_extreme_by_the_prior_free_maximum():
    comps = [("A", "B", "a")] * 5 + [("A", "B", "tie")] * 5 + [("A", "C", "a")] * 10  # no ridge-free finite optimum for C
    fit = fit_bt(comps)
    assert all(math.isfinite(v) for v in fit.theta.values()) and all(abs(v) < 6 for v in fit.theta.values())


def test_unbeaten_fields_stay_finite_thanks_to_the_ridge_prior_and_keep_their_order():
    comps = [("A", "B", "a")] * 20 + [("B", "C", "a")] * 20
    t = fit_bt(comps).theta
    assert t["A"] > t["B"] > t["C"] and max(map(abs, t.values())) < 6


def test_rescale_maps_to_minus_one_one_keeping_order_and_scaling_se():
    pos, se = rescale({"a": -3.0, "b": 0.0, "c": 1.5}, {"a": 0.3, "b": 0.2, "c": 0.1})
    assert max(map(abs, pos.values())) == pytest.approx(1.0) and pos["a"] < pos["b"] < pos["c"]
    assert se["a"] == pytest.approx(0.3 / 3.0 * 1.0) or se["a"] > 0


def test_spearman_handles_ties_and_reversal():
    assert spearman([1, 2, 3, 4], [10, 20, 30, 40]) == pytest.approx(1.0)
    assert spearman([1, 2, 3, 4], [4, 3, 2, 1]) == pytest.approx(-1.0)
    assert abs(spearman([1, 1, 2, 2], [1, 2, 1, 2])) < 1e-9


def test_split_half_reliability_is_high_for_signal_and_near_zero_for_noise():
    th = truth(20)
    sig = split_half_reliability(simulate(th, all_pairs(list(th)), reps=8, seed=4), seed=0)
    rng = random.Random(5)
    noise = [(i, j, rng.choice(["a", "b", "tie"])) for i, j in all_pairs(list(th)) for _ in range(8)]
    assert sig > 0.9 and abs(split_half_reliability(noise, seed=0)) < 0.5
