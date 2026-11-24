import importlib.util
import json
from pathlib import Path

import pytest

from lifeimage.cache import AnswerCache
from lifeimage.comembership import link_agreement
from lifeimage.links import build_links_batches
from lifeimage.packs import coarse_pack, is_sector, pack_ids, ungrouped_pack

from conftest import link, make_card

ROOT = Path(__file__).resolve().parent.parent


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def prompts(tmp_path):
    d = tmp_path / "prompts"
    d.mkdir()
    (d / "links.v2.md").write_text("# Task: links\nAnswer v2.\n")
    return d


def cards(n=12, sector_of=lambda i: "s.a" if i % 2 else "s.b"):
    out = [make_card(f"s.{c}", label=f"Sector {c}", description=f"d {c}", links=[]) for c in "ab"]
    out += [make_card(f"c.f{i:02d}", label=f"Field {i}", description=f"desc {i}", links=[link(sector_of(i))], axes=None)
            for i in range(n)]
    return out


def ids_of(pack):
    return [l.split(" | ")[0] for l in pack.splitlines()[1:]]


# ---- ungrouped pack
def test_ungrouped_pack_lists_sectors_then_fields_by_id_whatever_the_guessed_links():
    other = cards(sector_of=lambda i: "s.b" if i < 6 else "s.a")
    a, b = ungrouped_pack(cards()), ungrouped_pack(other)
    assert a == b  # guessed links never reach the pack
    assert ids_of(a) == ["s.a", "s.b"] + [f"c.f{i:02d}" for i in range(12)]
    assert ids_of(coarse_pack(cards())) != ids_of(a)  # the grouped pack puts s.a's children before s.b's


def test_variants_shuffle_the_fields_only_deterministically():
    packs = [ungrouped_pack(cards(30), v) for v in range(3)]
    assert len({tuple(ids_of(p)) for p in packs}) == 3
    assert all(ids_of(p)[:2] == ["s.a", "s.b"] for p in packs)
    assert all(sorted(ids_of(p)[2:]) == sorted(ids_of(packs[0])[2:]) for p in packs)
    assert packs[1] == ungrouped_pack(cards(30), 1)
    assert all(pack_ids(p) == {c["id"] for c in cards(30)} for p in packs)


# ---- batches
def test_v2_batches_are_ungrouped_named_v2_and_tasks_carry_no_links(prompts):
    cs = cards(30)
    b = build_links_batches(cs, model="haiku-runner", prompt_version=2, prompts_dir=prompts, ungrouped=True)
    assert sorted(b) == [0, 1, 2]
    for v in range(3):
        h = json.loads(b[v][0])
        assert h["model"] == "haiku-runner" and h["prompt_version"] == 2
        assert h["prefix"] == "# Task: links\nAnswer v2.\n\n" + ungrouped_pack(cs, v)
        t = json.loads(b[v][1])
        assert set(t["input"]["card"]) == {"id", "label", "description"} and t["prompt_version"] == 2
        assert len(b[v]) - 1 == 30
    grouped = build_links_batches(cs, model="haiku-runner", prompt_version=2, prompts_dir=prompts)
    assert json.loads(grouped[0][1])["input_hash"] != json.loads(b[0][1])["input_hash"]  # the pack hash differs


def test_real_prompt_and_seed_give_247_field_tasks_with_an_ungrouped_pack_asking_for_field_upstream():
    prompt = (ROOT / "prompts" / "links.v2.md").read_text(encoding="utf-8")
    assert "upstream" in prompt and "another field" in prompt and "overlap" in prompt and "sector" in prompt
    seed = [json.loads(l) for l in (ROOT / "data/coarse/seed_v0.jsonl").read_text(encoding="utf-8").splitlines()]
    b = build_links_batches(seed, model="haiku-runner", prompt_version=2, ungrouped=True)
    body = ids_of(json.loads(b[0][0])["prefix"].split("# coarse pack", 1)[1].join(["#", ""]))
    sectors = [i for i in body if i.startswith("s.")]
    assert body[:len(sectors)] == sectors and all(not i.startswith("s.") for i in body[len(sectors):])
    assert len(b[0]) - 1 == 247 and len(body) == 263
    fields = body[len(sectors):]
    assert fields == sorted(fields)  # variant 0: all fields by id, not in sector groups


# ---- agreement with the data-learnt co-membership
def row(a, b, p, support, ti="content", tj="content"):
    return {"a": a, "type_i": ti, "b": b, "type_j": tj, "p": p, "support": support, "version": "0"}


def test_link_agreement_counts_direction_for_upstream_and_symmetry_for_overlap_on_testable_pairs_only():
    cs = [make_card("c.child", links=[link("c.parent", weight=0.6), link("c.wrong", weight=0.4),
                                      link("c.sib", rel="overlap", weight=1), link("c.thin", weight=1.0, rel="overlap")]),
          make_card("c.other", links=[link("c.child2", rel="overlap", weight=1)])]
    rows = [row("c.child", "c.parent", 0.9, 5), row("c.parent", "c.child", 0.2, 5),      # child included in parent
            row("c.child", "c.wrong", 0.1, 4), row("c.wrong", "c.child", 0.8, 4),        # reversed: wrong way round
            row("c.child", "c.sib", 0.4, 6), row("c.sib", "c.child", 0.45, 6),           # symmetric overlap
            row("c.child", "c.thin", 0.9, 2), row("c.thin", "c.child", 0.9, 2)]          # support below the floor
    s = link_agreement(cs, rows, min_support=3)
    assert (s["upstream_testable"], s["upstream_agree"]) == (2, 1)
    assert (s["overlap_testable"], s["overlap_agree"]) == (1, 1)
    assert s["upstream_rate"] == pytest.approx(0.5) and s["overlap_rate"] == pytest.approx(1.0)


def test_link_agreement_counterexample_a_directed_pair_does_not_agree_as_overlap():
    cs = [make_card("c.a", links=[link("c.b", rel="overlap", weight=1)])]
    rows = [row("c.a", "c.b", 0.95, 9), row("c.b", "c.a", 0.1, 9)]
    s = link_agreement(cs, rows, min_support=3)
    assert s["overlap_testable"] == 1 and s["overlap_agree"] == 0


# ---- apply script
def answer(task, upstream, overlap, model="haiku-runner"):
    return {"task_id": task["task_id"], "task_type": "links", "input_hash": task["input_hash"], "variant": task["variant"],
            "model": model, "prompt_version": 2, "verdict": "links", "upstream": upstream, "overlap": overlap, "reason": "r"}


def test_apply_links_v2_writes_field_to_field_upstream_and_compares_with_seed_and_data(prompts, tmp_path):
    tool = load_tool("apply_links_v2")
    cs = cards(6)
    seed = tmp_path / "seed_v0.jsonl"
    seed.write_text("".join(json.dumps(c) + "\n" for c in cs))
    b = build_links_batches(cs, model="haiku-runner", prompt_version=2, prompts_dir=prompts, ungrouped=True)
    paths = []
    for v in range(3):
        lines = []
        for t in map(json.loads, b[v][1:]):
            fid = t["input"]["card"]["id"]
            up = {"c.f00": 1.0} if fid != "c.f00" else {"s.a": 1.0}  # every other field sits under c.f00; c.f00 under s.a
            lines.append(json.dumps(answer(t, up, ["c.f01"] if fid not in ("c.f01", "c.f00") else [])))
        p = tmp_path / f"var{v}.answers.jsonl"
        p.write_text("\n".join(lines) + "\n")
        paths.append(str(p))
        (tmp_path / f"var{v}.jsonl").write_text("\n".join(b[v]) + "\n")
    comem = tmp_path / "comembership.jsonl"
    comem.write_text("".join(json.dumps(r) + "\n" for r in [row("c.f03", "c.f00", 0.9, 5), row("c.f00", "c.f03", 0.2, 5)]))
    out = tmp_path / "seed_v2.jsonl"
    s = tool.apply(seed, paths, out, AnswerCache(tmp_path / "cache"), tmp_path / "esc.jsonl", comembership=comem,
                   prompts_dir=prompts)
    new = {c["id"]: c for c in map(json.loads, out.read_text().splitlines())}
    assert [l["id"] for l in new["c.f03"]["links"] if l["rel"] == "upstream"] == ["c.f00"]
    assert s["fields_with_field_upstream"] == 5 / 6  # five of the six fields name a field, one a sector
    assert s["v0_upstream_retained"] == 0.0  # v0 guessed sectors for all six; none of those links was repeated
    assert s["data"]["upstream_testable"] == 1 and s["data"]["upstream_agree"] == 1
