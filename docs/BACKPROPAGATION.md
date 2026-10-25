# Back-Propagation Audit: What Formalisation Found That the Sources Miss

Formalising Benefuture in Lean forced decisions the pseudocode and articles leave implicit, and proved
some properties that only hold under conditions the sources do not state. This document lists each
such nuance with its evidence and a proposed edit to the sources. Nothing here has been applied to
`spec/Bf_Pseudocode.txt` or `docs/articles/`; the author decides.

Classes:
- **A — Author's ruling, not yet in the sources.** Decided in discussion; the sources should say it.
- **B — Forced by proof.** A stated property only holds under a condition the sources omit.
- **C — Open.** The sources are under-specified and need the author's reading.

Notation follows the pseudocode. "Lean:" names the definition or theorem that carries the point.

---

## 1. Synergy and parameters (L11–L14)

**1.1 Subscripts of Sy are ambiguous (B).**
`Sy_{κ,q₊}` is the signature, but `Sy_{½,1.5}` (L61) was read as q₊ = ½, q₋ = 1.5, which made Ha_wt
concave in severity; by the signature it is κ = ½, q₊ = 1.5 (convex, as the article says).
Lean: `compute_harm_weight`, `harm_tier_superlinear`.
Proposed edit: name the subscripts. L61 `Ha_wt: 1 + Sy_{κ=½, q₊=1.5}(…)`; L73 `V := Sy_{κ=2}(…)`.

**1.2 Items are (x, w₊, w₋) (B).**
L13 declares `[(x, w_+ = 1, w_- = w_+)]`; L73's triples `(U, α, Ha_wt)` only make sense in that
reading (Ha_wt weighs losses). An earlier formalisation applied α·Ha_wt to gains too.
Lean: `net_synergy_signed`, `net_synergy_signed_gain_ignores_loss_weight`.
Proposed edit: L73 `V := Sy_{κ=2}(As([(U, w₊=α, w₋=Ha_wt), (H, w₊=β, w₋=α·Ha_wt), (N, w₊=γ)], A, t))`.

**1.3 λ ≤ 1 is required (B).**
Sy is Pareto-monotone (more of every good, less of every bad never scores lower) only for 0 ≤ λ ≤ 1.
Above 1, a dominated mix of gains and losses can outscore its dominator.
Lean: `net_synergy_raw_strict_mono_plus`, `sy_score_pareto_monotone`, `Admissible.lambda_le_one`.
Proposed edit: L13 `(κ = 1, q₊ = 1.1, q₋ = 1.5, λ = ½) ∈ SigThGv | κ ≥ 0, q₋ ≥ q₊ > 1, 0 ≤ λ ≤ 1`.

**1.4 Loss aversion needs threshold-normalised inputs (B).**
With q₋ > q₊ > 1, losses outweigh equal gains only for magnitudes ≥ 1; below 1 the exponents invert
it. As normalises by Th_Cx (L48) and significance means ≥ Th (L25), so every significant input is
≥ 1, but L13 never says its inputs are in threshold units.
Lean: `loss_aversion_fails_below_one`, `significant_assessment_preserves_loss_aversion`,
`admissible_loss_aversion`.
Proposed edit: L13 append `| x ← As(·) (threshold units, L48)`.

**1.5 One priority weight per tier (B).**
`(x_1 > … > x_n) := [(x_i, Pm_i)]` (L12) needs n weights; Ha_wt has 8 tiers but the generic
schedule had 6, silently dropping two. Harm now has its own schedule.
Lean: `harmSchedule`.
Proposed edit: L12 `| |Pm| = n`; L61 name its schedule (`Pm_Ha`).

**1.6 `find ∧ max(⋂ ↑x)` is Pareto-then-maximise (B, confirms).**
The tail of L13 reads as: keep options that are not dominated on every dimension, then maximise.
Lean: `pareto_front`, `pareto_front_nonempty`.
Proposed edit: none required; an article sentence would help ("first discard dominated options,
then maximise").

## 2. Harm, happiness, understanding (L37, L54–L55, L58–L59)

**2.1 Harm reference points (A).**
↓H is a fall below the rolling average (coming down from a peak is not harm); ↓U is a fall below
the being's running maximum (forgetting is harm). L54 says only `↓U ∨ ↓H`.
Lean: `h_harm`, `u_harm`, `coming_down_not_harm`, `forgetting_is_harm`.
Proposed edit: L54 `Ha(t) := (U(t) < max_{τ≤t} U(τ)) ∨ (H(t) < avg_{window} H)`.

**2.2 H is non-negative; bias is a graded, separate MM claim (A).**
Bias covers malice, doom-scrolling and impairing stupor. MMs attach (degree, confidence) to each
source; measurements stay raw; claims are made independently of tier so peak-tier sources are not
discounted twice.
Lean: `BiasClaim`, `happiness_score`, `happiness_score_nonneg`, `fully_biased_contributes_nothing`.
Proposed edit: L37 `H := ∫Positive(Se) + BiasMitigation + Di ≥ 0 | BiasMitigation := −Σ c·b·Se_i ← MM(claim ⊥ tier)`.

**2.3 Two different Di (B).**
L35's Di is system-level (order/chaos balance); L37's Di inside a being's H is read as variety
within one life. The same symbol names both.
Lean: `experiential_variety` (L37), `DiversityBalance` (L35).
Proposed edit: L37 `… + Di_exp` with `Di_exp := Variety(Se(b))`, or state the relation to L35.

**2.4 Priority tiers mix kinds and distribution positions (A).**
L58–L59 interleave kinds (eudaimonic, shareable, satisficing, peak; peak, teachable, meta,
undirected) with population positions (baseline, median, floor). The first come from MM labels on a
being's sources; the second from the population distribution.
Lean: `happiness_tiers_of`, `understanding_tiers_of`, `kind_tiers_partition_happiness`.
Proposed edit: mark positions, e.g. `H: Sy(eudaimonic > shareable > satisficing > baseline_q > median_q > peak)`.

**2.5 NHa operates inside Fr (A).**
Necessary harm can only justify a harm among Fr-permitted actions; Fr filters first.
Lean: `choose_action`, `chosen_action_fr_sound`.
Proposed edit: L55 `NHa := Ha ∈ Fr : Ha → ↑V > Ha`.

## 3. Freedom (L135)

**3.1 Read literally, the irreversible clause blocks everything (A).**
Almost every action has some chance of irreversible harm. Author's reading: Fr blocks established
harm (confidence ≥ Th_conf) at long-term severity or worse, and any harm whose expected severity
exceeds Th_high; mild chances of passing harm do not block.
Lean: `fr_permissible`, `speculative_catastrophe_blocks`, `remote_irreversible_chance_permitted`.
Proposed edit: L135 `Fr := f_max(∃A, Imp, N, Po) | ¬Ha_(Estd(P ≥ Th_conf, ≥ longterm) ∨ P·severity > Th_high)`.

## 4. Population, distribution and the Goal (L62, L68, L73–L74)

**4.1 Bf ranks actions, not worlds (A).**
Being-level value exists only as an expected lifetime tally over Bounds_B, under the best available
uplift policy. Existing beings may only be uplifted; removal is never chosen; net-negative tallies
never outweigh a positive population. Withholding uplift is not Ha, only comparatively worse.
Lean: `expected_tally`, `removal_never_chosen`, `net_negative_never_outweighs_positive`,
`withholding_incurs_no_harm`.
Proposed edit: an article section (Benefuture goals.txt or a population-ethics article) stating these.

**4.2 The Repugnant Conclusion is not "directly dissolved" by the floor or skew alone (B).**
Benefuture goals.txt says the skew requirement with q₊ > 1 "directly dissolves" it. A floor alone
only moves the threshold; skew alone can be met by pushing the worst-off further down. What blocks
it is the combination of directional pushDistr, ↑min held jointly, and Fr.
Lean: `floor_shifts_repugnant_conclusion`, `skew_direction_alone_permits_min_decline`, `goal_G_sound`.
Proposed edit: reword to "is blocked by the skew directive held jointly with ↑min and the Freedom
boundary: …".

**4.3 pushDistr is directional, and ↑min holds over the trajectory (A, B).**
Skew sets direction, not a target shape (A). ↑min is hard but may dip inside an NHa tunnel that
closes within the prediction horizon (A); a step-by-step filter would reject every such tunnel (B).
Lean: `pushDistr_aligned`, `min_holds_over`, `tunnel_admissible_but_not_stepwise`,
`nonclosing_tunnel_triggers_harm_intv`.
Proposed edit: L62 `pushDistr(…direction…, ↑min over lt (NHa dips ⇒ Harm_Intv), …)`.

**4.4 G needs an explicit order of operations (A).**
L74 says `argmax ΣV ∧ ↑ℝ`. The staged form is: filter Fr ∧ ↑ℝ ∧ ↑min, take the Pareto front on
pushDistr progress, then argmax ΣV.
Lean: `goal_G`, `goal_G_sound`, `goal_G_some`.
Proposed edit: L74 `G(t) := argmax_{A ∈ Front_{pushDistr}(Fr ∧ ↑ℝ ∧ ↑min)} Σ_b V(A, b)`.

**4.5 No sentience multiplier (A).**
Capacity enters through absolute magnitudes of U and H.
Proposed edit: L73 note `| no St weight; capacity ∈ |ΔU|, |ΔH|`.

**4.6 Diversity is derived from N (B, confirms).**
Summing N(x) = 1/Frequency over a population gives exactly its number of distinct types (at most
that, counting history), so copies cannot buy diversity.
Lean: `population_novelty_eq_effective_types`, `population_novelty_hist_le`, `copies_add_no_diversity`.
Proposed edit: one sentence in Diversity.txt: "Total novelty of a population equals its number of
distinct kinds; duplicates add nothing".

## 5. Economy and governance (L82–L86, L99, L113–L117, L157)

**5.1 Infrastructure is a resource, not a fee (B, confirms).**
MM compute and Technology Network bandwidth enter the action's resource cost (L83, L86), are burned
(L99), and providers are paid via CD (L96). A flat protocol fee has no source.
Lean: `Economy.Pricing`, `price_strictly_increases_with_compute`, `heavier_model_less_efficient`.
Proposed edit: Benefuture currency.txt: "There is no protocol fee; infrastructure is accounted as
resources consumed".

**5.2 The delegation cap bounds concentration at cap + one delegation (B).**
Under L114, a delegate can end at most one delegator's weight above Th_k, not at Th_k.
Lean: `accumulate_capped_bound`.
Proposed edit: L114 note `⇒ CumulativeVoteWeight ≤ Th_k + max VW_i`.

**5.3 Base voting weight (B).**
Government.txt has VoteWeight = BaseWeight + ExpertiseWeight·Expertise + ImpactWeight·Impact;
L113 has no base term.
Proposed edit: L113 `BfDm := (Base + Expert(Σŵ·Re)·VW + Impacted·VW) …`.

**5.4 SigThGv must reject inadmissible proposals (B).**
Theorems hold everywhere in the admissible region; governance must not leave it. Perturbation drift
is bounded by n·δ after n steps, so large moves require debate.
Lean: `Admissible`, `gov_step`, `governed_params_admissible`, `perturb_run_drift`.
Proposed edit: L157 `SigThGv := Ap(Th ∈ Debatable? LqdBfDm : Perturb(Th ± δ ∈ Fr)) | Admissible(Pm)`.

**5.5 EHR is under-specified (C).**
L117 combines tit-for-tat with α·Re₊·P(Forgive) and δ·Re₋·P(Overreact); the spec encodes only
harm − α·Re₊. A generous tit-for-tat reading (forgiveness probability rising with Re₊, overreaction
with Re₋) is plausible but unratified.

**5.6 Reputation decay form and partition of unity (C).**
Exponential vs subtractive decay (§4.3 of SPEC_DIVERGENCES) and one vs per-RelType partitions of
unity (§3.2) remain open in the sources.

## 6. Process

**6.1 Two pseudocode copies diverged.** The root copy predated recorded decisions; it is now synced.
Keep one source (spec/), or generate the other.

**6.2 Encodings.** About 25 modules use fixed-point integers; they are within one micro-unit of the
ℝ definitions (`Systems.FixedPoint`). Not a source issue, but the sources could state SCALE
semantics if fixed point is intended for implementations.
