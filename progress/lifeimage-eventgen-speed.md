# lifeimage-eventgen-speed (restore probe contract, test tiers, profile eventgen)

Status: DONE

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

## Hotspots (cProfile of the old probe, 168 s profiled / 69 s real)
- `load_table` 73 calls = 49 s profiled: every World/head seed re-parsed the JSONL and re-validated every Param (245k validations, each also validating its relational snippet).
- `make_row`: 18k rows each through the full jsonschema Draft 2020-12 check (21 s profiled).
- remainder is genuine generation (diary draws, person_events); left alone (RNG order must not change).

## Decisions
- Params parsed once per file state (path, mtime, size) and validated once per Param object (`calibration._VALIDATED`); frozen, so same verdicts. misspecify copies still validate changed Params.
- `events.make_row`: full contract validation once per (key, region) on the fixed part; per row only entity, time and span are checked with the schema's own rules (falls back to the full check on any violation). Same verdicts, same rows.
- Probe: SMALL (default) and FULL config dicts in probe.py; per-statistic detail printed only in --full.
- Tiers: marker `full` in pyproject (`addopts = -m 'not full'`); conftest `pytest_configure` lifts it for BF_TIER=full.
- Golden fingerprint (`tests/_eventgen_fingerprint.py`, `tests/data_eventgen_golden.json`, taken on the old code) and `tests/test_eventgen_speed.py` prove rows, relational events, statistics, degraded entries, rate/domain/sequence head verdicts unchanged.

## Done
- Fixes: Params parsed once per file state and validated once per Param; make_row validates the fixed part once per (key, region); tests' rate-head worlds built with domains=False (family statistics are identical with or without the domain machines: own streams). Golden fingerprint unchanged.
- Probe: default (small) about 6-7 s; `--full` about 35 s (was 69 s single size).
- Tiers: marker `full`, default `-m 'not full'`, BF_TIER=full lifts it. Moved to full (no assertion changed): sequence: births_ignoring_marriage_are_flagged_softly, shuffled_order_passes_the_rate_head, early_marriage_tail_removes_the_india_miss, true_generator_has_zero_hard_violations_on_every_seed; breadth: births_outside_marriage_match_the_source, india_married_by_18, single_normal_marriage_age, births_ignoring_marriage_fail_the_sourced_target, days_at_work_on_people_without_a_job, true_generator_has_zero_hard_violations_in_every_seed; plus the full probe test (own prediction <= 90 s, measured 35 s). Added fast: default probe test (< 10 s), marriage-mixture analytic probe, golden fingerprint test.
- Eventgen suite alone: 13:52 -> about 5 min of fast tests (rate-head tests 10x faster).

## Measurements (shared machine: another agent's pytest ran concurrently in part)
- before: full suite 20:32 (1 failed: probe 69 s).
- after: fast tier 1372 passed, 11 deselected, 1 xfailed in 8:21 (user 8:14); full tier (-m full) 11 passed in 5:31. Fast + full = about 13:50 vs 20:32.

## Prediction verdicts
- fast tier <= 7 min: MISSED (8:21; remaining time is non-eventgen: test_characterise 65 s, seriation setup 35 s, tiles ~70 s).
- probe default <= 10 s: MET (6-7 s). full tier green: MET (11 passed). Full probe <= 90 s: MET (35 s).
- Increment-3 prediction (c) full probe < 60 s: FAILED as stated (69 s alone); recorded in progress/lifeimage-eventgen3.md.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q ; python3 -m pytest -q -m full
