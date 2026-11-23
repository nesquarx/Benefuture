"""Layer D battery (event-event links): the sub-events of a scenario and typed links among them.

Task type `events` v1. A task is one item (text and participants as context); its answer line carries `subevents`
(`{id, label}`) and `event_links` (`{from, to, type, confidence}`, confidence strictly between 0 and 1). Variants
reorder the participants and the order in which the four link types are defined in the prefix, so no variant's
definition order favours a type. The prefix holds no worked answer.

`validate_bd_answers` replaces the generic answer check for both batteries (the generic schema forbids the extra
keys): it checks each line's identity against its task, then the task type's own rules.
"""
import hashlib
import json
from pathlib import Path

from .participation import build_batches, validate_participation_answer
from .tasks import DEFAULT_K, DEFAULT_PROMPTS
from .validate import ValidationError, validate_answer, validate_task

TASK_TYPE = "events"
PROMPT_VERSION = 1
MODEL = "haiku-subagent-low"
MAX_SUBEVENTS = 12
LINK_DEFS = {
    "part_of": "`from` is a component or step of `to` (the whole), within the same occurrence.",
    "causes": "`from` brought about `to`, and happened earlier; a prior threat that makes a hand-over, not a mere sequence.",
    "re_description": ("`from` and `to` are the same occurrence under two descriptions (symmetric), not two occurrences: "
                       "one act that counts as another under a rule or context, such as a signature that counts as a sale."),
    "concurrent": "`from` and `to` are separate occurrences that overlap in time (symmetric); neither causes nor contains the other.",
}
LINK_TYPES = tuple(LINK_DEFS)
SYMMETRIC = frozenset({"re_description", "concurrent"})
EXTRA_KEYS = ("participants", "subevents", "event_links")


def link_types_text(variant):
    """The link-type definitions, one line each, in the variant's fixed order (variant 0: as defined)."""
    order = list(LINK_TYPES) if variant == 0 else sorted(
        LINK_TYPES, key=lambda t: hashlib.sha256(f"{variant}:{t}".encode()).hexdigest())
    return "\n".join(f"- {t}: {LINK_DEFS[t]}" for t in order)


def build_events_batches(items, *, model=MODEL, prompt_version=PROMPT_VERSION, prompts_dir=DEFAULT_PROMPTS,
                         k=DEFAULT_K, cache=None):
    text = (Path(prompts_dir) / f"{TASK_TYPE}.v{prompt_version}.md").read_text(encoding="utf-8").rstrip("\n")
    return build_batches(TASK_TYPE, items, lambda v: text.replace("{{link_types}}", link_types_text(v)), model=model,
                         prompt_version=prompt_version, k=k, cache=cache)


def _nonblank(x):
    return isinstance(x, str) and bool(x.strip())


def validate_events_answer(answer):
    """verdict "events"; 1-MAX_SUBEVENTS sub-events with unique ids and non-blank labels; links between distinct
    known ids with a known type and confidence in (0, 1), no pair repeated for a type (unordered if symmetric)."""
    if answer.get("verdict") != TASK_TYPE:
        raise ValidationError(f"verdict must be {TASK_TYPE!r}, not {answer.get('verdict')!r}")
    subs, links = answer.get("subevents"), answer.get("event_links")
    if not isinstance(subs, list) or not isinstance(links, list):
        raise ValidationError("an events answer needs subevents and event_links lists")
    if not 1 <= len(subs) <= MAX_SUBEVENTS:
        raise ValidationError(f"{len(subs)} sub-events, expected 1-{MAX_SUBEVENTS}")
    ids = set()
    for s in subs:
        if not isinstance(s, dict) or set(s) != {"id", "label"} or not _nonblank(s["id"]) or not _nonblank(s["label"]):
            raise ValidationError(f"a sub-event needs exactly a non-blank id and label, not {s!r}")
        if s["id"] in ids:
            raise ValidationError(f"duplicate sub-event id {s['id']}")
        ids.add(s["id"])
    seen = set()
    for l in links:
        if not isinstance(l, dict) or set(l) != {"from", "to", "type", "confidence"}:
            raise ValidationError(f"a link needs exactly from, to, type and confidence, not {l!r}")
        if l["from"] not in ids or l["to"] not in ids:
            raise ValidationError(f"link {l['from']}->{l['to']} names an unknown sub-event")
        if l["from"] == l["to"]:
            raise ValidationError(f"{l['from']}: a sub-event cannot link to itself")
        if l["type"] not in LINK_TYPES:
            raise ValidationError(f"link type {l['type']!r} is not in {LINK_TYPES}")
        c = l["confidence"]
        if isinstance(c, bool) or not isinstance(c, (int, float)) or not 0 < c < 1:
            raise ValidationError(f"confidence must be strictly between 0 and 1, not {c!r}")
        pair = frozenset((l["from"], l["to"])) if l["type"] in SYMMETRIC else (l["from"], l["to"])
        if (pair, l["type"]) in seen:
            raise ValidationError(f"duplicate {l['type']} link between {l['from']} and {l['to']}")
        seen.add((pair, l["type"]))
    return answer


def validate_bd_answers(batch_lines, answer_lines, conservation=True):
    """Errors (empty when valid) of a participation or events answers file against its batch file: exactly one
    well-formed answer per task, echoing the task's identity, with its type's own rules satisfied."""
    errors = []
    header = json.loads(batch_lines[0])
    tt = header["task_type"]
    if tt not in (TASK_TYPE, "participation"):
        return [f"task type {tt!r} is not a participation or events battery"]
    tasks = {}
    for line in batch_lines[1:]:
        t = validate_task(json.loads(line))
        tasks[t["task_id"]] = t
    seen = set()
    for n, line in enumerate(answer_lines, 1):
        try:
            a = json.loads(line)
            validate_answer({k: v for k, v in a.items() if k not in EXTRA_KEYS})
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
        try:
            if tt == TASK_TYPE:
                validate_events_answer(a)
            else:
                validate_participation_answer(a, t["input"]["item"]["participants"], conservation)
        except (ValidationError, KeyError, TypeError, AttributeError) as e:
            errors.append(f"line {n}: {e}")
    for missing in sorted(set(tasks) - seen):
        errors.append(f"missing answer for {missing}")
    return errors
