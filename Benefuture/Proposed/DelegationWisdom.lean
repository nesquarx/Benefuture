/-
  Benefuture.Proposed.DelegationWisdom
  [P] The delegation cap (L114, `Governance.Incentives.accumulate_capped`) against Golub and
  Jackson's wisdom condition (2010, "Naïve Learning in Social Networks and the Wisdom of Crowds",
  AEJ: Micro, https://doi.org/10.1257/mic.2.1.112): a society's aggregated belief tracks the truth
  only if no one's influence stays large as the society grows.

  Proved here, for one round of delegation: under the ratified L114 rule every delegate's weight
  stays below cap + M (M the largest single delegator weight), so the largest influence share
  stays below capShare + M / total; under the stricter acceptance rule (accept only if the result
  stays within the cap) the largest weight is at most the cap. If the cap share and the largest
  weight's share of the total both vanish as the society grows, the largest influence share
  vanishes. The variance of an influence-weighted mean of independent, equally noisy signals is
  at most the largest share times the signal variance, so it vanishes too.

  Conjectured (`GolubJacksonWisdomConjecture`; docs/SIM_CONJECTURES.md B26): over repeated rounds
  with delegates chosen by reputation, audited, and with correlated signals (deliberation, 8.45),
  the tally's error still vanishes as the cap share does. The proofs above assume one round and
  independent signals; the conjecture removes both assumptions and is tested in simulation.

  IMPORTANT ARCHITECTURAL RULE: core Benefuture modules MUST NOT import this file.
-/

import Benefuture.Governance.Incentives
import Mathlib.Order.Filter.Basic
import Mathlib.Topology.Order.Basic
import Mathlib.Topology.Algebra.Order.Field
import Mathlib.Analysis.SpecificLimits.Basic
import Mathlib.Algebra.Order.BigOperators.Group.Finset

namespace Benefuture.Proposed

open Benefuture.Governance Filter Topology Finset

/-- THEOREM (acceptance): One round of L114 delegation bounds every delegate. Each delegate `d`
    starts below cap + M and receives the delegators in `ws d`, each of weight at most M; every
    delegate ends below cap + M. -/
theorem round_weight_lt {D : Type*} (cap M : ℝ) (start : D → ℝ) (ws : D → List ℝ)
    (hstart : ∀ d, start d < cap + M) (hw : ∀ d, ∀ w ∈ ws d, w ≤ M) :
    ∀ d, accumulate_capped cap (start d) (ws d) < cap + M :=
  fun d => accumulate_capped_bound cap M (ws d) (start d) (hstart d) (hw d)

/-- THEOREM (acceptance): The largest influence share in one L114 round stays below
    capShare + M / total, where the cap is capShare × total. -/
theorem round_share_lt {D : Type*} (capShare M total : ℝ) (htot : 0 < total) (start : D → ℝ)
    (ws : D → List ℝ) (hstart : ∀ d, start d < capShare * total + M) (hw : ∀ d, ∀ w ∈ ws d, w ≤ M) :
    ∀ d, accumulate_capped (capShare * total) (start d) (ws d) / total < capShare + M / total := by
  intro d
  have h := round_weight_lt (capShare * total) M start ws hstart hw d
  rw [div_lt_iff₀ htot, add_mul, div_mul_cancel₀ M htot.ne']
  linarith

/-- [P] Strict capped delegation: a delegation is accepted only if the delegate's weight stays
    within the cap. -/
noncomputable def accumulate_capped_strict (cap : ℝ) : ℝ → List ℝ → ℝ
  | cur, [] => cur
  | cur, w :: ws => accumulate_capped_strict cap (if cur + w ≤ cap then cur + w else cur) ws

/-- THEOREM (acceptance): Under strict capped delegation the largest weight in a round is at most
    the cap: max weight ≤ cap. -/
theorem accumulate_capped_strict_le (cap : ℝ) :
    ∀ (ws : List ℝ) (cur : ℝ), cur ≤ cap → accumulate_capped_strict cap cur ws ≤ cap
  | [], _, h => h
  | w :: ws, cur, h => by
    unfold accumulate_capped_strict
    apply accumulate_capped_strict_le cap ws
    split_ifs with hc
    · exact hc
    · exact h

/-- THEOREM (counterexample): The ratified L114 rule can overshoot the cap. A delegate at 0.04 with
    cap 0.05 accepts a further 0.03 (it is still under the cap when asked), ending at 0.07: the
    bound for L114 is cap + M, not cap. -/
theorem accumulate_capped_overshoots :
    accumulate_capped 0.05 0.04 [0.03] = 0.07 := by
  simp only [accumulate_capped]
  norm_num

/-- THEOREM (acceptance): Vanishing influence. If, as the society grows, the cap share and the
    largest delegator weight's share of the total both vanish, then any influence share bounded as
    in `round_share_lt` vanishes: Golub and Jackson's condition on the largest influence. -/
theorem capped_influence_vanishes (share capShare relM : ℕ → ℝ) (hnn : ∀ n, 0 ≤ share n)
    (hb : ∀ n, share n < capShare n + relM n) (hc : Tendsto capShare atTop (𝓝 0))
    (hm : Tendsto relM atTop (𝓝 0)) : Tendsto share atTop (𝓝 0) := by
  have hsum : Tendsto (fun n => capShare n + relM n) atTop (𝓝 0) := by simpa using hc.add hm
  exact tendsto_of_tendsto_of_tendsto_of_le_of_le tendsto_const_nhds hsum hnn fun n => (hb n).le

/-- THEOREM (acceptance): With influence shares s (non-negative, summing to 1, each at most m),
    the sum of squared shares is at most m. The variance of the s-weighted mean of independent
    signals of variance σ² is σ² · Σ sᵢ², hence at most m · σ²: it vanishes with the largest
    share. -/
theorem weighted_signal_variance_bound {V : Type*} (S : Finset V) (s : V → ℝ) (m : ℝ)
    (hnn : ∀ i ∈ S, 0 ≤ s i) (hsum : ∑ i ∈ S, s i = 1) (hmax : ∀ i ∈ S, s i ≤ m) :
    ∑ i ∈ S, s i ^ 2 ≤ m := by
  calc ∑ i ∈ S, s i ^ 2 ≤ ∑ i ∈ S, m * s i :=
        Finset.sum_le_sum fun i hi => by
          rw [sq]; exact mul_le_mul_of_nonneg_right (hmax i hi) (hnn i hi)
    _ = m := by rw [← Finset.mul_sum, hsum, mul_one]

/-- THEOREM (counterexample): Without a cap the bound is useless. When one voter holds every
    share (the star topology of `star_topology_power_concentration`), the sum of squared shares is
    1: the weighted mean is as noisy as a single signal, however large the society. -/
theorem uncapped_star_no_wisdom {V : Type*} [DecidableEq V] (S : Finset V) (d : V) (hd : d ∈ S) :
    ∑ i ∈ S, (if i = d then (1 : ℝ) else 0) ^ 2 = 1 := by
  simp [hd]

/-- [CONJ] Golub–Jackson wisdom under the delegation cap (docs/SIM_CONJECTURES.md B26). For a
    growing sequence of societies (index n) with cap shares `capShare n`, the error of the
    decision tally `tallyError n` (for instance the probability that the weighted majority is
    wrong) vanishes whenever the cap share and the largest base weight's share vanish, over
    repeated rounds with reputation-chosen, audited delegates and correlated signals. Stated as a
    proposition about the simulated trajectories; not proved. -/
def GolubJacksonWisdomConjecture (capShare relM tallyError : ℕ → ℝ) : Prop :=
  Tendsto capShare atTop (𝓝 0) → Tendsto relM atTop (𝓝 0) → Tendsto tallyError atTop (𝓝 0)

end Benefuture.Proposed
