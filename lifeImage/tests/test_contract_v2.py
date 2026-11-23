"""Contract v2 (LI.42): option_set, counterfactual, impact count, context, valid and record time, entity kind, link
support and version; old data stays readable through migration functions.

Red first on the outcome: against the previous contract a new-form row is rejected, an old-form row is accepted
without being migrated, an unknown entity kind and a malformed counterfactual are accepted, and the migrations
(stubs that return their input) leave `date` in place."""
import copy

import pytest

from lifeimage.migration import migrate_card_links, migrate_entity_v0, migrate_evidence_v0, read_evidence
from lifeimage.participation import validate_participation_answer
from lifeimage.validate import (ValidationError, validate_card, validate_count_as, validate_entity,
                                validate_evidence)
from tests.conftest import link, make_card, make_row, membership

OLD = {k: v for k, v in make_row().items() if k not in ("valid_time", "record_time")} | {"date": "2020-05"}
OUT = membership("a", "outcome")
MEM = {"outcome": ["outcome"]}


def ok(row, **kw):
    return validate_evidence(row, membership_rels={"act", "content", "purpose", "outcome"}, **kw)


def rejected(row, **kw):
    with pytest.raises(ValidationError):
        ok(row, **kw)


# ---- time ----
def test_new_rows_carry_valid_time_and_record_time_not_date():
    ok(make_row())
    assert "date" not in make_row() and {"valid_time", "record_time"} <= set(make_row())
    rejected(make_row(date="2020-05"))
    rejected({k: v for k, v in make_row().items() if k != "record_time"})
    rejected({k: v for k, v in make_row().items() if k != "valid_time"})


@pytest.mark.parametrize("t", ["2020", "2020-05", "2020-05-01"])
def test_valid_time_takes_year_month_or_day(t):
    ok(make_row(valid_time=t))


@pytest.mark.parametrize("t", ["May 2020", "2020-5", "2020-05-01T10:00:00Z", "", 2020])
def test_valid_time_rejects_malformed(t):
    rejected(make_row(valid_time=t))


def test_record_time_may_carry_a_timestamp():
    ok(make_row(record_time="2026-11-23T10:00:00Z"))
    rejected(make_row(record_time="yesterday"))


def test_old_row_migrates_to_a_valid_new_row_and_keeps_everything_else():
    new = migrate_evidence_v0(copy.deepcopy(OLD))
    assert "date" not in new and new["valid_time"] == "2020-05" and new["record_time"]
    ok(new)
    assert {k: v for k, v in new.items() if k not in ("valid_time", "record_time")} == {k: v for k, v in OLD.items() if k != "date"}


def test_old_row_is_not_valid_unmigrated_but_read_evidence_accepts_both_forms():
    rejected(copy.deepcopy(OLD))
    assert read_evidence(copy.deepcopy(OLD))["valid_time"] == "2020-05"
    assert read_evidence(make_row()) == make_row()


def test_migration_is_idempotent_and_never_mutates_its_input():
    old = copy.deepcopy(OLD)
    once = migrate_evidence_v0(old)
    assert old == OLD and migrate_evidence_v0(once) == once


def test_migration_rejects_a_row_with_a_malformed_date_or_both_forms():
    with pytest.raises(ValueError):
        migrate_evidence_v0({**OLD, "date": "May"})
    with pytest.raises(ValueError):
        migrate_evidence_v0({**OLD, "valid_time": "2020"})


# ---- option set, counterfactual, context on rows ----
def test_row_option_set_is_null_or_a_list_of_alternative_and_harm():
    ok(make_row(option_set=None))
    ok(make_row(option_set=[{"alternative": "walk away", "harm": 0}]))
    for bad in ([{"alternative": "x", "harm": 4}], [{"alternative": "x"}], [{"harm": 1}], "walk", [{"alternative": "x", "harm": True}]):
        rejected(make_row(option_set=bad))


@pytest.mark.parametrize("src", ["stated", "implied", "model:m1", "model:haiku-v2"])
def test_counterfactual_on_an_outcome_membership_takes_course_and_source(src):
    ok(make_row(memberships=[{**OUT, "counterfactual": {"course": "the appendix bursts", "source": src}}]))


@pytest.mark.parametrize("cf", [{"course": "x", "source": "guess"}, {"course": "x", "source": "model:"}, {"course": "", "source": "stated"},
                                {"source": "stated"}, {"course": "x"}, {"course": "x", "source": "stated", "p": 1}, "stated"])
def test_malformed_counterfactual_is_rejected(cf):
    rejected(make_row(memberships=[{**OUT, "counterfactual": cf}]))


def test_counterfactual_is_null_or_absent_elsewhere_and_forbidden_off_outcome():
    ok(make_row(memberships=[{**OUT, "counterfactual": None}]))
    ok(make_row(memberships=[membership("a", "content")]))
    rejected(make_row(memberships=[{**membership("a", "content"), "counterfactual": {"course": "x", "source": "stated"}}]))


def test_context_is_optional_and_closed():
    ok(make_row(context={"jurisdiction": "DE", "culture": "northern european", "norm_set": "tipping"}))
    ok(make_row(context={"jurisdiction": "DE"}))
    ok(make_row())
    rejected(make_row(context={"planet": "earth"}))
    rejected(make_row(context={"jurisdiction": ""}))
    rejected(make_row(context="DE"))


# ---- entities ----
@pytest.mark.parametrize("kind", ["person", "organisation", "ai", "animal", "other"])
def test_entity_kinds(kind):
    assert validate_entity({"id": "e:1", "kind": kind})["kind"] == kind


@pytest.mark.parametrize("bad", [{"id": "e:1", "kind": "robot"}, {"id": "e:1"}, {"kind": "person"}, {"id": "", "kind": "person"},
                                 {"id": "e:1", "kind": "person", "x": 1}, "e:1"])
def test_entity_rejects_unknown_kind_and_malformed(bad):
    with pytest.raises(ValidationError):
        validate_entity(bad)


def test_entity_migration_never_guesses_a_kind():
    assert migrate_entity_v0("acme") == {"id": "acme", "kind": "other"}
    assert migrate_entity_v0("person:1") == {"id": "person:1", "kind": "person"}
    assert migrate_entity_v0("organisation:acme")["kind"] == "organisation"
    validate_entity(migrate_entity_v0("acme"))


def test_row_may_carry_the_entity_kind():
    ok(make_row(entity_kind="ai"))
    rejected(make_row(entity_kind="robot"))


# ---- count-as rules ----
def test_count_as_rule_carries_optional_context():
    validate_count_as({"when": "payment to a waiter", "counts_as": "tip", "context": {"jurisdiction": "US", "norm_set": "hospitality"}})
    validate_count_as({"when": "payment to a waiter", "counts_as": "tip"})
    for bad in ({"when": "x"}, {"counts_as": "y"}, {"when": "x", "counts_as": "y", "context": {"planet": "earth"}},
                {"when": "x", "counts_as": "y", "z": 1}, {"when": "", "counts_as": "y"}):
        with pytest.raises(ValidationError):
            validate_count_as(bad)


# ---- domain links ----
def test_links_take_support_and_version_and_old_links_stay_valid():
    validate_card(make_card(links=[link("b")]))
    validate_card(make_card(links=[link("b", support=12, version="2027.1")]))
    validate_card(make_card(links=[link("b", "overlap", 0.4, support=0, version="2027.1")]))
    for bad in ({"support": -1}, {"support": 1.5}, {"support": True}, {"version": ""}, {"version": 3}):
        with pytest.raises(ValidationError):
            validate_card(make_card(links=[link("b", **bad)]))


def test_link_migration_stamps_the_version_of_the_card_and_keeps_existing_values():
    c = make_card(links=[link("b"), link("c", "overlap", 0.5, version="2026.0", support=3)], basemap_version="2027.0")
    m = migrate_card_links(c)
    assert m["links"][0]["version"] == "2027.0" and "support" not in m["links"][0]
    assert m["links"][1]["version"] == "2026.0" and m["links"][1]["support"] == 3
    validate_card(m)
    assert "version" not in c["links"][0]


# ---- participation answers: option_set, impact count ----
def entry(pid="a", **over):
    e = {"id": pid, "contribution": 0.5, "responsibility": 0.5, "impact": [], "acting_for": None, "under_agreement": None,
         "informed": None, "volition": None, "volition_record": None, "production": "produced", "option_set": None}
    e.update(over)
    return e


def ans(*entries):
    return {"verdict": "participation", "participants": list(entries)}


PS = [{"id": "a", "label": "a"}]


def test_v2_participation_requires_option_set_null_or_valid():
    validate_participation_answer(ans(entry()), PS, version=2)
    validate_participation_answer(ans(entry(option_set=[{"alternative": "walk", "harm": 0}])), PS, version=2)
    no_key = entry()
    del no_key["option_set"]
    for bad in (no_key, entry(option_set=[{"alternative": "walk", "harm": 9}]), entry(option_set="walk")):
        with pytest.raises(ValidationError):
            validate_participation_answer(ans(bad), PS, version=2)


def test_v1_participation_answers_without_option_set_still_validate_and_with_it_do_not():
    v1 = entry()
    del v1["option_set"]
    validate_participation_answer(ans(v1), PS)
    with pytest.raises(ValidationError):
        validate_participation_answer(ans(entry()), PS)


def test_impact_count_is_a_positive_integer_and_optional():
    imp = {"party": "villagers", "sign": 1, "magnitude": 2}
    validate_participation_answer(ans(entry(impact=[imp])), PS, version=2)
    validate_participation_answer(ans(entry(impact=[{**imp, "count": 40}])), PS, version=2)
    for bad in (0, -3, 1.5, True, "many"):
        with pytest.raises(ValidationError):
            validate_participation_answer(ans(entry(impact=[{**imp, "count": bad}])), PS, version=2)
    with pytest.raises(ValidationError):
        validate_participation_answer(ans(entry(impact=[{**imp, "count": 3}])), PS)  # v1 has no count
