/-
  Benefuture.Axiology.Value
  Formalization of the Benefuture Value function V(A, b) and Goal function G.
  Corresponds to: Bf_Pseudocode.txt L73-75, L79-81
  "V(A, b ∈ B) := Sy_{2}(As([(U(b), α, Ha_wt), (H(b), β, α * Ha_wt), (N, γ)], A, t));"
  "Goal«G»(t) := argmax_{A(t)} [Σ_{b ∈ B(t)} V(A, b(t))] ∧ ↑ℝ;"
-/

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
  Evaluates Value V(A, b) on Being b given the prioritized assessment:
  1. Synthesizes U from UnderstandingTiers: Sy(peak > teachable > meta > median > floor > undirected)
  2. Synthesizes H from HappinessTiers: Sy(eudaimonic > shareable > satisficing > baseline > median > peak)
  3. Synthesizes N from NoveltyTiers: Sy(paradigm > perspective > chaotic > incremental > perilous > trivial)
  4. Computes convex Harm Weight Ha_wt: 1 + Sy(Irreparable > Irreversible > Longterm...)
  5. Combines via outer Value formulation:
     V = [α * U + β * H + γ * N] - [δ * Ha_wt * total_harm] / SCALE
  6. Amplified by the Being's sentience level.
-/
def value_on_being (b : Being) (asmt : PrioritizedAssessment) (p : BfParams) (raw_harm_magnitude : Int) : Int :=
  let u_val := synthesize_understanding asmt.u_tiers
  let h_val := synthesize_happiness asmt.h_tiers
  let n_val := synthesize_novelty asmt.n_tiers
  let ha_wt := compute_harm_weight asmt.harm_prof
  
  -- Outer combination: α·U + β·H + γ·N
  let pos_components := (p.alpha * u_val + p.beta * h_val + p.gamma * n_val) / SCALE
  
  -- Harm penalty with convex severity multiplier
  let harm_penalty := (p.delta * ha_wt * raw_harm_magnitude) / (SCALE * SCALE)
  
  let raw_value := pos_components - harm_penalty
  -- Scaled by being's sentience capacity
  (raw_value * b.sentience.experienceLevel) / SCALE

/-- 
  The Aggregate Sentient Value Sum over a population of Beings:
  Σ_{b ∈ B} V(A, b).
-/
def aggregate_sentient_value (population : List Being) (asmt_fn : Being → PrioritizedAssessment) (p : BfParams) (harm_fn : Being → Int) : Int :=
  population.foldl (λ acc b => acc + value_on_being b (asmt_fn b) p (harm_fn b)) 0

/-- 
  The Complete Benefuture Goal G(t):
  Corresponds to: Bf_Pseudocode.txt L74:
  "Goal«G»(t) := argmax_{A(t)} [Σ_{b ∈ B(t)} V(A, b(t))] ∧ ↑ℝ;"
  
  The Goal function does NOT simply maximize internal value sum Σ V;
  it mandates a joint optimization where value maximization is strictly 
  coupled with Reality Enhancement (↑ℝ): expanding the frontier of what is 
  perceivable and changeable in the Universe.
  A civilization cannot shrink or turn inwards into a self-contained simulation box.
-/
structure GoalEvaluation extends Thing where
  population         : List Being
  aggregateValue     : Int           -- Σ_{b ∈ B} V(A, b)
  realityScopeBefore : RealityScope  -- (Perceivable ∪ Changeable) scope before action
  realityScopeAfter  : RealityScope  -- (Perceivable ∪ Changeable) scope after action
  deriving Repr

instance : Coe GoalEvaluation Thing where
  coe eval := eval.toThing


def GoalEvaluation.mkSimple (id : String) (pop : List Being) (val : Int) (r0 r1 : RealityScope) : GoalEvaluation :=
  { toThing := Thing.mkSimple id s!"goal_eval_{id}" "axiology" 0,
    population := pop, aggregateValue := val, realityScopeBefore := r0, realityScopeAfter := r1 }

/-- 
  Predicate: An action or civilizational step satisfies Goal G iff:
  1. It generates positive aggregate sentient Value: aggregateValue > 0
  2. It strictly enhances Reality (↑ℝ): reality_enhancement_delta > 0
-/
def satisfies_goal_G (eval : GoalEvaluation) : Prop :=
  eval.aggregateValue > 0 ∧ enhances_reality eval.realityScopeBefore eval.realityScopeAfter

/-- 
  Joint Goal Objective:
  Returns aggregate Value if Reality is enhanced or preserved (↑ℝ), 
  and strictly zero/negative if Reality is contracted.
-/
def goal_G (eval : GoalEvaluation) : Int :=
  if enhances_reality eval.realityScopeBefore eval.realityScopeAfter then
    eval.aggregateValue
  else
    0

/-- 
  MASTER THEOREM: Anti-Inward-Collapse Theorem (Reality Enhancement Invariant).
  Corresponds to: Bf_Pseudocode.txt L74: "Goal«G»(t) := argmax_{A(t)} [Σ_{b ∈ B(t)} V(A, b(t))] ∧ ↑ℝ;".
  A civilization that turns inward, shrinking its perceptual scope or collapsing its causal capability
  in the Universe (reality_enhancement_delta ≤ 0), is mathematically disqualified from satisfying Goal G,
  regardless of how large its internal hedonic satisfaction sum (aggregateValue) might be!
  Simulated solipsism and civilizational contraction are strictly prohibited.
-/
theorem inward_shrinkage_violates_goal (eval : GoalEvaluation) 
    (h_shrink : reality_enhancement_delta eval.realityScopeBefore eval.realityScopeAfter ≤ 0) :
    ¬ satisfies_goal_G eval := by
  intro h_sat
  unfold satisfies_goal_G enhances_reality at h_sat
  have h_enh := h_sat.2
  omega

/-- 
  THEOREM: Outward Capability Expansion Invariant.
  When an action produces both positive sentient value and outward expansion of the 
  perceivable and changeable boundary of Reality, it successfully satisfies Goal G.
-/
theorem outward_expansion_satisfies_goal (eval : GoalEvaluation)
    (h_val : eval.aggregateValue > 0)
    (h_expand : reality_enhancement_delta eval.realityScopeBefore eval.realityScopeAfter > 0) :
    satisfies_goal_G eval := by
  unfold satisfies_goal_G enhances_reality
  exact ⟨h_val, h_expand⟩

/-- 
  Saturated Hedonic Sensation Ceiling:
  Raw sensory pleasure cannot expand beyond physical/neurological capacity (H_max).
-/
def saturate_pleasure (raw maxH : Int) : Int :=
  if raw > maxH then maxH else raw

/-- 
  Good (Gd): Any action or transition that increases systemic Value V.
  Corresponds to: Bf_Pseudocode.txt L79: "Good«Gd»(t) := ↑V(t);"
-/
def is_good (delta_v : Int) : Bool :=
  delta_v > 0

/-- Grounded on Action: An action is Good if its execution increases systemic Value. -/
def is_action_good (_a : Action) (delta_v : Int) : Bool :=
  delta_v > 0

/-- 
  Bad (Bd): Any action or outcome that produces net Harm.
  Corresponds to: Bf_Pseudocode.txt L80: "Bad«Bd»(t) := (A, O) → Ha(t);"
-/
def is_bad (delta_v : Int) (harm_caused : Int) : Bool :=
  delta_v < 0 ∨ harm_caused > 0

/-- Grounded on Action: An action is Bad if its outcome causes harm or degrades value. -/
def is_action_bad (_a : Action) (delta_v : Int) (harm_caused : Int) : Bool :=
  delta_v < 0 ∨ harm_caused > 0

abbrev V := value_on_being
abbrev G := goal_G
abbrev Gd := is_good
abbrev Bd := is_bad

end Benefuture.Axiology


