# Adversarial attack search

Build: commit 4ef9182 (with any uncommitted changes at the time).

Attacker strategies optimised by the cross-entropy method (population 8, 4 iterations) to minimise the success pattern's margin (1: the unattacked world; below 0: a criterion failed), within a budget of 1.0 (one attack at the top of its realistic range). Search on fixed seeds; the worst strategy re-checked on held-out seeds.

## economy (M3c) (4.2 minutes)

Worst strategy: `(bloc = [5, 6, 7, 8], deceit = 1.048251435330191, launder = 0.44581239499836195, frivolous = 0.030061887335869737, capture = 0.0, target = 4, windows = [(88, 53), (194, 53)])`.

Margin on the search seeds 0.337; on held-out seeds 0.357 (per seed: 0.37, 0.42, 0.30, 0.34). Bloc's wealth relative to honest agents, over the unattacked run: -0.11. The framework holds.

Best margin by iteration: 0.348, 0.348, 0.344, 0.337.

## governance (M5) (0.4 minutes)

Worst strategy: `(colluders = [23, 16, 21, 11, 14, 6, 18, 15, 48, 41, 37, 39, 46, 38, 34, 49, 73, 64, 75, 69, 70, 58, 68, 74, 99, 100, 92, 97, 87, 96, 89, 98], domains = [1, 2, 3, 4], stealth = false, fork_copies = 1, loyalty = 3.0870136824330596)`.

Margin on the search seeds 0.197; on held-out seeds 0.194 (per seed: 0.96, 0.93, 0.96, 0.94, 0.94, 0.94). The framework holds.

Best margin by iteration: 0.233, 0.197, 0.197, 0.197.

