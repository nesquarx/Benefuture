"""Judged radius scale (LI.26): one 0-10 verdict per coarse field, batches, comparison with the mechanical proxies, and
the composite that takes the judged score when present. Tests assert outcomes: what a runner is shown, what the
report says, where a field lands."""
import importlib
import importlib.util
import json
import random
from pathlib import Path

import pytest

from lifeimage import degradation
from lifeimage import radius as rd
from lifeimage.axes import axes_input
from lifeimage.canonical import content_hash
from lifeimage.validate import validate_answers

from conftest import link, make_card
from test_radius import tiny_world

ROOT = Path(__file__).resolve().parent.parent


def judged_mod():
    return importlib.import_module("lifeimage.radius_judged")


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def world(n=120):
    cards = [make_card("s.a", axes=None, links=[], label="Sector A")]
    cards += [make_card(f"f.{i:03d}", label=f"Field {i}", links=[link("s.a")]) for i in range(n)]
    return cards


def batches(cards=None, **kw):
    return judged_mod().build_batches(cards or world(), model="haiku-runner", **kw)


def tasks(lines):
    return [json.loads(l) for l in lines[1:]]


def test_batches_hold_at_most_50_cards_two_variants_every_field_once_each():
    b = batches()
    assert {key[0] for key in b} == {0, 1}
    for v in (0, 1):
        parts = [(k, l) for k, l in b.items() if k[0] == v]
        assert all(len(l) - 1 <= 50 for _, l in parts)
        ids = [t["input"]["card"]["id"] for _, l in sorted(parts) for t in tasks(l)]
        assert sorted(ids) == sorted(f"f.{i:03d}" for i in range(120)) and len(parts) == 3
    sizes = sorted(len(l) - 1 for k, l in b.items() if k[0] == 0)
    assert sizes[-1] - sizes[0] <= 1  # balanced, not 50 + 50 + 20


def test_sectors_are_not_judged_and_the_variants_show_different_orders():
    b = batches()
    ids = {t["input"]["card"]["id"] for l in b.values() for t in tasks(l)}
    assert "s.a" not in ids
    order = {v: [t["input"]["card"]["id"] for k, l in sorted(b.items()) if k[0] == v for t in tasks(l)] for v in (0, 1)}
    assert order[0] != order[1]


def test_tasks_are_radius_type_with_a_0_to_10_string_scale_and_validate():
    b = batches()
    for (v, n), lines in b.items():
        h = json.loads(lines[0])
        assert h["task_type"] == "radius" and h["prompt_version"] == 1 and h["model"] == "haiku-runner"
        for t in tasks(lines):
            assert t["allowed_verdicts"] == [str(i) for i in range(11)] and t["task_type"] == "radius"
    lines = b[(0, 0)]
    rest = [{"task_id": t["task_id"], "task_type": "radius", "input_hash": t["input_hash"], "variant": 0, "model": "haiku-runner",
             "prompt_version": 1, "verdict": "7", "reason": "r"} for t in tasks(lines)]
    assert validate_answers(lines, [json.dumps(a) for a in rest]) == []
    rest[0]["verdict"] = "11"
    assert any("not in" in e for e in validate_answers(lines, [json.dumps(a) for a in rest]))


def test_the_prompt_names_the_scale_and_the_three_aspects_and_forbids_bulk_scoring():
    prefix = json.loads(batches()[(0, 0)][0])["prefix"].lower()
    for word in ("0 = elementary", "10 = highly specialised", "complexity", "difficulty", "specificity", "quantum decoherence",
                 "neurosurgery", "sleep", "judge each task on its own card; do not build a scoring table or script that assigns values in bulk"):
        assert word in prefix


def test_files_are_named_per_variant_and_part_and_are_gitignored(tmp_path):
    paths = judged_mod().write_batches(batches(), tmp_path)
    assert sorted(p.name for p in paths) == sorted(f"radius.v1.var{v}.part{n}.jsonl" for v in (0, 1) for n in range(3))
    assert "data/batches/" in (ROOT / ".gitignore").read_text()


def test_cached_votes_are_skipped():
    cards = world(10)
    by = {c["id"]: c for c in cards}
    done = {content_hash(axes_input(by["f.000"], by))}

    class Cache:
        def has(self, task_type, h, model, version, variant):
            assert task_type == "radius"
            return h in done
    ids = {t["input"]["card"]["id"] for l in batches(cards, cache=Cache()).values() for t in tasks(l)}
    assert "f.000" not in ids and len(ids) == 9


# ---- the report ----
CARDS = world(40)
BY = {c["id"]: c for c in CARDS}
H = {c["id"]: content_hash(axes_input(c, BY)) for c in CARDS if c["id"].startswith("f.")}
FIELDS = sorted(H)
rank = lambda f: int(f.split(".")[1])


def with_proxies(cards, fn):
    out = []
    for c in cards:
        if c["id"].startswith("f."):
            r = fn(rank(c["id"]))
            c = {**c, "radius": {"complexity": r, "difficulty": r, "specificity": r, "composite": r}}
        out.append(c)
    return out


def votes(fn, k=2):
    return [{"input_hash": H[f], "variant": v, "verdict": str(fn(f, v))} for f in FIELDS for v in range(k)]


def rep(answers, cards=None):
    return judged_mod().radius_report(answers, cards or with_proxies(CARDS, lambda r: r / 40))


def test_identical_variants_agree_and_follow_the_proxies_and_poles_are_counted():
    lin = lambda f, v: round(rank(f) * 10 / 39)
    r = rep(votes(lin))
    assert r["variant_spearman"] == pytest.approx(1.0) and r["variant_mad"] == pytest.approx(0.0)
    assert r["fields"] == 40 and r["variants"] == 2
    for proxy in ("complexity", "difficulty", "specificity", "composite"):
        assert r["spearman"][proxy] > 0.99
    assert 0 < r["share_poles"] < 0.5
    assert rep(votes(lambda f, v: 10 if rank(f) >= 20 else 0))["share_poles"] == 1.0


def test_noisy_variants_disagree_and_reversed_proxies_correlate_negatively():
    rng = random.Random(3)
    r = rep(votes(lambda f, v: rng.randint(0, 10)))
    assert abs(r["variant_spearman"]) < 0.5 and r["variant_mad"] > 2.5
    rev = rep(votes(lambda f, v: round(rank(f) * 10 / 39)), with_proxies(CARDS, lambda r: 1 - r / 40))
    assert rev["spearman"]["composite"] < -0.99


def test_disagreement_lists_the_domains_where_judged_and_mechanical_differ_most():
    # mechanical rises with rank; the judges put f.003 at the top and f.036 at the bottom
    lin = lambda f, v: {"f.003": 10, "f.036": 0}.get(f, round(rank(f) * 10 / 39))
    r = rep(votes(lin))
    top = [d["id"] for d in r["disagreement"][:2]]
    assert set(top) == {"f.003", "f.036"}
    d = r["disagreement"][0]
    assert {"id", "label", "judged", "mechanical"} <= set(d) and len(r["disagreement"]) <= 10


def test_the_compare_tool_reads_answer_files_and_prints_every_figure(tmp_path):
    tool = load_tool("radius_compare")
    cards = with_proxies(CARDS, lambda r: r / 40)
    (tmp_path / "data/coarse").mkdir(parents=True)
    (tmp_path / "data/batches").mkdir()
    (tmp_path / "data/coarse/seed_v3.jsonl").write_text("\n".join(json.dumps(c) for c in cards) + "\n")
    for v in range(2):
        (tmp_path / f"data/batches/radius.v1.var{v}.part0.answers.jsonl").write_text(
            "\n".join(json.dumps({"input_hash": H[f], "variant": v, "verdict": str(round(rank(f) * 10 / 39))}) for f in FIELDS) + "\n")
    r = tool.compare(sorted((tmp_path / "data/batches").glob("radius.v1.*.answers.jsonl")), tmp_path)
    assert r["fields"] == 40 and r["variant_spearman"] == pytest.approx(1.0)
    text = tool.format_report(r)
    for w in ("Spearman", "mean abs difference", "at 0 or 10", "complexity", "difficulty", "specificity", "composite", "disagree"):
        assert w in text


# ---- the composite takes the judged score ----
def composites(judged, log=None):
    cards, fine, rows = tiny_world()
    return rd.compute(cards, fine, rows, log=log, judged=judged)


def test_a_judged_field_lands_by_its_score_not_by_its_mechanical_rank():
    base = composites(None)
    hi = composites({"c.0": 10.0, "c.1": 5.0, "c.2": 5.0, "c.3": 0.0, "c.4": 5.0})
    assert hi.radius["c.0"]["composite"] > hi.radius["c.3"]["composite"]
    assert hi.radius["c.0"]["composite"] != base.radius["c.0"]["composite"]
    lo = composites({"c.0": 0.0, "c.1": 5.0, "c.2": 5.0, "c.3": 10.0, "c.4": 5.0})
    assert lo.radius["c.3"]["composite"] > lo.radius["c.0"]["composite"]
    assert hi.radius["c.0"]["composite"] > lo.radius["c.0"]["composite"]


def test_judged_composite_is_monotone_in_the_score_and_children_stay_outside_parents():
    scores = {f"c.{i}": float(s) for i, s in enumerate([1, 3, 6, 9])}
    scores["c.4"] = 5.0
    res = composites(scores)
    comp = {i: res.radius[i]["composite"] for i in res.radius}
    assert comp["c.0"] < comp["c.1"] < comp["c.2"] < comp["c.3"]
    cards, fine, rows = tiny_world()
    assert rd.hierarchy_violations(cards + fine, res.radius) == []
    assert all(0 <= v <= 1 for v in comp.values())


def test_a_field_without_a_judgement_falls_back_to_the_mechanical_composite_loudly():
    degradation.reset_warned()
    log = []
    with pytest.warns(RuntimeWarning, match="radius_judged"):
        res = composites({"c.0": 9.0, "c.1": 2.0}, log=log)
    fb = [d for d in log if d["mechanism"] == "radius_judged"]
    assert len(fb) == 1 and fb[0]["substitute"] == "mechanical radius composite"
    assert "c.2" in fb[0]["step"] and "c.0" not in fb[0]["step"]
    base = composites(None)
    assert res.radius["c.2"]["composite"] == pytest.approx(base.radius["c.2"]["composite"])
    assert res.report["judged"] == {"judged": 2, "fallback": 3}


def test_without_judged_scores_nothing_changes():
    a, b = composites(None), composites({})
    assert {i: r["composite"] for i, r in a.radius.items()} == {i: r["composite"] for i, r in b.radius.items()}
