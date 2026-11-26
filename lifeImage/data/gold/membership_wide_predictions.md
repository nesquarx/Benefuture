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
