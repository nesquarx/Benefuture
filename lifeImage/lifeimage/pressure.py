"""Domain pressure (LI.25): the share of the evidence each domain carries, smoothed.

Pressure dictates slice widths; the axes dictate sectors. This is the measure only: layout does not use it yet.
Each row (or annotated item) counts once in total, split over its memberships by weight, so a row with many
memberships does not weigh more than one with few. Memberships of domains outside the given list are ignored. With
additive smoothing s, pressure(d) = (mass(d) + s) / (total mass + s * n): a distribution over the n listed domains,
uniform when there is no evidence, positive for every domain when s > 0 (a domain with no evidence yet keeps a slice).
"""


def _distribution(masses, domains, smoothing):
    if smoothing < 0:
        raise ValueError("smoothing must be >= 0")
    total = sum(masses.get(d, 0.0) for d in domains) + smoothing * len(domains)
    if total == 0:
        return {d: 1 / len(domains) for d in domains}
    return {d: (masses.get(d, 0.0) + smoothing) / total for d in domains}


def _add_unit(masses, weighted, known):
    kept = [(d, w) for d, w in weighted if d in known and w > 0]
    s = sum(w for _, w in kept)
    for d, w in kept:
        masses[d] = masses.get(d, 0.0) + w / s


def pressure_from_evidence(rows, domains, smoothing=1.0):
    """rows: evidence rows with `memberships` [{domain, rel, weight}]."""
    known, masses = set(domains), {}
    for r in rows:
        _add_unit(masses, [(m["domain"], m["weight"]) for m in r["memberships"]], known)
    return _distribution(masses, domains, smoothing)


def pressure_from_annotations(items, domains, smoothing=1.0):
    """items: {item id: {type: {domain: weight} or None}} (the merged annotations of `comembership.merge_items`)."""
    known, masses = set(domains), {}
    for types in items.values():
        _add_unit(masses, [(d, w) for ws in types.values() for d, w in (ws or {}).items()], known)
    return _distribution(masses, domains, smoothing)
