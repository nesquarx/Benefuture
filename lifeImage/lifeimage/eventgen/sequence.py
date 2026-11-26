"""Sequence head: the verifier's second head. The rate head reads marginals; this one reads the order of each life.

It works only on the generated relational events of each person (kinds, valid times, spans, links), never on the generator's internals.

Hard checks (zero tolerance, every person in every seed): no event after death or before birth; a divorce is linked part_of a prior
marriage of the same life; no birth or pregnancy before the governed minimum maternal age; schooling levels in order (a level needs
the one before, times do not decrease, nothing follows a dropout); causes do not follow their effects and a part lies inside its whole
(`relational.validate_links`); births belong to women and fatherhood to men; one death, last.

Soft checks (distributional, per region and sex, over paired seeds; `rates.judge` with the significance rule, z = 2): mean and median age
at first marriage and the spread (IQR), mean age at childbearing, median age at primary completion, share married by 18, and the
share of first births before the first marriage. A target comes from a calibration Param where one exists (`calibration` says which:
`param`, `derived` from a Param and a governed world parameter, or `assumed`); statistics without any target are reported, not judged.
A statistic passes by equivalence within its margin (never by mere non-significance), fails at z combined standard errors beyond the
margin, else is inconclusive. Survivors to the horizon are the sample (death is independent of the rest, so they are unbiased).
"""
import datetime as dt
from collections import Counter
from statistics import NormalDist, mean, median

from ..governed import governed
from ..validate import ValidationError
from .rates import judge
from .relational import validate_links
from .marriage import model as marriage_model
from .world import BIRTH_DATE, derive_setup

_N = NormalDist()
TOL = 0.01   # years: event dates are rounded to the day
SCHOOL = ("school_start", "primary_complete", "secondary_start", "secondary_complete", "tertiary_start", "tertiary_complete")


def life_records(world, light=True):
    """[{pid, region, sex, events}] of the world's relational events."""
    evs = world.events(light=light)
    return [{"pid": p.pid, "region": p.region, "sex": p.sex, "events": evs[p.pid]} for p in world.people]


def _d(iso):
    return dt.date.fromisoformat(iso)


def age_of(e):
    return (_d(e["valid_time"]) - BIRTH_DATE).days / 365.25


def hard_violations(records):
    """Counter of violated rules and up to three examples each: {code: (count, [(pid, message)])}."""
    found = {}

    def flag(code, pid, msg):
        c, ex = found.setdefault(code, [0, []])
        found[code][0] = c + 1
        if len(ex) < 3:
            ex.append((pid, msg))
    minage = governed("eventgen.min_maternal_age")
    for r in records:
        evs, pid = r["events"], r["pid"]
        by = {}
        for e in evs:
            by.setdefault(e["kind"], []).append(e)
        born = by.get("born", [None])[0]
        deaths = by.get("death", [])
        if len(deaths) > 1:
            flag("two_deaths", pid, f"{len(deaths)} deaths")
        d = _d(deaths[0]["valid_time"]) if deaths else None
        for e in evs:
            if born is not None and _d(e["valid_time"]) < _d(born["valid_time"]):
                flag("event_before_birth", pid, f"{e['kind']} {e['valid_time']}")
            if d is not None and e["kind"] != "death" and (_d(e["valid_time"]) > d or _d(e["span"]["end"]) > d):
                flag("event_after_death", pid, f"{e['kind']} {e['valid_time']}..{e['span']['end']} after death {d}")
        byid = {e["id"]: e for e in evs}
        for e in by.get("divorce", []):
            ok = any(l["type"] == "part_of" and byid.get(l["to"], {}).get("kind") == "marriage" and _d(byid[l["to"]]["valid_time"]) <= _d(e["valid_time"])
                     for l in e["links"])
            if not ok:
                flag("divorce_without_prior_marriage", pid, f"divorce {e['valid_time']} has no part_of link to an earlier marriage")
        for k in ("birth_of_child", "pregnancy"):
            for e in by.get(k, []):
                if age_of(e) < minage - 1e-6:
                    flag("birth_before_minimum_maternal_age", pid, f"{k} at {age_of(e):.1f}")
        if (r["sex"] == "m" and by.get("birth_of_child")) or (r["sex"] == "f" and by.get("fatherhood")):
            flag("parenthood_of_wrong_sex", pid, r["sex"])
        _schooling(by, pid, flag)
        _domains(by, evs, pid, flag, r["sex"])
        for e in evs:
            if e["record_time"] < e["valid_time"]:
                flag("record_before_valid_time", pid, f"{e['kind']} recorded {e['record_time']} before it happened {e['valid_time']}")
        try:
            validate_links(evs)
        except ValidationError as exc:
            flag("link_violates_time_or_span", pid, str(exc))
    return {k: (v[0], v[1]) for k, v in found.items()}


def _schooling(by, pid, flag):
    t = {k: _d(by[k][0]["valid_time"]) for k in SCHOOL + ("preschool", "school_dropout") if by.get(k)}
    for i, k in enumerate(SCHOOL):
        if k in t and i and SCHOOL[i - 1] not in t:
            flag("school_level_without_previous", pid, f"{k} without {SCHOOL[i - 1]}")
        if k in t and i and SCHOOL[i - 1] in t and t[k] < t[SCHOOL[i - 1]]:
            flag("school_levels_out_of_order", pid, f"{k} {t[k]} before {SCHOOL[i - 1]} {t[SCHOOL[i - 1]]}")
    if "preschool" in t and "school_start" in t and t["preschool"] > t["school_start"]:
        flag("school_levels_out_of_order", pid, "preschool after school_start")
    if len(by.get("school_dropout", [])) > 1:
        flag("school_levels_out_of_order", pid, "two dropouts")
    if "school_dropout" in t and any(k in t and t[k] > t["school_dropout"] for k in SCHOOL):
        flag("school_levels_out_of_order", pid, "schooling continues after dropout")
    if "school_dropout" in t and "school_start" not in t:
        flag("school_level_without_previous", pid, "dropout without school_start")


def _span(e):
    return _d(e["valid_time"]), _d(e["span"]["end"])


def _domains(by, evs, pid, flag, sex):
    """Hard rules of the work, harm and care machines: no work before the minimum working age; retirement follows a start of work, at or after the governed
    minimum age; every reemployment ends a job-loss spell and no job loss starts inside another; a day at work lies inside a spell of employment;
    no suspected offence or conviction before the minimum age of criminal responsibility and a conviction follows a suspected offence; partner violence only
    inside a marriage."""
    minwork, minoff, minret = governed("eventgen.min_working_age"), governed("eventgen.min_offending_age"), governed("eventgen.retirement_min_age")
    starts = [e for e in evs if e["kind"] in ("industry_work_start", "service_work_start", "farm_work_start", "self_employment_start")]
    jobs = sorted(starts + by.get("job_change", []) + by.get("reemployment", []) + by.get("job_loss", []) + by.get("retirement", []), key=lambda e: e["valid_time"])
    for e in jobs:
        if age_of(e) < minwork - TOL:
            flag("work_before_minimum_age", pid, f"{e['kind']} at {age_of(e):.1f}")
    if by.get("retirement"):
        ret = by["retirement"][0]
        if not starts or _d(starts[0]["valid_time"]) > _d(ret["valid_time"]):
            flag("retirement_without_work", pid, "retirement before any start of work")
        if age_of(ret) < minret - TOL:
            flag("retirement_before_minimum_age", pid, f"retirement at {age_of(ret):.1f}")
        if len(by["retirement"]) > 1:
            flag("retirement_without_work", pid, "two retirements")
    spells = sorted(by.get("job_loss", []), key=lambda e: e["valid_time"])
    for a, b in zip(spells, spells[1:]):
        if _d(b["valid_time"]) < _d(a["span"]["end"]):
            flag("job_loss_inside_spell", pid, f"{b['valid_time']} inside spell to {a['span']['end']}")
    for e in by.get("reemployment", []):
        if not any(_d(s["span"]["end"]) == _d(e["valid_time"]) or abs((_d(s["span"]["end"]) - _d(e["valid_time"])).days) <= 1 for s in spells):
            flag("reemployment_without_job_loss", pid, e["valid_time"])
    ret = _d(by["retirement"][0]["valid_time"]) if by.get("retirement") else None
    for e in by.get("employment", []):
        t = _d(e["valid_time"])
        ok = starts and _d(starts[0]["valid_time"]) <= t and (ret is None or t <= ret) and not any(_d(s["valid_time"]) < t < _d(s["span"]["end"]) for s in spells)
        if not ok:
            flag("work_day_outside_employment", pid, f"employment on {e['valid_time']}")
    for k in ("suspected_offence", "conviction"):
        for e in by.get(k, []):
            if age_of(e) < minoff - TOL:
                flag("offence_before_minimum_age", pid, f"{k} at {age_of(e):.1f}")
    sus = [_d(e["valid_time"]) for e in by.get("suspected_offence", [])]
    for e in by.get("conviction", []):
        if not any(s <= _d(e["valid_time"]) for s in sus):
            flag("conviction_without_suspicion", pid, e["valid_time"])
    mar, div = by.get("marriage", []), by.get("divorce", [])
    for e in by.get("partner_violence_victim", []):
        t = _d(e["valid_time"])
        if not mar or t < _d(mar[0]["valid_time"]) or (div and t >= _d(div[0]["valid_time"])):
            flag("partner_violence_outside_union", pid, e["valid_time"])


# ---- soft statistics ----
def _first(evs, kind):
    return next((e for e in evs if e["kind"] == kind), None)


def _quartiles(x):
    x = sorted(x)
    q = lambda f: x[min(len(x) - 1, int(f * (len(x) - 1) + 0.5))]  # noqa: E731
    return q(0.25), q(0.75)


def soft_statistics(records, regions):
    """{(name, age band, sex, region): value} of the generated sequences; NaN where a stratum has no one."""
    nan = float("nan")
    out = {}
    for rg in regions:
        for sx in "fm":
            Q = [r for r in records if r["region"] == rg and r["sex"] == sx and not any(e["kind"] == "death" for e in r["events"])]
            marr = [age_of(m) for r in Q if (m := _first(r["events"], "marriage"))]
            out[("seq.mean_age_first_marriage", "all", sx, rg)] = mean(marr) if marr else nan
            out[("seq.median_age_first_marriage", "all", sx, rg)] = median(marr) if marr else nan
            out[("seq.iqr_age_first_marriage", "all", sx, rg)] = (lambda q: q[1] - q[0])(_quartiles(marr)) if len(marr) > 3 else nan
            if sx == "f":
                ages = [age_of(e) for r in Q for e in r["events"] if e["kind"] == "birth_of_child"]
                out[("seq.mean_age_childbearing", "15-49", "f", rg)] = mean(ages) if ages else nan
                out[("seq.share_married_by_18", "20-24", "f", rg)] = (sum(a < 18 for a in marr) / len(Q)) if Q else nan
                bm = [(_first(r["events"], "marriage"), _first(r["events"], "divorce"), [age_of(e) for e in r["events"] if e["kind"] == "birth_of_child"]) for r in Q]
                nb = sum(len(b) for _, _, b in bm)
                outside = sum(1 for m, dv, b in bm for a in b if m is None or a < age_of(m) or (dv is not None and a >= age_of(dv)))
                out[("seq.births_outside_marriage_share", "all", "f", rg)] = outside / nb if nb else nan
                mothers = [r for r in Q if _first(r["events"], "birth_of_child")]
                pre = [r for r in mothers if not (m := _first(r["events"], "marriage")) or _d(_first(r["events"], "birth_of_child")["valid_time"]) < _d(m["valid_time"])]
                out[("seq.premarital_first_birth_share", "all", "f", rg)] = len(pre) / len(mothers) if mothers else nan
            prim = [age_of(e) for r in Q if (e := _first(r["events"], "primary_complete"))]
            out[("seq.median_age_primary_completion", "all", sx, rg)] = median(prim) if prim else nan
    return out


def describe(records, regions):
    """Median and IQR of age at first marriage, first birth (women), first fatherhood (men) and school completion, per region and sex; not judged."""
    out = {}
    for rg in regions:
        for sx in "fm":
            Q = [r for r in records if r["region"] == rg and r["sex"] == sx and not any(e["kind"] == "death" for e in r["events"])]
            for name, kind in (("first_marriage", "marriage"), ("first_birth", "birth_of_child" if sx == "f" else "fatherhood"),
                               ("school_completion", "secondary_complete"), ("primary_completion", "primary_complete")):
                a = [age_of(e) for r in Q if (e := _first(r["events"], kind))]
                if len(a) > 3:
                    lo, hi = _quartiles(a)
                    out[(name, sx, rg)] = {"n": len(a), "median": median(a), "iqr": hi - lo}
    return out


def soft_targets(table, regions, region_map):
    """{key: (target, kind, confidence, margin)}: `kind` is param (a Param of the region's own stratum), derived (such a Param plus a governed
    world parameter) or assumed. A Param that exists only at world level (or not at all) is no target for a region: the statistic is left
    unjudged and the substitution recorded loudly (`degraded`), never judged against another place's value or the generator's own default."""
    my, mp = governed("eventgen.seq_margin_years"), governed("eventgen.seq_margin_prop")
    out = {}
    for rg in regions:
        S = derive_setup(table, rg, region_map)
        step = f"seqhead:{rg}"

        def own(q, band, sx="all"):
            p = table.lookup(q, band, sx, rg, region_map, step)
            if p is not None and p.region in (rg, region_map.get(rg)):
                return p
            table.degrade(step, q, rg, "statistic unjudged", "no Param of the region's own stratum (country or World Bank region) to serve as a target")
            return None
        sd = governed("noise.marriage_age_sd")
        for sx in "fm":
            p = own("family.age_first_marriage", "all", sx)
            if p is not None:
                M = marriage_model(S["smam"][sx], sd, S["married_by_18"] / governed("eventgen.partnership_ever_share") if sx == "f" and S["married_by_18"] is not None else None,
                                   governed("noise.marriage_early_mean"), governed("noise.marriage_early_sd"), float(governed("eventgen.minor_age")))
                q = M.ppf
                out[("seq.mean_age_first_marriage", "all", sx, rg)] = (S["smam"][sx], "param", p.confidence, my)
                out[("seq.median_age_first_marriage", "all", sx, rg)] = (q(0.5), "derived", p.confidence, my)
                out[("seq.iqr_age_first_marriage", "all", sx, rg)] = (q(0.75) - q(0.25), "derived", "low", 2 * my)
            if own("education.primary_entry_age", "all") is not None and own("education.primary_duration", "all") is not None:
                out[("seq.median_age_primary_completion", "all", sx, rg)] = (float(S["entry_age"] + S["prim_dur"]), "param", "high", my)
        m = own("fertility.mean_age_childbearing", "15-49", "f")
        if m is not None:
            out[("seq.mean_age_childbearing", "15-49", "f", rg)] = (m.value, "param", m.confidence, my)
        b = own("family.married_by_18", "20-24", "f")
        if b is not None:
            out[("seq.share_married_by_18", "20-24", "f", rg)] = (b.value / 100, "param", b.confidence, mp)
        bo = own("family.births_outside_marriage", "all", "f")
        if bo is not None:   # Eurostat live births by the mother's legal marital status; the share of first births before marriage has no source and is reported only
            out[("seq.births_outside_marriage_share", "all", "f", rg)] = (bo.value / 100, "param", bo.confidence, governed("eventgen.seq_margin_prop"))
    return out


def sequence_head(true_table, make_world, regions, region_map, seeds=None, z=None, seed0=0, hard_only=False):
    """Per seed: hard violations over all lives; over seeds: soft verdicts per statistic. `make_world(seed)` builds the generated world.
    Seeds are added by precision like the rate head (min_seeds first, then one at a time until every judged statistic is decided, capped)."""
    targets = soft_targets(true_table, regions, region_map)
    zz = governed("eventgen.rate_z") if z is None else z
    series = {k: [] for k in targets}
    hard, seed = [], seed0

    def add():
        nonlocal seed
        seed += 1
        recs = life_records(make_world(seed))
        hard.append(hard_violations(recs))
        st = soft_statistics(recs, regions)
        for k in targets:
            series[k].append(st[k])

    def stable():
        for k, (t, kind, conf, mg) in targets.items():
            v = [x for x in series[k] if x == x]
            if len(v) < 2 or judge(k[0], v, t, conf, zz, margin=mg)["status"] == "inconclusive":
                return False
        return True
    if seeds:
        for _ in range(seeds):
            add()
    else:
        for _ in range(governed("eventgen.min_seeds")):
            add()
        while not hard_only and not stable() and len(hard) < governed("eventgen.max_seeds"):
            add()
    results = []
    for k, (t, kind, conf, mg) in sorted(targets.items()):
        v = [x for x in series[k] if x == x]
        results.append({"key": k, "calibration": kind, "confidence": conf, **(judge(k[0], v, t, conf, zz, margin=mg) if len(v) > 1 else {"status": "inconclusive"})})
    codes = Counter(c for h in hard for c in h)
    return {"seeds": len(hard), "hard": hard, "hard_failing_seeds": sum(bool(h) for h in hard), "hard_codes": dict(codes), "soft": results,
            "soft_summary": {s: sum(r["status"] == s for r in results) for s in ("pass", "fail", "inconclusive")},
            "calibrated_passing": sum(r["status"] == "pass" and r["calibration"] == "param" for r in results)}
