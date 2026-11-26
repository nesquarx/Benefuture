"""Breadth across the circle (increment 3): generated events reach most coarse fields (LI.60), every domain machine is calibrated and relational (LI.65),
the increment-2 findings are fixed (early-marriage tail, sourced births outside marriage, registration lag).

Acceptance claims state their hypothesis, direction, metric and the smallest effect that matters before measuring; arms share seeds; structural claims hold in
every seed, effects by the significance rule (z = 2, `rates.judge`), regimes as proportions with their interval. Counterexamples state what must fail:
a generator limited to the increment-2 kinds, a single-normal marriage age, births ignoring marriage, days at work on people without a job, a doubled
participation rate, a missing Param (degrades loudly, never stalls)."""
import datetime as dt
import json
import time
import warnings

import pytest

from lifeimage.eventgen import calibration as cal
from lifeimage.eventgen import catalog, coverage, domains
from lifeimage.eventgen import events as ev
from lifeimage.eventgen import relational as rel
from lifeimage.eventgen.rates import judge, rate_head
from lifeimage.eventgen.sequence import hard_violations, sequence_head, soft_targets
from lifeimage.eventgen.variants import IGNORES_MARRIAGE, career_blind
from lifeimage.eventgen.world import BIRTH_DATE, World, misspecify
from lifeimage.generators.common import seed_ids
from lifeimage.governed import GOVERNED, governed

REGIONS = ("KEN", "IND", "FRA")
RM = cal.load_regions()
ROOT = coverage.ROOT


def table():
    return cal.load_table(field_ids=seed_ids())


def world(n, seed=1, regions=REGIONS, tab=None, **kw):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return World(tab or table(), regions, n, seed, region_map=RM, **kw)


@pytest.fixture(scope="module")
def report():
    return coverage.build_report(2000)


@pytest.fixture(scope="module")
def full():
    w = world(400)
    return w, w.events()


@pytest.fixture(scope="module")
def domain_head():
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return rate_head(table(), lambda s: world(1000, s), REGIONS, RM, seeds=16, domains="only")


def all_events(by):
    return [e for evs in by.values() for e in evs]


# ---- coverage of the circle ----
def test_generated_events_reach_most_coarse_fields(report):
    s = report["summary"]
    assert s["fields"] == 247 and report["sample"]["people_per_region"] == 2000 and report["sample"]["regions"] == list(REGIONS)
    assert s["share_reached"] >= 0.60, f"{s['reached']} of {s['fields']} fields reached; unreached {s['unreached']}"
    assert s["pairs_observed"] >= 500 and s["events"] > 100000


def test_the_increment_2_kinds_alone_reach_under_a_fifth_of_the_fields(report):
    """The red baseline kept as a counterexample: family formation and schooling cannot score the placement of most fields."""
    b = report["baseline_increment_2_kinds"]
    assert b["share_reached"] < 0.20 and b["reached"] < report["summary"]["reached"] / 2


def test_the_coverage_report_file_is_written_and_consistent():
    f = ROOT / "data" / "events" / "coverage_v1.json"
    assert f.exists(), "run python3 -m lifeimage.eventgen.coverage"
    r = json.loads(f.read_text(encoding="utf-8"))
    assert r["sample"]["people_per_region"] == 2000 and r["summary"]["fields"] == 247
    assert r["summary"]["reached"] == sum(v > 0 for v in r["per_field_events"].values())
    assert r["summary"]["share_reached"] >= 0.60 and r["summary"]["pairs_observed"] == len(r["pairs"])
    assert all(a < b for a, b in (k.split("|") for k in r["pairs"]))


def test_every_catalog_kind_is_generated_in_the_probe_regions(report):
    missing = sorted(set(catalog.BY_KEY) - set(report["events_per_kind"]))
    assert len(missing) <= 2, missing


def test_every_catalog_domain_exists_on_the_circle():
    ids = seed_ids()
    for k in catalog.ALL:
        for d in k.form + k.content + k.outcome + k.setting:
            assert d in ids, (k.key, d)


# ---- every event relational ----
def test_every_generated_event_passes_the_relational_validator_and_new_roles_appear(full):
    w, by = full
    events = all_events(by)
    assert len(events) > 40000
    roles = set()
    for e in events:
        rel.validate_event(e)                       # layers A and B and the metadata; rows through the library's validator (once per structure)
        roles.update(e["roles"].values())
        assert e["record_time"] >= e["valid_time"]
    assert {"employer", "clinic", "club", "polling", "victim", "offender"} <= roles, roles
    ents = {x["id"].split(":")[0]: x["kind"] for x in rel.entities(by)}
    assert ents["employer"] == ents["clinic"] == ents["club"] == ents["polling"] == "organisation" and ents["victim"] == ents["offender"] == "person"


def test_time_use_events_are_short_term_actions_with_their_duration(full):
    _, by = full
    tu = [e for e in all_events(by) if e["kind"] in catalog.TIME_BY_KEY]
    assert len(tu) > 10000 and all(e["timescale"] == "minutes/hours" for e in tu)
    assert sum("duration_minutes" in e for e in tu) == len(tu) and all(0 < e["duration_minutes"] <= 1440 for e in tu)
    assert len({e["kind"] for e in tu}) >= 30


def test_responsibility_follows_freedom_for_offender_and_victim(full):
    _, by = full
    for kind in ("assault_victim", "theft_victim", "burglary_victim", "partner_violence_victim"):
        evs = [e for e in all_events(by) if e["kind"] == kind]
        assert evs, kind
        for e in evs:
            off = next(p for p in e["participants"] if e["roles"][p["id"]] == "offender")
            vic = next(p for p in e["participants"] if e["roles"][p["id"]] == "self")
            assert off["responsibility"] == 1.0 and off["option_set"] == [{"alternative": off["option_set"][0]["alternative"], "harm": 0}]
            assert vic["responsibility"] == 0.0 and e["memberships"][0]["domain"] and any(m["rel"] == "outcome" for m in e["memberships"])
    jobs = [e for e in all_events(by) if e["kind"] == "job_loss"]
    emp = [next(p for p in e["participants"] if e["roles"][p["id"]] == "employer") for e in jobs]
    assert jobs and all(p["responsibility"] > 0.5 for p in emp)   # the employer chose to lay off with a harmless alternative open (retain the worker, harm 2): high responsibility


def test_missing_option_sets_and_minors_take_the_governed_default_loudly():
    w = world(300)
    w.events()
    log = w.relational_degraded
    assert log and {d["mechanism"] for d in log} == {"responsibility_from_freedom"} and all("governed default" in d["substitute"] for d in log)


# ---- domain machines: calibration (rate head over paired seeds) ----
def test_domain_head_follows_the_calibration_without_a_systematic_failure(domain_head):
    s = domain_head["summary"]
    n = sum(s.values())
    assert n > 1000 and domain_head["seeds"] == 16
    assert s["pass"] / n >= 0.75, s
    failing = [r["key"] for r in domain_head["results"] if r["status"] == "fail"]
    assert len(failing) / n <= 0.01, failing    # regime: at z = 2 over ~1500 statistics a few fall beyond their margin by chance; a systematic fault would take dozens


@pytest.mark.parametrize("family", ["work.labour_force_participation", "work.unemployment", "work.youth_unemployment", "harm.theft_recorded_rate", "harm.suspect_rate",
                                    "health.tb_incidence", "health.disability_prevalence", "civic.voter_turnout_year", "family.contraceptive_prevalence"])
def test_each_domain_family_has_no_failing_statistic(domain_head, family):
    rows = [r for r in domain_head["results"] if r["key"][0] == family]
    assert rows, family
    assert not [r["key"] for r in rows if r["status"] == "fail"], [r for r in rows if r["status"] == "fail"]


def test_india_group_time_use_matches_the_survey_it_is_calibrated_to(domain_head):
    rows = [r for r in domain_head["results"] if r["key"][0].startswith("time.group.") and r["key"][3] == "IND"]
    assert len(rows) >= 40 and sum(r["status"] == "fail" for r in rows) <= 1, [r for r in rows if r["status"] == "fail"]


def test_at_least_ten_time_use_activities_have_participation_and_minutes_calibration():
    t = table()
    for region in ("DEU", "ECS"):
        kinds = {p.quantity.split(".")[-1] for p in t.params if p.quantity.startswith("time.participation.") and p.region == region}
        mins = {p.quantity.split(".")[-1] for p in t.params if p.quantity.startswith("time.minutes.") and p.region == region}
        assert len(kinds & mins) >= 10 and (kinds & mins) >= {"sleep", "cooking", "television", "employment", "shopping", "childcare"}
    groups = {p.quantity for p in t.params if p.region == "IND" and p.quantity.startswith("time.group.")}
    assert len(groups) == 18


def test_every_domain_param_carries_provenance_and_a_relational_event_snippet():
    t = table()
    new = [p for p in t.params if p.quantity.startswith(("time.", "harm.", "leisure.", "civic.", "health.", "work.new", "work.long", "family.births"))]
    assert len(new) > 1500
    for p in new[::25]:
        assert p.source_statement and p.snippet_locator and p.retrieved and p.event_snippets
        for s in p.event_snippets:
            rel.validate_relational_snippet(s["relational"])


def test_a_doubled_participation_rate_is_detected():
    """Hypothesis: doubling the cooking participation in the generator's table is detected as a failure (z >= 2, effect beyond the margin) on cooking only."""
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        bad = rate_head(table(), lambda s: world(1000, s, tab=misspecify(table(), "time.participation.cooking", 2.0)), REGIONS, RM, seeds=8, domains="only")
    cook = [r for r in bad["results"] if r["key"][0] == "time.participation.cooking" and r["key"][1] == "all"]
    assert cook and all(r["status"] == "fail" and r["z"] >= 2 and r["effect_rel"] > 0.3 for r in cook)
    other = [r for r in bad["results"] if r["key"][0] == "time.participation.sleep" and r["key"][1] == "all"]
    assert other and all(r["status"] != "fail" for r in other)


def test_a_region_without_a_param_degrades_loudly_and_never_stalls():
    w = world(200)
    assert "cinema_visit" in w.domains["KEN"]["absent"] and "cinema_visit" not in w.domains["FRA"]["absent"]
    none = [d for d in w.degraded if d["substitute"] == "none" and d["region"] == "KEN" and d["mechanism"] == "leisure.cinema_12m"]
    assert none and not any(k == "cinema_visit" for p in w.people if p.region == "KEN" for k, _ in p.events)
    assert any(k == "cinema_visit" for p in w.people if p.region == "FRA" for k, _ in p.events)


def test_a_region_with_only_group_level_time_use_is_rescaled_and_says_so():
    w = world(200)
    assert any(v[2] == "group" for v in w.domains["IND"]["tu"].values()) and any(v[2] == "ECS" for v in w.domains["KEN"]["tu"].values())
    assert any("ECS profile" in d["substitute"] for d in w.degraded if d["region"] == "KEN")


# ---- sequence head: new hard rules and the gaming counterexample ----
def rec(i, kind, age, end=None, links=()):
    t = ev.valid_time(BIRTH_DATE, age)
    return {"id": i, "kind": kind, "valid_time": t, "record_time": t, "span": {"start": t, "end": ev.valid_time(BIRTH_DATE, age if end is None else end)},
            "links": [{"from": i, "to": to, "type": ty, "confidence": 0.8} for ty, to in links]}


def life(*events, sex="f"):
    return [{"pid": "x", "region": "KEN", "sex": sex, "events": [rec("b", "born", 0.0), *events]}]


def test_a_coherent_working_life_has_no_hard_violation():
    L = life(rec("w", "industry_work_start", 20), rec("l", "job_loss", 30, 31), rec("r", "reemployment", 31), rec("e", "employment", 35), rec("t", "retirement", 62),
             rec("q", "suspected_offence", 20), rec("c", "conviction", 21))
    assert hard_violations(L) == {}


@pytest.mark.parametrize("code,events,sex", [
    ("work_before_minimum_age", [rec("w", "service_work_start", 12)], "m"),
    ("retirement_without_work", [rec("t", "retirement", 62)], "m"),
    ("retirement_before_minimum_age", [rec("w", "industry_work_start", 20), rec("t", "retirement", 40)], "m"),
    ("reemployment_without_job_loss", [rec("w", "industry_work_start", 20), rec("r", "reemployment", 31)], "m"),
    ("job_loss_inside_spell", [rec("w", "industry_work_start", 20), rec("l", "job_loss", 30, 33), rec("k", "job_loss", 31, 32)], "m"),
    ("work_day_outside_employment", [rec("w", "industry_work_start", 20), rec("t", "retirement", 62), rec("e", "employment", 64)], "m"),
    ("work_day_outside_employment", [rec("e", "employment", 10)], "m"),
    ("offence_before_minimum_age", [rec("q", "suspected_offence", 11)], "m"),
    ("conviction_without_suspicion", [rec("c", "conviction", 30)], "m"),
    ("partner_violence_outside_union", [rec("v", "partner_violence_victim", 30)], "f"),
    ("record_before_valid_time", [dict(rec("v", "theft_victim", 30), record_time=ev.valid_time(BIRTH_DATE, 29))], "f"),
])
def test_each_domain_hard_rule_flags_its_violation(code, events, sex):
    assert code in hard_violations(life(*events, sex=sex))


def test_true_generator_has_zero_hard_violations_in_every_seed():
    for seed in range(1, 7):
        v = hard_violations([{"pid": p.pid, "region": p.region, "sex": p.sex, "events": evs} for p, evs in zip(world(400, seed).people, world(400, seed).events(light=True).values())])
        assert v == {}, (seed, {k: x[1] for k, x in v.items()})


def test_days_at_work_on_people_without_a_job_pass_the_rate_head_and_fail_the_sequence_head():
    """Gaming counterexample: permuting days at work among diary days keeps every participation rate; it must break the coherence of the lives."""
    def blind(s):
        return career_blind(world(1000, s), s)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        rates = rate_head(table(), blind, REGIONS, RM, seeds=8, domains="only")
    emp = [r for r in rates["results"] if r["key"][0] in ("time.participation.employment", "time.minutes.employment") and r["key"][1] == "all"]
    assert emp and not [r for r in emp if r["status"] == "fail"], emp   # the rate head cannot tell
    recs = lambda w: [{"pid": p.pid, "region": p.region, "sex": p.sex, "events": evs} for p, evs in zip(w.people, w.events(light=True).values())]  # noqa: E731
    w = career_blind(world(500, 3), 3)
    v = hard_violations(recs(w))
    assert v.get("work_day_outside_employment", (0,))[0] > 50, v
    assert hard_violations(recs(world(500, 3))) == {}


# ---- fixes of increment 2 ----
def seq(variant_table=None, seeds=10, n=500, noise=None, regions=REGIONS):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return sequence_head(table(), lambda s: world(n, s, regions, variant_table() if variant_table else None, noise=noise), regions, RM, seeds=seeds)


def test_india_married_by_18_passes_after_the_early_tail_change():
    """Hypothesis (judged again, not tuned): with the early component set from the WDI share married by 18, the generated share is equivalent to the Param within
    the governed margin (5 points) in India; the mean age at first marriage is still the singulate mean."""
    rep = seq(seeds=12)
    key = ("seq.share_married_by_18", "20-24", "f", "IND")
    r = next(x for x in rep["soft"] if x["key"] == key)
    assert r["status"] == "pass" and abs(r["effect"]) < r["margin"], r
    m = next(x for x in rep["soft"] if x["key"] == ("seq.mean_age_first_marriage", "all", "f", "IND"))
    assert m["status"] == "pass"
    assert not [x["key"] for x in rep["soft"] if x["status"] == "fail"]


def test_a_single_normal_marriage_age_reproduces_the_miss():
    """Counterexample: without the married-by-18 Param the generator falls back to one normal spread and the head flags India again (z <= -2)."""
    def no_b18():
        return cal.Table([p for p in table().params if p.quantity != "family.married_by_18"])
    rep = seq(no_b18, seeds=12)
    r = next(x for x in rep["soft"] if x["key"] == ("seq.share_married_by_18", "20-24", "f", "IND"))
    assert r["status"] == "fail" and r["z"] <= -2 and r["effect"] < -r["margin"]


def test_the_births_outside_marriage_target_is_sourced_and_no_assumed_target_remains():
    t = table()
    tg = soft_targets(t, REGIONS, RM)
    kinds = {k: v[1] for k, v in tg.items()}
    assert "assumed" not in kinds.values() and not any(k[0] == "seq.premarital_first_birth_share" for k in tg)
    assert ("seq.births_outside_marriage_share", "all", "f", "FRA") in tg and tg[("seq.births_outside_marriage_share", "all", "f", "FRA")][1] == "param"
    p = t.get("family.births_outside_marriage", "all", "f", "DEU")
    assert p is not None and p.source_id == "Eurostat-demo_fagec" and 20 < p.value < 60
    for name in ("premarital_first_birth_share", "premarital_rare_below_smam", "premarital_margin"):
        assert f"eventgen.{name}" not in GOVERNED


def test_births_outside_marriage_match_the_source_where_it_exists():
    rep = seq(seeds=12)
    r = next(x for x in rep["soft"] if x["key"] == ("seq.births_outside_marriage_share", "all", "f", "FRA"))
    assert r["status"] == "pass", r
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        head = rate_head(table(), lambda s: world(1000, s), REGIONS, RM, seeds=10, domains=False)
    b = next(x for x in head["results"] if x["key"][0] == "family.births_outside_marriage")
    assert b["key"][3] == "FRA" and b["status"] != "fail"


def test_births_ignoring_marriage_fail_the_sourced_target():
    rep = seq(noise=IGNORES_MARRIAGE, seeds=10)
    r = next(x for x in rep["soft"] if x["key"] == ("seq.births_outside_marriage_share", "all", "f", "FRA"))
    assert r["status"] == "fail" and r["z"] >= 2


def test_record_time_follows_valid_time_by_a_registration_lag_on_its_own_stream():
    w = world(300)
    by = w.events(light=True)
    lags = [(dt.date.fromisoformat(e["record_time"]) - dt.date.fromisoformat(e["valid_time"])).days for e in all_events(by)]
    assert min(lags) >= 0 and sum(l > 0 for l in lags) / len(lags) > 0.9
    civil = sorted(l for e, l in zip(all_events(by), lags) if e["kind"] in rel.CIVIL)
    other = sorted(l for e, l in zip(all_events(by), lags) if e["kind"] not in rel.CIVIL)
    assert civil[len(civil) // 2] < other[len(other) // 2] and 3 <= civil[len(civil) // 2] <= 14 and 20 <= other[len(other) // 2] <= 45   # governed medians 7 and 30 days
    w0 = world(300, noise={"registration_lag_other_days": 0.0, "registration_lag_civil_days": 0.0})
    by0 = w0.events(light=True)
    assert all(e["record_time"] == e["valid_time"] for e in all_events(by0))
    sig = lambda b: [(e["id"], e["kind"], e["valid_time"]) for e in all_events(b)]  # noqa: E731
    assert sig(by) == sig(by0)                    # the lag moves record times only: common random numbers


def test_new_governed_values_are_documented_in_the_package_readme():
    text = (ROOT / "lifeimage" / "eventgen" / "README.md").read_text(encoding="utf-8")
    new = [k for k in GOVERNED if k.startswith(("eventgen.", "noise.")) and k.split(".", 1)[1] in text]
    for key in ("eventgen.life_horizon_age", "eventgen.diary_days", "noise.registration_lag_sigma", "noise.marriage_early_mean", "eventgen.time_ratio_cap",
                "eventgen.min_working_age", "eventgen.min_offending_age", "eventgen.partner_violence_persistence", "noise.time_use_minutes_sd"):
        assert key.split(".", 1)[1] in text, key
    assert len(new) > 40 and "Increment 3" in text and "Gaming" in text


def test_the_full_probe_with_both_heads_runs_in_under_a_minute():
    from lifeimage.eventgen.probe import run
    t0 = time.time()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        out = run(verbose=False)
    assert time.time() - t0 < 60, time.time() - t0
    assert out["head"]["summary"]["fail"] == 0 and out["domain_head"]["summary"]["fail"] <= max(3, 0.01 * sum(out["domain_head"]["summary"].values()))
    assert out["sequence"]["hard_failing_seeds"] == 0 and out["shuffled"]["hard_failing_seeds"] > 0
    assert out["career_blind"]["hard_codes"].get("work_day_outside_employment", 0) > 0
