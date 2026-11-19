# Long-Horizon & Century Simulation Report

- **Commit**: `0ece8ff5b0d35dc5c409b71c347ef756a4f30020`
- **Consolidation**: Sharded parallel execution merged via statistical pooling
- **Significance Standard**: Pre-stated `z = 2.0` (`z = 3.0` for README/BACKPROPAGATION).

| Suite | Metric | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|---|
| `10yr_coupled` | `floor_u_bf_vs_sq_stressed` | 76.7634 | 70.0699 | +6.6935 ± 6.2537 | +1.07 | [-5.5637, 18.9507] |
| `10yr_coupled` | `floor_h_bf_vs_sq_stressed` | 76.2179 | 69.2505 | +6.9674 ± 5.4306 | +1.28 | [-3.6765, 17.6114] |
| `10yr_coupled` | `median_u_bf_vs_sq_stressed` | 95.2245 | 85.4003 | +9.8242 ± 6.3917 | +1.54 | [-2.7035, 22.3518] |
| `10yr_coupled` | `median_h_bf_vs_sq_stressed` | 94.1762 | 84.2524 | +9.9238 ± 5.7491 | +1.73 | [-1.3443, 21.1920] |
| `10yr_coupled` | `worst_drop_bf_vs_sq_stressed` | 26.4190 | 27.0559 | -0.6369 ± 0.4384 | -1.45 | [-1.4961, 0.2224] |
| `10yr_coupled` | `gov_acc_bf_vs_sq_stressed` | 0.9653 | 0.9687 | -0.0035 ± 0.0035 | -1.00 | [-0.0103, 0.0033] |
| `10yr_coupled` | `floor_u_bf_vs_sq_unstressed` | 79.5173 | 74.9909 | +4.5265 ± 6.9639 | +0.65 | [-9.1228, 18.1757] |
| `10yr_coupled` | `floor_h_bf_vs_sq_unstressed` | 78.6084 | 74.7276 | +3.8809 ± 6.7291 | +0.58 | [-9.3081, 17.0698] |
| `10yr_coupled` | `median_u_bf_vs_sq_unstressed` | 94.9054 | 90.3123 | +4.5932 ± 8.2184 | +0.56 | [-11.5148, 20.7011] |
| `10yr_coupled` | `median_h_bf_vs_sq_unstressed` | 93.8013 | 90.3728 | +3.4285 ± 7.7111 | +0.44 | [-11.6852, 18.5423] |
| `10yr_coupled` | `worst_drop_bf_vs_sq_unstressed` | 4.2853 | 4.8927 | -0.6074 ± 0.2676 | -2.27 | [-1.1319, -0.0829] |
| `10yr_coupled` | `gov_acc_bf_vs_sq_unstressed` | 0.9618 | 0.9583 | +0.0035 ± 0.0082 | +0.42 | [-0.0126, 0.0195] |
| `10yr_coupled` | `floor_u_stressed_vs_unstressed_bf` | 76.7634 | 79.5173 | -2.7540 ± 3.8109 | -0.72 | [-10.2233, 4.7153] |
| `10yr_coupled` | `floor_h_stressed_vs_unstressed_bf` | 76.2179 | 78.6084 | -2.3905 ± 4.2984 | -0.56 | [-10.8154, 6.0343] |
| `10yr_coupled` | `median_u_stressed_vs_unstressed_bf` | 95.2245 | 94.9054 | +0.3190 ± 2.8488 | +0.11 | [-5.2646, 5.9026] |
| `10yr_coupled` | `median_h_stressed_vs_unstressed_bf` | 94.1762 | 93.8013 | +0.3748 ± 3.2058 | +0.12 | [-5.9085, 6.6581] |
| `10yr_coupled` | `worst_drop_stressed_vs_unstressed_bf` | 26.4190 | 4.2853 | +22.1337 ± 12.6327 | +1.75 | [-2.6263, 46.8937] |
| `10yr_coupled` | `gov_acc_stressed_vs_unstressed_bf` | 0.9653 | 0.9618 | +0.0035 ± 0.0035 | +1.00 | [-0.0033, 0.0103] |
| `10yr_coupled` | `floor_u_stressed_vs_unstressed_sq` | 70.0699 | 74.9909 | -4.9210 ± 8.4935 | -0.58 | [-21.5683, 11.7262] |
| `10yr_coupled` | `floor_h_stressed_vs_unstressed_sq` | 69.2505 | 74.7276 | -5.4771 ± 8.4033 | -0.65 | [-21.9476, 10.9934] |
| `10yr_coupled` | `median_u_stressed_vs_unstressed_sq` | 85.4003 | 90.3123 | -4.9120 ± 9.6088 | -0.51 | [-23.7452, 13.9212] |
| `10yr_coupled` | `median_h_stressed_vs_unstressed_sq` | 84.2524 | 90.3728 | -6.1204 ± 9.5920 | -0.64 | [-24.9208, 12.6800] |
| `10yr_coupled` | `worst_drop_stressed_vs_unstressed_sq` | 27.0559 | 4.8927 | +22.1632 ± 13.0147 | +1.70 | [-3.3456, 47.6720] |
| `10yr_coupled` | `gov_acc_stressed_vs_unstressed_sq` | 0.9687 | 0.9583 | +0.0104 ± 0.0104 | +1.00 | [-0.0100, 0.0308] |
| `20yr_coupled_gov` | `floor_u_bf_vs_sq_stressed` | 193.1794 | 178.3354 | +14.8441 ± 26.5674 | +0.56 | [-37.2281, 66.9162] |
| `20yr_coupled_gov` | `floor_h_bf_vs_sq_stressed` | 193.8904 | 177.0671 | +16.8233 ± 24.7757 | +0.68 | [-31.7370, 65.3836] |
| `20yr_coupled_gov` | `median_u_bf_vs_sq_stressed` | 217.5886 | 199.3667 | +18.2219 ± 27.7877 | +0.66 | [-36.2419, 72.6858] |
| `20yr_coupled_gov` | `median_h_bf_vs_sq_stressed` | 217.1470 | 199.9281 | +17.2189 ± 27.6741 | +0.62 | [-37.0223, 71.4601] |
| `20yr_coupled_gov` | `worst_drop_bf_vs_sq_stressed` | 12.7023 | 13.2003 | -0.4979 ± 0.6314 | -0.79 | [-1.7354, 0.7396] |
| `20yr_coupled_gov` | `gov_acc_bf_vs_sq_stressed` | 0.9600 | 0.9557 | +0.0043 ± 0.0018 | +2.37 | [0.0007, 0.0078] |
| `20yr_coupled_gov` | `floor_u_bf_vs_sq_unstressed` | 197.2464 | 195.7838 | +1.4626 ± 16.3318 | +0.09 | [-30.5477, 33.4729] |
| `20yr_coupled_gov` | `floor_h_bf_vs_sq_unstressed` | 197.0418 | 192.4145 | +4.6273 ± 16.3241 | +0.28 | [-27.3679, 36.6225] |
| `20yr_coupled_gov` | `median_u_bf_vs_sq_unstressed` | 220.1037 | 218.6480 | +1.4557 ± 17.6412 | +0.08 | [-33.1210, 36.0325] |
| `20yr_coupled_gov` | `median_h_bf_vs_sq_unstressed` | 218.9066 | 215.2517 | +3.6548 ± 17.8129 | +0.21 | [-31.2584, 38.5681] |
| `20yr_coupled_gov` | `worst_drop_bf_vs_sq_unstressed` | 4.8550 | 4.9709 | -0.1159 ± 0.1889 | -0.61 | [-0.4861, 0.2543] |
| `20yr_coupled_gov` | `gov_acc_bf_vs_sq_unstressed` | 0.9597 | 0.9572 | +0.0025 ± 0.0022 | +1.12 | [-0.0019, 0.0069] |
| `20yr_coupled_gov` | `floor_u_stressed_vs_unstressed_bf` | 193.1794 | 197.2464 | -4.0670 ± 1.8597 | -2.19 | [-7.7119, -0.4220] |
| `20yr_coupled_gov` | `floor_h_stressed_vs_unstressed_bf` | 193.8904 | 197.0418 | -3.1515 ± 4.1908 | -0.75 | [-11.3654, 5.0625] |
| `20yr_coupled_gov` | `median_u_stressed_vs_unstressed_bf` | 217.5886 | 220.1037 | -2.5151 ± 3.2090 | -0.78 | [-8.8048, 3.7746] |
| `20yr_coupled_gov` | `median_h_stressed_vs_unstressed_bf` | 217.1470 | 218.9066 | -1.7595 ± 4.0883 | -0.43 | [-9.7725, 6.2535] |
| `20yr_coupled_gov` | `worst_drop_stressed_vs_unstressed_bf` | 12.7023 | 4.8550 | +7.8473 ± 5.2482 | +1.50 | [-2.4393, 18.1339] |
| `20yr_coupled_gov` | `gov_acc_stressed_vs_unstressed_bf` | 0.9600 | 0.9597 | +0.0003 ± 0.0014 | +0.17 | [-0.0026, 0.0031] |
| `20yr_coupled_gov` | `floor_u_stressed_vs_unstressed_sq` | 178.3354 | 195.7838 | -17.4484 ± 23.2833 | -0.75 | [-63.0838, 28.1869] |
| `20yr_coupled_gov` | `floor_h_stressed_vs_unstressed_sq` | 177.0671 | 192.4145 | -15.3475 ± 21.9909 | -0.70 | [-58.4496, 27.7547] |
| `20yr_coupled_gov` | `median_u_stressed_vs_unstressed_sq` | 199.3667 | 218.6480 | -19.2813 ± 24.4980 | -0.79 | [-67.2973, 28.7348] |
| `20yr_coupled_gov` | `median_h_stressed_vs_unstressed_sq` | 199.9281 | 215.2517 | -15.3236 ± 24.0284 | -0.64 | [-62.4193, 31.7721] |
| `20yr_coupled_gov` | `worst_drop_stressed_vs_unstressed_sq` | 13.2003 | 4.9709 | +8.2293 ± 5.4843 | +1.50 | [-2.5199, 18.9785] |
| `20yr_coupled_gov` | `gov_acc_stressed_vs_unstressed_sq` | 0.9557 | 0.9572 | -0.0015 ± 0.0011 | -1.43 | [-0.0036, 0.0006] |
| `100yr_century` | `floor_u_bf_vs_sq_stressed` | 1060.0882 | 668.8835 | +391.2047 ± 163.4997 | +2.39 | [70.7452, 711.6642] |
| `100yr_century` | `floor_h_bf_vs_sq_stressed` | 1055.0668 | 664.9820 | +390.0847 ± 162.4058 | +2.40 | [71.7693, 708.4002] |
| `100yr_century` | `median_u_bf_vs_sq_stressed` | 1117.8073 | 711.0103 | +406.7970 ± 170.0647 | +2.39 | [73.4701, 740.1239] |
| `100yr_century` | `median_h_bf_vs_sq_stressed` | 1109.6995 | 707.9710 | +401.7285 ± 169.6224 | +2.37 | [69.2686, 734.1884] |
| `100yr_century` | `worst_drop_bf_vs_sq_stressed` | 26.0225 | 23.3973 | +2.6252 ± 5.6593 | +0.46 | [-8.4669, 13.7174] |
| `100yr_century` | `gov_acc_bf_vs_sq_stressed` | 0.9541 | 0.9534 | +0.0006 ± 0.0016 | +0.40 | [-0.0025, 0.0038] |
| `100yr_century` | `floor_u_bf_vs_sq_unstressed` | 1055.7007 | 591.5110 | +464.1897 ± 158.3773 | +2.93 | [153.7702, 774.6093] |
| `100yr_century` | `floor_h_bf_vs_sq_unstressed` | 1048.7394 | 593.3985 | +455.3409 ± 156.6505 | +2.91 | [148.3059, 762.3759] |
| `100yr_century` | `median_u_bf_vs_sq_unstressed` | 1112.7432 | 634.1863 | +478.5568 ± 167.4904 | +2.86 | [150.2756, 806.8381] |
| `100yr_century` | `median_h_bf_vs_sq_unstressed` | 1107.1403 | 633.0410 | +474.0993 ± 165.3852 | +2.87 | [149.9443, 798.2543] |
| `100yr_century` | `worst_drop_bf_vs_sq_unstressed` | 6.9839 | 6.3070 | +0.6770 ± 0.7592 | +0.89 | [-0.8111, 2.1650] |
| `100yr_century` | `gov_acc_bf_vs_sq_unstressed` | 0.9560 | 0.9547 | +0.0013 ± 0.0011 | +1.16 | [-0.0009, 0.0034] |
| `100yr_century` | `floor_u_stressed_vs_unstressed_bf` | 1060.0882 | 1055.7007 | +4.3874 ± 13.3615 | +0.33 | [-21.8011, 30.5759] |
| `100yr_century` | `floor_h_stressed_vs_unstressed_bf` | 1055.0668 | 1048.7394 | +6.3273 ± 13.3507 | +0.47 | [-19.8401, 32.4947] |
| `100yr_century` | `median_u_stressed_vs_unstressed_bf` | 1117.8073 | 1112.7432 | +5.0641 ± 15.1321 | +0.33 | [-24.5948, 34.7230] |
| `100yr_century` | `median_h_stressed_vs_unstressed_bf` | 1109.6995 | 1107.1403 | +2.5592 ± 13.2691 | +0.19 | [-23.4482, 28.5667] |
| `100yr_century` | `worst_drop_stressed_vs_unstressed_bf` | 26.0225 | 6.9839 | +19.0386 ± 7.4916 | +2.54 | [4.3551, 33.7221] |
| `100yr_century` | `gov_acc_stressed_vs_unstressed_bf` | 0.9541 | 0.9560 | -0.0019 ± 0.0019 | -1.00 | [-0.0057, 0.0018] |
| `100yr_century` | `floor_u_stressed_vs_unstressed_sq` | 668.8835 | 591.5110 | +77.3725 ± 138.0249 | +0.56 | [-193.1563, 347.9012] |
| `100yr_century` | `floor_h_stressed_vs_unstressed_sq` | 664.9820 | 593.3985 | +71.5835 ± 137.6265 | +0.52 | [-198.1645, 341.3315] |
| `100yr_century` | `median_u_stressed_vs_unstressed_sq` | 711.0103 | 634.1863 | +76.8240 ± 142.8252 | +0.54 | [-203.1134, 356.7613] |
| `100yr_century` | `median_h_stressed_vs_unstressed_sq` | 707.9710 | 633.0410 | +74.9301 ± 142.0058 | +0.53 | [-203.4013, 353.2614] |
| `100yr_century` | `worst_drop_stressed_vs_unstressed_sq` | 23.3973 | 6.3070 | +17.0903 ± 8.2808 | +2.06 | [0.8600, 33.3206] |
| `100yr_century` | `gov_acc_stressed_vs_unstressed_sq` | 0.9534 | 0.9547 | -0.0013 ± 0.0017 | -0.75 | [-0.0046, 0.0020] |
| `open_885_better_models` | `takeover_count_decay_vs_window` | 2.7500 | 3.1250 | -0.3750 ± 0.3239 | -1.16 | [-1.0098, 0.2598] |
| `open_885_better_models` | `own_share_decay_vs_window` | 0.6157 | 0.6221 | -0.0064 ± 0.0287 | -0.22 | [-0.0627, 0.0499] |
| `open_885_better_models` | `floor_u_decay_vs_window` | 465.3224 | 369.1821 | +96.1403 ± 59.7971 | +1.61 | [-21.0620, 213.3425] |
