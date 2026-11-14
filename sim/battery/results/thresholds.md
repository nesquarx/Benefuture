# Governed-threshold perturbation battery

Build: commit a6802da. Seeds 1:6; 300 steps; run time 92.0 minutes.
World: the economy battery's, noise at moderate severity, two deceivers at full size, AdvAp on. Each cell: mean paired difference from the default (arm − default); + / − significant at z = 2. Harm and the deceivers' advantage are better when lower. 'candidate' = some reading better and none worse: for the author, after replication on fresh seeds.

| Threshold | Setting | Floor u | Floor h | Median u | Median h | Harm peak | Deceivers' advantage | Verdict |
|---|---|---|---|---|---|---|---|---|
| `threshold` | 0.5× → 0.45 | 7.32+ | 8.63 | 7.33 | 6.33 | 0.13 | -4.48 | candidate |
| `threshold` | 0.75× → 0.675 | 7.32+ | 8.63 | 7.33 | 6.33 | 0.13 | -4.48 | candidate |
| `threshold` | 1.1× → 0.99 | -0.85 | -1.72 | 2.42 | -0.70 | 0.30 | -23.45 | no effect |
| `threshold` | 1.1× → 0.99 | -0.85 | -1.72 | 2.42 | -0.70 | 0.30 | -23.45 | no effect |
| `coarse_threshold` | 0.5× → 0.375 | 1.77 | 1.97 | 1.80 | 2.60 | 0.06 | 0.22 | no effect |
| `coarse_threshold` | 0.75× → 0.562 | 1.77 | 1.97 | 1.80 | 2.60 | 0.06 | 0.22 | no effect |
| `coarse_threshold` | 1.32× → 0.99 | -42.80 | -41.74 | -43.73 | -43.73 | 0.13 | -1.02 | no effect |
| `coarse_threshold` | 1.32× → 0.99 | -42.80 | -41.74 | -43.73 | -43.73 | 0.13 | -1.02 | no effect |
| `model_z` | 0.5× → 1.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `model_z` | 0.75× → 1.5 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `model_z` | 1.5× → 3.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `model_z` | 2.0× → 4.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `max_credence` | 0.99× → 0.98 | 0.65 | 5.19+ | 1.93 | 2.33 | 0.42 | 6.41 | candidate |
| `max_credence` | 0.997× → 0.987 | 1.06 | 2.25 | 3.38 | 1.44 | -0.06 | -2.34 | no effect |
| `max_credence` | 1.003× → 0.993 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | -0.00 | no effect |
| `max_credence` | 1.005× → 0.995 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `ratchet_growth` | 0.5× → 0.5 | 2.27 | 7.73 | 5.64 | 8.38 | 0.21 | 0.78 | no effect |
| `ratchet_growth` | 0.75× → 0.75 | 2.70 | 3.97 | 2.62 | 4.19 | -0.01 | 4.38 | no effect |
| `ratchet_growth` | 1.5× → 1.5 | 5.34 | 4.48 | 4.77 | 4.51 | 0.08 | -2.32 | no effect |
| `ratchet_growth` | 2.0× → 2.0 | -3.52 | -3.79 | -1.98 | 0.51 | 0.37 | -6.14 | no effect |
| `adv_z` | 0.5× → 1.5 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `adv_z` | 0.75× → 2.25 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `adv_z` | 1.5× → 4.5 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `adv_z` | 2.0× → 6.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `acc_halflife` | 0.5× → 3.5 | 7.17 | 7.14 | 6.43 | 6.08 | 0.18 | 2.77 | no effect |
| `acc_halflife` | 0.75× → 5.25 | 3.06 | 2.85 | 0.27 | 3.17 | -0.05 | -8.79 | no effect |
| `acc_halflife` | 1.5× → 10.5 | 0.23 | 1.19 | -0.43 | 4.23 | -0.03 | -2.06 | no effect |
| `acc_halflife` | 2.0× → 14.0 | 8.29 | 9.00 | 7.57 | 7.43 | 0.18 | 7.11 | no effect |
| `ratchet_horizon` | 0.5× → 10.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `ratchet_horizon` | 0.75× → 15.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `ratchet_horizon` | 1.5× → 30.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `ratchet_horizon` | 2.0× → 40.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `actor_min_records` | 0.4× → 2.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `actor_min_records` | 0.8× → 4.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `actor_min_records` | 1.6× → 8.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `actor_min_records` | 2.0× → 10.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `adv_min_records` | 0.4× → 2.0 | 11.02+ | 10.03 | 9.38+ | 9.55+ | 0.20 | -5.44 | candidate |
| `adv_min_records` | 0.8× → 4.0 | 7.69+ | 5.60+ | 4.64 | 6.04 | 0.31 | -3.73 | candidate |
| `adv_min_records` | 1.6× → 8.0 | 5.98+ | 6.82 | 5.44 | 7.30+ | 0.03 | 3.15 | candidate |
| `adv_min_records` | 2.0× → 10.0 | 3.22 | 4.47 | 4.00 | 5.67 | 0.02 | 4.98 | no effect |
| `pattern_attention` | 0.5× → 4.5 | 7.92 | 6.08 | 6.48 | 8.04 | 0.01 | -3.93 | no effect |
| `pattern_attention` | 0.75× → 6.75 | -0.58 | 1.90 | 0.72 | 4.00 | 0.22 | -1.52 | no effect |
| `pattern_attention` | 1.5× → 13.5 | -0.08 | 3.36 | 0.86 | 1.72 | 0.13 | -7.65 | no effect |
| `pattern_attention` | 2.0× → 18.0 | 2.41 | 1.67 | 2.19 | 1.72 | 0.09 | -10.00 | no effect |
| `min_records` | 0.5× → 5.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `min_records` | 0.8× → 8.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `min_records` | 1.5× → 15.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
| `min_records` | 2.0× → 20.0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect |
