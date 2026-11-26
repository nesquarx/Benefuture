"""Domain state machines of increment 3: work and careers, health and care, everyday time use, leisure and sport, social and civic life, harms.

Every machine reads its inputs from the calibration table through `derive` (one lookup per quantity with the country -> region -> world chain; a quantity
missing at every level leaves its kind ungenerated for the region and is recorded loudly, a coarser substitute is used and recorded where one exists) and
draws from a stream per (seed, region, mechanism, person), so a noise parameter or a Param moves only its own mechanism and arms share seeds.
Events are plain (kind, age) pairs on `Person.events` (spans, minutes and survey reference years in side tables), turned into relational events by
`relational.py` from `catalog.py`.

Machines (all toy assumptions named in the package README):
  work      labour-force participation by age and sex is a nested threshold (a person is in the labour force at age a iff a latent draw is below the curve at a,
            so the marginal at every age is the Param and entries and exits are ordered); first entry (wage work, farm work or self-employment from the WDI
            shares), job changes (hazard from the share of employed with tenure under a year), unemployment spells (onset hazard from the unemployment rate and a
            mean duration from the long-term share; the stationary rate is the Param) and retirement (the first exit after `retirement_min_age`).
  health    vaccination at age one (measles coverage), diabetes, HIV and disability onset as nested thresholds on prevalence curves, tuberculosis incidence,
            and in survey reference years doctor visits and informal caring.
  time use  diary days: for each activity the participation rate by age and sex and minutes per participant (HETUS; India's survey for the group level).
  leisure, civic   in survey reference years: cultural visits, sport, voting, volunteering, active citizenship, religious attendance.
  harm      victimisation by offence class (police-recorded rates per inhabitant), partner violence, suspected offences and convictions with their victim.
"""
import math
import random
from bisect import bisect_right

from ..governed import governed
from . import catalog

K = catalog.BY_KEY
BANDS_H = (("16-24", 16, 25), ("25-34", 25, 35), ("35-44", 35, 45), ("45-54", 45, 55), ("55-64", 55, 65), ("65-74", 65, 75), ("75+", 75, 200))
TU = catalog.AGE_BANDS   # (lo, hi, label): the five diary age bands
INDIA_BAND = {"15-20": "15-29", "20-24": "15-29", "25-44": "15-59", "45-64": "15-59", "65+": "60+"}   # HETUS band -> the India age group its group-level Param is applied to
ANNUAL = {"doctor_visit": "health.doctor_visit_12m", "caregiving_start": "health.informal_care_share", "cinema_visit": "leisure.cinema_12m",
          "live_performance": "leisure.live_performance_12m", "cultural_site_visit": "leisure.cultural_site_12m", "sports_event": "leisure.sports_event_12m",
          "aerobic_sport": "leisure.aerobic_activity_150min", "strength_training": "leisure.strength_2days", "cycling_trip": "leisure.cycling_week",
          "formal_volunteering": "civic.formal_volunteering_12m", "informal_volunteering": "civic.informal_volunteering_12m", "active_citizenship": "civic.active_citizenship_12m"}
VICTIM = {"theft_victim": "harm.theft_recorded_rate", "burglary_victim": "harm.burglary_recorded_rate", "robbery_victim": "harm.robbery_recorded_rate",
          "assault_victim": "harm.assault_recorded_rate", "sexual_violence_victim": "harm.sexual_violence_recorded_rate", "fraud_victim": "harm.fraud_recorded_rate",
          "cyber_victim": "harm.cybercrime_recorded_rate"}
ENTRY = ("industry_work_start", "service_work_start", "farm_work_start", "self_employment_start")
LF_ENTRY = ("job_search_start",) + ENTRY
JOB_START = ENTRY + ("job_change", "reemployment")
# adoption events: (Param quantity, divisor of its value, mean age, sd, minimum age); the person adopts with probability = the Param's share, at a truncated-normal age
ADOPT = {"migration": ("mobility.migrant_stock", 100, 26.0, 6.0, 18.0), "account_opening": ("money.account_ownership", 100, 24.0, 6.0, 15.0),
         "phone_subscription": ("tech.mobile_subscriptions", 100, 20.0, 8.0, 10.0), "internet_adoption": ("tech.internet_use", 100, 22.0, 10.0, 10.0)}
JUDGE_MIN_SHARE = 0.10   # a band cell is judged on its own only where the rate is at least this (rarer cells are pooled across bands): below it a seed's sample cannot decide the verdict
ANNUAL_LO, ANNUAL_TOP = 16.0, 69.0   # reference years start in [16, 69)
EXPOSURE = (10.0, 70.0)   # ages over which a recorded rate per inhabitant is applied as a per-person hazard


def pstream(seed, region, mech, i):
    return random.Random(f"{seed}|eventgen|{region}|{mech}|{i}")


def _idx(table):
    ix = getattr(table, "_dom_idx", None)
    if ix is None:
        ix = {}
        for p in table.params:
            ix.setdefault((p.quantity, p.region), []).append(p)
        table._dom_idx = ix
    return ix


def stratum(table, quantity, region, regions, step):
    """The region whose Param of `quantity` serves `region` (itself, its World Bank region, the world), the substitution recorded once; None when no level has it."""
    ix = _idx(table)
    chain = [region] + ([regions[region]] if regions.get(region) and regions[region] != region else []) + (["WLD"] if region != "WLD" else [])
    for r in chain:
        if (quantity, r) in ix:
            if r != region:
                table.degrade(step, quantity, region, r, f"no {quantity} for {region}")
            return r
    table.degrade(step, quantity, region, "none", f"no {quantity} at any level for {region}: the kind is not generated, or a governed default applies")
    return None


def value(table, quantity, region, step, regions, band="all", sex="all", default=None):
    p = table.lookup(quantity, band, sex, region, regions, step)
    return p.value if p is not None else default


def curve(table, quantity, region, regions, step, bands=BANDS_H):
    """{sex: [(lo, hi, p)]} of a survey proportion by age band and sex (percent -> share), from the serving stratum; None when no level has it."""
    st = stratum(table, quantity, region, regions, step)
    if st is None:
        return None
    ix = {(p.age_band, p.sex): p.value / 100 for p in _idx(table)[(quantity, st)]}
    out = {}
    for sx in "fm":
        row = []
        for label, lo, hi in bands:
            v = ix.get((label, sx), ix.get((label, "all")))
            if v is None and ("all", "all") in ix:
                v = ix[("all", "all")]
            if v is None:
                continue
            row.append((lo, hi, v))
        if not row:
            return None
        out[sx] = row
    return out


def at(rows, a):
    """Value of a banded curve at age a (the last band's value beyond it, the first's before it)."""
    for lo, hi, v in rows:
        if lo <= a < hi:
            return v
    return rows[-1][2] if a >= rows[-1][1] else rows[0][2]


# ---------------- derive: every input of the machines for a region ----------------
def derive(table, region, regions, S):
    step = f"domains:{region}"
    D = {"region": region, "work": {}, "health": {}, "annual": {}, "harm": {}, "tu": {}, "groups": {}, "absent": []}
    D["work"] = _derive_work(table, region, regions, step)
    D["health"] = _derive_health(table, region, regions, step)
    for kind, q in ANNUAL.items():
        c = curve(table, q, region, regions, step)
        if c is None:
            D["absent"].append(kind)
        D["annual"][kind] = c
    turn = value(table, "civic.voter_turnout", region, step, regions)
    D["annual"]["voting"] = turn / 100 / governed("eventgen.election_cycle_years") if turn is not None else None
    if turn is None:
        D["absent"].append("voting")
    rel = value(table, "civic.religious_attendance", region, step, regions)
    if rel is None:
        table.degrade(step, "civic.religious_attendance", region, f"governed default {governed('eventgen.religious_attendance_default')}", "no religious-attendance Param at any level")
    D["annual"]["religious_service"] = rel / 100 if rel is not None else governed("eventgen.religious_attendance_default")
    D["adopt"] = {}
    for kind, (q, div, mean, sd, lo) in ADOPT.items():
        v = value(table, q, region, step, regions)
        D["adopt"][kind] = None if v is None else (min(0.97, v / div), mean, sd, lo)
    cp = value(table, "family.contraceptive_prevalence", region, step, regions, "15-49", "f")
    D["contraception"] = cp / 100 if cp is not None else None
    vs = value(table, "education.vocational_share_secondary", region, step, regions, "secondary")
    D["vocational"] = vs / 100 if vs is not None else None
    D["harm"] = _derive_harm(table, region, regions, step)
    D["tu"], D["groups"] = _derive_time_use(table, region, regions, step)
    _note_employment_cap(table, D, region, step)
    return D


def _derive_work(table, region, regions, step):
    W = {}
    nodes = {}
    for sx in "fm":
        v = {b: value(table, "work.labour_force_participation", region, step, regions, b, sx) for b in ("15-24", "25-54", "55-64", "65+")}
        if any(x is None for x in v.values()):
            W["lfp"] = None
            break
        nodes[sx] = {b: x / 100 for b, x in v.items()}
    else:
        W["lfp"] = {sx: lfp_curve(nodes[sx]) for sx in "fm"}
        W["lfp_nodes"] = nodes
    u_all = value(table, "work.unemployment", region, step, regions, "15+")
    u_y = value(table, "work.youth_unemployment", region, step, regions, "15-24")
    W["unemp"] = {"adult": None if u_all is None else u_all / 100, "youth": None if u_y is None else u_y / 100}
    if W.get("lfp") is not None and u_all is not None and u_y is not None:
        wy = sum(W["lfp"][sx][a] for sx in "fm" for a in range(15, 25))
        wa = sum(W["lfp"][sx][a] for sx in "fm" for a in range(25, 70))
        adult = (u_all / 100 * (wy + wa) - u_y / 100 * wy) / wa if wa > 0 else u_all / 100
        W["unemp"]["adult"] = min(0.5, max(0.005, adult))   # the pooled rate over ages 15+ is the Param's, the youth rate its own
    ltu = value(table, "work.long_term_unemployment_share", region, step, regions, "15-74")
    if ltu is None:
        W["spell_years"] = governed("eventgen.unemployment_spell_default_years")
        table.degrade(step, "work.long_term_unemployment_share", region, f"governed default {W['spell_years']} years", "no long-term-unemployment Param at any level")
    else:
        W["spell_years"] = min(5.0, max(0.2, -1 / math.log(min(0.95, max(0.05, ltu / 100)))))
    nj = {b: value(table, "work.new_job_share", region, step, regions, b, "all") for b in ("15-24", "15-64")}
    W["new_job"] = {b: (x / 100 if x is not None else None) for b, x in nj.items()}
    if all(x is None for x in nj.values()):
        table.degrade(step, "work.new_job_share", region, f"governed default {governed('eventgen.job_change_default')} per year", "no job-tenure Param at any level")
    W["agri"] = (value(table, "work.agriculture_employment", region, step, regions, "15+", default=0.0)) / 100
    W["self"] = (value(table, "work.self_employment", region, step, regions, "15+", default=0.0)) / 100
    ind = value(table, "work.industry_employment", region, step, regions, "15+")
    srv = value(table, "work.services_employment", region, step, regions, "15+")
    W["industry_share"] = ind / (ind + srv) if ind is not None and srv is not None and ind + srv > 0 else 0.3   # among non-farm wage work
    return W


BAND_EDGES = {"15-24": (15, 25), "25-54": (25, 55), "55-64": (55, 65), "65+": (65, 70)}


def lfp_curve(v):
    """Labour-force participation by single year of age 15..69 for one sex: rising through the youth band, a plateau over the prime ages (27-50), falling through
    the 55-64 and 65+ band midpoints, rescaled per band so each band's mean is the Param."""
    nodes = [(15.0, 0.25 * v["15-24"]), (19.5, v["15-24"]), (27.0, v["25-54"]), (50.0, v["25-54"]), (59.5, v["55-64"]), (67.5, v["65+"])]

    def interp(a):
        if a <= nodes[0][0]:
            return nodes[0][1]
        if a >= nodes[-1][0]:
            return nodes[-1][1]
        for (x0, y0), (x1, y1) in zip(nodes, nodes[1:]):
            if x0 <= a <= x1:
                return y0 + (y1 - y0) * (a - x0) / (x1 - x0)
    raw = {a: interp(a + 0.5) for a in range(15, 71)}
    out = {}
    for b, (lo, hi) in BAND_EDGES.items():
        m = sum(raw[a] for a in range(lo, hi)) / (hi - lo)
        c = v[b] / m if m > 0 else 0.0
        for a in range(lo, hi):
            out[a] = min(1.0, raw[a] * c)
    return out


def lfp_path(lfp, u, minage, retmin):
    """(entry, retirement) ages of a person with latent draw u: in the labour force at age x iff u < f(x), f the participation curve interpolated linearly
    through its year midpoints (so the share in the labour force at every age is the curve); entry is the first upward crossing at or after `minage`, the
    retirement the first downward crossing after the entry and `retmin`; None where the curve never exceeds u (no entry) or never falls back below it."""
    pts = [(a + 0.5, lfp[a]) for a in range(15, 70)]
    entry = minage if pts[0][1] > u else None
    if entry is None:
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            if y0 <= u < y1:
                entry = x0 + (u - y0) / (y1 - y0) * (x1 - x0)
                break
    if entry is None:
        return None, None
    start = max(entry, retmin)
    at_start = next((y0 + (y1 - y0) * (start - x0) / (x1 - x0) for (x0, y0), (x1, y1) in zip(pts, pts[1:]) if x0 <= start <= x1), pts[-1][1])
    if at_start <= u:   # a curve that has already fallen below u before the minimum retirement age: the exit is recorded at that age
        return entry, start
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if x1 > start and y0 > u >= y1:
            x = x0 + (y0 - u) / (y0 - y1) * (x1 - x0)
            if x >= start:
                return entry, x
    return entry, None


def _derive_health(table, region, regions, step):
    H = {}
    H["vacc"] = value(table, "health.measles_immunisation", region, step, regions, "12-23 months")
    H["vacc"] = H["vacc"] / 100 if H["vacc"] is not None else None
    for q, key in (("health.diabetes_prevalence", "diab"), ("health.hiv_prevalence", "hiv")):
        v = value(table, q, region, step, regions, "20-79" if key == "diab" else "15-49")
        H[key] = v / 100 if v is not None else None
    tb = value(table, "health.tb_incidence", region, step, regions, "all")
    H["tb"] = tb / 1e5 if tb is not None else None
    H["diab_prev"] = diabetes_prevalence_curve(H["diab"]) if H["diab"] is not None else None
    H["hiv_prev"] = hiv_prevalence_curve(H["hiv"]) if H["hiv"] is not None else None
    H["disab"] = _disability(table, region, regions, step)
    return H


def _grid_mean(f, lo, hi):
    return sum(f(a + 0.5) for a in range(lo, hi)) / (hi - lo)


def diabetes_prevalence_curve(level):
    """Prevalence at single years of age 20..70 (logistic gradient, governed centre and scale) whose mean over ages 20-79 equals the WDI prevalence `level`."""
    mu, sd = governed("eventgen.diabetes_gradient_age"), governed("eventgen.diabetes_gradient_sd")
    s = lambda a: 1 / (1 + math.exp(-(a - mu) / sd))   # noqa: E731
    c = level / _grid_mean(s, 20, 80)
    return {a: min(0.95, c * s(a + 0.5)) for a in range(20, 71)}


def hiv_prevalence_curve(level):
    """Share ever infected by single year of age 15..70 (normal onset age, governed), scaled so the mean over ages 15-49 equals the WDI prevalence `level`."""
    from statistics import NormalDist
    nd = NormalDist(governed("eventgen.hiv_onset_mean"), governed("eventgen.hiv_onset_sd"))
    f = lambda a: nd.cdf(a)   # noqa: E731
    c = level / _grid_mean(f, 15, 50)
    return {a: min(0.95, c * f(a + 0.5)) for a in range(15, 71)}


def _disability(table, region, regions, step):
    c = curve(table, "health.disability_prevalence", region, regions, step)
    if c is None:
        return None
    out = {}
    for sx in "fm":
        run, cur = 0.0, {}
        for a in range(16, 71):   # prevalence rises with age; a dip between bands is flattened (the stock cannot fall)
            run = max(run, at(c[sx], a + 0.5))
            cur[a] = run
        out[sx] = cur
    # a world-level Param with no age bands is flat in the table: reshape with the ECS age profile (a cross-region substitute, recorded)
    st = stratum(table, "health.disability_prevalence", region, regions, step + ":shape")
    if st == "WLD" and len({v for _, _, v in c["f"]}) == 1:
        prof = curve(table, "health.disability_prevalence", "FRA", regions, step + ":shape")
        if prof is not None:
            table.degrade(step, "health.disability_prevalence", region, "ECS age profile rescaled to the world level", "the world-level Param has no age bands")
            for sx in "fm":
                lvl = c[sx][0][2]
                mean = sum(at(prof[sx], a + 0.5) for a in range(16, 71)) / 55
                run, cur = 0.0, {}
                for a in range(16, 71):
                    run = max(run, min(0.95, at(prof[sx], a + 0.5) * lvl / mean))
                    cur[a] = run
                out[sx] = cur
    return out


def _derive_harm(table, region, regions, step):
    Hm = {"victim": {}}
    for kind, q in VICTIM.items():
        v = value(table, q, region, step, regions)
        Hm["victim"][kind] = v / 1e5 if v is not None else None
    pv = value(table, "harm.partner_violence_12m", region, step, regions, "15-49", "f")
    Hm["partner"] = pv / 100 if pv is not None else None
    Hm["suspect"] = {sx: value(table, "harm.suspect_rate", region, step, regions, "all", sx) for sx in "fm"}
    Hm["suspect"] = {sx: (v / 1e5 if v is not None else None) for sx, v in Hm["suspect"].items()}
    cv = {sx: value(table, "harm.conviction_rate", region, step, regions, "all", sx) for sx in "fm"}
    Hm["conviction_ratio"] = {sx: (min(0.95, cv[sx] / 1e5 / Hm["suspect"][sx]) if cv[sx] is not None and Hm["suspect"][sx] else None) for sx in "fm"}
    lo, hi = governed("eventgen.min_offending_age"), governed("eventgen.life_horizon_age")
    pk, dec = governed("eventgen.offending_peak_age"), governed("eventgen.offending_decay_per_year")
    w = {a: (math.exp(-dec * (a + 0.5 - pk)) if a + 0.5 > pk else math.exp(-0.25 * (pk - a - 0.5))) for a in range(int(lo), int(hi))}
    m = sum(w.values()) / len(w)
    Hm["offending_shape"] = {a: x / m for a, x in w.items()}
    return Hm


# ---------------- time use ----------------
def _derive_time_use(table, region, regions, step):
    """{(kind, sex, band): (p, minutes, tag)} and the group Param targets. A kind's rate comes from the region's own fine Param (country, region, world); where
    the region has only India-style group Params the European profile is rescaled by group; where it has neither, the European profile stands in (recorded)."""
    ix = _idx(table)
    tu, groups = {}, {}
    chain = [region] + ([regions[region]] if regions.get(region) and regions[region] != region else []) + ["WLD"]
    ecs_ref = "ECS"
    fine = lambda k, r, sx, b: (  # noqa: E731
        next((p for p in ix.get((f"time.participation.{k}", r), []) if p.sex == sx and p.age_band == b), None),
        next((p for p in ix.get((f"time.minutes.{k}", r), []) if p.sex == sx and p.age_band == b), None))
    group_par = {}
    for g in catalog.INDIA_GROUPS:
        for p in ix.get((f"time.group.participation.{g}", region), []):
            group_par.setdefault((g, p.sex, p.age_band), {})["p"] = p.value / 100
        for p in ix.get((f"time.group.minutes.{g}", region), []):
            group_par.setdefault((g, p.sex, p.age_band), {})["m"] = p.value
    groups.update({k: v for k, v in group_par.items() if "p" in v})
    for k in catalog.TIME:
        for sx in "fm":
            for _, _, b in TU:
                got = None
                for r in chain:
                    pp, mm = fine(k.key, r, sx, b)
                    if pp is not None and mm is not None:
                        got = (pp.value / 100, mm.value, "own" if r == region else r)
                        break
                if got is None:
                    pp, mm = fine(k.key, ecs_ref, sx, b)
                    if pp is not None and mm is not None:
                        got = (pp.value / 100, mm.value, "ECS")
                if got is not None:
                    tu[(k.key, sx, b)] = got
    # fine kinds missing in the region's own strata: rescale by group where group Params exist
    own = {kk for kk, v in tu.items() if v[2] == "own" or v[2] in chain}
    cap = governed("eventgen.time_ratio_cap")
    if groups:
        for sx in "fm":
            for hb, ib in INDIA_BAND.items():
                for g in catalog.INDIA_GROUPS:
                    gp = groups.get((g, sx, ib))
                    members = [k for k in catalog.TIME if k.group == g and (k.key, sx, hb) in tu]
                    if g == "employment" and gp is not None and ("employment", sx, hb) in tu and ("travel_work", sx, hb) in tu:
                        # the journey to work follows a day at work (nested, not independent): the group's participation is the participation in work, the group's minutes
                        # the day's work plus its journey, in the European proportions
                        (pe, me, _), (pt, mt, _) = tu[("employment", sx, hb)], tu[("travel_work", sx, hb)]
                        share = min(1.0, pt / pe) if pe > 0 else 0.0
                        rm = min(cap, max(1 / cap, gp["m"] / (me + share * mt))) if "m" in gp and me + share * mt > 0 else 1.0
                        tu[("employment", sx, hb)] = (gp["p"], me * rm, "group")
                        tu[("travel_work", sx, hb)] = (min(1.0, share * gp["p"]), mt * rm, "group")
                        continue
                    if gp is None or not members:
                        if gp is not None and g == "own_use":
                            k = K["own_use_production"]
                            tu[(k.key, sx, hb)] = (gp["p"], gp.get("m", 60.0), "group")
                        continue
                    ps = [tu[(k.key, sx, hb)][0] for k in members]
                    ms = [tu[(k.key, sx, hb)][1] for k in members]
                    rho = _solve_rho(ps, gp["p"], cap)
                    p2 = [min(1.0, x * rho) for x in ps]
                    tot = sum(x * m for x, m in zip(p2, ms))
                    pg = 1 - math.prod(1 - x for x in p2)
                    rm = min(cap, max(1 / cap, gp.get("m", 0) * pg / tot)) if tot > 0 and "m" in gp else 1.0
                    for k, x, m in zip(members, p2, ms):
                        tu[(k.key, sx, hb)] = (x, m * rm, "group")
    absent = sorted({k.key for k in catalog.TIME} - {kk[0] for kk in tu})
    for key in absent:
        table.degrade(step, f"time.participation.{key}", region, "none", "no time-use Param at any level: the activity is not generated for the region")
    for kk, v in tu.items():
        if v[2] == "ECS" and region != ecs_ref and ecs_ref not in chain:
            table.degrade(step, f"time.participation.{kk[0]}", region, "ECS profile (cross-region)", "no time-use Param for the region or its World Bank region; the European profile stands in")
            break
    return tu, groups


def eff_employment(W, sx, lo, hi, p):
    """Share of diary days with work the generator can reach in the age span [lo, hi): a person works only in a job, so the share cannot exceed the share employed
    (labour-force participation times one minus unemployment) at each age; the source's rate is the target where it is lower (the cap is recorded)."""
    ages = range(max(int(lo), 15), min(int(hi), 70))
    if W.get("lfp") is None or not ages:
        return p
    return sum(min(p, p_employed(W, sx, a + 0.5)) for a in ages) / len(ages)


def _note_employment_cap(table, D, region, step):
    W = D["work"]
    if W.get("lfp") is None:
        return
    for sx in "fm":
        for lo, hi, b in TU:
            v = D["tu"].get(("employment", sx, b))
            if v is not None and eff_employment(W, sx, lo, hi, v[0]) < 0.97 * v[0]:
                table.degrade(step, "time.participation.employment", region, "share employed (cap)",
                              f"diary days at work ({100 * v[0]:.0f}% for {sx}, {b}) exceed the share employed at those ages: capped, the source's labour-force and time-use rates disagree")
                return


def _solve_rho(ps, target, cap):
    """Factor rho with 1 - prod(1 - min(1, rho p_k)) = target (bisection), within [1/cap, cap]."""
    f = lambda rho: 1 - math.prod(1 - min(1.0, rho * x) for x in ps)   # noqa: E731
    lo, hi = 1 / cap, cap
    if f(hi) < target:
        return hi
    if f(lo) > target:
        return lo
    for _ in range(40):
        m = (lo + hi) / 2
        lo, hi = (m, hi) if f(m) < target else (lo, m)
    return (lo + hi) / 2


# ---------------- generation ----------------
class Extra:
    """What the domain machines add to a person: events (kind, age), spans, minutes and the survey reference days and years."""

    def __init__(self):
        self.events, self.spans, self.minutes, self.diary, self.occasions, self.occ_hits = [], {}, {}, [], [], []


def person_extra(D, seed, region, i, sx, own_events, end, noise):
    """Domain events of one person, alive until age `end` (death age, else the life horizon). `own_events` are the family and schooling events."""
    X = Extra()
    horizon = float(governed("eventgen.life_horizon_age"))
    end = min(end, horizon)
    marriage = next((a for k, a in own_events if k == "marriage"), None)
    divorce = next((a for k, a in own_events if k == "divorce"), None)
    _work(X, D["work"], pstream(seed, region, "work", i), sx, end, horizon)
    _health(X, D, pstream(seed, region, "health", i), sx, end)
    _annual(X, D, pstream(seed, region, "annual", i), sx, end)
    _diary(X, D, pstream(seed, region, "diary", i), sx, end, noise, _employed_intervals(X, end))
    _harm(X, D["harm"], pstream(seed, region, "harm", i), sx, end, marriage, divorce)
    _adopt(X, D, pstream(seed, region, "adopt", i), sx, end, own_events, marriage)
    X.events = [e for e in X.events if e[1] < end]
    return X


def _spell_end(X, kind, age, end_age, end):
    X.spans[(kind, age)] = min(end_age, end)


def _work(X, W, rng, sx, end, horizon):
    if W.get("lfp") is None:
        return
    lfp = W["lfp"][sx]
    minage = governed("eventgen.min_working_age")
    u = rng.random()
    usec, uself = rng.random(), rng.random()
    entry, retire = lfp_path(lfp, u, float(minage), float(governed("eventgen.retirement_min_age")))
    if entry is None or entry >= end:
        return
    stop = min(end, retire if retire is not None else horizon)
    farm, selfemp = usec < W["agri"], (usec >= W["agri"] and uself < W["self"])
    kind0 = "farm_work_start" if farm else "self_employment_start" if selfemp else ("industry_work_start" if rng.random() < W["industry_share"] else "service_work_start")
    wage = not (farm or selfemp)
    unemp_u, unemp_y = W["unemp"]["adult"], W["unemp"]["youth"]
    D_sp = W["spell_years"]
    U0 = unemp_y if entry < 25 and unemp_y is not None else unemp_u
    first_search, ufs = rng.random(), rng.random()
    if U0 is not None and first_search < U0:   # the labour market is entered at its stationary state: a share U starts with a spell of search
        te = entry + (-D_sp * math.log(max(ufs, 1e-12)))
        X.events.append(("job_search_start", entry))
        _spell_end(X, "job_search_start", entry, te, end)
        if te >= stop:
            return
        entry_job = te
    else:
        entry_job = entry
    X.events.append((kind0, entry_job))
    t = entry_job
    while t < stop:
        a = int(t)
        U = unemp_y if a < 25 and unemp_y is not None else unemp_u
        lam = (U / (1 - U) / D_sp) if U is not None and U < 0.95 else 0.0
        nj = W["new_job"]["15-24" if a < 25 else "15-64"]
        h = max(0.0, (nj - lam)) if nj is not None else governed("eventgen.job_change_default")
        if not wage:
            h = 0.0
        tot = lam + h
        if tot <= 0:
            t = float(a + 1)
            continue
        wait = -math.log(max(rng.random(), 1e-12)) / tot   # competing exponential risks within the year (memoryless: redrawn at each year boundary)
        pick, spell = rng.random(), rng.random()
        if t + wait >= a + 1:
            t = float(a + 1)
            continue
        t += wait
        if t >= stop:
            break
        if pick < lam / tot:
            X.events.append(("job_loss", t))
            te = t + (-D_sp * math.log(max(spell, 1e-12)))
            if te < stop:
                X.events.append(("reemployment", te))
                _spell_end(X, "job_loss", t, te, end)
                t = te
                continue
            _spell_end(X, "job_loss", t, stop, end)
            break
        X.events.append(("job_change", t))
    if retire is not None and retire < end:
        X.events.append(("retirement", retire))


def _threshold_onset(curve_, u, lo=None):
    """First single year of age whose prevalence exceeds the latent draw u (nested threshold), as the integer age; None if never."""
    for a in sorted(curve_):
        if curve_[a] > u:
            return a
    return None


def _health(X, D, rng, sx, end):
    H = D["health"]
    uv, ud, uh, ut, us, uj = (rng.random() for _ in range(6))
    ua, ub, uc = rng.random(), rng.random(), rng.random()
    if H["vacc"] is not None and uv < H["vacc"] and end > 2.0:
        X.events.append(("vaccination", 1.0 + 0.95 * ua))
    if H["diab_prev"] is not None:
        a = _threshold_onset(H["diab_prev"], ud)
        if a is not None:
            X.events.append(("chronic_condition_onset", a + ub))
    if H["hiv_prev"] is not None:
        a = _threshold_onset(H["hiv_prev"], uh)
        if a is not None:
            X.events.append(("hiv_diagnosis", a + uc))
    dcurve = H["disab"][sx] if H["disab"] is not None else None
    if dcurve is not None:
        a = _threshold_onset(dcurve, uj)
        if a is not None:
            X.events.append(("disability_onset", a + ua * ub))
    if H["tb"] is not None:
        t = 0.0
        while True:   # constant hazard from birth: exponential waiting times
            t += -math.log(max(rng.random(), 1e-12)) / H["tb"]
            if t >= end:
                break
            X.events.append(("infectious_illness", t))
            X.spans[("infectious_illness", t)] = min(end, t + 0.6)
            t += 0.6


def _annual(X, D, rng, sx, end):
    n = governed("eventgen.occasion_years")
    vote_age = governed("eventgen.voting_age")
    for _ in range(n):
        a = 16.0 + rng.random() * (governed("eventgen.life_horizon_age") - 17.0)   # year [a, a+1) inside the horizon
        draws = {k: (rng.random(), rng.random()) for k in list(ANNUAL) + ["voting", "religious_service"]}
        if a + 1 > end:
            continue
        X.occasions.append(a)
        for kind, c in D["annual"].items():
            if c is None:
                continue
            p = c if isinstance(c, float) else at(c[sx], a)
            if kind == "voting" and a < vote_age:
                continue
            if draws[kind][0] < p:
                X.events.append((kind, a + draws[kind][1]))
                X.occ_hits.append((kind, a))


def _employed_intervals(X, end):
    """[(start, stop)] of the person's spells in employment: from a first entry or a reemployment to the next job loss, retirement or the end of life."""
    out, start = [], None
    for k, a in sorted((e for e in X.events if e[0] in ENTRY + ("reemployment", "job_loss", "retirement")), key=lambda e: e[1]):
        if k in ENTRY or k == "reemployment":
            start = a
        elif start is not None:
            out.append((start, a))
            start = None
    if start is not None:
        out.append((start, end))
    return out


def p_employed(W, sx, a):
    """Share of the population in employment at age a: in the labour force and not unemployed."""
    if W.get("lfp") is None or a >= 70:
        return 0.0
    U = W["unemp"]["youth"] if a < 25 else W["unemp"]["adult"]
    return W["lfp"][sx][int(a)] * (1 - (U or 0.0))


def _diary(X, D, rng, sx, end, noise, employed=None):
    tu = D["tu"]
    if not tu:
        return
    sd = noise["time_use_minutes_sd"]
    horizon = float(governed("eventgen.life_horizon_age"))
    for _ in range(governed("eventgen.diary_days")):
        lo, hi, label = TU[int(rng.random() * len(TU))]
        a = lo + rng.random() * (min(hi, horizon) - lo)
        draws = [(rng.random(), rng.gauss(0, 1)) for _ in catalog.TIME]
        if a >= end:
            continue
        X.diary.append(a)
        W = D["work"]
        career = W.get("lfp") is not None
        in_job = any(s <= a < e for s, e in (employed or ()))
        worked = False
        for k, (u, z) in zip(catalog.TIME, draws):
            v = tu.get((k.key, sx, label))
            if v is None:
                continue
            p = v[0]
            if career and k.key in ("employment", "travel_work"):
                # the diary's employment is tied to the career: only a person in a job works, with the rate that keeps the population rate (p / share employed);
                # the journey to work follows a day at work, with its share of workdays
                pe = p_employed(W, sx, a)
                emp = tu.get(("employment", sx, label))
                if not in_job:
                    continue
                if k.key == "employment":
                    p = min(1.0, p / pe) if pe > 0 else 0.0
                else:
                    if not worked:
                        continue
                    p = min(1.0, p / emp[0]) if emp and emp[0] > 0 else 0.0
            if u >= p:
                continue
            worked = worked or k.key == "employment"
            X.events.append((k.key, a))
            X.minutes[(k.key, a)] = min(1440.0, v[1] * math.exp(sd * z - sd * sd / 2))   # a day has 1440 minutes


def _harm(X, Hm, rng, sx, end, marriage, divorce):
    lo, hi = EXPOSURE
    for kind, rate in Hm["victim"].items():
        if rate is None:
            continue
        r = rate
        if kind == "sexual_violence_victim":
            share = governed("eventgen.sexual_violence_female_share")
            r = rate * 2 * (share if sx == "f" else 1 - share)
        t = lo
        while True:
            t += -math.log(max(rng.random(), 1e-12)) / r if r > 0 else 1e9
            if t >= min(hi, end):
                break
            X.events.append((kind, t))
    if Hm["partner"] is not None and sx == "f" and marriage is not None:
        a0 = max(15.0, marriage)
        a1 = min(50.0, end, divorce if divorce is not None else 99.0)
        persist = governed("eventgen.partner_violence_persistence")
        q = min(1.0, Hm["partner"] / persist)   # share of unions that are violent; within one, each year carries violence with probability `persist`
        in_violent, ur = rng.random() < q, [rng.random() for _ in range(35)]
        if in_violent:
            for j, a in enumerate(range(int(a0), int(a1))):
                if ur[j % 35] < persist and a + 0.5 >= a0:
                    X.events.append(("partner_violence_victim", a + 0.5))
    lam = Hm["suspect"][sx]
    if lam is not None:
        ratio = Hm["conviction_ratio"][sx]
        a0 = float(governed("eventgen.min_offending_age"))
        for a in range(int(a0), int(min(hi, end))):
            w = Hm["offending_shape"].get(a, 0.0)
            u1, u2, u3, u4 = rng.random(), rng.random(), rng.random(), rng.random()
            if u1 < lam * w:
                t = a + u2
                X.events.append(("suspected_offence", t))
                if ratio is not None and u3 < ratio:
                    tc = t + max(0.1, -governed("eventgen.conviction_delay_years") * math.log(max(u4, 1e-12)))
                    if tc < end:
                        X.events.append(("conviction", tc))


def _trunc_normal_draw(rng, mean, sd, lo):
    for _ in range(50):
        x = rng.gauss(mean, sd)
        if x >= lo:
            return x
    return lo


def _adopt(X, D, rng, sx, end, own_events, marriage):
    """Adoption events (migration, account, phone, internet), contraception at marriage and vocational training at secondary entry."""
    for kind, spec in D["adopt"].items():
        u, ua = rng.random(), rng.random()
        if spec is None:
            continue
        share, mean, sd, lo = spec
        age = _trunc_normal_draw(random.Random(ua), mean, sd, lo)
        if u < share:
            X.events.append((kind, age))
    uc, uo, uv = rng.random(), rng.random(), rng.random()
    if D["contraception"] is not None and sx == "f" and marriage is not None and uc < D["contraception"]:
        X.events.append(("contraception_start", marriage + 3 * uo))
    sec = next((a for k, a in own_events if k == "secondary_start"), None)
    if D["vocational"] is not None and sec is not None and uv < D["vocational"]:
        X.events.append(("vocational_training_start", sec))
        X.spans[("vocational_training_start", sec)] = min(end, sec + 3.0)


# ---------------- statistics and targets (the domain head) ----------------
def band_of(a):
    for lo, hi, label in TU:
        if lo <= a < hi:
            return label
    return TU[-1][2]


def _end(p):
    return p.death if p.death is not None else p.death_late if p.death_late is not None else float(governed("eventgen.life_horizon_age"))


def statistics(world):
    """Generated statistics per (quantity, age band, sex, region) of the domain machines, in the units of `targets`."""
    out = {}
    horizon = float(governed("eventgen.life_horizon_age"))
    for r in world.regions:
        D = world.domains.get(r)
        if D is None:
            continue
        P = [p for p in world.people if p.region == r]
        _stats_time(out, P, r, D)
        _stats_work(out, P, r, D)
        _stats_annual(out, P, r, D)
        _stats_health_harm(out, P, r, D, horizon)
    return out


def _ratio(a, b, scale=1.0):
    return scale * a / b if b > 0 else float("nan")


def _stats_time(out, P, r, D):
    days, hits, mins, nmin, gdays, ghit, gmin = {}, {}, {}, {}, {}, {}, {}
    group_of = {k.key: k.group for k in catalog.TIME}
    for p in P:
        ev = [(k, a) for k, a in p.events if k in catalog.TIME_BY_KEY]
        by_day = {}
        for k, a in ev:
            by_day.setdefault(a, []).append(k)
        for a in p.diary:
            b = band_of(a)
            days[(p.sex, b)] = days.get((p.sex, b), 0) + 1
            gdays[(p.sex, INDIA_BAND[b])] = gdays.get((p.sex, INDIA_BAND[b]), 0) + 1
            gs = {}
            for k in by_day.get(a, ()):
                hits[(k, p.sex, b)] = hits.get((k, p.sex, b), 0) + 1
                m = p.minutes[(k, a)]
                mins[(k, p.sex)] = mins.get((k, p.sex), 0.0) + m
                nmin[(k, p.sex)] = nmin.get((k, p.sex), 0) + 1
                gs[group_of[k]] = gs.get(group_of[k], 0.0) + m
            for g, m in gs.items():
                key = (g, p.sex, INDIA_BAND[b])
                ghit[key] = ghit.get(key, 0) + 1
                gmin[key] = gmin.get(key, 0.0) + m
    kinds = {kk[0] for kk in D["tu"]}
    for k in kinds:
        for sx in "fm":
            for _, _, b in TU:
                out[(f"time.participation.{k}", b, sx, r)] = _ratio(hits.get((k, sx, b), 0), days.get((sx, b), 0), 100)
            out[(f"time.participation.{k}", "all", sx, r)] = _ratio(sum(hits.get((k, sx, b), 0) for _, _, b in TU), sum(days.get((sx, b), 0) for _, _, b in TU), 100)
            out[(f"time.minutes.{k}", "all", sx, r)] = _ratio(mins.get((k, sx), 0.0), nmin.get((k, sx), 0))
    for (g, sx, ib) in D["groups"]:
        out[(f"time.group.participation.{g}", ib, sx, r)] = _ratio(ghit.get((g, sx, ib), 0), gdays.get((sx, ib), 0), 100)
        out[(f"time.group.minutes.{g}", ib, sx, r)] = _ratio(gmin.get((g, sx, ib), 0.0), ghit.get((g, sx, ib), 0))


def _stats_work(out, P, r, D):
    W = D["work"]
    if W.get("lfp") is None:
        return
    lf = {(b, sx): [0.0, 0.0] for b in BAND_EDGES for sx in "fm"}
    un = {"adult": [0.0, 0.0], "youth": [0.0, 0.0]}
    for p in P:
        end = _end(p)
        entry = min((a for k, a in p.events if k in LF_ENTRY), default=None)
        retire = next((a for k, a in p.events if k == "retirement"), None)
        for b, (lo, hi) in BAND_EDGES.items():
            n = max(0.0, min(end, hi) - lo)
            lf[(b, p.sex)][1] += n
            if entry is not None:
                stop = min(end, retire if retire is not None else 1e9)
                lf[(b, p.sex)][0] += max(0.0, min(stop, hi) - max(entry, lo))
        if entry is None:
            continue
        stop = min(end, retire if retire is not None else 1e9)
        for lo, hi, key in ((15, 25, "youth"), (15, 71, "adult")):
            un[key][1] += max(0.0, min(stop, hi) - max(entry, lo))
            for k, a in p.events:
                if k in ("job_loss", "job_search_start"):
                    e = min(p.spans.get((k, a), a), stop)
                    un[key][0] += max(0.0, min(e, hi) - max(a, lo))
    for (b, sx), (n, d) in lf.items():
        out[("work.labour_force_participation", b, sx, r)] = _ratio(n, d, 100)
    out[("work.youth_unemployment", "15-24", "all", r)] = _ratio(*un["youth"], 100)
    out[("work.unemployment", "15+", "all", r)] = _ratio(*un["adult"], 100)


def _stats_annual(out, P, r, D):
    yrs, hits = {}, {}
    for p in P:
        for a in p.occasions:
            for label, lo, hi in BANDS_H:
                if lo <= a < hi:
                    yrs[(label, p.sex)] = yrs.get((label, p.sex), 0) + 1
                    break
            if a >= governed("eventgen.voting_age"):
                yrs[("vote", "all")] = yrs.get(("vote", "all"), 0) + 1
        for kind, a in p.occ_hits:
            if kind == "voting":
                hits[("vote", "all")] = hits.get(("vote", "all"), 0) + 1
                continue
            for label, lo, hi in BANDS_H:
                if lo <= a < hi:
                    hits[(kind, label, p.sex)] = hits.get((kind, label, p.sex), 0) + 1
                    break
    for kind, c in D["annual"].items():
        if c is None or kind == "religious_service":
            continue
        if kind == "voting":
            out[("civic.voter_turnout_year", "all", "all", r)] = _ratio(hits.get(("vote", "all"), 0), yrs.get(("vote", "all"), 0), 100)
            continue
        for sx in "fm":
            tot_y = sum(v for (l, s2), v in yrs.items() if s2 == sx and l != "vote")
            out[(ANNUAL[kind], "all", sx, r)] = _ratio(sum(v for key, v in hits.items() if len(key) == 3 and key[0] == kind and key[2] == sx), tot_y, 100)
            for label, lo, hi in BANDS_H:
                if (label, sx) in yrs:
                    out[(ANNUAL[kind], label, sx, r)] = _ratio(hits.get((kind, label, sx), 0), yrs[(label, sx)], 100)


def _stats_health_harm(out, P, r, D, horizon):
    H, Hm = D["health"], D["harm"]
    alive2 = [p for p in P if _end(p) > 2.0]
    if H["vacc"] is not None and alive2:
        out[("health.measles_immunisation", "12-23 months", "all", r)] = 100 * sum(any(k == "vaccination" for k, _ in p.events) for p in alive2) / len(alive2)
    if H["disab"] is not None:
        for label, lo, hi in BANDS_H[:6]:
            m = min(69, (lo + hi) // 2)
            for sx in "fm":
                Q = [p for p in P if p.sex == sx and _end(p) >= m + 1]
                if Q:
                    out[("health.disability_prevalence", label, sx, r)] = 100 * sum(any(k == "disability_onset" and a < m + 1 for k, a in p.events) for p in Q) / len(Q)
    if H["hiv_prev"] is not None:
        inf, yrs = 0.0, 0.0
        for p in P:
            e = min(_end(p), 50.0)
            yrs += max(0.0, e - 15)
            o = next((a for k, a in p.events if k == "hiv_diagnosis"), None)
            if o is not None:
                inf += max(0.0, e - max(o, 15.0))
        out[("health.hiv_prevalence", "15-49", "all", r)] = _ratio(inf, yrs, 100)
    if H["tb"] is not None:
        n = sum(k == "infectious_illness" for p in P for k, _ in p.events)
        out[("health.tb_incidence", "all", "all", r)] = _ratio(n, sum(_end(p) for p in P), 1e5)
    lo, hi = EXPOSURE
    expo = sum(max(0.0, min(_end(p), hi) - lo) for p in P)
    for kind, rate in Hm["victim"].items():
        if rate is not None:
            n = sum(k == kind for p in P for k, _ in p.events)
            out[(VICTIM[kind], "all", "all", r)] = _ratio(n, expo, 1e5)
    if Hm["partner"] is not None:
        yrs = n = 0.0
        for p in P:
            if p.sex != "f":
                continue
            m = next((a for k, a in p.events if k == "marriage"), None)
            if m is None:
                continue
            d = next((a for k, a in p.events if k == "divorce"), 99.0)
            yrs += max(0.0, min(50.0, _end(p), d) - max(15.0, m))
            n += sum(k == "partner_violence_victim" for k, _ in p.events)
        out[("harm.partner_violence_12m", "15-49", "f", r)] = _ratio(n, yrs, 100)
    olo = float(governed("eventgen.min_offending_age"))
    for sx in "fm":
        Q = [p for p in P if p.sex == sx]
        yrs = sum(max(0.0, min(_end(p), hi) - olo) for p in Q)
        if Hm["suspect"][sx] is not None:
            out[("harm.suspect_rate", "all", sx, r)] = _ratio(sum(k == "suspected_offence" for p in Q for k, _ in p.events), yrs, 1e5)
        if Hm["conviction_ratio"][sx] is not None:
            out[("harm.conviction_rate", "all", sx, r)] = _ratio(sum(k == "conviction" for p in Q for k, _ in p.events), yrs, 1e5)
    for kind, spec in D["adopt"].items():
        if spec is None:
            continue
        Q = [p for p in P if _end(p) >= 50]
        if Q:
            out[(f"adopt.{kind}", "by50", "all", r)] = 100 * sum(any(k == kind and a < 50 for k, a in p.events) for p in Q) / len(Q)
    if D["contraception"] is not None:
        W = [p for p in P if p.sex == "f" and any(k == "marriage" for k, _ in p.events)]
        if W:
            out[("family.contraceptive_prevalence", "15-49", "f", r)] = 100 * sum(any(k == "contraception_start" for k, _ in p.events) for p in W) / len(W)
    if D["vocational"] is not None:
        S = [p for p in P if any(k == "secondary_start" for k, _ in p.events)]
        if S:
            out[("education.vocational_share_secondary", "secondary", "all", r)] = 100 * sum(any(k == "vocational_training_start" for k, _ in p.events) for p in S) / len(S)


def _conf(table, quantity, region, regions):
    ix = _idx(table)
    for r in [region, regions.get(region), "WLD"]:
        if r and (quantity, r) in ix:
            return ix[(quantity, r)][0].confidence
    return "medium"


def targets(table, regions, region_map):
    """{(quantity, band, sex, region): (target, confidence, False)} for the statistics of `statistics`, derived by the same `derive` the generator uses
    (cross-region substitutes and group rescalings included, as the generator was meant to follow them)."""
    from .world import derive_setup
    from statistics import NormalDist
    out = {}
    for r in regions:
        S = derive_setup(table, r, region_map)
        D = derive(table, r, region_map, S)
        conf = lambda q: _conf(table, q, r, region_map)   # noqa: E731
        for k in {kk[0] for kk in D["tu"]}:
            for sx in "fm":
                ps = [D["tu"][(k, sx, b)] for _, _, b in TU if (k, sx, b) in D["tu"]]
                eff = {}
                for lo, hi, b in TU:
                    if (k, sx, b) in D["tu"]:
                        p = D["tu"][(k, sx, b)][0]
                        if k == "employment":
                            p = eff_employment(D["work"], sx, lo, hi, p)
                        elif k == "travel_work" and ("employment", sx, b) in D["tu"]:
                            pe = D["tu"][("employment", sx, b)][0]
                            p = eff_employment(D["work"], sx, lo, hi, pe) * (min(1.0, p / pe) if pe > 0 else 0.0)
                        eff[b] = p
                        if p >= JUDGE_MIN_SHARE:
                            out[(f"time.participation.{k}", b, sx, r)] = (100 * p, conf(f"time.participation.{k}"), False)
                if eff:
                    out[(f"time.participation.{k}", "all", sx, r)] = (100 * sum(eff.values()) / len(eff), conf(f"time.participation.{k}"), False)
                num = sum(x[0] * x[1] for x in ps)
                den = sum(x[0] for x in ps)
                if den > 0:
                    out[(f"time.minutes.{k}", "all", sx, r)] = (num / den, conf(f"time.minutes.{k}"), False)
        for (g, sx, ib), v in D["groups"].items():
            p = v["p"]
            if g == "employment":
                hbs = [(lo, hi) for lo, hi, b in TU if INDIA_BAND[b] == ib]
                p = sum(eff_employment(D["work"], sx, lo, hi, v["p"]) for lo, hi in hbs) / len(hbs)
            out[(f"time.group.participation.{g}", ib, sx, r)] = (100 * p, conf(f"time.group.participation.{g}"), False)
            if "m" in v:
                out[(f"time.group.minutes.{g}", ib, sx, r)] = (v["m"], conf(f"time.group.minutes.{g}"), False)
        W = D["work"]
        if W.get("lfp_nodes"):
            for sx in "fm":
                for b, v in W["lfp_nodes"][sx].items():
                    out[("work.labour_force_participation", b, sx, r)] = (100 * v, conf("work.labour_force_participation"), False)
        if W["unemp"]["youth"] is not None and W.get("lfp"):
            out[("work.youth_unemployment", "15-24", "all", r)] = (100 * W["unemp"]["youth"], conf("work.youth_unemployment"), False)
            if W["unemp"]["adult"] is not None:
                u_all = value(table, "work.unemployment", r, f"head:{r}", region_map, "15+")
                out[("work.unemployment", "15+", "all", r)] = (u_all, conf("work.unemployment"), False)
        for kind, c in D["annual"].items():
            if c is None or kind == "religious_service":
                continue
            if kind == "voting":
                out[("civic.voter_turnout_year", "all", "all", r)] = (100 * c, conf("civic.voter_turnout"), False)
                continue
            for sx in "fm":
                ws = {l: max(0, min(hi, ANNUAL_TOP) - max(lo, ANNUAL_LO)) for l, lo, hi in BANDS_H}
                tot = sum(ws.values())
                pooled = 0.0
                for label, lo, hi in BANDS_H:
                    if ws[label] <= 0:
                        continue
                    v = at(c[sx], (max(lo, ANNUAL_LO) + min(hi, ANNUAL_TOP)) / 2)   # a band the source lacks takes the nearest band's value, as the generator does
                    pooled += v * ws[label] / tot
                    if any(lo == a for a, b, _ in c[sx]) and v >= JUDGE_MIN_SHARE * 2:
                        out[(ANNUAL[kind], label, sx, r)] = (100 * v, conf(ANNUAL[kind]), False)
                out[(ANNUAL[kind], "all", sx, r)] = (100 * pooled, conf(ANNUAL[kind]), False)
        H, Hm = D["health"], D["harm"]
        if H["vacc"] is not None:
            out[("health.measles_immunisation", "12-23 months", "all", r)] = (100 * H["vacc"], conf("health.measles_immunisation"), False)
        if H["disab"] is not None:
            for label, lo, hi in BANDS_H[:6]:
                m = min(69, (lo + hi) // 2)
                for sx in "fm":
                    out[("health.disability_prevalence", label, sx, r)] = (100 * H["disab"][sx][m], conf("health.disability_prevalence"), False)
        if H["hiv_prev"] is not None:
            out[("health.hiv_prevalence", "15-49", "all", r)] = (100 * H["hiv"], conf("health.hiv_prevalence"), False)
        if H["tb"] is not None:
            out[("health.tb_incidence", "all", "all", r)] = (1e5 * H["tb"], conf("health.tb_incidence"), False)
        for kind, rate in Hm["victim"].items():
            if rate is not None:
                out[(VICTIM[kind], "all", "all", r)] = (1e5 * rate, conf(VICTIM[kind]), False)
        if Hm["partner"] is not None:
            out[("harm.partner_violence_12m", "15-49", "f", r)] = (100 * Hm["partner"], conf("harm.partner_violence_12m"), False)
        for sx in "fm":
            if Hm["suspect"][sx] is not None:
                out[("harm.suspect_rate", "all", sx, r)] = (1e5 * Hm["suspect"][sx], conf("harm.suspect_rate"), False)
            if Hm["conviction_ratio"][sx] is not None:
                out[("harm.conviction_rate", "all", sx, r)] = (1e5 * Hm["conviction_ratio"][sx] * Hm["suspect"][sx], conf("harm.conviction_rate"), False)
        for kind, spec in D["adopt"].items():
            if spec is not None:
                share, mean, sd, lo = spec
                nd = NormalDist(mean, sd)
                f = lambda x: (nd.cdf(x) - nd.cdf(lo)) / (1 - nd.cdf(lo))   # noqa: E731
                out[(f"adopt.{kind}", "by50", "all", r)] = (100 * share * f(50.0), conf(ADOPT[kind][0]), False)
        if D["contraception"] is not None:
            out[("family.contraceptive_prevalence", "15-49", "f", r)] = (100 * D["contraception"], conf("family.contraceptive_prevalence"), False)
        if D["vocational"] is not None:
            out[("education.vocational_share_secondary", "secondary", "all", r)] = (100 * D["vocational"], conf("education.vocational_share_secondary"), False)
    return out
