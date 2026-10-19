/-
  Benefuture.Axiology.RepugnantConclusion
  Analysis of Parfit's Repugnant Conclusion in Population Ethics.
  
  [OPEN] Status Note:
  Parfit's Repugnant Conclusion is an open theoretical problem for population ethics:
  "For any possible population of at least ten billion people, all with a very high
   quality of life, there must be some much larger imaginable population whose existence,
   if other things are equal, would be better, even though its members have lives that are
   barely worth living."
  
  Previous versions claimed a "structural dissolution" via an ad hoc baseline flourishing floor
  (`FLOURISHING_BASELINE_FLOOR`). However:
  1. An arbitrary floor threshold is not present in Bf_Pseudocode.txt.
  2. A floor does not dissolve the paradox; it merely moves the boundary. For any floor f > 0
     giving positive individual value, a sufficiently large population n of lives at floor f
     yields an aggregate value exceeding any fixed finite flourishing population (as proved below).
  
  Therefore, addressing the Repugnant Conclusion remains an open research and simulation question.
-/

import Benefuture.Math.Order
import Benefuture.Math.Synergy
import Benefuture.Ontology.Being
import Benefuture.Axiology.Priorities

namespace Benefuture.Axiology

open Benefuture.Math
open Benefuture.Ontology

/-- 
  [OPEN] Aggregate valuation of a population:
  Calculates aggregate societal value across an arbitrary list of individual flourishing scores.
-/
def aggregate_population_wellbeing (w : Int → Int) (lives : List Int) : Int :=
  lives.foldl (fun acc x => acc + w x) 0

theorem foldl_replicate_val (w : Int → Int) (f : Int) (n : Nat) (acc : Int) :
    (List.replicate n f).foldl (fun a x => a + w x) acc = acc + (n : Int) * w f := by
  induction n generalizing acc with
  | zero => simp [List.replicate]
  | succ n ih =>
    rw [List.replicate_succ, List.foldl_cons]
    rw [ih]
    have : acc + w f + (n : Int) * w f = acc + ((n + 1 : Nat) : Int) * w f := by
      push_cast
      have : ((n : Int) + 1) * w f = (n : Int) * w f + w f := by
        have := Int.add_mul (n : Int) 1 (w f)
        omega
      omega
    exact this

theorem aggregate_replicate_eq (w : Int → Int) (f : Int) (n : Nat) :
    aggregate_population_wellbeing w (List.replicate n f) = (n : Int) * w f := by
  unfold aggregate_population_wellbeing
  have := foldl_replicate_val w f n 0
  omega

/-- 
  [OPEN] Lemma: The Floor Moves Rather Than Resolves the Repugnant Conclusion.
  For ANY positive floor f yielding positive individual value (w f > 0) and ANY
  arbitrarily high target value V_target (e.g. from any fixed finite flourishing population),
  there exists a population size n of lives at wellbeing f whose aggregate value strictly
  dominates V_target:
    AggregateValue(n × [f]) > V_target.
  
  Hence an ad hoc floor does not dissolve Parfit's Repugnant Conclusion; it simply relocates
  the threshold of what counts as a marginal life.
-/
theorem floor_shifts_repugnant_conclusion (w : Int → Int) (f : Int) (hw : 0 < w f) (V_target : Int) :
    ∃ (n : Nat), aggregate_population_wellbeing w (List.replicate n f) > V_target := by
  by_cases hV : V_target < 0
  · refine ⟨0, ?_⟩
    rw [aggregate_replicate_eq]
    dsimp
    omega
  · have hV_ge : 0 ≤ V_target := by omega
    have h_div : 0 ≤ V_target / w f := Int.ediv_nonneg hV_ge (by omega)
    refine ⟨(V_target / w f + 1).toNat, ?_⟩
    rw [aggregate_replicate_eq]
    have h_nat : ((V_target / w f + 1).toNat : Int) = V_target / w f + 1 :=
      Int.toNat_of_nonneg (by omega)
    rw [h_nat]
    have h_mul : (V_target / w f + 1) * w f = (V_target / w f) * w f + w f := by
      have : (V_target / w f + 1) * w f = (V_target / w f) * w f + 1 * w f := Int.add_mul _ _ _
      omega
    have h_comm : (V_target / w f) * w f = w f * (V_target / w f) := Int.mul_comm _ _
    have h_rem := Int.emod_lt_of_pos V_target hw
    have h_mod := Int.mul_ediv_add_emod (a := V_target) (b := w f)
    omega

end Benefuture.Axiology
