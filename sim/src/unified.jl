# ---- The unified world, phase A (WORLD_COVERAGE; author rulings 8.167-8.174): one network, clusters that emerge ----
#
# One trust network (who hears whom) carries the M5 voters' contacts, the rumour (`run_m8_truth`, per voter by the echoes
# among its contacts), the claims (`ih_truth_level` through M5 decisions) and the adoption vote of `run_coupled`; the economy
# receives the claims' outputs. Clusters are never declared: they are read from the interaction measured on that network
# (the weight each voter gave each source it heard), nested (clusters of clusters), and recorded per epoch with per-cluster
# outcome readings. Phase A only measures; governance and the economy per cluster are phase B (8.174).
# Glue and measurement, no rule: the clustering is an instrument (a candidate for a Lean export when phase B lets clusters
# govern), the network is a world property.

using Random, Statistics

"A persistent trust network: `contacts[i]` are the persons voter `i` hears. `planted` is the world's own community labels, kept only to judge recovery (never read by a rule)."
struct TrustNetwork
    n::Int
    contacts::Vector{Vector{Int}}
    planted::Vector{Int}
end

"""
    build_trust_network(n; communities = 4, n_contacts = 5, homophily = 0.85, seed = 1) -> TrustNetwork

World: people live in `communities` (by index modulo, so domains and communities cross) and each hears `n_contacts` others, a
share `homophily` of them from its own community (people mostly talk to their own).
"""
function build_trust_network(n::Integer; communities::Integer = 4, n_contacts::Integer = 5, homophily::Real = 0.85, seed::Integer = 1)
    check(n >= 2 && communities >= 1 && n_contacts >= 1 && 0 <= homophily <= 1, "network: n at least 2, communities and contacts positive, homophily in [0, 1]")
    rng = Xoshiro(hash((seed, :trust_network)))
    planted = [1 + (i - 1) % communities for i in 1:n]
    contacts = map(1:n) do i
        own = [j for j in 1:n if j != i && planted[j] == planted[i]]
        other = [j for j in 1:n if j != i && planted[j] != planted[i]]
        chosen = Int[]
        for _ in 1:min(n_contacts, n - 1)
            pool = filter(j -> !(j in chosen), (rand(rng) < homophily && !isempty(own)) || isempty(other) ? own : other)
            isempty(pool) && (pool = [j for j in 1:n if j != i && !(j in chosen)])
            push!(chosen, pool[rand(rng, 1:length(pool))])
        end
        chosen
    end
    TrustNetwork(n, contacts, planted)
end

"""
    voter_rumour_defer(net, liars, stay, ih; seed) -> Vector{Float64}

Each voter's share who defer to what they hear: the adoption of an echoed rumour (`run_m8_truth`) among the echoes in its own
contacts (the colluders it hears), so a voter who hears no liar adopts none. Measured once per distinct echo count.
"""
function voter_rumour_defer(net::TrustNetwork, liars, stay::Real, ih::Bool; seed::Integer)
    cache = Dict{Int,Float64}()
    fa(c) = c == 0 ? 0.0 : get!(cache, c) do
        run_m8_truth(M8TruthParams(n = 24, steps = 4, echo_copies = c, mode = ih ? :bf_truth : :untagged_naive, seed = seed)).false_adoption
    end
    [clamp(fa(count(in(liars), net.contacts[i])), 0.0, 1 - stay) for i in 1:net.n]
end

"""
    attention_normalise(W) -> Matrix

A listener's attention is finite: each row of the measured interaction is scaled to sum to one (silent rows stay zero), so a forged clique
praising itself loudly carries no more than one unit per member, however loud (gaming: steering the clustering by fake interaction).
"""
function attention_normalise(W::AbstractMatrix{<:Real})
    R = Matrix{Float64}(W); for i in axes(R, 1); s = sum(@view R[i, :]); s > 0 && (R[i, :] ./= s); end
    R
end

"""
    cluster_hierarchy(W) -> NamedTuple

Nested clusters read from measured interaction `W` (n × n, non-negative: the weight `i` gave `j`; symmetrised): greedy agglomeration by
modularity gain (Clauset, Newman and Moore 2004), recording the partition at every number of clusters `k` (so coarser partitions
merge finer ones: clusters of clusters). `partitions[k]` labels the nodes 1..k, `modularity[k]` is its Q, `best` the k with the
highest Q (the fewest on ties, so a world with no interaction is one cluster). Dense, O(n^3): the population-scale world will need a sparse form.
"""
function cluster_hierarchy(W::AbstractMatrix{<:Real})
    n = size(W, 1)
    check(size(W, 2) == n && all(x -> isfinite(x) && x >= 0, W), "interaction: square, finite, non-negative")
    A = Matrix{Float64}((W .+ W') ./ 2); for i in 1:n; A[i, i] = 0.0; end
    m2 = sum(A)
    partitions = Vector{Vector{Int}}(undef, n); Q = zeros(n)
    labels = collect(1:n)
    canon(l) = (u = unique(l); [findfirst(==(x), u) for x in l])
    if m2 <= 0   # nothing measured: everyone is one cluster (the substitute; the caller records it loudly)
        for k in 1:n; partitions[k] = [min(i, k) for i in 1:n]; end
        return (n = n, partitions = partitions, modularity = Q, best = 1)
    end
    E = A ./ m2; a = vec(sum(E; dims = 2)); active = collect(1:n)
    partitions[n] = canon(labels); Q[n] = sum(E[i, i] - a[i]^2 for i in 1:n)
    while length(active) > 1
        bi, bj, bg = 0, 0, -Inf
        for (x, i) in enumerate(active), j in active[(x + 1):end]
            g = 2 * (E[i, j] - a[i] * a[j])
            g > bg && ((bi, bj, bg) = (i, j, g))
        end
        E[bi, :] .+= E[bj, :]; E[:, bi] .+= E[:, bj]; E[bj, :] .= 0.0; E[:, bj] .= 0.0
        a[bi] += a[bj]; a[bj] = 0.0
        labels[labels .== bj] .= bi; filter!(!=(bj), active)
        k = length(active)
        partitions[k] = canon(labels); Q[k] = sum(E[i, i] - a[i]^2 for i in active)
    end
    (n = n, partitions = partitions, modularity = Q, best = something(findfirst(==(maximum(Q)), Q)))
end

"The nested levels of a hierarchy: the best partition, one twice as fine, one half as coarse, and everything as one (descending in the number of clusters)."
function cluster_levels(h)
    h.modularity[h.best] == 0 && h.best == 1 && return [(k = 1, labels = h.partitions[1], modularity = 0.0)]
    ks = sort(unique([min(h.n, 2 * h.best), h.best, max(1, h.best ÷ 2), 1]); rev = true)
    [(k = k, labels = h.partitions[k], modularity = h.modularity[k]) for k in ks]
end

"Nested: every cluster of a finer level lies wholly inside one cluster of the next coarser level."
function levels_nested(levels)
    all(zip(levels[1:(end - 1)], levels[2:end])) do (fine, coarse)
        all(c -> length(unique(coarse.labels[fine.labels .== c])) == 1, unique(fine.labels))
    end
end

"Adjusted Rand index of two labelings (1 identical, about 0 for unrelated ones; Hubert and Arabie 1985)."
function adjusted_rand_index(a::AbstractVector, b::AbstractVector)
    check(length(a) == length(b), "labelings of the same nodes")
    n = length(a); c2(x) = x * (x - 1) / 2
    ua, ub = unique(a), unique(b)
    nij = [count(i -> a[i] == x && b[i] == y, 1:n) for x in ua, y in ub]
    sa = sum(c2.(sum(nij; dims = 2))); sb = sum(c2.(sum(nij; dims = 1))); sn = sum(c2.(nij)); tot = c2(n)
    exp_ = sa * sb / tot; mx = (sa + sb) / 2
    mx == exp_ ? 1.0 : (sn - exp_) / (mx - exp_)
end

"Per-cluster readings of per-voter measures: for each cluster its members and the mean of each reading over them."
function cluster_readings(labels::AbstractVector{<:Integer}, readings::NamedTuple)
    [(cluster = c, members = findall(==(c), labels), size = count(==(c), labels),
      (; (nm => mean(v[labels .== c]) for (nm, v) in pairs(readings))...)...) for c in sort(unique(labels))]
end

"""
    UnifiedParams

World wiring of the unified world (`run_coupled(...; unified = UnifiedParams())`): the network (`communities`, `n_contacts`,
`homophily`), where the lie starts (`liar_community` > 0: every colluder drawn from that community, `liar_share` of it; 0: every
`liar_stride`-th person), the claims per epoch and hops, and `ih`, overrides of `IhWorldParams` fields (`extremist_frac`, `signal_σ`, ...).
"""
Base.@kwdef struct UnifiedParams
    communities::Int = 4
    n_contacts::Int = 5
    homophily::Float64 = 0.85
    liar_community::Int = 0
    liar_share::Float64 = 1 / 3
    liar_stride::Int = 3
    claims_per_epoch::Int = 4
    rounds::Int = 2
    domains::Vector{Int} = [1, 2, 3, 4]
    ih_flag::Bool = true
    over::Dict{Symbol,Any} = Dict{Symbol,Any}()
    identity::Union{Nothing,IdentityParams} = nothing   # entry-point identity binding layer (8.72, 8.167c); nothing: no newcomers or sybils
end

"Set the unified world up: the network, the claim stream on it (a pre-pass over the horizon's epochs), the economy with the claims' outputs as its inputs."
function unified_setup(econ::M3cParams, up::UnifiedParams, n_epochs::Integer; seed::Integer)
    na = length(econ.agents)
    net = build_trust_network(na; communities = up.communities, n_contacts = up.n_contacts, homophily = up.homophily, seed = seed)
    liars = if up.liar_community > 0
        mem = [i for i in 1:na if net.planted[i] == up.liar_community]
        mem[1:max(1, round(Int, up.liar_share * length(mem)))]
    else
        collect(1:up.liar_stride:na)
    end
    m3 = run_m3c(econ; seed = seed)   # the society the claims circulate in (reputations)
    ihp = IhWorldParams(; m3, econ, domains = up.domains, steps = n_epochs, claims_per_step = up.claims_per_epoch, ih = up.ih_flag,
                        network = net, rounds = up.rounds, liars_override = liars, run_economy = false, seed = seed, up.over...)
    cl = run_ih_world(ihp)
    (net = net, claims = cl, econ = _with_fields(econ, Dict{Symbol,Any}(:p_informed => cl.econ_inputs.p_informed, :p_side => cl.econ_inputs.p_side)),
     bloc = cl.bloc, gov_inter = zeros(na, na), epochs = NamedTuple[], n_epochs = n_epochs,
     ident = up.identity === nothing ? nothing : identity_setup(up.identity, net, up.communities; seed = seed))
end

"The governance's M5 parameters on the one network: its contacts, its colluders, its rumour exposure."
unified_gp(U, gp::M5Params) = _with_fields(gp, Dict{Symbol,Any}(:network => U.net.contacts, :defer_voter => U.claims.voter_defer,
                                                               :colluders => U.bloc, :tag_liars => U.bloc))

"Add what a governance M5 run heard (its `heard`) to the measured interaction."
function unified_hear!(U, heard)
    for i in eachindex(heard.sources), (j, w) in zip(heard.sources[i], heard.weights[i]); U.gov_inter[i, j] += w; end
end

"Record epoch `ep`: clusters (nested) from the interaction measured so far, with per-cluster outcome readings."
function unified_record!(U, ep::Integer, reputation::AbstractMatrix)
    e = clamp(ep, 1, length(U.claims.interaction))
    W = attention_normalise(reduce(+, U.claims.interaction[1:e]) .+ U.gov_inter)
    # the identity layer (8.72): newcomers and sybils join the attention matrix, weighted by their confidence once binding is on
    isnap = U.ident === nothing ? nothing : identity_advance!(U.ident, W, ep)
    isnap === nothing || (W = identity_weighted(U.ident, identity_attention(U.ident, W)))
    h = cluster_hierarchy(W); lv = cluster_levels(h)
    s = U.claims.voter_snapshots[e]
    readings = (led_astray = s.led_astray, accuracy = s.accuracy, rumour_deferral = U.claims.voter_defer, reputation = vec(mean(max.(reputation, 0.0); dims = 2)))
    push!(U.epochs, (epoch = ep, levels = lv, nested = levels_nested(lv), interaction = sum(reduce(+, U.claims.interaction[1:e]) .+ U.gov_inter),
                     agreement = adjusted_rand_index(lv[findfirst(l -> l.k == h.best, lv)].labels[1:U.net.n], U.net.planted),
                     readings = [(k = l.k, clusters = cluster_readings(l.labels[1:U.net.n], readings)) for l in lv], identity = isnap))
end

"What the unified world reports: the network, the epochs' nested clusters and readings, the claims' outputs."
unified_report(U) = (network = U.net, identity = U.ident, epochs = U.epochs, claims = U.claims, interaction = U.gov_inter, econ_inputs = U.claims.econ_inputs)
