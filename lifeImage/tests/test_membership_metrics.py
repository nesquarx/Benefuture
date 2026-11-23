"""Metrics for the membership battery. Acceptance cases state what must hold; counterexamples state what must
fail (chance agreement scoring as agreement, a consistent shared domain read as confusion, nulls counted as
domains). Red first against a naive stub that scores percent agreement as alpha."""
import json
import math

import pytest

from lifeimage.membership_metrics import (jaccard, krippendorff_alpha_nominal, load_records, render, top_domain,
                                          vocab_metrics)

T = ["form", "outcome"]


def rec(item, variant, form=None, outcome=None, other=None, vocab="A4"):
    return {"vocab": vocab, "item": item, "variant": variant, "other": other,
            "types": {"form": form, "outcome": outcome}}


def m(records, types=T):
    return vocab_metrics(records, types)


# ---- Krippendorff's alpha (nominal) ----
def test_alpha_is_one_for_perfect_agreement_across_varied_values():
    assert krippendorff_alpha_nominal([["a"] * 3, ["b"] * 3, ["c"] * 3]) == 1.0


def test_alpha_near_zero_or_below_when_agreement_is_only_what_chance_gives():
    # two categories, coders agree on exactly half of the units: no better than chance
    units = [["a", "a", "a"], ["a", "b", "b"], ["b", "b", "a"], ["b", "a", "a"]] * 5
    assert krippendorff_alpha_nominal(units) < 0.2


def test_alpha_is_negative_for_systematic_disagreement():
    assert krippendorff_alpha_nominal([["a", "b"], ["b", "a"], ["a", "b"], ["b", "a"]]) < 0


def test_alpha_matches_a_hand_computed_value():
    # two [a,a,b] and two [a,a,a] units: n = 12 pairable values (10 a, 2 b); each mismatched unit holds 4 ordered
    # mismatched pairs at weight 1/2, so Do = (2 * 2) / 12; De = 2 * 10 * 2 / (12 * 11); alpha = 1 - Do / De = -0.1
    units = [["a", "a", "b"], ["a", "a", "b"], ["a", "a", "a"], ["a", "a", "a"]]
    assert krippendorff_alpha_nominal(units) == pytest.approx(-0.1)


def test_alpha_ignores_units_with_fewer_than_two_values():
    assert krippendorff_alpha_nominal([["a", "a"], ["b"], ["b", "b"]]) == 1.0


def test_alpha_with_a_single_category_everywhere_is_one_not_a_division_error():
    assert krippendorff_alpha_nominal([["a", "a", "a"]] * 4) == 1.0


def test_alpha_is_nan_when_no_unit_can_be_compared():
    assert math.isnan(krippendorff_alpha_nominal([["a"], ["b"]]))


# ---- Jaccard, top domain ----
def test_jaccard_empty_sets_agree_fully_and_disjoint_sets_not_at_all():
    assert jaccard([], []) == 1.0 and jaccard({"x"}, {"y"}) == 0.0 and jaccard({"x", "y"}, {"y"}) == 0.5


def test_top_domain_is_heaviest_with_ties_to_the_lowest_id_and_none_for_null():
    assert top_domain({"c.b": 0.5, "c.a": 0.5}) == "c.a" and top_domain({"c.b": 0.7, "c.a": 0.3}) == "c.b"
    assert top_domain(None) is None


# ---- rates ----
def test_other_rate_and_applicability():
    rs = [rec("ev.1", 0, {"c.x": 1.0}, None, other="a relation of trust"),
          rec("ev.1", 1, {"c.x": 1.0}, {"c.y": 1.0}),
          rec("ev.2", 0, None, {"c.y": 1.0}), rec("ev.2", 1, None, None)]
    r = m(rs)
    assert r["other_rate"] == 0.25
    assert r["types"]["form"]["applicability"] == 0.5 and r["types"]["outcome"]["applicability"] == 0.5


def test_forced_rate_counts_answers_that_filled_every_type_and_named_no_other():
    rs = [rec("e", 0, {"c.x": 1.0}, {"c.y": 1.0}),
          rec("e", 1, {"c.x": 1.0}, {"c.y": 1.0}, other="trust"),
          rec("e", 2, {"c.x": 1.0}, None)]
    assert m(rs)["forced_rate"] == pytest.approx(1 / 3)


def test_redteam_other_share_uses_only_rt_items_and_is_none_without_them():
    rs = [rec("ev.1", 0, other="x"), rec("rt.1", 0, other="x"), rec("rt.2", 0), rec("rt.2", 1, other="y")]
    assert m(rs)["redteam_other"] == pytest.approx(2 / 3)
    assert m([rec("ev.1", 0)])["redteam_other"] is None


# ---- agreement per type ----
def three(item, tops, form_sets=None):
    return [rec(item, v, {tops[v]: 1.0}, {"c.o": 1.0}) for v in range(3)]


def test_agreement_alpha_is_high_when_variants_agree_and_low_when_they_split_at_random():
    agree = [r for i in range(8) for r in three(f"ev.{i}", [f"c.d{i % 4}"] * 3)]
    split = [r for i in range(8) for r in three(f"ev.{i}", [f"c.d{(i + v) % 4}" for v in range(3)])]
    assert m(agree)["types"]["form"]["alpha"] == 1.0
    assert m(split)["types"]["form"]["alpha"] < 0.2
    # percent agreement of the 'agree' set is identical to alpha but the split set must not look decent
    assert m(split)["types"]["form"]["alpha"] < m(agree)["types"]["form"]["alpha"] - 0.7


def test_null_is_its_own_category_for_alpha_so_applicability_disagreement_counts():
    rs = [rec("e1", 0, {"c.x": 1.0}), rec("e1", 1, None), rec("e1", 2, {"c.x": 1.0}),
          rec("e2", 0, None), rec("e2", 1, {"c.x": 1.0}), rec("e2", 2, None)]
    assert m(rs)["types"]["form"]["alpha"] < 0.5


def test_mean_jaccard_over_variant_pairs_of_domain_sets():
    rs = [rec("e", 0, {"c.a": .5, "c.b": .5}), rec("e", 1, {"c.a": 1.0}), rec("e", 2, {"c.b": 1.0})]
    # pairs: {a,b}-{a}=.5, {a,b}-{b}=.5, {a}-{b}=0 -> 1/3
    assert m(rs)["types"]["form"]["jaccard"] == pytest.approx(1 / 3)


def test_null_in_every_variant_is_perfect_set_agreement():
    rs = [rec("e", v, None) for v in range(3)]
    assert m(rs)["types"]["form"]["jaccard"] == 1.0


def test_an_item_answered_by_a_single_variant_contributes_no_agreement():
    rs = [rec("e1", 0, {"c.a": 1.0}), rec("e2", 0, {"c.b": 1.0}), rec("e2", 1, {"c.b": 1.0})]
    assert m(rs)["types"]["form"]["jaccard"] == 1.0


# ---- confusion between types ----
def test_swap_is_confusion_the_same_domain_under_form_in_one_variant_and_outcome_in_another():
    rs = [rec("e", 0, {"c.x": 1.0}, {"c.y": 1.0}), rec("e", 1, {"c.y": 1.0}, {"c.z": 1.0}),
          rec("e", 2, {"c.x": 1.0}, {"c.y": 1.0})]
    c = m(rs)["confusion"]
    assert c[("form", "outcome")] == 1.0  # the one item: c.y is outcome in v0, v2 but form in v1


def test_a_domain_shared_by_two_types_in_every_variant_is_not_confusion():
    rs = [rec("e", v, {"c.x": 1.0}, {"c.x": 1.0}) for v in range(3)]
    assert m(rs)["confusion"].get(("form", "outcome"), 0.0) == 0.0


def test_confusion_is_a_share_of_items_not_of_answers():
    swap = [rec("e1", 0, {"c.x": 1.0}, {"c.y": 1.0}), rec("e1", 1, {"c.y": 1.0}, {"c.x": 1.0})]
    calm = [rec("e2", v, {"c.p": 1.0}, {"c.q": 1.0}) for v in range(2)]
    assert m(swap + calm)["confusion"][("form", "outcome")] == 0.5


# ---- loading and rendering ----
def test_render_is_a_markdown_table_naming_every_vocabulary_and_type():
    rs = [rec("ev.1", v, {"c.x": 1.0}, {"c.y": 1.0}) for v in range(3)]
    out = render({"A4": m(rs)})
    assert out.count("|---") >= 1 and "A4" in out and "form" in out and "outcome" in out and "alpha" in out.lower()


def test_load_records_rejects_an_answers_file_without_its_batch(tmp_path):
    p = tmp_path / "membership.A4.v1.var0.answers.jsonl"
    p.write_text("{}\n")
    with pytest.raises(FileNotFoundError):
        load_records([p])


def test_end_to_end_from_batch_and_answers_files_to_a_report(tmp_path):
    from lifeimage.membership import VOCABS, build_membership_batches, load_items, write_membership_batches, DEFAULT_PACK
    from lifeimage.membership_metrics import compute
    items = [i for i in load_items() if i["id"] in ("ev.1", "ev.2", "rt.1")]
    for p in (tmp_path / "p",):
        p.mkdir()
        (p / "membership.v1.md").write_text("# Task: membership\n")
    b = build_membership_batches("ACP", items, DEFAULT_PACK.read_text(), prompts_dir=tmp_path / "p")
    paths = write_membership_batches("ACP", b, tmp_path)
    for p in paths:
        lines = p.read_text().splitlines()
        out = []
        for l in lines[1:]:
            t = json.loads(l)
            rt = t["input"]["item"]["id"] == "rt.1"
            out.append(json.dumps({"task_id": t["task_id"], "variant": t["variant"], "other": "omission" if rt else None,
                                   "types": {"act": None if rt else {"c.cooking": 1.0}, "content": {"c.reading": 1.0},
                                             "purpose": {"c.sleep": 1.0}}}))
        p.with_name(p.name.replace(".jsonl", ".answers.jsonl")).write_text("\n".join(out) + "\n")
    answers = sorted(tmp_path.glob("*.answers.jsonl"))
    r = compute(load_records(answers))["ACP"]
    assert r["answers"] == 9 and r["items"] == 3
    assert r["redteam_other"] == 1.0 and r["other_rate"] == pytest.approx(1 / 3)
    assert r["types"]["act"]["applicability"] == pytest.approx(2 / 3)
    assert r["types"]["content"]["alpha"] == 1.0
    assert VOCABS["ACP"]["types"] == list(r["types"])
