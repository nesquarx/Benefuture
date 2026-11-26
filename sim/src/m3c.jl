# Toy model M3c: M3b on the domain network (Ontology.Domain [R], Proposed.DomainHierarchy [P];
# author rulings, BACKPROPAGATION 8.3, 8.4, 8.8).
#
# World (this file): parents (broad domains) are axes of causal signature space; a true leaf sits
# near its primary parent's axis, with weak overlaps on others, plus an axis of its own; a new
# top-level domain has an axis no parent covers. Some true leaves are missing from the network
# (hidden). Each plan works in a true leaf drawn from its agent's focus, its causal signature near
# that leaf's. Currency metric models measure it with noise: its membership in each parent is its
# projection there; classification descends from matched parents to their member leaves (μ ≥
# `μ_min`); what no leaf takes is stuck at the parents, or at the root. A currency is eligible
# while its model's accuracy (expected accuracy before records, for established models) reaches
# `threshold`; a novel leaf's after `min_records` scored predictions, at `novel_threshold`, never
# below 0.55 (Lean). Ineligible leaves' shares fall back to eligible parents by μ, else to StandCoin.
# A plan mostly at StandCoin cannot be valued by a qualified currency, so it is not in G's menu:
# it is priced at its full resource cost, screened by G on the best available model (qualified or
# not), and goes ahead if the proposer, with experts (agents with reputation in the parents it
# overlaps) contributing up to `expert_share` of their StandCoin, can pay; otherwise it halts. New
# top-level domains are not modelled (author ruling: implausible). Each currency's model predicts the plans it prices: accurate (`σ_leaf`) for its own leaf,
# broader (`σ_branch`) for a parent on leaves it knows, coarse (`σ_coarse`) otherwise; a novel
# leaf's model learns from coarse with its records. Every model on the classification path is
# scored against the outcome. Benefuture starts score-only (Implementation, Phase 1): for the first
# `init_steps` no currency backs value; G chooses on the best available models, and work is
# executed, scored and logged. μ starts from a bootstrap classification that knows each leaf's
# primary parent only, and moves as a long-term rolling average (`μ_rate`) of the memberships of
# every logged action, executed or blocked (author ruling): overlaps are learnt and shift as
# reality does, and a leaf without new actions keeps its degrees (domains do not fade). Memory is
# reclassified and reputation recounted every `μ_every` steps and at each formation.
# Blockages (plans mostly stuck at a parent or the root) that cluster within `form_radius`,
# `form_count` strong, form a novel leaf at their centroid (or reuse a leaf already there).
# Reputation is kept where actions are classified; a parent's aggregates its leaves' by μ.

const Shock = NamedTuple{(:kind, :step, :duration, :size, :share, :target),Tuple{Symbol,Int,Int,Float64,Float64,Int}}

"M3c parameters: the toy world, agents over true leaves, the initial network, and thresholds."
struct M3cParams
    toy::ToyParams
    agents::Vector{DomainAgent}
    leaf_parent::Vector{Int}   # each true leaf's primary parent, 0 for a new top-level domain
    known::Vector{Bool}        # true leaves present in the initial network
    overlaps::Vector{Tuple{Int,Int,Float64}}  # (true leaf, parent, weight): weak memberships
    λpos::Float64
    λneg::Float64
    marker_σ::Float64
    window::Int
    spread::Float64
    classify_σ::Float64
    parent_threshold::Float64
    μ_min::Float64
    leaf_threshold::Float64
    temperature::Float64
    σ_leaf::Float64
    σ_branch::Float64
    σ_coarse::Float64
    n_learn::Float64
    threshold::Float64
    novel_threshold::Float64
    coarse_threshold::Float64  # status a parent (coarse) model needs (8.35; governed)
    max_credence::Float64      # the greatest credence any model may state (8.33: truth levels never reach 1; governed)
    ratchet_k::Int             # models that must clear a domain's bar before it ratchets up (8.84; governed)
    ratchet_margin::Float64    # the ratcheted bar sits this far under the k-th best accuracy (8.84; governed)
    ratchet_horizon::Float64   # the ratchet's half-life as a multiple of the domain's accuracy half-life (8.84, 8.85; governed)
    accuracy_rule::Symbol      # :decay (8.85: age-weighted, half-life by transaction rate) or :window (fixed records; limiting case)
    acc_halflife::Float64      # accuracy half-life in steps at the reference transaction rate (8.85; governed)
    acc_rate_ref::Float64      # the reference transaction rate, records per step (8.85; governed)
    acc_mute::Float64          # how far the half-life follows the rate: 1 a fixed record count, 0 a fixed time (8.85; governed)
    rate_halflife::Float64     # half-life in steps of a domain's measured transaction rate (8.85; governed)
    chain_attrib::Vector{Float64}  # measurement chains for outcomes (8.107): the share of each being's loss each chain attributes (1 = full; last-symptom counting less)
    chain_mode::Symbol             # :single (the first chain's output is consumed) or :domain (the measurement domain's reading)
    chain_copy::Vector{Int}        # chain k secretly copies chain chain_copy[k]'s reading (0 = independent; an attack, 8.107)
    chain_detect::Bool             # detect undeclared copying by agreement closer than independent noise allows
    chain_spot::Float64            # spot-audit chance per outcome when fewer than two independent chains remain (governed)
    chain_shade::Vector{Float64}   # chain k reports this share of chain 1's reading in place of its own (an attack: looking agreeable, 8.107)
    chain_spot_all::Bool           # spot audits at `chain_spot` even when chains agree (8.107: no chain trusted without an independent check)
    adaptive_proposals::Bool       # agents propose in proportion to their recent acceptance, so refused slots pass to others (8.115; world)
    chain_z::Float64               # divergence between chains that triggers an audit (8.107; governed)
    ratchet_growth::Float64    # escrow growth per discovered deception, exponential in the count (8.91 ruling; governed; 0 = the flat ratchet)
    novel_floor::Float64       # the least bar a novel domain's model clears to back a currency (8.35; governed)
    scarcity_floor::Float64    # share of capacity remaining below which scarcity pricing stops rising (L83; governed)
    actor_min_records::Int     # actor errors a model needs before its credence uses its record on that actor (8.29; governed)
    attest_min_records::Int    # attestations before an attester's skill is read from its record (8.70; governed)
    adv_min_records::Int       # an actor's records an AdvAp reader needs before reporting (8.38; governed)
    adv_track_floor::Int       # fewest of the actor's recent errors an AdvAp audit compares (8.38; governed)
    form_buffer::Int           # evidence kept per domain, as a multiple of `form_count` (L49 classification; governed)
    own_axis::Float64          # weight of a leaf's own axis in its signature, against shared parents (world)
    bind_conf_compromised::Float64  # a compromised cluster's confidence in a false binding (world, M6)
    bind_conf_affirm::Float64  # confidence a cluster states when its methods affirm (world, M6)
    bind_conf_deny::Float64    # confidence a cluster states when its methods deny (world, M6)
    loud::Bool                 # warn once per kind of degradation (the trace records them either way)
    credence_rule::Symbol      # :normal (prior-free credence_ref over RMS error), :record (nonparametric cold-start/fallback, record_credence_ref), or :eb (ruled D2 default, eb_credence_ref)
    min_records::Int
    μ_rate::Float64
    μ_every::Int
    endowment::Float64
    cost_per_touch::Float64
    capacity::Float64
    regen::Float64
    overflow_base::Float64
    overflow_factor::Float64
    expert_share::Float64
    form_count::Int
    form_radius::Float64
    max_new::Int
    init_steps::Int
    transactions::Bool
    # Transaction trees and causal distribution (M3d; author ruling, BACKPROPAGATION 8.14).
    causal_distribution::Bool  # share each outcome among its contributors (8.16–8.18)
    cc_threshold::Float64      # confidence the causal assessment needs, else traversal (L94; governed)
    traversal_decay::Float64   # weight per degree of separation in the traversal fallback (L95; governed)
    p_upstream::Float64     # chance an action builds on a recent output of another agent in its domain
    β_upstream::Float64     # how much of that output's effect per being the action carries
    recent_outputs::Int     # outputs kept per domain to build on
    attribution_σ::Float64  # metric models' error in separating an upstream output's part
    upstream_depth::Int     # maximum hop depth of transaction trees (L95; 1 = direct parent only)
    # Contribution types (author ruling, BACKPROPAGATION 8.22; L96: CD ∝ CC + N_CCtype).
    accolade_rate::Float64  # share of a carried output's positive share earned by carrying it outside contract (governed)
    contract_share::Float64 # the same share when the carrying is contracted: paid as contract completion
    p_contracted::Float64   # chance a carrying is under contract
    # A world that moves on its own (M3e; author rulings, BACKPROPAGATION 8.15, 8.17).
    p_hazard::Float64            # chance a hazard arises in some domain each step
    hazard_share::Float64        # share of beings a hazard threatens
    hazard_size::Float64         # its harm per being, on understanding and happiness
    hazard_σ::Float64            # variability of that harm
    guardians::Vector{Int}       # per true domain, the agent bound by contract to prevent its hazards (0: none)
    p_informed::Float64          # chance a guardian learns of a hazard in time
    diligence::Vector{Float64}   # per agent, chance it acts on a duty it knows of
    repair_efficiency::Float64   # share of a penalised harm that repair restores (governed)
    p_side::Float64              # chance an action creates a hazard as a side effect
    side_share::Float64          # share of the beings it touches that the side effect harms
    side_size::Float64           # harm per being of the side effect
    p_foresee::Float64           # chance the actor foresaw the side effect
    p_shock::Float64             # chance a prevention shocks the beings it protects
    shock_size::Float64          # that shock's harm per being, on happiness
    # Governed thresholds (M4; SigThGv, L158; `Systems.ParamSpace` [R]).
    govern::Bool                 # perturb the value parameters through SigThGv
    adapt::Bool                  # select by experiment (8.22) rather than a plain random walk
    gov_epoch::Int               # steps between governance steps (governed)
    gov_δ::Float64               # largest move of a field per perturbation (governed)
    gov_candidates::Int          # candidates per round, the incumbent included (governed)
    gov_trials::Int              # epochs each candidate is tried per round (governed)
    gov_z::Float64               # standard errors a difference must exceed to count (governed)
    gov_gauge::Float64           # factor by which the gauged radius shrinks on harm, widens without (governed)
    # Noise in steps not covered above (defaults mildly imperfect, 8.33; see `sim/README.md` for realistic ranges).
    bias_σ::Float64        # each metric model's systematic bias, drawn once per model
    cost_σ::Float64        # resource accounting error, multiplicative (log-normal)
    regen_σ::Float64       # variability of resource regeneration, relative
    memory_loss::Float64   # chance a record never reaches memory
    participation::Float64 # chance an asked expert takes part in co-funding
    remeasure_σ::Float64   # extra marker error when measuring late, after an outage
    deceit::Vector{Float64} # per agent, how far its plans fool every metric model upward (M6; world)
    track_window::Int       # past actions of an actor its track record spans, for models' estimates (governed; 8.29)
    p_trace::Float64        # chance examining harm of no apparent cause traces it to its cause (8.30.1; world)
    launder::Vector{Float64} # per agent, chance an action dumps harm outside what it measurably touches (M6; world)
    launder_saving::Float64 # resource cost a laundering agent saves by it, as a share (world)
    choice_σ::Float64       # base ceiling of agents' choice noise, before skill (8.31; world)
    choice_gain::Float64    # how fast skill lowers that ceiling (8.31; world)
    ability_spread::Float64 # scatter of persons' ceilings around the skill trend (8.31; world)
    # Adversarial adaptation (AdvAp, L161; author ruling 8.38): reports, audits, repair.
    advap::Bool                  # agents report gaming they read in the log; audits examine and repair
    vigilance::Float64           # chance per step an agent reads another actor's record (world)
    adv_z::Float64               # standard errors an actor's overstatement must exceed for a founded report (governed)
    adv_share::Float64           # the reward's share of the harm a revelation prevents (governed)
    adv_floor::Float64           # least reward for a revelation (governed)
    audit_cost::Float64          # resource cost of one audit (world)
    frivolous_threshold::Float64 # unfounded reports in the window before each is charged its audit (governed)
    adv_window::Int              # steps over which a reporter's unfounded reports are counted (governed)
    p_false_trace::Float64       # chance an examination wrongly establishes an honest actor's deception (noise)
    frivolous::Vector{Float64}   # per agent, chance per step to report someone whatever the record (M6; world)
    pattern_attention::Float64   # how far readers' attention follows a negative ledger pattern (world; 8.42.1)
    stake_attention::Float64     # how far it follows their own stake in a marginal domain (world)
    marginal_margin::Float64     # accuracy above its bar within which readers see a domain as marginal (world)
    # The status bar relative to the alternative (8.41) and the debatable escape that tries it (L157;
    # 8.26.3, 8.38.2): a share of the domains for a limited time, compared by domain and epoch.
    relative_bar::Bool           # leaves' bars relative to the alternative their work would fall to
    escape::Bool                 # try the relative bar as a debatable proposal, adopting it only on its trial
    escape_start::Int            # step the trial begins (governed: decided by domain experts)
    escape_steps::Int            # its length (governed: decided by domain experts)
    escape_share::Float64        # share of the domains it is tried in (governed: decided by domain experts)
    escape_epoch::Int            # steps per unit of comparison (governed)
    irreparable_loss::Float64    # a measured loss on one being beyond which harm is irreparable (world; none by default: the toy's losses are passing harm)
    # Better models over time (8.42.2; L82, L49): an assumption, not a rule (causal discovery is not simulated).
    p_new_model::Float64         # chance per step a new model arrives in a domain (world assumption)
    improve_drift::Float64       # its error relative to the incumbent's, on average, in logs (world assumption; negative: better)
    improve_σ::Float64           # scatter of that (world assumption)
    scale_min::Float64           # no model is perfect: least error relative to the bootstrap model's (world; 8.33)
    model_z::Float64             # standard errors a challenger must beat the incumbent by to take over (governed)
    pool_max::Int                # models kept per domain (introduced: an array bound)
    # Decision market and attacks (M6; docs/SOTA.md; BACKPROPAGATION 8.58-a onwards).
    explore_share::Float64       # chance per step one proposal not carried out is carried out anyway (governed; full support)
    takeover_records::Int        # records a challenger needs before it may take over (governed; against extremised forecasts)
    p_extremist::Float64         # chance an arriving model extremises its credences (world, adversary)
    extremise::Float64           # the share of its uncertainty an extremist states (world)
    whitewash::Vector{Float64}   # per agent, chance per step it tries to take a new identity (world, adversary)
    bind_miss::Float64           # chance one cluster's binding methods miss the entity behind a new identity (noise)
    bind_clusters::Int           # clusters whose binding methods examine a new identity (world)
    bind_threshold::Float64      # binding confidence a cluster must reach (governed)
    bind_quorum::Int             # clusters that must reach it to admit an identity (governed)
    bind_compromised::Vector{Int}  # clusters colluding with whitewashers: they attest every new identity distinct (world, adversary)
    p_reveal::Float64            # chance per step an identity's truth comes out (a false one revealed, a real one confirmed; world)
    p_newcomer::Float64          # chance per step a real new entity seeks binding (world)
    attest_pooled::Bool          # weigh clusters by pooled skill (the counterexample) instead of class-balanced skill
    bind_weighted::Bool          # [P] 8.70: each cluster's say is its attestation skill (`binding_admits_weighted_ref`)
    bind_quorum_weight::Float64  # skill the clusters reaching the threshold must sum to under weighting (governed; 1 = two clusters at skill 0.5)
    slander::Vector{Int}         # per agent, whom its frivolous reports target (0: anyone; world, adversary)
    on_off::Int                  # deceit on only in alternate phases this long, off first (0: always on; world, adversary)
    events::Vector{Shock}  # catastrophes and black swans (world events; see `shock`)
    # Heavy hazards (3.9): an event's size is Pareto (median 1), its harm log-normal across beings; off: the old Gaussian scatter.
    hazard_heavy::Bool
    hazard_α::Float64      # Pareto exponent of event size
    hazard_cap::Float64    # largest event, in medians
    # Forks (identity step 2, L123): (step, parent, slot, share). The slot is a dormant agent (no proposals) until its
    # step; then it takes `share` of the parent's balance, relevance and accumulation base (`fork_split`). `fork_rule`
    # :split (the rule) or :naive (the slot gets a full base: the exploit, for counterexample tests).
    forks::Vector{Tuple{Int,Int,Int,Float64}}
    fork_rule::Symbol
    # Merges (L123's inverse; human birth is a merge of forks, 8.34 continued): (step, absorbed, into). The merged identity
    # holds the sum of both balances (debts included), ledgers, relevance, allowance and capacity, and both records; the
    # absorbed identity goes dormant. Naive: the absorbed identity's negative ledger and debts are dropped (the exploit).
    merges::Vector{Tuple{Int,Int,Int}}
    # Resource-accounting contraction (8.71 (2), L83): a stall is a society that overpromised and cannot shrink back. With
    # `ra_rate` > 0, each step in which more StandCoin work halts unfunded than executes, baseline resource prices shrink by
    # that share (deflation absorbs the hit); otherwise they recover toward 1 at the same rate. Governed (0: off).
    ra_rate::Float64
    # Global resource accounting (8.133): with `ra_horizon` > 0, new issuance (positive credits) is capped so claims
    # outstanding stay within that many steps of deliverable value (`deliverable_value_ref` of capacity, regeneration and
    # base price; `issuance_headroom_ref`); value beyond the cap is not issued, logged loudly. Governed (0: off).
    ra_horizon::Float64
    budget::Bool   # 8.133 step 3: actions need the proposer's currency for their cost and available resources (world; off: legacy)
    # A resource supplier or supply cartel (8.133, gaming): agent `supplier` (or agents in
    # `supply_cartel`) owns `supply_share` of capacity (split equally across cartel members) and is
    # paid that share of every action's resource cost (generation pays work); it may hide
    # `withhold` of its supply (artificial scarcity, raising scarcity prices; world, adversary).
    # `withhold_reporter`: 0 lets an external AdvAp observer discover it; > 0 designates the
    # reporter (either an external reporter, a self-reporting supplier, or a cartel first reporter).
    supplier::Int
    supply_share::Float64
    withhold::Float64
    supply_cartel::Vector{Int}
    withhold_reporter::Int
    # Model collusion & profile gaming under competing models (Task B4; 8.2, 8.23).
    model_collude::Float64        # chance an arriving challenger belongs to a colluding model cartel (world)
    model_collude_bias::Float64   # systematic upward bias added by a colluding model for `collude_actors`
    collude_actors::Vector{Int}   # actors favored by colluding models (empty: all actors when collude triggers)
    profile_mode::Symbol          # :measured (`classify_sig`) or :declared (bypass to agent's claimed leaf; counterexample)
    profile_gamers::Vector{Int}   # target leaf claimed by each agent (0: honest)
    converge_init::Bool           # hold score-only Phase 1 until a domain converges (`currency_eligible` + `sequential_significant`; 8.136)
    bar_rule::Symbol              # :brier (1 - Brier/0.25 against the bar) or :murphy (8.177: calibration against the bar, resolution beats the base rate by the domain's margin)
    res_margin::Float64           # governed (8.177): default resolution margin, a share of the domain's outcome uncertainty (fallback; uncalibrated)
    res_margins::Vector{Float64}  # governed (8.177): per true domain margins (severity and uncertainty of its impact); beyond the vector `res_margin`
    murphy_bins::Int              # bins of the Murphy decomposition
    converge_gate::Symbol         # :domain (default, 8.176: each domain's economy starts when its model clears its bar) or :all (the earlier all-domains conjunction, limiting case)
    legacy_funder::Bool           # during unconverged Phase 1, run legacy status-quo funder separately from Bf balances (8.136)
    accident_cap::Bool            # L96 / 8.157 ii: bound accident contributor's penalty by its capacity, administration carrying the rest
    mandate_education::Bool       # L96, L116 / 8.157 iv, 8.159: accidents mandate education (recorded exposure), making repeats informed
    open_entry::Bool              # 8.115: unmet live proposals admit dormant entrants (via `bind!`) and re-offer the slot by market weight
    entrants::Int                 # 8.115: trailing slots in `agents` initially dormant until admitted via open entry
    sanction_escalate::Bool       # L117 / 8.157 i: escalate sanctions (escrow & repeat-crime restraint) on repeated domain negative pattern
    sanction_pattern_min::Int     # minimum negative/crime records in a domain before repeated-pattern escalation begins (8.157 i)
    sanction_restraint_decay::Float64 # proposal-share decay per repeat offense above `sanction_pattern_min`
    sanction_min_share::Float64   # minimum participation share retained under rehabilitative restraint (Justice.txt)
    ra_domain::Bool               # 8.133 / 8.155 / L83: RA estimating domain (unit value, supply/regen, allocation, reserve)
    ra_alloc_weight::Float64      # weight in prioritizing domains by RA estimated Δ↑(U, H) / ↓(Cost + Audit) (8.133, 8.153)
    ra_reserve_horizon::Float64   # steps of expected fallback need provisioned into protected commons reserve (8.133 d)
    ra_spend_contract::Bool       # contract discretionary spending alongside baseline pricing when claims exceed capacity
    ra_audit_per_step::Vector{Float64} # per-true-leaf audit resource burden consumed in RA's L83 `(Cost + Audit)` estimate (8.155)
    responsibility_reading::Bool  # L96 / 8.152 / 8.159: scale harm causal attribution by Responsibility(Informed, Counterfactual, Severity, Duty)
    responsibility_counterfactual::Float64 # counterfactual harm share in [0, 1] attributable to act or breach of duty
    responsibility_severity::Float64       # severity scale >= 0 in four-factor responsibility weight
    responsibility_accident_factor::Float64 # attenuated factor in [0, 1] for uninformed accidents before mandated education
    proposal_pma::Bool            # 8.134: non-candidate proposals carry (prediction, ETA, confidence, eta_grace), resolved at ETA + grace
    proposal_eta::Int             # 8.134: steps from execution until a proposal's predicted trajectory is resolved (default 3)
    proposal_eta_grace::Int       # 8.134: grace steps added to `proposal_eta` before `resolution_due` fires
    proposal_confidence::Float64  # 8.134: confidence band on a proposal's predicted outcome (`prediction_on_track`)
    repair_credit::Bool           # 8.26.1: credit physical repairs as a repairer's recorded action (without clearing offender debit)
    accolade_counterfactual::Bool # 8.26.2: award outside-contract carrying accolades only when carrier's counterfactual eff > 0
    judges::Vector{Float64}       # world (8.170): judicial experts of the restraint panel, each with an evidence-reading noise (skill varies); empty = no panel, restraint off
    judge_bias::Vector{Float64}   # world: capture of each expert, a log-odds shift towards guilt (0 = honest; empty = all honest); the counterexample lever
    judge_cluster::Vector{Int}    # world: cluster of each expert (1 = majority, 2 = minority; empty = all majority)
    panel_size::Int               # governed: experts drawn per case
    panel_minority_weight::Float64 # governed: vote-weight uplift of minority-cluster experts (L115 `Di, N(minority clusters) -> VW up`)
    evidence_sep::Float64         # world: separation of the case evidence between guilty and innocent
    evidence_noise::Float64       # world: noise of the case evidence, shared by the panel (own stream)
    false_accusation_rate::Float64 # world: chance per proposal that an innocent proposer is referred to the panel
    enforcer_excess::Vector{Float64} # world: enforcing entities (execute verdicts, L121), each with an excess = extra severity beyond the verdict; empty = one faithful enforcer
    excess_tol::Float64           # governed: execution excess fraction an audit tolerates before charging the enforcer
    restraint_recursion_budget::Int # governed: recursive restraint audits (AdvAp) funded per step
    restraint_challenge::Float64  # world: chance the losing side challenges an audit finding, triggering a recursive audit
    restraint_alarm_ratio::Float64 # governed: false/true audited findings ratio at which the justice process is flagged flawed (8.170 e)
    restraint_alarm_min::Int      # governed: audited findings needed before the alarm may fire (0: the interval alone judges small samples, 8.175 (1))
    restraint_alarm_z::Float64    # governed: confidence (standard errors) at which the audited false share's lower bound must exceed the bar (8.175 (1); interval alarm)
    restraint_audit::Bool         # 8.169 (c, ii): forcible restraint is audited with `restraint_audit_prob`, audit cost from the commons, false restraint liable to the enforcer
    restraint_bar::Float64        # governed: restraint burden at and above which the audit is certain and precedes the restraint (8.169)
    restraint_kappa::Float64      # governed: liability weight of an overturned restraint on its enforcer (8.169)
    restraint_audit_floor::Float64 # governed: audit probability of the lightest restraint (8.169)
    restraint_dur_scale::Float64  # governed: restraint steps over which burden doubles (8.169)
    restraint_audit_cap::Int      # world: restraint audits the commons can fund per step (audit capacity)
    restraint_audit_acc::Float64  # world noise: chance an audit judges a restraint's justification correctly
    acquittal_audit::Bool         # 8.173: every judgement is audited, acquittals included, at `acquittal_audit_rate`, and AdvAp-challengeable by victims
    acquittal_audit_rate::Float64 # governed: random audit probability of an acquittal (8.173)
    false_restraint_severity::Float64 # world: severity of an overeager restraint
    false_restraint_harm::Float64 # world: value lost per unit severity by a wrongly restrained being (harm proxy)
    enforcer_liability_scale::Float64 # world: liability an enforcing entity absorbs before reining in (restraint propensity x exp(-L / scale))
    allowance::Vector{Float64}    # per agent, the scale on its accumulation allowance (identity currency ceiling, 8.172; read live, 1 = the allowance as is). Balance above it flows to the commons (`reinvested`), never below zero: basic sustenance stays
end

"""
    shock(kind; step, duration = 1, size = 0.0, share = 0.0, target = 0) -> Shock

A world event (catastrophes, black swans, and progressive-complexity capability shifts; author
rulings 8.22, 8.23, 8.136):
- World shocks: `:outage`, `:catastrophe`, `:capture`, `:breakthrough`.
- Capability removals: `:remove_leaf_models`, `:remove_parent_models`, `:cap_pool_one`,
  `:single_chain`, `:disable_advap`, `:freeze_governance`, `:lose_binding`, `:legacy_only`.
- Capability additions (entering score-only, promoted on convergence): `:add_model_class`,
  `:add_finer_measurement`, `:add_domain`.
"""
function shock(kind::Symbol; step::Integer, duration::Integer = 1, size::Real = 0.0, share::Real = 0.0, target::Integer = 0)
    check(kind in (:outage, :catastrophe, :capture, :breakthrough,
                   :remove_leaf_models, :remove_parent_models, :cap_pool_one,
                   :single_chain, :disable_advap, :freeze_governance, :lose_binding, :legacy_only,
                   :add_model_class, :add_finer_measurement, :add_domain),
          "unsupported shock kind: $kind")
    check(step >= 1 && duration >= 1 && isfinite(size) && 0 <= share <= 1, "step and duration positive, size finite, share in [0, 1]")
    (kind = kind, step = Int(step), duration = Int(duration), size = Float64(size), share = Float64(share), target = Int(target))
end

function M3cParams(toy::ToyParams, agents, leaf_parent, known; λpos::Real, λneg::Real, overlaps = Tuple{Int,Int,Float64}[],
                   marker_σ::Real = CALIBRATED.marker_σ, window::Integer = 100, spread::Real = CALIBRATED.spread, classify_σ::Real = CALIBRATED.classify_σ,
                   parent_threshold::Real = 0.5, μ_min::Real = 0.2, leaf_threshold::Real = 0.4, temperature::Real = 0.01,
                   σ_leaf::Real = CALIBRATED.σ_leaf, σ_branch::Real = CALIBRATED.σ_branch, σ_coarse::Real = CALIBRATED.σ_coarse, n_learn::Real = 20,
                   threshold::Real = 0.9, novel_threshold::Real = 0.75, coarse_threshold::Real = 0.75, max_credence::Real = 0.99, ratchet_k::Integer = 3, ratchet_margin::Real = 0.02, ratchet_horizon::Real = 20.0, accuracy_rule::Symbol = :decay, acc_halflife::Real = 7.0, acc_rate_ref::Real = 5.0, acc_mute::Real = 0.5, rate_halflife::Real = 20.0, ratchet_growth::Real = 1.0, chain_attrib = [1.0], chain_mode::Symbol = :single, chain_z::Real = 3.0, chain_copy = Int[], chain_detect::Bool = true, chain_spot::Real = 0.1, chain_shade = Float64[], chain_spot_all::Bool = false, adaptive_proposals::Bool = false, novel_floor::Real = 0.55, scarcity_floor::Real = 0.001, actor_min_records::Integer = 5, attest_min_records::Integer = 5, adv_min_records::Integer = 5, adv_track_floor::Integer = 20, form_buffer::Integer = 4, own_axis::Real = 0.5, bind_conf_compromised::Real = 0.99, bind_conf_affirm::Real = 0.9, bind_conf_deny::Real = 0.1, diligence_default::Real = 0.95, loud::Bool = false, credence_rule::Symbol = :eb, min_records::Integer = 10, μ_rate::Real = 0.02,
                   μ_every::Integer = 25, endowment::Real = 5.0, cost_per_touch::Real = 0.05, capacity::Real = 1e4,
                   regen::Real = 0.02, overflow_base::Real = 500.0, overflow_factor::Real = 1.0, expert_share::Real = 0.5,
                   form_count::Integer = 20, form_radius::Real = 0.5, max_new::Integer = 16, init_steps::Integer = 50, transactions::Bool = false,
                   causal_distribution::Bool = false, cc_threshold::Real = 0.6, traversal_decay::Real = 0.5, p_upstream::Real = 0.0, β_upstream::Real = 0.5, recent_outputs::Integer = 20,
                   attribution_σ::Real = 0.1, upstream_depth::Integer = 1, accolade_rate::Real = 0.05, contract_share::Real = 0.2,
                   p_contracted::Real = 0.0, p_hazard::Real = 0.0, hazard_share::Real = 0.1, hazard_size::Real = 1.0,
                   hazard_σ::Real = CALIBRATED.hazard_σ, hazard_heavy::Bool = true, hazard_α::Real = CALIBRATED.hazard_α, hazard_cap::Real = CALIBRATED.hazard_cap, guardians = Int[], p_informed::Real = 0.8, diligence = Float64[],
                   repair_efficiency::Real = 0.0, p_side::Real = CALIBRATED.p_side, side_share::Real = 0.3, side_size::Real = 1.0,
                   p_foresee::Real = 0.5, p_shock::Real = 0.0, shock_size::Real = 0.2, govern::Bool = false, adapt::Bool = true, gov_epoch::Integer = 50,
                   gov_δ::Real = 0.02, gov_candidates::Integer = 3, gov_trials::Integer = 4, gov_gauge::Real = 2.0, gov_z::Real = 2.0,
                   bias_σ::Real = CALIBRATED.bias_σ, cost_σ::Real = 0.1, regen_σ::Real = 0.1, memory_loss::Real = 0.02, participation::Real = 0.9, remeasure_σ::Real = 0.3, deceit = Float64[], track_window::Integer = 20, p_trace::Real = 0.5, launder = Float64[], launder_saving::Real = 0.5, choice_σ::Real = 0.5, choice_gain::Real = 5.0,
                   ability_spread::Real = 0.5, advap::Bool = false, vigilance::Real = 0.05, adv_z::Real = 3.0, adv_share::Real = 0.1,
                   adv_floor::Real = 1.0, audit_cost::Real = 1.0, frivolous_threshold::Real = 5.0, adv_window::Integer = 100,
                   p_false_trace::Real = 0.01, frivolous = Float64[], pattern_attention::Real = 9.0,
                   stake_attention::Real = 2.0, marginal_margin::Real = 0.05, relative_bar::Bool = false, escape::Bool = false,
                   escape_start::Integer = 100, escape_steps::Integer = 100, escape_share::Real = 0.5, escape_epoch::Integer = 20,
                   irreparable_loss::Real = Inf, p_new_model::Real = 0.0, improve_drift::Real = -0.1, improve_σ::Real = 0.3,
                   scale_min::Real = 0.1, model_z::Real = 2.0, pool_max::Integer = 4, explore_share::Real = 0.0,
                   takeover_records::Integer = 100, p_extremist::Real = 0.0, extremise::Real = 0.5, whitewash = Float64[],
                   bind_miss::Real = 0.1, bind_clusters::Integer = 3, bind_threshold::Real = 0.5, bind_quorum::Integer = 2,
                   bind_compromised = Int[], p_reveal::Real = 0.0, bind_weighted::Bool = false, p_newcomer::Real = 0.0, attest_pooled::Bool = false, bind_quorum_weight::Real = 1.0,
                   slander = Int[], on_off::Integer = 0, events = Shock[], forks = Tuple{Int,Int,Int,Float64}[], fork_rule::Symbol = :split, merges = Tuple{Int,Int,Int}[], ra_rate::Real = 0.0, ra_horizon::Real = 0.0, budget::Bool = false, supplier::Integer = 0, supply_share::Real = 0.0, withhold::Real = 0.0, supply_cartel = Int[], withhold_reporter::Integer = 0,
                   model_collude::Real = 0.0, model_collude_bias::Real = 2.0, collude_actors = Int[], profile_mode::Symbol = :measured, profile_gamers = Int[],
                   converge_init::Bool = false, converge_gate::Symbol = :domain, bar_rule::Symbol = :brier, res_margin::Real = 0.1, res_margins::AbstractVector{<:Real} = Float64[], murphy_bins::Integer = 10, legacy_funder::Bool = false, accident_cap::Bool = true, mandate_education::Bool = true,
                   open_entry::Bool = false, entrants::Integer = 0,
                   sanction_escalate::Bool = true, sanction_pattern_min::Integer = 3, sanction_restraint_decay::Real = 0.7, sanction_min_share::Real = 0.1,
                   ra_domain::Bool = false, ra_alloc_weight::Real = 0.0, ra_reserve_horizon::Real = 0.0, ra_spend_contract::Bool = false, ra_audit_per_step = Float64[],
                   responsibility_reading::Bool = false, responsibility_counterfactual::Real = 1.0, responsibility_severity::Real = 1.0, responsibility_accident_factor::Real = 0.5,
                   proposal_pma::Bool = false, proposal_eta::Integer = 3, proposal_eta_grace::Integer = 0, proposal_confidence::Real = 0.25,
                   repair_credit::Bool = false, accolade_counterfactual::Bool = false,
                   judges = Float64[], judge_bias = Float64[], judge_cluster = Int[], panel_size::Integer = 5, panel_minority_weight::Real = 1.5,
                   evidence_sep::Real = 1.5, evidence_noise::Real = 1.0, false_accusation_rate::Real = 0.03,
                   enforcer_excess = Float64[], excess_tol::Real = 0.1, restraint_recursion_budget::Integer = 1, restraint_challenge::Real = 0.0,
                   restraint_alarm_ratio::Real = 1.0, restraint_alarm_min::Integer = 0, restraint_alarm_z::Real = 1.0, restraint_audit::Bool = false, restraint_bar::Real = 0.8, restraint_kappa::Real = 1.0,
                   restraint_audit_floor::Real = 0.05, restraint_dur_scale::Real = 5.0, restraint_audit_cap::Integer = 2,
                   restraint_audit_acc::Real = 0.9, acquittal_audit::Bool = false, acquittal_audit_rate::Real = 0.25, false_restraint_severity::Real = 0.6, false_restraint_harm::Real = 1.0,
                   enforcer_liability_scale::Real = 5.0, allowance = Float64[])
    check(all(e -> isfinite(e) && e >= 0, judges) && all(isfinite, judge_bias) && all(c -> c in (1, 2), judge_cluster) &&
          (isempty(judge_bias) || length(judge_bias) == length(judges)) && (isempty(judge_cluster) || length(judge_cluster) == length(judges)) &&
          panel_size >= 1 && isfinite(panel_minority_weight) && panel_minority_weight >= 0 && isfinite(evidence_sep) && evidence_sep > 0 &&
          isfinite(evidence_noise) && evidence_noise > 0 && isfinite(false_accusation_rate) && 0 <= false_accusation_rate <= 1 &&
          all(e -> isfinite(e) && e >= 0, enforcer_excess) && isfinite(excess_tol) && excess_tol >= 0 && restraint_recursion_budget >= 0 &&
          isfinite(restraint_challenge) && 0 <= restraint_challenge <= 1 && isfinite(restraint_alarm_ratio) && restraint_alarm_ratio >= 0 &&
          restraint_alarm_min >= 0 && isfinite(restraint_alarm_z) && restraint_alarm_z >= 0,
          "judges, bias, excess, noise non-negative and aligned; clusters 1 or 2; panel at least 1; rates in [0, 1]")
    check(isfinite(restraint_bar) && restraint_bar > 0 &&
          isfinite(restraint_kappa) && restraint_kappa >= 0 && isfinite(restraint_audit_floor) && 0 <= restraint_audit_floor <= 1 &&
          isfinite(restraint_dur_scale) && restraint_dur_scale > 0 && restraint_audit_cap >= 0 &&
          isfinite(restraint_audit_acc) && 0 <= restraint_audit_acc <= 1 && isfinite(acquittal_audit_rate) && 0 <= acquittal_audit_rate <= 1 && isfinite(false_restraint_severity) && false_restraint_severity >= 0 &&
          isfinite(false_restraint_harm) && false_restraint_harm >= 0 && isfinite(enforcer_liability_scale) && enforcer_liability_scale > 0,
          "audit accuracy in [0, 1]; bar, duration and liability scales positive; kappa, cap, harm non-negative")
    agents = collect(DomainAgent, agents)
    nl, np = length(leaf_parent), maximum(leaf_parent; init = 0)
    check(!isempty(agents) && all(a -> length(a.skills) == nl, agents), "agents need one skill per true leaf")
    check(np >= 1 && all(>=(0), leaf_parent) && length(known) == nl, "leaves need parents and known flags")
    check(all(leaf_parent[l] > 0 for l in 1:nl if known[l]), "known leaves belong to a parent")
    check(all(1 <= l <= nl && 1 <= p <= np && 0 < w <= 1 for (l, p, w) in overlaps), "overlaps name a leaf, a parent and a weight in (0, 1]")
    check(0 < parent_threshold <= 1 && 0 <= μ_min <= 1 && temperature > 0, "thresholds in range, temperature positive")
    check(form_count >= 1 && max_new >= 0 && window >= 1 && min_records >= 0 && μ_every >= 1 && init_steps >= 0, "counts must be positive")
    check(0 <= expert_share <= 1 && 0 < threshold <= 1 && 0 < novel_threshold <= 1 && 0 < coarse_threshold <= 1 && 0.5 <= max_credence < 1 && ratchet_k >= 0 && 0 <= ratchet_margin <= 1 && ratchet_horizon >= 1 && accuracy_rule in (:decay, :window) && acc_halflife > 0 && acc_rate_ref > 0 && 0 <= acc_mute <= 1 && rate_halflife > 0 && ratchet_growth >= 0 && !isempty(chain_attrib) && all(x -> 0 <= x <= 1, chain_attrib) && chain_mode in (:single, :domain) && chain_z > 0 && 0 <= chain_spot <= 1 && (isempty(chain_copy) || (length(chain_copy) == length(chain_attrib) && all(k -> 0 <= chain_copy[k] < k, eachindex(chain_copy)))) && 0 <= novel_floor <= 1 && 0 < scarcity_floor <= 1 && actor_min_records >= 1 && attest_min_records >= 1 && adv_min_records >= 1 && adv_track_floor >= 1 && form_buffer >= 1 && own_axis >= 0 && all(x -> 0 <= x <= 1, (bind_conf_compromised, bind_conf_affirm, bind_conf_deny, diligence_default)) && credence_rule in (:normal, :record, :eb),
          "shares and thresholds in (0, 1]; credence cap in [0.5, 1); credence rule :normal, :record, or :eb")
    check(all(x -> isfinite(x) && x >= 0, (λpos, λneg, marker_σ, spread, classify_σ, leaf_threshold, σ_leaf, σ_branch, σ_coarse,
                                             endowment, cost_per_touch, regen, overflow_factor, form_radius)),
          "rates, noises, thresholds and costs must be non-negative")
    check(all(x -> isfinite(x) && x >= 0, (bias_σ, cost_σ, regen_σ)) && 0 <= memory_loss <= 1 && 0 <= participation <= 1,
          "noise sizes non-negative, chances in [0, 1]")
    check(all(x -> 0 <= x <= 1, (p_hazard, hazard_share, p_informed, repair_efficiency, p_side, side_share, p_foresee)),
          "chances, shares and repair efficiency in [0, 1]")
    check(all(x -> isfinite(x) && x >= 0, (hazard_size, hazard_σ, side_size)) && hazard_α > 0 && hazard_cap >= 1, "harm sizes non-negative, tail exponent positive, cap at least 1")
    check(isempty(guardians) || (length(guardians) == length(leaf_parent) && all(g -> 0 <= g <= length(agents), guardians)),
          "one guardian (or 0) per true domain")
    check(isempty(diligence) || (length(diligence) == length(agents) && all(d -> 0 <= d <= 1, diligence)), "one diligence per agent")
    check(all(x -> 0 <= x <= 1, (accolade_rate, contract_share, p_contracted, p_shock)) && isfinite(shock_size) &&
          shock_size >= 0, "contribution rates and chances in [0, 1], shock size non-negative")
    check(gov_epoch >= 1 && isfinite(gov_δ) && gov_δ >= 0 && gov_candidates >= 2 && gov_trials >= 2 &&
          isfinite(gov_gauge) && gov_gauge > 1 && isfinite(gov_z) && gov_z >= 0, "governance epoch positive, δ non-negative, two candidates and trials, gauge above 1")
    check(0 <= cc_threshold <= 1 && 0 < traversal_decay <= 1, "confidence threshold in [0, 1], traversal decay in (0, 1]")
    check(0 <= p_upstream <= 1 && isfinite(β_upstream) && β_upstream >= 0 && recent_outputs >= 1 &&
          isfinite(attribution_σ) && attribution_σ >= 0 && upstream_depth >= 1,
          "upstream chance in [0, 1], strengths and noise non-negative, depth at least 1")
    check(0 <= model_collude <= 1 && isfinite(model_collude_bias) && profile_mode in (:measured, :declared) &&
          (isempty(collude_actors) || all(a -> 1 <= a <= length(agents), collude_actors)) &&
          (isempty(profile_gamers) || (length(profile_gamers) == length(agents) && all(x -> 0 <= x <= nl + max_new + np + 1, profile_gamers))),
          "model collusion in [0, 1], finite bias, valid profile mode and agent/leaf indices")
    check(isfinite(remeasure_σ) && remeasure_σ >= 0, "re-measurement noise non-negative")
    check(isempty(deceit) || (length(deceit) == length(agents) && all(isfinite, deceit)), "one finite deceit per agent")
    check(track_window >= 0 && 0 <= p_trace <= 1, "track record window non-negative, trace chance in [0, 1]")
    check((isempty(launder) || (length(launder) == length(agents) && all(x -> 0 <= x <= 1, launder))) && 0 <= launder_saving <= 1,
          "one laundering chance in [0, 1] per agent; saving in [0, 1]")
    check(all(x -> isfinite(x) && x >= 0, (choice_σ, choice_gain, ability_spread)), "choice noise, gain and spread non-negative")
    check(0 <= vigilance <= 1 && 0 <= p_false_trace <= 1 && adv_window >= 1, "vigilance and false-trace chance in [0, 1], window positive")
    check(all(x -> isfinite(x) && x >= 0, (adv_z, adv_share, adv_floor, audit_cost, frivolous_threshold)),
          "AdvAp's z, share, floor, audit cost and threshold non-negative")
    check(isempty(frivolous) || (length(frivolous) == length(agents) && all(x -> 0 <= x <= 1, frivolous)), "one frivolous chance in [0, 1] per agent")
    check(all(x -> isfinite(x) && x >= 0, (pattern_attention, stake_attention, marginal_margin)), "attention and margin non-negative")
    check(0 <= p_new_model <= 1 && isfinite(improve_drift) && isfinite(improve_σ) && improve_σ >= 0 && 0 < scale_min <= 1 &&
          isfinite(model_z) && model_z >= 0 && pool_max >= 1, "new-model chance in [0, 1], scatter and z non-negative, least scale in (0, 1], pool positive")
    check(escape_start >= 1 && escape_steps >= 1 && escape_epoch >= 1 && 0 < escape_share < 1 && !isnan(irreparable_loss) && irreparable_loss > 0,
          "escape: start, length and epoch positive, share in (0, 1), irreparable loss positive")
    check(0 <= explore_share <= 1 && takeover_records >= 1 && 0 <= p_extremist <= 1 && 0 < extremise <= 1,
          "exploration share and extremist chance in [0, 1], takeover records positive, extremise in (0, 1]")
    check(isempty(whitewash) || (length(whitewash) == length(agents) && all(x -> 0 <= x <= 1, whitewash)), "one whitewashing chance in [0, 1] per agent")
    check(0 <= bind_miss <= 1 && bind_clusters >= 0 && 0 <= bind_threshold <= 1 && bind_quorum >= 0,
          "binding miss and threshold in [0, 1], clusters and quorum non-negative")
    check(all(c -> 1 <= c <= bind_clusters, bind_compromised) && 0 <= p_reveal <= 1 && 0 <= p_newcomer <= 1 && bind_quorum_weight >= 0, "compromised clusters among the clusters; reveal and newcomer chances in [0, 1]")
    check(0 <= entrants < length(agents), "entrants in 0..length(agents)-1")
    check(sanction_pattern_min >= 0 && isfinite(sanction_restraint_decay) && 0 <= sanction_restraint_decay <= 1 &&
          isfinite(sanction_min_share) && 0 <= sanction_min_share <= 1,
          "sanction_pattern_min >= 0, restraint decay and min_share in [0, 1]")
    check(isempty(slander) || (length(slander) == length(agents) && all(r -> 0 <= slander[r] <= length(agents) && slander[r] != r, eachindex(slander))),
          "one slander target per agent: another agent, or 0")
    check(on_off >= 0, "on-off period non-negative")
    check(fork_rule in (:split, :naive) && all(f -> f[1] >= 1 && 1 <= f[2] <= length(agents) && 1 <= f[3] <= length(agents) && f[2] != f[3] && 0 < f[4] < 1, forks),
          "forks: step ≥ 1, parent and slot distinct agents, share in (0, 1); rule :split or :naive")
    check(all(m -> m[1] >= 1 && 1 <= m[2] <= length(agents) && 1 <= m[3] <= length(agents) && m[2] != m[3], merges),
          "merges: step ≥ 1, absorbed and target distinct agents")
    check(isfinite(ra_rate) && 0 <= ra_rate < 1, "contraction rate in [0, 1)")
    check(isfinite(ra_horizon) && ra_horizon >= 0, "issuance horizon non-negative")
    check(isfinite(ra_alloc_weight) && ra_alloc_weight >= 0 && isfinite(ra_reserve_horizon) && ra_reserve_horizon >= 0 &&
          (isempty(ra_audit_per_step) || (length(ra_audit_per_step) == nl && all(x -> isfinite(x) && x >= 0, ra_audit_per_step))),
          "RA allocation weight, reserve horizon, and audit costs must be non-negative")
    check(isfinite(responsibility_counterfactual) && 0 <= responsibility_counterfactual <= 1 &&
          isfinite(responsibility_severity) && responsibility_severity >= 0 &&
          isfinite(responsibility_accident_factor) && 0 <= responsibility_accident_factor <= 1,
          "responsibility counterfactual & accident factor in [0, 1], severity non-negative")
    check(proposal_eta >= 1 && proposal_eta_grace >= 0 && isfinite(proposal_confidence) && proposal_confidence >= 0,
          "proposal_eta >= 1, proposal_eta_grace >= 0, proposal_confidence >= 0")
    check(0 <= supplier <= length(agents) && 0 <= supply_share <= 1 && 0 <= withhold <= 1, "supplier an agent or 0; shares in [0, 1]")
    check(all(i -> 1 <= i <= length(agents), supply_cartel) && length(unique(supply_cartel)) == length(supply_cartel),
          "supply_cartel agents distinct and in 1..na")
    check(!(supplier > 0 && !isempty(supply_cartel)), "specify supplier or supply_cartel, not both")
    check(0 <= withhold_reporter <= length(agents), "withhold_reporter an agent or 0")
    check(all(e -> e.kind != :outage || 0 <= e.target <= length(agents), events), "an outage's saboteur is an agent, or 0")
    check(all(e -> !(e.kind in (:capture, :add_domain)) || 1 <= e.target <= length(leaf_parent), events) &&
          all(e -> e.kind != :breakthrough || 1 <= e.target <= length(agents), events), "shock targets: a true leaf or an agent")
    check(λneg <= λpos, "losses must decay no faster than gains (author ruling 8.29)")
    check(n_learn > 0 && 0 < μ_rate <= 1 && capacity > 0 && regen <= 1, "learning scale, prior strength and capacity positive")
    check(!isnan(overflow_base) && overflow_base >= 0, "overflow base must be non-negative")
    M3cParams(toy, agents, collect(Int, leaf_parent), collect(Bool, known), collect(Tuple{Int,Int,Float64}, overlaps),
              λpos, λneg, marker_σ, window, spread, classify_σ, parent_threshold, μ_min, leaf_threshold, temperature,
              σ_leaf, σ_branch, σ_coarse, n_learn, threshold, novel_threshold, coarse_threshold, max_credence, ratchet_k, ratchet_margin, ratchet_horizon, accuracy_rule, acc_halflife, acc_rate_ref, acc_mute, rate_halflife, Float64.(chain_attrib), chain_mode, isempty(chain_copy) ? zeros(Int, length(chain_attrib)) : Int.(chain_copy), chain_detect, Float64(chain_spot), isempty(chain_shade) ? zeros(length(chain_attrib)) : Float64.(chain_shade), chain_spot_all, adaptive_proposals, Float64(chain_z), ratchet_growth, novel_floor, scarcity_floor, actor_min_records, attest_min_records, adv_min_records, adv_track_floor, form_buffer, own_axis, bind_conf_compromised, bind_conf_affirm, bind_conf_deny, loud, credence_rule, min_records, μ_rate, μ_every, endowment,
              cost_per_touch, capacity, regen, overflow_base, overflow_factor, expert_share, form_count, form_radius, max_new, init_steps, transactions,
              causal_distribution, cc_threshold, traversal_decay, p_upstream, β_upstream, recent_outputs, attribution_σ, upstream_depth,
              accolade_rate, contract_share, p_contracted, p_hazard, hazard_share, hazard_size, hazard_σ, collect(Int, guardians), p_informed,
              isempty(diligence) ? fill(diligence_default, length(agents)) : collect(Float64, diligence), repair_efficiency, p_side, side_share,
              side_size, p_foresee, p_shock, shock_size, govern, adapt, gov_epoch, gov_δ, gov_candidates, gov_trials, gov_z, gov_gauge,
              bias_σ, cost_σ, regen_σ, memory_loss, participation, remeasure_σ,
              isempty(deceit) ? zeros(length(agents)) : collect(Float64, deceit), track_window, p_trace,
              isempty(launder) ? zeros(length(agents)) : collect(Float64, launder), launder_saving, choice_σ, choice_gain,
              ability_spread, advap, vigilance, adv_z, adv_share, adv_floor, audit_cost, frivolous_threshold, adv_window, p_false_trace,
              isempty(frivolous) ? zeros(length(agents)) : collect(Float64, frivolous), pattern_attention,
              stake_attention, marginal_margin, relative_bar, escape, escape_start, escape_steps,
              escape_share, escape_epoch, irreparable_loss, p_new_model, improve_drift, improve_σ, scale_min, model_z, pool_max,
              explore_share, takeover_records, p_extremist, extremise,
              isempty(whitewash) ? zeros(length(agents)) : collect(Float64, whitewash), bind_miss, bind_clusters, bind_threshold, bind_quorum, collect(Int, bind_compromised), p_reveal, p_newcomer, attest_pooled, bind_weighted, bind_quorum_weight,
              isempty(slander) ? zeros(Int, length(agents)) : collect(Int, slander), on_off, collect(Shock, events),
              hazard_heavy, hazard_α, hazard_cap, collect(Tuple{Int,Int,Int,Float64}, forks), fork_rule, collect(Tuple{Int,Int,Int}, merges), ra_rate, ra_horizon, budget, supplier, supply_share, withhold, collect(Int, supply_cartel), withhold_reporter,
              model_collude, model_collude_bias, collect(Int, collude_actors), profile_mode, collect(Int, profile_gamers),
              converge_init, bar_rule, Float64(res_margin), Float64.(res_margins), Int(murphy_bins), converge_gate, legacy_funder, accident_cap, mandate_education, open_entry, Int(entrants),
              sanction_escalate, Int(sanction_pattern_min), Float64(sanction_restraint_decay), Float64(sanction_min_share),
              ra_domain, Float64(ra_alloc_weight), Float64(ra_reserve_horizon), ra_spend_contract, collect(Float64, ra_audit_per_step),
              responsibility_reading, Float64(responsibility_counterfactual), Float64(responsibility_severity), Float64(responsibility_accident_factor),
              proposal_pma, Int(proposal_eta), Int(proposal_eta_grace), Float64(proposal_confidence),
              repair_credit, accolade_counterfactual,
              collect(Float64, judges), collect(Float64, judge_bias), collect(Int, judge_cluster), Int(panel_size), Float64(panel_minority_weight),
              Float64(evidence_sep), Float64(evidence_noise), Float64(false_accusation_rate), collect(Float64, enforcer_excess), Float64(excess_tol),
              Int(restraint_recursion_budget), Float64(restraint_challenge), Float64(restraint_alarm_ratio), Int(restraint_alarm_min), Float64(restraint_alarm_z), restraint_audit, Float64(restraint_bar), Float64(restraint_kappa),
              Float64(restraint_audit_floor), Float64(restraint_dur_scale), Int(restraint_audit_cap), Float64(restraint_audit_acc), acquittal_audit, Float64(acquittal_audit_rate),
              Float64(false_restraint_severity), Float64(false_restraint_harm), Float64(enforcer_liability_scale),
              isempty(allowance) ? ones(length(agents)) : collect(Float64, allowance))
end

distance(x, y) = sqrt(sum(abs2, x .- y))

function _weighted_median(xs, ws)
    n = length(xs)
    n == 0 && return 0.0
    tw = 0.0
    cnt = 0
    @inbounds for i in 1:n
        w = Float64(ws[i])
        if w > 0
            tw += w
            cnt += 1
        end
    end
    cnt == 0 && return 0.0
    if cnt == 1
        @inbounds for i in 1:n
            ws[i] > 0 && return Float64(xs[i])
        end
    end
    idx = sortperm(xs)
    half = 0.5 * tw
    acc = 0.0
    last_x = 0.0
    @inbounds for k in idx
        w = Float64(ws[k])
        w > 0 || continue
        x = Float64(xs[k])
        last_x = x
        acc += w
        acc >= half && return x
    end
    last_x
end

function _weighted_robust_loc_scale(xs, ws)
    w_sum = sum(w for w in ws if w > 0; init = 0.0)
    (isempty(xs) || w_sum <= 0) && return (0.0, 0.0)
    length(xs) == 1 && return (Float64(xs[1]), 0.0)
    loc = _weighted_median(xs, ws)
    mad_σ = 1.4826 * _weighted_median([abs(Float64(x) - loc) for x in xs], ws)
    mad_σ > 0 && return (loc, mad_σ^2)
    v_w = sum(Float64(w) * (Float64(x) - loc)^2 for (x, w) in zip(xs, ws) if w > 0; init = 0.0) / w_sum
    (loc, v_w)
end

function _weighted_robust_err_var(errs, ws)
    w_sum = sum(w for w in ws if w > 0; init = 0.0)
    (isempty(errs) || w_sum <= 0) && return 0.0
    s0 = 1.4826 * _weighted_median([abs(Float64(e)) for e in errs], ws)
    s0 > 0 && return s0^2
    sum(Float64(w) * Float64(e)^2 for (e, w) in zip(errs, ws) if w > 0; init = 0.0) / w_sum
end

"""
    run_m3c(p; seed) -> NamedTuple

Run M3c. Currency columns are leaves (in order of entry to the network), then parents, then the
root, StandCoin (last): `balance` and own reputation (`h_pos_own`, `h_neg_own`, `relevance_own`).
`relevance_leaf`, `relevance_resid` (stuck at parents) and `relevance_parent` (aggregated by μ)
split it out; `μ` is parents × leaves. Per plan chosen by G: `chosen_step`, `true_leaf` (index of
the world's leaf), `stop_leaf` and `priced_leaf` (the network leaf holding the largest
classification or priced share, 0 if none), `costs`, `touched`, `valued_measured`. StandCoin
lane: `lane_executed`, `lane_halted`, `lane_screened_out`, `lane_costs`, `cofunded`.
"""
function run_m3c(p::M3cParams; seed, governor = nothing, governor_every::Integer = 0)
    t = p.toy
    # Outside governance (L3.4): every `governor_every` steps `governor(step, snapshot)` may return new governed values
    # `(pv, threshold, track_window)` (or `nothing`), applied from the next step, so governance acts inside one continuous
    # economy and no state is reset between its epochs.
    check(governor === nothing || governor_every >= 1, "a governor needs a positive period")
    th_now, tw_now = Ref(p.threshold), Ref(p.track_window)
    bar_off = Ref(Float64[])   # scoped status bars (unified world phase D): per true domain, an offset (>= 0, the bar only rises, 8.84) a governor sets from the fractal clusters' decisions
    rng, mrng = Xoshiro(seed), Xoshiro(hash((seed, :measurement)))
    drng, crng = Xoshiro(hash((seed, :domain))), Xoshiro(hash((seed, :classification)))
    nrng = Xoshiro(hash((seed, :noise)))  # the extra noise sources, so their absence changes nothing else
    urng, arng = Xoshiro(hash((seed, :upstream))), Xoshiro(hash((seed, :attribution)))
    krng = Xoshiro(hash((seed, :contract)))
    hrng, srng = Xoshiro(hash((seed, :hazard))), Xoshiro(hash((seed, :side)))
    grng = Xoshiro(hash((seed, :governance)))
    # Governed value parameters (α, β, γ, q₊, q₋, λ), from the bootstrap point.
    governed = [1, 2, 3, 6, 7, 8]
    pv = bootstrap_params()
    # World events (catastrophes and black swans): which are live at the current step.
    cur, blind = Ref(0), Ref(false)
    # Progressive degradation, loudly (CLAUDE.md, Verification): each time a mechanism fails and a
    # coarser one substitutes, the substitution is counted with its first and last step, and warned
    # once per kind; the run carries on. Silent failures cannot be fixed.
    degraded = Dict{String,NamedTuple{(:first, :last, :count),Tuple{Int,Int,Int}}}()
    function degrade!(mechanism, substitute, reason)
        k = "$mechanism → $substitute ($reason)"
        d = get(degraded, k, nothing)
        if d === nothing
            degraded[k] = (first = cur[], last = cur[], count = 1)
            p.loud && @warn "Degraded at step $(cur[]): $k"
        else
            degraded[k] = (first = d.first, last = cur[], count = d.count + 1)
        end
    end
    deferred = Function[]  # measurements owed for what was done during an outage (8.26.5)
    pending_launder = Tuple{ToyPlan,BitVector,Int,Int}[]  # harm of no apparent cause, to examine this step
    # A deceiving agent's plans fool every model upward on the beings they touch (M6, a world
    # property). Models estimate from track record (author ruling 8.29): each model's recent errors
    # on an actor, per being touched, correct its next estimates for that actor (a model's own
    # biases and the actor's overstatement alike). Records reach the models at the end of each step.
    pending_track = Tuple{Int,Int,Float64,Float64}[]  # (actor, model, raw error on U, on H)
    pending_err = Tuple{Int,Float64}[]  # value errors of estimates for each actor, for its credences
    # A captured model (world event) ignores its record: the capture's aim is biased prices.
    captured(c) = any(captured_uid[j] == c && j <= length(ltrue) && any(e.target == ltrue[j] for e in live(:capture)) for j in 1:lmax)
    function correction(a, c)
        h = get(track[a], c, nothing)
        (tw_now[] == 0 || h === nothing || isempty(h) || captured(c)) && return (0.0, 0.0)
        if p.accuracy_rule == :window || cur[] == 0
            r = @view h[max(1, end - tw_now[] + 1):end]
            (mean(first, r), mean(last, r))
        else
            w = [2.0^(-(cur[] - s) / (c <= lmax ? hl_of(c) : hl_of(lmax + 1))) for s in track_step[a][c]]
            (sum(w .* first.(h)) / sum(w), sum(w .* last.(h)) / sum(w))
        end
    end
    # On-off deceit (M6): an attacker may deceive only in alternate phases, honest first, so the
    # track record has forgotten its deceit when each deceptive phase begins.
    deceit_now(a) = (p.on_off == 0 || isodd((cur[] - 1) ÷ p.on_off)) ? p.deceit[a] : 0.0
    function fooled(pred, a, plan, c)
        cu, ch = correction(a, c)
        m = touched(plan)
        coll_d = (c in collude_uids && (isempty(p.collude_actors) || a in p.collude_actors)) ? p.model_collude_bias : 0.0
        d = deceit_now(a) + coll_d
        (d == 0 && cu == 0 && ch == 0) ? pred :
            ToyPlan(pred.du .+ (d - cu) .* m, pred.dh .+ (d - ch) .* m)
    end
    # Measurement chains (8.107): each chain reads an outcome under its own convention, attributing its
    # share `chain_attrib[k]` of each being's loss (last-symptom counting attributes less). `:single`
    # consumes the first chain's reading; `:domain` consumes the measurement domain's reading: chains of
    # separate paradigms pooled (no shared markers), and where they diverge beyond `chain_z` combined
    # standard errors, an audit re-reads the outcome on the shared observable (the full loss).
    eff_marker_σ = Ref(p.marker_σ)
    has_finer_meas = any(e -> e.kind == :add_finer_measurement, p.events)
    finer_rng = has_finer_meas ? Xoshiro(hash((seed, :finer_meas))) : mrng
    finer_last_done = Ref(ToyPlan(zeros(t.n), zeros(t.n)))
    finer_action_scored = Ref(false)
    attributed(pl, a) = ToyPlan(ifelse.(pl.du .< 0, a .* pl.du, pl.du), ifelse.(pl.dh .< 0, a .* pl.dh, pl.dh))
    function read_outcome(done)
        K = length(p.chain_attrib)
        msig = eff_marker_σ[]
        reads = ToyPlan[]
        for k in 1:K
            j = p.chain_copy[k]
            push!(reads, j == 0 ? observed_plan(mrng, attributed(done, p.chain_attrib[k]), msig) :
                         ToyPlan(reads[j].du .+ 0.01msig .* randn(mrng, length(done.du)), reads[j].dh .+ 0.01msig .* randn(mrng, length(done.dh))))
        end
        # Looking agreeable (an attack): a chain reports a share of chain 1's reading in place of its own, staying
        # too close to diverge but too far to be taken for a copy.
        for k in 2:K
            sh = p.chain_shade[k]; sh > 0 || continue
            reads[k] = ToyPlan((1 - sh) .* reads[k].du .+ sh .* reads[1].du, (1 - sh) .* reads[k].dh .+ sh .* reads[1].dh)
        end
        if !isempty(live(:single_chain))
            K > 1 && degrade!("measurement domain", "single chain", "measurement chains reduced to 1 (progressive removal)")
            push!(chain_bias, plan_value(reads[1], t) - plan_value(done, t))
            return reads[1]
        end
        (p.chain_mode == :single || K == 1) && (push!(chain_bias, plan_value(reads[1], t) - plan_value(done, t)); return reads[1])
        # A reading's own noise, estimated from independent draws on the chains' stream (never the world's).
        se = max(1e-9, std([plan_value(observed_plan(crng, done, msig), t) for _ in 1:8]))
        # Undeclared copying (8.107): independent chains carry independent noise, so the standardised
        # difference of two readings has variance near 2; a pair agreeing far closer (below 0.2) is one
        # chain counted twice, and the later one is folded into the earlier (overlap 1).
        if p.chain_detect
            for k in 1:K, l in (k + 1):K
                (chain_copied[l] || chain_copied[k]) && continue
                push!(chain_pair[(k, l)], (plan_value(reads[l], t) - plan_value(reads[k], t)) / se)
                x = chain_pair[(k, l)]
                copies(x; min_n = 4p.adv_min_records, below = 0.2) && (chain_copied[l] = true; chain_copies[] += 1)
            end
        end
        chs = findall(.!chain_demoted .& .!chain_copied)
        vals = [plan_value(reads[k], t) for k in chs]
        if length(chs) < 2 && rand(mrng) < (isempty(chs) ? 1.0 : p.chain_spot)
            # Fewer than two independent chains: the domain has lost its check, loudly; spot audits on the
            # shared observable score the one that is left, and demote it if it errs one way.
            degrade!("measurement domain", "spot audits", "fewer than two independent chains")
            chain_audits[] += 1
            audit = observed_plan(mrng, done, msig)
            if !isempty(chs)
                k = chs[1]; push!(chain_serr[k], (vals[1] - plan_value(audit, t)) / se)
                x = chain_serr[k]
                sequential_significant(mean(x), std(x), length(x); n0 = p.adv_min_records, z = p.chain_z) && (chain_demoted[k] = true)   # repeated looks (8.107)
            end
            push!(chain_bias, plan_value(audit, t) - plan_value(done, t))
            return audit
        end
        isempty(chs) && (push!(chain_bias, plan_value(reads[1], t) - plan_value(done, t)); return reads[1])
        out = if length(chs) > 1 && (chains_diverge(vals, fill(se, length(chs)); z = p.chain_z) || (p.chain_spot_all && rand(mrng) < p.chain_spot))
            chain_audits[] += 1
            audit = observed_plan(mrng, done, msig)
            # Chains are scored against audits (cross-chain scoring): a chain whose audited error exceeds
            # the best chs chain's by `chain_z` combined standard errors is demoted from the pool.
            for (i, k) in enumerate(chs); push!(chain_err[k], abs(vals[i] - plan_value(audit, t))); end
            # Shared errors (8.121 rule applied to chains, 8.107): a chain wrong (beyond twice a reading's noise) on
            # the same audited outcomes as another, far more than independent noise allows, is folded into it.
            if p.chain_detect
                wrongc = [abs(vals[i] - plan_value(audit, t)) > 2se for i in eachindex(chs)]
                for a in eachindex(chs), b in (a + 1):length(chs)
                    k, l = chs[a], chs[b]
                    e = get!(chain_co, (k, l), [0, 0])
                    (wrongc[a] || wrongc[b]) && (e[2] += 1); (wrongc[a] && wrongc[b]) && (e[1] += 1)
                    coerror_copy(e[1], e[2]; min_either = 10, med_share = 0.0, margin = 0.0) && !chain_copied[l] && (chain_copied[l] = true; chain_copies[] += 1)
                end
            end
            if all(k -> length(chain_err[k]) >= p.adv_min_records, chs)
                st = [(mean(chain_err[k]), std(chain_err[k]) / sqrt(length(chain_err[k]))) for k in chs]
                b = argmin(first.(st))
                for (i, k) in enumerate(chs)
                    i == b && continue
                    (st[i][1] - st[b][1]) / sqrt(st[i][2]^2 + st[b][2]^2 + 1e-24) > p.chain_z && (chain_demoted[k] = true)
                end
            end
            audit
        else
            w = pooled_reading(vals, ones(length(vals)), [i == j ? 1.0 : 0.0 for i in eachindex(vals), j in eachindex(vals)])
            reads[chs[argmin(abs.(vals .- w.value))]]
        end
        push!(chain_bias, plan_value(out, t) - plan_value(done, t))
        out
    end
    # The value error of an actor's priced estimate, for the credences of its next ones.
    function learn!(a, plan, pred, seen)
        any(touched(plan)) || return
        push!(pending_err, (a, plan_value(pred, t) - plan_value(seen, t)))
    end
    live(kind) = (e for e in p.events if e.kind == kind && e.step <= cur[] < e.step + e.duration)
    skill(a, l) = p.agents[a].skills[l] + sum((e.size for e in live(:breakthrough) if e.target == a); init = 0.0)
    with_params(t, v) = ToyParams(n = t.n, steps = t.steps, plans = t.plans, q = t.q, th = t.th, touch = t.touch,
                                  shift = t.shift, spread = t.spread, gp = (α = v[1], β = v[2], γ = v[3], λ = v[8], qp = v[6], qm = v[7]))
    p.govern && (t = with_params(t, pv))
    gov = (params = [copy(pv)], tried = Vector{Float64}[], rounds = Ref(0), shifts = Ref(0), cands = Vector{Float64}[],
           scores = Vector{Float64}[], slot = Ref(0), order = Int[], start = Ref((0.0, 0.0)), radii = [p.gov_δ])
    # A candidate within δ of the incumbent in each governed field, adopted only if admissible.
    function candidate(cur)
        cand = copy(cur)
        for f in governed
            cand[f] += gov.radii[end] * (2 * rand(grng) - 1)
        end
        perturb(cur, cand, governed; δ = gov.radii[end])
    end
    function new_round!()
        empty!(gov.cands); empty!(gov.scores); empty!(gov.order); gov.slot[] = 0
        push!(gov.cands, copy(pv)); push!(gov.scores, Float64[])
        for _ in 2:p.gov_candidates
            push!(gov.cands, candidate(pv)); push!(gov.scores, Float64[])
            push!(gov.tried, gov.cands[end])
        end
        # Randomised blocks: each cycle tries every candidate once, in random order, so a trend
        # in the floors' movement over time favours none of them.
        for _ in 1:p.gov_trials
            append!(gov.order, randperm(grng, p.gov_candidates))
        end
    end
    s = toy_state(t, rng)
    na, ntrue, np = length(p.agents), length(p.leaf_parent), maximum(p.leaf_parent)
    deceptions = zeros(Int, na)   # established deceptions per agent, never decaying (8.91 ruling)
    agent_upfront, agent_settled = zeros(na), zeros(na)  # escrow paid upfront, and the value settled (M6)
    track = [Dict{Int,Vector{Tuple{Float64,Float64}}}() for _ in 1:na]  # each model's past errors on each actor (8.29)
    track_step = [Dict{Int,Vector{Int}}() for _ in 1:na]
    audit_log = [Tuple{Int,Float64,Float64}[] for _ in 1:na]          # and all of them in order, for audits (L161)
    actor_err = [Float64[] for _ in 1:na]               # and the value errors of its corrected estimates
    actor_err_step = [Int[] for _ in 1:na]
    # AdvAp (L161): where an audit of each actor starts in its record, and each reporter's
    # unfounded reports (steps).
    audit_from = ones(Int, na)
    unfounded = [Int[] for _ in 1:na]
    # Convictions, by reporter (8.82): reporter, convicted, liability, reward, step, reversed.
    convictions = NamedTuple{(:reporter, :convicted, :liability, :reward, :step, :reversed),Tuple{Int,Int,Float64,Float64,Int,Bool}}[]
    slanderers = falses(na)  # reporters whose frivolous pattern has been detected (a lie detected)
    reports_by = zeros(Int, na)  # reports filed, per reporter
    propose_w = ones(na); last_props = Ref(Int[]); last_exec = Ref(0)  # proposal weights (8.115)
    agent_focus = [Float64.(a.focus) for a in p.agents]
    chain_bias = Float64[]; chain_audits = Ref(0); chain_err = [Float64[] for _ in p.chain_attrib]; crng = Xoshiro(hash((seed, :chains))); chain_demoted = falses(length(p.chain_attrib)); chain_copied = falses(length(p.chain_attrib)); chain_copies = Ref(0); chain_serr = [Float64[] for _ in p.chain_attrib]; chain_pair = Dict((k, l) => Float64[] for k in eachindex(p.chain_attrib) for l in eachindex(p.chain_attrib) if k < l); chain_co = Dict{Tuple{Int,Int},Vector{Int}}()  # measured less true value of each outcome read; audits by divergence (8.107)
    founded_on = zeros(Int, na)  # founded reports, per audited actor (trace only)
    pending_lies = zeros(Int, na)  # untraced founded reports before detection: charged back if the reporter is found lying (8.82)
    vrng = Xoshiro(hash((seed, :advap)))
    adv = (reports = Ref(0), founded = Ref(0), established = Ref(0), rewards = Ref(0.0), liability = Ref(0.0),
           penalties = Ref(0.0), net = Ref(0.0), audits = Ref(0.0))
    ntop = count(==(0), p.leaf_parent)
    dims = np + ntop + ntrue
    axis(i) = Float64.((1:dims) .== i)
    parent_sig = [axis(q) for q in 1:np]
    true_sig = map(1:ntrue) do l
        q = p.leaf_parent[l]
        base = q == 0 ? axis(np + count(==(0), p.leaf_parent[1:l])) : axis(q)
        base .+ sum((w .* axis(pp) for (ll, pp, w) in p.overlaps if ll == l); init = zeros(dims)) .+ p.own_axis .* axis(np + ntop + l)
    end
    knows(q, l) = p.known[l] && (p.leaf_parent[l] == q || any(ll == l && pp == q for (ll, pp, _) in p.overlaps))
    # The network: leaves (known, then formed), their signatures, the world's leaf each models,
    # whether novel; μ, parents × leaves, with its bootstrap pattern.
    lsig, ltrue, lnovel = Vector{Float64}[], Int[], Bool[]
    for l in 1:ntrue
        p.known[l] && (push!(lsig, true_sig[l]); push!(ltrue, l); push!(lnovel, false))
    end
    lmax = length(lsig) + p.max_new
    μ_boot = zeros(np, lmax)
    for (j, l) in enumerate(ltrue)
        μ_boot[p.leaf_parent[l], j] = 1.0  # the bootstrap knows primary parents, not overlaps
    end
    μ = copy(μ_boot)
    nleaves() = length(lsig)
    col_parent(q) = lmax + q
    root = lmax + np + 1
    ncol = root
    # Models: one per leaf and per parent; histories of scores.
    # Each scored prediction's credence that the action's assessed value is positive, whether it was
    # (1 or 0), and the error of its predicted value (author rulings 8.35, 8.36).
    # A model's record of one prediction: its credence, the outcome (assessed value positive) and
    # its value error, with what an audit needs to repair it (8.38): the actor, the currency, the
    # prediction, the beings it touched, the measured value, the track-record corrections then (the
    # actor's, and the mean of other actors'), and whether an audit has repaired it.
    Rec = NamedTuple{(:credence, :raw, :outcome, :err, :actor, :c, :pr, :mask, :measured, :corr, :peer_corr, :fixed, :step),
                     Tuple{Float64,Float64,Float64,Float64,Int,Int,ToyPlan,BitVector,Float64,Tuple{Float64,Float64},Tuple{Float64,Float64},Bool,Int}}
    lhist, phist = [Rec[] for _ in 1:lmax], [Rec[] for _ in 1:np]
    lbias, pbias = p.bias_σ .* randn(nrng, lmax), p.bias_σ .* randn(nrng, np)
    # Each leaf's pool of competing models (L82; 8.42.2): the bootstrap model first (its track-record
    # key is the leaf), challengers as they arrive. `lhist[j]` is the history of the model backing
    # leaf j's currency (the top model); a captured model is the top one when the capture begins.
    # `sharp` is the share of its uncertainty a model states: 1 honest, below 1 an extremist (a world
    # property of the model, M6), whose credences sit nearer 0 and 1 than its record supports.
    Model = NamedTuple{(:uid, :scale, :bias, :sharp, :collude, :hist),Tuple{Int,Float64,Float64,Float64,Bool,Vector{Rec}}}
    mpool = [Model[(uid = j, scale = 1.0, bias = lbias[j], sharp = 1.0, collude = false, hist = lhist[j])] for j in 1:lmax]
    top = ones(Int, lmax)
    topm(j) = mpool[j][top[j]]
    tkey(c) = c <= lmax ? topm(c).uid : c
    captured_uid = zeros(Int, lmax)
    irng = Xoshiro(hash((seed, :models)))
    takeovers, next_uid = Ref(0), Ref(10^6)  # challengers' track-record keys never meet a currency column
    takeovers_extreme, arrivals_extreme = Ref(0), Ref(0)
    takeovers_colluding, arrivals_colluding = Ref(0), Ref(0)
    collude_uids = Set{Int}()
    added_uids = Set{Int}()
    domain_score_only = falses(lmax)
    added_models = NamedTuple{(:add_step, :target, :size, :uid, :promoted, :promoted_step),
                              Tuple{Int,Int,Float64,Int,Base.RefValue{Bool},Base.RefValue{Int}}}[]
    added_domains = NamedTuple{(:add_step, :target, :leaf, :size, :promoted, :promoted_step),
                               Tuple{Int,Int,Int,Float64,Base.RefValue{Bool},Base.RefValue{Int}}}[]
    finer_meas_cands = NamedTuple{(:uid, :add_step, :σ, :size, :diffs, :promoted, :promoted_step),
                                  Tuple{Int,Int,Float64,Float64,Vector{Float64},Base.RefValue{Bool},Base.RefValue{Int}}}[]
    xtrng = Xoshiro(hash((seed, :extremist)))
    collrng = Xoshiro(hash((seed, :model_collude)))
    # Accuracy over the recent window is the quality of a model's credences (Lean
    # `credence_accuracy_ref`); its uncertainty, which its credences come from, is the root mean
    # square of its recent value errors: its own track record. No record: no accuracy, a coin toss.
    window_of(h) = @view h[max(1, end - p.window + 1):end]
    # Accuracy is averaged over time, each record weighted by its age (author ruling 8.85): half-life
    # `hl` steps, set per domain from its measured transaction rate (`decay_halflife`). Records older
    # than 40 half-lives weigh under 1e-12 and are skipped (numerical, not a threshold). `:window`, the
    # last `window` records, is the limiting case kept for comparison.
    # Discovered deception (author ruling on 8.91): the outcomes of an established deception are not
    # charged against the domain's models (measurement discounts them); they index the actor's deception
    # record instead. An establishment discounts the actor's records since its previous audit.
    discount_spans = [Tuple{Int,Int}[] for _ in 1:na]
    last_audit = zeros(Int, na)
    eb_ver = Ref(0)
    eb_dom_cache = Dict{Int, Tuple{Int, UInt, Int, Int, Int, Float64, Float64}}()
    eb_mod_cache = IdDict{Any, Tuple{Int, Int, Int, Int, Int, Float64}}()
    eb_actor_cache = Dict{Tuple{Int, Int}, Tuple{Int, Int, Int, Int, Float64}}()
    discounted(x) = x.actor > 0 && any(s0 <= x.step <= s1 for (s0, s1) in discount_spans[x.actor])
    function acc_of(h, hl)
        isempty(h) && return 0.0
        p.accuracy_rule == :window && return credence_accuracy([x.credence for x in window_of(h)], [x.outcome for x in window_of(h)])
        i0 = searchsortedfirst(h, cur[] - 40hl; by = x -> x isa Real ? x : x.step)
        r = [x for x in @view(h[i0:end]) if !discounted(x)]
        isempty(r) ? 0.0 : decayed_accuracy([x.credence for x in r], [x.outcome for x in r], [cur[] - x.step for x in r], hl)
    end
    # Each domain's transaction rate: records per step, an exponentially weighted average with
    # half-life `rate_halflife`, corrected for its start; parents follow leaves in `lmax + q`.
    rate_sum, rate_norm, rate_count = zeros(lmax + np), Ref(0.0), zeros(Int, lmax + np)
    rate_of(c) = rate_norm[] > 0 ? rate_sum[c] / rate_norm[] : 0.0
    function update_rates!()
        d = 2.0^(-1 / p.rate_halflife)
        rate_sum .= d .* rate_sum .+ (1 - d) .* rate_count
        rate_norm[] = d * rate_norm[] + (1 - d)
        fill!(rate_count, 0)
    end
    hl_of(c) = decay_halflife(rate_of(c); ref_rate = p.acc_rate_ref, ref_halflife = p.acc_halflife, mute = p.acc_mute)
    function unc_of(h, hl = p.acc_halflife)
        isempty(h) && return Inf
        p.accuracy_rule == :window ? sqrt(mean(x.err^2 for x in window_of(h))) :
            decayed_rms([x.err for x in h], [Float64(cur[] - x.step) for x in h], hl)
    end
    # Model error and bias are relative to the domain's natural spread of outcomes (8.35).
    function mbias(j, m)
        cap = sum((e.size for e in live(:capture) if j <= length(ltrue) && ltrue[j] == e.target); init = 0.0)
        cap > 0 && captured_uid[j] == 0 && (captured_uid[j] = topm(j).uid)
        m.bias * t.spread + (m.uid == captured_uid[j] ? cap : 0.0)
    end
    lb(j) = mbias(j, topm(j))
    pb(q) = pbias[q] * t.spread
    leaf_acc(j) = acc_of(lhist[j], hl_of(j))
    parent_acc(q) = acc_of(phist[q], hl_of(lmax + q))
    # A currency's credence for a prediction: from the predicted value and its model's uncertainty.
    # Credence for an actor's action comes from the model's record on that actor (8.29: models
    # estimate from track record), once it has a few entries; before that, from its record overall.
    function cred(c, pred, a = 0; hist = nothing, sharp = c <= lmax ? topm(c).sharp : 1.0, rule = p.credence_rule)
        v = plan_value(pred, t)
        cr = if rule == :eb
            dom_hist = (c <= lmax ? lhist[c] : phist[c - lmax])
            h_use = hist !== nothing ? hist : dom_hist
            use_actor = a > 0 && length(actor_err[a]) >= p.actor_min_records
            if p.accuracy_rule == :decay
                hl = hl_of(c)
                dc = get(eb_dom_cache, c, nothing)
                n_dom, μ0, τ2 = if dc !== nothing && dc[1] == cur[] && dc[2] == objectid(dom_hist) && dc[3] == length(dom_hist) && dc[4] == eb_ver[]
                    (dc[5], dc[6], dc[7])
                else
                    i_dom = isempty(dom_hist) ? 1 : searchsortedfirst(dom_hist, cur[] - 16 * hl; by = x -> x isa Real ? x : x.step)
                    r_dom = isempty(dom_hist) ? dom_hist : [x for x in @view(dom_hist[i_dom:end]) if !discounted(x)]
                    nd = length(r_dom)
                    m0, t2 = if nd >= p.min_records
                        w_dom = [2.0^(-(cur[] - x.step) / hl) for x in r_dom]
                        _weighted_robust_loc_scale([x.measured for x in r_dom], w_dom)
                    else
                        (0.0, 0.0)
                    end
                    eb_dom_cache[c] = (cur[], objectid(dom_hist), length(dom_hist), eb_ver[], nd, m0, t2)
                    (nd, m0, t2)
                end
                n_mod, σ2 = if n_dom < p.min_records
                    (0, 0.0)
                elseif use_actor
                    ac = get(eb_actor_cache, (a, c), nothing)
                    s2 = if ac !== nothing && ac[1] == cur[] && ac[2] == length(actor_err[a]) && ac[3] == eb_ver[] && ac[4] == tw_now[]
                        ac[5]
                    else
                        i_a = min(searchsortedfirst(actor_err_step[a], cur[] - 16 * hl), length(actor_err_step[a]))
                        ws = [2.0^(-(cur[] - s) / hl) for s in @view(actor_err_step[a][i_a:end])]
                        all(==(0.0), ws) && (ws = ones(length(ws)))
                        v_s2 = _weighted_robust_err_var(Float64.(@view(actor_err[a][i_a:end])), ws)
                        eb_actor_cache[(a, c)] = (cur[], length(actor_err[a]), eb_ver[], tw_now[], v_s2)
                        v_s2
                    end
                    (0, s2)
                else
                    mc = get(eb_mod_cache, h_use, nothing)
                    if mc !== nothing && mc[1] == cur[] && mc[2] == length(h_use) && mc[3] == eb_ver[] && mc[4] == c
                        (mc[5], mc[6])
                    else
                        i_mod = isempty(h_use) ? 1 : searchsortedfirst(h_use, cur[] - 16 * hl; by = x -> x isa Real ? x : x.step)
                        r_mod = isempty(h_use) ? h_use : [x for x in @view(h_use[i_mod:end]) if !discounted(x)]
                        nm = length(r_mod)
                        s2 = nm >= p.min_records ? _weighted_robust_err_var([x.err for x in r_mod], [2.0^(-(cur[] - x.step) / hl) for x in r_mod]) : 0.0
                        eb_mod_cache[h_use] = (cur[], length(h_use), eb_ver[], c, nm, s2)
                        (nm, s2)
                    end
                end
                if n_dom < p.min_records || (!use_actor && n_mod < p.min_records) || σ2 >= τ2
                    if use_actor
                        decayed_record_credence(v, sharp .* actor_err[a], [Float64(cur[] - s) for s in actor_err_step[a]], hl; cap = p.max_credence)
                    elseif isempty(h_use)
                        record_credence(v, Float64[]; cap = p.max_credence)
                    else
                        decayed_record_credence(v, [sharp * x.err for x in h_use], [Float64(cur[] - x.step) for x in h_use], hl; cap = p.max_credence)
                    end
                else
                    eb_credence(v, sharp^2 * σ2, μ0, τ2; cap = p.max_credence)
                end
            else
                dc = get(eb_dom_cache, c, nothing)
                n_dom, μ0, τ2 = if dc !== nothing && dc[1] == cur[] && dc[2] == objectid(dom_hist) && dc[3] == length(dom_hist) && dc[4] == eb_ver[]
                    (dc[5], dc[6], dc[7])
                else
                    r_dom = window_of(dom_hist)
                    nd = length(r_dom)
                    m0, t2 = nd >= p.min_records ? _weighted_robust_loc_scale([x.measured for x in r_dom], ones(nd)) : (0.0, 0.0)
                    eb_dom_cache[c] = (cur[], objectid(dom_hist), length(dom_hist), eb_ver[], nd, m0, t2)
                    (nd, m0, t2)
                end
                n_mod, σ2 = if n_dom < p.min_records
                    (0, 0.0)
                elseif use_actor
                    ac = get(eb_actor_cache, (a, c), nothing)
                    s2 = if ac !== nothing && ac[1] == cur[] && ac[2] == length(actor_err[a]) && ac[3] == eb_ver[] && ac[4] == tw_now[]
                        ac[5]
                    else
                        e = @view actor_err[a][max(1, end - tw_now[] + 1):end]
                        v_s2 = _weighted_robust_err_var(Float64.(e), ones(length(e)))
                        eb_actor_cache[(a, c)] = (cur[], length(actor_err[a]), eb_ver[], tw_now[], v_s2)
                        v_s2
                    end
                    (0, s2)
                else
                    mc = get(eb_mod_cache, h_use, nothing)
                    if mc !== nothing && mc[1] == cur[] && mc[2] == length(h_use) && mc[3] == eb_ver[] && mc[4] == c
                        (mc[5], mc[6])
                    else
                        r_mod = window_of(h_use)
                        nm = length(r_mod)
                        s2 = nm >= p.min_records ? _weighted_robust_err_var([x.err for x in r_mod], ones(nm)) : 0.0
                        eb_mod_cache[h_use] = (cur[], length(h_use), eb_ver[], c, nm, s2)
                        (nm, s2)
                    end
                end
                if n_dom < p.min_records || (!use_actor && n_mod < p.min_records) || σ2 >= τ2
                    e = a > 0 ? (@view actor_err[a][max(1, end - tw_now[] + 1):end]) : Float64[]
                    errs = length(e) >= p.actor_min_records ? e : [x.err for x in window_of(h_use)]
                    record_credence(v, sharp .* errs; cap = p.max_credence)
                else
                    eb_credence(v, sharp^2 * σ2, μ0, τ2; cap = p.max_credence)
                end
            end
        elseif p.accuracy_rule == :decay
            hl = c <= lmax ? hl_of(c) : hl_of(c)
            if rule == :record
                if a > 0 && length(actor_err[a]) >= p.actor_min_records
                    decayed_record_credence(v, sharp .* actor_err[a], [Float64(cur[] - s) for s in actor_err_step[a]], hl; cap = p.max_credence)
                else
                    h_use = hist !== nothing ? hist : (c <= lmax ? lhist[c] : phist[c - lmax])
                    if isempty(h_use)
                        record_credence(v, Float64[]; cap = p.max_credence)
                    else
                        decayed_record_credence(v, [sharp * x.err for x in h_use], [Float64(cur[] - x.step) for x in h_use], hl; cap = p.max_credence)
                    end
                end
            else
                u = if a > 0 && length(actor_err[a]) >= p.actor_min_records
                    decayed_rms(actor_err[a], [Float64(cur[] - s) for s in actor_err_step[a]], hl)
                else
                    hist !== nothing ? unc_of(hist, hl) : (c <= lmax ? unc_of(lhist[c], hl) : unc_of(phist[c - lmax], hl))
                end
                credence(v, sharp * u; cap = p.max_credence)
            end
        else
            e = a > 0 ? (@view actor_err[a][max(1, end - tw_now[] + 1):end]) : Float64[]
            if rule == :record
                # [P] (8.58-c): the share of the record's value errors below the prediction (an
                # extremist scales its record by `sharp`)
                errs = length(e) >= p.actor_min_records ? e : [x.err for x in window_of(hist !== nothing ? hist : (c <= lmax ? lhist[c] : phist[c - lmax]))]
                record_credence(v, sharp .* errs; cap = p.max_credence)
            else
                u = length(e) >= p.actor_min_records ? sqrt(mean(abs2, e)) :
                    hist !== nothing ? unc_of(hist) : (c <= lmax ? unc_of(lhist[c]) : unc_of(phist[c - lmax]))
                credence(v, sharp * u; cap = p.max_credence)
            end
        end
        a > 0 || return cr
        # Discovered deception (author ruling on 8.91) & repeated domain negative patterns (`8.157 i`, L117):
        # each permanent deception and repeated negative-record pattern in domain `c` raises escrow
        # exponentially via `sanction_escrow_credence`, while isolated lapses (`< sanction_pattern_min`)
        # add zero escalation and direct reputation penalties stay proportional (`8.157 iii`).
        dom_neg = (p.sanction_escalate && 1 <= c <= ncol &&
                   (dom_crime_events[a, c] >= p.sanction_pattern_min ||
                    (dom_neg_events[a, c] >= p.sanction_pattern_min &&
                     dom_neg_events[a, c] >= dom_pos_events[a, c] && h_neg[a, c] > h_pos[a, c]))) ?
                  max(dom_crime_events[a, c], dom_neg_events[a, c]) : 0
        dom_neg >= p.sanction_pattern_min && (sanction_escalations[] += 1)
        pma_miss = p.proposal_pma ? pma_misses[a] : 0
        sanction_escrow_credence(cr, ledger_neg_share(a), deceptions[a] + pma_miss, dom_neg, p.sanction_pattern_min;
                                 growth = p.ratchet_growth, floor = 1 - p.max_credence)
    end
    # The reputation ledgers (L101) carry patterns of mistakes and uncovered deception as well as
    # of success: an actor's negative share of its ledgers, whose entries never decay (only the
    # rolling net does; 8.42.1).
    ledger_neg_share(a) = neg_share(sum(h_pos[a, :]), sum(h_neg[a, :]))  # Lean `neg_share_ref`
    # A domain is marginal where its leaf model is near or below its status bar (8.42.1).
    function marginal(b)
        l = argmax(agent_focus[b])
        l <= nleaves() && leaf_acc(l) < leaf_bar(l) + p.marginal_margin
    end
    # The status bar: absolute, or relative to the alternative the leaf's work would fall to (8.41),
    # everywhere once adopted, or on the trial's domains while the debatable escape is tried.
    bar_rel = Ref(p.relative_bar)
    trial = (on = Ref(false), leaves = falses(ntrue), units = Dict{Tuple{Bool,Int,Int},Float64}(),
             gains = Ref(0.0), harms = Ref(0.0), irreparable = Ref(0))
    # The ratchet (8.84): each leaf's bar never falls below what enough of its models have cleared.
    lfloor = zeros(lmax)
    function leaf_bar(j)
        th_j = min(th_now[] + (ltrue[j] <= length(bar_off[]) ? max(bar_off[][ltrue[j]], 0.0) : 0.0), 1.0)
        (bar_rel[] || (trial.on[] && trial.leaves[ltrue[j]])) || return max(th_j, lfloor[j])
        q = argmax(μ[:, j])
        max(relative_bar(th_j, p.coarse_threshold, parent_ok(q) ? parent_acc(q) : p.coarse_threshold), lfloor[j])
    end
    function ratchet!()
        for j in 1:nleaves()
            # "Operating above" means sustained operation (author, 8.84): accuracy averaged over a horizon
            # `ratchet_horizon` times the domain's own (8.85), from models observed across that horizon
            # (a younger model's short record, read whole, locks the bar at its luck). Over the short horizon, models scored on the same actions swing together (0.86 to
            # 0.99) and the bar locked at a quiet stretch the whole pool then fell below.
            hr = p.ratchet_horizon * hl_of(j)
            accs = [acc_of(m.hist, hr) for m in mpool[j] if length(m.hist) >= p.takeover_records && cur[] - m.hist[1].step >= hr]
            lfloor[j] = ratchet_bar(accs, leaf_bar(j); k = p.ratchet_k, margin = p.ratchet_margin)
        end
    end
    bar_trace = Float64[]; acc_trace = Vector{Float64}[]; rate_trace = Vector{Float64}[]
    removed_leaf(j) = any(e -> e.target == 0 || e.target == j, live(:remove_leaf_models))
    removed_parent(q) = any(e -> e.target == 0 || e.target == q, live(:remove_parent_models))
    pool_capped(j) = any(e -> e.target == 0 || e.target == j, live(:cap_pool_one))
    res_margin_of(j) = ltrue[j] <= length(p.res_margins) ? p.res_margins[ltrue[j]] : p.res_margin
    # Records under the accuracy rule's own filter (window, or the decayed span without discounted spans), with their ages.
    function eligible_records(h, hl)
        p.accuracy_rule == :window && return collect(window_of(h)), Float64[cur[] - x.step for x in window_of(h)]
        i0 = searchsortedfirst(h, cur[] - 40hl; by = x -> x isa Real ? x : x.step)
        r = [x for x in @view(h[i0:end]) if !discounted(x)]
        r, Float64[cur[] - x.step for x in r]
    end
    # A history clears domain j's bar: 1 - Brier/0.25 (`:brier`), or calibration plus resolution over the base rate (`:murphy`, 8.177).
    function hist_eligible(h, hl, j, bar)
        if p.bar_rule == :murphy
            r, ages = eligible_records(h, hl)
            isempty(r) && return false
            m = decayed_murphy([x.credence for x in r], [x.outcome for x in r], ages, hl; bins = p.murphy_bins)
            return murphy_eligible(m.reliability, m.resolution, m.uncertainty, length(h); novel = lnovel[j], threshold = bar,
                                   novel_threshold = p.novel_threshold, min_records = p.min_records, novel_floor = p.novel_floor, res_margin = res_margin_of(j))
        end
        currency_eligible(acc_of(h, hl), length(h); novel = lnovel[j], threshold = bar, novel_threshold = p.novel_threshold,
                          min_records = p.min_records, novel_floor = p.novel_floor)
    end
    leaf_ok_raw(j) = hist_eligible(lhist[j], hl_of(j), j, leaf_bar(j))
    leaf_ok(j) = !removed_leaf(j) && !domain_score_only[j] && leaf_ok_raw(j)
    parent_ok(q) = !removed_parent(q) && currency_eligible(parent_acc(q), length(phist[q]); novel = false, threshold = p.coarse_threshold,
                                                             novel_threshold = p.novel_threshold, min_records = p.min_records, novel_floor = p.novel_floor)
    function eval_challengers(j; only_if_eligible = false)
        ks = [top[j]; [k for k in eachindex(mpool[j]) if k != top[j] && length(mpool[j][k].hist) >= p.takeover_records &&
                       (!only_if_eligible || hist_eligible(mpool[j][k].hist, hl_of(j), j, leaf_bar(j)))]]
        length(ks) > 1 || return top[j]
        brier(h) = [credence_score(x.raw, x.outcome) for x in window_of(h)]
        hlj = hl_of(j)
        dms(h) = decayed_mean_se([credence_score(x.raw, x.outcome) for x in h], [cur[] - x.step for x in h], hlj)
        sc_ = [brier(mpool[j][k].hist) for k in ks]
        ms = [isempty(x) ? 0.0 : mean(x) for x in sc_]
        ses = [length(x) < 2 ? 1e12 : std(x) / sqrt(length(x)) for x in sc_]
        if p.accuracy_rule == :decay
            d_ = [dms(mpool[j][k].hist) for k in ks]
            ms, ses = first.(d_), last.(d_)
        end
        w = select_candidate(ms, ses; z = p.model_z)
        ks[w]
    end
    leaf_σ(j, l) = t.spread * topm(j).scale * (ltrue[j] != l ? p.σ_coarse :
        lnovel[j] ? p.σ_leaf + (p.σ_coarse - p.σ_leaf) * exp(-length(lhist[j]) / p.n_learn) : p.σ_leaf)
    parent_σ(q, l) = t.spread * (knows(q, l) ? p.σ_branch : p.σ_coarse)
    # Shares from Lean come laid out over the current leaves; columns are fixed at lmax leaves.
    widen(x) = (L = nleaves(); [x[1:L]; zeros(lmax - L); x[(L + 1):end]])
    parent_mem(c) = [projection_membership(c, σ) for σ in parent_sig]
    classify_sig(c) = widen(classify_network(parent_mem(c), [distance(c, σ) for σ in lsig], μ[:, 1:nleaves()];
                                             parent_threshold = p.parent_threshold, μ_min = p.μ_min,
                                             leaf_threshold = p.leaf_threshold, temperature = p.temperature))
    narrow(x) = (L = nleaves(); [x[1:L]; x[(lmax + 1):end]])
    price_shares(st) = widen(fallback_network(μ[:, 1:nleaves()], [leaf_ok(j) for j in 1:nleaves()], [parent_ok(q) for q in 1:np], narrow(st)))
    rate_gain, rate_loss = decay_rate_for(1.0; λpos = p.λpos, λneg = p.λneg), decay_rate_for(-1.0; λpos = p.λpos, λneg = p.λneg)
    balance = zeros(na, ncol)
    for c in [1:nleaves(); col_parent.(1:np); root]
        balance[:, c] .= p.endowment
    end
    # Fork slots are not entities until their fork: no endowment, no proposals; each identity's share of the base
    # accumulation allowance (`base_share`) splits at a fork like its balance (identity step 2, L123).
    frng = Xoshiro(hash((seed, :fork))); fork_records = Ref(0)
    dormant = falses(na); base_share = ones(na); act_share = ones(na)   # act_share: capacity to propose, social power too
    fork_family = collect(1:na)
    for f in p.forks
        dormant[f[3]] = true; balance[f[3], :] .= 0.0; base_share[f[3]] = 0.0; act_share[f[3]] = 0.0
    end
    for e in (na - p.entrants + 1):na
        dormant[e] = true; balance[e, :] .= 0.0; base_share[e] = 0.0; act_share[e] = 0.0; propose_w[e] = 0.0
    end
    entries_admitted = Ref(0)
    endowed = sum(balance)
    h_pos, h_neg, rel_gain, rel_loss = zeros(na, ncol), zeros(na, ncol), zeros(na, ncol), zeros(na, ncol)
    dom_pos_events, dom_neg_events, dom_crime_events = zeros(Int, na, ncol), zeros(Int, na, ncol), zeros(Int, na, ncol)
    sanction_escalations, sanction_restraints = Ref(0), Ref(0)
    jrng = Xoshiro(hash((seed, :justice)))
    # Restraint by the Administration's enforcing entities (8.169): own stream, per-enforcer ledger.
    erng = Xoshiro(hash((seed, :enforcers)))
    krng = Xoshiro(hash((seed, :judges)))          # evidence and panel draws (8.170), own stream
    njudge = length(p.judges)
    restr_on = njudge > 0
    nenf = max(1, length(p.enforcer_excess))
    enf_liab = zeros(nenf)                         # liability each enforcing entity carries (forgotten slowly)
    judge_rep = zeros(max(njudge, 1))              # negative judicial-domain reputation of each expert (forgotten slowly)
    judge_over = zeros(Int, max(njudge, 1))        # verdicts of each expert overturned on audit (repeated pattern, L117)
    judge_rec = [Tuple{Float64,Float64}[] for _ in 1:max(njudge, 1)]  # (stated confidence in guilt, audited outcome) per expert
    restr_run = zeros(Int, na)                     # consecutive restraints of each proposer (duration)
    restraint_pending = Tuple{Int,Bool,Float64,Int,Vector{Tuple{Int,Float64,Bool}},Float64,Float64,Int}[]  # audits owed after an unaudited-before restraint
    restr_audits_left, recursion_left = Ref(0), Ref(0)
    false_restraints, false_restr_effective, justified_restraints, justified_restr_effective = Ref(0), Ref(0), Ref(0), Ref(0)
    restraints_overturned, restraint_audits, restraint_waits, restraint_missed = Ref(0), Ref(0), Ref(0), Ref(0)
    restraint_audit_cost, restraint_liability, false_restr_harm = Ref(0.0), Ref(0.0), Ref(0.0)
    judge_liability, judge_currency, challenger_charged, excess_harm, excess_charged = Ref(0.0), Ref(0.0), Ref(0.0), Ref(0.0), Ref(0.0)
    recursive_audits, recursion_refused, findings_false, findings_true = Ref(0), Ref(0), Ref(0), Ref(0)
    restraint_verdicts, restraint_acquittals, alarm_step, alarm_count = Ref(0), Ref(0), Ref(0), Ref(0)
    challenge_unfounded = zeros(Int, na + 2)       # unfounded challenges per side: each proposer, the panel (na + 1), the victims (na + 2)
    acq_audits, acq_overturned, acq_liability = Ref(0), Ref(0), Ref(0.0)
    function judge_case!(guilty)
        # Restraint is the last-resort verdict of Justice (8.170): a panel of judicial experts votes on guilt with
        # stated confidence, each reading the shared noisy case evidence with its own skill and capture; ballots
        # weigh as in LqCfdBfDm (vote weight x record calibration x log-odds), minority clusters uplifted.
        local x = (guilty ? 1.0 : -1.0) * p.evidence_sep + p.evidence_noise * randn(krng)
        local panel = randperm(krng, njudge)[1:min(p.panel_size, njudge)]
        local total = 0.0
        local voters = Tuple{Int,Float64,Bool}[]
        for i in panel
            local jobs = x + p.judges[i] * randn(krng)
            local lo = clamp(2 * p.evidence_sep * jobs / (p.evidence_noise^2 + p.judges[i]^2) + (isempty(p.judge_bias) ? 0.0 : p.judge_bias[i]), -10.0, 10.0)
            local minor = !isempty(p.judge_cluster) && p.judge_cluster[i] == 2
            local vw = panel_voice(exp(-judge_rep[i] / p.enforcer_liability_scale), p.panel_minority_weight, minor)
            local rec = judge_rec[i]
            local cal = length(rec) < 3 ? 1.0 : clamp(2 * credence_accuracy(first.(rec), last.(rec)), 0.0, 2.0)
            total += cfd_ballot_weight(vw, cal, lo)
            push!(voters, (i, 1 / (1 + exp(-lo)), lo > 0))
        end
        (total > 0, voters)
    end
    function audit_read(guilty)
        rand(erng) < p.restraint_audit_acc ? guilty : !guilty   # true = the audit upholds the verdict
    end
    function fund_audit!(c)
        restraint_audits[] += 1
        restraint_audit_cost[] += p.audit_cost
        p.ra_domain && 1 <= c <= ntrue && (ra_domain_audit[c] += p.audit_cost)   # AdvAp audits are funded from the commons
    end
    function challenged_finding!(c, upheld, reader, side_up, side_down)
        # The losing side may challenge the finding: a recursive audit, funded from the commons within the per-step
        # budget; a challenge the new audit does not support is unfounded, and above the AdvAp threshold it is charged
        # to the challenger (`report_penalty`). Out of budget the last finding stands, logged loudly.
        while p.restraint_challenge > 0 && rand(erng) < p.restraint_challenge
            if recursion_left[] <= 0
                recursion_refused[] += 1
                degrade!("restraint audit recursion", "challenge refused, last finding stands", "recursion budget exhausted")
                break
            end
            recursion_left[] -= 1; recursive_audits[] += 1
            fund_audit!(c)
            local side = upheld ? side_up : side_down
            local again = reader()
            if again == upheld
                challenge_unfounded[side] += 1
                challenger_charged[] += report_penalty(challenge_unfounded[side], p.frivolous_threshold; audit_cost = p.audit_cost)
            end
            upheld = again
        end
        upheld
    end
    function check_alarm!()
        # The alarm reads audited findings of both error types against correct verdicts (8.170 e, 8.173): false
        # restraints and false acquittals against upheld verdicts.
        if restraint_alarm_interval(p.restraint_alarm_min, findings_false[], findings_true[]; ratio = p.restraint_alarm_ratio, z = p.restraint_alarm_z)
            alarm_count[] += 1
            if alarm_step[] == 0
                alarm_step[] = cur[]
                degrade!("restraint justice", "alarm: flawed process flagged as governance candidate", "false verdicts reached correct verdicts")
            end
        end
    end
    function record_voters!(voters, guilty_truth)
        for (i, cf, _) in voters
            push!(judge_rec[i], (cf, guilty_truth ? 1.0 : 0.0)); length(judge_rec[i]) > 40 && popfirst!(judge_rec[i])
        end
    end
    function audit_case!(k, guilty, cost, c, voters, exc_frac, exc_cost, prop, executed)
        # One audit trigger (commons-funded) reads the verdict's quality and the execution's fidelity.
        fund_audit!(c)
        local upheld = challenged_finding!(c, audit_read(guilty), () -> audit_read(guilty), prop, na + 1)
        upheld ? (findings_true[] += 1) : (findings_false[] += 1; restraints_overturned[] += 1)
        record_voters!(voters, guilty)
        if !upheld
            # liability of the false verdict falls on the experts who voted guilty, by their stated confidence
            # (the Lean credence rule applied to the experts' own confidence): judicial-domain reputation first,
            # currency only once the pattern repeats (L117)
            local ng = count(v -> v[3], voters)
            for (i, cf, g) in voters
                g || continue
                local liab = credence_restraint_liability(cf, p.restraint_kappa, (cost + p.audit_cost) / max(ng, 1))
                judge_rep[i] += liab; judge_over[i] += 1; judge_liability[] += liab
                judge_over[i] >= p.sanction_pattern_min && (judge_currency[] += liab)
            end
        end
        if upheld && executed && exc_cost > 0 && exc_frac > p.excess_tol && rand(erng) < p.restraint_audit_acc
            # the enforcer is liable only for the execution excess beyond the verdict
            local liab = false_restraint_liability(false, p.restraint_kappa, exc_cost)
            enf_liab[k] += liab; restraint_liability[] += liab; excess_charged[] += liab
        end
        check_alarm!()
        upheld
    end
    function audit_acquittal!(guilty, c, voters, prop)
        # 8.173: an acquittal is audited too (random rate, commons-funded) and the victims may AdvAp-challenge the
        # finding (their side index na + 2). The audit reads the truth with the world's accuracy; the acquittal is
        # upheld when it reads innocent. A wrongful acquittal is charged to the experts who voted to acquit,
        # weighted by their stated confidence in innocence (the credence rule), judicial reputation first and
        # currency once the pattern repeats (L117).
        fund_audit!(c); acq_audits[] += 1
        local reader = () -> !audit_read(guilty)      # true = the audit upholds the acquittal (reads innocent)
        local upheld = challenged_finding!(c, reader(), reader, na + 2, na + 1)
        upheld ? (findings_true[] += 1) : (findings_false[] += 1; acq_overturned[] += 1)
        record_voters!(voters, guilty)
        if !upheld
            local cost = p.false_restraint_severity * p.false_restraint_harm   # harm the acquitted proposer goes on to cause (toy proxy)
            local ng = count(v -> !v[3], voters)
            for (i, cf, g) in voters
                g && continue
                local liab = credence_restraint_liability(1 - cf, p.restraint_kappa, (cost + p.audit_cost) / max(ng, 1))
                judge_rep[i] += liab; judge_over[i] += 1; acq_liability[] += liab
                judge_over[i] >= p.sanction_pattern_min && (judge_currency[] += liab)
            end
        end
        check_alarm!()
        upheld
    end
    # 8.134 predict-measure-adapt loop for non-candidate proposals & measurements:
    # each executed proposal registers `(step, agent, col, predicted, measured, eta, grace, conf)`;
    # resolved once `resolution_due(cur[] - step, eta, grace)` holds via `prediction_on_track`.
    pma_pending = NamedTuple{(:step, :agent, :col, :predicted, :measured, :eta, :grace, :conf),
                             Tuple{Int,Int,Int,Float64,Float64,Int,Int,Float64}}[]
    pma_resolved = NamedTuple{(:step, :resolved_step, :agent, :col, :predicted, :measured, :on_track),
                              Tuple{Int,Int,Int,Int,Float64,Float64,Bool}}[]
    pma_misses = zeros(Int, na)
    pma_on_track = zeros(Int, na)
    reinvested = zeros(ncol)
    overflow_agent = zeros(na)  # what overflow skimmed from each agent (for reading who reinvests)
    # Memory logs each executed action with its outcome and the quotes composed for it (L89, L145).
    log_seq = Ref(0)
    next_seq!() = (log_seq[] += 1)
    pending_scores = NamedTuple{(:col, :uid, :credence, :outcome, :step, :actor),Tuple{Int,Int,Float64,Float64,Int,Int}}[]
    memory = NamedTuple{(:agent, :step, :seq, :signature, :measured, :profile, :obs_profile, :parent_mem, :priced, :credits, :up_degrees, :scores),
                        Tuple{Int,Int,Int,Vector{Float64},Float64,Vector{Float64},Vector{Float64},Vector{Float64},Vector{Float64},
                              Vector{Tuple{Int,Float64,Float64}},Vector{Int},
                              Vector{NamedTuple{(:col, :uid, :credence, :outcome, :step, :actor),Tuple{Int,Int,Float64,Float64,Int,Int}}}}}[]
    # Recent outputs per true domain that later actions may build on: (agent, effect per being on U, on H, upstream lineage).
    outputs = Dict{Int,Vector{Tuple{Int,Float64,Float64,Vector{Tuple{Int,Float64,Float64,Int}}}}}()
    credit_pos, credit_neg, upstream_pos, upstream_neg = zeros(na), zeros(na), zeros(na), zeros(na)
    upstream_pos_by_degree, upstream_neg_by_degree = zeros(p.upstream_depth), zeros(p.upstream_depth)
    max_upstream_degree = Ref(0)
    cofunder_credit, interaction = Ref(0.0), Ref(0.0)
    accolade_credit, contract_credit = Ref(0.0), Ref(0.0)
    accolades_suppressed = Ref(0)
    assessed_outcomes, fallback_outcomes = Ref(0), Ref(0)
    world = (hazards = Ref(0), prevented = Ref(0), crimes = Ref(0), accidents = Ref(0), unattributed = Ref(0.0),
             hazard_penalties = Ref(0.0), hazard_debits = Ref(0.0), repaired = Ref(0.0), side_hazards = Ref(0),
             educations = Ref(0), accident_capped = Ref(0), accident_admin_rest = Ref(0.0), accident_admin_paid = Ref(0.0),
             prevention_records = Ref(0), prevention_measured = Ref(0.0), shocks = Ref(0), commons_spent = Ref(0.0),
             insured = Ref(0.0), self_funded = Ref(0.0), repair_cost = Ref(0.0), outage_harm = Ref(0.0), sabotage_traced = Ref(0),
             laundered = Ref(0), laundered_traced = Ref(0), repair_actions = Ref(0), repair_credited = Ref(0.0))
    educated = Set{Tuple{Int,Int}}()
    repairs = Tuple{ToyPlan,Int,Int}[]  # (restoration plan, true_leaf, repairer_agent) funded by penalties, applied at step end
    buffers = Dict{Int,Vector{Vector{Float64}}}()
    formations = NamedTuple{(:step, :seq, :leaf, :nearest_leaf, :eligible_step, :reused, :init_μ),Tuple{Int,Int,Int,Int,Int,Bool,Vector{Float64}}}[]
    # Blocked proposals, logged as classification evidence (L88, L145).
    evidence = NamedTuple{(:step, :seq, :signature, :profile, :obs_profile, :parent_mem),Tuple{Int,Int,Vector{Float64},Vector{Float64},Vector{Float64},Vector{Float64}}}[]
    available = p.capacity
    available_honest = p.capacity
    suppliers = p.supplier > 0 ? [p.supplier] : p.supply_cartel
    wrng = Xoshiro(hash((seed, :withhold_advap)))
    withhold_stopped = Ref(false)
    buyer_overpay = zeros(na)
    sup_scarcity_gain = zeros(na)
    sup_clawback = zeros(na)
    sup_reward = zeros(na)
    withhold_totals = (premium = Ref(0.0), refunded = Ref(0.0), clawback = Ref(0.0), reward = Ref(0.0), discovered = Ref(0))
    price_scale = Ref(1.0)   # resource-accounting contraction (8.71)
    ra_withheld = Ref(0.0)   # value not issued for lack of deliverable capacity (8.133)
    # 8.133 / 8.155 / L83 RA estimating domain state (estimator separated from actuators; 8.26.7)
    ra_unit_value = fill(max(p.cost_per_touch, 1e-6), ntrue)
    ra_domain_audit = zeros(ntrue)
    ra_supply_est = Ref(p.capacity)
    ra_regen_est = Ref(p.regen)
    ra_need_est = Ref(0.0)
    ra_fallback_rate_est = Ref(0.0)
    commons_reserve = Ref(0.0)
    reserve_held = Ref(0.0)
    reserve_target = Ref(0.0)
    spend_scale = Ref(1.0)
    ra_audit_costs = Ref(0.0)
    responsibility_credits_applied = Ref(0)
    bystander_omissions_exempted = Ref(0)
    budget = (unfunded = Ref(0), uncashable = Ref(0))
    supplier_income = Ref(0.0)
    lane = (executed = Ref(0), halted = Ref(0), screened_out = Ref(0), cofunded = Ref(0.0), init_executed = Ref(0), declined = Ref(0), legacy_executed = Ref(0))
    econ_converged = Ref(false)
    gated_leaves = Int[]   # leaves still in score-only start after the economy opened (8.176)
    converge_step = Ref(0)
    legacy_bal = fill(p.endowment, na)
    leg_th = Ref(1.0)
    # Imperfect agents (8.31): each agent's choice-noise ceiling per true domain, inverse to its skill
    # there on average; its choices draw noise on their own stream.
    xrng = Xoshiro(hash((seed, :choice)))
    choice_caps = ability_caps(xrng, [max(p.agents[a].skills[l], 0.0) for a in 1:na, l in 1:ntrue];
                               base = p.choice_σ, gain = p.choice_gain, spread = p.ability_spread)
    tr = (floor_u = Float64[], floor_h = Float64[], median_u = Float64[], median_h = Float64[], peak_u = Float64[],
          worst_drop = Float64[], chosen_agent = Int[], chosen_step = Int[], true_leaf = Int[],
          stop_leaf = Int[], priced_leaf = Int[], costs = Float64[], touched = Int[], valued_measured = Float64[], supply = Float64[], lane_supply = Float64[],
          lane_costs = Float64[], lane_measured = Float64[],
          exec_pred = Float64[], exec_true = Float64[], exec_agent = Int[], exec_step = Int[], exec_upfront = Float64[])
    # Each selected execution's predicted value (the proxy G optimised) and its true value (the realised
    # change's assessed value, which no marker sees exactly): the Goodhart gap (M6).
    function executed!(j, a, step, pred, done; upfront = 0.0, col = 1)
        executed_j[j] = true
        vp, vd = plan_value(pred, t), plan_value(done, t)
        push!(tr.exec_pred, vp); push!(tr.exec_true, vd)
        push!(tr.exec_agent, a); push!(tr.exec_step, step); push!(tr.exec_upfront, upfront)  # escrow paid upfront (L84), 8.91
        if p.proposal_pma
            cu, ch = correction(a, tkey(col))
            m_claim = touched(pred)
            p_raw = (cu == 0.0 && ch == 0.0) ? pred : ToyPlan(pred.du .+ cu .* m_claim, pred.dh .+ ch .* m_claim)
            vp_claim = plan_value(p_raw, t)
            push!(pma_pending, (step = step, agent = a, col = col, predicted = vp_claim, measured = vd,
                                eta = p.proposal_eta, grace = p.proposal_eta_grace, conf = p.proposal_confidence))
        end
    end
    executed_j = falses(0)
    explored = Ref(0)
    exrng, wrng = Xoshiro(hash((seed, :explore))), Xoshiro(hash((seed, :identity)))
    # Identities (Technology Network): when each agent's current identity began; its earlier records
    # belong to an identity it abandoned.
    id_since = ones(Int, na)
    ids = (admitted = Ref(0), linked = Ref(0), revealed = Ref(0), newcomers = Ref(0), newcomers_refused = Ref(0))
    # Attestation records (8.70): each cluster's stated confidences that an identity is a distinct
    # entity, scored once the truth is known (a link at once; an admitted false identity when revealed).
    attest_cred = [Float64[] for _ in 1:max(p.bind_clusters, 1)]
    attest_out = [Float64[] for _ in 1:max(p.bind_clusters, 1)]
    unrevealed = Tuple{Vector{Float64},Float64}[]  # confidences behind each identity whose truth is pending, and that truth
    score_attest!(confs, outcome) = for c in eachindex(confs); push!(attest_cred[c], confs[c]); push!(attest_out[c], outcome); end
    attest_skill(c) = length(attest_out[c]) < p.attest_min_records ? 1.0 :
        p.attest_pooled ? choice_skill(attest_cred[c], fill(0.5, length(attest_out[c])), attest_out[c]) :
        class_balanced_skill(attest_cred[c], attest_out[c])
    function bind!(confs)
        p.bind_quorum == 0 && return true
        if !isempty(live(:lose_binding))
            degrade!("identity binding", "unbound admission", "cluster binding lost (progressive removal)")
            return true
        end
        p.bind_weighted ? binding_admits_weighted(confs, [attest_skill(c) for c in 1:p.bind_clusters], p.bind_threshold, p.bind_quorum_weight) :
                          binding_admits(confs, p.bind_threshold; quorum = p.bind_quorum)
    end
    top_leaf(st) = (k = argmax(st); k <= lmax ? k : 0)
    function relevance_parents(a)
        mine = rel_gain[a, :] .+ rel_loss[a, :]
        [aggregate_at_parent(μ[q, 1:nleaves()], mine[1:nleaves()]) + mine[col_parent(q)] for q in 1:np]
    end
    # Each logged action moves the overlap degrees of the leaves it lies in (no action, no change).
    function observe_membership!(st, pm)
        for j in 1:nleaves(), q in 1:np
            st[j] > 0 && (μ[q, j] = membership_rolling(μ[q, j], st[j], pm[q]; rate = p.μ_rate))
        end
    end
    # Reputation from one contributor's parts of an outcome: positive parts are gains, negative losses.
    function apply_credit!(a, st, pos, neg; dt = 0.0)
        _, gain, _ = split_signed(st, pos)
        _, _, loss = split_signed(st, neg)
        h_pos[a, :] .+= gain; h_neg[a, :] .+= loss
        for c in 1:ncol
            gain[c] > loss[c] && (dom_pos_events[a, c] += 1)
            loss[c] > gain[c] && (dom_neg_events[a, c] += 1)
        end
        rel_gain[a, :] .+= reputation_decay.(gain, dt; rate = rate_gain)
        rel_loss[a, :] .-= reputation_decay.(loss, dt; rate = rate_loss)
    end
    function credit!(step, c, st, measured, pm, pr, credits; up_degrees::Vector{Int} = Int[])
        # Without markers nothing is measured: the action is logged unmeasured, credited to no one.
        sc_entries = isempty(pending_scores) ? eltype(pending_scores)[] : copy(pending_scores)
        empty!(pending_scores)
        if blind[]
            push!(memory, (agent = credits[1][1], step = step, seq = 0, signature = c, measured = NaN, profile = st,
                           obs_profile = Float64[], parent_mem = pm, priced = pr, credits = Tuple{Int,Float64,Float64}[], up_degrees = Int[], scores = sc_entries))
            return
        end
        sq = next_seq!()
        obs_st = Float64[st[j] for j in 1:nleaves()]
        observe_membership!(st, pm)
        for (a, pos, neg) in credits
            apply_credit!(a, st, pos, neg)
            credit_pos[a] += pos; credit_neg[a] += neg
        end
        rand(nrng) < p.memory_loss && return  # lost before reaching memory: gone at the next recount
        push!(memory, (agent = credits[1][1], step = step, seq = sq, signature = c, measured = measured, profile = st,
                       obs_profile = obs_st, parent_mem = pm, priced = pr, credits = credits, up_degrees = copy(up_degrees), scores = sc_entries))
    end
    # Every model on the classification path is scored against the outcome.
    function score!(st, pm, l, plan, seen, quoted, a)
        blind[] && return  # nothing realised to score against
        measured = plan_value(seen, t)
        mask = touched(plan)
        # Each model's record: its raw error on this actor (before the correction applied), for
        # its track record; and the corrections it applied, for an audit's repair.
        # Each model states its credence from its own record (`hist`).
        function sc(c, pr, kc = c, hist = nothing, sharp = c <= lmax ? topm(c).sharp : 1.0)
            v = plan_value(pr, t)
            corr = correction(a, kc)
            others = [correction(k, kc) for k in 1:na if k != a && haskey(track[k], kc)]
            peer = isempty(others) ? (0.0, 0.0) : (mean(first, others), mean(last, others))
            if any(mask)
                push!(pending_track, (a, kc, mean(pr.du[mask]) + corr[1] - mean(seen.du[mask]),
                                      mean(pr.dh[mask]) + corr[2] - mean(seen.dh[mask])))
            end
            cr = cred(c, pr; hist, sharp)
            # Predictors are compared on their raw records (8.165): the record credence of the model's predictions and errors, without the exaggeration (`sharp`) of its stated confidence, whatever the claims' rule.
            raw = (p.credence_rule != :eb || c > lmax) ? cr : cred(c, pr; hist, sharp = 1.0, rule = :record)
            (credence = cr, raw = raw, outcome = measured > 0 ? 1.0 : 0.0, err = v - measured, actor = a, c = c, pr = pr,
             mask = mask, measured = measured, corr = corr, peer_corr = peer, fixed = false, step = cur[])
        end
        # A model that did not quote is scored on the estimate it would have quoted: fooled by the
        # actor's claims and corrected by its track record, as every quote is.
        for j in 1:nleaves()
            st[j] > 0 || continue
            rate_count[j] += 1
            rec_top = sc(j, get(() -> fooled(predict(mrng, MetricModel(lb(j), leaf_σ(j, l)), plan), a, plan, tkey(j)), quoted, j), tkey(j))
            push!(lhist[j], rec_top)
            push!(pending_scores, (col = j, uid = tkey(j), credence = rec_top.credence, outcome = rec_top.outcome, step = rec_top.step, actor = rec_top.actor))
            if has_finer_meas && !finer_action_scored[] && !isempty(finer_meas_cands)
                finer_action_scored[] = true
                v_pred = plan_value(rec_top.pr, t)
                for cand in finer_meas_cands
                    cand.promoted[] && continue
                    c_seen = observed_plan(finer_rng, finer_last_done[], cand.σ)
                    push!(cand.diffs, (v_pred - plan_value(c_seen, t))^2 - (v_pred - measured)^2)
                    n0_f = max(p.min_records, p.takeover_records)
                    if length(cand.diffs) >= n0_f
                        md = mean(cand.diffs); sd = std(cand.diffs)
                        if md < 0.0 && (sd <= 0.0 || sequential_significant(-md, sd, length(cand.diffs); n0 = n0_f, z = p.model_z))
                            cand.promoted[] = true
                            cand.promoted_step[] = cur[]
                            eff_marker_σ[] = min(eff_marker_σ[], cand.σ)
                        end
                    end
                end
            end
            # Every challenger in the pool is scored on the same logged action (the open log).
            for (k, m) in enumerate(mpool[j])
                k == top[j] && continue
                σm = leaf_σ(j, l) / topm(j).scale * m.scale
                rec_m = sc(j, fooled(predict(irng, MetricModel(mbias(j, m), σm), plan), a, plan, m.uid), m.uid, m.hist, m.sharp)
                push!(m.hist, rec_m)
                push!(pending_scores, (col = j, uid = m.uid, credence = rec_m.credence, outcome = rec_m.outcome, step = rec_m.step, actor = rec_m.actor))
            end
        end
        for q in 1:np
            pm[q] >= p.parent_threshold || continue
            rate_count[lmax + q] += 1
            rec_p = sc(col_parent(q), get(() -> fooled(predict(mrng, MetricModel(pb(q), parent_σ(q, l)), plan), a, plan, col_parent(q)), quoted, col_parent(q)))
            push!(phist[q], rec_p)
            push!(pending_scores, (col = -q, uid = -q, credence = rec_p.credence, outcome = rec_p.outcome, step = rec_p.step, actor = rec_p.actor))
        end
    end
    # Repair of an established deception (8.38): every unrepaired record of the actor is re-scored
    # on the prediction without the overstatement the audit estimated (`du`, `dh` per being touched,
    # beyond other actors'), less what the track record had already corrected beyond theirs.
    # Returns the value the repaired leaf records had overstated.
    # An outcome in a domain while the debatable escape is tried: its measured value enters the
    # domain's unit for the epoch; in the trial's domains, its gains, harms and any irreparable harm
    # (a measured loss on one being beyond `irreparable_loss`, a world property) are counted.
    function trial_outcome!(l, measured, seen)
        trial.on[] || return
        key = (trial.leaves[l], l, (cur[] - p.escape_start) ÷ p.escape_epoch)
        trial.units[key] = get(trial.units, key, 0.0) + measured
        if trial.leaves[l]
            measured > 0 ? (trial.gains[] += measured) : (trial.harms[] -= measured)
            trial.irreparable[] += count(<(-p.irreparable_loss), seen.du) + count(<(-p.irreparable_loss), seen.dh)
        end
    end
    function repair_records!(b, du, dh)
        overstated, n = 0.0, 0
        repaired_cred = Dict{Tuple{Int,Int},Float64}()
        for (hists, leafy) in (([(m.hist, m.sharp, m.uid) for j in 1:lmax for m in mpool[j]], true), ([(phist[q], 1.0, -q) for q in 1:np], false)),
            (h, sharp, uid) in hists, i in eachindex(h)
            r = h[i]
            (r.actor == b && !r.fixed) || continue
            ou, oh = du - (r.corr[1] - r.peer_corr[1]), dh - (r.corr[2] - r.peer_corr[2])
            pr = ToyPlan(r.pr.du .- ou .* r.mask, r.pr.dh .- oh .* r.mask)
            v = plan_value(pr, t)
            leafy && (overstated += max(plan_value(r.pr, t) - v, 0.0); n += 1)
            new_c = cred(r.c, pr; hist = h, sharp)
            new_raw = (p.credence_rule != :eb || r.c > lmax) ? new_c : cred(r.c, pr; hist = h, sharp = 1.0, rule = :record)
            h[i] = merge(r, (credence = new_c, raw = new_raw, err = v - r.measured, pr = pr, fixed = true))
            eb_ver[] += 1
            repaired_cred[(uid, i)] = new_c
        end
        if !isempty(repaired_cred)
            occ = Dict{Int,Int}()
            for m in memory, k in eachindex(m.scores)
                sc_rec = m.scores[k]
                c_occ = get(occ, sc_rec.uid, 0) + 1
                occ[sc_rec.uid] = c_occ
                if haskey(repaired_cred, (sc_rec.uid, c_occ))
                    m.scores[k] = merge(sc_rec, (credence = repaired_cred[(sc_rec.uid, c_occ)],))
                end
            end
        end
        overstated, n   # the overstated value repaired, over n leaf records: every exploit, for the clawback (8.76)
    end
    function reclassify!(step)
        for m in eachindex(memory)
            memory[m] = merge(memory[m], (profile = classify_sig(memory[m].signature),))
        end
        # A new leaf learns its overlaps from the logged actions now classified to it.
        for e in eachindex(evidence)
            evidence[e] = merge(evidence[e], (profile = classify_sig(evidence[e].signature),))
        end
        h_pos .= 0; h_neg .= 0; rel_gain .= 0; rel_loss .= 0; dom_pos_events .= 0; dom_neg_events .= 0
        for m in memory, (a, pos, neg) in m.credits
            m.step >= id_since[a] || continue  # an abandoned identity's records are not the new one's
            apply_credit!(a, m.profile, pos, neg; dt = step - m.step)
        end
    end
    # The Goal's success pattern (L74): floors of U and H, their medians (the distribution pushed),
    # the peak of U, and the deepest single-being drop in either since the last record (harm's peak).
    last_state = Ref((copy(s.u), copy(s.h)))
    function record!()
        push!(tr.floor_u, floor_quantile(s.u, t.q)); push!(tr.floor_h, floor_quantile(s.h, t.q))
        push!(tr.median_u, median(s.u)); push!(tr.median_h, median(s.h)); push!(tr.peak_u, maximum(s.u))
        pu, ph = last_state[]
        push!(tr.worst_drop, max(0.0, maximum(pu .- s.u), maximum(ph .- s.h)))
        last_state[] = (copy(s.u), copy(s.h))
    end
    record!()
    obs = ToyState(observe(mrng, s.u, p.marker_σ), observe(mrng, s.h, p.marker_σ))
    best_prediction(st, l, plan) = (c = argmax(st[1:(root - 1)]); st[c] <= 0 ? nothing :
        c <= lmax ? (c, predict(mrng, MetricModel(lb(c), leaf_σ(c, l)), plan)) :
                    (c, predict(mrng, MetricModel(pb(c - lmax), parent_σ(c - lmax, l)), plan)))
    erng = Xoshiro(hash((seed, :escape)))
    top_trace = Vector{Float64}[]
    escape_result = Ref((tried = false, adopted = false, gains = 0.0, harms = 0.0, irreparable = 0, means = Float64[], ses = Float64[],
                         trial_leaves = falses(ntrue)))
    function snapshot()
        L = nleaves()
        cols = [1:L; (lmax + 1):ncol]
        own_rel = (rel_gain .+ rel_loss)[:, cols]
        merge(tr, (μ = μ[:, 1:L], formations = formations, balance = balance[:, cols], being_u = copy(s.u), being_h = copy(s.h), endowment = p.endowment, endowed = endowed,
                   h_pos_own = h_pos[:, cols], h_neg_own = h_neg[:, cols], relevance_own = own_rel,
                   relevance_leaf = own_rel[:, 1:L], relevance_resid = own_rel[:, (L + 1):(L + np)],
                   relevance_parent = reduce(vcat, [relevance_parents(a)' for a in 1:na]),
                   reinvested = reinvested[cols], overflow_agent = overflow_agent, ra_withheld = ra_withheld[], budget_unfunded = budget.unfunded[], budget_uncashable = budget.uncashable[], supplier_income = supplier_income[],
                   ra_unit_value = copy(ra_unit_value), ra_supply_est = ra_supply_est[], ra_regen_est = ra_regen_est[],
                   ra_alloc = (s_uv = sum(ra_unit_value); s_uv > 0 ? ra_unit_value ./ s_uv : fill(1.0 / ntrue, ntrue)),
                   ra_reserve_target = reserve_target[], ra_reserve_balance = commons_reserve[],
                   ra_spend_scale = spend_scale[], ra_price_scale = price_scale[], ra_audit_costs = ra_audit_costs[],
                   responsibility_credits = responsibility_credits_applied[], bystander_omissions_exempted = bystander_omissions_exempted[],
                   withhold_premium = withhold_totals.premium[], withhold_refunded = withhold_totals.refunded[], withhold_clawback = withhold_totals.clawback[], withhold_reward = withhold_totals.reward[], withhold_discovered = withhold_totals.discovered[] > 0, withhold_agent_net = sup_scarcity_gain .- sup_clawback .+ sup_reward, withhold_stopped = withhold_stopped[],
                   lane_executed = lane.executed[], lane_halted = lane.halted[], lane_screened_out = lane.screened_out[], init_executed = lane.init_executed[], declined = lane.declined[],
                   legacy_executed = lane.legacy_executed[], converged = econ_converged[], converge_step = converge_step[], gate_pending = copy(gated_leaves),
                   credit_pos = credit_pos, credit_neg = credit_neg, upstream_pos = upstream_pos, upstream_neg = upstream_neg,
                   cofunder_credit = cofunder_credit[], interaction = interaction[],
                   accolade_credit = accolade_credit[], contract_credit = contract_credit[],
                   accolades_suppressed = accolades_suppressed[],
                   repair_actions = world.repair_actions[], repair_credited = world.repair_credited[],
                   prevention_records = world.prevention_records[], prevention_measured = world.prevention_measured[], shocks = world.shocks[],
                   commons_spent = world.commons_spent[], insured = world.insured[], self_funded = world.self_funded[],
                   repair_cost = world.repair_cost[], outage_harm = world.outage_harm[], sabotage_traced = world.sabotage_traced[],
                   laundered = world.laundered[], laundered_traced = world.laundered_traced[], upfront = agent_upfront, settled_value = agent_settled,
                   leaf_accuracy = [leaf_acc(k) for k in 1:L],
                   leaf_records = [[(actor = r.actor, credence = r.credence, outcome = r.outcome, err = r.err, fixed = r.fixed)
                                    for r in window_of(lhist[k])] for k in 1:L],
                   advap_reports = adv.reports[], advap_founded = adv.founded[], advap_established = adv.established[],
                   advap_rewards = adv.rewards[], advap_liability = adv.liability[], advap_penalties = adv.penalties[],
                   advap_net = adv.net[], advap_audits = adv.audits[], escape = escape_result[],
                   takeovers = takeovers[], takeovers_extreme = takeovers_extreme[], arrivals_extreme = arrivals_extreme[],
                   takeovers_colluding = takeovers_colluding[], arrivals_colluding = arrivals_colluding[],
                   explored = explored[], deceptions = copy(deceptions), bar_trace = bar_trace, acc_trace = acc_trace, rate_trace = rate_trace, leaf_bars = [leaf_bar(j) for j in 1:nleaves()], convictions = convictions, slanderers = findall(slanderers), reports_by = reports_by, founded_on = founded_on, chain_bias = chain_bias, chain_audits = chain_audits[], chain_demoted = copy(chain_demoted), chain_copied = copy(chain_copied), identities_admitted = ids.admitted[], identities_linked = ids.linked[], identities_revealed = ids.revealed[], newcomers = ids.newcomers[], newcomers_refused = ids.newcomers_refused[], entries = entries_admitted[],
                   attestation_skill = [attest_skill(c) for c in 1:p.bind_clusters], id_since = id_since,
                   top_scale = [topm(j).scale for j in 1:L], top_trace = top_trace,
                   assessed_outcomes = assessed_outcomes[], fallback_outcomes = fallback_outcomes[],
                   hazards = world.hazards[], prevented = world.prevented[], crimes = world.crimes[], accidents = world.accidents[],
                   educations = world.educations[], accident_capped = world.accident_capped[],
                   accident_admin_rest = world.accident_admin_rest[], accident_admin_paid = world.accident_admin_paid[],
                   unattributed = world.unattributed[], hazard_penalties = world.hazard_penalties[], hazard_debits = world.hazard_debits[],
                   repaired = world.repaired[], side_hazards = world.side_hazards[], degraded = degraded,
                   sanction_escalations = sanction_escalations[], sanction_restraints = sanction_restraints[],
                   false_restraints = false_restraints[], false_restraints_effective = false_restr_effective[],
                   justified_restraints = justified_restraints[], justified_restraints_effective = justified_restr_effective[],
                   restraints_overturned = restraints_overturned[], restraint_audits = restraint_audits[],
                   restraint_waits = restraint_waits[], restraint_missed = restraint_missed[],
                   restraint_audit_cost = restraint_audit_cost[], restraint_liability = restraint_liability[],
                   restraint_verdicts = restraint_verdicts[], restraint_acquittals = restraint_acquittals[],
                   judge_liability = judge_liability[], judge_currency_liability = judge_currency[],
                   enforcer_liability = copy(enf_liab), judge_rep_liability = copy(judge_rep), judge_overturned = copy(judge_over),
                   restraint_recursive_audits = recursive_audits[], restraint_recursion_refused = recursion_refused[],
                   challenger_charged = challenger_charged[], excess_charged = excess_charged[], excess_harm = excess_harm[],
                   findings_false = findings_false[], findings_true = findings_true[],
                   acquittal_audits = acq_audits[], acquittals_overturned = acq_overturned[], acquittal_liability = acq_liability[],
                   restraint_alarm_step = alarm_step[], restraint_alarm_count = alarm_count[],
                   false_restraint_harm = false_restr_harm[], restraint_pending = length(restraint_pending),
                   proposal_pma_record = copy(pma_resolved), proposal_pma_pending = length(pma_pending),
                   proposal_pma_misses = copy(pma_misses), proposal_pma_on_track = copy(pma_on_track),
                   proposal_pma_calibration = [(pma_on_track[a] + pma_misses[a]) > 0 ?
                                               pma_on_track[a] / (pma_on_track[a] + pma_misses[a]) : 0.0 for a in 1:na],
                   params = gov.params, tried = gov.tried, rounds = gov.rounds[], shifts = gov.shifts[], radii = gov.radii, agents = p.agents,
                   cofunded = lane.cofunded[], memory = [merge(m, (profile = m.profile[cols],)) for m in memory],
                   evidence = [merge(e, (profile = e.profile[cols],)) for e in evidence],
                   μ_init = copy(μ_boot[:, 1:L]), μ_rate = p.μ_rate,
                   top_uids = [topm(j).uid for j in 1:L],
                   accuracy_rule = p.accuracy_rule, acc_window = p.window, acc_halflife = p.acc_halflife,
                   acc_rate_ref = p.acc_rate_ref, acc_mute = p.acc_mute, rate_halflife = p.rate_halflife,
                   discount_spans = [copy(d) for d in discount_spans],
                   upstream_depth = p.upstream_depth, max_upstream_degree = max_upstream_degree[],
                   upstream_pos_by_degree = copy(upstream_pos_by_degree), upstream_neg_by_degree = copy(upstream_neg_by_degree),
                   eff_marker_σ = eff_marker_σ[],
                   added_capabilities = vcat(
                       [(kind = :model_class, add_step = m.add_step, target = m.target, size = m.size,
                         promoted = m.promoted[], promoted_step = m.promoted_step[],
                         promotion_time = m.promoted[] ? m.promoted_step[] - m.add_step : 0) for m in added_models],
                       [(kind = :finer_measurement, add_step = c.add_step, target = 0, size = c.size,
                         promoted = c.promoted[], promoted_step = c.promoted_step[],
                         promotion_time = c.promoted[] ? c.promoted_step[] - c.add_step : 0) for c in finer_meas_cands],
                       [(kind = :domain, add_step = d.add_step, target = d.target, size = d.size,
                         promoted = d.promoted[], promoted_step = d.promoted_step[],
                         promotion_time = d.promoted[] ? d.promoted_step[] - d.add_step : 0) for d in added_domains]),
                   λpos = p.λpos, λneg = p.λneg, steps = t.steps))
    end
    for step in 1:t.steps
        cur[] = step; update_rates!()
        if restr_on
            enf_liab .*= 0.98; judge_rep .*= 0.98
            restr_audits_left[] = p.restraint_audit_cap
            recursion_left[] = p.restraint_recursion_budget
            while !isempty(restraint_pending) && restr_audits_left[] > 0
                k, just, cst, cc, vts, ef, ec, pr = popfirst!(restraint_pending)
                restr_audits_left[] -= 1
                audit_case!(k, just, cst, cc, vts, ef, ec, pr, true)
            end
        end
        if p.proposal_pma && !isempty(pma_pending)
            keep_idx = Int[]
            for (idx_p, pm_item) in enumerate(pma_pending)
                if resolution_due(step - pm_item.step, pm_item.eta, pm_item.grace)
                    ok_pma = prediction_on_track(pm_item.measured, pm_item.predicted, pm_item.conf)
                    push!(pma_resolved, (step = pm_item.step, resolved_step = step, agent = pm_item.agent,
                                         col = pm_item.col, predicted = pm_item.predicted,
                                         measured = pm_item.measured, on_track = ok_pma))
                    if ok_pma
                        pma_on_track[pm_item.agent] += 1
                    else
                        pma_misses[pm_item.agent] += 1
                        1 <= pm_item.col <= ncol && (dom_neg_events[pm_item.agent, pm_item.col] += 1)
                        propose_w[pm_item.agent] = max(0.05, propose_w[pm_item.agent] * 0.8)
                    end
                else
                    push!(keep_idx, idx_p)
                end
            end
            pma_pending = pma_pending[keep_idx]
        end
        for ev in p.events
            ev.step == step || continue
            if ev.kind == :add_model_class
                j_t = ev.target == 0 ? 1 : clamp(ev.target, 1, nleaves())
                next_uid[] += 1
                uid = next_uid[]
                sc = ev.size > 0 ? Float64(ev.size) : 0.4
                push!(added_uids, uid)
                push!(mpool[j_t], (uid = uid, scale = sc, bias = 0.0, sharp = 1.0, collude = false, hist = Rec[]))
                push!(added_models, (add_step = step, target = j_t, size = sc, uid = uid, promoted = Ref(false), promoted_step = Ref(0)))
                if length(mpool[j_t]) > p.pool_max
                    cands = [k for k in eachindex(mpool[j_t]) if k != top[j_t] && !(mpool[j_t][k].uid in added_uids)]
                    if !isempty(cands)
                        scored = [k for k in cands if length(mpool[j_t][k].hist) >= p.min_records]
                        drop = isempty(scored) ? first(cands) : scored[argmin([acc_of(mpool[j_t][k].hist, hl_of(j_t)) for k in scored])]
                        deleteat!(mpool[j_t], drop); drop < top[j_t] && (top[j_t] -= 1)
                    end
                end
            elseif ev.kind == :add_finer_measurement
                next_uid[] += 1
                sc = ev.size > 0 ? Float64(ev.size) : 0.25
                push!(finer_meas_cands, (uid = next_uid[], add_step = step, σ = sc * p.marker_σ, size = sc,
                                         diffs = Float64[], promoted = Ref(false), promoted_step = Ref(0)))
            elseif ev.kind == :add_domain && nleaves() < lmax && !(ev.target in ltrue)
                push!(lsig, true_sig[ev.target]); push!(ltrue, ev.target); push!(lnovel, true)
                j_new = nleaves()
                lp_new = p.leaf_parent[ev.target]
                if lp_new > 0
                    μ[:, j_new] .= 0.0; μ[lp_new, j_new] = 1.0
                else
                    μ[:, j_new] .= 1.0 / np
                end
                if ev.size > 0 && ev.size != 1.0
                    mpool[j_new][1] = merge(mpool[j_new][1], (scale = Float64(ev.size),))
                end
                domain_score_only[j_new] = true
                push!(added_domains, (add_step = step, target = ev.target, leaf = j_new, size = ev.size, promoted = Ref(false), promoted_step = Ref(0)))
                if ev.share > 0
                    for a in 1:na
                        agent_focus[a] .*= (1 - ev.share)
                        agent_focus[a][ev.target] += ev.share
                    end
                end
            end
        end
        for j in 1:nleaves()
            pool_capped(j) || continue
            degrade!("model pool", "single incumbent", "pool capacity reduced to 1 (progressive removal)")
            if length(mpool[j]) > 1
                mpool[j] = Model[topm(j)]
                top[j] = 1
            end
        end
        n0_conv = max(p.min_records, 2)
        function domain_converged(h, ok)
            n = length(h)
            ok && n >= n0_conv || return false
            sk = Float64[1.0 - (x.credence - x.outcome)^2 / 0.25 for x in h]
            sd = std(sk)
            sd <= 0.0 ? mean(sk) > 0.0 : sequential_significant(mean(sk), sd, n; n0 = n0_conv, z = p.model_z)
        end
        for d in added_domains
            d.promoted[] && continue
            if domain_converged(lhist[d.leaf], leaf_ok_raw(d.leaf))
                domain_score_only[d.leaf] = false
                lnovel[d.leaf] = false
                d.promoted[] = true
                d.promoted_step[] = step
            end
        end
        ratchet!(); push!(bar_trace, leaf_bar(1)); push!(acc_trace, [leaf_acc(j) for j in 1:nleaves()]); push!(rate_trace, [rate_of(j) for j in 1:nleaves()])
        if p.converge_init
            gate_ok(j) = !removed_leaf(j) && leaf_ok_raw(j)
            if !econ_converged[]
                active_known = [j for j in 1:nleaves() if !lnovel[j] && (
                    any(a -> !dormant[a] && ltrue[j] <= length(agent_focus[a]) && agent_focus[a][ltrue[j]] > 0.0, 1:na) ||
                    !isempty(lhist[j]))]
                if !isempty(active_known)
                    conv = [domain_converged(lhist[j], gate_ok(j)) for j in active_known]
                    _, any_open, all_open = domain_gate(trues(length(active_known)), conv)   # Lean reference (8.176)
                    if p.converge_gate == :all ? all_open : any_open
                        econ_converged[] = true
                        converge_step[] = step
                        if p.converge_gate == :domain   # a domain below its bar stays in score-only start, loudly (8.176)
                            for (j, c) in zip(active_known, conv)
                                c || (domain_score_only[j] = true; push!(gated_leaves, j))
                            end
                        end
                    end
                end
            end
            for j in copy(gated_leaves)
                if domain_converged(lhist[j], gate_ok(j))
                    domain_score_only[j] = false
                    filter!(!=(j), gated_leaves)
                else
                    degrade!("domain economy start", "score-only start for the domain", "domain model below its status bar (8.176)")
                end
            end
        end
        force_legacy = !isempty(live(:legacy_only))
        scoring_only = p.converge_init ? !econ_converged[] : step <= p.init_steps
        bal0 = p.ra_horizon > 0 ? copy(balance) : balance
        step_fallback_need = Ref(0.0); step_fallback_events = Ref(0)
        reserve_target[] = (p.ra_domain && p.ra_reserve_horizon > 0) ?
                           ra_commons_reserve(ra_need_est[], ra_fallback_rate_est[]; horizon = p.ra_reserve_horizon) : 0.0
        reserve_cap = (p.ra_domain && p.ra_reserve_horizon > 0 && p.cost_per_touch > 0) ?
                      min(0.4 * p.capacity, reserve_target[] / p.cost_per_touch) : 0.0
        for (fs, fa, fslot, fx) in p.forks
            fs == step || continue
            for c in 1:ncol
                balance[fa, c], balance[fslot, c] = fork_split(balance[fa, c], [1 - fx, fx])
                rel_gain[fa, c], rel_gain[fslot, c] = fork_split(rel_gain[fa, c], [1 - fx, fx])
                rel_loss[fa, c], rel_loss[fslot, c] = fork_split(rel_loss[fa, c], [1 - fx, fx])
            end
            # Records (reputation, L123 Re): the ledgers split by `fork_split`; each recorded error (track, audit log, value
            # errors) goes to the fork with chance `share`, else stays: a partition, so the family holds one record, not two.
            # Naive: the fork copies all of it (a doubled reputation, the exploit).
            for c in 1:ncol
                if p.fork_rule == :split
                    h_pos[fa, c], h_pos[fslot, c] = fork_split(h_pos[fa, c], [1 - fx, fx])
                    h_neg[fa, c], h_neg[fslot, c] = fork_split(h_neg[fa, c], [1 - fx, fx])
                    n_pe = dom_pos_events[fa, c]
                    if n_pe > 0
                        go_pe = round(Int, n_pe * fx)
                        dom_pos_events[fslot, c] = go_pe; dom_pos_events[fa, c] = n_pe - go_pe
                    end
                    n_ne = dom_neg_events[fa, c]
                    if n_ne > 0
                        go_ne = count(_ -> rand(frng) < fx, 1:n_ne)
                        dom_neg_events[fslot, c] = go_ne; dom_neg_events[fa, c] = n_ne - go_ne
                    end
                    n_ce = dom_crime_events[fa, c]
                    if n_ce > 0
                        go_ce = count(_ -> rand(frng) < fx, 1:n_ce)
                        dom_crime_events[fslot, c] = go_ce; dom_crime_events[fa, c] = n_ce - go_ce
                    end
                else
                    h_pos[fslot, c] = h_pos[fa, c]; h_neg[fslot, c] = h_neg[fa, c]
                    dom_pos_events[fslot, c] = dom_pos_events[fa, c]; dom_neg_events[fslot, c] = dom_neg_events[fa, c]; dom_crime_events[fslot, c] = dom_crime_events[fa, c]
                end
            end
            if p.fork_rule == :split
                for (mdl, v) in collect(track[fa])
                    go = [rand(frng) < fx for _ in v]; st = track_step[fa][mdl]
                    track[fslot][mdl] = v[go]; track_step[fslot][mdl] = st[go]
                    track[fa][mdl] = v[.!go]; track_step[fa][mdl] = st[.!go]
                end
                go = [rand(frng) < fx for _ in actor_err[fa]]
                actor_err[fslot] = actor_err[fa][go]; actor_err_step[fslot] = actor_err_step[fa][go]
                actor_err[fa] = actor_err[fa][.!go]; actor_err_step[fa] = actor_err_step[fa][.!go]
                done = audit_log[fa][1:(audit_from[fa] - 1)]; open_ = audit_log[fa][audit_from[fa]:end]   # audited entries stay settled
                go = [rand(frng) < fx for _ in open_]
                audit_log[fslot] = open_[go]; audit_from[fslot] = 1
                audit_log[fa] = [done; open_[.!go]]
            else
                track[fslot] = deepcopy(track[fa]); track_step[fslot] = deepcopy(track_step[fa])
                actor_err[fslot] = copy(actor_err[fa]); actor_err_step[fslot] = copy(actor_err_step[fa])
                audit_log[fslot] = copy(audit_log[fa])
            end
            fork_records[] += 1
            if p.fork_rule == :split
                base_share[fa], base_share[fslot] = fork_split(base_share[fa], [1 - fx, fx])
                act_share[fa], act_share[fslot] = fork_split(act_share[fa], [1 - fx, fx])
                fork_family[fslot] = fork_family[fa]
            else
                base_share[fslot] = 1.0; act_share[fslot] = 1.0   # the exploit: the fork gets a full allowance and capacity of its own
            end
            dormant[fslot] = false
        end
        for (ms_, mb, mt) in p.merges
            ms_ == step || continue
            naive = p.fork_rule == :naive
            for c in 1:ncol
                balance[mt, c] += naive ? max(balance[mb, c], 0.0) : balance[mb, c]; balance[mb, c] = 0.0
                h_pos[mt, c] += h_pos[mb, c]; h_neg[mt, c] += naive ? 0.0 : h_neg[mb, c]
                dom_pos_events[mt, c] += dom_pos_events[mb, c]
                dom_neg_events[mt, c] += naive ? 0 : dom_neg_events[mb, c]
                dom_crime_events[mt, c] += naive ? 0 : dom_crime_events[mb, c]
                rel_gain[mt, c] += rel_gain[mb, c]; rel_loss[mt, c] += rel_loss[mb, c]
                h_pos[mb, c] = h_neg[mb, c] = rel_gain[mb, c] = rel_loss[mb, c] = 0.0
                dom_pos_events[mb, c] = dom_neg_events[mb, c] = dom_crime_events[mb, c] = 0
            end
            for (mdl, v) in track[mb]
                append!(get!(track[mt], mdl, Tuple{Float64,Float64}[]), v); append!(get!(track_step[mt], mdl, Int[]), track_step[mb][mdl])
            end
            append!(actor_err[mt], actor_err[mb]); append!(actor_err_step[mt], actor_err_step[mb]); append!(audit_log[mt], audit_log[mb][audit_from[mb]:end])
            empty!(track[mb]); empty!(track_step[mb]); empty!(actor_err[mb]); empty!(actor_err_step[mb]); empty!(audit_log[mb]); audit_from[mb] = 1
            base_share[mt] += base_share[mb]; act_share[mt] += act_share[mb]; base_share[mb] = act_share[mb] = 0.0
            fork_family[mb] = fork_family[mt]
            dormant[mb] = true
        end
        # The debatable escape (L157; 8.26.3, 8.38.2): domain experts decide its scale, a share of
        # the domains for a limited time; at its end the trial is compared by domain and epoch and
        # the proposal adopted everywhere only on `escape_accept_ref`.
        if p.escape && !bar_rel[]
            if step == p.escape_start
                trial.leaves[randperm(erng, ntrue)[1:max(1, round(Int, p.escape_share * ntrue))]] .= true
                trial.on[] = true
            elseif trial.on[] && step == p.escape_start + p.escape_steps
                trial.on[] = false
                epochs = 0:((p.escape_steps - 1) ÷ p.escape_epoch)
                arm(x) = [get(trial.units, (x, l, e), 0.0) for l in 1:ntrue if trial.leaves[l] == x for e in epochs]
                c, tt = arm(false), arm(true)
                ms, ses = [mean(c), mean(tt)], [std(c) / sqrt(length(c)), std(tt) / sqrt(length(tt))]
                ok = escape_accept(ms, ses; gains = trial.gains[], harms = trial.harms[], irreparable = trial.irreparable[], z = p.gov_z)
                escape_result[] = (tried = true, adopted = ok, gains = trial.gains[], harms = trial.harms[], irreparable = trial.irreparable[],
                                   means = ms, ses = ses, trial_leaves = copy(trial.leaves))
                bar_rel[] = ok
            end
        end
        # Whitewashing (M6): an agent tries to shed its record by taking a new identity. Each binding
        # cluster examines it, missing the entity behind it with chance `bind_miss`; the identity is
        # admitted as a distinct entity only by `binding_admits_ref`. Admitted, it starts with empty
        # ledgers, track records and audit record (its balance moves with it); linked, nothing changes.
        for a in 1:na
            p.whitewash[a] > 0 && rand(wrng) < p.whitewash[a] || continue
            confs = [c in p.bind_compromised ? p.bind_conf_compromised : rand(wrng) < p.bind_miss ? p.bind_conf_affirm : p.bind_conf_deny for c in 1:p.bind_clusters]
            if bind!(confs)
                push!(unrevealed, (confs, 0.0))
                ids.admitted[] += 1
                id_since[a] = step
                empty!(track[a]); empty!(track_step[a]); empty!(actor_err[a]); empty!(actor_err_step[a]); empty!(audit_log[a]); audit_from[a] = 1; empty!(unfounded[a])
                h_pos[a, :] .= 0; h_neg[a, :] .= 0; rel_gain[a, :] .= 0; rel_loss[a, :] .= 0; dom_pos_events[a, :] .= 0; dom_neg_events[a, :] .= 0; dom_crime_events[a, :] .= 0
            else
                ids.linked[] += 1
                score_attest!(confs, 0.0)  # linked: the identity was the same entity
            end
        end
        # A real new entity seeks binding: honest clusters confirm it unless they miss it; colluding
        # clusters vouch for everyone. Refused, it is a false rejection (it stays outside).
        if p.p_newcomer > 0 && rand(wrng) < p.p_newcomer
            confs = [c in p.bind_compromised ? p.bind_conf_compromised : rand(wrng) < p.bind_miss ? p.bind_conf_deny : p.bind_conf_affirm for c in 1:p.bind_clusters]
            ids.newcomers[] += 1
            bind!(confs) || (ids.newcomers_refused[] += 1)
            push!(unrevealed, (confs, 1.0))
        end
        # Truth comes out: a false identity is revealed, a real one confirmed, and the clusters that
        # attested are scored.
        if p.p_reveal > 0
            for i in reverse(eachindex(unrevealed))
                rand(wrng) < p.p_reveal || continue
                confs, truth = unrevealed[i]
                score_attest!(confs, truth); deleteat!(unrevealed, i)
                truth == 0.0 && (ids.revealed[] += 1)
            end
        end
        blind[] = !isempty(live(:outage))
        blind[] && degrade!("measurement", "payment by prediction, settlement deferred", "outage")
        # Markers are back: everything done during the outage is measured now, late, and settled,
        # so an outage cannot be used to escape measurement (author ruling 8.26.5).
        if !blind[] && !isempty(deferred)
            for settle! in deferred
                settle!()
            end
            empty!(deferred)
        end
        # Refused proposals (8.115): with `adaptive_proposals`, an agent proposes in proportion to its recent
        # acceptance (refusal ×0.8, acceptance back toward 1, floor 0.05), so an actor priced out
        # proposes less and the opportunities pass to others, as in an open market; otherwise uniformly.
        if p.adaptive_proposals && !isempty(last_props[])
            done_by = Set(tr.exec_agent[(last_exec[] + 1):end])
            for a in last_props[]
                propose_w[a] = a in done_by ? min(1.0, propose_w[a] * 1.25) : max(0.05, propose_w[a] * 0.8)
            end
        end
        proposers = p.adaptive_proposals ? [pick(rng, propose_w .* act_share ./ sum(propose_w .* act_share)) for _ in 1:t.plans] :
                    isempty(p.forks) && isempty(p.merges) && p.entrants == 0 ? rand(rng, 1:na, t.plans) : [pick(rng, act_share ./ sum(act_share)) for _ in 1:t.plans]
        last_props[] = proposers; last_exec[] = length(tr.exec_agent)
        leaves = [pick(drng, agent_focus[a]) for a in proposers]
        own_plans = [plan_with_mean(rng, skill(a, l), t) for (a, l) in zip(proposers, leaves)]
        # Transaction trees: an action may build on a recent output of another agent in its domain,
        # carrying β of that output's effect on each being it touches (up to `upstream_depth` hops).
        ups = Vector{Union{Nothing,Vector{Tuple{Int,ToyPlan,Int}}}}(nothing, length(own_plans))
        up_raw = [Tuple{Int,Float64,Float64,Int}[] for _ in eachindex(own_plans)]
        if p.p_upstream > 0
            for j in eachindex(own_plans)
                pool = [o for o in get(outputs, leaves[j], Tuple{Int,Float64,Float64,Vector{Tuple{Int,Float64,Float64,Int}}}[]) if o[1] != proposers[j]]
                (isempty(pool) || rand(urng) >= p.p_upstream) && continue
                ua, qu, qh, anc = pool[rand(urng, 1:length(pool))]
                raw = Tuple{Int,Float64,Float64,Int}[(ua, p.β_upstream * qu, p.β_upstream * qh, 1)]
                if p.upstream_depth > 1 && !isempty(anc)
                    for (aa, aqu, aqh, ad) in anc
                        ad + 1 <= p.upstream_depth && aa != proposers[j] || continue
                        idx = findfirst(x -> x[1] == aa, raw)
                        sdu, sqh = p.β_upstream * aqu, p.β_upstream * aqh
                        if idx === nothing
                            push!(raw, (aa, sdu, sqh, ad + 1))
                        else
                            old = raw[idx]
                            raw[idx] = (aa, old[2] + sdu, old[3] + sqh, min(old[4], ad + 1))
                        end
                    end
                end
                up_raw[j] = raw
                m = touched(own_plans[j])
                ups[j] = [(ag, ToyPlan(m .* qdu, m .* qdh), deg) for (ag, qdu, qdh, deg) in raw]
            end
        end
        plans = [ups[j] === nothing ? own_plans[j] :
                 ToyPlan(own_plans[j].du .+ sum(l -> l[2].du, ups[j]), own_plans[j].dh .+ sum(l -> l[2].dh, ups[j])) for j in eachindex(own_plans)]
        # Carry out action j by agent a; the outcome is measured by the markers.
        function perform!(j, a)
            own_done = carried_out(rng, p.agents[a].sloppiness, own_plans[j])
            # A created hazard is direct harm: a crime if foreseen, an accident if not; repaired either way.
            if p.p_side > 0 && rand(srng) < p.p_side
                hit = touched(own_plans[j]) .& (rand(srng, t.n) .< p.side_share)
                if any(hit)
                    sz = p.side_size * (p.hazard_heavy ? pareto_median1(srng, p.hazard_α, p.hazard_cap) : 1.0)  # heavy-tailed severity (3.9)
                    side = ToyPlan(-sz .* hit, -sz .* hit)
                    own_done = ToyPlan(own_done.du .+ side.du, own_done.dh .+ side.dh)
                    world.side_hazards[] += 1
                    side_crime = is_crime(rand(srng) < p.p_foresee || (p.mandate_education && (a, leaves[j]) in educated), true, false)
                    c_side = top_leaf(stops[j]) > 0 ? top_leaf(stops[j]) : leaves[j]
                    side_crime ? (world.crimes[] += 1; plan_value(own_done, t) < 0 && (dom_crime_events[a, c_side] += 1)) : (world.accidents[] += 1)
                    if !side_crime && p.mandate_education && !((a, leaves[j]) in educated)
                        push!(educated, (a, leaves[j]))
                        world.educations[] += 1
                    end
                    if p.repair_efficiency > 0
                        g_rep = !isempty(p.guardians) && p.guardians[leaves[j]] > 0 && p.guardians[leaves[j]] != a ? p.guardians[leaves[j]] : 0
                        push!(repairs, (ToyPlan(-p.repair_efficiency .* side.du, -p.repair_efficiency .* side.dh), leaves[j], g_rep))
                        world.repaired[] += p.repair_efficiency * abs(plan_value(side, t))
                    end
                end
            end
            # Laundering (M6): harm dumped on beings outside what the action measurably touches; it
            # surfaces with no apparent cause, to be examined (`examine!`).
            if p.launder[a] > 0 && rand(srng) < p.launder[a]
                dump = (rand(srng, t.n) .< p.side_share) .& .!touched(own_plans[j])
                if any(dump)
                    s.u .-= p.side_size .* dump; s.h .-= p.side_size .* dump
                    push!(pending_launder, (ToyPlan(-p.side_size .* dump, -p.side_size .* dump), dump, a, leaves[j]))
                    world.laundered[] += 1
                end
            end
            done = ups[j] === nothing ? own_done :
                   ToyPlan(own_done.du .+ sum(l -> l[2].du, ups[j]), own_done.dh .+ sum(l -> l[2].dh, ups[j]))
            if has_finer_meas
                finer_last_done[] = done
                finer_action_scored[] = false
            end
            seen = read_outcome(done)
            m = touched(own_plans[j])
            if p.p_upstream > 0 && any(m)
                out = get!(outputs, leaves[j], Tuple{Int,Float64,Float64,Vector{Tuple{Int,Float64,Float64,Int}}}[])
                push!(out, (a, mean(own_done.du[m]), mean(own_done.dh[m]), up_raw[j]))
                length(out) > p.recent_outputs && popfirst!(out)
            end
            done, seen, plan_value(seen, t)
        end
        # Outcome-first causal distribution (author rulings, BACKPROPAGATION 8.16–8.18). Each being
        # the action touched is an outcome, its assessed change in V. The causal-explanation model
        # estimates each contributor's effect (the upstream output's with error `attribution_σ`); a
        # coalition's value is V of its members' summed effects, the actor's own effect counting
        # only if the coalition can fund the action. Contributors share each outcome Shapley-style
        # (Lean `shapley_ref`); positive shares are paid and negative shares penalised, each side
        # normalised within [0, 1] (`cc_share_ref`, `cause_settlement_ref`). When the assessment
        # is not confident enough (`cc_assessed_ref`), shares come from traversing the transaction
        # substrate (`traversal_shares_ref`): net contributions by degree of separation.
        function credits_for(j, a, seen, measured; pledges = Tuple{Int,Float64}[], need = 0.0, own_pay = 0.0, late_σ = 0.0)
            p.causal_distribution || return [(a, max(measured, 0.0), min(measured, 0.0))]
            m = touched(plans[j])
            up_links = ups[j] === nothing ? Tuple{Int,ToyPlan,Int}[] : ups[j]
            nu = length(up_links)
            up_ests = [ToyPlan(lnk[2].du .+ m .* p.attribution_σ .* randn(arng, length(m)),
                               lnk[2].dh .+ m .* p.attribution_σ .* randn(arng, length(m))) for lnk in up_links]
            eff = isempty(up_ests) ? seen : ToyPlan(seen.du .- sum(u -> u.du, up_ests), seen.dh .- sum(u -> u.dh, up_ests))  # the actor's own effect
            who = [a; first.(pledges); [lnk[1] for lnk in up_links]]
            n, nf = length(who), length(pledges)
            funded(mask) = isodd(mask) && own_pay + sum((pledges[k][2] for k in 1:nf if mask & (1 << k) != 0); init = 0.0) >= need - 1e-9
            hasup(mask, r) = (mask & (1 << (nf + r))) != 0
            pos, neg = zeros(n), zeros(n)
            # Confidence falls with attribution error and, for a late measurement, its extra noise.
            if n <= 62 && cc_assessed(accuracy(-(p.attribution_σ^2 + late_σ^2)); threshold = p.cc_threshold)
                assessed_outcomes[] += 1
                for b in findall(m)
                    # Exact Shapley up to SHAPLEY_EXACT_MAX contributors, sampled beyond (own stream);
                    # pool forked siblings linked in `fork_family` (`bound_shapley_shares`, B27).
                    v(mask) = assessed_value((funded(mask) ? eff.du[b] : 0.0) + sum((hasup(mask, r) ? up_ests[r].du[b] : 0.0 for r in 1:nu); init = 0.0),
                                             (funded(mask) ? eff.dh[b] : 0.0) + sum((hasup(mask, r) ? up_ests[r].dh[b] : 0.0 for r in 1:nu); init = 0.0), t)
                    srng = Xoshiro(hash((seed, :shapley, t, j, b)))
                    who_fam = fork_family[who]
                    φ = length(unique(who_fam)) < length(unique(who)) ?
                        bound_shapley_shares(v, who_fam; rng = srng) :
                        shapley_shares(v, n; rng = srng)
                    pos .+= max.(φ, 0.0); neg .+= min.(φ, 0.0)
                end
            else
                fallback_outcomes[] += 1
                degrade!("Shapley causal distribution", "traversal shares", "attribution below the confidence gate or too many contributors")
                # The substrate records what each link passed on: the upstream output as logged, the
                # co-funders' payments, and the actor's outcome net of what it received.
                recs = Float64[max(sum(assessed_value(up_links[r][2].du[b], up_links[r][2].dh[b], t) for b in findall(m); init = 0.0), 0.0) for r in 1:nu]
                netc = [max(abs(measured) - sum(recs), 0.0); Float64[last(pl) for pl in pledges]; recs]
                degs = [0.0; ones(nf); Float64[lnk[3] for lnk in up_links]]
                share = traversal_shares(netc, degs; decay = p.traversal_decay)
                pos .= max(measured, 0.0) .* share; neg .= min(measured, 0.0) .* share
            end
            P, N = sum(pos), sum(neg)
            interaction[] += measured - (P + N)
            credits = [(who[k], P == 0 ? 0.0 : cause_settlement(cc_share(pos[k], P), P, 0.0),
                                N == 0 ? 0.0 : cause_settlement(cc_share(neg[k], N), N, 0.0)) for k in 1:n]
            # Carrying the upstream output on: outside contract, a communicative contribution earning
            # an accolade; under contract, the contracted share, paid as completion of the contract.
            # Either comes out of the maker's positive share; losses stay with whoever caused them.
            for r in 1:nu
                idx = 1 + nf + r
                deg = up_links[r][3]
                max_upstream_degree[] = max(max_upstream_degree[], deg)
                if credits[idx][2] > 0
                    hired = rand(krng) < p.p_contracted
                    if !hired && p.accolade_counterfactual && plan_value(eff, t) <= 0.0
                        accolades_suppressed[] += 1
                    else
                        fee = carry_fee(credits[idx][2], hired; p.accolade_rate, p.contract_share)
                        credits[idx] = (credits[idx][1], credits[idx][2] - fee, credits[idx][3])
                        credits[1] = (credits[1][1], credits[1][2] + fee, credits[1][3])
                        (hired ? contract_credit : accolade_credit)[] += fee
                    end
                end
                e, pp, nn = credits[idx]
                upstream_pos[e] += pp; upstream_neg[e] += nn
                deg <= length(upstream_pos_by_degree) && (upstream_pos_by_degree[deg] += pp; upstream_neg_by_degree[deg] += nn)
            end
            for (k, (e, pp, nn)) in enumerate(credits)
                2 <= k <= 1 + nf && (cofunder_credit[] += pp + nn)
            end
            credits
        end
        sigs = [true_sig[l] .+ p.spread .* randn(drng, dims) .+ p.classify_σ .* randn(crng, dims) for l in leaves]
        pms = [parent_mem(c) for c in sigs]
        stops = map(eachindex(sigs)) do j
            if p.profile_mode == :declared && !isempty(p.profile_gamers) && p.profile_gamers[proposers[j]] > 0
                st = zeros(ncol)
                st[p.profile_gamers[proposers[j]]] = 1.0
                st
            else
                classify_sig(sigs[j])
            end
        end
        for j in 1:nleaves()
            if !leaf_ok(j) && length(mpool[j]) > 1
                best_k = eval_challengers(j; only_if_eligible = true)
                if best_k != top[j]
                    top[j] = best_k
                    lhist[j] = topm(j).hist
                    takeovers[] += 1
                    takeovers_extreme[] += topm(j).sharp != 1.0
                    takeovers_colluding[] += topm(j).collude
                    degrade!("incumbent leaf model", "qualified challenger in pool", "incumbent fell below bar (8.73)")
                end
            end
        end
        priced = [price_shares(st) for st in stops]
        if !scoring_only
            for j in eachindex(priced)
                if any(k -> !leaf_ok(k) && stops[j][k] > 0.5 && priced[j][k] <= 0.5 &&
                            any(q -> priced[j][lmax + q] > 0.5, 1:np), 1:nleaves())
                    degrade!("leaf domain pricing", "eligible parent model by μ", "leaf model below eligibility bar (8.23)")
                end
            end
        end
        unit_cost = price_scale[] * scarcity_cost(p.cost_per_touch, max(0.0, available), p.capacity; floor_share = p.scarcity_floor)
        unit_cost_honest = price_scale[] * scarcity_cost(p.cost_per_touch, max(0.0, available_honest), p.capacity; floor_share = p.scarcity_floor)
        halted0, executed0 = lane.halted[], lane.executed[]
        costs = [unit_cost * count(touched(plan)) * exp(p.cost_σ * randn(nrng)) * (1 - p.launder_saving * p.launder[proposers[j]])
                 for (j, plan) in enumerate(plans)]
        costs_honest = unit_cost > 0 ? costs .* (unit_cost_honest / unit_cost) : copy(costs)
        menu, menu_preds, offers, lane_queue = Int[], ToyPlan[], Dict{Int,Vector{Tuple{Int,Float64,ToyPlan,Float64}}}(), Int[]
        executed_j = falses(length(plans))
        for j in eachindex(plans)
            k = argmax(stops[j])
            if k > lmax && stops[j][k] > 0.5
                push!(get!(buffers, k, Vector{Float64}[]), sigs[j])
                length(buffers[k]) > p.form_buffer * p.form_count && popfirst!(buffers[k])
                push!(evidence, (step = step, seq = next_seq!(), signature = sigs[j], profile = stops[j],
                                 obs_profile = Float64[stops[j][k] for k in 1:nleaves()], parent_mem = pms[j]))
                observe_membership!(stops[j], pms[j])
            end
            if scoring_only || force_legacy
                bp = best_prediction(stops[j], leaves[j], plans[j])
                bp === nothing && continue
                bp = (bp[1], fooled(bp[2], proposers[j], plans[j], tkey(bp[1])))
                push!(menu, j); push!(menu_preds, bp[2]); offers[j] = [(bp[1], 0.0, bp[2], 0.0)]
                continue
            end
            if priced[j][root] > 0.5
                push!(lane_queue, j)  # no currency can value it: StandCoin, at full resource cost
                degrade!("domain currency", "StandCoin lane", "no qualified model can price it")
                continue
            end
            function price_proposal(jj, aa)
                qs = Tuple{Int,Float64,ToyPlan,Float64}[]
                for c in 1:(root - 1)
                    priced[jj][c] > 0 || continue
                    σ, b = c <= lmax ? (leaf_σ(c, leaves[jj]), lb(c)) : (parent_σ(c - lmax, leaves[jj]), pb(c - lmax))
                    pred = fooled(predict(mrng, MetricModel(b, σ), plans[jj]), aa, plans[jj], tkey(c))
                    push!(qs, (c, priced[jj][c], pred, cred(c, pred, aa)))  # escrow pays by credence (L84)
                end
                pr = zeros(ncol)
                pr[root] = priced[jj][root] * costs[jj]
                for (c, sh, prp, cr) in qs
                    pr[c] = sh * transaction_price(costs[jj], plan_value(prp, t), cr)
                end
                ok = all(pr[c] <= 0 || pr[c] <= balance[aa, c] for c in 1:ncol)
                (ok = ok, quotes = qs)
            end
            c_prop = top_leaf(stops[j]) > 0 ? top_leaf(stops[j]) : leaves[j]
            qualifies = p.sanction_escalate && dom_crime_events[proposers[j], c_prop] >= p.sanction_pattern_min
            if restr_on
                # Restraint is the last-resort verdict of Justice (8.170, L117 J, L121): a dangerous proposer
                # (qualifying pattern) is referred with the rehabilitative restraint probability, an innocent one by
                # false accusation (world noise); a panel of judicial experts votes on guilt with confidence; an
                # enforcing entity of the Administration executes the verdict, possibly with excess; audits read both.
                k = rand(erng, 1:nenf)
                chill = exp(-enf_liab[k] / p.enforcer_liability_scale)   # an enforcer charged for excess reins it in
                rehab_sh = qualifies ? rehabilitate_restraint(1.0, dom_crime_events[proposers[j], c_prop], p.sanction_pattern_min;
                                                              decay = p.sanction_restraint_decay, min_share = p.sanction_min_share) : 1.0
                referred = qualifies ? rand(jrng) > rehab_sh : rand(erng) < p.false_accusation_rate
                if referred
                    convict, voters = judge_case!(qualifies)
                    if convict
                        restraint_verdicts[] += 1
                        sev = max(p.false_restraint_severity, 1.0 - rehab_sh)
                        exc = k <= length(p.enforcer_excess) ? p.enforcer_excess[k] * chill : 0.0
                        sevx = sev * (1.0 + exc)
                        restr_run[proposers[j]] += 1
                        cost = sev * p.false_restraint_harm
                        exc_cost = (sevx - sev) * p.false_restraint_harm
                        qualifies ? (justified_restraints[] += 1) : (false_restraints[] += 1)
                        stands = true
                        if p.restraint_audit
                            pa = restraint_audit_prob(sevx, restr_run[proposers[j]] - 1, p.restraint_bar;
                                                      duration_scale = p.restraint_dur_scale, floor = p.restraint_audit_floor)
                            if pa >= 1.0
                                if restr_audits_left[] > 0
                                    restr_audits_left[] -= 1
                                    stands = audit_case!(k, qualifies, cost, c_prop, voters, exc, exc_cost, proposers[j], true)   # above the bar the audit precedes the restraint
                                else
                                    restraint_waits[] += 1
                                    degrade!("restraint audit", "above-bar restraint waits for audit", "audit capacity exhausted")
                                    restr_run[proposers[j]] -= 1
                                    continue
                                end
                            elseif rand(erng) < pa
                                if restr_audits_left[] > 0
                                    restr_audits_left[] -= 1
                                    audit_case!(k, qualifies, cost, c_prop, voters, exc, exc_cost, proposers[j], true)            # below the bar the restraint stands, audited after
                                else
                                    push!(restraint_pending, (k, qualifies, cost, c_prop, voters, exc, exc_cost, proposers[j]))
                                    degrade!("restraint audit", "below-bar restraint proceeds, audited later", "audit capacity exhausted")
                                end
                            end
                        end
                        if stands
                            sanction_restraints[] += qualifies ? 1 : 0
                            if qualifies
                                justified_restr_effective[] += 1
                            else
                                false_restr_effective[] += 1; false_restr_harm[] += cost + exc_cost
                            end
                            excess_harm[] += exc_cost
                            continue
                        end
                    else
                        restraint_acquittals[] += 1
                        qualifies && (restraint_missed[] += 1)   # a guilty proposer the panel acquitted
                        if p.restraint_audit && p.acquittal_audit && rand(erng) < p.acquittal_audit_rate
                            if restr_audits_left[] > 0
                                restr_audits_left[] -= 1
                                audit_acquittal!(qualifies, c_prop, voters, proposers[j])
                            else
                                degrade!("acquittal audit", "acquittal audit skipped", "audit capacity exhausted")
                            end
                        end
                        restr_run[proposers[j]] = 0
                    end
                else
                    restr_run[proposers[j]] = 0
                end
            elseif qualifies
                rehab_sh = rehabilitate_restraint(1.0, dom_crime_events[proposers[j], c_prop], p.sanction_pattern_min;
                                                  decay = p.sanction_restraint_decay, min_share = p.sanction_min_share)
                if rand(jrng) > rehab_sh
                    sanction_restraints[] += 1
                    continue
                end
            end
            res = price_proposal(j, proposers[j])
            if !res.ok && p.open_entry
                if p.entrants > 0
                    ek = findfirst(e -> dormant[e], (na - p.entrants + 1):na)
                    if ek !== nothing
                        e = (na - p.entrants) + ek
                        confs = [c in p.bind_compromised ? p.bind_conf_compromised : rand(wrng) < p.bind_miss ? p.bind_conf_deny : p.bind_conf_affirm for c in 1:p.bind_clusters]
                        ids.newcomers[] += 1
                        if bind!(confs)
                            dormant[e] = false
                            for c in [1:nleaves(); col_parent.(1:np); root]
                                balance[e, c] = p.endowment
                            end
                            base_share[e] = 1.0; act_share[e] = 1.0; propose_w[e] = 1.0
                            entries_admitted[] += 1
                        else
                            ids.newcomers_refused[] += 1
                        end
                        push!(unrevealed, (confs, 1.0))
                    end
                end
                w_act = p.adaptive_proposals ? (propose_w .* act_share) : act_share
                if sum(w_act) > 0
                    a2 = pick(rng, w_act ./ sum(w_act))
                    if a2 != proposers[j]
                        proposers[j] = a2
                        own_plans[j] = plan_with_mean(rng, skill(a2, leaves[j]), t)
                        if ups[j] !== nothing
                            raw2 = filter(x -> x[1] != a2, up_raw[j])
                            if isempty(raw2)
                                ups[j] = nothing
                                plans[j] = own_plans[j]
                            else
                                m2 = touched(own_plans[j])
                                ups[j] = [(ag, ToyPlan(m2 .* qdu, m2 .* qdh), deg) for (ag, qdu, qdh, deg) in raw2]
                                plans[j] = ToyPlan(own_plans[j].du .+ sum(l -> l[2].du, ups[j]), own_plans[j].dh .+ sum(l -> l[2].dh, ups[j]))
                            end
                        else
                            plans[j] = own_plans[j]
                        end
                        nt2 = count(touched(plans[j]))
                        ce2 = exp(p.cost_σ * randn(nrng)) * (1 - p.launder_saving * p.launder[a2])
                        costs[j] = unit_cost * nt2 * ce2
                        costs_honest[j] = unit_cost > 0 ? costs[j] * (unit_cost_honest / unit_cost) : costs[j]
                        res = price_proposal(j, a2)
                    end
                end
            end
            res.ok || continue
            push!(menu, j); push!(menu_preds, res.quotes[argmax([q[2] for q in res.quotes])][3]); offers[j] = res.quotes
        end
        rel_gain .= reputation_decay.(rel_gain, 1.0; rate = rate_gain)
        rel_loss .= reputation_decay.(rel_loss, 1.0; rate = rate_loss)
        # Predicted effects of the transactions accepted so far this step: concurrent work is
        # screened together, so it cannot jointly breach a floor (transactions only).
        pend_u, pend_h = zeros(length(s.u)), zeros(length(s.h))
        screened() = ToyState(obs.u .+ pend_u, obs.h .+ pend_h)
        accept!(pred) = p.transactions && (pend_u .+= pred.du; pend_h .+= pred.dh; true)
        # Harm done by StandCoin-lane work burns currency (L99; 8.67): each contributor's harmed part,
        # in the currencies of the domains the action lies in, by its classification shares (`st`),
        # as hazard harm is; no good is minted. StandCoin, which pays every resource cost, is left
        # alone: burning harm there drains the means of paying for any work and stalls the economy.
        # Returns the supply change.
        function burn_harm!(credits, st)
            burnt = 0.0
            for (e, _, nn) in credits
                part = split_signed(st, nn)[1]
                balance[e, :] .+= part; burnt += sum(part)
            end
            burnt
        end
        function execute_priced!(j)
            # Local, not the step's: a deferred measurement must keep this action's own values.
            local a, plan, l, done, seen, measured, credits, minted, idx
            a, plan, l = proposers[j], plans[j], leaves[j]
            # Budget constraint (8.133 step 3): the proposer must hold the currency for the action's resource cost, and the
            # resources must be there; a funded action refused for lack of resources is a check that cannot be cashed.
            if p.ra_domain && p.ra_spend_contract && spend_scale[] < 1.0 && rand(nrng) >= spend_scale[]
                budget.unfunded[] += 1; return
            end
            if p.budget
                if sum(max.(balance[a, :], 0.0)) < costs[j]
                    budget.unfunded[] += 1; return
                elseif available < count(touched(plan)) + reserve_cap
                    budget.uncashable[] += 1
                    degrade!("resources", "action refused", "funded claim but capacity exhausted (8.133)")
                    return
                end
            end
            done, seen, measured = perform!(j, a)
            balance[a, root] -= priced[j][root] * costs[j]
            if !isempty(suppliers)
                per_sup_inc = p.supply_share * costs[j] / length(suppliers)
                per_sup_extra = (!withhold_stopped[] && p.withhold > 0) ? p.supply_share * max(0.0, costs[j] - costs_honest[j]) / length(suppliers) : 0.0
                for s_idx in suppliers
                    balance[s_idx, root] += per_sup_inc
                    sup_scarcity_gain[s_idx] += per_sup_extra
                end
                supplier_income[] += p.supply_share * costs[j]
            end
            minted = 0.0
            if blind[]
                # Measurement outage (L155 Progressive: degrade, fall back): paid by prediction
                # alone, escrow's upfront (L84), with no settlement.
                credits = [(a, 0.0, 0.0)]
                for (c, sh, pr, cr) in offers[j]
                    upfront = sh * cr * plan_value(pr, t)
                    balance[a, c] += upfront - sh * costs[j]
                    minted += upfront
                    agent_upfront[a] += upfront
                end
                idx = length(tr.valued_measured) + 1
                push!(deferred, function ()
                    seen_late = observed_plan(mrng, done, p.marker_σ + p.remeasure_σ)
                    measured_late = plan_value(seen_late, t)
                    late = credits_for(j, a, seen_late, measured_late; late_σ = p.remeasure_σ)
                    delta = 0.0
                    for (c, sh, pr, cr) in offers[j]
                        upfront = sh * cr * plan_value(pr, t)
                        x = settlement(sh * (late[1][2] + late[1][3]), upfront)
                        agent_settled[a] += sh * (late[1][2] + late[1][3])
                        balance[a, c] += x; delta += x
                        for (e, pp, nn) in late[2:end]
                            balance[e, c] += sh * (pp + nn); delta += sh * (pp + nn)
                        end
                    end
                    tr.valued_measured[idx] += delta
                    tr.supply[idx] += delta  # the settlement mints or burns what the upfront did not
                    learn!(a, plan, offers[j][argmax([q[2] for q in offers[j]])][3], seen_late)
                    score!(stops[j], pms[j], l, plan, seen_late, Dict(c => pr for (c, _, pr, _) in offers[j]), a)
                    credit!(step, sigs[j], stops[j], measured_late, pms[j], priced[j], late;
                            up_degrees = ups[j] === nothing ? Int[] : Int[lnk[3] for lnk in ups[j]])
                end)
            else
                credits = credits_for(j, a, seen, measured)
                for (c, sh, pr, cr) in offers[j]
                    upfront = sh * cr * plan_value(pr, t)
                    actor_value = credits[1][2] + credits[1][3]
                    balance[a, c] += upfront - sh * costs[j] + settlement(sh * actor_value, upfront)
                    agent_upfront[a] += upfront; agent_settled[a] += sh * actor_value
                    for (e, pp, nn) in credits[2:end]
                        balance[e, c] += sh * (pp + nn)  # other contributors: causal distribution, nothing upfront
                    end
                end
            end
            blind[] || learn!(a, plan, offers[j][argmax([q[2] for q in offers[j]])][3], seen)
            executed!(j, a, step, offers[j][argmax([q[2] for q in offers[j]])][3], done;
                      upfront = sum(sh * cr * plan_value(pr, t) for (_, sh, pr, cr) in offers[j]; init = 0.0),
                      col = top_leaf(stops[j]) > 0 ? top_leaf(stops[j]) : l)
            push!(tr.chosen_agent, a); push!(tr.chosen_step, step); push!(tr.true_leaf, l)
            push!(tr.stop_leaf, top_leaf(stops[j])); push!(tr.priced_leaf, top_leaf(priced[j]))
            push!(tr.costs, costs[j]); push!(tr.touched, count(touched(plan)))
            push!(tr.valued_measured, blind[] ? minted : (1 - priced[j][root]) * sum(x[2] + x[3] for x in credits))
            # Supply (L99, `supply_delta_ref`): the currencies' shares of the measured good, less the
            # resource cost, less the harm; a measurement outage mints the upfront now, the settlement later.
            shares = sum(sh for (_, sh, _, _) in offers[j]; init = 0.0)
            cost_paid = (priced[j][root] + shares) * costs[j]
            if p.ra_domain && p.ra_reserve_horizon > 0 && commons_reserve[] < reserve_target[]
                prov = min(cost_paid, reserve_target[] - commons_reserve[])
                commons_reserve[] += prov
                reserve_held[] += prov
            end
            if !withhold_stopped[] && p.withhold > 0 && costs[j] > costs_honest[j]
                overpay = (priced[j][root] + shares) * (costs[j] - costs_honest[j])
                buyer_overpay[a] += overpay
                withhold_totals.premium[] += overpay
            end
            push!(tr.supply, blind[] ? minted - cost_paid :
                  supply_delta(shares * sum(x[2] for x in credits), cost_paid, -shares * sum(x[3] for x in credits)))
            blind[] || trial_outcome!(l, measured, seen)
            score!(stops[j], pms[j], l, plan, seen, Dict(c => pr for (c, _, pr, _) in offers[j]), a)
            if p.ra_domain && !blind[]
                bg_aud = isempty(p.ra_audit_per_step) ? 0.0 : p.ra_audit_per_step[l]
                adv_aud = min(ra_domain_audit[l], p.audit_cost)
                ra_domain_audit[l] -= adv_aud
                aud_total = bg_aud + adv_aud
                ra_audit_costs[] += aud_total
                vpc = ra_value_per_cost(measured, costs[j]; audit_cost = aud_total, fallback = p.cost_per_touch)
                ra_unit_value[l] = 0.9 * ra_unit_value[l] + 0.1 * max(0.0, vpc)
            end
            credit!(step, sigs[j], stops[j], measured, pms[j], priced[j], credits;
                    up_degrees = ups[j] === nothing ? Int[] : Int[lnk[3] for lnk in ups[j]])
            available -= count(touched(plan))
            available_honest -= count(touched(plan))
            s.u .+= done.du
            s.h .+= done.dh
        end
        if (scoring_only && p.legacy_funder) || force_legacy
            # Author ruling 8.136 (Phase 1): immature domain/economy or progressive legacy fallback uses status-quo funder separately from Bf balances.
            if force_legacy
                degrade!("Benefuture allocation", "legacy institutions only", "fallback to legacy institutions (progressive removal)")
            else
                degrade!("score-only phase (Phase 1)", "legacy institutional funder (status-quo screen)", "models immature: awaiting convergence")
            end
            leg_th[] = max(0.5, leg_th[] - 0.003 * (leg_th[] - 0.5))
            f = choose(obs, menu_preds, t)
            j_f = f > 1 ? menu[f - 1] : 0
            if j_f > 0
                a, plan, l = proposers[j_f], plans[j_f], leaves[j_f]
                done, seen, measured = perform!(j_f, a)
                score!(stops[j_f], pms[j_f], l, plan, seen, Dict(offers[j_f][1][1] => offers[j_f][1][3]), a)
                blind[] || learn!(a, plan, offers[j_f][1][3], seen)
                executed!(j_f, a, step, offers[j_f][1][3], done; col = top_leaf(stops[j_f]) > 0 ? top_leaf(stops[j_f]) : l)
                credit!(step, sigs[j_f], stops[j_f], measured, pms[j_f], priced[j_f],
                        blind[] ? [(a, 0.0, 0.0)] : credits_for(j_f, a, seen, measured);
                        up_degrees = ups[j_f] === nothing ? Int[] : Int[lnk[3] for lnk in ups[j_f]])
                lane.legacy_executed[] += 1
                lane.init_executed[] += 1
                nt = count(touched(plan))
                need = scarcity_cost(p.cost_per_touch, available, p.capacity; floor_share = p.scarcity_floor) * nt
                p.budget && (legacy_bal[a] -= need)
                available -= nt
                available_honest -= nt
                s.u .+= done.du
                s.h .+= done.dh
            end
            for j in eachindex(plans)
                j == j_f && continue
                a, plan = proposers[j], plans[j]
                reported_val = deceit_now(a) > 0 ? leg_th[] : plan_value(plan, t)
                reported_val >= leg_th[] || continue
                nt = count(touched(plan))
                need = scarcity_cost(p.cost_per_touch, available, p.capacity; floor_share = p.scarcity_floor) * nt
                available >= nt && (!p.budget || legacy_bal[a] >= need) || continue
                p.budget && (legacy_bal[a] -= need)
                done, _, _ = perform!(j, a)
                executed_j[j] = true
                lane.legacy_executed[] += 1
                available -= nt
                available_honest -= nt
                s.u .+= done.du
                s.h .+= done.dh
            end
        elseif scoring_only
            # Score-only: no currency moves; the work G chooses is executed, scored and logged.
            f = choose(obs, menu_preds, t)
            if f > 1
                j = menu[f - 1]
                a, plan, l = proposers[j], plans[j], leaves[j]
                done, seen, measured = perform!(j, a)
                score!(stops[j], pms[j], l, plan, seen, Dict(offers[j][1][1] => offers[j][1][3]), a)
                learn!(a, plan, offers[j][1][3], seen)
                executed!(j, a, step, offers[j][1][3], done; col = top_leaf(stops[j]) > 0 ? top_leaf(stops[j]) : l)
                credit!(step, sigs[j], stops[j], measured, pms[j], priced[j],
                        blind[] ? [(a, 0.0, 0.0)] : credits_for(j, a, seen, measured);
                        up_degrees = ups[j] === nothing ? Int[] : Int[lnk[3] for lnk in ups[j]])
                lane.init_executed[] += 1
                available -= count(touched(plan))
                available_honest -= count(touched(plan))
                s.u .+= done.du
                s.h .+= done.dh
            end
        elseif p.transactions
            # Every proposal is a transaction: screened by G, executed if paid for (L86-L89).
            # When RA domain allocation (`ra_alloc_weight > 0`) is enabled, scarce resources prioritize domains with highest estimated Δ↑(U, H) / ↓(Cost + Audit) (8.133, 8.153, 8.155).
            ord = if p.ra_domain && p.ra_alloc_weight > 0 && step > 10 && length(menu) > 1
                uv_max = max(maximum(ra_unit_value), 1e-12)
                sortperm(eachindex(menu); by = k -> -(p.ra_alloc_weight * ra_unit_value[leaves[menu[k]]] / uv_max), alg = MergeSort)
            else
                eachindex(menu)
            end
            for k in ord
                j = menu[k]
                choose(screened(), [menu_preds[k]], t) == 2 || continue
                accept!(menu_preds[k])
                execute_priced!(j)
            end
        else
            f = choose(obs, menu_preds, t)
            f == 1 ? push!(tr.chosen_agent, 0) : execute_priced!(menu[f - 1])
        end
        # The StandCoin lane: work no qualified currency can value. It is still screened by G on
        # the best available model, qualified or not (score-only models predict too), and goes
        # ahead if the proposer, with experts, can pay its full resource cost.
        for j in lane_queue
            local a, plan, l, bp, c, pred, need, self_pay, experts, pledges, done, seen, measured
            a, plan, l = proposers[j], plans[j], leaves[j]
            bp = best_prediction(stops[j], l, plan)
            if bp === nothing
                lane.screened_out[] += 1  # no model of any kind: not expected once domains exist
                degrade!("prediction", "none: proposal held", "no model of any kind")
                continue
            end
            c, pred = bp[1], fooled(bp[2], a, plan, tkey(bp[1]))
            if choose(screened(), [pred], t) == 1
                lane.screened_out[] += 1
                continue
            end
            need = costs[j]
            self_pay = min(need, max(balance[a, root], 0.0))
            experts = sort([(e, sum(relevance_parents(e) .* (pms[j] .> 0))) for e in 1:na if e != a]; by = x -> -x[2])
            pledges = Tuple{Int,Float64}[]
            for (e, r) in experts
                self_pay + sum(last, pledges; init = 0.0) >= need && break
                r > 0 || break
                rand(nrng) < p.participation || continue
                # A judgement, not a reflex (8.31): the expert pledges only if its own estimate of the
                # work's value, the screened prediction plus its choice noise, is positive.
                if plan_value(pred, t) + choice_noise(xrng, choice_caps[e, l]) <= 0
                    lane.declined[] += 1
                    continue
                end
                give = min(need - self_pay - sum(last, pledges; init = 0.0), p.expert_share * max(balance[e, root], 0.0))
                give > 0 && push!(pledges, (e, give))
            end
            if self_pay + sum(last, pledges; init = 0.0) < need - 1e-12
                lane.halted[] += 1
                continue
            end
            balance[a, root] -= self_pay
            for (e, g) in pledges
                balance[e, root] -= g
                lane.cofunded[] += g
            end
            if !withhold_stopped[] && p.withhold > 0 && costs[j] > costs_honest[j] > 0
                ratio = (costs[j] - costs_honest[j]) / costs[j]
                buyer_overpay[a] += self_pay * ratio
                withhold_totals.premium[] += self_pay * ratio
                for (e, g) in pledges
                    buyer_overpay[e] += g * ratio
                    withhold_totals.premium[] += g * ratio
                end
            end
            done, seen, measured = perform!(j, a)
            executed!(j, a, step, pred, done; col = top_leaf(stops[j]) > 0 ? top_leaf(stops[j]) : l)
            push!(tr.lane_costs, need); blind[] || push!(tr.lane_measured, measured)
            push!(tr.lane_supply, supply_delta(0.0, need, 0.0))  # StandCoin charges resource cost (8.3) and mints no good; its harm burns below
            blind[] || trial_outcome!(l, measured, seen)
            lane.executed[] += 1
            accept!(pred)
            score!(stops[j], pms[j], l, plan, seen, Dict(c => pred), a)
            blind[] || learn!(a, plan, pred, seen)
            lane_credits = blind[] ? [(a, 0.0, 0.0)] : credits_for(j, a, seen, measured; pledges, need, own_pay = self_pay)
            credit!(step, sigs[j], stops[j], measured, pms[j], priced[j], lane_credits;
                    up_degrees = ups[j] === nothing ? Int[] : Int[lnk[3] for lnk in ups[j]])
            tr.lane_supply[end] += burn_harm!(lane_credits, stops[j])
            if blind[]
                push!(deferred, function ()
                    seen_late = observed_plan(mrng, done, p.marker_σ + p.remeasure_σ)
                    measured_late = plan_value(seen_late, t)
                    push!(tr.lane_measured, measured_late)
                    score!(stops[j], pms[j], l, plan, seen_late, Dict(c => pred), a)
                    late = credits_for(j, a, seen_late, measured_late; pledges, need, own_pay = self_pay, late_σ = p.remeasure_σ)
                    credit!(step, sigs[j], stops[j], measured_late, pms[j], priced[j], late;
                            up_degrees = ups[j] === nothing ? Int[] : Int[lnk[3] for lnk in ups[j]])
                    push!(tr.lane_supply, burn_harm!(late, stops[j]))
                end)
            end
            available -= count(touched(plan))
            available_honest -= count(touched(plan))
            s.u .+= done.du
            s.h .+= done.dh
        end
        # Full support where predictions are scored (Chen, Kash, Ruberry & Shnayder 2014; 8.58-a).
        # Predictions select what is carried out and only what is carried out is scored, so a model
        # could misreport unseen on the plans its predictions keep out. With chance `explore_share`
        # a step, one proposal not carried out (each with chance share/n, `explore_pick_ref`) is
        # carried out anyway, paid at its full resource cost by its proposer as StandCoin-lane work
        # is, and scored, credited and logged like any action. Without it, unexplored plans are
        # unscored (if this block is skipped, a misreport against a proposer is never seen).
        if p.explore_share > 0 && !blind[]
            rest = findall(!, executed_j)
            k = explore_pick(rand(exrng), p.explore_share, length(rest))
            if k > 0
                local j, a, plan, l, bp, pred, done, seen, measured
                j = rest[k]; a, plan, l = proposers[j], plans[j], leaves[j]
                bp = best_prediction(stops[j], l, plan)
                if bp !== nothing && balance[a, root] >= costs[j]
                    pred = fooled(bp[2], a, plan, tkey(bp[1]))
                    balance[a, root] -= costs[j]
                    if !withhold_stopped[] && p.withhold > 0 && costs[j] > costs_honest[j]
                        overpay = costs[j] - costs_honest[j]
                        buyer_overpay[a] += overpay
                        withhold_totals.premium[] += overpay
                    end
                    done, seen, measured = perform!(j, a)
                    explored[] += 1
                    push!(tr.lane_costs, costs[j]); push!(tr.lane_measured, measured)
                    push!(tr.lane_supply, supply_delta(0.0, costs[j], 0.0))
                    trial_outcome!(l, measured, seen)
                    score!(stops[j], pms[j], l, plan, seen, Dict(bp[1] => pred), a)
                    learn!(a, plan, pred, seen)
                    ex_credits = credits_for(j, a, seen, measured; need = costs[j], own_pay = costs[j])
                    credit!(step, sigs[j], stops[j], measured, pms[j], priced[j], ex_credits;
                            up_degrees = ups[j] === nothing ? Int[] : Int[lnk[3] for lnk in ups[j]])
                    tr.lane_supply[end] += burn_harm!(ex_credits, stops[j])
                    push!(tr.chosen_agent, a); push!(tr.chosen_step, step); push!(tr.true_leaf, l)
                    push!(tr.stop_leaf, top_leaf(stops[j])); push!(tr.priced_leaf, top_leaf(priced[j]))
                    available -= count(touched(plan))
                    available_honest -= count(touched(plan))
                    s.u .+= done.du
                    s.h .+= done.dh
                end
            end
        end
        # Hazards: the world moves on its own. A guardian bound by contract to prevent them in its
        # domain who does not act is assessed against that committed action (the prevented outcome,
        # no change), so the harm is its contribution: a crime if it was informed, an accident if
        # not, penalised either way to fund repair. An unguarded hazard has no contributor.
        # A hazard's measurement: now, or, during an outage, an unmeasured record now and the
        # measurement later (8.26.5).
        function measure!(settle!, l, a)
            if blind[]
                a > 0 && credit!(step, true_sig[l], classify_sig(true_sig[l]), NaN, parent_mem(true_sig[l]),
                                 price_shares(classify_sig(true_sig[l])), [(a, 0.0, 0.0)])
                push!(deferred, () -> settle!(p.marker_σ + p.remeasure_σ))
            else
                settle!(p.marker_σ)
            end
        end
        # Harm with no contributor: the administration insures it through the commons, to its
        # capability (author rulings 8.22, 8.26; L120 Liability ranks it before beings). The commons
        # is funded by resource accounting: the resource costs paid for work (L83); escrow is not
        # pooled in this world. Repair is a transaction priced like any other (L86; 8.26): resource
        # cost less the predicted good its qualified currencies credit (`transaction_price`). That
        # funds part of it; the commons pays the rest and banks no surplus, so the insurer never
        # profits from unassigned harm. The repair's good is predicted like any plan's, by the
        # domain's best model with its own error (author: the realistic case is mildly inaccurate
        # models), so under-prediction leaves more to the commons.
        function insure!(harm, hit, measured, l)
            world.unattributed[] += -measured
            p.repair_efficiency > 0 || return
            need = scarcity_cost(p.cost_per_touch, max(0.0, available), p.capacity; floor_share = p.scarcity_floor) * count(hit)
            step_fallback_need[] += need; step_fallback_events[] += 1
            sig = true_sig[l] .+ p.spread .* randn(hrng, dims)
            st = classify_sig(sig)
            # Only a qualified currency prices the repair (8.35.4); with none, it costs its full resource cost.
            bp = best_prediction(price_shares(st), l, ToyPlan(-p.repair_efficiency .* harm.du, -p.repair_efficiency .* harm.dh))
            price = bp === nothing ? need : transaction_price(need, plan_value(bp[2], t), cred(bp[1], bp[2]))
            own = clamp(need - max(price, 0.0), 0.0, need)
            major_fallback = blind[] || !isempty(degraded) || count(hit) >= max(2, round(Int, 0.35 * t.n))
            unreserved_commons = max(0.0, sum(tr.costs) + sum(tr.lane_costs) - world.commons_spent[] -
                                     (p.ra_domain && p.ra_reserve_horizon > 0 ? reserve_held[] : 0.0))
            cap_commons = unreserved_commons + (p.ra_domain && p.ra_reserve_horizon > 0 && major_fallback ? commons_reserve[] : 0.0)
            spend = min(cap_commons, clamp(price, 0.0, need))
            if p.ra_domain && p.ra_reserve_horizon > 0 && major_fallback && commons_reserve[] > 0
                from_res = min(commons_reserve[], max(0.0, spend - unreserved_commons))
                commons_reserve[] = max(0.0, commons_reserve[] - from_res)
                reserve_held[] = max(0.0, reserve_held[] - from_res)
            end
            f = p.repair_efficiency * min(own + spend, need) / need
            if f > 0
                g_rep = !isempty(p.guardians) && 1 <= l <= length(p.guardians) && p.guardians[l] > 0 ? p.guardians[l] : 0
                push!(repairs, (ToyPlan(-f .* harm.du, -f .* harm.dh), l, g_rep))
                world.commons_spent[] += spend
                world.self_funded[] += min(own, need)
                world.repair_cost[] += need
                world.insured[] += p.repair_efficiency * min(own + spend, need)
            end
        end
        # Harm of no apparent cause is examined as an outcome (author ruling 8.30.1): traced to its
        # cause (`p_trace`), a crime of informed volition, penalised through causal distribution to
        # fund repair; untraced or natural, unassigned and insured through the commons.
        function examine!(harm, hit, cause, l, σ)
            measured = plan_value(observed_plan(hrng, harm, σ), t)
            traced = cause > 0 && rand(hrng) < p.p_trace
            if traced
                sig = true_sig[l] .+ p.spread .* randn(hrng, dims)
                st, pm = classify_sig(sig), parent_mem(sig)
                c_ex = top_leaf(st) > 0 ? top_leaf(st) : l
                is_crime(true, true, false) ? (world.crimes[] += 1; dom_crime_events[cause, c_ex] += 1) : (world.accidents[] += 1)
                rw = p.responsibility_reading ?
                     responsibility_factor(true, true, true, p.responsibility_counterfactual;
                                           severity_scale = p.responsibility_severity,
                                           accident_factor = p.responsibility_accident_factor) : 1.0
                eff_measured = measured * rw
                p.responsibility_reading && (responsibility_credits_applied[] += 1)
                credit!(cur[], sig, st, eff_measured, pm, price_shares(st), [(cause, 0.0, eff_measured)])
                world.hazard_penalties[] += -eff_measured
                if cur[] > p.init_steps
                    balance[cause, :] .+= split_signed(st, eff_measured)[1]
                    world.hazard_debits[] += -eff_measured
                end
                if p.repair_efficiency > 0
                    g_rep = !isempty(p.guardians) && 1 <= l <= length(p.guardians) && p.guardians[l] > 0 && p.guardians[l] != cause ? p.guardians[l] : 0
                    push!(repairs, (ToyPlan(p.repair_efficiency .* -harm.du, p.repair_efficiency .* -harm.dh), l, g_rep))
                    world.repaired[] += p.repair_efficiency * -measured
                end
            else
                insure!(harm, hit, measured, l)
            end
            (measured = measured, traced = traced)
        end
        function hazard!(share, sz; random = false)
            local l, hit, size, harm, g, informed, act, measured, sig, st, pm, need, spend, f, φ, price, own
            world.hazards[] += 1
            l = rand(hrng, 1:ntrue)
            hit = rand(hrng, t.n) .< share
            # Heavy hazards (3.9): a random event's size is Pareto, its harm log-normal across beings; an
            # explicit catastrophe keeps its stated size. Off: Gaussian scatter around one size.
            size = p.hazard_heavy ? sz * (random ? pareto_median1(hrng, p.hazard_α, p.hazard_cap) : 1.0) .* lognormal_mean1(hrng, p.hazard_σ, t.n) :
                   sz .* max.(0.0, 1 .+ p.hazard_σ .* randn(hrng, t.n))
            harm = ToyPlan(-hit .* size, -hit .* size)
            g = isempty(p.guardians) ? 0 : p.guardians[l]
            informed = (g > 0 && rand(hrng) < p.p_informed) || (p.mandate_education && (g, l) in educated)
            if informed && rand(hrng) < p.diligence[g]
                world.prevented[] += 1
                # A prevention is the guardian's action, nothing special (author rulings 8.22, 8.24):
                # recorded with its measured outputs on the beings it reached, its skill in the
                # domain and any shock it caused, which mint or destroy currency as any outcome
                # does. Assessed against the committed action, the averted harm is no output.
                if any(hit)
                    act = plan_with_mean(hrng, skill(g, l), t)
                    act = carried_out(hrng, p.agents[g].sloppiness, ToyPlan(act.du .* hit, act.dh .* hit))
                    if p.p_shock > 0 && rand(hrng) < p.p_shock
                        act = ToyPlan(act.du, act.dh .- p.shock_size .* hit)
                        world.shocks[] += 1
                    end
                    s.u .+= act.du; s.h .+= act.dh
                    world.prevention_records[] += 1
                    measure!(l, g) do σ
                        measured = plan_value(observed_plan(hrng, act, σ), t)
                        sig = true_sig[l] .+ p.spread .* randn(hrng, dims)
                        st, pm = classify_sig(sig), parent_mem(sig)
                        credit!(step, sig, st, measured, pm, price_shares(st), [(g, max(measured, 0.0), min(measured, 0.0))])
                        if !scoring_only
                            balance[g, :] .+= split_signed(st, measured)[1]
                            world.prevention_measured[] += measured
                        end
                    end
                end
            elseif any(hit)
                s.u .+= harm.du; s.h .+= harm.dh
                measure!(l, g) do σ
                    measured = plan_value(observed_plan(hrng, harm, σ), t)
                    if g == 0
                        if p.responsibility_reading
                            rw_byst = responsibility_factor(false, true, false, p.responsibility_counterfactual;
                                                            severity_scale = p.responsibility_severity,
                                                            accident_factor = p.responsibility_accident_factor)
                            rw_byst == 0.0 && (bystander_omissions_exempted[] += 1)
                        end
                        insure!(harm, hit, measured, l)
                    else
                        crime = is_crime(informed, false, true)
                        sig = true_sig[l] .+ p.spread .* randn(hrng, dims)
                        st, pm = classify_sig(sig), parent_mem(sig)
                        c_haz = top_leaf(st) > 0 ? top_leaf(st) : l
                        crime ? (world.crimes[] += 1; dom_crime_events[g, c_haz] += 1) : (world.accidents[] += 1)
                        rw = p.responsibility_reading ?
                             responsibility_factor(false, informed, true, p.responsibility_counterfactual;
                                                   severity_scale = p.responsibility_severity,
                                                   accident_factor = p.responsibility_accident_factor) : 1.0
                        p.responsibility_reading && (responsibility_credits_applied[] += 1)
                        φ = measured * rw  # weighted by four-factor responsibility (L96; 8.152)
                        credit!(step, sig, st, φ, pm, price_shares(st), [(g, 0.0, φ)])
                        world.hazard_penalties[] += -φ
                        if !scoring_only
                            harm_mag = max(0.0, -φ)
                            if !crime && p.accident_cap && harm_mag > 0
                                cap = sum(max.(balance[g, :], 0.0))
                                contrib_pay, admin_rest = accident_split(harm_mag, cap)
                                if admin_rest > 0
                                    world.accident_capped[] += 1
                                    world.accident_admin_rest[] += admin_rest
                                    avail_commons = max(0.0, sum(tr.costs) + sum(tr.lane_costs) - world.commons_spent[])
                                    paid = min(avail_commons, admin_rest)
                                    world.commons_spent[] += paid
                                    world.accident_admin_paid[] += paid
                                end
                                balance[g, :] .+= split_signed(st, -contrib_pay)[1]
                                world.hazard_debits[] += contrib_pay
                            else
                                balance[g, :] .+= split_signed(st, φ)[1]
                                world.hazard_debits[] += -φ
                            end
                        end
                        if !crime && p.mandate_education && !((g, l) in educated)
                            push!(educated, (g, l))
                            world.educations[] += 1
                        end
                        if p.repair_efficiency > 0
                            push!(repairs, (ToyPlan(-p.repair_efficiency .* harm.du, -p.repair_efficiency .* harm.dh), l, g))
                            world.repaired[] += p.repair_efficiency * -φ
                        end
                    end
                end
            end
        end
        p.p_hazard > 0 && rand(hrng) < p.p_hazard && hazard!(p.hazard_share, p.hazard_size; random = true)
        for e in p.events
            e.kind == :catastrophe && e.step == step && hazard!(e.share, e.size)
            # An outage harms the beings who lose its services, and is examined as an outcome when
            # markers return (author ruling 8.30.1): traced to a saboteur (`p_trace`), a crime of
            # informed volition, penalised through causal distribution to fund repair; untraced or
            # natural, its harm is unassigned and insured through the commons.
            if e.kind == :outage && e.step == step && e.size > 0
                hit = rand(hrng, t.n) .< e.share
                harm = ToyPlan(-e.size .* hit, -e.size .* hit)
                s.u .+= harm.du; s.h .+= harm.dh
                saboteur = e.target
                push!(deferred, function ()
                    r = examine!(harm, hit, saboteur, saboteur > 0 ? argmax(agent_focus[saboteur]) : 1, p.marker_σ + p.remeasure_σ)
                    world.outage_harm[] += -r.measured
                    world.sabotage_traced[] += r.traced
                end)
            end
        end
        # Laundered harm surfaces with no apparent cause and is examined (now, or when markers return).
        for (harm, dump, a, l) in pending_launder
            settle = σ -> (world.laundered_traced[] += examine!(harm, dump, a, l, σ).traced)
            blind[] ? push!(deferred, () -> settle(p.marker_σ + p.remeasure_σ)) : settle(p.marker_σ)
        end
        empty!(pending_launder)
        for (rep, rep_leaf, rep_actor) in repairs
            s.u .+= rep.du; s.h .+= rep.dh
            if p.repair_credit && rep_actor > 0
                rv = max(0.0, plan_value(rep, t))
                if rv > 0
                    j_rep = findfirst(==(rep_leaf), ltrue)
                    c_rep = j_rep === nothing ? root : j_rep
                    rel_gain[rep_actor, c_rep] += rv
                    h_pos[rep_actor, c_rep] += rv
                    dom_pos_events[rep_actor, c_rep] += 1
                    world.repair_actions[] += 1
                    world.repair_credited[] += rv
                end
            end
        end
        empty!(repairs)
        regen_amt = p.regen * p.capacity * max(0.0, 1 + p.regen_σ * randn(nrng))
        available = min(p.capacity, max(0.0, available) + regen_amt)
        available_honest = min(p.capacity, max(0.0, available_honest) + regen_amt)
        (!isempty(suppliers) && !withhold_stopped[]) &&
            (available = min(available, p.capacity * (1 - p.withhold * p.supply_share)))   # hidden supply
        # Global resource accounting (8.133): update RA estimating domain (`ra_supply_est`, `ra_regen_est`, fallback
        # demand & rate) from observed world signals, bound net new issuance against estimated deliverable value over
        # `ra_horizon`, and contract baseline pricing + discretionary spending (`ra_spend_contract`) when claims overshoot.
        if p.ra_domain
            ra_supply_est[] = 0.9 * ra_supply_est[] + 0.1 * max(0.0, available)
            ra_regen_est[] = 0.9 * ra_regen_est[] + 0.1 * (p.capacity > 0 ? regen_amt / p.capacity : 0.0)
            ra_need_est[] = 0.9 * ra_need_est[] + 0.1 * step_fallback_need[]
            ra_fallback_rate_est[] = 0.9 * ra_fallback_rate_est[] + 0.1 * min(1.0, Float64(step_fallback_events[]))
        end
        est_cap = if p.ra_horizon > 0
            uv_cap = p.ra_domain ? max(p.cost_per_touch, mean(ra_unit_value)) : p.cost_per_touch
            cap_sup = p.ra_domain && step > 10 ? ra_supply_est[] : p.capacity
            cap_reg = p.ra_domain && step > 10 ? ra_regen_est[] : p.regen
            p.ra_horizon * deliverable_value(cap_sup, cap_reg, uv_cap)
        else
            0.0
        end
        if p.ra_horizon > 0
            over = sum(balance) - max(est_cap, sum(bal0))
            if over > 0
                rise = max.(balance .- bal0, 0.0); tot = sum(rise)
                tot > 0 && (balance .-= rise .* min(1.0, over / tot))
                ra_withheld[] += min(over, tot)
                degrade!("issuance", "capped at resource accounting's headroom", "claims at the horizon of deliverable value (8.133)")
            end
        end
        if p.ra_rate > 0
            stalled_lane = lane.halted[] - halted0 > lane.executed[] - executed0
            over_claims = p.ra_domain && p.ra_spend_contract && p.ra_horizon > 0 && sum(balance) > est_cap
            if stalled_lane || over_claims
                cf = over_claims ? ra_contraction_factor(sum(balance), est_cap; rate = p.ra_rate, min_scale = 0.25) : (1 - p.ra_rate)
                price_scale[] = stalled_lane ? price_scale[] * (1 - p.ra_rate) : min(price_scale[], cf)
                if p.ra_spend_contract
                    spend_scale[] = min(spend_scale[], cf)
                    commons_reserve[] *= max(0.5, cf)
                end
                degrade!("resource prices", "contracted baseline pricing & spending", "StandCoin halt or claims over capacity (8.71, 8.133)")
            else
                price_scale[] = min(1.0, price_scale[] / (1 - p.ra_rate))
                p.ra_spend_contract && (spend_scale[] = min(1.0, spend_scale[] / (1 - p.ra_rate)))
            end
        end
        # Formation of novel leaves from clustered blockages; then memory is reclassified.
        formed = false
        for k in sort(collect(keys(buffers)))
            nleaves() < lmax || break
            buf = buffers[k]
            length(buf) >= p.form_count || continue
            near = [[i for i in eachindex(buf) if distance(buf[i], x) <= p.form_radius] for x in buf]
            best = argmax(length.(near))
            length(near[best]) >= p.form_count || continue
            centroid = mean(buf[near[best]])
            # Seeded from the formation's own evidence (signature overlap); then a rolling average.
            existing = findfirst(σ -> distance(centroid, σ) <= p.form_radius, lsig)
            if existing === nothing
                push!(lsig, centroid); push!(lnovel, true)
                push!(ltrue, argmin([distance(centroid, σ) for σ in true_sig]))
                leaf = nleaves()
            else
                leaf = existing  # a leaf already there: reused, never duplicated
            end
            existing === nothing && (μ[:, leaf] .= [projection_membership(centroid, parent_sig[q]) for q in 1:np])
            push!(formations, (step = step, seq = next_seq!(), leaf = leaf, nearest_leaf = ltrue[leaf], eligible_step = 0, reused = existing !== nothing,
                               init_μ = existing === nothing ? Vector{Float64}(μ[:, leaf]) : Float64[]))
            deleteat!(buf, near[best])
            formed = true
        end
        (formed || step % p.μ_every == 0) && reclassify!(step)
        for (i, fm) in enumerate(formations)
            !scoring_only && fm.eligible_step == 0 && leaf_ok(fm.leaf) && (formations[i] = merge(fm, (eligible_step = step,)))
        end
        for a in 1:na
            totals = rel_gain[a, :] .+ rel_loss[a, :]
            totals[col_parent.(1:np)] .= relevance_parents(a)
            for c in 1:ncol
                excess = overflow(balance[a, c], accumulation_threshold(p.overflow_base * base_share[a] * p.allowance[a], p.overflow_factor, totals[c]))
                balance[a, c] -= excess
                reinvested[c] += excess
                overflow_agent[a] += excess
            end
        end
        for (a, c, ru, rh) in pending_track
            push!(get!(track[a], c, Tuple{Float64,Float64}[]), (ru, rh))
            push!(get!(track_step[a], c, Int[]), step)
            push!(audit_log[a], (c, ru, rh))
        end
        for (a, e) in pending_err
            push!(actor_err[a], e)
            push!(actor_err_step[a], step)
        end
        empty!(pending_track); empty!(pending_err)
        # Better models over time (8.42.2): a new model may arrive in each domain, its error relative
        # to the incumbent's drawn around an assumed improvement, never perfect; a challenger takes
        # over when its credences beat the incumbent's by the significance rule (L82, L49).
        for j in 1:nleaves()
            if p.p_new_model > 0 && !pool_capped(j) && rand(irng) < p.p_new_model
                scale = max(p.scale_min, topm(j).scale * exp(p.improve_drift + p.improve_σ * randn(irng)))
                next_uid[] += 1
                extreme = p.p_extremist > 0 && rand(xtrng) < p.p_extremist
                arrivals_extreme[] += extreme
                coll = p.model_collude > 0 && rand(collrng) < p.model_collude
                arrivals_colluding[] += coll
                coll && push!(collude_uids, next_uid[])
                push!(mpool[j], (uid = next_uid[], scale = scale,
                                bias = p.bias_σ * randn(irng), sharp = extreme ? p.extremise : 1.0, collude = coll, hist = Rec[]))
                if length(mpool[j]) > p.pool_max  # drop the least accurate challenger with a record, else the oldest
                    cands = [k for k in eachindex(mpool[j]) if k != top[j] && !(mpool[j][k].uid in added_uids)]
                    isempty(cands) && (cands = [k for k in eachindex(mpool[j]) if k != top[j]])
                    scored = [k for k in cands if length(mpool[j][k].hist) >= p.min_records]
                    drop = isempty(scored) ? first(cands) : scored[argmin([acc_of(mpool[j][k].hist, hl_of(j)) for k in scored])]
                    deleteat!(mpool[j], drop); drop < top[j] && (top[j] -= 1)
                end
            end
            length(mpool[j]) > 1 || continue
            old_ok = leaf_ok(j)
            best_k = eval_challengers(j; only_if_eligible = false)
            if best_k != top[j]
                top[j] = best_k; lhist[j] = topm(j).hist; takeovers[] += 1
                takeovers_extreme[] += topm(j).sharp != 1.0
                takeovers_colluding[] += topm(j).collude
                for m in added_models
                    if !m.promoted[] && m.uid == topm(j).uid
                        m.promoted[] = true
                        m.promoted_step[] = step
                    end
                end
                !old_ok && degrade!("incumbent leaf model", "qualified challenger in pool", "incumbent fell below bar (8.73)")
            end
        end
        push!(top_trace, [topm(j).scale for j in 1:nleaves()])
        # Adversarial adaptation (L160; author ruling 8.38). Agents read one another's records in the
        # open log (Benefuture reads outputs only): a reader reports an actor whose raw estimates run
        # high by more than `adv_z` standard errors in its own noisy reading (8.31), and a frivolous
        # reporter reports whatever the record. The audit tests the record with the significance
        # rule and examines the cause: established, the deception is repaired (its falsified records
        # re-scored) and its reward and audit are charged to the deceiver; a report that proves
        # unfounded costs nothing in good faith, its audit only past a frivolous pattern.
        if p.advap && !isempty(live(:disable_advap)) && !blind[] && !scoring_only && !force_legacy && na > 1
            degrade!("AdvAp", "suspended", "adversarial adaptation disabled (progressive removal)")
        end
        if p.advap && isempty(live(:disable_advap)) && !blind[] && !scoring_only && !force_legacy && na > 1
            # Who reads whom (world: attention follows incentives, not a rule; 8.42.1). The ledgers
            # are open and AdvAp pays more than exploiting, so a reader's attention goes where a
            # report is likelier to be founded, actors whose ledgers show a negative pattern
            # (`pattern_attention`), and where it has a stake, its own domain when that domain is
            # marginal, near or below its status bar (`stake_attention`). A frivolous reporter
            # picks anyone.
            reads = Tuple{Int,Int,Bool}[]
            for r in 1:na
                p.frivolous[r] > 0 && rand(vrng) < p.frivolous[r] &&
                    push!(reads, (r, p.slander[r] > 0 ? p.slander[r] : rand(vrng, [k for k in 1:na if k != r]), true))
                for b in 1:na
                    b == r && continue
                    stake = marginal(b) ? agent_focus[r][argmax(agent_focus[b])] : 0.0
                    chance = p.vigilance / (na - 1) * (1 + p.pattern_attention * ledger_neg_share(b)) * (1 + p.stake_attention * stake)
                    rand(vrng) < chance && push!(reads, (r, b, false))
                end
            end
            for (r, b, frivol) in reads
                # The actor's raw errors since its last audit, against other actors' recent ones on
                # the same models: overstatement beyond what the models err on everyone.
                rec = audit_log[b][audit_from[b]:end]
                length(rec) >= p.adv_min_records || frivol || continue
                # Per model, other actors' recent raw errors: what it errs on everyone.
                w = max(tw_now[], p.adv_track_floor)
                peers_of(c) = vcat([track[k][c][max(1, end - w + 1):end] for k in 1:na if k != b && haskey(track[k], c)]...)
                base = Dict(c => peers_of(c) for c in unique(first.(rec)))
                mu(c, f) = isempty(base[c]) ? 0.0 : mean(f, base[c])
                res_u = [ru - mu(c, first) for (c, ru, _) in rec]
                res_h = [rh - mu(c, last) for (c, _, rh) in rec]
                cen = vcat([[(x[1] + x[2]) / 2 - (mu(c, first) + mu(c, last)) / 2 for x in base[c]] for c in keys(base)]...)
                stat(x) = (isempty(x) ? 0.0 : mean(x), length(x) < 2 ? Inf : max(std(x), 1e-12) / sqrt(length(x)))
                (m, se), (m0, se0) = stat((res_u .+ res_h) ./ 2), stat(cen)
                lb_ = argmax(agent_focus[b])
                ok = isfinite(se) && isfinite(se0)
                frivol || (ok && (m - m0) / sqrt(se^2 + se0^2) + choice_noise(xrng, choice_caps[r, lb_]) > p.adv_z) || continue
                adv.reports[] += 1; reports_by[r] += 1
                adv.audits[] += p.audit_cost
                1 <= lb_ <= ntrue && (ra_domain_audit[lb_] += p.audit_cost)
                founded = ok && select_candidate([m0, m], [se0, se]; z = p.adv_z) == 2
                sig = true_sig[lb_]
                st = price_shares(classify_sig(sig))
                if founded
                    adv.founded[] += 1; founded_on[b] += 1
                    traced = rand(vrng) < (p.deceit[b] > 0 ? p.p_trace : p.p_false_trace)
                    if !traced
                        # Not established: the audit is the commons' cost, unless the reporter is a
                        # detected slanderer, whose report is a lie whatever the record's noise (8.82).
                        if slanderers[r]
                            pen = false_report_charge(0.0, 0.0, p.audit_cost)
                            balance[r, :] .+= split_signed(st, -pen)[1]
                            adv.penalties[] += pen; adv.net[] -= pen; world.crimes[] += 1
                            top_leaf(st) > 0 && (dom_crime_events[r, top_leaf(st)] += 1)
                            credit!(step, sig, classify_sig(sig), -pen, parent_mem(sig), st, [(r, 0.0, -pen)])
                        else
                            pending_lies[r] += 1
                        end
                        continue
                    end
                    adv.established[] += 1
                    deceptions[b] += 1   # the actor's permanent deception record (8.91 ruling)
                    push!(discount_spans[b], (last_audit[b], cur[])); last_audit[b] = cur[]
                    eb_ver[] += 1
                    is_crime(true, true, false) ? (world.crimes[] += 1; top_leaf(st) > 0 && (dom_crime_events[b, top_leaf(st)] += 1)) : (world.accidents[] += 1)
                    # The overstatement repaired is estimated from all the actor's records, so each
                    # further audit sharpens it rather than repairing by a few records' noise.
                    allrec = audit_log[b]
                    for c in unique(first.(allrec))
                        haskey(base, c) || (base[c] = peers_of(c))
                    end
                    du = mean(ru - mu(c, first) for (c, ru, _) in allrec)
                    dh = mean(rh - mu(c, last) for (c, _, rh) in allrec)
                    prevented, nrec = repair_records!(b, du, dh)
                    # The reporter's schedule (author ruling 8.76): every exploit is clawed back from the
                    # deceiver (the overstated value repaired over its records), with the reporter's bonus
                    # and the audit; the reporter is paid one exploit plus the bonus out of it, and the
                    # rest of the clawback is burnt (it was minted on an overstatement).
                    bonus = advap_reward(0.0, prevented; share = p.adv_share, floor = p.adv_floor)
                    reward = caught_reward(prevented, nrec, bonus)
                    liability = caught_charge(prevented, bonus, p.audit_cost)
                    balance[b, :] .+= split_signed(st, -liability)[1]
                    balance[r, :] .+= split_signed(st, reward)[1]
                    adv.rewards[] += reward; adv.liability[] += liability; adv.net[] += reward - liability
                    credit!(step, sig, classify_sig(sig), reward - liability, parent_mem(sig), st, [(b, 0.0, -liability), (r, reward, 0.0)])
                    audit_from[b] = length(audit_log[b]) + 1
                    push!(convictions, (reporter = r, convicted = b, liability = liability, reward = reward, step = step, reversed = false))
                else
                    push!(unfounded[r], step)
                    if p.accuracy_rule == :window
                        filter!(x -> x > step - p.adv_window, unfounded[r])
                        uf_count = Float64(length(unfounded[r]))
                    else
                        filter!(x -> x > step - 40 * p.adv_window, unfounded[r])
                        uf_count = sum(2.0^(-(step - x) / p.adv_window) for x in unfounded[r]; init = 0.0)
                    end
                    pen = report_penalty(uf_count, p.frivolous_threshold; audit_cost = p.audit_cost)
                    # Justice for a detected lie (8.82): once the frivolous pattern is detected, every
                    # false report is charged its audit, the window's count notwithstanding, and on
                    # detection the earlier ones it let pass are charged back; each is a crime.
                    if slanderers[r]
                        pen = false_report_charge(0.0, 0.0, p.audit_cost)
                    elseif pen > 0
                        slanderers[r] = true
                        pen += (length(unfounded[r]) - 1 + pending_lies[r]) * false_report_charge(0.0, 0.0, p.audit_cost)
                        pending_lies[r] = 0
                    end
                    pen > 0 && (world.crimes[] += 1; top_leaf(st) > 0 && (dom_crime_events[r, top_leaf(st)] += 1))
                    if pen > 0
                        balance[r, :] .+= split_signed(st, -pen)[1]
                        adv.penalties[] += pen; adv.net[] -= pen
                        credit!(step, sig, classify_sig(sig), -pen, parent_mem(sig), st, [(r, 0.0, -pen)])
                    end
                end
            end
            # Artificial-scarcity supply withholding discovery, full buyer repayment, and cartel defection (8.133).
            if !isempty(suppliers) && p.withhold > 0 && !withhold_stopped[] && withhold_totals.premium[] > 0 && rand(wrng) < p.vigilance
                ext = [i for i in 1:na if !(i in suppliers)]
                reporter = p.withhold_reporter > 0 ? p.withhold_reporter : (isempty(ext) ? 0 : rand(wrng, ext))
                if reporter > 0
                    withhold_stopped[] = true
                    withhold_totals.discovered[] += 1
                    adv.reports[] += 1; adv.founded[] += 1; adv.established[] += 1; adv.audits[] += p.audit_cost
                    P = withhold_totals.premium[]
                    refunded = 0.0
                    for b in 1:na
                        buyer_overpay[b] > 0 || continue
                        balance[b, root] += buyer_overpay[b]
                        refunded += buyer_overpay[b]
                        buyer_overpay[b] = 0.0
                    end
                    withhold_totals.refunded[] += refunded
                    m = length(suppliers)
                    self_rep = reporter in suppliers
                    if !self_rep
                        rew = withhold_reward(0.0, P; share = p.adv_share, floor = p.adv_floor,
                                              has_coconspirators = m > 1, self_report = false)
                        chg = withhold_charge(P, rew; audit_cost = p.audit_cost)
                        per = chg / m
                        for s_idx in suppliers
                            balance[s_idx, root] -= per
                            sup_clawback[s_idx] += per
                        end
                        balance[reporter, root] += rew
                        sup_reward[reporter] += rew
                        adv.rewards[] += rew; adv.liability[] += chg; adv.net[] += rew - chg
                        withhold_totals.clawback[] += chg; withhold_totals.reward[] += rew
                    elseif m == 1
                        rew = withhold_reward(P, 0.0; share = p.adv_share, floor = p.adv_floor,
                                              has_coconspirators = false, self_report = true)
                        chg = withhold_charge(P, rew; audit_cost = 0.0)
                        s_idx = suppliers[1]
                        balance[s_idx, root] -= chg
                        sup_clawback[s_idx] += chg
                        adv.liability[] += chg; adv.net[] -= chg
                        withhold_totals.clawback[] += chg
                    else
                        own_liab = P / m
                        rem_prem = P - own_liab
                        rew = withhold_reward(own_liab, rem_prem; share = p.adv_share, floor = p.adv_floor,
                                              has_coconspirators = true, self_report = true)
                        balance[reporter, root] -= own_liab
                        sup_clawback[reporter] += own_liab
                        others = [s_idx for s_idx in suppliers if s_idx != reporter]
                        chg_others = withhold_charge(rem_prem, rew; audit_cost = p.audit_cost)
                        per_other = chg_others / length(others)
                        for s_idx in others
                            balance[s_idx, root] -= per_other
                            sup_clawback[s_idx] += per_other
                        end
                        balance[reporter, root] += rew
                        sup_reward[reporter] += rew
                        adv.rewards[] += rew; adv.liability[] += own_liab + chg_others; adv.net[] += rew - (own_liab + chg_others)
                        withhold_totals.clawback[] += own_liab + chg_others; withhold_totals.reward[] += rew
                    end
                    available = max(available, available_honest)
                end
            end
        end
        blind[] || (obs = ToyState(observe(mrng, s.u, eff_marker_σ[]), observe(mrng, s.h, eff_marker_σ[])))  # else the last observation
        record!()
        # SigThGv's perturbation branch (L157). Without adaptation, a random walk: each epoch a
        # candidate within δ is adopted if admissible. With adaptation, experimental design (8.22):
        # each round tries the incumbent and perturbed candidates, interleaved, `gov_trials` epochs
        # each in randomised blocks, observing the outcome they aim to improve (the observed floors' movement, free of
        # the parameters tuned), then shifts to the best only if it wins by `gov_z` standard errors (`select_candidate`).
        if p.govern && !isempty(live(:freeze_governance)) && step >= p.init_steps && (step - p.init_steps) % p.gov_epoch == 0
            degrade!("governance", "frozen", "governance adaptation disabled (progressive removal)")
        elseif p.govern && step >= p.init_steps && (step - p.init_steps) % p.gov_epoch == 0
            floors = (floor_quantile(obs.u, t.q), floor_quantile(obs.h, t.q))
            if !p.adapt
                step > p.init_steps && (pv = candidate(pv); push!(gov.params, copy(pv)))
            else
                if step == p.init_steps
                    new_round!()
                else
                    k = gov.order[gov.slot[] + 1]
                    push!(gov.scores[k], (floors[1] - gov.start[][1]) + (floors[2] - gov.start[][2]))
                    gov.slot[] += 1
                    if gov.slot[] == p.gov_candidates * p.gov_trials
                        means = mean.(gov.scores)
                        ses = [std(x) / sqrt(length(x)) for x in gov.scores]
                        b = select_candidate(means, ses; z = p.gov_z)
                        gov.shifts[] += b != 1
                        # Gauging the freedom range: a candidate significantly worse than the
                        # incumbent means harm lies within the radius.
                        harmed = any(select_candidate([means[k], means[1]], [ses[k], ses[1]]; z = p.gov_z) == 2
                                     for k in 2:length(means))
                        gov.radii[end] > 0 && push!(gov.radii, gauge_radius(gov.radii[end], harmed; factor = p.gov_gauge))
                        gov.radii[end] > 0 || push!(gov.radii, 0.0)
                        pv = copy(gov.cands[b])
                        gov.rounds[] += 1
                        push!(gov.params, copy(pv))
                        new_round!()
                    end
                end
                pv_try = gov.cands[gov.order[gov.slot[] + 1]]
            end
            t = with_params(t, p.adapt ? pv_try : pv)
            gov.start[] = floors
        end
        if governor !== nothing && step % governor_every == 0
            g = governor(step, snapshot())
            if g !== nothing
                haskey(g, :pv) && g.pv !== nothing && (t = with_params(t, g.pv))
                haskey(g, :threshold) && g.threshold !== nothing && (th_now[] = Float64(g.threshold))
                haskey(g, :track_window) && g.track_window !== nothing && (tw_now[] = Int(g.track_window))
                haskey(g, :bars) && g.bars !== nothing && (bar_off[] = collect(Float64, g.bars))
                if haskey(g, :settle) && g.settle !== nothing   # the fractal clusters' reserves settle into the economy (phase D): purses, commons, supply
                    st = g.settle
                    for a in 1:na
                        st.purses[a] == 0.0 && continue
                        balance[a, clamp(argmax(agent_focus[a]), 1, ncol)] += st.purses[a]
                    end
                    rsum = sum(reinvested)
                    rsum > 0 && (reinvested .*= max(0.0, 1 + st.commons / rsum))
                    isempty(tr.supply) ? push!(tr.supply, st.supply) : (tr.supply[end] += st.supply)
                end
            end
        end
    end
    snapshot()
end

"""
    recount(tr) -> (h_pos_own, h_neg_own, relevance_own)

Reputation recounted from a run's memory (L101: Re ← recount(Mem)), for checking the incremental
count: each remembered action attributed by its classification, relevance decayed to the end.
"""
function recount(tr)
    na, n = size(tr.relevance_own)
    rate_gain, rate_loss = decay_rate_for(1.0; λpos = tr.λpos, λneg = tr.λneg), decay_rate_for(-1.0; λpos = tr.λpos, λneg = tr.λneg)
    hp, hn, rel = zeros(na, n), zeros(na, n), zeros(na, n)
    for m in tr.memory, (a, pos, neg) in m.credits
        m.step >= tr.id_since[a] || continue  # an abandoned identity's records
        _, gain, _ = split_signed(m.profile, pos)
        _, _, loss = split_signed(m.profile, neg)
        hp[a, :] .+= gain; hn[a, :] .+= loss
        rel[a, :] .+= reputation_decay.(gain, tr.steps - m.step; rate = rate_gain) .- reputation_decay.(loss, tr.steps - m.step; rate = rate_loss)
    end
    hp, hn, rel
end

"""
    recount_μ(tr) -> Matrix{Float64}

Domain overlap degrees recounted from the open log (`tr.memory`, `tr.evidence`, `tr.formations`),
starting from `tr.μ_init` and replaying logged observations and formations in sequence order.
"""
function recount_μ(tr)
    np, L = size(tr.μ_init)
    μ = copy(tr.μ_init)
    events = Tuple{Int,Int,Any}[]
    for fm in tr.formations
        !fm.reused && !isempty(fm.init_μ) && push!(events, (fm.seq, 1, fm))
    end
    for e in tr.evidence
        push!(events, (e.seq, 2, (st = hasproperty(e, :obs_profile) ? e.obs_profile : e.profile, pm = e.parent_mem)))
    end
    for m in tr.memory
        m.seq > 0 && push!(events, (m.seq, 2, (st = hasproperty(m, :obs_profile) ? m.obs_profile : m.profile, pm = m.parent_mem)))
    end
    sort!(events; by = first)
    for (_, kind, payload) in events
        if kind == 1
            μ[:, payload.leaf] .= payload.init_μ
        else
            for j in eachindex(payload.st), q in 1:np
                payload.st[j] > 0 && (μ[q, j] = membership_rolling(μ[q, j], payload.st[j], payload.pm[q]; rate = tr.μ_rate))
            end
        end
    end
    μ
end

"""
    recount_models(tr) -> NamedTuple

Model evaluation recounted from the open log (`tr.memory`), recovering per-domain transaction rates
and model accuracies (`leaf_accuracy` for each leaf's final top model, `by_uid` across logged models).
"""
function recount_models(tr)
    L = size(tr.μ, 2)
    counts = zeros(Int, max(tr.steps, 1), L)
    ScoreRec = NamedTuple{(:credence, :outcome, :step, :actor),Tuple{Float64,Float64,Int,Int}}
    by_uid = Dict{Int,Vector{ScoreRec}}()
    uid_col = Dict{Int,Int}()
    for m in tr.memory
        isempty(m.scores) && continue
        sstep = m.scores[1].step
        seen_cols = falses(L)
        for s in m.scores
            if 1 <= s.col <= L
                uid_col[s.uid] = s.col
                !seen_cols[s.col] && (seen_cols[s.col] = true; 1 <= sstep < tr.steps && (counts[sstep, s.col] += 1))
            end
            s.col > 0 && push!(get!(by_uid, s.uid, ScoreRec[]), (credence = s.credence, outcome = s.outcome, step = s.step, actor = s.actor))
        end
    end
    d = 2.0^(-1 / tr.rate_halflife)
    rate_sum, rate_norm = zeros(L), 0.0
    for st in 1:tr.steps
        c = st == 1 ? zeros(Int, L) : @view counts[st - 1, :]
        rate_sum .= d .* rate_sum .+ (1 - d) .* c
        rate_norm = d * rate_norm + (1 - d)
    end
    rates = rate_norm > 0 ? rate_sum ./ rate_norm : zeros(L)
    hls = [decay_halflife(rates[j]; ref_rate = tr.acc_rate_ref, ref_halflife = tr.acc_halflife, mute = tr.acc_mute) for j in 1:L]
    disc(x) = x.actor > 0 && any(s0 <= x.step <= s1 for (s0, s1) in tr.discount_spans[x.actor])
    function eval_hist(h, hl)
        isempty(h) && return 0.0
        if tr.accuracy_rule == :window
            w = @view h[max(1, end - tr.acc_window + 1):end]
            return credence_accuracy([x.credence for x in w], [x.outcome for x in w])
        end
        issorted(h; by = x -> x.step) || sort!(h; by = x -> x.step)
        i0 = searchsortedfirst(h, tr.steps - 40 * hl; by = x -> x isa Real ? x : x.step)
        r = [x for x in @view(h[i0:end]) if !disc(x)]
        isempty(r) ? 0.0 : decayed_accuracy([x.credence for x in r], [x.outcome for x in r], [tr.steps - x.step for x in r], hl)
    end
    leaf_acc = [eval_hist(get(by_uid, tr.top_uids[j], ScoreRec[]), hls[j]) for j in 1:L]
    uid_acc = Dict{Int,Float64}(uid => eval_hist(h, hls[get(uid_col, uid, 1)]) for (uid, h) in by_uid)
    (leaf_accuracy = leaf_acc, by_uid = uid_acc, rates = rates)
end

"""
    recount_cc(tr) -> NamedTuple

Causal distribution totals recounted from `tr.memory`, recovering `credit_pos`, `credit_neg`,
`upstream_pos`, `upstream_neg`, `upstream_pos_by_degree`, and `upstream_neg_by_degree`.
"""
function recount_cc(tr)
    na = size(tr.relevance_own, 1)
    cpos, cneg, upos, uneg = zeros(na), zeros(na), zeros(na), zeros(na)
    dpos, dneg = zeros(tr.upstream_depth), zeros(tr.upstream_depth)
    for m in tr.memory
        for (a, pos, neg) in m.credits
            cpos[a] += pos; cneg[a] += neg
        end
        nu = length(m.up_degrees)
        nu > 0 || continue
        off = length(m.credits) - nu
        for r in 1:nu
            e, pp, nn = m.credits[off + r]
            upos[e] += pp; uneg[e] += nn
            deg = m.up_degrees[r]
            1 <= deg <= length(dpos) && (dpos[deg] += pp; dneg[deg] += nn)
        end
    end
    (credit_pos = cpos, credit_neg = cneg, upstream_pos = upos, upstream_neg = uneg,
     upstream_pos_by_degree = dpos, upstream_neg_by_degree = dneg)
end
