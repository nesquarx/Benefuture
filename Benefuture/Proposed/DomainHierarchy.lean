/-
  Benefuture.Proposed.DomainHierarchy
  [P] Proposed Instantiation of Parent Domain Fuzzy Membership Degrees (μ_p).
  Computes fuzzy subsethood S(x, y) over actions (not actors), CE-weighted:
    S(x,y) = Σ_a min(m(a,x), m(a,y))·CE(a) / Σ_a m(a,x)·CE(a),
  with a confidence factor for sparse evidence.
  
  IMPORTANT ARCHITECTURAL RULE:
  The core Benefuture modules MUST NOT import this file. This is a swappable proposed default.
-/

import Mathlib.Data.Real.Basic
import Mathlib.Data.Finset.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.Order.BigOperators.Group.Finset
import Mathlib.Tactic.Linarith
import Mathlib.Order.FixedPoints

namespace Benefuture.Proposed

/-- 
  [P] Fuzzy subsethood of domain x in domain y over observed actions:
  S(x, y) := (Σ_a min(m(a,x), m(a,y)) · CE(a)) / (Σ_a m(a,x) · CE(a)).
  Measures the degree to which actions in domain x are also causally within domain y.
-/
noncomputable def fuzzy_subsethood {Action : Type*} [DecidableEq Action]
    (actions : Finset Action)
    (m : Action → String → ℝ)
    (CE : Action → ℝ)
    (x y : String) : ℝ :=
  let num := actions.sum (fun a => min (m a x) (m a y) * CE a)
  let den := actions.sum (fun a => m a x * CE a)
  if den = 0 then 0 else num / den

/-- 
  [P] Confidence factor for sparse evidence:
  conf(n, k) = n / (n + k).
  Dampens subsethood when sample size n is small relative to prior strength k > 0.
-/
noncomputable def confidence_factor (n : ℝ) (k : ℝ) : ℝ :=
  if n + k ≤ 0 then 0 else n / (n + k)

/-- 
  [P] Confidence-weighted subsethood:
  S_conf(x, y) = S(x, y) * conf(evidence_count, k).
-/
noncomputable def S_with_confidence {Action : Type*} [DecidableEq Action]
    (actions : Finset Action)
    (m : Action → String → ℝ)
    (CE : Action → ℝ)
    (k : ℝ)
    (x y : String) : ℝ :=
  let raw_S := fuzzy_subsethood actions m CE x y
  let n : ℝ := (actions.filter (fun a => m a x > 0)).card
  raw_S * confidence_factor n k

/-- 
  LEMMA: S(x, y) is in the Unit Interval [0, 1].
  Assuming non-negative memberships, positive CE weights, and non-empty support.
-/
theorem fuzzy_subsethood_in_unit_interval {Action : Type*} [DecidableEq Action]
    (actions : Finset Action)
    (m : Action → String → ℝ)
    (CE : Action → ℝ)
    (x y : String)
    (hm_nonneg : ∀ a d, 0 ≤ m a d)
    (hCE_pos : ∀ a, 0 < CE a)
    (h_den_pos : 0 < actions.sum (fun a => m a x * CE a)) :
    0 ≤ fuzzy_subsethood actions m CE x y ∧ fuzzy_subsethood actions m CE x y ≤ 1 := by
  unfold fuzzy_subsethood
  have h_den_ne : actions.sum (fun a => m a x * CE a) ≠ 0 := ne_of_gt h_den_pos
  simp only [h_den_ne, ite_false]
  have h_num_nonneg : 0 ≤ actions.sum (fun a => min (m a x) (m a y) * CE a) := by
    apply Finset.sum_nonneg
    intro a _
    have hmin : 0 ≤ min (m a x) (m a y) := le_min (hm_nonneg a x) (hm_nonneg a y)
    exact mul_nonneg hmin (le_of_lt (hCE_pos a))
  have h_num_le_den : actions.sum (fun a => min (m a x) (m a y) * CE a) ≤ actions.sum (fun a => m a x * CE a) := by
    apply Finset.sum_le_sum
    intro a _
    have hmin_le : min (m a x) (m a y) ≤ m a x := min_le_left (m a x) (m a y)
    exact mul_le_mul_of_nonneg_right hmin_le (le_of_lt (hCE_pos a))
  constructor
  · exact div_nonneg h_num_nonneg (le_of_lt h_den_pos)
  · exact (div_le_one h_den_pos).mpr h_num_le_den

/-- 
  LEMMA: Self-Subsethood is Identically One (S(x, x) = 1).
  A domain is a total subset of itself whenever its support is non-empty.
-/
theorem fuzzy_subsethood_self {Action : Type*} [DecidableEq Action]
    (actions : Finset Action)
    (m : Action → String → ℝ)
    (CE : Action → ℝ)
    (x : String)
    (h_den_pos : 0 < actions.sum (fun a => m a x * CE a)) :
    fuzzy_subsethood actions m CE x x = 1 := by
  unfold fuzzy_subsethood
  have h_den_ne : actions.sum (fun a => m a x * CE a) ≠ 0 := ne_of_gt h_den_pos
  simp only [h_den_ne, ite_false]
  have h_num_eq : (fun a => min (m a x) (m a x) * CE a) = (fun a => m a x * CE a) := by
    funext a
    rw [min_self]
  rw [h_num_eq]
  exact div_self h_den_ne

/-- 
  LEMMA: Support Containment Implies S(x, y) = 1.
  If for all observed actions, the membership of a in x is less than or equal to y,
  then x is completely contained in y (S(x, y) = 1).
-/
theorem fuzzy_subsethood_of_support_contained {Action : Type*} [DecidableEq Action]
    (actions : Finset Action)
    (m : Action → String → ℝ)
    (CE : Action → ℝ)
    (x y : String)
    (h_le : ∀ a ∈ actions, m a x ≤ m a y)
    (h_den_pos : 0 < actions.sum (fun a => m a x * CE a)) :
    fuzzy_subsethood actions m CE x y = 1 := by
  unfold fuzzy_subsethood
  have h_den_ne : actions.sum (fun a => m a x * CE a) ≠ 0 := ne_of_gt h_den_pos
  simp only [h_den_ne, ite_false]
  have h_num_eq : actions.sum (fun a => min (m a x) (m a y) * CE a) = actions.sum (fun a => m a x * CE a) := by
    apply Finset.sum_congr rfl
    intro a ha
    rw [min_eq_left (h_le a ha)]
  rw [h_num_eq]
  exact div_self h_den_ne

/-- 
  LEMMA: Invariance under Renaming Domains.
  Renaming domains via a bijection preserving memberships leaves S(x, y) invariant.
-/
theorem fuzzy_subsethood_rename_invariant {Action : Type*} [DecidableEq Action]
    (actions : Finset Action)
    (m m' : Action → String → ℝ)
    (CE : Action → ℝ)
    (x y x' y' : String)
    (hx : ∀ a ∈ actions, m' a x' = m a x)
    (hy : ∀ a ∈ actions, m' a y' = m a y) :
    fuzzy_subsethood actions m' CE x' y' = fuzzy_subsethood actions m CE x y := by
  unfold fuzzy_subsethood
  have h_num : actions.sum (fun a => min (m' a x') (m' a y') * CE a) =
               actions.sum (fun a => min (m a x) (m a y) * CE a) := by
    apply Finset.sum_congr rfl
    intro a ha
    rw [hx a ha, hy a ha]
  have h_den : actions.sum (fun a => m' a x' * CE a) =
               actions.sum (fun a => m a x * CE a) := by
    apply Finset.sum_congr rfl
    intro a ha
    rw [hx a ha]
  rw [h_num, h_den]

/-- 
  Hypothesis: Monotonicity of the Domain Hierarchy Update Operator.
  Used to establish the existence of a fixed point via Knaster-Tarski.
-/
def monotone_update_assumption {α : Type*} [PartialOrder α] (F : α → α) : Prop :=
  Monotone F

/-- 
  LEMMA: Existence of Hierarchy Fixed Point (Knaster-Tarski).
  Assuming the update operator F on a complete lattice (e.g. bounded subsethood profiles)
  satisfies the monotonicity hypothesis, there exists a fixed point S* = F(S*).
-/
theorem hierarchy_fixed_point_exists {α : Type*} [CompleteLattice α]
    (F : α → α) (h_mono : monotone_update_assumption F) :
    ∃ fixedPoint : α, F fixedPoint = fixedPoint := by
  have h_is_fixed : F (OrderHom.lfp ⟨F, h_mono⟩) = OrderHom.lfp ⟨F, h_mono⟩ :=
    OrderHom.isFixedPt_lfp ⟨F, h_mono⟩
  exact ⟨OrderHom.lfp ⟨F, h_mono⟩, h_is_fixed⟩

end Benefuture.Proposed
