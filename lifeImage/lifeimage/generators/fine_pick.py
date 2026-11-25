"""Which fine domain an event names (LI.51): deterministic by seed, chosen by fit to the event and the person's archetype.

An event that falls in a coarse field with fine children also names one of them. The choice for (persona seed, event,
coarse field) is drawn on its own stream, so it never shifts another mechanism's draws and a persona's events agree
across their rows and tiers. A child's chance is its upstream link weight toward the field times exp(sharpness x fit),
where fit is the share, by rarity (idf over every fine card), of the child's own words that the event's wording and key
carry, plus half the same share against the archetype's sectors and interests. Fields with no fine child stay coarse.
The fit is a bag of words: it separates "Cooks" from "Kitchen and food clean-up" under an event about baking, not "Algebra"
from "Numerical Analysis" under an event that says only "mathematics".
"""
import math
import re
from functools import lru_cache

from ..fine.cards import children_by_parent, load_fine
from .common import seed_label, stream
from .params import ARCHETYPES

STOP = frozenset("and for the with other not except non household own personal some any all use using work working "
                 "activities activity services service general".split())
WORD = re.compile(r"[a-z]{3,}")


def words(text):
    """The stems of a text's content words (a trailing s dropped)."""
    return {w[:-1] if w.endswith("s") and len(w) > 3 else w for w in WORD.findall(text.lower())} - STOP


@lru_cache(maxsize=1)
def _index():
    """({coarse id: [(fine id, weight, words of label and aliases)]}, {word: idf})."""
    fines = load_fine()
    toks = {c["id"]: words(" ".join([c["label"]] + [a["text"] for a in c.get("aliases", [])])) for c in fines}
    df = {}
    for t in toks.values():
        for w in t:
            df[w] = df.get(w, 0) + 1
    idf = {w: math.log((1 + len(fines)) / (1 + n)) + 1.0 for w, n in df.items()}
    kids = {p: sorted(((c["id"], w, toks[c["id"]]) for c, w in cs), key=lambda x: x[0]) for p, cs in children_by_parent(fines).items()}
    return kids, idf


def has_fine_children(coarse):
    return coarse in _index()[0]


@lru_cache(maxsize=None)
def archetype_words(archetype):
    a = ARCHETYPES[archetype]
    text = " ".join([archetype.replace("_", " ")] + list(a.get("sectors", [])) + [seed_label(d) for d in a.get("interests", [])])
    return frozenset(words(text))


def fit(fine_words, idf, event_words, arch_words):
    """Share of the child's own words (idf-weighted) carried by the event, plus half the share carried by the archetype."""
    total = math.fsum(idf[w] for w in fine_words)
    if total <= 0:
        return 0.0
    ev = math.fsum(idf[w] for w in fine_words & event_words)
    ar = math.fsum(idf[w] for w in fine_words & arch_words)
    return (ev + 0.5 * ar) / total


def choose(seed, n, coarse, event_words, archetype, sharpness):
    """The fine id event number `n` of persona `seed` names under `coarse` (None when the field has no fine child)."""
    kids, idf = _index()
    if coarse not in kids:
        return None
    arch = archetype_words(archetype)
    ws = [w * math.exp(sharpness * fit(t, idf, event_words, arch)) for _, w, t in kids[coarse]]
    u = stream(seed, f"fine|{n}|{coarse}").random() * math.fsum(ws)
    acc = 0.0
    for (fid, _, _), w in zip(kids[coarse], ws):
        acc += w
        if u < acc:
            return fid
    return kids[coarse][-1][0]


def event_words(key, area, label, detail):
    """Words of an event: its template key and area, its diary line, and the text details (not the city)."""
    return words(" ".join([key.replace("_", " "), area, label] + [v for k, v in detail.items() if isinstance(v, str) and k != "city"]))


def name_fine(memberships, mapping):
    """The memberships with each coarse domain in `mapping` replaced by its fine domain, merged per (domain, rel)."""
    acc = {}
    for m in memberships:
        d = mapping.get(m["domain"], m["domain"])
        acc[(d, m["rel"])] = acc.get((d, m["rel"]), 0.0) + m["weight"]
    out = [{"domain": d, "rel": rel, "weight": round(w, 6)} for (d, rel), w in acc.items()]
    by = {}
    for x in out:
        by.setdefault(x["rel"], []).append(x)
    for ms in by.values():  # rounding must keep each relation summing to 1
        ms[-1]["weight"] = round(1 - sum(x["weight"] for x in ms[:-1]), 6)
    return out
