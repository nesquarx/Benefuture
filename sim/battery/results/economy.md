# Failure-boundary battery: economy

Build: commit cda8d93 (with any uncommitted changes at the time).

Caveats (this run): 7 of 16 rays non-monotone and interactions of ±0.5 from small quadrant counts point to a noisy oracle near the boundary (a majority of two seeds) and a small screen; read the single-factor limits as the firmer result. More seeds near the boundary would sharpen it.

Clean world's floor growth: 252.9. 
Run time 35.1 minutes; 16 random rays; 64 screened worlds (severities up to 0.14), 34% failing.

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
| model error | 0.014 |
| execution | 0.013 |
| capture | 0.013 |
| classification | 0.007 |
| attribution | 0.003 |
| hazards | 0.002 |
| markers | -0.001 |
| memory loss | -0.002 |
| side harm | -0.002 |
| model bias | -0.006 |
| laundering | -0.010 |
| deceit | -0.010 |
| outage | -0.011 |
| accounting | -0.023 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| deceit × side harm | -0.541 |
| model error × side harm | +0.541 |
| markers × execution | -0.463 |
| execution × capture | +0.429 |
| attribution × deceit | +0.429 |
| attribution × laundering | +0.397 |
| memory loss × attribution | -0.375 |
| execution × laundering | +0.375 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | memory loss | attribution | hazards | deceit | outage | capture | side harm | laundering | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.10 | 0.00 | 0.00 | 0.01 | 0.01 | 0.00 | 0.02 | 0.01 | 0.01 | 0.04 | 0.05 | 0.07 | 0.00 | 0.00 | 0.02 | false |
| 0.15 | 0.02 | 0.02 | 0.01 | 0.06 | 0.02 | 0.02 | 0.00 | 0.02 | 0.02 | 0.04 | 0.07 | 0.04 | 0.06 | 0.06 | false |
| 0.23 | 0.03 | 0.01 | 0.05 | 0.05 | 0.09 | 0.06 | 0.01 | 0.07 | 0.08 | 0.07 | 0.11 | 0.06 | 0.07 | 0.01 | false |
| 0.23 | 0.06 | 0.07 | 0.08 | 0.12 | 0.05 | 0.00 | 0.09 | 0.00 | 0.02 | 0.02 | 0.04 | 0.07 | 0.04 | 0.06 | true |
| 0.23 | 0.01 | 0.04 | 0.03 | 0.00 | 0.06 | 0.01 | 0.05 | 0.03 | 0.09 | 0.13 | 0.13 | 0.00 | 0.05 | 0.03 | false |
| 0.31 | 0.07 | 0.09 | 0.14 | 0.02 | 0.08 | 0.09 | 0.03 | 0.11 | 0.03 | 0.05 | 0.02 | 0.06 | 0.12 | 0.12 | true |
| 0.31 | 0.06 | 0.02 | 0.12 | 0.08 | 0.01 | 0.13 | 0.00 | 0.16 | 0.00 | 0.09 | 0.02 | 0.14 | 0.00 | 0.07 | false |
| 0.31 | 0.05 | 0.19 | 0.05 | 0.10 | 0.01 | 0.07 | 0.04 | 0.13 | 0.03 | 0.10 | 0.07 | 0.08 | 0.03 | 0.05 | true |

Non-monotone rays (converging again beyond the boundary): 7 of 16.
