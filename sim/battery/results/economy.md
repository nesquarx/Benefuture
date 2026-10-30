# Failure-boundary battery: economy

Build: commit 9ceed47 (with any uncommitted changes at the time).

Clean world's floor growth: 252.6. 
Run time 86.8 minutes; 16 random rays; 64 screened worlds (severities up to 0.73), 2% failing.

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
| capture | 0.593 |
| audit errors | 0.311 |
| outage | 0.249 |
| deceit | 0.226 |
| inattention | 0.167 |
| classification | 0.131 |
| accounting | 0.060 |
| attribution | -0.004 |
| side harm | -0.036 |
| model bias | -0.131 |
| hazards | -0.165 |
| execution | -0.165 |
| memory loss | -0.172 |
| model error | -0.198 |
| laundering | -0.207 |
| markers | -0.267 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| model error × execution | +0.100 |
| deceit × laundering | -0.083 |
| memory loss × side harm | +0.083 |
| execution × hazards | +0.083 |
| model error × classification | -0.083 |
| classification × deceit | +0.083 |
| markers × side harm | +0.077 |
| memory loss × audit errors | -0.077 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | memory loss | attribution | hazards | deceit | outage | capture | side harm | laundering | inattention | audit errors | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1.65 | 0.09 | 0.46 | 0.10 | 0.05 | 0.29 | 0.22 | 0.04 | 0.43 | 0.10 | 0.00 | 1.09 | 0.37 | 0.22 | 0.16 | 0.23 | 0.84 | false |
| 1.73 | 0.21 | 0.01 | 0.08 | 0.19 | 0.83 | 0.11 | 0.04 | 0.04 | 0.02 | 0.54 | 0.02 | 0.39 | 0.76 | 0.28 | 1.04 | 0.13 | true |

Non-monotone rays (converging again beyond the boundary): 1 of 16.
