"""The predicted/measured image (LI.34): red potential, green expertise, blue impact, additive on black.

Channels (LI.32, LI.33). Expertise follows what was done and engaged with (membership rels form and content), impact
follows what changed (rel outcome), potential is predicted expertise and impact (self-assessment rows, channel
`prediction`, all their rels). Setting memberships colour nothing. A row's channel weight is split evenly over the
rels it has in that channel, so a row counts once per channel however many rels it carries. Negative rows and
revoked rows wait for the reputation image (LI.35).

Folding is `projection.project` (caps by relation, a little bleed one step to upstream domains, none to overlap
neighbours). Before folding, each row is dimmed by a half-life: factor 0.5 ** (age / half_life), age measured from
`asof`, by default the entity's latest `valid_time`, so a historical figure's career is not dimmed to nothing.

Layers. Colour is kept in two layers: `solid` (every row but predictions) and `claimed` (claimed potential: predictions
only, red). The claimed layer is drawn as grain; the solid layer is drawn with the saturation of its tiers (LI.38: a
self-report is pale, a record full). In the legacy projection the claimed layer is the claimed tier, desaturated.

Intensity is magnitude on a log scale, the same fixed scale for every entity so images stay comparable; colour never
exceeds the value its domain's rows carry. Wedges of different domains never overlap, so additive colour is
precomputed per wedge (within a domain channels add as RGB); the grain overlay uses `mix-blend-mode: screen`.

Deterministic: sorted iteration, rounded coordinates, no clock.
"""
import json
import math
from dataclasses import dataclass, field
from datetime import date
from html import escape
from pathlib import Path

from .. import levels as lv
from ..fine.cards import coarsen_rows
from ..projection import DEFAULT as PROJECTION
from ..projection import project
from .basemap import EXTENT_MARGIN, ROOT, read_jsonl

CHANNELS = ("red", "green", "blue")
# (source row channel, membership rels) per image channel
CHANNEL_SOURCE = {"red": ("prediction", ("form", "content", "outcome")),
                  "green": ("positive", ("form", "content")),
                  "blue": ("positive", ("outcome",))}
ALL_RELS = frozenset(r for _, rels in CHANNEL_SOURCE.values() for r in rels)


@dataclass(frozen=True)
class Governed:
    """Governed values of the image (defaults; each is a threshold to be governed later)."""
    half_life_years: float = 15.0  # a row's weight halves every this many years
    v0: float = 0.02  # log scale knee: values well below it stay dark
    v_ref: float = 2.0  # the per-domain channel value shown at full intensity
    claimed_saturation: float = 0.5  # share of colour kept (rest goes to grey) for the claimed layer
    grain_dot: float = 0.006  # grain dot size and tile (fractions of the rim radius)
    grain_tile: float = 0.014
    projection: object = PROJECTION
    levels: object = lv.DEFAULT  # LI.36 levels and the LI.37 channel split (`lifeimage/levels.py`)


DEFAULT = Governed()


def intensity(v, g=DEFAULT):
    if v <= 0:
        return 0.0
    return min(1.0, math.log1p(v / g.v0) / math.log1p(g.v_ref / g.v0))


def rgb(ch, g=DEFAULT, claimed=False, levels=False):
    """(r, g, b) ints from channel values (legacy: log intensity) or levels in [0, 1] (`levels=True`: used as they are, kept to
    the slice's `saturation` of their chroma when it has one); legacy claimed colours keep `claimed_saturation`."""
    c = [min(1.0, max(0.0, ch.get(k, 0.0))) if levels else intensity(ch.get(k, 0.0), g) for k in CHANNELS]
    sat = ch.get("saturation", 1.0) if levels else (g.claimed_saturation if claimed else 1.0)
    if sat != 1.0:
        grey = math.fsum(c) / 3
        c = [grey + sat * (x - grey) for x in c]
    return tuple(int(round(255 * x)) for x in c)


parse_time = lv.parse_time
_years = lv.years_between


def channel_values(rows, cards, governed=DEFAULT, asof=None, legacy=False):
    """{"solid": {domain: {red, green, blue}}, "claimed": {...}} for one entity's rows: levels in [0, 1] (LI.36, LI.37), or
    with `legacy=True` the earlier projection (summed magnitudes, to be drawn on the log scale)."""
    if not legacy:
        return lv.channel_levels(rows, cards, governed.levels, asof)
    known = {c["id"] for c in cards}
    fine = [c for c in cards if c.get("level") == "fine"]
    if fine:  # the earlier projection knows coarse fields only: rows are read at the coarse level (fine.cards.coarsen_rows)
        rows = coarsen_rows(rows, fine)
    live = [r for r in rows if not r["revoked"] and r["channel"] in ("positive", "prediction")]
    for r in live:
        for m in r["memberships"]:
            if m["domain"] not in known:
                raise ValueError(f"unknown domain {m['domain']}")
    ref = parse_time(asof) if asof else max((parse_time(r["valid_time"]) for r in live), default=None)
    derived = {"solid": [], "claimed": []}
    for r in live:
        age = max(0.0, _years(ref, parse_time(r["valid_time"])))
        dim = 0.5 ** (age / governed.half_life_years)
        for channel, (source, rels) in CHANNEL_SOURCE.items():
            if r["channel"] != source:
                continue
            ms = [m for m in r["memberships"] if m["rel"] in rels]
            n = len({m["rel"] for m in ms})
            if not ms:
                continue
            derived["claimed" if r["tier"] == "claimed" else "solid"].append(
                {**r, "channel": channel, "magnitude": r["magnitude"] * dim,
                 "memberships": [{**m, "weight": m["weight"] / n} for m in ms]})
    out = {}
    for layer, rs in derived.items():
        out[layer] = {}
        for _entity, per_domain in sorted(project(rs, cards, governed.projection, ALL_RELS).items()):
            for d, ch in per_domain.items():
                row = out[layer].setdefault(d, dict.fromkeys(CHANNELS, 0.0))
                for k in CHANNELS:
                    row[k] += max(0.0, ch.get(k, 0.0))
    return out


def totals(cv):
    return {k: math.fsum(ch[k] for layer in cv.values() for ch in layer.values()) for k in CHANNELS}


# ---------- entities ----------

def load_entities(root=ROOT):
    """Personas, organisations and public figures with their rows: [{id, label, kind, archetype, calibration, rows}]."""
    out = []
    syn = root / "data/synthetic"
    rows = read_jsonl(syn / "rows.jsonl") + read_jsonl(syn / "org_rows.jsonl")
    by = {}
    for r in rows:
        by.setdefault(r["entity"], []).append(r)
    for p in read_jsonl(syn / "personas.jsonl"):
        out.append({"id": p["id"], "label": p["id"], "kind": "person", "archetype": p["archetype"],
                    "calibration": p["calibration"], "rows": by.get(p["entity"], [])})
    for o in read_jsonl(syn / "orgs.jsonl"):
        has_pred = any(r["channel"] == "prediction" for r in by.get(o["entity"], []))
        out.append({"id": o["id"], "label": o["name"], "kind": "organisation", "archetype": o["org_kind"],
                    "calibration": "recorded" if has_pred else "none recorded", "rows": by.get(o["entity"], [])})
    for meta in sorted((root / "data/public").glob("*.json")):
        m = json.loads(meta.read_text(encoding="utf-8"))
        slug = meta.stem
        out.append({"id": slug, "label": m["label"], "kind": "public", "archetype": m.get("shape", "").split(":")[0] or "public figure",
                    "calibration": "none recorded", "rows": read_jsonl(root / f"data/public/{slug}.rows.jsonl")})
    return out


# ---------- svg ----------

def _pt(r, a):
    x, y = r * math.cos(math.radians(a)), -r * math.sin(math.radians(a))
    return f"{x:.3f} {y:.3f}"


def wedge_path(s):
    a0, a1 = s.start, s.start + s.width
    big = 1 if s.width > 180 else 0
    return (f"M{_pt(s.r1, a0)}A{s.r1} {s.r1} 0 {big} 0 {_pt(s.r1, a1)}L{_pt(s.r0, a1)}"
            f"A{s.r0} {s.r0} 0 {big} 1 {_pt(s.r0, a0)}Z")


def hexcolour(c):
    return "#%02x%02x%02x" % c


def flange(version, rim=1.0):
    """Orientation marker at angle 0 (tangible, right): a triangle outside the rim pointing in, and the basemap version."""
    return (f'<g id="flange"><path d="M{rim + 0.1:.3f} -0.035L{rim + 0.1:.3f} 0.035L{rim + 0.015:.3f} 0Z" fill="#9a9a9a"/>'
            f'<text x="{rim + 0.12:.3f}" y="0.012" font-size="0.03" fill="#9a9a9a" font-family="sans-serif">v{escape(version)}</text></g>')


def render_svg(label, cv, bm, governed=DEFAULT, size=640, legacy=False):
    """The image as SVG. Coarse slices (sector and field rings) and, where the basemap has them, the fine slices in their
    outer rings (LI.51); the drawing is as wide as the outermost ring needs (`bm.extent`)."""
    g = governed
    fine = getattr(bm, "fine", {}) or {}
    e = getattr(bm, "extent", 1.25) if fine else 1.25
    order = sorted(bm.slices.values(), key=lambda s: (s.ring != "sector", s.id)) + sorted(fine.values(), key=lambda s: s.id)
    outline = "".join(wedge_path(s) for s in order)
    solid, claimed = [], []
    for s in order:
        for layer, bucket, flag in (("solid", solid, False), ("claimed", claimed, True)):
            ch = cv.get(layer, {}).get(s.id)
            if ch and any(ch[k] > 0 for k in CHANNELS):
                bucket.append(f'<path d="{wedge_path(s)}" fill="{hexcolour(rgb(ch, g, flag and legacy, levels=not legacy))}"><title>{escape(s.id)}</title></path>')
    t = g.grain_tile
    defs = claimed_g = ""
    if claimed:  # the grain mask exists only where there is something claimed to draw
        m = e - 0.15
        defs = ("<defs>"
                f'<pattern id="dots" width="{t}" height="{t}" patternUnits="userSpaceOnUse"><rect width="{t}" height="{t}" fill="#000"/>'
                f'<rect width="{g.grain_dot}" height="{g.grain_dot}" fill="#fff"/></pattern>'
                f'<mask id="grain" maskUnits="userSpaceOnUse" x="-{m:g}" y="-{m:g}" width="{2 * m:g}" height="{2 * m:g}">'
                f'<rect x="-{m:g}" y="-{m:g}" width="{2 * m:g}" height="{2 * m:g}" fill="url(#dots)"/></mask></defs>')
        claimed_g = f'<g id="claimed" mask="url(#grain)" style="mix-blend-mode:screen">{"".join(claimed)}</g>'
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-{e:g} -{e:g} {2 * e:g} {2 * e:g}" width="{size}" height="{size}">',
        f"<title>{escape(label)}</title>",
        defs,
        f'<rect x="-{e:g}" y="-{e:g}" width="{2 * e:g}" height="{2 * e:g}" fill="#000"/>',
        f'<path id="guides" d="{outline}" fill="none" stroke="#1c1c1c" stroke-width="0.002"/>',
        f'<g id="wedges">{"".join(solid)}</g>',
        claimed_g,
        '<g id="notches"></g>',
        flange(bm.version, rim=e - EXTENT_MARGIN),
        "</svg>",
    ]
    return "\n".join(parts) + "\n"
