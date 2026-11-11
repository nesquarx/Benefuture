# Long-Horizon & Century Simulation Report

- **Commit**: `755d017ef12b561ab87a9ffbaf246db6e284a64b`
- **Consolidation**: Sharded parallel execution merged via statistical pooling
- **Significance Standard**: Pre-stated `z = 2.0` (`z = 3.0` for README/BACKPROPAGATION).

| Suite | Metric | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|---|
| `10yr_economy` | `floor_u_decay_vs_window` | 134.1348 | 132.6219 | +1.5130 ± 1.5091 | +1.00 | [-1.4449, 4.4709] |
| `10yr_economy` | `floor_h_decay_vs_window` | 133.5382 | 131.4392 | +2.0989 ± 1.5743 | +1.33 | [-0.9866, 5.1845] |
| `10yr_economy` | `tx_count_decay_vs_window` | 998.8750 | 989.8750 | +9.0000 ± 11.0551 | +0.81 | [-12.6679, 30.6679] |
| `10yr_economy` | `floor_u_stressed_vs_unstressed` | 113.0669 | 134.1348 | -21.0680 ± 2.3761 | -8.87 | [-25.7251, -16.4108] |
| `10yr_economy` | `floor_h_stressed_vs_unstressed` | 112.5378 | 133.5382 | -21.0004 ± 3.1013 | -6.77 | [-27.0789, -14.9219] |
| `10yr_economy` | `floor_u_bf_vs_status_quo` | 113.0669 | 56.5657 | +56.5012 ± 18.7908 | +3.01 | [19.6713, 93.3311] |
| `10yr_economy` | `floor_h_bf_vs_status_quo` | 112.5378 | 56.0898 | +56.4479 ± 18.8386 | +3.00 | [19.5244, 93.3715] |
| `20yr_governance` | `late_half_acc_advap_vs_none` | 0.9823 | 0.9525 | +0.0298 ± 0.0020 | +14.69 | [0.0258, 0.0338] |
| `20yr_governance` | `late_half_acc_coll_vs_clean` | 0.9823 | 0.9833 | -0.0010 ± 0.0024 | -0.44 | [-0.0057, 0.0036] |
| `100yr_century` | `century_floor_u_stressed_vs_unstressed` | 1342.2614 | 1207.1348 | +135.1266 ± 5.4805 | +24.66 | [124.3849, 145.8684] |
| `100yr_century` | `century_floor_h_stressed_vs_unstressed` | 1334.8923 | 1200.2835 | +134.6088 ± 7.8295 | +17.19 | [119.2629, 149.9546] |
| `100yr_century` | `century_gov_acc_stressed_vs_unstressed` | 0.9615 | 0.9610 | +0.0004 ± 0.0004 | +1.00 | [-0.0004, 0.0012] |
| `100yr_century` | `century_floor_u_bf_vs_status_quo` | 1342.2614 | 1345.1946 | -2.9332 ± 5.3355 | -0.55 | [-13.3907, 7.5244] |
| `100yr_century` | `century_floor_h_bf_vs_status_quo` | 1334.8923 | 1339.8452 | -4.9529 ± 6.6050 | -0.75 | [-17.8986, 7.9929] |
| `100yr_century` | `century_gov_acc_bf_vs_status_quo` | 0.9615 | 0.9619 | -0.0004 ± 0.0004 | -1.00 | [-0.0012, 0.0004] |
| `open_885_better_models` | `takeover_count_decay_vs_window` | 2.3750 | 2.3750 | +0.0000 ± 0.4226 | +0.00 | [-0.8283, 0.8283] |
| `open_885_better_models` | `own_share_decay_vs_window` | 0.5926 | 0.6149 | -0.0223 ± 0.0486 | -0.46 | [-0.1175, 0.0730] |
| `open_885_better_models` | `floor_u_decay_vs_window` | 485.2325 | 425.7513 | +59.4812 ± 74.5368 | +0.80 | [-86.6109, 205.5734] |
