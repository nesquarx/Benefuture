"""Relatedness judging (LI.55): pairwise 0-10 judgements that grow the layout simulation's signal where it is missing.

Red first (no `lifeimage.relatedness`, no 'judged' source in the simulation). Outcomes: on the real data the signal covers
fewer than 20% of the pairs within two positions of each other in either layout (the gap this closes); with a synthetic
answer set planting relatedness, the simulation's signal coverage of those pairs and the same-cluster neighbour share both
rise, and without answers the source is absent and the degradation is recorded loudly. Acceptance: pair selection, batch
shape (at most 50 tasks, two variants in opposite pair order, controls indistinguishable from other tasks, a stable
prefix), the loader (mean over variants scaled to [0,1], agreement as confidence). Counterexamples: out-of-scale verdicts,
a pair of one field, and an answer set without variant agreement are rejected or given low confidence."""
import json
import random
from pathlib import Path

import numpy as np
import pytest

from lifeimage import layout_sim as ls
from lifeimage import relatedness as rel
from lifeimage.validate import ValidationError, validate_answers, validate_task

from conftest import make_card
from test_layout_sim import planted, same_share

ROOT = Path(__file__).resolve().parent.parent
BASE_COVERAGE_MAX = 0.20  # real data: share of pairs within two positions with any signal, before judged relatedness


def real():
    from lifeimage.fine.cards import load_fine
    from lifeimage.render import basemap as bm
    cards = bm.load_cards(ROOT / "data/coarse/seed_v3.jsonl")
    fine = load_fine(ROOT / "data/fine/fine_v1.jsonl")
    comem = bm.read_jsonl(ROOT / "data/coarse/comembership_v0.jsonl")
    res = json.loads((ROOT / "data/coarse/layout_sim_v0.json").read_text())
    return cards, fine, comem, res["ring_order"]["before"], res["ring_order"]["after"]


def near_pairs(order, k):
    n = len(order)
    return {tuple(sorted((order[p], order[(p + j) % n]))) for p in range(n) for j in range(1, k + 1)}


def test_real_signal_leaves_most_adjacent_pairs_uncovered():
    cards, fine, comem, axes_order, sim_order = real()
    sig = ls.signals(cards, fine, comem)
    ix = {i: n for n, i in enumerate(sig.ids)}
    for order in (axes_order, sim_order):
        pairs = near_pairs(order, 2)
        covered = sum(sig.combined[ix[a], ix[b]] > 0 for a, b in pairs) / len(pairs)
        assert covered < BASE_COVERAGE_MAX


# ---- selection ----

N = 120


def synth_world(n=N, seed=2):
    rng = random.Random(seed)
    ids = [f"c.{k:03d}" for k in range(n)]
    sig = np.zeros((n, n))
    for _ in range(600):
        a, b = rng.sample(range(n), 2)
        sig[a, b] = sig[b, a] = rng.choice([0.5, 1.0, 2.0, 3.0])
    a_order, b_order = ids[:], ids[:]
    rng.shuffle(b_order)
    return ids, sig, a_order, b_order


def test_selection_covers_near_pairs_without_signal_and_respects_the_cap():
    ids, sig, a_order, b_order = synth_world()
    ix = {i: n for n, i in enumerate(ids)}
    sel = rel.select_pairs(ids, sig, a_order, b_order, cap=700, controls=20, randoms=20)
    has = lambda p: sig[ix[p[0]], ix[p[1]]] > 0
    near = near_pairs(a_order, 2) | near_pairs(b_order, 2)
    need = {p for p in near if not has(p)}
    got_near = {p for p, k in sel["kind"].items() if k == "near"}
    assert got_near == need
    wide = {p for p, k in sel["kind"].items() if k == "wide"}
    assert not any(has(p) for p in got_near | wide)
    assert len(got_near) + len(wide) <= 700 and len(wide) > 0
    assert wide <= (near_pairs(a_order, 5) | near_pairs(b_order, 5))
    controls = [p for p, k in sel["kind"].items() if k == "control"]
    randoms = [p for p, k in sel["kind"].items() if k == "random"]
    assert len(controls) == len(randoms) == 20
    assert all(has(p) for p in controls)
    assert all(sig[ix[a], ix[b]] >= np.percentile(sig[sig > 0], 50) for a, b in controls)
    assert not any(has(p) for p in randoms)
    assert not any(p in near_pairs(a_order, 5) or p in near_pairs(b_order, 5) for p in randoms)
    assert all(a < b for a, b in sel["kind"])


def test_selection_is_deterministic_and_keeps_closest_wide_pairs_under_a_cap():
    ids, sig, a_order, b_order = synth_world()
    s1 = rel.select_pairs(ids, sig, a_order, b_order, cap=500, controls=10, randoms=10)
    s2 = rel.select_pairs(ids, sig, a_order, b_order, cap=500, controls=10, randoms=10)
    assert s1["kind"] == s2["kind"]
    big = rel.select_pairs(ids, sig, a_order, b_order, cap=5000, controls=10, randoms=10)
    wide_big = {p for p, k in big["kind"].items() if k == "wide"}
    wide_small = {p for p, k in s1["kind"].items() if k == "wide"}
    assert wide_small < wide_big


# ---- batches ----

def world_cards(n=N):
    cards = [make_card(f"c.{k:03d}", label=f"Field {k}", description=f"About field {k}", aliases=[], links=[], axes=None) for k in range(n)]
    fine = [make_card(f"f.{k:03d}.{j}", label=f"Fine {k} {j}", level="fine", links=[{"id": f"c.{k:03d}", "rel": "upstream", "weight": 1.0}])
            for k in range(0, n, 2) for j in range(7)]
    return cards, fine


def build():
    ids, sig, a_order, b_order = synth_world()
    sel = rel.select_pairs(ids, sig, a_order, b_order, cap=300, controls=20, randoms=20)
    cards, fine = world_cards()
    return sel, rel.build_relatedness_batches(cards, fine, sel["kind"], model="haiku-runner", prompts_dir=ROOT / "prompts")


def test_batches_are_small_two_variants_opposite_order_and_blind_to_kind():
    sel, (batches, key) = build()
    assert {v for v, _ in batches} == {0, 1}
    assert all(1 <= len(l) - 1 <= 50 for l in batches.values())
    assert sum(len(l) - 1 for (v, _), l in batches.items() if v == 0) == len(sel["kind"])
    by_task = {}
    for lines in batches.values():
        h = json.loads(lines[0])
        assert h["task_type"] == "relatedness" and h["prompt_version"] == 1
        assert h["prefix"].count("Calibration") == 1 and all(x in h["prefix"] for x in ("Cardiology", "Gardening", "Astronomy"))
        for line in lines[1:]:
            t = json.loads(line)
            validate_task(t)
            assert t["allowed_verdicts"] == [str(i) for i in range(11)]
            assert "kind" not in json.dumps(t["input"]) and "control" not in line and "random" not in t["input"]["first"]["label"]
            f, s = t["input"]["first"], t["input"]["second"]
            assert len(f["children"]) <= 5 and len(s["children"]) <= 5
            by_task.setdefault(t["input_hash"], {})[t["variant"]] = (f["id"], s["id"])
    for h, v in by_task.items():
        assert v[0][0] < v[0][1] and v[1] == v[0][::-1]
    assert len({json.loads(l[0])["prefix"] for l in batches.values()}) == 1
    assert len(key["tasks"]) == 2 * len(sel["kind"])
    assert any(len(json.loads(l)["input"]["first"]["children"]) == 5 for lines in batches.values() for l in lines[1:])


def answer_for(batch_lines, score, model="haiku-runner"):
    out = []
    for line in batch_lines[1:]:
        t = json.loads(line)
        out.append(json.dumps({"task_id": t["task_id"], "task_type": t["task_type"], "input_hash": t["input_hash"], "variant": t["variant"],
                               "model": model, "prompt_version": t["prompt_version"], "verdict": str(score(t)), "reason": "x"}))
    return out


def test_validation_accepts_scale_and_rejects_out_of_scale_and_self_pairs():
    _, (batches, _) = build()
    lines = next(iter(batches.values()))
    assert validate_answers(lines, answer_for(lines, lambda t: 4)) == []
    errs = validate_answers(lines, answer_for(lines, lambda t: 11))
    assert errs and "not in" in errs[0]
    bad = json.loads(lines[1])
    bad["input"]["second"] = bad["input"]["first"]
    with pytest.raises(ValidationError):
        validate_answers([lines[0], json.dumps(bad)], [])


# ---- loader ----

def rows_for(key, score_of):
    rows = []
    for tid, t in sorted(key["tasks"].items()):
        rows.append({"task_id": tid, "pair": t["pair"], "variant": t["variant"], "first": t["first"],
                     "verdict": str(score_of(tuple(t["pair"]), t["variant"]))})
    return rows


def test_loader_means_variants_scales_and_gives_agreement_as_confidence():
    sel, (_, key) = build()
    p0 = sorted(sel["kind"])[0]
    rows = rows_for(key, lambda p, v: {0: 8, 1: 8}[v] if p == p0 else {0: 2, 1: 6}[v])
    sg = rel.judged_signal(rows)
    assert sg[p0]["score"] == pytest.approx(0.8) and sg[p0]["confidence"] == pytest.approx(1.0) and sg[p0]["n"] == 2
    other = sorted(sel["kind"])[1]
    assert sg[other]["score"] == pytest.approx(0.4) and sg[other]["confidence"] == pytest.approx(0.6)
    one = rel.judged_signal([rows[0]])
    assert list(one.values())[0]["n"] == 1 and list(one.values())[0]["confidence"] == pytest.approx(rel.SINGLE_CONFIDENCE)


def test_order_bias_report_measures_variant_difference():
    sel, (_, key) = build()
    rows = rows_for(key, lambda p, v: 5 + (2 if v == 1 else 0))  # the reversed order always scores two points higher
    rep = rel.order_bias(rows)
    assert rep["pairs"] == len(sel["kind"]) and rep["mean_reversed_minus_canonical"] == pytest.approx(2.0)
    assert rep["agree_within_1"] == 0.0


def test_calibration_report_states_the_prediction():
    sel, (_, key) = build()
    kind = sel["kind"]
    rows = rows_for(key, lambda p, v: 7 if kind[p] == "control" else 1)
    rep = rel.calibration(rows, kind)
    assert rep["control_mean"] == pytest.approx(7) and rep["random_mean"] == pytest.approx(1)
    assert rep["gap"] == pytest.approx(6) and rep["prediction_met"] is True
    flat = rel.calibration(rows_for(key, lambda p, v: 3), kind)
    assert flat["gap"] == 0 and flat["prediction_met"] is False


# ---- the simulation's 'judged' source ----

def sim_cards(n=24):
    return [make_card(f"c.{k:02d}", label=f"Alpha{chr(97 + k)}", description=f"zq{chr(97 + k)}x unique", aliases=[], links=[], axes=None)
            for k in range(n)]


def sim_params(w_judged=None):
    w = {s: 0.0 for s in ls.SOURCES}
    if w_judged is not None:
        w["judged"] = w_judged
    return ls.Params(weights=w)


def planted_rows(cluster, ids, hi=8, lo=1):
    rows = []
    for a in range(len(ids)):
        for b in range(a + 1, len(ids)):
            for v in (0, 1):
                rows.append({"task_id": f"{a}-{b}-{v}", "pair": [ids[a], ids[b]], "variant": v, "first": ids[a],
                             "verdict": str(hi if cluster[a] == cluster[b] else lo)})
    return rows


def test_judged_source_is_absent_without_answers_and_says_so():
    log = []
    sig = ls.signals(sim_cards(), [], [], sim_params(w_judged=0.5), log=log)
    assert sig.coverage["judged"]["pairs"] == 0
    assert any(d["mechanism"] == "layout_sim judged relatedness" for d in log)
    assert "judged" in ls.SOURCES and ls.governed("layout_sim.w_judged") > 0 and ls.governed("layout_sim.judged_floor") > 0


def test_planted_answers_raise_coverage_and_neighbour_similarity():
    prior, cluster, _, widths = planted(seed=6)
    ids = [f"c.{k:02d}" for k in range(len(prior))]
    cards = sim_cards(len(prior))
    base = ls.signals(cards, [], [], sim_params(w_judged=0.5))
    assert base.coverage["judged"]["pairs"] == 0
    judged = rel.judged_signal(planted_rows(cluster, ids))
    log = []
    sig = ls.signals(cards, [], [], sim_params(w_judged=0.5), judged=judged, log=log)
    assert not log
    n_same = sum(cluster[a] == cluster[b] for a in range(len(ids)) for b in range(a + 1, len(ids)))
    assert sig.coverage["judged"]["pairs"] == n_same  # low scores (below the floor) are not signal
    assert sig.any_coverage["pairs"] > base.any_coverage["pairs"]
    prior_angles = dict(zip(ids, prior))
    out = ls.update_layout(sig, prior_angles, {i: 0.5 for i in ids}, {i: 4.0 for i in ids})
    angles = [out["angles"][i] for i in ids]
    assert same_share(prior, cluster) < 0.8 <= 0.85 <= same_share(angles, cluster)
    order0 = sorted(ids, key=lambda i: prior_angles[i])
    order1 = sorted(ids, key=lambda i: out["angles"][i])
    assert ls.coherence(order1, sig)["mean_similarity"] > ls.coherence(order0, sig)["mean_similarity"]


def test_low_confidence_answers_pull_less():
    cards = sim_cards(6)
    ids = [c["id"] for c in cards]
    row = lambda b, v, x: {"task_id": f"{b}{v}", "pair": [ids[0], ids[b]], "variant": v, "first": ids[0], "verdict": str(x)}
    rows = [row(1, 0, 8), row(1, 1, 8), row(2, 0, 6), row(2, 1, 10)]  # the same mean score, one pair with the variants split
    judged = rel.judged_signal(rows)
    assert judged[(ids[0], ids[1])]["confidence"] > judged[(ids[0], ids[2])]["confidence"]
    m = ls.signals(cards, [], [], sim_params(w_judged=0.5), judged=judged).sources["judged"]
    assert m[0, 1] > m[0, 2] > 0
