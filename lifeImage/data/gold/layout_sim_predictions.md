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
