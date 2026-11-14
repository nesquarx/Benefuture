# Anti-Corruption (L160) attack-payoff table (8.142)

Build: commit `3fe3331` (working tree may carry uncommitted edits). Runtime: 748.8 s, seeds: `1:16` (16 paired seeds).

Measured claim: every known attack pays less than honesty on the same seeds, judged by `paired_effect` (`z = 2` with Student-t inflation). An attack whose paired difference (`attacker payoff − honest baseline`) is significantly positive (`direction = :up`) is flagged **[OPEN]**.

| Attack | Unit | Mean Δ (attack − honest) | t-inflated interval (z = 2) | Seeds | Verdict |
|---|---|---|---|---|---|
| Overpromising (AdvAp + clawback) | standing | -181.39 ± 126.16 | [-455.73, +92.95] | 16 | no significant gain |
| Overpromising (track record, no AdvAp) | standing | -17.79 ± 127.03 | [-294.01, +258.43] | 16 | no significant gain |
| Decision market (harmful proposals, explore=0.2) | standing | -5967.93 ± 95.61 | [-6175.82, -5760.04] | 16 | attack costs |
| Frozen worst economy attack (bloc, default p_trace=0.5) | bloc mean standing | -7519.09 ± 228.84 | [-8016.69, -7021.48] | 16 | attack costs |
| Frozen worst economy attack (untraced, p_trace=0.0) | bloc mean standing | -23.52 ± 264.61 | [-598.91, +551.86] | 16 | no significant gain |
| Laundering (traced, p_trace=1.0) | standing | -733.29 ± 52.23 | [-846.87, -619.70] | 16 | attack costs |
| Laundering (untraced, p_trace=0.0) | standing | -0.72 ± 10.78 | [-24.15, +22.72] | 16 | no significant gain |
| On-off oscillation (AdvAp + 8.91 clawback) | standing | -5660.94 ± 111.49 | [-5903.38, -5418.49] | 16 | attack costs |
| Slandering (frivolous=1.0 on peer, AdvAp) | standing | -262.98 ± 97.51 | [-475.01, -50.96] | 16 | attack costs |
| Whitewashing (3 clusters, weighted binding) | standing | +28.27 ± 142.65 | [-281.91, +338.45] | 16 | no significant gain |
| Whitewashing + compromised clusters (2/3, weighted) | standing | +78.72 ± 137.45 | [-220.17, +377.60] | 16 | no significant gain |
| Model collusion (track_window=20, AdvAp) | standing | -8158.46 ± 3617.35 | [-16024.35, -292.56] | 16 | attack costs |
| Profile gaming (:measured routing) | standing | +0.00 ± 0.00 | [+0.00, +0.00] | 16 | no significant gain |
| M5 stealthy voter collusion (AdvAp + diversity) | bloc rep share delta | -0.56 ± 0.02 | [-0.61, -0.51] | 16 | attack costs |
| Sybil harm split (-2 split beside +1.5 co-contributor, rule level, 8.58-e) | Shapley credit Δ | +0.267 | deterministic (no noise) | rule | [OPEN] attack pays unless identity-bound |
