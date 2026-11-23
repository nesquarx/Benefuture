import json

import pytest

from lifeimage.canonical import content_hash
from lifeimage.gold import accuracy, eligible, eligible_models, load_gold


def gold(n=10):
    return [{"task_type": "relate", "input": {"card": {"id": f"d{i}"}, "candidates": []},
             "expected": "same", "reviewed_by": "author"} for i in range(n)]


def verdicts(g, wrong=0, missing=0):
    out = {}
    for i, item in enumerate(g):
        if i < missing:
            continue
        out[content_hash(item["input"])] = "different" if missing <= i < missing + wrong else item["expected"]
    return out


def test_accuracy_counts_wrong_and_missing_as_misses():
    g = gold()
    assert accuracy(g, verdicts(g)) == 1.0
    assert accuracy(g, verdicts(g, wrong=2)) == 0.8
    assert accuracy(g, verdicts(g, missing=3)) == 0.7


def test_model_serves_only_at_or_above_threshold():
    assert eligible(0.9) and eligible(1.0)
    assert not eligible(0.89)
    assert eligible(0.8, threshold=0.8) and not eligible(0.79, threshold=0.8)


def test_empty_gold_is_not_evidence_of_eligibility():
    assert accuracy([], {}) is None
    assert not eligible(None)


def test_eligible_models_filters_by_accuracy():
    assert eligible_models({"haiku": 0.85, "sonnet": 0.95, "opus": 0.9}) == ["opus", "sonnet"]


def test_load_gold_requires_reviewer_and_fields(tmp_path):
    f = tmp_path / "g.jsonl"
    f.write_text("\n".join(json.dumps(x) for x in gold(2)) + "\n")
    assert len(load_gold(f)) == 2
    unreviewed = dict(gold(1)[0], reviewed_by="")
    f.write_text(json.dumps(unreviewed) + "\n")
    with pytest.raises(ValueError):
        load_gold(f)
    f.write_text(json.dumps({"task_type": "relate"}) + "\n")
    with pytest.raises(ValueError):
        load_gold(f)
