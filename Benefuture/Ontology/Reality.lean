/-
  Benefuture.Ontology.Reality
  Formalization of Reality (ℝ), the Universe (𝕌), and Simulations.
  Corresponds to: Bf_Pseudocode.txt L16, L18, L22, L132 and Reality.txt / Simulation.txt
  "Reality«ℝ» := (Perceivable ∪ Changeable) ⊆ Universe«𝕌»;"
  "Id(T) := ∃!SubPattern(T):¬∃Id(ℝ-T),Disambiguate(Location(T) ∈ ℝ, History(T)), Id ≡ Dn : |Dn ∩ ℝ| = 1;"
  "Domain«Dn»:=ClassificationPattern(ℝ),Dn(T):=[(Dn_i,RelType,Wt)]|ΣWt=1,CausalStructure,NaturalOverlap,Nested(fuzzy),Rel(Dn_i,Dn_j)←Mem !declared;"
-/

import Mathlib.Data.Finset.Basic
import Mathlib.Data.Finset.Card
import Mathlib.Data.Real.Basic
import Benefuture.Ontology.Thing

namespace Benefuture.Ontology

/-- 
  Universe (𝕌):
  The total state space of all logically possible patterns, configurations, and abstractions.
  Corresponds to: Bf_Pseudocode.txt L16:
  "Reality«ℝ» := (Perceivable ∪ Changeable) ⊆ Universe«𝕌»;"
-/
structure UniversePattern where
  patternId     : String
  isPerceivable : Bool
  isChangeable  : Bool
  deriving Repr, DecidableEq

/-- 
  Reality (ℝ): The subset of the Universe that can be perceived or changed.
  Reality is defined operatively by causal interactivity:
  (Perceivable ∨ Changeable).
-/
structure RealityTouchpoint where
  isPerceivable : Bool
  isChangeable  : Bool
  h_real        : isPerceivable = true ∨ isChangeable = true
  deriving Repr, DecidableEq

/-- Coercion / Canonical Embedding: Every RealityTouchpoint embeds into the Universe 𝕌. -/
def RealityTouchpoint.toUniverse (r : RealityTouchpoint) (id : String := "real_point") : UniversePattern :=
  { patternId := id, isPerceivable := r.isPerceivable, isChangeable := r.isChangeable }

/-- 
  THEOREM: Reality is a Strict Subset of the Universe (ℝ ⊆ 𝕌).
  Every point in Reality satisfies causal interactivity in the Universe:
  isPerceivable = true ∨ isChangeable = true.
-/
theorem reality_is_subset_of_universe (r : RealityTouchpoint) :
    let u := r.toUniverse
    u.isPerceivable = true ∨ u.isChangeable = true := by
  dsimp [RealityTouchpoint.toUniverse]
  exact r.h_real

/-- 
  Theoretical Non-Real Patterns in the Universe (𝕌 − ℝ):
  Patterns where isPerceivable = false ∧ isChangeable = false (such as one-shot games
  or solipsistic ungrounded abstractions).
  Corresponds to: Bf_Pseudocode.txt L136 ("1shotGame ⊆ 𝕌 − ℝ").
-/
def is_outside_reality (u : UniversePattern) : Bool :=
  !u.isPerceivable && !u.isChangeable

/- =========================================================================
   3.1 [R] IDENTITY AND DOMAIN PATTERNS MATCHED AGAINST ℝ
   "Identity and domains are one kind of object: a pattern matched against ℝ."
   Corresponds to: Bf_Pseudocode.txt L18, L22
   ========================================================================= -/

/-- 
  [R] Thing disambiguated identity pattern.
  Includes location ⊕ history worldline per L18 Disambiguate(Location(T) ∈ ℝ, History(T)).
-/
def thing_identity_pattern (t : Thing) : Pattern := {
  id := "id_" ++ t.id,
  «matches» := fun t' => (t'.id == t.id) && (t'.grounding.location == t.grounding.location) && (t'.grounding.history == t.grounding.history)
}

/-- 
  [R] RealityState: A finite collection of Things existing in Reality (ℝ) at an epoch.
  Maintains the foundational invariant that identity patterns are injective.
-/
structure RealityState where
  things     : Finset Thing
  id_pattern : Thing → Pattern := thing_identity_pattern
  h_id_inj   : ∀ t1 t2, t1 ∈ things → t2 ∈ things → id_pattern t1 = id_pattern t2 → t1 = t2

/-- 
  [R] Extension of a Pattern against Reality:
  ext(p)(R) := {t ∈ R | matches p t}
-/
def ext (p : Pattern) (R : RealityState) : Finset Thing :=
  R.things.filter (fun t => p.«matches» t)

/-- 
  [R] IsIdentity predicate:
  A pattern p is an identity in RealityState R iff its extension is a singleton:
  |ext p R| = 1.
  Corresponds to: Bf_Pseudocode.txt L18: "Id ≡ Dn : |Dn ∩ ℝ| = 1".
-/
def IsIdentity (p : Pattern) (R : RealityState) : Prop :=
  (ext p R).card = 1

/-- 
  [R] IsDomainPattern predicate:
  A pattern p is a domain pattern in RealityState R iff its extension has cardinality > 1.
  Corresponds to: Bf_Pseudocode.txt L18, L22.
-/
def IsDomainPattern (p : Pattern) (R : RealityState) : Prop :=
  1 < (ext p R).card

theorem thing_identity_pattern_matches_self (t : Thing) :
    (thing_identity_pattern t).«matches» t = true := by
  unfold thing_identity_pattern
  dsimp
  simp

/-- 
  THEOREM: RealityState Identity Injectivity Invariant.
  In any valid RealityState R, distinct things have distinct identity patterns.
-/
theorem reality_state_id_injective (R : RealityState) (t1 t2 : Thing)
    (h1 : t1 ∈ R.things) (h2 : t2 ∈ R.things) (h_eq : R.id_pattern t1 = R.id_pattern t2) :
    t1 = t2 :=
  R.h_id_inj t1 t2 h1 h2 h_eq

/-- 
  THEOREM: Singleton Extension Yields Identity.
  If an identity pattern matches exactly one unique thing in R, it is an Identity in R.
-/
theorem identity_pattern_is_identity (R : RealityState) (t : Thing) (ht : t ∈ R.things)
    (h_uniq : ∀ t' ∈ R.things, (thing_identity_pattern t).«matches» t' = true → t' = t) :
    IsIdentity (thing_identity_pattern t) R := by
  unfold IsIdentity ext
  have h_set : R.things.filter (fun t' => (thing_identity_pattern t).«matches» t') = {t} := by
    ext x
    simp only [Finset.mem_filter, Finset.mem_singleton]
    constructor
    · intro ⟨hx, hm⟩
      exact h_uniq x hx hm
    · intro hx
      rw [hx]
      exact ⟨ht, thing_identity_pattern_matches_self t⟩
  rw [h_set]
  exact Finset.card_singleton t

/- =========================================================================
   IDENTITY ESTIMATES AND BIND-ID
   Corresponds to: Bf_Pseudocode.txt L132:
   "Agg(LogIdMl[](E, 1:(0,1)) | ≥2 Cluster) ≥Th ⇒ BindId(E, 1:1)"
   ========================================================================= -/

/-- Evidence logged from a decentralized network cluster. -/
structure ClusterEvidence where
  clusterId : String
  logScore  : ℝ

/-- 
  [R] Identity Estimate before BindId:
  Before binding, identity is an uncertain distribution over candidate records.
  Unbound records carry only statistical reputation (consistent with opt-out tier).
-/
structure IdentityEstimate where
  candidateIds     : List (String × ℝ)
  clusterEvidences : List ClusterEvidence
  isBound          : Bool := false

/-- 
  Predicate: Sufficient multi-cluster evidence to trigger BindId (L132).
  Requires aggregation over ≥ 2 independent clusters and aggregate log score ≥ Th.
-/
def can_bind_id (est : IdentityEstimate) (th : ℝ) : Prop :=
  est.clusterEvidences.length ≥ 2 ∧
  (est.clusterEvidences.map (·.logScore)).sum ≥ th

/-- 
  [R] BindId operation:
  Binds an entity record 1:1 to a singleton identity once threshold evidence is met.
-/
def bind_id (est : IdentityEstimate) (boundId : String) : IdentityEstimate := {
  candidateIds := [(boundId, 1.0)],
  clusterEvidences := est.clusterEvidences,
  isBound := true
}

/-- THEOREM: BindId yields a singleton candidate list with probability 1. -/
theorem bind_id_yields_singleton (est : IdentityEstimate) (boundId : String) :
    (bind_id est boundId).candidateIds = [(boundId, 1.0)] := rfl

/- =========================================================================
   REALITY SCOPE (↑ℝ)
   ========================================================================= -/

/-- 
  The Scope of Reality (ℝ):
  Reality«ℝ» := (Perceivable ∪ Changeable) ⊆ Universe«𝕌».
  Quantifies civilizational perceptual reach and causal transformation capability.
  Corresponds to: Bf_Pseudocode.txt L16, L74 (↑ℝ).
-/
structure RealityScope where
  perceivableScope : Nat  -- Empirical perception, telemetry, scientific discovery, exploration
  changeableScope  : Nat  -- Causal agency, physical engineering, transformation reach
  deriving Repr, DecidableEq

/-- Total magnitude of Reality accessible to the civilization: |ℝ| = Perceivable + Changeable. -/
def reality_scope_magnitude (r : RealityScope) : Nat :=
  r.perceivableScope + r.changeableScope

/-- 
  Reality Enhancement Delta (Δℝ):
  Measures the expansion or contraction of Reality resulting from an action or epoch.
-/
def reality_enhancement_delta (r0 r1 : RealityScope) : Int :=
  (reality_scope_magnitude r1 : Int) - (reality_scope_magnitude r0 : Int)

/-- 
  Reality Enhancement Predicate (↑ℝ):
  An action or civilizational step enhances Reality if it strictly expands 
  perceivable or changeable scope in the Universe (reality_enhancement_delta > 0).
-/
def enhances_reality (r0 r1 : RealityScope) : Prop :=
  reality_enhancement_delta r0 r1 > 0

instance (r0 r1 : RealityScope) : Decidable (enhances_reality r0 r1) := by
  unfold enhances_reality
  infer_instance

/-- Non-shrinking reality condition: reality_enhancement_delta ≥ 0. -/
def non_shrinking_reality (r0 r1 : RealityScope) : Prop :=
  reality_enhancement_delta r0 r1 ≥ 0

instance (r0 r1 : RealityScope) : Decidable (non_shrinking_reality r0 r1) := by
  unfold non_shrinking_reality
  infer_instance

/-- 
  A Substrate in Reality (extends Thing):
  Physical energy-matter or computational infrastructure capable of hosting informational patterns.
  Corresponds to: Substrate ⊆ Energy ∪ Matter ⊆ Thing«T» (Bf_Pseudocode.txt L15).
-/
structure RealitySubstrate extends Thing where
  touchpoint   : RealityTouchpoint
  deriving Repr, DecidableEq

instance : Coe RealitySubstrate Thing where
  coe s := s.toThing

def RealitySubstrate.mkSimple (id : String) (tp : RealityTouchpoint) : RealitySubstrate :=
  { toThing := Thing.mkSimple id s!"substrate_{id}" "reality_substrate" 0,
    touchpoint := tp }

/-- 
  Simulation Scope:
  Distinguishes internal simulation context from external reality.
-/
inductive SimulationScope where
  | InternalOnly     : SimulationScope  -- Isolated inside substrate (e.g. book, offline sandbox)
  | RealityBridged   : SimulationScope  -- Capable of bidirectional interaction with outside Reality
  deriving Repr, DecidableEq

/-- 
  Simulated Thing (extends Thing):
  A pattern rendered symbolically within a Reality substrate.
  Corresponds to: Bf_Pseudocode.txt L15 ("Simulation ⊆ Thing«T»").
-/
structure SimulatedThing extends Thing where
  substrate      : RealitySubstrate
  scope          : SimulationScope
  hasAgency      : Bool
  deriving Repr

instance : Coe SimulatedThing Thing where
  coe st := st.toThing

def SimulatedThing.mkSimple (id : String) (sub : RealitySubstrate) (scope : SimulationScope) (agency : Bool := true) : SimulatedThing :=
  { toThing := Thing.mkSimple id s!"sim_{id}" "simulation" 0,
    substrate := sub,
    scope := scope,
    hasAgency := agency }

/-- 
  Predicate: A simulated thing is an active, real participant in Reality (ℝ)
  if it is capable of interacting outside its substrate.
-/
def is_part_of_reality (st : SimulatedThing) : Bool :=
  match st.scope with
  | .RealityBridged => true
  | .InternalOnly   => false

/-- 
  THEOREM: The Reality Interaction Bridge.
  If an entity in a simulation can perceive and act upon Reality outside its substrate,
  it is structurally part of Reality and must be treated as a real entity with full moral/causal standing.
  Static simulations (e.g. characters in books) remain isolated descriptions.
-/
theorem bridged_simulation_is_part_of_reality (st : SimulatedThing) 
    (h_bridged : st.scope = .RealityBridged) :
    is_part_of_reality st = true := by
  unfold is_part_of_reality
  rw [h_bridged]

theorem isolated_simulation_not_in_external_reality (st : SimulatedThing)
    (h_iso : st.scope = .InternalOnly) :
    is_part_of_reality st = false := by
  unfold is_part_of_reality
  rw [h_iso]

/- =========================================================================
   LONG-TERM TIME CONTINUUM (lt ∈ T)
   "LongTerm«lt» := (t_maxRecord, 0, t_maxPr), time«t» ∈ lt, Sig(O_t) ∝ P(O_t) * |O_t|;"
   Corresponds to: Bf_Pseudocode.txt L34, L164.
   ========================================================================= -/

inductive TemporalEra where
  | HistoricalPast    : TemporalEra  -- t < 0
  | PresentExecution  : TemporalEra  -- t = 0
  | PredictiveFuture  : TemporalEra  -- t > 0
  deriving Repr, DecidableEq

def classify_temporal_era (t : Int) : TemporalEra :=
  if t < 0 then .HistoricalPast
  else if t = 0 then .PresentExecution
  else .PredictiveFuture

/-- 
  LongTerm Continuum (lt ∈ T, extends Thing):
  The bounded temporal scope spanning from earliest verified record history
  to the furthest predictive planning horizon: (t_maxRecord, 0, t_maxPr).
  Corresponds to: Bf_Pseudocode.txt L34 ("lt ∈ T").
-/
structure LongTermHorizon extends Thing where
  t_maxRecord  : Int  -- Earliest historical record horizon in past (t_maxRecord < 0)
  t_present    : Int := 0
  t_maxPr      : Int  -- Furthest predictive planning horizon in future (0 < t_maxPr)
  h_record_past: t_maxRecord < 0
  h_pr_future  : 0 < t_maxPr
  deriving Repr

instance : Coe LongTermHorizon Thing where
  coe lt := lt.toThing

def LongTermHorizon.mkSimple (id : String) (t_past t_future : Int)
    (h_past : t_past < 0 := by decide) (h_fut : 0 < t_future := by decide) : LongTermHorizon :=
  { toThing := Thing.mkSimple id s!"horizon_{id}" "temporal_continuum" 0,
    t_maxRecord := t_past, t_present := 0, t_maxPr := t_future,
    h_record_past := h_past, h_pr_future := h_fut }

def is_in_longterm (lt : LongTermHorizon) (t : Int) : Prop :=
  lt.t_maxRecord ≤ t ∧ t ≤ lt.t_maxPr

instance (lt : LongTermHorizon) (t : Int) : Decidable (is_in_longterm lt t) := by
  unfold is_in_longterm
  infer_instance

def outcome_significance (prob magnitude : Int) : Int :=
  (prob * magnitude) / 1000000

theorem present_is_in_longterm (lt : LongTermHorizon) :
    is_in_longterm lt 0 := by
  unfold is_in_longterm
  have hpast := lt.h_record_past
  have hfut := lt.h_pr_future
  omega

theorem outcome_significance_nonneg (p mag : Int) (hp : 0 ≤ p) (hm : 0 ≤ mag) :
    0 ≤ outcome_significance p mag := by
  unfold outcome_significance
  have hmul : 0 ≤ p * mag := Int.mul_nonneg hp hm
  exact Int.ediv_nonneg hmul (by decide)

abbrev lt := LongTermHorizon
abbrev RealityTouch := RealityTouchpoint
abbrev 𝕌 := UniversePattern
abbrev Universe := UniversePattern

end Benefuture.Ontology
