# Benefuture Specification Divergences

This document records every place where the Lean 4 formal specification diverges from, chooses between interpretations of, or extends `spec/Bf_Pseudocode.txt` and the background articles (`docs/articles/*.txt`).

Per the Ground Rules:
- Sources of truth: `spec/Bf_Pseudocode.txt`, then `docs/articles/*.txt`.
- Every definition cites its pseudocode line.
- Where Lean deviates or chooses, a `-- SPEC-CHOICE:` comment is placed in the code and recorded here.
- Status tags: `[R]` ratified by the author; `[P]` proposed default; `[OPEN]` unresolved.

---

## 1. Phase 1 Divergences (Honesty and Cleanup)

### 1.1 Repugnant Conclusion ([OPEN])
- **Source**: `Philosophy.txt` mentions Parfit's Repugnant Conclusion. `Bf_Pseudocode.txt` does not specify a baseline flourishing floor.
- **Divergence**: Previous formalizations introduced an ad hoc `FLOURISHING_BASELINE_FLOOR := 100000` (0.10) and claimed "structural dissolution" of the Repugnant Conclusion.
- **Lean Spec Choice**: Removed `FLOURISHING_BASELINE_FLOOR` and the dissolution claims. Added an `[OPEN]` note and formal lemma `floor_shifts_repugnant_conclusion`: for any non-zero floor $f > 0$, a sufficiently large population $n$ at wellbeing $f$ exceeds any fixed finite flourishing population. The floor relocates the threshold rather than solving the paradox.

### 1.2 Anti-Corruption Choice Architecture (AC) ([P])
- **Source**: `Bf_Pseudocode.txt` L156: `AntiCorruption := ChoiceArchitecture(Effort(Good) < Effort(Bad));`.
- **Divergence**: Previously framed as a mathematical theorem that $a < a + b + c$ from definition.
- **Lean Spec Choice**: Recast as `AntiCorruptionDesignRequirement`: a design parameter assumption requiring restorative friction to be strictly positive (`ac_friction_pos_assumption : 0 < restorativeFriction`).

### 1.3 Anti-Cobra Vulnerability Clawbacks (AdvAp) ([P])
- **Source**: `Bf_Pseudocode.txt` L157; `Adversarial adaptation.txt` §Nuance 1.
- **Divergence**: Previously claimed a theorem eliminating bounty farming.
- **Lean Spec Choice**: Recast as `AntiCobraDesignRequirement`: clawback $\ge$ bounty is guaranteed by construction in the reward formula (`creator_liability := bounty + overhead`), but preventing bounty farming critically assumes that causal attribution successfully detects who planted the flaw (`flaw_planter_attribution_assumption`).

### 1.4 Non-Circularity and Goodhart's Law ([P])
- **Source**: `Bf_Pseudocode.txt` L46-50.
- **Divergence**: Previously claimed a theorem that metric models prevent Goodhart gaming via `m.origin.isEmpirical = true`.
- **Lean Spec Choice**: Recast as `EmpiricalMarkerRequirement`: markers are empirical by construction, which prevents syntactic self-reference, but does NOT solve Goodhart's Law. Addressing Goodhart requires latent vs observed model competition.

### 1.5 Domain Causal Grounding ([P])
- **Source**: `Bf_Pseudocode.txt` L22.
- **Divergence**: Theorem `anti_gerrymandering_causal_grounding` was a definitional tautology returning the structure field `h_causal_nonempty`.
- **Lean Spec Choice**: Retained `h_causal_nonempty` as an explicit structure field / design requirement on `Domain`.

### 1.6 Deletion of Tautological and Overclaimed Theorems
- **Tautological subtyping theorems**: Removed 93 theorems of the form `foo_is_thing : (x : Thing).id = x.id := rfl`. Coercion instances (`Coe`) are preserved.
- **Legacy Risk Claims**: Removed `CivilizationalConcern`, `BenefutureSystemMitigation`, `calculate_systemic_mitigation`, `residual_risk`, and associated theorems asserting elimination of legacy civilizational risk via arbitrary linear coefficients.
- **Constant Yield Claims**: Removed `progressive_goal_yield` (which hardcoded a constant 1000) and `progressive_preserves_core_goal_under_all_contexts`.
- **Definitional Good/Bad Theorems**: Removed `good_action_*` and `harm_causing_action_*` which merely restated `decide (delta_v > 0)`.
- **Non-Spec Synergy Additions**: Removed `net_synergy_balance`, `synergy_pair_gains`, and `synergy_superadditive` (not part of L13 pseudocode formula).
- **Epistemic Dominance of Wireheading**: Dropped integer toy versions `epistemic_dominates_wireheading` and `epistemic_dominates_saturated_wireheading` pending faithful real formulation in Phase 2.

---

## 2. Phase 2 Divergences (Faithful Core Mathematics)

### 2.1 Unified Parameter Governance (GovParams & ParamSchedule) ([R], [P])
- **Source**: `Bf_Pseudocode.txt` L11-14, L25, L101, L155.
- **Specification**: All governed parameters ($\alpha, \beta, \gamma, \delta, \kappa, q_+, q_-, \lambda, \nu, h, \lambda_+, \lambda_-, Th_{sig}, Th_{gov}$) are unified into one record `GovParams` subject to Significant Threshold Governance (`SigThGv`).
- **Priority Schedule**: Instead of hardcoding ad-hoc integer multipliers (100, 60, 40), tiered priorities take weights from a general strictly decreasing `ParamSchedule` over $\mathbb{R}$.

### 2.2 Faithful Synergy Operator ($Sy$ and $\hat{Sy}$) over $\mathbb{R}$ ([R])
- **Source**: `Bf_Pseudocode.txt` L13-14.
- **Specification**: Formalized exactly per pseudocode:
  $$\Phi_s := \sum_i w_{s,i} a_{s,i}^{q_s} + \kappa \sqrt{\sum_{i<j} w_{s,i} w_{s,j} (a_{s,i} a_{s,j})^{q_s}}$$
  $$Sy := \Phi_+ - \Phi_- - \lambda \frac{\Phi_+ \Phi_-}{\Phi_+ + \Phi_-} \quad (0 \text{ when } \Phi_+ + \Phi_- = 0)$$
  $$\hat{Sy}(s) := \operatorname{sgn}(s) \frac{|s|^\nu}{|s|^\nu + h^\nu}$$
- **Proved Lemmas**:
  - `equal_gains_and_losses_are_negative`: for equal potentials $v > 0$ and $\lambda > 0$, $Sy(v, v) = -\lambda v / 2 < 0$.
  - `squashed_synergy_odd`: $\hat{Sy}(-s) = -\hat{Sy}(s)$.
  - `squashed_synergy_bounds`: $\hat{Sy}(s) \in (-1, 1)$ for $h > 0, \nu > 0$.
  - `squashed_synergy_strictly_monotone_nu_one`: strictly monotone for canonical $\nu = 1$.
  - `net_synergy_single_positive` & `net_synergy_single_negative`: strictly positive/negative for single positive/negative items.

### 2.3 Loss Aversion Scale Inversion below 1.0 ([OPEN])
- **Source**: `Bf_Pseudocode.txt` L13: $q_+ = 1.1, q_- = 1.5$.
- **Finding**: With $q_- > q_+ > 1$, loss aversion behaves correctly for magnitudes $m > 1$ (`loss_aversion_holds_above_one`), but inverts for $0 < m < 1$ (`loss_aversion_fails_below_one`):
  $$\forall m \in (0, 1), \quad m^{q_-} < m^{q_+}$$
- **Spec Implication**: Because exponents $> 1$ compress sub-unitary quantities, higher penalty powers perversely attenuate micro-harms unless input variables are explicitly normalized against a unit scale threshold. Tagged `[OPEN]`.

### 2.4 Harm Tiers: Weighted vs Lexical Readings ([OPEN])
- **Source**: `Bf_Pseudocode.txt` L61-63; `Benefuture goals.txt` #Harm.
- **Finding**:
  - Under a weighted reading (`HarmWeights`), $\mathbb{R}$ is Archimedean, so `finite_exchange_rate_weighted` proves $\exists n : \mathbb{N}, n \cdot w_{pass} \ge w_{irrep}$ (aggregation dilemma).
  - Under a lexical reading (`LexicalHarmLt`), `no_finite_exchange_rate_lexical` proves $\forall n : \mathbb{N}, (0, n) <_{lex} (1, 0)$ (no quantity of minor harms compensates one catastrophic harm).
- **Spec Implication**: Left unresolved as an open ethical parameterization choice between utilitarian optimization and deontological thresholds.

### 2.5 Freedom vs Necessary Harm Tension (Fr vs NHa) ([OPEN])
- **Source**: `Bf_Pseudocode.txt` L55 ($NHa := Ha : Ha \to \uparrow V > Ha$) vs L135 ($Fr := f_{max}(\dots) \mid \neg Ha_{irreversible}$).
- **Finding**: Theorem `freedom_excludes_irreversible_necessary_harm` constructs an action causing irreversible harm where value yield exceeds harm ($\Delta V > Ha$). It satisfies $NHa$ (value-positive) but is categorically rejected by $Fr$ (deontological non-harm constraint).
- **Spec Implication**: Fundamental structural tension between global optimization and rights constraints; tagged `[OPEN]`.

### 2.6 Dynamic Assessment $As$ (L48) ([R])
- **Source**: `Bf_Pseudocode.txt` L48.
- **Specification**: Formalized `dynamic_assessment_real` over $\mathbb{R}$ with abstract functions `pr_predict`, `pr_counter`, and `me_measure` supplied by `MetricModel`. Proved `ex_post_uses_measurement_real` ($t > t_0$) and `ex_ante_uses_prediction_real` ($t \le t_0$).

### 2.7 Value $V$ and Goal $G$ Bugfix (SPEC-CHOICE)
- **Source**: `Bf_Pseudocode.txt` L73-74.
- **Value Function Simplification**: Removed early draft ad-hoc $\delta$ penalty and sentience multiplier `experienceLevel` from $V(A, b)$ (sentience multiplier tagged `[OPEN]`). $V$ computes $Sy_2$ directly over assessed inputs $[(U, \alpha \cdot Ha\_wt), (H, \beta \cdot \alpha \cdot Ha\_wt), (N, \gamma)]$.
- **Goal G Contracting Action Bugfix**: Previously, `goal_G` assigned value 0 to contracting actions, allowing an illegal contracting action (value 0) to outrank an eligible expanding action with negative value (e.g. -5).
  - Fixed by defining `is_eligible_action` and `eligible_actions` filtering candidates by reality enhancement.
  - **SPEC-CHOICE**: Adopted non-decreasing reality scope ($\Delta \ge 0$) as the eligibility baseline for $\uparrow \mathbb{R}$. A strictly positive requirement ($\Delta > 0$) would disqualify routine flourishing-preserving maintenance actions.
- **Distributional Push (`pushDistr`, L60)**: Marked `[OPEN]` and left unformalized in the core spec; requires formal population quantile distribution mechanics deferred to simulation.

---

## 3. Phase 3 Divergences (Ontology, Domains, and Reputation)

### 3.1 Pattern / Thing and RealityState Duality ([R], [P])
- **Source**: `Bf_Pseudocode.txt` L21-22, L132; `Architecture.txt` §Ontology.
- **Specification**: In `Reality.lean` and `Thing.lean`, `Thing` is an entity grounded in spacetime (`SpacetimeGrounding`), while `Pattern` is an abstraction with an evaluation predicate `«matches» : Thing → Bool`.
- **Extension & Predicates**:
  - `ext p R := R.things.filter (fun t => p.«matches» t)`
  - `IsIdentity p R :↔ (ext p R).card = 1`
  - `IsDomainPattern p R :↔ 1 < (ext p R).card`
- **Identity Disambiguation**: To distinguish identical twins, digital clones, or behavioral mimics from the underlying individual, identity resolution requires history worldline / spacetime grounding (`thing_identity_pattern`).
- **Identity Binding (`can_bind_id`, L132)**: An entity can only bind an identity pattern if confidence exceeds threshold and zero collision exists in the observed reality state.

### 3.2 Share-Based Partition of Unity vs Independent Weights ([P], [OPEN])
- **Source**: `Bf_Pseudocode.txt` L21-22, L113.
- **Finding & Divergence**: If domains are assigned unconstrained independent weights in $[0, 1]$, an action spanning multiple overlapping domain labels can multiply its influence, reputation rewards, and voting weight without bound (domain gerrymandering / double-counting vulnerability).
- **Lean Spec Choice**: Formulated `PartitionOfUnity` over `LeafDomain` where weights sum to 1 ($\sum_{l \in leaves} w_l = 1$). Proved `aggregate_no_double_count` and `aggregate_monotonicity` for parent domains.
- **Status ([OPEN])**: Single vs Multi-RelType Partition of Unity. Whether a single partition of unity governs all relationships or separate partitions exist per relation type (causal, structural, communicative) is left open.

### 3.3 Domain Hierarchy Knaster-Tarski Fixed Point ([P])
- **Source**: `Bf_Pseudocode.txt` L21-22.
- **Specification**: In `Benefuture.Proposed.DomainHierarchy`, fuzzy subsethood $S(x, y)$ over action relevance is modeled as a monotonic operator on a complete lattice. Theorem `hierarchy_fixed_point_exists` proves existence of a fixed-point hierarchy via Knaster-Tarski, resolving circularity in mutually interdependent domains without ad-hoc cutoffs.

### 3.4 3-Component Reputation Architecture ([R], [P])
- **Source**: `Bf_Pseudocode.txt` L101 ("!halo, !horn, !transfer"), L113 ("VW_expert"), L117 ("EHR").
- **Specification**: Separated reputation into distinct state stores and views in `Benefuture/Ontology/Reputation.lean`:
  - `ReHistory`: Monotonic, append-only historical record ($hPos \ge 0, hNeg \ge 0$). Non-cancelling ledger.
  - `ReRelevance`: Current time-decayed domain competence ($rel \in [0, 1]$).
  - `Re`: Transparent query view synthesizing history, relevance, and retracted items.
- **Anti-Halo Domain Isolation**: Proved theorem `anti_halo_domain_isolation` on `DecisionProfile` and `VW_expert`: a voter with zero relevance across a decision's leaf domain support receives exactly 0 expert voting weight, preventing cross-domain halo/horn leakage.
- **Fork / Merge Conservation**: In `Benefuture/Ontology/Entity.lean`, proved `fork_conserves_per_domain_*` and `merge_conserves_per_domain_*`, ensuring splitting or merging entities cannot manufacture or destroy reputation history or currency.
- **Exponential vs Subtractive Decay ([OPEN])**: Provided both continuous exponential decay ($rel_0 \cdot \exp(-\lambda \Delta t)$) and linear bounded subtractive decay ($rel_0 - \lambda \Delta t$). Left open as a governance schedule decision.

