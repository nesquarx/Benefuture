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

## Prediction 3 relatedness (2026-11-25, stated before any relatedness answer exists)
`relatedness.v1` (prompts/relatedness.v1.md, tools/relatedness.py, lifeimage/relatedness.py): 2,268 pairs (828 adjacent within two
positions in either layout with no signal, 1,140 within five, 150 controls with strong signal, 150 random pairs at least a quarter
of the ring apart in both layouts), two variants (canonical and reversed order), 92 batch files of at most 50 in `data/batches/`.
Baseline on the current code: signal covers 11.9% of pairs within two positions in the axes order and 14.8% in the simulated order.
- Controls with signal score at least 3 points above random far-apart pairs on average (0-10 scale). Confidence 0.8. Not yet measured.
- Order bias (reversed minus canonical) within one point on average, variants within one point on at least 70% of pairs. Confidence 0.6.
- With the judged source on (weight 0.75, floor 0.3) the adjacent-pair coverage rises above 60% and the blinded adjacency
  judgement favours the simulation by at least 55% (z >= 2) on a rerun. Confidence 0.4 (the earlier effect was small).

## Rerun with the judged source, prediction judged (lead, 2026-11-25)
relatedness.v1: 4,536 answers; calibration gap 3.97 (predicted >= 3: met); order bias -0.02, 95% within 1 point (met).
Judged pairs above the floor: 345 of 2,268 (most nearby pairs score low: the neighbours are often unrelated, not just
unsignalled). Rerun: adjacent no-signal share 0.733 -> 0.721 (coverage > 60% predicted: not met). Blinded adjacency (axes A
vs rerun B): variant 0, 113 vs 91, share 0.554, z 1.54; variant 1, 103 vs 91, share 0.531, z 0.86; pooled 0.543, z 1.70.
Prediction (>= 55%, z >= 2): **not met**, again. Two runs agree: the simulation is a small, consistent, non-significant
improvement to an independent judge. The relaxation with a loose angular prior does not fix adjacency enough to be seen.

## After the fine level grew (lead, 2026-11-25, 1503 fine cards)
Rerun on the new data: mean adjacent combined similarity 0.301 (shipped order) -> 0.276 (relaxed), no-signal share 0.733 ->
0.781; mean rank distance of signal pairs 32.9 -> 27.1 (still falls). No bug (progress/lifeimage-red-diag.md): the shipped
build orders the axes prior's 178 tied fields by their parent's angle, worth +0.079 over an id tie-break; the relaxation
beats the id-tie-broken prior (0.221 -> 0.276) and lowers its own energy (1.375e6 -> 0.940e6) but not the shipped order.
Removing any one source gives higher full-signal adjacency (0.32-0.38): more sources pulling locally means more compromise.
The claim "the simulation improves adjacency over the shipped layout" no longer holds; the test now asserts only what holds
(signal pairs closer in rank). Reading: a cheap global ordering heuristic beat the local relaxation, which favours a global
ordering arm (circular seriation) over further force tuning.

## Seriation arm (LI.60; written before the seriation was run on the data)
Arm C: the circular order of the 247 coarse fields found by a heuristic for the Hamiltonian cycle that minimises
cost = -(combined similarity of circularly adjacent fields) + lambda x (angular displacement of each field's slot from its axes-prior
angle), summed over the ring (`lifeimage/seriation.py`). Slots are the shipped order's tiled slice centres (a field at ring position p
takes slot p's angle); the displacement guard is `layout_sim.shift_max` (LI.25/LI.58, 120 degrees); `seriation.lambda` is 1/120 per
degree (a displacement the size of the guard costs one median-strength adjacency; derived from the guard, not tuned, see
`governed.py`); sectors may split no more than the shipped order (16). Heuristic: the shipped order and `seriation.restarts`
deterministic starts (greedy chain, seeded kicks), each improved by 2-opt, Or-opt (segments of 1-3) and slot rotations, best kept;
no randomness beyond the fixed seeds. The order enters `basemap.build` as unit axes vectors like `tiled_slices`, so widths and radii
are unchanged. A = shipped order (axes placement tiled), B = force simulation (current governed defaults, tiled), both
recomputed on the same signals as C. All similarities use the same combined matrix.

Named groups (explicit ids): arts and religion = `c.arts_humanities_studies`, `c.visual_arts`, `c.performing_arts`,
`c.religion_worship`, `c.religious_community`; mathematics and statistics = `c.mathematics`, `c.statistics_data`; agriculture =
`c.horticulture_farming`, `c.agricultural_science`, `c.agri_forestry_fishing_work`, `c.fishing_hunting_foraging`; housing =
`c.housing_search`. Outlier present = an arts/religion field circularly adjacent to a mathematics/statistics field; housing with an
agriculture field as a neighbour (stricter than "between two").

Baseline on the current code (the red test): in A, `c.arts_humanities_studies` is adjacent to `c.statistics_data` and
`c.housing_search` is adjacent to `c.horticulture_farming`.

Predictions (lead, confidence 0.6 unless stated; C against A, and against B where stated):
1. Mean adjacent combined similarity of C >= 1.2 x A. C also >= B (confidence 0.7: B is below A on current data).
2. No-signal share of C <= 0.9 x A.
3. Mean circular rank distance of signal pairs of C below A (confidence 0.7; an optimiser of adjacency tends to pull signal pairs together, but a ring order only controls adjacency).
4. Named outliers: no arts/religion field adjacent to mathematics/statistics in C; no agriculture field beside housing in C.
5. Stability: mean tiled shift from the axes angle <= 25 degrees (guard max <= 120 by construction; p95 <= 60, confidence 0.5); sectors split <= 16 (enforced by construction); extra runs <= A's (confidence 0.4, not enforced).
6. Blinded adjacency (run later by the lead, A vs C, two variants): C preferred in >= 58% of decisive judgements with z >= 2 in each variant. Confidence 0.5.
Counterexample cases (tests): lambda very large returns the shipped/prior order; lambda 0 is free, displacement unbounded except by the guard.
Sensitivity (reported, not used to retune the headline): lambda x {0, 0.25, 4, 1000}.

### Seriation arm: results (2026-11-26, governed defaults; deterministic, no seeds; `data/coarse/seriation_v0.json`, `tools/seriation.py`)
Runtime about 20 s per arm (pure Python, 9 starts: shipped, 3 greedy, 5 kicks; best from a kick). Same signals for A, B and C.

| arm | mean adjacent similarity | no-signal share | mean rank distance (signal pairs) | tiled shift mean / p95 / max | sectors split | extra runs |
|---|---|---|---|---|---|---|
| A shipped | 0.337 | 0.729 | 33.0 | 15.8 / 32.9 / 42.2 | 16 | 166 |
| B force sim | 0.352 | 0.777 | 27.3 | 24.4 / 61.3 / 105.2 | 16 | 185 |
| C seriation | 2.243 | 0.093 | 34.1 | 28.7 / 79.7 / 122.8 | 16 | 97 |

Verdicts: 1 mean similarity C = 6.7 x A (>= 1.2: met), C > B (met). 2 no-signal share C = 0.13 x A (<= 0.9: met). 3 mean rank
distance of signal pairs C 34.1 against A 33.0: **not met** (a ring order controls adjacency only; the pairs it pulls together
leave other signal pairs where they were or farther). 4 named outliers: both removed in C (arts_humanities_studies no longer beside
statistics_data, housing beside no agriculture field): met (B also removes them). 5 stability: mean tiled shift 28.7 > 25 **not met**,
p95 79.7 > 60 **not met**; sectors split 16 = A's (met, enforced); extra runs 97 <= 166 (met). The guard holds on the slots (maximum slot
displacement <= 120, tested) but the tiled slice centres of the 247 variable-width slices drift from the slots: tiled maximum 122.8, so
"max <= 120 by construction" was wrong for the tiled centre (it holds for the slot). 6 blinded adjacency: not yet run (lead).

Reading. Combined similarity is both what C optimises and what 1 and 2 measure, so 1 and 2 are sanity checks (the circularity of
metric 1 above); the independent check is prediction 6. A large share of the gain costs no displacement: with lambda x 1000 (a
near-hard prior) C still reaches mean similarity 1.64 and no-signal share 0.24 at mean tiled shift 15.3 (A: 15.8), because the axes
prior leaves 178 of 247 fields tied (127 distinct angles) and free to reorder within the tie. The shipped tie-break (parent angle)
uses only part of that freedom.

Sensitivity (lambda multiples of the default, reported not used to retune; the default stays the pre-registered one):

| lambda x | mean similarity | no-signal | rank dist | tiled shift mean / p95 / max | extra runs |
|---|---|---|---|---|---|
| 0 | 2.141 | 0.105 | 43.4 | 45.6 / 103.1 / 121.5 | 101 |
| 0.25 | 2.217 | 0.081 | 33.8 | 32.3 / 74.3 / 127.0 | 104 |
| 1 (default) | 2.243 | 0.093 | 34.1 | 28.7 / 79.7 / 122.8 | 97 |
| 4 | 2.130 | 0.138 | 34.3 | 20.0 / 53.6 / 98.0 | 105 |
| 1000 | 1.639 | 0.239 | 33.4 | 15.3 / 47.8 / 101.1 | 101 |

Lambda x 4 (1/30 per degree) would meet every stability prediction (mean 20.0, p95 53.6, max 98) at 95% of the default's similarity
gain; choosing it now would be a post-hoc tune, so it is offered to the lead as a decision, not adopted. Note lambda 0 does not give
the highest similarity (2.141 < 2.243): the heuristic is not exact and the greedy and kick starts end in different local optima.
Blinded batches (shipped A against seriation C, two variants, 247 fields each, `adjacency.v1`): `data/batches/seriation/`
(gitignored), key `data/ephemeral/seriation/adjacency.v1.key.json` (gitignored, set 1 versus layout A or C per task).

## Seriation arm, blinded adjacency judged (lead, 2026-11-26)
`adjacency.v1`, Haiku runners, 247 fields x 2 variants, shipped order (A) vs circular seriation at the pre-registered lambda
(B in the key; key held in data/ephemeral/seriation/): variant 0, B 230 vs A 9, 8 ties, share 0.962, z 14.3; variant 1, B 229
vs A 12, 6 ties, share 0.950, z 14.0 (pooled 459 vs 21, z 20.0; per-variant z is the honest figure). Decisive 97% of tasks;
position bias 0.54 / 0.43. Prediction (>= 58%, z >= 2 per variant; z >= 3 for README): **met**, far beyond (the force sim
reached 54%). Caveat: the combined similarity includes a TF-IDF text source, so part of what the judge rewards (labels that
read alike) is also what seriation optimised; the judge is still independent of the matrix and reads meaning. Stability
remains unmet at this lambda (mean shift 28.7, p95 79.7 against 25 and 60); a stiffer lambda (x4 met every stability
prediction keeping 95% of the similarity gain) is an author decision and, being chosen after this result, needs its own
blinded check before adoption.
