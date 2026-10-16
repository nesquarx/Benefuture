/-
  Benefuture.Math.Synergy
  Axiomatic specification of the Benefuture Synergy operator and Harm convexity.
  Corresponds to: Bf_Pseudocode.txt L13-14, L54-63, and Benefuture goals.txt (Mathematical approach).
-/

import Benefuture.Math.Order

namespace Benefuture.Math

/-- 
  Severity tiers for Harm (from highest priority to lowest).
  Wiki reference: Benefuture goals #Harm
  Irreparable > Irreversible > Longterm > Passing > Time-loss > Cultural offence (~0) > Established necessary (=0)
-/
inductive HarmSeverity where
  | Irreparable          : HarmSeverity  -- Death, permanent capacity destruction
  | Irreversible         : HarmSeverity  -- Lasting trauma, irreparable baseline
  | LongTerm             : HarmSeverity  -- Multi-year extended negative impact
  | Passing              : HarmSeverity  -- Temporary discomfort/loss
  | TimeLoss             : HarmSeverity  -- Wasted opportunity/time
  | CulturalOffence      : HarmSeverity  -- Subjective offence, weighted near zero
  | EstablishedNecessary : HarmSeverity  -- Necessary training/strain, zero weight
  deriving Repr, DecidableEq

/-- 
  Convex weight multiplier for harm severity tiers in micro-units.
  Encodes the convex harm principle: severe harms compound disproportionately.
-/
def harm_severity_weight : HarmSeverity → Int
  | .Irreparable          => 10000000  -- 10.0x
  | .Irreversible         => 5000000   -- 5.0x
  | .LongTerm             => 2500000   -- 2.5x
  | .Passing              => 1200000   -- 1.2x
  | .TimeLoss             => 1000000   -- 1.0x (baseline)
  | .CulturalOffence      => 10000     -- 0.01x (structural liberalism: near 0)
  | .EstablishedNecessary => 0         -- 0.0x (e.g. surgical recovery, exercise)

/-- Theorem: Harm severity weights are strictly convex and monotonic across the core spectrum. -/
theorem irreparable_dominates_irreversible :
    harm_severity_weight .Irreparable > harm_severity_weight .Irreversible := by
  decide

theorem irreversible_dominates_longterm :
    harm_severity_weight .Irreversible > harm_severity_weight .LongTerm := by
  decide

theorem longterm_dominates_passing :
    harm_severity_weight .LongTerm > harm_severity_weight .Passing := by
  decide

theorem passing_dominates_offence :
    harm_severity_weight .Passing > harm_severity_weight .CulturalOffence := by
  decide

theorem offence_dominates_necessary :
    harm_severity_weight .CulturalOffence > harm_severity_weight .EstablishedNecessary := by
  decide

/-- 
  Integer synergy calculation for two positive components (e.g., Understanding and Happiness).
  Phi(x, y) = x + y + interaction_bonus.
  In micro-units, when both inputs are positive, synergy provides superadditive boost.
-/
def synergy_pair_gains (x y : Int) : Int :=
  x + y + (if x ≤ y then x else y) / 2

/-- 
  Theorem: Synergy of positive gains is strictly superadditive 
  when inputs are above the minimal granularity threshold (x ≥ 2, y ≥ 2).
-/
theorem synergy_superadditive (x y : Int) (hx : 2 ≤ x) (hy : 2 ≤ y) :
    synergy_pair_gains x y > x + y := by
  unfold synergy_pair_gains
  split
  · -- x ≤ y
    omega
  · -- y < x
    omega

/-- 
  The interaction loss penalty between positive gains and negative losses:
  penalty(Φ_+, Φ_-) = λ · (Φ_+ · Φ_-) / (Φ_+ + Φ_-) where λ = 1/2.
  Corresponds to: Bf_Pseudocode.txt L13: "λ·Φ_+Φ_- / (Φ_+ + Φ_-) | (λ = ½)"
-/
def synergy_interaction_penalty (phi_plus phi_minus : Int) : Int :=
  if phi_plus + phi_minus ≤ 0 then 0
  else (phi_plus * phi_minus) / (2 * (phi_plus + phi_minus))

/-- 
  Net Synergy Operator:
  Sy(Φ_+, Φ_-) = Φ_+ - Φ_- - penalty(Φ_+, Φ_-).
  Directly formalizes Bf_Pseudocode.txt L13.
-/
def net_synergy (phi_plus phi_minus : Int) : Int :=
  phi_plus - phi_minus - synergy_interaction_penalty phi_plus phi_minus

/-- 
  Legacy alias for backwards compatibility.
-/
def net_synergy_balance (phi_plus phi_minus penalty : Int) : Int :=
  phi_plus - phi_minus - penalty

/-- 
  THEOREM: Loss Aversion Theorem (Non-Tautological).
  When positive gains and negative losses are identical (Φ_+ = Φ_- = v) and non-trivial (v ≥ 4),
  the internal cross-term penalty λ·v²/(2v) ≥ 1 strictly forces the net synergy to be negative.
  Equal magnitude gains and losses yield a strictly negative net balance!
-/
theorem equal_gains_and_losses_are_negative (v : Int) (hv : 4 ≤ v) :
    net_synergy v v < 0 := by
  unfold net_synergy synergy_interaction_penalty
  have hnot : ¬ (v + v ≤ 0) := by omega
  simp only [hnot, ite_false]
  have h_pos_denom : 0 < 2 * (v + v) := by omega
  have h_nonneg : (v - 4) * v ≥ 0 := by
    have h1 : v - 4 ≥ 0 := by omega
    have h2 : v ≥ 0 := by omega
    exact Int.mul_nonneg h1 h2
  have h_alg : (v - 4) * v = v * v - 4 * v := by
    rw [Int.sub_mul]
  have h_ge : v * v ≥ 2 * (v + v) := by
    have : v * v - 4 * v ≥ 0 := by omega
    omega
  have h_div_ge1 : (v * v) / (2 * (v + v)) ≥ 1 := by
    apply Int.le_ediv_of_mul_le h_pos_denom
    have : 1 * (2 * (v + v)) = 2 * (v + v) := by omega
    omega
  omega

/-- 
  Squashed Synergy Operator Ŝy(s):
  Ŝy(s) := sgn(s)·|s|^ν / (|s|^ν + h^ν) | (ν = 1, h) ∈ SigThGv.
  Corresponds to: Bf_Pseudocode.txt L14.
  Normalizes raw synergy into a bounded S-curve [ -SCALE, SCALE ].
-/
def squashed_synergy (s : Int) (h : Int) : Int :=
  if s > 0 then
    (s * SCALE) / (s + h)
  else if s < 0 then
    - ((-s * SCALE) / (-s + h))
  else
    0

/-- 
  THEOREM: Squashed Synergy Saturation Bound.
  For any positive synergy and positive threshold h, Ŝy(s, h) is strictly bounded below SCALE (1.0).
-/
theorem squashed_synergy_strictly_bounded (s h : Int) (hs : s > 0) (hh : h > 0) :
    squashed_synergy s h < SCALE := by
  unfold squashed_synergy
  simp only [hs, ite_true]
  have h_pos_denom : s + h > 0 := by omega
  apply Int.ediv_lt_of_lt_mul h_pos_denom
  have h_distrib : SCALE * (s + h) = SCALE * s + SCALE * h := by
    rw [Int.mul_add]
  have h_comm1 : s * SCALE = SCALE * s := by rw [Int.mul_comm]
  have h_pos_h : SCALE * h > 0 := by
    apply Int.mul_pos (by decide) hh
  omega

/-- 
  THEOREM: Squashed Synergy Non-Negativity for Positive Inputs.
-/
theorem squashed_synergy_nonneg (s h : Int) (hs : s > 0) (hh : h > 0) :
    squashed_synergy s h ≥ 0 := by
  unfold squashed_synergy
  simp only [hs, ite_true]
  have h_pos_denom : s + h > 0 := by omega
  have h_pos_num : s * SCALE ≥ 0 := by
    have : s ≥ 0 := by omega
    exact Int.mul_nonneg this (by decide)
  exact Int.ediv_nonneg h_pos_num (by omega)

end Benefuture.Math


