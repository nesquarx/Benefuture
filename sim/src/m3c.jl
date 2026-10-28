# Toy model M3c: M3b on a domain tree (author ruling, BACKPROPAGATION 8.3).
#
# World (this file): true leaf domains sit under branches of a tree rooted at StandCoin; some are
# missing from the initial tree (hidden), under a branch or directly under the root. Signatures:
# branch b is the unit vector e_b; a leaf under b is e_b + 0.5 e_leaf; a top-level domain has its
# own axis. Each plan works in a true leaf drawn from its agent's focus, its causal signature
# near that leaf's. Currency metric models measure the signature with noise and classify it by
# descent from the root; whatever stops at a node with children is a blockage there. Pricing
# falls back to the nearest eligible ancestor: a node's currency is eligible while its model's
# rolling score (its expected error before any record) is within `err_threshold`. Each currency's
# model predicts the plan; a model is accurate (`σ_leaf`) for its own leaf and coarse
# (`σ_coarse`) otherwise. StandCoin, at the root, predicts nothing and charges resource cost
# only, by availability: a plan mostly at the root cannot be valued and leaves G's menu, logged as
# a novelty signal. When `form_count` blockages at a node lie within `form_radius` of one another
# a subdomain forms there at their centroid; its model starts coarse and learns with records, and
# reputation is recounted from memory. Reputation is kept per node where an action is
# classified; a domain's total sums its subdomains'. Rules (Lean): everything in M3b, plus tree
# classification, fallback, subtree sums and resource cost by availability.

"M3c parameters: the toy world, agents over true leaves, the initial tree, and thresholds."
struct M3cParams
    toy::ToyParams
    agents::Vector{DomainAgent}
    leaf_branch::Vector{Int}   # each true leaf's branch, 0 for a top-level domain
    known::Vector{Bool}        # true leaves present in the initial tree
    λpos::Float64
    λneg::Float64
    marker_σ::Float64
    window::Int
    spread::Float64
    classify_σ::Float64
    thresholds::Vector{Float64}
    temperature::Float64
    σ_leaf::Float64
    σ_coarse::Float64
    n_learn::Float64
    err_threshold::Float64
    endowment::Float64
    cost_per_touch::Float64
    capacity::Float64
    regen::Float64
    overflow_base::Float64
    overflow_factor::Float64
    form_count::Int
    form_radius::Float64
    max_new::Int
end

function M3cParams(toy::ToyParams, agents, leaf_branch, known; λpos::Real, λneg::Real, marker_σ::Real = 0.0,
                   window::Integer = 10, spread::Real = 0.03, classify_σ::Real = 0.03, thresholds = [0.8, 0.4],
                   temperature::Real = 0.01, σ_leaf::Real = 0.3, σ_coarse::Real = 1.0, n_learn::Real = 20,
                   err_threshold::Real = 1.5, endowment::Real = 5.0, cost_per_touch::Real = 0.05,
                   capacity::Real = 1e4, regen::Real = 0.02, overflow_base::Real = 500.0, overflow_factor::Real = 1.0,
                   form_count::Integer = 20, form_radius::Real = 0.5, max_new::Integer = 16)
    agents = collect(DomainAgent, agents)
    nl = length(leaf_branch)
    check(!isempty(agents) && all(a -> length(a.skills) == nl, agents), "agents need one skill per true leaf")
    check(length(known) == nl && all(b -> b >= 0, leaf_branch) && any(>(0), leaf_branch), "leaves need branches and known flags")
    check(all(leaf_branch[l] > 0 for l in 1:nl if known[l]), "known leaves sit under a branch")
    check(length(thresholds) >= 2 && all(t -> isfinite(t) && t >= 0, thresholds), "one threshold per level of the initial tree")
    check(form_count >= 1 && max_new >= 0 && window >= 1, "formation count and window must be positive")
    check(all(x -> isfinite(x) && x >= 0, (λpos, λneg, marker_σ, spread, classify_σ, σ_leaf, σ_coarse, err_threshold,
                                             endowment, cost_per_touch, regen, overflow_factor, form_radius)),
          "rates, noises, thresholds and costs must be non-negative")
    check(temperature > 0 && n_learn > 0 && capacity > 0 && regen <= 1, "temperature, learning scale and capacity positive")
    check(!isnan(overflow_base) && overflow_base >= 0, "overflow base must be non-negative")
    M3cParams(toy, agents, collect(Int, leaf_branch), collect(Bool, known), λpos, λneg, marker_σ, window, spread,
              classify_σ, collect(Float64, thresholds), temperature, σ_leaf, σ_coarse, n_learn, err_threshold, endowment,
              cost_per_touch, capacity, regen, overflow_base, overflow_factor, form_count, form_radius, max_new)
end

distance(x, y) = sqrt(sum(abs2, x .- y))

"Ancestors of `v` up to but excluding the root, with `v` itself."
function lineage(parents, v)
    out = Int[]
    while v > 1
        push!(out, v)
        v = parents[v]
    end
    out
end

"""
    run_m3c(p; seed) -> NamedTuple

Run M3c. Matrices are agents × nodes of the final tree (node 1 is the root, StandCoin): `balance`,
own reputation (`h_pos_own`, `h_neg_own`, `relevance_own`, where actions were classified) and
`relevance` (totals over subtrees). Per chosen plan: `chosen_step`, `true_leaf`, `stop_node`
(largest classification share), `priced_node` (largest priced share), `costs`, `touched`,
`valued_measured` (measured value in the shares a domain priced). `formations` lists new nodes.
"""
function run_m3c(p::M3cParams; seed)
    t = p.toy
    rng, mrng = Xoshiro(seed), Xoshiro(hash((seed, :measurement)))
    drng, crng = Xoshiro(hash((seed, :domain))), Xoshiro(hash((seed, :classification)))
    s = toy_state(t, rng)
    na, nl = length(p.agents), length(p.leaf_branch)
    nb, ntop = maximum(p.leaf_branch), count(==(0), p.leaf_branch)
    dims = nb + ntop + nl
    axis(i) = Float64.((1:dims) .== i)
    leaf_sig = [b == 0 ? axis(nb + count(==(0), p.leaf_branch[1:l])) : axis(b) .+ 0.5 .* axis(nb + ntop + l)
                for (l, b) in enumerate(p.leaf_branch)]
    # The initial tree: root, branches, known leaves.
    parents, sigs, node_leaf, established = [0], [zeros(dims)], [0], [true]
    branch_node = zeros(Int, nb)
    for b in 1:nb
        push!(parents, 1); push!(sigs, axis(b)); push!(node_leaf, 0); push!(established, true)
        branch_node[b] = length(parents)
    end
    leaf_node = zeros(Int, nl)
    for l in 1:nl
        p.known[l] || continue
        push!(parents, branch_node[p.leaf_branch[l]]); push!(sigs, leaf_sig[l]); push!(node_leaf, l); push!(established, true)
        leaf_node[l] = length(parents)
    end
    n0 = length(parents)
    nmax = n0 + p.max_new
    has_children(v) = any(==(v), parents)
    history = [Float64[] for _ in 1:nmax]
    rolling(v) = isempty(history[v]) ? -prior_σ(v)^2 : mean(@view history[v][max(1, end - p.window + 1):end])
    prior_σ(v) = node_leaf[v] != 0 && established[v] ? p.σ_leaf : p.σ_coarse  # expected error before records
    model_σ(v, l) = node_leaf[v] != l ? p.σ_coarse :
        established[v] ? p.σ_leaf : p.σ_leaf + (p.σ_coarse - p.σ_leaf) * exp(-length(history[v]) / p.n_learn)
    eligible(v) = v == 1 || rolling(v) >= -p.err_threshold
    confidence(v) = 1 / (1 + sqrt(-rolling(v)))
    classify_sig(c) = classify_tree(parents, [distance(c, σ) for σ in sigs]; thresholds = p.thresholds, temperature = p.temperature)
    rate_gain, rate_loss = decay_rate_for(1.0; λpos = p.λpos, λneg = p.λneg), decay_rate_for(-1.0; λpos = p.λpos, λneg = p.λneg)
    balance = zeros(na, nmax); balance[:, 1:n0] .= p.endowment
    h_pos, h_neg, rel_gain, rel_loss = zeros(na, nmax), zeros(na, nmax), zeros(na, nmax), zeros(na, nmax)
    reinvested = zeros(nmax)
    memory = NamedTuple{(:agent, :step, :signature, :measured, :profile),Tuple{Int,Int,Vector{Float64},Float64,Vector{Float64}}}[]
    buffers = [Vector{Vector{Float64}}() for _ in 1:nmax]
    formations = NamedTuple{(:step, :node, :parent, :nearest_leaf),NTuple{4,Int}}[]
    available, root_blocked = p.capacity, 0
    tr = (floor_u = Float64[], floor_h = Float64[], chosen_agent = Int[], chosen_step = Int[], true_leaf = Int[],
          stop_node = Int[], priced_node = Int[], costs = Float64[], touched = Int[], valued_measured = Float64[])
    pad(x) = [x; zeros(nmax - length(x))]
    function recount_into!(hp, hn, rg, rl, T)
        hp .= 0; hn .= 0; rg .= 0; rl .= 0
        for m in memory
            net, pos, neg = split_signed(m.profile, m.measured)
            hp[m.agent, :] .+= pad(pos); hn[m.agent, :] .+= pad(neg)
            dt = T - m.step
            if m.measured >= 0
                rg[m.agent, :] .+= pad(reputation_decay.(net, dt; rate = rate_gain))
            else
                rl[m.agent, :] .+= pad(reputation_decay.(net, dt; rate = rate_loss))
            end
        end
    end
    record!() = (push!(tr.floor_u, floor_quantile(s.u, t.q)); push!(tr.floor_h, floor_quantile(s.h, t.q)))
    record!()
    obs = ToyState(observe(mrng, s.u, p.marker_σ), observe(mrng, s.h, p.marker_σ))
    for step in 1:t.steps
        n = length(parents)
        proposers = rand(rng, 1:na, t.plans)
        leaves = [pick(drng, p.agents[a].focus) for a in proposers]
        plans = [plan_with_mean(rng, p.agents[a].skills[l], t) for (a, l) in zip(proposers, leaves)]
        measured_sigs = [leaf_sig[l] .+ p.spread .* randn(drng, dims) .+ p.classify_σ .* randn(crng, dims) for l in leaves]
        stops = [classify_sig(c) for c in measured_sigs]
        elig = [eligible(v) for v in 1:n]
        priced = [fallback(parents, elig, st) for st in stops]
        unit_cost = scarcity_cost(p.cost_per_touch, available, p.capacity)
        costs = [unit_cost * count(touched(plan)) for plan in plans]
        menu, menu_preds, offers = Int[], ToyPlan[], Dict{Int,Vector{Tuple{Int,Float64,ToyPlan,Float64}}}()
        for j in eachindex(plans)
            v = argmax(stops[j])
            if has_children(v) && stops[j][v] > 0.5
                v == 1 && (root_blocked += 1)
                push!(buffers[v], measured_sigs[j])
                length(buffers[v]) > 4 * p.form_count && popfirst!(buffers[v])
            end
            priced[j][1] > 0.5 && continue  # only StandCoin would take it: no domain can value it
            quotes = [(v, priced[j][v], predict(mrng, MetricModel(0.0, model_σ(v, leaves[j])), plans[j]), confidence(v))
                      for v in 2:n if priced[j][v] > 0]
            price = zeros(n)
            price[1] = priced[j][1] * costs[j]
            for (v, sh, pr, cf) in quotes
                price[v] = sh * transaction_price(costs[j], plan_value(pr, t), cf)
            end
            all(price[v] <= 0 || price[v] <= balance[proposers[j], v] for v in 1:n) || continue
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
            balance[a, 1] -= priced[j][1] * costs[j]
            for (v, sh, pr, cf) in offers[j]
                upfront = sh * cf * plan_value(pr, t)
                balance[a, v] += upfront - sh * costs[j] + settlement(sh * measured, upfront)
            end
            push!(tr.chosen_agent, a); push!(tr.chosen_step, step); push!(tr.true_leaf, l)
            push!(tr.stop_node, argmax(stops[j])); push!(tr.priced_node, argmax(priced[j][2:end]) + 1)
            push!(tr.costs, costs[j]); push!(tr.touched, count(touched(plan)))
            push!(tr.valued_measured, (1 - priced[j][1]) * measured)
            # Every model on the classification path is scored against the outcome.
            mask = touched(plan)
            realised = [seen.du[mask]; seen.dh[mask]]
            quoted = Dict(v => pr for (v, _, pr, _) in offers[j])
            for v in unique(reduce(vcat, [lineage(parents, u) for u in 1:n if stops[j][u] > 0]; init = Int[]))
                pr = get(() -> predict(mrng, MetricModel(0.0, model_σ(v, l)), plan), quoted, v)
                push!(history[v], mm_score([pr.du[mask]; pr.dh[mask]], realised))
            end
            push!(memory, (agent = a, step = step, signature = measured_sigs[j], measured = measured, profile = stops[j]))
            net, pos, neg = split_signed(stops[j], measured)
            h_pos[a, 1:n] .+= pos; h_neg[a, 1:n] .+= neg
            (measured >= 0 ? rel_gain : rel_loss)[a, 1:n] .+= net
            available -= count(mask)
            s.u .+= done.du
            s.h .+= done.dh
        end
        available = min(p.capacity, max(0.0, available) + p.regen * p.capacity)
        # Subdomain formation from clustered blockages; memory is reclassified and recounted.
        for v in 1:length(parents)
            length(parents) < nmax || break
            buf = buffers[v]
            length(buf) >= p.form_count || continue
            near = [[k for k in eachindex(buf) if distance(buf[k], x) <= p.form_radius] for x in buf]
            best = argmax(length.(near))
            length(near[best]) >= p.form_count || continue
            centroid = mean(buf[near[best]])
            push!(parents, v); push!(sigs, centroid); push!(established, false)
            push!(node_leaf, argmin([distance(centroid, σ) for σ in leaf_sig]))
            push!(formations, (step = step, node = length(parents), parent = v, nearest_leaf = node_leaf[end]))
            deleteat!(buf, near[best])
            for (k, m) in enumerate(memory)
                memory[k] = merge(m, (profile = classify_sig(m.signature),))
            end
            recount_into!(h_pos, h_neg, rel_gain, rel_loss, step)
        end
        n = length(parents)
        for a in 1:na
            totals = subtree_sum(parents, rel_gain[a, 1:n] .+ rel_loss[a, 1:n])
            for v in 1:n
                excess = overflow(balance[a, v], accumulation_threshold(p.overflow_base, p.overflow_factor, totals[v]))
                balance[a, v] -= excess
                reinvested[v] += excess
            end
        end
        obs = ToyState(observe(mrng, s.u, p.marker_σ), observe(mrng, s.h, p.marker_σ))
        record!()
    end
    n = length(parents)
    relevance_own = (rel_gain .+ rel_loss)[:, 1:n]
    merge(tr, (parents = parents, branch_node = branch_node, leaf_node = leaf_node, formations = formations,
               balance = balance[:, 1:n], endowment = p.endowment, endowed = p.endowment * na * n0,
               h_pos_own = h_pos[:, 1:n], h_neg_own = h_neg[:, 1:n], relevance_own = relevance_own,
               relevance = reduce(vcat, [subtree_sum(parents, relevance_own[a, :])' for a in 1:na]),
               reinvested = reinvested[1:n], root_blocked = root_blocked, memory = memory,
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
        prof = [m.profile; zeros(n - length(m.profile))]
        net, pos, neg = split_signed(prof, m.measured)
        hp[m.agent, :] .+= pos; hn[m.agent, :] .+= neg
        rel[m.agent, :] .+= reputation_decay.(net, tr.steps - m.step; rate = m.measured >= 0 ? rate_gain : rate_loss)
    end
    hp, hn, rel
end
