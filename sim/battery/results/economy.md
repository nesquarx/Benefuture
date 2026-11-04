# Failure-boundary battery: economy

Build: commit 102474a (with any uncommitted changes at the time).

Clean world's floor growth: 265.0. 
Run time 323.3 minutes; 16 random rays; 64 screened worlds (severities up to 0.67), 2% failing.

## Limits along one factor (severity 1 = top of the explored range)

| Factor | Fails beyond |
|---|---|
| markers | 1.44 |
| model error | not within 2 |
| model bias | not within 2 |
| classification | not within 2 |
| execution | 1.73 |
| accounting | not within 2 |
| commons | not within 2 |
| memory loss | not within 2 |
| attribution | not within 2 |
| hazards | not within 2 |
| guardians | not within 2 |
| deceit | not within 2 |
| outage | not within 2 |
| capture | not within 2 |
| side harm | 1.94 |
| laundering | not within 2 |
| inattention | not within 2 |
| audit errors | not within 2 |

## Importance in screening (mean severity in failing worlds less in converging ones)

| Factor | Importance |
|---|---|
| outage | 0.319 |
| model bias | 0.249 |
| guardians | 0.169 |
| side harm | 0.158 |
| audit errors | 0.102 |
| commons | 0.097 |
| model error | 0.086 |
| accounting | 0.059 |
| markers | 0.029 |
| deceit | 0.009 |
| attribution | -0.030 |
| hazards | -0.049 |
| memory loss | -0.123 |
| inattention | -0.154 |
| classification | -0.163 |
| capture | -0.182 |
| execution | -0.224 |
| laundering | -0.293 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| markers × attribution | -0.111 |
| capture × audit errors | -0.100 |
| commons × guardians | +0.083 |
| markers × memory loss | -0.083 |
| guardians × deceit | +0.083 |
| model error × deceit | +0.083 |
| memory loss × capture | +0.077 |
| model bias × hazards | -0.077 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | markers | model error | model bias | classification | execution | accounting | commons | memory loss | attribution | hazards | guardians | deceit | outage | capture | side harm | laundering | inattention | audit errors | monotone |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.65 | 0.17 | 0.03 | 0.15 | 0.26 | 0.05 | 0.13 | 0.26 | 0.06 | 0.11 | 0.02 | 0.22 | 0.02 | 0.01 | 0.11 | 0.26 | 0.13 | 0.14 | 0.16 | false |
| 1.65 | 0.21 | 0.27 | 0.61 | 0.30 | 0.63 | 0.06 | 0.33 | 0.08 | 0.58 | 0.38 | 0.05 | 0.18 | 0.06 | 0.07 | 0.00 | 0.78 | 0.29 | 0.63 | false |
| 1.98 | 0.77 | 0.31 | 0.94 | 0.48 | 0.22 | 0.29 | 0.05 | 0.23 | 0.37 | 0.83 | 0.23 | 0.37 | 0.61 | 0.03 | 0.48 | 0.53 | 0.02 | 0.19 | true |

Non-monotone rays (converging again beyond the boundary): 2 of 16.

## Failure boxes (PRIM over the screened worlds)

No failing world, so no box.
