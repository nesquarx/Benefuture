# Identification ceiling: where the archetype and calibration signal is lost

Question: archetype identification sits near 0.55 to 0.57 and calibration near 0.45 to 0.47 at every resolution. Is the limit the image's
features, the image itself, or the generator's own signal? The same leave-one-out protocol runs on three levels of the same 144 generated personas
(8 archetypes x 3 calibrations x 6 replicates, truth rows, fine evidence): the raw truth rows summarised per persona, the full per-slice channel
levels the image encodes, and the pre-registered summary features. Classifiers: nearest centroid (the battery's) and L2 multinomial logistic regression
whose penalty is chosen by nested cross-validation inside every training fold (grid 0.0001, 0.001, 0.01, 0.1, 1, 10; 4 inner folds;
selection by cross-validated log-loss). Neither a language model nor an image model is run: the personas come from the deterministic generator.

## Predictions (fixed in `tools/identification_ceiling.py` before the first measurement)

Chance is 0.125 for archetype and 0.333 for calibration; the battery's references on the same population are 0.569 and 0.451 (summary features,
nearest centroid). Confidence is the stated probability the prediction holds. Verdict rules: accuracy bounds as the battery's (held if the point value
meets the bound, not held if the Wilson interval lies wholly on the wrong side); paired differences by the interval of the paired difference of correct
flags; rankings by the observed order (one run, no interval).

| id | label | prediction | confidence | what it says |
|---|---|---|---|---|
| A1 | archetype | raw / logistic: at least 0.70 | 0.45 | raw rows identify archetype at least 0.70 (logistic): the rows carry far more than the image shows |
| A2 | archetype | raw/logistic minus summary/centroid at least 0.08 | 0.55 | raw rows beat the summary features' nearest centroid (the battery's 0.57) by at least 0.08: the image or its features lose archetype information |
| A3 | archetype | levels/logistic minus summary/centroid at least 0.04 | 0.55 | the full image levels beat the summary features by at least 0.04: the image carries what the features miss |
| A4 | archetype | summary/logistic and summary/centroid within 0.05 | 0.60 | a stronger classifier on the summary features is within 0.05 of the nearest centroid: the classifier is not the limit |
| A5 | archetype | raw_noage/logistic and raw/logistic within 0.05 | 0.50 | removing age, recency and span from the raw rows moves archetype accuracy by less than 0.05: age is not what raw rows lean on |
| C1 | calibration | raw / logistic: at most 0.55 | 0.60 | raw rows identify calibration at most 0.55 (logistic): the generator's calibration signal is small |
| C2 | calibration | levels / logistic: at most 0.55 | 0.60 | the full image levels identify calibration at most 0.55 (logistic) |
| C3 | calibration | raw/logistic and summary/centroid within 0.08 | 0.50 | raw rows and the summary features differ by less than 0.08 on calibration: the image loses nothing the rows show |
| R1 | archetype | summary/centroid: rank pair | 0.35 | shift worker and small-business owner are among the three most confused pairs on the summary features (shared sectors: hospitality, retail) |
| R2 | archetype | raw/logistic: rank low | 0.60 | generalist or career changer is among the two lowest-recall archetypes on raw rows (no distinctive profile) |
| R3 | archetype | raw/logistic: rank high | 0.50 | student and retiree are the two highest-recall archetypes on raw rows (age range and education) |

## Results

n = 144 personas. Columns per level: raw rows (with age) 1127, raw rows (no age, recency or span) 1124, image levels, coarse rings 1841, image levels, coarse and fine rings 7343, summary features (pre-registered) 41.

### Accuracy, leave one out (Wilson 95% interval)

| level | classifier | archetype | calibration |
|---|---|---|---|
| raw rows (with age) **** | centroid | 0.792 [0.718, 0.850] | 0.312 [0.242, 0.392] |
| raw rows (with age) **** | logistic | 0.778 [0.703, 0.838] | 0.389 [0.313, 0.470] |
| raw rows (no age, recency or span) | centroid | 0.792 [0.718, 0.850] | 0.312 [0.242, 0.392] |
| raw rows (no age, recency or span) | logistic | 0.778 [0.703, 0.838] | 0.389 [0.313, 0.470] |
| image levels, coarse rings **** | centroid | 0.847 [0.780, 0.897] | 0.229 [0.168, 0.304] |
| image levels, coarse rings **** | logistic | 0.847 [0.780, 0.897] | 0.174 [0.120, 0.244] |
| image levels, coarse and fine rings | centroid | 0.826 [0.756, 0.880] | 0.250 [0.186, 0.327] |
| image levels, coarse and fine rings | logistic | 0.861 [0.795, 0.908] | 0.201 [0.144, 0.274] |
| summary features (pre-registered) **** | centroid | 0.569 [0.488, 0.647] | 0.451 [0.372, 0.533] |
| summary features (pre-registered) **** | logistic | 0.576 [0.495, 0.654] | 0.576 [0.495, 0.654] |

Chance 0.125 (archetype) and 0.333 (calibration); majority class 0.125 and 0.333. Levels in bold are the three of the question; the others are controls. Intervals at n=144 are about +-0.08, so differences below that are read through the paired table, not by comparing intervals.

### Paired differences (same personas, difference of accuracy, paired 95% interval, exact sign test)

| label | a | b | a - b [interval] | only a right | only b right | sign p |
|---|---|---|---|---|---|---|
| archetype | raw/logistic | summary/logistic | +0.201 [+0.114, +0.289] | 38 | 9 | 0.000 |
| archetype | levels/logistic | summary/logistic | +0.271 [+0.186, +0.355] | 44 | 5 | 0.000 |
| archetype | raw/logistic | levels/logistic | -0.069 [-0.132, -0.007] | 6 | 16 | 0.052 |
| archetype | levels_fine/logistic | levels/logistic | +0.014 [-0.033, +0.061] | 7 | 5 | 0.774 |
| archetype | raw/logistic | raw/centroid | -0.014 [-0.072, +0.044] | 8 | 10 | 0.815 |
| archetype | levels/logistic | levels/centroid | +0.000 [-0.038, +0.038] | 4 | 4 | 1.000 |
| archetype | summary/logistic | summary/centroid | +0.007 [-0.066, +0.080] | 15 | 14 | 1.000 |
| archetype | raw_noage/logistic | raw/logistic | +0.000 [+0.000, +0.000] | 0 | 0 | 1.000 |
| calibration | raw/logistic | summary/logistic | -0.188 [-0.296, -0.079] | 21 | 48 | 0.002 |
| calibration | levels/logistic | summary/logistic | -0.403 [-0.498, -0.308] | 7 | 65 | 0.000 |
| calibration | raw/logistic | levels/logistic | +0.215 [+0.140, +0.290] | 34 | 3 | 0.000 |
| calibration | levels_fine/logistic | levels/logistic | +0.028 [-0.039, +0.094] | 14 | 10 | 0.541 |
| calibration | raw/logistic | raw/centroid | +0.076 [+0.015, +0.138] | 16 | 5 | 0.027 |
| calibration | levels/logistic | levels/centroid | -0.056 [-0.098, -0.013] | 1 | 9 | 0.021 |
| calibration | summary/logistic | summary/centroid | +0.125 [+0.051, +0.199] | 25 | 7 | 0.002 |
| calibration | raw_noage/logistic | raw/logistic | +0.000 [+0.000, +0.000] | 0 | 0 | 1.000 |

### Predictions against results

| id | confidence | verdict | observed |
|---|---|---|---|
| A1 | 0.45 | held | 0.778 [0.703, 0.838] against 0.7 |
| A2 | 0.55 | held | +0.208 [+0.114, +0.302] against 0.08 |
| A3 | 0.55 | held | +0.278 [+0.189, +0.367] against 0.04 |
| A4 | 0.60 | inconclusive | +0.007 [-0.066, +0.080] against 0.05 |
| A5 | 0.50 | held | +0.000 [+0.000, +0.000] against 0.05 |
| C1 | 0.60 | held | 0.389 [0.313, 0.470] against 0.55 |
| C2 | 0.60 | held | 0.174 [0.120, 0.244] against 0.55 |
| C3 | 0.50 | inconclusive | -0.062 [-0.172, +0.047] against 0.08 |
| R1 | 0.35 | not held | carer/small_business_owner, retiree/generalist, researcher/generalist |
| R2 | 0.60 | held | generalist, retiree |
| R3 | 0.50 | not held | student, researcher |

Held 7, not held 2, inconclusive 2 of 11; the stated confidences expected 5.8 to hold.

### Confusions

Logistic classifier at each of the three levels (rows: truth; columns: predicted, first four letters; diagonal in bold). Pairs list the
unordered pairs by confusions in both directions (a taken for b / b taken for a), for both classifiers.

#### archetype, raw rows (with age), logistic (112/144)

| truth \ predicted | stud | shif | care | smal | rese | reti | care | gene | recall |
|---|---|---|---|---|---|---|---|---|---|
| student | **17** | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0.94 |
| shift_worker | 1 | **15** | 1 | 1 | 0 | 0 | 0 | 0 | 0.83 |
| carer | 0 | 1 | **16** | 0 | 0 | 1 | 0 | 0 | 0.89 |
| small_business_owner | 1 | 3 | 0 | **14** | 0 | 0 | 0 | 0 | 0.78 |
| researcher | 0 | 0 | 0 | 0 | **16** | 0 | 2 | 0 | 0.89 |
| retiree | 0 | 0 | 1 | 2 | 0 | **13** | 1 | 1 | 0.72 |
| career_changer | 0 | 0 | 0 | 1 | 0 | 0 | **14** | 3 | 0.78 |
| generalist | 3 | 1 | 0 | 1 | 1 | 3 | 2 | **7** | 0.39 |

- centroid top pairs: retiree / generalist (0 / 4); student / generalist (0 / 3); student / researcher (0 / 3); retiree / career_changer (1 / 1)
- logistic top pairs: career_changer / generalist (3 / 2); retiree / generalist (1 / 3); shift_worker / small_business_owner (1 / 3); student / generalist (0 / 3)

#### archetype, image levels, coarse rings, logistic (122/144)

| truth \ predicted | stud | shif | care | smal | rese | reti | care | gene | recall |
|---|---|---|---|---|---|---|---|---|---|
| student | **17** | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0.94 |
| shift_worker | 2 | **14** | 1 | 0 | 0 | 0 | 0 | 1 | 0.78 |
| carer | 0 | 0 | **17** | 0 | 0 | 1 | 0 | 0 | 0.94 |
| small_business_owner | 0 | 1 | 0 | **17** | 0 | 0 | 0 | 0 | 0.94 |
| researcher | 0 | 0 | 0 | 0 | **13** | 1 | 0 | 4 | 0.72 |
| retiree | 0 | 0 | 1 | 0 | 0 | **17** | 0 | 0 | 0.94 |
| career_changer | 1 | 0 | 0 | 0 | 0 | 0 | **17** | 0 | 0.94 |
| generalist | 3 | 0 | 0 | 0 | 1 | 4 | 0 | **10** | 0.56 |

- centroid top pairs: researcher / generalist (3 / 2); student / generalist (1 / 3); retiree / generalist (0 / 3); student / shift_worker (1 / 2)
- logistic top pairs: researcher / generalist (4 / 1); retiree / generalist (0 / 4); student / generalist (0 / 3); carer / retiree (1 / 1)

#### archetype, summary features (pre-registered), logistic (83/144)

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

- centroid top pairs: carer / small_business_owner (3 / 4); retiree / generalist (3 / 4); researcher / generalist (3 / 2); shift_worker / carer (4 / 0)
- logistic top pairs: retiree / generalist (5 / 3); carer / small_business_owner (3 / 4); small_business_owner / generalist (2 / 4); student / researcher (2 / 3)

#### calibration, raw rows (with age), logistic (56/144)

| truth \ predicted | over | well | unde | recall |
|---|---|---|---|---|
| over | **21** | 18 | 9 | 0.44 |
| well | 18 | **10** | 20 | 0.21 |
| under | 5 | 18 | **25** | 0.52 |

- centroid top pairs: well / under (22 / 21); over / well (24 / 17); over / under (11 / 4)
- logistic top pairs: well / under (20 / 18); over / well (18 / 18); over / under (9 / 5)

#### calibration, image levels, coarse rings, logistic (25/144)

| truth \ predicted | over | well | unde | recall |
|---|---|---|---|---|
| over | **7** | 24 | 17 | 0.15 |
| well | 23 | **6** | 19 | 0.12 |
| under | 12 | 24 | **12** | 0.25 |

- centroid top pairs: over / well (24 / 20); well / under (18 / 24); over / under (16 / 9)
- logistic top pairs: over / well (24 / 23); well / under (19 / 24); over / under (17 / 12)

#### calibration, summary features (pre-registered), logistic (83/144)

| truth \ predicted | over | well | unde | recall |
|---|---|---|---|---|
| over | **34** | 11 | 3 | 0.71 |
| well | 12 | **19** | 17 | 0.40 |
| under | 4 | 14 | **30** | 0.62 |

- centroid top pairs: well / under (21 / 15); over / well (13 / 16); over / under (7 / 7)
- logistic top pairs: well / under (17 / 14); over / well (11 / 12); over / under (3 / 4)

### Penalty chosen by the nested tuning (logistic; number of leave-one-out folds per C)

| level | label | 0.0001 | 0.001 | 0.01 | 0.1 | 1 | 10 |
|---|---|---|---|---|---|---|---|
| raw rows (with age) | archetype | 0 | 0 | 0 | 144 | 0 | 0 |
| raw rows (with age) | calibration | 0 | 57 | 87 | 0 | 0 | 0 |
| raw rows (no age, recency or span) | archetype | 0 | 0 | 0 | 144 | 0 | 0 |
| raw rows (no age, recency or span) | calibration | 0 | 57 | 87 | 0 | 0 | 0 |
| image levels, coarse rings | archetype | 0 | 0 | 0 | 130 | 14 | 0 |
| image levels, coarse rings | calibration | 78 | 66 | 0 | 0 | 0 | 0 |
| image levels, coarse and fine rings | archetype | 0 | 0 | 0 | 126 | 18 | 0 |
| image levels, coarse and fine rings | calibration | 133 | 11 | 0 | 0 | 0 | 0 |
| summary features (pre-registered) | archetype | 0 | 0 | 0 | 44 | 100 | 0 |
| summary features (pre-registered) | calibration | 0 | 0 | 0 | 144 | 0 | 0 |

### Per-class recall, archetype (logistic)

| archetype | raw | levels | summary |
|---|---|---|---|
| student | 0.94 | 0.94 | 0.67 |
| shift_worker | 0.83 | 0.78 | 0.61 |
| carer | 0.89 | 0.94 | 0.72 |
| small_business_owner | 0.78 | 0.94 | 0.44 |
| researcher | 0.89 | 0.72 | 0.61 |
| retiree | 0.72 | 0.94 | 0.56 |
| career_changer | 0.78 | 0.94 | 0.83 |
| generalist | 0.39 | 0.56 | 0.17 |

## Limits

- 144 personas, 18 per archetype and 48 per calibration: intervals are wide and a single replicate set; the generator's seeds are fixed, so a different draw is not measured here.
- Features are summaries chosen by the author of this run (counts and magnitudes per coarse domain and channel, tier and production shares, ages; the per-slice levels); a better summary of the raw rows, or a different model class, can sit above these numbers. The ceiling reported is a lower bound on what the rows hold.
- Nested tuning chooses one penalty per leave-one-out fold; the reported accuracies are the outer folds' only, never the inner ones.
- Calibration is carried by the predictions of the persona about itself against demonstrated evidence; the raw level includes `pred_minus_demonstrated` for it, the levels and summary levels carry it through the claimed layer.
- Generated data: what the generator puts in is what can come out; a real population adds signal and noise this one does not have.
