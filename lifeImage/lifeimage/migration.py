"""Release migration tables: a sparse linear map from old ids to weighted new ids.

Ops: split (old -> weighted new ids), merge (several old -> one new), rename, deprecate (tombstone with weighted
successors). Every row of the map sums to 1, so migrating a domain-weight vector preserves its total; ids not in
the table map to themselves. Migration is a pure function of (vector, table).
"""
import math

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
