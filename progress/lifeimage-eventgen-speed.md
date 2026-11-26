# lifeimage-eventgen-speed (restore probe contract, test tiers, profile eventgen)

Status: IN PROGRESS

## Goal and acceptance checks
1 profile probe and slowest eventgen tests; fix genuine inefficiencies with outputs unchanged (test: probe rows and head verdicts identical before/after on fixed seeds);
2 `python3 -m lifeimage.eventgen.probe` default <= 10 s on a small world covering every mechanism once; `--full` = larger world, both heads;
3 pytest marker `full` for heavy eventgen tests, excluded by default (addopts), `-m full` or BF_TIER=full runs them; documented; no assertion lost; every mechanism keeps a fast probe test;
4 finish increment 3: fast tier and full tier green end to end; progress/lifeimage-eventgen3.md DONE with prediction (c) failed.

## Predictions (recorded before measuring; confidence 0.6)
- default suite (fast tier) <= 7 min; probe default <= 10 s; full tier green.
- Full probe (--full) target (new, before measuring): <= 90 s after fixes (was 69 s alone; target is the new prediction, not a relaxed old one).

## Baseline (lead, measured)
full suite 20 min 32 s, 1 failed (probe under a minute: 69 s alone).

## Decisions / Done / In progress / Next
(see below, updated per milestone)

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q --durations=30 tests/test_eventgen_*.py
