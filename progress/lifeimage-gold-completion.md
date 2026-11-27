# lifeimage-gold-completion (LI.69: complete the calibration gold, re-score v3/v4, build v4 kinds/snippets)

Status: DONE

## Goal and acceptance checks
1. Task `gold_judge` (prompt `gold_judge.v1`, stable prefix) judging every unjudged (item, relation, domain) of the v3 and v4 calibration (deduplicated): `fair|bad|unsure` plus a one-line reason; 2 variants with the gold lists in opposite order; disputes to `data/gold/membership_wide_disputed_v1.md`; agreed verdicts extend the gold as `membership_wide_controls_v1.jsonl` with provenance (v0 kept).
2. `judge --version 3|4 --gold v1` -> `membership_wide_calibration_report_v{3,4}_gold_v1.json` (pre-registered metric, judged-only metric, old padding and `padding_single_complete`). Predictions registered first.
3. v4 kinds and snippets batches built (not run); ingest already logs refinement candidates (tested at floor 5).
4. Tests red first; default tier green.

## Predictions (pre-registered before any gold-judge answer, confidence 0.5)
v4 `precision_secondary` >= 0.8 on v1 gold; v4 `padding_single_complete` <= 0.25; v3 worse than v4 on both. In `data/gold/membership_wide_predictions.md`.

## Decisions
- 71 deduplicated unjudged triples (v3 59 + v4 55 cells collapse across variants and versions); 2 variants x 2 parts of <= 50 tasks.
- Relation meanings are parsed from `prompts/membership.v4.md` (live once); domain label and description come from the coarse pack.
- Disputes stay out of `fair`/`bad` and are recorded in the control's `unsure` lists; an author ruling file `data/gold/membership_wide_rulings_v1.jsonl` ({item, relation, domain, verdict}) resolves them on the next `gold-ingest` (provenance `author`).
- Padding definition change: `padding_single_complete` counts a cell only for a gold-bad or `unsure` secondary; unjudged domains are reported (`n_unjudged`), not counted; old `padding_single` (outside fair) still reported.
- No model identifiers outside the batch header (`MODEL`, existing).

## Done
All of the above. `tests/test_gold_completion.py` 21 tests.

## In progress
none

## Next (lead)
Run the four gold batches, then `python3 lifeImage/tools/build_membership_wide.py gold-ingest`, then `judge --version 3 --gold v1` and `judge --version 4 --gold v1`; judge against the predictions; review `membership_wide_disputed_v1.md`. Then run the v4 kinds and snippets batches and `ingest kinds|snippets`.

## Batches (data/batches, gitignored)
gold_judge.v1.gold.var{0,1}.part{0,1}.jsonl; membership.A3S.v4.kinds.var{0,1}.part{0,1}.jsonl; membership.A3S.v4.snippets.var{0,1}.part{0..3}.jsonl

## Files touched
lifeImage/lifeimage/gold_judge.py, membership_wide.py, tasks.py; prompts/gold_judge.v1.md; tools/build_membership_wide.py; tests/test_gold_completion.py; data/gold/membership_wide_predictions.md; this note.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_gold_completion.py && python3 tools/build_membership_wide.py gold-batches && python3 tools/build_membership_wide.py batches --version 4 --sets kinds,snippets
