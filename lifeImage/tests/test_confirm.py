"""Confirming battery: item set, combined task `confirm.v1` (A, B and D per item), batches and answer validation.

Red first on the outcome: each test is built so a naive stub (an item set without participants or strata, a
prompt that keeps the old production wording, batches whose variants are identical, a validator that accepts
everything) returns the wrong result rather than a missing-function error."""
import importlib.util
import json
from pathlib import Path

import pytest

from lifeimage.canonical import content_hash
from lifeimage.confirm import (DEFAULT_ITEMS, MAX_BATCH_TOKENS, MODEL, PROMPT_VERSION, TASK_TYPE, build_confirm_batches,
                               item_input, load_confirm_items, prefix_text, validate_confirm_answers,
                               write_confirm_batches)
from lifeimage.membership import DEFAULT_PACK, load_items_v2, pack_hash, pack_lines

ROOT = Path(__file__).resolve().parent.parent
PACK = DEFAULT_PACK.read_text(encoding="utf-8")
PRODUCTION_DEFINITION = ("produced = the participant's act yields an output others can use or assess (a review, a "
                         "meal for others, a repaired roof); consumed = they take in or use up an output without "
                         "yielding one; both; null if no record")


@pytest.fixture(scope="module")
def items():
    return load_confirm_items()


def by_source(items, source):
    return [i for i in items if i["source"] == source]


# ---- the item set ----
def test_item_set_has_about_120_items_in_four_sources(items):
    assert 110 <= len(items) <= 130
    counts = {s: len(by_source(items, s)) for s in ("a_pool", "bd", "counterfactual", "production_pair")}
    assert counts["a_pool"] >= 30 and counts["bd"] >= 20
    assert counts["counterfactual"] >= 28
    assert counts["production_pair"] == 30
    assert sum(counts.values()) == len(items)


def test_every_item_lists_participants_even_the_ones_from_the_participant_free_a_pool(items):
    for i in items:
        ps = i["participants"]
        assert ps and len({p["id"] for p in ps}) == len(ps), i["id"]
        assert all(p["id"].strip() and p["label"].strip() for p in ps), i["id"]


def test_ids_and_texts_are_unique(items):
    assert len({i["id"] for i in items}) == len(items)
    assert len({i["text"].strip().lower() for i in items}) == len(items)


def test_existing_items_are_drawn_from_the_273_and_81_sets_unchanged(items):
    pool = {i["id"]: i["text"] for i in load_items_v2()}
    bd = {json.loads(l)["id"]: json.loads(l) for l in (ROOT / "data/gold/bd_items_v0.jsonl").read_text().splitlines()}
    for i in by_source(items, "a_pool"):
        assert pool[i["id"]] == i["text"]
    for i in by_source(items, "bd"):
        assert bd[i["id"]]["text"] == i["text"]
        assert bd[i["id"]]["participants"] == i["participants"]


def test_a_pool_sample_is_stratified_over_events_red_team_and_whole_pairs(items):
    a = by_source(items, "a_pool")
    kinds = {k: [i for i in a if i["id"].startswith(k + ".")] for k in ("ev", "rt", "mp")}
    assert all(len(v) >= 6 for v in kinds.values())
    cov = {json.loads(l)["id"]: json.loads(l) for l in (ROOT / "data/gold/coverage_events_v0.jsonl").read_text().splitlines()}
    fields = {(cov[i["id"]]["expected_fields"] or [""])[0] for i in kinds["ev"]}
    assert len(fields) >= 15, "coverage events must spread over many domains, not cluster"
    mp = {i["id"] for i in kinds["mp"]}
    pairs = {i["id"].rsplit(".", 1)[0] for i in kinds["mp"]}
    assert len(pairs) >= 4 and all(f"{p}.a" in mp and f"{p}.b" in mp for p in pairs)


def test_bd_sample_keeps_overdetermination_and_every_b_and_d_pair_whole(items):
    bd = by_source(items, "bd")
    assert sum("expect" in i for i in bd) >= 5, "overdetermination items carry the conservation check"
    ids = {i["id"] for i in bd}
    pairs = {i["pair"] for i in bd if "pair" in i}
    assert len(pairs) >= 6
    assert all(f"bd.mp.{p}.a" in ids and f"bd.mp.{p}.b" in ids for p in pairs)


def test_counterfactual_items_state_or_imply_what_would_otherwise_have_happened(items):
    cf = by_source(items, "counterfactual")
    for i in cf:
        assert i["counterfactual"] in ("stated", "implied"), i["id"]
        assert i["expected_outcome"] in ("change", "null"), i["id"]
        assert len(i["text"].split()) >= 12, i["id"]
    assert sum(i["expected_outcome"] == "change" for i in cf) >= 15
    assert sum(i["expected_outcome"] == "null" for i in cf) >= 6, "failed rescues and no-difference cases"
    stated = [i for i in cf if i["counterfactual"] == "stated"]
    import re
    marker = re.compile(r"\b(would|whereas|unlike|without|otherwise|had not|did not|never|instead|while the|but the)\b", re.I)
    assert len(stated) >= 12 and all(marker.search(i["text"]) for i in stated)
    topics = " ".join(i["text"].lower() for i in cf)
    for word in ("vaccinat", "storm", "surg", "rescue"):
        assert word in topics


def test_production_pairs_contrast_consumed_with_produced_on_one_focal_participant(items):
    cp = by_source(items, "production_pair")
    pairs = {}
    for i in cp:
        pairs.setdefault(i["pair"], {})[i["side"]] = i
    assert len(pairs) == 15 and all(set(v) == {"a", "b"} for v in pairs.values())
    for name, v in pairs.items():
        a, b = v["a"], v["b"]
        (fa, ea), = a["expect_production"].items()
        (fb, eb), = b["expect_production"].items()
        assert (ea, eb) == ("consumed", "produced"), name
        assert fa in {p["id"] for p in a["participants"]} and fb in {p["id"] for p in b["participants"]}
        assert a["text"] != b["text"]
    joined = " ".join(i["text"].lower() for i in cp)
    for word in ("watch", "review", "read", "annotat", "eat", "cook"):
        assert word in joined


def test_item_builder_reproduces_the_gold_file():
    spec = importlib.util.spec_from_file_location("build_confirm_items", ROOT / "tools/build_confirm_items.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    want = "\n".join(json.dumps(r, sort_keys=True, ensure_ascii=False) for r in mod.build()) + "\n"
    assert DEFAULT_ITEMS.read_text(encoding="utf-8") == want


def test_loader_rejects_malformed_items(tmp_path):
    good = {"id": "x.1", "text": "A man waters a plant", "source": "a_pool", "participants": [{"id": "man", "label": "the man"}]}
    for bad in (dict(good, participants=[]), dict(good, source="elsewhere"),
                dict(good, participants=[{"id": "m", "label": "a"}, {"id": "m", "label": "b"}]),
                dict(good, source="counterfactual"), dict(good, source="production_pair")):
        p = tmp_path / "items.jsonl"
        p.write_text(json.dumps(bad) + "\n")
        with pytest.raises(ValueError):
            load_confirm_items(p)
    p = tmp_path / "dup.jsonl"
    p.write_text(json.dumps(good) + "\n" + json.dumps(good) + "\n")
    with pytest.raises(ValueError):
        load_confirm_items(p)


# ---- the prompt ----
def test_prompt_sharpens_production_and_gates_the_counterfactual():
    text = (ROOT / "prompts/confirm.v1.md").read_text(encoding="utf-8")
    flat = " ".join(text.split())
    assert PRODUCTION_DEFINITION in flat
    assert "use the counterfactual only when the text states or implies it, else null" in flat.lower()
    for field in ("contribution", "responsibility", "impact", "production", "acting_for", "under_agreement",
                  "informed", "volition", "subevents", "event_links", "flavour", "{{link_types}}"):
        assert field in text, field
    assert "contributed to an output" not in text, "the old, weak production wording must be gone"


def test_prefix_carries_the_vocabulary_the_pack_and_the_variants_link_order():
    p0, p1 = prefix_text(0, PACK), prefix_text(1, PACK)
    assert "{{link_types}}" not in p0
    for t in ("form:", "content:", "outcome:", "setting:", "flavour:"):
        assert t in p0
    assert p0 != p1, "pack and link-type order differ by variant"
    assert p0.index("part_of") != p1.index("part_of") or p0.index("causes") != p1.index("causes")
    assert pack_lines(PACK)[1][0].split(" | ")[0] in p0


# ---- batches ----
def test_batches_cover_every_item_per_variant_with_a_variant_invariant_hash(items):
    bs = build_confirm_batches(items, PACK)
    assert sorted(bs) == [0, 1, 2]
    hashes = {}
    for v, parts in bs.items():
        tasks = [json.loads(l) for part in parts for l in part[1:]]
        assert sorted(t["input"]["item"]["id"] for t in tasks) == sorted(i["id"] for i in items)
        for t in tasks:
            assert t["task_type"] == TASK_TYPE and t["prompt_version"] == PROMPT_VERSION
            assert t["allowed_verdicts"] == ["confirm"] and t["variant"] == v
            assert t["input"]["item"]["participants"], t["input"]["item"]["id"]
            hashes.setdefault(t["input"]["item"]["id"], set()).add(t["input_hash"])
    assert all(len(h) == 1 for h in hashes.values())


def test_variants_reorder_participants_and_the_header_prefix(items):
    bs = build_confirm_batches(items, PACK)
    order = {v: {json.loads(l)["input"]["item"]["id"]: [p["id"] for p in json.loads(l)["input"]["item"]["participants"]]
                 for part in parts for l in part[1:]} for v, parts in bs.items()}
    many = [i["id"] for i in items if len(i["participants"]) >= 3]
    assert any(order[0][i] != order[1][i] for i in many)
    assert len({json.loads(bs[v][0][0])["prefix"] for v in bs}) == 3


def test_input_hash_depends_on_the_pack_and_the_text(items):
    a = item_input(items[0], 0, pack_hash(PACK))
    assert content_hash(a) != content_hash(item_input(items[0], 0, "other"))
    assert content_hash(a) != content_hash(item_input(dict(items[0], text=items[0]["text"] + "!"), 0, pack_hash(PACK)))


def test_batches_split_by_token_size_and_each_part_keeps_the_header(items):
    assert MAX_BATCH_TOKENS == 40_000
    whole = build_confirm_batches(items, PACK)
    assert all(len(parts) == 1 for parts in whole.values()), "120 items fit one batch per variant"
    small = build_confirm_batches(items, PACK, max_tokens=12_000)
    for v, parts in small.items():
        assert len(parts) >= 2
        for part in parts:
            assert json.loads(part[0])["kind"] == "header" and len(part) > 1
            assert sum(len(l.encode()) + 1 for l in part) // 4 <= 12_000
        assert sum(len(p) - 1 for p in parts) == len(items)


def test_written_batch_files_are_named_for_variant_and_part(items, tmp_path):
    paths = write_confirm_batches(build_confirm_batches(items, PACK), tmp_path)
    assert [p.name for p in paths] == ["confirm.v1.var0.jsonl", "confirm.v1.var1.jsonl", "confirm.v1.var2.jsonl"]
    paths = write_confirm_batches(build_confirm_batches(items, PACK, max_tokens=12_000), tmp_path / "s")
    assert all(p.name.startswith("confirm.v1.var") and ".p" in p.name for p in paths)
    assert {p.name.split(".")[2] for p in paths} == {"var0", "var1", "var2"}
    assert max(len(p.read_bytes()) // 4 for p in paths) <= 12_000


# ---- answer validation ----
def tiny_batch(items):
    two = [i for i in items if len(i["participants"]) == 2][:1]
    parts = build_confirm_batches(two, PACK, k=1)[0]
    return two[0], parts[0]


def good_answer(item, task):
    ids = {l.split(" | ")[0] for l in pack_lines(PACK)[2]}
    dom = sorted(ids)[0]
    ps = item["participants"]
    return {"task_id": task["task_id"], "task_type": TASK_TYPE, "input_hash": task["input_hash"], "variant": 0,
            "model": MODEL, "prompt_version": 1, "verdict": "confirm", "reason": "r",
            "types": {"form": {dom: 1.0}, "content": {dom: 0.5, sorted(ids)[1]: 0.5}, "outcome": None, "setting": None,
                      "flavour": None},
            "other": None,
            "participants": [{"id": p["id"], "contribution": 0.5 if n == 0 else 0.0, "responsibility": 0.5,
                              "impact": [], "acting_for": None, "under_agreement": None, "informed": None,
                              "volition": "free", "volition_record": "chose", "production": "produced"}
                             for n, p in enumerate(ps)],
            "subevents": [{"id": "e1", "label": "the act"}, {"id": "e2", "label": "the result"}],
            "event_links": [{"from": "e1", "to": "e2", "type": "causes", "confidence": 0.7}]}


def check(item, batch, mutate=None):
    task = json.loads(batch[1])
    a = good_answer(item, task)
    if mutate:
        mutate(a)
    return validate_confirm_answers(batch, [json.dumps(a)])


def test_a_complete_answer_validates(items):
    item, batch = tiny_batch(items)
    assert check(item, batch) == []


@pytest.mark.parametrize("name,mutate", [
    ("contributions above one", lambda a: [p.update(contribution=0.9) for p in a["participants"]]),
    ("a participant missing", lambda a: a["participants"].pop()),
    ("an unlisted participant", lambda a: a["participants"].append(dict(a["participants"][0], id="ghost"))),
    ("a made-up production value", lambda a: a["participants"][0].update(production="made")),
    ("constrained volition without its record", lambda a: a["participants"][0].update(volition="constrained", volition_record=None)),
    ("an A type missing", lambda a: a["types"].pop("setting")),
    ("an A weight map that does not sum to one", lambda a: a["types"].update(form={sorted(a["types"]["content"])[0]: 0.4})),
    ("a domain id outside the pack", lambda a: a["types"].update(form={"c.nonexistent_domain": 1.0})),
    ("a link to an unknown sub-event", lambda a: a["event_links"][0].update(to="e9")),
    ("a link type outside the four", lambda a: a["event_links"][0].update(type="inspires")),
    ("confidence 1", lambda a: a["event_links"][0].update(confidence=1.0)),
    ("no sub-events", lambda a: a.update(subevents=[], event_links=[])),
    ("the wrong verdict", lambda a: a.update(verdict="participation")),
    ("a missing D part", lambda a: a.pop("event_links")),
    ("a missing B part", lambda a: a.pop("participants")),
    ("a missing A part", lambda a: a.pop("types")),
])
def test_a_malformed_answer_is_rejected(items, name, mutate):
    item, batch = tiny_batch(items)
    assert check(item, batch, mutate), f"accepted: {name}"


def test_a_missing_answer_and_a_duplicate_are_reported(items):
    item, batch = tiny_batch(items)
    assert any("missing answer" in e for e in validate_confirm_answers(batch, []))
    a = json.dumps(good_answer(item, json.loads(batch[1])))
    assert any("duplicate" in e for e in validate_confirm_answers(batch, [a, a]))
