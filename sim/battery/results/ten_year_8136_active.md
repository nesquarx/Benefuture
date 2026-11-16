# 10-Year Coupled Economy with Author Ruling 8.136 On

- **Build**: commit `aba08fc`. Horizon: `120` steps (`10` years), `epoch = 24` (`2` years), `m5_decisions = 120`, `continuous = true`.
- **Seeds**: `1:64` paired seeds (`min = 64`, `max = 64`, stopping when t-inflated SE of `floor_u(bf_8136 - sq) <= 1.50` in both `:stressed` and `:unstressed`; stopped_early = `false`). Run time: `297.8` minutes.
- **Arms**: `:bf_8136` (`:bf` + `converge_init = true`, `legacy_funder = true`, `shadow = true`), `:bf_base` (`long_horizon.jl` default `:bf`), `:status_quo` (`long_horizon.jl` default `:status_quo`), plus warmup-matched controls `:bf_leg50` (`:bf` + `init_steps = 50`, `legacy_funder = true`, `shadow = true`) and `:sq_leg50` (`:status_quo` + `init_steps = 50`, `legacy_funder = true`).
- **Significance Bar**: `z = 3.0` Student-t inflated (two-sided reported as `yes (+)` / `yes (-)`, 99.7% Student-t CI `[ci_lo, ci_hi]`).

## Pre-registered Predictions (stated before running)
- **P5 (confidence 0.6)**: The 10-year `floor_u` difference (`:bf_8136` minus `:status_quo`) becomes significant at `z >= 3` (`z * t_inflation`).
- **P6 (confidence 0.7)**: The early dip in the first two years (`steps 1..24`) shrinks under `:bf_8136` relative to `:bf_base` (and `:status_quo`).
- **P8 (confidence 0.85, active-leaf unblocked)**: With `domain_converged` gating on active known leaves (`m3c.jl`), `:bf_8136` exits the `0/64` sparse-focus deadlock and converges on a majority (`> 50%`) of seeds before step 120.
- **P9 (confidence 0.55, live graduation)**: Dynamic graduation around `converge_step` preserves the Y1–2 early-dip reduction (`< bf_base`) while finishing higher or indistinguishable vs warmup-matched `:sq_leg50` over 10 years.
- **Diagnostic on failure**: If P5 fails, inspect the year-by-year trajectory (`Years 1..10`) to identify where Benefuture diverges (no tuning).

## 8.136 Activation & Diagnostics (`:bf_8136` and `:bf_leg50`)
- **Stressed `:bf_8136`**: converged `61 / 64` (mean `converge_step = 29.1`), mean `legacy_executed = 313.8`, `shadow_promoted = 0 / 64`.
- **Stressed `:bf_leg50` vs `:sq_leg50`**: mean `legacy_executed = 484.9` vs `484.9` (`init_steps = 50`), `:bf_leg50` `shadow_promoted = 0 / 64`.
- **Unstressed `:bf_8136`**: converged `64 / 64` (mean `converge_step = 29.6`), mean `legacy_executed = 276.9`, `shadow_promoted = 0 / 64`.
- **Unstressed `:bf_leg50` vs `:sq_leg50`**: mean `legacy_executed = 484.8` vs `484.8` (`init_steps = 50`), `:bf_leg50` `shadow_promoted = 0 / 64`.

## 10-Year Endpoint Comparisons — Stressed (`1:64` seeds)

### :bf_8136 vs :status_quo (Stressed)

| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) | 122.858 | 73.857 | +49.001 ± 1.965 | +24.93 (3.00) | [+43.105, +54.898] | yes (+) |
| Floor H (`floor_h`) | 122.359 | 73.197 | +49.162 ± 1.899 | +25.88 (3.00) | [+43.464, +54.860] | yes (+) |
| Median U (`median_u`) | 143.379 | 90.237 | +53.141 ± 2.169 | +24.50 (3.00) | [+46.635, +59.648] | yes (+) |
| Median H (`median_h`) | 142.879 | 89.537 | +53.342 ± 2.112 | +25.26 (3.00) | [+47.006, +59.678] | yes (+) |
| Worst drop (`worst_drop`) | 21.623 | 27.188 | -5.565 ± 4.438 | -1.25 (3.00) | [-18.880, +7.750] | no |
| Governance acc (`gov_acc`) | 0.953 | 0.950 | +0.003 ± 0.002 | +1.30 (3.00) | [-0.004, +0.010] | no |

### :bf_8136 vs :bf_base (Stressed)

| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) | 122.858 | 78.107 | +44.752 ± 1.287 | +34.77 (3.00) | [+40.891, +48.612] | yes (+) |
| Floor H (`floor_h`) | 122.359 | 77.595 | +44.764 ± 1.201 | +37.28 (3.00) | [+41.162, +48.366] | yes (+) |
| Median U (`median_u`) | 143.379 | 95.093 | +48.286 ± 1.300 | +37.16 (3.00) | [+44.388, +52.185] | yes (+) |
| Median H (`median_h`) | 142.879 | 94.336 | +48.543 ± 1.255 | +38.67 (3.00) | [+44.777, +52.309] | yes (+) |
| Worst drop (`worst_drop`) | 21.623 | 26.821 | -5.198 ± 4.327 | -1.20 (3.00) | [-18.179, +7.784] | no |
| Governance acc (`gov_acc`) | 0.953 | 0.953 | +0.001 ± 0.002 | +0.33 (3.00) | [-0.006, +0.008] | no |

### :bf_base vs :status_quo (Stressed)

| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) | 78.107 | 73.857 | +4.250 ± 1.799 | +2.36 (3.00) | [-1.146, +9.646] | no |
| Floor H (`floor_h`) | 77.595 | 73.197 | +4.398 ± 1.757 | +2.50 (3.00) | [-0.874, +9.670] | no |
| Median U (`median_u`) | 95.093 | 90.237 | +4.855 ± 1.961 | +2.48 (3.00) | [-1.027, +10.737] | no |
| Median H (`median_h`) | 94.336 | 89.537 | +4.799 ± 1.951 | +2.46 (3.00) | [-1.055, +10.653] | no |
| Worst drop (`worst_drop`) | 26.821 | 27.188 | -0.367 ± 1.119 | -0.33 (3.00) | [-3.724, +2.989] | no |
| Governance acc (`gov_acc`) | 0.953 | 0.951 | +0.002 ± 0.001 | +1.93 (3.00) | [-0.001, +0.006] | no |

### :bf_leg50 vs :sq_leg50 (Stressed)

| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) | 127.046 | 125.826 | +1.220 ± 1.000 | +1.22 (3.00) | [-1.781, +4.221] | no |
| Floor H (`floor_h`) | 126.286 | 124.908 | +1.378 ± 1.005 | +1.37 (3.00) | [-1.637, +4.393] | no |
| Median U (`median_u`) | 147.945 | 146.468 | +1.477 ± 0.998 | +1.48 (3.00) | [-1.516, +4.470] | no |
| Median H (`median_h`) | 147.873 | 145.914 | +1.959 ± 1.015 | +1.93 (3.00) | [-1.086, +5.005] | no |
| Worst drop (`worst_drop`) | 22.511 | 23.171 | -0.660 ± 0.811 | -0.81 (3.00) | [-3.093, +1.773] | no |
| Governance acc (`gov_acc`) | 0.955 | 0.949 | +0.007 ± 0.004 | +1.66 (3.00) | [-0.005, +0.018] | no |

### :bf_8136 vs :sq_leg50 (Stressed)

| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) | 122.858 | 125.826 | -2.967 ± 1.771 | -1.68 (3.00) | [-8.281, +2.346] | no |
| Floor H (`floor_h`) | 122.359 | 124.908 | -2.549 ± 1.703 | -1.50 (3.00) | [-7.656, +2.559] | no |
| Median U (`median_u`) | 143.379 | 146.468 | -3.090 ± 1.868 | -1.65 (3.00) | [-8.693, +2.514] | no |
| Median H (`median_h`) | 142.879 | 145.914 | -3.035 ± 1.839 | -1.65 (3.00) | [-8.553, +2.483] | no |
| Worst drop (`worst_drop`) | 21.623 | 23.171 | -1.548 ± 1.739 | -0.89 (3.00) | [-6.765, +3.670] | no |
| Governance acc (`gov_acc`) | 0.953 | 0.949 | +0.004 ± 0.003 | +1.66 (3.00) | [-0.004, +0.012] | no |

## 10-Year Endpoint Comparisons — Unstressed (`1:64` seeds)

### :bf_8136 vs :status_quo (Unstressed)

| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) | 124.105 | 79.187 | +44.918 ± 1.284 | +34.97 (3.00) | [+41.065, +48.771] | yes (+) |
| Floor H (`floor_h`) | 123.670 | 78.843 | +44.828 ± 1.201 | +37.34 (3.00) | [+41.226, +48.430] | yes (+) |
| Median U (`median_u`) | 143.156 | 94.100 | +49.056 ± 1.349 | +36.36 (3.00) | [+45.008, +53.104] | yes (+) |
| Median H (`median_h`) | 143.089 | 93.654 | +49.435 ± 1.327 | +37.26 (3.00) | [+45.455, +53.414] | yes (+) |
| Worst drop (`worst_drop`) | 6.908 | 6.468 | +0.440 ± 0.150 | +2.94 (3.00) | [-0.008, +0.889] | no |
| Governance acc (`gov_acc`) | 0.955 | 0.953 | +0.003 ± 0.003 | +1.01 (3.00) | [-0.005, +0.010] | no |

### :bf_8136 vs :bf_base (Unstressed)

| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) | 124.105 | 80.637 | +43.468 ± 1.038 | +41.86 (3.00) | [+40.353, +46.583] | yes (+) |
| Floor H (`floor_h`) | 123.670 | 79.889 | +43.781 ± 0.928 | +47.17 (3.00) | [+40.997, +46.566] | yes (+) |
| Median U (`median_u`) | 143.156 | 95.202 | +47.954 ± 1.070 | +44.81 (3.00) | [+44.744, +51.165] | yes (+) |
| Median H (`median_h`) | 143.089 | 94.444 | +48.644 ± 1.004 | +48.44 (3.00) | [+45.632, +51.657] | yes (+) |
| Worst drop (`worst_drop`) | 6.908 | 6.437 | +0.471 ± 0.147 | +3.21 (3.00) | [+0.031, +0.912] | yes (+) |
| Governance acc (`gov_acc`) | 0.955 | 0.954 | +0.002 ± 0.002 | +0.71 (3.00) | [-0.006, +0.009] | no |

### :bf_base vs :status_quo (Unstressed)

| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) | 80.637 | 79.187 | +1.450 ± 0.854 | +1.70 (3.00) | [-1.113, +4.013] | no |
| Floor H (`floor_h`) | 79.889 | 78.843 | +1.047 ± 0.822 | +1.27 (3.00) | [-1.420, +3.513] | no |
| Median U (`median_u`) | 95.202 | 94.100 | +1.102 ± 0.944 | +1.17 (3.00) | [-1.732, +3.935] | no |
| Median H (`median_h`) | 94.444 | 93.654 | +0.790 ± 0.871 | +0.91 (3.00) | [-1.822, +3.402] | no |
| Worst drop (`worst_drop`) | 6.437 | 6.468 | -0.031 ± 0.092 | -0.33 (3.00) | [-0.308, +0.246] | no |
| Governance acc (`gov_acc`) | 0.954 | 0.953 | +0.001 ± 0.001 | +1.00 (3.00) | [-0.002, +0.003] | no |

### :bf_leg50 vs :sq_leg50 (Unstressed)

| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) | 130.042 | 126.643 | +3.399 ± 1.645 | +2.07 (3.00) | [-1.535, +8.333] | no |
| Floor H (`floor_h`) | 129.270 | 125.834 | +3.436 ± 1.672 | +2.06 (3.00) | [-1.579, +8.451] | no |
| Median U (`median_u`) | 150.062 | 146.227 | +3.835 ± 1.781 | +2.15 (3.00) | [-1.509, +9.178] | no |
| Median H (`median_h`) | 149.662 | 145.973 | +3.689 ± 1.851 | +1.99 (3.00) | [-1.864, +9.241] | no |
| Worst drop (`worst_drop`) | 6.856 | 6.918 | -0.062 ± 0.076 | -0.82 (3.00) | [-0.289, +0.165] | no |
| Governance acc (`gov_acc`) | 0.953 | 0.953 | +0.001 ± 0.004 | +0.18 (3.00) | [-0.010, +0.012] | no |

### :bf_8136 vs :sq_leg50 (Unstressed)

| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) | 124.105 | 126.643 | -2.538 ± 1.796 | -1.41 (3.00) | [-7.924, +2.849] | no |
| Floor H (`floor_h`) | 123.670 | 125.834 | -2.163 ± 1.864 | -1.16 (3.00) | [-7.755, +3.428] | no |
| Median U (`median_u`) | 143.156 | 146.227 | -3.071 ± 2.019 | -1.52 (3.00) | [-9.128, +2.987] | no |
| Median H (`median_h`) | 143.089 | 145.973 | -2.884 ± 2.061 | -1.40 (3.00) | [-9.067, +3.299] | no |
| Worst drop (`worst_drop`) | 6.908 | 6.918 | -0.010 ± 0.087 | -0.11 (3.00) | [-0.272, +0.252] | no |
| Governance acc (`gov_acc`) | 0.955 | 0.953 | +0.003 ± 0.003 | +0.97 (3.00) | [-0.005, +0.011] | no |

## P6: Early-Dip Comparisons (First Two Years, `steps 1..24`)

### :bf_8136 vs :status_quo — Stressed

| Early Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Early floor U dip (`max(0, u0 - min u[1:24])`) | 0.031 | 1.081 | -1.050 ± 0.322 | -3.26 (3.00) | [-2.015, -0.085] | yes (-) |
| Early floor H dip (`max(0, h0 - min h[1:24])`) | 0.033 | 1.216 | -1.183 ± 0.348 | -3.40 (3.00) | [-2.228, -0.138] | yes (-) |
| Early worst single-being drop (`max worst_drop[1:24]`) | 11.070 | 14.250 | -3.179 ± 4.293 | -0.74 (3.00) | [-16.058, +9.699] | no |
| Year-2 net Floor U (`u[24] - u0`) | 20.637 | 1.737 | +18.900 ± 0.427 | +44.29 (3.00) | [+17.619, +20.180] | yes (+) |
| Year-2 net Floor H (`h[24] - h0`) | 20.465 | 1.470 | +18.995 ± 0.417 | +45.51 (3.00) | [+17.743, +20.247] | yes (+) |

### :bf_8136 vs :bf_base — Stressed

| Early Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Early floor U dip (`max(0, u0 - min u[1:24])`) | 0.031 | 1.081 | -1.050 ± 0.322 | -3.26 (3.00) | [-2.015, -0.085] | yes (-) |
| Early floor H dip (`max(0, h0 - min h[1:24])`) | 0.033 | 1.216 | -1.183 ± 0.348 | -3.40 (3.00) | [-2.228, -0.138] | yes (-) |
| Early worst single-being drop (`max worst_drop[1:24]`) | 11.070 | 14.255 | -3.185 ± 4.293 | -0.74 (3.00) | [-16.063, +9.693] | no |
| Year-2 net Floor U (`u[24] - u0`) | 20.637 | 1.740 | +18.897 ± 0.427 | +44.29 (3.00) | [+17.617, +20.177] | yes (+) |
| Year-2 net Floor H (`h[24] - h0`) | 20.465 | 1.475 | +18.990 ± 0.418 | +45.47 (3.00) | [+17.737, +20.243] | yes (+) |

### :bf_leg50 vs :sq_leg50 — Stressed

| Early Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Early floor U dip (`max(0, u0 - min u[1:24])`) | 0.031 | 0.031 | +0.000 ± 0.000 | +0.00 (3.00) | [+0.000, +0.000] | no |
| Early floor H dip (`max(0, h0 - min h[1:24])`) | 0.033 | 0.033 | +0.000 ± 0.000 | +0.00 (3.00) | [+0.000, +0.000] | no |
| Early worst single-being drop (`max worst_drop[1:24]`) | 11.124 | 11.124 | +0.000 ± 0.000 | +0.00 (3.00) | [+0.000, +0.000] | no |
| Year-2 net Floor U (`u[24] - u0`) | 20.863 | 20.866 | -0.003 ± 0.008 | -0.35 (3.00) | [-0.028, +0.022] | no |
| Year-2 net Floor H (`h[24] - h0`) | 20.668 | 20.668 | -0.000 ± 0.005 | -0.04 (3.00) | [-0.014, +0.014] | no |

### :bf_8136 vs :sq_leg50 — Stressed

| Early Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Early floor U dip (`max(0, u0 - min u[1:24])`) | 0.031 | 0.031 | +0.000 ± 0.000 | +0.00 (3.00) | [+0.000, +0.000] | no |
| Early floor H dip (`max(0, h0 - min h[1:24])`) | 0.033 | 0.033 | +0.000 ± 0.000 | +0.00 (3.00) | [+0.000, +0.000] | no |
| Early worst single-being drop (`max worst_drop[1:24]`) | 11.070 | 11.124 | -0.054 ± 0.040 | -1.36 (3.00) | [-0.173, +0.065] | no |
| Year-2 net Floor U (`u[24] - u0`) | 20.637 | 20.866 | -0.229 ± 0.101 | -2.26 (3.00) | [-0.533, +0.075] | no |
| Year-2 net Floor H (`h[24] - h0`) | 20.465 | 20.668 | -0.203 ± 0.073 | -2.76 (3.00) | [-0.423, +0.017] | no |

### :bf_8136 vs :status_quo — Unstressed

| Early Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Early floor U dip (`max(0, u0 - min u[1:24])`) | 0.031 | 0.020 | +0.011 ± 0.013 | +0.81 (3.00) | [-0.029, +0.050] | no |
| Early floor H dip (`max(0, h0 - min h[1:24])`) | 0.033 | 0.035 | -0.002 ± 0.011 | -0.15 (3.00) | [-0.036, +0.032] | no |
| Early worst single-being drop (`max worst_drop[1:24]`) | 4.244 | 2.714 | +1.531 ± 0.151 | +10.15 (3.00) | [+1.078, +1.983] | yes (+) |
| Year-2 net Floor U (`u[24] - u0`) | 21.728 | 3.445 | +18.283 ± 0.295 | +61.93 (3.00) | [+17.397, +19.168] | yes (+) |
| Year-2 net Floor H (`h[24] - h0`) | 21.477 | 3.282 | +18.195 ± 0.285 | +63.84 (3.00) | [+17.340, +19.051] | yes (+) |

### :bf_8136 vs :bf_base — Unstressed

| Early Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Early floor U dip (`max(0, u0 - min u[1:24])`) | 0.031 | 0.020 | +0.011 ± 0.013 | +0.81 (3.00) | [-0.029, +0.050] | no |
| Early floor H dip (`max(0, h0 - min h[1:24])`) | 0.033 | 0.035 | -0.002 ± 0.011 | -0.15 (3.00) | [-0.036, +0.032] | no |
| Early worst single-being drop (`max worst_drop[1:24]`) | 4.244 | 2.719 | +1.525 ± 0.151 | +10.11 (3.00) | [+1.073, +1.977] | yes (+) |
| Year-2 net Floor U (`u[24] - u0`) | 21.728 | 3.447 | +18.281 ± 0.295 | +61.98 (3.00) | [+17.396, +19.166] | yes (+) |
| Year-2 net Floor H (`h[24] - h0`) | 21.477 | 3.288 | +18.189 ± 0.285 | +63.81 (3.00) | [+17.334, +19.044] | yes (+) |

### :bf_leg50 vs :sq_leg50 — Unstressed

| Early Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Early floor U dip (`max(0, u0 - min u[1:24])`) | 0.031 | 0.031 | +0.000 ± 0.000 | +0.00 (3.00) | [+0.000, +0.000] | no |
| Early floor H dip (`max(0, h0 - min h[1:24])`) | 0.033 | 0.033 | +0.000 ± 0.000 | +0.00 (3.00) | [+0.000, +0.000] | no |
| Early worst single-being drop (`max worst_drop[1:24]`) | 4.268 | 4.268 | +0.000 ± 0.000 | +0.00 (3.00) | [+0.000, +0.000] | no |
| Year-2 net Floor U (`u[24] - u0`) | 21.990 | 21.993 | -0.003 ± 0.008 | -0.35 (3.00) | [-0.028, +0.022] | no |
| Year-2 net Floor H (`h[24] - h0`) | 21.662 | 21.662 | -0.000 ± 0.005 | -0.04 (3.00) | [-0.014, +0.014] | no |

### :bf_8136 vs :sq_leg50 — Unstressed

| Early Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |
|---|---|---|---|---|---|---|
| Early floor U dip (`max(0, u0 - min u[1:24])`) | 0.031 | 0.031 | +0.000 ± 0.000 | +0.00 (3.00) | [+0.000, +0.000] | no |
| Early floor H dip (`max(0, h0 - min h[1:24])`) | 0.033 | 0.033 | +0.000 ± 0.000 | +0.00 (3.00) | [+0.000, +0.000] | no |
| Early worst single-being drop (`max worst_drop[1:24]`) | 4.244 | 4.268 | -0.024 ± 0.017 | -1.39 (3.00) | [-0.074, +0.027] | no |
| Year-2 net Floor U (`u[24] - u0`) | 21.728 | 21.993 | -0.265 ± 0.095 | -2.80 (3.00) | [-0.550, +0.019] | no |
| Year-2 net Floor H (`h[24] - h0`) | 21.477 | 21.662 | -0.185 ± 0.080 | -2.31 (3.00) | [-0.425, +0.055] | no |

## Year-by-Year Floor U Trajectory (`Years 1..10`, Cumulative Growth & Annual Δ)

### Stressed — `:bf_8136` vs `:status_quo` (and `:bf_base`)

| Year (Step) | `:bf_8136` Cum | `:bf_base` Cum | `:sq` Cum | `8136 − SQ` Cum ± SE (`z`) | Annual Δ `8136` | Annual Δ `SQ` | Annual Δ `8136 − SQ` ± SE (`z`) |
|---|---|---|---|---|---|---|---|
| Y1 (12) | 9.33 | 1.34 | 1.34 | +7.99 ± 0.13 (+63.42) | +9.33 | +1.34 | +7.99 ± 0.13 (+63.42) |
| Y2 (24) | 20.64 | 1.74 | 1.74 | +18.90 ± 0.43 (+44.29) | +11.31 | +0.39 | +10.91 ± 0.40 (+27.33) |
| Y3 (36) | 33.04 | 4.14 | 4.11 | +28.93 ± 0.47 (+62.15) | +12.40 | +2.37 | +10.03 ± 0.24 (+42.16) |
| Y4 (48) | 45.57 | 6.87 | 6.88 | +38.69 ± 0.59 (+65.09) | +12.54 | +2.77 | +9.76 ± 0.28 (+34.82) |
| Y5 (60) | 57.28 | 16.19 | 16.21 | +41.07 ± 0.69 (+59.27) | +11.70 | +9.33 | +2.37 ± 0.32 (+7.39) |
| Y6 (72) | 67.44 | 25.60 | 24.61 | +42.83 ± 0.87 (+49.45) | +10.16 | +8.40 | +1.76 ± 0.53 (+3.35) |
| Y7 (84) | 81.64 | 38.27 | 36.93 | +44.72 ± 1.00 (+44.59) | +14.20 | +12.32 | +1.89 ± 0.45 (+4.17) |
| Y8 (96) | 95.05 | 51.13 | 49.02 | +46.03 ± 1.25 (+36.72) | +13.40 | +12.09 | +1.32 ± 0.51 (+2.59) |
| Y9 (108) | 108.93 | 64.58 | 61.36 | +47.57 ± 1.59 (+29.85) | +13.88 | +12.34 | +1.54 ± 0.61 (+2.53) |
| Y10 (120) | 122.86 | 78.11 | 73.86 | +49.00 ± 1.97 (+24.93) | +13.93 | +12.50 | +1.43 ± 0.59 (+2.42) |

### Stressed — Warmup-Matched `:bf_leg50` vs `:sq_leg50` (`init_steps = 50`, `legacy_funder = true`)

| Year (Step) | `:bf_leg50` Cum | `:sq_leg50` Cum | `bf_leg50 − sq_leg50` Cum ± SE (`z`) | Annual Δ `bf_leg50` | Annual Δ `sq_leg50` | Annual Δ Diff ± SE (`z`) |
|---|---|---|---|---|---|---|
| Y1 (12) | 9.33 | 9.32 | +0.01 ± 0.01 (+1.00) | +9.33 | +9.32 | +0.01 ± 0.01 (+1.00) |
| Y2 (24) | 20.86 | 20.87 | -0.00 ± 0.01 (-0.35) | +11.53 | +11.54 | -0.01 ± 0.01 (-1.18) |
| Y3 (36) | 34.64 | 34.64 | +0.01 ± 0.02 (+0.29) | +13.78 | +13.77 | +0.01 ± 0.02 (+0.38) |
| Y4 (48) | 49.53 | 49.51 | +0.03 ± 0.02 (+1.14) | +14.89 | +14.87 | +0.02 ± 0.03 (+0.65) |
| Y5 (60) | 61.62 | 62.23 | -0.61 ± 0.26 (-2.37) | +12.09 | +12.73 | -0.64 ± 0.26 (-2.50) |
| Y6 (72) | 72.06 | 72.06 | +0.01 ± 0.39 (+0.02) | +10.44 | +9.82 | +0.62 ± 0.41 (+1.52) |
| Y7 (84) | 85.88 | 85.73 | +0.15 ± 0.47 (+0.32) | +13.82 | +13.68 | +0.14 ± 0.34 (+0.42) |
| Y8 (96) | 99.28 | 98.65 | +0.63 ± 0.58 (+1.09) | +13.40 | +12.92 | +0.48 ± 0.40 (+1.21) |
| Y9 (108) | 112.68 | 112.45 | +0.22 ± 0.81 (+0.28) | +13.39 | +13.80 | -0.41 ± 0.44 (-0.93) |
| Y10 (120) | 127.05 | 125.83 | +1.22 ± 1.00 (+1.22) | +14.37 | +13.37 | +1.00 ± 0.48 (+2.06) |

### Unstressed — `:bf_8136` vs `:status_quo` (and `:bf_base`)

| Year (Step) | `:bf_8136` Cum | `:bf_base` Cum | `:sq` Cum | `8136 − SQ` Cum ± SE (`z`) | Annual Δ `8136` | Annual Δ `SQ` | Annual Δ `8136 − SQ` ± SE (`z`) |
|---|---|---|---|---|---|---|---|
| Y1 (12) | 9.33 | 1.34 | 1.34 | +7.99 ± 0.13 (+63.42) | +9.33 | +1.34 | +7.99 ± 0.13 (+63.42) |
| Y2 (24) | 21.73 | 3.45 | 3.45 | +18.28 ± 0.30 (+61.93) | +12.40 | +2.10 | +10.30 ± 0.25 (+41.94) |
| Y3 (36) | 33.63 | 5.68 | 5.69 | +27.94 ± 0.39 (+71.84) | +11.90 | +2.24 | +9.66 ± 0.23 (+41.95) |
| Y4 (48) | 45.99 | 8.38 | 8.28 | +37.71 ± 0.52 (+72.50) | +12.36 | +2.59 | +9.77 ± 0.26 (+37.61) |
| Y5 (60) | 57.02 | 16.80 | 16.93 | +40.08 ± 0.69 (+58.10) | +11.03 | +8.66 | +2.37 ± 0.31 (+7.71) |
| Y6 (72) | 68.40 | 27.44 | 27.24 | +41.16 ± 0.85 (+48.54) | +11.38 | +10.31 | +1.08 ± 0.34 (+3.20) |
| Y7 (84) | 82.34 | 40.44 | 39.92 | +42.42 ± 0.88 (+47.95) | +13.93 | +12.68 | +1.26 ± 0.30 (+4.13) |
| Y8 (96) | 96.67 | 54.17 | 52.92 | +43.75 ± 0.95 (+46.25) | +14.33 | +13.00 | +1.34 ± 0.35 (+3.77) |
| Y9 (108) | 110.07 | 67.12 | 66.08 | +43.99 ± 1.10 (+39.86) | +13.40 | +13.16 | +0.23 ± 0.42 (+0.56) |
| Y10 (120) | 124.11 | 80.64 | 79.19 | +44.92 ± 1.28 (+34.97) | +14.04 | +13.10 | +0.93 ± 0.45 (+2.05) |

### Unstressed — Warmup-Matched `:bf_leg50` vs `:sq_leg50` (`init_steps = 50`, `legacy_funder = true`)

| Year (Step) | `:bf_leg50` Cum | `:sq_leg50` Cum | `bf_leg50 − sq_leg50` Cum ± SE (`z`) | Annual Δ `bf_leg50` | Annual Δ `sq_leg50` | Annual Δ Diff ± SE (`z`) |
|---|---|---|---|---|---|---|
| Y1 (12) | 9.33 | 9.32 | +0.01 ± 0.01 (+1.00) | +9.33 | +9.32 | +0.01 ± 0.01 (+1.00) |
| Y2 (24) | 21.99 | 21.99 | -0.00 ± 0.01 (-0.35) | +12.66 | +12.67 | -0.01 ± 0.01 (-1.18) |
| Y3 (36) | 35.75 | 35.76 | -0.00 ± 0.02 (-0.09) | +13.76 | +13.76 | +0.00 ± 0.02 (+0.05) |
| Y4 (48) | 50.39 | 50.33 | +0.06 ± 0.04 (+1.29) | +14.63 | +14.57 | +0.06 ± 0.05 (+1.25) |
| Y5 (60) | 62.34 | 62.50 | -0.16 ± 0.23 (-0.69) | +11.95 | +12.17 | -0.22 ± 0.23 (-0.92) |
| Y6 (72) | 74.10 | 74.10 | +0.00 ± 0.38 (+0.01) | +11.76 | +11.60 | +0.16 ± 0.38 (+0.43) |
| Y7 (84) | 88.11 | 87.45 | +0.67 ± 0.60 (+1.11) | +14.01 | +13.34 | +0.66 ± 0.47 (+1.41) |
| Y8 (96) | 102.11 | 101.04 | +1.07 ± 0.88 (+1.22) | +14.00 | +13.59 | +0.41 ± 0.53 (+0.77) |
| Y9 (108) | 115.87 | 113.67 | +2.21 ± 1.25 (+1.77) | +13.76 | +12.63 | +1.13 ± 0.55 (+2.07) |
| Y10 (120) | 130.04 | 126.64 | +3.40 ± 1.64 (+2.07) | +14.17 | +12.98 | +1.19 ± 0.53 (+2.27) |

