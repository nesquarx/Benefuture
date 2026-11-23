# Long-Horizon & Century Simulation Report

- **Commit**: `7f62a1587af84d3cb69c073a9766ed9423ba115b`
- **Consolidation**: Sharded parallel execution merged via statistical pooling
- **Significance Standard**: Pre-stated `z = 2.0` (`z = 3.0` for README/BACKPROPAGATION).

| Suite | Metric | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|---|
| `10yr_coupled` | `floor_u_bf_vs_sq_stressed` | 78.1987 | 74.4024 | +3.7963 ± 3.0422 | +1.25 | [-2.1665, 9.7590] |
| `10yr_coupled` | `floor_h_bf_vs_sq_stressed` | 76.0604 | 73.1113 | +2.9490 ± 2.3119 | +1.28 | [-1.5822, 7.4803] |
| `10yr_coupled` | `median_u_bf_vs_sq_stressed` | 93.7926 | 90.9174 | +2.8752 ± 2.2159 | +1.30 | [-1.4680, 7.2183] |
| `10yr_coupled` | `median_h_bf_vs_sq_stressed` | 93.5945 | 90.3773 | +3.2171 ± 1.9933 | +1.61 | [-0.6897, 7.1240] |
| `10yr_coupled` | `worst_drop_bf_vs_sq_stressed` | 14.9037 | 26.7075 | -11.8038 ± 11.6678 | -1.01 | [-34.6727, 11.0651] |
| `10yr_coupled` | `gov_acc_bf_vs_sq_stressed` | 0.9653 | 0.9687 | -0.0035 ± 0.0035 | -1.00 | [-0.0103, 0.0033] |
| `10yr_coupled` | `floor_u_bf_vs_sq_unstressed` | 78.2280 | 83.4278 | -5.1997 ± 2.1424 | -2.43 | [-9.3988, -1.0007] |
| `10yr_coupled` | `floor_h_bf_vs_sq_unstressed` | 76.1607 | 82.0815 | -5.9208 ± 1.2987 | -4.56 | [-8.4662, -3.3753] |
| `10yr_coupled` | `median_u_bf_vs_sq_unstressed` | 92.8492 | 98.0120 | -5.1628 ± 1.6881 | -3.06 | [-8.4715, -1.8540] |
| `10yr_coupled` | `median_h_bf_vs_sq_unstressed` | 92.1678 | 97.4438 | -5.2760 ± 1.3261 | -3.98 | [-7.8751, -2.6768] |
| `10yr_coupled` | `worst_drop_bf_vs_sq_unstressed` | 4.5209 | 4.7025 | -0.1816 ± 0.2436 | -0.75 | [-0.6591, 0.2959] |
| `10yr_coupled` | `gov_acc_bf_vs_sq_unstressed` | 0.9618 | 0.9687 | -0.0069 ± 0.0045 | -1.53 | [-0.0159, 0.0020] |
| `10yr_coupled` | `floor_u_stressed_vs_unstressed_bf` | 78.1987 | 78.2280 | -0.0293 ± 2.0366 | -0.01 | [-4.0210, 3.9623] |
| `10yr_coupled` | `floor_h_stressed_vs_unstressed_bf` | 76.0604 | 76.1607 | -0.1004 ± 2.0091 | -0.05 | [-4.0382, 3.8374] |
| `10yr_coupled` | `median_u_stressed_vs_unstressed_bf` | 93.7926 | 92.8492 | +0.9434 ± 1.5162 | +0.62 | [-2.0283, 3.9151] |
| `10yr_coupled` | `median_h_stressed_vs_unstressed_bf` | 93.5945 | 92.1678 | +1.4266 ± 0.9099 | +1.57 | [-0.3568, 3.2101] |
| `10yr_coupled` | `worst_drop_stressed_vs_unstressed_bf` | 14.9037 | 4.5209 | +10.3828 ± 7.5985 | +1.37 | [-4.5102, 25.2758] |
| `10yr_coupled` | `gov_acc_stressed_vs_unstressed_bf` | 0.9653 | 0.9618 | +0.0035 ± 0.0035 | +1.00 | [-0.0033, 0.0103] |
| `10yr_coupled` | `floor_u_stressed_vs_unstressed_sq` | 74.4024 | 83.4278 | -9.0253 ± 2.6344 | -3.43 | [-14.1888, -3.8619] |
| `10yr_coupled` | `floor_h_stressed_vs_unstressed_sq` | 73.1113 | 82.0815 | -8.9702 ± 2.6812 | -3.35 | [-14.2253, -3.7150] |
| `10yr_coupled` | `median_u_stressed_vs_unstressed_sq` | 90.9174 | 98.0120 | -7.0946 ± 1.6688 | -4.25 | [-10.3653, -3.8238] |
| `10yr_coupled` | `median_h_stressed_vs_unstressed_sq` | 90.3773 | 97.4438 | -7.0665 ± 1.3590 | -5.20 | [-9.7301, -4.4028] |
| `10yr_coupled` | `worst_drop_stressed_vs_unstressed_sq` | 26.7075 | 4.7025 | +22.0050 ± 12.6339 | +1.74 | [-2.7575, 46.7675] |
| `10yr_coupled` | `gov_acc_stressed_vs_unstressed_sq` | 0.9687 | 0.9687 | +0.0000 ± 0.0000 | +0.00 | [0.0000, 0.0000] |
| `20yr_coupled_gov` | `floor_u_bf_vs_sq_stressed` | 193.7443 | 206.6976 | -12.9533 ± 2.6243 | -4.94 | [-18.0969, -7.8098] |
| `20yr_coupled_gov` | `floor_h_bf_vs_sq_stressed` | 191.9231 | 208.0291 | -16.1060 ± 2.6420 | -6.10 | [-21.2843, -10.9278] |
| `20yr_coupled_gov` | `median_u_bf_vs_sq_stressed` | 217.3748 | 230.3171 | -12.9423 ± 2.2526 | -5.75 | [-17.3573, -8.5273] |
| `20yr_coupled_gov` | `median_h_bf_vs_sq_stressed` | 214.7981 | 231.0886 | -16.2904 ± 2.8520 | -5.71 | [-21.8804, -10.7004] |
| `20yr_coupled_gov` | `worst_drop_bf_vs_sq_stressed` | 19.0829 | 13.0313 | +6.0515 ± 5.8216 | +1.04 | [-5.3588, 17.4619] |
| `20yr_coupled_gov` | `gov_acc_bf_vs_sq_stressed` | 0.9577 | 0.9567 | +0.0010 ± 0.0029 | +0.34 | [-0.0047, 0.0067] |
| `20yr_coupled_gov` | `floor_u_bf_vs_sq_unstressed` | 196.3026 | 211.2843 | -14.9816 ± 2.1306 | -7.03 | [-19.1576, -10.8057] |
| `20yr_coupled_gov` | `floor_h_bf_vs_sq_unstressed` | 196.2232 | 211.9186 | -15.6954 ± 2.1282 | -7.37 | [-19.8667, -11.5241] |
| `20yr_coupled_gov` | `median_u_bf_vs_sq_unstressed` | 219.1823 | 236.7143 | -17.5319 ± 2.2735 | -7.71 | [-21.9880, -13.0758] |
| `20yr_coupled_gov` | `median_h_bf_vs_sq_unstressed` | 219.3613 | 236.5406 | -17.1794 ± 2.3310 | -7.37 | [-21.7482, -12.6105] |
| `20yr_coupled_gov` | `worst_drop_bf_vs_sq_unstressed` | 5.5007 | 5.0422 | +0.4585 ± 0.4121 | +1.11 | [-0.3492, 1.2663] |
| `20yr_coupled_gov` | `gov_acc_bf_vs_sq_unstressed` | 0.9587 | 0.9577 | +0.0010 ± 0.0037 | +0.27 | [-0.0063, 0.0083] |
| `20yr_coupled_gov` | `floor_u_stressed_vs_unstressed_bf` | 193.7443 | 196.3026 | -2.5584 ± 2.9039 | -0.88 | [-8.2499, 3.1332] |
| `20yr_coupled_gov` | `floor_h_stressed_vs_unstressed_bf` | 191.9231 | 196.2232 | -4.3001 ± 2.3082 | -1.86 | [-8.8242, 0.2239] |
| `20yr_coupled_gov` | `median_u_stressed_vs_unstressed_bf` | 217.3748 | 219.1823 | -1.8075 ± 2.4705 | -0.73 | [-6.6497, 3.0347] |
| `20yr_coupled_gov` | `median_h_stressed_vs_unstressed_bf` | 214.7981 | 219.3613 | -4.5631 ± 2.0230 | -2.26 | [-8.5282, -0.5980] |
| `20yr_coupled_gov` | `worst_drop_stressed_vs_unstressed_bf` | 19.0829 | 5.5007 | +13.5821 ± 7.2145 | +1.88 | [-0.5584, 27.7226] |
| `20yr_coupled_gov` | `gov_acc_stressed_vs_unstressed_bf` | 0.9577 | 0.9587 | -0.0010 ± 0.0015 | -0.68 | [-0.0039, 0.0019] |
| `20yr_coupled_gov` | `floor_u_stressed_vs_unstressed_sq` | 206.6976 | 211.2843 | -4.5867 ± 3.1480 | -1.46 | [-10.7567, 1.5834] |
| `20yr_coupled_gov` | `floor_h_stressed_vs_unstressed_sq` | 208.0291 | 211.9186 | -3.8895 ± 2.7780 | -1.40 | [-9.3344, 1.5554] |
| `20yr_coupled_gov` | `median_u_stressed_vs_unstressed_sq` | 230.3171 | 236.7143 | -6.3971 ± 2.4027 | -2.66 | [-11.1065, -1.6878] |
| `20yr_coupled_gov` | `median_h_stressed_vs_unstressed_sq` | 231.0886 | 236.5406 | -5.4521 ± 1.8239 | -2.99 | [-9.0269, -1.8773] |
| `20yr_coupled_gov` | `worst_drop_stressed_vs_unstressed_sq` | 13.0313 | 5.0422 | +7.9891 ± 5.4146 | +1.48 | [-2.6235, 18.6017] |
| `20yr_coupled_gov` | `gov_acc_stressed_vs_unstressed_sq` | 0.9567 | 0.9577 | -0.0010 ± 0.0007 | -1.53 | [-0.0023, 0.0003] |
| `100yr_century` | `floor_u_bf_vs_sq_stressed` | 1020.0821 | 483.3465 | +536.7357 ± 166.5330 | +3.22 | [210.3309, 863.1404] |
| `100yr_century` | `floor_h_bf_vs_sq_stressed` | 1009.7264 | 476.7362 | +532.9902 ± 165.4857 | +3.22 | [208.6383, 857.3421] |
| `100yr_century` | `median_u_bf_vs_sq_stressed` | 1072.7391 | 511.4098 | +561.3292 ± 172.9437 | +3.25 | [222.3595, 900.2989] |
| `100yr_century` | `median_h_bf_vs_sq_stressed` | 1067.9756 | 510.5982 | +557.3774 ± 171.0528 | +3.26 | [222.1140, 892.6408] |
| `100yr_century` | `worst_drop_bf_vs_sq_stressed` | 19.1570 | 20.1442 | -0.9873 ± 3.8989 | -0.25 | [-8.6292, 6.6546] |
| `100yr_century` | `gov_acc_bf_vs_sq_stressed` | 0.9554 | 0.9564 | -0.0011 ± 0.0020 | -0.54 | [-0.0049, 0.0028] |
| `100yr_century` | `floor_u_bf_vs_sq_unstressed` | 1040.5633 | 352.0821 | +688.4812 ± 141.9188 | +4.85 | [410.3204, 966.6421] |
| `100yr_century` | `floor_h_bf_vs_sq_unstressed` | 1034.7867 | 346.5485 | +688.2382 ± 138.7792 | +4.96 | [416.2308, 960.2455] |
| `100yr_century` | `median_u_bf_vs_sq_unstressed` | 1089.9529 | 377.6822 | +712.2708 ± 147.8822 | +4.82 | [422.4217, 1002.1198] |
| `100yr_century` | `median_h_bf_vs_sq_unstressed` | 1086.4511 | 374.0034 | +712.4477 ± 144.2164 | +4.94 | [429.7835, 995.1119] |
| `100yr_century` | `worst_drop_bf_vs_sq_unstressed` | 7.0585 | 5.9253 | +1.1331 ± 0.6166 | +1.84 | [-0.0753, 2.3416] |
| `100yr_century` | `gov_acc_bf_vs_sq_unstressed` | 0.9551 | 0.9543 | +0.0009 ± 0.0014 | +0.61 | [-0.0019, 0.0036] |
| `100yr_century` | `floor_u_stressed_vs_unstressed_bf` | 1020.0821 | 1040.5633 | -20.4812 ± 24.8474 | -0.82 | [-69.1821, 28.2198] |
| `100yr_century` | `floor_h_stressed_vs_unstressed_bf` | 1009.7264 | 1034.7867 | -25.0603 ± 19.8784 | -1.26 | [-64.0220, 13.9014] |
| `100yr_century` | `median_u_stressed_vs_unstressed_bf` | 1072.7391 | 1089.9529 | -17.2139 ± 22.5571 | -0.76 | [-61.4258, 26.9980] |
| `100yr_century` | `median_h_stressed_vs_unstressed_bf` | 1067.9756 | 1086.4511 | -18.4755 ± 22.3483 | -0.83 | [-62.2781, 25.3270] |
| `100yr_century` | `worst_drop_stressed_vs_unstressed_bf` | 19.1570 | 7.0585 | +12.0985 ± 6.8356 | +1.77 | [-1.2993, 25.4963] |
| `100yr_century` | `gov_acc_stressed_vs_unstressed_bf` | 0.9554 | 0.9551 | +0.0002 ± 0.0019 | +0.11 | [-0.0034, 0.0039] |
| `100yr_century` | `floor_u_stressed_vs_unstressed_sq` | 483.3465 | 352.0821 | +131.2644 ± 127.1180 | +1.03 | [-117.8868, 380.4156] |
| `100yr_century` | `floor_h_stressed_vs_unstressed_sq` | 476.7362 | 346.5485 | +130.1877 ± 125.5918 | +1.04 | [-115.9722, 376.3475] |
| `100yr_century` | `median_u_stressed_vs_unstressed_sq` | 511.4098 | 377.6822 | +133.7277 ± 129.9717 | +1.03 | [-121.0169, 388.4722] |
| `100yr_century` | `median_h_stressed_vs_unstressed_sq` | 510.5982 | 374.0034 | +136.5948 ± 130.0351 | +1.05 | [-118.2741, 391.4636] |
| `100yr_century` | `worst_drop_stressed_vs_unstressed_sq` | 20.1442 | 5.9253 | +14.2189 ± 7.0521 | +2.02 | [0.3967, 28.0411] |
| `100yr_century` | `gov_acc_stressed_vs_unstressed_sq` | 0.9564 | 0.9543 | +0.0021 ± 0.0017 | +1.26 | [-0.0012, 0.0054] |
| `open_885_better_models` | `takeover_count_decay_vs_window` | 1.8750 | 2.7500 | -0.8750 ± 0.5154 | -1.70 | [-1.8852, 0.1352] |
| `open_885_better_models` | `own_share_decay_vs_window` | 0.6189 | 0.5765 | +0.0424 ± 0.0407 | +1.04 | [-0.0373, 0.1221] |
| `open_885_better_models` | `floor_u_decay_vs_window` | 477.8494 | 472.0652 | +5.7842 ± 10.6846 | +0.54 | [-15.1576, 26.7260] |
