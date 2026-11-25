# Characterisation v1: report

Pre-registered signatures (`characterisation_signatures_v1.json`, committed before any new render) evaluated on the extended population
(144 generated personas, all-tier truth rows; the primary verdicts) and, as secondary readings, on the 40 starter personas under each
projection. No model was run. Held, not held and inconclusive are reported as they fall; signatures are not edited after measurement.

## Summary

| set | n | held | not held | inconclusive | archetype id. (LOO) | calibration id. (LOO) |
|---|---|---|---|---|---|---|
| extended / new | 144 | 6 | 9 | 11 | 0.58 [0.49, 0.65] (chance 0.125, majority 0.12) | 0.31 [0.24, 0.39] (chance 0.333, majority 0.33) |
| extended / legacy | 144 | 4 | 20 | 2 | 0.56 [0.48, 0.64] (chance 0.125, majority 0.12) | 0.25 [0.19, 0.33] (chance 0.333, majority 0.33) |
| starter truth / new | 40 | 5 | 5 | 16 | 0.53 [0.37, 0.67] (chance 0.125, majority 0.12) | 0.28 [0.16, 0.43] (chance 0.333, majority 0.40) |
| starter truth / legacy | 40 | 2 | 14 | 10 | 0.45 [0.31, 0.60] (chance 0.125, majority 0.12) | 0.35 [0.22, 0.50] (chance 0.333, majority 0.40) |
| starter resume claims / new | 40 | 3 | 13 | 10 | 0.23 [0.12, 0.38] (chance 0.125, majority 0.12) | 0.35 [0.22, 0.50] (chance 0.333, majority 0.40) |
| starter extracted var0 / new | 40 | 2 | 14 | 10 | 0.12 [0.05, 0.26] (chance 0.125, majority 0.12) | 0.53 [0.37, 0.67] (chance 0.333, majority 0.40) |
| starter extracted var0 / legacy | 40 | 2 | 9 | 15 | 0.12 [0.05, 0.26] (chance 0.125, majority 0.12) | 0.40 [0.26, 0.55] (chance 0.333, majority 0.40) |
| starter extracted var1 / new | 40 | 1 | 15 | 10 | 0.17 [0.09, 0.32] (chance 0.125, majority 0.12) | 0.57 [0.42, 0.71] (chance 0.333, majority 0.40) |
| starter extracted var1 / legacy | 40 | 1 | 10 | 15 | 0.15 [0.07, 0.29] (chance 0.125, majority 0.12) | 0.47 [0.33, 0.63] (chance 0.333, majority 0.40) |
| starter extracted var2 / new | 40 | 1 | 20 | 5 | 0.28 [0.16, 0.43] (chance 0.125, majority 0.12) | 0.62 [0.47, 0.76] (chance 0.333, majority 0.40) |
| starter extracted var2 / legacy | 40 | 1 | 13 | 12 | 0.23 [0.12, 0.38] (chance 0.125, majority 0.12) | 0.53 [0.37, 0.67] (chance 0.333, majority 0.40) |

Identification: nearest centroid, leave one out, features standardised on the training fold; Wilson 95% interval; chance is 1/classes,
majority the share of the largest class. An interval whose lower end is above the chance and the majority rate is better than chance.

## Signatures on the primary population (extended / new)

| id | prediction | conf | verdict | effect [95% interval] against delta |
|---|---|---|---|---|
| C1 | over-estimators carry a larger grainy share of their red than well-calibrated people | medium | **not held** | 0.013 [-0.012, 0.037] vs 0.05 |
| C2 | over-estimators show more red overall than well-calibrated people | medium | **inconclusive** | -0.006 [-0.078, 0.065] vs 0.04 |
| C3 | under-estimators show less red overall than well-calibrated people | medium | **inconclusive** | 0.043 [-0.031, 0.117] vs 0.04 |
| C4 | under-estimators carry a smaller grainy share of their red than well-calibrated people | low | **not held** | 0.016 [-0.015, 0.047] vs 0.05 |
| C5 | the grainy red share separates the extremes: over above under | medium | **not held** | 0.029 [0.000, 0.057] vs 0.1 |
| C6 | well-calibrated images sit closer to channel balance than over-estimators | low | **inconclusive** | -0.019 [-0.077, 0.038] vs 0.03 |
| C7 | well-calibrated images sit closer to channel balance than under-estimators | low | **inconclusive** | -0.024 [-0.082, 0.034] vs 0.03 |
| A1 | students show little blue (they take in more than they change) | medium | **held** | 0.188 [0.115, 0.261] vs 0.05 |
| A2 | students' red is spread wide over the circle | low | **not held** | -0.135 [-0.170, -0.100] vs 0.03 |
| A3 | students' evidence is recent, so little is dimmed | high | **held** | 0.342 [0.308, 0.375] vs 0.05 |
| A4 | shift workers show less red than others (little formal learning, few credentials) | low | **inconclusive** | 0.015 [-0.045, 0.075] vs 0.03 |
| A5 | carers' luminance concentrates in the family arc | medium | **not held** | 0.001 [-0.010, 0.012] vs 0.05 |
| A6 | carers show more blue (their output changes things for others) | low | **inconclusive** | 0.004 [-0.026, 0.034] vs 0.03 |
| A7 | small-business owners' luminance concentrates in the work arc | medium | **held** | 0.150 [0.090, 0.210] vs 0.05 |
| A8 | researchers' green and blue lie in the science and learning arcs | medium | **inconclusive** | 0.046 [-0.025, 0.116] vs 0.1 |
| A9 | researchers' red is less grainy (publications, degrees and records attest their work) | low | **not held** | 0.009 [-0.021, 0.039] vs 0.05 |
| A10 | retirees show low current luminance | low | **not held** | 0.008 [0.001, 0.014] vs 0.05 |
| A11 | retirees' past domains are brighter than their current ones | low | **not held** | 0.096 [0.011, 0.180] vs 0.25 |
| A12 | retirees' evidence is largely dimmed by age | high | **held** | 0.280 [0.236, 0.323] vs 0.08 |
| A13 | career changers show more separated clusters than others | low | **inconclusive** | 0.437 [0.063, 0.810] vs 0.5 |
| A14 | most career changers show two or more clusters | low | **held** | 15/18 [0.608, 0.942] vs 0.5 |
| A15 | where a career changer shows two or more clusters, the older cluster is the dimmer | medium | **inconclusive** | 8/15 [0.301, 0.752] vs 0.6 |
| A16 | generalists spread their luminance over the circle | medium | **inconclusive** | -0.005 [-0.044, 0.033] vs 0.03 |
| A17 | generalists have no dominant arc | medium | **inconclusive** | -0.027 [-0.113, 0.059] vs 0.04 |
| G1 | the pooled population composite (mean of displayed channels per slice over all personas) tends toward white: each channel share in the band | medium | **held** | red 0.346, green 0.281, blue 0.374 in [0.27, 0.4] |
| G2 | pooling cancels colour: the composite's chroma is at most half the mean chroma of a single persona | medium | **not held** | 0.923 <= 0.5 |

## Verdict by set

| id | extended / new | extended / legacy | starter truth / new | starter truth / legacy | starter resume claims / new | starter extracted var0 / new | starter extracted var0 / legacy | starter extracted var1 / new | starter extracted var1 / legacy | starter extracted var2 / new | starter extracted var2 / legacy |
|---|---|---|---|---|---|---|---|---|---|---|---|
| C1 | not held | not held | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive |
| C2 | inconclusive | not held | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive |
| C3 | inconclusive | not held | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | not held |
| C4 | not held | not held | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive |
| C5 | not held | not held | inconclusive | not held | not held | not held | inconclusive | not held | inconclusive | not held | not held |
| C6 | inconclusive | not held | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive |
| C7 | inconclusive | not held | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | not held |
| A1 | held | not held | held | not held | not held | not held | not held | not held | not held | not held | not held |
| A2 | not held | not held | not held | inconclusive | not held | not held | inconclusive | not held | not held | not held | not held |
| A3 | held | held | held | held | held | held | held | held | held | held | held |
| A4 | inconclusive | not held | inconclusive | inconclusive | not held | not held | inconclusive | not held | inconclusive | not held | inconclusive |
| A5 | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held |
| A6 | inconclusive | not held | inconclusive | not held | not held | not held | not held | not held | not held | not held | not held |
| A7 | held | held | inconclusive | inconclusive | held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A8 | inconclusive | not held | held | inconclusive | not held | not held | inconclusive | not held | inconclusive | not held | inconclusive |
| A9 | not held | not held | inconclusive | not held | not held | not held | inconclusive | not held | inconclusive | not held | inconclusive |
| A10 | not held | not held | not held | inconclusive | not held | not held | not held | not held | not held | not held | not held |
| A11 | not held | not held | not held | not held | inconclusive | not held | not held | not held | not held | not held | not held |
| A12 | held | held | held | held | held | held | held | inconclusive | inconclusive | inconclusive | inconclusive |
| A13 | inconclusive | not held | inconclusive | inconclusive | not held | not held | not held | not held | not held | not held | not held |
| A14 | held | held | inconclusive | inconclusive | not held | not held | not held | not held | not held | not held | not held |
| A15 | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A16 | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A17 | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive | inconclusive | inconclusive |
| G1 | held | not held | held | not held | not held | not held | not held | not held | not held | not held | not held |
| G2 | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held |

## Humanity white (pooled composite)

| set | red | green | blue | chroma / mean chroma |
|---|---|---|---|---|
| extended / new | 0.346 | 0.281 | 0.374 | 0.923 |
| extended / legacy | 0.049 | 0.507 | 0.444 | 0.957 |
| starter truth / new | 0.340 | 0.281 | 0.378 | 0.924 |
| starter truth / legacy | 0.047 | 0.507 | 0.446 | 0.963 |
| starter resume claims / new | 1.000 | 0.000 | 0.000 | 1.081 |
| starter extracted var0 / new | 1.000 | 0.000 | 0.000 | 1.081 |
| starter extracted var0 / legacy | 0.067 | 0.933 | 0.000 | 1.081 |
| starter extracted var1 / new | 1.000 | 0.000 | 0.000 | 1.081 |
| starter extracted var1 / legacy | 0.067 | 0.933 | 0.000 | 1.081 |
| starter extracted var2 / new | 1.000 | 0.000 | 0.000 | 1.000 |
| starter extracted var2 / legacy | 0.082 | 0.918 | 0.000 | 1.000 |

## Post-hoc diagnostic (not pre-registered)

Extended population, by calibration: the mean level of the claimed red over lit claimed slices, and how many slices carry claimed red.

| calibration | mean claimed red level | lit claimed slices | n |
|---|---|---|---|
| over | 0.211 | 57.9 | 48 |
| well | 0.163 | 60.8 | 48 |
| under | 0.141 | 60.8 | 48 |

Candidate for a v2 signature (to be registered before it is measured on fresh seeds), not a result of v1.

## Degradations

- none

## Reading notes

- Starter cells hold 1 to 4 personas; read the starter verdicts as a check of the pipeline's direction, not as tests with power.
- The extracted rows are claims read from resumes: no attested or measured tier, no self-assessment rows. Signatures that need the solid layer
  cannot hold from them, by construction.
