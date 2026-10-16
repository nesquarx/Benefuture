/-
  Benefuture.Ontology.Reality
  Formalization of Reality (ℝ), the Universe (𝕌), and Simulations.
  Corresponds to: Bf_Pseudocode.txt L16, and Reality.txt / Simulation.txt
  "Reality«ℝ» := (Perceivable ∪ Changeable) ⊆ Universe«𝕌»;"
  "When a thing only exists as a pattern represented symbolically through a substrate pattern in reality, it is a simulation."
-/

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

theorem reality_substrate_is_thing (s : RealitySubstrate) : (s : Thing).id = s.id := rfl

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

theorem simulated_thing_is_thing (st : SimulatedThing) : (st : Thing).id = st.id := rfl

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

/-- 
  Temporal Era classification centered around the present execution horizon (t = 0):
  - Historical Past (t < 0): recorded in immutable memory.
  - Present Execution (t = 0): active interaction and intervention.
  - Predictive Future (t > 0): subject to probabilistic forecasting and proper scoring.
-/
inductive TemporalEra where
  | HistoricalPast    : TemporalEra  -- t < 0
  | PresentExecution  : TemporalEra  -- t = 0
  | PredictiveFuture  : TemporalEra  -- t > 0
  deriving Repr, DecidableEq

/-- Classify any integer time coordinate into its temporal era. -/
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

theorem longterm_horizon_is_thing (lt : LongTermHorizon) : (lt : Thing).id = lt.id := rfl

def LongTermHorizon.mkSimple (id : String) (t_past t_future : Int)
    (h_past : t_past < 0 := by decide) (h_fut : 0 < t_future := by decide) : LongTermHorizon :=
  { toThing := Thing.mkSimple id s!"horizon_{id}" "temporal_continuum" 0,
    t_maxRecord := t_past, t_present := 0, t_maxPr := t_future,
    h_record_past := h_past, h_pr_future := h_fut }

/-- Predicate: A time point t is grounded within the LongTerm civilizational horizon. -/
def is_in_longterm (lt : LongTermHorizon) (t : Int) : Prop :=
  lt.t_maxRecord ≤ t ∧ t ≤ lt.t_maxPr

instance (lt : LongTermHorizon) (t : Int) : Decidable (is_in_longterm lt t) := by
  unfold is_in_longterm
  infer_instance

/-- 
  Significance of an Outcome across Time:
  Sig(O_t) ∝ P(O_t) * |O_t|.
  Scaled in micro-units: Sig = (P * |O|) / SCALE.
  Corresponds to: Bf_Pseudocode.txt L34.
-/
def outcome_significance (prob magnitude : Int) : Int :=
  (prob * magnitude) / 1000000

/-- 
  THEOREM: Present is Invariant in LongTerm Horizon.
  The present execution horizon (t = 0) is guaranteed to lie strictly 
  within the LongTerm continuum: t_maxRecord < 0 < t_maxPr.
-/
theorem present_is_in_longterm (lt : LongTermHorizon) :
    is_in_longterm lt 0 := by
  unfold is_in_longterm
  have hpast := lt.h_record_past
  have hfut := lt.h_pr_future
  omega

/-- 
  THEOREM: Outcome Significance Non-Negativity.
  Non-negative probability and magnitude produce non-negative significance.
-/
theorem outcome_significance_nonneg (p mag : Int) (hp : 0 ≤ p) (hm : 0 ≤ mag) :
    0 ≤ outcome_significance p mag := by
  unfold outcome_significance
  have hmul : 0 ≤ p * mag := Int.mul_nonneg hp hm
  exact Int.ediv_nonneg hmul (by decide)

/-- Abbreviations aligning with Bf_Pseudocode.txt L16, L34. -/
abbrev lt := LongTermHorizon
abbrev ℝ := RealityTouchpoint
abbrev 𝕌 := UniversePattern
abbrev Universe := UniversePattern

end Benefuture.Ontology

