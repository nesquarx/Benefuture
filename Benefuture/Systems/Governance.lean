/-
  Benefuture.Systems.Governance
  Formalization of Bounded Liquid Democracy (LqdBfDm) and External Harm Response (EHR).
  Corresponds to: Bf_Pseudocode.txt L114, L117, and Government.txt
  "LqdBfDm(D_n, Dn_k) := DelegateDnVote(S_i → S_j) if (Re_k(S_j) > Re_k(S_i) ∧ CumulativeVoteWeight(S_j) < Th_k ∧ Impacted_Wt_i_n < Th_b)..."
  "ExternalHaResponse«EHR»(Ha_i, Aggressor(E_!Bf)_j) := TitForTat(viaReparableHa)_ij + (α * Re_+ve_j) * P(Forgive)..."
-/

import Benefuture.Governance.Democracy
import Benefuture.Ontology.Entity

namespace Benefuture.Systems

open Benefuture.Math
open Benefuture.Ontology
open Benefuture.Governance
open Benefuture.Measurement

/-- 
  Liquid Delegation Vote (extends Thing):
  Corresponds to: Bf_Pseudocode.txt L114:
  "LqdBfDm(D_n, Dn_k) := DelegateDnVote(S_i → S_j) if (Re_k(S_j) > Re_k(S_i) ∧ CumulativeVoteWeight(S_j) < Th_k ∧ Impacted_Wt_i_n < Th_b)"
  Delegation between Sophonts on a specific Decision in a Domain.
-/
structure LiquidDelegationVote extends Thing where
  delegatorExpertise  : Int
  delegateExpertise   : Int
  delegateTotalWeight : Int
  delegatorImpact     : Int
  weightCapThreshold  : Int  -- Anti-whale ceiling Th_k
  highImpactThreshold : Int  -- Impact threshold beyond which voting is mandatory
  deriving Repr

instance : Coe LiquidDelegationVote Thing where
  coe v := v.toThing


def LiquidDelegationVote.mkSimple 
    (id : String) (delExp dgtExp dgtWt delImp capTh impTh : Int) : LiquidDelegationVote :=
  { toThing := Thing.mkSimple id s!"delegation_{id}" "governance_substrate" 0,
    delegatorExpertise := delExp, delegateExpertise := dgtExp,
    delegateTotalWeight := dgtWt, delegatorImpact := delImp,
    weightCapThreshold := capTh, highImpactThreshold := impTh }

abbrev DelegationAttempt := LiquidDelegationVote

/-- 
  Predicate: Delegation S_i → S_j is legally valid iff:
  1. Delegate has strictly higher expertise in domain k.
  2. Delegate has not exceeded the cumulative voting weight cap (anti-oligarchy).
  3. Delegator is not intensely impacted (high-impact decisions demand direct participation!).
-/
def is_delegation_permitted (att : LiquidDelegationVote) : Bool :=
  (att.delegateExpertise > att.delegatorExpertise) &&
  (att.delegateTotalWeight < att.weightCapThreshold) &&
  (att.delegatorImpact < att.highImpactThreshold)

/-- 
  External Harm Response (EHR ∈ T):
  Game-theoretic response to aggression from non-Benefuture external entities (extends Thing):
  Tit-for-tat using strictly reparable harm + forgiveness scaled by positive reputation.
  Corresponds to: Bf_Pseudocode.txt L117.
-/
structure ExternalHarmInteraction extends Thing where
  incomingHarm         : Int
  aggressorPosRep      : Int  -- Past cooperative reputation of external actor
  h_harm_pos           : 0 < incomingHarm
  isResponseRepairable : Bool := true
  deriving Repr

instance : Coe ExternalHarmInteraction Thing where
  coe ehr := ehr.toThing


def ExternalHarmInteraction.mkSimple (id : String) (harm rep : Int) (h_pos : 0 < harm) : ExternalHarmInteraction :=
  { toThing := Thing.mkSimple id s!"ehr_{id}" "external_defense" 0,
    incomingHarm := harm, aggressorPosRep := rep, h_harm_pos := h_pos, isResponseRepairable := true }

/-- 
  Proportional response with forgiveness buffer:
  Retaliatory defensive harm is strictly capped to reparable levels 
  and attenuated by the aggressor's positive track record.
-/
def ehr_defensive_response (inter : ExternalHarmInteraction) (alpha_scaled : Int) : Int :=
  let forgiveness := (alpha_scaled * inter.aggressorPosRep) / SCALE
  if forgiveness ≥ inter.incomingHarm then 0
  else inter.incomingHarm - forgiveness

/-- 
  THEOREM: High-Impact Mandatory Participation Theorem.
  If a voter is intensely affected by a decision (impact ≥ threshold),
  delegating their vote is strictly forbidden, guaranteeing authentic stakeholder voice.
-/
theorem high_impact_prevents_delegation (att : LiquidDelegationVote) 
    (h_intense : att.delegatorImpact ≥ att.highImpactThreshold) :
    is_delegation_permitted att = false := by
  unfold is_delegation_permitted
  have h_not : ¬ (att.delegatorImpact < att.highImpactThreshold) := by omega
  have h_dec : decide (att.delegatorImpact < att.highImpactThreshold) = false := decide_eq_false h_not
  simp [h_dec]

/-- 
  THEOREM: Anti-Whale Concentration Ceiling Theorem.
  A delegate whose cumulative weight has hit the cap cannot accept further delegations.
-/
theorem whale_cap_prevents_delegation (att : LiquidDelegationVote)
    (h_cap : att.delegateTotalWeight ≥ att.weightCapThreshold) :
    is_delegation_permitted att = false := by
  unfold is_delegation_permitted
  have h_not : ¬ (att.delegateTotalWeight < att.weightCapThreshold) := by omega
  have h_dec : decide (att.delegateTotalWeight < att.weightCapThreshold) = false := decide_eq_false h_not
  simp [h_dec]

/-- 
  Administration (Ad ⊆ E ⊆ T):
  Corresponds to: Bf_Pseudocode.txt L106 & Administration.txt.
  "Administration«Ad» := E → CRUD(Lw, Infra);"
  An Entity responsible for managing and maintaining legal processes and physical/digital infrastructure.
-/
structure Administration extends Entity where
  managedLaws  : List String
  managedInfra : List String
  deriving Repr, DecidableEq

instance : Coe Administration Entity where
  coe ad := ad.toEntity

instance : Coe Administration Thing where
  coe ad := ad.toEntity.toThing


/-- 
  Government (Gv ∈ T):
  Corresponds to: Bf_Pseudocode.txt L107 & Government.txt.
  "Gov«Gv» := Ad(D_So);"
  The execution arm of societal decisions through administrative processes.
-/
structure Government extends Thing where
  administration         : Administration
  activeSocietalDecisions: List String
  deriving Repr

instance : Coe Government Thing where
  coe gv := gv.toThing


/-- 
  Sophont Oversight (SO ∈ T):
  Corresponds to: Bf_Pseudocode.txt L141 & L142.
  "SophontOversight«SO»(Sys_i) := SafetyNet, Intervention(Intv), Correction, viaS_Sig_Re(Dn_i + SysSec + Ethics);"
  A safety net mechanism where sophonts with significant reputation in system security,
  ethics, and relevant domains monitor autonomous systems and trigger interventions when needed.
-/
structure SophontOversight extends Thing where
  targetSystemId         : String
  isInterventionRequired : Bool
  overseerReputationSum  : Int
  qualificationThreshold : Int
  deriving Repr

instance : Coe SophontOversight Thing where
  coe so := so.toThing


/-- Predicate: Oversight intervention is legally authorized if overseer reputation meets the threshold. -/
def is_oversight_authorized (so : SophontOversight) : Bool :=
  so.isInterventionRequired ∧ so.overseerReputationSum ≥ so.qualificationThreshold

/-- THEOREM: Sub-threshold oversight cannot execute unverified interventions. -/
theorem sub_threshold_oversight_blocked (so : SophontOversight) (h : so.overseerReputationSum < so.qualificationThreshold) :
    is_oversight_authorized so = false := by
  unfold is_oversight_authorized
  have : ¬(so.overseerReputationSum ≥ so.qualificationThreshold) := by omega
  simp [this]

abbrev Ad := Administration
abbrev Gv := Government
abbrev SO := SophontOversight
abbrev LqdBfDm := DelegationAttempt
abbrev EHR := ExternalHarmInteraction

end Benefuture.Systems
