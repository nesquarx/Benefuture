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
against named conjectures. Toy worlds are a stage: the simulation's end state models the Lean
objects one to one (domains, leaf and parent domains, metric models, currencies, transaction
proposals, memory), so each rung names the Lean objects it approximates and graduates to them.

| Rung | World added | Judged against | Status |
|---|---|---|---|
| M0 | Fixed population; random plan menus; perfect measurement; every loss is passing harm | `Conj_FloorsRise` | done |
| M1 | Competing metric models with bias and noise, scored against established markers | `Conj_MMCompetitionConverges`, B14 | done |
| M2 | Agents propose the plans; imperfect agents (skill, sloppiness); escrow payment and settlement; reputation from contribution | B9, B20, `Conj_MinTracksPrediction` | first pass done |
| M3 | Domains, needed by every transaction: profiles as partitions of unity; payment, currency and reputation (history and relevance) attributed per domain, never crossing | B10, anti-halo isolation | first pass done |
| M3b | Profiles measured by currency metric models from causal signatures, not declared; prices per currency (resource cost less escrow upfront); spending only from the same currency; balance overflow into domain reinvestment | B6, B9, B10 | flat first pass done |
| M3c | Domain network (Ontology.Domain [R]): leaves hold shares, parents are fuzzy sets of leaves with μ learnt from memory; descent from matched parents; currencies eligible by accuracy threshold (novel leaves after a score-only phase, never below 0.5); fallback by μ; StandCoin lane at full resource cost with co-funding experts; novel leaves formed from clustered blockages; a noise parameter for every step | B6, B9, B10 | first pass done |
| M3d | Transactions and the behavioural transaction substrate: every action a transaction; each relevant currency's model generates a proposal (TP_Gen, L86); the actor composes them (L88); every executed action and outcome logged to memory and measured (L145); transaction trees with several contributors, causal contribution and distribution (L93–94); baseline negative pricing (L143); G as prices rather than a central chooser | B6, B9, `Conj_MinTracksPrediction` | next |
| M4 | Thresholds: significance thresholds per context, harm tiers by kind, floor quantile and other governed parameters inside the admissible region, perturbed by SigThGv | `Conj_ParamStability` | |
| M5 | Governance: weighted voting (base, domain expertise, impact), capped liquid delegation, debate on thresholds; the uncertainty margin on floors if ratified | `Conj_DelegationDispersed`, B11, B23 | |
| M6 | Malicious and gaming agents: inflating measured outcomes, profile gaming, exploit against reveal with bounties and clawbacks, model collusion, Sybil attempts against identity binding, informed falsehood, external aggressors | `Conj_GamingResistance`, `Conj_AdversarialRobustness`, `Conj_GoodhartReduction`, B1–B5, B18, B21 | |
| M7 | Population change: births, deaths, forks; teaching that shares understanding | `Conj_NoRepugnantDrift`, B15, B17, B19 | |
| M8 | Networks; propagation and leakage across games; end of lifespan and causal inheritance | B25 | |

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
parents are fuzzy sets of leaves with degrees μ (`aggregate_at_parent`). μ starts from the
bootstrap pattern (signature overlap) and is learnt from memory as fuzzy subsethood
(`Proposed.DomainHierarchy`), blended so evidence takes over from the prior. Classification
descends from matched parents to member leaves; pricing falls back from ineligible currencies to
eligible parents by μ, or to StandCoin; work only StandCoin would take pays its full resource
cost, is still screened by G on the best available model (qualified or not), and goes ahead if
the proposer, with experts, can pay. New top-level domains are not modelled (implausible). Tests: plans reach their true leaf;
parent reputation equals Σ μ × leaf reputation plus what stuck at the parent; memory recovers an
overlap degree; a hidden leaf forms, is scored but prices nothing until it qualifies, then takes
its work; when no currency qualifies, StandCoin work is screened (a harmful agent's almost never
passes, and what passes is measured beneficial), halts when unfunded, and is co-funded by experts; incremental reputation equals a recount; under every noise source at once
the books still balance.

3 parents of 4 known leaves (three with weak overlaps of 0.2–0.4 on a second parent) and two
hidden leaves under parents; 42 agents, three per leaf, sloppiness 0.3; 200 beings, 500 steps,
15 plans a step, marker noise 0.05; 5 seeds (about 7 s a run). Heavy noise: classification 0.08,
model bias 0.3, cost error 0.3, regeneration variability 0.5, memory loss 10%, expert
participation 50%.

| Reading | Formation | No formation | Formation, heavy noise |
|---|---|---|---|
| Novel leaves formed (none spurious) | 2 | 0 | 2 |
| Step of formation (mean) | 18 | n/a | 20 |
| Novel leaves qualifying within 500 steps | 5 of 10 | n/a | 3 of 10 |
| Score-only phase of those that qualified (steps) | 216 | n/a | 164 |
| Known work classified to its leaf | 100% | 100% | 84% |
| Error of learnt overlap degrees μ | 0.005 | 0.005 | 0.008 |
| StandCoin lane: executed, halted (per run) | 0, 0 | 0, 0 | 23, 71 |
| Floor growth, understanding | 36.3 | 34.4 | 29.8 |

Missing domains are found within about 20 steps and nothing spurious forms, even under heavy
noise; memory recovers overlap degrees almost exactly. The score-only phase is the bottleneck: a
novel leaf qualifies only as fast as its work is executed and scored, and work in a new domain is
a small share of activity, so half the novel leaves never qualify within 500 steps; meanwhile
their work is priced by the parent at coarse confidence, which is why formation changes how
often it is chosen very little. Under heavy noise, model bias costs some parents their
eligibility; their work falls to StandCoin, where three in four plans halt for lack of funds,
and floors grow 18% less.

Balance overflow trades reinvestment against spread of wealth (strict-tree version, 3 seeds):

| Base, factor | Share of net earnings reinvested | Gini of balances |
|---|---|---|
| 50, 0.5 | 84% | 0.18 |
| 200, 1.0 | 59% | 0.35 |
| 500, 1.0 (default) | 34% | 0.45 |
| 1,000, 1.0 | 11% | 0.53 |

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
| Resource accounting | `cost_σ` | 0 | 0–0.5 |
| Resource regeneration | `regen_σ` | 0 | 0–1 |
| Records reaching memory | `memory_loss` | 0 | 0–0.2 |
| Experts joining co-funding | `participation` | 1 | 0.3–1 |

Still without noise, to add as their rungs arrive: identity binding (M6), votes and delegation
(M5), threshold estimates (M4), transaction logging and composition (M3d).
