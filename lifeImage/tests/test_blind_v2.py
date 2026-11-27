"""LI.71: `blind.v2`, categories from the most specific to the most generic with decreasing weights (summing to 1) and glosses, a facet per
relation, the outcome expected, the setting `unknown` when the statement gives none. Red first: v1 accepts the thin answer v2 exists to replace."""
import copy
import json
import re
from pathlib import Path

import pytest

import lifeimage.label_match as lm
import lifeimage.two_pass as tp
from lifeimage.validate import ValidationError, validate_answers, validate_blind_answer

ROOT = Path(__file__).resolve().parent.parent
ID = re.compile(r"\b[csf]\.[a-z][a-z0-9_]+\b")


def _w(label, weight, gloss):
    return {"label": label, "weight": weight, "gloss": gloss}


REL = {"participants": [{"ref": "p1", "role": "seller"}, {"ref": "p2", "role": "buyer"}], "action": "sells bread",
       "outcome": {"text": "money in, bread out", "counterfactual": None}, "links": []}


def good_v2():
    return {"verdict": "blind", "reason": "the key action is a sale", "relational": copy.deepcopy(REL), "blind": {
        "form": [_w("sale", 0.4, "handing goods over for money"), _w("retail", 0.28, "selling to final customers"),
                 _w("exchange", 0.2, "goods for value"), _w("financial transaction", 0.12, "a payment between parties")],
        "content": [_w("bread", 0.4, "the loaf sold"), _w("baked goods", 0.3, "flour products baked in an oven"),
                    _w("food", 0.2, "things eaten"), _w("direct person-to-person transaction", 0.1, "no intermediary platform")],
        "outcome": [_w("money received", 0.4, "the seller's cash goes up"), _w("inventory spent", 0.3, "the seller has fewer loaves"),
                    _w("bread obtained", 0.2, "the buyer holds the bread"), _w("money spent", 0.1, "the buyer's cash goes down")],
        "setting": [_w("market", 0.4, "an open-air place of trade"), _w("stall", 0.3, "a trader's counter at a market"),
                    _w("retail", 0.2, "the sphere of selling to consumers; here the place, not the act"), _w("commerce", 0.1, "trade in general")]}}


# ---- the baseline: the outcome v2 replaces, true of v1 today and after ----
def test_baseline_v1_accepts_one_or_two_broad_labels_per_relation_and_an_empty_outcome():
    thin = {"verdict": "blind", "reason": "r", "relational": copy.deepcopy(REL), "blind": {
        "form": [{"label": "commerce", "fit": 8, "gloss": "trade"}], "content": [{"label": "food", "fit": 7, "gloss": "things eaten"},
                                                                           {"label": "cooking", "fit": 5, "gloss": "preparing food"}],
        "outcome": None, "setting": [{"label": "market", "fit": 6, "gloss": "a place"}]}}
    validate_blind_answer(thin)  # v1: accepted, the undesired outcome


# ---- the v2 validator ----
def test_v2_accepts_a_good_answer_and_the_unknown_setting_marker():
    validate_blind_answer(good_v2(), version=2)
    a = good_v2()
    a["blind"]["setting"] = [_w("point of sale", 0.6, "where payment is taken"), _w("unknown", 0.4, "the statement gives no more")]
    validate_blind_answer(a, version=2)
    a["blind"]["setting"] = [_w("unknown", 1.0, "the statement gives no venue")]
    validate_blind_answer(a, version=2)


def test_v2_accepts_a_null_outcome_but_reports_the_thin_lists():
    a = good_v2()
    a["blind"]["outcome"] = None
    validate_blind_answer(a, version=2)
    a["blind"]["form"] = a["blind"]["form"][:2]
    a["blind"]["form"][0]["weight"], a["blind"]["form"][1]["weight"] = 0.6, 0.4
    validate_blind_answer(a, version=2)
    assert tp.thin_relations(a) == ["form", "outcome"]
    assert tp.thin_relations(good_v2()) == []


@pytest.mark.parametrize("edit,msg", [
    (lambda a: a["blind"]["form"].reverse(), "decreas"),
    (lambda a: a["blind"]["form"][1].update(weight=0.4), "decreas"),  # a tie is not decreasing
    (lambda a: a["blind"]["form"][0].update(weight=0.5), "sum"),
    (lambda a: a["blind"]["form"][0].update(weight=0), "weight"),
    (lambda a: a["blind"]["form"][0].update(weight="0.4"), "weight"),
    (lambda a: a["blind"]["form"][0].pop("gloss"), "label, weight, gloss"),
    (lambda a: a["blind"]["form"][0].update(gloss=""), "gloss"),
    (lambda a: a["blind"]["form"][0].update(fit=9), "label, weight, gloss"),
    (lambda a: a["blind"]["form"][0].update(label="c.cooking"), "domain id"),
    (lambda a: a["blind"]["form"][0].update(gloss="see f.baking_bread"), "domain id"),
    (lambda a: a["blind"]["form"][1].update(label="Sale"), "duplicate"),
    (lambda a: a["blind"]["form"].extend([_w(f"x{i}", 0.001 * (9 - i), f"g{i}") for i in range(5)]), "at most 8"),
    (lambda a: a["blind"].update(setting=[_w("unknown", 0.5, "none given"), _w("unknown ", 0.5, "none given either")]), "unknown"),
    (lambda a: a["blind"].update(setting=[_w("unknown", 0.6, "none given"), _w("market", 0.4, "a place")]), "unknown"),  # unknown ends the list
    (lambda a: a["blind"].update(setting=None), "setting"),
    (lambda a: a["blind"].update(form=None), "form"),
    (lambda a: a["blind"].pop("outcome"), "exactly"),
])
def test_v2_rejects(edit, msg):
    a = good_v2()
    edit(a)
    with pytest.raises(ValidationError, match=msg):
        validate_blind_answer(a, version=2)


def test_v2_a_label_repeated_across_relations_needs_a_gloss_of_its_own():
    a = good_v2()
    a["blind"]["content"][1]["label"] = "retail"  # also a form label and a setting label
    a["blind"]["content"][1]["gloss"] = "selling to final customers"  # the form gloss, repeated
    with pytest.raises(ValidationError, match="repeated.*gloss"):
        validate_blind_answer(a, version=2)
    a["blind"]["content"][1]["gloss"] = "the retail trade as the subject matter"
    a["blind"]["setting"][2]["gloss"] = "selling to final customers"
    with pytest.raises(ValidationError, match="repeated.*gloss"):  # setting repeats the form gloss
        validate_blind_answer(a, version=2)
    a["blind"]["setting"][2]["gloss"] = "the sphere of selling to consumers; here the place, not the act"
    validate_blind_answer(a, version=2)


def test_v2_answers_pass_the_runner_validator_with_the_header_version(tmp_path):
    items = [{"id": "cal.a", "text": "A baker sells bread at the market"}]
    (bp,) = tp.write_blind_batches("t", tp.build_blind_batches(items, variants=1, prompt_version=2), tmp_path, prompt_version=2)
    lines = bp.read_text(encoding="utf-8").splitlines()
    t = json.loads(lines[1])
    ans = {"task_id": t["task_id"], "task_type": "blind", "input_hash": t["input_hash"], "variant": 0, "model": json.loads(lines[0])["model"],
           "prompt_version": 2, **good_v2()}
    assert validate_answers(lines, [json.dumps(ans)]) == []
    ans["blind"]["form"][0]["weight"] = 0.9
    assert any("sum" in e for e in validate_answers(lines, [json.dumps(ans)]))


# ---- the prompt ----
def _prompt():
    return (ROOT / "prompts" / "blind.v2.md").read_text(encoding="utf-8")


def test_prompt_v2_carries_the_author_examples_verbatim_and_the_rules():
    p = _prompt()
    for needle in ("form sale, retail,\nexchange, financial transaction", "content bread, baked goods, food, direct human-to-human transaction",
                   "outcome money input, inventory spent", "setting market, stall/store/shop, point of sale, retail, commerce, business",
                   "A baker sells bread at the market", "A woman buys a train ticket", "form purchase, booking, travel planning, logistics",
                   "content ticket/pass, receipt, train, public transportation", "outcome ticket obtained, promise obtained, seat booked, documentation",
                   "setting point of sale (rest unknown)"):
        assert needle.replace("\n", " ") in re.sub(r"\s+", " ", p), needle
    flat = re.sub(r"\s+", " ", p)
    for needle in ("4 to 8", "most specific", "sum to 1", "key action", "unknown", "issue ticket", "each party", "relational extraction"):
        assert needle in flat, needle
    assert not ID.search(p)
    assert (ROOT / "prompts" / "blind.v1.md").exists()  # old versions kept


def test_prompt_v2_examples_are_valid_answers():
    p = _prompt()
    blocks = [json.loads(b) for b in re.findall(r"```json\n(.*?)\n```", p, re.S)]
    assert len(blocks) >= 4  # author example 1 and 2, a domain in two relations, an unknown setting
    for b in blocks:
        validate_blind_answer({"verdict": "blind", "reason": "r", **b}, version=2)
    two = [b for b in blocks if len({e["label"].lower() for r in ("form", "content", "outcome", "setting") for e in (b["blind"][r] or [])})
           < sum(len(b["blind"][r] or []) for r in ("form", "content", "outcome", "setting"))]
    assert two, "one example has a label under two relations"
    assert any(b["blind"]["setting"][-1]["label"] == "unknown" for b in blocks)


# ---- the pilot batches ----
def test_pilot_v2_batches_cover_the_32_controls_in_two_variants_without_ids(tmp_path):
    paths = tp.pilot_blind_batches(tmp_path, prompt_version=2, sets=("controls",))
    assert sorted(p.name for p in paths) == [f"blind.v2.controls.var{v}.part0.jsonl" for v in (0, 1)]
    for p in paths:
        lines = p.read_text(encoding="utf-8").splitlines()
        h = json.loads(lines[0])
        assert h["prompt_version"] == 2 and h["task_type"] == "blind" and len(lines) - 1 == 32
        assert h["prefix"].startswith(_prompt().rstrip("\n")) and not ID.search(p.read_text(encoding="utf-8"))
        assert json.loads(lines[1])["prompt_version"] == 2


# ---- label_match.v1 ----
def test_author_labels_are_the_li71_lists():
    a = lm.AUTHOR_LABELS
    assert a["cal.d01"]["form"] == ["sale", "retail", "exchange", "financial transaction"]
    assert a["cal.d01"]["outcome"] == ["money input", "inventory spent"] and len(a["cal.d01"]["setting"]) == 6
    assert a["cal.d02"]["setting"] == ["point of sale"] and a["cal.d02"]["outcome"][0] == "ticket obtained"
    texts = {json.loads(l)["id"]: json.loads(l)["text"] for l in (ROOT / "data/gold/membership_wide_controls_v1.jsonl").read_text(encoding="utf-8").splitlines()}
    assert "baker" in texts["cal.d01"] and "train ticket" in texts["cal.d02"]


def _pairs(tmp_path):
    items = [{"id": "cal.d01", "text": "A baker named Mason sells bread at the market"}, {"id": "cal.d02", "text": "A woman buys a train ticket on a bank holiday"}]
    paths = tp.write_blind_batches("t", tp.build_blind_batches(items, prompt_version=2), tmp_path, prompt_version=2)
    out = []
    for p in paths:
        lines = p.read_text(encoding="utf-8").splitlines()
        ans = []
        for l in lines[1:]:
            t = json.loads(l)
            b = good_v2()
            if t["input"]["item"]["id"] == "cal.d02":
                b["blind"]["setting"] = [_w("point of sale", 0.7, "where the ticket is paid for"), _w("unknown", 0.3, "no more is stated")]
            ans.append(json.dumps({"task_id": t["task_id"], "task_type": "blind", "input_hash": t["input_hash"], "variant": t["variant"],
                                   "model": json.loads(lines[0])["model"], "prompt_version": 2, **b}))
        ap = p.with_name(p.name.replace(".jsonl", ".answers.jsonl"))
        ap.write_text("\n".join(ans) + "\n", encoding="utf-8")
        out.append((p, ap))
    return out


def test_label_match_batches_one_task_per_author_label_and_variant(tmp_path):
    b = lm.build_label_match_batches(_pairs(tmp_path))
    n = sum(len(v) - 1 for v in b.values())
    assert n == (16 + 13) * 2 and all(len(v) - 1 <= 50 for v in b.values())
    h = json.loads(b[0][0])
    assert h["task_type"] == "label_match" and h["prompt_version"] == 1
    t = json.loads(b[0][1])
    assert t["allowed_verdicts"] == ["match", "partial", "none"]
    assert set(t["input"]) == {"item", "relation", "author_label", "run"} and t["input"]["run"][0]["ref"] == "r0"
    assert not ID.search("\n".join(sum(b.values(), [])))


def test_label_match_prompt_exists_and_defines_the_three_verdicts():
    p = (ROOT / "prompts" / "label_match.v1.md").read_text(encoding="utf-8")
    for needle in ("match", "partial", "none", "same sense", "run_ref"):
        assert needle in p


def _judge(b, make):
    out = []
    for lines in b.values():
        for l in lines[1:]:
            t = json.loads(l)
            v, ref = make(t)
            out.append((t, {"task_id": t["task_id"], "task_type": "label_match", "input_hash": t["input_hash"], "variant": t["variant"],
                            "model": json.loads(lines[0])["model"], "prompt_version": 1, "verdict": v, "run_ref": ref, "reason": "r"}))
    return out


def test_label_match_validator(tmp_path):
    b = lm.build_label_match_batches(_pairs(tmp_path))
    ok = _judge(b, lambda t: ("match", "r0"))
    for t, a in ok[:3]:
        lm.validate_label_match_answer(a, t)
    t, a = ok[0]
    for edit, msg in ((lambda a: a.update(run_ref=None), "run_ref"), (lambda a: a.update(run_ref="r99"), "run_ref"),
                      (lambda a: a.update(verdict="none"), "none")):
        bad = dict(a)
        edit(bad)
        with pytest.raises(ValidationError, match=msg):
            lm.validate_label_match_answer(bad, t)
    n = dict(a, verdict="none", run_ref=None)
    lm.validate_label_match_answer(n, t)
    path = tmp_path / "x.jsonl"
    lines = next(iter(b.values()))
    assert validate_answers(lines, [json.dumps(a2) for tt, a2 in _judge({0: lines}, lambda t: ("none", None))]) == []


# ---- the report ----
def test_report_judges_the_preregistered_predictions(tmp_path):
    pairs = _pairs(tmp_path)
    b = lm.build_label_match_batches(pairs)
    # a judge that matches an author label iff the run holds the same normalised label, else partial for the form relation, none otherwise
    def judge(t):
        runs = {tp.norm_label(r["label"]): r["ref"] for r in t["input"]["run"]}
        n = tp.norm_label(t["input"]["author_label"])
        return ("match", runs[n]) if n in runs else ("none", None)
    judged = [(t, a) for t, a in _judge(b, judge)]
    rep = tp.blind_v2_report(tp.answers_by_item(pairs), judged)
    assert rep["median_labels"] == {"form": 4, "content": 4, "outcome": 4} and rep["outcome_present"] == 1.0
    assert rep["predictions"]["median_labels_at_least_4"] is True and rep["predictions"]["outcome_present_at_least_0.9"] is True
    assert rep["cooking_in_d01_form_or_content"] == 0 and rep["predictions"]["no_cooking_in_cal_d01_form_or_content"] is True
    assert set(rep["author_match_share"]) == {"form", "content", "outcome", "setting"}
    assert rep["predictions"]["author_match_at_least_0.6_each_relation"] is (min(rep["author_match_share"].values()) >= 0.6)


def test_report_flags_thin_lists_and_cooking():
    a = good_v2()
    a["blind"]["form"][2]["label"] = "cooking"
    a["blind"]["outcome"] = None
    item = {"cal.d01": {0: ("A baker sells bread at the market", {**a, "task_id": "x", "input_hash": "h", "variant": 0, "prompt_version": 2, "model": "m",
                                                                  "task_type": "blind"})}}
    rep = tp.blind_v2_report(item, [])
    assert rep["cooking_in_d01_form_or_content"] == 1 and rep["outcome_present"] == 0.0
    assert rep["predictions"]["no_cooking_in_cal_d01_form_or_content"] is False and rep["predictions"]["outcome_present_at_least_0.9"] is False


# ---- the pre-registration ----
def _preds():
    return (ROOT / "data" / "gold" / "blind_v2_predictions.md").read_text(encoding="utf-8")


def test_predictions_are_preregistered_before_any_answer_exists():
    t = _preds()
    for needle in ("Confidence 0.5", "4", "90%", "60%", "cal.d01", "cal.d02", "cooking", "label_match.v1", "blind.v2", "confound"):
        assert needle in t, needle
    assert not list((ROOT / "data" / "batches").glob("blind.v2.*.answers.jsonl")) or "judged" in t


def test_governed_values_of_blind_v2_are_listed():
    from lifeimage.governed import GOVERNED
    for k, d in (("blind.v2.max_labels", 8), ("blind.v2.min_labels", 4), ("blind.v2.weight_tolerance", 0.02)):
        assert GOVERNED[k]["default"] == d and k in (ROOT / "README.md").read_text(encoding="utf-8")


def test_leaf_domains_note_states_the_li71_rules_and_open_questions():
    t = (ROOT / "data" / "fine" / "LEAF_DOMAINS.md").read_text(encoding="utf-8")
    for needle in ("strongest tie", "polyhierarchy", "sense", "bleed", "refinement log", "synonym log", "upstream", "1,634", "Open questions"):
        assert needle in t, needle
