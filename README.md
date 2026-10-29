# Benefuture

A thought experiment in civilizational design, written as wiki articles and pseudocode, partly
formalised in Lean 4 and partly simulated in Julia. This repository holds all four and states what
each establishes.

[![Lean Action CI](https://github.com/nesquarx/Benefuture/actions/workflows/lean_action_ci.yml/badge.svg)](https://github.com/nesquarx/Benefuture/actions/workflows/lean_action_ci.yml)
[![Julia Sim CI](https://github.com/nesquarx/Benefuture/actions/workflows/julia_sim_ci.yml/badge.svg)](https://github.com/nesquarx/Benefuture/actions/workflows/julia_sim_ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-v4.29.0-blue.svg)](https://leanprover.github.io/)
[![License: LGPL v2.1](https://img.shields.io/badge/License-LGPL_v2.1-green.svg)](LICENSE)

---

## What Benefuture attempts

Benefuture is a consequentialist philosophy of civilization by Nesquarx. It claims no natural or
preordained purpose; it chooses one: raise universal understanding, then happiness, with extra
weight where the two reinforce each other, while weighing harm and keeping diversity
([Benefuture](docs/articles/Benefuture.txt), [Benefuture goals](docs/articles/Benefuture%20goals.txt)).
Understanding (accurate, parsimonious prediction and explanation) is ranked over happiness by a
larger weight, not lexically ([Philosophy](docs/articles/Philosophy.txt)); the reasons offered are
that understanding compounds, is shared without being lost to the one who shares it, and is
measurable by prediction ([Introduction](docs/articles/Introduction.txt)). That ranking is a
premise, not a derivation, and the corpus answers its critics on that footing
([Critique addressal](docs/articles/Critique%20addressal.txt)).

By the author's own description it is not a solution to the problems of civilization but "a rough
process outline of how we might discover those problems, find the solutions, implement them, and
keep improving on the process", with gaps to be filled from reality
([Benefuture, Critical Evaluation](docs/articles/Benefuture.txt)). It is not a post-scarcity
framework: it is a framework to discover and diminish scarcities
([BACKPROPAGATION 8.27](docs/BACKPROPAGATION.md)).

The mechanisms proposed to that end, each with its own article:

- **Measurement.** Competing metric models predict outcomes and are scored against established
  empirical markers; none is protected, and a dominated one is retired
  ([Measurement](docs/articles/Measurement.txt)).
- **Domains.** Value, currency and reputation are kept per domain, so success in one cannot buy
  standing in another ([Domain](docs/articles/Domain.txt)).
- **Currency.** Each domain's currency is backed by a qualified metric model; work is paid partly
  on prediction and partly on measured outcome, held in escrow against uncertainty, and credited to
  contributors by causal distribution; currencies are not traded against one another
  ([Benefuture currency](docs/articles/Benefuture%20currency.txt)).
- **Governance.** Direct democracy weighted by domain expertise and by impact, with capped,
  audited, retractable delegation ([Government](docs/articles/Government.txt)); laws refined by
  measured outcomes, justice by reparation first ([Law](docs/articles/Law.txt),
  [Justice](docs/articles/Justice.txt)).
- **Self-correction.** Finding a flaw pays more than exploiting it
  ([Adversarial adaptation](docs/articles/Adversarial%20adaptation.txt)); systems degrade to
  simpler fallbacks rather than failing ([Progressive complexity](docs/articles/Progressive%20complexity.txt));
  and the diversity axiom applies to Benefuture itself, which yields to a better goal structure if
  one is found and shown.
- **Rollout.** A score-only first phase, in parallel with existing systems, before any currency
  ([Implementation prototype](docs/articles/Implementation%20prototype.txt)).

The epistemic stance the rest follows from:

- **Outputs only.** Beliefs and preferences are not directly accessible, so definitions,
  enforcement and alignment are stated over outputs; only empirical test confers public authority
  ([Philosophy, Positioning in One Line](docs/articles/Philosophy.txt)).
- **Truth comes in levels and never reaches 1** ([Truth](docs/articles/Truth.txt)). This applies
  to the work here too (author ruling, [BACKPROPAGATION 8.33](docs/BACKPROPAGATION.md)): every claim
  below carries its confidence, hypotheses and assumptions.
- **Correctable, not correct.** The bootstrap is not guaranteed to be right, only to be correctable
  ([Critique addressal](docs/articles/Critique%20addressal.txt)). Reality as it is, not an ideal,
  is the benchmark. Critiques of internal coherence stand on their own and are welcome.

The author's one-line positioning: *Walzer's spheres, operated by Hanson's markets of Lakatos'
programmes under Strevens' iron rule, toward Deutsch's understanding, even over Bentham's
happiness* ([Philosophy](docs/articles/Philosophy.txt)).

## What exists, and what it shows

Nothing here shows that Benefuture would work in the world. No deployment exists. What exists:

| Layer | Where | What it establishes |
|---|---|---|
| Articles | [`docs/articles/`](docs/articles) | The framework in prose: MediaWiki source of the [Benefuture wiki](https://benefuture.miraheze.org), synced by `tools/wiki_sync/`. Most articles end with a note of how much of them is AI-written. |
| Pseudocode | [`spec/Bf_Pseudocode.txt`](spec/Bf_Pseudocode.txt) | The framework as compact symbolic definitions (not machine-checked), cited by line (L74 is Goal G). Copies, kept identical: [`Bf_Pseudocode.txt`](Bf_Pseudocode.txt) and the block embedded in [Benefuture](docs/articles/Benefuture.txt). |
| Lean specification | [`Benefuture/`](Benefuture) | Type-checked definitions over ℝ (Mathlib), with theorems about them. A proof holds for the definitions as written under the hypotheses listed; it says nothing about whether they describe the world. Proposed designs live in `Benefuture/Proposed/` (status [P]); behavioural claims are stated, unproved, as `Conj_*` in `Benefuture/Systems/Conjectures.lean`. |
| Lean reference | [`BenefutureReference/`](BenefutureReference) | Mathlib-free Float versions of the rules, exported to C. Generates the test vectors in [`spec/vectors/`](spec/vectors). Its correspondence to the ℝ specification is not proved. |
| Simulation | [`sim/`](sim) ([`sim/README.md`](sim/README.md)) | A Julia agent-based model in toy worlds that calls the Lean reference for every rule. Shows behaviour under stated toy assumptions, a few seeds at a time; not proof, not significance-tested. |

Records that keep the layers honest with each other:

- [`docs/BACKPROPAGATION.md`](docs/BACKPROPAGATION.md): what formalisation and simulation found that
  the sources miss, with proposed edits, and the author's rulings on them.
- [`docs/SPEC_DIVERGENCES.md`](docs/SPEC_DIVERGENCES.md): every place the Lean chooses between
  readings of, or departs from, the pseudocode and articles.
- [`docs/SIM_CONJECTURES.md`](docs/SIM_CONJECTURES.md): behavioural claims in the sources, in
  measurable form, with what Lean already settles.
- [`docs/THEOREM_INDEX.md`](docs/THEOREM_INDEX.md): every theorem with its docstring (generated;
  docstrings unreviewed, so some overstate; the reviewed claims are below).
- [`docs/PLAN.md`](docs/PLAN.md): direction and history; [`docs/CODING_STYLE.md`](docs/CODING_STYLE.md)
  and [`CLAUDE.md`](CLAUDE.md): method.

Status tags across the corpus: `[R]` ratified by the author, `[P]` proposed, `[OPEN]` unresolved,
`[CONJ]` simulation conjecture. Where to start reading: [Introduction](docs/articles/Introduction.txt),
then the reading order in [Benefuture](docs/articles/Benefuture.txt);
[Critique addressal](docs/articles/Critique%20addressal.txt) for the objections.

---

## Claims

What this repository establishes, in plain words, with links to the proof or the code and its
results. Three kinds of evidence, never to be read as more than they are:

- **Proved** (Lean 4 with Mathlib, over ℝ unless noted; checked by CI, no `sorry`, `admit`, custom
  axioms or `native_decide`). True of the definitions as written, under the hypotheses listed;
  silent on whether the definitions describe the world.
- **By construction**: the theorem confirms that a rule is encoded as intended (the property is a
  structure field or follows directly from a definition). These check the encoding; they are not
  discoveries.
- **Demonstrated in simulation**: observed in `sim/` under the stated toy assumptions, as tests that
  pass on every CI run or as readings averaged over a few seeds. Not proofs, and not
  significance-tested.

The simulation does not run the ℝ specification: it calls the Float reference (`BenefutureReference`)
through C exports. The reference reproduces the spec's test vectors, but correspondence between the
two is not proved. `python3 tools/check_readme_claims.py` checks that every theorem named here exists
in the file linked.

### Proved

Synergy and value
- Net synergy rises strictly with the gain potential when the cross-term weight λ is in [0, 1],
  and falls strictly with the loss potential for λ ≥ 0 ([`net_synergy_raw_strict_mono_plus`](Benefuture/Math/Synergy.lean),
  [`net_synergy_raw_strict_anti_minus`](Benefuture/Math/Synergy.lean)). Equal gains and losses net strictly negative for λ > 0
  ([`equal_gains_and_losses_are_negative`](Benefuture/Math/Synergy.lean)).
- The squashed synergy Ŝy is odd and lies strictly in (−1, 1) for h > 0 ([`squashed_synergy_odd`](Benefuture/Math/Synergy.lean),
  [`squashed_synergy_bounds`](Benefuture/Math/Synergy.lean)); with ν = 1 it is strictly increasing
  ([`squashed_synergy_strictly_monotone_nu_one`](Benefuture/Math/Synergy.lean)).
- Loss aversion (losses weigh more than gains of equal size, q₋ > q₊) holds for magnitudes above 1
  and **fails** below 1 ([`loss_aversion_holds_above_one`](Benefuture/Math/Synergy.lean), [`loss_aversion_fails_below_one`](Benefuture/Math/Synergy.lean));
  normalising by the context threshold restores it for every significant input
  ([`significant_assessment_preserves_loss_aversion`](Benefuture/Math/Synergy.lean)), at every admissible parameter point
  ([`admissible_loss_aversion`](Benefuture/Systems/ParamSpace.lean)).
- With harm-tier exponent 1.5, doubling a harm more than doubles its weight
  ([`harm_tier_superlinear`](Benefuture/Axiology/Priorities.lean)). Whether harm tiers trade at a finite rate is open: under a weighted
  reading enough passing harms outweigh one irreparable harm ([`finite_exchange_rate_weighted`](Benefuture/Math/Synergy.lean));
  under a lexical reading none do ([`no_finite_exchange_rate_lexical`](Benefuture/Math/Synergy.lean)).
- Sy never reverses Pareto dominance, for positive weights and exponents, κ ≥ 0 and λ in [0, 1]
  ([`sy_score_pareto_monotone`](Benefuture/Proposed/PopulationDirection.lean)).
- Harm reference points: understanding below any earlier level is harm ([`forgetting_is_harm`](Benefuture/Axiology/Priorities.lean));
  happiness at or above its rolling average is not ([`h_at_or_above_average_no_harm`](Benefuture/Axiology/Priorities.lean),
  [`coming_down_not_harm`](Benefuture/Axiology/Priorities.lean)). The happiness kind tiers sum exactly to the bias-corrected happiness
  score ([`kind_tiers_partition_happiness`](Benefuture/Axiology/Priorities.lean)).

Goal G and distribution (`Benefuture.Proposed.PopulationDirection`, status [P])
- Inaction is always admissible, so some plan is always chosen
  ([`inaction_admissible`](Benefuture/Proposed/PopulationDirection.lean), [`goal_G_some`](Benefuture/Proposed/PopulationDirection.lean)). The chosen plan never contracts reality, never lowers the
  maximum or minimum understanding or the minimum happiness against not acting, and maximises the
  objective over admissible plans ([`goal_G_sound`](Benefuture/Proposed/PopulationDirection.lean)).
- G never chooses a plan that another admissible plan dominates (no worse for any being present at
  decision time, better for one, no worse in distribution), under positive weights and exponents,
  κ ≥ 0, λ in [0, 1] ([`dominated_plan_not_chosen`](Benefuture/Proposed/PopulationDirection.lean)); likewise at every admissible parameter point
  ([`admissible_dominated_plan_not_chosen`](Benefuture/Proposed/PopulationDirection.lean)). Uplift with no losers beats inaction
  ([`uplift_beats_inaction`](Benefuture/Proposed/PopulationDirection.lean)).
- The floor is taken over the decision-time population: removing a being cannot raise it, for the
  literal minimum ([`removal_cannot_raise_floor`](Benefuture/Proposed/PopulationDirection.lean)) and for G's floor as a
  thresholded low quantile, the (k+1)-th smallest level ([`removal_cannot_raise_quantile_floor`](Benefuture/Proposed/PopulationDirection.lean));
  over survivors only it would rise, in both forms ([`survivor_floor_rises_on_removal`](Benefuture/Proposed/PopulationDirection.lean),
  [`survivor_quantile_floor_rises_on_removal`](Benefuture/Proposed/PopulationDirection.lean)).
- The distribution term D ignores the order of beings ([`level_gain_perm`](Benefuture/Proposed/PopulationDirection.lean)) and beings absent at
  decision time ([`dist_score_ignores_absent`](Benefuture/Proposed/PopulationDirection.lean)); for monotone shapes, levelling down never helps and
  uplift never hurts ([`levelling_down_never_helps`](Benefuture/Proposed/PopulationDirection.lean), [`uplift_gain_nonneg`](Benefuture/Proposed/PopulationDirection.lean)). For every concave shape,
  moving happiness from a better-off to a worse-off being without reversing their order never lowers
  D, nor does any sequence of such moves ([`pigou_dalton_h`](Benefuture/Proposed/PopulationDirection.lean), [`pd_run_raises`](Benefuture/Proposed/PopulationDirection.lean)). Sharing
  understanding (the learner rises, the teacher keeps their level) never lowers D
  ([`u_sharing_gain_nonneg`](Benefuture/Proposed/PopulationDirection.lean)).
- Population: any number of net-negative tallies never outweighs a non-empty set of positive ones
  ([`net_negative_never_outweighs_positive`](Benefuture/Proposed/PopulationDirection.lean)); copies of one type add at most one type
  ([`copies_add_no_diversity`](Benefuture/Proposed/PopulationDirection.lean)); summed novelty equals the number of distinct types
  ([`population_novelty_eq_effective_types`](Benefuture/Proposed/PopulationDirection.lean)) and, with history, never exceeds it
  ([`population_novelty_hist_le`](Benefuture/Proposed/PopulationDirection.lean)).
- Checking ↑min step by step is stricter than over a trajectory: a temporary dip that closes is
  admissible over the trajectory but not stepwise ([`tunnel_admissible_but_not_stepwise`](Benefuture/Proposed/PopulationDirection.lean)); a dip still
  open at the horizon has triggered harm intervention at some step ([`nonclosing_tunnel_triggers_harm_intv`](Benefuture/Proposed/PopulationDirection.lean)).

Economy, reputation and domains
- A closed cycle of transactions with zero predicted value loses exactly its resource cost
  ([`closed_cycle_arbitrage_negative`](Benefuture/Economy/Currency.lean)); an action no model can value pays its full resource cost
  ([`unmodelled_action_pays_resource_cost`](Benefuture/Economy/Pricing.lean)); confident predicted value above cost makes the price
  negative ([`price_negative_when_value_exceeds_cost`](Benefuture/Economy/Pricing.lean)).
- At a parent domain, aggregated value never exceeds the value an action carried
  ([`aggregate_no_double_count`](Benefuture/Ontology/Domain.lean)), and parents with larger degrees aggregate more
  ([`aggregate_monotonicity`](Benefuture/Ontology/Domain.lean)).
- Reputation summed over leaf domains equals the attributed contribution, when every action's
  shares sum to 1 ([`conservation_positive`](Benefuture/Ontology/Reputation.lean), [`conservation_negative`](Benefuture/Ontology/Reputation.lean)); a domain outside an action's
  profile is untouched ([`reputation_locality`](Benefuture/Ontology/Reputation.lean)); zero causal contribution earns nothing
  ([`reputation_no_transfer`](Benefuture/Ontology/Reputation.lean)); history never decreases as memory grows ([`hPos_nondecreasing_on_append`](Benefuture/Ontology/Reputation.lean)).
- Lazily decayed reputation is exact: decay distributes over sums, chains across checkpoints, and
  checkpointing changes no later reading ([`cache_correct`](Benefuture/Systems/State.lean), [`decay_transitive`](Benefuture/Systems/State.lean), [`checkpoint_sound`](Benefuture/Systems/State.lean)).
- The Int fixed-point versions of escrow, assessment normalisation and novelty are within one
  micro-unit of their real values ([`escrow_fixed_point`](Benefuture/Systems/FixedPoint.lean), [`norm_assessment_fixed_point`](Benefuture/Systems/FixedPoint.lean),
  [`novelty_fixed_point`](Benefuture/Systems/FixedPoint.lean)).
- Fuzzy subsethood lies in [0, 1], equals 1 for a domain and itself, and ignores renaming
  ([`fuzzy_subsethood_in_unit_interval`](Benefuture/Proposed/DomainHierarchy.lean), [`fuzzy_subsethood_self`](Benefuture/Proposed/DomainHierarchy.lean), [`fuzzy_subsethood_rename_invariant`](Benefuture/Proposed/DomainHierarchy.lean));
  a hierarchy fixed point exists **if** the update operator is monotone, which is assumed, not
  shown ([`hierarchy_fixed_point_exists`](Benefuture/Proposed/DomainHierarchy.lean)).

Causal distribution (`Benefuture.Proposed.OutcomeDistribution`, status [P])
- A duty left undone is assessed negative: against the action a contract or communicated law
  committed the actor to, an outcome worse than the committed one assesses below zero
  ([`breached_duty_assessed_negative`](Benefuture/Proposed/OutcomeDistribution.lean)); without a committed action, not acting assesses at
  zero ([`inaction_without_duty_assessed_zero`](Benefuture/Proposed/OutcomeDistribution.lean)).
- A contributor whose presence changes no coalition's assessed outcome receives no Shapley share
  ([`shapley_null`](Benefuture/Proposed/OutcomeDistribution.lean)). That the shares sum to the outcome (efficiency) is not proved; it is
  checked numerically on random games ([sim/test/shapley_tests.jl](sim/test/shapley_tests.jl)).
- Paying positive shares and penalising negative ones distributes exactly the sum of the shares
  ([`sides_sum`](Benefuture/Proposed/OutcomeDistribution.lean)), and each paid contributor's share of its side lies in [0, 1]
  ([`paid_share_in_unit`](Benefuture/Proposed/OutcomeDistribution.lean)).
- Informed inaction against a committed action is a crime (L115); inaction without one is not,
  informed or not; an uninformed breach is an accident
  ([`informed_inaction_under_duty_is_crime`](Benefuture/Subgoals/Justice.lean), [`inaction_without_duty_is_not_crime`](Benefuture/Subgoals/Justice.lean),
  [`uninformed_breach_is_accident`](Benefuture/Subgoals/Justice.lean)).

Governance and incentives
- The Brier score is strictly proper: reporting one's belief uniquely minimises expected loss
  ([`brier_score_strictly_proper`](Benefuture/Governance/Incentives.lean)).
- With the delegation cap, no delegate ever exceeds the cap plus one delegator's maximum weight,
  however many delegate to it ([`accumulate_capped_bound`](Benefuture/Governance/Incentives.lean)).
- Planting flaws to farm bounties is unprofitable in expectation when the clawback covers bounty
  plus damage and detection is likelier than bounty ÷ clawback ([`bounty_incentive_compatible`](Benefuture/Governance/Incentives.lean)).
- External harm response: forgiveness and overreaction probabilities form a valid split
  ([`probabilities_sum_le_one`](Benefuture/Governance/ExternalHarm.lean)); the expected response lies between 0 and (1 + margin) × harm
  ([`ehr_response_bounds`](Benefuture/Governance/ExternalHarm.lean)); more positive reputation never raises it
  ([`more_positive_reputation_lowers_response`](Benefuture/Governance/ExternalHarm.lean)); with equal ledgers and δ < α, forgiveness is
  strictly likelier than overreaction ([`forgiveness_bias`](Benefuture/Governance/ExternalHarm.lean)), at every admissible point
  ([`admissible_forgiveness_bias`](Benefuture/Systems/ParamSpace.lean)).
- Every parameter vector reachable from the bootstrap point by governance steps is admissible
  ([`governed_params_admissible`](Benefuture/Systems/ParamSpace.lean)); n evolutionary perturbations move a parameter by at most n·δ
  ([`perturb_run_drift`](Benefuture/Systems/ParamSpace.lean)).
- The modelled state transitions (`Step`) keep memory append-only, identities injective and
  escrow sound ([`step_preserves_mem`](Benefuture/Systems/State.lean), [`step_preserves_id`](Benefuture/Systems/State.lean), [`step_preserves_escrow_soundness`](Benefuture/Systems/State.lean)).

### By construction

These confirm encoded rules: the priority order of understanding over happiness over novelty over
harm's base weight ([`understanding_dominates_happiness`](Benefuture/Math/Order.lean), a structure field); escrow conservation
([`escrow_conservation`](Benefuture/Economy/Currency.lean)); conservation under forks and merges ([`fork_conserves_per_domain_currency`](Benefuture/Ontology/Entity.lean),
[`merge_conserves_per_domain_currency`](Benefuture/Ontology/Entity.lean)); overflow conservation and its ceiling
([`balance_overflow_conservation_law`](Benefuture/Systems/Economy.lean), [`auto_spill_enforces_ceiling`](Benefuture/Systems/State.lean)); Phase 1 issues no currency
proposals ([`phase1_score_only_forbids_currency_proposals`](Benefuture/Systems/TechnologyNetwork.lean)); a currency needs a qualified model
([`currency_requires_qualified_model`](Benefuture/Economy/Currency.lean)); crime needs information and volition, otherwise accident
([`crime_and_accident_mutually_exclusive`](Benefuture/Subgoals/Justice.lean)); the freedom rules block irreversible, irreparable and
established severe harm ([`irreversible_harm_strictly_impermissible`](Benefuture/Subgoals/Freedom.lean), [`established_severe_blocks`](Benefuture/Subgoals/Freedom.lean));
anti-halo isolation: no relevance in a decision's domains, no expert weight
([`anti_halo_domain_isolation`](Benefuture/Governance/Democracy.lean)); domain-relative expertise (L113, ruling 8.22.1) sums to one across a
domain's voters and gives no voter more than the expertise weight, however large its raw reputation
([`relative_expertise_sum_one`](Benefuture/Governance/Democracy.lean), [`relative_expertise_le_one`](Benefuture/Governance/Democracy.lean)); harm to a coupled part of the extended self is positive harm to
the being ([`defection_harms_extended_self`](Benefuture/Subgoals/Morality.lean): damage × positive coupling); completing the required
education zeroes an infohazard's modelled risk ([`education_inoculates_infohazard`](Benefuture/Epistemology/InfoHandling.lean)); reporting an
exploit pays more than exploiting it, because the bounty is defined above the gain
([`revelation_strictly_dominates`](Benefuture/Governance/Adversarial.lean)); the antifragility and continuity triggers fire on their
defining conditions ([`harm_growth_activates_intervention`](Benefuture/Axioms/Antifragility.lean), [`rising_harm_mandates_intervention`](Benefuture/Subgoals/Continuity.lean));
metric models are non-circular given the empirical-marker requirement
([`metric_models_are_non_circular`](Benefuture/Measurement/MetricModel.lean)).

In the simulation, rules are defined once by construction: every simulated rule is a Lean reference
function called through C exports, and the shared library rebuilds only when the Lean sources change
([sim/src/lean.jl](sim/src/lean.jl)).

### Negative and open results

- A positive floor moves the repugnant conclusion rather than resolving it: under additive
  aggregation, enough beings at any positive floor exceed any finite total
  ([`floor_shifts_repugnant_conclusion`](Benefuture/Axiology/RepugnantConclusion.lean)). The [P] distribution design answers with the
  decision-time population and diversity bounds above, not with the floor.
- Loss aversion fails for sub-unit magnitudes without normalisation ([`loss_aversion_fails_below_one`](Benefuture/Math/Synergy.lean)).
- Skew direction alone admits plans that lower the minimum ([`skew_direction_alone_permits_min_decline`](Benefuture/Proposed/PopulationDirection.lean)).
- Freedom excludes irreversible harm even when it is necessary harm with positive net gain
  ([`freedom_excludes_irreversible_necessary_harm`](Benefuture/Subgoals/Freedom.lean)); the tension is open.
- Without a delegation cap, a star topology hands one node all the weight
  ([`star_topology_power_concentration`](Benefuture/Governance/Incentives.lean)).
- Causal contribution as specified (clamped value added, L93's range [0, 1]) over-distributes along
  a chain with a loss: links adding 10 and 5 followed by one destroying 10 receive 15 for an outcome
  of 5, and the loss is distributed to no one ([`cc_clamped_overdistributes`](Benefuture/Systems/Substrate.lean)).
  Resolved by the author's ruling: credit follows an outcome's assessed parts (BACKPROPAGATION 8.14).
- Harm through inaction under a duty is simulated with hazards and guardians (M3e); whether "not
  braking" is inaction or part of driving, and duty from hazards of one's own making, follow the
  author's rulings (BACKPROPAGATION 8.15, 8.17).

### Demonstrated in simulation

Every claim below is a toy-world reading, never certain (author ruling 8.33). Readings for the
transaction, hazard, governance and threshold rungs were taken before the rulings that mistakes
decay slower than wins, that models use track records (8.29) and that world defaults are mildly
imperfect (8.33); their tests still pass under those rulings, but the numbers quoted have not been
re-run unless the claim says so. Failure-boundary batteries (`sim/battery/results/`) run continuously
on the latest build.

Toy assumptions common to all, still to be removed (`sim/README.md`, model ladder): beings and
plans in a small abstract world (80–200 beings; a plan's effect is Gaussian around its proposer's
skill); causal signatures as points near unit axes; model and measurement error as Gaussian noise
of fixed size; G chooses one plan a step from a menu of proposals, or screens transactions (M3d);
fixed agents and skills; one measured value per plan, with every loss counted as passing harm.
Readings are means over 5 seeds of 500 steps unless a claim says otherwise. Which Lean modules the
simulation covers, and which not yet: [sim/README.md, coverage](sim/README.md#coverage-of-the-specification).

Measurement, agents and domains
- With perfect measurement, the floors of understanding and happiness never fall, and the peak of
  understanding never falls ([sim/test/m0_tests.jl](sim/test/m0_tests.jl)). With noise, the floors'
  guarantee is only as good as measurement: noise on current levels alone lets the true floor fall
  in 9% of steps, and heavy prediction noise freezes G (G acts in 7% of steps)
  ([sim/README.md, M1](sim/README.md#m1-observations)).
- Metric model competition settles on the most accurate model, and a precise but biased model
  loses to an unbiased one of equal noise ([sim/test/m1_tests.jl](sim/test/m1_tests.jl)).
- Reputation tracks agents' skill (Spearman 0.98) when they are careful; with heavy execution noise
  it tracks carefulness instead (0.64), since convex harm makes noise cost more than it gives
  ([sim/README.md, M2](sim/README.md#m2-observations)).
- Payments and reputation are conserved across domains and never leak into domains outside an
  action's profile ([sim/test/m3_tests.jl](sim/test/m3_tests.jl)). Profiles declared by actors
  cannot identify per-domain skill (Spearman 0.39); profiles measured from causal signatures can
  (0.71) ([sim/README.md, M3b](sim/README.md#m3b-observations)).
- On the domain network: domains missing from the bootstrap classification form from clustered
  blocked work within about 20 steps, with no spurious domain in 5 seeds, also under heavy noise;
  overlap degrees unknown to the bootstrap are learnt, slowly by design; a rarely used domain keeps
  its place; work no qualified currency can value is screened by G on the best available model (a
  harmful agent's passes in 2 of 2,000 plans, both measured beneficial) and halts when unfunded;
  the books balance under every noise source at once ([sim/test/m3c_tests.jl](sim/test/m3c_tests.jl),
  [sim/README.md, M3c](sim/README.md#m3c-observations)).
- Balance overflow trades reinvestment against concentration: raising the threshold moves the
  share reinvested from 84% to 11% while the Gini of balances rises from 0.18 to 0.53
  ([sim/README.md, M3c](sim/README.md#m3c-observations)).
- Better models over time (author guidance 8.42.2; an assumption stated, not derived: new models
  keep arriving in each domain, better on average, never perfect): every model is scored on the open
  log and a challenger takes over a domain's currency when its credences beat the incumbent's by the
  significance rule; better models take over the domain's own pricing from coarser fallbacks (leaf
  priced by its own currency 100% against 70%), a captured model is overtaken (73% of its work
  still priced by the domain's own currency against none), and floors grow about as much (toy world,
  1–3 seeds) ([sim/test/models_tests.jl](sim/test/models_tests.jl), [sim/README.md, better models](sim/README.md#better-models-over-time-8422)).

Transactions and causal distribution
- Transactions instead of a single choice by G: about four actions a step instead of one, roughly
  three times the floor growth, and more mediocre and harmful work admitted (9% of executed actions
  measured harmful, against 2%; 27% under model bias); with exact models, screening each step's
  transactions together keeps every floor from falling ([sim/test/m3d_tests.jl](sim/test/m3d_tests.jl),
  [sim/README.md, M3d](sim/README.md#m3d-observations)).
- Outcome-first causal distribution: contributors share each outcome Shapley-style, with the
  traversal fallback when the causal assessment is not confident; intermediaries who add nothing
  to what they pass on earn almost nothing while the makers upstream are paid; a bad output is
  penalised through the losses it carries downstream; co-funders whose money was needed are
  credited; every outcome is fully distributed and the books balance. Coalition values follow
  BACKPROPAGATION 8.18, a decision open to the author ([sim/test/m3d_tests.jl](sim/test/m3d_tests.jl),
  [sim/README.md, M3d](sim/README.md#m3d-observations)).
- Contribution types (author ruling 8.22): carrying another's output outside contract earns an
  accolade, under contract the contracted share, both out of the maker's positive share and never
  out of a loss (the fee's basis is a proposal, [P]). A prevention is the guardian's ordinary
  recorded action: its measured outputs mint or destroy currency, and what it earns does not depend
  on the size of the harm averted; the books still balance ([sim/test/m3d_tests.jl](sim/test/m3d_tests.jl),
  [sim/test/m3e_tests.jl](sim/test/m3e_tests.jl), [sim/README.md, contribution types](sim/README.md#contribution-types-and-preventions-822-824)).

Hazards and black swans
- A world that moves on its own: unguarded hazards cut floor growth by a sixth and double the
  steps the floor falls; guardians bound by contract recover most of it; what they miss for lack of
  notice is accident, negligence is crime, and penalties fund repair either way. Harm with no
  contributor is repaired through the commons, the repair priced as any transaction (resource cost
  less predicted good), so it largely pays for itself and the commons covers only the rest, never
  beyond what it holds and banking no surplus. How resource accounting funds the commons is open;
  the simulation's commons holds the resource costs paid
  ([sim/test/m3e_tests.jl](sim/test/m3e_tests.jl), [sim/README.md, M3e](sim/README.md#m3e-observations)).
- Black swans, each with a native fallback (toy world, five seeds). Through a measurement outage
  work continues, paid by prediction and logged unmeasured, then re-measured (with extra noise,
  through the same confidence gate) and settled when markers return, so an outage that ends hides
  nothing; floor growth holds. A catastrophe takes 30–40 steps to recover from alone and one step
  when repaired through the commons. A captured metric model loses eligibility while captured and
  its parent prices its work, then it requalifies. A breakthrough raises floor growth by a third.
  Sabotaged outages are penalised when examination traces them (a world chance), else insured; harm
  passed off as unassigned pays only when practically untraceable (a tracing rate of 0.1 already
  makes it a loss); identity forks capture votes only if each fork gets its own base vote, and by
  the author's ruling for now, forks divide it. Not yet tested: rogue agents and the
  diversity–novelty balance ([sim/test/m3f_tests.jl](sim/test/m3f_tests.jl),
  [sim/README.md, black swans](sim/README.md#black-swans-8224-823)).

Gaming (M6, toy world, 3–6 seeds)
- An agent whose plans fool every metric model gains nothing relative to its peers once each model
  prices each actor by its record on it (8.29) and escrow settles on measured outcomes. Its harm
  falls on the domain: a model with no record of it is fooled in full, so in a marginal domain
  (accuracy near its status bar) it can keep the domain from ever qualifying (2 seeds of 6), and
  without track records it takes the domain's currency down in every seed (BACKPROPAGATION 8.37).
- Adversarial adaptation (AdvAp, L160; author ruling 8.38) uncovers and repairs it: agents reading
  the open log report an actor whose estimates run significantly above other actors' on the same
  models; an audit tests and examines the report; an established deception's falsified records are
  re-scored, and the reporter's reward and the audit are charged to the deceiver. Repair restores a
  blocked marginal domain (one seed: no actions to 772; another stays blocked, too little work for a
  report) and a third or more of peers' work without track records; honest worlds draw almost no
  reports, and a frivolous reporter pays for its audits. Over 24 seeds of a marginal domain, AdvAp
  cuts blocked domains from 9 to 3, and readers' attention drawn by a negative pattern in the open
  ledgers triples the deceptions uncovered (8.42).
- Colluding voters (toy decision world; outcomes apparent 70% of the time; readings before the
  scoring correction of 8.38's status): a bloc of the most reputable fifth of experts lowers
  decision accuracy only from 97% to 93%; delegation amplifies a larger bloc's capture (30% of
  experts: 66% with delegation, 86% without) until votes earn or cost reputation and delegations are
  audited (L114), when the bloc's expertise share collapses and accuracy returns to 96%.
- A bloc that defects only where outcomes stay hidden escapes this (79% correct on hidden decisions
  in the current build). Keeping the option not chosen available to locales by a novelty bonus
  (diversity, L158) corrects part of the damage (89%); AdvAp's manufactured prisoner's dilemma (a
  member revealing the bloc for a reward above its share of the bloc's gain, the bloc's falsified
  votes struck and the hidden decisions recounted) restores them to 99.7% while the bloc's expertise
  share falls from 0.74 to 0.15 (4 seeds; each member weighs revealing with chance 0.05 after a
  hidden defection) ([sim/test/m6_tests.jl](sim/test/m6_tests.jl), [sim/README.md, M6](sim/README.md#m6-observations)).

Governance and thresholds
- Expertise-weighted votes decide better than one agent, one vote (98.5% against 94.8% in a toy
  where skill sharpens judgement), but raw reputation concentrates a third of the weight in one
  voter; domain-relative expertise (the default, by the author's ruling) keeps nearly all the
  accuracy with far less concentration, from a household of eight to a polity of a hundred; the
  delegation cap holds (no delegate exceeds the cap plus one delegator's weight)
  ([sim/test/m5_tests.jl](sim/test/m5_tests.jl), [sim/README.md, M5](sim/README.md#m5-observations)).
- Convergence under heavy friction (8.31; toy decision world, 16 seeds): voters with noisy choices
  (per-person ceilings, inverse to expertise only on average), outcomes apparent 40% of the time,
  starting from inverted reputations, converge within a few hundred decisions to the accuracy that
  true reputations give; the effect is small (expertise is worth about two points there). In the
  economy, with accuracy as the quality of models' credences and thresholds as currency status
  (author rulings 8.35–8.36), every noise source at the top of its realistic range at once thins
  pricing but floors still rise (about 9% of clean growth, 14% before the scoring correction of
  8.38's status); far beyond a functional domain, no currency qualifies and work goes to StandCoin.
  Under status thresholds a deceiver can degrade a domain's currency status for everyone (8.37),
  which AdvAp largely restores (8.38; Gaming above)
  ([sim/test/m5_tests.jl](sim/test/m5_tests.jl), [sim/README.md, friction](sim/README.md#imperfect-agents-and-convergence-under-friction-831)).
- Clean deliberation in governance (toy decision world, 3 seeds): voters weighing contacts' and
  improving models' published readings by the rolling net of their records hand prediction to the
  models as they improve (their share of the weight rising to 0.7–0.95) and drop a captured model
  entirely. But shared sources make votes dependent, and decisions fall towards the sources' own
  accuracy (92.8% alone, 85–86% with models; BACKPROPAGATION 8.43). With understanding trickling
  down only (8.44) through the network's information handling, each layman's echo still recasts its
  source's information with a full base vote, a finding awaiting the author (8.45). Where experts are
  divided between two camps, one leaning by an honest bias, hearing both sides with diversity's
  trials finds the performant option on contested questions 86.7% of the time, against 80.7% with
  trials alone and 75.8% with neither
  ([sim/test/m5_tests.jl](sim/test/m5_tests.jl), [sim/README.md, deliberation](sim/README.md#clean-deliberation-and-better-models-in-governance-8422-843)).
- Governed value parameters stay admissible under SigThGv's perturbation, and within ±0.02 per
  epoch the outcomes do not depend on them. Adaptation as experimental design (author ruling 8.22)
  tries candidates in randomised blocks and shifts only on a significant gain; where the parameters
  make no difference it shifted once in eight rounds, against every round with a fixed order (floor
  movement trends over time). The freedom radius is gauged in the same rounds, shrinking on
  significant harm and widening otherwise; where nothing matters it widens across seeds until
  admissibility rejects the candidates ([sim/test/m4_tests.jl](sim/test/m4_tests.jl),
  [sim/README.md, M4](sim/README.md#m4-observations)).
- Deaths (M7, first rung; toy population of 50, 20 trials): G's floors over the decision-time
  population, the dead at the bottom, do not stop a plan that removes the two worst-off and lifts
  everyone else (the 10% quantile still rises; only the literal minimum would not); Freedom does,
  since a death is irreparable harm (Lean `fr_permissible_ref`), a finding for the corpus's account of
  sacrificial trade-offs (BACKPROPAGATION 8.47) ([sim/test/m7_tests.jl](sim/test/m7_tests.jl),
  [sim/README.md, M7](sim/README.md#m7-observations-deaths-first-rung)).
- The debatable escape (L157; author rulings 8.26.3, 8.38.2, 8.41): a proposal beyond the freedom
  range is tried on half the domains for a limited time and adopted only if it beats the incumbent
  by the significance rule, its gains exceed its harms and it caused no irreparable harm. The status
  bar relative to the alternative a domain has is adopted in 2 of 4 low-skill seeds and rejected as
  no better in capable domains; set world-wide it halves losses at skill 0.3 and cuts them tenfold
  at 0.15 (toy world, 3–4 seeds; irreparable harm is a world classification, none by default)
  ([sim/test/m4_tests.jl](sim/test/m4_tests.jl), [sim/README.md, debatable escape](sim/README.md#the-debatable-escape-8263-8382-841)).

What is not yet demonstrated at all: the `Conj_*` conjectures over a `SimTrace` (convergence,
gaming resistance, parameter stability in general), population change (M7), and networks and
propagation (M8); see [docs/SIM_CONJECTURES.md](docs/SIM_CONJECTURES.md) and
[docs/PLAN.md](docs/PLAN.md).

---

## Notation

The pseudocode's symbols, as used in the Lean and the simulation (articles spell them out):

| Symbol | Concept | Pseudocode |
| :--- | :--- | :--- |
| `𝕌` | Universe | ℝ ⊆ 𝕌 (L16) |
| `ℝ` | Reality | (Perceivable ∪ Changeable) ⊆ 𝕌 (L16) |
| `T`, `E`, `B`, `Pe`, `S` | Things, entities, beings, persons, sophonts | S ⊆ Pe ⊆ B ⊆ E ⊆ T; society, markers, currencies, actions, outcomes, decisions and interactions are things |
| `U` | Understanding, never utility | PrAcc(Ml) + CE(I(Ml)) − (Cy(Ml) \| PrAcc): predictive accuracy plus causal explanation, less complexity |
| `H` | Happiness | Affective satisfaction, weighted below U |
| `N` | Novelty | Inverse frequency; a means toward diversity |
| `Di` | Diversity | A subgoal and emergent outcome, not a priority weight |
| `Sy`, `Ŝy` | Synergy, squashed synergy | Rewards gains moving together beyond the sum of the parts (L13–14) |
| `V` | Value of an action on a being | Over U, H and N, assessed against not acting |
| `G` | Goal | argmax over actions of Σ_b Sy(V(A, b), As(pushDistr)) ∧ ↑ℝ ∧ ¬↓(U(max, min), H(min)) (L74) |

---

## Repository layout

```
Benefuture/
├── docs/
│   ├── articles/                  # Wiki articles (MediaWiki source) and _manifest.json
│   ├── BACKPROPAGATION.md         # Findings and author rulings flowing back to the sources
│   ├── SPEC_DIVERGENCES.md        # Where the Lean departs from or chooses between readings
│   ├── SIM_CONJECTURES.md         # Behavioural claims in measurable form
│   ├── THEOREM_INDEX.md           # Every theorem with its docstring (generated)
│   ├── PLAN.md, CODING_STYLE.md   # Direction, history and method
│   └── pseudocode_lean_coherence_audit.md
├── spec/
│   ├── Bf_Pseudocode.txt          # Pseudocode, source of truth (copied at the root and in Benefuture.txt)
│   ├── vectors/                   # JSON test vectors generated by the Lean reference
│   └── extracted/                 # Extracted definitions and abbreviations
├── Benefuture/                    # Lean specification over ℝ (Mathlib)
│   ├── Math/ Ontology/ Measurement/ Epistemology/ Axiology/
│   ├── Subgoals/ Governance/ Economy/ Systems/ Axioms/
│   └── Proposed/                  # [P] designs: population direction, outcome distribution, domain hierarchy
├── BenefutureReference/           # Mathlib-free Float reference; Export.lean holds the C exports
├── Main.lean                      # `lake exe benefuture`: regenerates spec/vectors
├── sim/                           # Julia package BenefutureSim: src/, test/, battery/, README.md
└── tools/                         # setup/, wiki_sync/, extraction/, bf-graph/, README and index checks
```

---

## Building and verifying

```bash
tools/setup/toolchains.sh                         # Lean and Julia (idempotent)
lake exe cache get && lake build                  # Lean specification and reference
julia --project=sim -e 'using Pkg; Pkg.test()'    # simulation tests
python3 tools/check_readme_claims.py              # every theorem named here exists
python3 tools/theorem_index.py                    # regenerate docs/THEOREM_INDEX.md
lake exe benefuture                               # regenerate spec/vectors (Mathlib-free)
```

CI runs the Lean build ("Lean Action CI") and the simulation tests ("Julia Sim CI") on every push.

---

## For implementers

- The ℝ specification (`Benefuture`) is the mathematical statement: definitions, structural
  theorems, state transition semantics (`Step`) and conservation invariants (append-only memory,
  identity injectivity, escrow soundness, supply balance identities).
- The Float reference (`BenefutureReference`) implements the core operators computably (Sy, Ŝy,
  As, V, escrow splitting, lazy continuous decay, parent domain aggregation, voting weights, and the
  rules the simulation calls). Correspondence with the ℝ specification is **not** proved.
- The simulation defines no rule itself: every rule is a reference function exported through
  `BenefutureReference/Export.lean` and called by `ccall`; Julia holds the world model and input
  guards. Each increment starts with acceptance tests (against `spec/vectors/` where they apply) and
  an adversarial suite, run red before implementing. Ladder, run lengths, noise ranges, governed
  thresholds and the parsimony audit: [sim/README.md](sim/README.md).
- Vector files and the spec definitions they match:
  - `synergy.json`: `net_synergy`, `squashed_synergy` (L13-14).
  - `assessment.json`: `dynamic_assessment_real`, `((t > t₀ ? Me : Pr) − Pr_counter) / Th_Cx` (L48).
  - `value.json`: `compute_harm_weight` (κ = ½, q₊ = 1.5, `harmSchedule`) and `value_on_being` (items (x, w₊, w₋), κ = 2) (L61, L73).
  - `ehr.json`: `p_forgive`, `p_overreact`, `ehr_expected_response` (L117).
  - `pricing.json`: `resource_cost` (physical + compute + network + time), `transaction_price` (L86), `supply_delta` (L99), `competition_efficiency` (L82).
  - `escrow.json`: `upfront_payment` / `escrow_hold` (L84; no overhead).
  - `reputation.json`: lazy exponential decay (`RepCache`).
  - `democracy.json`: voting weight (L113; Government.txt: base + expertise·Σŵ·Re + impact; optional below Th) and cyclic-review attenuation (`attenuate_cyclic_reviews`).
  - `harm.json`: `h_harm` (below rolling average), `u_harm` (below running maximum), `happiness_score` with graded MM bias claims (L54, L37).
  - `freedom.json`: `fr_permissible` with longtermist defaults, `experiential_variety` (L135, L37).
  - `population.json`: `skew_key`, `population_novelty_hist`, `effective_types`, `pareto_front`, `accumulate_capped` (`Benefuture.Proposed.PopulationDirection`, `Benefuture.Governance.Incentives`).
- Runtime checks that follow from proved theorems: chosen plans never contract ℝ and never lower max
  U, min U or min H against not acting (`goal_G_sound`), and are never dominated by another
  admissible plan (`dominated_plan_not_chosen`); Fr is reported per plan as a subgoal, not enforced
  on G; no delegate exceeds Th_k + max single weight (`accumulate_capped_bound`); summed novelty
  never exceeds the number of distinct types (`population_novelty_hist_le`).
- Parameter space: `Benefuture.Systems.ParamSpace` defines every governed parameter
  (`ParamVector`), the admissible region (`Admissible`), bootstrap defaults (`bootstrapParams`) and
  SigThGv steps. Sweep parameters only inside `Admissible`; every structural theorem holds there
  (`governed_params_admissible`, `admissible_dominated_plan_not_chosen`).
- Conjectures to test: implement `SimTrace` and check each `Conj_*` on simulated runs.

---

## License

GNU Lesser General Public License v2.1 (LGPL-2.1). See [LICENSE](LICENSE).
