"""Levels (LI.36) and the channel split (LI.37): evidence rows to per-domain red, green and blue levels in [0, 1].

Each row imprints its own pattern on the circle: its memberships across related domains (colour stays in the row's
domains, a little bleeds to major upstream domains, none to neighbours; `projection.project` does the folding), with
luminosity = weight x decay. Imprints add per channel; a saturating tone map turns each domain's sum into a level,
level = 1 - exp(-sum / tone_k), so exposures compose as 1 - prod(1 - level) and a thousand small imprints approach but
never exceed one. A potential event (a claim or prediction) imprints with the level it claims: its amount is the sum
whose tone-mapped level is the claim, so red compares with green like for like.

Channel split (LI.37). Red is knowledge and potential: rows that take in (production `consumed`), claims (the claimed
tier, whatever the row says it did), self-assessments and predictions, and tests of knowing (red solid by tier).
Green is demonstrated skill: attested or measured rows that produce, and assessments of doing. Blue is impact: the
outcome membership of attested or measured rows that produce (a test measures skill, not what it changed). Grainy red
is never made solid and red without green reads as knowing or claiming without doing. Taking in counts
`consumed_weight` as much as producing.

A row's `production` is `produced` or `consumed`; where the field is absent (extracted rows) the relation decides:
`impacted` is consumed, anything else produced. `test_kind` is `knowing` or `doing` on a test or assessment row.

Layers: `solid` (attested and measured) and `claimed`, each tone-mapped separately.
"""
import math
from dataclasses import dataclass
from datetime import date

from .projection import DEFAULT as PROJECTION
from .projection import project

CHANNELS = ("red", "green", "blue")
PRODUCTION = ("produced", "consumed")
TEST_KINDS = ("knowing", "doing")
ALL_RELS = frozenset({"form", "content", "outcome"})
KNOWLEDGE_RELS = ("form", "content")


@dataclass(frozen=True)
class Governed:
    """Governed constants of the levels (defaults; each is a threshold to be governed later)."""
    half_life_years: float = 15.0  # a row's luminosity halves every this many years
    tone_k: float = 1.0  # tone map level = 1 - exp(-sum / tone_k): a summed luminosity of tone_k gives level 0.63
    consumed_weight: float = 0.5  # taking in imprints this fraction of what producing does
    max_claimed_level: float = 0.99  # a claim of 1 would need an infinite imprint
    projection: object = PROJECTION  # bleed to upstream domains


DEFAULT = Governed()


def parse_time(s):
    y, m, d = (s.split("-") + ["1", "1"])[:3]
    return date(int(y), int(m), int(d))


def years_between(a, b):
    return (a - b).days / 365.25


def production(row):
    return row.get("production") or ("consumed" if row["relation"] == "impacted" else "produced")


def decay(age_years, governed=DEFAULT):
    return 0.5 ** (max(0.0, age_years) / governed.half_life_years)


def tone(s, governed=DEFAULT):
    return 1.0 - math.exp(-max(0.0, s) / governed.tone_k)


def claimed_amount(level, governed=DEFAULT):
    """The summed luminosity whose tone-mapped level is the claim."""
    return -governed.tone_k * math.log(1.0 - min(max(level, 0.0), governed.max_claimed_level))


def route(r):
    """[(layer, channel, rels, weight factor)] a live positive or prediction row imprints in, before decay."""
    if r["channel"] == "prediction":
        return [("claimed", "red", ("form", "content", "outcome"), 1.0)]
    claimed = r["tier"] == "claimed"
    layer = "claimed" if claimed else "solid"
    consumed = production(r) == "consumed"
    kind = r.get("test_kind")
    if claimed:  # a claim is knowledge or potential, whatever it claims to have done
        return [("claimed", "red", ("form", "content", "outcome"), 1.0)]
    if kind == "knowing":
        return [(layer, "red", KNOWLEDGE_RELS, 1.0)]
    if kind == "doing":
        return [(layer, "green", KNOWLEDGE_RELS, 1.0)]
    if consumed:
        return [(layer, "red", KNOWLEDGE_RELS, 1.0)]
    return [(layer, "green", KNOWLEDGE_RELS, 1.0), (layer, "blue", ("outcome",), 1.0)]


def imprints(rows, cards, governed=DEFAULT, asof=None):
    """[{layer, channel, row, amount, memberships}]: one per row and channel, amount = luminosity (weight x decay)."""
    known = {c["id"] for c in cards}
    live = [r for r in rows if not r["revoked"] and r["channel"] in ("positive", "prediction")]
    for r in live:
        for m in r["memberships"]:
            if m["domain"] not in known:
                raise ValueError(f"unknown domain {m['domain']}")
    ref = parse_time(asof) if asof else max((parse_time(r["valid_time"]) for r in live), default=None)
    out = []
    for r in live:
        dim = decay(years_between(ref, parse_time(r["valid_time"])), governed)
        base = claimed_amount(r["magnitude"], governed) if r["channel"] == "prediction" else r["magnitude"]
        w_consumed = governed.consumed_weight if r["channel"] == "positive" and production(r) == "consumed" else 1.0
        for layer, channel, rels, f in route(r):
            ms = [m for m in r["memberships"] if m["rel"] in rels]
            n = len({m["rel"] for m in ms})
            if ms:
                out.append({"layer": layer, "channel": channel, "row": r, "amount": base * dim * f * w_consumed,
                            "memberships": [{**m, "weight": m["weight"] / n} for m in ms]})
    return out


def channel_levels(rows, cards, governed=DEFAULT, asof=None):
    """{"solid": {domain: {red, green, blue}}, "claimed": {...}}: per-domain levels in [0, 1]."""
    derived = {"solid": [], "claimed": []}
    for imp in imprints(rows, cards, governed, asof):
        r = imp["row"]
        derived[imp["layer"]].append({"entity": "x", "relation": "causal", "channel": imp["channel"], "sign": 1, "revoked": False,
                                      "magnitude": imp["amount"], "memberships": imp["memberships"]})
    out = {}
    for layer, rs in derived.items():
        out[layer] = {}
        for _entity, per_domain in sorted(project(rs, cards, governed.projection, ALL_RELS).items()):
            for d, ch in per_domain.items():
                row = out[layer].setdefault(d, dict.fromkeys(CHANNELS, 0.0))
                for k in CHANNELS:
                    row[k] += max(0.0, ch.get(k, 0.0))
        for d, row in out[layer].items():
            for k in CHANNELS:
                row[k] = tone(row[k], governed)
    return out
