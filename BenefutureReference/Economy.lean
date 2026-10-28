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

/-- Causal distribution (L94, `causal_distribution_settlement`): contribution × outcome, net of the
    escrow already paid upfront. -/
def cause_settlement_ref (cc total upfrontPaid : Float) : Float := cc * total - upfrontPaid

end BenefutureReference
