/-
  Benefuture.Ontology.Sophont
  Formalization of Sophont (S): Goal-aligned persons, and the master inclusion theorem.
  Corresponds to: Bf_Pseudocode.txt L6, L78
  "S ⊆ Pe ⊆ B ⊆ E ⊆ T;"
  "S := Pe | A → G;"
-/

import Benefuture.Ontology.Person

namespace Benefuture.Ontology

/-- 
  Sophont (S): Extends Person with commitment and orientation to universal Goal G.
-/
structure Sophont extends Person where
  alignmentScore : Int
  h_aligned      : alignmentScore > 0
  deriving Repr

/-- Coercions enabling seamless projection down the ontological chain. -/
instance : Coe Sophont Person where
  coe s := s.toPerson

instance : Coe Sophont Being where
  coe s := s.toPerson.toBeing

instance : Coe Sophont Entity where
  coe s := s.toPerson.toBeing.toEntity

instance : Coe Sophont Thing where
  coe s := s.toPerson.toBeing.toEntity.toThing

/-- 
  MASTER THEOREM: The Ontological Subsetting Chain (Bf Pseudocode L6).
  S ⊆ Pe ⊆ B ⊆ E ⊆ T.
  Every Sophont is a Person, every Person is a Being, 
  every Being is an Entity, and every Entity is a Thing.
-/
theorem master_ontological_inclusion_chain (s : Sophont) :
    let pe : Person := s
    let b  : Being  := pe
    let e  : Entity := b
    let t  : Thing  := e
    s.id = pe.id ∧ pe.id = b.id ∧ b.id = e.id ∧ e.id = t.id := by
  dsimp
  refine ⟨rfl, rfl, rfl, rfl⟩

/-- 
  Benesophont is the canonical term for a Sophont aligned with Benefuture goals:
  Corresponds to: Benesophont.txt & Bf_Pseudocode.txt L78 ("S := Pe | A → G").
-/
abbrev Benesophont := Sophont
abbrev S := Sophont

end Benefuture.Ontology

