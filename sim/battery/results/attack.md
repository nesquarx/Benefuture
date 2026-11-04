# Adversarial attack search

Build: commit 102474a (with any uncommitted changes at the time).

Attacker strategies optimised by the cross-entropy method (population 8, 4 iterations) to minimise the success pattern's margin (1: the unattacked world; below 0: a criterion failed), within a budget of 1.0 (one attack at the top of its realistic range). Search on fixed seeds; the worst strategy re-checked on held-out seeds.

## economy (M3c) (15.2 minutes)

Worst strategy: `(bloc = [5, 6, 7, 8], deceit = 0.0, launder = 0.8956406845106938, frivolous = 0.01912315926190236, capture = 0.42707615946401567, target = 3, windows = [(79, 11), (101, 11), (123, 11)])`.

Margin on the search seeds 0.362; on held-out seeds 0.382 (per seed: 0.35, 0.37, 0.38, 0.43). Bloc's wealth relative to honest agents, over the unattacked run: -2.70. The framework holds.

Best margin by iteration: 0.678, 0.649, 0.562, 0.362.

## governance (M5) (0.3 minutes)

Worst strategy: `(colluders = [21, 20, 16, 11, 10, 24, 25, 48, 50, 45, 40, 44, 37, 34, 75, 74, 70, 69, 63, 61, 64, 98, 94, 92, 95, 88, 85, 93], domains = [1, 2, 3, 4], stealth = false, fork_copies = 1, loyalty = 4.58354519356704)`.

Margin on the search seeds 0.205; on held-out seeds 0.202 (per seed: 0.95, 0.95, 0.94, 0.97, 0.96, 0.94). The framework holds.

Best margin by iteration: 0.228, 0.205, 0.205, 0.205.

