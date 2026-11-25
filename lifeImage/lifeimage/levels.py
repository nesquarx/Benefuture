"""Levels (LI.36), the channel split (LI.37, LI.38) and the tone anchor (LI.39): evidence rows to per-domain red, green and
blue levels in [0, 1].

Each row imprints its own pattern on the circle: its memberships across related domains (colour stays in the row's
domains, a little bleeds to major upstream domains, none to neighbours; `projection.project` does the folding), with
luminosity = weight x decay. Imprints add per channel; a saturating tone map turns each domain's sum into a level,
level = 1 - exp(-sum / tone_k), so exposures compose as 1 - prod(1 - level) and a thousand small imprints approach but
never exceed one. `tone_k` is the governed value `levels.tone_k` (`lifeimage/governed.py`), derived so that a reference
life's typical touched domain is at level 0.5; the scale is absolute across people. A potential event (a claim or
prediction) imprints with the level it claims: its amount is the sum whose tone-mapped level is the claim, so red
compares with green like for like.

Channel split. Red is knowledge and potential: rows that take in (production `consumed`), tests of knowing, and
predictions (self-assessments, forecasts, claims of capability). Green is demonstrated skill: rows that produce, and
assessments of doing. Blue is impact: the outcome membership of rows that produce (a test measures skill, not what it
changed). Taking in counts `consumed_weight` as much as producing. Red without green reads as knowing or claiming
without doing.

Fine level (LI.51). A row may name a fine domain (a card of level `fine`) instead of its coarse field. The imprint lands on
the fine domain, a little bleeds to its upstream coarse fields (LI.30, by link weight), none to neighbours or overlap
links, and a coarse level aggregates its fine children: its summed luminosity is its own (direct imprints and the bleed it
received) plus each child's summed luminosity times the link weight, and the tone map is applied to that sum once
(re-saturated, so it never exceeds 1). A fine imprint thus reaches its coarse field whole, once: the child keeps
1 - bleed of it, the field gets the bleed plus what the child holds. The aggregate is one step (fine to coarse): a sector
is lit by what names coarse fields directly, not by their fine children.

Layers. `claimed` holds claimed potential only: the red of prediction rows, drawn as grain. Every other row, whatever its
tier, is `solid`. Tier shows only as saturation: each solid domain carries `saturation`, the imprint-weighted mean of
the tier saturations (measured, attested, claimed) of the rows that built it, so self-reported colour is pale and a
record is full. Tier never changes a level and never makes grain.

A row's `production` is `produced` or `consumed`; where the field is absent (extracted rows) the relation decides:
`impacted` is consumed, anything else produced. `test_kind` is `knowing` or `doing` on a test or assessment row.
"""
import math
from dataclasses import dataclass
from datetime import date

from . import governed as gv
from .fine.cards import is_fine, upstream
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
    tone_k: float = gv.governed("levels.tone_k")  # tone map level = 1 - exp(-sum / tone_k); derived (LI.39), a summed luminosity of tone_k gives 0.63
    saturation_measured: float = gv.governed("levels.saturation_measured")  # share of colour kept, by tier of the rows that built a slice
    saturation_attested: float = gv.governed("levels.saturation_attested")
    saturation_claimed: float = gv.governed("levels.saturation_claimed")
    consumed_weight: float = 0.5  # taking in imprints this fraction of what producing does
    max_claimed_level: float = 0.99  # a claim of 1 would need an infinite imprint
    projection: object = PROJECTION  # bleed to upstream domains


    def saturation(self, tier):
        return {"measured": self.saturation_measured, "attested": self.saturation_attested, "claimed": self.saturation_claimed}[tier]


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
    consumed = production(r) == "consumed"
    kind = r.get("test_kind")
    if kind == "knowing":
        return [("solid", "red", KNOWLEDGE_RELS, 1.0)]
    if kind == "doing":
        return [("solid", "green", KNOWLEDGE_RELS, 1.0)]
    if consumed:
        return [("solid", "red", KNOWLEDGE_RELS, 1.0)]
    return [("solid", "green", KNOWLEDGE_RELS, 1.0), ("solid", "blue", ("outcome",), 1.0)]


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


def _fold(imps, cards, governed):
    """{(layer, tier): {domain: {channel: summed luminosity}}} of imprints (before the tone map)."""
    derived = {}
    for imp in imps:
        tier = imp["row"]["tier"] if imp["layer"] == "solid" else "claimed"
        derived.setdefault((imp["layer"], tier), []).append(
            {"entity": "x", "relation": "causal", "channel": imp["channel"], "sign": 1, "revoked": False,
             "magnitude": imp["amount"], "memberships": imp["memberships"]})
    out = {}
    fine = {c["id"]: upstream(c) for c in cards if is_fine(c)}
    for key, rs in sorted(derived.items()):
        sums = out.setdefault(key, {})
        for _entity, per_domain in sorted(project(rs, cards, governed.projection, ALL_RELS).items()):
            for d, ch in per_domain.items():
                row = sums.setdefault(d, dict.fromkeys(CHANNELS, 0.0))
                for k in CHANNELS:
                    row[k] += max(0.0, ch.get(k, 0.0))
        held = {d: dict(v) for d, v in sums.items() if d in fine}  # the children's sums, before any aggregation
        for d, ch in sorted(held.items()):
            for parent, w in fine[d]:
                row = sums.setdefault(parent, dict.fromkeys(CHANNELS, 0.0))
                for k in CHANNELS:
                    row[k] += ch[k] * w
    return out


def raw_sums(rows, cards, governed=DEFAULT, asof=None):
    """{"solid": {domain: {channel: sum}}, "claimed": {...}, "tier_mass": {domain: {tier: mass}}}: summed luminosity before
    the tone map (the solid layer over all tiers; tier_mass is the solid sum over channels by tier)."""
    folded = _fold(imprints(rows, cards, governed, asof), cards, governed)
    out = {"solid": {}, "claimed": {}, "tier_mass": {}}
    for (layer, tier), sums in folded.items():
        for d, ch in sums.items():
            row = out[layer].setdefault(d, dict.fromkeys(CHANNELS, 0.0))
            for k in CHANNELS:
                row[k] += ch[k]
            if layer == "solid":
                tm = out["tier_mass"].setdefault(d, {})
                tm[tier] = tm.get(tier, 0.0) + math.fsum(ch.values())
    return out


def touched_domains(rows, cards, governed=DEFAULT, asof=None):
    """Domains a solid imprint names directly (not by upstream bleed)."""
    return {m["domain"] for imp in imprints(rows, cards, governed, asof) if imp["layer"] == "solid" for m in imp["memberships"]}


def touched_coarse(rows, cards, governed=DEFAULT, asof=None):
    """The coarse domains a solid imprint names directly, and the main upstream field (heaviest link, never a sector) of each
    fine domain it names: what the anchor of LI.39 and the characterisation count as touched. A fine domain's lighter
    parents are lit by the aggregate but not touched (the leak of a two-parent domain is not a field the life visited)."""
    by = {c["id"]: c for c in cards}
    out = set()
    for d in touched_domains(rows, cards, governed, asof):
        if d in by and is_fine(by[d]):
            ups = [p for p, _w in upstream(by[d]) if not p.startswith("s.")]
            out.update(ups[:1])
        else:
            out.add(d)
    return out


def touched_with_parents(rows, cards, governed=DEFAULT, asof=None):
    """Touched domains for the image: those named directly (fine ones too) and the coarse fields they make touched."""
    return touched_domains(rows, cards, governed, asof) | touched_coarse(rows, cards, governed, asof)


def channel_levels(rows, cards, governed=DEFAULT, asof=None):
    """{"solid": {domain: {red, green, blue, saturation}}, "claimed": {domain: {red, green, blue}}}: per-domain levels in
    [0, 1] and the solid layer's saturation (imprint-weighted mean of the tier saturations)."""
    raw = raw_sums(rows, cards, governed, asof)
    out = {"solid": {}, "claimed": {}}
    for layer in out:
        for d, row in raw[layer].items():
            out[layer][d] = {k: tone(row[k], governed) for k in CHANNELS}
    for d, tm in raw["tier_mass"].items():
        total = math.fsum(tm.values())
        out["solid"][d]["saturation"] = math.fsum(governed.saturation(t) * m for t, m in tm.items()) / total if total > 0 else 1.0
    return out
