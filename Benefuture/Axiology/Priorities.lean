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
import Mathlib.Data.Finset.Card
import Mathlib.Algebra.Order.BigOperators.Group.List
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

/- --- 4b. Happiness components (L37) --- -/

/--
  [P] Experiential variety of a being's experience stream: distinct experiences / total.
  Reading of Di in L37 `H(t) := ∫Positive(Se) + BiasMitigation + Di` as variety within one
  life (a counter to hedonic adaptation), distinct from N, which scores outcomes against ℝ.
-/
noncomputable def experiential_variety {τ : Type*} [DecidableEq τ] (stream : List τ) : ℝ :=
  if stream = [] then 0 else (stream.toFinset.card : ℝ) / stream.length

/-- [R] A happiness source with the MM bias flag (dark triad, malicious pleasure; L37 BiasMitigation). -/
structure HappinessSource where
  intensity     : ℝ
  flaggedBiased : Bool

/--
  [R] Happiness score (L37): a positive structure. Σ of unflagged, non-negative source intensities
  plus experiential variety Di. Bias mitigation is done by MMs; Lean only honours their flag.
-/
noncomputable def happiness_score (sources : List HappinessSource) (di : ℝ) : ℝ :=
  (sources.map (fun s => if s.flaggedBiased then 0 else max 0 s.intensity)).sum + max 0 di

theorem happiness_score_nonneg (sources : List HappinessSource) (di : ℝ) :
    0 ≤ happiness_score sources di := by
  unfold happiness_score
  have h1 : 0 ≤ (sources.map (fun s => if s.flaggedBiased then 0 else max 0 s.intensity)).sum := by
    apply List.sum_nonneg
    intro x hx
    rw [List.mem_map] at hx
    obtain ⟨s, _, rfl⟩ := hx
    split_ifs
    · exact le_refl 0
    · exact le_max_left 0 _
  have h2 : 0 ≤ max 0 di := le_max_left 0 di
  linarith

/-- [R] THEOREM: MM-flagged biased happiness (e.g. malicious pleasure) contributes nothing. -/
theorem flagged_happiness_contributes_nothing (s : HappinessSource) (ss : List HappinessSource)
    (di : ℝ) (hs : s.flaggedBiased = true) :
    happiness_score (s :: ss) di = happiness_score ss di := by
  unfold happiness_score
  simp [hs]

theorem experiential_variety_le_one {τ : Type*} [DecidableEq τ] (stream : List τ) :
    experiential_variety stream ≤ 1 := by
  unfold experiential_variety
  split_ifs with h
  · norm_num
  · have hlen : (0 : ℝ) < stream.length := by
      exact_mod_cast List.length_pos_iff.mpr h
    rw [div_le_one hlen]
    exact_mod_cast List.toFinset_card_le (l := stream)

/-- THEOREM: Repeating one experience n times leaves variety at 1/n. -/
theorem repetitive_experience_variety {τ : Type*} [DecidableEq τ] (x : τ) (n : ℕ) (hn : 0 < n) :
    experiential_variety (List.replicate n x) = 1 / n := by
  unfold experiential_variety
  have hne : List.replicate n x ≠ [] := by
    simpa [List.replicate_eq_nil_iff] using Nat.pos_iff_ne_zero.mp hn
  rw [if_neg hne, List.length_replicate]
  have hcard : (List.replicate n x).toFinset.card = 1 := by
    rw [List.toFinset_replicate_of_ne_zero (Nat.pos_iff_ne_zero.mp hn), Finset.card_singleton]
  rw [hcard, Nat.cast_one]

/- --- 4c. Harm reference points (L54, author's reading) --- -/

/-- Rolling average of H over the preceding window. -/
noncomputable def rolling_average (window : List ℝ) : ℝ :=
  if window = [] then 0 else window.sum / window.length

/--
  [R] Happiness harm (↓H in L54): how far H falls below its rolling average.
  Coming down from a peak to at or above the average is not harm.
-/
noncomputable def h_harm (window : List ℝ) (h_now : ℝ) : ℝ :=
  max 0 (rolling_average window - h_now)

/--
  [R] Understanding harm (↓U in L54): how far U falls below the being's running maximum.
  Any forgetting of understood relationships is harm.
-/
noncomputable def u_harm (history : List ℝ) (u_now : ℝ) : ℝ :=
  max 0 (history.foldr max u_now - u_now)

theorem le_foldr_max_of_mem (l : List ℝ) (b x : ℝ) (hx : x ∈ l) : x ≤ l.foldr max b := by
  induction l with
  | nil => simp at hx
  | cons a t ih =>
    rw [List.foldr_cons]
    rcases List.mem_cons.mp hx with rfl | ht
    · exact le_max_left _ _
    · exact le_trans (ih ht) (le_max_right _ _)

theorem foldr_max_le (l : List ℝ) (b : ℝ) (h : ∀ x ∈ l, x ≤ b) : l.foldr max b ≤ b := by
  induction l with
  | nil => exact le_refl b
  | cons a t ih =>
    rw [List.foldr_cons]
    exact max_le (h a List.mem_cons_self) (ih (fun x hx => h x (List.mem_cons_of_mem a hx)))

/-- [R] THEOREM: Forgetting is harm. If U falls below any earlier level, U-harm is positive. -/
theorem forgetting_is_harm (history : List ℝ) (u_now u : ℝ) (hu : u ∈ history) (hlt : u_now < u) :
    0 < u_harm history u_now := by
  unfold u_harm
  have := le_foldr_max_of_mem history u_now u hu
  exact lt_max_of_lt_right (by linarith)

/-- [R] THEOREM: U at its running maximum carries no U-harm. -/
theorem u_at_max_no_harm (history : List ℝ) (u_now : ℝ) (h : ∀ x ∈ history, x ≤ u_now) :
    u_harm history u_now = 0 := by
  unfold u_harm
  have := foldr_max_le history u_now h
  exact max_eq_left (by linarith)

/-- [R] THEOREM: H at or above its rolling average carries no H-harm. -/
theorem h_at_or_above_average_no_harm (window : List ℝ) (h_now : ℝ)
    (h : rolling_average window ≤ h_now) : h_harm window h_now = 0 := by
  unfold h_harm
  exact max_eq_left (by linarith)

/--
  [R] THEOREM: Coming down from a giddy rush is not harm. After a window [1, 1, 1, 5],
  H falling from 5 to 2 sits at the rolling average, so H-harm is 0.
-/
theorem coming_down_not_harm : h_harm [1, 1, 1, 5] 2 = 0 := by
  apply h_at_or_above_average_no_harm
  unfold rolling_average
  norm_num

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
noncomputable def compute_harm_weight (hp : HarmProfile) (p : GovParams) : ℝ :=
  -- One weight per tier from `harmSchedule`; NHa_Estd carries weight 0 by L61 and is omitted.
  let items := zip_priority_weights [
    hp.irreparable,
    hp.irreversible,
    hp.longterm,
    hp.passing,
    hp.timeLoss,
    hp.nhaPredicted,
    hp.culturalOffence
  ] harmSchedule
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
