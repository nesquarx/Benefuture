"""Release migration tables: a sparse linear map from old ids to weighted new ids.

Ops: split (old -> weighted new ids), merge (several old -> one new), rename, deprecate (tombstone with weighted
successors). Every row of the map sums to 1, so migrating a domain-weight vector preserves its total; ids not in
the table map to themselves. Migration is a pure function of (vector, table).

Evidence rows migrate through their memberships: each relation's weights are a vector migrated on its own, so every
relation still sums to 1 and a domain reached by several olds in one relation gets the sum of their weights.
`convert_card_v0` rewrites cards from the parents/neighbours form into links.
"""
import math
import re

from .vocab import OVERLAP, UPSTREAM

TOL = 1e-6


def _refs(refs, what):
    if not refs:
        raise ValueError(f"{what}: needs at least one target")
    return {r["id"]: r["weight"] for r in refs}


def validate_table(table, retired_ids=()):
    for old, row in table.items():
        if not row:
            raise ValueError(f"{old}: empty row would drop weight")
        if abs(math.fsum(row.values()) - 1.0) > TOL:
            raise ValueError(f"{old}: row sums to {math.fsum(row.values())}, not 1")
        if any(w <= 0 for w in row.values()):
            raise ValueError(f"{old}: non-positive weight")
        for new in row:
            if new in retired_ids:
                raise ValueError(f"{old}: target {new} is retired and never reused")
    return table


def build_table(ops, existing_ids, retired_ids=()):
    table = {}
    for op in ops:
        kind = op.get("op")
        if kind == "split":
            olds, row = [op["old"]], _refs(op["new"], f"split {op['old']}")
        elif kind == "merge":
            olds, row = list(op["old"]), {op["new"]: 1.0}
        elif kind == "rename":
            olds, row = [op["old"]], {op["new"]: 1.0}
        elif kind == "deprecate":
            olds, row = [op["old"]], _refs(op.get("successors"), f"deprecate {op['old']}")
        else:
            raise ValueError(f"unknown op {kind!r}")
        for old in olds:
            if old not in existing_ids:
                raise ValueError(f"{old}: not an existing id")
            if old in table:
                raise ValueError(f"{old}: appears in more than one op")
            table[old] = dict(row)
    return validate_table(table, retired_ids)


def migrate_vector(vec, table):
    if abs(math.fsum(vec.values()) - 1.0) > TOL:
        raise ValueError("domain weights must sum to 1")
    out = {}
    for old, w in vec.items():
        for new, tw in table.get(old, {old: 1.0}).items():
            out[new] = out.get(new, 0.0) + w * tw
    return out


def apply_table(vectors, table):
    return [migrate_vector(v, table) for v in vectors]


def migrate_memberships(memberships, table):
    """[{domain, rel, weight}] -> the same under the new ids; per-relation weights stay summing to 1."""
    by_rel = {}
    for m in memberships:
        vec = by_rel.setdefault(m["rel"], {})
        vec[m["domain"]] = vec.get(m["domain"], 0.0) + m["weight"]
    out = []
    for rel, vec in by_rel.items():
        try:
            moved = migrate_vector(vec, table)
        except ValueError:
            raise ValueError(f"memberships of relation {rel!r} do not sum to 1") from None
        out += [{"domain": d, "rel": rel, "weight": w} for d, w in moved.items()]
    return out


def migrate_row(row, table, basemap_version):
    return {**row, "memberships": migrate_memberships(row["memberships"], table), "basemap_version": basemap_version}


def convert_card_v0(card):
    """Card with parents and neighbours -> card with links (parents become upstream, neighbours overlap), weights
    kept; the two provenance entries fold into one `links` entry at the weaker confidence."""
    if "parents" not in card or "neighbours" not in card:
        raise ValueError(f"{card.get('id')}: no parents/neighbours to convert (already migrated?)")
    out = {k: v for k, v in card.items() if k not in ("parents", "neighbours")}
    out["links"] = ([{"id": p["id"], "rel": UPSTREAM, "weight": p["weight"]} for p in card["parents"]]
                    + [{"id": n["id"], "rel": OVERLAP, "weight": n["weight"]} for n in card["neighbours"]])
    prov = {k: v for k, v in card["provenance"].items() if k not in ("parents", "neighbours")}
    old = [card["provenance"][k] for k in ("parents", "neighbours") if k in card["provenance"]]
    if old:
        prov["links"] = dict(min(old, key=lambda e: e["confidence"]))
    out["provenance"] = prov
    return out


def convert_cards_v0(cards):
    return [convert_card_v0(c) for c in cards]


DATE = re.compile(r"^\d{4}(-\d{2}(-\d{2})?)?$")
ENTITY_KINDS = ("person", "organisation", "ai", "animal", "other")


def migrate_evidence_v0(row):
    """Row with the single `date` -> row with `valid_time` (the date) and `record_time` (the same value: the old
    contract kept one date, so the best known record time is the date itself). Rows already in the new form pass
    through; a row carrying both forms or a malformed date raises."""
    if "date" not in row:
        return dict(row)
    if "valid_time" in row or "record_time" in row:
        raise ValueError("row carries both date and valid_time/record_time")
    if not isinstance(row["date"], str) or not DATE.match(row["date"]):
        raise ValueError(f"malformed date {row['date']!r}")
    out = {k: v for k, v in row.items() if k != "date"}
    out["valid_time"] = out["record_time"] = row["date"]
    return out


def read_evidence(row):
    """An evidence row of either contract version, in the current one."""
    return migrate_evidence_v0(row)


def migrate_entity_v0(entity):
    """Entity id (string) -> {id, kind}. The kind is taken only from an id prefix that is itself a kind name
    ("person:1"); otherwise "other", never a guess."""
    prefix = entity.split(":", 1)[0] if ":" in entity else None
    return {"id": entity, "kind": prefix if prefix in ENTITY_KINDS else "other"}


def migrate_card_links(card):
    """Card with each link stamped with the version it was recorded under (the card's basemap version) where it
    carries none; existing versions and supports are kept, a missing support stays missing (unknown, not 0)."""
    out = dict(card)
    out["links"] = [{**l, "version": l.get("version", card["basemap_version"])} for l in card["links"]]
    return out
