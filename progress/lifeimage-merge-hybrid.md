# lifeimage-merge-hybrid

Status: IN PROGRESS

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

## In progress / Next
Task B (map.v2): red tests, prompt, validator (version-aware), builder, ingest, report, batches.

## Files touched
lifeimage/governed.py, lifeimage/membership_wide.py, lifeimage/refinement.py, lifeimage/two_pass.py, tools/build_membership_wide.py, tests/test_merge_union.py, tests/test_membership_wide.py, tests/test_two_pass.py, README.md, data/gold/membership_wide_predictions.md, data/gold/membership_wide_merged_*.json, data/events/*_memberships_v1.jsonl, data/answers/escalations.membership_wide.*.jsonl

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_membership_wide.py tests/test_two_pass.py
