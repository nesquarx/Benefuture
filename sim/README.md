# BenefutureSim

Agent-based simulation of the Benefuture specification. The rules (synergy, value, harm weight,
assessment, floors, Goal G's choice) are computed by the Lean reference library
`BenefutureReference` through its C exports (`BenefutureReference/Export.lean`); this package
supplies the world they act on, and checks behavioural conjectures over the resulting traces.

```
julia --project=sim -e 'using Pkg; Pkg.test()'
```

Loading the package rebuilds the Lean shared library only when the hash of the Lean reference
sources changes. Toolchains: `tools/setup/toolchains.sh`.

## Model ladder

Each rung adds one source of mess and must still run in minutes, not hours. Every rung keeps the
earlier ones as special cases (perfect settings reproduce the rung below), and each is judged
against named conjectures. Toy worlds are a stage. The end state is a system of rules ready for
implementation: the Lean objects modelled one to one (domains, leaf and parent domains, metric
models, currencies, transaction proposals, memory), no toy assumptions left, and every step able
to absorb messy reality's noise. Each rung names the Lean objects it approximates and the toy
assumptions it still makes, and graduates to them.

| Rung | World added | Judged against | Status |
|---|---|---|---|
| M0 | Fixed population; random plan menus; perfect measurement; every loss is passing harm | `Conj_FloorsRise` | done |
| M1 | Competing metric models with bias and noise, scored against established markers | `Conj_MMCompetitionConverges`, B14 | done |
| M2 | Agents propose the plans; imperfect agents (skill, sloppiness); escrow payment and settlement; reputation from contribution | B9, B20, `Conj_MinTracksPrediction` | first pass done |
| M3 | Domains, needed by every transaction: profiles as partitions of unity; payment, currency and reputation (history and relevance) attributed per domain, never crossing | B10, anti-halo isolation | first pass done |
| M3b | Profiles measured by currency metric models from causal signatures, not declared; prices per currency (resource cost less escrow upfront); spending only from the same currency; balance overflow into domain reinvestment | B6, B9, B10 | flat first pass done |
| M3c | Domain network (Ontology.Domain [R]): leaves hold shares, parents are fuzzy sets of leaves with μ learnt from memory; descent from matched parents; currencies eligible by accuracy threshold (novel leaves after a score-only phase, never below 0.5); fallback by μ; StandCoin lane at full resource cost with co-funding experts; novel leaves formed from clustered blockages; a noise parameter for every step | B6, B9, B10 | first pass done |
| M3d | Transactions and the behavioural transaction substrate: every proposal a transaction quoted by each relevant currency (TP_Gen, L86), screened by G together with the step's accepted work, executed if paid for, logged with its quotes (L89, L145); transaction trees: actions build on others' recent outputs; outcomes split into assessed parts, positive parts paying their contributors and negative parts penalising theirs (L93–94, BACKPROPAGATION 8.14); co-funders share the actor's parts | B6, B9, `Conj_MinTracksPrediction` | first pass done |
| M3e | A world that moves on its own: hazards in domains; guardians bound by contract (laws once communicated count) to prevent them, assessed against that committed action when they do not; crime when informed, accident when not (Lean `is_crime_ref`); hazards created as side effects of actions; penalties funding repair | B5, `Conj_FloorsRise` | first pass done |
| M4 | Thresholds: the value parameters governed by SigThGv's perturbation branch inside the admissible region (Lean `admissible_ref`, `perturb_step_ref`), with adaptation by the floors' movement ([P]); next, the simulation's own gates and debatable thresholds (M5) | `Conj_ParamStability` | first pass done |
| M5 | Governance: weighted voting (base, domain expertise, impact), capped liquid delegation, debate on thresholds; the uncertainty margin on floors if ratified | `Conj_DelegationDispersed`, B11, B23 | |
| M6 | Malicious and gaming agents: inflating measured outcomes, profile gaming, exploit against reveal with bounties and clawbacks, model collusion, Sybil attempts against identity binding, informed falsehood, external aggressors | `Conj_GamingResistance`, `Conj_AdversarialRobustness`, `Conj_GoodhartReduction`, B1–B5, B18, B21 | |
| M7 | Population change: births, deaths, forks; teaching that shares understanding | `Conj_NoRepugnantDrift`, B15, B17, B19 | |
| M8 | Networks; propagation and leakage across games; end of lifespan and causal inheritance | B25 | |

## Coverage of the specification

The end state simulates every aspect of the Lean specification and the pseudocode. Where each Lean
module stands (simulated: its rules run in the simulation through the Lean reference; partial:
some of its rules or a simplified stand-in; not yet: no simulated counterpart):

| Lean module | Status | Where |
|---|---|---|
| `Math.Synergy`, `Math.Order` | simulated | Sy, Ŝy, V weights (all rungs) |
| `Axiology.Value`, `Axiology.Priorities` | partial | V, harm schedule and passing-tier harm (M0+); happiness kinds, bias claims, U and H harm reference points not yet |
| `Measurement.MetricModel` | partial | scoring by −MSE, adoption, accuracy, eligibility (M1, M3c); markers, novelty and causal explanation terms not yet |
| `Measurement.Threshold` | not yet | M4 |
| `Economy.Pricing`, `Economy.Currency` | partial | escrow, settlement, transaction price, scarcity cost, overflow (M2–M3c); supply minting and burning not yet |
| `Ontology.Domain`, `Proposed.DomainHierarchy` | simulated | leaf shares, fuzzy parents, aggregation, learnt overlaps (M3c) |
| `Ontology.Reputation` | simulated | hPos, hNeg, relevance by sign, recount from memory (M3–M3c) |
| `Proposed.PopulationDirection` (G, D) | partial | a reference chooser over floors (`g_choose_ref`); the full `goal_G` with D and Pareto filtering not yet |
| `Systems.Memory`, `Systems.State` | partial | append-only memory of executed and blocked actions (M3c); identity and `Step` invariants not yet |
| `Systems.Substrate`, `Systems.Pipeline` | partial | transactions logged with their quotes; transaction trees one link deep; outcome-first causal distribution with Shapley shares and the traversal fallback (M3d); deeper chains not yet |
| `Systems.TechnologyNetwork` | partial | Phase 1 score-only start (M3c); identity binding, privacy tiers not yet |
| `Systems.Economy` | partial | overflow (M3b, M3c); baseline income not yet |
| `Systems.ParamSpace` | partial | admissibility and perturbation of the value parameters (M4); debatable parameters and the simulation's own gates not yet |
| `Governance.Democracy`, `Governance.Incentives`, `Systems.Governance` | not yet | voting, delegation cap, Brier incentives (M5) |
| `Governance.Adversarial`, `Axioms.Antifragility` | not yet | bounties, clawbacks, revelation (M6) |
| `Governance.ExternalHarm` | not yet | external harm response (M6) |
| `Ontology.Entity`, `Ontology.Being`, `Ontology.Sophont`, `Ontology.Person`, `Ontology.Thing`, `Ontology.Reality` | not yet | forks, merges, extended self, liability (M7, M8) |
| `Subgoals.Justice` | partial | crime or accident by notice and duty, repair funded by penalties (M3e); restorative packages not yet |
| `Subgoals.*` (others), `Epistemology.*`, `Ontology.Law`, `Systems.Enforcement` | not yet | freedom, justice, diversity, truth, information handling, law and enforcement (M6–M8) |
| `Systems.Conjectures` | partial | readings in this file; `SimTrace` and the `Conj_*` checks not yet |
| `Systems.FixedPoint` | not applicable | the simulation uses Float, not the Int fixed point |

## Run length

Measured on M1 (200 beings, 20 plans a step, three models, ten seeds of 1,000 steps; about 11 s
a run):

| Reading | Running mean settles within 10% (median, worst seed) | Spread across ten seeds (relative 95% half-width) at 100 / 300 / 1,000 steps |
|---|---|---|
| Share of steps acting | 81, 208 | 4.5% / 1.7% / 0.6% |
| Floor growth, happiness | 482, 576 | 8.3% / 5.2% / 2.2% |
| Floor growth, understanding | 570, 681 | 10.4% / 4.7% / 3.0% |
| Floor falls (rare) | 736, 884 | 16.4% / 10.3% / 6.3% |

Model adoption locks onto the best model by step 4 (median; 19 at worst). Rates are not steady
from the start: floor growth is about 0.06 a step over the first 100 steps and 0.10–0.12 after,
so the slow settling of growth rates is mostly warm-up. Guidance: discard a burn-in of 200
steps; measure rates over at least 500 steps after it, and rare events such as floor falls over
1,000; use ten seeds. Spread falls roughly with the square root of steps times seeds.

## M0 observations

1,000 beings, 100 steps, 20 random plans a step, seed 1 (about 8 s):

- A plan beats inaction in 89 of 100 steps.
- Floors of understanding and happiness rise (3.7 → 10.1 and 3.7 → 9.5), as `Conj_FloorsRise` requires; in M0 it holds exactly, since measurement is perfect and G never accepts a plan that lowers a floor against inaction.
- The peak of understanding pulls away from the median (8.0 → 38.6 against 5.1 → 16.2). With the distribution term D absent and gain exponent q₊ > 1, concentrated gains score well; this is the frontier-compounding question of conjecture B17, to revisit once D and sharing of understanding are modelled.

## M1 observations

Competition settles on the most accurate model, and a precise but biased model loses to an
unbiased one of equal noise (tests). With perfect models and exact markers M1 reproduces M0.
Floors under noise, 200 beings, 100 steps, 20 plans a step, mean of 5 seeds:

| Model noise | Marker noise | Steps the true floor falls | Steps a plan is chosen |
|---|---|---|---|
| 0 | 0 | 0 | 90% |
| 0 | 0.1 | 9% | 91% |
| 0.5 | 0 | 14% | 85% |
| 2.0 | 0 | 2% | 7% |

The floors' guarantee is exactly as good as measurement. Noise on current levels alone breaks it,
because G misjudges who is at the floor; moderate prediction noise admits plans that lower the
true floor; heavy prediction noise freezes G, which then chooses inaction in most steps. Noise
turns the hard filter into either harm or stagnation (conjectures B7, B14).

## M2 observations

Agents propose the plans; the proposer of the chosen plan is paid its predicted value split by
the model's confidence, then settled against the markers. Under perfect measurement and careful
agents nothing is settled, predicted and realised floor changes match, and payments sum to the
measured value of the plans chosen (tests). 30 agents with skills from −0.2 to 0.6, 200 beings,
500 steps, 15 plans a step, exact measurement, mean of 5 seeds:

| Agents' sloppiness | Reputation against skill (Spearman) | Settlement relative to value | Chosen plans measured negative |
|---|---|---|---|
| none | 0.98 | 0 | 0 |
| 0.3 | 0.97 | 21% | 0 |
| mixed 0, 1, 2 | 0.23 | 96% | 40% |

With heavy sloppiness reputation tracks carefulness (Spearman 0.64 against carefulness, 0.23
against skill): convex harm makes execution noise cost more in losses than it gives in gains,
so a skilled but sloppy agent contributes less, often harm. That is reputation working as
specified, demonstrated contribution rather than latent skill; it also means escrow settlements
are large and frequently clawbacks, the solvency question of conjecture B9. Contributions from
several agents to one plan, and causal distribution among them, are still to come.

## M3 observations

With one domain M3 reproduces M2 exactly; payments and history are conserved across domains, and
a domain outside an agent's profile receives nothing (tests). 4 domains, 40 agents with random
skills per domain, half specialists and half generalists, 500 steps, mean of 5 seeds: relevance
in a domain correlates only weakly with skill in that domain (Spearman 0.36), and barely better
with profile share × overall effect (0.44). With a fixed profile per action, attribution splits
whole-action outcomes by declared shares, so per-domain skill cannot be identified, and an agent
able to set its own profile could claim reputation in a domain of its choosing. The spec points
the other way: domain relations come from memory, not declaration (L22, `!declared`). M3b
therefore measures each action's profile from where its effects land.

## M3b observations

Flat first pass: D leaf domains, plus StandCoin for anything matching none. With one domain, no
cost and no overflow, M3b reproduces M2; balances move by measured value less resource cost less
overflow; declaring a focus buys no reputation outside the domains a plan is classified into; new
scenarios go to StandCoin and are flagged; plans an agent cannot afford leave the menu (tests).
Same setup as the M3 reading (4 domains, 40 agents, sloppiness 0.3, 500 steps, 5 seeds; about 6 s
a run):

| Reading | M3 (declared profile) | M3b | M3b, 5% new scenarios |
|---|---|---|---|
| Relevance against focus × skill per domain (Spearman) | 0.39 | 0.71 | 0.72 |
| Known plans classified to their own domain | n/a | 100% | 100% |
| New scenarios sent to StandCoin | n/a | n/a | 100% |
| Share of net earnings overflowing into reinvestment | n/a | 83% | 82% |

Measuring profiles nearly doubles how well domain reputation tracks domain skill; what remains is
sloppiness and selection. The approximate thresholds are not yet calibrated: signatures are so
well separated that classification is perfect, overflow takes most earnings, and a resource cost
of 0.01 per touched being changes nothing measurable. Superseded in part: StandCoin here pays for
predicted value like any other currency, whereas it sits at the root of the domain tree, predicts
no outcomes and charges only resource cost (M3c).

## M3c observations

Domains form a network, as in Lean's ratified model: an action's shares sit on leaf domains, and
parents are fuzzy sets of leaves with degrees μ (`aggregate_at_parent`). Benefuture starts
score-only: for the first 50 steps no currency backs value, G chooses on the best available
models, and work is executed, scored and logged. μ starts from a bootstrap classification that
knows each leaf's primary parent only, and moves as a long-term rolling average of the
memberships of every logged action, executed or blocked (`membership_rolling`): overlaps are
learnt and shift as reality does, and domains never fade. Classification descends from matched
parents to member leaves; pricing falls back from ineligible currencies to eligible parents by
μ, or to StandCoin; work only StandCoin would take pays its full resource cost, is screened by G
on the best available model, and goes ahead if the proposer, with experts, can pay. New
top-level domains are not modelled (implausible). Tests: the score-only start moves no currency;
plans reach their true leaf; unused and rarely used leaves keep their degrees and their work; an
overlap the bootstrap does not know is learnt; parent reputation equals Σ μ × leaf reputation
plus what stuck at the parent; a hidden leaf forms, is scored but prices nothing until it
qualifies, then takes its work; when no currency qualifies, StandCoin work is screened (a
harmful agent's almost never passes, and what passes is measured beneficial), halts when
unfunded, and is co-funded by experts; incremental reputation equals a recount; under every
noise source at once the books still balance.

3 parents of 4 known leaves (three with real overlaps of 0.2–0.4 on a second parent, unknown to
the bootstrap) and two hidden leaves under parents; 42 agents, three per leaf, sloppiness 0.3;
200 beings, 500 steps (50 score-only), 15 plans a step, marker noise 0.05; 5 seeds (about 7 s a
run). Heavy noise: classification 0.08, model bias 0.3, cost error 0.3, regeneration variability
0.5, memory loss 10%, expert participation 50%.

| Reading | Formation | No formation | Formation, heavy noise |
|---|---|---|---|
| Novel leaves formed (none spurious) | 2 | 0 | 2 |
| Step of formation (mean) | 18 | n/a | 22 |
| Novel leaves qualifying within 500 steps | 5 of 10 | n/a | 3 of 10 |
| Steps from formation to qualifying (those that did) | 257 | n/a | 139 |
| Known work classified to its leaf | 100% | 100% | 83% |
| Error of learnt overlap degrees (true 0.2–0.4) | 0.17 | 0.18 | 0.20 |
| StandCoin lane: executed, halted (per run) | 0, 0 | 0, 0 | 26, 43 |
| Floor growth, understanding | 35.1 | 34.4 | 29.3 |

Missing domains are found within about 20 steps and nothing spurious forms, even under heavy
noise. Overlaps are learnt slowly by design: at a rolling rate of 0.02 and about 35 logged
actions per leaf in 500 steps, a degree has moved about halfway from the bootstrap to its true
value; a busy leaf converges (tests), a quiet one lags. A novel leaf qualifies only as fast as its
work is executed and scored; half have not within 500 steps, and meanwhile their work is priced
by the parent at coarse confidence. Under heavy noise, model bias costs some parents their
eligibility; their work falls to StandCoin, where most halts for lack of funds, and floors grow
about 17% less.

## M3d observations

Every proposal is a transaction: each relevant currency quotes it (TP_Gen, L86); G screens it
against the observed state plus the predicted effects of the transactions already accepted that
step, so concurrent work cannot jointly breach a floor on its predictions; it executes if its
proposer can pay; memory logs it with the quotes composed for it (L89, L145). Tests: many
transactions a step; with exact models and markers no floor ever falls; every executed transaction
is logged with its quotes; a harmful agent's transactions are screened out; with the switch off,
M3c is unchanged. Same world as the M3c reading, with the score-only start excluded:

| Reading | G picks one plan | Transactions | G, model bias 0.3 | Transactions, model bias 0.3 |
|---|---|---|---|---|
| Actions executed per step | 0.99 | 4.1 | 0.99 | 4.9 |
| Floor growth, understanding (450 steps) | 33 | 98 | 28 | 98 |
| Steps the true floor of understanding falls | 7.3% | 9.7% | 13% | 15% |
| Executed actions measured harmful | 1.7% | 8.9% | 14% | 27% |

G's single argmax takes the best of fifteen proposals; the transaction screen admits anything
predicted to beat inaction. That roughly triples progress and admits more mediocre and harmful
work, which settlement claws back; model bias magnifies the harmful share. Selective composition
(quoting from a subset of currencies) changes nothing here, since settlement already runs against
the union of all concerned currencies; it is tested with gaming agents (M6). Baseline negative
pricing (L143) needs beings who transact for basic needs themselves (M7).

Transaction trees and outcome-first causal distribution (BACKPROPAGATION 8.16–8.18): an action
may build on a recent output of another agent in its domain, carrying part of its effect. Each
being an action touches is an outcome, its assessed change in V. The causal-explanation model
estimates each contributor's effect; contributors share each outcome Shapley-style (Lean
`shapley_ref`) over coalition values (V of the members' summed effects, the actor's own effect
counting only if the coalition can fund the action); positive shares are paid and negative shares
penalised. Below the confidence threshold (`cc_assessed_ref`), the traversal fallback shares the
outcome by net contribution and degree of separation (`traversal_shares_ref`). Tests: intermediaries
who add nothing earn almost nothing while the makers upstream are paid; every outcome is fully
distributed; a bad output is penalised through the losses it carries downstream; co-funders whose
money was needed are credited; heavy attribution error switches distribution to the fallback; the
books balance and reputation recounts exactly.

## M3e observations

Hazards arise in domains and harm beings unless prevented. A guardian bound by contract to
prevent them in its domain who does not act is assessed against that committed action, so the harm
is its contribution: a crime if it was informed, an accident if not (Lean `is_crime_ref`, L115),
penalised either way to fund repair. Unguarded hazards have no contributor: the harm is recorded as
unattributed and no bystander is penalised. Actions may create hazards as side effects: direct
harm to their actors, a crime if foreseen and an accident if not, repaired either way. Tests cover
each case and the books balance. Same world as the M3d reading, transactions with causal
distribution, hazards in half of all steps (each threatening 10% of beings), 5 seeds:

| Condition | Floor growth, understanding | Steps the floor falls | Crimes | Accidents |
|---|---|---|---|---|
| No hazards | 97 | 8.7% | 0 | 0 |
| Unguarded hazards | 81 | 18.8% | 0 | 0 (all harm unattributed) |
| Guarded (informed 80% of the time) | 96 | 12.3% | 0 | 49 |
| Guarded, repair efficiency 0.5 | 98 | 10.2% | 0 | 49 |
| Half-diligent guardians, repair 0.5 | 93 | 12.6% | 103 | 51 |

Duties recover most of what unguarded hazards cost; what guardians miss for lack of notice becomes
accidents, and negligence becomes crime, both repaired from the penalties.

## M4 observations

The value parameters (α, β, γ, q₊, q₋, λ) start at the Lean bootstrap point and are governed by
SigThGv's perturbation branch: every epoch a candidate within δ of the current vector in each
field is adopted if admissible (`perturb_step`). Adaptation ([P], BACKPROPAGATION 8.20) keeps a
candidate only if the floors moved at least as well during its epoch as during the previous one;
the first epoch runs on the bootstrap point as the baseline. Tests: every vector stays admissible;
drift is bounded by epochs × δ; δ = 0 changes nothing. 600 steps, epochs of 50, δ = 0.02, 5 seeds:

| Parameters | Floor growth, understanding | Steps the floor falls | Largest drift | Kept, reverted |
|---|---|---|---|---|
| Fixed at bootstrap | 123 ± 23 | 8.3% | 0 | – |
| Perturbed | 123 ± 24 | 8.1% | 0.058 | 10, 0 |
| Perturbed with adaptation | 124 ± 23 | 8.6% | 0.044 | 5, 5 |

Within this range the outcomes do not depend on the parameters (consistent with
`Conj_ParamStability` at this scale), and adaptation is a coin toss: epoch-to-epoch movement of the
floors is far noisier than any effect of a 0.02 change, so adaptation needs longer epochs or a
paired comparison to mean anything.

Balance overflow trades reinvestment against spread of wealth (strict-tree version of M3c, 3 seeds):

| Base, factor | Share of net earnings reinvested | Gini of balances |
|---|---|---|
| 50, 0.5 | 84% | 0.18 |
| 200, 1.0 | 59% | 0.35 |
| 500, 1.0 (default) | 34% | 0.45 |
| 1,000, 1.0 | 11% | 0.53 |

## Governed thresholds

Every gate value the simulation sets is a threshold to be governed later (SigThGv, M4–M5;
`Systems.ParamSpace`). Defaults are approximate, chosen to make the toy world behave, not
ratified.

| Gate | Parameter | Default | Source |
|---|---|---|---|
| Floor quantile and significance | `ToyParams.q`, `ToyParams.th` | 0.1, 1.0 | L74, L48 |
| Governance epoch and perturbation size | `gov_epoch`, `gov_δ` | 50, 0.02 | L157 |
| Currency eligibility (established, novel; novel never below 0.5) | `threshold`, `novel_threshold`, `min_records` | 0.55, 0.52, 10 | L82; 8.8 |
| Classification: parent match, leaf membership, leaf match | `parent_threshold`, `μ_min`, `leaf_threshold`, `temperature` | 0.5, 0.2, 0.4, 0.01 | L22; 8.3 |
| Overlap rolling-average rate | `μ_rate` | 0.02 | 8.12 |
| Formation of novel domains | `form_count`, `form_radius` | 20, 0.5 | 8.6 |
| Score-only start | `init_steps` | 50 | Implementation, Phase 1; 8.11 |
| Balance overflow | `overflow_base`, `overflow_factor` | 500, 1.0 | L100; 8.7 |
| Expert co-funding share | `expert_share` | 0.5 | 8.8 |
| Resource cost and regeneration | `cost_per_touch`, `capacity`, `regen` | 0.05, 10⁴, 0.02 | L83 |
| Reputation decay | `λpos`, `λneg` | 0.02, 0.05 | L101 |
| Causal assessment confidence (else traversal) | `cc_threshold` | 0.6 | L94; 8.17 |
| Traversal decay by degree of separation | `traversal_decay` | 0.5 | L95; 8.17 |

## Noise

Every step that can go wrong in reality has a noise parameter, drawn from its own random stream
so that turning one off changes nothing else. Defaults are toy-level; the ranges are first
guesses at reality, to be swept once the model is solid.

| Step | Parameter | Default | Range to explore |
|---|---|---|---|
| A plan's effect on each being | `ToyParams.spread` | 1.0 | 0.5–3 |
| Carrying a plan out | agent `sloppiness` | 0–0.3 | 0–2 |
| Markers measuring levels and outcomes | `marker_σ` | 0–0.05 | 0.05–0.5 |
| Metric model predictions | `σ_leaf`, `σ_branch`, `σ_coarse`, `MetricModel.σ` | 0.3, 0.5, 0.75 | 0.2–2 |
| Systematic model bias | `bias_σ`, `MetricModel.bias` | 0 | 0–0.5 |
| An action's causal signature (world, measured) | `spread`, `classify_σ` | 0.03, 0.03 | 0.03–0.15 |
| Bootstrap classification (what it misses) | overlaps unknown to it | all | all to none |
| Resource accounting | `cost_σ` | 0 | 0–0.5 |
| Resource regeneration | `regen_σ` | 0 | 0–1 |
| Records reaching memory | `memory_loss` | 0 | 0–0.2 |
| Experts joining co-funding | `participation` | 1 | 0.3–1 |
| Separating an upstream output's part | `attribution_σ` | 0 | 0–0.5 |
| Hazard harm | `hazard_σ` | 0.2 | 0–1 |
| A guardian learning of a hazard in time | `p_informed` | 0.8 | 0.3–1 |
| A guardian acting on a known duty | `diligence` | 1 | 0.3–1 |
| An actor foreseeing a side effect | `p_foresee` | 0.5 | 0–1 |
| Repair restoring harm | `repair_efficiency` | 0 (off) | 0.2–1 |

Still without noise, to add as their rungs arrive: identity binding (M6), votes and delegation
(M5), threshold estimates (M4), transaction logging and composition (M3d).
