"""LI.71-72: `blind.v3`, the answer holds a list of events (a compound statement is split first), each categorised on its own facets; form names the
act at every level, outcomes are the actor's supported state changes, lists run up to 10 specific to generic, weights are no fixed ladder.
Red first: the baseline tests below pass on the code that exists (blind.v2) and show the outcomes v3 replaces: v2 accepts one event for a compound
statement and accepts an outcome that is another entity's act; the rest of this file is red until v3 exists."""
import copy
import json
import re
from pathlib import Path

import pytest

import lifeimage.label_match as lm
import lifeimage.two_pass as tp
from lifeimage.validate import ValidationError, equal_step_ladders, validate_answers, validate_blind_answer

ROOT = Path(__file__).resolve().parent.parent
ID = re.compile(r"\b[csf]\.[a-z][a-z0-9_]+\b")


def _w(label, weight, gloss):
    return {"label": label, "weight": weight, "gloss": gloss}


def _rel(action="sells bread", outcome="money in, bread out", links=None):
    return {"participants": [{"ref": "p1", "role": "seller"}, {"ref": "p2", "role": "buyer"}], "action": action,
            "outcome": {"text": outcome, "counterfactual": None}, "links": links or []}


def _blind(tag="a"):
    return {
        "form": [_w(f"sale {tag}", 0.34, "handing goods over for money"), _w(f"retail {tag}", 0.24, "selling to final customers"),
                 _w(f"exchange {tag}", 0.18, "goods for value"), _w(f"financial transaction {tag}", 0.14, "a payment between parties"),
                 _w(f"commerce {tag}", 0.1, "trade in general")],
        "content": [_w(f"bread {tag}", 0.38, "the loaf sold"), _w(f"baked goods {tag}", 0.29, "flour products baked in an oven"),
                    _w(f"food {tag}", 0.2, "things eaten"), _w(f"trade goods {tag}", 0.13, "goods for sale")],
        "outcome": [_w(f"money received {tag}", 0.6, "the seller's cash goes up"), _w(f"inventory spent {tag}", 0.4, "the seller has fewer loaves")],
        "setting": [_w(f"market {tag}", 0.45, "an open-air place of trade"), _w(f"retail {tag}x", 0.35, "the sphere of selling to consumers"),
                    _w("unknown", 0.2, "the statement says nothing more")]}


def _event(i, tag, links=None):
    return {"id": f"e{i}", "text": f"event {i}", "blind": _blind(tag), "relational": _rel(links=links)}


def good_v3(n=1):
    evs = [_event(i, chr(96 + i)) for i in range(1, n + 1)]
    if n > 1:
        evs[0]["relational"]["links"] = [{"type": "concurrent", "other": "e2"}]
        evs[1]["relational"]["links"] = [{"type": "concurrent", "other": "e1"}]
    return {"verdict": "blind", "reason": "the key acts", "events": evs}


# ---- the baseline: the outcomes v3 replaces, true of v2 today ----
def _v2_answer(outcome_labels, form):
    rel = _rel()
    return {"verdict": "blind", "reason": "r", "relational": rel, "blind": {
        "form": [_w(l, w, f"gloss of {l}") for l, w in form],
        "content": [_w("maize", 0.6, "the grain"), _w("food", 0.4, "things eaten")],
        "outcome": [_w(l, w, f"gloss of {l}") for l, w in outcome_labels],
        "setting": [_w("weekly market", 0.6, "a market held weekly"), _w("unknown", 0.4, "no more is stated")]}}


def test_baseline_v2_accepts_a_single_event_answer_for_a_compound_statement():
    # "A village family grows maize and sells the surplus at the weekly market" (cal.m02): two events, one v2 answer
    a = _v2_answer([("money received", 0.6), ("maize sold", 0.4)], [("sale", 0.6), ("cultivation", 0.4)])
    validate_blind_answer(a, version=2)  # v2: accepted, one event; the undesired outcome
    with pytest.raises(ValidationError, match="events"):
        validate_blind_answer(a, version=3)  # v3 wants an events list


def test_baseline_v2_accepts_an_outcome_that_is_another_entitys_act():
    # "A commuter rides the bus to work": "passenger carried" is the bus's event, "arrival at work" is not stated
    a = _v2_answer([("arrival at work", 0.6), ("passenger carried", 0.4)], [("commuting", 0.6), ("travel", 0.4)])
    validate_blind_answer(a, version=2)


# ---- the v3 validator ----
def test_v3_accepts_one_event_and_several_events():
    validate_blind_answer(good_v3(1), version=3)
    validate_blind_answer(good_v3(2), version=3)


def test_v3_needs_an_events_list_and_not_the_v2_shape():
    a = good_v3()
    for bad, msg in (({**a, "events": []}, "events"), ({k: v for k, v in a.items() if k != "events"}, "events"),
                     ({**a, "blind": a["events"][0]["blind"]}, "events"), ({**a, "events": a["events"][0]}, "events")):
        with pytest.raises(ValidationError, match=msg):
            validate_blind_answer(bad, version=3)


@pytest.mark.parametrize("edit,msg", [
    (lambda a: a["events"][0]["blind"]["form"].reverse(), "decreas"),
    (lambda a: a["events"][0]["blind"]["form"][0].update(weight=0.9), "sum|decreas"),
    (lambda a: a["events"][0]["blind"]["form"][0].pop("gloss"), "label, weight, gloss"),
    (lambda a: a["events"][0]["blind"]["form"][0].update(gloss=""), "gloss"),
    (lambda a: a["events"][0]["blind"]["form"][0].update(label="c.cooking"), "domain id"),
    (lambda a: a["events"][0]["relational"].update(action="see f.baking_bread"), "domain id"),
    (lambda a: a["events"][0].update(text="a clause about c.cooking"), "domain id"),
    (lambda a: a["events"][0]["blind"]["form"].extend([_w(f"x{i}", 0.001 * (9 - i), f"g{i}") for i in range(6)]), "at most 10"),
    (lambda a: a["events"][0]["blind"].update(setting=None), "setting"),
    (lambda a: a["events"][0]["blind"].pop("outcome"), "exactly"),
    (lambda a: a["events"][0].pop("relational"), "id, text, blind, relational"),
    (lambda a: a["events"][0].update(id="x1"), "id"),
    (lambda a: a.update(blind={}), "events"),
])
def test_v3_rejects(edit, msg):
    a = good_v3(1)
    edit(a)
    with pytest.raises(ValidationError, match=msg):
        validate_blind_answer(a, version=3)


def test_v3_up_to_ten_labels_and_each_event_checked_on_its_own():
    a = good_v3(1)
    ws = [0.19, 0.17, 0.15, 0.13, 0.11, 0.09, 0.07, 0.05, 0.03, 0.01]
    a["events"][0]["blind"]["form"] = [_w(f"l{i}", w, f"g{i}") for i, w in enumerate(ws)]
    validate_blind_answer(a, version=3)  # 10 labels, sum 1
    b = good_v3(2)
    b["events"][1]["blind"]["form"][0]["weight"] = 0.9
    with pytest.raises(ValidationError, match="sum|decreas"):
        validate_blind_answer(b, version=3)


def test_v3_a_compound_answer_links_its_events_by_id():
    a = good_v3(2)
    a["events"][0]["relational"]["links"] = []
    a["events"][1]["relational"]["links"] = []
    with pytest.raises(ValidationError, match="link"):
        validate_blind_answer(a, version=3)  # two events and no link between them
    a = good_v3(2)
    a["events"][0]["relational"]["links"] = [{"type": "causes", "other": "e9"}]
    with pytest.raises(ValidationError, match="e9"):
        validate_blind_answer(a, version=3)
    a["events"][0]["relational"]["links"] = [{"type": "part_of", "other": "e1"}]
    with pytest.raises(ValidationError, match="itself|e1"):
        validate_blind_answer(a, version=3)


def test_equal_step_ladders_are_flagged_not_rejected():
    a = good_v3(1)
    ladder = [_w("a1", 0.4, "g"), _w("a2", 0.3, "g"), _w("a3", 0.2, "g"), _w("a4", 0.1, "g")]  # the 0.4/0.3/0.2/0.1 formula
    a["events"][0]["blind"]["form"] = ladder
    validate_blind_answer(a, version=3)  # accepted
    assert equal_step_ladders(a["events"][0]["blind"]) == ["form"]
    assert equal_step_ladders(good_v3(1)["events"][0]["blind"]) == []
    two = [_w("a1", 0.6, "g"), _w("a2", 0.4, "g")]  # two labels are no ladder
    b = good_v3(1)["events"][0]["blind"]
    b["form"] = two
    assert equal_step_ladders(b) == []
    c = good_v3(1)["events"][0]["blind"]
    c["form"] = [_w("a1", 0.45, "g"), _w("a2", 0.25, "g"), _w("a3", 0.18, "g"), _w("a4", 0.12, "g")]
    assert equal_step_ladders(c) == []


def test_v3_answers_pass_the_runner_validator_with_the_header_version(tmp_path):
    items = [{"id": "cal.a", "text": "A baker sells bread at the market"}]
    (bp,) = tp.write_blind_batches("t", tp.build_blind_batches(items, variants=1, prompt_version=3), tmp_path, prompt_version=3)
    lines = bp.read_text(encoding="utf-8").splitlines()
    t = json.loads(lines[1])
    ans = {"task_id": t["task_id"], "task_type": "blind", "input_hash": t["input_hash"], "variant": 0, "model": json.loads(lines[0])["model"],
           "prompt_version": 3, **good_v3(2)}
    assert validate_answers(lines, [json.dumps(ans)]) == []
    ans["events"][0]["blind"]["form"][0]["weight"] = 0.9
    assert any("sum" in e or "decreas" in e for e in validate_answers(lines, [json.dumps(ans)]))


# ---- the prompt ----
def _prompt():
    return (ROOT / "prompts" / "blind.v3.md").read_text(encoding="utf-8")


def test_prompt_v3_carries_the_li71_examples_and_not_the_held_out_categorisations():
    p = re.sub(r"\s+", " ", _prompt())
    for needle in ("form sale, retail, exchange, financial transaction", "content bread, baked goods, food, direct human-to-human transaction",
                   "outcome money input, inventory spent", "setting market, stall/store/shop, point of sale, retail, commerce, business",
                   "A baker sells bread at the market", "A woman buys a train ticket", "form purchase, booking, travel planning, logistics",
                   "content ticket/pass, receipt, train, public transportation", "outcome ticket obtained, promise obtained, seat booked, documentation",
                   "setting point of sale (rest unknown)"):
        assert needle in p, needle
    low = p.lower()
    for held_out in ("commuter", "commuting", "polling station", "ballot", "bus ride", "passenger carried", "arrival at work", "voting", "maize",
                     "electoral", "turnout", "vehicle ride", "democra"):
        assert held_out not in low, held_out
    assert not ID.search(p)
    for v in ("blind.v1.md", "blind.v2.md"):
        assert (ROOT / "prompts" / v).exists()  # old versions kept


def test_prompt_v3_states_the_lessons_as_rules():
    p = re.sub(r"\s+", " ", _prompt())
    for needle in ("split", "events", "role", "purpose", "regularity", "most specific first", "perspective", "another entity", "unstated",
                   "up to 10", "more generic than the one before", "central", "no fixed ladder", "part_of", "causes", "concurrent", "unknown",
                   "stops where the statement stops", "key action", "doing", "issue ticket"):
        assert needle in p, needle


def test_prompt_v3_examples_are_valid_answers():
    p = _prompt()
    blocks = [json.loads(b) for b in re.findall(r"```json\n(.*?)\n```", p, re.S)]
    assert len(blocks) >= 4
    for b in blocks:
        validate_blind_answer({"verdict": "blind", "reason": "r", **b}, version=3)
    assert any(len(b["events"]) >= 2 for b in blocks), "one example is a compound statement split into events"
    assert all(equal_step_ladders(e["blind"]) == [] for b in blocks for e in b["events"]), "no example teaches the ladder"
    assert any(len(e["blind"]["form"]) >= 6 for b in blocks for e in b["events"]), "an example shows a longer list"


# ---- the pilot batches ----
def test_pilot_v3_batches_cover_the_32_controls_in_two_variants_without_ids(tmp_path):
    paths = tp.pilot_blind_batches(tmp_path, prompt_version=3, sets=("controls",))
    assert sorted(p.name for p in paths) == [f"blind.v3.controls.var{v}.part0.jsonl" for v in (0, 1)]
    for p in paths:
        lines = p.read_text(encoding="utf-8").splitlines()
        h = json.loads(lines[0])
        assert h["prompt_version"] == 3 and h["task_type"] == "blind" and len(lines) - 1 == 32
        assert h["prefix"].startswith(_prompt().rstrip("\n")) and not ID.search(p.read_text(encoding="utf-8"))
        assert json.loads(lines[1])["prompt_version"] == 3
    assert tp.LATEST_BLIND_VERSION == 3


# ---- label_match against the author's held-out categorisations ----
def test_held_out_author_labels_are_the_li72_lists():
    h = lm.HELD_OUT
    assert h["cal.s08"]["form"][:3] == ["commuting", "passenger", "travel in bus"] and len(h["cal.s08"]["form"]) == 9
    assert h["cal.s08"]["content"] == ["bus ride", "vehicle ride", "journey", "getting on/off vehicle"]
    assert h["cal.s08"]["setting"][:2] == ["inside bus", "inside vehicle"] and len(h["cal.s08"]["setting"]) == 6
    assert h["cal.s08"]["outcome"] == ["journey made", "time spent travelling"]  # LI.72 (corrected by the lead from the author's message)
    assert h["cal.s04"]["form"] == ["voting", "civic participation", "electoral process", "decision making", "democracy"]
    assert h["cal.s04"]["outcome"] == ["vote cast", "vote entered in count", "ballot used", "turnout counted"]
    assert h["cal.s04"]["setting"] == ["polling station", "election", "civic life", "democratic polity"]
    assert lm.NEGATIVE_LABELS == {"cal.s08": {"outcome": ["arrival at work", "passenger carried"]}}
    texts = {json.loads(l)["id"]: json.loads(l)["text"] for l in (ROOT / "data/gold/membership_wide_controls_v1.jsonl").read_text(encoding="utf-8").splitlines()}
    assert "commuter" in texts["cal.s08"] and "ballot" in texts["cal.s04"] and "maize" in texts["cal.m02"]


def _pairs(tmp_path, n_events=1):
    items = [{"id": k, "text": f"text of {k}"} for k in ("cal.d01", "cal.d02", "cal.s04", "cal.s08")]
    paths = tp.write_blind_batches("t", tp.build_blind_batches(items, prompt_version=3), tmp_path, prompt_version=3)
    out = []
    for p in paths:
        lines = p.read_text(encoding="utf-8").splitlines()
        ans = [json.dumps({"task_id": json.loads(l)["task_id"], "task_type": "blind", "input_hash": json.loads(l)["input_hash"],
                           "variant": json.loads(l)["variant"], "model": json.loads(lines[0])["model"], "prompt_version": 3, **good_v3(n_events)})
               for l in lines[1:]]
        ap = p.with_name(p.name.replace(".jsonl", ".answers.jsonl"))
        ap.write_text("\n".join(ans) + "\n", encoding="utf-8")
        out.append((p, ap))
    return out


def test_label_match_v3_batches_cover_in_prompt_held_out_and_negative_labels(tmp_path):
    b = lm.build_label_match_batches(_pairs(tmp_path), authors={**lm.AUTHOR_LABELS, **lm.HELD_OUT}, negatives=lm.NEGATIVE_LABELS)
    tasks = [json.loads(l) for v in b.values() for l in v[1:]]
    per_variant = 16 + 13 + (9 + 4 + 2 + 6) + 2 + (5 + 3 + 4 + 4)
    assert len(tasks) == 2 * per_variant and all(len(v) - 1 <= 50 for v in b.values())
    neg = [t for t in tasks if t["input"]["item"]["id"] == "cal.s08" and t["input"]["relation"] == "outcome"]
    assert sorted({t["input"]["author_label"] for t in neg}) == ["arrival at work", "journey made", "passenger carried", "time spent travelling"] and len(neg) == 8
    assert set(tasks[0]["input"]) == {"item", "relation", "author_label", "run"}  # the judge is not told which labels are negative
    assert not ID.search("\n".join(sum(b.values(), [])))


def test_label_match_run_view_flattens_the_events_of_a_v3_answer():
    a = good_v3(2)
    view = lm.run_view(a, "form")
    assert [r["ref"] for r in view] == [f"r{i}" for i in range(10)] and view[0]["label"] == "sale a" and view[5]["label"] == "sale b"
    assert lm.run_view(a, "setting")[2]["label"] == "market b"  # unknown markers are not categories


# ---- the report ----
def _judge(b, make):
    out = []
    for lines in b.values():
        for l in lines[1:]:
            t = json.loads(l)
            v, ref = make(t)
            out.append((t, {"task_id": t["task_id"], "task_type": "label_match", "input_hash": t["input_hash"], "variant": t["variant"],
                            "model": json.loads(lines[0])["model"], "prompt_version": 1, "verdict": v, "run_ref": ref, "reason": "r"}))
    return out


def test_report_judges_the_v3_predictions(tmp_path):
    pairs = _pairs(tmp_path, n_events=2)
    b = lm.build_label_match_batches(pairs, authors={**lm.AUTHOR_LABELS, **lm.HELD_OUT}, negatives=lm.NEGATIVE_LABELS)
    def judge(t):  # held-out labels half matched (partial), in-prompt matched, negatives matched (the failure the report must show)
        if t["input"]["item"]["id"] in lm.HELD_OUT and t["input"]["author_label"] not in ("arrival at work", "passenger carried"):
            return ("partial", "r0")
        return ("match", "r0")
    rep = tp.blind_v3_report(tp.answers_by_item(pairs), _judge(b, judge))
    assert rep["events_per_answer"]["cal.d01"] == {0: 2, 1: 2}
    assert rep["median_labels"]["form"] == 5
    assert rep["ladder"]["share"] == 0.0
    assert rep["heldout_match"]["cal.s04"]["form"] == 0.5 and "outcome" in rep["heldout_match"]["cal.s08"]
    assert rep["negatives"]["cal.s08"]["arrival at work"]["match"] == 2 and rep["predictions"]["no_rejected_outcome_produced"] is False
    assert rep["in_prompt_match"] == 1.0 and rep["predictions"]["in_prompt_match_at_least_0.8"] is True
    assert rep["predictions"]["heldout_match_at_least_0.6"] is False
    assert rep["predictions"]["maize_split_in_both_variants"] is None  # no cal.m02 answers in this fixture
    assert rep["predictions"]["median_form_labels_at_least_5"] is True and rep["predictions"]["equal_step_ladders_at_most_25pct"] is True


def test_report_flags_ladders_and_the_unsplit_maize_control():
    a = good_v3(1)
    a["events"][0]["blind"]["form"] = [_w("a1", 0.4, "g"), _w("a2", 0.3, "g"), _w("a3", 0.2, "g"), _w("a4", 0.1, "g")]
    answers = {"cal.m02": {0: ("A village family grows maize and sells the surplus at the weekly market",
                                {**a, "task_id": "x", "input_hash": "h", "variant": 0, "prompt_version": 3, "model": "m", "task_type": "blind"})}}
    rep = tp.blind_v3_report(answers, [])
    assert rep["events_per_answer"]["cal.m02"] == {0: 1} and rep["predictions"]["maize_split_in_both_variants"] is False
    assert rep["ladder"]["flagged"] == 1 and rep["ladder"]["share"] == 0.25 and rep["predictions"]["median_form_labels_at_least_5"] is False


# ---- the pre-registration ----
def _preds():
    return (ROOT / "data" / "gold" / "blind_v3_predictions.md").read_text(encoding="utf-8")


def test_predictions_are_preregistered_before_any_answer_exists():
    t = _preds()
    for needle in ("Confidence 0.5", "0.6", "cal.s08", "cal.s04", "arrival at work", "passenger carried", "cal.m02", "25%", "0.8", "median", "5",
                   "held out", "blind.v3", "label_match.v1"):
        assert needle in t, needle
    assert not list((ROOT / "data" / "batches").glob("blind.v3.*.answers.jsonl")) or "judged" in t


def test_governed_values_of_blind_v3_are_listed():
    from lifeimage.governed import GOVERNED
    for k, d in (("blind.v3.max_labels", 10), ("blind.v3.min_labels", 5), ("blind.v3.max_events", 6), ("blind.v3.ladder_min_labels", 3)):
        assert GOVERNED[k]["default"] == d and k in (ROOT / "README.md").read_text(encoding="utf-8")
