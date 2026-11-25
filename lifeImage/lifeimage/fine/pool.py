"""The candidate pool of fine domains, from four kinds of source, deduplicated mechanically.

(a) `candidates_from_wikidata`: the public-figure statements whose label matched no coarse domain (`mapped: false` in
    `data/public/*.trace.jsonl`). An occupation keeps its own label. Any other kind of statement names an instance (a
    named prize, a single work, one employer): the instance is evidence for the event record, never a domain, so the
    candidate is its domain-level class (`literary award`, `theorem`) with the instance labels as examples; an
    instance with only a generic class (`award`, `human`) is dropped, loudly, and counted.
(b) `candidates_from_answers`: a domain the cached membership and confirm answers state is missing ("X has no dedicated
    domain"). Other free-text complaints (vocabulary gaps, scenario notes) are not domains.
(c) `data/fine/sources/*.jsonl`: classes of public classifications (`sources.py`): OpenAlex subfields, ISCO-08 minor
    groups and ESCO skill groups (depth 2), ICATUS divisions and groups.

`build_pool` merges them by normalised label (`normalise.py`), drops residual categories and any candidate that only
restates a coarse domain, gives each a stable id `f.<slug>`, and returns the pool with a report accounting for every raw
item: raw = pool + merged + dropped.
"""
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

from .normalise import dedupe_key, merge_candidates
from .sources import KINDS, LICENCES, read_jsonl, write_jsonl

ROOT = Path(__file__).resolve().parent.parent.parent
SOURCE_ORDER = ["openalex", "esco_skills", "esco_isco", "icatus", "wikidata", "answers"]
DEPTH = {"esco_isco": 2, "esco_skills": 2}  # only ISCO minor groups and ESCO skill groups of this depth
GENERIC = frozenset({"award", "occupation", "profession", "position", "human", "organization", "organisation", "class of award",
                     "group of awards", "list", "honorific suffix", "creative work", "real number", "series of creative works",
                     "project", "inscription", "engraving", "married couple", "nonprofit organization", "school", "social role",
                     "hall of fame", "group of humans", "commemorative plaque", "function", "method", "grade of an order"})
WIKIDATA_KINDS = {"occupation": "occupation", "award received": "award", "notable work": "work", "member of": "membership",
                  "employer": "employer", "position held": "position", "educated at": "education"}
_MISSING = re.compile(r"^(?P<what>.+?)\s+(?:has|have)\s+no\s+(?:dedicated|specific|separate)\s+(?:domain|field)\b", re.I)


def _item(label, source, code, kind, description="", aliases=(), broader=(), **extra):
    return {"label": label, "aliases": list(aliases), "description": description, "kinds": [kind],
            "sources": [{"source": source, "code": str(code), "label": label, "licence_status": LICENCES[source]["status"]}],
            "broader_in_source": [b for b in broader if b], **extra}


def _domain_class(instance_of):
    """The first class that is neither generic nor a proper name (a named instance, not a kind)."""
    for c in instance_of:
        words = c.split()
        if c.lower() not in GENERIC and words and not words[-1][0].isupper():
            return c
    return None


def candidates_from_wikidata(public_dir=ROOT / "data" / "public"):
    """([merged candidates with evidence_count and examples], [dropped rows])."""
    groups, dropped = defaultdict(list), []
    for p in sorted(Path(public_dir).glob("*.trace.jsonl")):
        for r in read_jsonl(p):
            if r["mapped"]:
                continue
            label = r["label"] if r["kind"] == "occupation" else _domain_class(r["instance_of"])
            if label is None:
                dropped.append({"label": r["label"], "source": "wikidata", "reason": "instance with no domain-level class"})
                continue
            groups[dedupe_key(label)].append((label, r))
    cands = []
    for key in sorted(groups):
        rows = groups[key]
        label = sorted({l for l, _ in rows})[0]
        kind = WIKIDATA_KINDS[rows[0][1]["kind"]]
        examples = sorted({r["label"] for _, r in rows if r["label"] != label})[:5]
        desc = (f"{kind.capitalize()} class seen in public records; examples: {'; '.join(examples)}." if examples
                else f"{kind.capitalize()} seen in public records.")
        cands.append(_item(label, "wikidata", ",".join(sorted({r["qid"] for _, r in rows})[:3]), kind, desc,
                           evidence_count=len(rows), examples=examples))
    return cands, dropped


def candidates_from_answers(answers_dir=ROOT / "data" / "answers"):
    out = {}
    d = Path(answers_dir)
    for p in sorted([*d.glob("membership.*.jsonl"), *d.glob("confirm.*.jsonl")]):
        for line in p.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            a = json.loads(line)
            m = _MISSING.match(a["other"]) if isinstance(a.get("other"), str) else None
            if m:
                out.setdefault(dedupe_key(m["what"]), _item(m["what"].strip(), "answers", a["input_hash"][:12], "activity",
                                                            "Named in a cached answer as lacking a domain of its own."))
    return [out[k] for k in sorted(out)]


def candidates_from_source(name, rows):
    depth = DEPTH.get(name)
    return [_item(r["label"], name, r["code"], KINDS[name], r.get("description", ""), r.get("aliases", []), [r.get("broader", "")])
            for r in rows if depth is None or r.get("depth", depth) == depth]


def _slug(label):
    return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", dedupe_key(label).replace(" ", "_").lower())).strip("_") or "x"


def _network(source_dir):
    p = Path(source_dir) / "network.json"
    return json.loads(p.read_text()) if p.exists() else {}


def build_pool(coarse_cards, source_dir=ROOT / "data" / "fine" / "sources", public_dir=ROOT / "data" / "public",
               answers_dir=ROOT / "data" / "answers"):
    """(pool, report)."""
    items, raw, scope = [], Counter(), {}
    for name in sorted(KINDS):
        f = Path(source_dir) / f"{name}.jsonl"
        if f.exists():
            got = candidates_from_source(name, read_jsonl(f))
            items += got
            raw[name] = len(got)
    wd, wd_dropped = candidates_from_wikidata(public_dir)
    items += wd
    raw["wikidata"] = len(wd)
    ans = candidates_from_answers(answers_dir)
    items += ans
    raw["answers"] = len(ans)
    ckeys = {}
    for c in coarse_cards:
        for l in [c["label"], *(a["text"] for a in c["aliases"])]:
            ckeys.setdefault(dedupe_key(l), c["id"])
    kept, dropped = [], []
    for it in items:
        hit = ckeys.get(dedupe_key(it["label"]))
        if hit:
            dropped.append({"label": it["label"], "source": it["sources"][0]["source"], "reason": f"restates coarse domain {hit}"})
        else:
            kept.append(it)
    merged, rep = merge_candidates(kept, SOURCE_ORDER)
    pool, used = [], Counter()
    for c in merged:
        slug = _slug(c["label"])
        used[slug] += 1
        pool.append(dict(c, id=f"f.{slug}"))
    clash = {c["id"] for c in pool if used[c["id"][2:]] > 1}
    for c in pool:
        if c["id"] in clash:
            c["id"] = f"{c['id']}_{hashlib.sha256(dedupe_key(c['label']).encode()).hexdigest()[:6]}"
    pool.sort(key=lambda c: c["id"])
    net = _network(source_dir)
    all_dropped = dropped + rep["dropped"]
    report = {
        "by_source": {s: {"raw": raw[s], "in_pool": sum(any(x["source"] == s for x in c["sources"]) for c in pool),
                          "licence": LICENCES[s]["licence"], "licence_status": LICENCES[s]["status"]} for s in sorted(raw)},
        "pool": len(pool), "merged": rep["merged"], "dropped": all_dropped,
        "wikidata": {"unmapped_rows": sum(c["evidence_count"] for c in wd) + len(wd_dropped), "class_candidates": len(wd),
                     "instances_dropped": len(wd_dropped), "dropped": wd_dropped},
        "licence_status_of_candidates": dict(sorted(Counter(min((x["licence_status"] for x in c["sources"]),
                                                                key=["restricted", "unverified", "verified"].index)
                                                              for c in pool).items())),
        "kinds": dict(sorted(Counter(k for c in pool for k in c["kinds"]).items())),
        "network": {"blocked": any(v["status"] != "fetched" for v in net.values()) if net else None, "sources": net},
    }
    return pool, report


def new_candidates(rows, existing_pool, coarse_cards, source="atus", order=None):
    """(candidates, report) for the rows of one or more further sources, only what is new: a row that restates a coarse
    domain or an existing candidate (by label or alias) is dropped with its reason; the rest are deduplicated among
    themselves and given ids clear of the existing pool, so the first pool's cards and cached answers are untouched.
    A row may carry its own `source` (default `source`), `kind` and `target` (the empty coarse field it was chosen for:
    a candidate lists every target of the rows it merged as `target_fields`, a trace only). `order` ranks the sources
    when rows merge. report: raw = candidates + dropped + merged."""
    held = {}
    for c in coarse_cards:
        for l in [c["label"], *(a["text"] for a in c["aliases"])]:
            held.setdefault(dedupe_key(l), f"restates coarse domain {c['id']}")
    for c in existing_pool:
        for l in [c["label"], *c.get("aliases", [])]:
            held.setdefault(dedupe_key(l), f"restates existing candidate {c['id']}")
    items, dropped, targets = [], [], defaultdict(set)
    for r in rows:
        src = r.get("source", source)
        hit = held.get(dedupe_key(r["label"]))
        if hit:
            dropped.append({"label": r["label"], "source": src, "reason": hit})
            continue
        items.append(_item(r["label"], src, r["code"], r.get("kind") or KINDS.get(src, "activity"), r.get("description", ""),
                           r.get("aliases", []), [r.get("broader", "")]))
        if r.get("target"):
            targets[dedupe_key(r["label"])].add(r["target"])
    merged, rep = merge_candidates(items, order or [source])
    taken = {c["id"] for c in existing_pool}
    out = []
    for c in sorted(merged, key=lambda c: c["sources"][0]["code"]):
        base = f"f.{_slug(c['label'])}"
        cid, n = base, 1
        while cid in taken:
            n += 1
            cid = f"{base}_{n}"
        taken.add(cid)
        extra = {"target_fields": sorted(targets[dedupe_key(c["label"])])} if targets.get(dedupe_key(c["label"])) else {}
        out.append(dict(c, id=cid, **extra))
    out.sort(key=lambda c: c["id"])
    all_dropped = dropped + rep["dropped"]
    return out, {"raw": len(rows), "candidates": len(out), "merged": rep["merged"], "dropped": all_dropped,
                 "licence_status": LICENCES[source]["status"] if source in LICENCES else None}


def load_pool(path):
    return read_jsonl(path)


def write_pool(pool, path):
    write_jsonl(pool, path)
