# Convergence & Population-Diversity Sizing Report

- **Commit**: `08627f2`
- **Runtime**: `15.54` minutes (`8` threads)
- **Convergence Criteria**: Running-mean settling within `10%` (`3%` for M5 accuracy), between-seed relative 95% CI half-width `<= 10%`, and signal-to-noise `z = mean / se >= 3.0`.

## 1. M1 Metric Competition & Distributed Choice (`seeds = 1:10`)
- **Step-rate settling (`tol = 10%` over 1,000 steps)**: action rate median step **53** (worst **113**), `floor_u` rate median **512** (worst **686**), `floor_h` rate median **423** (worst **671**), rare floor falls median **448** (worst **600**).

| Horizon (`steps`, `n = 200`) | `floor_u` Mean ± SE | Rel 95% Half-Width | `z` (`mean/se`) | `floor_h` Rel 95% Half-Width |
|---|---|---|---|---|
| `50` | 2.30 ± 0.07 | 5.9% | 33.3 | 22.8% |
| `100` | 6.60 ± 0.26 | 7.8% | 25.2 | 10.2% |
| `200` | 15.74 ± 0.48 | 6.0% | 32.8 | 7.1% |
| `300` | 27.17 ± 0.63 | 4.5% | 43.4 | 4.0% |
| `500` | 48.32 ± 1.13 | 4.6% | 42.9 | 2.3% |
| `1000` | 105.75 ± 1.29 | 2.4% | 82.0 | 2.0% |

| Diverse Population (`n`, distributed G, `150` steps) | `floor_u` Mean ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Settling Step (med / max) |
|---|---|---|---|---|
| `20` | 15.27 ± 0.58 | 7.4% | 26.3 | 121 / 150 |
| `50` | 11.00 ± 0.44 | 7.8% | 25.2 | 123 / 140 |
| `100` | 9.36 ± 0.48 | 10.1% | 19.5 | 120 / 142 |
| `200` | 7.21 ± 0.47 | 12.9% | 15.2 | 122 / 137 |
| `500` | 6.13 ± 0.41 | 13.1% | 15.0 | 137 / 146 |
| `1000` | 6.30 ± 0.46 | 14.5% | 13.6 | 124 / 141 |

## 2. M3c Calibrated Realistic Economy (`seeds = 1:8`, Log-Normal Agent Skills)
- **Post-bootstrap (`>50`) growth-rate settling (`tol = 10%` over 500 steps)**: `floor_u` median step **81** (worst **113**), `floor_h` median step **116** (worst **154**).

| Total Steps (`50` init + active, `n = 80`, `8` agents) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | `floor_h` Rel 95% Half-Width |
|---|---|---|---|---|
| `100` (`50` active) | 50.58 ± 0.71 | 2.8% | 70.9 | 2.6% |
| `150` (`100` active) | 103.69 ± 1.34 | 2.5% | 77.5 | 3.2% |
| `250` (`200` active) | 212.74 ± 2.54 | 2.3% | 83.7 | 2.4% |
| `350` (`300` active) | 320.07 ± 3.52 | 2.2% | 91.1 | 3.2% |
| `400` (`350` active) | 378.09 ± 3.50 | 1.8% | 108.1 | 2.6% |

| Diverse Population (`n` beings, `n_agents` log-normal, `plans = max(10, 10n/80)`, `150` steps) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Settling Step (med / max) |
|---|---|---|---|---|
| `n = 20`, `agents = 4`, `plans = 10` | 87.56 ± 13.01 | 29.1% | 6.7 | 110 / 141 |
| `n = 40`, `agents = 6`, `plans = 10` | 99.50 ± 1.55 | 3.1% | 64.2 | 87 / 111 |
| `n = 80`, `agents = 8`, `plans = 10` | 103.69 ± 1.34 | 2.5% | 77.5 | 80 / 94 |
| `n = 160`, `agents = 12`, `plans = 20` | 161.57 ± 1.20 | 1.5% | 134.6 | 78 / 115 |
| `n = 240`, `agents = 16`, `plans = 30` | 250.97 ± 4.46 | 3.5% | 56.3 | 82 / 112 |

## 3. M5 Governance with Diverse Voter Skills & Ability Caps (`seeds = 1:10`, Domain Specialists, `signal_σ = 25.0`, Paired Equal-Weight Arm)
- **Accuracy running-mean settling (`tol = 3%` over 800 decisions)**: median decision **35** (worst **75**).

| Decisions (`n_voters = 60`) | Accuracy Mean ± SE | Acc 95% Half-Width | Equal-Weight Mean | Paired Wisdom Gain (`bf − eq`) ± SE | Wisdom Gain `z` |
|---|---|---|---|---|---|
| `50` | 0.9600 ± 0.0067 | 1.36% | 0.8900 | +0.0700 ± 0.0150 | +4.67 |
| `100` | 0.9570 ± 0.0052 | 1.06% | 0.8900 | +0.0670 ± 0.0132 | +5.09 |
| `200` | 0.9565 ± 0.0053 | 1.08% | 0.8995 | +0.0570 ± 0.0088 | +6.46 |
| `300` | 0.9577 ± 0.0052 | 1.06% | 0.8973 | +0.0603 ± 0.0074 | +8.16 |
| `500` | 0.9584 ± 0.0048 | 0.98% | 0.8998 | +0.0586 ± 0.0060 | +9.71 |
| `800` | 0.9543 ± 0.0044 | 0.91% | 0.8964 | +0.0579 ± 0.0049 | +11.89 |

| Diverse Voters (`n_voters`, `300` decisions) | Late Accuracy Mean ± SE | Acc 95% Half-Width | Equal-Weight Mean | Paired Wisdom Gain (`bf − eq`) ± SE | Wisdom Gain `z` |
|---|---|---|---|---|---|
| `12` voters | 0.7927 ± 0.0103 | 2.54% | 0.6693 | +0.1233 ± 0.0135 | +9.12 |
| `24` voters | 0.8873 ± 0.0071 | 1.56% | 0.7833 | +0.1040 ± 0.0179 | +5.81 |
| `48` voters | 0.9587 ± 0.0044 | 0.90% | 0.9107 | +0.0480 ± 0.0073 | +6.58 |
| `80` voters | 0.9907 ± 0.0018 | 0.35% | 0.9160 | +0.0747 ± 0.0064 | +11.62 |
| `140` voters | 0.9980 ± 0.0014 | 0.28% | 0.9620 | +0.0360 ± 0.0025 | +14.55 |
| `240` voters | 1.0000 ± 0.0000 | 0.00% | 0.9700 | +0.0300 ± 0.0038 | +8.00 |

## 4. M7 Population with Diverse Teachers, Learners & Novelty (`seeds = 1:8`, Distributed G)
- **Step-rate settling (`tol = 10%` over 200 steps)**: `floor_u` median step **64** (worst **122**), `median_u` median step **80** (worst **117**).

| Steps (`n = 100`) | `floor_u` Gain ± SE | `floor_u` Rel 95% Half-Width | `floor_u` `z` | `median_u` Rel 95% Half-Width |
|---|---|---|---|---|
| `25` | 4.18 ± 0.15 | 7.2% | 27.2 | 9.5% |
| `50` | 7.21 ± 0.47 | 12.8% | 15.3 | 14.9% |
| `80` | 11.23 ± 0.81 | 14.2% | 13.8 | 15.3% |
| `120` | 16.40 ± 0.90 | 10.7% | 18.3 | 11.4% |
| `150` | 20.89 ± 1.26 | 11.8% | 16.6 | 12.2% |

| Diverse Beings (`n`, `teacher_cv = 0.5`, `reception_σ = 0.5`, `80` steps) | `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Settling Step (med / max) |
|---|---|---|---|---|
| `n = 20` | 6.54 ± 0.60 | 17.9% | 11.0 | 50 / 54 |
| `n = 40` | 8.37 ± 0.78 | 18.2% | 10.8 | 46 / 53 |
| `n = 80` | 8.78 ± 0.19 | 4.2% | 46.2 | 39 / 44 |
| `n = 150` | 9.94 ± 0.19 | 3.7% | 52.5 | 32 / 39 |
| `n = 300` | 13.30 ± 0.22 | 3.3% | 59.5 | 26 / 35 |
| `n = 500` | 18.14 ± 0.29 | 3.1% | 62.5 | 18 / 25 |
