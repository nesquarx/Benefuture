/-
  Benefuture.Epistemology.Context
  Formalization of Epistemic & Operational Context (Cx ∈ T).
  Corresponds to: Bf_Pseudocode.txt L25, L42, L48, L154, L165, and Epistemology articles.
  
  "Context«Cx» represents the operational, epistemic, and environmental frame
   within which parameters, truth levels, assessments, and thresholds operate."
  "Threshold«Th»(Pm_i, Context«Cx») := (Pm_i ≥ Th_Cx) ⇒ Sig(Pm, Cx), (graded, multidimensional, nuanced);"
  "Assess«As»(x, A, t) := Norm((t ≤ t_0 ? Pr : Me)(x ← A) - Pr(x ← ¬A | Mem_ctrl) | Th_Cx);"
-/

import Benefuture.Math.Order
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Domain

namespace Benefuture.Epistemology

open Benefuture.Math
open Benefuture.Ontology

/-- 
  Operational and Epistemic Context (Cx ∈ T):
  Encapsulates the spatio-temporal, computational, telemetry, and threat conditions.
  Corresponds to: Bf_Pseudocode.txt L25, L154, L165.
-/
structure Context extends Thing where
  domain              : Domain
  telemetryResolution : Int  -- Observation fidelity in micro-units [0, SCALE]
  computeBudget       : Int  -- Available computational resources
  threatLevel         : Int  -- Environmental adversarial pressure [0, SCALE]
  noiseVariance       : Int  -- Sensor/attribution noise in micro-units
  h_telemetry_nonneg  : 0 ≤ telemetryResolution
  h_telemetry_bound   : telemetryResolution ≤ SCALE
  h_threat_nonneg     : 0 ≤ threatLevel
  h_threat_bound      : threatLevel ≤ SCALE
  deriving Repr

/-- Coercion: Every Context is canonically a Thing in Reality. -/
instance : Coe Context Thing where
  coe cx := cx.toThing


/-- Degraded Context Predicate: Telemetry resolution drops below degradation threshold. -/
def is_degraded (cx : Context) (th_degrade : Int) : Bool :=
  cx.telemetryResolution < th_degrade

/-- Optimal Context Predicate: Telemetry resolution meets or exceeds optimal threshold. -/
def is_optimal (cx : Context) (th_optimal : Int) : Bool :=
  cx.telemetryResolution ≥ th_optimal

/-- Emergency Context Predicate: Threat level exceeds safe operational threshold. -/
def is_emergency (cx : Context) (th_threat : Int) : Bool :=
  cx.threatLevel ≥ th_threat

/-- Helper constructor for standard Optimal Context. -/
def Context.mkOptimal (id : String) (dom : Domain) : Context :=
  { toThing := Thing.mkSimple id s!"context_optimal_{id}" dom.name 0,
    domain := dom,
    telemetryResolution := SCALE,
    computeBudget := 1000000,
    threatLevel := 0,
    noiseVariance := 1000,
    h_telemetry_nonneg := by unfold SCALE; decide,
    h_telemetry_bound := by unfold SCALE; decide,
    h_threat_nonneg := by decide,
    h_threat_bound := by unfold SCALE; decide }

/-- Helper constructor for standard Degraded Context (e.g., communications blackout, catastrophe). -/
def Context.mkDegraded (id : String) (dom : Domain) : Context :=
  { toThing := Thing.mkSimple id s!"context_degraded_{id}" dom.name 0,
    domain := dom,
    telemetryResolution := 10000, -- 1% telemetry
    computeBudget := 1000,
    threatLevel := 200000,
    noiseVariance := 500000,
    h_telemetry_nonneg := by decide,
    h_telemetry_bound := by unfold SCALE; decide,
    h_threat_nonneg := by decide,
    h_threat_bound := by unfold SCALE; decide }

/-- 
  THEOREM: Degraded Context Bounding Theorem.
  If a context is classified as degraded under threshold T, its telemetry is strictly less than T.
-/
theorem degraded_telemetry_strictly_below_threshold (cx : Context) (th : Int) 
    (h : is_degraded cx th = true) :
    cx.telemetryResolution < th := by
  unfold is_degraded at h
  exact of_decide_eq_true h

abbrev Cx := Context

end Benefuture.Epistemology

