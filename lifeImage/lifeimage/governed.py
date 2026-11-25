"""Governed values: every default or threshold a rule falls back on, in one place, each with its source.

A value here is a threshold to be governed later; rules read it by name through `governed`.
"""

GOVERNED = {
    "responsibility.no_option_set": {
        "default": 0.5,
        "source": "LI.40 / LI.42: option set missing; neither full freedom nor coercion is assumed (midpoint).",
    },
    "responsibility.floor": {
        "default": 0.1,
        "source": "LI.40: responsibility when no less harmful alternative was open; coercion lowers it, never to 0.",
    },
    "levels.tone_k": {
        "default": 0.15862,
        "source": "LI.39: the tone map's constant; derived by `derive_tone_k` so the median 40-year-old persona of the generated "
                  "population has its typical touched coarse field at level 0.5 (mid-brightness). Absolute across people. "
                  "Re-derived on fine evidence (LI.51: 0.16388 before, the coarse field now aggregating its fine children).",
    },
    "levels.saturation_measured": {
        "default": 1.0,
        "source": "LI.38: share of colour kept when every row behind a slice is a log or output (full).",
    },
    "levels.saturation_attested": {
        "default": 0.85,
        "source": "LI.38: share kept when a third party attests; assumption, slightly under a measurement.",
    },
    "levels.saturation_claimed": {
        "default": 0.5,
        "source": "LI.38: share kept when the person reports it themselves (pale); the earlier claimed-layer saturation.",
    },
    "tiles.min_slice_px": {
        "default": 1.0,
        "source": "LI.52: a tile at zoom z ships a slice only when both its on-screen arc width (at mid radius) and its radial depth "
                  "are at least this many pixels at that zoom's resolution (256 px tiles). One pixel is the least a pixel grid can "
                  "show as its own colour; a narrower slice is drawn as its parent, whose level aggregates it (LI.51). Assumption; "
                  "Nyquist (2 px) would halve the detail shipped.",
    },
    "tiles.arc_tolerance_px": {
        "default": 0.25,
        "source": "LI.52: the most an arc's polygon may stray from the true circle, in pixels at the tile's zoom; sets vertex density "
                  "(no wasted vertices at low zoom). Assumption: a quarter pixel is invisible.",
    },
    "radius.band": {
        "default": 0.2,
        "source": "LI.26: a domain's radial band as a share of its ring's span (`render/basemap.py` BAND); assumption.",
    },
    "radius.sector_cap": {
        "default": 0.4,
        "source": "LI.26: the composite a sector's top rank reaches before fields lift outward (`radius.py` SECTOR_CAP); assumption.",
    },
    "radius.step_floor": {
        "default": 0.1,
        "source": "LI.26: the least share of the remaining radius a child moves outward of its parent (`radius.py` STEP_FLOOR); "
                  "keeps a child strictly outside its parent; assumption.",
    },
    "radius.step_span": {
        "default": 0.8,
        "source": "LI.26: the share of the remaining radius a child's own rank spans (`radius.py` STEP_SPAN); floor + span < 1; assumption.",
    },
    "radius.prerequisite_margin": {
        "default": 0.1,
        "source": "LI.26: inclusion asymmetry p(b|a) - p(a|b) that gives a co-membership direction (`radius.py` PREREQ_MARGIN); assumption.",
    },
}

# The reference pool of LI.39: generalist personas aged 40 on the generated population's calibration mix, fixed seeds,
# evidence as of the date below. The constant is derived on these seeds; tests check it on others.
REFERENCE_SEEDS = tuple(range(6000, 6040))
REFERENCE_AGE = 40
REFERENCE_AS_OF = "2026-11-24"
REFERENCE_LEVEL = 0.5


def derive_tone_k(seeds=REFERENCE_SEEDS):
    """The tone constant that puts the reference life's typical touched domain at `REFERENCE_LEVEL`.

    Per persona, the typical touched domain is the median, over the coarse fields a solid imprint names directly or through a
    fine child (LI.51), of the strongest channel's summed luminosity (the field's aggregate); the reference life is the median persona of that figure. Level = 1 - exp(-S / k),
    so k = S / -ln(1 - REFERENCE_LEVEL). Reads the untoned sums, so it does not depend on the constant it sets."""
    import math
    from statistics import median
    from .generators import life
    from .render import basemap as bmod
    cards = bmod.load_all_cards()
    typical = []
    for sd in seeds:
        p = life.generate_persona(seed=sd, archetype="generalist", age=REFERENCE_AGE, as_of=REFERENCE_AS_OF, pid=f"ref{sd}")
        from . import levels as lv
        raw = lv.raw_sums(p.rows, cards, lv.DEFAULT, REFERENCE_AS_OF)["solid"]
        direct = lv.touched_coarse(p.rows, cards, lv.DEFAULT, REFERENCE_AS_OF)
        vals = [max(raw[d].values()) for d in direct if d in raw]
        if vals:
            typical.append(median(vals))
    return median(typical) / -math.log(1.0 - REFERENCE_LEVEL)


def governed(name):
    """The governed default of `name`; unknown names raise KeyError."""
    return GOVERNED[name]["default"]
