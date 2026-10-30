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
    # Contribution types (author ruling, BACKPROPAGATION 8.22; L95: CD ∝ CC + N_CCtype).
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
    # Governed thresholds (M4; SigThGv, L157; `Systems.ParamSpace` [R]).
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
    # Adversarial adaptation (AdvAp, L160; author ruling 8.38): reports, audits, repair.
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
    # Decision market and attacks (M6; docs/SOTA.md; BACKPROPAGATION 8.53-M3a onwards).
    explore_share::Float64       # chance per step one proposal not carried out is carried out anyway (governed; full support)
    takeover_records::Int        # records a challenger needs before it may take over (governed; against extremised forecasts)
    p_extremist::Float64         # chance an arriving model extremises its credences (world, adversary)
    extremise::Float64           # the share of its uncertainty an extremist states (world)
    whitewash::Vector{Float64}   # per agent, chance per step it tries to take a new identity (world, adversary)
    bind_miss::Float64           # chance one cluster's binding methods miss the entity behind a new identity (noise)
    bind_clusters::Int           # clusters whose binding methods examine a new identity (world)
    bind_threshold::Float64      # binding confidence a cluster must reach (governed)
    bind_quorum::Int             # clusters that must reach it to admit an identity (governed)
    slander::Vector{Int}         # per agent, whom its frivolous reports target (0: anyone; world, adversary)
    on_off::Int                  # deceit on only in alternate phases this long, off first (0: always on; world, adversary)
    events::Vector{Shock}  # catastrophes and black swans (world events; see `shock`)
end

"""
    shock(kind; step, duration = 1, size = 0.0, share = 0.0, target = 0) -> Shock

A world event (catastrophes and black swans; author rulings 8.22, 8.23): `:outage` (no markers
for `duration` steps), `:catastrophe` (one hazard at `step` harming each being with chance `share`
by `size`), `:capture` (leaf `target`'s model biased by `size` for `duration` steps),
`:breakthrough` (agent `target`'s skill raised by `size` for `duration` steps).
"""
function shock(kind::Symbol; step::Integer, duration::Integer = 1, size::Real = 0.0, share::Real = 0.0, target::Integer = 0)
    check(kind in (:outage, :catastrophe, :capture, :breakthrough), "kind: outage, catastrophe, capture or breakthrough")
    check(step >= 1 && duration >= 1 && isfinite(size) && 0 <= share <= 1, "step and duration positive, size finite, share in [0, 1]")
    (kind = kind, step = Int(step), duration = Int(duration), size = Float64(size), share = Float64(share), target = Int(target))
end

function M3cParams(toy::ToyParams, agents, leaf_parent, known; λpos::Real, λneg::Real, overlaps = Tuple{Int,Int,Float64}[],
                   marker_σ::Real = 0.05, window::Integer = 100, spread::Real = 0.03, classify_σ::Real = 0.03,
                   parent_threshold::Real = 0.5, μ_min::Real = 0.2, leaf_threshold::Real = 0.4, temperature::Real = 0.01,
                   σ_leaf::Real = 0.15, σ_branch::Real = 0.3, σ_coarse::Real = 0.45, n_learn::Real = 20,
                   threshold::Real = 0.9, novel_threshold::Real = 0.75, coarse_threshold::Real = 0.75, max_credence::Real = 0.99, min_records::Integer = 10, μ_rate::Real = 0.02,
                   μ_every::Integer = 25, endowment::Real = 5.0, cost_per_touch::Real = 0.05, capacity::Real = 1e4,
                   regen::Real = 0.02, overflow_base::Real = 500.0, overflow_factor::Real = 1.0, expert_share::Real = 0.5,
                   form_count::Integer = 20, form_radius::Real = 0.5, max_new::Integer = 16, init_steps::Integer = 50, transactions::Bool = false,
                   causal_distribution::Bool = false, cc_threshold::Real = 0.6, traversal_decay::Real = 0.5, p_upstream::Real = 0.0, β_upstream::Real = 0.5, recent_outputs::Integer = 20,
                   attribution_σ::Real = 0.1, accolade_rate::Real = 0.05, contract_share::Real = 0.2,
                   p_contracted::Real = 0.0, p_hazard::Real = 0.0, hazard_share::Real = 0.1, hazard_size::Real = 1.0,
                   hazard_σ::Real = 0.2, guardians = Int[], p_informed::Real = 0.8, diligence = Float64[],
                   repair_efficiency::Real = 0.0, p_side::Real = 0.0, side_share::Real = 0.3, side_size::Real = 1.0,
                   p_foresee::Real = 0.5, p_shock::Real = 0.0, shock_size::Real = 0.2, govern::Bool = false, adapt::Bool = true, gov_epoch::Integer = 50,
                   gov_δ::Real = 0.02, gov_candidates::Integer = 3, gov_trials::Integer = 4, gov_gauge::Real = 2.0, gov_z::Real = 2.0,
                   bias_σ::Real = 0.1, cost_σ::Real = 0.1, regen_σ::Real = 0.1, memory_loss::Real = 0.02, participation::Real = 0.9, remeasure_σ::Real = 0.3, deceit = Float64[], track_window::Integer = 20, p_trace::Real = 0.5, launder = Float64[], launder_saving::Real = 0.5, choice_σ::Real = 0.5, choice_gain::Real = 5.0,
                   ability_spread::Real = 0.5, advap::Bool = false, vigilance::Real = 0.05, adv_z::Real = 3.0, adv_share::Real = 0.1,
                   adv_floor::Real = 1.0, audit_cost::Real = 1.0, frivolous_threshold::Real = 5.0, adv_window::Integer = 100,
                   p_false_trace::Real = 0.01, frivolous = Float64[], pattern_attention::Real = 9.0,
                   stake_attention::Real = 2.0, marginal_margin::Real = 0.05, relative_bar::Bool = false, escape::Bool = false,
                   escape_start::Integer = 100, escape_steps::Integer = 100, escape_share::Real = 0.5, escape_epoch::Integer = 20,
                   irreparable_loss::Real = Inf, p_new_model::Real = 0.0, improve_drift::Real = -0.1, improve_σ::Real = 0.3,
                   scale_min::Real = 0.1, model_z::Real = 2.0, pool_max::Integer = 4, explore_share::Real = 0.0,
                   takeover_records::Integer = 100, p_extremist::Real = 0.0, extremise::Real = 0.5, whitewash = Float64[],
                   bind_miss::Real = 0.1, bind_clusters::Integer = 3, bind_threshold::Real = 0.5, bind_quorum::Integer = 2,
                   slander = Int[], on_off::Integer = 0, events = Shock[])
    agents = collect(DomainAgent, agents)
    nl, np = length(leaf_parent), maximum(leaf_parent; init = 0)
    check(!isempty(agents) && all(a -> length(a.skills) == nl, agents), "agents need one skill per true leaf")
    check(np >= 1 && all(>=(0), leaf_parent) && length(known) == nl, "leaves need parents and known flags")
    check(all(leaf_parent[l] > 0 for l in 1:nl if known[l]), "known leaves belong to a parent")
    check(all(1 <= l <= nl && 1 <= p <= np && 0 < w <= 1 for (l, p, w) in overlaps), "overlaps name a leaf, a parent and a weight in (0, 1]")
    check(0 < parent_threshold <= 1 && 0 <= μ_min <= 1 && temperature > 0, "thresholds in range, temperature positive")
    check(form_count >= 1 && max_new >= 0 && window >= 1 && min_records >= 0 && μ_every >= 1 && init_steps >= 0, "counts must be positive")
    check(0 <= expert_share <= 1 && 0 < threshold <= 1 && 0 < novel_threshold <= 1 && 0 < coarse_threshold <= 1 && 0.5 <= max_credence < 1,
          "shares and thresholds in (0, 1]; credence cap in [0.5, 1)")
    check(all(x -> isfinite(x) && x >= 0, (λpos, λneg, marker_σ, spread, classify_σ, leaf_threshold, σ_leaf, σ_branch, σ_coarse,
                                             endowment, cost_per_touch, regen, overflow_factor, form_radius)),
          "rates, noises, thresholds and costs must be non-negative")
    check(all(x -> isfinite(x) && x >= 0, (bias_σ, cost_σ, regen_σ)) && 0 <= memory_loss <= 1 && 0 <= participation <= 1,
          "noise sizes non-negative, chances in [0, 1]")
    check(all(x -> 0 <= x <= 1, (p_hazard, hazard_share, p_informed, repair_efficiency, p_side, side_share, p_foresee)),
          "chances, shares and repair efficiency in [0, 1]")
    check(all(x -> isfinite(x) && x >= 0, (hazard_size, hazard_σ, side_size)), "harm sizes non-negative")
    check(isempty(guardians) || (length(guardians) == length(leaf_parent) && all(g -> 0 <= g <= length(agents), guardians)),
          "one guardian (or 0) per true domain")
    check(isempty(diligence) || (length(diligence) == length(agents) && all(d -> 0 <= d <= 1, diligence)), "one diligence per agent")
    check(all(x -> 0 <= x <= 1, (accolade_rate, contract_share, p_contracted, p_shock)) && isfinite(shock_size) &&
          shock_size >= 0, "contribution rates and chances in [0, 1], shock size non-negative")
    check(gov_epoch >= 1 && isfinite(gov_δ) && gov_δ >= 0 && gov_candidates >= 2 && gov_trials >= 2 &&
          isfinite(gov_gauge) && gov_gauge > 1 && isfinite(gov_z) && gov_z >= 0, "governance epoch positive, δ non-negative, two candidates and trials, gauge above 1")
    check(0 <= cc_threshold <= 1 && 0 < traversal_decay <= 1, "confidence threshold in [0, 1], traversal decay in (0, 1]")
    check(0 <= p_upstream <= 1 && isfinite(β_upstream) && β_upstream >= 0 && recent_outputs >= 1 &&
          isfinite(attribution_σ) && attribution_σ >= 0, "upstream chance in [0, 1], strengths and noise non-negative")
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
    check(isempty(slander) || (length(slander) == length(agents) && all(r -> 0 <= slander[r] <= length(agents) && slander[r] != r, eachindex(slander))),
          "one slander target per agent: another agent, or 0")
    check(on_off >= 0, "on-off period non-negative")
    check(all(e -> e.kind != :outage || 0 <= e.target <= length(agents), events), "an outage's saboteur is an agent, or 0")
    check(all(e -> e.kind != :capture || 1 <= e.target <= length(leaf_parent), events) &&
          all(e -> e.kind != :breakthrough || 1 <= e.target <= length(agents), events), "shock targets: a true leaf or an agent")
    check(λneg <= λpos, "losses must decay no faster than gains (author ruling 8.29)")
    check(n_learn > 0 && 0 < μ_rate <= 1 && capacity > 0 && regen <= 1, "learning scale, prior strength and capacity positive")
    check(!isnan(overflow_base) && overflow_base >= 0, "overflow base must be non-negative")
    M3cParams(toy, agents, collect(Int, leaf_parent), collect(Bool, known), collect(Tuple{Int,Int,Float64}, overlaps),
              λpos, λneg, marker_σ, window, spread, classify_σ, parent_threshold, μ_min, leaf_threshold, temperature,
              σ_leaf, σ_branch, σ_coarse, n_learn, threshold, novel_threshold, coarse_threshold, max_credence, min_records, μ_rate, μ_every, endowment,
              cost_per_touch, capacity, regen, overflow_base, overflow_factor, expert_share, form_count, form_radius, max_new, init_steps, transactions,
              causal_distribution, cc_threshold, traversal_decay, p_upstream, β_upstream, recent_outputs, attribution_σ,
              accolade_rate, contract_share, p_contracted, p_hazard, hazard_share, hazard_size, hazard_σ, collect(Int, guardians), p_informed,
              isempty(diligence) ? fill(0.95, length(agents)) : collect(Float64, diligence), repair_efficiency, p_side, side_share,
              side_size, p_foresee, p_shock, shock_size, govern, adapt, gov_epoch, gov_δ, gov_candidates, gov_trials, gov_z, gov_gauge,
              bias_σ, cost_σ, regen_σ, memory_loss, participation, remeasure_σ,
              isempty(deceit) ? zeros(length(agents)) : collect(Float64, deceit), track_window, p_trace,
              isempty(launder) ? zeros(length(agents)) : collect(Float64, launder), launder_saving, choice_σ, choice_gain,
              ability_spread, advap, vigilance, adv_z, adv_share, adv_floor, audit_cost, frivolous_threshold, adv_window, p_false_trace,
              isempty(frivolous) ? zeros(length(agents)) : collect(Float64, frivolous), pattern_attention,
              stake_attention, marginal_margin, relative_bar, escape, escape_start, escape_steps,
              escape_share, escape_epoch, irreparable_loss, p_new_model, improve_drift, improve_σ, scale_min, model_z, pool_max,
              explore_share, takeover_records, p_extremist, extremise,
              isempty(whitewash) ? zeros(length(agents)) : collect(Float64, whitewash), bind_miss, bind_clusters, bind_threshold, bind_quorum,
              isempty(slander) ? zeros(Int, length(agents)) : collect(Int, slander), on_off, collect(Shock, events))
end

distance(x, y) = sqrt(sum(abs2, x .- y))

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
function run_m3c(p::M3cParams; seed)
    t = p.toy
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
        (p.track_window == 0 || h === nothing || isempty(h) || captured(c)) && return (0.0, 0.0)
        r = @view h[max(1, end - p.track_window + 1):end]
        (mean(first, r), mean(last, r))
    end
    # On-off deceit (M6): an attacker may deceive only in alternate phases, honest first, so the
    # track record has forgotten its deceit when each deceptive phase begins.
    deceit_now(a) = (p.on_off == 0 || isodd((cur[] - 1) ÷ p.on_off)) ? p.deceit[a] : 0.0
    function fooled(pred, a, plan, c)
        cu, ch = correction(a, c)
        m = touched(plan)
        d = deceit_now(a)
        (d == 0 && cu == 0 && ch == 0) ? pred :
            ToyPlan(pred.du .+ (d - cu) .* m, pred.dh .+ (d - ch) .* m)
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
    agent_upfront, agent_settled = zeros(na), zeros(na)  # escrow paid upfront, and the value settled (M6)
    track = [Dict{Int,Vector{Tuple{Float64,Float64}}}() for _ in 1:na]  # each model's past errors on each actor (8.29)
    audit_log = [Tuple{Int,Float64,Float64}[] for _ in 1:na]          # and all of them in order, for audits (L160)
    actor_err = [Float64[] for _ in 1:na]               # and the value errors of its corrected estimates
    # AdvAp (L160): where an audit of each actor starts in its record, and each reporter's
    # unfounded reports (steps).
    audit_from = ones(Int, na)
    unfounded = [Int[] for _ in 1:na]
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
        base .+ sum((w .* axis(pp) for (ll, pp, w) in p.overlaps if ll == l); init = zeros(dims)) .+ 0.5 .* axis(np + ntop + l)
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
    Rec = NamedTuple{(:credence, :outcome, :err, :actor, :c, :pr, :mask, :measured, :corr, :peer_corr, :fixed),
                     Tuple{Float64,Float64,Float64,Int,Int,ToyPlan,BitVector,Float64,Tuple{Float64,Float64},Tuple{Float64,Float64},Bool}}
    lhist, phist = [Rec[] for _ in 1:lmax], [Rec[] for _ in 1:np]
    lbias, pbias = p.bias_σ .* randn(nrng, lmax), p.bias_σ .* randn(nrng, np)
    # Each leaf's pool of competing models (L82; 8.42.2): the bootstrap model first (its track-record
    # key is the leaf), challengers as they arrive. `lhist[j]` is the history of the model backing
    # leaf j's currency (the top model); a captured model is the top one when the capture begins.
    # `sharp` is the share of its uncertainty a model states: 1 honest, below 1 an extremist (a world
    # property of the model, M6), whose credences sit nearer 0 and 1 than its record supports.
    Model = NamedTuple{(:uid, :scale, :bias, :sharp, :hist),Tuple{Int,Float64,Float64,Float64,Vector{Rec}}}
    mpool = [Model[(uid = j, scale = 1.0, bias = lbias[j], sharp = 1.0, hist = lhist[j])] for j in 1:lmax]
    top = ones(Int, lmax)
    topm(j) = mpool[j][top[j]]
    tkey(c) = c <= lmax ? topm(c).uid : c
    captured_uid = zeros(Int, lmax)
    irng = Xoshiro(hash((seed, :models)))
    takeovers, next_uid = Ref(0), Ref(10^6)  # challengers' track-record keys never meet a currency column
    takeovers_extreme, arrivals_extreme = Ref(0), Ref(0)
    xtrng = Xoshiro(hash((seed, :extremist)))
    # Accuracy over the recent window is the quality of a model's credences (Lean
    # `credence_accuracy_ref`); its uncertainty, which its credences come from, is the root mean
    # square of its recent value errors: its own track record. No record: no accuracy, a coin toss.
    window_of(h) = @view h[max(1, end - p.window + 1):end]
    acc_of(h) = isempty(h) ? 0.0 : credence_accuracy([x.credence for x in window_of(h)], [x.outcome for x in window_of(h)])
    unc_of(h) = isempty(h) ? Inf : sqrt(mean(x.err^2 for x in window_of(h)))
    # Model error and bias are relative to the domain's natural spread of outcomes (8.35).
    function mbias(j, m)
        cap = sum((e.size for e in live(:capture) if j <= length(ltrue) && ltrue[j] == e.target); init = 0.0)
        cap > 0 && captured_uid[j] == 0 && (captured_uid[j] = topm(j).uid)
        m.bias * t.spread + (m.uid == captured_uid[j] ? cap : 0.0)
    end
    lb(j) = mbias(j, topm(j))
    pb(q) = pbias[q] * t.spread
    leaf_acc(j) = acc_of(lhist[j])
    parent_acc(q) = acc_of(phist[q])
    # A currency's credence for a prediction: from the predicted value and its model's uncertainty.
    # Credence for an actor's action comes from the model's record on that actor (8.29: models
    # estimate from track record), once it has a few entries; before that, from its record overall.
    function cred(c, pred, a = 0; hist = nothing, sharp = c <= lmax ? topm(c).sharp : 1.0)
        e = a > 0 ? (@view actor_err[a][max(1, end - p.track_window + 1):end]) : Float64[]
        u = length(e) >= 5 ? sqrt(mean(abs2, e)) :
            hist !== nothing ? unc_of(hist) : (c <= lmax ? unc_of(lhist[c]) : unc_of(phist[c - lmax]))
        cr = credence(plan_value(pred, t), sharp * u; cap = p.max_credence)
        a > 0 ? ratchet_credence(cr, ledger_neg_share(a)) : cr
    end
    # The reputation ledgers (L101) carry patterns of mistakes and uncovered deception as well as
    # of success: an actor's negative share of its ledgers, whose entries never decay (only the
    # rolling net does; 8.42.1).
    ledger_neg_share(a) = neg_share(sum(h_pos[a, :]), sum(h_neg[a, :]))  # Lean `neg_share_ref`
    # A domain is marginal where its leaf model is near or below its status bar (8.42.1).
    function marginal(b)
        l = argmax(p.agents[b].focus)
        l <= nleaves() && leaf_acc(l) < leaf_bar(l) + p.marginal_margin
    end
    # The status bar: absolute, or relative to the alternative the leaf's work would fall to (8.41),
    # everywhere once adopted, or on the trial's domains while the debatable escape is tried.
    bar_rel = Ref(p.relative_bar)
    trial = (on = Ref(false), leaves = falses(ntrue), units = Dict{Tuple{Bool,Int,Int},Float64}(),
             gains = Ref(0.0), harms = Ref(0.0), irreparable = Ref(0))
    function leaf_bar(j)
        (bar_rel[] || (trial.on[] && trial.leaves[ltrue[j]])) || return p.threshold
        q = argmax(μ[:, j])
        relative_bar(p.threshold, p.coarse_threshold, parent_ok(q) ? parent_acc(q) : p.coarse_threshold)
    end
    leaf_ok(j) = currency_eligible(leaf_acc(j), length(lhist[j]); novel = lnovel[j], threshold = leaf_bar(j),
                                   novel_threshold = p.novel_threshold, min_records = p.min_records)
    parent_ok(q) = currency_eligible(parent_acc(q), length(phist[q]); novel = false, threshold = p.coarse_threshold,
                                     novel_threshold = p.novel_threshold, min_records = p.min_records)
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
    endowed = sum(balance)
    h_pos, h_neg, rel_gain, rel_loss = zeros(na, ncol), zeros(na, ncol), zeros(na, ncol), zeros(na, ncol)
    reinvested = zeros(ncol)
    # Memory logs each executed action with its outcome and the quotes composed for it (L89, L145).
    memory = NamedTuple{(:agent, :step, :signature, :measured, :profile, :parent_mem, :priced, :credits),
                        Tuple{Int,Int,Vector{Float64},Float64,Vector{Float64},Vector{Float64},Vector{Float64},
                              Vector{Tuple{Int,Float64,Float64}}}}[]
    # Recent outputs per true domain that later actions may build on: (agent, effect per being on U, on H).
    outputs = Dict{Int,Vector{Tuple{Int,Float64,Float64}}}()
    credit_pos, credit_neg, upstream_pos, upstream_neg = zeros(na), zeros(na), zeros(na), zeros(na)
    cofunder_credit, interaction = Ref(0.0), Ref(0.0)
    accolade_credit, contract_credit = Ref(0.0), Ref(0.0)
    assessed_outcomes, fallback_outcomes = Ref(0), Ref(0)
    world = (hazards = Ref(0), prevented = Ref(0), crimes = Ref(0), accidents = Ref(0), unattributed = Ref(0.0),
             hazard_penalties = Ref(0.0), hazard_debits = Ref(0.0), repaired = Ref(0.0), side_hazards = Ref(0),
             prevention_records = Ref(0), prevention_measured = Ref(0.0), shocks = Ref(0), commons_spent = Ref(0.0),
             insured = Ref(0.0), self_funded = Ref(0.0), repair_cost = Ref(0.0), outage_harm = Ref(0.0), sabotage_traced = Ref(0),
             laundered = Ref(0), laundered_traced = Ref(0))
    repairs = ToyPlan[]  # restorations funded by penalties, applied at the end of the step
    buffers = Dict{Int,Vector{Vector{Float64}}}()
    formations = NamedTuple{(:step, :leaf, :nearest_leaf, :eligible_step, :reused),Tuple{Int,Int,Int,Int,Bool}}[]
    # Blocked proposals, logged as classification evidence (L88, L145).
    evidence = NamedTuple{(:signature, :profile, :parent_mem),NTuple{3,Vector{Float64}}}[]
    available = p.capacity
    lane = (executed = Ref(0), halted = Ref(0), screened_out = Ref(0), cofunded = Ref(0.0), init_executed = Ref(0), declined = Ref(0))
    # Imperfect agents (8.31): each agent's choice-noise ceiling per true domain, inverse to its skill
    # there on average; its choices draw noise on their own stream.
    xrng = Xoshiro(hash((seed, :choice)))
    choice_caps = ability_caps(xrng, [max(p.agents[a].skills[l], 0.0) for a in 1:na, l in 1:ntrue];
                               base = p.choice_σ, gain = p.choice_gain, spread = p.ability_spread)
    tr = (floor_u = Float64[], floor_h = Float64[], median_u = Float64[], median_h = Float64[], peak_u = Float64[],
          worst_drop = Float64[], chosen_agent = Int[], chosen_step = Int[], true_leaf = Int[],
          stop_leaf = Int[], priced_leaf = Int[], costs = Float64[], touched = Int[], valued_measured = Float64[],
          lane_costs = Float64[], lane_measured = Float64[],
          exec_pred = Float64[], exec_true = Float64[], exec_agent = Int[], exec_step = Int[])
    # Each selected execution's predicted value (the proxy G optimised) and its true value (the realised
    # change's assessed value, which no marker sees exactly): the Goodhart gap (M6).
    function executed!(j, a, step, pred, done)
        executed_j[j] = true
        push!(tr.exec_pred, plan_value(pred, t)); push!(tr.exec_true, plan_value(done, t))
        push!(tr.exec_agent, a); push!(tr.exec_step, step)
    end
    executed_j = falses(0)
    explored = Ref(0)
    exrng, wrng = Xoshiro(hash((seed, :explore))), Xoshiro(hash((seed, :identity)))
    # Identities (Technology Network): when each agent's current identity began; its earlier records
    # belong to an identity it abandoned.
    id_since = ones(Int, na)
    ids = (admitted = Ref(0), linked = Ref(0))
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
        rel_gain[a, :] .+= reputation_decay.(gain, dt; rate = rate_gain)
        rel_loss[a, :] .-= reputation_decay.(loss, dt; rate = rate_loss)
    end
    function credit!(step, c, st, measured, pm, pr, credits)
        # Without markers nothing is measured: the action is logged unmeasured, credited to no one.
        if blind[]
            push!(memory, (agent = credits[1][1], step = step, signature = c, measured = NaN, profile = st,
                           parent_mem = pm, priced = pr, credits = Tuple{Int,Float64,Float64}[]))
            return
        end
        observe_membership!(st, pm)
        for (a, pos, neg) in credits
            apply_credit!(a, st, pos, neg)
            credit_pos[a] += pos; credit_neg[a] += neg
        end
        rand(nrng) < p.memory_loss && return  # lost before reaching memory: gone at the next recount
        push!(memory, (agent = credits[1][1], step = step, signature = c, measured = measured, profile = st,
                       parent_mem = pm, priced = pr, credits = credits))
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
            (credence = cred(c, pr; hist, sharp), outcome = measured > 0 ? 1.0 : 0.0, err = v - measured, actor = a, c = c, pr = pr,
             mask = mask, measured = measured, corr = corr, peer_corr = peer, fixed = false)
        end
        # A model that did not quote is scored on the estimate it would have quoted: fooled by the
        # actor's claims and corrected by its track record, as every quote is.
        for j in 1:nleaves()
            st[j] > 0 || continue
            push!(lhist[j], sc(j, get(() -> fooled(predict(mrng, MetricModel(lb(j), leaf_σ(j, l)), plan), a, plan, tkey(j)), quoted, j), tkey(j)))
            # Every challenger in the pool is scored on the same logged action (the open log).
            for (k, m) in enumerate(mpool[j])
                k == top[j] && continue
                σm = leaf_σ(j, l) / topm(j).scale * m.scale
                push!(m.hist, sc(j, fooled(predict(irng, MetricModel(mbias(j, m), σm), plan), a, plan, m.uid), m.uid, m.hist, m.sharp))
            end
        end
        for q in 1:np
            pm[q] >= p.parent_threshold &&
                push!(phist[q], sc(col_parent(q), get(() -> fooled(predict(mrng, MetricModel(pb(q), parent_σ(q, l)), plan), a, plan, col_parent(q)), quoted, col_parent(q))))
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
        overstated = 0.0
        for (hists, leafy) in (([(m.hist, m.sharp) for j in 1:lmax for m in mpool[j]], true), ([(h, 1.0) for h in phist], false)),
            (h, sharp) in hists, i in eachindex(h)
            r = h[i]
            (r.actor == b && !r.fixed) || continue
            ou, oh = du - (r.corr[1] - r.peer_corr[1]), dh - (r.corr[2] - r.peer_corr[2])
            pr = ToyPlan(r.pr.du .- ou .* r.mask, r.pr.dh .- oh .* r.mask)
            v = plan_value(pr, t)
            leafy && (overstated += max(plan_value(r.pr, t) - v, 0.0))
            h[i] = merge(r, (credence = cred(r.c, pr; hist = h, sharp), err = v - r.measured, pr = pr, fixed = true))
        end
        overstated
    end
    function reclassify!(step)
        for m in eachindex(memory)
            memory[m] = merge(memory[m], (profile = classify_sig(memory[m].signature),))
        end
        # A new leaf learns its overlaps from the logged actions now classified to it.
        for e in eachindex(evidence)
            evidence[e] = merge(evidence[e], (profile = classify_sig(evidence[e].signature),))
        end
        h_pos .= 0; h_neg .= 0; rel_gain .= 0; rel_loss .= 0
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
    for step in 1:t.steps
        scoring_only = step <= p.init_steps
        cur[] = step
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
            confs = [rand(wrng) < p.bind_miss ? 0.9 : 0.1 for _ in 1:p.bind_clusters]
            if binding_admits(confs, p.bind_threshold; quorum = p.bind_quorum)
                ids.admitted[] += 1
                id_since[a] = step
                empty!(track[a]); empty!(actor_err[a]); empty!(audit_log[a]); audit_from[a] = 1; empty!(unfounded[a])
                h_pos[a, :] .= 0; h_neg[a, :] .= 0; rel_gain[a, :] .= 0; rel_loss[a, :] .= 0
            else
                ids.linked[] += 1
            end
        end
        blind[] = !isempty(live(:outage))
        # Markers are back: everything done during the outage is measured now, late, and settled,
        # so an outage cannot be used to escape measurement (author ruling 8.26.5).
        if !blind[] && !isempty(deferred)
            for settle! in deferred
                settle!()
            end
            empty!(deferred)
        end
        proposers = rand(rng, 1:na, t.plans)
        leaves = [pick(drng, p.agents[a].focus) for a in proposers]
        own_plans = [plan_with_mean(rng, skill(a, l), t) for (a, l) in zip(proposers, leaves)]
        # Transaction trees: an action may build on a recent output of another agent in its domain,
        # carrying β of that output's effect on each being it touches.
        ups = Vector{Union{Nothing,Tuple{Int,ToyPlan}}}(nothing, length(own_plans))
        if p.p_upstream > 0
            for j in eachindex(own_plans)
                pool = [o for o in get(outputs, leaves[j], Tuple{Int,Float64,Float64}[]) if o[1] != proposers[j]]
                (isempty(pool) || rand(urng) >= p.p_upstream) && continue
                ua, qu, qh = pool[rand(urng, 1:length(pool))]
                m = touched(own_plans[j])
                ups[j] = (ua, ToyPlan(m .* (p.β_upstream * qu), m .* (p.β_upstream * qh)))
            end
        end
        plans = [ups[j] === nothing ? own_plans[j] :
                 ToyPlan(own_plans[j].du .+ ups[j][2].du, own_plans[j].dh .+ ups[j][2].dh) for j in eachindex(own_plans)]
        # Carry out action j by agent a; the outcome is measured by the markers.
        function perform!(j, a)
            own_done = carried_out(rng, p.agents[a].sloppiness, own_plans[j])
            # A created hazard is direct harm: a crime if foreseen, an accident if not; repaired either way.
            if p.p_side > 0 && rand(srng) < p.p_side
                hit = touched(own_plans[j]) .& (rand(srng, t.n) .< p.side_share)
                if any(hit)
                    side = ToyPlan(-p.side_size .* hit, -p.side_size .* hit)
                    own_done = ToyPlan(own_done.du .+ side.du, own_done.dh .+ side.dh)
                    world.side_hazards[] += 1
                    is_crime(rand(srng) < p.p_foresee, true, false) ? (world.crimes[] += 1) : (world.accidents[] += 1)
                    if p.repair_efficiency > 0
                        push!(repairs, ToyPlan(-p.repair_efficiency .* side.du, -p.repair_efficiency .* side.dh))
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
            done = ups[j] === nothing ? own_done : ToyPlan(own_done.du .+ ups[j][2].du, own_done.dh .+ ups[j][2].dh)
            seen = observed_plan(mrng, done, p.marker_σ)
            m = touched(own_plans[j])
            if p.p_upstream > 0 && any(m)
                out = get!(outputs, leaves[j], Tuple{Int,Float64,Float64}[])
                push!(out, (a, mean(own_done.du[m]), mean(own_done.dh[m])))
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
            up = ups[j] === nothing ? nothing :
                ToyPlan(ups[j][2].du .+ m .* p.attribution_σ .* randn(arng, length(m)),
                        ups[j][2].dh .+ m .* p.attribution_σ .* randn(arng, length(m)))
            eff = up === nothing ? seen : ToyPlan(seen.du .- up.du, seen.dh .- up.dh)  # the actor's own effect
            who = [a; first.(pledges); up === nothing ? Int[] : [ups[j][1]]]
            n, nf = length(who), length(pledges)
            funded(mask) = isodd(mask) && own_pay + sum((pledges[k][2] for k in 1:nf if mask & (1 << k) != 0); init = 0.0) >= need - 1e-9
            hasup(mask) = up !== nothing && mask & (1 << (n - 1)) != 0
            pos, neg = zeros(n), zeros(n)
            # Confidence falls with attribution error and, for a late measurement, its extra noise.
            if n <= 10 && cc_assessed(accuracy(-(p.attribution_σ^2 + late_σ^2)); threshold = p.cc_threshold)
                assessed_outcomes[] += 1
                for b in findall(m)
                    v = [assessed_value((funded(mask) ? eff.du[b] : 0.0) + (hasup(mask) ? up.du[b] : 0.0),
                                        (funded(mask) ? eff.dh[b] : 0.0) + (hasup(mask) ? up.dh[b] : 0.0), t) for mask in 0:(2^n - 1)]
                    φ = shapley(v)
                    pos .+= max.(φ, 0.0); neg .+= min.(φ, 0.0)
                end
            else
                fallback_outcomes[] += 1
                # The substrate records what each link passed on: the upstream output as logged, the
                # co-funders' payments, and the actor's outcome net of what it received.
                rec = up === nothing ? 0.0 : max(sum(assessed_value(ups[j][2].du[b], ups[j][2].dh[b], t) for b in findall(m); init = 0.0), 0.0)
                netc = [max(abs(measured) - rec, 0.0); last.(pledges); up === nothing ? Float64[] : [rec]]
                share = traversal_shares(netc, [0.0; ones(n - 1)]; decay = p.traversal_decay)
                pos .= max(measured, 0.0) .* share; neg .= min(measured, 0.0) .* share
            end
            P, N = sum(pos), sum(neg)
            interaction[] += measured - (P + N)
            credits = [(who[k], P == 0 ? 0.0 : cause_settlement(cc_share(pos[k], P), P, 0.0),
                                N == 0 ? 0.0 : cause_settlement(cc_share(neg[k], N), N, 0.0)) for k in 1:n]
            # Carrying the upstream output on: outside contract, a communicative contribution earning
            # an accolade; under contract, the contracted share, paid as completion of the contract.
            # Either comes out of the maker's positive share; losses stay with whoever caused them.
            if up !== nothing && credits[n][2] > 0
                hired = rand(krng) < p.p_contracted
                fee = carry_fee(credits[n][2], hired; p.accolade_rate, p.contract_share)
                credits[n] = (credits[n][1], credits[n][2] - fee, credits[n][3])
                credits[1] = (credits[1][1], credits[1][2] + fee, credits[1][3])
                (hired ? contract_credit : accolade_credit)[] += fee
            end
            for (k, (e, pp, nn)) in enumerate(credits)
                2 <= k <= 1 + nf && (cofunder_credit[] += pp + nn)
                if up !== nothing && k == n
                    upstream_pos[e] += pp; upstream_neg[e] += nn
                end
            end
            credits
        end
        sigs = [true_sig[l] .+ p.spread .* randn(drng, dims) .+ p.classify_σ .* randn(crng, dims) for l in leaves]
        pms = [parent_mem(c) for c in sigs]
        stops = [classify_sig(c) for c in sigs]
        priced = [price_shares(st) for st in stops]
        unit_cost = scarcity_cost(p.cost_per_touch, available, p.capacity)
        costs = [unit_cost * count(touched(plan)) * exp(p.cost_σ * randn(nrng)) * (1 - p.launder_saving * p.launder[proposers[j]])
                 for (j, plan) in enumerate(plans)]
        menu, menu_preds, offers, lane_queue = Int[], ToyPlan[], Dict{Int,Vector{Tuple{Int,Float64,ToyPlan,Float64}}}(), Int[]
        executed_j = falses(length(plans))
        for j in eachindex(plans)
            k = argmax(stops[j])
            if k > lmax && stops[j][k] > 0.5
                push!(get!(buffers, k, Vector{Float64}[]), sigs[j])
                length(buffers[k]) > 4 * p.form_count && popfirst!(buffers[k])
                push!(evidence, (signature = sigs[j], profile = stops[j], parent_mem = pms[j]))
                observe_membership!(stops[j], pms[j])
            end
            if scoring_only
                bp = best_prediction(stops[j], leaves[j], plans[j])
                bp === nothing && continue
                bp = (bp[1], fooled(bp[2], proposers[j], plans[j], tkey(bp[1])))
                push!(menu, j); push!(menu_preds, bp[2]); offers[j] = [(bp[1], 0.0, bp[2], 0.0)]
                continue
            end
            if priced[j][root] > 0.5
                push!(lane_queue, j)  # no currency can value it: StandCoin, at full resource cost
                continue
            end
            quotes = Tuple{Int,Float64,ToyPlan,Float64}[]
            for c in 1:(root - 1)
                priced[j][c] > 0 || continue
                σ, b = c <= lmax ? (leaf_σ(c, leaves[j]), lb(c)) : (parent_σ(c - lmax, leaves[j]), pb(c - lmax))
                pred = fooled(predict(mrng, MetricModel(b, σ), plans[j]), proposers[j], plans[j], tkey(c))
                push!(quotes, (c, priced[j][c], pred, cred(c, pred, proposers[j])))  # escrow pays by credence (L84)
            end
            price = zeros(ncol)
            price[root] = priced[j][root] * costs[j]
            for (c, sh, pr, cr) in quotes
                price[c] = sh * transaction_price(costs[j], plan_value(pr, t), cr)
            end
            all(price[c] <= 0 || price[c] <= balance[proposers[j], c] for c in 1:ncol) || continue
            push!(menu, j); push!(menu_preds, quotes[argmax([q[2] for q in quotes])][3]); offers[j] = quotes
        end
        rel_gain .= reputation_decay.(rel_gain, 1.0; rate = rate_gain)
        rel_loss .= reputation_decay.(rel_loss, 1.0; rate = rate_loss)
        # Predicted effects of the transactions accepted so far this step: concurrent work is
        # screened together, so it cannot jointly breach a floor (transactions only).
        pend_u, pend_h = zeros(length(s.u)), zeros(length(s.h))
        screened() = ToyState(obs.u .+ pend_u, obs.h .+ pend_h)
        accept!(pred) = p.transactions && (pend_u .+= pred.du; pend_h .+= pred.dh; true)
        function execute_priced!(j)
            # Local, not the step's: a deferred measurement must keep this action's own values.
            local a, plan, l, done, seen, measured, credits, minted, idx
            a, plan, l = proposers[j], plans[j], leaves[j]
            done, seen, measured = perform!(j, a)
            balance[a, root] -= priced[j][root] * costs[j]
            minted = 0.0
            if blind[]
                # Measurement outage (L154 Progressive: degrade, fall back): paid by prediction
                # alone, escrow's upfront (L86), with no settlement.
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
                    learn!(a, plan, offers[j][argmax([q[2] for q in offers[j]])][3], seen_late)
                    score!(stops[j], pms[j], l, plan, seen_late, Dict(c => pr for (c, _, pr, _) in offers[j]), a)
                    credit!(step, sigs[j], stops[j], measured_late, pms[j], priced[j], late)
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
            executed!(j, a, step, offers[j][argmax([q[2] for q in offers[j]])][3], done)
            push!(tr.chosen_agent, a); push!(tr.chosen_step, step); push!(tr.true_leaf, l)
            push!(tr.stop_leaf, top_leaf(stops[j])); push!(tr.priced_leaf, top_leaf(priced[j]))
            push!(tr.costs, costs[j]); push!(tr.touched, count(touched(plan)))
            push!(tr.valued_measured, blind[] ? minted : (1 - priced[j][root]) * sum(x[2] + x[3] for x in credits))
            blind[] || trial_outcome!(l, measured, seen)
            score!(stops[j], pms[j], l, plan, seen, Dict(c => pr for (c, _, pr, _) in offers[j]), a)
            credit!(step, sigs[j], stops[j], measured, pms[j], priced[j], credits)
            available -= count(touched(plan))
            s.u .+= done.du
            s.h .+= done.dh
        end
        if scoring_only
            # Score-only: no currency moves; the work G chooses is executed, scored and logged.
            f = choose(obs, menu_preds, t)
            if f > 1
                j = menu[f - 1]
                a, plan, l = proposers[j], plans[j], leaves[j]
                done, seen, measured = perform!(j, a)
                score!(stops[j], pms[j], l, plan, seen, Dict(offers[j][1][1] => offers[j][1][3]), a)
                learn!(a, plan, offers[j][1][3], seen)
                executed!(j, a, step, offers[j][1][3], done)
                credit!(step, sigs[j], stops[j], measured, pms[j], priced[j], credits_for(j, a, seen, measured))
                lane.init_executed[] += 1
                available -= count(touched(plan))
                s.u .+= done.du
                s.h .+= done.dh
            end
        elseif p.transactions
            # Every proposal is a transaction: screened by G, executed if paid for (L86-L89).
            for (k, j) in enumerate(menu)
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
            done, seen, measured = perform!(j, a)
            executed!(j, a, step, pred, done)
            push!(tr.lane_costs, need); blind[] || push!(tr.lane_measured, measured)
            blind[] || trial_outcome!(l, measured, seen)
            lane.executed[] += 1
            accept!(pred)
            score!(stops[j], pms[j], l, plan, seen, Dict(c => pred), a)
            blind[] || learn!(a, plan, pred, seen)
            credit!(step, sigs[j], stops[j], measured, pms[j], priced[j],
                    blind[] ? [(a, 0.0, 0.0)] : credits_for(j, a, seen, measured; pledges, need, own_pay = self_pay))
            if blind[]
                push!(deferred, function ()
                    seen_late = observed_plan(mrng, done, p.marker_σ + p.remeasure_σ)
                    measured_late = plan_value(seen_late, t)
                    push!(tr.lane_measured, measured_late)
                    score!(stops[j], pms[j], l, plan, seen_late, Dict(c => pred), a)
                    credit!(step, sigs[j], stops[j], measured_late, pms[j], priced[j],
                            credits_for(j, a, seen_late, measured_late; pledges, need, own_pay = self_pay, late_σ = p.remeasure_σ))
                end)
            end
            available -= count(touched(plan))
            s.u .+= done.du
            s.h .+= done.dh
        end
        # Full support where predictions are scored (Chen, Kash, Ruberry & Shnayder 2014; 8.53-M3a).
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
                    done, seen, measured = perform!(j, a)
                    explored[] += 1
                    push!(tr.lane_costs, costs[j]); push!(tr.lane_measured, measured)
                    trial_outcome!(l, measured, seen)
                    score!(stops[j], pms[j], l, plan, seen, Dict(bp[1] => pred), a)
                    learn!(a, plan, pred, seen)
                    credit!(step, sigs[j], stops[j], measured, pms[j], priced[j], credits_for(j, a, seen, measured; need = costs[j], own_pay = costs[j]))
                    push!(tr.chosen_agent, a); push!(tr.chosen_step, step); push!(tr.true_leaf, l)
                    push!(tr.stop_leaf, top_leaf(stops[j])); push!(tr.priced_leaf, top_leaf(priced[j]))
                    available -= count(touched(plan))
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
        # capability (author rulings 8.22, 8.26; L119 Liability ranks it before beings). The commons
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
            need = scarcity_cost(p.cost_per_touch, available, p.capacity) * count(hit)
            sig = true_sig[l] .+ p.spread .* randn(hrng, dims)
            st = classify_sig(sig)
            # Only a qualified currency prices the repair (8.35.4); with none, it costs its full resource cost.
            bp = best_prediction(price_shares(st), l, ToyPlan(-p.repair_efficiency .* harm.du, -p.repair_efficiency .* harm.dh))
            price = bp === nothing ? need : transaction_price(need, plan_value(bp[2], t), cred(bp[1], bp[2]))
            own = clamp(need - max(price, 0.0), 0.0, need)
            spend = min(sum(tr.costs) + sum(tr.lane_costs) - world.commons_spent[], clamp(price, 0.0, need))
            f = p.repair_efficiency * min(own + spend, need) / need
            if f > 0
                push!(repairs, ToyPlan(-f .* harm.du, -f .* harm.dh))
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
                is_crime(true, true, false) ? (world.crimes[] += 1) : (world.accidents[] += 1)
                sig = true_sig[l] .+ p.spread .* randn(hrng, dims)
                st, pm = classify_sig(sig), parent_mem(sig)
                credit!(cur[], sig, st, measured, pm, price_shares(st), [(cause, 0.0, measured)])
                world.hazard_penalties[] += -measured
                if cur[] > p.init_steps
                    balance[cause, :] .+= split_signed(st, measured)[1]
                    world.hazard_debits[] += -measured
                end
                if p.repair_efficiency > 0
                    push!(repairs, ToyPlan(p.repair_efficiency .* -harm.du, p.repair_efficiency .* -harm.dh))
                    world.repaired[] += p.repair_efficiency * -measured
                end
            else
                insure!(harm, hit, measured, l)
            end
            (measured = measured, traced = traced)
        end
        function hazard!(share, sz)
            local l, hit, size, harm, g, informed, act, measured, sig, st, pm, need, spend, f, φ, price, own
            world.hazards[] += 1
            l = rand(hrng, 1:ntrue)
            hit = rand(hrng, t.n) .< share
            size = sz .* max.(0.0, 1 .+ p.hazard_σ .* randn(hrng, t.n))
            harm = ToyPlan(-hit .* size, -hit .* size)
            g = isempty(p.guardians) ? 0 : p.guardians[l]
            informed = g > 0 && rand(hrng) < p.p_informed
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
                        insure!(harm, hit, measured, l)
                    else
                        is_crime(informed, false, true) ? (world.crimes[] += 1) : (world.accidents[] += 1)
                        sig = true_sig[l] .+ p.spread .* randn(hrng, dims)
                        st, pm = classify_sig(sig), parent_mem(sig)
                        φ = measured  # its one contributor's whole share, assessed against the committed action
                        credit!(step, sig, st, measured, pm, price_shares(st), [(g, 0.0, φ)])
                        world.hazard_penalties[] += -φ
                        if !scoring_only
                            balance[g, :] .+= split_signed(st, φ)[1]
                            world.hazard_debits[] += -φ
                        end
                        if p.repair_efficiency > 0
                            push!(repairs, ToyPlan(-p.repair_efficiency .* harm.du, -p.repair_efficiency .* harm.dh))
                            world.repaired[] += p.repair_efficiency * -φ
                        end
                    end
                end
            end
        end
        p.p_hazard > 0 && rand(hrng) < p.p_hazard && hazard!(p.hazard_share, p.hazard_size)
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
                    r = examine!(harm, hit, saboteur, saboteur > 0 ? argmax(p.agents[saboteur].focus) : 1, p.marker_σ + p.remeasure_σ)
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
        for rep in repairs
            s.u .+= rep.du; s.h .+= rep.dh
        end
        empty!(repairs)
        available = min(p.capacity, max(0.0, available) + p.regen * p.capacity * max(0.0, 1 + p.regen_σ * randn(nrng)))
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
            push!(formations, (step = step, leaf = leaf, nearest_leaf = ltrue[leaf], eligible_step = 0, reused = existing !== nothing))
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
                excess = overflow(balance[a, c], accumulation_threshold(p.overflow_base, p.overflow_factor, totals[c]))
                balance[a, c] -= excess
                reinvested[c] += excess
            end
        end
        for (a, c, ru, rh) in pending_track
            push!(get!(track[a], c, Tuple{Float64,Float64}[]), (ru, rh))
            push!(audit_log[a], (c, ru, rh))
        end
        for (a, e) in pending_err
            push!(actor_err[a], e)
        end
        empty!(pending_track); empty!(pending_err)
        # Better models over time (8.42.2): a new model may arrive in each domain, its error relative
        # to the incumbent's drawn around an assumed improvement, never perfect; a challenger takes
        # over when its credences beat the incumbent's by the significance rule (L82, L49).
        if p.p_new_model > 0
            for j in 1:nleaves()
                if rand(irng) < p.p_new_model
                    scale = max(p.scale_min, topm(j).scale * exp(p.improve_drift + p.improve_σ * randn(irng)))
                    next_uid[] += 1
                    extreme = p.p_extremist > 0 && rand(xtrng) < p.p_extremist
                    arrivals_extreme[] += extreme
                    push!(mpool[j], (uid = next_uid[], scale = scale,
                                    bias = p.bias_σ * randn(irng), sharp = extreme ? p.extremise : 1.0, hist = Rec[]))
                    if length(mpool[j]) > p.pool_max  # drop the least accurate challenger with a record, else the oldest
                        cands = [k for k in eachindex(mpool[j]) if k != top[j]]
                        scored = [k for k in cands if length(mpool[j][k].hist) >= p.min_records]
                        drop = isempty(scored) ? first(cands) : scored[argmin([acc_of(mpool[j][k].hist) for k in scored])]
                        deleteat!(mpool[j], drop); drop < top[j] && (top[j] -= 1)
                    end
                end
                length(mpool[j]) > 1 || continue
                brier(h) = [credence_score(x.credence, x.outcome) for x in window_of(h)]  # Lean `credence_score_ref`
                # A challenger competes once its record spans `takeover_records` (8.53-M3b): picking the
                # best of several on a few records rewards extremised credences (Witkowski et al. 2023).
                ks = [top[j]; [k for k in eachindex(mpool[j]) if k != top[j] && length(mpool[j][k].hist) >= p.takeover_records]]
                length(ks) > 1 || continue
                sc_ = [brier(mpool[j][k].hist) for k in ks]
                ms = [isempty(x) ? 0.0 : mean(x) for x in sc_]
                ses = [length(x) < 2 ? 1e12 : std(x) / sqrt(length(x)) for x in sc_]
                w = select_candidate(ms, ses; z = p.model_z)
                if w != 1
                    top[j] = ks[w]; lhist[j] = topm(j).hist; takeovers[] += 1
                    takeovers_extreme[] += topm(j).sharp != 1.0
                end
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
        if p.advap && !blind[] && !scoring_only && na > 1
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
                    stake = marginal(b) ? p.agents[r].focus[argmax(p.agents[b].focus)] : 0.0
                    chance = p.vigilance / (na - 1) * (1 + p.pattern_attention * ledger_neg_share(b)) * (1 + p.stake_attention * stake)
                    rand(vrng) < chance && push!(reads, (r, b, false))
                end
            end
            for (r, b, frivol) in reads
                # The actor's raw errors since its last audit, against other actors' recent ones on
                # the same models: overstatement beyond what the models err on everyone.
                rec = audit_log[b][audit_from[b]:end]
                length(rec) >= 5 || frivol || continue
                # Per model, other actors' recent raw errors: what it errs on everyone.
                w = max(p.track_window, 20)
                peers_of(c) = vcat([track[k][c][max(1, end - w + 1):end] for k in 1:na if k != b && haskey(track[k], c)]...)
                base = Dict(c => peers_of(c) for c in unique(first.(rec)))
                mu(c, f) = isempty(base[c]) ? 0.0 : mean(f, base[c])
                res_u = [ru - mu(c, first) for (c, ru, _) in rec]
                res_h = [rh - mu(c, last) for (c, _, rh) in rec]
                cen = vcat([[(x[1] + x[2]) / 2 - (mu(c, first) + mu(c, last)) / 2 for x in base[c]] for c in keys(base)]...)
                stat(x) = (isempty(x) ? 0.0 : mean(x), length(x) < 2 ? Inf : max(std(x), 1e-12) / sqrt(length(x)))
                (m, se), (m0, se0) = stat((res_u .+ res_h) ./ 2), stat(cen)
                lb_ = argmax(p.agents[b].focus)
                ok = isfinite(se) && isfinite(se0)
                frivol || (ok && (m - m0) / sqrt(se^2 + se0^2) + choice_noise(xrng, choice_caps[r, lb_]) > p.adv_z) || continue
                adv.reports[] += 1
                adv.audits[] += p.audit_cost
                founded = ok && select_candidate([m0, m], [se0, se]; z = p.adv_z) == 2
                sig = true_sig[lb_]
                st = price_shares(classify_sig(sig))
                if founded
                    adv.founded[] += 1
                    traced = rand(vrng) < (p.deceit[b] > 0 ? p.p_trace : p.p_false_trace)
                    traced || continue  # not established: the audit is the commons' cost
                    adv.established[] += 1
                    is_crime(true, true, false) ? (world.crimes[] += 1) : (world.accidents[] += 1)
                    # The overstatement repaired is estimated from all the actor's records, so each
                    # further audit sharpens it rather than repairing by a few records' noise.
                    allrec = audit_log[b]
                    for c in unique(first.(allrec))
                        haskey(base, c) || (base[c] = peers_of(c))
                    end
                    du = mean(ru - mu(c, first) for (c, ru, _) in allrec)
                    dh = mean(rh - mu(c, last) for (c, _, rh) in allrec)
                    prevented = repair_records!(b, du, dh)
                    # What deceit gained the actor: nothing settlement has not already clawed back
                    # (escrow pays upfront by credence and settles on the measured outcome, L86).
                    reward = advap_reward(0.0, prevented; share = p.adv_share, floor = p.adv_floor)
                    liability = advap_liability(reward; audit_cost = p.audit_cost)
                    balance[b, :] .+= split_signed(st, -liability)[1]
                    balance[r, :] .+= split_signed(st, reward)[1]
                    adv.rewards[] += reward; adv.liability[] += liability; adv.net[] += reward - liability
                    credit!(step, sig, classify_sig(sig), reward - liability, parent_mem(sig), st, [(b, 0.0, -liability), (r, reward, 0.0)])
                    audit_from[b] = length(audit_log[b]) + 1
                else
                    push!(unfounded[r], step)
                    filter!(x -> x > step - p.adv_window, unfounded[r])
                    pen = report_penalty(length(unfounded[r]), p.frivolous_threshold; audit_cost = p.audit_cost)
                    if pen > 0
                        balance[r, :] .+= split_signed(st, -pen)[1]
                        adv.penalties[] += pen; adv.net[] -= pen
                        credit!(step, sig, classify_sig(sig), -pen, parent_mem(sig), st, [(r, 0.0, -pen)])
                    end
                end
            end
        end
        blind[] || (obs = ToyState(observe(mrng, s.u, p.marker_σ), observe(mrng, s.h, p.marker_σ)))  # else the last observation
        record!()
        # SigThGv's perturbation branch (L157). Without adaptation, a random walk: each epoch a
        # candidate within δ is adopted if admissible. With adaptation, experimental design (8.22):
        # each round tries the incumbent and perturbed candidates, interleaved, `gov_trials` epochs
        # each in randomised blocks, observing the outcome they aim to improve (the observed floors' movement, free of
        # the parameters tuned), then shifts to the best only if it wins by `gov_z` standard errors (`select_candidate`).
        if p.govern && step >= p.init_steps && (step - p.init_steps) % p.gov_epoch == 0
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
    end
    L = nleaves()
    cols = [1:L; (lmax + 1):ncol]
    own_rel = (rel_gain .+ rel_loss)[:, cols]
    merge(tr, (μ = μ[:, 1:L], formations = formations, balance = balance[:, cols], endowment = p.endowment, endowed = endowed,
               h_pos_own = h_pos[:, cols], h_neg_own = h_neg[:, cols], relevance_own = own_rel,
               relevance_leaf = own_rel[:, 1:L], relevance_resid = own_rel[:, (L + 1):(L + np)],
               relevance_parent = reduce(vcat, [relevance_parents(a)' for a in 1:na]),
               reinvested = reinvested[cols], lane_executed = lane.executed[], lane_halted = lane.halted[], lane_screened_out = lane.screened_out[], init_executed = lane.init_executed[], declined = lane.declined[],
               credit_pos = credit_pos, credit_neg = credit_neg, upstream_pos = upstream_pos, upstream_neg = upstream_neg,
               cofunder_credit = cofunder_credit[], interaction = interaction[],
               accolade_credit = accolade_credit[], contract_credit = contract_credit[],
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
               explored = explored[], identities_admitted = ids.admitted[], identities_linked = ids.linked[], id_since = id_since,
               top_scale = [topm(j).scale for j in 1:L], top_trace = top_trace,
               assessed_outcomes = assessed_outcomes[], fallback_outcomes = fallback_outcomes[],
               hazards = world.hazards[], prevented = world.prevented[], crimes = world.crimes[], accidents = world.accidents[],
               unattributed = world.unattributed[], hazard_penalties = world.hazard_penalties[], hazard_debits = world.hazard_debits[],
               repaired = world.repaired[], side_hazards = world.side_hazards[],
               params = gov.params, tried = gov.tried, rounds = gov.rounds[], shifts = gov.shifts[], radii = gov.radii, agents = p.agents,
               cofunded = lane.cofunded[], memory = [merge(m, (profile = m.profile[cols],)) for m in memory],
               λpos = p.λpos, λneg = p.λneg, steps = t.steps))
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
