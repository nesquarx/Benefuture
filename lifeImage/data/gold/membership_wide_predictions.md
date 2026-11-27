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

## Support-weighted union merge (pre-registered 2026-11-27, before any re-score; LI.67 widening, LI.68 logging; confidence 0.5)

Context (lead): with the intersection merge (a domain kept only if every variant lists it) the widening is lost. v4 calibration answers list 2 to 3
domains per relation, the merged kinds (83) and snippets (200) have a median of 1 per relation, 42 of 83 and 116 of 200 items are escalated, and the
field-pair coverage is 0.31% (kinds), 0.55% (snippets), 0.655% (both, 199 of 30,381 pairs).

Rule under test (`merge_item(..., rule="support_union")`; the old rule stays as `rule="intersection"`): every domain any variant lists is a candidate;
its merged weight is the mean over the variants (0 where unlisted), renormalised per relation; each kept domain carries `support` (share of variants
listing it) and the row a confidence (mean agreement over its relations). A domain listed by one variant only (with more than one variant) whose mean
weight is below the governed `membership.single_support_floor` (0.2, `lifeimage/governed.py`; chosen from the calibration data, source stated there)
is not kept: it goes to the refinement log with source `disputed`. A relation never empties (the best domain by mean weight is kept). Escalation stays
for a differing primary domain, agreement below `membership.agree_floor` and a relation applying in some variants only; it no longer empties lists.
The calibration judge scores the merged list as one answer (`merged_calibration_report`), against gold v1 (`complete_gold`), v4 answers.

| # | Prediction | Metric | Smallest effect that matters |
|---|------------|--------|------------------------------|
| 1 | Recall survives the merge | merged recall of the gold `required` domains, 27 cells | >= 0.96 (v4 per variant 0.963) |
| 2 | Secondary precision holds | `precision_secondary` (unjudged and unsure count against), merged lists, gold v1 | >= 0.80 |
| 3 | Padding is bounded | `padding_single_complete` (a secondary the gold calls bad or unsure) on single-domain controls, merged lists | <= 0.35 |
| 4 | The kind and snippet memberships widen | median listed domains per relation over non-null cells, kinds and snippets, form and content | >= 2 each, in both sets |
| 5 | Pair coverage widens | share of the 30,381 field pairs inside one row's memberships, kinds and snippets together | >= 3x the intersection figure (0.655%, 199 pairs), so >= 597 pairs |

Also reported, no prediction attached: escalated items (kinds 42 of 83, snippets 116 of 200 under the intersection), the number of single-variant
domains dropped to the log, the intersection merge's own recall, precision and padding on the same answers (the baseline), mean domains per cell.
Out-of-sample note: the floor was set on the calibration answers, so 1 to 3 on the controls are in-sample for that one number (recall is not
touched by it); 4 and 5 on kinds and snippets are the out-of-sample test. ETA: judged in this session from the existing answers, no runner needed.
Decision if 4 or 5 fail: the floor is the suspect (lower it, the log of dropped domains shows the cost) before any other change; if 2 or 3 fail,
the floor rises or the dropped domains of the log are reviewed; the merge is one rule among the options, so the pre-registered fallback is the
fine-grid floor between 0.1 and 0.2 that holds precision, reported with the sweep.

## Support-weighted union merge judged (2026-11-27)
Floor 0.2 (`membership.single_support_floor`), v4 answers, gold v1 (`data/gold/membership_wide_merged_support_union_v4_gold_v1.json`; the intersection
baseline beside it, `..._intersection_...`). Kinds and snippets re-ingested with the new rule.

| # | Prediction | Result | Verdict |
|---|------------|--------|---------|
| 1 | merged recall >= 0.96 | 0.963 (26 of 27; the intersection merge also 0.963 on these answers) | **met** |
| 2 | `precision_secondary` >= 0.80 | 0.881 (intersection 0.908) | **met** |
| 3 | `padding_single_complete` <= 0.35 | 0.138 (intersection 0.103) | **met** |
| 4 | median listed >= 2, form and content, kinds and snippets | kinds 2 and 2, snippets 2 and 2 (intersection: 1 everywhere); mean per non-null cell 1.81 (1.47) | **met** |
| 5 | pair coverage of kinds+snippets >= 3x 0.655% (>= 597 pairs) | 284 pairs, 0.93% (1.43x) | **failed** |

Escalated items unchanged (kinds 42 of 83, snippets 116 of 200): the escalation reasons are the same, only the lists no longer empty. Single-variant
domains dropped to the refinement log (`disputed`): 31 in kinds, 156 in snippets.

Floor sweep (pre-registered fallback), same answers, controls with gold v1 and kinds+snippets together:

| floor | recall | precision_secondary | padding (complete) | pairs | share of pairs | mean listed per cell |
|---|---|---|---|---|---|---|
| intersection | 0.963 | 0.908 | 0.103 | 199 | 0.66% | 1.47 |
| 0.20 (governed) | 0.963 | 0.881 | 0.138 | 284 | 0.93% | 1.81 |
| 0.15 | 0.963 | 0.808 | 0.310 | 328 | 1.08% | 1.94 |
| 0.10 | 0.963 | 0.780 | 0.414 | 367 | 1.21% | 2.03 |
| 0.00 (pure union) | 0.963 | 0.788 | 0.414 | 369 | 1.21% | 2.03 |

Reading: prediction 5 fails at the ceiling, not at the floor: even the pure union of the two variants reaches 369 pairs (1.85x), because each
variant lists about two domains per relation and the variants mostly list the same ones. Lowering the floor below 0.2 buys 44 to 85 pairs and costs
precision (0.78 to 0.81 at 0.15 and below, under the 0.80 target at 0.10) and padding (0.31 to 0.41); the governed 0.2 is the widest floor
that meets 1 to 3 with margin, and 0.15 meets them narrowly. Pair coverage of 3x needs more listed domains per event (more variants, or
a wider prompt), not a different merge; recorded for the lead's decision. Confidence in these figures: recall rests on 27 cells (one cell 0.037), the
floor was tuned on the same controls (4 on kinds and snippets is the out-of-sample result and holds).
