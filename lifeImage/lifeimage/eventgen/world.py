"""Probe world: family formation and schooling for a few hundred synthetic people across regions, driven only by the calibration table.

Per person: birth -> (preschool) -> primary entry -> primary completion or dropout -> secondary -> lower-secondary completion
or dropout -> tertiary entry -> completion or dropout; first marriage; for women, births by age band. Every gate is a
conditional probability derived from the table's cohort shares (`derive_setup`, shared with the rate head so the head's target
is what the generator was meant to follow). Cohort shares are nested (each level cannot exceed the one before): where the
table's values are incoherent (over-age pupils push completion above 100%) the share is clipped and a loud `degraded`
entry records it. Missing strata degrade country -> region -> world (`Table.lookup`).

Each mechanism draws from its own random stream per (seed, region, mechanism) and the same number of draws per person whether
or not the gate opens, so changing one mechanism's parameter moves only that mechanism and arms of an experiment share seeds.
Not modelled (named toy assumptions): deaths, partners (a marriage has no spouse; births ignore marital state, so marginal
rates can be right while sequences are wrong, the reason the sequence head comes next), fatherhood, upper-secondary completion,
migration, cohort change (period rates of one year are applied to every age).
"""
import dataclasses
import datetime as dt
import math
from collections import defaultdict
from statistics import NormalDist

from ..generators.common import stream
from ..governed import governed
from . import events as ev
from .calibration import load_regions

BIRTH_DATE = dt.date(1973, 7, 1)
BANDS = ("15-19", "20-24", "25-29", "30-34", "35-39", "40-44", "45-49")
PRIMARY_AGE, LAST_GRADE_AGE = "primary age", "last-grade age"
_N = NormalDist()


def noise_defaults():
    return {k: governed(f"noise.{k}") for k in ("fertility_frailty_sd", "marriage_age_sd", "school_entry_delay_p")}


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


def derive_setup(table, region, regions):
    """The generator's inputs for a region from the table: ASFR by band, sex ratio at birth, marriage ages, and nested cohort shares per sex."""
    step = f"setup:{region}"
    look = lambda q, band, sex="all": table.lookup(q, band, sex, region, regions, step)  # noqa: E731
    val = lambda p, d=None: (p.value if p is not None else d)  # noqa: E731
    s = {"region": region, "params": {}, "clipped": []}
    s["asfr"] = {b: val(look("fertility.asfr", b, "f"), 0.0) for b in BANDS}
    s["srb"] = val(look("fertility.sex_ratio_at_birth", "0"), 105.0)
    s["tfr"] = val(look("fertility.tfr", "15-49", "f"))
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
    return s


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


class World:
    def __init__(self, table, regions=("KEN", "IND", "FRA"), n_per_region=170, seed=1, noise=None, region_map=None):
        self.table, self.seed, self.regions = table, seed, tuple(regions)
        self.noise = {**noise_defaults(), **(noise or {})}
        self.region_map = region_map if region_map is not None else load_regions()
        self.setups = {r: derive_setup(table, r, self.region_map) for r in self.regions}
        self.people = [p for r in self.regions for p in self._region(r, n_per_region)]

    @property
    def degraded(self):
        return self.table.degraded

    def _region(self, region, n):
        S, nz, seed = self.setups[region], self.noise, self.seed
        R = {m: _stream(seed, region, m) for m in ("sex", "preschool", "entry", "delay", "pc", "prog", "lsc", "ter", "ba", "drop", "ever", "marriage_age",
                                                    "fertility", "frailty")}
        horizon, L, TY = governed("eventgen.horizon_age"), governed("eventgen.lower_secondary_years"), governed("eventgen.tertiary_years")
        mus = {sx: trunc_normal_mu(S["smam"][sx], nz["marriage_age_sd"], 15.0) for sx in "fm"}
        a_cdf = {sx: _N.cdf((15.0 - mus[sx]) / nz["marriage_age_sd"]) for sx in "fm"}
        out = []
        for i in range(n):
            sx = "m" if R["sex"].random() < S["srb"] / (100 + S["srb"]) else "f"
            sh = S["shares"][sx]
            u = {k: R[k].random() for k in ("preschool", "entry", "delay", "pc", "prog", "lsc", "ter", "ba")}
            ud = [R["drop"].random() for _ in range(3)]
            ever, um = R["ever"].random(), R["marriage_age"].random()
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
            if ever < governed("eventgen.partnership_ever_share"):
                x = _N.inv_cdf(a_cdf[sx] + um * (1 - a_cdf[sx])) * nz["marriage_age_sd"] + mus[sx]
                ev_.append(("marriage", x))
            if sx == "f":
                fr = math.exp(nz["fertility_frailty_sd"] * R["frailty"].gauss(0, 1) - nz["fertility_frailty_sd"] ** 2 / 2)
                for age in range(15, 50):
                    d = R["fertility"].random()
                    if d < min(0.95, S["asfr"][BANDS[(age - 15) // 5]] / 1000 * fr):
                        ev_.append(("birth_of_child", age + R["fertility"].random() * 0.0 + 0.5))
            out.append(Person(f"{region}-{i:04d}", region, sx, [e for e in ev_ if e[1] <= horizon]))
        return out

    def rows(self):
        """Library-format rows of every event (validated); one per event."""
        out = []
        for p in self.people:
            for n, (key, age) in enumerate(p.events):
                out.append(ev.make_row(f"person:{p.pid}", p.region, key, BIRTH_DATE, age, f"ev:{p.pid}-{n:02d}"))
        return out

    def statistics(self):
        """Generated statistics per (quantity, age_band, sex, region), in the units of `rates.UNITS`."""
        out = {}
        for r in self.regions:
            P = [p for p in self.people if p.region == r]
            wm = [p for p in P if p.sex == "f"]
            births = defaultdict(int)
            for p in wm:
                for k, a in p.events:
                    if k == "birth_of_child":
                        births[BANDS[int(a - 15) // 5]] += 1
            for b in BANDS:
                out[("fertility.asfr", b, "f", r)] = 1000 * births[b] / (5 * len(wm)) if wm else float("nan")
            out[("fertility.tfr", "15-49", "f", r)] = sum(births.values()) / len(wm) if wm else float("nan")
            out[("fertility.sex_ratio_at_birth", "0", "all", r)] = 100 * sum(p.sex == "m" for p in P) / max(1, sum(p.sex == "f" for p in P))
            for sx in "fm":
                Q = [p for p in P if p.sex == sx]
                n = len(Q) or float("nan")
                has = lambda p, k: any(e[0] == k for e in p.events)  # noqa: E731
                ages = [a for p in Q for k, a in p.events if k == "marriage"]
                out[("family.age_first_marriage", "all", sx, r)] = sum(ages) / len(ages) if ages else float("nan")
                for share, key in (("primary_entry", "school_start"), ("primary_completion", "primary_complete"), ("secondary_entry", "secondary_start"),
                                   ("lower_secondary_completion", "secondary_complete"), ("tertiary_entry", "tertiary_start"),
                                   ("tertiary_completion", "tertiary_complete")):
                    out[("share:" + share, "all", sx, r)] = 100 * sum(has(p, key) for p in Q) / n
            Q = P
            out[("share:preschool", "all", "all", r)] = 100 * sum(any(e[0] == "preschool" for e in p.events) for p in Q) / len(Q)
        return out
