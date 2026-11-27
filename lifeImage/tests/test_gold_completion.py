"""LI.69: completing the calibration gold. The unjudged secondary domains of the v3 and v4 calibration are judged by runners
(`gold_judge.v1`, 2 variants); agreed verdicts extend the gold (v1, v0 kept), disputes wait for the author, and the calibration is
re-scored against the completed gold."""
import copy
import json
from pathlib import Path

import pytest

import lifeimage.membership_wide as mw
from lifeimage import gold_judge as gj
from lifeimage.membership import DEFAULT_PACK
from lifeimage.validate import validate_answers

ROOT = Path(__file__).resolve().parent.parent
PACK = DEFAULT_PACK.read_text(encoding="utf-8")
RELS = mw.RELS
REPORTS = {3: ROOT / "data/gold/membership_wide_calibration_report.json", 4: ROOT / "data/gold/membership_wide_calibration_report_v4.json"}


@pytest.fixture(autouse=True)
def refinement_dir(tmp_path, monkeypatch):
    monkeypatch.setattr(mw, "REFINEMENT_DIR", tmp_path / "refinement", raising=False)


def _ans(lists, rejected=("c.zzz", 2), version=4):
    types, ranks = {}, {}
    for rel in RELS:
        ds = lists.get(rel)
        if ds is None:
            types[rel], ranks[rel] = None, None
            continue
        n = len(ds)
        w = [n - i for i in range(n)]
        types[rel] = {d: x / sum(w) for d, x in zip(ds, w)}
        ranks[rel] = {"listed": [{"domain": d, "fit": 9 - i} for i, d in enumerate(ds)], "rejected": {"domain": rejected[0], "fit": rejected[1]}}
    return {"types": types, "ranks": ranks, "prompt_version": version, "model": "m"}


def _controls():
    return [{"id": "cal.s", "group": "single", "text": "A woman sleeps", "fair": {"form": ["c.sleep"]}, "bad": {"form": ["c.nutrition_diet"]}},
            {"id": "cal.m", "group": "multi", "text": "A girl cooks", "fair": {"form": ["c.cooking", "c.eating_drinking"]},
             "bad": {"form": ["c.sleep"]}, "required": {"form": ["c.cooking"]}}]


def _by(version=4):
    return {"cal.s": {0: ("A woman sleeps", _ans({"form": ["c.sleep", "c.hygiene_grooming", "c.nutrition_diet"]}, version=version)),
                      1: ("A woman sleeps", _ans({"form": ["c.sleep", "c.hygiene_grooming"]}, version=version))},
            "cal.m": {0: ("A girl cooks", _ans({"form": ["c.cooking", "c.eating_drinking", "c.food_purchasing"]}, version=version)),
                      1: ("A girl cooks", _ans({"form": ["c.cooking", "c.eating_drinking"]}, version=version))}}


# ---- red baseline: the outcome the incomplete gold produces ----
def test_baseline_unjudged_domains_count_against_precision_and_padding():
    r = mw.calibration_report(_controls(), _by())
    assert r["n_unjudged"] == 3  # hygiene_grooming x2 and food_purchasing: nobody judged them
    assert r["precision_judged"] == 2 / 3 and r["precision_secondary"] == 2 / 6
    assert r["precision_secondary"] < r["precision_judged"]  # the incomplete gold depresses the pre-registered metric
    assert r["padding_single"] == 1.0  # a fair-looking secondary counted as padding only because nobody judged it


def test_committed_reports_show_the_unjudged_stall():
    for v, n in ((3, 59), (4, 55)):
        rep = json.loads(REPORTS[v].read_text())
        assert len(rep["unjudged_secondary"]) == n and rep["precision_secondary"] < 0.8


# ---- the unjudged set, the task, the validator ----
def test_unjudged_entries_are_deduplicated_across_variants_and_versions():
    e = gj.unjudged_entries(_controls(), {3: _by(3), 4: _by(4)})
    assert [(x["item"], x["relation"], x["domain"]) for x in e] == [("cal.m", "form", "c.food_purchasing"), ("cal.s", "form", "c.hygiene_grooming")]
    assert e[1]["versions"] == [3, 4] and e[1]["variants"] == [0, 1]


def test_relation_meanings_come_from_the_membership_prompt():
    m = gj.relation_meanings()
    assert set(m) == set(RELS) and "what kind of act or thing" in m["form"] and "observably changed" in m["outcome"]


def _entries():
    return gj.unjudged_entries(_controls(), {3: _by(3), 4: _by(4)})


def _batches():
    return gj.build_gold_batches(_entries(), _controls(), PACK)


def test_task_shows_item_relation_meaning_domain_and_the_gold_lists_in_opposite_order_for_variants():
    b = _batches()
    t0, t1 = (json.loads(b[(v, 0)][1 + 1]) for v in (0, 1))  # cal.s is the second sorted item
    i0, i1 = t0["input"], t1["input"]
    assert i0["item"]["text"] == "A woman sleeps" and i0["relation"] == "form" and i0["domain"]["id"] == "c.hygiene_grooming"
    assert i0["domain"]["label"] and i0["domain"]["description"] and "what kind of act" in i0["meaning"]
    assert [d["id"] for d in i0["fair"]] == ["c.sleep"] and [d["id"] for d in i0["bad"]] == ["c.nutrition_diet"]
    t = json.loads(b[(0, 0)][1])  # cal.m: two fair domains, order reverses between variants
    u = json.loads(b[(1, 0)][1])
    assert [d["id"] for d in t["input"]["fair"]] == ["c.cooking", "c.eating_drinking"]
    assert [d["id"] for d in u["input"]["fair"]] == ["c.eating_drinking", "c.cooking"]
    assert t["allowed_verdicts"] == ["fair", "bad", "unsure"] and t["task_type"] == "gold_judge"


def test_prefix_is_stable_across_variants_parts_and_tasks_and_carries_the_relations():
    b = _batches()
    heads = {json.dumps(json.loads(b[k][0]), sort_keys=True) for k in b}
    assert len(heads) == 1  # one prefix: cache hits across every file
    h = json.loads(b[(0, 0)][0])
    assert h["task_type"] == "gold_judge" and h["prompt_version"] == 1 and "setting:" in h["prefix"]


def test_batches_are_at_most_fifty_tasks_per_file():
    entries = [{"item": "cal.s", "relation": "form", "domain": f"c.d{i}", "versions": [4], "variants": [0]} for i in range(120)]
    b = gj.build_gold_batches(entries, _controls(), PACK, check_domains=False)
    assert sorted(b) == [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)]
    assert all(len(v) - 1 <= 50 for v in b.values())


def _write_answers(tmp_path, verdicts):
    """verdicts: {(variant, item, domain): (verdict, reason)}; returns (batch, answers) pairs."""
    b = _batches()
    pairs = []
    for (v, p), lines in sorted(b.items()):
        bp, ap = tmp_path / f"b{v}{p}.jsonl", tmp_path / f"a{v}{p}.jsonl"
        bp.write_text("\n".join(lines) + "\n")
        out = []
        for line in lines[1:]:
            t = json.loads(line)
            verdict, reason = verdicts[(v, t["input"]["item"]["id"], t["input"]["domain"]["id"])]
            out.append(json.dumps({"task_id": t["task_id"], "task_type": t["task_type"], "input_hash": t["input_hash"], "variant": v,
                                   "model": json.loads(lines[0])["model"], "prompt_version": 1, "verdict": verdict, "reason": reason}))
        ap.write_text("\n".join(out) + "\n")
        pairs.append((bp, ap))
    return pairs


AGREE = {(v, "cal.s", "c.hygiene_grooming"): ("fair", "washing follows waking") for v in (0, 1)}
AGREE.update({(v, "cal.m", "c.food_purchasing"): ("bad", "shopping is not cooking") for v in (0, 1)})


def test_validator_accepts_the_three_verdicts_and_rejects_others(tmp_path):
    pairs = _write_answers(tmp_path, AGREE)
    assert all(not validate_answers(bp.read_text().splitlines(), ap.read_text().splitlines()) for bp, ap in pairs)
    for verdict in ("maybe", "membership", "FAIR", ""):
        bp, ap = pairs[0]
        lines = ap.read_text().splitlines()
        row = json.loads(lines[0])
        row["verdict"] = verdict
        errs = validate_answers(bp.read_text().splitlines(), [json.dumps(row)] + lines[1:])
        assert errs, verdict
    row["verdict"] = "unsure"
    assert not validate_answers(bp.read_text().splitlines(), [json.dumps(row)] + lines[1:])


def test_validator_rejects_a_reason_with_a_line_break_and_an_unknown_verdict_key(tmp_path):
    bp, ap = _write_answers(tmp_path, AGREE)[0]
    lines = ap.read_text().splitlines()
    row = json.loads(lines[0])
    row["reason"] = "a\nb"
    assert validate_answers(bp.read_text().splitlines(), [json.dumps(row)] + lines[1:])


# ---- completing the gold ----
def test_agreed_verdicts_extend_the_gold_with_provenance_and_v0_is_never_dropped(tmp_path):
    verdicts = dict(AGREE)
    pairs = _write_answers(tmp_path, verdicts)
    v0 = _controls()
    res = gj.complete_gold(v0, gj.read_verdicts(pairs))
    v1 = {c["id"]: c for c in res["controls"]}
    for c in v0:  # v0 kept: every fair, bad and required entry is still there, in order
        for k in ("fair", "bad", "required"):
            for rel, ds in c.get(k, {}).items():
                assert v1[c["id"]][k][rel][:len(ds)] == ds
    assert "c.hygiene_grooming" in v1["cal.s"]["fair"]["form"] and "c.food_purchasing" in v1["cal.m"]["bad"]["form"]
    p = v1["cal.s"]["provenance"]["form"]["c.hygiene_grooming"]
    assert p["verdict"] == "fair" and p["source"] == "gold_judge.v1" and len(p["reasons"]) == 2 and p["agreed"] is True
    assert res["disputed"] == [] and "provenance" not in v1.get("cal.none", {})
    assert [c["id"] for c in res["controls"]] == [c["id"] for c in v0]


def test_disputed_and_unsure_items_are_excluded_from_v1_until_reviewed(tmp_path):
    verdicts = dict(AGREE)
    verdicts[(0, "cal.s", "c.hygiene_grooming")] = ("fair", "r0")
    verdicts[(1, "cal.s", "c.hygiene_grooming")] = ("bad", "r1")  # variants differ
    verdicts[(0, "cal.m", "c.food_purchasing")] = ("unsure", "r0")  # one unsure
    verdicts[(1, "cal.m", "c.food_purchasing")] = ("bad", "r1")
    res = gj.complete_gold(_controls(), gj.read_verdicts(_write_answers(tmp_path, verdicts)))
    v1 = {c["id"]: c for c in res["controls"]}
    assert "c.hygiene_grooming" not in v1["cal.s"]["fair"]["form"] + v1["cal.s"]["bad"].get("form", [])
    assert "c.food_purchasing" not in v1["cal.m"]["fair"]["form"] + v1["cal.m"]["bad"]["form"]
    assert {(d["item"], d["domain"]) for d in res["disputed"]} == {("cal.s", "c.hygiene_grooming"), ("cal.m", "c.food_purchasing")}
    assert v1["cal.s"]["unsure"]["form"] == ["c.hygiene_grooming"]
    md = gj.disputed_review(res["disputed"], _controls(), PACK)
    assert "cal.s" in md and "c.hygiene_grooming" in md and "r0" in md and "r1" in md and "fair" in md and "bad" in md and "unsure" in md


def test_an_author_ruling_resolves_a_dispute_with_its_own_provenance(tmp_path):
    verdicts = {k: ("fair", "r") if k[0] == 0 else ("unsure", "r") for k in AGREE}
    rulings = [{"item": "cal.s", "relation": "form", "domain": "c.hygiene_grooming", "verdict": "fair"}]
    res = gj.complete_gold(_controls(), gj.read_verdicts(_write_answers(tmp_path, verdicts)), rulings=rulings)
    v1 = {c["id"]: c for c in res["controls"]}
    assert "c.hygiene_grooming" in v1["cal.s"]["fair"]["form"] and v1["cal.s"]["provenance"]["form"]["c.hygiene_grooming"]["source"] == "author"
    assert [(d["item"], d["domain"]) for d in res["disputed"]] == [("cal.m", "c.food_purchasing")]


def test_a_missing_variant_is_an_error_not_a_half_verdict(tmp_path):
    pairs = _write_answers(tmp_path, AGREE)
    with pytest.raises(ValueError, match="expected 2"):
        gj.complete_gold(_controls(), gj.read_verdicts(pairs[:1]))


def test_gold_is_written_in_v0_order_and_loads_through_the_ordinary_loader(tmp_path):
    res = gj.complete_gold(_controls(), gj.read_verdicts(_write_answers(tmp_path, AGREE)))
    p = tmp_path / "v1.jsonl"
    gj.write_controls(res["controls"], p)
    assert [c["id"] for c in mw.load_controls(p)] == ["cal.s", "cal.m"]


# ---- re-scoring against the complete gold ----
def test_complete_gold_removes_the_unjudged_stall_and_padding_counts_only_bad_or_unsure(tmp_path):
    v0 = mw.calibration_report(_controls(), _by())
    res = gj.complete_gold(_controls(), gj.read_verdicts(_write_answers(tmp_path, AGREE)))
    r = mw.calibration_report(res["controls"], _by(), complete_gold=True)
    assert v0["n_unjudged"] == 3 and r["n_unjudged"] == 0
    assert r["precision_secondary"] > v0["precision_secondary"] and r["precision_secondary"] == r["precision_judged"]
    assert r["padding_single_complete"] == 0.5  # only variant 0 of cal.s lists a gold-bad secondary (c.nutrition_diet)
    assert r["padding_single"] >= r["padding_single_complete"]  # old definition kept and reported
    by = _by()
    by["cal.s"][0] = ("A woman sleeps", _ans({"form": ["c.sleep", "c.hygiene_grooming"]}, version=4))
    r2 = mw.calibration_report(res["controls"], by, complete_gold=True)
    assert r2["padding_single_complete"] == 0.0 and r2["padding_single"] == 0.0


def test_padding_complete_counts_unsure_and_ignores_domains_nobody_judged():
    c = _controls()
    c[0]["unsure"] = {"form": ["c.hygiene_grooming"]}
    by = {"cal.s": {0: ("t", _ans({"form": ["c.sleep", "c.hygiene_grooming"]}))}}
    assert mw.calibration_report(c, by, complete_gold=True)["padding_single_complete"] == 1.0
    c[0]["unsure"] = {}
    r = mw.calibration_report(c, by, complete_gold=True)
    assert r["padding_single_complete"] == 0.0 and r["n_unjudged"] == 1 and r["padding_single"] == 1.0


def test_default_report_is_unchanged_without_the_flag():
    r = mw.calibration_report(_controls(), _by())
    assert "padding_single_complete" not in r
    assert r["padding_single"] == 1.0


def test_gold_v1_report_name_and_cli_flag():
    assert gj.report_path(3, "v1").name == "membership_wide_calibration_report_v3_gold_v1.json"
    assert gj.report_path(4, "v1").name == "membership_wide_calibration_report_v4_gold_v1.json"
    assert gj.report_path(4, "v0").name == "membership_wide_calibration_report_v4.json"
    assert gj.report_path(3, "v0").name == "membership_wide_calibration_report.json"


# ---- v4 kinds and snippets batches and the constant refinement logging ----
def test_v4_kinds_and_snippets_batches_are_built_for_83_kinds_and_200_snippets_without_running():
    kinds = mw.build_wide_batches(mw.kind_items(), PACK, prompt_version=4)
    snips = mw.build_wide_batches(mw.snippet_items(), PACK, prompt_version=4)
    assert sum(len(v) - 1 for (var, _), v in kinds.items() if var == 0) == 83
    assert sum(len(v) - 1 for (var, _), v in snips.items() if var == 0) == 200
    assert json.loads(kinds[(0, 0)][0])["prompt_version"] == 4 and json.loads(snips[(1, 0)][0])["prompt_version"] == 4


def test_v4_ingest_writes_near_floor_candidates_at_floor_5(tmp_path):
    items = [{"id": "kind.cooking", "text": "A person cooked a meal."}]
    pairs = []
    for v in (0, 1):
        batch = mw.build_wide_batches(items, PACK, prompt_version=4)[(v, 0)]
        bp, ap = tmp_path / f"b{v}.jsonl", tmp_path / f"a{v}.jsonl"
        bp.write_text("\n".join(batch) + "\n")
        t = json.loads(batch[1])
        a = _ans({"form": ["c.cooking", "c.nutrition_diet"] if v == 0 else ["c.cooking"]}, ("c.food_purchasing", 4))
        for rel in RELS:
            if a["ranks"][rel]:
                for i, e in enumerate(a["ranks"][rel]["listed"]):
                    e["fit"] = 9 - 4 * i  # 9, 5
        ap.write_text(json.dumps({"task_id": t["task_id"], "task_type": t["task_type"], "input_hash": t["input_hash"], "variant": v,
                                  "model": json.loads(batch[0])["model"], "prompt_version": 4, "verdict": "membership", "reason": "r",
                                  "types": a["types"], "ranks": a["ranks"], "other": None}) + "\n")
        pairs.append((bp, ap))
    mw.ingest(pairs, tmp_path / "t.jsonl", tmp_path / "e.jsonl")
    cand = [json.loads(l) for l in (mw.REFINEMENT_DIR / "candidates_v1.jsonl").read_text().splitlines()]
    assert {(r["source"], r["domain"], r["prompt_version"]) for r in cand} >= {("near_floor", "c.food_purchasing", 4), ("disputed", "c.nutrition_diet", 4)}


def test_predictions_for_the_gold_completion_are_registered_before_any_judge_answer():
    s = (ROOT / "data/gold/membership_wide_predictions.md").read_text(encoding="utf-8")
    assert "Gold completion and v3/v4 re-score" in s
    head = s.split("## Gold completion and v3/v4 re-score")[1]
    assert "0.8" in head and "0.25" in head and "confidence 0.5" in s and "padding_single_complete" in head
    if "## Gold completion judged" in s:
        assert s.index("confidence 0.5") < s.index("## Gold completion judged")
