/-
  BenefutureReference.Goal
  Computable reference for Goal G's admissibility and choice (L74), over Float.
  Mirrors `plan_admissible_G` and `goal_G` in `Benefuture.Proposed.PopulationDirection`:
  a plan is admissible when, against not acting, reality's scope does not contract and the
  floors of U and H and the peak of U do not fall; G picks the admissible plan of highest value.
-/

namespace BenefutureReference

/--
  Floor of a population: the lower nearest-rank q-quantile (L74, `min := Th_quantile`).
  Monotone in every level, so removing a being (setting it to the bottom) never raises it.
  0 for an empty population; q is clamped to [0, 1].
-/
def floor_quantile_ref (xs : Array Float) (q : Float) : Float :=
  if xs.size == 0 then 0.0
  else
    let sorted := xs.qsort (· < ·)
    let qc := if q < 0.0 then 0.0 else if q > 1.0 then 1.0 else q
    let rank := (qc * xs.size.toFloat).ceil.toUInt64.toNat
    let k := if rank == 0 then 0 else min (rank - 1) (xs.size - 1)
    sorted[k]!

/-- G-admissibility from the changes against not acting: none of ↑ℝ, min U, min H, max U falls. -/
def g_admissible_ref (dScope dMinU dMinH dMaxU : Float) : Bool :=
  dScope ≥ 0.0 && dMinU ≥ 0.0 && dMinH ≥ 0.0 && dMaxU ≥ 0.0

/--
  G's choice: the first index of highest value among admissible plans, or the number of plans
  when none is admissible. Including inaction (all changes zero) guarantees a choice.
-/
def g_choose_ref (values dScope dMinU dMinH dMaxU : Array Float) : Nat := Id.run do
  let mut best : Option (Nat × Float) := none
  for i in [0:values.size] do
    if g_admissible_ref dScope[i]! dMinU[i]! dMinH[i]! dMaxU[i]! then
      match best with
      | none => best := some (i, values[i]!)
      | some (_, v) => if values[i]! > v then best := some (i, values[i]!)
  match best with
  | none => values.size
  | some (i, _) => i

/--
  Tail-sensitive floor (`tail → Me`, Spike D1, L74, `8.56`):
  if any being stands below neutral (`< 0`), returns the total negative shortfall `∑ min(0, x)`
  so unaffected lives above neutral cannot mask a negative life; otherwise returns the mean
  of the bottom `max 1 (min rank n)` sorted levels (CVaR over the bottom q-tail).
-/
def tail_floor_ref (xs : Array Float) (q : Float) : Float := Id.run do
  let n := xs.size
  if n == 0 then return 0.0
  let mut hasNeg := false
  let mut negSum := 0.0
  for i in [0:n] do
    let x := xs[i]!
    if x < 0.0 then
      hasNeg := true
      negSum := negSum + x
  if hasNeg then return negSum
  let sorted := xs.qsort (· < ·)
  let qc := if q < 0.0 then 0.0 else if q > 1.0 then 1.0 else q
  let rank := (qc * n.toFloat).ceil.toUInt64.toNat
  let m := max 1 (min rank n)
  let mut s := 0.0
  for i in [0:m] do
    s := s + sorted[i]!
  return s / m.toFloat

/--
  Two-stage tragic-choice-safe lexical rights gate (`goal_G_lexical_fr`, Spike D3, L55, L136):
  returns `(index, degraded)` where `index = values.size` when no plan is G-admissible.
  Stage 1 restricts to plans that are both G-admissible and Fr-permissible (`degraded = false`).
  When no such plan exists (true tragic choice or omission catastrophe), Stage 2 falls back to
  unconstrained `g_choose_ref` (`degraded = true`).
-/
def g_choose_lexical_fr_ref (values dScope dMinU dMinH dMaxU : Array Float) (frOk : Array Bool) :
    Nat × Bool := Id.run do
  let mut best : Option (Nat × Float) := none
  for i in [0:values.size] do
    if g_admissible_ref dScope[i]! dMinU[i]! dMinH[i]! dMaxU[i]! && frOk.getD i false then
      match best with
      | none => best := some (i, values[i]!)
      | some (_, v) => if values[i]! > v then best := some (i, values[i]!)
  match best with
  | some (i, _) => (i, false)
  | none => (g_choose_ref values dScope dMinU dMinH dMaxU, true)

end BenefutureReference
