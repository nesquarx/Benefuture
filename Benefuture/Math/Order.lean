/-
  Benefuture.Math.Order
  Specification of core parameter governance and priority hierarchies over ℝ.
  Corresponds to: Bf_Pseudocode.txt L11-14, L25, L101, L155.
  
  Params«Pm» := 1 > α > β > γ > δ...;
  (x_1 > x_2 > ... > x_n) := [(x_i, Pm_i)];
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.NormNum

namespace Benefuture.Math

/-- Fixed-point scalar scale for backward compatibility: 1.0 is represented as 1,000,000. -/
def SCALE : Int := 1000000

/-- 
  [R] All governed parameters in one record, governed by Significant Threshold Governance (SigThGv).
  Corresponds to: Bf_Pseudocode.txt L11, L13, L14, L25, L101, L155.
-/
structure GovParams where
  -- Core priority hierarchy: 1 > α > β > γ > δ > 0 (L11)
  alpha              : ℝ
  beta               : ℝ
  gamma              : ℝ
  delta              : ℝ
  h_alpha_lt_one     : alpha < 1
  h_beta_lt_alpha    : beta < alpha
  h_gamma_lt_beta    : gamma < beta
  h_delta_lt_gamma   : delta < gamma
  h_delta_pos        : 0 < delta

  -- Synergy operator parameters: κ, q₊, q₋, λ (L13)
  kappa              : ℝ
  q_plus             : ℝ
  q_minus            : ℝ
  lambda             : ℝ
  h_kappa_nonneg     : 0 ≤ kappa
  h_q_plus_pos       : 0 < q_plus
  h_q_minus_pos      : 0 < q_minus
  h_lambda_nonneg    : 0 ≤ lambda

  -- Squashed synergy parameters: ν, h (L14)
  nu                 : ℝ
  h_param            : ℝ
  h_nu_pos           : 0 < nu
  h_h_param_pos      : 0 < h_param

  -- Decay rates for reputation's rolling net (L101; ledger entries never decay, ruling 8.42.4)
  lambda_plus        : ℝ
  lambda_minus       : ℝ
  h_lambda_plus_pos  : 0 < lambda_plus
  h_lambda_minus_pos : 0 < lambda_minus
  -- Ledger asymmetry: mistakes decay no faster than wins (ruling 8.29.1). Non-strict here so that
  -- equal rates (the reduction to M2) stay representable; `Systems.ParamSpace.Admissible` is strict.
  h_lambda_minus_le_plus : lambda_minus ≤ lambda_plus

  -- Significance and governance thresholds (L25, L155)
  th_sig             : ℝ
  th_gov             : ℝ
  h_th_sig_pos       : 0 < th_sig
  h_th_gov_pos       : 0 < th_gov

/-- 
  [P] Proposed default configuration for GovParams.
  α=0.8, β=0.6, γ=0.4, δ=0.2, κ=1.0, q₊=1.1, q₋=1.5, λ=0.5, ν=1.0, h=1.0.
-/
noncomputable def defaultGovParams : GovParams := {
  alpha := 0.8
  beta  := 0.6
  gamma := 0.4
  delta := 0.2
  h_alpha_lt_one  := by norm_num
  h_beta_lt_alpha := by norm_num
  h_gamma_lt_beta := by norm_num
  h_delta_lt_gamma:= by norm_num
  h_delta_pos     := by norm_num

  kappa   := 1.0
  q_plus  := 1.1
  q_minus := 1.5
  lambda  := 0.5
  h_kappa_nonneg  := by norm_num
  h_q_plus_pos    := by norm_num
  h_q_minus_pos   := by norm_num
  h_lambda_nonneg := by norm_num

  nu      := 1.0
  h_param := 1.0
  h_nu_pos      := by norm_num
  h_h_param_pos := by norm_num

  lambda_plus  := 0.05
  lambda_minus := 0.02  -- mistakes decay slower than wins (BACKPROPAGATION 8.29)
  h_lambda_plus_pos  := by norm_num
  h_lambda_minus_pos := by norm_num
  h_lambda_minus_le_plus := by norm_num

  th_sig := 0.5
  th_gov := 0.7
  h_th_sig_pos := by norm_num
  h_th_gov_pos := by norm_num
}

-- Backward-compatible alias
abbrev BfParams := GovParams
noncomputable abbrev defaultParams : GovParams := defaultGovParams

/-- Theorem: Understanding strictly dominates Happiness in weight. -/
theorem understanding_dominates_happiness (p : GovParams) : p.alpha > p.beta :=
  p.h_beta_lt_alpha

/-- Theorem: Happiness strictly dominates Novelty in weight. -/
theorem happiness_dominates_novelty (p : GovParams) : p.beta > p.gamma :=
  p.h_gamma_lt_beta

/-- Theorem: Understanding strictly dominates Novelty by transitivity. -/
theorem understanding_dominates_novelty (p : GovParams) : p.alpha > p.gamma :=
  lt_trans p.h_gamma_lt_beta p.h_beta_lt_alpha

/--
  Theorem: α exceeds δ, the fourth parameter of L11's order, by transitivity. δ is not harm's
  weight: harm enters V as the loss weight Ha_wt = 1 + Sy(...) ≥ 1 (L61, L73), above α, and L62
  ranks U > Ha > H. The name is historical; this proves only α > δ.
-/
theorem understanding_dominates_harm_base (p : GovParams) : p.alpha > p.delta :=
  lt_trans p.h_delta_lt_gamma (lt_trans p.h_gamma_lt_beta p.h_beta_lt_alpha)

/-- Theorem: All core priority parameters are strictly bounded within the open interval (0, 1.0). -/
theorem params_in_unit_interval (p : GovParams) : 
    0 < p.delta ∧ p.delta < 1 ∧
    0 < p.gamma ∧ p.gamma < 1 ∧
    0 < p.beta  ∧ p.beta  < 1 ∧
    0 < p.alpha ∧ p.alpha < 1 := by
  have hd_pos := p.h_delta_pos
  have hg_pos := lt_trans hd_pos p.h_delta_lt_gamma
  have hb_pos := lt_trans hg_pos p.h_gamma_lt_beta
  have ha_pos := lt_trans hb_pos p.h_beta_lt_alpha
  have ha_lt := p.h_alpha_lt_one
  have hb_lt := lt_trans p.h_beta_lt_alpha ha_lt
  have hg_lt := lt_trans p.h_gamma_lt_beta hb_lt
  have hd_lt := lt_trans p.h_delta_lt_gamma hg_lt
  exact ⟨hd_pos, hd_lt, hg_pos, hg_lt, hb_pos, hb_lt, ha_pos, ha_lt⟩

/-- 
  [R] General strictly decreasing parameter schedule over ℝ.
  Corresponds to: Bf_Pseudocode.txt L11-12: "Params«Pm» := 1 > α > β > γ > δ...; (x_1 > ... > x_n) := [(x_i, Pm_i)];"
-/
structure ParamSchedule where
  weights       : List ℝ
  h_nonempty    : weights ≠ []
  h_upper_bound : ∀ w ∈ weights, w < 1
  h_lower_bound : ∀ w ∈ weights, 0 < w
  h_decreasing  : weights.Pairwise (· > ·)

/-- 
  Priority Tier Assignment (L12):
  (x_1 > x_2 > ... > x_n) := [(x_i, Pm_i)];
  Pairs an ordered list of elements with their corresponding weight parameters.
-/
def zip_priority_weights {α : Type} (items : List α) (schedule : ParamSchedule) : List (α × ℝ) :=
  items.zip schedule.weights

/-- 
  [P] Canonical 6-tier schedule corresponding to priority tiers:
  Weights decrease strictly: 0.8 > 0.6 > 0.4 > 0.25 > 0.15 > 0.05 > 0.
-/
noncomputable def defaultSchedule : ParamSchedule := {
  weights := [0.8, 0.6, 0.4, 0.25, 0.15, 0.05],
  h_nonempty := by decide,
  h_upper_bound := by
    intro w hw
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl | rfl | rfl | rfl <;> norm_num,
  h_lower_bound := by
    intro w hw
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl | rfl | rfl | rfl <;> norm_num,
  h_decreasing := by
    simp only [List.pairwise_cons, List.not_mem_nil, IsEmpty.forall_iff,
      List.mem_cons, or_false, forall_eq_or_imp, forall_eq]
    norm_num
}

/--
  [P] Harm tier schedule for Ha_wt (L61), one weight per tier with NHa_Estd = 0 excluded:
  Irreparable 0.9 > Irreversible 0.7 > Longterm 0.45 > Passing 0.15 > TimeLoss 0.08 >
  NHa_Pr 0.04 > Culture_offence 0.01 (≈ 0). Catastrophic and irreversible tiers dominate
  (irreparable / passing = 6), in line with longtermist priorities.
-/
noncomputable def harmSchedule : ParamSchedule := {
  weights := [0.9, 0.7, 0.45, 0.15, 0.08, 0.04, 0.01],
  h_nonempty := by decide,
  h_upper_bound := by
    intro w hw
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> norm_num,
  h_lower_bound := by
    intro w hw
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> norm_num,
  h_decreasing := by
    simp only [List.pairwise_cons, List.not_mem_nil, IsEmpty.forall_iff,
      List.mem_cons, or_false, forall_eq_or_imp, forall_eq]
    norm_num
}

end Benefuture.Math
