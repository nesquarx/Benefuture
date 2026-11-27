Status: DONE 2026-11-27

## Goal and acceptance
Task A: prompt `lifeImage/prompts/blind.v2.md` (v1 kept) per LI.71: per relation 4-8 categories specific to generic, weights decreasing and summing to 1,
glosses, key action decides, setting unknown when not stated. Validator v2 in `lifeimage/validate.py` (decreasing, sum 1, glosses, no ids, at most one
`unknown` per relation, a label repeated across relations needs a different gloss). Red test first: v1 accepts a sparse answer (1-2 broad labels, outcome null).
Task B: pilot batches `data/batches/blind.v2.controls.var{0,1}.part0.jsonl` (built, not run); pre-registration `data/gold/blind_v2_predictions.md`
(confidence 0.5); judging task `label_match.v1` (+ builder, since its batch needs the answers).
Task C: design note `lifeImage/data/fine/LEAF_DOMAINS.md` (proposal), including the author's placement addition (strongest-tie parent; other parents not placed).
Acceptance: `cd lifeImage && python3 -m pytest -q` green; no LLM batch run.

## Predictions (work)
Tests red then green in one sitting; default tier green; confidence 0.8.

## Decisions
- v2 answer entries are `{label, weight, gloss}` (weight replaces fit); an `unknown` marker is a label "unknown" last in its list, carrying residual weight.
- Min 4 labels is measured (soft, pre-registered), max 8 enforced; validator list follows the brief exactly. Outcome may be null (measured >= 90% present).
- Strictly decreasing weights, sum within 0.02 of 1 (governed `blind.v2.weight_tolerance`).
- Confound recorded: cal.d01 and cal.d02 are the in-prompt author examples, so their matches test faithful use of the example, not generalisation.

## Done
- Red tests `lifeImage/tests/test_blind_v2.py` (collection error, then 5 red) then green; baseline test shows v1 accepts the thin answer.
- Validator v2 (`validate.py`, `version=2`, header version used by `validate_answers`), governed values, `schemas/answer.schema.json` run_ref, tasks verdicts.
- `prompts/blind.v2.md` (v1 kept), `two_pass.py` (thin_relations, blind_v2_report, pilot_blind_batches(prompt_version, sets)), `label_match.py`, `prompts/label_match.v1.md`, RUNNER.md.
- Built (not run), gitignored like all batches: `data/batches/blind.v2.controls.var{0,1}.part0.jsonl` (32 tasks each).
- `data/gold/blind_v2_predictions.md` (confidence 0.5; confound recorded).
- `lifeImage/data/fine/LEAF_DOMAINS.md` with the author's strongest-tie placement addition.

## In progress
(nothing)

## Next
After blind.v2 answers: `build_two_pass.py label_match`, run its batch, `report_v2`; adapt map.v2 to weights and glosses.

## Files touched
progress/lifeimage-blind-v2.md; lifeImage/{prompts/blind.v2.md,prompts/label_match.v1.md,prompts/RUNNER.md,lifeimage/{validate,governed,tasks,two_pass,label_match}.py,
schemas/answer.schema.json,tools/build_two_pass.py,tests/test_blind_v2.py,README.md,data/gold/blind_v2_predictions.md,data/fine/LEAF_DOMAINS.md}

## Resume
cd /home/user/Benefuture/lifeImage && python3 tools/build_two_pass.py pilot --blind-version 2 --sets controls && python3 -m pytest -q
