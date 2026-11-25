# Characterisation v2: report

Pre-registered signatures (`characterisation_signatures_v2.json`, committed before any render with grain restricted to claimed potential, the
anchored tone map or the literature-based estimation bias) evaluated on the extended population (144 generated personas, all-tier truth rows; the
primary verdicts) and, as secondary readings, on the 40 starter personas under each projection. No model was run. Held, not held and inconclusive
are reported as they fall; signatures are not edited after measurement.

## Summary

| set | n | held | not held | inconclusive | archetype id. (LOO) | calibration id. (LOO) |
|---|---|---|---|---|---|---|
| extended / new | 144 | 14 | 10 | 14 | 0.53 [0.45, 0.61] (chance 0.125, majority 0.12) | 0.47 [0.39, 0.55] (chance 0.333, majority 0.33) |
| extended / legacy | 144 | 11 | 23 | 4 | 0.54 [0.46, 0.62] (chance 0.125, majority 0.12) | 0.36 [0.29, 0.44] (chance 0.333, majority 0.33) |
| starter truth / new | 40 | 10 | 8 | 20 | 0.35 [0.22, 0.50] (chance 0.125, majority 0.12) | 0.30 [0.18, 0.45] (chance 0.333, majority 0.40) |
| starter truth / legacy | 40 | 7 | 11 | 20 | 0.42 [0.29, 0.58] (chance 0.125, majority 0.12) | 0.40 [0.26, 0.55] (chance 0.333, majority 0.40) |
| starter resume claims / new | 40 | 7 | 7 | 24 | 0.23 [0.12, 0.38] (chance 0.125, majority 0.12) | 0.50 [0.35, 0.65] (chance 0.333, majority 0.40) |
| starter extracted var0 / new | 40 | 11 | 7 | 20 | 0.20 [0.10, 0.35] (chance 0.125, majority 0.12) | 0.40 [0.26, 0.55] (chance 0.333, majority 0.40) |
| starter extracted var0 / legacy | 40 | 9 | 16 | 13 | 0.12 [0.05, 0.26] (chance 0.125, majority 0.12) | 0.40 [0.26, 0.55] (chance 0.333, majority 0.40) |
| starter extracted var1 / new | 40 | 6 | 6 | 26 | 0.15 [0.07, 0.29] (chance 0.125, majority 0.12) | 0.57 [0.42, 0.71] (chance 0.333, majority 0.40) |
| starter extracted var1 / legacy | 40 | 8 | 17 | 13 | 0.12 [0.05, 0.26] (chance 0.125, majority 0.12) | 0.45 [0.31, 0.60] (chance 0.333, majority 0.40) |
| starter extracted var2 / new | 40 | 8 | 10 | 20 | 0.15 [0.07, 0.29] (chance 0.125, majority 0.12) | 0.60 [0.45, 0.74] (chance 0.333, majority 0.40) |
| starter extracted var2 / legacy | 40 | 8 | 17 | 13 | 0.23 [0.12, 0.38] (chance 0.125, majority 0.12) | 0.53 [0.37, 0.67] (chance 0.333, majority 0.40) |

Identification: nearest centroid, leave one out, features standardised on the training fold; Wilson 95% interval; chance is 1/classes,
majority the share of the largest class. An interval whose lower end is above the chance and the majority rate is better than chance.

## Predicted blind identification

The three extracted variants are pooled (correct and n summed over the variants) for the extracted rows: the registered line names the three variants
together and does not say how to combine them; this reading was fixed before any measurement.

| id | set | label | prediction | accuracy [95% interval] | verdict |
|---|---|---|---|---|---|
| I1 | extended / new | archetype | at least 0.60 | 0.535 [0.453, 0.614] (n=144) | inconclusive |
| I2 | extended / new | calibration | at least 0.45 | 0.465 [0.386, 0.547] (n=144) | held |
| I3 | starter extracted (var0, var1, var2) / new | archetype | at least 0.25 | 0.167 [0.111, 0.243] (n=120) | not held |
| I4 | starter extracted (var0, var1, var2) / new | calibration | at least 0.40 | 0.525 [0.436, 0.612] (n=120) | held |
| I5 | extended / legacy | archetype | at most 0.62 | 0.542 [0.460, 0.621] (n=144) | held |
| I6 | extended / legacy | calibration | at most 0.40 | 0.361 [0.287, 0.442] (n=144) | held |

## Signatures on the primary population (extended / new)

| id | prediction | conf | verdict | effect [95% interval] against delta |
|---|---|---|---|---|
| A1 | students show little blue (they take in more than they change) | medium | **held** | 0.088 [0.038, 0.139] vs 0.05 |
| A2 | students' red is spread wide over the circle | low | **not held** | -0.145 [-0.184, -0.106] vs 0.03 |
| A3 | students' evidence is recent, so little is dimmed | high | **held** | 0.342 [0.309, 0.375] vs 0.05 |
| A4 | shift workers show less red than others (little formal learning, few credentials) | low | **inconclusive** | 0.020 [-0.008, 0.048] vs 0.03 |
| A5 | carers' luminance concentrates in the family arc | medium | **not held** | 0.018 [0.005, 0.031] vs 0.05 |
| A6 | carers show more blue (their output changes things for others) | low | **not held** | 0.011 [-0.001, 0.023] vs 0.03 |
| A7 | small-business owners' luminance concentrates in the work arc | medium | **held** | 0.078 [0.054, 0.101] vs 0.05 |
| A8 | researchers' green and blue lie in the science and learning arcs | medium | **not held** | 0.031 [-0.007, 0.069] vs 0.1 |
| A9 | researchers' red is less grainy (publications, degrees and records attest their work) | low | **held** | 0.063 [0.015, 0.112] vs 0.05 |
| A10 | retirees show low current luminance | low | **not held** | 0.008 [-0.016, 0.031] vs 0.05 |
| A11 | retirees' past domains are brighter than their current ones | low | **not held** | 0.055 [-0.011, 0.121] vs 0.25 |
| A12 | retirees' evidence is largely dimmed by age | high | **held** | 0.278 [0.236, 0.320] vs 0.08 |
| A13 | career changers show more separated clusters than others | low | **not held** | -0.643 [-1.076, -0.210] vs 0.5 |
| A14 | most career changers show two or more clusters | low | **inconclusive** | 13/18 [0.491, 0.875] vs 0.5 |
| A15 | where a career changer shows two or more clusters, the older cluster is the dimmer | medium | **inconclusive** | 8/13 [0.355, 0.823] vs 0.6 |
| A16 | generalists spread their luminance over the circle | medium | **inconclusive** | -0.000 [-0.042, 0.042] vs 0.03 |
| A17 | generalists have no dominant arc | medium | **inconclusive** | -0.005 [-0.068, 0.058] vs 0.04 |
| G1 | the pooled population composite (mean of displayed channels per slice over all personas) tends toward white: each channel share in the band | medium | **not held** | red 0.269, green 0.376, blue 0.355 in [0.27, 0.4] |
| G2 | pooling cancels colour: the composite's chroma is at most half the mean chroma of a single persona | medium | **not held** | 0.948 <= 0.5 |
| K1 | over-estimators claim potential above demonstrated skill, more than well-calibrated people | medium | **inconclusive** | 0.066 [-0.024, 0.157] vs 0.08 |
| K2 | under-estimators claim potential below demonstrated skill, more than well-calibrated people | low | **inconclusive** | 0.063 [-0.026, 0.151] vs 0.05 |
| K3 | the extremes separate on the claim gap: over above under | medium | **inconclusive** | 0.129 [0.049, 0.209] vs 0.15 |
| K4 | over-estimators: grain is a larger share of grain plus green in the domains they claim | medium | **inconclusive** | 0.007 [-0.037, 0.051] vs 0.05 |
| K5 | under-estimators: grain is a smaller share of grain plus green | low | **inconclusive** | 0.030 [-0.015, 0.075] vs 0.03 |
| K6 | over-estimators claim higher levels | medium | **held** | 0.072 [0.043, 0.102] vs 0.03 |
| K7 | under-estimators claim lower levels | low | **held** | 0.078 [0.047, 0.109] vs 0.02 |
| K8 | over-estimators: more of the claimed area exceeds demonstrated skill | medium | **inconclusive** | 0.077 [-0.047, 0.200] vs 0.1 |
| K9 | under-estimators: more of the claimed area falls short of demonstrated skill | low | **inconclusive** | 0.096 [-0.009, 0.200] vs 0.05 |
| K10 | well-calibrated people have a smaller absolute claim gap than over-estimators | medium | **inconclusive** | 0.014 [-0.057, 0.085] vs 0.05 |
| K11 | well-calibrated people have a smaller absolute claim gap than under-estimators | low | **inconclusive** | -0.013 [-0.075, 0.049] vs 0.02 |
| K12 | the claim gap is larger where demonstrated skill is low than where it is high (paired within persona) | medium | **held** | 0.512 [0.445, 0.579] vs 0.2 |
| K13 | where demonstrated skill is high, claims fall below it | medium | **held** | 0.029 [0.010, 0.048] vs 0.02 |
| W1 | the reference life's typical touched domain sits at mid-brightness: personas aged 36 to 44, median typical level | medium | **held** | median 0.556 (n=18) in [0.35, 0.65] |
| W2 | the scale is absolute: students (thin evidence) sit dimmer than others | medium | **held** | 0.145 [0.080, 0.209] vs 0.05 |
| W3 | an ordinary life is no longer almost black: mean luminance over the extended population | low | **held** | mean 0.168 (n=144) in [0.04, 0.25] |
| W4 | tier shows as saturation: resume-claim images are paler than truth images of the same people | medium | **held** | 0.151 [0.094, 0.207] vs 0.1 |
| W5 | grain needs a prediction: no starter resume-claim image carries grain | high | **held** | mean 0.000 (n=40) in [0.0, 0.0] |
| W6 | grain is a minor part of the red: mean grainy share of red over the extended population | low | **not held** | mean 0.449 (n=144) in [0.05, 0.4] |

## Verdict by set

| id | extended / new | extended / legacy | starter truth / new | starter truth / legacy | starter resume claims / new | starter extracted var0 / new | starter extracted var0 / legacy | starter extracted var1 / new | starter extracted var1 / legacy | starter extracted var2 / new | starter extracted var2 / legacy |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A1 | held | not held | inconclusive | not held | held | held | not held | inconclusive | not held | not held | not held |
| A2 | not held | not held | not held | inconclusive | not held | not held | inconclusive | not held | not held | not held | not held |
| A3 | held | held | held | held | held | held | held | held | held | held | held |
| A4 | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A5 | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held |
| A6 | not held | not held | inconclusive | not held | inconclusive | inconclusive | not held | inconclusive | not held | not held | not held |
| A7 | held | held | inconclusive | inconclusive | held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A8 | not held | not held | held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A9 | held | not held | inconclusive | not held | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A10 | not held | not held | not held | inconclusive | inconclusive | inconclusive | not held | inconclusive | not held | inconclusive | not held |
| A11 | not held | not held | not held | not held | inconclusive | not held | not held | inconclusive | not held | not held | not held |
| A12 | held | held | held | held | held | held | held | inconclusive | inconclusive | inconclusive | inconclusive |
| A13 | not held | not held | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive | not held | inconclusive | not held |
| A14 | inconclusive | held | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive | not held | inconclusive | not held |
| A15 | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A16 | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| A17 | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| G1 | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held |
| G2 | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held | not held |
| K1 | inconclusive | not held | inconclusive | inconclusive | inconclusive | held | held | inconclusive | held | held | held |
| K2 | inconclusive | held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| K3 | inconclusive | not held | held | inconclusive | inconclusive | held | held | inconclusive | held | held | held |
| K4 | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive | not held | not held | not held |
| K5 | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive | not held | inconclusive | not held |
| K6 | held | held | held | held | inconclusive | held | held | held | held | held | held |
| K7 | held | held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| K8 | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive | not held | inconclusive | not held |
| K9 | inconclusive | not held | inconclusive | not held | inconclusive | inconclusive | not held | inconclusive | not held | inconclusive | not held |
| K10 | inconclusive | not held | inconclusive | inconclusive | inconclusive | held | held | inconclusive | held | held | held |
| K11 | inconclusive | not held | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| K12 | held | held | held | held | inconclusive | held | inconclusive | held | inconclusive | inconclusive | inconclusive |
| K13 | held | not held | inconclusive | not held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive |
| W1 | held | not held | held | not held | held | not held | not held | not held | not held | not held | not held |
| W2 | held | inconclusive | inconclusive | inconclusive | inconclusive | inconclusive | not held | inconclusive | not held | inconclusive | not held |
| W3 | held | held | held | held | not held | not held | not held | not held | not held | not held | not held |
| W4 | held | held | held | held | held | held | held | held | held | held | held |
| W5 | held | held | held | held | held | held | held | held | held | held | held |
| W6 | not held | not held | not held | not held | not held | held | held | held | held | held | held |

## Humanity white (pooled composite)

| set | red | green | blue | chroma / mean chroma |
|---|---|---|---|---|
| extended / new | 0.269 | 0.376 | 0.355 | 0.948 |
| extended / legacy | 0.050 | 0.507 | 0.443 | 0.956 |
| starter truth / new | 0.269 | 0.375 | 0.357 | 0.951 |
| starter truth / legacy | 0.048 | 0.506 | 0.446 | 0.962 |
| starter resume claims / new | 0.186 | 0.392 | 0.423 | 1.019 |
| starter extracted var0 / new | 0.214 | 0.621 | 0.166 | 1.065 |
| starter extracted var0 / legacy | 0.067 | 0.933 | 0.000 | 1.081 |
| starter extracted var1 / new | 0.215 | 0.620 | 0.166 | 1.066 |
| starter extracted var1 / legacy | 0.067 | 0.933 | 0.000 | 1.081 |
| starter extracted var2 / new | 0.228 | 0.607 | 0.165 | 0.987 |
| starter extracted var2 / legacy | 0.082 | 0.918 | 0.000 | 1.000 |

## Luminance, before and after

Mean image luminance by set; version 1 is the earlier report (earlier tone constant, claimed tier as grain, earlier generator).

| set | mean luminance v1 (min, max) | mean luminance v2 | mean typical level v2 |
|---|---|---|---|
| extended / new | 0.0310 (0.0017, 0.0704) | 0.168 | 0.444 |
| extended / legacy | 0.1321 (0.0162, 0.2233) | 0.132 | 0.197 |
| starter truth / new | 0.0315 (0.0022, 0.0510) | 0.169 | 0.464 |
| starter truth / legacy | 0.1359 (0.0210, 0.1921) | 0.136 | 0.231 |
| starter resume claims / new | 0.0006 (0.0000, 0.0015) | 0.035 | 0.500 |
| starter extracted var0 / new | 0.0006 (0.0000, 0.0019) | 0.025 | 0.493 |
| starter extracted var0 / legacy | 0.0054 (0.0000, 0.0112) | 0.005 | 0.000 |
| starter extracted var1 / new | 0.0006 (0.0000, 0.0024) | 0.024 | 0.482 |
| starter extracted var1 / legacy | 0.0054 (0.0000, 0.0111) | 0.005 | 0.000 |
| starter extracted var2 / new | 0.0003 (0.0000, 0.0014) | 0.016 | 0.280 |
| starter extracted var2 / legacy | 0.0042 (0.0003, 0.0082) | 0.004 | 0.000 |

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
