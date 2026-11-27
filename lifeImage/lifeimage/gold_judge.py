"""LI.69: completing the membership calibration gold. The unjudged (item, relation, domain) triples of the v3 and v4 calibration
(a listed secondary domain the gold names neither `fair` nor `bad`) are judged by runners (task `gold_judge`, prompt `gold_judge.v1`,
2 variants that show the gold's fair and bad lists in opposite order). Agreed verdicts (`fair` or `bad` from both variants) extend the
gold as a new version, v0 kept, with provenance per added entry; a disagreement or any `unsure` goes to an author review file and
stays out of the new version (recorded in the control's `unsure` lists) until the author rules. No model is run here.

The batch prefix (instructions and the four relation meanings) is identical in every file, and every variable part is in the task
lines, so a runner reusing the prefix across files gets cache hits."""
import json
import re
from pathlib import Path

from .canonical import canonical_json, content_hash
from .membership import DEFAULT_GOLD, DEFAULT_OUT, MODEL
from .tasks import DEFAULT_PROMPTS
from .validate import validate_answers

ROOT = Path(__file__).resolve().parent.parent
TASK_TYPE = "gold_judge"
PROMPT_VERSION = 1
VERDICTS = ["fair", "bad", "unsure"]
VARIANTS = 2
MAX_TASKS = 50
RELS = ("form", "content", "outcome", "setting")
CONTROLS_V1 = DEFAULT_GOLD / "membership_wide_controls_v1.jsonl"
DISPUTED = DEFAULT_GOLD / "membership_wide_disputed_v1.md"
RULINGS = DEFAULT_GOLD / "membership_wide_rulings_v1.jsonl"  # optional: the author's rulings on disputes, one JSON per line
SOURCE = f"gold_judge.v{PROMPT_VERSION}"


# ---- the unjudged set ----
def unjudged_entries(controls, reports_by_version, floors=None):
    """The deduplicated unjudged triples over calibration versions. `reports_by_version`: {prompt version: by_item}. Each entry names
    the item, relation, domain and the versions and variants that listed it; sorted by (item, relation, domain)."""
    from .membership_wide import calibration_report
    got = {}
    for version, by_item in sorted(reports_by_version.items()):
        rep = calibration_report(controls, by_item, prompt_version=version)
        for cid, v, rel, d in rep["unjudged_secondary"]:
            e = got.setdefault((cid, rel, d), {"item": cid, "relation": rel, "domain": d, "versions": set(), "variants": set()})
            e["versions"].add(version)
            e["variants"].add(v)
    return [{**e, "versions": sorted(e["versions"]), "variants": sorted(e["variants"])} for _, e in sorted(got.items())]


def relation_meanings(prompt_path=DEFAULT_PROMPTS / "membership.v4.md"):
    """{relation: meaning}, parsed from the membership prompt's relations section, so the meanings live once."""
    text = Path(prompt_path).read_text(encoding="utf-8")
    sect = text.split("## The four relations, sharply", 1)[1].split("\n## ", 1)[0]
    out, cur = {}, None
    for line in sect.splitlines():
        m = re.match(r"^- (form|content|outcome|setting): (.*)$", line)
        if m:
            cur = m.group(1)
            out[cur] = m.group(2).strip()
        elif cur and line.startswith("  "):
            out[cur] += " " + line.strip()
        elif not line.strip():
            cur = None
    return out


def pack_domains(pack_text):
    """{domain id: (label, description)} from the coarse pack."""
    out = {}
    for line in pack_text.splitlines():
        parts = [x.strip() for x in line.split("|")]
        if len(parts) >= 3 and " " not in parts[0] and "." in parts[0]:
            out[parts[0]] = (parts[1], parts[2])
    return out


# ---- batches ----
def read_instructions(prompts_dir=DEFAULT_PROMPTS):
    text = (Path(prompts_dir) / f"{TASK_TYPE}.v{PROMPT_VERSION}.md").read_text(encoding="utf-8").rstrip("\n")
    rel = "\n".join(f"- {r}: {m}" for r, m in relation_meanings().items())
    return text.replace("{{RELATIONS}}", rel)


def _dom(doms, d, check):
    if d not in doms:
        if check:
            raise KeyError(f"domain {d!r} is not in the pack")
        return {"id": d, "label": d, "description": ""}
    return {"id": d, "label": doms[d][0], "description": doms[d][1]}


def build_gold_batches(entries, controls, pack_text, *, variants=VARIANTS, max_tasks=MAX_TASKS, model=MODEL, check_domains=True,
                       prompts_dir=DEFAULT_PROMPTS):
    """{(variant, part): [header, task lines...]}. Variant v shows the gold's fair and bad lists in the control's order (v even) or the
    reverse (v odd). Tasks sorted by (item, relation, domain); at most max_tasks per file; one header for every file."""
    doms, meanings = pack_domains(pack_text), relation_meanings()
    byid = {c["id"]: c for c in controls}
    header = json.dumps({"kind": "header", "task_type": TASK_TYPE, "model": model, "prompt_version": PROMPT_VERSION,
                         "prefix": read_instructions(prompts_dir)}, sort_keys=True, ensure_ascii=False)
    batches = {}
    for v in range(variants):
        lines = []
        for e in sorted(entries, key=lambda e: (e["item"], e["relation"], e["domain"])):
            c = byid[e["item"]]
            lists = {}
            for k in ("fair", "bad"):
                ds = list(c.get(k, {}).get(e["relation"], []))
                lists[k] = [_dom(doms, d, check_domains) for d in (ds[::-1] if v % 2 else ds)]
            inp = {"item": {"id": c["id"], "text": c["text"]}, "relation": e["relation"], "meaning": meanings[e["relation"]],
                   "domain": _dom(doms, e["domain"], check_domains), **lists}
            h = content_hash(inp)
            lines.append(canonical_json({"kind": "task", "task_id": f"{h[:16]}-v{v}", "task_type": TASK_TYPE, "prompt_version": PROMPT_VERSION,
                                         "input_hash": h, "variant": v, "k": variants, "input": inp, "allowed_verdicts": list(VERDICTS)}))
        for p in range(0, len(lines), max_tasks):
            batches[(v, p // max_tasks)] = [header] + lines[p:p + max_tasks]
    return batches


def write_gold_batches(batches, out_dir=DEFAULT_OUT, name="gold"):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for (v, p), lines in sorted(batches.items()):
        path = out / f"{TASK_TYPE}.v{PROMPT_VERSION}.{name}.var{v}.part{p}.jsonl"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(path)
    return paths


# ---- answers and the completed gold ----
def read_verdicts(pairs):
    """{(item, relation, domain): {variant: (verdict, reason)}} over validated (batch, answers) path pairs; raises ValueError on any
    validation error."""
    out = {}
    for bp, ap in pairs:
        b = Path(bp).read_text(encoding="utf-8").splitlines()
        a = Path(ap).read_text(encoding="utf-8").splitlines()
        errs = validate_answers(b, a)
        if errs:
            raise ValueError(f"{ap}: {len(errs)} validation errors, first: {errs[0]}")
        tasks = {json.loads(l)["task_id"]: json.loads(l) for l in b[1:]}
        for line in a:
            ans = json.loads(line)
            t = tasks[ans["task_id"]]
            key = (t["input"]["item"]["id"], t["input"]["relation"], t["input"]["domain"]["id"])
            out.setdefault(key, {})[ans["variant"]] = (ans["verdict"], ans["reason"])
    return out


def complete_gold(controls, verdicts, *, variants=VARIANTS, rulings=()):
    """The v1 controls and the disputes. A triple both variants judged `fair` (or both `bad`) is appended to the control's `fair` (or
    `bad`) list for the relation, with provenance {verdict, source, agreed, reasons}; anything else is a dispute: left out of `fair` and
    `bad`, listed in the control's `unsure` lists and returned in `disputed` (item, relation, domain, verdicts, reasons), unless an author
    ruling (`{item, relation, domain, verdict}` with verdict `fair` or `bad`) settles it, with source `author`. Every v0 entry is kept, in
    order. Returns {"controls": [...], "disputed": [...]}."""
    rule = {(r["item"], r["relation"], r["domain"]): r for r in rulings}
    out = [json.loads(json.dumps(c)) for c in controls]
    byid = {c["id"]: c for c in out}
    disputed = []
    for (item, rel, dom), per in sorted(verdicts.items()):
        if len(per) != variants:
            raise ValueError(f"{item} {rel} {dom}: verdicts from variants {sorted(per)}, expected {variants}")
        vs = [per[v][0] for v in sorted(per)]
        reasons = [per[v][1] for v in sorted(per)]
        c = byid[item]
        agreed = len(set(vs)) == 1 and vs[0] in ("fair", "bad")
        ruling = rule.get((item, rel, dom))
        if agreed:
            verdict, source = vs[0], SOURCE
        elif ruling and ruling["verdict"] in ("fair", "bad"):
            verdict, source = ruling["verdict"], "author"
        else:
            c.setdefault("unsure", {}).setdefault(rel, []).append(dom)
            disputed.append({"item": item, "relation": rel, "domain": dom, "verdicts": vs, "reasons": reasons})
            continue
        if dom in c.setdefault(verdict, {}).setdefault(rel, []):
            continue
        c[verdict][rel].append(dom)
        c.setdefault("provenance", {}).setdefault(rel, {})[dom] = {"verdict": verdict, "source": source, "agreed": agreed,
                                                                  "variants": vs, "reasons": reasons}
    return {"controls": out, "disputed": disputed}


def write_controls(controls, path=CONTROLS_V1):
    Path(path).write_text("".join(json.dumps(c, sort_keys=True, ensure_ascii=False) + "\n" for c in controls), encoding="utf-8")


def read_rulings(path=RULINGS):
    p = Path(path)
    return [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()] if p.exists() else []


def disputed_review(disputed, controls, pack_text):
    """Compact author review file: one line per disputed (item, relation, domain) with both verdicts and reasons. Record a ruling in
    `data/gold/membership_wide_rulings_v1.jsonl` ({item, relation, domain, verdict}) and rebuild the gold."""
    doms, byid = pack_domains(pack_text), {c["id"]: c for c in controls}
    out = ["# Disputed gold-judge verdicts (membership gold v1)", "",
           f"{len(disputed)} (item, relation, domain) triples were judged differently by the two variants, or `unsure` by one. They are "
           "left out of the gold's `fair` and `bad` lists (recorded as `unsure`) until ruled. Rule by adding "
           "`{\"item\", \"relation\", \"domain\", \"verdict\": \"fair\"|\"bad\"}` lines to `data/gold/membership_wide_rulings_v1.jsonl`.", ""]
    cur = None
    for d in sorted(disputed, key=lambda d: (d["item"], d["relation"], d["domain"])):
        if d["item"] != cur:
            cur = d["item"]
            out += [f"## {cur}: {byid[cur]['text']}", ""]
        label = doms.get(d["domain"], ("?",))[0]
        out.append(f"- {d['relation']} `{d['domain']}` ({label}): " + "; ".join(
            f"variant {i} {v}: {r}" for i, (v, r) in enumerate(zip(d["verdicts"], d["reasons"]))))
    return "\n".join(out) + "\n"


def report_path(version, gold):
    """v0 keeps the existing names (v3 unsuffixed); the completed gold names the version always."""
    if gold == "v0":
        return DEFAULT_GOLD / f"membership_wide_calibration_report{'' if version == 3 else f'_v{version}'}.json"
    return DEFAULT_GOLD / f"membership_wide_calibration_report_v{version}_gold_{gold}.json"
