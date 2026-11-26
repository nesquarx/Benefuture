# Wide event memberships (LI.67): pre-registered predictions

Registered before any answer exists (2026-11-26). Rule under test: prompt `membership.v3` (and `extract.v2`), a ranked stopping rule with a
fit floor of 4 of 10 (`membership.fit_floor`, `lifeimage/governed.py`), judged by `python3 lifeImage/tools/build_membership_wide.py judge`
on the control battery `data/gold/membership_wide_controls_v0.jsonl` (12 single-domain, 12 multi-domain, 8 decoy events; two pack-order
variants; batches `data/batches/membership.A3S.v3.calibration.var{0,1}.part0.jsonl`). Confidence 0.5 for the set; each line below is a separate
claim, and the set can fail in parts.

| # | Prediction | Metric | Smallest effect that matters |
|---|------------|--------|------------------------------|
| 1 | Median listed domains per relation rises from about 1 to 2-4 | median over non-null (event, relation) cells, per relation, on the kinds and snippets tables (`width_summary`) and on the multi controls for form and content | median 2 or more; above 4 is padding |
| 2 | Secondary domains are real | share of secondary (second and later) listed domains that the gold `fair` list names, over control cells | >= 0.8 (unjudged domains count against it and are listed for review) |
| 3 | The rule does not pad plain events | share of single-domain control cells with a secondary domain outside `fair` | <= 0.10 |

Also reported, no prediction attached: recall of the gold `required` domains on multi controls, the decoy hit rate (decoy cells listing a gold
`bad` domain), and the rate at which an answer's best rejected domain sits at the floor's edge (a fit of 3).

Baseline (current hand-set memberships of the 83 generated kinds, `lifeimage/eventgen/catalog.py`): median 1 (form), 3 (content), 2 (outcome), 1 (setting);
pair coverage 2.1% of 30381 field pairs (`data/events/coverage_v1.json`, P.EG3.4).

ETA and adaptation: judged when the lead has the two calibration answers files (minutes of runner time). Decision rule: if 2 fails (secondary
precision under 0.8) or 3 fails (padding over 0.10), raise the floor to 5 and write `membership.v4` (a new prompt version, the old stays); if 1 fails on
the multi controls with precision intact, lower the floor to 3 the same way; if both fail together, the rubric text is the suspect, not the floor.
Re-run the battery once on the new version. Only then run the kinds and snippets batches.

## v3 judged (2026-11-26, lead)

Battery `membership.A3S.v3.calibration.var{0,1}.part0` (report `data/gold/membership_wide_calibration_report.json`, floor 4):

| # | Prediction | Result | Verdict |
|---|------------|--------|---------|
| 1 | median listed rises to 2-4 | all relations: form 2, content 2.5, outcome 2, setting 2; multi controls form 3, content 3 | met |
| 2 | secondary precision >= 0.8 | 0.6919 (211 secondary cells: 146 fair, 6 bad, 59 unjudged counted against) | failed |
| 3 | padding on single-domain controls <= 0.10 | 0.5517 (58 cells) | failed |

Also reported: decoy hit rate 0.0625, recall of required 0.9259. Fair share of the judged secondaries: 146 of 152 = 0.9605 (reported beside the
pre-registered metric, which stays the verdict's metric; the 59 unjudged domains are listed in `data/gold/membership_wide_unjudged_v3.md`).

Consequence by the decision rule above: 2 and 3 failed, so the floor is raised to 5 and `membership.v4` is written (a new prompt version; v3 stays
and its answers keep validating under floor 4: the floor is chosen by prompt version, `membership.fit_floor` 4 for v3, `membership.fit_floor.v4` 5
for v4, `lifeimage/governed.py`). The battery is re-run once on v4; kinds and snippets batches are not built for v4 until then.

## v4 predictions (pre-registered 2026-11-26, before any v4 answer exists)

Rule under test: prompt `membership.v4`, floor 5 (scale text, worked examples, stopping rule and best-rejected rule at 5), judged by
`python3 lifeImage/tools/build_membership_wide.py judge --version 4` on the same controls and variants (batches
`data/batches/membership.A3S.v4.calibration.var{0,1}.part0.jsonl`). Confidence 0.4 for the set; each line is a separate claim.

| # | Prediction | Metric | Smallest effect that matters |
|---|------------|--------|------------------------------|
| 1 | Secondary precision holds up | `precision_secondary` (pre-registered form: unjudged count against) | >= 0.8 |
| 2 | Padding on plain events falls | share of single-domain control cells with a secondary domain outside `fair` | <= 0.10 |
| 3 | Width survives | median listed domains on the multi controls, form and content | >= 2 each |
| 4 | Recall survives | share of gold `required` domains listed | >= 0.85 |

Also reported: the fair share of judged secondaries (`precision_judged`), decoy hit rate, the 59-style unjudged list for v4 (`unjudged --version 4`).

ETA: judged when the lead has the two v4 answers files. If any of 1-4 still fails, the next step is an author decision, not a higher floor: the gold
set's unjudged domains may need judging (they are the likeliest cause of a low precision and of "padding" counted against the rule).
