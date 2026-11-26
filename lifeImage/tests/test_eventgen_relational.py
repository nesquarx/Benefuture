"""Relational events (LI.65): every generated event and every calibration event snippet carries layer A memberships, participant records
(layer B, responsibility by freedom), valid time and the metadata of LI.42; layer D links obey time and span. Counterexamples: an event or
snippet lacking any of them, a cause after its effect, a part outside its whole, all fail."""
import copy
import datetime as dt
import time
import warnings

import pytest

from lifeimage.eventgen import calibration as cal
from lifeimage.eventgen import events as ev
from lifeimage.eventgen import relational as rel
from lifeimage.eventgen.world import BIRTH_DATE, World
from lifeimage.generators.common import seed_ids, validate_row
from lifeimage.validate import ValidationError

REGIONS = ("KEN", "IND", "FRA")
RM = cal.load_regions()


def world(n=150, seed=1, **kw):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return World(cal.load_table(field_ids=seed_ids()), REGIONS, n, seed, region_map=RM, **kw)


@pytest.fixture(scope="module")
def built():
    w = world()
    return w, w.events()


def all_events(by):
    return [e for evs in by.values() for e in evs]


def test_every_generated_event_is_relational(built):
    w, by = built
    events = all_events(by)
    assert len(events) > 3000 and len(by) == len(w.people)
    for e in events:
        rel.validate_event(e)                                       # layers A and B and the metadata, rows through the library's validator
        assert {m["rel"] for m in e["memberships"]} == {"form", "content", "outcome", "setting"}
        for r in ("form", "content", "outcome", "setting"):
            assert sum(m["weight"] for m in e["memberships"] if m["rel"] == r) == pytest.approx(1.0)
        assert e["participants"] and e["valid_time"] and e["record_time"] and e["place"] and e["span"]["start"] == e["valid_time"]
        assert all(m["counterfactual"]["source"].startswith("model:eventgen:") for m in e["memberships"] if m["rel"] == "outcome")
        assert sum(p["contribution"] for p in e["participants"]) <= 1 + 1e-6
    for pid, evs in list(by.items())[::10]:
        for e in evs:
            for r in e["rows"]:
                validate_row(r)                                       # strict, not the structure-cached check
                assert r["valid_time"] == e["valid_time"] and r["context"]["jurisdiction"] == e["place"]


def test_participants_cover_the_roles_of_each_kind(built):
    _, by = built
    roles = {}
    for e in all_events(by):
        roles.setdefault(e["kind"], set()).update(e["roles"].values())
    assert {"self", "mother", "health"} <= roles["born"] and {"self", "spouse", "registry"} <= roles["marriage"]
    assert {"self", "spouse", "court"} <= roles["divorce"] and {"self", "child", "other_parent", "health"} <= roles["birth_of_child"]
    assert {"self", "mother", "child"} <= roles["fatherhood"] and {"self", "family"} <= roles["death"] and "school" in roles["school_start"]
    assert "parent" in roles["school_start"] and "parent" not in roles["tertiary_start"]


def test_spouse_child_and_agency_entities_exist_and_validate(built):
    w, by = built
    ents = rel.entities(by)
    kinds = {e["id"].split(":")[0]: e["kind"] for e in ents}
    assert kinds["spouse"] == "person" and kinds["child"] == "person" and kinds["school"] == "organisation" and kinds["agency"] == "organisation"
    married = [p for p in w.people if any(k == "marriage" for k, _ in p.events)]
    assert married and all(f"spouse:{p.pid}" in {e["id"] for e in ents} for p in married)
    assert w.entities() == ents


def test_responsibility_follows_freedom_and_missing_option_sets_degrade_loudly():
    w = world(300)
    by = w.events()
    log = w.relational_degraded
    assert log and all({"step", "mechanism", "substitute", "reason"} <= set(d) for d in log)
    assert {d["mechanism"] for d in log} == {"responsibility_from_freedom"} and all("governed default" in d["substitute"] for d in log)
    items = {d["step"] for d in log}
    flagged = [e for e in all_events(by) if e["id"] in items]
    from lifeimage.eventgen import catalog
    missing = {k.key for k in catalog.ALL if any(r[4] == ("missing",) for r in k.roles) or k.family in ("work", "civic", "harm")}   # a minor's act or a domain with no option set
    assert flagged and {e["kind"] for e in flagged} <= {"marriage", "school_dropout", "divorce"} | missing
    for e in all_events(by):
        for p in e["participants"]:
            if p["contribution"] == 0:
                assert p["responsibility"] == 0                      # a beneficiary who only receives carries none
            if e["id"] in items and p["option_set"] is None:
                assert p["responsibility"] == 0.5                    # the governed default, never full freedom
    adult = [e for e in all_events(by) if e["kind"] == "school_dropout" and e["id"] not in items]
    assert adult and all(p["responsibility"] == 1.0 for e in adult for p in e["participants"] if p["contribution"] > 0)
    div = [e for e in all_events(by) if e["kind"] == "divorce"]
    assert div and all(min(p["responsibility"] for p in e["participants"] if p["contribution"] > 0 and p["option_set"]) == 0.1 for e in div)   # no better way out: the floor


@pytest.mark.parametrize("break_", ["no_memberships", "no_outcome", "outcome_weights", "no_counterfactual", "no_participants", "no_valid_time", "no_span",
                                    "no_place", "overfull", "unproduced_receiver", "unknown_domain", "row_entity_mismatch"])
def test_an_event_lacking_a_layer_or_metadata_fails(built, break_):
    _, by = built
    e = copy.deepcopy(next(x for x in all_events(by) if x["kind"] == "marriage"))
    if break_ == "no_memberships":
        e["memberships"] = []
    elif break_ == "no_outcome":
        e["memberships"] = [m for m in e["memberships"] if m["rel"] != "outcome"]
    elif break_ == "outcome_weights":
        next(m for m in e["memberships"] if m["rel"] == "setting")["weight"] = 0.5
    elif break_ == "no_counterfactual":
        for m in e["memberships"]:
            m.pop("counterfactual", None)
    elif break_ == "no_participants":
        e["participants"], e["roles"], e["rows"] = [], {}, []
    elif break_ == "no_valid_time":
        e["valid_time"] = None
    elif break_ == "no_span":
        e["span"] = None
    elif break_ == "no_place":
        e["place"] = ""
    elif break_ == "overfull":
        for p in e["participants"]:
            p["contribution"] = 0.9
    elif break_ == "unproduced_receiver":
        next(p for p in e["participants"] if p["contribution"] > 0)["production"] = None
    elif break_ == "unknown_domain":
        e["memberships"][0]["domain"] = "c.no_such_domain"
    elif break_ == "row_entity_mismatch":
        e["rows"][0]["entity"] = "person:somebody-else"
    with pytest.raises(ValidationError):
        rel.validate_event(e)


# ---- layer D ----
def ev_(i, kind, age, end=None, links=()):
    t = ev.valid_time(BIRTH_DATE, age)
    return {"id": i, "kind": kind, "valid_time": t, "span": {"start": t, "end": ev.valid_time(BIRTH_DATE, age if end is None else end)},
            "links": [{"from": i, "to": to, "type": ty, "confidence": 0.8} for ty, to in links]}


def test_a_cause_after_its_effect_and_a_part_outside_its_whole_fail():
    rel.validate_links([ev_("a", "primary_complete", 12, links=[("causes", "b")]), ev_("b", "secondary_start", 12)])
    with pytest.raises(ValidationError, match="precedes the cause"):
        rel.validate_links([ev_("a", "primary_complete", 12, links=[("causes", "b")]), ev_("b", "secondary_start", 11)])
    rel.validate_links([ev_("b", "birth_of_child", 20, links=[("part_of", "p")]), ev_("p", "pregnancy", 19.25, 20)])
    with pytest.raises(ValidationError, match="outside"):
        rel.validate_links([ev_("b", "birth_of_child", 21, links=[("part_of", "p")]), ev_("p", "pregnancy", 19.25, 20)])
    with pytest.raises(ValidationError, match="outside"):
        rel.validate_links([ev_("b", "divorce", 30, links=[("part_of", "m")]), ev_("m", "marriage", 31, 40)])
    with pytest.raises(ValidationError, match="do not overlap"):
        rel.validate_links([ev_("a", "school_dropout", 15, links=[("concurrent", "b")]), ev_("b", "marriage", 25)])
    rel.validate_links([ev_("a", "school_dropout", 15, links=[("concurrent", "b")]), ev_("b", "marriage", 15.5)])
    with pytest.raises(ValidationError, match="different valid times"):
        rel.validate_links([ev_("a", "marriage", 20, links=[("re_description", "b")]), ev_("b", "marriage", 21)])
    with pytest.raises(ValidationError):
        rel.validate_links([ev_("a", "marriage", 20, links=[("causes", "zzz")])])


def test_generated_links_obey_time_and_span_and_use_the_calibrated_readings(built):
    w, by = built
    types = {}
    for evs in by.values():
        rel.validate_links(evs)
        kinds = {e["id"]: e["kind"] for e in evs}
        for e in evs:
            for l in e["links"]:
                types.setdefault(l["type"], set()).add((e["kind"], kinds[l["to"]]))
    assert {("birth_of_child", "pregnancy"), ("divorce", "marriage")} <= types["part_of"]
    assert ("primary_complete", "secondary_start") in types["causes"] and ("marriage", "birth_of_child") in types["causes"]
    assert types["concurrent"] == {("school_dropout", "marriage")}                 # dropout and early marriage: temporal reading only
    assert ("school_dropout", "marriage") not in types["causes"] and ("marriage", "school_dropout") not in types["causes"]
    for evs in by.values():
        births = [e for e in evs if e["kind"] == "birth_of_child"]
        pregs = {e["span"]["end"] for e in evs if e["kind"] == "pregnancy"}
        assert all(b["valid_time"] in pregs and any(l["type"] == "part_of" for l in b["links"]) for b in births)


def test_no_marriage_causes_link_where_the_model_ignores_marriage():
    w = world(150, noise={"nonmarital_birth_relative_hazard": 1.0})
    types = {l["type"] for evs in w.events().values() for e in evs for l in e["links"] if e["kind"] == "marriage"}
    assert "causes" not in types


# ---- calibration event snippets ----
def test_every_committed_event_snippet_has_its_relational_form():
    table = cal.load_table(field_ids=seed_ids())
    n = 0
    for p in table.params:
        for s in p.event_snippets:
            n += 1
            r = s["relational"]
            assert s["actor"] and s["action"]                                         # the free text stays
            assert r["event"]["valid_time"] == str(p.year) and r["participants"] and r["event"]["memberships"]
            assert {m["rel"] for m in r["event"]["memberships"]} == {"form", "content", "outcome", "setting"}
            assert all(m["counterfactual"]["source"].startswith("model:") for m in r["event"]["memberships"] if m["rel"] == "outcome")
            assert r["degraded"] and r["degraded"][0]["mechanism"] == "responsibility_from_freedom"      # option set unknown: logged
    assert n >= 1000


@pytest.mark.parametrize("break_", ["no_memberships", "no_participants", "no_valid_time", "no_counterfactual", "no_relational"])
def test_a_snippet_lacking_its_relational_form_fails(break_):
    from tests.test_eventgen_calibration import EV, P
    e = EV()
    r = copy.deepcopy(e["relational"])
    if break_ == "no_memberships":
        r["event"]["memberships"] = []
    elif break_ == "no_participants":
        r["participants"], r["roles"] = [], {}
    elif break_ == "no_valid_time":
        r["event"]["valid_time"] = ""
    elif break_ == "no_counterfactual":
        for m in r["event"]["memberships"]:
            m.pop("counterfactual", None)
    if break_ == "no_relational":
        e.pop("relational")
    else:
        e["relational"] = r
    with pytest.raises(cal.CalibrationError):
        cal.Table([P(event_snippets=[e])])


def test_probe_with_partners_and_deaths_stays_under_ten_seconds():
    t0 = time.time()
    w = world(500)
    by = w.events()
    assert time.time() - t0 < 10 and len(w.people) == 1500
    kinds = {e["kind"] for e in all_events(by)}
    assert {"marriage", "divorce", "fatherhood", "death", "pregnancy", "birth_of_child"} <= kinds
