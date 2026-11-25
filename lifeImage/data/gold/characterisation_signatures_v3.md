# Characterisation signatures v3 (pre-registered 2026-11-25)

Written from the identification-ceiling result and committed before any v3 measurement. The machine-readable twin is `characterisation_signatures_v3.json` (same ids, values and directions); the battery (`tools/characterise_v3.py`) evaluates exactly that file and the file is hash-pinned by a test. A prediction is held, not held or inconclusive as it falls, and is never edited after measurement. Version 2 (`characterisation_signatures_v2.*`) stays as it was and is re-evaluated unchanged on the same personas.

## Why a v3 feature set

The identification ceiling found the image's full per-domain levels carry the archetype (0.85) while the battery's summary features lose it (0.57), and calibration lives in grain and tier (summary features, which include the global grain share, 0.58; levels alone 0.17). The v3 set reads levels and grain together, reduced only by an unsupervised method fitted inside each fold, and keeps the v2 summary features.

## Feature set

- L: per coarse slice (sector and field rings): solid red, green and blue levels.
- G: per coarse slice: red grain share = claimed red / (solid red + claimed red), 0 where both are 0.
- T: per coarse slice: saturation of the solid layer (tier, LI.38).
- S: the v2 summary features (BASE_FEATURES and the arc shares, the battery's identification names), passed through unreduced.
- Reduction: PCA on the columns standardised with the training fold's mean and sd, top k components (k = 20), fitted inside every training fold and, for the penalty search, again inside every inner fold; unsupervised, labels never read; sign of each component fixed by its largest absolute loading being positive.

| set | columns |
|---|---|
| v2 | S |
| v3 | PCA(L, G, T) + S |
| v3_L | PCA(L) + S |
| v3_GT | PCA(G, T) + S |
| v3_pca | PCA(L, G, T) alone |
| v3_k10 | as v3 with k = 10 (exploratory, truth rows only) |
| v3_k40 | as v3 with k = 40 (exploratory, truth rows only) |

Classifiers: nearest centroid (the battery's) and L2 logistic regression with nested cross-validation (grid 0.0001 to 10, 4 inner folds, log-loss). Protocol: leave one out per persona; scaling, reduction and tuning see the training rows only; deterministic.

## Populations

| key | set |
|---|---|
| truth | extended / new: 144 generated personas (8 archetypes x 3 calibrations x 6), truth rows, fine evidence, new projection |
| legacy | extended / legacy: the same 144 personas under the legacy projection |
| extracted | starter extracted (var0, var1, var2) / new: the 40 starter personas, rows read from resume texts, new projection; each variant evaluated on its own (leave one out within the variant) and pooled, 120 persona-variants |

Reference (identification ceiling, same personas): v2 summary features on truth rows, archetype 0.569 (centroid) and 0.576 (logistic), calibration 0.451 and 0.576.

## Verdict rules

| kind | rule |
|---|---|
| min | held if the point accuracy >= value, not held if the Wilson 95% upper bound < value, else inconclusive |
| max | held if the point accuracy <= value, not held if the Wilson 95% lower bound > value, else inconclusive |
| diff | difference of accuracy a - b over the same personas, normal-approximation 95% interval of the paired difference of correct flags (persona-level means over the three variants for the extracted set, 40 clusters, Student-t 39 df); held if the difference >= delta and the interval excludes 0; not held if the interval's upper end < delta; else inconclusive. The exact sign test is reported (per persona-variant flags; for the extracted set on the persona-level sign of the mean difference) |
| rank_low | held if any named class is among the k lowest-recall classes (ties by class order) |
| multiplicity | no adjustment; each prediction is read on its own, with its stated confidence; the report counts held against the confidences' expectation |

## Predictions

Each prediction states direction, smallest effect (value or delta) and confidence (the stated probability it holds); a and b are set / feature set / classifier.

| id | label | prediction | a | b | value or delta | confidence |
|---|---|---|---|---|---|---|
| A1 | archetype | v3 features identify archetype from truth rows at least 0.75 (logistic): the image's levels, reduced, keep the signal the summary features lose | truth / v3 / logistic |  | 0.75 | 0.60 |
| A2 | archetype | v3 beats v2 (same classifier, logistic) on archetype by at least 0.15 | truth / v3 / logistic | truth / v2 / logistic | 0.15 | 0.65 |
| A3 | archetype | v3 (logistic) beats the battery's v2 nearest centroid on archetype by at least 0.15 | truth / v3 / logistic | truth / v2 / centroid | 0.15 | 0.65 |
| A4 | archetype | levels carry archetype, grain and tier do not: v3_L minus v3_GT (logistic) is at least 0.10 | truth / v3_L / logistic | truth / v3_GT / logistic | 0.1 | 0.70 |
| A5 | archetype | the reduction helps the nearest centroid too: v3 minus v2 (centroid) is at least 0.10 | truth / v3 / centroid | truth / v2 / centroid | 0.1 | 0.55 |
| C1 | calibration | v3 features identify calibration from truth rows at least 0.60 (logistic) | truth / v3 / logistic |  | 0.6 | 0.35 |
| C2 | calibration | per-domain grain share and tier saturation add to the global grain share: v3 minus v2 (logistic) on calibration is at least 0.04 | truth / v3 / logistic | truth / v2 / logistic | 0.04 | 0.35 |
| C3 | calibration | adding the grain and tier block to the summary features beats adding the levels block: v3_GT minus v3_L (logistic) on calibration is at least 0.04 | truth / v3_GT / logistic | truth / v3_L / logistic | 0.04 | 0.45 |
| C4 | calibration | the full v3 beats v3_L (logistic) on calibration by at least 0.04: the grain and tier block is what calibration needs | truth / v3 / logistic | truth / v3_L / logistic | 0.04 | 0.45 |
| C5 | calibration | the reduced image blocks alone (v3_pca, without the summary features) identify calibration at most 0.55 (logistic) | truth / v3_pca / logistic |  | 0.55 | 0.50 |
| X1 | archetype | on rows extracted from resume texts, v3 beats v2 (logistic) on archetype by at least 0.05 | extracted / v3 / logistic | extracted / v2 / logistic | 0.05 | 0.40 |
| X2 | archetype | on extracted rows v3 identifies archetype at least 0.30 (logistic; the v2 battery reads about 0.2) | extracted / v3 / logistic |  | 0.3 | 0.40 |
| X3 | calibration | on extracted rows v3 beats v2 (logistic) on calibration by at least 0.04 | extracted / v3 / logistic | extracted / v2 / logistic | 0.04 | 0.30 |
| L1 | archetype | on the legacy projection v3 beats v2 (logistic) on archetype by at least 0.15: the legacy image still draws the levels | legacy / v3 / logistic | legacy / v2 / logistic | 0.15 | 0.60 |
| L2 | calibration | the legacy projection has no tier saturation, so calibration drops: truth minus legacy for v3 (logistic) is at least 0.05 | truth / v3 / logistic | legacy / v3 / logistic | 0.05 | 0.50 |
| L3 | calibration | on the legacy projection v3 identifies calibration at most 0.55 (logistic) | legacy / v3 / logistic |  | 0.55 | 0.60 |
| R1 | archetype | generalist is among the two lowest-recall archetypes for v3 (logistic) on truth rows (no distinctive profile) | truth / v3 / logistic |  | k=2 | 0.55 |
| R2 | calibration | well calibrated is the lowest-recall calibration class for v3 (logistic) on truth rows (the middle class is confused with both sides) | truth / v3 / logistic |  | k=1 | 0.50 |

Expected to hold: 9.1 of 18.

## Caveats stated in advance

- 144 personas: intervals of about +-0.08; differences below that are read through the paired interval and the sign test.
- The extracted set repeats 40 personas under three extraction variants; its paired intervals are clustered by persona.
- Generated data: what the generator puts in is what can come out.
- The summary features are carried unreduced, so v3 differs from v2 by the reduced image blocks only.
