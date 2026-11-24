"""The pairwise pilot: fewer comparisons per field, each pair shown once with the first slot balanced across the set."""
import importlib.util
import json
import random
from collections import Counter
from pathlib import Path

import pytest

from lifeimage.axes_pair import (build_pair_batches, choose_anchors, comparisons_from_answers, design_pairs, write_pair_batches)
from lifeimage.pairwise import fit_bt, spearman
from lifeimage.validate import validate_answers

from conftest import link, make_card

ROOT = Path(__file__).resolve().parent.parent
N = 120


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


def pilot(cards, m, **kw):
    parts = build_pair_batches(cards, m, "abstract_tangible", model="m", prompts_dir=ROOT / "prompts", comparisons=4, single_order=True, **kw)
    return parts, [json.loads(l) for p in parts for l in p[1:]]


def test_four_comparisons_per_field_is_the_floor_and_about_a_third_of_the_default_design():
    m = means(world())
    a = choose_anchors(m, 12)
    pairs, full = design_pairs(m, a, comparisons=4), design_pairs(m, a)
    opp = {f: set() for f in m}
    for x, y in pairs:
        opp[x].add(y)
        opp[y].add(x)
    assert min(len(v) for v in opp.values()) >= 4
    assert len(pairs) < 0.75 * len(full)


def test_each_pair_is_asked_once_and_presented_in_one_order():
    cards = world()
    m = means(cards)
    _, tasks = pilot(cards, m)
    pairs = design_pairs(m, choose_anchors(m, 12), comparisons=4)
    assert len(tasks) == len(pairs) and len({t["input_hash"] for t in tasks}) == len(pairs)
    assert all(t["k"] == 1 and t["variant"] == 0 for t in tasks)
    assert {frozenset((t["input"]["a"]["id"], t["input"]["b"]["id"])) for t in tasks} == {frozenset(p) for p in pairs}


def test_the_first_slot_is_balanced_over_the_set_and_per_field():
    cards = world()
    _, tasks = pilot(cards, means(cards))
    first, second = Counter(), Counter()
    for t in tasks:
        first[t["input"]["a"]["id"]] += 1
        second[t["input"]["b"]["id"]] += 1
    fields = set(first) | set(second)
    assert max(abs(first[f] - second[f]) for f in fields) <= 1  # every field is first as often as second, give or take one
    share = [first[f] / (first[f] + second[f]) for f in fields]
    assert 0.45 <= sum(share) / len(share) <= 0.55


def test_the_presentation_is_deterministic():
    cards = world()
    m = means(cards)
    assert pilot(cards, m)[0] == pilot(cards, m)[0]


def test_a_judge_that_always_names_the_first_slot_carries_no_position():
    cards = world()
    _, tasks = pilot(cards, means(cards))
    comps = comparisons_from_answers([{"input_hash": t["input_hash"], "variant": 0, "verdict": "a"} for t in tasks], tasks)
    fit = fit_bt(comps)
    ids = sorted(fit.theta)
    assert max(fit.theta.values()) - min(fit.theta.values()) < 1.5  # an odd win in four comparisons moves a field about one log-unit
    assert abs(spearman(range(len(ids)), [fit.theta[i] for i in ids])) < 0.3  # nothing orders the fields by id


def test_a_first_slot_biased_judge_still_recovers_the_positions():
    cards = world()
    m = means(cards)
    true = {k: v + random.Random(k).gauss(0, 0.3) for k, v in m.items()}
    _, tasks = pilot(cards, m)
    rng = random.Random(3)
    ans = []
    for t in tasks:
        d = true[t["input"]["a"]["id"]] - true[t["input"]["b"]["id"]] + 0.8 + rng.gauss(0, 0.4)  # +0.8: a pull to slot a
        ans.append({"input_hash": t["input_hash"], "variant": 0, "verdict": "tie" if abs(d) < 0.25 else "a" if d > 0 else "b"})
    fit = fit_bt(comparisons_from_answers(ans, tasks))
    ids = sorted(true)
    assert spearman([true[i] for i in ids], [fit.theta[i] for i in ids]) > 0.85


def test_pilot_parts_are_named_pilot_stay_under_the_cap_and_validate(tmp_path):
    cards = world()
    m = means(cards)
    parts, _ = pilot(cards, m, max_tokens=3000)
    assert len(parts) > 1
    paths = write_pair_batches(parts, tmp_path, "abstract_tangible", tag="pilot")
    assert [p.name for p in paths] == [f"axes_pair.abstract_tangible.pilot.part{n}.jsonl" for n in range(len(parts))]
    for lines in parts:
        assert -(-len("\n".join(lines)) // 4) <= 3000
    lines = parts[0]
    answers = [json.dumps({**{k: json.loads(l)[k] for k in ("task_id", "task_type", "input_hash", "variant", "prompt_version")},
                           "model": "m", "verdict": "tie", "reason": "r"}) for l in lines[1:]]
    assert validate_answers(lines, answers) == []


def test_the_default_build_keeps_its_names_and_both_orders():
    cards = world()
    m = means(cards)
    parts = build_pair_batches(cards, m, "abstract_tangible", model="m", prompts_dir=ROOT / "prompts")
    tasks = [json.loads(l) for p in parts for l in p[1:]]
    assert len(tasks) == 2 * len(design_pairs(m, choose_anchors(m, 12))) and {t["k"] for t in tasks} == {2}


def test_the_fit_tool_reads_pilot_answers_and_reports_reliability_agreement_and_extremes(tmp_path):
    tool = load_tool("axes_pair_fit")
    cards = world()
    m = means(cards)
    _, tasks = pilot(cards, m)
    rng = random.Random(4)
    ans = []
    for t in tasks:
        d = m[t["input"]["a"]["id"]] - m[t["input"]["b"]["id"]] + rng.gauss(0, 0.3)
        ans.append({"task_id": t["task_id"], "input_hash": t["input_hash"], "variant": 0, "verdict": "tie" if abs(d) < 0.2 else "a" if d > 0 else "b"})
    for n in range(2):
        (tmp_path / f"axes_pair.abstract_tangible.pilot.part{n}.answers.jsonl").write_text("".join(json.dumps(a) + "\n" for a in ans[n::2]))
    (tmp_path / "axes_pair.abstract_tangible.v1.part0.answers.jsonl").write_text("not read\n")
    files = tool.answer_files(tmp_path, "abstract_tangible", pilot=True)
    assert [f.name for f in files] == [f"axes_pair.abstract_tangible.pilot.part{n}.answers.jsonl" for n in range(2)]
    got = [json.loads(l) for f in files for l in f.read_text().splitlines()]
    rows, stats = tool.fit_axis("abstract_tangible", tasks, got, m, version_means={"v1": m, "v2": m})
    assert stats["split_half"] > 0.4 and stats["spearman_v1"] > 0.85 and stats["spearman_v2"] > 0.85
    text = tool.report({"abstract_tangible": stats})
    assert "split-half" in text and "Spearman with v1 means" in text and "extremes" in text
    assert [f.name for f in tool.answer_files(tmp_path, "abstract_tangible", pilot=False)] == [
        "axes_pair.abstract_tangible.v1.part0.answers.jsonl"]
