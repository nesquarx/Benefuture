# Failure-boundary battery: economy

Build: commit f3c5963 (with any uncommitted changes at the time).

Clean world's floor growth: 255.1. 
Run time 112.7 minutes; 16 random rays; 64 screened worlds (severities up to 0.62), 8% failing.

## Limits along one factor (severity 1 = top of the explored range)

| Factor | Fails beyond |
|---|---|
| markers | 1.35 |
| model error | 1.94 |
| model bias | not within 2 |
| classification | not within 2 |
| execution | 1.65 |
| accounting | not within 2 |
| commons | not within 2 |
| memory loss | not within 2 |
| attribution | not within 2 |
| hazards | not within 2 |
| guardians | not within 2 |
| deceit | not within 2 |
| outage | not within 2 |
| capture | not within 2 |
| side harm | 0.31 |
| laundering | not within 2 |
| inattention | not within 2 |
| audit errors | not within 2 |

## Importance in screening (mean severity in failing worlds less in converging ones)

| Factor | Importance |
|---|---|
| classification | 0.168 |
| hazards | 0.139 |
| markers | 0.119 |
| model error | 0.095 |
| side harm | 0.091 |
| memory loss | 0.075 |
| execution | 0.033 |
| model bias | 0.018 |
| accounting | 0.015 |
| deceit | 0.010 |
| commons | 0.001 |
| capture | -0.020 |
| guardians | -0.025 |
| attribution | -0.032 |
| laundering | -0.040 |
| audit errors | -0.049 |
| inattention | -0.115 |
| outage | -0.131 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| commons × guardians | -0.357 |
| markers × inattention | -0.333 |
| execution × guardians | +0.312 |
| execution × commons | -0.312 |
| model error × memory loss | +0.294 |
| deceit × audit errors | +0.294 |
| classification × outage | -0.278 |
| attribution × capture | +0.255 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | commons | memory loss | attribution | hazards | guardians | deceit | outage | capture | side harm | laundering | inattention | audit errors | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.31 | 0.08 | 0.05 | 0.05 | 0.08 | 0.02 | 0.01 | 0.02 | 0.03 | 0.01 | 0.05 | 0.00 | 0.01 | 0.07 | 0.10 | 0.08 | 0.23 | 0.01 | 0.00 | false |
| 0.65 | 0.14 | 0.14 | 0.19 | 0.27 | 0.11 | 0.00 | 0.19 | 0.00 | 0.04 | 0.22 | 0.29 | 0.00 | 0.25 | 0.07 | 0.11 | 0.04 | 0.04 | 0.03 | false |
| 1.31 | 0.35 | 0.05 | 0.31 | 0.53 | 0.11 | 0.27 | 0.52 | 0.12 | 0.22 | 0.05 | 0.45 | 0.05 | 0.03 | 0.22 | 0.53 | 0.27 | 0.29 | 0.32 | true |
| 1.31 | 0.17 | 0.22 | 0.48 | 0.24 | 0.50 | 0.05 | 0.26 | 0.06 | 0.47 | 0.30 | 0.04 | 0.14 | 0.05 | 0.06 | 0.00 | 0.63 | 0.23 | 0.50 | false |
| 1.44 | 0.60 | 0.49 | 0.11 | 0.17 | 0.32 | 0.04 | 0.35 | 0.20 | 0.27 | 0.04 | 0.34 | 0.71 | 0.12 | 0.08 | 0.22 | 0.51 | 0.16 | 0.33 | true |
| 1.60 | 0.18 | 0.06 | 0.29 | 0.26 | 0.51 | 0.34 | 0.06 | 0.38 | 0.37 | 0.40 | 0.16 | 0.69 | 0.54 | 0.38 | 0.45 | 0.25 | 0.46 | 0.39 | true |
| 1.65 | 0.31 | 0.17 | 0.28 | 0.21 | 0.76 | 0.21 | 0.49 | 0.20 | 0.29 | 0.03 | 0.51 | 0.40 | 0.28 | 0.15 | 0.65 | 0.45 | 0.40 | 0.44 | true |
| 1.73 | 0.73 | 0.16 | 0.43 | 0.42 | 0.16 | 0.25 | 0.07 | 0.04 | 0.73 | 0.11 | 0.65 | 0.36 | 0.03 | 0.68 | 0.49 | 0.39 | 0.16 | 0.05 | true |

Non-monotone rays (converging again beyond the boundary): 3 of 16.

## Failure boxes (PRIM over the screened worlds)

No failing world, so no box.
