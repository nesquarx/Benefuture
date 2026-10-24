/-
  Benefuture.Axiology.Value
  Formalization of the Benefuture Value function V(A, b) and Goal function G over ℝ.
  Corresponds to: Bf_Pseudocode.txt L73-75, L79-81
  "V(A, b ∈ B) := Sy_{2}(As([(U(b), α, Ha_wt), (H(b), β, α * Ha_wt), (N, γ)], A, t));"
  "Goal«G»(t) := argmax_{A(t)} [Σ_{b ∈ B(t)} V(A, b(t))] ∧ ↑ℝ;"
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Linarith
import Benefuture.Math.Order
import Benefuture.Math.Synergy
import Benefuture.Ontology.Being
import Benefuture.Ontology.Entity
import Benefuture.Ontology.Reality
import Benefuture.Axiology.Priorities

namespace Benefuture.Axiology

open Benefuture.Math
open Benefuture.Ontology

/-- 
  [R] Evaluates Value V(A, b) on Being b (L73):
  V(A, b ∈ B) := Sy_{2}(As([(U(b), α, Ha_wt), (H(b), β, α * Ha_wt), (N, γ)], A, t)).
  
  Evaluates outer synergy over assessed dimensions:
  1. Understanding (U) with weight α · Ha_wt
  2. Happiness (H) with weight β · α · Ha_wt
  3. Novelty (N) with weight γ
  
  NOTE: The ad hoc δ penalty and experienceLevel multiplier from early drafts are removed.
  [OPEN] Sentience Capacity Multiplier:
  Scaling value by sentience capacity (e.g. experienceLevel) is a proposed extension
  but is omitted from the core pseudocode L73; marked [OPEN] pending empirical calibration.
-/
noncomputable def value_on_being 
    (_b : Being) (asmt : PrioritizedAssessment) (sched : ParamSchedule) (p : GovParams) : ℝ :=
  let u_val := synthesize_understanding asmt.u_tiers sched p
  let h_val := synthesize_happiness asmt.h_tiers sched p
  let n_val := synthesize_novelty asmt.n_tiers sched p
  let ha_wt := compute_harm_weight asmt.harm_prof sched p
  -- SPEC-CHOICE: items read through the Sy signature [(x, w₊, w₋ = w₊)] (L13):
  -- U: gains α, losses Ha_wt; H: gains β, losses α·Ha_wt; N: γ both ways.
  -- Benefuture goals.txt: harm is "counted as a weight on losses".
  let items : List (ℝ × ℝ × ℝ) := [
    (u_val, p.alpha, ha_wt),
    (h_val, p.beta, p.alpha * ha_wt),
    (n_val, p.gamma, p.gamma)
  ]
  -- SPEC-CHOICE: Sy_{2} (L73) read through Sy_{κ,q₊} (L13) as κ = 2;
  -- Benefuture goals.txt: "κ = 1 (2 for Value itself)".
  net_synergy_signed items (p.with_kappa 2 (by norm_num))

/-- 
  [R] The Aggregate Sentient Value Sum over a population of Beings (L74):
  Σ_{b ∈ B} V(A, b).
-/
noncomputable def aggregate_sentient_value 
    (population : List Being) (asmt_fn : Being → PrioritizedAssessment) 
    (sched : ParamSchedule) (p : GovParams) : ℝ :=
  (population.map (fun b => value_on_being b (asmt_fn b) sched p)).sum

/- --- Complete Benefuture Goal G(t) (L74) --- -/

-- SPEC-CHOICE: On ↑ℝ (L74):
-- We specify that ↑ℝ requires non-decreasing reality scope (delta ≥ 0).
-- A strictly increasing requirement (delta > 0) would disqualify routine flourishing-preserving actions.
-- Furthermore, we fix the bug where an ineligible contracting action (previously defaulting to value 0)
-- outranked an eligible expanding action with negative value (e.g. -5).
-- Contraction is handled via filter-based eligibility, NOT a 0-default value!

/-- Evaluated Action profile with sentient value sum and reality scope boundary change. -/
structure ActionEvaluation where
  action         : Action
  aggregateValue : ℝ
  scopeBefore    : RealityScope
  scopeAfter     : RealityScope

/-- 
  Eligibility condition for Goal G:
  Action must satisfy ↑ℝ (non-decreasing reality scope: delta ≥ 0).
-/
def is_eligible_action (eval : ActionEvaluation) : Bool :=
  reality_enhancement_delta eval.scopeBefore eval.scopeAfter ≥ 0

/-- Predicate: An evaluated action satisfies Goal G iff it generates positive value and preserves/enhances reality. -/
def satisfies_goal_G (eval : ActionEvaluation) : Prop :=
  eval.aggregateValue > 0 ∧ reality_enhancement_delta eval.scopeBefore eval.scopeAfter ≥ 0

/-- Filter candidate actions down to those that satisfy the ↑ℝ reality invariant. -/
def eligible_actions (evals : List ActionEvaluation) : List ActionEvaluation :=
  evals.filter is_eligible_action

/-- 
  MASTER THEOREM: Anti-Inward-Collapse Invariant (L74).
  A civilization that turns inward, shrinking its perceptual scope or collapsing its causal capability
  in the Universe (delta < 0), is disqualified from Goal G.
-/
theorem inward_shrinkage_violates_goal (eval : ActionEvaluation) 
    (h_shrink : reality_enhancement_delta eval.scopeBefore eval.scopeAfter < 0) :
    ¬ satisfies_goal_G eval := by
  intro h_sat
  have h_enh := h_sat.2
  linarith

/-- 
  THEOREM: Bugfix Verification (Contracting Actions Excluded from Argmax).
  A contracting action (delta < 0) is strictly ineligible and filtered out of consideration,
  preventing contracting actions from erroneously outranking eligible actions.
-/
theorem contracting_action_is_ineligible (eval : ActionEvaluation)
    (h_shrink : reality_enhancement_delta eval.scopeBefore eval.scopeAfter < 0) :
    is_eligible_action eval = false := by
  unfold is_eligible_action
  have hnot : ¬(reality_enhancement_delta eval.scopeBefore eval.scopeAfter ≥ 0) := by linarith
  simp [hnot]

/-- 
  Good (Gd): Any action or transition that increases systemic Value V.
  Corresponds to: Bf_Pseudocode.txt L79: "Good«Gd»(t) := ↑V(t);"
-/
noncomputable def is_good (delta_v : ℝ) : Bool :=
  delta_v > 0

/-- 
  Bad (Bd): Any action or outcome that produces net Harm.
  Corresponds to: Bf_Pseudocode.txt L80: "Bad«Bd»(t) := (A, O) → Ha(t);"
-/
noncomputable def is_bad (delta_v : ℝ) (harm_caused : ℝ) : Bool :=
  delta_v < 0 ∨ harm_caused > 0

noncomputable abbrev V := value_on_being
noncomputable abbrev Gd := is_good
noncomputable abbrev Bd := is_bad

end Benefuture.Axiology
