"""Battery v2 (layer A): vocabularies with a placebo, minimal pairs, round-trip identification and the new metrics.

Acceptance tests state what must hold; counterexamples state what must fail. Red first, on the outcome: each metric
test is built so a naive stub (weighted Jaccard computed unweighted, a collision rate that ignores `should_differ_in`,
round-trip distractors that repeat the true item) returns the wrong number, not a missing-function error."""
import json
import math

import pytest

from lifeimage.cache import AnswerCache
from lifeimage.canonical import content_hash
from lifeimage.membership import (DEFAULT_GOLD, DEFAULT_PACK, PLACEBO, V1_VOCABS, VOCABS, build_membership_batches,
                                  item_input, load_items, load_items_v2, load_pairs, pack_hash, pair_item_ids,
                                  real_types, stratified_subset, vocab_text)
from lifeimage.membership_metrics import (collisions, compute, majority_top, render, vocab_metrics, weighted_jaccard)
from lifeimage.packs import pack_ids
from lifeimage.roundtrip import (LABELS, build_roundtrip_batch, domain_labels, merge_annotation, merged_annotations,
                                 pick_distractors, score_roundtrip)
from lifeimage.validate import validate_answers, validate_task

PACK = DEFAULT_PACK.read_text(encoding="utf-8")
IDS = pack_ids(PACK)
V2 = ["A3", "A3S"]


# ---- vocabularies ----
def test_v2_vocabularies_have_the_named_types_with_the_placebo_last():
    assert VOCABS["A3"]["types"] == ["form", "content", "outcome", "flavour"]
    assert VOCABS["A3S"]["types"] == ["form", "content", "outcome", "setting", "flavour"]
    assert real_types("A3S") == ["form", "content", "outcome", "setting"]


def test_every_v2_vocabulary_carries_the_placebo_and_no_v1_vocabulary_does():
    assert all(PLACEBO in VOCABS[v]["types"] for v in V2)
    assert not any(PLACEBO in VOCABS[v]["types"] for v in V1_VOCABS)
    assert VOCABS["A4"]["types"] == ["form", "material", "outcome", "reference"]  # v1 kept


def test_every_v2_type_has_four_worked_examples_over_real_pack_domains_and_declines_where_it_should():
    for v in V2:
        for t in VOCABS[v]["types"]:
            spec = VOCABS[v]["defs"][t]
            assert len(spec["examples"]) == 4 and spec["example"] == spec["examples"][0]
            assert "\n" not in spec["definition"]
            for ex in spec["examples"]:
                ans = ex["answer"]
                assert ans is None or (set(ans) <= IDS and abs(sum(ans.values()) - 1) < 1e-9), (v, t, ex)
        # declining is demonstrated: some type answers null in some example
        assert any(ex["answer"] is None for t in VOCABS[v]["types"] for ex in VOCABS[v]["defs"][t]["examples"])


def test_the_worked_events_include_film_review_vaccination_and_actor_and_are_not_gold_or_pair_texts():
    events = {ex["event"] for ex in VOCABS["A3"]["defs"]["form"]["examples"]}
    low = " ".join(events).lower()
    assert "watch" in low and "review" in low and "vaccination" in low and "actor plays a surgeon" in low
    gold = {i["text"].lower() for i in load_items_v2()}
    for v in V2:
        for t in VOCABS[v]["types"]:
            for ex in VOCABS[v]["defs"][t]["examples"]:
                assert ex["event"].lower() not in gold


def test_the_prevented_harm_example_is_an_outcome_and_the_actor_form_is_not_medicine():
    d = VOCABS["A3"]["defs"]
    vacc = [e for e in d["outcome"]["examples"] if "vaccination" in e["event"]][0]["answer"]
    actor = [e for e in d["form"]["examples"] if "actor" in e["event"]][0]["answer"]
    assert vacc and "c.medical_care" not in actor and actor == {"c.performing_arts": 1.0}
    film = [e for e in d["outcome"]["examples"] if "watch" in e["event"]][0]["answer"]
    assert film is None  # nothing observable changed


def test_vocab_text_for_v2_lists_four_examples_per_type():
    s = vocab_text("A3S")
    for t in VOCABS["A3S"]["types"]:
        assert s.count(f"- {t}: \"") == 4 and f"- {t}: " in s
    assert "four per type" in s


# ---- the prompt and the batches ----
def v2_batches(vocab="A3", items=None, **kw):
    return build_membership_batches(vocab, items or load_items_v2(), PACK, prompt_version=2, **kw)


def test_prompt_v2_declares_declining_correct_outputs_only_and_the_contrasts():
    prefix = json.loads(v2_batches()[0][0])["prefix"]
    low = prefix.lower()
    assert "declining is correct and expected" in low and "`null`" in prefix and "other" in low
    assert "outputs only" in low and "never infer intentions" in low
    assert "actor playing a surgeon" in low and "vaccinated" in low and "reviewing" in low
    assert prefix.index("# Task: membership") < prefix.index("# vocabulary A3") < prefix.index("# coarse pack")


@pytest.mark.parametrize("vocab", V2)
def test_v2_batches_have_three_variants_over_every_item_and_pair_text(vocab):
    b = v2_batches(vocab)
    items = load_items_v2()
    assert sorted(b) == [0, 1, 2] and all(len(b[v]) - 1 == len(items) for v in b)
    h = json.loads(b[0][0])
    assert h["task_type"] == f"membership.{vocab}" and h["prompt_version"] == 2
    t = json.loads(b[0][1])
    assert t["allowed_verdicts"] == ["membership"] and set(t["input"]["item"]) == {"id", "text"}


def test_v2_input_hash_equals_the_shared_item_input_hash():
    b = v2_batches()
    it = load_items_v2()[0]
    assert json.loads(b[0][1])["input_hash"] == content_hash(item_input(it, pack_hash(PACK)))


def test_v2_answer_must_carry_the_placebo_type():
    b = v2_batches(items=load_items_v2()[:1])[0]
    t = json.loads(b[1])
    types = {k: {"c.cooking": 1.0} for k in VOCABS["A3"]["types"]}
    good = {"task_id": t["task_id"], "task_type": t["task_type"], "input_hash": t["input_hash"], "variant": 0,
            "model": "haiku-subagent-low", "prompt_version": 2, "verdict": "membership", "reason": "r",
            "types": types, "other": None}
    assert validate_answers(b, [json.dumps(good)]) == []
    no_placebo = dict(good, types={k: v for k, v in types.items() if k != PLACEBO})
    assert any("differ from the vocabulary" in e for e in validate_answers(b, [json.dumps(no_placebo)]))


# ---- minimal pairs ----
def test_pairs_file_has_about_forty_well_formed_pairs_with_unique_ids():
    ps = load_pairs()
    assert 38 <= len(ps) <= 48 and len({p["id"] for p in ps}) == len(ps)
    for p in ps:
        assert set(p) >= {"id", "a", "b", "should_differ_in", "note"}
        assert p["should_differ_in"] in {"A", "B", "count_as", "D", "none"}
        assert p["a"].strip().lower() != p["b"].strip().lower() and p["note"].strip()
        if p["should_differ_in"] == "A":
            assert p["type"] in {"form", "content", "outcome", "setting"}


def test_pairs_cover_the_named_cases_with_the_named_kinds():
    by = {p["id"]: p for p in load_pairs()}
    want = {"surgery_assault": "B", "tip_bribe": "count_as", "bribe_tax": "count_as", "tip_tax": "count_as",
            "film_review": "A", "vaccination": "A", "actor_surgeon": "A", "boycott_chance": "B",
            "placebo_drug": "B", "podcast_commute": "D"}
    assert {k: by[k]["should_differ_in"] for k in want} == want
    assert by["vaccination"]["type"] == "outcome" and by["actor_surgeon"]["type"] == "form"
    assert by["film_review"]["type"] == "form" and by["film_review"]["same_in"] == ["content"]
    assert "A: form differs" in by["film_review"]["note"] and "B (production)" in by["film_review"]["note"]
    kinds = {p["should_differ_in"] for p in by.values()}
    assert kinds == {"A", "B", "count_as", "D", "none"}


def test_items_v2_are_the_192_items_plus_each_pair_text_once_by_text():
    base, items = load_items(), load_items_v2()
    assert len(base) == 192 and items[:192] == base
    texts = [i["text"].strip().lower() for i in items]
    assert len(set(texts)) == len(texts) and len({i["id"] for i in items}) == len(items)
    for p in load_pairs():
        a, b = pair_item_ids(p, items)
        assert {i["id"]: i["text"] for i in items}[a] == p["a"] and {i["id"]: i["text"] for i in items}[b] == p["b"]
    # a text shared by two pairs appears once
    assert len(items) - 192 <= 2 * len(load_pairs())


def test_a_pair_text_already_in_the_set_keeps_the_existing_id(tmp_path):
    (tmp_path / "coverage_events_v0.jsonl").write_text(json.dumps({"id": "ev.1", "text": "Brushing teeth"}) + "\n")
    (tmp_path / "relation_redteam_v0.jsonl").write_text("")
    (tmp_path / "minimal_pairs_v0.jsonl").write_text(json.dumps(
        {"id": "p", "a": "brushing TEETH", "b": "Flossing", "should_differ_in": "A", "type": "form", "note": "n"}) + "\n")
    items = load_items_v2(tmp_path)
    assert [i["id"] for i in items] == ["ev.1", "mp.p.b"]
    assert pair_item_ids(load_pairs(tmp_path)[0], items) == ("ev.1", "mp.p.b")


def test_stratified_subset_has_fifty_items_in_three_strata_and_whole_pairs():
    items, pairs = load_items_v2(), load_pairs()
    sub = stratified_subset(items, pairs)
    ids = {i["id"] for i in sub}
    assert len(sub) == 50 == len(ids)
    assert sum(i.startswith("ev.") for i in ids) >= 20 and sum(i.startswith("rt.") for i in ids) >= 8
    whole = [p for p in pairs if set(pair_item_ids(p, items)) <= ids]
    assert len(whole) >= 7
    assert {p["should_differ_in"] for p in whole} >= {"A", "B", "count_as"}
    assert stratified_subset(items, pairs) == sub  # deterministic


# ---- weighted Jaccard ----
def test_weighted_jaccard_sees_weight_shifts_the_unweighted_set_overlap_cannot():
    a, b = {"x": 0.9, "y": 0.1}, {"x": 0.1, "y": 0.9}
    assert weighted_jaccard(a, b) == pytest.approx(0.2 / 1.8)  # same domain set: unweighted would say 1.0
    assert weighted_jaccard(a, a) == 1.0
    assert weighted_jaccard({"x": 1.0}, {"y": 1.0}) == 0.0


def test_weighted_jaccard_treats_null_as_the_empty_map():
    assert weighted_jaccard(None, None) == 1.0 and weighted_jaccard({}, None) == 1.0
    assert weighted_jaccard(None, {"x": 1.0}) == 0.0
    assert weighted_jaccard({"x": 0.5, "y": 0.5}, {"x": 1.0}) == pytest.approx(1 / 3)


# ---- vocabulary metrics ----
T3 = ["form", PLACEBO]


def rec(item, variant, form=None, flavour=None, vocab="A3", model="m", pv=2):
    return {"vocab": vocab, "item": item, "variant": variant, "other": None, "model": model, "prompt_version": pv,
            "types": {"form": form, "content": None, "outcome": None, PLACEBO: flavour}}


def test_per_type_weighted_jaccard_drops_when_weights_shift_though_top_domain_alpha_is_one():
    recs = []
    for i in range(4):
        recs += [rec(f"i{i}", 0, {"a": 0.9, "b": 0.1}), rec(f"i{i}", 1, {"a": 0.55, "b": 0.45})]
    m = vocab_metrics(recs, T3)["types"]["form"]
    assert m["alpha"] == 1.0 and m["jaccard"] == 1.0
    assert m["weighted_jaccard"] == pytest.approx(0.65 / 1.35) and m["weighted_jaccard"] < 0.5


def test_null_rate_per_type():
    recs = [rec("i", 0, {"a": 1.0}), rec("i", 1, None), rec("j", 0, None), rec("j", 1, None)]
    t = vocab_metrics(recs, T3)["types"]["form"]
    assert t["null_rate"] == pytest.approx(0.75) and t["applicability"] == pytest.approx(0.25)


def test_placebo_is_reported_apart_and_left_out_of_every_mean():
    recs = []
    for i in range(4):  # form agrees perfectly; the placebo is pure noise
        recs += [rec(f"i{i}", 0, {"a": 1.0}, {"x": 1.0}), rec(f"i{i}", 1, {"a": 1.0}, {"y": 1.0})]
    m = vocab_metrics(recs, T3)
    assert PLACEBO not in m["types"] and set(m["types"]) == {"form"}
    assert m["mean_alpha"] == 1.0 and m["mean_weighted_jaccard"] == 1.0  # the noisy placebo is not averaged in
    assert m["placebo"]["fill_rate"] == 1.0 and m["placebo"]["alpha"] < 0.2 and m["placebo"]["weighted_jaccard"] == 0.0


def test_forced_rate_ignores_the_placebo_and_a_vocabulary_without_one_has_no_placebo_entry():
    recs = [rec("i", 0, {"a": 1.0}, None), rec("i", 1, {"a": 1.0}, None)]
    assert vocab_metrics(recs, T3)["forced_rate"] == 1.0  # form filled, flavour declined: still not forced
    v1 = [{"vocab": "A4", "item": "i", "variant": v, "other": None, "types": {"form": {"a": 1.0}}} for v in (0, 1)]
    assert vocab_metrics(v1, ["form"])["placebo"] is None


# ---- collision metric ----
PAIRS = [
    {"id": "p1", "a": "a1", "b": "b1", "should_differ_in": "A", "type": "outcome", "note": "n"},   # collides
    {"id": "p2", "a": "a2", "b": "b2", "should_differ_in": "A", "type": "form", "note": "n"},      # does not
    {"id": "p3", "a": "a3", "b": "b3", "should_differ_in": "B", "note": "n"},                      # identical, expected
    {"id": "p4", "a": "a4", "b": "b4", "should_differ_in": "none", "note": "n"},                   # identical, expected
]
PITEMS = [{"id": f"mp.p{n}.{s}", "text": f"{s}{n}"} for n in range(1, 5) for s in "ab"]


def crec(item, top, variant=0):
    return rec(item, variant, {top: 1.0}, {"zzz": 1.0})


def coll_records():
    r = []
    for n, (ta, tb) in enumerate([("x", "x"), ("x", "y"), ("x", "x"), ("x", "x")], 1):
        r += [crec(f"mp.p{n}.a", ta), crec(f"mp.p{n}.b", tb)]
    return r


def test_collision_rate_counts_only_pairs_marked_A_and_reports_the_rest_apart():
    c = collisions(coll_records(), PAIRS, PITEMS, T3)
    assert c["A"] == {"pairs": 2, "identical": 1, "rate": 0.5}  # a stub that ignores should_differ_in says 3/4
    assert c["B"]["rate"] == 1.0 and c["none"]["rate"] == 1.0 and "count_as" not in c
    assert c["A:outcome"]["rate"] == 1.0 and c["A:form"]["rate"] == 0.0


def test_collision_ignores_the_placebo_type_and_uses_the_majority_across_variants():
    r = []
    for n in (1, 2):  # same form everywhere; the placebo differs wildly: still a collision
        r += [rec(f"mp.p{n}.a", 0, {"x": 1.0}, {"p": 1.0}), rec(f"mp.p{n}.b", 0, {"x": 1.0}, {"q": 1.0})]
    assert collisions(r, PAIRS[:2], PITEMS, T3)["A"]["rate"] == 1.0
    maj = [crec("i", "x", 0), crec("i", "x", 1), crec("i", "y", 2)]
    assert majority_top(maj, "i", "form") == "x"


def test_collision_skips_pairs_missing_answers_instead_of_counting_them_identical():
    r = [crec("mp.p1.a", "x"), crec("mp.p1.b", "x")]
    c = collisions(r, PAIRS, PITEMS, T3)
    assert c["A"]["pairs"] == 1 and "B" not in c


def test_collision_counts_a_difference_in_any_real_type_as_not_identical():
    a = rec("mp.p1.a", 0, {"x": 1.0}, None)
    b = dict(rec("mp.p1.b", 0, {"x": 1.0}, None))
    a["types"]["outcome"], b["types"]["outcome"] = {"o1": 1.0}, {"o2": 1.0}
    assert collisions([a, b], PAIRS[:1], PITEMS, ["form", "outcome", PLACEBO])["A"]["rate"] == 0.0
    a["types"]["outcome"] = b["types"]["outcome"] = None  # both decline: agree
    assert collisions([a, b], PAIRS[:1], PITEMS, ["form", "outcome", PLACEBO])["A"]["rate"] == 1.0


def test_compute_adds_collisions_and_keeps_models_apart():
    recs = coll_records() + [dict(r, model="other") for r in coll_records()]
    out = compute(recs, PAIRS, PITEMS)
    assert set(out) == {"A3 [m]", "A3 [other]"} and out["A3 [m]"]["collisions"]["A"]["rate"] == 0.5
    assert set(compute(coll_records(), PAIRS, PITEMS)) == {"A3"}
    text = render(out)
    assert "Placebo noise floor" in text and "collision rate" in text and "weighted Jaccard" in text


# ---- round trip ----
def ann(form, content=None):
    mk = lambda d: [{"domain": d, "label": d, "weight": 1.0}] if d else None
    return {"form": mk(form), "content": mk(content)}


def test_merge_annotation_needs_a_strict_majority_to_fill_a_type_and_averages_the_fillers():
    answers = [{"types": {"form": {"a": 0.8, "b": 0.2}, "content": {"c": 1.0}}},
               {"types": {"form": {"a": 0.6, "d": 0.4}, "content": None}},
               {"types": {"form": None, "content": None}}]
    m = merge_annotation(answers, ["form", "content"], {"a": "A label"})
    assert m["content"] is None  # one of three: not a majority
    assert [d["domain"] for d in m["form"]] == ["a", "d", "b"] or [d["domain"] for d in m["form"]] == ["a", "d"]
    assert m["form"][0] == {"domain": "a", "label": "A label", "weight": 0.7}
    assert all(d["weight"] >= 0.2 for d in m["form"]) and len(m["form"]) <= 3


def test_merge_annotation_keeps_the_heaviest_domain_even_when_all_are_light():
    ws = {f"d{i}": 0.1 for i in range(10)}
    m = merge_annotation([{"types": {"form": ws}}] * 3, ["form"])
    assert [d["domain"] for d in m["form"]] == ["d0"]


def test_distractors_prefer_a_shared_top_form_domain_then_id_and_never_repeat_the_true_item():
    anns = {"i0": ann("f"), "i1": ann("g"), "i2": ann("f"), "i3": ann("f"), "i4": ann("g"), "i5": ann("f"),
            "i6": ann("f"), "i7": ann("h")}
    texts = {k: f"text of {k}" for k in anns}
    d = pick_distractors("i3", anns, texts, "form")
    assert d == ["i0", "i2", "i5", "i6"]  # the four other 'f' items by id
    assert "i3" not in d and len(set(d)) == 4
    d1 = pick_distractors("i1", anns, texts, "form")
    assert d1 == ["i4", "i0", "i2", "i3"]  # one 'g' mate, then the rest by id


def test_distractors_skip_items_with_the_same_text_as_the_true_one():
    anns = {f"i{k}": ann("f") for k in range(7)}
    texts = {k: f"t{k}" for k in anns}
    texts["i0"] = "t0"
    texts["i1"] = "T0"  # same text as the true item i0 up to case
    texts["i2"] = texts["i3"]  # two distractors with one text
    d = pick_distractors("i0", anns, texts, "form")
    assert "i1" not in d and not ("i2" in d and "i3" in d) and len(d) == 4


def synthetic(n=30):
    anns = {f"i{k:02d}": ann(f"f{k % 3}", f"c{k % 5}") for k in range(n)}
    return anns, {k: f"event number {k}" + " x" * (int(k[1:]) % 4) for k in anns}


def test_roundtrip_batch_has_five_distinct_candidates_with_the_true_one_exactly_once(tmp_path):
    anns, texts = synthetic()
    lines, keys = build_roundtrip_batch("A3", anns, texts, prompts_dir=_prompts(tmp_path))
    assert len(lines) - 1 == len(keys) == 30
    for line, key in zip(lines[1:], keys):
        t = validate_task(json.loads(line))
        cands = t["input"]["candidates"]
        assert [c["id"] for c in cands] == LABELS and t["allowed_verdicts"] == LABELS and t["k"] == 1
        cand_texts = [c["text"] for c in cands]
        assert len(set(cand_texts)) == 5  # the true text is not repeated
        true_text = texts[key["item"]]
        assert cand_texts.count(true_text) == 1 and cands[LABELS.index(key["correct"])]["text"] == true_text
        assert sorted(key["candidates"].values()).count(key["item"]) == 1


def test_the_batch_never_shows_the_text_or_the_answer_and_the_correct_label_varies(tmp_path):
    anns, texts = synthetic()
    lines, keys = build_roundtrip_batch("A3", anns, texts, prompts_dir=_prompts(tmp_path))
    for line, key in zip(lines[1:], keys):
        t = json.loads(line)
        assert "text" not in json.dumps(t["input"]["annotation"]) and "correct" not in line
        assert key["task_id"] == t["task_id"]
    assert len({k["correct"] for k in keys}) >= 4  # shuffled, not always c1


def test_roundtrip_batch_is_deterministic_and_skips_cached_pairs(tmp_path):
    anns, texts = synthetic(12)
    pr = _prompts(tmp_path)
    a = build_roundtrip_batch("A3", anns, texts, prompts_dir=pr)
    assert a == build_roundtrip_batch("A3", anns, texts, prompts_dir=pr)
    cache = AnswerCache(tmp_path / "c")
    t = json.loads(a[0][1])
    cache._loaded.add("roundtrip.A3")
    cache._votes[("roundtrip.A3", t["input_hash"], "haiku-subagent-low", 1)] = {0: {"variant": 0}}
    assert len(build_roundtrip_batch("A3", anns, texts, prompts_dir=pr, cache=cache)[0]) == len(a[0]) - 1


def test_an_item_with_too_few_possible_distractors_is_left_out(tmp_path):
    anns, texts = synthetic(4)
    assert build_roundtrip_batch("A3", anns, texts, prompts_dir=_prompts(tmp_path))[1] == []


def _prompts(tmp_path):
    d = tmp_path / "pr"
    d.mkdir(exist_ok=True)
    (d / "roundtrip.v1.md").write_text("# Task: roundtrip\nPick.\n")
    return d


def test_roundtrip_answers_validate_against_the_batch(tmp_path):
    anns, texts = synthetic(8)
    lines, keys = build_roundtrip_batch("A3", anns, texts, prompts_dir=_prompts(tmp_path))
    t = json.loads(lines[1])
    a = {"task_id": t["task_id"], "task_type": t["task_type"], "input_hash": t["input_hash"], "variant": 0,
         "model": "haiku-subagent-low", "prompt_version": 1, "verdict": "c2", "reason": "r"}
    bad = dict(a, verdict="c9")
    assert validate_answers(lines[:2], [json.dumps(a)]) == []
    assert validate_answers(lines[:2], [json.dumps(bad)]) != []


def test_score_counts_unanswered_tasks_as_wrong_and_reports_chance():
    keys = [{"task_id": f"t{i}", "correct": "c1"} for i in range(4)]
    answers = [{"task_id": "t0", "verdict": "c1"}, {"task_id": "t1", "verdict": "c1"}, {"task_id": "t2", "verdict": "c3"}]
    s = score_roundtrip(keys, answers)
    assert s["accuracy"] == 0.5 and s["answered"] == 3 and s["correct"] == 2 and s["chance"] == 0.2
    assert score_roundtrip(keys, [{"task_id": f"t{i}", "verdict": "c1"} for i in range(4)])["accuracy"] == 1.0
    assert math.isnan(score_roundtrip([], [])["accuracy"])


# ---- round trip on the cached v1 answers ----
@pytest.mark.parametrize("vocab", ["A4", "ACP"])
def test_cached_v1_answers_give_a_full_roundtrip_batch(vocab):
    items = load_items()
    anns = merged_annotations(vocab, items, PACK, AnswerCache(), model="haiku-subagent-low", prompt_version=1)
    assert len(anns) == 192
    assert all(set(a) == set(VOCABS[vocab]["types"]) for a in anns.values())
    labels = domain_labels(PACK)
    assert all(d["label"] == labels[d["domain"]] for a in anns.values() for ds in a.values() if ds for d in ds)
    texts = {i["id"]: i["text"] for i in items}
    lines, keys = build_roundtrip_batch(vocab, anns, texts)
    assert len(keys) == 192
    for line, key in zip(lines[1:], keys):
        cands = [c["text"] for c in json.loads(line)["input"]["candidates"]]
        assert len(set(cands)) == 5 and cands.count(texts[key["item"]]) == 1
