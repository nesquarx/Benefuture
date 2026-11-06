# Governed-threshold perturbation battery

Build: commit 0d6481c. Seeds 7:18; 300 steps; run time 9.9 minutes.
World: the economy battery's, noise at moderate severity, two deceivers at full size, AdvAp on. Each cell: mean paired difference from the default (arm − default); + / − significant at z = 2. Harm and the deceivers' advantage are better when lower. 'candidate' = some reading better and none worse: for the author, after replication on fresh seeds.

| Threshold | Setting | Floor u | Floor h | Median u | Median h | Harm peak | Deceivers' advantage | Verdict |
|---|---|---|---|---|---|---|---|---|
| `threshold` | 0.75× → 0.675 | -1.81 | 3.56 | -0.60 | 4.14 | -0.14 | -1.94 | no effect |
| `adv_min_records` | 0.4× → 2.0 | -1.81 | 0.56 | -1.73 | 0.22 | 0.36 | -0.17 | no effect |
| `adv_min_records` | 0.8× → 4.0 | -0.47 | 1.56 | -0.90 | 2.57 | 0.04 | 3.31 | no effect |
| `max_credence` | 0.99× → 0.98 | 3.40 | 0.17 | 3.35 | 3.44 | -0.11 | 5.89 | no effect |
