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
  `defaultFrParams`, `Proposed.shapley` ↔ `shapley_ref`, `Proposed.shapley_sampled` ↔
  `shapley_sampled_ref`. Computable specifications compared directly: `bounty_reward` (ℤ) ↔
  `advap_reward_ref` at share 1/10 and floor 1 (equal where the prevented harm is a multiple of 10,
  within 1 otherwise: the spec floors harm / 10), `upfront_payment` (ℤ, parts per million) ↔
  `Escrow_split_ref` (within 1, by flooring). Exact checks over ℚ: the mean of marginals over all
  n! orderings equals the subset form of Shapley for n ≤ 5 (the identity cited, not proved, in
  `Proposed.ShapleySampling`).

  Not covered: rules whose specification involves exp, log, sqrt or powers with real exponents
  (`phi`, `Sy`, `HaWt`, `V`, `Rep_decay`, `accuracy`, `normal_cdf`, `credence`,
  `shapley_sample_count_ref`, `Voting_weight`), so no exact oracle exists over ℚ; rules with no
  ℝ counterpart in `Benefuture/` (most of `BenefutureReference.Domains`, `Records`, `Justice`,
  `Adversarial`, `ParamSpace`, `Measurement`'s model scoring); and noncomputable choices
  (`g_choose`, `pareto_front` over `Classical`). These rely on `spec/vectors` and the Julia suites.
  No refinement proof links ℝ to Float: Float rounding is tested, not bounded.
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

def ratToFloat (q : ℚ) : Float := Float.ofInt q.num / q.den.toFloat

def close (f : Float) (q : ℚ) : Bool :=
  let r := ratToFloat q
  (f - r).abs ≤ 1e-9 * (1 + r.abs)

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

#eval runAll

end BenefutureTest
