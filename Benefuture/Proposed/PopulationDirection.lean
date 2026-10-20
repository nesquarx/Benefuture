/-
  Benefuture.Proposed.PopulationDirection
  [P] Proposed population axiology by direction rather than by world-ranking.
  Corresponds to: Bf_Pseudocode.txt L54-55 (Ha, NHa), L62 (pushDistr), L68 (Bounds_B),
  L74 (G), L135 (Fr), L150 (Harm_Intv).

  Design decisions (from discussion with the framework author):
  1. Bf ranks actions, not worlds. V is per action; a being-level value exists only as an
     expected lifetime tally over Bounds_B, computed under the best available uplift policy.
  2. Existing beings may only be uplifted. Removal is irreparable harm, excluded by Fr before
     any NHa justification is considered (Fr filters, then argmax; resolves SPEC_DIVERGENCES §2.5).
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
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.IntervalCases
import Benefuture.Ontology.Entity
import Benefuture.Axiology.Priorities
import Benefuture.Subgoals.Freedom

namespace Benefuture.Proposed

open Benefuture.Ontology
open Benefuture.Axiology
open Benefuture.Subgoals

/- --- 1. Harm and withholding (L54) --- -/

/-- [R] Ha := ↓U ∨ ↓H (L54), on one being's levels before and after an action. -/
def harm_occurs (u₀ u₁ h₀ h₁ : ℝ) : Prop :=
  u₁ < u₀ ∨ h₁ < h₀

/-- [P] Withholding uplift leaves levels unchanged, hence is not Ha (decision 3). -/
theorem withholding_incurs_no_harm (u h : ℝ) : ¬ harm_occurs u u h h := by
  unfold harm_occurs
  rintro (hu | hh)
  · exact lt_irrefl _ hu
  · exact lt_irrefl _ hh

/- --- 2. Fr filters before NHa and argmax (L55, L74, L135) --- -/

/-- [P] A candidate action with its predicted harm profile and assessed value. -/
structure Candidate where
  action : Action
  harm   : HarmProfile
  value  : ℝ

/-- [R] Fr permissibility of a candidate (L135). -/
noncomputable def fr_permitted (c : Candidate) : Bool :=
  is_action_freedom_permissible c.action c.harm

/--
  [P] Action choice: Fr filters the candidate set, then argmax over value.
  NHa (L55) can only justify a harm among Fr-permitted candidates.
-/
noncomputable def choose_action (cs : List Candidate) : Option Candidate :=
  (cs.filter fr_permitted).argmax (·.value)

/--
  [P] THEOREM: The chosen action never carries irreparable or irreversible harm,
  however large its value would have been. In particular, removing existing beings
  (irreparable harm) is never chosen, whatever their expected tally.
-/
theorem chosen_action_never_irreparable (cs : List Candidate) (c : Candidate)
    (hc : c ∈ choose_action cs) :
    c.harm.irreparable ≤ 0 ∧ c.harm.irreversible ≤ 0 := by
  have hm := List.argmax_mem hc
  rw [List.mem_filter] at hm
  have hp := hm.2
  simp only [fr_permitted, is_action_freedom_permissible, Bool.and_eq_true,
    decide_eq_true_eq] at hp
  exact hp

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

/-- [P] Pareto filter: keep only candidates not dominated by another candidate. -/
def pareto_front {k : ℕ} (ps : List (Fin k → ℝ)) : List (Fin k → ℝ) :=
  ps.filter (fun p => decide (¬ ∃ q ∈ ps, pareto_dominates q p))

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

end Benefuture.Proposed
