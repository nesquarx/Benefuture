# lifeimage-red-diag (DONE)
Goal: diagnose three reds after fine level 786 -> 1503 cards. No loosening, no skips.

## 1. test_layout_sim real_result_improves_signal_adjacency: NO BUG, left red
Measured (data/coarse/layout_sim_v0.json, 247 fields, combined similarity, same matrix for before and after):
- (i) before = default build's order (0.3007); after = build on the relaxed angles (0.2757). Same matrix, but the conventions differ in the
  tie-break: the axes prior has only 127 distinct angles for 247 fields (178 fields in ties, up to 12 tied); the default build breaks ties by
  the primary parent's angle, then id. Raw prior order with id tie-break scores 0.2212; the build's tie-break is worth +0.079. After the
  relaxation all 247 angles are distinct, so no tie-break applies. Against the same id convention the relaxation improves 0.2212 -> 0.2757.
- (iii) tiling does not undo the relaxed order: raw relaxed angle order, order by tiled slice centre and tiled start order all give 0.27566.
- (ii) no dominance: each source is divided by its median and capped; fine mean 1.24, median 1.0, 221 pairs (0.7% of pairs), weight 0.75.
- The simulation does what it optimises: weighted attraction (Huber) energy 1.375e6 -> 0.940e6, weighted mean angular distance of attracted
  pairs 40.8 -> 30.8 degrees. The rank-adjacency metric is a different, coarser objective: relaxing with a source removed and scoring
  against the full signal gives higher adjacency (without text 0.380, judged 0.369, upstream 0.328, fine 0.323), so more sources pulling
  mean more compromise, not better neighbours.
- (iv) per source adjacency before -> after: overlap .112 -> .082, text .095 -> .076, comembership .028 -> .020, judged .141 -> .137,
  fine .024 -> .057 (up), upstream .003 -> 0.
Conclusion: convention (tie-break inherited by the default order) plus objective mismatch, not a bug. Any fix would be changing the dynamics or
the metric to pass the test (speculative); left red. Candidate for lead ruling: compare after against the prior under the same tie-break, or
add adjacency-aware ordering within near ties.

## 2. test_tiles hover_labels (online, offline): test fragility, fixed
The toggle works (fill 70,219,220 -> 35,35,185 at neighbouring pixels). The slice is only ~6 px wide at the fly-to zoom and its geometric centre
lies on a vertical selection outline. tests/js/map_check.cjs now samples the nearest pixel to the centre that is not outline colour (selection
yellow or white hover), the same point before and after; assertion unchanged. tests/test_tiles.py: 51 passed.

## Files touched
tests/js/map_check.cjs, progress/lifeimage-red-diag.md
Resume: `cd lifeImage && python3 -m pytest -q --no-header 2>&1 | tail`

Final suite: 1 failed (layout_sim adjacency, item 1), 1182 passed, 1 xfailed.
