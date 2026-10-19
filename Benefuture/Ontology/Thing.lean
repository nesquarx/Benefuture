/-
  Benefuture.Ontology.Thing
  Formalization of the most fundamental ontological class: Thing (T).
  Corresponds to: Bf_Pseudocode.txt L16-18
  "Reality«ℝ» := (Perceivable ∪ Changeable) ⊆ Universe«𝕌»;"
  "T := InfoPattern | renderedIn(org(spctime(Energy, Matter, otherT[])));"
  "Id(T) := ∃!SubPattern(T):¬∃Id(ℝ-T),Disambiguate(Location(T) ∈ ℝ, History(T));"
-/

namespace Benefuture.Ontology

/-- 
  Spatiotemporal coordinates disambiguating an instance in Reality (ℝ).
-/
structure SpacetimeGrounding where
  location : String
  timestamp: Nat
  history  : List String
  deriving Repr, DecidableEq

/-- 
  Thing (T): The universal root of all distinguishable patterns in Reality.
  Guaranteed to possess an informational pattern and disambiguated grounding.
  Corresponds to: Bf_Pseudocode.txt L16-18.
-/
structure Thing where
  id        : String
  grounding : SpacetimeGrounding
  deriving Repr, DecidableEq

/-- Two Things are identical if and only if their identifiers and grounding match. -/
def thing_eq (t1 t2 : Thing) : Prop :=
  t1.id = t2.id ∧ t1.grounding = t2.grounding

instance : DecidableRel thing_eq := by
  intro t1 t2
  unfold thing_eq
  infer_instance

/-- Helper constructor for a spatiotemporal point in Reality. -/
def SpacetimeGrounding.mkPoint (loc : String) (t : Nat) : SpacetimeGrounding :=
  ⟨loc, t, []⟩

/-- Ergonomic constructor for a generic Thing in Reality. -/
def Thing.mkSimple (id : String) (_name : String := id) (loc : String := "reality_substrate") (t : Nat := 0) : Thing :=
  ⟨id, SpacetimeGrounding.mkPoint loc t⟩

/-- 
  Identity Id(T):
  Corresponds to: Bf_Pseudocode.txt L18:
  "Id(T) := ∃!SubPattern(T):¬∃Id(ℝ-T),Disambiguate(Location(T) ∈ ℝ, History(T));"
-/
def identity_of (t : Thing) : String := t.id

abbrev Id := identity_of
abbrev T := Thing

/-- 
  [R] Pattern matched against Reality (ℝ).
  Corresponds to: Bf_Pseudocode.txt L17-18, L22.
  "Identity and domains are one kind of object: a pattern matched against ℝ."
-/
structure Pattern where
  id        : String
  name      : String := id
  «matches» : Thing → Bool

/-- Helper constructor for standard patterns. -/
def Pattern.mkSimple (name : String) (_invariant : String := "identity_invariant") : Pattern :=
  { id := name, name := name, «matches» := fun _ => true }

end Benefuture.Ontology
