import json

import pytest

from lifeimage.comembership import (comembership, fields_with_links, load_answers, merge_items, pair_view,
                                    reference_view, production_view, specialisation_view, write_rows)


def ans(h, types, variant=0, task_type="membership.A3S"):
    return {"input_hash": h, "variant": variant, "task_type": task_type, "types": types, "verdict": "membership"}


def rows_by(rows):
    return {(r["a"], r["type_i"], r["b"], r["type_j"]): r for r in rows}


# ---- acceptance: what must hold
def test_conditional_probability_is_directed_and_both_directions_are_stored_separately():
    items = merge_items([ans("1", {"form": {"c.a": 1}, "content": {"c.b": 1}}),
                         ans("2", {"form": {"c.a": 1}, "content": {"c.c": 1}})])
    r = rows_by(comembership(items))
    assert r[("c.a", "form", "c.b", "content")]["p"] == pytest.approx(0.5)  # A under form: 2 items, B follows in 1
    assert r[("c.b", "content", "c.a", "form")]["p"] == pytest.approx(1.0)  # B under content: 1 item, A in it
    assert r[("c.a", "form", "c.b", "content")]["support"] == 1


def test_types_are_kept_apart_not_pooled():
    items = merge_items([ans("1", {"form": {"c.a": 1}, "content": {"c.b": 1}, "outcome": None})])
    r = rows_by(comembership(items))
    assert ("c.a", "form", "c.b", "content") in r
    assert ("c.a", "form", "c.b", "form") not in r and ("c.a", "form", "c.b", "outcome") not in r


def test_split_weights_enter_the_conditional():
    items = merge_items([ans("1", {"form": {"c.a": 0.5, "c.d": 0.5}, "content": {"c.b": 0.8, "c.c": 0.2}})])
    r = rows_by(comembership(items))
    assert r[("c.a", "form", "c.b", "content")]["p"] == pytest.approx(0.8)
    assert r[("c.a", "form", "c.d", "form")]["p"] == pytest.approx(0.5)  # co-membership inside one type


def test_variants_merge_by_mean_with_null_as_zero_and_placebo_dropped():
    items = merge_items([ans("1", {"form": {"c.a": 1}, "flavour": {"c.x": 1}}, 0),
                         ans("1", {"form": {"c.b": 1}, "flavour": {"c.x": 1}}, 1),
                         ans("1", {"form": None, "flavour": None}, 2)])
    assert items["1"]["form"] == pytest.approx({"c.a": 1 / 3, "c.b": 1 / 3})
    assert "flavour" not in items["1"]


def test_a_type_missing_from_a_vocabulary_is_not_counted_as_zero_and_sources_share_one_unit():
    items = merge_items([ans("1", {"form": {"c.a": 1}}, 0, "membership.A3"),
                         ans("1", {"form": {"c.a": 1}, "content": {"c.b": 1}}, 0, "membership.A3S"),
                         ans("1", {"causal": {"c.b": 1}}, 0, "membership.R156")])
    assert items["1"]["form"] == {"c.a": 1.0}  # not diluted by the R156 answer that has no form
    r = rows_by(comembership(items))
    assert r[("c.a", "form", "c.b", "content")]["support"] == 1  # one item, not one per vocabulary


def test_same_domain_pairs_are_not_rows():
    items = merge_items([ans("1", {"form": {"c.a": 1}, "content": {"c.a": 1}})])
    assert comembership(items) == []


def test_rows_carry_version_and_are_deterministic():
    items = merge_items([ans("1", {"form": {"c.a": 1}, "content": {"c.b": 1}})])
    r = comembership(items, version="7")
    assert set(r[0]) == {"a", "type_i", "b", "type_j", "p", "support", "version"} and r[0]["version"] == "7"
    assert r == comembership(items, version="7")


def test_specialisation_is_the_within_type_inclusion_asymmetry():
    # c.child is always with c.parent; c.parent often appears alone
    answers = [ans(str(i), {"content": {"c.child": 0.5, "c.parent": 0.5}}) for i in range(3)]
    answers += [ans(f"p{i}", {"content": {"c.parent": 1}}) for i in range(3)]
    spec = specialisation_view(comembership(merge_items(answers)))
    top = spec[0]
    assert (top["a"], top["b"], top["type"]) == ("c.child", "c.parent", "content")
    assert top["asymmetry"] > 0.3
    assert all(not (s["a"] == "c.parent" and s["b"] == "c.child") for s in spec)  # only the specialising direction


def test_reference_and_production_views_are_the_form_to_content_and_form_to_outcome_rows():
    items = merge_items([ans("1", {"form": {"c.a": 1}, "content": {"c.b": 1}, "outcome": {"c.c": 1}})])
    rows = comembership(items)
    assert [(r["a"], r["b"]) for r in reference_view(rows)] == [("c.a", "c.b")]
    assert [(r["a"], r["b"]) for r in production_view(rows)] == [("c.a", "c.c")]


def test_pair_view_aggregates_types_and_fields_with_links_counts_support_threshold():
    items = merge_items([ans(str(i), {"form": {"c.a": 1}, "content": {"c.b": 1}}) for i in range(3)]
                        + [ans("x", {"form": {"c.z": 1}, "content": {"c.y": 1}})])
    rows = comembership(items)
    pv = pair_view(rows)
    assert pv[("c.a", "c.b")] == pytest.approx((1.0, 3))
    assert fields_with_links(rows, ["c.a", "c.b", "c.z", "c.y", "c.q"], min_support=3) == {"c.a", "c.b"}
    assert fields_with_links(rows, ["c.a", "c.z"], min_support=1) == {"c.a", "c.z"}


def test_write_rows_and_load_answers_roundtrip(tmp_path):
    d = tmp_path / "answers"
    d.mkdir()
    (d / "membership.A3.jsonl").write_text(json.dumps(ans("1", {"form": {"c.a": 1}, "content": {"c.b": 1}})) + "\n")
    (d / "links.jsonl").write_text(json.dumps({"input_hash": "9", "variant": 0, "task_type": "links", "verdict": "links"}) + "\n")
    (d / "confirm.v2.jsonl").write_text(json.dumps(ans("2", {"form": {"c.a": 1}, "content": {"c.b": 1}}, 0, "confirm.v2")) + "\n")
    loaded = load_answers(d)
    assert sorted(a["input_hash"] for a in loaded) == ["1", "2"]  # membership and confirm only
    out = tmp_path / "c.jsonl"
    write_rows(comembership(merge_items(loaded)), out)
    r = [json.loads(l) for l in out.read_text().splitlines()]
    assert r[0]["support"] == 2


def test_real_data_every_row_is_a_probability_and_seed_fields_have_links():
    from pathlib import Path
    root = Path(__file__).resolve().parent.parent
    rows = comembership(merge_items(load_answers(root / "data" / "answers")))
    assert rows and all(0 < r["p"] <= 1 + 1e-9 and r["support"] >= 1 and r["a"] != r["b"] for r in rows)
    seed = [json.loads(l) for l in (root / "data/coarse/seed_v0.jsonl").read_text().splitlines()]
    fields = [c["id"] for c in seed if not c["id"].startswith("s.")]
    assert len(fields_with_links(rows, fields, 3)) >= 50
