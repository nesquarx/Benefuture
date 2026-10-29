# Toy model M5: governance by weighted liquid democracy (L113 BfDm, L114 LqdBfDm).
#
# World (this file): decisions arise in the domains given; each has a right option, and each agent
# receives a signal of it with noise `signal_σ` × exp(−`skill_gain` × its skill there) (a toy
# assumption: skill sharpens judgement). Votes are weighted by L113 (base + expertise weight ×
# domain reputation + impact weight × impact), with reputations from an M3c run and impact the
# agent's focus on the domain. In random order, each agent with impact below `impact_threshold`
# (Th_b) delegates with chance `p_delegate` to the highest-reputation agent above it in the domain
# whose accumulated weight is still under `cap` × total weight (Th_k); delegates vote with all
# they hold. Reputations enter as shares of the domain's total (author ruling 8.22; the
# `relative_expertise` default). Rules (Lean): voting weight, capped delegation, relative reputation.

"M5 parameters: an M3c run (its agents and reputations), the domains decided in, and the rules' weights."
struct M5Params
    reputation::Matrix{Float64}   # agents × domains (leaf relevance from the M3c run)
    skills::Matrix{Float64}       # agents × domains
    focus::Matrix{Float64}        # agents × domains
    domains::Vector{Int}
    base::Float64
    expertise_weight::Float64
    impact_weight::Float64
    optional_below::Float64
    decisions::Int
    signal_σ::Float64
    skill_gain::Float64
    p_delegate::Float64
    cap::Float64
    impact_threshold::Float64
    relative_expertise::Bool   # expertise as shares of the domain's reputation (author ruling 8.22)
    colluders::Vector{Int}     # agents voting one fixed side whatever their signal (M6; world)
    p_apparent::Float64        # chance a decision's optimality becomes apparent afterwards (world)
    vote_value::Float64        # reputation a vote earns or costs, per share of weight cast, in units of the domain's (governed)
    audit_window::Int          # a delegate's recent apparent votes a delegator audits (L114; governed)
    audit_threshold::Float64   # share of them right below which delegations are retracted (L114; governed)
end

function M5Params(m3, domains; base::Real = 1.0, expertise_weight::Real = 5.0, impact_weight::Real = 1.0,
                  optional_below::Real = 0.0, decisions::Integer = 200, signal_σ::Real = 1.0, skill_gain::Real = 5.0,
                  p_delegate::Real = 0.0, cap::Real = 0.05, impact_threshold::Real = 0.5,
                  relative_expertise::Bool = true, colluders = Int[], p_apparent::Real = 0.7, vote_value::Real = 0.5,
                  audit_window::Integer = 20, audit_threshold::Real = 0.6)
    domains = collect(Int, domains)
    check(!isempty(domains) && all(d -> 1 <= d <= size(m3.relevance_leaf, 2), domains), "domains must be leaves of the run")
    check(decisions >= 1 && 0 <= p_delegate <= 1 && 0 < cap <= 1, "decisions positive, delegation chance in [0, 1], cap in (0, 1]")
    check(all(x -> isfinite(x) && x >= 0, (base, expertise_weight, impact_weight, optional_below, signal_σ, skill_gain, impact_threshold)),
          "weights and noise non-negative")
    agents = m3.agents
    check(all(c -> 1 <= c <= length(agents), colluders), "colluders are agents of the run")
    check(0 <= p_apparent <= 1 && isfinite(vote_value) && vote_value >= 0 && audit_window >= 0 && 0 <= audit_threshold <= 1,
          "chance and audit threshold in [0, 1], vote value and window non-negative")
    skills = [a.skills[d] for a in agents, d in 1:size(m3.relevance_leaf, 2)]
    focus = [a.focus[d] for a in agents, d in 1:size(m3.relevance_leaf, 2)]
    M5Params(Float64.(m3.relevance_leaf), skills, focus, domains, base, expertise_weight, impact_weight, optional_below,
             decisions, signal_σ, skill_gain, p_delegate, cap, impact_threshold, relative_expertise, collect(Int, colluders),
             p_apparent, vote_value, audit_window, audit_threshold)
end

"""
    run_m5(p; seed) -> NamedTuple

Decide `p.decisions` times. Returns the share decided correctly (`correct`) and, per decision, the
largest share of total weight one voter held (`max_share`) and the largest single weight
(`max_single`), both as shares of the total.
"""
function run_m5(p::M5Params; seed)
    rng = Xoshiro(seed)
    na = size(p.skills, 1)
    correct, max_share, max_single, bloc_expertise = 0, Float64[], Float64[], Float64[]
    # Votes are outputs (author ruling 8.29): reputation moves with each apparent decision, and
    # each agent's recent apparent votes per domain are its audited record (L114).
    reputation = copy(p.reputation)
    scale = [sum(max.(p.reputation[:, k], 0.0)) / size(p.reputation, 1) for k in axes(p.reputation, 2)]
    record = [Bool[] for _ in 1:na, _ in axes(p.reputation, 2)]
    audited_out(j, k) = p.audit_window > 0 && length(record[j, k]) >= 3 && mean(record[j, k]) < p.audit_threshold
    for _ in 1:p.decisions
        k = p.domains[rand(rng, 1:length(p.domains))]
        truth = randn(rng)
        rep = max.(reputation[:, k], 0.0)
        expertise = p.relative_expertise ? relative_reputation(rep) : rep
        w = [voting_weight(p.base, p.expertise_weight, [1.0], [expertise[i]], p.impact_weight, p.focus[i, k];
                           optional_below = p.optional_below)[1] for i in 1:na]
        total = sum(w)
        held = copy(w)
        delegated, received = falses(na), falses(na)
        for i in randperm(rng, na)
            (received[i] || p.focus[i, k] >= p.impact_threshold || rand(rng) >= p.p_delegate) && continue
            for j in sortperm(rep; rev = true)
                (j == i || delegated[j] || rep[j] <= rep[i] || audited_out(j, k)) && continue
                after = accumulate_capped(p.cap * total, held[j], [w[i]])
                if after > held[j]
                    held[j] = after; held[i] -= w[i]; delegated[i] = true; received[j] = true
                    break
                end
            end
        end
        signal = [truth + p.signal_σ * exp(-p.skill_gain * max(p.skills[i, k], 0.0)) * randn(rng) for i in 1:na]
        vote(i) = i in p.colluders ? 1.0 : sign(signal[i])  # a bloc votes its side, not its signal
        tally = sum(held[i] * vote(i) for i in 1:na if !delegated[i])
        correct += sign(tally) == sign(truth)
        push!(max_share, maximum(held) / total); push!(max_single, maximum(w) / total)
        isempty(p.colluders) || push!(bloc_expertise, sum(relative_reputation(rep)[p.colluders]))
        # Afterwards, the decision's optimality may become apparent: each vote is then credited or
        # debited by the weight it cast, and enters its voter's audited record.
        if rand(rng) < p.p_apparent
            for i in 1:na
                delegated[i] && continue
                right = vote(i) == sign(truth)
                reputation[i, k] += (right ? 1 : -1) * p.vote_value * scale[k] * na * held[i] / total
                push!(record[i, k], right)
                length(record[i, k]) > max(p.audit_window, 1) && popfirst!(record[i, k])
            end
        end
    end
    (correct = correct / p.decisions, max_share = max_share, max_single = max_single, bloc_expertise = bloc_expertise)
end
