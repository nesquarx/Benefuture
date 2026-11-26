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


FIT_MAX = 10
RANKED_MEMBERSHIP_VERSION = 3  # membership prompt versions from here on carry the ranked stopping rule (LI.67)
RANKED_EXTRACT_VERSION = 2  # extract prompt versions from here on carry it


def _fit_floor(floor):
    if floor is not None:
        return floor
    from .governed import governed
    return governed("membership.fit_floor")


def _int_fit(x):
    return isinstance(x, int) and not isinstance(x, bool) and 0 <= x <= FIT_MAX


def validate_ranked_types(types, ranks, want, ids=None, where="", floor=None):
    """LI.67: per relation, `types` is null or {domain: weight} in rank order, and `ranks` null exactly then, else
    {"listed": [{"domain", "fit"}...], "rejected": {"domain", "fit"}}. Rejected: lists that are unranked (fits or weights
    rise down the list), a listed domain below the floor, weights not summing to 1, and a list that stopped while its best
    rejected domain is at or above the floor (or that is not auditable: no rejected domain)."""
    floor = _fit_floor(floor)
    pre = f"{where}: " if where else ""
    if not isinstance(types, dict) or sorted(types) != sorted(want):
        raise ValidationError(f"{pre}types must be exactly {sorted(want)}")
    if not isinstance(ranks, dict) or sorted(ranks) != sorted(want):
        raise ValidationError(f"{pre}ranks must be exactly {sorted(want)} (the fit record of the ranked stopping rule)")
    for t in want:
        ws, rk = types[t], ranks[t]
        if ws is None or rk is None:
            if ws is not None or rk is not None:
                raise ValidationError(f"{pre}{t}: types and ranks must both be null or both be given")
            continue
        if not isinstance(ws, dict) or not ws:
            raise ValidationError(f"{pre}{t}: types must be null or a non-empty {{domain: weight}} map")
        if any(isinstance(w, bool) or not isinstance(w, (int, float)) or w <= 0 for w in ws.values()):
            raise ValidationError(f"{pre}{t}: weights must be positive numbers")
        _sums_to_one([{"weight": w} for w in ws.values()], f"{pre}{t} membership")
        if ids is not None:
            for i in ws:
                if i not in ids:
                    raise ValidationError(f"{pre}{i} is not in the pack")
        if not isinstance(rk, dict) or set(rk) != {"listed", "rejected"}:
            raise ValidationError(f"{pre}{t}: ranks must have exactly listed and rejected")
        listed = rk["listed"]
        if not isinstance(listed, list) or not listed or not all(isinstance(e, dict) and set(e) == {"domain", "fit"} for e in listed):
            raise ValidationError(f"{pre}{t}: listed must be a non-empty list of {{domain, fit}}")
        doms = [e["domain"] for e in listed]
        if doms != list(ws):
            raise ValidationError(f"{pre}{t}: listed domains {doms} differ from the weighted domains {list(ws)} (order included)")
        fits = [e["fit"] for e in listed]
        if not all(_int_fit(f) for f in fits):
            raise ValidationError(f"{pre}{t}: fits must be integers 0 to {FIT_MAX}")
        for d, f in zip(doms, fits):
            if f < floor:
                raise ValidationError(f"{pre}{t}: {d} is listed with fit {f}, below the floor {floor}")
        if any(a < b for a, b in zip(fits, fits[1:])):
            raise ValidationError(f"{pre}{t}: unranked, fits {fits} rise down the list")
        wl = list(ws.values())
        if any(a < b - WEIGHT_TOL for a, b in zip(wl, wl[1:])):
            raise ValidationError(f"{pre}{t}: unranked, weights {wl} rise down the list")
        rej = rk["rejected"]
        if not isinstance(rej, dict) or set(rej) != {"domain", "fit"} or not _int_fit(rej["fit"]):
            raise ValidationError(f"{pre}{t}: rejected must be {{domain, fit}} with an integer fit (the stopping point is audited)")
        if rej["domain"] in doms:
            raise ValidationError(f"{pre}{t}: the rejected domain {rej['domain']} is also listed")
        if ids is not None and rej["domain"] not in ids:
            raise ValidationError(f"{pre}{rej['domain']} is not in the pack")
        if rej["fit"] >= floor:
            raise ValidationError(f"{pre}{t}: stopped early, the best rejected domain {rej['domain']} has fit {rej['fit']}, at or above the floor {floor}")
    if all(types[t] is None for t in want):
        raise ValidationError(f"{pre}every relation is null")
    return types


def validate_ranked_membership_answer(answer, vocab, ids=None, floor=None):
    """A v3 membership answer: verdict "membership", `types` and `ranks` over the vocabulary's real types (no placebo),
    ranked per `validate_ranked_types`, and `other` (string or null)."""
    if answer.get("verdict") != "membership":
        raise ValidationError(f"membership verdict must be 'membership', not {answer.get('verdict')!r}")
    for k in ("types", "ranks", "other"):
        if k not in answer:
            raise ValidationError(f"a ranked membership answer needs {k}")
    if isinstance(answer["other"], str) and not answer["other"].strip():
        raise ValidationError("other must name a relation or be null, not blank")
    validate_ranked_types(answer["types"], answer["ranks"], real_types(vocab), ids, floor=floor)
    return answer


EXTRACT_KEYS = {"span", "relation", "channel", "magnitude", "valid_time", "types"}
EXTRACT_CHANNELS = ("positive", "prediction")  # the negative channel is reserved
EXTRACT_MAGNITUDE_MAX = 1.5
_SPAN = re.compile(r"^L(\d+)$")
_VALID_TIME = re.compile(r"^\d{4}(-\d{2}(-\d{2})?)?$")


def validate_extract_answer(answer, task, ids=None, ranked=False, floor=None):
    """An extract answer: verdict "rows" and `rows`, each row exactly span (`L<n>` of a non-blank line of the task's
    `lines`), relation (an event relation), channel (positive or prediction), magnitude (0 to 1.5), valid_time (null or a
    date) and `types` (exactly the A3S types, each null or {domain: weight} summing to 1, ids in the pack when given,
    at least one non-null). An answer with no rows is valid. With `ranked` (extract v2, LI.67) each row also carries `ranks`
    and its lists obey the ranked stopping rule (`validate_ranked_types`)."""
    if answer.get("verdict") != "rows":
        raise ValidationError(f"extract verdict must be 'rows', not {answer.get('verdict')!r}")
    rows = answer.get("rows")
    if not isinstance(rows, list):
        raise ValidationError("an extract answer needs a list `rows`")
    lines = {int(l[1:l.index(":")]) for l in task["input"]["lines"] if l.startswith("L") and ":" in l}
    want = sorted(real_types("A3S"))
    for n, r in enumerate(rows):
        where = f"row {n}"
        keys = EXTRACT_KEYS | {"ranks"} if ranked else EXTRACT_KEYS
        if not isinstance(r, dict) or set(r) != keys:
            raise ValidationError(f"{where}: keys must be exactly {sorted(keys)}")
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
        if ranked:
            validate_ranked_types(types, r["ranks"], want, ids, where=where, floor=floor)
            continue
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


def validate_adjacency_input(task):
    """An adjacency task: `input.card` plus `set_1` and `set_2`, two domains each, none the card's own."""
    inp = task["input"]
    own = inp.get("card", {}).get("id")
    for k in ("set_1", "set_2"):
        s = inp.get(k)
        if not isinstance(s, list) or len(s) != 2 or len({c.get("id") for c in s}) != 2:
            raise ValidationError(f"adjacency {k} must hold two distinct domains")
        if any(c.get("id") == own for c in s):
            raise ValidationError(f"adjacency {k} contains the card's own domain")
    return task


def validate_relatedness_input(task):
    """A relatedness task: `input.first` and `input.second`, two distinct fields, each with at most five children labels."""
    inp = task["input"]
    ids = []
    for k in ("first", "second"):
        f = inp.get(k)
        if not isinstance(f, dict) or not f.get("id"):
            raise ValidationError(f"relatedness {k} must be a field with an id")
        if not isinstance(f.get("children"), list) or len(f["children"]) > 5:
            raise ValidationError(f"relatedness {k} children must be a list of at most five labels")
        ids.append(f["id"])
    if ids[0] == ids[1]:
        raise ValidationError("relatedness needs two distinct fields")
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
    membership = header["task_type"].startswith("membership.")
    extract = header["task_type"] == "extract"
    ids = pack_ids(header["prefix"]) if header["task_type"] == "links" or membership or extract else None
    tasks = {}
    for line in batch_lines[1:]:
        t = validate_task(json.loads(line))
        if header["task_type"] == "adjacency":
            validate_adjacency_input(t)
        if header["task_type"] == "relatedness":
            validate_relatedness_input(t)
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
                validate_extract_answer(a, t, ids, ranked=header["prompt_version"] >= RANKED_EXTRACT_VERSION)
            except ValidationError as e:
                errors.append(f"line {n}: {e}")
        if membership:
            vocab = header["task_type"].split(".", 1)[1]
            try:
                if header["prompt_version"] >= RANKED_MEMBERSHIP_VERSION:
                    validate_ranked_membership_answer(a, vocab, ids)
                else:
                    validate_membership_answer(a, vocab, ids)
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
