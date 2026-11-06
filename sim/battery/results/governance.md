# Failure-boundary battery: governance

Build: commit 102474a (with any uncommitted changes at the time).

Run time 2.3 minutes; 24 random rays; 128 screened worlds (severities up to 1.00), 0% failing.

## Limits along one factor (severity 1 = top of the explored range)

| Factor | Fails beyond |
|---|---|
| signal noise | not within 2 |
| ability scatter | not within 2 |
| hidden outcomes | not within 2 |
| local noise | not within 2 |
| collusion | not within 2 |
| delegation | not within 2 |
| loyalty | not within 2 |

## Importance in screening (mean severity in failing worlds less in converging ones)

| Factor | Importance |
|---|---|
| signal noise | 0.000 |
| ability scatter | 0.000 |
| hidden outcomes | 0.000 |
| local noise | 0.000 |
| collusion | 0.000 |
| delegation | 0.000 |
| loyalty | 0.000 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| local noise × collusion | +0.000 |
| signal noise × ability scatter | +0.000 |
| ability scatter × collusion | +0.000 |
| hidden outcomes × loyalty | +0.000 |
| signal noise × hidden outcomes | +0.000 |
| signal noise × local noise | +0.000 |
| local noise × delegation | +0.000 |
| ability scatter × delegation | +0.000 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | signal noise | ability scatter | hidden outcomes | local noise | collusion | delegation | loyalty | monotone |
|---|---|---|---|---|---|---|---|---|

Non-monotone rays (converging again beyond the boundary): 0 of 24.

## Failure boxes (PRIM over the screened worlds)

No failing world, so no box.

## Continuous methods (run time 4.1 minutes)

Readings: the share of the last half of decisions right, less 0.75 (the margin), averaged over seeds 1, 2, … until its standard error (Student-t inflated) is within 0.02 (3 to 8 seeds).

### Variance-based sensitivity (Sobol indices; severities uniform in [0, 1.00])

Saltelli et al. (2010) design, 576 evaluations; 95% bootstrap intervals. S1: the share of the reading's variance a factor explains alone; ST: with all its interactions. ST well above S1 marks a factor acting through interactions; variance the seeds add is in no factor's S1. Seeds per world: mean 3.0, 2 of 576 worlds at the cap.

| Factor | S1 (margin) | ST (margin) |
|---|---|---|
| signal noise | 0.19 [-8.62, 9.61] | 0.48 [0.31, 0.68] |
| ability scatter | 0.92 [-8.06, 9.52] | 0.47 [0.32, 0.66] |
| collusion | 1.48 [-5.88, 9.37] | 0.35 [0.22, 0.52] |
| hidden outcomes | -3.75 [-11.09, 3.12] | 0.24 [0.14, 0.37] |
| local noise | 0.78 [-6.11, 6.00] | 0.22 [0.14, 0.30] |
| delegation | 0.36 [-4.98, 5.34] | 0.14 [0.09, 0.20] |
| loyalty | 2.86 [-0.23, 6.19] | 0.05 [0.03, 0.09] |

Sum of first-order indices (margin): 2.85; variance of the margin: 3.39e-05.

### Active learning of the failure boundary (AK-MCS)

A Gaussian-process surrogate of the margin chose 10 of 2000 candidate worlds (drawn as the screening's), each where its sign was least certain (Echard, Gayton & Lemaire 2011). Estimated failing share of the candidates: 0.0% (screening: 0.0%). Seeds per world: mean 3.0, 10 of 10 worlds at the cap.

#### Failure boxes (PRIM over the surrogate's verdict on the candidates)

No failing world, so no box.

Evaluated worlds nearest the boundary (smallest |margin|):

| margin | signal noise | ability scatter | hidden outcomes | local noise | collusion | delegation | loyalty |
|---|---|---|---|---|---|---|---|
| +0.22 | 1.02 | 0.67 | 0.99 | 0.69 | 0.78 | 0.38 | 0.23 |
| +0.23 | 0.33 | 0.35 | 0.47 | 0.57 | 0.97 | 0.55 | 0.62 |
| +0.23 | 0.72 | 0.28 | 0.27 | 0.25 | 0.57 | 0.51 | 0.53 |
| +0.23 | 0.35 | 0.05 | 0.66 | 0.69 | 0.40 | 0.67 | 0.92 |
| +0.23 | 0.76 | 0.73 | 0.29 | 0.63 | 0.61 | 0.26 | 0.78 |
| +0.23 | 0.38 | 0.77 | 0.37 | 0.25 | 0.00 | 0.51 | 0.42 |
| +0.24 | 0.12 | 0.71 | 0.27 | 0.34 | 0.46 | 0.82 | 0.44 |
| +0.24 | 0.34 | 0.79 | 0.72 | 0.48 | 0.20 | 0.44 | 0.59 |

## Continuous methods (run time 23.7 minutes)

Readings: the share of the last half of decisions right, less 0.75 (the margin), averaged over seeds 1, 2, … until its standard error (Student-t inflated) is within 0.02 (3 to 8 seeds).

### Variance-based sensitivity (Sobol indices; severities uniform in [0, 1.00])

Saltelli et al. (2010) design, 576 evaluations; 95% bootstrap intervals. S1: the share of the reading's variance a factor explains alone; ST: with all its interactions. ST well above S1 marks a factor acting through interactions; variance the seeds add is in no factor's S1. Seeds per world: mean 3.0, 1 of 576 worlds at the cap.

| Factor | S1 (margin) | ST (margin) |
|---|---|---|
| signal noise | 1.84 [-8.18, 11.51] | 0.54 [0.32, 0.76] |
| ability scatter | 4.73 [-4.34, 15.76] | 0.47 [0.38, 0.64] |
| local noise | 3.34 [-3.31, 10.00] | 0.26 [0.17, 0.37] |
| hidden outcomes | 1.58 [-5.30, 7.90] | 0.17 [0.12, 0.24] |
| delegation | 3.70 [-2.49, 9.73] | 0.17 [0.10, 0.25] |
| collusion | 1.91 [-4.41, 7.71] | 0.16 [0.10, 0.27] |
| loyalty | 0.63 [-3.06, 3.86] | 0.06 [0.03, 0.11] |

Sum of first-order indices (margin): 17.73; variance of the margin: 3.29e-05.

### Active learning of the failure boundary (AK-MCS)

A Gaussian-process surrogate of the margin chose 10 of 2000 candidate worlds (drawn as the screening's), each where its sign was least certain (Echard, Gayton & Lemaire 2011). Estimated failing share of the candidates: 0.0% (screening: 0.0%). Seeds per world: mean 3.0, 10 of 10 worlds at the cap.

#### Failure boxes (PRIM over the surrogate's verdict on the candidates)

No failing world, so no box.

Evaluated worlds nearest the boundary (smallest |margin|):

| margin | signal noise | ability scatter | hidden outcomes | local noise | collusion | delegation | loyalty |
|---|---|---|---|---|---|---|---|
| +0.23 | 0.52 | 0.14 | 0.56 | 0.66 | 0.81 | 0.10 | 0.20 |
| +0.23 | 0.61 | 0.41 | 0.19 | 0.42 | 0.71 | 0.92 | 0.28 |
| +0.23 | 0.81 | 0.21 | 0.60 | 0.88 | 0.17 | 0.28 | 1.00 |
| +0.23 | 0.59 | 0.43 | 0.19 | 0.64 | 0.54 | 0.41 | 0.18 |
| +0.23 | 0.47 | 0.52 | 0.47 | 0.43 | 0.47 | 0.81 | 0.72 |
| +0.23 | 0.40 | 0.55 | 0.54 | 0.23 | 0.44 | 0.61 | 0.29 |
| +0.23 | 0.24 | 0.40 | 0.38 | 0.67 | 0.25 | 0.98 | 0.48 |
| +0.23 | 0.86 | 0.70 | 0.86 | 1.06 | 0.65 | 0.32 | 0.50 |
