import copy

import pytest

from lifeimage.validate import ValidationError, validate_answer, validate_card, validate_evidence, validate_task


def bad(fn, obj):
    with pytest.raises(ValidationError):
        fn(obj)


def test_valid_card_accepted(card):
    validate_card(card())


def test_card_with_parents_summing_to_one(card):
    validate_card(card(parents=[{"id": "a", "weight": 0.7}, {"id": "b", "weight": 0.3}]))


@pytest.mark.parametrize("weights", [[0.7, 0.2], [0.5, 0.5, 0.5], [1.2]])
def test_card_parent_weights_must_sum_to_one(card, weights):
    bad(validate_card, card(parents=[{"id": f"p{i}", "weight": w} for i, w in enumerate(weights)]))


def test_card_rejects_unknown_field_and_missing_field(card):
    bad(validate_card, card(extra=1))
    c = card()
    del c["label"]
    bad(validate_card, c)


@pytest.mark.parametrize("axes", [{"abstract_tangible": 1.5, "personal_global": 0}, {"abstract_tangible": 0}])
def test_card_axes_in_range(card, axes):
    bad(validate_card, card(axes=axes))


def test_card_radius_and_arc_bounds(card):
    r = {"complexity": 0.2, "difficulty": 0.3, "specificity": 0.4, "composite": 0.3}
    validate_card(card(radius=r, arc={"start": 10, "end": 50}))
    bad(validate_card, card(radius={**r, "composite": 1.1}))
    bad(validate_card, card(arc={"start": -5, "end": 50}))


def test_card_enums(card):
    bad(validate_card, card(level="huge"))
    bad(validate_card, card(status="draft"))


def test_confidence_never_reaches_one(card):
    bad(validate_card, card(provenance={"label": {"source": "s", "confidence": 1.0}}))
    validate_card(card(provenance={"label": {"source": "s", "confidence": 0.999999}}))


def test_tombstone_requires_successors_and_only_tombstones_have_them(card):
    bad(validate_card, card(status="tombstone", successors=[]))
    bad(validate_card, card(status="stable", successors=[{"id": "n", "weight": 1.0}]))
    validate_card(card(status="tombstone", successors=[{"id": "n", "weight": 0.6}, {"id": "m", "weight": 0.4}]))
    bad(validate_card, card(status="tombstone", successors=[{"id": "n", "weight": 0.6}]))


def evidence(**over):
    row = {
        "entity": "person:1",
        "domains": [{"id": "a", "weight": 0.5}, {"id": "b", "weight": 0.5}],
        "basemap_version": "2027.0",
        "channel": "positive",
        "sign": 1,
        "magnitude": 2.0,
        "date": "2020-05",
        "tier": "claimed",
        "confidence": 0.4,
        "provenance": {"source": "resume.pdf", "span": "p1:l3-l5"},
        "revoked": False,
    }
    row.update(over)
    return row


def test_evidence_accepted():
    validate_evidence(evidence())


@pytest.mark.parametrize(
    "over",
    [
        {"domains": [{"id": "a", "weight": 0.5}, {"id": "b", "weight": 0.4}]},
        {"domains": []},
        {"confidence": 1.0},
        {"tier": "rumoured"},
        {"sign": 0},
        {"magnitude": -1},
        {"date": "May 2020"},
        {"revoked": "no"},
        {"channel": "negative", "sign": 1},
        {"channel": "positive", "sign": -1},
    ],
)
def test_evidence_rejected(over):
    bad(validate_evidence, evidence(**over))


def test_negative_channel_reserved_until_enabled():
    row = evidence(channel="negative", sign=-1)
    bad(validate_evidence, row)
    validate_evidence(row, allow_negative=True)


def task(**over):
    t = {
        "kind": "task",
        "task_id": "abc-v0",
        "task_type": "relate",
        "prompt_version": 1,
        "input_hash": "abc",
        "variant": 0,
        "k": 3,
        "input": {"card": {}, "candidates": []},
        "allowed_verdicts": ["same", "different"],
    }
    t.update(over)
    return t


def answer(**over):
    a = {
        "task_id": "abc-v0",
        "task_type": "relate",
        "input_hash": "abc",
        "variant": 0,
        "model": "haiku",
        "prompt_version": 1,
        "verdict": "same",
        "reason": "Same label and anchor.",
    }
    a.update(over)
    return a


def test_task_and_answer_accepted():
    validate_task(task())
    validate_answer(answer())
    validate_answer(answer(weights={"a": 0.5, "b": 0.5}))


@pytest.mark.parametrize("over", [{"variant": -1}, {"k": 0}, {"allowed_verdicts": []}, {"kind": "header"}])
def test_task_rejected(over):
    bad(validate_task, task(**over))


@pytest.mark.parametrize(
    "over",
    [{"reason": ""}, {"reason": "line one\nline two"}, {"verdict": ""}, {"weights": {"a": 0.5, "b": 0.2}}, {"junk": 1}],
)
def test_answer_rejected(over):
    bad(validate_answer, answer(**over))
