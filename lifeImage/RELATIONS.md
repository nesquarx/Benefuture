# Life Image: relation types (working analysis)

All `[P]`. Three layers: A, how an event belongs to a domain (membership, L22 with a partition of unity per relation
type, 8.156); B, how an entity is involved in an event; C, how domains relate. Each type is a hypothesis with a
falsification condition; every counterexample becomes a permanent regression test, absorbed or forcing a change.
Stress set: `data/gold/coverage_events_v0.jsonl` and `data/gold/relation_redteam_v0.jsonl` (93 red-team cases).

## Verification criteria

1. Complete: "other" or forced choices below a threshold on the stress set.
2. Meaningful: agreement per type across variants (Krippendorff's α), sparse confusions, agreement with the author's
   reviewed labels.
3. Useful: ablating a type (merging it into its nearest) degrades a consumer (image projection, currency routing,
   reputation, metric-model selection); otherwise it goes.
4. Parsimonious: no type definable from others; a type stays only if it shortens the total description (MDL).
5. Not gameable: no type raises reputation or currency without measured value. Relations route value; they never
   mint it.
6. Comparative: competing vocabularies (8.156, act/content/purpose, OBO Relation Ontology, ConceptNet, SKOS) are
   scored on the same battery.

## Layer A battery (no model run yet)

Candidate membership vocabularies on the same items (151 coverage events plus the layer-A red-team cases):
A4 (form, material, outcome, reference), A6 (A4 plus mechanism, normative), R156 (causal, structural,
communicative) and ACP (act, content, purpose). Vocabularies and builder: `lifeimage/membership.py`; batches
`data/batches/membership.<VOCAB>.v1.var{0,1,2}.jsonl` from `tools/build_membership_batches.py`; scoring with
`tools/membership_metrics.py` (other and forced rates, applicability, alpha and Jaccard per type, type swaps,
red-team other share). The pack is listed ungrouped so no guessed sector hints at an answer.

## Triage of counterexamples

| Case | Layer | Finding | Disposition |
|---|---|---|---|
| Failed treatment (aim health, result harm) | A | Purpose is a belief; outputs only | Outcome means what observably changes; a stated intent is a communicative output (reference) |
| Theft by hacking | A | Mechanism or second form? | Test: form takes several memberships; mechanism may be redundant |
| Prescription under medical law | A | Regulation per event | Derived from the form domain's normative links (C); an event's own contract is a row field |
| Reading a paper | A | Material and reference blur for informational acts | Material is the carrier (the paper, the film); reference is its subject |
| Conference dinner (food, networking, work) | A | Sum to 1 makes coexisting effects zero-sum | Membership is per outcome: each distinct outcome has its own partition; within one value unit, sharing prevents double counting |
| Surgery vs assault | B | Same contribution, impact and informedness, opposite meaning | Row field: under agreement (consent as contract) |
| Coercion | B | Freedom absent | Add volition, which Benefuture already uses (Crime: informed volition) |
| CEO signs for the company | B | Acting on behalf of | Row field: acting for (liability chain, L121) |
| Lifeguard does nothing | B | Omission | Counterfactual contribution with duty (L96); the omission is a row |
| Five sufficient shooters | B | Overdetermination with contribution in [0, 1] | Shapley-style attribution (Benefuture's sampled attribution) gives each a share |
| Medicine → illness | C | Addressing a problem | Signed causal link |
| Fluid dynamics ↔ traffic flow | C | Shared structure, no shared events | Add analogous (shared models); consumer: metric-model reuse, provisional until proven |
| Alchemy → chemistry | C | Identity drift | Release migration tables carry successors; a historical lineage link if a consumer needs it |
| Education supplies workers | C | Beings are not materials | Signed causal (capability), not supply |
| Health vs illness | C | Opposition | No consumer yet; kept as a regression case |
| Same act, different cultures | A | Classification depends on context | Rows carry context; each entity classifies on its own view (8.50) |
| Spam reviews, self-citation rings, staged volunteering photos | A | Reference is cheap | Route, never mint; value measured by metric models; Sybils by identity binding |

## Current candidate

- A: form, material (carrier or input), outcome (observed output), reference (subject); mechanism and normative
  (laws, contracts, norms) under test as derivable.
- B: causal contribution (Shapley-style), signed impact, informedness, volition; row fields acting for and under
  agreement.
- C, recorded: directed co-membership (conditional weights, from which specialisation emerges), signed causal,
  analogous, normative, reference. Derived views: specialisation, prerequisite (temporal precedence in histories),
  currency flow (from transactions). Lineage lives in migration tables.

## Measured: membership battery v1 (layer A)

192 items (151 coverage events, 41 red-team), 3 Haiku variants per vocabulary (low effort); full tables in
`data/gold/membership_v1_metrics.md`. Mean α over each vocabulary's types: ACP 0.75, R156 0.63, A4 0.59, A6 0.45.

- **Two relations are robust in every vocabulary:** what kind of act it is (form 0.88, act 0.86, causal 0.82) and
  what it is about or for (outcome 0.70–0.74, content 0.75, purpose 0.64).
- **Material (0.38–0.46) and reference (0.33; −0.06 in A6) are unstable.** In A4, outcome and reference swap on 26%
  of items; in A6, reference loses its mass to normative (21%) and mechanism (17%), so in A4 it was absorbing them.
  ACP's single content type (0.75) beats A4's material and reference split.
- **Completeness was not measured by this battery:** "other" stays under 1% even on red-team cases built to break
  the sets (0.8–3.3%). Low-effort Haiku forces a fit rather than declining; completeness needs the author's review or a
  judging step.
- **Agreement on broad types is cheap:** ACP fills every type in 92% of answers; high α there partly reflects vague
  categories, and purpose is not observable (outputs only).
- Mechanism and normative apply rarely (17%, 29%); their high Jaccard is mostly agreement on null.
- Process flaw: two runs shared scratch filenames; material agreement between A4 v0 and A6 v1 is raised (0.56 against
  0.26–0.35 for independent pairs). Each run gets its own scratch folder from now on.
- Prediction (A4 beats A6 and R156 on completeness and agreement together, 0.55): missed. A4 beat A6 only.

Open: whether material and reference are ill-defined or not distinct (sharper definitions with examples in v2, and a
stronger model on a subset, separate the two); usefulness by ablation; the author's review of disputed items.

## External review (Fable, oversight prompt v1) and triage

Prompt: `prompts/oversight_relations.v1.md`. Dispositions: adopt, adopt with change, test, or dispute.

| Point | Disposition |
|---|---|
| A = form + one unsplit content (+ outcome as interim); carrier is derivable from participating things, which carry their own memberships through layer B; consumed vs produced is a layer-B fact | Adopt; it matches the battery (split .46/.33, unsplit .75) |
| Outcome stamped post hoc from observed changes with valid time; possibly migrates to event→event links | Adopt with change: outcome is observed change against the predicted counterfactual (metric models already predict the baseline), which also credits prevention (below) |
| An event↔event layer D (part-of, causes, re-description) absorbs mechanism (a means sub-event), coercion (a prior threat event), the conference dinner and concurrency (separate events, each with its own partition), and domain-level causality | Adopt; Benefuture already keeps event chains in transaction logs (L95 traversal), so D is native there |
| Purpose violates outputs-only; informedness and volition only as records (disclosure delivered, option set, prior threat event) | Adopt; Benefuture's informedness is already defined over memory (L116) |
| Normative out of A: status is act × norm set × context; count-as rules ("X counts as Y in C", Searle) in C | Adopt; also resolves the transfer family (tip, tithe, tax, bribe, ransom, gift), cross-culture classification, and agency |
| Mechanism redundant (form of a sub-event); C reference is the aggregate P(content = B given form = A) | Adopt |
| C signed causal as a scalar is ill-posed: aggregate event-level effects, store the distribution | Adopt |
| Prerequisite from precedence alone is confounded; use per-entity hazard of success given prior exposure, controlled | Adopt |
| R156's communicative is a form, not a relation type | Test; a candidate backpropagation against ruling 8.156 |
| Analogous cannot be learnt from events; source it from cross-domain model transfer performance | Adopt |
| Direction from typed co-membership, both directions stored with support, window and version | Adopt |
| Completeness tests: collision rate on minimal pairs, round-trip identification, placebo type as noise floor, ablation, scoring weights not only top domains; three runs of one model measure retest stability, not validity | Adopt as battery v2 |
| One additivity rule misfits four consumers: sum to one suits value routing; culpability is non-additive (Chockler–Halpern degree of responsibility, 1/(k+1)) | Adopt with change: additive attribution routes value and currency (conservation needs it); degree of responsibility serves culpability; concurrency goes to layer D, not to weights |
| Invisible prevention (maintenance, vaccination) | Absorbed by the counterfactual outcome above; a probe case |
| Omission without duty (boycott, strike, fast) | Test: an output relative to the counterfactual, with no duty needed for credit, only for blame |
| Depiction (actor playing a surgeon) | Absorbed: form acting, content medicine |
| Placebo, lottery win | Test: attribution against the predicted counterfactual should route little to luck |
| One decisive vote (Shapley near 0) | Test: degree of responsibility for culpability; value routing stays additive |
| Setting slot ("home" as a place) | Test as a candidate type in battery v2 |
| Form's .88 partly lexical anchoring on the verb | Test: round-trip and collision measure validity |

Prior art to test against: Dowty's proto-roles (supports layer B's graded quantities), Chockler and Halpern
(responsibility), Searle (constitutive rules), Pustejovsky's qualia (A4's ancestor; telic is a lexical default, not an
observation), W3C PROV-O (used, wasGeneratedBy, actedOnBehalfOf: a serialisation), ICATUS (benchmark for everyday
items, with simultaneous activities and "for whom").

## Current candidate (after review)

- A: form, content, outcome (observed change against the predicted counterfactual, with valid time); setting under
  test.
- B: causal contribution (additive, for routing), degree of responsibility (for culpability), signed impact per
  affected party, acting for, under agreement; informedness and volition as records.
- C, recorded: typed directed co-membership (both directions, with support, window, version), count-as rules with
  context, analogous (from model transfer). Derived: specialisation, reference, production, prerequisite (hazard
  model), causal distribution, currency flow.
- D (event↔event): part-of, causes, re-description, concurrency.

## Battery v2 (layer A): built, not yet run

Prompt `prompts/membership.v2.md`; vocabularies A3 (form, content, outcome) and A3S (plus setting), each with the
placebo type `flavour` (noise floor, reported apart). Minimal pairs in `data/gold/minimal_pairs_v0.jsonl`; round-trip
identification (`prompts/roundtrip.v1.md`, `lifeimage/roundtrip.py`) on merged annotations. Build with
`python3 lifeImage/tools/build_battery_v2.py`; metrics: `python3 lifeImage/tools/membership_metrics.py --pairs
data/batches/membership.A3.v2.var*.answers.jsonl`; round-trip: `python3 lifeImage/tools/roundtrip_score.py KEY ANSWERS`.
Predictions before measuring: placebo alpha well below form's; collision on setting pairs near 100% in A3 and low in
A3S; round-trip above chance (0.2) for ACP and A4 v1 annotations.

## Measured: membership battery v2 (layer A)

273 items (192 from v1 plus 42 minimal pairs' texts), 3 Haiku variants each for A3 and A3S, a 50-item Sonnet run, and
round-trip on v1 annotations. Tables in `data/gold/membership_v2_metrics.md`.

- **Predictions held:** content α 0.74 (A3) and 0.77 (A3S), against ≥ 0.70; placebo `flavour` filled 7.2% and 4.2%,
  against < 40%; round-trip 95.8% (A4) and 93.2% (ACP), against > 50%.
- **Round-trip is at ceiling and does not discriminate.** Distractors shared only the top form domain; next version
  uses distractors sharing form and content.
- **Declining works when asked:** the placebo stays near empty and its α is low (0.37, 0.16); outcome now applies to
  43–50% of items (declined when nothing observably changed), with α near 0.5. Outcome is sparse and harder.
- **Setting earns its place by collisions:** minimal pairs that should differ in A collide 28.6% without setting and
  7.1% with it; pairs that should differ only in B collide 37.5% and 25%. Form and content agreement rose slightly with
  setting present (0.89, 0.77).
- **The limit is the definitions, not the annotator:** Sonnet matches the Haiku majority on form 0.84, content 0.74,
  outcome 0.68, about the same as Haiku's agreement with itself. Sonnet is stricter on outcome (null 72%) and fills
  the placebo more (24%): a stronger model rationalises a meaningless type more readily, so the noise floor is per
  model.
- Process: two runners made a stray attempt to create a remote session (denied); runners should be a restricted agent
  type.

Current layer A: form, content, outcome (observed against counterfactual), setting.

## Graded round-trip v2 (built, not yet run)

Author ruling: decoys get progressively harder, to cases so nuanced that failure is expected, so the test shows where
validity ends. Levels (true item plus four decoys, chance 0.2): L1 random; L2 same top form domain; L3 same top form
and content; L4 same top form, content and setting; L5 near-duplicate texts (`data/gold/roundtrip_l5_v0.jsonl`, 40
items, each four decoys that differ only in a nuance: outcome, setting, content (A-encodable, 16 items) or consumed
versus produced, consent, acting for, count-as, volition (not A-encodable, 24)). L1-L4 decoys come from the 273-item
pool; the pool is thin (160 distinct top forms), so a level too few items qualify for is filled from the next easier
level, nearest first, and marked per decoy in the key and per item in `roundtrip.A3S.v2.fill_report.jsonl`. Scorer:
accuracy per level with a Wilson interval and the chance line, L5 split by A-encodable and by nuance kind. Predictions
before measuring: accuracy falls with level; L5 A-encodable nuances above chance, other nuances near 0.2 (confidence
0.6). Build: `python3 lifeImage/tools/build_roundtrip_graded.py`, annotate the `membership.A3S.v2.l5.var*` batches,
rerun with `--l5-answers`; score: `python3 lifeImage/tools/roundtrip_score.py --graded data/batches/roundtrip.A3S.v2.L*.key.jsonl`.

## Measured: graded round-trip v2 (A3S annotations)

| Level | Accuracy [95% Wilson] | Note |
|---|---|---|
| L1 random decoys | 99.3% [97.4, 99.8] | |
| L2–L4 nearest decoys | 81.0% [75.9, 85.2] | the thin pool collapsed the three levels: L2 and L3 batches are byte-identical, L4 differs in one task; independent runs agreed on 252 of 273 verdicts |
| L5 near-duplicates | 85.0% [70.9, 92.9] (n = 40) | A-encodable nuances 81%, others 88% |

- The designed failure did not appear, and the reason is a leak, not validity: on the 18 L5 items with decoys whose
  annotation is identical to the true one, guessing among the identical candidates predicts about 6.5 correct; 14
  were correct. The runner is separating the true text from template decoys by cues other than the annotation (the
  decoys carry their nuance in added wording). Outcome nuances were the hardest (50%, n = 6).
- Next version: a text-only control (candidates without the annotation; accuracy above chance there measures the
  leak), decoys written so the true text is not the plainest candidate, and difficulty scored against the nearest
  decoy's annotation similarity instead of nominal levels.
- Process: a fifth runner made a stray tool call (documentation read, harmless). All runs move to the restricted
  runner agent type.

## Measured: layers B and D, battery v1

81 items (28 red-team, 24 minimal-pair texts, 29 new scenarios), 3 Haiku variants (participation on the restricted
runner). Tables in `data/gold/bd_v1_metrics.md`.

- **Layer B agrees well on the quantities:** contribution α 0.81 (Spearman 0.81), responsibility 0.80, net impact
  0.73 (affected parties Jaccard 0.85). Prediction (about 0.5) was pessimistic.
- **Conservation held in every answer** (contributions to one outcome never above 1).
- **Contribution and responsibility diverge where they should:** on overdetermination items (sufficient shooters,
  decisive votes) mean contribution 0.12, responsibility 0.49; the pattern held in 89% of answers.
- **The record fields are sparse:** informed null 99%, under agreement 92%, volition 90%, acting for 96%; their α
  rests on few cases. Outputs-only makes them rare in plain text, as intended; consent is caught when stated (surgery
  carries the signed consent in all three variants, assault in none).
- **Production (consumed vs produced) is weak:** α 0.60, null 55%. Prediction (≥ 0.7) missed; it needs a sharper
  definition, since the image's expertise rule leans on it.
- **B minimal pairs:** 1 of 8 collides; 7 of 8 differ in an expected field.
- **Layer D:** sub-event count α 0.66 (mean 2.05); link type α 0.70 over matched pairs. Causes dominates (used in 59%
  of scenarios), concurrent 22%, part_of 16%, re_description 5%; richer texts get more sub-events in 4 of 4 pairs.
- **Surgery's impact is recorded as harm** when recovery is not in the text: outcome against the counterfactual needs
  the counterfactual stated or predicted, which the plain-text battery cannot supply.

## Final candidate sets (for the confirming battery)

- **A (event → domain):** form, content, outcome (observed against the predicted counterfactual, with valid time),
  setting.
- **B (entity → event):** contribution (additive, routes value), responsibility (degree, for culpability), impact per
  affected party, production (consumed, produced, both; definition to sharpen), and the records acting for, under
  agreement, informed, volition.
- **C (domain ↔ domain), recorded:** typed directed co-membership (both directions, support, window, version),
  count-as rules with context, analogous (from model transfer). Derived: specialisation, reference, production,
  prerequisite (hazard model), causal distribution, currency flow.
- **D (event ↔ event):** part_of, causes, re_description, concurrent.
- **Channels (predicted/measured image):** potential (red) from predicted expertise and impact, including
  self-assessment; expertise (green) through form and content with production; impact (blue) through outcome.

Confirming battery: the four layers on one item set; production v2 definition; outcome items that state or imply the
counterfactual; the round-trip with a text-only control, decoys where the true text is not the plainest, and
difficulty by nearest-decoy similarity; then the author's review of disputed cases.

## Confirming battery (built, not yet run)

One item set, `data/gold/confirm_items_v0.jsonl` (120 items, every item with its participants listed): 36 from the
273 layer-A items (20 coverage events spread over domains, 8 red-team cases, 4 whole A minimal pairs), 24 from the 81
layer-B/D items (overdetermination items and the B and D pairs kept whole), 30 new texts that state or imply the
counterfactual (22 with an observed change, 8 where the counterfactual equals the observed course, such as a failed
rescue) and 30 in 15 consumed-versus-produced pairs. One combined task per item, `confirm.v1` (A with the placebo,
B per participant, D), three variants; production is defined as: produced = the participant's act yields an output
others can use or assess; consumed = they take in or use up an output without yielding one; both; null if no record.
The outcome is the observed change against what would otherwise have happened, used only when the text states or
implies it.

Round-trip v3 (built from the confirm answers): decoys are the nearest annotations (weighted Jaccard over the A types),
chosen inside a 15% band of the true text's length and added wording so the true text is not the plainest, with the
nearest decoy's similarity recorded per task; a text-only control batch carries the same candidates without the
annotation. Scoring: accuracy by similarity decile with Wilson intervals, the control accuracy and the leak-corrected
gain (annotation minus control, paired by item, counted beyond z = 2 standard errors). Decoys are chosen, not
rewritten; tasks whose band could not be filled are flagged in the key and scored apart.

Predictions before measuring (confidence 0.6 each): focal production matches the expected value in at least 80% of
answers on the pairs and separates at least 12 of 15 pairs (alpha was 0.60); the outcome is filled in at least 80% of
the change items and at most 20% of the no-difference and plain items; control accuracy stays above chance but below
the annotated arm, the leak-corrected gain is positive and clearly under the 85% raw L5 figure, and accuracy falls
with the similarity decile (0.7).

Build and score: `python3 lifeImage/tools/build_confirm_items.py`, `python3 lifeImage/tools/build_battery_confirm.py`
(batches), annotate and answer, then `python3 lifeImage/tools/confirm_metrics.py data/batches/confirm.v1.var*.answers.jsonl`
and `python3 lifeImage/tools/build_battery_confirm.py --from-answers data/batches/confirm.v1.var*.answers.jsonl`
(round-trip v3, scored with `roundtrip_score.py --v3`).

## Measured: confirming battery v1 (all layers, 120 items, 3 variants on the restricted runner)

Tables in `data/gold/confirm_v1_metrics.md`.

- **A:** mean α 0.77; form 0.82, content 0.83, outcome 0.81 (applies 29%; on items that state or imply the
  counterfactual it is now stable), setting 0.61. Placebo filled 0.3%. A minimal pairs: no collisions (4 of 4 differ).
- **B:** contribution 0.92 (Spearman 0.90), responsibility 0.89, net impact 0.65; conservation held in all 360
  answers; overdetermination pattern 89% (contribution 0.07, responsibility 0.55). Production α 0.57 overall, but on
  the 15 consumed/produced pairs it matched the expected value in 89 of 90 participant judgements: it works when the
  text records an act, and its low α comes from items with no record. Record fields stay sparse (null 98–100%).
  B minimal pairs: 1 of 5 collides.
- **D:** sub-event count α 0.66 (mean 1.43); link type α 0.65, identical label on 89% of linked pairs.
- **Weak spots left:** setting (0.61), net impact (0.65), D segmentation (0.66), and the decisive vote item (33%).

## Measured: round-trip v3 (leak-controlled)

- Annotated 93.3% [87.4, 96.6], text-only control 20.0% [13.8, 28.0] (chance 20%): the text leak is gone, and the
  leak-corrected gain is +73.3 points (se 0.041; beats the 2-standard-error rule). With fully equalised wording only:
  94.4% against 21.3%.
- By nearest-decoy similarity: 92–100% up to similarity 0.69, then 66.7% [39.1, 86.2] in the top decile (0.71–1.00),
  where decoys share most of the annotation: the designed failure region appears where it should.

Author review: `data/gold/review_v1.md` (the 30 most disputed items and the round-trip misses).

## Author review rulings (2026-11-23)

- **[R] Responsibility follows freedom at the moment of producing the outcome** (author). The outcome is recorded as
  it is; responsibility is assigned by the level of freedom the participant had in producing it. A self-defender
  causes harm, and responsibility rests on which ways of defence were available. So the volition record becomes the
  option set (the alternatives available, and how harmful each was), and responsibility is computed from contribution
  and that freedom, not capped by a flag. Coerced handovers (shopkeeper, clerk, donor) carry little responsibility
  because their options were narrow. Beneficiaries who only received an outcome produced nothing and carry none
  (lead's reading of the same rule; case 3).
- **[R] Production is required whenever contribution is above 0 (produced) or the participant receives the output
  (consumed)** (author, confirming case 4). A vote produces; publishing under one's name is a count-as matter (C).
- Candidate backpropagation: L96's `Responsibility(Informed, Counterfactual, Severity, Duty)` has no explicit freedom
  term (alternatives available); the self-defence ruling suggests adding one.

## Relation metadata (LI.42)

Each property has a consumer; nothing generic. Already in the contract: weight, confidence, tier, provenance (source,
span), date, revoked.

| Property | On | Consumer |
|---|---|---|
| Option set (alternatives available, each with its harm) | participation | responsibility by freedom (LI.40) |
| Counterfactual reference (predicted course and the model or statement it comes from) | outcome membership | outcome against the counterfactual; prevention credit |
| Magnitude and count per affected party | impact | impact intensity |
| Context (jurisdiction, culture, norm set) | count-as rules, memberships | tip vs bribe; cross-culture classification |
| Valid time and record time | every relation | decay (valid time); recount and audit (record time, L101) |
| Support (evidence count) and version | domain ↔ domain relations | direction and stability of learnt links |
| Time span and place | events | decay, setting cross-check |
| Identity binding and entity kind (person, organisation, AI, animal) | entities | liability and image rules by kind |

Left out until a consumer needs them: stated intent (unless itself a recorded statement), emotional valence, generic
tags. When the option set is missing, responsibility falls back to a governed default and the substitution is logged
(progressive degradation), never assuming full freedom.

## Contract v2 and the confirm v2 rerun (built, not yet run)

- Contract: evidence rows carry `valid_time` and `record_time` (old `date` rows migrate by `migrate_evidence_v0` /
  `read_evidence`), optional `option_set`, `context` and `entity_kind`; outcome memberships carry an optional
  `counterfactual` {course, source: stated | implied | model:<id>}; entities have a `kind`; domain links carry optional
  `support` and `version`; count-as rules (`count_as.schema.json`) carry optional `context`; participation impact
  entries take an optional `count`.
- Responsibility by freedom (`responsibility_from_freedom`): contribution 0 gives 0; a missing option set uses the
  governed default 0.5 (`lifeimage/governed.py`), logged as a degradation record each use; with an option set, no
  alternative less harmful than the outcome gives the governed floor 0.1, rising to 1 when a harmless alternative
  existed.
- Production: version-2 answers need a production value whenever contribution is above 0 or the output is received;
  an answer recording an outcome with every participant at 0 and 0 is a zero run and is rejected.
- Rerun: `python3 lifeImage/tools/build_battery_confirm.py --rerun` writes `confirm.v2.var{0,1,2}.jsonl` over the 38
  review items plus 4 self-defence items (`prompts/confirm.v2.md`); compare with
  `python3 lifeImage/tools/confirm_metrics.py data/batches/confirm.v1.var*.answers.jsonl --vs data/batches/confirm.v2.var*.answers.jsonl`.
  On v1 the production value was null for 59 of 111 answers that required it.

## Measured: rerun under LI.40–42 (confirm v2, 38 disputed items + 4 self-defence items)

Tables in `data/gold/confirm_v2_rerun_metrics.md`.

- **Production fixed:** α 0.30 → 0.86; nulls where required 59 of 111 → 0 of 134.
- **Responsibility follows freedom:** coerced participants 0.56 → 0.08; self-defence with no less harmful option 0.10,
  with a less harmful option 0.90, disproportionate 0.90, ambiguous perceived threat 0.40. Prediction (coerced ≤ 0.2;
  less-harmful case above no-less-harmful) held.
- **Cost:** responsibility α 0.80 → 0.54, because it now depends on the recorded option set, on which runs differ
  (volition α 0.42). The option set is the new weak spot; under agreement stays too sparse to measure (α −0.04).
- Impact α 0.56 → 0.69; acting for 0.75 → 1.00; layer A unchanged (form 0.78, content 0.74, outcome 0.71, setting 0.56).
- **Defect found (lead fix):** on overdetermined items runners score each redundant contributor near 0 (a "but for"
  reading), so the zero-run check pushed them to null the outcome (archers, volunteers). Contribution is the additive,
  Shapley-style share (five sufficient archers: 0.2 each); "but for" belongs to responsibility. The prompt needs that
  definition in the next version.
- Governed default for responsibility with no option set: 0.5 (`lifeimage/governed.py`), logged as a degradation
  when used. `[P]`, a governed threshold.
