/-
  Benefuture.Axiology.Priorities
  Formalization of internal tiered priorities for Understanding (U), Happiness (H),
  Novelty (N), and Harm Weight (Ha_wt) using Sy over ℝ and ParamSchedule.
  Corresponds to: Bf_Pseudocode.txt L55, L57-63.
  
  "Priorities: {
     U:     Sy(peak > teachable > meta^x > median > floor > undirected),
     H:     Sy(eudaimonic > shareable > satisficing > baseline > median > peak),
     N:     Sy(paradigm > PoV > chaotic > incremental > perilous > trivial ≈ 0),
     Ha_wt: 1 + Sy_{½,1.5}(Irreparable > Irreversible > longterm > passing > t_loss > NHa_Pr > Culture_offence ≈ 0 > NHa_Estd = 0)
   }"
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Linarith
import Benefuture.Math.Order
import Benefuture.Math.Synergy

namespace Benefuture.Axiology

open Benefuture.Math

/- --- 1. Understanding Priority Tiers (L57) --- -/

/-- 
  [R] Tiers of Understanding in strict priority order (L57):
  Peak (breakthroughs) > Teachable (multipliers) > Meta (learning how to learn) >
  Median (population mean) > Floor (universal comprehension) > Undirected (idle)
-/
structure UnderstandingTiers where
  peak         : ℝ  -- Breakthroughs, paradigm shifts
  teachable    : ℝ  -- Communicable knowledge
  metaLearning : ℝ  -- Meta-learning capacity
  median       : ℝ  -- Population baseline shift
  floor        : ℝ  -- Minimal safety floor
  undirected   : ℝ  -- Idle / unfocused

/-- 
  [R] Tiered synthesis of Understanding: Sy(peak > teachable > meta > median > floor > undirected).
  Weights are taken strictly from a ParamSchedule, pairing items by priority.
-/
noncomputable def synthesize_understanding (u : UnderstandingTiers) (sched : ParamSchedule) (p : GovParams) : ℝ :=
  let items := zip_priority_weights [u.peak, u.teachable, u.metaLearning, u.median, u.floor, u.undirected] sched
  net_synergy items p

/- --- 2. Happiness Priority Tiers (L58) --- -/

/-- 
  [R] Tiers of Happiness in strict priority order (L58):
  Eudaimonic (flourishing) > Shareable (contagious/networked) > Satisficing (contentment) >
  Baseline (Rawlsian quantile floor) > Median (average hedonic) > Peak (maximum hedonic intensity - ranked lowest!)
-/
structure HappinessTiers where
  eudaimonic  : ℝ  -- Meaning, flourishing, growth
  shareable   : ℝ  -- Propagates through community
  satisficing : ℝ  -- Sufficient well-being that enables understanding
  baseline    : ℝ  -- Raising the worst-off quantile
  median      : ℝ  -- Average hedonic tone
  peak        : ℝ  -- Raw sensory hedonic intensity (ranked last to prevent wireheading)

/-- 
  [R] Tiered synthesis of Happiness: Sy(eudaimonic > shareable > satisficing > baseline > median > peak).
  Notice: Peak sensory pleasure has the lowest structural priority, preventing wireheading.
-/
noncomputable def synthesize_happiness (h : HappinessTiers) (sched : ParamSchedule) (p : GovParams) : ℝ :=
  let items := zip_priority_weights [h.eudaimonic, h.shareable, h.satisficing, h.baseline, h.median, h.peak] sched
  net_synergy items p

/- --- 3. Novelty Priority Tiers (L59) --- -/

/-- 
  [R] Tiers of Novelty in strict priority order (L59):
  Paradigm > Perspective > Chaotic > Incremental > Perilous > Trivial (~0)
-/
structure NoveltyTiers where
  paradigm    : ℝ  -- Fundamental shifts in model space
  perspective : ℝ  -- New points of view (PoV)
  chaotic     : ℝ  -- Exploratory variation
  incremental : ℝ  -- Minor improvements
  perilous    : ℝ  -- High risk innovation (priced with separate harm penalty)
  trivial     : ℝ  -- Superficial variation (weighted near zero)

/-- [R] Tiered synthesis of Novelty: Sy(paradigm > PoV > chaotic > incremental > perilous > trivial). -/
noncomputable def synthesize_novelty (n : NoveltyTiers) (sched : ParamSchedule) (p : GovParams) : ℝ :=
  let items := zip_priority_weights [n.paradigm, n.perspective, n.chaotic, n.incremental, n.perilous, n.trivial] sched
  net_synergy items p

/- --- 4. Distributional Push (pushDistr, L60) --- -/

/--
  [OPEN] Distributional Push: pushDistr(median, quantile_spread) ⇄ Sy(...) (L60).
  Represents distribution-wide optimization prioritizing the raising of the floor and lower quantiles
  over the unbounded elevation of top percentiles.
  Marked [OPEN] and unformalized in the core spec; requires detailed population distribution semantics
  to be modeled and evaluated in simulation.
-/
def pushDistr_unformalized_spec_note : String :=
  "[OPEN] pushDistr requires formal distribution-quantile mechanics deferred to simulation."

/- --- 5. Convex Harm Weighting (Ha_wt, L61) --- -/

/-- 
  [R] Harm Severity Profile:
  Evaluated across all tiers:
  Irreparable > Irreversible > Longterm > Passing > TimeLoss > NHa_Pr > CulturalOffence > NHa_Estd (=0).
-/
structure HarmProfile where
  irreparable     : ℝ  -- Destruction of life/capacity
  irreversible    : ℝ  -- Permanent non-fatal damage
  longterm        : ℝ  -- Multi-year impacts
  passing         : ℝ  -- Transient harm
  timeLoss        : ℝ  -- Opportunity waste
  nhaPredicted    : ℝ := 0  -- Predicted necessary harm (NHa_Pr)
  culturalOffence : ℝ := 0  -- Subjective cultural offence (Cu_offence ≈ 0)
  nhaEstablished  : ℝ := 0  -- Established necessary training/strain (NHa_Estd = 0)

/-- 
  [R] Computes Ha_wt multiplier (L61):
  Ha_wt := 1 + Sy_{½,1.5}(Irreparable > Irreversible > longterm > passing > t_loss > NHa_Pr > Culture_offence ≈ 0 > NHa_Estd = 0).
  -- SPEC-CHOICE: Sy_{½,1.5} (L61) read through the Sy_{κ,q₊} signature (L13): κ = ½, q₊ = 1.5.
  Severity magnitudes are non-negative, so they enter Φ₊; q₊ = 1.5 > 1 makes the score convex
  (Benefuture goals.txt: "1 plus a convex synergy score over the severity tiers").
  Earlier drafts read the subscripts as q₊ = 0.5, q₋ = 1.5, which made Ha_wt concave in severity.
-/
noncomputable def compute_harm_weight (hp : HarmProfile) (sched : ParamSchedule) (p : GovParams) : ℝ :=
  let items := zip_priority_weights [
    hp.irreparable,
    hp.irreversible,
    hp.longterm,
    hp.passing,
    hp.timeLoss,
    hp.nhaPredicted,
    hp.culturalOffence,
    0.0 -- Established necessary harm carries 0 weight (NHa_Estd = 0)
  ] sched
  -- Override parameters per L61: κ = ½, q₊ = 1.5
  let harm_params : GovParams := {
    p with
    kappa          := 0.5
    q_plus         := 1.5
    h_kappa_nonneg := by norm_num
    h_q_plus_pos   := by norm_num
  }
  1 + net_synergy items harm_params

/--
  THEOREM: Harm weighting is superlinear in severity. With q₊ = 1.5 (L61), doubling a tier's
  magnitude more than doubles its contribution: (2x)^{1.5} > 2·x^{1.5} for x > 0.
-/
theorem harm_tier_superlinear (x : ℝ) (hx : 0 < x) :
    2 * x ^ (1.5 : ℝ) < (2 * x) ^ (1.5 : ℝ) := by
  rw [Real.mul_rpow (by norm_num) hx.le]
  have h2 : (2 : ℝ) < 2 ^ (1.5 : ℝ) := by
    have := Real.rpow_lt_rpow_of_exponent_lt (by norm_num : (1 : ℝ) < 2) (by norm_num : (1 : ℝ) < 1.5)
    simpa using this
  exact mul_lt_mul_of_pos_right h2 (Real.rpow_pos_of_pos hx _)

/- --- 6. Necessary Harm (NHa, L55) --- -/

/-- 
  [R] Necessary Harm (NHa):
  NHa := Ha : Ha → ↑V > Ha (L55).
  A transient harm whose downstream consequence generates strictly greater Value.
-/
structure NecessaryHarm where
  rawHarm    : ℝ
  valueYield : ℝ
  h_positive : 0 < rawHarm
  h_net_gain : rawHarm < valueYield

/-- Net value added by undergoing necessary harm: ↑V - Ha. -/
def net_necessary_gain (nh : NecessaryHarm) : ℝ :=
  nh.valueYield - nh.rawHarm

/-- Theorem: Necessary harm is justified by positive net value yield. -/
theorem necessary_harm_produces_net_positive_value (nh : NecessaryHarm) :
    0 < net_necessary_gain nh := by
  unfold net_necessary_gain
  have h := nh.h_net_gain
  linarith

/-- 
  Comprehensive Assessment Profile:
  Bundles the full tiered internal priorities of an action before outer Value aggregation.
-/
structure PrioritizedAssessment where
  u_tiers   : UnderstandingTiers
  h_tiers   : HappinessTiers
  n_tiers   : NoveltyTiers
  harm_prof : HarmProfile

abbrev NHa := NecessaryHarm

end Benefuture.Axiology
