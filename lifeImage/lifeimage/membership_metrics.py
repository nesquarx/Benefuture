"""Metrics of the membership battery (layer A): how candidate vocabularies behave over k variants.

Definitions (stated, because "forced" is easy to read two ways):
- other rate: share of answers whose `other` is not null (a relation the vocabulary could not express).
- forced rate: share of answers that filled every type and named no other, i.e. that put the event into every
  type of the vocabulary and declined nothing.
- applicability: per type, share of answers where the type is not null.
- agreement: per type, Krippendorff's alpha (nominal) over items with the variants as coders, on the top domain
  (heaviest weight, ties to the lowest id; null is its own category), and the mean Jaccard of the variants'
  domain sets over variant pairs (null is the empty set).
- confusion: per unordered pair of types, the share of items where some variant puts a domain under one type and
  another variant puts that same domain under the other type, with neither variant having it under both (a swap).
- red-team other share: the share of answers to red-team items (ids `rt.*`) that used `other`.

Battery v2 additions:
- weighted Jaccard: per type, the mean over items and variant pairs of sum(min) / sum(max) of the two weight maps
  (null is the empty map; two empty maps agree fully). It sees weight shifts that top-domain alpha ignores.
- null rate: per type, 1 - applicability.
- placebo noise floor: the type `flavour` (meaningless by design) is reported apart (fill rate, alpha, Jaccard) and
  left out of every vocabulary mean (`mean_alpha`, `mean_jaccard`, `mean_weighted_jaccard`, `forced_rate`). A real
  type whose alpha does not clear the placebo's measures lexical anchoring, not meaning.
- collision rate: over minimal pairs whose `should_differ_in` is "A", the share whose two texts get identical
  A-annotations (the majority top domain of every non-placebo type, null a category). Pairs marked otherwise are
  reported apart, where identical is expected. A pairs are also split by the type expected to differ.
- round-trip accuracy: see `lifeimage.roundtrip` (the share of items whose annotation identifies the original).
"""
import itertools
import json
import math
from collections import defaultdict
from pathlib import Path

from .links import jaccard as _jaccard
from .membership import PLACEBO, VOCABS, pair_item_ids

NULL = "<null>"


def is_redteam(item):
    return item.startswith("rt.")


def jaccard(a, b):
    return _jaccard(a, b)


def weighted_jaccard(a, b):
    """Sum of mins over sum of maxes of two weight maps (None or empty is the empty map; both empty is 1)."""
    a, b = a or {}, b or {}
    keys = set(a) | set(b)
    hi = sum(max(a.get(k, 0.0), b.get(k, 0.0)) for k in keys)
    return 1.0 if hi == 0 else sum(min(a.get(k, 0.0), b.get(k, 0.0)) for k in keys) / hi


def top_domain(weights):
    return min(weights, key=lambda d: (-weights[d], d)) if weights else None


def krippendorff_alpha_nominal(units):
    """units: lists of the values the coders gave one unit. Units with fewer than two values are not pairable.
    A single category everywhere gives 1.0 (no disagreement to explain); no pairable unit gives nan."""
    units = [u for u in units if len(u) >= 2]
    if not units:
        return float("nan")
    coin = defaultdict(float)
    for u in units:
        for a, b in itertools.permutations(range(len(u)), 2):
            coin[(u[a], u[b])] += 1 / (len(u) - 1)
    totals = defaultdict(float)
    for (c, _), w in coin.items():
        totals[c] += w
    n = sum(totals.values())
    d_o = sum(w for (c, k), w in coin.items() if c != k) / n
    d_e = sum(totals[c] * totals[k] for c in totals for k in totals if c != k) / (n * (n - 1))
    return 1.0 if d_e == 0 else 1.0 - d_o / d_e


def _by_item(records):
    items = defaultdict(list)
    for r in records:
        items[r["item"]].append(r)
    return items


def _mean(xs):
    xs = [x for x in xs if not (isinstance(x, float) and math.isnan(x))]
    return sum(xs) / len(xs) if xs else float("nan")


def vocab_metrics(records, types, placebo=PLACEBO):
    real = [t for t in types if t != placebo]
    n = len(records)
    items = _by_item(records)
    red = [r for r in records if is_redteam(r["item"])]
    out = {
        "answers": n, "items": len(items),
        "other_rate": sum(r["other"] is not None for r in records) / n,
        "forced_rate": sum(all(r["types"][t] is not None for t in real) and r["other"] is None for r in records) / n,
        "redteam_other": sum(r["other"] is not None for r in red) / len(red) if red else None,
        "types": {}, "confusion": {},
    }
    for t in types:
        units = [[top_domain(r["types"][t]) or NULL for r in rs] for rs in items.values()]
        js = [_jaccard(set(x["types"][t] or ()), set(y["types"][t] or ()))
              for rs in items.values() for x, y in itertools.combinations(rs, 2)]
        wjs = [weighted_jaccard(x["types"][t], y["types"][t])
               for rs in items.values() for x, y in itertools.combinations(rs, 2)]
        app = sum(r["types"][t] is not None for r in records) / n
        out["types"][t] = {"applicability": app, "null_rate": 1 - app,
                           "alpha": krippendorff_alpha_nominal(units),
                           "jaccard": sum(js) / len(js) if js else float("nan"),
                           "weighted_jaccard": sum(wjs) / len(wjs) if wjs else float("nan")}
    out["mean_alpha"] = _mean(out["types"][t]["alpha"] for t in real)
    out["mean_jaccard"] = _mean(out["types"][t]["jaccard"] for t in real)
    out["mean_weighted_jaccard"] = _mean(out["types"][t]["weighted_jaccard"] for t in real)
    out["placebo"] = ({"fill_rate": out["types"][placebo]["applicability"], "alpha": out["types"][placebo]["alpha"],
                       "jaccard": out["types"][placebo]["jaccard"],
                       "weighted_jaccard": out["types"][placebo]["weighted_jaccard"]} if placebo in types else None)
    for t in [t for t in types if t == placebo]:
        del out["types"][t]
    for t1, t2 in itertools.combinations(real, 2):
        hit = 0
        for rs in items.values():
            for a, b in itertools.permutations(rs, 2):
                s1a, s2a = set(a["types"][t1] or ()), set(a["types"][t2] or ())
                s1b, s2b = set(b["types"][t1] or ()), set(b["types"][t2] or ())
                if (s1a & s2b) - s2a - s1b:
                    hit += 1
                    break
        out["confusion"][(t1, t2)] = hit / len(items)
    return out


def majority_top(records, item, type_):
    """The plurality top domain of one type across the item's variants (null is a category; ties to the lowest)."""
    votes = defaultdict(int)
    for r in records:
        if r["item"] == item:
            votes[top_domain(r["types"][type_]) or NULL] += 1
    return min(votes, key=lambda v: (-votes[v], v)) if votes else None


def collisions(records, pairs, items, types, placebo=PLACEBO):
    """Collision metric over minimal pairs, for one vocabulary's records (see the module docstring).
    {"A": {...}, "A:<type>": {...}, "<other kind>": {...}}, each {"pairs", "identical", "rate"}; a pair is skipped
    when either text has no answers."""
    real = [t for t in types if t != placebo]
    have = {r["item"] for r in records}
    groups = defaultdict(lambda: [0, 0])
    for p in pairs:
        a, b = pair_item_ids(p, items)
        if a not in have or b not in have:
            continue
        same = all(majority_top(records, a, t) == majority_top(records, b, t) for t in real)
        keys = [p["should_differ_in"]] + ([f"A:{p['type']}"] if p["should_differ_in"] == "A" and p.get("type") else [])
        for k in keys:
            groups[k][0] += 1
            groups[k][1] += same
    return {k: {"pairs": n, "identical": c, "rate": c / n} for k, (n, c) in sorted(groups.items())}


def load_records(paths):
    """Records from answers files; each pairs with its batch file (same name without `.answers`) for the item id
    behind each input hash. A missing batch is an error: without it red-team items cannot be told apart."""
    records = []
    for p in map(Path, paths):
        batch = p.with_name(p.name.replace(".answers.jsonl", ".jsonl"))
        if batch == p or not batch.exists():
            raise FileNotFoundError(f"no batch file for answers {p} (expected {batch})")
        lines = batch.read_text(encoding="utf-8").splitlines()
        task_type = json.loads(lines[0])["task_type"]
        item_of = {}
        for l in lines[1:]:
            t = json.loads(l)
            item_of[t["task_id"]] = t["input"]["item"]["id"]
        for l in p.read_text(encoding="utf-8").splitlines():
            if not l.strip():
                continue
            a = json.loads(l)
            records.append({"vocab": task_type.split(".", 1)[1], "item": item_of[a["task_id"]],
                            "variant": a["variant"], "types": a["types"], "other": a.get("other"),
                            "model": a.get("model"), "prompt_version": a.get("prompt_version")})
    return records


def _f(x, pct=False):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "n/a"
    return f"{x:.1%}" if pct else f"{x:.2f}"


def render(metrics):
    """Markdown tables: one summary row per vocabulary, one row per (vocabulary, type), the placebo noise floor,
    the minimal-pair collisions (when computed) and the confusions."""
    lines = ["| vocabulary | answers | items | other rate | forced rate | red-team other | mean alpha | "
             "mean Jaccard | mean weighted Jaccard |", "|---|---|---|---|---|---|---|---|---|"]
    for v, r in sorted(metrics.items()):
        lines.append(f"| {v} | {r['answers']} | {r['items']} | {_f(r['other_rate'], True)} | "
                     f"{_f(r['forced_rate'], True)} | {_f(r['redteam_other'], True)} | {_f(r['mean_alpha'])} | "
                     f"{_f(r['mean_jaccard'])} | {_f(r['mean_weighted_jaccard'])} |")
    lines += ["", "| vocabulary | type | applicability | null rate | alpha (top domain) | mean Jaccard | "
              "weighted Jaccard |", "|---|---|---|---|---|---|---|"]
    for v, r in sorted(metrics.items()):
        for t, x in r["types"].items():
            lines.append(f"| {v} | {t} | {_f(x['applicability'], True)} | {_f(x['null_rate'], True)} | "
                         f"{_f(x['alpha'])} | {_f(x['jaccard'])} | {_f(x['weighted_jaccard'])} |")
    if any(r.get("placebo") for r in metrics.values()):
        lines += ["", "Placebo noise floor (type `flavour`, meaningless by design; excluded from the means):", "",
                  "| vocabulary | fill rate | alpha | mean Jaccard | weighted Jaccard |", "|---|---|---|---|---|"]
        for v, r in sorted(metrics.items()):
            if r.get("placebo"):
                x = r["placebo"]
                lines.append(f"| {v} | {_f(x['fill_rate'], True)} | {_f(x['alpha'])} | {_f(x['jaccard'])} | "
                             f"{_f(x['weighted_jaccard'])} |")
    if any(r.get("collisions") for r in metrics.values()):
        lines += ["", "Minimal pairs: share of pairs with identical A-annotations. For `A` (and `A:<type>`) this is "
                  "the collision rate, which should be low; for the other kinds identical is expected.", "",
                  "| vocabulary | pairs marked | pairs | identical | share |", "|---|---|---|---|---|"]
        for v, r in sorted(metrics.items()):
            for k, x in (r.get("collisions") or {}).items():
                lines.append(f"| {v} | {k} | {x['pairs']} | {x['identical']} | {_f(x['rate'], True)} |")
    lines += ["", "| vocabulary | type pair | items with a swap |", "|---|---|---|"]
    for v, r in sorted(metrics.items()):
        for (a, b), x in r["confusion"].items():
            lines.append(f"| {v} | {a} / {b} | {_f(x, True)} |")
    return "\n".join(lines) + "\n"


def compute(records, pairs=None, items=None):
    """Metrics per vocabulary. Records of one vocabulary from different models or prompt versions are kept apart
    (labelled `VOCAB [model]`); with `pairs` and `items` the collision metric is added."""
    groups = defaultdict(list)
    for r in records:
        groups[(r["vocab"], r.get("model"), r.get("prompt_version"))].append(r)
    n_groups = defaultdict(int)
    for v, _, _ in groups:
        n_groups[v] += 1
    out = {}
    for (v, model, _), rs in groups.items():
        label = v if n_groups[v] == 1 else f"{v} [{model}]"
        out[label] = vocab_metrics(rs, VOCABS[v]["types"])
        if pairs and items:
            out[label]["collisions"] = collisions(rs, pairs, items, VOCABS[v]["types"])
    return out
