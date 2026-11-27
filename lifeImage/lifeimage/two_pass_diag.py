"""Read-only diagnosis of the two-pass pilot's recall loss (LI.70; `data/gold/two_pass_diagnosis.md`). No model is run, nothing is written.

For every (control, relation, gold-required domain) cell the merged two-pass result misses, `classify_miss` names the stage that lost it:
  P1  no blind label of either variant could map to the domain (no label of the item matches its label, alias or id words, and the mapper
      matched none to it);
  P2a a blind label plausibly names it (word overlap with the domain's label, aliases or id) but the mapper allocated every such label to
      another domain (or to it under another relation only, which cannot list it: `V`, below);
  P2b the mapper matched a label of this relation to it, but it is not in the variant's list (below the floor, or cut by the stopping rule);
  P2c a blind label plausibly names it and the mapper marked that label `noise` or `new_domain_candidate`;
  M   listed by exactly one variant, lost by the intersection merge;
  V   anything else (matched only under another relation).
Merges compared on the same answers: intersection (the shipped rule), union, and weighted (mean weight over variants, absent = 0, kept at or
above a threshold).  "Could map" is a word-overlap heuristic: the report lists every miss with its labels so the class can be audited by eye.
"""
import re
import statistics

from .membership_wide import RELS

_STOP = {"and", "of", "the", "a", "in", "for", "to", "work", "life", "services", "service"}


def _stem(w):
    for suf in ("ing", "ies", "es", "s", "ed", "al", "ion", "ment"):
        if w.endswith(suf) and len(w) - len(suf) >= 4:
            return w[:-len(suf)]
    return w


def words(text):
    return {_stem(w) for w in re.split(r"[^a-z]+", text.lower()) if len(w) >= 3 and w not in _STOP}


def domain_words(card):
    """Words of the domain's label, aliases and id (the id minus its level prefix)."""
    parts = [card["label"], card["id"].split(".", 1)[-1].replace("_", " ")] + [a["text"] for a in card.get("aliases", [])]
    return set().union(*(words(p) for p in parts))


def listed(answer, rel):
    rk = answer["ranks"][rel]
    return [] if rk is None else [e["domain"] for e in rk["listed"]]


def label_status(blind_answer, map_answer, rel, domain, cards):
    """What happened to `domain` under `rel` in one variant: (stage, detail). `blind_answer`, `map_answer` are that variant's pass-1 and
    pass-2 answers, `cards` the {id: card} of the domain pack."""
    if domain in listed(map_answer, rel):
        return "listed", ""
    refs = {f"{r}.{i}": (r, e) for r in blind_answer["blind"] if blind_answer["blind"][r] for i, e in enumerate(blind_answer["blind"][r])}
    acts = {e["ref"]: e for e in map_answer["labels"]}
    same = [r for r, a in acts.items() if a["action"] == "match" and a["domain"] == domain and refs[r][0] == rel]
    if same:
        return "P2b", f"matched by {[refs[r][1]['label'] for r in same]}"
    other = [r for r, a in acts.items() if a["action"] == "match" and a["domain"] == domain]
    dw = domain_words(cards[domain])
    near = [(r, refs[r][1]["label"], acts[r]) for r in refs if words(refs[r][1]["label"]) & dw]
    near_rel = [x for x in near if refs[x[0]][0] == rel] or near
    lost = [x for x in near_rel if x[2]["action"] != "match" or x[2]["domain"] != domain]
    if other:
        return "V", f"matched only under {sorted({refs[r][0] for r in other})} by {[refs[r][1]['label'] for r in other]}"
    if any(x[2]["action"] in ("noise", "new_domain_candidate") for x in lost):
        return "P2c", f"labels {[(x[1], x[2]['action']) for x in lost]}"
    if lost:
        return "P2a", f"labels {[(x[1], x[2].get('domain')) for x in lost]}"
    return "P1", ""


def _weights(answer, rel):
    t = answer["types"][rel]
    return dict(t) if t else {}


def merged_sets(map_variants, rel, floor_weight, floor=5):
    """The memberships of one relation under each merge rule, as sets of domains: intersection, union, weighted (mean weight, absent = 0,
    at least floor_weight), weighted_half (at least half of it: a domain one variant lists at twice the floor weight is kept)."""
    per = [_weights(a, rel) for _, a in sorted(map_variants.items())]
    if not any(per):
        return {m: set() for m in ("intersection", "union", "weighted", "weighted_half")}
    k = len(per)
    union = set().union(*per)
    mean = {d: sum(p.get(d, 0.0) for p in per) / k for d in union}
    given = [set(p) for p in per if p]
    return {"intersection": set.intersection(*given) if len(given) == k else set(), "union": union,
            "weighted": {d for d, w in mean.items() if w >= floor_weight}, "weighted_half": {d for d, w in mean.items() if w >= floor_weight / 2}}


def floor_weight(map_by_item, floor=5):
    """The weight a domain at the floor fit carries: the median over all listed fit == floor entries of the pass-2 answers."""
    ws = []
    for per in map_by_item.values():
        for _, a in per.values():
            for rel in RELS:
                rk = a["ranks"][rel]
                if rk:
                    ws += [a["types"][rel][e["domain"]] for e in rk["listed"] if e["fit"] == floor]
    return statistics.median(ws) if ws else 0.0


def recall_table(controls, map_by_item, v4_by_item=None):
    """Recall of the gold-required cells: per variant, per merge rule, plus the per-variant average (the metric of `two_pass_report`)."""
    fw = floor_weight(map_by_item)
    tot, hit = 0, {"var0": 0, "var1": 0, "per_variant": 0, "intersection": 0, "union": 0, "weighted": 0, "weighted_half": 0}
    cells = []
    for c in controls:
        for rel, doms in c.get("required", {}).items():
            for d in doms:
                per = map_by_item[c["id"]]
                sets = merged_sets({v: a for v, (_, a) in per.items()}, rel, fw)
                tot += 1
                for v in (0, 1):
                    hit[f"var{v}"] += d in listed(per[v][1], rel)
                hit["per_variant"] += sum(d in listed(per[v][1], rel) for v in (0, 1)) / 2
                for m, s in sets.items():
                    hit[m] += d in s
                cells.append((c["id"], rel, d))
    return {"cells": tot, "floor_weight": fw, **{k: v / tot for k, v in hit.items()}, "hits": hit}


def classify_miss(item, rel, domain, blind_variants, map_variants, cards):
    """Class of one (item, relation, domain) the intersection merge misses: returns (class, per-variant statuses)."""
    st = {v: label_status(blind_variants[v][1], map_variants[v][1], rel, domain, cards) for v in sorted(map_variants)}
    n_listed = sum(s[0] == "listed" for s in st.values())
    if n_listed == len(st):
        return None, st
    if n_listed:
        return "M", st
    order = ["P2b", "P2c", "V", "P2a", "P1"]  # closest to success first: the best variant names the stage
    return min((s[0] for s in st.values()), key=order.index), st


def precision_by_merge(controls, map_by_item):
    """Share of judged secondary domains (after the first, by mean weight) that gold calls fair, per merge rule; and the mean list length."""
    fw = floor_weight(map_by_item)
    out = {}
    for m in ("intersection", "union", "weighted", "weighted_half"):
        ok = bad = n = cells = 0
        for c in controls:
            for rel in RELS:
                fair = c.get("fair", {}).get(rel)
                per = {v: a for v, (_, a) in map_by_item.get(c["id"], {}).items()}
                if fair is None or not per:
                    continue
                s = merged_sets(per, rel, fw)[m]
                w = {d: sum(_weights(a, rel).get(d, 0) for a in per.values()) for d in s}
                lst = sorted(s, key=lambda d: (-w[d], d))
                cells += 1
                n += len(lst)
                for d in lst[1:]:
                    ok += d in fair
                    bad += d in c.get("bad", {}).get(rel, [])
        out[m] = {"precision_judged": ok / (ok + bad) if ok + bad else None, "mean_listed": n / cells if cells else None}
    return out
