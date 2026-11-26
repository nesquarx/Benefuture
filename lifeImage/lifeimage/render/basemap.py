"""Basemap v0: where each coarse field sits on the image (LI.22 to LI.26).

Angle (LI.24, LI.25): each field is placed once, at the angle of its axes position, the mean of the cached axes
votes: the v3 means (`axis_at` and `axis_pg` answers on a 0-10 scale, 5 balanced, scaled to [-1, 1]) when the field has
votes on both axes, else the v1/v2 means (prompt versions 1 and 2; three variants each), the fallback recorded loudly
(`degradation`, mechanism `axes_v3`, with the fields named). Abstract-tangible horizontal (0 deg = tangible, right) and
personal-global vertical (90 deg = global, top). A field whose mean axes are shorter than `layout.AXES_MIN` has no
direction and takes the weighted circular mean of its upstream domains (listed in `Basemap.inherited`). A sector has
no axes of its own and takes the weighted circular mean of the fields placed under it.

Slice width (LI.25): within each ring, slices keep the circular order of their axes angles and take widths in
proportion to pressure (`pressure.pressure_from_evidence` over the rows given), after a minimum slice so that a
domain with no evidence yet keeps a place. A slice's centre therefore follows its axes angle only up to the shift the
widths cause; `Slice.axes_angle` keeps the angle the axes alone gave and `Basemap.shift` reports the spread.

Radius (LI.26): sectors fill the inner ring, fields the outer. Inside its ring a domain takes a radial band of
`BAND` of the ring's span, placed by its radius composite (`radius.composite` on the card, from `lifeimage.radius`:
complexity, difficulty and specificity, outward-increasing), scaled so the ring's innermost composite sits at the ring's
inner edge and its outermost at the outer edge. A domain without a composite falls back to depth: it spans its whole
ring, recorded loudly (`degradation`, mechanism `radius_composite`, the domains named). `by_depth=True` asks for depth outright (the legacy projection), unlogged. Equal composites in a ring sit mid-ring.

Fine level (LI.51). Fine domains are placed once, inside the arc of their main parent (`fine/placement.py`: the heaviest
upstream link, else the heaviest overlap link, the substitution logged as `fine_placement`), ordered by their pull toward
their other parents, in an outer ring, so no coarse arc, order or centre moves (the fine level is drawn after the coarse
one and pressure is counted at the coarse fields, `fine.cards.coarsen_rows`). Fine children of a coarse field sit in the
ring just outside the rim (`FINE_RING`), those whose main parent is a sector in the one beyond it (`FINE_SECTOR_RING`).
A fine domain's radial band comes from the composite on its card, scaled within its ring like the coarse ones; the judged
radius exists for coarse fields only, so the mechanical composite stands in for fine domains, recorded loudly
(`radius_judged`). `Basemap.fine` holds the fine slices (`Slice.parent` is the main parent), `Basemap.extent` the half-width
a drawing needs.

Everything is deterministic: ties break by id, no randomness, no clock.
"""
import json
import math
from dataclasses import dataclass, field
from pathlib import Path

from ..axes import axes_input, parse_scores
from ..axes_v3 import parse_scale
from ..canonical import content_hash
from ..degradation import record_degradation
from ..fine.cards import coarsen_rows, load_fine, placement_parents
from ..fine.placement import main_parent, place_fine
from ..layout import AXES_MIN, _mean_angle, angle_from_axes, circ_diff
from ..packs import is_sector
from ..pressure import pressure_from_evidence

ROOT = Path(__file__).resolve().parent.parent.parent
CARDS = ROOT / "data/coarse/seed_v3.jsonl"
LEGACY_CARDS = (ROOT / "data/coarse/seed_v0.jsonl", ROOT / "data/coarse/seed_v1.jsonl", ROOT / "data/coarse/seed_v2.jsonl")  # answers cached against earlier links
ANSWERS = ROOT / "data/answers/axes.jsonl"

SECTOR_RING = (0.16, 0.42)  # (r0, r1) as a fraction of the rim
FIELD_RING = (0.44, 0.96)
MIN_FIELD_SLICE = 0.25  # governed: degrees, the least a field keeps however little evidence it has
MIN_SECTOR_SLICE = 2.0  # governed: degrees
BAND = 0.2  # governed: a domain's radial band as a share of its ring's span (LI.26)
FINE_RING = (0.98, 1.12)  # fine children of a coarse field
FINE_SECTOR_RING = (1.14, 1.28)  # fine domains whose main parent is a sector
FINE_BAND = 0.5  # governed: a fine domain's radial band as a share of its (narrow) ring's span
EXTENT_MARGIN = 0.25  # room outside the outermost ring for the orientation flange
SMOOTHING = 1.0  # governed: additive pressure smoothing (`pressure.py`)

# Coarse ring order (LI.66). A layout is a pinned file holding the field order and the slot angles the tiling is turned to;
# "axes_v0" is the earlier order (circular order of the axes angles, no file) and keeps the bare card version. The default
# is the seriation order (LI.60); a new layout never changes a domain id, so the id migration table between versions is identity.
LAYOUTS = {"axes_v0": None, "seriation_v0": "data/coarse/layout_seriation_v0.json"}
DEFAULT_LAYOUT = "seriation_v0"


def layout_version(card_version, layout):
    """The basemap version id: the card version for the axes layout, `<card version>+<layout>` for a pinned one."""
    if layout not in LAYOUTS:
        raise ValueError(f"unknown layout {layout!r}; known: {sorted(LAYOUTS)}")
    return card_version if LAYOUTS[layout] is None else f"{card_version}+{layout}"


def load_layout(layout, root=None):
    """The pinned ring order of `layout` ({"order": [...], "angles": {...}}), or None for the axes layout."""
    if layout not in LAYOUTS:
        raise ValueError(f"unknown layout {layout!r}; known: {sorted(LAYOUTS)}")
    return None if LAYOUTS[layout] is None else json.loads((Path(root or ROOT) / LAYOUTS[layout]).read_text(encoding="utf-8"))

OPEN_NOTES = [
    "[OPEN] Radius within a ring comes from the mechanical proxies of `lifeimage.radius` (LI.26): complexity and "
    "specificity cover every domain, difficulty under a fifth (ISCO skill level), and specificity does not yet "
    "correlate positively with the other two; novelty (L159) is not used. A domain with no composite spans its whole ring (logged).",
    "[OPEN] Pressure here is the share of the synthetic persona, organisation and public-figure rows, a tiny and "
    "unrepresentative sample; real pressure is the smoothed share of recent works, postings and evidence rows (LI.25).",
    "Field order (LI.66): the pinned seriation order of the default layout; the `axes_v0` layout orders by axes angle. "
    "Sector order, and for `axes_v0` the field order, is the circular order of axes angles, from the 0-10 axes scores (v3, two variants per axis) where "
    "present, else the five-point v1/v2 means (logged); ties break by their primary sector's angle, then id.",
]


@dataclass(frozen=True)
class Slice:
    id: str
    ring: str  # sector | field
    axes_angle: float  # degrees, from the axes (or inherited); the centre the layout aims at
    start: float  # degrees in [0, 360)
    width: float
    r0: float
    r1: float
    pressure: float
    source: str  # axes | upstream | children
    composite: float = None  # radius composite behind the band; None when the domain fell back to depth
    parent: str = None  # fine slices: the main parent whose arc holds this slice

    @property
    def angle(self):
        return (self.start + self.width / 2) % 360


@dataclass
class Basemap:
    version: str = ""
    slices: dict = field(default_factory=dict)
    inherited: list = field(default_factory=list)  # fields that took their upstream's mean angle
    notes: list = field(default_factory=list)
    shift: dict = field(default_factory=dict)  # ring -> {mean, max}: degrees between slice centre and axes angle
    votes: dict = field(default_factory=dict)  # field id -> number of axes votes behind its angle
    radius_fallback: list = field(default_factory=list)  # domains without a composite, placed by depth
    fine: dict = field(default_factory=dict)  # fine domain id -> Slice (ring "fine"), inside the main parent's arc
    extent: float = 1.0 + EXTENT_MARGIN  # half-width of the drawing: the outermost ring plus a margin


def read_jsonl(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def load_cards(path=CARDS):
    return read_jsonl(path)


def axes_means(cards, answers_path=ANSWERS, legacy=LEGACY_CARDS, v3_paths=None, log=None):
    """{field id: {abstract_tangible, personal_global, votes, source}}, scores scaled to [-1, 1]. A field takes its v3
    means (the cached `axis_at` and `axis_pg` answers, 0 abstract / personal to 10 tangible / global, 5 balanced; votes
    is the smaller count of the two axes) when it has votes on both axes (`source` "v3"), else the mean of every
    cached v1/v2 vote (`source` "v1v2"), the substitution recorded loudly in `log` (see `degradation`). Votes are
    matched to fields by the hash of the axes input; answers cached against earlier card sets (`legacy`) are matched
    through those sets. `v3_paths` is (axis_at file, axis_pg file), by default beside `answers_path`. Fields with no
    vote are absent."""
    index = {}
    for cs in [cards] + [read_jsonl(p) for p in legacy if Path(p).exists()]:
        by = {c["id"]: c for c in cs}
        for c in cs:
            if not is_sector(c):
                index.setdefault(content_hash(axes_input(c, by)), c["id"])
    want = {c["id"] for c in cards}
    acc = {}
    for a in read_jsonl(answers_path):
        i = index.get(a["input_hash"])
        if i in want:
            acc.setdefault(i, []).append(parse_scores(a["verdict"]))
    out = {i: {"abstract_tangible": math.fsum(s[0] for s in v) / len(v) / 2,
               "personal_global": math.fsum(s[1] for s in v) / len(v) / 2, "votes": len(v), "source": "v1v2"}
           for i, v in sorted(acc.items())}
    v3_paths = v3_paths or [Path(answers_path).parent / f"{t}.jsonl" for t in ("axis_at", "axis_pg")]
    v3 = {}
    for path, (task_type, axis) in zip(v3_paths, (("axis_at", "abstract_tangible"), ("axis_pg", "personal_global"))):
        for a in read_jsonl(path) if Path(path).exists() else []:
            i = index.get(a["input_hash"])
            if i in want and a.get("task_type", task_type) == task_type:
                v3.setdefault(i, {}).setdefault(axis, []).append(parse_scale(a["verdict"]))
    for i, d in sorted(v3.items()):
        if len(d) == 2:
            out[i] = {**{ax: (math.fsum(v) / len(v) - 5) / 5 for ax, v in d.items()}, "votes": min(len(v) for v in d.values()), "source": "v3"}
    fallback = sorted(i for i, a in out.items() if a["source"] == "v1v2")
    if fallback:
        shown = ", ".join(fallback[:5]) + (f" and {len(fallback) - 5} more" if len(fallback) > 5 else "")
        record_degradation(f"axes_means: {shown}", "axes_v3", "axes v1/v2 means",
                           f"no axis_at and axis_pg v3 answers for {len(fallback)} of {len(out)} fields", log)
    return dict(sorted(out.items()))


def _own(ax):
    if ax and math.hypot(ax["abstract_tangible"], ax["personal_global"]) >= AXES_MIN:
        return angle_from_axes(ax)
    return None


def _upstream(card):
    return [(l["id"], l["weight"]) for l in card["links"] if l["rel"] == "upstream"]


def place_angles(cards, axes):
    """({id: degrees}, {id: source}, [inherited field ids]). Fields: own axes, else upstream mean once the upstream is
    placed (sectors place from their children first). Sectors: weighted mean of the fields placed under them."""
    by = {c["id"]: c for c in cards}
    angle, source = {}, {}
    for c in cards:
        if not is_sector(c) and (a := _own(axes.get(c["id"]))) is not None:
            angle[c["id"]], source[c["id"]] = a, "axes"
    for c in cards:
        if is_sector(c):
            kids = [(angle[k["id"]], l["weight"]) for k in cards if k["id"] in angle
                    for l in k["links"] if l["rel"] == "upstream" and l["id"] == c["id"]]
            if kids and (m := _mean_angle(kids)) is not None:
                angle[c["id"]], source[c["id"]] = m, "children"
    pending = sorted(i for i in by if i not in angle)
    while pending:
        fresh = {}
        for i in pending:
            known = [(angle[u], w) for u, w in _upstream(by[i]) if u in angle]
            if known and (m := _mean_angle(known)) is not None:
                fresh[i] = m
        if not fresh:
            raise ValueError(f"no axes and no placed upstream domain for {pending}")
        angle.update(fresh)
        source.update({i: "upstream" for i in fresh})
        pending = [i for i in pending if i not in angle]
    return angle, source, sorted(i for i, s in source.items() if s == "upstream" and not is_sector(by[i]))


def slice_ring(items, weights, floor):
    """Tile the circle in the given order: widths = floor + (360 - n floor) share. Returns {id: (start, width)} with
    the whole arrangement turned so that the mean circular offset between slice centres and `items`' targets is zero.
    items: ordered [(id, target angle)]."""
    n = len(items)
    total = math.fsum(weights[i] for i, _ in items)
    free = 360 - n * floor
    if free < 0:
        raise ValueError("minimum slices do not fit the circle")
    widths = {i: floor + free * weights[i] / total for i, _ in items}
    pos, centre = 0.0, {}
    for i, _ in items:
        centre[i] = pos + widths[i] / 2
        pos += widths[i]
    offs = [((t - centre[i] + 180) % 360 - 180, 1.0) for i, t in items]
    turn = _mean_angle(offs) or 0.0
    out, pos = {}, turn
    for i, _ in items:
        out[i] = (pos % 360, widths[i])
        pos += widths[i]
    return out


def evidence_pressure(rows, domains, smoothing=SMOOTHING):
    return pressure_from_evidence([r for r in rows if not r["revoked"]], domains, smoothing)


def radial_bands(cards, ring_of, log=None, by_depth=False):
    """({id: (r0, r1)}, [ids by depth]). Per ring, the composites are scaled linearly onto the ring (innermost at the
    inner edge); a card with no composite spans the whole ring and is listed."""
    radii = {"sector": SECTOR_RING, "field": FIELD_RING}
    comp = {c["id"]: None if by_depth else (c.get("radius") or {}).get("composite") for c in cards}
    out, fallback = {}, []
    for ring, (lo, hi) in radii.items():
        ids = [c["id"] for c in cards if ring_of[c["id"]] == ring]
        vals = [comp[i] for i in ids if comp[i] is not None]
        cmin, cmax = (min(vals), max(vals)) if vals else (0.0, 0.0)
        for i in ids:
            if comp[i] is None:
                out[i] = (lo, hi)
                fallback.append(i)
                continue
            t = 0.5 if cmax == cmin else (comp[i] - cmin) / (cmax - cmin)
            r0 = lo + t * (hi - lo) * (1 - BAND)
            out[i] = (r0, r0 + (hi - lo) * BAND)
    if fallback and not by_depth:
        shown = ", ".join(sorted(fallback)[:5]) + (f" and {len(fallback) - 5} more" if len(fallback) > 5 else "")
        record_degradation(f"radial_bands: {shown}", "radius_composite", "depth (whole ring)",
                           f"no radius composite on {len(fallback)} of {len(cards)} domains", log)
    return out, sorted(fallback)


def pinned_order(fields, angle, ring_order, log=None):
    """[(id, target angle)] in the pinned order. A field the pinned order does not know (added since) goes after the listed
    field nearest its axes angle, recorded loudly (`layout_order`); a pinned id that no longer exists is dropped."""
    have = set(fields)
    order = [i for i in ring_order["order"] if i in have]
    target = {i: ring_order["angles"].get(i, angle[i]) for i in fields}
    listed = set(order)
    new = sorted(i for i in fields if i not in listed)
    for i in new:
        k = min(range(len(order)), key=lambda p: (circ_diff(target[order[p]], angle[i]), p))
        order.insert(k + 1, i)
        target[i] = angle[i]
    if new:
        shown = ", ".join(new[:5]) + (f" and {len(new) - 5} more" if len(new) > 5 else "")
        record_degradation(f"pinned_order: {shown}", "layout_order", "after the nearest-axes listed field",
                           f"{len(new)} fields are not in the pinned ring order", log)
    return [(i, target[i]) for i in order]


def build(cards, axes, rows, version="0.0.0-draft", log=None, by_depth=False, fine_cards=None, ring_order=None):
    """`ring_order` ({"order", "angles"}, see `load_layout`) fixes the order of the field ring (LI.66); none: the circular
    order of the axes angles. Widths follow pressure either way, sectors always follow their axes angles."""
    by = {c["id"]: c for c in cards}
    if fine_cards:
        rows = coarsen_rows(rows, fine_cards)  # pressure is counted at the coarse fields
    angle, source, inherited = place_angles(cards, axes)
    ids = sorted(by)
    p = evidence_pressure(rows, ids)
    primary = {}
    for c in cards:
        ups = sorted(_upstream(c), key=lambda u: (-u[1], u[0]))
        primary[c["id"]] = ups[0][0] if ups and not is_sector(c) else c["id"] if is_sector(c) else None
    sector_p = {i: p[i] for i in ids if is_sector(by[i])}
    for i in ids:
        if not is_sector(by[i]):
            s = primary[i] if primary[i] in sector_p else None
            if s:
                sector_p[s] += p[i]
    sectors = sorted((i for i in ids if is_sector(by[i])), key=lambda i: (round(angle[i], 6), i))
    fields = sorted((i for i in ids if not is_sector(by[i])),
                    key=lambda i: (round(angle[i], 6), round(angle.get(primary[i], 0.0), 6), i))
    s_arcs = slice_ring([(i, angle[i]) for i in sectors], sector_p, MIN_SECTOR_SLICE)
    f_items = pinned_order(fields, angle, ring_order, log) if ring_order else [(i, angle[i]) for i in fields]
    f_arcs = slice_ring(f_items, p, MIN_FIELD_SLICE)
    bands, fallback = radial_bands(cards, {i: "sector" if is_sector(by[i]) else "field" for i in ids}, log, by_depth)
    slices = {}
    for ring, arcs, press in (("sector", s_arcs, sector_p), ("field", f_arcs, p)):
        for i, (start, wd) in arcs.items():
            slices[i] = Slice(i, ring, angle[i], start, wd, bands[i][0], bands[i][1], press[i], source[i],
                              None if i in fallback else by[i]["radius"]["composite"])
    shift = {}
    for ring in ("sector", "field"):
        d = [circ_diff(s.angle, s.axes_angle) for s in slices.values() if s.ring == ring]
        shift[ring] = {"mean": math.fsum(d) / len(d), "max": max(d)}
    bm = Basemap(version, slices, inherited, list(OPEN_NOTES), shift, {i: a["votes"] for i, a in axes.items()}, fallback)
    if fine_cards:
        bm.fine = place_fine_slices(fine_cards, slices, log, by_depth)
        bm.extent = round(max(s.r1 for s in bm.fine.values()) + EXTENT_MARGIN, 3)
    return bm


def fine_bands(fine_cards, kind_of, log=None, by_depth=False):
    """{id: (r0, r1)}: per ring (`kind_of[id]`: "field" or "sector" for the main parent's kind), the composites scaled
    linearly onto the ring, innermost at the inner edge. A card with no composite spans the whole ring (`radius_composite`);
    every fine domain uses its mechanical composite, as the judged radius covers coarse fields only (`radius_judged`)."""
    rings = {"field": FINE_RING, "sector": FINE_SECTOR_RING}
    comp = {c["id"]: None if by_depth else (c.get("radius") or {}).get("composite") for c in fine_cards}
    out, fallback = {}, []
    for kind, (lo, hi) in rings.items():
        ids = sorted(c["id"] for c in fine_cards if kind_of[c["id"]] == kind)
        vals = [comp[i] for i in ids if comp[i] is not None]
        cmin, cmax = (min(vals), max(vals)) if vals else (0.0, 0.0)
        for i in ids:
            if comp[i] is None:
                out[i] = (lo, hi)
                fallback.append(i)
                continue
            t = 0.5 if cmax == cmin else (comp[i] - cmin) / (cmax - cmin)
            r0 = lo + t * (hi - lo) * (1 - FINE_BAND)
            out[i] = (r0, r0 + (hi - lo) * FINE_BAND)
    if not by_depth:
        mech = sorted(i for i, v in comp.items() if v is not None)
        if mech:
            record_degradation(f"fine_bands: {len(mech)} fine domains", "radius_judged", "mechanical composite",
                               "the judged radius covers coarse fields only; fine domains take the mechanical composite", log)
        if fallback:
            record_degradation(f"fine_bands: {len(fallback)} fine domains", "radius_composite", "depth (whole ring)",
                               f"no radius composite on {len(fallback)} of {len(fine_cards)} fine domains", log)
    return out


def place_fine_slices(fine_cards, coarse_slices, log=None, by_depth=False):
    """{fine id: Slice}: each fine domain inside its main parent's arc (`fine.placement.place_fine`), in the ring of its
    parent's kind, radial band from its composite. Raises on a fine domain with no parent at all."""
    parent_arcs = {i: (s.start, s.start + s.width) for i, s in coarse_slices.items()}
    specs, substituted = [], []
    for c in sorted(fine_cards, key=lambda c: c["id"]):
        parents, sub = placement_parents(c)
        if sub:
            substituted.append(c["id"])
        specs.append({"id": c["id"], "parents": parents})
    if substituted:
        shown = ", ".join(substituted[:5]) + (f" and {len(substituted) - 5} more" if len(substituted) > 5 else "")
        record_degradation(f"place_fine_slices: {shown}", "fine_placement", "heaviest overlap link as parent",
                           f"{len(substituted)} fine domains have no upstream link", log)
    arcs = place_fine(parent_arcs, specs)
    parent = {f["id"]: main_parent(f) for f in specs}
    kind_of = {i: "sector" if coarse_slices[p].ring == "sector" else "field" for i, p in parent.items()}
    bands = fine_bands(fine_cards, kind_of, log, by_depth)
    by = {c["id"]: c for c in fine_cards}
    out = {}
    for i, (start, end) in sorted(arcs.items()):
        comp = (by[i].get("radius") or {}).get("composite")
        out[i] = Slice(i, "fine", ((start + end) / 2) % 360, start % 360, end - start, bands[i][0], bands[i][1], 0.0, "placement",
                       None if comp is None or by_depth else comp, parent[i])
    return out


def evidence_rows(root=ROOT):
    """Every synthetic and public row (the pressure sample)."""
    rows = read_jsonl(root / "data/synthetic/rows.jsonl") + read_jsonl(root / "data/synthetic/org_rows.jsonl")
    for p in sorted((root / "data/public").glob("*.rows.jsonl")):
        rows += read_jsonl(p)
    return rows


def build_v0(root=ROOT, by_depth=False, fine=True, log=None, layout=DEFAULT_LAYOUT):
    """The basemap of the coarse seed (v3) with, unless `fine=False`, the fine level (`data/fine/fine_v1.jsonl`) placed
    inside it; `log` takes the loud degradation records. `layout` names the coarse ring order (LI.66): the default is the
    seriation order (version `<card version>+seriation_v0`), `"axes_v0"` rebuilds the earlier basemap (the bare card version)."""
    cards = load_cards(root / "data/coarse/seed_v3.jsonl")
    fine_cards = load_fine(root / "data/fine/fine_v1.jsonl")
    bm = build(cards, axes_means(cards, root / "data/answers/axes.jsonl", [root / f"data/coarse/seed_v{v}.jsonl" for v in (0, 1, 2)],
                                 [root / "data/answers/axis_at.jsonl", root / "data/answers/axis_pg.jsonl"]),
               coarsen_rows(evidence_rows(root), fine_cards),  # pressure is counted at the coarse fields either way
               layout_version(cards[0]["basemap_version"], layout), log=log, by_depth=by_depth,
               fine_cards=fine_cards if fine else None, ring_order=load_layout(layout, root))
    return bm


def load_all_cards(root=ROOT):
    """The coarse seed cards (v3) followed by the fine cards (v1): every domain a row may name."""
    return load_cards(root / "data/coarse/seed_v3.jsonl") + load_fine(root / "data/fine/fine_v1.jsonl")
