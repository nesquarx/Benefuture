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

### 2.3 Loss Aversion Scale Inversion below 1.0 ([OPEN] → resolved in §7.2, [R])
- **Source**: `Bf_Pseudocode.txt` L13: $q_+ = 1.1, q_- = 1.5$.
- **Finding**: With $q_- > q_+ > 1$, loss aversion behaves correctly for magnitudes $m > 1$ (`loss_aversion_holds_above_one`), but inverts for $0 < m < 1$ (`loss_aversion_fails_below_one`):
  $$\forall m \in (0, 1), \quad m^{q_-} < m^{q_+}$$
- **Spec Implication**: Because exponents $> 1$ compress sub-unitary quantities, higher penalty powers perversely attenuate micro-harms unless input variables are explicitly normalized against a unit scale threshold. Tagged `[OPEN]`.

### 2.4 Harm Tiers: Weighted vs Lexical Readings ([OPEN] → resolved in §7.3, [P])
- **Source**: `Bf_Pseudocode.txt` L61-63; `Benefuture goals.txt` #Harm.
- **Finding**:
  - Under a weighted reading (`HarmWeights`), $\mathbb{R}$ is Archimedean, so `finite_exchange_rate_weighted` proves $\exists n : \mathbb{N}, n \cdot w_{pass} \ge w_{irrep}$ (aggregation dilemma).
  - Under a lexical reading (`LexicalHarmLt`), `no_finite_exchange_rate_lexical` proves $\forall n : \mathbb{N}, (0, n) <_{lex} (1, 0)$ (no quantity of minor harms compensates one catastrophic harm).
- **Spec Implication**: Left unresolved as an open ethical parameterization choice between utilitarian optimization and deontological thresholds.

### 2.5 Freedom vs Necessary Harm Tension (Fr vs NHa) ([OPEN] → resolved in §6.1, [P])
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

---

## 4. Phase 4 Divergences (State, Step, Invariants, Governance & Incentives)

### 4.1 Ground Truth vs Measurement (Latent vs Observed) ([R], [P])
- **Source**: `Bf_Pseudocode.txt` L48-50; `Architecture.txt` §Measurement.
- **Specification**: In `Benefuture.Systems.State`, true flourishing variables ($U, H, N$) are latent world model properties (`LatentFlourishing`), distinct from noisy empirical observations (`ObservedMeasurement`).
- **Measurement Gap**: Defined `LatentObsGap(actual, observed) := |actual - observed|`.
- **Goodhart Resistance**: Incentives must strictly reward latent improvement, not purely observed proxies (`GoodhartResistantIncentive`).

### 4.2 Operational Semantics (State, Event, Step) ([R])
- **Source**: `Bf_Pseudocode.txt` L25, L26, L101, L113, L132, L155, L157.
- **Specification**: Small-step transition semantics `Step : State → Event → State → Prop` over 12 operational events (`mint`, `spend`, `escrow_lock`, `escrow_release`, `escrow_forfeit`, `bounty_post`, `bounty_claim`, `bounty_clawback`, `vote_cast`, `entity_fork`, `entity_merge`, `time_advance`).

### 4.3 RepCache & Lazy Continuous Decay ([R])
- **Source**: `Bf_Pseudocode.txt` L101 ("continuous decay").
- **Specification**: Defined `RepCache` storing `(lastUpdateTime, cachedScore, decayRate)`. Reads compute lazy decay $s \cdot e^{-\lambda \Delta t}$ on demand, avoiding continuous chain-wide writes.
- **Theorems Proved**:
  - `cache_correct`: Exponential decay commutes with summation over disjoint score components.
  - `decay_transitive`: Multi-checkpoint decay composition is transitive.
  - `checkpoint_sound`: Updating a cache at time $t$ preserves identical readings for all future queries $t' \ge t$.
- **Recount Triggers**: Formalized predicate `RecountNeeded` triggered by elapsed time $\Delta t > \Delta t_{\max}$, uncheckpointed events $N > N_{\max}$, or formal dispute.

### 4.4 System Invariant Preservation ([R])
- **Source**: `Bf_Pseudocode.txt` L26, L132, L155.
- **Theorems Proved over `Step`**:
  - `step_preserves_mem`: Append-only memory ledger. Past records are immutable (`Invariant_Mem`).
  - `step_preserves_id`: Active identity injectivity / uniqueness (`Invariant_Id`).
  - `SupplyAccountingIdentity`: Exact supply conservation ($\Delta \text{Supply} = \sum \text{Mint} - \sum \text{Burn} - \sum \text{Lost}$).
  - `step_preserves_escrow_soundness`: Escrow nominal equals upfront plus ongoing hold (`Invariant_EscrowSoundness`).
  - `auto_spill_enforces_ceiling`: Automatic balance spill to community treasury enforces $balance(E) \le Th_{bal}$ (`Invariant_BalOvflw`).

### 4.5 Governance & Incentives ([R], [P], [OPEN])
- **Source**: `Bf_Pseudocode.txt` L34, L114, L117, L157.
- **Liquid Democracy Acyclicity**: Defined `DelegationGraph` with well-founded acyclicity condition. Proved `delegation_no_trivial_cycles`.
- **Delegation Cap & Power Concentration ([OPEN] → resolved in §7.4, [R])**: Theorem `star_topology_power_concentration` proves that without a cap, a star delegation graph allows a single entity to concentrate 100% of voting weight. Proposed `SatisfiesDelegationCap` (e.g. 5% max weight).
- **Strict Propriety of Brier Score**: In `Benefuture.Governance.Incentives`, proved `brier_score_strictly_proper` via algebraic decomposition $\mathbb{E}[L(p)] = (p - q)^2 + q(1-q)$. Reporting truth $p = q$ is the unique global minimizer.
- **Anti-Cobra Incentive Compatibility**: Proved `bounty_incentive_compatible`: under clawback $C \ge B + D$, expected farming payoff is strictly negative whenever detection probability $p_{detect} > B / C$.
- **Uncollateralized Exploit Vulnerability ([OPEN])**: Documented `UncollateralizedExploitVulnerability`: if market short gains exceed $C$, or attacker wealth $W < C$, clawbacks cannot deter exploit planting.
- **Anti-Collusion EHR Attenuation**: Proved `complete_cyclic_attenuation` for mutual review pairs $(A \to B, B \to A)$, and noted limitation for cycles of length $\ge 3$ requiring global eigenvector centrality (`SybilCycleDetectionRequirement`).

---

## 5. Phase 5 Divergences (Reference Implementation & Test Vectors)

### 5.1 Decoupled Float Reference Architecture ([R], [P])
- **Source**: `Bf_Pseudocode.txt` L13-14, L21-22, L26, L48, L73, L101, L113, L117, L157.
- **Specification Architecture**:
  - The specification (`Benefuture`, over $\mathbb{R}$) uses Mathlib real numbers to prove axiomatic properties and structural invariants without floating-point rounding artifacts.
  - The reference implementation (`BenefutureReference`, over `Float`) is completely decoupled from Mathlib and from the specification library.
  - `Main.lean` (the executable `benefuture`) imports only `BenefutureReference`.
- **Test Vectors**: Emits canonical test vectors (`spec/vectors/*.json`) for $Sy, \hat{Sy}, As, V$, escrow splits, continuous lazy decay, and voting weights to guide downstream simulation implementations (e.g., in Julia).




---

## 6. Phase 6 Divergences (Population Direction)

### 6.1 Population Axiology by Direction ([R] decisions, [P] formalization)
- **Source**: `Bf_Pseudocode.txt` L54-55 ($Ha$, $NHa$), L62 (`pushDistr`), L68 ($Bounds_B$), L74 ($G$), L135 ($Fr$), L150 ($Harm\_Intv$).
- **Decisions ratified by the author**:
  - Bf ranks actions, not worlds. $V$ is per action; a being-level value is only an expected (speculated) lifetime tally over $Bounds_B$.
  - Existing beings may only be uplifted; removal via irreparable harm is never an option.
  - Withholding available uplift is not $Ha$, but is always comparatively worse than providing it under argmax.
  - `pushDistr` skew is a direction, not a target shape. The skew directions set the exchange rate between max and min.
  - Net-negative expected tallies never outweigh a smaller positive population.
  - $\uparrow$min may dip through an $NHa$ gap; priorities resolve which gaps to tunnel through.
- **Lean Spec Choice** (`Benefuture.Proposed.PopulationDirection`, not imported by core):
  - `choose_action`: $Fr$ filters candidates, then argmax over value. `chosen_action_fr_sound` proves the chosen action passes Fr (§7.8); `removal_never_chosen`: removing an existing being (irreparable harm known to occur) is never chosen.
  - `progress`, `pushDistr_aligned`, `pareto_dominates` (strict partial order: `pareto_irrefl`, `pareto_trans`), `pareto_front`. `pareto_front_nonempty` proves the filter never empties a non-empty choice set. Pareto-first is grounded in Sy's `find ∧ max(⋂ ↑x)` (L13).
  - Skew from populations: `pop_mean`, `pop_m2`, `pop_m3`, `skewness`, and the square-root-free direction key `skew_key` (`skew_key_eq`: key = γ·|γ|; `mul_abs_strictMono`: the key orders populations exactly as γ does). Direction-only `pushDistr` needs only a strictly monotone transform of γ.
  - `skew_direction_alone_permits_min_decline`: lowering the worst-off being ([2,6,8,9,10] → [0,6,8,9,10]) moves U toward left skew while min falls. Hence ↑min must hold jointly with the skew push.
  - `min_holds_over`: $\uparrow$min holds at the trajectory endpoint, with every dip covered by $NHa$. `tunnel_admissible_but_not_stepwise` proves that a stepwise filter rejects tunnels the trajectory criterion admits, so Pareto filtering must compare trajectories over the prediction horizon (L34).
  - `harm_intv_fires`; `nonclosing_tunnel_triggers_harm_intv`: a tunnel still open at the horizon has triggered $Harm\_Intv$ (L150) at some step.
  - `expected_tally`; `net_negative_never_outweighs_positive`.
  - `effective_types`; `copies_add_no_diversity`, `new_type_adds_diversity`. `population_novelty_eq_effective_types`: summing $N(x) := 1/Frequency(x)$ (L36) over a population gives the number of distinct types, so saturating diversity is derived from $N$, not added as a population term. Grounded in `Diversity.txt`: "diversity is built into the Novelty factor".
- **Arbitration note**: `Benefuture goals.txt` speaks of "target distribution shapes"; the author specified "more direction than shape". Reconciled through the pseudocode's `pushDistr` (L62): the push is toward a skew class (left, right, normal), not toward a parametrised target shape.
- **Resolves**: §2.5 ($Fr$ vs $NHa$) as a lexical ordering — $Fr$ filters the action set before $NHa$ can justify a harm, mirroring `eligible_actions` for $\uparrow\mathbb{R}$ (§2.7). Also resolves where diversity enters (through $N$).
- **Partially addresses**: §1.1 (Repugnant Conclusion) and the `pushDistr` note in §2.7. `floor_shifts_repugnant_conclusion` remains true, but its premise (ranking worlds by summed value) is not Bf's mechanism under this proposal.
  - `population_novelty_hist`; `population_novelty_hist_le`: with frequency counted against history in ℝ (L36), summed novelty is at most the number of distinct types (equality with empty history, `population_novelty_hist_nil`).
  - Choice pipeline: `Plan`, `plan_admissible` ($Fr$ ∧ `is_eligible_action`), `choose_plan`. `choose_plan_sound`: for any Pareto-monotone score, the chosen plan carries no irreparable or irreversible harm, does not contract ℝ, and is not Pareto-dominated by any admissible plan. `weighted_score_pareto_monotone`: positive-weight sums qualify.
- **[OPEN]**:
  - Whether Sy (L13) over trajectory progress is Pareto-monotone. Progress components can be negative, and Sy's cross term $-\lambda\Phi_+\Phi_-/(\Phi_++\Phi_-)$ couples gains and losses; until proved, `choose_plan_sound` is stated for any Pareto-monotone score, with positive-weight sums as the proved instance.
  - Estimating `prog` (trajectory-level progress over the horizon) from MetricModel predictions.

### 6.2 Build Coverage of Proposed Modules (SPEC-CHOICE)
- **Finding**: The `Benefuture` library built only modules reachable from `Benefuture.lean`. `Proposed/` modules are deliberately not imported by core, so they were never compiled in CI.
- **Fix**: `lakefile.toml` globs `Benefuture.+`, so every module under `Benefuture/` is compiled without core importing `Proposed/`.

---

## 7. Phase 7 Divergences (Coherence and Simulation Readiness)

### 7.1 Sy Signature, Value and Harm Weight (SPEC-CHOICE, from L13)
- **Source**: `Bf_Pseudocode.txt` L13 (`Sy_{κ,q₊}([(x, w_+ = 1, w_- = w_+)])`), L61 (`Ha_wt: 1 + Sy_{½,1.5}(…)`), L73 (`V := Sy_{2}(As([(U, α, Ha_wt), (H, β, α·Ha_wt), (N, γ)]))`); `Benefuture goals.txt` (V uses "κ = 2"; harm is "counted as a weight on losses"; Ha_wt is "a convex synergy score").
- **Divergences fixed**:
  - V applied α·Ha_wt to U gains as well as losses, and used the default κ. Now `net_synergy_signed` takes items (x, w₊, w₋); V uses U: (α, Ha_wt), H: (β, α·Ha_wt), N: (γ, γ), with κ = 2.
  - Ha_wt read `Sy_{½,1.5}` as q₊ = 0.5, q₋ = 1.5, making it concave in severity. Read through the L13 signature it is κ = ½, q₊ = 1.5 (convex). `harm_tier_superlinear` proves doubling a tier more than doubles its contribution.
  - The reference `V_ref` treated H as harm and swapped λ and κ in its test vector. Rewritten to match the spec.
- **Proved**: `net_synergy_signed_single_gain`, `net_synergy_signed_single_loss`, `net_synergy_signed_gain_ignores_loss_weight` (harm weight never touches a gain).

### 7.2 Loss-Aversion Inversion Resolved by Significance (resolves §2.3, [R])
- **Source**: L25 (`(Pm_i ≥ Th_Cx) ⇒ Sig`), L48 (`As := Norm(… | Th_Cx)`).
- **Resolution**: Sy's inputs are As outputs in threshold units. `significant_assessment_preserves_loss_aversion`: every significant input has magnitude ≥ 1, where $m^{q_+} \le m^{q_-}$. The inversion lives only below the significance threshold.

### 7.3 Weighted vs Lexical Harm Resolved by Fr (resolves §2.4, [P])
- **Source**: L61 (Ha_wt is a Sy-weighted sum), L135 (Fr excludes irreversible harm).
- **Resolution**: Both readings hold, at different layers. Fr removes irreversible and irreparable harm lexically before any weighting (`choose_plan_sound`, §6.1); Ha_wt weights the remaining tiers. No finite quantity of passing harm is ever traded against an irreversible one inside an admissible choice.

### 7.4 Delegation Cap from L114 (resolves §4.5 cap, [R])
- **Source**: L114 (`DelegateDnVote(S_i → S_j) if … CumulativeVoteWeight(S_j) < Th_k …`).
- **Resolution**: The cap is in the pseudocode. `accumulate_capped_bound`: under sequential delegation, a delegate's weight never exceeds Th_k + M, where M bounds a single delegator's weight. The star topology cannot form.

### 7.5 Reference Library Fidelity (simulation readiness)
- `As_ref` returned the raw measurement ex post and never normalised. Now `((t > t₀ ? Me : Pr) − Pr_counter) / Th_Cx`, matching `dynamic_assessment_real`.
- Added `Sy_signed_ref`, `HaWt_ref`, and population operators matching `Benefuture.Proposed.PopulationDirection`: `skew_key_ref`, `population_novelty_ref`, `effective_types_ref`, `pareto_front_ref`, `accumulate_capped_ref`.
- Vectors: `assessment.json` and `value.json` regenerated with `defaultGovParams`; new `population.json`. Values agree with the Lean theorems (e.g. skew key −81/128 → −1.0646; novelty of 5 copies = 1).

### 7.6 Pseudocode Copies
- The root `Bf_Pseudocode.txt` (2026-10-16) predated the decisions recorded in `spec/Bf_Pseudocode.txt` (2026-10-19). The root copy is now identical to `spec/`, the recorded source of truth.

### 7.7 Open Findings
- **Harm schedule ([P], resolved)**: `compute_harm_weight` used the generic 6-weight schedule against 8 tiers, silently dropping Culture_offence and NHa_Estd. It now uses `harmSchedule`, one weight per tier: 0.9 > 0.7 > 0.45 > 0.15 > 0.08 > 0.04 > 0.01 (NHa_Estd = 0 omitted).
- **Di in H ([P])**: L37 defines `H(t) := ∫Positive(Se) + BiasMitigation + Di`. Di is read as experiential variety within one life (`experiential_variety` = distinct experiences / total; `repetitive_experience_variety`, `experiential_variety_le_one`), distinct from N, which scores outcomes against ℝ. See §7.9 for the H score.

### 7.8 Fr per the Author's Reading of L135 ([R] reading, [P] parameters)
- **Source**: L135 `Fr := f_max(∃A, Imp, N, Po) | ¬Ha_(Estd ∨ Pr(P·severity>Th_high) ∨ irreversible)`. Author: Fr blocks established (not speculative) harm at long-term severity or worse, at high enough confidence; a mild chance of passing or time-loss harm does not block. Parameters chosen to match longtermist common sense.
- **Divergence fixed**: the previous Fr blocked any non-zero irreversible harm at any probability, which would block nearly every action.
- **Lean Spec Choice**: `HarmForecast` (profile + confidence), `FrParams`, `severity_score`, `established_severe`, `fr_permissible` (now `Fr`). Defaults: established at confidence 0.9; expected-severity ceiling 1; severities 1000 / 100 / 10 / 1 / 0.5 (irreparable / irreversible / long-term / passing / time loss).
- **Proved**: `fr_permissible_spec`, `established_severe_blocks`, `probable_severe_harm_blocks`; with defaults, `mild_passing_chance_permitted` (50% passing harm), `speculative_catastrophe_blocks` (1% irreparable), `remote_irreversible_chance_permitted` (0.1% irreversible), `certain_longterm_harm_blocks`.
- The certain-harm boundary `is_action_freedom_permissible` is kept as the special case used by the freedom metric.

### 7.9 Harm Reference Points and the H Score ([R])
- **Source**: L54 `Ha(t) := ↓U(t) ∨ ↓H(t)`, L37 `H := ∫Positive(Se) + BiasMitigation + Di`. Author: the H score is a positive structure; H-harm is a drop below the rolling average; U-harm is a drop below the being's running maximum. Coming down from a giddy rush is not harm; forgetting understood relationships is. Bias mitigation is done by MMs, which flag biased happiness (dark triad, malicious pleasure). Consistent with `Happiness.txt` ("rewarding boosts … leveling back to the optimal state") and `Harm.txt` ("reduces … over time").
- **Lean Spec Choice**: `HappinessSource` (intensity + MM flag), `happiness_score`, `rolling_average`, `h_harm`, `u_harm`.
- **Proved**: `happiness_score_nonneg`, `flagged_happiness_contributes_nothing`, `forgetting_is_harm`, `u_at_max_no_harm`, `h_at_or_above_average_no_harm`, `coming_down_not_harm` (window [1,1,1,5], H 5 → 2). `withholding_incurs_no_harm` (Proposed) now uses these reference points.
- **[OPEN]**: rolling-window length (a threshold, SigThGv).
