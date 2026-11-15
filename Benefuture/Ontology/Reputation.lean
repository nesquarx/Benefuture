/-
  Benefuture.Ontology.Reputation
  [R] Formalization of Domain-Specific 4-Component Reputation:
  Re(E, d) = { hPos : ℝ≥0, hNeg : ℝ≥0, prAcc : ℝ, rel : ℝ }
  Corresponds to: Bf_Pseudocode.txt L100-101, L113-114, L117.
  "Reputation«Re»(t, CD, Dn) := Σ(CC(U(Dn), H(Dn)) + N(Dn)),"
  "Re(E, Dn) = [ΣRe_+ve, ΣRe_-ve, PrAcc, Relevance := Re_net - Decay]_Dn ← recount(Mem), ∄Re(E, ¬Dn), !halo, !horn, !transfer;"
-/

import Mathlib.Data.Real.Basic
import Mathlib.Data.Finset.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Ring.Finset
import Mathlib.Algebra.Order.BigOperators.Group.Finset
import Mathlib.Analysis.SpecialFunctions.Exp
import Mathlib.Tactic.Linarith
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Domain

namespace Benefuture.Ontology

open Benefuture.Math

/- =========================================================================
   3.3 COMPONENT TYPING
   Distinct types for history and relevance to enforce correct consumer usage.
   - EHR uses ReHistory (L118: Re_+ve, Re_-ve)
   - BfDm, LqdBfDm, BalOvflw, SourceVerify use ReRelevance
   ========================================================================= -/

/-- 
  [R] Un-decayed historical reputation counter (hPos, hNeg).
  Logs cumulative verified positive contributions and negative infractions.
  Never decays.
-/
structure ReHistory where
  hPos : ℝ
  hNeg : ℝ
  hPos_nonneg : 0 ≤ hPos
  hNeg_nonneg : 0 ≤ hNeg

/-- 
  [R] Decayed synthesized relevance score.
  The only component subject to temporal decay.
-/
structure ReRelevance where
  rel : ℝ

/--
  [R] Prediction accuracy component of domain reputation (author ruling 8.149; L101 `PrAcc`).
  Captures proper-scored calibration history in domain d and unblocks weighted binding (8.70).
-/
structure RePredictionAccuracy where
  prAcc : ℝ

/-- 
  [R] Complete 4-Component Reputation view for an Entity in a Leaf Domain.
  Re(E, d) = [hPos, hNeg, prAcc, rel]_d (author ruling 8.149; L101).
  Includes compensating retracted counter hRetracted so hPos and hNeg never decrease.
-/
structure Re where
  history    : ReHistory
  relevance  : ReRelevance
  prAcc      : RePredictionAccuracy := { prAcc := 0 }
  hRetracted : ℝ := 0
  hRetracted_nonneg : 0 ≤ hRetracted := by linarith

/-- 
  Attributed Action Record in immutable Memory (Mem):
  Reputation is a pure view derived from Mem records, never an authoritative state field.
-/
structure AttributedAction where
  actionId              : String
  timestamp             : ℝ
  leafShares            : LeafDomain → ℝ
  positiveContribution  : ℝ
  negativeContribution  : ℝ
  causalContribution    : String → ℝ -- CC(a, E) ∈ [0, 1]
  h_shares_nonneg       : ∀ l, 0 ≤ leafShares l
  h_pos_nonneg          : 0 ≤ positiveContribution
  h_neg_nonneg          : 0 ≤ negativeContribution
  h_cc_nonneg           : ∀ e, 0 ≤ causalContribution e

/-- 
  [R] Compute hPos: Cumulative positive contributions attributed to entity in leaf domain d.
  hPos = Σ_a share(a, d) * CC(a, E) * a.pos.
-/
def compute_hPos (mem : List AttributedAction) (eId : String) (d : LeafDomain) : ℝ :=
  (mem.map (fun a => a.leafShares d * (a.causalContribution eId * a.positiveContribution))).sum

/-- 
  [R] Compute hNeg: Cumulative negative infractions attributed to entity in leaf domain d.
  hNeg = Σ_a share(a, d) * CC(a, E) * a.neg.
-/
def compute_hNeg (mem : List AttributedAction) (eId : String) (d : LeafDomain) : ℝ :=
  (mem.map (fun a => a.leafShares d * (a.causalContribution eId * a.negativeContribution))).sum

/-- Action decay rate selector based on contribution sign (L101 shorthand vs per-action decay). -/
noncomputable def action_decay_rate (signedContrib : ℝ) (lambdaPos lambdaNeg : ℝ) : ℝ :=
  if signedContrib ≥ 0 then lambdaPos else lambdaNeg

/-- 
  [P] Per-action exponential decay for Relevance (reads 'older activities contribute lesser'):
  rel(E, d, t) = Σ_a share(a, d) · signedContribution(a, E) · e^{−λ_sign (t − t_a)}.
-/
noncomputable def compute_rel (mem : List AttributedAction) (eId : String) (d : LeafDomain) (t : ℝ)
    (lambdaPos lambdaNeg : ℝ) : ℝ :=
  (mem.map (fun a =>
    let signed := a.causalContribution eId * (a.positiveContribution - a.negativeContribution)
    let lam := action_decay_rate signed lambdaPos lambdaNeg
    a.leafShares d * signed * Real.exp (- lam * (t - a.timestamp)))).sum

/-- 
  [R] Subtractive reading of L101 kept as an alternative definition:
  rel_subtractive := hPos - hNeg - decay.
-/
def compute_rel_subtractive (mem : List AttributedAction) (eId : String) (d : LeafDomain) (decay : ℝ) : ℝ :=
  compute_hPos mem eId d - compute_hNeg mem eId d - decay

/-- Helper lemma: hPos is non-negative. -/
theorem compute_hPos_nonneg (mem : List AttributedAction) (eId : String) (d : LeafDomain) :
    0 ≤ compute_hPos mem eId d := by
  unfold compute_hPos
  induction mem with
  | nil => simp
  | cons head tail ih =>
    simp only [List.map_cons, List.sum_cons]
    have h_prod : 0 ≤ head.leafShares d * (head.causalContribution eId * head.positiveContribution) := by
      apply mul_nonneg (head.h_shares_nonneg d)
      exact mul_nonneg (head.h_cc_nonneg eId) head.h_pos_nonneg
    linarith

/-- Helper lemma: hNeg is non-negative. -/
theorem compute_hNeg_nonneg (mem : List AttributedAction) (eId : String) (d : LeafDomain) :
    0 ≤ compute_hNeg mem eId d := by
  unfold compute_hNeg
  induction mem with
  | nil => simp
  | cons head tail ih =>
    simp only [List.map_cons, List.sum_cons]
    have h_prod : 0 ≤ head.leafShares d * (head.causalContribution eId * head.negativeContribution) := by
      apply mul_nonneg (head.h_shares_nonneg d)
      exact mul_nonneg (head.h_cc_nonneg eId) head.h_neg_nonneg
    linarith

/-- 
  [R] Reputation View: Derived from Mem, never a State field.
-/
noncomputable def re_view (mem : List AttributedAction) (eId : String) (d : LeafDomain) (t : ℝ)
    (lambdaPos lambdaNeg : ℝ) (predAcc : ℝ := 0) (retracted : ℝ := 0)
    (h_ret_nonneg : 0 ≤ retracted := by linarith) : Re := {
  history := {
    hPos := compute_hPos mem eId d,
    hNeg := compute_hNeg mem eId d,
    hPos_nonneg := compute_hPos_nonneg mem eId d,
    hNeg_nonneg := compute_hNeg_nonneg mem eId d
  },
  relevance := {
    rel := compute_rel mem eId d t lambdaPos lambdaNeg
  },
  prAcc := {
    prAcc := predAcc
  },
  hRetracted := retracted,
  hRetracted_nonneg := h_ret_nonneg
}

/- =========================================================================
   3.3 DECISION PROFILES & VOTING WEIGHT
   Type rule: NO exported function Entity → ℝ that aggregates across domains.
   Every consumer takes a normalized decision profile [(leaf_i, ŵ_i)] with Σ ŵ_i = 1.
   ========================================================================= -/

/-- 
  [R] Decision Profile: Normalized leaf domain distribution with Σ ŵ_i = 1.
  Dn(D) = [(leaf_i, ŵ_i)].
-/
structure DecisionProfile (leaves : Finset LeafDomain) where
  weights          : LeafDomain → ℝ
  h_weights_nonneg : ∀ l, 0 ≤ weights l
  h_sum_one        : leaves.sum weights = 1
  h_support        : ∀ l, l ∉ leaves → weights l = 0

/-- 
  [R] Expert Voting Weight formula:
  VW_expert(E, D) = Σ_i ŵ_i · f(rel(E, leaf_i)).
  Purely a weighted combination of leaf relevance scores.
-/
def VW_expert {leaves : Finset LeafDomain} (dp : DecisionProfile leaves)
    (relScores : LeafDomain → ReRelevance) (f : ℝ → ℝ) : ℝ :=
  leaves.sum (fun l => dp.weights l * f (relScores l).rel)

/-- 
  [R] External Harm Response (EHR, L118):
  TitForTat + α·Σ_d ŵ(Ha_i,d)·hPos(j,d)·P(Forgive) + δ·Σ_d ŵ(Ha_i,d)·hNeg(j,d)·P(Overreact).
  External aggressors carry statistical (low-precision) reputation with uncertainty.
-/
structure ExternalAggressorReputation where
  hPos : ℝ
  hNeg : ℝ
  uncertainty : ℝ -- Lower precision / variance

def external_harm_response {leaves : Finset LeafDomain}
    (titForTat : ℝ) (harmWeights : LeafDomain → ℝ)
    (hPos hNeg : LeafDomain → ℝ) (pForgive pOverreact : ℝ) (alpha delta : ℝ) : ℝ :=
  titForTat +
  alpha * (leaves.sum (fun d => harmWeights d * hPos d)) * pForgive +
  delta * (leaves.sum (fun d => harmWeights d * hNeg d)) * pOverreact

/- =========================================================================
   VERIFIED SPECIFICATION THEOREMS
   ========================================================================= -/

/-- 
  THEOREM: Conservation of Positive Attributed Contributions.
  Summing hPos across all leaf domains equals the total attributed positive value.
-/
theorem conservation_positive (actions : List AttributedAction) (leaves : Finset LeafDomain)
    (eId : String)
    (h_shares_sum : ∀ a ∈ actions, leaves.sum a.leafShares = 1) :
    leaves.sum (fun l => compute_hPos actions eId l) =
    (actions.map (fun a => a.causalContribution eId * a.positiveContribution)).sum := by
  induction actions with
  | nil =>
    simp only [compute_hPos, List.map_nil, List.sum_nil]
    simp
  | cons head tail ih =>
    have h_tail_sum : ∀ a ∈ tail, leaves.sum a.leafShares = 1 := by
      intro a ha; exact h_shares_sum a (List.mem_cons_of_mem head ha)
    have h_head_sum : leaves.sum head.leafShares = 1 :=
      h_shares_sum head (by simp)
    unfold compute_hPos
    simp only [List.map_cons, List.sum_cons]
    rw [Finset.sum_add_distrib]
    have h_head_term : leaves.sum (fun l => head.leafShares l * (head.causalContribution eId * head.positiveContribution)) =
                       head.causalContribution eId * head.positiveContribution := by
      rw [← Finset.sum_mul, h_head_sum, one_mul]
    rw [h_head_term]
    have h_tail_eq : leaves.sum (fun l => (tail.map (fun a => a.leafShares l * (a.causalContribution eId * a.positiveContribution))).sum) =
                     leaves.sum (fun l => compute_hPos tail eId l) := rfl
    rw [h_tail_eq, ih h_tail_sum]

/-- 
  THEOREM: Conservation of Negative Attributed Infractions.
  Summing hNeg across all leaf domains equals the total attributed negative infractions.
-/
theorem conservation_negative (actions : List AttributedAction) (leaves : Finset LeafDomain)
    (eId : String)
    (h_shares_sum : ∀ a ∈ actions, leaves.sum a.leafShares = 1) :
    leaves.sum (fun l => compute_hNeg actions eId l) =
    (actions.map (fun a => a.causalContribution eId * a.negativeContribution)).sum := by
  induction actions with
  | nil =>
    simp only [compute_hNeg, List.map_nil, List.sum_nil]
    simp
  | cons head tail ih =>
    have h_tail_sum : ∀ a ∈ tail, leaves.sum a.leafShares = 1 := by
      intro a ha; exact h_shares_sum a (List.mem_cons_of_mem head ha)
    have h_head_sum : leaves.sum head.leafShares = 1 :=
      h_shares_sum head (by simp)
    unfold compute_hNeg
    simp only [List.map_cons, List.sum_cons]
    rw [Finset.sum_add_distrib]
    have h_head_term : leaves.sum (fun l => head.leafShares l * (head.causalContribution eId * head.negativeContribution)) =
                       head.causalContribution eId * head.negativeContribution := by
      rw [← Finset.sum_mul, h_head_sum, one_mul]
    rw [h_head_term]
    have h_tail_eq : leaves.sum (fun l => (tail.map (fun a => a.leafShares l * (a.causalContribution eId * a.negativeContribution))).sum) =
                     leaves.sum (fun l => compute_hNeg tail eId l) := rfl
    rw [h_tail_eq, ih h_tail_sum]

/-- 
  THEOREM: Locality of Reputation.
  If an action has zero share in domain d, it does not affect hPos, hNeg, or rel in domain d.
-/
theorem reputation_locality (mem : List AttributedAction) (a : AttributedAction)
    (eId : String) (d : LeafDomain) (t : ℝ) (lp ln : ℝ)
    (h_zero_share : a.leafShares d = 0) :
    compute_hPos (a :: mem) eId d = compute_hPos mem eId d ∧
    compute_hNeg (a :: mem) eId d = compute_hNeg mem eId d ∧
    compute_rel (a :: mem) eId d t lp ln = compute_rel mem eId d t lp ln := by
  constructor
  · unfold compute_hPos
    simp [h_zero_share]
  · constructor
    · unfold compute_hNeg
      simp [h_zero_share]
    · unfold compute_rel
      simp [h_zero_share]

/-- 
  THEOREM: No Transfer of Reputation.
  If an entity has zero causal contribution to an action (CC(a, E') = 0),
  the action contributes identically zero to E''s reputation across all domains.
-/
theorem reputation_no_transfer (a : AttributedAction) (eId : String) (d : LeafDomain)
    (h_zero_cc : a.causalContribution eId = 0) :
    a.leafShares d * (a.causalContribution eId * a.positiveContribution) = 0 ∧
    a.leafShares d * (a.causalContribution eId * a.negativeContribution) = 0 := by
  constructor
  · rw [h_zero_cc, zero_mul, mul_zero]
  · rw [h_zero_cc, zero_mul, mul_zero]

/-- 
  THEOREM: Non-Decreasing History (Append-Only Invariant).
  Appending an attributed action to Mem can only increase or preserve hPos and hNeg.
-/
theorem hPos_nondecreasing_on_append (mem : List AttributedAction) (a : AttributedAction)
    (eId : String) (d : LeafDomain) :
    compute_hPos mem eId d ≤ compute_hPos (a :: mem) eId d := by
  unfold compute_hPos
  simp only [List.map_cons, List.sum_cons]
  have h_add : 0 ≤ a.leafShares d * (a.causalContribution eId * a.positiveContribution) := by
    apply mul_nonneg (a.h_shares_nonneg d)
    exact mul_nonneg (a.h_cc_nonneg eId) a.h_pos_nonneg
  linarith

theorem hNeg_nondecreasing_on_append (mem : List AttributedAction) (a : AttributedAction)
    (eId : String) (d : LeafDomain) :
    compute_hNeg mem eId d ≤ compute_hNeg (a :: mem) eId d := by
  unfold compute_hNeg
  simp only [List.map_cons, List.sum_cons]
  have h_add : 0 ≤ a.leafShares d * (a.causalContribution eId * a.negativeContribution) := by
    apply mul_nonneg (a.h_shares_nonneg d)
    exact mul_nonneg (a.h_cc_nonneg eId) a.h_neg_nonneg
  linarith

/-- 
  THEOREM: Relevance Tends to Zero Under Inactivity (Per-Action Decay).
  For any single activity with positive decay rate λ > 0, the weight e^{-λ * Δt}
  strictly decreases towards zero as Δt increases.
-/
theorem exp_decay_strictly_decreasing (lam : ℝ) (h_lam : 0 < lam) (t1 t2 : ℝ) (h_t : t1 < t2) :
    Real.exp (-lam * t2) < Real.exp (-lam * t1) := by
  apply Real.exp_lt_exp.mpr
  nlinarith

/--
  THEOREM (author ruling 8.149): `re_view` exposes prediction accuracy (`PrAcc`) as the fourth
  component of the reputation view alongside `history`, `relevance`, and `hRetracted`.
-/
theorem re_view_prAcc_eq (mem : List AttributedAction) (eId : String) (d : LeafDomain) (t : ℝ)
    (lp ln predAcc retracted : ℝ) (h_ret_nonneg : 0 ≤ retracted) :
    (re_view mem eId d t lp ln predAcc retracted h_ret_nonneg).prAcc.prAcc = predAcc :=
  rfl

/--
  [R] Per-relation attributed positive history (author ruling 8.156):
  each action supplies a `RelationPartitionOfUnity leaves` so its share vector sums to 1 within
  each `RelationType` (`causal`, `structural`, `communicative`), keeping shares independent across types.
-/
def compute_hPos_rel {leaves : Finset LeafDomain}
    (actions : List AttributedAction)
    (partitions : AttributedAction → RelationPartitionOfUnity leaves)
    (r : RelationType) (eId : String) (d : LeafDomain) : ℝ :=
  (actions.map (fun a => (partitions a).share r d * (a.causalContribution eId * a.positiveContribution))).sum

/--
  [R] Per-relation attributed negative infractions (author ruling 8.156).
-/
def compute_hNeg_rel {leaves : Finset LeafDomain}
    (actions : List AttributedAction)
    (partitions : AttributedAction → RelationPartitionOfUnity leaves)
    (r : RelationType) (eId : String) (d : LeafDomain) : ℝ :=
  (actions.map (fun a => (partitions a).share r d * (a.causalContribution eId * a.negativeContribution))).sum

/-- Non-negativity of per-relation `hPos`. -/
theorem compute_hPos_rel_nonneg {leaves : Finset LeafDomain}
    (actions : List AttributedAction)
    (partitions : AttributedAction → RelationPartitionOfUnity leaves)
    (r : RelationType) (eId : String) (d : LeafDomain) :
    0 ≤ compute_hPos_rel actions partitions r eId d := by
  unfold compute_hPos_rel
  induction actions with
  | nil => simp
  | cons head tail ih =>
    simp only [List.map_cons, List.sum_cons]
    have h_prod : 0 ≤ (partitions head).share r d * (head.causalContribution eId * head.positiveContribution) := by
      apply mul_nonneg ((partitions head).h_nonneg r d)
      exact mul_nonneg (head.h_cc_nonneg eId) head.h_pos_nonneg
    linarith

/--
  THEOREM (author ruling 8.156): Conservation of Positive Attributed Contributions Per Relation Type.
  Within any relation type `r`, summing `compute_hPos_rel` across all leaf domains equals the total
  attributed positive contribution.
-/
theorem conservation_positive_per_relation {leaves : Finset LeafDomain}
    (actions : List AttributedAction)
    (partitions : AttributedAction → RelationPartitionOfUnity leaves)
    (r : RelationType) (eId : String) :
    leaves.sum (fun l => compute_hPos_rel actions partitions r eId l) =
    (actions.map (fun a => a.causalContribution eId * a.positiveContribution)).sum := by
  induction actions with
  | nil =>
    simp only [compute_hPos_rel, List.map_nil, List.sum_nil]
    simp
  | cons head tail ih =>
    unfold compute_hPos_rel
    simp only [List.map_cons, List.sum_cons]
    rw [Finset.sum_add_distrib]
    have h_head_term :
        leaves.sum (fun l => (partitions head).share r l * (head.causalContribution eId * head.positiveContribution)) =
        head.causalContribution eId * head.positiveContribution := by
      rw [← Finset.sum_mul, (partitions head).h_sum_one r, one_mul]
    rw [h_head_term]
    have h_tail_eq :
        leaves.sum (fun l => (tail.map (fun a => (partitions a).share r l * (a.causalContribution eId * a.positiveContribution))).sum) =
        leaves.sum (fun l => compute_hPos_rel tail partitions r eId l) := rfl
    rw [h_tail_eq, ih]

/--
  THEOREM (author ruling 8.156): Conservation of Negative Attributed Infractions Per Relation Type.
  Within any relation type `r`, summing `compute_hNeg_rel` across all leaf domains equals the total
  attributed negative infractions.
-/
theorem conservation_negative_per_relation {leaves : Finset LeafDomain}
    (actions : List AttributedAction)
    (partitions : AttributedAction → RelationPartitionOfUnity leaves)
    (r : RelationType) (eId : String) :
    leaves.sum (fun l => compute_hNeg_rel actions partitions r eId l) =
    (actions.map (fun a => a.causalContribution eId * a.negativeContribution)).sum := by
  induction actions with
  | nil =>
    simp only [compute_hNeg_rel, List.map_nil, List.sum_nil]
    simp
  | cons head tail ih =>
    unfold compute_hNeg_rel
    simp only [List.map_cons, List.sum_cons]
    rw [Finset.sum_add_distrib]
    have h_head_term :
        leaves.sum (fun l => (partitions head).share r l * (head.causalContribution eId * head.negativeContribution)) =
        head.causalContribution eId * head.negativeContribution := by
      rw [← Finset.sum_mul, (partitions head).h_sum_one r, one_mul]
    rw [h_head_term]
    have h_tail_eq :
        leaves.sum (fun l => (tail.map (fun a => (partitions a).share r l * (a.causalContribution eId * a.negativeContribution))).sum) =
        leaves.sum (fun l => compute_hNeg_rel tail partitions r eId l) := rfl
    rw [h_tail_eq, ih]

/--
  THEOREM (author ruling 8.156): No Double Counting in Parent-Domain Per-Relation History.
  Aggregating `compute_hPos_rel` at any parent domain `p` within relation type `r` cannot exceed
  the total attributed positive contribution.
-/
theorem aggregate_hPos_per_relation_no_double_count {leaves : Finset LeafDomain}
    (p : ParentDomain leaves) (actions : List AttributedAction)
    (partitions : AttributedAction → RelationPartitionOfUnity leaves)
    (r : RelationType) (eId : String) :
    aggregate_at_parent p (fun l => compute_hPos_rel actions partitions r eId l) ≤
    (actions.map (fun a => a.causalContribution eId * a.positiveContribution)).sum := by
  unfold aggregate_at_parent
  have h_le :
      leaves.sum (fun l => p.μ l * compute_hPos_rel actions partitions r eId l) ≤
      leaves.sum (fun l => compute_hPos_rel actions partitions r eId l) := by
    apply Finset.sum_le_sum
    intro l _
    have h_nonneg := compute_hPos_rel_nonneg actions partitions r eId l
    have h_mu := p.h_μ_bound l
    nlinarith
  rw [conservation_positive_per_relation actions partitions r eId] at h_le
  exact h_le

end Benefuture.Ontology
