"""Metrics of the layer B (participation) and layer D (event links) batteries, over k variants.

Participation, per (item, participant) unit with the variants as coders:
- agreement per field: Krippendorff's alpha, interval for the numbers (contribution, responsibility, net impact =
  sum of sign x magnitude over parties) and nominal for the categories (production, volition, acting_for as a
  normalised string, informed and under_agreement as present-or-null, since their text is free). Null is its own
  category. Impact parties are compared as sets (mean Jaccard). The null rate of a field is the share of
  participant entries answering null (an empty impact list for impact).
- contribution Spearman: the mean over variant pairs of the rank correlation of contributions over the units.
- conservation: the share of answers whose contributions to the one outcome sum above 1 (tolerance 1e-6), and the
  largest sum. Contributions are additive shares of one outcome, so above 1 means value would be minted.
- overdetermination: items carrying `expect` (participants, contribution_max, responsibility_min) are those where
  contribution and responsibility should diverge (sufficient shooters, a decisive vote). `pattern_rate` is the share
  of answers in which every expected participant has contribution at most contribution_max and responsibility at
  least responsibility_min; `mean_divergence` is the mean of responsibility minus contribution over them. A model
  that credits each sufficient cause fully fails the contribution bound; one that collapses responsibility into
  contribution fails the responsibility bound.
- collision rate on minimal pairs marked B: the share whose two texts get identical B annotations. A text's
  annotation is, per participant id and field, the majority value over its variants (ties to the lowest, null a
  category); fields are contribution and responsibility in quarter steps, impact sign, acting_for, under_agreement,
  informed, volition and production. Only participants listed in both texts are compared. The share of pairs
  differing per field, and the share differing in at least one field the pair is expected to differ in, are
  reported with it.

Events, per item with the variants as coders:
- agreement on the number of sub-events: interval alpha.
- link-type agreement: sub-events of two variants are matched one-to-one by normalised token overlap (lower case,
  stop words dropped, light stemming; overlap coefficient at least 0.5, best first). Over every pair of matched
  sub-events, the label of the link between them in each variant (`none`, or the type, with `^-1` for a directed
  type pointing the other way; several links join with `+`) is compared: nominal alpha over all matched pairs, and
  `linked_agree`, the share of matched pairs linked in at least one variant where the labels are equal.
- link usage: per type, the share of items where any variant uses it.
- D pairs: for minimal pairs marked D (the first text adds an occurrence), the share where the first text gets more
  sub-events on average than the second.
"""
import itertools
import json
import math
import re
from collections import defaultdict
from pathlib import Path

from .events import LINK_TYPES, SYMMETRIC
from .links import jaccard
from .membership_metrics import NULL, krippendorff_alpha_nominal

CONSERVATION_TOL = 1e-6
MATCH_THRESHOLD = 0.5
SIGNATURE_FIELDS = ("contribution", "responsibility", "impact_sign", "acting_for", "under_agreement", "informed",
                    "volition", "production")
# The fields in which each B pair's two texts are expected to differ (the note in the pairs file says why).
EXPECTED_B_FIELDS = {
    "surgery_assault": {"under_agreement", "informed", "volition"},
    "placebo_drug": {"contribution"},
    "boycott_chance": {"volition", "contribution"},
    "lottery_earned": {"contribution", "volition"},
    "decisive_vote": {"responsibility"},
    "donation_coerced": {"volition"},
    "informed_pharmacist": {"informed"},
    "acting_for": {"acting_for"},
}
STOP = frozenset("a an the for of to and in on at with by his her their its is are as while".split())


def _mean(xs):
    xs = [x for x in xs if not (isinstance(x, float) and math.isnan(x))]
    return sum(xs) / len(xs) if xs else float("nan")


# ---- primitives ----
def krippendorff_alpha_interval(units):
    """Interval alpha over units (lists of the numbers the coders gave). Units with fewer than two values are not
    pairable; a constant value everywhere gives 1.0; no pairable unit gives nan."""
    units = [u for u in units if len(u) >= 2]
    if not units:
        return float("nan")
    n = sum(len(u) for u in units)
    d_o = sum(2 * (len(u) * sum(v * v for v in u) - sum(u) ** 2) / (len(u) - 1) for u in units) / n
    allv = [v for u in units for v in u]
    d_e = 2 * (n * sum(v * v for v in allv) - sum(allv) ** 2) / (n * (n - 1))
    return 1.0 if d_e == 0 else 1.0 - d_o / d_e


def _ranks(xs):
    order = sorted(range(len(xs)), key=lambda i: xs[i])
    ranks, i = [0.0] * len(xs), 0
    while i < len(order):
        j = i
        while j + 1 < len(order) and xs[order[j + 1]] == xs[order[i]]:
            j += 1
        for k in range(i, j + 1):
            ranks[order[k]] = (i + j) / 2 + 1
        i = j + 1
    return ranks


def spearman(xs, ys):
    """Rank correlation with average ranks for ties; nan when either side is constant or too short."""
    if len(xs) != len(ys) or len(xs) < 2:
        return float("nan")
    rx, ry = _ranks(xs), _ranks(ys)
    mx, my = sum(rx) / len(rx), sum(ry) / len(ry)
    sx = math.sqrt(sum((a - mx) ** 2 for a in rx))
    sy = math.sqrt(sum((b - my) ** 2 for b in ry))
    if sx == 0 or sy == 0:
        return float("nan")
    return sum((a - mx) * (b - my) for a, b in zip(rx, ry)) / (sx * sy)


def _norm_text(s):
    return re.sub(r"\s+", " ", s.strip().lower()) if isinstance(s, str) else None


# ---- loading ----
def load_bd_records(paths):
    """{"participation": [...], "events": [...]} from answers files, each read with the batch file beside it (same
    name without `.answers`), which gives the item behind each task. A missing batch is an error."""
    out = {"participation": [], "events": []}
    for p in map(Path, paths):
        batch = p.with_name(p.name.replace(".answers.jsonl", ".jsonl"))
        if batch == p or not batch.exists():
            raise FileNotFoundError(f"no batch file for answers {p} (expected {batch})")
        lines = batch.read_text(encoding="utf-8").splitlines()
        tt = json.loads(lines[0])["task_type"]
        if tt not in out:
            raise ValueError(f"{batch}: task type {tt!r} is not a participation or events battery")
        item_of = {json.loads(l)["task_id"]: json.loads(l)["input"]["item"]["id"] for l in lines[1:]}
        for l in p.read_text(encoding="utf-8").splitlines():
            if not l.strip():
                continue
            a = json.loads(l)
            r = {"item": item_of[a["task_id"]], "variant": a["variant"], "model": a.get("model"),
                 "prompt_version": a.get("prompt_version")}
            if tt == "participation":
                r["participants"] = {e["id"]: e for e in a["participants"]}
            else:
                r["subevents"] = a["subevents"]
                r["links"] = a["event_links"]
            out[tt].append(r)
    return out


# ---- participation ----
def _net_impact(e):
    return sum(i["sign"] * i["magnitude"] for i in e["impact"])


def _present(x):
    return "record" if x else NULL


FIELD_VALUE = {
    "contribution": ("interval", lambda e: e["contribution"]),
    "responsibility": ("interval", lambda e: e["responsibility"]),
    "impact_net": ("interval", _net_impact),
    "production": ("nominal", lambda e: e["production"] or NULL),
    "volition": ("nominal", lambda e: e["volition"] or NULL),
    "acting_for": ("nominal", lambda e: _norm_text(e["acting_for"]) or NULL),
    "informed": ("nominal", lambda e: _present(e["informed"])),
    "under_agreement": ("nominal", lambda e: _present(e["under_agreement"])),
}
NULL_TEST = {"contribution": None, "responsibility": None, "impact_net": None,
             "production": lambda e: e["production"] is None, "volition": lambda e: e["volition"] is None,
             "acting_for": lambda e: e["acting_for"] is None, "informed": lambda e: e["informed"] is None,
             "under_agreement": lambda e: e["under_agreement"] is None}


def _units(records):
    """{(item, participant id): [entry per variant, in record order]}."""
    units = defaultdict(list)
    for r in records:
        for pid, e in r["participants"].items():
            units[(r["item"], pid)].append((r["variant"], e))
    return units


def _spearman_over_variants(units):
    by_pair = defaultdict(lambda: ([], []))
    for entries in units.values():
        vals = dict(entries)
        for a, b in itertools.combinations(sorted(vals), 2):
            xs, ys = by_pair[(a, b)]
            xs.append(vals[a]["contribution"])
            ys.append(vals[b]["contribution"])
    return _mean(spearman(xs, ys) for xs, ys in by_pair.values())


def conservation(records):
    sums = [math.fsum(e["contribution"] for e in r["participants"].values()) for r in records]
    bad = sum(s > 1 + CONSERVATION_TOL for s in sums)
    return {"answers": len(sums), "violations": bad, "rate": bad / len(sums) if sums else float("nan"),
            "max_sum": max(sums) if sums else float("nan")}


def overdetermination(records, items):
    by_id = {i["id"]: i for i in items}
    rows, per_item, meets = [], defaultdict(list), []
    for r in records:
        exp = by_id.get(r["item"], {}).get("expect")
        if not exp:
            continue
        es = [r["participants"][p] for p in exp["participants"] if p in r["participants"]]
        if not es:
            continue
        ok = all(e["contribution"] <= exp["contribution_max"] and e["responsibility"] >= exp["responsibility_min"] for e in es)
        meets.append(ok)
        per_item[r["item"]].append(ok)
        rows += [(e["contribution"], e["responsibility"]) for e in es]
    return {"items": len(per_item), "answers": len(meets),
            "pattern_rate": sum(meets) / len(meets) if meets else float("nan"),
            "mean_contribution": _mean(c for c, _ in rows), "mean_responsibility": _mean(r for _, r in rows),
            "mean_divergence": _mean(r - c for c, r in rows),
            "by_item": {i: sum(v) / len(v) for i, v in sorted(per_item.items())}}


def _signature_value(field, e):
    if field in ("contribution", "responsibility"):
        return f"{round(e[field] * 4) / 4:.2f}"
    if field == "impact_sign":
        n = _net_impact(e)
        return str((n > 0) - (n < 0))
    return FIELD_VALUE[field][1](e)


def _majority(values):
    votes = defaultdict(int)
    for v in values:
        votes[v] += 1
    return min(votes, key=lambda v: (-votes[v], v))


def _annotation(records, item):
    """{participant id: {field: majority value over the item's variants}}."""
    vals = defaultdict(lambda: defaultdict(list))
    for r in records:
        if r["item"] == item:
            for pid, e in r["participants"].items():
                for f in SIGNATURE_FIELDS:
                    vals[pid][f].append(_signature_value(f, e))
    return {pid: {f: _majority(v) for f, v in fs.items()} for pid, fs in vals.items()}


def collisions_b(records, items, pairs):
    """Collision over minimal pairs marked B (see the module docstring); pairs with no answers for a side, or no
    participant listed in both, are skipped."""
    by_pair = {(i["pair"], i["side"]): i["id"] for i in items if "pair" in i}
    have = {r["item"] for r in records}
    n = identical = 0
    differs = defaultdict(int)
    hit = hit_n = 0
    for p in pairs:
        if p["should_differ_in"] != "B":
            continue
        a, b = by_pair.get((p["id"], "a")), by_pair.get((p["id"], "b"))
        if a not in have or b not in have:
            continue
        ann_a, ann_b = _annotation(records, a), _annotation(records, b)
        common = sorted(set(ann_a) & set(ann_b))
        if not common:
            continue
        diff = {f for f in SIGNATURE_FIELDS if any(ann_a[pid][f] != ann_b[pid][f] for pid in common)}
        n += 1
        identical += not diff
        for f in diff:
            differs[f] += 1
        if p["id"] in EXPECTED_B_FIELDS:
            hit_n += 1
            hit += bool(diff & EXPECTED_B_FIELDS[p["id"]])
    return {"pairs": n, "identical": identical, "rate": identical / n if n else float("nan"),
            "field_differs": {f: differs[f] / n if n else float("nan") for f in SIGNATURE_FIELDS},
            "expected_hit": {"pairs": hit_n, "hit": hit, "rate": hit / hit_n if hit_n else float("nan")}}


def participation_metrics(records, items, pairs=None):
    units = _units(records)
    out = {"answers": len(records), "items": len({r["item"] for r in records}), "fields": {}}
    entries = [e for r in records for e in r["participants"].values()]
    for f, (kind, get) in FIELD_VALUE.items():
        vals = [[get(e) for _, e in es] for es in units.values()]
        alpha = krippendorff_alpha_interval(vals) if kind == "interval" else krippendorff_alpha_nominal(vals)
        test = NULL_TEST[f]
        out["fields"][f] = {"kind": kind, "alpha": alpha,
                            "null_rate": (sum(test(e) for e in entries) / len(entries) if entries else float("nan"))
                            if test else None}
    parties = [[{_norm_text(i["party"]) for i in e["impact"]} for _, e in es] for es in units.values()]
    out["impact_party_jaccard"] = _mean(jaccard(a, b) for ps in parties for a, b in itertools.combinations(ps, 2))
    out["impact_empty_rate"] = sum(not e["impact"] for e in entries) / len(entries) if entries else float("nan")
    out["contribution_spearman"] = _spearman_over_variants(units)
    out["conservation"] = conservation(records)
    out["overdetermination"] = overdetermination(records, items)
    if pairs is not None:
        out["collisions"] = collisions_b(records, items, pairs)
    return out


# ---- events ----
def tokens(label):
    """Normalised content tokens of a sub-event label: lower case, stop words dropped, light stemming."""
    out = set()
    for w in re.findall(r"[a-z0-9]+", label.lower()):
        if w in STOP:
            continue
        if len(w) > 4 and w.endswith("ing"):
            w = w[:-3]
            if len(w) > 2 and w[-1] == w[-2] and w[-1] not in "aeiou":
                w = w[:-1]
        elif len(w) > 3 and w.endswith("ies"):
            w = w[:-3] + "y"
        elif len(w) > 3 and w.endswith("ed"):
            w = w[:-2]
        elif len(w) > 2 and w.endswith("s") and not w.endswith("ss"):
            w = w[:-1]
        out.add(w)
    return out


def match_subevents(a_labels, b_labels, threshold=MATCH_THRESHOLD):
    """One-to-one matches [(i, j)] between two label lists: overlap coefficient of the normalised token sets at
    least `threshold`, best first (ties to the lower indices)."""
    ta, tb = [tokens(l) for l in a_labels], [tokens(l) for l in b_labels]
    cands = []
    for i, x in enumerate(ta):
        for j, y in enumerate(tb):
            if x and y:
                s = len(x & y) / min(len(x), len(y))
                if s >= threshold:
                    cands.append((-s, i, j))
    used_a, used_b, out = set(), set(), []
    for _, i, j in sorted(cands):
        if i not in used_a and j not in used_b:
            used_a.add(i)
            used_b.add(j)
            out.append((i, j))
    return sorted(out)


def link_label(record, x, y):
    """The links between sub-events x and y (indices into record's list), oriented from x to y: `none`, or the
    types joined with `+` (`type^-1` where a directed link points from y to x)."""
    ids = [s["id"] for s in record["subevents"]]
    ix, iy = ids[x], ids[y]
    labels = set()
    for l in record["links"]:
        if (l["from"], l["to"]) == (ix, iy) or (l["from"], l["to"]) == (iy, ix):
            forward = l["from"] == ix
            labels.add(l["type"] if forward or l["type"] in SYMMETRIC else l["type"] + "^-1")
    return "+".join(sorted(labels)) or "none"


def d_pairs(records, items, pairs):
    by_pair = {(i["pair"], i["side"]): i["id"] for i in items if "pair" in i}
    counts = defaultdict(list)
    for r in records:
        counts[r["item"]].append(len(r["subevents"]))
    n = more = 0
    for p in pairs:
        if p["should_differ_in"] != "D":
            continue
        a, b = by_pair.get((p["id"], "a")), by_pair.get((p["id"], "b"))
        if a in counts and b in counts:
            n += 1
            more += sum(counts[a]) / len(counts[a]) > sum(counts[b]) / len(counts[b])
    return {"pairs": n, "richer_has_more": more, "rate": more / n if n else float("nan")}


def events_metrics(records, items, pairs=None):
    by_item = defaultdict(list)
    for r in records:
        by_item[r["item"]].append(r)
    counts = [[len(r["subevents"]) for r in rs] for rs in by_item.values()]
    units = []
    for rs in by_item.values():
        for a, b in itertools.combinations(rs, 2):
            m = match_subevents([s["label"] for s in a["subevents"]], [s["label"] for s in b["subevents"]])
            for (i1, j1), (i2, j2) in itertools.combinations(m, 2):
                units.append([link_label(a, i1, i2), link_label(b, j1, j2)])
    linked = [u for u in units if u != ["none", "none"]]
    out = {"answers": len(records), "items": len(by_item),
           "n_subevents": {"alpha": krippendorff_alpha_interval(counts), "mean": _mean(c for cs in counts for c in cs)},
           "link_agreement": {"alpha": krippendorff_alpha_nominal(units), "matched_pairs": len(units),
                              "linked_pairs": len(linked),
                              "linked_agree": sum(u[0] == u[1] for u in linked) / len(linked) if linked else float("nan")},
           "link_usage": {t: (sum(any(l["type"] == t for r in rs for l in r["links"]) for rs in by_item.values())
                              / len(by_item) if by_item else float("nan")) for t in LINK_TYPES}}
    if pairs is not None:
        out["d_pairs"] = d_pairs(records, items, pairs)
    return out


def compute(records, items, pairs=None):
    """Metrics per battery that has records: {"participation": ..., "events": ...}."""
    out = {}
    if records.get("participation"):
        out["participation"] = participation_metrics(records["participation"], items, pairs)
    if records.get("events"):
        out["events"] = events_metrics(records["events"], items, pairs)
    return out


# ---- report ----
def _f(x, pct=False):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "n/a"
    return f"{x:.1%}" if pct else f"{x:.2f}"


def render(metrics):
    lines = []
    p = metrics.get("participation")
    if p:
        lines += [f"## Layer B: participation ({p['answers']} answers, {p['items']} items)", "",
                  "Agreement per field (alpha: interval for numbers, nominal for categories; variants are coders):", "",
                  "| field | kind | alpha | null rate |", "|---|---|---|---|"]
        for f, x in p["fields"].items():
            lines.append(f"| {f} | {x['kind']} | {_f(x['alpha'])} | {_f(x['null_rate'], True)} |")
        lines += ["", f"Contribution Spearman (mean over variant pairs): {_f(p['contribution_spearman'])}. "
                  f"Impact party Jaccard: {_f(p['impact_party_jaccard'])}. Empty impact lists: {_f(p['impact_empty_rate'], True)}.",
                  ""]
        c = p["conservation"]
        lines += [f"Conservation violations (contributions to one outcome summing above 1): {c['violations']} of "
                  f"{c['answers']} answers ({_f(c['rate'], True)}); largest sum {_f(c['max_sum'])}.", ""]
        o = p["overdetermination"]
        lines += [f"Overdetermination ({o['items']} items): pattern met in {_f(o['pattern_rate'], True)} of "
                  f"{o['answers']} answers; mean contribution {_f(o['mean_contribution'])}, mean responsibility "
                  f"{_f(o['mean_responsibility'])}, mean divergence (responsibility minus contribution) "
                  f"{_f(o['mean_divergence'])}.", ""]
        if o["by_item"]:
            lines += ["| item | pattern met |", "|---|---|"]
            lines += [f"| {i} | {_f(v, True)} |" for i, v in o["by_item"].items()]
            lines.append("")
        col = p.get("collisions")
        if col:
            e = col["expected_hit"]
            lines += [f"Collision rate on B minimal pairs: {col['identical']} of {col['pairs']} pairs have identical "
                      f"B annotations ({_f(col['rate'], True)}; should be low). Differing in an expected field: "
                      f"{e['hit']} of {e['pairs']} ({_f(e['rate'], True)}).", "",
                      "| field | pairs differing |", "|---|---|"]
            lines += [f"| {f} | {_f(v, True)} |" for f, v in col["field_differs"].items()]
            lines.append("")
    e = metrics.get("events")
    if e:
        a, l = e["n_subevents"], e["link_agreement"]
        lines += [f"## Layer D: event links ({e['answers']} answers, {e['items']} items)", "",
                  f"Number of sub-events: interval alpha {_f(a['alpha'])}, mean {_f(a['mean'])}.", "",
                  f"Link-type agreement over {l['matched_pairs']} matched sub-event pairs: nominal alpha "
                  f"{_f(l['alpha'])}; among {l['linked_pairs']} pairs linked in either variant, identical label "
                  f"{_f(l['linked_agree'], True)}.", "",
                  "Share of scenarios where any variant uses each link type:", "", "| link type | share |", "|---|---|"]
        lines += [f"| {t} | {_f(v, True)} |" for t, v in e["link_usage"].items()]
        d = e.get("d_pairs")
        if d:
            lines += ["", f"D minimal pairs: the richer text gets more sub-events in {d['richer_has_more']} of "
                      f"{d['pairs']} pairs ({_f(d['rate'], True)})."]
    return "\n".join(lines) + "\n"
