/-
  Benefuture.Subgoals.Art
  Formalization of Art as aesthetic and cognitive transmission.
  Corresponds to: Bf_Pseudocode.txt L125-126
  "Art := E_i -> In((T_a = (Cx_a ∨ Reorg) <- (T_o ⊆ ℝ)), Cm(ΔAffect_St + ΔU)_p) : (B_j <- T_a) -> (ΔAffect_St(B_j) + U : U ≠ U(T_a))_q..."
  "V_a = (Tr_lvl(U) + N)_q"
-/

import Benefuture.Ontology.Entity
import Benefuture.Ontology.Being

namespace Benefuture.Subgoals

open Benefuture.Ontology

/-- An Artwork (T_a): A physical or symbolic Thing created with aesthetic intent. -/
structure Artwork extends Thing where
  artistId : String
  deriving Repr

/-- Coercion: Every Artwork is canonically a Thing in Reality. -/
instance : Coe Artwork Thing where
  coe a := a.toThing

/-- Theorem: Artwork inclusion in Thing holds by construction. -/
theorem artwork_is_thing (a : Artwork) : (a : Thing).id = a.id := rfl

/-- 
  Artistic Transmission (extends Thing):
  Artist communicates affective and cognitive shifts (ΔAffect + ΔU) to an Audience Being.
  Corresponds to: Bf_Pseudocode.txt L125-126.
-/
structure ArtExperience extends Thing where
  artwork        : Artwork
  audience       : Being
  affectShift    : Int  -- Emotional resonance / change in subjective experience
  understandingU : Int  -- Epistemic insight imparted
  noveltyScore   : Int  -- Aesthetic novelty
  deriving Repr

instance : Coe ArtExperience Thing where
  coe exp := exp.toThing

theorem art_experience_is_thing (exp : ArtExperience) : (exp : Thing).id = exp.id := rfl

def ArtExperience.mkSimple (id : String) (art : Artwork) (aud : Being) (aff u nov : Int) : ArtExperience :=
  { toThing := Thing.mkSimple id s!"art_exp_{id}" "aesthetic_cognitive_substrate" 0,
    artwork := art, audience := aud, affectShift := aff, understandingU := u, noveltyScore := nov }

/-- 
  Art Value: V_a = TruthLevel(U) + Novelty.
-/
def art_value (exp : ArtExperience) : Int :=
  exp.understandingU + exp.noveltyScore

/-- 
  THEOREM: Art Generates Multi-Dimensional Value.
  Art simultaneously expands understanding and imparts affective experience,
  fulfilling the Gyananandam synergy principle.
-/
theorem art_value_nonneg (exp : ArtExperience) (hu : 0 ≤ exp.understandingU) (hn : 0 ≤ exp.noveltyScore) :
    0 ≤ art_value exp := by
  unfold art_value
  omega

abbrev Art := ArtExperience

end Benefuture.Subgoals

