# Characterisation v3: report

Predictions registered in `characterisation_signatures_v3.json` (hash-pinned, committed before any measurement) evaluated on three populations: the 144 extended personas on truth rows, the same personas under the legacy projection, and the 40 starter personas on rows extracted from resume texts (three variants, each leave-one-out within its variant, pooled to 120 persona-variants). The v3 feature set is the image's per-domain solid levels, red grain share and tier saturation (coarse rings) reduced by PCA (k = 20, fitted inside every training fold and every inner fold of the penalty search, labels never read) plus the v2 summary features. Classifiers: nearest centroid and L2 logistic regression with nested cross-validation. No language or image model was run. Predictions are not edited after measurement.

## Accuracy (leave one out, Wilson 95% interval)

### extended / new (truth rows) (n = 144)

| feature set | columns (raw, after reduction) | classifier | archetype | calibration |
|---|---|---|---|---|
| v2 | 41, 41 | centroid | 0.569 [0.488, 0.647] | 0.451 [0.372, 0.533] |
| v2 | 41, 41 | logistic | 0.576 [0.495, 0.654] | 0.576 [0.495, 0.654] |
| v3 | 1356, 61 | centroid | 0.792 [0.718, 0.850] | 0.424 [0.346, 0.505] |
| v3 | 1356, 61 | logistic | 0.785 [0.711, 0.844] | 0.542 [0.460, 0.621] |
| v3_L | 1356, 61 | centroid | 0.764 [0.688, 0.826] | 0.438 [0.359, 0.519] |
| v3_L | 1356, 61 | logistic | 0.757 [0.681, 0.820] | 0.535 [0.453, 0.614] |
| v3_GT | 1356, 61 | centroid | 0.778 [0.703, 0.838] | 0.458 [0.379, 0.540] |
| v3_GT | 1356, 61 | logistic | 0.750 [0.673, 0.814] | 0.514 [0.433, 0.594] |
| v3_pca | 1315, 20 | centroid | 0.819 [0.749, 0.874] | 0.257 [0.193, 0.334] |
| v3_pca | 1315, 20 | logistic | 0.854 [0.787, 0.903] | 0.167 [0.115, 0.236] |
| v3_k10 (exploratory) | 1356, 51 | centroid | 0.778 [0.703, 0.838] | 0.396 [0.320, 0.477] |
| v3_k10 (exploratory) | 1356, 51 | logistic | 0.799 [0.726, 0.856] | 0.556 [0.474, 0.634] |
| v3_k40 (exploratory) | 1356, 81 | centroid | 0.819 [0.749, 0.874] | 0.389 [0.313, 0.470] |
| v3_k40 (exploratory) | 1356, 81 | logistic | 0.806 [0.733, 0.862] | 0.472 [0.392, 0.553] |

Chance 0.125 (archetype) and 0.333 (calibration); majority class 0.125 and 0.333.

### extended / legacy (n = 144)

| feature set | columns (raw, after reduction) | classifier | archetype | calibration |
|---|---|---|---|---|
| v2 | 41, 41 | centroid | 0.549 [0.467, 0.628] | 0.410 [0.333, 0.491] |
| v2 | 41, 41 | logistic | 0.604 [0.523, 0.680] | 0.472 [0.392, 0.553] |
| v3 | 1356, 61 | centroid | 0.771 [0.696, 0.832] | 0.382 [0.307, 0.463] |
| v3 | 1356, 61 | logistic | 0.812 [0.741, 0.868] | 0.431 [0.353, 0.512] |
| v3_L | 1356, 61 | centroid | 0.722 [0.644, 0.789] | 0.347 [0.274, 0.428] |
| v3_L | 1356, 61 | logistic | 0.799 [0.726, 0.856] | 0.431 [0.353, 0.512] |
| v3_GT | 1356, 61 | centroid | 0.681 [0.601, 0.751] | 0.354 [0.281, 0.435] |
| v3_GT | 1356, 61 | logistic | 0.750 [0.673, 0.814] | 0.382 [0.307, 0.463] |
| v3_pca | 1315, 20 | centroid | 0.833 [0.764, 0.885] | 0.264 [0.199, 0.341] |
| v3_pca | 1315, 20 | logistic | 0.819 [0.749, 0.874] | 0.000 [0.000, 0.026] |

Chance 0.125 (archetype) and 0.333 (calibration); majority class 0.125 and 0.333.

### starter extracted, three variants pooled / new (n = 120)

| feature set | columns (raw, after reduction) | classifier | archetype | calibration |
|---|---|---|---|---|
| v2 | 41, 41 | centroid | 0.200 [0.138, 0.280] | 0.425 [0.340, 0.514] |
| v2 | 41, 41 | logistic | 0.100 [0.058, 0.167] | 0.517 [0.428, 0.604] |
| v3 | 1356, 61 | centroid | 0.233 [0.167, 0.317] | 0.425 [0.340, 0.514] |
| v3 | 1356, 61 | logistic | 0.192 [0.131, 0.271] | 0.442 [0.356, 0.531] |
| v3_L | 1356, 61 | centroid | 0.233 [0.167, 0.317] | 0.450 [0.364, 0.539] |
| v3_L | 1356, 61 | logistic | 0.183 [0.124, 0.262] | 0.400 [0.317, 0.489] |
| v3_GT | 1356, 61 | centroid | 0.217 [0.152, 0.299] | 0.483 [0.396, 0.572] |
| v3_GT | 1356, 61 | logistic | 0.183 [0.124, 0.262] | 0.475 [0.388, 0.564] |
| v3_pca | 1315, 20 | centroid | 0.317 [0.240, 0.404] | 0.417 [0.332, 0.506] |
| v3_pca | 1315, 20 | logistic | 0.275 [0.203, 0.361] | 0.383 [0.301, 0.473] |

Chance 0.125 (archetype) and 0.333 (calibration); majority class 0.125 and 0.400.

## Paired differences against v2 (same personas)

Difference of accuracy a - b, 95% interval of the paired difference (clustered by persona, Student-t, for the extracted set), exact sign test (extracted: on the persona-level sign). Only a / only b: units where only a (b) is right.

| set | label | a | b | a - b [interval] | only a | only b | sign p |
|---|---|---|---|---|---|---|---|
| truth | archetype | v3/logistic | v2/logistic | +0.208 [+0.137, +0.280] | 32 | 2 | 0.000 |
| truth | archetype | v3/logistic | v2/centroid | +0.215 [+0.136, +0.295] | 36 | 5 | 0.000 |
| truth | archetype | v3/centroid | v2/centroid | +0.222 [+0.149, +0.295] | 34 | 2 | 0.000 |
| truth | archetype | v3_L/logistic | v2/logistic | +0.181 [+0.107, +0.254] | 30 | 4 | 0.000 |
| truth | archetype | v3_GT/logistic | v2/logistic | +0.174 [+0.101, +0.246] | 29 | 4 | 0.000 |
| truth | calibration | v3/logistic | v2/logistic | -0.035 [-0.097, +0.027] | 8 | 13 | 0.383 |
| truth | calibration | v3/logistic | v2/centroid | +0.090 [+0.007, +0.174] | 26 | 13 | 0.053 |
| truth | calibration | v3/centroid | v2/centroid | -0.028 [-0.082, +0.026] | 6 | 10 | 0.455 |
| truth | calibration | v3_L/logistic | v2/logistic | -0.042 [-0.102, +0.019] | 7 | 13 | 0.263 |
| truth | calibration | v3_GT/logistic | v2/logistic | -0.062 [-0.124, -0.001] | 6 | 15 | 0.078 |
| legacy | archetype | v3/logistic | v2/logistic | +0.208 [+0.134, +0.283] | 33 | 3 | 0.000 |
| legacy | archetype | v3/logistic | v2/centroid | +0.264 [+0.176, +0.352] | 45 | 7 | 0.000 |
| legacy | archetype | v3/centroid | v2/centroid | +0.222 [+0.152, +0.293] | 33 | 1 | 0.000 |
| legacy | archetype | v3_L/logistic | v2/logistic | +0.194 [+0.124, +0.265] | 30 | 2 | 0.000 |
| legacy | archetype | v3_GT/logistic | v2/logistic | +0.146 [+0.074, +0.218] | 26 | 5 | 0.000 |
| legacy | calibration | v3/logistic | v2/logistic | -0.042 [-0.108, +0.025] | 9 | 15 | 0.307 |
| legacy | calibration | v3/logistic | v2/centroid | +0.021 [-0.060, +0.101] | 19 | 16 | 0.736 |
| legacy | calibration | v3/centroid | v2/centroid | -0.028 [-0.075, +0.019] | 4 | 8 | 0.388 |
| legacy | calibration | v3_L/logistic | v2/logistic | -0.042 [-0.111, +0.027] | 10 | 16 | 0.327 |
| legacy | calibration | v3_GT/logistic | v2/logistic | -0.090 [-0.162, -0.018] | 8 | 21 | 0.024 |
| extracted | archetype | v3/logistic | v2/logistic | +0.092 [+0.019, +0.164] | 7 | 0 | 0.016 |
| extracted | archetype | v3/logistic | v2/centroid | -0.008 [-0.038, +0.021] | 1 | 2 | 1.000 |
| extracted | archetype | v3/centroid | v2/centroid | +0.033 [-0.007, +0.074] | 5 | 1 | 0.219 |
| extracted | archetype | v3_L/logistic | v2/logistic | +0.083 [+0.016, +0.151] | 7 | 0 | 0.016 |
| extracted | archetype | v3_GT/logistic | v2/logistic | +0.083 [+0.021, +0.146] | 8 | 0 | 0.008 |
| extracted | calibration | v3/logistic | v2/logistic | -0.075 [-0.149, -0.001] | 2 | 10 | 0.039 |
| extracted | calibration | v3/logistic | v2/centroid | +0.017 [-0.118, +0.151] | 12 | 11 | 1.000 |
| extracted | calibration | v3/centroid | v2/centroid | +0.000 [-0.076, +0.076] | 3 | 6 | 0.508 |
| extracted | calibration | v3_L/logistic | v2/logistic | -0.117 [-0.215, -0.018] | 4 | 13 | 0.049 |
| extracted | calibration | v3_GT/logistic | v2/logistic | -0.042 [-0.097, +0.013] | 2 | 6 | 0.289 |

## Predictions against results

| id | confidence | verdict | observed | prediction |
|---|---|---|---|---|
| A1 | 0.60 | **held** | 0.785 [0.711, 0.844] against 0.75 | v3 features identify archetype from truth rows at least 0.75 (logistic): the image's levels, reduced, keep the signal the summary features lose |
| A2 | 0.65 | **held** | +0.208 [+0.137, +0.280] against 0.15 | v3 beats v2 (same classifier, logistic) on archetype by at least 0.15 |
| A3 | 0.65 | **held** | +0.215 [+0.136, +0.295] against 0.15 | v3 (logistic) beats the battery's v2 nearest centroid on archetype by at least 0.15 |
| A4 | 0.70 | **not held** | +0.007 [-0.058, +0.072] against 0.1 | levels carry archetype, grain and tier do not: v3_L minus v3_GT (logistic) is at least 0.10 |
| A5 | 0.55 | **held** | +0.222 [+0.149, +0.295] against 0.1 | the reduction helps the nearest centroid too: v3 minus v2 (centroid) is at least 0.10 |
| C1 | 0.35 | **inconclusive** | 0.542 [0.460, 0.621] against 0.6 | v3 features identify calibration from truth rows at least 0.60 (logistic) |
| C2 | 0.35 | **not held** | -0.035 [-0.097, +0.027] against 0.04 | per-domain grain share and tier saturation add to the global grain share: v3 minus v2 (logistic) on calibration is at least 0.04 |
| C3 | 0.45 | **not held** | -0.021 [-0.080, +0.038] against 0.04 | adding the grain and tier block to the summary features beats adding the levels block: v3_GT minus v3_L (logistic) on calibration is at least 0.04 |
| C4 | 0.45 | **inconclusive** | +0.007 [-0.034, +0.048] against 0.04 | the full v3 beats v3_L (logistic) on calibration by at least 0.04: the grain and tier block is what calibration needs |
| C5 | 0.50 | **held** | 0.167 [0.115, 0.236] against 0.55 | the reduced image blocks alone (v3_pca, without the summary features) identify calibration at most 0.55 (logistic) |
| X1 | 0.40 | **held** | +0.092 [+0.019, +0.164] against 0.05 | on rows extracted from resume texts, v3 beats v2 (logistic) on archetype by at least 0.05 |
| X2 | 0.40 | **not held** | 0.192 [0.131, 0.271] against 0.3 | on extracted rows v3 identifies archetype at least 0.30 (logistic; the v2 battery reads about 0.2) |
| X3 | 0.30 | **not held** | -0.075 [-0.149, -0.001] against 0.04 | on extracted rows v3 beats v2 (logistic) on calibration by at least 0.04 |
| L1 | 0.60 | **held** | +0.208 [+0.134, +0.283] against 0.15 | on the legacy projection v3 beats v2 (logistic) on archetype by at least 0.15: the legacy image still draws the levels |
| L2 | 0.50 | **held** | +0.111 [+0.021, +0.202] against 0.05 | the legacy projection has no tier saturation, so calibration drops: truth minus legacy for v3 (logistic) is at least 0.05 |
| L3 | 0.60 | **held** | 0.431 [0.353, 0.512] against 0.55 | on the legacy projection v3 identifies calibration at most 0.55 (logistic) |
| R1 | 0.55 | **held** | generalist 0.33, shift_worker 0.72 | generalist is among the two lowest-recall archetypes for v3 (logistic) on truth rows (no distinctive profile) |
| R2 | 0.50 | **held** | well 0.33 | well calibrated is the lowest-recall calibration class for v3 (logistic) on truth rows (the middle class is confused with both sides) |

Held 11, not held 5, inconclusive 2 of 18; the stated confidences expected 9.1 to hold.

## Confusion matrices (logistic; rows truth, columns predicted, first four letters)

#### extended / new (truth rows), archetype, v2 (83/144)

| truth \ predicted | stud | shif | care | smal | rese | reti | care | gene | recall |
|---|---|---|---|---|---|---|---|---|---|
| student | **12** | 2 | 1 | 0 | 2 | 0 | 0 | 1 | 0.67 |
| shift_worker | 1 | **11** | 2 | 2 | 0 | 1 | 0 | 1 | 0.61 |
| carer | 0 | 0 | **13** | 3 | 0 | 1 | 0 | 1 | 0.72 |
| small_business_owner | 0 | 0 | 4 | **8** | 2 | 2 | 0 | 2 | 0.44 |
| researcher | 3 | 0 | 1 | 1 | **11** | 0 | 0 | 2 | 0.61 |
| retiree | 0 | 1 | 0 | 0 | 1 | **10** | 1 | 5 | 0.56 |
| career_changer | 0 | 0 | 0 | 0 | 1 | 1 | **15** | 1 | 0.83 |
| generalist | 3 | 1 | 1 | 4 | 1 | 3 | 2 | **3** | 0.17 |

- top pairs: retiree / generalist (5 / 3); carer / small_business_owner (3 / 4); small_business_owner / generalist (2 / 4); student / researcher (2 / 3)

#### extended / new (truth rows), archetype, v3 (113/144)

| truth \ predicted | stud | shif | care | smal | rese | reti | care | gene | recall |
|---|---|---|---|---|---|---|---|---|---|
| student | **13** | 1 | 0 | 0 | 0 | 0 | 0 | 4 | 0.72 |
| shift_worker | 1 | **13** | 2 | 0 | 0 | 1 | 0 | 1 | 0.72 |
| carer | 0 | 0 | **16** | 1 | 0 | 1 | 0 | 0 | 0.89 |
| small_business_owner | 0 | 1 | 0 | **17** | 0 | 0 | 0 | 0 | 0.94 |
| researcher | 1 | 0 | 0 | 0 | **16** | 0 | 0 | 1 | 0.89 |
| retiree | 0 | 0 | 0 | 0 | 0 | **16** | 1 | 1 | 0.89 |
| career_changer | 0 | 0 | 0 | 0 | 1 | 1 | **16** | 0 | 0.89 |
| generalist | 3 | 0 | 0 | 3 | 2 | 3 | 1 | **6** | 0.33 |

- top pairs: student / generalist (4 / 3); retiree / generalist (1 / 3); researcher / generalist (1 / 2); small_business_owner / generalist (0 / 3)

#### extended / new (truth rows), calibration, v2 (83/144)

| truth \ predicted | over | well | unde | recall |
|---|---|---|---|---|
| over | **34** | 11 | 3 | 0.71 |
| well | 12 | **19** | 17 | 0.40 |
| under | 4 | 14 | **30** | 0.62 |

- top pairs: well / under (17 / 14); over / well (11 / 12); over / under (3 / 4)

#### extended / new (truth rows), calibration, v3 (78/144)

| truth \ predicted | over | well | unde | recall |
|---|---|---|---|---|
| over | **33** | 13 | 2 | 0.69 |
| well | 17 | **16** | 15 | 0.33 |
| under | 4 | 15 | **29** | 0.60 |

- top pairs: over / well (13 / 17); well / under (15 / 15); over / under (2 / 4)

#### extended / legacy, archetype, v2 (87/144)

| truth \ predicted | stud | shif | care | smal | rese | reti | care | gene | recall |
|---|---|---|---|---|---|---|---|---|---|
| student | **13** | 2 | 0 | 0 | 0 | 0 | 0 | 3 | 0.72 |
| shift_worker | 2 | **11** | 1 | 1 | 0 | 0 | 1 | 2 | 0.61 |
| carer | 0 | 0 | **12** | 3 | 1 | 0 | 0 | 2 | 0.67 |
| small_business_owner | 0 | 0 | 2 | **12** | 1 | 1 | 1 | 1 | 0.67 |
| researcher | 0 | 0 | 1 | 3 | **12** | 0 | 0 | 2 | 0.67 |
| retiree | 0 | 0 | 0 | 1 | 1 | **12** | 2 | 2 | 0.67 |
| career_changer | 0 | 1 | 1 | 0 | 1 | 0 | **12** | 3 | 0.67 |
| generalist | 1 | 3 | 2 | 2 | 1 | 3 | 3 | **3** | 0.17 |

- top pairs: career_changer / generalist (3 / 3); carer / small_business_owner (3 / 2); retiree / generalist (2 / 3); shift_worker / generalist (2 / 3)

#### extended / legacy, archetype, v3 (117/144)

| truth \ predicted | stud | shif | care | smal | rese | reti | care | gene | recall |
|---|---|---|---|---|---|---|---|---|---|
| student | **13** | 2 | 0 | 0 | 0 | 0 | 0 | 3 | 0.72 |
| shift_worker | 1 | **14** | 1 | 1 | 0 | 0 | 1 | 0 | 0.78 |
| carer | 0 | 0 | **16** | 1 | 0 | 1 | 0 | 0 | 0.89 |
| small_business_owner | 0 | 1 | 0 | **17** | 0 | 0 | 0 | 0 | 0.94 |
| researcher | 0 | 0 | 0 | 0 | **18** | 0 | 0 | 0 | 1.00 |
| retiree | 0 | 0 | 0 | 0 | 1 | **15** | 2 | 0 | 0.83 |
| career_changer | 0 | 0 | 0 | 0 | 0 | 1 | **16** | 1 | 0.89 |
| generalist | 1 | 1 | 0 | 0 | 2 | 4 | 2 | **8** | 0.44 |

- top pairs: retiree / generalist (0 / 4); student / generalist (3 / 1); career_changer / generalist (1 / 2); retiree / career_changer (2 / 1)

#### extended / legacy, calibration, v2 (68/144)

| truth \ predicted | over | well | unde | recall |
|---|---|---|---|---|
| over | **27** | 16 | 5 | 0.56 |
| well | 17 | **15** | 16 | 0.31 |
| under | 8 | 14 | **26** | 0.54 |

- top pairs: over / well (16 / 17); well / under (16 / 14); over / under (5 / 8)

#### extended / legacy, calibration, v3 (62/144)

| truth \ predicted | over | well | unde | recall |
|---|---|---|---|---|
| over | **27** | 15 | 6 | 0.56 |
| well | 22 | **11** | 15 | 0.23 |
| under | 11 | 13 | **24** | 0.50 |

- top pairs: over / well (15 / 22); well / under (15 / 13); over / under (6 / 11)

#### starter extracted, three variants pooled / new, archetype, v2 (12/120)

| truth \ predicted | stud | shif | care | smal | rese | reti | care | gene | recall |
|---|---|---|---|---|---|---|---|---|---|
| student | **9** | 0 | 1 | 0 | 5 | 0 | 0 | 0 | 0.60 |
| shift_worker | 1 | **3** | 4 | 2 | 1 | 2 | 0 | 2 | 0.20 |
| carer | 0 | 3 | **0** | 1 | 2 | 6 | 2 | 1 | 0.00 |
| small_business_owner | 0 | 4 | 0 | **0** | 2 | 1 | 0 | 8 | 0.00 |
| researcher | 3 | 0 | 2 | 3 | **0** | 4 | 2 | 1 | 0.00 |
| retiree | 0 | 2 | 2 | 4 | 3 | **0** | 0 | 4 | 0.00 |
| career_changer | 0 | 0 | 3 | 0 | 4 | 4 | **0** | 4 | 0.00 |
| generalist | 2 | 0 | 1 | 6 | 0 | 2 | 4 | **0** | 0.00 |

- top pairs: small_business_owner / generalist (8 / 6); career_changer / generalist (4 / 4); carer / retiree (6 / 2); student / researcher (5 / 3)

#### starter extracted, three variants pooled / new, archetype, v3 (23/120)

| truth \ predicted | stud | shif | care | smal | rese | reti | care | gene | recall |
|---|---|---|---|---|---|---|---|---|---|
| student | **9** | 0 | 1 | 0 | 5 | 0 | 0 | 0 | 0.60 |
| shift_worker | 0 | **7** | 3 | 0 | 1 | 0 | 0 | 4 | 0.47 |
| carer | 1 | 3 | **0** | 0 | 3 | 3 | 0 | 5 | 0.00 |
| small_business_owner | 0 | 3 | 0 | **4** | 3 | 2 | 0 | 3 | 0.27 |
| researcher | 3 | 0 | 3 | 0 | **1** | 5 | 2 | 1 | 0.07 |
| retiree | 0 | 1 | 3 | 1 | 3 | **2** | 0 | 5 | 0.13 |
| career_changer | 0 | 0 | 2 | 0 | 5 | 4 | **0** | 4 | 0.00 |
| generalist | 3 | 1 | 1 | 3 | 1 | 2 | 4 | **0** | 0.00 |

- top pairs: career_changer / generalist (4 / 4); researcher / retiree (5 / 3); student / researcher (5 / 3); researcher / career_changer (2 / 5)

#### starter extracted, three variants pooled / new, calibration, v2 (62/120)

| truth \ predicted | over | well | unde | recall |
|---|---|---|---|---|
| over | **38** | 9 | 1 | 0.79 |
| well | 19 | **20** | 3 | 0.48 |
| under | 10 | 16 | **4** | 0.13 |

- top pairs: over / well (9 / 19); well / under (3 / 16); over / under (1 / 10)

#### starter extracted, three variants pooled / new, calibration, v3 (53/120)

| truth \ predicted | over | well | unde | recall |
|---|---|---|---|---|
| over | **38** | 9 | 1 | 0.79 |
| well | 23 | **15** | 4 | 0.36 |
| under | 17 | 13 | **0** | 0.00 |

- top pairs: over / well (9 / 23); over / under (1 / 17); well / under (4 / 13)

## Penalty chosen by the nested search (logistic, truth rows; leave-one-out folds per C)

| feature set | label | 0.0001 | 0.001 | 0.01 | 0.1 | 1 | 10 |
|---|---|---|---|---|---|---|---|
| v2 | archetype | 0 | 0 | 0 | 44 | 100 | 0 |
| v2 | calibration | 0 | 0 | 0 | 144 | 0 | 0 |
| v3 | archetype | 0 | 0 | 0 | 0 | 144 | 0 |
| v3 | calibration | 0 | 0 | 0 | 144 | 0 | 0 |
| v3_L | archetype | 0 | 0 | 0 | 0 | 144 | 0 |
| v3_L | calibration | 0 | 0 | 0 | 144 | 0 | 0 |
| v3_GT | archetype | 0 | 0 | 0 | 0 | 144 | 0 |
| v3_GT | calibration | 0 | 0 | 0 | 144 | 0 | 0 |
| v3_pca | archetype | 0 | 0 | 0 | 0 | 144 | 0 |
| v3_pca | calibration | 1 | 47 | 96 | 0 | 0 | 0 |
| v3_k10 | archetype | 0 | 0 | 0 | 0 | 144 | 0 |
| v3_k10 | calibration | 0 | 0 | 0 | 144 | 0 | 0 |
| v3_k40 | archetype | 0 | 0 | 0 | 0 | 144 | 0 |
| v3_k40 | calibration | 0 | 0 | 70 | 74 | 0 | 0 |

## v2 signatures re-evaluated unchanged

The v2 identification predictions (I1 to I6) and the 38 signatures, evaluated with the v2 battery's code and the unchanged v2 file on the same personas as this report (current generator and code, fine evidence).

| id | set | label | prediction | accuracy | verdict |
|---|---|---|---|---|---|
| I1 | extended / new | archetype | at least 0.60 | 0.569 [0.488, 0.647] (n=144) | inconclusive |
| I2 | extended / new | calibration | at least 0.45 | 0.451 [0.372, 0.533] (n=144) | held |
| I3 | starter extracted (var0, var1, var2) / new | archetype | at least 0.25 | 0.200 [0.138, 0.280] (n=120) | inconclusive |
| I4 | starter extracted (var0, var1, var2) / new | calibration | at least 0.40 | 0.425 [0.340, 0.514] (n=120) | held |
| I5 | extended / legacy | archetype | at most 0.62 | 0.549 [0.467, 0.628] (n=144) | held |
| I6 | extended / legacy | calibration | at most 0.40 | 0.410 [0.333, 0.491] (n=144) | inconclusive |

| set | held | not held | inconclusive | committed v2 report (held / not held / inconclusive) |
|---|---|---|---|---|
| extended / legacy | 9 | 22 | 7 | 11/23/4 |
| extended / new | 12 | 11 | 15 | 14/10/14 |

## Limits

- 144 personas: intervals of about +-0.08; the extracted set is 40 personas read three ways (120 persona-variants, not independent), so its intervals are clustered by persona.
- One reduction size (k = 20) was registered; k = 10 and 40 are exploratory sensitivity on truth rows.
- The summary features are carried unreduced, so a v3 gain is from the reduced image blocks.
- Generated data: what the generator puts in is what can come out; no real population is measured here.
- No multiplicity adjustment; each prediction is read on its own.

