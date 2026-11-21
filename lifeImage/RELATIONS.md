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
