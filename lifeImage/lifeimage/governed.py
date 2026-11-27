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
        "default": 0.15012,
        "source": "LI.39: the tone map's constant; derived by `derive_tone_k` so the median 40-year-old persona of the generated "
                  "population has its typical touched coarse field at level 0.5 (mid-brightness). Absolute across people. "
                  "Re-derived on fine evidence (LI.51: 0.16388 before, the coarse field now aggregating its fine children), and again when the fine level grew "
                  "786 -> 1503 cards (0.15862 before), and when the base fine set gained its third variant (0.15291 before), and when every coarse field gained a fine child (0.1509 before).",
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
    "membership.fit_floor": {
        "default": 4,
        "source": "LI.67: quality floor of the ranked stopping rule: a domain joins an event's membership in a relation only while its fit score "
                  "(0 no relation .. 10 the event plainly is that domain) is at least this; the first domain below it ends the list. 4 is the lowest "
                  "score the rubric calls a fair, if minor, categorisation (3 is `loosely related`, the layout_sim.judged_floor reading of 3 of 10 as "
                  "barely related). Assumption; calibrated by the membership.v3 control battery (`data/gold/membership_wide_predictions.md`), then governed.",
    },
    "membership.fit_floor.v4": {
        "default": 5,
        "source": "LI.67: quality floor of `membership.v4`, raised from 4 by the pre-registered rule after the v3 calibration battery failed "
                  "secondary precision (0.69 < 0.8) and single-domain padding (0.55 > 0.10) (`data/gold/membership_wide_predictions.md`, v3 judged). "
                  "5 is the lowest score the v4 scale calls a real secondary aspect a careful reader would accept. Assumption; calibrated by the "
                  "membership.v4 control battery, then governed. v3 answers keep `membership.fit_floor` (4).",
    },
    "blind.fit_floor": {
        "default": 4,
        "source": "LI.70: least fit (0-10) of a blind label in pass 1 of two-pass extraction. One below the membership floor of 5 (`membership.fit_floor.v4`) so "
                  "that near-floor categories are observed and reach the mapper's review; the floor of the memberships themselves is applied in pass 2. Assumption.",
    },
    "blind.max_labels": {
        "default": 6,
        "source": "LI.70: most blind labels per relation in pass 1 (a bound on the review load of pass 2, as the width of the v3 and v4 lists is bounded in practice). Assumption.",
    },
    "membership.agree_floor": {
        "default": 0.5,
        "source": "LI.67: least Jaccard agreement of two variants' domain lists in one relation for the merged list to stand without escalation "
                  "(`lifeimage/membership_wide.py` ingest); a differing primary domain always escalates. Assumption.",
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
    "layout_sim.pull_cap": {
        "default": 30.0,
        "source": "LI.55: degrees at which an attraction saturates (a Huber pull: linear inside, constant beyond), so one far link "
                  "cannot drag a field across the circle alone while several can; assumption (about the width of a sector's arc).",
    },
    "layout_sim.shift_budget": {
        "default": 300.0,
        "source": "LI.55 / LI.58: the shift (degrees from the prior angle) the median field's full attraction may cause. The angular spring is "
                  "weak by ruling (do not constrain angle too much): the prior is the stability term (LI.25) but may give way far (the budget "
                  "exceeds the shift_max guard, which bounds it in practice); a first run at 100 (k_polar 0.3) is kept in the predictions addendum; the radius, judged on its own scale, is held much harder (k_radial).",
    },
    "layout_sim.k_polar": {
        "default": 0.1,
        "source": "LI.58: stiffness of the weak angular spring to the prior angle (the axes angle, later the previous layout), relative to the median "
                  "field's total attraction (normalised to 1). Derived: pull_cap / shift_budget = 30 / 300, so a field pulled at saturation by the "
                  "median total attraction settles at the budget. This is the stability term of LI.25; the stability metrics show the drift it allows.",
    },
    "layout_sim.shift_max": {
        "default": 120.0,
        "source": "LI.58: hard limit on a field's shift from its prior angle (a third of the circle), a guard so a loose spring can never carry a "
                  "field to the opposite side; assumption.",
    },
    "layout_sim.k_repel": {
        "default": 2.0,
        "source": "LI.55: stiffness of the short-range repulsion between fields closer than the sum of their half-widths, relative to the "
                  "median field's total attraction; twice the attraction per degree so slices keep their order; assumption.",
    },
    "layout_sim.rep_floor": {
        "default": 0.4,
        "source": "LI.55: degrees added to the half-width sum of two fields as the repulsion range, so fields with no evidence (the "
                  "minimum slice) still keep a gap; about a quarter of the mean slot (360 / 247); assumption.",
    },
    "layout_sim.w_overlap": {"default": 1.0, "source": "LI.55: weight of overlap links (judged by runners, weight per link); the reference source."},
    "layout_sim.w_upstream": {"default": 1.0, "source": "LI.55: weight of field-to-field upstream links (a parent field is a close neighbour)."},
    "layout_sim.w_sector": {
        "default": 0.5,
        "source": "LI.55: weight of the pull of a field toward the circular mean of its sector (upstream links, by link weight); a sector is "
                  "broad, so its pull is half an overlap's; assumption.",
    },
    "layout_sim.w_comembership": {
        "default": 0.5,
        "source": "LI.55: weight of learnt conditional co-membership (annotations by runners, noisy, popularity-biased); half an overlap's; assumption.",
    },
    "layout_sim.w_fine": {
        "default": 0.75,
        "source": "LI.55: weight of shared fine children (fine cards linking both fields, a nearness signal from the fine level); assumption.",
    },
    "layout_sim.w_text": {
        "default": 0.5,
        "source": "LI.55: weight of textual nearness (TF-IDF cosine over label, aliases, description and fine children's labels); cheap and "
                  "partly derived from the same words the axes judges read, so half an overlap's; assumption.",
    },
    "layout_sim.w_judged": {
        "default": 0.75,
        "source": "LI.55: weight of judged pairwise relatedness (`relatedness.v1`: one runner verdict 0-10 per field pair, mean over two "
                  "variants scaled to [0,1], times their agreement); a direct judgement of the pair but cheap and a single reading, so the "
                  "weight of shared fine children, below an overlap's; assumption. Off (empty, degradation logged) until answers exist.",
    },
    "layout_sim.judged_floor": {
        "default": 0.3,
        "source": "LI.55: least judged relatedness score (0-1, a verdict of 3 of 10) that counts as signal; below it the pair is judged "
                  "unrelated or barely related, which is the absence of a pull, not a repulsion; assumption.",
    },
    "layout_sim.support_floor": {
        "default": 3,
        "source": "LI.55: least number of annotated items on which a co-membership row stands to count as signal (the file's median support is 2); assumption.",
    },
    "layout_sim.weight_cap": {
        "default": 3.0,
        "source": "LI.55: each source's weights are divided by their median over pairs with signal, then capped at this multiple, so no source's "
                  "tail dominates; assumption.",
    },
    "layout_sim.text_floor": {"default": 0.10, "source": "LI.55: least TF-IDF cosine that counts as textual signal; assumption."},
    "layout_sim.text_topk": {
        "default": 6,
        "source": "LI.55: a field keeps textual signal only to its k most similar fields (and a pair counts if either keeps it), so the dense "
                  "cosine matrix stays a nearness signal, not a haze; assumption.",
    },
    "layout_sim.inherited_stiffness": {
        "default": 0.25,
        "source": "LI.55: share of the polar stiffness a field keeps when it has no axes of its own (its angle is inherited from upstream); assumption.",
    },
    "layout_sim.seriation_lambda": {
        "default": 1.0 / 120.0,
        "source": "LI.60: price of one degree of displacement (slot angle from the axes-prior angle) in units of combined similarity in the "
                  "seriation cost -similarity + lambda x displacement. Derived from the guard, not tuned: a displacement the size of the guard "
                  "(120 degrees) costs one median-strength adjacency (normalised source similarity 1). A sweep is reported as sensitivity only.",
    },
    "layout_sim.seriation_guard": {
        "default": 120.0,
        "source": "LI.60 / LI.25 / LI.58: hard limit (degrees) on a field's displacement in the seriation order; the same value as the force "
                  "simulation's `layout_sim.shift_max` (a third of the circle), so the arms are held to one stability guard; assumption.",
    },
    "layout_sim.seriation_restarts": {
        "default": 8,
        "source": "LI.60: deterministic starts of the seriation heuristic besides the shipped order (3 greedy chains from the fields at "
                  "the first slots, the rest seeded double-bridge kicks of the best order so far); the best cost wins. Compute budget, assumption.",
    },
    "layout_sim.seriation_kick_seed": {
        "default": 60,
        "source": "LI.60: seed of the double-bridge kicks (a fixed number so the heuristic is deterministic); the value carries no meaning.",
    },
    "layout_sim.k_radial": {
        "default": 5.0,
        "source": "LI.58: stiffness of the strict radial spring to the judged radius (LI.26), relative to the median field's total attraction; "
                  "five times the weak angular spring's order of magnitude, so the radius stays at the prior.",
    },
    "layout_sim.radial_pull": {
        "default": 0.1,
        "source": "LI.55: share of the angular attraction that also acts radially (pulls linked fields to similar radii); small, as the radius "
                  "is judged on its own scale; assumption. The radial state is a diagnostic: bands in the build keep the judged radius.",
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


def membership_fit_floor(prompt_version):
    """The fit floor of a membership prompt version (LI.67): v3 keeps `membership.fit_floor`, v4 and later use `membership.fit_floor.v4`."""
    return governed("membership.fit_floor.v4") if prompt_version >= 4 else governed("membership.fit_floor")

# Event generator thresholds and noise parameters (`eventgen/governed.py`).
from .eventgen.governed import GOVERNED_EVENTGEN  # noqa: E402

GOVERNED.update(GOVERNED_EVENTGEN)
