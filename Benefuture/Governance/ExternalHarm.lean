/-
  Benefuture.Governance.ExternalHarm
  [R] External Harm Response (EHR), over ℝ.
  Corresponds to: Bf_Pseudocode.txt L117; Life in benefuture.txt (External Harm Response Protocol);
  Critique addressal.txt ("External harm response is naive about asymmetric conflict").
  "ExternalHaResponse«EHR»(Ha_i, Aggressor(E_!Bf)_j) := TitForTat(viaReparableHa)_ij
     + (α * Re_+ve_j(Dn(Ha_i))) * P(Forgive) + (δ * Re_-ve_j(Dn(Ha_i))) * P(Overreact)
     | (ContextAware ∧ Transparent);"

  Reading (Life in benefuture.txt): proportional tit-for-tat using only reparable harm, plus a
  forgiveness probability weighted by the aggressor's accumulated positive reputation in the domains
  of the harm, plus an overreaction probability weighted by their accumulated negative reputation in
  the same domains. Accumulated reputation is the un-decayed ledger ΣRe± (L101), not decayed relevance.
  Reparable excludes only irreparable harm: irreversible harm can be reparable (author).
  [OPEN] Existential threats (Critique addressal.txt): whether they lift the reparable cap inside EHR
  or are decided by G, where irreparable harm already dominates.
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Ring
import Benefuture.Axiology.Priorities

namespace Benefuture.Governance

open Benefuture.Axiology

/--
  [R] EHR parameters: α and δ are the L11 priority weights (α > δ), `margin` the extra fraction
  of harm returned when overreacting (≥ 0).
-/
structure EHRParams where
  alpha  : ℝ
  delta  : ℝ
  margin : ℝ

/--
  [R] The aggressor's accumulated reputation in the harm's domains: Σ_d ŵ_d · ΣRe±_j(d) over the
  decision profile of Dn(Ha_i). Items are (ŵ_d, ΣRe₊(d), ΣRe₋(d)).
-/
noncomputable def domain_ledger (profile : List (ℝ × ℝ × ℝ)) : ℝ × ℝ :=
  ((profile.map (fun x => x.1 * x.2.1)).sum, (profile.map (fun x => x.1 * x.2.2)).sum)

/-- [R] Probability of forgiving: α · Re₊, capped at 1. -/
noncomputable def p_forgive (ep : EHRParams) (rePos : ℝ) : ℝ :=
  min 1 (ep.alpha * rePos)

/-- [R] Probability of overreacting: δ · Re₋, capped so that the probabilities sum to at most 1. -/
noncomputable def p_overreact (ep : EHRParams) (rePos reNeg : ℝ) : ℝ :=
  min (1 - p_forgive ep rePos) (ep.delta * reNeg)

/--
  [R] Expected magnitude of the EHR response to incoming harm of magnitude h:
  forgive (0) with p_F, overreact ((1 + margin)·h) with p_O, otherwise proportional (h).
-/
noncomputable def ehr_expected_response (ep : EHRParams) (h rePos reNeg : ℝ) : ℝ :=
  (1 - p_forgive ep rePos - p_overreact ep rePos reNeg) * h +
    p_overreact ep rePos reNeg * ((1 + ep.margin) * h)

/-- [R] An EHR response profile: reparable harm only, so no irreparable component. -/
structure ReparableResponse where
  profile        : HarmProfile
  h_reparable    : profile.irreparable = 0

/-- Expected response, rearranged: h · (1 − p_F + margin · p_O). -/
theorem ehr_expected_response_eq (ep : EHRParams) (h rePos reNeg : ℝ) :
    ehr_expected_response ep h rePos reNeg =
      h * (1 - p_forgive ep rePos + ep.margin * p_overreact ep rePos reNeg) := by
  unfold ehr_expected_response
  ring

theorem p_forgive_nonneg (ep : EHRParams) (rePos : ℝ) (ha : 0 ≤ ep.alpha) (hr : 0 ≤ rePos) :
    0 ≤ p_forgive ep rePos :=
  le_min (by norm_num) (mul_nonneg ha hr)

theorem p_forgive_le_one (ep : EHRParams) (rePos : ℝ) : p_forgive ep rePos ≤ 1 :=
  min_le_left _ _

theorem p_overreact_nonneg (ep : EHRParams) (rePos reNeg : ℝ) (hd : 0 ≤ ep.delta)
    (hn : 0 ≤ reNeg) : 0 ≤ p_overreact ep rePos reNeg :=
  le_min (by linarith [p_forgive_le_one ep rePos]) (mul_nonneg hd hn)

/-- THEOREM: The two probabilities are a valid split: p_F + p_O ≤ 1. -/
theorem probabilities_sum_le_one (ep : EHRParams) (rePos reNeg : ℝ) :
    p_forgive ep rePos + p_overreact ep rePos reNeg ≤ 1 := by
  have := min_le_left (1 - p_forgive ep rePos) (ep.delta * reNeg)
  unfold p_overreact
  linarith

/-- THEOREM: A novel entity (no reputation history) meets pure tit-for-tat: response = harm. -/
theorem novel_entity_pure_tit_for_tat (ep : EHRParams) (h : ℝ) :
    ehr_expected_response ep h 0 0 = h := by
  have hF : p_forgive ep 0 = 0 := by
    unfold p_forgive
    rw [mul_zero]
    exact min_eq_right zero_le_one
  have hO : p_overreact ep 0 0 = 0 := by
    unfold p_overreact
    rw [hF, mul_zero]
    exact min_eq_right (by norm_num)
  rw [ehr_expected_response_eq, hF, hO]
  ring

/-- THEOREM: Cooperation is met with cooperation: no incoming harm, no response. -/
theorem cooperation_met_with_cooperation (ep : EHRParams) (rePos reNeg : ℝ) :
    ehr_expected_response ep 0 rePos reNeg = 0 := by
  rw [ehr_expected_response_eq]
  ring

/-- THEOREM: The expected response is never negative and never exceeds (1 + margin)·h. -/
theorem ehr_response_bounds (ep : EHRParams) (h rePos reNeg : ℝ) (hh : 0 ≤ h)
    (ha : 0 ≤ ep.alpha) (hd : 0 ≤ ep.delta) (hm : 0 ≤ ep.margin)
    (hp : 0 ≤ rePos) (hn : 0 ≤ reNeg) :
    0 ≤ ehr_expected_response ep h rePos reNeg ∧
      ehr_expected_response ep h rePos reNeg ≤ (1 + ep.margin) * h := by
  rw [ehr_expected_response_eq]
  have hF0 := p_forgive_nonneg ep rePos ha hp
  have hF1 := p_forgive_le_one ep rePos
  have hO0 := p_overreact_nonneg ep rePos reNeg hd hn
  have hO1 : p_overreact ep rePos reNeg ≤ 1 := by
    have := probabilities_sum_le_one ep rePos reNeg
    linarith
  have hfac0 : 0 ≤ 1 - p_forgive ep rePos + ep.margin * p_overreact ep rePos reNeg := by
    nlinarith [mul_nonneg hm hO0]
  have hfac1 : 1 - p_forgive ep rePos + ep.margin * p_overreact ep rePos reNeg ≤ 1 + ep.margin := by
    nlinarith [mul_le_mul_of_nonneg_left hO1 hm]
  constructor
  · exact mul_nonneg hh hfac0
  · nlinarith [mul_le_mul_of_nonneg_left hfac1 hh]

/--
  THEOREM: Positive reputation earns forgiveness. More accumulated positive reputation in the
  harm's domains never raises the expected response.
-/
theorem more_positive_reputation_lowers_response (ep : EHRParams) (h r₁ r₂ reNeg : ℝ)
    (hh : 0 ≤ h) (ha : 0 ≤ ep.alpha) (hm : 0 ≤ ep.margin) (hr : r₁ ≤ r₂) :
    ehr_expected_response ep h r₂ reNeg ≤ ehr_expected_response ep h r₁ reNeg := by
  rw [ehr_expected_response_eq, ehr_expected_response_eq]
  have hF : p_forgive ep r₁ ≤ p_forgive ep r₂ :=
    min_le_min (le_refl 1) (mul_le_mul_of_nonneg_left hr ha)
  have hO : p_overreact ep r₂ reNeg ≤ p_overreact ep r₁ reNeg :=
    min_le_min (by linarith) (le_refl _)
  have hfac : 1 - p_forgive ep r₂ + ep.margin * p_overreact ep r₂ reNeg ≤
      1 - p_forgive ep r₁ + ep.margin * p_overreact ep r₁ reNeg := by
    nlinarith [mul_le_mul_of_nonneg_left hO hm]
  exact mul_le_mul_of_nonneg_left hfac hh

/--
  THEOREM: Bias toward forgiveness (Critique addressal.txt) follows from the priority order.
  With equal accumulated reputation on both ledgers and δ < α (L11), forgiveness is strictly more
  likely than overreaction (below the cap α·r ≤ 1).
-/
theorem forgiveness_bias (ep : EHRParams) (r : ℝ) (hr : 0 < r) (hda : ep.delta < ep.alpha)
    (hcap : ep.alpha * r ≤ 1) :
    p_overreact ep r r < p_forgive ep r := by
  have hF : p_forgive ep r = ep.alpha * r := min_eq_right hcap
  have hO : p_overreact ep r r ≤ ep.delta * r := min_le_right _ _
  have hlt : ep.delta * r < ep.alpha * r := mul_lt_mul_of_pos_right hda hr
  linarith

end Benefuture.Governance
