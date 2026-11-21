"""Layer A battery: candidate vocabularies of membership relation types, scored on the same events.

One module holds the vocabularies (a one-line definition and one worked example per type), the item set (the
coverage events plus the layer-A red-team cases) and the batch builder. Task type `membership.<VOCAB>` v1: the
batch prefix is the instructions, the vocabulary's definitions and the coarse pack; each task is one item's text.

The pack is listed ungrouped: sectors first, then fields, so no guessed grouping hints at an answer. Variant 0
sorts each block by id; variant i sorts it by sha256(i:id), a fixed shuffle that is stable across reruns.
"""
import hashlib
import json
from pathlib import Path

from .canonical import canonical_json, content_hash
from .packs import PACK_MARK, pack_ids
from .tasks import DEFAULT_K, DEFAULT_PROMPTS

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PACK = ROOT / "data" / "packs" / "coarse.0.0.0-draft.txt"
DEFAULT_GOLD = ROOT / "data" / "gold"
DEFAULT_OUT = ROOT / "data" / "batches"
MODEL = "haiku-subagent-low"
PROMPT_VERSION = 1


def _t(definition, event, answer):
    return {"definition": definition, "example": {"event": event, "answer": answer}}


_A4 = {
    "form": _t("What kind of act or thing the event is.",
               "A trainee electrician rewires a kitchen socket", {"c.home_repair_diy": 0.5, "c.skilled_trades": 0.5}),
    "material": _t("The carrier or input the event uses, acts on or consumes.",
                   "Paying a water bill by mobile money", {"c.banking_payments": 0.7, "c.home_energy_utilities": 0.3}),
    "outcome": _t("What observably changes as a result.",
                  "Volunteers plant a hedge along an eroding stream bank and the bank stops collapsing",
                  {"c.environmental_stewardship": 0.6, "c.wildlife_conservation": 0.4}),
    "reference": _t("What the event represents or is about.",
                    "A documentary about migrant farm workers is screened at a library",
                    {"c.migration": 0.5, "c.agri_forestry_fishing_work": 0.5}),
}
_A6 = {
    **_A4,
    "mechanism": _t("The domain whose workings produce the event or its outcome.",
                    "A course of antibiotics clears a throat infection", {"c.medicine_science": 0.6, "c.life_sciences": 0.4}),
    "normative": _t("The laws, contracts or norms that govern the event.",
                    "A cafe owner files the quarterly sales tax return", {"c.taxation_compliance": 1.0}),
}
_R156 = {
    "causal": _t("What the event brings about, or acts on, through cause and effect.",
                 "A farmer opens an irrigation channel onto a dry field", {"c.horticulture_farming": 0.7, "c.environmental_stewardship": 0.3}),
    "structural": _t("The standing arrangement (role, institution, part of a whole) the event instantiates or belongs to.",
                     "A council clerk records a new street name in the land registry", {"c.public_administration": 0.6, "c.urban_planning": 0.4}),
    "communicative": _t("What the event conveys, signals or records.",
                        "A union posts the result of its strike ballot on the noticeboard", {"c.labour_organising": 0.7, "c.news_media": 0.3}),
}
_ACP = {
    "act": _t("The kind of act the event is.",
              "A cashier scans a customer's groceries", {"c.retail_work": 1.0}),
    "content": _t("What the event is about.",
                  "A radio talk on pension reform", {"c.welfare_benefits": 0.6, "c.news_media": 0.4}),
    "purpose": _t("What the event serves, read from its observed outputs (the function it performs), never from intentions.",
                  "A weekly food bank hands out parcels and the parcels reach eighty households",
                  {"c.poverty_scarcity": 0.5, "c.charity_giving": 0.5}),
}
VOCABS = {
    "A4": {"title": "A4: form, material, outcome, reference", "types": list(_A4), "defs": _A4},
    "A6": {"title": "A6: A4 plus mechanism and normative", "types": list(_A6), "defs": _A6},
    "R156": {"title": "R156: causal, structural, communicative (Benefuture ruling 8.156)", "types": list(_R156), "defs": _R156},
    "ACP": {"title": "ACP: act, content, purpose", "types": list(_ACP), "defs": _ACP},
}


def task_type(vocab):
    return f"membership.{vocab}"


def vocab_text(vocab):
    """The vocabulary's definitions, one line each, then its worked examples (event and answer per type)."""
    v = VOCABS[vocab]
    lines = [f"# vocabulary {v['title']}", "", "Relation types:"]
    lines += [f"- {t}: {v['defs'][t]['definition']}" for t in v["types"]]
    lines += ["", "Worked examples (one per type, each showing that type's answer alone):"]
    for t in v["types"]:
        ex = v["defs"][t]["example"]
        lines.append(f'- {t}: "{ex["event"]}" gives {t} = {json.dumps(ex["answer"], sort_keys=True)}')
    return "\n".join(lines)


def load_items(gold_dir=DEFAULT_GOLD):
    """The coverage events, then the layer-A red-team cases: [{id, text}]."""
    def rows(name):
        return [json.loads(l) for l in (Path(gold_dir) / name).read_text(encoding="utf-8").splitlines() if l.strip()]
    items = [{"id": r["id"], "text": r["text"]} for r in rows("coverage_events_v0.jsonl")]
    items += [{"id": r["id"], "text": r["text"]} for r in rows("relation_redteam_v0.jsonl") if r.get("layer") == "A"]
    return items


def pack_lines(pack_text):
    """(header, sector lines, field lines) of a pack file, in file order."""
    lines = pack_text.splitlines()
    body = [l for l in lines[1:] if l.count(" | ") == 2]
    return lines[0], [l for l in body if l.startswith("s.")], [l for l in body if not l.startswith("s.")]


def _key(variant, line):
    cid = line.split(" | ")[0]
    return cid if variant == 0 else hashlib.sha256(f"{variant}:{cid}".encode()).hexdigest()


def ungrouped_pack(pack_text, variant=0):
    """The pack with sectors first, then fields, each block ordered for the variant; no field sits under a sector."""
    header, sectors, fields = pack_lines(pack_text)
    order = lambda ls: sorted(ls, key=lambda l: _key(variant, l))
    return "\n".join([header, *order(sectors), *order(fields)]) + "\n"


def build_membership_batches(vocab, items, pack_text, *, model=MODEL, prompt_version=PROMPT_VERSION,
                             prompts_dir=DEFAULT_PROMPTS, k=DEFAULT_K, cache=None):
    """{variant: [header, task lines...]} for the (item, variant) pairs not yet cached."""
    tt = task_type(vocab)
    instructions = (Path(prompts_dir) / f"membership.v{prompt_version}.md").read_text(encoding="utf-8").rstrip("\n")
    pack_hash = content_hash({"pack": ungrouped_pack(pack_text)})[:16]
    batches = {}
    for v in range(k):
        prefix = f"{instructions}\n\n{vocab_text(vocab)}\n\nThe coarse pack follows.\n{ungrouped_pack(pack_text, v)}"
        header = json.dumps({"kind": "header", "task_type": tt, "model": model, "prompt_version": prompt_version,
                             "prefix": prefix}, sort_keys=True, ensure_ascii=False)
        lines = []
        for it in sorted(items, key=lambda i: i["id"]):
            inp = {"item": {"id": it["id"], "text": it["text"]}, "pack": pack_hash}
            h = content_hash(inp)
            if cache is not None and cache.has(tt, h, model, prompt_version, v):
                continue
            lines.append(canonical_json({
                "kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": tt, "prompt_version": prompt_version,
                "input_hash": h, "variant": v, "k": k, "input": inp, "allowed_verdicts": ["membership"]}))
        if lines:
            batches[v] = [header] + lines
    return batches


def write_membership_batches(vocab, batches, out_dir=DEFAULT_OUT, prompt_version=PROMPT_VERSION):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for v, lines in sorted(batches.items()):
        p = out / f"{task_type(vocab)}.v{prompt_version}.var{v}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    return paths
