# lifeimage-fine-regen (DONE)
Goal: six tests red after fine level grew 786 -> 1503 cards. Regenerate derived artefacts only; (b) cases reported, not loosened.
Acceptance: `cd lifeImage && python3 -m pytest -q` green or remaining reds explained with measured values.

## Per test
- test_levels tone_k: (a) re-derived: `governed.derive_tone_k()` = 0.15291 (stored 0.15862); governed.py default + source note updated (same procedure as the LI.51 re-derivation).
- test_generators_starter, test_texts_v2: (a) `python3 tools/gen_starter.py` then `python3 tools/gen_texts_v2.py`.
- test_fine_rows tiling: test hard-coded 786 placed domains; arcs tile fine. Count now `len(fine_cards())` (and unique). Not a threshold.
- test_fine_rows fair share: (b) share = 911/911 event rows name a fine domain (>= 0.45 holds); the clause `coarse_only` non-empty fails because the 9 fields still without fine child are not used by the templates. Left red.
- test_layout_sim real result: (b) after-mean_similarity 0.2757 (test run 0.2718) vs before 0.3007 (was 0.3231 vs 0.2940 on 125 fine pairs; now 221 fine pairs, no_signal_share after 0.781 vs before 0.733). Left red; artefact regenerated (`python3 tools/layout_sim.py --no-batches`).
- Knock-on (a): tests/test_characterise contact sheet: regenerated `python3 tools/render_v0.py --out data/images/v2` and `python3 tools/render_v0.py --legacy` (data/images/v0).
- Knock-on (b?): tests/test_tiles hover_labels [online/offline]: green-toggle pixel at fly-to centre reads the same before/after (255,216,74 = the selection outline colour #ffd84a) once data/synthetic is regenerated (slice width 7.881 -> 7.846 deg via pressure); passes with the old synthetic rows. Sampling-point fragility vs geometry shift; left red, not loosened.
build_radius.py reran: fine_v1 unchanged.

Final suite: 4 failed, 1179 passed, 1 xfailed.
Resume: `cd lifeImage && python3 -m pytest -q --no-header 2>&1 | tail`
