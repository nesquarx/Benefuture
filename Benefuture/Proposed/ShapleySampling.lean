/-
  Benefuture.Proposed.ShapleySampling
  [P] Shapley shares by permutation sampling (Castro, Gómez & Tejada 2009), for outcomes with more
  contributors than exact Shapley (`Proposed.OutcomeDistribution.shapley`, 2ⁿ coalition values)
  can afford. A contributor's sampled share is the mean, over sampled orderings of the
  contributors, of its marginal contribution to those before it. Mirrored over Float by
  `BenefutureReference.shapley_sampled_ref` and `shapley_sample_count_ref`.

  Proved here, for every sample (not only in expectation): sampled shares are efficient (they sum
  to v(N) − v(∅), so sampling error moves currency between contributors and never mints or
  destroys it) and a null contributor gets nothing. Also proved: the governed sample count
  ⌈ln(2n/δ) / (2ε²)⌉ makes the Hoeffding union bound 2n·exp(−2mε²) at most δ. Cited, not proved:
  Hoeffding's inequality itself, and that the mean over all n! orderings equals the subset form of
  `shapley` (checked exactly over ℚ for small n by `BenefutureTest.Differential`).

  IMPORTANT ARCHITECTURAL RULE: core Benefuture modules MUST NOT import this file.
-/

import Benefuture.Proposed.OutcomeDistribution
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.Exp
import Mathlib.Algebra.BigOperators.Field

namespace Benefuture.Proposed

open Finset

variable {ι : Type*} [DecidableEq ι]

/-- [P] Marginal contributions along an ordering, after the coalition `pre` has acted: the
    contributor at each position adds v(pre ∪ earlier ∪ {it}) − v(pre ∪ earlier); contributors not
    in the ordering get nothing. -/
noncomputable def marginalsFrom (v : Finset ι → ℝ) : Finset ι → List ι → ι → ℝ
  | _, [], _ => 0
  | pre, a :: rest, i =>
      (if i = a then v (insert a pre) - v pre else 0) + marginalsFrom v (insert a pre) rest i

/-- [P] Marginal contributions along an ordering of the contributors. -/
noncomputable def marginals (v : Finset ι → ℝ) (σ : List ι) (i : ι) : ℝ := marginalsFrom v ∅ σ i

/-- [P] Sampled Shapley share: the mean of contributor `i`'s marginal contributions over the
    sampled orderings. -/
noncomputable def shapley_sampled (v : Finset ι → ℝ) (samples : List (List ι)) (i : ι) : ℝ :=
  (samples.map fun σ => marginals v σ i).sum / samples.length

theorem marginalsFrom_not_mem (v : Finset ι → ℝ) :
    ∀ (σ : List ι) (pre : Finset ι) (i : ι), i ∉ σ → marginalsFrom v pre σ i = 0
  | [], _, _, _ => rfl
  | a :: rest, pre, i, h => by
    have hia : i ≠ a := fun e => h (e ▸ List.mem_cons_self)
    have hr : i ∉ rest := fun hm => h (List.mem_cons_of_mem a hm)
    simp [marginalsFrom, hia, marginalsFrom_not_mem v rest (insert a pre) i hr]

/-- THEOREM: Marginals along an ordering telescope: they sum to what the whole ordering adds to
    the coalition that had already acted. -/
theorem marginalsFrom_sum (v : Finset ι → ℝ) :
    ∀ (σ : List ι) (pre : Finset ι), σ.Nodup →
      ∑ i ∈ σ.toFinset, marginalsFrom v pre σ i = v (pre ∪ σ.toFinset) - v pre
  | [], pre, _ => by simp
  | a :: rest, pre, hnd => by
    rw [List.nodup_cons] at hnd
    obtain ⟨ha, hnd⟩ := hnd
    have ha' : a ∉ rest.toFinset := by simpa using ha
    rw [List.toFinset_cons, Finset.sum_insert ha']
    have h1 : marginalsFrom v pre (a :: rest) a = v (insert a pre) - v pre := by
      simp [marginalsFrom, marginalsFrom_not_mem v rest (insert a pre) a ha]
    have h2 : ∑ i ∈ rest.toFinset, marginalsFrom v pre (a :: rest) i =
        ∑ i ∈ rest.toFinset, marginalsFrom v (insert a pre) rest i := by
      refine Finset.sum_congr rfl fun i hi => ?_
      have hia : i ≠ a := fun e => ha' (e ▸ hi)
      simp [marginalsFrom, hia]
    rw [h1, h2, marginalsFrom_sum v rest (insert a pre) hnd]
    have hset : insert a pre ∪ rest.toFinset = pre ∪ insert a rest.toFinset := by
      ext x; simp only [Finset.mem_union, Finset.mem_insert]; tauto
    rw [hset]; ring

/-- THEOREM (acceptance): Sampled shares are efficient on every sample. When each sampled ordering
    lists every contributor of `N` once, the shares sum to v(N) − v(∅): sampling error moves
    currency between contributors and never mints or destroys it. -/
theorem shapley_sampled_efficient (v : Finset ι → ℝ) (N : Finset ι) (samples : List (List ι))
    (hne : samples ≠ []) (hperm : ∀ σ ∈ samples, σ.Nodup ∧ σ.toFinset = N) :
    ∑ i ∈ N, shapley_sampled v samples i = v N - v ∅ := by
  unfold shapley_sampled
  rw [← Finset.sum_div]
  have hsum : ∀ (ss : List (List ι)), (∀ σ ∈ ss, σ.Nodup ∧ σ.toFinset = N) →
      ∑ i ∈ N, (ss.map fun σ => marginals v σ i).sum = ss.length * (v N - v ∅) := by
    intro ss
    induction ss with
    | nil => intro _; simp
    | cons σ ss ih =>
      intro h
      have hσ := h σ List.mem_cons_self
      simp only [List.map_cons, List.sum_cons, Finset.sum_add_distrib, List.length_cons]
      rw [ih fun τ hτ => h τ (List.mem_cons_of_mem σ hτ)]
      have : ∑ i ∈ N, marginals v σ i = v N - v ∅ := by
        unfold marginals
        rw [← hσ.2, marginalsFrom_sum v σ ∅ hσ.1, Finset.empty_union]
      rw [this]; push_cast; ring
  rw [hsum samples hperm]
  have hlen : (samples.length : ℝ) ≠ 0 := by
    have : 0 < samples.length := List.length_pos_iff.mpr hne
    exact_mod_cast this.ne'
  field_simp

/-- THEOREM (acceptance): A null contributor gets nothing on every sample. -/
theorem shapley_sampled_null (v : Finset ι → ℝ) (samples : List (List ι)) (i : ι)
    (h : ∀ S, v (insert i S) = v S) : shapley_sampled v samples i = 0 := by
  have hm : ∀ (σ : List ι) (pre : Finset ι), marginalsFrom v pre σ i = 0 := by
    intro σ
    induction σ with
    | nil => intro _; rfl
    | cons a rest ih =>
      intro pre
      by_cases hia : i = a
      · subst hia; simp [marginalsFrom, h, ih]
      · simp [marginalsFrom, hia, ih]
  unfold shapley_sampled marginals
  simp [hm]

/-- THEOREM (counterexample): A single sampled ordering is not exact Shapley. In the
    overdetermined game where either of two contributors alone produces the outcome, exact
    Shapley gives each half (`OutcomeDistribution.shapley`), but the ordering [0, 1] gives
    contributor 0 everything: sampled shares are estimates, and only their error bound is
    governed. -/
theorem shapley_sampled_single_order_inexact :
    shapley_sampled (fun S : Finset (Fin 2) => if S = ∅ then (0 : ℝ) else 1) [[0, 1]] 0 = 1 := by
  simp [shapley_sampled, marginals, marginalsFrom]

/-- [P] The governed number of orderings for n contributors at accuracy ε (relative to each
    contributor's marginal range) and failure probability δ: ⌈ln(2n/δ) / (2ε²)⌉. -/
noncomputable def hoeffding_count (n : ℕ) (ε δ : ℝ) : ℕ :=
  ⌈Real.log (2 * n / δ) / (2 * ε ^ 2)⌉₊

/-- THEOREM (acceptance): The governed sample count suffices for the Hoeffding union bound: with m
    orderings, the probability that some contributor's share misses by more than ε of its
    marginal range is at most 2n·exp(−2mε²) (Hoeffding's inequality and a union bound, cited),
    and that is at most δ. -/
theorem hoeffding_count_suffices (n : ℕ) (hn : 0 < n) (ε δ : ℝ) (hε : 0 < ε) (hδ : 0 < δ) :
    2 * n * Real.exp (-2 * (hoeffding_count n ε δ : ℝ) * ε ^ 2) ≤ δ := by
  set L := Real.log (2 * n / δ)
  have hnpos : (0 : ℝ) < 2 * n := by positivity
  have he2 : 0 < 2 * ε ^ 2 := by positivity
  have hm : L / (2 * ε ^ 2) ≤ (hoeffding_count n ε δ : ℝ) := Nat.le_ceil _
  by_cases hL : 0 ≤ L
  · have h1 : L ≤ 2 * (hoeffding_count n ε δ : ℝ) * ε ^ 2 := by
      rw [div_le_iff₀ he2] at hm; linarith
    have h2 : Real.exp (-2 * (hoeffding_count n ε δ : ℝ) * ε ^ 2) ≤ Real.exp (-L) :=
      Real.exp_le_exp.mpr (by linarith)
    have h3 : Real.exp (-L) = δ / (2 * n) := by
      rw [Real.exp_neg, Real.exp_log (by positivity)]; field_simp
    calc 2 * n * Real.exp (-2 * (hoeffding_count n ε δ : ℝ) * ε ^ 2)
        ≤ 2 * n * (δ / (2 * n)) := by rw [← h3]; exact mul_le_mul_of_nonneg_left h2 hnpos.le
      _ = δ := by field_simp
  · push Not at hL
    have hlt : 2 * (n : ℝ) / δ < 1 := by
      have := (Real.log_neg_iff (by positivity)).mp hL
      exact this
    have hnd : 2 * (n : ℝ) < δ := by rwa [div_lt_one hδ] at hlt
    have h2 : Real.exp (-2 * (hoeffding_count n ε δ : ℝ) * ε ^ 2) ≤ 1 := by
      rw [Real.exp_le_one_iff]
      have : (0 : ℝ) ≤ (hoeffding_count n ε δ : ℝ) * ε ^ 2 := by positivity
      linarith
    nlinarith

/-- THEOREM (counterexample): One ordering is not enough: with one contributor and a single
    ordering, the union bound 2n·exp(−2mε²) at ε = 1/2 is at least 1, above any δ < 1. -/
theorem hoeffding_one_sample_insufficient :
    (1 : ℝ) ≤ 2 * (1 : ℝ) * Real.exp (-2 * 1 * (1 / 2 : ℝ) ^ 2) := by
  have := Real.add_one_le_exp (-2 * 1 * (1 / 2 : ℝ) ^ 2)
  nlinarith

end Benefuture.Proposed
