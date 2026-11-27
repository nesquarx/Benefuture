# lifeimage-merge-hybrid

Status: DONE

## Goal and acceptance checks
Task A: support-weighted union merge (rule `support_union`, old `intersection` kept by name) for membership_wide and two_pass; governed
`membership.single_support_floor` (0.2); dropped singles to refinement log (`disputed`); pre-registered predictions (data/gold/membership_wide_predictions.md,
section "Support-weighted union merge") then re-score controls (v4, gold v1) and re-ingest kinds and snippets; verdicts recorded.
Task B: `map.v2` hybrid pass 2 (v4 rule from event text with blind labels as hints; `unlabelled_add`; a label may match several domains); validator,
builder, ingest; v1 reproducible; build (not run) map.v2 batches for the 32 controls and 50 snippets. Predictions in two_pass_predictions.md.
Red tests first. No LLM batches. Default test tier green. Commit own paths only; push.

## Predictions
See the two predictions files (registered before scoring).

## Decisions
- Floor 0.2 from the 104 single-variant domains of the v4 calibration (kept judged precision 0.80 at >= 0.19).
- Weights: null relation in a variant counts as unlisted (mean over all variants).

## Done
- governed threshold, predictions for Task A (committed before scoring).
- Task A done: red tests (tests/test_merge_union.py), merge rules in membership_wide.py (`rule=`), `merged_calibration_report`, tool `judge-merged`, kinds and snippets re-ingested;
  verdicts in membership_wide_predictions.md (1-4 met, 5 pair coverage failed at the ceiling: pure union 1.85x).

- Task B done except final full-suite check: prompts/map.v2.md, validate_map_answer(version=2) + unlabelled_add, two_pass (pilot_map_batches, table_path, unlabelled_adds,
  report with per-variant and merged recall), tools/build_two_pass.py --version/--gold/--merge, schema, tests/test_map_v2.py (23), predictions registered before
  implementation. map.v2 batches built (not run): lifeImage/data/batches/map.v2.{controls,snippets}.var{0,1}.part0.jsonl (gitignored; rebuild with
  `python3 lifeImage/tools/build_two_pass.py map --version 2`).
- map.v1 under the new merge on the controls (gold v1): intersection recall 0.619, union 0.741 (precision 0.607).

## In progress / Next (full default tier: 1509 passed)
Full default tier green, commit, push, mark DONE. Lead runs map.v2 batches then `build_two_pass.py ingest --version 2` and `judge --version 2`.

## Files touched
lifeimage/validate.py, schemas/answer.schema.json, prompts/map.v2.md, tests/test_map_v2.py, tools/build_two_pass.py, data/gold/two_pass_predictions.md, BACKPROPAGATION.md, data/events/two_pass_memberships_v1.jsonl, data/answers/escalations.two_pass.jsonl, lifeimage/governed.py, lifeimage/membership_wide.py, lifeimage/refinement.py, lifeimage/two_pass.py, tools/build_membership_wide.py, tests/test_merge_union.py, tests/test_membership_wide.py, tests/test_two_pass.py, README.md, data/gold/membership_wide_predictions.md, data/gold/membership_wide_merged_*.json, data/events/*_memberships_v1.jsonl, data/answers/escalations.membership_wide.*.jsonl

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_membership_wide.py tests/test_two_pass.py
