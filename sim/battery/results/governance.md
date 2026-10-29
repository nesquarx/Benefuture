# Failure-boundary battery: governance

Build: commit 2df0f1b (with any uncommitted changes at the time).

Run time 8.1 minutes; 24 random rays; 128 screened worlds (severities up to 1.00), 14% failing.

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
| collusion | 0.357 |
| hidden outcomes | 0.206 |
| signal noise | 0.165 |
| ability scatter | -0.061 |
| delegation | -0.141 |
| local noise | -0.191 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| hidden outcomes × collusion | +0.242 |
| local noise × collusion | -0.230 |
| signal noise × collusion | +0.224 |
| ability scatter × delegation | +0.188 |
| signal noise × hidden outcomes | -0.153 |
| collusion × delegation | -0.153 |
| ability scatter × hidden outcomes | -0.136 |
| local noise × delegation | +0.098 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | signal noise | ability scatter | hidden outcomes | local noise | collusion | delegation | monotone |
|---|---|---|---|---|---|---|---|
| 1.34 | 0.53 | 0.20 | 1.08 | 0.26 | 0.44 | 0.22 | true |
| 1.38 | 0.68 | 0.42 | 0.62 | 0.73 | 0.53 | 0.29 | true |
| 1.38 | 0.14 | 0.28 | 0.39 | 0.35 | 1.22 | 0.20 | true |
| 1.46 | 0.96 | 0.12 | 0.77 | 0.15 | 0.51 | 0.57 | true |
| 1.65 | 0.45 | 0.63 | 0.87 | 0.08 | 0.92 | 0.71 | true |
| 1.74 | 0.88 | 0.10 | 0.40 | 0.07 | 0.63 | 1.30 | true |

Non-monotone rays (converging again beyond the boundary): 0 of 24.
