# Failure-boundary battery: economy

Build: commit de5d305 (with any uncommitted changes at the time).

Clean world's floor growth: 259.8. 
Run time 67.9 minutes; 16 random rays; 64 screened worlds (severities up to 0.59), 2% failing.

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
| classification | 0.236 |
| side harm | 0.232 |
| outage | 0.152 |
| model bias | 0.123 |
| execution | 0.100 |
| markers | 0.052 |
| deceit | 0.025 |
| laundering | 0.001 |
| capture | -0.038 |
| accounting | -0.044 |
| model error | -0.070 |
| memory loss | -0.121 |
| hazards | -0.131 |
| attribution | -0.288 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| classification × capture | -0.111 |
| markers × classification | +0.100 |
| accounting × capture | +0.083 |
| model bias × side harm | +0.083 |
| hazards × side harm | -0.083 |
| deceit × capture | -0.077 |
| markers × laundering | +0.077 |
| accounting × outage | -0.077 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | memory loss | attribution | hazards | deceit | outage | capture | side harm | laundering | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.31 | 0.00 | 0.05 | 0.09 | 0.01 | 0.06 | 0.03 | 0.12 | 0.16 | 0.10 | 0.07 | 0.03 | 0.15 | 0.04 | 0.06 | false |
| 1.27 | 0.22 | 0.76 | 0.21 | 0.39 | 0.04 | 0.27 | 0.15 | 0.54 | 0.13 | 0.39 | 0.29 | 0.31 | 0.11 | 0.20 | false |
| 1.31 | 0.35 | 0.37 | 0.48 | 0.71 | 0.28 | 0.00 | 0.50 | 0.01 | 0.11 | 0.09 | 0.24 | 0.41 | 0.22 | 0.33 | false |

Non-monotone rays (converging again beyond the boundary): 3 of 16.
