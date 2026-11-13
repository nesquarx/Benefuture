/-
  Benefuture.Proposed.ReviewFindings
  [P] Acceptance and counterexample theorems for gaps found in review (`docs/BACKPROPAGATION.md`
  8.137–8.144). Each section names the pseudocode line it reads and the finding it states.

  1. Law drift (L139, EmbeddedLaws, `DynamicAp: ΔImp(ΔLw) < Th`): bounded adaptations bound the
     drift over n steps by n · Th; without a bound on n, sub-threshold steps pass any limit, which
     is why Civilizational Continuity validates change over a span, not per step.
  2. Resource accounting direction (L83, L152): cost per gain ranks a harmful transaction ahead of
     every beneficial one under minimisation; gain per cost ranks it behind.
  3. Harm split across identities (finding 8.58-e): a convex penalty is lighter on a split harm;
     assessed on the origin's total it is not.
  4. Confidence voting (L115, `logit(Cf)`): even confidence carries no weight, confidence orders
     weight, opposite confidences cancel, and a record with no accuracy carries no weight.
  5. Extremisers (open problem): against an honest forecaster, the extremist wins a
     winner-take-all contest more often than not while its expected Brier loss is worse.
  6. Common-mode error (open problem): pooling models leaves their shared error untouched,
     whatever their number; with no shared error, pooling removes the idiosyncratic part.
  7. Stasis is not harmless (L36, L37, L54, L151): under constant experience novelty falls, so
     happiness falls below the average of its window. Zero standing harm does not persist unaided.

  IMPORTANT ARCHITECTURAL RULE: core Benefuture modules MUST NOT import this file.
-/

import Mathlib.Data.Real.Basic
import Mathlib.Algebra.Order.Field.Basic
import Mathlib.Algebra.Order.Archimedean.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.Order.BigOperators.Group.Finset
import Mathlib.Data.Fintype.Card
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Ring
import Mathlib.Tactic.Positivity

namespace Benefuture.Proposed.ReviewFindings

open Finset

/- =========================================================================
   1. Law drift (L139)
   ========================================================================= -/

/-- [P] THEOREM (acceptance): if each of n law adaptations changes impact by less than the
    threshold in size, the accumulated change is at most n · Th in size. -/
theorem bounded_adaptations_bound_drift (n : ℕ) (impact : Fin n → ℝ) (th : ℝ)
    (h : ∀ i, |impact i| < th) :
    |∑ i, impact i| ≤ n * th := by
  calc |∑ i, impact i| ≤ ∑ i, |impact i| := Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ _i : Fin n, th := Finset.sum_le_sum (fun i _ => (h i).le)
    _ = n * th := by simp

/-- [P] THEOREM (counterexample): the per-step bound alone bounds nothing. For any threshold and
    any limit, enough adaptations of half the threshold each pass the limit. -/
theorem sub_threshold_steps_pass_any_limit (th limit : ℝ) (hth : 0 < th) :
    ∃ n : ℕ, limit < n * (th / 2) ∧ |th / 2| < th := by
  obtain ⟨n, hn⟩ := exists_nat_gt (limit / (th / 2))
  have hhalf : 0 < th / 2 := by linarith
  refine ⟨n, ?_, ?_⟩
  · have := (div_lt_iff₀ hhalf).mp hn
    linarith
  · rw [abs_of_pos hhalf]
    linarith

/- =========================================================================
   2. Resource accounting direction (L83, L152)
   ========================================================================= -/

/-- [P] THEOREM (counterexample): read as cost per gain and minimised, resource accounting ranks a
    harmful transaction (negative gain) ahead of every beneficial one. -/
theorem cost_per_gain_prefers_harm (cost gain cost' gain' : ℝ)
    (hc : 0 < cost) (hg : gain < 0) (hc' : 0 < cost') (hg' : 0 < gain') :
    cost / gain < cost' / gain' := by
  have h1 : cost / gain < 0 := div_neg_of_pos_of_neg hc hg
  have h2 : 0 < cost' / gain' := div_pos hc' hg'
  linarith

/-- [P] THEOREM (acceptance): read as gain per cost and maximised, a harmful transaction ranks
    behind every beneficial one. -/
theorem gain_per_cost_ranks_harm_last (cost gain cost' gain' : ℝ)
    (hc : 0 < cost) (hg : gain < 0) (hc' : 0 < cost') (hg' : 0 < gain') :
    gain / cost < gain' / cost' := by
  have h1 : gain / cost < 0 := div_neg_of_neg_of_pos hg hc
  have h2 : 0 < gain' / cost' := div_pos hg' hc'
  linarith

/- =========================================================================
   3. Harm split across identities (8.58-e)
   ========================================================================= -/

/-- A convex penalty on a harm's size; the square stands for any strictly convex weight
    (the harm weight of L61 has exponent 1.5). -/
def convexPenalty (harm : ℝ) : ℝ := harm ^ 2

/-- [P] THEOREM (counterexample): a harm split between two identities is penalised less than the
    same harm whole. -/
theorem split_harm_lightens_convex_penalty (a b : ℝ) (ha : 0 < a) (hb : 0 < b) :
    convexPenalty a + convexPenalty b < convexPenalty (a + b) := by
  unfold convexPenalty
  nlinarith [mul_pos ha hb]

/-- The penalty assessed on the origin: the forks' harms are summed before the weight applies,
    and each fork carries its share of the result. -/
noncomputable def originPenaltyShare (a b : ℝ) : ℝ × ℝ :=
  (convexPenalty (a + b) * (a / (a + b)), convexPenalty (a + b) * (b / (a + b)))

/-- [P] THEOREM (acceptance): assessed on the origin, the shares add up to the whole harm's
    penalty, so splitting gains nothing. -/
theorem origin_assessment_removes_split_gain (a b : ℝ) (ha : 0 < a) (hb : 0 < b) :
    (originPenaltyShare a b).1 + (originPenaltyShare a b).2 = convexPenalty (a + b) := by
  unfold originPenaltyShare
  have hab : a + b ≠ 0 := by positivity
  simp only
  field_simp

/- =========================================================================
   4. Confidence voting (L115)
   ========================================================================= -/

/-- The log-odds of a confidence in (0, 1). -/
noncomputable def logit (c : ℝ) : ℝ := Real.log c - Real.log (1 - c)

/-- One ballot's term in L115: vote weight · accuracy of the voter's record · logit(confidence). -/
noncomputable def ballotTerm (weight accuracy confidence : ℝ) : ℝ :=
  weight * accuracy * logit confidence

/-- [P] THEOREM: even confidence carries no weight. -/
theorem logit_half : logit (1 / 2) = 0 := by
  unfold logit
  have h : (1 : ℝ) - 1 / 2 = 1 / 2 := by norm_num
  rw [h, sub_self]

/-- [P] THEOREM: opposite confidences cancel. -/
theorem logit_complement (c : ℝ) : logit (1 - c) = -logit c := by
  unfold logit
  have h : (1 : ℝ) - (1 - c) = c := by ring
  rw [h]
  ring

/-- [P] THEOREM: more confidence, more weight. -/
theorem logit_strict_mono (a b : ℝ) (ha : 0 < a) (hab : a < b) (hb : b < 1) :
    logit a < logit b := by
  unfold logit
  have h1 : Real.log a < Real.log b := Real.log_lt_log ha hab
  have h2 : Real.log (1 - b) < Real.log (1 - a) := Real.log_lt_log (by linarith) (by linarith)
  linarith

/-- [P] THEOREM (counterexample to confidence alone deciding): a record with no accuracy carries
    no weight, however confident the ballot. -/
theorem no_record_no_weight (weight confidence : ℝ) : ballotTerm weight 0 confidence = 0 := by
  unfold ballotTerm
  simp

/- =========================================================================
   5. Extremisers against honest forecasters
   ========================================================================= -/

/-- Brier loss of a report on an outcome (1 occurred, 0 did not). -/
def brier (report outcome : ℝ) : ℝ := (report - outcome) ^ 2

/-- [P] THEOREM (counterexample): an event has probability q in (1/2, 1). The honest forecaster
    reports q; the extremist reports 1. The extremist has the lower loss whenever the event
    occurs, so it wins a winner-take-all contest with probability q > 1/2, yet its expected Brier
    loss is strictly worse. Selection by wins rewards what the proper score penalises. -/
theorem extremist_wins_more_and_scores_worse (q : ℝ) (hq : 1 / 2 < q) (hq1 : q < 1) :
    brier 1 1 < brier q 1 ∧ 1 / 2 < q ∧
    q * brier q 1 + (1 - q) * brier q 0 < q * brier 1 1 + (1 - q) * brier 1 0 := by
  unfold brier
  have h : 0 < (1 - q) * (1 - q) := mul_pos (by linarith) (by linarith)
  refine ⟨by nlinarith, hq, by nlinarith⟩

/- =========================================================================
   6. Common-mode error
   ========================================================================= -/

/-- [P] THEOREM (counterexample): k models share an error and each adds its own. If their own
    errors average out, the pooled error is still the shared one, for every k. -/
theorem pooling_keeps_shared_error (k : ℕ) (hk : 0 < k) (shared : ℝ) (own : Fin k → ℝ)
    (hown : ∑ i, own i = 0) :
    (∑ i, (shared + own i)) / k = shared := by
  have hk' : (k : ℝ) ≠ 0 := by exact_mod_cast hk.ne'
  rw [Finset.sum_add_distrib, hown, add_zero]
  simp only [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]
  field_simp

/-- [P] THEOREM (acceptance): with no shared error, pooling models whose own errors average out
    leaves none. -/
theorem pooling_removes_independent_error (k : ℕ) (hk : 0 < k) (own : Fin k → ℝ)
    (hown : ∑ i, own i = 0) :
    (∑ i, ((0 : ℝ) + own i)) / k = 0 :=
  pooling_keeps_shared_error k hk 0 own hown

/- =========================================================================
   7. Stasis is not harmless (L36, L37, L54, L151)
   ========================================================================= -/

/-- Happiness under constant experience: a constant positive part plus novelty, which is
    1 / frequency (L36); at step n the same experience has occurred n + 1 times. -/
noncomputable def stasisHappiness (base : ℝ) (n : ℕ) : ℝ := base + 1 / ((n : ℝ) + 1)

/-- [P] THEOREM: under constant experience happiness strictly falls each step. -/
theorem stasis_happiness_falls (base : ℝ) (n : ℕ) :
    stasisHappiness base (n + 1) < stasisHappiness base n := by
  unfold stasisHappiness
  have hpos : (0 : ℝ) < (n : ℝ) + 1 := by positivity
  have hlt : (n : ℝ) + 1 < ((n + 1 : ℕ) : ℝ) + 1 := by push_cast; linarith
  have := one_div_lt_one_div_of_lt hpos hlt
  linarith

/-- [P] THEOREM: under constant experience happiness is below the average of its preceding
    window (here two steps), which is harm by L54. A flat harm reading at zero is therefore not
    a resting state, and `Harm_Intv` (L151) reading "not falling" as a trigger is sound. -/
theorem stasis_is_harm (base : ℝ) (n : ℕ) :
    stasisHappiness base (n + 2) <
      (stasisHappiness base n + stasisHappiness base (n + 1)) / 2 := by
  have h1 := stasis_happiness_falls base n
  have h2 := stasis_happiness_falls base (n + 1)
  have h3 : stasisHappiness base (n + 1 + 1) = stasisHappiness base (n + 2) := rfl
  rw [h3] at h2
  linarith

end Benefuture.Proposed.ReviewFindings
