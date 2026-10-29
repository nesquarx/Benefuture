# Failure-boundary battery: economy

Build: commit 0e08fc3 (with any uncommitted changes at the time).

Clean world's floor growth: 252.6. 
Run time 91.5 minutes; 16 random rays; 64 screened worlds (severities up to 0.80), 0% failing.

## Limits along one factor (severity 1 = top of the explored range)

| Factor | Fails beyond |
|---|---|
| markers | not within 2 |
| model error | not within 2 |
| model bias | not within 2 |
| classification | not within 2 |
| execution | 1.40 |
| accounting | not within 2 |
| memory loss | not within 2 |
| attribution | not within 2 |
| hazards | not within 2 |
| deceit | not within 2 |
| outage | not within 2 |
| capture | not within 2 |
| side harm | 1.31 |
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
| memory loss | 0.000 |
| attribution | 0.000 |
| hazards | 0.000 |
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
| markers × outage | +0.000 |
| model error × accounting | +0.000 |
| execution × outage | +0.000 |
| execution × audit errors | +0.000 |
| model bias × laundering | +0.000 |
| markers × deceit | +0.000 |
| model error × execution | +0.000 |
| accounting × capture | +0.000 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | memory loss | attribution | hazards | deceit | outage | capture | side harm | laundering | inattention | audit errors | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1.48 | 0.08 | 0.41 | 0.09 | 0.05 | 0.26 | 0.20 | 0.03 | 0.39 | 0.09 | 0.00 | 0.98 | 0.33 | 0.20 | 0.15 | 0.20 | 0.76 | false |
| 1.65 | 0.00 | 0.24 | 0.02 | 0.59 | 0.75 | 0.50 | 0.53 | 0.32 | 0.05 | 0.20 | 0.79 | 0.41 | 0.26 | 0.27 | 0.12 | 0.34 | false |
| 1.73 | 0.21 | 0.01 | 0.08 | 0.19 | 0.83 | 0.11 | 0.04 | 0.04 | 0.02 | 0.54 | 0.02 | 0.39 | 0.76 | 0.28 | 1.04 | 0.13 | true |
| 1.98 | 0.39 | 0.07 | 0.86 | 0.18 | 0.51 | 0.50 | 0.19 | 0.29 | 0.23 | 0.35 | 0.86 | 0.13 | 0.77 | 0.43 | 0.03 | 0.80 | true |
| 1.98 | 0.33 | 0.20 | 0.45 | 0.09 | 0.29 | 1.21 | 0.58 | 0.40 | 0.22 | 0.28 | 0.40 | 0.68 | 0.23 | 0.67 | 0.34 | 0.36 | true |
| 1.98 | 0.18 | 0.12 | 1.11 | 0.11 | 0.32 | 0.43 | 0.55 | 0.30 | 0.41 | 0.29 | 0.26 | 0.78 | 0.67 | 0.23 | 0.09 | 0.71 | true |

Non-monotone rays (converging again beyond the boundary): 2 of 16.
