Status: IN PROGRESS 2026-11-28

## Goal and acceptance
`blind.v5` (v1-v4 kept), changing only: (1) form lists role and purpose besides the act (new in-prompt event: an exam); (2) competence lists concrete
sub-skills before broader capabilities (new event: pruning a tree); (3) per-event `mode` (LI.74) required by the validator, `competence_basis(mode, validation)`
in `lifeimage/two_pass.py`, 8 invented profile statements in the pilot items; (4) outcome contrast with a new example (sequel and another entity's act
excluded even when paraphrased); (5) competence/form overlap metric fixed. Red test first (`lifeImage/tests/test_blind_v5.py`). Overfitting note and the
`HELD_OUT_FRESH` slot in `data/gold/blind_v5_predictions.md` and `label_match.py`. Batches built, not run; no LLM batch run.
Acceptance: `cd lifeImage && python3 -m pytest -q` green (default tier), pre-registration written before any answer.

## Predictions (work)
One sitting; default tier green; confidence 0.8. Measurement predictions: `lifeImage/data/gold/blind_v5_predictions.md` (confidence 0.5).

## Decisions
- Enforcing role/purpose/sub-skill needs a structural handle: each event carries `layers` {role, purpose, sub_skill} naming a label of the form (role, purpose: two
  different labels) or competence list (sub_skill within the first `blind.v5.concrete_first_share` = 0.5, rounded up; governed), or `{"none": reason}`.
- Profile statements: 8 = 2 each of role, credential, plan, self_assessment (`claim` is a statement of an event, not profile-like); gold in
  `data/gold/profile_statements_v0.jsonl`, never in a task. v5 controls = 32 + 8 (+ fresh items); earlier versions stay 32.
- Overlap metric: the committed v4 report holds 0.345, not null; the v4 function is null only without events and misses near-copies. v5 reports events and labels,
  identical and near (stemmed Jaccard >= 0.6, reporting parameter), the pre-registered line stays the identical-event share. Recorded in the predictions file.
- `competence_basis`: validation tiers formal, attested, claimed, none/None; unknown mode or tier raises ValueError ("verified" is not accepted: LI.74 text names it as a tier but the task fixed formal or attested).
- Rejected outcomes counted on match or partial (stricter than v4).
- New in-prompt events: exam (role/purpose), pruning (sub-skills), kettle (outcome contrast, prose), forklift licence (mode credential).

## Done
- Red `lifeImage/tests/test_blind_v5.py` first (67 failed, 5 passed incl. 3 baselines showing the v4 outcomes), then green (72).
- `validate.py` (version 5, `_check_layers`, BLIND_MODES), `governed.py` + README (concrete_first_share), `two_pass.py` (competence_basis, profile_items/gold,
  pilot_items(version), overlap detail, blind_v5_report, LATEST 5), `label_match.py` (HELD_OUT_FRESH, fresh_items, DEVELOPMENT_ITEMS, held_out(5)),
  `tools/build_two_pass.py` (report_v5, status), `prompts/blind.v5.md`, `data/gold/{blind_v5_predictions.md,profile_statements_v0.jsonl}`, BACKPROPAGATION LI.74 Built line.
- Built (gitignored): `lifeImage/data/batches/blind.v5.controls.var{0,1}.part0.jsonl` (40 tasks each).

## In progress
full default-tier run after the last change

## Next
After the blind.v5 answers exist: `python3 tools/build_two_pass.py label_match --blind-version 5`, run them, `python3 tools/build_two_pass.py report_v5`.

## Files touched
progress/lifeimage-blind-v5.md; lifeImage/{prompts/blind.v5.md,lifeimage/{validate,governed,two_pass,label_match}.py,tools/build_two_pass.py,tests/{test_blind_v5,test_blind_v4}.py,
README.md,BACKPROPAGATION.md,data/gold/{blind_v5_predictions.md,profile_statements_v0.jsonl}}

## Resume
cd /home/user/Benefuture/lifeImage && python3 tools/build_two_pass.py pilot --blind-version 5 --sets controls && python3 -m pytest -q
