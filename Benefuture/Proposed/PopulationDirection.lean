/-
  Benefuture.Proposed.PopulationDirection
  [P] Proposed population axiology by direction rather than by world-ranking.
  Corresponds to: Bf_Pseudocode.txt L54-55 (Ha, NHa), L62 (pushDistr), L68 (Bounds_B),
  L74 (G), L135 (Fr), L150 (Harm_Intv).

  Design decisions (from discussion with the framework author):
  1. Bf ranks actions, not worlds. V is per action; a being-level value exists only as an
     expected lifetime tally over Bounds_B, computed under the best available uplift policy.
  2. Existing beings may only be uplifted. Removal is irreparable harm known to occur, excluded
     by Fr before any NHa justification is considered (Fr filters, then argmax; §2.5).
  3. Withholding uplift is not Ha (no ↓U, ↓H); it is only comparatively worse under argmax.
  4. pushDistr is directional: actions are compared by signed deltas of skew, max and min.
     The skew directions are only non-degenerate jointly with ↑min (left skew can otherwise be
     raised by pushing a few beings further down), so ↑min is held over the trajectory.
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

/- --- 2. Fr filters before NHa and argmax (L55, L74, L135) --- -/

/-- [P] A candidate action with its predicted harm (with confidence) and assessed value. -/
structure Candidate where
  action : Action
  harm   : HarmForecast
  value  : ℝ

/-- [R] Fr permissibility of a candidate (L135, `fr_permissible`). -/
noncomputable def fr_permitted (fp : FrParams) (c : Candidate) : Bool :=
  fr_permissible c.harm fp

/--
  [P] Action choice: Fr filters the candidate set, then argmax over value.
  NHa (L55) can only justify a harm among Fr-permitted candidates.
-/
noncomputable def choose_action (fp : FrParams) (cs : List Candidate) : Option Candidate :=
  (cs.filter (fr_permitted fp)).argmax (·.value)

/--
  [P] THEOREM: The chosen action carries no established harm at the long-term tier or worse,
  and its expected severity stays within Fr's ceiling, however large its value would have been.
-/
theorem chosen_action_fr_sound (fp : FrParams) (cs : List Candidate) (c : Candidate)
    (hc : c ∈ choose_action fp cs) :
    ¬ established_severe c.harm fp ∧
      c.harm.confidence * severity_score c.harm.profile fp ≤ fp.thHigh := by
  have hm := List.argmax_mem hc
  rw [List.mem_filter] at hm
  exact fr_permissible_spec _ _ hm.2

/--
  [P] THEOREM: Removal is never chosen. Removing an existing being is irreparable harm known
  to occur (confidence ≥ thConf), so no chosen action carries it, whatever the being's tally.
-/
theorem removal_never_chosen (fp : FrParams) (cs : List Candidate) (c : Candidate)
    (hc : c ∈ choose_action fp cs) (hconf : fp.thConf ≤ c.harm.confidence) :
    c.harm.profile.irreparable ≤ 0 := by
  have h := (chosen_action_fr_sound fp cs c hc).1
  by_contra hpos
  exact h ⟨hconf, Or.inl (not_le.mp hpos)⟩

/- --- 3. Directional pushDistr (L62) and Pareto dominance --- -/

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

/--
  [P] Progress vector of a step s₀ → s₁, oriented so that higher is better in every component:
  U, H toward left skew; Ha toward right skew; N toward normal; ↑(U, N, H)(max, min); ↓Ha(max, min).
-/
def progress (s₀ s₁ : DistrStats) : Fin 11 → ℝ :=
  ![s₀.skewU - s₁.skewU, s₀.skewH - s₁.skewH, s₁.skewHa - s₀.skewHa,
    s₀.normDevN - s₁.normDevN,
    s₁.minU - s₀.minU, s₁.minH - s₀.minH,
    s₁.maxU - s₀.maxU, s₁.maxH - s₀.maxH, s₁.maxN - s₀.maxN,
    s₀.maxHa - s₁.maxHa, s₀.minHa - s₁.minHa]

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

/- --- 3b. Skew direction computed from a population (L62) --- -/

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

/- --- 4. ↑min over a trajectory, with NHa tunnels (L55, L62, L150) --- -/

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

/- --- 5. Expected lifetime tallies (L68) --- -/

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

/- --- 6. Saturating diversity (L35) --- -/

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

/- --- 7. Full choice pipeline: Fr ∧ ↑ℝ, then Pareto, then a monotone score (L13, L74, L135) --- -/

/-- [P] A plan: an evaluated action, its predicted harm, and its trajectory-level pushDistr progress. -/
structure Plan where
  eval : ActionEvaluation
  harm : HarmForecast
  prog : Fin 11 → ℝ

/-- [P] Admissible plans pass Fr (L135) and ↑ℝ eligibility (L74, `is_eligible_action`). -/
noncomputable def plan_admissible (fp : FrParams) (c : Plan) : Bool :=
  fr_permissible c.harm fp && is_eligible_action c.eval

/-- [P] A score is Pareto-monotone if dominance strictly raises it. -/
def pareto_monotone {k : ℕ} (score : (Fin k → ℝ) → ℝ) : Prop :=
  ∀ p q, pareto_dominates q p → score p < score q

/-- [P] Positive-weight sums are Pareto-monotone; a stand-in for Sy-weighting until Sy's monotonicity is proved. -/
theorem weighted_score_pareto_monotone {k : ℕ} (w : Fin k → ℝ) (hw : ∀ i, 0 < w i) :
    pareto_monotone (fun p => ∑ i, w i * p i) := by
  intro p q ⟨hle, i, hi⟩
  exact Finset.sum_lt_sum (fun j _ => mul_le_mul_of_nonneg_left (hle j) (hw j).le)
    ⟨i, Finset.mem_univ i, mul_lt_mul_of_pos_left hi (hw i)⟩

/-- [P] Choice: filter admissible plans, then maximise a score over trajectory progress. -/
noncomputable def choose_plan (fp : FrParams) (score : (Fin 11 → ℝ) → ℝ) (cs : List Plan) :
    Option Plan :=
  (cs.filter (plan_admissible fp)).argmax (fun c => score c.prog)

/--
  [P] THEOREM: Soundness of the choice pipeline. For any Pareto-monotone score, the chosen plan
  passes Fr (no established severe harm; expected severity within the ceiling), does not
  contract ℝ, and is not Pareto-dominated by any admissible plan.
-/
theorem choose_plan_sound (fp : FrParams) (score : (Fin 11 → ℝ) → ℝ) (hs : pareto_monotone score)
    (cs : List Plan) (c : Plan) (hc : c ∈ choose_plan fp score cs) :
    ¬ established_severe c.harm fp ∧
      c.harm.confidence * severity_score c.harm.profile fp ≤ fp.thHigh ∧
      reality_enhancement_delta c.eval.scopeBefore c.eval.scopeAfter ≥ 0 ∧
      ¬ ∃ d ∈ cs.filter (plan_admissible fp), pareto_dominates d.prog c.prog := by
  have hm := List.argmax_mem hc
  rw [List.mem_filter] at hm
  have hp := hm.2
  simp only [plan_admissible, Bool.and_eq_true] at hp
  have hfr := fr_permissible_spec _ _ hp.1
  have hel := hp.2
  simp only [is_eligible_action, decide_eq_true_eq] at hel
  refine ⟨hfr.1, hfr.2, hel, ?_⟩
  rintro ⟨d, hd, hdom⟩
  have h1 := List.le_of_mem_argmax hd hc
  have h2 := hs _ _ hdom
  linarith

/- --- 8. Sy over trajectory progress is Pareto-monotone (L13) --- -/

/--
  [P] Sy score of a progress vector (L13): gains p_i⁺ enter Φ₊ with weights w, losses p_i⁻ enter Φ₋
  with weights v. Zero components contribute nothing to either branch.
-/
noncomputable def sy_score {k : ℕ} (w v : Fin k → ℝ) (qp qm kappa lambda : ℝ) (p : Fin k → ℝ) : ℝ :=
  net_synergy_raw (phi_of (List.finRange k) (fun i => w i * (max 0 (p i)) ^ qp) kappa)
    (phi_of (List.finRange k) (fun i => v i * (max 0 (-p i)) ^ qm) kappa) lambda

/--
  [P] THEOREM: Sy is Pareto-monotone for positive weights, positive exponents, κ ≥ 0 and 0 ≤ λ ≤ 1.
  So `choose_plan_sound` holds with Sy itself as the score.
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

/--
  [P] THEOREM: The choice pipeline is sound with Sy as the score: the chosen plan passes Fr,
  does not contract ℝ, and is not Pareto-dominated by any admissible plan.
-/
theorem choose_plan_sy_sound (fp : FrParams) (w v : Fin 11 → ℝ) (qp qm kappa lambda : ℝ)
    (hw : ∀ i, 0 < w i) (hv : ∀ i, 0 < v i) (hqp : 0 < qp) (hqm : 0 < qm)
    (hk : 0 ≤ kappa) (hl0 : 0 ≤ lambda) (hl1 : lambda ≤ 1)
    (cs : List Plan) (c : Plan) (hc : c ∈ choose_plan fp (sy_score w v qp qm kappa lambda) cs) :
    ¬ established_severe c.harm fp ∧
      c.harm.confidence * severity_score c.harm.profile fp ≤ fp.thHigh ∧
      reality_enhancement_delta c.eval.scopeBefore c.eval.scopeAfter ≥ 0 ∧
      ¬ ∃ d ∈ cs.filter (plan_admissible fp), pareto_dominates d.prog c.prog :=
  choose_plan_sound fp _ (sy_score_pareto_monotone w v qp qm kappa lambda hw hv hqp hqm hk hl0 hl1)
    cs c hc

/--
  [P] THEOREM: At every admissible parameter point, choice with Sy as the score is sound.
-/
theorem admissible_choose_plan_sy_sound (pv : ParamVector) (h : Admissible pv)
    (w v : Fin 11 → ℝ) (hw : ∀ i, 0 < w i) (hv : ∀ i, 0 < v i)
    (cs : List Plan) (c : Plan)
    (hc : c ∈ choose_plan pv.toFrParams (sy_score w v pv.q_plus pv.q_minus pv.kappa pv.lambda) cs) :
    ¬ established_severe c.harm pv.toFrParams ∧
      c.harm.confidence * severity_score c.harm.profile pv.toFrParams ≤ pv.toFrParams.thHigh ∧
      reality_enhancement_delta c.eval.scopeBefore c.eval.scopeAfter ≥ 0 ∧
      ¬ ∃ d ∈ cs.filter (plan_admissible pv.toFrParams), pareto_dominates d.prog c.prog :=
  choose_plan_sy_sound pv.toFrParams w v pv.q_plus pv.q_minus pv.kappa pv.lambda hw hv
    (by linarith [h.q_plus_gt_one]) (by linarith [h.q_plus_gt_one, h.q_plus_le_q_minus])
    h.kappa_nonneg h.lambda_nonneg h.lambda_le_one cs c hc

/--
  [P] THEOREM: Wherever SigThGv takes the parameters from bootstrap, choice with Sy stays sound.
-/
theorem governed_choose_plan_sy_sound (qs : List ParamVector)
    (w v : Fin 11 → ℝ) (hw : ∀ i, 0 < w i) (hv : ∀ i, 0 < v i) (cs : List Plan) (c : Plan)
    (hc : c ∈ choose_plan (gov_run bootstrapParams qs).toFrParams
      (sy_score w v (gov_run bootstrapParams qs).q_plus (gov_run bootstrapParams qs).q_minus
        (gov_run bootstrapParams qs).kappa (gov_run bootstrapParams qs).lambda) cs) :
    ¬ established_severe c.harm (gov_run bootstrapParams qs).toFrParams ∧
      c.harm.confidence * severity_score c.harm.profile (gov_run bootstrapParams qs).toFrParams ≤
        (gov_run bootstrapParams qs).toFrParams.thHigh ∧
      reality_enhancement_delta c.eval.scopeBefore c.eval.scopeAfter ≥ 0 ∧
      ¬ ∃ d ∈ cs.filter (plan_admissible (gov_run bootstrapParams qs).toFrParams),
        pareto_dominates d.prog c.prog :=
  admissible_choose_plan_sy_sound _ (governed_params_admissible qs) w v hw hv cs c hc

/- --- 9. Goal G, staged (decision 6a; L62, L74, L135) --- -/

/-- [P] ↑min over the horizon: trajectory-level min U and min H do not fall (progress indices 4, 5). -/
noncomputable def min_nondecreasing (c : Plan) : Bool :=
  haveI := Classical.propDecidable (0 ≤ c.prog 4 ∧ 0 ≤ c.prog 5)
  decide (0 ≤ c.prog 4 ∧ 0 ≤ c.prog 5)

/-- [P] G-admissible plans: Fr ∧ ↑ℝ ∧ ↑min. -/
noncomputable def plan_admissible_G (fp : FrParams) (c : Plan) : Bool :=
  plan_admissible fp c && min_nondecreasing c

open Classical in
/-- [P] Plans whose pushDistr progress no other plan in the list Pareto-dominates. -/
noncomputable def plan_front (ps : List Plan) : List Plan :=
  ps.filter (fun p => decide (¬ ∃ q ∈ ps, pareto_dominates q.prog p.prog))

/--
  [P] Goal G (L74), staged: filter by Fr ∧ ↑ℝ ∧ ↑min, take the Pareto front on pushDistr progress
  (whose floor and median inputs are the distributional tiers), then argmax ΣV over the front.
-/
noncomputable def goal_G (fp : FrParams) (cs : List Plan) : Option Plan :=
  (plan_front (cs.filter (plan_admissible_G fp))).argmax (·.eval.aggregateValue)

/--
  [P] THEOREM: Soundness of staged G. The chosen plan passes Fr, does not contract ℝ, keeps min U
  and min H from falling over the horizon, is not Pareto-dominated by any G-admissible plan, and
  has the highest ΣV on the front.
-/
theorem goal_G_sound (fp : FrParams) (cs : List Plan) (c : Plan) (hc : c ∈ goal_G fp cs) :
    ¬ established_severe c.harm fp ∧
      c.harm.confidence * severity_score c.harm.profile fp ≤ fp.thHigh ∧
      reality_enhancement_delta c.eval.scopeBefore c.eval.scopeAfter ≥ 0 ∧
      0 ≤ c.prog 4 ∧ 0 ≤ c.prog 5 ∧
      (¬ ∃ d ∈ cs.filter (plan_admissible_G fp), pareto_dominates d.prog c.prog) ∧
      ∀ d ∈ plan_front (cs.filter (plan_admissible_G fp)),
        d.eval.aggregateValue ≤ c.eval.aggregateValue := by
  have hm := List.argmax_mem hc
  unfold plan_front at hm
  rw [List.mem_filter] at hm
  obtain ⟨hadm, hnd⟩ := hm
  have hadm' := (List.mem_filter.mp hadm).2
  simp only [plan_admissible_G, plan_admissible, min_nondecreasing, Bool.and_eq_true,
    decide_eq_true_eq] at hadm'
  obtain ⟨⟨hfr, hel⟩, hmin⟩ := hadm'
  have hfr' := fr_permissible_spec _ _ hfr
  simp only [is_eligible_action, decide_eq_true_eq] at hel
  simp only [decide_eq_true_eq] at hnd
  exact ⟨hfr'.1, hfr'.2, hel, hmin.1, hmin.2, hnd,
    fun d hd => List.le_of_mem_argmax hd hc⟩

theorem sum_prog_lt_of_dominates {p q : Plan} (h : pareto_dominates q.prog p.prog) :
    ∑ i, p.prog i < ∑ i, q.prog i :=
  sum_lt_of_dominates h

/-- [P] THEOREM: Staged G always chooses when some plan is G-admissible. -/
theorem goal_G_some (fp : FrParams) (cs : List Plan)
    (hne : cs.filter (plan_admissible_G fp) ≠ []) : goal_G fp cs ≠ none := by
  obtain ⟨p, hp⟩ : ∃ p, p ∈ (cs.filter (plan_admissible_G fp)).argmax (fun p => ∑ i, p.prog i) := by
    cases h : (cs.filter (plan_admissible_G fp)).argmax (fun p => ∑ i, p.prog i) with
    | none => exact absurd (List.argmax_eq_none.mp h) hne
    | some p => exact ⟨p, rfl⟩
  have hpf : p ∈ plan_front (cs.filter (plan_admissible_G fp)) := by
    unfold plan_front
    rw [List.mem_filter]
    refine ⟨List.argmax_mem hp, ?_⟩
    simp only [decide_eq_true_eq]
    rintro ⟨q, hq, hdom⟩
    have h1 := List.le_of_mem_argmax hq hp
    have h2 := sum_prog_lt_of_dominates hdom
    linarith
  unfold goal_G
  intro hnone
  rw [List.argmax_eq_none] at hnone
  rw [hnone] at hpf
  simp at hpf

end Benefuture.Proposed
