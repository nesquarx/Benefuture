"""Schema validation plus the rules JSON Schema cannot state (weights summing to one, tombstone successors,
answers matching their task)."""
import json
import math
from functools import lru_cache
from pathlib import Path

from jsonschema import Draft202012Validator

SCHEMA_DIR = Path(__file__).resolve().parent.parent / "schemas"
WEIGHT_TOL = 1e-6


class ValidationError(ValueError):
    pass


@lru_cache(maxsize=None)
def _validator(name):
    schema = json.loads((SCHEMA_DIR / f"{name}.schema.json").read_text())
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema)


def _schema(name, obj):
    errs = sorted(_validator(name).iter_errors(obj), key=lambda e: list(e.path))
    if errs:
        e = errs[0]
        raise ValidationError(f"{name}: {'/'.join(map(str, e.path)) or '<root>'}: {e.message}")


def _sums_to_one(refs, what, key="weight"):
    total = math.fsum(r[key] for r in refs)
    if abs(total - 1.0) > WEIGHT_TOL:
        raise ValidationError(f"{what} weights sum to {total}, not 1")


def validate_card(card):
    _schema("card", card)
    if card["parents"]:
        _sums_to_one(card["parents"], "parents")
    if (card["status"] == "tombstone") != bool(card["successors"]):
        raise ValidationError("successors are required exactly when status is tombstone")
    if card["successors"]:
        _sums_to_one(card["successors"], "successors")
    return card


def validate_evidence(row, allow_negative=False):
    _schema("evidence", row)
    _sums_to_one(row["domains"], "domains")
    if (row["channel"] == "negative") != (row["sign"] == -1):
        raise ValidationError("sign is -1 exactly when the channel is negative")
    if row["channel"] == "negative" and not allow_negative:
        raise ValidationError("the negative channel is reserved")
    return row


def validate_task(task):
    _schema("task", task)
    return task


def validate_answer(answer):
    _schema("answer", answer)
    if "weights" in answer:
        _sums_to_one([{"weight": w} for w in answer["weights"].values()], "answer")
    return answer


def validate_answers(batch_lines, answer_lines):
    """Errors (empty when valid) of an answers file against its batch file: exactly one well-formed answer per
    task, echoing the task's identity, with a verdict from its allowed set."""
    errors = []
    header = json.loads(batch_lines[0])
    tasks = {}
    for line in batch_lines[1:]:
        t = validate_task(json.loads(line))
        tasks[t["task_id"]] = t
    seen = set()
    for n, line in enumerate(answer_lines, 1):
        try:
            a = validate_answer(json.loads(line))
        except (ValueError, ValidationError) as e:
            errors.append(f"line {n}: {e}")
            continue
        t = tasks.get(a["task_id"])
        if t is None:
            errors.append(f"line {n}: unknown task_id {a['task_id']}")
            continue
        if a["task_id"] in seen:
            errors.append(f"line {n}: duplicate answer for {a['task_id']}")
        seen.add(a["task_id"])
        for f in ("task_type", "input_hash", "variant", "prompt_version"):
            if a[f] != t[f]:
                errors.append(f"line {n}: {f} {a[f]!r} differs from the task's {t[f]!r}")
        if a["model"] != header["model"]:
            errors.append(f"line {n}: model {a['model']!r} differs from the batch's {header['model']!r}")
        if a["verdict"] not in t["allowed_verdicts"]:
            errors.append(f"line {n}: verdict {a['verdict']!r} not in {t['allowed_verdicts']}")
    for missing in sorted(set(tasks) - seen):
        errors.append(f"missing answer for {missing}")
    return errors
