/-
  Benefuture.Ontology.Person
  Formalization of Person (Pe): Beings with cognitive continuity, contract capacity, and legal liability.
  Corresponds to: Bf_Pseudocode.txt L71, L119
  "Pe := B + Fuzzy(Sig(St, Sp, SelfAwareness, Empathy, Memory, Continuity«Cnt», Planning, Cm, Contract«Ct»)),gradedLvls;"
  "Liability«Lia» := (S > Pe) > Ad > (B, E) > T;"
-/

import Benefuture.Ontology.Being

namespace Benefuture.Ontology

/-- 
  Cognitive & Social Personhood Profile.
  Personhood is graded across 6 key dimensions.
-/
structure PersonhoodCapacities where
  selfAwareness : Int
  empathy       : Int
  memoryTrace   : Int
  continuity    : Int
  planning      : Int
  contractCap   : Int
  deriving Repr, DecidableEq

/-- 
  Person (Pe): Extends Being with graded personhood capacities 
  meeting the significance threshold for contract capability and memory continuity.
-/
structure Person extends Being where
  capacities      : PersonhoodCapacities
  h_contract_cap  : capacities.contractCap > 0
  h_continuity    : capacities.continuity > 0
  deriving Repr

/-- Coercion: Every Person is a Being. -/
instance : Coe Person Being where
  coe p := p.toBeing

/-- Coercion: Every Person is an Entity. -/
instance : Coe Person Entity where
  coe p := p.toBeing.toEntity

/-- Coercion: Every Person is a Thing. -/
instance : Coe Person Thing where
  coe p := p.toBeing.toEntity.toThing

/-- Theorem: Ontological inclusion Pe ⊆ B holds by construction. -/
theorem person_is_being (p : Person) : (p : Being).id = p.id := rfl

/-- Theorem: Transitive inclusion Pe ⊆ E holds by construction. -/
theorem person_is_entity (p : Person) : (p : Entity).id = p.id := rfl

/-- Theorem: Transitive inclusion Pe ⊆ T holds by construction. -/
theorem person_is_thing (p : Person) : (p : Thing).id = p.id := rfl

abbrev Pe := Person

end Benefuture.Ontology

