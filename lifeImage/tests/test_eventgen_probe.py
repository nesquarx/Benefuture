"""Probe world and rate head: acceptance (rates match calibration on every seed set) and counterexamples (a doubled Param is detected,
a missing region degrades loudly rather than stalling, a noise parameter moves only its own mechanism)."""
import time
import warnings

import pytest

from lifeimage.eventgen import calibration as cal
from lifeimage.eventgen.rates import expected_targets, paired_effect, rate_head, table_coherence
from lifeimage.eventgen.world import World, misspecify
from lifeimage.generators.common import seed_ids
from lifeimage.governed import GOVERNED

REGIONS = ("KEN", "IND", "FRA")
RM = cal.load_regions()


def table():
    return cal.load_table(field_ids=seed_ids())


def world(seed=1, n=1500, regions=REGIONS, tab=None, **kw):
    return World(tab or table(), regions, n, seed, region_map=RM, **kw)


def head(gen_table_fn=None, **kw):
    true = table()
    mk = (lambda s: world(s, tab=gen_table_fn())) if gen_table_fn else (lambda s: world(s))
    return rate_head(true, mk, REGIONS, RM, **kw)


@pytest.mark.parametrize("seed0", [0, 1000])
def test_generated_rates_match_calibration_on_every_seed_set(seed0):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        rep = head(seed0=seed0)
    assert rep["summary"]["fail"] == 0 and rep["summary"]["inconclusive"] == 0, [r for r in rep["results"] if r["status"] != "pass"]
    assert rep["summary"]["pass"] >= 60 and rep["seeds"] <= 60


def test_doubled_fertility_is_detected_and_other_rates_still_pass():
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        rep = head(lambda: misspecify(table(), "fertility.asfr", 2.0), seeds=12)
    fert = [r for r in rep["results"] if r["key"][0] in ("fertility.asfr", "fertility.tfr")]
    assert fert and all(r["status"] == "fail" and abs(r["z"]) >= 2 and r["effect_rel"] > 0.5 for r in fert)
    assert all(r["status"] != "fail" for r in rep["results"] if r not in fert)   # 12 seeds: others may be underpowered, none may fail


def test_a_halved_schooling_share_is_detected():
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        rep = head(lambda: misspecify(table(), "education.primary_net_enrolment", 0.5), seeds=12)
    bad = [r for r in rep["results"] if r["status"] == "fail"]
    assert bad and all(r["key"][0].startswith("share:") for r in bad)
    assert any(r["key"][0] == "share:primary_entry" for r in bad)


def test_probe_runtime_and_rows_are_in_the_library_format():
    t0 = time.time()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        w = world(1, 500)
        rows = w.rows()
    assert time.time() - t0 < 10 and len(w.people) == 1500
    from lifeimage.generators.common import validate_row
    ids = seed_ids()
    for r in rows[::25]:
        validate_row(r)
        assert all(m["domain"] in ids or m["domain"].startswith("f.") for m in r["memberships"])
    assert {"born", "marriage", "birth_of_child"} <= {k for p in w.people for k, _ in p.events}


def test_missing_region_degrades_loudly_and_never_stalls():
    tab = table()
    with warnings.catch_warnings(record=True) as w:
        warnings.simplefilter("always")
        wd = World(tab, ("ZZZ", "KEN"), 100, 1, region_map=RM)
        rows = wd.rows()
    assert rows and any(d["region"] == "ZZZ" and d["substitute"] in ("WLD", "none") for d in wd.degraded)
    assert all({"step", "mechanism", "substitute", "reason"} <= set(d) for d in wd.degraded)
    kinds = {(d["mechanism"], "none" if d["substitute"] == "none" else "world" if d["substitute"].startswith("WLD") else "region") for d in wd.degraded}
    assert len([x for x in w if "degraded" in str(x.message)]) == len(kinds)       # one warning per kind
    # the default probe region absent from the table (FRA) degrades to its World Bank region or the world
    t2 = table()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        World(t2, ("FRA",), 50, 1, region_map=RM)
    assert {d["substitute"] for d in t2.degraded if d["region"] == "FRA"} & {"ECS", "WLD"}


def test_incoherent_shares_are_clipped_loudly_and_head_targets_follow_the_clip():
    tab = table()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        tg = expected_targets(tab, ("KEN",), RM)
    assert any(d["substitute"] == "preceding level's share" for d in tab.degraded)
    assert tg[("share:primary_completion", "all", "f", "KEN")][2] is True
    assert tg[("share:primary_completion", "all", "f", "KEN")][0] <= tg[("share:primary_entry", "all", "f", "KEN")][0] + 1e-9


def test_each_noise_parameter_moves_only_its_own_mechanism():
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        base, fr, ma, de = (world(3, 200, noise=n) for n in ({}, {"fertility_frailty_sd": 0.4}, {"marriage_age_sd": 6.0}, {"school_entry_delay_p": 0.4}))
    ev = lambda w, keys: [[e for e in p.events if e[0] in keys] for p in w.people]  # noqa: E731
    school = ("preschool", "school_start", "primary_complete", "secondary_start", "secondary_complete", "tertiary_start", "tertiary_complete")
    assert ev(base, ("marriage",)) == ev(fr, ("marriage",)) and ev(base, school) == ev(fr, school)
    assert ev(base, ("birth_of_child",)) == ev(ma, ("birth_of_child",)) and ev(base, school) == ev(ma, school)
    assert ev(base, ("birth_of_child", "marriage")) == ev(de, ("birth_of_child", "marriage"))
    assert ev(base, ("birth_of_child",)) != ev(fr, ("birth_of_child",))


def test_same_seed_same_world_and_paired_effect():
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        a, b = world(5, 100), world(5, 100)
    assert [p.events for p in a.people] == [p.events for p in b.people]
    m, se, z = paired_effect([2.0, 2.1, 1.9, 2.2], [1.0, 1.0, 1.0, 1.0])
    assert m > 1 and z > 2


def test_table_internal_coherence_asfr_sum_vs_tfr():
    c = table_coherence(table(), RM)
    assert len(c) >= 7 and sum(x["ok"] for x in c) >= len(c) - 1, c


def test_governed_and_noise_parameters_are_listed_with_sources_and_ranges():
    names = [n for n in GOVERNED if n.startswith(("eventgen.", "noise."))]
    assert len(names) >= 15 and all(GOVERNED[n]["source"].strip() for n in names)
    noise = [n for n in names if n.startswith("noise.")]
    assert noise and all(GOVERNED[n]["range"][0] <= GOVERNED[n]["default"] <= GOVERNED[n]["range"][1] for n in noise)
    assert all(GOVERNED[n]["default"] <= (GOVERNED[n]["range"][0] + GOVERNED[n]["range"][1]) / 2 for n in noise)  # mild end
