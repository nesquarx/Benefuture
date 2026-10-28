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

end BenefutureReference
