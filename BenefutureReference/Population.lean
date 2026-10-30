/-
  BenefutureReference.Population
  Computable reference for population change (M7): the value of a life a plan ends or saves
  (author ruling 8.47, [P] reading), and births (author ruling 8.52, [P] reading): the level a
  newborn counts at in G's floors and the escrow its causers post. The long-term window, the
  breakthrough scale, the optimistic quantile, the confidence threshold, the dependency window and
  the baseline are governed thresholds.
-/

import BenefutureReference.Goal

namespace BenefutureReference

/-- A life's foreclosed future over the long-term window (8.47 [P]; L70, the self over `Ha_lt`):
    the understanding and happiness the being holds, plus the growth its models predict for it over
    `window` steps. Levels below zero and negative growth count as nothing foreclosed. -/
def foreclosed_ref (u h growthU growthH window : Float) : Float :=
  max 0 u + max 0 h + max 0 window * (max 0 growthU + max 0 growthH)

/-- Value on a being whose life a plan ends or, against not acting, saves (8.47 [P]; L61, the
    irreparable tier; L73): its foreclosed future, weighted by the irreparable tier's priority and the
    breakthrough scale. A life saved is irreparable harm prevented and counts as much as a life ended,
    so redirecting harm so that fewer die is preferred (the standard trolley rules); ordinary gains,
    valued by V at their own size, outweigh a death only past `scale` times its weighted foreclosed
    future (a breakthrough-scale gain). -/
def life_value_ref (foreclosed tierWeight scale : Float) (saved : Bool) : Float :=
  (if saved then 1.0 else -1.0) * max 0 scale * max 0 tierWeight * max 0 foreclosed

/-- The optimistic average of a model pool's predictions (8.52 [P]): the mean of the predictions at or
    above the pool's lower q-quantile (`floor_quantile_ref`). q = 0 is the plain mean, q = 1 the most
    optimistic prediction. 0 for an empty pool. -/
def optimistic_average_ref (preds : Array Float) (q : Float) : Float :=
  if preds.size == 0 then 0.0
  else
    let cut := floor_quantile_ref preds q
    let top := preds.filter (· ≥ cut)
    top.foldl (· + ·) 0.0 / top.size.toFloat

/-- The level a newborn counts at in G's floors (8.52 [P]): the pool's optimistic average when the
    pool's confidence reaches `threshold`, else its initial level (a fresh low). -/
def birth_level_ref (preds : Array Float) (q confidence threshold initial : Float) : Float :=
  if confidence ≥ threshold then optimistic_average_ref preds q else initial

/-- Shortfall of a trajectory below a baseline: Σ max(0, baseline − level). -/
def shortfall_ref (levels : Array Float) (baseline : Float) : Float :=
  levels.foldl (fun acc x => acc + max 0 (baseline - x)) 0.0

/-- The trajectory a prediction implies over the dependency window: from the initial level, linearly,
    reaching the predicted level at step `window`; one level per step. -/
def birth_trajectory_ref (initial predicted : Float) (window : Nat) : Array Float :=
  (List.range window).toArray.map fun t =>
    initial + (predicted - initial) * (t + 1).toFloat / window.toFloat

/-- The birth escrow (8.52 [P]), posted by those causing the birth: the predicted shortfall below the
    baseline over the dependency window, along the trajectory from the initial level to the predicted
    one. It settles against the measured shortfall like any escrow (`settlement_ref`). -/
def birth_escrow_ref (initial predicted : Float) (window : Nat) (baseline : Float) : Float :=
  shortfall_ref (birth_trajectory_ref initial predicted window) baseline

end BenefutureReference
