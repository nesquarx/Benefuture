"""The fine cards as the rest of the pipeline reads them: loading, upstream parents, placement parents, and the way a row
that names fine domains reads at the coarse level.

A fine domain's upstream links (weights summing to 1) are its coarse parents: evidence naming it reaches them by the
levels' aggregation (`lifeimage/levels.py`). A fine domain with no upstream link (47 of 786, overlap links only) has no
parent to aggregate into; it is placed by its heaviest overlap link (logged by the basemap) and a row naming it lights
that slice alone. Overlap links never carry colour.
"""
import json
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
FINE_PATH = ROOT / "data" / "fine" / "fine_v1.jsonl"


@lru_cache(maxsize=4)
def _load(path):
    return tuple(json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip())


def load_fine(path=FINE_PATH):
    """[card, ...] of the fine level, in file order."""
    return list(_load(str(path)))


def is_fine(card):
    return card.get("level") == "fine"


def upstream(card):
    """[(coarse id, weight)] of the upstream links, heaviest first (ties by id)."""
    return sorted(((l["id"], l["weight"]) for l in card["links"] if l["rel"] == "upstream"), key=lambda p: (-p[1], p[0]))


def placement_parents(card):
    """([(parent id, weight)], substituted): the upstream links, else (a degradation) the overlap links."""
    up = upstream(card)
    if up:
        return up, False
    return sorted(((l["id"], l["weight"]) for l in card["links"] if l["rel"] == "overlap"), key=lambda p: (-p[1], p[0])), True


def children_by_parent(fine_cards):
    """{coarse id: [(fine card, weight toward it)]} by upstream link, in card order."""
    out = {}
    for c in fine_cards:
        for p, w in upstream(c):
            out.setdefault(p, []).append((c, w))
    return out


def coarsen_memberships(memberships, fine_by_id):
    """The memberships with each fine domain read at its upstream coarse parents (its weight split by link weight, merged
    per (domain, rel)); a fine domain with no upstream stays as it is."""
    acc = {}
    for m in memberships:
        card = fine_by_id.get(m["domain"])
        ups = upstream(card) if card else []
        for d, w in (ups or [(m["domain"], 1.0)]):
            key = (d, m["rel"])
            acc[key] = acc.get(key, 0.0) + m["weight"] * w
    return [{"domain": d, "rel": rel, "weight": round(w, 6)} for (d, rel), w in acc.items()]


def coarsen_rows(rows, fine_cards):
    """Rows read at the coarse level (for the pressure sample, which counts coarse domains); rows naming no fine domain are
    returned as they are."""
    by = {c["id"]: c for c in fine_cards}
    out = []
    for r in rows:
        if any(m["domain"] in by for m in r["memberships"]):
            r = {**r, "memberships": coarsen_memberships(r["memberships"], by)}
        out.append(r)
    return out
