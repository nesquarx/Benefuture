"""Gold sets and model eligibility.

A gold case is {task_type, input, expected, reviewed_by}. A model serves a task type only while its accuracy on
the gold set is at least the threshold (governed; default 0.9). No gold, no eligibility.
"""
import json
from pathlib import Path

from .canonical import content_hash

DEFAULT_THRESHOLD = 0.9  # governed
FIELDS = ("task_type", "input", "expected", "reviewed_by")


def load_gold(path):
    items = []
    for n, line in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        g = json.loads(line)
        missing = [f for f in FIELDS if f not in g]
        if missing:
            raise ValueError(f"{path}:{n}: missing {missing}")
        if not str(g["reviewed_by"]).strip():
            raise ValueError(f"{path}:{n}: gold must be reviewed")
        items.append(g)
    return items


def accuracy(gold, verdicts):
    """Share of gold cases whose verdict (by input hash) matches; a missing verdict is a miss. None if no gold."""
    if not gold:
        return None
    return sum(verdicts.get(content_hash(g["input"])) == g["expected"] for g in gold) / len(gold)


def eligible(acc, threshold=DEFAULT_THRESHOLD):
    return acc is not None and acc >= threshold


def eligible_models(accuracies, threshold=DEFAULT_THRESHOLD):
    return sorted(m for m, a in accuracies.items() if eligible(a, threshold))
