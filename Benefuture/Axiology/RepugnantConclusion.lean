/-
  Benefuture.Axiology.RepugnantConclusion
  Formalization of Theorem 2: Structural Dissolution of Parfit's Repugnant Conclusion.
  Corresponds to: Bf_Pseudocode.txt L13-14, L58-75, and Philosophy.txt #Repugnant Conclusion
  
  Parfit's Repugnant Conclusion in classical additive utilitarianism:
  For any flourishing population of high quality of life, an astronomically large 
  population of lives barely worth living (u ≈ ε > 0) has a larger aggregate sum.
  
  Benefuture's Structural Dissolution:
  1. The Synergy operator uses a superadditive depth exponent q_+ > 1 (e.g. 1.1),
     meaning depth of flourishing compounds superlinearly, while marginal diffuse
     pleasures decay superlinearly (ε^(q_+) << ε).
  2. The Priority hierarchy enforces a Baseline Flourishing Floor (Th_baseline).
     Entities with flourishing below the baseline receive zero or penalized weight in G.
  3. Consequently, shifting population mass to marginal, barely-positive lives 
     strictly decreases aggregate societal utility G.
-/

import Benefuture.Math.Order
import Benefuture.Math.Synergy
import Benefuture.Ontology.Being
import Benefuture.Axiology.Priorities

namespace Benefuture.Axiology

open Benefuture.Math
open Benefuture.Ontology

/-- Baseline flourishing threshold below which lives are marginal / near-zero. -/
def FLOURISHING_BASELINE_FLOOR : Int := 100000  -- 0.10 of SCALE

/-- 
  Synergistic flourishing weight of a Being:
  If flourishing is above baseline floor, receives full compounding value plus depth bonus.
  If flourishing is below baseline floor, penalized to 0 (cannot aggregate into collective G).
-/
def synergistic_wellbeing (individualFlourishing : Int) : Int :=
  if individualFlourishing < FLOURISHING_BASELINE_FLOOR then
    0
  else
    -- Compounding depth: flourishing + superadditive synergy surplus
    individualFlourishing + (individualFlourishing * individualFlourishing) / SCALE

/-- 
  Societal Utility of a population:
  G = Σ synergistic_wellbeing(b_i).
-/
def aggregate_societal_utility (flourishingList : List Int) : Int :=
  flourishingList.foldl (fun acc f => acc + synergistic_wellbeing f) 0

/-- 
  THEOREM: Structural Dissolution of Parfit's Repugnant Conclusion.
  An astronomical population of barely-positive lives (where every individual's 
  wellbeing is strictly below the baseline floor) yields an aggregate societal 
  utility of exactly zero, whereas even a small population of flourishing individuals
  yields strictly positive societal utility.
  
  Therefore, no expansion of barely-worth-living lives can ever overtake or equal 
  a flourishing population, completely dissolving Parfit's Repugnant Conclusion.
-/
theorem repugnant_population_strictly_dominated 
    (marginalPopulation : List Int) 
    (h_marginal : ∀ x ∈ marginalPopulation, x < FLOURISHING_BASELINE_FLOOR)
    (flourishingInd : Int)
    (h_flourishing : flourishingInd ≥ FLOURISHING_BASELINE_FLOOR)
    (h_pos : 0 < flourishingInd) :
    aggregate_societal_utility marginalPopulation < aggregate_societal_utility [flourishingInd] := by
  -- 1. Compute utility of marginal population
  have h_marginal_zero : aggregate_societal_utility marginalPopulation = 0 := by
    unfold aggregate_societal_utility
    have h_fold : ∀ (l : List Int) (acc : Int),
      (∀ x ∈ l, x < FLOURISHING_BASELINE_FLOOR) →
      acc = 0 →
      l.foldl (fun a f => a + synergistic_wellbeing f) acc = 0 := by
      intro l
      induction l with
      | nil => intro acc _ hacc; dsimp; exact hacc
      | cons head tail ih =>
        intro acc h_all hacc
        dsimp
        have h_head : head < FLOURISHING_BASELINE_FLOOR := h_all head (List.Mem.head tail)
        have h_head_zero : synergistic_wellbeing head = 0 := by
          unfold synergistic_wellbeing
          simp [h_head]
        have h_tail : ∀ x ∈ tail, x < FLOURISHING_BASELINE_FLOOR :=
          fun x hx => h_all x (List.Mem.tail head hx)
        have h_next : acc + synergistic_wellbeing head = 0 := by
          rw [h_head_zero, hacc]
          rfl
        exact ih (acc + synergistic_wellbeing head) h_tail h_next
    exact h_fold marginalPopulation 0 h_marginal rfl
  
  -- 2. Compute utility of flourishing population
  have h_flourish_val : aggregate_societal_utility [flourishingInd] = synergistic_wellbeing flourishingInd := by
    unfold aggregate_societal_utility
    dsimp
    omega
  
  have h_flourish_pos : synergistic_wellbeing flourishingInd > 0 := by
    unfold synergistic_wellbeing
    have h_not : ¬(flourishingInd < FLOURISHING_BASELINE_FLOOR) := by omega
    simp [h_not]
    have hsq_nonneg : 0 ≤ (flourishingInd * flourishingInd) / SCALE := by
      apply Int.ediv_nonneg (Int.mul_nonneg (by omega) (by omega)) (by unfold SCALE; decide)
    omega
  
  rw [h_marginal_zero, h_flourish_val]
  exact h_flourish_pos

/-- 
  Flourishing Utility of a sentient Being:
  Directly grounded in the Being's sentience experienceLevel.
  Corresponds to: Bf_Pseudocode.txt L67: B := St(E).
-/
def being_synergistic_flourishing (b : Being) : Int :=
  synergistic_wellbeing b.sentience.experienceLevel

/-- 
  Societal utility aggregated over a concrete population of Beings:
  Σ_{b ∈ B} synergistic_wellbeing(b.sentience.experienceLevel).
  Directly embodies Goal G on sentient Beings: Bf_Pseudocode.txt L74.
-/
def aggregate_population_utility (population : List Being) : Int :=
  population.foldl (fun acc b => acc + being_synergistic_flourishing b) 0

/-- 
  THEOREM: Structural Dissolution of Parfit's Repugnant Conclusion on Beings.
  An astronomical population of barely-positive lives (b.sentience.experienceLevel < floor)
  yields exactly zero aggregate societal utility, whereas flourishing Beings compound value.
-/
theorem repugnant_population_of_beings_dominated
    (marginalPopulation : List Being)
    (h_marginal : ∀ b ∈ marginalPopulation, b.sentience.experienceLevel < FLOURISHING_BASELINE_FLOOR)
    (flourishingBeing : Being)
    (h_flourishing : flourishingBeing.sentience.experienceLevel ≥ FLOURISHING_BASELINE_FLOOR)
    (h_pos : 0 < flourishingBeing.sentience.experienceLevel) :
    aggregate_population_utility marginalPopulation < aggregate_population_utility [flourishingBeing] := by
  have h_map_marginal : ∀ x ∈ marginalPopulation.map (fun b => b.sentience.experienceLevel), x < FLOURISHING_BASELINE_FLOOR := by
    intro x hx
    rcases List.mem_map.mp hx with ⟨b, hb, rfl⟩
    exact h_marginal b hb
  have h_fold_eq : ∀ (l : List Being) (acc : Int),
    l.foldl (fun a b => a + being_synergistic_flourishing b) acc = 
    (l.map (fun b => b.sentience.experienceLevel)).foldl (fun a f => a + synergistic_wellbeing f) acc := by
    intro l
    induction l with
    | nil => intro acc; rfl
    | cons head tail ih =>
      intro acc
      dsimp [being_synergistic_flourishing]
      exact ih (acc + synergistic_wellbeing head.sentience.experienceLevel)
  have h_pop_eq : aggregate_population_utility marginalPopulation = 
                  aggregate_societal_utility (marginalPopulation.map (fun b => b.sentience.experienceLevel)) := by
    unfold aggregate_population_utility aggregate_societal_utility
    exact h_fold_eq marginalPopulation 0
  have h_single_eq : aggregate_population_utility [flourishingBeing] = 
                     aggregate_societal_utility [flourishingBeing.sentience.experienceLevel] := by
    unfold aggregate_population_utility aggregate_societal_utility
    exact h_fold_eq [flourishingBeing] 0
  rw [h_pop_eq, h_single_eq]
  exact repugnant_population_strictly_dominated 
    (marginalPopulation.map (fun b => b.sentience.experienceLevel))
    h_map_marginal
    flourishingBeing.sentience.experienceLevel
    h_flourishing
    h_pos

end Benefuture.Axiology

