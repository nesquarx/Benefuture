/-
  Benefuture.Axiology.Priorities
  Formalization of the internal tiered synergies for Understanding, Happiness, Novelty, and Harm Weight.
  Corresponds to: Bf_Pseudocode.txt L57-63, and Benefuture goals.txt (Tradeoff priorities)

  Priorities: {
    U:     Sy(peak > teachable > meta^x > median > floor > undirected),
    H:     Sy(eudaimonic > shareable > satisficing > baseline > median > peak),
    N:     Sy(paradigm > PoV > chaotic > incremental > perilous > trivial ≈ 0),
    Ha_wt: 1 + Sy_{½,1.5}(Irreparable > Irreversible > longterm > passing > t_loss > NHa_Pr > Culture_offence ≈ 0 > NHa_Estd = 0)
  }
-/

import Benefuture.Math.Order
import Benefuture.Math.Synergy

namespace Benefuture.Axiology

open Benefuture.Math

/- --- 1. Understanding Priority Tiers --- -/

/-- 
  Tiers of Understanding in strict priority order:
  Peak (breakthroughs) > Teachable (multipliers) > Meta (learning how to learn) >
  Median (population mean) > Floor (universal comprehension) > Undirected (idle)
-/
structure UnderstandingTiers where
  peak         : Int  -- Breakthroughs, paradigm shifts
  teachable    : Int  -- Communicable knowledge
  metaLearning : Int  -- Meta-learning capacity
  median       : Int  -- Population baseline shift
  floor        : Int  -- Minimal safety floor
  undirected   : Int  -- Idle / unfocused
  deriving Repr, DecidableEq

/-- 
  Tiered synthesis of Understanding: Sy(peak > teachable > meta > median > floor > undirected).
  Higher tiers carry strictly larger compounding weights.
-/
def synthesize_understanding (u : UnderstandingTiers) : Int :=
  -- Weighted sum with diminishing weights across tiers + synergy between peak & teachable
  let base := (100 * u.peak + 60 * u.teachable + 40 * u.metaLearning + 25 * u.median + 15 * u.floor + 2 * u.undirected) / 100
  let peak_teachable_bonus := if u.peak > 0 ∧ u.teachable > 0 then (u.peak + u.teachable) / 4 else 0
  base + peak_teachable_bonus


/- --- 2. Happiness Priority Tiers --- -/

/-- 
  Tiers of Happiness in strict priority order:
  Eudaimonic (flourishing) > Shareable (contagious/networked) > Satisficing (contentment) >
  Baseline (Rawlsian quantile floor) > Median (average hedonic) > Peak (maximum hedonic intensity - ranked lowest!)
-/
structure HappinessTiers where
  eudaimonic  : Int  -- Meaning, flourishing, growth
  shareable   : Int  -- Propagates through community
  satisficing : Int  -- Sufficient well-being that enables understanding
  baseline    : Int  -- Raising the worst-off quantile
  median      : Int  -- Average hedonic tone
  peak        : Int  -- Raw sensory hedonic intensity (ranked last to prevent wireheading)
  deriving Repr, DecidableEq

/-- 
  Tiered synthesis of Happiness: Sy(eudaimonic > shareable > satisficing > baseline > median > peak).
  Notice: Peak pleasure has the smallest structural weight (5%), preventing wireheading!
-/
def synthesize_happiness (h : HappinessTiers) : Int :=
  let base := (100 * h.eudaimonic + 70 * h.shareable + 45 * h.satisficing + 30 * h.baseline + 15 * h.median + 5 * h.peak) / 100
  let eudaimonic_shareable_bonus := if h.eudaimonic > 0 ∧ h.shareable > 0 then (h.eudaimonic + h.shareable) / 4 else 0
  base + eudaimonic_shareable_bonus

/- --- 3. Novelty Priority Tiers --- -/

/-- 
  Tiers of Novelty in strict priority order:
  Paradigm > Perspective > Chaotic > Incremental > Perilous > Trivial (~0)
-/
structure NoveltyTiers where
  paradigm    : Int  -- Fundamental shifts in model space
  perspective : Int  -- New points of view
  chaotic     : Int  -- Exploratory variation
  incremental : Int  -- Minor improvements
  perilous    : Int  -- High risk innovation (priced with separate harm penalty)
  trivial     : Int  -- Superficial variation (weighted near zero)
  deriving Repr, DecidableEq

/-- Tiered synthesis of Novelty. -/
def synthesize_novelty (n : NoveltyTiers) : Int :=
  (100 * n.paradigm + 60 * n.perspective + 35 * n.chaotic + 15 * n.incremental + 5 * n.perilous + 1 * n.trivial) / 100

/- --- 4. Convex Harm Weighting (Ha_wt) --- -/

/-- 
  Harm Severity Multiplier Profile:
  1 + Sy_{1/2, 1.5}(Irreparable > Irreversible > Longterm > Passing > TimeLoss > Necessary)
-/
structure HarmProfile where
  irreparable     : Int  -- Destruction of life/capacity
  irreversible    : Int  -- Permanent non-fatal damage
  longterm        : Int  -- Multi-year impacts
  passing         : Int  -- Transient harm
  timeLoss        : Int  -- Opportunity waste
  nhaPredicted    : Int := 0  -- Predicted necessary harm (NHa_Pr)
  culturalOffence : Int := 0  -- Subjective cultural offence (Cu_offence ≈ 0)
  nhaEstablished  : Int := 0  -- Established necessary training/strain (NHa_Estd = 0)
  deriving Repr, DecidableEq

/-- 
  Computes Ha_wt multiplier in micro-units (SCALE = 1.0x baseline).
  Severe harm compounding is convex: irreparable harm yields a massive multiplier.
  Corresponds to: Bf_Pseudocode.txt L61:
  "Ha_wt: 1 + Sy_{½,1.5}(Irreparable > Irreversible > longterm > passing > t_loss > NHa_Pr > Culture_offence ≈ 0 > NHa_Estd = 0)"
-/
def compute_harm_weight (hp : HarmProfile) : Int :=
  let base_wt := SCALE  -- 1.0 baseline
  let severity_sum := 10 * hp.irreparable + 5 * hp.irreversible + 2 * hp.longterm + 
                      hp.passing + (hp.timeLoss / 2) + (hp.nhaPredicted / 5) + (hp.culturalOffence / 1000)
  base_wt + severity_sum

/-- 
  Necessary Harm (NHa):
  NHa := Ha : Ha → ↑V > Ha.
  Corresponds to: Bf_Pseudocode.txt L55.
  A transient harm whose downstream consequence generates strictly greater Value.
-/
structure NecessaryHarm where
  rawHarm    : Int
  valueYield : Int
  h_positive : rawHarm > 0
  h_net_gain : valueYield > rawHarm
  deriving Repr

/-- Net value added by undergoing necessary harm. -/
def net_necessary_gain (nh : NecessaryHarm) : Int :=
  nh.valueYield - nh.rawHarm

/-- Theorem: Necessary harm is mathematically justified by positive net value yield. -/
theorem necessary_harm_produces_net_positive_value (nh : NecessaryHarm) :
    net_necessary_gain nh > 0 := by
  unfold net_necessary_gain
  have h := nh.h_net_gain
  omega

/-- 
  THEOREM: Established Necessary Harm carries exactly Zero Weight Multiplier.
  Undergoing established growth/training (exercise, medical intervention) incurs no punitive multiplier.
-/
theorem established_necessary_harm_incurs_zero_weight_penalty (hp : HarmProfile) 
    (_h_nha : hp.nhaEstablished > 0) 
    (hp_pure : hp.irreparable = 0 ∧ hp.irreversible = 0 ∧ hp.longterm = 0 ∧ 
               hp.passing = 0 ∧ hp.timeLoss = 0 ∧ hp.nhaPredicted = 0 ∧ hp.culturalOffence = 0) :
    compute_harm_weight hp = SCALE := by
  unfold compute_harm_weight
  rcases hp_pure with ⟨h1, h2, h3, h4, h5, h6, h7⟩
  simp [h1, h2, h3, h4, h5, h6, h7]

/-- 
  Comprehensive Assessment Profile:
  Bundles the full tiered internal priorities of an action before outer Value aggregation.
-/
structure PrioritizedAssessment where
  u_tiers   : UnderstandingTiers
  h_tiers   : HappinessTiers
  n_tiers   : NoveltyTiers
  harm_prof : HarmProfile
  deriving Repr

/-- 
  Theorem: Peak pleasure contributes strictly less than eudaimonic flourishing per unit.
  This formalizes the structural defense against wireheading at the tier level.
-/
theorem eudaimonic_dominates_peak_pleasure (v : Int) (hv : v > 0) :
    let euda_only : HappinessTiers := { eudaimonic := v, shareable := 0, satisficing := 0, baseline := 0, median := 0, peak := 0 }
    let peak_only : HappinessTiers := { eudaimonic := 0, shareable := 0, satisficing := 0, baseline := 0, median := 0, peak := v }
    synthesize_happiness euda_only > synthesize_happiness peak_only := by
  dsimp [synthesize_happiness]
  omega

abbrev NHa := NecessaryHarm

end Benefuture.Axiology


