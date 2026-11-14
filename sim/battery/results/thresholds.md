# Governed-threshold perturbation battery

Build: commit 3fe3331. 300 steps; run time 139.4 minutes; 46 distinct arms, 0 flagged.

Seeds and bars: seeds by precision per arm (stop when the t-inflated standard error of the paired floor-u difference is at most 1.5, 6 to 24 seeds; * = cap reached without that precision); stage 1 screen on seeds 1..; every verdict at z = 3.0, Student-t inflated. Two-stage rule: a screen candidate is re-measured on the disjoint fresh seeds 1001.. (default re-run on them) and is FLAGGED only if the confirmation is also a candidate.

World: the economy battery's, noise at moderate severity, two deceivers at full size, AdvAp on. Each cell: mean paired difference from the default (arm − default); + / − significant at z = 3.0. Harm and the deceivers' advantage are better when lower. Candidate = some reading better and none worse. Stage 2 cells: floor u / floor h / median u / median h / harm / deceivers' advantage.

| Threshold | Setting | Seeds | Floor u | Floor h | Median u | Median h | Harm peak | Deceivers' advantage | Screen | Confirm seeds | Confirm cells | Result |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `threshold` | 0.5× → 0.45 | 24* | 1.63 | 1.26 | 2.46 | 2.16 | 0.10 | 3.55 | no effect | – | – | no effect |
| `threshold` | 0.75× → 0.675 | 24* | 1.63 | 1.26 | 2.46 | 2.16 | 0.10 | 3.55 | no effect | – | – | no effect |
| `threshold` | 1.1× → 0.99 | 24* | -8.04 | -8.52− | -7.96 | -7.51 | 0.04 | -18.65 | worse | – | – | worse |
| `coarse_threshold` | 0.5× → 0.375 | 17 | 1.13 | -1.17 | 2.18 | -0.57 | -0.04 | 1.75 | no effect | – | – | no effect |
| `coarse_threshold` | 0.75× → 0.562 | 17 | 1.13 | -1.17 | 2.18 | -0.57 | -0.04 | 1.75 | no effect | – | – | no effect |
| `coarse_threshold` | 1.32× → 0.99 | 24* | -60.48− | -61.04− | -64.10− | -63.36− | -0.08 | -7.08 | worse | – | – | worse |
| `model_z` | 0.5× → 1.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `model_z` | 0.75× → 1.5 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `model_z` | 1.5× → 3.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `model_z` | 2.0× → 4.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `max_credence` | 0.99× → 0.98 | 24 | 0.46 | 0.11 | 0.89 | 1.54 | -0.11 | -0.28 | no effect | – | – | no effect |
| `max_credence` | 0.997× → 0.987 | 6 | 0.22 | 0.62 | -0.64 | 0.55 | -0.03 | 3.11 | no effect | – | – | no effect |
| `max_credence` | 1.003× → 0.993 | 6 | 1.00 | -0.43 | 0.76 | -0.47 | 0.00 | -0.26 | no effect | – | – | no effect |
| `max_credence` | 1.005× → 0.995 | 6 | 1.00 | -0.43 | 0.76 | -0.47 | 0.00 | -0.26 | no effect | – | – | no effect |
| `ratchet_growth` | 0.5× → 0.5 | 6 | -0.57 | -1.02 | -1.30 | 0.11 | -0.03 | 3.48 | no effect | – | – | no effect |
| `ratchet_growth` | 0.75× → 0.75 | 6 | -0.78 | -1.64 | -0.66 | -0.44 | 0.00 | 0.37 | no effect | – | – | no effect |
| `ratchet_growth` | 1.5× → 1.5 | 20 | -3.17 | -2.27 | -2.76 | -1.46 | -0.24 | -4.72 | no effect | – | – | no effect |
| `ratchet_growth` | 2.0× → 2.0 | 18 | -3.36 | -2.19 | -2.62 | -2.17 | -0.19 | -8.68 | no effect | – | – | no effect |
| `adv_z` | 0.5× → 1.5 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `adv_z` | 0.75× → 2.25 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `adv_z` | 1.5× → 4.5 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `adv_z` | 2.0× → 6.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `acc_halflife` | 0.5× → 3.5 | 24* | -0.97 | -0.58 | 0.15 | 2.30 | -0.06 | 1.30 | no effect | – | – | no effect |
| `acc_halflife` | 0.75× → 5.25 | 24* | -0.56 | -0.86 | -0.57 | -0.65 | -0.01 | 1.81 | no effect | – | – | no effect |
| `acc_halflife` | 1.5× → 10.5 | 24* | 2.88 | 1.77 | 2.24 | 2.64 | -0.09 | -3.52 | no effect | – | – | no effect |
| `acc_halflife` | 2.0× → 14.0 | 24* | -0.94 | -1.73 | -0.03 | 1.12 | 0.15 | 4.08 | no effect | – | – | no effect |
| `ratchet_horizon` | 0.5× → 10.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `ratchet_horizon` | 0.75× → 15.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `ratchet_horizon` | 1.5× → 30.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `ratchet_horizon` | 2.0× → 40.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `actor_min_records` | 0.4× → 2.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `actor_min_records` | 0.8× → 4.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `actor_min_records` | 1.6× → 8.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `actor_min_records` | 2.0× → 10.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `adv_min_records` | 0.4× → 2.0 | 24* | -2.71 | -3.86 | -3.11 | -2.36 | -0.16 | -4.91 | no effect | – | – | no effect |
| `adv_min_records` | 0.8× → 4.0 | 24* | -2.84 | -2.01 | -1.15 | -0.19 | 0.02 | -3.00 | no effect | – | – | no effect |
| `adv_min_records` | 1.6× → 8.0 | 23 | 0.00 | 1.63 | 0.37 | 1.02 | -0.10 | 2.57 | no effect | – | – | no effect |
| `adv_min_records` | 2.0× → 10.0 | 24* | -0.17 | 1.04 | 0.68 | 2.59 | 0.06 | 1.74 | no effect | – | – | no effect |
| `pattern_attention` | 0.5× → 4.5 | 24* | 2.43 | 2.93 | 1.92 | 3.08 | 0.05 | 0.72 | no effect | – | – | no effect |
| `pattern_attention` | 0.75× → 6.75 | 24* | 1.02 | -1.55 | 0.39 | 1.95 | 0.04 | 0.83 | no effect | – | – | no effect |
| `pattern_attention` | 1.5× → 13.5 | 16 | 2.28 | 1.34 | 2.80 | 2.36 | 0.03 | -1.43 | no effect | – | – | no effect |
| `pattern_attention` | 2.0× → 18.0 | 24* | -0.70 | 1.45 | 0.78 | 1.70 | 0.09 | -2.27 | no effect | – | – | no effect |
| `min_records` | 0.5× → 5.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `min_records` | 0.8× → 8.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `min_records` | 1.5× → 15.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
| `min_records` | 2.0× → 20.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | no effect | – | – | no effect |
