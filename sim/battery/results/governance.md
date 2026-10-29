# Failure-boundary battery: governance

Build: commit 732fe43 (with any uncommitted changes at the time).

Run time 8.3 minutes; 24 random rays; 128 screened worlds (severities up to 1.00), 12% failing.

## Limits along one factor (severity 1 = top of the explored range)

| Factor | Fails beyond |
|---|---|
| signal noise | not within 2 |
| ability scatter | not within 2 |
| hidden outcomes | not within 2 |
| local noise | not within 2 |
| collusion | not within 2 |
| delegation | not within 2 |

## Importance in screening (mean severity in failing worlds less in converging ones)

| Factor | Importance |
|---|---|
| collusion | 0.332 |
| hidden outcomes | 0.193 |
| signal noise | 0.102 |
| ability scatter | -0.054 |
| local noise | -0.139 |
| delegation | -0.186 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| collusion × delegation | -0.253 |
| signal noise × local noise | -0.176 |
| local noise × collusion | -0.149 |
| hidden outcomes × collusion | +0.139 |
| hidden outcomes × delegation | -0.127 |
| signal noise × hidden outcomes | -0.127 |
| signal noise × collusion | +0.124 |
| ability scatter × hidden outcomes | -0.113 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | signal noise | ability scatter | hidden outcomes | local noise | collusion | delegation | monotone |
|---|---|---|---|---|---|---|---|
| 1.38 | 0.14 | 0.28 | 0.39 | 0.35 | 1.22 | 0.20 | true |
| 1.46 | 0.58 | 0.22 | 1.18 | 0.29 | 0.48 | 0.24 | true |
| 1.49 | 0.98 | 0.12 | 0.78 | 0.15 | 0.52 | 0.58 | true |
| 1.55 | 0.76 | 0.47 | 0.70 | 0.82 | 0.60 | 0.32 | true |
| 1.76 | 0.48 | 0.67 | 0.93 | 0.09 | 0.98 | 0.76 | true |
| 1.77 | 0.90 | 0.10 | 0.41 | 0.07 | 0.64 | 1.32 | true |

Non-monotone rays (converging again beyond the boundary): 0 of 24.
