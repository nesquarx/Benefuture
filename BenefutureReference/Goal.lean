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

end BenefutureReference
