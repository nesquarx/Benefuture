"""LI.70 baseline: what the one-pass membership and extraction code does today, the outcome two-pass extraction must beat. These
pass on the current code and stay true after it (the one-pass path is unchanged): the domain list is in the prefix, so a category
outside it can never be observed."""
import json
from pathlib import Path

import lifeimage.membership_wide as mw
from lifeimage.validate import validate_answers

ROOT = Path(__file__).resolve().parent.parent


def _items():
    return [{"id": "cal.a", "text": "A woman bakes bread for her neighbours"}]


# ---- the baseline the two-pass rule must beat (outcomes of the current one-pass code) ----
def test_baseline_one_pass_prefix_shows_the_domain_list_so_unanchored_categories_are_never_observed():
    pack = "# coarse pack | basemap t | 2 domains | ~1 tokens\nc.cooking | Cooking | x\nc.sleep | Sleep | y\n"
    b = mw.build_wide_batches(_items(), pack, prompt_version=4)
    header = json.loads(b[(0, 0)][0])
    assert "c.cooking" in header["prefix"] and "c.sleep" in header["prefix"]


def test_baseline_one_pass_rejects_a_category_outside_the_domain_set_so_no_unmatched_label_survives():
    header = {"kind": "header", "task_type": "membership.A3S", "model": "m", "prompt_version": 4,
              "prefix": "x\n# coarse pack | basemap 0 | 2 domains | ~1 tokens\nc.cooking | Cooking | x\nc.sleep | Sleep | x\n"}
    task = {"kind": "task", "task_id": "t1-v0", "task_type": "membership.A3S", "prompt_version": 4, "input_hash": "h" * 64, "variant": 0, "k": 2,
            "input": {"item": {"id": "i", "text": "Gives bread to a neighbour"}, "pack": "p"}, "allowed_verdicts": ["membership"]}
    types = {"form": {"c.neighbourly_gifting": 1.0}, "content": None, "outcome": None, "setting": None}
    ranks = {"form": {"listed": [{"domain": "c.neighbourly_gifting", "fit": 9}], "rejected": {"domain": "c.sleep", "fit": 1}},
             "content": None, "outcome": None, "setting": None}
    ans = {"task_id": "t1-v0", "task_type": "membership.A3S", "input_hash": "h" * 64, "variant": 0, "model": "m", "prompt_version": 4,
           "verdict": "membership", "reason": "r", "types": types, "ranks": ranks, "other": None}
    errs = validate_answers([json.dumps(header), json.dumps(task)], [json.dumps(ans)])
    assert any("not in the pack" in e for e in errs), errs


def test_baseline_one_pass_logs_no_synonyms_and_no_blind_unmatched_candidates():
    from lifeimage.refinement import candidates_for_item
    ans = {"types": {"form": {"c.cooking": 1.0}, "content": None, "outcome": None, "setting": None}, "prompt_version": 4, "model": "m",
           "ranks": {"form": {"listed": [{"domain": "c.cooking", "fit": 9}], "rejected": {"domain": "c.sleep", "fit": 4}},
                     "content": None, "outcome": None, "setting": None}}
    recs = candidates_for_item("i", "t", {0: ans, 1: ans}, 5)
    assert recs and {r["source"] for r in recs} <= {"unjudged", "near_floor", "disputed"}


