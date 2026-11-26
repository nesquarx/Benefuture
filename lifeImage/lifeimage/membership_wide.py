"""LI.67: wide event memberships by a ranked stopping rule: items, runner batches, the calibration judge and the ingest.

Prompt `membership.v3` asks, per relation (form, content, outcome, setting), for the domains in decreasing weight, primary
first, listing each while its fit score (0-10) is at least the governed floor (`membership.fit_floor`) and recording the best
rejected domain (`validate.validate_ranked_types` enforces it). This module builds the batches (the control battery that
calibrates the floor, the generated event kinds, a sample of calibration snippets: 2 variants, at most 50 tasks per file),
judges the battery, and merges the variants' answers into the table the event generator can read later
(`data/events/kind_memberships_v1.jsonl`): the agreed domains with their weights, the agreement as confidence, the
disagreements escalated. No model is run here.

The batch prefix is the instructions and the coarse pack only; every variable part is in the task lines, so a runner reusing
one prefix across the parts of a variant gets cache hits. Variant i orders the pack by a fixed hash shuffle (as the other
membership batteries), so variants differ in prefix, each stable across reruns and across parts.
"""
import hashlib
import json
import statistics
from pathlib import Path

from .canonical import canonical_json, content_hash
from .governed import governed
from .membership import (DEFAULT_GOLD, DEFAULT_OUT, DEFAULT_PACK, MODEL, item_input, pack_hash, ungrouped_pack)
from .tasks import DEFAULT_K, DEFAULT_PROMPTS
from .validate import RANKED_MEMBERSHIP_VERSION, validate_answers

ROOT = Path(__file__).resolve().parent.parent
PROMPT_VERSION = RANKED_MEMBERSHIP_VERSION
VOCAB = "A3S"
TASK_TYPE = f"membership.{VOCAB}"
RELS = ("form", "content", "outcome", "setting")
VARIANTS = 2
MAX_TASKS = 50
CONTROLS = DEFAULT_GOLD / "membership_wide_controls_v0.jsonl"
KIND_TABLE = ROOT / "data" / "events" / "kind_memberships_v1.jsonl"
SNIPPET_TABLE = ROOT / "data" / "events" / "snippet_memberships_v1.jsonl"
ESCALATIONS = ROOT / "data" / "answers" / "escalations.membership_wide.jsonl"
CALIBRATION_DIR = ROOT / "data" / "events" / "calibration"
SNIPPET_SAMPLE = 200
PAIRS_POSSIBLE = 30381  # unordered pairs of the 247 fields (`data/events/coverage_v1.json`)


# ---- items ----
def load_controls(path=CONTROLS):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def calibration_items(controls=None):
    return [{"id": c["id"], "text": c["text"]} for c in (controls if controls is not None else load_controls())]


def _event_text(statement, outcome):
    return f"{statement}. Outcome: {outcome}." if outcome else f"{statement}."


def kind_items():
    """The generated event kinds as items: `kind.<key>`, the kind's sentence without its place and, where the kind has one, its outcome."""
    from .eventgen.catalog import ALL
    return [{"id": f"kind.{k.key}", "text": _event_text(k.stmt.replace(" in {place}", "").format(who="person"), k.outcome_text)} for k in ALL]


def snippet_items(n=SNIPPET_SAMPLE, calibration_dir=CALIBRATION_DIR):
    """A stable sample of n calibration event snippets, spread over the calibrated quantities (round-robin over quantities in hash
    order, distinct actions and outcomes first), as items `snip.<hash>`."""
    by_q = {}
    for name in ("aggregates_v1.jsonl", "aggregates_v2_domains.jsonl"):
        for line in (Path(calibration_dir) / name).read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            for s in row.get("event_snippets", []):
                by_q.setdefault(row["quantity"], []).append(s)
    h = lambda s: hashlib.sha256(s.encode()).hexdigest()
    pools = {}
    for q, snips in by_q.items():
        seen, triples, first, rest = set(), set(), [], []
        for s in sorted(snips, key=lambda s: h(f"{s['action']}|{s.get('outcome')}|{s['actor']}")):
            key = (s["action"], s.get("outcome"))
            if (s["actor"], *key) in triples:
                continue
            triples.add((s["actor"], *key))
            (rest if key in seen else first).append(s)
            seen.add(key)
        pools[q] = first + rest  # a snippet repeating an earlier action and outcome (another actor) comes after all distinct ones
    order = sorted(pools, key=h)
    out, i = {}, 0
    while len(out) < n and any(i < len(p) for p in pools.values()):
        for q in order:
            if i < len(pools[q]) and len(out) < n:
                s = pools[q][i]
                iid = f"snip.{h(s['action'] + '|' + str(s.get('outcome')) + '|' + s['actor'])[:10]}"
                out.setdefault(iid, {"id": iid, "text": _event_text(f"{s['actor']} {s['action']}", s.get("outcome"))})
        i += 1
    return sorted(out.values(), key=lambda o: o["id"])


# ---- batches ----
def read_instructions(prompt_version=PROMPT_VERSION, prompts_dir=DEFAULT_PROMPTS):
    return (Path(prompts_dir) / f"membership.v{prompt_version}.md").read_text(encoding="utf-8").rstrip("\n")


def build_wide_batches(items, pack_text, *, variants=VARIANTS, max_tasks=MAX_TASKS, prompt_version=PROMPT_VERSION, model=MODEL,
                       prompts_dir=DEFAULT_PROMPTS):
    """{(variant, part): [header, task lines...]}: variant v's header carries the instructions and the pack ordered for v (the same
    in every part), each part holds at most max_tasks tasks sorted by item id."""
    instructions = read_instructions(prompt_version, prompts_dir)
    phash = pack_hash(pack_text)
    batches = {}
    for v in range(variants):
        prefix = f"{instructions}\n\nThe coarse pack follows.\n{ungrouped_pack(pack_text, v)}"
        header = json.dumps({"kind": "header", "task_type": TASK_TYPE, "model": model, "prompt_version": prompt_version,
                             "prefix": prefix}, sort_keys=True, ensure_ascii=False)
        lines = []
        for it in sorted(items, key=lambda i: i["id"]):
            inp = item_input(it, phash)
            h = content_hash(inp)
            lines.append(canonical_json({"kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": TASK_TYPE,
                                         "prompt_version": prompt_version, "input_hash": h, "variant": v, "k": variants,
                                         "input": inp, "allowed_verdicts": ["membership"]}))
        for p in range(0, len(lines), max_tasks):
            batches[(v, p // max_tasks)] = [header] + lines[p:p + max_tasks]
    return batches


def write_wide_batches(name, batches, out_dir=DEFAULT_OUT, prompt_version=PROMPT_VERSION):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for (v, p), lines in sorted(batches.items()):
        path = out / f"{TASK_TYPE}.v{prompt_version}.{name}.var{v}.part{p}.jsonl"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(path)
    return paths


# ---- answers ----
def read_validated(batch_path, answers_path):
    """(header, {task_id: item}, answers) of a batch and its answers; raises ValueError listing every validation error."""
    b = Path(batch_path).read_text(encoding="utf-8").splitlines()
    a = Path(answers_path).read_text(encoding="utf-8").splitlines()
    errs = validate_answers(b, a)
    if errs:
        raise ValueError(f"{answers_path}: {len(errs)} validation errors, first: {errs[0]}")
    header = json.loads(b[0])
    items = {}
    for line in b[1:]:
        t = json.loads(line)
        items[t["task_id"]] = t["input"]["item"]
    return header, items, [json.loads(l) for l in a]


def answers_by_item(pairs):
    """{item id: {variant: (item text, answer)}} over (batch, answers) path pairs."""
    out = {}
    for bp, ap in pairs:
        _, items, answers = read_validated(bp, ap)
        for a in answers:
            it = items[a["task_id"]]
            out.setdefault(it["id"], {})[a["variant"]] = (it["text"], a)
    return out


# ---- the calibration judge ----
def _listed(answer, rel):
    rk = answer["ranks"][rel]
    return None if rk is None else [e["domain"] for e in rk["listed"]]


def calibration_report(controls, by_item, floor=None):
    """Judge the control battery against its pre-registered predictions. `by_item`: {item id: {variant: (text, answer)}}.

    Cells are (control, variant, relation) where the control's gold names the relation (`fair`). A secondary domain is any listed
    domain after the first. Precision of secondary domains = share in the control's `fair` list for that relation; the rest are
    `bad` (the gold names it) or `unjudged` (the gold names neither: the lead reviews these, they count against precision).
    Padding on single-domain controls = share of their cells with a secondary domain outside `fair`. Recall = share of `required`
    domains listed. Decoy hits = decoy cells listing a `bad` domain. Widths: median listed domains over non-null cells."""
    floor = governed("membership.fit_floor") if floor is None else floor
    n_sec = ok_sec = 0
    unjudged, bad_sec = [], []
    pad_cells = pad_hit = 0
    req_total = req_hit = 0
    decoy_cells = decoy_hit = 0
    widths = {g: {r: [] for r in RELS} for g in ("single", "multi", "decoy", "all")}
    wide_rejected = []
    for c in controls:
        for v, (_, ans) in sorted(by_item.get(c["id"], {}).items()):
            for rel in RELS:
                lst = _listed(ans, rel)
                if lst is None:
                    continue
                widths[c["group"]][rel].append(len(lst))
                widths["all"][rel].append(len(lst))
                fair = c.get("fair", {}).get(rel)
                if fair is None:
                    continue
                bad = set(c.get("bad", {}).get(rel, []))
                sec = lst[1:]
                outside = [d for d in sec if d not in fair]
                for d in sec:
                    n_sec += 1
                    if d in fair:
                        ok_sec += 1
                    elif d in bad:
                        bad_sec.append((c["id"], v, rel, d))
                    else:
                        unjudged.append((c["id"], v, rel, d))
                if c["group"] == "single":
                    pad_cells += 1
                    pad_hit += bool(outside)
                if c["group"] == "decoy":
                    decoy_cells += 1
                    decoy_hit += any(d in bad for d in lst)
                for d in c.get("required", {}).get(rel, []):
                    req_total += 1
                    req_hit += d in lst
                if not lst or ans["ranks"][rel]["rejected"]["fit"] >= floor:
                    wide_rejected.append((c["id"], v, rel))
    med = lambda xs: statistics.median(xs) if xs else None
    prec = ok_sec / n_sec if n_sec else None
    padding = pad_hit / pad_cells if pad_cells else None
    medians = {g: {r: med(w[r]) for r in RELS} for g, w in widths.items()}
    multi_ok = all((medians["multi"][r] or 0) >= 2 for r in ("form", "content"))
    return {
        "floor": floor,
        "cells_judged": {"secondary": n_sec, "single": pad_cells, "decoy": decoy_cells, "required": req_total},
        "median_listed": medians,
        "precision_secondary": prec,
        "unjudged_secondary": unjudged,
        "bad_secondary": bad_sec,
        "padding_single": padding,
        "recall_required": req_hit / req_total if req_total else None,
        "decoy_hit_rate": decoy_hit / decoy_cells if decoy_cells else None,
        "predictions": {
            "median_listed_multi_form_content_at_least_2": multi_ok,
            "precision_secondary_at_least_0.8": prec is not None and prec >= 0.8,
            "padding_single_at_most_0.10": padding is not None and padding <= 0.10,
        },
    }


# ---- the ingest ----
def _jaccard(sets):
    union = set().union(*sets)
    return len(set.intersection(*sets)) / len(union) if union else 1.0


def merge_item(key, text, variant_answers, *, agree_floor=None):
    """One table row from the variants' (validated, ranked) answers of one item. A relation's memberships are the domains every
    variant listed, weights the mean over variants renormalised; confidence is the Jaccard agreement of the lists, with the share
    of variants behind each domain. Escalate when the primary domain differs, the agreement is below the governed floor, or a
    relation applies in some variants only."""
    agree_floor = governed("membership.agree_floor") if agree_floor is None else agree_floor
    k = len(variant_answers)
    memberships, confidence, disputed, reasons = {}, {}, {}, []
    for rel in RELS:
        per = [a["types"][rel] for _, a in sorted(variant_answers.items())]
        lists = [list(p) if p else None for p in per]
        if all(p is None for p in per):
            memberships[rel] = None
            continue
        if any(p is None for p in per):
            reasons.append(f"{rel}: applies in {sum(p is not None for p in per)} of {k} variants")
        given = [set(p) for p in per if p]
        agreed = set.intersection(*given) if len(given) == k else set()
        share = {d: sum(d in p for p in per if p) / k for d in set().union(*given)}
        jac = _jaccard(given) if len(given) == k else 0.0
        if agreed:
            raw = {d: sum(p[d] for p in per) / k for d in agreed}
            order = sorted(agreed, key=lambda d: (-raw[d], d))
            total = sum(raw.values())
            memberships[rel] = {d: raw[d] / total for d in order}
        else:
            memberships[rel] = None
        confidence[rel] = {"agreement": jac, "domains": dict(sorted(share.items(), key=lambda x: (-x[1], x[0])))}
        dis = {d: s for d, s in share.items() if d not in agreed}
        if dis:
            disputed[rel] = dict(sorted(dis.items()))
        firsts = {l[0] for l in lists if l}
        if len(given) == k and len(firsts) > 1:
            reasons.append(f"{rel}: primary domains differ {sorted(firsts)}")
        if len(given) == k and jac < agree_floor:
            reasons.append(f"{rel}: agreement {jac:.2f} below {agree_floor}")
        if len(given) == k and not agreed:
            reasons.append(f"{rel}: no domain listed by every variant")
    first = next(iter(variant_answers.values()))
    return {"key": key, "text": text, "source": key.split(".", 1)[0], "prompt_version": first["prompt_version"],
            "model": first["model"], "variants": k, "memberships": memberships, "confidence": confidence,
            "disputed": disputed, "escalate": bool(reasons), "escalate_reasons": reasons}


def ingest(pairs, out_path, escalation_path=ESCALATIONS, *, variants=VARIANTS):
    """Merge answers (path pairs of batch and answers file, every variant of every item) into the table at out_path (one row per
    item, sorted by key) and write the escalations (one record per escalated item, with the variants' own lists) to
    escalation_path. Both files are rewritten. Returns the rows."""
    got = answers_by_item(pairs)
    rows, esc = [], []
    for key in sorted(got):
        per = got[key]
        if len(per) != variants:
            raise ValueError(f"{key}: answers from variants {sorted(per)}, expected {variants}")
        text = next(iter(per.values()))[0]
        row = merge_item(key, text, {v: a for v, (_, a) in per.items()})
        rows.append(row)
        if row["escalate"]:
            esc.append({"key": key, "text": text, "reasons": row["escalate_reasons"],
                        "variants": {str(v): {r: a["ranks"][r] for r in RELS} for v, (_, a) in sorted(per.items())}})
    for path, recs in ((out_path, rows), (escalation_path, esc)):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text("".join(canonical_json(r) + "\n" for r in recs), encoding="utf-8")
    return rows


def width_summary(rows):
    """Median listed domains per relation over the table's non-null cells (the LI.67 width prediction), and the share of the
    field pairs that co-occur inside one kind's memberships (the static analogue of P.EG3.4's pair coverage)."""
    widths = {r: [len(row["memberships"][r]) for row in rows if row["memberships"].get(r)] for r in RELS}
    pairs = set()
    for row in rows:
        doms = sorted({d for r in RELS for d in (row["memberships"].get(r) or {}) if d.startswith("c.")})
        pairs |= {(a, b) for i, a in enumerate(doms) for b in doms[i + 1:]}
    return {"median_listed": {r: (statistics.median(w) if w else None) for r, w in widths.items()},
            "escalated": sum(row["escalate"] for row in rows), "rows": len(rows),
            "pairs_in_kinds": len(pairs), "share_of_pairs": len(pairs) / PAIRS_POSSIBLE}
