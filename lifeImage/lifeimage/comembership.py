"""Layer C from memory (L22 `Rel ← Mem`): typed, directed co-membership learnt from the cached annotations.

Unit: one annotated item (input hash). Its answers (every variant, every vocabulary and confirm run) merge into one
membership per type: the mean over the answers that carry the type (a null answer counts as empty, a type a
vocabulary does not have is not counted as zero), so two vocabularies sharing `form` share one unit instead of
doubling it. The placebo type `flavour` is dropped.

Row {a, type_i, b, type_j, p, support, version}, for domains a != b:
  p = sum over items of w_i(a) * w_j(b) / sum over items of w_i(a)   (weights of a's membership under type_i and of
      b's under type_j; the soft form of P(b under type_j | a under type_i))
  support = items where both weights are above 0.
Both directions are separate rows (p is not symmetric). Derived views, each a filter or ordering of the rows:
specialisation (within-type inclusion asymmetry: a sits inside b when p(b|a) exceeds p(a|b)), reference (form to
content) and production (form to outcome).
"""
import json
from collections import defaultdict
from pathlib import Path

PLACEBO = "flavour"
VERSION = "0"
ROOT = Path(__file__).resolve().parent.parent


def load_answers(answers_dir=ROOT / "data" / "answers"):
    """Every membership.* and confirm.* answer that carries `types`."""
    out = []
    d = Path(answers_dir)
    for p in sorted([*d.glob("membership.*.jsonl"), *d.glob("confirm.*.jsonl")]):
        for line in p.read_text(encoding="utf-8").splitlines():
            if line.strip():
                a = json.loads(line)
                if a.get("types"):
                    out.append(a)
    return out


def merge_items(answers):
    """{input_hash: {type: {domain: mean weight}}}; types with no domain are left out."""
    seen = defaultdict(lambda: defaultdict(list))  # hash -> type -> [weights map or None per answer]
    for a in answers:
        for t, ws in a["types"].items():
            if t != PLACEBO:
                seen[a["input_hash"]][t].append(ws or {})
    items = {}
    for h, types in seen.items():
        merged = {}
        for t, votes in types.items():
            acc = defaultdict(float)
            for ws in votes:
                for d, w in ws.items():
                    acc[d] += w / len(votes)
            if acc:
                merged[t] = dict(acc)
        if merged:
            items[h] = merged
    return items


def comembership(items, version=VERSION):
    num, support, den = defaultdict(float), defaultdict(int), defaultdict(float)
    for types in items.values():
        for ti, wi in types.items():
            for a, wa in wi.items():
                if wa <= 0:
                    continue
                den[(a, ti)] += wa
                for tj, wj in types.items():
                    for b, wb in wj.items():
                        if b != a and wb > 0:
                            num[(a, ti, b, tj)] += wa * wb
                            support[(a, ti, b, tj)] += 1
    return [{"a": a, "type_i": ti, "b": b, "type_j": tj, "p": min(1.0, round(n / den[(a, ti)], 6)),
             "support": support[(a, ti, b, tj)], "version": version}
            for (a, ti, b, tj), n in sorted(num.items())]


def pair_view(rows):
    """{(a, b): (p, support)} pooled over types: p is the support-weighted mean, support the total."""
    acc = defaultdict(lambda: [0.0, 0])
    for r in rows:
        x = acc[(r["a"], r["b"])]
        x[0] += r["p"] * r["support"]
        x[1] += r["support"]
    return {k: (s / n, n) for k, (s, n) in acc.items()}


def specialisation_view(rows, min_support=1):
    """Within-type rows where p(b|a) > p(a|b): [{a, b, type, p, p_rev, asymmetry, support}], largest asymmetry first.
    a specialises b (a's items are mostly also b's, not the converse); only that direction is listed."""
    same = {(r["a"], r["type_i"], r["b"]): r for r in rows if r["type_i"] == r["type_j"]}
    out = []
    for (a, t, b), r in same.items():
        if r["support"] < min_support:
            continue
        rev = same.get((b, t, a))
        p_rev = rev["p"] if rev else 0.0
        if r["p"] > p_rev:
            out.append({"a": a, "b": b, "type": t, "p": r["p"], "p_rev": p_rev, "asymmetry": round(r["p"] - p_rev, 6),
                        "support": r["support"]})
    return sorted(out, key=lambda s: (-s["asymmetry"], s["a"], s["b"], s["type"]))


def _view(rows, ti, tj):
    return sorted((r for r in rows if r["type_i"] == ti and r["type_j"] == tj), key=lambda r: (-r["p"], r["a"], r["b"]))


def reference_view(rows):
    """Form to content: what an act of this kind is typically about."""
    return _view(rows, "form", "content")


def production_view(rows):
    """Form to outcome: what an act of this kind typically produces."""
    return _view(rows, "form", "outcome")


def fields_with_links(rows, fields, min_support=3):
    """The fields (of the given ids) that are an endpoint of some row with support >= min_support."""
    ends = {d for r in rows if r["support"] >= min_support for d in (r["a"], r["b"])}
    return ends & set(fields)


def write_rows(rows, path):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text("".join(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n" for r in rows), encoding="utf-8")
    return Path(path)


OVERLAP_ASYMMETRY = 0.25  # governed: an overlap is data-consistent when |p(b|a) - p(a|b)| is at most this


def link_agreement(cards, rows, min_support=3, overlap_asymmetry=OVERLAP_ASYMMETRY):
    """How the cards' links agree with the data-learnt directed co-membership, on testable links only.

    A link a -> b is testable when a and b share items with support >= min_support (in either direction, pooled over
    types by `pair_view`). upstream agrees when a lies inside b: p(b|a) > p(a|b). overlap agrees when the pair is
    not strongly directed: |p(b|a) - p(a|b)| <= overlap_asymmetry. Chance level for upstream is 0.5 (the direction
    of an undirected pair is a coin), so a rate near 0.5 means the data says nothing about the direction."""
    pv = pair_view(rows)
    out = {"upstream_testable": 0, "upstream_agree": 0, "overlap_testable": 0, "overlap_agree": 0,
           "upstream_links": 0, "overlap_links": 0}
    for c in cards:
        for l in c.get("links", []):
            kind = l["rel"]
            if kind not in ("upstream", "overlap"):
                continue
            out[f"{kind}_links"] += 1
            fwd, rev = pv.get((c["id"], l["id"]), (0.0, 0)), pv.get((l["id"], c["id"]), (0.0, 0))
            if max(fwd[1], rev[1]) < min_support:
                continue
            out[f"{kind}_testable"] += 1
            if kind == "upstream":
                out["upstream_agree"] += fwd[0] > rev[0]
            else:
                out["overlap_agree"] += abs(fwd[0] - rev[0]) <= overlap_asymmetry
    for kind in ("upstream", "overlap"):
        n = out[f"{kind}_testable"]
        out[f"{kind}_rate"] = out[f"{kind}_agree"] / n if n else 0.0
    return out
