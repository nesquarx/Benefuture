/-
  Benefuture.Ontology.Entity
  Formalization of Entity (E), Interactions (I), Outcomes (O), Actions (A), Decisions (D), and Society (So).
  Corresponds to: Bf_Pseudocode.txt L3-7, L19-21, L65
  "Things«T», Entities«E», Beings«B», Persons«Pe», Sophonts«S», Society«So», Markers«M»,"
  "Currencies«C», Actions«A», Outcomes«O», Decisions«D», Interactions«I»;"
  "S ⊆ Pe ⊆ B ⊆ E ⊆ T;"
  "So, M, C, A, O, D, I... ∈ T;"
  "I := Process(T ← Inputs → Outputs«Ou» ↔ ℝ ∨ T);"
  "O := Significant«Sig» perceived Δℝ ← I;"
  "A := Ou → O;"
  "E(t) := T ↔ I(t) + Sp > 0;"
-/

import Benefuture.Ontology.Thing
import Benefuture.Math.Order

namespace Benefuture.Ontology

open Benefuture.Math

/-- 
  Interaction (I ∈ T):
  Process of exchanging inputs and outputs with Reality or another Thing.
  Grounding holds in Reality via Thing primitive.
-/
structure Interaction extends Thing where
  sender    : String
  receiver  : String
  content   : String
  timestamp : Nat
  deriving Repr, DecidableEq

/-- Coercion: Every Interaction is canonically a Thing in Reality. -/
instance : Coe Interaction Thing where
  coe i := i.toThing

/-- 
  Outcome (O ∈ T):
  Significant perceived change in Reality (Δℝ) resulting from an Interaction.
-/
structure Outcome extends Thing where
  sourceInteractionId : String
  perceivedDelta      : Int   -- Scaled change in reality state (micro-units)
  isSignificant       : Bool  -- Exceeds significance threshold
  timestamp           : Nat
  deriving Repr, DecidableEq

/-- Coercion: Every Outcome is canonically a Thing in Reality. -/
instance : Coe Outcome Thing where
  coe o := o.toThing

/-- 
  Entity (E ⊆ T):
  A Thing with causal interaction agency, internal state trace, and inbox/outbox.
-/
structure Entity extends Thing where
  stateTrace   : List (Nat × String)
  inbox        : List Interaction
  outbox       : List Interaction
  deriving Repr, DecidableEq

/-- Helper constructor for an Entity. -/
def Entity.mkSimple (id name : String) (dom : String := "General") (t : Nat := 0) : Entity :=
  { toThing := Thing.mkSimple id name dom t, stateTrace := [], inbox := [], outbox := [] }

/-- Coercion: Every Entity is canonically a Thing. -/
instance : Coe Entity Thing where
  coe e := e.toThing

/-- 
  Action (A ∈ T):
  An Output emitted by an Entity intended to affect an Outcome in Reality.
-/
structure Action extends Thing where
  actor            : Entity
  payload          : Interaction
  intendedOutcome  : Option Outcome := none
  timestamp        : Nat
  h_actor          : payload.sender = actor.id
  deriving Repr

/-- Coercion: Every Action is canonically a Thing in Reality. -/
instance : Coe Action Thing where
  coe a := a.toThing

/-- 
  Decision (D ∈ T):
  A chosen Action selected from candidate options by an Entity evaluating expected value.
-/
structure Decision extends Thing where
  decider       : Entity
  candidates    : List Action
  chosenAction  : Action
  expectedValue : Int
  h_chosen_in   : chosenAction ∈ candidates
  deriving Repr

/-- Coercion: Every Decision is canonically a Thing in Reality. -/
instance : Coe Decision Thing where
  coe d := d.toThing

/-- 
  Society / Civilization (So ⊆ E ⊆ T):
  A collective system of interacting persons collaborating to maximize common goals.
-/
structure Society extends Entity where
  members            : List String
  h_members_nonempty : members ≠ []
  deriving Repr, DecidableEq

/-- Coercion: Every Society is canonically an Entity. -/
instance : Coe Society Entity where
  coe so := so.toEntity

/-- Coercion: Every Society is canonically a Thing. -/
instance : Coe Society Thing where
  coe so := so.toEntity.toThing

/-- Helper constructors using primitive Thing foundation. -/
def Interaction.mkSimple (id sender receiver content : String) (t : Nat := 0) : Interaction :=
  { toThing := Thing.mkSimple id s!"interaction_{id}" s!"channel_{sender}_{receiver}" t,
    sender := sender, receiver := receiver, content := content, timestamp := t }

def Outcome.mkSimple (id interactionId : String) (delta : Int) (sig : Bool := true) (t : Nat := 0) : Outcome :=
  { toThing := Thing.mkSimple id s!"outcome_{id}" "reality_state" t,
    sourceInteractionId := interactionId, perceivedDelta := delta, isSignificant := sig, timestamp := t }

def Action.mkSimple (id : String) (actor : Entity) (payload : Interaction) 
    (intended : Option Outcome := none) (t : Nat := 0) (h : payload.sender = actor.id) : Action :=
  { toThing := Thing.mkSimple id s!"action_{id}" s!"action_space_{actor.id}" t,
    actor := actor, payload := payload, intendedOutcome := intended, timestamp := t, h_actor := h }

/-- 
  Input (Inp ∈ T):
  A Thing received by an Entity from Reality or another Entity.
  Corresponds to: Bf_Pseudocode.txt L19 & Input.txt.
-/
structure Input extends Thing where
  sourceId       : String
  targetEntityId : String
  deriving Repr, DecidableEq

instance : Coe Input Thing where
  coe inp := inp.toThing

/-- 
  Output (Ou ∈ T):
  A Thing emitted by an Entity directed towards Reality or another Entity.
  Corresponds to: Bf_Pseudocode.txt L19, L21 & Output.txt.
  "A := Ou → O"
-/
structure Output extends Thing where
  emitterEntityId : String
  payloadContent  : String
  deriving Repr, DecidableEq

instance : Coe Output Thing where
  coe ou := ou.toThing

/-- 
  Civilization (Cv) is an alias for Society (So):
  "So := Civilization«Cv» := {(S, Pe, B, E)[]} + Sys(I) → CollectiveGoals«CG»(↑G) | Safeguards(AntiFragility«Af»);"
  Corresponds to: Bf_Pseudocode.txt L105 & Civilization.txt.
-/
abbrev Civilization := Society

/- --- Fundamental Primitive Inclusion Theorems --- -/


/-- 
  Intent (In ∈ T):
  Intent«In» : E_Precommit(Ou, Ct(Self)).
  Corresponds to: Bf_Pseudocode.txt L76.
  An entity's internal precommitment to execute an output directed towards an intended outcome.
-/
structure Intent extends Thing where
  entityId        : String
  intendedActionId: String
  precommitment   : String
  deriving Repr

instance : Coe Intent Thing where
  coe in_ := in_.toThing

/-- 
  Power (Po ∈ T):
  Power«Po» := Capacity(→Δ).
  Corresponds to: Bf_Pseudocode.txt L110.
  An entity's capacity to cause significant delta in Reality.
-/
structure Power extends Thing where
  holderId        : String
  transformationCapacity : Int
  deriving Repr

instance : Coe Power Thing where
  coe po := po.toThing

/-- 
  Influence (Inf ∈ T):
  Influence«Inf» := Control(Ou(Others)).
  Corresponds to: Bf_Pseudocode.txt L111.
  The capacity to modulate or direct the outputs of other entities.
-/
structure Influence extends Thing where
  influencerId : String
  directedEntities : List String
  controlFactor : Int  -- Scaled in [0, SCALE]
  deriving Repr

instance : Coe Influence Thing where
  coe inf := inf.toThing

/-- 
  Impact (Imp ∈ T):
  Imp(A, t) := ΔV : ∫MM_Me(Δℝ | A) dt.
  Corresponds to: Bf_Pseudocode.txt L112.
  The integral of value-change generated by an action over time as measured by Metric Models.
-/
structure Impact extends Thing where
  actionId         : String
  measuredValueDelta : Int
  deriving Repr

instance : Coe Impact Thing where
  coe imp := imp.toThing


/-- 
  Good vs Bad Influence Classification (Article Nuance: Influence.txt L7):
  When influence improves an entity's understanding of reality and long-term 
  understanding and happiness (deltaU > 0 ∧ deltaH ≥ 0), it is a Good Influence.
  Otherwise, it is a Bad Influence.
-/
def is_good_influence (deltaU deltaH : Int) : Bool :=
  deltaU > 0 ∧ deltaH ≥ 0

/-- 
  Influence-Weighted Upstream Causal Liability (Influence.txt & Crime.txt L8):
  An influencer directing the outputs of subordinate entities with controlFactor ∈ [0, SCALE]
  incurs upstream causal liability proportional to their degree of control:
  LiabilityShare = (directHarm * controlFactor) / SCALE.
-/
def calculate_influencer_liability (directHarm : Int) (controlFactor : Int) : Int :=
  if directHarm ≤ 0 ∨ controlFactor ≤ 0 then 0
  else (directHarm * controlFactor) / SCALE

/-- 
  THEOREM: Influencer Liability Sharing Invariant.
  An entity with positive control factor over an agent causing significant harm
  such that the product of harm and control exceeds SCALE (1.0 in fixed-point)
  shares strictly positive causal liability.
  Autonomous subordinates cannot be used as liability shields for their controllers.
-/
theorem influencer_shares_positive_liability 
    (harm : Int) (control : Int) (h_harm : harm > 0) (h_ctrl : control > 0)
    (h_prod : harm * control ≥ SCALE) :
    calculate_influencer_liability harm control > 0 := by
  unfold calculate_influencer_liability
  have h_harm_pos : ¬(harm ≤ 0) := by omega
  have h_ctrl_pos : ¬(control ≤ 0) := by omega
  simp [h_harm_pos, h_ctrl_pos]
  unfold SCALE at h_prod ⊢
  omega

/-- 
  THEOREM: Full Control Full Liability Invariant.
  An entity exercising total control (controlFactor = SCALE) over an agent 
  bears 100% of the causal liability for the resulting direct harm.
-/
theorem full_control_shares_full_liability (harm : Int) (h_harm : harm > 0) :
    calculate_influencer_liability harm SCALE = harm := by
  unfold calculate_influencer_liability
  have h_harm_pos : ¬(harm ≤ 0) := by omega
  have h_scale_pos : ¬(SCALE ≤ 0) := by decide
  simp [h_harm_pos, h_scale_pos]
  exact Int.mul_ediv_cancel harm (by decide)

/-- 
  Fork Operation Record:
  Corresponds to: Life in benefuture.txt L575-592 & Bf_Pseudocode.txt L134.
  Fork(Id(E_i)) → (Distribute(SoPo_i: C, Re, ...) → New(Ids[i,j]), LiabilityOverflow ← CD, N = 0).
  - Parent entity branches a cognitive fork.
  - Social capital (reputation, currency) is partitioned proportionally, never duplicated.
  - Initial novelty is strictly ZERO: a copy must earn divergence.
-/
structure ForkOperation extends Thing where
  parentEntityId           : String
  forkEntityId             : String
  parentPreForkReputation  : Nat
  parentPostForkReputation : Nat
  forkInitialReputation    : Nat
  forkInitialNovelty       : Nat := 0
  h_reputation_split       : parentPostForkReputation + forkInitialReputation = parentPreForkReputation
  h_zero_novelty           : forkInitialNovelty = 0
  deriving Repr

instance : Coe ForkOperation Thing where
  coe op := op.toThing


/-- THEOREM: Zero Initial Novelty Invariant for Cognitive Forks. -/
theorem fork_initial_novelty_is_zero (op : ForkOperation) :
    op.forkInitialNovelty = 0 :=
  op.h_zero_novelty

/-- THEOREM: Conservation of Social Capital on Forking (No Duplication). -/
theorem fork_conserves_social_capital (op : ForkOperation) :
    op.parentPostForkReputation + op.forkInitialReputation = op.parentPreForkReputation :=
  op.h_reputation_split

/-- 
  Merge Operation Record:
  Corresponds to: Bf_Pseudocode.txt L123:
  "Merge(Ids[]) → (Σ(SoPo_i, N) → EstNew(Id));"
  Consolidates multiple constituent identities into a new consolidated entity,
  summing their social positions (currency, reputation) and novelty.
-/
structure MergeOperation extends Thing where
  constituentEntityIds : List String
  mergedEntityId       : String
  constituentReputations : List Nat
  mergedReputation     : Nat
  constituentNovelties : List Nat
  mergedNovelty        : Nat
  h_rep_sum            : mergedReputation = constituentReputations.foldl (· + ·) 0
  h_nov_sum            : mergedNovelty = constituentNovelties.foldl (· + ·) 0
  deriving Repr

instance : Coe MergeOperation Thing where
  coe mop := mop.toThing


/-- THEOREM: Conservation of Reputation under Identity Merging. -/
theorem merge_conserves_reputation (mop : MergeOperation) :
    mop.mergedReputation = mop.constituentReputations.foldl (· + ·) 0 :=
  mop.h_rep_sum

/-- THEOREM: Accumulation of Novelty under Identity Merging. -/
theorem merge_accumulates_novelty (mop : MergeOperation) :
    mop.mergedNovelty = mop.constituentNovelties.foldl (· + ·) 0 :=
  mop.h_nov_sum

/-- 
  External Harm Response Protocol:
  Corresponds to: Life in benefuture.txt L606-616 & Bf_Pseudocode.txt ExternalHarmResponse.
  Iterated tit-for-tat with forgiveness weighting for interactions with unaligned external entities:
  - strictly restricted to repairable harm (never irreparable).
  - defensive response magnitude proportional to incoming provocation.
-/
structure ExternalHarmResponse extends Thing where
  incomingHarmMagnitude : Int
  isIncomingIrreparable : Bool
  responseHarmMagnitude : Int
  isResponseRepairable  : Bool
  forgivenessFactor     : Int  -- Weighted by external entity's positive reputation
  deriving Repr

instance : Coe ExternalHarmResponse Thing where
  coe ehr := ehr.toThing


def ExternalHarmResponse.mkSimple (id : String) (incoming response forgiveness : Int) : ExternalHarmResponse :=
  { toThing := Thing.mkSimple id s!"ehr_{id}" "external_defense_substrate" 0,
    incomingHarmMagnitude := incoming, isIncomingIrreparable := false,
    responseHarmMagnitude := response, isResponseRepairable := true,
    forgivenessFactor := forgiveness }

/-- 
  Defensive Damage Profile:
  Deterrent magnitude is proportional to provocation exceeding forgiveness.
  Irreparable and irreversible harm are strictly zero by institutional design.
-/
structure DefensiveDamageProfile where
  deterrentMagnitude : Int
  irreparableDamage  : Int
  irreversibleDamage : Int
  deriving Repr, DecidableEq

/-- 
  Calculates calibrated defensive response:
  Response matches incoming harm proportionally, but is strictly constrained to repairable harm:
  irreparableDamage = 0 and irreversibleDamage = 0.
-/
def calculate_defensive_action (incomingHarm : Int) (forgiveness : Int) : DefensiveDamageProfile :=
  let netDefense := if incomingHarm > forgiveness then incomingHarm - forgiveness else 0
  { deterrentMagnitude := netDefense,
    irreparableDamage := 0,
    irreversibleDamage := 0 }

def calculate_external_defense (incomingHarm : Int) (forgiveness : Int) : (Int × Bool) :=
  let prof := calculate_defensive_action incomingHarm forgiveness
  (prof.deterrentMagnitude, prof.irreparableDamage ≤ 0 ∧ prof.irreversibleDamage ≤ 0)

/-- 
  THEOREM: Defensive Proportionality and Repairability Invariant.
  Any civilizational response to external harm is strictly guaranteed to have
  non-positive irreparable and irreversible damage, preventing catastrophic escalation.
-/
theorem external_defense_guarantees_repairability (incoming forgiveness : Int) :
    let prof := calculate_defensive_action incoming forgiveness
    prof.irreparableDamage ≤ 0 ∧ prof.irreversibleDamage ≤ 0 := by
  dsimp [calculate_defensive_action]
  omega

theorem external_response_always_repairable (incoming forgiveness : Int) :
    (calculate_external_defense incoming forgiveness).2 = true := by
  dsimp [calculate_external_defense, calculate_defensive_action]
  rfl

abbrev E := Entity
abbrev I := Interaction
abbrev O := Outcome
abbrev A := Action
abbrev D := Decision
abbrev So := Society
abbrev In := Intent
abbrev Po := Power
abbrev Inf := Influence
abbrev Imp := Impact
abbrev Ou := Output

end Benefuture.Ontology


