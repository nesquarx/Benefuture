"""Rate head of the verifier: generated rates by age band, sex and region against the calibration table.

Statistic per (quantity, age band, sex, region) is computed per seed on a world built from the (possibly mis-specified) generator
table; the target is derived from the *true* table by the same `derive_setup`, so the head checks what the generator was meant
to follow, clipping included. Per Param (CLAUDE.md significance rule):
  effect = mean over seeds - target; standard error from the spread across seeds, inflated by Student-t over z (small seed counts);
  calibration uncertainty enters the combined standard error by confidence class;
  fail  = |effect| >= z combined SEs and |effect| beyond the margin (the smallest effect that matters);
  pass  = |effect| + z SEs of the generator <= margin (equivalence within the margin, never mere non-significance);
  otherwise inconclusive (underpowered). Seeds are added by precision (`seeds_until_stable`) up to a cap and the count is reported.
"""
import math
from statistics import NormalDist, mean, stdev

from ..governed import governed
from .world import BANDS, World, derive_setup

UNITS = {"fertility.asfr": "per1000", "fertility.tfr": "births_per_woman", "fertility.sex_ratio_at_birth": "ratio",
         "family.age_first_marriage": "years"}  # all "share:*" statistics are in percent
SHARE_PARAM = {"primary_entry": "education.primary_net_enrolment", "primary_completion": "education.primary_completion",
               "secondary_entry": "education.progression_to_secondary", "lower_secondary_completion": "education.lower_secondary_completion",
               "tertiary_entry": "education.tertiary_gross_enrolment", "tertiary_completion": "education.tertiary_bachelor_attainment",
               "preschool": "education.preprimary_gross_enrolment"}


def student_inflation(n):
    """t(0.975, n-1) / z(0.975): how much a standard error from n seeds is widened (Cornish-Fisher t quantile)."""
    z = NormalDist().inv_cdf(0.975)
    v = max(1, n - 1)
    t = z + (z**3 + z) / (4 * v) + (5 * z**5 + 16 * z**3 + 3 * z) / (96 * v**2)
    return t / z


def expected_targets(table, regions, region_map):
    """{(quantity, band, sex, region): (target, param_or_None, clipped)} from the true table, in statistic units."""
    out = {}
    for r in regions:
        S = derive_setup(table, r, region_map)
        for b in BANDS:
            out[("fertility.asfr", b, "f", r)] = (S["asfr"][b], table.lookup("fertility.asfr", b, "f", r, region_map, f"head:{r}"), False)
        if S["tfr"] is not None:
            out[("fertility.tfr", "15-49", "f", r)] = (S["tfr"], table.lookup("fertility.tfr", "15-49", "f", r, region_map, f"head:{r}"), False)
        out[("fertility.sex_ratio_at_birth", "0", "all", r)] = (S["srb"], table.lookup("fertility.sex_ratio_at_birth", "0", "all", r, region_map, f"head:{r}"), False)
        for sx in "fm":
            out[("family.age_first_marriage", "all", sx, r)] = (S["smam"][sx], table.lookup("family.age_first_marriage", "all", sx, r, region_map, f"head:{r}"), False)
            clipped = {c["share"] for c in S["clipped"] if c["sex"] == sx}
            for share, v in S["shares"][sx].items():
                if share == "secondary_entry":
                    continue  # derived from completion and progression, not a Param of its own; checked through primary_completion and lower_secondary
                out[("share:" + share, "all", sx, r)] = (100 * v, None, share in clipped)
        out[("share:preschool", "all", "all", r)] = (100 * S["pre"], None, False)
    return out


def _margin(quantity, target):
    unit = UNITS.get(quantity, "pct")
    return max(governed("eventgen.rate_margin_rel") * abs(target), governed(f"eventgen.margin_floor.{unit}"))


def paired_effect(a, b):
    """Mean difference a-b over paired seeds (common random numbers), its standard error and z."""
    d = [x - y for x, y in zip(a, b)]
    se = stdev(d) / math.sqrt(len(d)) if len(d) > 1 else float("inf")
    return mean(d), se, (mean(d) / se if se > 0 else (0.0 if mean(d) == 0 else math.inf))


def judge(quantity, values, target, confidence, z=None):
    z = governed("eventgen.rate_z") if z is None else z
    n = len(values)
    m = mean(values)
    se = stdev(values) / math.sqrt(n) * student_inflation(n) if n > 1 else float("inf")
    se_cal = governed(f"eventgen.cal_se_rel.{confidence}") * abs(target)
    comb = math.hypot(se, se_cal)
    eff, margin = m - target, _margin(quantity, target)
    zeff = eff / comb if comb > 0 else 0.0
    if abs(zeff) >= z and abs(eff) > margin:
        status = "fail"
    elif abs(eff) + z * se <= margin:
        status = "pass"
    else:
        status = "inconclusive"
    return {"status": status, "mean": m, "target": target, "effect": eff, "effect_rel": eff / target if target else float("nan"), "se": se,
            "z": zeff, "margin": margin, "seeds": n}


def rate_head(true_table, make_world, regions, region_map, seeds=None, z=None):
    """Judge every statistic. `make_world(seed)` builds the generated world; `seeds` fixes the seed list, else seeds are added by
    precision (`eventgen.min_seeds` first, then one at a time until every statistic's z-SE is within half its margin, capped at `eventgen.max_seeds`)."""
    targets = expected_targets(true_table, regions, region_map)
    zz = governed("eventgen.rate_z") if z is None else z
    series = {k: [] for k in targets}
    n_seeds = 0
    seed = 0
    degraded_worlds = []

    def add():
        nonlocal seed, n_seeds
        seed += 1
        w = make_world(seed)
        if not degraded_worlds:
            degraded_worlds.extend(w.degraded)
        st = w.statistics()
        for k in targets:
            series[k].append(st[k])
        n_seeds += 1

    def stable():
        for k, (t, _, _) in targets.items():
            v = series[k]
            if len(v) < 2 or any(x != x for x in v):
                return False
            se = stdev(v) / math.sqrt(len(v)) * student_inflation(len(v))
            if zz * se > _margin(k[0], t) / 2:
                return False
        return True

    if seeds:
        for _ in range(seeds):
            add()
    else:
        for _ in range(governed("eventgen.min_seeds")):
            add()
        while not stable() and n_seeds < governed("eventgen.max_seeds"):
            add()
    results = []
    for k, (t, p, clipped) in sorted(targets.items(), key=lambda kv: kv[0]):
        vals = [x for x in series[k] if x == x]
        conf = p.confidence if p is not None else "medium"
        if not vals:
            results.append({"key": k, "status": "inconclusive", "seeds": 0, "clipped": clipped, "degraded": False})
            continue
        r = judge(k[0], vals, t, conf, zz)
        results.append({"key": k, "clipped": clipped, "confidence": conf, "param_region": p.region if p else None, **r})
    summary = {s: sum(r["status"] == s for r in results) for s in ("pass", "fail", "inconclusive")}
    return {"results": results, "summary": summary, "seeds": n_seeds, "degraded": true_table.degraded}
