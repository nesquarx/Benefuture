# Long-Horizon & Century Coupled Battery Report (L3.1–L3.3; 8.64, 8.81, 8.85, 8.86)

- **Commit**: `89d4a35`
- **Threads**: `4`
- **Workers**: `4`
- **Status**: `COMPLETED` (132.4 minutes elapsed)
- **Coupling Mode**: `continuous = true` (persistent M3c state across epochs, L3.4 / `run_coupled`)
- **Significance Standard**: Exploratory `z = 2.0`; **README / formal claim bar `z = 3.0`**, contiguous paired seeds `1:N`.
- **Pre-stated Hypotheses & Smallest Effects That Matter (`L3.3`)**:
  - *Mechanisms (`:bf` vs `:status_quo`)*: Under identical world, adversaries, noise, and shocks (`L3.1`), Benefuture (`:decay`, `advap = true`, `ratchet_k = 3`, `:eb`, `dormant_flags`, `bf_unified()`) yields higher `floor_u`, `floor_h`, `median_u`, `median_h`, smaller `worst_drop`, and higher `gov_acc` than `:status_quo` (`:window`, `advap = false`, `ratchet_k = 0`, `:normal`), with strongest advantage under `:stressed`.
  - *Stress (`:stressed` vs `:unstressed`)*: Catastrophes, outages, and metric capture degrade `floor_u`, `floor_h`, and `worst_drop` relative to `:unstressed` (which keeps breakthroughs and baseline hazards/deceivers equal).
  - *Smallest Effects That Matter*: `|Δ floor| >= 2.0`, `|Δ median| >= 2.0`, `|Δ worst_drop| >= 1.0`, `|Δ gov_acc| >= 0.01` (`1.0 pp`), at `z >= 3.0`.

## 1. 10-Year Coupled World (`:bf` × `:status_quo` × `:stressed` × `:unstressed`) (`steps = 120`, `epoch = 24`, `m5_decisions = 120`, `1:32` seeds, 26.7 min)

| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI | `z >= 3` |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Stressed) | 49.391 | 73.664 | -24.274 ± 1.947 | -12.47 | [-28.167, -20.380] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Stressed) | 49.765 | 73.999 | -24.234 ± 2.056 | -11.79 | [-28.346, -20.121] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Stressed) | 62.358 | 89.715 | -27.357 ± 2.214 | -12.36 | [-31.784, -22.930] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Stressed) | 62.033 | 90.093 | -28.059 ± 2.268 | -12.37 | [-32.596, -23.522] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Stressed) | 10.640 | 21.756 | -11.116 ± 3.700 | -3.00 | [-18.516, -3.716] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Stressed) | 0.955 | 0.944 | +0.011 ± 0.004 | +2.83 | [0.003, 0.019] | no |
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Unstressed) | 49.596 | 78.152 | -28.556 ± 1.720 | -16.60 | [-31.997, -25.115] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Unstressed) | 49.501 | 78.087 | -28.586 ± 1.606 | -17.80 | [-31.799, -25.374] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Unstressed) | 61.973 | 93.144 | -31.171 ± 1.851 | -16.84 | [-34.873, -27.469] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Unstressed) | 61.497 | 92.622 | -31.125 ± 1.794 | -17.35 | [-34.713, -27.538] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Unstressed) | 4.041 | 4.505 | -0.464 ± 0.235 | -1.97 | [-0.935, 0.007] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Unstressed) | 0.953 | 0.941 | +0.012 ± 0.004 | +3.03 | [0.004, 0.019] | yes |
| Floor U (`floor_u`) — Stressed vs Unstressed (Benefuture) | 49.391 | 49.596 | -0.206 ± 0.672 | -0.31 | [-1.550, 1.139] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Benefuture) | 49.765 | 49.501 | +0.264 ± 0.626 | +0.42 | [-0.989, 1.517] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Benefuture) | 62.358 | 61.973 | +0.385 ± 0.449 | +0.86 | [-0.514, 1.283] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Benefuture) | 62.033 | 61.497 | +0.537 ± 0.515 | +1.04 | [-0.494, 1.568] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Benefuture) | 10.640 | 4.041 | +6.599 ± 3.207 | +2.06 | [0.186, 13.012] | no |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Benefuture) | 0.955 | 0.953 | +0.002 ± 0.002 | +0.82 | [-0.003, 0.007] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Status-Quo) | 73.664 | 78.152 | -4.488 ± 1.627 | -2.76 | [-7.743, -1.233] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Status-Quo) | 73.999 | 78.087 | -4.089 ± 1.783 | -2.29 | [-7.655, -0.522] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Status-Quo) | 89.715 | 93.144 | -3.430 ± 1.900 | -1.81 | [-7.229, 0.370] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Status-Quo) | 90.093 | 92.622 | -2.529 ± 1.888 | -1.34 | [-6.305, 1.246] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Status-Quo) | 21.756 | 4.505 | +17.251 ± 3.806 | +4.53 | [9.639, 24.863] | yes |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Status-Quo) | 0.944 | 0.941 | +0.003 ± 0.003 | +0.90 | [-0.003, 0.008] | no |


## 2. 20-Year Coupled Governance (1,200 decisions as epochs; 4 factorial arms) (`steps = 240`, `epoch = 20`, `m5_decisions = 1200`, `1:32` seeds, 28.8 min)

| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI | `z >= 3` |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Stressed) | 101.257 | 186.235 | -84.978 ± 8.168 | -10.40 | [-101.314, -68.642] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Stressed) | 99.678 | 186.058 | -86.381 ± 7.964 | -10.85 | [-102.309, -70.452] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Stressed) | 117.710 | 210.960 | -93.250 ± 8.641 | -10.79 | [-110.532, -75.969] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Stressed) | 118.013 | 210.627 | -92.614 ± 8.489 | -10.91 | [-109.593, -75.635] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Stressed) | 12.382 | 41.400 | -29.018 ± 5.791 | -5.01 | [-40.600, -17.436] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Stressed) | 0.963 | 0.962 | +0.001 ± 0.001 | +1.00 | [-0.001, 0.004] | no |
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Unstressed) | 101.882 | 178.013 | -76.131 ± 10.453 | -7.28 | [-97.037, -55.226] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Unstressed) | 100.290 | 177.166 | -76.876 ± 10.395 | -7.40 | [-97.666, -56.085] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Unstressed) | 119.224 | 199.818 | -80.595 ± 11.302 | -7.13 | [-103.198, -57.991] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Unstressed) | 118.831 | 199.161 | -80.329 ± 11.204 | -7.17 | [-102.738, -57.921] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Unstressed) | 5.667 | 4.980 | +0.687 ± 0.948 | +0.72 | [-1.210, 2.583] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Unstressed) | 0.963 | 0.961 | +0.002 ± 0.001 | +1.40 | [-0.001, 0.004] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Benefuture) | 101.257 | 101.882 | -0.625 ± 1.214 | -0.51 | [-3.053, 1.804] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Benefuture) | 99.678 | 100.290 | -0.612 ± 1.284 | -0.48 | [-3.181, 1.956] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Benefuture) | 117.710 | 119.224 | -1.514 ± 1.326 | -1.14 | [-4.166, 1.139] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Benefuture) | 118.013 | 118.831 | -0.818 ± 1.279 | -0.64 | [-3.377, 1.741] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Benefuture) | 12.382 | 5.667 | +6.715 ± 3.796 | +1.77 | [-0.876, 14.306] | no |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Benefuture) | 0.963 | 0.963 | -0.000 ± 0.001 | -0.12 | [-0.002, 0.002] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Status-Quo) | 186.235 | 178.013 | +8.222 ± 9.879 | +0.83 | [-11.536, 27.980] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Status-Quo) | 186.058 | 177.166 | +8.893 ± 9.786 | +0.91 | [-10.680, 28.465] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Status-Quo) | 210.960 | 199.818 | +11.142 ± 10.668 | +1.04 | [-10.194, 32.478] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Status-Quo) | 210.627 | 199.161 | +11.466 ± 10.604 | +1.08 | [-9.742, 32.675] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Status-Quo) | 41.400 | 4.980 | +36.420 ± 6.098 | +5.97 | [24.223, 48.616] | yes |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Status-Quo) | 0.962 | 0.961 | +0.000 ± 0.000 | +0.50 | [-0.001, 0.001] | no |


## 3. 100-Year Coupled Century World (4 factorial arms) (`steps = 1200`, `epoch = 25`, `m5_decisions = 1200`, `1:32` seeds, 51.8 min)

| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI | `z >= 3` |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Stressed) | 504.165 | 600.284 | -96.120 ± 80.925 | -1.19 | [-257.969, 65.729] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Stressed) | 502.635 | 596.973 | -94.339 ± 80.222 | -1.18 | [-254.783, 66.106] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Stressed) | 543.770 | 636.667 | -92.897 ± 83.416 | -1.11 | [-259.729, 73.935] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Stressed) | 540.044 | 633.750 | -93.706 ± 82.779 | -1.13 | [-259.264, 71.852] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Stressed) | 10.222 | 16.104 | -5.882 ± 4.191 | -1.40 | [-14.264, 2.499] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Stressed) | 0.958 | 0.955 | +0.003 ± 0.001 | +1.98 | [-0.000, 0.005] | no |
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Unstressed) | 497.415 | 557.933 | -60.518 ± 82.540 | -0.73 | [-225.598, 104.561] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Unstressed) | 494.366 | 556.110 | -61.744 ± 82.351 | -0.75 | [-226.447, 102.959] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Unstressed) | 536.749 | 593.340 | -56.591 ± 85.528 | -0.66 | [-227.648, 114.465] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Unstressed) | 533.508 | 592.193 | -58.685 ± 85.313 | -0.69 | [-229.312, 111.941] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Unstressed) | 7.272 | 8.682 | -1.409 ± 1.958 | -0.72 | [-5.325, 2.507] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Unstressed) | 0.955 | 0.956 | -0.001 ± 0.001 | -1.05 | [-0.004, 0.001] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Benefuture) | 504.165 | 497.415 | +6.750 ± 4.723 | +1.43 | [-2.696, 16.196] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Benefuture) | 502.635 | 494.366 | +8.269 ± 5.037 | +1.64 | [-1.805, 18.342] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Benefuture) | 543.770 | 536.749 | +7.021 ± 4.791 | +1.47 | [-2.562, 16.604] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Benefuture) | 540.044 | 533.508 | +6.536 ± 4.892 | +1.34 | [-3.249, 16.321] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Benefuture) | 10.222 | 7.272 | +2.949 ± 1.727 | +1.71 | [-0.504, 6.403] | no |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Benefuture) | 0.958 | 0.955 | +0.003 ± 0.001 | +4.11 | [0.002, 0.005] | yes |
| Floor U (`floor_u`) — Stressed vs Unstressed (Status-Quo) | 600.284 | 557.933 | +42.351 ± 64.715 | +0.65 | [-87.079, 171.782] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Status-Quo) | 596.973 | 556.110 | +40.864 ± 64.638 | +0.63 | [-88.412, 170.140] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Status-Quo) | 636.667 | 593.340 | +43.327 ± 66.829 | +0.65 | [-90.330, 176.984] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Status-Quo) | 633.750 | 592.193 | +41.557 ± 66.324 | +0.63 | [-91.091, 174.205] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Status-Quo) | 16.104 | 8.682 | +7.423 ± 3.498 | +2.12 | [0.426, 14.419] | no |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Status-Quo) | 0.955 | 0.956 | -0.000 ± 0.001 | -0.63 | [-0.002, 0.001] | no |


## 4. High-Seed Sweep: Open Question 8.85 (800-step Better-Models Takeover, `1:64` seeds, 25.0 min)

- **Takeover regime (`:decay`)**: `64 / 64` (100.0%, 95% interval `[0.941, 1.000]`)
- **Takeover regime (`:window`)**: `63 / 64` (98.4%, 95% interval `[0.914, 0.997]`)

| Metric (`1:64` paired seeds) | `:decay` Mean | `:window` Mean | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|
| Takeover count per run | 2.375 | 2.781 | -0.406 ± 0.129 | -3.14 | [-0.665, -0.148] |
| Own-currency pricing share | 0.651 | 0.589 | +0.062 ± 0.013 | +4.67 | [0.035, 0.088] |
| Floor understanding growth (`floor_u`) | 495.578 | 483.580 | +11.998 ± 6.312 | +1.90 | [-0.626, 24.623] |


