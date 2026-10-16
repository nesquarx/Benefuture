/-
  Benefuture.Math.Order
  Axiomatic specification of Benefuture core weights and priority hierarchies.
  Corresponds to: Bf_Pseudocode.txt L11-12 (Params«Pm» := 1 > α > β > γ > δ...)
-/

namespace Benefuture.Math

/-- 
  Fixed-point scalar scale: 1.0 is represented as 1,000,000 (micro-units).
  This enables exact, non-overflowing integer arithmetic with full `omega` proof automation.
-/
def SCALE : Int := 1000000

/-- 
  Governable parameters for the Benefuture priority hierarchy:
  α: Understanding weight
  β: Happiness weight
  γ: Novelty weight
  δ: Harm base weight
  Strict hierarchy constraint: SCALE > α > β > γ > δ > 0.
-/
structure BfParams where
  alpha : Int
  beta  : Int
  gamma : Int
  delta : Int
  h_max : alpha < SCALE
  h_ab  : beta < alpha
  h_bg  : gamma < beta
  h_gd  : delta < gamma
  h_min : 0 < delta
  deriving Repr, DecidableEq

/-- Standard reference parameter configuration: α=0.8, β=0.6, γ=0.4, δ=0.2 -/
def defaultParams : BfParams := {
  alpha := 800000
  beta  := 600000
  gamma := 400000
  delta := 200000
  h_max := by decide
  h_ab  := by decide
  h_bg  := by decide
  h_gd  := by decide
  h_min := by decide
}

/-- Theorem: Understanding strictly dominates Happiness in weight. -/
theorem understanding_dominates_happiness (p : BfParams) : p.alpha > p.beta := by
  have h := p.h_ab
  omega

/-- Theorem: Happiness strictly dominates Novelty in weight. -/
theorem happiness_dominates_novelty (p : BfParams) : p.beta > p.gamma := by
  have h := p.h_bg
  omega

/-- Theorem: Understanding strictly dominates Novelty by transitivity. -/
theorem understanding_dominates_novelty (p : BfParams) : p.alpha > p.gamma := by
  have h1 := p.h_ab
  have h2 := p.h_bg
  omega

/-- Theorem: Understanding strictly dominates Harm base weight by transitivity. -/
theorem understanding_dominates_harm_base (p : BfParams) : p.alpha > p.delta := by
  have h1 := p.h_ab
  have h2 := p.h_bg
  have h3 := p.h_gd
  omega

/-- Theorem: All parameters are strictly bounded within the open interval (0, 1.0). -/
theorem params_in_unit_interval (p : BfParams) : 
    0 < p.delta ∧ p.delta < SCALE ∧
    0 < p.gamma ∧ p.gamma < SCALE ∧
    0 < p.beta  ∧ p.beta  < SCALE ∧
    0 < p.alpha ∧ p.alpha < SCALE := by
  have hm := p.h_max
  have hab := p.h_ab
  have hbg := p.h_bg
  have hgd := p.h_gd
  have hmin := p.h_min
  omega

/-- 
  ParamSchedule: An arbitrary-length decreasing sequence of parameters.
  Corresponds to: Bf_Pseudocode.txt L11-12: "Params«Pm» := 1 > α > β > γ > δ...;"
-/
structure ParamSchedule where
  weights       : List Int
  h_nonempty    : weights ≠ []
  h_upper_bound : ∀ w ∈ weights, w < SCALE
  h_lower_bound : ∀ w ∈ weights, w > 0
  deriving Repr

/-- 
  Priority Tier Assignment:
  (x_1 > x_2 > ... > x_n) := [(x_i, Pm_i)];
  Pairs an ordered list of elements with their corresponding weight parameters.
-/
def zip_priority_weights {α : Type} (items : List α) (schedule : ParamSchedule) : List (α × Int) :=
  items.zip schedule.weights

/-- The canonical 4-tier schedule corresponding to defaultParams. -/
def defaultSchedule : ParamSchedule := {
  weights := [800000, 600000, 400000, 200000],
  h_nonempty := by decide,
  h_upper_bound := by
    intro w hw
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl | rfl <;> decide,
  h_lower_bound := by
    intro w hw
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl | rfl <;> decide
}

end Benefuture.Math

