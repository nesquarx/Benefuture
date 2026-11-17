/-
  Benefuture.Epistemology.InfoHandling
  Formalization of InfoHazards (IHz), Critical Thinking (CrT), Education (Ed),
  and Epistemic Information Handling (IH).
  Corresponds to: Bf_Pseudocode.txt L128-134, and Education.txt / Technology Network.txt
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.Linarith
import Benefuture.Epistemology.Truth
import Benefuture.Ontology.Person

namespace Benefuture.Epistemology

open Benefuture.Math
open Benefuture.Ontology

/-- 
  InfoHazard (IHz, extends Statement):
  A statement that, in the absence of requisite background context 
  and epistemic inoculation, produces harm or epistemological corruption:
  (U_i ∧ ¬U_recipient → Harm) ∨ (U_i ∧ U_recipient → ↓Tr_lvl)
  Corresponds to: Bf_Pseudocode.txt L128 ("InfoHazards«IHz»").
-/
structure InfoHazard extends Statement where
  prerequisiteEd   : Nat  -- Level of education required to process safely without harm
  potentialHarm    : Int  -- Magnitude of unmitigated harm
  h_harm_pos       : 0 < potentialHarm
  deriving Repr

instance : Coe InfoHazard Statement where
  coe ihz := ihz.toStatement

instance : Coe InfoHazard Thing where
  coe ihz := ihz.toStatement.toThing

theorem infohazard_is_statement (ihz : InfoHazard) : (ihz : Statement).id = ihz.id := rfl

def InfoHazard.mkSimple (id content : String) (dom : Domain) (preReq : Nat) (harm : Int)
    (h_harm : 0 < harm := by decide) : InfoHazard :=
  { toStatement := Statement.mkSimple id content dom,
    prerequisiteEd := preReq, potentialHarm := harm, h_harm_pos := h_harm }

/-- 
  Education Profile of a Person (extends Thing):
  Measures metacognition, critical thinking (CrT), emotional quotient (EQ), 
  and infohazard inoculation level.
  Corresponds to: Bf_Pseudocode.txt L130-132.
-/
structure EducationProfile extends Thing where
  person           : Person
  educationLevel   : Nat  -- Universal access tier
  criticalThinking : Int  -- Ability to evaluate truth levels and source validity
  inoculationLevel : Nat  -- Highest infohazard clearance safely mastered
  deriving Repr

instance : Coe EducationProfile Thing where
  coe ed := ed.toThing


def EducationProfile.mkSimple (id : String) (p : Person) (lvl : Nat) (crt : Int) (inoc : Nat) : EducationProfile :=
  { toThing := Thing.mkSimple id s!"edu_{id}" "education" 0,
    person := p, educationLevel := lvl, criticalThinking := crt, inoculationLevel := inoc }

/-- 
  Access Policy: Gated access without censorship.
  ManageAccess(IHz, preReq(Ed), Provide(Ed), EnsurePath(Ed → Access) | Freedom(Tr), !Censor).
  Instead of deleting or banning infohazardous material, the system gates it behind 
  educational completion, providing an open, unblocked learning path for anyone to qualify.
-/
def can_safely_access (ihz : InfoHazard) (ed : EducationProfile) : Bool :=
  ed.inoculationLevel ≥ ihz.prerequisiteEd

/-- Residual harm incurred upon encountering an infohazard. -/
def access_harm_risk (ihz : InfoHazard) (ed : EducationProfile) : Int :=
  if can_safely_access ihz ed then 0 else ihz.potentialHarm

/-- 
  THEOREM: Epistemic Inoculation Theorem.
  Completing requisite education for an InfoHazard completely eliminates its harm risk (drops to 0),
  demonstrating that educational inoculation achieves safety without paternalistic censorship.
-/
theorem education_inoculates_infohazard (ihz : InfoHazard) (ed : EducationProfile) 
    (h_cleared : ed.inoculationLevel ≥ ihz.prerequisiteEd) :
    access_harm_risk ihz ed = 0 := by
  unfold access_harm_risk can_safely_access
  simp [h_cleared]

/-! ## Real-Valued InfoHazard Gate Exposure Risk (`L127`, `B21`, M8) -/

/-- Residual exposure risk from encountering gated material requiring `reqEd` at `clearance` (`L127`):
    `0` once cleared (`clearance ≥ reqEd`), otherwise `max 0 potentialHarm`. -/
noncomputable def ihz_access_risk_real (clearance reqEd potentialHarm : ℝ) : ℝ :=
  if clearance ≥ reqEd then 0 else max 0 potentialHarm

theorem ihz_access_risk_real_nonneg (clearance reqEd potentialHarm : ℝ) :
    0 ≤ ihz_access_risk_real clearance reqEd potentialHarm := by
  unfold ihz_access_risk_real
  split_ifs
  · exact le_refl 0
  · exact le_max_left 0 _

theorem ihz_access_risk_real_zero_when_cleared (clearance reqEd potentialHarm : ℝ)
    (h : clearance ≥ reqEd) :
    ihz_access_risk_real clearance reqEd potentialHarm = 0 := by
  unfold ihz_access_risk_real
  simp [h]

theorem ihz_access_risk_real_pos_when_uncleared (clearance reqEd potentialHarm : ℝ)
    (h_unclear : clearance < reqEd) (h_harm : 0 < potentialHarm) :
    0 < ihz_access_risk_real clearance reqEd potentialHarm := by
  unfold ihz_access_risk_real
  have hnot : ¬ (clearance ≥ reqEd) := by linarith
  simp only [hnot, ↓reduceIte]
  exact lt_of_lt_of_le h_harm (le_max_right 0 _)

end Benefuture.Epistemology
