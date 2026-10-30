/-
  Benefuture.Axiology.Priorities
  Formalization of internal tiered priorities for Understanding (U), Happiness (H),
  Novelty (N), and Harm Weight (Ha_wt) using Sy over ℝ and ParamSchedule.
  Corresponds to: Bf_Pseudocode.txt L55, L57-63 (U L58, H L59, N L60, Ha_wt L61, pushDistr L62).
  
  "Priorities: {
     U:     Sy(peak > teachable > meta^x > median > floor > undirected),
     H:     Sy(eudaimonic > shareable > satisficing > baseline > median > peak),
     N:     Sy(paradigm > PoV > chaotic > incremental > perilous > trivial ≈ 0),
     Ha_wt: 1 + Sy_{κ=½,q₊=1.5}(Irreparable > Irreversible > longterm > passing > t_loss > NHa_Pr > Culture«Cu»_offence ≈ 0 > NHa_Estd = 0),
     pushDistr(Σ_{b ∈ B(t)} ΔW((U, convex), (H, concave), (Ha(¬NHa), convex))_lt | U > Ha > H, (N, norm(—^—)))
   }"
-/

import Mathlib.Data.Real.Basic
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Linarith
import Mathlib.Data.Finset.Card
import Mathlib.Algebra.Order.BigOperators.Group.List
import Mathlib.Tactic.LinearCombination
import Benefuture.Math.Order
import Benefuture.Math.Synergy

namespace Benefuture.Axiology

open Benefuture.Math

/- --- 1. Understanding Priority Tiers (L58) --- -/

/-- 
  [R] Tiers of Understanding in strict priority order (L58):
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

/- --- 2. Happiness Priority Tiers (L59) --- -/

/-- 
  [R] Tiers of Happiness in strict priority order (L59):
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

/- --- 3. Novelty Priority Tiers (L60) --- -/

/-- 
  [R] Tiers of Novelty in strict priority order (L60):
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

/- --- 4. Distributional Push (pushDistr, L62) --- -/

/--
  [OPEN] Distributional Push: pushDistr(median, quantile_spread) ⇄ Sy(...) (L62).
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
  Reading of the last term of L37 `H(t) := ∫Positive(Se(St(t))) dSt + BiasMitigation + N(Se)`
  (written Di in earlier drafts) as variety within one life, the novelty of the being's own
  experience (a counter to hedonic adaptation), distinct from N over outcomes against ℝ.
-/
noncomputable def experiential_variety {τ : Type*} [DecidableEq τ] (stream : List τ) : ℝ :=
  if stream = [] then 0 else (stream.toFinset.card : ℝ) / stream.length

/--
  [R] Bias claim on a happiness source (L37 BiasMitigation): measurement metadata.
  `degree` b ∈ [0, 1]: how far the source is misaligned with long-run U and H (malice, addictive
  doom-scrolling, impairing stupor). It is claimed independently of tier: peak-tier sources are
  already down-weighted by the L59 priorities and must not be discounted again for being peaks.
  `confidence` c ∈ [0, 1]: confidence in the claim.
-/
structure BiasClaim where
  degree     : ℝ
  confidence : ℝ
  h_degree   : 0 ≤ degree ∧ degree ≤ 1
  h_conf     : 0 ≤ confidence ∧ confidence ≤ 1

/-- No bias claimed. -/
def BiasClaim.none : BiasClaim := ⟨0, 0, by norm_num, by norm_num⟩

/-- Effective discount c · b ∈ [0, 1]. -/
def BiasClaim.discount (b : BiasClaim) : ℝ := b.confidence * b.degree

theorem BiasClaim.discount_mem (b : BiasClaim) : 0 ≤ b.discount ∧ b.discount ≤ 1 := by
  unfold BiasClaim.discount
  obtain ⟨hd0, hd1⟩ := b.h_degree
  obtain ⟨hc0, hc1⟩ := b.h_conf
  exact ⟨mul_nonneg hc0 hd0, mul_le_one₀ hc1 hd0 hd1⟩

/-- [R] Kind of a happiness source (measurement metadata); the L59 kind tiers (decision 6c). -/
inductive HappinessKind where
  | eudaimonic  : HappinessKind
  | shareable   : HappinessKind
  | satisficing : HappinessKind
  | peak        : HappinessKind
  deriving DecidableEq, Repr

/--
  [R] A happiness source: a measurement (intensity, kept raw) with its metadata, the bias claim
  and kind label. Metadata is produced by the measuring model alongside the measurement; H's
  definition (L37) only consumes it, so H makes no forward reference to MMs.
-/
structure HappinessSource where
  intensity : ℝ
  bias      : BiasClaim := BiasClaim.none
  kind      : HappinessKind := .satisficing

/-- ∫Positive(Se) (L37): sum of non-negative measured intensities. -/
noncomputable def positive_integral (sources : List HappinessSource) : ℝ :=
  (sources.map (fun s => max 0 s.intensity)).sum

/-- BiasMitigation (L37): the separate, non-positive correction −Σ c·b·intensity. -/
noncomputable def bias_mitigation (sources : List HappinessSource) : ℝ :=
  -(sources.map (fun s => s.bias.discount * max 0 s.intensity)).sum

/--
  [R] Happiness score (L37): H := ∫Positive(Se) + BiasMitigation + Di.
  Measurements stay raw; bias claims enter as a separate term, so they can be audited,
  contested and revised without touching what was measured.
-/
noncomputable def happiness_score (sources : List HappinessSource) (di : ℝ) : ℝ :=
  positive_integral sources + bias_mitigation sources + max 0 di

/-- THEOREM: Each source counts (1 − c·b) of its intensity. -/
theorem happiness_score_eq (sources : List HappinessSource) (di : ℝ) :
    happiness_score sources di =
      (sources.map (fun s => (1 - s.bias.discount) * max 0 s.intensity)).sum + max 0 di := by
  unfold happiness_score positive_integral bias_mitigation
  induction sources with
  | nil => simp
  | cons s ss ih =>
    simp only [List.map_cons, List.sum_cons]
    linear_combination ih

/-- THEOREM: The H score is a positive structure, whatever the bias claims. -/
theorem happiness_score_nonneg (sources : List HappinessSource) (di : ℝ) :
    0 ≤ happiness_score sources di := by
  rw [happiness_score_eq]
  have h1 : 0 ≤ (sources.map (fun s => (1 - s.bias.discount) * max 0 s.intensity)).sum := by
    apply List.sum_nonneg
    intro x hx
    rw [List.mem_map] at hx
    obtain ⟨s, _, rfl⟩ := hx
    exact mul_nonneg (by linarith [s.bias.discount_mem.2]) (le_max_left 0 _)
  linarith [le_max_left 0 di]

/-- THEOREM: A source with no bias claim counts its full measured intensity. -/
theorem unclaimed_source_counts_fully (i di : ℝ) :
    happiness_score [{ intensity := i, bias := BiasClaim.none }] di = max 0 i + max 0 di := by
  rw [happiness_score_eq]
  simp [BiasClaim.none, BiasClaim.discount]

/--
  THEOREM: Fully biased happiness claimed with full confidence (e.g. malicious pleasure)
  contributes nothing. The victim's harm still counts through Ha, so harm for pleasure is net negative.
-/
theorem fully_biased_contributes_nothing (s : HappinessSource) (ss : List HappinessSource) (di : ℝ)
    (hb : s.bias.degree = 1) (hc : s.bias.confidence = 1) :
    happiness_score (s :: ss) di = happiness_score ss di := by
  rw [happiness_score_eq, happiness_score_eq]
  simp [BiasClaim.discount, hb, hc]

/-- THEOREM: A larger effective bias discount never raises happiness. -/
theorem more_bias_less_happiness (i : ℝ) (b₁ b₂ : BiasClaim) (di : ℝ)
    (h : b₁.discount ≤ b₂.discount) :
    happiness_score [{ intensity := i, bias := b₂ }] di ≤
      happiness_score [{ intensity := i, bias := b₁ }] di := by
  rw [happiness_score_eq, happiness_score_eq]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero]
  have := le_max_left 0 i
  nlinarith

/-- [R] Bias-corrected happiness from sources of one kind. -/
noncomputable def kind_score (k : HappinessKind) (sources : List HappinessSource) : ℝ :=
  (sources.map (fun s => if s.kind = k then (1 - s.bias.discount) * max 0 s.intensity else 0)).sum

/--
  [P] A being's H tiers (L59, decision 6c): kind tiers from its labelled sources, distributional
  tiers (baseline = worse-off quantile floor, median) from the population's H scores.
  Experiential variety Di joins the eudaimonic tier (variety within a life as growth).
-/
noncomputable def happiness_tiers_of (sources : List HappinessSource) (di baseline median : ℝ) :
    HappinessTiers :=
  { eudaimonic := kind_score .eudaimonic sources + max 0 di,
    shareable := kind_score .shareable sources,
    satisficing := kind_score .satisficing sources,
    baseline := baseline,
    median := median,
    peak := kind_score .peak sources }

theorem kind_scores_sum (sources : List HappinessSource) :
    kind_score .eudaimonic sources + kind_score .shareable sources +
      kind_score .satisficing sources + kind_score .peak sources =
    (sources.map (fun s => (1 - s.bias.discount) * max 0 s.intensity)).sum := by
  induction sources with
  | nil => simp [kind_score]
  | cons s ss ih =>
    simp only [kind_score, List.map_cons, List.sum_cons] at ih ⊢
    cases hk : s.kind <;> simp <;> linarith

/--
  THEOREM: The kind tiers partition the H score: they sum exactly to the being's bias-corrected
  happiness, so labelling by kind neither loses nor double-counts any happiness.
-/
theorem kind_tiers_partition_happiness (sources : List HappinessSource) (di baseline median : ℝ) :
    (happiness_tiers_of sources di baseline median).eudaimonic +
      (happiness_tiers_of sources di baseline median).shareable +
      (happiness_tiers_of sources di baseline median).satisficing +
      (happiness_tiers_of sources di baseline median).peak =
    happiness_score sources di := by
  simp only [happiness_tiers_of]
  rw [happiness_score_eq, ← kind_scores_sum]
  ring

/-- [R] Kind of an understanding change (measurement metadata); the L58 kind tiers (decision 6c). -/
inductive UnderstandingKind where
  | peak         : UnderstandingKind
  | teachable    : UnderstandingKind
  | metaLearning : UnderstandingKind
  | undirected   : UnderstandingKind
  deriving DecidableEq, Repr

/-- [R] An assessed change in understanding with its kind label (metadata). -/
structure UnderstandingChange where
  amount : ℝ
  kind   : UnderstandingKind

/-- Sum of understanding changes of one kind. -/
noncomputable def u_kind_score (k : UnderstandingKind) (cs : List UnderstandingChange) : ℝ :=
  (cs.map (fun c => if c.kind = k then c.amount else 0)).sum

/--
  [P] A being's U tiers (L58, decision 6c): kind tiers from labelled changes, distributional tiers
  (median, floor) from the population's U distribution.
-/
noncomputable def understanding_tiers_of (cs : List UnderstandingChange) (median floor : ℝ) :
    UnderstandingTiers :=
  { peak := u_kind_score .peak cs, teachable := u_kind_score .teachable cs,
    metaLearning := u_kind_score .metaLearning cs, median := median, floor := floor,
    undirected := u_kind_score .undirected cs }

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
  rw [if_neg (List.cons_ne_nil _ _)]
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
