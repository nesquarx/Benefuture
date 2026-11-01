# Failure-boundary battery: economy

Build: commit unknown (with any uncommitted changes at the time).

Clean world's floor growth: 265.2. 
Run time 39.3 minutes; 16 random rays; 64 screened worlds (severities up to 0.20), 0% failing.

## Limits along one factor (severity 1 = top of the explored range)

| Factor | Fails beyond |
|---|---|
| markers | 1.31 |
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
| side harm | 1.98 |
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
| guardians × inattention | +0.000 |
| guardians × audit errors | +0.000 |
| memory loss × deceit | +0.000 |
| memory loss × side harm | +0.000 |
| markers × deceit | +0.000 |
| markers × side harm | +0.000 |
| classification × accounting | +0.000 |
| commons × inattention | +0.000 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | commons | memory loss | attribution | hazards | guardians | deceit | outage | capture | side harm | laundering | inattention | audit errors | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.31 | 0.03 | 0.03 | 0.00 | 0.03 | 0.06 | 0.03 | 0.00 | 0.00 | 0.08 | 0.14 | 0.00 | 0.15 | 0.11 | 0.12 | 0.00 | 0.03 | 0.09 | 0.08 | false |
| 0.65 | 0.04 | 0.13 | 0.05 | 0.18 | 0.08 | 0.28 | 0.11 | 0.14 | 0.03 | 0.31 | 0.03 | 0.09 | 0.17 | 0.29 | 0.09 | 0.06 | 0.08 | 0.08 | false |

Non-monotone rays (converging again beyond the boundary): 2 of 16.

## Failure boxes (PRIM over the screened worlds)

No failing world, so no box.

## Continuous methods (run time 48.6 minutes)

Readings: the success pattern's continuous margin (each criterion scaled so the clean world reads 1 and the criterion's edge 0; the margin is the weakest) and each criterion's slack, averaged over seeds 1, 2, … until the margin's standard error (Student-t inflated) is within 0.1 (3 to 8 seeds).

### Variance-based sensitivity (Sobol indices; severities uniform in [0, 1.00])

Saltelli et al. (2010) design, 320 evaluations; 95% bootstrap intervals. S1: the share of the reading's variance a factor explains alone; ST: with all its interactions. ST well above S1 marks a factor acting through interactions; variance the seeds add is in no factor's S1. Seeds per world: mean 6.4, 191 of 320 worlds at the cap.

| Factor | S1 (margin) | ST (margin) | ST floor_u | ST floor_h | ST median_u | ST median_h | ST peak_u | ST worst_drop |
|---|---|---|---|---|---|---|---|---|
| guardians | -0.60 [-2.51, 0.31] | 1.08 [0.41, 2.53] | 0.05 | 0.05 | 0.05 | 0.05 | 0.05 | 1.32 |
| markers | 0.60 [-0.10, 1.22] | 0.77 [0.41, 1.56] | 0.65 | 0.65 | 0.67 | 0.67 | 0.68 | 0.61 |
| hazards | 0.82 [0.22, 1.41] | 0.67 [0.10, 1.49] | 0.13 | 0.13 | 0.13 | 0.13 | 0.13 | 0.80 |
| outage | 0.51 [-0.20, 1.39] | 0.57 [0.08, 1.11] | 0.04 | 0.04 | 0.04 | 0.04 | 0.03 | 0.62 |
| side harm | 0.74 [0.18, 1.40] | 0.50 [0.11, 1.01] | 0.30 | 0.30 | 0.31 | 0.29 | 0.30 | 0.37 |
| execution | 0.25 [-0.34, 0.85] | 0.38 [0.09, 0.71] | 0.14 | 0.14 | 0.15 | 0.14 | 0.16 | 0.44 |
| model error | -0.22 [-1.13, 0.28] | 0.38 [0.05, 0.91] | 0.09 | 0.08 | 0.08 | 0.08 | 0.09 | 0.50 |
| deceit | 0.49 [-0.14, 1.10] | 0.35 [0.10, 0.66] | 0.23 | 0.24 | 0.24 | 0.24 | 0.24 | 0.33 |
| model bias | -0.19 [-1.06, 0.33] | 0.35 [0.10, 0.90] | 0.11 | 0.11 | 0.11 | 0.11 | 0.12 | 0.41 |
| laundering | 0.20 [-0.33, 0.72] | 0.34 [0.03, 0.75] | 0.06 | 0.07 | 0.06 | 0.06 | 0.07 | 0.35 |
| inattention | -0.13 [-0.91, 0.34] | 0.23 [0.05, 0.50] | 0.05 | 0.05 | 0.05 | 0.05 | 0.06 | 0.29 |
| accounting | -0.08 [-0.38, 0.35] | 0.16 [0.04, 0.46] | 0.06 | 0.06 | 0.06 | 0.06 | 0.05 | 0.21 |
| classification | -0.03 [-0.32, 0.57] | 0.16 [0.06, 0.36] | 0.20 | 0.21 | 0.21 | 0.21 | 0.21 | 0.19 |
| memory loss | -0.15 [-0.48, 0.08] | 0.11 [0.02, 0.26] | 0.02 | 0.02 | 0.02 | 0.02 | 0.02 | 0.17 |
| attribution | -0.05 [-0.19, 0.13] | 0.03 [0.01, 0.07] | 0.03 | 0.03 | 0.03 | 0.03 | 0.04 | 0.03 |
| commons | -0.06 [-0.17, 0.00] | 0.01 [0.00, 0.04] | 0.02 | 0.02 | 0.02 | 0.02 | 0.02 | 0.02 |
| capture | -0.01 [-0.07, 0.11] | 0.01 [0.00, 0.03] | 0.01 | 0.01 | 0.01 | 0.01 | 0.01 | 0.02 |
| audit errors | 0.00 [0.00, 0.00] | 0.00 [0.00, 0.00] | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |

Sum of first-order indices (margin): 2.09; variance of the margin: 0.119.

### Active learning of the failure boundary (AK-MCS)

A Gaussian-process surrogate of the margin chose 10 of 2000 candidate worlds (drawn as the screening's), each where its sign was least certain (Echard, Gayton & Lemaire 2011). Estimated failing share of the candidates: 0.0% (screening: 0.0%). Seeds per world: mean 4.6, 1 of 10 worlds at the cap.

#### Failure boxes (PRIM over the surrogate's verdict on the candidates)

No failing world, so no box.

Evaluated worlds nearest the boundary (smallest |margin|):

| margin | markers | model error | model bias | classification | execution | accounting | commons | memory loss | attribution | hazards | guardians | deceit | outage | capture | side harm | laundering | inattention | audit errors |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| +0.70 | 0.13 | 0.20 | 0.08 | 0.11 | 0.05 | 0.11 | 0.08 | 0.19 | 0.07 | 0.21 | 0.14 | 0.02 | 0.01 | 0.13 | 0.15 | 0.03 | 0.04 | 0.18 |
| +0.82 | 0.09 | 0.12 | 0.10 | 0.12 | 0.08 | 0.12 | 0.12 | 0.14 | 0.10 | 0.02 | 0.18 | 0.09 | 0.19 | 0.11 | 0.13 | 0.19 | 0.08 | 0.07 |
| +0.83 | 0.07 | 0.09 | 0.18 | 0.04 | 0.13 | 0.04 | 0.08 | 0.03 | 0.00 | 0.16 | 0.03 | 0.06 | 0.10 | 0.08 | 0.12 | 0.09 | 0.04 | 0.09 |
| +0.83 | 0.05 | 0.22 | 0.04 | 0.11 | 0.17 | 0.09 | 0.10 | 0.10 | 0.06 | 0.15 | 0.02 | 0.07 | 0.11 | 0.21 | 0.15 | 0.09 | 0.14 | 0.04 |
| +0.84 | 0.09 | 0.12 | 0.08 | 0.14 | 0.15 | 0.19 | 0.10 | 0.13 | 0.14 | 0.15 | 0.07 | 0.06 | 0.08 | 0.15 | 0.19 | 0.14 | 0.12 | 0.17 |
| +0.86 | 0.00 | 0.08 | 0.10 | 0.16 | 0.09 | 0.00 | 0.09 | 0.15 | 0.11 | 0.04 | 0.05 | 0.16 | 0.07 | 0.08 | 0.12 | 0.02 | 0.09 | 0.18 |
| +0.87 | 0.12 | 0.16 | 0.12 | 0.05 | 0.08 | 0.05 | 0.09 | 0.09 | 0.13 | 0.00 | 0.09 | 0.11 | 0.11 | 0.16 | 0.08 | 0.04 | 0.07 | 0.08 |
| +0.88 | 0.07 | 0.07 | 0.08 | 0.07 | 0.04 | 0.07 | 0.18 | 0.12 | 0.11 | 0.06 | 0.03 | 0.14 | 0.15 | 0.13 | 0.07 | 0.07 | 0.12 | 0.19 |
