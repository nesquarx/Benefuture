# Long-Horizon & Century Simulation Report

- **Commit**: `51006a9a9fe2c917a6d019667fb03d5eae7262f1`
- **Consolidation**: Sharded parallel execution merged via statistical pooling
- **Significance Standard**: Pre-stated `z = 2.0` (`z = 3.0` for README/BACKPROPAGATION).

| Suite | Metric | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|---|
| `10yr_coupled` | `floor_u_bf_vs_sq_stressed` | 81.4005 | 81.2539 | +0.1466 ± 1.0327 | +0.14 | [-1.8776, 2.1708] |
| `10yr_coupled` | `floor_h_bf_vs_sq_stressed` | 81.2542 | 81.3622 | -0.1080 ± 1.2689 | -0.09 | [-2.5950, 2.3791] |
| `10yr_coupled` | `median_u_bf_vs_sq_stressed` | 118.9092 | 119.2475 | -0.3383 ± 1.3795 | -0.25 | [-3.0421, 2.3655] |
| `10yr_coupled` | `median_h_bf_vs_sq_stressed` | 119.6963 | 119.0892 | +0.6071 ± 1.3585 | +0.45 | [-2.0556, 3.2698] |
| `10yr_coupled` | `worst_drop_bf_vs_sq_stressed` | 27.5657 | 26.8965 | +0.6691 ± 0.1943 | +3.44 | [0.2882, 1.0500] |
| `10yr_coupled` | `gov_acc_bf_vs_sq_stressed` | 0.9609 | 0.9625 | -0.0016 ± 0.0011 | -1.36 | [-0.0038, 0.0007] |
| `10yr_coupled` | `floor_u_bf_vs_sq_unstressed` | 86.6889 | 87.4792 | -0.7903 ± 1.2402 | -0.64 | [-3.2211, 1.6405] |
| `10yr_coupled` | `floor_h_bf_vs_sq_unstressed` | 87.2081 | 87.5601 | -0.3520 ± 1.1286 | -0.31 | [-2.5641, 1.8601] |
| `10yr_coupled` | `median_u_bf_vs_sq_unstressed` | 121.1688 | 122.1450 | -0.9762 ± 1.2749 | -0.77 | [-3.4751, 1.5226] |
| `10yr_coupled` | `median_h_bf_vs_sq_unstressed` | 121.0873 | 121.9903 | -0.9029 ± 1.2392 | -0.73 | [-3.3318, 1.5259] |
| `10yr_coupled` | `worst_drop_bf_vs_sq_unstressed` | 5.2691 | 5.2830 | -0.0139 ± 0.2104 | -0.07 | [-0.4263, 0.3985] |
| `10yr_coupled` | `gov_acc_bf_vs_sq_unstressed` | 0.9615 | 0.9630 | -0.0016 ± 0.0011 | -1.36 | [-0.0038, 0.0007] |
| `10yr_coupled` | `floor_u_stressed_vs_unstressed_bf` | 81.4005 | 86.6889 | -5.2884 ± 1.3052 | -4.05 | [-7.8465, -2.7303] |
| `10yr_coupled` | `floor_h_stressed_vs_unstressed_bf` | 81.2542 | 87.2081 | -5.9539 ± 1.3681 | -4.35 | [-8.6355, -3.2724] |
| `10yr_coupled` | `median_u_stressed_vs_unstressed_bf` | 118.9092 | 121.1688 | -2.2596 ± 0.8374 | -2.70 | [-3.9008, -0.6183] |
| `10yr_coupled` | `median_h_stressed_vs_unstressed_bf` | 119.6963 | 121.0873 | -1.3910 ± 0.8822 | -1.58 | [-3.1202, 0.3382] |
| `10yr_coupled` | `worst_drop_stressed_vs_unstressed_bf` | 27.5657 | 5.2691 | +22.2965 ± 4.7705 | +4.67 | [12.9463, 31.6467] |
| `10yr_coupled` | `gov_acc_stressed_vs_unstressed_bf` | 0.9609 | 0.9615 | -0.0005 ± 0.0009 | -0.57 | [-0.0023, 0.0013] |
| `10yr_coupled` | `floor_u_stressed_vs_unstressed_sq` | 81.2539 | 87.4792 | -6.2253 ± 1.3680 | -4.55 | [-8.9067, -3.5440] |
| `10yr_coupled` | `floor_h_stressed_vs_unstressed_sq` | 81.3622 | 87.5601 | -6.1980 ± 1.4619 | -4.24 | [-9.0633, -3.3326] |
| `10yr_coupled` | `median_u_stressed_vs_unstressed_sq` | 119.2475 | 122.1450 | -2.8975 ± 0.9883 | -2.93 | [-4.8346, -0.9604] |
| `10yr_coupled` | `median_h_stressed_vs_unstressed_sq` | 119.0892 | 121.9903 | -2.9010 ± 0.9503 | -3.05 | [-4.7636, -1.0385] |
| `10yr_coupled` | `worst_drop_stressed_vs_unstressed_sq` | 26.8965 | 5.2830 | +21.6135 ± 4.6622 | +4.64 | [12.4757, 30.7513] |
| `10yr_coupled` | `gov_acc_stressed_vs_unstressed_sq` | 0.9625 | 0.9630 | -0.0005 ± 0.0020 | -0.25 | [-0.0045, 0.0035] |
| `20yr_coupled_gov` | `floor_u_bf_vs_sq_stressed` | 168.1035 | 168.9652 | -0.8618 ± 1.1770 | -0.73 | [-3.1687, 1.4451] |
| `20yr_coupled_gov` | `floor_h_bf_vs_sq_stressed` | 167.8031 | 168.5823 | -0.7792 ± 1.2072 | -0.65 | [-3.1454, 1.5870] |
| `20yr_coupled_gov` | `median_u_bf_vs_sq_stressed` | 245.2550 | 246.4888 | -1.2338 ± 1.4509 | -0.85 | [-4.0775, 1.6099] |
| `20yr_coupled_gov` | `median_h_bf_vs_sq_stressed` | 245.1526 | 246.6637 | -1.5112 ± 1.3947 | -1.08 | [-4.2448, 1.2225] |
| `20yr_coupled_gov` | `worst_drop_bf_vs_sq_stressed` | 30.7103 | 30.8750 | -0.1647 ± 0.2399 | -0.69 | [-0.6349, 0.3055] |
| `20yr_coupled_gov` | `gov_acc_bf_vs_sq_stressed` | 0.9572 | 0.9548 | +0.0024 ± 0.0007 | +3.29 | [0.0010, 0.0039] |
| `20yr_coupled_gov` | `floor_u_bf_vs_sq_unstressed` | 174.8926 | 174.3827 | +0.5099 ± 1.1907 | +0.43 | [-1.8238, 2.8437] |
| `20yr_coupled_gov` | `floor_h_bf_vs_sq_unstressed` | 174.6422 | 174.9296 | -0.2874 ± 1.1717 | -0.25 | [-2.5839, 2.0091] |
| `20yr_coupled_gov` | `median_u_bf_vs_sq_unstressed` | 249.6551 | 249.1752 | +0.4799 ± 1.2825 | +0.37 | [-2.0338, 2.9936] |
| `20yr_coupled_gov` | `median_h_bf_vs_sq_unstressed` | 249.3185 | 249.0700 | +0.2485 ± 1.1469 | +0.22 | [-1.9995, 2.4965] |
| `20yr_coupled_gov` | `worst_drop_bf_vs_sq_unstressed` | 6.1790 | 6.0909 | +0.0881 ± 0.1848 | +0.48 | [-0.2740, 0.4503] |
| `20yr_coupled_gov` | `gov_acc_bf_vs_sq_unstressed` | 0.9570 | 0.9550 | +0.0020 ± 0.0007 | +3.12 | [0.0008, 0.0033] |
| `20yr_coupled_gov` | `floor_u_stressed_vs_unstressed_bf` | 168.1035 | 174.8926 | -6.7892 ± 1.3239 | -5.13 | [-9.3840, -4.1943] |
| `20yr_coupled_gov` | `floor_h_stressed_vs_unstressed_bf` | 167.8031 | 174.6422 | -6.8391 ± 1.2520 | -5.46 | [-9.2931, -4.3851] |
| `20yr_coupled_gov` | `median_u_stressed_vs_unstressed_bf` | 245.2550 | 249.6551 | -4.4002 ± 1.0458 | -4.21 | [-6.4499, -2.3505] |
| `20yr_coupled_gov` | `median_h_stressed_vs_unstressed_bf` | 245.1526 | 249.3185 | -4.1659 ± 0.9916 | -4.20 | [-6.1094, -2.2224] |
| `20yr_coupled_gov` | `worst_drop_stressed_vs_unstressed_bf` | 30.7103 | 6.1790 | +24.5313 ± 5.2324 | +4.69 | [14.2757, 34.7868] |
| `20yr_coupled_gov` | `gov_acc_stressed_vs_unstressed_bf` | 0.9572 | 0.9570 | +0.0002 ± 0.0004 | +0.49 | [-0.0006, 0.0010] |
| `20yr_coupled_gov` | `floor_u_stressed_vs_unstressed_sq` | 168.9652 | 174.3827 | -5.4174 ± 1.1934 | -4.54 | [-7.7564, -3.0785] |
| `20yr_coupled_gov` | `floor_h_stressed_vs_unstressed_sq` | 168.5823 | 174.9296 | -6.3473 ± 1.3387 | -4.74 | [-8.9712, -3.7235] |
| `20yr_coupled_gov` | `median_u_stressed_vs_unstressed_sq` | 246.4888 | 249.1752 | -2.6865 ± 0.9048 | -2.97 | [-4.4598, -0.9131] |
| `20yr_coupled_gov` | `median_h_stressed_vs_unstressed_sq` | 246.6637 | 249.0700 | -2.4062 ± 0.9378 | -2.57 | [-4.2443, -0.5682] |
| `20yr_coupled_gov` | `worst_drop_stressed_vs_unstressed_sq` | 30.8750 | 6.0909 | +24.7841 ± 5.2751 | +4.70 | [14.4450, 35.1232] |
| `20yr_coupled_gov` | `gov_acc_stressed_vs_unstressed_sq` | 0.9548 | 0.9550 | -0.0002 ± 0.0006 | -0.35 | [-0.0014, 0.0010] |
| `100yr_century` | `floor_u_bf_vs_sq_stressed` | 928.4219 | 923.8388 | +4.5831 ± 2.9727 | +1.54 | [-1.2433, 10.4095] |
| `100yr_century` | `floor_h_bf_vs_sq_stressed` | 928.6542 | 921.9642 | +6.6900 ± 2.8990 | +2.31 | [1.0079, 12.3721] |
| `100yr_century` | `median_u_bf_vs_sq_stressed` | 1279.1464 | 1273.9544 | +5.1920 ± 3.9916 | +1.30 | [-2.6315, 13.0155] |
| `100yr_century` | `median_h_bf_vs_sq_stressed` | 1277.7377 | 1270.7819 | +6.9558 ± 3.5464 | +1.96 | [0.0048, 13.9068] |
| `100yr_century` | `worst_drop_bf_vs_sq_stressed` | 38.7295 | 38.4294 | +0.3001 ± 0.2549 | +1.18 | [-0.1996, 0.7997] |
| `100yr_century` | `gov_acc_bf_vs_sq_stressed` | 0.9551 | 0.9540 | +0.0010 ± 0.0005 | +1.92 | [-0.0000, 0.0021] |
| `100yr_century` | `floor_u_bf_vs_sq_unstressed` | 940.2561 | 936.2336 | +4.0225 ± 2.9717 | +1.35 | [-1.8019, 9.8470] |
| `100yr_century` | `floor_h_bf_vs_sq_unstressed` | 938.8332 | 934.2914 | +4.5418 ± 2.9157 | +1.56 | [-1.1730, 10.2567] |
| `100yr_century` | `median_u_bf_vs_sq_unstressed` | 1287.7976 | 1283.2252 | +4.5724 ± 3.6848 | +1.24 | [-2.6499, 11.7946] |
| `100yr_century` | `median_h_bf_vs_sq_unstressed` | 1286.8120 | 1279.9659 | +6.8461 ± 3.3301 | +2.06 | [0.3192, 13.3731] |
| `100yr_century` | `worst_drop_bf_vs_sq_unstressed` | 11.1827 | 10.7721 | +0.4106 ± 0.2350 | +1.75 | [-0.0499, 0.8712] |
| `100yr_century` | `gov_acc_bf_vs_sq_unstressed` | 0.9556 | 0.9548 | +0.0008 ± 0.0006 | +1.38 | [-0.0003, 0.0020] |
| `100yr_century` | `floor_u_stressed_vs_unstressed_bf` | 928.4219 | 940.2561 | -11.8342 ± 1.2526 | -9.45 | [-14.2892, -9.3792] |
| `100yr_century` | `floor_h_stressed_vs_unstressed_bf` | 928.6542 | 938.8332 | -10.1790 ± 1.3460 | -7.56 | [-12.8172, -7.5409] |
| `100yr_century` | `median_u_stressed_vs_unstressed_bf` | 1279.1464 | 1287.7976 | -8.6511 ± 1.5588 | -5.55 | [-11.7064, -5.5959] |
| `100yr_century` | `median_h_stressed_vs_unstressed_bf` | 1277.7377 | 1286.8120 | -9.0743 ± 1.5517 | -5.85 | [-12.1157, -6.0329] |
| `100yr_century` | `worst_drop_stressed_vs_unstressed_bf` | 38.7295 | 11.1827 | +27.5468 ± 4.9209 | +5.60 | [17.9019, 37.1918] |
| `100yr_century` | `gov_acc_stressed_vs_unstressed_bf` | 0.9551 | 0.9556 | -0.0006 ± 0.0007 | -0.77 | [-0.0020, 0.0009] |
| `100yr_century` | `floor_u_stressed_vs_unstressed_sq` | 923.8388 | 936.2336 | -12.3947 ± 2.1338 | -5.81 | [-16.5770, -8.2124] |
| `100yr_century` | `floor_h_stressed_vs_unstressed_sq` | 921.9642 | 934.2914 | -12.3272 ± 1.8926 | -6.51 | [-16.0367, -8.6178] |
| `100yr_century` | `median_u_stressed_vs_unstressed_sq` | 1273.9544 | 1283.2252 | -9.2708 ± 1.8268 | -5.07 | [-12.8513, -5.6903] |
| `100yr_century` | `median_h_stressed_vs_unstressed_sq` | 1270.7819 | 1279.9659 | -9.1839 ± 1.6670 | -5.51 | [-12.4514, -5.9165] |
| `100yr_century` | `worst_drop_stressed_vs_unstressed_sq` | 38.4294 | 10.7721 | +27.6574 ± 5.0223 | +5.51 | [17.8136, 37.5011] |
| `100yr_century` | `gov_acc_stressed_vs_unstressed_sq` | 0.9540 | 0.9548 | -0.0008 ± 0.0007 | -1.16 | [-0.0021, 0.0005] |
| `open_885_better_models` | `takeover_count_decay_vs_window` | 2.5938 | 2.8125 | -0.2188 ± 0.2448 | -0.89 | [-0.6986, 0.2611] |
| `open_885_better_models` | `own_share_decay_vs_window` | 0.6123 | 0.5781 | +0.0342 ± 0.0225 | +1.52 | [-0.0099, 0.0784] |
| `open_885_better_models` | `floor_u_decay_vs_window` | 456.4619 | 404.8461 | +51.6158 ± 34.5720 | +1.49 | [-16.1453, 119.3769] |
