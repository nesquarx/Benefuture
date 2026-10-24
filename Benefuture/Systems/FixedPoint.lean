/-
  Benefuture.Systems.FixedPoint
  [R] Correspondence between the legacy fixed-point modules (Int at SCALE = 10⁶) and the ℝ spec.
  Several modules (Economy.Currency, Measurement.Threshold, Subgoals.Diversity, …) still encode
  quantities as integers in micro-units. They are fixed-point approximations of the ℝ definitions:
  each operation below is within one unit (10⁻⁶ in real terms) of its real counterpart.
  Simulations should implement the ℝ / Float definitions; these bounds say how far the Int
  modules may drift from them.
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Positivity
import Benefuture.Math.Order
import Benefuture.Economy.Currency
import Benefuture.Measurement.Threshold
import Benefuture.Subgoals.Diversity

namespace Benefuture.Systems

open Benefuture.Math
open Benefuture.Economy
open Benefuture.Measurement
open Benefuture.Subgoals

/-- [R] Real value of a fixed-point quantity at SCALE = 10⁶. -/
noncomputable def fx (x : Int) : ℝ := (x : ℝ) / (SCALE : ℝ)

theorem scale_pos : (0 : Int) < SCALE := by
  unfold SCALE
  norm_num

/-- THEOREM: Integer division under-approximates real division by less than one unit. -/
theorem int_ediv_approx (a b : Int) (hb : 0 < b) :
    (a : ℝ) / b - 1 < ((a / b : Int) : ℝ) ∧ ((a / b : Int) : ℝ) ≤ (a : ℝ) / b := by
  have hbR : (0 : ℝ) < b := by exact_mod_cast hb
  have h1 : a / b * b ≤ a := Int.ediv_mul_le a hb.ne'
  have h2 : a < (a / b + 1) * b := Int.lt_ediv_add_one_mul_self a hb
  have h1R : ((a / b : Int) : ℝ) * b ≤ a := by exact_mod_cast h1
  have h2R : (a : ℝ) < (((a / b : Int) : ℝ) + 1) * b := by exact_mod_cast h2
  constructor
  · rw [div_sub_one hbR.ne', div_lt_iff₀ hbR]
    linarith
  · rw [le_div_iff₀ hbR]
    exact h1R

/--
  THEOREM: Escrow (L84). The Int upfront payment is within one micro-unit of the real
  nominal · P, never above it; conservation (`escrow_conservation`) is exact.
-/
theorem escrow_fixed_point (nominal : Int) (pe : ProbabilisticEscrow) :
    (nominal : ℝ) * pe.predicted_confidence / SCALE - 1 < (upfront_payment nominal pe : ℝ) ∧
      (upfront_payment nominal pe : ℝ) ≤ (nominal : ℝ) * pe.predicted_confidence / SCALE := by
  unfold upfront_payment
  have h := int_ediv_approx (nominal * pe.predicted_confidence) SCALE scale_pos
  push_cast at h
  exact h

/--
  THEOREM: Assessment normalisation (L48). The Int `norm_assessment` is within one micro-unit of
  the real Δ · SCALE / Th_Cx, matching `dynamic_assessment_real` (Δ / Th_Cx) to within 10⁻⁶.
-/
theorem norm_assessment_fixed_point (delta : Int) (th : Threshold) :
    (delta : ℝ) * SCALE / th.baseCutoff - 1 < (norm_assessment delta th : ℝ) ∧
      (norm_assessment delta th : ℝ) ≤ (delta : ℝ) * SCALE / th.baseCutoff := by
  unfold norm_assessment
  have h := int_ediv_approx (delta * SCALE) th.baseCutoff th.h_cutoff_pos
  push_cast at h
  exact h

/--
  THEOREM: Novelty (L36). The Int `compute_novelty` is within one micro-unit of the real
  10⁶ / (frequency + 1).
-/
theorem novelty_fixed_point (freq : ℕ) :
    (1000000 : ℝ) / ((freq : ℝ) + 1) - 1 < (compute_novelty freq : ℝ) ∧
      (compute_novelty freq : ℝ) ≤ (1000000 : ℝ) / ((freq : ℝ) + 1) := by
  unfold compute_novelty
  rw [Int.natCast_ediv]
  have h := int_ediv_approx ((1000000 : ℕ) : Int) ((freq + 1 : ℕ) : Int) (by positivity)
  push_cast at h ⊢
  exact h

end Benefuture.Systems
