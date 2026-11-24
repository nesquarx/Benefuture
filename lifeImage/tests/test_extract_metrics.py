"""The extraction scorer, judged by outcome: a perfect reading scores perfectly, and each way to read badly (nothing,
the wrong domains, parents only, shifted lines, inflated sizes, invented rows) scores badly in the measure it harms."""
import copy
import importlib.util
import json
from pathlib import Path

import pytest

from lifeimage.extract import answer_rows, build_extract_batches, evidence_rows, resume_input
from lifeimage.extract_metrics import CHANNELS, compute, compute_variants, corroborated_magnitudes, load_synthetic, render

ROOT = Path(__file__).resolve().parent.parent
CARDS = [json.loads(l) for l in (ROOT / "data/coarse/seed_v2.jsonl").read_text().splitlines()]
UP = {c["id"]: [l["id"] for l in c["links"] if l["rel"] == "upstream"] for c in CARDS}
FIELDS = [c["id"] for c in CARDS if not c["id"].startswith("s.")]


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def world():
    return load_synthetic(ROOT / "data" / "synthetic")


def resume_rows(truth):
    return {p: [copy.deepcopy(r) for r in rows if r["provenance"]["source"].startswith("resume")] for p, rows in truth.items()}


def score(world, extracted):
    personas, truth, _texts, corro = world
    return compute(extracted, truth, personas, CARDS, corro)


def mapped(rows, f):
    for per in rows.values():
        for r in per:
            f(r)
    return rows


def test_a_perfect_reading_scores_perfectly_in_every_channel_with_data(world):
    rep = score(world, resume_rows(world[1]))
    assert rep["personas"] == 40 and rep["rows"]["extracted"] == rep["rows"]["truth_resume"] == 340
    for c in ("expertise", "impact"):
        m = rep["channels"][c]
        assert m["precision"] == m["recall"] == m["precision_near"] == m["recall_near"] == 1.0
        assert m["magnitude_mae"] == pytest.approx(0) and m["magnitude_bias"] == pytest.approx(0) and m["matched"] > 300
        assert m["projection_corr"] == pytest.approx(1.0)


def test_what_a_resume_cannot_evidence_is_the_coverage_gap_and_caps_recall_and_projection(world):
    rep = score(world, resume_rows(world[1]))
    for c in ("expertise", "impact"):
        m = rep["channels"][c]
        assert 0.3 < m["coverage_gap"] < 0.9  # most claimed rows come from the diary and the self-description
        assert m["recall_all"] == pytest.approx(1 - m["coverage_gap"], abs=0.1)  # units against rows
        assert m["projection_corr_all"] < m["projection_corr"] - 0.1
    p = rep["channels"]["potential"]  # a resume states no self-assessed potential: nothing to recall
    assert p["coverage_gap"] == 1.0 and p["recall"] is None


def test_nothing_extracted_recalls_nothing(world):
    rep = score(world, {p: [] for p in world[1]})
    for c in ("expertise", "impact"):
        m = rep["channels"][c]
        assert m["recall"] == 0.0 and m["recall_near"] == 0.0 and m["precision"] is None and m["matched"] == 0
        assert m["projection_corr"] == 0.0


def test_invented_rows_cost_precision_not_recall(world):
    ex = resume_rows(world[1])
    for p, per in ex.items():
        for n, r in enumerate(list(per)):
            junk = copy.deepcopy(r)
            junk["provenance"]["span"] = f"L{1000 + n}"
            per.append(junk)
    m = score(world, ex)["channels"]["expertise"]
    assert m["recall"] == 1.0 and m["precision"] == pytest.approx(0.5, abs=0.01)


def test_lines_off_by_one_lose_most_of_the_credit(world):
    ex = mapped(resume_rows(world[1]), lambda r: r["provenance"].update(span=f"L{int(r['provenance']['span'][1:]) + 1}"))
    m = score(world, ex)["channels"]["expertise"]
    assert m["recall"] < 0.4 and m["precision"] < 0.4  # neighbouring lines often share a domain, so not all is lost


def test_random_domains_are_neither_exact_nor_near(world):
    def swap(r):
        k = sum(map(ord, r["provenance"]["span"] + r["entity"]))
        for i, mem in enumerate(r["memberships"]):
            mem["domain"] = FIELDS[(k * 31 + i * 17) % len(FIELDS)]
    m = score(world, mapped(resume_rows(world[1]), swap))["channels"]["expertise"]
    assert m["precision"] < 0.1 and m["recall"] < 0.1 and m["precision_near"] < 0.3 and m["recall_near"] < 0.3


def test_upstream_parents_are_near_but_not_exact(world):
    def lift(r):
        for mem in r["memberships"]:
            mem["domain"] = UP[mem["domain"]][0] if UP.get(mem["domain"]) else mem["domain"]
    m = score(world, mapped(resume_rows(world[1]), lift))["channels"]["expertise"]
    assert m["precision"] < 0.25 and m["precision_near"] > 0.95 and m["recall_near"] > 0.95


def test_a_flat_overstatement_shows_as_magnitude_bias_and_inflation(world):
    base = score(world, resume_rows(world[1]))["channels"]["expertise"]
    m = score(world, mapped(resume_rows(world[1]), lambda r: r.update(magnitude=r["magnitude"] + 0.3)))["channels"]["expertise"]
    assert m["magnitude_bias"] == pytest.approx(0.3, abs=1e-6) and m["magnitude_mae"] == pytest.approx(0.3, abs=1e-6)
    assert m["inflation"]["overall"] > base["inflation"]["overall"] + 0.2
    assert all(m["inflation"][k] > base["inflation"][k] + 0.1 for k in ("over", "under", "well"))


def test_inflation_against_the_corroborated_size_follows_the_persona_calibration(world):
    infl = score(world, resume_rows(world[1]))["channels"]["expertise"]["inflation"]
    assert infl["n"] > 100
    assert infl["over"] > 0.1 and infl["under"] < -0.05 and abs(infl["well"]) < 0.08  # the claims of the truth carry the persona's bias


def test_claimed_potential_is_compared_with_the_latent_truth_by_calibration(world):
    personas, truth, _t, corro = world
    pot = {p: [copy.deepcopy(r) for r in rows if r["channel"] == "prediction"] for p, rows in truth.items()}
    rep = compute(pot, truth, personas, CARDS, corro)["channels"]["potential"]
    assert rep["inflation"]["n"] > 400
    assert rep["inflation"]["over"] > 0.1 and rep["inflation"]["under"] < -0.1 and abs(rep["inflation"]["well"]) < 0.08
    assert rep["precision"] == 0.0  # nothing in the resume says it


def test_corroborated_sizes_come_from_attested_and_measured_rows_of_the_same_event(world):
    personas, truth, _t, corro = world
    assert 100 < len(corro) < 340
    rows, events = {}, {}
    for l in (ROOT / "data/synthetic/rows.jsonl").read_text().splitlines():
        r = json.loads(l)
        rows.setdefault(r["entity"], []).append(r)
    import gzip
    for l in gzip.open(ROOT / "data/synthetic/events.jsonl.gz", "rt"):
        e = json.loads(l)
        events.setdefault(e["entity"], []).append(e)
    assert corroborated_magnitudes(rows, events) == corro
    (pid, span), v = sorted(corro.items())[0]
    claimed = next(r for r in truth[pid] if r["provenance"] == {"source": f"resume:{pid}", "span": span})
    assert v > 0 and v != claimed["magnitude"]


def test_mean_over_variants_ignores_undefined_values(world):
    full = score(world, resume_rows(world[1]))
    empty = score(world, {p: [] for p in world[1]})
    mean = compute_variants([full, empty])
    m = mean["channels"]["expertise"]
    assert m["recall"] == pytest.approx(0.5) and m["precision"] == 1.0  # precision undefined in the empty variant
    assert mean["variants"] == 2


def test_the_report_names_every_measure_and_channel(world):
    text = render(compute_variants([score(world, resume_rows(world[1]))])).lower()
    for word in ("precision", "recall", "within one link", "magnitude", "inflation", "over", "under", "well", "coverage", "projected",
                 *CHANNELS):
        assert word in text


def test_the_score_tool_checks_answers_then_scores_the_valid_ones(world, tmp_path, capsys):
    tool = load_tool("extract_score")
    personas, truth, texts, _ = world
    ins = [resume_input(p, texts[p["id"]]) for p in sorted(personas.values(), key=lambda p: p["id"])]
    pack = (ROOT / "data/packs/coarse.0.0.0-draft.txt").read_text()
    batches = build_extract_batches(ins, pack)
    files = []
    for v, lines in batches.items():
        (tmp_path / f"extract.v1.var{v}.jsonl").write_text("\n".join(lines) + "\n")
        answers = []
        for l in lines[1:]:
            t = json.loads(l)
            pid = t["input"]["source"].split(":")[1]
            rows = [r for r in truth[pid] if r["provenance"]["source"].startswith("resume")]
            answers.append({"task_id": t["task_id"], "task_type": "extract", "input_hash": t["input_hash"], "variant": v,
                            "model": "haiku-runner", "prompt_version": 1, "verdict": "rows", "rows": answer_rows(rows), "reason": "r"})
        if v == 2:
            answers[0]["rows"] = [{"span": "L1"}]  # malformed: the tool reports it and scores the rest
        f = tmp_path / f"extract.v1.var{v}.answers.jsonl"
        f.write_text("".join(json.dumps(a) + "\n" for a in answers))
        files.append(str(f))
    rc = tool.main(files)
    out = capsys.readouterr().out
    assert rc == 0 and "var2: 1 invalid answer" in out and "var0: 0 invalid" in out
    assert "expertise" in out and "recall" in out
