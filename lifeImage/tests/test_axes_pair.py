import importlib.util
import json
import random
from pathlib import Path

import pytest

from lifeimage.axes import axes_input
from lifeimage.axes_pair import (AXES, axis_means, build_pair_batches, choose_anchors, comparisons_from_answers, design_pairs,
                                 pair_hash, presented, write_pair_batches)
from lifeimage.cache import AnswerCache
from lifeimage.canonical import content_hash
from lifeimage.pairwise import fit_bt, spearman
from lifeimage.validate import validate_answers

from conftest import link, make_card

ROOT = Path(__file__).resolve().parent.parent
N = 60


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def world():
    cards = [make_card("s.one", label="Sector", description="d", links=[], axes=None)]
    cards += [make_card(f"f.{k:03d}", label=f"Field {k}", description=f"Describes field {k} " + "x" * 80,
                        links=[link("s.one")], axes=None) for k in range(N)]
    return cards


def means(cards, seed=0):
    rng = random.Random(seed)
    return {c["id"]: rng.uniform(-2, 2) for c in cards if not c["id"].startswith("s.")}


@pytest.fixture
def prompts(tmp_path):
    d = tmp_path / "prompts"
    d.mkdir()
    (d / "axes_pair.v1.md").write_text("# Task: axes_pair\nprefix text.\n")
    return d


def test_anchors_spread_across_the_means_and_are_distinct():
    m = means(world())
    a = choose_anchors(m, 12)
    assert len(a) == len(set(a)) == 12
    vals = sorted(m[x] for x in a)
    assert vals[0] - min(m.values()) < 0.25 and max(m.values()) - vals[-1] < 0.25
    assert max(b - c for b, c in zip(vals[1:], vals)) < 1.0


def test_no_field_is_compared_to_itself_and_no_pair_repeats():
    m = means(world())
    pairs = design_pairs(m, choose_anchors(m, 12))
    assert all(a != b for a, b in pairs)
    assert len(pairs) == len({tuple(sorted(p)) for p in pairs})


def test_every_field_meets_four_anchors_adaptively_and_two_random_fields():
    m = means(world())
    anchors = choose_anchors(m, 12)
    pairs = design_pairs(m, anchors)
    opp = {f: set() for f in m}
    for a, b in pairs:
        opp[a].add(b)
        opp[b].add(a)
    for f in m:
        met = [x for x in anchors if x in opp[f]]
        assert len(opp[f]) >= 6 and len(met) >= 4
        below = sorted((x for x in anchors if x != f and m[x] <= m[f]), key=lambda x: m[f] - m[x])[:2]
        above = sorted((x for x in anchors if x != f and m[x] > m[f]), key=lambda x: m[x] - m[f])[:2]
        assert set(below + above) <= opp[f]  # the nearest anchors on either side, whatever else it meets


def test_design_is_deterministic_and_about_six_pairs_per_field():
    m = means(world())
    a = choose_anchors(m, 12)
    assert design_pairs(m, a) == design_pairs(m, a)
    assert 5.0 * N / 1 <= len(design_pairs(m, a)) <= 6.0 * N


def test_both_orders_share_one_hash_present_opposite_orders_and_balance_across_pairs():
    ids = [f"f.{k:03d}" for k in range(400)]
    first = 0
    for k in range(0, 400, 2):
        pair = (ids[k], ids[k + 1])
        h = pair_hash("abstract_tangible", [{"id": p} for p in pair])
        v0, v1 = presented(pair, h, 0), presented(pair, h, 1)
        assert v0 == v1[::-1] and set(v0) == set(pair)
        first += v0[0] == min(pair)
    assert 0.35 < first / 200 < 0.65


def test_batches_have_both_orders_under_the_token_cap_with_the_prompt_in_every_part(prompts):
    cards = world()
    m = means(cards)
    parts = build_pair_batches(cards, m, "abstract_tangible", model="haiku-runner", prompts_dir=prompts, max_tokens=4000,
                               anchors=choose_anchors(m, 12))
    assert len(parts) > 1
    tasks = []
    for lines in parts:
        assert json.loads(lines[0])["prefix"] == "# Task: axes_pair\nprefix text.\n"
        assert -(-len("\n".join(lines)) // 4) <= 4000
        tasks += [json.loads(l) for l in lines[1:]]
    pairs = design_pairs(m, choose_anchors(m, 12))
    assert len(tasks) == 2 * len(pairs)
    by_hash = {}
    for t in tasks:
        assert t["task_type"] == "axes_pair" and t["allowed_verdicts"] == ["a", "b", "tie"] and t["k"] == 2
        assert t["input"]["axis"] == "abstract_tangible" and t["input"]["a"]["id"] != t["input"]["b"]["id"]
        by_hash.setdefault(t["input_hash"], {})[t["variant"]] = (t["input"]["a"]["id"], t["input"]["b"]["id"])
    assert all(set(v) == {0, 1} and v[0] == v[1][::-1] for v in by_hash.values())


def test_a_card_in_the_task_is_context_free_and_the_input_hash_ignores_presentation(prompts):
    cards = world()
    m = means(cards)
    t = json.loads(build_pair_batches(cards, m, "personal_global", model="m", prompts_dir=prompts)[0][1])
    assert set(t["input"]) == {"axis", "toward", "a", "b"} and set(t["input"]["a"]) == {"id", "label", "description", "sectors"}
    assert t["input"]["a"]["sectors"] == ["Sector"]
    assert t["input_hash"] == pair_hash("personal_global", [t["input"]["a"], t["input"]["b"]])
    assert t["input_hash"] == pair_hash("personal_global", [t["input"]["b"], t["input"]["a"]])


def test_cached_votes_are_skipped(prompts, tmp_path):
    cards = world()
    m = means(cards)
    parts = build_pair_batches(cards, m, "abstract_tangible", model="m", prompts_dir=prompts)
    first = json.loads(parts[0][1])
    cache = AnswerCache(tmp_path / "answers")
    cache.put_all([{"task_id": first["task_id"], "task_type": "axes_pair", "input_hash": first["input_hash"], "variant": 0,
                    "model": "m", "prompt_version": 1, "verdict": "a", "reason": "r"}])
    again = build_pair_batches(cards, m, "abstract_tangible", model="m", prompts_dir=prompts, cache=cache)
    assert sum(len(p) - 1 for p in again) == sum(len(p) - 1 for p in parts) - 1


def test_batches_are_written_as_axis_part_files_and_answers_validate(prompts, tmp_path):
    cards = world()
    m = means(cards)
    parts = build_pair_batches(cards, m, "abstract_tangible", model="haiku-runner", prompts_dir=prompts, max_tokens=4000)
    paths = write_pair_batches(parts, tmp_path, "abstract_tangible")
    assert [p.name for p in paths] == [f"axes_pair.abstract_tangible.v1.part{n}.jsonl" for n in range(len(parts))]
    lines = parts[0]
    answers = [json.dumps({**{k: json.loads(l)[k] for k in ("task_id", "task_type", "input_hash", "variant", "prompt_version")},
                           "model": "haiku-runner", "verdict": "tie", "reason": "r"}) for l in lines[1:]]
    assert validate_answers(lines, answers) == []


def test_a_verdict_names_the_presented_slot_and_resolves_to_field_ids():
    cards = world()
    m = means(cards)
    parts = build_pair_batches(cards, m, "abstract_tangible", model="m", prompts_dir=ROOT / "prompts")
    tasks = [json.loads(l) for p in parts for l in p[1:]]
    ans = [{"input_hash": t["input_hash"], "variant": t["variant"], "verdict": "a"} for t in tasks[:2]]
    comps = comparisons_from_answers(ans, tasks)
    assert len(comps) == 2 and tasks[0]["input_hash"] == tasks[1]["input_hash"]
    assert comps[0][:2] == comps[1][:2][::-1] and {c[2] for c in comps} == {"a"}  # "a" is the slot, so the winners differ
    t = tasks[0]
    assert comps[0][:2] == (t["input"]["a"]["id"], t["input"]["b"]["id"]) and comps[0][2] == "a"


def test_always_naming_the_first_slot_cancels_across_the_two_orders():
    cards = world()
    m = means(cards)
    parts = build_pair_batches(cards, m, "abstract_tangible", model="m", prompts_dir=ROOT / "prompts")
    tasks = [json.loads(l) for p in parts for l in p[1:]]
    comps = comparisons_from_answers([{"input_hash": t["input_hash"], "variant": t["variant"], "verdict": "a"} for t in tasks], tasks)
    fit = fit_bt(comps)
    assert max(fit.theta.values()) - min(fit.theta.values()) < 0.5  # pure position bias carries no position


def test_a_simulated_judge_over_the_design_recovers_the_true_positions():
    cards = world()
    m = means(cards)
    true = {k: v + random.Random(k).gauss(0, 0.3) for k, v in m.items()}  # the prior means are only a noisy guide
    parts = build_pair_batches(cards, m, "abstract_tangible", model="m", prompts_dir=ROOT / "prompts")
    tasks = [json.loads(l) for p in parts for l in p[1:]]
    rng = random.Random(1)
    ans = []
    for t in tasks:
        d = true[t["input"]["a"]["id"]] - true[t["input"]["b"]["id"]] + rng.gauss(0, 0.4)
        ans.append({"input_hash": t["input_hash"], "variant": t["variant"], "verdict": "tie" if abs(d) < 0.25 else "a" if d > 0 else "b"})
    fit = fit_bt(comparisons_from_answers(ans, tasks))
    ids = sorted(true)
    assert spearman([true[i] for i in ids], [fit.theta[i] for i in ids]) > 0.9


def test_axis_means_average_each_version_over_variants_and_map_hashes_to_fields():
    cards = world()
    by_id = {c["id"]: c for c in cards}
    f0, f1 = (axes_input(by_id[i], by_id) for i in ("f.000", "f.001"))
    h0, h1 = content_hash(f0), content_hash(f1)
    v1 = [{"input_hash": h0, "verdict": "+2,-1"}, {"input_hash": h0, "verdict": "0,-1"}, {"input_hash": h1, "verdict": "-2,+2"}]
    v2 = [{"input_hash": h0, "verdict": "+1,0"}, {"input_hash": h1, "verdict": "-1,+1"}]
    mm = axis_means(cards, [v1, v2])
    assert set(AXES) == {"abstract_tangible", "personal_global"}
    assert mm["abstract_tangible"]["f.000"] == pytest.approx((1.0 + 1.0) / 2) and mm["abstract_tangible"]["f.001"] == pytest.approx(-1.5)
    assert mm["personal_global"]["f.000"] == pytest.approx((-1.0 + 0.0) / 2) and "s.one" not in mm["personal_global"]


def test_fit_tool_writes_rescaled_positions_and_reports_agreement_extremes_and_split_half(tmp_path):
    tool = load_tool("axes_pair_fit")
    cards = world()
    m = means(cards)
    true = {k: v for k, v in m.items()}
    parts = build_pair_batches(cards, m, "abstract_tangible", model="m", prompts_dir=ROOT / "prompts")
    tasks = [json.loads(l) for p in parts for l in p[1:]]
    rng = random.Random(2)
    ans = []
    for t in tasks:
        d = true[t["input"]["a"]["id"]] - true[t["input"]["b"]["id"]] + rng.gauss(0, 0.3)
        ans.append({"input_hash": t["input_hash"], "variant": t["variant"], "verdict": "tie" if abs(d) < 0.2 else "a" if d > 0 else "b"})
    rows, stats = tool.fit_axis("abstract_tangible", tasks, ans, m, seed=0)
    assert {r["id"] for r in rows} == set(m) and all(-1 <= r["position"] <= 1 and r["se"] > 0 for r in rows)
    assert max(abs(r["position"]) for r in rows) == pytest.approx(1.0)
    assert stats["spearman_v1v2"] > 0.9 and 0 <= stats["extreme_share"] <= 1 and stats["split_half"] > 0.8
    out = tmp_path / "pw.jsonl"
    tool.write_rows(rows, out)
    first = json.loads(out.read_text().splitlines()[0])
    assert set(first) == {"id", "axis", "position", "se"} and first["axis"] == "abstract_tangible"
    assert "abstract_tangible" in tool.report({"abstract_tangible": stats})
