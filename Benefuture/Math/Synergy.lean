/-
  Benefuture.Math.Synergy
  Faithful specification of the Benefuture Synergy operator (Sy), Squashed Synergy (Ŝy),
  Harm convexity, and foundational lemmas over ℝ.
  Corresponds to: Bf_Pseudocode.txt L13-14, L54-63.
  
  "Sy(x) | (κ=1, q₊=1.1, q₋=1.5, λ=½) :=
     a_s := |x| ⊙ [sgn(x)=s];
     Φ_s := Σ_i w_{s,i} a_{s,i}^{q_s} + κ √(Σ_{i<j} w_{s,i} w_{s,j} (a_{s,i} a_{s,j})^{q_s});
     Sy  := Φ₊ − Φ₋ − λ Φ₊Φ₋/(Φ₊+Φ₋)   (0 when Φ₊+Φ₋ = 0)."
  
  "Ŝy(s) := sgn(s)·|s|^ν / (|s|^ν + h^ν) | (ν = 1, h) ∈ SigThGv."
-/

import Mathlib.Data.Real.Basic
import Mathlib.Data.Real.Sqrt
import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Positivity
import Mathlib.Tactic.Linarith
import Benefuture.Math.Order

namespace Benefuture.Math

/- --- 1. Harm Severity Tiers & Readings --- -/

/-- 
  [R] Severity tiers for Harm in strict priority order.
  Corresponds to: Bf_Pseudocode.txt L61-63.
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
  [P] Weighted reading of harm tiers:
  Each tier is assigned a positive numerical weight in ℝ.
  Default weights: Irreparable = 10.0, Passing = 1.2.
-/
structure HarmWeights where
  w_irreparable : ℝ
  w_passing     : ℝ
  h_irrep_pos   : 0 < w_irreparable
  h_pass_pos    : 0 < w_passing

/--
  [OPEN] Under the weighted reading of harm tiers, there exists a finite exchange rate:
  a sufficiently large count n of transient passing harms equals or outweighs a single irreparable harm.
  This represents the classical utilitarian aggregation tradeoff.
-/
theorem finite_exchange_rate_weighted (hw : HarmWeights) :
    ∃ n : ℕ, (n : ℝ) * hw.w_passing ≥ hw.w_irreparable := by
  obtain ⟨n, hn⟩ := exists_nat_gt (hw.w_irreparable / hw.w_passing)
  use n
  have hp : 0 < hw.w_passing := hw.h_pass_pos
  rw [ge_iff_le]
  have h_mul := (div_le_iff₀ hp).mp (le_of_lt hn)
  linarith

/-- 
  [P] Lexical reading of harm tiers:
  Harms are compared lexicographically: any occurrence of a higher-priority harm tier
  strictly dominates any finite quantity of lower-priority harm tiers.
  Here modeled on the pair (irreparableCount, passingCount).
-/
def LexicalHarmLe (h1 h2 : ℕ × ℕ) : Prop :=
  h1.1 < h2.1 ∨ (h1.1 = h2.1 ∧ h1.2 ≤ h2.2)

def LexicalHarmLt (h1 h2 : ℕ × ℕ) : Prop :=
  h1.1 < h2.1 ∨ (h1.1 = h2.1 ∧ h1.2 < h2.2)

/--
  [OPEN] Under the lexical reading of harm tiers, no finite exchange rate exists:
  for any natural number n of passing harms, (0, n) is strictly dominated by a single irreparable harm (1, 0).
  Irreparable harm cannot be compensated by avoiding any finite number of passing harms.
-/
theorem no_finite_exchange_rate_lexical (n : ℕ) :
    LexicalHarmLt (0, n) (1, 0) := by
  unfold LexicalHarmLt
  left
  norm_num

/- --- 2. The Synergy Operator (Sy) over ℝ --- -/

/-- 
  Constructive sum of pairwise cross products for i < j:
  Σ_{i<j} y_i · y_j.
  For a list [y₁, y₂, ..., yₙ], computes y₁·(y₂+...+yₙ) + pairwiseCrossSum [y₂, ..., yₙ].
-/
def pairwiseCrossSum : List ℝ → ℝ
  | [] => 0
  | y :: ys => y * ys.sum + pairwiseCrossSum ys

@[simp]
theorem pairwiseCrossSum_nil : pairwiseCrossSum [] = 0 := rfl

@[simp]
theorem pairwiseCrossSum_singleton (y : ℝ) : pairwiseCrossSum [y] = 0 := by
  simp [pairwiseCrossSum]

/-- Pairwise cross sum of non-negative elements is non-negative. -/
theorem pairwiseCrossSum_nonneg : ∀ (l : List ℝ), (∀ y ∈ l, 0 ≤ y) → 0 ≤ pairwiseCrossSum l
  | [], _ => by simp [pairwiseCrossSum]
  | y :: ys, h => by
    simp only [pairwiseCrossSum]
    have hy : 0 ≤ y := h y (by simp)
    have hys : ∀ z ∈ ys, 0 ≤ z := fun z hz => h z (List.mem_cons_of_mem y hz)
    have h_sum : 0 ≤ ys.sum := List.sum_nonneg hys
    have h_prod : 0 ≤ y * ys.sum := mul_nonneg hy h_sum
    have h_rec : 0 ≤ pairwiseCrossSum ys := pairwiseCrossSum_nonneg ys hys
    linarith

/-- 
  [R] Unipolar branch potential Φ_s (L13):
  Φ_s := Σ_i w_{s,i} a_{s,i}^{q_s} + κ √(Σ_{i<j} w_{s,i} w_{s,j} (a_{s,i} a_{s,j})^{q_s}).
  Here `items` is a list of pairs (magnitude a_i, weight w_i) where a_i ≥ 0, w_i ≥ 0.
-/
noncomputable def phiBranch (items : List (ℝ × ℝ)) (q : ℝ) (kappa : ℝ) : ℝ :=
  let y_list := items.map (fun (a, w) => w * (a ^ q))
  let linear_sum := y_list.sum
  let cross_sum  := pairwiseCrossSum y_list
  linear_sum + kappa * Real.sqrt cross_sum

@[simp]
theorem phiBranch_nil (q kappa : ℝ) : phiBranch [] q kappa = 0 := by
  dsimp [phiBranch]
  simp

theorem phiBranch_singleton (x w q kappa : ℝ) :
    phiBranch [(x, w)] q kappa = w * (x ^ q) := by
  dsimp [phiBranch]
  simp

/-- 
  [R] Raw interaction penalty between positive and negative potentials (L13):
  penalty(Φ₊, Φ₋) = λ · Φ₊ · Φ₋ / (Φ₊ + Φ₋)   (0 when Φ₊ + Φ₋ = 0).
-/
noncomputable def synergy_penalty (phi_plus phi_minus lambda : ℝ) : ℝ :=
  if phi_plus + phi_minus = 0 then 0
  else lambda * (phi_plus * phi_minus) / (phi_plus + phi_minus)

/-- 
  [R] Raw Net Synergy from branch potentials (L13):
  Sy(Φ₊, Φ₋) = Φ₊ − Φ₋ − λ · Φ₊ · Φ₋ / (Φ₊ + Φ₋)   (0 when Φ₊ + Φ₋ = 0).
-/
noncomputable def net_synergy_raw (phi_plus phi_minus lambda : ℝ) : ℝ :=
  if phi_plus + phi_minus = 0 then 0
  else phi_plus - phi_minus - lambda * (phi_plus * phi_minus) / (phi_plus + phi_minus)

theorem net_synergy_raw_pos_zero (phi : ℝ) (hphi : 0 < phi) (lambda : ℝ) :
    net_synergy_raw phi 0 lambda = phi := by
  unfold net_synergy_raw
  have h_sum : phi + 0 ≠ 0 := by linarith
  simp only [h_sum, ite_false, mul_zero, zero_div, sub_zero]

theorem net_synergy_raw_zero_pos (phi : ℝ) (hphi : 0 < phi) (lambda : ℝ) :
    net_synergy_raw 0 phi lambda = -phi := by
  unfold net_synergy_raw
  have h_sum : 0 + phi ≠ 0 := by linarith
  simp only [h_sum, ite_false, zero_mul, mul_zero, zero_div, sub_zero, zero_sub]

@[simp]
theorem net_synergy_raw_zero_zero (lambda : ℝ) :
    net_synergy_raw 0 0 lambda = 0 := by
  unfold net_synergy_raw
  simp

/-- 
  [R] Full Net Synergy Operator Sy(x) (L13):
  Takes a list of (value, weight) pairs over ℝ and GovParams.
  Separates positive values a₊ and negative values a₋ = |x|:
  a_s := |x| ⊙ [sgn(x) = s].
-/
noncomputable def net_synergy (items : List (ℝ × ℝ)) (p : GovParams) : ℝ :=
  let pos_items := items.filterMap (fun (x, w) => if x > 0 then some (x, w) else none)
  let neg_items := items.filterMap (fun (x, w) => if x < 0 then some (-x, w) else none)
  let phi_pos := phiBranch pos_items p.q_plus p.kappa
  let phi_neg := phiBranch neg_items p.q_minus p.kappa
  net_synergy_raw phi_pos phi_neg p.lambda

/-- Binary/two-argument synergy shorthand: Sy₂(x, y). -/
noncomputable def net_synergy_binary (x y : ℝ) (w_x w_y : ℝ) (p : GovParams) : ℝ :=
  net_synergy [(x, w_x), (y, w_y)] p

/- --- 3. Squashed Synergy Ŝy(s) over ℝ --- -/

/-- 
  [R] Squashed Synergy Operator Ŝy(s) (L14):
  Ŝy(s) := sgn(s)·|s|^ν / (|s|^ν + h^ν) | (ν = 1, h) ∈ SigThGv.
  Transforms raw synergy into a smooth S-curve bounded in (-1, 1).
-/
noncomputable def squashed_synergy (s : ℝ) (nu : ℝ) (h : ℝ) : ℝ :=
  if s > 0 then
    (s ^ nu) / (s ^ nu + h ^ nu)
  else if s < 0 then
    - (((-s) ^ nu) / ((-s) ^ nu + h ^ nu))
  else
    0

/- --- 4. Verified Lemmas over ℝ --- -/

/-- 
  THEOREM: Equal gains and losses yield a strictly negative net balance for λ > 0.
  When Φ₊ = Φ₋ = v > 0, the cross-term interaction penalty λ·v²/2v = λv/2 strictly depresses
  net synergy below zero: Sy(v, v) = -λv/2 < 0.
-/
theorem equal_gains_and_losses_are_negative (v lambda : ℝ) (hv : 0 < v) (hlambda : 0 < lambda) :
    net_synergy_raw v v lambda < 0 := by
  unfold net_synergy_raw
  have h_sum : v + v ≠ 0 := by linarith
  simp only [h_sum, ite_false]
  have h_sub : v - v = 0 := by ring
  have h_alg : lambda * (v * v) / (v + v) = lambda * v / 2 := by
    calc
      lambda * (v * v) / (v + v) = (lambda * v) * v / (2 * v) := by ring_nf
      _ = (lambda * v) / 2 := by
        rw [mul_div_mul_right (lambda * v) 2 (ne_of_gt hv)]
  rw [h_sub, h_alg, zero_sub]
  have h_pos : 0 < lambda * v / 2 := by positivity
  linarith

/-- 
  [OPEN] Loss Aversion Scale Inversion Theorem (Upper Regime):
  For input magnitudes m > 1 and exponents q₋ > q₊, loss aversion holds: m^{q₊} < m^{q₋}.
  Negative impacts compound faster than positive impacts for large values.
-/
theorem loss_aversion_holds_above_one (m : ℝ) (hm : 1 < m) (q_plus q_minus : ℝ) (hq : q_plus < q_minus) :
    m ^ q_plus < m ^ q_minus := by
  exact Real.rpow_lt_rpow_of_exponent_lt hm hq

/-- 
  [OPEN] Loss Aversion Scale Inversion Theorem (Sub-unitary Failure):
  For input magnitudes 0 < m < 1 and exponents q₋ > q₊, standard loss aversion FAILS:
  m^{q₋} < m^{q₊}. Because exponents greater than 1 compress sub-unitary magnitudes,
  higher penalty exponents perversely attenuate micro-harms!
  SPEC-FINDING: Raw Sy requires explicit scale normalization or dimensional unit grounding.
-/
theorem loss_aversion_fails_below_one (m : ℝ) (hm_pos : 0 < m) (hm_lt : m < 1) (q_plus q_minus : ℝ) (hq : q_plus < q_minus) :
    m ^ q_minus < m ^ q_plus := by
  exact Real.rpow_lt_rpow_of_exponent_gt hm_pos hm_lt hq

/-- Ŝy is zero at zero. -/
@[simp]
theorem squashed_synergy_zero (nu h : ℝ) : squashed_synergy 0 nu h = 0 := by
  unfold squashed_synergy
  simp

/-- Ŝy is an odd function: Ŝy(-s) = -Ŝy(s). -/
theorem squashed_synergy_odd (s nu h : ℝ) :
    squashed_synergy (-s) nu h = - squashed_synergy s nu h := by
  unfold squashed_synergy
  by_cases hpos : s > 0
  · have hneg : -s < 0 := by linarith
    have hnot_pos : ¬(-s > 0) := by linarith
    simp [hpos, hneg, hnot_pos, neg_neg]
  · by_cases hneg : s < 0
    · have hpos' : -s > 0 := by linarith
      have hnot_pos : ¬(s > 0) := by linarith
      simp [hpos', hneg, hnot_pos, neg_neg]
    · have hz : s = 0 := by linarith
      subst hz
      simp

/-- Ŝy is strictly bounded in (-1, 1) for positive parameters. -/
theorem squashed_synergy_bounds (s : ℝ) (h : ℝ) (nu : ℝ) (hh : 0 < h) (_hnu : 0 < nu) :
    -1 < squashed_synergy s nu h ∧ squashed_synergy s nu h < 1 := by
  unfold squashed_synergy
  by_cases hs_pos : s > 0
  · simp only [hs_pos, ite_true]
    have hs_pow_pos : 0 < s ^ nu := Real.rpow_pos_of_pos hs_pos nu
    have hh_pow_pos : 0 < h ^ nu := Real.rpow_pos_of_pos hh nu
    have hdenom : 0 < s ^ nu + h ^ nu := by linarith
    have hlt : s ^ nu < s ^ nu + h ^ nu := by linarith
    have hdiv_pos : 0 < (s ^ nu) / (s ^ nu + h ^ nu) := div_pos hs_pow_pos hdenom
    have hdiv_lt_one : (s ^ nu) / (s ^ nu + h ^ nu) < 1 := (div_lt_one hdenom).mpr hlt
    constructor
    · linarith
    · exact hdiv_lt_one
  · by_cases hs_neg : s < 0
    · simp only [hs_pos, hs_neg, ite_false, ite_true]
      have h_pos_neg_s : 0 < -s := by linarith
      have hs_pow_pos : 0 < (-s) ^ nu := Real.rpow_pos_of_pos h_pos_neg_s nu
      have hh_pow_pos : 0 < h ^ nu := Real.rpow_pos_of_pos hh nu
      have hdenom : 0 < (-s) ^ nu + h ^ nu := by linarith
      have hlt : (-s) ^ nu < (-s) ^ nu + h ^ nu := by linarith
      have hdiv_pos : 0 < ((-s) ^ nu) / ((-s) ^ nu + h ^ nu) := div_pos hs_pow_pos hdenom
      have hdiv_lt_one : ((-s) ^ nu) / ((-s) ^ nu + h ^ nu) < 1 := (div_lt_one hdenom).mpr hlt
      constructor
      · linarith
      · linarith
    · have hz : s = 0 := by linarith
      subst hz
      simp only [gt_iff_lt, lt_self_iff_false, ite_false]
      norm_num

/-- 
  Linear canonical squashed synergy (ν = 1):
  Ŝy(s) = s / (s + h) for s ≥ 0.
-/
theorem squashed_synergy_nu_one_pos (s h : ℝ) (hs : 0 ≤ s) (_hh : 0 < h) :
    squashed_synergy s 1 h = s / (s + h) := by
  unfold squashed_synergy
  by_cases hpos : s > 0
  · simp only [hpos, ite_true, Real.rpow_one]
  · have hz : s = 0 := by linarith
    subst hz
    simp only [gt_iff_lt, lt_self_iff_false, ite_false, zero_div]

/-- 
  Strict monotonicity of Ŝy for canonical ν = 1:
  s₁ < s₂ ⇒ Ŝy(s₁, 1, h) < Ŝy(s₂, 1, h).
-/
theorem squashed_synergy_strictly_monotone_nu_one (s₁ s₂ h : ℝ) (hh : 0 < h) (hs : s₁ < s₂) :
    squashed_synergy s₁ 1 h < squashed_synergy s₂ 1 h := by
  by_cases h0 : 0 ≤ s₁
  · have hs2_pos : 0 < s₂ := by linarith
    have h1 := squashed_synergy_nu_one_pos s₁ h h0 hh
    have h2 := squashed_synergy_nu_one_pos s₂ h (le_of_lt hs2_pos) hh
    rw [h1, h2]
    have hd1 : 0 < s₁ + h := by linarith
    have hd2 : 0 < s₂ + h := by linarith
    rw [div_lt_div_iff₀ hd1 hd2]
    calc
      s₁ * (s₂ + h) = s₁ * s₂ + s₁ * h := by ring
      _ < s₁ * s₂ + s₂ * h := by
        have : s₁ * h < s₂ * h := mul_lt_mul_of_pos_right hs hh
        linarith
      _ = s₂ * (s₁ + h) := by ring
  · have hs1_neg : s₁ < 0 := by linarith
    by_cases hs2_nonpos : s₂ ≤ 0
    · have h_neg_s : -s₂ < -s₁ := by linarith
      have hs2_nonneg : 0 ≤ -s₂ := by linarith
      have h1 := squashed_synergy_nu_one_pos (-s₂) h hs2_nonneg hh
      have h2 := squashed_synergy_nu_one_pos (-s₁) h (by linarith) hh
      have h_odd1 := squashed_synergy_odd s₁ 1 h
      have h_odd2 := squashed_synergy_odd s₂ 1 h
      rw [← neg_neg (squashed_synergy s₁ 1 h), ← h_odd1]
      rw [← neg_neg (squashed_synergy s₂ 1 h), ← h_odd2]
      have hd1 : 0 < -s₂ + h := by linarith
      have hd2 : 0 < -s₁ + h := by linarith
      have h_lt : squashed_synergy (-s₂) 1 h < squashed_synergy (-s₁) 1 h := by
        rw [h1, h2]
        rw [div_lt_div_iff₀ hd1 hd2]
        calc
          -s₂ * (-s₁ + h) = (-s₂) * (-s₁) + (-s₂) * h := by ring
          _ < (-s₂) * (-s₁) + (-s₁) * h := by
            have : (-s₂) * h < (-s₁) * h := mul_lt_mul_of_pos_right h_neg_s hh
            linarith
          _ = -s₁ * (-s₂ + h) := by ring
      linarith
    · have hs2_pos : 0 < s₂ := by linarith
      have h1_neg : squashed_synergy s₁ 1 h < 0 := by
        unfold squashed_synergy
        have hnot_pos : ¬(s₁ > 0) := by linarith
        simp only [hnot_pos, hs1_neg, ite_true, ite_false, Real.rpow_one]
        have hp : 0 < -s₁ / (-s₁ + h) := div_pos (by linarith) (by linarith)
        linarith
      have h2_pos : 0 < squashed_synergy s₂ 1 h := by
        unfold squashed_synergy
        simp only [hs2_pos, ite_true, Real.rpow_one]
        exact div_pos hs2_pos (by linarith)
      linarith

/-- Synergy of empty list is zero. -/
@[simp]
theorem net_synergy_nil (p : GovParams) : net_synergy [] p = 0 := by
  dsimp [net_synergy]
  simp

/-- Synergy is strictly positive for a single positive item with positive weight. -/
theorem net_synergy_single_positive (x w : ℝ) (hx : 0 < x) (hw : 0 < w) (p : GovParams) :
    0 < net_synergy [(x, w)] p := by
  have hnot_neg : ¬(x < 0) := by linarith
  dsimp [net_synergy]
  simp only [hx, hnot_neg, ite_true, ite_false, List.filterMap_cons, List.filterMap_nil]
  rw [phiBranch_singleton, phiBranch_nil]
  have h_phi_pos : 0 < w * x ^ p.q_plus := mul_pos hw (Real.rpow_pos_of_pos hx p.q_plus)
  rw [net_synergy_raw_pos_zero _ h_phi_pos]
  exact h_phi_pos

/-- Synergy is strictly negative for a single negative item with positive weight. -/
theorem net_synergy_single_negative (x w : ℝ) (hx : x < 0) (hw : 0 < w) (p : GovParams) :
    net_synergy [(x, w)] p < 0 := by
  have hnot_pos : ¬(x > 0) := by linarith
  have h_neg_x : 0 < -x := by linarith
  dsimp [net_synergy]
  simp only [hnot_pos, hx, ite_true, ite_false, List.filterMap_cons, List.filterMap_nil]
  rw [phiBranch_nil, phiBranch_singleton]
  have h_phi_neg : 0 < w * (-x) ^ p.q_minus := mul_pos hw (Real.rpow_pos_of_pos h_neg_x p.q_minus)
  rw [net_synergy_raw_zero_pos _ h_phi_neg]
  linarith

/-- Synergy of a single item is zero iff the value is zero or the weight is zero. -/
theorem net_synergy_single_zero_val (w : ℝ) (p : GovParams) :
    net_synergy [(0, w)] p = 0 := by
  dsimp [net_synergy]
  simp

end Benefuture.Math
