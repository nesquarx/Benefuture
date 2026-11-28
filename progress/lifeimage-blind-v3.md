Status: DONE 2026-11-28 (pass-1 batches built, not run; label_match batches are built from the answers, so they wait for them)

## Goal and acceptance
`blind.v3` (v1, v2 kept) per LI.71-72: prompt `lifeImage/prompts/blind.v3.md` (events split first; form at every level incl. role, purpose, regularity;
content the doing; outcome the actor's supported changes only; setting concrete to generic stopping where the statement stops; lists up to 10, each more
generic; weights by centrality, no ladder; LI.71 baker and ticket examples kept; LI.72 commuter and ballot NOT in the prompt). Validator version 3
(events >= 1, decreasing weights summing to 1, glosses, no ids, equal-step ladders flagged). Red test first. Batches over the 32 controls (2 variants) and
label_match batches vs in-prompt (d01, d02) and held-out (cal.s08, cal.s04) author labels with the rejected outcomes as negatives. Pre-registration
`lifeImage/data/gold/blind_v3_predictions.md` (confidence 0.5). Acceptance: `cd lifeImage && python3 -m pytest -q` green; no LLM batch run.

## Predictions (work)
Red then green in one sitting; default tier green; confidence 0.8. Measurement predictions: see the pre-registration file.

## Decisions
- v3 answer = `{verdict, reason, events:[{id e1.., text, blind, relational}]}`; no top-level blind/relational; `blind.v3.max_events` 6 enforced.
- Multi-event answers must link events by id (a link naming an id must name another existing event); compound detection is NOT lexical (no speculative
  patching): splitting is measured (maize control), not enforced.
- "Another entity's act" and "unstated result" outcomes cannot be validated structurally: measured through label_match negatives (`NEGATIVE_LABELS`).
- LI.72 lists no accepted outcome for the commuter: `HELD_OUT["cal.s08"]["outcome"] == []`, seven held-out cells; asked of the author (recorded in
  the predictions and LI.72 Built line).
- Ladder: flagged by `validate.equal_step_ladders` (>= 3 entries, equal two-decimal steps), share over all non-null lists.
- Prompt weights in examples are non-ladder; a test asserts it. Prompt examples: baker, ticket (author), nurse (long lists), teacher (compound split).
- label_match judge prompt unchanged (v1); the judge is not told which labels are negative.

## Done
- Red tests `lifeImage/tests/test_blind_v3.py` (collection error first; baselines show v2 accepts a one-event compound answer and the rejected outcomes), then green (32).
- `validate.py` (`_validate_relational` extracted, `_validate_blind_answer_v3`, `equal_step_ladders`), `governed.py` + README (4 governed values), schema `events`.
- `prompts/blind.v3.md`; `two_pass.py` (LATEST_BLIND_VERSION 3, `blind_prefix` v3 wording, `event_blinds`, `blind_v3_report`); `label_match.py` (HELD_OUT,
  NEGATIVE_LABELS, `authors`/`negatives` args, v3 `run_view`); `tools/build_two_pass.py` (`label_match --blind-version 3`, `report_v3`, status).
- Built (gitignored): `lifeImage/data/batches/blind.v3.controls.var{0,1}.part0.jsonl` (32 tasks each).
- `lifeImage/data/gold/blind_v3_predictions.md`; LI.72 Built line in `lifeImage/BACKPROPAGATION.md`.

## In progress
(nothing)

## Next
After the blind.v3 answers exist: `python3 tools/build_two_pass.py label_match --blind-version 3` (132 tasks, 3 parts), run them, `report_v3`; adapt map.v2 to events.

## Files touched
progress/lifeimage-blind-v3.md; lifeImage/{prompts/blind.v3.md,lifeimage/{validate,governed,two_pass,label_match}.py,schemas/answer.schema.json,
tools/build_two_pass.py,tests/test_blind_v3.py,README.md,BACKPROPAGATION.md,data/gold/blind_v3_predictions.md}

## Resume
cd /home/user/Benefuture/lifeImage && python3 tools/build_two_pass.py pilot --blind-version 3 --sets controls && python3 -m pytest -q
