"""LI.67: wide event memberships by a ranked stopping rule (prompt membership.v3, extract.v2)."""
import json
import statistics
from pathlib import Path

from lifeimage.eventgen.catalog import ALL
from lifeimage.validate import validate_answers

ROOT = Path(__file__).resolve().parent.parent
RELS = ("form", "content", "outcome", "setting")


# ---- the baseline the rule must beat (outcomes of the current code and data) ----
def test_baseline_current_catalog_memberships_are_narrow():
    med = {r: statistics.median(len(getattr(k, r)) for k in ALL) for r in RELS}
    assert med["form"] == 1 and med["setting"] == 1 and med["outcome"] == 2 and med["content"] <= 3, med


def test_baseline_pair_coverage_is_two_percent():
    s = json.loads((ROOT / "data" / "events" / "coverage_v1.json").read_text())["summary"]
    assert 0.020 <= s["share_pairs"] <= 0.022 and s["pairs_possible"] == 30381


# ---- red outcome: the current validator lets unranked, padded and early-stopped lists through ----
def _batch(prompt_version):
    header = {"kind": "header", "task_type": "membership.A3S", "model": "m", "prompt_version": prompt_version,
              "prefix": "x\n# coarse pack | basemap 0 | 3 domains | ~1 tokens\n"
                        "c.cooking | Cooking | x\nc.nutrition_diet | Diet | x\nc.sleep | Sleep | x\n"}
    task = {"kind": "task", "task_id": "t1-v0", "task_type": "membership.A3S", "prompt_version": prompt_version,
            "input_hash": "h" * 64, "variant": 0, "k": 2, "input": {"item": {"id": "i", "text": "Cooked a meal"}, "pack": "p"},
            "allowed_verdicts": ["membership"]}
    return [json.dumps(header), json.dumps(task)]


def _answer(prompt_version, form, ranks):
    types = {"form": form, "content": None, "outcome": None, "setting": None}
    return json.dumps({"task_id": "t1-v0", "task_type": "membership.A3S", "input_hash": "h" * 64, "variant": 0, "model": "m",
                       "prompt_version": prompt_version, "verdict": "membership", "reason": "r", "types": types, "other": None,
                       "ranks": {"form": ranks, "content": None, "outcome": None, "setting": None}})


def test_a_listed_domain_below_the_floor_is_rejected_at_v3():
    ranks = {"listed": [{"domain": "c.cooking", "fit": 9}, {"domain": "c.sleep", "fit": 1}],
             "rejected": {"domain": "c.nutrition_diet", "fit": 1}}
    errs = validate_answers(_batch(3), [_answer(3, {"c.cooking": 0.7, "c.sleep": 0.3}, ranks)])
    assert errs and any("floor" in e for e in errs), errs


def test_an_unranked_list_with_no_fit_record_is_rejected_at_v3():
    a = json.loads(_answer(3, {"c.cooking": 0.5, "c.sleep": 0.5}, None))
    a.pop("ranks")
    a["types"]["flavour"] = None  # the current vocabulary A3S still demands its placebo type
    errs = validate_answers(_batch(3), [json.dumps(a)])
    assert errs, "a v3 membership answer without its fit record was accepted"
