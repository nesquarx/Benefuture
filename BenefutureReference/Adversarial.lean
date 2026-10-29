/-
  BenefutureReference.Adversarial
  Computable reference for adversarial adaptation (AdvAp, L160; `Governance.Adversarial`;
  Adversarial adaptation article). Share, floor, audit cost and the frivolous threshold are
  governed thresholds.
-/

namespace BenefutureReference

/-- The reward for revealing successful gaming: the exploit's gain to a single entity plus a share
    of the harm the revelation prevents, at least `floor`, so revealing dominates exploiting.
    Mirrors `bounty_reward` (gain + max(1, harm / 10)) with share and floor governed. -/
def advap_reward_ref (exploitGain preventedHarm share floor : Float) : Float :=
  max 0 exploitGain + max floor (share * max 0 preventedHarm)

/-- What is charged down the causal chain of an established exploit: the reward and the audit
    (`creator_liability`), so planting a flaw to report it never pays. -/
def advap_liability_ref (reward auditCost : Float) : Float :=
  reward + max 0 auditCost

/-- A report that proves unfounded costs nothing in good faith; once the reporter's unfounded
    reports in the window exceed `threshold`, each is charged the audit it caused (Adversarial
    adaptation, Discussion: frivolous patterns above a high threshold). -/
def report_penalty_ref (unfounded threshold auditCost : Float) : Float :=
  if unfounded > threshold then max 0 auditCost else 0

/-- Ratcheting escrow (Benefuture currency: "overestimating models face ratcheting escrow
    requirements"; L84; author guidance 8.42.1): the reputation ledgers (L101) carry an actor's
    pattern of mistakes and uncovered deception as well as of success; escrow pays its work by a
    credence pulled towards a coin toss by its negative ledger's share (`negShare` ∈ [0, 1]), so more
    is held until measured. -/
def ratchet_credence_ref (credence negShare : Float) : Float :=
  0.5 + (credence - 0.5) * (1.0 - negShare)

end BenefutureReference
