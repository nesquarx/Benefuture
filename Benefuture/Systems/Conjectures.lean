/-
  Benefuture.Systems.Conjectures
  [CONJ] Behavioural conjectures for simulation, stated as precise propositions over a simulation
  trace. They are definitions, not axioms and not theorems: nothing here is assumed or proved.
  A simulation implements `SimTrace` and tests each conjecture on its runs.

  The structural theorems elsewhere hold for every admissible parameter point; these conjectures
  concern dynamics (convergence, gaming, drift), which only simulation or field data can test.
-/

import Mathlib.Data.Real.Basic
import Benefuture.Systems.ParamSpace

namespace Benefuture.Systems

/-- [CONJ] Observables a simulation run records at each step t. -/
structure SimTrace where
  /-- Governed parameters (from `gov_run` / `perturb_run`). -/
  params             : ℕ → ParamVector
  /-- Population minimum and median of U and H. -/
  minU               : ℕ → ℝ
  minH               : ℕ → ℝ
  medianU            : ℕ → ℝ
  medianH            : ℕ → ℝ
  /-- Σ V of the chosen action, and the scope of ℝ (Perceivable ∪ Changeable). -/
  aggregateValue     : ℕ → ℝ
  realityScope       : ℕ → ℝ
  /-- Share of adversarial agents. -/
  adversaryShare     : ℝ
  /-- Predictive accuracy of the adopted MM and of the best MM available in its domain (L49). -/
  adoptedMMAccuracy  : ℕ → ℝ
  bestMMAccuracy     : ℕ → ℝ
  /-- |latent − observed| for the flourishing variables (Systems.State, Goodhart gap). -/
  latentObsGap       : ℕ → ℝ
  /-- Best available payoff from exploiting a flaw, and from revealing it (AdvAp, L160). -/
  exploitPayoff      : ℕ → ℝ
  revealPayoff       : ℕ → ℝ
  /-- Predicted and realised trajectory-level change in min U (↑min, L62). -/
  predictedMinUGain  : ℕ → ℝ
  realisedMinUGain   : ℕ → ℝ
  /-- Largest share of voting weight held by one delegate (L114). -/
  maxDelegateShare   : ℕ → ℝ
  /-- Mean H of the population (Repugnant-Conclusion drift). -/
  meanH              : ℕ → ℝ

/--
  [CONJ] MM competition converges (L49): the adopted model's accuracy approaches the best
  available, ∀ ε > 0, eventually within ε.
-/
def Conj_MMCompetitionConverges (tr : SimTrace) : Prop :=
  ∀ ε > 0, ∃ T, ∀ t ≥ T, tr.bestMMAccuracy t - tr.adoptedMMAccuracy t < ε

/--
  [CONJ] Goodhart reduction (L49–52, Systems.State): under MM competition and adversarial audits,
  the latent–observed gap does not grow over a window of length w.
-/
def Conj_GoodhartReduction (tr : SimTrace) (w : ℕ) : Prop :=
  ∀ t, tr.latentObsGap (t + w) ≤ tr.latentObsGap t

/--
  [CONJ] Gaming resistance (AdvAp, L160): revealing a flaw pays at least as much as exploiting it,
  at every step.
-/
def Conj_GamingResistance (tr : SimTrace) : Prop :=
  ∀ t, tr.exploitPayoff t ≤ tr.revealPayoff t

/--
  [CONJ] Robustness to adversaries: below an adversary share f*, Σ V of chosen actions stays positive
  and ℝ does not contract.
-/
def Conj_AdversarialRobustness (tr : SimTrace) (fStar : ℝ) : Prop :=
  tr.adversaryShare < fStar →
    ∀ t, 0 < tr.aggregateValue t ∧ tr.realityScope t ≤ tr.realityScope (t + 1)

/--
  [CONJ] Prediction fidelity for ↑min: realised gains in min U track predicted ones within η.
  `goal_G_sound` guarantees predicted (counterfactual) ↑min; this conjecture is what makes it hold in reality.
-/
def Conj_MinTracksPrediction (tr : SimTrace) (η : ℝ) : Prop :=
  ∀ t, |tr.realisedMinUGain t - tr.predictedMinUGain t| ≤ η

/--
  [CONJ] Floors rise: over every window of length w, min U and min H do not fall
  (L62 ↑min; Benefuture goals.txt: "increasing the … median and floor").
-/
def Conj_FloorsRise (tr : SimTrace) (w : ℕ) : Prop :=
  ∀ t, tr.minU t ≤ tr.minU (t + w) ∧ tr.minH t ≤ tr.minH (t + w)

/--
  [CONJ] No repugnant drift: population growth under G never lowers mean H over a window of
  length w by more than ε.
-/
def Conj_NoRepugnantDrift (tr : SimTrace) (w : ℕ) (ε : ℝ) : Prop :=
  ∀ t, tr.meanH t - ε ≤ tr.meanH (t + w)

/--
  [CONJ] Parameter stability under SigThGv (L157): governed parameters settle; each tracked
  field eventually moves by less than ε per step.
-/
def Conj_ParamStability (tr : SimTrace) (fields : List (ParamVector → ℝ)) : Prop :=
  ∀ ε > 0, ∃ T, ∀ t ≥ T, ∀ f ∈ fields, |f (tr.params (t + 1)) - f (tr.params t)| < ε

/--
  [CONJ] Delegation stays dispersed (L114): the largest delegate share stays at or below the
  governed cap plus a margin m (the proved bound is cap + one delegator's weight).
-/
def Conj_DelegationDispersed (tr : SimTrace) (m : ℝ) : Prop :=
  ∀ t, tr.maxDelegateShare t ≤ (tr.params t).deleg_cap + m

end Benefuture.Systems
