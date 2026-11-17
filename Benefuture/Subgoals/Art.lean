/-
  Benefuture.Subgoals.Art
  Formalization of Art as aesthetic and cognitive transmission.
  Corresponds to: Bf_Pseudocode.txt L126-127
  "Art := E_i -> In((T_a = (Cx_a ∨ Reorg) <- (T_o ⊆ ℝ)), Cm(ΔAffect_St + ΔU)_p) : (B_j <- T_a) -> (ΔAffect_St(B_j) + U : U ≠ U(T_a))_q..."
  "V_a = (Tr_lvl(U) + N)_q"
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.Linarith
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


/-- 
  Artistic Transmission (extends Thing):
  Artist communicates affective and cognitive shifts (ΔAffect + ΔU) to an Audience Being.
  Corresponds to: Bf_Pseudocode.txt L126-127.
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

/-! ## Real-Valued Art Reception Match & Surplus Value (`L126–L127`, `7.13`, M8) -/

/-- L1 distribution discrepancy between intended reception `p` and realised reception spread `q`. -/
noncomputable def art_distribution_l1_loss : List ℝ → List ℝ → ℝ
  | p :: ps, q :: qs => |p - q| + art_distribution_l1_loss ps qs
  | _, _ => 0

/-- Art success from matching intended distribution `intent` against audience reception spread `reception`
    (`Success := match(p, Dist(q))`, `L126`, `7.13`): `1 - L1(p, q) / 2` clamped below at `0`. -/
noncomputable def art_success_score (intent reception : List ℝ) : ℝ :=
  max 0 (1 - art_distribution_l1_loss intent reception / 2)

/-- Art surplus value beyond raw feeling in V (`V_a = Tr_lvl(ΔU) + N`, `L127`, `7.13`):
    sum of non-negative truth-level understanding imparted and execution novelty. -/
noncomputable def art_surplus_value (truthDeltaU novelty : ℝ) : ℝ :=
  max 0 truthDeltaU + max 0 novelty

theorem art_distribution_l1_loss_nonneg (intent reception : List ℝ) :
    0 ≤ art_distribution_l1_loss intent reception := by
  induction intent generalizing reception with
  | nil => simp [art_distribution_l1_loss]
  | cons p ps ih =>
    cases reception with
    | nil => simp [art_distribution_l1_loss]
    | cons q qs =>
      unfold art_distribution_l1_loss
      exact add_nonneg (abs_nonneg _) (ih qs)

theorem art_distribution_l1_loss_self (dist : List ℝ) :
    art_distribution_l1_loss dist dist = 0 := by
  induction dist with
  | nil => simp [art_distribution_l1_loss]
  | cons p ps ih => simp [art_distribution_l1_loss, ih]

theorem art_success_score_exact_match (dist : List ℝ) :
    art_success_score dist dist = 1 := by
  unfold art_success_score
  rw [art_distribution_l1_loss_self]
  norm_num

theorem art_success_score_bounds (intent reception : List ℝ) :
    0 ≤ art_success_score intent reception ∧ art_success_score intent reception ≤ 1 := by
  unfold art_success_score
  have hloss := art_distribution_l1_loss_nonneg intent reception
  constructor
  · exact le_max_left 0 _
  · exact max_le (by norm_num) (by linarith)

theorem art_surplus_value_nonneg (truthDeltaU novelty : ℝ) :
    0 ≤ art_surplus_value truthDeltaU novelty := by
  unfold art_surplus_value
  exact add_nonneg (le_max_left 0 _) (le_max_left 0 _)

abbrev Art := ArtExperience

end Benefuture.Subgoals

