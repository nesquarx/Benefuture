/-
  BenefutureReference.Economy
  Computable reference for settling probabilistic escrow (L84, L94), over Float.
-/

namespace BenefutureReference

/--
  Settlement of a front-loaded payment: the measured value less what was paid upfront. Positive
  releases the hold; negative is a clawback. Causal distribution nets over escrow payments
  already made, so the total paid equals the measured value (L94: CD ∝ CC − PE_paid).
-/
def settlement_ref (measured upfrontPaid : Float) : Float := measured - upfrontPaid

/--
  A contributor's causal contribution to one side of an outcome (L93, `causal_contribution_ratio`;
  author ruling, BACKPROPAGATION 8.14): its part over the side's total, in [0, 1]. Positive parts
  pay their contributors, negative parts penalise theirs, so each side is shared on its own.
-/
def cc_share_ref (part sideTotal : Float) : Float :=
  if sideTotal == 0.0 then 0.0 else max 0.0 (min 1.0 (part / sideTotal))

/-- Factorial over Float. -/
def fact_ref (k : Nat) : Float := (List.range k).foldl (fun a j => a * (j + 1).toFloat) 1.0

/-- Number of set bits: the size of a coalition given as a bitmask. -/
def popcount_ref (m : Nat) : Nat := (List.range 64).foldl (fun c b => if m.testBit b then c + 1 else c) 0

/--
  Shapley shares of an outcome among n contributors (Benefuture currency: "approximates
  shapley-esque mechanisms"; author ruling, BACKPROPAGATION 8.17; `Proposed.OutcomeDistribution`).
  `v[m]` is the outcome a metric model assesses had only the contributors in bitmask m acted, the
  others at their counterfactuals (inaction, or the committed action).
-/
def shapley_ref (n : Nat) (v : Array Float) : Array Float :=
  (List.range n).toArray.map fun i =>
    (List.range (2 ^ n)).foldl (fun acc m =>
      if m.testBit i then acc
      else
        let s := popcount_ref m
        let w := fact_ref s * fact_ref (n - s - 1) / fact_ref n
        acc + w * (v.getD (m ||| (1 <<< i)) 0.0 - v.getD m 0.0)) 0.0

/-- The switch of L94: contributions come from the causal assessment (MM_CE) when its confidence
    reaches the threshold, else from traversing the transaction substrate (L95). -/
def cc_assessed_ref (confidence threshold : Float) : Bool := confidence ≥ threshold

/--
  Fallback traversal (L95): each link's net contribution NetC weighted down by its degree of
  separation, decay^degree, and normalised; nothing to share when no link contributed.
-/
def traversal_shares_ref (netC degree : Array Float) (decay : Float) : Array Float :=
  let w := (netC.zip degree).map fun (c, d) => c * Float.pow decay d
  let total := w.foldl (· + ·) 0.0
  if total ≤ 0.0 then w.map fun _ => 0.0 else w.map (· / total)

/-- Causal distribution (L94, `causal_distribution_settlement`): contribution × outcome, net of the
    escrow already paid upfront. -/
def cause_settlement_ref (cc total upfrontPaid : Float) : Float := cc * total - upfrontPaid

/-- Carrying another's output on (author ruling, BACKPROPAGATION 8.22; L95: CD ∝ CC + N_CCtype):
outside contract, a communicative contribution earning an accolade; under contract, the contracted
share, paid as completion of the contract. Either comes out of the maker's positive share; nothing
comes out of a loss. -/
def carry_fee_ref (makerPos accoladeRate contractShare : Float) (contracted : Bool) : Float :=
  if makerPos ≤ 0 then 0 else (if contracted then contractShare else accoladeRate) * makerPos

end BenefutureReference
