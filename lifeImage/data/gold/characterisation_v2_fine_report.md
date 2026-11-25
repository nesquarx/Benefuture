# Characterisation v2 on fine evidence: report

Pre-registered signatures (`characterisation_signatures_v2.json`, committed before any render with grain restricted to claimed potential, the
anchored tone map or the literature-based estimation bias) evaluated on the extended population (144 generated personas, all-tier truth rows; the
primary verdicts) and, as secondary readings, on the 40 starter personas under each projection. No model was run. Held, not held and inconclusive
are reported as they fall; signatures are not edited after measurement.

## Summary

| set | n | held | not held | inconclusive | archetype id. (LOO) | calibration id. (LOO) |
|---|---|---|---|---|---|---|
| extended / new | 144 | 14 | 11 | 13 | 0.57 [0.49, 0.65] (chance 0.125, majority 0.12) | 0.45 [0.37, 0.53] (chance 0.333, majority 0.33) |
| extended / legacy | 144 | 11 | 22 | 5 | 0.55 [0.47, 0.63] (chance 0.125, majority 0.12) | 0.41 [0.33, 0.49] (chance 0.333, majority 0.33) |
| starter truth / new | 40 | 10 | 7 | 21 | 0.42 [0.29, 0.58] (chance 0.125, majority 0.12) | 0.28 [0.16, 0.43] (chance 0.333, majority 0.40) |
| starter truth / legacy | 40 | 8 | 10 | 20 | 0.38 [0.24, 0.53] (chance 0.125, majority 0.12) | 0.30 [0.18, 0.45] (chance 0.333, majority 0.40) |
| starter resume claims / new | 40 | 10 | 7 | 21 | 0.33 [0.20, 0.48] (chance 0.125, majority 0.12) | 0.45 [0.31, 0.60] (chance 0.333, majority 0.40) |
| starter extracted var0 / new | 40 | 7 | 7 | 24 | 0.20 [0.10, 0.35] (chance 0.125, majority 0.12) | 0.47 [0.33, 0.63] (chance 0.333, majority 0.40) |
| starter extracted var0 / legacy | 40 | 8 | 16 | 14 | 0.23 [0.12, 0.38] (chance 0.125, majority 0.12) | 0.53 [0.37, 0.67] (chance 0.333, majority 0.40) |
| starter extracted var1 / new | 40 | 12 | 9 | 17 | 0.23 [0.12, 0.38] (chance 0.125, majority 0.12) | 0.38 [0.24, 0.53] (chance 0.333, majority 0.40) |
| starter extracted var1 / legacy | 40 | 9 | 16 | 13 | 0.23 [0.12, 0.38] (chance 0.125, majority 0.12) | 0.38 [0.24, 0.53] (chance 0.333, majority 0.40) |
| starter extracted var2 / new | 40 | 10 | 10 | 18 | 0.17 [0.09, 0.32] (chance 0.125, majority 0.12) | 0.42 [0.29, 0.58] (chance 0.333, majority 0.40) |
| starter extracted var2 / legacy | 40 | 8 | 16 | 14 | 0.20 [0.10, 0.35] (chance 0.125, majority 0.12) | 0.45 [0.31, 0.60] (chance 0.333, majority 0.40) |

Identification: nearest centroid, leave one out, features standardised on the training fold; Wilson 95% interval; chance is 1/classes,
majority the share of the largest class. An interval whose lower end is above the chance and the majority rate is better than chance.

## Predicted blind identification

The three extracted variants are pooled (correct and n summed over the variants) for the extracted rows: the registered line names the three variants
together and does not say how to combine them; this reading was fixed before any measurement.

| id | set | label | prediction | accuracy [95% interval] | verdict |
|---|---|---|---|---|---|
| I1 | extended / new | archetype | at least 0.60 | 0.569 [0.488, 0.647] (n=144) | inconclusive |
| I2 | extended / new | calibration | at least 0.45 | 0.451 [0.372, 0.533] (n=144) | held |
| I3 | starter extracted (var0, var1, var2) / new | archetype | at least 0.25 | 0.200 [0.138, 0.280] (n=120) | inconclusive |
| I4 | starter extracted (var0, var1, var2) / new | calibration | at least 0.40 | 0.425 [0.340, 0.514] (n=120) | held |
| I5 | extended / legacy | archetype | at most 0.62 | 0.549 [0.467, 0.628] (n=144) | held |
| I6 | extended / legacy | calibration | at most 0.40 | 0.410 [0.333, 0.491] (n=144) | inconclusive |

## Signatures on the primary population (extended / new)

| id | prediction | conf | verdict | effect [95% interval] against delta |
|---|---|---|---|---|
| A1 | students show little blue (they take in more than they change) | medium | **held** | 0.104 [0.051, 0.156] vs 0.05 |
| A2 | students' red is spread wide over the circle | low | **not held** | -0.141 [-0.182, -0.101] vs 0.03 |
| A3 | students' evidence is recent, so little is dimmed | high | **held** | 0.342 [0.309, 0.375] vs 0.05 |
| A4 | shift workers show less red than others (little formal learning, few credentials) | low | **inconclusive** | 0.013 [-0.014, 0.040] vs 0.03 |
| A5 | carers' luminance concentrates in the family arc | medium | **not held** | 0.014 [0.001, 0.027] vs 0.05 |
| A6 | carers show more blue (their output changes things for others) | low | **not held** | 0.013 [0.001, 0.026] vs 0.03 |
| A7 | small-business owners' luminance concentrates in the work arc | medium | **held** | 0.064 [0.044, 0.084] vs 0.05 |
| A8 | researchers' green and blue lie in the science and learning arcs | medium | **not held** | 0.024 [-0.008, 0.057] vs 0.1 |
| A9 | researchers' red is less grainy (publications, degrees and records attest their work) | low | **held** | 0.050 [0.000, 0.101] vs 0.05 |
| A10 | retirees show low current luminance | low | **not held** | 0.007 [-0.016, 0.030] vs 0.05 |
| A11 | retirees' past domains are brighter than their current ones | low | **not held** | 0.083 [0.012, 0.154] vs 0.25 |
| A12 | retirees' evidence is largely dimmed by age | high | **held** | 0.278 [0.236, 0.320] vs 0.08 |
| A13 | career changers show more separated clusters than others | low | **not held** | -0.643 [-1.121, -0.164] vs 0.5 |
| A14 | most career changers show two or more clusters | low | **inconclusive** | 9/18 [0.290, 0.710] vs 0.5 |
| A15 | where a career changer shows two or more clusters, the older cluster is the dimmer | medium | **inconclusive** | 4/9 [0.189, 0.733] vs 0.6 |
| A16 | generalists spread their luminance over the circle | medium | **inconclusive** | -0.002 [-0.043, 0.040] vs 0.03 |
| A17 | generalists have no dominant arc | medium | **inconclusive** | -0.002 [-0.058, 0.053] vs 0.04 |
| G1 | the pooled population composite (mean of displayed channels per slice over all personas) tends toward white: each channel share in the band | medium | **not held** | red 0.261, green 0.378, blue 0.361 in [0.27, 0.4] |
| G2 | pooling cancels colour: the composite's chroma is at most half the mean chroma of a single persona | medium | **not held** | 0.898 <= 0.5 |
| K1 | over-estimators claim potential above demonstrated skill, more than well-calibrated people | medium | **inconclusive** | 0.064 [-0.026, 0.155] vs 0.08 |
| K2 | under-estimators claim potential below demonstrated skill, more than well-calibrated people | low | **inconclusive** | 0.055 [-0.034, 0.144] vs 0.05 |
| K3 | the extremes separate on the claim gap: over above under | medium | **inconclusive** | 0.119 [0.040, 0.199] vs 0.15 |
| K4 | over-estimators: grain is a larger share of grain plus green in the domains they claim | medium | **not held** | 0.006 [-0.038, 0.050] vs 0.05 |
| K5 | under-estimators: grain is a smaller share of grain plus green | low | **inconclusive** | 0.027 [-0.019, 0.073] vs 0.03 |
| K6 | over-estimators claim higher levels | medium | **held** | 0.072 [0.043, 0.102] vs 0.03 |
| K7 | under-estimators claim lower levels | low | **held** | 0.078 [0.047, 0.109] vs 0.02 |
| K8 | over-estimators: more of the claimed area exceeds demonstrated skill | medium | **inconclusive** | 0.094 [-0.029, 0.216] vs 0.1 |
| K9 | under-estimators: more of the claimed area falls short of demonstrated skill | low | **inconclusive** | 0.069 [-0.037, 0.174] vs 0.05 |
| K10 | well-calibrated people have a smaller absolute claim gap than over-estimators | medium | **inconclusive** | 0.012 [-0.057, 0.082] vs 0.05 |
| K11 | well-calibrated people have a smaller absolute claim gap than under-estimators | low | **inconclusive** | -0.005 [-0.067, 0.057] vs 0.02 |
| K12 | the claim gap is larger where demonstrated skill is low than where it is high (paired within persona) | medium | **held** | 0.493 [0.425, 0.560] vs 0.2 |
| K13 | where demonstrated skill is high, claims fall below it | medium | **held** | 0.029 [0.010, 0.049] vs 0.02 |
| W1 | the reference life's typical touched domain sits at mid-brightness: personas aged 36 to 44, median typical level | medium | **held** | median 0.564 (n=18) in [0.35, 0.65] |
| W2 | the scale is absolute: students (thin evidence) sit dimmer than others | medium | **held** | 0.124 [0.059, 0.188] vs 0.05 |
| W3 | an ordinary life is no longer almost black: mean luminance over the extended population | low | **held** | mean 0.150 (n=144) in [0.04, 0.25] |
| W4 | tier shows as saturation: resume-claim images are paler than truth images of the same people | medium | **held** | 0.181 [0.121, 0.242] vs 0.1 |
| W5 | grain needs a prediction: no starter resume-claim image carries grain | high | **held** | mean 0.000 (n=40) in [0.0, 0.0] |
| W6 | grain is a minor part of the red: mean grainy share of red over the extended population | low | **not held** | mean 0.483 (n=144) in [0.05, 0.4] |

## Verdict by set

| id | extended / new | extended / legacy | starter truth / new | starter truth / legacy | starter resume claims / new | starter extracted var0 / new | starter extracted var0 / legacy | starter extracted var1 / new | starter extracted var1 / legacy | starter extracted var2 / new | starter extracted var2 / legacy |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A1 | held | not held | inconclusive | inconclusive | held | inconclusive | not held | held | inconclusive | not held | not held |
| A2 | not held | not held | not held | inconclusive | not held | not held | not held | not held | not held | not held | inconclusive |
| A3 | held | held | held | held | held | held | held | held | held | held | held |
| A4 | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A5 | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held |
| A6 | not held | not held | inconclusive | not held | inconclusive | inconclusive | not held | not held | not held | not held | not held |
| A7 | held | held | inconclusive | held | held | held | inconclusive | inconclusive | inconclusive | held | inconclusive |
| A8 | not held | not held | inconclusive | inconclusive | held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A9 | held | not held | inconclusive | not held | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A10 | not held | not held | not held | inconclusive | held | inconclusive | not held | held | not held | inconclusive | not held |
| A11 | not held | not held | not held | not held | inconclusive | not held | not held | inconclusive | not held | not held | not held |
| A12 | held | held | held | held | held | inconclusive | inconclusive | held | held | inconclusive | inconclusive |
| A13 | not held | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | not held | inconclusive | not held |
| A14 | inconclusive | held | inconclusive | inconclusive | held | inconclusive | not held | inconclusive | not held | inconclusive | not held |
| A15 | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A16 | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A17 | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| G1 | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held |
| G2 | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held |
| K1 | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | held | held | held | held | held |
| K2 | inconclusive | held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| K3 | inconclusive | not held | held | inconclusive | inconclusive | inconclusive | held | held | held | held | held |
| K4 | not held | not held | inconclusive | inconclusive | inconclusive | inconclusive | not held | not held | not held | not held | not held |
| K5 | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive | not held | inconclusive | not held |
| K6 | held | held | held | held | inconclusive | held | held | held | held | held | held |
| K7 | held | held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| K8 | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive | not held | inconclusive | not held |
| K9 | inconclusive | not held | inconclusive | not held | inconclusive | inconclusive | not held | not held | not held | not held | not held |
| K10 | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | held | held | held | held | held |
| K11 | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| K12 | held | held | held | held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| K13 | held | not held | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| W1 | held | not held | held | not held | held | held | not held | held | not held | held | not held |
| W2 | held | inconclusive | held | inconclusive | inconclusive | not held | not held | inconclusive | not held | inconclusive | not held |
| W3 | held | held | held | held | not held | not held | not held | not held | not held | not held | not held |
| W4 | held | held | held | held | held | held | held | held | held | held | held |
| W5 | held | held | held | held | held | held | held | held | held | held | held |
| W6 | not held | not held | not held | not held | not held | held | held | held | held | held | held |

## Humanity white (pooled composite)

| set | red | green | blue | chroma / mean chroma |
|---|---|---|---|---|
| extended / new | 0.261 | 0.378 | 0.361 | 0.898 |
| extended / legacy | 0.049 | 0.499 | 0.452 | 0.966 |
| starter truth / new | 0.264 | 0.377 | 0.359 | 0.903 |
| starter truth / legacy | 0.047 | 0.501 | 0.452 | 0.973 |
| starter resume claims / new | 0.188 | 0.395 | 0.418 | 0.998 |
| starter extracted var0 / new | 0.225 | 0.610 | 0.165 | 1.073 |
| starter extracted var0 / legacy | 0.121 | 0.879 | 0.000 | 1.081 |
| starter extracted var1 / new | 0.276 | 0.527 | 0.197 | 1.039 |
| starter extracted var1 / legacy | 0.072 | 0.874 | 0.054 | 1.079 |
| starter extracted var2 / new | 0.401 | 0.434 | 0.165 | 1.005 |
| starter extracted var2 / legacy | 0.122 | 0.878 | 0.000 | 1.000 |

## Luminance, before and after

Mean image luminance by set; version 1 is the earlier report (earlier tone constant, claimed tier as grain, earlier generator).

| set | mean luminance v1 (min, max) | mean luminance v2 | mean typical level v2 |
|---|---|---|---|
| extended / new | 0.0310 (0.0017, 0.0704) | 0.150 | 0.440 |
| extended / legacy | 0.1321 (0.0162, 0.2233) | 0.131 | 0.195 |
| starter truth / new | 0.0315 (0.0022, 0.0510) | 0.150 | 0.470 |
| starter truth / legacy | 0.1359 (0.0210, 0.1921) | 0.135 | 0.224 |
| starter resume claims / new | 0.0006 (0.0000, 0.0015) | 0.033 | 0.498 |
| starter extracted var0 / new | 0.0006 (0.0000, 0.0019) | 0.018 | 0.397 |
| starter extracted var0 / legacy | 0.0054 (0.0000, 0.0112) | 0.004 | 0.000 |
| starter extracted var1 / new | 0.0006 (0.0000, 0.0024) | 0.017 | 0.410 |
| starter extracted var1 / legacy | 0.0054 (0.0000, 0.0111) | 0.005 | 0.000 |
| starter extracted var2 / new | 0.0003 (0.0000, 0.0014) | 0.015 | 0.371 |
| starter extracted var2 / legacy | 0.0042 (0.0003, 0.0082) | 0.004 | 0.000 |

## Fine evidence: does identification change with the finer resolution?

Prediction, written before the run (confidence moderate, ETA this run): the pre-registered features read the coarse image, where a field
is the re-saturated sum of its children, so identification stays within 0.05 of the control (the same personas and code with every row kept at
the coarse fields); the exploratory fine descriptors add at least 0.05 to archetype identification (low confidence: fine detail may separate
archetypes the coarse fields blur).

144 personas (8 archetypes x 3 calibrations x 6), paired by persona. Control: the same code and personas, rows at the coarse fields.
Before (committed v2 report, earlier generator and code): archetype 0.535, calibration 0.465.

| label | v2 report (before) | control, current code | fine evidence | only fine right / only control right (exact sign test p) |
|---|---|---|---|---|
| archetype | 0.535 | 0.562 [0.481, 0.641] | 0.569 [0.488, 0.647] | 8 / 7 (p = 1.000) |
| calibration | 0.465 | 0.472 [0.392, 0.553] | 0.451 [0.372, 0.533] | 10 / 13 (p = 0.678) |

Exploratory, not pre-registered: the same identification with the fine-ring descriptors (`fine_*`) added to the features.

| label | fine evidence | with fine descriptors | only descriptors right / only base right (exact sign test p) |
|---|---|---|---|
| archetype | 0.569 | 0.556 [0.474, 0.634] | 3 / 5 (p = 0.727) |
| calibration | 0.451 | 0.431 [0.353, 0.512] | 2 / 5 (p = 0.453) |

Facts of the fine ring: 15457 of 16113 event rows name a fine domain (95.9%); a persona lights 64.3 fine slices on average (16.8% of the ring by area); the median typical level of a touched fine domain is 0.376 against 0.449 for a touched coarse field (evidence splits over children).


## Post-hoc diagnostic (not pre-registered)

Extended population: mean estimate minus truth over every claimed domain, by calibration, and the pooled correlation between estimate and truth
(1714 estimates; Zell and Krizan 2014 report about 0.29 between self-assessment and performance).

| calibration | mean estimate minus truth |
|---|---|
| over | 0.145 |
| under | -0.074 |
| well | 0.012 |

Pooled correlation of estimate and truth: 0.481.

## Degradations

- none

## Reading notes

- Starter cells hold 1 to 4 personas; read the starter verdicts as a check of the pipeline's direction, not as tests with power.
- Extracted rows are claims read from resumes and texts: tier shows as pale solid colour and self-assessments as grain, but no attested or measured
  tier exists in them, so signatures that need demonstrated skill rest on claimed green only.
- Signatures that name a projection (W4, W5) report the same value in every column.
