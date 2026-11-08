# Convergence & Population-Diversity Sizing Report

- **Commit**: `7177b3c`
- **Runtime**: `25.40` minutes (`4` threads)
- **Convergence Criteria**: Running-mean settling within `10%` (`3%` for M5 accuracy), between-seed relative 95% CI half-width `<= 10%`, and signal-to-noise `z = mean / se >= 3.0`.

## 1. M1 Metric Competition & Distributed Choice (`seeds = 1:10`)
- **Step-rate settling (`tol = 10%` over 1,000 steps)**: action rate median step **90** (worst **150**), `floor_u` rate median **529** (worst **721**), `floor_h` rate median **580** (worst **685**), rare floor falls median **462** (worst **718**).

| Horizon (`steps`, `n = 200`) | `floor_u` Mean ± SE | Rel 95% Half-Width | `z` (`mean/se`) | `floor_h` Rel 95% Half-Width |
|---|---|---|---|---|
| `50` | 2.42 ± 0.22 | 18.1% | 10.9 | 21.3% |
| `100` | 6.72 ± 0.38 | 11.0% | 17.9 | 11.7% |
| `200` | 16.05 ± 0.76 | 9.3% | 21.1 | 5.1% |
| `300` | 26.86 ± 1.04 | 7.6% | 25.9 | 3.3% |
| `500` | 48.42 ± 1.35 | 5.4% | 36.0 | 4.2% |
| `1000` | 106.30 ± 1.48 | 2.7% | 71.7 | 1.6% |

| Diverse Population (`n`, distributed G, `150` steps) | `floor_u` Mean ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Settling Step (med / max) |
|---|---|---|---|---|
| `20` | 15.97 ± 0.51 | 6.2% | 31.5 | 120 / 139 |
| `50` | 10.55 ± 0.41 | 7.6% | 25.7 | 130 / 144 |
| `100` | 9.30 ± 0.41 | 8.7% | 22.6 | 132 / 142 |
| `200` | 7.12 ± 0.33 | 9.0% | 21.8 | 138 / 143 |
| `500` | 6.34 ± 0.39 | 12.0% | 16.3 | 132 / 138 |
| `1000` | 6.22 ± 0.50 | 15.7% | 12.5 | 131 / 138 |

## 2. M3c Calibrated Realistic Economy (`seeds = 1:8`, Log-Normal Agent Skills)
- **Post-bootstrap (`>50`) growth-rate settling (`tol = 10%` over 500 steps)**: `floor_u` median step **94** (worst **152**), `floor_h` median step **120** (worst **153**).

| Total Steps (`50` init + active, `n = 80`, `8` agents) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | `floor_h` Rel 95% Half-Width |
|---|---|---|---|---|
| `100` (`50` active) | 50.23 ± 1.43 | 5.6% | 35.2 | 4.9% |
| `150` (`100` active) | 102.10 ± 1.27 | 2.4% | 80.4 | 2.0% |
| `250` (`200` active) | 214.53 ± 1.74 | 1.6% | 123.5 | 1.6% |
| `350` (`300` active) | 325.73 ± 2.74 | 1.6% | 119.0 | 1.5% |
| `400` (`350` active) | 382.91 ± 2.60 | 1.3% | 147.5 | 0.8% |

| Diverse Population (`n` beings, `n_agents` log-normal, `150` steps) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Gain / Being | Gain / Plan | Realised Plans/b/step |
|---|---|---|---|---|---|---|
| `n = 20`, `agents = 4`, `plans = 10` | 251.58 ± 3.64 | 2.8% | 69.2 | 12.579 | 25.16 | 0.275 |
| `n = 40`, `agents = 6`, `plans = 10` | 191.81 ± 3.80 | 3.9% | 50.5 | 4.795 | 19.18 | 0.179 |
| `n = 80`, `agents = 8`, `plans = 10` | 102.10 ± 1.27 | 2.4% | 80.4 | 1.276 | 10.21 | 0.097 |
| `n = 160`, `agents = 12`, `plans = 20` | 89.29 ± 1.76 | 3.9% | 50.8 | 0.558 | 4.46 | 0.097 |
| `n = 240`, `agents = 16`, `plans = 30` | 111.95 ± 0.86 | 1.5% | 130.2 | 0.466 | 3.73 | 0.105 |

## 3. M5 Governance with Diverse Voter Skills & Ability Caps (`seeds = 1:10`)
- **Accuracy running-mean settling (`tol = 3%` over 800 decisions)**: median decision **1** (worst **26**).

| Decisions (`n_voters = 60`) | Accuracy Mean ± SE | Acc 95% Half-Width | Wisdom Gain vs Equal ± SE | Wisdom Gain `z` |
|---|---|---|---|---|
| `50` | 0.9920 ± 0.0033 | 0.65% | +0.3000 ± 0.0294 | +10.22 |
| `100` | 0.9910 ± 0.0043 | 0.86% | +0.3190 ± 0.0179 | +17.87 |
| `200` | 0.9920 ± 0.0027 | 0.54% | +0.3185 ± 0.0110 | +28.87 |
| `300` | 0.9927 ± 0.0023 | 0.45% | +0.3137 ± 0.0065 | +48.21 |
| `500` | 0.9916 ± 0.0014 | 0.28% | +0.2974 ± 0.0051 | +58.57 |
| `800` | 0.9918 ± 0.0012 | 0.24% | +0.2981 ± 0.0055 | +54.52 |

| Diverse Voters (`n_voters`, `300` decisions) | Late Accuracy Mean ± SE | Acc 95% Half-Width | Wisdom Gain vs Equal ± SE | Wisdom Gain `z` |
|---|---|---|---|---|
| `12` voters | 0.9560 ± 0.0061 | 1.26% | +0.2507 ± 0.0142 | +17.69 |
| `24` voters | 0.9707 ± 0.0055 | 1.10% | +0.2760 ± 0.0069 | +40.00 |
| `48` voters | 0.9900 ± 0.0027 | 0.53% | +0.2953 ± 0.0193 | +15.32 |
| `80` voters | 0.9893 ± 0.0020 | 0.40% | +0.3007 ± 0.0116 | +25.90 |
| `140` voters | 0.9933 ± 0.0022 | 0.44% | +0.2973 ± 0.0123 | +24.25 |
| `240` voters | 0.9873 ± 0.0027 | 0.54% | +0.2967 ± 0.0109 | +27.11 |

## 4. M7 Population with Diverse Teachers, Learners & Novelty (`seeds = 1:8`, Distributed G)
- **Step-rate settling (`tol = 10%` over 200 steps)**: `floor_u` median step **132** (worst **133**), `median_u` median step **132** (worst **133**).

| Steps (`n = 100`) | `floor_u` Gain ± SE | `floor_u` Rel 95% Half-Width | `floor_u` `z` | `median_u` Rel 95% Half-Width |
|---|---|---|---|---|
| `25` | 11.22 ± 0.23 | 4.0% | 49.1 | 3.6% |
| `50` | 12.97 ± 0.23 | 3.5% | 56.8 | 2.7% |
| `80` | 14.96 ± 0.25 | 3.3% | 59.7 | 2.9% |
| `120` | 17.24 ± 0.36 | 4.1% | 48.3 | 3.7% |
| `150` | 18.50 ± 0.40 | 4.3% | 46.0 | 3.8% |

| Diverse Beings (`n`, `teacher_cv = 0.5`, `reception_σ = 0.5`, `80` steps) | `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Gain / Being | Realised Acts/b/step | Realised Res/b/step |
|---|---|---|---|---|---|---|
| `n = 20` | 11.54 ± 0.47 | 8.0% | 24.5 | 0.577 | 0.164 | 0.099 |
| `n = 40` | 12.64 ± 0.48 | 7.4% | 26.3 | 0.316 | 0.169 | 0.104 |
| `n = 80` | 13.28 ± 0.56 | 8.3% | 23.7 | 0.166 | 0.179 | 0.099 |
| `n = 150` | 13.53 ± 0.26 | 3.8% | 51.1 | 0.090 | 0.176 | 0.102 |
| `n = 300` | 14.21 ± 0.18 | 2.5% | 78.4 | 0.047 | 0.181 | 0.100 |
| `n = 500` | 14.30 ± 0.21 | 2.9% | 68.0 | 0.029 | 0.180 | 0.100 |
