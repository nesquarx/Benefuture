# blind.v3 (LI.71, LI.72): pre-registered predictions

Registered 2026-11-28, before any `blind.v3` answer exists. Rule under test: pass 1 `blind.v3` (`prompts/blind.v3.md`; v1 and v2 kept): the answer holds a
list of events (a compound statement is split first, each event with its own facets and relational block, linked by `part_of`, `causes`, `concurrent`);
form names the act at every level (the act, the actor's role, the purpose, the regularity), most specific first; content names the doing and what it
involves; outcome only the actor's state changes the statement supports (another entity's act is that entity's event; an unstated result is left out);
setting runs concrete to generic and stops where the statement stops (`unknown` beyond); lists as long as the event supports (up to 10), each label more
generic than the one before; weights reflect centrality, no fixed ladder. Validator: `validate_blind_answer(..., version=3)` (events >= 1, per facet weights
decreasing and summing to 1, glosses, no domain ids; an equal-step ladder is flagged by `validate.equal_step_ladders`, not rejected).
Pilot: the 32 membership calibration controls, 2 variants (`data/batches/blind.v3.controls.var{0,1}.part0.jsonl`, built by
`python3 lifeImage/tools/build_two_pass.py pilot --blind-version 3 --sets controls`, not run). Judging: `label_match.v1` unchanged
(`prompts/label_match.v1.md`), batches `data/batches/label_match.v1.blind_v3.part*.jsonl` built from the validated answers by
`build_two_pass.py label_match --blind-version 3` (132 tasks, 3 parts); report `build_two_pass.py report_v3` (`two_pass.blind_v3_report`). The v3 lessons
come from the author's categorisations held out of the prompts (LI.72); the commuter and ballot categorisations are in no prompt, so a match on them measures
generalisation of the rules, not use of an example. Confidence 0.5 for the set; each line is a separate claim and the set can fail in parts.

| # | Prediction | Metric | Smallest effect that matters |
|---|------------|--------|------------------------------|
| 1 | The runs generalise to the author's held-out categories | for each (item, facet) cell of cal.s08 (commuter) and cal.s04 (ballot) that has accepted author labels, the share of those labels a run's lists match in the same sense, pooled over the two variants, `partial` counting 0.5 (`label_match.HELD_OUT`) | >= 0.6 in every cell (seven cells: s08 form, content, setting; s04 form, content, outcome, setting) |
| 2 | The author's rejected outcomes are not produced | on cal.s08, the `match` verdicts of the two negative labels, "arrival at work" and "passenger carried", over the two variants (a `partial` is reported, not counted; the judge is not told these are negative) | 0 matches in either variant |
| 3 | A compound statement is split | the number of events in the answers to the maize control cal.m02 ("grows maize and sells the surplus at the weekly market") | >= 2 events in both variants |
| 4 | The form lists are long | median number of form categories per event (`unknown` excluded) over all events of the 64 answers | >= 5 |
| 5 | The weights are not a formula | the share of facets (non-null lists, over all events) whose weights fall in exactly equal steps at two decimals, lists of >= 3 entries only being flaggable | <= 25% |
| 6 | The in-prompt examples stay faithful | author-label match share on cal.d01 and cal.d02 (the LI.71 examples, 29 labels), all facets, pooled, `partial` 0.5 | >= 0.8 |

Also reported, no prediction attached: strict (`match` only) shares per cell, the median of content, outcome and setting categories, the events per answer
for every control, the lists under 4 categories, the facets whose list is `unknown` alone, the share of answers with a null outcome, the validator's
rejections on first writing, the `partial` verdicts on the negative labels, and the shape of the weights (share of the first label).

Stated before measuring:
- Prediction 1 has a gap: LI.72 records no accepted outcome for the commuter (only the two rejected ones), so cal.s08 outcome has no accepted labels and is
  judged by prediction 2 alone. The cell count above (seven) reflects that. An open request to the author: the commuter's accepted outcome labels.
- cal.d01 and cal.d02 are the LI.71 examples in the prompt: prediction 6 tests faithfulness (the same confound as `blind_v2_predictions.md`), and is
  expected to hold; the v2 value was 0.96 / 0.71 per facet. A fall below 0.8 would show the new rules (splitting, outcome restraint, `unknown`) crowd out the
  examples.
- The judge `label_match.v1` sees the whole run for a facet (the events' lists in order), so a split answer is compared with the author's single list.
  Splitting a statement the author categorised as one event (the commuter, the ballot) would spread labels across events and may lower the match; that is a
  finding on the splitting rule (too eager), recorded as such.
- Predictions 2 and 3 are structural to a single run and have no sampling error beyond the two variants; with 2 variants, "0 of 2" is weak evidence of
  absence, and "both variants split" is the claim, not a rate. Predictions 1, 4, 5 and 6 are medians and shares over 64 answers or 29 to 70 labels, and
  carry sampling error not estimated here; a pass inside 0.05 of a threshold is read as unresolved, not as met.

Reading and adaptation (decision rule, before the numbers): if 3 fails, the splitting instruction is too weak or its example too narrow: strengthen Step 1
in `blind.v4` with a second worked split, never by a lexical rule in the validator. If 2 fails, the outcome rule is not holding (the run names a result the
statement does not state, or a vehicle's act): sharpen the outcome paragraph with a negative example. If 1 fails with 6 holding, the rules are read but the
categories differ from the author's: read the unmatched author labels per cell (commuting's regularity and purpose levels, the setting's concrete
levels) before changing wording. If 5 fails, the weights instruction is ignored: ask for weights as shares of a stated total, or accept the weights as
a formula and drop them as a signal. If 4 fails, the form instruction does not push to role, purpose and regularity. One re-run on a changed prompt before
any adoption; the prompt version is recorded with every result. ETA: minutes of runner time for 64 answers and 132 judgements; judged by the lead on
the first complete set. Pass 2 (`map.v2`) reads `blind` and `fit`; its adaptation to events, weights and glosses waits for this pilot.
