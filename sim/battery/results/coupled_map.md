# Continuous-Coupled Break-Even & Threshold Map (`z = 3.0`, Student-t inflated)

- **Commit**: `d95a683` · **Runtime**: `112.1 min` · **Workers**: `8`

## 1. Coupled Break-Even & Open-Entry Horizons (`10yr..50yr`, `1:24` seeds, `:stressed`, `epoch = 24`)
| Horizon (`steps`) | Arm Pair | `floor_u` Δ ± SE (`z_raw`, `z>=3`) | `floor_h` Δ ± SE (`z_raw`, `z>=3`) | `median_u` Δ ± SE | `gov_acc` Δ ± SE | `entries` (`bf_open`) |
|---|---|---|---|---|---|---|
| `120` (`10yr`) | `:bf_closed - :sq_closed` | +5.33 ± 3.48 (`1.53`, no) | +4.90 ± 3.67 (`1.34`, no) | +5.59 ± 3.85 | +0.0000 ± 0.0000 | 6.00 |
| `120` (`10yr`) | `:bf_open - :sq_closed` | +12.94 ± 3.15 (`4.11`, yes) | +12.70 ± 3.31 (`3.84`, yes) | +13.79 ± 3.68 | +0.0093 ± 0.0128 | 6.00 |
| `240` (`20yr`) | `:bf_closed - :sq_closed` | +12.64 ± 11.39 (`1.11`, no) | +11.88 ± 11.44 (`1.04`, no) | +14.42 ± 12.22 | +0.0000 ± 0.0018 | 7.83 |
| `240` (`20yr`) | `:bf_open - :sq_closed` | +28.42 ± 11.76 (`2.42`, no) | +28.06 ± 11.85 (`2.37`, no) | +30.91 ± 12.63 | +0.0200 ± 0.0082 | 7.83 |
| `360` (`30yr`) | `:bf_closed - :sq_closed` | +39.68 ± 23.96 (`1.66`, no) | +39.66 ± 24.16 (`1.64`, no) | +41.31 ± 25.27 | -0.0005 ± 0.0020 | 8.00 |
| `360` (`30yr`) | `:bf_open - :sq_closed` | +75.20 ± 23.47 (`3.20`, yes) | +76.17 ± 23.49 (`3.24`, yes) | +78.59 ± 24.70 | +0.0043 ± 0.0081 | 8.00 |
| `480` (`40yr`) | `:bf_closed - :sq_closed` | +56.57 ± 32.67 (`1.73`, no) | +54.99 ± 32.74 (`1.68`, no) | +58.41 ± 33.89 | -0.0031 ± 0.0022 | 8.00 |
| `480` (`40yr`) | `:bf_open - :sq_closed` | +109.08 ± 32.26 (`3.38`, yes) | +109.12 ± 32.20 (`3.39`, yes) | +111.83 ± 33.62 | +0.0058 ± 0.0076 | 8.00 |
| `600` (`50yr`) | `:bf_closed - :sq_closed` | +61.56 ± 40.83 (`1.51`, no) | +60.82 ± 40.97 (`1.48`, no) | +64.91 ± 42.59 | -0.0027 ± 0.0020 | 8.00 |
| `600` (`50yr`) | `:bf_open - :sq_closed` | +134.65 ± 40.27 (`3.34`, yes) | +137.15 ± 40.64 (`3.37`, yes) | +141.14 ± 42.41 | +0.0088 ± 0.0053 | 8.00 |

## 2. Composed 50-Year Coupled Governed-Threshold Map (`600` steps, `epoch = 25`, `1:16` seeds, `8.164` touch check)
| Threshold | Setting | Touch | `floor_u` Δ | `floor_h` Δ | `median_u` Δ | `harm` Δ | `adv` Δ | Verdict |
|---|---|---|---|---|---|---|---|---|
| `ratchet_horizon` | `5` | yes (audits 66) | -4.45 | -6.38 | -6.09 | -1.53 | -75.98 | no effect |
| `ratchet_horizon` | `40` | yes (audits 40) | 0.31 | 0.07 | 0.57 | 0.01 | -5.09 | no effect |
| `ratchet_horizon` | `100` | yes (audits 40) | 0.31 | 0.07 | 0.57 | 0.01 | -5.09 | no effect |
| `model_z` | `1` | yes (audits 50) | 5.05 | 2.23 | 3.85 | 0.12 | -26.38 | no effect |
| `model_z` | `4` | yes (audits 50) | -0.81 | 0.20 | -0.67 | -1.42 | -0.58 | no effect |
| `model_z` | `10` | yes (audits 58) | 2.34 | 2.35 | -0.35 | -1.55 | -32.63 | no effect |
| `acc_halflife` | `1.75` | yes (lane 107) | -9.37 | -12.50 | -9.54 | 0.39 | 3945.59 | no effect |
| `acc_halflife` | `28` | yes (audits 72) | 8.19 | 6.62 | 8.43 | 5.40 | 6369.74 | no effect |
| `threshold` | `0.45` | yes (audits 52) | 11.69 | 9.80 | 10.21 | 0.57 | 4471.65 | no effect |
| `threshold` | `0.99` | yes (audits 142) | -25.21− | -30.26− | -30.21− | 5.34 | 6002.43 | worse |
| `adv_z` | `1.5` | yes (audits 71) | -0.80 | -1.92 | -2.37 | -6.60 | -2023.57 | no effect |
| `adv_z` | `6` | yes (audits 85) | -1.31 | -3.43 | -2.14 | 5.20 | 5845.23 | no effect |
| `pattern_attention` | `2.25` | yes (audits 110) | 6.22 | 3.54 | 5.81 | 0.50 | 4056.86 | no effect |
| `pattern_attention` | `45` | yes (audits 181) | 2.18 | -0.79 | 0.96 | -4.89 | -1958.75 | no effect |
| `adv_min_records` | `1` | yes (audits 28) | 0.68 | -0.72 | -0.07 | -1.60 | 2.96 | no effect |
| `adv_min_records` | `25` | yes (audits 124) | -4.84 | -7.13 | -4.73 | 0.13 | 4039.68 | no effect |
| `min_records` | `1` | yes (audits 50) | 3.10 | 1.17 | 2.01 | -0.09 | -15.17 | no effect |
| `min_records` | `50` | yes (audits 40) | 2.60 | 3.12 | 4.46 | -1.23 | -16.59 | no effect |
