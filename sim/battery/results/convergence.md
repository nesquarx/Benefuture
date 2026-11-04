# Convergence & Population-Diversity Sizing Report

- **Commit**: `11c82f8f6d453d71df755a5a6f7dd389fd400fd7`
- **Sharded Execution**: Consolidated across parallel shards
- **Convergence Criteria**: Running-mean settling within `10%` (`3%` for M5 accuracy), between-seed relative 95% CI half-width `<= 10%`, and signal-to-noise `z = mean / se >= 3.0`.

## 1. M1 Metric Competition & Distributed Choice
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
| `20` | 15.97 ± 0.51 | 6.2% | 31.5 | 119 / 139 |
| `50` | 10.55 ± 0.41 | 7.6% | 25.7 | 120 / 144 |
| `100` | 9.30 ± 0.41 | 8.7% | 22.6 | 128 / 142 |
| `200` | 7.12 ± 0.33 | 9.0% | 21.8 | 127 / 143 |
| `500` | 6.34 ± 0.39 | 12.0% | 16.3 | 131 / 138 |
| `1000` | 6.22 ± 0.50 | 15.7% | 12.5 | 127 / 138 |

## 2. M3c Calibrated Realistic Economy (Log-Normal Agent Skills)
| Total Steps (`50` init + active, `n = 80`, `8` agents) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | `floor_h` Rel 95% Half-Width |
|---|---|---|---|---|
| `100` (`50` active) | 49.74 ± 1.10 | 4.3% | 45.1 | 3.6% |
| `150` (`100` active) | 101.70 ± 1.04 | 2.0% | 98.0 | 1.5% |
| `250` (`200` active) | 213.82 ± 1.44 | 1.3% | 149.0 | 1.6% |
| `350` (`300` active) | 325.57 ± 2.06 | 1.2% | 158.0 | 1.1% |
| `400` (`350` active) | 382.41 ± 1.95 | 1.0% | 196.3 | 0.5% |

| Diverse Population (`n` beings, `n_agents` log-normal, `150` steps) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Gain / Being | Gain / Plan |
|---|---|---|---|---|---|
| `n = 20`, `agents = 4`, `plans = 10` | 257.23 ± 4.59 | 3.5% | 56.0 | 12.862 | 25.72 |
| `n = 40`, `agents = 6`, `plans = 10` | 191.40 ± 2.86 | 2.9% | 66.9 | 4.785 | 19.14 |
| `n = 80`, `agents = 8`, `plans = 10` | 101.70 ± 1.04 | 2.0% | 98.0 | 1.271 | 10.17 |
| `n = 160`, `agents = 12`, `plans = 20` | 89.67 ± 1.31 | 2.9% | 68.3 | 0.560 | 4.48 |
| `n = 240`, `agents = 16`, `plans = 30` | 112.75 ± 0.73 | 1.3% | 153.9 | 0.470 | 3.76 |

## 3. M5 Governance with Diverse Voter Skills & Ability Caps
| Decisions (`n_voters = 60`) | Accuracy Mean ± SE | Acc 95% Half-Width | Wisdom Gain vs Equal ± SE | Wisdom Gain `z` |
|---|---|---|---|---|
| `50` | 0.9925 ± 0.0037 | 0.72% | +0.3050 ± 0.0292 | +10.44 |
| `100` | 0.9912 ± 0.0052 | 1.02% | +0.3262 ± 0.0204 | +15.96 |
| `200` | 0.9931 ± 0.0030 | 0.59% | +0.3175 ± 0.0136 | +23.41 |
| `300` | 0.9933 ± 0.0025 | 0.50% | +0.3150 ± 0.0082 | +38.58 |
| `500` | 0.9915 ± 0.0018 | 0.35% | +0.2980 ± 0.0053 | +56.03 |
| `800` | 0.9916 ± 0.0015 | 0.31% | +0.2969 ± 0.0068 | +43.86 |

| Diverse Voters (`n_voters`, `300` decisions) | Late Accuracy Mean ± SE | Acc 95% Half-Width | Wisdom Gain vs Equal ± SE | Wisdom Gain `z` |
|---|---|---|---|---|
| `12` voters | 0.9508 ± 0.0047 | 0.97% | +0.2508 ± 0.0170 | +14.72 |
| `24` voters | 0.9683 ± 0.0066 | 1.34% | +0.2725 ± 0.0080 | +34.01 |
| `48` voters | 0.9925 ± 0.0027 | 0.52% | +0.3117 ± 0.0201 | +15.47 |
| `80` voters | 0.9900 ± 0.0022 | 0.43% | +0.3025 ± 0.0141 | +21.40 |
| `140` voters | 0.9942 ± 0.0020 | 0.39% | +0.3008 ± 0.0146 | +20.59 |
| `240` voters | 0.9892 ± 0.0018 | 0.35% | +0.2983 ± 0.0111 | +26.85 |

## 4. M7 Population with Diverse Teachers, Learners & Novelty (Distributed G)
| Steps (`n = 100`) | `floor_u` Gain ± SE | `floor_u` Rel 95% Half-Width | `floor_u` `z` | `median_u` Rel 95% Half-Width |
|---|---|---|---|---|
| `25` | 4.66 ± 0.15 | 6.3% | 31.0 | 7.3% |
| `50` | 7.84 ± 0.29 | 7.3% | 26.9 | 8.2% |
| `80` | 11.66 ± 0.54 | 9.1% | 21.5 | 10.6% |
| `120` | 17.46 ± 0.80 | 9.0% | 21.8 | 9.9% |
| `150` | 21.86 ± 0.86 | 7.7% | 25.4 | 8.0% |

| Diverse Beings (`n`, `teacher_cv = 0.5`, `reception_σ = 0.5`, `80` steps) | `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Gain / Being |
|---|---|---|---|---|
| `n = 20` | 6.58 ± 0.69 | 20.6% | 9.5 | 0.329 |
| `n = 40` | 9.25 ± 0.93 | 19.6% | 10.0 | 0.231 |
| `n = 80` | 10.02 ± 0.84 | 16.5% | 11.9 | 0.125 |
| `n = 150` | 10.27 ± 0.44 | 8.3% | 23.6 | 0.068 |
| `n = 300` | 11.33 ± 0.29 | 5.1% | 38.7 | 0.038 |
| `n = 500` | 10.75 ± 0.25 | 4.6% | 42.6 | 0.022 |

