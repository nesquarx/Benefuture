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
    stealth::Bool              # colluders defect only where the outcome will not become apparent (M6; world)
    diversity::Bool            # keep the option not chosen available to locales (L158; the axiom)
    novelty_bonus::Float64     # subsidy to a locale choosing the alternative, in outcome units (L158; governed)
    trial_units::Int           # locales a decision applies to (world)
    local_σ::Float64           # noise in a locale's own reading of the options (world)
    conviction::Float64        # how strongly a locale's reading must oppose the decision before it departs (world)
    outcome_σ::Float64         # noise in a locale's measured outcome (world)
    trial_z::Float64           # standard errors that settle a split trial (governed)
    ability_spread::Float64    # scatter of persons' noise ceilings around the expertise trend (8.31; world)
    fork_copies::Int           # copies each colluder forks into, voting alike (M6; world)
    fork_rule::Symbol          # :divided (forks share the social power, base vote included) or :per_identity ([OPEN])
end

function M5Params(m3, domains; base::Real = 1.0, expertise_weight::Real = 5.0, impact_weight::Real = 1.0,
                  optional_below::Real = 0.0, decisions::Integer = 200, signal_σ::Real = 1.0, skill_gain::Real = 5.0,
                  p_delegate::Real = 0.0, cap::Real = 0.05, impact_threshold::Real = 0.5,
                  relative_expertise::Bool = true, colluders = Int[], p_apparent::Real = 0.7, vote_value::Real = 0.5,
                  audit_window::Integer = 20, audit_threshold::Real = 0.6, stealth::Bool = false,
                  diversity::Bool = true, novelty_bonus::Real = 0.5, trial_units::Integer = 50, local_σ::Real = 1.0, conviction::Real = 1.5,
                  outcome_σ::Real = 1.0, trial_z::Real = 2.0, ability_spread::Real = 0.5,
                  reputation = nothing, fork_copies::Integer = 0, fork_rule::Symbol = :divided)
    domains = collect(Int, domains)
    check(!isempty(domains) && all(d -> 1 <= d <= size(m3.relevance_leaf, 2), domains), "domains must be leaves of the run")
    check(decisions >= 1 && 0 <= p_delegate <= 1 && 0 < cap <= 1, "decisions positive, delegation chance in [0, 1], cap in (0, 1]")
    check(all(x -> isfinite(x) && x >= 0, (base, expertise_weight, impact_weight, optional_below, signal_σ, skill_gain, impact_threshold)),
          "weights and noise non-negative")
    agents = m3.agents
    check(all(c -> 1 <= c <= length(agents), colluders), "colluders are agents of the run")
    check(0 <= p_apparent <= 1 && isfinite(vote_value) && vote_value >= 0 && audit_window >= 0 && 0 <= audit_threshold <= 1,
          "chance and audit threshold in [0, 1], vote value and window non-negative")
    check(isfinite(novelty_bonus) && novelty_bonus >= 0 && trial_units >= 1 && all(x -> isfinite(x) && x >= 0, (local_σ, conviction, outcome_σ, trial_z, ability_spread)),
          "novelty bonus, noises and z non-negative, units positive")
    skills = [a.skills[d] for a in agents, d in 1:size(m3.relevance_leaf, 2)]
    focus = [a.focus[d] for a in agents, d in 1:size(m3.relevance_leaf, 2)]
    reputation === nothing || check(size(reputation) == size(m3.relevance_leaf), "one reputation per agent and domain")
    check(fork_copies >= 0 && fork_rule in (:divided, :per_identity), "fork copies non-negative; rule :divided or :per_identity")
    M5Params(Float64.(reputation === nothing ? m3.relevance_leaf : reputation), skills, focus, domains, base, expertise_weight, impact_weight, optional_below,
             decisions, signal_σ, skill_gain, p_delegate, cap, impact_threshold, relative_expertise, collect(Int, colluders),
             p_apparent, vote_value, audit_window, audit_threshold, stealth,
             diversity, novelty_bonus, trial_units, local_σ, conviction, outcome_σ, trial_z, ability_spread,
             fork_copies, fork_rule)
end

"""
    run_m5(p; seed) -> NamedTuple

Decide `p.decisions` times. Returns the share decided correctly (`correct`) and, per decision, the
largest share of total weight one voter held (`max_share`) and the largest single weight
(`max_single`), both as shares of the total.
"""
function run_m5(p::M5Params; seed)
    rng = Xoshiro(seed)
    trng = Xoshiro(hash((seed, :split_trial)))  # its own stream: diversity changes no other draw
    # Imperfect agents (8.31): each voter's noise ceiling per domain, inverse to its skill there on
    # average; each locale's ceiling; choices draw noise on their own stream.
    arng, crng = Xoshiro(hash((seed, :ability))), Xoshiro(hash((seed, :choice)))
    caps = ability_caps(arng, max.(p.skills, 0.0); base = p.signal_σ, gain = p.skill_gain, spread = p.ability_spread)
    local_caps = vec(ability_caps(arng, zeros(p.trial_units, 1); base = p.local_σ, gain = 0.0, spread = p.ability_spread))
    correct_trace = Bool[]
    welfare, novelty_paid, chosen_share = 0.0, 0.0, Float64[]
    share_when_right, share_when_wrong = Float64[], Float64[]
    na = size(p.skills, 1)
    correct, max_share, max_single, bloc_expertise = 0, Float64[], Float64[], Float64[]
    tally_apparent, tally_hidden = [0, 0], [0, 0]  # (correct, decided)
    after_all, after_hidden = 0, 0  # correct once a split trial's winner is adopted
    # Votes are outputs (author ruling 8.29): reputation moves with each apparent decision, and
    # each agent's recent apparent votes per domain are its audited record (L114).
    reputation = copy(p.reputation)
    scale = [sum(max.(p.reputation[:, k], 0.0)) / size(p.reputation, 1) for k in axes(p.reputation, 2)]
    record = [Bool[] for _ in 1:na, _ in axes(p.reputation, 2)]
    audited_out(j, k) = p.audit_window > 0 && length(record[j, k]) >= 3 && mean(record[j, k]) < p.audit_threshold
    for _ in 1:p.decisions
        k = p.domains[rand(rng, 1:length(p.domains))]
        truth = randn(rng)
        apparent = rand(rng) < p.p_apparent  # drawn now, revealed after the decision
        rep = max.(reputation[:, k], 0.0)
        expertise = p.relative_expertise ? relative_reputation(rep) : rep
        w = [voting_weight(p.base, p.expertise_weight, [1.0], [expertise[i]], p.impact_weight, p.focus[i, k];
                           optional_below = p.optional_below)[1] for i in 1:na]
        # Forks (L122): with a base vote per identity, each copy adds its base and impact weight and
        # votes with its origin; divided, the family holds the origin's single share.
        if p.fork_rule == :per_identity && p.fork_copies > 0
            for i in p.colluders
                w[i] += p.fork_copies * voting_weight(p.base, p.expertise_weight, [1.0], [0.0], p.impact_weight, p.focus[i, k];
                                                      optional_below = p.optional_below)[1]
            end
        end
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
        signal = [truth + choice_noise(crng, caps[i, k]) for i in 1:na]
        defect = !(p.stealth && apparent)  # a stealthy bloc defects only where it will not be seen
        vote(i) = (i in p.colluders && defect) ? 1.0 : sign(signal[i])  # a bloc votes its side, not its signal
        tally = sum(held[i] * vote(i) for i in 1:na if !delegated[i])
        correct += sign(tally) == sign(truth)
        push!(correct_trace, sign(tally) == sign(truth))
        t = apparent ? tally_apparent : tally_hidden
        t[1] += sign(tally) == sign(truth); t[2] += 1
        # Diversity: a share of locales tries the option not chosen; when the split trial settles
        # the comparison, the decision's optimality becomes apparent, which no one foresaw.
        decided = sign(tally) == 0 ? 1.0 : sign(tally)
        # Diversity (L158): the option not chosen stays available, subsidised by a novelty bonus.
        # Each locale knows the decision and reads the options for itself; it departs when its own
        # reading opposes the decision by more than its conviction margin, which the bonus lowers.
        # No one is assigned to the alternative.
        share = 0.0
        if p.diversity
            reading = [truth + choice_noise(crng, local_caps[u]) for u in 1:p.trial_units]
            share = count(r -> decided * r < p.novelty_bonus - p.conviction, reading) / p.trial_units
            novelty_paid += p.novelty_bonus * share * p.trial_units
            push!(chosen_share, share)
            push!(decided == sign(truth) ? share_when_right : share_when_wrong, share)
        end
        # Welfare: the locales trying the alternative bear its outcome.
        welfare += (1 - share) * (decided == sign(truth)) + share * (decided != sign(truth))
        revealed = apparent
        if p.diversity
            trial = split_trial(trng, [decided * truth, -decided * truth], [1 - share, share];
                                units = p.trial_units, σ = p.outcome_σ, z = p.trial_z)
            revealed |= trial.significant
            # The alternative proved better where it was tried: it is adopted (the stochastic escape).
            trial.winner == 2 && (decided = -decided)
        end
        after_all += decided == sign(truth)
        apparent || (after_hidden += decided == sign(truth))
        push!(max_share, maximum(held) / total); push!(max_single, maximum(w) / total)
        isempty(p.colluders) || push!(bloc_expertise, sum(relative_reputation(rep)[p.colluders]))
        # Afterwards, the decision's optimality may become apparent: each vote is then credited or
        # debited by the weight it cast, and enters its voter's audited record.
        if revealed
            for i in 1:na
                delegated[i] && continue
                right = vote(i) == sign(truth)
                reputation[i, k] += (right ? 1 : -1) * p.vote_value * scale[k] * na * held[i] / total
                push!(record[i, k], right)
                length(record[i, k]) > max(p.audit_window, 1) && popfirst!(record[i, k])
            end
        end
    end
    (correct = correct / p.decisions, max_share = max_share, max_single = max_single, bloc_expertise = bloc_expertise,
     correct_apparent = tally_apparent[1] / max(tally_apparent[2], 1), correct_hidden = tally_hidden[1] / max(tally_hidden[2], 1),
     welfare = welfare / p.decisions, correct_after = after_all / p.decisions, novelty_paid = novelty_paid,
     chosen_share = chosen_share, correct_trace = correct_trace, share_when_right = share_when_right, share_when_wrong = share_when_wrong,
     correct_after_hidden = after_hidden / max(tally_hidden[2], 1))
end
