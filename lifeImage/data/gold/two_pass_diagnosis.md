# Two-pass recall loss: diagnosis (LI.70 pilot, controls)

Read-only analysis of the existing pilot answers (no batches run, no prompt or code changed): `lifeimage/two_pass_diag.py` (tested by
`tests/test_two_pass_diag.py`). Items: the 32 controls; gold: `membership_wide_controls_v1.jsonl` (its `required` equals v0's: 12 controls,
27 (item, relation, domain) cells, 54 per-variant cells). Answers: `blind.v1.controls.*` and `map.v1.controls.*`; one-pass comparison
`membership.A3S.v4.calibration.*`. The class of each cell is a word-overlap heuristic first (`classify_miss`), then audited by eye against the
labels (the listing below); the audited class is the one reported. Confidence in the audit about 0.8: the sample is 27 cells, so every share
here is a pilot figure (one cell is 0.037 of recall, one variant-cell 0.019).

## 1. What the 0.630 is
The pilot judge scores each variant's own list, not the merged one. Both variants have recall 17/27 = 0.630. The shipped intersection merge is
lower still, 13/27 = 0.481. So the headline loss is mostly inside each variant, not in the merge: the variants' lists are short and mostly
wrong in the same cells. One-pass v4: 26/27 = 0.963 per variant and merged.

| Rule over the same two-pass answers | Recall of required (27 cells) | Precision of judged secondaries | Mean domains listed per relation cell |
|---|---|---|---|
| Variant 0 alone | 0.630 (17) | | |
| Variant 1 alone | 0.630 (17) | | |
| Intersection (shipped) | 0.481 (13) | 1.000 | 0.96 |
| Union | 0.778 (21) | 0.887 | 2.37 |
| Weighted: mean weight (absent = 0) >= 0.385 (median weight of a fit-5 entry) | 0.444 (12) | 1.000 | 1.05 |
| Weighted at half that threshold (a lone variant listing at twice the floor weight keeps it) | 0.741 (20) | 0.919 | 2.17 |
| v4 one pass (intersection = union = either variant) | 0.963 (26) | 0.952 (intersection), 0.871 (union) | 1.81 |

The union is the ceiling of any merge of these two variants: 6 required cells (22%) are in neither list, and union precision (0.887) already
falls below the 0.95 target. No merge rule alone reaches 0.913.

## 2. Classification of the losses
Per variant (20 missed variant-cells of 54; heuristic class in brackets; M does not apply per variant):

| Class | Audited | Heuristic | Meaning |
|---|---|---|---|
| P1 no blind label could map | 4 | 7 | pass 1 never named it |
| P2a label exists, mapped to another domain | 10 | 5 | mapper chose a different domain |
| P2b mapped to it, not listed (floor or stopping rule) | 0 | 0 | |
| P2c mapped-and-listed label marked noise/candidate | 0 | 0 | |
| V mapped to it only under another relation | 6 | 8 | cannot be listed (anchoring is per relation) |

Per cell, after the intersection merge (14 missed of 27; the class is the stage of the variant closest to success):

| Class | Audited | Heuristic |
|---|---|---|
| M listed by one variant only | 8 | 8 |
| P2a | 4 | 2 |
| V | 2 | 3 |
| P1 | 0 | 1 |
| P2b, P2c | 0 | 0 |

Heuristic-versus-audit differences: the word overlap missed paraphrases (`nursing` names healthcare work, `wedding` names marriage), so P1
shrinks and P2a grows.

Examples:
- P2a, fine child preferred over the required coarse domain: `cal.m01` form `c.healthcare_work`, labels `night shift nursing` and `nursing
  care` were mapped to `f.midwifery_nursing_professional` (child of the required domain), in both variants; `cal.m07` same; `cal.m10`
  `wedding` mapped to `f.wedding` (child of `c.marriage_wedding`); `cal.m05` `drought` to `f.drought` (child of
  `c.weather_climate_adaptation`). Credit for a listed fine child lifts per-variant recall 0.630 to 0.741 (`recall_child_credit`).
- P2a, near-duplicate domain: `cal.m01` content `c.pregnancy_birth`: labels `maternity care`, `childbirth` mapped to `c.birth_of_child` and
  `f.childbirth`; `cal.m12` `diabetes` mapped to `c.serious_illness`, required `c.physical_health`.
- P2a, label too specific: `cal.m02` `produce sold for income` mapped to `f.promoting_purchasing_selling`, required `c.income_earning`.
- V (relation): `cal.m08` `home cooking` and `cooking supper` sit under form, the gold requires `c.cooking` under content, where the blind labels
  were `childcare`, `family meal`; `cal.m11` `loan repayment` under form and outcome, required `c.borrowing_debt` under content.
- P1: `cal.m04` v1 (`employment abroad`, `language learning`: no migration label), `cal.m06` v1 (`road clearance`, `storm damage` for
  `c.neighbours_community` and `c.mutual_aid`), `cal.m02` v0 (`maize`, `agricultural produce`: no income label).
- M: `cal.m04` `c.migration` (v0 has `migration`, v1 does not), `cal.m05` both `c.horticulture_farming` and `c.weather_climate_adaptation`
  (each variant has one), `cal.m11` `c.borrowing_debt`, `cal.m12` `c.physical_health`.

Mechanisms behind the classes: pass 2 maps each label to exactly one domain and is told to prefer the fine one, and to list a domain once;
v4 lists the coarse and the fine domains side by side. Memberships may use only domains some label of the same relation matched, so a label
the blind pass filed under another relation cannot supply it. Blind labels differ between variants (mean Jaccard of the two-pass domain lists
0.42, v4 0.64).

## 3. Escalation causes (controls, 28 of 32 escalated; 70 of 82 with snippets; v4 escalates 21 of 32)
Counts of items per cause (an item can have several): primary domains differ 23; agreement below the governed 0.5 floor 19; no domain listed by
every variant (in some relation) 16; relation applies in one variant only 16; blind labels apply in one variant only 6. The shared cause is
that two short lists built from different labels rarely overlap: the escalation is the symptom of the short per-variant lists, and v4's
longer lists escalate less (21 of 32) while sharing the same rule.

## 4. Against v4: what v4 finds that two-pass misses
Of the 14 cells the merged two-pass misses, v4 finds 13 (the one it also misses is `c.income_earning`, `cal.m02`). In 9 of those 13 it is the
primary at fit 9 (healthcare_work x2, pregnancy_birth, migration, weather_climate_adaptation, mutual_aid, marriage_wedding, borrowing_debt,
physical_health); the other four are secondaries at fit 5 to 8 (`c.medical_care`, `c.horticulture_farming`, `c.neighbours_community`,
`c.cooking`). Would a blind labeller name them? Judged by the labels: yes for 9 (the labels named it or its fine child: `nursing`, `childbirth`,
`drought`, `wedding`, `diabetes`, `migration` in one variant, `business finance`), partly for 2 (`neighbourly help`, `debris clearing` for
`mutual_aid` and `neighbours_community`), no for 2 (`c.income_earning` and `c.cooking` as a content domain where the blind pass filed cooking under
form). The obvious primaries are mostly named, then lost in pass 2.

## 5. Recommendation: hybrid (pass 2 may add what pass 1 missed, and may list the coarse parent)
Evidence: of the 20 per-variant losses, 16 (80%) occur after a blind label existed (P2a 10, V 6) and only 4 (20%) are pass-1 gaps; a merge
change cannot recover more than 0.778 (union) at precision 0.887. Combining the two cheap repairs measured here, union plus credit for a fine
child, gives 0.852, still below 0.913. So the fix must be in pass 2's allocation, not the merge:

1. Pass 2 builds memberships by the v4 rule from the event text with the blind labels as hints and anchors, not as the only source: it may list
   an obvious domain no label named (answers the P1 cases and the V cases) and a label may match several domains (a fine domain and its coarse
   parent; answers the P2a cases). Pass 1 keeps its other jobs: synonyms (488) and new-domain candidates (4 to 5).
2. Keep the intersection merge and the escalation as in v4 (no merge change first; merge variants are then as stable as v4's).
3. Do not add labels or a relation checklist to pass 1 first: it addresses 4 of 20 losses; and it would not touch the 16.

Pre-registered prediction for the hybrid (confidence 0.55; to be recorded before re-scoring): per-variant recall of required >= 0.913 (v4 0.963
minus 0.05; the 0.925 to 0.963 range expected, since the hybrid is v4 plus hints), judged-secondary precision >= 0.95, escalated controls <= 24
of 32 (v4 21), distinct synonyms >= 10 and new-domain candidates >= 3 retained (pass 1 unchanged). If recall fails, the next steps in order are the
union merge (ceiling shown above) and a wider pass 1; none changes the mapper's one-label-one-domain rule, so re-score that rule first.
A cheaper test of the mechanism alone: re-run only pass 2 (same pass-1 answers) with the parent-listing rule, predicted per-variant recall
0.74 (from child credit, confidence 0.6), which isolates P2a from P1 and V.

Caveats: 27 required cells in 12 controls; the audited classes are one reader's judgement, the heuristic classes are mechanical; the gold's
`required` names specific coarse domain ids where the pack has near-duplicates (`c.birth_of_child` against `c.pregnancy_birth`), so part of
the P2a share is gold strictness, not an error (the child credit measures the hierarchical part only); disputed gold items (20 to the author)
do not touch `required`.
