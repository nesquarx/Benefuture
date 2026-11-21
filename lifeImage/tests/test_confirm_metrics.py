"""Metrics of the confirming battery: A, B and D on the combined answers, plus the two measures the confirming
battery adds (production on consumed-versus-produced pairs, the outcome on counterfactual items).

Red first on the outcome: a stub that returns empty sections, one that counts any non-null production as a hit, or
one that never separates counterfactual from plain items returns wrong numbers, not a missing-function error."""
import json
import math

import pytest

from lifeimage.confirm import TASK_TYPE, build_confirm_batches, load_confirm_records
from lifeimage.confirm_metrics import compute_confirm, outcome_metrics, production_metrics, render_confirm
from lifeimage.membership import DEFAULT_PACK, pack_lines

PACK = DEFAULT_PACK.read_text(encoding="utf-8")
DOMS = sorted(l.split(" | ")[0] for l in pack_lines(PACK)[2])


def item(iid, source="a_pool", participants=("p", "q"), **extra):
    return {"id": iid, "text": f"text of {iid}", "source": source,
            "participants": [{"id": p, "label": p} for p in participants], **extra}


def entry(pid, production="produced", contribution=0.0):
    return {"id": pid, "contribution": contribution, "responsibility": 0.5, "impact": [], "acting_for": None,
            "under_agreement": None, "informed": None, "volition": None, "volition_record": None,
            "production": production}


def answer(task, variant, *, outcome=None, production=None, contributions=None, subevents=2, form=DOMS[0]):
    ps = task["input"]["item"]["participants"]
    contributions = contributions or {}
    return {"task_id": task["task_id"], "task_type": TASK_TYPE, "input_hash": task["input_hash"], "variant": variant,
            "model": "m", "prompt_version": 1, "verdict": "confirm", "reason": "r",
            "types": {"form": {form: 1.0}, "content": {DOMS[1]: 1.0}, "outcome": outcome, "setting": None,
                      "flavour": None}, "other": None,
            "participants": [entry(p["id"], (production or {}).get(p["id"]), contributions.get(p["id"], 0.0)) for p in ps],
            "subevents": [{"id": f"e{n}", "label": f"step {n} of text"} for n in range(1, subevents + 1)],
            "event_links": [{"from": "e1", "to": "e2", "type": "causes", "confidence": 0.6}] if subevents > 1 else []}


def write(tmp_path, items, make):
    """Batch files and answers (3 variants) on disk; make(task, variant) -> answer. Returns the answers paths."""
    out = []
    for v, parts in build_confirm_batches(items, PACK).items():
        b = tmp_path / f"confirm.v1.var{v}.jsonl"
        b.write_text("\n".join(parts[0]) + "\n")
        a = tmp_path / f"confirm.v1.var{v}.answers.jsonl"
        a.write_text("\n".join(json.dumps(make(json.loads(l), v)) for l in parts[0][1:]) + "\n")
        out.append(a)
    return out


# ---- loading ----
def test_combined_answers_split_into_the_three_layers_with_their_items(tmp_path):
    items = [item("x.1"), item("x.2", participants=("solo",))]
    paths = write(tmp_path, items, lambda t, v: answer(t, v, outcome={DOMS[2]: 1.0}))
    r = load_confirm_records(paths)
    assert len(r["A"]) == len(r["participation"]) == len(r["events"]) == 6
    assert {x["item"] for x in r["A"]} == {"x.1", "x.2"} and r["A"][0]["vocab"] == "A3S"
    assert set(r["participation"][0]["participants"]) <= {"p", "q", "solo"}
    assert r["events"][0]["subevents"] and r["A"][0]["types"]["outcome"] == {DOMS[2]: 1.0}


# ---- combined metrics reuse the layer metrics ----
def test_a_b_and_d_sections_are_computed_and_a_conservation_breach_is_counted(tmp_path):
    items = [item("x.1"), item("x.2")]
    breach = lambda t, v: answer(t, v, contributions={"p": 0.8, "q": 0.8} if t["input"]["item"]["id"] == "x.1" else {"p": 0.4})
    r = load_confirm_records(write(tmp_path, items, breach))
    m = compute_confirm(r, items)
    assert set(m) >= {"A", "B", "D", "production", "outcome"}
    assert m["B"]["conservation"]["violations"] == 3 and m["B"]["conservation"]["answers"] == 6
    assert m["A"]["items"] == 2 and m["A"]["types"]["form"]["alpha"] == 1.0
    assert m["D"]["n_subevents"]["mean"] == 2.0
    assert "Layer B" in render_confirm(m) and "Layer D" in render_confirm(m)


# ---- production on pairs ----
def pair_items():
    return [item("cp.1.a", "production_pair", pair="cp.1", side="a", expect_production={"p": "consumed"}),
            item("cp.1.b", "production_pair", pair="cp.1", side="b", expect_production={"p": "produced"}),
            item("cp.2.a", "production_pair", pair="cp.2", side="a", expect_production={"p": "consumed"}),
            item("cp.2.b", "production_pair", pair="cp.2", side="b", expect_production={"p": "produced"})]


def prod_records(tmp_path, said):
    items = pair_items()
    return items, load_confirm_records(write(tmp_path, items, lambda t, v: answer(
        t, v, production={"p": said[t["input"]["item"]["id"]]})))


def test_production_pairs_count_right_when_the_focal_participant_matches_the_expected_value(tmp_path):
    items, r = prod_records(tmp_path, {"cp.1.a": "consumed", "cp.1.b": "produced", "cp.2.a": "consumed", "cp.2.b": "produced"})
    m = production_metrics(r["participation"], items)
    assert m["pairs"] == 2 and m["pairs_separated"] == 2 and m["match_rate"] == 1.0 and m["null_rate"] == 0.0


def test_a_runner_that_calls_everything_produced_does_not_separate_the_pairs(tmp_path):
    items, r = prod_records(tmp_path, {k: "produced" for k in ("cp.1.a", "cp.1.b", "cp.2.a", "cp.2.b")})
    m = production_metrics(r["participation"], items)
    assert m["pairs_separated"] == 0 and m["match_rate"] == 0.5
    assert m["by_expected"]["consumed"]["match_rate"] == 0.0 and m["by_expected"]["produced"]["match_rate"] == 1.0


def test_null_production_is_counted_apart_and_never_a_match(tmp_path):
    items, r = prod_records(tmp_path, {"cp.1.a": None, "cp.1.b": "produced", "cp.2.a": None, "cp.2.b": None})
    m = production_metrics(r["participation"], items)
    assert m["null_rate"] == 0.75 and m["match_rate"] == 0.25 and m["pairs_separated"] == 0


# ---- outcome on counterfactual items ----
def cf_items():
    return [item("cf.1", "counterfactual", counterfactual="stated", expected_outcome="change"),
            item("cf.2", "counterfactual", counterfactual="implied", expected_outcome="change"),
            item("cf.3", "counterfactual", counterfactual="stated", expected_outcome="null"),
            item("ev.1"), item("ev.2")]


def test_outcome_is_filled_on_change_items_and_null_on_no_difference_and_plain_items(tmp_path):
    items = cf_items()
    right = {"cf.1": {DOMS[2]: 1.0}, "cf.2": {DOMS[3]: 1.0}, "cf.3": None, "ev.1": None, "ev.2": None}
    r = load_confirm_records(write(tmp_path, items, lambda t, v: answer(t, v, outcome=right[t["input"]["item"]["id"]])))
    m = outcome_metrics(r["A"], items)
    assert m["change"]["fill_rate"] == 1.0 and m["null"]["fill_rate"] == 0.0 and m["plain"]["fill_rate"] == 0.0
    assert m["agreement_with_expectation"] == 1.0


def test_an_always_filled_outcome_is_not_credited_and_the_naive_stub_would_be(tmp_path):
    items = cf_items()
    r = load_confirm_records(write(tmp_path, items, lambda t, v: answer(t, v, outcome={DOMS[2]: 1.0})))
    m = outcome_metrics(r["A"], items)
    assert m["change"]["fill_rate"] == 1.0 and m["null"]["fill_rate"] == 1.0 and m["plain"]["fill_rate"] == 1.0
    assert m["agreement_with_expectation"] == pytest.approx(2 / 3)  # cf.3 wrong; the plain items are not expectations
    assert m["plain"]["items"] == 2 and m["change"]["items"] == 2 and m["null"]["items"] == 1


def test_an_outcome_filled_by_a_strict_majority_of_variants_counts_as_filled(tmp_path):
    items = [item("cf.1", "counterfactual", counterfactual="stated", expected_outcome="change")]
    r = load_confirm_records(write(tmp_path, items, lambda t, v: answer(t, v, outcome={DOMS[2]: 1.0} if v < 2 else None)))
    m = outcome_metrics(r["A"], items)
    assert m["change"]["item_fill_rate"] == 1.0 and m["change"]["fill_rate"] == pytest.approx(2 / 3)
