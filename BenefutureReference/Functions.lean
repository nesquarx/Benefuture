/-
  BenefutureReference.Functions
  Computable Float-based reference implementation of Benefuture core operators.
  MANDATORY REQUIREMENT: ZERO imports from Mathlib, ZERO imports from Benefuture spec library.
  Only Lean 4 core language and standard library.
-/

namespace BenefutureReference

/-- Sum of list of Floats. -/
def sumFloat (xs : List Float) : Float :=
  xs.foldl (· + ·) 0.0

/-- Helper to compute cross pairs (i < j) from a list. -/
def crossPairs {α : Type} : List α → List (α × α)
  | [] => []
  | x :: xs => (xs.map (fun y => (x, y))) ++ crossPairs xs

/--
  Reference calculation of synergy potential Φ_s for a branch (positive or negative).
  Corresponds to: Bf_Pseudocode.txt L13.
  items: list of (magnitude a_i, weight w_i).
-/
def phi_ref (items : List (Float × Float)) (q : Float) (kappa : Float) : Float :=
  let linearTerms := items.map (fun (a, w) => w * (a.pow q))
  let linearSum := sumFloat linearTerms
  let pairs := crossPairs items
  let crossTerms := pairs.map (fun ((a1, w1), (a2, w2)) =>
    w1 * w2 * ((a1 * a2).pow q))
  let crossSum := sumFloat crossTerms
  let synergyBoost := kappa * (crossSum.sqrt)
  linearSum + synergyBoost

/--
  Reference calculation of net synergy Sy.
  Corresponds to: Bf_Pseudocode.txt L13.
-/
def Sy_ref (posItems : List (Float × Float)) (negItems : List (Float × Float))
    (lambda : Float) (kappa : Float) (qPlus : Float) (qMinus : Float) : Float :=
  let phiPlus := phi_ref posItems qPlus kappa
  let phiMinus := phi_ref negItems qMinus kappa
  let denom := phiPlus + phiMinus
  if denom == 0.0 then
    0.0
  else
    phiPlus - phiMinus - lambda * ((phiPlus * phiMinus) / denom)

/--
  Reference calculation of squashed synergy Ŝy.
  Corresponds to: Bf_Pseudocode.txt L14.
-/
def Sy_hat_ref (s : Float) (nu : Float) (h : Float) : Float :=
  if s == 0.0 then
    0.0
  else
    let sign := if s > 0.0 then 1.0 else -1.0
    let absS := if s < 0.0 then -s else s
    let num := absS.pow nu
    let den := num + (h.pow nu)
    if den == 0.0 then
      0.0
    else
      sign * (num / den)

/--
  Reference calculation of Dynamic Assessment As.
  Corresponds to: Bf_Pseudocode.txt L48.
  If t > t0 (ex-post), returns measured empirical delta;
  otherwise (ex-ante), returns predicted delta minus counterfactual.
-/
def As_ref (predicted : Float) (counter : Float) (measured : Float) (t : Float) (t0 : Float) : Float :=
  if t > t0 then
    measured
  else
    predicted - counter

/--
  Reference calculation of Tiered Value V over Understanding (U), Harm (H), and Novelty (N).
  Corresponds to: Bf_Pseudocode.txt L73.
-/
def V_ref (u : Float) (h : Float) (n : Float)
    (alpha : Float) (beta : Float) (gamma : Float) (ha_wt : Float)
    (lambda : Float) (kappa : Float) (qPlus : Float) (qMinus : Float) : Float :=
  let posItems := [(u, 1.0), (n, gamma)]
  let negItems := [(h, beta * alpha * ha_wt)]
  Sy_ref posItems negItems lambda kappa qPlus qMinus

/--
  Reference calculation of Escrow Fund Splitting:
  Returns (upfrontPayout, ongoingHold, protocolOverhead).
  Corresponds to: Bf_Pseudocode.txt L26, L157.
-/
def Escrow_split_ref (nominal : Float) (pWin : Float) (overheadRate : Float) : Float × Float × Float :=
  let overhead := nominal * overheadRate
  let distributable := nominal - overhead
  let upfront := distributable * pWin
  let hold := distributable * (1.0 - pWin)
  (upfront, hold, overhead)

/--
  Reference calculation of continuous lazy reputation decay.
  Corresponds to: Bf_Pseudocode.txt L101.
-/
def Rep_decay_ref (cachedScore : Float) (dt : Float) (lambdaDecay : Float) : Float :=
  if dt <= 0.0 then
    cachedScore
  else
    cachedScore * (Float.exp (-lambdaDecay * dt))

/--
  Reference calculation of Parent Domain Aggregation.
  Corresponds to: Bf_Pseudocode.txt L21-22.
  Computes weighted dot product: ∑ w_i * v_i.
-/
def Parent_aggregate_ref (leafValues : List Float) (weights : List Float) : Float :=
  let pairs := leafValues.zip weights
  sumFloat (pairs.map (fun (v, w) => v * w))

/--
  Reference calculation of EHR anti-collusion cyclic attenuation.
  Corresponds to: Bf_Pseudocode.txt L117.
-/
def EHR_attenuate_ref (rawWeight : Float) (cycleOverlap : Float) : Float :=
  let discount := if cycleOverlap < 0.0 then 0.0 else if cycleOverlap > 1.0 then 1.0 else cycleOverlap
  rawWeight * (1.0 - discount)

/--
  Reference calculation of Weighted Democratic Voting Weight.
  Corresponds to: Bf_Pseudocode.txt L113.
-/
def Voting_weight_ref (base : Float) (expertise : Float) (impact : Float) : Float :=
  base + expertise + impact

end BenefutureReference
