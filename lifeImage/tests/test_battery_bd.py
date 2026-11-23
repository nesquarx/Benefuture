"""Battery BD (layer B participation, layer D event links): items, prompts, batches, answer validation, metrics.

Acceptance tests state what must hold; counterexamples state what must fail. Red first, on the outcome: each test is
built so a naive stub (a validator that accepts everything, a conservation counter that returns zero, a collision
rate that ignores the fields, an alpha that ignores disagreement) returns the wrong answer, not a missing-name error."""
import json
import math
import subprocess
import sys
from pathlib import Path

import pytest

from lifeimage.bd_metrics import (collisions_b, compute, events_metrics, krippendorff_alpha_interval, load_bd_records,
                                  match_subevents, participation_metrics, render, spearman)
from lifeimage.events import LINK_TYPES, build_events_batches, validate_bd_answers, validate_events_answer
from lifeimage.membership import DEFAULT_GOLD, load_pairs
from lifeimage.participation import (DEFAULT_ITEMS, build_participation_batches, item_hash, item_input, load_bd_items,
                                     ordered_participants, validate_participation_answer)
from lifeimage.validate import ValidationError

ROOT = Path(__file__).resolve().parent.parent
ITEMS = load_bd_items()
BY_ID = {i["id"]: i for i in ITEMS}


# ---- items ----
def test_item_count_and_sources():
    by_source = {s: [i for i in ITEMS if i["source"] == s] for s in ("redteam", "pair", "new")}
    assert 76 <= len(ITEMS) <= 86
    assert len(by_source["redteam"]) == 28 and len(by_source["pair"]) == 24 and len(by_source["new"]) >= 25
    assert len({i["id"] for i in ITEMS}) == len(ITEMS)
    assert len({i["text"].strip().lower() for i in ITEMS}) == len(ITEMS)


def test_redteam_items_are_exactly_the_layer_b_cases_and_pair_items_the_b_and_d_pairs():
    rows = [json.loads(l) for l in (DEFAULT_GOLD / "relation_redteam_v0.jsonl").read_text().splitlines() if l.strip()]
    b = {r["id"]: r["text"] for r in rows if r["layer"] == "B"}
    got = {i["source_id"]: i["text"] for i in ITEMS if i["source"] == "redteam"}
    assert got == b
    pairs = {p["id"]: p for p in load_pairs() if p["should_differ_in"] in ("B", "D")}
    texts = {(i["pair"], i["side"]): i["text"] for i in ITEMS if i["source"] == "pair"}
    assert texts == {(pid, s): p[s] for pid, p in pairs.items() for s in "ab"}


def test_every_item_lists_its_participants_explicitly_and_expectations_refer_to_them():
    for i in ITEMS:
        ids = [p["id"] for p in i["participants"]]
        assert ids and len(set(ids)) == len(ids), i["id"]
        assert all(p["label"].strip() for p in i["participants"]), i["id"]
        if "expect" in i:
            assert set(i["expect"]["participants"]) <= set(ids), i["id"]


def test_the_named_scenarios_are_covered_by_tags():
    tags = {t for i in ITEMS for t in i["tags"]}
    want = {"overdetermination", "vote", "boycott", "strike", "fasting", "coercion", "acting_for", "surgery_assault",
            "placebo", "lottery", "prevention", "maintenance", "conference_dinner", "theft", "concurrent",
            "failed_treatment", "birth", "teaching", "ghostwriter", "ai_agent", "animal", "employment", "household"}
    assert want <= tags


def test_overdetermination_items_carry_expectations():
    od = [i for i in ITEMS if "overdetermination" in i["tags"] and i["source"] != "pair"]
    assert len(od) >= 5 and all("expect" in i for i in od)


# ---- prompts and batches ----
PART = build_participation_batches(ITEMS)
EVT = build_events_batches(ITEMS)


@pytest.mark.parametrize("batches,tt", [(PART, "participation"), (EVT, "events")])
def test_three_variants_over_every_item(batches, tt):
    assert sorted(batches) == [0, 1, 2]
    for v, lines in batches.items():
        h = json.loads(lines[0])
        assert h["kind"] == "header" and h["task_type"] == tt and h["prompt_version"] == 1
        assert len(lines) - 1 == len(ITEMS)
        t = json.loads(lines[1])
        assert t["allowed_verdicts"] == [tt] and t["variant"] == v and t["k"] == 3
        assert set(t["input"]["item"]) == {"id", "text", "participants"}


def test_participation_prefix_states_the_rules_and_anchors_nothing():
    prefix = json.loads(PART[0][0])["prefix"]
    low = prefix.lower()
    for need in ("outputs only", "never infer intentions", "1/(k+1)", "sum to at most 1", "pivotal", "null"):
        assert need in low, need
    for field in ("contribution", "responsibility", "impact", "acting_for", "under_agreement", "informed", "volition",
                  "production"):
        assert field in prefix
    for it in ITEMS:  # no item text leaks into the shared prefix, and no scenario word that reveals an answer
        assert it["text"].lower() not in low
    for word in ("assassin", "shooter", "archer", "surgeon", "lottery", "placebo", "boycott", "strike", "1/5"):
        assert word not in low, word


def test_events_prefix_defines_the_four_link_types_in_a_variant_dependent_order():
    prefixes = [json.loads(EVT[v][0])["prefix"] for v in range(3)]
    for p in prefixes:
        assert all(f"- {t}:" in p for t in LINK_TYPES)
    orders = {tuple(sorted(LINK_TYPES, key=lambda t: p.index(f"- {t}:"))) for p in prefixes}
    assert len(orders) >= 2


def test_variants_reorder_participants_deterministically_without_changing_the_hash():
    it = BY_ID["bd.rt.44"]
    orders = [tuple(p["id"] for p in ordered_participants(it, v)) for v in range(3)]
    assert len(set(orders)) >= 2 and all(sorted(o) == sorted(orders[0]) for o in orders)
    assert orders == [tuple(p["id"] for p in ordered_participants(it, v)) for v in range(3)]
    assert orders[0] == tuple(sorted(orders[0]))
    assert item_hash(it) == item_hash(dict(it, participants=list(reversed(it["participants"]))))
    assert item_input(it, 1)["item"]["participants"] != item_input(it, 0)["item"]["participants"] or orders[0] == orders[1]
    tasks = [next(t for t in map(json.loads, PART[v][1:]) if t["input"]["item"]["id"] == it["id"]) for v in range(3)]
    assert len({t["input_hash"] for t in tasks}) == 1
    assert [[p["id"] for p in t["input"]["item"]["participants"]] for t in tasks] == [list(o) for o in orders]


def test_batches_are_deterministic():
    assert build_participation_batches(ITEMS) == PART and build_events_batches(ITEMS) == EVT


# ---- answers: participation ----
PARTS = [{"id": "agent", "label": "the surgeon"}, {"id": "patient", "label": "the patient"}]


def pa(**over):
    e = {"id": "agent", "contribution": 0.6, "responsibility": 0.5, "impact": [{"party": "patient", "sign": 1, "magnitude": 2}],
         "acting_for": None, "under_agreement": "the signed consent form", "informed": "risks explained at the pre-op visit",
         "volition": "free", "volition_record": "chose to operate", "production": "produced"}
    e.update(over)
    return e


def pb(**over):
    e = {"id": "patient", "contribution": 0.2, "responsibility": 0.1, "impact": [], "acting_for": None,
         "under_agreement": None, "informed": None, "volition": None, "volition_record": None, "production": "consumed"}
    e.update(over)
    return e


def answer(*ps):
    return {"verdict": "participation", "participants": list(ps)}


def test_a_well_formed_participation_answer_passes():
    assert validate_participation_answer(answer(pa(), pb()), PARTS)


@pytest.mark.parametrize("bad,why", [
    (answer(pa()), "missing participant"),
    (answer(pa(), pb(), pb(id="stranger")), "extra participant"),
    (answer(pa(), pb(id="agent")), "duplicate id"),
    (answer(pa(contribution=0.9), pb(contribution=0.4)), "conservation: sum above 1"),
    (answer(pa(contribution=1.2), pb(contribution=0.0)), "contribution above 1"),
    (answer(pa(contribution=-0.1), pb()), "negative contribution"),
    (answer(pa(responsibility=1.5), pb()), "responsibility above 1"),
    (answer(pa(impact=[{"party": "patient", "sign": 1, "magnitude": 4}]), pb()), "magnitude above 3"),
    (answer(pa(impact=[{"party": "patient", "sign": 0, "magnitude": 1}]), pb()), "sign zero"),
    (answer(pa(impact=[{"party": "patient", "sign": 1}]), pb()), "impact without magnitude"),
    (answer(pa(volition="constrained", volition_record=None), pb()), "constrained with no record"),
    (answer(pa(volition="forced"), pb()), "unknown volition"),
    (answer(pa(volition=None, volition_record="x"), pb()), "record without volition"),
    (answer(pa(production="made"), pb()), "unknown production"),
    (answer(pa(informed=""), pb()), "blank informed"),
    (answer(pa(informed=True), pb()), "informed must be text or null"),
    ({"verdict": "participation", "participants": [{k: v for k, v in pa().items() if k != "informed"}, pb()]}, "missing key"),
    (dict(answer(pa(), pb()), verdict="events"), "wrong verdict"),
])
def test_malformed_participation_answers_are_rejected(bad, why):
    with pytest.raises(ValidationError):
        validate_participation_answer(bad, PARTS)


def test_constrained_with_a_named_record_and_conservation_toggle():
    ok = answer(pa(volition="constrained", volition_record="a prior threat with a knife"), pb())
    assert validate_participation_answer(ok, PARTS)
    over = answer(pa(contribution=0.9), pb(contribution=0.4))
    assert validate_participation_answer(over, PARTS, conservation=False)


# ---- answers: events ----
def ea(**over):
    a = {"verdict": "events",
         "subevents": [{"id": "e1", "label": "make soup"}, {"id": "e2", "label": "chop onions"}],
         "event_links": [{"from": "e2", "to": "e1", "type": "part_of", "confidence": 0.9}]}
    a.update(over)
    return a


def test_a_well_formed_events_answer_passes_and_zero_links_is_fine():
    assert validate_events_answer(ea())
    assert validate_events_answer(ea(event_links=[]))


@pytest.mark.parametrize("bad", [
    ea(subevents=[]),
    ea(subevents=[{"id": "e1", "label": "a"}, {"id": "e1", "label": "b"}]),
    ea(subevents=[{"id": "e1", "label": " "}, {"id": "e2", "label": "b"}]),
    ea(event_links=[{"from": "e2", "to": "e3", "type": "part_of", "confidence": 0.9}]),
    ea(event_links=[{"from": "e1", "to": "e1", "type": "causes", "confidence": 0.9}]),
    ea(event_links=[{"from": "e2", "to": "e1", "type": "enables", "confidence": 0.9}]),
    ea(event_links=[{"from": "e2", "to": "e1", "type": "causes", "confidence": 1.0}]),
    ea(event_links=[{"from": "e2", "to": "e1", "type": "causes", "confidence": 0.0}]),
    ea(event_links=[{"from": "e2", "to": "e1", "type": "causes", "confidence": 0.5},
                    {"from": "e2", "to": "e1", "type": "causes", "confidence": 0.6}]),
    ea(event_links=[{"from": "e1", "to": "e2", "type": "concurrent", "confidence": 0.5},
                    {"from": "e2", "to": "e1", "type": "concurrent", "confidence": 0.5}]),
    ea(verdict="participation"),
])
def test_malformed_events_answers_are_rejected(bad):
    with pytest.raises(ValidationError):
        validate_events_answer(bad)


def _answer_line(task, header, body):
    base = {"task_id": task["task_id"], "task_type": task["task_type"], "input_hash": task["input_hash"],
            "variant": task["variant"], "model": header["model"], "prompt_version": 1,
            "verdict": task["allowed_verdicts"][0], "reason": "r"}
    return base | body


def _fill(task):
    """A valid answer to a task: equal shares for participants, one part_of link for events."""
    parts = task["input"]["item"]["participants"]
    if task["task_type"] == "participation":
        n = len(parts)
        return {"participants": [pb(id=p["id"], contribution=round(0.5 / n, 4), responsibility=0.5) for p in parts]}
    return {"subevents": [{"id": "e1", "label": task["input"]["item"]["text"][:30]}, {"id": "e2", "label": "a step"}],
            "event_links": [{"from": "e2", "to": "e1", "type": "part_of", "confidence": 0.8}]}


def test_validate_bd_answers_end_to_end():
    for batches in (PART, EVT):
        lines = batches[0]
        header = json.loads(lines[0])
        good = [json.dumps(_answer_line(json.loads(l), header, _fill(json.loads(l)))) for l in lines[1:]]
        assert validate_bd_answers(lines, good) == []
        errs = validate_bd_answers(lines, good[:-1])
        assert any("missing answer" in e for e in errs)
        bad_model = json.loads(good[0]) | {"model": "other"}
        assert any("model" in e for e in validate_bd_answers(lines, [json.dumps(bad_model)] + good[1:]))
        if header["task_type"] == "participation":
            wrong = json.loads(good[0])
            wrong["participants"][0]["contribution"] = 1.5
            assert any("line 1" in e for e in validate_bd_answers(lines, [json.dumps(wrong)] + good[1:]))
            stray = json.loads(good[0])
            stray["participants"].pop()
            assert any("line 1" in e for e in validate_bd_answers(lines, [json.dumps(stray)] + good[1:]))
        else:
            wrong = json.loads(good[0])
            wrong["event_links"][0]["type"] = "enables"
            assert any("line 1" in e for e in validate_bd_answers(lines, [json.dumps(wrong)] + good[1:]))


# ---- metrics: primitives ----
def test_spearman():
    assert spearman([1, 2, 3, 4], [10, 20, 30, 40]) == pytest.approx(1.0)
    assert spearman([1, 2, 3, 4], [4, 3, 2, 1]) == pytest.approx(-1.0)
    assert spearman([1, 2, 3, 4], [1, 3, 2, 4]) == pytest.approx(0.8)
    assert spearman([1, 1, 2, 2], [1, 2, 1, 2]) == pytest.approx(0.0)
    assert math.isnan(spearman([1, 1, 1], [1, 2, 3]))


def test_interval_alpha_perfect_total_disagreement_and_degenerate_cases():
    assert krippendorff_alpha_interval([[0.1, 0.1], [0.5, 0.5], [0.9, 0.9]]) == pytest.approx(1.0)
    assert krippendorff_alpha_interval([[0.0, 1.0], [1.0, 0.0]]) == pytest.approx(-0.5)
    # a near-miss counts for less than a far miss (interval, not nominal)
    near = krippendorff_alpha_interval([[0.0, 0.1], [0.5, 0.6], [1.0, 0.9]])
    far = krippendorff_alpha_interval([[0.0, 0.5], [0.5, 1.0], [1.0, 0.0]])
    assert near > 0.9 > far
    assert math.isnan(krippendorff_alpha_interval([[0.3]]))
    assert krippendorff_alpha_interval([[0.4, 0.4], [0.4, 0.4]]) == 1.0


# ---- metrics: participation ----
def rec(item, variant, entries):
    return {"item": item, "variant": variant, "participants": {e["id"]: e for e in entries}, "model": "m", "prompt_version": 1}


def mk_items(*specs):
    return [{"id": i, "text": i, "source": "new", "participants": [{"id": p, "label": p} for p in ps], "tags": [], **extra}
            for i, ps, extra in specs]


def test_conservation_violations_are_counted_per_answer():
    items = mk_items(("x", ["agent", "patient"], {}))
    recs = [rec("x", 0, [pa(contribution=0.5), pb(contribution=0.5)]),
            rec("x", 1, [pa(contribution=0.7), pb(contribution=0.5)]),
            rec("x", 2, [pa(contribution=1.0), pb(contribution=1.0)])]
    c = participation_metrics(recs, items)["conservation"]
    assert c["answers"] == 3 and c["violations"] == 2 and c["rate"] == pytest.approx(2 / 3)
    assert c["max_sum"] == pytest.approx(2.0)


def test_field_alphas_distinguish_agreeing_from_disagreeing_variants():
    items = mk_items(*[(f"x{n}", ["agent", "patient"], {}) for n in range(4)])
    agree, clash = [], []
    for n in range(4):
        for v in range(3):
            agree.append(rec(f"x{n}", v, [pa(contribution=0.1 + 0.2 * n, responsibility=0.2 * n, production="produced" if n % 2 else "both"),
                                           pb(contribution=0.05, production="consumed")]))
            clash.append(rec(f"x{n}", v, [pa(contribution=[0.1, 0.8, 0.3][(n + v) % 3] * 0.9, responsibility=[0.0, 1.0, 0.5][(n + 2 * v) % 3],
                                              production=["produced", "consumed", "both"][(n + v) % 3]),
                                           pb(contribution=[0.6, 0.02, 0.3][(2 * n + v) % 3] * 0.9, production="consumed")]))
    good, bad = participation_metrics(agree, items), participation_metrics(clash, items)
    for f in ("contribution", "responsibility", "production"):
        assert good["fields"][f]["alpha"] > 0.95 > 0.3 > bad["fields"][f]["alpha"], f
    assert good["contribution_spearman"] > 0.95 and bad["contribution_spearman"] < 0.5


def test_null_rates_count_nulls_per_field():
    items = mk_items(("x", ["agent", "patient"], {}))
    recs = [rec("x", 0, [pa(), pb()]), rec("x", 1, [pa(informed=None), pb()])]
    f = participation_metrics(recs, items)["fields"]
    assert f["informed"]["null_rate"] == pytest.approx(3 / 4) and f["under_agreement"]["null_rate"] == pytest.approx(1 / 2)
    assert f["volition"]["null_rate"] == pytest.approx(1 / 2) and f["acting_for"]["null_rate"] == 1.0


SHOOT = mk_items(("shoot", [f"s{i}" for i in range(5)] + ["victim"],
                  {"expect": {"participants": [f"s{i}" for i in range(5)], "contribution_max": 0.35, "responsibility_min": 0.2}}))


def shooters(c, r, v):
    return rec("shoot", v, [pa(id=f"s{i}", contribution=c, responsibility=r) for i in range(5)] + [pb(id="victim", contribution=0.0, responsibility=0.0)])


def test_overdetermination_separates_the_expected_pattern_from_naive_full_credit():
    right = participation_metrics([shooters(0.2, 0.2, v) for v in range(3)], SHOOT)["overdetermination"]
    naive = participation_metrics([shooters(1.0, 1.0, v) for v in range(3)], SHOOT)["overdetermination"]
    flat = participation_metrics([shooters(0.2, 0.0, v) for v in range(3)], SHOOT)["overdetermination"]
    assert right["pattern_rate"] == 1.0 and naive["pattern_rate"] == 0.0 and flat["pattern_rate"] == 0.0
    assert right["mean_contribution"] == pytest.approx(0.2) and right["mean_responsibility"] == pytest.approx(0.2)
    div = participation_metrics([shooters(0.1, 0.9, v) for v in range(3)], SHOOT)["overdetermination"]
    assert div["mean_divergence"] == pytest.approx(0.8) and div["pattern_rate"] == 1.0
    assert flat["mean_divergence"] == pytest.approx(-0.2)


PAIR_ITEMS = mk_items(("p.a", ["agent", "patient"], {"pair": "surgery_assault", "side": "a"}),
                      ("p.b", ["agent", "patient"], {"pair": "surgery_assault", "side": "b"}))
PAIR = [{"id": "surgery_assault", "a": "a", "b": "b", "should_differ_in": "B", "note": "n"}]


def side(item, **over):
    return [rec(item, v, [pa(**over), pb()]) for v in range(3)]


def test_collision_rate_counts_identical_b_annotations_and_names_the_differing_field():
    same = collisions_b(side("p.a") + side("p.b"), PAIR_ITEMS, PAIR)
    assert same["pairs"] == 1 and same["identical"] == 1 and same["rate"] == 1.0
    split = collisions_b(side("p.a") + side("p.b", under_agreement=None, informed=None, volition="constrained", volition_record="threat"),
                         PAIR_ITEMS, PAIR)
    assert split["identical"] == 0 and split["rate"] == 0.0
    assert split["field_differs"]["under_agreement"] == 1.0 and split["field_differs"]["production"] == 0.0
    assert split["expected_hit"]["rate"] == 1.0
    wrong = collisions_b(side("p.a") + side("p.b", production="consumed"), PAIR_ITEMS, PAIR)
    assert wrong["identical"] == 0 and wrong["expected_hit"]["rate"] == 0.0
    # majority over variants decides: one deviant variant does not split a pair
    maj = side("p.b")
    maj[0] = rec("p.b", 0, [pa(informed=None), pb()])
    assert collisions_b(side("p.a") + maj, PAIR_ITEMS, PAIR)["identical"] == 1


def test_collisions_skip_pairs_without_answers_and_pairs_of_other_kinds():
    assert collisions_b(side("p.a"), PAIR_ITEMS, PAIR)["pairs"] == 0
    other = [dict(PAIR[0], should_differ_in="D")]
    assert collisions_b(side("p.a") + side("p.b"), PAIR_ITEMS, other)["pairs"] == 0


# ---- metrics: events ----
def erec(item, variant, labels, links):
    return {"item": item, "variant": variant,
            "subevents": [{"id": f"e{i + 1}", "label": l} for i, l in enumerate(labels)],
            "links": [{"from": f, "to": t, "type": ty, "confidence": 0.7} for f, t, ty in links]}


def test_matching_of_labels_by_normalised_token_overlap():
    m = match_subevents(["Chops the onions", "Cooks soup for dinner"], ["cook soup dinner", "chopping onions"])
    assert sorted(m) == [(0, 1), (1, 0)]
    assert match_subevents(["wash the car"], ["file a tax return"]) == []
    one = match_subevents(["chop onions", "chop onions again"], ["chop onions"])
    assert len(one) == 1  # one-to-one


EITEMS = mk_items(("s1", ["a"], {}), ("s2", ["a"], {}), ("s3", ["a"], {}))


def test_subevent_count_agreement_and_link_agreement_over_matched_pairs():
    agree = []
    for n, (labels, links) in enumerate([(["make soup", "chop onions"], [(2, 1, "part_of")]),
                                          (["threaten shopkeeper", "hand over cash", "close shop"], [(1, 2, "causes")]),
                                          (["listen podcast", "ride train"], [(1, 2, "concurrent")])]):
        for v in range(3):
            agree.append(erec(f"s{n + 1}", v, [l + (" " if v == 2 else "") for l in labels],
                              [(f"e{a}", f"e{b}", t) for a, b, t in links]))
    m = events_metrics(agree, EITEMS)
    assert m["n_subevents"]["alpha"] == pytest.approx(1.0)
    assert m["link_agreement"]["linked_agree"] == 1.0 and m["link_agreement"]["linked_pairs"] >= 3
    assert m["link_usage"]["part_of"] == pytest.approx(1 / 3) and m["link_usage"]["causes"] == pytest.approx(1 / 3)
    assert m["link_usage"]["re_description"] == 0.0

    clash = []
    types = ["part_of", "causes", "re_description"]
    for n in range(3):
        for v in range(3):
            clash.append(erec(f"s{n + 1}", v, ["make soup", "chop onions"], [("e2", "e1", types[(n + v) % 3])]))
    c = events_metrics(clash, EITEMS)
    assert c["link_agreement"]["linked_agree"] < 0.5
    assert all(c["link_usage"][t] == 1.0 for t in types)


def test_link_direction_matters_for_directed_types_only():
    def run(second):
        return events_metrics([erec("s1", 0, ["alpha step", "beta step"], [("e1", "e2", "causes")]),
                               erec("s1", 1, ["alpha step", "beta step"], [second])], EITEMS)["link_agreement"]["linked_agree"]
    assert run(("e1", "e2", "causes")) == 1.0 and run(("e2", "e1", "causes")) == 0.0
    sym = events_metrics([erec("s1", 0, ["alpha step", "beta step"], [("e1", "e2", "concurrent")]),
                          erec("s1", 1, ["alpha step", "beta step"], [("e2", "e1", "concurrent")])], EITEMS)
    assert sym["link_agreement"]["linked_agree"] == 1.0


def test_d_pairs_report_whether_the_richer_text_gets_more_subevents():
    items = mk_items(("d.a", ["a"], {"pair": "podcast_commute", "side": "a"}), ("d.b", ["a"], {"pair": "podcast_commute", "side": "b"}))
    pairs = [{"id": "podcast_commute", "a": "a", "b": "b", "should_differ_in": "D", "note": "n"}]
    recs = [erec("d.a", v, ["listen podcast", "ride train"], [("e1", "e2", "concurrent")]) for v in range(3)] + \
           [erec("d.b", v, ["ride train"], []) for v in range(3)]
    d = events_metrics(recs, items, pairs)["d_pairs"]
    assert d["pairs"] == 1 and d["richer_has_more"] == 1
    flat = events_metrics([erec("d.a", v, ["ride train"], []) for v in range(3)] + recs[3:], items, pairs)["d_pairs"]
    assert flat["richer_has_more"] == 0


# ---- loading, rendering, the command line ----
def _write(tmp, lines_by_name):
    paths = []
    for name, lines in lines_by_name.items():
        (tmp / name).write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(tmp / name.replace(".jsonl", ".answers.jsonl"))
    return paths


def _answer_files(tmp, batches):
    paths = []
    for tt, bs in batches.items():
        for v, lines in bs.items():
            header = json.loads(lines[0])
            (tmp / f"{tt}.v1.var{v}.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
            ans = []
            for l in lines[1:]:
                t = json.loads(l)
                body = _fill(t)
                if tt == "participation":
                    n = len(body["participants"])
                    for k, e in enumerate(body["participants"]):
                        e["contribution"] = round((0.4 + 0.1 * ((k + v) % 3)) / n, 4)
                ans.append(json.dumps(_answer_line(t, header, body)))
            p = tmp / f"{tt}.v1.var{v}.answers.jsonl"
            p.write_text("\n".join(ans) + "\n", encoding="utf-8")
            paths.append(p)
    return paths


def test_records_load_from_answer_files_and_the_report_renders(tmp_path):
    paths = _answer_files(tmp_path, {"participation": PART, "events": EVT})
    recs = load_bd_records(paths)
    assert len(recs["participation"]) == 3 * len(ITEMS) and len(recs["events"]) == 3 * len(ITEMS)
    r = recs["participation"][0]
    assert {"item", "variant", "participants", "model", "prompt_version"} <= set(r)
    assert set(r["participants"]) == {p["id"] for p in BY_ID[r["item"]]["participants"]}
    assert set(recs["events"][0]) >= {"item", "variant", "subevents", "links"}
    m = compute(recs, ITEMS, load_pairs())
    assert m["participation"]["conservation"]["violations"] == 0 and m["participation"]["answers"] == 3 * len(ITEMS)
    assert m["participation"]["collisions"]["pairs"] == 8
    assert m["events"]["n_subevents"]["alpha"] == 1.0 or math.isnan(m["events"]["n_subevents"]["alpha"])
    md = render(m)
    for h in ("contribution", "responsibility", "conservation", "overdetermination", "collision", "sub-event", "link"):
        assert h in md.lower(), h


def test_a_missing_batch_file_is_an_error(tmp_path):
    p = tmp_path / "participation.v1.var0.answers.jsonl"
    p.write_text("")
    with pytest.raises(FileNotFoundError):
        load_bd_records([p])


def test_command_line_prints_the_report(tmp_path):
    paths = _answer_files(tmp_path, {"participation": PART, "events": EVT})
    out = subprocess.run([sys.executable, str(ROOT / "tools" / "bd_metrics.py"), *map(str, paths)], capture_output=True,
                         text=True, check=True).stdout
    assert "Conservation violations" in out and "Link-type agreement" in out
    assert subprocess.run([sys.executable, str(ROOT / "tools" / "bd_metrics.py")], capture_output=True).returncode != 0


def test_the_builder_tool_writes_all_six_batches(tmp_path):
    out = subprocess.run([sys.executable, str(ROOT / "tools" / "build_battery_bd.py"), "--out", str(tmp_path)],
                         capture_output=True, text=True, check=True).stdout
    names = sorted(p.name for p in tmp_path.iterdir())
    assert names == [f"{t}.v1.var{v}.jsonl" for t in ("events", "participation") for v in range(3)]
    assert str(len(ITEMS)) in out
