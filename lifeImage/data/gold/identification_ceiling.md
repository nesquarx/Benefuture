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
