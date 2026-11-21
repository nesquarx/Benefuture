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

from .bd_metrics import events_metrics, participation_metrics, render as render_bd
from .confirm import VOCAB
from .membership import VOCABS
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
