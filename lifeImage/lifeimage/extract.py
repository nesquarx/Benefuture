"""The extract task: one persona's resume text plus the coarse pack in, claimed-tier evidence rows out.

A task is one resume (`input`: entity, source, as_of and `lines`, every non-blank line of the text numbered `L<n>: ...`); the
batch prefix is the instructions (`prompts/extract.v1.md`) followed by the coarse pack, ungrouped and ordered per
variant (variant 0 by id, variant i by a hash), so k = 3 variants differ only in pack order and each is stable across
reruns. An answer (verdict `rows`) lists compact rows: span `L<n>`, relation, channel (`positive`, or `prediction` for
a self-assessed level the text states), magnitude, valid_time (or null), and `types`: the A3S membership types form,
content, outcome and setting, each null or {domain: weight} summing to 1.

`evidence_rows` completes a validated answer into contract rows: tier `claimed`, record_time the reading date,
confidence CLAIMED_CONFIDENCE (a governed default: the extractor states no confidence, so a claim carries the weakest
tier's standing until attested), provenance the resume line. A claim whose line gives no date is a present claim: its
valid_time is the reading month. `answer_rows` is the inverse, used to check that the generators' truth survives the
answer format.
"""
import json
from pathlib import Path

from .canonical import canonical_json, content_hash
from .membership import VOCABS, pack_hash, real_types, ungrouped_pack
from .tasks import DEFAULT_K, DEFAULT_PROMPTS
from .validate import validate_evidence

TASK_TYPE = "extract"
PROMPT_VERSION = 1
MODEL = "haiku-runner"
VOCAB = "A3S"
TYPES = real_types(VOCAB)  # form, content, outcome, setting
MEMBERSHIP_RELS = frozenset(TYPES)
CLAIMED_CONFIDENCE = 0.3  # governed: the confidence of a claimed row the extractor read from a self-report
SYNTHETIC = Path(__file__).resolve().parent.parent / "data" / "synthetic"
ENTITY_KINDS = {"person", "organisation", "ai", "animal"}


def numbered(text):
    """Every non-blank line as `L<n>: line`, n counting from 1 over all lines, so a span names a line of the file. A
    list, since canonical text would fold newlines (and so line breaks) into spaces."""
    return [f"L{n}: {l}" for n, l in enumerate(text.splitlines(), 1) if l.strip()]


def resume_input(persona, text):
    return {"entity": persona["entity"], "source": f"resume:{persona['id']}", "as_of": persona["as_of"], "lines": numbered(text)}


def build_extract_batches(inputs, pack_text, *, model=MODEL, prompt_version=PROMPT_VERSION, prompts_dir=DEFAULT_PROMPTS,
                          k=DEFAULT_K, cache=None):
    """{variant: [header, task lines...]}: one task per input, uncached (input, variant) pairs only."""
    instructions = (Path(prompts_dir) / f"{TASK_TYPE}.v{prompt_version}.md").read_text(encoding="utf-8").rstrip("\n")
    batches = {}
    for v in range(k):
        prefix = f"{instructions}\n\nThe coarse pack follows.\n{ungrouped_pack(pack_text, v)}"
        header = json.dumps({"kind": "header", "task_type": TASK_TYPE, "model": model, "prompt_version": prompt_version,
                             "prefix": prefix}, sort_keys=True, ensure_ascii=False)
        lines = []
        for inp in sorted(inputs, key=lambda i: i["entity"]):
            h = content_hash({"input": inp, "pack": pack_hash(pack_text)})
            if cache is not None and cache.has(TASK_TYPE, h, model, prompt_version, v):
                continue
            lines.append(canonical_json({
                "kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": TASK_TYPE, "prompt_version": prompt_version,
                "input_hash": h, "variant": v, "k": k, "input": inp, "allowed_verdicts": ["rows"]}))
        batches[v] = [header] + lines
    return batches


def write_extract_batches(batches, out_dir, prompt_version=PROMPT_VERSION):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for v, lines in sorted(batches.items()):
        p = out / f"{TASK_TYPE}.v{prompt_version}.var{v}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    return paths


def evidence_rows(answer, inp, basemap_version):
    """Contract rows (validated) of an extract answer for the task input; an answer must already be valid."""
    kind = inp["entity"].split(":", 1)[0]
    out = []
    for r in answer["rows"]:
        mems = [{"domain": d, "rel": t, "weight": w} for t in TYPES for d, w in sorted((r["types"].get(t) or {}).items())]
        out.append(validate_evidence({
            "entity": inp["entity"], "relation": r["relation"], "memberships": mems, "basemap_version": basemap_version,
            "channel": r["channel"], "sign": 1, "magnitude": r["magnitude"], "entity_kind": kind if kind in ENTITY_KINDS else "other",
            "valid_time": r.get("valid_time") or inp["as_of"][:7], "record_time": inp["as_of"], "tier": "claimed",
            "confidence": CLAIMED_CONFIDENCE, "provenance": {"source": inp["source"], "span": r["span"]}, "revoked": False},
            membership_rels=MEMBERSHIP_RELS))
    return out


def answer_rows(rows):
    """The compact answer rows of evidence rows (the inverse of evidence_rows)."""
    out = []
    for r in rows:
        types = {t: {m["domain"]: m["weight"] for m in r["memberships"] if m["rel"] == t} or None for t in TYPES}
        out.append({"span": r["provenance"]["span"], "relation": r["relation"], "channel": r["channel"], "magnitude": r["magnitude"],
                    "valid_time": r["valid_time"], "types": types})
    return out
