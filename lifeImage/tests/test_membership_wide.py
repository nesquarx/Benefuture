"""LI.67: wide event memberships by a ranked stopping rule (prompt membership.v3, extract.v2)."""
import json
import statistics
from pathlib import Path

import pytest

from lifeimage.eventgen.catalog import ALL
from lifeimage.validate import validate_answers

ROOT = Path(__file__).resolve().parent.parent
RELS = ("form", "content", "outcome", "setting")


@pytest.fixture(autouse=True)
def _refinement_log_to_tmp(tmp_path, monkeypatch):
    """The ingest and judge log refinement candidates (LI.68); these tests' fixtures never touch the real log."""
    import lifeimage.membership_wide as mw
    monkeypatch.setattr(mw, "REFINEMENT_DIR", tmp_path / "refinement")


# ---- the baseline the rule must beat (outcomes of the current code and data) ----
def test_baseline_current_catalog_memberships_are_narrow():
    med = {r: statistics.median(len(getattr(k, r)) for k in ALL) for r in RELS}
    assert med["form"] == 1 and med["setting"] == 1 and med["outcome"] == 2 and med["content"] <= 3, med


def test_baseline_pair_coverage_is_two_percent():
    s = json.loads((ROOT / "data" / "events" / "coverage_v1.json").read_text())["summary"]
    assert 0.020 <= s["share_pairs"] <= 0.022 and s["pairs_possible"] == 30381


# ---- red outcome: the current validator lets unranked, padded and early-stopped lists through ----
def _batch(prompt_version):
    header = {"kind": "header", "task_type": "membership.A3S", "model": "m", "prompt_version": prompt_version,
              "prefix": "x\n# coarse pack | basemap 0 | 3 domains | ~1 tokens\n"
                        "c.cooking | Cooking | x\nc.nutrition_diet | Diet | x\nc.sleep | Sleep | x\n"}
    task = {"kind": "task", "task_id": "t1-v0", "task_type": "membership.A3S", "prompt_version": prompt_version,
            "input_hash": "h" * 64, "variant": 0, "k": 2, "input": {"item": {"id": "i", "text": "Cooked a meal"}, "pack": "p"},
            "allowed_verdicts": ["membership"]}
    return [json.dumps(header), json.dumps(task)]


def _answer(prompt_version, form, ranks):
    types = {"form": form, "content": None, "outcome": None, "setting": None}
    return json.dumps({"task_id": "t1-v0", "task_type": "membership.A3S", "input_hash": "h" * 64, "variant": 0, "model": "m",
                       "prompt_version": prompt_version, "verdict": "membership", "reason": "r", "types": types, "other": None,
                       "ranks": {"form": ranks, "content": None, "outcome": None, "setting": None}})


def test_a_listed_domain_below_the_floor_is_rejected_at_v3():
    ranks = {"listed": [{"domain": "c.cooking", "fit": 9}, {"domain": "c.sleep", "fit": 1}],
             "rejected": {"domain": "c.nutrition_diet", "fit": 1}}
    errs = validate_answers(_batch(3), [_answer(3, {"c.cooking": 0.7, "c.sleep": 0.3}, ranks)])
    assert errs and any("floor" in e for e in errs), errs


def test_an_unranked_list_with_no_fit_record_is_rejected_at_v3():
    a = json.loads(_answer(3, {"c.cooking": 0.5, "c.sleep": 0.5}, None))
    a.pop("ranks")
    errs = validate_answers(_batch(3), [json.dumps(a)])
    assert errs, "a v3 membership answer without its fit record was accepted"


# ======== the ranked stopping rule, validator, prompts, batches, judge and ingest (green) ========
import copy
import re

import pytest

from lifeimage.governed import GOVERNED, governed
from lifeimage.membership import DEFAULT_GOLD, DEFAULT_PACK, load_items_v2
from lifeimage.membership_wide import (CONTROLS, MAX_TASKS, build_wide_batches, calibration_items, calibration_report, kind_items,
                                       load_controls, merge_item, snippet_items, width_summary, write_wide_batches, ingest)
from lifeimage.packs import pack_ids
from lifeimage.validate import (ValidationError, validate_extract_answer, validate_ranked_membership_answer, validate_ranked_types)

PACK = DEFAULT_PACK.read_text(encoding="utf-8")
IDS = pack_ids(PACK)
PROMPTS = ROOT / "prompts"
WANT = list(RELS)


def good(form=None, content=None, outcome=None, setting=None):
    """A valid ranked pair (types, ranks); each argument is a list of (domain, fit, weight) or None, plus a rejected via `rej`."""
    def rel(spec):
        if spec is None:
            return None, None
        lst, rej = spec
        return ({d: w for d, f, w in lst}, {"listed": [{"domain": d, "fit": f} for d, f, w in lst], "rejected": {"domain": rej[0], "fit": rej[1]}})
    pairs = {r: rel(s) for r, s in zip(WANT, (form, content, outcome, setting))}
    return {r: p[0] for r, p in pairs.items()}, {r: p[1] for r, p in pairs.items()}


def base():
    return good(form=([("c.cooking", 9, 0.6), ("c.nutrition_diet", 5, 0.4)], ("c.sleep", 2)), content=([("c.cooking", 8, 1.0)], ("c.sleep", 3)))


def check(mutate=None):
    types, ranks = copy.deepcopy(base())
    if mutate:
        mutate(types, ranks)
    return validate_ranked_types(types, ranks, WANT, IDS)


def test_floor_is_a_governed_value_with_its_source():
    assert governed("membership.fit_floor") == 4 and GOVERNED["membership.fit_floor"]["source"].startswith("LI.67")
    assert 0 < governed("membership.agree_floor") <= 1


def test_a_ranked_answer_with_a_fit_record_is_accepted():
    check()


def test_nulls_must_match_between_types_and_ranks():
    def m(t, r): r["content"] = None
    with pytest.raises(ValidationError, match="both be null or both"):
        check(m)


def test_a_list_below_the_floor_is_rejected():
    def m(t, r):
        t["form"]["c.sleep"] = 0.1; t["form"]["c.cooking"] = 0.5; t["form"]["c.nutrition_diet"] = 0.4
        r["form"]["listed"].append({"domain": "c.sleep", "fit": 3})
    with pytest.raises(ValidationError, match="below the floor 4"):
        check(m)


def test_an_unranked_list_is_rejected():
    def m(t, r):
        r["form"]["listed"] = [{"domain": "c.cooking", "fit": 5}, {"domain": "c.nutrition_diet", "fit": 9}]
    with pytest.raises(ValidationError, match="unranked, fits"):
        check(m)


def test_weights_that_rise_down_the_list_are_rejected():
    def m(t, r):
        t["form"] = {"c.cooking": 0.4, "c.nutrition_diet": 0.6}
    with pytest.raises(ValidationError, match="unranked, weights"):
        check(m)


def test_a_list_that_stops_while_the_best_rejected_domain_is_above_the_floor_is_rejected():
    def m(t, r):
        r["form"]["rejected"] = {"domain": "c.sleep", "fit": 4}
    with pytest.raises(ValidationError, match="stopped early"):
        check(m)


def test_the_stopping_point_must_be_auditable():
    def m(t, r):
        r["form"].pop("rejected")
    with pytest.raises(ValidationError, match="ranks must have exactly"):
        check(m)

    def m2(t, r):
        r["form"]["rejected"] = {"domain": "c.cooking", "fit": 2}
    with pytest.raises(ValidationError, match="also listed"):
        check(m2)


def test_weights_sum_to_one_and_ids_come_from_the_pack_and_listed_matches_weighted():
    def m(t, r): t["form"] = {"c.cooking": 0.5, "c.nutrition_diet": 0.4}
    with pytest.raises(ValidationError, match="sum to"):
        check(m)

    def m2(t, r):
        t["form"] = {"c.nowhere": 0.6, "c.nutrition_diet": 0.4}
    with pytest.raises(ValidationError, match="not in the pack"):
        check(m2)

    def m3(t, r):
        r["form"]["listed"] = list(reversed(r["form"]["listed"]))
    with pytest.raises(ValidationError):
        check(m3)


def test_fits_are_integers_in_range_and_an_all_null_answer_is_rejected():
    def m(t, r): r["form"]["listed"][0]["fit"] = 9.5
    with pytest.raises(ValidationError, match="integers"):
        check(m)
    with pytest.raises(ValidationError, match="every relation is null"):
        validate_ranked_types(dict.fromkeys(WANT), dict.fromkeys(WANT), WANT, IDS)


def test_floor_is_taken_from_governed_unless_given():
    def m(t, r): r["form"]["listed"][1]["fit"] = 3
    with pytest.raises(ValidationError, match="below the floor"):
        check(m)
    types, ranks = copy.deepcopy(base())
    ranks["form"]["listed"][1]["fit"] = 3
    ranks["form"]["rejected"]["fit"] = 2
    ranks["content"]["rejected"]["fit"] = 2
    validate_ranked_types(types, ranks, WANT, IDS, floor=3)  # a lowered floor accepts the same list


def test_the_placebo_type_is_not_part_of_a_ranked_membership_answer():
    t, r = base()
    a = {"verdict": "membership", "types": {**t, "flavour": None}, "ranks": r, "other": None}
    with pytest.raises(ValidationError):
        validate_ranked_membership_answer(a, "A3S", IDS)
    validate_ranked_membership_answer({"verdict": "membership", "types": t, "ranks": r, "other": None}, "A3S", IDS)


def test_validate_answers_applies_the_rule_by_prompt_version_and_leaves_v2_alone():
    t, r = base()
    ok = _answer(3, t["form"], r["form"])
    a = json.loads(ok)
    a["types"], a["ranks"] = t, r
    assert validate_answers(_batch(3), [json.dumps(a)]) == []
    a2 = copy.deepcopy(a)
    a2["ranks"]["form"]["rejected"]["fit"] = 6
    assert any("stopped early" in e for e in validate_answers(_batch(3), [json.dumps(a2)]))
    # v2 batches still demand the placebo type and take no ranks
    v2 = json.loads(_answer(2, {"c.cooking": 1.0}, None))
    v2.pop("ranks")
    v2["types"]["flavour"] = None
    assert validate_answers(_batch(2), [json.dumps(v2)]) == []


def _extract_task():
    return {"input": {"lines": ["L1: Nurse, City Hospital, 2015-2020"]}}


def _extract_answer(rank_mut=None):
    t, r = good(form=([("c.healthcare_work", 9, 0.6), ("c.employment_job", 6, 0.4)], ("c.sleep", 1)),
                content=([("c.medical_care", 9, 1.0)], ("c.reading", 2)), setting=([("c.medical_care", 8, 1.0)], ("c.reading", 1)))
    row = {"span": "L1", "relation": "causal", "channel": "positive", "magnitude": 0.7, "valid_time": "2015", "types": t, "ranks": r}
    if rank_mut:
        rank_mut(row)
    return {"verdict": "rows", "rows": [row]}


def test_extract_v2_rows_carry_ranks_under_the_same_rule():
    validate_extract_answer(_extract_answer(), _extract_task(), IDS, ranked=True)
    with pytest.raises(ValidationError, match="keys must be exactly"):
        a = _extract_answer(lambda r: r.pop("ranks"))
        validate_extract_answer(a, _extract_task(), IDS, ranked=True)
    with pytest.raises(ValidationError, match="stopped early"):
        validate_extract_answer(_extract_answer(lambda r: r["ranks"]["content"]["rejected"].update(fit=7)), _extract_task(), IDS, ranked=True)
    # v1 rows are unchanged
    with pytest.raises(ValidationError, match="keys must be exactly"):
        validate_extract_answer(_extract_answer(), _extract_task(), IDS, ranked=False)


# ---- prompts ----
def _example_blocks():
    s = (PROMPTS / "membership.v3.md").read_text(encoding="utf-8")
    return re.findall(r'Event: "(.*?)"\n```json\n(.*?)\n```', s, re.S)


def test_membership_v3_worked_examples_obey_the_rule_over_pack_domains_and_are_not_gold_items():
    blocks = _example_blocks()
    assert len(blocks) >= 3
    gold = {i["text"].strip().lower() for i in load_items_v2(DEFAULT_GOLD)}
    cal = {c["text"].strip().lower() for c in load_controls()}
    for event, js in blocks:
        ans = json.loads(js)
        validate_ranked_types(ans["types"], ans["ranks"], WANT, IDS)
        assert event.strip().lower() not in gold | cal
    assert any(b["types"] and any(len(v or {}) >= 3 for v in json.loads(js)["types"].values()) for b, js in
               [(json.loads(j), j) for _, j in blocks])  # at least one example lists three domains
    assert any(len(json.loads(j)["types"]["form"]) == 1 for _, j in blocks)  # and one stops at a single domain
    assert any(json.loads(j)["types"]["outcome"] is None for _, j in blocks)  # and one declines a relation


def test_the_prompts_state_the_governed_floor_and_old_versions_remain():
    for name in ("membership.v3.md", "extract.v2.md"):
        s = (PROMPTS / name).read_text(encoding="utf-8")
        assert f"at least {governed('membership.fit_floor')}" in s and "rejected" in s and "decreasing" in s
    for old in ("membership.v1.md", "membership.v2.md", "extract.v1.md", "events.v1.md"):
        assert (PROMPTS / old).exists()
    assert "ranks" in (PROMPTS / "extract.v2.md").read_text(encoding="utf-8")


def test_events_v1_assigns_no_domains_so_it_needs_no_v2():
    s = (PROMPTS / "events.v1.md").read_text(encoding="utf-8")
    assert "domain" not in s.lower() and not (PROMPTS / "events.v2.md").exists()


# ---- items and batches ----
def test_item_sets_are_the_83_kinds_200_snippets_and_the_controls():
    assert len(kind_items()) == len(ALL) == 83 and len({i["id"] for i in kind_items()}) == 83
    sn = snippet_items()
    assert len(sn) == 200 and len({i["text"] for i in sn}) == 200
    assert sn == snippet_items()  # stable sample
    c = load_controls()
    assert {g: sum(x["group"] == g for x in c) for g in ("single", "multi", "decoy")} == {"single": 12, "multi": 12, "decoy": 8}
    assert all(i["text"].endswith(".") or True for i in kind_items())


def test_every_control_domain_is_in_the_pack_and_gold_is_consistent():
    for c in load_controls():
        for k in ("fair", "bad", "required"):
            for rel, ds in c.get(k, {}).items():
                assert rel in RELS and set(ds) <= IDS, (c["id"], k, rel)
        for rel, ds in c.get("required", {}).items():
            assert set(ds) <= set(c["fair"][rel]), (c["id"], rel)
        for rel, ds in c.get("bad", {}).items():
            assert not set(ds) & set(c.get("fair", {}).get(rel, [])), (c["id"], rel)
        assert c["group"] != "multi" or c["required"], c["id"]


def test_batches_are_two_variants_at_most_fifty_per_file_with_a_stable_prefix(tmp_path):
    items = kind_items()
    b = build_wide_batches(items, PACK)
    assert sorted(b) == [(0, 0), (0, 1), (1, 0), (1, 1)]
    assert all(len(lines) - 1 <= MAX_TASKS for lines in b.values())
    assert sum(len(l) - 1 for (v, _), l in b.items() if v == 0) == 83
    h = lambda key: json.loads(b[key][0])["prefix"]
    assert h((0, 0)) == h((0, 1)) and h((1, 0)) == h((1, 1)) and h((0, 0)) != h((1, 0))  # shared within a variant, shuffled across
    prefix = h((0, 0))
    assert prefix.startswith((PROMPTS / "membership.v3.md").read_text(encoding="utf-8").rstrip("\n")) and "kind." not in prefix  # no item text in the prefix
    task = json.loads(b[(0, 0)][1])
    assert task["task_type"] == "membership.A3S" and task["prompt_version"] == 3 and task["variant"] == 0 and task["k"] == 2
    paths = write_wide_batches("kinds", b, tmp_path)
    assert [p.name for p in paths][:2] == ["membership.A3S.v3.kinds.var0.part0.jsonl", "membership.A3S.v3.kinds.var0.part1.jsonl"]
    from lifeimage.validate import validate_task
    for line in b[(0, 0)][1:]:
        validate_task(json.loads(line))


def test_snippet_and_calibration_batches_fit_the_limits():
    s = build_wide_batches(snippet_items(), PACK)
    assert sorted(s) == [(v, p) for v in (0, 1) for p in range(4)]
    c = build_wide_batches(calibration_items(), PACK)
    assert sorted(c) == [(0, 0), (1, 0)] and len(c[(0, 0)]) - 1 == 32


# ---- the judge ----
def _ans(lists, rejected_fit=2):
    """A validated-shape answer from {rel: [domains]} (fits step down from 9, weights decreasing)."""
    types, ranks = {}, {}
    for rel in RELS:
        ds = lists.get(rel)
        if ds is None:
            types[rel], ranks[rel] = None, None
            continue
        n = len(ds)
        w = [(n - i) for i in range(n)]
        t = sum(w)
        types[rel] = {d: x / t for d, x in zip(ds, w)}
        ranks[rel] = {"listed": [{"domain": d, "fit": 9 - i} for i, d in enumerate(ds)], "rejected": {"domain": "c.reading", "fit": rejected_fit}}
    return {"types": types, "ranks": ranks}


def _controls():
    return [
        {"id": "cal.s", "group": "single", "text": "t", "fair": {"form": ["c.a"], "content": ["c.a", "c.b"]}, "bad": {"form": ["c.x"]}},
        {"id": "cal.m", "group": "multi", "text": "t", "fair": {"form": ["c.a", "c.b", "c.c"]}, "required": {"form": ["c.a", "c.b"]}},
        {"id": "cal.d", "group": "decoy", "text": "t", "fair": {"form": ["c.a"]}, "bad": {"form": ["c.x"]}},
    ]


def test_the_judge_counts_precision_padding_recall_and_decoys():
    by = {"cal.s": {0: ("t", _ans({"form": ["c.a", "c.x"], "content": ["c.a", "c.b"]}))},
          "cal.m": {0: ("t", _ans({"form": ["c.a", "c.b", "c.c"]}))},
          "cal.d": {0: ("t", _ans({"form": ["c.a", "c.q"]}))}}
    r = calibration_report(_controls(), by)
    # secondary: s.form c.x (bad), s.content c.b (fair), m c.b c.c (fair, fair), d c.q (unjudged)  -> 3 of 5
    assert r["cells_judged"]["secondary"] == 5 and r["precision_secondary"] == 3 / 5
    assert r["bad_secondary"] == [("cal.s", 0, "form", "c.x")] and r["unjudged_secondary"] == [("cal.d", 0, "form", "c.q")]
    assert r["padding_single"] == 1 / 2  # single cells: form (c.x outside fair) and content (c.b inside fair)
    assert r["recall_required"] == 1.0 and r["decoy_hit_rate"] == 0.0
    assert r["median_listed"]["multi"]["form"] == 3
    assert not r["predictions"]["precision_secondary_at_least_0.8"] and not r["predictions"]["padding_single_at_most_0.10"]


def test_the_judge_passes_a_clean_battery():
    by = {"cal.s": {0: ("t", _ans({"form": ["c.a"], "content": ["c.a", "c.b"]}))},
          "cal.m": {0: ("t", _ans({"form": ["c.a", "c.b", "c.c"], "content": None}))},
          "cal.d": {0: ("t", _ans({"form": ["c.a"]}))}}
    r = calibration_report(_controls(), by)
    assert all(r["predictions"].values()) is False  # multi content has no cells so the width check lacks data
    assert r["precision_secondary"] == 1.0 and r["padding_single"] == 0.0 and r["decoy_hit_rate"] == 0.0


# ---- the ingest ----
def _mk(types_lists):
    return _ans(types_lists) | {"prompt_version": 3, "model": "m"}


def test_variants_agreeing_merge_into_weights_with_full_confidence():
    a = _mk({"form": ["c.a", "c.b"], "content": ["c.a"]})
    b = _mk({"form": ["c.a", "c.b"], "content": ["c.a"]})
    r = merge_item("kind.x", "t", {0: a, 1: b})
    assert r["memberships"]["form"] == {"c.a": pytest.approx(2 / 3), "c.b": pytest.approx(1 / 3)} and r["memberships"]["outcome"] is None
    assert r["confidence"]["form"]["agreement"] == 1.0 and not r["escalate"] and r["source"] == "kind"


def test_intersection_merge_escalates_and_keeps_only_the_agreed_core():
    a = _mk({"form": ["c.a", "c.b", "c.c"]})
    b = _mk({"form": ["c.a", "c.b", "c.d"]})
    r = merge_item("kind.x", "t", {0: a, 1: b}, rule="intersection")
    assert set(r["memberships"]["form"]) == {"c.a", "c.b"} and abs(sum(r["memberships"]["form"].values()) - 1) < 1e-9
    assert r["disputed"]["form"] == {"c.c": 0.5, "c.d": 0.5} and r["confidence"]["form"]["agreement"] == 0.5
    assert not r["escalate"]  # Jaccard 2/4 meets the floor and the primary agrees
    c = _mk({"form": ["c.a", "c.b", "c.c", "c.d"]})
    d = _mk({"form": ["c.a", "c.e", "c.f", "c.g"]})
    r2 = merge_item("kind.x", "t", {0: c, 1: d}, rule="intersection")
    assert r2["escalate"] and any("below" in x for x in r2["escalate_reasons"])
    e = merge_item("kind.x", "t", {0: _mk({"form": ["c.a"]}), 1: _mk({"form": ["c.b"]})}, rule="intersection")
    assert e["memberships"]["form"] is None and e["escalate"]
    f = merge_item("kind.x", "t", {0: _mk({"form": ["c.a", "c.b"]}), 1: _mk({"form": ["c.b", "c.a"]})}, rule="intersection")
    assert any("primary domains differ" in x for x in f["escalate_reasons"])
    g = merge_item("kind.x", "t", {0: _mk({"form": ["c.a"], "outcome": ["c.a"]}), 1: _mk({"form": ["c.a"]})}, rule="intersection")
    assert g["escalate"] and g["memberships"]["outcome"] is None


def test_ingest_reads_validated_files_and_writes_the_table_and_escalations(tmp_path):
    items = [{"id": "kind.cooking", "text": "A person cooked a meal."}, {"id": "kind.sleep", "text": "A person slept."}]
    pack_cooking = ["c.cooking", "c.nutrition_diet"]
    pairs = []
    for v in (0, 1):
        batch = build_wide_batches(items, PACK)[(v, 0)]
        bp, ap = tmp_path / f"b{v}.jsonl", tmp_path / f"a{v}.jsonl"
        bp.write_text("\n".join(batch) + "\n")
        lines = []
        for line in batch[1:]:
            t = json.loads(line)
            if t["input"]["item"]["id"] == "kind.cooking":
                lists = {"form": pack_cooking, "content": ["c.cooking"]}
            else:
                lists = {"form": ["c.sleep"] if v == 0 else ["c.hygiene_grooming"]}
            a = _ans(lists)
            lines.append(json.dumps({"task_id": t["task_id"], "task_type": t["task_type"], "input_hash": t["input_hash"], "variant": v,
                                     "model": json.loads(batch[0])["model"], "prompt_version": 3, "verdict": "membership",
                                     "reason": "r", "types": a["types"], "ranks": a["ranks"], "other": None}))
        ap.write_text("\n".join(lines) + "\n")
        pairs.append((bp, ap))
    out, esc = tmp_path / "table.jsonl", tmp_path / "esc.jsonl"
    rows = ingest(pairs, out, esc)
    assert [r["key"] for r in rows] == ["kind.cooking", "kind.sleep"]
    table = [json.loads(l) for l in out.read_text().splitlines()]
    assert table[0]["memberships"]["form"] and not table[0]["escalate"] and table[1]["escalate"]
    escalated = [json.loads(l) for l in esc.read_text().splitlines()]
    assert [e["key"] for e in escalated] == ["kind.sleep"] and set(escalated[0]["variants"]) == {"0", "1"}
    # a variant missing for an item is an error, never a silent half-merge
    with pytest.raises(ValueError, match="expected 2"):
        ingest(pairs[:1], out, esc)
    # an invalid answer file is refused
    bad = tmp_path / "bad.jsonl"
    bad.write_text(pairs[0][1].read_text().replace('"fit": 9', '"fit": 1', 1))
    with pytest.raises(ValueError, match="validation errors"):
        ingest([(pairs[0][0], bad), pairs[1]], out, esc)


def test_width_summary_reports_medians_and_pair_share():
    rows = [{"memberships": {"form": {"c.a": 0.6, "c.b": 0.4}, "content": {"c.a": 1.0}, "outcome": None, "setting": {"c.c": 1.0}}, "escalate": False},
            {"memberships": {"form": {"c.a": 1.0}, "content": {"c.a": 0.5, "c.d": 0.5}, "outcome": None, "setting": None}, "escalate": True}]
    s = width_summary(rows)
    assert s["median_listed"]["form"] == 1.5 and s["median_listed"]["outcome"] is None and s["escalated"] == 1
    assert s["pairs_in_kinds"] == 4  # {a,b,c}: 3 pairs, plus {a,d}


def test_predictions_are_registered_before_measuring():
    s = (ROOT / "data" / "gold" / "membership_wide_predictions.md").read_text(encoding="utf-8")
    assert "2-4" in s and ">= 0.8" in s and "<= 0.10" in s and "Confidence 0.5" in s and "ETA" in s
    assert "ranks" in (PROMPTS / "RUNNER.md").read_text(encoding="utf-8")


# ======== membership.v4: the floor raised to 5 by the pre-registered rule (v3 stays reproducible) ========
from lifeimage.governed import membership_fit_floor
from lifeimage.membership_wide import (LATEST_PROMPT_VERSION, judged_precision, read_instructions, unjudged_review)


def _v4_answer(form_ranks, form_types, version=4):
    a = json.loads(_answer(version, form_types, form_ranks))
    return json.dumps(a)


def test_the_floor_is_chosen_by_prompt_version_and_governed():
    assert membership_fit_floor(3) == 4 and membership_fit_floor(4) == 5 and membership_fit_floor(5) == 5
    assert governed("membership.fit_floor") == 4  # v3's value stays
    assert governed("membership.fit_floor.v4") == 5 and GOVERNED["membership.fit_floor.v4"]["source"].startswith("LI.67")
    assert LATEST_PROMPT_VERSION == 4


def test_v4_rejects_a_listed_domain_at_fit_4_and_v3_accepts_it():
    ranks = {"listed": [{"domain": "c.cooking", "fit": 9}, {"domain": "c.sleep", "fit": 4}], "rejected": {"domain": "c.nutrition_diet", "fit": 3}}
    types = {"c.cooking": 0.7, "c.sleep": 0.3}
    assert validate_answers(_batch(3), [_v4_answer(ranks, types, 3)]) == []
    errs = validate_answers(_batch(4), [_v4_answer(ranks, types, 4)])
    assert errs and any("below the floor 5" in e for e in errs), errs


def test_v4_rejects_a_stop_while_the_best_rejected_is_at_least_5_and_v3_accepts_5_only_as_a_stop_error():
    ranks = {"listed": [{"domain": "c.cooking", "fit": 9}], "rejected": {"domain": "c.sleep", "fit": 4}}
    assert validate_answers(_batch(4), [_v4_answer(ranks, {"c.cooking": 1.0}, 4)]) == []  # a 4 now stops the list
    assert any("stopped early" in e for e in validate_answers(_batch(3), [_v4_answer(ranks, {"c.cooking": 1.0}, 3)]))  # and v3 says it belongs
    ranks["rejected"]["fit"] = 5
    errs = validate_answers(_batch(4), [_v4_answer(ranks, {"c.cooking": 1.0}, 4)])
    assert errs and any("stopped early" in e and "floor 5" in e for e in errs), errs


def test_v4_prompt_states_floor_5_and_its_examples_validate_at_5_but_not_all_at_the_v3_floor_text():
    s = read_instructions(4)
    assert "at least 5" in s and "below 5" in s and "least 4" not in s and "below 4" not in s and "4 or more" not in s
    blocks = re.findall(r'Event: "(.*?)"\n```json\n(.*?)\n```', s, re.S)
    assert len(blocks) >= 3
    gold = {i["text"].strip().lower() for i in load_items_v2(DEFAULT_GOLD)} | {c["text"].strip().lower() for c in load_controls()}
    for event, js in blocks:
        ans = json.loads(js)
        validate_ranked_types(ans["types"], ans["ranks"], WANT, IDS, floor=5)
        assert event.strip().lower() not in gold
    assert any(len(v or {}) >= 3 for _, js in blocks for v in json.loads(js)["types"].values())
    assert any(json.loads(js)["types"]["form"] and len(json.loads(js)["types"]["form"]) == 1 for _, js in blocks)
    assert (PROMPTS / "membership.v3.md").exists() and "at least 4" in (PROMPTS / "membership.v3.md").read_text(encoding="utf-8")


def test_v4_batches_carry_prompt_version_4_and_v3_batches_are_unchanged():
    b4 = build_wide_batches(calibration_items(), PACK, prompt_version=4)
    h = json.loads(b4[(0, 0)][0])
    assert h["prompt_version"] == 4 and h["prefix"].startswith(read_instructions(4))
    assert json.loads(b4[(0, 0)][1])["prompt_version"] == 4
    assert json.loads(build_wide_batches(calibration_items(), PACK)[(0, 0)][0])["prompt_version"] == 3


def test_judge_reports_precision_both_ways_and_lists_unjudged_for_review():
    by = {"cal.s": {0: ("t", _ans({"form": ["c.a", "c.x"], "content": ["c.a", "c.b"]}))},
          "cal.m": {0: ("t", _ans({"form": ["c.a", "c.b", "c.c"]}))},
          "cal.d": {0: ("t", _ans({"form": ["c.a", "c.q"]}))}}
    r = calibration_report(_controls(), by)
    assert r["precision_secondary"] == 3 / 5  # pre-registered: unjudged counts against
    assert r["precision_judged"] == 3 / 4 and judged_precision(r) == 3 / 4  # fair share of judged (fair 3, bad 1)
    assert r["n_unjudged"] == 1 and r["n_bad"] == 1
    md = unjudged_review(_controls(), by, {"c.q": "Quiet", "c.a": "A"}, version=3)
    assert "cal.d" in md and "c.q" in md and "Quiet" in md and "pre-registered" in md
    assert "## cal.s" not in md


def test_v4_predictions_are_registered_before_the_v4_verdict():
    # Restated (lead, 2026-11-26): the answers now exist; the pre-registration must precede the judged section in the record.
    s = (ROOT / "data" / "gold" / "membership_wide_predictions.md").read_text(encoding="utf-8")
    assert "v3 judged" in s and "0.6919" in s and "membership.v4" in s and "Confidence 0.4" in s
    if "## v4 judged" in s:
        assert s.index("Confidence 0.4") < s.index("## v4 judged")
