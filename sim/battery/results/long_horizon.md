# Long-Horizon & Century Simulation Report

- **Commit**: `cbed8ef9c36e854efb7057c36df9d699fb4c463c`
- **Consolidation**: Sharded parallel execution merged via statistical pooling
- **Significance Standard**: Pre-stated `z = 2.0` (`z = 3.0` for README/BACKPROPAGATION).

| Suite | Metric | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |
|---|---|---|---|---|---|---|
| `10yr_coupled` | `floor_u_bf_vs_sq_stressed` | 47.7835 | 61.9119 | -14.1284 ± 10.2338 | -1.38 | [-34.1867, 5.9299] |
| `10yr_coupled` | `floor_h_bf_vs_sq_stressed` | 47.6162 | 61.8965 | -14.2803 ± 10.5006 | -1.36 | [-34.8614, 6.3008] |
| `10yr_coupled` | `median_u_bf_vs_sq_stressed` | 60.8043 | 77.0703 | -16.2661 ± 11.4160 | -1.42 | [-38.6414, 6.1093] |
| `10yr_coupled` | `median_h_bf_vs_sq_stressed` | 60.1916 | 76.6109 | -16.4193 ± 11.6853 | -1.41 | [-39.3226, 6.4840] |
| `10yr_coupled` | `worst_drop_bf_vs_sq_stressed` | 10.7075 | 15.0333 | -4.3258 ± 4.4991 | -0.96 | [-13.1440, 4.4924] |
| `10yr_coupled` | `gov_acc_bf_vs_sq_stressed` | 0.9583 | 0.9687 | -0.0104 ± 0.0135 | -0.77 | [-0.0368, 0.0160] |
| `10yr_coupled` | `floor_u_bf_vs_sq_unstressed` | 48.8416 | 71.6455 | -22.8039 ± 9.0766 | -2.51 | [-40.5940, -5.0138] |
| `10yr_coupled` | `floor_h_bf_vs_sq_unstressed` | 48.3783 | 71.9697 | -23.5914 ± 8.8410 | -2.67 | [-40.9199, -6.2630] |
| `10yr_coupled` | `median_u_bf_vs_sq_unstressed` | 61.3362 | 84.8377 | -23.5015 ± 10.0988 | -2.33 | [-43.2952, -3.7079] |
| `10yr_coupled` | `median_h_bf_vs_sq_unstressed` | 60.8087 | 84.2531 | -23.4444 ± 10.0701 | -2.33 | [-43.1818, -3.7070] |
| `10yr_coupled` | `worst_drop_bf_vs_sq_unstressed` | 4.5328 | 4.6495 | -0.1167 ± 0.8952 | -0.13 | [-1.8712, 1.6378] |
| `10yr_coupled` | `gov_acc_bf_vs_sq_unstressed` | 0.9521 | 0.9653 | -0.0132 ± 0.0126 | -1.05 | [-0.0378, 0.0114] |
| `10yr_coupled` | `floor_u_stressed_vs_unstressed_bf` | 47.7835 | 48.8416 | -1.0581 ± 1.1731 | -0.90 | [-3.3573, 1.2411] |
| `10yr_coupled` | `floor_h_stressed_vs_unstressed_bf` | 47.6162 | 48.3783 | -0.7621 ± 1.2598 | -0.60 | [-3.2313, 1.7071] |
| `10yr_coupled` | `median_u_stressed_vs_unstressed_bf` | 60.8043 | 61.3362 | -0.5320 ± 1.1454 | -0.46 | [-2.7770, 1.7130] |
| `10yr_coupled` | `median_h_stressed_vs_unstressed_bf` | 60.1916 | 60.8087 | -0.6171 ± 0.9947 | -0.62 | [-2.5666, 1.3325] |
| `10yr_coupled` | `worst_drop_stressed_vs_unstressed_bf` | 10.7075 | 4.5328 | +6.1747 ± 6.1154 | +1.01 | [-5.8115, 18.1608] |
| `10yr_coupled` | `gov_acc_stressed_vs_unstressed_bf` | 0.9583 | 0.9521 | +0.0063 ± 0.0030 | +2.05 | [0.0003, 0.0122] |
| `10yr_coupled` | `floor_u_stressed_vs_unstressed_sq` | 61.9119 | 71.6455 | -9.7336 ± 8.6065 | -1.13 | [-26.6023, 7.1352] |
| `10yr_coupled` | `floor_h_stressed_vs_unstressed_sq` | 61.8965 | 71.9697 | -10.0732 ± 8.9297 | -1.13 | [-27.5754, 7.4289] |
| `10yr_coupled` | `median_u_stressed_vs_unstressed_sq` | 77.0703 | 84.8377 | -7.7674 ± 9.8563 | -0.79 | [-27.0858, 11.5510] |
| `10yr_coupled` | `median_h_stressed_vs_unstressed_sq` | 76.6109 | 84.2531 | -7.6422 ± 10.1429 | -0.75 | [-27.5223, 12.2380] |
| `10yr_coupled` | `worst_drop_stressed_vs_unstressed_sq` | 15.0333 | 4.6495 | +10.3838 ± 7.6588 | +1.36 | [-4.6275, 25.3951] |
| `10yr_coupled` | `gov_acc_stressed_vs_unstressed_sq` | 0.9687 | 0.9653 | +0.0035 ± 0.0035 | +1.00 | [-0.0033, 0.0103] |
| `20yr_coupled_gov` | `floor_u_bf_vs_sq_stressed` | 96.9737 | 170.0368 | -73.0631 ± 12.9948 | -5.62 | [-98.5330, -47.5932] |
| `20yr_coupled_gov` | `floor_h_bf_vs_sq_stressed` | 96.1648 | 171.4662 | -75.3014 ± 12.9267 | -5.83 | [-100.6377, -49.9650] |
| `20yr_coupled_gov` | `median_u_bf_vs_sq_stressed` | 114.3752 | 193.8641 | -79.4889 ± 13.7093 | -5.80 | [-106.3591, -52.6186] |
| `20yr_coupled_gov` | `median_h_bf_vs_sq_stressed` | 112.7070 | 193.4711 | -80.7641 ± 14.8222 | -5.45 | [-109.8156, -51.7127] |
| `20yr_coupled_gov` | `worst_drop_bf_vs_sq_stressed` | 11.2752 | 15.2095 | -3.9344 ± 10.5656 | -0.37 | [-24.6430, 16.7743] |
| `20yr_coupled_gov` | `gov_acc_bf_vs_sq_stressed` | 0.9608 | 0.9570 | +0.0038 ± 0.0018 | +2.11 | [0.0003, 0.0074] |
| `20yr_coupled_gov` | `floor_u_bf_vs_sq_unstressed` | 99.0629 | 190.7742 | -91.7112 ± 22.7499 | -4.03 | [-136.3010, -47.1215] |
| `20yr_coupled_gov` | `floor_h_bf_vs_sq_unstressed` | 96.0030 | 187.1167 | -91.1137 ± 21.7167 | -4.20 | [-133.6785, -48.5490] |
| `20yr_coupled_gov` | `median_u_bf_vs_sq_unstressed` | 115.5528 | 211.7531 | -96.2002 ± 25.0991 | -3.83 | [-145.3945, -47.0060] |
| `20yr_coupled_gov` | `median_h_bf_vs_sq_unstressed` | 114.7998 | 211.0419 | -96.2421 ± 24.1613 | -3.98 | [-143.5983, -48.8860] |
| `20yr_coupled_gov` | `worst_drop_bf_vs_sq_unstressed` | 4.4973 | 5.3257 | -0.8284 ± 0.7470 | -1.11 | [-2.2925, 0.6358] |
| `20yr_coupled_gov` | `gov_acc_bf_vs_sq_unstressed` | 0.9623 | 0.9577 | +0.0045 ± 0.0017 | +2.70 | [0.0012, 0.0078] |
| `20yr_coupled_gov` | `floor_u_stressed_vs_unstressed_bf` | 96.9737 | 99.0629 | -2.0892 ± 2.7894 | -0.75 | [-7.5565, 3.3780] |
| `20yr_coupled_gov` | `floor_h_stressed_vs_unstressed_bf` | 96.1648 | 96.0030 | +0.1619 ± 2.2833 | +0.07 | [-4.3135, 4.6372] |
| `20yr_coupled_gov` | `median_u_stressed_vs_unstressed_bf` | 114.3752 | 115.5528 | -1.1776 ± 2.2483 | -0.52 | [-5.5842, 3.2290] |
| `20yr_coupled_gov` | `median_h_stressed_vs_unstressed_bf` | 112.7070 | 114.7998 | -2.0928 ± 2.2518 | -0.93 | [-6.5064, 2.3208] |
| `20yr_coupled_gov` | `worst_drop_stressed_vs_unstressed_bf` | 11.2752 | 4.4973 | +6.7778 ± 6.8469 | +0.99 | [-6.6421, 20.1978] |
| `20yr_coupled_gov` | `gov_acc_stressed_vs_unstressed_bf` | 0.9608 | 0.9623 | -0.0015 ± 0.0015 | -1.00 | [-0.0043, 0.0014] |
| `20yr_coupled_gov` | `floor_u_stressed_vs_unstressed_sq` | 170.0368 | 190.7742 | -20.7374 ± 23.2535 | -0.89 | [-66.3143, 24.8396] |
| `20yr_coupled_gov` | `floor_h_stressed_vs_unstressed_sq` | 171.4662 | 187.1167 | -15.6505 ± 22.2576 | -0.70 | [-59.2754, 27.9744] |
| `20yr_coupled_gov` | `median_u_stressed_vs_unstressed_sq` | 193.8641 | 211.7531 | -17.8890 ± 25.0808 | -0.71 | [-67.0473, 31.2694] |
| `20yr_coupled_gov` | `median_h_stressed_vs_unstressed_sq` | 193.4711 | 211.0419 | -17.5708 ± 24.4765 | -0.72 | [-65.5448, 30.4033] |
| `20yr_coupled_gov` | `worst_drop_stressed_vs_unstressed_sq` | 15.2095 | 5.3257 | +9.8838 ± 6.4276 | +1.54 | [-2.7143, 22.4820] |
| `20yr_coupled_gov` | `gov_acc_stressed_vs_unstressed_sq` | 0.9570 | 0.9577 | -0.0008 ± 0.0014 | -0.53 | [-0.0035, 0.0020] |
| `100yr_century` | `floor_u_bf_vs_sq_stressed` | 521.9066 | 550.2317 | -28.3251 ± 124.1085 | -0.23 | [-271.5779, 214.9276] |
| `100yr_century` | `floor_h_bf_vs_sq_stressed` | 519.9552 | 547.3591 | -27.4040 ± 121.6565 | -0.23 | [-265.8507, 211.0428] |
| `100yr_century` | `median_u_bf_vs_sq_stressed` | 559.6600 | 590.0534 | -30.3934 ± 128.3815 | -0.24 | [-282.0212, 221.2343] |
| `100yr_century` | `median_h_bf_vs_sq_stressed` | 556.4906 | 585.8685 | -29.3779 ± 127.1030 | -0.23 | [-278.4998, 219.7439] |
| `100yr_century` | `worst_drop_bf_vs_sq_stressed` | 14.7811 | 17.2008 | -2.4197 ± 11.5533 | -0.21 | [-25.0643, 20.2248] |
| `100yr_century` | `gov_acc_bf_vs_sq_stressed` | 0.9587 | 0.9547 | +0.0040 ± 0.0021 | +1.92 | [-0.0001, 0.0080] |
| `100yr_century` | `floor_u_bf_vs_sq_unstressed` | 512.9277 | 683.5472 | -170.6195 ± 152.8331 | -1.12 | [-470.1724, 128.9334] |
| `100yr_century` | `floor_h_bf_vs_sq_unstressed` | 511.7667 | 682.7053 | -170.9386 ± 150.4721 | -1.14 | [-465.8639, 123.9867] |
| `100yr_century` | `median_u_bf_vs_sq_unstressed` | 551.8462 | 725.1084 | -173.2622 ± 157.2604 | -1.10 | [-481.4925, 134.9682] |
| `100yr_century` | `median_h_bf_vs_sq_unstressed` | 548.8603 | 720.6201 | -171.7598 ± 155.6535 | -1.10 | [-476.8408, 133.3211] |
| `100yr_century` | `worst_drop_bf_vs_sq_unstressed` | 8.5478 | 6.4054 | +2.1423 ± 3.5196 | +0.61 | [-4.7560, 9.0407] |
| `100yr_century` | `gov_acc_bf_vs_sq_unstressed` | 0.9614 | 0.9522 | +0.0092 ± 0.0031 | +2.97 | [0.0031, 0.0153] |
| `100yr_century` | `floor_u_stressed_vs_unstressed_bf` | 521.9066 | 512.9277 | +8.9789 ± 13.6796 | +0.66 | [-17.8330, 35.7909] |
| `100yr_century` | `floor_h_stressed_vs_unstressed_bf` | 519.9552 | 511.7667 | +8.1885 ± 14.3600 | +0.57 | [-19.9570, 36.3340] |
| `100yr_century` | `median_u_stressed_vs_unstressed_bf` | 559.6600 | 551.8462 | +7.8138 ± 13.5586 | +0.58 | [-18.7611, 34.3886] |
| `100yr_century` | `median_h_stressed_vs_unstressed_bf` | 556.4906 | 548.8603 | +7.6303 ± 13.1417 | +0.58 | [-18.1274, 33.3879] |
| `100yr_century` | `worst_drop_stressed_vs_unstressed_bf` | 14.7811 | 8.5478 | +6.2333 ± 9.4389 | +0.66 | [-12.2669, 24.7336] |
| `100yr_century` | `gov_acc_stressed_vs_unstressed_bf` | 0.9587 | 0.9614 | -0.0027 ± 0.0024 | -1.11 | [-0.0075, 0.0021] |
| `100yr_century` | `floor_u_stressed_vs_unstressed_sq` | 550.2317 | 683.5472 | -133.3154 ± 104.7870 | -1.27 | [-338.6979, 72.0670] |
| `100yr_century` | `floor_h_stressed_vs_unstressed_sq` | 547.3591 | 682.7053 | -135.3461 ± 105.0358 | -1.29 | [-341.2163, 70.5240] |
| `100yr_century` | `median_u_stressed_vs_unstressed_sq` | 590.0534 | 725.1084 | -135.0550 ± 108.8433 | -1.24 | [-348.3878, 78.2778] |
| `100yr_century` | `median_h_stressed_vs_unstressed_sq` | 585.8685 | 720.6201 | -134.7516 ± 107.9767 | -1.25 | [-346.3861, 76.8828] |
| `100yr_century` | `worst_drop_stressed_vs_unstressed_sq` | 17.2008 | 6.4054 | +10.7954 ± 6.7122 | +1.61 | [-2.3605, 23.9514] |
| `100yr_century` | `gov_acc_stressed_vs_unstressed_sq` | 0.9547 | 0.9522 | +0.0026 ± 0.0015 | +1.66 | [-0.0005, 0.0056] |
| `open_885_better_models` | `takeover_count_decay_vs_window` | 2.5000 | 2.5000 | +0.0000 ± 0.4226 | +0.00 | [-0.8283, 0.8283] |
| `open_885_better_models` | `own_share_decay_vs_window` | 0.6133 | 0.5993 | +0.0140 ± 0.0256 | +0.55 | [-0.0361, 0.0641] |
| `open_885_better_models` | `floor_u_decay_vs_window` | 478.5514 | 475.7954 | +2.7560 ± 11.8932 | +0.23 | [-20.5546, 26.0667] |
