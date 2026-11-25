"""tools/fine_apply.py end to end on synthetic answers: cards, summary, escalations, co-membership check."""
import importlib.util
import json
from pathlib import Path

import pytest

from lifeimage.fine.parent import build_fine_batches, write_fine_batches
from lifeimage.fine.compare import parent_pair_agreement
from lifeimage.validate import validate_card

from conftest import link, make_card
from test_fine_parent import answers_for, coarse, pool

ROOT = Path(__file__).resolve().parent.parent


def load_tool():
    spec = importlib.util.spec_from_file_location("fine_apply", ROOT / "tools" / "fine_apply.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def world(tmp_path):
    prompts = tmp_path / "p"
    prompts.mkdir()
    (prompts / "fine_parent.v1.md").write_text("# Task: fine_parent\nno scoring table\n")
    cands = pool(6)
    cs = coarse()
    batches = build_fine_batches(cands, cs, model="haiku-runner", prompts_dir=prompts)
    paths = write_fine_batches(batches, tmp_path / "batches")
    (tmp_path / "cands.jsonl").write_text("".join(json.dumps(c) + "\n" for c in cands))
    (tmp_path / "coarse.jsonl").write_text("".join(json.dumps(c) + "\n" for c in cs))
    return tmp_path, prompts, batches, paths


def plan(i):
    # cand 0-3: field c.f1 (cand 1 also overlaps s.a), cand 4: new field in every variant, cand 5: variants disagree
    return {0: ("upstream", {"c.f1": 1.0}), 1: ("upstream", {"c.f1": 0.6, "c.f2": 0.4}), 2: ("overlap", {"c.f3": 1.0}),
            3: ("upstream", {"c.f1": 1.0}), 4: ("new_field", None)}.get(i)


def write_answers(world, disagree=True):
    tmp, prompts, batches, paths = world
    out = {}
    for (v, part), lines in sorted(batches.items()):
        def make(t, v=v):
            i = int(t["input"]["card"]["id"].split("_")[1])
            p = plan(i)
            if p is None:  # cand 5: three different parents
                return {"verdict": "upstream", "weights": {f"c.f{v}": 1.0}}
            verdict, w = p
            return {"verdict": verdict, **({"weights": w} if w else {"reason": "needs a gambling field"})}
        f = tmp / f"ans.var{v}.part{part}.jsonl"
        f.write_text("\n".join(answers_for(lines, make)) + "\n")
        out.setdefault(v, []).append(f)
    return out


def run(world, answers, **kw):
    tmp, prompts, *_ = world
    tool = load_tool()
    return tool.apply(candidates=tmp / "cands.jsonl", coarse=tmp / "coarse.jsonl", answers=answers, out=tmp / "fine_v0.jsonl",
                      summary=tmp / "summary.json", escalation_log=tmp / "esc.jsonl", cache=None, prompts_dir=prompts,
                      comembership=kw.get("comembership"))


def test_apply_writes_valid_fine_cards_with_majority_parents(world):
    s = run(world, write_answers(world))
    cards = [json.loads(l) for l in (world[0] / "fine_v0.jsonl").read_text().splitlines()]
    assert len(cards) == 6
    by = {c["id"]: c for c in cards}
    for c in cards:
        validate_card(c)
        assert c["level"] == "fine" and c["status"] == "score_only" and c["axes"] is None and c["arc"] is None
        assert c["provenance"]["links"]["confidence"] < 1
    ups = lambda c: {l["id"]: l["weight"] for l in c["links"] if l["rel"] == "upstream"}
    assert ups(by["f.cand_000"]) == {"c.f1": 1.0}
    assert ups(by["f.cand_001"]) == {"c.f1": pytest.approx(0.6), "c.f2": pytest.approx(0.4)}
    assert [l["rel"] for l in by["f.cand_002"]["links"]] == ["overlap"]
    assert by["f.cand_004"]["links"] == []  # new coarse field needed: no parent invented
    assert by["f.cand_000"]["anchors"] == [{"source": "openalex", "code": "0", "label": "Candidate 0"}]


def test_summary_counts_children_per_field_childless_fields_and_new_field_list(world):
    s = run(world, write_answers(world))
    assert s["children_per_coarse"]["c.f1"] == 3 and s["children_per_coarse"]["c.f3"] == 1 and s["children_per_coarse"]["c.f0"] == 1
    assert set(s["fields_without_children"]) == {"c.f2", "c.f4", "c.f5"}
    assert "s.a" not in s["fields_without_children"]  # sectors are not fields
    assert [n["id"] for n in s["new_field_needed"]] == ["f.cand_004"]
    assert s["new_field_needed"][0]["reasons"] == ["needs a gambling field"]
    assert s["escalated"]["count"] == 1 and s["escalated"]["share"] == pytest.approx(1 / 6)
    assert s["candidates"] == 6
    assert json.loads((world[0] / "summary.json").read_text())["candidates"] == 6


def test_escalations_are_logged_loudly(world):
    run(world, write_answers(world))
    log = [json.loads(l) for l in (world[0] / "esc.jsonl").read_text().splitlines()]
    assert {r["id"] for r in log} == {"f.cand_005"}
    assert log[0]["reason"]


def test_stale_or_malformed_answers_fail_loudly(world):
    answers = write_answers(world)
    bad = answers[1][0]
    lines = bad.read_text().splitlines()
    t = json.loads(lines[0])
    t["weights"] = {"c.nope": 1.0}
    bad.write_text("\n".join([json.dumps(t)] + lines[1:]) + "\n")
    with pytest.raises(SystemExit, match="invalid"):
        run(world, answers)


def test_comembership_check_reports_testable_pairs_against_the_baseline():
    cards = [make_card("f.a", level="fine", links=[link("c.x", weight=0.6), link("c.y", weight=0.4)]),
             make_card("f.b", level="fine", links=[link("c.x", weight=0.5), link("c.z", weight=0.5)]),
             make_card("f.c", level="fine", links=[link("c.x")])]
    rows = [{"a": "c.x", "b": "c.y", "p": 0.4, "support": 5, "type_i": "form", "type_j": "form", "version": "0"},
            {"a": "c.y", "b": "c.x", "p": 0.3, "support": 4, "type_i": "form", "type_j": "form", "version": "0"},
            {"a": "c.q", "b": "c.r", "p": 0.2, "support": 3, "type_i": "form", "type_j": "form", "version": "0"}]
    r = parent_pair_agreement(cards, rows, coarse_ids=["c.x", "c.y", "c.z", "c.q", "c.r"], min_support=3)
    assert r["multi_parent_cards"] == 2 and r["pairs"] == 2
    assert r["pairs_with_data"] == 1 and r["rate"] == 0.5
    assert r["baseline_rate"] == pytest.approx(2 / 10)  # (x,y) and (q,r) of the ten coarse pairs
