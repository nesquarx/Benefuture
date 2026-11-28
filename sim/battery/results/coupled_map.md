# Continuous-Coupled Break-Even & Threshold Map (`z = 3.0`, Student-t inflated)

- **Commit**: `1bad6f6` · **Runtime**: `21.2 min` · **Workers**: `4`

## 1. Coupled Break-Even & Open-Entry Horizons (`10yr..50yr`, `1:24` seeds, `:stressed`, `epoch = 24`)
| Horizon (`steps`) | Arm Pair | `floor_u` Δ ± SE (`z_raw`, `z>=3`) | `floor_h` Δ ± SE (`z_raw`, `z>=3`) | `median_u` Δ ± SE | `gov_acc` Δ ± SE | `entries` (`bf_open`) |
|---|---|---|---|---|---|---|
| `120` (`10yr`) | `:bf_closed - :sq_closed` | -26.09 ± 1.39 (`-18.84`, no) | -25.95 ± 1.67 (`-15.57`, no) | -29.30 ± 1.65 | +0.0174 ± 0.0097 | 7.96 |
| `120` (`10yr`) | `:bf_open - :sq_closed` | -25.11 ± 2.68 (`-9.36`, no) | -25.45 ± 2.87 (`-8.87`, no) | -28.72 ± 3.00 | +0.0194 ± 0.0130 | 7.96 |
| `240` (`20yr`) | `:bf_closed - :sq_closed` | -81.19 ± 11.32 (`-7.17`, no) | -80.51 ± 11.15 (`-7.22`, no) | -87.09 ± 11.44 | +0.0010 ± 0.0046 | 8.00 |
| `240` (`20yr`) | `:bf_open - :sq_closed` | -69.16 ± 10.84 (`-6.38`, no) | -67.53 ± 10.84 (`-6.23`, no) | -73.93 ± 11.20 | -0.0030 ± 0.0077 | 8.00 |
| `360` (`30yr`) | `:bf_closed - :sq_closed` | -72.37 ± 27.80 (`-2.60`, no) | -70.95 ± 27.30 (`-2.60`, no) | -75.91 ± 29.55 | -0.0048 ± 0.0024 | 8.00 |
| `360` (`30yr`) | `:bf_open - :sq_closed` | -65.58 ± 26.72 (`-2.45`, no) | -64.10 ± 26.22 (`-2.44`, no) | -68.19 ± 28.05 | -0.0094 ± 0.0056 | 8.00 |
| `480` (`40yr`) | `:bf_closed - :sq_closed` | -125.51 ± 35.47 (`-3.54`, no) | -123.96 ± 35.60 (`-3.48`, no) | -128.80 ± 37.69 | -0.0038 ± 0.0042 | 8.00 |
| `480` (`40yr`) | `:bf_open - :sq_closed` | -106.38 ± 35.93 (`-2.96`, no) | -104.24 ± 35.90 (`-2.90`, no) | -108.76 ± 37.87 | +0.0003 ± 0.0049 | 8.00 |
| `600` (`50yr`) | `:bf_closed - :sq_closed` | -125.83 ± 44.88 (`-2.80`, no) | -128.16 ± 45.26 (`-2.83`, no) | -131.37 ± 47.39 | +0.0026 ± 0.0028 | 8.00 |
| `600` (`50yr`) | `:bf_open - :sq_closed` | -91.93 ± 44.35 (`-2.07`, no) | -92.42 ± 44.42 (`-2.08`, no) | -93.81 ± 46.28 | +0.0065 ± 0.0045 | 8.00 |

## 2. Composed 50-Year Coupled Governed-Threshold Map (`600` steps, `epoch = 25`, `1:16` seeds, `8.164` touch check)
| Threshold | Setting | Touch | `floor_u` Δ | `floor_h` Δ | `median_u` Δ | `harm` Δ | `adv` Δ | Verdict |
|---|---|---|---|---|---|---|---|---|
| `ratchet_horizon` | `5` | yes (lane 51) | -2.16 | -2.51 | -1.98 | 0.14 | -0.92 | no effect |
| `ratchet_horizon` | `40` | NONE (0) | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | inconsequential |
| `ratchet_horizon` | `100` | NONE (0) | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | inconsequential |
| `model_z` | `1` | yes (audits 39) | 1.62 | 0.15 | 1.35 | 0.08 | -2.67 | no effect |
| `model_z` | `4` | yes (audits 102) | 3.78 | 3.39 | 4.00 | 0.03 | -3.82 | no effect |
| `model_z` | `10` | yes (audits 112) | -0.41 | -0.22 | -1.18 | -4.40 | -533.60 | no effect |
| `acc_halflife` | `1.75` | yes (audits 111) | 1.56 | 0.93 | -0.27 | -4.54 | -536.28 | no effect |
| `acc_halflife` | `28` | yes (audits 120) | -1.01 | 1.37 | 0.18 | -0.09 | 9.36 | no effect |
| `threshold` | `0.45` | yes (audits 72) | 4.62 | 3.04 | 4.21 | 0.26 | -10.13 | no effect |
| `threshold` | `0.99` | yes (audits 162) | -14.88 | -14.51− | -16.38 | -4.06 | -511.31 | worse |
| `adv_z` | `1.5` | yes (audits 89) | -0.34 | -2.30 | -0.29 | -3.99 | -519.75 | no effect |
| `adv_z` | `6` | yes (audits 88) | -5.54 | -2.66 | -4.97 | -0.15 | -10.30 | no effect |
| `pattern_attention` | `2.25` | yes (audits 82) | -4.41 | -3.66 | -3.44 | -4.10 | -532.36 | no effect |
| `pattern_attention` | `45` | yes (audits 119) | -1.50 | -3.41 | -1.62 | 0.09 | 2.74 | no effect |
| `adv_min_records` | `1` | yes (audits 93) | -0.94 | -0.15 | -1.09 | 0.20 | 0.45 | no effect |
| `adv_min_records` | `25` | yes (audits 104) | 2.59 | 3.48 | 1.35 | -4.17 | -539.23 | no effect |
| `min_records` | `1` | yes (audits 75) | 3.27 | 1.36 | 1.27 | -4.34 | -533.44 | no effect |
| `min_records` | `50` | yes (audits 112) | -10.06− | -10.49− | -9.95− | -4.21 | -525.81 | worse |
