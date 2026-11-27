# blind.v2 (LI.71): pre-registered predictions

Registered 2026-11-27, before any `blind.v2` answer exists. Rule under test: pass 1 `blind.v2` (`prompts/blind.v2.md`): per relation 4 to 8
categories from the most specific to the most generic, weights decreasing and summing to 1, a gloss each, the key action deciding, the outcome
expected for nearly every event, the setting `unknown` where the statement gives none (validator: `validate_blind_answer(..., version=2)`).
Pilot: the 32 membership calibration controls, 2 variants (`data/batches/blind.v2.controls.var{0,1}.part0.jsonl`, built by
`python3 lifeImage/tools/build_two_pass.py pilot --blind-version 2 --sets controls`, not run). Judging task `label_match.v1` (`prompts/label_match.v1.md`,
`lifeimage/label_match.py`): a runner compares each of the author's labels (LI.71) with the run's list for that relation, verdict `match`, `partial`
or `none`; its batch is built from the validated answers (`build_two_pass.py label_match`); the report is `build_two_pass.py report_v2`
(`two_pass.blind_v2_report`). Confidence 0.5 for the set; each line is a separate claim and the set can fail in parts.

| # | Prediction | Metric | Smallest effect that matters |
|---|------------|--------|------------------------------|
| 1 | The lists are wide | median number of categories (the `unknown` marker excluded; a null outcome counts 0) per relation over the 64 answers (32 controls, 2 variants) | median >= 4 for form, for content and for outcome |
| 2 | The outcome is given | share of the 64 answers whose outcome is not null | >= 90% |
| 3 | The runs hold the author's categories | for each relation, the share of the author's labels (cal.d01, cal.d02; 16 and 13 labels) that a run's list matches in the same sense, pooled over the two items and the two variants, `partial` counting 0.5 | >= 60% in each of form, content, outcome and setting |
| 4 | The key action decides | the number of form or content labels of cal.d01 (both variants) containing the word cook (cooking appears nowhere in the text: the baker sells; the v4 runs listed cooking as a form and as the first content) | 0 |

Also reported, no prediction attached: the strict match share (`match` only), the answers with any relation under 4 categories (`thin_answers`),
the answers whose setting is `unknown`, the validator's rejections on first writing, and the weights' shape (the share going to the first label).

Known confound, stated before measuring: cal.d01 and cal.d02 are the two events whose author categorisations are the in-prompt worked examples, so
predictions 3 and 4 measure whether a run uses the examples faithfully (and the example format), not whether it generalises to unseen events; a
pass is expected and weak evidence. A generalisation test needs a held-out author-categorised event or two (an open request to the author:
categorise two more controls by hand, then judge them the same way). Predictions 1 and 2 are not affected, the examples being only four of the
prompt's forms. A second weakness: the author's outcome lists hold two labels (cal.d01), so the share on outcome rests on 2 + 4 labels.

Reading and adaptation: judged when the 64 answers and the label_match answers exist (minutes of runner time). Decision rule: if 1 or 2 fails,
the prompt's width or outcome instruction is too weak, so strengthen that paragraph in `blind.v3` (the old versions stay) before blaming the
runner; if 3 fails with the examples in the prompt, the runners do not read them, so the format rules are the problem; if 4 fails, the key-action
rule is not holding even for the case the prompt shows. One re-run on a changed prompt before any adoption; the prompt version is recorded with
every result. Pass 2 (`map.v2`) reads `fit`, not `weight`; its adaptation to weighted, glossed categories waits for this pilot.
