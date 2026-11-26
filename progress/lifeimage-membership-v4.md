# lifeimage-membership-v4 (LI.67: floor 5, membership.v4)

Status: DONE

## Goal and acceptance checks
- Record the v3 verdict in `lifeImage/data/gold/membership_wide_predictions.md` (done first), then implement `membership.v4` per the pre-registered rule: floor 5 everywhere in the prompt (scale, examples, stopping rule, best-rejected rule); examples validate at 5.
- Floor by prompt version (`governed.membership_fit_floor`: v3 -> `membership.fit_floor` 4, v4 -> `membership.fit_floor.v4` 5); v3 reproducible.
- Tests: v4 rejects a listed domain at fit 4 and a stop while best rejected >= 5; v3 unchanged.
- Judge reports precision two ways (pre-registered with unjudged against; fair share of judged = 146/152 = 0.9605); unjudged review file `data/gold/membership_wide_unjudged_v3.md` (59 domains).
- Only the v4 calibration batches built; no kinds/snippets for v4; nothing run.

## Predictions (pre-registered before any v4 answer, confidence 0.4)
precision (pre-registered metric) >= 0.8; padding <= 0.10; median listed multi form/content >= 2; recall of required >= 0.85. If it still fails: author decision (judge the gold's unjudged domains) rather than a higher floor.

## Decisions
- `membership_wide.PROMPT_VERSION` stays 3 (library default, v3 reproducible); `LATEST_PROMPT_VERSION` = 4; the CLI defaults to `--version 4` and to the calibration set only (`--sets` widens).
- `validate_ranked_membership_answer` takes the floor from the answer's prompt_version when no floor is given; `validate_answers` passes the header's version floor. extract.v2 keeps floor 4.
- v4 judge report goes to `membership_wide_calibration_report_v4.json` (v3's name unchanged).
- v4 examples: fit-4 listings of v3 became rejected-at-4 (tomato horticulture, measles healthcare_work kept at 5, glaciers weather at 5).

## Done
All of the above; 39 tests in `tests/test_membership_wide.py` green plus test_responsibility, test_schemas, test_cache_tasks (177 passed).

## In progress
(none)

## Next (lead)
Run `lifeImage/data/batches/membership.A3S.v4.calibration.var{0,1}.part0.jsonl`, then `python3 lifeImage/tools/build_membership_wide.py judge --version 4` and `unjudged --version 4`; compare with the v4 predictions; only then build kinds/snippets (`batches --version 4 --sets kinds,snippets`).

## Files touched
lifeImage/prompts/membership.v4.md; lifeimage/governed.py, validate.py, membership_wide.py; tools/build_membership_wide.py; tests/test_membership_wide.py; data/gold/membership_wide_predictions.md, membership_wide_unjudged_v3.md.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_membership_wide.py && python3 tools/build_membership_wide.py batches --version 4
