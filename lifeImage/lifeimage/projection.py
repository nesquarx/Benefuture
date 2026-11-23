"""Projection: folds evidence rows into per-domain channel values for the image.

The Life Image is a view over a subset of an event's relations. Each membership of a row is weighed by a governed
table keyed (entity relation, membership rel): outputs (causal, communicative) count fully; passive consumption
(impacted) counts only up to a small cap, however much of it there is. Colour stays in the row's own domains; a
governed fraction bleeds one step to a domain's upstream links by link weight, never to overlap links. Bleed moves
amount from the source to its upstream domains, so each stream (entity, relation, membership rel, channel) keeps its
total. Without the cap a thousand viewings outweigh one review; without conservation the bleed mints colour.

Values are sign x magnitude x membership weight x table weight. Confidence stays on the row and is rendered
separately.
"""
from collections import namedtuple
from dataclasses import dataclass, field

from .vocab import MEMBERSHIP_RELS, UPSTREAM

Entry = namedtuple("Entry", "weight cap")  # cap: fraction of full_output_weight, per (entity, domain, stream); None = none


@dataclass(frozen=True)
class Governed:
    """Every governed value of the projection, with its default."""
    bleed_fraction: float = 0.1  # share of a domain's colour passed one step to its upstream links
    full_output_weight: float = 1.0  # the weight of one full output; caps are fractions of it
    table: dict = field(default_factory=lambda: {
        ("causal", "*"): Entry(1.0, None),
        ("communicative", "*"): Entry(1.0, None),
        ("structural", "*"): Entry(0.5, None),
        ("impacted", "*"): Entry(1.0, 0.1),
    })


DEFAULT = Governed()


def _entry(governed, relation, rel):
    e = governed.table.get((relation, rel)) or governed.table.get((relation, "*"))
    if e is None:
        raise ValueError(f"no table entry for entity relation {relation!r} with membership rel {rel!r}")
    return e


def fold(rows, cards, governed=DEFAULT, membership_rels=MEMBERSHIP_RELS):
    """{(entity, relation, rel, channel): {domain: value}} after caps and bleed."""
    by_id = {c["id"]: c for c in cards}
    for c in cards:
        for l in c["links"]:
            if l["id"] not in by_id:
                raise ValueError(f"{c['id']}: link target {l['id']} is not in the card set")
    direct = {}
    for r in rows:
        if r["revoked"]:
            continue
        for m in r["memberships"]:
            if m["domain"] not in by_id:
                raise ValueError(f"unknown domain {m['domain']}")
            if m["rel"] not in membership_rels:
                raise ValueError(f"unknown membership rel {m['rel']!r}")
            e = _entry(governed, r["relation"], m["rel"])
            key = (r["entity"], r["relation"], m["rel"], r["channel"], m["domain"])
            direct[key] = direct.get(key, 0.0) + r["sign"] * r["magnitude"] * m["weight"] * e.weight
    streams = {}
    for (entity, relation, rel, channel, domain), v in sorted(direct.items()):
        cap = _entry(governed, relation, rel).cap
        if cap is not None:
            limit = cap * governed.full_output_weight
            v = max(-limit, min(limit, v))
        s = streams.setdefault((entity, relation, rel, channel), {})
        ups = [l for l in by_id[domain]["links"] if l["rel"] == UPSTREAM]
        give = v * governed.bleed_fraction if ups else 0.0
        s[domain] = s.get(domain, 0.0) + v - give
        for l in ups:
            s[l["id"]] = s.get(l["id"], 0.0) + give * l["weight"]
    return streams


def project(rows, cards, governed=DEFAULT, membership_rels=MEMBERSHIP_RELS):
    """{entity: {domain: {channel: value}}}."""
    out = {}
    for (entity, _relation, _rel, channel), s in fold(rows, cards, governed, membership_rels).items():
        for domain, v in s.items():
            ch = out.setdefault(entity, {}).setdefault(domain, {})
            ch[channel] = ch.get(channel, 0.0) + v
    return out
