import importlib.util
import json
from pathlib import Path

import pytest

from lifeimage.axes import build_axes_batches, extreme_share, parse_scores, write_axes_batches
from lifeimage.validate import validate_answers

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
    (d / "axes.v2.md").write_text("# Task: axes\nv2 text.\n")
    return d


def cards():
    return [make_card("s.a", label="Sector A", description="da", links=[]),
            make_card("s.b", label="Sector B", description="db", links=[]),
            make_card("c.x", label="Ex", description="dx", links=[link("s.a")], axes=None),
            make_card("c.y", label="Why", description="dy", links=[link("s.b", weight=0.6), link("s.a", weight=0.4)], axes=None),
            make_card("c.z", label="Zed", description="dz", links=[link("c.x")], axes=None)]


def test_batches_cover_fields_only_with_sector_labels_in_the_card_and_the_prompt_as_prefix(prompts):
    b = build_axes_batches(cards(), model="haiku-runner", prompt_version=2, prompts_dir=prompts)
    assert sorted(b) == [0, 1, 2]
    h = json.loads(b[0][0])
    assert h["prefix"] == "# Task: axes\nv2 text.\n" and h["task_type"] == "axes" and h["prompt_version"] == 2
    t = [json.loads(l) for l in b[0][1:]]
    assert [x["input"]["card"]["id"] for x in t] == ["c.x", "c.y", "c.z"]
    assert t[1]["input"]["card"]["sectors"] == ["Sector B", "Sector A"]  # heaviest first
    assert t[2]["input"]["card"]["sectors"] == []  # a field under a field names no sector
    assert t[0]["input"]["candidates"] == [] and len(t[0]["allowed_verdicts"]) == 25 and "+2,-2" in t[0]["allowed_verdicts"]


def test_variants_share_the_input_hash_and_differ_in_task_id_and_files_are_named_v2(prompts, tmp_path):
    b = build_axes_batches(cards(), model="haiku-runner", prompt_version=2, prompts_dir=prompts)
    first = [json.loads(b[v][1]) for v in range(3)]
    assert len({t["input_hash"] for t in first}) == 1 and len({t["task_id"] for t in first}) == 3
    paths = write_axes_batches(b, tmp_path, prompt_version=2)
    assert [p.name for p in paths] == [f"axes.v2.var{v}.jsonl" for v in range(3)]


def test_a_well_formed_answer_validates_against_the_batch(prompts):
    b = build_axes_batches(cards(), model="haiku-runner", prompt_version=2, prompts_dir=prompts)
    t = json.loads(b[0][1])
    a = {"task_id": t["task_id"], "task_type": "axes", "input_hash": t["input_hash"], "variant": 0, "model": "haiku-runner",
         "prompt_version": 2, "verdict": "+1,0", "reason": "r"}
    rest = [json.dumps({**a, "task_id": x["task_id"], "input_hash": x["input_hash"]}) for x in map(json.loads, b[0][1:])]
    assert validate_answers(b[0], rest) == []


def test_real_v1_batches_are_reproduced_from_seed_v0_so_the_builder_matches_what_was_run():
    v1 = ROOT / "data/batches/axes.v1.var0.jsonl"
    if not v1.exists():
        pytest.skip("batches are gitignored")
    seed = [json.loads(l) for l in (ROOT / "data/coarse/seed_v0.jsonl").read_text(encoding="utf-8").splitlines()]
    b = build_axes_batches(seed, model="haiku-subagent-low", prompt_version=1)
    assert b[0][1:] == v1.read_text(encoding="utf-8").splitlines()[1:]
    assert b[0][0] == v1.read_text(encoding="utf-8").splitlines()[0]


def test_parse_scores_and_extreme_share_count_pm2_over_both_axes():
    assert parse_scores("+2,-1") == (2, -1) and parse_scores("0,0") == (0, 0)
    with pytest.raises(ValueError):
        parse_scores("3,0")
    ans = [{"verdict": "+2,-2"}, {"verdict": "+1,0"}, {"verdict": "0,+2"}, {"verdict": "-1,-1"}]
    s = extreme_share(ans)
    assert s["scores"] == 8 and s["extreme"] == 3 and s["share"] == pytest.approx(3 / 8)
    assert s["axis1"] == pytest.approx(1 / 4) and s["axis2"] == pytest.approx(2 / 4)
    assert s["both_extreme_items"] == pytest.approx(1 / 4)


def test_compare_script_shows_v1_against_v2_on_the_same_files(tmp_path):
    tool = load_tool("axes_compare")
    v1 = tmp_path / "v1.jsonl"
    v2 = tmp_path / "v2.jsonl"
    v1.write_text("".join(json.dumps({"verdict": v}) + "\n" for v in ["+2,-2", "+2,+2", "-2,0", "+1,0"]))
    v2.write_text("".join(json.dumps({"verdict": v}) + "\n" for v in ["+2,-1", "+1,+1", "-1,0", "+1,0"]))
    s = tool.compare([v1], [v2])
    assert s["v1"]["share"] == pytest.approx(5 / 8) and s["v2"]["share"] == pytest.approx(1 / 8)
    assert s["drop"] == pytest.approx(4 / 8)
    assert "v1" in tool.report(s) and "v2" in tool.report(s)


def test_real_v1_answers_are_extreme_heavy_the_motive_for_v2():
    files = sorted((ROOT / "data/batches").glob("axes.v1.var*.answers.jsonl"))
    if not files:
        pytest.skip("answers are gitignored")
    ans = [json.loads(l) for f in files for l in f.read_text().splitlines() if l.strip()]
    assert extreme_share(ans)["share"] > 0.3
