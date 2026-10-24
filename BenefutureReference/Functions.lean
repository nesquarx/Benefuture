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
  Corresponds to: Bf_Pseudocode.txt L48:
  As(x, A, t) := Norm((t ≤ t_0 ? Pr : Me)(x ← A) - Pr(x ← ¬A | Mem_ctrl) | Th_Cx).
  Ex-ante (t ≤ t0) uses the prediction, ex-post the measurement; the counterfactual prediction
  is subtracted in both cases, and the difference is normalised by the context threshold.
  Matches `dynamic_assessment_real` in the spec.
-/
def As_ref (predicted : Float) (counter : Float) (measured : Float) (t : Float) (t0 : Float)
    (thCx : Float) : Float :=
  let actionBranch := if t > t0 then measured else predicted
  (actionBranch - counter) / thCx

/--
  Reference signed-weight synergy (L13): Sy([(x, w_+ = 1, w_- = w_+)]).
  items: list of (x, w₊, w₋). Gains enter Φ₊ with w₊, losses enter Φ₋ with |x| and w₋.
  Matches `net_synergy_signed` in the spec.
-/
def Sy_signed_ref (items : List (Float × Float × Float))
    (lambda : Float) (kappa : Float) (qPlus : Float) (qMinus : Float) : Float :=
  let posItems := items.filterMap (fun (x, wp, _) => if x > 0.0 then some (x, wp) else none)
  let negItems := items.filterMap (fun (x, _, wn) => if x < 0.0 then some (-x, wn) else none)
  Sy_ref posItems negItems lambda kappa qPlus qMinus

/--
  Reference calculation of the harm weight Ha_wt (L61): 1 + Sy_{½,1.5}(tiers).
  tiers: list of (severity magnitude ≥ 0, priority weight), highest tier first.
  κ = ½, q₊ = 1.5 per the Sy_{κ,q₊} signature (L13). Matches `compute_harm_weight`.
-/
def HaWt_ref (tiers : List (Float × Float)) (lambda : Float) : Float :=
  1.0 + Sy_ref tiers [] lambda 0.5 1.5 1.5

/--
  Reference calculation of Value V (L73):
  V := Sy_{2}(As[(U, α, Ha_wt), (H, β, α·Ha_wt), (N, γ)]), items as (x, w₊, w₋), κ = 2.
  u, h, n are assessed (threshold-normalised) changes. Matches `value_on_being`.
-/
def V_ref (u : Float) (h : Float) (n : Float)
    (alpha : Float) (beta : Float) (gamma : Float) (haWt : Float)
    (lambda : Float) (qPlus : Float) (qMinus : Float) : Float :=
  Sy_signed_ref [(u, alpha, haWt), (h, beta, alpha * haWt), (n, gamma, gamma)]
    lambda 2.0 qPlus qMinus

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

/- --- Population direction (Benefuture.Proposed.PopulationDirection) --- -/

def mean_ref (xs : List Float) : Float :=
  if xs.isEmpty then 0.0 else sumFloat xs / xs.length.toFloat

def central_moment_ref (xs : List Float) (k : Float) : Float :=
  let m := mean_ref xs
  if xs.isEmpty then 0.0 else sumFloat (xs.map (fun x => (x - m).pow k)) / xs.length.toFloat

/-- Third central moment with sign preserved (Float.pow is undefined for negative bases). -/
def m3_ref (xs : List Float) : Float :=
  let m := mean_ref xs
  if xs.isEmpty then 0.0 else sumFloat (xs.map (fun x => (x - m) * (x - m) * (x - m))) / xs.length.toFloat

/-- Square-root-free skew direction key γ·|γ| = m₃·|m₃| / m₂³. Matches `skew_key`. -/
def skew_key_ref (xs : List Float) : Float :=
  let m2 := central_moment_ref xs 2.0
  let m3 := m3_ref xs
  if m2 == 0.0 then 0.0 else m3 * m3.abs / (m2 * m2 * m2)

/-- Σ_b 1 / Frequency(type b), frequency within history ++ population. Matches `population_novelty_hist`. -/
def population_novelty_ref (hist pop : List Nat) : Float :=
  let all := hist ++ pop
  sumFloat (pop.map (fun x => 1.0 / (all.count x).toFloat))

/-- Number of distinct types. Matches `effective_types`. -/
def effective_types_ref (pop : List Nat) : Nat :=
  pop.eraseDups.length

/-- q Pareto-dominates p: at least as good everywhere, strictly better somewhere. -/
def pareto_dominates_ref (q p : List Float) : Bool :=
  (q.zip p).all (fun (a, b) => b ≤ a) && (q.zip p).any (fun (a, b) => b < a)

/-- Indices of non-dominated progress vectors. Matches `pareto_front`. -/
def pareto_front_ref (ps : List (List Float)) : List Nat :=
  (List.range ps.length).filter (fun i =>
    match ps[i]? with
    | some p => !(ps.any (fun q => pareto_dominates_ref q p))
    | none => false)

/-- Sequential capped delegation (L114). Matches `accumulate_capped`. -/
def accumulate_capped_ref (cap : Float) : Float → List Float → Float
  | cur, [] => cur
  | cur, w :: ws => accumulate_capped_ref cap (if cur < cap then cur + w else cur) ws

/- --- Freedom (L135, author's reading) --- -/

/-- Harm schedule weights for Ha_wt (L61). Matches `harmSchedule`. -/
def harmSchedule_ref : List Float := [0.9, 0.7, 0.45, 0.15, 0.08, 0.04, 0.01]

/-- Fr severity score with longtermist multipliers 1000 / 100 / 10 / 1 / 0.5. Matches `severity_score`. -/
def severity_score_ref (irreparable irreversible longterm passing timeLoss : Float) : Float :=
  1000.0 * irreparable + 100.0 * irreversible + 10.0 * longterm + 1.0 * passing + 0.5 * timeLoss

/--
  Fr with defaults (thConf = 0.9, thHigh = 1). Blocks established harm at long-term severity
  or worse, and any harm with confidence · severity above 1. Matches `fr_permissible`.
-/
def fr_permissible_ref (irreparable irreversible longterm passing timeLoss confidence : Float) : Bool :=
  let established := confidence ≥ 0.9 && (irreparable > 0.0 || irreversible > 0.0 || longterm > 0.0)
  let expected := confidence * severity_score_ref irreparable irreversible longterm passing timeLoss
  !established && expected ≤ 1.0

/-- Distinct experiences / total. Matches `experiential_variety`. -/
def experiential_variety_ref (stream : List Nat) : Float :=
  if stream.isEmpty then 0.0 else stream.eraseDups.length.toFloat / stream.length.toFloat

/- --- Harm reference points (L54, author's reading) --- -/

/-- Rolling average of the preceding window. Matches `rolling_average`. -/
def rolling_average_ref (window : List Float) : Float :=
  if window.isEmpty then 0.0 else sumFloat window / window.length.toFloat

/-- H falls below its rolling average. Matches `h_harm`. -/
def h_harm_ref (window : List Float) (hNow : Float) : Float :=
  let d := rolling_average_ref window - hNow
  if d > 0.0 then d else 0.0

/-- U falls below its running maximum. Matches `u_harm`. -/
def u_harm_ref (history : List Float) (uNow : Float) : Float :=
  let m := history.foldr (fun a b => if a > b then a else b) uNow
  let d := m - uNow
  if d > 0.0 then d else 0.0

/--
  H := ∫Positive + BiasMitigation + Di (L37). sources: (intensity, bias degree, MM confidence).
  Each source counts (1 − c·b) of its non-negative intensity. Matches `happiness_score`.
-/
def happiness_score_ref (sources : List (Float × Float × Float)) (di : Float) : Float :=
  let pos := sources.map (fun (i, b, c) => (1.0 - c * b) * (if i > 0.0 then i else 0.0))
  sumFloat pos + (if di > 0.0 then di else 0.0)

end BenefutureReference
