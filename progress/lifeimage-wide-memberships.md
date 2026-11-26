# lifeimage-wide-memberships (LI.67: wide event memberships by a ranked stopping rule)

Status: DONE

## Goal and acceptance checks
1. `prompts/membership.v3.md`, `prompts/extract.v2.md`: per relation, domains listed in decreasing weight, primary first, adding while the next domain is a fair
   categorisation (fit score 0-10 >= floor 4), stopping at the first poor fit; answer records each listed fit and the best rejected domain with its score.
   events.v1 assigns no domains, so no events.v2. Old versions stay.
2. Validator (`lifeimage/validate.py`): rejects unranked lists, listed domain below floor, stop while best rejected >= floor, weights not decreasing/summing to 1.
   Floor governed (`membership.fit_floor` in `lifeimage/governed.py`). Red tests first (`tests/test_membership_wide.py`).
3. Calibration battery (controls: single-domain, multi-domain, decoys) as 2 runner batches; metrics function for the lead.
4. Batches for the 83 kinds and 200 calibration snippets (2 variants, <= 50 per file) in `data/batches/` (gitignored); NOT run by me. Ingest tool merges variants into
   `data/events/kind_memberships_v1.jsonl` (agreement = confidence, escalate disagreements). `lifeimage/eventgen/` untouched.
5. Default test tier green; paths listed; predictions written (`data/gold/membership_wide_predictions.md`).

## Predictions (pre-registered, confidence 0.5)
- Median listed domains per relation rises from about 1 to 2-4 (form, content, outcome, setting; null relations excluded).
- Precision of secondary domains on the controls >= 0.8.
- Padding on single-domain controls <= 10%.
- ETA: judged when the lead has the calibration answers (2 batch files, minutes of runner time); adapt the floor (3 or 5) if padding or recall fails, then re-run once.

## Decisions
- Answer shape v3: `types` {rel: {domain: weight} in rank order | null} plus `ranks` {rel: {listed:[{domain,fit}], rejected:{domain,fit}} | null}; real types only (form, content, outcome, setting; no placebo `flavour`). Schema `answer.schema.json` allows `ranks`.
- Floor 4 and variant agreement floor 0.5 are governed (`membership.fit_floor`, `membership.agree_floor`), GT.2 proposed in `lifeImage/BACKPROPAGATION.md`.
- events.v1 assigns no domains, so no events.v2; extract.v2 prompt + validator (`ranked=True` by header prompt_version >= 2) added, extract batch builder untouched.
- Baseline measured: catalog medians form 1, content 3, outcome 2, setting 1 (the brief said 1-2; content is 3); coverage 2.1%.
- Ingest: memberships = domains every variant listed (mean weights renormalised); confidence = Jaccard agreement + per-domain share; disputed domains kept apart; escalate on differing primary, agreement < floor, or relation null in some variants only.
- Floor stays on the 0-10 fit scale (integer scores match the prompt text and validator); `membership.` added to the unitless exemption in `tests/test_responsibility.py` (lead's request, one-line reason: converting to 0.4 would couple prompt wording to a share).
- Items: kinds `kind.<key>` text = statement without place (+ outcome text when the kind has one); 200 snippets sampled round-robin over quantities (distinct actions first); 32 controls.

## Done
- Red baseline tests committed (validator accepted unranked/below-floor lists), then: prompts membership.v3, extract.v2; validator; governed values; `lifeimage/membership_wide.py` (items, batches, judge, ingest, width_summary); `tools/build_membership_wide.py`; controls gold; predictions; RUNNER.md note; 32 tests green in `tests/test_membership_wide.py`.
- Batches written (gitignored) in `lifeImage/data/batches/`: calibration 2 files, kinds 4, snippets 8.

## In progress
- (none) Default tier: 1377 passed; remaining failures are test_render circular order and two test_tiles cases (basemap adoption agent files, not mine); the responsibility governed-range test is fixed.

## Next (lead)
1. Run `membership.A3S.v3.calibration.var{0,1}.part0.jsonl` with lifeimage-runner agents, then `python3 lifeImage/tools/build_membership_wide.py judge`; compare to `data/gold/membership_wide_predictions.md`; adapt floor per its decision rule.
2. Then run the kinds (4 files) and snippets (8 files) batches; `... ingest kinds` / `ingest snippets` (writes `data/events/kind_memberships_v1.jsonl`, `snippet_memberships_v1.jsonl`, escalations in `data/answers/`).
3. Eventgen generator adoption of the table (other agent's area; not touched).

## Files touched
lifeImage/prompts/membership.v3.md, extract.v2.md, RUNNER.md; lifeimage/validate.py, governed.py, membership_wide.py; schemas/answer.schema.json; tools/build_membership_wide.py; tests/test_membership_wide.py; data/gold/membership_wide_controls_v0.jsonl, membership_wide_predictions.md; BACKPROPAGATION.md (GT.2 hunk only).

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_membership_wide.py && python3 tools/build_membership_wide.py batches
