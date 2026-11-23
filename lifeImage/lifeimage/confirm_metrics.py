"""Metrics of the confirming battery on the combined answers: A, B and D by the layer metrics the earlier batteries
use (`membership_metrics.vocab_metrics` and `collisions`, `bd_metrics.participation_metrics` and `events_metrics`),
plus two measures this battery adds.

- production: on the consumed-versus-produced pairs (items of source `production_pair`, one focal participant with
  an expected value each), the share of focal answers equal to the expected value (`match_rate`; null is never a
  match and is counted apart in `null_rate`), the same per expected value, and `pairs_separated`: pairs whose two
  texts get different non-null majority productions for the focal participant. A runner that says `produced` for
  everything matches half the answers and separates no pair.
- outcome: whether the A outcome type is filled where the text states or implies a counterfactual (items marked
  `counterfactual`, split by `expected_outcome`: change or null) against plain events (source `a_pool`). For each
  group `fill_rate` is the share of answers with a non-null outcome, `item_fill_rate` the share of items whose
  strict majority of variants fill it, `items` the count; `agreement_with_expectation` is the share of
  counterfactual items whose majority-filled status equals the expectation (change: filled, null: not filled). A
  runner that always fills the outcome matches only the change items; one that never fills it only the null items.
"""
import math
from collections import defaultdict

from .bd_metrics import (FIELD_VALUE, _units, events_metrics, krippendorff_alpha_interval, krippendorff_alpha_nominal,
                         participation_metrics, render as render_bd)
from .confirm import VOCAB, zero_run_flag
from .confirm_rerun import COERCED
from .membership import VOCABS
from .participation import production_gaps
from .membership_metrics import collisions, render as render_a, vocab_metrics


def _majority(values):
    votes = defaultdict(int)
    for v in values:
        votes[v] += 1
    return min(votes, key=lambda v: (-votes[v], str(v)))


def production_metrics(records, items):
    """See the module docstring. records: participation records (`load_confirm_records`)."""
    focal = {}  # item id -> (participant id, expected production)
    pairs = defaultdict(dict)
    for i in items:
        if i.get("source") == "production_pair":
            (pid, exp), = i["expect_production"].items()
            focal[i["id"]] = (pid, exp)
            pairs[i["pair"]][i["side"]] = i["id"]
    said = defaultdict(list)
    for r in records:
        if r["item"] in focal and focal[r["item"]][0] in r["participants"]:
            said[r["item"]].append(r["participants"][focal[r["item"]][0]]["production"])
    answers = [(focal[i][1], p) for i, ps in said.items() for p in ps]
    by_expected = {}
    for exp in sorted({e for e, _ in answers}):
        mine = [p for e, p in answers if e == exp]
        by_expected[exp] = {"answers": len(mine), "match_rate": sum(p == exp for p in mine) / len(mine)}
    separated = n_pairs = 0
    for sides in pairs.values():
        if all(s in said for s in sides.values()) and len(sides) == 2:
            n_pairs += 1
            a, b = (_majority(said[sides[s]]) for s in ("a", "b"))
            separated += a is not None and b is not None and a != b
    n = len(answers)
    return {"answers": n, "pairs": n_pairs, "pairs_separated": separated, "by_expected": by_expected,
            "match_rate": sum(p == e for e, p in answers) / n if n else float("nan"),
            "null_rate": sum(p is None for _, p in answers) / n if n else float("nan")}


def outcome_metrics(records, items):
    """See the module docstring. records: A records (`load_confirm_records`)."""
    group_of = {}
    expected = {}
    for i in items:
        if i.get("source") == "counterfactual":
            group_of[i["id"]] = i["expected_outcome"]
            expected[i["id"]] = i["expected_outcome"] == "change"
        elif i.get("source") == "a_pool":
            group_of[i["id"]] = "plain"
    filled = defaultdict(list)
    for r in records:
        if r["item"] in group_of:
            filled[r["item"]].append(r["types"]["outcome"] is not None)
    out = {}
    for g in ("change", "null", "plain"):
        ids = [i for i in filled if group_of[i] == g]
        answers = [x for i in ids for x in filled[i]]
        out[g] = {"items": len(ids), "answers": len(answers),
                  "fill_rate": sum(answers) / len(answers) if answers else float("nan"),
                  "item_fill_rate": (sum(2 * sum(filled[i]) > len(filled[i]) for i in ids) / len(ids)
                                     if ids else float("nan"))}
    cf = [i for i in filled if i in expected]
    out["agreement_with_expectation"] = (sum((2 * sum(filled[i]) > len(filled[i])) == expected[i] for i in cf) / len(cf)
                                         if cf else float("nan"))
    return out


def compute_confirm(records, items, pairs=None):
    """{"A": ..., "B": ..., "D": ..., "production": ..., "outcome": ...} over the combined answers. `items` are the
    confirm items (with their expectations); `pairs` the minimal pairs, of which those whose two texts are both in
    `items` add the collision rates (A, B) and the D richness check."""
    types = VOCABS[VOCAB]["types"]
    out = {"A": vocab_metrics(records["A"], types)}
    bd_pairs = None
    if pairs is not None:
        have = {i["text"].strip().lower() for i in items}
        bd_pairs = [p for p in pairs if p["a"].strip().lower() in have and p["b"].strip().lower() in have]
        out["A"]["collisions"] = collisions(records["A"], bd_pairs, items, types)
    out["B"] = participation_metrics(records["participation"], items, bd_pairs)
    out["D"] = events_metrics(records["events"], items, bd_pairs)
    out["production"] = production_metrics(records["participation"], items)
    out["outcome"] = outcome_metrics(records["A"], items)
    return out


def _f(x, pct=False):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "n/a"
    return f"{x:.1%}" if pct else f"{x:.2f}"


def render_confirm(m):
    """Markdown report: layer A, B and D as the earlier batteries print them, then production and outcome."""
    a = dict(m["A"])
    lines = ["## Layer A: membership (A3S)", "", render_a({VOCAB: a})]
    lines.append(render_bd({"participation": m["B"], "events": m["D"]}))
    p = m["production"]
    lines += ["## Production on consumed-versus-produced pairs", "",
              f"Focal answers equal to the expected value: {_f(p['match_rate'], True)} over {p['answers']} answers; "
              f"null {_f(p['null_rate'], True)}. Pairs whose two texts get different non-null productions: "
              f"{p['pairs_separated']} of {p['pairs']}.", "", "| expected | answers | match rate |", "|---|---|---|"]
    lines += [f"| {e} | {x['answers']} | {_f(x['match_rate'], True)} |" for e, x in p["by_expected"].items()]
    o = m["outcome"]
    lines += ["", "## Outcome against the counterfactual", "",
              "| group | items | answers | outcome filled | items filled by majority |", "|---|---|---|---|---|"]
    lines += [f"| {g} | {o[g]['items']} | {o[g]['answers']} | {_f(o[g]['fill_rate'], True)} | "
              f"{_f(o[g]['item_fill_rate'], True)} |" for g in ("change", "null", "plain")]
    lines += ["", f"Counterfactual items matching the expectation (change: filled, null: not filled): "
              f"{_f(o['agreement_with_expectation'], True)}."]
    return "\n".join(lines) + "\n"


# ---- confirm v1 versus v2 on the same items ----
def _mean(xs):
    xs = list(xs)
    return sum(xs) / len(xs) if xs else float("nan")


def _only(rec, ids):
    return {k: [r for r in v if r["item"] in ids] for k, v in rec.items()}


def _field_alphas(participation):
    units = _units(participation)
    out = {}
    for f, (kind, get) in FIELD_VALUE.items():
        vals = [[get(e) for _, e in es] for es in units.values()]
        out[f] = (krippendorff_alpha_interval if kind == "interval" else krippendorff_alpha_nominal)(vals)
    return out


def _focal_mean(participation, focal):
    """Mean responsibility of each item's focal participant over its answers; per item, then over items."""
    per_item = []
    for item, pid in focal.items():
        vals = [r["participants"][pid]["responsibility"] for r in participation
                if r["item"] == item and pid in r["participants"]]
        if vals:
            per_item.append(_mean(vals))
    return _mean(per_item), len(per_item)


def compare_versions(v1, v2, items, ids):
    """confirm v1 against v2 on the same items. `v1`, `v2`: records (`load_confirm_records`); `items`: the rerun items
    (`confirm_rerun.rerun_items`); `ids`: the item ids of the rerun set. Everything but the self-defence rows is
    computed over the items both versions answered (`items` in the result counts them), so the two columns see the
    same items. Returns
    - fields: Krippendorff alpha per participation field, {field: {v1, v2}}, and a_types the same per A type;
    - zero_run: answers, and those flagged (outcome recorded, every participant 0 and 0), per version;
    - production: participant answers where production is required (contribution above 0, or the output received),
      and how many of those are null, per version;
    - responsibility: mean responsibility of the coerced participant (`COERCED`) per version, and of the defender per
      self-defence case (every item of the case that a version answered; v1 has none, so its column is nan).
    """
    ids = set(ids)
    common = ({r["item"] for r in v1["participation"]} & {r["item"] for r in v2["participation"]}) & ids
    one, two = _only(v1, common), _only(v2, common)
    types = VOCABS[VOCAB]["types"]
    out = {"items": len(common), "fields": {}, "a_types": {}, "zero_run": {"answers": {}, "flagged": {}},
           "production": {}, "responsibility": {}}
    fa, fb = _field_alphas(one["participation"]), _field_alphas(two["participation"])
    out["fields"] = {f: {"v1": fa[f], "v2": fb[f]} for f in fa}
    if common:
        ta, tb = vocab_metrics(one["A"], types)["types"], vocab_metrics(two["A"], types)["types"]
        out["a_types"] = {t: {"v1": ta[t]["alpha"], "v2": tb[t]["alpha"]} for t in ta}
    for name, rec in (("v1", one), ("v2", two)):
        by_key = {(r["item"], r["variant"]): r for r in rec["participation"]}
        flagged = n = 0
        for a in rec["A"]:
            p = by_key.get((a["item"], a["variant"]))
            if p is not None:
                n += 1
                flagged += zero_run_flag({"types": a["types"], "participants": list(p["participants"].values())})
        out["zero_run"]["answers"][name], out["zero_run"]["flagged"][name] = n, flagged
        gaps = required = 0
        for r in rec["participation"]:
            es = list(r["participants"].values())
            missing = set(production_gaps(es))
            gaps += len(missing)
            receivers = {i["party"] for e in es for i in e["impact"] if i["sign"] == 1 and i["magnitude"] > 0}
            required += sum(e["contribution"] > 0 or e["id"] in receivers for e in es)
        out["production"][name] = {"required": required, "null": gaps}
    coerced = {i: p for i, p in COERCED.items() if i in common}
    c1, n1 = _focal_mean(one["participation"], coerced)
    c2, n2 = _focal_mean(two["participation"], coerced)
    cases = {}
    for it in items:
        if it.get("source") == "self_defence" and it["id"] in ids:
            cases.setdefault(it["case"], {})[it["id"]] = "defender"
    sd = {}
    for case, focal in cases.items():
        sd[case] = {"v1": _focal_mean(v1["participation"], focal)[0], "v2": _focal_mean(v2["participation"], focal)[0]}
    out["responsibility"] = {"coercion": {"v1": c1, "v2": c2, "items": max(n1, n2)}, "self_defence": sd}
    return out


def render_compare(c):
    """Markdown report of `compare_versions`."""
    lines = [f"## confirm v1 versus v2 on the same {c['items']} items", "", "### Agreement per field (Krippendorff alpha over variants)", "",
             "| field | v1 | v2 |", "|---|---|---|"]
    lines += [f"| {f} | {_f(x['v1'])} | {_f(x['v2'])} |" for f, x in c["fields"].items()]
    lines += [f"| A: {t} | {_f(x['v1'])} | {_f(x['v2'])} |" for t, x in c["a_types"].items()]
    z = c["zero_run"]
    lines += ["", "### Zero runs (outcome recorded, every participant 0 and 0)", "", "| | v1 | v2 |", "|---|---|---|",
              f"| flagged | {z['flagged']['v1']} of {z['answers']['v1']} | {z['flagged']['v2']} of {z['answers']['v2']} |"]
    p = c["production"]
    lines += ["", "### Production nulls where production is required", "", "| | v1 | v2 |", "|---|---|---|",
              f"| null of required | {p['v1']['null']} of {p['v1']['required']} | {p['v2']['null']} of {p['v2']['required']} |"]
    r = c["responsibility"]
    lines += ["", "### Responsibility on coercion and self-defence items (mean over answers)", "",
              "| items | v1 | v2 |", "|---|---|---|",
              f"| coerced participant ({r['coercion']['items']} items) | {_f(r['coercion']['v1'])} | {_f(r['coercion']['v2'])} |"]
    lines += [f"| self-defence: {k} defender | {_f(x['v1'])} | {_f(x['v2'])} |" for k, x in sorted(r["self_defence"].items())]
    return "\n".join(lines) + "\n"
