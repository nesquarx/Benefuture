# Long-Horizon & Century Coupled Battery Report (L3.1–L3.3; 8.64, 8.81, 8.85, 8.86)

- **Commit**: `a86db6f`
- **Threads**: `1`
- **Status**: `IN PROGRESS` (7.9 minutes elapsed)
- **Coupling Mode**: `continuous = true` (persistent M3c state across epochs, L3.4 / `run_coupled`)
- **Significance Standard**: Exploratory `z = 2.0`; **README / formal claim bar `z = 3.0`**, contiguous paired seeds `1:N`.
- **Pre-stated Hypotheses & Smallest Effects That Matter (`L3.3`)**:
  - *Mechanisms (`:bf` vs `:status_quo`)*: Under identical world, adversaries, noise, and shocks (`L3.1`), Benefuture (`:decay`, `advap = true`, `ratchet_k = 3`, `:record`) yields higher `floor_u`, `floor_h`, `median_u`, `median_h`, smaller `worst_drop`, and higher `gov_acc` than `:status_quo` (`:window`, `advap = false`, `ratchet_k = 0`, `:normal`), with strongest advantage under `:stressed`.
  - *Stress (`:stressed` vs `:unstressed`)*: Catastrophes, outages, and metric capture degrade `floor_u`, `floor_h`, and `worst_drop` relative to `:unstressed` (which keeps breakthroughs and baseline hazards/deceivers equal).
  - *Smallest Effects That Matter*: `|Δ floor| >= 2.0`, `|Δ median| >= 2.0`, `|Δ worst_drop| >= 1.0`, `|Δ gov_acc| >= 0.01` (`1.0 pp`), at `z >= 3.0`.

## 1. 10-Year Coupled World (`:bf` × `:status_quo` × `:stressed` × `:unstressed`) (`steps = 120`, `epoch = 24`, `m5_decisions = 120`, `1:32` seeds, 7.8 min)

| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI | `z >= 3` |
|---|---|---|---|---|---|---|
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Stressed) | 75.587 | 75.386 | +0.201 ± 1.824 | +0.11 | [-3.446, 3.848] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Stressed) | 74.661 | 74.820 | -0.159 ± 1.762 | -0.09 | [-3.684, 3.365] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Stressed) | 92.948 | 91.767 | +1.181 ± 1.742 | +0.68 | [-2.303, 4.665] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Stressed) | 91.756 | 91.077 | +0.679 ± 1.816 | +0.37 | [-2.954, 4.311] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Stressed) | 27.430 | 28.340 | -0.910 ± 1.355 | -0.67 | [-3.620, 1.800] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Stressed) | 0.964 | 0.966 | -0.002 ± 0.002 | -0.70 | [-0.007, 0.003] | no |
| Floor U (`floor_u`) — Benefuture vs Status-Quo (Unstressed) | 79.524 | 78.114 | +1.409 ± 1.770 | +0.80 | [-2.131, 4.950] | no |
| Floor H (`floor_h`) — Benefuture vs Status-Quo (Unstressed) | 78.744 | 76.927 | +1.817 ± 1.566 | +1.16 | [-1.315, 4.950] | no |
| Median U (`median_u`) — Benefuture vs Status-Quo (Unstressed) | 94.256 | 92.312 | +1.944 ± 1.678 | +1.16 | [-1.412, 5.300] | no |
| Median H (`median_h`) — Benefuture vs Status-Quo (Unstressed) | 93.543 | 91.975 | +1.568 ± 1.708 | +0.92 | [-1.849, 4.985] | no |
| Worst drop (`worst_drop`) — Benefuture vs Status-Quo (Unstressed) | 4.486 | 4.454 | +0.032 ± 0.241 | +0.13 | [-0.450, 0.514] | no |
| Governance accuracy (`gov_acc`) — Benefuture vs Status-Quo (Unstressed) | 0.965 | 0.967 | -0.002 ± 0.002 | -0.70 | [-0.007, 0.003] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Benefuture) | 75.587 | 79.524 | -3.936 ± 1.280 | -3.07 | [-6.497, -1.376] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Benefuture) | 74.661 | 78.744 | -4.084 ± 1.395 | -2.93 | [-6.874, -1.293] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Benefuture) | 92.948 | 94.256 | -1.308 ± 0.927 | -1.41 | [-3.163, 0.546] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Benefuture) | 91.756 | 93.543 | -1.787 ± 0.877 | -2.04 | [-3.541, -0.033] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Benefuture) | 27.430 | 4.486 | +22.943 ± 5.210 | +4.40 | [12.523, 33.364] | yes |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Benefuture) | 0.964 | 0.965 | -0.001 ± 0.003 | -0.30 | [-0.007, 0.005] | no |
| Floor U (`floor_u`) — Stressed vs Unstressed (Status-Quo) | 75.386 | 78.114 | -2.728 ± 2.680 | -1.02 | [-8.088, 2.631] | no |
| Floor H (`floor_h`) — Stressed vs Unstressed (Status-Quo) | 74.820 | 76.927 | -2.107 ± 2.548 | -0.83 | [-7.204, 2.990] | no |
| Median U (`median_u`) — Stressed vs Unstressed (Status-Quo) | 91.767 | 92.312 | -0.545 ± 2.470 | -0.22 | [-5.485, 4.394] | no |
| Median H (`median_h`) — Stressed vs Unstressed (Status-Quo) | 91.077 | 91.975 | -0.898 ± 2.516 | -0.36 | [-5.931, 4.135] | no |
| Worst drop (`worst_drop`) — Stressed vs Unstressed (Status-Quo) | 28.340 | 4.454 | +23.885 ± 5.234 | +4.56 | [13.417, 34.354] | yes |
| Governance accuracy (`gov_acc`) — Stressed vs Unstressed (Status-Quo) | 0.966 | 0.967 | -0.001 ± 0.003 | -0.30 | [-0.007, 0.005] | no |


