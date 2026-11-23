import importlib.util
import json
from pathlib import Path

import pytest

from lifeimage.cache import AnswerCache
from lifeimage.links import build_links_batches
from lifeimage.packs import coarse_pack, pack_ids
from lifeimage.validate import validate_answers

from conftest import link, make_card

spec = importlib.util.spec_from_file_location("apply_links", Path(__file__).resolve().parent.parent / "tools" / "apply_links.py")
apply_links = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply_links)


@pytest.fixture
def prompts(tmp_path):
    d = tmp_path / "prompts"
    d.mkdir()
    (d / "links.v1.md").write_text("# Task: links\nAnswer.\n")
    return d


def cards(n=12):
    out = [make_card(f"s.{c}", label=f"Sector {c}", description=f"d {c}") for c in "ab"]
    for i in range(n):
        out.append(make_card(f"c.f{i:02d}", label=f"Field {i}", description=f"desc {i}",
                             links=[link("s.a", weight=1.0)], axes=None))
    return out


def build(cs, prompts, cache=None):
    return build_links_batches(cs, cache=cache, model="m", prompt_version=1, prompts_dir=prompts)


def test_one_batch_per_variant_prefix_is_instructions_then_that_variants_pack(prompts):
    b = build(cards(30), prompts)
    assert sorted(b) == [0, 1, 2]
    prefixes = [json.loads(b[v][0])["prefix"] for v in range(3)]
    assert len(set(prefixes)) == 3 and all(p.startswith("# Task: links\nAnswer.\n\n# coarse pack") for p in prefixes)
    assert prefixes[1].endswith(coarse_pack(cards(30), 1))
    assert prefixes == [json.loads(build(cards(30), prompts)[v][0])["prefix"] for v in range(3)]  # stable across reruns
    assert all(pack_ids(p) == {c["id"] for c in cards(30)} for p in prefixes)


def test_tasks_carry_only_id_label_description_so_guessed_links_cannot_anchor(prompts):
    b = build(cards(), prompts)
    t = json.loads(b[0][1])
    assert set(t["input"]["card"]) == {"id", "label", "description"} and "links" not in json.dumps(t["input"])
    assert t["allowed_verdicts"] == ["links"] and len(b[0]) - 1 == 12  # fields only, no sectors
    other = [dict(c, links=[link("s.b")]) if c["id"].startswith("c.") else c for c in cards()]
    assert [json.loads(l)["input_hash"] for l in b[0][1:]] == [json.loads(l)["input_hash"] for l in build(other, prompts)[0][1:]]


def test_same_field_has_the_same_input_hash_in_every_variant_and_cache_skips_answered(prompts, tmp_path):
    b = build(cards(), prompts)
    h = lambda v: [json.loads(l)["input_hash"] for l in b[v][1:]]
    assert h(0) == h(1) == h(2)
    cache = AnswerCache(tmp_path / "a")
    t = json.loads(b[1][1])
    cache.put_all([{"task_id": t["task_id"], "task_type": "links", "input_hash": t["input_hash"], "variant": 1, "model": "m",
                    "prompt_version": 1, "verdict": "links", "reason": "r"}])
    assert len(build(cards(), prompts, cache)[1]) - 1 == 11 and len(build(cards(), prompts, cache)[0]) - 1 == 12


def test_a_changed_pack_misses_the_cache(prompts):
    a = json.loads(build(cards(), prompts)[0][1])["input_hash"]
    changed = cards()
    changed[-1] = dict(changed[-1], description="something else")
    assert json.loads(build(changed, prompts)[0][1])["input_hash"] != a


def fake_runner(batch, up_for):
    header, tasks = batch[0], [json.loads(l) for l in batch[1:]]
    out = []
    for t in tasks:
        fid = t["input"]["card"]["id"]
        up, ov = up_for(fid, t["variant"])
        out.append(json.dumps({"task_id": t["task_id"], "task_type": "links", "input_hash": t["input_hash"],
                               "variant": t["variant"], "model": "m", "prompt_version": 1, "verdict": "links",
                               "upstream": up, "overlap": ov, "reason": "r"}))
    return out


def test_apply_merges_replaces_links_sets_provenance_and_reports_retention(prompts, tmp_path, monkeypatch):
    cs = cards(6)
    seed = tmp_path / "seed.jsonl"
    seed.write_text("".join(json.dumps(c) + "\n" for c in cs))
    # the runner always says s.b (v0 guessed s.a), except field 00 where variants agree on s.a and one adds s.b
    def up_for(fid, v):
        if fid == "c.f00":
            return ({"s.a": 1.0} if v < 2 else {"s.b": 1.0}), ["c.f01"] if v < 2 else []
        return {"s.b": 1.0}, []
    monkeypatch.setattr(apply_links, "build_links_batches", lambda c, **kw: build_links_batches(c, prompts_dir=prompts, **kw))
    monkeypatch.setattr(apply_links, "MODEL", "m")
    batches = build_links_batches(cs, model="m", prompt_version=1, prompts_dir=prompts)
    files = []
    for v in range(3):
        p = tmp_path / f"a{v}.jsonl"
        p.write_text("\n".join(fake_runner(batches[v], up_for)) + "\n")
        assert validate_answers(batches[v], p.read_text().splitlines()) == []
        files.append(p)
    out = tmp_path / "seed_v1.jsonl"
    cache = AnswerCache(tmp_path / "cache")
    s = apply_links.apply(seed, files, out, cache, tmp_path / "esc.jsonl", model="m")
    rows = {r["id"]: json.loads(l) for l in out.read_text().splitlines() for r in [json.loads(l)]}
    assert rows["c.f00"]["links"][0] == {"id": "s.a", "rel": "upstream", "weight": 1.0}
    assert [l["id"] for l in rows["c.f00"]["links"] if l["rel"] == "overlap"] == ["c.f01"]
    assert [l["id"] for l in rows["c.f01"]["links"]] == ["s.b"]
    prov = rows["c.f00"]["provenance"]["links"]
    assert prov["source"] == "haiku-subagent-low x3, links.v1" and 0 < prov["confidence"] < 1
    assert rows["c.f01"]["provenance"]["links"]["confidence"] > prov["confidence"]  # unanimous beats split
    assert rows["s.a"] == cs[0]  # sectors untouched
    assert s["v0_upstream_retained"] == pytest.approx(1 / 6) and s["escalated"] == 0
    assert s["upstream_all_agree"] == pytest.approx(5 / 6)
    assert len(cache.get("links", batches[0][1] and json.loads(batches[0][1])["input_hash"], "m", 1)) == 3


def test_apply_refuses_an_invalid_answers_file(prompts, tmp_path, monkeypatch):
    cs = cards(3)
    seed = tmp_path / "seed.jsonl"
    seed.write_text("".join(json.dumps(c) + "\n" for c in cs))
    monkeypatch.setattr(apply_links, "build_links_batches", lambda c, **kw: build_links_batches(c, prompts_dir=prompts, **kw))
    batches = build_links_batches(cs, model="m", prompt_version=1, prompts_dir=prompts)
    files = []
    for v in range(3):
        p = tmp_path / f"a{v}.jsonl"
        p.write_text("\n".join(fake_runner(batches[v], lambda f, v: ({"s.nope": 1.0}, []))) + "\n")
        files.append(p)
    with pytest.raises(SystemExit):
        apply_links.apply(seed, files, tmp_path / "o.jsonl", AnswerCache(tmp_path / "c"), tmp_path / "e", model="m")
    assert not (tmp_path / "o.jsonl").exists()
