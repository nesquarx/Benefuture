/-
  Benefuture.Proposed.OutcomeDistribution
  [P] Outcome-first causal distribution (L48, L93–98; author rulings, BACKPROPAGATION 8.14, 8.16,
  8.17). An outcome is an event whose understanding, happiness and novelty a metric model estimates
  per domain and being. Each contributor's causal contribution is assessed against its
  counterfactual: inaction, or the action a contract or communicated law committed it to.
  Contributions to one outcome are shared Shapley-style over the coalitions of contributors; positive
  shares are paid and negative shares penalised, each side normalised within [0, 1].

  IMPORTANT ARCHITECTURAL RULE: core Benefuture modules MUST NOT import this file.
-/

import Mathlib.Data.Real.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Nat.Factorial.Basic
import Mathlib.Data.Finset.Powerset
import Mathlib.Algebra.Order.BigOperators.Group.Finset
import Mathlib.Tactic.Linarith

namespace Benefuture.Proposed

open Finset

/-- [P] The counterfactual a contributor is assessed against (L48; author ruling 8.17): not acting
    (¬A := ∄Ou(actor)), or the action a contract, including a law once communicated, committed it to,
    given as its predicted outcome. -/
inductive Counterfactual where
  | inaction
  | committed (predictedOutcome : ℝ)

/-- [P] Assessment of a measured outcome against a counterfactual, normalised by the context
    threshold; `prInaction` is the predicted outcome of not acting. -/
noncomputable def assess_against (measured prInaction th : ℝ) : Counterfactual → ℝ
  | .inaction => (measured - prInaction) / th
  | .committed pr => (measured - pr) / th

/-- THEOREM: A duty left undone is negative: when the committed action would have produced a better
    outcome than what was measured (a driver bound to brake who does not), the assessment is
    negative. -/
theorem breached_duty_assessed_negative (measured prInaction committed th : ℝ) (hth : 0 < th)
    (h : measured < committed) : assess_against measured prInaction th (.committed committed) < 0 := by
  unfold assess_against
  exact div_neg_of_neg_of_pos (by linarith) hth

/-- THEOREM: Without a committed action, not acting is assessed at zero: its counterfactual is
    itself (a bystander with no duty). -/
theorem inaction_without_duty_assessed_zero (x th : ℝ) : assess_against x x th .inaction = 0 := by
  simp [assess_against]

/-- [P] Shapley share of contributor `i` in an outcome, from the coalition values `v` a metric model
    assesses (v S: the outcome had only the contributors in S acted, the others at their
    counterfactuals). -/
noncomputable def shapley {ι : Type*} [DecidableEq ι] (N : Finset ι) (v : Finset ι → ℝ) (i : ι) : ℝ :=
  ∑ S ∈ (N.erase i).powerset,
    ((S.card.factorial * (N.card - S.card - 1).factorial : ℕ) : ℝ) / (N.card.factorial : ℝ) *
      (v (insert i S) - v S)

/-- THEOREM: Null contributor. A contributor whose presence changes no coalition's assessed outcome
    receives nothing: no share without an assessed contribution. -/
theorem shapley_null {ι : Type*} [DecidableEq ι] (N : Finset ι) (v : Finset ι → ℝ) (i : ι)
    (h : ∀ S ∈ (N.erase i).powerset, v (insert i S) = v S) : shapley N v i = 0 := by
  unfold shapley
  exact Finset.sum_eq_zero fun S hS => by rw [h S hS, sub_self, mul_zero]

/-- [P] The two sides of an outcome's shares: positive shares are paid, negative shares penalised. -/
noncomputable def side_pos {ι : Type*} (N : Finset ι) (φ : ι → ℝ) : ℝ := ∑ i ∈ N, max (φ i) 0
noncomputable def side_neg {ι : Type*} (N : Finset ι) (φ : ι → ℝ) : ℝ := ∑ i ∈ N, min (φ i) 0

/-- THEOREM: What is paid plus what is penalised is exactly the sum of the shares: nothing is
    distributed twice and nothing is lost. -/
theorem sides_sum {ι : Type*} (N : Finset ι) (φ : ι → ℝ) :
    side_pos N φ + side_neg N φ = ∑ i ∈ N, φ i := by
  unfold side_pos side_neg
  rw [← Finset.sum_add_distrib]
  exact Finset.sum_congr rfl fun i _ => by rw [max_add_min, add_zero]

/-- THEOREM: On the paid side, each contributor's causal contribution, its share over the side's
    total, lies in [0, 1] (L93). -/
theorem paid_share_in_unit {ι : Type*} (N : Finset ι) (φ : ι → ℝ) (i : ι) (hi : i ∈ N)
    (hφ : 0 ≤ φ i) (hP : 0 < side_pos N φ) : 0 ≤ φ i / side_pos N φ ∧ φ i / side_pos N φ ≤ 1 := by
  have hle : φ i ≤ side_pos N φ := by
    have h1 : max (φ i) 0 ≤ side_pos N φ :=
      Finset.single_le_sum (f := fun j => max (φ j) 0) (fun j _ => le_max_right _ _) hi
    have h2 : max (φ i) 0 = φ i := max_eq_left hφ
    linarith
  exact ⟨div_nonneg hφ hP.le, (div_le_one hP).mpr hle⟩

end Benefuture.Proposed
