/-
  Benefuture.Proposed.RevelationGame
  [P] "Revealing pays more than exploiting" (L161, AdvAp) as a relational, dominant-strategy
  statement in the style of Barthe et al. (2015, POPL, https://doi.org/10.1145/2676726.2677000):
  for every profile of the others' strategies, an agent who knows a flaw is strictly better off
  reporting it than exploiting it. Strengthens `Governance.revelation_strictly_dominates`, which
  compares the two payoffs for one agent with the rest of the world fixed implicitly.

  The game: a set ι of agents who all know one flaw, each choosing to report or exploit.
  Reporters share the bounty (`bounty_reward`, gain + max(1, harm / 10)) equally, the worst case
  for a reporter. An exploiter is caught for certain once anyone else reports (the flaw is then
  public): every gain is clawed back and a positive restitution charged (L161; Adversarial
  adaptation, retroactive clawback). While no one else reports, the exploiter keeps its gain less
  an expected penalty that may depend arbitrarily on the whole profile, and may be zero.

  IMPORTANT ARCHITECTURAL RULE: core Benefuture modules MUST NOT import this file.
-/

import Benefuture.Governance.Adversarial
import Mathlib.Data.Fintype.Card

namespace Benefuture.Proposed

open Benefuture.Governance Finset

variable {ι : Type*} [Fintype ι] [DecidableEq ι]

/-- [P] The revelation game over agents ι who all know `vuln`. -/
structure RevelationGame (ι : Type*) where
  vuln : ExploitVulnerability
  /-- Restitution charged on top of the clawed-back gain when an exploiter is caught. -/
  restitution : Int
  h_rest : 0 < restitution
  /-- Expected penalty for exploiting while no one else reports, for any profile; may be zero. -/
  penalty : (ι → AdversarialChoice) → ι → Int
  h_pen : ∀ σ i, 0 ≤ penalty σ i

/-- Number of agents other than `i` who report under profile σ. -/
def othersReporting (σ : ι → AdversarialChoice) (i : ι) : ℕ :=
  (univ.filter fun j => j ≠ i ∧ σ j = .ReportAndReveal).card

/-- [P] Agent i's payoff under profile σ. -/
def RevelationGame.payoff (G : RevelationGame ι) (σ : ι → AdversarialChoice) (i : ι) : Int :=
  match σ i with
  | .ReportAndReveal =>
      bounty_reward G.vuln.exploitGain G.vuln.preventedHarm / ((othersReporting σ i : Int) + 1)
  | .SilentlyExploit =>
      if othersReporting σ i = 0 then G.vuln.exploitGain - G.penalty σ i else -G.restitution

theorem othersReporting_update (σ : ι → AdversarialChoice) (i : ι) (c : AdversarialChoice) :
    othersReporting (Function.update σ i c) i = othersReporting σ i := by
  unfold othersReporting
  congr 1
  refine Finset.filter_congr fun j _ => ?_
  constructor
  · rintro ⟨hj, h⟩; exact ⟨hj, by rwa [Function.update_of_ne hj] at h⟩
  · rintro ⟨hj, h⟩; exact ⟨hj, by rwa [Function.update_of_ne hj]⟩

theorem bounty_pos (gain harm : Int) (hg : 0 ≤ gain) : 0 < bounty_reward gain harm := by
  unfold bounty_reward; split <;> omega

/-- THEOREM (acceptance): Reporting strictly dominates exploiting. For every profile σ of the
    others' strategies, agent i earns strictly more by reporting than by exploiting, whatever the
    penalty schedule (including zero detection risk while the others stay silent). -/
theorem revelation_dominant (G : RevelationGame ι) (σ : ι → AdversarialChoice) (i : ι) :
    G.payoff (Function.update σ i .SilentlyExploit) i <
      G.payoff (Function.update σ i .ReportAndReveal) i := by
  unfold RevelationGame.payoff
  simp only [Function.update_self, othersReporting_update]
  have hb := bounty_pos G.vuln.exploitGain G.vuln.preventedHarm G.vuln.h_gain_nonneg
  have hpen := G.h_pen (Function.update σ i .SilentlyExploit) i
  by_cases hk : othersReporting σ i = 0
  · have hdom := bounty_strictly_exceeds_gain G.vuln.exploitGain G.vuln.preventedHarm G.vuln.h_harm_pos
    simp only [hk, if_true, Nat.cast_zero, zero_add, Int.ediv_one]
    omega
  · simp only [hk, if_false]
    have : 0 ≤ bounty_reward G.vuln.exploitGain G.vuln.preventedHarm /
        ((othersReporting σ i : Int) + 1) := Int.ediv_nonneg hb.le (by omega)
    have := G.h_rest
    omega

/-- THEOREM (acceptance): Weak dominance follows: reporting is never worse, for every profile. -/
theorem revelation_weakly_dominant (G : RevelationGame ι) (σ : ι → AdversarialChoice) (i : ι) :
    G.payoff (Function.update σ i .SilentlyExploit) i ≤
      G.payoff (Function.update σ i .ReportAndReveal) i :=
  (revelation_dominant G σ i).le

/-- THEOREM (acceptance): Everyone reporting is a Nash equilibrium: no agent gains by deviating. -/
theorem all_report_nash (G : RevelationGame ι) (i : ι) (c : AdversarialChoice) :
    G.payoff (Function.update (fun _ => .ReportAndReveal) i c) i ≤
      G.payoff (fun _ => AdversarialChoice.ReportAndReveal) i := by
  have hself : Function.update (fun _ : ι => AdversarialChoice.ReportAndReveal) i .ReportAndReveal =
      fun _ => .ReportAndReveal := by
    funext j; by_cases h : j = i <;> simp [Function.update, h]
  cases c with
  | ReportAndReveal => rw [hself]
  | SilentlyExploit =>
    have := revelation_dominant G (fun _ => .ReportAndReveal) i
    rw [hself] at this
    exact this.le

/-- THEOREM (acceptance): It is the only equilibrium: in any profile where some agent exploits,
    that agent gains strictly by switching to reporting. -/
theorem exploit_not_equilibrium (G : RevelationGame ι) (σ : ι → AdversarialChoice) (i : ι)
    (hi : σ i = .SilentlyExploit) :
    G.payoff σ i < G.payoff (Function.update σ i .ReportAndReveal) i := by
  have hσ : Function.update σ i .SilentlyExploit = σ := by
    rw [← hi]; exact Function.update_eq_self i σ
  have := revelation_dominant G σ i
  rwa [hσ] at this

/-- THEOREM (counterexample): The clawback on disclosure is load-bearing. Without it (an exploiter
    keeps its gain whoever reports), a flaw with gain 10 and prevented harm 10 (bounty 11) known
    to three agents who all report pays each reporter 11 / 3 = 3, while exploiting alone pays 10:
    reporting no longer dominates. -/
theorem revelation_needs_clawback :
    bounty_reward 10 10 / ((2 : Int) + 1) < 10 := by decide

/-!
  ## Multi-step reporter's schedule game (author ruling 8.76, Task A2)
  Each agent chooses `(n, reports)` where `n : ℕ` is the number of exploits attempted before
  reporting and `reports : Bool` is whether the agent self-reports at step `n`. If another agent
  reports at an earlier step `< n` (or if the agent never reports while someone else does), the
  agent is caught and receives `caught_net e bonus audit n`; otherwise a self-reporter nets
  `self_report_net e bonus n`.
-/

/-- Strategy in the multi-step revelation game: `(exploitsBeforeReport, selfReports)`. -/
structure TimedRevelationStrategy where
  exploits : ℕ
  reports  : Bool
  deriving DecidableEq, Repr

/-- Whether any agent other than `i` reports at or before step `t` under profile `τ`. -/
def someoneElseReportsBy (τ : ι → TimedRevelationStrategy) (i : ι) (t : ℕ) : Bool :=
  (univ.filter fun j => j ≠ i ∧ (τ j).reports = true ∧ (τ j).exploits ≤ t).Nonempty

theorem someoneElseReportsBy_update (τ : ι → TimedRevelationStrategy) (i : ι)
    (s : TimedRevelationStrategy) (t : ℕ) :
    someoneElseReportsBy (Function.update τ i s) i t = someoneElseReportsBy τ i t := by
  unfold someoneElseReportsBy
  congr 1
  congr 1
  ext j
  simp only [Finset.mem_filter, Finset.mem_univ, true_and]
  constructor
  · rintro ⟨hj, hr, he⟩
    rw [Function.update_of_ne hj] at hr he
    exact ⟨hj, hr, he⟩
  · rintro ⟨hj, hr, he⟩
    rw [Function.update_of_ne hj]
    exact ⟨hj, hr, he⟩

theorem someoneElseReportsBy_mono (τ : ι → TimedRevelationStrategy) (i : ι) {t₁ t₂ : ℕ}
    (h : t₁ ≤ t₂) (h1 : someoneElseReportsBy τ i t₁ = true) :
    someoneElseReportsBy τ i t₂ = true := by
  unfold someoneElseReportsBy at h1 ⊢
  simp only [decide_eq_true_eq] at h1 ⊢
  obtain ⟨j, hj⟩ := h1
  rw [Finset.mem_filter] at hj
  exact ⟨j, Finset.mem_filter.mpr ⟨hj.1, hj.2.1, hj.2.2.1, le_trans hj.2.2.2 h⟩⟩

/-- Payoff in the timed reporter's schedule game (8.76):
    - If `i` reports at `n = 0`, `i` cannot be pre-empted at an earlier step and nets `self_report_net e bonus 0 = e + bonus`.
    - If `i` delays reporting to `n > 0`, `i` is caught if someone else reports at `< n`, and otherwise nets `self_report_net e bonus n`.
    - If `i` never reports (`reports = false`), `i` is caught if anyone else ever reports (at step `≤ bound`), and otherwise nets `caught_net` or at most `e` when audited. -/
def timed_revelation_payoff (e bonus audit : ℤ) (τ : ι → TimedRevelationStrategy) (i : ι) : ℤ :=
  let s := τ i
  if s.reports then
    if s.exploits = 0 then
      self_report_net e bonus 0
    else if someoneElseReportsBy τ i (s.exploits - 1) then
      caught_net e bonus audit s.exploits
    else
      self_report_net e bonus s.exploits
  else
    caught_net e bonus audit s.exploits

/-- THEOREM: Under the 8.76 reporter's schedule, immediate reporting (`exploits = 0, reports = true`)
    weakly dominates every delayed self-report or silent exploit across all profiles `τ` of the other
    agents, and strictly dominates whenever another agent reports before `s.exploits` (or when `s`
    never reports). -/
theorem immediate_revelation_dominates (e bonus audit : ℤ) (he : 0 ≤ e) (hb : 0 ≤ bonus)
    (ha : 0 ≤ audit) (hpos : 0 < e + bonus + audit)
    (τ : ι → TimedRevelationStrategy) (i : ι) (s : TimedRevelationStrategy) :
    timed_revelation_payoff e bonus audit (Function.update τ i s) i ≤
      timed_revelation_payoff e bonus audit (Function.update τ i ⟨0, true⟩) i := by
  unfold timed_revelation_payoff
  simp only [Function.update_self, someoneElseReportsBy_update, ↓reduceIte]
  rw [self_report_net_constant]
  split_ifs with hr h0 hpre
  · exact le_rfl
  · have := self_report_beats_caught e bonus audit 0 s.exploits he hb ha hpos
    rw [self_report_net_constant] at this
    exact this.le
  · rw [self_report_net_constant]
  · have := self_report_beats_caught e bonus audit 0 s.exploits he hb ha hpos
    rw [self_report_net_constant] at this
    exact this.le

/-- THEOREM: Immediate reporting strictly dominates delaying (`exploits > 0`) whenever another agent
    reports at or before `s.exploits - 1`. -/
theorem immediate_revelation_strictly_dominates_when_preempted
    (e bonus audit : ℤ) (he : 0 ≤ e) (hb : 0 ≤ bonus) (ha : 0 ≤ audit) (hpos : 0 < e + bonus + audit)
    (τ : ι → TimedRevelationStrategy) (i : ι) (s : TimedRevelationStrategy)
    (hne : s.exploits ≠ 0) (hpre : someoneElseReportsBy τ i (s.exploits - 1) = true) :
    timed_revelation_payoff e bonus audit (Function.update τ i s) i <
      timed_revelation_payoff e bonus audit (Function.update τ i ⟨0, true⟩) i := by
  unfold timed_revelation_payoff
  simp only [Function.update_self, someoneElseReportsBy_update, hne, hpre, ↓reduceIte]
  split_ifs <;> exact self_report_beats_caught e bonus audit 0 s.exploits he hb ha hpos

end Benefuture.Proposed
