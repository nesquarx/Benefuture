"""Probe world: family formation and schooling for a few hundred synthetic people across regions, driven only by the calibration table.

Per person: birth -> (preschool) -> primary entry -> primary completion or dropout -> secondary -> lower-secondary completion
or dropout -> tertiary entry -> completion or dropout; first marriage; for women, births by age band. Every gate is a
conditional probability derived from the table's cohort shares (`derive_setup`, shared with the rate head so the head's target
is what the generator was meant to follow). Cohort shares are nested (each level cannot exceed the one before): where the
table's values are incoherent (over-age pupils push completion above 100%) the share is clipped and a loud `degraded`
entry records it. Missing strata degrade country -> region -> world (`Table.lookup`).

Each mechanism draws from its own random stream per (seed, region, mechanism) and the same number of draws per person whether
or not the gate opens, so changing one mechanism's parameter moves only that mechanism and arms of an experiment share seeds.
Increment 2 adds: deaths (piecewise-constant hazards from the infant, under-five and 40q0 mortality Params, a Gompertz rise
after 40; own stream), a spouse entity at marriage (age gap from the male-female difference of the marriage-age Params), divorce
(share of marriages from the divorce Param, else a governed default logged as degraded), births that depend on marital state
(married hazard h = ASFR / (M(a) + r (1 - M(a))), unmarried r h, so the marginal ASFR is preserved) and fatherhood (a married
man fathers the births of his spouse at her age). The sequence head (`sequence.py`) judges the order these produce.
Not modelled (named toy assumptions): spouse death and remarriage, children as people, upper-secondary completion, migration,
cohort change (period rates of one year are applied to every age), widowhood, men's births outside marriage.
"""
import dataclasses
import datetime as dt
import math
from collections import defaultdict
from statistics import NormalDist

from ..generators.common import stream
from ..governed import governed
from . import domains as _domains
from . import events as ev
from . import marriage as mm
from .calibration import load_regions

BIRTH_DATE = dt.date(1973, 7, 1)
BANDS = ("15-19", "20-24", "25-29", "30-34", "35-39", "40-44", "45-49")
PRIMARY_AGE, LAST_GRADE_AGE = "primary age", "last-grade age"
_N = NormalDist()


def noise_defaults():
    return {k: governed(f"noise.{k}") for k in ("fertility_frailty_sd", "marriage_age_sd", "school_entry_delay_p", "nonmarital_birth_relative_hazard",
                                                 "spouse_age_gap_sd", "time_use_minutes_sd",
                                                 "registration_lag_civil_days", "registration_lag_other_days", "registration_lag_sigma", "marriage_early_mean",
                                                 "marriage_early_sd")}


def _stream(seed, region, mechanism):
    return stream(seed, f"eventgen|{region}|{mechanism}")


def trunc_normal_mu(mean, sd, lo):
    """Location mu such that a normal(mu, sd) truncated below at lo has the given mean (bisection; mean > lo)."""
    def tm(mu):
        a = (lo - mu) / sd
        return mu + sd * _N.pdf(a) / (1 - _N.cdf(a))
    a, b = mean - 10 * sd, mean
    for _ in range(80):
        m = (a + b) / 2
        a, b = (m, b) if tm(m) < mean else (a, m)
    return (a + b) / 2


def own_param(table, quantity, band, sex, region, regions):
    """The Param of the region's own stratum (the country or its World Bank region), else None; no substitution, nothing recorded."""
    for r in (region, regions.get(region)):
        if r:
            for sx in dict.fromkeys((sex, "all")):
                p = table.get(quantity, band, sx, r)
                if p is not None:
                    return p
    return None


def derive_setup(table, region, regions):
    """The generator's inputs for a region from the table: ASFR by band, sex ratio at birth, marriage ages, and nested cohort shares per sex."""
    step = f"setup:{region}"
    look = lambda q, band, sex="all": table.lookup(q, band, sex, region, regions, step)  # noqa: E731
    val = lambda p, d=None: (p.value if p is not None else d)  # noqa: E731
    s = {"region": region, "params": {}, "clipped": []}
    s["asfr"] = {b: val(look("fertility.asfr", b, "f"), 0.0) for b in BANDS}
    s["srb"] = val(look("fertility.sex_ratio_at_birth", "0"), 105.0)
    s["smam"] = {sx: val(look("family.age_first_marriage", "all", sx), 27.0) for sx in "fm"}
    s["pre"] = min(1.0, val(look("education.preprimary_gross_enrolment", "3-5"), 0.0) / 100)
    s["entry_age"] = round(val(look("education.primary_entry_age", "all"), 6.0))
    s["prim_dur"] = round(val(look("education.primary_duration", "all"), 6.0))
    s["sec_dur"] = round(val(look("education.secondary_duration", "all"), 6.0))
    prog = min(1.0, val(look("education.progression_to_secondary", "all"), 100.0) / 100)
    lsc = val(look("education.lower_secondary_completion", LAST_GRADE_AGE), 0.0) / 100
    ter = val(look("education.tertiary_gross_enrolment", "5 years after secondary"), 0.0) / 100
    ba = val(look("education.tertiary_bachelor_attainment", "25+"), 0.0) / 100
    s["shares"] = {}
    for sx in "fm":
        raw = [min(1.0, val(look("education.primary_net_enrolment", PRIMARY_AGE, sx), 0.0) / 100),
               val(look("education.primary_completion", LAST_GRADE_AGE, sx), 0.0) / 100, None, lsc, ter, ba]
        names = ["primary_entry", "primary_completion", "secondary_entry", "lower_secondary_completion", "tertiary_entry", "tertiary_completion"]
        eff = []
        for i, (n, r) in enumerate(zip(names, raw)):
            if i == 2:
                r = eff[1] * prog
            bound = eff[-1] if eff else 1.0
            e = min(r, bound)
            if r > bound + 0.005 and i != 0:
                s["clipped"].append({"share": n, "sex": sx, "raw": r, "effective": e})
                table.degrade(step, f"education.{n}", region, "preceding level's share", f"raw share {r:.3f} exceeds the level before it ({bound:.3f}); nested shares must not rise")
            eff.append(e)
        s["shares"][sx] = dict(zip(names, eff))
    s["mort"] = {}
    im = val(look("mortality.infant", "all"), 30.0) / 1000
    u5 = max(im, val(look("mortality.under5", "all"), 40.0) / 1000)
    for sx in "fm":
        q40 = val(look("mortality.prob_death_0_40", "0-40", sx), 100.0) / 1000
        s["mort"][sx] = mortality_hazards(im, u5, q40, table, step, region)
    d = look("family.divorces_per_100_marriages", "all")
    if d is None:
        table.degrade(step, "family.divorces_per_100_marriages", region, f"governed default {governed('eventgen.divorce_share_default')}", "no divorce Param at any level")
    s["divorce_share"] = min(0.9, d.value / 100) if d is not None else governed("eventgen.divorce_share_default")
    b18 = own_param(table, "family.married_by_18", "20-24", "f", region, regions)
    s["married_by_18"] = b18.value / 100 if b18 is not None else None
    bom = own_param(table, "family.births_outside_marriage", "all", "f", region, regions)
    s["births_outside"] = bom.value / 100 if bom is not None else None
    return s


def solve_nonmarital_hazard(S, married_share, target):
    """The relative birth hazard r of unmarried women (births outside marriage / births) such that the share of births outside marriage is `target`:
    sum_a asfr_a (1-M_a) r / (M_a + r (1-M_a)) over sum_a asfr_a is increasing in r (bisection on [0.001, 1]; a target beyond r = 1, births ignoring marriage,
    gives r = 1)."""
    ages = range(15, 50)
    asfr = {a: S["asfr"][BANDS[(a - 15) // 5]] for a in ages}
    M = {a: married_share(a + 0.5, "f") for a in ages}
    tot = sum(asfr.values())

    def share(r):
        return sum(asfr[a] * (1 - M[a]) * r / (M[a] + r * (1 - M[a])) for a in ages) / tot if tot else 0.0
    if target >= share(1.0):
        return 1.0
    lo, hi = 0.001, 1.0
    for _ in range(50):
        m = (lo + hi) / 2
        lo, hi = (m, hi) if share(m) < target else (lo, m)
    return (lo + hi) / 2


def mortality_hazards(im, u5, q40, table, step, region):
    """Piecewise-constant hazards [0,1), [1,5), [5,40) from infant, under-five and 40q0 survival (a 40q0 not above the under-five
    mortality is incoherent: the 5-40 hazard falls to a floor and the effective 40q0 is recorded), and the effective 40q0."""
    S1, S5, S40 = 1 - im, 1 - u5, 1 - q40
    h0 = -math.log(S1)
    h1 = -math.log(S5 / S1) / 4 if S5 < S1 else 0.0
    if S40 < S5:
        h2 = -math.log(S40 / S5) / 35
    else:
        h2 = 1e-5
        table.degrade(step, "mortality.prob_death_0_40", region, "floor hazard", f"40q0 {q40:.3f} is not above under-five mortality {u5:.3f}")
    return {"h": (h0, h1, h2), "q40": q40 if S40 < S5 else 1 - S5 * math.exp(-35 * h2)}


def death_age(h, u, slope, horizon):
    """Age at death for survival draw u in (0,1) under the hazards of `mortality_hazards`; None when beyond the horizon."""
    h0, h1, h2 = h
    e = -math.log(max(u, 1e-12))
    if e < h0:
        return e / h0
    e -= h0
    if h1 > 0 and e < 4 * h1:
        return 1 + e / h1
    e -= 4 * h1
    if e < 35 * h2:
        return 5 + e / h2
    e -= 35 * h2
    a = 40 + math.log(e * slope / h2 + 1) / slope
    return a if a <= horizon else None


def misspecify(table, quantity, factor):
    """A copy of the table with `quantity` scaled by `factor` in every stratum (a deliberately wrong Param for counterexamples)."""
    from .calibration import Table
    return Table([dataclasses.replace(p, value=p.value * factor) if p.quantity == quantity else p for p in table.params])


@dataclasses.dataclass
class Person:
    pid: str
    region: str
    sex: str
    events: list  # [(key, age)]
    death: float = None   # age at death; None when alive at the family horizon (50); a later death is a "death" event with `death_late`
    spouse: dict = None   # {"gap": years the spouse is older (+) or younger (-) than the person}
    death_late: float = None   # age at death between the family horizon and the life horizon
    spans: dict = dataclasses.field(default_factory=dict)      # {(kind, age): end age} of events that last
    minutes: dict = dataclasses.field(default_factory=dict)    # {(kind, age): minutes} of time-use events
    diary: list = dataclasses.field(default_factory=list)      # ages of the diary days
    occasions: list = dataclasses.field(default_factory=list)  # start ages of the survey reference years
    occ_hits: list = dataclasses.field(default_factory=list)   # (kind, reference-year start age) of annual-participation events


class World:
    def __init__(self, table, regions=("KEN", "IND", "FRA"), n_per_region=170, seed=1, noise=None, region_map=None, domains=True):
        self.table, self.seed, self.regions = table, seed, tuple(regions)
        self.noise = {**noise_defaults(), **(noise or {})}
        self._explicit = frozenset(noise or {})
        self.region_map = region_map if region_map is not None else load_regions()
        self.setups = {r: derive_setup(table, r, self.region_map) for r in self.regions}
        self.domains = {r: _domains.derive(table, r, self.region_map, self.setups[r]) for r in self.regions} if domains else {}
        self.people = [p for r in self.regions for p in self._region(r, n_per_region)]

    @property
    def degraded(self):
        return self.table.degraded

    def _region(self, region, n):
        S, nz, seed = self.setups[region], self.noise, self.seed
        R = {m: _stream(seed, region, m) for m in ("sex", "preschool", "entry", "delay", "pc", "prog", "lsc", "ter", "ba", "drop", "ever", "marriage_age",
                                                    "fertility", "frailty", "death", "divorce", "spouse", "male_fertility")}
        horizon, L, TY = governed("eventgen.horizon_age"), governed("eventgen.lower_secondary_years"), governed("eventgen.tertiary_years")
        slope, preg = governed("eventgen.mortality_gompertz_slope"), governed("eventgen.pregnancy_years")
        r, sdm, ever_share = nz["nonmarital_birth_relative_hazard"], nz["marriage_age_sd"], governed("eventgen.partnership_ever_share")
        cutoff = float(governed("eventgen.minor_age"))
        MM = {sx: mm.model(S["smam"][sx], sdm, (S["married_by_18"] / ever_share if sx == "f" and S["married_by_18"] is not None else None),
                           nz["marriage_early_mean"], nz["marriage_early_sd"], cutoff) for sx in "fm"}
        if S["married_by_18"] is None:
            self.table.degrade(f"setup:{region}", "family.married_by_18", region, "single normal marriage-age distribution", "no married-by-18 Param of the region's own stratum")
        gap_mean = S["smam"]["m"] - S["smam"]["f"]

        def married_share(x, sx):  # probability a person of sex sx is ever-married by age x (the marriage-age distribution is that of the person's own sex)
            return 0.0 if x < 15 else ever_share * MM[sx].cdf(x)

        r_calibrated = False
        if S["births_outside"] is not None and "nonmarital_birth_relative_hazard" not in self._explicit:
            r, r_calibrated = solve_nonmarital_hazard(S, married_share, S["births_outside"]), True
        S["r"], S["r_calibrated"], S["marriage_model"] = r, r_calibrated, MM

        def birth_hazards(a, sx_mother="f"):
            """(married, unmarried) annual birth probability for a woman in year-age a (marginal ASFR preserved), with the hazard cap recorded."""
            asfr = S["asfr"][BANDS[(a - 15) // 5]] / 1000
            m = married_share(a + 0.5, sx_mother)
            hm = asfr / (m + r * (1 - m))
            if hm > 0.95:
                self.table.degrade(f"setup:{region}", "fertility.asfr", region, "hazard cap 0.95", f"married-state birth hazard {hm:.2f} at age {a} exceeds one year's probability")
            return min(0.95, hm), min(0.95, r * hm)

        BH = {a: birth_hazards(a) for a in range(15, 50)}
        dom = self.domains.get(region)
        out = []
        for i in range(n):
            sx = "m" if R["sex"].random() < S["srb"] / (100 + S["srb"]) else "f"
            sh = S["shares"][sx]
            u = {k: R[k].random() for k in ("preschool", "entry", "delay", "pc", "prog", "lsc", "ter", "ba")}
            ud = [R["drop"].random() for _ in range(3)]
            ever, um = R["ever"].random(), R["marriage_age"].random()
            udeath = R["death"].random()
            udiv, udur = R["divorce"].random(), R["divorce"].random()
            ugap = R["spouse"].gauss(0, 1)
            ev_ = [("born", 0.0)]
            ea = S["entry_age"] + (1 if u["delay"] < nz["school_entry_delay_p"] else 0)
            if u["preschool"] < S["pre"]:
                ev_.append(("preschool", float(max(3, S["entry_age"] - 3))))
            if u["entry"] < sh["primary_entry"]:
                ev_.append(("school_start", float(ea)))
                pe = ea + S["prim_dur"]
                p_pc = sh["primary_completion"] / sh["primary_entry"]
                if u["pc"] < p_pc:
                    ev_.append(("primary_complete", float(pe)))
                    p_pr = sh["secondary_entry"] / sh["primary_completion"] if sh["primary_completion"] else 0.0
                    if u["prog"] < p_pr:
                        ev_.append(("secondary_start", float(pe)))
                        p_l = sh["lower_secondary_completion"] / sh["secondary_entry"] if sh["secondary_entry"] else 0.0
                        if u["lsc"] < p_l:
                            ev_.append(("secondary_complete", float(pe + L)))
                            p_t = sh["tertiary_entry"] / sh["lower_secondary_completion"] if sh["lower_secondary_completion"] else 0.0
                            ts = pe + max(S["sec_dur"], L)
                            if u["ter"] < p_t:
                                ev_.append(("tertiary_start", float(ts)))
                                p_b = sh["tertiary_completion"] / sh["tertiary_entry"] if sh["tertiary_entry"] else 0.0
                                if u["ba"] < p_b:
                                    ev_.append(("tertiary_complete", float(ts + TY)))
                                else:
                                    ev_.append(("school_dropout", float(ts + 1 + int(ud[2] * (TY - 1)))))
                        else:
                            ev_.append(("school_dropout", float(pe + 1 + int(ud[1] * (L - 1)))))
                else:
                    ev_.append(("school_dropout", float(ea + 1 + int(ud[0] * (S["prim_dur"] - 1)))))
            marriage = div = None
            if ever < ever_share:
                marriage = MM[sx].ppf(um)
                ev_.append(("marriage", marriage))
                if udiv < S["divorce_share"]:
                    div = marriage + max(0.5, -governed("eventgen.divorce_mean_duration") * math.log(max(udur, 1e-12)))
                    ev_.append(("divorce", div))
            spouse = {"gap": (gap_mean + nz["spouse_age_gap_sd"] * ugap) * (1 if sx == "f" else -1)} if marriage is not None else None
            if sx == "f":
                fr = math.exp(nz["fertility_frailty_sd"] * R["frailty"].gauss(0, 1) - nz["fertility_frailty_sd"] ** 2 / 2)
                for age in range(15, 50):
                    d = R["fertility"].random()
                    hm, hu = BH[age]
                    p = (hm if marriage is not None and marriage < age + 0.5 else hu) * fr
                    if d < min(0.95, p):
                        ev_.append(("birth_of_child", age + 0.75 + 0.25 * R["fertility"].random()))
            else:
                fr = math.exp(nz["fertility_frailty_sd"] * R["male_fertility"].gauss(0, 1) - nz["fertility_frailty_sd"] ** 2 / 2)
                for age in range(15, 50):
                    d, ub = R["male_fertility"].random(), R["male_fertility"].random()
                    if marriage is None or marriage >= age + 0.5 or (div is not None and div <= age + 0.5):
                        continue
                    sa = int(age + 0.5 - spouse["gap"])  # the spouse's age in this year
                    if 15 <= sa < 50 and d < min(0.95, BH[sa][0] * fr):
                        ev_.append(("fatherhood", age + 0.75 + 0.25 * ub))
            dead = death_age(S["mort"][sx]["h"], udeath, slope, horizon)
            kept = [e for e in ev_ if e[1] <= horizon and (dead is None or e[1] < dead)]
            if dead is not None:
                kept.append(("death", dead))
            dead_late = None
            person = Person(f"{region}-{i:04d}", region, sx, kept, dead, spouse if any(k == "marriage" for k, _ in kept) else None)
            if dom is not None:
                life = governed("eventgen.life_horizon_age")
                dead_late = death_age(S["mort"][sx]["h"], udeath, slope, life) if dead is None else None
                X = _domains.person_extra(dom, seed, region, i, sx, kept, dead if dead is not None else (dead_late if dead_late is not None else float(life)), nz)
                person.events = kept + X.events
                person.spans, person.minutes, person.diary, person.occasions, person.occ_hits = X.spans, X.minutes, X.diary, X.occasions, X.occ_hits
                if dead_late is not None:
                    person.events.append(("death", dead_late))
                    person.death_late = dead_late
            out.append(person)
        return out

    def rows(self):
        """Library-format rows of every event (validated); one per event (the subject's row; `events()` carries every participant's)."""
        out = []
        for p in self.people:
            for n, (key, age) in enumerate(p.events):
                out.append(ev.make_row(f"person:{p.pid}", p.region, key, BIRTH_DATE, age, f"ev:{p.pid}-{n:02d}"))
        return out

    def events(self, light=False):
        """Relational events (LI.65) of every person: {pid: [event, ...]}; see `relational.py`. Degradations go to `relational_degraded`.
        `light` skips the participant records and rows (the sequence head reads only times, kinds, spans and links)."""
        from . import relational
        self.relational_degraded = []
        return {p.pid: relational.person_events(self, p, light) for p in self.people}

    def entities(self):
        """Every entity the events name, in the library's entity form ({id, kind})."""
        from . import relational
        return relational.entities(self.events())

    def statistics(self):
        """Generated statistics per (quantity, age_band, sex, region), in the units of `rates.UNITS`.
        Shares, marriage age and the sex ratio are taken among people alive at the horizon (death is independent of everything else
        here, so survivors are an unbiased sample of the life course), births per woman-year lived in the band, mortality over everyone."""
        horizon = governed("eventgen.horizon_age")
        out = {}
        for r in self.regions:
            P = [p for p in self.people if p.region == r]
            wm = [p for p in P if p.sex == "f"]
            births = defaultdict(int)
            years = defaultdict(float)
            for p in wm:
                end = min(horizon, p.death if p.death is not None else horizon)
                for k, a in p.events:
                    if k == "birth_of_child":
                        births[BANDS[int(a - 15) // 5]] += 1
                for j, b in enumerate(BANDS):
                    lo = 15 + 5 * j
                    years[b] += max(0.0, min(end, lo + 5) - lo)
            for b in BANDS:
                out[("fertility.asfr", b, "f", r)] = 1000 * births[b] / years[b] if years[b] else float("nan")
            out[("fertility.tfr", "15-49", "f", r)] = 5 * sum(out[("fertility.asfr", b, "f", r)] for b in BANDS) / 1000
            out[("fertility.sex_ratio_at_birth", "0", "all", r)] = 100 * sum(p.sex == "m" for p in P) / max(1, sum(p.sex == "f" for p in P))
            for sx in "fm":
                Q = [p for p in P if p.sex == sx]
                out[("mortality.prob_death_0_40", "0-40", sx, r)] = 1000 * sum(p.death is not None and p.death < 40 for p in Q) / len(Q) if Q else float("nan")
                Q = [p for p in Q if p.death is None]
                n = len(Q) or float("nan")
                has = lambda p, k: any(e[0] == k for e in p.events)  # noqa: E731
                ages = [a for p in Q for k, a in p.events if k == "marriage"]
                out[("family.age_first_marriage", "all", sx, r)] = sum(ages) / len(ages) if ages else float("nan")
                for share, key in (("primary_entry", "school_start"), ("primary_completion", "primary_complete"), ("secondary_entry", "secondary_start"),
                                   ("lower_secondary_completion", "secondary_complete"), ("tertiary_entry", "tertiary_start"),
                                   ("tertiary_completion", "tertiary_complete")):
                    out[("share:" + share, "all", sx, r)] = 100 * sum(has(p, key) for p in Q) / n
            Q = [p for p in P if p.death is None]
            out[("share:preschool", "all", "all", r)] = 100 * sum(any(e[0] == "preschool" for e in p.events) for p in Q) / len(Q)
            out.update(self._births_outside(r, wm))
        if self.domains:
            out.update(_domains.statistics(self))
        return out

    def _births_outside(self, r, women):
        """Share of births (to women alive at the family horizon) outside marriage: the mother unmarried or divorced at the birth."""
        n = m = 0
        for p in women:
            if p.death is not None:
                continue
            mar = next((a for k, a in p.events if k == "marriage"), None)
            div = next((a for k, a in p.events if k == "divorce"), None)
            for k, a in p.events:
                if k == "birth_of_child":
                    n += 1
                    m += mar is None or a < mar or (div is not None and a >= div)
        return {("family.births_outside_marriage", "all", "f", r): 100 * m / n if n else float("nan")}
