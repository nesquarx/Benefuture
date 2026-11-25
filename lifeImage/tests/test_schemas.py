import copy

import pytest

from lifeimage.validate import ValidationError, validate_answer, validate_card, validate_evidence, validate_task


def bad(fn, obj):
    with pytest.raises(ValidationError):
        fn(obj)


def test_valid_card_accepted(card):
    validate_card(card())


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
    validate_card(card(radius={**r, "difficulty": None}))  # a proxy with no source is null, the composite stays
    bad(validate_card, card(radius={**r, "composite": None}))
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


from conftest import make_row as evidence  # noqa: E402


def test_evidence_accepted():
    validate_evidence(evidence())


@pytest.mark.parametrize(
    "over",
    [
        {"memberships": []},
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


# ---- links and memberships (replace parents / neighbours / domain weights) -------------------------------------

from conftest import link, make_row, membership  # noqa: E402


def rejects(fn, obj, match):
    with pytest.raises(ValidationError, match=match):
        fn(obj)


def test_card_with_upstream_links_summing_to_one_and_overlaps_free(card):
    validate_card(card(links=[link("a", weight=0.7), link("b", weight=0.3), link("n", "overlap", 0.5),
                              link("m", "overlap", 0.9)]))


def test_card_with_only_overlap_links_has_no_upstream_constraint(card):
    validate_card(card(links=[link("n", "overlap", 0.2)]))


@pytest.mark.parametrize("weights", [[0.7, 0.2], [0.5, 0.5, 0.5], [1.0, 0.1]])
def test_card_upstream_weights_must_sum_to_one(card, weights):
    rejects(validate_card, card(links=[link(f"p{i}", weight=w) for i, w in enumerate(weights)]), "upstream")


def test_overlap_weights_do_not_count_towards_the_upstream_sum(card):
    rejects(validate_card, card(links=[link("a", weight=0.6), link("n", "overlap", 0.4)]), "upstream")


def test_card_link_rel_comes_from_the_vocabulary(card):
    rejects(validate_card, card(links=[link("a", "cousin", 1.0)]), "cousin")
    validate_card(card(links=[link("a", "cousin", 1.0)]), link_rels={"upstream", "overlap", "cousin"})


def test_card_rejects_self_links_duplicate_links_and_bad_strict(card):
    rejects(validate_card, card(id="x", links=[link("x")]), "itself")
    rejects(validate_card, card(links=[link("a", "overlap", 0.5), link("a", "overlap", 0.5)]), "duplicate")
    rejects(validate_card, card(links=[link("a", strict="yes")]), "strict")
    validate_card(card(links=[link("a", strict=True)]))


def test_card_rejects_old_parents_and_neighbours(card):
    rejects(validate_card, card(parents=[]), "parents")
    c = card()
    c["links"] = [link("a")]
    c["neighbours"] = []
    rejects(validate_card, c, "neighbours")


def test_evidence_with_relation_and_typed_memberships_accepted():
    validate_evidence(make_row(memberships=[membership("a", "content", 0.5), membership("b", "content", 0.5),
                                            membership("c", "purpose", 1.0)]))


@pytest.mark.parametrize("ms", [
    [membership("a", "content", 0.5), membership("b", "content", 0.4)],
    [membership("a", "content", 1.0), membership("b", "purpose", 0.6)],
    [membership("a", "content", 0.5), membership("a", "content", 0.5)],
    [],
])
def test_evidence_membership_weights_sum_to_one_within_each_relation(ms):
    with pytest.raises(ValidationError):
        validate_evidence(make_row(memberships=ms))


def test_evidence_membership_sum_error_names_the_relation():
    rejects(validate_evidence,
            make_row(memberships=[membership("a", "content", 1.0), membership("b", "purpose", 0.6)]), "purpose")


def test_evidence_relation_and_membership_rel_come_from_vocabularies():
    rejects(validate_evidence, make_row(relation="bystander"), "bystander")
    validate_evidence(make_row(relation="bystander"), relations={"bystander"})
    rejects(validate_evidence, make_row(memberships=[membership("a", "vibe", 1.0)]), "vibe")
    validate_evidence(make_row(memberships=[membership("a", "vibe", 1.0)]), membership_rels={"vibe"})


def test_evidence_rejects_old_domains_field_and_missing_relation():
    rejects(validate_evidence, make_row(domains=[{"id": "a", "weight": 1.0}]), "domains")
    row = make_row()
    del row["relation"]
    rejects(validate_evidence, row, "relation")
