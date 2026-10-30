/-
  Benefuture.Subgoals.Diversity
  Formalization of Diversity (Di), Novelty (N), Culture (Cu), and the Anti-Monoculture Axiom.
  Corresponds to: Bf_Pseudocode.txt L35-36, L124, L158, and Diversity.txt / Culture.txt
  "Di_N_Balance := (MarginalΔV(Spread(Gd_i)) < Th) ⇒ Need(↑N ∧ ↓MonoCu_i), ∃i=Bf;"
-/

import Benefuture.Math.Order
import Benefuture.Ontology.Thing

namespace Benefuture.Subgoals

open Benefuture.Math
open Benefuture.Ontology

/-- 
  Culture (Cu ∈ T):
  Memetic pattern of beliefs, values, and behaviors in Reality.
  Corresponds to: Bf_Pseudocode.txt L124:
  "Cu := Memetic(Beliefs, Values, Behaviors), Respect, (Inter, Multi)cultural, Lw(adopt(Gd ⊆ Cu)), J(↓Bd ⊆ Cu);"
-/
structure Culture extends Thing where
  name            : String
  beliefs         : List String
  values          : List String
  beneficialNorms : List String  -- Gd ⊆ Cu adopted into Law
  harmfulNorms    : List String  -- Bd ⊆ Cu mitigated via Justice
  deriving Repr

instance : Coe Culture Thing where
  coe cu := cu.toThing


def Culture.mkSimple (id name : String) : Culture :=
  { toThing := Thing.mkSimple id s!"culture_{name}" "memetic_substrate" 0,
    name := name, beliefs := [], values := [], beneficialNorms := [], harmfulNorms := [] }

/-- 
  System Diversity Profile:
  orderRatio : Fraction of predictable, standardized protocols [0, SCALE]
  chaosRatio : Fraction of exploratory, novel mutations [0, SCALE]
-/
structure DiversityBalance extends Thing where
  orderRatio : Int
  chaosRatio : Int
  h_sum      : orderRatio + chaosRatio = SCALE
  h_order_pos: 0 < orderRatio
  h_chaos_pos: 0 < chaosRatio
  deriving Repr

instance : Coe DiversityBalance Thing where
  coe db := db.toThing


def DiversityBalance.mkSimple (id : String) (order chaos : Int) (h_s : order + chaos = SCALE) (ho : 0 < order) (hc : 0 < chaos) : DiversityBalance :=
  { toThing := Thing.mkSimple id s!"diversity_{id}" "diversity_substrate" 0,
    orderRatio := order, chaosRatio := chaos, h_sum := h_s, h_order_pos := ho, h_chaos_pos := hc }


/-- 
  Novelty calculation: Inverse of frequency in Reality (scaled).
  Single observations carry maximal novelty; frequency accumulation strictly diminishes novelty.
-/
def compute_novelty (frequency : Nat) : Int :=
  (1000000 / (frequency + 1) : Nat)

/-- 
  THEOREM: Zero Frequency Yields Maximal Novelty.
  A newly observed phenomenon with zero prior historical instances carries maximal novelty SCALE.
-/
theorem zero_frequency_yields_maximal_novelty :
    compute_novelty 0 = SCALE := by
  rfl

/-- 
  THEOREM: Positive Frequency Strictly Diminishes Novelty.
  Once a pattern has been observed one or more times in Reality (freq ≥ 1),
  its novelty drops to at most half of the maximum scale.
-/
theorem positive_frequency_strictly_diminishes_novelty (freq : Nat) (h_pos : freq > 0) :
    compute_novelty freq ≤ SCALE / 2 := by
  unfold compute_novelty
  have h_denom : 2 ≤ freq + 1 := by omega
  have _h_nat : 1000000 / (freq + 1) ≤ 1000000 / 2 := Nat.div_le_div_left h_denom (by decide)
  have : (SCALE / 2 : Int) = (500000 : Int) := by rfl
  omega

/-- 
  Anti-Monoculture Trigger (Di_N_Balance Axiom, L158):
  If the marginal value spread of the dominant paradigm falls below threshold Th, alternatives
  are to be tried (even if the dominant paradigm is Benefuture itself). The trigger only flags the
  stagnation: by ruling 8.30.3 alternatives are subsidised (novelty bonuses) until some local body
  chooses them, never forced on anyone.
-/
def needs_diversity_injection (marginal_delta_v : Int) (threshold : Int) : Bool :=
  marginal_delta_v < threshold

/-- 
  THEOREM: Anti-Monoculture Diversity Axiom Theorem.
  When marginal improvement stagnates (marginal_delta_v < threshold), the trigger flags it
  (`needs_diversity_injection` is true). That is all this proves; the response is subsidised
  alternatives, never forced ones (ruling 8.30.3), and lock-in prevention is not proved here.
-/
theorem monoculture_stagnation_triggers_diversity 
    (marginal_v : Int) (threshold : Int) (h_stag : marginal_v < threshold) :
    needs_diversity_injection marginal_v threshold = true := by
  unfold needs_diversity_injection
  exact decide_eq_true h_stag

/-- 
  THEOREM: Flourishing Growth Avoids Unforced Perturbation.
  When marginal value exceeds the threshold (marginal_v ≥ threshold),
  the system avoids forced diversity disruption.
-/
theorem flourishing_growth_avoids_diversity_injection 
    (marginal_v : Int) (threshold : Int) (h_healthy : marginal_v ≥ threshold) :
    needs_diversity_injection marginal_v threshold = false := by
  unfold needs_diversity_injection
  have h_not : ¬(marginal_v < threshold) := by omega
  exact decide_eq_false h_not

abbrev Di := DiversityBalance
abbrev N := compute_novelty
abbrev Cu := Culture

end Benefuture.Subgoals

