# Failure-boundary battery: economy

Build: commit 60aedf0 (with any uncommitted changes at the time).

Clean world's floor growth: 252.9. 
Run time 28.7 minutes; 16 random rays; 64 screened worlds (severities up to 0.39), 70% failing.

## Limits along one factor (severity 1 = top of the explored range)

| Factor | Fails beyond |
|---|---|
| markers | 1.44 |
| model error | 0.27 |
| model bias | not within 2 |
| classification | not within 2 |
| execution | 0.35 |
| accounting | not within 2 |
| memory loss | not within 2 |
| attribution | not within 2 |
| hazards | not within 2 |
| deceit | not within 2 |
| outage | not within 2 |
| capture | not within 2 |
| side harm | not within 2 |

## Importance in screening (mean severity in failing worlds less in converging ones)

| Factor | Importance |
|---|---|
| model error | 0.152 |
| execution | 0.103 |
| side harm | 0.077 |
| accounting | 0.040 |
| markers | 0.028 |
| capture | 0.016 |
| attribution | 0.011 |
| hazards | -0.007 |
| memory loss | -0.009 |
| model bias | -0.023 |
| outage | -0.029 |
| deceit | -0.033 |
| classification | -0.064 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| markers × outage | +0.000 |
| model error × accounting | +0.000 |
| execution × outage | +0.000 |
| memory loss × attribution | +0.000 |
| markers × deceit | +0.000 |
| model error × execution | +0.000 |
| accounting × capture | +0.000 |
| deceit × capture | +0.000 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | memory loss | attribution | hazards | deceit | outage | capture | side harm | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.44 | 0.02 | 0.26 | 0.13 | 0.03 | 0.06 | 0.06 | 0.04 | 0.05 | 0.14 | 0.17 | 0.08 | 0.12 | 0.15 | true |
| 0.48 | 0.11 | 0.08 | 0.19 | 0.20 | 0.30 | 0.09 | 0.00 | 0.01 | 0.11 | 0.05 | 0.15 | 0.00 | 0.05 | true |
| 0.52 | 0.02 | 0.24 | 0.17 | 0.24 | 0.12 | 0.11 | 0.03 | 0.01 | 0.22 | 0.03 | 0.06 | 0.19 | 0.04 | true |
| 0.60 | 0.10 | 0.21 | 0.08 | 0.02 | 0.21 | 0.13 | 0.10 | 0.12 | 0.23 | 0.27 | 0.28 | 0.13 | 0.03 | true |
| 0.65 | 0.22 | 0.05 | 0.06 | 0.26 | 0.07 | 0.21 | 0.08 | 0.29 | 0.05 | 0.16 | 0.29 | 0.17 | 0.13 | false |
| 0.73 | 0.27 | 0.08 | 0.26 | 0.02 | 0.27 | 0.37 | 0.02 | 0.04 | 0.06 | 0.29 | 0.14 | 0.01 | 0.24 | true |
| 0.81 | 0.33 | 0.01 | 0.00 | 0.19 | 0.33 | 0.04 | 0.21 | 0.09 | 0.17 | 0.33 | 0.37 | 0.27 | 0.10 | true |
| 0.81 | 0.62 | 0.07 | 0.09 | 0.07 | 0.29 | 0.05 | 0.09 | 0.18 | 0.10 | 0.09 | 0.32 | 0.05 | 0.12 | true |

Non-monotone rays (converging again beyond the boundary): 1 of 16.
