Status: DONE 2026-11-28 (pass-1 batches built, not run; label_match batches are built from the answers, so they wait for them)

## Goal and acceptance
`blind.v4` (v1-v3 kept), changing only what the v3 pilot verdict names: minimum list lengths enforced (form 5, content 4, setting 4, outcome 2; max 10; fewer
only with a per-facet `short_reason`); outcome = what the event itself makes true for the actor (no unstated sequels, no other entities' acts; contrast example
from a new event, the letter); `unknown` a zero-weight terminator, setting concrete to generic by ordinary inference; content the activity first. Kept: v3 event
splitting, perspective, glosses, LI.65 block, author baker and ticket examples; commuter, ballot, maize answers out of the prompt (test enforces).
Red test first (v3 accepts an unknown-heavy one-label setting, a null outcome, a one-label form). Batches over the 32 controls (2 variants), label_match path
(held-out cal.s08, cal.s04 incl. accepted commuter outcomes; rejected outcomes negatives). Pre-registration `lifeImage/data/gold/blind_v4_predictions.md`
(confidence 0.55). Acceptance: `cd lifeImage && python3 -m pytest -q` green; no LLM batch run.

## Predictions (work)
One sitting; default tier green; confidence 0.8. Measurement predictions: the pre-registration file (6 lines).

## Decisions
- `short_reason` is an optional event key `{facet: line}`; allowed only for a facet that is short; a null outcome or setting needs one.
- v4 `unknown` weight must be exactly 0; the real labels fall strictly and sum to 1; ladders ignore a zero-weight unknown.
- The prompt's setting-inference illustration is a ferry (the task text's bus example is the held-out commuter setting; kept out per item 5).
- Author examples rendered with the activity added to content, form/setting extended by ordinary inference to the minimum; the author's quoted lists verbatim.
- Report `two_pass.blind_v4_report` wraps `blind_v3_report`; held-out claim needs all eight cells (both items, four facets) >= 0.6.
- Governed: blind.v4.min_{form,content,outcome,setting}, short_reason_ceiling (README + governed.py).

## Done
- Red `lifeImage/tests/test_blind_v4.py` (22 of 24 failed first; baseline shows v3 accepts the thin answer), then green.
- `validate.py` (zero_unknown, `_check_minimums`, version 4), `governed.py`, README, `two_pass.py` (LATEST_BLIND_VERSION 4, `blind_v4_report`),
  `tools/build_two_pass.py` (pilot/label_match `--blind-version 4`, `report_v4`, status), `prompts/blind.v4.md`, predictions file, LI.72 Built line.
- Built (gitignored): `lifeImage/data/batches/blind.v4.controls.var{0,1}.part0.jsonl` (32 tasks each).

## In progress
(nothing)

## Next
After the blind.v4 answers exist: `python3 tools/build_two_pass.py label_match --blind-version 4` (132 tasks, 3 parts), run them, `report_v4`.

## Files touched
progress/lifeimage-blind-v4.md; lifeImage/{prompts/blind.v4.md,lifeimage/{validate,governed,two_pass}.py,tools/build_two_pass.py,tests/{test_blind_v4,test_blind_v3}.py,
README.md,BACKPROPAGATION.md,data/gold/blind_v4_predictions.md}

## Resume
cd /home/user/Benefuture/lifeImage && python3 tools/build_two_pass.py pilot --blind-version 4 --sets controls && python3 -m pytest -q
