/-
  BenefutureReference.Adversarial
  Computable reference for adversarial adaptation (AdvAp, L161; `Governance.Adversarial`;
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

/-- The reporter's schedule (author ruling 8.76). With `e` the gain of one exploit and `bonus` the
    bonus: a self-reporter after `n` exploits is paid e + bonus when n = 0, else bonus less the
    n − 1 exploits clawed back, so it nets e + bonus whatever n is (exploiting more before
    reporting earns nothing). -/
def self_report_payout_ref (n e bonus : Float) : Float :=
  if n ≤ 0.0 then e + bonus else bonus - (n - 1.0) * e

/-- Caught by someone else (8.76): the exploiter is charged every exploit (`clawback`, the overstated
    value repaired over its `n` exploits), the reporter's bonus and the audit. -/
def caught_charge_ref (clawback bonus auditCost : Float) : Float :=
  max 0.0 clawback + max 0.0 bonus + max 0.0 auditCost

/-- The reporter of a caught exploiter (8.76): one exploit of it (its clawback over its `n` exploits)
    plus the bonus, paid out of the exploiter's clawbacks; over a cabal, one exploit per exploiter. -/
def caught_reward_ref (clawback n bonus : Float) : Float :=
  (if n > 0.0 then max 0.0 clawback / n else 0.0) + max 0.0 bonus

/-- Justice for a detected false report (author ruling 8.82): the slanderer is charged the harm its
    report caused (the victim's liability, refunded to the victim), the reward it received, and the
    audit; a crime, like any detected lie. -/
def false_report_charge_ref (harm reward auditCost : Float) : Float :=
  max 0.0 harm + max 0.0 reward + max 0.0 auditCost

/-- Justice for artificial-scarcity supply withholding (author ruling 8.133): the withholder repays
    the entire market-wide scarcity premium buyers overpaid across all trades (including others'
    supply), plus any AdvAp reporter reward and audit cost. -/
def withhold_charge_ref (marketPremium reward auditCost : Float) : Float :=
  max 0.0 marketPremium + max 0.0 reward + max 0.0 auditCost

/-- AdvAp reporter reward for discovering supply withholding (author ruling 8.133):
    a lone withholder who self-reports earns 0; a first reporter in a supply cartel recovers its
    own liability share plus the AdvAp bounty on the remaining colluders' liability; an external
    reporter earns the AdvAp bounty on the prevented harm. -/
def withhold_reward_ref (ownLiability remainingPremium advShare advFloor : Float)
    (hasCoconspirators selfReport : Bool) : Float :=
  if selfReport then
    if hasCoconspirators then
      max 0.0 ownLiability + advap_reward_ref 0.0 (max 0.0 remainingPremium) advShare advFloor
    else
      0.0
  else
    advap_reward_ref 0.0 (max 0.0 remainingPremium) advShare advFloor

end BenefutureReference
