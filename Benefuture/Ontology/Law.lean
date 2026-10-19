/-
  Benefuture.Ontology.Law
  Formalization of Law (L ∈ T), Contracts (K ∈ T), and Sophont Legal Roles.
  Corresponds to: Bf_Pseudocode.txt L3-7, L149-162, Law.txt, Contract.txt, and Enforcement.txt

  "S ⊆ Pe ⊆ B ⊆ E ⊆ T;"
  "So, M, C, A, O, D, I... ∈ T;"
  "A law is an agreed upon process of interaction for entities, specifically persons."
  "Embedded Law: EL(C, MM) where compliance is automated via transaction debits."
-/

import Benefuture.Math.Order
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Entity
import Benefuture.Ontology.Being
import Benefuture.Ontology.Person
import Benefuture.Ontology.Sophont
import Benefuture.Ontology.Domain

namespace Benefuture.Ontology

open Benefuture.Math

/-- 
  Sophont Legal Classification according to Benefuture Law.txt:
  - Right: Mandatorily entitled benefit; failure to provide is a crime.
  - Privilege: Optional benefit; revocation is permissible unless causing significant harm.
  - Duty: Mandatory interaction to perform; failure to perform is a crime.
  - Responsibility: Recommended optional action; performing generates an accolade.
-/
inductive LegalRoleType where
  | Right          : LegalRoleType
  | Privilege      : LegalRoleType
  | Duty           : LegalRoleType
  | Responsibility : LegalRoleType
  deriving Repr, DecidableEq

/-- 
  Law (L ∈ T, extends Thing):
  An interaction rule governing entities and persons to maximize universal Understanding and Happiness.
  Corresponds to: Bf_Pseudocode.txt L3-7 ("Law«L» ∈ T").
-/
structure Law extends Thing where
  roleType     : LegalRoleType
  isMandatory  : Bool
  targetDomain : Domain
  isEmbedded   : Bool  -- True if embedded directly into transaction scripts / smart contracts (EL)
  deriving Repr, DecidableEq

/-- Coercion: Every Law is canonically a Thing in Reality. -/
instance : Coe Law Thing where
  coe l := l.toThing


/-- Helper constructor for standard laws. -/
def Law.mkSimple (id : String) (role : LegalRoleType) (mandatory : Bool) (dom : Domain) (embedded : Bool := false) : Law :=
  { toThing := Thing.mkSimple id s!"law_{id}" dom.name 0,
    roleType := role, isMandatory := mandatory, targetDomain := dom, isEmbedded := embedded }

/-- 
  Contract (K ∈ T, extends Thing):
  A documented commitment of multiple Persons/Entities committing to perform a set of interactions (Inputs → Outputs).
  Corresponds to: Bf_Pseudocode.txt L71, L119 ("Contract«Ct»").
-/
structure Contract extends Thing where
  signatories  : List Person := []
  participants : List String := []
  clauses      : List String
  enforcerId   : String
  netHarmBound : Int    -- Upper bound on permissible negative externalities
  h_two_party  : signatories.length ≥ 2 ∨ participants.length ≥ 2
  deriving Repr

/-- Coercion: Every Contract is canonically a Thing in Reality. -/
instance : Coe Contract Thing where
  coe k := k.toThing


def Contract.mkSimple (id : String) (signers : List Person) (clauses : List String) (enforcer : String) (bound : Int)
    (h_two : signers.length ≥ 2 := by decide) : Contract :=
  { toThing := Thing.mkSimple id s!"contract_{id}" "legal" 0,
    signatories := signers, participants := signers.map (·.id),
    clauses := clauses, enforcerId := enforcer, netHarmBound := bound,
    h_two_party := Or.inl h_two }

/-- 
  Contract Validity Predicate:
  A contract that produces net negative systemic value (causing harm exceeding bound) is null and void.
-/
def is_valid_contract (k : Contract) (projectedHarm : Int) : Bool :=
  projectedHarm ≤ k.netHarmBound

/-- Theorem: A contract that produces harm exceeding its bounds is invalid and unenforceable. -/
theorem invalid_contract_null_and_void (k : Contract) (harm : Int) (h : harm > k.netHarmBound) :
    is_valid_contract k harm = false := by
  unfold is_valid_contract
  exact decide_eq_false (by omega)

/-- 
  Embedded Law (EL) Automated Compliance:
  If a law is embedded into a transaction (e.g. automated restorative restitution),
  compliance occurs by default during execution.
-/
def is_automatically_enforced (l : Law) : Bool :=
  l.isEmbedded ∧ l.isMandatory

/-- 
  Liability Hierarchy:
  Liability«Lia» := (S > Pe) > Ad > (B, E) > T;
  Corresponds to: Bf_Pseudocode.txt L119.
  Moral and legal liability increases strictly with awareness, agency, and goal alignment.
-/
inductive MoralAgentTier where
  | Sophont        : MoralAgentTier
  | Person         : MoralAgentTier
  | Administration : MoralAgentTier
  | BeingOrEntity  : MoralAgentTier
  | InanimateThing : MoralAgentTier
  deriving Repr, DecidableEq

def liability_rank : MoralAgentTier → Nat
  | .Sophont        => 4
  | .Person         => 3
  | .Administration => 2
  | .BeingOrEntity  => 1
  | .InanimateThing => 0

/-- THEOREM: Monotonic Liability Ordering. -/
theorem liability_hierarchy_order :
    liability_rank .Sophont > liability_rank .Person ∧
    liability_rank .Person > liability_rank .Administration ∧
    liability_rank .Administration > liability_rank .BeingOrEntity ∧
    liability_rank .BeingOrEntity > liability_rank .InanimateThing := by
  decide

/-- 
  Ontological Liability Ranking grounded directly on entities:
  - Sophont (S): Maximum liability (Rank 4) due to conscious goal alignment with G
  - Person (Pe): High liability (Rank 3) due to cognitive continuity and contract capacity
  - Being (B) or Entity (E): Base patient standing (Rank 1)
  - Inanimate Thing (T): Zero liability (Rank 0)
-/
def sophont_liability (_s : Sophont) : Nat := 4
def person_liability (_p : Person) : Nat := 3
def being_liability (_b : Being) : Nat := 1
def entity_liability (_e : Entity) : Nat := 1
def thing_liability (_t : Thing) : Nat := 0

theorem ontological_liability_ordering (s : Sophont) (p : Person) (b : Being) (t : Thing) :
    sophont_liability s > person_liability p ∧
    person_liability p > being_liability b ∧
    being_liability b > thing_liability t := by
  dsimp [sophont_liability, person_liability, being_liability, thing_liability]
  decide

/-- 
  Accolade (Aco ∈ T):
  Accolade«Aco» := Acknowledge(Gd > Duty).
  Corresponds to: Bf_Pseudocode.txt L121.
  Public recognition awarded when an entity generates positive value beyond mandatory duty.
-/
structure Accolade extends Thing where
  recipientId   : String
  goodGenerated : Int
  dutyBaseline  : Int
  h_surplus     : goodGenerated > dutyBaseline
  deriving Repr

/-- Coercion: Every Accolade is canonically a Thing in Reality. -/
instance : Coe Accolade Thing where
  coe a := a.toThing


abbrev Lw := Law
abbrev Ct := Contract
abbrev Lia := MoralAgentTier
abbrev Aco := Accolade

end Benefuture.Ontology


