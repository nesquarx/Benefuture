# Convergence & Population-Diversity Sizing Report

- **Commit**: `e62f62a977c7ad9fe42fec68faf36c95807c3f34`
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
| `250` (`200` active) | 213.28 ± 1.82 | 1.7% | 117.4 | 1.4% |
| `350` (`300` active) | 323.61 ± 2.04 | 1.2% | 158.8 | 1.2% |
| `400` (`350` active) | 378.56 ± 2.02 | 1.0% | 187.3 | 1.0% |

| Diverse Population (`n` beings, `n_agents` log-normal, `150` steps) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Gain / Being | Gain / Plan |
|---|---|---|---|---|---|
| `n = 20`, `agents = 4`, `plans = 10` | 258.27 ± 4.96 | 3.8% | 52.1 | 12.914 | 25.83 |
| `n = 40`, `agents = 6`, `plans = 10` | 189.88 ± 2.83 | 2.9% | 67.1 | 4.747 | 18.99 |
| `n = 80`, `agents = 8`, `plans = 10` | 101.70 ± 1.04 | 2.0% | 98.0 | 1.271 | 10.17 |
| `n = 160`, `agents = 12`, `plans = 20` | 89.32 ± 1.20 | 2.6% | 74.2 | 0.558 | 4.47 |
| `n = 240`, `agents = 16`, `plans = 30` | 112.37 ± 0.76 | 1.3% | 148.7 | 0.468 | 3.75 |

## 3. M5 Governance with Diverse Voter Skills & Ability Caps
| Decisions (`n_voters = 60`) | Accuracy Mean ± SE | Acc 95% Half-Width | Wisdom Gain vs Equal ± SE | Wisdom Gain `z` |
|---|---|---|---|---|
| `50` | 0.9925 ± 0.0037 | 0.72% | +0.3050 ± 0.0292 | +10.44 |
| `100` | 0.9912 ± 0.0052 | 1.02% | +0.3262 ± 0.0204 | +15.96 |
| `200` | 0.9931 ± 0.0030 | 0.59% | +0.3175 ± 0.0130 | +24.44 |
| `300` | 0.9933 ± 0.0027 | 0.53% | +0.3150 ± 0.0078 | +40.17 |
| `500` | 0.9912 ± 0.0019 | 0.37% | +0.2977 ± 0.0051 | +58.01 |
| `800` | 0.9908 ± 0.0014 | 0.28% | +0.2961 ± 0.0065 | +45.28 |

| Diverse Voters (`n_voters`, `300` decisions) | Late Accuracy Mean ± SE | Acc 95% Half-Width | Wisdom Gain vs Equal ± SE | Wisdom Gain `z` |
|---|---|---|---|---|
| `12` voters | 0.9792 ± 0.0037 | 0.73% | +0.2792 ± 0.0141 | +19.78 |
| `24` voters | 0.9642 ± 0.0052 | 1.05% | +0.2683 ± 0.0121 | +22.11 |
| `48` voters | 0.9933 ± 0.0028 | 0.56% | +0.3125 ± 0.0197 | +15.83 |
| `80` voters | 0.9900 ± 0.0022 | 0.43% | +0.3025 ± 0.0141 | +21.40 |
| `140` voters | 0.9942 ± 0.0020 | 0.39% | +0.3008 ± 0.0146 | +20.59 |
| `240` voters | 0.9892 ± 0.0018 | 0.35% | +0.2983 ± 0.0111 | +26.85 |

## 4. M7 Population with Diverse Teachers, Learners & Novelty (Distributed G)
| Steps (`n = 100`) | `floor_u` Gain ± SE | `floor_u` Rel 95% Half-Width | `floor_u` `z` | `median_u` Rel 95% Half-Width |
|---|---|---|---|---|
| `25` | 11.03 ± 0.28 | 5.0% | 39.2 | 4.4% |
| `50` | 12.66 ± 0.30 | 4.6% | 42.5 | 4.7% |
| `80` | 14.35 ± 0.37 | 5.0% | 38.8 | 5.0% |
| `120` | 16.72 ± 0.27 | 3.2% | 61.7 | 2.9% |
| `150` | 17.99 ± 0.31 | 3.4% | 57.6 | 3.1% |

| Diverse Beings (`n`, `teacher_cv = 0.5`, `reception_σ = 0.5`, `80` steps) | `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Gain / Being |
|---|---|---|---|---|
| `n = 20` | 11.93 ± 0.59 | 9.7% | 20.3 | 0.597 |
| `n = 40` | 12.68 ± 0.42 | 6.5% | 30.0 | 0.317 |
| `n = 80` | 13.20 ± 0.34 | 5.1% | 38.5 | 0.165 |
| `n = 150` | 13.78 ± 0.23 | 3.3% | 59.3 | 0.092 |
| `n = 300` | 13.99 ± 0.20 | 2.8% | 69.0 | 0.047 |
| `n = 500` | 14.28 ± 0.21 | 2.9% | 67.9 | 0.029 |

