# Claims record

<!-- Moved from README.md (2026-11-06) to keep the README short; links and claims unchanged. -->

## 2. Verified claims at a glance

Each row pairs the result with the preconditions it needs. "Proved" means checked by Lean in CI. The
simulation column cites the current build (`c2cc169`), with readings restated under author ruling 8.85
(time-decayed accuracy) where they changed. Full statements and links are in
[§4](#4-claims-record).

| Invariant / mechanism | Lean 4 proof and module | Julia simulation (current build) | Explicit preconditions |
| :--- | :--- | :--- | :--- |
| Goal G is sound and never picks a dominated plan | [`goal_G_sound`](../Benefuture/Proposed/PopulationDirection.lean), [`dominated_plan_not_chosen`](../Benefuture/Proposed/PopulationDirection.lean), [`admissible_dominated_plan_not_chosen`](../Benefuture/Proposed/PopulationDirection.lean) | With perfect measurement the floors and peak of understanding never fall ([m0_tests](../sim/test/m0_tests.jl)); with noise the guarantee is only as good as measurement | [P] design; positive weights and exponents, κ ≥ 0, λ ∈ [0, 1]; dominance over beings present at decision time |
| The floor cannot be gamed by removing beings | [`removal_cannot_raise_floor`](../Benefuture/Proposed/PopulationDirection.lean), [`removal_cannot_raise_quantile_floor`](../Benefuture/Proposed/PopulationDirection.lean); counterexample [`survivor_floor_rises_on_removal`](../Benefuture/Proposed/PopulationDirection.lean) | M7: removing the two worst-off for +3 to everyone else is not chosen | Floor taken over the decision-time population, not survivors |
| Reporting a flaw dominates exploiting it | [`revelation_dominant`](../Benefuture/Proposed/RevelationGame.lean), [`exploit_not_equilibrium`](../Benefuture/Proposed/RevelationGame.lean); counterexample [`revelation_needs_clawback`](../Benefuture/Proposed/RevelationGame.lean) | A caught deceiver ends behind its honest self (−267 ± 174, 12 seeds) ([m6_tests](../sim/test/m6_tests.jl)) | Full clawback plus restitution once anyone else reports; bounty split among reporters |
| Bounty farming is unprofitable | [`bounty_incentive_compatible`](../Benefuture/Governance/Incentives.lean) | Frivolous reporters pay for their audits | Clawback ≥ bounty + damage; detection probability > bounty ÷ clawback |
| Capped delegation bounds concentration | [`accumulate_capped_bound`](../Benefuture/Governance/Incentives.lean), [`capped_influence_vanishes`](../Benefuture/Proposed/DelegationWisdom.lean); counterexample [`uncapped_star_no_wisdom`](../Benefuture/Proposed/DelegationWisdom.lean) | Pathologies bounded: 96.8 / 95.9 / 96.3% against 85.6 / 77.6 / 65.2% uncapped, 6 seeds ([m5_tests](../sim/test/m5_tests.jl)) | One round, independent signals; repeated rounds are a conjecture |
| Sampling error never mints or destroys currency | [`shapley_sampled_efficient`](../Benefuture/Proposed/ShapleySampling.lean), [`hoeffding_count_suffices`](../Benefuture/Proposed/ShapleySampling.lean) | Sampled shares within ε × marginal range of the exact ones ([shapley_sampling_tests](../sim/test/shapley_sampling_tests.jl)) | Hoeffding's inequality cited, not proved |
| Reputation is conserved and local | [`conservation_positive`](../Benefuture/Ontology/Reputation.lean), [`reputation_locality`](../Benefuture/Ontology/Reputation.lean) | Payments and reputation never leak across domains ([m3_tests](../sim/test/m3_tests.jl)) | Every action's shares sum to 1 |
| Credence from the record is robust to outliers | [`recordCredence_one_error`](../Benefuture/Proposed/RecordCredence.lean), [`recordCredence_bounds`](../Benefuture/Proposed/RecordCredence.lean) | Under heavy-tailed side harm: runs without halts 4 of 12 against 0 of 12; floor growth +51 ± 16 (paired, significant) ([calibrated_tests](../sim/test/calibrated_tests.jl)) | Realistic world, 250 steps, 12 paired seeds, 8.85 accuracy |
| Strictly proper scoring | [`brier_score_strictly_proper`](../Benefuture/Governance/Incentives.lean) | Biased-but-precise models lose to unbiased ones ([m1_tests](../sim/test/m1_tests.jl)) | Binary outcomes |
| Identity binding against whitewashing | (rule in `BenefutureReference/Records.lean`; no ℝ theorem) | Binding leaves model accuracy equivalent to no whitewashing (−0.003 ± 0.002, margin 0.02, 10 seeds) ([m6_attacks_tests](../sim/test/m6_attacks_tests.jl)) | Technology Network clusters attest; weighted by attestation record (8.70) |
| Optimised attacks | — | Cross-entropy search: economy margin 0.38 on held-out seeds (1 = unattacked, < 0 = failure), with the bloc poorer than honest; governance margin 0.20 ([attack.md](../sim/battery/results/attack.md)) | Attack budget at the realistic top of range; small search (8 × 4); build `102474a` |
| Failure boundaries | — | Economy: 1 of 64 screened worlds fails (severities to 0.67); single-factor limits at markers 1.44× and execution 1.73× the realistic bad end, the rest not within 2× (build `102474a`). Governance: 0 of 128 fail ([results](../sim/battery/results)) | Severity 1 = realistic bad end; search to 2; recorded builds in each file |
| Modelled transitions are safe | [`step_preserves_mem`](../Benefuture/Systems/State.lean), [`step_preserves_escrow_soundness`](../Benefuture/Systems/State.lean) | Books balance under every noise source at once ([m3c_tests](../sim/test/m3c_tests.jl)) | Over the modelled `Step` relation |
| Parameters stay admissible under governance | [`governed_params_admissible`](../Benefuture/Systems/ParamSpace.lean), [`perturb_run_drift`](../Benefuture/Systems/ParamSpace.lean) | Within ±0.02 per epoch, outcomes do not depend on them ([m4_tests](../sim/test/m4_tests.jl)) | Steps from the bootstrap point by SigThGv |


##  Recent architectural and verification milestones

**Three-tier Lean architecture.** The tiers are:

- **Specification:** [`Benefuture/`](Benefuture), over ℝ with Mathlib.
- **Reference:** [`BenefutureReference/`](../BenefutureReference), Float, Mathlib-free, exported to C.
  A CI guard enforces that it never imports Mathlib or `Benefuture.*`.
- **Bridge:** [`BenefutureTest/`](../BenefutureTest), compiled with every `lake build`.

Julia calls the reference by `ccall` and holds only the world model and input guards. A new rule is a
Lean function plus one export, never a Julia reimplementation. Two exceptions remain and are listed
as candidates to move ([parsimony audit](../sim/README.md#parsimony-audit)).

**Differential interval-bound ℚ oracles** ([`BenefutureTest/Differential.lean`](../BenefutureTest/Differential.lean)).
The bridge works in two links:

- **ℝ to ℚ, proved.** For eleven rules a ℚ oracle is *proved* equal to the ℝ specification after
  casting ([`supplyQ_spec`](../BenefutureTest/Differential.lean), [`cappedQ_spec`](../BenefutureTest/Differential.lean),
  [`shapleyQ_spec`](../BenefutureTest/Differential.lean), [`sampledQ_spec`](../BenefutureTest/Differential.lean),
  [`recordCredenceQ_spec`](../BenefutureTest/Differential.lean), [`votingWeightQ_spec`](../BenefutureTest/Differential.lean)
  and others; 12 theorems).
- **ℚ to Float, tested.** The Float reference is tested against those oracles on generated dyadic
  inputs to 1e-9 relative.

The latest addition covers rules that use exp, log or sqrt (`Rep_decay_ref`,
`shapley_sample_count_ref`, `phi_ref` at q = 1, `normal_cdf_ref`, `credence_ref`). Rational
enclosures (Heron bounds for √, range-reduced bounds for exp) must contain the Float result.
Float rounding is still sampled, never bounded, and there is no refinement proof from ℝ to Float.

**Ghost audit, parts 1 and 2** ([`sim/README.md`, Ghost audit](../sim/README.md#ghost-audit)).
The author ruled that "an unnamed scalar is a ghost in the system".

- **Part 1** named every scalar in the economy (M3c), governance (M5) and population (M7) rungs.
  Each became a governed threshold, a world parameter with a noise range, or a listed definitional
  constant (the coin toss's 0.5, Laplace's +1/+2, numerical tolerances).
- **Part 2** lifted the last two literals out of Lean reference rules. `currency_eligible_ref` now
  takes the **novelty floor** (`novel_floor`, 0.55, ruling 8.35), the least bar a new domain's model
  must clear to back a currency. `scarcity_cost_ref` now takes the **scarcity floor**
  (`scarcity_floor`, 0.001, L83), the capacity share below which scarcity pricing stops rising.

The result is that every coefficient a rule uses can now be governed and swept. These are governed
parameters, not theorems. The formerly literal M0 constants (harm weight's κ and q, Freedom's severity
multipliers) were lifted into governed parameters read from `bootstrap_params()` (`HaWt_params_ref`,
`fr_permissible_params_ref`).

**Spec 8.85 restatements.** Author ruling 8.85 replaced fixed record windows with **time-decayed
accuracy**. Each record weighs 2^(−age/h), and the half-life h follows the domain's transaction rate
with muted dependence (β = 0.5): busy domains get steadier, slow ones react faster. Implemented as Lean
`decay_halflife_ref`, `decayed_accuracy_ref` and `decayed_mean_se_ref`, and shown in a probe first.
The remaining record-count windows were converted in full to time-decayed weighting: time-decayed
record credence (`decayed_record_credence_ref`), time-decayed RMS uncertainty (`decayed_rms_ref`),
actor track-record corrections, and AdvAp `adv_window`.
Every affected test was then re-run, and the suite itself was hardened: `runtests.jl` used to stop at
the first failing file, which had hidden three later failures; it now runs every file and fails at the
end. Under the new rule:

- **Record credence keeps the currency regime.** This is a significant paired effect over 12 seeds.
- **Whitewashing with identity binding** is shown *equivalent* to no whitewashing within a stated
  margin.
- **Extremist takeovers** are stated as a regime with its interval: 9 of 9 takeovers over 12 seeds.
- **Better-models takeover regime:** over 400 steps 16 of 24 seeds (interval 0.46–0.82); over 800
  steps 64 of 64 under either accuracy rule (interval 0.94–1.00): a short-horizon effect. Floors lose no
  more than 5% of their growth (equivalence test).

Three earlier claims did not survive and are recorded as **unsupported** rather than tuned until they
passed: the cost of *unbound* whitewashing, the takeover-record bar's no-effect, and the debatable
escape's adoption of a relative bar in the low-skill world (0 of 16 seeds, mean z −0.24). Why that
last one changed is open; an earlier macOS pass at seed 31 was dropped because the seed was chosen
after seeing it ([BACKPROPAGATION 8.85](BACKPROPAGATION.md)). The project applies
[adversarial adaptation](https://benefuture.miraheze.org/wiki/Adversarial_adaptation) to itself: a
claim that stops holding is withdrawn in the open, not retuned until it passes.

**Spec 8.86 Accession, settlement, and population ethics.** Author ruling 8.86 and its addendum address
forced additions (births, mergers, accession of suffering polities): taken as given and answered by
uplift. Admissibility requires that no existing being ends lower over the long-term window (`Ha_lt`)
without loud degradation logging ([`addition_lowering_floor_inadmissible`](../Benefuture/Proposed/PopulationDirection.lean),
[`strong_accession_preserves_existing_beings`](../Benefuture/Proposed/PopulationDirection.lean),
[`accession_fallback_never_stalls`](../Benefuture/Proposed/PopulationDirection.lean),
[`accession_uplift_beats_inaction`](../Benefuture/Proposed/PopulationDirection.lean)).
The settlement theorems prove that settling on measured outcomes removes gains from overstated
predictions and gaming the birth model pool ([`settlement_removes_overstatement_gain`](../Benefuture/Proposed/PopulationDirection.lean),
[`unbiased_settlement_removes_expected_gain`](../Benefuture/Proposed/PopulationDirection.lean),
[`birth_settlement_removes_overstatement_gain`](../Benefuture/Proposed/PopulationDirection.lean),
[`transaction_settlement_removes_overstatement_gain`](../Benefuture/Economy/Pricing.lean)).
A 4-part accession probe in [`sim/test/probe_tests.jl`](../sim/test/probe_tests.jl) and [`sim/test/m7_tests.jl`](../sim/test/m7_tests.jl)
demonstrates newcomer uplift with resident protection, counterexample stall, newcomer majority, and loud fallback.

**Theoretic extensions: timed revelation dominance and multi-round delegation (A1, A2).**
- Multi-round liquid delegation: the single-round cap bound `cap + M` is proved invariant across
  arbitrarily many rounds of delegation ([`multi_round_weight_lt`](../Benefuture/Proposed/DelegationWisdom.lean)),
  as delegates reaching the cap accept no further weight in subsequent rounds.
- Multi-step timed reporter's schedule: in `Benefuture.Proposed.RevelationGame`, immediate reporting
  weakly dominates delayed reporting or silent exploitation across all profiles, and strictly dominates
  whenever another agent reports before the planned delay ([`immediate_revelation_dominates`](../Benefuture/Proposed/RevelationGame.lean),
  [`immediate_revelation_strictly_dominates_when_preempted`](../Benefuture/Proposed/RevelationGame.lean)).

**Historical decisions replayed as-of (Task E4, `docs/DATA.md` §16): machinery built, evidence not yet.**
Built: a pre-registration with thresholds read from the governed point ([`docs/REPLAY_PREREG.md`](REPLAY_PREREG.md)),
the replay engine ([`sim/src/replay.jl`](../sim/src/replay.jl)), counterfactual estimators (synthetic control,
difference-in-differences, inverse-variance combination; [`sim/src/counterfactual.jl`](../sim/src/counterfactual.jl)),
a forecasting layer scored by quantile (pinball) loss in Lean (`pinball_loss_ref`, `quantile_score_ref`, with a
probe) and a rolling-window forecast replay, tested on a synthetic case with a known right choice
([`sim/test/replay_tests.jl`](../sim/test/replay_tests.jl)). Options are priced from what was known at the time:
each option's scenarios carry the consequences known before the decision and probabilities computed from as-of
event records (Lean `event_rate_ref`, `expected_effect_ref`); typed effects are flagged unsupported. Of the 12
pre-registered primary cases, 9 replay this way, 2 stay unsupported (thalidomide, Ragusa: no verifiable as-of
rates) and 1 was not built ([8.94](BACKPROPAGATION.md)). Benefuture agrees with the 2 good actual decisions,
differs from the 4 bad ones (Challenger: delay, at a loss probability of (5/6)(1/9) ≈ 0.09 from the record), and
differs on the 3 unclear ones. **That is not yet evidence**: the cases were chosen knowing their outcomes, rates
rest on 1 to 6 prior trials, most magnitudes are judgements, sources were checked mainly from abstracts, and the
baselines are not run.

**Test and compute infrastructure.** Probes now cover every core mechanism (19 audited); the eight that
only called a rule function were rebuilt as small-world probes with acceptance and counterexample cases.
The full suite runs as 8 parallel CI shards; batteries shard by seed range across free runners and merge
their results (checked: a sharded run reproduces the unsharded row count). Platform floating-point
differences are treated as noise: assertions are distributional (paired effects, equivalence,
proportions), never fixed offsets over a few seeds.

**Overnight long-horizon & century simulation suite** ([`sim/battery/long_horizon.jl`](../sim/battery/long_horizon.jl), launcher [`tools/battery/overnight.sh`](../tools/battery/overnight.sh)).
Extended-duration battery sweeps: 10-year scaled economy (5,000 steps), 20-year governance (1,000 decisions),
composed 100-year century simulation with rare catastrophes and breakthroughs per ruling 8.64, and 64-seed sweeps
over open questions from 8.85 and 8.81.

**Multi-threaded failure-boundary battery** ([`sim/src/battery.jl`](../sim/src/battery.jl),
[`sim/battery/`](../sim/battery), launcher [`tools/battery/run.sh`](../tools/battery/run.sh)).
Batteries run detached with `julia -t auto`, using `Threads.@threads` over worlds, rays and screening
samples. Each evaluation is cached on disk under a hash of the code it runs, behind a lock
(`ReentrantLock`). A container restart therefore resumes rather than repeats a run, and a code change
starts fresh. The batteries combine PRIM boxes, Sobol indices, active learning and a cross-entropy
attack search. Cross-machine timings are in [`tools/bench/bench.jl`](../tools/bench/bench.jl) and
[COORDINATION §2b](../COORDINATION.md), including an 8-core Apple M1.

---


##  Claims record

What this repository establishes, in plain words, with links to the proof or the code. There are three
kinds of evidence, and none should be read as more than it is:

- **Proved** (Lean 4 with Mathlib, over ℝ unless noted; checked by CI, with no `sorry`, `admit`,
  custom axioms or `native_decide`). True of the definitions as written, under the hypotheses listed.
  Silent on whether the definitions describe the world.
- **By construction:** the theorem confirms that a rule is encoded as intended. These check the
  encoding; they are not discoveries.
- **Demonstrated in simulation:** observed in `sim/` under stated toy assumptions. Newer claims follow
  the significance rule: paired seeds, effects beyond z standard errors, no-effect claims by
  equivalence within a stated margin, and regimes as proportions with intervals. Older readings are
  means over a few seeds and say so. Testing against the Lean vectors is verification, not
  validation: no simulation result has been checked against data from the world.

`python3 tools/check_readme_claims.py` checks that every theorem named here exists in the file
linked. [`docs/THEOREM_INDEX.md`](THEOREM_INDEX.md) lists every theorem with its docstring. It
is generated and the docstrings are unreviewed, so some overstate; the reviewed claims are below.

### Proved

Synergy and value
- Net synergy rises strictly with the gain potential when λ ∈ [0, 1], and falls strictly with the
  loss potential for λ ≥ 0 ([`net_synergy_raw_strict_mono_plus`](../Benefuture/Math/Synergy.lean),
  [`net_synergy_raw_strict_anti_minus`](../Benefuture/Math/Synergy.lean)). Equal gains and losses net
  strictly negative for λ > 0 ([`equal_gains_and_losses_are_negative`](../Benefuture/Math/Synergy.lean)).
- Squashed synergy Ŝy is odd and lies strictly in (−1, 1) for h > 0 ([`squashed_synergy_odd`](../Benefuture/Math/Synergy.lean),
  [`squashed_synergy_bounds`](../Benefuture/Math/Synergy.lean)). With ν = 1 it is strictly increasing
  ([`squashed_synergy_strictly_monotone_nu_one`](../Benefuture/Math/Synergy.lean)).
- Loss aversion (q₋ > q₊; reference dependence after [Kahneman & Tversky 1979](https://doi.org/10.2307/1914185))
  holds for magnitudes above 1 and **fails** below 1 ([`loss_aversion_holds_above_one`](../Benefuture/Math/Synergy.lean),
  [`loss_aversion_fails_below_one`](../Benefuture/Math/Synergy.lean)). Normalising by the context
  threshold restores it for every significant input ([`significant_assessment_preserves_loss_aversion`](../Benefuture/Math/Synergy.lean)),
  at every admissible parameter point ([`admissible_loss_aversion`](../Benefuture/Systems/ParamSpace.lean)).
- With harm-tier exponent 1.5, doubling a harm more than doubles its weight ([`harm_tier_superlinear`](../Benefuture/Axiology/Priorities.lean)).
  Whether harm tiers trade at a finite rate is open. Under a weighted reading, enough passing harms
  outweigh one irreparable harm ([`finite_exchange_rate_weighted`](../Benefuture/Math/Synergy.lean));
  under a lexical reading none do ([`no_finite_exchange_rate_lexical`](../Benefuture/Math/Synergy.lean)).
- Sy never reverses Pareto dominance, for positive weights and exponents, κ ≥ 0 and λ ∈ [0, 1]
  ([`sy_score_pareto_monotone`](../Benefuture/Proposed/PopulationDirection.lean)).
- Harm reference points: understanding below any earlier level is harm ([`forgetting_is_harm`](../Benefuture/Axiology/Priorities.lean)).
  Happiness at or above its rolling average is not harm ([`h_at_or_above_average_no_harm`](../Benefuture/Axiology/Priorities.lean),
  [`coming_down_not_harm`](../Benefuture/Axiology/Priorities.lean)). The happiness kind tiers sum to the
  bias-corrected happiness score ([`kind_tiers_partition_happiness`](../Benefuture/Axiology/Priorities.lean)).

Goal G and distribution (`Benefuture.Proposed.PopulationDirection`, status [P])
- Inaction is always admissible, so some plan is always chosen ([`inaction_admissible`](../Benefuture/Proposed/PopulationDirection.lean),
  [`goal_G_some`](../Benefuture/Proposed/PopulationDirection.lean)). The chosen plan never contracts
  reality, never lowers the maximum or minimum understanding or the minimum happiness against not
  acting, and maximises the objective over admissible plans ([`goal_G_sound`](../Benefuture/Proposed/PopulationDirection.lean)).
- G never chooses a plan that another admissible plan dominates, meaning one no worse for any being
  present at decision time, better for one, and no worse in distribution. This holds under positive
  weights and exponents, κ ≥ 0 and λ ∈ [0, 1] ([`dominated_plan_not_chosen`](../Benefuture/Proposed/PopulationDirection.lean)),
  and at every admissible parameter point ([`admissible_dominated_plan_not_chosen`](../Benefuture/Proposed/PopulationDirection.lean)).
  Uplift with no losers beats inaction ([`uplift_beats_inaction`](../Benefuture/Proposed/PopulationDirection.lean)).
- The floor is taken over the decision-time population, so removing a being cannot raise it. This
  holds for the literal minimum ([`removal_cannot_raise_floor`](../Benefuture/Proposed/PopulationDirection.lean))
  and for G's thresholded low quantile ([`removal_cannot_raise_quantile_floor`](../Benefuture/Proposed/PopulationDirection.lean)).
  Taken over survivors only, it would rise in both forms ([`survivor_floor_rises_on_removal`](../Benefuture/Proposed/PopulationDirection.lean),
  [`survivor_quantile_floor_rises_on_removal`](../Benefuture/Proposed/PopulationDirection.lean)).
- The distribution term D:
  - ignores the order of beings ([`level_gain_perm`](../Benefuture/Proposed/PopulationDirection.lean))
    and beings absent at decision time ([`dist_score_ignores_absent`](../Benefuture/Proposed/PopulationDirection.lean));
  - for monotone shapes, never rewards levelling down and never penalises uplift
    ([`levelling_down_never_helps`](../Benefuture/Proposed/PopulationDirection.lean),
    [`uplift_gain_nonneg`](../Benefuture/Proposed/PopulationDirection.lean));
  - for concave shapes, is never lowered by a Pigou–Dalton transfer of happiness or a sequence of
    them ([`pigou_dalton_h`](../Benefuture/Proposed/PopulationDirection.lean), [`pd_run_raises`](../Benefuture/Proposed/PopulationDirection.lean));
  - is never lowered by sharing understanding, where the learner rises and the teacher keeps their
    level ([`u_sharing_gain_nonneg`](../Benefuture/Proposed/PopulationDirection.lean)).
- Population:
  - net-negative tallies never outweigh a non-empty set of positive ones ([`net_negative_never_outweighs_positive`](../Benefuture/Proposed/PopulationDirection.lean));
  - copies of one type add at most one type ([`copies_add_no_diversity`](../Benefuture/Proposed/PopulationDirection.lean));
  - summed novelty equals the number of distinct types ([`population_novelty_eq_effective_types`](../Benefuture/Proposed/PopulationDirection.lean))
    and, with history, never exceeds it ([`population_novelty_hist_le`](../Benefuture/Proposed/PopulationDirection.lean)).
- Checking ↑min stepwise is stricter than over a trajectory. A dip that closes is admissible over the
  trajectory but not stepwise ([`tunnel_admissible_but_not_stepwise`](../Benefuture/Proposed/PopulationDirection.lean)).
  A dip still open at the horizon has triggered harm intervention at some step ([`nonclosing_tunnel_triggers_harm_intv`](../Benefuture/Proposed/PopulationDirection.lean)).
- Accession and population ethics (8.86):
  - chosen additions lowering a floor are not G-admissible against inaction ([`addition_lowering_floor_inadmissible`](../Benefuture/Proposed/PopulationDirection.lean));
  - when the strong per-being reading can be met, G preserves every existing being over the long-term window (`Ha_lt`) without lowering anyone ([`strong_accession_preserves_existing_beings`](../Benefuture/Proposed/PopulationDirection.lean));
  - when the strong reading cannot be met, G sets `degraded = true` and falls back to combined floors without stalling ([`accession_fallback_never_stalls`](../Benefuture/Proposed/PopulationDirection.lean));
  - an uplift plan that raises newcomers while protecting existing beings strictly beats inaction ([`accession_uplift_beats_inaction`](../Benefuture/Proposed/PopulationDirection.lean)).
- Settlement (8.86 addendum):
  - settling on measured outcomes removes gains from prediction overstatement for any true value, bias, or confidence ([`settlement_removes_overstatement_gain`](../Benefuture/Proposed/PopulationDirection.lean));
  - under unbiased noise, the expected sum of settled payouts equals `n * (v - cost)` ([`unbiased_settlement_removes_expected_gain`](../Benefuture/Proposed/PopulationDirection.lean));
  - birth escrow settlement removes gains from understating predicted shortfall or gaming model pools ([`birth_settlement_removes_overstatement_gain`](../Benefuture/Proposed/PopulationDirection.lean)).

Economy, reputation and domains
- A closed cycle of transactions with zero predicted value loses exactly its resource cost ([`closed_cycle_arbitrage_negative`](../Benefuture/Economy/Currency.lean)).
  An action no model can value pays its full resource cost ([`unmodelled_action_pays_resource_cost`](../Benefuture/Economy/Pricing.lean)).
  Confident predicted value above cost makes the price negative ([`price_negative_when_value_exceeds_cost`](../Benefuture/Economy/Pricing.lean)).
- Settling transaction pricing on measured outcomes removes gains from prediction overstatement or confidence gaming ([`transaction_settlement_removes_overstatement_gain`](../Benefuture/Economy/Pricing.lean)).
- At a parent domain, aggregated value never exceeds the value an action carried ([`aggregate_no_double_count`](../Benefuture/Ontology/Domain.lean)),
  and parents with larger degrees aggregate more ([`aggregate_monotonicity`](../Benefuture/Ontology/Domain.lean)).
- Reputation:
  - summed over leaf domains, equals the attributed contribution when every action's shares sum to 1
    ([`conservation_positive`](../Benefuture/Ontology/Reputation.lean), [`conservation_negative`](../Benefuture/Ontology/Reputation.lean));
  - leaves untouched any domain outside an action's profile ([`reputation_locality`](../Benefuture/Ontology/Reputation.lean));
  - gives nothing for zero causal contribution ([`reputation_no_transfer`](../Benefuture/Ontology/Reputation.lean));
  - keeps a history that never decreases as memory grows ([`hPos_nondecreasing_on_append`](../Benefuture/Ontology/Reputation.lean)).
- Lazily decayed reputation is exact. Decay distributes over sums, chains across checkpoints, and
  checkpointing changes no later reading ([`cache_correct`](../Benefuture/Systems/State.lean), [`decay_transitive`](../Benefuture/Systems/State.lean),
  [`checkpoint_sound`](../Benefuture/Systems/State.lean)).
- Int fixed-point escrow, assessment normalisation and novelty are each within one micro-unit of
  their real values ([`escrow_fixed_point`](../Benefuture/Systems/FixedPoint.lean), [`norm_assessment_fixed_point`](../Benefuture/Systems/FixedPoint.lean),
  [`novelty_fixed_point`](../Benefuture/Systems/FixedPoint.lean)).
- Fuzzy subsethood lies in [0, 1], equals 1 for a domain and itself, and ignores renaming ([`fuzzy_subsethood_in_unit_interval`](../Benefuture/Proposed/DomainHierarchy.lean),
  [`fuzzy_subsethood_self`](../Benefuture/Proposed/DomainHierarchy.lean), [`fuzzy_subsethood_rename_invariant`](../Benefuture/Proposed/DomainHierarchy.lean)).
  A hierarchy fixed point exists **if** the update operator is monotone, which is assumed, not shown
  ([`hierarchy_fixed_point_exists`](../Benefuture/Proposed/DomainHierarchy.lean)).

Causal distribution (`Benefuture.Proposed.OutcomeDistribution`, [P])
- A duty left undone is assessed negative: measured against the action a contract or communicated
  law committed the actor to, a worse outcome assesses below zero ([`breached_duty_assessed_negative`](../Benefuture/Proposed/OutcomeDistribution.lean)).
  Without a committed action, not acting assesses at zero ([`inaction_without_duty_assessed_zero`](../Benefuture/Proposed/OutcomeDistribution.lean)).
- A contributor whose presence changes no coalition's outcome receives no Shapley share ([`shapley_null`](../Benefuture/Proposed/OutcomeDistribution.lean)).
  Exact efficiency is not proved; it is checked numerically ([shapley_tests](../sim/test/shapley_tests.jl)).
- Shapley by permutation sampling (`Benefuture.Proposed.ShapleySampling`;
  [Castro, Gómez & Tejada 2009](https://doi.org/10.1016/j.cor.2008.04.004), who estimate Shapley
  values by sampling orderings in polynomial time):
  - on every sample, the shares sum to v(all) − v(none) ([`shapley_sampled_efficient`](../Benefuture/Proposed/ShapleySampling.lean));
  - a null contributor gets nothing ([`shapley_sampled_null`](../Benefuture/Proposed/ShapleySampling.lean));
  - a single ordering is inexact ([`shapley_sampled_single_order_inexact`](../Benefuture/Proposed/ShapleySampling.lean));
  - the governed count ⌈ln(2n/δ)/(2ε²)⌉ makes the union bound at most δ ([`hoeffding_count_suffices`](../Benefuture/Proposed/ShapleySampling.lean)),
    and one ordering never suffices ([`hoeffding_one_sample_insufficient`](../Benefuture/Proposed/ShapleySampling.lean)).

  Hoeffding's inequality itself is cited, not proved. The permutation–subset identity is checked
  exactly over ℚ for n ≤ 5 at build time.
- The reporter's schedule (author ruling 8.76): a self-reporter nets one exploit plus the bonus,
  however often it exploited first ([`self_report_net_constant`](../Benefuture/Governance/Adversarial.lean)),
  and reporting oneself beats being caught ([`self_report_beats_caught`](../Benefuture/Governance/Adversarial.lean)).
- Credence from the record (8.66, 8.71) is a model's share of recent errors below its prediction,
  ties counting half. It stays within [1 − cap, cap] ([`recordCredence_bounds`](../Benefuture/Proposed/RecordCredence.lean)),
  rises with the prediction ([`recordScore_mono`](../Benefuture/Proposed/RecordCredence.lean)), and
  moves by at most 1/n over a record of n for any single error ([`recordCredence_one_error`](../Benefuture/Proposed/RecordCredence.lean)).
- Paying positive shares and penalising negative ones distributes exactly the sum of the shares
  ([`sides_sum`](../Benefuture/Proposed/OutcomeDistribution.lean)). Each paid share of its side lies in
  [0, 1] ([`paid_share_in_unit`](../Benefuture/Proposed/OutcomeDistribution.lean)).
- Informed inaction against a committed action is a crime (L115). Inaction without one is not; an
  uninformed breach is an accident ([`informed_inaction_under_duty_is_crime`](../Benefuture/Subgoals/Justice.lean),
  [`inaction_without_duty_is_not_crime`](../Benefuture/Subgoals/Justice.lean), [`uninformed_breach_is_accident`](../Benefuture/Subgoals/Justice.lean)).

Governance and incentives
- The Brier score is strictly proper ([`brier_score_strictly_proper`](../Benefuture/Governance/Incentives.lean);
  [Gneiting & Raftery 2007](https://doi.org/10.1198/016214506000001437), the standard treatment of
  proper scoring rules).
- With the delegation cap, no delegate exceeds the cap plus one delegator's maximum weight ([`accumulate_capped_bound`](../Benefuture/Governance/Incentives.lean)).
- Delegation and wisdom (`Benefuture.Proposed.DelegationWisdom`,
  [P]; after [Golub & Jackson 2010](https://doi.org/10.1257/mic.2.1.112), whose societies become wise
  when no agent's influence stays bounded away from zero). These results hold for one round with
  independent signals:
  - every delegate stays below cap + M, and every share below capShare + M/total ([`round_weight_lt`](../Benefuture/Proposed/DelegationWisdom.lean),
    [`round_share_lt`](../Benefuture/Proposed/DelegationWisdom.lean));
  - the strict rule keeps the largest weight within the cap ([`accumulate_capped_strict_le`](../Benefuture/Proposed/DelegationWisdom.lean)),
    while the ratified L114 rule can overshoot it ([`accumulate_capped_overshoots`](../Benefuture/Proposed/DelegationWisdom.lean));
  - vanishing cap shares make the largest influence share vanish ([`capped_influence_vanishes`](../Benefuture/Proposed/DelegationWisdom.lean));
  - the variance of an influence-weighted mean of independent equal-variance signals is at most the
    largest share times their variance ([`weighted_signal_variance_bound`](../Benefuture/Proposed/DelegationWisdom.lean));
  - without a cap, a star keeps it at a single signal's ([`uncapped_star_no_wisdom`](../Benefuture/Proposed/DelegationWisdom.lean));
  - the single-round cap bound `cap + M` is invariant across arbitrarily many rounds of delegation ([`multi_round_weight_lt`](../Benefuture/Proposed/DelegationWisdom.lean)), because capped delegates accept no further delegations in later rounds.

  Correlated signals remain a conjecture ([SIM_CONJECTURES](SIM_CONJECTURES.md) B26).
- Revealing a flaw strictly dominates exploiting it, for every profile of others' strategies (`Benefuture.Proposed.RevelationGame`,
  [P]). This holds in a game where reporters split the bounty and an exploiter is fully clawed back,
  plus restitution, once anyone else reports ([`revelation_dominant`](../Benefuture/Proposed/RevelationGame.lean),
  [`revelation_weakly_dominant`](../Benefuture/Proposed/RevelationGame.lean)). Under the multi-step timed
  reporter's schedule, immediate reporting weakly dominates delayed reporting or silent exploitation
  across all profiles of others ([`immediate_revelation_dominates`](../Benefuture/Proposed/RevelationGame.lean)),
  and strictly dominates whenever another agent reports before the planned delay ([`immediate_revelation_strictly_dominates_when_preempted`](../Benefuture/Proposed/RevelationGame.lean)).
  Everyone reporting is a Nash equilibrium ([`all_report_nash`](../Benefuture/Proposed/RevelationGame.lean)) and the only one
  ([`exploit_not_equilibrium`](../Benefuture/Proposed/RevelationGame.lean)). The clawback is
  load-bearing: without it, three simultaneous reporters of a gain-10 flaw get 3 each against 10 for
  exploiting ([`revelation_needs_clawback`](../Benefuture/Proposed/RevelationGame.lean)). This is
  mechanism design in the sense of [Hurwicz and Myerson](https://www.nobelprize.org/prizes/economic-sciences/2007/summary/):
  incentive compatibility built in, not assumed.
- Planting flaws to farm bounties is unprofitable in expectation when the clawback covers bounty plus
  damage and detection is likelier than bounty ÷ clawback ([`bounty_incentive_compatible`](../Benefuture/Governance/Incentives.lean)).
- External harm response:
  - forgiveness and overreaction form a valid split ([`probabilities_sum_le_one`](../Benefuture/Governance/ExternalHarm.lean));
  - the expected response lies in [0, (1 + margin) × harm] ([`ehr_response_bounds`](../Benefuture/Governance/ExternalHarm.lean));
  - more positive reputation never raises it ([`more_positive_reputation_lowers_response`](../Benefuture/Governance/ExternalHarm.lean));
  - forgiveness is strictly likelier than overreaction when ledgers are equal and δ < α ([`forgiveness_bias`](../Benefuture/Governance/ExternalHarm.lean)),
    at every admissible point ([`admissible_forgiveness_bias`](../Benefuture/Systems/ParamSpace.lean)).
- Every parameter vector reachable from the bootstrap by governance steps is admissible ([`governed_params_admissible`](../Benefuture/Systems/ParamSpace.lean)).
  n perturbations move a parameter by at most n·δ ([`perturb_run_drift`](../Benefuture/Systems/ParamSpace.lean)).
- The modelled transitions (`Step`) keep memory append-only, identities injective and escrow sound
  ([`step_preserves_mem`](../Benefuture/Systems/State.lean), [`step_preserves_id`](../Benefuture/Systems/State.lean),
  [`step_preserves_escrow_soundness`](../Benefuture/Systems/State.lean)).

Bridge to the reference ([`BenefutureTest/Differential.lean`](../BenefutureTest/Differential.lean))
- The bridge chain is ℝ specification = ℚ oracle (proved, 12 `*_spec` theorems) ≈ Float reference
  (tested within 1e-9 relative on dyadic inputs).
  - Rules covered: `supply_delta`, `competition_efficiency`, `rolling_average`, `accumulate_capped`,
    `p_forgive`, `p_overreact`, `severity_score`, `Voting_weight`, exact and sampled Shapley, and
    `recordCredence`.
  - Interval-bound oracles enclose the nonlinear rules (`Rep_decay`, `shapley_sample_count`, `phi`,
    `normal_cdf`, `credence`).
  - ℤ specifications are compared directly (`bounty_reward`, `upfront_payment`).
  - Rules with real exponents or noncomputable choices rest on `spec/vectors` alone.
- Between the Lean exports and the Julia input guards, property-based differential tests check that
  each guard accepts exactly the rule's documented domain ([differential_tests](../sim/test/differential_tests.jl)).

### By construction

These confirm encoded rules:

- **Priority order.** Understanding over happiness over novelty over harm's base weight ([`understanding_dominates_happiness`](../Benefuture/Math/Order.lean)).
- **Conservation.** Escrow ([`escrow_conservation`](../Benefuture/Economy/Currency.lean)); forks and
  merges ([`fork_conserves_per_domain_currency`](../Benefuture/Ontology/Entity.lean), [`merge_conserves_per_domain_currency`](../Benefuture/Ontology/Entity.lean));
  overflow and its ceiling ([`balance_overflow_conservation_law`](../Benefuture/Systems/Economy.lean),
  [`auto_spill_enforces_ceiling`](../Benefuture/Systems/State.lean)).
- **Phase 1** issues no currency proposals ([`phase1_score_only_forbids_currency_proposals`](../Benefuture/Systems/TechnologyNetwork.lean)).
- **Currency qualification.** A currency needs a qualified model, and qualification depends on
  accuracy alone ([`currency_requires_qualified_model`](../Benefuture/Economy/Currency.lean),
  [`qualification_depends_on_accuracy_only`](../Benefuture/Measurement/MetricModel.lean)).
- **Crime and accident** are mutually exclusive ([`crime_and_accident_mutually_exclusive`](../Benefuture/Subgoals/Justice.lean)).
- **Freedom.** Irreversible harm is impermissible and established severe harm is blocked ([`irreversible_harm_strictly_impermissible`](../Benefuture/Subgoals/Freedom.lean),
  [`established_severe_blocks`](../Benefuture/Subgoals/Freedom.lean)). Freedom is reported per plan, not
  used as a filter on G (SPEC_DIVERGENCES §8.8).
- **Anti-halo isolation** ([`anti_halo_domain_isolation`](../Benefuture/Governance/Democracy.lean)).
  Domain-relative expertise sums to one, and the expertise term never exceeds its weight ([`relative_expertise_sum_one`](../Benefuture/Governance/Democracy.lean),
  [`relative_expertise_le_one`](../Benefuture/Governance/Democracy.lean), [`bfdm_expertise_term_le_weight`](../Benefuture/Governance/Democracy.lean)).
- **Extended self.** Harm to a coupled part of the extended self is harm to the being ([`defection_harms_extended_self`](../Benefuture/Subgoals/Morality.lean)).
- **Infohazards.** Education inoculates against an infohazard ([`education_inoculates_infohazard`](../Benefuture/Epistemology/InfoHandling.lean)).
- **Revelation.** Reporting beats exploiting because the bounty is defined above the gain ([`revelation_strictly_dominates`](../Benefuture/Governance/Adversarial.lean)).
- **Triggers.** Antifragility and continuity triggers fire on their defining conditions ([`harm_growth_activates_intervention`](../Benefuture/Axioms/Antifragility.lean),
  [`rising_harm_mandates_intervention`](../Benefuture/Subgoals/Continuity.lean)).
- **Non-circular metric models,** given the empirical-marker requirement ([`metric_models_are_non_circular`](../Benefuture/Measurement/MetricModel.lean)).

### Negative and open results

- **In a closed economy, pricing out skilled deceivers costs growth (8.115).** Against status-quo institutions in the same world, Benefuture's grow floors and medians about 10% less (8 seeds, z ≈ 11) while cutting the deceivers' advantage sharply. The cost is the deceivers' real work, priced out and not replaced in a fixed eight-agent world with no entry; without deceivers, the same vigilance costs nothing. With open-market proposals (refused slots pass to others) the gap halves (floor of understanding −12 ± 3, floor of happiness −5 ± 2, median of understanding no difference shown). Entry of new producers pending.

Formal and measured limits. Those shared with real institutions are put in context in
[hard problems shared with every institution](#hard-problems-shared-with-every-institution).

- A positive floor moves the repugnant conclusion rather than resolving it ([`floor_shifts_repugnant_conclusion`](../Benefuture/Axiology/RepugnantConclusion.lean)).
  The [P] design answers with the decision-time population and diversity bounds, not with the floor.
- Skew direction alone admits plans that lower the minimum ([`skew_direction_alone_permits_min_decline`](../Benefuture/Proposed/PopulationDirection.lean)).
- Freedom excludes irreversible harm even when it is necessary and net-positive ([`freedom_excludes_irreversible_necessary_harm`](../Benefuture/Subgoals/Freedom.lean));
  the tension is open.
- Without a delegation cap, a star topology hands one node all the weight ([`star_topology_power_concentration`](../Benefuture/Governance/Incentives.lean)).
- Shapley shares invite false-name manipulation ([Aziz et al. 2011](https://doi.org/10.1613/jair.3166),
  who show that splitting identities can raise a player's power in weighted voting games). An
  indispensable funder split into k identities takes k/(k+1) of the outcome instead of 1/2
  ([shapley_sampling_tests](../sim/test/shapley_sampling_tests.jl); 8.57-a, open).
- Clamped causal contribution over-distributes along a chain with a loss ([`cc_clamped_overdistributes`](../Benefuture/Systems/Substrate.lean)).
  Resolved by ruling 8.14: credit follows an outcome's assessed parts.
- The reputation recount is symmetric in the sense of [Cheng & Friedman 2005](https://doi.org/10.1145/1080192.1080202),
  who prove that symmetric reputation functions cannot be sybilproof, so the recount is not
  sybilproof. Identity binding is what stops sybils. Splitting a harm across identities lightens its
  penalty (8.58-e, open).
- On-off deceit defeats the track record and takes a capable domain's currency down, and AdvAp's
  repair does not undo it (8.58-d, open).

### Demonstrated in simulation

These are toy-world readings, never certain (author ruling 8.33). They show how the rules behave when
the world is noisy, people are imperfect and some actors are hostile; they are not forecasts.

**World defaults.** Defaults are calibrated to empirical sources at the mildly imperfect end of their
realistic range ([`docs/CALIBRATION.md`](CALIBRATION.md); [Noise](../sim/README.md#noise)).
Institution-dependent rates (vigilance, audit, deceit prevalence, delegation, research share) are
swept, never defaults, because in a Benefuture society they should emerge from its incentives.

**Toy assumptions still to be removed** ([model ladder](../sim/README.md#model-ladder)):

- small abstract worlds of 50–200 beings;
- Gaussian model and measurement error;
- fixed agents and skills;
- one measured value per plan.

Coverage of the Lean modules: [sim/README.md, coverage](../sim/README.md#coverage-of-the-specification).

Measurement, agents and domains
- **Measurement.** With perfect measurement the floors and peak of understanding never fall ([m0_tests](../sim/test/m0_tests.jl)).
  With noise, the floor guarantee is only as good as measurement ([M1](../sim/README.md#m1-observations)).
  Metric model competition settles on the most accurate model, and a precise but biased model loses
  to an unbiased one ([m1_tests](../sim/test/m1_tests.jl)).
- **Calibrated world.** The economy converges unevenly: floors grow in every seed, and heavy-tailed
  hazards make harm's peak about four times deeper than Gaussian ones. With every noise source at its
  realistic bad end, floors still rise, at a twelfth to a fifth of clean growth (8.65) ([calibrated_tests](../sim/test/calibrated_tests.jl),
  [friction_m3c_tests](../sim/test/friction_m3c_tests.jl)).
- **Currency moves only by outcomes** (L99). Total balances change by exactly the sum of
  `supply_delta_ref` plus lane burns ([probe_tests](../sim/test/probe_tests.jl)).
- **Domain network.**
  - Missing domains form from clustered blocked work within about 20 steps.
  - Work no currency can value is screened by G on the best available model.
  - The books balance under every noise source at once ([m3c_tests](../sim/test/m3c_tests.jl)).
  - Balance overflow trades reinvestment against concentration: share reinvested 84% → 11% as the
    Gini rises 0.18 → 0.53 ([M3c](../sim/README.md#m3c-observations)).
- **Better models over time** (8.42.2, restated under 8.85). Challengers take over a domain's currency
  only by the significance rule. The takeover regime holds in 16 of 24 seeds over
  400 steps (interval 0.46–0.82) and in 64 of 64 over 800 (0.94–1.00), and floors lose no more than 5%
  of their growth (equivalence) ([models_tests](../sim/test/models_tests.jl)). Over 800 steps time-decayed
  accuracy (8.85) beats the fixed record window on 64 paired seeds: more takeovers (+12.3 ± 1.6, z 7.7),
  more work priced in the domain's own currency (+0.056 ± 0.013, z 4.2) and faster floor growth
  (+88 ± 24, z 3.6) ([long_horizon](../sim/battery/results/long_horizon.md), build `5605704`). Under re-check: a 16-seed re-run on the current head in a different configuration did not show these effects (floor +70 ± 50, z 1.4); the exact 64-seed, 800-step replication is queued.
- **Collusion over 20 years of governance.** With 100 voters, stealth collusion and delegation over 1,200
  decisions, AdvAp raises late accuracy by +0.026 ± 0.002 (z 10.7, 24 paired seeds); a residual cost
  against a collusion-free world (−0.003 ± 0.001, z −3.0 on build `5605704`) did not replicate on the current head (−0.002 ± 0.002, z −1.2, 16 seeds): unsupported ([long_horizon](../sim/battery/results/long_horizon.md), build `5605704`).

Transactions and causal distribution
- **Transactions.** About four actions a step instead of one choice by G, roughly three times the
  floor growth, and more mediocre work admitted (9% harmful against 2%) ([m3d_tests](../sim/test/m3d_tests.jl)).
- **Outcome-first causal distribution.** Intermediaries who add nothing earn almost nothing, bad
  outputs are penalised through the losses they carry downstream, and every outcome is fully
  distributed ([m3d_tests](../sim/test/m3d_tests.jl)). Beyond 10 contributors, sampled Shapley shares
  match exact or closed-form ones within the bound ([shapley_sampling_tests](../sim/test/shapley_sampling_tests.jl)).

Hazards and black swans
- **Hazards.** Unguarded hazards cut floor growth by a sixth. Contracted guardians recover most of
  it, and repair through the commons largely pays for itself ([m3e_tests](../sim/test/m3e_tests.jl)).
- **Measurement outages** hide nothing once markers return ([m3f_tests](../sim/test/m3f_tests.jl)).
- **Catastrophes** recover in one step when repaired through the commons, against 30–40 steps alone.
- **Captured models** lose eligibility and requalify.
- **Breakthroughs** raise floor growth by a third.

Gaming and attacks (M6)
- **Fooling every model** gains nothing relative to peers once models price actors by their record
  (8.29) and escrow settles on outcomes. AdvAp cuts blocked marginal domains from 9 to 3 over 24
  seeds ([m6_tests](../sim/test/m6_tests.jl)).
- **Colluding voters** that defect where outcomes stay hidden are exposed by AdvAp's manufactured
  prisoner's dilemma. Accuracy on hidden decisions is restored to 99.7% and the bloc's expertise share
  falls from 0.74 to 0.15 (4 seeds) ([M6](../sim/README.md#m6-observations)).
- **Attacks from the literature** ([attacks](../sim/README.md#attacks-from-the-state-of-the-art-docssotamd-items-5-7-10-backpropagation-858-ae);
  [m6_attacks_tests](../sim/test/m6_attacks_tests.jl)):
  - **Decision markets** ([Chen et al. 2014](https://doi.org/10.1145/2556271), on eliciting
    predictions when only the chosen action's outcome is observed): full-support exploration catches
    unscored misreports.
  - **Extremised forecasts** ([Witkowski et al. 2023](https://doi.org/10.1287/mnsc.2022.4410), on how
    winner-take-all forecasting contests reward extremising): extremists dominate takeovers (9 of 9
    over 12 seeds) because honest credences are underconfident there (8.58-c, open).
  - **Reputation attacks** ([Hoffman, Zage & Nita-Rotaru 2009](https://doi.org/10.1145/1592451.1592452),
    a taxonomy of attacks on reputation systems): binding makes whitewashing equivalent to none, and
    slandering convicts no one.
  - **Goodhart under selection pressure** ([Gao et al. 2023](https://arxiv.org/abs/2210.10760), on
    proxy over-optimisation): without track records the proxy gap grows from 16.6 to 20.5 as
    candidates go from 2 to 32; with them it stays within half a unit.
- **Optimised attacks** (cross-entropy method) found no strategy that breaks the success pattern; the
  worst cases are frozen as tests ([attack_tests](../sim/test/attack_tests.jl), [attack.md](../sim/battery/results/attack.md)).
  A search this small is weak evidence that no breaking strategy exists.

Governance and thresholds
- **Weighted voting.** Expertise-weighted votes decide better than one person, one vote (98.5%
  against 94.8%). Domain-relative expertise keeps most of that accuracy with far less concentration
  ([m5_tests](../sim/test/m5_tests.jl)).
- **Deliberation** with realistic advice-taking ([Soll & Larrick 2009](https://doi.org/10.1037/a0015145),
  who found people often choose one opinion rather than average two) decides as well as voters alone
  on factual decisions. Source tags remove the echo cost.
- **Divided experts.** Hearing both sides plus diversity's trials finds the better option 84.4% of the
  time, against 73.8% with neither ([deliberation](../sim/README.md#clean-deliberation-and-better-models-in-governance-8422-843)).
- **Parameter governance.** Governed parameters stay admissible under SigThGv. Adaptation run as
  experimental design shifts only on significant gains ([m4_tests](../sim/test/m4_tests.jl)).
- **The debatable escape** (L157) trial machinery works: gains exceed harms and nothing is irreparable
  in every seed. Adoption of the relative bar in the low-skill world is unsupported under the current
  build (0 of 16 seeds) and recorded open ([debatable escape](../sim/README.md#the-debatable-escape-8263-8382-841)).

Population (M7)
- **Deaths.** The trolley switch is chosen, except when the one holds the peak of understanding.
  Removing the worst-off for gains to others is not chosen ([m7_tests](../sim/test/m7_tests.jl)).
- **Births.** Births are escrowed against predicted shortfall, and over-optimistic causers are
  clawed back (finding 8.54).
- **Population ethics.** G avoids the Repugnant Conclusion in probes. It gives up Non-Sadism only in a forced addition (8.56), which by ruling 8.86 is taken as given and answered by uplift.
- **Accession and forced additions (8.86).** A joined population well below the floors is uplifted by G without harming existing beings over their long-term counterfactual window; when a large accession cannot meet the strong per-being reading, G falls back to combined floors with loud progressive degradation logging and zero stalls ([probe_tests](../sim/test/probe_tests.jl), [m7_tests](../sim/test/m7_tests.jl)).
- **Teaching and research** are complements; uplift peaks near a fifth of time on research.

Historical decisions and long horizons
- **Real forecasters' skill persists, moderately (E4 measurement layer, the first real-data result).** On the COVID-19 Forecast Hub (US weekly deaths, one week ahead, 10 teams, 140 weeks), scored by the Lean quantile score on rolling 6-week windows, team rankings in consecutive windows correlate at 0.36 ± 0.09 (z ≈ 4, 22 window pairs), and a ranking from L weeks of record predicts the next period at about 0.36 for L = 2, rising to a plateau near 0.5 from about five weeks. So weighting by record is justified but noisy, and most of its information arrives within about five resolved forecasts, in line with Benefuture's minimum record of five and time-decayed records ([BACKPROPAGATION 8.93](BACKPROPAGATION.md)). Caveats: one target, a pandemic regime, truth at the final vintage.
- **The honesty of claims is read apart from skill (8.101).** Six actors in one leaf, skill high or low crossed with honest or overstating: over 10 seeds, founded audit reports land only on the overstating actors, never on an honest one of either skill (10 of 10 seeds, interval 0.71–1.0), and deceit roughly halves a skilled liar's earnings and cuts an unskilled liar's by about nine-tenths against honest actors of equal skill (z = 3 on the probe world). Condition: models correct each prediction by the actor's own track record (8.29). Toy assumptions: one leaf, a fixed overstatement, the probe's audit and trace rates ([probe](../sim/test/probe_tests.jl)).
- **Understanding measured by its equation tracks the truth, with one weak part (8.102, 8.103).** True understanding is the pragmatic equation (L31) on a being's hidden traits, with accuracy net of irreducible uncertainty (author ruling 8.103); measured, the same equation on its outputs. Over 40 random beings (z = 3; mean true understanding 0.32): error from the record falls from 0.028 to 0.010 as it grows from 10 to 200 reports per item, and a noisy reading of map fit then sets a floor (≈ 0.024 at σ 0.05); overconfident reporting lowers measured understanding (−0.05, proper scoring); unaudited overclaims of causal explanation inflate it (+0.14, about 45%), and audits remove that bias; exact knowledge of a fair coin counts as full understanding ([probe](../sim/test/probe_tests.jl)). Toy assumptions: one thing, five fixed items with one outcome probability each, no learning, judged noise levels.
- **Unaudited claims of understanding slow the floor (8.104).** In M7, entities see each being's understanding as the pragmatic equation reads its outputs and predict lessons on that view. When a third of beings overclaim causal explanation and nothing is audited, they are taken for teachers and their lessons pass on little: floor growth of understanding falls by 41% (8 seeds, z ≈ 4.6); auditing half the claims recovers about half the loss, 90% most of it, all of it fully. Toy assumptions: fixed traits, one measured thing, a constant overclaim, audits at a set rate rather than earned by reporters ([probe](../sim/test/probe_tests.jl)).
- **Learners' reports find overclaimed understanding (8.105).** In M7, with no set audit rate, learners report teachers whose lessons fall short of prediction beyond the general shortfall; 95–100% of overclaimers are audited, most within 10 steps, and floor growth recovers from 7.1 to 9.3 (honest 12.2; 8 seeds, z ≈ 2.6). The rest is lost early, before detection. Toy assumptions: no audit cost or reporter reward in M7, fixed traits ([probe](../sim/test/probe_tests.jl)).
- **Competing measurement chains expose hidden harm (8.108).** When one chain counts only half of each loss (as counting deaths by last symptom does), consuming its output alone hides harm (measured value +3.4 above true, z = 3); reading through the measurement domain instead (a second chain of another paradigm, audits where chains diverge, chains scored against audits) demotes the biased chain after 5–11 audits, then reads outcomes at their true size with audits on under 4% of them, and never demotes honest chains; a wrong majority of agreeing chains is demoted in favour of a right minority (audits weigh the shared observable, not votes), and a 10% bias is caught after 23–34 audits. A fake second paradigm (a secret copy of the biased chain) is caught by agreeing more closely than independent noise allows, and spot audits then demote the original (6 of 6 seeds; residual bias from before detection). Toy assumptions: chains differ only in attribution, the audit reads the shared observable, one leaf ([probe](../sim/test/probe_tests.jl)).
- **Understanding as its equation, with models taught whole (8.110).** In a traits world where each being's understanding is the pragmatic equation on its model bundles, explanation and practice: no learner ever ends with one model's accuracy and another's simplicity (structural); teaching raises floor growth of understanding (+0.59 on a 0–1 scale, 8 seeds, z ≫ 3); teachable breakthroughs spread lower complexity; practice alone raises the median; when a third overclaim explanation, learners' reports audit every overclaimer and no honest being and recover the floor (0.47 → 0.615, honest 0.62). Ported into M7 with its full machinery (G per entity, happiness, research spending): floor growth 15.4 against scalar M7's 12.4, peak lower (bounded per thing) (8.112). Toy assumptions: one thing, no accession in traits mode ([probe](../sim/test/probe_tests.jl)).
- **Benefuture's governance beats one person one vote as the world gets harder (8.114).** Same population, worlds and seeds: at the realistic bad end (noisy signals, scattered ability, hidden outcomes, a colluding bloc of top experts, loyalty), expertise-weighted liquid democracy with capped audited delegation decides 97.4% right against 88.5% for one person one vote with no delegation (8 seeds, z ≈ 9); at moderate severity +3.5 points; in easy worlds no difference. Toy assumptions: binary decisions, the governance battery's population ([battery](../sim/battery/status_quo.jl)).
- **Historical decision replay (E4): provisional.** Options priced from as-of records; scored only on cases with a settled outcome, against simple rules on the same prices (status quo, fewest deaths, mean welfare, equal-weight scenarios). Pre-registered set: Benefuture 6/6 (interval 0.60–1.00), tied with fewest deaths; the cases do not separate it from simple rules. Held-out set, built without running the replay and replayed once under frozen code: 3/5 (0.23–0.89), the misses being the printing press and the 1973 lead phase-down, where the strong per-being reading let a small group's uncompensated loss veto a reform ([8.99](BACKPROPAGATION.md)). With compensated reforms priced (author ruling [8.100](BACKPROPAGATION.md), added after that replay, so not out of sample): 4/5; the lead case turns on whether an understanding gain may offset a happiness cost for the same person (open). With the author's rulings on understanding offsetting happiness over the long term and on environmental health harm (8.116, 8.118; third replay, not out of sample): held-out 5/5. A sensitivity readout (8.113) halves and doubles each judged magnitude alone: 8 of the 11 settled cases are robust (all right) and 3 are contested (Bengal relief, lead, Volcker), so those are not counted as wins. Limits: small samples, judged magnitudes, builders knew the outcomes, sources not yet verified from primary texts ([`docs/REPLAY_PREREG.md`](REPLAY_PREREG.md) §4.4–4.5, §5b).
- **Status-quo comparison: specified, not built.** The baseline institution is one person, one vote with uncapped delegation, calibrated to realistic boom–bust and regulatory capture ([8.92](BACKPROPAGATION.md)); comparisons in this README are against Benefuture's own arms until it is built.
- **Run length and population size** ([convergence](../sim/battery/results/convergence.md)). Results depend on population in ways the small test worlds hide. The q-floor in M1 shrinks from 15.3 at 20 beings to 6.3 at 1,000 (a floor over two beings flatters), so floor claims state their population. M3c economies of 20 beings and 4 agents spread 29% between seeds; from 40 beings and 6 agents, 3.5% or less. With plans scaled to population, M3c floor gain rises faster than population (104 at 80 beings, 251 at 240), and M7 understanding gain rises steeply at fixed per-being effort (6 at 20 beings, 27 at 500): candidate scale effects of shared understanding, under replication at z = 3 before they count.
- **Expertise weighting at scale: open.** Weighting votes by domain record beats equal weight (+0.06 at 60 voters), but the current sweep copies one skill distribution per voter, so equal weight reaches certainty at 240 voters and the gain shrinks. By author clarification 8.90 specialists stay sparse in narrow subdomains as populations grow; the sweep is being rebuilt that way, with the hypothesis, stated before measuring, that the gain grows with population.
- **Century and long-horizon battery.** Composed multi-decade and century simulations ([long_horizon](../sim/battery/long_horizon.jl), launcher `tools/battery/overnight.sh`) test convergence over 5,000–20,000 steps with rare catastrophes and breakthroughs, validating stability beyond short test horizons.

Not yet demonstrated: the `Conj_*` conjectures over a `SimTrace`, forks and graded personhood, and
networks and propagation (M8) ([SIM_CONJECTURES](SIM_CONJECTURES.md), [PLAN](PLAN.md)).

---

##  Epistemic scope: what is proved, what is simulated, what is open

**(a) Deductive guarantees (Lean 4).** The 399 theorems in [`Benefuture/`](Benefuture) and the 12
bridge theorems in [`BenefutureTest/`](../BenefutureTest) hold for the definitions as written. Designs
tagged [P] live in `Benefuture/Proposed/`. Behavioural claims are stated as `Conj_*` in
[Benefuture/Systems/Conjectures.lean](../Benefuture/Systems/Conjectures.lean) and are unproved. No
theorem shows the definitions describe people, and no proof links the Float reference to ℝ.

**(b) Synthetic multi-agent dynamics (Julia, spec 8.85).** Agents, models and measurements are noisy
at empirically adapted levels, and adversaries search for the worst strategy. The results are
distributional claims under the stated toy assumptions, tested by the significance rule. Only
distributional claims are portable across platforms: floating point moves single seeds.

**(c) Open for field pilots.** Whether people take the advice, whether markers track welfare, whether
domain currencies hold value, and whether score-only adoption spreads voluntarily are empirical
questions. They belong to the phased, score-only pilots of the
[Implementation prototype](https://benefuture.miraheze.org/wiki/Implementation_prototype), running in
parallel with existing institutions and issuing no currency in Phase 1. The first planned contact with real data is not an attempt to fit history. For documented good and
bad decisions (pandemic interventions, monetary policy, the Challenger launch, the Montreal
Protocol), it asks what Benefuture would have chosen on the information then available, whether that
differs from what was chosen, and how the outcome would likely have differed. The counterfactuals are
estimated by competing methods with intervals. Cases are chosen by criteria written beforehand, so
that a sound decision with bad luck is not scored as an error. Forecasters' records, replayed on
rolling windows, supply the credences ([`docs/DATA.md` §16](DATA.md)). Real-world data plans are in
[`docs/DATA.md`](DATA.md); the model description follows ODD ([`docs/ODD.md`](ODD.md)).

Records that keep the layers honest with each other:

- [`docs/BACKPROPAGATION.md`](BACKPROPAGATION.md): findings and author rulings flowing back to
  the sources.
- [`docs/SPEC_DIVERGENCES.md`](SPEC_DIVERGENCES.md): where the Lean chooses between readings.
- [`docs/SIM_CONJECTURES.md`](SIM_CONJECTURES.md): behavioural claims in measurable form.
- [`docs/SOTA.md`](SOTA.md): state of the art per mechanism.

Status tags: `[R]` ratified, `[P]` proposed, `[OPEN]`, `[CONJ]`.

---
