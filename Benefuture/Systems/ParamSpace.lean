/-
  Benefuture.Systems.ParamSpace
  [R] The Bf parameter space: every governed parameter, its bootstrap default, admissibility
  (ranges and cross-parameter constraints the proved theorems rely on), and SigThGv governance.
  Corresponds to: Bf_Pseudocode.txt L11, L13-14, L25, L54, L61, L73, L101, L114, L135, L155, L157.
  "SigThGv := Ap(Th ∈ Debatable? LqdBfDm : Perturb(Th ± δ ∈ Fr));"

  Parameters start from bootstrap defaults (Bf system-design bootstrap) and are thereafter governed
  by SigThGv: debatable parameters by liquid democracy (LqdBfDm), the rest by controlled perturbation.
  The spec defines the space and what holds everywhere in it; simulation explores values.
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Linarith
import Benefuture.Math.Order
import Benefuture.Math.Synergy
import Benefuture.Subgoals.Freedom
import Benefuture.Governance.ExternalHarm

namespace Benefuture.Systems

open Benefuture.Math
open Benefuture.Subgoals
open Benefuture.Governance

/-- [R] One point in the Bf parameter space. -/
structure ParamVector where
  -- Priority hierarchy (L11)
  alpha            : ℝ
  beta             : ℝ
  gamma            : ℝ
  delta            : ℝ
  -- Synergy (L13); κ for V (L73) and for Ha_wt (L61); Ha_wt exponent (L61)
  kappa            : ℝ
  q_plus           : ℝ
  q_minus          : ℝ
  lambda           : ℝ
  kappa_value      : ℝ
  kappa_harm       : ℝ
  q_harm           : ℝ
  -- Squashed synergy (L14)
  nu               : ℝ
  h_param          : ℝ
  -- Reputation decay (L101)
  lambda_plus      : ℝ
  lambda_minus     : ℝ
  -- Significance and governance thresholds (L25, L155)
  th_sig           : ℝ
  th_gov           : ℝ
  -- Freedom (L135)
  fr_thConf        : ℝ
  fr_thHigh        : ℝ
  sev_irreparable  : ℝ
  sev_irreversible : ℝ
  sev_longterm     : ℝ
  sev_passing      : ℝ
  sev_timeLoss     : ℝ
  -- H-harm rolling window (L54) and delegation cap Th_k as a share of total weight (L114)
  h_window         : ℕ
  deleg_cap        : ℝ
  -- EHR overreaction margin (L117)
  ehr_margin       : ℝ
  -- Weight of the assessed distribution term in G (L62, L74): w_D in Sy(V, As(pushDistr))
  dist_weight      : ℝ

/-- [R] Admissible parameter vectors: the ranges and joint constraints the proved theorems need. -/
structure Admissible (pv : ParamVector) : Prop where
  -- L11: 1 > α > β > γ > δ > 0
  alpha_lt_one       : pv.alpha < 1
  beta_lt_alpha      : pv.beta < pv.alpha
  gamma_lt_beta      : pv.gamma < pv.beta
  delta_lt_gamma     : pv.delta < pv.gamma
  delta_pos          : 0 < pv.delta
  -- L13: κ ≥ 0; q₊ > 1 (depth over breadth); q₋ ≥ q₊ (losses convex relative to gains);
  -- 0 ≤ λ ≤ 1 (Sy Pareto-monotone, `sy_score_pareto_monotone`)
  kappa_nonneg       : 0 ≤ pv.kappa
  q_plus_gt_one      : 1 < pv.q_plus
  q_plus_le_q_minus  : pv.q_plus ≤ pv.q_minus
  lambda_nonneg      : 0 ≤ pv.lambda
  lambda_le_one      : pv.lambda ≤ 1
  -- L61, L73
  kappa_value_nonneg : 0 ≤ pv.kappa_value
  kappa_harm_nonneg  : 0 ≤ pv.kappa_harm
  q_harm_gt_one      : 1 < pv.q_harm
  -- L14
  nu_pos             : 0 < pv.nu
  h_param_pos        : 0 < pv.h_param
  -- L101
  lambda_plus_pos    : 0 < pv.lambda_plus
  lambda_minus_pos   : 0 < pv.lambda_minus
  -- Mistakes decay slower than wins (author ruling, BACKPROPAGATION 8.29: ledger asymmetry)
  lambda_minus_lt    : pv.lambda_minus < pv.lambda_plus
  -- L25, L155
  th_sig_pos         : 0 < pv.th_sig
  th_gov_pos         : 0 < pv.th_gov
  -- L135: confidence threshold in (0, 1]; positive ceiling; severities positive and ordered
  fr_thConf_pos      : 0 < pv.fr_thConf
  fr_thConf_le_one   : pv.fr_thConf ≤ 1
  fr_thHigh_pos      : 0 < pv.fr_thHigh
  sev_timeLoss_pos   : 0 < pv.sev_timeLoss
  sev_order_1        : pv.sev_timeLoss ≤ pv.sev_passing
  sev_order_2        : pv.sev_passing ≤ pv.sev_longterm
  sev_order_3        : pv.sev_longterm ≤ pv.sev_irreversible
  sev_order_4        : pv.sev_irreversible ≤ pv.sev_irreparable
  -- L54, L114
  h_window_pos       : 1 ≤ pv.h_window
  deleg_cap_pos      : 0 < pv.deleg_cap
  deleg_cap_le_one   : pv.deleg_cap ≤ 1
  -- L117
  ehr_margin_nonneg  : 0 ≤ pv.ehr_margin
  -- L62, L74: the distribution term enters G through Sy, not additively, so it is not discounted
  dist_weight_pos    : 0 < pv.dist_weight

/--
  [P] Bootstrap defaults (Bf system-design bootstrap), matching `defaultGovParams`,
  `harmSchedule`'s Ha_wt reading (κ = ½, q = 1.5), V's κ = 2 and `defaultFrParams`.
  Window 10 and delegation cap 5% are bootstrap choices for SigThGv to take over.
-/
noncomputable def bootstrapParams : ParamVector :=
  { alpha := 0.8, beta := 0.6, gamma := 0.4, delta := 0.2,
    kappa := 1, q_plus := 1.1, q_minus := 1.5, lambda := 0.5,
    kappa_value := 2, kappa_harm := 0.5, q_harm := 1.5,
    nu := 1, h_param := 1,
    lambda_plus := 0.05, lambda_minus := 0.02,
    th_sig := 0.5, th_gov := 0.7,
    fr_thConf := 0.9, fr_thHigh := 1,
    sev_irreparable := 1000, sev_irreversible := 100, sev_longterm := 10,
    sev_passing := 1, sev_timeLoss := 0.5,
    h_window := 10, deleg_cap := 0.05, ehr_margin := 0.25,
    dist_weight := 1 }

/-- THEOREM: The bootstrap point is admissible. -/
theorem bootstrap_admissible : Admissible bootstrapParams := by
  constructor <;> norm_num [bootstrapParams]

/-- [R] The core GovParams record of an admissible parameter vector. -/
noncomputable def ParamVector.toGovParams (pv : ParamVector) (h : Admissible pv) : GovParams :=
  { alpha := pv.alpha, beta := pv.beta, gamma := pv.gamma, delta := pv.delta,
    h_alpha_lt_one := h.alpha_lt_one, h_beta_lt_alpha := h.beta_lt_alpha,
    h_gamma_lt_beta := h.gamma_lt_beta, h_delta_lt_gamma := h.delta_lt_gamma,
    h_delta_pos := h.delta_pos,
    kappa := pv.kappa, q_plus := pv.q_plus, q_minus := pv.q_minus, lambda := pv.lambda,
    h_kappa_nonneg := h.kappa_nonneg,
    h_q_plus_pos := by linarith [h.q_plus_gt_one],
    h_q_minus_pos := by linarith [h.q_plus_gt_one, h.q_plus_le_q_minus],
    h_lambda_nonneg := h.lambda_nonneg,
    nu := pv.nu, h_param := pv.h_param, h_nu_pos := h.nu_pos, h_h_param_pos := h.h_param_pos,
    lambda_plus := pv.lambda_plus, lambda_minus := pv.lambda_minus,
    h_lambda_plus_pos := h.lambda_plus_pos, h_lambda_minus_pos := h.lambda_minus_pos,
    th_sig := pv.th_sig, th_gov := pv.th_gov,
    h_th_sig_pos := h.th_sig_pos, h_th_gov_pos := h.th_gov_pos }

/-- [R] The Fr parameters of a parameter vector. -/
noncomputable def ParamVector.toFrParams (pv : ParamVector) : FrParams :=
  { thConf := pv.fr_thConf, thHigh := pv.fr_thHigh,
    sevIrreparable := pv.sev_irreparable, sevIrreversible := pv.sev_irreversible,
    sevLongterm := pv.sev_longterm, sevPassing := pv.sev_passing, sevTimeLoss := pv.sev_timeLoss }

/-- [R] EHR parameters of a parameter vector (L117): α and δ from L11, overreaction margin. -/
noncomputable def ParamVector.toEHRParams (pv : ParamVector) : EHRParams :=
  { alpha := pv.alpha, delta := pv.delta, margin := pv.ehr_margin }

/- --- SigThGv governance (L157) --- -/

/-- [R] SigThGv modes (L157): debatable parameters by LqdBfDm, others by controlled perturbation. -/
inductive GovMode where
  | debatable    : GovMode
  | perturbation : GovMode
  deriving Repr, DecidableEq

/--
  [R] A governance step: a proposal (from LqdBfDm or perturbation) is adopted only if the
  resulting vector is admissible; otherwise the current vector stands.
-/
noncomputable def gov_step (pv proposal : ParamVector) : ParamVector :=
  haveI := Classical.propDecidable (Admissible proposal)
  if Admissible proposal then proposal else pv

theorem gov_step_preserves (pv proposal : ParamVector) (h : Admissible pv) :
    Admissible (gov_step pv proposal) := by
  unfold gov_step
  split_ifs with hp
  · exact hp
  · exact h

/-- [R] A sequence of governance steps. -/
noncomputable def gov_run : ParamVector → List ParamVector → ParamVector
  | pv, [] => pv
  | pv, q :: qs => gov_run (gov_step pv q) qs

theorem gov_run_preserves : ∀ (qs : List ParamVector) (pv : ParamVector),
    Admissible pv → Admissible (gov_run pv qs)
  | [], _, h => h
  | q :: qs, pv, h => gov_run_preserves qs (gov_step pv q) (gov_step_preserves pv q h)

/--
  THEOREM: Every parameter vector reachable from bootstrap by SigThGv is admissible, so every
  theorem stated for admissible parameters holds throughout governance.
-/
theorem governed_params_admissible (qs : List ParamVector) :
    Admissible (gov_run bootstrapParams qs) :=
  gov_run_preserves qs bootstrapParams bootstrap_admissible

/--
  [R] Controlled perturbation (L157: Perturb(Th ± δ ∈ Fr)): a candidate is adopted only if it is
  admissible and every governed field moves by at most δ.
-/
noncomputable def perturb_step (fields : List (ParamVector → ℝ)) (δ : ℝ)
    (pv cand : ParamVector) : ParamVector :=
  haveI := Classical.propDecidable (Admissible cand ∧ ∀ f ∈ fields, |f cand - f pv| ≤ δ)
  if Admissible cand ∧ ∀ f ∈ fields, |f cand - f pv| ≤ δ then cand else pv

theorem perturb_step_preserves (fields : List (ParamVector → ℝ)) (δ : ℝ) (pv cand : ParamVector)
    (h : Admissible pv) : Admissible (perturb_step fields δ pv cand) := by
  unfold perturb_step
  split_ifs with hc
  · exact hc.1
  · exact h

theorem perturb_step_close (fields : List (ParamVector → ℝ)) (δ : ℝ) (hδ : 0 ≤ δ)
    (pv cand : ParamVector) (f : ParamVector → ℝ) (hf : f ∈ fields) :
    |f (perturb_step fields δ pv cand) - f pv| ≤ δ := by
  unfold perturb_step
  split_ifs with hc
  · exact hc.2 f hf
  · simpa using hδ

/-- [R] A sequence of perturbation steps. -/
noncomputable def perturb_run (fields : List (ParamVector → ℝ)) (δ : ℝ) :
    ParamVector → List ParamVector → ParamVector
  | pv, [] => pv
  | pv, c :: cs => perturb_run fields δ (perturb_step fields δ pv c) cs

theorem perturb_run_preserves (fields : List (ParamVector → ℝ)) (δ : ℝ) :
    ∀ (cs : List ParamVector) (pv : ParamVector), Admissible pv →
      Admissible (perturb_run fields δ pv cs)
  | [], _, h => h
  | c :: cs, pv, h =>
    perturb_run_preserves fields δ cs (perturb_step fields δ pv c)
      (perturb_step_preserves fields δ pv c h)

/--
  THEOREM: Bounded drift. After n perturbation steps every governed field has moved by at most n·δ:
  evolutionary perturbation cannot jump a parameter; large moves need debate (LqdBfDm).
-/
theorem perturb_run_drift (fields : List (ParamVector → ℝ)) (δ : ℝ) (hδ : 0 ≤ δ)
    (f : ParamVector → ℝ) (hf : f ∈ fields) :
    ∀ (cs : List ParamVector) (pv : ParamVector),
      |f (perturb_run fields δ pv cs) - f pv| ≤ cs.length * δ
  | [], pv => by simp [perturb_run]
  | c :: cs, pv => by
    have h1 := perturb_run_drift fields δ hδ f hf cs (perturb_step fields δ pv c)
    have h2 := perturb_step_close fields δ hδ pv c f hf
    have h3 := abs_sub_le (f (perturb_run fields δ (perturb_step fields δ pv c) cs))
      (f (perturb_step fields δ pv c)) (f pv)
    simp only [perturb_run, List.length_cons, Nat.cast_succ]
    rw [add_mul, one_mul]
    linarith

/- --- What holds everywhere in the admissible space --- -/

/--
  THEOREM: Loss aversion holds for every significant input at every admissible point
  (L13, L25, L48; `significant_assessment_preserves_loss_aversion`).
-/
theorem admissible_loss_aversion (pv : ParamVector) (h : Admissible pv) (d th : ℝ)
    (hth : 0 < th) (hsig : th ≤ |d|) :
    |d / th| ^ pv.q_plus ≤ |d / th| ^ pv.q_minus :=
  significant_assessment_preserves_loss_aversion d th pv.q_plus pv.q_minus hth hsig
    h.q_plus_le_q_minus

/--
  THEOREM: At every admissible point EHR is biased toward forgiveness: with equal accumulated
  reputation on both ledgers (below the cap), forgiveness is strictly more likely than overreaction,
  because δ < α in the L11 priority order.
-/
theorem admissible_forgiveness_bias (pv : ParamVector) (h : Admissible pv) (r : ℝ) (hr : 0 < r)
    (hcap : pv.alpha * r ≤ 1) :
    p_overreact pv.toEHRParams r r < p_forgive pv.toEHRParams r :=
  forgiveness_bias pv.toEHRParams r hr
    (by
      show pv.delta < pv.alpha
      linarith [h.delta_lt_gamma, h.gamma_lt_beta, h.beta_lt_alpha])
    hcap

end Benefuture.Systems
