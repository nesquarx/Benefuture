# ODD description of the simulation

An ODD protocol description (Overview, Design concepts, Details; Grimm et al. 2020, "The ODD protocol
for describing agent-based and other simulation models: a second update to improve clarity,
replication, and structural realism", *JASSS* 23(2) 7, https://doi.org/10.18564/jasss.4259) of the
Julia package `BenefutureSim` (`sim/`), rung by rung. It describes the code as it stands; where code
and `sim/README.md` differ, the code is described and the difference noted. The rungs are nested:
each keeps the one below as a special case (perfect settings reproduce it, `sim/README.md`, Model
ladder), so §1 describes M0 in full and each later section gives only what it adds or changes. M4
and M6 are not separate programs: M4 is `run_m3c` with governance switched on, and M6 is a set of
adversarial settings of `run_m3c` and `run_m5`.

Common to every rung:

- **Rules versus world.** The rules (synergy, value V, harm weight, assessment, floors, G's choice,
  pricing, settlement, domain classification, voting weights, delegation, AdvAp's reward and
  liability, significance tests, admissibility) are computed by the Lean reference
  (`BenefutureReference`, exported in `BenefutureReference/Export.lean`) through `ccall`; Julia holds
  the world model and input guards (`sim/src/lean.jl` loads the library, rebuilt when the Lean
  sources' hash changes). Thin wrappers: `sim/src/synergy.jl`, `value.jl`, `goal.jl`,
  `measurement.jl`, `economy.jl`, `domains.jl`, `governance.jl`, `diversity.jl`, `friction.jl`.
- **Verification, not validation.** Wrappers are checked against `spec/vectors/*.json` and adversarial
  suites (`sim/test/`). No rung is calibrated or validated against data from the world
  (`README.md`, Claims; candidates in `docs/DATA.md`).
- **Stochasticity.** Every run takes a `seed`; each source of noise draws from its own
  `Xoshiro(hash((seed, :name)))` stream, so switching one off changes no other draw (CLAUDE.md,
  Verification; `sim/README.md`, Noise).
- **Units.** Understanding and happiness are dimensionless levels; changes are assessed in units of
  the significance threshold `ToyParams.th` (default 1). One time step has no calendar length.
- **Observation.** The Goal's success pattern (L74): floors (the `q`-quantile, default 0.1) and medians
  of understanding and happiness, the peak of understanding, and harm's peak (the deepest
  single-being drop since the last record); summarised by `success_pattern`
  (`sim/src/analysis.jl`). Analysis helpers: `running_mean`, `settling_step`, `ci_halfwidth`,
  `spearman`. Run-length guidance: burn-in 200 steps, rates over 500+, rare events over 1,000, ten
  seeds (`sim/README.md`, Run length).

---

## 1. M0: fixed population, random plans, perfect measurement (`sim/src/m0.jl`)

**1.1 Purpose and patterns.** The minimal world in which G (L74) chooses: does choosing by the Lean
rules make the floors rise? Pattern: `Conj_FloorsRise` (no floor falls over any window,
`floors_rise`); secondary: the peak of understanding pulling away from the median (B17).

**1.2 Entities, state variables, scales.**
- *Beings*: `n` (default 200; readings use 1,000), each with understanding `u` and happiness `h`
  (`ToyState`).
- *Plans* (`ToyPlan`): a change `du`, `dh` for every being (zero for beings not touched).
- *G*: one global chooser (a limiting case since 8.50).
- *Parameters* (`ToyParams`): `steps` (100), `plans` (20 a step), `q` (0.1), `th` (1), `touch`
  ((0.05, 0.3)), `shift` (0.5), `spread` (1), value parameters `gp` (α 0.8, β 0.6, γ 0.4, λ 0.5,
  q₊ 1.1, q₋ 1.5).
- Scale: discrete steps; no space.

**1.3 Process overview and scheduling.** Each step: (1) draw `plans` random plans; (2) G chooses
among inaction and the plans (`choose`); (3) the chosen plan's changes are added to every being;
(4) record floors, medians, mean happiness, peak.

**1.4 Design concepts.**
- *Basic principles*: Goal G (L74) as argmax of Σ V subject to no floor of U or H and no peak of U
  falling (the Lean `g_choose_ref`), V (L73) with every loss classed as passing harm.
- *Emergence*: distributional change (floors, median, peak) from repeated choices.
- *Objectives*: G maximises Σ V over the plans admissible under the floor constraints; inaction is
  always admissible.
- *Prediction, sensing*: perfect: G sees true levels and true plan effects.
- *Interaction*: none between beings; plans touch beings independently.
- *Stochasticity*: plan reach (share of beings touched uniform in `touch`), mean effect N(0, `shift`²)
  per plan, per-being effect N(mean, `spread`²).
- *Observation*: `floor_u`, `floor_h`, `median_u`, `median_h`, `mean_h`, `peak_u`, `chosen`, `value`.

**1.5 Initialisation.** `u`, `h` ~ 5 + N(0, 1) per being (`toy_state`).

**1.6 Input data.** None.

**1.7 Submodels.**
- `random_plan`: mask of touched beings, mean shift, per-being scatter.
- `being_value`: V on one being of (du, dh)/th with the harm schedule's passing tier (index 4 of
  `HARM_SCHEDULE`, loaded from the Lean reference) carrying all losses (`value_on_being`,
  `harm_weight`).
- `plan_value`: Σ V over touched beings.
- `choose`: floors before and after each plan (`floor_quantile`, the (k+1)-th smallest level), peak
  change, then `g_choose`.
- `assessed_value`: an outcome assessed against not acting (As, L48) and valued by V (used from M3d).

## 2. M1: measurement and competing metric models (`sim/src/m1.jl`)

**2.1 Purpose and patterns.** M0 seen through measurement: does the floors' guarantee survive noisy
markers and imperfect models? Patterns: `Conj_MMCompetitionConverges` (adoption settles on the most
accurate model; a precise but biased model loses to an unbiased one), B14; floors fall under noise
(harm) or G freezes (stagnation) (BACKPROPAGATION 8.1).

**2.2 Entities, state variables, scales.** M0's beings and plans, now latent. *Metric models*
(`MetricModel`): `bias`, `σ`; each keeps a history of scores. *Markers*: observe current levels and
realised changes with noise `marker_σ`. Parameters (`M1Params`): `models`, `marker_σ`, scoring `window`.

**2.3 Process overview.** Each step: (1) draw plans (world stream, as in M0); (2) every model predicts
every plan (bias and noise on touched beings); (3) G chooses on the adopted model's predictions and
the markers' view of levels; (4) if a plan is chosen, its realised changes are observed with marker
noise and every model is scored on it (`mm_score`, −MSE); (5) the true plan is applied; (6) the
model with the best rolling score is adopted (`mm_adopt`); (7) levels are re-observed.

**2.4 Design concepts.** *Adaptation*: model adoption by rolling score (L82). *Sensing*: G sees only
markers and the adopted model's predictions. *Stochasticity*: a measurement stream separate from
the world stream, so perfect models and exact markers reproduce M0 exactly (tested). *Observation*:
true and observed floors, the gap between them, adopted model and its score.

**2.5 Initialisation.** As M0; adoption starts from empty histories (all scores 0).

**2.6 Input data.** None.

**2.7 Submodels.** `predict`, `observe`, `mm_score` and `mm_adopt` (Lean scoring and adoption).

## 3. M2: agents propose, escrow pays (`sim/src/m2.jl`)

**3.1 Purpose and patterns.** Agents propose the plans and are paid through probabilistic escrow
(L84): does payment and reputation track contribution? Patterns: B9 (solvency of settlement), B20,
`Conj_MinTracksPrediction`; reputation tracks skill with careful agents and carefulness with sloppy
ones.

**3.2 Entities.** *Agents* (`Agent`): `skill` (mean effect of their plans on touched beings),
`sloppiness` (execution noise no model predicts); state: `balance`, `reputation`. Parameters
(`M2Params`): M1's world, agents, reputation decay `rep_rate`.

**3.3 Process overview.** Each step: (1) `plans` proposers drawn uniformly with replacement; each
proposes a plan with mean effect its skill (`plan_with_mean`); (2) models predict; G chooses; (3)
reputation decays; (4) if a plan is chosen: confidence = accuracy of the adopted model's rolling score
(Lean `accuracy_ref`); upfront = predicted value split by that confidence (`escrow_split`); the plan
is carried out with sloppiness noise (`carried_out`); markers measure it; settlement = measured −
upfront (`settlement`); balance += upfront + settlement; reputation += measured; models scored;
true changes applied; (5) adoption; re-observation.

**3.4 Design concepts.** *Objectives*: agents have none; they propose at random (no strategy).
*Learning*: none by agents. *Collectives*: none. *Observation*: upfronts, settlements, measured
values, predicted against realised floor change, final reputation and balance.

**3.5 Initialisation.** Balances and reputations zero; as M1 otherwise.

**3.6 Input data.** None.

**3.7 Submodels.** `escrow_split`, `settlement`, `reputation_decay`, `accuracy` (Lean).

## 4. M3: domains (`sim/src/m3.jl`)

**4.1 Purpose and patterns.** Payment, currency and reputation per domain, never crossing (L100–L101,
no halo, no horn). Patterns: B10, anti-halo isolation; finding: declared profiles cannot identify
per-domain skill and invite profile gaming.

**4.2 Entities.** *Agents* (`DomainAgent`): `skills` per domain, a declared `focus` (a partition of
unity, `profile_valid`), `sloppiness`; state per agent × domain: balance, hPos and hNeg (history,
never decaying), relevance (gains decaying at `λpos`, losses at `λneg`, with λneg ≤ λpos enforced,
ruling 8.29).

**4.3 Process overview.** As M2, with the plan's mean effect the focus-weighted skill; payment and
measured contribution split over domains by focus (`attribute`; positive and negative parts apart);
relevance gains and losses decay separately each step.

**4.4 Design concepts.** As M2. *Observation*: per-domain ledgers and balances.

**4.5 Initialisation.** As M2; one domain reproduces M2 exactly (tested).

**4.6 Input data.** None. **4.7 Submodels.** `attribute`, `decay_rate_for` (Lean), `split_signed`.

## 5. M3b: measured profiles, prices, overflow (`sim/src/m3b.jl`)

**5.1 Purpose and patterns.** Profiles measured from where effects land, not declared (L22); prices
per currency (L86); balance overflow (L103). Patterns: B6, B9, B10; measured profiles roughly double
how well domain reputation tracks domain skill.

**5.2 Entities.** *Domains*: D with a causal signature each (a unit vector); *StandCoin* (column D + 1)
for work matching none, flagged for adjudication. *Agents*: as M3, the focus now only where they
work. Parameters (`M3bParams`): `novelty` (chance a plan is a new scenario), signature `spread`,
`classify_σ`, `threshold`, `temperature`, `endowment` (5), `cost_per_touch`, `overflow_base`,
`overflow_factor`.

**5.3 Process overview.** Each step: (1) proposers draw a domain from their focus; each plan's
signature lies near that domain's, or far from all with chance `novelty`; (2) a currency metric model
measures the signature with noise and classifies it (`classify`) into a profile; (3) each currency
prices its share (resource cost share less escrow upfront, `transaction_price`); plans an agent cannot
pay in some currency leave the menu; (4) G chooses among the feasible plans; payment, settlement and
reputation follow the measured profile; (5) after the step, each balance above its accumulation
threshold overflows into reinvestment in its domain (`accumulation_threshold`, `overflow`).

**5.4 Design concepts.** *Sensing*: profiles are measured outputs. *Interaction*: through
affordability only. *Observation*: costs, true and classified domains, flagged steps, ledgers.

**5.5 Initialisation.** Balances at `endowment` per currency. **5.6 Input data.** None.
**5.7 Submodels.** `classify`, `transaction_price`, `accumulation_threshold`, `overflow` (Lean).

## 6. M3c (with M3d, M3e, M3f, and the M4 and M6 settings): the domain network (`sim/src/m3c.jl`)

One program, `run_m3c(::M3cParams; seed)`, carries every economy rung; switches select them:
`transactions` and `causal_distribution` (M3d), hazards and guardians (M3e), `events` (M3f black
swans), `govern`/`adapt`/`escape`/`relative_bar` (M4), and adversarial agents and `advap` (M6).

**6.1 Purpose and patterns.** The economy on Lean's ratified domain network (Ontology.Domain):
classification, currencies eligible by accuracy, fallbacks, novel domains, transactions with causal
distribution, hazards and duties, shocks, governed thresholds, adversarial agents and AdvAp. Patterns:
B6, B9, B10, B5, `Conj_MinTracksPrediction`, `Conj_FloorsRise` under noise, `Conj_ParamStability`
(M4), `Conj_GamingResistance` and `Conj_AdversarialRobustness` (M6); and, in batteries, the Goal's
success pattern against the clean world with no attack paying (`sim/battery/economy.jl`).

**6.2 Entities, state variables, scales.**
- *Beings*: `u`, `h` (as M0), observed through markers (`marker_σ`).
- *Agents* (`DomainAgent` over true leaves): skills per true leaf, focus, sloppiness; per agent:
  `deceit`, `launder`, `frivolous` (M6), `diligence`, choice-noise ceilings per true domain
  (`ability_caps`: `choice_σ`, `choice_gain`, `ability_spread`; 8.31); balances and reputation
  ledgers per currency; track records per model; a ledger negative share (`neg_share_ref`).
- *Domain network*: parents (axes of signature space); true leaves near their parent's axis with
  optional weak overlaps on others (`overlaps`), some hidden at the start (`known`); novel leaves
  formed during the run (up to `max_new`); μ, parents × leaves, from a bootstrap that knows each
  leaf's primary parent only, then learnt; the root with StandCoin.
- *Currencies*: one per leaf, parent and root; each backed by the top model of its pool; eligible
  by status bar (`threshold` 0.9 for established leaves, `novel_threshold` 0.75 after `min_records`,
  `coarse_threshold` 0.75 for parents; never below 0.55), optionally relative to the alternative
  (`relative_bar`, 8.41).
- *Metric models*: per leaf a pool (bootstrap model plus challengers, `pool_max` 4) with error by
  level (`σ_leaf`, `σ_branch`, `σ_coarse`, relative to the domain's spread), a systematic bias drawn
  once (`bias_σ`), histories of credences, outcomes and value errors; a novel leaf's model learns from
  coarse to leaf error over `n_learn` records.
- *Memory*: append-only log of executed actions (outcome, quotes, contributors) and blocked proposals
  (classification evidence; L88, L145), lossy (`memory_loss`).
- *Recent outputs* per true domain (`recent_outputs`) that later actions build on (M3d).
- *The commons*: resource costs paid less repair spending; the resource stock `available`
  (`capacity`, regenerating at `regen` with `regen_σ`).
- *Hazards*, *guardians* (one agent per true domain bound by contract, or none), *world events*
  (`Shock`: outage, catastrophe, capture, breakthrough).
- *Governance state* (M4): the value parameters (α, β, γ, q₊, q₋, λ) from the Lean bootstrap point,
  candidates and their trial scores, the gauged radius; the debatable escape's trial domains.
- Scales: discrete steps (`ToyParams.steps`); the first `init_steps` (50) are score-only (no currency
  moves; Implementation Phase 1).

**6.3 Process overview and scheduling.** Each step, in this order (the `for step` loop of `run_m3c`):

1. *Debatable escape* (M4, if `escape`): at `escape_start` choose `escape_share` of the true leaves
   for the trial; at its end compare trial and control by domain and epoch and adopt the relative
   bar only on `escape_accept_ref`.
2. *Outage status*: if no outage is live and measurements are owed, settle everything done during
   the outage now, late, with extra noise (`remeasure_σ`; 8.26.5).
3. *Proposals*: `plans` proposers drawn uniformly; each picks a true leaf from its focus and draws a
   plan with mean its skill there (raised by a live breakthrough). With chance `p_upstream` a plan
   builds on another agent's recent output in that domain, carrying `β_upstream` of its effect.
4. *Classification and quoting*: each plan's signature is measured (`classify_σ`), classified by
   descent from matched parents to member leaves (`classify_network`), and priced by each relevant
   currency (TP_Gen, L86) on its model's prediction, fooled by the actor's `deceit` and corrected by
   the model's track record on the actor (`track_window`; 8.29); ineligible leaves fall back to
   eligible parents by μ (`fallback_network`) or to StandCoin. Credences come from each model's own
   record (`credence`, capped at `max_credence`) and are ratcheted by the actor's ledger negative share
   (`ratchet_credence_ref`).
5. *Choice*: with `transactions` off, G chooses one plan (M3c); with it on, every proposal is a
   transaction screened by G against the observed state plus the predicted effects of the
   transactions already accepted this step, executed if its proposer can pay (M3d). Work only
   StandCoin would take goes to the StandCoin lane: full resource cost, screened by G on the best
   available model, co-funded by experts (`expert_share`, `participation`), else halted.
6. *Execution and settlement* (`perform!`): the plan is carried out with sloppiness; side effects
   (`p_side`) harm a share of touched beings (crime if foreseen, `p_foresee`; Lean `is_crime_ref`);
   markers measure the outcome; during an outage the action is paid by escrow's upfront only and
   measured later. Escrow settles; with `causal_distribution` each touched being's assessed change is
   an outcome shared among contributors by Shapley (`shapley_ref`, exact up to 10 contributors) or,
   below `cc_threshold`, by traversal (`traversal_shares_ref`); positive shares paid, negative
   penalised; carriers earn an accolade or contract share (`carry_fee_ref`). Reputation ledgers,
   track records and every model on the classification path are updated; memory logs the action and
   μ moves (`membership_rolling`, `μ_rate`). Laundering agents dump harm outside what the action
   measurably touches (`launder`).
7. *Hazards* (M3e): with chance `p_hazard` a hazard threatens `hazard_share` of beings; a guardian
   learns of it with `p_informed` and acts with its `diligence`; a prevention is the guardian's
   ordinary recorded action (optionally shocking those it protects, `p_shock`); an unprevented
   hazard under a guardian is its contribution (crime if informed, else accident), penalised to fund
   repair; unguarded harm is unassigned and insured through the commons, repair priced as a
   transaction (L86), gated by `repair_efficiency`.
8. *Harm of no apparent cause* (laundered or a sabotaged outage's) is examined: traced with `p_trace`
   (a crime, penalised through causal distribution), else insured through the commons.
9. *Resources*: the stock regenerates.
10. *Novel domains*: blockages (plans stuck at a parent or the root) clustered within `form_radius`,
    `form_count` strong, form a novel leaf; memory is reclassified and reputation recounted at each
    formation and every `μ_every` steps.
11. *Overflow*: balances above their accumulation threshold are reinvested (L103).
12. *Track records* pending this step reach the models.
13. *Better models* (8.42.2, a world assumption): with chance `p_new_model` per domain a challenger
    arrives, its error relative to the incumbent's log-normal around `improve_drift`, never below
    `scale_min` of the bootstrap error; a challenger takes over when its credences beat the
    incumbent's by `model_z` standard errors (`select_candidate_ref`).
14. *AdvAp* (M6, if `advap`): each agent reads another actor's record with chance `vigilance`
    (attention weighted towards negative ledger patterns, `pattern_attention`, and its own marginal
    domain, `stake_attention`); reports when the actor's raw errors exceed other actors' on the same
    models by `adv_z` standard errors in its own noisy reading; frivolous agents report anyone. An
    audit applies the significance rule and examines the cause (`p_trace`, `p_false_trace`);
    established, the falsified records are re-scored, the reporter paid (`advap_reward_ref`), the
    deceiver charged (`advap_liability_ref`); unfounded reports past `frivolous_threshold` in
    `adv_window` are charged (`report_penalty_ref`).
15. *Record* the success pattern; *observe* levels (unless blind: the last observation stands).
16. *SigThGv* (M4, if `govern`): after the score-only start, every `gov_epoch` steps either a random
    walk (a candidate within δ adopted if admissible, `perturb_step`) or, with `adapt`, experimental
    design: the incumbent and `gov_candidates − 1` perturbed candidates are tried `gov_trials` epochs
    each in randomised blocks, scored by the observed floors' movement, and the best adopted only if
    it wins by `gov_z` standard errors (`select_candidate_ref`); the radius is gauged
    (`gauge_radius_ref`).

**6.4 Design concepts.**
- *Basic principles*: L74 (G), L82 (currencies backed by top models above a bar), L84 (escrow), L86
  (pricing), L94–L96 (causal contribution and distribution), L100–L103 (reputation, overflow), L115
  (crime), L119 (liability), L145 (memory), L154 (progressive fallback), L157 (SigThGv), L160 (AdvAp).
- *Emergence*: domain formation, learnt overlaps, eligibility patterns (the cliff of 8.32), wealth
  concentration, blockades of marginal domains by deceivers (8.37).
- *Adaptation*: model adoption and takeover; μ learning; formation; parameter governance (M4).
  Agents themselves do not adapt their strategies: deceivers, launderers and frivolous reporters are
  fixed types (a toy assumption; adaptive attackers are planned, `docs/SOTA.md` action 2).
- *Objectives*: G's (central, one chooser screening every proposal); agents' only in co-funding and
  AdvAp reporting, by noisy judgement.
- *Learning*: models' track records per actor; the escape and SigThGv learn by experiment.
- *Prediction*: metric models predict plan effects; G and prices act on predictions.
- *Sensing*: markers with noise; outages blind G (last observation).
- *Interaction*: through transactions, upstream outputs, co-funding, causal distribution, audits.
- *Stochasticity*: separate streams for world, measurement, domain choice, classification, extra
  noise, upstream, attribution, contracts, hazards, side effects, governance (and more).
- *Collectives*: domains and their currencies; no agent coalitions in the economy.
- *Observation*: the trace (`floor_u` etc.; per chosen plan `true_leaf`, `stop_leaf`, `priced_leaf`,
  `costs`; the StandCoin lane; per-currency ledgers and balances; μ; crimes, accidents, repairs;
  takeovers; AdvAp tallies; escape result); `recount` checks incremental reputation against a recount
  from memory.

**6.5 Initialisation.** Levels as M0; balances at `endowment`; μ from the bootstrap pattern; one
bootstrap model per leaf and parent, biases drawn; empty memory; the commons empty and the stock at
`capacity`; value parameters at the Lean bootstrap point (`bootstrap_params`).

**6.6 Input data.** None. Batteries (`sim/battery/economy.jl`) and tests build worlds in code.

**6.7 Submodels.** Classification (`projection_membership`, `classify_network`), fallback
(`fallback_network`), aggregation (`aggregate_at_parent`), subsethood, μ (`membership_rolling`),
accuracy and credence (`accuracy`, `credence`, `credence_accuracy`, `credence_score`), eligibility
(`currency_eligible`, `relative_bar`), scarcity (`scarcity_cost`), pricing and settlement
(`transaction_price`, `escrow_split`, `settlement`, `cause_settlement`, `cc_share`), Shapley and
traversal (`shapley`, `cc_assessed`, `traversal_shares`), carrying (`carry_fee`), crime (`is_crime`),
AdvAp (`advap_reward`, `advap_liability`, `report_penalty`, `ratchet_credence`, `neg_share`),
governance (`admissible`, `perturb`, `select_candidate`, `gauge_radius`, `escape_accept`), friction
(`ability_caps`, `choice_noise`, `sim/src/friction.jl`); all rules in Lean, wrappers in
`sim/src/economy.jl` and `sim/src/domains.jl`. Introduced mechanisms are listed in `sim/README.md`
(Parsimony audit): the pending-effects screen, `pool_max`, `max_new`, the 10-contributor Shapley bound.

## 7. M4: governed thresholds (settings of `run_m3c`)

**7.1 Purpose and patterns.** Whether governing the value parameters by SigThGv (L157) inside the
admissible region keeps outcomes stable (`Conj_ParamStability`), whether adaptation by experiment
avoids confounds, and whether the debatable escape adopts only a proposal that proves better.
**7.2–7.7.** Entities, schedule and submodels as §6, steps 1 and 16, with `govern = true` (and
`adapt`, `escape`, `relative_bar`, `irreparable_loss`). Design: *adaptation* by randomised-block
experiments; *objective* the observed floors' movement, free of the parameters tuned; the trial
domains of the escape are chosen at random (the domain experts' vote to try it is assumed, a toy
assumption). Thresholds of the simulation's own gates (`sim/README.md`, Governed thresholds) are not
yet governed.

## 8. M5: governance by weighted liquid democracy (`sim/src/m5.jl`)

**8.1 Purpose and patterns.** Decisions in domains with L113 weights and L114 capped, audited,
retractable delegation; votes as outputs (8.29); diversity's split trials (L158); deliberation through
information handling (L133); forks; and, as M6, colluding blocs met by AdvAp's manufactured prisoner's
dilemma. Patterns: `Conj_DelegationDispersed`, B11, B23; in batteries at least 75% of the last half
of decisions right (`sim/battery/governance.jl`).

**8.2 Entities, state variables, scales.**
- *Voters*: the agents of an M3c run, with skills and focus per domain; state: reputation per domain
  (from the M3c run's leaf relevance, or given), noise ceilings (`ability_caps`), audited records of
  apparent votes, published-reading records (rights, wrongs) for deliberation, `camp_bias`.
- *Decisions*: `decisions` (200 default), each in a domain drawn from `domains`, with a true value
  `truth` ~ N(0, 1); the right option is its sign.
- *Metric models* per domain (deliberation): noise from `model_σ0`, improving by arrivals
  (`p_new_model`, `improve_drift`, `improve_σ`, `scale_min`); pool bounded at 4 (hardcoded).
- *Locales*: `trial_units` (50) for diversity's split trials, each with its own reading noise.
- *Colluders* (M6), fork copies, a captured model (`model_capture`).
- Scale: one decision per iteration; no space.

**8.3 Process overview.** For each decision: (1) draw domain and truth; draw whether its optimality
will become apparent (`p_apparent`); (2) forks add copies (base vote divided by default,
`fork_rule = :divided`); (3) weights by L113 (`voting_weight_ref`, expertise as shares of the
domain's reputation, `relative_expertise`); (4) in random order, voters with impact below
`impact_threshold` delegate with chance `p_delegate` to the highest-reputation voter above them not
audited out (`audited_out_ref`) and under the cap (`accumulate_capped_ref`); (5) each voter's signal is
truth + camp bias + choice noise; (6) with `deliberation`, models publish readings and each voter
weighs its own reading, its contacts' (or, with `info_handling`, the ContentionMap's most reputable
sources on each side) and the models' by log-odds of their records (`source_weight_ref`), hearing only
sources at least as reputable as itself except rare novel input (`heard_ref`, `p_novel`); (7)
colluders vote their side (a stealthy bloc only where the outcome will stay hidden); the tally is the
sign of Σ held weight × vote; (8) with `diversity`, locales whose own reading opposes the decision by
more than their conviction margin (lowered by `novelty_bonus`) try the alternative; a significant
split trial (`split_trial`, `trial_z`) makes the outcome apparent and adopts a better alternative; (9)
if apparent, each vote earns or costs reputation by the weight it cast (`vote_reputation_ref`) and
enters the audited record; sources' records update; (10) with `advap`, after a hidden defection bloc
members weigh revealing (`p_weigh`), reveal when the reward beats their share and `loyalty`; an
established revelation (`p_trace`) strikes the bloc's votes from every falsified decision since the
last one and recounts them.

**8.4 Design concepts.** *Basic principles*: L113, L114, L133, L158, L160, rulings 8.22, 8.29,
8.43–8.45. *Emergence*: concentration of weight, re-sorting of reputation by vote records, echoes
(8.45). *Adaptation*: delegation retracted by audit; source weights by record. *Objectives*: voters
vote their reading; bloc members compare reward and loyalty. *Sensing*: noisy signals, ceilings
inverse to skill on average (`skill_gain`; skill sharpens judgement, a toy assumption).
*Interaction*: delegation, deliberation over a fixed random contact network (`n_contacts`).
*Collectives*: blocs, fork families, camps. *Observation*: share decided correctly (apparent and
hidden), largest share of weight held, bloc's expertise share, welfare under trials.

**8.5 Initialisation.** Reputations, skills and focus from an M3c run (`M5Params(m3, domains)`);
contacts drawn once; one bootstrap model per domain.

**8.6 Input data.** The output of an M3c run (reputation matrix), not external data.

**8.7 Submodels.** `voting_weight`, `accumulate_capped`, `relative_reputation`, `vote_reputation`,
`audited_out`, `source_weight`, `heard` (Lean, `sim/src/governance.jl`); `split_trial`
(`sim/src/diversity.jl`); `ability_caps`, `choice_noise`. Still computed in Julia (to move to Lean):
the ContentionMap and AdvAp's recount of falsified decisions (`sim/README.md`, Parsimony audit).

## 9. M6: malicious and gaming agents (settings of `run_m3c` and `run_m5`)

**9.1 Purpose and patterns.** Exploits tested against the native mechanisms before any defence is
built (8.28): `Conj_GamingResistance`, `Conj_AdversarialRobustness`, `Conj_GoodhartReduction`,
B1–B5, B18, B21. **9.2–9.7.** No new entities: adversarial *types* are parameters. Economy (§6):
`deceit` (plans fool every model upward), `launder` and `launder_saving`, `frivolous`, sabotaged
outages (`shock(:outage; target)`), captured models (`shock(:capture)`). Governance (§8): `colluders`
(optionally `stealth`), `fork_copies`, `model_capture`. Responses are the native ones: track records,
escrow and settlement, ratcheting credence, AdvAp, vote reputation and audited delegation, diversity,
divided forks. Attackers are fixed strategies, not optimised; adaptive attack search is planned.
Tests: `sim/test/m6_tests.jl`, `advap_tests.jl`.

## 10. M7: population, teaching, research, G per entity (`sim/src/m7.jl`; deaths in `sim/test/m7_tests.jl`)

**10.1 Purpose and patterns.** Deaths under G's quantile floors over the decision-time population
(finding 8.47); teaching that shares understanding without moving it; research as spending (8.49);
G per entity (8.50). Patterns: `Conj_NoRepugnantDrift`, B15, B17, B19; uplift against
`research_share`; floor, median and peak rising together under teaching.

**10.2 Entities, state variables, scales.**
- *Beings* (M0's), each also an entity that can act, with `tacit` understanding (not teachable) and a
  fixed `novelty` trait (uniform 0.2–1).
- *Lessons* (`teaching_plan`): one teacher, up to `class` (10) learners below its teachable level.
- *Options*: `options` (3) ordinary plans, each `action_scale` (0.05) of an M0 plan, and one lesson.
- Parameters: `ε`, `reception_σ`, `research_share` (governed, 0.1), `p_research`, `research_σ`,
  `research_gain`, `p_teachable`, `research_cost`, `p_innovate`, `lessons`, `p_act`, `view_σ`,
  `pred_σ`, `central`.

**10.3 Process overview.** Each step: (1) each being researches with chance `research_share` (its
cost tallied); an attempt succeeds with chance `p_research` × (u / peak)² × novelty × log-normal
(`research_σ`) and raises u by a log-normal gain (`research_gain`), tacit unless teachable
(`p_teachable`); (2) ordinary work is capped at the peak except by in-job innovation, chance
`p_innovate` × ((u − median)/(peak − median))⁴; (3) *G per entity* (default): every non-researching
entity acts with chance `p_act`, on its own noisy view of levels (`view_σ`), predicting its options
with error `pred_σ`, choosing by the Lean rules (`choose`); all chosen actions apply concurrently;
concurrent lessons add up but no learner ends above the best teacher it met (introduced bound). With
`central`, one global G chooses one plan among ordinary plans and lessons, scaled by the time left;
(4) record.

The deaths rung is a test, not a run: a constructed plan removing the two worst-off of 50 beings and
lifting the rest, against which the quantile floor over the decision-time population and V with
deaths as irreparable harm are checked (`fr_permissible_ref` marks it impermissible).

**10.4 Design concepts.** *Basic principles*: L74 per entity (8.50); understanding shared, not moved
(the teacher keeps its own, `u_sharing_gain_nonneg` in Lean); L151 Rc_Innovation. *Emergence*:
frontier growth, concentration of understanding (top decile's share). *Objectives*: each entity's G
on its own view. *Sensing*: noisy views. *Interaction*: lessons. *Stochasticity*: streams for
reception, research, and views. *Observation*: success pattern, top decile's share, actions per step
and kinds, breakthroughs, innovations, research spent.

**10.5 Initialisation.** As M0; tacit zero; novelty drawn. **10.6 Input data.** None.

**10.7 Submodels.** `teaching_plan`; research attempt; innovation cap (`capped`); `choose`.

---

## What the ODD shows

- **No input data anywhere.** Every rung runs on invented worlds; the parameters marked "world" in
  `sim/README.md` are the calibration surface (`docs/DATA.md`).
- **The rungs do not compose.** M7's population and G per entity do not run inside M3c's economy or
  M5's governance; M5 reads reputations from a finished M3c run rather than running beside it; the
  economy's chooser is still one central G screening proposals (the limiting case 8.50 retires).
- **Agents are fixed types.** No agent learns a strategy, enters or leaves (outside M7's research and
  teaching); attackers are given, not optimised.
- **No space and no networks** beyond M5's fixed random contacts and M3c's domain network (M8).
- **One resource stock and one commons** for the whole economy (§6.2), which matters for the Ostrom
  audit (`docs/OSTROM.md`, principles 1b and 2b).
