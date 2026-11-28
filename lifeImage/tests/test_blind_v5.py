"""LI.74: `blind.v5`, what the blind.v4 pilot verdict names: the form lists the actor's role and the purpose besides the act, the competence lists concrete
sub-skills before broader capabilities, each event carries a `mode` (occurred, claim, plan, credential, role, self_assessment) from which the pipeline
assigns the competence basis, the outcome contrast names sequels and other entities' acts (also paraphrased), and the competence/form overlap metric
reports a number that catches near-copies.
Red first: the baseline tests pass on the code that exists (blind.v4) and show the v4 outcomes v5 replaces (v4 accepts a commuting-like form list with no
role or purpose, has no mode, and its overlap metric misses a near-copy and is null without events); the v5 tests are red until v5 exists."""
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
MODES = ("occurred", "claim", "plan", "credential", "role", "self_assessment")


def _w(label, weight, gloss=None):
    return {"label": label, "weight": weight, "gloss": gloss or f"gloss of {label}"}


def _rel():
    return {"participants": [{"ref": "p1", "role": "rider"}], "action": "rides", "outcome": {"text": "ride made", "counterfactual": None}, "links": []}


def _blind(tag="a", form=None, competence=None):
    return {
        "form": form or [_w(f"riding {tag}", 0.30), _w(f"travel {tag}", 0.24), _w(f"transport {tag}", 0.18), _w(f"mobility {tag}", 0.15), _w(f"routine {tag}", 0.13)],
        "content": [_w(f"the ride {tag}", 0.34), _w(f"vehicle {tag}", 0.28), _w(f"route {tag}", 0.21), _w(f"fare {tag}", 0.17)],
        "outcome": [_w(f"ride made {tag}", 0.6), _w(f"time spent {tag}", 0.4)],
        "setting": [_w(f"vehicle interior {tag}", 0.4), _w(f"road {tag}", 0.28), _w(f"network {tag}", 0.19), _w(f"sector {tag}", 0.13), _w("unknown", 0, "nothing more is stated")],
        "competence": competence or [_w(f"operating a thing {tag}", 0.4), _w(f"finding the way {tag}", 0.33), _w(f"trade know-how {tag}", 0.27)]}


def _answer4(n=1, form=None, competence=None):
    evs = [{"id": f"e{i}", "text": f"event {i}", "blind": _blind(chr(96 + i), form, competence), "relational": _rel()} for i in range(1, n + 1)]
    if n > 1:
        evs[0]["relational"]["links"] = [{"type": "concurrent", "other": "e2"}]
        evs[1]["relational"]["links"] = [{"type": "concurrent", "other": "e1"}]
    return {"verdict": "blind", "reason": "the key acts", "events": evs}


def good5(n=1, mode="occurred"):
    """A valid v5 answer: v4's events plus `mode` and `layers` (role and purpose among the form labels, a concrete sub-skill among the first competences)."""
    a = _answer4(n)
    for i, e in enumerate(a["events"], 1):
        tag = chr(96 + i)
        e["mode"] = mode
        e["layers"] = {"role": f"transport {tag}", "purpose": f"mobility {tag}", "sub_skill": f"operating a thing {tag}"}
    return a


# ---- the baseline: what v4 accepts and reports today ----
def test_baseline_v4_accepts_a_commuting_like_form_list_without_role_or_purpose():
    form = [_w("commuting", 0.3), _w("riding a vehicle", 0.24), _w("travel", 0.18), _w("transportation", 0.15), _w("regular activity", 0.13)]
    a = _answer4(1, form=form)  # no label names who the actor is in the act, and none says what the act is for
    validate_blind_answer(a, version=4)  # v4 accepts it: the undesired outcome (v4 pilot: commuter form 0.583, missing passenger and preparation for work)


def test_baseline_v4_events_carry_no_mode_and_reject_one():
    validate_blind_answer(_answer4(1), version=4)  # accepted without a mode
    a = _answer4(1)
    a["events"][0]["mode"] = "occurred"
    with pytest.raises(ValidationError, match="exactly"):
        validate_blind_answer(a, version=4)  # v4 has no place for a mode


def test_baseline_v4_overlap_metric_misses_a_near_copy_and_is_null_without_events():
    form = [_w("using public transport", 0.3), _w("travel", 0.24), _w("transport", 0.18), _w("mobility", 0.15), _w("routine", 0.13)]
    comp = [_w("use of public transport", 0.4, "the skill of using a service"), _w("finding the way", 0.33), _w("reading signs", 0.27)]
    bl = _answer4(1, form=form, competence=comp)["events"][0]["blind"]
    assert tp.competence_form_overlap(bl) == []  # the near-copy "use of public transport" is not counted
    assert tp.blind_v4_report({}, [])["competence_form_overlap_share"] is None  # null, and the report has no label-level counts
    assert "competence_form_overlap" not in tp.blind_v4_report({}, [])


# ---- mode (LI.74) ----
def test_v5_accepts_a_good_answer_and_several_events():
    validate_blind_answer(good5(1), version=5)
    validate_blind_answer(good5(2), version=5)


def test_v5_requires_a_mode_from_the_six():
    a = good5(1)
    del a["events"][0]["mode"]
    with pytest.raises(ValidationError, match="exactly|mode"):
        validate_blind_answer(a, version=5)
    b = good5(1)
    b["events"][0]["mode"] = "rumour"
    with pytest.raises(ValidationError, match="mode"):
        validate_blind_answer(b, version=5)
    for m in MODES:
        validate_blind_answer(good5(1, mode=m), version=5)
    c = good5(2)
    c["events"][1]["mode"] = "plan"  # a statement of several events: each event has its own mode
    validate_blind_answer(c, version=5)


def test_v5_modes_are_the_six_of_li74():
    from lifeimage.validate import BLIND_MODES
    assert BLIND_MODES == MODES


@pytest.mark.parametrize("mode", MODES)
@pytest.mark.parametrize("validation", ["formal", "attested", "claimed", "none", None])
def test_competence_basis_is_demonstrated_only_for_an_occurred_event_with_formal_or_attested_validation(mode, validation):
    want = "demonstrated" if mode == "occurred" and validation in ("formal", "attested") else "predicted"
    assert tp.competence_basis(mode, validation) == want


def test_competence_basis_rejects_unknown_inputs():
    with pytest.raises(ValueError, match="mode"):
        tp.competence_basis("rumour", "formal")
    with pytest.raises(ValueError, match="validation"):
        tp.competence_basis("occurred", "believed")


def test_the_basis_follows_the_record_not_the_agents_reading():
    # an agent marking an event `occurred` does not make it demonstrated: with no validation it stays predicted
    assert tp.competence_basis("occurred", None) == "predicted"
    assert tp.competence_basis("credential", "formal") == "predicted"  # a held credential is predicted competence even when formally recorded


# ---- form: role and purpose; competence: concrete sub-skills first (the `layers`) ----
def test_v5_rejects_what_v4_accepted_a_form_list_with_no_role_or_purpose_declared():
    a = good5(1)
    del a["events"][0]["layers"]
    with pytest.raises(ValidationError, match="exactly|layers"):
        validate_blind_answer(a, version=5)
    b = good5(1)
    b["events"][0]["layers"]["role"] = "passenger"  # a role no form label carries
    with pytest.raises(ValidationError, match="role"):
        validate_blind_answer(b, version=5)
    c = good5(1)
    c["events"][0]["layers"]["purpose"] = "going somewhere"
    with pytest.raises(ValidationError, match="purpose"):
        validate_blind_answer(c, version=5)


def test_v5_a_layer_may_be_none_only_with_a_one_line_reason():
    a = good5(1)
    a["events"][0]["layers"]["purpose"] = {"none": "a sale's purpose is the sale itself; no further purpose follows from the act"}
    validate_blind_answer(a, version=5)
    a["events"][0]["layers"]["purpose"] = {"none": ""}
    with pytest.raises(ValidationError, match="purpose"):
        validate_blind_answer(a, version=5)
    a["events"][0]["layers"]["purpose"] = None
    with pytest.raises(ValidationError, match="purpose"):
        validate_blind_answer(a, version=5)


def test_v5_role_and_purpose_are_two_labels_not_one():
    a = good5(1)
    a["events"][0]["layers"]["purpose"] = a["events"][0]["layers"]["role"]
    with pytest.raises(ValidationError, match="role|purpose"):
        validate_blind_answer(a, version=5)


def test_v5_layers_have_exactly_the_three_keys():
    a = good5(1)
    a["events"][0]["layers"]["mood"] = "calm"
    with pytest.raises(ValidationError, match="layers"):
        validate_blind_answer(a, version=5)
    b = good5(1)
    del b["events"][0]["layers"]["sub_skill"]
    with pytest.raises(ValidationError, match="layers"):
        validate_blind_answer(b, version=5)


def test_v5_the_sub_skill_is_a_competence_label_in_the_concrete_half_of_the_list():
    a = good5(1)
    a["events"][0]["layers"]["sub_skill"] = "trade know-how a"  # the broadest competence, last of three
    with pytest.raises(ValidationError, match="sub_skill|concrete"):
        validate_blind_answer(a, version=5)
    b = good5(1)
    b["events"][0]["layers"]["sub_skill"] = "no such skill"
    with pytest.raises(ValidationError, match="sub_skill"):
        validate_blind_answer(b, version=5)
    c = good5(1)
    c["events"][0]["layers"]["sub_skill"] = "finding the way a"  # second of three: within the first half rounded up
    validate_blind_answer(c, version=5)
    d = good5(1)
    d["events"][0]["layers"]["sub_skill"] = {"none": "the act asks for no perceptual or procedural skill, only general knowledge"}
    validate_blind_answer(d, version=5)


def test_v5_keeps_v4_rules():
    a = good5(1)
    a["events"][0]["blind"]["setting"][-1]["weight"] = 0.2
    with pytest.raises(ValidationError, match="unknown|zero|weight"):
        validate_blind_answer(a, version=5)
    b = good5(1)
    b["events"][0]["blind"]["form"] = b["events"][0]["blind"]["form"][:3]
    with pytest.raises(ValidationError, match="form"):
        validate_blind_answer(b, version=5)
    c = good5(1)
    c["events"][0]["blind"]["form"][0]["label"] = "c.cooking"
    with pytest.raises(ValidationError, match="domain id"):
        validate_blind_answer(c, version=5)
    d = good5(1)
    d["events"][0]["blind"]["competence"] = None
    d["events"][0]["short_reason"] = {"competence": "the statement shows no skill exercised"}
    d["events"][0]["layers"]["sub_skill"] = {"none": "no competence is listed"}
    validate_blind_answer(d, version=5)
    d["events"][0]["layers"]["sub_skill"] = "operating a thing a"  # a sub-skill in a list that does not exist
    with pytest.raises(ValidationError, match="sub_skill"):
        validate_blind_answer(d, version=5)


def test_v4_validation_is_unchanged_by_v5():
    validate_blind_answer(_answer4(1), version=4)
    with pytest.raises(ValidationError):
        validate_blind_answer(good5(1), version=4)  # mode and layers are v5 only


def test_v5_answers_pass_the_runner_validator_with_the_header_version(tmp_path):
    items = [{"id": "cal.a", "text": "A baker sells bread at the market"}]
    (bp,) = tp.write_blind_batches("t", tp.build_blind_batches(items, variants=1, prompt_version=5), tmp_path, prompt_version=5)
    lines = bp.read_text(encoding="utf-8").splitlines()
    t = json.loads(lines[1])
    ans = {"task_id": t["task_id"], "task_type": "blind", "input_hash": t["input_hash"], "variant": 0, "model": json.loads(lines[0])["model"], "prompt_version": 5, **good5(2)}
    assert validate_answers(lines, [json.dumps(ans)]) == []
    del ans["events"][0]["mode"]
    assert validate_answers(lines, [json.dumps(ans)])


# ---- the competence/form overlap metric ----
def test_overlap_detail_counts_identical_and_near_copies():
    form = [_w("using public transport", 0.3), _w("travel", 0.24), _w("transport", 0.18), _w("mobility", 0.15), _w("routine", 0.13)]
    comp = [_w("use of public transport", 0.4, "the skill of using a service"), _w("travel", 0.33, "the skill of finding a route"), _w("reading signs", 0.27)]
    bl = _answer4(1, form=form, competence=comp)["events"][0]["blind"]
    d = tp.competence_form_overlap_detail(bl)
    assert d["identical"] == ["travel"]
    assert sorted(d["near"]) == ["travel", "use of public transport"]  # identical labels are near too
    assert tp.competence_form_overlap(bl) == ["travel"]  # the v4 function keeps its meaning


def test_overlap_detail_does_not_flag_unrelated_labels():
    bl = good5(1)["events"][0]["blind"]
    d = tp.competence_form_overlap_detail(bl)
    assert d == {"identical": [], "near": []}


# ---- the prompt ----
def _prompt():
    return (ROOT / "prompts" / "blind.v5.md").read_text(encoding="utf-8")


def _blocks():
    return [json.loads(b) for b in re.findall(r"```json\n(.*?)\n```", _prompt(), re.S)]


def test_prompt_v5_carries_the_author_examples_and_not_the_held_out_answers_or_the_profile_items():
    p = re.sub(r"\s+", " ", _prompt())
    for needle in ("form sale, retail, exchange, financial transaction", "content bread, baked goods, food, direct human-to-human transaction",
                   "outcome money input, inventory spent", "setting market, stall/store/shop, point of sale, retail, commerce, business",
                   "A baker sells bread at the market", "A woman buys a train ticket", "form purchase, booking, travel planning, logistics",
                   "content ticket/pass, receipt, train, public transportation", "outcome ticket obtained, promise obtained, seat booked, documentation",
                   "setting point of sale (rest unknown)"):
        assert needle in p, needle
    low = p.lower()
    assert not re.search(r"\bbus\b|\bbuses\b|\bpassenger", low)
    for held_out in ("commuter", "commuting", "polling station", "ballot", "arrival at work", "voting", "vote", "voter", "maize", "electoral", "turnout",
                     "vehicle ride", "democra", "journey made", "time spent travelling", "inside vehicle", "road network", "going to work", "preparation for work",
                     "work related", "pedestrian", "street sign", "getting on and off", "getting on/off", "recognising a bus", "bus travel"):
        assert held_out not in low, held_out
    for profile in ("county hospital", "treasurer", "category b", "master's degree", "study law", "violin", "good with numbers", "strong swimmer", "retired engineer"):
        assert profile not in low, profile
    assert not ID.search(p)
    for v in ("blind.v1.md", "blind.v2.md", "blind.v3.md", "blind.v4.md"):
        assert (ROOT / "prompts" / v).exists()  # earlier versions kept


def test_prompt_v5_teaches_role_and_purpose_in_form_with_a_new_event():
    p = re.sub(r"\s+", " ", _prompt())
    low = p.lower()
    for needle in ("the actor's role in the act", "customer", "patient", "tenant", "student", "purpose", "what the act is for", "besides the act", "every level",
                   "layers", "role", "sub_skill", "not the actor's private motive"):
        assert needle.lower() in low, needle
    assert "exam" in low  # the new event of the form lesson (an exam: the examinee, the qualification)
    exam = [e for b in _blocks() for e in b["events"] if "exam" in e["text"]]
    assert exam and all(e["layers"]["role"] and e["layers"]["purpose"] for e in exam)
    for e in exam:
        assert isinstance(e["layers"]["role"], str) and isinstance(e["layers"]["purpose"], str)


def test_prompt_v5_teaches_competence_sub_skills_first_with_a_new_event():
    p = re.sub(r"\s+", " ", _prompt())
    low = p.lower()
    for needle in ("sub-skill", "perceiving", "recognising", "operating", "navigating", "reading", "following a procedure", "before broader capabilities",
                   "perceptual or procedural", "concrete"):
        assert needle in low, needle
    prune = [e for b in _blocks() for e in b["events"] if "prune" in e["text"]]
    assert prune and isinstance(prune[0]["layers"]["sub_skill"], str)
    comp = [c["label"] for c in prune[0]["blind"]["competence"]]
    assert comp.index(prune[0]["layers"]["sub_skill"]) < 2


def test_prompt_v5_teaches_the_mode_with_six_values_and_profile_statements():
    p = re.sub(r"\s+", " ", _prompt())
    low = p.lower()
    for m in MODES:
        assert m in low, m
    for needle in ("`mode`", "predicted", "demonstrated", "profile", "is a nurse", "holds a driving licence", "plans to study law", "i'm good with numbers"):
        pass
    for needle in ("`mode`", "predicted", "demonstrated", "profile", "the pipeline"):
        assert needle in low, needle
    modes = {e["mode"] for b in _blocks() for e in b["events"]}
    assert "occurred" in modes and len(modes) >= 2, "an example shows a profile-like mode"
    cred = [e for b in _blocks() for e in b["events"] if e["mode"] != "occurred"]
    assert all(e["blind"]["competence"] for e in cred)


def test_prompt_v5_names_the_outcome_contrast_with_a_new_example():
    p = re.sub(r"\s+", " ", _prompt())
    low = p.lower()
    for needle in ("a sequel the statement does not state", "another entity's act", "even when", "paraphrase", "in other words", "kettle"):
        assert needle in low, needle
    assert "letter delivered" in low  # the v4 contrast is kept; the kettle is the new contrast


def test_prompt_v5_examples_are_valid_v5_answers():
    blocks = _blocks()
    assert len(blocks) >= 6
    for b in blocks:
        validate_blind_answer({"verdict": "blind", "reason": "r", **b}, version=5)
    assert any(len(b["events"]) >= 2 for b in blocks), "one example is a compound statement split into events"
    assert all(equal_step_ladders(e["blind"]) == [] for b in blocks for e in b["events"]), "no example teaches the ladder"
    assert any("short_reason" in e for b in blocks for e in b["events"])
    assert any(isinstance(e["layers"][k], dict) for b in blocks for e in b["events"] for k in e["layers"]), "an example shows a declared none"
    for b in blocks:
        for e in b["events"]:
            assert isinstance(e["layers"]["role"], str) or "role" in json.dumps(e["layers"]["role"])
            ls = e["blind"]["setting"]
            if ls and ls[-1]["label"] == "unknown":
                assert ls[-1]["weight"] == 0


def test_prompt_v5_keeps_the_v4_rules():
    p = re.sub(r"\s+", " ", _prompt())
    for needle in ("at least 5", "at least 4", "at least 2", "short_reason", "up to 10", "weight 0", "the event itself makes true", "likely but unstated", "split",
                   "part_of", "causes", "concurrent", "issue ticket", "no fixed ladder", "competence", "skills and know-how", "acting entity", "at least 3",
                   "concrete to generic", "ordinary inference"):
        assert needle in p, needle


# ---- profile statements and the pilot batches ----
def test_there_are_eight_profile_statements_two_per_profile_mode_with_gold_modes():
    items = tp.profile_items()
    assert len(items) == 8 and len({i["id"] for i in items}) == 8
    gold = tp.profile_gold()
    assert set(gold) == {i["id"] for i in items}
    assert sorted(gold.values()) == sorted(["role", "role", "credential", "credential", "plan", "plan", "self_assessment", "self_assessment"])
    assert all(set(i) == {"id", "text"} for i in items), "the gold mode is not in the task input"
    assert all(i["id"].startswith("prof.") for i in items)


def test_profile_statements_are_invented_with_no_real_people():
    for i in tp.profile_items():
        assert not re.search(r"\b[A-Z][a-z]+ [A-Z][a-z]+\b", i["text"].replace("A woman", "").replace("A man", ""))  # no full personal name
        assert len(i["text"]) < 90


def test_pilot_v5_batches_cover_the_32_controls_and_8_profile_statements_in_two_variants(tmp_path):
    paths = tp.pilot_blind_batches(tmp_path, prompt_version=5, sets=("controls",))
    assert sorted(p.name for p in paths) == [f"blind.v5.controls.var{v}.part0.jsonl" for v in (0, 1)]
    prof = {i["id"] for i in tp.profile_items()}
    for p in paths:
        lines = p.read_text(encoding="utf-8").splitlines()
        h = json.loads(lines[0])
        assert h["prompt_version"] == 5 and h["task_type"] == "blind" and len(lines) - 1 == 40
        assert h["prefix"].startswith(_prompt().rstrip("\n")) and not ID.search(p.read_text(encoding="utf-8"))
        tasks = [json.loads(l) for l in lines[1:]]
        assert prof <= {t["input"]["item"]["id"] for t in tasks}
        assert json.loads(lines[1])["prompt_version"] == 5
    assert tp.LATEST_BLIND_VERSION == 5


def test_earlier_pilot_versions_stay_32_controls(tmp_path):
    (p, *_) = tp.pilot_blind_batches(tmp_path, prompt_version=4, sets=("controls",))
    assert len(p.read_text(encoding="utf-8").splitlines()) - 1 == 32
    assert len(tp.pilot_items()["controls"]) == 32


# ---- label_match: held-out, rejected, and the fresh slot ----
def test_the_fresh_held_out_slot_exists_and_is_empty_until_the_author_provides_categorisations():
    assert lm.HELD_OUT_FRESH == {}
    assert lm.fresh_items() == []
    assert set(lm.HELD_OUT) == {"cal.s08", "cal.s04"} and lm.DEVELOPMENT_ITEMS == ("cal.s08", "cal.s04")
    assert lm.held_out(5) == lm.held_out(4)


def test_a_fresh_entry_enters_the_held_out_labels_from_v5_only(monkeypatch):
    monkeypatch.setitem(lm.HELD_OUT_FRESH, "fresh.01", {"text": "A clerk files a form", "form": ["filing", "paperwork"], "outcome": ["form filed"]})
    assert lm.held_out(5)["fresh.01"] == {"form": ["filing", "paperwork"], "outcome": ["form filed"]}
    assert "fresh.01" not in lm.held_out(4)
    assert lm.fresh_items() == [{"id": "fresh.01", "text": "A clerk files a form"}]
    assert {"id": "fresh.01", "text": "A clerk files a form"} in tp.pilot_items(5)["controls"]
    assert {"id": "fresh.01", "text": "A clerk files a form"} not in tp.pilot_items(4)["controls"]


def _pairs(tmp_path, n_events=1, extra=()):
    ids = ("cal.d01", "cal.d02", "cal.s04", "cal.s08", "cal.m02") + tuple(extra)
    items = [{"id": k, "text": f"text of {k}"} for k in ids]
    paths = tp.write_blind_batches("t", tp.build_blind_batches(items, prompt_version=5), tmp_path, prompt_version=5)
    out = []
    for p in paths:
        lines = p.read_text(encoding="utf-8").splitlines()
        ans = [json.dumps({"task_id": json.loads(l)["task_id"], "task_type": "blind", "input_hash": json.loads(l)["input_hash"],
                           "variant": json.loads(l)["variant"], "model": json.loads(lines[0])["model"], "prompt_version": 5, **good5(n_events)})
               for l in lines[1:]]
        ap = p.with_name(p.name.replace(".jsonl", ".answers.jsonl"))
        ap.write_text("\n".join(ans) + "\n", encoding="utf-8")
        out.append((p, ap))
    return out


def test_label_match_v5_batches_cover_in_prompt_held_out_and_negative_labels(tmp_path):
    pairs = _pairs(tmp_path)
    b = lm.build_label_match_batches(pairs, authors={**lm.AUTHOR_LABELS, **lm.held_out(5)}, negatives=lm.NEGATIVE_LABELS)
    tasks = [json.loads(l) for v in b.values() for l in v[1:]]
    per_variant = 16 + 13 + (9 + 4 + 2 + 6 + 5) + 2 + (5 + 3 + 4 + 4)
    assert len(tasks) == 2 * per_variant
    assert {t["variant"] for t in tasks} == {0, 1}


def test_label_match_v5_batches_include_a_fresh_item_once_it_is_provided(tmp_path, monkeypatch):
    monkeypatch.setitem(lm.HELD_OUT_FRESH, "fresh.01", {"text": "A clerk files a form", "form": ["filing", "paperwork"], "outcome": ["form filed"]})
    pairs = _pairs(tmp_path, extra=("fresh.01",))
    b = lm.build_label_match_batches(pairs, authors={**lm.AUTHOR_LABELS, **lm.held_out(5)}, negatives=lm.NEGATIVE_LABELS)
    tasks = [json.loads(l) for v in b.values() for l in v[1:]]
    assert sum(1 for t in tasks if t["input"]["item"]["id"] == "fresh.01") == 2 * 3


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


def _meta(variant=0):
    return {"task_id": "x", "input_hash": "h", "variant": variant, "prompt_version": 5, "model": "m", "task_type": "blind"}


def test_report_v5_judges_the_pre_registered_predictions(tmp_path):
    pairs = _pairs(tmp_path, n_events=2)
    b = lm.build_label_match_batches(pairs, authors={**lm.AUTHOR_LABELS, **lm.held_out(5)}, negatives=lm.NEGATIVE_LABELS)
    rep = tp.blind_v5_report(tp.answers_by_item(pairs), _judge(b, lambda t: ("match", "r0")))
    p = rep["predictions"]
    assert rep["competence_form_overlap_share"] == 0.0 and p["competence_form_overlap_at_most_20pct"] is True
    assert rep["competence_form_overlap"]["events"] == 20 and rep["competence_form_overlap"]["labels_identical"] == 0
    assert p["commuter_form_at_least_0.7"] is True and p["commuter_competence_at_least_0.5"] is True
    assert p["ballot_all_facets_at_least_0.6"] is True and p["in_prompt_match_at_least_0.85"] is True
    assert p["rejected_outcomes_bad_at_most_1_of_4"] is False  # the negatives matched in this fixture
    assert rep["negatives_judged"] == {"judgements": 4, "match_or_partial": 4}
    assert p["median_labels_at_least_minimum"] is True and p["maize_split_in_both_variants"] is True
    assert p["mode_correct_at_least_90pct_of_profile"] is None  # no profile statement in this fixture
    assert p["fresh_held_out_at_least_0.6"] is None  # the fresh slot is empty
    rep2 = tp.blind_v5_report(tp.answers_by_item(pairs), _judge(b, lambda t: ("none", None) if t["input"]["item"]["id"] == "cal.s08" and t["input"]["relation"] == "form"
                                                               else ("partial", "r0") if t["input"]["author_label"] in ("arrival at work", "passenger carried") and t["variant"] == 0
                                                               else ("none", None) if t["input"]["author_label"] in ("arrival at work", "passenger carried") else ("match", "r0")))
    q = rep2["predictions"]
    assert q["commuter_form_at_least_0.7"] is False
    assert rep2["negatives_judged"] == {"judgements": 4, "match_or_partial": 2} and q["rejected_outcomes_bad_at_most_1_of_4"] is False
    rep3 = tp.blind_v5_report(tp.answers_by_item(pairs), _judge(b, lambda t: ("partial", "r0") if t["input"]["author_label"] == "arrival at work" and t["variant"] == 0
                                                               else ("none", None) if t["input"]["author_label"] in ("arrival at work", "passenger carried") else ("match", "r0")))
    assert rep3["negatives_judged"] == {"judgements": 4, "match_or_partial": 1} and rep3["predictions"]["rejected_outcomes_bad_at_most_1_of_4"] is True


def test_report_v5_scores_the_mode_of_the_profile_statements():
    gold = tp.profile_gold()
    by_item = {}
    for i, (iid, m) in enumerate(sorted(gold.items())):
        by_item[iid] = {0: ("t", {**good5(1, mode=m), **_meta(0)}), 1: ("t", {**good5(1, mode=m if i != 0 else "claim"), **_meta(1)})}
    rep = tp.blind_v5_report(by_item, [])
    assert rep["mode_profile"] == {"correct": 15, "total": 16, "share": 15 / 16}
    assert rep["predictions"]["mode_correct_at_least_90pct_of_profile"] is True
    by_item["prof.01"][0] = ("t", {**good5(1, mode="plan"), **_meta(0)})
    rep = tp.blind_v5_report(by_item, [])
    assert rep["mode_profile"]["correct"] == 14 and rep["predictions"]["mode_correct_at_least_90pct_of_profile"] is False  # 14 of 16 is under 90%
    assert rep["mode_counts_other_items"] == {}


def test_report_v5_a_split_profile_answer_is_correct_only_when_every_event_has_the_gold_mode():
    gold = tp.profile_gold()
    iid = sorted(gold)[0]
    a = good5(2, mode=gold[iid])
    a["events"][1]["mode"] = "occurred"
    rep = tp.blind_v5_report({iid: {0: ("t", {**a, **_meta(0)})}}, [])
    assert rep["mode_profile"] == {"correct": 0, "total": 1, "share": 0.0}


def test_report_v5_overlap_reports_a_number_and_catches_near_copies():
    form = [_w("using public transport", 0.3), _w("travel", 0.24), _w("transport", 0.18), _w("mobility", 0.15), _w("routine", 0.13)]
    comp = [_w("use of public transport", 0.4, "the skill of using a service"), _w("finding the way", 0.33), _w("reading signs", 0.27)]
    a = good5(1)
    a["events"][0]["blind"] = _blind("a", form=form, competence=comp)
    a["events"][0]["layers"] = {"role": "travel", "purpose": "mobility", "sub_skill": "use of public transport"}
    rep = tp.blind_v5_report({"cal.m02": {0: ("t", {**a, **_meta(0)})}}, [])
    ov = rep["competence_form_overlap"]
    assert ov["events"] == 1 and ov["events_identical"] == 0 and ov["events_near"] == 1
    assert rep["competence_form_overlap_share"] == 0.0 and ov["share_events_near"] == 1.0  # the prediction line is the identical-label share; near-copies are reported
    assert rep["predictions"]["competence_form_overlap_at_most_20pct"] is True


def test_report_v5_reports_the_layers_declared_none():
    a = good5(2)
    a["events"][0]["layers"]["purpose"] = {"none": "no purpose beyond the act"}
    a["events"][1]["layers"]["sub_skill"] = {"none": "no concrete skill"}
    rep = tp.blind_v5_report({"cal.m02": {0: ("t", {**a, **_meta(0)})}}, [])
    assert rep["layers_none"] == {"role": 0, "purpose": 1, "sub_skill": 1, "events": 2}


def test_report_v5_fresh_items_are_judged_apart_from_the_development_set(tmp_path, monkeypatch):
    monkeypatch.setitem(lm.HELD_OUT_FRESH, "fresh.01", {"text": "A clerk files a form", "form": ["filing", "paperwork"], "outcome": ["form filed"]})
    pairs = _pairs(tmp_path, extra=("fresh.01",))
    b = lm.build_label_match_batches(pairs, authors={**lm.AUTHOR_LABELS, **lm.held_out(5)}, negatives=lm.NEGATIVE_LABELS)
    rep = tp.blind_v5_report(tp.answers_by_item(pairs), _judge(b, lambda t: ("match", "r0") if t["input"]["item"]["id"] != "fresh.01" else ("none", None)))
    assert rep["heldout_fresh"] == {"fresh.01": {"form": 0.0, "outcome": 0.0}}
    assert rep["predictions"]["fresh_held_out_at_least_0.6"] is False
    assert "fresh.01" not in rep["heldout_match"]
    assert rep["predictions"]["commuter_form_at_least_0.7"] is True


# ---- the pre-registration, the overfitting note, the governed value, the CLI ----
def test_predictions_are_preregistered_before_any_answer_exists():
    t = (ROOT / "data" / "gold" / "blind_v5_predictions.md").read_text(encoding="utf-8")
    for needle in ("Confidence 0.5", "0.7", "0.6", "cal.s08", "cal.s04", "1 of 4", "90%", "20%", "0.85", "HELD_OUT_FRESH", "development set", "no longer a clean",
                   "mode", "competence_basis", "profile", "form", "competence", "label_match.v1", "blind.v5", "overlap", "identical"):
        assert needle in t, needle
    assert not list((ROOT / "data" / "batches").glob("blind.v5.*.answers.jsonl")) or "judged" in t


def test_governed_value_of_blind_v5_is_listed():
    from lifeimage.governed import GOVERNED
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    assert GOVERNED["blind.v5.concrete_first_share"]["default"] == 0.5 and "blind.v5.concrete_first_share" in readme


def test_build_script_knows_v5():
    src = (ROOT / "tools" / "build_two_pass.py").read_text(encoding="utf-8")
    for needle in ("report_v5", "--blind-version 5", "blind.v5 controls"):
        assert needle in src, needle
