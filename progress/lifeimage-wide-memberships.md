# lifeimage-wide-memberships (LI.67: wide event memberships by a ranked stopping rule)

Status: IN PROGRESS

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

## Decisions / Done / In progress / Next
(updated per milestone)

## Files touched
(see below)

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_membership_wide.py
