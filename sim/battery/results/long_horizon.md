# Long-Horizon & Century Composed Simulation Report (8.64, 8.81, 8.85, 8.86)

- **Commit**: `5605704`
- **Threads**: `8`
- **Status**: `COMPLETED` (133.7 minutes elapsed)
- **Significance Standard**: Pre-stated `z = 2.0` (`z = 3.0` for README/BACKPROPAGATION), contiguous seeds `1:N`.

## 1. 10-Year Scaled Economy (120 steps, 240 beings, 16 agents, 8 leaves, `1:24` seeds, 25.5 min)

| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|
| `floor_u` (`:decay` vs `:window`) | 136.14 | 134.28 | +1.86 ± 1.12 | +1.66 | [-0.51, 4.22] |
| `floor_h` (`:decay` vs `:window`) | 136.39 | 134.00 | +2.38 ± 1.08 | +2.20 | [0.09, 4.67] |
| Transactions (`:decay` vs `:window`) | 1022.88 | 1004.50 | +18.38 ± 8.25 | +2.23 | [0.95, 35.80] |
| Stressed 10-yr `floor_u` gain (outage + catastrophe + capture + deceit) | 112.72 | 0.00 | +112.72 ± 1.67 | +67.48 | [109.19, 116.24] |
| Stressed 10-yr `floor_h` gain | 112.60 | 0.00 | +112.60 ± 1.64 | +68.71 | [109.14, 116.06] |


## 2. 20-Year Governance (1,200 decisions, 100 voters, stealth collusion & delegation, `1:24` seeds, 0.4 min)

| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|
| Late-half accuracy under stealth collusion (AdvAp ON vs OFF) | 0.9824 | 0.9561 | +0.0262 ± 0.0024 | +10.74 | [0.0211, 0.0314] |
| Late-half accuracy (Stealth collusion + AdvAp vs Clean) | 0.9824 | 0.9858 | -0.0034 ± 0.0011 | -2.98 | [-0.0058, -0.0010] |
| Years 16–20 accuracy (`901:1200`) vs `0.75` convergence bar | 0.9817 | 0.7500 | +0.2317 ± 0.0015 | +151.61 | [0.2284, 0.2349] |


## 3. 100-Year Composed Century World (1,200 economy steps + governance + 100-yr M7 population, `1:16` seeds, 39.8 min)

Includes 3 major catastrophes (steps 240, 660, 960), 2 measurement outages (steps 420, 840), 1 metric capture (step 540), and 3 breakthroughs (steps 300, 720, 1020), coupled with M5 governance and M7 population dynamics (teaching, research, births, G per entity).

| Century Metric | Mean | Baseline | Effect ± SE | `z` | 95% CI |
|---|---|---|---|---|---|
| Economy 1,200-step `floor_u` growth | 1365.21 | 0.00 | +1365.21 ± 19.61 | +69.61 | [1322.56, 1407.86] |
| Economy 1,200-step `floor_h` growth | 1361.45 | 0.00 | +1361.45 ± 19.09 | +71.32 | [1319.94, 1402.95] |
| Governance late-half accuracy vs `0.75` | 0.96 | 0.75 | +0.21 ± 0.00 | +68.28 | [0.21, 0.22] |
| Population 100-yr `floor_u` gain (teaching + research + births) | 14.83 | 0.00 | +14.83 ± 0.56 | +26.29 | [13.60, 16.05] |
| Population 100-yr `floor_h` gain | 3.05 | 0.00 | +3.05 ± 0.05 | +57.89 | [2.93, 3.16] |

- Mean century transactions executed: **9431.1**
- Mean century births admitted under escrow/ratchet: **11.4**


## 4. High-Seed Sweep: Open Question 8.85 (800-step Better-Models Takeover, `1:64` seeds, 67.9 min)

- **Takeover regime (`:decay`)**: `64 / 64` (100.0%, 95% interval `[0.941, 1.000]`)
- **Takeover regime (`:window`)**: `64 / 64` (100.0%, 95% interval `[0.941, 1.000]`)

| Metric (`1:64` paired seeds) | `:decay` Mean | `:window` Mean | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|
| Takeover count per run | 29.359 | 17.094 | +12.266 ± 1.600 | +7.66 | [9.065, 15.466] |
| Own-currency pricing share | 0.802 | 0.745 | +0.056 ± 0.013 | +4.20 | [0.030, 0.083] |
| Floor understanding growth (`floor_u`) | 437.397 | 349.743 | +87.654 ± 24.268 | +3.61 | [39.118, 136.191] |


