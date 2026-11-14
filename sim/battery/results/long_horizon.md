# Long-Horizon & Century Coupled Battery Report (L3.1–L3.3; 8.64, 8.81, 8.85, 8.86)

- **Commit**: `unknown`
- **Threads**: `8`
- **Status**: `COMPLETED` (337.5 minutes elapsed)
- **Coupling Mode**: `continuous = true` (persistent M3c state across epochs, L3.4 / `run_coupled`)
- **Significance Standard**: Exploratory `z = 2.0`; **README / formal claim bar `z = 3.0`**, contiguous paired seeds `1:N`.
- **Pre-stated Hypotheses & Smallest Effects That Matter (`L3.3`)**:
  - *Mechanisms (`:bf` vs `:status_quo`)*: Under identical world, adversaries, noise, and shocks (`L3.1`), Benefuture (`:decay`, `advap = true`, `ratchet_k = 3`, `:record`) yields higher `floor_u`, `floor_h`, `median_u`, `median_h`, smaller `worst_drop`, and higher `gov_acc` than `:status_quo` (`:window`, `advap = false`, `ratchet_k = 0`, `:normal`), with strongest advantage under `:stressed`.
  - *Stress (`:stressed` vs `:unstressed`)*: Catastrophes, outages, and metric capture degrade `floor_u`, `floor_h`, and `worst_drop` relative to `:unstressed` (which keeps breakthroughs and baseline hazards/deceivers equal).
  - *Smallest Effects That Matter*: `|Δ floor| >= 2.0`, `|Δ median| >= 2.0`, `|Δ worst_drop| >= 1.0`, `|Δ gov_acc| >= 0.01` (`1.0 pp`), at `z >= 3.0`.

## 1. 10-Year Coupled World (`:bf` × `:status_quo` × `:stressed` × `:unstressed`) (`steps = 120`, `epoch = 24`, `m5_decisions = 120`, `1:32` seeds, 14.6 min)

| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI | `z >= 3` |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Stressed) | 77.101 | 72.229 | +4.872 ± 2.731 | +1.78 | [-0.589, 10.334] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Stressed) | 76.408 | 71.804 | +4.604 ± 2.647 | +1.74 | [-0.689, 9.898] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Stressed) | 93.878 | 89.088 | +4.790 ± 2.946 | +1.63 | [-1.102, 10.682] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Stressed) | 93.057 | 88.331 | +4.725 ± 2.976 | +1.59 | [-1.227, 10.677] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Stressed) | 31.806 | 31.468 | +0.338 ± 0.222 | +1.52 | [-0.106, 0.782] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Stressed) | 0.957 | 0.954 | +0.003 ± 0.002 | +1.68 | [-0.001, 0.008] | no |
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Unstressed) | 81.624 | 80.287 | +1.338 ± 0.983 | +1.36 | [-0.629, 3.304] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Unstressed) | 80.922 | 79.560 | +1.362 ± 0.891 | +1.53 | [-0.420, 3.144] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Unstressed) | 96.593 | 95.198 | +1.395 ± 0.899 | +1.55 | [-0.404, 3.193] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Unstressed) | 95.827 | 94.662 | +1.164 ± 0.934 | +1.25 | [-0.704, 3.033] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Unstressed) | 5.164 | 5.147 | +0.017 ± 0.143 | +0.12 | [-0.269, 0.304] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Unstressed) | 0.956 | 0.955 | +0.001 ± 0.002 | +0.44 | [-0.003, 0.005] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Benefuture) | 77.101 | 81.624 | -4.523 ± 1.214 | -3.72 | [-6.952, -2.094] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Benefuture) | 76.408 | 80.922 | -4.514 ± 1.056 | -4.28 | [-6.625, -2.403] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Benefuture) | 93.878 | 96.593 | -2.715 ± 0.999 | -2.72 | [-4.713, -0.717] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Benefuture) | 93.057 | 95.827 | -2.770 ± 0.880 | -3.15 | [-4.531, -1.010] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Benefuture) | 31.806 | 5.164 | +26.642 ± 5.149 | +5.17 | [16.344, 36.940] | yes |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Benefuture) | 0.957 | 0.956 | +0.002 ± 0.002 | +1.00 | [-0.002, 0.005] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Status-Quo) | 72.229 | 80.287 | -8.057 ± 2.653 | -3.04 | [-13.363, -2.752] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Status-Quo) | 71.804 | 79.560 | -7.756 ± 2.614 | -2.97 | [-12.984, -2.528] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Status-Quo) | 89.088 | 95.198 | -6.110 ± 2.855 | -2.14 | [-11.820, -0.400] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Status-Quo) | 88.331 | 94.662 | -6.331 ± 2.833 | -2.24 | [-11.996, -0.666] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Status-Quo) | 31.468 | 5.147 | +26.321 ± 5.012 | +5.25 | [16.298, 36.344] | yes |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Status-Quo) | 0.954 | 0.955 | -0.001 ± 0.002 | -0.44 | [-0.005, 0.003] | no |


## 2. 20-Year Coupled Governance (1,200 decisions as epochs; 4 factorial arms) (`steps = 240`, `epoch = 20`, `m5_decisions = 1200`, `1:32` seeds, 35.9 min)

| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI | `z >= 3` |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Stressed) | 202.711 | 193.131 | +9.580 ± 7.817 | +1.23 | [-6.054, 25.214] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Stressed) | 202.650 | 191.975 | +10.675 ± 7.906 | +1.35 | [-5.137, 26.487] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Stressed) | 227.580 | 217.614 | +9.966 ± 8.345 | +1.19 | [-6.725, 26.657] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Stressed) | 227.713 | 216.580 | +11.133 ± 8.310 | +1.34 | [-5.487, 27.752] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Stressed) | 36.852 | 36.768 | +0.084 ± 0.183 | +0.46 | [-0.282, 0.450] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Stressed) | 0.960 | 0.956 | +0.003 ± 0.001 | +4.32 | [0.002, 0.005] | yes |
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Unstressed) | 205.633 | 191.415 | +14.219 ± 8.595 | +1.65 | [-2.971, 31.408] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Unstressed) | 204.034 | 190.420 | +13.615 ± 8.833 | +1.54 | [-4.052, 31.281] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Unstressed) | 229.363 | 213.901 | +15.462 ± 9.506 | +1.63 | [-3.550, 34.474] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Unstressed) | 227.678 | 212.830 | +14.848 ± 9.537 | +1.56 | [-4.225, 33.921] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Unstressed) | 6.037 | 6.154 | -0.116 ± 0.157 | -0.74 | [-0.430, 0.197] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Unstressed) | 0.959 | 0.956 | +0.004 ± 0.001 | +5.13 | [0.002, 0.005] | yes |
| Floor U (`floor_u`) — Stressed vs Unstressed (Benefuture) | 202.711 | 205.633 | -2.922 ± 1.844 | -1.59 | [-6.609, 0.765] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Benefuture) | 202.650 | 204.034 | -1.385 ± 1.777 | -0.78 | [-4.938, 2.168] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Benefuture) | 227.580 | 229.363 | -1.784 ± 1.802 | -0.99 | [-5.387, 1.820] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Benefuture) | 227.713 | 227.678 | +0.035 ± 1.501 | +0.02 | [-2.968, 3.038] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Benefuture) | 36.852 | 6.037 | +30.815 ± 5.986 | +5.15 | [18.842, 42.788] | yes |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Benefuture) | 0.960 | 0.959 | +0.000 ± 0.001 | +0.60 | [-0.001, 0.001] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Status-Quo) | 193.131 | 191.415 | +1.716 ± 8.144 | +0.21 | [-14.572, 18.004] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Status-Quo) | 191.975 | 190.420 | +1.555 ± 8.042 | +0.19 | [-14.530, 17.639] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Status-Quo) | 217.614 | 213.901 | +3.712 ± 8.831 | +0.42 | [-13.949, 21.374] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Status-Quo) | 216.580 | 212.830 | +3.750 ± 8.616 | +0.44 | [-13.481, 20.981] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Status-Quo) | 36.768 | 6.154 | +30.615 ± 5.978 | +5.12 | [18.658, 42.572] | yes |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Status-Quo) | 0.956 | 0.956 | +0.001 ± 0.001 | +1.34 | [-0.000, 0.002] | no |


## 3. 100-Year Coupled Century World (4 factorial arms) (`steps = 1200`, `epoch = 25`, `m5_decisions = 1200`, `1:32` seeds, 208.2 min)

| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI | `z >= 3` |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Stressed) | 1208.960 | 816.957 | +392.003 ± 76.357 | +5.13 | [239.289, 544.717] | yes |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Stressed) | 1200.817 | 810.150 | +390.667 ± 75.352 | +5.18 | [239.962, 541.372] | yes |
| Median U (`median_u`) — Benefuture vs Status-Quo (Stressed) | 1267.047 | 863.917 | +403.130 ± 78.396 | +5.14 | [246.337, 559.923] | yes |
| Median H (`median_h`) — Benefuture vs Status-Quo (Stressed) | 1261.508 | 858.180 | +403.328 ± 77.763 | +5.19 | [247.801, 558.854] | yes |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Stressed) | 41.239 | 41.587 | -0.348 ± 0.206 | -1.69 | [-0.761, 0.064] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Stressed) | 0.955 | 0.956 | -0.001 ± 0.001 | -1.51 | [-0.002, 0.000] | no |
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Unstressed) | 1212.652 | 902.589 | +310.064 ± 78.204 | +3.96 | [153.655, 466.472] | yes |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Unstressed) | 1204.046 | 896.802 | +307.244 ± 78.095 | +3.93 | [151.054, 463.433] | yes |
| Median U (`median_u`) — Benefuture vs Status-Quo (Unstressed) | 1269.975 | 950.751 | +319.225 ± 80.630 | +3.96 | [157.965, 480.484] | yes |
| Median H (`median_h`) — Benefuture vs Status-Quo (Unstressed) | 1263.583 | 947.330 | +316.253 ± 80.937 | +3.91 | [154.379, 478.127] | yes |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Unstressed) | 9.240 | 9.068 | +0.172 ± 0.265 | +0.65 | [-0.358, 0.702] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Unstressed) | 0.956 | 0.957 | -0.001 ± 0.001 | -0.99 | [-0.002, 0.001] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Benefuture) | 1208.960 | 1212.652 | -3.692 ± 4.356 | -0.85 | [-12.405, 5.021] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Benefuture) | 1200.817 | 1204.046 | -3.229 ± 4.571 | -0.71 | [-12.371, 5.913] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Benefuture) | 1267.047 | 1269.975 | -2.928 ± 4.296 | -0.68 | [-11.520, 5.664] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Benefuture) | 1261.508 | 1263.583 | -2.076 ± 4.640 | -0.45 | [-11.356, 7.205] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Benefuture) | 41.239 | 9.240 | +31.999 ± 6.349 | +5.04 | [19.301, 44.697] | yes |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Benefuture) | 0.955 | 0.956 | -0.001 ± 0.001 | -1.27 | [-0.002, 0.000] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Status-Quo) | 816.957 | 902.589 | -85.632 ± 92.707 | -0.92 | [-271.045, 99.782] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Status-Quo) | 810.150 | 896.802 | -86.652 ± 91.905 | -0.94 | [-270.462, 97.158] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Status-Quo) | 863.917 | 950.751 | -86.834 ± 94.707 | -0.92 | [-276.247, 102.579] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Status-Quo) | 858.180 | 947.330 | -89.151 ± 94.784 | -0.94 | [-278.718, 100.417] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Status-Quo) | 41.587 | 9.068 | +32.519 ± 6.426 | +5.06 | [19.668, 45.370] | yes |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Status-Quo) | 0.956 | 0.957 | -0.000 ± 0.001 | -0.41 | [-0.002, 0.002] | no |


## 4. High-Seed Sweep: Open Question 8.85 (800-step Better-Models Takeover, `1:64` seeds, 78.7 min)

- **Takeover regime (`:decay`)**: `62 / 64` (96.9%, 95% interval `[0.891, 0.992]`)
- **Takeover regime (`:window`)**: `64 / 64` (100.0%, 95% interval `[0.941, 1.000]`)

| Metric (`1:64` paired seeds) | `:decay` Mean | `:window` Mean | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|
| Takeover count per run | 2.469 | 2.891 | -0.422 ± 0.144 | -2.93 | [-0.710, -0.134] |
| Own-currency pricing share | 0.625 | 0.555 | +0.070 ± 0.015 | +4.65 | [0.040, 0.100] |
| Floor understanding growth (`floor_u`) | 469.002 | 413.054 | +55.948 ± 24.543 | +2.28 | [6.861, 105.034] |


