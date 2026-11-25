"""Synthetic life histories: outcome tests (red first against a stub that ignores the seed and emits an invalid row).

Structural claims hold for every seed; distributional claims use paired seeds and a z-rule (z = 3 combined standard
errors; no-effect claims by equivalence inside a stated margin that the sample could have detected)."""
import json
import math
import statistics as st

import pytest

from lifeimage.fine.cards import coarsen_rows, load_fine
from lifeimage.generators import life
from lifeimage.generators.common import padded, seed_ids, validate_row
from lifeimage.generators.params import ARCHETYPES, PARAMS, resolve
from lifeimage.participation import validate_participation_answer

AREAS = {"care", "home", "family", "health", "learning", "work", "leisure", "faith", "civic", "consumption"}
SEEDS = range(40)


def gen(seed, archetype="generalist", age=45, **kw):
    return life.generate_persona(seed, archetype, age, **kw)


def se_mean(xs):
    return st.stdev(xs) / math.sqrt(len(xs))


def paired_effect(a, b, z=3.0):
    d = [x - y for x, y in zip(a, b)]
    return st.mean(d), z * se_mean(d)


# ---- determinism ----
def test_same_seed_same_life_different_seed_different_life():
    a, b, c = gen(7), gen(7), gen(8)
    assert a.rows == b.rows and a.texts == b.texts and a.events == b.events
    assert a.rows != c.rows and a.texts["resume"] != c.texts["resume"] and (a.name, a.birth) != (c.name, c.birth)


# ---- contract ----
@pytest.mark.parametrize("archetype", sorted(ARCHETYPES))
def test_every_row_meets_the_contract_for_every_archetype_and_age(archetype):
    lo, hi = ARCHETYPES[archetype]["age_range"]
    ids = seed_ids() | {c["id"] for c in load_fine()}  # a row names a coarse field or a fine domain (LI.51)
    for seed, age in zip(range(6), [lo, (lo + hi) // 2, hi, lo + 1, hi - 1, (lo + hi) // 2 + 1]):
        p = gen(seed, archetype, age)
        assert len(p.rows) >= 8, "a life leaves evidence"
        for r in p.rows:
            validate_row(r)
            assert r["entity"] == p.entity
            assert r["confidence"] < 1
            assert {m["domain"] for m in r["memberships"]} <= ids
            assert padded(r["valid_time"]) <= padded(r["record_time"])
            assert padded(r["valid_time"])[0] >= int(p.birth[:4]) and padded(r["valid_time"]) <= padded(p.as_of)
            assert padded(r["record_time"]) <= padded(p.as_of)


def test_confidence_is_never_one_and_not_constant():
    cs = [r["confidence"] for s in range(5) for r in gen(s).rows]
    assert max(cs) < 1 and len(set(round(c, 2) for c in cs)) > 8


def test_participation_of_every_event_validates_and_harm_is_negative():
    for s in range(15):
        p = gen(s)
        assert p.events
        for e in p.events:
            validate_participation_answer(e["participation"], e["participants"], version=2)
            me = next(x for x in e["participation"]["participants"] if x["id"] == p.entity)
            if e["area"] == "harm":
                assert any(i["sign"] == -1 for x in e["participation"]["participants"] for i in x["impact"])
                assert me["option_set"] is not None and me["responsibility"] > 0
            for ri in e["rows"]:
                assert p.rows[ri]["provenance"]["span"]
    # every row belongs to exactly one event
    p = gen(3)
    owned = sorted(i for e in p.events for i in e["rows"])
    assert owned == sorted(set(owned)) and set(owned) | {i for i, r in enumerate(p.rows) if r["channel"] == "prediction"} == set(range(len(p.rows)))


# ---- coverage of all of life ----
def test_adult_lives_cover_every_area_across_seeds_and_each_life_most_of_them():
    covered, per = set(), []
    for s in SEEDS:
        p = gen(s, "generalist", 50)
        a = {e["area"] for e in p.events}
        covered |= a
        per.append(len(a & AREAS))
    assert AREAS <= covered
    assert st.mean(per) >= 8, per


def test_rare_harm_is_rare_but_present():
    n = sum(any(e["area"] == "harm" for e in gen(s, "generalist", 55).events) for s in range(80))
    p = n / 80
    half = 1.96 * math.sqrt(p * (1 - p) / 80) if 0 < p < 1 else 0
    assert 0.03 <= p <= 0.5, (n, half)
    r = [r for s in range(80) for r in gen(s, "generalist", 55).rows if r["channel"] == "negative"]
    assert r and all(x["sign"] == -1 and x["option_set"] is not None for x in r)


# ---- age plausibility (adversarial) ----
def test_a_child_has_no_adult_life_events():
    for s in range(30):
        p = gen(s, "student", 8)
        keys = {e["key"] for e in p.events}
        assert not keys & {"job", "marriage", "birth_of_child", "retirement", "loan", "first_job", "partner", "own_home"}
        assert all(e["area"] != "work" for e in p.events)
        birth = int(p.birth[:4])
        assert all(birth <= padded(r["valid_time"])[0] <= birth + 8 for r in p.rows)


def test_minimum_ages_hold_for_everyone():
    mins = {"marriage": 18, "birth_of_child": 16, "job": 14, "retirement": 50, "loan": 18, "own_home": 18, "first_job": 14}
    for s in range(30):
        for age in (13, 17, 24, 70):
            p = gen(s, "generalist", age)
            assert p.events
            for e in p.events:
                if e["key"] in mins:
                    assert int(e["valid_time"][:4]) - int(p.birth[:4]) >= mins[e["key"]] - 1, (e["key"], age)


def test_a_retiree_is_retired_a_young_adult_is_not():
    assert all(any(e["key"] == "retirement" for e in gen(s, "retiree", 75).events) for s in range(20))
    assert not any(e["key"] == "retirement" for s in range(20) for e in gen(s, "student", 21).events)


# ---- archetypes are parameter presets, not hard-coded lives ----
def coarse_rows(p):
    """The persona's rows read at the coarse level (fine domains read as their upstream fields, LI.51)."""
    return coarsen_rows(p.rows, load_fine())


def share(p, prefix):
    ds = [m["domain"] for r in coarse_rows(p) for m in r["memberships"] if r["channel"] == "positive"]
    return sum(d.startswith(prefix) for d in ds) / len(ds)


def test_researcher_touches_science_more_than_shift_worker_paired_seeds():
    sci = ("c.physics", "c.chemistry", "c.life_sciences", "c.science_research_work", "c.research_training", "c.mathematics",
           "c.statistics_data", "c.computer_science", "c.medicine_science", "c.psychology", "c.sociology", "c.economics")

    def frac(p):
        ds = [m["domain"] for r in coarse_rows(p) for m in r["memberships"] if r["channel"] == "positive"]
        return sum(d in sci for d in ds) / len(ds)

    a = [frac(gen(s, "researcher", 40)) for s in SEEDS]
    b = [frac(gen(s, "shift_worker", 40)) for s in SEEDS]
    eff, margin = paired_effect(a, b)
    assert eff > margin and eff > 0.05, (eff, margin)


def test_carer_small_business_and_career_changer_have_their_signature():
    care = {"c.eldercare", "c.care_of_ill_disabled", "c.parenting_young_children"}
    for s in range(15):
        c = gen(s, "carer", 45)
        assert sum(m["domain"] in care for r in coarse_rows(c) for m in r["memberships"]) >= 3
        b = gen(s, "small_business_owner", 45)
        assert any(m["domain"] == "c.entrepreneurship" for r in coarse_rows(b) for m in r["memberships"])
        k = gen(s, "career_changer", 45)
        sectors = {e["detail"].get("sector") for e in k.events if e["key"] == "job"}
        assert len(sectors - {None}) >= 2 and any(e["key"] == "employment_transition" for e in k.events)


def test_archetypes_are_presets_overriding_parameters_within_their_ranges():
    for name, a in ARCHETYPES.items():
        resolve(a["params"])  # raises when any override is outside its range
        assert a["age_range"][0] < a["age_range"][1]
    assert set(ARCHETYPES) >= {"student", "shift_worker", "carer", "small_business_owner", "researcher", "retiree",
                               "career_changer", "generalist"}


# ---- parameters ----
def test_every_parameter_has_range_source_and_confidence():
    assert len(PARAMS) >= 20
    for name, p in PARAMS.items():
        assert p.low <= p.default <= p.high, name
        assert p.source.strip() and p.confidence in ("low", "medium", "high") and p.unit
    with pytest.raises(ValueError):
        resolve({"p_faith_active": 1.5})
    with pytest.raises(ValueError):
        resolve({"no_such_parameter": 1})


def test_a_parameter_changes_the_outcome_paired_seeds():
    def n_faith(s, v):
        return sum(e["area"] == "faith" for e in gen(s, "generalist", 50, params={"p_faith_active": v}).events)

    hi = [n_faith(s, 0.7) for s in SEEDS]
    lo = [n_faith(s, 0.05) for s in SEEDS]
    eff, margin = paired_effect(hi, lo)
    assert eff > margin and eff > 1, (eff, margin)


# ---- tiers ----
def test_tier_shares_and_confidence_ordering_over_a_population():
    rows = [r for s in SEEDS for r in gen(s, "generalist", 20 + s).rows if r["channel"] == "positive"]
    n = len(rows)
    sh = {t: sum(r["tier"] == t for r in rows) / n for t in ("claimed", "attested", "measured")}
    assert sh["claimed"] < 0.8 and sh["attested"] > 0.1 and 0.03 < sh["measured"] < 0.4, sh
    mean = {t: st.mean(r["confidence"] for r in rows if r["tier"] == t) for t in sh}
    assert mean["claimed"] < mean["attested"] - 0.05 and mean["claimed"] < mean["measured"] - 0.05, mean
    for r in rows:
        if r["tier"] == "claimed":
            assert r["provenance"]["source"].split(":")[0] in ("resume", "diary", "self")
        else:
            assert r["provenance"]["source"].split(":")[0] not in ("resume", "diary", "self")


# ---- self-assessed potential ----
def est_errors(p):
    out = []
    for r in p.rows:
        if r["channel"] != "prediction":
            continue
        kind = "impact" if any(m["rel"] == "outcome" for m in r["memberships"]) else "expertise"
        d = r["memberships"][0]["domain"]
        out.append(r["magnitude"] - p.latent[d][kind])
    return out


def test_self_assessment_over_under_and_well_calibrated_with_estimation_error():
    means = {}
    for cal in ("over", "under", "well"):
        ps = [gen(s, "generalist", 40, calibration=cal) for s in SEEDS]
        assert all(p.calibration == cal for p in ps)
        means[cal] = [st.mean(est_errors(p)) for p in ps]
        assert all(est_errors(p) for p in ps)
    m, s_ = st.mean(means["over"]), 3 * se_mean(means["over"])
    assert m - s_ > 0.04, (m, s_)
    m, s_ = st.mean(means["under"]), 3 * se_mean(means["under"])
    assert m + s_ < -0.02, (m, s_)  # the better-than-average shift (LI.50) offsets part of the under-estimator's offset
    w, ws = st.mean(means["well"]), 3 * se_mean(means["well"])
    assert abs(w) + ws < 0.05, (w, ws)  # equivalence margin 0.05, and the sample could detect an effect of that size
    assert st.mean(means["over"]) - st.mean(means["well"]) > 0.08 and st.mean(means["well"]) - st.mean(means["under"]) > 0.05
    # never ideal: even the well-calibrated misjudge, and persons differ within a type
    assert st.pstdev(est_errors(gen(1, "generalist", 40, calibration="well"))) > 0.02
    assert st.pstdev(means["over"]) > 0.02


def test_default_population_mixes_all_calibrations_and_potential_rows_are_claimed_predictions():
    cals = [gen(s).calibration for s in range(60)]
    assert {"over", "under", "well"} <= set(cals)
    pr = [r for r in gen(2).rows if r["channel"] == "prediction"]
    assert pr and all(r["tier"] == "claimed" and r["sign"] == 1 and r["relation"] == "causal" for r in pr)
    assert any(any(m["rel"] == "outcome" for m in r["memberships"]) for r in pr)
    assert any(all(m["rel"] in ("form", "content") for m in r["memberships"]) for r in pr)
    assert all(r["provenance"]["source"].startswith("self:") for r in pr)


# ---- texts for extraction tests ----
def test_texts_carry_the_ground_truth_rows_on_the_lines_they_cite():
    for s in range(12):
        p = gen(s, "generalist", 38)
        assert set(p.texts) == {"resume", "self", "diary"} and all(len(t) > 80 for t in p.texts.values())
        assert p.name in p.texts["resume"]
        claimed = [r for r in p.rows if r["tier"] == "claimed" and r["channel"] == "positive"]
        assert claimed
        by_row = {i: e for e in p.events for i in e["rows"]}
        for i, r in enumerate(p.rows):
            if r["tier"] != "claimed":
                continue
            kind = r["provenance"]["source"].split(":")[0]
            n = int(r["provenance"]["span"].lstrip("L"))
            line = p.texts[kind].splitlines()[n - 1]
            if i in by_row:
                assert by_row[i]["phrase"] in line, (kind, line, by_row[i]["phrase"])
        assert all(l[:4].isdigit() for l in p.texts["diary"].splitlines() if l.strip())
        assert len(p.truth_rows) == sum(r["tier"] == "claimed" for r in p.rows)


def test_texts_hold_fictional_contact_details_for_redaction_tests():
    t = gen(4).texts["resume"]
    assert "@example.org" in t and "555-01" in t


# ---- adversarial inputs ----
@pytest.mark.parametrize("kw", [dict(archetype="astronaut"), dict(age=-1), dict(age=200), dict(age=30.5), dict(calibration="perfect"),
                                dict(params={"p_vote": 2.0}), dict(params={"nope": 1})])
def test_invalid_inputs_are_rejected(kw):
    args = dict(archetype="generalist", age=30)
    args.update(kw)
    with pytest.raises((ValueError, TypeError)):
        life.generate_persona(1, args.pop("archetype"), args.pop("age"), **args)


def test_age_zero_and_a_hundred_generate_without_error():
    for age in (0, 1, 100):
        p = gen(2, "generalist", age)
        assert p.events and all(validate_row(r) for r in p.rows)


# ---- self-estimates follow the self-assessment literature (LI.50) ----
_EST_CACHE = {}


def estimate_gaps(cal="well", seeds=range(8000, 8080)):
    """[(true level, estimate minus truth, feedback in the domain)] over expertise and impact of every claimed domain; feedback is
    the persona's latent record of how much feedback the domain gave (0 none, 1 constant)."""
    key = (cal, seeds)
    if key not in _EST_CACHE:
        out = []
        for sd in seeds:
            p = gen(sd, "generalist", 40, calibration=cal)
            est = {}
            for r in p.rows:
                if r["channel"] == "prediction":
                    m = r["memberships"][0]
                    est[(m["domain"], "impact" if m["rel"] == "outcome" else "expertise")] = r["magnitude"]
            for d, lat in p.latent.items():
                for kind in ("expertise", "impact"):
                    out.append((lat[kind], est[(d, kind)] - lat[kind], lat["feedback"]))
        _EST_CACHE[key] = out
    return _EST_CACHE[key]


def verdict(group, versus, direction, delta):
    from lifeimage import characterise as ch
    return ch.contrast_verdict(group, versus, direction, delta)


def test_where_feedback_is_frequent_people_estimate_better_than_where_it_is_sparse_at_the_same_skill():
    mid = [(g, n) for t, g, n in estimate_gaps() if 0.35 <= t <= 0.65]
    sparse, frequent = [g for g, n in mid if n <= 0.25], [g for g, n in mid if n >= 0.5]
    assert len(sparse) >= 30 and len(frequent) >= 30  # fresh seeds hold both kinds of domain
    v = verdict(sparse, frequent, ">", 0.02)
    assert v["verdict"] == "held", v


def test_even_a_well_calibrated_person_estimates_themselves_better_than_average_where_feedback_is_sparse():
    sparse_mid = [g for t, g, n in estimate_gaps() if 0.35 <= t <= 0.65 and n <= 0.25]
    assert verdict(sparse_mid, [0.0] * len(sparse_mid), ">", 0.04)["verdict"] == "held"


def test_low_skill_with_sparse_feedback_is_over_estimated_and_the_highly_skilled_under_estimated():
    low = [g for t, g, n in estimate_gaps() if t <= 0.5 and n <= 0.25]
    high = [g for t, g, n in estimate_gaps() if t >= 0.75]
    assert len(low) >= 20 and len(high) >= 40
    assert verdict(low, [0.0] * len(low), ">", 0.06)["verdict"] == "held"
    assert verdict(high, [0.0] * len(high), "<", 0.02)["verdict"] == "held"


def test_estimation_parameters_are_world_parameters_with_ranges_sources_and_literature_confidence():
    for name in ("est_bta", "est_slope", "est_feedback_scale"):
        p = PARAMS[name]
        assert p.low <= p.default <= p.high and p.source.strip() and p.confidence in ("low", "medium", "high")
    assert PARAMS["est_slope"].low >= 0.1 and PARAMS["est_slope"].high <= 0.7  # Zell and Krizan 2014: r about 0.29
    assert "est_regression_slope" not in PARAMS
    with pytest.raises(ValueError):
        resolve({"est_bta": 0.9})
