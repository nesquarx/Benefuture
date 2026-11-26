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
    economy::Bool = false        # phase C (a): the identity layer's newcomers and sybils are the economy's trailing agents (one to one), so the currency ceiling acts on their real balances
    fractal::Any = nothing       # phase C (b): a `FractalParams`; each epoch's cluster decisions run on that epoch's measured clusters, funded from the economy's commons
    draw_frac::Float64 = 0.5     # governed (phase C b): the share of the undrawn commons an epoch's fractal run may take as its root reserve
    decisions_per_epoch::Int = 6 # world (phase C b): the cluster decisions taken each epoch
    scoped::Bool = false         # phase D: each epoch's cluster decisions set the economy's scoped parameters (the status bar per domain; the finer scope wins)
    settle::Bool = false         # phase D: the fractal's reserves settle into the economy (level-1 balances to the members' purses, the rest back to the commons, mint and burn into the supply)
    bar_step::Float64 = 0.05     # governed (phase D): how far a decided "raise" lifts a domain's status bar above the economy's own (the bar only rises, 8.84; "hold" leaves it)
    fractal_truth::Union{Nothing,Vector{Int}} = nothing   # world (tests): the right option (+1 raise, -1 hold) per decision class, in place of the random draw (a planted heterogeneity)
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
    allow = ones(na); k_id = 0
    if up.economy
        up.identity === nothing && throw(ArgumentError("unified economy mapping needs the identity layer"))
        k_id = up.identity.newcomers + up.identity.sybils
        check(k_id < na && k_id > 0, "unified: newcomers + sybils are the economy's trailing agents, fewer than the agents")
        econ = _with_fields(econ, Dict{Symbol,Any}(:allowance => allow))   # the live vector the economy reads; updated at each epoch end
    end
    m3 = run_m3c(econ; seed = seed)   # the society the claims circulate in (reputations)
    ihp = IhWorldParams(; m3, econ, domains = up.domains, steps = n_epochs, claims_per_step = up.claims_per_epoch, ih = up.ih_flag,
                        network = net, rounds = up.rounds, liars_override = liars, run_economy = false, seed = seed, up.over...)
    cl = run_ih_world(ihp)
    (net = net, claims = cl, econ = _with_fields(econ, Dict{Symbol,Any}(:p_informed => cl.econ_inputs.p_informed, :p_side => cl.econ_inputs.p_side)),
     bloc = cl.bloc, gov_inter = zeros(na, na), epochs = NamedTuple[], n_epochs = n_epochs,
     ident = up.identity === nothing ? nothing :
             identity_setup(up.identity, up.economy ? (n = na - k_id, planted = net.planted[1:(na - k_id)]) : net, up.communities; seed = seed),
     economy = up.economy, allow = allow, nm = na - k_id, up = up, fractal = NamedTuple[], drawn = Ref(0.0), commons = Ref(0.0),
     bars = Ref(zeros(length(econ.known))), scope = Ref(Dict{Int,NamedTuple}()), pending = Ref{Any}(nothing))
end

"The governance's M5 parameters on the one network: its contacts, its colluders, its rumour exposure."
unified_gp(U, gp::M5Params) = _with_fields(gp, Dict{Symbol,Any}(:network => U.net.contacts, :defer_voter => U.claims.voter_defer,
                                                               :colluders => U.bloc, :tag_liars => U.bloc))

"Add what a governance M5 run heard (its `heard`) to the measured interaction."
function unified_hear!(U, heard)
    for i in eachindex(heard.sources), (j, w) in zip(heard.sources[i], heard.weights[i]); U.gov_inter[i, j] += w; end
end

"""
Beings linked to agents (phase C c): being `b` is served by agent `1 + (b - 1) % na` (a ring: every agent serves about the same number), so a
cluster of agents has the understanding and happiness of the beings its members serve.
"""
agent_of_being(b::Integer, na::Integer) = 1 + (b - 1) % na

"Per-agent readings of the economy's beings (mean understanding and happiness of the beings each agent serves), from a trace that carries them."
function being_readings(tr, na::Integer)
    hasproperty(tr, :being_u) || return nothing
    nb = length(tr.being_u); cnt = zeros(na); su = zeros(na); sh = zeros(na)
    for b in 1:nb; a = agent_of_being(b, na); cnt[a] += 1; su[a] += tr.being_u[b]; sh[a] += tr.being_h[b]; end
    (understanding = su ./ max.(cnt, 1), happiness = sh ./ max.(cnt, 1))
end

"Record epoch `ep`: clusters (nested) from the interaction measured so far, with per-cluster outcome readings (and, given the economy's trace `tr`, the beings' understanding and happiness)."
function unified_record!(U, ep::Integer, reputation::AbstractMatrix, tr = nothing)
    e = clamp(ep, 1, length(U.claims.interaction))
    W = attention_normalise(reduce(+, U.claims.interaction[1:e]) .+ U.gov_inter)
    # the identity layer (8.72): newcomers and sybils join the attention matrix, weighted by their confidence once binding is on
    nm = U.economy ? U.nm : U.net.n
    isnap = U.ident === nothing ? nothing : identity_advance!(U.ident, U.economy ? attention_normalise(W[1:nm, 1:nm]) : W, ep)
    isnap === nothing || (W = identity_weighted(U.ident, identity_attention(U.ident, U.economy ? attention_normalise(W[1:nm, 1:nm]) : W)))
    # phase C (a): the currency ceiling (8.172) acts on the economy agents' real accumulation allowance, relative to a bound member's
    # (so a member keeps its allowance as it is and an unbound identity falls to basic sustenance, never below it); the economy reads it live
    if U.economy && isnap !== nothing
        ref = identity_ceiling(U.ident)[1]
        U.allow .= clamp.(isnap.ceiling ./ ref, 0.0, 1.0)
    end
    h = cluster_hierarchy(W); lv = cluster_levels(h)
    na = U.net.n
    s = U.claims.voter_snapshots[e]
    readings = (led_astray = s.led_astray, accuracy = s.accuracy, rumour_deferral = U.claims.voter_defer, reputation = vec(mean(max.(reputation, 0.0); dims = 2)))
    br = tr === nothing ? nothing : being_readings(tr, na)
    br === nothing || (readings = merge(readings, br))
    push!(U.epochs, (epoch = ep, levels = lv, nested = levels_nested(lv), interaction = sum(reduce(+, U.claims.interaction[1:e]) .+ U.gov_inter),
                     agreement = adjusted_rand_index(lv[findfirst(l -> l.k == h.best, lv)].labels[1:na], U.net.planted),
                     readings = [(k = l.k, clusters = cluster_readings(l.labels[1:na], readings)) for l in lv], identity = isnap))
    tr !== nothing && U.up.fractal !== nothing && unified_fractal_epoch!(U, ep, tr)
end

"A member's vote weight is its own; an economy-mapped newcomer or sybil votes with the ballot weight of its identity confidence (none below the working confidence, 8.72)."
function unified_vote_scale(U, w::AbstractVector)
    (U.ident === nothing || !U.economy) && return w
    vw = identity_vote_weight(U.ident); out = copy(w)
    for i in (U.nm + 1):length(w); out[i] *= vw[i]; end
    out
end

"A sybil economy agent votes against the candidate's merit (as the identity layer's ballots do), any other agent as it reads."
unified_sybil(U, i::Integer) = U.economy && U.ident !== nothing && U.ident.kind[i] == :sybil

"""
Phase C (b): the epoch's fractal run. The nested clusters just measured decide `decisions_per_epoch` decisions (`run_fractal`), funded from the
economy's own commons: the root reserve is `draw_frac` of the commons not yet drawn (`sum(tr.reinvested)`, what overflow above the identity
ceiling and the accumulation allowance returned), so the clusters together never spend beyond what the economy put in the commons, and each
level's reserves are shares of its parent's (one currency). The tree's ledger is exact (`sum(balances) = reserve + minted - burnt`).
"""
function unified_fractal_epoch!(U, ep::Integer, tr)
    na = U.net.n; fp = U.up.fractal; up = U.up
    U.commons[] = sum(max.(tr.reinvested, 0.0))
    # settled draws leave the commons for real, so the draw is a share of what is there; unsettled draws are tracked (`drawn`) against it
    root = up.draw_frac * max(U.commons[] - (up.settle ? 0.0 : U.drawn[]), 0.0)
    labs = [l.labels[1:na] for l in U.epochs[end].levels]
    if root <= 0
        push!(U.fractal, (epoch = ep, reserve = 0.0, ledger_gap = 0.0, minted = 0.0, burnt = 0.0, decisions = 0, right_share = NaN, harm_peak = 0.0, drawn = up.settle ? 0.0 : U.drawn[], commons = U.commons[]))
        return
    end
    p = _with_fields(fp, Dict{Symbol,Any}(:reserve => root, :decisions => up.decisions_per_epoch))
    W = fractal_world(na, p; seed = ep)
    up.fractal_truth === nothing || (W = merge(W, (τ = copy(up.fractal_truth),)))
    r = run_fractal(labs, p; seed = ep, world = W)
    up.settle || (U.drawn[] += root)
    gap = sum(values(r.balances)) - (root + r.minted - r.burnt)
    rec = (epoch = ep, reserve = root, ledger_gap = gap, minted = r.minted, burnt = r.burnt, decisions = length(r.decisions), right_share = r.right_share,
           harm_peak = r.harm_peak, drawn = up.settle ? root : U.drawn[], commons = U.commons[], spent = sum(values(r.spent)), degraded = length(r.degraded))
    if up.scoped   # phase D (a): the decisions set the economy's scoped parameters; a finer scope wins, a coarser later decision sets only what is undecided
        U.scope[] = unified_scope(r.decisions, length(U.bars[]))
        U.bars[] = [haskey(U.scope[], d) && U.scope[][d].option == 1 ? up.bar_step : 0.0 for d in 1:length(U.bars[])]
        rec = merge(rec, (scope = copy(U.scope[]), bars = copy(U.bars[])))
    end
    if up.settle   # phase D (b): the clusters' reserves settle into the economy (the finest clusters' balances to their members' purses, every coarser reserve back to the commons)
        purses = zeros(na); back = 0.0
        for ((l, c), b) in r.balances
            if l == 1
                m = findall(==(c), r.levels[1]); purses[m] .+= b / length(m)
            else
                back += b
            end
        end
        U.pending[] = (purses = purses, commons = back - root, supply = r.minted - r.burnt)
        rec = merge(rec, (settled = sum(purses), returned = back, settle_gap = sum(purses) + back - (root + r.minted - r.burnt)))
    end
    push!(U.fractal, rec)
end

"""
The scope each domain's decision settled at (phase D): decisions in order, a decision for a domain replaces the held one only when its scope is as fine or finer
(level number as low or lower), so a coarser later decision sets only the undecided domains. Domains beyond `nd` have no economy parameter to set.
"""
function unified_scope(decisions, nd::Integer)
    scope = Dict{Int,NamedTuple}()
    for d in decisions
        d.class <= nd || continue
        cur = get(scope, d.class, nothing)
        (cur === nothing || d.level <= cur.level) && (scope[d.class] = (level = d.level, option = d.option, cluster = d.cluster))
    end
    scope
end

"What the governor hands the economy at an epoch boundary besides thresholds (phase D): the scoped status bars and the pending settlement (taken once)."
function unified_handover!(U)
    st = U.pending[]; U.pending[] = nothing
    (bars = U.up.scoped ? copy(U.bars[]) : nothing, settle = st)
end

"What the unified world reports: the network, the epochs' nested clusters and readings, the claims' outputs."
unified_report(U) = (network = U.net, identity = U.ident, allowance = copy(U.allow), fractal = U.fractal, epochs = U.epochs, claims = U.claims, interaction = U.gov_inter, econ_inputs = U.claims.econ_inputs)
