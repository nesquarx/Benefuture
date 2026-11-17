# Progressive-Complexity Battery Report (`docs/PLAN.md` L67; `z = 3.0`, Student-t inflated)

- **Commit**: `ba29c86` · **Seeds**: `1:16` (`n = 16`) · **Runtime**: `11.2 min` · **Workers**: `6`

## 1. Capability Removals (Step `81`, Duration `60`, Paired vs Intact & Matched Status-Quo Arm)
| Removal Arm | `degraded` Logged (`rate`, Wilson lo) | `dip_u` vs Intact (`z_raw`, `z>=3`) | `end_diff_u` vs Intact | Recovery (steps / `recovered`) | `floor_u` vs SQ (`z_raw`, `z>=3`) |
|---|---|---|---|---|---|
| Leaf models removed -> parent | `16/16` (`0.80`) | -8.27 ± 1.03 (`-8.00`, yes) | -2.84 ± 1.50 | 103.7 (`15/16`) | -19.12 ± 2.17 (`-8.80`, yes) |
| Leaf + parent removed -> StandCoin | `16/16` (`0.80`) | -37.89 ± 2.73 (`-13.90`, yes) | -34.06 ± 2.78 | — (`0/16`) | -50.35 ± 2.67 (`-18.83`, yes) |
| Model pool capped to 1 (w/ capture) | `16/16` (`0.80`) | -7.06 ± 0.82 (`-8.61`, yes) | -2.54 ± 1.07 | 131.6 (`15/16`) | -16.85 ± 1.58 (`-10.63`, yes) |
| Measurement chains reduced to 1 | `16/16` (`0.80`) | -7.61 ± 0.96 (`-7.95`, yes) | -3.29 ± 1.68 | 103.3 (`13/16`) | -19.57 ± 2.07 (`-9.44`, yes) |
| AdvAp disabled mid-run | `16/16` (`0.80`) | -6.01 ± 0.99 (`-6.05`, yes) | -0.42 ± 1.68 | 94.2 (`15/16`) | -16.71 ± 2.05 (`-8.15`, yes) |
| Governance frozen mid-run (coupled) | `16/16` (`0.80`) | -19.63 ± 0.92 (`-21.27`, yes) | -19.51 ± 0.97 | — (`0/16`) | -54.36 ± 1.05 (`-51.65`, yes) |
| Identity binding lost mid-run | `16/16` (`0.80`) | -5.81 ± 1.27 (`-4.57`, yes) | 0.25 ± 1.57 | 96.8 (`16/16`) | -16.03 ± 2.01 (`-7.97`, yes) |
| Legacy institutions only mid-run | `16/16` (`0.80`) | -0.66 ± 0.18 (`-3.69`, yes) | 19.35 ± 1.48 | 5.1 (`16/16`) | +3.06 ± 1.68 (`1.82`, no) |
| Combined (leaf + chain + AdvAp + bind) | `16/16` (`0.80`) | -4.51 ± 0.85 (`-5.33`, yes) | 3.09 ± 1.92 | 65.3 (`15/16`) | -13.20 ± 2.14 (`-6.17`, yes) |

## 2. Capability Additions (`8.136` Score-Only Entry -> Convergence Promotion)
| Addition Arm | Promoted (`rate`, Wilson lo) | Mean Promotion Time | `floor_u` vs Intact (`z_raw`, `z>=3`) | `floor_u` vs SQ (`z_raw`, `z>=3`) |
|---|---|---|---|---|
| Model class: better (`0.1×`) | `16/16` (`0.80`) | 47.8 | +26.96 ± 2.68 (`10.07`, yes) | +28.01 ± 3.06 (`9.15`, yes) |
| Model class: worse (`4.0×`) | `0/16` (`0.00`) | — | +0.00 ± 0.00 (`0.00`, no) | +1.04 ± 0.91 (`1.14`, no) |
| Finer measurement (`0.1×`) | `16/16` (`0.80`) | 16.2 | +0.56 ± 0.93 (`0.60`, no) | +0.56 ± 0.93 (`0.60`, no) |
| Noisier measurement (`4.0×`) | `0/16` (`0.00`) | — | +0.00 ± 0.00 (`0.00`, no) | +0.00 ± 0.00 (`0.00`, no) |
| New domain: viable (`1.0×`) | `16/16` (`0.80`) | 6.2 | -0.81 ± 1.12 (`-0.72`, no) | -0.97 ± 1.11 (`-0.87`, no) |
| New domain: noisy (`10.0×`) | `0/16` (`0.00`) | — | -4.44 ± 1.20 (`-3.70`, yes) | -4.60 ± 1.19 (`-3.87`, yes) |
| New rule: better (`shadow 8.136`) | `16/16` (`0.80`) | 2.0 | +19.51 ± 0.97 (`20.19`, yes) | -34.85 ± 1.16 (`-30.03`, yes) |
| New rule: worse/over-optimistic | `0/16` (`0.00`) | — | +0.00 ± 0.00 (`0.00`, no) | -54.36 ± 1.05 (`-51.65`, yes) |
