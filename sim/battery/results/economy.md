# Failure-boundary battery: economy

Build: commit 352a6b4 (with any uncommitted changes at the time).

Clean world's floor growth: 265.0. 
Run time 1292.3 minutes; 16 random rays; 64 screened worlds (severities up to 0.26), 6% failing.

## Limits along one factor (severity 1 = top of the explored range)

| Factor | Fails beyond |
|---|---|
| markers | 1.44 |
| model error | not within 2 |
| model bias | not within 2 |
| classification | not within 2 |
| execution | 1.73 |
| accounting | not within 2 |
| commons | not within 2 |
| memory loss | not within 2 |
| attribution | not within 2 |
| hazards | not within 2 |
| guardians | not within 2 |
| deceit | not within 2 |
| outage | not within 2 |
| capture | not within 2 |
| side harm | 1.94 |
| laundering | not within 2 |
| inattention | not within 2 |
| audit errors | not within 2 |

## Importance in screening (mean severity in failing worlds less in converging ones)

| Factor | Importance |
|---|---|
| attribution | 0.067 |
| model error | 0.065 |
| model bias | 0.062 |
| guardians | 0.054 |
| accounting | 0.027 |
| outage | 0.018 |
| markers | 0.018 |
| capture | 0.018 |
| inattention | 0.009 |
| side harm | 0.003 |
| commons | 0.002 |
| laundering | -0.000 |
| hazards | -0.003 |
| classification | -0.018 |
| execution | -0.022 |
| memory loss | -0.023 |
| audit errors | -0.035 |
| deceit | -0.058 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| capture × laundering | +0.286 |
| side harm × laundering | +0.267 |
| outage × inattention | +0.267 |
| classification × memory loss | +0.250 |
| accounting × hazards | -0.235 |
| deceit × audit errors | +0.235 |
| commons × inattention | +0.222 |
| capture × side harm | +0.222 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | commons | memory loss | attribution | hazards | guardians | deceit | outage | capture | side harm | laundering | inattention | audit errors | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.31 | 0.12 | 0.05 | 0.15 | 0.08 | 0.04 | 0.05 | 0.01 | 0.04 | 0.06 | 0.13 | 0.04 | 0.06 | 0.10 | 0.00 | 0.08 | 0.08 | 0.00 | 0.03 | false |
| 0.65 | 0.20 | 0.11 | 0.11 | 0.14 | 0.17 | 0.10 | 0.15 | 0.14 | 0.09 | 0.08 | 0.27 | 0.04 | 0.04 | 0.27 | 0.15 | 0.01 | 0.27 | 0.04 | false |
| 0.98 | 0.21 | 0.22 | 0.28 | 0.41 | 0.16 | 0.00 | 0.29 | 0.01 | 0.06 | 0.33 | 0.45 | 0.00 | 0.38 | 0.10 | 0.17 | 0.06 | 0.06 | 0.05 | false |

Non-monotone rays (converging again beyond the boundary): 3 of 16.

## Failure boxes (PRIM over the screened worlds)

No failing world, so no box.

## Continuous methods (run time 478.6 minutes)

Readings: the success pattern's continuous margin (each criterion scaled so the clean world reads 1 and the criterion's edge 0; the margin is the weakest) and each criterion's slack, averaged over seeds 1, 2, … until the margin's standard error (Student-t inflated) is within 0.1 (3 to 8 seeds).

### Variance-based sensitivity (Sobol indices; severities uniform in [0, 1.00])

Saltelli et al. (2010) design, 320 evaluations; 95% bootstrap intervals. S1: the share of the reading's variance a factor explains alone; ST: with all its interactions. ST well above S1 marks a factor acting through interactions; variance the seeds add is in no factor's S1. Seeds per world: mean 6.5, 189 of 320 worlds at the cap.

| Factor | S1 (margin) | ST (margin) | ST floor_u | ST floor_h | ST median_u | ST median_h | ST peak_u | ST worst_drop |
|---|---|---|---|---|---|---|---|---|
| guardians | 0.29 [-0.34, 0.87] | 0.88 [0.28, 1.72] | 0.11 | 0.10 | 0.10 | 0.10 | 0.10 | 1.01 |
| execution | 0.23 [-0.16, 0.91] | 0.57 [0.15, 1.14] | 0.23 | 0.21 | 0.22 | 0.23 | 0.19 | 0.48 |
| model error | -0.27 [-1.24, 0.03] | 0.46 [0.06, 1.17] | 0.10 | 0.11 | 0.10 | 0.10 | 0.11 | 0.50 |
| laundering | 0.09 [-0.54, 0.42] | 0.44 [0.16, 0.99] | 0.10 | 0.09 | 0.09 | 0.09 | 0.10 | 0.51 |
| side harm | 0.16 [-0.25, 0.78] | 0.38 [0.11, 0.81] | 0.31 | 0.32 | 0.31 | 0.31 | 0.31 | 0.39 |
| hazards | -0.09 [-0.89, 0.35] | 0.37 [0.16, 0.87] | 0.15 | 0.13 | 0.15 | 0.15 | 0.15 | 0.46 |
| model bias | 0.17 [-0.03, 0.64] | 0.35 [0.03, 0.73] | 0.09 | 0.08 | 0.08 | 0.08 | 0.07 | 0.39 |
| markers | 0.28 [-0.08, 0.68] | 0.33 [0.15, 0.90] | 0.49 | 0.50 | 0.48 | 0.50 | 0.53 | 0.21 |
| classification | 0.25 [-0.08, 0.89] | 0.32 [0.09, 0.76] | 0.25 | 0.26 | 0.25 | 0.26 | 0.26 | 0.34 |
| deceit | 0.30 [0.08, 0.99] | 0.22 [0.08, 0.58] | 0.38 | 0.36 | 0.38 | 0.37 | 0.37 | 0.22 |
| inattention | 0.12 [-0.11, 0.51] | 0.21 [0.03, 0.77] | 0.07 | 0.06 | 0.06 | 0.06 | 0.05 | 0.22 |
| outage | 0.02 [-0.21, 0.38] | 0.13 [0.03, 0.27] | 0.06 | 0.06 | 0.06 | 0.06 | 0.04 | 0.19 |
| memory loss | -0.09 [-0.66, 0.15] | 0.10 [0.01, 0.35] | 0.03 | 0.03 | 0.03 | 0.03 | 0.03 | 0.14 |
| attribution | -0.22 [-0.72, -0.04] | 0.08 [0.01, 0.26] | 0.07 | 0.06 | 0.07 | 0.07 | 0.07 | 0.06 |
| accounting | -0.02 [-0.28, 0.16] | 0.05 [0.01, 0.16] | 0.03 | 0.03 | 0.03 | 0.03 | 0.03 | 0.05 |
| capture | 0.01 [-0.09, 0.15] | 0.02 [0.00, 0.05] | 0.03 | 0.03 | 0.03 | 0.03 | 0.03 | 0.01 |
| commons | -0.01 [-0.06, 0.02] | 0.00 [0.00, 0.02] | 0.02 | 0.02 | 0.02 | 0.02 | 0.03 | 0.02 |
| audit errors | -0.01 [-0.05, 0.00] | 0.00 [0.00, 0.01] | 0.01 | 0.01 | 0.01 | 0.01 | 0.01 | 0.00 |

Sum of first-order indices (margin): 1.20; variance of the margin: 0.183.

### Active learning of the failure boundary (AK-MCS)

A Gaussian-process surrogate of the margin chose 10 of 2000 candidate worlds (drawn as the screening's), each where its sign was least certain (Echard, Gayton & Lemaire 2011). Estimated failing share of the candidates: 0.0% (screening: 6.2%). Seeds per world: mean 4.6, 3 of 10 worlds at the cap.

#### Failure boxes (PRIM over the surrogate's verdict on the candidates)

No failing world, so no box.

Evaluated worlds nearest the boundary (smallest |margin|):

| margin | markers | model error | model bias | classification | execution | accounting | commons | memory loss | attribution | hazards | guardians | deceit | outage | capture | side harm | laundering | inattention | audit errors |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| +0.72 | 0.13 | 0.16 | 0.13 | 0.16 | 0.11 | 0.16 | 0.16 | 0.19 | 0.13 | 0.03 | 0.24 | 0.12 | 0.26 | 0.15 | 0.18 | 0.26 | 0.10 | 0.10 |
| +0.72 | 0.16 | 0.21 | 0.16 | 0.07 | 0.10 | 0.07 | 0.13 | 0.12 | 0.18 | 0.00 | 0.12 | 0.15 | 0.15 | 0.22 | 0.11 | 0.05 | 0.10 | 0.11 |
| +0.75 | 0.10 | 0.09 | 0.11 | 0.10 | 0.05 | 0.10 | 0.25 | 0.16 | 0.15 | 0.08 | 0.04 | 0.19 | 0.20 | 0.18 | 0.10 | 0.09 | 0.16 | 0.25 |
| +0.79 | 0.07 | 0.29 | 0.05 | 0.14 | 0.23 | 0.12 | 0.14 | 0.13 | 0.08 | 0.20 | 0.03 | 0.09 | 0.15 | 0.28 | 0.20 | 0.12 | 0.18 | 0.05 |
| +0.80 | 0.14 | 0.12 | 0.05 | 0.14 | 0.16 | 0.12 | 0.02 | 0.20 | 0.07 | 0.13 | 0.04 | 0.21 | 0.13 | 0.00 | 0.08 | 0.08 | 0.15 | 0.07 |
| +0.80 | 0.13 | 0.16 | 0.11 | 0.19 | 0.21 | 0.25 | 0.14 | 0.17 | 0.19 | 0.20 | 0.09 | 0.09 | 0.11 | 0.20 | 0.26 | 0.19 | 0.16 | 0.22 |
| +0.81 | 0.00 | 0.11 | 0.13 | 0.22 | 0.12 | 0.00 | 0.12 | 0.20 | 0.15 | 0.06 | 0.07 | 0.22 | 0.10 | 0.11 | 0.17 | 0.03 | 0.11 | 0.24 |
| +0.83 | 0.18 | 0.27 | 0.11 | 0.14 | 0.07 | 0.15 | 0.11 | 0.25 | 0.09 | 0.28 | 0.20 | 0.03 | 0.01 | 0.18 | 0.20 | 0.04 | 0.06 | 0.24 |
