# blind.v4 (LI.73): pre-registered predictions

Registered 2026-11-28, before any `blind.v4` answer exists. Rule under test: pass 1 `blind.v4` (`prompts/blind.v4.md`; v1 to v3 kept) changes only what the
`blind.v3` verdict named (`blind_v3_predictions.md`, "Pilot judged": v3 overcorrected). Kept from v3: event splitting, actor perspective, sense glosses, the
LI.65 relational block, the author's baker and ticket examples, the held-out commuter, ballot and maize answers out of the prompt. Changed:
1. Minimum list lengths enforced by the validator (`validate.py` version 4): form >= 5, setting >= 4, content >= 4, outcome >= 2 real labels (`unknown` is none),
   at most 10; fewer only with an explicit per-facet `short_reason` (an optional object on the event, naming only a facet that is short); the setting may be
   null only with a `short_reason`, as the outcome may.
2. Outcome: what the event itself makes true for the actor (a state change that holds by the event's occurrence), excluding likely-but-unstated sequels and
   other entities' acts; taught with a contrast example from a new event ("a man posts a letter at the post office": letter posted, postage paid, money spent
   in; letter delivered and mail sorted out).
3. `unknown` is a zero-weight terminator (weight exactly 0, last, at most one, no label, no part of the minimum); the real labels sum to 1; the setting runs
   concrete to generic as far as the statement and ordinary inference about the stated act allow before `unknown` (the prompt's illustration is a ferry, not
   the held-out bus).
4. Content: the activity itself first, then the objects and interactions.
Pilot: the 32 membership calibration controls, 2 variants (`data/batches/blind.v4.controls.var{0,1}.part0.jsonl`, built by
`python3 lifeImage/tools/build_two_pass.py pilot --blind-version 4 --sets controls`, not run). Judging: `label_match.v1` unchanged, batches
`data/batches/label_match.v1.blind_v4.part*.jsonl` built from the validated answers by `build_two_pass.py label_match --blind-version 4` (132 tasks, 3 parts),
with the author's held-out labels (`label_match.HELD_OUT`: the commuter's accepted outcomes "journey made" and "time spent travelling" now included) and the
rejected outcomes "arrival at work" and "passenger carried" as negatives; report `build_two_pass.py report_v4` (`two_pass.blind_v4_report`). The commuter and
ballot categorisations are in no prompt, so a match measures generalisation, not use of an example. Confidence 0.55 for the set; each line is a separate claim and the
set can fail in parts.

| # | Prediction | Metric | Smallest effect that matters |
|---|------------|--------|------------------------------|
| 1 | The runs generalise to the author's held-out categories, in every facet, for both items | per (item, facet) cell of cal.s08 (commuter) and cal.s04 (ballot), the share of the author's accepted labels a run's lists match in the same sense, pooled over the two variants, `partial` counting 0.5; eight cells (form, content, outcome, setting of each) | >= 0.6 in every cell, for BOTH cal.s08 and cal.s04 |
| 2 | No rejected outcome is produced | on cal.s08, `match` verdicts of "arrival at work" and "passenger carried" over the two variants (a `partial` is reported, not counted; the judge is not told these are negative) | 0 matches in either variant |
| 3 | A compound statement is split | events in the answers to the maize control cal.m02 | >= 2 events in both variants |
| 4 | The lists are as long as the minimums | median number of real labels per facet over all events of the 64 answers | form >= 5, setting >= 4, content >= 4, outcome >= 2 (all four) |
| 5 | The author's in-prompt examples stay faithful | author-label match share on cal.d01 and cal.d02 (29 labels), all facets pooled, `partial` 0.5 | >= 0.8 |
| 6 | The minimums are met by the statements, not waived | share of facets (events times four) carrying a `short_reason` | <= 15% |

Also reported, no prediction attached: strict (`match` only) shares per cell; the medians of every facet; events per answer for every control; the facets
where the validator first rejected an answer; the `partial` verdicts on the negative labels; the share of null outcomes and null settings; the share of
setting lists ending in `unknown`; the weight shape (share of the first label) and the equal-step ladders (share of eligible lists, as in v3); the
labels of cal.s08 content the run missed (the v3 content failure was objects only: "journey" and "bus ride" absent).

Stated before measuring:
- Prediction 4 is partly structural: the validator enforces the minimums, so a validated answer meets them unless it carries a `short_reason`; the claim is
  that the medians hold after the validator, with prediction 6 bounding how often the way out is used. If runners resubmit under rejection the rejection
  rate, not the median, is the signal of the prompt's strength; both are reported.
- Prediction 1 includes the cells v3 failed: commuter form 0.61, content 0.375, setting 0.33 and, with the accepted outcomes added, outcome (v3: 0.00).
  The ballot passed in v3 (0.625 to 0.75) and is the guard against overcorrection in the other direction (a longer list padding with labels that miss).
- The judge sees the whole run for a facet (all events' lists in order), so a split answer is compared with the author's single list; splitting the
  commuter or ballot would spread labels and may lower the match (a finding on the splitting rule, as in v3).
- Predictions 2 and 3 are structural to a single run and have no sampling error beyond the two variants; "0 of 2" is weak evidence of absence and "both
  variants split" is the claim, not a rate. Predictions 1, 4, 5, 6 are medians and shares over 64 answers or 29 to 70 labels with sampling error not
  estimated here; a pass inside 0.05 of a threshold is read as unresolved, not as met.
- The `unknown` zero weight is a contract change: pass 2 (`map.v2`) reads `blind` labels and fit; `unknown` was never a category there, so its weight
  carries no downstream effect, but the adaptation of map.v2 to events and weights still waits for a green pilot.

Reading and adaptation (decision rule, before the numbers): if 1 fails on one item only with 4 holding, read the unmatched author labels per cell
(commuter's regularity and purpose levels; the setting's concrete levels) before changing wording; if 1 fails on outcome with 2 holding, the
"event itself makes true" rule is too narrow or too wide: read which accepted outcome ("journey made", "time spent travelling", "vote cast", "turnout
counted") is missing and add a second contrast example, never a lexical rule. If 2 fails, the outcome rule lets sequels or other entities' acts through:
sharpen the contrast. If 6 fails (many `short_reason`), the minimums ask for padding: read the reasons given before relaxing a minimum. If 5 fails, the
longer lists crowd out the examples. One re-run on a changed prompt before any adoption; the prompt version is recorded with every result. ETA: minutes of
runner time for 64 answers and 132 judgements; judged by the lead on the first complete set.
