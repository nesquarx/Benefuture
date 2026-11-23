"""Layer A battery: candidate vocabularies of membership relation types, scored on the same events.

One module holds the vocabularies (a one-line definition and one worked example per type), the item set (the
coverage events plus the layer-A red-team cases) and the batch builder. Task type `membership.<VOCAB>` v1: the
batch prefix is the instructions, the vocabulary's definitions and the coarse pack; each task is one item's text.

Battery v2 (prompt version 2) adds A3 (form, content, outcome) and A3S (A3 plus setting). Every v2 vocabulary also
carries the placebo type `flavour`, meaningless by design: its fill rate and agreement are the noise floor, so the
metrics report it apart and leave it out of vocabulary means. Minimal pairs (`data/gold/minimal_pairs_v0.jsonl`)
join the item set as `mp.<pair id>.a` and `.b` (a text already in the set keeps its id).

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

PLACEBO = "flavour"


def _t2(definition, examples):
    """A type with several worked examples [(event, answer)]; `example` stays the first, as in v1."""
    ex = [{"event": e, "answer": a} for e, a in examples]
    return {"definition": definition, "example": ex[0], "examples": ex}


# Four events shared by every v2 type, so each type's answer to the same event can be compared: a film watched,
# a review written of it, a vaccination (a prevented harm), an actor playing a surgeon (depiction).
E_FILM = "Two friends watch a documentary about glaciers at a cinema"
E_REVIEW = "A critic writes a review of a documentary about glaciers and a weekly paper prints it"
E_VACC = "A nurse gives a child a measles vaccination at a clinic, and the child stays well through the outbreak that follows"
E_ACTOR = "An actor plays a surgeon in a hospital drama filmed in a studio"

_FORM2 = _t2("What kind of act or thing the event is: the act itself, apart from its subject matter and effects. "
             "Depicting an act is a different act from doing it.",
             [(E_FILM, {"c.film_tv_video": 1.0}),
              (E_REVIEW, {"c.media_publishing": 0.5, "c.journalism": 0.5}),
              (E_VACC, {"c.medical_care": 1.0}),
              (E_ACTOR, {"c.performing_arts": 1.0})])
_CONTENT2 = _t2("What the event is about or engages: its subject matter or object domain, one type, never split "
                "into carrier, input or reference. Watching a film and reviewing it share the film as content.",
                [(E_FILM, {"c.earth_sciences": 0.5, "c.film_tv_video": 0.5}),
                 (E_REVIEW, {"c.film_tv_video": 0.6, "c.earth_sciences": 0.4}),
                 (E_VACC, {"c.preventive_health": 0.6, "c.public_health_science": 0.4}),
                 (E_ACTOR, {"c.medical_care": 1.0})])
_OUTCOME2 = _t2("What observably changed relative to what would otherwise have happened; a prevented harm counts. "
                "Never intentions. Null when nothing observable differs from the counterfactual.",
                [(E_FILM, None),
                 (E_REVIEW, {"c.news_media": 1.0}),
                 (E_VACC, {"c.preventive_health": 0.7, "c.physical_health": 0.3}),
                 (E_ACTOR, {"c.film_tv_video": 1.0})])
_SETTING2 = _t2("Where, or in which sphere of life, the event takes place (a venue, institution or sphere). "
                "Null when the text gives no place.",
                [(E_FILM, {"c.nightlife": 1.0}),
                 (E_REVIEW, None),
                 (E_VACC, {"c.medical_care": 1.0}),
                 (E_ACTOR, {"c.film_tv_video": 1.0})])
_FLAVOUR2 = _t2("The domain whose flavour the event has. Null when no domain's flavour stands out.",
                [(E_FILM, {"c.film_tv_video": 1.0}),
                 (E_REVIEW, {"c.media_publishing": 1.0}),
                 (E_VACC, None),
                 (E_ACTOR, None)])
_A3 = {"form": _FORM2, "content": _CONTENT2, "outcome": _OUTCOME2, PLACEBO: _FLAVOUR2}
_A3S = {"form": _FORM2, "content": _CONTENT2, "outcome": _OUTCOME2, "setting": _SETTING2, PLACEBO: _FLAVOUR2}

VOCABS = {
    "A4": {"title": "A4: form, material, outcome, reference", "types": list(_A4), "defs": _A4},
    "A6": {"title": "A6: A4 plus mechanism and normative", "types": list(_A6), "defs": _A6},
    "R156": {"title": "R156: causal, structural, communicative (Benefuture ruling 8.156)", "types": list(_R156), "defs": _R156},
    "ACP": {"title": "ACP: act, content, purpose", "types": list(_ACP), "defs": _ACP},
    "A3": {"title": "A3: form, content, outcome (plus the placebo type flavour)", "types": list(_A3), "defs": _A3},
    "A3S": {"title": "A3S: A3 plus setting (plus the placebo type flavour)", "types": list(_A3S), "defs": _A3S},
}
V1_VOCABS = ["A4", "A6", "R156", "ACP"]


def real_types(vocab):
    """The vocabulary's types without the placebo."""
    return [t for t in VOCABS[vocab]["types"] if t != PLACEBO]


def task_type(vocab):
    return f"membership.{vocab}"


def vocab_text(vocab):
    """The vocabulary's definitions, one line each, then its worked examples (event and answer per type)."""
    v = VOCABS[vocab]
    lines = [f"# vocabulary {v['title']}", "", "Relation types:"]
    lines += [f"- {t}: {v['defs'][t]['definition']}" for t in v["types"]]
    many = any("examples" in v["defs"][t] for t in v["types"])
    lines += ["", "Worked examples (%s, each showing that type's answer alone):" % (
        "four per type" if many else "one per type")]
    for t in v["types"]:
        for ex in v["defs"][t].get("examples", [v["defs"][t]["example"]]):
            lines.append(f'- {t}: "{ex["event"]}" gives {t} = {json.dumps(ex["answer"], sort_keys=True)}')
    return "\n".join(lines)


def load_items(gold_dir=DEFAULT_GOLD):
    """The coverage events, then the layer-A red-team cases: [{id, text}]."""
    def rows(name):
        return [json.loads(l) for l in (Path(gold_dir) / name).read_text(encoding="utf-8").splitlines() if l.strip()]
    items = [{"id": r["id"], "text": r["text"]} for r in rows("coverage_events_v0.jsonl")]
    items += [{"id": r["id"], "text": r["text"]} for r in rows("relation_redteam_v0.jsonl") if r.get("layer") == "A"]
    return items


def load_pairs(gold_dir=DEFAULT_GOLD):
    """The minimal pairs: [{id, a, b, should_differ_in, note, ...}]."""
    p = Path(gold_dir) / "minimal_pairs_v0.jsonl"
    return [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()]


def pair_ids(pair_id):
    return f"mp.{pair_id}.a", f"mp.{pair_id}.b"


def load_items_v2(gold_dir=DEFAULT_GOLD):
    """The 192 items, then the minimal-pair texts, deduplicated by text (case-insensitive): a text already in
    the set keeps the earlier id."""
    items = load_items(gold_dir)
    seen = {i["text"].strip().lower() for i in items}
    for p in load_pairs(gold_dir):
        for side, iid in zip("ab", pair_ids(p["id"])):
            key = p[side].strip().lower()
            if key not in seen:
                seen.add(key)
                items.append({"id": iid, "text": p[side]})
    return items


def text_index(items):
    """Lower-cased text -> item id."""
    return {i["text"].strip().lower(): i["id"] for i in items}


def pair_item_ids(pair, items):
    """The item ids carrying the pair's two texts (the pair's own ids unless a text was deduplicated)."""
    idx = text_index(items)
    return idx[pair["a"].strip().lower()], idx[pair["b"].strip().lower()]


def stratified_subset(items, pairs, *, n_events=24, n_redteam=10, n_pairs=8):
    """50 items in three strata, evenly spaced over a stable order: coverage events (ordered by their first
    expected field), layer-A red-team cases (by id), and whole minimal pairs (kinds taken round-robin)."""
    def spaced(seq, n):
        n = min(n, len(seq))
        return [seq[(2 * i + 1) * len(seq) // (2 * n)] for i in range(n)]
    gold = {r["id"]: r for r in (json.loads(l) for l in (DEFAULT_GOLD / "coverage_events_v0.jsonl").read_text().splitlines() if l.strip())}
    ev = sorted((i for i in items if i["id"].startswith("ev.")), key=lambda i: ((gold[i["id"]]["expected_fields"] or [""])[0], i["id"]))
    rt = sorted((i for i in items if i["id"].startswith("rt.")), key=lambda i: i["id"])
    by_kind = {}
    for p in sorted(pairs, key=lambda p: p["id"]):
        by_kind.setdefault(p["should_differ_in"], []).append(p)
    order = []
    while any(by_kind.values()):
        for k in sorted(by_kind):
            if by_kind[k]:
                order.append(by_kind[k].pop(0))
    byid = {i["id"]: i for i in items}
    chosen = spaced(ev, n_events) + spaced(rt, n_redteam)
    for p in order[:n_pairs]:
        chosen += [byid[x] for x in pair_item_ids(p, items)]
    seen, out = set(), []
    for i in chosen:
        if i["id"] not in seen:
            seen.add(i["id"])
            out.append(i)
    return sorted(out, key=lambda i: i["id"])


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


def pack_hash(pack_text):
    return content_hash({"pack": ungrouped_pack(pack_text)})[:16]


def item_input(item, phash):
    """The task input of one item, shared by the batch builder and the answer lookup."""
    return {"item": {"id": item["id"], "text": item["text"]}, "pack": phash}


def build_membership_batches(vocab, items, pack_text, *, model=MODEL, prompt_version=PROMPT_VERSION,
                             prompts_dir=DEFAULT_PROMPTS, k=DEFAULT_K, cache=None):
    """{variant: [header, task lines...]} for the (item, variant) pairs not yet cached."""
    tt = task_type(vocab)
    instructions = (Path(prompts_dir) / f"membership.v{prompt_version}.md").read_text(encoding="utf-8").rstrip("\n")
    phash = pack_hash(pack_text)
    batches = {}
    for v in range(k):
        prefix = f"{instructions}\n\n{vocab_text(vocab)}\n\nThe coarse pack follows.\n{ungrouped_pack(pack_text, v)}"
        header = json.dumps({"kind": "header", "task_type": tt, "model": model, "prompt_version": prompt_version,
                             "prefix": prefix}, sort_keys=True, ensure_ascii=False)
        lines = []
        for it in sorted(items, key=lambda i: i["id"]):
            inp = item_input(it, phash)
            h = content_hash(inp)
            if cache is not None and cache.has(tt, h, model, prompt_version, v):
                continue
            lines.append(canonical_json({
                "kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": tt, "prompt_version": prompt_version,
                "input_hash": h, "variant": v, "k": k, "input": inp, "allowed_verdicts": ["membership"]}))
        if lines:
            batches[v] = [header] + lines
    return batches


def write_batch_file(path, lines):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    return Path(path)


def write_membership_batches(vocab, batches, out_dir=DEFAULT_OUT, prompt_version=PROMPT_VERSION):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for v, lines in sorted(batches.items()):
        p = out / f"{task_type(vocab)}.v{prompt_version}.var{v}.jsonl"
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(p)
    return paths
