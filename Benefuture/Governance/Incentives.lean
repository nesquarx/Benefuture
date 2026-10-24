/-
  Benefuture.Governance.Incentives
  Formalization of Phase 4.5: Governance & Incentives.
  Covers:
  - Liquid Democracy Delegation Graph and Acyclicity (L114)
  - Delegation Cap and Star-Topology Power Concentration [OPEN]
  - Truth and Brier Score Strict Propriety (L34)
  - Bounty & Anti-Cobra Incentive Compatibility (L157)
  - Uncollateralized Exploit Vulnerability [OPEN]
  - Anti-Collusion Cyclic Review Attenuation (L117)
  Corresponds to: Bf_Pseudocode.txt L34, L114, L117, L157.
-/

import Mathlib.Data.Real.Basic
import Mathlib.Data.Finset.Basic
import Benefuture.Math.Order
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Entity
import Benefuture.Ontology.Domain
import Benefuture.Ontology.Reputation

namespace Benefuture.Governance

open Benefuture.Math
open Benefuture.Ontology

set_option linter.unusedVariables false

/-!
  # 1. Liquid Democracy Delegation & Acyclicity
  Corresponds to: Bf_Pseudocode.txt L114 ("acyclic delegation").
-/

/-- 
  [R] Delegation Graph: Directed mapping representing transitive proxy voting assignments.
  Each sophont can delegate their voting power to at most one proxy (out-degree ≤ 1).
-/
structure DelegationGraph (V : Type) [DecidableEq V] where
  delegatesTo : V → Option V
  /--
    [R] Acyclicity Invariant: The transitive closure of delegation contains no self-referential cycles.
    Modeled as an acyclic relation / strict well-founded ordering.
  -/
  acyclic : ∀ v : V, ∀ n : ℕ, n > 0 → (Nat.iterate (fun u => match delegatesTo u with | some w => w | none => u) n v = v → delegatesTo v = none)

/--
  [R] THEOREM: An acyclic delegation graph admits no non-trivial cycles.
-/
theorem delegation_no_trivial_cycles (V : Type) [DecidableEq V] (dg : DelegationGraph V) (v : V) :
    dg.delegatesTo v ≠ some v := by
  intro h_self
  have h_iter : Nat.iterate (fun u => match dg.delegatesTo u with | some w => w | none => u) 1 v = v := by
    dsimp [Nat.iterate]
    rw [h_self]
  have h_none := dg.acyclic v 1 (by decide) h_iter
  rw [h_self] at h_none
  contradiction

/--
  -- SPEC-CHOICE: Star-Topology Power Concentration ([OPEN]).
  In the absence of a delegation cap, if all N voters delegate to a single node D,
  node D controls 100% of voting weight, defeating democratic distribution.
-/
theorem star_topology_power_concentration (n : ℕ) (hn : n > 0) (baseWeight : ℝ) (h_base : baseWeight > 0) :
    let totalWeight := (n : ℝ) * baseWeight
    let concentratedWeight := (n : ℝ) * baseWeight
    concentratedWeight / totalWeight = 1 := by
  dsimp
  have h_pos : (n : ℝ) * baseWeight > 0 := by
    apply mul_pos
    · exact Nat.cast_pos.mpr hn
    · exact h_base
  exact div_self (ne_of_gt h_pos)

/--
  [P] Capped Delegation Proposal:
  No single delegate may hold more than `capRatio` (e.g., 0.05 = 5%) of total democratic weight.
-/
def SatisfiesDelegationCap (delegateWeight : ℝ) (totalWeight : ℝ) (capRatio : ℝ) : Prop :=
  totalWeight > 0 → delegateWeight ≤ capRatio * totalWeight

/--
  [R] Sequential delegation under the L114 rule: a delegation to S_j is accepted only while
  CumulativeVoteWeight(S_j) < Th_k. Returns S_j's weight after processing the delegators in order.
-/
def accumulate_capped (cap : ℝ) : ℝ → List ℝ → ℝ
  | cur, [] => cur
  | cur, w :: ws => accumulate_capped cap (if cur < cap then cur + w else cur) ws

/--
  [R] THEOREM: The L114 cap bounds concentration. If every delegator's weight is at most M and the
  delegate starts below cap + M, the delegate never exceeds cap + M, however many delegate to it.
  The star topology of `star_topology_power_concentration` cannot form under L114.
-/
theorem accumulate_capped_bound (cap M : ℝ) :
    ∀ (ws : List ℝ) (cur : ℝ), cur < cap + M → (∀ w ∈ ws, w ≤ M) →
      accumulate_capped cap cur ws < cap + M
  | [], cur, hcur, _ => hcur
  | w :: ws, cur, hcur, hw => by
    unfold accumulate_capped
    apply accumulate_capped_bound cap M ws
    · split_ifs with h
      · linarith [hw w List.mem_cons_self]
      · exact hcur
    · exact fun x hx => hw x (List.mem_cons_of_mem w hx)

/-!
  # 2. Truth and Brier Score Strict Propriety
  Corresponds to: Bf_Pseudocode.txt L34, Epistemology.txt §Truth.
-/

/--
  [R] Quadratic Brier Scoring Rule for binary predictions:
  Given reported probability p ∈ [0, 1] and actual outcome o ∈ {0, 1}:
  BrierScore(p, o) := (p - o)².
-/
def brier_score (p : ℝ) (o : ℝ) : ℝ :=
  (p - o)^2

/--
  [R] Expected Brier Loss under true subjective belief q ∈ [0, 1]:
  E_q[L(p)] = q * (p - 1)² + (1 - q) * p².
-/
def expected_brier_loss (p : ℝ) (q : ℝ) : ℝ :=
  q * (p - 1)^2 + (1 - q) * p^2

/--
  [R] Canonical algebraic decomposition of expected Brier loss:
  E_q[L(p)] = (p - q)² + q * (1 - q).
  The second term is the irreducible entropy of the event; the first is the calibration penalty.
-/
theorem expected_brier_decomposition (p q : ℝ) :
    expected_brier_loss p q = (p - q)^2 + q * (1 - q) := by
  unfold expected_brier_loss
  ring

/--
  [R] THEOREM: Strict Propriety of Brier Score.
  The unique global minimizer of expected Brier loss under belief q is reporting p = q.
  Any misreporting p ≠ q strictly increases expected loss by (p - q)² > 0.
-/
theorem brier_score_strictly_proper (p q : ℝ) (h_diff : p ≠ q) :
    expected_brier_loss q q < expected_brier_loss p q := by
  rw [expected_brier_decomposition p q, expected_brier_decomposition q q]
  have h_sq_zero : (q - q)^2 = 0 := by ring
  rw [h_sq_zero, zero_add]
  have h_sq_pos : 0 < (p - q)^2 := by
    have h_sub_ne : p - q ≠ 0 := sub_ne_zero.mpr h_diff
    exact sq_pos_of_ne_zero h_sub_ne
  linarith

/-!
  # 3. Bounty & Anti-Cobra Incentive Compatibility
  Corresponds to: Bf_Pseudocode.txt L157, Adversarial adaptation.txt §Nuance 1.
-/

/--
  [R] Anti-Cobra Expected Payoff:
  An agent who plants a flaw with societal damage D and attempts to claim bounty B
  faces detection probability pDetect. If detected, they must pay clawback C ≥ B + D.
  Expected Payoff:
    E[Payoff] = (1 - pDetect) * B + pDetect * (B - C) = B - pDetect * C.
-/
def bounty_farming_expected_payoff (bounty : ℝ) (clawback : ℝ) (pDetect : ℝ) : ℝ :=
  (1 - pDetect) * bounty + pDetect * (bounty - clawback)

theorem bounty_farming_payoff_eq (bounty clawback pDetect : ℝ) :
    bounty_farming_expected_payoff bounty clawback pDetect = bounty - pDetect * clawback := by
  unfold bounty_farming_expected_payoff
  ring

/--
  [R] Detection Threshold pThreshold = bounty / clawback.
  When pDetect > pThreshold, the expected payoff of bounty farming is strictly negative.
-/
noncomputable def cobra_detection_threshold (bounty : ℝ) (clawback : ℝ) : ℝ :=
  bounty / clawback

/--
  [R] THEOREM: Bounty Farming Incentive Compatibility.
  If clawback C ≥ bounty B + damage D (with D > 0, B > 0), and detection probability
  exceeds threshold B / C, then planting flaws is strictly unprofitable in expectation.
-/
theorem bounty_incentive_compatible (bounty clawback damage pDetect : ℝ)
    (h_bounty_pos : bounty > 0)
    (h_damage_pos : damage > 0)
    (h_clawback_rule : clawback ≥ bounty + damage)
    (h_prob : pDetect ≤ 1)
    (h_thresh : pDetect > cobra_detection_threshold bounty clawback) :
    bounty_farming_expected_payoff bounty clawback pDetect < 0 := by
  rw [bounty_farming_payoff_eq]
  unfold cobra_detection_threshold at h_thresh
  have h_claw_pos : clawback > 0 := by linarith
  have h_mul : pDetect * clawback > bounty := by
    have h1 := (div_lt_iff₀ h_claw_pos).mp h_thresh
    linarith
  linarith

/--
  -- SPEC-CHOICE: Uncollateralized Exploit Vulnerability ([OPEN]).
  If an adversary can extract external gain G_exploit (e.g. market short) exceeding clawback C,
  or if total entity assets W < C so clawback is uncollectible, the clawback rule fails to deter.
-/
structure UncollateralizedExploitVulnerability where
  externalGain   : ℝ
  clawback       : ℝ
  entityWealth   : ℝ
  h_gain_exceeds : externalGain > clawback ∨ entityWealth < clawback

/-!
  # 4. Anti-Collusion Cyclic Review Attenuation
  Corresponds to: Bf_Pseudocode.txt L117 ("EHR", "!halo, !horn, !transfer").
-/

/--
  [R] Cyclic endorsement pair between two colluding entities A and B.
  A awards positive reputation to B, and B awards positive reputation to A.
-/
structure CyclicReviewPair where
  weightAtoB : ℝ
  weightBtoA : ℝ
  h_pos_ab   : weightAtoB > 0
  h_pos_ba   : weightBtoA > 0

/--
  [R] EHR / Graph-based Attenuation:
  Effective reputation weight is discounted by cyclic cross-endorsement factor (1 - attenuationFactor).
  When attenuationFactor = 1, mutual cross-endorsements are completely zeroed out.
-/
def attenuate_cyclic_reviews (pair : CyclicReviewPair) (attenuationFactor : ℝ) : ℝ × ℝ :=
  (pair.weightAtoB * (1 - attenuationFactor), pair.weightBtoA * (1 - attenuationFactor))

theorem complete_cyclic_attenuation (pair : CyclicReviewPair) :
    (attenuate_cyclic_reviews pair 1) = (0, 0) := by
  unfold attenuate_cyclic_reviews
  simp

/--
  [OPEN] Sybil-Pair Resistance Limitation:
  If entities route endorsements through an arbitrary-length directed cycle (A → B → C → ... → A),
  local pair attenuation fails unless global cycle detection or eigenvector centrality (PageRank/EHR)
  is computed across the full graph.
-/
def SybilCycleDetectionRequirement (cycleLength : ℕ) : Prop :=
  cycleLength ≥ 3

end Benefuture.Governance
