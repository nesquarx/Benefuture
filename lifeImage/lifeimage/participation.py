"""Layer B battery (participation): how each listed participant is involved in an event.

Task type `participation` v1. The item set is `data/gold/bd_items_v0.jsonl`: every item carries its participants
explicitly (`{id, label}`), because who takes part is not what is being measured. A task is one item; its answer
line carries `participants`, one object per listed participant (see `prompts/participation.v1.md`).

Variants change only the order of the participants listed in the task (variant 0 sorts by id; variant i sorts by
sha256(i:id), a fixed shuffle). The prompt prefix is shared and holds no worked answer, so nothing anchors a value.
The input hash ignores the order, so one item has one hash across variants.

Answer rules checked by `validate_participation_answer`: exactly the listed participants, once each; contribution
and responsibility in [0, 1]; contributions to the one outcome sum to at most 1 (omitting this check lets a runner
credit every participant fully, which breaks value routing); impact entries with sign +-1 and integer magnitude
0-3; text-or-null for the record fields; a constrained volition names its record.
"""
import hashlib
import json
import math
from pathlib import Path

from .canonical import canonical_json, content_hash
from .membership import DEFAULT_GOLD, DEFAULT_OUT
from .tasks import DEFAULT_K, DEFAULT_PROMPTS
from .validate import ValidationError

TASK_TYPE = "participation"
PROMPT_VERSION = 1
MODEL = "haiku-subagent-low"
DEFAULT_ITEMS = DEFAULT_GOLD / "bd_items_v0.jsonl"
VOLITIONS = ("free", "constrained")
PRODUCTIONS = ("produced", "consumed", "both")
MAX_MAGNITUDE = 3
CONSERVATION_TOL = 1e-6
ENTRY_KEYS = ("id", "contribution", "responsibility", "impact", "acting_for", "under_agreement", "informed",
              "volition", "volition_record", "production")


def load_bd_items(path=DEFAULT_ITEMS):
    """The items: [{id, text, source, participants: [{id, label}], tags, expect?, ...}]."""
    items = [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]
    for i in items:
        ids = [p["id"] for p in i["participants"]]
        if not ids or len(set(ids)) != len(ids):
            raise ValueError(f"{i['id']}: participants must be non-empty with unique ids")
    return items


def _key(variant, pid):
    return pid if variant == 0 else hashlib.sha256(f"{variant}:{pid}".encode()).hexdigest()


def ordered_participants(item, variant):
    """The item's participants in the variant's fixed order."""
    return sorted(item["participants"], key=lambda p: _key(variant, p["id"]))


def item_input(item, variant=0):
    """The task input of one item for a variant."""
    return {"item": {"id": item["id"], "text": item["text"],
                     "participants": [{"id": p["id"], "label": p["label"]} for p in ordered_participants(item, variant)]}}


def item_hash(item):
    """Hash of the input in the canonical order, so every variant of one item shares it."""
    return content_hash(item_input(item, 0))


def build_batches(task_type, items, prefix_for, *, model=MODEL, prompt_version=PROMPT_VERSION, k=DEFAULT_K, cache=None):
    """{variant: [header, task lines...]}; `prefix_for(variant)` is the variant's instruction text. Items whose
    (task type, hash, model, version, variant) the cache already holds are left out."""
    batches = {}
    for v in range(k):
        header = json.dumps({"kind": "header", "task_type": task_type, "model": model, "prompt_version": prompt_version,
                             "prefix": prefix_for(v)}, sort_keys=True, ensure_ascii=False)
        lines = []
        for it in sorted(items, key=lambda i: i["id"]):
            h = item_hash(it)
            if cache is not None and cache.has(task_type, h, model, prompt_version, v):
                continue
            lines.append(canonical_json({
                "kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": task_type, "prompt_version": prompt_version,
                "input_hash": h, "variant": v, "k": k, "input": item_input(it, v), "allowed_verdicts": [task_type]}))
        if lines:
            batches[v] = [header] + lines
    return batches


def build_participation_batches(items, *, model=MODEL, prompt_version=PROMPT_VERSION, prompts_dir=DEFAULT_PROMPTS,
                                k=DEFAULT_K, cache=None):
    text = (Path(prompts_dir) / f"{TASK_TYPE}.v{prompt_version}.md").read_text(encoding="utf-8").rstrip("\n")
    return build_batches(TASK_TYPE, items, lambda v: text, model=model, prompt_version=prompt_version, k=k, cache=cache)


def write_bd_batches(task_type, batches, out_dir=DEFAULT_OUT, prompt_version=PROMPT_VERSION):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for v, lines in sorted(batches.items()):
        p = out / f"{task_type}.v{prompt_version}.var{v}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    return paths


# ---- validation ----
def _num(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool) and math.isfinite(x)


def _text_or_null(x, what):
    if x is not None and not (isinstance(x, str) and x.strip()):
        raise ValidationError(f"{what} must be non-blank text or null, not {x!r}")


def _unit(x, what):
    if not _num(x) or not 0 <= x <= 1:
        raise ValidationError(f"{what} must be a number in [0, 1], not {x!r}")


def validate_participation_answer(answer, participants, conservation=True):
    """A participation answer: verdict "participation" and `participants` holding exactly the listed ids, each with
    exactly ENTRY_KEYS and valid values; contributions sum to at most 1 unless `conservation` is False."""
    if answer.get("verdict") != TASK_TYPE:
        raise ValidationError(f"verdict must be {TASK_TYPE!r}, not {answer.get('verdict')!r}")
    entries = answer.get("participants")
    if not isinstance(entries, list):
        raise ValidationError("a participation answer needs a participants list")
    want = [p["id"] for p in participants]
    got = [e.get("id") if isinstance(e, dict) else None for e in entries]
    if sorted(map(str, got)) != sorted(want):
        raise ValidationError(f"participants {got} differ from the listed {want}")
    for e in entries:
        pid = e["id"]
        if set(e) != set(ENTRY_KEYS):
            raise ValidationError(f"{pid}: keys {sorted(set(e) ^ set(ENTRY_KEYS))} missing or unknown")
        _unit(e["contribution"], f"{pid}: contribution")
        _unit(e["responsibility"], f"{pid}: responsibility")
        if not isinstance(e["impact"], list):
            raise ValidationError(f"{pid}: impact must be a list")
        for imp in e["impact"]:
            if not isinstance(imp, dict) or set(imp) != {"party", "sign", "magnitude"}:
                raise ValidationError(f"{pid}: an impact needs exactly party, sign and magnitude")
            _text_or_null(imp["party"], f"{pid}: impact party")
            if imp["party"] is None:
                raise ValidationError(f"{pid}: impact party is required")
            if imp["sign"] not in (1, -1) or isinstance(imp["sign"], bool):
                raise ValidationError(f"{pid}: impact sign must be 1 or -1, not {imp['sign']!r}")
            m = imp["magnitude"]
            if isinstance(m, bool) or not isinstance(m, int) or not 0 <= m <= MAX_MAGNITUDE:
                raise ValidationError(f"{pid}: impact magnitude must be an integer 0-{MAX_MAGNITUDE}, not {m!r}")
        for f in ("acting_for", "under_agreement", "informed", "volition_record"):
            _text_or_null(e[f], f"{pid}: {f}")
        if e["volition"] is not None and e["volition"] not in VOLITIONS:
            raise ValidationError(f"{pid}: volition must be one of {VOLITIONS} or null, not {e['volition']!r}")
        if e["volition"] == "constrained" and e["volition_record"] is None:
            raise ValidationError(f"{pid}: a constrained volition must name its option set or prior threat")
        if e["volition"] is None and e["volition_record"] is not None:
            raise ValidationError(f"{pid}: volition_record without a volition")
        if e["production"] is not None and e["production"] not in PRODUCTIONS:
            raise ValidationError(f"{pid}: production must be one of {PRODUCTIONS} or null, not {e['production']!r}")
    total = math.fsum(e["contribution"] for e in entries)
    if conservation and total > 1 + CONSERVATION_TOL:
        raise ValidationError(f"contributions sum to {total:.4f}, above 1")
    return answer
