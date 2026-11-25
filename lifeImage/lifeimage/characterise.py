"""Characterisation: what an image shows, measured from features and not by eye.

An image state is what the renderer draws: per basemap slice, solid and claimed-potential (grain) levels of red, green and
blue in [0, 1] (`image_state`), the solid layer's saturation (tier, LI.38), whether a row names the slice directly, and the
newest imprint date of each slice. `features` computes the pre-registered features of
`data/gold/characterisation_signatures_v1.md` and `_v2.md` from it. `contrast_verdict`, `proportion_verdict`,
`paired_verdict`, `evaluate_signatures` and `identification_verdict` decide each pre-registered signature (held, not
held, inconclusive); `loo_accuracy` is blind identification (nearest centroid, leave one out, features standardised on the
training fold only); `pooled` is the humanity-white composite.

Populations: the starter personas under four projections (truth rows, claimed resume rows, rows extracted from the
resume texts, and the legacy projection) and the extended population (8 archetypes x 3 calibrations x 6 replicates,
generated, truth rows). Deterministic: no clock, fixed seeds.
"""
import json
import math
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from . import levels as lv
from .canonical import canonical_json
from .degradation import record_degradation
from .generators import life
from .generators.params import ARCHETYPES
from .render import basemap as bmod
from .render import image as im

ROOT = Path(__file__).resolve().parent.parent
SIGNATURES = ROOT / "data/gold/characterisation_signatures_v2.json"

CONSTANTS = {"grain_cover": 0.1837, "lit_bin_threshold": 0.10, "merge_gap_degrees": 15, "min_cluster_mass": 0.10,
             "current_years": 5, "past_years": 10, "luma": (0.2126, 0.7152, 0.0722),
             "claimed_slice_level": 0.05, "gap_margin": 0.10, "low_green": 0.30, "high_green": 0.60}
BINS = 360
ARCHETYPE_ORDER = ["student", "shift_worker", "carer", "small_business_owner", "researcher", "retiree", "career_changer", "generalist"]
CALIBRATION_ORDER = ["over", "well", "under"]
REPLICATES = 6
BASE_FEATURES = ("share_red", "share_green", "share_blue", "red_grain_share", "dimmed_share", "luminance", "chroma", "balance_distance",
                 "spread_entropy", "red_spread_entropy", "n_clusters", "max_arc_share", "current_luminance", "past_luminance",
                 "past_over_current", "cluster_age_gap",
                 "typical_level", "grain_cover", "n_claimed_slices", "claim_gap", "claim_gap_abs", "grain_green_share",
                 "mean_claimed_level", "overclaim_share", "underclaim_share")
EXTRA_FEATURES = ("claim_gap_low_green", "claim_gap_high_green")  # computed, not used in blind identification


@dataclass(frozen=True)
class Slice:
    id: str
    ring: str
    start: float
    width: float
    r0: float
    r1: float
    solid: tuple  # (red, green, blue) levels
    claimed: tuple  # claimed potential (grain), red only in practice
    newest: object = None  # day ordinal of the newest imprint, or None
    sat: float = 1.0  # saturation of the solid layer (tier, LI.38)
    touched: bool = False  # a row names this domain directly (not only by upstream bleed)

    @property
    def area(self):
        return self.width * (self.r1 ** 2 - self.r0 ** 2) / 2

    @property
    def centre(self):
        return (self.start + self.width / 2) % 360

    def displayed(self):
        """The solid colour blended toward its grey by 1 - sat, then lit by the grain: 1 - (1 - s') (1 - g L_claimed)."""
        g = CONSTANTS["grain_cover"]
        grey = math.fsum(self.solid) / 3
        solid = self.solid if self.sat == 1.0 else tuple(grey + self.sat * (x - grey) for x in self.solid)
        return tuple(1 - (1 - s) * (1 - g * c) for s, c in zip(solid, self.claimed))

    def luminance(self, d=None):
        return sum(w * c for w, c in zip(CONSTANTS["luma"], d or self.displayed()))


@dataclass
class State:
    slices: list
    asof: int  # day ordinal


class Features(dict):
    """Feature values by name; `gb_in:a+b` is computed from the per-sector `gb_in:a`."""
    def __missing__(self, key):
        if key.startswith("gb_in:") and "+" in key:
            return sum(self[f"gb_in:{s}"] for s in key[6:].split("+"))
        raise KeyError(key)


def feature_names():
    return set(BASE_FEATURES) | set(EXTRA_FEATURES)


def _runs(lit):
    """Circular runs of True bins, merged across dark gaps shorter than merge_gap_degrees: [[bin, ...], ...] (lit bins only)."""
    n = len(lit)
    if not any(lit):
        return []
    if all(lit):
        return [list(range(n))]
    d = lit.index(False)
    runs, cur = [], []
    for p in range(1, n + 1):
        b = (d + p) % n
        if lit[b]:
            cur.append((p, b))
        elif cur:
            runs.append(cur)
            cur = []
    if cur:
        runs.append(cur)
    gap = CONSTANTS["merge_gap_degrees"]
    merged = [runs[0]]
    for r in runs[1:]:
        if r[0][0] - merged[-1][-1][0] - 1 < gap:
            merged[-1] = merged[-1] + r
        else:
            merged.append(r)
    if len(merged) > 1 and (merged[0][0][0] - 1) + (n - merged[-1][-1][0]) < gap:
        merged[0] = merged.pop() + merged[0]
    return [[b for _, b in r] for r in merged]


def _bins(slices, value):
    """({bin: mean of value over the slices covering it}, per-bin (sum of weight x value x date, sum of weight x value))."""
    m = [0.0] * BINS
    dated = [[0.0, 0.0] for _ in range(BINS)]
    for s in slices:
        v = value(s)
        k0 = int(math.floor(s.start))
        k1 = int(math.ceil(s.start + s.width))
        for k in range(k0, k1):
            ov = min(s.start + s.width, k + 1) - max(s.start, k)
            if ov <= 0:
                continue
            b = k % BINS
            m[b] += ov * v
            if s.newest is not None and v > 0:
                dated[b][0] += ov * v * s.newest
                dated[b][1] += ov * v
    return m, dated


def _entropy(m):
    t = math.fsum(m)
    if t <= 0:
        return 0.0
    return -math.fsum(x / t * math.log(x / t) for x in m if x > 0) / math.log(len(m))


def features(state):
    sl = state.slices
    disp = [s.displayed() for s in sl]
    area = [s.area for s in sl]
    tot_a = math.fsum(area) or 1.0
    f = Features()
    chan = [math.fsum(a * d[k] for a, d in zip(area, disp)) for k in range(3)]
    t = math.fsum(chan)
    shares = [c / t if t > 0 else 0.0 for c in chan]
    f["share_red"], f["share_green"], f["share_blue"] = shares
    sol = math.fsum(a * s.solid[0] for a, s in zip(area, sl))
    cla = math.fsum(a * s.claimed[0] for a, s in zip(area, sl))
    f["red_grain_share"] = cla / (sol + cla) if sol + cla > 0 else 0.0
    y = [s.luminance(d) for s, d in zip(sl, disp)]
    f["luminance"] = math.fsum(a * v for a, v in zip(area, y)) / tot_a
    lit = [(a, d, v) for a, d, v in zip(area, disp, y) if v > 0]
    la = math.fsum(a for a, _, _ in lit)
    f["chroma"] = math.fsum(a * (max(d) - min(d)) / max(d) for a, d, _ in lit) / la if la > 0 else 0.0
    f["balance_distance"] = max(abs(x - 1 / 3) for x in shares)
    # angular features on the field ring
    fields = [s for s in sl if s.ring == "field"]
    d_of = dict(zip((id(s) for s in sl), disp))
    m, dated = _bins(fields, lambda s: s.luminance(d_of[id(s)]))
    f["spread_entropy"] = _entropy(m)
    mr, _ = _bins(fields, lambda s: d_of[id(s)][0])
    f["red_spread_entropy"] = _entropy(mr)
    thr, total = CONSTANTS["lit_bin_threshold"], math.fsum(m)
    clusters = []
    for run in _runs([x >= thr for x in m]):
        mass = math.fsum(m[b] for b in run)
        if total > 0 and mass >= CONSTANTS["min_cluster_mass"] * total:
            w = math.fsum(dated[b][1] for b in run)
            age = math.fsum(dated[b][0] for b in run) / w if w > 0 else None
            clusters.append({"lum": mass / len(run), "age": age})
    f["n_clusters"] = len(clusters)
    dc = sorted((c for c in clusters if c["age"] is not None), key=lambda c: c["age"])
    f["cluster_age_gap"] = dc[0]["lum"] - dc[-1]["lum"] if len(dc) >= 2 else float("nan")
    # sector arcs: a field belongs to the arc containing its centre angle
    sectors = [s for s in sl if s.ring == "sector"]
    fy = {s.id: a * v for s, a, v in zip(sl, area, y) if s.ring == "field"}
    fgb = {s.id: a * (d[1] + d[2]) for s, a, d in zip(sl, area, disp) if s.ring == "field"}
    arc_y, arc_gb = {s.id: 0.0 for s in sectors}, {s.id: 0.0 for s in sectors}
    for s in fields:
        for a in sectors:
            if (s.centre - a.start) % 360 < a.width:
                arc_y[a.id] += fy[s.id]
                arc_gb[a.id] += fgb[s.id]
                break
    ty, tgb = math.fsum(fy.values()), math.fsum(fgb.values())
    for a in sectors:
        f[f"arc_share:{a.id}"] = arc_y[a.id] / ty if ty > 0 else 0.0
        f[f"gb_in:{a.id}"] = arc_gb[a.id] / tgb if tgb > 0 else 0.0
    f["max_arc_share"] = max((f[f"arc_share:{a.id}"] for a in sectors), default=0.0)
    # recency
    cur, past = [], []
    for s, v in zip(sl, y):
        if v > 0 and s.newest is not None:
            age = (state.asof - s.newest) / 365.25
            if age <= CONSTANTS["current_years"]:
                cur.append(v)
            elif age >= CONSTANTS["past_years"]:
                past.append(v)
    nan = float("nan")
    f["current_luminance"] = math.fsum(cur) / len(cur) if cur else nan
    f["past_luminance"] = math.fsum(past) / len(past) if past else nan
    f["past_over_current"] = f["past_luminance"] / f["current_luminance"] if cur and past and f["current_luminance"] > 0 else nan
    _claim_features(f, fields)
    touched = sorted(max(s.solid) for s in fields if s.touched)
    n = len(touched)
    f["typical_level"] = (touched[n // 2] if n % 2 else (touched[n // 2 - 1] + touched[n // 2]) / 2) if n else nan
    return f


def _claim_features(f, fields):
    """Claimed potential (grain red) against demonstrated skill (solid green) in the field slices that carry a claim."""
    nan = float("nan")
    lvl, gm = CONSTANTS["claimed_slice_level"], CONSTANTS["gap_margin"]
    field_area = math.fsum(s.area for s in fields)
    cl = [s for s in fields if s.claimed[0] >= lvl]
    f["n_claimed_slices"] = len(cl)
    f["grain_cover"] = math.fsum(s.area for s in cl) / field_area if field_area > 0 and cl else 0.0
    for k in ("claim_gap", "claim_gap_abs", "grain_green_share", "mean_claimed_level", "overclaim_share", "underclaim_share",
              "claim_gap_low_green", "claim_gap_high_green"):
        f[k] = nan
    if not cl:
        return
    area = math.fsum(s.area for s in cl)
    gap = lambda ss: math.fsum(s.area * (s.claimed[0] - s.solid[1]) for s in ss) / math.fsum(s.area for s in ss)
    f["claim_gap"] = gap(cl)
    f["claim_gap_abs"] = math.fsum(s.area * abs(s.claimed[0] - s.solid[1]) for s in cl) / area
    claimed, green = math.fsum(s.area * s.claimed[0] for s in cl), math.fsum(s.area * s.solid[1] for s in cl)
    f["grain_green_share"] = claimed / (claimed + green) if claimed + green > 0 else nan
    f["mean_claimed_level"] = math.fsum(s.claimed[0] for s in cl) / len(cl)
    f["overclaim_share"] = math.fsum(s.area for s in cl if s.claimed[0] - s.solid[1] > gm) / area
    f["underclaim_share"] = math.fsum(s.area for s in cl if s.solid[1] - s.claimed[0] > gm) / area
    low = [s for s in cl if s.solid[1] < CONSTANTS["low_green"]]
    high = [s for s in cl if s.solid[1] >= CONSTANTS["high_green"]]
    if low:
        f["claim_gap_low_green"] = gap(low)
    if high:
        f["claim_gap_high_green"] = gap(high)


def dimmed_share(rows, asof, half_life=lv.DEFAULT.half_life_years):
    """1 - sum(magnitude x decay) / sum(magnitude) over the rows that imprint (live positive and prediction rows)."""
    live = [r for r in rows if not r["revoked"] and r["channel"] in ("positive", "prediction")]
    total = math.fsum(r["magnitude"] for r in live)
    if total <= 0:
        return 0.0
    ref = lv.parse_time(asof)
    kept = math.fsum(r["magnitude"] * lv.decay(lv.years_between(ref, lv.parse_time(r["valid_time"])), lv.Governed(half_life_years=half_life)) for r in live)
    return 1.0 - kept / total


# ---------- verdicts ----------

def wilson(k, n, z=1.96):
    if n == 0:
        return (0.0, 1.0)
    p = k / n
    den = 1 + z * z / n
    c = (p + z * z / (2 * n)) / den
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return (max(0.0, c - h), min(1.0, c + h))


def t_crit(df, p=0.975):
    """Student-t quantile (two-sided 95% by default): table below 3 degrees of freedom, Cornish-Fisher series above."""
    if df < 3:
        a, b = (1, 12.706), (2, 4.303)
        c = (3, 3.182)
        df = max(df, 1.0)
        return a[1] + (b[1] - a[1]) * (df - 1) if df <= 2 else b[1] + (c[1] - b[1]) * (df - 2)
    z = 1.959964
    return (z + (z ** 3 + z) / (4 * df) + (5 * z ** 5 + 16 * z ** 3 + 3 * z) / (96 * df ** 2)
            + (3 * z ** 7 + 19 * z ** 5 + 17 * z ** 3 - 15 * z) / (384 * df ** 3))


def _mean_var(x):
    n = len(x)
    m = math.fsum(x) / n
    return m, (math.fsum((v - m) ** 2 for v in x) / (n - 1) if n > 1 else 0.0)


def contrast_verdict(group, versus, direction, delta):
    """Held / not held / inconclusive for a contrast of means (see the rule in the signatures file)."""
    s = 1.0 if direction == ">" else -1.0
    out = {"n_group": len(group), "n_versus": len(versus)}
    if len(group) < 2 or len(versus) < 2:
        return {**out, "verdict": "inconclusive", "effect": None, "lo": None, "hi": None}
    (ma, va), (mb, vb) = _mean_var(group), _mean_var(versus)
    e = s * (ma - mb)
    se2 = va / len(group) + vb / len(versus)
    se = math.sqrt(se2)
    if se2 > 0:
        df = se2 ** 2 / ((va / len(group)) ** 2 / (len(group) - 1) + (vb / len(versus)) ** 2 / (len(versus) - 1))
        crit = t_crit(df)
    else:
        crit = 0.0
    lo, hi = e - crit * se, e + crit * se
    if e >= delta and lo > 0:
        verdict = "held"
    elif hi < delta:
        verdict = "not held"
    else:
        verdict = "inconclusive"
    return {**out, "verdict": verdict, "mean_group": ma, "mean_versus": mb, "effect": e, "lo": lo, "hi": hi}


def paired_verdict(diffs, direction, delta):
    """Held / not held / inconclusive for the mean of per-persona differences (Student-t at n - 1 degrees of freedom)."""
    s = 1.0 if direction == ">" else -1.0
    n = len(diffs)
    if n < 2:
        return {"n_group": n, "n_versus": n, "verdict": "inconclusive", "effect": None, "lo": None, "hi": None}
    m, v = _mean_var(diffs)
    e, se = s * m, math.sqrt(v / n)
    crit = t_crit(n - 1) if se > 0 else 0.0
    lo, hi = e - crit * se, e + crit * se
    verdict = "held" if e >= delta and lo > 0 else "not held" if hi < delta else "inconclusive"
    return {"n_group": n, "n_versus": n, "verdict": verdict, "mean_group": m, "mean_versus": 0.0, "effect": e, "lo": lo, "hi": hi}


def identification_verdict(bound, value, correct, n):
    """A stated minimum or maximum of blind-identification accuracy: held if the point accuracy meets it, not held if the
    Wilson 95% interval lies wholly on the wrong side, inconclusive otherwise."""
    lo, hi = wilson(correct, n)
    acc = correct / n if n else 0.0
    if bound == "min":
        verdict = "held" if n and acc >= value else "not held" if hi < value else "inconclusive"
    else:
        verdict = "held" if n and acc <= value else "not held" if lo > value else "inconclusive"
    return {"verdict": verdict, "accuracy": acc, "correct": correct, "n": n, "lo": lo, "hi": hi, "bound": bound, "value": value}


def evaluate_identification(specs, ident_by_set):
    """Verdicts of the pre-registered identification predictions; `ident_by_set` is {set name: {label: {correct, n}}}. A spec set
    "starter extracted (var0, var1, var2) / new" pools the three variants (correct and n summed)."""
    out = []
    for sp in specs:
        names = [f"starter extracted var{v} / new" for v in range(3)] if sp["set"].startswith("starter extracted (") else [sp["set"]]
        got = [ident_by_set[n][sp["label"]] for n in names if n in ident_by_set]
        res = identification_verdict(sp["bound"], sp["value"], sum(g["correct"] for g in got), sum(g["n"] for g in got)) if got else \
            {"verdict": "inconclusive", "accuracy": None, "correct": 0, "n": 0, "lo": 0.0, "hi": 1.0, "bound": sp["bound"], "value": sp["value"]}
        out.append({"id": sp["id"], "set": sp["set"], "label": sp["label"], "confidence": sp["confidence"], **res})
    return out


def proportion_verdict(k, n, p0):
    lo, hi = wilson(k, n)
    verdict = "held" if n and lo >= p0 else "not held" if n and hi < p0 else "inconclusive"
    return {"verdict": verdict, "k": k, "n": n, "p": k / n if n else None, "lo": lo, "hi": hi}


def _match(rec, spec):
    return all(rec.get(k) == v for k, v in spec.items())


def _predicate(rec, text):
    name, op, val = text.split()
    x = rec[name]
    if isinstance(x, float) and math.isnan(x):
        return False
    return {">=": x >= float(val), "<": x < float(val), ">": x > float(val), "<=": x <= float(val)}[op]


def feature_value(rec, name):
    """A record's value of a feature; `gb_in:a+b` sums the per-sector values."""
    if name.startswith("gb_in:") and "+" in name:
        return sum(rec[f"gb_in:{x}"] for x in name[6:].split("+"))
    return rec[name]


def _isnan(x):
    return isinstance(x, float) and math.isnan(x)


def _subset(records, spec):
    if not spec:
        return records
    return [r for r in records if r.get("age") is not None and spec.get("age_min", -1e9) <= r["age"] <= spec.get("age_max", 1e9)]


def evaluate_signatures(sigs, records, pooled_result=None, sets=None):
    """[{id, statement, confidence, verdict, ...}] over records ({archetype, calibration, age, **features}); `sets` is
    {name: records} for signatures that name another projection (`paired_sets`, `band_stat` with a `set`)."""
    out = []
    for s in sigs:
        base = {"id": s["id"], "statement": s["statement"], "confidence": s["confidence"], "kind": s["kind"]}
        if s["kind"] == "contrast":
            grp = [r for r in records if _match(r, s["group"])]
            if s["versus"] == "rest":
                (k, v), = s["group"].items()
                ver = [r for r in records if r.get(k) != v]
            else:
                ver = [r for r in records if _match(r, s["versus"])]
            vals = lambda rs: [feature_value(r, s["feature"]) for r in rs]
            pick = lambda rs: [x for x in vals(rs) if not (isinstance(x, float) and math.isnan(x))]
            res = contrast_verdict(pick(grp), pick(ver), s["direction"], s["delta"])
            res["delta"], res["direction"], res["feature"] = s["delta"], s["direction"], s["feature"]
        elif s["kind"] == "proportion":
            grp = [r for r in records if _match(r, s["group"]) and (not s.get("given") or _predicate(r, s["given"]))]
            res = proportion_verdict(sum(_predicate(r, s["predicate"]) for r in grp), len(grp), s["p0"])
            res["p0"] = s["p0"]
        elif s["kind"] == "paired":
            diffs = []
            for r in records:
                a = feature_value(r, s["a"])
                b = s["b"] if isinstance(s["b"], (int, float)) else feature_value(r, s["b"])
                if not (_isnan(a) or _isnan(b)):
                    diffs.append(a - b)
            res = paired_verdict(diffs, s["direction"], s["delta"])
            res["delta"], res["direction"], res["feature"] = s["delta"], s["direction"], s.get("feature", f"{s['a']} - {s['b']}")
        elif s["kind"] == "paired_sets":
            first, second = ({r["id"]: r for r in (sets or {}).get(n, [])} for n in s["sets"])
            diffs = [first[i][s["feature"]] - second[i][s["feature"]] for i in sorted(set(first) & set(second))
                     if not (_isnan(first[i][s["feature"]]) or _isnan(second[i][s["feature"]]))]
            res = paired_verdict(diffs, s["direction"], s["delta"])
            res["delta"], res["direction"] = s["delta"], s["direction"]
        elif s["kind"] == "band_stat":
            pool = _subset((sets or {}).get(s["set"], []) if "set" in s else records, s.get("subset"))
            vals = sorted(x for x in (feature_value(r, s["feature"]) for r in pool) if not _isnan(x))
            if not vals:
                res = {"verdict": "inconclusive", "value": None, "n": 0, "lo": s["lo"], "hi": s["hi"]}
            else:
                v = math.fsum(vals) / len(vals) if s["stat"] == "mean" else (vals[len(vals) // 2] if len(vals) % 2 else (vals[len(vals) // 2 - 1] + vals[len(vals) // 2]) / 2)
                res = {"verdict": "held" if s["lo"] - 1e-12 <= v <= s["hi"] + 1e-12 else "not held", "value": v, "n": len(vals), "lo": s["lo"], "hi": s["hi"], "stat": s["stat"]}
        elif s["kind"] == "band":
            vals = pooled_result["shares"] if pooled_result else {}
            ok = bool(vals) and all(s["lo"] <= v <= s["hi"] for v in vals.values())
            res = {"verdict": "held" if ok else "not held", "values": dict(vals), "lo": s["lo"], "hi": s["hi"]}
        else:  # contrast_pooled
            v = pooled_result["chroma_over_mean_chroma"] if pooled_result else None
            res = {"verdict": "held" if v is not None and v <= s["value"] else "not held", "value": v, "limit": s["value"]}
        out.append({**base, **res})
    return out


def load_signatures(path=SIGNATURES):
    return json.loads(Path(path).read_text(encoding="utf-8"))["signatures"]


def load_identification(path=SIGNATURES):
    return json.loads(Path(path).read_text(encoding="utf-8")).get("identification", [])


def tally(verdicts):
    t = {"held": 0, "not held": 0, "inconclusive": 0}
    for v in verdicts:
        t[v["verdict"]] += 1
    return t


# ---------- blind identification ----------

def loo_accuracy(X, y):
    """Nearest centroid, leave one out; features standardised (and NaN imputed with the mean) on the training fold only.
    A held-out point whose class has no other member cannot be identified."""
    n, d = len(X), len(X[0]) if X else 0
    preds = []
    for i in range(n):
        tr = [j for j in range(n) if j != i]
        mu, sd = [], []
        for k in range(d):
            col = [X[j][k] for j in tr if not math.isnan(X[j][k])]
            m = math.fsum(col) / len(col) if col else 0.0
            v = math.sqrt(math.fsum((c - m) ** 2 for c in col) / len(col)) if col else 0.0
            mu.append(m)
            sd.append(v if v > 1e-12 else 1.0)
        z = lambda row: [((row[k] if not math.isnan(row[k]) else mu[k]) - mu[k]) / sd[k] for k in range(d)]
        cent = {}
        for j in tr:
            cent.setdefault(y[j], []).append(z(X[j]))
        cent = {c: [math.fsum(col) / len(col) for col in zip(*v)] for c, v in sorted(cent.items())}
        zi = z(X[i])
        preds.append(min(cent, key=lambda c: (math.fsum((a - b) ** 2 for a, b in zip(zi, cent[c])), c)))
    correct = sum(p == t for p, t in zip(preds, y))
    classes = sorted(set(y))
    return {"accuracy": correct / n if n else 0.0, "correct": correct, "n": n, "wilson": wilson(correct, n),
            "chance": 1 / len(classes) if classes else 0.0, "majority": max(y.count(c) for c in classes) / n if n else 0.0,
            "predictions": preds}


def _vector(rec, names):
    out = []
    for k in names:
        x = rec[k]
        if k == "past_over_current" and not math.isnan(x):
            x = min(5.0, x)
        out.append(x)
    return out


def identification_names(records):
    arcs = sorted(k for k in records[0] if k.startswith("arc_share:"))
    return [k for k in BASE_FEATURES] + arcs


def identify(records):
    names = identification_names(records)
    X = [_vector(r, names) for r in records]
    return {label: loo_accuracy(X, [r[label] for r in records]) for label in ("archetype", "calibration")}


# ---------- humanity white ----------

def pooled(states):
    """The composite of many images: per slice, the mean of the displayed channels. Its channel shares, chroma and the
    ratio of its chroma to the mean chroma of one image."""
    states = list(states)
    base = states[0].slices
    comp = []
    for i, s in enumerate(base):
        d = [st.slices[i].displayed() for st in states]
        comp.append(Slice(s.id, s.ring, s.start, s.width, s.r0, s.r1, tuple(math.fsum(x[k] for x in d) / len(d) for k in range(3)), (0.0, 0.0, 0.0), None))
    f = features(State(comp, states[0].asof))
    mean_chroma = math.fsum(features(st)["chroma"] for st in states) / len(states)
    return {"shares": {"red": f["share_red"], "green": f["share_green"], "blue": f["share_blue"]}, "chroma": f["chroma"],
            "mean_chroma": mean_chroma, "chroma_over_mean_chroma": f["chroma"] / mean_chroma if mean_chroma > 0 else 0.0}


# ---------- image states ----------

@lru_cache(maxsize=1)
def world_basemap():
    return bmod.build_v0()


@lru_cache(maxsize=1)
def world_cards():
    return bmod.load_cards()


def _newest(rows, cards):
    """{domain: newest valid_time ordinal} over the live rows that imprint it, directly or through an upstream bleed."""
    by = {c["id"]: c for c in cards}
    out = {}
    for r in rows:
        if r["revoked"] or r["channel"] not in ("positive", "prediction"):
            continue
        t = lv.parse_time(r["valid_time"]).toordinal()
        for m in r["memberships"]:
            if m["rel"] not in lv.ALL_RELS or m["domain"] not in by:
                continue
            for d in [m["domain"]] + [l["id"] for l in by[m["domain"]]["links"] if l["rel"] == "upstream"]:
                out[d] = max(out.get(d, t), t)
    return out


def image_state(rows, bm, asof=None, legacy=False):
    """The state the renderer draws for one entity's rows: levels per slice (legacy: the earlier projection on its log
    intensity scale, claimed colour not desaturated)."""
    cards = world_cards()
    cv = im.channel_values(rows, cards, asof=asof, legacy=legacy)
    newest = _newest(rows, cards)
    touched = lv.touched_domains(rows, cards, im.DEFAULT.levels, asof)
    live = [r for r in rows if not r["revoked"] and r["channel"] in ("positive", "prediction")]
    ref = lv.parse_time(asof).toordinal() if asof else max((lv.parse_time(r["valid_time"]).toordinal() for r in live), default=0)
    conv = (lambda v: im.intensity(v)) if legacy else (lambda v: min(1.0, max(0.0, v)))
    sl = []
    for i, s in sorted(bm.slices.items()):
        lay = []
        for layer in ("solid", "claimed"):
            ch = cv.get(layer, {}).get(i, {})
            lay.append(tuple(conv(ch.get(k, 0.0)) for k in lv.CHANNELS))
        sat = 1.0 if legacy else cv.get("solid", {}).get(i, {}).get("saturation", 1.0)
        sl.append(Slice(i, s.ring, s.start, s.width, s.r0, s.r1, lay[0], lay[1], newest.get(i), sat, i in touched))
    return State(sl, ref)


def record_for(entity, rows, asof, legacy=False, bm=None):
    st = image_state(rows, bm or world_basemap(), asof, legacy)
    f = features(st)
    f["dimmed_share"] = dimmed_share(rows, asof) if asof else 0.0
    return {"id": entity["id"], "archetype": entity.get("archetype"), "calibration": entity.get("calibration"), "age": entity.get("age"), **f}, st


# ---------- data ----------

def _jsonl(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def starter_personas(root=ROOT):
    return _jsonl(root / "data/synthetic/personas.jsonl")


def _by_persona(personas, rows):
    by = {p["id"]: [] for p in personas}
    for r in rows:
        pid = r["entity"].split(":", 1)[1]
        if pid in by:
            by[pid].append(r)
    return by


def starter_rows(source, root=ROOT, log=None):
    """"truth": every row; "resume": the claimed rows read from resumes; "extracted": {variant: {id: rows}} read by the extractor
    from the resume texts (claims only; memberships in domains outside the card set dropped, recorded loudly)."""
    personas = starter_personas(root)
    if source in ("truth", "resume"):
        rows = _by_persona(personas, _jsonl(root / "data/synthetic/rows.jsonl"))
        if source == "resume":
            rows = {p: [r for r in rs if r["tier"] == "claimed" and r["provenance"]["source"].startswith("resume:")] for p, rs in rows.items()}
        return rows
    if source != "extracted":
        raise ValueError(f"unknown source {source!r}")
    from .extract import evidence_rows
    known = {c["id"] for c in world_cards()}
    version = world_cards()[0]["basemap_version"]
    out = {}
    for v in range(3):
        base = root / f"data/batches/texts_v2/extract.v1.var{v}"
        if not Path(f"{base}.jsonl").exists() or not Path(f"{base}.answers.jsonl").exists():
            record_degradation(f"extracted var{v}", "extract_answers", "no extracted rows for this variant",
                               f"answers file absent: {Path(base).name}.answers.jsonl run the rebuilt batch on the runner", log)
            out[v] = _by_persona(personas, [])
            continue
        tasks = {t["task_id"]: t for t in _jsonl(f"{base}.jsonl") if t.get("kind") == "task"}
        from .extract import numbered
        for t in tasks.values():  # the batch must carry the texts as they are now, or its answers are for other texts
            pid = t["input"]["source"].split(":", 1)[1]
            now = numbered((root / f"data/synthetic/texts_v2/{pid}.resume.txt").read_text(encoding="utf-8"))
            if canonical_json(t["input"]["lines"]) != canonical_json(now):  # batches hold canonical text (whitespace folded)
                raise ValueError(f"extracted var{v}: the batch of {pid} holds other texts than data/synthetic/texts_v2 now "
                                 "(answers to it are stale); rebuild with tools/build_extract_batches.py --texts texts_v2")
        rows = []
        for a in _jsonl(f"{base}.answers.jsonl"):
            t = tasks[a["task_id"]]
            for r in evidence_rows(a, t["input"], version):
                dropped = [m["domain"] for m in r["memberships"] if m["domain"] not in known]
                if dropped:
                    record_degradation(f"extracted var{v} {r['entity']}", "extract_domains", "memberships dropped",
                                       f"domains not in the card set: {sorted(set(dropped))[:3]}", log)
                    r["memberships"] = [m for m in r["memberships"] if m["domain"] in known]
                if r["memberships"]:
                    rows.append(r)
        out[v] = _by_persona(personas, rows)
    return out


def extended_population():
    """[{id, seed, archetype, calibration, age}]: 8 archetypes x 3 calibrations x 6 replicates, deterministic."""
    out = []
    for ai, a in enumerate(ARCHETYPE_ORDER):
        lo, hi = ARCHETYPES[a]["age_range"]
        for ci, c in enumerate(CALIBRATION_ORDER):
            for rep in range(REPLICATES):
                seed = 9000 + 1000 * ai + 100 * ci + rep
                out.append({"id": f"x{seed}", "seed": seed, "archetype": a, "calibration": c, "age": lo + round((hi - lo) * rep / (REPLICATES - 1))})
    return out


def extended_rows(spec):
    p = life.generate_persona(seed=spec["seed"], archetype=spec["archetype"], age=spec["age"], calibration=spec["calibration"], pid=spec["id"])
    return p.rows, p.as_of


def population_records(entities, rows_by_id, asof_by_id, legacy=False):
    recs, states = [], []
    for e in entities:
        rec, st = record_for(e, rows_by_id[e["id"]], asof_by_id[e["id"]], legacy)
        recs.append(rec)
        states.append(st)
    return recs, states
