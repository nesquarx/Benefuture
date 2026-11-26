"""Sequence head: hard constraints at zero tolerance, soft age and order statistics against calibration (significance rule, paired seeds).
Counterexamples: the shuffled-order generator (increment 1's gaming case) passes the rate head and fails the sequence head; a generator
whose births ignore marriage is flagged softly, not as a hard failure."""
import warnings

import pytest

from lifeimage.eventgen import calibration as cal
from lifeimage.eventgen import events as ev
from lifeimage.eventgen.rates import paired_effect, rate_head
from lifeimage.eventgen.sequence import describe, hard_violations, life_records, sequence_head, soft_statistics, soft_targets
from lifeimage.eventgen.variants import IGNORES_MARRIAGE, shuffled
from lifeimage.eventgen.world import BIRTH_DATE, World
from lifeimage.generators.common import seed_ids

REGIONS = ("KEN", "IND", "FRA")
RM = cal.load_regions()
KNOWN_SOFT_FLAG = ("seq.share_married_by_18", "20-24", "f", "IND")   # the normal marriage-age model (sd 4) puts 17% of Indian women married by 18, the table says 22%


def table():
    return cal.load_table(field_ids=seed_ids())


def make(n=500, variant=None, **kw):
    def mk(seed):
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            w = World(table(), REGIONS, n, seed, region_map=RM, **kw)
        return shuffled(w, seed) if variant == "shuffled" else w
    return mk


def head(variant=None, seeds=10, n=500, **kw):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return sequence_head(table(), make(n, variant, **kw), REGIONS, RM, seeds=seeds)


def rec(i, kind, age, end=None, links=()):
    t = ev.valid_time(BIRTH_DATE, age)
    return {"id": i, "kind": kind, "valid_time": t, "record_time": t, "span": {"start": t, "end": ev.valid_time(BIRTH_DATE, age if end is None else end)},
            "links": [{"from": i, "to": to, "type": ty, "confidence": 0.8} for ty, to in links]}


def life(*events, sex="f"):
    return [{"pid": "x", "region": "KEN", "sex": sex, "events": [rec("b", "born", 0.0), *events]}]


# ---- hard checks, one rule at a time ----
def test_a_coherent_life_has_no_hard_violation():
    L = life(rec("s", "school_start", 6), rec("p", "primary_complete", 12, links=[("causes", "q")]), rec("q", "secondary_start", 12), rec("m", "marriage", 22, 50),
             rec("g", "pregnancy", 23.25, 24), rec("c", "birth_of_child", 24, links=[("part_of", "g")]), rec("d", "divorce", 30, links=[("part_of", "m")]))
    L[0]["events"][4]["span"]["end"] = ev.valid_time(BIRTH_DATE, 30)       # the marriage ends with the divorce
    L[0]["events"][-1]["links"][0]["to"] = "m"
    assert hard_violations(L) == {}


@pytest.mark.parametrize("code,events,sex", [
    ("event_after_death", [rec("d", "death", 30), rec("m", "marriage", 35)], "f"),
    ("event_after_death", [rec("m", "marriage", 20, 40), rec("d", "death", 30)], "f"),                      # the marriage span outlives the person
    ("divorce_without_prior_marriage", [rec("v", "divorce", 30)], "f"),
    ("divorce_without_prior_marriage", [rec("m", "marriage", 31, 40), rec("v", "divorce", 30, links=[("part_of", "m")])], "f"),   # linked, but not prior
    ("birth_before_minimum_maternal_age", [rec("g", "pregnancy", 13.25, 14), rec("c", "birth_of_child", 14, links=[("part_of", "g")])], "f"),
    ("school_levels_out_of_order", [rec("s", "school_start", 6), rec("p", "primary_complete", 12), rec("q", "secondary_start", 11)], "f"),
    ("school_level_without_previous", [rec("t", "tertiary_complete", 22)], "f"),
    ("school_levels_out_of_order", [rec("s", "school_start", 6), rec("x", "school_dropout", 9), rec("p", "primary_complete", 12)], "f"),
    ("link_violates_time_or_span", [rec("a", "primary_complete", 12, links=[("causes", "b")]), rec("b", "secondary_start", 11)], "f"),
    ("link_violates_time_or_span", [rec("b", "birth_of_child", 21, links=[("part_of", "p")]), rec("p", "pregnancy", 19.25, 20)], "f"),
    ("event_before_birth", [rec("m", "marriage", -1)], "f"),
    ("parenthood_of_wrong_sex", [rec("c", "birth_of_child", 30)], "m"),
    ("two_deaths", [rec("d", "death", 30), rec("e", "death", 31)], "f"),
])
def test_each_hard_rule_flags_its_violation(code, events, sex):
    assert code in hard_violations(life(*events, sex=sex))


# ---- the generator itself ----
def test_true_generator_has_zero_hard_violations_on_every_seed_and_passes_soft_checks():
    rep = head(seeds=16)
    assert rep["hard_failing_seeds"] == 0 and rep["hard_codes"] == {}
    failing = [r["key"] for r in rep["soft"] if r["status"] == "fail"]
    assert set(failing) <= {KNOWN_SOFT_FLAG}, [r for r in rep["soft"] if r["status"] == "fail"]
    calibrated = [r for r in rep["soft"] if r["calibration"] == "param" and r["status"] == "pass"]
    assert len(calibrated) >= 3 and rep["calibrated_passing"] >= 3
    assert {r["key"][0] for r in calibrated} >= {"seq.mean_age_first_marriage", "seq.mean_age_childbearing", "seq.median_age_primary_completion"}


def test_the_known_soft_flag_is_a_real_miss_within_detectable_effect():
    rep = head(seeds=16)
    r = next(x for x in rep["soft"] if x["key"] == KNOWN_SOFT_FLAG)
    assert r["status"] == "fail" and r["z"] <= -2 and r["effect"] < -r["margin"]


def test_soft_checks_use_only_the_regions_own_stratum_and_say_so():
    t = table()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        tg = soft_targets(t, REGIONS, RM)
    assert not any(k[3] == "FRA" and k[0] != "seq.median_age_primary_completion" for k in tg)   # FRA has only world-level or default values
    assert any(d["substitute"] == "statistic unjudged" and d["region"] == "FRA" for d in t.degraded)
    assert ("seq.premarital_first_birth_share", "all", "f", "KEN") in tg and ("seq.premarital_first_birth_share", "all", "f", "FRA") not in tg
    assert {v[1] for v in tg.values()} == {"param", "derived", "assumed"}


def test_descriptive_median_and_iqr_of_first_events_are_reported():
    w = make(500)(1)
    d = describe(life_records(w), REGIONS)
    for name in ("first_marriage", "first_birth", "school_completion"):
        for r in ("KEN", "IND"):
            assert d[(name, "f", r)]["iqr"] >= (0 if name == "school_completion" else 1) and d[(name, "f", r)]["median"] > 5   # school completion ages barely vary
    assert d[("first_marriage", "f", "KEN")]["median"] == pytest.approx(21.6, abs=1.0)


# ---- counterexamples ----
def test_shuffled_order_passes_the_rate_head_and_fails_the_sequence_head():
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        rates = rate_head(table(), lambda s: shuffled(World(table(), REGIONS, 1500, s, region_map=RM), s), REGIONS, RM)
        base = rate_head(table(), lambda s: World(table(), REGIONS, 1500, s, region_map=RM), REGIONS, RM)
    assert rates["summary"]["fail"] == 0 and base["summary"]["fail"] == 0              # the rate head cannot tell the shuffled generator apart
    assert rates["summary"]["inconclusive"] <= 3
    rep = head("shuffled", seeds=20)
    assert rep["hard_failing_seeds"] / rep["seeds"] >= 0.95                                # the sequence head flags it on (nearly) every seed
    assert {"event_after_death", "divorce_without_prior_marriage", "school_levels_out_of_order", "link_violates_time_or_span"} <= set(rep["hard_codes"])


def test_births_ignoring_marriage_are_flagged_softly_not_as_a_hard_failure():
    base, bad = head(seeds=12), head(seeds=12, noise=IGNORES_MARRIAGE)
    assert bad["hard_failing_seeds"] == 0 and bad["hard_codes"] == {}                   # coherent lives: no hard rule is broken
    key = lambda r: r["key"][0] == "seq.premarital_first_birth_share" and r["key"][3] in ("KEN", "IND")   # noqa: E731
    for r in filter(key, bad["soft"]):
        assert r["status"] == "fail" and r["z"] >= 2 and r["effect"] > r["margin"]
    for r in filter(key, base["soft"]):
        assert r["status"] == "pass"
    # the paired effect (same seeds, common random numbers) is large against the true generator
    def series(mk, k):
        out = []
        for s in range(1, 9):
            out.append(soft_statistics(life_records(mk(s)), REGIONS)[k])
        return out
    k = ("seq.premarital_first_birth_share", "all", "f", "KEN")
    m, se, z = paired_effect(series(make(500, noise=IGNORES_MARRIAGE), k), series(make(500), k))
    assert m > 0.15 and z >= 2


def test_marginal_asfr_is_preserved_by_marital_state_dependence():
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        rep = rate_head(table(), lambda s: World(table(), REGIONS, 1500, s, region_map=RM), REGIONS, RM)
    assert rep["summary"]["fail"] == 0 and rep["summary"]["inconclusive"] == 0
    assert any(r["key"][0] == "mortality.prob_death_0_40" and r["status"] == "pass" for r in rep["results"])
