/-
  Benefuture.Epistemology.InfoHandling
  Formalization of InfoHazards (IHz), Critical Thinking (CrT), Education (Ed),
  and Epistemic Information Handling (IH).
  Corresponds to: Bf_Pseudocode.txt L127-134, and Education.txt / Technology Network.txt
-/

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
  Corresponds to: Bf_Pseudocode.txt L127 ("InfoHazards«IHz»").
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
  Corresponds to: Bf_Pseudocode.txt L128-132.
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


end Benefuture.Epistemology
