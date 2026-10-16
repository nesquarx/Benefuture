/-
  Benefuture.Measurement.Threshold
  Formalization of Threshold of Significance (Th ∈ T), Graded Significance, 
  Contextual Normalization, and Significant Threshold Governance (SigThGv).
  Corresponds to: Bf_Pseudocode.txt L25, L48, L157, L171, and Threshold of significance.txt
  
  "Threshold«Th»(Pm_i, Context«Cx») := (Pm_i ≥ Th_Cx) ⇒ Sig(Pm, Cx), (graded, multidimensional, nuanced);"
  "SigThGv := Ap(Th ∈ Debatable? LqdBfDm : Perturb(Th ± δ ∈ Fr));"
  "A threshold is also the unit in which an assessed change is expressed: the difference 
   an action makes is scaled by the threshold of significance of its context..."
-/

import Benefuture.Math.Order
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Domain
import Benefuture.Epistemology.Context

namespace Benefuture.Measurement

open Benefuture.Math
open Benefuture.Ontology
open Benefuture.Epistemology

/-- 
  Threshold of Significance (Th ∈ T):
  An understood, context-dependent value beyond which any metric starts affecting a decision.
  Corresponds to: Bf_Pseudocode.txt L25, Threshold of significance.txt L2-12.
-/
structure Threshold extends Thing where
  parameterName    : String
  context          : Context
  baseCutoff       : Int  -- Value beyond which parameter becomes significant
  marginWidth      : Int  -- Margin width for graded, smooth transitions
  isDebatable      : Bool -- Whether threshold is open to democratic debate (LqdBfDm)
  freedomAllowance : Int  -- Permissible perturbation radius δ ∈ Freedom
  h_cutoff_pos     : 0 < baseCutoff
  h_margin_nonneg  : 0 ≤ marginWidth
  h_freedom_nonneg : 0 ≤ freedomAllowance
  h_freedom_safe   : freedomAllowance < baseCutoff -- Controlled variance cannot invert threshold
  deriving Repr

/-- Coercion: Every Threshold is canonically a Thing in Reality. -/
instance : Coe Threshold Thing where
  coe th := th.toThing

/-- Theorem: Threshold inclusion Th ∈ T holds by construction. -/
theorem threshold_is_thing (th : Threshold) : (th : Thing).id = th.id := rfl

/-- 
  Binary significance predicate:
  (Pm_i ≥ Th_Cx) ⇒ Sig(Pm, Cx).
-/
def is_significant (val : Int) (th : Threshold) : Bool :=
  val ≥ th.baseCutoff

/-- 
  Graded Significance Evaluation:
  Computes a continuous, graded significance in [0, SCALE] rather than a naive step function.
  If marginWidth = 0, behaves as exact step. Otherwise ramps linearly from 0 to SCALE.
-/
def graded_significance (val : Int) (th : Threshold) : Int :=
  if th.marginWidth = 0 then
    if val ≥ th.baseCutoff then SCALE else 0
  else
    let lower := th.baseCutoff - th.marginWidth
    let upper := th.baseCutoff + th.marginWidth
    if val ≤ lower then
      0
    else if val ≥ upper then
      SCALE
    else
      -- Linear interpolation across the 2 * marginWidth interval
      let num := (val - lower) * SCALE
      let den := 2 * th.marginWidth
      num / den

/-- 
  Contextual Assessment Normalization:
  An assessed change ΔAs is scaled and expressed in units of the threshold of significance
  of its context: ΔAs_norm = (ΔAs * SCALE) / Th_Cx.
  Corresponds to: Bf_Pseudocode.txt L48, Threshold of significance.txt L10.
-/
def norm_assessment (delta : Int) (th : Threshold) : Int :=
  (delta * SCALE) / th.baseCutoff

/-- 
  Significant Threshold Governance Mode (SigThGv):
  Debatable thresholds are put to Liquid Benefuture Democracy (LqdBfDm);
  non-debatable thresholds undergo controlled evolutionary perturbation (Perturb(Th ± δ ∈ Fr)).
  Corresponds to: Bf_Pseudocode.txt L157, Threshold of significance.txt L9.
-/
inductive ThresholdGovMode where
  | LiquidDemocracyDebate : ThresholdGovMode
  | ControlledPerturbation : ThresholdGovMode
  deriving Repr, DecidableEq

/-- Selector for Threshold Governance mode. -/
def threshold_governance_selector (th : Threshold) : ThresholdGovMode :=
  if th.isDebatable then
    .LiquidDemocracyDebate
  else
    .ControlledPerturbation

/-- 
  Apply Controlled Perturbation within Freedom limits (Perturb(Th ± δ ∈ Fr)):
  Clamps delta to [-freedomAllowance, freedomAllowance].
-/
def apply_perturbation (th : Threshold) (delta : Int) : Threshold :=
  let clamped_delta := 
    if delta > th.freedomAllowance then th.freedomAllowance
    else if delta < -th.freedomAllowance then -th.freedomAllowance
    else delta
  let new_cutoff := th.baseCutoff + clamped_delta
  { toThing := th.toThing,
    parameterName := th.parameterName,
    context := th.context,
    baseCutoff := new_cutoff,
    marginWidth := th.marginWidth,
    isDebatable := th.isDebatable,
    freedomAllowance := 0,
    h_cutoff_pos := by
      have hsafe := th.h_freedom_safe
      have hpos := th.h_cutoff_pos
      have hfnonneg := th.h_freedom_nonneg
      dsimp [clamped_delta, new_cutoff]
      split
      · omega
      · split
        · omega
        · omega,
    h_margin_nonneg := th.h_margin_nonneg,
    h_freedom_nonneg := by decide,
    h_freedom_safe := by
      have hsafe := th.h_freedom_safe
      have hpos := th.h_cutoff_pos
      have hfnonneg := th.h_freedom_nonneg
      dsimp [clamped_delta, new_cutoff]
      split
      · omega
      · split
        · omega
        · omega }

/-- 
  THEOREM: Perturbed Threshold Positivity Theorem.
  Perturbing any threshold within its freedom allowance δ ∈ Fr is guaranteed 
  to preserve strict positivity of the cutoff: 0 < (apply_perturbation th delta).baseCutoff.
-/
theorem perturbed_threshold_remains_positive (th : Threshold) (delta : Int) :
    0 < (apply_perturbation th delta).baseCutoff :=
  (apply_perturbation th delta).h_cutoff_pos

/-- 
  Helper constructor for standard thresholds.
-/
def Threshold.mkSimple (id name : String) (cx : Context) (cutoff : Int) 
    (h_pos : 0 < cutoff) (margin : Int := 0) (h_m : 0 ≤ margin := by decide)
    (debatable : Bool := true) (freedom : Int := 0) 
    (h_f : 0 ≤ freedom := by decide) (h_safe : freedom < cutoff := by omega) : Threshold :=
  { toThing := Thing.mkSimple id s!"threshold_{name}" cx.domain.name 0,
    parameterName := name,
    context := cx,
    baseCutoff := cutoff,
    marginWidth := margin,
    isDebatable := debatable,
    freedomAllowance := freedom,
    h_cutoff_pos := h_pos,
    h_margin_nonneg := h_m,
    h_freedom_nonneg := h_f,
    h_freedom_safe := h_safe }

abbrev Th := Threshold
abbrev Sig := is_significant

end Benefuture.Measurement

