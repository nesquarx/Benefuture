/-
  Benefuture.Epistemology.Prediction
  Formalization of Prediction (Pr ∈ T), Proper Scoring (PrAcc), and Sapience (Sp ∈ T).
  Corresponds to: Bf_Pseudocode.txt L27, L33, L165, and Sapience.txt / Measurement.txt
  
  "Predict«Pr»(I), PrAcc(Pr) := Proper(Pr, ℝ);"
  "Sapience«Sp» := U & Pr(I);"
  "Sapience is the ability to understand any thing and maximise the accuracy 
   of prediction of the thing interacting any other thing (especially reality)."
-/

import Benefuture.Math.Order
import Benefuture.Ontology.Thing
import Benefuture.Ontology.Reality
import Benefuture.Ontology.Entity
import Benefuture.Epistemology.Context

namespace Benefuture.Epistemology

open Benefuture.Math
open Benefuture.Ontology

/-- 
  Prediction (Pr ∈ T):
  A probabilistic forecast or model output predicting future states in Reality (t > 0).
  Corresponds to: Bf_Pseudocode.txt L27.
-/
structure Prediction extends Thing where
  forecastTime    : Int    -- Projected future timestamp (0 < forecastTime)
  targetSubject   : Thing  -- Entity or process being forecasted
  predictedValue  : Int    -- Expected metric value scaled in micro-units
  confidence      : Int    -- Forecast subjective probability [0, SCALE]
  h_future_time   : 0 < forecastTime
  h_conf_nonneg   : 0 ≤ confidence
  h_conf_bound    : confidence ≤ SCALE
  deriving Repr

/-- Coercion: Every Prediction is canonically a Thing in Reality. -/
instance : Coe Prediction Thing where
  coe pr := pr.toThing


/-- 
  Proper Scoring Rule (Brier Accuracy) in Reality (ℝ):
  PrAcc(Pr) := Proper(Pr, ℝ).
  Scores prediction against observed reality outcome x.
  Maximal score = SCALE (1.0) when error = 0.
-/
def compute_brier_accuracy (forecast actual : Int) : Int :=
  let err := (forecast - actual)
  let errSq := (err * err) / SCALE
  if errSq ≥ SCALE then 0 else SCALE - errSq

/-- 
  THEOREM: Perfect Prediction Achieves Maximum Accuracy.
  When forecast matches actual outcome identically, accuracy is exactly SCALE (1.0).
-/
theorem perfect_prediction_achieves_scale (val : Int) :
    compute_brier_accuracy val val = SCALE := by
  unfold compute_brier_accuracy
  have herr : val - val = 0 := by omega
  simp [herr]
  decide

/-- 
  Sapience (Sp ∈ T):
  The synthesis of verified Understanding (U) and Predictive Accuracy (Pr(I)):
  Sapience«Sp» := U & Pr(I).
  Corresponds to: Bf_Pseudocode.txt L33, Sapience.txt L2-8.
-/
structure Sapience extends Thing where
  understandingScore : Int  -- General and pragmatic understanding level [0, SCALE]
  predictiveAccuracy : Int  -- Proper score on empirical prediction tests [0, SCALE]
  h_u_nonneg         : 0 ≤ understandingScore
  h_u_bound          : understandingScore ≤ SCALE
  h_pr_nonneg        : 0 ≤ predictiveAccuracy
  h_pr_bound         : predictiveAccuracy ≤ SCALE
  deriving Repr

/-- Coercion: Every Sapience instance is canonically a Thing in Reality. -/
instance : Coe Sapience Thing where
  coe sp := sp.toThing


/-- 
  Sapience Index:
  The joint geometric / product metric Sp = (U * PrAcc) / SCALE.
  Reflects that understanding without prediction is untested dogma,
  and prediction without understanding is brittle black-box heuristic.
-/
def sapience_index (sp : Sapience) : Int :=
  (sp.understandingScore * sp.predictiveAccuracy) / SCALE

/-- 
  THEOREM: Sapience Index Non-Negativity and Boundedness.
-/
theorem sapience_index_bounded (sp : Sapience) :
    0 ≤ sapience_index sp ∧ sapience_index sp ≤ SCALE := by
  unfold sapience_index
  have hu := sp.h_u_nonneg
  have hpr := sp.h_pr_nonneg
  have hu_b := sp.h_u_bound
  have hpr_b := sp.h_pr_bound
  have hmul_nonneg : 0 ≤ sp.understandingScore * sp.predictiveAccuracy := Int.mul_nonneg hu hpr
  have h1 : sp.understandingScore * sp.predictiveAccuracy ≤ sp.understandingScore * SCALE := 
    Int.mul_le_mul_of_nonneg_left hpr_b hu
  have h2 : sp.understandingScore * SCALE ≤ SCALE * SCALE := 
    Int.mul_le_mul_of_nonneg_right hu_b (by unfold SCALE; decide)
  have hmul_bound : sp.understandingScore * sp.predictiveAccuracy ≤ SCALE * SCALE := 
    Int.le_trans h1 h2
  have hdiv_le : (sp.understandingScore * sp.predictiveAccuracy) / SCALE ≤ (SCALE * SCALE) / SCALE :=
    Int.ediv_le_ediv (by unfold SCALE; decide) hmul_bound
  have hcancel : (SCALE * SCALE) / SCALE = SCALE := by unfold SCALE; decide
  rw [hcancel] at hdiv_le
  constructor
  · exact Int.ediv_nonneg hmul_nonneg (by unfold SCALE; decide)
  · exact hdiv_le

abbrev Pr := Prediction
abbrev PrAcc := compute_brier_accuracy
abbrev Sp := Sapience

end Benefuture.Epistemology

