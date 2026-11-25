"""Adjacency judging batches (LI.55): which of two layouts puts the thematically closer neighbours beside a field, judged
blind. Red first against a stub that writes no batches. Acceptance: at most 50 tasks a batch, two variants showing the two
sets in opposite positions, the layouts never named in a task line, the report recovering a planted preference and a
planted position bias. Counterexamples: malformed layouts and verdicts are rejected."""
import json
import random
from pathlib import Path

import pytest

from lifeimage import adjacency as adj
from lifeimage.validate import validate_answers, validate_task

from conftest import make_card

ROOT = Path(__file__).resolve().parent.parent
N = 80


def world(n=N):
    return [make_card(f"c.{k:03d}", label=f"Field {k}", description=f"About field {k}", aliases=[], links=[], axes=None) for k in range(n)]


def orders(n=N, seed=1):
    a = [f"c.{k:03d}" for k in range(n)]
    b = a[:]
    random.Random(seed).shuffle(b)
    return a, b


def build(**kw):
    a, b = orders()
    return adj.build_adjacency_batches(world(), a, b, model="haiku-runner", prompts_dir=ROOT / "prompts", **kw)


def tasks(lines):
    return [json.loads(l) for l in lines[1:]]


def test_batches_are_small_and_cover_both_variants():
    batches, key = build()
    assert {v for v, _ in batches} == {0, 1}
    assert all(1 <= len(lines) - 1 <= 50 for lines in batches.values())
    per_variant = {v: sum(len(l) - 1 for (vv, _), l in batches.items() if vv == v) for v in (0, 1)}
    assert per_variant[0] == per_variant[1] == len(key["fields"]) > 0
    for lines in batches.values():
        h = json.loads(lines[0])
        assert h["task_type"] == "adjacency" and h["prompt_version"] == 1 and "set 1" in h["prefix"]
        for t in tasks(lines):
            validate_task(t)
            assert t["allowed_verdicts"] == ["1", "2", "equal"]
            assert len(t["input"]["set_1"]) == len(t["input"]["set_2"]) == 2
            assert t["input"]["card"]["id"] not in {c["id"] for c in t["input"]["set_1"] + t["input"]["set_2"]}


def test_fields_with_the_same_neighbours_in_both_layouts_are_not_asked():
    a = [f"c.{k:03d}" for k in range(8)]
    batches, key = adj.build_adjacency_batches(world(8), a, a[:], model="m", prompts_dir=ROOT / "prompts")
    assert batches == {} and key["fields"] == {}


def test_neighbours_are_the_two_circular_neighbours_in_each_layout():
    a, b = orders()
    batches, key = build()
    t = tasks(batches[(0, 0)])[0]
    f = t["input"]["card"]["id"]
    sets = {frozenset(c["id"] for c in t["input"]["set_1"]), frozenset(c["id"] for c in t["input"]["set_2"])}
    na, nb = adj.neighbour_sets(a)[f], adj.neighbour_sets(b)[f]
    assert sets == {na, nb} and na != nb
    assert adj.neighbour_sets(["x", "y", "z", "w"])["x"] == frozenset({"y", "w"})  # wraps around


def test_layouts_are_blinded_and_positions_randomised():
    batches, key = build()
    text = "\n".join(l for lines in batches.values() for l in lines[1:])
    for word in ("layout", "sim", "axes", '"A"', '"B"'):
        assert word not in text
    first = {}
    for (v, _), lines in batches.items():
        for t in tasks(lines):
            first[(v, t["task_id"])] = key["tasks"][t["task_id"]]["set_1"]
    v0 = [x for (v, _), x in first.items() if v == 0]
    share_a = v0.count("A") / len(v0)
    assert 0.3 <= share_a <= 0.7, share_a  # randomised, not always the same layout first
    assert all(key["tasks"][t["task_id"]]["set_1"] != key["tasks"][f"{t['task_id'][:-2]}v0"]["set_1"]
               for lines in batches.values() for t in tasks(lines) if t["variant"] == 1)  # variant 1 swaps positions


def test_report_recovers_a_planted_preference_and_a_planted_position_bias():
    batches, key = build()
    def answer(task, rule):
        return {"task_id": task["task_id"], "task_type": "adjacency", "input_hash": task["input_hash"], "variant": task["variant"],
                "model": "haiku-runner", "prompt_version": 1, "verdict": rule(task), "reason": "x"}
    allt = [t for lines in batches.values() for t in tasks(lines)]
    prefers_b = [answer(t, lambda t: "1" if key["tasks"][t["task_id"]]["set_1"] == "B" else "2") for t in allt]
    r = adj.adjacency_report(prefers_b, key)
    assert r["share_b_of_decisive"] == 1.0 and r["position_bias"] == pytest.approx(0.5, abs=0.1) and r["decisive"] == len(allt)
    always_1 = [answer(t, lambda t: "1") for t in allt]
    r = adj.adjacency_report(always_1, key)
    assert r["share_b_of_decisive"] == pytest.approx(0.5, abs=1e-9)  # the second variant swaps positions, so a bias cancels
    assert r["position_bias"] == 1.0
    ties = [answer(t, lambda t: "equal") for t in allt]
    r = adj.adjacency_report(ties, key)
    assert r["decisive"] == 0 and r["share_b_of_decisive"] is None


def test_validation_accepts_good_answers_and_rejects_bad_verdicts():
    batches, key = build()
    lines = batches[(0, 0)]
    good = [json.dumps({"task_id": t["task_id"], "task_type": "adjacency", "input_hash": t["input_hash"], "variant": 0,
                        "model": "haiku-runner", "prompt_version": 1, "verdict": "equal", "reason": "r"}) for t in tasks(lines)]
    assert validate_answers(lines, good) == []
    bad = [json.dumps({**json.loads(g), "verdict": "A"}) for g in good]
    assert len(validate_answers(lines, bad)) == len(good)


def test_validation_rejects_a_task_whose_sets_are_malformed():
    batches, _ = build()
    lines = list(batches[(0, 0)])
    t = json.loads(lines[1])
    t["input"]["set_1"] = t["input"]["set_1"][:1]
    lines[1] = json.dumps(t)
    with pytest.raises(ValueError):
        validate_answers(lines, [])


@pytest.mark.parametrize("bad", ["short", "other_ids", "duplicate"])
def test_malformed_layouts_are_rejected(bad):
    a, b = orders(10)
    if bad == "short":
        a, b = a[:3], b[:3]
    elif bad == "other_ids":
        b = b[:-1] + ["c.zzz"]
    else:
        b = b[:-1] + [b[0]]
    with pytest.raises(ValueError):
        adj.build_adjacency_batches(world(10), a, b, model="m", prompts_dir=ROOT / "prompts")
