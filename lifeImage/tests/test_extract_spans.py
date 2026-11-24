"""Extraction scored on the realistic texts (texts_v2), judged by outcome: rows are matched by the lines of the v2 text that
render them, so a perfect reading of a v2 resume scores 1, and the v1 spans (the templated lines) cannot do that.
Without spans, a fallback matches by domain within one link and year within one, reported on its own."""
import copy
import importlib.util
import json
from pathlib import Path

import pytest

from lifeimage.extract_metrics import compute, load_synthetic

ROOT = Path(__file__).resolve().parent.parent
SYN = ROOT / "data" / "synthetic"
CARDS = [json.loads(l) for l in (ROOT / "data/coarse/seed_v2.jsonl").read_text().splitlines()]


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def v1():
    return load_synthetic(SYN)


@pytest.fixture(scope="module")
def v2():
    return load_synthetic(SYN, "texts_v2")


def perfect_v2_reading(v1_world):
    """The resume rows as a perfect reader of the v2 resume reports them: each row on the line that renders it, taken from
    the generator's own row-index spans (<id>.spans.json), not from truth_spans.jsonl."""
    _p, truth, _t, _c = v1_world
    rows = {}
    for pid, per in truth.items():
        allrows = [json.loads(l) for l in (SYN / "rows.jsonl").read_text().splitlines() if f'"person:{pid}"' in l]
        by_idx = json.loads((SYN / "texts_v2" / f"{pid}.spans.json").read_text())["spans"]["resume"]
        out = []
        for r in per:
            if not r["provenance"]["source"].startswith("resume:"):
                continue
            r2 = copy.deepcopy(r)
            r2["provenance"]["span"] = f"L{by_idx[str(allrows.index(r))]}"
            out.append(r2)
        rows[pid] = out
    return rows


def test_a_perfect_reading_of_the_v2_resumes_scores_one_against_the_v2_spans(v1, v2):
    personas, truth, _t, corro = v2
    reading = perfect_v2_reading(v1)
    rep = compute(reading, truth, personas, CARDS, corro)
    for c in ("expertise", "impact"):
        ch = rep["channels"][c]
        assert ch["precision"] == 1 and ch["recall"] == 1, (c, ch["precision"], ch["recall"])
        assert ch["precision_near"] == 1 and ch["recall_near"] == 1


def test_the_v1_spans_cannot_score_a_v2_reading_that_the_v2_spans_score_perfectly(v1):
    personas, truth, _t, corro = v1
    rep = compute(perfect_v2_reading(v1), truth, personas, CARDS, corro)
    assert rep["channels"]["expertise"]["precision"] < 0.5 and rep["channels"]["expertise"]["recall"] < 0.5


def test_every_truth_row_has_a_spans_record_and_the_resume_rows_have_lines(v2):
    _p, truth, _t, _c = v2
    recs = [json.loads(l) for l in (SYN / "texts_v2" / "truth_spans.jsonl").read_text().splitlines()]
    n = sum(len([l for l in (SYN / "truth" / f"{pid}.jsonl").read_text().splitlines() if l.strip()]) for pid in truth)
    assert len(recs) == n
    for r in recs:
        if r["source"].startswith("resume:"):
            assert r["spans"] and all(s.startswith("L") for s in r["spans"])


def test_the_fallback_finds_rows_on_the_wrong_lines_and_the_span_match_does_not(v1, v2):
    personas, truth, _t, corro = v2
    shifted = perfect_v2_reading(v1)
    for per in shifted.values():
        for r in per:
            r["provenance"]["span"] = "L999"
    rep = compute(shifted, truth, personas, CARDS, corro)["channels"]["expertise"]
    assert rep["precision"] == 0 and rep["recall"] == 0
    assert rep["precision_nospan"] == 1 and rep["recall_nospan"] == 1


def test_the_fallback_ignores_other_years_and_unrelated_domains(v1, v2):
    personas, truth, _t, corro = v2
    far = perfect_v2_reading(v1)
    for per in far.values():
        for r in per:
            r["valid_time"] = str(int(r["valid_time"][:4]) + 5) + r["valid_time"][4:]
    rep = compute(far, truth, personas, CARDS, corro)["channels"]["expertise"]
    assert rep["precision_nospan"] < 0.3 and rep["recall_nospan"] < 0.3


def test_the_score_tool_takes_texts_v2_and_a_perfect_v2_answer_set_scores_one(v1, tmp_path, capsys):
    from lifeimage.extract import answer_rows, build_extract_batches, resume_input
    tool = load_tool("extract_score")
    personas = v1[0]
    reading = perfect_v2_reading(v1)
    ins = [resume_input(p, (SYN / "texts_v2" / f"{p['id']}.resume.txt").read_text()) for p in sorted(personas.values(), key=lambda p: p["id"])]
    batches = build_extract_batches(ins, (ROOT / "data/packs/coarse.0.0.0-draft.txt").read_text())
    files = []
    for v, lines in batches.items():
        (tmp_path / f"extract.v1.var{v}.jsonl").write_text("\n".join(lines) + "\n")
        answers = []
        for l in lines[1:]:
            t = json.loads(l)
            pid = t["input"]["source"].split(":")[1]
            answers.append({"task_id": t["task_id"], "task_type": "extract", "input_hash": t["input_hash"], "variant": v,
                            "model": "haiku-runner", "prompt_version": 1, "verdict": "rows", "rows": answer_rows(reading[pid]), "reason": "r"})
        f = tmp_path / f"extract.v1.var{v}.answers.jsonl"
        f.write_text("".join(json.dumps(a) + "\n" for a in answers))
        files.append(str(f))
    assert tool.main(["--texts", "texts_v2", *files]) == 0
    out = capsys.readouterr().out
    expertise = [l for l in out.splitlines() if l.startswith("| precision (exact domain)")][0]
    assert "1.000" in expertise.split("|")[2]
    tool.main(files)  # the v1 default on the same answers cannot match them
    out = capsys.readouterr().out
    assert "1.000" not in [l for l in out.splitlines() if l.startswith("| precision (exact domain)")][0].split("|")[2]
