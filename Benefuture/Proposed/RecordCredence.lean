/-
  Benefuture.Proposed.RecordCredence
  [P] A model's credence from its record (finding 8.58-c, `docs/BACKPROPAGATION.md` 8.66): the share
  of its past value errors (predicted less measured) below its prediction, a tie counting half,
  within [1 − cap, cap] (truth levels never reach 1, 8.33). Mirrored over Float by
  `BenefutureReference.record_credence_ref`.

  Proved here: the credence lies within [1 − cap, cap]; it rises with the prediction; and one
  error, however large (a heavy-tailed side effect), moves it by at most 1 / n over a record of n.
  The normal credence over the record's root mean square error (`credence_ref`) has no such bound:
  one large enough error turns every credence into a coin toss (shown in the Julia suites,
  `sim/test/domain_tests.jl`), which is what stalls the economy under heavy-tailed side harm.

  IMPORTANT ARCHITECTURAL RULE: core Benefuture modules MUST NOT import this file.
-/

import Mathlib.Data.Real.Basic
import Mathlib.Algebra.Order.Field.Basic
import Mathlib.Algebra.BigOperators.Group.List.Basic
import Mathlib.Order.Lattice
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Positivity

namespace Benefuture.Proposed

/-- [P] One past error's weight toward a positive outcome for prediction `v`: 1 below the
    prediction (the true value, prediction less error, is positive), a half on a tie, 0 above. -/
noncomputable def recordWeight (v e : ℝ) : ℝ := if e < v then 1 else if e = v then 1 / 2 else 0

/-- [P] The record's count toward a positive outcome: the sum of the weights. -/
noncomputable def recordScore (v : ℝ) (errs : List ℝ) : ℝ := (errs.map (recordWeight v)).sum

/-- [P] Credence from the record: the score's share of the record, a coin toss with no record,
    within [1 − cap, cap]. -/
noncomputable def recordCredence (cap v : ℝ) (errs : List ℝ) : ℝ :=
  max (1 - cap) (min cap (if errs = [] then 1 / 2 else recordScore v errs / errs.length))

theorem recordWeight_mem (v e : ℝ) : 0 ≤ recordWeight v e ∧ recordWeight v e ≤ 1 := by
  unfold recordWeight; split_ifs <;> constructor <;> norm_num

theorem recordWeight_mono {v w : ℝ} (h : v ≤ w) (e : ℝ) : recordWeight v e ≤ recordWeight w e := by
  unfold recordWeight
  rcases lt_trichotomy e v with h1 | h1 | h1
  · simp [h1, lt_of_lt_of_le h1 h]
  · subst h1
    rcases eq_or_lt_of_le h with h2 | h2
    · subst h2; exact le_rfl
    · simp [h2]; norm_num
  · have hv : ¬e < v := not_lt.mpr h1.le
    have hne : e ≠ v := ne_of_gt h1
    simp only [hv, hne, if_false]
    split_ifs <;> norm_num

/-- The credence stays within [1 − cap, cap] for every cap of at least a half. -/
theorem recordCredence_bounds {cap : ℝ} (hc : 1 / 2 ≤ cap) (v : ℝ) (errs : List ℝ) :
    1 - cap ≤ recordCredence cap v errs ∧ recordCredence cap v errs ≤ cap := by
  unfold recordCredence
  refine ⟨le_max_left _ _, max_le (by linarith) (min_le_left _ _)⟩

/-- The score rises with the prediction. -/
theorem recordScore_mono {v w : ℝ} (h : v ≤ w) (errs : List ℝ) : recordScore v errs ≤ recordScore w errs := by
  unfold recordScore
  induction errs with
  | nil => simp
  | cons e rest ih => simp only [List.map_cons, List.sum_cons]; exact add_le_add (recordWeight_mono h e) ih

/-- Acceptance: one error, however large, moves the score by at most 1. -/
theorem recordScore_one_error (v a b : ℝ) (l₁ l₂ : List ℝ) :
    |recordScore v (l₁ ++ a :: l₂) - recordScore v (l₁ ++ b :: l₂)| ≤ 1 := by
  unfold recordScore
  simp only [List.map_append, List.map_cons, List.sum_append, List.sum_cons]
  have ha := recordWeight_mem v a
  have hb := recordWeight_mem v b
  rw [abs_le]; constructor <;> linarith [ha.1, ha.2, hb.1, hb.2]

/-- Clamping to [lo, hi] moves two values no further apart. -/
theorem clamp_lipschitz (lo hi x y : ℝ) : |max lo (min hi x) - max lo (min hi y)| ≤ |x - y| := by
  rcases le_total x y with h | h
  · have h1 : max lo (min hi x) ≤ max lo (min hi y) := max_le_max le_rfl (min_le_min le_rfl h)
    rw [abs_of_nonpos (by linarith), abs_of_nonpos (by linarith)]
    have : max lo (min hi y) - max lo (min hi x) ≤ y - x := by
      rcases le_total y hi with hy | hy <;> rcases le_total x hi with hx | hx <;>
        rcases le_total lo (min hi x) with hl | hl <;> rcases le_total lo (min hi y) with hm | hm <;>
        simp_all <;> linarith
    linarith
  · have h1 : max lo (min hi y) ≤ max lo (min hi x) := max_le_max le_rfl (min_le_min le_rfl h)
    rw [abs_of_nonneg (by linarith), abs_of_nonneg (by linarith)]
    have : max lo (min hi x) - max lo (min hi y) ≤ x - y := by
      rcases le_total y hi with hy | hy <;> rcases le_total x hi with hx | hx <;>
        rcases le_total lo (min hi x) with hl | hl <;> rcases le_total lo (min hi y) with hm | hm <;>
        simp_all <;> linarith
    linarith

/-- Acceptance: over a record of n errors, one error, however large, moves the credence by at most
    1 / n (where the normal credence over the root mean square error can move to a coin toss). -/
theorem recordCredence_one_error (cap v a b : ℝ) (l₁ l₂ : List ℝ) :
    |recordCredence cap v (l₁ ++ a :: l₂) - recordCredence cap v (l₁ ++ b :: l₂)|
      ≤ 1 / (l₁ ++ a :: l₂).length := by
  have hlen : (l₁ ++ b :: l₂).length = (l₁ ++ a :: l₂).length := by simp
  have hpos : (0 : ℝ) < (l₁ ++ a :: l₂).length := by simp; positivity
  unfold recordCredence
  simp only [List.append_ne_nil_of_right_ne_nil l₁ (List.cons_ne_nil a l₂),
    List.append_ne_nil_of_right_ne_nil l₁ (List.cons_ne_nil b l₂), if_false, hlen]
  refine (clamp_lipschitz _ _ _ _).trans ?_
  rw [← sub_div, abs_div, abs_of_pos hpos]
  exact div_le_div_of_nonneg_right (recordScore_one_error v a b l₁ l₂) hpos.le

end Benefuture.Proposed
