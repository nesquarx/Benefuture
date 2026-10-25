# Conjectures for Simulation

Behavioural claims made by the pseudocode and articles that simulation can test, with a measurable
form, and what Lean already settles. "Lean" marks claims whose *mechanism* is proved for every
admissible parameter point; the sim then tests the dynamics or the empirical inputs the proof assumes.
`Conj_*` names refer to `Benefuture.Systems.Conjectures`.

## A. Claims stated in the sources

### Measurement and metric models

| # | Claim | Source | Measurable form | Status |
|---|---|---|---|---|
| A1 | Competition converges in value *amplitudes* toward truth, while model *approaches* do not collapse into one | Critique addressal (Goodhart/convergence) | adopted-model accuracy → best; effective number of distinct model families stays above a floor | `Conj_MMCompetitionConverges` covers only the first half |
| A2 | Competing models keep Goodhart in check | Critique addressal; Benefuture currency | latent–observed gap non-increasing under optimisation pressure | `Conj_GoodhartReduction` |
| A3 | Anti-herding: correlated models add little confidence | System Design (Anti-herding) | inject k correlated clones; aggregate confidence rises ≪ k-fold | new |
| A4 | Sunset clause retires dominated models; low entry barrier keeps the market efficient | Measurement (Sunset, Entry) | dominated-model survival time; entrant success rate | new |
| A5 | Established markers prevent circular reinforcement | Measurement (Primacy of markers) | ablate markers → measure drift of latent–observed gap | new |
| A6 | Bootstrap bias decays under evolutionary pressure but has a non-zero floor | Benefuture currency; System Design | bias(t) decreasing, lim > 0 | new |

### Adversarial adaptation and antifragility

| # | Claim | Source | Measurable form | Status |
|---|---|---|---|---|
| A7 | Revealing flaws pays more than exploiting them, so exploitation falls | Introduction; System Design; L160 | exploit rate and payoff gap over time | `Conj_GamingResistance` |
| A8 | Bounty farming is deterred | Adversarial adaptation; L160 | farming payoff < 0 at realistic detection p | Lean (conditional on p > B/C); sim estimates p |
| A9 | Systems strengthen under attack | System Design (Antifragility) | post-attack performance > pre-attack | new |
| A10 | Harm_Intv: non-falling harm triggers intervention, so harm trends down | L150 | harm trend after interventions | Lean (trigger); sim (trend) |
| A11 | Rc_Innovation: non-falling resource use triggers innovation, so resource use per value falls | L151 | RA(t) trend | new |
| A12 | Graceful degradation: under degraded context, goal performance degrades smoothly, not catastrophically | L154–156; Progressive complexity | G vs. context-degradation curve | new |
| A13 | Required trust decreases layer by layer | L161 | required trust per layer | new |

### Economy

| # | Claim | Source | Measurable form | Status |
|---|---|---|---|---|
| A14 | No direct exchange prevents arbitrage, speculation and a meta-currency | Benefuture currency (No Direct Exchange) | profitable cycles; emergence of a dominant medium | new |
| A15 | Implicit exchange rates emerge and track resource efficiency | Benefuture currency (Implicit Exchange) | correlation of emergent rates with value/resource | new |
| A16 | Endogenous supply removes inflation/deflation mechanisms | Benefuture currency (Supply Stability) | price-level variance vs. fiat baseline | Lean (accounting identity); sim (stability) |
| A17 | Resource costs prevent costless cycling | Benefuture currency | net gain of transaction cycles < 0 | Lean (`resource_use_without_good_burns`) |
| A18 | Prosocial currencies win; weak ones fade | Implementation prototype | currency share vs. measured U/H per resource | new |
| A19 | Escrow calibrates: over-estimators face rising escrow | Introduction; Benefuture currency | escrow ratio vs. calibration error | new |
| A20 | Balance overflow does not kill excellence incentives | Critique addressal (overflow) | output of top producers with/without overflow | new |
| A21 | Causal distribution credits indirect contributions, approximating Shapley values | Critique addressal (causal attribution) | CD vs. Shapley on small games | new |
| A22 | Fork factories gain nothing | Critique addressal (forks) | payoff of fork-heavy strategies ≤ baseline | new |
| A23 | Domain-locking prevents wealth → power conversion | Critique addressal | correlation of balance with influence | new |
| A24 | Compute-heavy models lose currency competition | Benefuture currency; L82 | share of heavy-model currencies | Lean (`heavier_model_less_efficient`); sim (dynamics) |

### Governance and reputation

| # | Claim | Source | Measurable form | Status |
|---|---|---|---|---|
| A25 | Delegation stays dispersed under the cap | L114; Government | max delegate share | Lean (bound); `Conj_DelegationDispersed` |
| A26 | Expertise-and-impact weighting decides better than one-person-one-vote or technocracy | Government; Critique addressal (epistocracy) | decision quality vs. baselines | new |
| A27 | Anti-corruption: making good easier than bad, with distributed power, reduces corruption | L159; Anti-Corruption | corruption rate | new |
| A28 | SigThGv settles thresholds without oscillation | L157 | parameter variance over time | Lean (drift bound); `Conj_ParamStability` |
| A29 | Domain-locked reputation (no halo/horn) allocates trust better | Domain; Reputation | trust-allocation accuracy vs. global reputation | new |
| A30 | Decay prevents coasting without cliff-edge punishment of sabbaticals | Critique addressal (decay) | reputation paths of active vs. paused agents | new |
| A31 | Anti-gerrymandering prevents domain-boundary manipulation | Domain | success rate of boundary attacks | new |
| A32 | Identity binding gives Sybil resistance | System Design; Critique addressal | Sybil attack success | Lean (pair attenuation); cycles ≥ 3 [OPEN] |

### Axiology and population

| # | Claim | Source | Measurable form | Status |
|---|---|---|---|---|
| A33 | Floors rise: median and floor of U and H increase | Benefuture goals (Goals 1–2) | min/median trajectories | `Conj_FloorsRise` |
| A34 | Wireheading is prevented | Introduction; Benefuture goals | share of value from peak-H strategies | Lean (tier weights); sim (dynamics) |
| A35 | The Repugnant Conclusion is blocked | Benefuture goals | mean H under population growth | `Conj_NoRepugnantDrift` |
| A36 | Convex harm prevents sacrificial (organ-harvest) trade-offs | Benefuture goals | such actions never chosen | Lean (`dominated_plan_not_chosen`, `removal_cannot_raise_floor`); sim (how often uplift dominates) |
| A37 | Quantile floors and saturation neutralise utility monsters | Benefuture goals | share captured by high-capacity agents | new |
| A38 | Diversity axiom prevents monoculture and stagnation | L158; Culture | cultural/model diversity; novelty injection after stagnation | new |
| A39 | Harm-propagating cultures die out; harmless ones persist | Critique addressal (imperialism) | survival by culture type | new |
| A40 | Understanding adapts away less than happiness | Introduction (Stability) | adaptation rates (agent-model assumption) | assumption, not testable in sim alone |
| A41 | Synergy selects actions that raise U and H together | Philosophy; Benefuture goals (Synergy Override) | share of chosen actions with joint gains | Lean (cross term); sim (frequency) |

### External relations

| # | Claim | Source | Measurable form | Status |
|---|---|---|---|---|
| A42 | Tit-for-tat with forgiveness performs well against a strategy zoo | Philosophy; Life in benefuture | tournament payoff | Lean (EHR properties); sim (tournament) |
| A43 | Outsiders' optimal strategy becomes accommodation | Implementation prototype (Deterrence) | outsider best response | new |
| A44 | Black markets are flagged and shrink | Implementation prototype | off-book volume | new |
| A45 | Truth-level verification makes disinformation fail | Implementation prototype; Government | belief accuracy under disinformation | new |
| A46 | Recognising iterated interaction raises cooperation | L136; Philosophy | cooperation rate with/without self-model | new |

## B. Missed by the sources: suggested conjectures

| # | Conjecture | Why it matters |
|---|---|---|
| B1 | **Salami-slicing:** splitting a harm into many sub-threshold pieces does not escape weighting | Significance is threshold-based (L25); Lean showed loss aversion only holds at or above threshold. An adversary could fragment harm below it. |
| B2 | **Pascal's mugging:** fabricated low-probability catastrophe claims cannot block actions | Fr prices P·severity with large irreparable multipliers. Bostrom, "Pascal's Mugging" (2009): tiny probabilities of huge stakes can dominate expected-value reasoning. |
| B3 | **Performative prediction:** predictions that change behaviour still converge | MM predictions set prices and escrow, which change what agents do. Perdomo et al., "Performative Prediction" (2020): when predictions influence outcomes, repeated retraining converges only under stability conditions. |
| B4 | **Model collusion:** diverse-looking models coordinating to Goodhart jointly are detected | Anti-herding targets correlation; a cartel can be decorrelated by design. |
| B5 | **Confidence gaming:** agents cannot understate confidence to keep harm below "established" | Fr turns on confidence; Brier scoring is proper (proved), but strategic misreporting under Fr is a different incentive. |
| B6 | **Reputation oligarchy:** reputation does not compound into lasting concentration of influence | Balance overflows but reputation does not, and reputation is the main source of influence (Critique addressal). |
| B7 | **Liveness:** the admissible set is rarely empty | Settled by Lean: inaction is always admissible (`inaction_admissible`), so G always chooses. Sim instead measures how often inaction is chosen (stagnation). |
| B8 | **Tunnel abuse:** NHa dips are mostly closed; non-closing ones are caught | `nonclosing_tunnel_triggers_harm_intv` guarantees detection, not prevention. |
| B9 | **Escrow solvency** under heavy-tailed outcomes | Rare large failures could exhaust holds. |
| B10 | **Domain proliferation:** low-friction sub-domain creation does not fragment measurement into sparsity | Domain evolution is low-friction to add, high-friction to remove. |
| B11 | **Governance capture inside the admissible region:** debate can move thresholds to harmful admissible values | Admissibility bounds structure, not wisdom; the drift bound covers perturbation, not debate. |
| B12 | **Novelty farming:** manufactured trivial novelty earns about zero | N's trivial tier is ≈ 0; within-life variety N(Se) could reward churn. |
| B13 | **Partial adoption:** Bf mechanisms keep their properties when coexisting with a fiat economy | Transition is where most frameworks fail (Critique addressal, transition). |
| B14 | **Noise robustness:** G's choices degrade smoothly as MM noise grows | Links measurement quality to decision quality directly. |
| B16 | **Fr emergence:** Fr-violating plans are rarely chosen although Fr does not filter G | Fr is a subgoal; the claim is that priorities produce it. Measure the share of chosen plans failing `fr_permissible`, and whether each is a tragic choice. |
| B17 | **Frontier compounding:** frontier U gains diffuse and compound, so convex W_U does not leave the floor behind | `frontier_u_preferred` is the static fixed-stock case; measure diffusion of frontier gains into later floor gains and the top-decile share as ε grows; refines A37. |
| B18 | **NHa relabelling:** harm relabelled as NHa to escape Ha_max does not pay | `ha_lt` excludes closing NHa dips; the incentive to label is new. |
| B19 | **Diversity flip point:** where γ·Σ N lets a large diverse population outweigh a small homogeneous one | Depends on γ, q and headcount; the opening Parfit case. |
| B15 | **Population size converges** under birth escrow and creation policies | Government (Birth) and the population-direction rules imply but do not state it. |

## C. Not testable by simulation

Claims that are value commitments or real-world empirical facts: understanding-first as a value
choice; cross-cultural convergence (Philosophy); real-world measurability of U/H; human acceptance.
These need argument, field data or pilots (Implementation prototype), not simulation.
