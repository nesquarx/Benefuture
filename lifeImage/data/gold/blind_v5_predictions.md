# blind.v5 (LI.74): pre-registered predictions

Registered 2026-11-28, before any `blind.v5` answer exists. Rule under test: pass 1 `blind.v5` (`prompts/blind.v5.md`; v1 to v4 kept) changes only what the
`blind.v4` verdict named (`blind_v4_predictions.md`, "Pilot judged"): the commuter's form missed the actor's role and the purpose, its competence was coarser than
the author's fine skills, the rejected outcomes were judged partial 3 times of 4, and the overlap metric was defective. Kept from v4: event splitting, minimum
lengths, the zero-weight `unknown`, the outcome rule, the author baker and ticket examples, the held-out answers out of the prompt.
1. Form: the list names, besides the act at every level, the actor's role in the act (customer, patient, tenant, student) and the purpose (what the act is for by
   the convention of that kind of act, never the actor's private motive), where the statement implies them. Taught with a new event (a student sits a written exam:
   the examinee, earning a qualification). The validator makes it checkable: each event carries `layers` {role, purpose, sub_skill}, each the label of the
   matching list (role and purpose of the form list, two different labels) or `{"none": one-line reason}`.
2. Competence: the concrete sub-skills the act requires (perceiving, recognising, operating, navigating, reading, following a procedure) before the broader
   capabilities, at least one perceptual or procedural sub-skill when the act involves one; `layers.sub_skill` must sit in the first half of the competence list
   (`blind.v5.concrete_first_share`, 0.5, governed). Taught with a new event (a gardener prunes an apple tree).
3. Mode (LI.74): each event carries `mode` in {occurred, claim, plan, credential, role, self_assessment}, required by the validator; profile-like statements
   ("is a nurse", "holds a licence", "plans to study", "I'm good with numbers") are events with that mode. The pipeline function `two_pass.competence_basis(mode,
   validation)` returns `demonstrated` only for mode `occurred` with validation `formal` or `attested`, otherwise `predicted` (the agent marks the mode; the basis
   follows the record). Eight invented profile statements join the pilot controls (`data/gold/profile_statements_v0.jsonl`, `two_pass.profile_items`, two each
   of role, credential, plan, self-assessment; gold = the intended mode, never in a task).
4. Outcome: the contrast is named, with a new example (a shopper returns a faulty kettle): a sequel the statement does not state, and another entity's act, are both
   left out even when paraphrased (money back, the shop takes it in).
5. The competence/form overlap metric: `two_pass.blind_v5_report` always reports a number over events (the share with a competence label identical, normalised, to a
   form label), with the label-level shares and the near-copies (stemmed word sets, Jaccard >= 0.6; "use of public transport" against "using public transport") beside
   it. Not reproduced: the committed v4 report already holds 0.345 (not null) for this overlap; the cause of the null seen at judging is not established (the v4 function returns null only when there are no events), and the
   v4 measure missed near-copies, so the v5 report counts events and labels, identical and near, and is undecided (None) only when there are no events at all.
Pilot: the 32 membership calibration controls plus the 8 profile statements, 2 variants (`data/batches/blind.v5.controls.var{0,1}.part0.jsonl`, 40 tasks each, built by
`python3 lifeImage/tools/build_two_pass.py pilot --blind-version 5 --sets controls`, not run). Judging: `label_match.v1` unchanged; batches
`data/batches/label_match.v1.blind_v5.part*.jsonl` are built from the validated answers by `build_two_pass.py label_match --blind-version 5` (the development set,
the rejected outcomes as negatives, and any fresh items), so they wait for the answers; report `build_two_pass.py report_v5` (`two_pass.blind_v5_report`).

## Overfitting note (lead, 2026-11-28)
The commuter (cal.s08) and the ballot (cal.s04) have now guided three prompt revisions (v3, v4, v5): each verdict named what their author categories showed and the
next prompt answered it. They are a development set, no longer a clean held-out test: a pass on them measures that the revisions fixed the faults they exposed, not
that the rules generalise. They stay for continuity (comparison with v3 and v4). `label_match.HELD_OUT_FRESH` is the slot for the author's fresh categorisations
of items no revision has seen ({id: {"text", form, content, outcome, setting, competence}}, empty until the author provides them); `blind.v5` already routes them: a fresh
item joins the pilot controls, its labels are judged, and the report scores it apart (`heldout_fresh`, prediction 8 below). The next pilot is judged on unseen author
answers; until then a v5 pass on the development set is read as continuity evidence only.

| # | Prediction | Metric | Smallest effect that matters |
|---|------------|--------|------------------------------|
| 1 | The commuter's form finds the role and the purpose | cal.s08 form: share of the author's accepted labels a run's lists match, pooled over the two variants, `partial` 0.5 | >= 0.7 (v4: 0.583) |
| 2 | The commuter's competence is as fine as the author's | cal.s08 competence, the same measure | >= 0.5 (v4: 0.35) |
| 3 | The ballot keeps its match in every facet | cal.s04 form, content, outcome, setting, the same measure (guard against overcorrection) | all >= 0.6 (v4: 0.625 to 0.75) |
| 4 | The rejected outcomes are not produced, not even close | cal.s08 outcome, "arrival at work" and "passenger carried", 2 labels x 2 variants = 4 judgements; `match` and `partial` both count against the run | no more than 1 of 4 |
| 5 | The mode is marked correctly on the profile statements | the 8 profile statements x 2 variants = 16 answers; an answer is correct when every event carries the gold (intended) mode | >= 90% (15 of 16; 14 of 16 fails) |
| 6 | Competence is not a copy of form | share of events with a competence label identical (same normalised label) to a form label, over all 80 answers' events | <= 20% of events (v4: 34.5%) |
| 7 | The author's in-prompt examples stay faithful | author-label match share on cal.d01 and cal.d02, all facets pooled, `partial` 0.5 | >= 0.85 (v4: 0.922) |
| 8 | Fresh held-out items (when the author supplies them) | each fresh (item, facet) cell, the same measure | >= 0.6 in every cell; undecided while `HELD_OUT_FRESH` is empty |

Also read as guards (v4 predictions kept): the medians of real labels per facet at or above the minimums (form 5, content 4, setting 4, outcome 2, competence 3), the
maize control cal.m02 split into at least 2 events in both variants, `short_reason` on at most 15% of facets. Also reported, no prediction attached: the strict (`match` only)
shares; the near-copy and label-level overlap shares; the layers declared `none` (`layers_none`: how often the agents decline a role, a purpose or a sub-skill); the modes
marked on the 32 controls (`mode_counts_other_items`); which author commuter labels were missed (role, purpose, each competence); the rejected outcomes' verdict per variant.

Confidence 0.5 for the set (the lines are separate claims and the set can fail in parts; lines 1 and 2 are the least certain, as v4 moved the commuter form by
-0.02 against a rule that already named the role and the purpose).

Stated before measuring:
- Lines 1 and 2 compare with the v4 runs on the same two items; the v5 form gain rests on the `layers` declaration, which makes a missing role or purpose a visible, validated act;
  the metric cannot tell whether the agents' role label matches the author's word ("passenger" against "rider"), so the judge's `partial` carries it.
- A rejected outcome is counted when the judge says `match` or `partial` (v4 counted `match` only and read 3 of 4 `partial` as close paraphrases): the line is stricter than v4's.
- Line 5 is judged on 16 answers: one error passes, two fail. The gold mode is the author's intended reading of an invented statement, not a measured fact; a disagreement
  about a statement is read, not counted as the agent's fault, when it names a defensible alternative (a role read as a credential).
- Line 6 uses the identical-label share, as pre-registered in v4; the near-copies are reported because a metric that counts only exact repeats can pass while competence copies form.
- A pass inside 0.05 of a threshold is read as unresolved. One re-run on a changed prompt before any adoption; the prompt version is recorded with every result.

Reading and adaptation (decision rule, before the numbers): if 1 fails with 3 holding, read which of the author's commuter form labels are missed (passenger, preparation for
work, regular activity) and whether `layers.role` was `{"none": ...}`; a high none-rate means the prompt's role rule is too soft, a low one with a miss means the labels are the wrong
words (a lexical gap the judge's `partial` records). If 2 fails, read whether `layers.sub_skill` was declared and which author skills are absent (recognising, getting on and off,
navigating, reading signs) before adding another new-event example, never a lexical rule. If 4 fails, the contrast example did not generalise: read the labels judged. If 5
fails, read the modes marked against the gold per mode type (role against credential is the likeliest confusion). If 3 fails while 1 and 2 pass, the longer role and purpose
lists pad the ballot. ETA: minutes of runner time for 80 answers and about 146 judgements; judged by the lead on the first complete set.
