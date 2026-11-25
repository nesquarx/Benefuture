# World coverage: which mechanisms run together

Goal (author): more and more complete Benefuture worlds in which every mechanism works in tandem. This
record states, per mechanism of [`spec/Bf_Pseudocode.txt`](../spec/Bf_Pseudocode.txt), in which simulated
world it runs, which mechanisms never meet the economy and governance, and the order in which they can
be composed into one world. Evidence: [`sim/README.md`](../sim/README.md) (Coverage of the specification,
Parsimony audit, Governed thresholds), [`docs/PLAN.md`](PLAN.md) Part 2, [`docs/CLAIMS.md`](CLAIMS.md), and the
constructors and defaults in `sim/src/`. Counts are tallied from the table; recount them when a column changes.

## Worlds (columns)

| Column | World | Source | What it composes |
|---|---|---|---|
| M3c | `run_m3c` | [`m3c.jl`](../sim/src/m3c.jl) | Economy: domains, models, currencies, escrow, transactions, justice, AdvAp, identity binding (M3, M3b, M3d, M3e, M3f folded in) |
| M5 | `run_m5` | [`m5.jl`](../sim/src/m5.jl) | Governance: weighted votes, delegation, deliberation, diversity; reputations taken from an M3c trace |
| Cpl | `run_coupled` | [`coupled.jl`](../sim/src/coupled.jl) | M3c stepped in epochs under M5 governance and M4 threshold perturbation; `continuous = true` keeps one economy |
| M7 | `run_m7` (and `run_m7_traits`) | [`m7.jl`](../sim/src/m7.jl), [`understanding.jl`](../sim/src/understanding.jl) | Fixed population with teaching, research, G per entity, deaths, accession; no currency |
| M7p | `run_births`, `run_population_identities`, `run_population_world` | [`m7.jl`](../sim/src/m7.jl) | Births with escrow, graded personhood, forks and merges, teaching and research together |
| M8 | `run_m8` | [`m8.jl`](../sim/src/m8.jl) | Social network, extended-self morality, propagated liability, delegation cap, overflow, end-of-horizon conduct |
| IHz | `run_m8_ihz` | [`m8.jl`](../sim/src/m8.jl) | Gated access to information hazards against censorship and open access |
| Art | `run_m8_art`, `run_m8_art_confounders`, `run_m8_culture` | [`m8.jl`](../sim/src/m8.jl) | Art reception, confounder deconvolution, cultural diversity |
| Tru | `run_m8_truth` | [`m8.jl`](../sim/src/m8.jl) | Multi-hop truth level and rumour deduplication |
| EHR | `run_m8_ehr` | [`m8.jl`](../sim/src/m8.jl) | External aggressors, tit-for-tat, forgiveness |
| Enf | `run_m8_enforcement` | [`m8.jl`](../sim/src/m8.jl) | Contract screening, three-tier enforcement, continuity and harm intervention |

Other worlds are not mechanism-complete: `run_m0`..`run_m3b` (earlier rungs, each a special case of M3c),
`run_status_quo` ([`status_quo.jl`](../sim/src/status_quo.jl), the comparison arm), `run_programmes`
([`programmes.jl`](../sim/src/programmes.jl)), and the replay machinery ([`replay.jl`](../sim/src/replay.jl)).
The M8 worlds are self-contained toys: none calls M3c, M5 or M7, so they share no state with the economy.

## Cell codes

- **W**: on in the world's default path. For M3c, M5, M7 and the M8 worlds: on in the constructor default
  (a flag that is on but fires only when its inputs exist, such as hazards, is still W). For Cpl: on in the
  composed `:bf` builders (`world` in [`sim/battery/long_horizon.jl`](../sim/battery/long_horizon.jl),
  `coupled_world` in [`sim/battery/coupled_map.jl`](../sim/battery/coupled_map.jl)).
- **O**: reachable by a parameter but off by default (for Cpl: reachable through `econ` or `gov` but off in the composed builders).
- **-**: absent from that world.
- **Probe**: the mechanism exists only in isolated probes ([`probe_tests.jl`](../sim/test/probe_tests.jl)) and the
  batteries, in no world column.

## Coverage matrix

| # | Mechanism (pseudocode) | M3c | M5 | Cpl | M7 | M7p | M8 | IHz | Art | Tru | EHR | Enf | Probe |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Competing metric models, accuracy eligibility, decay rule (L82, 8.85) | W | O | W | - | - | - | - | - | - | - | - | |
| 2 | Model arrival, takeover, ratchet, extremist and colluding models (L82, 8.84, 8.58) | O | O | W | - | - | - | - | - | - | - | - | |
| 3 | Domain network: leaves, fuzzy parents, learnt overlaps, novel leaves (Ontology.Domain) | W | - | W | - | - | - | - | - | - | - | - | |
| 4 | Credence from record, empirical-Bayes rule (L84) | W | O | W | - | - | - | - | - | - | - | - | |
| 5 | Score-only start, convergence gate, legacy funder, shadow governance (Implementation Phase 1, 8.136) | O | - | O | - | - | - | - | - | - | - | - | |
| 6 | Resource cost, capacity, regeneration, scarcity price (L83) | W | - | W | - | - | - | - | - | - | - | - | |
| 7 | RA estimating domain, budget-bound issuance, commons reserve (L83, 8.133, 8.155) | O | - | O | - | - | - | - | - | - | - | - | |
| 8 | Probabilistic escrow and settlement (L84) | W | - | W | - | W | - | - | - | - | - | - | |
| 9 | TP_Gen quotes by every currency, TP*, transaction log (L85-91, L145) | O | - | W | - | - | - | - | - | - | - | - | |
| 10 | Cross-domain isolation, no cashing in (L93, 8.80) | W | - | W | - | - | - | - | - | - | - | - | |
| 11 | Causal contribution, direct transaction chains (L94-95, 8.16-8.18) | O | - | W | - | - | - | - | - | - | - | - | |
| 12 | Multi-hop transaction trees, degree attenuation (`upstream_depth` > 1, L95) | O | - | O | - | - | - | - | - | - | - | - | |
| 13 | Causal distribution, reward and penalty, supply minting and burning (L96-99) | O | - | W | - | - | - | - | - | - | - | - | |
| 14 | Reputation per domain, decay, recount, no halo or transfer (L100-101) | W | W | W | - | - | W | - | - | - | - | - | |
| 15 | Balance overflow, directed auto-invest (L103) | W | - | W | - | - | W | - | - | - | - | - | |
| 16 | Law, contracts, guardian duties, communicated laws (L104, L116) | O | - | W | - | - | - | - | - | - | - | W | |
| 17 | Crime versus accident by notice, accident cap, mandated education (L116, 8.157) | W | - | W | - | - | - | W | - | - | - | W | |
| 18 | Justice: repair from penalties, restorative, sanction escalation, rehabilitation (L117, 8.157) | O | - | W | - | - | - | - | - | - | - | W | |
| 19 | Responsibility four-factor reading, repair credit, accolade counterfactual (8.152, 8.26) | O | - | O | - | - | - | W | - | - | - | - | |
| 20 | Accolade for carrying good outputs (L122) | W | - | W | - | - | - | - | - | - | - | - | |
| 21 | Liability chain, power and influence concentration (L111, L120) | - | - | - | - | - | W | - | - | - | - | - | |
| 22 | Enforcement tiers, harm-bound screening, `CvCnt`, `Harm_Intv` (L121, L151, L153) | - | - | - | - | - | - | - | - | - | - | W | |
| 23 | External harm response (L118) | - | - | - | - | - | - | - | - | - | W | - | |
| 24 | BfDm vote weights: base, expertise, impact via synergy (L113, 8.158) | - | W | W | - | - | - | - | - | - | - | - | |
| 25 | LqdBfDm capped delegation with audits (L114) | - | O | W | - | - | W | - | - | - | - | - | |
| 26 | Credence ballots, correlated-ballot dedupe (L115, 8.121) | - | O | O | - | - | - | - | - | - | - | - | |
| 27 | SigThGv threshold perturbation, experimental design, debatable escape (L158, M4) | O | - | W | - | - | - | - | - | - | - | - | |
| 28 | Subsidiarity: nested scopes (8.150) | - | O | O | - | - | - | - | - | - | - | - | |
| 29 | Identity binding by Technology Network clusters (L18, L133, 8.70) | O | O | W | - | - | - | - | - | - | - | - | |
| 30 | Fork and merge of identities (L123-124, 8.34) | O | O | O | - | W | - | - | - | - | - | - | |
| 31 | Diversity: split trials, novelty bonus (L159) | - | W | W | W | - | - | - | - | - | - | - | |
| 32 | Culture, `Di_N` monoculture escape (L125, L159) | - | - | - | - | - | - | - | W | - | - | - | |
| 33 | Art: reception match, surplus value, confounders (L126-127) | - | - | - | - | - | - | - | W | - | - | - | |
| 34 | Information hazard gated access, no censorship (L128, L131) | - | - | - | - | - | - | W | - | - | - | - | |
| 35 | IH: source verification by record, ContentionMap, source tags (L134, 8.45, 8.60) | - | O | W | - | - | - | - | - | - | - | - | |
| 36 | IH: multi-hop truth level, count-once rumour suppression (L133-134, P28) | - | - | - | - | - | - | - | - | W | - | - | |
| 37 | IH: categorise truth levels, opinion, fact, hypothesis; fact check against Mem (L134) | - | - | - | - | - | - | - | - | - | - | - | |
| 38 | Education, critical thinking, inoculation (L130-131) | W | - | W | W | W | - | W | - | - | - | - | |
| 39 | Understanding by its equation, teaching, research (L31, 8.98) | - | - | - | W | W | - | - | - | - | - | - | |
| 40 | Goal G per entity on a noisy view (L74, 8.50) | W | - | W | W | W | - | - | - | - | - | - | |
| 41 | Deaths, lifespan window, long-term self (L67-70) | - | - | - | W | W | W | - | - | - | - | - | |
| 42 | Births with escrow, graded personhood, baseline shortfall (L71, 8.52) | - | - | - | - | W | - | - | - | - | - | - | |
| 43 | Accession and forced additions (8.86) | - | - | - | O | - | - | - | - | - | - | - | |
| 44 | Extended-self morality, end-of-horizon conduct, zero property inheritance (L137, B25) | - | - | - | - | - | W | - | - | - | - | - | |
| 45 | Freedom, harm boundary (L136) | O | - | O | W | - | - | W | - | - | - | W | |
| 46 | Hazards, side effects, black swans, breakthroughs (L151, L155) | O | O | W | O | - | W | - | - | - | - | - | |
| 47 | AdvAp: open-log audits, clawback, first-reporter reward (L161) | O | O | W | O | - | W | W | - | - | - | - | |
| 48 | Progressive degradation: fallback order, loud `degraded` trace (L155, 8.71-8.73) | W | - | W | - | - | - | - | - | - | - | - | |
| 49 | Predict, measure, adapt for proposals (8.134) | O | - | O | - | - | - | - | - | - | - | - | |
| 50 | Memory as immutable log, open-log recounts (L146-147, BTS) | W | O | W | - | - | W | - | - | - | - | - | |
| 51 | Axioms in probes only: `EmbeddedLaws` (L139), `Rc_Innovation` (L152), `TrustMin` (L162), `AntiCorruption` payoffs (L160) | - | - | - | - | - | - | - | - | - | - | - | P |
| 52 | Not modelled: baseline income SB (L144), SophontOversight SO (L142), Implementation Phase 2 and data tiers (L141), privacy (L133) | - | - | - | - | - | - | - | - | - | - | - | |

Reading notes for cells that need a reason:

- Rows 5, 7, 19, 49 stay O in Cpl after step 5 (2026-11-25): `dormant_flags` (`sim/battery/long_horizon.jl`; `dormant = true` in `world` and `coupled_world`) turns on budget-bound issuance with RA's horizon bound,
  the RA estimating domain with commons reserve and spend contraction, the converge gate with the legacy funder, `responsibility_reading`, `repair_credit`, `accolade_counterfactual` and proposal
  predict-measure-adapt together. It is not default in `:bf` because the budget bound makes deliverable capacity scarce, which changes the world every cached battery measured; flipping the default
  is a re-baselining decision. Shadow governance (row 5's last part) needs a candidate, so it stays with its own probe. Combined probe `P55` (`probe_tests.jl`), findings: no stall (`lane_halted = 0`, the gate opens
  within two epochs, the legacy funder carries the score-only start); the currency identity holds exactly with RA's bound as its last term (`balance + reinvested - endowed = supply + lane_supply - ra_withheld`,
  because the bound claws back claims above the horizon of deliverable value after `supply` logs them); under scarce regeneration the bound itself lowers the floor against an unbounded world (a resource limit, not
  a flag interaction) and the other flags add no further loss against the bound alone (z = 3, one-sided, 6 seeds); with ample regeneration the set loses nothing against flags off. No bug found.

- Row 35 is W in Cpl since step 1 (2026-11-23): the `:bf` builders (`ih = true`) turn on `deliberation`, `info_handling`, `source_tags`, `tag_audit` in `gov`,
  and `run_coupled` carries each source's record across epochs (`run_m5(...; records)`), so weights read live records, not a table reset each epoch.
  It acts on the M5 side-run (`gov_acc`); with `ih_vote` (on in `:bf`, 2026-11-23, M5Params field; off in a bare `run_coupled`) the candidate-adoption vote
  also reads through M5's deliberation (`run_m5(...; truths)`, the final readings `last_signal`), so IH reaches the economy and the Goal pattern. Probe
  `Probe: IH in the adoption vote ...` (`probe_heavy1_tests.jl`, smoke version in `probe_tests.jl`): with half the voters colluding liars and a harmful candidate (honest readings centred at -1),
  adoption per epoch falls from 1.00 to 0.65 (-0.35 +- 0.04, 8 paired seeds, z > 5) and the Goal pattern is not worse (+2.8 +- 1.2, at least 8 seeds needed for the bound;
  loss below 3 shown one-sided). Toy: the harm is a stated world property (`candidate_merit`), not read from the economy before adoption. Row 37 stays absent: `BenefutureReference` has the chain rule
  (`chain_truth_level_ref`) but no categoriser for ruling 8.167a.

- Rows 9-13 are O in M3c because `transactions`, `causal_distribution` and `p_upstream` default off in the constructor,
  and W in Cpl because the composed builders set them (`transactions = true`, `causal_distribution = true`, `p_upstream = 0.4`).
  `upstream_depth` stays at 1 in the composed builders.
- Rows 16 and 18: the composed builders set `guardians`, `p_hazard`, `p_side` and `repair_efficiency`; `p_contracted` stays 0, so contract-based duty is
  limited to guardians; `is_valid_contract` screening and the enforcement tiers run only in `run_m8_enforcement`.
- Row 35: `info_handling = true` and `tag_audit = true` are M5 defaults, but they act only when `deliberation = true`, which is off, so
  governance in Cpl votes without deliberation or IH. `source_tags` is off.
- Row 40: M3c screens proposals by G over the step's pending effects, a single-pool approximation that diverges from M7's concurrent per-entity
  G (README Parsimony audit: pending predicted effects).
- Row 47: M7 has a report-audit path (`claim_ratio`, `audited_ratio`) that is off unless supplied.
- Rows 41-44 and 21-23: no economy world holds beings that die, are born, or hold an extended self; M3c's agents are a fixed set with fixed skills.
- Row 51: each axiom has a probe in [`sim/test/probe_tests.jl`](../sim/test/probe_tests.jl); the table in sim/README.md (Antifragility axioms) is the authority on their status.
  The other axioms are carried by worlds: `Harm_Intv` and `CvCnt` by the Enf column, `Progressive` by row 48 and the progressive battery
  ([`sim/battery/progressive.jl`](../sim/battery/progressive.jl), which removes capabilities from a Cpl run), `SigThGv` by row 27, `Di_N_Balance` by rows 31-32, `AdvAp` by row 47.

### Counts per world

Rows 1-52 (row 51 groups four axioms; row 52 groups four unmodelled items).

| World | W | O | absent (of 52) |
|---|---|---|---|
| M3c | 14 | 17 | 21 |
| M5 | 3 | 12 | 37 |
| Cpl | 28 | 9 | 15 |
| M7 | 6 | 3 | 43 |
| M7p | 7 | 0 | 45 |
| M8 | 9 | 0 | 43 |
| IHz | 6 | 0 | 46 |
| Art | 2 | 0 | 50 |
| Tru | 1 | 0 | 51 |
| EHR | 1 | 0 | 51 |
| Enf | 5 | 0 | 47 |

One mechanism group (row 37, categorising truth levels and fact checking against Mem) appears in no world, four more (row 52) are not modelled,
and four axioms (row 51) live in probes alone.

## (1) Mechanisms that never run together with economy and governance

Absent from `run_coupled`, in any setting (neither W nor O):

| Group | Rows | Where it exists | Why it matters for the composed world |
|---|---|---|---|
| Population: deaths, births, personhood, teaching, research, accession | 39, 41-43 | M7, M7p | The economy's beings are a fixed set; understanding grows by a fixed `ε` and a toy regeneration, not by teaching and research |
| Liability chain, power and influence concentration | 21 | M8 | Transaction trees (row 12) and delegation (row 25) are the real graph this applies to, yet liability stops at guardians |
| Extended-self morality, B25 end-of-horizon conduct | 44 | M8 | Needs deaths first; would alter the finite-horizon defection that M3c's honest-record incentives price only through reputation |
| External harm response | 23 | EHR | Aggressors outside Benefuture have no identity, currency or reputation in M3c |
| Enforcement tiers, contract harm-bound screening, `CvCnt` in a world | 22 | Enf | M3c punishes through escrow, penalties and restraint but never screens contracts against the harm boundary or audits forcible restraint |
| Culture, art | 32-33 | Art | Art value and cultural diversity do not yet enter V or the economy's currencies |
| IHz gate and truth-level propagation, categorisation | 34, 36, 37 | IHz, Tru | Information handling in Cpl is M5's ContentionMap, source tags and tag audit (row 35, on in `:bf` since step 1, 2026-11-23) with no truth-level classifier (row 37) |
| Freedom as a reported quantity | 45 | M7, IHz, Enf | Cpl carries the harm boundary only through `irreparable_loss` (off) |
| Axioms in probes only; SB, SO, Phase 2, privacy | 51, 52 | probes, none | No world exercises them |

Reachable but off in the composed builders (O in Cpl): rows 5, 7, 12, 19, 26, 28, 30, 45, 49 (rows 5, 7, 19, 49 turn on together with `dormant = true` in `world` and `coupled_world`, step 5, `P55`; default off, see the reading note). Flipping them is composition work
without new rules, but each interacts with others, so each needs its own probe before it enters the full world.

## (2) Composition order toward one complete world

Each step extends `run_coupled` (continuous mode, composed `:bf` builders). Rule: a mechanism enters the full world only after its probe is green
(`sim/test/probe_tests.jl`; mechanism probes first). Each step names its probe, what it removes or keeps among toy assumptions, and the
interaction a success or a failure reveals. Predictions are stated when the step is briefed (predict, measure, adapt, 8.134).

| Step | Mechanism group | Couples to | Interaction it would reveal | Probe needed | Toy assumptions removed / kept |
|---|---|---|---|---|---|
| 1 | **IH in governance and the economy's claims** (row 35) [done 2026-11-23, see reading note under Counts; candidate-vote routing and row 37 open]: `deliberation`, `info_handling`, `source_tags`, `tag_audit` on in the Cpl `gov` builder; source weights read M3c reputations per domain | M3c reputation (row 14), M5 votes (24-25), AdvAp (47) | Whether record-weighted sources raise governance accuracy when the economy's reputations, not a stand-in, set the weights; whether echo-compounding (8.45) reappears under economy-driven reputation churn | Composition probe: Cpl continuous with deliberation on, tagged versus untagged, a tag-lying bloc; asserts no stall and the success pattern no worse | Removes: M5 reading reputations from a frozen trace. Keeps: contacts as a random graph, truth known to the world |
| 2 | **IH world: propagation and hazard access** (rows 34, 36, 37): `run_m8_truth` chain truth level and `count_once` over a social network that also supplies M5's contacts; `run_m8_ihz` gate on a hazard domain feeding M3c hazards and `mandate_education`; ContentionMap over the same network | M8 network (21), M5 contacts, M3c hazards and accidents (17), education (38), freedom (45) | Whether gated access keeps `Freedom(Tr)` while cutting uninoculated accidents inside the economy's own hazard stream; whether truth-level attenuation changes what governance hears | New IH-world probe: 24-40 beings on one network, one hazard domain, true and rumour signals, tens of steps, 3 seeds; acceptance: gated beats censored and open on harm plus access; counterexample: censorship fails freedom, open access raises uninformed harm | Removes: separate toy graphs in M5 and M8. Keeps: truth level as a world property; categorisation of opinion, fact and hypothesis (row 37) still a gap, noted loudly |
| 3 | **Ideological extremists spreading** (author ruling 8.166): recruitment changes others' outputs at a measured rate, on the IH world of step 2 only; speech never sanctioned, resulting harm priced by liability | IH world (step 2), liability (21), AdvAp (47), M5 votes | Whether IH keeps spread bounded without censorship; whether influence liability (not speech sanction) suffices | Spread probe on the IH world, paired with the same world minus handling as the control the ruling says is not a Benefuture claim; recruitment rate from persuasion data as a sweep, institution-produced rates as sweep only | Removes: extremism as stated-confidence inflation only (8.165). Keeps: opinion as a scalar |
| 4 | **Liability, influence and enforcement over transaction trees** (rows 12, 16, 21, 22): `upstream_depth` above 1, `propagated_liability` on trees, delegation cap, contract harm-bound screening, three enforcement tiers, `p_contracted` above 0 | M3c trees and justice (11-13, 18), M5 delegation (25), M8 Enf and M8 | Whether influence concentration among hubs and contracted duties change causal distribution; whether forcible restraint stays audited-only under noisy audits | Probe: a 6-10 agent tree with a hub, contract and a breach; acceptance: liability follows control, no double counting; counterexample: uncontrolled hub | Removes: M8's hand-built graphs and M3c's direct-parent-only chains. Keeps: control weights as a world parameter |
| 5 | **Dormant economy flags**: RA estimating domain, budget-bound issuance, commons reserve, converge gate with legacy funder and shadow governance, `responsibility_reading`, `repair_credit`, `accolade_counterfactual`, predict-measure-adapt for proposals (rows 5, 7, 19, 49) | M3c core, Cpl epochs, M4 | Whether RA's issuance bound and budgets interact with scarcity pricing and overflow (rows 6, 15); whether the converge gate stalls Cpl epochs | One probe per flag exists in part (`P30`, `P46`, RA probes); combined-flag probe `P55` [done 2026-11-25]: all on, 3 epochs, no stall, ledger identity holds, Goal pattern no worse than the bound alone; default-on awaits re-baselining | Removes: fixed capacity and ungated phase 1. Keeps: pool bounds and array bounds named in the Parsimony audit |
| 6 | **Population in the economy**: M7 deaths, then births and teaching and research (rows 39, 41-43) replacing the fixed beings of M3c; beings with graded personhood take part in votes (base vote by personhood) | M3c agents and balances (14-15), M5 base vote (24), M7p | What a death does to reputation, balances and open escrow; whether births before a causer's first settlement escape the ratchet (8.54-8.56); whether floors rise with a living population | Probe: `run_population_world` coupled to a 3-domain M3c with deaths and births; acceptance: floors, no repugnant drift, balances conserved; counterexample: removal cannot raise the floor | Removes: fixed population, fixed skills, fixed `ε`. Keeps: births endowment and baseline as a reading (SB not formalised); skills drawn, not learnt in the economy |
| 7 | **G per entity in the economy** (row 40): each agent runs its own noisy G, concurrently, replacing the pooled pending-effect screen in M3c | M3c screen, M7 chooser, step 6 | The divergence recorded in the Parsimony audit: concurrent entities double-spending the same capacity | Probe: two entities choosing plans that conflict on one resource; acceptance: both screened by their own G, capacity respected | Removes: single-pool screening. Keeps: shared state for pending effects only within a step |
| 8 | **Morality and B25** (row 44): extended-self feedback and end-of-horizon score, zero property inheritance with continuing `Self`, posthumous causal distribution and recounted reputation, on step 6's deaths | M8 `run_m8`, M3c balances, M5 | Whether finite-horizon defection returns in the economy once deaths exist; whether inheritance of causal and ideological shares carries | Probe: `P22`/`P24` worlds embedded into one dying M3c cohort | Removes: M8's own fixed payoff table. Keeps: couplings as a world graph |
| 9 | **Identity forks and merges in the population** (row 30) with binding clusters (row 29) | M7p forks, M3c binding, M5 per-identity base vote | Whether forking a being splits liability overflow and votes without cashing in | Probe: fork of a being with reputation, balance and an open escrow; acceptance: totals conserved, binding rejects whitewash | Removes: separate fork stories in three worlds. Keeps: attestation skill as a cluster property |
| 10 | **Art and culture** (rows 32-33): art surplus enters V as `Tr_lvl(U) + N` and culture diversity as the monoculture signal for `Di_N_Balance` | M8 Art, M5 diversity (31), V | Whether art value distorts currencies (art measured by reception, not by an outcome the economy prices) | Probe: art domain in M3c with confounded reception | Removes: art as an isolated reception world. Keeps: reception spread as a toy of cultural transmission |
| 11 | **External aggressors** (row 23): external actors without Benefuture identity act on the composed world; response proportional, reparable-only | M8 EHR, M3c reputation, Enf | Whether external harm response needs a currency or reputation for non-members | Probe: aggressor with attack harm against a Cpl economy | Keeps: externals as scripted actors |
| 12 | **Axioms into worlds and what is not modelled**: `EmbeddedLaws`, `Rc_Innovation`, `TrustMin`, `AntiCorruption` payoffs from probes to the run; then SB, SO, Phase 2 and data tiers, privacy (row 52) | all | The meta layer: whether the axioms' triggers fire inside a composed run and their responses stay inside the harm boundary | One probe per axiom already; add an "axioms fire in the composed run" probe; SB, SO and tiers need the pseudocode extended first | Removes: probe-only status. Keeps: SB, SO, tiers as open until ruled |

After step 6 the composed world supports the century battery (author ruling 8.64): economy 10 years, governance 20, catastrophes and
breakthroughs at converted realistic frequencies.

Why this order: steps 1-3 follow ruling 8.166 (spread only in an IH world), and step 1 is nearly free because M5 already carries the IH
mechanisms (flags only). Steps 4-5 raise the economy's own coverage with mechanisms that already run in isolation and need no population.
Steps 6-8 form one chain (population, then G per entity, then morality), because B25 needs deaths and G per entity needs a living cast.
Steps 9-12 are less coupled and can proceed in parallel once step 6 is green.

Step 2a status (2026-11-24, `P52`): the categoriser `ih_truth_level_ref` and a claim-stream world `run_ih_claims` (provable flag per claim, infrastructure event) are green in a probe. Step 2b status (2026-11-24, `P53`): `run_ih_world` composes the claim stream, the M5 society and the economy on one network: `run_m8_truth` (echoed rumours) sets the share of voters who defer to what they hear, each claim is an M5 decision whose readings (records carried from claim to claim, a record only where checkable) go through `ih_truth_level`, `run_m8_ihz` sets the economy's side-effect hazard chance and decision accuracy its guardian-informed chance, and M3c runs on them. Result (16 seeds, paired): where lies bite (noisy voters, deferring) IH raises decision accuracy +0.22 +- 0.02 (z 9, above the z = 3 bar); in the default regime (accurate voters) accuracy is at a ceiling and the difference is +0.003 +- 0.003, no loss within 0.05 (the lead's 'effect detected' prediction holds only in the first regime, not the default). Payoff, the economy's floor of understanding and harm's peak lose less than 3 one-sided. Not wired: the M8 truth and IHz toy worlds feed one number each, not a per-voter network. Wrong-side weight on unprovable claims now reaches the economy (step 3 glue, below).

## (3) Compositions that likely need an author ruling

| Composition | Question | Why past rulings do not settle it |
|---|---|---|
| Step 2, row 37 [provable flag settled by 8.168; classifier `ih_truth_level_ref`] | How are truth levels assigned in the composed world: a world property, measured by metric models, or both? How are opinion, fact and hypothesis categorised (L134 `Categorize`)? | `Truth.lean` bounds the chain rule but the pseudocode gives no classifier; a world property is the toy assumption, a measured one needs a model class |
| Step 3 [settled by 8.171 (1), pending author review] | Recruitment rate source and form (8.166 (3) says adapt persuasion data): which datasets, whether recruitment acts on outputs through the weight-on-advice mixture (8.63) | The figure is institution-dependent in part; the sweep range needs a ruling on the Benefuture-plausible end |
| Step 2 [settled by 8.171 (2)(6), pending author review] | Whether a hazard domain's gate is a governed threshold of its own and who sets `req_ed` | `ihz_access_risk` is formal, the gate's governance is not stated; candidate for SigThGv |
| Step 4 [settled by 8.169, rebuilt on 8.170; built 2026-11-25] | Who restrains, who is liable, and who audits, in an economy where audits are resource-priced | Settled by 8.170: restraint is the last-resort verdict of a panel of judicial experts voting with stated confidence (`cfd_ballot_weight_ref`, minority clusters uplifted, `panel_voice_ref`); liability for a false restraint falls on the experts who voted for it by their confidence (`credence_restraint_liability_ref`), as judicial-domain reputation first and currency on a repeated pattern; the enforcer executes and answers only for excess; audits (`restraint_audit_prob_ref`, commons-funded, recursion within an AdvAp budget) read verdict quality and execution fidelity; false restraints below true restraints is an invariant whose breach raises an alarm (`restraint_balance_flawed_ref`). The 8.169 enforcer-eagerness model and the credence liability on the enforcer (8.169 iii) are withdrawn. Measured in `sim/battery/restraint_balance.jl`: false/true 0.04 nominally, standing unchanged by liability, alarm 24/24 under capture and 1/24 falsely nominal. Open: acquittals are unaudited, alarm not wired to a governance candidate |
| Step 6 [newborn base vote OPEN, 8.171] | Birth endowment and baseline (SB, L144): what a newborn's currency, reputation and base vote are before any record | SB: Lean `baseline_required_ref`, `newborn_baseline_ref`, `baseline_refine_ref` and `run_population_world(birth_baseline = true)` (8.167b [P], probe P-BB, 2026-11-24) cover the baseline income of a newborn; not yet in the coupled world (it has no births), no endowment of reputation or base vote; 8.52 still prices the shortfall in M7 |
| Step 6 [open: positive balance, 8.171] | What happens to a dead being's open escrow, hold and balances in the economy beyond zero property inheritance (B25) | 8.47 and 7.12 rule inheritance, not unsettled contracts |
| Step 7 [settled by 8.171 (5), pending author review] | Whether G per entity replaces the pending-effect screen, or both coexist (a Sophont's G and the Administration's screen) | 8.50 rules per-entity G; the screen is recorded as a divergence and has no ruling on retirement |
| Step 8 [OPEN, 8.171] | The extended-self coupling graph's origin: observed from transactions, declared, or inferred | `Entity` formalises the feedback, not the graph |
| Step 11 [identity settled by 8.171 (3); currency and reputation OPEN] | A currency, reputation and identity for non-members | EHR rules the response; entities outside Benefuture appear nowhere in domain or currency ontology |
| Step 12 [OPEN, 8.171] | SO (Sophont Oversight), Phase 2 and data tiers, privacy | Named in the pseudocode, absent from Lean; the corpus gives no rule to simulate |
| All [settled by 8.171 (4), pending author review] | Whether a mechanism enters the default world only after a z = 3 composed-world replication (CLAUDE.md significance rule), or after the probe alone | Process question; the current practice is probe-green then battery |

Step 3 status (2026-11-24, `P54`; ruling 8.166): extremists are in `run_ih_world` (`extremist_frac`): people who publish the ideology at full confidence whatever the evidence, join the colluding bloc on the one network (M5 spreads, tags and weighs them as any colluder), and frame a checkable claim as unfalsifiable with chance `reframe` (8.168). Predictions stated before measuring: spread reduced with IH (lead, confidence 0.6). Results (paired seeds, z = 2, count by precision, two regimes, all reported): extremist influence (truth level x their weighted share of the consensus) falls with IH by 0.13 (default voters) and 0.08 (noisy voters), minds swayed by 0.09 and 0.21, wrong-side weight on unprovable claims by 0.27 and 0.17, each significant over 5 seeds; no unprovable extremist influence exceeds `cap_unprovable` in any seed (structural); Goal pattern: IH loses less than 3 one-sided on the floor of understanding and on harm's peak (16 seeds each, not stable at the tolerance, equivalence still shown), the worst drop is lower with IH. Falsified expectations (recorded, not tuned): the control's extremist influence is 0.18, not 0.3, and extremists add no measurable sway beside the existing liar bloc at 3 seeds (that bloc already saturates M5 spreading). The gap of step 2b closes: the mean wrong-side weight on unprovable claims adds to the accidental-hazard risk behind `p_side` (`unprovable_to_econ`). Not covered: recruitment rate is a world parameter set by the shared network's measured echo adoption, not yet adapted from persuasion data (a sweep, ruling 8.166 point 3); influence liability on extremists' resulting harm is not yet priced inside this world (row 21 composition). Question status: spread under IH is bounded without sanctioning speech in the toy; the persuasion-data sweep remains open.
