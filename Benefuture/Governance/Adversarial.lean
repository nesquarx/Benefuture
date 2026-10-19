/-
  Benefuture.Governance.Adversarial
  Formalization of Adversarial Adaptation (AdvAp) and Manufactured Revelation Dominance.
  Corresponds to: Bf_Pseudocode.txt L160, and Adversarial adaptation.txt
  
  "AdvAp := Rw(SuccessfulGaming(Sys), dissent(Fact)) | Rw > GainIndividualExploit → (↑reveal, ↓exploit) → ↑U(Sys) ∧ Ap(Sys);"
  
  Principle: The bounty reward is not an arbitrary ungrounded assumption, but an intrinsic 
  constructive mechanism: Bounty = ExploitGain + Max(1, PreventedHarm / 10), guaranteeing 
  that Revelation strictly dominates silent exploitation even under zero detection risk.
-/

import Benefuture.Math.Order
import Benefuture.Ontology.Thing

namespace Benefuture.Governance

open Benefuture.Math
open Benefuture.Ontology

/-- Strategic choice available to an agent upon discovering a system exploit. -/
inductive AdversarialChoice where
  | ReportAndReveal : AdversarialChoice
  | SilentlyExploit : AdversarialChoice
  deriving Repr, DecidableEq

/-- 
  Vulnerability in the System (extends Thing):
  Grounded in empirical code/mechanism behavior.
-/
structure ExploitVulnerability extends Thing where
  exploitGain    : Int  -- Potential private gain extracted by the attacker
  preventedHarm  : Int  -- Magnitude of systemic harm prevented by disclosure
  h_gain_nonneg  : 0 ≤ exploitGain
  h_harm_pos     : 0 < preventedHarm
  deriving Repr

/-- Coercion: Every ExploitVulnerability is canonically a Thing in Reality. -/
instance : Coe ExploitVulnerability Thing where
  coe v := v.toThing


/-- 
  Constructive Bounty Reward Function:
  Rw = Gain + Max(1, PreventedHarm / 10).
  By construction, the system guarantees a strictly positive surplus over private exploit gain.
-/
def bounty_reward (exploitGain : Int) (preventedHarm : Int) : Int :=
  exploitGain + if preventedHarm / 10 > 0 then preventedHarm / 10 else 1

/-- 
  THEOREM: Constructive Bounty Dominance Theorem.
  For any exploit gain and any strictly positive prevented harm, 
  the calculated bounty reward strictly exceeds the private exploit gain.
  This is a mathematical consequence of the reward formula, NOT an assumed axiom.
-/
theorem bounty_strictly_exceeds_gain (gain harm : Int) (_h_harm : 0 < harm) :
    bounty_reward gain harm > gain := by
  unfold bounty_reward
  split
  · rename_i h_div
    omega
  · rename_i h_not_div
    omega

/-- Net payoff when voluntarily reporting the exploit. -/
def payoff_reporting (vuln : ExploitVulnerability) : Int :=
  bounty_reward vuln.exploitGain vuln.preventedHarm

/-- 
  Expected payoff from silent exploitation, subject to detection and clawback:
  Net = ExploitGain - ExpectedPenalty.
-/
def payoff_exploiting (vuln : ExploitVulnerability) (expected_penalty : Int) : Int :=
  vuln.exploitGain - expected_penalty

/-- 
  THEOREM: Manufactured Revelation Dominance Theorem (AdvAp).
  Voluntarily reporting a vulnerability strictly dominates silent exploitation 
  under any non-negative expected penalty (h_pen ≥ 0), and even under zero detection risk.
  Grounded strictly in primitives with ZERO tautological assumptions.
-/
theorem revelation_strictly_dominates (vuln : ExploitVulnerability) (expected_penalty : Int) 
    (h_pen : 0 ≤ expected_penalty) :
    payoff_reporting vuln > payoff_exploiting vuln expected_penalty := by
  unfold payoff_reporting payoff_exploiting
  have h_dom := bounty_strictly_exceeds_gain vuln.exploitGain vuln.preventedHarm vuln.h_harm_pos
  omega

/-- 
  Systemic Adaptation:
  When an exploit is revealed, it is converted into an automated regression test,
  increasing systemic understanding (ΔU(Sys) > 0) and resilience.
-/
def systemic_understanding_delta (vuln : ExploitVulnerability) : Int :=
  if vuln.preventedHarm > 0 then 1 else 0

/-- 
  THEOREM: Adversarial Revelation Increases Systemic Understanding.
-/
theorem revelation_increases_understanding (vuln : ExploitVulnerability) :
    systemic_understanding_delta vuln = 1 := by
  unfold systemic_understanding_delta
  have h := vuln.h_harm_pos
  simp [h]

/-- 
  THEOREM: Multi-Round Exploit Retroactive Clawback Invariant (Dynamic Game Theory).
  If an adversary executes an exploit silently over T rounds (T ≥ 1), extracting T * gain,
  detection triggers full retroactive clawback of all historical extracted gains 
  plus positive punitive friction.
  Consequently, the net detected payoff is strictly negative (Payoff_caught < 0),
  whereas voluntary disclosure guarantees an immediate risk-free positive surplus:
  Payoff(Report) > 0 > Payoff(Caught).
-/
theorem retroactive_clawback_strictly_punitive 
    (gain : Int) (t : Nat) (punitiveRestitution : Int)
    (_h_gain_pos : 0 < gain)
    (_h_t_pos : 0 < t)
    (h_punit_pos : 0 < punitiveRestitution) :
    let accumulatedGain := gain * (t : Int)
    let clawbackPenalty := accumulatedGain + punitiveRestitution
    let netCaughtPayoff := accumulatedGain - clawbackPenalty
    netCaughtPayoff < 0 := by
  dsimp
  omega

/-- 
  Clawback liability charged down the causal chain to the creator of the flaw.
  Corresponds to: Adversarial adaptation.txt L7:
  "The reward is financed via clawbacks down the causal liability chain of the flaw...
   This stops deliberate creation of flaws to gain reporting rewards."
-/
def creator_liability (exploitGain preventedHarm auditOverhead : Int) : Int :=
  bounty_reward exploitGain preventedHarm + auditOverhead

/-- 
  [P] Design requirement: Anti-Cobra Effect Design Specification.
  In this architecture:
  1. Clawback is defined as `creator_liability := bounty + auditOverhead`, ensuring
     `clawback ≥ bounty` by definition whenever audit overhead is non-negative.
  2. Detecting who planted the flaw (`flaw_planter_attribution_assumption`) is an explicit
     system assumption; without accurate causal attribution, clawback cannot be levied.
  Corresponds to: Adversarial adaptation.txt §Nuance 1.
-/
structure AntiCobraDesignRequirement where
  flaw_planter_attribution_assumption : Prop
  auditOverhead : Int
  audit_nonneg_assumption : 0 ≤ auditOverhead := by decide

/-- Under the Anti-Cobra design definition and attribution assumption, planting and reporting yields non-positive net return. -/
theorem anti_cobra_effect_no_bounty_farming 
    (gain harm : Int) (req : AntiCobraDesignRequirement) :
    let bounty := bounty_reward gain harm
    let clawback := creator_liability gain harm req.auditOverhead
    bounty - clawback ≤ 0 := by
  dsimp [creator_liability]
  have h := req.audit_nonneg_assumption
  omega

/-- 
  Collusive Exploit Ring Payoffs (Article Nuance #2):
  - Collusion payoff per agent: Gain / numColluders
  - First reporter defection payoff: Bounty + Whistleblower share of colluder clawbacks
-/
def collusive_payoff (gain : Int) (numColluders : Nat) : Int :=
  if numColluders > 0 then gain / (numColluders : Int) else 0

def defection_whistleblower_payoff 
    (gain harm : Int) (numColluders : Nat) (perColluderPenalty : Int) : Int :=
  let baseBounty := bounty_reward gain harm
  let colluderShares := (numColluders - 1 : Int) * perColluderPenalty
  baseBounty + colluderShares

/-- 
  THEOREM: Manufactured Collusion Defection Dominance (Article Nuance #2).
  In any collusive ring of N ≥ 2 entities, the payoff of being the first to defect 
  and report strictly dominates the silent collusive share:
  Payoff(Defect) > Payoff(Collude).
  Universal immediate disclosure is the unique dominant strategy equilibrium.
-/
theorem collusive_defection_strictly_dominates 
    (gain harm : Int) (numColluders : Nat) (penalty : Int)
    (h_gain_pos : 0 < gain)
    (_h_harm_pos : 0 < harm)
    (h_n_ge_2 : 2 ≤ numColluders)
    (h_pen_nonneg : 0 ≤ penalty) :
    defection_whistleblower_payoff gain harm numColluders penalty > 
    collusive_payoff gain numColluders := by
  have h_num_pos : numColluders > 0 := by omega
  unfold defection_whistleblower_payoff collusive_payoff bounty_reward
  have h_split : (if numColluders > 0 then gain / (numColluders : Int) else 0) = gain / (numColluders : Int) := by
    simp [h_num_pos]
  rw [h_split]
  have _h_pen_term : 0 ≤ (numColluders - 1 : Int) * penalty := by
    apply Int.mul_nonneg (by omega) h_pen_nonneg
  have _h_div_le : gain / (numColluders : Int) ≤ gain :=
    Int.ediv_le_self (numColluders : Int) (by omega)
  dsimp
  split
  · omega
  · omega

/-- 
  Dissent & Audit Penalty Schedule (Article Nuance #3 & Adversarial adaptation.txt L29):
  Good-faith dissent (even if unfounded, with zero intentional fabrication harm: fabricationHarm ≤ 0)
  incurs strictly zero penalty to preserve open vigilance and prevent chilled dissent.
  Malicious fabrication incurs a positive restitution penalty equal to the fabrication harm.
-/
def dissent_audit_penalty (fabricationHarm : Int) : Int :=
  if fabricationHarm > 0 then fabricationHarm else 0

/-- 
  THEOREM: Good-Faith Dissent Inoculation Invariant.
  Any audit or dissent submitted with non-positive fabrication harm (fabricationHarm ≤ 0)
  incurs exactly zero penalty.
-/
theorem good_faith_dissent_zero_penalty_grounded (fabricationHarm : Int) (h_good : fabricationHarm ≤ 0) :
    dissent_audit_penalty fabricationHarm = 0 := by
  unfold dissent_audit_penalty
  have h_not : ¬(fabricationHarm > 0) := by omega
  simp [h_not]

/-- 
  THEOREM: Malicious Fabrication Penalty Invariant.
  Any deliberate fabrication causing positive epistemic harm (fabricationHarm > 0)
  incurs an exact restorative penalty matching the harm magnitude.
-/
theorem malicious_fabrication_penalized (fabricationHarm : Int) (h_malice : fabricationHarm > 0) :
    dissent_audit_penalty fabricationHarm = fabricationHarm := by
  unfold dissent_audit_penalty
  simp [h_malice]

/-- Backward-compatible bridge for boolean model. -/
def dissent_penalty (isMalicious : Bool) (maliceMagnitude : Int) : Int :=
  dissent_audit_penalty (if isMalicious then maliceMagnitude else 0)

theorem good_faith_dissent_zero_penalty (mag : Int) :
    dissent_penalty false mag = 0 := by
  unfold dissent_penalty
  dsimp
  exact good_faith_dissent_zero_penalty_grounded 0 (by omega)

abbrev Adv := ExploitVulnerability
abbrev AdvAp := bounty_reward

end Benefuture.Governance



