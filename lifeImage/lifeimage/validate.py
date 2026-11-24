"""Schema validation plus the rules JSON Schema cannot state (upstream link weights and membership weights per
relation summing to one, vocabularies, tombstone successors, answers matching their task)."""
import json
import math
import re
from functools import lru_cache
from pathlib import Path

from jsonschema import Draft202012Validator

from .membership import VOCABS, real_types
from .packs import pack_ids
from .vocab import EVENT_RELATIONS, LINK_RELS, MEMBERSHIP_RELS, UPSTREAM

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


def validate_card(card, link_rels=LINK_RELS):
    _schema("card", card)
    seen = set()
    for l in card["links"]:
        if l["rel"] not in link_rels:
            raise ValidationError(f"link rel {l['rel']!r} is not in {sorted(link_rels)}")
        if l["id"] == card["id"]:
            raise ValidationError(f"{card['id']}: a domain cannot link to itself")
        if (l["id"], l["rel"]) in seen:
            raise ValidationError(f"{card['id']}: duplicate {l['rel']} link to {l['id']}")
        seen.add((l["id"], l["rel"]))
    upstream = [l for l in card["links"] if l["rel"] == UPSTREAM]
    if upstream:
        _sums_to_one(upstream, "upstream link")
    if (card["status"] == "tombstone") != bool(card["successors"]):
        raise ValidationError("successors are required exactly when status is tombstone")
    if card["successors"]:
        _sums_to_one(card["successors"], "successors")
    return card


def validate_evidence(row, allow_negative=False, relations=EVENT_RELATIONS, membership_rels=MEMBERSHIP_RELS):
    _schema("evidence", row)
    if row["relation"] not in relations:
        raise ValidationError(f"relation {row['relation']!r} is not in {sorted(relations)}")
    by_rel, seen = {}, set()
    for m in row["memberships"]:
        if m.get("counterfactual") is not None and m["rel"] != "outcome":
            raise ValidationError("a counterfactual belongs to an outcome membership only")
        if m["rel"] not in membership_rels:
            raise ValidationError(f"membership rel {m['rel']!r} is not in {sorted(membership_rels)}")
        if (m["domain"], m["rel"]) in seen:
            raise ValidationError(f"duplicate {m['rel']} membership of {m['domain']}")
        seen.add((m["domain"], m["rel"]))
        by_rel.setdefault(m["rel"], []).append(m)
    for rel, ms in sorted(by_rel.items()):
        _sums_to_one(ms, f"{rel} membership")
    if (row["channel"] == "negative") != (row["sign"] == -1):
        raise ValidationError("sign is -1 exactly when the channel is negative")
    if row["channel"] == "negative" and not allow_negative:
        raise ValidationError("the negative channel is reserved")
    return row


def validate_task(task):
    _schema("task", task)
    return task


LINKS_MAX_UPSTREAM = 3
LINKS_MAX_OVERLAP = 6


def validate_links_answer(answer, task, ids=None):
    """A links answer: verdict "links", 1-3 upstream ids with weights summing to 1, 0-6 distinct overlap ids; with
    ids (the pack's) and the task, every id must exist in the pack and none may be the field itself."""
    if answer.get("verdict") != "links":
        raise ValidationError(f"links verdict must be 'links', not {answer.get('verdict')!r}")
    if "upstream" not in answer or "overlap" not in answer:
        raise ValidationError("a links answer needs upstream and overlap")
    up, ov = answer["upstream"], answer["overlap"]
    if not 1 <= len(up) <= LINKS_MAX_UPSTREAM:
        raise ValidationError(f"{len(up)} upstream domains, expected 1-{LINKS_MAX_UPSTREAM}")
    _sums_to_one([{"weight": w} for w in up.values()], "upstream")
    if len(ov) > LINKS_MAX_OVERLAP or len(set(ov)) != len(ov):
        raise ValidationError(f"overlap must be at most {LINKS_MAX_OVERLAP} distinct ids")
    own = task["input"]["card"]["id"]
    for i in [*up, *ov]:
        if i == own:
            raise ValidationError(f"{own}: a domain cannot link to itself")
        if ids is not None and i not in ids:
            raise ValidationError(f"{i} is not in the pack")
    return answer


def validate_membership_answer(answer, vocab, ids=None):
    """A membership answer: verdict "membership", `types` holding exactly the vocabulary's types, each null or a
    non-empty {domain id: weight} summing to 1 (every id in the pack, when given), and `other` (string or null)."""
    if answer.get("verdict") != "membership":
        raise ValidationError(f"membership verdict must be 'membership', not {answer.get('verdict')!r}")
    if "types" not in answer or "other" not in answer:
        raise ValidationError("a membership answer needs types and other")
    types, want = answer["types"], VOCABS[vocab]["types"]
    if sorted(types) != sorted(want):
        raise ValidationError(f"types {sorted(types)} differ from the vocabulary's {sorted(want)}")
    if isinstance(answer["other"], str) and not answer["other"].strip():
        raise ValidationError("other must name a relation or be null, not blank")
    for t, ws in types.items():
        if ws is None:
            continue
        if not ws:
            raise ValidationError(f"{t}: an empty map; use null when the type does not apply")
        _sums_to_one([{"weight": w} for w in ws.values()], f"{t} membership")
        for i in ws:
            if ids is not None and i not in ids:
                raise ValidationError(f"{i} is not in the pack")
    return answer


EXTRACT_KEYS = {"span", "relation", "channel", "magnitude", "valid_time", "types"}
EXTRACT_CHANNELS = ("positive", "prediction")  # the negative channel is reserved
EXTRACT_MAGNITUDE_MAX = 1.5
_SPAN = re.compile(r"^L(\d+)$")
_VALID_TIME = re.compile(r"^\d{4}(-\d{2}(-\d{2})?)?$")


def validate_extract_answer(answer, task, ids=None):
    """An extract answer: verdict "rows" and `rows`, each row exactly span (`L<n>` of a non-blank line of the task's
    `lines`), relation (an event relation), channel (positive or prediction), magnitude (0 to 1.5), valid_time (null or a
    date) and `types` (exactly the A3S types, each null or {domain: weight} summing to 1, ids in the pack when given,
    at least one non-null). An answer with no rows is valid."""
    if answer.get("verdict") != "rows":
        raise ValidationError(f"extract verdict must be 'rows', not {answer.get('verdict')!r}")
    rows = answer.get("rows")
    if not isinstance(rows, list):
        raise ValidationError("an extract answer needs a list `rows`")
    lines = {int(l[1:l.index(":")]) for l in task["input"]["lines"] if l.startswith("L") and ":" in l}
    want = sorted(real_types("A3S"))
    for n, r in enumerate(rows):
        where = f"row {n}"
        if not isinstance(r, dict) or set(r) != EXTRACT_KEYS:
            raise ValidationError(f"{where}: keys must be exactly {sorted(EXTRACT_KEYS)}")
        m = _SPAN.match(r["span"]) if isinstance(r["span"], str) else None
        if not m or int(m.group(1)) not in lines:
            raise ValidationError(f"{where}: span {r['span']!r} is not a line of the text")
        if r["relation"] not in EVENT_RELATIONS:
            raise ValidationError(f"{where}: relation {r['relation']!r} is not in {sorted(EVENT_RELATIONS)}")
        if r["channel"] not in EXTRACT_CHANNELS:
            raise ValidationError(f"{where}: channel {r['channel']!r} is not in {list(EXTRACT_CHANNELS)}")
        mag = r["magnitude"]
        if isinstance(mag, bool) or not isinstance(mag, (int, float)) or not 0 <= mag <= EXTRACT_MAGNITUDE_MAX:
            raise ValidationError(f"{where}: magnitude {mag!r} is not a number in [0, {EXTRACT_MAGNITUDE_MAX}]")
        vt = r["valid_time"]
        if vt is not None and not (isinstance(vt, str) and _VALID_TIME.match(vt)):
            raise ValidationError(f"{where}: valid_time {vt!r} is neither null nor YYYY[-MM[-DD]]")
        types = r["types"]
        if not isinstance(types, dict) or sorted(types) != want:
            raise ValidationError(f"{where}: types must be exactly {want}")
        if all(ws is None for ws in types.values()):
            raise ValidationError(f"{where}: every type is null; the row belongs to no domain")
        for t, ws in types.items():
            if ws is None:
                continue
            if not isinstance(ws, dict) or not ws:
                raise ValidationError(f"{where}: {t} must be null or a non-empty {{domain: weight}} map")
            if any(isinstance(w, bool) or not isinstance(w, (int, float)) or w <= 0 for w in ws.values()):
                raise ValidationError(f"{where}: {t} weights must be positive numbers")
            _sums_to_one([{"weight": w} for w in ws.values()], f"{where} {t}")
            for i in ws:
                if ids is not None and i not in ids:
                    raise ValidationError(f"{where}: {i} is not in the pack")
    return answer


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
    membership = header["task_type"].startswith("membership.")
    extract = header["task_type"] == "extract"
    ids = pack_ids(header["prefix"]) if header["task_type"] == "links" or membership or extract else None
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
        if t["task_type"] == "links":
            try:
                validate_links_answer(a, t, ids)
            except ValidationError as e:
                errors.append(f"line {n}: {e}")
        if extract:
            try:
                validate_extract_answer(a, t, ids)
            except ValidationError as e:
                errors.append(f"line {n}: {e}")
        if membership:
            try:
                validate_membership_answer(a, header["task_type"].split(".", 1)[1], ids)
            except ValidationError as e:
                errors.append(f"line {n}: {e}")
    for missing in sorted(set(tasks) - seen):
        errors.append(f"missing answer for {missing}")
    return errors


def validate_entity(entity):
    _schema("entity", entity)
    return entity


def validate_count_as(rule):
    _schema("count_as", rule)
    return rule
