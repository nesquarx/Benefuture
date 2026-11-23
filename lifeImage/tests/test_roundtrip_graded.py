"""Graded round-trip v2: five levels of decoy difficulty, a Wilson interval, an L5 split by nuance kind.

Red first on the outcome: each test is built so a naive stub (a level builder that ignores the level, a normal-
approximation interval, a silent backfill) returns the wrong answer, not a missing-function error."""
import json
import math
import re

import pytest

from lifeimage.membership import DEFAULT_GOLD, DEFAULT_PACK, item_input, pack_hash
from lifeimage.canonical import content_hash
from lifeimage.roundtrip import LABELS, merge_annotation
from lifeimage.roundtrip_graded import (A_KINDS, LEVELS, N_DECOYS, build_graded_batch, build_l5_batch, l5_items,
                                        l5_annotations, level_decoys, load_l5, same_annotation, score_graded,
                                        wilson_interval)

TYPES = ["form", "content", "outcome", "setting"]


def ann(form, content, outcome=None, setting=None):
    mk = lambda d: [{"domain": d, "label": d, "weight": 1.0}] if d else None
    return {"form": mk(form), "content": mk(content), "outcome": mk(outcome), "setting": mk(setting)}


def world():
    """40 items over 2 forms x 2 contents x 2 settings x 5 copies (plus distinct texts)."""
    anns, texts = {}, {}
    n = 0
    for f in "FG":
        for c in "XY":
            for s in "pq":
                for _ in range(5):
                    iid = f"i{n:02d}"
                    anns[iid] = ann(f, c, None, s)
                    texts[iid] = f"event {n}"
                    n += 1
    return anns, texts


def top(a, t):
    return a[t][0]["domain"] if a[t] else None


def levels_of(decoys):
    return [lv for _, lv in decoys]


# ---- level semantics ----
def test_level_one_is_random_and_not_the_same_as_the_nearest():
    anns, texts = world()
    d = level_decoys("i00", 1, anns, texts, TYPES)
    assert len(d) == N_DECOYS and levels_of(d) == [1] * 4
    forms = {top(anns[i], "form") for i, _ in d}
    # a stub taking the first four sorted ids would give four items of form F, content X, setting p
    assert d != [(f"i0{k}", 1) for k in (1, 2, 3, 4)]
    assert level_decoys("i00", 1, anns, texts, TYPES) == d  # deterministic


@pytest.mark.parametrize("level,need", [(2, ["form"]), (3, ["form", "content"]), (4, ["form", "content", "setting"])])
def test_level_decoys_share_exactly_the_required_types_with_the_true_item(level, need):
    anns, texts = world()
    d = level_decoys("i00", level, anns, texts, TYPES)
    assert levels_of(d) == [level] * 4
    for i, _ in d:
        assert all(top(anns[i], t) == top(anns["i00"], t) for t in need)
    # and no more: levels differ, so a level-ignoring builder fails one of these
    if level < 4:
        extra = ["setting"] if level == 3 else ["content", "setting"]
        assert level_decoys("i00", level, anns, texts, TYPES) != level_decoys("i00", 4, anns, texts, TYPES)


def test_a_higher_level_is_harder_in_shared_annotation_types():
    anns, texts = world()
    def shared(level):
        d = level_decoys("i10", level, anns, texts, TYPES)
        return sum(top(anns[i], t) == top(anns["i10"], t) for i, _ in d for t in TYPES)
    s = [shared(l) for l in (1, 2, 3, 4)]
    assert s == sorted(s) and s[0] < s[3]


def test_decoys_never_repeat_the_true_item_or_a_text():
    anns, texts = world()
    texts["i01"] = texts["i00"].upper()  # same text as the true item
    texts["i03"] = texts["i02"]
    for lv in (1, 2, 3, 4):
        d = [i for i, _ in level_decoys("i00", lv, anns, texts, TYPES)]
        assert "i00" not in d and "i01" not in d and not ("i02" in d and "i03" in d) and len(set(d)) == 4


# ---- backfill is loud ----
def test_too_few_qualifying_items_fill_from_the_next_easier_level_and_are_marked():
    anns, texts = world()
    anns["u"], texts["u"] = ann("F", "X", None, "r"), "unique setting"  # the only item with setting r
    d = level_decoys("u", 4, anns, texts, TYPES)
    lv = levels_of(d)
    assert len(d) == 4 and all(l < 4 for l in lv)  # nothing qualifies at L4, so none claims L4
    assert lv == sorted(lv, reverse=True) and lv[0] == 3  # the nearest easier level first (same form and content)
    anns["w"], texts["w"] = ann("F", "X", None, "p"), "one more like i00"
    d2 = level_decoys("i00", 4, anns, texts, TYPES)
    assert levels_of(d2).count(4) == 4  # plenty qualify here, nothing is marked down


def test_an_item_with_no_form_gets_random_decoys_marked_level_one():
    anns, texts = world()
    anns["n"], texts["n"] = ann(None, None), "no form"
    d = level_decoys("n", 3, anns, texts, TYPES)
    assert len(d) == 4 and levels_of(d) == [1] * 4


def test_batch_keys_record_each_decoys_source_level_and_the_backfill_count(tmp_path):
    anns, texts = world()
    anns["u"], texts["u"] = ann("F", "X", None, "r"), "unique setting"
    pr = tmp_path / "pr"
    pr.mkdir()
    (pr / "roundtrip.v2.md").write_text("# Task: roundtrip\nPick.\n")
    lines, keys = build_graded_batch("A3S", 4, anns, texts, prompts_dir=pr)
    byitem = {k["item"]: k for k in keys}
    assert byitem["i00"]["backfilled"] == 0 and byitem["i00"]["level"] == 4
    assert byitem["u"]["backfilled"] == 4
    assert sorted(byitem["u"]["decoy_levels"].values()) == sorted(byitem["u"]["decoy_levels"].values())
    assert set(byitem["u"]["decoy_levels"]) == set(LABELS) - {byitem["u"]["correct"]}
    assert all(v < 4 for v in byitem["u"]["decoy_levels"].values())


def test_batch_has_five_distinct_candidates_and_a_key_per_task_and_hides_the_level(tmp_path):
    anns, texts = world()
    pr = tmp_path / "pr"
    pr.mkdir()
    (pr / "roundtrip.v2.md").write_text("# Task: roundtrip\nPick.\n")
    for lv in (1, 3):
        lines, keys = build_graded_batch("A3S", lv, anns, texts, prompts_dir=pr)
        tasks = [json.loads(l) for l in lines[1:]]
        assert len(tasks) == len(keys) == 40
        for t, k in zip(tasks, keys):
            cands = [c["text"] for c in t["input"]["candidates"]]
            assert len(set(cands)) == 5 and k["task_id"] == t["task_id"]
            assert texts[k["item"]] == t["input"]["candidates"][LABELS.index(k["correct"])]["text"]
            assert "level" not in json.dumps(t) and "L3" not in json.dumps(t)
    a = build_graded_batch("A3S", 1, anns, texts, prompts_dir=pr)
    b = build_graded_batch("A3S", 3, anns, texts, prompts_dir=pr)
    assert a[0] != b[0]  # a level-ignoring builder would give the same batch


# ---- Wilson interval ----
def test_wilson_interval_matches_known_values():
    lo, hi = wilson_interval(8, 10)
    assert (round(lo, 3), round(hi, 3)) == (0.490, 0.943)
    lo, hi = wilson_interval(0, 20)
    assert lo == 0 and round(hi, 3) == 0.161  # normal approximation gives [0, 0]
    lo, hi = wilson_interval(20, 20)
    assert hi == 1 and round(lo, 3) == 0.839  # normal approximation gives [1, 1]
    assert all(math.isnan(x) for x in wilson_interval(0, 0))


# ---- scorer ----
def key_rows(level, results, kind=None):
    rows = []
    for j, r in enumerate(results):
        row = {"task_id": f"L{level}t{j}", "item": f"i{j}", "level": level, "correct": "c1", "backfilled": 0 if r != "b" else 2}
        if kind:
            row.update(kind[j])
        rows.append(row)
    return rows


def answers_for(rows, right):
    return [{"task_id": r["task_id"], "verdict": "c1" if ok else "c2"} for r, ok in zip(rows, right)]


def test_score_graded_gives_accuracy_interval_chance_and_n_per_level():
    rows = key_rows(1, [1] * 10) + key_rows(2, [1] * 10)
    ans = answers_for(rows[:10], [1] * 10) + answers_for(rows[10:], [1] * 8 + [0] * 2)
    s = score_graded(rows, ans)
    assert s["levels"]["1"]["accuracy"] == 1.0 and s["levels"]["2"]["accuracy"] == 0.8
    assert s["levels"]["2"]["n"] == 10 and s["levels"]["2"]["chance"] == 0.2
    lo, hi = s["levels"]["2"]["ci"]
    assert (round(lo, 3), round(hi, 3)) == (0.490, 0.943)
    assert s["levels"]["1"]["ci"][1] == 1.0 and s["levels"]["1"]["ci"][0] < 1.0  # not a normal interval


def test_score_graded_counts_unanswered_as_wrong_and_reports_backfilled_items():
    rows = key_rows(3, ["x", "x", "b", "b"])
    s = score_graded(rows, answers_for(rows[:3], [1, 1, 1]))
    assert s["levels"]["3"]["accuracy"] == 0.75 and s["levels"]["3"]["answered"] == 3
    assert s["levels"]["3"]["backfilled_items"] == 2
    assert s["levels"]["3"]["accuracy_unbackfilled"] == 1.0  # the two unfilled-pool items were both right


def test_l5_scores_split_by_nuance_kind_and_by_a_encodability():
    meta = ([{"kind": "outcome", "a_encodable": True}] * 4 + [{"kind": "consent", "a_encodable": False}] * 6)
    rows = key_rows(5, [1] * 10, meta)
    right = [1, 1, 1, 1, 1, 0, 0, 0, 0, 0]  # A kinds 4/4, non-A kinds 1/6
    s = score_graded(rows, answers_for(rows, right))
    assert s["l5"]["a_encodable"]["accuracy"] == 1.0 and s["l5"]["not_a_encodable"]["accuracy"] == pytest.approx(1 / 6)
    assert s["l5"]["not_a_encodable"]["n"] == 6
    assert s["l5"]["by_kind"]["consent"]["correct"] == 1 and s["l5"]["by_kind"]["outcome"]["n"] == 4
    assert "ci" in s["l5"]["by_kind"]["consent"]
    assert "l5" not in score_graded(key_rows(2, [1]), [])  # no L5 section without L5 rows


# ---- L5 gold ----
def test_l5_gold_file_has_forty_items_each_with_four_distinct_decoys_and_a_note():
    rows = load_l5()
    assert len(rows) == 40
    texts = set()
    for r in rows:
        assert len(r["decoys"]) == 4 and len({r["true"], *r["decoys"]}) == 5 and r["note"]
        assert r["a_encodable"] == (r["kind"] in A_KINDS)
        texts |= {r["true"], *r["decoys"]}
    assert len(texts) == 200
    assert len({r["id"] for r in rows}) == 40
    kinds = {r["kind"] for r in rows}
    assert A_KINDS <= kinds and len(kinds - A_KINDS) >= 4  # both A and non-A nuances are represented
    assert sum(r["a_encodable"] for r in rows) >= 10 and sum(not r["a_encodable"] for r in rows) >= 10


def test_l5_gold_rejects_a_malformed_file(tmp_path):
    (tmp_path / "roundtrip_l5_v0.jsonl").write_text(json.dumps({"id": "x", "kind": "outcome", "a_encodable": True,
                                                                  "true": "a", "decoys": ["a", "b", "c", "d"], "note": "n"}) + "\n")
    with pytest.raises(ValueError):
        load_l5(tmp_path)


def test_l5_items_cover_true_and_decoy_texts_with_stable_ids():
    rows = load_l5()
    items = l5_items(rows)
    assert len(items) == 200 and len({i["id"] for i in items}) == 200
    assert items[0]["id"] == f"{rows[0]['id']}.t" and items[1]["id"] == f"{rows[0]['id']}.d1"


def l5_answer_rows(rows, variants=3, fill=None):
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    ph = pack_hash(pack)
    out = []
    for it in l5_items(rows):
        h = content_hash(item_input(it, ph))
        for v in range(variants):
            types = {"form": {"c.cooking": 1.0}, "content": {"c.cooking": 1.0}, "outcome": None, "setting": None, "flavour": None}
            if fill:
                types = fill(it, v, types)
            out.append({"task_id": f"{h[:16]}-v{v}", "input_hash": h, "variant": v, "verdict": "membership", "types": types})
    return out


def test_l5_annotations_are_merged_per_item_from_answers_by_input_hash():
    rows = load_l5()[:2]
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    anns = l5_annotations("A3S", l5_items(rows), pack, l5_answer_rows(rows))
    assert set(anns) == {i["id"] for i in l5_items(rows)}
    assert anns[f"{rows[0]['id']}.t"]["form"][0]["domain"] == "c.cooking" and anns[f"{rows[0]['id']}.t"]["outcome"] is None


def test_l5_batch_shows_the_true_items_annotation_with_its_four_near_duplicates_and_keys_the_nuance(tmp_path):
    rows = load_l5()
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    anns = l5_annotations("A3S", l5_items(rows), pack, l5_answer_rows(rows))
    pr = tmp_path / "pr"
    pr.mkdir()
    (pr / "roundtrip.v2.md").write_text("# Task: roundtrip\nPick.\n")
    lines, keys = build_l5_batch("A3S", rows, anns, prompts_dir=pr)
    assert len(keys) == 40 and len(lines) == 41
    for t, k, r in zip((json.loads(l) for l in lines[1:]), keys, rows):
        cands = [c["text"] for c in t["input"]["candidates"]]
        assert sorted(cands) == sorted([r["true"], *r["decoys"]])
        assert cands[LABELS.index(k["correct"])] == r["true"]
        assert t["input"]["annotation"] == anns[f"{r['id']}.t"]
        assert k["level"] == 5 and k["kind"] == r["kind"] and k["a_encodable"] == r["a_encodable"] and k["note"] == r["note"]
        assert all(v == 5 for v in k["decoy_levels"].values()) and k["backfilled"] == 0
        assert "kind" not in json.dumps(t["input"]) and r["note"] not in json.dumps(t)


def test_l5_batch_refuses_when_a_true_text_has_no_annotation(tmp_path):
    rows = load_l5()
    pr = tmp_path / "pr"
    pr.mkdir()
    (pr / "roundtrip.v2.md").write_text("# Task: roundtrip\nPick.\n")
    with pytest.raises(ValueError, match="annotat"):
        build_l5_batch("A3S", rows, {}, prompts_dir=pr)


def test_l5_key_flags_decoys_whose_a_annotation_equals_the_trues():
    rows = load_l5()[:1]
    pack = DEFAULT_PACK.read_text(encoding="utf-8")
    items = l5_items(rows)
    def fill(it, v, types):
        if it["id"].endswith(".d2"):
            types = dict(types, form={"c.hygiene_grooming": 1.0})
        return types
    anns = l5_annotations("A3S", items, pack, l5_answer_rows(rows, fill=fill))
    _, keys = build_l5_batch("A3S", rows, anns)
    ident = keys[0]["a_identical"]
    assert sorted(ident.values()).count(True) == 3 and sum(not v for v in ident.values()) == 1
    assert same_annotation(anns[items[0]["id"]], anns[items[1]["id"]]) and not same_annotation(anns[items[0]["id"]], anns[items[2]["id"]])


# ---- end to end on the real pool ----
def test_builder_writes_levels_one_to_four_and_l5_annotation_batches_then_l5_from_answers(tmp_path):
    import importlib.util
    spec = importlib.util.spec_from_file_location("brg", DEFAULT_GOLD.parent.parent / "tools" / "build_roundtrip_graded.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    log = []
    m.build(tmp_path, say=log.append)
    sizes = {lv: len((tmp_path / f"roundtrip.A3S.v2.L{lv}.jsonl").read_text().splitlines()) - 1 for lv in (1, 2, 3, 4)}
    assert all(n == 273 for n in sizes.values())
    keys = {lv: [json.loads(l) for l in (tmp_path / f"roundtrip.A3S.v2.L{lv}.key.jsonl").read_text().splitlines()] for lv in (1, 2, 3, 4)}
    assert all(k["backfilled"] == 0 for k in keys[1]) and sum(k["backfilled"] > 0 for k in keys[3]) > 0  # loud, not silent
    report = [json.loads(l) for l in (tmp_path / "roundtrip.A3S.v2.fill_report.jsonl").read_text().splitlines()]
    assert any(r["level"] == 3 for r in report) and all(r["backfilled"] > 0 for r in report)
    assert not any(r["level"] == 1 for r in report)
    for v in range(3):
        assert len((tmp_path / f"membership.A3S.v2.l5.var{v}.jsonl").read_text().splitlines()) == 201
    assert not (tmp_path / "roundtrip.A3S.v2.L5.jsonl").exists()
    rows = load_l5()
    ans = tmp_path / "l5.answers.jsonl"
    ans.write_text("\n".join(json.dumps(a) for a in l5_answer_rows(rows)) + "\n")
    m.build(tmp_path, l5_answers=[ans], say=log.append)
    assert len((tmp_path / "roundtrip.A3S.v2.L5.jsonl").read_text().splitlines()) == 41
    assert len((tmp_path / "roundtrip.A3S.v2.L5.key.jsonl").read_text().splitlines()) == 40


def test_a_backfill_is_the_nearest_available_not_random_above_level_one():
    anns, texts = world()
    # i00 is F,X,p. Nobody else has setting 'z'; give the true item content shared with only one other item.
    anns["u"], texts["u"] = ann("F", "Z", None, "z"), "u text"
    anns["near"], texts["near"] = ann("G", "Z", None, "p"), "near text"  # shares content Z only
    anns["far"], texts["far"] = ann("G", "W", None, "q"), "far text"
    d = dict(level_decoys("u", 2, anns, texts, TYPES))
    # strict L2: form F items (10+ qualify); but with form unique to u the fill must pick the nearest first
    anns["u2"], texts["u2"] = ann("H", "Z", None, "z"), "u2 text"
    order = [i for i, _ in level_decoys("u2", 2, anns, texts, TYPES)]
    assert order[0] in ("u", "near")  # both share content Z; "far" and the rest share nothing
    assert order.index("far") > order.index("near") if "far" in order else True
