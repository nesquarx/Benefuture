# Open Small-Effect Fresh-Seed Replications (`z = 3.0`, Student-t inflated)

- **Commit**: `5b55742` · **Runtime**: `21.0 min` · **Workers**: `8`

## 1. M5 Sparse Specialists (`8.90`, `32` fresh seeds `201:232`, `decisions = 300`, `misconception_σ = 1.5`)
| Voters (`k_spec`) | `:bf` Mean | `:eq` Mean | Paired Gain (`bf - eq`) ± SE | `z_raw` | `z >= 3` |
|---|---|---|---|---|---|
| `12` (`k=3`) | 0.9804 | 0.7244 | +0.2560 ± 0.0069 | 36.92 | yes |
| `48` (`k=5`) | 0.9885 | 0.6950 | +0.2935 ± 0.0064 | 45.85 | yes |
| `120` (`k=6`) | 0.9917 | 0.7021 | +0.2896 ± 0.0084 | 34.29 | yes |
| `240` (`k=8`) | 0.9904 | 0.6965 | +0.2940 ± 0.0051 | 57.33 | yes |

- **Growth (`gain(240) - gain(12)`)**: `+0.0379 ± 0.0085` (`z_raw = 4.44`, `z >= 3`: `yes`).

## 2. 20-Year M5 Collusion Residual (`64` fresh seeds `201:264`, `100` voters, `1,200` decisions)
| Comparison | Mean A | Mean B | Paired Diff ± SE | `z_raw` | `z >= 3` | Equiv `±0.005` |
|---|---|---|---|---|---|---|
| AdvAp recovery (`:collude_advap - :collude_noadvap`) | 0.9813 | 0.9695 | +0.0118 ± 0.0009 | 13.51 | yes | no |
| Residual cost (`:collude_advap - :clean_advap`) | 0.9813 | 0.9833 | -0.0020 ± 0.0006 | -3.19 | no | yes |

## 3. M3c Population Scale Effect (`32` fresh seeds `101:132`, `steps = 150`, proportional `plans`)
| `(n, agents)` | Mean `floor_u` gain | Mean `median_u` gain | `floor_u / n` | vs `(40, 6)` Paired `floor_u` ± SE | `z_raw` | `z >= 3` |
|---|---|---|---|---|---|---|
| `(40, 6)` | 99.86 | 112.30 | 2.497 | baseline | – | – |
| `(80, 8)` | 97.97 | 110.36 | 1.225 | -1.89 ± 0.96 | -1.96 | no |
| `(160, 12)` | 159.87 | 176.79 | 0.999 | +60.01 ± 1.07 | 56.23 | yes |
| `(240, 16)` | 203.99 | 222.98 | 0.850 | +104.12 ± 1.69 | 61.63 | yes |

- **Per-being `floor_u / n` (`240 vs 40`)**: `-1.6466 ± 0.0189` (`z_raw = -87.06`, `z >= 3`: `no`).

## 4. M7 Traits-Mode Population Scale Effect (`32` fresh seeds `101:132`, `steps = 80`)
| `n` beings | Mean `floor_u` gain | Mean `median_u` gain | vs `n = 20` Paired `floor_u` ± SE | `z_raw` | `z >= 3` |
|---|---|---|---|---|---|
| `20` | 11.53 | 9.86 | baseline | – | – |
| `100` | 13.51 | 11.93 | +1.98 ± 0.24 | 8.20 | yes |
| `300` | 14.21 | 12.75 | +2.68 ± 0.25 | 10.56 | yes |
| `500` | 14.25 | 12.78 | +2.72 ± 0.25 | 10.92 | yes |
