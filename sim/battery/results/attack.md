# Adversarial attack search

Build: commit unknown (with any uncommitted changes at the time).

Attacker strategies optimised by the cross-entropy method (population 8, 4 iterations) to minimise the success pattern's margin (1: the unattacked world; below 0: a criterion failed), within a budget of 1.0 (one attack at the top of its realistic range). Search on fixed seeds; the worst strategy re-checked on held-out seeds.

## economy (M3c) (0.7 minutes)

Worst strategy: `(bloc = [6, 7, 8], deceit = 0.49143429226967583, launder = 0.9408098502532685, frivolous = 0.0, capture = 1.339111857260344, target = 3, windows = [(90, 12), (114, 12), (138, 12)])`.

Margin on the search seeds 0.501; on held-out seeds 0.525 (per seed: 0.51, 0.57, 0.52, 0.51). Bloc's wealth relative to honest agents, over the unattacked run: -3.37. The framework holds.

Best margin by iteration: 0.708, 0.626, 0.528, 0.501.

## governance (M5) (0.1 minutes)

Worst strategy: `(colluders = [25, 21, 3, 15, 17, 22, 20, 43, 45, 38, 40, 39, 46, 42, 66, 73, 63, 71, 74, 69, 55, 99, 98, 89, 100, 95, 96, 97], domains = [1, 2, 3, 4], stealth = false, fork_copies = 1, loyalty = 4.58354519356704)`.

Margin on the search seeds 0.205; on held-out seeds 0.200 (per seed: 0.96, 0.93, 0.95, 0.97, 0.94, 0.95). The framework holds.

Best margin by iteration: 0.223, 0.205, 0.205, 0.205.

