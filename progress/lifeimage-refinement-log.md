# lifeimage-refinement-log (LI.68)

Status: DONE

## Goal and acceptance checks
1. Candidate schema + `data/refinement/candidates_v1.jsonl` (append-safe, dedup by key, sorted) + `summary_v1.json` (per domain, per pair), written by judge and ingest.
2. Backfill from v3/v4 calibration answers (59 / 55 unjudged).
3. Tests: red first; candidates never in memberships; every unjudged secondary in the log; near-floor uses version floor (v3 4, v4 5).
4. `data/refinement/README.md`.

## Decisions
- Module `lifeimage/refinement.py`; `membership_wide.log_calibration` (judge) and `ingest(..., refinement_dir=None)` call it; `REFINEMENT_DIR` resolved at call time (tests redirect it).
- Key = item, relation, domain, source, prompt_version, variant. Gold-judged domains (fair or bad) are never candidates. `agent` field omitted (model ids kept out; variant identifies the run).
- unjudged only for controls (gold fair known), secondaries only (matches the calibration report); disputed = listed by exactly one variant.
- CLI `build_membership_wide.py refine [--version N]` backfills; `judge` also logs.

## Done
All of 1-4; 9 tests in `tests/test_refinement_log.py`; existing membership tests redirect the log to tmp.

## In progress / Next
None. Pre-existing failure not mine: `test_v4_predictions_are_registered_before_any_v4_answer_exists` (v4 answers now exist locally).

## Files touched
lifeimage/refinement.py, lifeimage/membership_wide.py, tools/build_membership_wide.py, tests/test_refinement_log.py, tests/test_membership_wide.py, data/refinement/*, this note.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_refinement_log.py && python3 tools/build_membership_wide.py refine --version 3 && python3 tools/build_membership_wide.py refine --version 4
