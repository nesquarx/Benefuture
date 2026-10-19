/-
  Benefuture.Measurement.MetricModel
  Formalization of Markers (M ∈ T), Assessment (As ∈ T), Metric Models (MM ∈ T), Domain (Dn ∈ T), and Model Competition.
  Corresponds to: Bf_Pseudocode.txt L22, L46-53, L82-86, and Measurement.txt

  "Domain«Dn»:=ClassificationPattern(ℝ),Dn(T):=[(Dn_i,RelType,Wt∈[0,1])]|CausalStructure,NaturalOverlap;"
  "M := PerceivableProxies(U, H, ...) ∈ ℝ, Estd, Novel;"
  "Assess«As»(x, A, t) := Norm((t ≤ t_0 ? Pr : Me)(x ← A) - Pr(x ← ¬A | Mem_ctrl) | Th_Cx);"
  "MetricMl«MM» := {Ml_i, m[] ⊆ M, Dn[]} ⇄ Compete(max Sy(As(PrAcc(Ml_i), adopt, t) > CorrSc(m) > CE(m) > N(m)))..."
  "C := {C_i} | C_i ↔ MM_j ∈ TopModels(MM_Acc>Th, Dn_i)..."
-/

import Benefuture.Math.Order
import Benefuture.Math.Synergy
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Entity
import Benefuture.Ontology.Domain
import Benefuture.Measurement.Threshold

namespace Benefuture.Measurement

open Benefuture.Math
open Benefuture.Ontology

/-- 
  Marker Origin Taxonomy:
  Grounded strictly in Reality:
  - EmpiricalObservation: Directly observed physical/behavioral state of a Thing in Reality (M ∈ ℝ).
  - MetricModelOutput: Synthetic output from another model (prohibited by anti-circularity).
-/
inductive MarkerOrigin where
  | EmpiricalObservation : String → MarkerOrigin  -- targetThingId in Reality
  | MetricModelOutput    : String → MarkerOrigin  -- modelId emitting output
  deriving Repr, DecidableEq

def MarkerOrigin.isEmpirical : MarkerOrigin → Bool
  | .EmpiricalObservation _ => true
  | .MetricModelOutput _    => false

/-- 
  Perceivable Marker (M ∈ T): An empirical proxy in reality.
  Crucial Rule (Anti-Circularity): A marker cannot be the output of another Metric Model.
  Corresponds to: Bf_Pseudocode.txt L46:
  "M := PerceivableProxies(U, H, ...) ∈ ℝ, Estd, Novel, m ≠ Ou ← MM_any;"
-/
structure Marker extends Thing where
  name         : String
  domain       : Domain
  origin       : MarkerOrigin := .EmpiricalObservation "reality_touchpoint"
  is_novel     : Bool := false  -- Novel marker vs Established anchor (M_Estd)
  is_model_out : Bool := false  -- Backward-compatibility circularity flag
  h_empirical  : origin.isEmpirical = true
  h_non_circ   : is_model_out = false  -- Anti-circularity constraint: m ≠ Ou ← MM_any
  deriving Repr, DecidableEq

/-- Coercion: Every Marker is canonically a Thing in Reality. -/
instance : Coe Marker Thing where
  coe m := m.toThing


/-- Helper constructor for Markers grounded in a domain. -/
def Marker.mkSimple (id name : String) (dom : Domain) (novel : Bool := false) : Marker :=
  { toThing := Thing.mkSimple id s!"marker_{name}" dom.name 0,
    name := name, domain := dom,
    origin := .EmpiricalObservation s!"obs_{id}",
    is_novel := novel, is_model_out := false,
    h_empirical := rfl, h_non_circ := rfl }

/-- 
  Prediction Accuracy (Brier score or equivalent accuracy metric in micro-units).
-/
structure PredictionAccuracy where
  brier_accuracy : Int  -- Scaled in [0, SCALE]
  h_acc_nonneg   : 0 ≤ brier_accuracy
  h_acc_bound    : brier_accuracy ≤ SCALE
  deriving Repr

/-- 
  Metric Model (MM ∈ T):
  An algorithmic model proposing markers, causal explanations, and predictive mappings for U/H.
-/
structure MetricModel extends Thing where
  domain           : Domain
  markers          : List Marker
  predictionAcc    : PredictionAccuracy
  correlationScore : Int  -- Correlation with established markers M_Estd
  hasCausalTheory  : Bool -- Causal explanation quality (CE)
  noveltyScore     : Int  -- Novelty of proposed proxies
  h_markers_exist  : markers ≠ []
  deriving Repr

/-- Coercion: Every MetricModel is canonically a Thing in Reality. -/
instance : Coe MetricModel Thing where
  coe mm := mm.toThing


/-- Helper constructor for MetricModels. -/
def MetricModel.mkSimple (id : String) (dom : Domain) (m : List Marker) (acc : PredictionAccuracy) 
    (corr : Int) (hasCE : Bool) (novelty : Int) (hm : m ≠ []) : MetricModel :=
  { toThing := Thing.mkSimple id s!"model_{id}" dom.name 0,
    domain := dom, markers := m, predictionAcc := acc,
    correlationScore := corr, hasCausalTheory := hasCE,
    noveltyScore := novelty, h_markers_exist := hm }

/-- 
  Competition Score for Metric Models:
  Sy(PrAcc > CorrSc > CE > N).
  Weights accuracy highest (50%), then correlation with established markers (30%),
  causal explanation (20%), and novelty bonus (20%).
-/
def compute_model_score (mm : MetricModel) : Int :=
  let pr_weight   := 50 * mm.predictionAcc.brier_accuracy / SCALE
  let corr_weight := 30 * mm.correlationScore / SCALE
  let ce_bonus    := if mm.hasCausalTheory then 20 else 0
  let nov_weight  := 20 * mm.noveltyScore / SCALE
  pr_weight + corr_weight + ce_bonus + nov_weight

/-- Qualification threshold to back a currency: must score at least 80 (e.g., 80% competency). -/
def MM_QUALIFICATION_THRESHOLD : Int := 80

/-- Predicate: A Metric Model qualifies for the TopModels set if its score exceeds threshold. -/
def is_qualified_top_model (mm : MetricModel) : Prop :=
  compute_model_score mm ≥ MM_QUALIFICATION_THRESHOLD

instance (mm : MetricModel) : Decidable (is_qualified_top_model mm) := by
  unfold is_qualified_top_model
  infer_instance

/-- 
  Dynamic Temporal Assessment Formula:
  Assess«As»(x, A, t) := Norm((t ≤ t_0 ? Pr : Me)(x ← A) - Pr(x ← ¬A | Mem_ctrl) | Th_Cx).
  Corresponds to: Bf_Pseudocode.txt L48, Measurement.txt L39-41.
  
  Before action execution (t ≤ t_0): both action outcome and counterfactual are Predictions (Pr).
  After action execution (t > t_0): action outcome is empirical Measurement (Me), while 
  inaction counterfactual remains a Prediction conditioned on control memory (Mem_ctrl).
  The resulting difference is normalized by the context threshold: (Δ * SCALE) / Th_Cx.
-/
def dynamic_assessment (t t_0 : Int) (pr_action me_action pr_counter : Int) (th : Threshold) : Int :=
  let action_branch := if t ≤ t_0 then pr_action else me_action
  let raw_diff := action_branch - pr_counter
  norm_assessment raw_diff th

/-- 
  Assessment (As ∈ T):
  The counterfactual difference an Action makes compared to inaction, normalized by context threshold.
-/
structure Assessment extends Thing where
  action           : Action
  timestamp        : Int        -- Evaluation time coordinate t
  executionHorizon : Int        -- Action execution timestamp t_0
  threshold        : Threshold  -- Contextual threshold Th_Cx
  actionOutcome    : Int        -- (t ≤ t_0 ? Pr : Me)(x ← A)
  counterfactual   : Int        -- Pr(x ← ¬A | Mem_ctrl)
  normalizedDelta  : Int        -- Scaled assessment in units of threshold
  h_normalized     : normalizedDelta = norm_assessment (actionOutcome - counterfactual) threshold
  deriving Repr

/-- Coercion: Every Assessment is canonically a Thing in Reality. -/
instance : Coe Assessment Thing where
  coe asmt := asmt.toThing


/-- Predicate: Assessment occurs post-execution in verified Reality. -/
def is_ex_post (asmt : Assessment) : Bool :=
  asmt.timestamp > asmt.executionHorizon

/-- Predicate: Assessment occurs pre-execution as planning forecast. -/
def is_ex_ante (asmt : Assessment) : Bool :=
  asmt.timestamp ≤ asmt.executionHorizon

/-- 
  THEOREM: Ex-Post Assessment Uses Empirical Measurement.
  When t > t_0, dynamic assessment uses the verified measurement in Reality (me_action),
  grounding probabilistic escrow settlement in empirical observation.
-/
theorem ex_post_uses_measurement (t t_0 : Int) (pr_act me_act pr_ctrl : Int) (th : Threshold)
    (h_post : t > t_0) :
    dynamic_assessment t t_0 pr_act me_act pr_ctrl th = 
    norm_assessment (me_act - pr_ctrl) th := by
  unfold dynamic_assessment
  have h_not : ¬(t ≤ t_0) := by omega
  simp [h_not]

/-- 
  THEOREM: Ex-Ante Assessment Uses Prediction.
  When t ≤ t_0, dynamic assessment evaluates purely predictive counterfactuals.
-/
theorem ex_ante_uses_prediction (t t_0 : Int) (pr_act me_act pr_ctrl : Int) (th : Threshold)
    (h_ante : t ≤ t_0) :
    dynamic_assessment t t_0 pr_act me_act pr_ctrl th = 
    norm_assessment (pr_act - pr_ctrl) th := by
  unfold dynamic_assessment
  simp [h_ante]

/-- Helper constructor for Assessments. -/
def Assessment.mkSimple (id : String) (act : Action) (t t_0 : Int) (th : Threshold) 
    (actOut ctrlOut : Int) : Assessment :=
  { toThing := Thing.mkSimple id s!"assessment_{id}" th.context.domain.name (if t ≥ 0 then t.toNat else 0),
    action := act,
    timestamp := t,
    executionHorizon := t_0,
    threshold := th,
    actionOutcome := actOut,
    counterfactual := ctrlOut,
    normalizedDelta := norm_assessment (actOut - ctrlOut) th,
    h_normalized := rfl }

/-- 
  [P] Design requirement: Non-circular empirical marker grounding.
  Markers are empirical by construction (`m.h_empirical : m.origin.isEmpirical = true`).
  This syntactically excludes direct circular dependency on another MetricModel's output.
  NOTE: This structural condition does NOT resolve Goodhart's Law; preventing proxy gaming
  requires distinguishing latent ground truth from noisy observed markers, which is handled
  via metric model competition and adversarial auditing.
  Corresponds to: Bf_Pseudocode.txt L46-50.
-/
structure EmpiricalMarkerRequirement (m : Marker) where
  marker_is_empirical : m.origin.isEmpirical = true := m.h_empirical

/-- Syntactic anti-circularity: an empirical marker origin cannot equal a synthetic model output. -/
theorem empirical_marker_not_model_output (m : Marker) (modelId : String)
    (req : EmpiricalMarkerRequirement m) :
    m.origin ≠ .MetricModelOutput modelId := by
  intro h_eq
  have h_emp := req.marker_is_empirical
  rw [h_eq] at h_emp
  contradiction

/-- Metric model non-circularity follows directly from the empirical marker design requirement. -/
theorem metric_models_are_non_circular (_mm : MetricModel) (m : Marker) (_hm : m ∈ _mm.markers)
    (req : EmpiricalMarkerRequirement m) :
    m.origin.isEmpirical = true :=
  req.marker_is_empirical

abbrev MM := MetricModel
abbrev M := Marker
abbrev As := Assessment
abbrev CorrSc := compute_model_score

end Benefuture.Measurement

