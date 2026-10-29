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
# below 0.5 (Lean). Ineligible leaves' shares fall back to eligible parents by μ, else to StandCoin.
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
    # Noise in steps not covered above (zero by default; see `sim/README.md` for realistic ranges).
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
                   marker_σ::Real = 0.05, window::Integer = 10, spread::Real = 0.03, classify_σ::Real = 0.03,
                   parent_threshold::Real = 0.5, μ_min::Real = 0.2, leaf_threshold::Real = 0.4, temperature::Real = 0.01,
                   σ_leaf::Real = 0.3, σ_branch::Real = 0.5, σ_coarse::Real = 0.75, n_learn::Real = 20,
                   threshold::Real = 0.55, novel_threshold::Real = 0.52, min_records::Integer = 10, μ_rate::Real = 0.02,
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
                   bias_σ::Real = 0.1, cost_σ::Real = 0.1, regen_σ::Real = 0.1, memory_loss::Real = 0.02, participation::Real = 0.9, remeasure_σ::Real = 0.3, deceit = Float64[], track_window::Integer = 20, p_trace::Real = 0.5, launder = Float64[], launder_saving::Real = 0.5, events = Shock[])
    agents = collect(DomainAgent, agents)
    nl, np = length(leaf_parent), maximum(leaf_parent; init = 0)
    check(!isempty(agents) && all(a -> length(a.skills) == nl, agents), "agents need one skill per true leaf")
    check(np >= 1 && all(>=(0), leaf_parent) && length(known) == nl, "leaves need parents and known flags")
    check(all(leaf_parent[l] > 0 for l in 1:nl if known[l]), "known leaves belong to a parent")
    check(all(1 <= l <= nl && 1 <= p <= np && 0 < w <= 1 for (l, p, w) in overlaps), "overlaps name a leaf, a parent and a weight in (0, 1]")
    check(0 < parent_threshold <= 1 && 0 <= μ_min <= 1 && temperature > 0, "thresholds in range, temperature positive")
    check(form_count >= 1 && max_new >= 0 && window >= 1 && min_records >= 0 && μ_every >= 1 && init_steps >= 0, "counts must be positive")
    check(0 <= expert_share <= 1 && 0 < threshold <= 1 && 0 < novel_threshold <= 1, "shares and thresholds in (0, 1]")
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
    check(all(e -> e.kind != :outage || 0 <= e.target <= length(agents), events), "an outage's saboteur is an agent, or 0")
    check(all(e -> e.kind != :capture || 1 <= e.target <= length(leaf_parent), events) &&
          all(e -> e.kind != :breakthrough || 1 <= e.target <= length(agents), events), "shock targets: a true leaf or an agent")
    check(λneg <= λpos, "losses must decay no faster than gains (author ruling 8.29)")
    check(n_learn > 0 && 0 < μ_rate <= 1 && capacity > 0 && regen <= 1, "learning scale, prior strength and capacity positive")
    check(!isnan(overflow_base) && overflow_base >= 0, "overflow base must be non-negative")
    M3cParams(toy, agents, collect(Int, leaf_parent), collect(Bool, known), collect(Tuple{Int,Int,Float64}, overlaps),
              λpos, λneg, marker_σ, window, spread, classify_σ, parent_threshold, μ_min, leaf_threshold, temperature,
              σ_leaf, σ_branch, σ_coarse, n_learn, threshold, novel_threshold, min_records, μ_rate, μ_every, endowment,
              cost_per_touch, capacity, regen, overflow_base, overflow_factor, expert_share, form_count, form_radius, max_new, init_steps, transactions,
              causal_distribution, cc_threshold, traversal_decay, p_upstream, β_upstream, recent_outputs, attribution_σ,
              accolade_rate, contract_share, p_contracted, p_hazard, hazard_share, hazard_size, hazard_σ, collect(Int, guardians), p_informed,
              isempty(diligence) ? fill(0.95, length(agents)) : collect(Float64, diligence), repair_efficiency, p_side, side_share,
              side_size, p_foresee, p_shock, shock_size, govern, adapt, gov_epoch, gov_δ, gov_candidates, gov_trials, gov_z, gov_gauge,
              bias_σ, cost_σ, regen_σ, memory_loss, participation, remeasure_σ,
              isempty(deceit) ? zeros(length(agents)) : collect(Float64, deceit), track_window, p_trace,
              isempty(launder) ? zeros(length(agents)) : collect(Float64, launder), launder_saving, collect(Shock, events))
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
    # property). Models estimate from track record (author ruling 8.29): each actor's recent
    # prediction errors, per being touched, correct its next estimates. Records reach the models at
    # the end of each step.
    pending_track = Tuple{Int,Float64,Float64}[]
    function correction(a)
        r = @view track[a][max(1, end - p.track_window + 1):end]
        (p.track_window == 0 || isempty(r)) ? (0.0, 0.0) : (mean(first, r), mean(last, r))
    end
    function fooled(pred, a, plan)
        cu, ch = correction(a)
        m = touched(plan)
        (p.deceit[a] == 0 && cu == 0 && ch == 0) ? pred :
            ToyPlan(pred.du .+ (p.deceit[a] - cu) .* m, pred.dh .+ (p.deceit[a] - ch) .* m)
    end
    # The raw error of an estimate (before the correction applied to it), for the actor's record.
    function learn!(a, plan, pred, seen)
        m = touched(plan)
        any(m) || return
        cu, ch = correction(a)
        push!(pending_track, (a, mean(pred.du[m]) + cu - mean(seen.du[m]), mean(pred.dh[m]) + ch - mean(seen.dh[m])))
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
    track = [Tuple{Float64,Float64}[] for _ in 1:na]  # each actor's past estimate errors (8.29)
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
    lhist, phist = [Float64[] for _ in 1:lmax], [Float64[] for _ in 1:np]
    lbias, pbias = p.bias_σ .* randn(nrng, lmax), p.bias_σ .* randn(nrng, np)
    rolling(h, prior) = isempty(h) ? -prior^2 : mean(@view h[max(1, end - p.window + 1):end])
    leaf_prior(j) = lnovel[j] ? p.σ_coarse : p.σ_leaf
    lb(j) = lbias[j] + sum((e.size for e in live(:capture) if j <= length(ltrue) && ltrue[j] == e.target); init = 0.0)
    leaf_acc(j) = accuracy(rolling(lhist[j], leaf_prior(j)))
    parent_acc(q) = accuracy(rolling(phist[q], p.σ_branch))
    leaf_ok(j) = currency_eligible(leaf_acc(j), length(lhist[j]); novel = lnovel[j], threshold = p.threshold,
                                   novel_threshold = p.novel_threshold, min_records = p.min_records)
    parent_ok(q) = currency_eligible(parent_acc(q), length(phist[q]); novel = false, threshold = p.threshold,
                                     novel_threshold = p.novel_threshold, min_records = p.min_records)
    leaf_σ(j, l) = ltrue[j] != l ? p.σ_coarse :
        lnovel[j] ? p.σ_leaf + (p.σ_coarse - p.σ_leaf) * exp(-length(lhist[j]) / p.n_learn) : p.σ_leaf
    parent_σ(q, l) = knows(q, l) ? p.σ_branch : p.σ_coarse
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
    lane = (executed = Ref(0), halted = Ref(0), screened_out = Ref(0), cofunded = Ref(0.0), init_executed = Ref(0))
    tr = (floor_u = Float64[], floor_h = Float64[], chosen_agent = Int[], chosen_step = Int[], true_leaf = Int[],
          stop_leaf = Int[], priced_leaf = Int[], costs = Float64[], touched = Int[], valued_measured = Float64[],
          lane_costs = Float64[], lane_measured = Float64[])
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
    function score!(st, pm, l, plan, seen, quoted)
        blind[] && return  # nothing realised to score against
        mask = touched(plan)
        realised = [seen.du[mask]; seen.dh[mask]]
        sc(pr) = mm_score([pr.du[mask]; pr.dh[mask]], realised)
        for j in 1:nleaves()
            st[j] > 0 && push!(lhist[j], sc(get(() -> predict(mrng, MetricModel(lb(j), leaf_σ(j, l)), plan), quoted, j)))
        end
        for q in 1:np
            pm[q] >= p.parent_threshold &&
                push!(phist[q], sc(get(() -> predict(mrng, MetricModel(pbias[q], parent_σ(q, l)), plan), quoted, col_parent(q))))
        end
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
            apply_credit!(a, m.profile, pos, neg; dt = step - m.step)
        end
    end
    record!() = (push!(tr.floor_u, floor_quantile(s.u, t.q)); push!(tr.floor_h, floor_quantile(s.h, t.q)))
    record!()
    obs = ToyState(observe(mrng, s.u, p.marker_σ), observe(mrng, s.h, p.marker_σ))
    best_prediction(st, l, plan) = (c = argmax(st[1:(root - 1)]); st[c] <= 0 ? nothing :
        c <= lmax ? (c, predict(mrng, MetricModel(lb(c), leaf_σ(c, l)), plan)) :
                    (c, predict(mrng, MetricModel(pbias[c - lmax], parent_σ(c - lmax, l)), plan)))
    for step in 1:t.steps
        scoring_only = step <= p.init_steps
        cur[] = step
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
                bp = (bp[1], fooled(bp[2], proposers[j], plans[j]))
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
                σ, b, acc = c <= lmax ? (leaf_σ(c, leaves[j]), lb(c), leaf_acc(c)) :
                    (parent_σ(c - lmax, leaves[j]), pbias[c - lmax], parent_acc(c - lmax))
                push!(quotes, (c, priced[j][c], fooled(predict(mrng, MetricModel(b, σ), plans[j]), proposers[j], plans[j]), acc))
            end
            price = zeros(ncol)
            price[root] = priced[j][root] * costs[j]
            for (c, sh, pr, acc) in quotes
                price[c] = sh * transaction_price(costs[j], plan_value(pr, t), acc)
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
                for (c, sh, pr, acc) in offers[j]
                    upfront = sh * acc * plan_value(pr, t)
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
                    for (c, sh, pr, acc) in offers[j]
                        upfront = sh * acc * plan_value(pr, t)
                        x = settlement(sh * (late[1][2] + late[1][3]), upfront)
                        agent_settled[a] += sh * (late[1][2] + late[1][3])
                        balance[a, c] += x; delta += x
                        for (e, pp, nn) in late[2:end]
                            balance[e, c] += sh * (pp + nn); delta += sh * (pp + nn)
                        end
                    end
                    tr.valued_measured[idx] += delta
                    learn!(a, plan, offers[j][argmax([q[2] for q in offers[j]])][3], seen_late)
                    score!(stops[j], pms[j], l, plan, seen_late, Dict(c => pr for (c, _, pr, _) in offers[j]))
                    credit!(step, sigs[j], stops[j], measured_late, pms[j], priced[j], late)
                end)
            else
                credits = credits_for(j, a, seen, measured)
                for (c, sh, pr, acc) in offers[j]
                    upfront = sh * acc * plan_value(pr, t)
                    actor_value = credits[1][2] + credits[1][3]
                    balance[a, c] += upfront - sh * costs[j] + settlement(sh * actor_value, upfront)
                    agent_upfront[a] += upfront; agent_settled[a] += sh * actor_value
                    for (e, pp, nn) in credits[2:end]
                        balance[e, c] += sh * (pp + nn)  # other contributors: causal distribution, nothing upfront
                    end
                end
            end
            blind[] || learn!(a, plan, offers[j][argmax([q[2] for q in offers[j]])][3], seen)
            push!(tr.chosen_agent, a); push!(tr.chosen_step, step); push!(tr.true_leaf, l)
            push!(tr.stop_leaf, top_leaf(stops[j])); push!(tr.priced_leaf, top_leaf(priced[j]))
            push!(tr.costs, costs[j]); push!(tr.touched, count(touched(plan)))
            push!(tr.valued_measured, blind[] ? minted : (1 - priced[j][root]) * sum(x[2] + x[3] for x in credits))
            score!(stops[j], pms[j], l, plan, seen, Dict(c => pr for (c, _, pr, _) in offers[j]))
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
                score!(stops[j], pms[j], l, plan, seen, Dict(offers[j][1][1] => offers[j][1][3]))
                learn!(a, plan, offers[j][1][3], seen)
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
            c, pred = bp[1], fooled(bp[2], a, plan)
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
            push!(tr.lane_costs, need); blind[] || push!(tr.lane_measured, measured)
            lane.executed[] += 1
            accept!(pred)
            score!(stops[j], pms[j], l, plan, seen, Dict(c => pred))
            blind[] || learn!(a, plan, pred, seen)
            credit!(step, sigs[j], stops[j], measured, pms[j], priced[j],
                    blind[] ? [(a, 0.0, 0.0)] : credits_for(j, a, seen, measured; pledges, need, own_pay = self_pay))
            if blind[]
                push!(deferred, function ()
                    seen_late = observed_plan(mrng, done, p.marker_σ + p.remeasure_σ)
                    measured_late = plan_value(seen_late, t)
                    push!(tr.lane_measured, measured_late)
                    score!(stops[j], pms[j], l, plan, seen_late, Dict(c => pred))
                    credit!(step, sigs[j], stops[j], measured_late, pms[j], priced[j],
                            credits_for(j, a, seen_late, measured_late; pledges, need, own_pay = self_pay, late_σ = p.remeasure_σ))
                end)
            end
            available -= count(touched(plan))
            s.u .+= done.du
            s.h .+= done.dh
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
            pr = price_shares(st)
            acc = sum((pr[c] * (c <= lmax ? leaf_acc(c) : parent_acc(c - lmax)) for c in 1:(root - 1) if pr[c] > 0); init = 0.0)
            bp = best_prediction(st, l, ToyPlan(-p.repair_efficiency .* harm.du, -p.repair_efficiency .* harm.dh))
            price = transaction_price(need, bp === nothing ? 0.0 : plan_value(bp[2], t), acc)
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
            local l, hit, size, harm, g, informed, act, measured, sig, st, pm, need, spend, f, φ, pr, acc, price, own
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
        for (a, ru, rh) in pending_track
            push!(track[a], (ru, rh))
        end
        empty!(pending_track)
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
               reinvested = reinvested[cols], lane_executed = lane.executed[], lane_halted = lane.halted[], lane_screened_out = lane.screened_out[], init_executed = lane.init_executed[],
               credit_pos = credit_pos, credit_neg = credit_neg, upstream_pos = upstream_pos, upstream_neg = upstream_neg,
               cofunder_credit = cofunder_credit[], interaction = interaction[],
               accolade_credit = accolade_credit[], contract_credit = contract_credit[],
               prevention_records = world.prevention_records[], prevention_measured = world.prevention_measured[], shocks = world.shocks[],
               commons_spent = world.commons_spent[], insured = world.insured[], self_funded = world.self_funded[],
               repair_cost = world.repair_cost[], outage_harm = world.outage_harm[], sabotage_traced = world.sabotage_traced[],
               laundered = world.laundered[], laundered_traced = world.laundered_traced[], upfront = agent_upfront, settled_value = agent_settled,
               leaf_accuracy = [leaf_acc(k) for k in 1:L],
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
        _, gain, _ = split_signed(m.profile, pos)
        _, _, loss = split_signed(m.profile, neg)
        hp[a, :] .+= gain; hn[a, :] .+= loss
        rel[a, :] .+= reputation_decay.(gain, tr.steps - m.step; rate = rate_gain) .- reputation_decay.(loss, tr.steps - m.step; rate = rate_loss)
    end
    hp, hn, rel
end
