/-
  Benefuture.Ontology.Being
  Formalization of Being (B): Sentient entities, moral patients, the Hair Razor,
  and the Three Concentric Boundaries: Lifespan, Minimal Body, Nuclear Self, and Extended Self.
  Corresponds to: Bf_Pseudocode.txt L23, L67-70, and Being.txt
  "Sentience«St» := SubjectiveExperience«Se» + Preferences;"
  "B := St(E);"
  "Bounds_B := Lifespan(t_0 = St_begin, t_end = St_loss_irreversible),"
  "Body : (∃min(T ∈ ℝ) : Ha(Body) = Ha_immediate(B), Id(B):=Id(Body)),"
  "Self«Sl» : ∃fuzzy(max(T ∈ ℝ) : Ha(Sl) = Ha_lt(B));"
-/

import Benefuture.Ontology.Entity
import Benefuture.Math.Order

namespace Benefuture.Ontology

open Benefuture.Math

/-- 
  Preference (extends Thing):
  Corresponds to: Preference.txt & Bf_Pseudocode.txt L23:
  "Sentience«St» := SubjectiveExperience«Se» + Preferences;"
  Valued preference vector directed at a target Thing or state in Reality.
-/
structure Preference extends Thing where
  targetId  : String
  valuation : Int  -- Positive or negative hedonic/evaluative weighting
  intensity : Nat
  deriving Repr, DecidableEq

/-- Coercion: Every Preference is canonically a Thing in Reality. -/
instance : Coe Preference Thing where
  coe p := p.toThing


abbrev Preferences := List Preference

/-- 
  Sentience (St): Subjective experience intensity plus distinct preferences.
  Sentience capacity is strictly positive in [1, SCALE].
  Preferences are grounded as Things in Reality.
  Corresponds to: Bf_Pseudocode.txt L23 ("St := Se + Preferences").
-/
structure Sentience where
  experienceLevel : Int
  preferences     : List Preference := []
  preferenceIds   : List String := []
  h_pos           : 0 < experienceLevel
  h_bound         : experienceLevel ≤ SCALE
  deriving Repr

abbrev St := Sentience

/-- 
  Physical Substrate Component of a Being (extends Thing).
  Used to formalize the Hair Razor (distinguishing minimal Body from external parts).
  Corresponds to: Bf_Pseudocode.txt L69 ("Body : (∃min(T ∈ ℝ) : Ha(Body) = Ha_immediate(B), Id(B):=Id(Body))").
-/
structure SubstrateComponent extends Thing where
  name       : String
  is_vital   : Bool  -- True if loss immediately diminishes subjective experience
  deriving Repr, DecidableEq

instance : Coe SubstrateComponent Thing where
  coe c := c.toThing


def SubstrateComponent.mkSimple (id name : String) (vital : Bool) : SubstrateComponent :=
  { toThing := Thing.mkSimple id s!"component_{name}" "biology" 0,
    name := name, is_vital := vital }

/-- 
  Interdependence Link in the Extended Self (Sl_ext, extends Thing):
  Couples an external Thing or Being to this Being with sensitivity factor L ∈ (0, SCALE].
  L = 1.0 (Total coupling: e.g. symbiotic life support).
  L ~ 0.1-0.5 (Habitat, tool, community, reputation).
  Corresponds to: Bf_Pseudocode.txt L70 ("Self«Sl» : ∃fuzzy(max(T ∈ ℝ) : Ha(Sl) = Ha_lt(B))"):
  the self is causal, over the long-term window.
-/
structure InterdependenceLink extends Thing where
  targetId       : String
  couplingWeight : Int  -- L in [1, SCALE]
  h_coupling_pos : 0 < couplingWeight
  h_coupling_bnd : couplingWeight ≤ SCALE
  deriving Repr, DecidableEq

instance : Coe InterdependenceLink Thing where
  coe link := link.toThing


def InterdependenceLink.mkSimple (id targetId : String) (weight : Int)
    (h_pos : 0 < weight := by decide) (h_bnd : weight ≤ SCALE := by decide) : InterdependenceLink :=
  { toThing := Thing.mkSimple id s!"link_{id}" "interdependence" 0,
    targetId := targetId, couplingWeight := weight,
    h_coupling_pos := h_pos, h_coupling_bnd := h_bnd }

/-- 
  Being (B): A sentient Entity bounded by Lifespan, minimal Body, internal Self, and extended Self.
-/
structure Being extends Entity where
  sentience    : Sentience
  t_begin      : Nat
  t_end        : Option Nat
  components   : List SubstrateComponent
  memoryTrace  : List String                 -- Internal Self: episodic memory trace
  extendedSelf : List InterdependenceLink     -- Extended Self: coupled network in Reality
  h_has_vital  : components.any SubstrateComponent.is_vital = true
  deriving Repr

/-- Coercion: Every Being is an Entity. -/
instance : Coe Being Entity where
  coe b := b.toEntity

/-- Coercion: Every Being is transitively a Thing. -/
instance : Coe Being Thing where
  coe b := b.toEntity.toThing



/- --- The Hair Razor Formalization --- -/

/-- A component is part of the minimal Body iff its destruction causes immediate vital harm. -/
def is_body_component (c : SubstrateComponent) : Prop :=
  c.is_vital = true

/-- Non-vital components (like hair, clipped nails, or external tools) belong to extended Self, not Body. -/
def is_extended_self_component (c : SubstrateComponent) : Prop :=
  c.is_vital = false

/-- 
  Theorem: The Hair Razor Minimality Theorem.
  Superfluous non-vital parts (hair, decorative ornaments) cannot be part of the minimal Body.
-/
theorem hair_razor_nonvital_excluded (c : SubstrateComponent) (h : is_extended_self_component c) :
    ¬ is_body_component c := by
  unfold is_extended_self_component at h
  unfold is_body_component
  intro h_body
  have h1 : c.is_vital = false := h
  have h2 : c.is_vital = true := h_body
  rw [h1] at h2
  contradiction

/- --- Extended Self Harm Propagation --- -/

/-- 
  Calculates the raw coupled harm impact on a Being from damage inflicted on its Extended Self:
  RawHarm = CouplingFactor L * Damage.
-/
def raw_extended_harm (link : InterdependenceLink) (damage : Int) : Int :=
  link.couplingWeight * damage

/-- 
  Calculates scaled derived harm on a Being from damage inflicted on its Extended Self:
  DerivedHarm = (CouplingFactor L * Damage) / SCALE.
-/
def derived_extended_harm (link : InterdependenceLink) (damage : Int) : Int :=
  raw_extended_harm link damage / SCALE

/-- 
  THEOREM: Extended Self Harm Propagation Theorem.
  Whenever an external target coupled to a Being's extended self suffers damage (> 0),
  the raw coupled impact transmitted to the Being is strictly positive (L * Damage > 0).
  Damage to the commons or community directly strikes the extended self.
-/
theorem extended_self_propagates_harm (link : InterdependenceLink) (damage : Int) (h_dam : damage > 0) :
    raw_extended_harm link damage > 0 :=
  Int.mul_pos link.h_coupling_pos h_dam

/-- 
  Vital Sustenance Coupling:
  Links a Being to an external sustenance resource (e.g. Bread) with full biological coupling (L = 1.0).
-/
def mk_sustenance_coupling (foodId : String) : InterdependenceLink :=
  InterdependenceLink.mkSimple s!"sustenance_{foodId}" foodId SCALE (by decide) (by decide)

/-- 
  THEOREM: Food Deprivation Direct Vital Harm.
  Because food sustenance possesses maximal vital coupling (L = 1.0) in a Being's extended self,
  loss or deprivation of food sustenance transmits 100% of the raw deprivation harm to the Being:
  Harm(Being) = DeprivationHarm * SCALE.
-/
theorem sustenance_deprivation_transmits_full_harm (foodId : String) (deprivationHarm : Int) :
    raw_extended_harm (mk_sustenance_coupling foodId) deprivationHarm = SCALE * deprivationHarm := by
  unfold raw_extended_harm mk_sustenance_coupling InterdependenceLink.mkSimple
  rfl

abbrev B := Being

end Benefuture.Ontology


