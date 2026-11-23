"""Confirm v2 (LI.40, LI.41): production required, zero-run flag, prompt v2, the rerun set and the v1-versus-v2
comparison.

Red first on the outcome: against stubs that accept everything, an answer with a contributor of unknown production or
a zero run is accepted, the rerun set is empty and the comparison reports nothing."""
import json
import math
from pathlib import Path

import pytest

from lifeimage.confirm import (build_confirm_batches, load_confirm_items, load_confirm_records, prefix_text,
                               validate_confirm_answers, write_confirm_batches, zero_run_flag)
from lifeimage.confirm_metrics import compare_versions, render_compare
from lifeimage.confirm_rerun import COERCED, load_selfdefence, review_ids, rerun_items
from lifeimage.membership import DEFAULT_PACK, pack_lines
from lifeimage.participation import production_gaps, validate_participation_answer
from lifeimage.validate import ValidationError

ROOT = Path(__file__).resolve().parent.parent
PACK = DEFAULT_PACK.read_text(encoding="utf-8")
DOMS = sorted(l.split(" | ")[0] for l in pack_lines(PACK)[2])
REVIEW = ROOT / "data/gold/review_v1.md"


def entry(pid, contribution=0.0, responsibility=0.0, production=None, impact=(), option_set=None):
    return {"id": pid, "contribution": contribution, "responsibility": responsibility, "impact": list(impact),
            "acting_for": None, "under_agreement": None, "informed": None, "volition": None, "volition_record": None,
            "production": production, "option_set": option_set}


def ben(party, sign=1, magnitude=2):
    return {"party": party, "sign": sign, "magnitude": magnitude}


# ---- production rule (LI.41) ----
def test_a_contributor_with_null_production_is_rejected_in_v2_but_not_in_v1():
    ps = [{"id": "a", "label": "a"}]
    a = {"verdict": "participation", "participants": [entry("a", 0.5, 0.5, None)]}
    with pytest.raises(ValidationError, match="production"):
        validate_participation_answer(a, ps, version=2)
    v1 = {"verdict": "participation", "participants": [{k: v for k, v in entry("a", 0.5, 0.5, None).items() if k != "option_set"}]}
    validate_participation_answer(v1, ps)


def test_a_participant_who_receives_the_output_needs_a_production_value():
    ps = [{"id": "doer", "label": "d"}, {"id": "patient", "label": "p"}]
    doer = entry("doer", 0.9, 0.9, "produced", impact=[ben("patient")])
    for ok_val in ("consumed", "both"):
        validate_participation_answer({"verdict": "participation", "participants": [doer, entry("patient", 0, 0, ok_val)]}, ps, version=2)
    with pytest.raises(ValidationError, match="patient"):
        validate_participation_answer({"verdict": "participation", "participants": [doer, entry("patient", 0, 0, None)]}, ps, version=2)


def test_production_stays_null_for_a_bystander_and_for_one_only_harmed():
    ps = [{"id": "doer", "label": "d"}, {"id": "bystander", "label": "b"}, {"id": "victim", "label": "v"}]
    doer = entry("doer", 0.9, 0.9, "produced", impact=[ben("victim", -1, 3)])
    validate_participation_answer({"verdict": "participation", "participants": [doer, entry("bystander"), entry("victim")]}, ps, version=2)


def test_production_gaps_names_each_participant_missing_a_required_value():
    es = [entry("a", 0.5, 0.5, None, impact=[ben("c")]), entry("b", 0.5, 0.5, "produced"), entry("c", 0, 0, None), entry("d")]
    assert sorted(production_gaps(es)) == ["a", "c"]
    assert production_gaps([entry("d")]) == []


# ---- zero-run flag ----
def ans(outcome, entries):
    return {"types": {"form": None, "content": None, "outcome": outcome, "setting": None, "flavour": None},
            "participants": entries}


def test_zero_run_flags_a_recorded_outcome_where_every_participant_scores_zero():
    assert zero_run_flag(ans({DOMS[0]: 1.0}, [entry("a"), entry("b")]))


@pytest.mark.parametrize("a", [
    ans(None, [entry("a"), entry("b")]),  # no outcome: all zero is the rule
    ans({DOMS[0]: 1.0}, [entry("a", 0.1), entry("b")]),
    ans({DOMS[0]: 1.0}, [entry("a", 0, 0.3), entry("b")]),
])
def test_zero_run_is_not_flagged_when_nothing_is_inconsistent(a):
    assert not zero_run_flag(a)


# ---- prompt v2 ----
def sections(text):
    parts, cur = {}, "head"
    for line in text.splitlines(keepends=True):
        if line.startswith("## "):
            cur = line[3:].strip()
        parts[cur] = parts.get(cur, "") + line
    return parts


def test_prompt_v2_judges_responsibility_by_freedom_and_records_the_option_set():
    t = (ROOT / "prompts/confirm.v2.md").read_text(encoding="utf-8")
    low = " ".join(t.lower().split())
    assert "freedom" in low and "option_set" in t and "at the moment" in low
    assert "self-defence" in low and "less harmful" in low
    assert "production is required" in low
    assert "surgery" in low and "medical care" in low
    assert "only when the text states or implies" in low or "only when the text states or implies it" in low
    assert "chockler" not in low, "v2 replaces the pivotality reading of responsibility with freedom"


def test_prompt_v2_keeps_everything_else_as_v1():
    v1 = sections((ROOT / "prompts/confirm.v1.md").read_text(encoding="utf-8"))
    v2 = sections((ROOT / "prompts/confirm.v2.md").read_text(encoding="utf-8"))
    changed = {"The observed outcome", "A: membership, per relation type", "B: participation, per participant", "Answer"}
    assert set(v1) == set(v2)
    for k in v1:
        if k not in changed:
            assert v1[k] == v2[k], k
    for k in changed:
        assert v1[k] != v2[k], k
    a1 = [l for l in v1["A: membership, per relation type"].splitlines() if l not in v2["A: membership, per relation type"].splitlines()]
    assert all(l.startswith(("- setting", "  ")) for l in a1), "only the setting bullet of A changes"
    assert "{{link_types}}" in v2["D: sub-events and links"]
    assert "validate_confirm_answers" in v2["Answer"]


def test_prefix_text_reads_the_prompt_of_its_version():
    assert "freedom" in prefix_text(0, PACK, prompt_version=2).lower()
    assert "freedom" not in prefix_text(0, PACK).lower()


# ---- rerun set ----
def review_listing():
    text = REVIEW.read_text(encoding="utf-8")
    heads = [l[3:].split(" (")[0] for l in text.splitlines() if l.startswith("## ") and "(disagreements" in l]
    tail = text.split("## Round-trip misses")[1]
    misses = [l[2:].split(":")[0] for l in tail.splitlines() if l.startswith("- ")]
    return heads, misses


def test_review_ids_are_the_disputed_plus_the_round_trip_misses_without_duplicates():
    heads, misses = review_listing()
    ids = review_ids()
    assert len(heads) == 30 and len(misses) >= 7
    assert ids and len(ids) == len(set(ids)) == len(set(heads) | set(misses))
    assert set(ids) == set(heads) | set(misses)


def test_rerun_items_are_the_review_items_unchanged_plus_four_self_defence_items():
    items = {i["id"]: i for i in load_confirm_items()}
    sd = load_selfdefence()
    out = rerun_items()
    ids = review_ids()
    assert len(sd) == 4 and len(out) == len(ids) + 4
    assert sorted(i["id"] for i in out) == sorted(ids + [i["id"] for i in sd])
    for i in out:
        if i["id"] in items:
            assert i == items[i["id"]]
    assert len({i["text"].strip().lower() for i in out}) == len(out)
    assert not {i["id"] for i in sd} & set(items)


def test_self_defence_items_cover_the_four_cases_each_with_a_defender_and_an_expectation():
    sd = load_selfdefence()
    assert sorted(i["case"] for i in sd) == ["ambiguous", "disproportionate", "less_harmful", "no_less_harmful"]
    for i in sd:
        ids = {p["id"] for p in i["participants"]}
        assert {"defender", "attacker"} <= ids and i["source"] == "self_defence"
        assert i["expect_responsibility"]["defender"] in ("low", "high", "open")
    want = {"no_less_harmful": "low", "less_harmful": "high", "disproportionate": "high", "ambiguous": "open"}
    assert {i["case"]: i["expect_responsibility"]["defender"] for i in sd} == want


def test_coerced_items_name_a_listed_participant_of_a_review_item():
    items = {i["id"]: i for i in rerun_items()}
    assert len(COERCED) >= 3
    for iid, pid in COERCED.items():
        assert iid in items and pid in {p["id"] for p in items[iid]["participants"]}


def test_v2_batches_cover_exactly_the_rerun_items_in_three_variants(tmp_path):
    items = rerun_items()
    batches = build_confirm_batches(items, PACK, prompt_version=2)
    assert sorted(batches) == [0, 1, 2]
    paths = write_confirm_batches(batches, tmp_path, prompt_version=2)
    assert [p.name for p in paths] == [f"confirm.v2.var{v}.jsonl" for v in range(3)]
    for v, p in enumerate(paths):
        lines = p.read_text().splitlines()
        h = json.loads(lines[0])
        tasks = [json.loads(l) for l in lines[1:]]
        assert h["task_type"] == "confirm.v2" and h["prompt_version"] == 2 and "freedom" in h["prefix"].lower()
        assert len(tasks) == len(items) and {t["input"]["item"]["id"] for t in tasks} == {i["id"] for i in items}
        assert all(t["task_type"] == "confirm.v2" and t["prompt_version"] == 2 and t["variant"] == v for t in tasks)
    first = [json.loads(l)["input"]["item"]["participants"] for l in paths[0].read_text().splitlines()[1:]]
    other = [json.loads(l)["input"]["item"]["participants"] for l in paths[1].read_text().splitlines()[1:]]
    assert first != other


# ---- v2 answers: validated and read ----
def v2_answer(task, outcome, entries, variant=0):
    return {"task_id": task["task_id"], "task_type": "confirm.v2", "input_hash": task["input_hash"], "variant": variant,
            "model": "haiku-subagent-low", "prompt_version": 2, "verdict": "confirm", "reason": "r",
            "types": {"form": {DOMS[0]: 1.0}, "content": {DOMS[1]: 1.0}, "outcome": outcome, "setting": None,
                      "flavour": None}, "other": None, "participants": entries,
            "subevents": [{"id": "e1", "label": "one step"}], "event_links": []}


def test_v2_validation_rejects_missing_production_and_zero_runs_and_accepts_a_consistent_answer(tmp_path):
    items = [i for i in rerun_items() if i["id"] == "bd.new.coercion"]
    (p,) = write_confirm_batches(build_confirm_batches(items, PACK, k=1, prompt_version=2), tmp_path, prompt_version=2)
    lines = p.read_text().splitlines()
    t = json.loads(lines[1])
    ids = [x["id"] for x in t["input"]["item"]["participants"]]

    def es(**kw):
        return [entry(i, **kw.get(i, {})) for i in ids]

    good = es(robber={"contribution": 0.6, "responsibility": 0.9, "production": "produced"},
              clerk={"contribution": 0.4, "responsibility": 0.1, "production": "produced",
                     "option_set": [{"alternative": "refuse and see her colleague stabbed", "harm": 3}]})
    check = lambda e, outcome={DOMS[2]: 1.0}: validate_confirm_answers(lines, [json.dumps(v2_answer(t, outcome, e))])
    assert check(good) == []
    assert any("production" in m for m in check(es(robber={"contribution": 0.6, "responsibility": 0.9})))
    assert any("zero" in m.lower() for m in check(es()))
    assert check(es()[:0] or es(), outcome=None) == []


def test_v2_records_load_with_the_option_set(tmp_path):
    items = [i for i in rerun_items() if i["id"] == "bd.new.coercion"]
    (p,) = write_confirm_batches(build_confirm_batches(items, PACK, k=1, prompt_version=2), tmp_path, prompt_version=2)
    t = json.loads(p.read_text().splitlines()[1])
    ids = [x["id"] for x in t["input"]["item"]["participants"]]
    a = tmp_path / "confirm.v2.var0.answers.jsonl"
    a.write_text(json.dumps(v2_answer(t, None, [entry(i) for i in ids])) + "\n")
    rec = load_confirm_records([a])
    assert rec["participation"][0]["item"] == "bd.new.coercion" and "option_set" in rec["participation"][0]["participants"][ids[0]]


# ---- comparison v1 versus v2 ----
def records(spec):
    """spec: {item: [(variant, outcome_filled, {pid: entry kwargs})]} -> load_confirm_records-shaped dict."""
    out = {"A": [], "participation": [], "events": []}
    for item, runs in spec.items():
        for variant, filled, ents in runs:
            out["A"].append({"item": item, "variant": variant, "vocab": "A3S", "other": None,
                             "types": {"form": {DOMS[0]: 1.0}, "content": {DOMS[1]: 1.0}, "setting": None, "flavour": None,
                                       "outcome": {DOMS[2]: 1.0} if filled else None}})
            out["participation"].append({"item": item, "variant": variant,
                                         "participants": {p: entry(p, **kw) for p, kw in ents.items()}})
    return out


def test_compare_reports_the_change_on_coercion_self_defence_zero_runs_and_production_nulls():
    sd = load_selfdefence()
    by_case = {i["case"]: i["id"] for i in sd}
    zero = {"tutor": dict(), "learner": dict()}
    full = {"tutor": dict(contribution=0.7, responsibility=0.7, production="produced"),
            "learner": dict(contribution=0.0, responsibility=0.0, production="consumed")}
    v1 = records({
        "bd.new.coercion": [(v, True, {"clerk": dict(contribution=0.4, responsibility=1.0, production=None),
                                       "robber": dict(contribution=0.6, responsibility=1.0, production="produced"),
                                       "colleague": {}}) for v in range(3)],
        "bd.mp.threat_cash.a": [(v, True, {"shopkeeper": dict(contribution=0.4, responsibility=1.0, production="produced"),
                                           "threatener": dict(contribution=0.6, responsibility=1.0, production="produced")})
                                for v in range(3)],
        "cf.tutoring": [(v, True, zero) for v in range(3)],
    })
    v2 = records({
        "bd.new.coercion": [(v, True, {"clerk": dict(contribution=0.4, responsibility=0.1, production="produced"),
                                       "robber": dict(contribution=0.6, responsibility=1.0, production="produced"),
                                       "colleague": {}}) for v in range(3)],
        "bd.mp.threat_cash.a": [(v, True, {"shopkeeper": dict(contribution=0.4, responsibility=0.1, production="produced"),
                                           "threatener": dict(contribution=0.6, responsibility=1.0, production="produced")})
                                for v in range(3)],
        "cf.tutoring": [(v, True, full) for v in range(3)],
        by_case["no_less_harmful"]: [(v, True, {"defender": dict(contribution=0.9, responsibility=0.1, production="produced"),
                                                "attacker": dict(contribution=0.1, responsibility=1.0, production="produced")}) for v in range(3)],
        by_case["less_harmful"]: [(v, True, {"defender": dict(contribution=0.9, responsibility=0.7, production="produced"),
                                             "attacker": dict(contribution=0.1, responsibility=1.0, production="produced")}) for v in range(3)],
    })
    items = rerun_items()
    ids = ["bd.new.coercion", "bd.mp.threat_cash.a", "cf.tutoring"]
    c = compare_versions(v1, v2, items, ids + list(by_case.values()))
    assert c["items"] == 3, "fields compare only items both versions answered"
    co = c["responsibility"]["coercion"]
    assert co["v1"] == pytest.approx(1.0) and co["v2"] == pytest.approx(0.1) and co["items"] == 2
    sdm = c["responsibility"]["self_defence"]
    assert sdm["no_less_harmful"]["v2"] == pytest.approx(0.1) and sdm["less_harmful"]["v2"] == pytest.approx(0.7)
    assert math.isnan(sdm["no_less_harmful"]["v1"]), "self-defence items have no v1 answers"
    assert c["zero_run"]["flagged"]["v1"] == 3 and c["zero_run"]["answers"]["v1"] == 9 and c["zero_run"]["flagged"]["v2"] == 0
    assert c["production"]["v1"]["null"] == 3 and c["production"]["v2"]["null"] == 0
    assert c["production"]["v1"]["required"] == 12 and c["production"]["v2"]["required"] == 15
    for f in ("contribution", "responsibility", "production"):
        assert f in c["fields"] and set(c["fields"][f]) == {"v1", "v2"}


def test_compare_restricts_to_the_listed_items_and_renders_every_section():
    v = records({"bd.new.coercion": [(k, True, {"clerk": dict(contribution=0.4, responsibility=0.5, production="produced")}) for k in range(3)],
                 "cf.tutoring": [(k, False, {"tutor": dict(responsibility=0.5)}) for k in range(3)]})
    c = compare_versions(v, v, rerun_items(), ["bd.new.coercion"])
    assert c["items"] == 1
    md = render_compare(c)
    for head in ("Agreement per field", "Zero runs", "Production", "Responsibility on coercion", "self-defence"):
        assert head in md, head


# ---- the tools ----
def _run(script, *args):
    import subprocess, sys
    return subprocess.run([sys.executable, str(ROOT / "tools" / script), *map(str, args)], capture_output=True, text=True, cwd=ROOT)


def test_build_tool_writes_the_rerun_batches_and_leaves_the_v1_batches_alone(tmp_path):
    r = _run("build_battery_confirm.py", "--rerun", "--out", tmp_path)
    assert r.returncode == 0, r.stderr
    assert sorted(p.name for p in tmp_path.iterdir()) == [f"confirm.v2.var{v}.jsonl" for v in range(3)]
    n = len(rerun_items())
    assert all(len((tmp_path / f"confirm.v2.var{v}.jsonl").read_text().splitlines()) == n + 1 for v in range(3))
    assert f"{n} items" in r.stdout


def test_metrics_tool_compares_two_answer_sets_and_reports_every_section(tmp_path):
    items = [i for i in rerun_items() if i["id"] == "bd.new.coercion"]
    (p,) = write_confirm_batches(build_confirm_batches(items, PACK, k=1, prompt_version=2), tmp_path, prompt_version=2)
    t = json.loads(p.read_text().splitlines()[1])
    es = [entry(x["id"], 0.5, 0.5, "produced") for x in t["input"]["item"]["participants"]]
    es[0]["contribution"] = 0.5
    (tmp_path / "confirm.v2.var0.answers.jsonl").write_text(json.dumps(v2_answer(t, {DOMS[2]: 1.0}, es)) + "\n")
    f = tmp_path / "confirm.v2.var0.answers.jsonl"
    r = _run("confirm_metrics.py", f, "--vs", f)
    assert r.returncode == 0, r.stderr
    for head in ("Agreement per field", "Zero runs", "Production nulls", "Responsibility on coercion and self-defence"):
        assert head in r.stdout
    assert _run("confirm_metrics.py", f, "--vs").returncode != 0
