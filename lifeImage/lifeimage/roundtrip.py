"""Round-trip identification: does an item's merged A-annotation single out the original event?

Given only the merged annotation (type -> top domains with labels, no text) and five candidate texts (the true one
and the four nearest distractors), a runner picks the original. Accuracy is a validity measure: an annotation that
cannot find its own event has dropped what distinguishes it (chance is 1/5). The distractors are the items whose top
domain of the vocabulary's first type (form, or act) equals the item's, then the rest, each group by id: a
deterministic rule, so a rerun repeats. Candidates are shown as c1..c5 in a fixed hash order; the sidecar key file
(never shown to the runner) says which is true.

Task type `roundtrip.<VOCAB>` v1, k = 1 (one variant is enough for a validity measure).
"""
import hashlib
import json
from collections import defaultdict
from pathlib import Path

from .canonical import canonical_json, content_hash
from .membership import (DEFAULT_OUT, DEFAULT_PROMPTS, item_input, pack_hash, pack_lines, real_types, write_batch_file)
from .membership import task_type as membership_task_type

MODEL = "haiku-subagent-low"
PROMPT_VERSION = 1
N_CANDIDATES = 5
LABELS = [f"c{i}" for i in range(1, N_CANDIDATES + 1)]
MIN_WEIGHT = 0.2
MAX_DOMAINS = 3


def task_type(vocab):
    return f"roundtrip.{vocab}"


def domain_labels(pack_text):
    """{domain id: label} from the pack's `id | label | description` lines."""
    _, sectors, fields = pack_lines(pack_text)
    return {l.split(" | ")[0]: l.split(" | ")[1] for l in sectors + fields}


def merge_annotation(answers, types, labels=None):
    """One item's annotation merged over its variants' answers (dicts with `types`). A type is null unless a strict
    majority of the variants filled it; otherwise the filling variants' weights are averaged and the top domains
    kept (weight at least MIN_WEIGHT, at most MAX_DOMAINS, always the heaviest). {type: [{domain, label, weight}]
    | None}."""
    out = {}
    for t in types:
        filled = [a["types"][t] for a in answers if a["types"].get(t)]
        if 2 * len(filled) <= len(answers):
            out[t] = None
            continue
        total = defaultdict(float)
        for w in filled:
            for d, x in w.items():
                total[d] += x / len(filled)
        order = sorted(total, key=lambda d: (-total[d], d))
        keep = [d for d in order if total[d] >= MIN_WEIGHT][:MAX_DOMAINS] or order[:1]
        out[t] = [{"domain": d, "label": (labels or {}).get(d, d), "weight": round(total[d], 3)} for d in keep]
    return out


def merged_annotations(vocab, items, pack_text, cache, *, model, prompt_version):
    """{item id: merged annotation} for the items whose answers are cached (placebo type left out)."""
    labels, ph, out = domain_labels(pack_text), pack_hash(pack_text), {}
    for it in items:
        h = content_hash(item_input(it, ph))
        votes = cache.get(membership_task_type(vocab), h, model, prompt_version)
        if votes:
            out[it["id"]] = merge_annotation([votes[v] for v in sorted(votes)], real_types(vocab), labels)
    return out


def top_form(annotation, form_type):
    ds = annotation.get(form_type)
    return ds[0]["domain"] if ds else None


def pick_distractors(item_id, annotations, texts, form_type, n=N_CANDIDATES - 1):
    """The n nearest distractor ids: other items sharing the item's top form domain first, then the rest, each by
    id; an item whose text equals the true text (or an earlier distractor's) is skipped, so no candidate repeats."""
    mine = top_form(annotations[item_id], form_type)
    seen = {texts[item_id].strip().lower()}
    out = []
    for i in sorted((i for i in annotations if i != item_id),
                    key=lambda i: (top_form(annotations[i], form_type) != mine or mine is None, i)):
        key = texts[i].strip().lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(i)
        if len(out) == n:
            break
    return out


def _shuffled(item_id, ids):
    return sorted(ids, key=lambda i: hashlib.sha256(f"{item_id}:{i}".encode()).hexdigest())


def build_roundtrip_batch(vocab, annotations, texts, *, model=MODEL, prompt_version=PROMPT_VERSION,
                          prompts_dir=DEFAULT_PROMPTS, cache=None):
    """(batch lines, key rows) for the annotated items. cache: an AnswerCache whose cached pairs are skipped."""
    tt = task_type(vocab)
    form_type = real_types(vocab)[0]
    prefix = (Path(prompts_dir) / f"roundtrip.v{prompt_version}.md").read_text(encoding="utf-8").rstrip("\n")
    header = json.dumps({"kind": "header", "task_type": tt, "model": model, "prompt_version": prompt_version,
                         "prefix": prefix}, sort_keys=True, ensure_ascii=False)
    lines, keys = [header], []
    for iid in sorted(annotations):
        ids = [iid] + pick_distractors(iid, annotations, texts, form_type)
        if len(ids) < N_CANDIDATES:
            continue
        order = _shuffled(iid, ids)
        inp = {"annotation": annotations[iid],
               "candidates": [{"id": lab, "text": texts[i]} for lab, i in zip(LABELS, order)]}
        h = content_hash(inp)
        if cache is not None and cache.has(tt, h, model, prompt_version, 0):
            continue
        tid = f"{h[:16]}-v0"
        lines.append(canonical_json({"kind": "task", "task_id": tid, "task_type": tt, "prompt_version": prompt_version,
                                     "input_hash": h, "variant": 0, "k": 1, "input": inp, "allowed_verdicts": LABELS}))
        keys.append({"task_id": tid, "item": iid, "correct": LABELS[order.index(iid)],
                     "candidates": dict(zip(LABELS, order))})
    return lines, keys


def write_roundtrip(vocab, lines, keys, out_dir=DEFAULT_OUT, prompt_version=PROMPT_VERSION):
    """data/batches/roundtrip.<V>.v1.var0.jsonl plus roundtrip.<V>.v1.key.jsonl (the answers, kept from runners)."""
    out = Path(out_dir)
    batch = write_batch_file(out / f"{task_type(vocab)}.v{prompt_version}.var0.jsonl", lines)
    key = write_batch_file(out / f"{task_type(vocab)}.v{prompt_version}.key.jsonl", [json.dumps(k, sort_keys=True) for k in keys])
    return batch, key


def score_roundtrip(key_rows, answers):
    """Round-trip accuracy. key_rows: dicts from the key file; answers: answer dicts. An unanswered task counts as
    wrong (not skipped), so a runner cannot raise its score by leaving hard items out."""
    got = {a["task_id"]: a["verdict"] for a in answers}
    right = sum(got.get(k["task_id"]) == k["correct"] for k in key_rows)
    n = len(key_rows)
    return {"tasks": n, "answered": sum(k["task_id"] in got for k in key_rows), "correct": right,
            "accuracy": right / n if n else float("nan"), "chance": 1 / N_CANDIDATES}


def score_files(key_path, answers_path):
    rows = lambda p: [json.loads(l) for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]
    return score_roundtrip(rows(key_path), rows(answers_path))
