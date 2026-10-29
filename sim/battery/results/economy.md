# Failure-boundary battery: economy

Build: commit d8174b2 (with any uncommitted changes at the time).

Clean world's floor growth: 259.8. 
Run time 89.6 minutes; 16 random rays; 64 screened worlds (severities up to 0.45), 5% failing.

## Limits along one factor (severity 1 = top of the explored range)

| Factor | Fails beyond |
|---|---|
| markers | not within 2 |
| model error | not within 2 |
| model bias | not within 2 |
| classification | not within 2 |
| execution | 1.44 |
| accounting | not within 2 |
| memory loss | not within 2 |
| attribution | not within 2 |
| hazards | not within 2 |
| deceit | not within 2 |
| outage | not within 2 |
| capture | 1.48 |
| side harm | 1.23 |
| laundering | not within 2 |

## Importance in screening (mean severity in failing worlds less in converging ones)

| Factor | Importance |
|---|---|
| execution | 0.156 |
| hazards | 0.119 |
| classification | 0.096 |
| side harm | 0.065 |
| laundering | 0.051 |
| model error | 0.028 |
| memory loss | 0.021 |
| outage | 0.015 |
| deceit | 0.008 |
| accounting | -0.012 |
| capture | -0.026 |
| attribution | -0.034 |
| model bias | -0.052 |
| markers | -0.079 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| attribution × deceit | +0.214 |
| classification × execution | +0.214 |
| model error × attribution | -0.200 |
| markers × execution | -0.200 |
| memory loss × attribution | -0.188 |
| memory loss × hazards | +0.188 |
| attribution × outage | +0.188 |
| attribution × side harm | -0.188 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | memory loss | attribution | hazards | deceit | outage | capture | side harm | laundering | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.27 | 0.01 | 0.00 | 0.02 | 0.02 | 0.00 | 0.06 | 0.02 | 0.03 | 0.12 | 0.13 | 0.18 | 0.01 | 0.01 | 0.05 | false |
| 0.31 | 0.04 | 0.01 | 0.07 | 0.06 | 0.12 | 0.08 | 0.01 | 0.09 | 0.11 | 0.09 | 0.15 | 0.08 | 0.10 | 0.02 | false |
| 0.31 | 0.07 | 0.09 | 0.14 | 0.02 | 0.08 | 0.09 | 0.03 | 0.11 | 0.03 | 0.05 | 0.02 | 0.06 | 0.12 | 0.12 | false |
| 0.31 | 0.06 | 0.02 | 0.12 | 0.08 | 0.01 | 0.13 | 0.00 | 0.16 | 0.00 | 0.09 | 0.02 | 0.14 | 0.00 | 0.07 | false |
| 0.90 | 0.07 | 0.30 | 0.05 | 0.10 | 0.19 | 0.32 | 0.22 | 0.45 | 0.06 | 0.13 | 0.16 | 0.51 | 0.02 | 0.03 | false |
| 0.98 | 0.01 | 0.04 | 0.10 | 0.44 | 0.06 | 0.02 | 0.02 | 0.24 | 0.31 | 0.62 | 0.25 | 0.31 | 0.13 | 0.20 | false |
| 1.31 | 0.35 | 0.37 | 0.48 | 0.71 | 0.28 | 0.00 | 0.50 | 0.01 | 0.11 | 0.09 | 0.24 | 0.41 | 0.22 | 0.33 | false |
| 1.35 | 0.18 | 0.17 | 0.25 | 0.04 | 0.25 | 0.39 | 0.36 | 0.31 | 0.79 | 0.08 | 0.33 | 0.64 | 0.23 | 0.26 | false |

Non-monotone rays (converging again beyond the boundary): 8 of 16.
