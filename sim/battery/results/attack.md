# Adversarial attack search

Build: commit 7063060 (with any uncommitted changes at the time).

Attacker strategies optimised by the cross-entropy method (population 8, 4 iterations) to minimise the success pattern's margin (1: the unattacked world; below 0: a criterion failed), within a budget of 1.0 (one attack at the top of its realistic range). Search on fixed seeds; the worst strategy re-checked on held-out seeds.

## economy (M3c) (5.1 minutes)

Worst strategy: `(bloc = [6, 7, 8], deceit = 0.9239101198238746, launder = 0.8277294383045349, frivolous = 0.043648835115922505, capture = 0.0, target = 2, windows = [(92, 11), (114, 11), (136, 11)])`.

Margin on the search seeds 0.547; on held-out seeds 0.567 (per seed: 0.58, 0.54, 0.58, 0.57). Bloc's wealth relative to honest agents, over the unattacked run: -2.71. The framework holds.

Best margin by iteration: 0.692, 0.651, 0.576, 0.547.

## governance (M5) (0.8 minutes)

Worst strategy: `(colluders = [22, 14, 23, 25, 16, 21, 24, 18, 45, 49, 48, 44, 34, 46, 38, 30, 75, 72, 74, 66, 68, 57, 61, 70, 95, 91, 94, 97, 87, 98, 86, 90], domains = [1, 2, 3, 4], stealth = false, fork_copies = 1, loyalty = 2.9175826647210044)`.

Margin on the search seeds 0.208; on held-out seeds 0.210 (per seed: 0.96, 0.96, 0.96, 0.96, 0.98, 0.94). The framework holds.

Best margin by iteration: 0.232, 0.208, 0.208, 0.208.

