# Governed-threshold perturbation battery (active world)

Build: commit fd82bae. World: active. 300 steps; run time 53.3 minutes; 46 distinct arms, 0 flagged.

Seeds and bars: seeds by precision per arm (stop when the t-inflated standard error of the paired floor-u difference is at most 1.5, 6 to 24 seeds; * = cap reached without that precision); stage 1 screen on seeds 1..; every verdict at z = 3.0, Student-t inflated. Two-stage rule: a screen candidate is re-measured on the disjoint fresh seeds 1001.. (default re-run on them) and is FLAGGED only if the confirmation is also a candidate. For no-effect arms, `Equiv ±Δ` states the smallest achievable floor-u equivalence bound (`equivalent` at z = 3.0).

World (active): economy battery + model churn (`p_new_model = 0.15`, `pool_max = 5 >= ratchet_k = 3`, `takeover_records = 20`), novel leaf formation (`form_count = 15`), binding budgets (`budget = true`, `endowment = 4.5`, `cost_per_touch = 0.75`), and a graded deceiver mix (`[0..0, 0.2, 0.4, 0.7]`). Each cell: mean paired difference from the default (arm − default); + / − significant at z = 3.0. Harm and the deceivers' advantage are better when lower. Candidate = some reading better and none worse. Stage 2 cells: floor u / floor h / median u / median h / harm / deceivers' advantage.

| Threshold | Setting | Seeds | Floor u | Floor h | Median u | Median h | Harm peak | Deceivers' advantage | Equiv ±Δ (floor u, z=3) | Screen | Confirm seeds | Confirm cells | Result |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `threshold` | 0.5× → 0.45 | 24* | 4.03 | 2.18 | 3.09 | 0.89 | 0.00 | 5.47 | ±11.84 | no effect | – | – | no effect |
| `threshold` | 0.75× → 0.675 | 24* | 4.00 | 1.91 | 3.49 | 0.85 | -0.01 | 6.08 | ±11.79 | no effect | – | – | no effect |
| `threshold` | 1.1× → 0.99 | 24* | -35.30− | -35.32− | -37.02− | -37.23− | 0.09 | -40.19− | – | worse | – | – | worse |
| `coarse_threshold` | 0.5× → 0.375 | 24* | 3.12 | 3.03 | 2.66 | 2.94 | -0.07 | 6.06 | ±9.30 | no effect | – | – | no effect |
| `coarse_threshold` | 0.75× → 0.562 | 24* | 3.12 | 3.03 | 2.66 | 2.94 | -0.07 | 6.06 | ±9.30 | no effect | – | – | no effect |
| `coarse_threshold` | 1.32× → 0.99 | 24* | -85.37− | -86.35− | -90.66− | -92.52− | -0.42 | 20.32+ | – | worse | – | – | worse |
| `model_z` | 0.5× → 1.0 | 7 | 0.18 | 0.20 | -0.81 | -2.47 | -0.08 | 3.45 | ±4.26 | no effect | – | – | no effect |
| `model_z` | 0.75× → 1.5 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | no effect | – | – | no effect |
| `model_z` | 1.5× → 3.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | no effect | – | – | no effect |
| `model_z` | 2.0× → 4.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | no effect | – | – | no effect |
| `max_credence` | 0.99× → 0.98 | 24* | -0.46 | 0.45 | 0.28 | -0.43 | 0.03 | -1.60 | ±6.09 | no effect | – | – | no effect |
| `max_credence` | 0.997× → 0.987 | 6 | -0.27 | 0.21 | -0.23 | -0.42 | 0.00 | -0.03 | ±1.32 | no effect | – | – | no effect |
| `max_credence` | 1.003× → 0.993 | 7 | -1.78 | -1.60 | -0.90 | -1.71 | 0.01 | 3.35 | ±6.09 | no effect | – | – | no effect |
| `max_credence` | 1.005× → 0.995 | 11 | -1.47 | -1.67 | -1.55 | -2.19 | -0.07 | 1.71 | ±5.76 | no effect | – | – | no effect |
| `ratchet_growth` | 0.5× → 0.5 | 24* | 2.41 | 2.98 | 4.59 | 2.92 | -0.00 | 2.86 | ±11.24 | no effect | – | – | no effect |
| `ratchet_growth` | 0.75× → 0.75 | 24* | 1.79 | 2.38 | 3.36 | 1.42 | 0.10 | 6.03 | ±8.97 | no effect | – | – | no effect |
| `ratchet_growth` | 1.5× → 1.5 | 24* | -4.02 | -4.15 | -3.51 | -5.21 | 0.15 | -8.36 | ±11.80 | no effect | – | – | no effect |
| `ratchet_growth` | 2.0× → 2.0 | 24* | -6.73 | -6.18 | -5.82 | -7.68 | 0.10 | -9.47 | ±15.56 | no effect | – | – | no effect |
| `adv_z` | 0.5× → 1.5 | 24* | -1.28 | -2.11 | -2.48 | -2.32 | -0.20 | -9.83− | – | candidate | 24* | -2.81 / -2.78 / -3.08 / -3.48 / -0.04 / -7.09 (no effect) | screen only (not confirmed: no effect) |
| `adv_z` | 0.75× → 2.25 | 22 | -0.88 | -0.99 | -1.08 | -1.32 | 0.00 | -1.18 | ±5.16 | no effect | – | – | no effect |
| `adv_z` | 1.5× → 4.5 | 24* | 2.92 | 2.34 | 2.74 | 1.24 | 0.03 | 3.73 | ±9.07 | no effect | – | – | no effect |
| `adv_z` | 2.0× → 6.0 | 24* | 2.04 | 1.54 | 2.84 | 0.35 | 0.09 | 3.90 | ±10.27 | no effect | – | – | no effect |
| `acc_halflife` | 0.5× → 3.5 | 24* | 1.52 | 0.68 | 2.20 | 0.72 | -0.09 | -2.33 | ±10.06 | no effect | – | – | no effect |
| `acc_halflife` | 0.75× → 5.25 | 24* | 1.42 | 0.27 | 1.33 | -1.13 | -0.03 | 1.62 | ±9.51 | no effect | – | – | no effect |
| `acc_halflife` | 1.5× → 10.5 | 24* | -0.43 | 0.15 | -0.07 | -1.57 | 0.13 | -0.21 | ±10.44 | no effect | – | – | no effect |
| `acc_halflife` | 2.0× → 14.0 | 24* | -0.60 | -1.39 | -1.24 | -3.95 | -0.01 | -2.88 | ±10.40 | no effect | – | – | no effect |
| `ratchet_horizon` | 0.5× → 10.0 | 24* | -0.81 | -0.51 | -1.51 | -2.46 | 0.09 | -5.18 | ±6.19 | no effect | – | – | no effect |
| `ratchet_horizon` | 0.75× → 15.0 | 10 | -1.56 | -0.01 | -1.42 | -0.77 | -0.05 | -2.54 | ±5.64 | no effect | – | – | no effect |
| `ratchet_horizon` | 1.5× → 30.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | no effect | – | – | no effect |
| `ratchet_horizon` | 2.0× → 40.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | no effect | – | – | no effect |
| `actor_min_records` | 0.4× → 2.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | no effect | – | – | no effect |
| `actor_min_records` | 0.8× → 4.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | no effect | – | – | no effect |
| `actor_min_records` | 1.6× → 8.0 | 17 | -0.74 | -0.16 | 0.29 | -0.18 | -0.02 | 3.86 | ±5.11 | no effect | – | – | no effect |
| `actor_min_records` | 2.0× → 10.0 | 24* | -0.56 | 0.55 | 0.49 | 0.03 | -0.12 | 3.83 | ±6.86 | no effect | – | – | no effect |
| `adv_min_records` | 0.4× → 2.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | no effect | – | – | no effect |
| `adv_min_records` | 0.8× → 4.0 | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | no effect | – | – | no effect |
| `adv_min_records` | 1.6× → 8.0 | 24* | 2.60 | 1.61 | 2.87 | -0.57 | 0.20 | 1.37 | ±11.68 | no effect | – | – | no effect |
| `adv_min_records` | 2.0× → 10.0 | 24* | 2.60 | 1.61 | 2.87 | -0.57 | 0.20 | 1.37 | ±11.68 | no effect | – | – | no effect |
| `pattern_attention` | 0.5× → 4.5 | 24* | 5.47 | 6.11 | 6.35 | 4.04 | -0.11 | 12.48 | ±14.04 | no effect | – | – | no effect |
| `pattern_attention` | 0.75× → 6.75 | 24* | 1.55 | 0.85 | 1.03 | -0.75 | -0.01 | -0.28 | ±8.81 | no effect | – | – | no effect |
| `pattern_attention` | 1.5× → 13.5 | 24* | -3.05 | -4.79 | -3.32 | -7.25 | 0.18 | -15.89− | – | candidate | 24* | -3.64 / 0.08 / -3.65 / -1.32 / -0.22 / -4.11 (no effect) | screen only (not confirmed: no effect) |
| `pattern_attention` | 2.0× → 18.0 | 24* | -6.46 | -7.63 | -8.35 | -9.09 | -0.03 | -18.33− | – | candidate | 24* | -5.00 / -4.86 / -6.18 / -3.65 / 0.08 / -9.04 (no effect) | screen only (not confirmed: no effect) |
| `min_records` | 0.5× → 5.0 | 24* | 1.75 | 1.12 | 1.43 | -0.14 | 0.22 | 5.52 | ±11.29 | no effect | – | – | no effect |
| `min_records` | 0.8× → 8.0 | 24* | 0.51 | 1.36 | 0.49 | 0.22 | -0.14 | 4.39 | ±10.49 | no effect | – | – | no effect |
| `min_records` | 1.5× → 15.0 | 24* | 2.23 | 2.54 | 2.67 | 2.84 | 0.15 | 6.27 | ±10.01 | no effect | – | – | no effect |
| `min_records` | 2.0× → 20.0 | 24* | 0.70 | -0.03 | 1.90 | -0.51 | 0.07 | -2.67 | ±8.15 | no effect | – | – | no effect |
