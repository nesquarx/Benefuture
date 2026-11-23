"""Round-trip v3 on the confirming battery: candidates by nearest annotation similarity (nearest decoy's similarity
recorded per task), wording equalised so the true text is not the plainest, a text-only control batch, and a scorer
with accuracy by similarity decile, the control accuracy and the leak-corrected accuracy.

Red first on the outcome: a naive stub (first four ids as decoys, no recorded similarity, a control that still shows
the annotation, one overall accuracy repeated per decile, no leak correction) returns wrong results."""
import json
import math

import pytest

from lifeimage.confirm_roundtrip import (A_TYPES, WORDING_TOLERANCE, added_wording, annotation_similarity,
                                         annotations_from_confirm_answers, build_roundtrip_v3, in_wording_band,
                                         pick_decoys, score_v3, similarity_deciles)
from lifeimage.roundtrip import LABELS
from lifeimage.roundtrip_graded import wilson_interval


def mk(*pairs):
    return [{"domain": d, "label": d, "weight": w} for d, w in pairs] or None


def ann(form=None, content=None, outcome=None, setting=None):
    return {"form": mk(*form) if form else None, "content": mk(*content) if content else None,
            "outcome": mk(*outcome) if outcome else None, "setting": mk(*setting) if setting else None}


# ---- similarity ----
def test_similarity_is_weighted_jaccard_averaged_over_types_either_side_answers():
    a = ann(form=[("x", 1.0)], content=[("p", 0.5), ("q", 0.5)])
    assert annotation_similarity(a, a) == 1.0
    assert annotation_similarity(a, ann(form=[("y", 1.0)], content=[("z", 1.0)])) == 0.0
    # form identical (1.0); content: sum of mins 0.5 over sum of maxes (1.0 on p + 0.5 on q) = 1/3
    b = ann(form=[("x", 1.0)], content=[("p", 1.0)])
    assert annotation_similarity(a, b) == pytest.approx((1.0 + 1 / 3) / 2)
    # a type null on both sides does not count: adding null outcome/setting changes nothing
    assert annotation_similarity(a, b, A_TYPES) == annotation_similarity(a, b, ["form", "content"])


def test_similarity_separates_an_answered_type_from_a_null_one():
    a = ann(form=[("x", 1.0)], outcome=[("o", 1.0)])
    b = ann(form=[("x", 1.0)])
    assert annotation_similarity(a, b) == pytest.approx(0.5)  # outcome answered on one side only counts as 0


def test_two_all_null_annotations_are_identical():
    assert annotation_similarity(ann(), ann()) == 1.0


# ---- wording ----
def test_added_wording_counts_words_after_the_first_clause_boundary():
    assert added_wording("A surgeon operates on a knee") == 0
    assert added_wording("A surgeon operates on a knee, and the patient walks again") == 5
    assert added_wording("A surgeon operates on a knee while the patient sleeps") == 4


def test_wording_band_is_fifteen_percent_of_the_true_text_with_a_one_word_floor():
    assert WORDING_TOLERANCE == 0.15
    true = "one two three four five six seven eight nine ten, then eleven twelve thirteen thirty"  # 15 words, tail 5
    inside = "one two three four five six seven eight nine ten, then eleven twelve thirteen"  # 14 words, tail 4
    far = "one two three four five six seven eight"
    assert in_wording_band(true, inside) and not in_wording_band(true, far)
    assert in_wording_band("a b c", "a b c d") and not in_wording_band("a b c", "a b c d e")  # one-word floor


# ---- decoy choice ----
def world():
    """One true item T and candidates of graded annotation similarity, all with similar wording."""
    anns = {"T": ann(form=[("f", 1.0)], content=[("c", 1.0)], setting=[("s", 1.0)])}
    texts = {"T": "A woman repairs a roof for her neighbour after the storm"}
    close = [("N1", 1.0), ("N2", 0.9), ("N3", 0.8), ("N4", 0.7)]
    for name, w in close:  # decreasing similarity through the content weight
        anns[name] = ann(form=[("f", 1.0)], content=[("c", w), ("k", 1 - w)] if w < 1 else [("c", 1.0)],
                         setting=[("s", 1.0)])
        texts[name] = f"A man repairs a roof for his cousin after the flood {name}"
    for n in range(6):  # far annotations
        anns[f"F{n}"] = ann(form=[(f"g{n}", 1.0)], content=[(f"d{n}", 1.0)], setting=[(f"t{n}", 1.0)])
        texts[f"F{n}"] = f"A girl bakes a loaf for her teacher after the fair F{n}"
    return anns, texts


def test_the_decoys_are_the_nearest_annotations_not_the_first_ids():
    anns, texts = world()
    decoys, info = pick_decoys("T", anns, texts)
    assert sorted(decoys) == ["N1", "N2", "N3", "N4"]
    assert info["equalised"] is True


def test_the_nearest_decoy_similarity_is_recorded_per_task():
    anns, texts = world()
    lines, keys, _, _ = build_roundtrip_v3(anns, texts)
    k = {r["item"]: r for r in keys}["T"]
    assert k["nearest_decoy_similarity"] == pytest.approx(annotation_similarity(anns["T"], anns["N1"]))
    assert k["nearest_decoy_similarity"] > 0.9
    assert set(k["decoy_similarity"]) == set(LABELS) - {k["correct"]}
    assert max(k["decoy_similarity"].values()) == k["nearest_decoy_similarity"]


def test_wording_is_equalised_even_when_the_nearest_annotations_have_different_wording():
    anns, texts = world()
    for n in ("N1", "N2"):  # the two nearest annotations carry much more added wording
        texts[n] = texts[n] + " and then the whole village gathered to thank them for the long hard work of that week"
    decoys, info = pick_decoys("T", anns, texts)
    assert "N1" not in decoys and "N2" not in decoys
    assert info["equalised"] is True
    assert all(in_wording_band(texts["T"], texts[d]) for d in decoys)


def test_the_true_text_is_never_the_unique_plainest_when_a_plainer_decoy_exists():
    anns, texts = world()
    texts["T"] = "A woman repairs a roof for her neighbour today"  # 8 words, no added wording
    for n in ("N1", "N2", "N3", "N4"):  # every near decoy carries a little more wording
        texts[n] = f"A man repairs a roof for his cousin, {n}"  # 9 words, one word of tail
    texts["F4"] = "A girl bakes bread for her school today"  # as plain as the true text, inside the band
    plain = lambda t: (len(t.split()), added_wording(t))
    assert all(plain(texts[n]) > plain(texts["T"]) for n in ("N1", "N2", "N3", "N4"))
    decoys, info = pick_decoys("T", anns, texts)
    assert "F4" in decoys
    assert min(plain(texts[d]) for d in decoys) <= plain(texts["T"])
    assert info["true_plainest"] is False


def test_when_no_plainer_decoy_exists_the_flag_says_so():
    anns, texts = world()
    texts["T"] = "A woman repairs a roof for her neighbour today"
    for n in ("N1", "N2", "N3", "N4"):
        texts[n] = f"A man repairs a roof for his cousin, {n}"
    decoys, info = pick_decoys("T", anns, texts)
    assert info["true_plainest"] is True and sorted(decoys) == ["N1", "N2", "N3", "N4"]


def test_a_shortfall_in_the_band_is_loud_not_silent():
    anns, texts = world()
    for n in texts:
        if n != "T":
            texts[n] = f"Short text {n}"
    decoys, info = pick_decoys("T", anns, texts)
    assert len(decoys) == 4
    assert info["equalised"] is False and set(info["out_of_band"]) == set(decoys)


def test_no_candidate_repeats_the_true_text():
    anns, texts = world()
    texts["N1"] = texts["T"].upper()
    decoys, _ = pick_decoys("T", anns, texts)
    assert "N1" not in decoys


# ---- the batches ----
def test_control_batch_has_the_same_candidates_in_the_same_order_and_no_annotation():
    anns, texts = world()
    lines, keys, clines, ckeys = build_roundtrip_v3(anns, texts)
    ann_tasks = [json.loads(l) for l in lines[1:]]
    ctl_tasks = [json.loads(l) for l in clines[1:]]
    assert len(ann_tasks) == len(ctl_tasks) == len(keys) == len(ckeys) == len(anns)
    for a, c in zip(ann_tasks, ctl_tasks):
        assert "annotation" in a["input"] and "annotation" not in c["input"]
        assert a["input"]["candidates"] == c["input"]["candidates"]
        assert a["task_id"] != c["task_id"]
    assert [k["correct"] for k in keys] == [k["correct"] for k in ckeys]
    ha, hc = json.loads(lines[0]), json.loads(clines[0])
    assert ha["task_type"] != hc["task_type"] and ha["prefix"] != hc["prefix"]


def test_candidates_are_labelled_and_the_key_identifies_the_true_one():
    anns, texts = world()
    lines, keys, _, _ = build_roundtrip_v3(anns, texts)
    for l, k in zip(lines[1:], keys):
        t = json.loads(l)
        cands = {c["id"]: c["text"] for c in t["input"]["candidates"]}
        assert sorted(cands) == LABELS and t["allowed_verdicts"] == LABELS
        assert cands[k["correct"]] == texts[k["item"]]
        assert k["candidates"][k["correct"]] == k["item"]


# ---- answers to annotations ----
def test_annotations_merge_the_variants_by_strict_majority():
    def a(task, outcome):
        return {"task_id": task, "variant": int(task[-1]), "types": {"form": {"c.x": 1.0}, "content": {"c.y": 1.0},
                "outcome": outcome, "setting": None, "flavour": {"c.z": 1.0}}}
    answers = [a("t-v0", {"c.o": 1.0}), a("t-v1", {"c.o": 1.0}), a("t-v2", None)]
    out = annotations_from_confirm_answers(answers, {"t-v0": "item1", "t-v1": "item1", "t-v2": "item1"}, {"c.o": "Outcome"})
    assert out["item1"]["outcome"][0]["domain"] == "c.o" and out["item1"]["outcome"][0]["label"] == "Outcome"
    assert out["item1"]["setting"] is None and "flavour" not in out["item1"]
    answers = [a("t-v0", {"c.o": 1.0}), a("t-v1", None), a("t-v2", None)]
    out = annotations_from_confirm_answers(answers, {"t-v0": "i", "t-v1": "i", "t-v2": "i"}, {})
    assert out["i"]["outcome"] is None


# ---- deciles ----
def test_deciles_rank_the_tasks_by_nearest_decoy_similarity():
    sims = [0.05 * i for i in range(20)]
    d = similarity_deciles(sims)
    assert sorted(d.count(k) for k in range(10)) == [2] * 10
    assert d[0] == d[1] == 0 and d[18] == d[19] == 9 and d == sorted(d)
    assert similarity_deciles(list(reversed(sims))) == list(reversed(d))


def test_deciles_of_fewer_than_ten_tasks_leave_some_empty_and_ties_are_deterministic():
    assert similarity_deciles([0.5]) == [0]
    t = similarity_deciles([0.7] * 4)
    assert t == similarity_deciles([0.7] * 4) and t == sorted(t)


# ---- scorer ----
def keyrows(n, label_of=lambda i: "c1"):
    return [{"task_id": f"a{i}", "item": f"i{i}", "correct": label_of(i), "nearest_decoy_similarity": i / n}
            for i in range(n)]


def ctl_rows(rows):
    return [dict(r, task_id=r["task_id"].replace("a", "c")) for r in rows]


def answers_for(rows, right):
    return [{"task_id": r["task_id"], "verdict": r["correct"] if right(i, r) else "c2"} for i, r in enumerate(rows)]


def test_score_reports_decile_accuracy_with_wilson_intervals_and_the_leak_corrected_gain():
    rows = keyrows(40)
    ctl = ctl_rows(rows)
    # annotation: right on 36 of 40 (wrong on the 4 most similar); control right on 12 of 40 (the least similar 12)
    ann_ans = answers_for(rows, lambda i, r: i < 36)
    ctl_ans = answers_for(ctl, lambda i, r: i < 12)
    s = score_v3(rows, ann_ans, ctl, ctl_ans)
    assert s["n"] == 40
    assert s["annotated"]["accuracy"] == pytest.approx(0.9) and s["control"]["accuracy"] == pytest.approx(0.3)
    assert s["leak_corrected"]["accuracy"] == pytest.approx(0.6)
    assert s["annotated"]["ci"] == pytest.approx(list(wilson_interval(36, 40)))
    assert len(s["deciles"]) == 10 and sum(d["n"] for d in s["deciles"]) == 40
    assert [d["annotated"]["correct"] for d in s["deciles"]] == [4, 4, 4, 4, 4, 4, 4, 4, 4, 0]
    assert [d["control"]["correct"] for d in s["deciles"]] == [4, 4, 4, 0, 0, 0, 0, 0, 0, 0]
    assert s["deciles"][0]["annotated"]["ci"] == pytest.approx(list(wilson_interval(4, 4)))
    assert s["deciles"][9]["leak_corrected"] == pytest.approx(0.0 - 0.0)
    assert s["deciles"][3]["leak_corrected"] == pytest.approx(1.0)
    lo, hi = s["deciles"][2]["sim_range"]
    assert lo <= hi and s["deciles"][0]["sim_range"][1] <= s["deciles"][9]["sim_range"][0]


def test_a_leaky_text_makes_the_corrected_accuracy_zero_not_the_raw_one():
    rows = keyrows(30)
    ctl = ctl_rows(rows)
    ans = answers_for(rows, lambda i, r: i % 3 != 0)
    cans = answers_for(ctl, lambda i, r: i % 3 != 0)  # text alone is as good as the annotation
    s = score_v3(rows, ans, ctl, cans)
    assert s["annotated"]["accuracy"] == pytest.approx(20 / 30)
    assert s["leak_corrected"]["accuracy"] == pytest.approx(0.0)
    assert s["leak_corrected"]["effect_counts"] is False


def test_a_real_gain_beats_the_significance_threshold():
    rows = keyrows(60)
    ctl = ctl_rows(rows)
    s = score_v3(rows, answers_for(rows, lambda i, r: True), ctl, answers_for(ctl, lambda i, r: i % 5 == 0))
    assert s["leak_corrected"]["accuracy"] == pytest.approx(0.8)
    assert s["leak_corrected"]["effect_counts"] is True and s["leak_corrected"]["z"] == 2.0


def test_unanswered_tasks_count_as_wrong_in_both_arms():
    rows = keyrows(10)
    ctl = ctl_rows(rows)
    s = score_v3(rows, answers_for(rows, lambda i, r: True)[:5], ctl, [])
    assert s["annotated"]["correct"] == 5 and s["annotated"]["answered"] == 5
    assert s["control"]["correct"] == 0 and s["control"]["answered"] == 0


def test_chance_is_one_in_five_and_items_pair_by_item_not_by_task_id():
    rows = keyrows(10)
    ctl = [dict(r, task_id=f"zz{i}") for i, r in enumerate(ctl_rows(rows))]
    s = score_v3(rows, answers_for(rows, lambda i, r: True), ctl, answers_for(ctl, lambda i, r: False))
    assert s["annotated"]["chance"] == pytest.approx(0.2) and s["leak_corrected"]["accuracy"] == pytest.approx(1.0)


def test_tasks_with_unequalised_wording_are_scored_apart():
    rows = keyrows(20)
    for i, r in enumerate(rows):
        r["equalised"] = i >= 10
    ctl = ctl_rows(rows)
    s = score_v3(rows, answers_for(rows, lambda i, r: True), ctl, answers_for(ctl, lambda i, r: i < 10))
    assert s["leak_corrected"]["accuracy"] == pytest.approx(0.5)
    assert s["equalised_only"]["n"] == 10 and s["equalised_only"]["leak_corrected"]["accuracy"] == pytest.approx(1.0)
    assert s["equalised_only"]["control"]["accuracy"] == 0.0


# ---- from answers ----
def test_the_batches_are_built_from_combined_answers_for_the_annotated_items_only(tmp_path):
    from lifeimage.confirm import build_confirm_batches
    from lifeimage.membership import DEFAULT_PACK, pack_lines
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    doms = sorted(l.split(" | ")[0] for l in pack_lines(pack)[2])
    items = [{"id": f"x.{n}", "text": f"A person does thing number {n} for a neighbour on a day", "source": "a_pool",
              "participants": [{"id": "p", "label": "the person"}]} for n in range(8)]
    items.append(dict(items[0], id="x.unanswered", text="A person does a different thing for a neighbour on a day"))
    parts = build_confirm_batches(items, pack)
    paths = []
    for v, ps in parts.items():
        b = tmp_path / f"confirm.v1.var{v}.jsonl"
        b.write_text("\n".join(ps[0]) + "\n")
        ans = []
        for l in ps[0][1:]:
            t = json.loads(l)
            if t["input"]["item"]["id"] == "x.unanswered":
                continue
            n = int(t["input"]["item"]["id"].split(".")[1])
            ans.append({"task_id": t["task_id"], "variant": v, "types": {
                "form": {doms[n % 3]: 1.0}, "content": {doms[10 + n]: 1.0}, "outcome": None, "setting": None, "flavour": None}})
        a = tmp_path / f"confirm.v1.var{v}.answers.jsonl"
        a.write_text("\n".join(json.dumps(x) for x in ans) + "\n")
        paths.append(a)
    from lifeimage.confirm_roundtrip import roundtrip_from_answers
    lines, keys, clines, ckeys = roundtrip_from_answers(paths, items, pack)
    assert sorted(k["item"] for k in keys) == sorted(f"x.{n}" for n in range(8))
    assert len(clines) == len(lines) and all("annotation" not in json.loads(l)["input"] for l in clines[1:])
    t = json.loads(lines[1])
    assert t["input"]["annotation"]["content"][0]["label"]  # a domain label from the pack, not the bare id
    # the unanswered item may not appear as a candidate: it has no annotation to be near
    assert all("x.unanswered" not in k["candidates"].values() for k in keys)
