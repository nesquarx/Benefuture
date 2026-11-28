# Failure-boundary battery: economy

Build: commit 4ef9182 (with any uncommitted changes at the time).

Clean world's floor growth: 258.9. 
Run time 45.0 minutes; 16 random rays; 64 screened worlds (severities up to 0.47), 0% failing.

## Limits along one factor (severity 1 = top of the explored range)

| Factor | Fails beyond |
|---|---|
| markers | 1.52 |
| model error | not within 2 |
| model bias | not within 2 |
| classification | not within 2 |
| execution | 1.90 |
| accounting | not within 2 |
| commons | not within 2 |
| memory loss | not within 2 |
| attribution | not within 2 |
| hazards | not within 2 |
| guardians | not within 2 |
| deceit | not within 2 |
| outage | not within 2 |
| capture | not within 2 |
| side harm | not within 2 |
| laundering | not within 2 |
| inattention | not within 2 |
| audit errors | not within 2 |

## Importance in screening (mean severity in failing worlds less in converging ones)

| Factor | Importance |
|---|---|
| markers | 0.000 |
| model error | 0.000 |
| model bias | 0.000 |
| classification | 0.000 |
| execution | 0.000 |
| accounting | 0.000 |
| commons | 0.000 |
| memory loss | 0.000 |
| attribution | 0.000 |
| hazards | 0.000 |
| guardians | 0.000 |
| deceit | 0.000 |
| outage | 0.000 |
| capture | 0.000 |
| side harm | 0.000 |
| laundering | 0.000 |
| inattention | 0.000 |
| audit errors | 0.000 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| markers × guardians | +0.000 |
| model error × accounting | +0.000 |
| execution × guardians | +0.000 |
| execution × laundering | +0.000 |
| model bias × capture | +0.000 |
| markers × hazards | +0.000 |
| model error × execution | +0.000 |
| accounting × deceit | +0.000 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | commons | memory loss | attribution | hazards | guardians | deceit | outage | capture | side harm | laundering | inattention | audit errors | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.31 | 0.02 | 0.06 | 0.02 | 0.09 | 0.04 | 0.14 | 0.05 | 0.07 | 0.02 | 0.15 | 0.02 | 0.04 | 0.08 | 0.14 | 0.04 | 0.03 | 0.04 | 0.04 | false |
| 1.98 | 0.77 | 0.31 | 0.94 | 0.48 | 0.22 | 0.29 | 0.05 | 0.23 | 0.37 | 0.83 | 0.23 | 0.37 | 0.61 | 0.03 | 0.48 | 0.53 | 0.02 | 0.19 | true |

Non-monotone rays (converging again beyond the boundary): 1 of 16.

## Failure boxes (PRIM over the screened worlds)

No failing world, so no box.

## Continuous methods (run time 56.9 minutes)

Readings: the success pattern's continuous margin (each criterion scaled so the clean world reads 1 and the criterion's edge 0; the margin is the weakest) and each criterion's slack, averaged over seeds 1, 2, … until the margin's standard error (Student-t inflated) is within 0.1 (3 to 8 seeds).

### Variance-based sensitivity (Sobol indices; severities uniform in [0, 1.00])

Saltelli et al. (2010) design, 320 evaluations; 95% bootstrap intervals. S1: the share of the reading's variance a factor explains alone; ST: with all its interactions. ST well above S1 marks a factor acting through interactions; variance the seeds add is in no factor's S1. Seeds per world: mean 6.2, 169 of 320 worlds at the cap.

| Factor | S1 (margin) | ST (margin) | ST floor_u | ST floor_h | ST median_u | ST median_h | ST peak_u | ST worst_drop |
|---|---|---|---|---|---|---|---|---|
| deceit | 0.13 [-1.32, 0.56] | 0.84 [0.39, 1.40] | 0.28 | 0.28 | 0.29 | 0.30 | 0.28 | 0.74 |
| hazards | 0.36 [-0.82, 0.64] | 0.82 [0.28, 1.67] | 0.05 | 0.05 | 0.05 | 0.04 | 0.06 | 1.01 |
| markers | 0.12 [-1.78, 0.52] | 0.80 [0.46, 2.24] | 0.29 | 0.27 | 0.30 | 0.28 | 0.33 | 0.65 |
| classification | -0.31 [-1.26, 0.67] | 0.78 [0.38, 2.85] | 0.19 | 0.20 | 0.19 | 0.21 | 0.21 | 0.92 |
| execution | 0.19 [-1.01, 0.52] | 0.69 [0.31, 2.10] | 0.26 | 0.25 | 0.25 | 0.25 | 0.23 | 0.73 |
| inattention | 0.22 [-0.77, 0.52] | 0.61 [0.14, 1.27] | 0.09 | 0.09 | 0.08 | 0.08 | 0.09 | 0.61 |
| model bias | -0.19 [-0.46, 0.68] | 0.46 [0.16, 0.89] | 0.05 | 0.05 | 0.05 | 0.05 | 0.04 | 0.37 |
| guardians | 0.25 [-0.67, 0.51] | 0.44 [0.10, 0.85] | 0.05 | 0.05 | 0.05 | 0.05 | 0.06 | 0.56 |
| laundering | 0.34 [-0.38, 0.62] | 0.43 [0.19, 0.98] | 0.21 | 0.22 | 0.21 | 0.22 | 0.22 | 0.46 |
| side harm | 0.17 [-0.95, 0.45] | 0.42 [0.14, 0.73] | 0.54 | 0.55 | 0.55 | 0.54 | 0.55 | 0.32 |
| accounting | 0.19 [-0.59, 0.45] | 0.33 [0.04, 0.48] | 0.04 | 0.04 | 0.04 | 0.04 | 0.04 | 0.38 |
| outage | 0.33 [-0.11, 0.63] | 0.32 [0.08, 0.48] | 0.04 | 0.03 | 0.04 | 0.03 | 0.04 | 0.31 |
| capture | 0.24 [-0.35, 0.45] | 0.25 [0.06, 0.34] | 0.02 | 0.03 | 0.02 | 0.02 | 0.03 | 0.25 |
| model error | -0.13 [-0.80, 0.15] | 0.25 [0.04, 1.26] | 0.05 | 0.04 | 0.04 | 0.05 | 0.07 | 0.26 |
| attribution | 0.04 [-0.17, 0.40] | 0.03 [0.00, 0.17] | 0.02 | 0.02 | 0.02 | 0.02 | 0.02 | 0.07 |
| memory loss | 0.06 [0.02, 0.25] | 0.01 [0.00, 0.06] | 0.00 | 0.00 | 0.01 | 0.00 | 0.00 | 0.03 |
| commons | -0.05 [-0.32, 0.01] | 0.01 [0.00, 0.07] | 0.02 | 0.01 | 0.02 | 0.02 | 0.01 | 0.01 |
| audit errors | 0.00 [0.00, 0.00] | 0.00 [0.00, 0.00] | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |

Sum of first-order indices (margin): 1.95; variance of the margin: 0.191.

### Active learning of the failure boundary (AK-MCS)

A Gaussian-process surrogate of the margin chose 40 of 2000 candidate worlds (drawn as the screening's), each where its sign was least certain (Echard, Gayton & Lemaire 2011). Estimated failing share of the candidates: 0.1% (screening: 0.0%). Seeds per world: mean 4.4, 9 of 40 worlds at the cap.

#### Failure boxes (PRIM over the surrogate's verdict on the candidates)

No failing world, so no box.

Evaluated worlds nearest the boundary (smallest |margin|):

| margin | markers | model error | model bias | classification | execution | accounting | commons | memory loss | attribution | hazards | guardians | deceit | outage | capture | side harm | laundering | inattention | audit errors |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| +0.06 | 0.10 | 0.33 | 0.19 | 0.03 | 0.35 | 0.18 | 0.28 | 0.29 | 0.10 | 0.15 | 0.29 | 0.13 | 0.23 | 0.23 | 0.34 | 0.30 | 0.13 | 0.20 |
| -0.12 | 0.36 | 0.11 | 0.14 | 0.33 | 0.25 | 0.38 | 0.16 | 0.21 | 0.36 | 0.14 | 0.46 | 0.18 | 0.32 | 0.27 | 0.09 | 0.31 | 0.39 | 0.25 |
| +0.29 | 0.26 | 0.18 | 0.13 | 0.52 | 0.24 | 0.35 | 0.41 | 0.40 | 0.17 | 0.34 | 0.28 | 0.18 | 0.19 | 0.26 | 0.10 | 0.27 | 0.10 | 0.28 |
| +0.40 | 0.04 | 0.09 | 0.15 | 0.23 | 0.05 | 0.35 | 0.10 | 0.33 | 0.00 | 0.07 | 0.13 | 0.26 | 0.18 | 0.22 | 0.38 | 0.01 | 0.22 | 0.28 |
| +0.40 | 0.23 | 0.16 | 0.12 | 0.36 | 0.20 | 0.12 | 0.17 | 0.24 | 0.23 | 0.11 | 0.44 | 0.09 | 0.26 | 0.30 | 0.17 | 0.32 | 0.27 | 0.29 |
| +0.43 | 0.27 | 0.43 | 0.20 | 0.32 | 0.20 | 0.10 | 0.22 | 0.30 | 0.46 | 0.23 | 0.57 | 0.23 | 0.25 | 0.54 | 0.40 | 0.19 | 0.30 | 0.33 |
| +0.44 | 0.11 | 0.24 | 0.34 | 0.05 | 0.36 | 0.15 | 0.15 | 0.31 | 0.00 | 0.45 | 0.25 | 0.17 | 0.38 | 0.26 | 0.29 | 0.09 | 0.30 | 0.29 |
| +0.57 | 0.26 | 0.00 | 0.16 | 0.19 | 0.36 | 0.13 | 0.22 | 0.30 | 0.15 | 0.36 | 0.36 | 0.13 | 0.34 | 0.24 | 0.31 | 0.40 | 0.15 | 0.20 |
