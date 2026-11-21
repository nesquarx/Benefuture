"""The confirming battery: one combined task per item, `confirm.v1`.

An item (`data/gold/confirm_items_v0.jsonl`) is an event text with its participants listed, because who takes part is
not what is measured. One task answers three layers on it: A (membership of domains by form, content, outcome,
setting, plus the placebo `flavour`), B (participation, per listed participant) and D (sub-events and their links).
The prompt is `prompts/confirm.v1.md`; the batch prefix is the prompt with the variant's link-type order, the A3S
vocabulary and the coarse pack in the variant's order. Variants reorder participants, link types and the pack, so
no order anchors an answer; the input hash ignores the order, so one item has one hash across variants. Item
metadata (strata, expectations, pair ids) never enters the task.

A batch file holds one variant of all items, split into parts when it would pass MAX_BATCH_TOKENS (every part keeps
the header). Answers are checked by the layer validators the batteries already use, so a rule lives once: the A
part by `validate_membership_answer`, B by `validate_participation_answer` (contributions to one outcome sum to at
most 1; omitting this check lets a runner credit every participant fully), D by `validate_events_answer`.
"""
import json
from collections import defaultdict
from pathlib import Path

from .canonical import canonical_json, content_hash
from .events import EXTRA_KEYS, link_types_text, validate_events_answer
from .membership import (DEFAULT_GOLD, DEFAULT_OUT, ungrouped_pack, pack_hash, vocab_text)
from .packs import pack_ids
from .participation import ordered_participants, validate_participation_answer
from .tasks import DEFAULT_K, DEFAULT_PROMPTS
from .validate import ValidationError, validate_answer, validate_membership_answer, validate_task

TASK_TYPE = "confirm.v1"
PROMPT_NAME = "confirm.v1.md"
PROMPT_VERSION = 1
MODEL = "haiku-subagent-low"
VOCAB = "A3S"
MAX_BATCH_TOKENS = 40_000
DEFAULT_ITEMS = DEFAULT_GOLD / "confirm_items_v0.jsonl"
SOURCES = ("a_pool", "bd", "counterfactual", "production_pair")
PRODUCTION_VALUES = ("produced", "consumed", "both")


def load_confirm_items(path=DEFAULT_ITEMS):
    """The items [{id, text, source, participants: [{id, label}], ...}], validated: unique ids and texts, a known
    source, non-empty participants with unique ids and labels; a counterfactual item names its kind and expected
    outcome; a production-pair item names its pair, side and the expected production of a listed participant."""
    items = [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]
    ids, texts = set(), set()
    for i in items:
        where = f"{path}: {i.get('id')!r}"
        ps = i.get("participants") or []
        if i.get("source") not in SOURCES:
            raise ValueError(f"{where}: source {i.get('source')!r} not in {SOURCES}")
        if not ps or len({p.get("id") for p in ps}) != len(ps) or not all(p.get("id") and p.get("label") for p in ps):
            raise ValueError(f"{where}: participants must be non-empty with unique ids and labels")
        if not i.get("text", "").strip() or i["id"] in ids or i["text"].strip().lower() in texts:
            raise ValueError(f"{where}: blank or duplicate id or text")
        ids.add(i["id"])
        texts.add(i["text"].strip().lower())
        if i["source"] == "counterfactual" and (i.get("counterfactual") not in ("stated", "implied")
                                                or i.get("expected_outcome") not in ("change", "null")):
            raise ValueError(f"{where}: a counterfactual item needs counterfactual and expected_outcome")
        if i["source"] == "production_pair":
            exp = i.get("expect_production") or {}
            if (not i.get("pair") or i.get("side") not in ("a", "b") or len(exp) != 1
                    or set(exp) - {p["id"] for p in ps} or set(exp.values()) - set(PRODUCTION_VALUES)):
                raise ValueError(f"{where}: a production-pair item needs pair, side and one expected production")
    return items


def item_input(item, variant, phash):
    """The task input of one item for a variant: id, text, participants in the variant's order, the pack hash."""
    return {"item": {"id": item["id"], "text": item["text"],
                     "participants": [{"id": p["id"], "label": p["label"]} for p in ordered_participants(item, variant)]},
            "pack": phash}


def item_hash(item, phash):
    return content_hash(item_input(item, 0, phash))


def prefix_text(variant, pack_text, prompts_dir=DEFAULT_PROMPTS):
    """The batch prefix of a variant: the prompt (link types in the variant's order), the A3S vocabulary, the pack."""
    prompt = (Path(prompts_dir) / PROMPT_NAME).read_text(encoding="utf-8").rstrip("\n")
    prompt = prompt.replace("{{link_types}}", link_types_text(variant))
    return f"{prompt}\n\n{vocab_text(VOCAB)}\n\nThe coarse pack follows.\n{ungrouped_pack(pack_text, variant)}"


def tokens_of(lines):
    """Size of a batch file's lines in tokens, estimated as bytes / 4 (the figure the builders report)."""
    return sum(len(l.encode("utf-8")) + 1 for l in lines) // 4


def split_parts(header, task_lines, max_tokens=MAX_BATCH_TOKENS):
    """[[header, tasks...], ...]: the tasks in order, a new part whenever the next would pass `max_tokens`; every
    part keeps the header. Raises when the header plus one task is already above the limit."""
    parts, cur = [], [header]
    for line in task_lines:
        if len(cur) > 1 and tokens_of(cur + [line]) > max_tokens:
            parts.append(cur)
            cur = [header]
        cur.append(line)
        if tokens_of(cur) > max_tokens:
            raise ValueError(f"header plus one task is {tokens_of(cur)} tokens, above the limit {max_tokens}")
    return parts + [cur]


def build_confirm_batches(items, pack_text, *, model=MODEL, prompt_version=PROMPT_VERSION, k=DEFAULT_K,
                          max_tokens=MAX_BATCH_TOKENS, prompts_dir=DEFAULT_PROMPTS):
    """{variant: [part, ...]}, each part [header, task lines...] of at most `max_tokens`."""
    phash = pack_hash(pack_text)
    batches = {}
    for v in range(k):
        header = json.dumps({"kind": "header", "task_type": TASK_TYPE, "model": model, "prompt_version": prompt_version,
                             "prefix": prefix_text(v, pack_text, prompts_dir)}, sort_keys=True, ensure_ascii=False)
        lines = []
        for it in sorted(items, key=lambda i: i["id"]):
            h = item_hash(it, phash)
            lines.append(canonical_json({"kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": TASK_TYPE,
                                         "prompt_version": prompt_version, "input_hash": h, "variant": v, "k": k,
                                         "input": item_input(it, v, phash), "allowed_verdicts": ["confirm"]}))
        batches[v] = split_parts(header, lines, max_tokens)
    return batches


def write_confirm_batches(batches, out_dir=DEFAULT_OUT):
    """confirm.v1.var<v>.jsonl, or confirm.v1.var<v>.p<j>.jsonl for a variant split into parts."""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for v, parts in sorted(batches.items()):
        for j, lines in enumerate(parts):
            name = f"{TASK_TYPE}.var{v}.jsonl" if len(parts) == 1 else f"{TASK_TYPE}.var{v}.p{j}.jsonl"
            (out / name).write_text("\n".join(lines) + "\n", encoding="utf-8")
            paths.append(out / name)
    return paths


# ---- validation ----
def _parts(answer):
    """The answer as the three layer answers the existing validators take (each with its own verdict)."""
    return (dict(answer, verdict="membership"), dict(answer, verdict="participation"), dict(answer, verdict="events"))


def validate_confirm_answers(batch_lines, answer_lines):
    """Errors (empty when valid) of a confirm answers file against its batch file: exactly one well-formed answer
    per task, echoing the task's identity, with the A, B and D parts each valid under its layer's rules."""
    errors = []
    header = json.loads(batch_lines[0])
    if header["task_type"] != TASK_TYPE:
        return [f"task type {header['task_type']!r} is not {TASK_TYPE!r}"]
    ids = pack_ids(header["prefix"])
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
        am, ap, ae = _parts(a)
        for layer, check in (("A", lambda: validate_membership_answer(am, VOCAB, ids)),
                             ("B", lambda: validate_participation_answer(ap, t["input"]["item"]["participants"])),
                             ("D", lambda: validate_events_answer(ae))):
            try:
                check()
            except (ValidationError, KeyError, TypeError, AttributeError) as e:
                errors.append(f"line {n}: {layer}: {e}")
    for missing in sorted(set(tasks) - seen):
        errors.append(f"missing answer for {missing}")
    return errors


# ---- records for the metrics ----
def load_confirm_records(paths):
    """{"A": [...], "participation": [...], "events": [...]} from confirm answers files, each read with the batch
    file beside it (same name without `.answers`), which gives the item behind each task. Records have the shapes the
    layer metrics read (`membership_metrics.vocab_metrics`, `bd_metrics.participation_metrics`/`events_metrics`)."""
    out = {"A": [], "participation": [], "events": []}
    for p in map(Path, paths):
        batch = p.with_name(p.name.replace(".answers.jsonl", ".jsonl"))
        if batch == p or not batch.exists():
            raise FileNotFoundError(f"no batch file for answers {p} (expected {batch})")
        lines = batch.read_text(encoding="utf-8").splitlines()
        if json.loads(lines[0])["task_type"] != TASK_TYPE:
            raise ValueError(f"{batch}: not a {TASK_TYPE} batch")
        item_of = {json.loads(l)["task_id"]: json.loads(l)["input"]["item"]["id"] for l in lines[1:]}
        for l in p.read_text(encoding="utf-8").splitlines():
            if not l.strip():
                continue
            a = json.loads(l)
            base = {"item": item_of[a["task_id"]], "variant": a["variant"], "model": a.get("model"),
                    "prompt_version": a.get("prompt_version")}
            out["A"].append(dict(base, vocab=VOCAB, types=a["types"], other=a.get("other")))
            out["participation"].append(dict(base, participants={e["id"]: e for e in a["participants"]}))
            out["events"].append(dict(base, subevents=a["subevents"], links=a["event_links"]))
    return out
