# Long-Horizon & Century Simulation Report

- **Commit**: `bc930b7365086bb050e27143ba28920539f89468`
- **Consolidation**: Sharded parallel execution merged via statistical pooling
- **Significance Standard**: Pre-stated `z = 2.0` (`z = 3.0` for README/BACKPROPAGATION).

| Suite | Metric | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|---|
| `10yr_coupled` | `floor_u_bf_vs_sq_stressed` | 75.2499 | 61.8315 | +13.4185 ± 7.4593 | +1.80 | [-1.2017, 28.0387] |
| `10yr_coupled` | `floor_h_bf_vs_sq_stressed` | 74.7898 | 62.5762 | +12.2136 ± 7.6987 | +1.59 | [-2.8759, 27.3031] |
| `10yr_coupled` | `median_u_bf_vs_sq_stressed` | 92.4739 | 78.1853 | +14.2886 ± 8.3653 | +1.71 | [-2.1074, 30.6845] |
| `10yr_coupled` | `median_h_bf_vs_sq_stressed` | 91.6231 | 77.8396 | +13.7836 ± 8.7769 | +1.57 | [-3.4192, 30.9863] |
| `10yr_coupled` | `worst_drop_bf_vs_sq_stressed` | 37.8794 | 37.9544 | -0.0750 ± 0.3757 | -0.20 | [-0.8115, 0.6614] |
| `10yr_coupled` | `gov_acc_bf_vs_sq_stressed` | 0.9653 | 0.9653 | +0.0000 ± 0.0052 | +0.00 | [-0.0103, 0.0103] |
| `10yr_coupled` | `floor_u_bf_vs_sq_unstressed` | 79.2094 | 78.0100 | +1.1994 ± 2.4237 | +0.49 | [-3.5511, 5.9499] |
| `10yr_coupled` | `floor_h_bf_vs_sq_unstressed` | 79.9466 | 77.3564 | +2.5903 ± 2.3819 | +1.09 | [-2.0782, 7.2588] |
| `10yr_coupled` | `median_u_bf_vs_sq_unstressed` | 94.8400 | 91.7230 | +3.1169 ± 2.6901 | +1.16 | [-2.1557, 8.3896] |
| `10yr_coupled` | `median_h_bf_vs_sq_unstressed` | 93.6277 | 91.1250 | +2.5027 ± 2.3699 | +1.06 | [-2.1423, 7.1477] |
| `10yr_coupled` | `worst_drop_bf_vs_sq_unstressed` | 4.7553 | 5.2301 | -0.4749 ± 0.4891 | -0.97 | [-1.4335, 0.4837] |
| `10yr_coupled` | `gov_acc_bf_vs_sq_unstressed` | 0.9653 | 0.9687 | -0.0035 ± 0.0035 | -1.00 | [-0.0103, 0.0033] |
| `10yr_coupled` | `floor_u_stressed_vs_unstressed_bf` | 75.2499 | 79.2094 | -3.9595 ± 1.7197 | -2.30 | [-7.3300, -0.5889] |
| `10yr_coupled` | `floor_h_stressed_vs_unstressed_bf` | 74.7898 | 79.9466 | -5.1568 ± 2.1325 | -2.42 | [-9.3365, -0.9771] |
| `10yr_coupled` | `median_u_stressed_vs_unstressed_bf` | 92.4739 | 94.8400 | -2.3660 ± 1.6600 | -1.43 | [-5.6196, 0.8876] |
| `10yr_coupled` | `median_h_stressed_vs_unstressed_bf` | 91.6231 | 93.6277 | -2.0045 ± 1.3122 | -1.53 | [-4.5765, 0.5674] |
| `10yr_coupled` | `worst_drop_stressed_vs_unstressed_bf` | 37.8794 | 4.7553 | +33.1241 ± 14.7664 | +2.24 | [4.1819, 62.0663] |
| `10yr_coupled` | `gov_acc_stressed_vs_unstressed_bf` | 0.9653 | 0.9653 | +0.0000 ± 0.0000 | +0.00 | [0.0000, 0.0000] |
| `10yr_coupled` | `floor_u_stressed_vs_unstressed_sq` | 61.8315 | 78.0100 | -16.1786 ± 7.2095 | -2.24 | [-30.3091, -2.0480] |
| `10yr_coupled` | `floor_h_stressed_vs_unstressed_sq` | 62.5762 | 77.3564 | -14.7801 ± 7.5012 | -1.97 | [-29.4825, -0.0778] |
| `10yr_coupled` | `median_u_stressed_vs_unstressed_sq` | 78.1853 | 91.7230 | -13.5377 ± 8.9273 | -1.52 | [-31.0352, 3.9599] |
| `10yr_coupled` | `median_h_stressed_vs_unstressed_sq` | 77.8396 | 91.1250 | -13.2854 ± 8.9898 | -1.48 | [-30.9053, 4.3346] |
| `10yr_coupled` | `worst_drop_stressed_vs_unstressed_sq` | 37.9544 | 5.2301 | +32.7243 ± 14.7052 | +2.23 | [3.9022, 61.5464] |
| `10yr_coupled` | `gov_acc_stressed_vs_unstressed_sq` | 0.9653 | 0.9687 | -0.0035 ± 0.0035 | -1.00 | [-0.0103, 0.0033] |
| `20yr_coupled_gov` | `floor_u_bf_vs_sq_stressed` | 208.7054 | 184.1804 | +24.5250 ± 20.7347 | +1.18 | [-16.1150, 65.1650] |
| `20yr_coupled_gov` | `floor_h_bf_vs_sq_stressed` | 207.8634 | 184.0715 | +23.7919 ± 20.1535 | +1.18 | [-15.7090, 63.2928] |
| `20yr_coupled_gov` | `median_u_bf_vs_sq_stressed` | 233.9421 | 207.9580 | +25.9841 ± 21.5636 | +1.20 | [-16.2805, 68.2488] |
| `20yr_coupled_gov` | `median_h_bf_vs_sq_stressed` | 231.8841 | 208.0856 | +23.7984 ± 21.7949 | +1.09 | [-18.9196, 66.5164] |
| `20yr_coupled_gov` | `worst_drop_bf_vs_sq_stressed` | 22.2068 | 22.4931 | -0.2863 ± 0.4089 | -0.70 | [-1.0878, 0.5152] |
| `20yr_coupled_gov` | `gov_acc_bf_vs_sq_stressed` | 0.9605 | 0.9562 | +0.0043 ± 0.0019 | +2.27 | [0.0006, 0.0079] |
| `20yr_coupled_gov` | `floor_u_bf_vs_sq_unstressed` | 206.2300 | 207.2544 | -1.0244 ± 2.5824 | -0.40 | [-6.0858, 4.0370] |
| `20yr_coupled_gov` | `floor_h_bf_vs_sq_unstressed` | 204.6699 | 205.8391 | -1.1692 ± 2.5272 | -0.46 | [-6.1225, 3.7841] |
| `20yr_coupled_gov` | `median_u_bf_vs_sq_unstressed` | 229.3908 | 230.6083 | -1.2175 ± 2.2538 | -0.54 | [-5.6349, 3.1999] |
| `20yr_coupled_gov` | `median_h_bf_vs_sq_unstressed` | 228.1309 | 229.7776 | -1.6467 ± 2.4609 | -0.67 | [-6.4700, 3.1766] |
| `20yr_coupled_gov` | `worst_drop_bf_vs_sq_unstressed` | 6.4145 | 6.3897 | +0.0247 ± 0.4105 | +0.06 | [-0.7799, 0.8293] |
| `20yr_coupled_gov` | `gov_acc_bf_vs_sq_unstressed` | 0.9607 | 0.9577 | +0.0030 ± 0.0023 | +1.29 | [-0.0016, 0.0076] |
| `20yr_coupled_gov` | `floor_u_stressed_vs_unstressed_bf` | 208.7054 | 206.2300 | +2.4755 ± 2.8837 | +0.86 | [-3.1765, 8.1274] |
| `20yr_coupled_gov` | `floor_h_stressed_vs_unstressed_bf` | 207.8634 | 204.6699 | +3.1935 ± 3.3265 | +0.96 | [-3.3265, 9.7135] |
| `20yr_coupled_gov` | `median_u_stressed_vs_unstressed_bf` | 233.9421 | 229.3908 | +4.5513 ± 3.2993 | +1.38 | [-1.9153, 11.0179] |
| `20yr_coupled_gov` | `median_h_stressed_vs_unstressed_bf` | 231.8841 | 228.1309 | +3.7532 ± 3.7580 | +1.00 | [-3.6125, 11.1188] |
| `20yr_coupled_gov` | `worst_drop_stressed_vs_unstressed_bf` | 22.2068 | 6.4145 | +15.7924 ± 8.9953 | +1.76 | [-1.8384, 33.4232] |
| `20yr_coupled_gov` | `gov_acc_stressed_vs_unstressed_bf` | 0.9605 | 0.9607 | -0.0003 ± 0.0019 | -0.13 | [-0.0039, 0.0034] |
| `20yr_coupled_gov` | `floor_u_stressed_vs_unstressed_sq` | 184.1804 | 207.2544 | -23.0740 ± 21.4795 | -1.07 | [-65.1738, 19.0259] |
| `20yr_coupled_gov` | `floor_h_stressed_vs_unstressed_sq` | 184.0715 | 205.8391 | -21.7676 ± 21.3254 | -1.02 | [-63.5652, 20.0301] |
| `20yr_coupled_gov` | `median_u_stressed_vs_unstressed_sq` | 207.9580 | 230.6083 | -22.6503 ± 23.3488 | -0.97 | [-68.4139, 23.1132] |
| `20yr_coupled_gov` | `median_h_stressed_vs_unstressed_sq` | 208.0856 | 229.7776 | -21.6919 ± 22.9795 | -0.94 | [-66.7317, 23.3478] |
| `20yr_coupled_gov` | `worst_drop_stressed_vs_unstressed_sq` | 22.4931 | 6.3897 | +16.1034 ± 8.9495 | +1.80 | [-1.4375, 33.6443] |
| `20yr_coupled_gov` | `gov_acc_stressed_vs_unstressed_sq` | 0.9562 | 0.9577 | -0.0015 ± 0.0024 | -0.63 | [-0.0062, 0.0032] |
| `100yr_century` | `floor_u_bf_vs_sq_stressed` | 1203.9873 | 885.2333 | +318.7540 ± 167.5133 | +1.90 | [-9.5722, 647.0802] |
| `100yr_century` | `floor_h_bf_vs_sq_stressed` | 1200.3299 | 878.0518 | +322.2781 ± 164.2141 | +1.96 | [0.4184, 644.1378] |
| `100yr_century` | `median_u_bf_vs_sq_stressed` | 1264.0584 | 934.3881 | +329.6704 ± 170.9931 | +1.93 | [-5.4761, 664.8168] |
| `100yr_century` | `median_h_bf_vs_sq_stressed` | 1261.7687 | 924.9920 | +336.7766 ± 169.0569 | +1.99 | [5.4251, 668.1282] |
| `100yr_century` | `worst_drop_bf_vs_sq_stressed` | 48.8131 | 49.5592 | -0.7460 ± 0.4236 | -1.76 | [-1.5762, 0.0841] |
| `100yr_century` | `gov_acc_bf_vs_sq_stressed` | 0.9543 | 0.9530 | +0.0013 ± 0.0022 | +0.57 | [-0.0031, 0.0056] |
| `100yr_century` | `floor_u_bf_vs_sq_unstressed` | 1219.0450 | 953.0844 | +265.9606 ± 167.7655 | +1.59 | [-62.8597, 594.7809] |
| `100yr_century` | `floor_h_bf_vs_sq_unstressed` | 1206.7225 | 948.0365 | +258.6860 ± 166.5768 | +1.55 | [-67.8045, 585.1765] |
| `100yr_century` | `median_u_bf_vs_sq_unstressed` | 1271.5212 | 998.1646 | +273.3565 ± 174.6362 | +1.57 | [-68.9304, 615.6435] |
| `100yr_century` | `median_h_bf_vs_sq_unstressed` | 1265.7807 | 995.4946 | +270.2861 ± 172.3382 | +1.57 | [-67.4968, 608.0690] |
| `100yr_century` | `worst_drop_bf_vs_sq_unstressed` | 22.0617 | 21.9014 | +0.1603 ± 0.2497 | +0.64 | [-0.3290, 0.6496] |
| `100yr_century` | `gov_acc_bf_vs_sq_unstressed` | 0.9564 | 0.9543 | +0.0021 ± 0.0018 | +1.16 | [-0.0015, 0.0057] |
| `100yr_century` | `floor_u_stressed_vs_unstressed_bf` | 1203.9873 | 1219.0450 | -15.0578 ± 4.9647 | -3.03 | [-24.7886, -5.3269] |
| `100yr_century` | `floor_h_stressed_vs_unstressed_bf` | 1200.3299 | 1206.7225 | -6.3926 ± 5.1397 | -1.24 | [-16.4664, 3.6812] |
| `100yr_century` | `median_u_stressed_vs_unstressed_bf` | 1264.0584 | 1271.5212 | -7.4627 ± 2.9644 | -2.52 | [-13.2729, -1.6526] |
| `100yr_century` | `median_h_stressed_vs_unstressed_bf` | 1261.7687 | 1265.7807 | -4.0120 ± 5.3139 | -0.76 | [-14.4273, 6.4033] |
| `100yr_century` | `worst_drop_stressed_vs_unstressed_bf` | 48.8131 | 22.0617 | +26.7514 ± 9.2284 | +2.90 | [8.6637, 44.8391] |
| `100yr_century` | `gov_acc_stressed_vs_unstressed_bf` | 0.9543 | 0.9564 | -0.0021 ± 0.0007 | -3.03 | [-0.0035, -0.0008] |
| `100yr_century` | `floor_u_stressed_vs_unstressed_sq` | 885.2333 | 953.0844 | -67.8511 ± 180.9647 | -0.37 | [-422.5419, 286.8396] |
| `100yr_century` | `floor_h_stressed_vs_unstressed_sq` | 878.0518 | 948.0365 | -69.9847 ± 180.2308 | -0.39 | [-423.2371, 283.2677] |
| `100yr_century` | `median_u_stressed_vs_unstressed_sq` | 934.3881 | 998.1646 | -63.7766 ± 184.9153 | -0.34 | [-426.2106, 298.6574] |
| `100yr_century` | `median_h_stressed_vs_unstressed_sq` | 924.9920 | 995.4946 | -70.5026 ± 185.7383 | -0.38 | [-434.5496, 293.5445] |
| `100yr_century` | `worst_drop_stressed_vs_unstressed_sq` | 49.5592 | 21.9014 | +27.6577 ± 9.0644 | +3.05 | [9.8915, 45.4240] |
| `100yr_century` | `gov_acc_stressed_vs_unstressed_sq` | 0.9530 | 0.9543 | -0.0013 ± 0.0014 | -0.94 | [-0.0039, 0.0014] |
| `open_885_better_models` | `takeover_count_decay_vs_window` | 2.3750 | 2.3750 | +0.0000 ± 0.4226 | +0.00 | [-0.8283, 0.8283] |
| `open_885_better_models` | `own_share_decay_vs_window` | 0.5926 | 0.6149 | -0.0223 ± 0.0486 | -0.46 | [-0.1175, 0.0730] |
| `open_885_better_models` | `floor_u_decay_vs_window` | 485.2325 | 425.7513 | +59.4812 ± 74.5368 | +0.80 | [-86.6109, 205.5734] |
