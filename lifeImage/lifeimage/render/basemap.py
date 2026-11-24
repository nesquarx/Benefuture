"""Basemap v0: where each coarse field sits on the image (LI.22 to LI.26).

Angle (LI.24, LI.25): each field is placed once, at the angle of its axes position, the mean of the cached axes
votes (prompt versions 1 and 2; three variants each), abstract-tangible horizontal (0 deg = tangible, right) and
personal-global vertical (90 deg = global, top). A field whose mean axes are shorter than `layout.AXES_MIN` has no
direction and takes the weighted circular mean of its upstream domains (listed in `Basemap.inherited`). A sector has
no axes of its own and takes the weighted circular mean of the fields placed under it.

Slice width (LI.25): within each ring, slices keep the circular order of their axes angles and take widths in
proportion to pressure (`pressure.pressure_from_evidence` over the rows given), after a minimum slice so that a
domain with no evidence yet keeps a place. A slice's centre therefore follows its axes angle only up to the shift the
widths cause; `Slice.axes_angle` keeps the angle the axes alone gave and `Basemap.shift` reports the spread.

Radius (LI.26): depth. Sectors fill the inner ring, fields the outer. Complexity, difficulty and specificity are
outward-increasing and would spread the fields across their ring; their proxies are not available, so every field
spans the whole outer ring (see `OPEN_NOTES`).

Everything is deterministic: ties break by id, no randomness, no clock.
"""
import json
import math
from dataclasses import dataclass, field
from pathlib import Path

from ..axes import axes_input, parse_scores
from ..canonical import content_hash
from ..layout import AXES_MIN, _mean_angle, angle_from_axes, circ_diff
from ..packs import is_sector
from ..pressure import pressure_from_evidence

ROOT = Path(__file__).resolve().parent.parent.parent
CARDS = ROOT / "data/coarse/seed_v2.jsonl"
LEGACY_CARDS = (ROOT / "data/coarse/seed_v0.jsonl", ROOT / "data/coarse/seed_v1.jsonl")  # answers cached against earlier links
ANSWERS = ROOT / "data/answers/axes.jsonl"

SECTOR_RING = (0.16, 0.42)  # (r0, r1) as a fraction of the rim
FIELD_RING = (0.44, 0.96)
MIN_FIELD_SLICE = 0.25  # governed: degrees, the least a field keeps however little evidence it has
MIN_SECTOR_SLICE = 2.0  # governed: degrees
SMOOTHING = 1.0  # governed: additive pressure smoothing (`pressure.py`)

OPEN_NOTES = [
    "[OPEN] Radius within the field ring: complexity and difficulty proxies are not yet available (LI.26), so every "
    "field spans the whole outer ring and radius carries depth only (sectors inner, fields outer). Specificity "
    "beyond depth, such as the number of upstream links or novelty (L159), is not yet used.",
    "[OPEN] Pressure here is the share of the synthetic persona, organisation and public-figure rows, a tiny and "
    "unrepresentative sample; real pressure is the smoothed share of recent works, postings and evidence rows (LI.25).",
    "[OPEN] Slice order is the circular order of axes angles. Axes scores are integers averaged over six votes, so "
    "many fields share an angle; ties break by their primary sector's angle, then id.",
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


def read_jsonl(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def load_cards(path=CARDS):
    return read_jsonl(path)


def axes_means(cards, answers_path=ANSWERS, legacy=LEGACY_CARDS):
    """{field id: {abstract_tangible, personal_global, votes}}, scores averaged over every cached vote and scaled to
    [-1, 1]. Votes are matched to fields by the hash of the axes input; answers cached against earlier card sets
    (`legacy`) are matched through those sets. Fields with no vote are absent."""
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
    return {i: {"abstract_tangible": math.fsum(s[0] for s in v) / len(v) / 2,
                "personal_global": math.fsum(s[1] for s in v) / len(v) / 2, "votes": len(v)}
            for i, v in sorted(acc.items())}


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


def build(cards, axes, rows, version="0.0.0-draft"):
    by = {c["id"]: c for c in cards}
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
    f_arcs = slice_ring([(i, angle[i]) for i in fields], p, MIN_FIELD_SLICE)
    slices = {}
    for ring, arcs, radii, press in (("sector", s_arcs, SECTOR_RING, sector_p), ("field", f_arcs, FIELD_RING, p)):
        for i, (start, wd) in arcs.items():
            slices[i] = Slice(i, ring, angle[i], start, wd, radii[0], radii[1], press[i], source[i])
    shift = {}
    for ring in ("sector", "field"):
        d = [circ_diff(s.angle, s.axes_angle) for s in slices.values() if s.ring == ring]
        shift[ring] = {"mean": math.fsum(d) / len(d), "max": max(d)}
    return Basemap(version, slices, inherited, list(OPEN_NOTES), shift, {i: a["votes"] for i, a in axes.items()})


def evidence_rows(root=ROOT):
    """Every synthetic and public row (the pressure sample)."""
    rows = read_jsonl(root / "data/synthetic/rows.jsonl") + read_jsonl(root / "data/synthetic/org_rows.jsonl")
    for p in sorted((root / "data/public").glob("*.rows.jsonl")):
        rows += read_jsonl(p)
    return rows


def build_v0(root=ROOT):
    cards = load_cards(root / "data/coarse/seed_v2.jsonl")
    bm = build(cards, axes_means(cards, root / "data/answers/axes.jsonl", [root / "data/coarse/seed_v0.jsonl", root / "data/coarse/seed_v1.jsonl"]),
               evidence_rows(root), cards[0]["basemap_version"])
    return bm
