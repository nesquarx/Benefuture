"""Mechanical deduplication of candidate domains: normalised labels and aliases, residual categories dropped.

Two labels name one candidate when their keys agree: lower case, accents and parentheticals removed, `&` as `and`,
punctuation as space, stop words removed, simple plurals folded, tokens sorted (so word order does not matter).
Folding is deliberately shallow (no stemming): `statistics` and `statisticians` stay two candidates, a field of study
and an occupation, because merging them is a judgement. A residual category ("Other ...", "... not elsewhere
classified") names no domain and is dropped, loudly, in the report.

`merge_candidates` is independent of input order: groups form by key; the canonical label, description and kinds come
from the highest-ranked source (`source_order`, then label), the other labels become aliases.
"""
import re
import unicodedata
from collections import defaultdict

STOP = frozenset({"a", "an", "and", "of", "the", "in", "for", "to", "on", "with", "by", "or"})
PROTECT = frozenset({"news", "series", "species", "physics", "mathematics", "economics", "ethics", "politics", "statistics",
                     "athletics", "gymnastics", "linguistics", "genetics", "robotics", "logistics", "analytics", "dynamics",
                     "mechanics", "optics", "acoustics", "aeronautics", "electronics", "informatics", "bioinformatics",
                     "pharmaceutics", "apparatus", "bus", "gas", "lens", "chaos", "pancreas", "diabetes", "herpes"})
RESIDUAL = re.compile(r"^(other|others|miscellaneous|not elsewhere|general and other)\b|not elsewhere classified|\bn\.?e\.?c\.?$|\bnot classified elsewhere\b",
                      re.I)


def _singular(w):
    if w in PROTECT or len(w) <= 3:
        return w
    if w.endswith("ies") and len(w) > 4:
        return w[:-3] + "y"
    if w.endswith(("sses", "xes", "ches", "shes")):
        return w[:-2]
    if w.endswith(("ss", "us", "is", "ics", "ics")):
        return w
    if w.endswith("s"):
        return w[:-1]
    return w


def dedupe_key(label):
    s = unicodedata.normalize("NFKD", label).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"\([^)]*\)", " ", s).replace("&", " and ")
    words = [w for w in re.sub(r"[^a-z0-9]+", " ", s).split() if w not in STOP]
    return " ".join(sorted(_singular(w) for w in words))


def is_residual(label):
    return bool(RESIDUAL.search(label.strip()))


def merge_candidates(cands, source_order=()):
    """(merged candidates sorted by key, report {merged, dropped}). Each input: label, aliases (strings), description,
    kinds, sources, broader_in_source, plus any extra keys (kept from the winning item, summed where numeric
    `evidence_count`)."""
    rank = {s: i for i, s in enumerate(source_order)}
    best = lambda c: (min((rank.get(s["source"], len(rank)) for s in c["sources"]), default=len(rank)), c["label"])
    groups, dropped = defaultdict(list), []
    for c in cands:
        if is_residual(c["label"]):
            dropped.append({"label": c["label"], "source": c["sources"][0]["source"], "reason": "residual category"})
            continue
        groups[dedupe_key(c["label"])].append(c)
    out = []
    for key in sorted(groups):
        items = sorted(groups[key], key=best)
        win = items[0]
        labels = {win["label"]}
        aliases = []
        for it in items:
            for l in [it["label"], *it.get("aliases", [])]:
                if l not in labels:
                    labels.add(l)
                    aliases.append(l)
        sources = sorted({(s["source"], s["code"]): s for it in items for s in it["sources"]}.values(),
                         key=lambda s: (rank.get(s["source"], len(rank)), s["source"], str(s["code"])))
        merged = dict(win, aliases=aliases, sources=sources,
                      description=next((it["description"] for it in items if it["description"]), ""),
                      kinds=sorted({k for it in items for k in it["kinds"]}),
                      broader_in_source=sorted({b for it in items for b in it.get("broader_in_source", []) if b}))
        if any("evidence_count" in it for it in items):
            merged["evidence_count"] = sum(it.get("evidence_count", 0) for it in items)
            merged["examples"] = sorted({e for it in items for e in it.get("examples", [])})[:5]
        out.append(merged)
    return out, {"merged": len(cands) - len(dropped) - len(out), "dropped": dropped}
