/-
  BenefutureTest.Differential
  Cedar-style differential testing of the Float reference (`BenefutureReference`) against the
  Mathlib specification (`Benefuture`), run at build time: `lake build` elaborates this module and
  fails if any check fails.

  The chain for each rule covered here:
    ℝ specification  =  ℚ oracle    (proved below: `*_spec`, the oracle cast to ℝ is the spec)
    ℚ oracle         ≈  Float reference   (tested below on generated inputs, within tolerance)
  ℚ is exact and computable, so the oracle evaluates what the specification says, and the proof
  ties it to the specification itself rather than to a second transcription. Inputs are dyadic
  rationals, exactly representable as Float, so comparisons (`cur < cap` in capped delegation)
  branch identically on both sides; outputs are compared within 1e-9 relative tolerance.

  Covered (ℝ spec ↔ Float reference): `supply_delta`, `competition_efficiency`,
  `rolling_average`, `accumulate_capped`, `p_forgive`, `p_overreact`, `severity_score` at
  `defaultFrParams`, `Voting_weight` ↔ `Voting_weight_ref`, `Proposed.shapley` ↔ `shapley_ref`,
  `Proposed.shapley_sampled` ↔ `shapley_sampled_ref`, `Proposed.recordCredence` ↔
  `record_credence_ref`. Interval-bound ℚ oracles covering rules with exp, log, sqrt:
  `Rep_decay_ref`, `shapley_sample_count_ref`, `phi_ref` (at q = 1), `normal_cdf_ref`, `credence_ref`.
  Computable specifications compared directly: `bounty_reward` (ℤ) ↔ `advap_reward_ref` at share
  1/10 and floor 1 (equal where the prevented harm is a multiple of 10, within 1 otherwise: the spec
  floors harm / 10), `upfront_payment` (ℤ, parts per million) ↔ `Escrow_split_ref` (within 1, by
  flooring). Exact checks over ℚ: the mean of marginals over all n! orderings equals the subset form
  of Shapley for n ≤ 5 (the identity cited, not proved, in `Proposed.ShapleySampling`).

  Not covered: rules whose specification involves real exponents or noncomputable choices
  (`Sy`, `HaWt`, `V`, `accuracy`), rules with no ℝ counterpart in `Benefuture/` (most of
  `BenefutureReference.Domains`, `Records`, `Justice`, `Adversarial`, `ParamSpace`,
  `Measurement`'s model scoring); and noncomputable choices (`g_choose`, `pareto_front` over
  `Classical`). These rely on `spec/vectors` and the Julia suites. No refinement proof links ℝ to
  Float: Float rounding is tested, not bounded.
-/

import Mathlib.Data.Rat.Cast.Order
import Mathlib.Data.Rat.Cast.Lemmas
import Mathlib.Algebra.Order.Field.Rat
import Benefuture.Economy.Pricing
import Benefuture.Economy.Currency
import Benefuture.Governance.Incentives
import Benefuture.Governance.ExternalHarm
import Benefuture.Governance.Adversarial
import Benefuture.Subgoals.Freedom
import Benefuture.Axiology.Priorities
import Benefuture.Proposed.OutcomeDistribution
import Benefuture.Proposed.ShapleySampling
import Benefuture.Proposed.RecordCredence
import BenefutureReference

namespace BenefutureTest

open Finset

/-! ## ℚ oracles, each proved to be its ℝ specification -/

def supplyQ (g c h : ℚ) : ℚ := g - c - h
theorem supplyQ_spec (g c h : ℚ) :
    (supplyQ g c h : ℝ) = Benefuture.Economy.supply_delta g c h := by
  simp [supplyQ, Benefuture.Economy.supply_delta]

def efficiencyQ (dV c dt : ℚ) : ℚ := dV / (c + dt)
theorem efficiencyQ_spec (dV c dt : ℚ) :
    (efficiencyQ dV c dt : ℝ) = Benefuture.Economy.competition_efficiency dV c dt := by
  simp [efficiencyQ, Benefuture.Economy.competition_efficiency]

def rollingQ (w : List ℚ) : ℚ := if w = [] then 0 else w.sum / w.length
theorem rollingQ_spec (w : List ℚ) :
    (rollingQ w : ℝ) = Benefuture.Axiology.rolling_average (w.map (↑)) := by
  unfold rollingQ Benefuture.Axiology.rolling_average
  by_cases h : w = []
  · simp [h]
  · simp [h, Rat.cast_list_sum]

def cappedQ (cap : ℚ) : ℚ → List ℚ → ℚ
  | cur, [] => cur
  | cur, w :: ws => cappedQ cap (if cur < cap then cur + w else cur) ws
theorem cappedQ_spec (cap : ℚ) : ∀ (ws : List ℚ) (cur : ℚ),
    (cappedQ cap cur ws : ℝ) = Benefuture.Governance.accumulate_capped cap cur (ws.map (↑))
  | [], cur => by simp [cappedQ, Benefuture.Governance.accumulate_capped]
  | w :: ws, cur => by
    simp only [cappedQ, List.map_cons, Benefuture.Governance.accumulate_capped]
    rw [cappedQ_spec cap ws]
    by_cases h : cur < cap
    · have h' : (cur : ℝ) < cap := by exact_mod_cast h
      simp [h, h']
    · have h' : ¬ (cur : ℝ) < cap := by exact_mod_cast h
      simp [h, h']

def forgiveQ (alpha re : ℚ) : ℚ := min 1 (alpha * re)
def overreactQ (alpha delta rePos reNeg : ℚ) : ℚ := min (1 - forgiveQ alpha rePos) (delta * reNeg)
theorem forgiveQ_spec (alpha delta margin re : ℚ) :
    (forgiveQ alpha re : ℝ) = Benefuture.Governance.p_forgive ⟨alpha, delta, margin⟩ re := by
  simp [forgiveQ, Benefuture.Governance.p_forgive]
theorem overreactQ_spec (alpha delta margin rp rn : ℚ) :
    (overreactQ alpha delta rp rn : ℝ) = Benefuture.Governance.p_overreact ⟨alpha, delta, margin⟩ rp rn := by
  simp [overreactQ, forgiveQ, Benefuture.Governance.p_overreact, Benefuture.Governance.p_forgive]

def severityQ (a b c d e : ℚ) : ℚ := 1000 * a + 100 * b + 10 * c + 1 * d + (1 / 2) * e
theorem severityQ_spec (a b c d e : ℚ) :
    (severityQ a b c d e : ℝ) = Benefuture.Subgoals.severity_score
      { irreparable := a, irreversible := b, longterm := c, passing := d, timeLoss := e }
      Benefuture.Subgoals.defaultFrParams := by
  simp [severityQ, Benefuture.Subgoals.severity_score, Benefuture.Subgoals.defaultFrParams]
  norm_num

def shapleyQ (n : ℕ) (v : Finset (Fin n) → ℚ) (i : Fin n) : ℚ :=
  ∑ S ∈ (univ.erase i).powerset,
    ((S.card.factorial * (n - S.card - 1).factorial : ℕ) : ℚ) / (n.factorial : ℚ) * (v (insert i S) - v S)
theorem shapleyQ_spec (n : ℕ) (v : Finset (Fin n) → ℚ) (i : Fin n) :
    (shapleyQ n v i : ℝ) = Benefuture.Proposed.shapley univ (fun S => (v S : ℝ)) i := by
  simp only [shapleyQ, Benefuture.Proposed.shapley, card_univ, Fintype.card_fin]
  push_cast
  rfl

def marginalsFromQ {n : ℕ} (v : Finset (Fin n) → ℚ) : Finset (Fin n) → List (Fin n) → Fin n → ℚ
  | _, [], _ => 0
  | pre, a :: rest, i => (if i = a then v (insert a pre) - v pre else 0) + marginalsFromQ v (insert a pre) rest i
def sampledQ {n : ℕ} (v : Finset (Fin n) → ℚ) (samples : List (List (Fin n))) (i : Fin n) : ℚ :=
  (samples.map fun σ => marginalsFromQ v ∅ σ i).sum / samples.length

theorem marginalsFromQ_spec {n : ℕ} (v : Finset (Fin n) → ℚ) : ∀ (σ : List (Fin n)) (pre : Finset (Fin n)) (i : Fin n),
    (marginalsFromQ v pre σ i : ℝ) = Benefuture.Proposed.marginalsFrom (fun S => (v S : ℝ)) pre σ i
  | [], _, _ => by simp [marginalsFromQ, Benefuture.Proposed.marginalsFrom]
  | a :: rest, pre, i => by
    simp only [marginalsFromQ, Benefuture.Proposed.marginalsFrom]
    rw [← marginalsFromQ_spec v rest (insert a pre) i]
    split_ifs <;> push_cast <;> ring
theorem sampledQ_spec {n : ℕ} (v : Finset (Fin n) → ℚ) (samples : List (List (Fin n))) (i : Fin n) :
    (sampledQ v samples i : ℝ) = Benefuture.Proposed.shapley_sampled (fun S => (v S : ℝ)) samples i := by
  unfold sampledQ Benefuture.Proposed.shapley_sampled Benefuture.Proposed.marginals
  push_cast [Rat.cast_list_sum]
  simp only [List.map_map, Function.comp_def, marginalsFromQ_spec]

def recordWeightQ (v e : ℚ) : ℚ := if e < v then 1 else if e = v then 1 / 2 else 0
def recordCredenceQ (cap v : ℚ) (errs : List ℚ) : ℚ :=
  max (1 - cap) (min cap (if errs = [] then 1 / 2 else (errs.map (recordWeightQ v)).sum / errs.length))
theorem recordCredenceQ_spec (cap v : ℚ) (errs : List ℚ) :
    (recordCredenceQ cap v errs : ℝ) = Benefuture.Proposed.recordCredence cap v (errs.map (↑)) := by
  have hw : ∀ e : ℚ, ((recordWeightQ v e : ℚ) : ℝ) = Benefuture.Proposed.recordWeight v e := by
    intro e; unfold recordWeightQ Benefuture.Proposed.recordWeight
    by_cases h1 : e < v
    · have h1' : (e : ℝ) < v := by exact_mod_cast h1
      simp [h1, h1']
    · have h1' : ¬ (e : ℝ) < v := by exact_mod_cast h1
      by_cases h2 : e = v
      · subst h2; simp
      · have h2' : (e : ℝ) ≠ v := by exact_mod_cast h2
        simp [h1, h1', h2, h2']
  have hs : ((errs.map (recordWeightQ v)).sum : ℝ) = Benefuture.Proposed.recordScore v (errs.map (↑)) := by
    unfold Benefuture.Proposed.recordScore
    induction errs with
    | nil => simp
    | cons e rest ih => simp [List.map_cons, List.sum_cons, hw, ih]
  unfold recordCredenceQ Benefuture.Proposed.recordCredence
  by_cases h : errs = []
  · subst h; simp
  · simp [h, hs, Rat.cast_max, Rat.cast_min]

def votingWeightQ (base expWt : ℚ) (profile : List (ℚ × ℚ)) (impWt impact : ℚ) : ℚ :=
  let expertise := (profile.map fun (w, r) => w * r).sum
  base + expWt * expertise + impWt * impact

theorem votingWeightQ_spec (base expWt : ℚ) (profile : List (ℚ × ℚ)) (impWt impact : ℚ) :
    (votingWeightQ base expWt profile impWt impact : ℝ) =
      (base : ℝ) + (expWt : ℝ) * ((profile.map fun (w, r) => (w : ℝ) * (r : ℝ)).sum) +
        (impWt : ℝ) * (impact : ℝ) := by
  dsimp [votingWeightQ]
  push_cast [Rat.cast_list_sum]
  simp only [List.map_map, Function.comp_def]
  push_cast
  rfl

/-! ## Interval-bound oracles for nonlinear functions -/

/-- Rational square root bounds via Heron's method. For S ≥ 0, returns (lo, hi) such that lo ≤ √S ≤ hi. -/
def sqrtBoundsQ (S : ℚ) : ℚ × ℚ :=
  if S ≤ 0 then (0, 0)
  else
    let nBits := S.num.natAbs.log2
    let dBits := S.den.log2
    let halfExp : ℤ := ((nBits : ℤ) - (dBits : ℤ)) / 2
    let x0 : ℚ :=
      if halfExp ≥ 0 then (2 : ℚ) ^ halfExp.toNat
      else 1 / ((2 : ℚ) ^ (-halfExp).toNat)
    let rec loop (x : ℚ) : Nat → ℚ
      | 0 => x
      | n + 1 => loop ((x + S / x) / 2) n
    let xFinal := loop x0 5
    let lo := min xFinal (S / xFinal)
    let hi := max xFinal (S / xFinal)
    (lo, hi)

/-- Rational exp(-u) bounds for u ≥ 0. Returns (lo, hi) such that lo ≤ exp(-u) ≤ hi. -/
def expNegBoundsQ (u : ℚ) : ℚ × ℚ :=
  if u ≤ 0 then (1, 1)
  else if u ≥ 80 then (0, 1 / (2 ^ 80 : ℚ))
  else
    let rec reduce (x : ℚ) (k : Nat) : Nat → ℚ × Nat
      | 0 => (x, k)
      | fuel + 1 =>
        if x ≤ 1 / 2 then (x, k)
        else reduce (x / 2) (k + 1) fuel
    let (v, k) := reduce u 0 8
    let rec taylor (term sum : ℚ) (i : Nat) : Nat → ℚ × ℚ
      | 0 => (sum, sum + term * v / (i + 1))
      | n + 1 =>
        let term' := term * v / (i + 1)
        let sum' := if (i + 1) % 2 == 1 then sum - term' else sum + term'
        taylor term' sum' (i + 1) n
    let (baseLo, baseHi) := taylor 1 1 0 15
    let rec squareK (lo hi : ℚ) : Nat → ℚ × ℚ
      | 0 => (lo, hi)
      | n + 1 => squareK (lo * lo) (hi * hi) n
    squareK (max 0 baseLo) baseHi k

/-- Rational ln(x) bounds for x ≥ 1. Returns (lo, hi) such that lo ≤ ln(x) ≤ hi. -/
def lnBoundsQ (x : ℚ) : ℚ × ℚ :=
  if x ≤ 1 then (0, 0)
  else
    let ln2Lo : ℚ := 6931471805599 / 10000000000000
    let ln2Hi : ℚ := 6931471805600 / 10000000000000
    let rec reduce (z : ℚ) (k : Nat) : Nat → ℚ × Nat
      | 0 => (z, k)
      | fuel + 1 =>
        if z < 2 then (z, k)
        else reduce (z / 2) (k + 1) fuel
    let (w, k) := reduce x 0 32
    let y := (w - 1) / (w + 1)
    let y2 := y * y
    let rec series (term : ℚ) (sum : ℚ) (idx : Nat) : Nat → ℚ × ℚ
      | 0 =>
        let tailBound := if 1 - y2 = 0 then 0 else term * y2 / ((2 * idx + 1) * (1 - y2))
        (2 * sum, 2 * (sum + tailBound))
      | n + 1 =>
        let term' := term * y2
        series term' (sum + term' / (2 * (idx + 1) + 1)) (idx + 1) n
    let (baseLo, baseHi) := series y y 0 12
    (baseLo + k * ln2Lo, baseHi + k * ln2Hi)

def repDecayBoundsQ (score dt lambda : ℚ) : ℚ × ℚ :=
  if dt ≤ 0 then (score, score)
  else
    let (elo, ehi) := expNegBoundsQ (lambda * dt)
    if score ≥ 0 then (score * elo, score * ehi)
    else (score * ehi, score * elo)

def shapleySampleCountBoundsQ (n : Nat) (eps delta : ℚ) : Nat × Nat :=
  if eps ≤ 0 || delta ≤ 0 || n == 0 then (0, 0)
  else
    let x := 2 * (n : ℚ) / delta
    let denom := 2 * eps * eps
    let (lnLo, lnHi) := lnBoundsQ x
    let ceilQ (q : ℚ) : Nat :=
      if q ≤ 0 then 0
      else (q.num + q.den - 1) / q.den |>.toNat
    (ceilQ (lnLo / denom), ceilQ (lnHi / denom))

def phiBoundsQ (items : List (ℚ × ℚ)) (kappa : ℚ) : ℚ × ℚ :=
  let linearSum := (items.map fun (a, w) => w * a).sum
  let pairs := BenefutureReference.crossPairs items
  let crossSum := (pairs.map fun ((a1, w1), (a2, w2)) => w1 * w2 * (a1 * a2)).sum
  let (sqrtLo, sqrtHi) := sqrtBoundsQ crossSum
  if kappa ≥ 0 then
    (linearSum + kappa * sqrtLo, linearSum + kappa * sqrtHi)
  else
    (linearSum + kappa * sqrtHi, linearSum + kappa * sqrtLo)

def normalCdfBoundsQ (x : ℚ) : ℚ × ℚ :=
  let xabs := |x|
  let (sqrt2Lo, sqrt2Hi) := sqrtBoundsQ 2
  let zLo := xabs / sqrt2Hi
  let zHi := xabs / sqrt2Lo
  let c0 : ℚ := 3275911 / 10000000
  let tLo := 1 / (1 + c0 * zHi)
  let tHi := 1 / (1 + c0 * zLo)
  let a1 : ℚ := 254829592 / 1000000000
  let a2 : ℚ := -284496736 / 1000000000
  let a3 : ℚ := 1421413741 / 1000000000
  let a4 : ℚ := -1453152027 / 1000000000
  let a5 : ℚ := 1061405429 / 1000000000
  let polyQ (t : ℚ) : ℚ :=
    t * (a1 + t * (a2 + t * (a3 + t * (a4 + t * a5))))
  let polyLo := min (polyQ tLo) (polyQ tHi)
  let polyHi := max (polyQ tLo) (polyQ tHi)
  let (expLo, _) := expNegBoundsQ (zHi * zHi)
  let (_, expHi) := expNegBoundsQ (zLo * zLo)
  let termLo := max 0 (polyLo * expLo)
  let termHi := polyHi * expHi
  let erfLo := 1 - termHi
  let erfHi := 1 - termLo
  if x ≥ 0 then
    ((1 + erfLo) / 2, (1 + erfHi) / 2)
  else
    ((1 - erfHi) / 2, (1 - erfLo) / 2)

def credenceBoundsQ (predicted uncertainty cap : ℚ) : ℚ × ℚ :=
  if uncertainty = 0 then
    let c : ℚ := if predicted > 0 then 1 else if predicted < 0 then 0 else 1 / 2
    (max (1 - cap) (min cap c), max (1 - cap) (min cap c))
  else
    let (nLo, nHi) := normalCdfBoundsQ (predicted / uncertainty)
    (max (1 - cap) (min cap nLo), max (1 - cap) (min cap nHi))

/-! ## Generated inputs -/

/-- A 64-bit linear congruential generator (Knuth's MMIX constants); fixed seeds, so every build
    checks the same inputs. -/
structure Gen where
  s : UInt64

def Gen.next (g : Gen) : UInt64 × Gen :=
  let s := g.s * 6364136223846793005 + 1442695040888963407
  (s >>> 11, ⟨s⟩)

def Gen.below (g : Gen) (k : Nat) : Nat × Gen :=
  let (x, g) := g.next
  (x.toNat % k, g)

/-- A dyadic rational z / 2^e with |z| < 2^20, e < 8: exact in Float. -/
def Gen.dyadic (g : Gen) : ℚ × Gen :=
  let (z, g) := g.below (2 ^ 21)
  let (e, g) := g.below 8
  (((z : ℤ) - 2 ^ 20 : ℤ) / (2 ^ e : ℚ), g)

def Gen.dyadicNonneg (g : Gen) : ℚ × Gen :=
  let (q, g) := g.dyadic
  (|q|, g)

def ratToFloat (q : ℚ) : Float :=
  let nBits := q.num.natAbs.log2
  let dBits := q.den.log2
  let maxBits := max nBits dBits
  if maxBits ≤ 900 then
    Float.ofInt q.num / q.den.toFloat
  else
    let shift := maxBits - 900
    let nShifted : ℤ := q.num >>> shift
    let dShifted : Nat := max 1 (q.den >>> shift)
    Float.ofInt nShifted / dShifted.toFloat

def close (f : Float) (q : ℚ) : Bool :=
  let r := ratToFloat q
  (f - r).abs ≤ 1e-9 * (1 + r.abs)

def inInterval (f : Float) (lo hi : ℚ) (tol : Float := 1e-6) : Bool :=
  let rlo := ratToFloat lo
  let rhi := ratToFloat hi
  let scale := 1.0 + f.abs
  f ≥ rlo - tol * scale && f ≤ rhi + tol * scale

/-- Runs `trials` generated cases; a case returns whether the Float reference agreed. -/
def checkAll (name : String) (trials : Nat) (seed : UInt64) (case : Gen → Bool × Gen) : IO Unit := do
  let mut g : Gen := ⟨seed⟩
  let mut bad := 0
  for _ in [0:trials] do
    let (ok, g') := case g
    g := g'
    unless ok do bad := bad + 1
  if bad > 0 then
    throw <| IO.userError s!"differential {name}: {bad} of {trials} cases disagree"
  IO.println s!"differential {name}: {trials} cases agree"

/-- Bitmask of a coalition of Fin n. -/
def maskOf {n : ℕ} (S : Finset (Fin n)) : Nat := S.sum fun i => 2 ^ i.val

/-- A random game on n contributors: one dyadic value per bitmask. -/
def Gen.game (g : Gen) (n : Nat) : Array ℚ × Gen := Id.run do
  let mut g := g
  let mut vs : Array ℚ := #[]
  for _ in [0:2 ^ n] do
    let (q, g') := g.dyadic
    g := g'
    vs := vs.push q
  (vs, g)

/-- A random ordering of 0 … n − 1 (Fisher–Yates). -/
def Gen.perm (g : Gen) (n : Nat) : List Nat × Gen := Id.run do
  let mut g := g
  let mut a : Array Nat := (List.range n).toArray
  for k in [0:n] do
    let j := n - 1 - k
    let (r, g') := g.below (j + 1)
    g := g'
    a := a.swapIfInBounds j r
  (a.toList, g)

def toFin (n : Nat) (l : List Nat) : List (Fin n) := l.filterMap fun i => if h : i < n then some ⟨i, h⟩ else none

/-! ## The checks (run when this module is built) -/

open BenefutureReference in
def runAll : IO Unit := do
  checkAll "supply_delta" 500 1 fun g =>
    let (a, g) := g.dyadic; let (b, g) := g.dyadic; let (c, g) := g.dyadic
    (close (supply_delta_ref (ratToFloat a) (ratToFloat b) (ratToFloat c)) (supplyQ a b c), g)
  checkAll "competition_efficiency" 500 2 fun g =>
    let (a, g) := g.dyadic; let (b, g) := g.dyadicNonneg; let (c, g) := g.dyadicNonneg
    if b + c = 0 then (true, g) else
    (close (competition_efficiency_ref (ratToFloat a) (ratToFloat b) (ratToFloat c)) (efficiencyQ a b c), g)
  checkAll "rolling_average" 300 3 fun g => Id.run do
    let (k, g) := g.below 8
    let mut g := g
    let mut w : List ℚ := []
    for _ in [0:k] do
      let (q, g') := g.dyadic
      g := g'; w := q :: w
    (close (rolling_average_ref (w.map ratToFloat)) (rollingQ w), g)
  checkAll "accumulate_capped" 500 4 fun g => Id.run do
    let (cap, g) := g.dyadicNonneg; let (cur, g) := g.dyadicNonneg
    let (k, g) := g.below 8
    let mut g := g
    let mut ws : List ℚ := []
    for _ in [0:k] do
      let (q, g') := g.dyadicNonneg
      g := g'; ws := q :: ws
    (close (accumulate_capped_ref (ratToFloat cap) (ratToFloat cur) (ws.map ratToFloat)) (cappedQ cap cur ws), g)
  checkAll "p_forgive, p_overreact" 500 5 fun g =>
    let (a, g) := g.dyadicNonneg; let (d, g) := g.dyadicNonneg
    let (rp, g) := g.dyadicNonneg; let (rn, g) := g.dyadicNonneg
    let (a, d) := (a / 2 ^ 20, d / 2 ^ 20)
    (close (p_forgive_ref (ratToFloat a) (ratToFloat rp)) (forgiveQ a rp) &&
     close (p_overreact_ref (ratToFloat a) (ratToFloat d) (ratToFloat rp) (ratToFloat rn)) (overreactQ a d rp rn), g)
  checkAll "severity_score" 500 6 fun g =>
    let (a, g) := g.dyadicNonneg; let (b, g) := g.dyadicNonneg; let (c, g) := g.dyadicNonneg
    let (d, g) := g.dyadicNonneg; let (e, g) := g.dyadicNonneg
    (close (severity_score_ref (ratToFloat a) (ratToFloat b) (ratToFloat c) (ratToFloat d) (ratToFloat e))
      (severityQ a b c d e), g)
  checkAll "shapley" 120 7 fun g =>
    let (n, g) := g.below 6
    let (vs, g) := g.game n
    let v : Finset (Fin n) → ℚ := fun S => vs.getD (maskOf S) 0
    let φ := shapley_ref n (vs.map ratToFloat)
    ((List.finRange n).all fun i => close (φ.getD i.val 0) (shapleyQ n v i), g)
  checkAll "shapley_sampled" 200 8 fun g => Id.run do
    let (n, g) := g.below 7
    let (m, g) := g.below 6
    let (vs, g) := g.game n
    let v : Finset (Fin n) → ℚ := fun S => vs.getD (maskOf S) 0
    let mut g := g
    let mut samples : List (List Nat) := []
    for _ in [0:m + 1] do
      let (p, g') := g.perm n
      g := g'; samples := samples ++ [p]
    let perms := samples.foldl (fun a p => a ++ (p.map Nat.toFloat).toArray) #[]
    let along (p : List Nat) : List Float :=
      (List.range (n + 1)).map fun k => ratToFloat (vs.getD ((p.take k).foldl (fun s i => s + 2 ^ i) 0) 0)
    let vals := samples.foldl (fun a p => a ++ (along p).toArray) #[]
    let φ := shapley_sampled_ref n (m + 1) perms vals
    let fs := samples.map (toFin n)
    ((List.finRange n).all fun i => close (φ.getD i.val 0) (sampledQ v fs i), g)
  -- Exact over ℚ: the mean over all n! orderings is the subset form of Shapley.
  checkAll "shapley orderings = subsets (exact, ℚ)" 60 9 fun g =>
    let (n, g) := g.below 6
    let (vs, g) := g.game n
    let v : Finset (Fin n) → ℚ := fun S => vs.getD (maskOf S) 0
    let all := (List.finRange n).permutations
    ((List.finRange n).all fun i => sampledQ v all i == shapleyQ n v i, g)
  checkAll "record_credence" 400 12 fun g => Id.run do
    let (k, g) := g.below 9
    let (v, g) := g.dyadic
    let mut g := g
    let mut errs : List ℚ := []
    for _ in [0:k] do
      let (q, g') := g.dyadic
      g := g'; errs := q :: errs
    let (tie, g2) := g.below 3
    let es := if tie == 0 then v :: errs else errs  -- ties counted half on both sides
    (close (record_credence_ref (ratToFloat v) (es.map ratToFloat).toArray 0.99) (recordCredenceQ (99 / 100) v es), g2)
  -- Computable ℤ specifications.
  checkAll "bounty_reward vs advap_reward_ref" 500 10 fun g =>
    let (gain, g) := g.below 100000; let (harm, g) := g.below 100000
    let spec := Benefuture.Governance.bounty_reward gain harm
    let f := advap_reward_ref gain.toFloat harm.toFloat 0.1 1.0
    let err := (f - Float.ofInt spec).abs
    (if harm % 10 == 0 then err ≤ 1e-6 else err < 1.0, g)
  checkAll "upfront_payment vs Escrow_split_ref" 500 11 fun g =>
    let (nom, g) := g.below 1000000000; let (conf, g) := g.below 1000001
    if h : conf ≤ 1000000 then
      let pe := Benefuture.Economy.ProbabilisticEscrow.mkSimple "e" conf (by omega)
        (by simp only [Benefuture.Math.SCALE]; omega)
      let spec := Benefuture.Economy.upfront_payment nom pe
      let f := (Escrow_split_ref nom.toFloat (conf.toFloat / 1000000.0)).1
      ((f - Float.ofInt spec).abs < 1.0 + 1e-6, g)
    else (true, g)
  -- Exact over ℚ: Voting_weight (L113)
  checkAll "Voting_weight" 500 13 fun g => Id.run do
    let (base, g) := g.dyadicNonneg
    let (expWt, g) := g.dyadicNonneg
    let (impWt, g) := g.dyadicNonneg
    let (impact, g) := g.dyadicNonneg
    let (th, g) := g.dyadicNonneg
    let (k, g) := g.below 6
    let mut g := g
    let mut profile : List (ℚ × ℚ) := []
    for _ in [0:k] do
      let (w, g') := g.dyadicNonneg
      let (r, g'') := g'.dyadicNonneg
      g := g''; profile := (w / 16, r) :: profile
    let q := votingWeightQ base expWt profile impWt impact
    let f := Voting_weight_ref (ratToFloat base) (ratToFloat expWt)
      (profile.map fun (w, r) => (ratToFloat w, ratToFloat r))
      (ratToFloat impWt) (ratToFloat impact) (ratToFloat th)
    (close f.1 q && f.2 == (q < th), g)
  -- Interval-bound oracles for nonlinear functions
  checkAll "Rep_decay" 500 14 fun g =>
    let (score, g) := g.dyadic
    let (dt, g) := g.dyadic
    let (lam, g) := g.dyadicNonneg
    let (lo, hi) := repDecayBoundsQ score dt (lam / 16)
    let f := Rep_decay_ref (ratToFloat score) (ratToFloat dt) (ratToFloat (lam / 16))
    (inInterval f lo hi 1e-6, g)
  checkAll "shapley_sample_count" 400 15 fun g =>
    let (n0, g) := g.below 20
    let n := n0 + 1
    let (eps0, g) := g.below 50
    let eps : ℚ := ((eps0 : ℚ) + 1) / 100
    let (del0, g) := g.below 50
    let delta : ℚ := ((del0 : ℚ) + 1) / 100
    let (lo, hi) := shapleySampleCountBoundsQ n eps delta
    let f := shapley_sample_count_ref n (ratToFloat eps) (ratToFloat delta)
    (f + 1 ≥ lo && f ≤ hi + 1, g)
  checkAll "phi" 400 16 fun g => Id.run do
    let (k, g) := g.below 5
    let (kappa, g) := g.dyadicNonneg
    let mut g := g
    let mut items : List (ℚ × ℚ) := []
    for _ in [0:k] do
      let (a, g') := g.dyadicNonneg
      let (w, g'') := g'.dyadicNonneg
      g := g''; items := (a / 8, w / 8) :: items
    let (lo, hi) := phiBoundsQ items (kappa / 8)
    let f := phi_ref (items.map fun (a, w) => (ratToFloat a, ratToFloat w)) 1.0 (ratToFloat (kappa / 8))
    (inInterval f lo hi 1e-6, g)
  checkAll "normal_cdf" 500 17 fun g =>
    let (x, g) := g.dyadic
    let (lo, hi) := normalCdfBoundsQ (x / 4)
    let f := normal_cdf_ref (ratToFloat (x / 4))
    (inInterval f lo hi 1e-5, g)
  checkAll "credence" 500 18 fun g =>
    let (pred, g) := g.dyadic
    let (unc, g) := g.dyadicNonneg
    let (cap0, g) := g.below 49
    let cap : ℚ := ((cap0 : ℚ) + 51) / 100
    let (lo, hi) := credenceBoundsQ (pred / 4) (unc / 4) cap
    let f := credence_ref (ratToFloat (pred / 4)) (ratToFloat (unc / 4)) (ratToFloat cap)
    (inInterval f lo hi 1e-5, g)

#eval runAll

end BenefutureTest
