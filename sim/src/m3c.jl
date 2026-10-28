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
# scored against the outcome. Blockages (plans mostly stuck at a parent or the root) that cluster
# within `form_radius`, `form_count` strong, form a novel leaf at their centroid. μ starts from the
# bootstrap pattern (signature overlap) and is learnt from memory as fuzzy subsethood every
# `μ_every` steps and at each formation, when memory is reclassified and reputation recounted.
# Reputation is kept where actions are classified; a parent's aggregates its leaves' by μ.

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
    μ_k::Float64
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
    # Noise in steps not covered above (zero by default; see `sim/README.md` for realistic ranges).
    bias_σ::Float64        # each metric model's systematic bias, drawn once per model
    cost_σ::Float64        # resource accounting error, multiplicative (log-normal)
    regen_σ::Float64       # variability of resource regeneration, relative
    memory_loss::Float64   # chance a record never reaches memory
    participation::Float64 # chance an asked expert takes part in co-funding
end

function M3cParams(toy::ToyParams, agents, leaf_parent, known; λpos::Real, λneg::Real, overlaps = Tuple{Int,Int,Float64}[],
                   marker_σ::Real = 0.0, window::Integer = 10, spread::Real = 0.03, classify_σ::Real = 0.03,
                   parent_threshold::Real = 0.5, μ_min::Real = 0.2, leaf_threshold::Real = 0.4, temperature::Real = 0.01,
                   σ_leaf::Real = 0.3, σ_branch::Real = 0.5, σ_coarse::Real = 0.75, n_learn::Real = 20,
                   threshold::Real = 0.55, novel_threshold::Real = 0.52, min_records::Integer = 10, μ_k::Real = 5,
                   μ_every::Integer = 25, endowment::Real = 5.0, cost_per_touch::Real = 0.05, capacity::Real = 1e4,
                   regen::Real = 0.02, overflow_base::Real = 500.0, overflow_factor::Real = 1.0, expert_share::Real = 0.5,
                   form_count::Integer = 20, form_radius::Real = 0.5, max_new::Integer = 16,
                   bias_σ::Real = 0.0, cost_σ::Real = 0.0, regen_σ::Real = 0.0, memory_loss::Real = 0.0, participation::Real = 1.0)
    agents = collect(DomainAgent, agents)
    nl, np = length(leaf_parent), maximum(leaf_parent; init = 0)
    check(!isempty(agents) && all(a -> length(a.skills) == nl, agents), "agents need one skill per true leaf")
    check(np >= 1 && all(>=(0), leaf_parent) && length(known) == nl, "leaves need parents and known flags")
    check(all(leaf_parent[l] > 0 for l in 1:nl if known[l]), "known leaves belong to a parent")
    check(all(1 <= l <= nl && 1 <= p <= np && 0 < w <= 1 for (l, p, w) in overlaps), "overlaps name a leaf, a parent and a weight in (0, 1]")
    check(0 < parent_threshold <= 1 && 0 <= μ_min <= 1 && temperature > 0, "thresholds in range, temperature positive")
    check(form_count >= 1 && max_new >= 0 && window >= 1 && min_records >= 0 && μ_every >= 1, "counts must be positive")
    check(0 <= expert_share <= 1 && 0 < threshold <= 1 && 0 < novel_threshold <= 1, "shares and thresholds in (0, 1]")
    check(all(x -> isfinite(x) && x >= 0, (λpos, λneg, marker_σ, spread, classify_σ, leaf_threshold, σ_leaf, σ_branch, σ_coarse,
                                             endowment, cost_per_touch, regen, overflow_factor, form_radius)),
          "rates, noises, thresholds and costs must be non-negative")
    check(all(x -> isfinite(x) && x >= 0, (bias_σ, cost_σ, regen_σ)) && 0 <= memory_loss <= 1 && 0 <= participation <= 1,
          "noise sizes non-negative, chances in [0, 1]")
    check(n_learn > 0 && μ_k > 0 && capacity > 0 && regen <= 1, "learning scale, prior strength and capacity positive")
    check(!isnan(overflow_base) && overflow_base >= 0, "overflow base must be non-negative")
    M3cParams(toy, agents, collect(Int, leaf_parent), collect(Bool, known), collect(Tuple{Int,Int,Float64}, overlaps),
              λpos, λneg, marker_σ, window, spread, classify_σ, parent_threshold, μ_min, leaf_threshold, temperature,
              σ_leaf, σ_branch, σ_coarse, n_learn, threshold, novel_threshold, min_records, μ_k, μ_every, endowment,
              cost_per_touch, capacity, regen, overflow_base, overflow_factor, expert_share, form_count, form_radius, max_new,
              bias_σ, cost_σ, regen_σ, memory_loss, participation)
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
    s = toy_state(t, rng)
    na, ntrue, np = length(p.agents), length(p.leaf_parent), maximum(p.leaf_parent)
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
    μ0 = zeros(np, lmax)
    for (j, σ) in enumerate(lsig), q in 1:np
        μ0[q, j] = projection_membership(σ, parent_sig[q])
    end
    μ = copy(μ0)
    nleaves() = length(lsig)
    col_parent(q) = lmax + q
    root = lmax + np + 1
    ncol = root
    # Models: one per leaf and per parent; histories of scores.
    lhist, phist = [Float64[] for _ in 1:lmax], [Float64[] for _ in 1:np]
    lbias, pbias = p.bias_σ .* randn(nrng, lmax), p.bias_σ .* randn(nrng, np)
    rolling(h, prior) = isempty(h) ? -prior^2 : mean(@view h[max(1, end - p.window + 1):end])
    leaf_prior(j) = lnovel[j] ? p.σ_coarse : p.σ_leaf
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
    memory = NamedTuple{(:agent, :step, :signature, :measured, :profile, :parent_mem),
                        Tuple{Int,Int,Vector{Float64},Float64,Vector{Float64},Vector{Float64}}}[]
    buffers = Dict{Int,Vector{Vector{Float64}}}()
    formations = NamedTuple{(:step, :leaf, :nearest_leaf, :eligible_step),NTuple{4,Int}}[]
    available = p.capacity
    lane = (executed = Ref(0), halted = Ref(0), screened_out = Ref(0), cofunded = Ref(0.0))
    tr = (floor_u = Float64[], floor_h = Float64[], chosen_agent = Int[], chosen_step = Int[], true_leaf = Int[],
          stop_leaf = Int[], priced_leaf = Int[], costs = Float64[], touched = Int[], valued_measured = Float64[],
          lane_costs = Float64[], lane_measured = Float64[])
    top_leaf(st) = (k = argmax(st); k <= lmax ? k : 0)
    function relevance_parents(a)
        mine = rel_gain[a, :] .+ rel_loss[a, :]
        [aggregate_at_parent(μ[q, 1:nleaves()], mine[1:nleaves()]) + mine[col_parent(q)] for q in 1:np]
    end
    function credit!(a, step, c, st, measured, pm)
        net, pos, neg = split_signed(st, measured)
        h_pos[a, :] .+= pos; h_neg[a, :] .+= neg
        (measured >= 0 ? rel_gain : rel_loss)[a, :] .+= net
        rand(nrng) < p.memory_loss && return  # lost before reaching memory: gone at the next recount
        push!(memory, (agent = a, step = step, signature = c, measured = measured, profile = st, parent_mem = pm))
    end
    # Every model on the classification path is scored against the outcome.
    function score!(st, pm, l, plan, seen, quoted)
        mask = touched(plan)
        realised = [seen.du[mask]; seen.dh[mask]]
        sc(pr) = mm_score([pr.du[mask]; pr.dh[mask]], realised)
        for j in 1:nleaves()
            st[j] > 0 && push!(lhist[j], sc(get(() -> predict(mrng, MetricModel(lbias[j], leaf_σ(j, l)), plan), quoted, j)))
        end
        for q in 1:np
            pm[q] >= p.parent_threshold &&
                push!(phist[q], sc(get(() -> predict(mrng, MetricModel(pbias[q], parent_σ(q, l)), plan), quoted, col_parent(q))))
        end
    end
    function relearn!(step)
        for m in eachindex(memory)
            memory[m] = merge(memory[m], (profile = classify_sig(memory[m].signature),))
        end
        ce = ones(length(memory))
        for j in 1:nleaves(), q in 1:np
            mx = [m.profile[j] for m in memory]
            S = subsethood(mx, [m.parent_mem[q] for m in memory], ce)
            μ[q, j] = membership_update(μ0[q, j], S, count(>(0), mx); k = p.μ_k)
        end
        h_pos .= 0; h_neg .= 0; rel_gain .= 0; rel_loss .= 0
        for m in memory
            net, pos, neg = split_signed(m.profile, m.measured)
            h_pos[m.agent, :] .+= pos; h_neg[m.agent, :] .+= neg
            r = m.measured >= 0 ? rate_gain : rate_loss
            (m.measured >= 0 ? rel_gain : rel_loss)[m.agent, :] .+= reputation_decay.(net, step - m.step; rate = r)
        end
    end
    record!() = (push!(tr.floor_u, floor_quantile(s.u, t.q)); push!(tr.floor_h, floor_quantile(s.h, t.q)))
    record!()
    obs = ToyState(observe(mrng, s.u, p.marker_σ), observe(mrng, s.h, p.marker_σ))
    for step in 1:t.steps
        proposers = rand(rng, 1:na, t.plans)
        leaves = [pick(drng, p.agents[a].focus) for a in proposers]
        plans = [plan_with_mean(rng, p.agents[a].skills[l], t) for (a, l) in zip(proposers, leaves)]
        sigs = [true_sig[l] .+ p.spread .* randn(drng, dims) .+ p.classify_σ .* randn(crng, dims) for l in leaves]
        pms = [parent_mem(c) for c in sigs]
        stops = [classify_sig(c) for c in sigs]
        priced = [price_shares(st) for st in stops]
        unit_cost = scarcity_cost(p.cost_per_touch, available, p.capacity)
        costs = [unit_cost * count(touched(plan)) * exp(p.cost_σ * randn(nrng)) for plan in plans]
        menu, menu_preds, offers, lane_queue = Int[], ToyPlan[], Dict{Int,Vector{Tuple{Int,Float64,ToyPlan,Float64}}}(), Int[]
        for j in eachindex(plans)
            k = argmax(stops[j])
            if k > lmax && stops[j][k] > 0.5
                push!(get!(buffers, k, Vector{Float64}[]), sigs[j])
                length(buffers[k]) > 4 * p.form_count && popfirst!(buffers[k])
            end
            if priced[j][root] > 0.5
                push!(lane_queue, j)  # no currency can value it: StandCoin, at full resource cost
                continue
            end
            quotes = Tuple{Int,Float64,ToyPlan,Float64}[]
            for c in 1:(root - 1)
                priced[j][c] > 0 || continue
                σ, b, acc = c <= lmax ? (leaf_σ(c, leaves[j]), lbias[c], leaf_acc(c)) :
                    (parent_σ(c - lmax, leaves[j]), pbias[c - lmax], parent_acc(c - lmax))
                push!(quotes, (c, priced[j][c], predict(mrng, MetricModel(b, σ), plans[j]), acc))
            end
            price = zeros(ncol)
            price[root] = priced[j][root] * costs[j]
            for (c, sh, pr, acc) in quotes
                price[c] = sh * transaction_price(costs[j], plan_value(pr, t), acc)
            end
            all(price[c] <= 0 || price[c] <= balance[proposers[j], c] for c in 1:ncol) || continue
            push!(menu, j); push!(menu_preds, quotes[argmax([q[2] for q in quotes])][3]); offers[j] = quotes
        end
        f = choose(obs, menu_preds, t)
        rel_gain .= reputation_decay.(rel_gain, 1.0; rate = rate_gain)
        rel_loss .= reputation_decay.(rel_loss, 1.0; rate = rate_loss)
        if f == 1
            push!(tr.chosen_agent, 0)
        else
            j = menu[f - 1]
            a, plan, l = proposers[j], plans[j], leaves[j]
            done = carried_out(rng, p.agents[a].sloppiness, plan)
            seen = observed_plan(mrng, done, p.marker_σ)
            measured = plan_value(seen, t)
            balance[a, root] -= priced[j][root] * costs[j]
            for (c, sh, pr, acc) in offers[j]
                upfront = sh * acc * plan_value(pr, t)
                balance[a, c] += upfront - sh * costs[j] + settlement(sh * measured, upfront)
            end
            push!(tr.chosen_agent, a); push!(tr.chosen_step, step); push!(tr.true_leaf, l)
            push!(tr.stop_leaf, top_leaf(stops[j])); push!(tr.priced_leaf, top_leaf(priced[j]))
            push!(tr.costs, costs[j]); push!(tr.touched, count(touched(plan)))
            push!(tr.valued_measured, (1 - priced[j][root]) * measured)
            score!(stops[j], pms[j], l, plan, seen, Dict(c => pr for (c, _, pr, _) in offers[j]))
            credit!(a, step, sigs[j], stops[j], measured, pms[j])
            available -= count(touched(plan))
            s.u .+= done.du
            s.h .+= done.dh
        end
        # The StandCoin lane: work no qualified currency can value. It is still screened by G on
        # the best available model, qualified or not (score-only models predict too), and goes
        # ahead if the proposer, with experts, can pay its full resource cost.
        for j in lane_queue
            a, plan, l = proposers[j], plans[j], leaves[j]
            c = argmax(stops[j][1:(root - 1)])
            if stops[j][c] <= 0
                lane.screened_out[] += 1  # no model of any kind: not expected once domains exist
                continue
            end
            pred = c <= lmax ? predict(mrng, MetricModel(lbias[c], leaf_σ(c, l)), plan) :
                predict(mrng, MetricModel(pbias[c - lmax], parent_σ(c - lmax, l)), plan)
            if choose(obs, [pred], t) == 1
                lane.screened_out[] += 1
                continue
            end
            need = costs[j]
            own = min(need, max(balance[a, root], 0.0))
            experts = sort([(e, sum(relevance_parents(e) .* (pms[j] .> 0))) for e in 1:na if e != a]; by = x -> -x[2])
            pledges = Tuple{Int,Float64}[]
            for (e, r) in experts
                own + sum(last, pledges; init = 0.0) >= need && break
                r > 0 || break
                rand(nrng) < p.participation || continue
                give = min(need - own - sum(last, pledges; init = 0.0), p.expert_share * max(balance[e, root], 0.0))
                give > 0 && push!(pledges, (e, give))
            end
            if own + sum(last, pledges; init = 0.0) < need - 1e-12
                lane.halted[] += 1
                continue
            end
            balance[a, root] -= own
            for (e, g) in pledges
                balance[e, root] -= g
                lane.cofunded[] += g
            end
            done = carried_out(rng, p.agents[a].sloppiness, plan)
            seen = observed_plan(mrng, done, p.marker_σ)
            measured = plan_value(seen, t)
            push!(tr.lane_costs, need); push!(tr.lane_measured, measured)
            lane.executed[] += 1
            score!(stops[j], pms[j], l, plan, seen, Dict(c => pred))
            credit!(a, step, sigs[j], stops[j], measured, pms[j])
            available -= count(touched(plan))
            s.u .+= done.du
            s.h .+= done.dh
        end
        available = min(p.capacity, max(0.0, available) + p.regen * p.capacity * max(0.0, 1 + p.regen_σ * randn(nrng)))
        # Formation of novel leaves from clustered blockages; then μ is relearnt from memory.
        formed = false
        for k in sort(collect(keys(buffers)))
            nleaves() < lmax || break
            buf = buffers[k]
            length(buf) >= p.form_count || continue
            near = [[i for i in eachindex(buf) if distance(buf[i], x) <= p.form_radius] for x in buf]
            best = argmax(length.(near))
            length(near[best]) >= p.form_count || continue
            centroid = mean(buf[near[best]])
            push!(lsig, centroid); push!(lnovel, true)
            push!(ltrue, argmin([distance(centroid, σ) for σ in true_sig]))
            for q in 1:np
                μ0[q, nleaves()] = projection_membership(centroid, parent_sig[q])
            end
            μ[:, nleaves()] .= μ0[:, nleaves()]
            push!(formations, (step = step, leaf = nleaves(), nearest_leaf = ltrue[end], eligible_step = 0))
            deleteat!(buf, near[best])
            formed = true
        end
        (formed || step % p.μ_every == 0) && relearn!(step)
        for (i, fm) in enumerate(formations)
            fm.eligible_step == 0 && leaf_ok(fm.leaf) && (formations[i] = merge(fm, (eligible_step = step,)))
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
        obs = ToyState(observe(mrng, s.u, p.marker_σ), observe(mrng, s.h, p.marker_σ))
        record!()
    end
    L = nleaves()
    cols = [1:L; (lmax + 1):ncol]
    own = (rel_gain .+ rel_loss)[:, cols]
    merge(tr, (μ = μ[:, 1:L], formations = formations, balance = balance[:, cols], endowment = p.endowment, endowed = endowed,
               h_pos_own = h_pos[:, cols], h_neg_own = h_neg[:, cols], relevance_own = own,
               relevance_leaf = own[:, 1:L], relevance_resid = own[:, (L + 1):(L + np)],
               relevance_parent = reduce(vcat, [relevance_parents(a)' for a in 1:na]),
               reinvested = reinvested[cols], lane_executed = lane.executed[], lane_halted = lane.halted[], lane_screened_out = lane.screened_out[],
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
    for m in tr.memory
        net, pos, neg = split_signed(m.profile, m.measured)
        hp[m.agent, :] .+= pos; hn[m.agent, :] .+= neg
        rel[m.agent, :] .+= reputation_decay.(net, tr.steps - m.step; rate = m.measured >= 0 ? rate_gain : rate_loss)
    end
    hp, hn, rel
end
