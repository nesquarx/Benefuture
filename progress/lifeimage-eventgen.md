# lifeimage-eventgen (Life Image life-course event generator, increment 1)

Status: IN PROGRESS

## Goal and acceptance checks
- Step 1: calibration table (`Param` schema, aggregates-only JSONL in `lifeImage/data/events/calibration/`), ~30 field families, source + URL + licence class + confidence per value. Red tests: missing source/URL/region/confidence fails; duplicate keys fail.
- Step 2: probe world `lifeImage/lifeimage/eventgen/` (family + schooling only; few hundred people, 2-3 regions; per-transition noise on own streams; library row format; loud `degraded` substitution).
- Step 3: rate head (paired seeds, combined SE, z=2): per-Param pass/fail with effect sizes; counterexample (doubled fertility) detected; missing region degrades loudly.
- Acceptance: `cd lifeImage && python3 -m pytest -q` green; probe runnable alone with one command.

## Predictions (lead, confidence 0.6; recorded before measuring)
(a) >= 30 field families with >= 1 Param with a working URL. (b) probe < 10 s for 500 people x 3 regions. (c) rate head passes all matched Params and flags doubled-fertility at z >= 2. (d) at least one region degrades to a coarser Param.

## Decisions
- Do not touch lifeimage/fine/gap2.py, tools/fine_*; existing generator untouched.
- Raw downloads (WPP, ILOSTAT bulk) live only in scratchpad; only aggregates are committed.

- LI.64 (lead, mid-task): every Param carries `snippet` (short sanitized source statement), `snippet_locator` (page/table/indicator code), `retrieved` (date); a Param without a snippet must carry `snippet_missing` (reason) and confidence low; schema test enforces. Aggregates and documentation only.

## Done
(none yet)

## In progress
Fetching aggregates.

## Next
Schema + red tests, fetch tool, table, probe, rate head, docs (governed + parsimony), README of package.

## Files touched
progress/lifeimage-eventgen.md

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_eventgen*.py
