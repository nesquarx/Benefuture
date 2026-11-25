# ---- Entry-point identity binding in the unified world (author rulings 8.72, 8.167c, 8.171 (3), 8.172 (3), 8.174 finding 3) ----
#
# Identities are bound at ports of entry with a preliminary confidence that rises through independent attestation (the rule is Lean:
# `identity_confidence_ref`, exported as `identity_confidence`): attestations from distinct clusters count most, a ring inside one cluster
# counts less for each earlier member, and the attester's own confidence weighs it, so confidence cannot be bootstrapped from nothing.
# An identity bound off an entry point is flagged and starts at zero. Participation amplifies attestation and never replaces it.
# Confidence then weights (a) the interaction counted toward clustering (the source's column of the attention matrix), (b) the ballot
# or source weight (withheld below the working confidence, the base vote of 8.72), (c) the currency ceiling above basic sustenance
# (8.172: a preliminary identity always has basic sustenance via pricing; the rest is earned through sophontic behaviour).
# Glue and measurement: the rule lives in Lean; this file is the world (who hears and attests whom, noise) and the weighting.
# Toy assumptions named: the layer measures ballot weight and currency ceiling but does not yet feed the adoption vote or the economy
# (newcomers and sybils have no ballots there); each attester vouches for a subject at most once, at a random step.

using Random, Statistics

"""
    IdentityParams

World: `newcomers` real people entering at a port of entry (`entry`, preliminary confidence `prelim`), `sybils` off-entry identities
(flagged, start 0), `contacts` members each newcomer hears and is heard by (`homophily` from its own community), per-step chance
`p_attest` that a contact vouches for a real newcomer, `p_dupe` that a real listener who hears a sybil is fooled into vouching
(honest people err, 8.33), `sybil_reach` of the members hear the sybils with `sybil_attention` of their attention, `newcomer_attention`
likewise for the newcomers; a sybil spreads its attention `sybil_ring` over fellow sybils (praising loudly) and the rest over
`sybil_targets` members across communities (a hub). `binding` false is the world before this rule: every identity counts in full.
Governed thresholds: `prelim`, `rate`, `disc`, `part_cap`, `part_half`, `work_conf`, `sustenance`. `member` is the confidence of bound members.
"""
Base.@kwdef struct IdentityParams
    newcomers::Int = 0
    sybils::Int = 0
    binding::Bool = false
    steps_per_epoch::Int = 10
    contacts::Int = 3
    homophily::Float64 = 0.85
    p_attest::Float64 = 0.15
    p_dupe::Float64 = 0.02
    sybil_reach::Float64 = 0.5
    sybil_attention::Float64 = 0.25
    newcomer_attention::Float64 = 0.1
    sybil_ring::Float64 = 0.5
    sybil_targets::Int = 12
    member::Float64 = 0.9
    prelim::Float64 = 0.2
    rate::Float64 = 0.5
    disc::Float64 = 0.5
    part_cap::Float64 = 0.5
    part_half::Float64 = 20.0
    work_conf::Float64 = 0.5
    sustenance::Float64 = 0.3
end

"The identity layer's state: who is who, who hears and vouches for whom, and the attestation logs (clusters and weights, in order)."
mutable struct IdentityLayer
    p::IdentityParams
    na::Int
    N::Int
    planted::Vector{Int}
    kind::Vector{Symbol}                       # :member, :newcomer, :sybil
    contacts::Vector{Vector{Int}}              # newcomers' contacts (members)
    hears_sybil::Vector{Int}                   # members who hear the sybils
    targets::Vector{Vector{Int}}               # per sybil, the members it addresses
    conf::Vector{Float64}
    flagged::Vector{Bool}
    log_cl::Vector{Vector{Float64}}
    log_w::Vector{Vector{Float64}}
    done::Set{Tuple{Int,Int}}                  # (attester, subject) already vouched
    step::Int
    rng::Xoshiro
    snapshots::Vector{NamedTuple}
end

function identity_setup(p::IdentityParams, net, communities::Integer; seed::Integer)
    check(p.newcomers >= 0 && p.sybils >= 0 && 0 <= p.rate < 1 && 0 <= p.disc <= 1 && 0 <= p.prelim < 1 && 0 < p.member < 1 && 0 <= p.part_cap < 1 &&
          p.part_half > 0 && 0 <= p.work_conf <= 1 && 0 <= p.sustenance <= 1 && 0 <= p.sybil_reach <= 1 && p.steps_per_epoch >= 1,
          "identity: counts non-negative, rate and part_cap in [0, 1), disc, shares and thresholds in [0, 1], part_half positive")
    na = net.n; N = na + p.newcomers + p.sybils
    rng = Xoshiro(hash((seed, :identity)))
    planted = vcat(net.planted, [1 + (i - 1) % communities for i in (na + 1):N])
    kind = vcat(fill(:member, na), fill(:newcomer, p.newcomers), fill(:sybil, p.sybils))
    contacts = map(1:p.newcomers) do k
        own = [j for j in 1:na if planted[j] == planted[na + k]]; other = [j for j in 1:na if planted[j] != planted[na + k]]
        chosen = Int[]
        while length(chosen) < min(p.contacts, na)
            pool = filter(j -> !(j in chosen), (rand(rng) < p.homophily && !isempty(own)) || isempty(other) ? own : other)
            isempty(pool) && (pool = filter(j -> !(j in chosen), 1:na))
            push!(chosen, rand(rng, pool))
        end
        chosen
    end
    hears = shuffle(rng, collect(1:na))[1:round(Int, p.sybil_reach * na)]
    targets = [shuffle(rng, collect(1:na))[1:min(na, p.sybil_targets)] for _ in 1:p.sybils]
    # without binding every identity counts in full (the world before this rule); with it members hold `member`, entrants `prelim`, off-entry 0
    conf = p.binding ? vcat(fill(p.member, na), fill(p.prelim, p.newcomers), zeros(p.sybils)) : ones(N)
    flagged = [k == :sybil for k in kind]
    IdentityLayer(p, na, N, planted, kind, contacts, hears, targets, conf, flagged, [Float64[] for _ in 1:N], [Float64[] for _ in 1:N],
                  Set{Tuple{Int,Int}}(), 0, rng, NamedTuple[])
end

"The attention matrix over all identities from the members' measured attention `Wr` (rows normalised): the members keep their own, give the newcomers and sybils they hear a share, and the new identities spread theirs."
function identity_attention(L::IdentityLayer, Wr::AbstractMatrix)
    p, na, N = L.p, L.na, L.N
    R = zeros(N, N); R[1:na, 1:na] .= Wr
    sy = (na + p.newcomers + 1):N; nc = (na + 1):(na + p.newcomers)
    hear_nc = [Int[] for _ in 1:na]
    for (k, cs) in enumerate(L.contacts), m in cs; push!(hear_nc[m], na + k); end
    for m in 1:na
        a_nc = isempty(hear_nc[m]) ? 0.0 : p.newcomer_attention; a_sy = (m in L.hears_sybil && p.sybils > 0) ? p.sybil_attention : 0.0
        R[m, 1:na] .*= (1 - a_nc - a_sy)
        for j in hear_nc[m]; R[m, j] += a_nc / length(hear_nc[m]); end
        for j in sy; R[m, j] += a_sy / p.sybils; end
    end
    for (k, cs) in enumerate(L.contacts), m in cs; R[na + k, m] += 1 / length(cs); end
    for (k, j) in enumerate(sy)
        for o in sy; o != j && (R[j, o] += p.sybil_ring / max(1, p.sybils - 1)); end
        for m in L.targets[k]; R[j, m] += (1 - p.sybil_ring) / length(L.targets[k]); end
    end
    R
end

"Weight the interaction by the source's identity confidence (a): what an unbound identity says carries what its confidence carries."
identity_weighted(L::IdentityLayer, R::AbstractMatrix) = L.p.binding ? R .* L.conf' : Matrix{Float64}(R)

"Ballot or source weight (b): the confidence once it reaches the working confidence, none below (the base vote waits for binding, 8.72); everyone counts in full without binding."
identity_vote_weight(L::IdentityLayer) = L.p.binding ? [c >= L.p.work_conf ? c : 0.0 for c in L.conf] : ones(L.N)

"Currency ceiling (c), as a share of full earning: basic sustenance for every identity (8.172), the rest in proportion to confidence."
identity_ceiling(L::IdentityLayer) = L.p.binding ? L.p.sustenance .+ (1 - L.p.sustenance) .* L.conf : ones(L.N)

"One step of vouching: each contact vouches for a real newcomer (`p_attest`), each member who hears the sybils may be fooled (`p_dupe`), sybils vouch for one another (the ring); once per attester and subject."
function identity_step!(L::IdentityLayer, labels::AbstractVector{<:Integer})
    p, na = L.p, L.na
    vouch!(a, s) = begin
        (a, s) in L.done && return
        push!(L.done, (a, s)); push!(L.log_cl[s], Float64(labels[a])); push!(L.log_w[s], clamp(L.conf[a], 0.0, 1.0))
    end
    for (k, cs) in enumerate(L.contacts), m in cs; rand(L.rng) < p.p_attest && vouch!(m, na + k); end
    sy = (na + p.newcomers + 1):L.N
    for m in L.hears_sybil, s in sy; rand(L.rng) < p.p_dupe && vouch!(m, s); end
    for s in sy, o in sy; o != s && vouch!(o, s); end
    L.step += 1
end

"Advance the layer one epoch from the members' measured attention `Wr`: vouch step by step (clusters re-read from the current weighted interaction), update every non-member's confidence by the Lean rule, and snapshot."
function identity_advance!(L::IdentityLayer, Wr::AbstractMatrix, ep::Integer)
    p = L.p
    if p.binding
        for _ in 1:p.steps_per_epoch
            Rw = identity_weighted(L, identity_attention(L, Wr)); h = cluster_hierarchy(Rw); labels = h.partitions[h.best]
            identity_step!(L, labels)
            for i in (L.na + 1):L.N
                start = L.flagged[i] ? 0.0 : p.prelim
                L.conf[i] = identity_confidence(start, L.log_cl[i], L.log_w[i]; rate = p.rate, disc = p.disc, participation = L.step,
                                                part_cap = p.part_cap, half = p.part_half)
            end
        end
    end
    R = identity_attention(L, Wr); Rw = identity_weighted(L, R)
    h = cluster_hierarchy(Rw); labels = h.partitions[h.best]
    sy = (L.na + p.newcomers + 1):L.N; nc = (L.na + 1):(L.na + p.newcomers); real = 1:(L.na + p.newcomers)
    vw = identity_vote_weight(L)
    push!(L.snapshots, (epoch = ep, conf = copy(L.conf), vote_weight = vw, ceiling = identity_ceiling(L), labels = labels,
                        sybil_attention = p.sybils == 0 ? 0.0 : sum(Rw[1:L.na, sy]) / max(sum(Rw[1:L.na, :]), eps()),
                        sybil_vote_share = p.sybils == 0 ? 0.0 : sum(vw[sy]) / max(sum(vw), eps()),
                        newcomer_conf = isempty(nc) ? NaN : mean(L.conf[nc]), sybil_conf = isempty(sy) ? NaN : mean(L.conf[sy]),
                        agreement = adjusted_rand_index(labels[real], L.planted[real])))
    L.snapshots[end]
end
