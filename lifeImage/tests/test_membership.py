import json

import pytest

from lifeimage.cache import AnswerCache
from lifeimage.membership import (DEFAULT_GOLD, V1_VOCABS, DEFAULT_PACK, VOCABS, build_membership_batches, load_items,
                                  pack_lines, ungrouped_pack, vocab_text)
from lifeimage.packs import pack_ids
from lifeimage.validate import ValidationError, validate_answers, validate_membership_answer

PACK = DEFAULT_PACK.read_text(encoding="utf-8")
IDS = pack_ids(PACK)


@pytest.fixture
def prompts(tmp_path):
    d = tmp_path / "p"
    d.mkdir()
    (d / "membership.v1.md").write_text("# Task: membership\nAnswer.\n")
    return d


def build(vocab="A4", items=None, **kw):
    return build_membership_batches(vocab, items or load_items(), PACK, **kw)


# ---- vocabularies ----
def test_the_four_v1_vocabularies_have_the_named_types_in_order():
    assert {v: d["types"] for v, d in VOCABS.items() if v in V1_VOCABS} == {
        "A4": ["form", "material", "outcome", "reference"],
        "A6": ["form", "material", "outcome", "reference", "mechanism", "normative"],
        "R156": ["causal", "structural", "communicative"],
        "ACP": ["act", "content", "purpose"]}


def test_every_type_has_a_one_line_definition_and_a_worked_example_over_real_pack_domains():
    for v, d in VOCABS.items():
        for t in d["types"]:
            spec = d["defs"][t]
            assert spec["definition"].strip() and "\n" not in spec["definition"]
            ans = spec["example"]["answer"]
            if ans is None:  # a v2 example may show a decline
                continue
            assert set(ans) <= IDS, (v, t)
            assert abs(sum(ans.values()) - 1) < 1e-9, (v, t)


def test_worked_examples_are_not_gold_items_so_they_cannot_leak_the_stress_set():
    texts = {i["text"].lower() for i in load_items()}
    for d in VOCABS.values():
        for t in d["types"]:
            assert d["defs"][t]["example"]["event"].lower() not in texts


def test_vocab_text_lists_each_types_definition_and_example():
    s = vocab_text("A6")
    for t in VOCABS["A6"]["types"]:
        assert f"- {t}: " in s and f"gives {t} = " in s


# ---- items ----
def test_items_are_the_151_events_plus_the_layer_a_redteam_cases():
    items = load_items()
    rt = [json.loads(l) for l in (DEFAULT_GOLD / "relation_redteam_v0.jsonl").read_text().splitlines() if l.strip()]
    n_a = sum(r["layer"] == "A" for r in rt)
    assert sum(i["id"].startswith("ev.") for i in items) == 151
    assert sum(i["id"].startswith("rt.") for i in items) == n_a and 0 < n_a < len(rt)
    assert len({i["id"] for i in items}) == len(items)


# ---- the pack: ungrouped and deterministic ----
def test_ungrouped_pack_lists_sectors_first_then_fields_and_keeps_every_domain():
    for v in range(3):
        _, sectors, fields = pack_lines(ungrouped_pack(PACK, v))
        assert all(l.startswith("s.") for l in sectors) and not any(l.startswith("s.") for l in fields)
        assert {l.split(" | ")[0] for l in sectors + fields} == IDS
        lines = ungrouped_pack(PACK, v).splitlines()[1:]
        assert [l.startswith("s.") for l in lines] == sorted((l.startswith("s.") for l in lines), reverse=True)


def test_variant_zero_is_sorted_by_id_and_variants_differ_but_are_stable():
    _, s0, f0 = pack_lines(ungrouped_pack(PACK, 0))
    assert f0 == sorted(f0) and s0 == sorted(s0)
    packs = [ungrouped_pack(PACK, v) for v in range(3)]
    assert len(set(packs)) == 3 and packs == [ungrouped_pack(PACK, v) for v in range(3)]


def test_counterexample_the_source_packs_grouping_is_not_reproduced():
    # the source pack lists fields under their guessed sector; the ungrouped variant 0 must differ from it
    assert ungrouped_pack(PACK, 0) != PACK
    _, _, src = pack_lines(PACK)
    assert src != sorted(src)


# ---- batches ----
def test_one_batch_per_variant_with_192_tasks_each_and_the_k3_variants():
    b = build()
    assert sorted(b) == [0, 1, 2]
    assert all(len(b[v]) - 1 == len(load_items()) for v in b)
    h = json.loads(b[1][0])
    assert h["task_type"] == "membership.A4" and h["model"] == "haiku-subagent-low"


def test_prefix_is_instructions_then_vocabulary_then_that_variants_pack_and_tasks_hold_only_the_item():
    b = build("R156")
    for v in range(3):
        prefix = json.loads(b[v][0])["prefix"]
        assert prefix.index("# Task: membership") < prefix.index("# vocabulary R156") < prefix.index("# coarse pack")
        assert prefix.endswith(ungrouped_pack(PACK, v))
        assert pack_ids(prefix) == IDS
        t = json.loads(b[v][1])
        assert set(t["input"]) == {"item", "pack"} and set(t["input"]["item"]) == {"id", "text"}
        assert t["allowed_verdicts"] == ["membership"]


def test_prefix_differs_by_vocabulary_but_task_ids_are_unique_within_a_batch():
    a, c = build("A4"), build("ACP")
    assert json.loads(a[0][0])["prefix"] != json.loads(c[0][0])["prefix"]
    ids = [json.loads(l)["task_id"] for l in a[0][1:]]
    assert len(set(ids)) == len(ids)


def test_prompt_states_outputs_only_and_forbids_inferring_intentions():
    prefix = json.loads(build()[0][0])["prefix"].lower()
    assert "outputs only" in prefix and "never infer intentions" in prefix


def test_cached_pairs_are_skipped(tmp_path):
    items = load_items()[:3]
    cache = AnswerCache(tmp_path)
    b = build(items=items)
    t = json.loads(b[0][1])
    cache._votes[("membership.A4", t["input_hash"], "haiku-subagent-low", 1)] = {0: {"variant": 0}}
    cache._loaded.add("membership.A4")
    assert len(build(items=items, cache=cache)[0]) - 1 == 2


# ---- answer validation ----
def ans(vocab="A4", **over):
    a = {"verdict": "membership", "other": None,
         "types": {t: {"c.cooking": 1.0} for t in VOCABS[vocab]["types"]}}
    a.update(over)
    return a


def test_valid_answer_with_null_types_and_a_named_other_passes():
    a = ans(other="a relation of trust")
    a["types"]["material"] = None
    assert validate_membership_answer(a, "A4", IDS) is a


@pytest.mark.parametrize("mutate,match", [
    (lambda a: a["types"].pop("form"), "differ from the vocabulary"),
    (lambda a: a["types"].update(extra={"c.cooking": 1.0}), "differ from the vocabulary"),
    (lambda a: a["types"].update(form={"c.cooking": 0.5, "c.reading": 0.4}), "sum to"),
    (lambda a: a["types"].update(form={"c.nowhere": 1.0}), "not in the pack"),
    (lambda a: a["types"].update(form={}), "empty map"),
    (lambda a: a.update(other="  "), "blank"),
    (lambda a: a.update(verdict="links"), "verdict"),
    (lambda a: a.pop("other"), "needs types and other"),
])
def test_invalid_answers_are_rejected(mutate, match):
    a = ans()
    mutate(a)
    with pytest.raises(ValidationError, match=match):
        validate_membership_answer(a, "A4", IDS)


def test_sums_are_checked_per_type_not_across_types():
    a = ans()
    a["types"]["outcome"] = {"c.cooking": 0.5, "c.reading": 0.5}
    validate_membership_answer(a, "A4", IDS)  # each type sums to 1 on its own


def test_validate_answers_checks_membership_answers_against_the_batch():
    b = build(items=load_items()[:2])[0]
    t = json.loads(b[1])
    good = {"task_id": t["task_id"], "task_type": t["task_type"], "input_hash": t["input_hash"], "variant": 0,
            "model": "haiku-subagent-low", "prompt_version": 1, "verdict": "membership", "reason": "r",
            "types": {k: {"c.cooking": 1.0} for k in VOCABS["A4"]["types"]}, "other": None}
    t2 = json.loads(b[2])
    bad = dict(good, task_id=t2["task_id"], input_hash=t2["input_hash"],
               types={**good["types"], "form": {"c.ghost": 1.0}})
    assert validate_answers(b, [json.dumps(good), json.dumps(bad)]) == [
        "line 2: c.ghost is not in the pack"]
    assert validate_answers(b, [json.dumps(good)]) == [f"missing answer for {t2['task_id']}"]
