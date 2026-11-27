# lifeimage-two-pass (LI.70: blind pass 1, mapping pass 2)

Status: DONE (pending final commit and push, see Done)

## Goal and acceptance checks
- Pass 1 `blind.v1`: runner reads the event text, never sees domain ids; per relation (form, content, outcome, setting) ranked free labels (fit 0-10, gloss) plus LI.65 relational extraction.
- Pass 2 `map.v1`: runner with the domain pack (coarse + fine, aliases, short descriptions) and the pass-1 answer allocates labels to ids (v4 floor 5), logs synonyms, reviews unmatched labels (new_domain_candidate or noise).
- Code: builders, validators (validate.py), merge across 2 variants, e2e ingest (memberships + synonyms + blind_unmatched candidates). Red tests first. Pilot pass-1 batches built, not run. Predictions pre-registered in data/gold/two_pass_predictions.md. Default tier green.

## Predictions
In `lifeImage/data/gold/two_pass_predictions.md` (confidence 0.5): recall >= 0.91 (v4 0.96 minus 0.05), judged-secondary precision >= 0.95, >= 10 distinct synonyms, >= 3 new-domain candidates non-noise, pass-1 labels never contain domain ids (structural).

## Decisions
- Task types `blind` and `map` (not `membership.*`); validators dispatch in `validate_answers` on the header task type.
- Pass 1 variants differ in the relation reading order (prefix tail); no pack to shuffle. Pass 2 variants shuffle the pack; variant v of pass 2 reads variant v of pass 1.
- Pass-1 floor 4 (`blind.fit_floor`), max 6 labels (`blind.max_labels`), both governed; pass-2 memberships use the v4 floor 5.
- Pass 2 memberships may only use domains some blind label of that relation matched (anchoring), all four relations may be null (`validate_ranked_types(allow_all_null=True)`); `exact` is only valid when the label equals the domain label or an alias.
- Pass 1 merge escalates only when a relation applies in one variant only (wording differs without disagreement); domain-level disagreement escalates through the pass-2 merge (`membership_wide.merge_item`).
- Synonym log idempotent via cells keyed by item, variant, pass-1 answer hash, ref. Refinement source `blind_unmatched` added to `refinement.py` (new function `blind_unmatched_record` and `slug`, SOURCES extended); only candidates logged, noise not.
- Pass-2 pack: 1,897 domains, ~62k tokens (fine descriptions cut to 90 chars, 2 aliases, coarse parent in brackets).

## Done
- Red tests: tests/test_two_pass_baseline.py (green baseline of one-pass), tests/test_two_pass.py (was red: module missing).
- lifeimage/two_pass.py, prompts/blind.v1.md, prompts/map.v1.md, validate.py, packs.py, governed.py, refinement.py, schemas/answer.schema.json, tools/build_two_pass.py, RUNNER.md, data/refinement/README.md, README governed line, BACKPROPAGATION LI.70 note, predictions file.
- Pass-1 pilot batches built (gitignored, rebuild with `build_two_pass.py pilot`): data/batches/blind.v1.{controls,snippets}.var{0,1}.part0.jsonl (32 and 50 tasks).

## In progress
(none)

## Next (lead)
Run the four pass-1 files, `python3 lifeImage/tools/build_two_pass.py map`, run the pass-2 files, `ingest`, `judge`; compare with the predictions.

## Files touched
lifeImage/: lifeimage/two_pass.py, validate.py, packs.py, governed.py, refinement.py; prompts/blind.v1.md, map.v1.md, RUNNER.md; schemas/answer.schema.json; tools/build_two_pass.py; tests/test_two_pass.py, test_two_pass_baseline.py; data/gold/two_pass_predictions.md; data/refinement/README.md; README.md; BACKPROPAGATION.md.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_two_pass.py tests/test_two_pass_baseline.py && python3 tools/build_two_pass.py pilot
