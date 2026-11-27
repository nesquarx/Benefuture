"""LI.67 widening with LI.68 logging: the support-weighted union merge of the variants' membership lists (rule `support_union`),
against the intersection merge (rule `intersection`, kept by name) that empties the lists the variants only partly share."""
import json
import statistics
from pathlib import Path

import pytest

import lifeimage.membership_wide as mw
from lifeimage.governed import GOVERNED, governed
from lifeimage.membership import DEFAULT_OUT

ROOT = Path(__file__).resolve().parent.parent
RELS = ("form", "content", "outcome", "setting")


@pytest.fixture(autouse=True)
def _refinement_log_to_tmp(tmp_path, monkeypatch):
    monkeypatch.setattr(mw, "REFINEMENT_DIR", tmp_path / "refinement")


def _answer(lists, v=0):
    """A ranked answer from {relation: [(domain, fit, weight)] or None}."""
    types, ranks = {}, {}
    for r in RELS:
        l = lists.get(r)
        types[r] = None if not l else {d: w for d, _, w in l}
        ranks[r] = None if not l else {"listed": [{"domain": d, "fit": f} for d, f, _ in l], "rejected": {"domain": "c.zzz", "fit": 1}}
    return {"task_id": f"t-v{v}", "variant": v, "model": "m", "prompt_version": 4, "types": types, "ranks": ranks}


def _va(l0, l1):
    return {0: _answer({"form": l0}, 0), 1: _answer({"form": l1}, 1)}


# two variants listing 3 and 2 domains, sharing only the primary
V0 = [("c.a", 9, 0.5), ("c.b", 7, 0.3), ("c.c", 5, 0.2)]
V1 = [("c.a", 9, 0.6), ("c.d", 8, 0.4)]


# ---- the outcome of the current rule (red baseline: the lists collapse to what both variants share) ----
def test_baseline_the_intersection_merge_collapses_two_to_three_domains_per_variant_to_one():
    row = mw.merge_item("kind.x", "t", _va(V0, V1), rule="intersection")
    assert list(row["memberships"]["form"]) == ["c.a"], row["memberships"]
    assert row["memberships"]["form"]["c.a"] == 1.0


def test_the_default_rule_is_the_support_union():
    assert mw.DEFAULT_MERGE == "support_union" and mw.MERGE_RULES == ("intersection", "support_union")


# ---- acceptance ----
def test_union_keeps_every_listed_domain_above_the_floor_with_mean_weights_renormalised_and_support():
    row = mw.merge_item("kind.x", "t", _va(V0, V1), rule="support_union")
    m = row["memberships"]["form"]
    # means: a .55, b .15, c .10, d .20; floor 0.2: b and c are single-support below it, d single-support at it (kept)
    assert list(m) == ["c.a", "c.d"]
    assert m["c.a"] == pytest.approx(0.55 / 0.75) and m["c.d"] == pytest.approx(0.20 / 0.75) and sum(m.values()) == pytest.approx(1)
    sup = row["confidence"]["form"]["support"]
    assert sup == {"c.a": 1.0, "c.d": 0.5}
    assert set(row["disputed"]["form"]) == {"c.b", "c.c"}
    assert row["merge"] == "support_union" and 0 <= row["row_confidence"] <= 1


def test_a_floor_of_zero_keeps_all_four_domains_in_mean_weight_order():
    row = mw.merge_item("kind.x", "t", _va(V0, V1), rule="support_union", single_support_floor=0.0)
    assert list(row["memberships"]["form"]) == ["c.a", "c.d", "c.b", "c.c"]
    assert row["disputed"] == {}


def test_a_domain_both_variants_list_is_kept_whatever_its_weight():
    row = mw.merge_item("kind.x", "t", _va([("c.a", 9, 0.95), ("c.b", 5, 0.05)], [("c.a", 9, 0.9), ("c.b", 5, 0.1)]), rule="support_union")
    assert list(row["memberships"]["form"]) == ["c.a", "c.b"]


def test_a_relation_never_empties():
    row = mw.merge_item("kind.x", "t", _va([("c.a", 6, 0.2), ("c.b", 6, 0.2), ("c.c", 6, 0.2), ("c.d", 6, 0.2), ("c.e", 5, 0.2)],
                                           [("c.f", 6, 0.2), ("c.g", 6, 0.2), ("c.h", 6, 0.2), ("c.i", 6, 0.2), ("c.j", 5, 0.2)]),
                        rule="support_union")
    assert len(row["memberships"]["form"]) >= 1 and sum(row["memberships"]["form"].values()) == pytest.approx(1)


def test_escalation_stays_for_a_differing_primary_but_lists_stay_filled():
    row = mw.merge_item("kind.x", "t", _va([("c.a", 9, 1.0)], [("c.b", 9, 1.0)]), rule="support_union")
    assert row["escalate"] and any("primary domains differ" in r for r in row["escalate_reasons"])
    assert set(row["memberships"]["form"]) == {"c.a", "c.b"}


def test_a_relation_one_variant_leaves_null_keeps_the_other_variants_list_and_escalates():
    va = {0: _answer({"form": V0}, 0), 1: _answer({}, 1)}
    row = mw.merge_item("kind.x", "t", va, rule="support_union")
    assert row["memberships"]["form"] and any("applies in 1 of 2" in r for r in row["escalate_reasons"])
    assert row["memberships"]["content"] is None


def test_merge_rule_is_chosen_by_name_and_unknown_names_fail():
    assert mw.merge_item("k.x", "t", _va(V0, V1), rule="intersection")["merge"] == "intersection"
    with pytest.raises(ValueError):
        mw.merge_item("k.x", "t", _va(V0, V1), rule="majority")


def test_the_floor_is_governed_and_listed():
    assert 0 < governed("membership.single_support_floor") < 0.5
    assert "membership.single_support_floor" in GOVERNED


def test_the_ingest_logs_only_the_dropped_single_support_domains_as_disputed(tmp_path):
    # one item, two variants, via the answers_by_item route used by ingest
    import lifeimage.membership_wide as m
    got = {"kind.x": {0: ("t", _answer({"form": V0}, 0)), 1: ("t", _answer({"form": V1}, 1))}}
    orig = m.answers_by_item
    m.answers_by_item = lambda pairs: got
    try:
        rows = m.ingest([], tmp_path / "t.jsonl", tmp_path / "e.jsonl", refinement_dir=tmp_path / "r")
    finally:
        m.answers_by_item = orig
    assert list(rows[0]["memberships"]["form"]) == ["c.a", "c.d"]
    log = [json.loads(l) for l in (tmp_path / "r" / "candidates_v1.jsonl").read_text().splitlines()]
    assert {(r["domain"], r["source"]) for r in log if r["source"] == "disputed"} == {("c.b", "disputed"), ("c.c", "disputed")}


def test_the_merged_calibration_report_scores_the_merged_list_as_one_answer():
    controls = [{"id": "cal.a", "group": "single", "text": "t", "fair": {"form": ["c.a", "c.d"]}, "bad": {"form": ["c.b"]},
                 "required": {"form": ["c.d"]}}]
    by = {"cal.a": {0: ("t", _answer({"form": V0}, 0)), 1: ("t", _answer({"form": V1}, 1))}}
    one = mw.calibration_report(controls, by, floor=5, prompt_version=4)
    assert one["recall_required"] == 0.5  # variant 0 lacks c.d, variant 1 has it
    inter = mw.merged_calibration_report(controls, by, rule="intersection", floor=5, prompt_version=4)
    uni = mw.merged_calibration_report(controls, by, rule="support_union", floor=5, prompt_version=4)
    assert inter["recall_required"] == 0.0 and uni["recall_required"] == 1.0
    assert uni["median_listed"]["all"]["form"] == 2 and inter["median_listed"]["all"]["form"] == 1
    assert uni["merge"] == "support_union" and uni["variants_merged"] == 2


# ---- the real answers (present in a working checkout, gitignored in CI) ----
def _pairs(name):
    bs = sorted(p for p in DEFAULT_OUT.glob(f"membership.A3S.v4.{name}.var*.part*.jsonl") if not p.name.endswith(".answers.jsonl"))
    prs = [(p, p.with_name(p.name.replace(".jsonl", ".answers.jsonl"))) for p in bs]
    if not prs or any(not a.exists() for _, a in prs):
        pytest.skip(f"v4 {name} answers not present")
    return prs


@pytest.mark.parametrize("name", ["kinds", "snippets"])
def test_the_merged_kinds_and_snippets_keep_a_median_of_two_domains_for_form_and_content(name, tmp_path):
    got = mw.answers_by_item(_pairs(name))
    rows = [mw.merge_item(k, next(iter(per.values()))[0], {v: a for v, (_, a) in per.items()}) for k, per in sorted(got.items())]
    for r in ("form", "content"):
        assert statistics.median(len(x["memberships"][r]) for x in rows if x["memberships"].get(r)) >= 2, (name, r)
