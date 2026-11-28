# Failure-boundary battery: governance

Build: commit 4ef9182 (with any uncommitted changes at the time).

Run time 3.4 minutes; 24 random rays; 128 screened worlds (severities up to 1.00), 0% failing.

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
| ability scatter × delegation | +0.000 |
| signal noise × delegation | +0.000 |
| ability scatter × collusion | +0.000 |
| hidden outcomes × delegation | +0.000 |
| local noise × delegation | +0.000 |
| signal noise × ability scatter | +0.000 |
| signal noise × hidden outcomes | +0.000 |
| hidden outcomes × local noise | +0.000 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | signal noise | ability scatter | hidden outcomes | local noise | collusion | delegation | loyalty | monotone |
|---|---|---|---|---|---|---|---|---|

Non-monotone rays (converging again beyond the boundary): 0 of 24.

## Failure boxes (PRIM over the screened worlds)

No failing world, so no box.

## Continuous methods (run time 5.1 minutes)

Readings: the share of the last half of decisions right, less 0.75 (the margin), averaged over seeds 1, 2, … until its standard error (Student-t inflated) is within 0.02 (3 to 8 seeds).

### Variance-based sensitivity (Sobol indices; severities uniform in [0, 1.00])

Saltelli et al. (2010) design, 576 evaluations; 95% bootstrap intervals. S1: the share of the reading's variance a factor explains alone; ST: with all its interactions. ST well above S1 marks a factor acting through interactions; variance the seeds add is in no factor's S1. Seeds per world: mean 3.0, 576 of 576 worlds at the cap.

| Factor | S1 (margin) | ST (margin) |
|---|---|---|
| signal noise | 0.05 [-12.33, 10.72] | 0.74 [0.47, 1.05] |
| collusion | -1.72 [-9.84, 6.68] | 0.35 [0.22, 0.54] |
| ability scatter | -0.68 [-8.73, 8.30] | 0.35 [0.24, 0.50] |
| hidden outcomes | -3.27 [-10.67, 2.34] | 0.22 [0.09, 0.38] |
| delegation | 0.98 [-4.87, 6.06] | 0.14 [0.07, 0.27] |
| local noise | -0.44 [-5.77, 4.26] | 0.14 [0.08, 0.23] |
| loyalty | -0.06 [-3.49, 3.43] | 0.06 [0.03, 0.12] |

Sum of first-order indices (margin): -5.13; variance of the margin: 3.45e-05.

### Active learning of the failure boundary (AK-MCS)

A Gaussian-process surrogate of the margin chose 10 of 2000 candidate worlds (drawn as the screening's), each where its sign was least certain (Echard, Gayton & Lemaire 2011). Estimated failing share of the candidates: 0.0% (screening: 0.0%). Seeds per world: mean 3.0, 10 of 10 worlds at the cap.

#### Failure boxes (PRIM over the surrogate's verdict on the candidates)

No failing world, so no box.

Evaluated worlds nearest the boundary (smallest |margin|):

| margin | signal noise | ability scatter | hidden outcomes | local noise | collusion | delegation | loyalty |
|---|---|---|---|---|---|---|---|
| +0.23 | 0.81 | 0.21 | 0.60 | 0.88 | 0.17 | 0.28 | 1.00 |
| +0.23 | 0.52 | 0.14 | 0.56 | 0.66 | 0.81 | 0.10 | 0.20 |
| +0.23 | 0.86 | 0.70 | 0.86 | 1.06 | 0.65 | 0.32 | 0.50 |
| +0.23 | 0.61 | 0.41 | 0.19 | 0.42 | 0.71 | 0.92 | 0.28 |
| +0.24 | 0.59 | 0.43 | 0.19 | 0.64 | 0.54 | 0.41 | 0.18 |
| +0.24 | 0.47 | 0.52 | 0.47 | 0.43 | 0.47 | 0.81 | 0.72 |
| +0.24 | 0.24 | 0.40 | 0.38 | 0.67 | 0.25 | 0.98 | 0.48 |
| +0.24 | 0.40 | 0.55 | 0.54 | 0.23 | 0.44 | 0.61 | 0.29 |
