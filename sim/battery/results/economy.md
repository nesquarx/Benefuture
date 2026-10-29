# Failure-boundary battery: economy

Build: commit 08671a6 (the run started there; its tag was read at the end, a fault fixed after).

Clean world's floor growth: 256.7. 
Run time 54.2 minutes; 16 random rays; 64 screened worlds (severities up to 0.37), 58% failing.

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
| laundering | not within 2 |

## Importance in screening (mean severity in failing worlds less in converging ones)

| Factor | Importance |
|---|---|
| model error | 0.132 |
| execution | 0.126 |
| classification | 0.035 |
| markers | 0.026 |
| attribution | 0.024 |
| model bias | 0.020 |
| memory loss | 0.020 |
| accounting | 0.003 |
| laundering | 0.000 |
| hazards | -0.005 |
| side harm | -0.010 |
| outage | -0.028 |
| capture | -0.042 |
| deceit | -0.053 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| classification × laundering | +0.786 |
| markers × capture | -0.652 |
| deceit × laundering | +0.562 |
| hazards × side harm | +0.517 |
| model bias × attribution | -0.459 |
| memory loss × side harm | +0.438 |
| deceit × outage | +0.420 |
| hazards × deceit | -0.405 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | memory loss | attribution | hazards | deceit | outage | capture | side harm | laundering | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.31 | 0.05 | 0.19 | 0.05 | 0.10 | 0.01 | 0.07 | 0.04 | 0.13 | 0.03 | 0.10 | 0.07 | 0.08 | 0.03 | 0.05 | true |
| 0.52 | 0.06 | 0.10 | 0.03 | 0.02 | 0.30 | 0.09 | 0.20 | 0.05 | 0.19 | 0.02 | 0.17 | 0.12 | 0.13 | 0.12 | true |
| 0.52 | 0.20 | 0.27 | 0.02 | 0.03 | 0.05 | 0.15 | 0.18 | 0.09 | 0.18 | 0.22 | 0.01 | 0.01 | 0.03 | 0.12 | true |
| 0.60 | 0.05 | 0.20 | 0.03 | 0.06 | 0.13 | 0.22 | 0.15 | 0.30 | 0.04 | 0.09 | 0.11 | 0.34 | 0.01 | 0.02 | true |
| 0.65 | 0.25 | 0.07 | 0.15 | 0.03 | 0.31 | 0.29 | 0.01 | 0.09 | 0.11 | 0.25 | 0.21 | 0.08 | 0.08 | 0.05 | true |
| 0.69 | 0.16 | 0.21 | 0.30 | 0.03 | 0.17 | 0.20 | 0.07 | 0.24 | 0.07 | 0.11 | 0.05 | 0.13 | 0.26 | 0.27 | true |
| 0.73 | 0.20 | 0.21 | 0.27 | 0.39 | 0.15 | 0.00 | 0.28 | 0.01 | 0.06 | 0.05 | 0.13 | 0.23 | 0.12 | 0.18 | true |
| 0.85 | 0.12 | 0.04 | 0.19 | 0.17 | 0.33 | 0.22 | 0.04 | 0.24 | 0.29 | 0.25 | 0.41 | 0.22 | 0.26 | 0.05 | true |

Non-monotone rays (converging again beyond the boundary): 1 of 16.
