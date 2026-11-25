# Layout simulation: pre-registered predictions (LI.55, LI.58)

Written before measuring the simulation on the coarse map, except for the disclosure below. Settings: governed defaults of
`layout_sim.*` in `lifeimage/governed.py` at the commit of this file. Layout A is the axes placement (`basemap.build`); layout B
is the simulation's angles tiled by `basemap.build`. Adjacent means circularly consecutive in the field ring.

## Disclosure (first look)

A test fixture ran the simulation on the real data once before this file existed, with the first stiffness set S1
(`k_polar` 0.3, `shift_budget` 100, `shift_max` 120). It showed mean combined similarity of adjacent pairs 0.180 after against
0.188 before, no-signal share 0.874 against 0.834, mean tiled shift 23.1 against 17.4 degrees, sectors split 16 and 16, extra
runs 184 against 166. M1 and M4 below were therefore written knowing S1 does not meet M1. An exploratory sweep (unit widths,
raw angle order as baseline 0.142) gave 0.184 at `k_polar` 0.3, 0.248 at 0.1, 0.180 at 0.03: the relaxation is a noisy
optimiser of the order. S2 (`k_polar` 0.1, `shift_budget` 300, otherwise S1) is the new governed default; both are reported.

## Metrics, direction, threshold (S2 default; S1 reported alongside, not held to M1)

1. Neighbour coherence (circular: the simulation optimises it, a sanity check only).
   a. Mean combined similarity of adjacent pairs: after >= 1.25 x before. Confidence 0.5.
   b. Share of adjacent pairs with no signal: after <= 0.9 x before. Confidence 0.5.
   c. Mean circular rank distance of pairs with signal: falls by >= 10%. Confidence 0.6.
   d. Hold-out (not optimised for the held-out source): rerun with a source's weight zero; its own similarity over adjacent pairs
      after >= 1.1 x before for at least 3 of the 5 sources. Confidence 0.5.
2. Independent check (blinded runner judging, `adjacency.v1`, run by the lead): the simulation's neighbours are judged closer in
   at least 55% of decisive judgements (set 1 versus set 2 mapped back through the key), with decisive judgements at least 40%
   of tasks and the sign test z >= 2 (z = 3 for any claim entering the README). Confidence 0.45.
3. Named outliers (arts, religion, mathematics, statistics, housing, agriculture fields): for at least 4 of the 6 groups the mean
   combined similarity of a field to its two neighbours rises; no arts or religion field is adjacent to mathematics or statistics
   after. Confidence 0.5.
4. Stability (LI.25): mean tiled-centre shift from the axes angle <= 25 degrees, 95th percentile <= 60, maximum <= 120 (the guard);
   sectors with split runs after <= before; extra runs after <= before. Confidence 0.5 (S1 failed the last on its first look).
   The loose angular spring is expected to let angles drift further than the old axes-only placement: that drift is reported, not hidden.

Runtime: `compute` without the hold-out reruns finishes within 30 s. Confidence 0.9.

## Results (2026-11-25, S2 default; S1 in brackets; seeds: none, the run is deterministic)

1a mean adjacent similarity 0.188 to 0.242 (x1.29, met) [0.180, not met]. 1b no-signal share 0.834 to 0.822 (x0.985, not met)
[0.874]. 1c mean rank distance of signal pairs 36.1 to 29.5 (-18%, met) [30.8, -15%, met]. 1d hold-out (baseline there is the
raw-angle order, not the build's tie-broken order): upstream and co-membership rose, overlap, fine (unchanged) and text fell:
2 of 5, not met. 2 not yet judged (batches `data/batches/adjacency.v1.*`, key beside them). 3 groups rising: agriculture (work and
science) no, arts yes in aggregate [S1: yes], housing flat at zero, mathematics and statistics lost their strong mutual
adjacency (1.68 to 0 and 0.33), religion fell: not met on the metric, though the named outliers moved to better
neighbours by eye (Arts, music and religion studies left Statistics for Philosophical inquiry; Finding and securing housing left
Crop farming for Hospitality and Commuting). 4 tiled mean shift 27.9, p95 71.4, max 133.8 (not met; S1: 23.1, 54.5, 89.3);
sectors split 16 and 16 (met), extra runs 166 to 174 (not met; S1 184). Runtime 5.5 s with the hold-out (met).

## Prediction 2 judged (lead, 2026-11-25)
Blinded `adjacency.v1`, Haiku runners, 247 fields x 2 variants (key held out of the runners' reach): variant 0, B (simulation)
108 vs A (axes) 91, 48 ties, share B 0.543, z 1.21; variant 1, 111 vs 92, 44 ties, share 0.547, z 1.33; pooled 219 vs 183,
share 0.545, z 1.80 (the variants agree on 82% of fields, so pooling overstates n; the per-variant z is the honest figure).
Decisive 81% of tasks (>= 40%: met). Position bias 0.46 / 0.51 (none to speak of). Prediction (>= 55%, z >= 2): **not met**.
Direction favours the simulation, magnitude small and not significant: the simulated layout is at best slightly better to an
independent judge, consistent with signal coverage of 3.7% of field pairs. Not adopted; rerun after the signals grow.
