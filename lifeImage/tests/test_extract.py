"""The extract task: a persona's resume text and the coarse pack in, claimed-tier evidence rows out."""
import copy
import json
from pathlib import Path

import pytest

from lifeimage.cache import AnswerCache
from lifeimage.extract import (CLAIMED_CONFIDENCE, answer_rows, build_extract_batches, evidence_rows, resume_input,
                               write_extract_batches)
from lifeimage.generators.common import A_RELS
from lifeimage.membership import DEFAULT_PACK, ungrouped_pack
from lifeimage.packs import pack_ids
from lifeimage.validate import ValidationError, validate_answers, validate_evidence, validate_extract_answer

ROOT = Path(__file__).resolve().parent.parent
SYN = ROOT / "data" / "synthetic"
PACK = DEFAULT_PACK.read_text(encoding="utf-8")
IDS = pack_ids(PACK)


def personas():
    return [json.loads(l) for l in (SYN / "personas.jsonl").read_text().splitlines()]


def truth(pid):
    return [json.loads(l) for l in (SYN / "truth" / f"{pid}.jsonl").read_text().splitlines()]


def inputs():
    return [resume_input(p, (SYN / "texts" / f"{p['id']}.resume.txt").read_text()) for p in personas()]


def oracle_answer(task):
    """The answer of an extractor that reads the resume perfectly: the truth's resume rows, compacted."""
    pid = task["input"]["source"].split(":")[1]
    rows = [r for r in truth(pid) if r["provenance"]["source"].startswith("resume")]
    return {"task_id": task["task_id"], "task_type": "extract", "input_hash": task["input_hash"], "variant": task["variant"],
            "model": "haiku-runner", "prompt_version": 1, "verdict": "rows", "rows": answer_rows(rows), "reason": "oracle"}


@pytest.fixture(scope="module")
def batches():
    return build_extract_batches(inputs(), PACK)


@pytest.fixture
def task(batches):
    return json.loads(batches[0][1 + 20])  # a persona with several resume lines


def test_three_variant_batches_one_task_per_persona_in_each(batches):
    assert sorted(batches) == [0, 1, 2]
    for v, lines in batches.items():
        assert len(lines) == 1 + 40
        header = json.loads(lines[0])
        assert header["task_type"] == "extract" and header["prompt_version"] == 1
        tasks = [json.loads(l) for l in lines[1:]]
        assert {t["variant"] for t in tasks} == {v} and all(t["k"] == 3 and t["allowed_verdicts"] == ["rows"] for t in tasks)
    h = lambda v: [json.loads(l)["input_hash"] for l in batches[v][1:]]
    assert h(0) == h(1) == h(2)  # one input per persona, so one cached answer per (persona, variant)


def test_the_variants_differ_only_in_the_order_of_the_pack_in_the_prefix(batches):
    prefixes = [json.loads(batches[v][0])["prefix"] for v in range(3)]
    assert len({p for p in prefixes}) == 3
    for v, p in enumerate(prefixes):
        assert pack_ids(p) == IDS and ungrouped_pack(PACK, v) in p
        assert p.split("# coarse pack")[0] == prefixes[0].split("# coarse pack")[0]


def test_the_prefix_gives_the_contract_the_pack_and_no_resume_text(batches):
    prefix = json.loads(batches[0][0])["prefix"]
    for word in ("form", "content", "outcome", "setting", "span", "magnitude", "valid_time", "causal", "impacted"):
        assert word in prefix
    assert all(p["name"] not in prefix for p in personas())


def test_task_input_numbers_every_nonblank_line_of_the_resume_and_nothing_else(task):
    pid = task["input"]["source"].split(":")[1]
    text = (SYN / "texts" / f"{pid}.resume.txt").read_text()
    want = [" ".join(f"L{n}: {l}".split()) for n, l in enumerate(text.splitlines(), 1) if l.strip()]  # canonical text folds spaces
    assert task["input"]["lines"] == want
    assert set(task["input"]) == {"entity", "source", "as_of", "lines"} and task["input"]["entity"] == f"person:{pid}"


def test_each_file_stays_under_35k_tokens_and_is_written_as_extract_v1_var(batches, tmp_path):
    paths = write_extract_batches(batches, tmp_path)
    assert [p.name for p in paths] == [f"extract.v1.var{v}.jsonl" for v in range(3)]
    for p in paths:
        assert -(-p.stat().st_size // 4) <= 35000


def test_cached_personas_are_skipped(tmp_path):
    ins = inputs()
    first = json.loads(build_extract_batches(ins, PACK)[0][1])
    cache = AnswerCache(tmp_path / "a")
    cache.put_all([{"task_id": first["task_id"], "task_type": "extract", "input_hash": first["input_hash"], "variant": 0,
                    "model": "haiku-runner", "prompt_version": 1, "verdict": "rows", "rows": [], "reason": "r"}])
    again = build_extract_batches(ins, PACK, cache=cache)
    assert len(again[0]) == 1 + 39 and len(again[1]) == 1 + 40


def test_a_perfect_reading_of_every_resume_validates_as_answers(batches):
    for v in range(3):
        answers = [json.dumps(oracle_answer(json.loads(l))) for l in batches[v][1:]]
        assert validate_answers(batches[v], answers) == []


def test_evidence_rows_of_a_perfect_reading_are_valid_claimed_rows_equal_to_the_truth(batches):
    for line in batches[0][1:]:
        t = json.loads(line)
        got = evidence_rows(oracle_answer(t), t["input"], "0.0.0-draft")
        want = [r for r in truth(t["input"]["source"].split(":")[1]) if r["provenance"]["source"].startswith("resume")]
        assert len(got) == len(want)
        for g, w in zip(got, want):
            validate_evidence(g, membership_rels=A_RELS)
            assert g["tier"] == "claimed" and g["confidence"] == CLAIMED_CONFIDENCE and g["record_time"] == t["input"]["as_of"]
            for k in ("entity", "relation", "channel", "sign", "magnitude", "valid_time", "provenance"):
                assert g[k] == w[k], k
            key = lambda ms: sorted((m["rel"], m["domain"], round(m["weight"], 6)) for m in ms)
            assert key(g["memberships"]) == key(w["memberships"])


def test_an_unstated_date_falls_back_to_the_record_month(task):
    a = oracle_answer(task)
    a["rows"][0]["valid_time"] = None
    assert evidence_rows(a, task["input"], "0.0.0-draft")[0]["valid_time"] == task["input"]["as_of"][:7]


def test_an_empty_resume_answer_with_no_rows_is_valid(batches):
    t = next(json.loads(l) for l in batches[0][1:] if not [r for r in truth(json.loads(l)["input"]["source"].split(":")[1])
                                                           if r["provenance"]["source"].startswith("resume")])
    a = oracle_answer(t)
    assert a["rows"] == [] and validate_extract_answer(a, t, IDS) == a


def bad(task, mutate, why):
    a = copy.deepcopy(oracle_answer(task))
    mutate(a)
    with pytest.raises(ValidationError):
        validate_extract_answer(a, task, IDS)


def test_malformed_extractions_are_rejected(task):
    first = lambda a: a["rows"][0]
    bad(task, lambda a: a.update(verdict="membership"), "verdict")
    bad(task, lambda a: a.pop("rows"), "no rows")
    bad(task, lambda a: first(a).update(span="L999"), "span past the text")
    bad(task, lambda a: first(a).update(span="L4"), "span on a blank line")
    bad(task, lambda a: first(a).update(span="12"), "span format")
    bad(task, lambda a: first(a).update(relation="owns"), "relation")
    bad(task, lambda a: first(a).update(channel="negative"), "negative channel is reserved")
    bad(task, lambda a: first(a).update(magnitude=-0.1), "negative magnitude")
    bad(task, lambda a: first(a).update(valid_time="last year"), "valid_time format")
    bad(task, lambda a: first(a)["types"].update(form={"c.not_a_domain": 1.0}), "unknown domain")
    bad(task, lambda a: first(a)["types"].update(content={"c.cooking": 0.3, "c.driving": 0.3}), "weights not 1")
    bad(task, lambda a: first(a)["types"].pop("setting"), "a type missing")
    bad(task, lambda a: first(a)["types"].update(flavour=None), "placebo type")
    bad(task, lambda a: first(a).update(types={"form": None, "content": None, "outcome": None, "setting": None}), "no membership at all")


def test_the_evidence_validator_would_reject_what_the_extractor_may_not_invent(task):
    a = oracle_answer(task)
    rows = evidence_rows(a, task["input"], "0.0.0-draft")
    r = copy.deepcopy(rows[0])
    r["memberships"][0]["weight"] = 0.5
    with pytest.raises(ValidationError):
        validate_evidence(r, membership_rels=A_RELS)
