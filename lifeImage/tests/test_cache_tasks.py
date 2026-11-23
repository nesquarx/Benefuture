import json

import pytest

from lifeimage.cache import AnswerCache
from lifeimage.tasks import build_batches, merge_answers
from lifeimage.validate import validate_answers

from conftest import make_card

PREFIX = "# Task relate\nDecide the relation. Answer with one verdict.\n"


@pytest.fixture
def prompts(tmp_path):
    d = tmp_path / "prompts"
    d.mkdir()
    (d / "relate.v1.md").write_text(PREFIX)
    return d


def items(n=4, group="sector1"):
    out = []
    for i in range(n):
        cands = [make_card(f"c{i}.{j}", label=f"Cand {i} {j}") for j in range(5)]
        out.append({"card": make_card(f"d{i}", label=f"Domain {i}"), "candidates": cands, "group": group})
    return out


def build(its, cache, prompts, **kw):
    return build_batches("relate", its, cache=cache, model="haiku", prompt_version=1, prompts_dir=prompts, **kw)


def tasks_of(batches):
    return [json.loads(l) for b in batches for l in b.lines[1:]]


def run_runner(batches, cache, verdict_for=lambda t: "same"):
    answers = []
    for t in tasks_of(batches):
        answers.append(
            {
                "task_id": t["task_id"],
                "task_type": t["task_type"],
                "input_hash": t["input_hash"],
                "variant": t["variant"],
                "model": "haiku",
                "prompt_version": t["prompt_version"],
                "verdict": verdict_for(t),
                "reason": "test",
            }
        )
    cache.put_all(answers)
    return answers


def test_k_variants_per_item_default_three(tmp_path, prompts):
    b = build(items(2), AnswerCache(tmp_path / "a"), prompts)
    ts = tasks_of(b)
    assert len(ts) == 2 * 3
    assert {t["variant"] for t in ts} == {0, 1, 2}


def test_batch_has_one_static_prefix_first(tmp_path, prompts):
    b = build(items(3), AnswerCache(tmp_path / "a"), prompts)[0]
    header = json.loads(b.lines[0])
    assert header["kind"] == "header" and header["prefix"] == PREFIX and header["model"] == "haiku"
    assert all(json.loads(l)["kind"] == "task" for l in b.lines[1:])
    assert PREFIX not in "".join(b.lines[1:])


def test_groups_get_their_own_batch_and_size_is_capped(tmp_path, prompts):
    its = items(2, "s1") + items(2, "s2")
    for i, it in enumerate(its):
        it["card"]["id"] = f"x{i}"
    b = build(its, AnswerCache(tmp_path / "a"), prompts)
    assert len(b) == 2
    b2 = build(its, AnswerCache(tmp_path / "a"), prompts, max_tasks=4)
    assert all(len(x.lines) - 1 <= 4 for x in b2) and len(b2) == 4


def test_variants_permute_candidates_deterministically(tmp_path, prompts):
    ts = tasks_of(build(items(1), AnswerCache(tmp_path / "a"), prompts))
    orders = [tuple(c["id"] for c in t["input"]["candidates"]) for t in ts]
    assert orders[0] == tuple(sorted(orders[0]))
    assert len(set(orders)) >= 2
    again = tasks_of(build(items(1), AnswerCache(tmp_path / "b"), prompts))
    assert again == ts


def test_unchanged_cards_produce_zero_new_tasks(tmp_path, prompts):
    cache = AnswerCache(tmp_path / "a")
    its = items(4)
    run_runner(build(its, cache, prompts), cache)
    assert build(its, cache, prompts) == []
    # a fresh cache object over the same files (new container) also hits
    assert build(its, AnswerCache(tmp_path / "a"), prompts) == []


def test_volatile_changes_still_hit_but_real_changes_miss(tmp_path, prompts):
    cache = AnswerCache(tmp_path / "a")
    its = items(2)
    run_runner(build(its, cache, prompts), cache)
    its[0]["card"]["provenance"] = {"label": {"source": "other", "confidence": 0.1}}
    assert build(its, cache, prompts) == []
    its[0]["card"]["label"] = "Renamed"
    assert len(tasks_of(build(its, cache, prompts))) == 3


def test_model_and_prompt_version_are_part_of_the_key(tmp_path, prompts):
    cache = AnswerCache(tmp_path / "a")
    its = items(1)
    run_runner(build(its, cache, prompts), cache)
    other = build_batches("relate", its, cache=cache, model="sonnet", prompt_version=1, prompts_dir=prompts)
    assert len(tasks_of(other)) == 3
    (prompts / "relate.v2.md").write_text("v2")
    v2 = build_batches("relate", its, cache=cache, model="haiku", prompt_version=2, prompts_dir=prompts)
    assert len(tasks_of(v2)) == 3


def test_partial_cache_only_builds_missing_variants(tmp_path, prompts):
    cache = AnswerCache(tmp_path / "a")
    its = items(1)
    answers = run_runner(build(its, cache, prompts), cache)
    cache2 = AnswerCache(tmp_path / "b")
    cache2.put_all([a for a in answers if a["variant"] != 1])
    ts = tasks_of(build(its, cache2, prompts))
    assert [t["variant"] for t in ts] == [1]


def test_missing_prompt_file_fails_loudly(tmp_path):
    with pytest.raises(FileNotFoundError):
        build_batches("relate", items(1), cache=AnswerCache(tmp_path / "a"), model="haiku", prompt_version=9,
                      prompts_dir=tmp_path)


def test_cache_is_committed_jsonl_and_never_overwritten(tmp_path, prompts):
    cache = AnswerCache(tmp_path / "a")
    answers = run_runner(build(items(1), cache, prompts), cache)
    f = tmp_path / "a" / "relate.jsonl"
    assert len(f.read_text().splitlines()) == 3
    cache.put_all(answers)  # duplicates are not appended
    assert len(f.read_text().splitlines()) == 3
    changed = dict(answers[0], verdict="different")
    cache.put_all([changed])
    assert len(f.read_text().splitlines()) == 3
    assert AnswerCache(tmp_path / "a").get("relate", answers[0]["input_hash"], "haiku", 1)[0]["verdict"] == "same"


def test_hit_rate_reported(tmp_path, prompts):
    cache = AnswerCache(tmp_path / "a")
    its = items(2)
    build(its, cache, prompts)
    assert cache.hit_rate() == 0.0
    run_runner(build(its, cache, prompts), cache)
    build(its, cache, prompts)
    assert 0.0 < cache.hit_rate() < 1.0


def votes(task_ids_verdicts):
    out = []
    for i, v in enumerate(task_ids_verdicts):
        out.append({"task_id": f"h-v{i}", "task_type": "relate", "input_hash": "h", "variant": i, "model": "haiku",
                    "prompt_version": 1, "verdict": v, "reason": "r"})
    return out


def test_merge_unanimous(tmp_path):
    log = tmp_path / "esc.jsonl"
    m = merge_answers(votes(["same"] * 3), k=3, log_path=log)
    assert m[0].verdict == "same" and m[0].credence == 1.0 and not m[0].escalate
    assert not log.exists()


def test_merge_majority_lists_disagreement_and_logs(tmp_path):
    log = tmp_path / "esc.jsonl"
    m = merge_answers(votes(["same", "same", "different"]), k=3, log_path=log)
    assert m[0].verdict == "same" and abs(m[0].credence - 2 / 3) < 1e-9 and m[0].escalate
    rec = json.loads(log.read_text().splitlines()[0])
    assert rec["input_hash"] == "h" and rec["votes"] == {"0": "same", "1": "same", "2": "different"}


def test_merge_split_vote_has_no_verdict_and_missing_votes_escalate(tmp_path):
    log = tmp_path / "esc.jsonl"
    m = merge_answers(votes(["same", "different", "overlapping"]), k=3, log_path=log)
    assert m[0].verdict is None and m[0].escalate
    m2 = merge_answers(votes(["same", "same"]), k=3, log_path=log)
    assert m2[0].escalate and m2[0].verdict == "same" and abs(m2[0].credence - 2 / 3) < 1e-9
    assert len(log.read_text().splitlines()) == 2


def test_validator_accepts_runner_output_and_rejects_bad_output(tmp_path, prompts):
    cache = AnswerCache(tmp_path / "a")
    b = build(items(1), cache, prompts)[0]
    good = [json.dumps(a) for a in run_runner([b], cache)]
    assert validate_answers(b.lines, good) == []
    ids = json.loads(good[0])
    cases = {
        "missing": good[:-1],
        "duplicate": good + [good[0]],
        "not json": good[:-1] + ["{oops"],
        "bad verdict": good[:-1] + [json.dumps(dict(json.loads(good[-1]), verdict="maybe"))],
        "wrong hash": good[:-1] + [json.dumps(dict(json.loads(good[-1]), input_hash="zzz"))],
        "wrong model": good[:-1] + [json.dumps(dict(json.loads(good[-1]), model="opus"))],
        "unknown task": good + [json.dumps(dict(ids, task_id="nope"))],
    }
    for name, lines in cases.items():
        assert validate_answers(b.lines, lines), name
