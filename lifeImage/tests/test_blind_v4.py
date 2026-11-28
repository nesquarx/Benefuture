"""LI.72-73: `blind.v4`, what the blind.v3 pilot verdict names: minimum list lengths (form 5, setting 4, content 4, outcome 2, enforced; fewer only with an
explicit per-facet `short_reason`), outcome = what the event itself makes true for the actor, `unknown` a zero-weight terminator, content the activity first.
Red first: the baseline tests pass on the code that exists (blind.v3) and show the undesired outcomes v4 replaces: v3 accepts a setting of one label plus an
`unknown` carrying most of the weight, and a null outcome for a completed act; the v4 tests are red until v4 exists."""
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


def _w(label, weight, gloss="a gloss"):
    return {"label": label, "weight": weight, "gloss": gloss}


def _rel(links=None):
    return {"participants": [{"ref": "p1", "role": "seller"}], "action": "sells bread", "outcome": {"text": "money in", "counterfactual": None}, "links": links or []}


def _blind(tag="a", zero_unknown=True, competence=True):
    unk = _w("unknown", 0 if zero_unknown else 0.2, "the statement says nothing more")
    setting = [_w(f"market {tag}", 0.4), _w(f"stall {tag}", 0.28), _w(f"retail {tag}", 0.19), _w(f"commerce {tag}", 0.13)]
    if not zero_unknown:
        setting = [_w(f"market {tag}", 0.45), _w(f"retail {tag}", 0.35)]
    b = {
        "form": [_w(f"sale {tag}", 0.34), _w(f"retail {tag}x", 0.24), _w(f"exchange {tag}", 0.18), _w(f"financial transaction {tag}", 0.14), _w(f"commerce {tag}x", 0.1)],
        "content": [_w(f"selling {tag}", 0.34), _w(f"bread {tag}", 0.28), _w(f"baked goods {tag}", 0.21), _w(f"food {tag}", 0.17)],
        "outcome": [_w(f"money received {tag}", 0.6), _w(f"inventory spent {tag}", 0.4)],
        "setting": setting + [unk]}
    if competence:
        b["competence"] = [_w(f"selling skill {tag}", 0.4, "serving buyers"), _w(f"handling cash {tag}", 0.33, "giving change"), _w(f"trade know-how {tag}", 0.27, "how markets work")]
    return b


def _event(i, tag, zero_unknown=True, competence=True):
    return {"id": f"e{i}", "text": f"event {i}", "blind": _blind(tag, zero_unknown, competence), "relational": _rel()}


def good(n=1, zero_unknown=True, competence=True):
    evs = [_event(i, chr(96 + i), zero_unknown, competence) for i in range(1, n + 1)]
    if n > 1:
        evs[0]["relational"]["links"] = [{"type": "concurrent", "other": "e2"}]
        evs[1]["relational"]["links"] = [{"type": "concurrent", "other": "e1"}]
    return {"verdict": "blind", "reason": "the key acts", "events": evs}


# ---- the baseline: the outcomes v4 replaces, true of v3 today ----
def test_baseline_v3_accepts_a_thin_unknown_heavy_setting_and_an_empty_outcome_for_a_completed_act():
    a = good(1, zero_unknown=False, competence=False)  # v3: four facets; unknown weighted
    a["events"][0]["blind"]["setting"] = [_w("market", 0.55), _w("unknown", 0.45)]  # one label, unknown carries nearly half the weight
    a["events"][0]["blind"]["outcome"] = None  # a completed sale with no outcome
    a["events"][0]["blind"]["form"] = [_w("sale", 1.0)]
    validate_blind_answer(a, version=3)  # v3 accepts it: the undesired outcome


# ---- the v4 validator ----
def test_v4_accepts_a_good_answer_and_several_events():
    validate_blind_answer(good(1), version=4)
    validate_blind_answer(good(2), version=4)


def test_v4_rejects_what_v3_accepted():
    a = good(1)
    a["events"][0]["blind"]["setting"] = [_w("market", 0.55), _w("unknown", 0.45)]
    with pytest.raises(ValidationError, match="unknown|zero|weight"):
        validate_blind_answer(a, version=4)
    b = good(1)
    b["events"][0]["blind"]["outcome"] = None
    with pytest.raises(ValidationError, match="outcome"):
        validate_blind_answer(b, version=4)
    c = good(1, zero_unknown=False)  # an unknown carrying weight
    with pytest.raises(ValidationError, match="unknown|zero|weight"):
        validate_blind_answer(c, version=4)


@pytest.mark.parametrize("facet,keep", [("form", 4), ("content", 3), ("setting", 3), ("outcome", 1), ("competence", 2)])
def test_v4_enforces_the_minimum_list_lengths(facet, keep):
    a = good(1)
    ls = [e for e in a["events"][0]["blind"][facet] if e["label"] != "unknown"][:keep]
    s = sum(e["weight"] for e in ls)
    for e in ls:
        e["weight"] = round(e["weight"] / s, 2)
    ls[0]["weight"] = round(ls[0]["weight"] + 1 - sum(e["weight"] for e in ls), 2)
    a["events"][0]["blind"][facet] = ls
    with pytest.raises(ValidationError, match=f"{facet}.*at least|{facet}.*short_reason"):
        validate_blind_answer(a, version=4)
    a["events"][0]["short_reason"] = {facet: "the statement names nothing more to list"}
    validate_blind_answer(a, version=4)  # fewer is allowed with an explicit per-facet reason


def test_v4_the_unknown_marker_is_a_zero_weight_terminator_and_is_no_label():
    a = good(1)
    assert a["events"][0]["blind"]["setting"][-1]["weight"] == 0
    validate_blind_answer(a, version=4)
    a["events"][0]["blind"]["setting"].insert(1, _w("unknown", 0))  # twice
    with pytest.raises(ValidationError, match="unknown"):
        validate_blind_answer(a, version=4)
    b = good(1)
    b["events"][0]["blind"]["setting"] = b["events"][0]["blind"]["setting"][:-1]  # no unknown: allowed, the list is concrete to generic
    validate_blind_answer(b, version=4)
    c = good(1)
    c["events"][0]["blind"]["setting"][-1]["weight"] = 0.0001
    with pytest.raises(ValidationError, match="unknown|zero"):
        validate_blind_answer(c, version=4)
    d = good(1)  # the real labels must still sum to 1 and fall
    d["events"][0]["blind"]["setting"][0]["weight"] = 0.9
    with pytest.raises(ValidationError, match="sum|decreas"):
        validate_blind_answer(d, version=4)
    e = good(1)  # unknown does not count towards the minimum
    e["events"][0]["blind"]["setting"] = [_w("market", 0.4), _w("stall", 0.3), _w("retail", 0.2), _w("unknown", 0.0), ]
    e["events"][0]["blind"]["setting"][2]["weight"] = 0.3
    e["events"][0]["blind"]["setting"][1]["weight"] = 0.3
    e["events"][0]["blind"]["setting"][0]["weight"] = 0.4
    with pytest.raises(ValidationError, match="setting"):
        validate_blind_answer(e, version=4)


def test_v4_short_reason_must_name_a_short_facet_and_a_line():
    a = good(1)
    a["events"][0]["short_reason"] = {"form": "not needed"}  # form has 5, no reason is due
    with pytest.raises(ValidationError, match="short_reason"):
        validate_blind_answer(a, version=4)
    b = good(1)
    b["events"][0]["short_reason"] = {"mood": "x"}
    with pytest.raises(ValidationError, match="short_reason"):
        validate_blind_answer(b, version=4)
    c = good(1)
    c["events"][0]["blind"]["outcome"] = None
    c["events"][0]["short_reason"] = {"outcome": ""}
    with pytest.raises(ValidationError, match="short_reason"):
        validate_blind_answer(c, version=4)
    c["events"][0]["short_reason"] = {"outcome": "the statement shows no change"}
    validate_blind_answer(c, version=4)  # a null outcome with a reason
    d = good(1)
    d["events"][0]["blind"]["setting"] = None
    d["events"][0]["short_reason"] = {"setting": "the statement names no place and the act has none"}
    validate_blind_answer(d, version=4)


def test_v4_keeps_v3_structure_and_rejects_ids_and_oversize():
    a = good(1)
    a["events"][0]["blind"]["form"][0]["label"] = "c.cooking"
    with pytest.raises(ValidationError, match="domain id"):
        validate_blind_answer(a, version=4)
    b = good(1)
    ws = [0.19, 0.17, 0.15, 0.13, 0.11, 0.09, 0.07, 0.05, 0.03, 0.01]
    b["events"][0]["blind"]["form"] = [_w(f"l{i}", w) for i, w in enumerate(ws)]
    validate_blind_answer(b, version=4)  # 10 allowed
    b["events"][0]["blind"]["form"].append(_w("l10", 0.0))
    with pytest.raises(ValidationError, match="at most 10|weight"):
        validate_blind_answer(b, version=4)
    c = good(2)
    c["events"][0]["relational"]["links"] = []
    c["events"][1]["relational"]["links"] = []
    with pytest.raises(ValidationError, match="link"):
        validate_blind_answer(c, version=4)
    with pytest.raises(ValidationError, match="events"):
        validate_blind_answer({**good(1), "events": []}, version=4)


def test_v3_validation_is_unchanged():
    validate_blind_answer(good(1, zero_unknown=False, competence=False), version=3)
    with pytest.raises(ValidationError):
        validate_blind_answer(good(1, competence=False), version=3)  # a zero-weight unknown is v4 only


def test_equal_step_ladders_ignore_a_zero_weight_unknown():
    bl = good(1)["events"][0]["blind"]
    bl["setting"] = [_w("a", 0.4), _w("b", 0.3), _w("c", 0.2), _w("d", 0.1), _w("unknown", 0)]
    assert equal_step_ladders(bl) == ["setting"]


def test_v4_answers_pass_the_runner_validator_with_the_header_version(tmp_path):
    items = [{"id": "cal.a", "text": "A baker sells bread at the market"}]
    (bp,) = tp.write_blind_batches("t", tp.build_blind_batches(items, variants=1, prompt_version=4), tmp_path, prompt_version=4)
    lines = bp.read_text(encoding="utf-8").splitlines()
    t = json.loads(lines[1])
    ans = {"task_id": t["task_id"], "task_type": "blind", "input_hash": t["input_hash"], "variant": 0, "model": json.loads(lines[0])["model"],
           "prompt_version": 4, **good(2)}
    assert validate_answers(lines, [json.dumps(ans)]) == []
    ans["events"][0]["blind"]["setting"][-1]["weight"] = 0.2
    assert validate_answers(lines, [json.dumps(ans)])


# ---- the prompt ----
def _prompt():
    return (ROOT / "prompts" / "blind.v4.md").read_text(encoding="utf-8")


def test_prompt_v4_carries_the_author_examples_and_not_the_held_out_answers():
    p = re.sub(r"\s+", " ", _prompt())
    for needle in ("form sale, retail, exchange, financial transaction", "content bread, baked goods, food, direct human-to-human transaction",
                   "outcome money input, inventory spent", "setting market, stall/store/shop, point of sale, retail, commerce, business",
                   "A baker sells bread at the market", "A woman buys a train ticket", "form purchase, booking, travel planning, logistics",
                   "content ticket/pass, receipt, train, public transportation", "outcome ticket obtained, promise obtained, seat booked, documentation",
                   "setting point of sale (rest unknown)"):
        assert needle in p, needle
    low = p.lower()
    assert not re.search(r"\bbus\b|\bpassenger", low)
    for held_out in ("commuter", "commuting", "polling station", "ballot", "arrival at work", "voting", "vote", "maize", "electoral",
                     "turnout", "vehicle ride", "democra", "journey made", "time spent travelling", "inside vehicle", "road network", "going to work"):
        assert held_out not in low, held_out
    assert not ID.search(p)
    for v in ("blind.v1.md", "blind.v2.md", "blind.v3.md"):
        assert (ROOT / "prompts" / v).exists()  # earlier versions kept


def test_prompt_v4_states_the_verdict_lessons_as_rules():
    p = re.sub(r"\s+", " ", _prompt())
    for needle in ("at least 5", "at least 4", "at least 2", "short_reason", "up to 10", "zero weight", "weight 0", "the event itself makes true",
                   "likely but unstated", "another entity", "the activity itself first", "concrete to generic", "ordinary inference",
                   "split", "part_of", "causes", "concurrent", "actor", "issue ticket", "no fixed ladder", "the setting stops", "competence", "skills and know-how", "acting entity", "at least 3"):
        assert needle in p, needle


def test_prompt_v4_has_a_contrast_example_from_a_new_event():
    p = _prompt()
    assert "post" in p.lower() and "letter" in p.lower()  # the new event used for the outcome contrast
    low = re.sub(r"\s+", " ", p).lower()
    assert "letter delivered" in low and "left out" in low


def test_prompt_v4_examples_are_valid_v4_answers():
    p = _prompt()
    blocks = [json.loads(b) for b in re.findall(r"```json\n(.*?)\n```", p, re.S)]
    assert len(blocks) >= 4
    for b in blocks:
        validate_blind_answer({"verdict": "blind", "reason": "r", **b}, version=4)
    assert any(len(b["events"]) >= 2 for b in blocks), "one example is a compound statement split into events"
    assert all(equal_step_ladders(e["blind"]) == [] for b in blocks for e in b["events"]), "no example teaches the ladder"
    assert any("short_reason" in e for b in blocks for e in b["events"]), "an example shows a short_reason"
    for b in blocks:
        for e in b["events"]:
            for rel in ("setting",):
                ls = e["blind"][rel]
                if ls and ls[-1]["label"] == "unknown":
                    assert ls[-1]["weight"] == 0


# ---- the pilot batches ----
def test_pilot_v4_batches_cover_the_32_controls_in_two_variants_without_ids(tmp_path):
    paths = tp.pilot_blind_batches(tmp_path, prompt_version=4, sets=("controls",))
    assert sorted(p.name for p in paths) == [f"blind.v4.controls.var{v}.part0.jsonl" for v in (0, 1)]
    for p in paths:
        lines = p.read_text(encoding="utf-8").splitlines()
        h = json.loads(lines[0])
        assert h["prompt_version"] == 4 and h["task_type"] == "blind" and len(lines) - 1 == 32
        assert h["prefix"].startswith(_prompt().rstrip("\n")) and not ID.search(p.read_text(encoding="utf-8"))
        assert json.loads(lines[1])["prompt_version"] == 4
    assert tp.LATEST_BLIND_VERSION == 4


# ---- label_match: held-out author labels incl. the accepted commuter outcomes, rejected outcomes as negatives ----
def test_held_out_includes_the_accepted_commuter_outcomes_and_the_rejected_ones_are_negatives():
    assert lm.HELD_OUT["cal.s08"]["outcome"] == ["journey made", "time spent travelling"]
    assert lm.HELD_OUT["cal.s08"]["competence"] == ["bus travel", "recognising a bus", "getting on and off", "pedestrian navigation", "reading street signs"]
    assert "competence" not in lm.HELD_OUT["cal.s04"]
    assert lm.NEGATIVE_LABELS == {"cal.s08": {"outcome": ["arrival at work", "passenger carried"]}}


def _pairs(tmp_path, n_events=1):
    items = [{"id": k, "text": f"text of {k}"} for k in ("cal.d01", "cal.d02", "cal.s04", "cal.s08", "cal.m02")]
    paths = tp.write_blind_batches("t", tp.build_blind_batches(items, prompt_version=4), tmp_path, prompt_version=4)
    out = []
    for p in paths:
        lines = p.read_text(encoding="utf-8").splitlines()
        ans = [json.dumps({"task_id": json.loads(l)["task_id"], "task_type": "blind", "input_hash": json.loads(l)["input_hash"],
                           "variant": json.loads(l)["variant"], "model": json.loads(lines[0])["model"], "prompt_version": 4, **good(n_events)})
               for l in lines[1:]]
        ap = p.with_name(p.name.replace(".jsonl", ".answers.jsonl"))
        ap.write_text("\n".join(ans) + "\n", encoding="utf-8")
        out.append((p, ap))
    return out


def test_label_match_v4_batches_cover_in_prompt_held_out_and_negative_labels(tmp_path):
    pairs = _pairs(tmp_path)
    b = lm.build_label_match_batches(pairs, authors={**lm.AUTHOR_LABELS, **lm.HELD_OUT}, negatives=lm.NEGATIVE_LABELS)
    tasks = [json.loads(l) for v in b.values() for l in v[1:]]
    per_variant = 16 + 13 + (9 + 4 + 2 + 6 + 5) + 2 + (5 + 3 + 4 + 4)
    assert len(tasks) == 2 * per_variant
    neg = [t for t in tasks if t["input"]["item"]["id"] == "cal.s08" and t["input"]["relation"] == "outcome"]
    assert sorted({t["input"]["author_label"] for t in neg}) == ["arrival at work", "journey made", "passenger carried", "time spent travelling"]
    assert set(tasks[0]["input"]) == {"item", "relation", "author_label", "run"}


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


def test_report_v4_judges_the_pre_registered_predictions(tmp_path):
    pairs = _pairs(tmp_path, n_events=2)
    b = lm.build_label_match_batches(pairs, authors={**lm.AUTHOR_LABELS, **lm.HELD_OUT}, negatives=lm.NEGATIVE_LABELS)
    rep = tp.blind_v4_report(tp.answers_by_item(pairs), _judge(b, lambda t: ("match", "r0")))
    assert rep["median_labels"] == {"form": 5, "content": 4, "outcome": 2, "setting": 4, "competence": 3}
    assert rep["competence_form_overlap_share"] == 0.0 and rep["predictions"]["competence_form_overlap_at_most_20pct"] is True
    assert rep["short_reason_share"] == 0.0
    assert rep["predictions"]["median_labels_at_least_minimum"] is True and rep["predictions"]["short_reason_at_most_15pct"] is True
    assert rep["predictions"]["maize_split_in_both_variants"] is True
    assert rep["predictions"]["no_rejected_outcome_produced"] is False  # the negatives matched in this fixture
    assert rep["predictions"]["heldout_match_at_least_0.6_each_facet_each_item"] is True and rep["predictions"]["in_prompt_match_at_least_0.8"] is True
    rep2 = tp.blind_v4_report(tp.answers_by_item(pairs), _judge(b, lambda t: ("none", None) if t["input"]["item"]["id"] == "cal.s08" and t["input"]["relation"] == "content" else ("match", "r0")))
    assert rep2["predictions"]["heldout_match_at_least_0.6_each_facet_each_item"] is False
    assert rep2["heldout_match"]["cal.s08"]["content"] == 0.0


def test_report_v4_counts_short_reasons_and_unknown_weight():
    a = good(1)
    a["events"][0]["blind"]["outcome"] = None
    a["events"][0]["short_reason"] = {"outcome": "no change shown"}
    meta = {"task_id": "x", "input_hash": "h", "variant": 0, "prompt_version": 4, "model": "m", "task_type": "blind"}
    rep = tp.blind_v4_report({"cal.m02": {0: ("t", {**a, **meta})}}, [])
    assert rep["short_reason_share"] == 0.2 and rep["predictions"]["short_reason_at_most_15pct"] is False
    assert rep["predictions"]["maize_split_in_both_variants"] is False


# ---- the pre-registration ----
def test_predictions_are_preregistered_before_any_answer_exists():
    t = (ROOT / "data" / "gold" / "blind_v4_predictions.md").read_text(encoding="utf-8")
    for needle in ("competence", "20%", "bus travel", "at least 2", "Confidence 0.55", "0.6", "cal.s08", "cal.s04", "journey made", "time spent travelling", "arrival at work", "passenger carried",
                   "cal.m02", "15%", "0.8", "median", "short_reason", "blind.v4", "label_match.v1", "both"):
        assert needle in t, needle
    assert not list((ROOT / "data" / "batches").glob("blind.v4.*.answers.jsonl")) or "judged" in t


def test_governed_values_of_blind_v4_are_listed():
    from lifeimage.governed import GOVERNED
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for k, d in (("blind.v4.min_form", 5), ("blind.v4.min_setting", 4), ("blind.v4.min_content", 4), ("blind.v4.min_outcome", 2),
                 ("blind.v4.min_competence", 3), ("blind.v4.short_reason_ceiling", 0.15)):
        assert GOVERNED[k]["default"] == d and k in readme


# ---- the fifth facet: competence (LI.73) ----
def test_v4_competence_is_required_and_a_fifth_facet():
    a = good(1)
    del a["events"][0]["blind"]["competence"]
    with pytest.raises(ValidationError, match="exactly the keys"):
        validate_blind_answer(a, version=4)
    b = good(1)
    b["events"][0]["blind"]["competence"] = None
    with pytest.raises(ValidationError, match="competence"):
        validate_blind_answer(b, version=4)
    b["events"][0]["short_reason"] = {"competence": "the statement shows no skill exercised"}
    validate_blind_answer(b, version=4)
    with pytest.raises(ValidationError):
        validate_blind_answer(good(1), version=3)  # v3 has four facets only


def test_v4_competence_may_repeat_a_form_label_only_with_a_distinct_gloss():
    a = good(1)
    a["events"][0]["blind"]["competence"][0]["label"] = "sale a"
    a["events"][0]["blind"]["competence"][0]["gloss"] = "a gloss"  # the form gloss of "sale a" is the default "a gloss"
    with pytest.raises(ValidationError, match="gloss"):
        validate_blind_answer(a, version=4)
    a["events"][0]["blind"]["competence"][0]["gloss"] = "the skill of selling, not the act"
    validate_blind_answer(a, version=4)
    assert tp.competence_form_overlap(a["events"][0]["blind"]) == ["sale a"]


def test_v4_competence_lists_follow_the_list_rules():
    a = good(1)
    a["events"][0]["blind"]["competence"] = [_w("c1", 0.5), _w("c2", 0.6), _w("c3", 0.1)]
    with pytest.raises(ValidationError, match="decreas|sum"):
        validate_blind_answer(a, version=4)


def test_prompt_v4_competence_rules_and_new_event_example():
    p = re.sub(r"\s+", " ", _prompt())
    low = p.lower()
    for needle in ("competence", "skills and know-how the event requires of the acting entity", "the minimum it needs", "not skills it could incidentally involve", "explains fractions"):
        assert needle.lower() in low, needle
    assert "competence" in json.dumps([json.loads(b) for b in re.findall(r"```json\n(.*?)\n```", _prompt(), re.S)])
    for b in re.findall(r"```json\n(.*?)\n```", _prompt(), re.S):
        for e in json.loads(b)["events"]:
            assert len(e["blind"]["competence"]) >= 3 or "competence" in e.get("short_reason", {})
