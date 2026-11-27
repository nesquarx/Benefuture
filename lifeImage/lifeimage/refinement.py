"""LI.68: the refinement log. Plausible domains that membership answers list or just reject are logged, never discarded and never
merged into memberships. Sources: `unjudged` (listed secondary the control gold neither accepts nor rejects), `near_floor`
(the best rejected domain, fit = floor - 1, and the gold does not judge it), `disputed` (listed by one variant only, gold
silent). They feed gold-set completion, fine-domain proposals and domain-domain link proposals (`data/refinement/README.md`). `blind_unmatched` (LI.70) is a blind label of the two-pass extraction that matched no domain and that the mapper
reviewed as a new-domain candidate.

The log (`candidates_v1.jsonl`) is append-safe: records merge by key (item, relation, domain, source, prompt version, variant),
sorted by key. The summary (`summary_v1.json`) is recomputed from the whole log."""
import hashlib
import json
from pathlib import Path

RELS = ("form", "content", "outcome", "setting")
SOURCES = ("unjudged", "near_floor", "disputed", "blind_unmatched")
KEY_FIELDS = ("item", "relation", "domain", "source", "prompt_version", "variant")


def text_hash(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def candidates_for_item(item_id, text, variant_answers, floor, gold=None, disputed_only=None):
    """Candidate records of one item. `variant_answers`: {variant: validated ranked answer}. `gold`: the control (dict with `fair`
    and `bad` lists per relation) or None for items with no gold (kinds, snippets: only near_floor and disputed apply). `disputed_only`: when
    given, a set of (relation, domain) the merge left out; a single-variant domain outside it is in the memberships and is not logged as disputed."""
    out = []
    k = len(variant_answers)
    ih = text_hash(text)

    def judged(rel, d):
        return gold is not None and (d in gold.get("fair", {}).get(rel, ()) or d in gold.get("bad", {}).get(rel, ()))

    for v, a in sorted(variant_answers.items()):
        pv = a["prompt_version"]
        for rel in RELS:
            rk = a["ranks"][rel]
            if rk is None:
                continue
            listed = [e["domain"] for e in rk["listed"]]

            def rec(d, fit, source):
                out.append({"item": item_id, "item_hash": ih, "relation": rel, "domain": d, "fit": fit, "prompt_version": pv,
                            "variant": v, "source": source, "listed": listed})

            rj = rk["rejected"]
            if rj["fit"] == floor - 1 and not judged(rel, rj["domain"]):
                rec(rj["domain"], rj["fit"], "near_floor")
            fair_known = gold is not None and gold.get("fair", {}).get(rel) is not None
            for i, e in enumerate(rk["listed"]):
                d = e["domain"]
                if judged(rel, d):
                    continue
                if fair_known and i > 0:
                    rec(d, e["fit"], "unjudged")
                if k > 1 and (disputed_only is None or (rel, d) in disputed_only) and sum(1 for b in variant_answers.values() if b["ranks"][rel] and d in [x["domain"] for x in b["ranks"][rel]["listed"]]) == 1:
                    rec(d, e["fit"], "disputed")
    return out


def _key(r):
    return tuple(r[f] for f in KEY_FIELDS)


def read_log(path):
    p = Path(path)
    return [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()] if p.exists() else []


def append_candidates(records, path):
    """Merge records into the log at path (existing records win on a key), rewrite it sorted by key; return all records."""
    merged = {_key(r): r for r in records}
    merged.update({_key(r): r for r in read_log(path)})
    rows = [merged[k] for k in sorted(merged)]
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text("".join(json.dumps(r, sort_keys=True, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
    return rows


def summarise(rows):
    """Per domain: appearances (records), by source, distinct items; per (candidate, listed) pair: how many distinct answers
    (item, relation, version, variant) had the candidate beside the listed domain. Counts only; nothing here enters memberships."""
    domains, pairs, seen = {}, {}, set()
    by_source, by_vs = {}, {}
    for r in rows:
        d = domains.setdefault(r["domain"], {"appearances": 0, "by_source": {}, "items": set()})
        d["appearances"] += 1
        d["by_source"][r["source"]] = d["by_source"].get(r["source"], 0) + 1
        d["items"].add(r["item"])
        by_source[r["source"]] = by_source.get(r["source"], 0) + 1
        vs = by_vs.setdefault(f"v{r['prompt_version']}", {})
        vs[r["source"]] = vs.get(r["source"], 0) + 1
        cell = (r["item"], r["relation"], r["prompt_version"], r["variant"], r["domain"])
        if cell in seen:
            continue
        seen.add(cell)
        for l in r["listed"]:
            if l != r["domain"]:
                pairs[(r["domain"], l)] = pairs.get((r["domain"], l), 0) + 1
    doms = {d: {"appearances": v["appearances"], "by_source": dict(sorted(v["by_source"].items())), "items": len(v["items"])}
            for d, v in sorted(domains.items(), key=lambda x: (-x[1]["appearances"], x[0]))}
    prs = [{"candidate": c, "listed": l, "count": n} for (c, l), n in sorted(pairs.items(), key=lambda x: (-x[1], x[0]))]
    return {"records": len(rows), "by_source": dict(sorted(by_source.items())),
            "by_version_source": {v: dict(sorted(s.items())) for v, s in sorted(by_vs.items())}, "domains": doms, "pairs": prs}


def log_candidates(records, directory):
    """Append records to `candidates_v1.jsonl` in directory and rewrite `summary_v1.json`; return (all rows, summary)."""
    d = Path(directory)
    rows = append_candidates(records, d / "candidates_v1.jsonl")
    s = summarise(rows)
    (d / "summary_v1.json").write_text(json.dumps(s, indent=1, sort_keys=False, ensure_ascii=False) + "\n", encoding="utf-8")
    return rows, s


def slug(label):
    import re
    return re.sub(r"[^a-z0-9]+", "_", label.lower()).strip("_")


def blind_unmatched_record(item_id, text, variant, prompt_version, relation, blind, review):
    """LI.70: the refinement record of one blind label the mapper reviewed as `new_domain_candidate`. `blind`: the blind label
    ({"label", "fit", "gloss"}); `review`: the mapper's entry (proposed_label, gloss, nearest, parent). The domain is `new:<slug>` (a proposal,
    never a pack id); `fit` is the blind fit, `listed` the nearest existing domains (feeding the candidate-link pairs of `summarise`)."""
    return {"item": item_id, "item_hash": text_hash(text), "relation": relation, "domain": f"new:{slug(review['proposed_label'])}", "fit": blind["fit"],
            "prompt_version": prompt_version, "variant": variant, "source": "blind_unmatched", "listed": list(review["nearest"]),
            "label": blind["label"], "proposed_label": review["proposed_label"], "gloss": review["gloss"], "parent": review["parent"]}
