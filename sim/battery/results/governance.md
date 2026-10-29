# Failure-boundary battery: governance

Build: commit 3ac870a (with any uncommitted changes at the time).

Run time 8.2 minutes; 24 random rays; 128 screened worlds, 10% failing.

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
| collusion | 0.360 |
| hidden outcomes | 0.210 |
| signal noise | 0.186 |
| ability scatter | -0.122 |
| local noise | -0.198 |
| delegation | -0.206 |

## Strongest interactions (failure rate when both are high, beyond each alone)

| Pair | Interaction |
|---|---|
| local noise × collusion | -0.223 |
| collusion × delegation | -0.194 |
| signal noise × collusion | +0.182 |
| ability scatter × delegation | +0.156 |
| hidden outcomes × collusion | +0.133 |
| hidden outcomes × delegation | -0.131 |
| signal noise × hidden outcomes | -0.131 |
| local noise × delegation | +0.120 |

## Nearest failures on random rays (severity per factor at the boundary)

| t | signal noise | ability scatter | hidden outcomes | local noise | collusion | delegation | monotone |
|---|---|---|---|---|---|---|---|
| 1.37 | 0.54 | 0.20 | 1.10 | 0.27 | 0.45 | 0.22 | true |
| 1.38 | 0.14 | 0.28 | 0.39 | 0.35 | 1.22 | 0.20 | true |
| 1.49 | 0.98 | 0.12 | 0.78 | 0.15 | 0.52 | 0.58 | true |
| 1.55 | 0.76 | 0.47 | 0.70 | 0.82 | 0.60 | 0.32 | true |
| 1.80 | 0.92 | 0.10 | 0.41 | 0.07 | 0.65 | 1.34 | true |
| 1.95 | 0.53 | 0.74 | 1.03 | 0.10 | 1.08 | 0.84 | true |

Non-monotone rays (converging again beyond the boundary): 0 of 24.
