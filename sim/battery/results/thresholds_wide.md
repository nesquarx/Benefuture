# Governed-threshold perturbation battery (active world) (wide grid, 8.164)

Build: commit 70052b6. World: active. Grid: wide. 300 steps; run time 82.9 minutes; 71 distinct arms, 1 flagged.

Seeds and bars: seeds by precision per arm (stop when the t-inflated standard error of the paired floor-u difference is at most 1.5, 6 to 24 seeds; * = cap reached without that precision); stage 1 screen on seeds 1..; every verdict at z = 3.0, Student-t inflated. Two-stage rule: a screen candidate is re-measured on the disjoint fresh seeds 1001.. (default re-run on them) and is FLAGGED only if the confirmation is also a candidate. For no-effect / inconsequential arms, `Equiv ±Δ` states the smallest achievable floor-u equivalence bound (`equivalent` at z = 3.0). `Touch` checks whether internal mechanism counters or outputs moved on any seed vs default (8.164).

World (active): economy battery + model churn (`p_new_model = 0.15`, `pool_max = 5 >= ratchet_k = 3`, `takeover_records = 20`), novel leaf formation (`form_count = 15`), binding budgets (`budget = true`, `endowment = 4.5`, `cost_per_touch = 0.75`), and a graded deceiver mix (`[0..0, 0.2, 0.4, 0.7]`). Each cell: mean paired difference from the default (arm − default); + / − significant at z = 3.0. Harm and the deceivers' advantage are better when lower. Candidate = some reading better and none worse; tradeoff = some reading better and another worse. Stage 2 cells: floor u / floor h / median u / median h / harm / deceivers' advantage.

## Per-threshold classification (Author Ruling 8.164)

| Threshold | Default | Touched arms | Worse/tradeoff low | Worse/tradeoff high | Classification |
|---|---|---|---|---|---|
| `threshold` | 0.9 | 4 / 4 | 3 | 1 | local_optimum / tradeoff_frontier (both sides bind) |
| `coarse_threshold` | 0.75 | 4 / 4 | 0 | 1 | one_sided_cliff / tradeoff (high binds) |
| `model_z` | 2.0 | 3 / 6 | 0 | 0 | inconclusive (touches system, n.s. at z=3) |
| `max_credence` | 0.99 | 8 / 8 | 3 | 0 | one_sided_cliff / tradeoff (low binds) |
| `ratchet_growth` | 1.0 | 7 / 7 | 1 (Stage 2) | 0 | one_sided_cliff / tradeoff (low 0.0 binds Stage 2 `+12.17+ floor_u / +11.43+ adv`) |
| `adv_z` | 3.0 | 6 / 6 | 0 | 3 | one_sided_cliff / tradeoff (high binds) |
| `acc_halflife` | 7.0 | 6 / 6 | 2 (0.7 & 1.75@64) | 0 | one_sided_cliff / tradeoff (low binds at 64 seeds: `0.7` & `1.75` both cut `adv` at significant floor cost) |
| `ratchet_horizon` | 20.0 | 3 / 6 | 2 (`2.0` & `5.0`) | 0 | one_sided_cliff (low binds; `>= 40` untouched) |
| `actor_min_records` | 5 | 3 / 5 | 0 | 0 | masked below (`1..2` untouched by `init_steps = 50`); touches above (`n.s.` at z=3, `Equiv ±11.29`) |
| `adv_min_records` | 5 | 3 / 5 | 0 | 2 | one_sided_cliff (high binds; `1..2` masked by `init_steps = 50`) |
| `pattern_attention` | 9.0 | 7 / 7 | 4 | 3 | local_optimum / tradeoff_frontier (both sides bind) |
| `min_records` | 10 | 7 / 7 | 1 | 0 | one_sided_cliff / tradeoff (low `0.0` binds) |

> **64-seed replication on `acc_halflife = 0.25× → 1.75` (`70052b6`, `min = 64, max = 64`, `24.0 min`):** In the initial 24-seed Stage 1 + Stage 2 screens above, `1.75` FLAGGED because `adv` fell significantly (`-13.93−`, `-13.03−`) while `floor_u` (`-3.06`, `-5.24`) and `floor_h` (`-2.15`, `-2.12`) stayed below `z = 3`. On **`64` paired seeds** (`yes (audits 77)`), **`acc_halflife = 1.75` resolves as a confirmed `tradeoff`**: `floor_h = -5.52−`, `adv = -16.41−` (`floor_u = -4.73`, `median_u = -4.65`, `median_h = -5.11`, `harm = +0.13`). Across all `71` wide arms and 64-seed follow-up, **0** genuine improvements over defaults exist.

## Per-arm results

| Threshold | Setting | Touch | Seeds | Floor u | Floor h | Median u | Median h | Harm peak | Deceivers' advantage | Equiv ±Δ (floor u, z=3) | Screen | Confirm seeds | Confirm cells | Result |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `threshold` | 0.1× → 0.09 | yes (audits 40) | 24* | 6.77 | 3.94 | 6.01 | 4.13 | -0.13 | 12.61+ | – | worse | – | – | worse |
| `threshold` | 0.25× → 0.225 | yes (audits 40) | 24* | 6.77 | 3.94 | 6.01 | 4.13 | -0.13 | 12.61+ | – | worse | – | – | worse |
| `threshold` | 0.5× → 0.45 | yes (audits 40) | 24* | 6.77 | 3.94 | 6.01 | 4.13 | -0.13 | 12.61+ | – | worse | – | – | worse |
| `threshold` | 1.106× → 0.995 | yes (audits 65) | 24* | -22.73− | -24.07− | -26.62− | -24.66− | -0.20 | -26.21− | – | tradeoff | – | – | tradeoff |
| `coarse_threshold` | 0.1× → 0.075 | yes (audits 40) | 18 | 1.83 | 2.28 | 1.20 | 1.76 | -0.06 | 2.39 | ±6.08 | no effect | – | – | no effect |
| `coarse_threshold` | 0.25× → 0.188 | yes (audits 40) | 18 | 1.83 | 2.28 | 1.20 | 1.76 | -0.06 | 2.39 | ±6.08 | no effect | – | – | no effect |
| `coarse_threshold` | 0.5× → 0.375 | yes (audits 40) | 18 | 1.83 | 2.28 | 1.20 | 1.76 | -0.06 | 2.39 | ±6.08 | no effect | – | – | no effect |
| `coarse_threshold` | 1.327× → 0.995 | yes (audits 102) | 24* | -97.58− | -97.19− | -103.08− | -102.57− | -0.53 | 26.19+ | – | worse | – | – | worse |
| `model_z` | 0.1× → 0.2 | yes (audits 40) | 24* | 3.08 | 1.98 | 2.42 | 2.75 | -0.25 | 2.88 | ±10.03 | no effect | – | – | no effect |
| `model_z` | 0.25× → 0.5 | yes (audits 43) | 24* | 2.19 | 3.22 | 2.88 | 3.57 | -0.15 | 6.97 | ±9.50 | no effect | – | – | no effect |
| `model_z` | 0.5× → 1.0 | yes (audits 40) | 24* | 1.10 | 0.88 | 0.28 | 0.11 | -0.08 | 2.59 | ±5.61 | no effect | – | – | no effect |
| `model_z` | 2.0× → 4.0 | NONE (0) | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | inconsequential | – | – | inconsequential |
| `model_z` | 5.0× → 10.0 | NONE (0) | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | inconsequential | – | – | inconsequential |
| `model_z` | 10.0× → 20.0 | NONE (0) | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | inconsequential | – | – | inconsequential |
| `max_credence` | 0.909× → 0.9 | yes (audits 78) | 24* | -8.12− | -9.92− | -8.16 | -9.69− | -0.08 | -14.24− | – | tradeoff | – | – | tradeoff |
| `max_credence` | 0.97× → 0.96 | yes (audits 28) | 24* | -0.31 | -1.24 | -1.18 | -1.07 | -0.18 | -0.43 | ±6.84 | no effect | – | – | no effect |
| `max_credence` | 0.99× → 0.98 | yes (audits 21) | 6 | -1.19 | -1.27 | 0.10 | -2.10 | -0.10 | 3.42 | ±4.40 | no effect | – | – | no effect |
| `max_credence` | 1.005× → 0.995 | yes (audits 21) | 11 | -0.95 | -1.14 | -0.72 | -1.30 | -0.05 | 2.70 | ±5.41 | no effect | – | – | no effect |
| `max_credence` | 1.008× → 0.998 | yes (audits 35) | 24* | -1.80 | -1.23 | -1.69 | -1.44 | -0.10 | 0.29 | ±6.46 | no effect | – | – | no effect |
| `max_credence` | 1.009× → 0.999 | yes (audits 35) | 24* | -1.78 | -1.35 | -1.53 | -1.36 | -0.10 | -0.09 | ±6.43 | no effect | – | – | no effect |
| `ratchet_growth` | 0.1× → 0.1 | yes (audits 41) | 24* | 7.13 | 5.98 | 6.68 | 6.59 | -0.18 | 4.62 | ±14.37 | no effect | – | – | no effect |
| `ratchet_growth` | 0.25× → 0.25 | yes (audits 40) | 24* | 4.76 | 3.63 | 4.58 | 4.35 | -0.20 | 2.66 | ±12.17 | no effect | – | – | no effect |
| `ratchet_growth` | 0.5× → 0.5 | yes (audits 50) | 24* | 3.98 | 1.84 | 3.59 | 3.17 | -0.14 | 2.48 | ±11.92 | no effect | – | – | no effect |
| `ratchet_growth` | 2.0× → 2.0 | yes (audits 50) | 24* | -2.27 | -3.03 | -2.58 | -1.89 | -0.10 | -5.76 | ±8.55 | no effect | – | – | no effect |
| `ratchet_growth` | 5.0× → 5.0 | yes (audits 34) | 24* | -4.25 | -4.66 | -4.94 | -4.08 | -0.26 | 0.26 | ±11.50 | no effect | – | – | no effect |
| `ratchet_growth` | 10.0× → 10.0 | yes (audits 38) | 24* | -5.15 | -5.92 | -5.97 | -4.96 | -0.24 | -4.11 | ±12.29 | no effect | – | – | no effect |
| `adv_z` | 0.1× → 0.3 | yes (established 30) | 8 | 1.10 | -4.38 | -0.34 | -1.16 | 0.08 | 2.78 | ±5.35 | no effect | – | – | no effect |
| `adv_z` | 0.25× → 0.75 | yes (established 30) | 6 | 0.61 | -4.58 | -2.91 | -3.28 | -0.04 | 1.15 | ±5.00 | no effect | – | – | no effect |
| `adv_z` | 0.5× → 1.5 | yes (established 30) | 8 | 0.55 | -3.91 | -1.69 | -1.89 | 0.04 | 0.23 | ±4.55 | no effect | – | – | no effect |
| `adv_z` | 2.0× → 6.0 | yes (audits 32) | 24* | 5.72 | 4.07 | 6.15 | 4.75 | -0.01 | 12.97+ | – | worse | – | – | worse |
| `adv_z` | 5.0× → 15.0 | yes (audits 66) | 24* | 16.34+ | 15.26+ | 17.02+ | 16.15+ | -0.35 | 33.78+ | – | tradeoff | – | – | tradeoff |
| `adv_z` | 10.0× → 30.0 | yes (audits 90) | 24* | 16.98+ | 18.05+ | 19.65+ | 19.17+ | 0.02 | 50.86+ | – | tradeoff | – | – | tradeoff |
| `acc_halflife` | 0.1× → 0.7 | yes (audits 84) | 24* | -8.63− | -8.90− | -9.29− | -9.55− | -0.38 | -25.30− | – | tradeoff | – | – | tradeoff |
| `acc_halflife` | 0.25× → 1.75 | yes (audits 77) | 24* | -3.06 | -2.15 | -1.74 | -3.43 | -0.10 | -13.93− | – | candidate | 24* | -5.24 / -2.12 / -3.72 / -4.01 / -0.29 / -13.03− (candidate) | FLAGGED |
| `acc_halflife` | 0.5× → 3.5 | yes (audits 70) | 24* | -1.56 | -0.84 | -0.63 | -0.60 | -0.28 | -1.63 | ±9.74 | no effect | – | – | no effect |
| `acc_halflife` | 2.0× → 14.0 | yes (audits 49) | 24* | -0.63 | -0.29 | 0.06 | -0.67 | -0.21 | 0.47 | ±8.91 | no effect | – | – | no effect |
| `acc_halflife` | 5.0× → 35.0 | yes (audits 39) | 24* | -3.04 | -3.63 | -3.16 | -4.12 | -0.13 | -2.84 | ±10.20 | no effect | – | – | no effect |
| `acc_halflife` | 10.0× → 70.0 | yes (audits 50) | 24* | -4.77 | -4.02 | -4.11 | -5.30 | -0.22 | -1.96 | ±14.69 | no effect | – | – | no effect |
| `ratchet_horizon` | 0.1× → 2.0 | yes (audits 60) | 24* | -12.87− | -13.30− | -13.30− | -14.74− | -0.06 | -21.07− | – | tradeoff | – | – | tradeoff |
| `ratchet_horizon` | 0.25× → 5.0 | yes (audits 62) | 24* | -4.35 | -5.46 | -5.67 | -5.53 | -0.26 | -8.85− | – | candidate | 24* | -6.90− / -6.78− / -6.87− / -8.23− / -0.03 / -11.62− (tradeoff) | screen only (not confirmed: tradeoff) |
| `ratchet_horizon` | 0.5× → 10.0 | yes (audits 40) | 6 | 0.07 | -1.36 | -0.44 | 0.05 | 0.00 | -3.24 | ±2.56 | no effect | – | – | no effect |
| `ratchet_horizon` | 2.0× → 40.0 | NONE (0) | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | inconsequential | – | – | inconsequential |
| `ratchet_horizon` | 5.0× → 100.0 | NONE (0) | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | inconsequential | – | – | inconsequential |
| `ratchet_horizon` | 10.0× → 200.0 | NONE (0) | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | inconsequential | – | – | inconsequential |
| `actor_min_records` | 0.2× → 1.0 | NONE (0) | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | inconsequential | – | – | inconsequential |
| `actor_min_records` | 0.4× → 2.0 | NONE (0) | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | inconsequential | – | – | inconsequential |
| `actor_min_records` | 2.0× → 10.0 | yes (audits 35) | 24* | 2.47 | 1.69 | 1.76 | 1.10 | 0.02 | 2.34 | ±9.67 | no effect | – | – | no effect |
| `actor_min_records` | 5.0× → 25.0 | yes (audits 35) | 24* | 4.12 | 2.41 | 3.89 | 2.91 | 0.02 | 4.05 | ±11.29 | no effect | – | – | no effect |
| `actor_min_records` | 10.0× → 50.0 | yes (audits 35) | 24* | 4.12 | 2.41 | 3.89 | 2.91 | 0.02 | 4.05 | ±11.29 | no effect | – | – | no effect |
| `adv_min_records` | 0.2× → 1.0 | NONE (0) | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | inconsequential | – | – | inconsequential |
| `adv_min_records` | 0.4× → 2.0 | NONE (0) | 6 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | ±0.00 | inconsequential | – | – | inconsequential |
| `adv_min_records` | 2.0× → 10.0 | yes (audits 42) | 24* | 1.14 | 0.68 | 0.84 | 1.05 | -0.10 | 2.12 | ±8.59 | no effect | – | – | no effect |
| `adv_min_records` | 5.0× → 25.0 | yes (audits 68) | 24* | 3.20 | 3.64 | 3.56 | 3.31 | -0.16 | 12.41+ | – | worse | – | – | worse |
| `adv_min_records` | 10.0× → 50.0 | yes (audits 85) | 24* | 6.92 | 7.34+ | 7.27+ | 6.46 | -0.21 | 16.81+ | – | tradeoff | – | – | tradeoff |
| `pattern_attention` | 0.1× → 0.9 | yes (audits 95) | 24* | 11.81+ | 12.36+ | 13.03+ | 11.84+ | -0.25 | 30.76+ | – | tradeoff | – | – | tradeoff |
| `pattern_attention` | 0.25× → 2.25 | yes (audits 78) | 24* | 9.45+ | 6.40 | 8.85+ | 8.14+ | -0.24 | 22.39+ | – | tradeoff | – | – | tradeoff |
| `pattern_attention` | 0.5× → 4.5 | yes (audits 64) | 24* | 6.90 | 4.83 | 6.96+ | 6.26 | -0.26 | 15.17+ | – | tradeoff | – | – | tradeoff |
| `pattern_attention` | 2.0× → 18.0 | yes (audits 115) | 24* | -6.75 | -6.23 | -7.88− | -7.66− | -0.24 | -18.01− | – | tradeoff | – | – | tradeoff |
| `pattern_attention` | 5.0× → 45.0 | yes (audits 235) | 24* | -13.33− | -14.37− | -13.42− | -13.68− | -0.18 | -28.63− | – | tradeoff | – | – | tradeoff |
| `pattern_attention` | 10.0× → 90.0 | yes (audits 308) | 24* | -14.42− | -14.20− | -15.04− | -15.60− | -0.20 | -37.33− | – | tradeoff | – | – | tradeoff |
| `min_records` | 0.1× → 1.0 | yes (audits 41) | 24* | -1.30 | -2.57 | -1.11 | -1.39 | 0.01 | 8.02 | ±9.22 | no effect | – | – | no effect |
| `min_records` | 0.2× → 2.0 | yes (audits 40) | 24* | -0.18 | -1.94 | -1.05 | -1.19 | -0.10 | 5.77 | ±7.92 | no effect | – | – | no effect |
| `min_records` | 0.5× → 5.0 | yes (audits 35) | 24* | 0.14 | 0.16 | 0.47 | 1.52 | -0.15 | 2.26 | ±6.87 | no effect | – | – | no effect |
| `min_records` | 2.0× → 20.0 | yes (audits 49) | 24* | -1.35 | -1.69 | -1.36 | -1.82 | -0.11 | -6.48 | ±8.08 | no effect | – | – | no effect |
| `min_records` | 5.0× → 50.0 | yes (audits 33) | 24* | -4.59 | -5.03 | -3.41 | -4.84 | 0.02 | -8.73 | ±14.98 | no effect | – | – | no effect |
| `min_records` | 10.0× → 100.0 | yes (audits 45) | 24* | -5.61 | -5.77 | -5.74 | -6.20 | -0.20 | -10.51 | ±15.49 | no effect | – | – | no effect |
| `max_credence` | 0.606× → 0.6 | yes (audits 134) | 24* | -222.32− | -221.00− | -241.87− | -240.15− | -2.53− | 70.07+ | – | tradeoff | – | – | tradeoff |
| `max_credence` | 0.758× → 0.75 | yes (audits 126) | 24* | -214.84− | -213.57− | -232.88− | -231.35− | -1.89− | 66.09+ | – | tradeoff | – | – | tradeoff |
| `ratchet_growth` | 0.0× → 0.0 | yes (audits 47) | 24* | 8.91+ | 7.54+ | 9.81+ | 7.92+ | -0.19 | 3.54 | – | candidate | 24* | 12.17+ / 12.22+ / 11.91+ / 11.23+ / -0.12 / 11.43+ (tradeoff) | screen only (not confirmed: tradeoff) |
| `pattern_attention` | 0.0× → 0.0 | yes (audits 109) | 24* | 11.30+ | 9.88+ | 13.16+ | 11.20+ | -0.20 | 35.43+ | – | tradeoff | – | – | tradeoff |
| `min_records` | 0.0× → 0.0 | yes (audits 44) | 24* | -3.53 | -3.57 | -2.99 | -3.90 | -0.35 | 12.64+ | – | worse | – | – | worse |
