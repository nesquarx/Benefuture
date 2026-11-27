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

## v4 judged (lead, 2026-11-26)
Floor 5. Median listed: all 2/2/2/2 (form, content, outcome, setting); multi form 3, content 3 (prediction met). Precision of
secondary domains, pre-registered metric (unjudged count against): 0.713 (< 0.8, **failed**); among judged secondaries 0.980
(3 bad, 55 unjudged). Padding on single-domain controls 0.448 (> 0.10, **failed**). Recall of required 0.963 (>= 0.85, met).
Decoy hit rate 0.000 (v3 0.0625). Against v3 the floor halved the bad domains (6 -> 3), removed decoy hits and raised recall,
but barely moved the pre-registered metrics: what fails them is the unjudged set (55) and secondary domains on single-domain
controls that the gold calls neither fair nor bad. By the pre-registered rule, the next step is the author's decision; the
lead's reading is that the gold set is incomplete, not the floor too low (raising it further would narrow memberships against
LI.67). Per LI.68 the unjudged domains are refinement candidates.

## Gold completion and v3/v4 re-score (pre-registered 2026-11-27, before any gold-judge answer exists; LI.69; confidence 0.5)

Rule under test: the unjudged (item, relation, domain) triples of the v3 and v4 calibration (deduplicated) are judged by runners (task `gold_judge.v1`,
2 variants with the gold's fair and bad lists in opposite order). Agreed verdicts (`fair` or `bad` from both variants) extend the gold as
`data/gold/membership_wide_controls_v1.jsonl` (v0 kept; provenance per added entry); a disagreement or any `unsure` goes to the author review file
`data/gold/membership_wide_disputed_v1.md` and stays out of v1 (recorded there as `unsure`) until reviewed. The existing answers are then re-judged
against v1: `judge --version 3|4 --gold v1`, reports `membership_wide_calibration_report_v{3,4}_gold_v1.json`.

Definition change, explicit: with the completed gold, padding on single-domain controls counts a cell only if it lists a secondary domain that the gold
calls `bad` or `unsure` (`padding_single_complete`); a domain the gold judged `fair` no longer counts, and a domain nobody has judged is not counted but
reported (`n_unjudged`). The old definition (secondary domain outside `fair`, unjudged counted) is still computed and reported as `padding_single`.
The pre-registered precision metric (unjudged and unsure count against) and the judged-only metric are both kept.

| # | Prediction (v1 gold) | Metric | Smallest effect that matters |
|---|----------------------|--------|------------------------------|
| 1 | v4 precision holds with the complete gold | `precision_secondary` (pre-registered form) on v4 | >= 0.8 |
| 2 | v4 padding on plain events falls | `padding_single_complete` on v4 | <= 0.25 |
| 3 | v3 is worse than v4 | v3 `precision_secondary` < v4's, and v3 `padding_single_complete` > v4's | both directions |

ETA: judged when the lead has the four gold-judge answers files. Decision if 1 or 2 fails: the floor is not raised on this evidence alone; the remaining
`bad` and `unsure` additions are the refinement candidates (LI.68) and the rubric text is the suspect. If 3 fails, the floor change from 4 to 5 bought nothing
on the complete gold and is reconsidered by the author.

## Gold completion judged (lead, 2026-11-27)
`gold_judge.v1`: 71 unjudged (item, relation, domain) triples, 2 variants; agreed verdicts extend the gold as
`membership_wide_controls_v1.jsonl`; 20 disputed (variants differ or unsure) await the author in
`membership_wide_disputed_v1.md`, counted as unsure meanwhile. Re-scored against v1 gold:
v4: precision (pre-registered metric) 0.817 (>= 0.8, **met**); padding on single-domain controls, complete definition (gold-bad
or unsure) 0.293 (<= 0.25, **failed**, narrowly; the 20 disputes count as unsure here); recall 0.963; judged bad 21; decoy hits
0.094. v3: precision 0.777, padding 0.431, recall 0.926, bad 26, decoy hits 0.125. v3 worse than v4 on both (**met**). The
completed gold found more bad secondaries than the v0 gold implied (v4: 3 -> 21), so precision among judged fell to 0.887; the
pre-registered metric rose because nothing is unjudged now. The padding verdict may change once the author rules on the 20
disputes; it is not re-judged until then.
