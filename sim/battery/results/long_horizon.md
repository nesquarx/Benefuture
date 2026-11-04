# Long-Horizon & Century Simulation Report

- **Commit**: `4db4a6aaf805607067374ec3864be3941f693126`
- **Consolidation**: Sharded parallel execution merged via statistical pooling
- **Significance Standard**: Pre-stated `z = 2.0` (`z = 3.0` for README/BACKPROPAGATION).

| Suite | Metric | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|---|
| `10yr_economy` | `floor_u_decay_vs_window` | 135.8453 | 133.0984 | +2.7469 ± 1.5321 | +1.79 | [-0.2559, 5.7498] |
| `10yr_economy` | `floor_h_decay_vs_window` | 135.0729 | 133.3197 | +1.7532 ± 1.5197 | +1.15 | [-1.2254, 4.7319] |
| `10yr_economy` | `tx_count_decay_vs_window` | 1015.6250 | 1004.5000 | +11.1250 ± 8.2729 | +1.34 | [-5.0899, 27.3399] |
| `10yr_economy` | `floor_u_stressed_vs_unstressed` | 112.3066 | 135.8453 | -23.5388 ± 1.8357 | -12.82 | [-27.1367, -19.9409] |
| `10yr_economy` | `floor_h_stressed_vs_unstressed` | 112.0909 | 135.0729 | -22.9821 ± 1.6322 | -14.08 | [-26.1811, -19.7830] |
| `10yr_economy` | `floor_u_bf_vs_status_quo` | 112.3066 | 50.9272 | +61.3793 ± 13.7016 | +4.48 | [34.5242, 88.2344] |
| `10yr_economy` | `floor_h_bf_vs_status_quo` | 112.0909 | 50.0049 | +62.0859 ± 13.4726 | +4.61 | [35.6797, 88.4922] |
| `20yr_governance` | `late_half_acc_advap_vs_none` | 0.9806 | 0.9543 | +0.0264 ± 0.0020 | +13.44 | [0.0225, 0.0302] |
| `20yr_governance` | `late_half_acc_coll_vs_clean` | 0.9806 | 0.9827 | -0.0021 ± 0.0018 | -1.16 | [-0.0056, 0.0015] |
| `100yr_century` | `century_floor_u_stressed_vs_unstressed` | 1359.2312 | 1225.7846 | +133.4466 ± 6.8064 | +19.61 | [120.1061, 146.7871] |
| `100yr_century` | `century_floor_h_stressed_vs_unstressed` | 1353.6171 | 1215.3350 | +138.2821 ± 5.9505 | +23.24 | [126.6191, 149.9452] |
| `100yr_century` | `century_gov_acc_stressed_vs_unstressed` | 0.9624 | 0.9625 | -0.0001 ± 0.0003 | -0.37 | [-0.0007, 0.0005] |
| `100yr_century` | `century_floor_u_bf_vs_status_quo` | 1359.2312 | 1365.2008 | -5.9695 ± 4.9068 | -1.22 | [-15.5869, 3.6478] |
| `100yr_century` | `century_floor_h_bf_vs_status_quo` | 1353.6171 | 1358.7035 | -5.0864 ± 5.0875 | -1.00 | [-15.0579, 4.8851] |
| `100yr_century` | `century_gov_acc_bf_vs_status_quo` | 0.9624 | 0.9625 | -0.0001 ± 0.0003 | -0.32 | [-0.0007, 0.0005] |
| `open_885_better_models` | `takeover_count_decay_vs_window` | 2.5000 | 2.4375 | +0.0625 ± 0.3091 | +0.20 | [-0.5434, 0.6684] |
| `open_885_better_models` | `own_share_decay_vs_window` | 0.5841 | 0.5856 | -0.0015 ± 0.0320 | -0.05 | [-0.0642, 0.0612] |
| `open_885_better_models` | `floor_u_decay_vs_window` | 467.0635 | 396.6152 | +70.4483 ± 49.6037 | +1.42 | [-26.7749, 167.6716] |
