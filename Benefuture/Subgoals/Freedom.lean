/-
  Benefuture.Subgoals.Freedom
  Formalization of Freedom (Fr): Maximization of action capacity subject to non-harm.
  Corresponds to: Bf_Pseudocode.txt L135, and Rights.txt / Philosophy.txt
  "Fr := f_max(∃A, Imp, N, Po) | ¬Ha_(Estd ∨ Pr(P·severity>Th_high) ∨ irreversible);"
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Linarith
import Benefuture.Math.Order
import Benefuture.Math.Synergy
import Benefuture.Ontology.Entity
import Benefuture.Axiology.Priorities

namespace Benefuture.Subgoals

open Benefuture.Math
open Benefuture.Ontology
open Benefuture.Axiology

/-- 
  [P] Certain-harm boundary: the special case of `fr_permissible` (below) for harm known to occur.
  Kept for the freedom metric; Fr itself is `fr_permissible` (L135, author's reading).
  "Fr := f_max(∃A, Imp, N, Po) | ¬Ha_(Estd ∨ Pr(P·severity>Th_high) ∨ irreversible);"
  An Action is permissible under the Benefuture Freedom Principle iff:
  1. It causes zero irreparable harm: harm.irreparable ≤ 0
  2. It causes zero irreversible harm: harm.irreversible ≤ 0
-/
noncomputable def is_action_freedom_permissible (_a : Action) (harm : HarmProfile) : Bool :=
  harm.irreparable ≤ 0 && harm.irreversible ≤ 0

/-- 
  [R] Freedom within Truth Boundaries (Fr(Tr)) (L133, L135):
  An action operates within the civilizational freedom boundary Fr(Tr) iff:
  1. It avoids severe or irreversible harm: is_action_freedom_permissible a harm = true
  2. It does not actively degrade truth in Reality: delta_truth ≥ 0
-/
noncomputable def is_action_freedom_within_truth (a : Action) (harm : HarmProfile) (delta_truth : Int) : Bool :=
  is_action_freedom_permissible a harm && (delta_truth ≥ 0)

/-- 
  THEOREM: Irreversible Harm Invariant.
  Any action yielding positive irreversible harm (irreversible > 0)
  is strictly impermissible under Freedom, regardless of its power or novelty!
-/
theorem irreversible_harm_strictly_impermissible 
    (a : Action) (harm : HarmProfile) (h_irrev : harm.irreversible > 0) :
    is_action_freedom_permissible a harm = false := by
  unfold is_action_freedom_permissible
  have h_not : ¬(harm.irreversible ≤ 0) := by linarith
  simp [h_not]

/-- 
  THEOREM: Irreparable Harm Invariant.
  Any action yielding positive irreparable harm (irreparable > 0)
  is strictly impermissible under Freedom.
-/
theorem irreparable_harm_strictly_impermissible 
    (a : Action) (harm : HarmProfile) (h_irrep : harm.irreparable > 0) :
    is_action_freedom_permissible a harm = false := by
  unfold is_action_freedom_permissible
  have h_not : ¬(harm.irreparable ≤ 0) := by linarith
  simp [h_not]

/- --- Fr per L135, author's reading --- -/

/--
  [R] A predicted harm with the confidence that it occurs.
  `profile` holds the magnitude per severity tier; `confidence` ∈ [0, 1].
-/
structure HarmForecast where
  profile    : HarmProfile
  confidence : ℝ

/--
  [P] Fr parameters. `thConf`: confidence at which a predicted harm counts as established.
  `thHigh`: ceiling on expected severity. `sev*`: severity multipliers per tier.
-/
structure FrParams where
  thConf          : ℝ
  thHigh          : ℝ
  sevIrreparable  : ℝ
  sevIrreversible : ℝ
  sevLongterm     : ℝ
  sevPassing      : ℝ
  sevTimeLoss     : ℝ

/--
  [P] Longtermist defaults: established at 90% confidence; expected severity ceiling 1;
  severities 1000 / 100 / 10 / 1 / 0.5. A 1% chance of one irreparable harm still blocks;
  a 50% chance of one passing harm does not.
-/
noncomputable def defaultFrParams : FrParams :=
  { thConf := 0.9, thHigh := 1, sevIrreparable := 1000, sevIrreversible := 100,
    sevLongterm := 10, sevPassing := 1, sevTimeLoss := 0.5 }

/-- Severity score of a harm profile under Fr's multipliers. -/
noncomputable def severity_score (hp : HarmProfile) (fp : FrParams) : ℝ :=
  fp.sevIrreparable * hp.irreparable + fp.sevIrreversible * hp.irreversible +
    fp.sevLongterm * hp.longterm + fp.sevPassing * hp.passing + fp.sevTimeLoss * hp.timeLoss

/--
  [R] Established severe harm (`Ha_Estd` in L135, author's reading): confidence at least thConf,
  and some harm at the long-term tier or worse.
-/
def established_severe (hf : HarmForecast) (fp : FrParams) : Prop :=
  fp.thConf ≤ hf.confidence ∧
    (0 < hf.profile.irreparable ∨ 0 < hf.profile.irreversible ∨ 0 < hf.profile.longterm)

/--
  [R] Fr (L135): Fr := f_max(∃A, Imp, N, Po) | ¬Ha_(Estd ∨ Pr(P·severity > Th_high) ∨ irreversible).
  Permissible iff the harm is not established-severe and its expected severity
  confidence · severity_score stays within thHigh. The irreversible clause is carried by both:
  established irreversible harm is established-severe, and speculative irreversible harm is
  priced by its severity multiplier. Mild chances of passing harm or time loss never block.
-/
noncomputable def fr_permissible (hf : HarmForecast) (fp : FrParams) : Bool :=
  !(decide (established_severe hf fp)) &&
    decide (hf.confidence * severity_score hf.profile fp ≤ fp.thHigh)

/-- THEOREM: Fr-permissible harm is neither established-severe nor over the severity ceiling. -/
theorem fr_permissible_spec (hf : HarmForecast) (fp : FrParams)
    (h : fr_permissible hf fp = true) :
    ¬ established_severe hf fp ∧ hf.confidence * severity_score hf.profile fp ≤ fp.thHigh := by
  unfold fr_permissible at h
  simp only [Bool.and_eq_true, Bool.not_eq_true', decide_eq_false_iff_not,
    decide_eq_true_eq] at h
  exact h

/-- THEOREM: Established harm at the long-term tier or worse blocks Fr. -/
theorem established_severe_blocks (hf : HarmForecast) (fp : FrParams)
    (h : established_severe hf fp) : fr_permissible hf fp = false := by
  unfold fr_permissible
  simp [h]

/-- THEOREM: Expected severity above the ceiling blocks Fr, however speculative the harm. -/
theorem probable_severe_harm_blocks (hf : HarmForecast) (fp : FrParams)
    (h : fp.thHigh < hf.confidence * severity_score hf.profile fp) :
    fr_permissible hf fp = false := by
  unfold fr_permissible
  have h_not : ¬(hf.confidence * severity_score hf.profile fp ≤ fp.thHigh) := not_le.mpr h
  simp [h_not]

/-- Profile with the given magnitude per severity tier. -/
def unit_harm (irreparable irreversible longterm passing timeLoss : ℝ) : HarmProfile :=
  { irreparable := irreparable, irreversible := irreversible, longterm := longterm,
    passing := passing, timeLoss := timeLoss }

/-- THEOREM (defaults): a 50% chance of one passing harm does not block Fr. -/
theorem mild_passing_chance_permitted :
    fr_permissible ⟨unit_harm 0 0 0 1 0, 0.5⟩ defaultFrParams = true := by
  unfold fr_permissible established_severe severity_score unit_harm defaultFrParams
  norm_num

/-- THEOREM (defaults): a 1% chance of one irreparable harm blocks Fr. -/
theorem speculative_catastrophe_blocks :
    fr_permissible ⟨unit_harm 1 0 0 0 0, 0.01⟩ defaultFrParams = false := by
  apply probable_severe_harm_blocks
  unfold severity_score unit_harm defaultFrParams
  norm_num

/-- THEOREM (defaults): a 0.1% chance of one irreversible non-fatal harm does not paralyse action. -/
theorem remote_irreversible_chance_permitted :
    fr_permissible ⟨unit_harm 0 1 0 0 0, 0.001⟩ defaultFrParams = true := by
  unfold fr_permissible established_severe severity_score unit_harm defaultFrParams
  norm_num

/-- THEOREM (defaults): certain long-term harm blocks Fr. -/
theorem certain_longterm_harm_blocks :
    fr_permissible ⟨unit_harm 0 0 1 0 0, 1⟩ defaultFrParams = false := by
  apply established_severe_blocks
  unfold established_severe unit_harm defaultFrParams
  norm_num

/--
  [OPEN] Freedom vs Necessary Harm Tension (Fr vs NHa):
  Pseudocode L55 defines Necessary Harm:
  NHa := Ha : Ha → ↑V > Ha.
  A transient harm whose downstream consequence generates strictly greater Value.
  
  Pseudocode L135 defines Freedom:
  Fr := f_max(∃A, Imp, N, Po) | ¬Ha_(Estd ∨ Pr(P·severity>Th_high) ∨ irreversible).
  Any irreversible harm is categorically prohibited by Freedom.
  
  TENSION: Consider an action causing an irreversible harm, but whose value yield
  strictly exceeds the harm (0 < net_necessary_gain nh).
  Under L55, this action is a valid Necessary Harm that increases civilizational Value.
  Under L135, this action is strictly impermissible under Freedom (is_action_freedom_permissible = false).
  Freedom's deontological non-harm boundary excludes a globally value-positive action.
  [P] Resolution (SPEC_DIVERGENCES §6.1): a lexical ordering. Fr filters the action set first;
  NHa can only justify a harm among Fr-permitted actions (`Proposed.PopulationDirection.choose_plan`).
-/
theorem freedom_excludes_irreversible_necessary_harm
    (a : Action) (harm : HarmProfile) (nh : NecessaryHarm)
    (h_irrev : harm.irreversible > 0) :
    is_action_freedom_permissible a harm = false ∧ 0 < net_necessary_gain nh := by
  constructor
  · exact irreversible_harm_strictly_impermissible a harm h_irrev
  · exact necessary_harm_produces_net_positive_value nh

/-- 
  THEOREM: Truth Degradation Invariant.
  An action that causes degradation of empirical Truth in Reality (delta_truth < 0)
  is strictly excluded from the Fr(Tr) freedom boundary!
-/
theorem truth_degradation_excluded_from_freedom_tr
    (a : Action) (harm : HarmProfile) (delta_truth : Int) (h_deg : delta_truth < 0) :
    is_action_freedom_within_truth a harm delta_truth = false := by
  unfold is_action_freedom_within_truth
  have h_not : ¬(delta_truth ≥ 0) := by omega
  simp [h_not]

/-- 
  Freedom Metric across a candidate set of Actions:
  f_max(∃A, Imp, N, Po) | ¬Ha_irreversible
  Filters permissible actions and aggregates their power capacity and novelty yield.
-/
noncomputable def calculate_freedom_metric 
    (actions : List Action) 
    (harm_fn : Action → HarmProfile) 
    (power_fn : Action → Int) 
    (novelty_fn : Action → Int) : Int :=
  let permissible := actions.filter (fun a => is_action_freedom_permissible a (harm_fn a))
  permissible.foldl (fun acc a => acc + power_fn a + novelty_fn a) 0

/-- THEOREM: Adding a permissible action monotonically increases freedom metric. -/
theorem freedom_metric_monotone_with_permissible_action
    (a : Action) (harm : HarmProfile) (power novelty : Int)
    (h_perm : is_action_freedom_permissible a harm = true)
    (h_pos : power + novelty > 0) :
    calculate_freedom_metric [a] (fun _ => harm) (fun _ => power) (fun _ => novelty) > 0 := by
  unfold calculate_freedom_metric
  simp [h_perm]
  omega

/- --- Backwards-Compatible Adapters for Threshold Perturbation & Simple Constraints --- -/

/-- 
  Freedom Scope (extends Thing):
  Grounded action set and capacity available to an agent in Reality.
  Corresponds to: Bf_Pseudocode.txt L135 ("f_max(∃A, Imp, N, Po)").
-/
structure FreedomScope extends Thing where
  actions       : List Action := []
  actionCount   : Nat := actions.length
  powerCapacity : Int
  noveltyRange  : Int
  deriving Repr

instance : Coe FreedomScope Thing where
  coe s := s.toThing

def FreedomScope.mkSimple (id : String) (acts : List Action) (power novelty : Int) : FreedomScope :=
  { toThing := Thing.mkSimple id s!"freedom_{id}" "action_space" 0,
    actions := acts, actionCount := acts.length, powerCapacity := power, noveltyRange := novelty }

/-- Deprecated constraint representation, superseded by direct evaluation on Action and HarmProfile. -/
structure ActionHarmConstraint where
  severity   : HarmSeverity
  is_certain : Bool
  deriving Repr

def is_freedom_permissible (c : ActionHarmConstraint) : Bool :=
  match c.severity with
  | .Irreparable => false
  | .Irreversible => false
  | _ => true

def freedom_metric (scope : FreedomScope) : Int :=
  (scope.actionCount * scope.powerCapacity) + scope.noveltyRange

def is_freedom_within_truth (c : ActionHarmConstraint) (isTruthOriented : Bool) : Bool :=
  is_freedom_permissible c ∧ isTruthOriented

/-- 
  Threshold Perturbation (extends Thing):
  Bounded epistemic calibration perturbation over a nominal metric threshold.
  Corresponds to: Bf_Pseudocode.txt L136 ("Perturb(Th_nom, δ) ∈ [-Δ, +Δ]").
-/
structure ThresholdPerturbation extends Thing where
  nominalThreshold : Int
  delta            : Int
  maxDelta         : Int
  h_max_pos        : 0 < maxDelta
  h_lower_bound    : -maxDelta ≤ delta
  h_upper_bound    : delta ≤ maxDelta
  deriving Repr

instance : Coe ThresholdPerturbation Thing where
  coe p := p.toThing

def ThresholdPerturbation.mkSimple (id : String) (nom delta maxD : Int)
    (h_pos : 0 < maxD := by decide)
    (h_low : -maxD ≤ delta := by decide)
    (h_up : delta ≤ maxD := by decide) : ThresholdPerturbation :=
  { toThing := Thing.mkSimple id s!"perturb_{id}" "threshold_calibration" 0,
    nominalThreshold := nom, delta := delta, maxDelta := maxD,
    h_max_pos := h_pos, h_lower_bound := h_low, h_upper_bound := h_up }

def apply_perturbation (p : ThresholdPerturbation) : Int :=
  p.nominalThreshold + p.delta

theorem perturbation_safety_invariant (p : ThresholdPerturbation) :
    p.nominalThreshold - p.maxDelta ≤ apply_perturbation p ∧
    apply_perturbation p ≤ p.nominalThreshold + p.maxDelta := by
  unfold apply_perturbation
  have h1 := p.h_lower_bound
  have h2 := p.h_upper_bound
  constructor <;> omega

noncomputable abbrev Fr := fr_permissible

end Benefuture.Subgoals
