"""Merge fine_parent answers into data/fine/fine_v0.jsonl (fine cards) and a summary; compare with the data.

Usage (from the repository root):
    python3 lifeImage/tools/fine_apply.py [--answers-dir data/batches]
Reads `fine_parent.v1.var{v}.part{n}.answers.jsonl` for each variant, validates every file against the batches rebuilt
from the candidate pool (a stale or malformed file fails loudly), merges the three votes per candidate (majority
parents, agreement as confidence, `fine_parent` escalations logged to data/answers/escalations.fine_parent.jsonl), and
writes the cards (level `fine`, status `score_only`, links to the coarse parents) and `fine_v0_summary.json`: candidates
per coarse field and sector, fields with no fine children, the `new_field` list, the escalated share, and the
multi-parent pairs against the data-learnt co-membership where it exists.
"""
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lifeimage.cache import AnswerCache  # noqa: E402
from lifeimage.canonical import canonical_json  # noqa: E402
from lifeimage.fine.compare import main_parent, parent_pair_agreement  # noqa: E402
from lifeimage.fine.parent import TASK, build_fine_batches, merge_fine, validate_fine_answers  # noqa: E402
from lifeimage.fine.sources import read_jsonl  # noqa: E402
from lifeimage.packs import is_sector  # noqa: E402
from lifeimage.validate import validate_card  # noqa: E402

MODEL = "haiku-runner"
# further candidate sets applied alongside the first: (batch tag, candidates file, variants)
SETS = [("atus", ROOT / "data/fine/candidates_atus_v0.jsonl", 2), ("gap", ROOT / "data/fine/candidates_gap_v0.jsonl", 2)]
SOURCE = "haiku-runner x3, fine_parent.v1"
ESCALATION_LIMIT = 0.05  # plan acceptance: at most 5% of nodes escalated
WEIGHT_DIGITS = 9  # rounding keeps parent weights summing to 1 within the validator's 1e-6


def _card(cand, m, version):
    links = ([{"id": i, "rel": m["relation"], "weight": round(w, WEIGHT_DIGITS)} for i, w in m["parents"].items()]
             if m["parents"] else [])
    names = ", ".join(sorted({s["source"] for s in cand["sources"]}))
    prov = {"source": names, "confidence": 0.6}
    return validate_card({
        "id": cand["id"], "label": cand["label"], "aliases": [{"text": a, "lang": "en"} for a in cand.get("aliases", [])],
        "description": " ".join(cand.get("description", "").split()), "level": "fine",
        "anchors": [{"source": s["source"], "code": str(s["code"]), "label": s["label"]} for s in cand["sources"]],
        "links": links, "axes": None, "radius": None, "arc": None, "status": "score_only", "successors": [],
        "basemap_version": version,
        "provenance": {"label": prov, "description": prov,
                       "links": {"source": SOURCE, "confidence": round(m["confidence"], 3)}}})


def apply(*, candidates, coarse, answers, out, summary, escalation_log, cache, prompts_dir=None, comembership=None,
          model=MODEL, extra=()):
    """answers: {variant: [answer files]} for the first candidate set. `extra`: further sets as [(candidates file,
    {variant: [answer files]})], each with its own variants; a set whose answers are not there yet (empty) is skipped and
    named in `pending_sets`, a set with only some of its answers fails loudly. Returns the summary dict (also written to
    `summary`)."""
    cands, coarse_cards = read_jsonl(candidates), read_jsonl(coarse)
    groups = [("base", cands, answers)]
    pending = []
    for path, ans in extra:
        name = re.sub(r"^candidates_|_v\d+$", "", Path(path).stem)
        if not ans or not any(ans.values()):
            pending.append(name)
            continue
        groups.append((name, read_jsonl(path), ans))
    kw = {"prompts_dir": prompts_dir} if prompts_dir is not None else {}
    all_answers, merged, set_of = [], {}, {}
    for name, gcands, ans in groups:
        batches = build_fine_batches(gcands, coarse_cards, model=model, k=len(ans), **kw)
        by_hash, gvotes = {}, {}
        for v in sorted(ans):
            tasks = [l for (vv, _), lines in sorted(batches.items()) if vv == v for l in lines[1:]]
            header = next(lines[0] for (vv, _), lines in sorted(batches.items()) if vv == v)
            lines = [l for p in ans[v] for l in Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]
            errs = validate_fine_answers([header] + tasks, lines)
            if errs:
                raise SystemExit(f"{name} variant {v}: {len(errs)} invalid, first: {errs[0]}")
            for t in tasks:
                t = json.loads(t)
                by_hash[t["input_hash"]] = t["input"]["card"]["id"]
            for l in lines:
                a = json.loads(l)
                gvotes.setdefault(by_hash[a["input_hash"]], {})[a["variant"]] = a
                all_answers.append(a)
        merged.update({cid: merge_fine(v, k=len(ans)) for cid, v in sorted(gvotes.items())})
        set_of.update({c["id"]: name for c in gcands})
    cands = [c for _, gcands, _ in groups for c in gcands]
    if cache is not None:
        cache.put_all(all_answers)
    version = next(c["basemap_version"] for c in coarse_cards)
    cards = [_card(c, merged[c["id"]], version) for c in cands]
    Path(out).write_text("".join(json.dumps(c, ensure_ascii=False, sort_keys=True) + "\n" for c in cards), encoding="utf-8")
    esc = [(cid, m) for cid, m in merged.items() if m["escalated"]]
    if escalation_log is not None and esc:
        Path(escalation_log).parent.mkdir(parents=True, exist_ok=True)
        with Path(escalation_log).open("a", encoding="utf-8") as f:
            for cid, m in esc:
                f.write(canonical_json({"task_type": TASK, "id": cid, "reason": m["escalation_reason"], "kept": m["parents"],
                                        "votes": m["votes"]}) + "\n")
    by_id = {c["id"]: c for c in coarse_cards}
    sector_of = lambda i: i if is_sector(by_id[i]) else next(
        (l["id"] for l in sorted(by_id[i]["links"], key=lambda l: (-l["weight"], l["id"])) if l["rel"] == "upstream"), None)
    mains = {c["id"]: main_parent(c) for c in cards if c["links"]}
    per = Counter(mains.values())
    per_base = Counter(p for i, p in mains.items() if set_of[i] == "base")
    fields = sorted(i for i in by_id if not is_sector(by_id[i]))
    labels = {c["id"]: c["label"] for c in cands}
    s = {"candidates": len(cands), "model": model, "prompt": f"{TASK}.v1",
         "children_per_coarse": dict(sorted(per.items())),
         "children_per_sector": dict(sorted(Counter(sector_of(p) for p in mains.values()).items(), key=lambda kv: str(kv[0]))),
         "fields_without_children": [i for i in fields if per[i] == 0],
         "new_field_needed": [{"id": cid, "label": labels[cid], "reasons": m["new_field_reasons"]}
                              for cid, m in merged.items() if m["new_field"]],
         "relations": dict(sorted(Counter(m["relation"] or "new_field" for m in merged.values()).items())),
         "escalated": {"count": len(esc), "share": len(esc) / len(cands) if cands else 0.0, "limit": ESCALATION_LIMIT,
                       "within_limit": (len(esc) / len(cands) if cands else 0.0) <= ESCALATION_LIMIT,
                       "ids": [cid for cid, _ in esc]},
         "mean_agreement": sum(m["agreement"] for m in merged.values()) / len(merged) if merged else 0.0,
         "sets": dict(Counter(set_of.values())), "pending_sets": pending, "comembership": None}
    if len(groups) > 1:
        before = [i for i in fields if per_base[i] == 0]
        s["gained_children"] = {"before_without_children": len(before), "after_without_children": len(s["fields_without_children"]),
                                "fields": [i for i in before if per[i] > 0],
                                "per_sector": dict(sorted(Counter(sector_of(i) for i in before if per[i] > 0).items(),
                                                          key=lambda kv: str(kv[0])))}
    if comembership is not None and Path(comembership).exists():
        s["comembership"] = parent_pair_agreement([c for c in cards if c["links"]], read_jsonl(comembership), fields)
    Path(summary).write_text(json.dumps(s, indent=1, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    return s


def report(s):
    cm = s["comembership"]
    out = [f"candidates: {s['candidates']}; relations {s['relations']}",
           f"escalated {s['escalated']['count']} ({s['escalated']['share']:.1%}; limit {s['escalated']['limit']:.0%})",
           f"mean agreement {s['mean_agreement']:.3f}",
           f"coarse fields with no fine children: {len(s['fields_without_children'])}",
           f"new coarse field needed: {len(s['new_field_needed'])}"]
    if s["pending_sets"]:
        out.append(f"PENDING (no answers yet, not merged): {', '.join(s['pending_sets'])}")
    if s.get("gained_children"):
        g = s["gained_children"]
        out.append(f"coarse fields without a fine child: {g['before_without_children']} before, {g['after_without_children']} after; "
                   f"{len(g['fields'])} gained children {g['fields']}")
    if cm:
        out.append(f"multi-parent pairs with data support >= {cm['min_support']}: {cm['pairs_with_data']} of {cm['pairs']} "
                   f"({cm['rate']:.1%}); baseline over all coarse pairs {cm['baseline_rate']:.1%}")
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--answers-dir", default=ROOT / "data/batches")
    ap.add_argument("--k", type=int, default=3)
    ap.add_argument("--candidates", default=ROOT / "data/fine/candidates_v0.jsonl")
    ap.add_argument("--coarse", default=ROOT / "data/coarse/seed_v2.jsonl")
    ap.add_argument("--out", default=ROOT / "data/fine/fine_v0.jsonl")
    ap.add_argument("--summary", default=ROOT / "data/fine/fine_v0_summary.json")
    ap.add_argument("--comembership", default=ROOT / "data/coarse/comembership_v0.jsonl")
    a = ap.parse_args(argv)
    answers = {v: sorted(Path(a.answers_dir).glob(f"fine_parent.v1.var{v}.part*.answers.jsonl")) for v in range(a.k)}
    extra = [(path, {v: sorted(Path(a.answers_dir).glob(f"fine_parent.v1.{tag}.var{v}.part*.answers.jsonl")) for v in range(k)})
             for tag, path, k in SETS]
    if not all(answers.values()):
        raise SystemExit(f"missing answers for variants {[v for v, f in answers.items() if not f]} in {a.answers_dir}")
    s = apply(candidates=a.candidates, coarse=a.coarse, answers=answers, out=a.out, summary=a.summary,
              escalation_log=ROOT / "data/answers/escalations.fine_parent.jsonl", cache=AnswerCache(),
              comembership=a.comembership, extra=extra)
    print(report(s))
    print(f"wrote {a.out} and {a.summary}")


if __name__ == "__main__":
    main()
