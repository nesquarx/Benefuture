"""LI.70 refined by the two-pass diagnosis (`data/gold/two_pass_diagnosis.md`): the hybrid pass 2 `map.v2` builds memberships by the
v4 rule from the event text with the blind labels as hints; a label may match several domains (a fine domain and its coarse parent);
an obvious domain no label named is an `unlabelled_add`. `map.v1` stays reproducible."""
import copy
import json
from pathlib import Path

import pytest

import lifeimage.membership_wide as mw
import lifeimage.two_pass as tp
from lifeimage.membership import DEFAULT_OUT
from lifeimage.validate import ValidationError, validate_answers

from test_two_pass import (CARDS, RELS, _blind_files, _card, _logs_to_tmp, _map_answer, _sign, _write_answers)  # noqa: F401

ROOT = Path(__file__).resolve().parent.parent
CARDS2 = CARDS + [_card("c.neighbours_community", "Neighbours and community", "People living near each other", up="s.home")]


def _v2_answer(task):
    """A valid map.v2 answer: the blind label `baking` matches the fine domain and its coarse parent, the setting is an unlabelled add."""
    a = _map_answer(task)
    a["unlabelled_add"] = []
    if task["input"]["item"]["id"] == "cal.a":
        i = next(n for n, l in enumerate(a["labels"]) if l["ref"] == "form.0")
        a["labels"][i:i + 1] = [{"ref": "form.0", "action": "match", "domain": "f.baking_bread", "kind": "synonym", "match": 0.85},
                                {"ref": "form.0", "action": "match", "domain": "c.cooking", "kind": "synonym", "match": 0.7}]
        a["types"]["form"] = {"f.baking_bread": 0.6, "c.cooking": 0.4}
        a["ranks"]["form"]["listed"] = [{"domain": "f.baking_bread", "fit": 9}, {"domain": "c.cooking", "fit": 8}]
        a["types"]["setting"] = {"c.neighbours_community": 1.0}
        a["ranks"]["setting"] = {"listed": [{"domain": "c.neighbours_community", "fit": 7}], "rejected": {"domain": "c.sleep", "fit": 1}}
        a["unlabelled_add"] = [{"relation": "setting", "domain": "c.neighbours_community"}]
    return a


def _ctx(tmp_path, version=2):
    pairs = _blind_files(tmp_path)
    b = tp.build_map_batches(pairs, CARDS2, prompt_version=version)
    tasks = {json.loads(l)["input"]["item"]["id"]: json.loads(l) for l in b[(0, 0)][1:]}
    entries = tp.pack_entries(json.loads(b[(0, 0)][0])["prefix"])
    return pairs, b, tasks, entries


# ---- the outcome of map.v1 (kept reproducible): a label allocates to one domain, so the coarse parent cannot be listed with its child ----
def test_baseline_map_v1_rejects_a_label_matched_to_a_fine_domain_and_its_coarse_parent(tmp_path):
    _, _, tasks, entries = _ctx(tmp_path, version=1)
    t = tasks["cal.a"]
    a = _sign(t, _v2_answer(t))
    a.pop("unlabelled_add")
    with pytest.raises(ValidationError, match="twice|duplicate"):
        tp.validate_map_answer(a, t, entries)


def test_baseline_map_v1_rejects_a_listed_domain_no_blind_label_matched(tmp_path):
    _, _, tasks, entries = _ctx(tmp_path, version=1)
    t = tasks["cal.a"]
    a = _sign(t, _map_answer(t))
    a["types"]["setting"] = {"c.neighbours_community": 1.0}
    a["ranks"]["setting"] = {"listed": [{"domain": "c.neighbours_community", "fit": 7}], "rejected": {"domain": "c.sleep", "fit": 1}}
    with pytest.raises(ValidationError, match="anchored|no blind label"):
        tp.validate_map_answer(a, t, entries)


def test_map_v1_batches_and_answers_stay_reproducible(tmp_path):
    pairs = _blind_files(tmp_path)
    b = tp.build_map_batches(pairs, CARDS2)  # default version 1
    h = json.loads(b[(0, 0)][0])
    assert h["prompt_version"] == 1 and "unlabelled_add" not in h["prefix"]
    _, _, tasks, entries = _ctx(tmp_path, version=1)
    for t in tasks.values():
        tp.validate_map_answer(_sign(t, _map_answer(t)), t, entries)  # no version argument: v1 rules


# ---- map.v2 ----
def test_map_v2_prefix_states_the_hybrid_rule_and_batches_name_version_2(tmp_path):
    pairs, b, tasks, entries = _ctx(tmp_path)
    h = json.loads(b[(0, 0)][0])
    assert h["prompt_version"] == 2 and h["task_type"] == "map"
    for needle in ("unlabelled_add", "several domains", "coarse parent", "from the event text"):
        assert needle in h["prefix"], needle
    assert all(json.loads(l)["prompt_version"] == 2 for l in b[(0, 0)][1:])
    paths = tp.write_map_batches("t", b, tmp_path, prompt_version=2)
    assert sorted(p.name for p in paths) == ["map.v2.t.var0.part0.jsonl", "map.v2.t.var1.part0.jsonl"]


def test_map_v2_accepts_a_label_matched_to_a_fine_domain_and_its_parent_and_an_unlabelled_add(tmp_path):
    _, _, tasks, entries = _ctx(tmp_path)
    for t in tasks.values():
        tp.validate_map_answer(_sign(t, _v2_answer(t)), t, entries, version=2)


def _bad(tasks, item, edit):
    t = tasks[item]
    a = _sign(t, _v2_answer(t))
    edit(a)
    return t, a


@pytest.mark.parametrize("edit,msg", [
    (lambda a: a.pop("unlabelled_add"), "unlabelled_add"),
    (lambda a: a.update(unlabelled_add=[]), "anchored|unlabelled"),  # the listed setting is then named nowhere
    (lambda a: a["unlabelled_add"].append({"relation": "setting", "domain": "c.neighbours_community"}), "twice|duplicate"),
    (lambda a: a["unlabelled_add"].append({"relation": "form", "domain": "c.cooking"}), "matched by a label|marked"),  # a label matched it
    (lambda a: a["unlabelled_add"].append({"relation": "content", "domain": "c.sleep"}), "not listed|types"),
    (lambda a: a["unlabelled_add"].append({"relation": "colour", "domain": "c.sleep"}), "relation"),
    (lambda a: a["unlabelled_add"][0].update(domain="c.nowhere"), "not in the pack"),
    (lambda a: a["unlabelled_add"][0].update(extra=1), "keys"),
    (lambda a: a["labels"].append({"ref": "form.0", "action": "noise", "reason": "r"}), "only entry|alone|twice"),
    (lambda a: a["labels"].append({"ref": "form.0", "action": "match", "domain": "c.cooking", "kind": "synonym", "match": 0.5}), "twice|duplicate|same domain"),
    (lambda a: [l for l in a["labels"] if l["ref"] == "form.0"][0].update(domain="c.nowhere"), "not in the pack"),
    (lambda a: a["labels"].__setitem__(slice(None), [l for l in a["labels"] if l["ref"] != "content.1"]), "every blind label"),
])
def test_map_v2_rejects(tmp_path, edit, msg):
    _, _, tasks, entries = _ctx(tmp_path)
    t, a = _bad(tasks, "cal.a", edit)
    with pytest.raises(ValidationError, match=msg):
        tp.validate_map_answer(a, t, entries, version=2)


def test_map_v2_answers_validate_through_the_runner_validator_by_header_version(tmp_path):
    pairs, b, _, _ = _ctx(tmp_path)
    paths = tp.write_map_batches("t", b, tmp_path, prompt_version=2)
    for p in paths:
        ap = _write_answers(p, _v2_answer)
        assert validate_answers(p.read_text(encoding="utf-8").splitlines(), ap.read_text(encoding="utf-8").splitlines()) == []


def _ingest(tmp_path, make=_v2_answer):
    pairs, b, _, _ = _ctx(tmp_path)
    mp = [(p, _write_answers(p, make)) for p in tp.write_map_batches("t", b, tmp_path, prompt_version=2)]
    kw = dict(synonyms_path=tmp_path / "syn.jsonl", escalation_path=tmp_path / "esc.jsonl", refinement_dir=tmp_path / "ref")
    return pairs, mp, tmp_path / "tp2.jsonl", kw, tp.ingest_two_pass(pairs, mp, tmp_path / "tp2.jsonl", **kw)


def test_ingest_keeps_the_coarse_parent_marks_the_unlabelled_add_and_logs_both_synonyms(tmp_path):
    pairs, mp, out, kw, rows = _ingest(tmp_path)
    by = {r["key"]: r for r in rows}
    a = by["cal.a"]
    assert list(a["memberships"]["form"]) == ["f.baking_bread", "c.cooking"] and list(a["memberships"]["setting"]) == ["c.neighbours_community"]
    assert a["unlabelled_add"] == {"setting": {"c.neighbours_community": 1.0}} and by["cal.b"]["unlabelled_add"] == {}
    assert a["map_version"] == 2
    syn = {(s["label"], s["domain"]): s for s in (json.loads(l) for l in kw["synonyms_path"].read_text().splitlines())}
    assert syn[("baking", "f.baking_bread")]["count"] == 2 and syn[("baking", "c.cooking")]["count"] == 2  # one label, two domains
    tp.ingest_two_pass(pairs, mp, out, **kw)
    assert {(s["label"], s["domain"]): s["count"] for s in (json.loads(l) for l in kw["synonyms_path"].read_text().splitlines())} == \
        {k: v["count"] for k, v in syn.items()}  # idempotent


def test_the_v2_table_and_escalations_have_their_own_paths():
    assert tp.table_path(2) != tp.table_path(1) and tp.table_path(1) == tp.TABLE
    assert tp.escalation_path(2) != tp.escalation_path(1) and tp.escalation_path(1) == tp.ESCALATIONS


def test_the_report_gives_per_variant_and_merged_recall_escalations_and_unlabelled_adds(tmp_path):
    pairs, mp, out, kw, rows = _ingest(tmp_path)
    controls = [{"id": "cal.a", "group": "multi", "text": "t", "fair": {"form": ["c.cooking", "f.baking_bread"]}, "bad": {},
                 "required": {"form": ["f.baking_bread"], "setting": ["c.neighbours_community"]}}]
    rep = tp.two_pass_report(controls, tp.answers_by_item(pairs), tp.answers_by_item(mp), synonyms=[], candidates=[], v4_recall=0.963)
    assert rep["recall_required"] == 1.0 and rep["recall_required_merged"] == 1.0
    assert rep["escalated_controls"] == 0 and rep["unlabelled_adds"] == 2 and rep["controls"] == 1
    assert rep["predictions"]["escalated_controls_at_most_24_of_32"] is True
    assert "recall_merged_at_least_0.926" in rep["predictions"]


def test_the_hybrid_predictions_are_registered_before_any_map_v2_answer_exists():
    text = (ROOT / "data" / "gold" / "two_pass_predictions.md").read_text(encoding="utf-8")
    for needle in ("map.v2", "0.913", "0.926", "unlabelled_add", "24 of 32", "confidence 0.55"):
        assert needle in text, needle
    assert not list((DEFAULT_OUT).glob("map.v2.*.answers.jsonl")) or "map.v2 judged" in text


def test_the_pilot_map_v2_batches_cover_the_32_controls_and_50_snippets(tmp_path):
    src = [DEFAULT_OUT / f"blind.v1.{s}.var{v}.part0.answers.jsonl" for s in ("controls", "snippets") for v in (0, 1)]
    if not all(p.exists() for p in src):
        pytest.skip("pass-1 pilot answers not present")
    paths = tp.pilot_map_batches(version=2, out_dir=tmp_path)
    assert sorted(p.name for p in paths) == [f"map.v2.{s}.var{v}.part0.jsonl" for s in ("controls", "snippets") for v in (0, 1)]
    counts = {p.name: len(p.read_text(encoding="utf-8").splitlines()) - 1 for p in paths}
    assert counts["map.v2.controls.var0.part0.jsonl"] == 32 and counts["map.v2.snippets.var1.part0.jsonl"] == 50
