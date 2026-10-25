/-
  Benefuture.Proposed.PopulationDirection
  [P] Proposed population axiology by direction rather than by world-ranking.
  Corresponds to: Bf_Pseudocode.txt L54-55 (Ha, NHa), L62 (pushDistr), L68 (Bounds_B),
  L74 (G), L135 (Fr), L150 (Harm_Intv).

  Design decisions (from discussion with the framework author):
  1. Bf ranks actions, not worlds. V is per action; a being-level value exists only as an
     expected lifetime tally over Bounds_B, computed under the best available uplift policy.
  2. Existing beings may only be uplifted: removal is dominated whenever uplift is available, and
     cannot raise the floor, which is taken over the decision-time population. Fr is a subgoal
     (a fair-weather rule for action-space maximisation), not a filter on G; in tragic choices
     (trolley problems) the priorities decide.
  3. Withholding uplift is not Ha (no ↓U, ↓H); it is only comparatively worse under argmax.
  4. pushDistr is directional and assessed counterfactually (As, L48): range moves come first and
     skew counts only when the range change is not significant. ↑min is a hard constraint on G,
     held over the trajectory; inaction always satisfies it (its counterfactual is itself).
  5. ↑min may dip inside an NHa tunnel, provided the trajectory endpoint recovers within the
     prediction horizon (lt, L34). A stepwise filter would reject every such tunnel.
  6. Net-negative expected tallies never outweigh a positive population, whatever its size.
  7. Diversity counts distinct types: copies saturate, so numbers alone cannot buy it.

  IMPORTANT ARCHITECTURAL RULE:
  The core Benefuture modules MUST NOT import this file. This is a swappable proposed default.
-/

import Mathlib.Data.Real.Basic
import Mathlib.Data.Finset.Card
import Mathlib.Data.List.MinMax
import Mathlib.Data.List.FinRange
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.Order.BigOperators.Group.Finset
import Mathlib.Data.Real.Sqrt
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.IntervalCases
import Mathlib.Tactic.FinCases
import Mathlib.Tactic.Ring
import Benefuture.Ontology.Entity
import Benefuture.Axiology.Priorities
import Benefuture.Axiology.Value
import Benefuture.Subgoals.Freedom
import Benefuture.Systems.ParamSpace

namespace Benefuture.Proposed

open Benefuture.Math
open Benefuture.Ontology
open Benefuture.Axiology
open Benefuture.Subgoals
open Benefuture.Systems

/- --- 1. Harm and withholding (L54) --- -/

/--
  [P] Withholding uplift is not Ha (decision 3). Harm is measured against reference points
  (U: running maximum; H: rolling average; `u_harm`, `h_harm`). A being whose levels are
  unchanged at an unharmed state stays unharmed.
-/
theorem withholding_incurs_no_harm (history window : List ℝ) (u h : ℝ)
    (hu : ∀ x ∈ history, x ≤ u) (hh : rolling_average window ≤ h) :
    u_harm history u = 0 ∧ h_harm window h = 0 :=
  ⟨u_at_max_no_harm history u hu, h_at_or_above_average_no_harm window h hh⟩

/- --- 2. Directional pushDistr (L62) and Pareto dominance --- -/

/-- [P] Summary statistics of the population distributions, supplied by MetricModel. -/
structure DistrStats where
  skewU    : ℝ
  skewH    : ℝ
  skewHa   : ℝ
  normDevN : ℝ  -- deviation of N from the normal shape (|skew|, excess kurtosis)
  minU     : ℝ
  minH     : ℝ
  maxU     : ℝ
  maxH     : ℝ
  maxN     : ℝ
  maxHa    : ℝ
  minHa    : ℝ
  minN     : ℝ

/--
  [P] Progress vector from s₀ to s₁, oriented so that higher is better in every component:
  U, H toward left skew; Ha toward right skew; N toward normal; ↑(U, N, H)(max, min); ↓Ha(max, min).
  In G, s₀ is the counterfactual (after ¬A) and s₁ the outcome after A (As, L48).
-/
def progress (s₀ s₁ : DistrStats) : Fin 12 → ℝ :=
  ![s₀.skewU - s₁.skewU, s₀.skewH - s₁.skewH, s₁.skewHa - s₀.skewHa,
    s₀.normDevN - s₁.normDevN,
    s₁.minU - s₀.minU, s₁.minH - s₀.minH,
    s₁.maxU - s₀.maxU, s₁.maxH - s₀.maxH, s₁.maxN - s₀.maxN,
    s₀.maxHa - s₁.maxHa, s₀.minHa - s₁.minHa, s₁.minN - s₀.minN]

/-- [P] A step is pushDistr-aligned iff no component moves the wrong way. -/
def pushDistr_aligned (s₀ s₁ : DistrStats) : Prop :=
  ∀ i, 0 ≤ progress s₀ s₁ i

/-- [P] Pareto dominance: at least as good on every criterion, strictly better on one. -/
def pareto_dominates {k : ℕ} (p q : Fin k → ℝ) : Prop :=
  (∀ i, q i ≤ p i) ∧ ∃ i, q i < p i

theorem pareto_irrefl {k : ℕ} (p : Fin k → ℝ) : ¬ pareto_dominates p p := by
  rintro ⟨_, i, hi⟩
  exact lt_irrefl _ hi

theorem pareto_trans {k : ℕ} {p q r : Fin k → ℝ}
    (hpq : pareto_dominates p q) (hqr : pareto_dominates q r) : pareto_dominates p r := by
  obtain ⟨hle₁, _⟩ := hpq
  obtain ⟨hle₂, i, hi⟩ := hqr
  exact ⟨fun j => le_trans (hle₂ j) (hle₁ j), i, lt_of_lt_of_le hi (hle₁ i)⟩

open Classical in
/-- [P] Pareto filter: keep only candidates not dominated by another candidate. -/
noncomputable def pareto_front {k : ℕ} (ps : List (Fin k → ℝ)) : List (Fin k → ℝ) :=
  ps.filter (fun p => decide (¬ ∃ q ∈ ps, pareto_dominates q p))

theorem sum_lt_of_dominates {k : ℕ} {p q : Fin k → ℝ} (h : pareto_dominates q p) :
    ∑ i, p i < ∑ i, q i := by
  obtain ⟨hle, i, hi⟩ := h
  exact Finset.sum_lt_sum (fun j _ => hle j) ⟨i, Finset.mem_univ i, hi⟩

/--
  [P] THEOREM: The Pareto filter never empties a non-empty choice set.
  This is the "find ∧ max(⋂ ↑x)" step of Sy (L13): find the actions not dominated on the
  intersection of improvements, then maximise among them (Sy-weighted, [OPEN]).
-/
theorem pareto_front_nonempty {k : ℕ} (ps : List (Fin k → ℝ)) (hne : ps ≠ []) :
    pareto_front ps ≠ [] := by
  obtain ⟨p, hp⟩ : ∃ p, p ∈ ps.argmax (fun p => ∑ i, p i) := by
    cases h : ps.argmax (fun p => ∑ i, p i) with
    | none => exact absurd (List.argmax_eq_none.mp h) hne
    | some p => exact ⟨p, rfl⟩
  apply List.ne_nil_of_mem (a := p)
  unfold pareto_front
  rw [List.mem_filter]
  refine ⟨List.argmax_mem hp, ?_⟩
  simp only [decide_eq_true_eq]
  rintro ⟨q, hq, hdom⟩
  have h1 := List.le_of_mem_argmax hq hp
  have h2 := sum_lt_of_dominates hdom
  linarith

/- --- 2b. Skew direction computed from a population (L62) --- -/

/-- Population mean. -/
noncomputable def pop_mean (l : List ℝ) : ℝ :=
  l.sum / l.length

/-- Second central moment. -/
noncomputable def pop_m2 (l : List ℝ) : ℝ :=
  (l.map (fun x => (x - pop_mean l) ^ 2)).sum / l.length

/-- Third central moment. -/
noncomputable def pop_m3 (l : List ℝ) : ℝ :=
  (l.map (fun x => (x - pop_mean l) ^ 3)).sum / l.length

/-- Standardized skewness γ = m₃ / m₂^{3/2}. -/
noncomputable def skewness (l : List ℝ) : ℝ :=
  pop_m3 l / (pop_m2 l * Real.sqrt (pop_m2 l))

/--
  [P] Square-root-free direction key: γ·|γ| = m₃·|m₃| / m₂³.
  Because pushDistr is directional, any strictly monotone transform of γ serves.
-/
noncomputable def skew_key (l : List ℝ) : ℝ :=
  pop_m3 l * |pop_m3 l| / pop_m2 l ^ 3

theorem skew_key_eq (l : List ℝ) (h : 0 < pop_m2 l) :
    skew_key l = skewness l * |skewness l| := by
  unfold skew_key skewness
  have hs : 0 < Real.sqrt (pop_m2 l) := Real.sqrt_pos.mpr h
  have hsq : Real.sqrt (pop_m2 l) ^ 2 = pop_m2 l := Real.sq_sqrt h.le
  rw [abs_div, abs_of_pos (mul_pos h hs), div_mul_div_comm]
  have hden : (pop_m2 l * Real.sqrt (pop_m2 l)) * (pop_m2 l * Real.sqrt (pop_m2 l)) =
      pop_m2 l ^ 3 := by
    have : (pop_m2 l * Real.sqrt (pop_m2 l)) * (pop_m2 l * Real.sqrt (pop_m2 l)) =
        pop_m2 l ^ 2 * Real.sqrt (pop_m2 l) ^ 2 := by ring
    rw [this, hsq]
    ring
  rw [hden]

/-- x ↦ x·|x| is strictly monotone, so skew_key orders populations exactly as γ does. -/
theorem mul_abs_strictMono : StrictMono (fun x : ℝ => x * |x|) := by
  intro a b hab
  simp only
  rcases le_total 0 a with ha | ha <;> rcases le_total 0 b with hb | hb
  · rw [abs_of_nonneg ha, abs_of_nonneg hb]; nlinarith
  · linarith
  · rw [abs_of_nonpos ha, abs_of_nonneg hb]
    rcases hb.lt_or_eq with hb' | hb'
    · nlinarith [mul_pos hb' hb', mul_self_nonneg a]
    · subst hb'
      nlinarith [mul_pos (neg_pos.mpr hab) (neg_pos.mpr hab)]
  · rw [abs_of_nonpos ha, abs_of_nonpos hb]; nlinarith

/--
  [P] THEOREM: Skew direction alone is degenerate.
  Lowering the worst-off being from 2 to 0, bulk unchanged, moves U toward left skew
  (skew_key: -81/128 → about -1.06) while min falls. Hence ↑min must hold jointly with the skew push.
-/
theorem skew_direction_alone_permits_min_decline :
    skew_key [0, 6, 8, 9, 10] < skew_key [2, 6, 8, 9, 10] := by
  have a2 : pop_m2 [2, 6, 8, 9, 10] = 8 := by norm_num [pop_m2, pop_mean]
  have a3 : pop_m3 [2, 6, 8, 9, 10] = -18 := by norm_num [pop_m3, pop_mean]
  have b2 : pop_m2 [0, 6, 8, 9, 10] = 316 / 25 := by norm_num [pop_m2, pop_mean]
  have b3 : pop_m3 [0, 6, 8, 9, 10] = -5796 / 125 := by norm_num [pop_m3, pop_mean]
  unfold skew_key
  rw [a2, a3, b2, b3, abs_of_neg (by norm_num), abs_of_neg (by norm_num)]
  norm_num

/- --- 3. ↑min over a trajectory, with NHa tunnels (L55, L62, L150) --- -/

/-- [P] Stepwise ↑min: min never dips at any step of the horizon. -/
def stepwise_min_monotone (m : ℕ → ℝ) (h : ℕ) : Prop :=
  ∀ t < h, m t ≤ m (t + 1)

/--
  [P] ↑min over a trajectory: the endpoint recovers to at least the start, and every
  dip along the way is covered (an Fr-permitted NHa step, closed under Harm_Intv).
-/
def min_holds_over (m : ℕ → ℝ) (h : ℕ) (covered : ℕ → Prop) : Prop :=
  m 0 ≤ m h ∧ ∀ t < h, m (t + 1) < m t → covered t

theorem stepwise_endpoint (m : ℕ → ℝ) : ∀ h, stepwise_min_monotone m h → m 0 ≤ m h
  | 0, _ => le_refl _
  | n + 1, hs =>
    le_trans (stepwise_endpoint m n (fun t ht => hs t (Nat.lt_succ_of_lt ht)))
      (hs n (Nat.lt_succ_self n))

/-- [P] Stepwise monotone trajectories satisfy trajectory-level ↑min, whatever the cover. -/
theorem stepwise_implies_min_holds (m : ℕ → ℝ) (h : ℕ) (covered : ℕ → Prop)
    (hs : stepwise_min_monotone m h) : min_holds_over m h covered := by
  refine ⟨stepwise_endpoint m h hs, fun t ht hdip => ?_⟩
  exact absurd (hs t ht) (not_le.mpr hdip)

/-- A two-step NHa tunnel: min dips from 1 to 0, then recovers to 2. -/
def tunnel_example : ℕ → ℝ
  | 0 => 1
  | 1 => 0
  | _ => 2

/--
  [P] THEOREM: A stepwise filter rejects NHa tunnels that trajectory-level ↑min admits.
  Hence Pareto filtering must compare trajectories over the horizon, not single steps.
-/
theorem tunnel_admissible_but_not_stepwise :
    min_holds_over tunnel_example 2 (fun t => t = 0) ∧
      ¬ stepwise_min_monotone tunnel_example 2 := by
  refine ⟨⟨by norm_num [tunnel_example], fun t ht hdip => ?_⟩, fun hs => ?_⟩
  · interval_cases t
    · rfl
    · norm_num [tunnel_example] at hdip
  · have h0 := hs 0 (by norm_num)
    norm_num [tunnel_example] at h0

/-- [P] Harm_Intv (L150) fires at step t when tunnel depth does not shrink (min does not rise). -/
def harm_intv_fires (m : ℕ → ℝ) (t : ℕ) : Prop :=
  m (t + 1) ≤ m t

/--
  [P] THEOREM: A tunnel still open at the horizon has triggered Harm_Intv at some step.
  Harm_Intv (L150) is the closure guard: an NHa gap that does not close cannot pass silently.
-/
theorem nonclosing_tunnel_triggers_harm_intv (m : ℕ → ℝ) (h : ℕ) (hopen : m h < m 0) :
    ∃ t < h, harm_intv_fires m t := by
  by_contra hno
  simp only [not_exists, not_and] at hno
  have hs : stepwise_min_monotone m h := fun t ht => by
    have := hno t ht
    unfold harm_intv_fires at this
    exact le_of_lt (not_le.mp this)
  have := stepwise_endpoint m h hs
  linarith

/- --- 4. Expected lifetime tallies (L68) --- -/

/--
  [P] Expected tally of a being over Bounds_B (L68):
  Σ_{t ∈ [St_begin, St_loss_irreversible)} E[V(π*, b, t)], with π* the best available uplift policy.
-/
def expected_tally (ev : ℕ → ℝ) (tBegin tEnd : ℕ) : ℝ :=
  ∑ t ∈ Finset.Ico tBegin tEnd, ev t

theorem sum_nonpos_of_neg : ∀ l : List ℝ, (∀ x ∈ l, x < 0) → l.sum ≤ 0
  | [], _ => by simp
  | a :: l, h => by
    rw [List.sum_cons]
    have ha := h a List.mem_cons_self
    have hl := sum_nonpos_of_neg l (fun x hx => h x (List.mem_cons_of_mem a hx))
    linarith

theorem sum_pos_of_pos : ∀ l : List ℝ, l ≠ [] → (∀ x ∈ l, 0 < x) → 0 < l.sum
  | [], hne, _ => absurd rfl hne
  | [a], _, h => by
    rw [List.sum_singleton]
    exact h a List.mem_cons_self
  | a :: b :: l, _, h => by
    rw [List.sum_cons]
    have ha := h a List.mem_cons_self
    have hl := sum_pos_of_pos (b :: l) (List.cons_ne_nil b l)
      (fun x hx => h x (List.mem_cons_of_mem a hx))
    linarith

/--
  [P] THEOREM: A population of net-negative expected tallies, of any size, never outweighs
  a non-empty population of positive expected tallies, of any size.
-/
theorem net_negative_never_outweighs_positive (neg pos : List ℝ)
    (hn : ∀ x ∈ neg, x < 0) (hp : ∀ x ∈ pos, 0 < x) (hne : pos ≠ []) :
    neg.sum < pos.sum :=
  lt_of_le_of_lt (sum_nonpos_of_neg neg hn) (sum_pos_of_pos pos hne hp)

/- --- 5. Saturating diversity (L35) --- -/

/-- [P] Effective diversity of a population: the number of distinct types present. -/
def effective_types {τ : Type*} [DecidableEq τ] (pop : List τ) : ℕ :=
  pop.toFinset.card

/-- [P] THEOREM: Any number of copies of one type counts as at most one type. -/
theorem copies_add_no_diversity {τ : Type*} [DecidableEq τ] (x : τ) (n : ℕ) :
    effective_types (List.replicate n x) ≤ 1 := by
  unfold effective_types
  rw [Finset.card_le_one]
  intro a ha b hb
  rw [List.mem_toFinset] at ha hb
  rw [List.eq_of_mem_replicate ha, List.eq_of_mem_replicate hb]

/-- [P] THEOREM: Adding a being of a new type raises effective diversity by exactly one. -/
theorem new_type_adds_diversity {τ : Type*} [DecidableEq τ] (x : τ) (pop : List τ)
    (hx : x ∉ pop) :
    effective_types (x :: pop) = effective_types pop + 1 := by
  unfold effective_types
  rw [List.toFinset_cons]
  exact Finset.card_insert_of_notMem (by rwa [List.mem_toFinset])

/--
  [R] Population novelty: Σ_b N(type b), with N(x) := 1 / Frequency(x) (L36), frequency taken
  within the population. Diversity.txt: "diversity is built into the Novelty factor".
-/
noncomputable def population_novelty {τ : Type*} [DecidableEq τ] (pop : List τ) : ℝ :=
  (pop.map (fun x => 1 / (pop.count x : ℝ))).sum

/--
  [P] THEOREM: Summed novelty equals the number of distinct types.
  Saturating diversity is therefore derived from N (L36), not an added population term.
-/
theorem population_novelty_eq_effective_types {τ : Type*} [DecidableEq τ] (pop : List τ) :
    population_novelty pop = effective_types pop := by
  unfold population_novelty effective_types
  rw [Finset.sum_list_map_count, Finset.card_eq_sum_ones, Nat.cast_sum]
  apply Finset.sum_congr rfl
  intro x hx
  have hc : (pop.count x : ℝ) ≠ 0 := by
    exact_mod_cast (List.count_pos_iff.mpr (List.mem_toFinset.mp hx)).ne'
  rw [nsmul_eq_mul, Nat.cast_one, mul_one_div_cancel hc]

/--
  [R] Novelty against history: frequency counts prior encounters in ℝ (L36) plus the population.
-/
noncomputable def population_novelty_hist {τ : Type*} [DecidableEq τ] (hist pop : List τ) : ℝ :=
  (pop.map (fun x => 1 / ((hist ++ pop).count x : ℝ))).sum

theorem population_novelty_hist_nil {τ : Type*} [DecidableEq τ] (pop : List τ) :
    population_novelty_hist [] pop = population_novelty pop := by
  simp [population_novelty_hist, population_novelty]

/--
  [P] THEOREM: With history, summed novelty is bounded by the number of distinct types.
  Familiar types contribute less; diversity still cannot be bought by headcount.
-/
theorem population_novelty_hist_le {τ : Type*} [DecidableEq τ] (hist pop : List τ) :
    population_novelty_hist hist pop ≤ effective_types pop := by
  unfold population_novelty_hist effective_types
  rw [Finset.sum_list_map_count, Finset.card_eq_sum_ones, Nat.cast_sum]
  apply Finset.sum_le_sum
  intro x hx
  have hc : (0 : ℝ) < pop.count x := by
    exact_mod_cast List.count_pos_iff.mpr (List.mem_toFinset.mp hx)
  have hh : (0 : ℝ) ≤ hist.count x := Nat.cast_nonneg _
  rw [nsmul_eq_mul, Nat.cast_one, List.count_append, Nat.cast_add, mul_one_div,
    div_le_one (by linarith)]
  linarith

/- --- 6. Pareto-monotone scores --- -/

/-- [P] A score is Pareto-monotone if dominance strictly raises it. -/
def pareto_monotone {k : ℕ} (score : (Fin k → ℝ) → ℝ) : Prop :=
  ∀ p q, pareto_dominates q p → score p < score q

/-- [P] Positive-weight sums are Pareto-monotone; a stand-in for Sy-weighting until Sy's monotonicity is proved. -/
theorem weighted_score_pareto_monotone {k : ℕ} (w : Fin k → ℝ) (hw : ∀ i, 0 < w i) :
    pareto_monotone (fun p => ∑ i, w i * p i) := by
  intro p q ⟨hle, i, hi⟩
  exact Finset.sum_lt_sum (fun j _ => mul_le_mul_of_nonneg_left (hle j) (hw j).le)
    ⟨i, Finset.mem_univ i, mul_lt_mul_of_pos_left hi (hw i)⟩

/- --- 7. Sy over trajectory progress is Pareto-monotone (L13) --- -/

/--
  [P] Sy score of a progress vector (L13): gains p_i⁺ enter Φ₊ with weights w, losses p_i⁻ enter Φ₋
  with weights v. Zero components contribute nothing to either branch.
-/
noncomputable def sy_score {k : ℕ} (w v : Fin k → ℝ) (qp qm kappa lambda : ℝ) (p : Fin k → ℝ) : ℝ :=
  net_synergy_raw (phi_of (List.finRange k) (fun i => w i * (max 0 (p i)) ^ qp) kappa)
    (phi_of (List.finRange k) (fun i => v i * (max 0 (-p i)) ^ qm) kappa) lambda

/--
  [P] THEOREM: Sy is Pareto-monotone for positive weights, positive exponents, κ ≥ 0 and 0 ≤ λ ≤ 1.
  So Sy can rank progress vectors without reversing dominance.
-/
theorem sy_score_pareto_monotone {k : ℕ} (w v : Fin k → ℝ) (qp qm kappa lambda : ℝ)
    (hw : ∀ i, 0 < w i) (hv : ∀ i, 0 < v i) (hqp : 0 < qp) (hqm : 0 < qm)
    (hk : 0 ≤ kappa) (hl0 : 0 ≤ lambda) (hl1 : lambda ≤ 1) :
    pareto_monotone (sy_score w v qp qm kappa lambda) := by
  intro p q hdom
  obtain ⟨hle, j, hj⟩ := hdom
  unfold sy_score
  have gain_nonneg : ∀ (r : Fin k → ℝ) i, 0 ≤ w i * (max 0 (r i)) ^ qp := fun r i =>
    mul_nonneg (hw i).le (Real.rpow_nonneg (le_max_left _ _) _)
  have loss_nonneg : ∀ (r : Fin k → ℝ) i, 0 ≤ v i * (max 0 (-r i)) ^ qm := fun r i =>
    mul_nonneg (hv i).le (Real.rpow_nonneg (le_max_left _ _) _)
  have gain_le : ∀ i ∈ List.finRange k,
      0 ≤ w i * (max 0 (p i)) ^ qp ∧ w i * (max 0 (p i)) ^ qp ≤ w i * (max 0 (q i)) ^ qp :=
    fun i _ => ⟨gain_nonneg p i, mul_le_mul_of_nonneg_left
      (Real.rpow_le_rpow (le_max_left _ _) (max_le_max (le_refl 0) (hle i)) hqp.le) (hw i).le⟩
  have loss_le : ∀ i ∈ List.finRange k,
      0 ≤ v i * (max 0 (-q i)) ^ qm ∧ v i * (max 0 (-q i)) ^ qm ≤ v i * (max 0 (-p i)) ^ qm :=
    fun i _ => ⟨loss_nonneg q i, mul_le_mul_of_nonneg_left
      (Real.rpow_le_rpow (le_max_left _ _) (max_le_max (le_refl 0) (neg_le_neg (hle i))) hqm.le)
      (hv i).le⟩
  set Pp := phi_of (List.finRange k) (fun i => w i * (max 0 (p i)) ^ qp) kappa
  set Pq := phi_of (List.finRange k) (fun i => w i * (max 0 (q i)) ^ qp) kappa
  set Mp := phi_of (List.finRange k) (fun i => v i * (max 0 (-p i)) ^ qm) kappa
  set Mq := phi_of (List.finRange k) (fun i => v i * (max 0 (-q i)) ^ qm) kappa
  have hP : Pp ≤ Pq := phi_of_mono _ _ _ kappa hk gain_le
  have hM : Mq ≤ Mp := phi_of_mono _ _ _ kappa hk loss_le
  have hPp0 : 0 ≤ Pp := phi_of_nonneg _ _ kappa hk (fun i _ => gain_nonneg p i)
  have hPq0 : 0 ≤ Pq := phi_of_nonneg _ _ kappa hk (fun i _ => gain_nonneg q i)
  have hMq0 : 0 ≤ Mq := phi_of_nonneg _ _ kappa hk (fun i _ => loss_nonneg q i)
  have hMp0 : 0 ≤ Mp := le_trans hMq0 hM
  have mono_plus : net_synergy_raw Pp Mp lambda ≤ net_synergy_raw Pq Mp lambda := by
    rcases hP.lt_or_eq with h | h
    · exact (net_synergy_raw_strict_mono_plus Pp Pq Mp lambda hPp0 h hMp0 hl0 hl1).le
    · rw [h]
  have anti_minus : net_synergy_raw Pq Mp lambda ≤ net_synergy_raw Pq Mq lambda := by
    rcases hM.lt_or_eq with h | h
    · exact (net_synergy_raw_strict_anti_minus Pq Mq Mp lambda hPq0 hMq0 h hl0).le
    · rw [h]
  by_cases hqj : 0 < q j
  · have hgain : w j * (max 0 (p j)) ^ qp < w j * (max 0 (q j)) ^ qp := by
      apply mul_lt_mul_of_pos_left _ (hw j)
      rw [max_eq_right hqj.le]
      exact Real.rpow_lt_rpow (le_max_left _ _) (max_lt hqj hj) hqp
    have hPs : Pp < Pq := phi_of_strict_mono _ _ _ kappa hk gain_le
      ⟨j, List.mem_finRange j, hgain⟩
    have := net_synergy_raw_strict_mono_plus Pp Pq Mp lambda hPp0 hPs hMp0 hl0 hl1
    linarith
  · have hqj' : 0 ≤ -q j := by linarith
    have hloss : v j * (max 0 (-q j)) ^ qm < v j * (max 0 (-p j)) ^ qm := by
      apply mul_lt_mul_of_pos_left _ (hv j)
      rw [max_eq_right hqj']
      exact Real.rpow_lt_rpow hqj' (lt_of_lt_of_le (by linarith) (le_max_right _ _)) hqm
    have hMs : Mq < Mp := phi_of_strict_mono _ _ _ kappa hk loss_le
      ⟨j, List.mem_finRange j, hloss⟩
    have := net_synergy_raw_strict_anti_minus Pq Mq Mp lambda hPq0 hMq0 hMs hl0
    linarith

/- --- 8. Goal G (L62, L74): Σ_b Sy(V_b, As(D)) under ↑ℝ and ¬↓min --- -/

/--
  [P] A plan: an evaluated action, its predicted harm, the population statistics after the action
  and after not acting (counterfactual, As L48), and the assessed V(A, b) of each being b present
  at decision time.
-/
structure Plan where
  eval      : ActionEvaluation
  harm      : HarmForecast
  statsNotA : DistrStats
  statsA    : DistrStats
  value     : ℕ → ℝ

/-- [R] Assessed distribution change of a plan: stats after A against stats after ¬A (As, L48). -/
def Plan.prog (c : Plan) : Fin 12 → ℝ :=
  progress c.statsNotA c.statsA

/-- [R] Range components of pushDistr: ↑(U, H, N)(max, min) and ↓Ha(max, min). -/
def range_idx : List (Fin 12) := [4, 5, 6, 7, 8, 9, 10, 11]

/-- Restriction of a progress vector to a set of components, zero elsewhere. -/
def restrict (idx : List (Fin 12)) (p : Fin 12 → ℝ) : Fin 12 → ℝ :=
  fun i => if i ∈ idx then p i else 0

/-- Magnitude of the assessed range change. -/
noncomputable def range_change (p : Fin 12 → ℝ) : ℝ :=
  (range_idx.map (fun i => |p i|)).sum

/-- [P] Graded significance (L25): a linear ramp reaching 1 at the threshold. -/
noncomputable def graded_sig (m th : ℝ) : ℝ :=
  min 1 (m / th)

/-- [R] Skew gate (L62): skew counts only as far as the range change is not significant. -/
noncomputable def skew_gate (th : ℝ) (p : Fin 12 → ℝ) : ℝ :=
  1 - graded_sig (range_change p) th

/-- [P] Parameters of G: Sy exponents and λ, κ; distribution weight w_D; significance threshold;
  priority weights of range and skew components (range > skew, L12). -/
structure GParams where
  qp     : ℝ
  qm     : ℝ
  kappa  : ℝ
  lambda : ℝ
  wD     : ℝ
  th     : ℝ
  wRange : Fin 12 → ℝ
  wSkew  : Fin 12 → ℝ

/--
  [R] Assessed distribution term D (L62): Sy over the range changes, plus Sy over the skew changes
  weighted by the skew gate.
-/
noncomputable def dist_score (gp : GParams) (p : Fin 12 → ℝ) : ℝ :=
  sy_score gp.wRange gp.wRange gp.qp gp.qm gp.kappa gp.lambda (restrict range_idx p) +
    skew_gate gp.th p *
      sy_score gp.wSkew gp.wSkew gp.qp gp.qm gp.kappa gp.lambda (restrict [0, 1, 2, 3] p)

/-- THEOREM: When the range change is significant, skew is ignored. -/
theorem skew_ignored_when_range_significant (gp : GParams) (p : Fin 12 → ℝ) (hth : 0 < gp.th)
    (h : gp.th ≤ range_change p) :
    dist_score gp p = sy_score gp.wRange gp.wRange gp.qp gp.qm gp.kappa gp.lambda
      (restrict range_idx p) := by
  have hg : graded_sig (range_change p) gp.th = 1 :=
    min_eq_left ((one_le_div hth).mpr h)
  unfold dist_score skew_gate
  rw [hg]
  ring

/-- THEOREM: When the range is static, skew counts in full. -/
theorem skew_counts_when_range_static (gp : GParams) (p : Fin 12 → ℝ) (h : range_change p = 0) :
    dist_score gp p = sy_score gp.wRange gp.wRange gp.qp gp.qm gp.kappa gp.lambda
      (restrict range_idx p) +
      sy_score gp.wSkew gp.wSkew gp.qp gp.qm gp.kappa gp.lambda (restrict [0, 1, 2, 3] p) := by
  have hg : graded_sig (range_change p) gp.th = 0 := by
    unfold graded_sig
    rw [h, zero_div]
    exact min_eq_right zero_le_one
  unfold dist_score skew_gate
  rw [hg]
  ring

/- --- Range priority: max U > min U > min H (author) --- -/

theorem sum_map_zero {ι : Type*} (y : ι → ℝ) (l : List ι) (h : ∀ i ∈ l, y i = 0) :
    (l.map y).sum = 0 :=
  List.sum_eq_zero (fun x hx => by
    obtain ⟨i, hi, rfl⟩ := List.mem_map.mp hx
    exact h i hi)

theorem pairwiseCrossSum_map_zero {ι : Type*} (y : ι → ℝ) :
    ∀ l : List ι, (∀ i ∈ l, y i = 0) → pairwiseCrossSum (l.map y) = 0
  | [], _ => by simp
  | a :: t, h => by
    simp only [List.map_cons, pairwiseCrossSum]
    rw [h a (by simp), zero_mul, zero_add]
    exact pairwiseCrossSum_map_zero y t (fun i hi => h i (List.mem_cons_of_mem a hi))

theorem sum_map_single {ι : Type*} (y : ι → ℝ) (j : ι) :
    ∀ l : List ι, l.Nodup → j ∈ l → (∀ i ∈ l, i ≠ j → y i = 0) → (l.map y).sum = y j
  | [], _, hj, _ => absurd hj (by simp)
  | a :: t, hn, hj, h => by
    rw [List.nodup_cons] at hn
    simp only [List.map_cons, List.sum_cons]
    by_cases haj : a = j
    · subst haj
      rw [sum_map_zero y t (fun i hi => h i (List.mem_cons_of_mem _ hi)
        (fun hia => hn.1 (hia ▸ hi))), add_zero]
    · have hjt : j ∈ t := by
        rcases List.mem_cons.mp hj with h' | h'
        · exact absurd h'.symm haj
        · exact h'
      rw [h a (by simp) haj, zero_add]
      exact sum_map_single y j t hn.2 hjt (fun i hi hij => h i (List.mem_cons_of_mem a hi) hij)

theorem pairwiseCrossSum_map_single {ι : Type*} (y : ι → ℝ) (j : ι) :
    ∀ l : List ι, l.Nodup → (∀ i ∈ l, i ≠ j → y i = 0) → pairwiseCrossSum (l.map y) = 0
  | [], _, _ => by simp
  | a :: t, hn, h => by
    rw [List.nodup_cons] at hn
    simp only [List.map_cons, pairwiseCrossSum]
    rw [pairwiseCrossSum_map_single y j t hn.2
      (fun i hi hij => h i (List.mem_cons_of_mem a hi) hij), add_zero]
    by_cases haj : a = j
    · subst haj
      rw [sum_map_zero y t (fun i hi => h i (List.mem_cons_of_mem _ hi)
        (fun hia => hn.1 (hia ▸ hi))), mul_zero]
    · rw [h a (by simp) haj, zero_mul]

/-- THEOREM: Sy of a zero vector is zero. -/
theorem sy_score_of_zero {k : ℕ} (w v : Fin k → ℝ) (qp qm kappa lambda : ℝ) (p : Fin k → ℝ)
    (hqp : 0 < qp) (hqm : 0 < qm) (h : ∀ i, p i = 0) : sy_score w v qp qm kappa lambda p = 0 := by
  have hy : ∀ i ∈ List.finRange k, w i * (max 0 (p i)) ^ qp = 0 := fun i _ => by
    rw [h i, max_self, Real.zero_rpow (ne_of_gt hqp), mul_zero]
  have hz : ∀ i ∈ List.finRange k, v i * (max 0 (-p i)) ^ qm = 0 := fun i _ => by
    rw [h i, neg_zero, max_self, Real.zero_rpow (ne_of_gt hqm), mul_zero]
  unfold sy_score phi_of
  rw [sum_map_zero _ _ hy, pairwiseCrossSum_map_zero _ _ hy, sum_map_zero _ _ hz,
    pairwiseCrossSum_map_zero _ _ hz]
  simp

/-- THEOREM: Sy of a single gain x in component j is w_j · x^q₊. -/
theorem sy_score_single {k : ℕ} (w v : Fin k → ℝ) (qp qm kappa lambda : ℝ) (p : Fin k → ℝ)
    (j : Fin k) (hqp : 0 < qp) (hqm : 0 < qm) (hw : 0 < w j) (hx : 0 < p j)
    (h0 : ∀ i, i ≠ j → p i = 0) : sy_score w v qp qm kappa lambda p = w j * (p j) ^ qp := by
  have hy : ∀ i ∈ List.finRange k, i ≠ j → w i * (max 0 (p i)) ^ qp = 0 := fun i _ hij => by
    rw [h0 i hij, max_self, Real.zero_rpow (ne_of_gt hqp), mul_zero]
  have hz : ∀ i ∈ List.finRange k, i ≠ j → v i * (max 0 (-p i)) ^ qm = 0 := fun i _ hij => by
    rw [h0 i hij, neg_zero, max_self, Real.zero_rpow (ne_of_gt hqm), mul_zero]
  have hzj : v j * (max 0 (-p j)) ^ qm = 0 := by
    rw [max_eq_left (show -p j ≤ 0 by linarith), Real.zero_rpow (ne_of_gt hqm), mul_zero]
  have hP : phi_of (List.finRange k) (fun i => w i * (max 0 (p i)) ^ qp) kappa =
      w j * (p j) ^ qp := by
    unfold phi_of
    rw [sum_map_single _ j _ (List.nodup_finRange k) (List.mem_finRange j) hy,
      pairwiseCrossSum_map_single _ j _ (List.nodup_finRange k) hy]
    simp only [Real.sqrt_zero, mul_zero, add_zero, max_eq_right hx.le]
  have hM : phi_of (List.finRange k) (fun i => v i * (max 0 (-p i)) ^ qm) kappa = 0 := by
    unfold phi_of
    rw [sum_map_single _ j _ (List.nodup_finRange k) (List.mem_finRange j) hz,
      pairwiseCrossSum_map_single _ j _ (List.nodup_finRange k) hz]
    simp only [Real.sqrt_zero, mul_zero, add_zero]
    exact hzj
  unfold sy_score
  rw [hP, hM]
  exact net_synergy_raw_pos_zero _ (mul_pos hw (Real.rpow_pos_of_pos hx _)) _

/-- A gain x in component j alone. -/
def unit_gain (j : Fin 12) (x : ℝ) : Fin 12 → ℝ :=
  fun i => if i = j then x else 0

/-- THEOREM: A single range gain scores w_j · x^q₊ in D; the skew term contributes nothing. -/
theorem dist_score_unit_gain (gp : GParams) (j : Fin 12) (hj : j ∈ range_idx)
    (hjs : j ∉ ([0, 1, 2, 3] : List (Fin 12))) (hqp : 0 < gp.qp) (hqm : 0 < gp.qm)
    (hw : 0 < gp.wRange j) (x : ℝ) (hx : 0 < x) :
    dist_score gp (unit_gain j x) = gp.wRange j * x ^ gp.qp := by
  have hr : restrict range_idx (unit_gain j x) = unit_gain j x := by
    funext i
    unfold restrict unit_gain
    by_cases hij : i = j
    · rw [hij, if_pos hj]
    · simp [hij]
  have hs : ∀ i, restrict [0, 1, 2, 3] (unit_gain j x) i = 0 := by
    intro i
    unfold restrict unit_gain
    by_cases hij : i = j
    · rw [hij, if_neg hjs]
    · simp [hij]
  unfold dist_score
  rw [hr, sy_score_of_zero _ _ _ _ _ _ _ hqp hqm hs, mul_zero, add_zero]
  have h1 := sy_score_single gp.wRange gp.wRange gp.qp gp.qm gp.kappa gp.lambda (unit_gain j x) j
    hqp hqm hw (by simp [unit_gain, hx]) (fun i hij => by simp [unit_gain, hij])
  rw [h1]
  simp [unit_gain]

/-- [R] Range priority (author): max U (index 6) > min U (4) > min H (5). -/
def RangePriority (w : Fin 12 → ℝ) : Prop :=
  w 4 < w 6 ∧ w 5 < w 4

/-- THEOREM: Under the range priority, equal gains score max U > min U > min H in D. -/
theorem range_priority_order (gp : GParams) (hpr : RangePriority gp.wRange)
    (hw : ∀ i, 0 < gp.wRange i) (hqp : 0 < gp.qp) (hqm : 0 < gp.qm) (x : ℝ) (hx : 0 < x) :
    dist_score gp (unit_gain 5 x) < dist_score gp (unit_gain 4 x) ∧
      dist_score gp (unit_gain 4 x) < dist_score gp (unit_gain 6 x) := by
  have hxq : 0 < x ^ gp.qp := Real.rpow_pos_of_pos hx _
  rw [dist_score_unit_gain gp 5 (by unfold range_idx; decide) (by decide) hqp hqm (hw 5) x hx,
    dist_score_unit_gain gp 4 (by unfold range_idx; decide) (by decide) hqp hqm (hw 4) x hx,
    dist_score_unit_gain gp 6 (by unfold range_idx; decide) (by decide) hqp hqm (hw 6) x hx]
  exact ⟨mul_lt_mul_of_pos_right hpr.2 hxq, mul_lt_mul_of_pos_right hpr.1 hxq⟩

/-- [R] A being's term in G: Sy(V_b, D) with gain and loss weights (1, w_D) (L13 default w = 1). -/
noncomputable def being_term (gp : GParams) (v d : ℝ) : ℝ :=
  sy_score ![1, gp.wD] ![1, gp.wD] gp.qp gp.qm gp.kappa gp.lambda ![v, d]

/-- [R] G's objective (L74): Σ over beings present at decision time of Sy(V(A, b), As(D)). -/
noncomputable def goal_value (gp : GParams) (pop : List ℕ) (c : Plan) : ℝ :=
  (pop.map (fun b => being_term gp (c.value b) (dist_score gp c.prog))).sum

/--
  [R] ¬↓(U(max, min), H(min)) (L62): counterfactual, trajectory-level min U, min H and max U do
  not fall. Max H has no hard limit: happiness peaks are unstable (author).
-/
noncomputable def min_nondecreasing (c : Plan) : Bool :=
  haveI := Classical.propDecidable (0 ≤ c.prog 4 ∧ 0 ≤ c.prog 5 ∧ 0 ≤ c.prog 6)
  decide (0 ≤ c.prog 4 ∧ 0 ≤ c.prog 5 ∧ 0 ≤ c.prog 6)

/-- [R] G-admissible plans: ↑ℝ ∧ ¬↓min. Fr is a subgoal, not a filter on G. -/
noncomputable def plan_admissible_G (c : Plan) : Bool :=
  is_eligible_action c.eval && min_nondecreasing c

/-- [R] Goal G (L74): argmax of the objective over admissible plans. -/
noncomputable def goal_G (gp : GParams) (pop : List ℕ) (cs : List Plan) : Option Plan :=
  (cs.filter plan_admissible_G).argmax (goal_value gp pop)

/-- THEOREM: Inaction's assessed distribution change is zero in every component. -/
theorem inaction_progress_zero (c : Plan) (h : c.statsA = c.statsNotA) : c.prog = fun _ => 0 := by
  funext i
  unfold Plan.prog
  rw [h]
  fin_cases i <;> simp [progress]

/-- THEOREM: Inaction is always G-admissible: its counterfactual is itself. -/
theorem inaction_admissible (c : Plan) (hs : c.statsA = c.statsNotA)
    (hr : c.eval.scopeAfter = c.eval.scopeBefore) : plan_admissible_G c = true := by
  have hp := inaction_progress_zero c hs
  simp [plan_admissible_G, min_nondecreasing, is_eligible_action, hp, reality_enhancement_delta, hr]

/-- THEOREM: G always chooses when some plan, e.g. inaction, is admissible. -/
theorem goal_G_some (gp : GParams) (pop : List ℕ) (cs : List Plan) (c : Plan) (hc : c ∈ cs)
    (ha : plan_admissible_G c = true) : goal_G gp pop cs ≠ none := by
  unfold goal_G
  intro hnone
  rw [List.argmax_eq_none] at hnone
  have : c ∈ cs.filter plan_admissible_G := List.mem_filter.mpr ⟨hc, ha⟩
  rw [hnone] at this
  simp at this

/-- THEOREM: G's choice satisfies ↑ℝ and ¬↓(U(max, min), H(min)) and maximises the objective over admissible plans. -/
theorem goal_G_sound (gp : GParams) (pop : List ℕ) (cs : List Plan) (c : Plan)
    (hc : c ∈ goal_G gp pop cs) :
    reality_enhancement_delta c.eval.scopeBefore c.eval.scopeAfter ≥ 0 ∧
      0 ≤ c.prog 4 ∧ 0 ≤ c.prog 5 ∧ 0 ≤ c.prog 6 ∧
      ∀ d ∈ cs.filter plan_admissible_G, goal_value gp pop d ≤ goal_value gp pop c := by
  have hm := (List.mem_filter.mp (List.argmax_mem hc)).2
  simp only [plan_admissible_G, min_nondecreasing, is_eligible_action, Bool.and_eq_true,
    decide_eq_true_eq] at hm
  exact ⟨hm.1, hm.2.1, hm.2.2.1, hm.2.2.2, fun d hd => List.le_of_mem_argmax (f := goal_value gp pop) hd hc⟩

theorem being_term_mono (gp : GParams) (hw : 0 < gp.wD) (hqp : 0 < gp.qp) (hqm : 0 < gp.qm)
    (hk : 0 ≤ gp.kappa) (hl0 : 0 ≤ gp.lambda) (hl1 : gp.lambda ≤ 1) (v v' d d' : ℝ)
    (hv : v ≤ v') (hd : d ≤ d') : being_term gp v d ≤ being_term gp v' d' := by
  have hmono := sy_score_pareto_monotone (k := 2) ![1, gp.wD] ![1, gp.wD] gp.qp gp.qm gp.kappa
    gp.lambda (by intro i; fin_cases i <;> simp [hw]) (by intro i; fin_cases i <;> simp [hw])
    hqp hqm hk hl0 hl1
  unfold being_term
  by_cases heq : v = v' ∧ d = d'
  · obtain ⟨rfl, rfl⟩ := heq
    exact le_refl _
  · apply le_of_lt
    apply hmono
    refine ⟨fun i => by fin_cases i <;> simp [hv, hd], ?_⟩
    by_cases hvv : v = v'
    · have hdd : d < d' := lt_of_le_of_ne hd (fun h => heq ⟨hvv, h⟩)
      exact ⟨1, by simp [hdd]⟩
    · exact ⟨0, by simp [lt_of_le_of_ne hv hvv]⟩

theorem being_term_strict_mono_value (gp : GParams) (hw : 0 < gp.wD) (hqp : 0 < gp.qp)
    (hqm : 0 < gp.qm) (hk : 0 ≤ gp.kappa) (hl0 : 0 ≤ gp.lambda) (hl1 : gp.lambda ≤ 1)
    (v v' d d' : ℝ) (hv : v < v') (hd : d ≤ d') : being_term gp v d < being_term gp v' d' := by
  have hmono := sy_score_pareto_monotone (k := 2) ![1, gp.wD] ![1, gp.wD] gp.qp gp.qm gp.kappa
    gp.lambda (by intro i; fin_cases i <;> simp [hw]) (by intro i; fin_cases i <;> simp [hw])
    hqp hqm hk hl0 hl1
  unfold being_term
  apply hmono
  exact ⟨fun i => by fin_cases i <;> simp [hv.le, hd], ⟨0, by simp [hv]⟩⟩

/--
  THEOREM: A plan that is better for some being present at decision time, no worse for any, and
  no worse in assessed distribution, has a strictly higher objective.
-/
theorem goal_value_strict_mono (gp : GParams) (hw : 0 < gp.wD) (hqp : 0 < gp.qp)
    (hqm : 0 < gp.qm) (hk : 0 ≤ gp.kappa) (hl0 : 0 ≤ gp.lambda) (hl1 : gp.lambda ≤ 1)
    (pop : List ℕ) (c c' : Plan)
    (hle : ∀ b ∈ pop, c'.value b ≤ c.value b) (hlt : ∃ b ∈ pop, c'.value b < c.value b)
    (hd : dist_score gp c'.prog ≤ dist_score gp c.prog) :
    goal_value gp pop c' < goal_value gp pop c := by
  unfold goal_value
  apply sum_map_lt_of_le_of_lt
  · intro b hb
    exact being_term_mono gp hw hqp hqm hk hl0 hl1 _ _ _ _ (hle b hb) hd
  · obtain ⟨b, hb, hbl⟩ := hlt
    exact ⟨b, hb, being_term_strict_mono_value gp hw hqp hqm hk hl0 hl1 _ _ _ _ hbl hd⟩

/--
  THEOREM: G never chooses a plan dominated by another admissible plan.
  Trolley: pulling is admissible (the floor does not fall against waiting, where more lives are
  lost) and better for the beings it spares, so waiting is not chosen.
  Fair-weather Fr: when V's convex harm weighting makes a Fr-compliant plan better for every being,
  the Fr-violating plan is not chosen; Fr emerges from the priorities without filtering G.
-/
theorem dominated_plan_not_chosen (gp : GParams) (hw : 0 < gp.wD) (hqp : 0 < gp.qp)
    (hqm : 0 < gp.qm) (hk : 0 ≤ gp.kappa) (hl0 : 0 ≤ gp.lambda) (hl1 : gp.lambda ≤ 1)
    (pop : List ℕ) (cs : List Plan) (better worse c : Plan)
    (hb : better ∈ cs) (hba : plan_admissible_G better = true)
    (hle : ∀ b ∈ pop, worse.value b ≤ better.value b)
    (hlt : ∃ b ∈ pop, worse.value b < better.value b)
    (hd : dist_score gp worse.prog ≤ dist_score gp better.prog)
    (hc : c ∈ goal_G gp pop cs) : c ≠ worse := by
  intro hcw
  have hmax := (goal_G_sound gp pop cs c hc).2.2.2.2 better (List.mem_filter.mpr ⟨hb, hba⟩)
  have hstrict := goal_value_strict_mono gp hw hqp hqm hk hl0 hl1 pop better worse hle hlt hd
  rw [hcw] at hmax
  linarith

/-- [R] G's parameters at an admissible point; range and skew priority weights stay explicit. -/
noncomputable def toGParams (pv : ParamVector) (wRange wSkew : Fin 12 → ℝ) : GParams :=
  { qp := pv.q_plus, qm := pv.q_minus, kappa := pv.kappa, lambda := pv.lambda,
    wD := pv.dist_weight, th := pv.th_sig, wRange := wRange, wSkew := wSkew }

/-- THEOREM: At every admissible point, and so throughout SigThGv, G never chooses a dominated plan. -/
theorem admissible_dominated_plan_not_chosen (pv : ParamVector) (h : Admissible pv)
    (wRange wSkew : Fin 12 → ℝ) (pop : List ℕ) (cs : List Plan) (better worse c : Plan)
    (hb : better ∈ cs) (hba : plan_admissible_G better = true)
    (hle : ∀ b ∈ pop, worse.value b ≤ better.value b)
    (hlt : ∃ b ∈ pop, worse.value b < better.value b)
    (hd : dist_score (toGParams pv wRange wSkew) worse.prog ≤
      dist_score (toGParams pv wRange wSkew) better.prog)
    (hc : c ∈ goal_G (toGParams pv wRange wSkew) pop cs) : c ≠ worse :=
  dominated_plan_not_chosen (toGParams pv wRange wSkew) h.dist_weight_pos
    (by show 0 < pv.q_plus; linarith [h.q_plus_gt_one])
    (by show 0 < pv.q_minus; linarith [h.q_plus_gt_one, h.q_plus_le_q_minus])
    h.kappa_nonneg h.lambda_nonneg h.lambda_le_one pop cs better worse c hb hba hle hlt hd hc

/- --- 9. The floor is taken over the decision-time population --- -/

/-- [R] Floor over beings present at decision time; lost lives keep their place at the bottom. -/
noncomputable def decision_floor (pop : List ℕ) (level : ℕ → ℝ) (top : ℝ) : ℝ :=
  (pop.map level).foldr min top

/--
  THEOREM: Removal cannot raise the floor. Removing a being sets its level to the bottom, which
  lowers no one else's, so the floor over the decision-time population cannot rise.
-/
theorem removal_cannot_raise_floor (pop : List ℕ) (level level' : ℕ → ℝ) (top : ℝ)
    (h : ∀ b ∈ pop, level' b ≤ level b) :
    decision_floor pop level' top ≤ decision_floor pop level top := by
  unfold decision_floor
  induction pop with
  | nil => exact le_refl _
  | cons a t ih =>
    simp only [List.map_cons, List.foldr_cons]
    exact min_le_min (h a (by simp)) (ih (fun b hb => h b (by simp [hb])))

/--
  THEOREM: Taken over survivors only, removal would raise the floor: removing the worst-off being
  (level 0) from [0, 5] lifts the survivors' minimum to 5. Hence the decision-time population.
-/
theorem survivor_floor_rises_on_removal :
    ([0, 5] : List ℝ).foldr min 10 < ([5] : List ℝ).foldr min 10 := by
  simp only [List.foldr_cons, List.foldr_nil]
  rw [min_eq_left (by norm_num : (5 : ℝ) ≤ 10), min_eq_left (by norm_num : (0 : ℝ) ≤ 5)]
  norm_num

end Benefuture.Proposed
