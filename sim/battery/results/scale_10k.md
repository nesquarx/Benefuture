# 10^4-Being Population Scale Report (`z = 3.0`, Student-t inflated)

- **Commit**: `3e5bcb7` · **Runtime**: `40.4 min` · **Workers**: `4`

## 1. M3c Economy Scaling (`n = 80 -> 10,000`, `16` seeds `101:116`, `steps = 100`, `init_steps = 40`, `8` agents)
| `n` beings | `floor_u` gain ± SE (`z_raw`, `z>=3`) | `floor_h` gain ± SE | `median_u` gain | `worst_drop` | `sec / seed` |
|---|---|---|---|---|---|
| `80` | 55.67 ± 0.50 (`110.32`, yes) | 56.56 ± 0.83 | 65.49 | 4.23 | 12.2 |
| `1000` | 46.97 ± 0.61 (`76.88`, yes) | 47.36 ± 0.67 | 55.26 | 7.02 | 29.7 |
| `10000` | 31.81 ± 0.50 (`63.62`, yes) | 31.82 ± 0.51 | 38.18 | 5.99 | 154.0 |

## 2. M5 Sparse Specialists Scaling (`nv = 80 -> 10,000`, `16` seeds `201:216`, `decisions = 120`, `misconception_σ = 1.5`)
| `nv` voters (`k_spec`) | `:bf` Mean | `:eq` Mean | Paired Gain (`bf - eq`) ± SE | `z_raw` | `z >= 3` | `sec / seed` |
|---|---|---|---|---|---|---|
| `80` (`k=6`) | 0.9865 | 0.6969 | +0.2896 ± 0.0121 | 24.00 | yes | 0.3 |
| `1000` (`k=12`) | 0.9917 | 0.6865 | +0.3052 ± 0.0110 | 27.63 | yes | 3.7 |
| `10000` (`k=24`) | 0.9958 | 0.7094 | +0.2865 ± 0.0127 | 22.63 | yes | 336.7 |
