/-
  Benefuture.Systems.Enforcement
  Formalization of the Benefuture Enforcement System:
  1. Primary: Enforcement by Design (Automated systemic debits & smart contracts)
  2. Secondary: Persuasive Non-Violent Influence
  3. Tertiary: Forcible Restraint (Strictly audited, bounded by Justice)
  Corresponds to: Enforcement.txt, Law.txt, Justice.txt, and Bf_Pseudocode.txt L159-162
-/

import Benefuture.Math.Order
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Entity
import Benefuture.Ontology.Law
import Benefuture.Subgoals.Justice

namespace Benefuture.Systems

open Benefuture.Math
open Benefuture.Ontology
open Benefuture.Subgoals

/-- 
  The Three Graduated Tiers of Enforcement:
  - DesignAutomated  : Built into transactional substrates and embedded laws (no physical force)
  - Persuasive       : Restorative dialogue, guidance, and reputation signaling
  - ForcibleRestraint: Physical or cryptographic interdiction (strictly audited)
-/
inductive EnforcementTier where
  | DesignAutomated   : EnforcementTier
  | Persuasive        : EnforcementTier
  | ForcibleRestraint : EnforcementTier
  deriving Repr, DecidableEq

/-- 
  Enforcement Action (extends Thing):
  A systematic intervention to align actions with Benefuture goals and restorative justice.
-/
structure EnforcementAction extends Thing where
  targetEntityId     : String
  tier               : EnforcementTier
  reparationAssessed : RestorativePackage
  isAudited          : Bool  -- Anti-corruption oversight
  deriving Repr

/-- Coercion: Every EnforcementAction is canonically a Thing in Reality. -/
instance : Coe EnforcementAction Thing where
  coe ea := ea.toThing

/-- Theorem: EnforcementAction inclusion in Thing holds by construction. -/
theorem enforcement_action_is_thing (ea : EnforcementAction) : (ea : Thing).id = ea.id := rfl

/-- 
  Rule: Forcible restraint is impermissible without explicit anti-corruption audit.
-/
def is_permissible_enforcement (ea : EnforcementAction) : Bool :=
  match ea.tier with
  | EnforcementTier.DesignAutomated   => true
  | EnforcementTier.Persuasive        => true
  | EnforcementTier.ForcibleRestraint => ea.isAudited

/-- Theorem: Unaudited forcible restraint is strictly impermissible. -/
theorem unaudited_forcible_restraint_rejected (ea : EnforcementAction) 
    (h_tier : ea.tier = EnforcementTier.ForcibleRestraint) (h_audit : ea.isAudited = false) :
    is_permissible_enforcement ea = false := by
  unfold is_permissible_enforcement
  rw [h_tier]
  exact h_audit

/-- 
  Theorem: Automated Design Enforcement Minimization.
  When a reparation package is fully satisfied via automated transaction debits,
  no residual societal harm remains and physical coercion is unnecessary.
-/
theorem automated_design_eliminates_residual_harm (ea : EnforcementAction)
    (h_repaired : ea.reparationAssessed.reparationToVictim = ea.reparationAssessed.crime.harmAmount) :
    residual_societal_harm ea.reparationAssessed = 0 := by
  exact full_reparation_eliminates_residual_harm ea.reparationAssessed h_repaired

abbrev En := EnforcementAction

end Benefuture.Systems

