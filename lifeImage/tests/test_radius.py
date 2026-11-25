"""Radius proxies (LI.26): specificity, difficulty, complexity from mechanical sources; composite; coverage."""
import copy
import json
import math
from functools import lru_cache
from pathlib import Path

import pytest

from lifeimage import radius as rd
from lifeimage.validate import validate_card

from conftest import make_card, link

ROOT = Path(__file__).resolve().parent.parent


def _anchor(source, code):
    return {"source": source, "code": code, "label": code}


def tiny_world():
    """Two sectors; four coarse fields in s.a (c.0 is broad, c.3 narrow); fine nodes under c.3 and c.0."""
    cards = [make_card("s.a", axes=None, links=[]), make_card("s.b", axes=None, links=[])]
    for n in range(4):
        cards.append(make_card(f"c.{n}", links=[link("s.a")]))
    cards.append(make_card("c.4", links=[link("s.b")]))
    fine = [make_card("f.skill", level="fine", links=[link("c.3")], anchors=[_anchor("esco_isco", "212")]),
            make_card("f.low", level="fine", links=[link("c.0")], anchors=[_anchor("esco_isco", "911")]),
            make_card("f.plain", level="fine", links=[link("c.0")], anchors=[_anchor("openalex", "1")])]
    rows = []
    for i, a in enumerate(["c.0", "c.1", "c.2", "c.3"]):
        for b in ["c.0", "c.1", "c.2", "c.3", "c.4"]:
            if a != b:
                rows.append({"a": a, "b": b, "p": 0.3, "support": 8 - 2 * i, "type_i": "content", "type_j": "content", "version": "0"})
    return cards, fine, rows


@lru_cache(maxsize=1)
def shipped():
    coarse = [json.loads(l) for l in (ROOT / "data/coarse/seed_v2.jsonl").read_text().splitlines() if l.strip()]
    fine = [json.loads(l) for l in (ROOT / "data/fine/fine_v0.jsonl").read_text().splitlines() if l.strip()]
    rows = [json.loads(l) for l in (ROOT / "data/coarse/comembership_v0.jsonl").read_text().splitlines() if l.strip()]
    return coarse, fine, rows, rd.compute(coarse, fine, rows)


def shipped_as_built():
    """The radius as `tools/build_radius.py` writes it: judged scores (radius v1) taken when cached, else mechanical."""
    coarse, fine, rows, _ = shipped()
    answers = ROOT / "data/answers/radius.jsonl"
    judged = {}
    if answers.exists():
        from lifeimage.radius_judged import judged_means, owners
        judged = judged_means([json.loads(l) for l in answers.read_text().splitlines() if l.strip()], owners(coarse))
    return coarse, fine, rows, rd.compute(coarse, fine, rows, judged=judged)


# ---------- the proxies, one by one ----------

def test_isco_difficulty_follows_the_four_skill_levels_of_isco08():
    d = {m: rd.isco_difficulty(m + "11") for m in "123456789"}
    assert d["9"] == 0.0 and d["2"] == 1.0                      # level 1 elementary, level 4 professionals
    assert d["3"] < d["2"] and d["3"] > d["4"] == d["5"] == d["6"] == d["7"] == d["8"] > d["9"]
    assert d["1"] == pytest.approx((3.5 - 1) / 3)               # managers: levels 3 and 4
    assert rd.isco_difficulty("4") == d["4"] and rd.isco_difficulty("212") == 1.0  # coarse anchors carry the major group alone
    assert rd.isco_difficulty("011") == 1.0 and rd.isco_difficulty("031") == 0.0  # armed forces by sub-major


def test_isco_difficulty_rejects_non_isco_codes():
    for bad in ("", "x", "S5.5", "99x"):
        with pytest.raises(ValueError):
            rd.isco_difficulty(bad)


def test_information_content_is_higher_for_a_narrower_node_and_never_lower_for_a_child():
    cards, fine, rows = tiny_world()
    ic = rd.information_content(cards, fine, rows)
    assert ic["c.3"] > ic["c.0"]                                 # c.3 has less mass than c.0
    assert ic["s.a"] < ic["c.3"]                                 # a sector holds its fields' mass
    assert ic["f.skill"] >= ic["c.3"] and ic["f.low"] >= ic["c.0"]


def test_reuse_level_runs_from_transversal_to_occupation_specific():
    sk = lambda code: make_card("f.x", level="fine", anchors=[_anchor("esco_skills", code)])
    occ = make_card("f.y", level="fine", anchors=[_anchor("esco_isco", "212")])
    assert rd.reuse_level(sk("S1.5")) < rd.reuse_level(sk("S8.9")) <= rd.reuse_level(occ) == 1.0
    assert rd.reuse_level(make_card("f.z", level="fine", anchors=[_anchor("openalex", "1402")])) is None


def test_distinct_upstream_counts_ancestors_once():
    cards, fine, _ = tiny_world()
    up = rd.distinct_upstream(cards + fine)
    assert up["s.a"] == 0 and up["c.0"] == 1 and up["f.skill"] == 2   # c.3 and s.a
    dual = make_card("f.dual", level="fine", links=[link("c.3", weight=.5), link("c.4", weight=.5)])
    assert rd.distinct_upstream(cards + fine + [dual])["f.dual"] == 4  # c.3, c.4, s.a, s.b


def test_prerequisite_depth_is_bounded_even_on_a_cycle():
    ids = [f"c.{i}" for i in range(6)]
    rows = []
    for i, a in enumerate(ids):  # a ring: each sits inside the next, a cycle
        b = ids[(i + 1) % 6]
        rows += [{"a": a, "b": b, "p": 0.9, "support": 9, "type_i": "content", "type_j": "content", "version": "0"},
                 {"a": b, "b": a, "p": 0.1, "support": 9, "type_i": "content", "type_j": "content", "version": "0"}]
    d = rd.prerequisite_depth(rows, ids)
    assert all(0 <= v <= rd.PREREQ_CAP for v in d.values())


def test_prerequisite_depth_follows_inclusion_direction():
    ids = ["c.a", "c.b", "c.c"]
    mk = lambda a, b, p, s=5: {"a": a, "b": b, "p": p, "support": s, "type_i": "content", "type_j": "content", "version": "0"}
    rows = [mk("c.a", "c.b", .9), mk("c.b", "c.a", .2), mk("c.b", "c.c", .8), mk("c.c", "c.b", .1)]  # a in b in c
    d = rd.prerequisite_depth(rows, ids)
    assert d["c.a"] == 2 and d["c.b"] == 1 and d["c.c"] == 0
    weak = [mk("c.a", "c.b", .9, s=1), mk("c.b", "c.a", .2, s=1)]  # below the support floor: no direction
    assert rd.prerequisite_depth(weak, ids)["c.a"] == 0


# ---------- the composite ----------

def test_composite_is_in_unit_interval_and_child_is_never_inside_its_parent():
    cards, fine, rows = tiny_world()
    res = rd.compute(cards, fine, rows)
    comp = {i: r["composite"] for i, r in res.radius.items()}
    assert all(0 <= v <= 1 for v in comp.values())
    assert rd.hierarchy_violations(cards + fine, res.radius) == []
    assert comp["f.skill"] > comp["c.3"] > comp["s.a"] and comp["f.low"] > comp["c.0"]


def test_a_child_placed_inside_its_parent_is_flagged():
    cards, fine, rows = tiny_world()
    radius = copy.deepcopy(rd.compute(cards, fine, rows).radius)
    radius["f.skill"]["composite"] = radius["c.3"]["composite"] - 0.05
    assert ("f.skill", "c.3") in rd.hierarchy_violations(cards + fine, radius)
    radius["f.skill"]["composite"] = radius["c.3"]["composite"]  # touching the parent's radius is still not outside
    assert ("f.skill", "c.3") in rd.hierarchy_violations(cards + fine, radius)


def test_a_simple_child_still_lands_outside_a_complex_parent():
    cards, fine, rows = tiny_world()
    res = rd.compute(cards, fine, rows)
    assert res.radius["f.low"]["composite"] > res.radius["c.0"]["composite"]   # f.low: ISCO 9, the easiest, under the broadest


def test_composite_never_falls_when_a_proxy_rises():
    base = {"complexity": 0.2, "difficulty": 0.3, "specificity": 0.4}
    c0 = rd.combine(base)
    for k in base:
        assert rd.combine({**base, k: base[k] + 0.3}) >= c0
        assert rd.combine({**base, k: None}) is not None            # a missing proxy is left out, not read as zero
    assert rd.combine({"complexity": None, "difficulty": None, "specificity": None}) is None


def test_ranks_are_normalised_within_each_sector_not_across():
    cards, fine, rows = tiny_world()
    res = rd.compute(cards, fine, rows)
    q = {i: r["specificity"] for i, r in res.radius.items() if i.startswith("c.")}
    assert min(q[f"c.{n}"] for n in range(4)) == 0.0 and max(q[f"c.{n}"] for n in range(4)) == 1.0
    assert q["c.4"] == 0.5                                       # alone in s.b: no information to rank against


def test_compute_is_deterministic():
    cards, fine, rows = tiny_world()
    assert rd.compute(cards, fine, rows).radius == rd.compute(cards, fine, rows).radius


# ---------- correlations ----------

def test_proxies_that_correlate_negatively_are_flagged():
    table = {f"d{i}": {"complexity": i / 9, "difficulty": i / 9, "specificity": 1 - i / 9} for i in range(10)}
    corr = rd.proxy_correlations(table)
    assert corr[("complexity", "specificity")][0] == pytest.approx(-1.0)
    assert corr[("complexity", "difficulty")][0] == pytest.approx(1.0)
    assert rd.negative_pairs(corr) == [("complexity", "specificity"), ("difficulty", "specificity")]


def test_spearman_uses_average_ranks_for_ties():
    assert rd.spearman([1, 1, 2, 3], [1, 1, 2, 3]) == pytest.approx(1.0)
    assert rd.spearman([1, 2, 3, 4], [4, 3, 2, 1]) == pytest.approx(-1.0)
    assert rd.spearman([1, 1, 1], [1, 2, 3]) is None


# ---------- the shipped data ----------

def test_every_coarse_and_fine_node_has_specificity_and_complexity():
    coarse, fine, rows, res = shipped()
    assert set(res.radius) == {c["id"] for c in coarse + fine}
    for r in res.radius.values():
        assert r["specificity"] is not None and r["complexity"] is not None and 0 <= r["composite"] <= 1
    cov = res.report["coverage"]
    assert cov["specificity"] == 1.0 and cov["complexity"] == 1.0 and 0.1 < cov["difficulty"] < 1.0


def test_shipped_children_are_outside_their_parents():
    coarse, fine, rows, res = shipped()
    assert rd.hierarchy_violations(coarse + fine, res.radius) == []


def test_shipped_correlation_report_flags_every_negative_pair_and_complexity_tracks_difficulty():
    """Positive co-movement is expected (LI.26), not assumed: the report must say which pairs fail it. On the shipped
    data complexity and difficulty correlate positively; specificity does not yet correlate with the others
    (|z| = |rho| sqrt(n - 1) < 2 for every pair involving it), so the report flags, never hides, that gap."""
    *_, res = shipped()
    corr = res.report["correlations"]
    assert res.report["negative_pairs"] == rd.negative_pairs(corr)
    rho, n = corr[("complexity", "difficulty")]
    assert rho > 0 and rho * math.sqrt(n - 1) > 2
    for pair in (("complexity", "specificity"), ("difficulty", "specificity")):
        rho, n = corr[pair]
        assert abs(rho) * math.sqrt(n - 1) < 2 or rho > 0, f"{pair} is significantly negative"


def test_v3_and_fine_v1_files_carry_the_radius_and_leave_every_other_field_alone():
    coarse, fine, rows, res = shipped_as_built()
    for old, new in ((coarse, "data/coarse/seed_v3.jsonl"), (fine, "data/fine/fine_v1.jsonl")):
        cards = [json.loads(l) for l in (ROOT / new).read_text().splitlines() if l.strip()]
        assert [c["id"] for c in cards] == [c["id"] for c in old]
        for o, c in zip(old, cards):
            validate_card(c)
            assert c["radius"] == res.radius[o["id"]]
            assert {k: v for k, v in c.items() if k != "radius"} == {k: v for k, v in o.items() if k != "radius"}
            assert o["radius"] is None                            # v2 and v0 stay untouched


def test_the_report_lists_the_nodes_where_the_proxies_disagree_most():
    *_, res = shipped()
    top = res.report["disagreement"]
    assert len(top) >= 10 and top[0]["spread"] >= top[-1]["spread"]
    assert all(t["spread"] <= 1 and len(t["proxies"]) >= 2 for t in top)
