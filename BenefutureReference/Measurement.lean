/-
  BenefutureReference.Measurement
  Computable reference for metric-model competition (L49), over Float, by predictive accuracy
  alone; correlation, causal explanation and novelty are not yet scored.
-/

namespace BenefutureReference

/--
  Accuracy score of a metric model: minus the mean squared error of its predictions against
  observations (a proper score for point predictions; higher is better, 0 is perfect).
  0 when there is nothing to score.
-/
def mm_score_ref (pred obs : Array Float) : Float := Id.run do
  let n := min pred.size obs.size
  if n == 0 then return 0.0
  let mut sse := 0.0
  for i in [0:n] do
    let e := pred[i]! - obs[i]!
    sse := sse + e * e
  return -(sse / n.toFloat)

/-- Adopted metric model: the first of highest score; 0 for an empty field. -/
def mm_adopt_ref (scores : Array Float) : Nat := Id.run do
  let mut best := 0
  for i in [0:scores.size] do
    if scores[i]! > scores[best]! then best := i
  return best

end BenefutureReference
