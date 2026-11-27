"""LI.70: two-pass extraction.

Pass 1, blind (`prompts/blind.v1.md`): a runner reads an event, of any detail, and suggests its categories in its own words for each
relation (form, content, outcome, setting) with a fit and a gloss, plus the relational extraction of LI.65. It never sees the domain
set: no domain id appears in the prefix or the input (`validate.validate_blind_answer` rejects any in the answer).

Pass 2, map (`prompts/map.v1.md`): a runner with the domain pack (coarse and fine, aliases, short descriptions) and the pass-1 answer
allocates every blind label to a domain id (exact or synonym, with a match confidence), builds the memberships by the v4 stopping
rule (floor 5) from the matched domains only, and reviews every label that matched nothing: `new_domain_candidate` or `noise`.
Pass 2 reads only validated pass-1 answers, and its input hash includes the pass-1 answer hash. Variant v of pass 2 reads variant v of
pass 1, so the two chains stay independent; the variants of pass 2 differ in pack order, those of pass 1 in the order the relations are
read (the prefix is otherwise one stable text, for cache hits; every variable part is in the task lines).

Pass 2 `map.v2` (LI.70 refined by `data/gold/two_pass_diagnosis.md`, the hybrid): the memberships are built by the v4 rule from the event text over
the whole pack, the blind labels being hints; a label may match several domains (a fine domain and its coarse parent: one `match` entry each), and
a listed domain no label of its relation matched is named in `unlabelled_add`. Synonym logging and the review of unmatched labels stay. `map.v1`
(one label, one domain, memberships from matched domains only) stays reproducible (`MAP_VERSION`, the default; `LATEST_MAP_VERSION` is v2).

The ingest merges the 2 variants (agreement as confidence, escalation on disagreement) into a memberships table, aggregates the synonyms
(blind label to domain, with counts and match confidence) into `data/refinement/synonyms_v1.jsonl` (feeds domain aliases), and writes the
candidate new domains to the refinement log with source `blind_unmatched` (LI.68, LI.69). Candidates and noise never enter memberships.
No model is run here.
"""
import json
import re
from collections import defaultdict
from pathlib import Path

from .canonical import canonical_json, content_hash
from .governed import governed, membership_fit_floor
from .membership import DEFAULT_OUT, MODEL
from .membership_wide import (REFINEMENT_DIR as _MW_REFINEMENT_DIR, calibration_items, calibration_report, merge_item,  # noqa: F401
                              merged_calibration_report, answers_by_item, snippet_items)
from .packs import domain_pack, pack_entries  # noqa: F401
from .refinement import RELS, append_candidates, blind_unmatched_record, log_candidates, read_log, text_hash
from .tasks import DEFAULT_PROMPTS
from .validate import (BLIND_RELS, ValidationError, blind_refs, domain_ids_in, norm_label, validate_answers,  # noqa: F401
                       validate_blind_answer, validate_map_answer)

ROOT = Path(__file__).resolve().parent.parent
BLIND_TASK, MAP_TASK = "blind", "map"
BLIND_VERSION = MAP_VERSION = 1  # the defaults keep the first versions reproducible
LATEST_BLIND_VERSION = 2  # LI.71: weighted categories from the most specific to the most generic (`prompts/blind.v2.md`); v1 stays reproducible
LATEST_MAP_VERSION = 2  # the hybrid pass 2 (`prompts/map.v2.md`): memberships from the event text, labels as hints
VARIANTS = 2
MAX_TASKS = 50
PILOT_SNIPPETS = 50
REFINEMENT_DIR = _MW_REFINEMENT_DIR
SYNONYMS = ROOT / "data" / "refinement" / "synonyms_v1.jsonl"
TABLE = ROOT / "data" / "events" / "two_pass_memberships_v1.jsonl"
ESCALATIONS = ROOT / "data" / "answers" / "escalations.two_pass.jsonl"
REPORT = ROOT / "data" / "gold" / "two_pass_report.json"


def _versioned(path, version):
    if version == 1:
        return path
    name = path.name
    return path.with_name(name.replace("_v1.", f"_v{version}.") if "_v1." in name else f"{path.stem}.v{version}{path.suffix}")


def table_path(version=MAP_VERSION):
    """The memberships table of a pass-2 prompt version (the v1 table keeps its path)."""
    return _versioned(TABLE, version)


def escalation_path(version=MAP_VERSION):
    return _versioned(ESCALATIONS, version)


def report_path(version=MAP_VERSION):
    return REPORT if version == 1 else REPORT.with_name(f"two_pass_report_v{version}.json")
COARSE_CARDS = ROOT / "data" / "coarse" / "seed_v3.jsonl"
FINE_CARDS = ROOT / "data" / "fine" / "fine_v1.jsonl"
READING_ORDER = {0: ("form", "content", "outcome", "setting"), 1: ("setting", "outcome", "content", "form")}


def _header(task_type, prompt_version, prefix, model):
    return json.dumps({"kind": "header", "task_type": task_type, "model": model, "prompt_version": prompt_version, "prefix": prefix},
                      sort_keys=True, ensure_ascii=False)


def _instructions(task_type, prompt_version, prompts_dir):
    return (Path(prompts_dir) / f"{task_type}.v{prompt_version}.md").read_text(encoding="utf-8").rstrip("\n")


def _parts(lines, max_tasks):
    return {p // max_tasks: lines[p:p + max_tasks] for p in range(0, len(lines), max_tasks)}


def _write(name, task_type, prompt_version, batches, out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for (v, p), lines in sorted(batches.items()):
        path = out / f"{task_type}.v{prompt_version}.{name}.var{v}.part{p}.jsonl"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(path)
    return paths


# ---- pass 1 ----
def pilot_items():
    """The pilot item sets: the 32 membership calibration controls and 50 calibration event snippets."""
    return {"controls": calibration_items(), "snippets": snippet_items(PILOT_SNIPPETS)}


def blind_prefix(variant, prompt_version=BLIND_VERSION, prompts_dir=DEFAULT_PROMPTS):
    order = ", ".join(READING_ORDER[variant % len(READING_ORDER)])
    return (f"{_instructions(BLIND_TASK, prompt_version, prompts_dir)}\n\n## Reading order\n\nIn this reading, think through the relations "
            f"in this order: {order}. The answer object keeps its four keys.\n")


def blind_input(item):
    return {"item": {"id": item["id"], "text": item["text"]}}


def build_blind_batches(items, *, variants=VARIANTS, max_tasks=MAX_TASKS, prompt_version=BLIND_VERSION, model=MODEL, prompts_dir=DEFAULT_PROMPTS):
    """{(variant, part): [header, task lines...]}: the header of variant v holds the instructions and the reading order of v (no domain id,
    the same in every part), each part at most `max_tasks` tasks sorted by item id."""
    batches = {}
    for v in range(variants):
        header = _header(BLIND_TASK, prompt_version, blind_prefix(v, prompt_version, prompts_dir), model)
        lines = []
        for it in sorted(items, key=lambda i: i["id"]):
            inp = blind_input(it)
            h = content_hash(inp)
            lines.append(canonical_json({"kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": BLIND_TASK, "prompt_version": prompt_version,
                                         "input_hash": h, "variant": v, "k": variants, "input": inp, "allowed_verdicts": ["blind"]}))
        for p, chunk in _parts(lines, max_tasks).items():
            batches[(v, p)] = [header] + chunk
    return batches


def write_blind_batches(name, batches, out_dir=DEFAULT_OUT, prompt_version=BLIND_VERSION):
    return _write(name, BLIND_TASK, prompt_version, batches, out_dir)


def pilot_blind_batches(out_dir=DEFAULT_OUT, prompt_version=BLIND_VERSION, sets=None):
    """Write the pass-1 pilot batches (controls, snippets, or the named `sets`; 2 variants; at most 50 per file) of a prompt version; returns the paths."""
    paths = []
    for name, items in pilot_items().items():
        if sets is None or name in sets:
            paths += write_blind_batches(name, build_blind_batches(items, prompt_version=prompt_version), out_dir, prompt_version)
    return paths


# ---- pass 2 ----
def load_domain_cards(coarse=COARSE_CARDS, fine=FINE_CARDS):
    return [json.loads(l) for p in (coarse, fine) for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]


def blind_view(answer):
    """What the mapper sees of a pass-1 answer: the labels per relation with refs `<relation>.<index>`."""
    return {rel: None if answer["blind"][rel] is None else
            [{"ref": f"{rel}.{i}", "label": e["label"], **({"fit": e["fit"]} if "fit" in e else {"weight": e["weight"]}), "gloss": e["gloss"]}
             for i, e in enumerate(answer["blind"][rel])]
            for rel in BLIND_RELS}


def pass1_hash(answer):
    """The hash of what pass 1 produced (its categories and relational extraction), carried in every pass-2 input."""
    return content_hash({"blind": answer["blind"], "relational": answer["relational"]})


def map_prefix(cards, variant, prompt_version=MAP_VERSION, prompts_dir=DEFAULT_PROMPTS):
    return f"{_instructions(MAP_TASK, prompt_version, prompts_dir)}\n\nThe domain pack follows.\n{domain_pack(cards, variant)}"


def build_map_batches(blind_pairs, cards, *, variants=VARIANTS, max_tasks=MAX_TASKS, prompt_version=MAP_VERSION, model=MODEL,
                      prompts_dir=DEFAULT_PROMPTS):
    """{(variant, part): [header, task lines...]} of pass 2 over validated pass-1 answers (`blind_pairs`: (batch, answers) paths; raises
    ValueError on an invalid answer). Variant v reads the pass-1 variant v. The input holds the item, the blind labels, the pass-1 input and
    answer hashes and the pack hash, so a changed pass-1 answer is a different task."""
    got = answers_by_item(blind_pairs)
    phash = content_hash({"pack": domain_pack(cards, 0)})[:16]
    batches = {}
    for v in range(variants):
        header = _header(MAP_TASK, prompt_version, map_prefix(cards, v, prompt_version, prompts_dir), model)
        lines = []
        for key in sorted(got):
            if v not in got[key]:
                raise ValueError(f"{key}: no pass-1 answer from variant {v}")
            text, ans = got[key][v]
            inp = {"item": {"id": key, "text": text}, "blind": blind_view(ans),
                   "pass1": {"input_hash": ans["input_hash"], "answer_hash": pass1_hash(ans)}, "pack": phash}
            h = content_hash(inp)
            lines.append(canonical_json({"kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": MAP_TASK, "prompt_version": prompt_version,
                                         "input_hash": h, "variant": v, "k": variants, "input": inp, "allowed_verdicts": ["map"]}))
        for p, chunk in _parts(lines, max_tasks).items():
            batches[(v, p)] = [header] + chunk
    return batches


def write_map_batches(name, batches, out_dir=DEFAULT_OUT, prompt_version=MAP_VERSION):
    return _write(name, MAP_TASK, prompt_version, batches, out_dir)


def pilot_map_batches(version=LATEST_MAP_VERSION, out_dir=DEFAULT_OUT, blind_dir=DEFAULT_OUT, cards=None):
    """Write the pass-2 pilot batches (`map.v<version>.{controls,snippets}`, 2 variants, at most 50 per file) from the validated pass-1 answers in
    `blind_dir`; returns the paths. Raises ValueError when a pass-1 answers file is missing."""
    cards = load_domain_cards() if cards is None else cards
    paths = []
    for name in pilot_items():
        pairs = []
        for v in range(VARIANTS):
            bp = Path(blind_dir) / f"{BLIND_TASK}.v{BLIND_VERSION}.{name}.var{v}.part0.jsonl"
            ap = bp.with_name(bp.name.replace(".jsonl", ".answers.jsonl"))
            if not ap.exists():
                raise ValueError(f"pass-1 answers missing: {ap.name}")
            pairs.append((bp, ap))
        paths += write_map_batches(name, build_map_batches(pairs, cards, prompt_version=version), out_dir, version)
    return paths


# ---- merging ----
def merge_blind(key, variant_answers):
    """Merge the variants' pass-1 answers of one item: per relation the labels (normalised, with the mean fit over the variants that gave
    them and the share of variants behind each), the Jaccard agreement of the label sets as confidence, and an escalation only when a
    relation applies in some variants and not in others (label wording differs between runs without disagreement; the domain-level
    disagreement is escalated by the pass-2 merge)."""
    k = len(variant_answers)
    labels, confidence, reasons = {}, {}, []
    for rel in BLIND_RELS:
        per = [a["blind"][rel] for _, a in sorted(variant_answers.items())]
        given = [p for p in per if p]
        if not given:
            labels[rel] = None
            continue
        if len(given) < k:
            reasons.append(f"{rel}: applies in {len(given)} of {k} variants")
        by = defaultdict(list)
        names = {}
        for p in given:
            for e in p:
                n = norm_label(e["label"])
                by[n].append(e["fit"])
                names.setdefault(n, e["label"])
        sets = [{norm_label(e["label"]) for e in p} for p in given]
        union = set().union(*sets)
        jac = len(set.intersection(*sets)) / len(union) if len(given) == k else 0.0
        order = sorted(by, key=lambda n: (-sum(by[n]) / len(by[n]), n))
        labels[rel] = [{"label": names[n], "fit": sum(by[n]) / len(by[n]), "variants": len(by[n])} for n in order]
        confidence[rel] = {"agreement": jac, "labels": {n: len(by[n]) / k for n in order}}
    return {"key": key, "variants": k, "labels": labels, "confidence": confidence, "escalate": bool(reasons), "escalate_reasons": reasons}


# ---- the ledgers: synonyms and candidates ----
def _read_map(pairs):
    """[(task, answer)] over validated (batch, answers) path pairs of pass 2."""
    out = []
    for bp, ap in pairs:
        b = Path(bp).read_text(encoding="utf-8").splitlines()
        a = Path(ap).read_text(encoding="utf-8").splitlines()
        errs = validate_answers(b, a)
        if errs:
            raise ValueError(f"{ap}: {len(errs)} validation errors, first: {errs[0]}")
        tasks = {json.loads(l)["task_id"]: json.loads(l) for l in b[1:]}
        out += [(tasks[json.loads(l)["task_id"]], json.loads(l)) for l in a]
    return out


def synonym_cells(task, answer):
    """{cell: observation} of every matched label of one pass-2 answer. A cell is item, variant, pass-1 answer hash and ref, so reading
    the same answers again changes nothing."""
    item, v, ah = task["input"]["item"]["id"], task["variant"], task["input"]["pass1"]["answer_hash"][:8]
    refs = blind_refs(task)
    out = {}
    for e in answer["labels"]:
        if e["action"] == "match":
            rel, blind = refs[e["ref"]]
            cell = f"{item}|v{v}|{ah}|{e['ref']}" + (f"|{e['domain']}" if answer["prompt_version"] >= 2 else "")  # v2: a label may match several domains
            out[cell] = {"label": norm_label(blind["label"]), "domain": e["domain"], "relation": rel,
                                                  "kind": e["kind"], "match": e["match"], "item": item}
    return out


def update_synonyms(cells, path):
    """Merge observation cells into the synonym log at path: one record per (label, domain) with count, distinct items, kinds, relations
    and mean match confidence, plus its cells (which make a re-read idempotent). Rewritten sorted by label and domain; returns the records."""
    merged = {}
    for r in read_log(path):
        merged.update(r["cells"])
    merged.update(cells)
    groups = defaultdict(dict)
    for c, o in merged.items():
        groups[(o["label"], o["domain"])][c] = o
    recs = []
    for (label, domain), cs in sorted(groups.items()):
        kinds, rels = defaultdict(int), defaultdict(int)
        for o in cs.values():
            kinds[o["kind"]] += 1
            rels[o["relation"]] += 1
        recs.append({"label": label, "domain": domain, "count": len(cs), "items": len({o["item"] for o in cs.values()}),
                     "kinds": dict(sorted(kinds.items())), "relations": dict(sorted(rels.items())),
                     "match_mean": round(sum(o["match"] for o in cs.values()) / len(cs), 4), "cells": dict(sorted(cs.items()))})
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text("".join(json.dumps(r, sort_keys=True, ensure_ascii=False) + "\n" for r in recs), encoding="utf-8")
    return recs


def blind_candidates(task, answer):
    """Refinement records (source `blind_unmatched`) of the new-domain candidates of one pass-2 answer."""
    refs = blind_refs(task)
    item = task["input"]["item"]
    return [blind_unmatched_record(item["id"], item["text"], task["variant"], answer["prompt_version"], *refs[e["ref"]], e)
            for e in answer["labels"] if e["action"] == "new_domain_candidate"]


def unlabelled_adds(variant_answers):
    """{relation: {domain: share of the variants naming it an `unlabelled_add`}} of one item's pass-2 answers (empty before `map.v2`)."""
    k = len(variant_answers)
    out = {}
    for _, a in sorted(variant_answers.items()):
        for e in a.get("unlabelled_add", []):
            out.setdefault(e["relation"], {}).setdefault(e["domain"], 0)
            out[e["relation"]][e["domain"]] += 1 / k
    return {r: dict(sorted(d.items())) for r, d in sorted(out.items())}


# ---- the ingest ----
def ingest_two_pass(blind_pairs, map_pairs, out_path=TABLE, *, synonyms_path=SYNONYMS, escalation_path=ESCALATIONS, refinement_dir=None,
                    variants=VARIANTS, merge=None):
    """Merge pass 1 and pass 2 answers (path pairs of batch and answers files; every variant of every item) into the table at out_path
    (one row per item: the merged memberships with agreement as confidence, the merged blind labels, the pass-1 relational extraction per
    variant), write the escalations (one record per escalated item), update the synonym log and log the new-domain candidates to the
    refinement log (never into the table). `merge` names the variant merge rule (`membership_wide.MERGE_RULES`, default the support-weighted union). A pass-2 answer built on another pass-1 answer than the one read is refused. Returns the rows."""
    blind = answers_by_item(blind_pairs)
    got = defaultdict(dict)
    cells, cands = {}, []
    for task, ans in _read_map(map_pairs):
        key, v = task["input"]["item"]["id"], task["variant"]
        if key not in blind or v not in blind[key]:
            raise ValueError(f"{key}: pass-2 variant {v} has no pass-1 answer")
        if task["input"]["pass1"]["answer_hash"] != pass1_hash(blind[key][v][1]):
            raise ValueError(f"{key}: pass-2 variant {v} was built on a different pass-1 answer than the one read")
        got[key][v] = (task, ans)
        cells.update(synonym_cells(task, ans))
        cands += blind_candidates(task, ans)
    rows, esc = [], []
    for key in sorted(got):
        per = got[key]
        if len(per) != variants:
            raise ValueError(f"{key}: pass-2 answers from variants {sorted(per)}, expected {variants}")
        text = blind[key][min(per)][0]
        row = merge_item(key, text, {v: a for v, (_, a) in per.items()}, rule=merge)
        mb = merge_blind(key, {v: blind[key][v][1] for v in per})
        row["blind"] = {"labels": mb["labels"], "confidence": mb["confidence"]}
        row["relational"] = {str(v): blind[key][v][1]["relational"] for v in sorted(per)}
        row["pass"] = "two_pass"
        row["map_version"] = next(iter(per.values()))[1]["prompt_version"]
        row["unlabelled_add"] = unlabelled_adds({v: a for v, (_, a) in per.items()})
        row["escalate_reasons"] = row["escalate_reasons"] + [f"blind {r}" for r in mb["escalate_reasons"]]
        row["escalate"] = bool(row["escalate_reasons"])
        rows.append(row)
        if row["escalate"]:
            esc.append({"key": key, "text": text, "reasons": row["escalate_reasons"],
                        "variants": {str(v): {r: a["ranks"][r] for r in RELS} for v, (_, a) in sorted(per.items())}})
    for path, recs in ((out_path, rows), (escalation_path, esc)):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text("".join(canonical_json(r) + "\n" for r in recs), encoding="utf-8")
    update_synonyms(cells, synonyms_path)
    log_candidates(cands, REFINEMENT_DIR if refinement_dir is None else refinement_dir)
    return rows


# ---- the judge ----
def two_pass_report(controls, blind_by_item, map_by_item, *, synonyms, candidates, v4_recall, floor=None, complete_gold=False):
    """Judge the pre-registered predictions (`data/gold/two_pass_predictions.md`). `blind_by_item`, `map_by_item`: {item: {variant: (text,
    answer)}}. Recall of the gold-required domains and precision among judged secondaries come from the v4 calibration judge applied to the
    pass-2 memberships, pooled over the variants (`recall_required`), for each variant (`recall_by_variant`) and for the merged lists
    (`recall_required_merged`, the default merge rule); synonyms are the distinct (label, domain) pairs of kind synonym; candidates the
    distinct proposed new domains of the refinement records of source `blind_unmatched` (every one reviewed non-noise by the mapper); pass-1
    labels are checked structurally; `escalated_controls` counts the controls the merge escalates, `unlabelled_adds` the `unlabelled_add`
    entries of map.v2 answers (0 for map.v1)."""
    floor = membership_fit_floor(4) if floor is None else floor
    rep = calibration_report(controls, map_by_item, floor=floor, prompt_version=4, complete_gold=complete_gold)
    variants = sorted({v for per in map_by_item.values() for v in per})
    by_variant = {}
    for v in variants:
        one = {k: {v: per[v]} for k, per in map_by_item.items() if v in per}
        by_variant[v] = calibration_report(controls, one, floor=floor, prompt_version=4, complete_gold=complete_gold)["recall_required"]
    merged = merged_calibration_report(controls, map_by_item, floor=floor, prompt_version=4, complete_gold=complete_gold)
    cids = {c["id"] for c in controls}
    escalated = sum(1 for k, per in map_by_item.items() if k in cids and len(per) > 1
                    and merge_item(k, "", {v: a for v, (_, a) in per.items()})["escalate"])
    ids = sum(len(domain_ids_in(s)) for per in blind_by_item.values() for _, (_, a) in per.items()
              for s in _strings_of(a))
    syn = {(s["label"], s["domain"]) for s in synonyms if s["kinds"].get("synonym")}
    new = {c["domain"] for c in candidates if c["source"] == "blind_unmatched"}
    answers = [a for per in map_by_item.values() for _, (_, a) in per.items()]
    noise = sum(1 for a in answers for e in a["labels"] if e["action"] == "noise")
    unmatched = sum(1 for a in answers for e in a["labels"] if e["action"] != "match")
    adds = sum(len(a.get("unlabelled_add", [])) for a in answers)
    rec, prec, mrec = rep["recall_required"], rep["precision_judged"], merged["recall_required"]
    out = {
        "recall_required": rec, "recall_by_variant": by_variant, "recall_required_merged": mrec,
        "precision_secondary_merged": merged["precision_secondary"], "padding_single_merged": merged["padding_single"],
        "recall_v4": v4_recall, "precision_judged": prec, "precision_secondary": rep["precision_secondary"],
        "n_unjudged": rep["n_unjudged"], "n_bad": rep["n_bad"], "median_listed": rep["median_listed"],
        "distinct_synonyms": len(syn), "new_domain_candidates": len(new), "noise_labels": noise, "unmatched_labels": unmatched,
        "unlabelled_adds": adds, "escalated_controls": escalated, "controls": len(cids & set(map_by_item)),
        "pass1_domain_ids": ids, "items": len(map_by_item),
        "predictions": {
            "recall_at_least_v4_minus_0.05": rec is not None and rec >= v4_recall - 0.05,
            "recall_each_variant_at_least_0.913": bool(by_variant) and all(r is not None and r >= 0.913 for r in by_variant.values()),
            "recall_merged_at_least_0.926": mrec is not None and mrec >= 0.926,
            "precision_judged_at_least_0.95": prec is not None and prec >= 0.95,
            "escalated_controls_at_most_24_of_32": escalated <= 24,
            "at_least_10_synonyms": len(syn) >= 10,
            "at_least_3_candidates": len(new) >= 3,
            "pass1_labels_never_contain_domain_ids": ids == 0,
        },
    }
    if complete_gold:
        out["padding_single_complete_merged"] = merged["padding_single_complete"]
    return out


def _strings_of(answer):
    from .validate import _strings
    return list(_strings({"blind": answer["blind"], "relational": answer["relational"]}))


# ---- blind.v2 (LI.71): thin lists and the judge of the pre-registered predictions ----
def thin_relations(answer, minimum=None):
    """The relations of a `blind.v2` answer listing fewer than `blind.v2.min_labels` categories (an `unknown` marker is not a category; a null
    outcome lists none)."""
    from .validate import BLIND_UNKNOWN
    minimum = governed("blind.v2.min_labels") if minimum is None else minimum
    return [rel for rel in BLIND_RELS
            if len([e for e in answer["blind"][rel] or [] if norm_label(e["label"]) != BLIND_UNKNOWN]) < minimum]


def _median(xs):
    xs = sorted(xs)
    n = len(xs)
    return None if not n else (xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2)


def blind_v2_report(blind_by_item, judged, *, partial_credit=0.5):
    """Judge `data/gold/blind_v2_predictions.md`. `blind_by_item`: {item: {variant: (text, answer)}} of validated `blind.v2` answers; `judged`:
    [(label_match task, answer)] (empty before the judge has run). Counts are real categories (the `unknown` marker excluded, a null outcome is 0);
    the author-match share of a relation is (match + partial_credit x partial) over the author's labels of that relation, pooled over the two
    author items and the variants; cooking counts the d01 form and content labels containing the word cook."""
    from .validate import BLIND_UNKNOWN
    answers = [(k, v, a) for k, per in sorted(blind_by_item.items()) for v, (_, a) in sorted(per.items())]
    counts = {rel: [len([e for e in a["blind"][rel] or [] if norm_label(e["label"]) != BLIND_UNKNOWN]) for _, _, a in answers] for rel in BLIND_RELS}
    med = {rel: _median(counts[rel]) for rel in ("form", "content", "outcome")}
    present = sum(1 for _, _, a in answers if a["blind"]["outcome"]) / len(answers) if answers else None
    cooking = sum(1 for k, _, a in answers if k == "cal.d01" for rel in ("form", "content") for e in a["blind"][rel] or []
                  if re.search(r"\bcook", e["label"].lower()))
    share, strict = {}, {}
    for rel in BLIND_RELS:
        rows = [a["verdict"] for t, a in judged if t["input"]["relation"] == rel]
        if rows:
            share[rel] = (rows.count("match") + partial_credit * rows.count("partial")) / len(rows)
            strict[rel] = rows.count("match") / len(rows)
    out = {
        "median_labels": med, "outcome_present": present, "cooking_in_d01_form_or_content": cooking,
        "author_match_share": share, "author_match_strict": strict, "n_answers": len(answers), "n_judged": len(judged),
        "thin_answers": sum(1 for _, _, a in answers if thin_relations(a)),
        "setting_unknown": sum(1 for _, _, a in answers if any(norm_label(e["label"]) == BLIND_UNKNOWN for e in a["blind"]["setting"])),
        "predictions": {
            "median_labels_at_least_4": bool(answers) and all(m is not None and m >= 4 for m in med.values()),
            "outcome_present_at_least_0.9": present is not None and present >= 0.9,
            "author_match_at_least_0.6_each_relation": (set(share) == set(BLIND_RELS) and all(x >= 0.6 for x in share.values())) if share else None,
            "no_cooking_in_cal_d01_form_or_content": cooking == 0,
        },
    }
    return out
