# Benefuture

> **A Formal Specification for Antifragile, Post-Scarcity Civilizational Flourishing**  
> *A type-checked specification of the Benefuture pseudocode, with invariants and sanity lemmas; behavioural claims (convergence, gaming resistance) are conjectures for simulation.*

[![Lean Action CI](https://github.com/nesquarx/Benefuture/actions/workflows/lean_action_ci.yml/badge.svg)](https://github.com/nesquarx/Benefuture/actions/workflows/lean_action_ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-v4.29.0-blue.svg)](https://leanprover.github.io/)
[![License: LGPL v2.1](https://img.shields.io/badge/License-LGPL_v2.1-green.svg)](LICENSE)

---

## Overview

**Benefuture** is a mathematical, epistemic, and economic framework designed to guide long-term civilizational trajectory away from catastrophic failure modes (such as wireheading loops, extractive financialization, systemic fragility, and cognitive monoculture) and toward open-ended, reality-grounded flourishing.

This repository hosts the **type-checked specification in Lean 4**. In this architecture:
- **Lean 4 holds the specification**: types, invariants, definitions, structural properties, and mathematical sanity lemmas.
- **Assumptions and requirements** are stated explicitly as hypotheses, structure fields, and design requirements rather than tautological theorems.
- **Behavioural and empirical claims** (such as convergence under adversarial agents, gaming resistance, and stability of metric-model competition) are formulated as conjectures (`Conj_*` in `Benefuture.Systems.Conjectures`) over a `SimTrace` of simulation observables: definitions only, neither assumed nor proved, intended for empirical validation in simulation (e.g. in Julia).

---

## Foundational Ontological Architecture

Benefuture organizes all phenomena in the Universe ($\mathbb{U}$) into a strict concentric ontology grounded in physical Reality ($\mathbb{R}$):

$$\text{Sophonts } (S) \subseteq \text{Persons } (Pe) \subseteq \text{Beings } (B) \subseteq \text{Entities } (E) \subseteq \text{Things } (T) \subseteq \text{Reality } (\mathbb{R}) \subseteq \text{Universe } (\mathbb{U})$$

Every operational primitive in the system inherits physical and informational standing as a subtype of `Thing`:
- **Society / Civilization** ($So, Cv \subseteq E \subseteq T$)
- **Empirical Markers** ($M \in T$)
- **Currencies & Resource Accounting** ($C, RA \in T$)
- **Interactions, Actions, Outcomes, & Decisions** ($I, A, O, D \in T$)
- **Laws, Contracts, Accolades, & Crimes** ($Lw, Ct, Aco, Cr \in T$)
- **Memetic Cultures & Artworks** ($Cu, Art \in T$)

### The Core Universal Goal ($G$)

$$\text{Goal } G(t) := \operatorname{argmax}_{A(t)} \left[ \sum_{b \in B(t)} V(A, b(t)) \right] \land \uparrow \mathbb{R}$$

Benefuture defines the civilizational goal as the joint maximization of sentient value **and** the non-decreasing or expanding scope of physical Reality ($\uparrow \mathbb{R}$). Actions that seek to maximize subjective pleasure by blinding sensors, shrinking capability, or collapsing into solipsistic simulation fail the reality condition.

### Canonical Notation & Symbol Disambiguation

To ensure mathematical precision and prevent conflation across foundational concepts:
| Symbol | Canonical Concept | Mathematical Meaning & Formula | Disambiguation Rule |
| :--- | :--- | :--- | :--- |
| **$\mathbb{U}$ / `𝕌`** | **Universe** | Total state space of all logically possible patterns | **Total ontological pattern space** ($\mathbb{R} \subseteq \mathbb{U}$). Never write as plain ASCII $U$. |
| **$\mathbb{R}$ / `ℝ`** | **Reality** | $(\text{Perceivable} \cup \text{Changeable}) \subseteq \mathbb{U}$ | Physical, empirical interactivity domain. |
| **$U$** | **Understanding** | $\text{PrAcc}(\text{Ml}) + \text{CE}(I(\text{Ml})) - (\text{Cy}(\text{Ml}) \mid \text{PrAcc})$ | **Strictly Epistemic Understanding**. Must **never** be interpreted as "utility". |
| **$V$** | **Value** | Generalized flourishing payoff $V(A, b)$ | Represents the true "utility" / value function of an action over $U, H, N$. |
| **$G$** | **Goal** | Civilizational trajectory function $\operatorname{argmax} \sum V \land \uparrow \mathbb{R}$ | Global macro objective. |
| **$H$** | **Happiness** | Internal affective flourishing | Tier $\beta$ in the priority hierarchy ($U > H > N$). |
| **$N$** | **Novelty** | Inverse empirical frequency: $N(x) := 1 / \text{Frequency}(x \mid \mathbb{R})$ | Tier $\gamma$ in the priority hierarchy ($U > H > N$). An operational input and means toward diversity. |
| **$\text{Di}$** | **Diversity** | $\text{Balance}(\text{order}, \text{chaos}) \to \text{Variety}(\text{Sys}) \to \text{Resilience} + \text{Innovation}$ | Emergent macro outcome & civilizational subgoal (`SubG.Diversity`), NOT a scalar priority weight. Novelty injection is one means to maintain diversity balance. |

---

## Invariants, Design Requirements, and Conjectures

Rather than asserting ungrounded real-world guarantees, the specification distinguishes:
- **Sanity Lemmas**: Proven mathematical properties of the operators (e.g. strict monotonicity, odd symmetry, loss penalty sign).
- **Invariants**: Structural invariants on state transitions (e.g. append-only memory, identity injectivity, escrow conservation, balance overflow redirection).
- **Design Requirements**: Parameter conditions required for system properties (e.g. restorative friction $> 0$ for anti-corruption, clawback $\ge$ bounty for anti-cobra).
- **Conjectures**: Behavioural dynamics left to simulation (e.g. convergence under adversarial agents, Goodhart error reduction via metric competition).

---

## Claims

What this repository establishes, in plain words, with links to the proof or the code and its
results. Three kinds of evidence, never to be read as more than they are:

- **Proved** (Lean 4 with Mathlib, over ℝ unless noted; checked by CI, no `sorry`, `admit`, custom
  axioms or `native_decide`). A proof establishes the statement *for the definitions as written,
  under the hypotheses listed*; it says nothing about whether the definitions describe the world.
- **By construction**: the theorem confirms that a rule is encoded as intended (the property is a
  structure field or follows directly from a definition). These check the encoding; they are not
  discoveries.
- **Demonstrated in simulation**: observed in the Julia agent-based simulation (`sim/`) under the
  stated toy assumptions, as tests that pass on every CI run or as readings averaged over a few
  seeds. Not proofs, and not significance-tested.

The simulation does not run the ℝ specification: it calls the Float reference library
(`BenefutureReference`, Mathlib-free) through C exports. The reference reproduces the spec's test
vectors (`spec/vectors/`), but correspondence between `Benefuture` and `BenefutureReference` is not
proved. Every theorem with its docstring: [docs/THEOREM_INDEX.md](docs/THEOREM_INDEX.md)
(generated, docstrings unreviewed).

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
- Some plan is always chosen when one is admissible, and inaction always is
  ([`inaction_admissible`](Benefuture/Proposed/PopulationDirection.lean), [`goal_G_some`](Benefuture/Proposed/PopulationDirection.lean)). The chosen plan never contracts reality, never lowers the
  maximum or minimum understanding or the minimum happiness against not acting, and maximises the
  objective over admissible plans ([`goal_G_sound`](Benefuture/Proposed/PopulationDirection.lean)).
- G never chooses a plan that another admissible plan dominates (no worse for any being present at
  decision time, better for one, no worse in distribution), under positive weights and exponents,
  κ ≥ 0, λ in [0, 1] ([`dominated_plan_not_chosen`](Benefuture/Proposed/PopulationDirection.lean)); likewise at every admissible parameter point
  ([`admissible_dominated_plan_not_chosen`](Benefuture/Proposed/PopulationDirection.lean)). Uplift with no losers beats inaction
  ([`uplift_beats_inaction`](Benefuture/Proposed/PopulationDirection.lean)).
- The floor is taken over the decision-time population: removing a being cannot raise it
  ([`removal_cannot_raise_floor`](Benefuture/Proposed/PopulationDirection.lean)), whereas over survivors only it would ([`survivor_floor_rises_on_removal`](Benefuture/Proposed/PopulationDirection.lean)).
- The distribution term D ignores the order of beings ([`level_gain_perm`](Benefuture/Proposed/PopulationDirection.lean)) and beings absent at
  decision time ([`dist_score_ignores_absent`](Benefuture/Proposed/PopulationDirection.lean)); levelling down never helps and uplift never hurts,
  for monotone shapes ([`levelling_down_never_helps`](Benefuture/Proposed/PopulationDirection.lean), [`uplift_gain_nonneg`](Benefuture/Proposed/PopulationDirection.lean)). Moving happiness from a
  better-off to a worse-off being without reversing their order never lowers D, for every concave
  shape, and any sequence of such moves likewise ([`pigou_dalton_h`](Benefuture/Proposed/PopulationDirection.lean), [`pd_run_raises`](Benefuture/Proposed/PopulationDirection.lean)). Sharing
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
  ([`shapley_null`](Benefuture/Proposed/OutcomeDistribution.lean)). That the shares sum to the outcome (efficiency) is not proved here; it
  is checked numerically on random games ([sim/test/shapley_tests.jl](sim/test/shapley_tests.jl)).
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
  however many delegate to it ([`accumulate_capped_bound`](Benefuture/Governance/Incentives.lean)); without a cap a star topology hands one
  node all the weight ([`star_topology_power_concentration`](Benefuture/Governance/Incentives.lean)).
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
([`anti_halo_domain_isolation`](Benefuture/Governance/Democracy.lean)); harm to a coupled part of the extended self is positive harm to
the being ([`defection_harms_extended_self`](Benefuture/Subgoals/Morality.lean): damage × positive coupling); completing the required
education zeroes an infohazard's modelled risk ([`education_inoculates_infohazard`](Benefuture/Epistemology/InfoHandling.lean)); reporting an
exploit pays more than exploiting it, because the bounty is defined above the gain
([`revelation_strictly_dominates`](Benefuture/Governance/Adversarial.lean)); the antifragility and continuity triggers fire on their
defining conditions ([`harm_growth_activates_intervention`](Benefuture/Axioms/Antifragility.lean), [`rising_harm_mandates_intervention`](Benefuture/Subgoals/Continuity.lean));
metric models are non-circular given the empirical-marker requirement
([`metric_models_are_non_circular`](Benefuture/Measurement/MetricModel.lean)).

### Negative and open results

- A positive floor moves the repugnant conclusion rather than resolving it: under additive
  aggregation, enough beings at any positive floor exceed any finite total
  ([`floor_shifts_repugnant_conclusion`](Benefuture/Axiology/RepugnantConclusion.lean)). The [P] distribution design answers with the
  decision-time population and diversity bounds above, not with the floor.
- Loss aversion fails for sub-unit magnitudes without normalisation ([`loss_aversion_fails_below_one`](Benefuture/Math/Synergy.lean)).
- Skew direction alone admits plans that lower the minimum ([`skew_direction_alone_permits_min_decline`](Benefuture/Proposed/PopulationDirection.lean)).
- Freedom excludes irreversible harm even when it is necessary harm with positive net gain
  ([`freedom_excludes_irreversible_necessary_harm`](Benefuture/Subgoals/Freedom.lean)); the tension is open.
- Without a delegation cap, power concentrates ([`star_topology_power_concentration`](Benefuture/Governance/Incentives.lean)).
- Causal contribution as specified (clamped value added, L93's range [0, 1]) over-distributes along
  a chain with a loss: links adding 10 and 5 followed by one destroying 10 receive 15 for an outcome
  of 5, and the loss is distributed to no one ([`cc_clamped_overdistributes`](Benefuture/Systems/Substrate.lean)).
  Resolved by the author's ruling: credit follows an outcome's assessed parts (BACKPROPAGATION 8.14).
- Harm through inaction cannot yet arise in the simulation's world, which does not change unless
  acted on (BACKPROPAGATION 8.15); the Lean now classifies informed inaction under a duty as crime.

### Demonstrated in simulation

Common toy assumptions, still to be removed (see `sim/README.md`, model ladder): beings and plans
in a small abstract world (80–200 beings; a plan's effect is Gaussian around its proposer's skill);
causal signatures as points near unit axes; model and measurement error as Gaussian noise of fixed
size; G chooses one plan a step from a menu of proposals, or screens transactions (M3d); fixed agents
and skills; one measured value per plan, with every loss counted as passing harm. Readings are
means over 5 seeds of 500 steps.

- Rules are defined once: every simulated rule is a Lean reference function called through C
  exports; the shared library rebuilds only when the Lean sources change ([sim/src/lean.jl](sim/src/lean.jl)).
- With perfect measurement, the floors of understanding and happiness never fall, and the peak of
  understanding never falls ([sim/test/m0_tests.jl](sim/test/m0_tests.jl)).
  With noise, the floors' guarantee is only as good as measurement: noise on current levels alone
  lets the true floor fall in 9% of steps, and heavy prediction noise freezes G (G acts in 7% of
  steps) ([sim/README.md, M1](sim/README.md#m1-observations)).
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
- Transactions instead of a single choice by G: about four actions a step instead of one, roughly
  three times the floor growth, and more mediocre and harmful work admitted (9% of executed actions
  measured harmful, against 2%; 27% under model bias); with exact models, screening each step's
  transactions together keeps every floor from falling ([sim/test/m3d_tests.jl](sim/test/m3d_tests.jl),
  [sim/README.md, M3d](sim/README.md#m3d-observations)).
- Causal distribution by assessed parts: agents who pass outputs on without adding to them earn
  almost nothing while the makers upstream are paid; a bad output is penalised through the losses
  it carries downstream; co-funders share the credit of the work they fund; the books balance
  exactly. About 8% of measured value (mixed outcomes, contributors meeting on one being) is not
  distributed ([sim/test/m3d_tests.jl](sim/test/m3d_tests.jl), [sim/README.md, M3d](sim/README.md#m3d-observations)).
- Balance overflow trades reinvestment against concentration: raising the threshold moves the
  share reinvested from 84% to 11% while the Gini of balances rises from 0.18 to 0.53
  ([sim/README.md, M3c](sim/README.md#m3c-observations)).

---

## Repository Structure

```
Benefuture/
├── .github/workflows/
│   └── lean_action_ci.yml         # Automated GitHub Actions Lean 4 CI
├── lakefile.toml                  # Lake package configuration
├── lean-toolchain                 # Lean 4 toolchain pin (v4.29.0)
├── lake-manifest.json             # Manifest dependencies
├── Benefuture.lean                # Primary library umbrella import
├── Main.lean                      # Executable specification / test harness
├── Bf_Pseudocode.txt              # Foundational formal pseudocode specification
│
├── Benefuture/                    # Specification modules
│   ├── Math/                      # Parameters, schedules, synergy & saturation
│   ├── Ontology/                  # Concentric ontology & entity definitions
│   ├── Measurement/               # Metric models, empirical markers & thresholds
│   ├── Epistemology/              # Truth correspondence, proper scoring, & info handling
│   ├── Axiology/                  # Priority schedules, value functions & repugnant conclusion
│   ├── Subgoals/                  # Freedom, Morality, Justice, Diversity, Art, & Continuity
│   ├── Governance/                # Liquid democracy, anti-halo isolation, & adversarial adaptation
│   ├── Economy/                   # Backed currencies, resource accounting, & probabilistic escrow
│   ├── Systems/                   # Ledger, memory, pipeline settlement, & technology network
│   └── Axioms/                    # Antifragility axioms and operational requirements
│
├── spec/
│   ├── Bf_Pseudocode.txt          # Primary formal specification source of truth
│   └── extracted/                 # Extracted definitions & abbreviations datasets
├── docs/
│   ├── SPEC_DIVERGENCES.md        # Explicit log of divergences between Lean and sources
│   ├── pseudocode_lean_coherence_audit.md # Historical audit matrix
│   └── articles/                  # Foundational Knowledge Base Articles
└── tools/                         # Maintenance, sync, extraction, and visualization tools
    ├── wiki_sync/                 # Live MediaWiki page fetcher & patch applier
    ├── extraction/                # Pseudocode extraction & semantic audit tools
    └── bf-graph/                  # Concept graph visualizer
```

---

## Quickstart & Verification

### Prerequisites

Install Lean 4 using the official `elan` toolchain manager:

```bash
curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh
source $HOME/.elan/env
```

### Build the Full Specification

Clone the repository and compile:

```bash
git clone https://github.com/nesquarx/Benefuture.git
cd Benefuture
lake build
```

---

## For Implementers

This repository maintains a two-tier formalization architecture:
1. **The Formal Specification (`Benefuture`, over $\mathbb{R}$)**:
   - Formulated over real numbers ($\mathbb{R}$) using Mathlib.
   - States foundational definitions, structural theorems, state transition semantics (`Step`), and exact conservation invariants (append-only memory, identity injectivity, escrow soundness, and supply balance identities).
   - Serves as the mathematical source of truth.
2. **The Computable Reference Library (`BenefutureReference`, over `Float`)**:
   - Zero Mathlib dependencies; completely decoupled from the spec library.
   - Implements computable, Float-based versions of core mathematical operators ($Sy, \hat{Sy}, As, V$, escrow splitting, lazy continuous decay, parent domain aggregation, and voting weights).
   - Generates deterministic JSON test vectors to `spec/vectors/*.json`.

### Working with Simulations (Julia, `sim/`)
- Spec ↔ reference correspondence is **not** proved in Lean (which uses classical reals).
- The agent-based simulation (`sim/`, Julia package `BenefutureSim`) defines no rule itself: every
  rule is a function of the Lean reference library, exported through
  `BenefutureReference/Export.lean` and called by `ccall`; Julia holds the world model and input
  guards. Loading the package rebuilds the shared library only when the Lean sources change.
  Ladder of models, run lengths, noise ranges and readings: [sim/README.md](sim/README.md).
- Each simulation increment starts with acceptance tests (against `spec/vectors/*.json` where they
  apply) and an adversarial suite, run red before implementing.
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
- Runtime checks that follow from proved theorems: chosen plans never contract ℝ and never lower max U, min U or min H against not acting (`goal_G_sound`), and are never dominated by another admissible plan (`dominated_plan_not_chosen`); Fr is reported per plan as a subgoal, not enforced on G; no delegate exceeds Th_k + max single weight (`accumulate_capped_bound`); summed novelty never exceeds the number of distinct types (`population_novelty_hist_le`).
- Parameter space: `Benefuture.Systems.ParamSpace` defines every governed parameter (`ParamVector`), the admissible region (`Admissible`), bootstrap defaults (`bootstrapParams`) and SigThGv steps. Sweep parameters only inside `Admissible`; every structural theorem holds there (`governed_params_admissible`, `admissible_dominated_plan_not_chosen`).
- Conjectures to test: implement `SimTrace` and check each `Conj_*` on simulated runs.
- Regenerate vectors with `lake exe benefuture` (Mathlib-free; builds in seconds).

---

## License

This project is licensed under the **GNU Lesser General Public License v2.1** (LGPL-2.1). See the [LICENSE](LICENSE) file for complete terms.