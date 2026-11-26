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
- caches + make_row + golden test (identical fingerprint); probe default about 5-7 s (noisy machine), full about 37 s (was 69 s); tier plumbing.

## In progress
Measuring eventgen suite durations after fixes, then marking heavy tests `full`.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q --durations=30 tests/test_eventgen_*.py
