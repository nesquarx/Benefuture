# Status-quo baseline: economy institutions (8.115 closed vs adaptive vs open entry)

Build: commit `5c84a52`. Seeds `1:24` (`n = 24`); `300` steps; `z = 3.0` (Student-t inflated, required `|z_raw| >= 3.17`); run time `7.7` minutes (`7` workers).

Pre-registered P7 (confidence 0.7, COORDINATION.md §2a): with open newcomer entry taking unmet demand (`open_entry = true`, `entrants = 8`), Benefuture's -10% `floor_u` disadvantage against status-quo institutions disappears while cutting `deceivers' advantage` sharply (`z >= 3.0`).

Same Benefuture economy, world and seeds; institutions at Benefuture-plausible values with AdvAp (`severity = 0`), or at today's status-quo values without it. Dormant entrant slots share identical world skill distribution (`median = 0.6`, `deceit = 0.0`) and must pass existing cluster identity binding (`bind!`) to enter on unmet proposals.

## Closed 8-agent economy (`adaptive_proposals = false`, `open_entry = false`)

Mean executed plans: `:bf` = `1830.2`, `:sq` = `2040.8`; Mean newcomers admitted (`entries`): `:bf` = `0.00`, `:sq` = `0.00`.

| Reading | Benefuture | Status quo | Paired diff ± SE (`z_raw`) | Equiv ±Δ (`z=3`) | Verdict at z = 3 |
|---|---|---|---|---|---|
| Floor of understanding | 242.65 | 266.36 | -23.71 ± 2.00 (`-11.85`) | – | status quo better |
| Floor of happiness | 240.91 | 264.71 | -23.80 ± 1.58 (`-15.07`) | – | status quo better |
| Median of understanding | 264.24 | 288.32 | -24.08 ± 1.71 (`-14.07`) | – | status quo better |
| Median of happiness | 261.37 | 286.51 | -25.13 ± 1.66 (`-15.15`) | – | status quo better |
| Harm's peak | 4.32 | 4.48 | -0.16 ± 0.14 (`-1.11`) | ±0.61 | no difference shown |
| Deceivers' advantage (endowments) | -79.98 | -5.85 | -74.13 ± 3.47 (`-21.38`) | – | Benefuture better |

## Adaptive proposals only (`adaptive_proposals = true`, `open_entry = false`)

Mean executed plans: `:bf` = `1971.0`, `:sq` = `2045.6`; Mean newcomers admitted (`entries`): `:bf` = `0.00`, `:sq` = `0.00`.

| Reading | Benefuture | Status quo | Paired diff ± SE (`z_raw`) | Equiv ±Δ (`z=3`) | Verdict at z = 3 |
|---|---|---|---|---|---|
| Floor of understanding | 261.06 | 268.81 | -7.76 ± 1.53 (`-5.07`) | – | status quo better |
| Floor of happiness | 258.46 | 268.70 | -10.24 ± 2.04 (`-5.02`) | – | status quo better |
| Median of understanding | 282.38 | 291.60 | -9.22 ± 1.74 (`-5.31`) | – | status quo better |
| Median of happiness | 280.42 | 289.43 | -9.01 ± 1.70 (`-5.29`) | – | status quo better |
| Harm's peak | 4.65 | 4.51 | +0.14 ± 0.15 (`+0.95`) | ±0.61 | no difference shown |
| Deceivers' advantage (endowments) | -170.96 | -10.87 | -160.09 ± 5.29 (`-30.28`) | – | Benefuture better |

## Open newcomer entry (`adaptive_proposals = true`, `open_entry = true`, `entrants = 8`)

Mean executed plans: `:bf` = `2077.0`, `:sq` = `2048.9`; Mean newcomers admitted (`entries`): `:bf` = `8.00`, `:sq` = `0.12`.

| Reading | Benefuture | Status quo | Paired diff ± SE (`z_raw`) | Equiv ±Δ (`z=3`) | Verdict at z = 3 |
|---|---|---|---|---|---|
| Floor of understanding | 289.49 | 269.61 | +19.88 ± 1.63 (`+12.20`) | – | Benefuture better |
| Floor of happiness | 288.01 | 268.97 | +19.05 ± 1.79 (`+10.63`) | – | Benefuture better |
| Median of understanding | 312.82 | 291.87 | +20.95 ± 1.87 (`+11.22`) | – | Benefuture better |
| Median of happiness | 311.21 | 290.09 | +21.12 ± 1.90 (`+11.11`) | – | Benefuture better |
| Harm's peak | 4.56 | 4.64 | -0.07 ± 0.18 (`-0.40`) | ±0.64 | no difference shown |
| Deceivers' advantage (endowments) | -55.67 | -10.66 | -45.01 ± 4.99 (`-9.02`) | – | Benefuture better |

