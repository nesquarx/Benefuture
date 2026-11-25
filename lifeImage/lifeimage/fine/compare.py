"""Checking fine parents against the data-learnt co-membership of the coarse domains (`comembership.py`).

A fine domain with two or more parents asserts that those coarse domains share ground. The data can test it: a pair is
supported when the learnt co-membership has support >= `min_support` for it (either direction, pooled over types). The
baseline is the supported share among all pairs of coarse fields, so a rate above it means the model's multi-parent
choices follow what events actually co-occur. The data covers only coarse fields (fine domains have no events yet).
"""
from itertools import combinations

from ..comembership import pair_view


def main_parent(card):
    ls = card["links"]
    return min(ls, key=lambda l: (-l["weight"], l["id"]))["id"] if ls else None


def parent_pair_agreement(cards, rows, coarse_ids, min_support=3):
    pv = pair_view(rows)
    has = lambda a, b: max(pv.get((a, b), (0, 0))[1], pv.get((b, a), (0, 0))[1]) >= min_support
    multi = [c for c in cards if len(c["links"]) >= 2]
    pairs = [(main_parent(c), l["id"]) for c in multi for l in c["links"] if l["id"] != main_parent(c)]
    done = sum(has(a, b) for a, b in pairs)
    allp = list(combinations(sorted(coarse_ids), 2))
    return {"multi_parent_cards": len(multi), "pairs": len(pairs), "pairs_with_data": done,
            "rate": done / len(pairs) if pairs else 0.0,
            "baseline_rate": sum(has(a, b) for a, b in allp) / len(allp) if allp else 0.0, "min_support": min_support}
