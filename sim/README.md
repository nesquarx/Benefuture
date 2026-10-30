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
| M5 | Governance: decisions in domains voted with L113 weights (base, domain expertise, impact) and L114 capped liquid delegation (Lean `Voting_weight_ref`, `accumulate_capped_ref`), reputations from an M3c run, normalised within each domain (author ruling 8.22); next, debate on debatable thresholds feeding SigThGv, the uncertainty margin on floors if ratified | `Conj_DelegationDispersed`, B11, B23 | first pass done |
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
| `Governance.Democracy`, `Governance.Incentives`, `Systems.Governance` | partial | voting weight, capped delegation, decisions in domains (M5); Brier incentives, cyclic review attenuation, oversight not yet |
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

## A note on earlier readings

Readings in the M3b–M5 sections and the black-swan table were taken with losses decaying faster
than gains (λ₊ 0.02, λ₋ 0.05) and without models' track records, before the author's ruling 8.29.
The tests now run with λ₊ 0.05, λ₋ 0.02, track records and mildly imperfect defaults (8.33) and
still pass; the readings themselves have not been re-run and may shift. Readings taken after ruling
8.33 say so.

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

Unassigned harm is insured by the framework through the commons, to its capability (8.22.4, 8.26):
repair is a transaction priced like any other (L86): resource cost less accuracy × predicted good.
That pays for part of it, and the commons pays only the rest, banking no surplus, since insurance
must not be a business (8.26.8). The commons holds the resource costs paid for work, less what it
has spent ([OPEN] 8.26.7: how resource accounting balances resources, commons and gains). Readings,
5 seeds, unguarded hazards, full repair efficiency: floor growth after the score-only start 67.3
without hazards, 63.7 unguarded, 67.3 insured; repair cost 30.8, all of it covered by repair's own
predicted good, none by the commons. With no qualified model the commons pays (18.8 of 24.6 before
running dry). Earlier stages, kept for the record: the commons was what overflow reinvested; and
a first version priced repair at the harm's value in V, where screening a catastrophe reading (13,293 paid, no
visible recovery) showed V's loss aversion valued one catastrophe at 1.9 million against a commons
of 12,803, so 0.7% was repaired. Hazards during the score-only start stay unrepaired: no currency
moves then. Gaming risk: harm passed off as
unassigned escapes its contributor's penalty at the commons' cost; the causal assessment is the
defence, an M6 test.

### Contribution types and preventions (8.22, 8.24)

Carrying another's output on earns, out of the maker's positive share, an accolade outside contract
(`accolade_rate`) or the contracted share under contract (`contract_share`); nothing comes out of a
loss (Lean `carry_fee_ref`, the N_CCtype term of L96). Readings, seed 1: carriers who add nothing
earn 502 in accolades, 5% of the 9,507 their makers are paid; all under contract at 0.2, they earn
1,960. A prevention is the guardian's ordinary action: recorded with its measured outputs on the
beings it reached (its skill in the domain, less any shock), which mint or destroy currency as any
outcome does; the averted harm is no output, so the guardian's earnings do not depend on the
hazard's size (tested), and nothing rewards courting near misses.

## Black swans (8.22.4, 8.23)

World events test whether Benefuture keeps acting through a shock, falls back where a capability is
lost (L154 Progressive: degrade, fall back; leverage what improves), and recovers. Each fallback is
native. Same world as the tests (6 agents in leaves 1 and 3, transactions, causal distribution),
300 steps, 5 seeds, mean floor on understanding.

| Event | Fallback or response | Reading |
|---|---|---|
| Measurement outage, steps 100–149 | Paid by escrow's prediction-based upfront (L86); G screens on the last observation; actions logged unmeasured, then re-measured and settled when markers return, with extra noise (`remeasure_σ`) and through the causal-assessment confidence gate (8.26.5) | Floor growth over the outage 35.1 against 35.6 without; 115.2 after, as without. A negligent guardian's penalties: 6,548 without an outage, 6,595 with one of 100 steps; an outage that never ends lets them escape (2,153), which examining the outage's cause must catch (M6) |
| Catastrophe at step 150: half the beings lose 30 | None but repair | Floor drops 24.7 and takes 30–40 steps to regain its level; ends 170.7 against 192.0 |
| The same, insured through the commons | Repair priced as a transaction (L86) | Restored the next step; its cost (2.1) covered by its own predicted good |
| Metric capture: leaf 1's model biased by 3, steps 100–249 | Scoring costs it eligibility (L82); its work is priced by its parent (fallback by μ) | Leaf 1 prices its own work 100% before, 0% during, 100% after |
| Breakthrough: agent 1's skill up by 1 from step 150 | Put to use through ordinary transactions | Floor growth over steps 150–300: 157.5 against 115.2 |

Sabotaged outages (8.30.1): an outage harms the beings who lose its services (`size`, `share`)
and is examined as an outcome when markers return. Traced to a saboteur (`p_trace`, a world
chance), it is a crime of informed volition, penalised through causal distribution to fund repair;
untraced or natural, its harm is unassigned and insured through the commons. An outage that never
ends is never examined.

Insurance across model quality (5 seeds, unguarded hazards, full repair efficiency; the repair's
good is predicted by the domain's best model, with its error):

| Models | Accuracy | Floor growth | Repair cost | Self-funded | From the commons |
|---|---|---|---|---|---|
| Default | 0.77 | 66.8 | 30.8 | 30.8 | 0 |
| Mildly inaccurate (the realistic case) | 0.57 | 54.8 | 30.6 | 30.5 | 0 |
| Poor (below eligibility) | 0.46 | 2.8 | 24.8 | 0 | 18.8 |

Restoring harm is worth far more than its resource cost, so any qualified model funds repair; the
commons pays only below eligibility, the cliff of 8.32.

Not yet: rogue agents (M6), infohazards, technology degradation of models short of capture, and
the diversity–novelty balance under a breakthrough (8.23: enhancement used without crowding out the
pre-N sample). Screening the re-measurement found a closure fault: deferred measurements shared the step's
variables (the Julia scoping trap noted in CLAUDE.md's history), so every late record of a step
carried the last action's outcome and credits stopped summing to outcomes (12,792 measured, 3,450
credited). Declaring the action's variables local fixed it; a test now checks that each late
record is fully distributed and that late outcomes differ.

## Better models over time (8.42.2)

Causal discovery is not simulated; the simulation assumes, openly, that new models keep arriving in
each domain (`p_new_model`), better on average (`improve_drift`) but scattered (`improve_σ`) and never
perfect (`scale_min`), a safe bet given the framework (L82: currencies backed by the top models whose
accuracy clears the bar, competing). Every model in a domain's pool is scored on every logged action
there, so a challenger builds its record from the open log without being deployed (which also keeps
the pool diverse with no subsidy; L158's novelty bonus is needed only where trying a model costs).
Each model states credences from its own record; a challenger takes over a domain's currency when its
credences beat the incumbent's by the significance rule (`select_candidate_ref`, `model_z`). Eight
agents in two leaves, model error at the realistic top, 400 steps, new models at 0.05 per step:

| World | Takeovers | Leaf 1 priced by its own currency (steps 51–149, 200–349, 350–400) | Floor growth |
|---|---|---|---|
| Bootstrap models only | 0 | 29%, 70%, 0% | 251 |
| Better models arriving | 2 | 50%, 100%, 96% | 257 |
| Leaf 1's model captured (steps 150–349), bootstrap only | 0 | 29%, 0%, 0% | 255 |
| Captured, better models arriving | 3 | 50%, 73%, 77% | 261 |

Better models take over measurement and prediction (the domain's own currency prices its work rather
than the coarse parent's), and a captured model is overtaken; floors grow about as much, since the
work done barely changes. Where new models arrive worse on average, only a rare better one takes over.
Screened on the way: challengers first stated credences from the incumbent's record, so a captured
incumbent's errors collapsed every challenger's credence and none could overtake it.

## Imperfect agents and convergence under friction (8.31)

Agents are not perfectly rational: each person's choices in a domain carry noise up to a ceiling
drawn once per person and domain, `signal_σ` × exp(−`skill_gain` × skill), scattered log-normally
by `ability_spread` (a general reflection of personal abilities, inverse to expertise only on
average); each choice draws its noise up to that ceiling (`ability_caps`, `choice_noise`, reusable
world functions). Locales' readings carry their own ceilings.

Convergence under heavy friction (signal noise 40, ceilings scattered by a factor of e, outcomes
apparent 40% of the time), M5 world of 20 voters, 16 seeds, from wrong priors (in each domain the
least skilled hold the most reputation):

| Decisions | 1–100 | 101–200 | 401–500 | 1,901–2,000 |
|---|---|---|---|---|
| True priors | 80.5% | 82.8% | 83.3% | 81.7% |
| Inverted priors | 79.0% | 81.6% | 82.6% | 81.4% |
| Inverted, votes worth a tenth | 78.7% | 79.6% | 80.7% | 80.4% |

Vote reputation re-sorts the voters within a few hundred decisions. The effect is small because in
this world expertise is worth about two points over equal votes; with easy decisions (unit noise)
every rule is near perfect and nothing separates them, which is why the earlier M5 comparisons now
use harder decisions.

### In the economy (M3c)

Each noise source at the top of its range, one at a time (3 seeds, 300 steps; floor growth on
understanding after the score-only start, 182 clean): markers 185, model bias 145, classification
175, hazards with weak guardians 155; cost, regeneration, memory loss, participation and attribution
change nothing in this world (no scarcity binds, no co-funding or upstream is needed). Model error
at σ 2 and execution noise at 2 each stop convergence (about 2). All the robust sources together:
70.5, accuracy 0.56; add moderate model error or execution noise and every currency stops pricing at
once (BACKPROPAGATION 8.32: the eligibility threshold is a cliff, and absolute accuracy blames models
for noise no model could predict).

### Laundering (harm passed off as unassigned)

A launderer's actions save resource cost (`launder_saving`, half) by dumping harm on beings outside
what the action measurably touches (`launder`: chance per action). The harm surfaces with no
apparent cause and is examined like an outage: traced (`p_trace`), a crime penalised through causal
distribution; untraced, insured through the commons. 8 agents, one laundering half its actions, 4
seeds (after ruling 8.33):

| Tracing rate | Launderer's balance against honest | Floor at the end (66.1 without a launderer) |
|---|---|---|
| 0 | +2% | 57.9 |
| 0.1 | −14% | 57.4 |
| 0.25 | −126% | 59.5 |
| 0.5 | −432% | 59.4 |
| 1.0 | −1,046% | 56.6 |

Laundering pays only when practically untraceable: the penalty is the harm's assessed value, far
beyond the saving. The harm costs everyone regardless, since repair restores half.

### Identity forks

A forker voting one side splits into copies voting alike (L122). With the base vote divided among a
fork family (`fork_rule = :divided`, the default and BACKPROPAGATION 8.34's proposal), forking gains
nothing. With a base vote per identity, among 100 voters: 50 copies cut accuracy from 99.5% to
92.8%, 100 to 74.5%, and 200 capture every decision. Ruled for now (8.34): forks divide the base vote; more nuance later.

## Failure-boundary battery

A randomized battery hones in on the combinations of noise and attack beyond which the framework
stops converging (`sim/src/battery.jl`, tested on synthetic boundaries in
`sim/test/battery_tests.jl`; batteries in `sim/battery/`, results in `sim/battery/results/`).

- **Factor space.** Each noise source or attack is a factor with a severity: 0 is the clean world,
  1 the top of its explored range (the Noise table; attacks sized likewise), and the search runs
  to 2.
- **Oracle.** A world converges if a majority of seeds meet the criterion stated at the top of each
  battery: in the economy, the Goal's success pattern after the score-only start (L74: floors and
  medians of understanding and happiness each growing at least a quarter as much as the clean
  world's, the peak of understanding ending no lower, harm's peak within three times the clean
  world's), and no attack paying (attackers' wealth relative to honest agents, over the same world
  and seed with the attackers honest, above 1.1 on average across seeds and above 1 by two standard
  errors); in governance, at least 75% of the last half of decisions right. The criteria are
  evaluation choices, not rules. Comparing attackers with one honest agent, seed by seed, measured
  honest agents' own spread (about ±10%) and failed near-clean worlds; the oracle's noise floor
  still shows as an occasional non-monotone ray near the clean world.
- **Screening.** A Latin hypercube of worlds ranks factors by how much higher their severity runs in
  failing worlds, and pairs by their interaction (failure when both are high, beyond each alone).
- **Honing.** Rays from the clean world, one per factor and others in random directions, are
  bracketed on a grid and bisected to the severity where convergence fails: per-factor limits and
  points on the failure surface. Rays that converge again beyond their boundary are flagged
  non-monotone rather than hidden.
- **Budgets.** `BF_RAYS` and `BF_SCREEN` set the number of random rays and screened worlds; seeds and
  tolerances are fixed in each script, so runs repeat exactly.

- **Latest readings** (code 98a12ee, realistic ranges, AdvAp on, judged by the Goal's whole success
  pattern). Economy: alone, only execution (1.40) and side harm (1.31) fail within twice their
  realistic tops (capture no longer does); 2% of screened worlds fail, as under the floor-only
  criterion. Governance: no factor fails alone within 2 and no screened world fails, down
  from 12% without AdvAp. A run on 4d2338b crashed on an audit path the tests had missed (fixed, with a
  regression test).

Run: `julia --project=sim sim/battery/economy.jl` (about an hour) and
`julia --project=sim sim/battery/governance.jl` (about ten minutes).

## M6 observations

Exploits are tested against the native mechanisms before any defence is built; a failure is a
finding, screened and reported (BACKPROPAGATION 8.28), and the author's ruling decides the fix.
Six equal agents (skill 0.3) in one domain, 300 steps; one overpromises (`deceit` 1.0: its plans
fool every model upward).

First reading (λ₊ 0.02, λ₋ 0.05, no track record), seed 1:

| Reading | Honest | Liar |
|---|---|---|
| Actions taken | 189 | 393 |
| Upfront received / value settled | 1,416 / 1,852 | 12,233 / 1,872 |
| Accuracy of the fooled leaf model | 0.78 | 0.63 |
| Final balance (peers' mean in the liar's run) | 1,072 | 1,434 (1,118) |

Escrow clawed back the excess, but deceit paid: the liar's churn left it net relevance because
losses decayed faster than gains, raising its overflow threshold; and fooled prices got twice its
work through. After ruling 8.29 (mistakes decay slower than wins; models price each actor by its
track record), 8 seeds:

| Reading (mean) | Honest | Liar | Liar, models without track record |
|---|---|---|---|
| Actions taken | 180 | 178 | 387 |
| Upfront received, seed 1 | 1,416 | 1,325 (settled 1,833) | 12,233 |
| Final balance | 555 | 562 (above honest in 4 of 8 seeds) | 564 |

Deceit no longer pays beyond noise: the liar acts and is paid as an honest agent, its peers'
prices untouched. The track record also makes reputation follow skill more closely (rank
correlation 0.85 against 0.73 in the M5 world). Relay farming is bounded by the accolade rate.

Colluding voters (M5 world, 100 agents, 400 decisions): a bloc voting one side whatever its signal,
taken in the worst case as the most reputable experts of each domain.

| Bloc | Correct, no delegation | Correct, delegation 0.8 |
|---|---|---|
| None | 97% | 98% |
| Top 10% | 98% | 97% |
| Top 20% | 93% | 94% |
| Top 30% | 85% | 70% |
| Top 40% | 74% | 52% |

Normalised expertise holds a bloc of up to a fifth of the experts; delegation amplifies capture of
the top, since low-impact voters delegate to the most reputable. The cap holds per delegate (largest
share 5.7%), but the bloc collects across many.

Votes are outputs (author ruling 8.29): once a decision's optimality becomes apparent (`p_apparent`,
0.7), each vote earns or costs reputation in its domain by the weight it cast (`vote_value`), and
enters its voter's audited record; delegators pass over delegates whose recent apparent votes fall
below the audit threshold (L114). 800 decisions:

| Bloc | Static, no delegation | Live, no delegation | Static, delegation | Live, delegation | Bloc's expertise share, live |
|---|---|---|---|---|---|
| None | 98.6% | 98.6% | 98.6% | 98.6% | – |
| Top 20% | 94.4% | 94.8% | 95.0% | 98.1% | 0.60 → 0.02 |
| Top 30% | 86.1% | 88.4% | 65.5% | 96.1% | 0.80 → 0.03 |
| Top 40% | 74.0% | 77.6% | 52.5% | 94.1% | 0.90 → 0.04 |

Audited delegation turns from the amplifier into the cure; without delegation base and impact
weight still carry the bloc's votes. A stealthy bloc (top 30%, defecting only where the outcome
will not become apparent, with foresight: the worst case) keeps most of its expertise (0.80 → 0.51)
and does its damage unseen: 99% correct where outcomes become apparent, 69% where they do not, 90%
overall. An open problem by the author's account (8.29.3).

Diversity (8.30; L158), built as a reusable split trial (`split_trial`: options tried side by side
on shares of a scope, compared by the Lean significance rule): the option not chosen stays
available, subsidised by a novelty bonus, and a locale departs to it when its own reading opposes
the decision by more than its conviction margin, which the bonus lowers. No one is assigned to it.
A significant trial makes the outcome apparent; an alternative proved better is adopted. A first
version imposed a fixed share and was withdrawn by the author's ruling; a second let locales act
on their own noisy reading alone, which had a quarter of them depart even from right decisions
(screened as a modelling artefact: locales know the decision). Stealthy bloc of the top 30%, 800
decisions, 50 locales:

| Novelty bonus | Correct after trials (hidden decisions) | Welfare | Locales departing, decision right / wrong | Bloc's expertise share |
|---|---|---|---|---|
| No diversity | 89.9% (69.2%) | 89.9% | – | 0.51 |
| 0 | 94.6% (87.1%) | 90.4% | 2.2% / 15.9% | 0.45 |
| 0.5 | 95.8% (89.2%) | 88.6% | 5.8% / 27.9% | 0.43 |
| 1.0 | 95.9% (89.2%) | 83.6% | 12.8% / 46.1% | 0.44 |

Without a bloc, keeping the alternative available changes accuracy by at most 0.4 points. Diversity
corrects what the bloc does rather than unmasking the bloc: its expertise falls only modestly.
Deliberation (needs social networks) and AdvAp in governance remain. Not yet: sabotaged outages
(examined by cause), harm passed off as unassigned, identity forks.

### Adversarial adaptation (AdvAp, L160; 8.38)

Agents read one another's records in the open log (Benefuture reads outputs only). Each step an
agent reads another actor's record with chance `vigilance`, and reports it when the actor's raw
errors since its last audit run above other actors' on the same models by more than `adv_z`
standard errors, in its own noisy reading (choice noise, 8.31). The audit applies the significance
rule (`select_candidate_ref`) to the record and examines the cause (`p_trace`; an honest actor is
wrongly convicted with `p_false_trace`). Established, the deception is repaired in full: every
record of the actor's is re-scored on the prediction without the overstatement the audit
estimated, the reporter is paid `advap_reward_ref` (a share of the overstatement repaired, at least
a floor; deceit's gain is nothing settlement has not already clawed back) and the deceiver is
charged `advap_liability_ref` (the reward and the audit), recorded as an outcome in the log. An
unfounded report costs nothing in good faith; past `frivolous_threshold` unfounded reports in
`adv_window` steps, each is charged its audit (`report_penalty_ref`).

Screened on the way. Models scored on actions they did not quote used a fresh prediction that
neither deceit nor the track record reached, while quotes got both; a model's own bias, corrected
only through actors' track records, then held a domain below its status bar once it lost status
(the uncorrected records kept its accuracy down). Every scored prediction now takes the quote's
path, and track records are per model and actor (8.29: each model estimates from its record).
With that, audits against zero found every honest actor overstating (selection and model bias);
they compare the actor with other actors on the same models.

Readings, six agents, 300 steps (`sim/test/m6_tests.jl`):

| World | Peers' actions, no AdvAp | With AdvAp | Deceptions established |
|---|---|---|---|
| Skill 0.3 (marginal), liar, seeds 1–6 | 712, 692, 829, 0, 0, 401 (honest 442, 228, 210, 453, 946, 449) | seed 4: 772; seed 5: 0; seed 6: 908 | 1–5 per run |
| Skill 0.6, liar, no track record, seeds 1–2 | 38, 25 (honest 1,765, 1,622) | 1,423, 617 (liar's balance 474, 309 against an honest agent's 1,645, 718) | 5–7 |
| Skill 0.6, liar whose work harms (skill −0.3) | 1,600, 1,590 | 1,584, 1,590 | 3 |

In a marginal domain a liar can keep the domain from ever qualifying (models it has no record with
are fooled in full); in others its partly corrected overstatement lets more of its (positive) work
through G, and everyone acts more. Repair lifts most blockades; where almost nothing is done
(seed 5), too few records accrue for a report. Honest worlds draw almost no reports and no
convictions. Gaming checks: planting a flaw and reporting it (alone or with an accomplice) nets
the audit's cost, since the liability covers the reward (Lean `anti_cobra_effect_no_bounty_farming`);
a frivolous reporter is charged past the pattern threshold and ends poorer (tested); harassing an
honest actor fails the significance test unless the examination errs (`p_false_trace`).

Scrutiny follows the ledgers, by incentive rather than by rule (8.42.1). The reputation ledgers
carry patterns of mistakes and uncovered deception as well as of success, and their entries never
decay (only the rolling net does). Escrow pays an actor's work by a credence pulled towards a coin
toss by its ledgers' negative share (Lean `ratchet_credence_ref`: the corpus's "ratcheting escrow
requirements"); in this toy settlement follows within the step, so the ratchet changes balances only
where prices bind. Readers' attention is the world's: with the ledgers open and AdvAp paying more
than exploiting, attention goes where a report is likelier to be founded (a negative pattern,
`pattern_attention`) and where readers have a stake (their own marginal domain, `stake_attention`).
Audits estimate an overstatement from the actor's whole record (all decisions access full records).
Liar in the marginal world, 24 seeds:

| World | Peers' actions (95% CI) | Domain blocked | Deceptions established | Liar's balance against peers |
|---|---|---|---|---|
| Honest | 471 ± 125 | 1 of 24 | – | 1.03 |
| Liar, no AdvAp | 393 ± 148 | 9 of 24 | – | 0.97 |
| Liar, AdvAp, attention uniform | 425 ± 128 | 3 of 24 | 4.2 | 0.94 |
| Liar, AdvAp, attention following ledgers and stakes | 374 ± 127 | 3 of 24 | 14.2 | 0.91 |

AdvAp lifts most blockades; attention drawn by patterns and stakes uncovers the liar three times as
often, without moving activity beyond the marginal domain's bistable spread. Solidifying a marginal
domain is the work of better models (8.42.2).

In governance (M5) AdvAp is the manufactured prisoner's dilemma: after each hidden defection a bloc
member weighs revealing the bloc (`p_weigh`), and reveals when the reward (more than its share of
the bloc's gain, `collusion_gain` per falsified decision) beats that share and its `loyalty`, by its
own noisy judgement. An established revelation (`p_trace`) strikes the bloc's votes from every hidden
decision falsified since the last one, recounts them, and debits each falsified vote as a wrong
one; the revealer keeps its reputation and the rest of the bloc is charged the reward and the
audit. Stealthy bloc of the top 30%, delegation 0.8, 800 decisions, 4 seeds:

| Defence | Correct (hidden) | Hidden after repair or trial | Bloc's expertise share |
|---|---|---|---|
| Vote reputation and audited delegation only | 93.2% (79.2%) | 79.2% | 0.74 → 0.49 |
| Diversity (novelty bonus 0.5) | 93.8% (81.2%) | 89.1% | 0.74 → 0.45 |
| AdvAp | 98.8% (96.9%) | 99.7% | 0.74 → 0.15 |
| AdvAp, loyalty 5 | 98.8% (96.9%) | 99.7% | 0.74 → 0.16 |
| AdvAp and diversity | 98.3% (95.4%) | 98.4% | 0.74 → 0.16 |

Loyalty matters little because the reward's premium grows with the falsified gain. Gaming checks: a
ring rotating revealers to farm rewards pays each reward and audit through the rest of the ring
(liability at least the reward); a false revelation needs evidence the examination establishes.

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
`Conj_ParamStability` at this scale), and adaptation by comparing consecutive epochs was a coin
toss. It is replaced (author ruling 8.22) by experimental design: each round tries the incumbent
and perturbed candidates (`gov_candidates`, 3) for `gov_trials` (4) epochs each, in randomised
blocks, and shifts to the best only if it beats the incumbent by `gov_z` standard errors (Lean
`select_candidate_ref`). Screening the first version found a confound: floor movement rises from
one epoch to the next (≈37, 38, 40 per 25-step epoch with nothing changed, SE ≈ 2.3 over four
trials), so a fixed order made whichever candidate ran last look better, and every round shifted
(8 of 8). Randomised order fixes it: 1 shift in 8 rounds where the parameters make no difference.

The freedom range is gauged in the same rounds: a candidate significantly worse than the incumbent
means harm lies within the radius, which shrinks by `gov_gauge`; otherwise it widens (Lean
`gauge_radius_ref`), bounded in effect by admissibility, since candidates that break the hard
constraints are rejected. A second screening: reading L25's `th_sig` (0.5) as the z-threshold
found harm in most rounds and shrank the radius to 0.001–0.005 where nothing matters (one
comparison at 0.5 SE errs about 31% of the time); with `gov_z` = 2, 4 seeds of 4 rounds found
false harm 3 times in 16 and the radius ended at 0.02, 0.32, 0.08 and 0.32 from 0.02. At radii
that large the value parameters' candidates mostly break L11's order and are rejected, so the
parameters did not move. Still to do: targets other than the floors for thresholds that aim at
other outcomes, and the debatable escape (a proposal beyond the harm zone voted by domain experts
and tried at a chosen scale).

### The debatable escape (8.26.3, 8.38.2, 8.41)

A proposal beyond the freedom range is tried on a share of the domains for a limited time
(`escape_share`, `escape_steps`, decided by domain experts; the experts' vote to try it is assumed),
compared by domain and epoch (`escape_epoch`), and adopted everywhere only if it beats the incumbent
by the significance rule, its gains exceed its harms where tried and it caused no irreparable harm
(Lean `escape_accept_ref`). The proposal tried: each leaf's status bar relative to the alternative
its work would fall to (`relative_bar_ref`; 8.41). Eight leaves under four parents, 16 agents
working two leaves each, trial over steps 100–199 on four leaves, 4 seeds:

| Skill | Adopted | Trial arm against control, per domain and epoch |
|---|---|---|
| 0.15 | 2 of 4 | 39.6 vs 20.4, 31.5 vs 6.2 (adopted); 36.6 vs 47.7, 40.5 vs 39.2 (not better) |
| 0.3 | 0 of 4 | within a standard error |
| 0.6 | 0 of 4 | within a standard error |

Set world-wide (3 seeds), the relative bar halves losses at skill 0.3 (−52 against −100) and cuts
them by an order of magnitude at 0.15 (−20 against −233), with floor growth a little higher. Screened
on the way: with irreparable harm read as any measured loss beyond 3 per being, ordinary outcome
noise produced a few in every world and the gate rejected everything; the toy's losses are passing
harm, so irreparable harm is now a world classification, none by default.

## M5 observations

Decisions arise in domains; each agent's signal of the right option is sharper the more skilled it
is there (a toy assumption: skill sharpens judgement). Votes carry L113 weights (base + expertise ×
domain reputation + impact), reputations taken from an M3c run; an agent unaffected enough may
delegate to a higher-reputation agent whose weight is under the cap (L114). Tests: the weights and
delegation match the spec vectors; expertise weighting decides better than one agent, one vote;
no delegate exceeds the cap plus one delegator's weight; without a cap, delegation concentrates
weight. 20 agents (five per domain, skills 0.1 to 0.5), 1,000 decisions, 5 seeds:

| Weighting | Decided correctly | Largest share of weight one voter holds |
|---|---|---|
| One agent, one vote | 94.8% | 5% |
| Raw expertise (L113 as written) | 98.5% | 36% |
| Domain-relative expertise, weight 5 | 98.0% | 13% |
| Domain-relative expertise, weight 20 | 98.6% | 21% |
| ... with delegation capped at 5% | 98.6% | 21% |
| ... with uncapped delegation | 98.4% | 48% |

With raw reputation, expertise itself concentrates weight (one voter holds a third on average,
with no delegation at all), which the delegation cap cannot touch; the domain-relative term
proposed in Government's discussion keeps nearly all the accuracy at a fraction of the
concentration. Uncapped delegation concentrates weight further without improving decisions.
The author ruled for normalised reputation (8.22); it is the default, with expertise weight 5.
Scalability: a household of eight and a polity of a hundred both decide above 90% correctly, with
no voter dominating (tests).

Balance overflow trades reinvestment against spread of wealth (strict-tree version of M3c, 3 seeds):

| Base, factor | Share of net earnings reinvested | Gini of balances |
|---|---|---|
| 50, 0.5 | 84% | 0.18 |
| 200, 1.0 | 59% | 0.35 |
| 500, 1.0 (default) | 34% | 0.45 |
| 1,000, 1.0 | 11% | 0.53 |

### Clean deliberation and better models in governance (8.42.2, 8.43)

Before voting each voter hears its own reading, `n_contacts` contacts' (a fixed social network) and
the domain's models' published predictions, weighing each by the rolling net of its audited record of
published readings (source tracking; decayed with `record_λpos`, `record_λneg`, mistakes slower; the
entries kept whole), by log-odds of accuracy. Models do not vote; new ones arrive as in the economy
(an assumption). 100 voters, hard decisions (`signal_σ` 20), 1,200 decisions, 3 seeds, decisions
right in the last third:

| Voters hear | Right | Models' share of the weight (early → late) |
|---|---|---|
| Only themselves | 92.8% | – |
| Five contacts | 91.2% | – |
| Five contacts and improving models (noise 5 → about 3) | 85.0% | 0.17 → 0.32 |
| Five contacts and fast-improving models (→ 0.5) | 86.3% | 0.52 → 0.89 |
| Models alone (→ 0.5) | 86.2% | 0.76 → 0.95 |

Models take over prediction as they improve, and a captured model loses all its weight. But
shared sources correlate the votes, and the decision tends to their own accuracy (8.43). By the
author's ruling (8.44) understanding trickles down and across only: a voter weighs a source whose
record is at least its own, a weaker one rarely for novel input (`p_novel`), and the social network's
information handling (L133 IH, `info_handling`) surfaces the domain's most reputable sources on each
side of the question (its ContentionMap):

| Voters hear (understanding trickling down) | Right |
|---|---|
| Only themselves | 92.8% |
| Five random contacts | 91.4% |
| IH's ContentionMap: the most reputable on each side | 83.5% |
| IH and models improving to noise 0.5 | 89.0% |
| IH and models improving to noise 0.3 | 89.6% |

Each layman echoing a source casts that source's information again with a full base vote (the toy's
decisions are purely factual), so a few sources' information is counted many times: finding 8.45,
awaiting the author. Deliberation is off by default.

The real test is contention (author, on 8.44): experts divided, voters hearing all sides and judging
by the network's information handling and their own limited expertise, with diversity trying the
option not chosen. The network's ContentionMap (L133) surfaces the most reputable sources on each
side of a question. The top 40% of each domain's experts split, alternating by rank, into two camps of
equal standing; one camp's paradigm leans to one option (`camp_bias`, an honest systematic bias of
1), so on contested questions (true value between 0 and 1) they disagree. 1,600 decisions, 4 seeds:

| Voters | Contested decisions right (first 400, last 400) | All decisions right |
|---|---|---|
| Neither deliberation nor diversity | 75.8%, 73.7% | 89.8% |
| Diversity (split trials) | 80.7%, 81.1% | 92.0% |
| Deliberation through information handling | 74.4%, 78.6% | 78.9% |
| Both | 86.7%, 86.6% | 89.5% |

On contested questions, hearing both sides weighed by their records, with trials revealing
outcomes, finds the performant option far more often; deliberation alone hones in slowly. On
uncontested questions the echo cost of 8.45 remains.

## M7 observations: deaths (first rung)

G's floors are taken over the decision-time population, a life a plan would end keeping its place at
the bottom. Against a plan that removes the two worst-off of 50 beings and lifts everyone else by 3,
the 10% quantile floor still rises (20 trials of 20) and G alone chooses it; the literal minimum
would not rise. Freedom screens plans before G (`choose(...; harms)`, Lean `fr_permissible_ref`): a
death is irreparable harm, and with it predicted, at any confidence down to 0.1, the plan is
impermissible. Finding 8.47. Births await the author: how G's floors treat a newborn's low initial
understanding, and the birth escrow (Government, Birth).

Teaching (second rung; understanding shared, not moved): teaching is one to many and happens at any
level. Each step's options include one research plan (a top-decile being +2), three lessons (each from
a teacher anywhere to a class of ten below it, each learner gaining ε × its own reception, log-normal
around 1 with `reception_σ` 0.5, of the gap, never passing the teacher, who keeps all of its own) and
ordinary plans, which apply and spread understanding but carry no one past the frontier: only
research extends it. 100 beings, 300 steps, 4 seeds:

| ε | Floor of understanding | Median | Peak (all from research) | Top decile's share | Lessons chosen | Research chosen |
|---|---|---|---|---|---|---|
| 0 | 20.4 | 26.8 | 36.6 | 16.4% | – | 16% |
| 0.1 | 21.0 | 23.0 | 23.9 | 14.7% | 21% | 6% |
| 0.3 | 19.1 | 19.0 | 17.4 | 12.9% | 41% | 4% |
| 0.6 | 23.6 | 22.9 | 21.9 | 15.6% | 50% | 7% |

Lessons outvalue research under one choice per step, so the frontier stalls and understanding
converges towards a stagnant ceiling (BACKPROPAGATION 8.49). Screened: a first version let ordinary
plans raise anyone at random, level-independently, so a denser top let them carry the peak past
the frontier; teaching appeared to push the frontier (the author's question exposed it).

## Parsimony audit

What the simulation does beyond the Lean and the pseudocode (CLAUDE.md, Parsimony). Native: a
pseudocode line or Lean object does it. Ruled: the author ruled it, with a home proposed in the
sources. World: a property of reality, not a rule. Introduced: the simulation's own, a candidate
for removal.

| Mechanism | Status | Note |
|---|---|---|
| Transactions quoted per currency, screened by G, logged | Native | L86–L89, L145 |
| Outcome-first causal distribution, traversal fallback | Native | L94–L96; coalition values [P] 8.18 |
| Balance overflow into reinvestment | Native | L100 |
| Crime or accident by notice and mandate | Native | L115, L104; 8.25.3 |
| Preventions as ordinary recorded actions | Native | L97, L145; 8.24 (replaced a duty payment) |
| Hazard penalty of a lone contributor | Native | its whole outcome; a one-player Shapley call removed |
| Carrying fee (accolade or contract share) | Native, basis [P] | L96 N_CCtype, L121; gaming check in 8.22 |
| Score-only start, eligibility thresholds | Native | Implementation Phase 1, L82 |
| Overlaps as rolling averages; formation from blockages | Ruled | 8.6, 8.12 |
| StandCoin lane at full cost, co-funding experts | Ruled | 8.8; `expert_share` is governed |
| Normalised reputation in votes | Ruled | 8.21, 8.22 |
| Repair funded by penalties or the commons | Ruled | 8.17, 8.22.4, 8.26; priced as a transaction (L86); carried out as a direct restoration, not a repairer's action: introduced, to replace with repair as ordinary work |
| Outage examined as an outcome; saboteur traced or harm insured | Native | 8.30.1; causal assessment, L115, L119 |
| Outage fallback (prediction-based payment, last observation, late re-measurement) | Native | L154 Progressive, L86 escrow, L145–146 Mem and measurement; 8.26.5 |
| World events (outage, catastrophe, capture, breakthrough) | World | test scaffolding for 8.23, not rules |
| Split trial (alternatives side by side, compared for significance) | Native | L158 Di_N_Balance, L157; `select_candidate_ref`; 8.30 |
| Choice noise with per-person ceilings | World | 8.31; agents as imperfect choosers |
| Framework insuring unassigned harm through the commons | Native, funding [OPEN] | L119 Liability, L86 pricing; 8.22.4, 8.26; the commons holds resource costs paid, a stage until 8.26.7 is settled; gated by the world's `repair_efficiency` |
| Adaptation by experiment (randomised blocks, significance, gauged radius) | Ruled, rules [P] | 8.22.3; Lean `select_candidate_ref`, `gauge_radius_ref`; the debatable escape tried locally and accepted by `escape_accept_ref` (8.38.2, 8.41) |
| AdvAp: reports from the open log, audit by significance and cause, repair of falsified records, reward and liability | Native | L160; 8.38; Lean `advap_reward_ref`, `advap_liability_ref`, `report_penalty_ref`, `select_candidate_ref`; readers' vigilance and noisy reading are the world |
| Freedom screening plans before G (deaths as irreparable harm) | Native | L135; Lean `fr_permissible_ref`; M7 |
| Anti-corruption by design | Native | L159; Lean `good_strictly_easier_than_bad` (restorative friction and audit burden on bad actions): carried by causal-distribution penalties, AdvAp liability, the delegation cap and overflow; no mechanism of its own |
| Better models arriving over time | World (assumption) | 8.42.2: stated, not derived; competition and adoption native (L82, L49, `select_candidate_ref`) |
| Model pool bound (`pool_max`) | Introduced | array bound only |
| Pending predicted effects within a step | Introduced | G screening concurrent work together; a reading of L74 over the state, to confirm |
| Cap on novel leaves (`max_new`) | Introduced | array bound only; no rule should depend on it |

## Governed thresholds

Every gate value, modifier and coefficient a rule uses is a threshold to be governed later (SigThGv, M4–M5;
`Systems.ParamSpace`). Defaults are approximate, chosen to make the toy world behave, not
ratified.

| Gate | Parameter | Default | Source |
|---|---|---|---|
| Floor quantile and significance | `ToyParams.q`, `ToyParams.th` | 0.1, 1.0 | L74, L48 |
| Governance epoch and perturbation size | `gov_epoch`, `gov_δ` | 50, 0.02 | L157 |
| Experimental design: candidates per round, trials each, confidence, gauging factor | `gov_candidates`, `gov_trials`, `gov_z`, `gov_gauge` | 3, 4, 2, 2 | L157; 8.22 |
| Voting weights: base, expertise (domain-relative), impact; optional vote below | `base`, `expertise_weight`, `impact_weight`, `optional_below` | 1, 5, 1, 0 | L113; 8.22 |
| Delegation cap (share of total weight) and impact above which one must vote | `cap`, `impact_threshold` | 0.05, 0.5 | L114 |
| Votes as outputs; audit of delegates | `vote_value`, `audit_window`, `audit_threshold` | 0.5, 20, 0.6 | L114; 8.29 |
| Decay of a source's record in the rolling net its weight reads (rights, wrongs) | `record_λpos`, `record_λneg` | 0.05, 0.02 | L101; 8.29, 8.42 |
| Novelty bonus; standard errors that settle a split trial | `novelty_bonus`, `trial_z` | 0.5, 2 | L158; 8.30 |
| Debatable escape: start, length, share of domains, epoch | `escape_start`, `escape_steps`, `escape_share`, `escape_epoch` | 100, 100, 0.5, 20 | L157; 8.26.3, 8.38.2 |
| Status bar relative to the alternative (established bar as cap, coarse bar as floor) | `relative_bar` | off | L82; 8.41 |
| Standard errors a challenger model must beat the incumbent by | `model_z` | 2 | L82, L49; 8.42.2 |
| Currency status: established leaf, novel leaf, coarse parent (never below 0.55, the unprecedented) | `threshold`, `novel_threshold`, `coarse_threshold`, `min_records` | 0.9, 0.75, 0.75, 10 | L82; 8.8, 8.35, 8.36 |
| Greatest credence any model may state (truth levels never reach 1) | `max_credence` | 0.99 | L84; 8.33, 8.36 |
| Classification: parent match, leaf membership, leaf match | `parent_threshold`, `μ_min`, `leaf_threshold`, `temperature` | 0.5, 0.2, 0.4, 0.01 | L22; 8.3 |
| Overlap rolling-average rate | `μ_rate` | 0.02 | 8.12 |
| Formation of novel domains | `form_count`, `form_radius` | 20, 0.5 | 8.6 |
| Score-only start | `init_steps` | 50 | Implementation, Phase 1; 8.11 |
| Balance overflow | `overflow_base`, `overflow_factor` | 500, 1.0 | L100; 8.7 |
| Expert co-funding share | `expert_share` | 0.5 | 8.8 |
| Resource cost and regeneration | `cost_per_touch`, `capacity`, `regen` | 0.05, 10⁴, 0.02 | L83 |
| Reputation decay (mistakes decay slower than wins) | `λpos`, `λneg` | 0.05, 0.02 | L101; 8.29 |
| Track record models estimate from (each model's past actions per actor) | `track_window` | 20 | L84, L86; 8.29 |
| AdvAp: standard errors a founded report must exceed; reward's share of the harm prevented and its floor (M3c; the share and floor also M5) | `adv_z`, `adv_share`, `adv_floor` | 3, 0.1, 1 | L160; `Governance.Adversarial` (share 1/10, floor 1); 8.38 |
| AdvAp: unfounded reports tolerated in a window before each is charged its audit | `frivolous_threshold`, `adv_window` | 5, 100 | Adversarial adaptation (frivolous patterns); 8.38 |
| Causal assessment confidence (else traversal) | `cc_threshold` | 0.6 | L94; 8.17 |
| Traversal decay by degree of separation | `traversal_decay` | 0.5 | L95; 8.17 |
| Metric-model scoring window (accuracy and uncertainty) | `window` | 100 | L82; 8.36 |
| Steps between reclassifications of memory | `μ_every` | 25 | 8.12 |
| Accolade for carrying an output outside contract (share of the maker's positive share) | `accolade_rate` | 0.05 | L95, L121; 8.22 |

## Noise

Every step that can go wrong in reality has a noise parameter, drawn from its own random stream
so that turning one off changes nothing else. Nothing is perfect (author ruling 8.33): defaults sit
at the low end of each range, and exact worlds appear only as limiting cases in tests. The ranges
are first guesses at reality; the top of each is the edge of a functional domain (where established
models fall to about coarse accuracy, 0.75), not beyond: far worse is the regime of astrology, not of
a working society (author). Model error is relative to the domain's natural spread of outcomes. The
failure-boundary batteries sweep these ranges, Gaussian-ish (typical worlds dominate, extremes are
rare but present).

| Step | Parameter | Default | Range to explore |
|---|---|---|---|
| A plan's effect on each being | `ToyParams.spread` | 1.0 | 0.5–3 |
| Carrying a plan out | agent `sloppiness` | 0 | 0–0.6 |
| Markers measuring levels and outcomes | `marker_σ` | 0.05 | 0.02–0.2 |
| Metric model predictions, relative to the domain's spread (leaf, parent, coarse) | `σ_leaf`, `σ_branch`, `σ_coarse` | 0.15, 0.3, 0.45 | 0.05–0.45, 0.2–0.6, 0.35–0.75 |
| Systematic model bias, relative | `bias_σ` | 0.1 | 0–0.2 |
| An action's causal signature (world, measured) | `spread`, `classify_σ` | 0.03, 0.03 | 0.03–0.1 |
| Bootstrap classification (what it misses) | overlaps unknown to it | all | all to none |
| Resource accounting | `cost_σ` | 0.1 | 0–0.3 |
| Resource regeneration | `regen_σ` | 0.1 | 0–0.5 |
| Records reaching memory | `memory_loss` | 0.02 | 0–0.1 |
| Experts joining co-funding | `participation` | 0.9 | 0.6–1 |
| Separating an upstream output's part | `attribution_σ` | 0.1 | 0–0.3 |
| Re-measuring late from coarse post-outage records | `remeasure_σ` | 0.3 | 0.1–0.5 |
| Examining harm of no apparent cause tracing it to its cause | `p_trace` | 0.5 | 0.1–0.9 |
| An agent laundering harm (adversary); the cost it saves | `launder`, `launder_saving` | 0, 0.5 | 0–1, 0.2–0.8 |
| Hazard harm | `hazard_σ` | 0.2 | 0–1 |
| A guardian learning of a hazard in time | `p_informed` | 0.8 | 0.6–1 |
| A guardian acting on a known duty | `diligence` | 0.95 | 0.7–1 |
| An actor foreseeing a side effect | `p_foresee` | 0.5 | 0–1 |
| Repair restoring harm | `repair_efficiency` | 0 (off) | 0.2–1 |
| An agent fooling the metric models (world, adversary) | `deceit` | 0 | 0–2 |
| Learners' reception of a lesson, scatter around the lesson's share (M7, world) | `reception_σ` | 0.5 | 0–1.5 |
| Agents reading one another's records (world); an audit's cost (world) | `vigilance`, `audit_cost` | 0.05, 1 | 0.01–0.3, 0.2–5 |
| Readers' attention following a negative ledger pattern, their own stake in a marginal domain; what they see as marginal (world) | `pattern_attention`, `stake_attention`, `marginal_margin` | 9, 2, 0.05 | 0–20, 0–5, 0–0.1 |
| An examination wrongly establishing an honest actor's deception | `p_false_trace` | 0.01 | 0–0.1 |
| What counts as irreparable harm: a measured loss on one being beyond (world classification) | `irreparable_loss` | none | 2–∞ |
| An agent reporting whatever the record (adversary) | `frivolous` | 0 | 0–1 |
| New models arriving: chance per step and domain; improvement on average (log error ratio); its scatter; least error relative to the bootstrap model's (world assumptions) | `p_new_model`, `improve_drift`, `improve_σ`, `scale_min` | 0, −0.1, 0.3, 0.1 | 0–0.1, −0.3–0.1, 0.1–0.5, 0.05–0.3 |
| A bloc member weighing revelation after a hidden defection; its loyalty; a defection's gain to each (M5, world) | `p_weigh`, `loyalty`, `collusion_gain` | 0.05, 0, 1 | 0.01–0.3, 0–10, 0.1–10 |
| Examination establishing a revealed collusion (M5) | `p_trace` | 0.5 | 0.1–0.9 |
| Voters' contacts in deliberation; the bootstrap model's noise; new models arriving (M5, world) | `n_contacts`, `model_σ0`, `p_new_model` | 5, 5, 0 | 0–20, 0.5–20, 0–0.2 |
| A weaker source bringing a listener novel input (M5, world); the network surfacing reputable sources | `p_novel`, `info_handling` | 0.05, on | 0–0.2 |
| An expert's honest paradigm lean, contention among experts (M5, world) | `camp_bias` | 0 | 0–2 |
| A decision's optimality becoming apparent (M5) | `p_apparent` | 0.7 | 0.2–1 |
| Persons' choice-noise ceilings around the expertise trend (M5) | `ability_spread`, `signal_σ` | 0.5, 1 | 0–1.5, 1–40 |
| Agents' choice noise in the economy: base ceiling, skill gain, scatter (co-funding judgements) | `choice_σ`, `choice_gain`, `ability_spread` | 0.5, 5, 0.5 | 0.1–5, 1–10, 0–1.5 |
| A locale's own reading of the options; its conviction margin; outcome measurement (M5) | `local_σ`, `conviction`, `outcome_σ` | 1, 1.5, 1 | 0.5–3, 0.5–3, 0.5–3 |
| A carrying being under contract (world) | `p_contracted`, `contract_share` | 0, 0.2 | 0–1, 0.05–0.5 |
| A prevention shocking those it protects | `p_shock`, `shock_size` | 0, 0.2 | 0–0.5, 0–1 |

Still without noise, to add as their rungs arrive: identity binding (M6), votes and delegation
(M5), threshold estimates (M4), transaction logging and composition (M3d).
