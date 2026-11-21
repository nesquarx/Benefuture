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
"""
import itertools
import json
import math
from collections import defaultdict
from pathlib import Path

from .links import jaccard as _jaccard
from .membership import VOCABS

NULL = "<null>"


def is_redteam(item):
    return item.startswith("rt.")


def jaccard(a, b):
    return _jaccard(a, b)


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


def vocab_metrics(records, types):
    n = len(records)
    items = _by_item(records)
    red = [r for r in records if is_redteam(r["item"])]
    out = {
        "answers": n, "items": len(items),
        "other_rate": sum(r["other"] is not None for r in records) / n,
        "forced_rate": sum(all(r["types"][t] is not None for t in types) and r["other"] is None for r in records) / n,
        "redteam_other": sum(r["other"] is not None for r in red) / len(red) if red else None,
        "types": {}, "confusion": {},
    }
    for t in types:
        units = [[top_domain(r["types"][t]) or NULL for r in rs] for rs in items.values()]
        js = [_jaccard(set(x["types"][t] or ()), set(y["types"][t] or ()))
              for rs in items.values() for x, y in itertools.combinations(rs, 2)]
        out["types"][t] = {"applicability": sum(r["types"][t] is not None for r in records) / n,
                           "alpha": krippendorff_alpha_nominal(units),
                           "jaccard": sum(js) / len(js) if js else float("nan")}
    for t1, t2 in itertools.combinations(types, 2):
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
                            "variant": a["variant"], "types": a["types"], "other": a.get("other")})
    return records


def _f(x, pct=False):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "n/a"
    return f"{x:.1%}" if pct else f"{x:.2f}"


def render(metrics):
    """Markdown tables: one summary row per vocabulary, one row per (vocabulary, type), and the confusions."""
    lines = ["| vocabulary | answers | items | other rate | forced rate | red-team other |", "|---|---|---|---|---|---|"]
    for v, r in sorted(metrics.items()):
        lines.append(f"| {v} | {r['answers']} | {r['items']} | {_f(r['other_rate'], True)} | "
                     f"{_f(r['forced_rate'], True)} | {_f(r['redteam_other'], True)} |")
    lines += ["", "| vocabulary | type | applicability | alpha (top domain) | mean Jaccard |", "|---|---|---|---|---|"]
    for v, r in sorted(metrics.items()):
        for t, x in r["types"].items():
            lines.append(f"| {v} | {t} | {_f(x['applicability'], True)} | {_f(x['alpha'])} | {_f(x['jaccard'])} |")
    lines += ["", "| vocabulary | type pair | items with a swap |", "|---|---|---|"]
    for v, r in sorted(metrics.items()):
        for (a, b), x in r["confusion"].items():
            lines.append(f"| {v} | {a} / {b} | {_f(x, True)} |")
    return "\n".join(lines) + "\n"


def compute(records):
    by_vocab = defaultdict(list)
    for r in records:
        by_vocab[r["vocab"]].append(r)
    return {v: vocab_metrics(rs, VOCABS[v]["types"]) for v, rs in by_vocab.items()}
