# lifeimage-adopt-seriation (IN PROGRESS)
Goal (LI.66): the seriation order becomes the basemap's default coarse ring order, as a new basemap version; the previous
version stays reproducible (`layout="axes_v0"`); migration recorded (per-field angle old -> new, mean/p95/max shift; LI.25 guard
targets 25/60 exceeded and deferred to the clean-up, loudly); everything derived regenerated; suite green.
Acceptance: red test (default ring order != seriation order) turns green; old layout reproducible and pinned; full default-tier suite green;
tile bytes per viewport within 9-36 KB; regeneration deterministic (run twice, identical bytes).

## Prediction (before measuring), confidence 0.6
Every derived artefact regenerates deterministically; default-tier suite passes after regeneration; tile bytes per viewport stay within 9-36 KB.

## Decisions
- Layout is a build parameter (`basemap.build(..., ring_order=)`, `build_v0(layout=)`); adopted layout pinned in `data/coarse/layout_seriation_v0.json`
  (copy of seriation_v0 order + slot angles), so re-running the seriation arm cannot silently move the shipped basemap.
- Version id: `<card version>+seriation_v0` (domain ids unchanged, so the id migration table is identity); old layout keeps the bare card version.
- Seriation arm itself (context/layout_sim) keeps building on the axes layout (its base is arm A).

## Done
- Red confirmed on old code (default order != seriation; both named outliers present). Implemented: basemap.LAYOUTS/DEFAULT_LAYOUT/layout_version/load_layout/pinned_order, `build(ring_order=)`, `build_v0(layout=)`;
  lifeimage/layout_migration.py; pinned data/coarse/layout_seriation_v0.json; data/coarse/layout_migration_seriation_v0.json; tests/test_basemap_layout.py (14 green).
- New version id `0.0.0-draft+seriation_v0`; old `0.0.0-draft` = `layout="axes_v0"`.
- Shift: vs axes angle old 15.8/32.9/42.2 -> new 28.7/79.7/122.8 (mean/p95/max); old->new centre shift 29.7/78.4/146.0. Exceptions recorded: mean, p95 AND max (122.8 > guard 120, by 2.8 degrees from the pressure-width tiling).
- Regenerated (twice-identical pmtiles): images/v2 (all), review sheets (coarse_layout default = adopted; new coarse_layout_axes_v0 = earlier), interactive, tiles (pmtiles, levels, offline pages). render_v0 legacy pinned to axes_v0; render_coarse_review --axes-v0.
- Tile worst-viewport KB z0..z6: 28.8/37.9/54.4/33.6/22.1/17.7/9.0 (before 19.0/24.5/36.0/27.6/15.2/13.6/8.8): the 9-36 KB prediction part FALSE (peak 54.4), 150 KB test bound holds.
- Docs: BACKPROPAGATION LI.66 adoption note, lifeImage/README entry.
## In progress
full default-tier suite (running)
## Next
fix any suite failures, commit+push, mark DONE
## Files touched
lifeImage/lifeimage/render/basemap.py, lifeImage/lifeimage/layout_migration.py, lifeImage/tests/test_basemap_layout.py, lifeImage/data/coarse/layout_seriation_v0.json, lifeImage/data/coarse/layout_migration_seriation_v0.json
## Resume
`cd lifeImage && python3 -m pytest -q tests/test_basemap_layout.py`

Files also: lifeImage/tools/render_v0.py, lifeImage/tools/render_coarse_review.py, lifeImage/data/images/{v2,review,interactive}/*, lifeImage/data/tiles/*, lifeImage/BACKPROPAGATION.md, lifeImage/README.md
