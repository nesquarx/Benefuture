/-
  Benefuture.Subgoals.Justice
  Formalization of Crime (Cr ∈ T), Restorative Justice (J), and Reparations.
  Corresponds to: Bf_Pseudocode.txt L115-117, L119, and Justice.txt / Crime.txt
  "Crime«Cr» := Ha | Informed(Volition ∨ Inaction(Lw_mandate ∨ Contract));"
  "J := Repair(Ha) ∧ Prevent(Cr), Restorative;"
-/

import Benefuture.Ontology.Thing
import Benefuture.Ontology.Person

namespace Benefuture.Subgoals

open Benefuture.Ontology

/-- 
  Crime (Cr ∈ T): Harm caused through informed volition or culpable inaction:
  Cr := Ha | Informed(Volition ∨ Inaction(Lw_mandate ∨ Contract)).
-/
structure Crime extends Thing where
  perpetrator  : Person
  victim       : Person
  harmAmount   : Int
  isInformed   : Bool
  hasVolition  : Bool
  /-- Informed inaction against a committed action: a duty from a contract, including a law once
      communicated (author ruling, BACKPROPAGATION 8.17). -/
  breachedDuty : Bool := false
  h_harm_pos   : 0 < harmAmount
  h_culpable   : isInformed = true ∧ (hasVolition = true ∨ breachedDuty = true)
  deriving Repr

/-- Coercion: Every Crime is canonically a Thing in Reality. -/
instance : Coe Crime Thing where
  coe cr := cr.toThing


/-- 
  Restorative Package (extends Thing):
  reparationToVictim : Restitution restoring victim's baseline
  rehabilitationCost : Educational and behavioral rehabilitation of perpetrator
-/
structure RestorativePackage extends Thing where
  crime              : Crime
  reparationToVictim : Int
  rehabilitationCost : Int
  deriving Repr

/-- Coercion: Every RestorativePackage is canonically a Thing in Reality. -/
instance : Coe RestorativePackage Thing where
  coe rp := rp.toThing


/-- Helper constructor for Crimes grounded in reality. -/
def Crime.mkSimple (id : String) (perp victim : Person) (harm : Int) (h_pos : 0 < harm) : Crime :=
  { toThing := Thing.mkSimple id s!"crime_{id}" "reality_substrate" 0,
    perpetrator := perp, victim := victim, harmAmount := harm,
    isInformed := true, hasVolition := true, h_harm_pos := h_pos, h_culpable := ⟨rfl, Or.inl rfl⟩ }

/-- Helper constructor for RestorativePackages. -/
def RestorativePackage.mkSimple (id : String) (cr : Crime) (reparation rehab : Int) : RestorativePackage :=
  { toThing := Thing.mkSimple id s!"restorative_{id}" "justice_substrate" 0,
    crime := cr, reparationToVictim := reparation, rehabilitationCost := rehab }

/-- 
  Net societal residual harm after restorative justice intervention:
  ResidualHarm = OriginalHarm - ReparationPaid.
-/
def residual_societal_harm (pkg : RestorativePackage) : Int :=
  pkg.crime.harmAmount - pkg.reparationToVictim

/-- 
  THEOREM: Restorative Minimization Theorem.
  When full restitution is paid to the victim (reparation = harmAmount),
  the uncompensated residual harm drops to zero, restoring the civilizational baseline.
-/
theorem full_reparation_eliminates_residual_harm 
    (pkg : RestorativePackage) (h_full : pkg.reparationToVictim = pkg.crime.harmAmount) :
    residual_societal_harm pkg = 0 := by
  unfold residual_societal_harm
  rw [h_full]
  omega

/-- 
  Accident (extends Thing):
  When harm is caused without informed volition or culpable inaction:
  Harm occurs, but isInformed = false ∨ (hasVolition = false ∧ breachedDuty = false).
  Repair is owed either way (author ruling, BACKPROPAGATION 8.17).
  Corresponds to: Crime.txt L9.
-/
structure Accident extends Thing where
  operator    : Person
  victim      : Person
  harmAmount  : Int
  isInformed  : Bool
  hasVolition : Bool
  breachedDuty : Bool := false
  h_harm_pos  : 0 < harmAmount
  h_accidental : isInformed = false ∨ (hasVolition = false ∧ breachedDuty = false)
  deriving Repr

instance : Coe Accident Thing where
  coe acc := acc.toThing


/-- 
  Accident Resolution Package:
  Victim receives full restorative restitution, but the operator incurs 
  ZERO punitive friction or criminal sanctions.
-/
structure AccidentResolution extends Thing where
  accident           : Accident
  reparationToVictim : Int
  punitivePenalty    : Int
  deriving Repr

instance : Coe AccidentResolution Thing where
  coe ar := ar.toThing


/-- 
  Standard pure restitution resolution for an accident:
  Reparation equals harm, punitive penalty is strictly zero.
-/
def mk_accident_pure_restitution (acc : Accident) : AccidentResolution :=
  { toThing := Thing.mkSimple s!"res_{acc.id}" s!"accident_res_{acc.id}" "restorative_justice" 0,
    accident := acc, reparationToVictim := acc.harmAmount, punitivePenalty := 0 }

/-- 
  THEOREM: Pure Restitution for Accidents Invariant (Crime.txt L9 & Justice.txt).
  An accident resolved through standard restorative justice completely eliminates 
  residual victim harm while assessing zero punitive friction on the operator.
-/
theorem accident_requires_pure_restitution_without_punitive_friction (acc : Accident) :
    let res := mk_accident_pure_restitution acc
    acc.harmAmount - res.reparationToVictim = 0 ∧ res.punitivePenalty = 0 := by
  dsimp [mk_accident_pure_restitution]
  omega

/-- 
  Ontological Classification of a Harmful Action (L115: Cr := Ha | Informed(Volition ∨
  Inaction(Lw_mandate ∨ Contract))):
  A harmful event constitutes a Crime (Cr) iff it was committed with verified epistemic awareness
  (isInformed = true) and either intentional volition (hasVolition = true) or inaction against a
  law's mandate or a contract (breachedDuty = true). Otherwise, it is an Accident.
  Corresponds to: Bf_Pseudocode.txt L115 & Crime.txt L9.
-/
def is_crime_classification (isInformed : Bool) (hasVolition : Bool) (breachedDuty : Bool := false) : Bool :=
  isInformed && (hasVolition || breachedDuty)

/-- 
  THEOREM: Crime and Accident Invariants are Mutually Exclusive.
  No harmful event is both classified a Crime (informed, and volition or breach of a law's
  mandate or contract, L115) and meets the Accident condition (uninformed, or neither volition
  nor breached duty).
-/
theorem crime_and_accident_mutually_exclusive (isInformed hasVolition breachedDuty : Bool) :
    ¬ (is_crime_classification isInformed hasVolition breachedDuty = true ∧
        (isInformed = false ∨ (hasVolition = false ∧ breachedDuty = false))) := by
  cases isInformed <;> cases hasVolition <;> cases breachedDuty <;> simp [is_crime_classification]

/-- 
  THEOREM: Culpability Classification Invariant (Informed Volition).
  An actor who acts with verified information (isInformed = true) and deliberate volition (hasVolition = true)
  is rigorously classified as committing a Crime.
-/
theorem verified_informed_volition_is_crime :
    is_crime_classification true true = true := by
  rfl

/-- 
  THEOREM: Uninformed Action is an Accident.
  An actor operating without epistemic notice (isInformed = false) 
  cannot be classified as a Crime, regardless of volition.
-/
theorem uninformed_action_is_accident (vol : Bool) :
    is_crime_classification false vol = false := by
  cases vol <;> rfl

/-- 
  THEOREM: Involuntary Action without breached duty is an Accident.
  An actor operating without volition (hasVolition = false) and with no breached duty (the default)
  cannot be classified as a Crime, regardless of information state.
-/
theorem involuntary_action_is_accident (inf : Bool) :
    is_crime_classification inf false = false := by
  cases inf <;> rfl

/-- 
  Epistemic Notice and Volition State:
  Distinguishes genuine ignorance from culpable willful negligence.
-/
inductive EpistemicNotice where
  | WarningVerifiedLogged : EpistemicNotice  -- BTS recorded verified warning received
  | NoWarningAvailable    : EpistemicNotice  -- Information was unavailable / unknown
  deriving Repr, DecidableEq

/-- Backward-compatible bridge to EpistemicNotice. -/
def classify_harmful_action 
    (notice : EpistemicNotice) (proceeded : Bool) : Bool :=
  match notice with
  | .WarningVerifiedLogged => is_crime_classification true proceeded
  | .NoWarningAvailable    => is_crime_classification false proceeded

theorem warning_ignored_constitutes_crime :
    classify_harmful_action .WarningVerifiedLogged true = true := by
  rfl

theorem absence_of_notice_is_accident (proceeded : Bool) :
    classify_harmful_action .NoWarningAvailable proceeded = false := by
  cases proceeded <;> rfl

/--
  THEOREM: Informed inaction against a committed action is a crime (L115: Informed(Volition ∨
  Inaction)). A driver bound by traffic law who sees the pedestrian and does not brake.
-/
theorem informed_inaction_under_duty_is_crime :
    is_crime_classification true false true = true := by
  rfl

/--
  THEOREM: Inaction without a committed action is not a crime, informed or not. A bystander with
  no duty has no causal contribution to the harm (assessed against inaction, its counterfactual is
  itself), so no crime arises from it.
-/
theorem inaction_without_duty_is_not_crime (isInformed : Bool) :
    is_crime_classification isInformed false false = false := by
  cases isInformed <;> rfl

/--
  THEOREM: An uninformed breach is an accident: repair is owed, no crime.
-/
theorem uninformed_breach_is_accident (hasVolition breachedDuty : Bool) :
    is_crime_classification false hasVolition breachedDuty = false := by
  rfl

abbrev Cr := Crime
abbrev J := RestorativePackage

end Benefuture.Subgoals

