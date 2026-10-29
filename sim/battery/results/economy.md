# Failure-boundary battery: economy

Build: commit 2d40b5a (with any uncommitted changes at the time).

Clean world's floor growth: 259.8. 
Run time 50.1 minutes; 16 random rays; 64 screened worlds (severities up to 0.30), 2% failing.

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
| model bias | 0.112 |
| markers | 0.091 |
| accounting | 0.083 |
| execution | 0.064 |
| model error | 0.034 |
| attribution | 0.034 |
| outage | 0.014 |
| deceit | -0.002 |
| side harm | -0.050 |
| hazards | -0.055 |
| capture | -0.061 |
| classification | -0.087 |
| laundering | -0.096 |
| memory loss | -0.122 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| model error × model bias | +0.077 |
| accounting × memory loss | -0.077 |
| markers × side harm | -0.077 |
| model error × outage | +0.077 |
| model bias × accounting | +0.077 |
| hazards × deceit | +0.071 |
| outage × laundering | -0.071 |
| capture × side harm | +0.071 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | memory loss | attribution | hazards | deceit | outage | capture | side harm | laundering | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.31 | 0.04 | 0.01 | 0.07 | 0.06 | 0.12 | 0.08 | 0.01 | 0.09 | 0.11 | 0.09 | 0.15 | 0.08 | 0.10 | 0.02 | false |
| 0.31 | 0.00 | 0.05 | 0.09 | 0.01 | 0.06 | 0.03 | 0.12 | 0.16 | 0.10 | 0.07 | 0.03 | 0.15 | 0.04 | 0.06 | false |
| 0.65 | 0.02 | 0.11 | 0.08 | 0.01 | 0.16 | 0.02 | 0.15 | 0.07 | 0.25 | 0.36 | 0.36 | 0.00 | 0.15 | 0.08 | false |
| 0.65 | 0.09 | 0.08 | 0.12 | 0.02 | 0.12 | 0.19 | 0.17 | 0.15 | 0.37 | 0.04 | 0.16 | 0.30 | 0.11 | 0.13 | false |
| 1.31 | 0.23 | 0.79 | 0.21 | 0.41 | 0.04 | 0.28 | 0.15 | 0.56 | 0.13 | 0.40 | 0.30 | 0.32 | 0.11 | 0.21 | true |
| 1.98 | 0.01 | 0.09 | 0.20 | 0.89 | 0.11 | 0.04 | 0.04 | 0.48 | 0.63 | 1.25 | 0.50 | 0.62 | 0.27 | 0.39 | true |
| 1.98 | 0.53 | 0.56 | 0.73 | 1.07 | 0.42 | 0.01 | 0.75 | 0.02 | 0.17 | 0.13 | 0.36 | 0.62 | 0.33 | 0.49 | true |

Non-monotone rays (converging again beyond the boundary): 4 of 16.
