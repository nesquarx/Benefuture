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
    # Adversarial adaptation (AdvAp, L160; 8.38): the manufactured prisoner's dilemma.
    advap::Bool                # bloc members may reveal the bloc for a reward
    p_weigh::Float64           # chance a member weighs revealing after a hidden defection (world)
    collusion_gain::Float64    # what one hidden defection gains each member (world)
    loyalty::Float64           # what revealing costs a member in its own eyes (world)
    adv_share::Float64         # the reward's share of the harm a revelation prevents (governed)
    adv_floor::Float64         # least reward (governed)
    audit_cost::Float64        # cost of examining a revelation (world)
    p_trace::Float64           # chance the examination establishes the collusion (world)
    # Clean deliberation (Government; 8.42.2): sources weighed by their audited records.
    deliberation::Bool         # voters hear contacts and models before voting
    n_contacts::Int            # persons each voter hears (world: a social network)
    model_σ0::Float64          # the bootstrap model's noise in each domain (world)
    p_new_model::Float64       # chance per decision a new model arrives in its domain (world assumption)
    improve_drift::Float64     # its noise relative to the best model's, on average, in logs (world assumption)
    improve_σ::Float64         # scatter of that (world assumption)
    scale_min::Float64         # no model is perfect: least noise relative to the bootstrap model's (world; 8.33)
    model_capture::Any         # nothing, or (decision, duration, domain): the best model there publishes one side (world event)
    record_λpos::Float64       # decay of a source's rights in the rolling net its weight reads (governed; L101)
    record_λneg::Float64       # and of its wrongs, no faster (8.29)
    p_novel::Float64           # chance a source with a weaker record brings input novel to the listener (world; 8.44)
    info_handling::Bool        # the social network surfaces the domain's most reputable sources (L133 IH; 8.44)
end

function M5Params(m3, domains; base::Real = 1.0, expertise_weight::Real = 5.0, impact_weight::Real = 1.0,
                  optional_below::Real = 0.0, decisions::Integer = 200, signal_σ::Real = 1.0, skill_gain::Real = 5.0,
                  p_delegate::Real = 0.0, cap::Real = 0.05, impact_threshold::Real = 0.5,
                  relative_expertise::Bool = true, colluders = Int[], p_apparent::Real = 0.7, vote_value::Real = 0.5,
                  audit_window::Integer = 20, audit_threshold::Real = 0.6, stealth::Bool = false,
                  diversity::Bool = true, novelty_bonus::Real = 0.5, trial_units::Integer = 50, local_σ::Real = 1.0, conviction::Real = 1.5,
                  outcome_σ::Real = 1.0, trial_z::Real = 2.0, ability_spread::Real = 0.5,
                  reputation = nothing, fork_copies::Integer = 0, fork_rule::Symbol = :divided,
                  advap::Bool = false, p_weigh::Real = 0.05, collusion_gain::Real = 1.0, loyalty::Real = 0.0,
                  adv_share::Real = 0.1, adv_floor::Real = 1.0, audit_cost::Real = 1.0, p_trace::Real = 0.5,
                  deliberation::Bool = false, n_contacts::Integer = 5, model_σ0::Real = 5.0, p_new_model::Real = 0.0,
                  improve_drift::Real = -0.1, improve_σ::Real = 0.3, scale_min::Real = 0.1, model_capture = nothing,
                  record_λpos::Real = 0.05, record_λneg::Real = 0.02, p_novel::Real = 0.05, info_handling::Bool = true)
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
    check(0 <= p_weigh <= 1 && 0 <= p_trace <= 1, "chances in [0, 1]")
    check(n_contacts >= 0 && isfinite(model_σ0) && model_σ0 > 0 && 0 <= p_new_model <= 1 && isfinite(improve_drift) &&
          isfinite(improve_σ) && improve_σ >= 0 && 0 < scale_min <= 1, "contacts non-negative, model noise positive, chance in [0, 1], least scale in (0, 1]")
    check(0 <= record_λneg <= record_λpos && isfinite(record_λpos), "record decay: wrongs no faster than rights (8.29)")
    check(0 <= p_novel <= 1, "novel-input chance in [0, 1]")
    check(model_capture === nothing || (model_capture.decision >= 1 && model_capture.duration >= 1 && model_capture.domain in domains),
          "a model capture names a decision, a duration and a domain decided in")
    check(all(x -> isfinite(x) && x >= 0, (collusion_gain, loyalty, adv_share, adv_floor, audit_cost)),
          "gain, loyalty, share, floor and audit cost non-negative")
    M5Params(Float64.(reputation === nothing ? m3.relevance_leaf : reputation), skills, focus, domains, base, expertise_weight, impact_weight, optional_below,
             decisions, signal_σ, skill_gain, p_delegate, cap, impact_threshold, relative_expertise, collect(Int, colluders),
             p_apparent, vote_value, audit_window, audit_threshold, stealth,
             diversity, novelty_bonus, trial_units, local_σ, conviction, outcome_σ, trial_z, ability_spread,
             fork_copies, fork_rule, advap, p_weigh, collusion_gain, loyalty, adv_share, adv_floor, audit_cost, p_trace,
             deliberation, n_contacts, model_σ0, p_new_model, improve_drift, improve_σ, scale_min, model_capture,
             record_λpos, record_λneg, p_novel, info_handling)
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
    # Votes are outputs (author ruling 8.29): reputation moves with each apparent decision, and
    # each agent's recent apparent votes per domain are its audited record (L114).
    reputation = copy(p.reputation)
    scale = [sum(max.(p.reputation[:, k], 0.0)) / size(p.reputation, 1) for k in axes(p.reputation, 2)]
    record = [Bool[] for _ in 1:na, _ in axes(p.reputation, 2)]
    audited_out(j, k) = p.audit_window > 0 && length(record[j, k]) >= 3 && mean(record[j, k]) < p.audit_threshold
    # AdvAp: hidden decisions the bloc falsified since the last revelation, kept for repair, and
    # whether each decision ends right (a repaired decision may change).
    vrng = Xoshiro(hash((seed, :advap)))
    falsified = NamedTuple{(:n, :k, :truth, :held, :votes, :delegated, :total),Tuple{Int,Int,Float64,Vector{Float64},Vector{Float64},BitVector,Float64}}[]
    right_now, hidden_flag = Bool[], Bool[]
    adv = (established = Ref(0), rewards = Ref(0.0), liability = Ref(0.0), gain_forgone = Ref(0.0), recounted = Ref(0))
    function record_vote!(i, k, right, held_i, total)
        reputation[i, k] += (right ? 1 : -1) * p.vote_value * scale[k] * na * held_i / total
        push!(record[i, k], right)
        length(record[i, k]) > max(p.audit_window, 1) && popfirst!(record[i, k])
    end
    # Clean deliberation: each voter's contacts (a fixed social network), each domain's models, and
    # every source's full record of published readings on apparent decisions (right, total).
    nrng = Xoshiro(hash((seed, :deliberation)))
    contacts = [p.deliberation ? [j for j in randperm(nrng, na)[1:min(p.n_contacts + 1, na)] if j != i][1:min(p.n_contacts, na - 1)] : Int[] for i in 1:na]
    nd = size(p.reputation, 2)
    mods = [[(id = k, σ = p.model_σ0, rec = [0.0, 0.0])] for k in 1:nd]
    person_rec = [[0.0, 0.0] for _ in 1:na, _ in 1:nd]
    # The weight of a source reads the rolling net of its record (rights and wrongs, decayed, mistakes
    # slower than wins: L101, 8.29; the entries themselves are kept whole): log-odds of its accuracy,
    # smoothed (Nitzan and Paroush, 1982); a source no better than chance carries none.
    rate_right, rate_wrong = decay_rate_for(1.0; λpos = p.record_λpos, λneg = p.record_λneg), decay_rate_for(-1.0; λpos = p.record_λpos, λneg = p.record_λneg)
    lo(r) = (q = (r[1] + 1) / (r[1] + r[2] + 2); max(0.0, log(q / (1 - q))))
    function note!(r, right)
        r[1] = reputation_decay(r[1], 1.0; rate = rate_right) + right
        r[2] = reputation_decay(r[2], 1.0; rate = rate_wrong) + !right
    end
    model_weight, cap_trace, cap_id = Float64[], Float64[], Ref(0)
    own_pub = zeros(na)
    for n in 1:p.decisions
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
        if p.deliberation
            # Better models arrive (an assumption, 8.42.2); the best model of a captured domain
            # publishes one side while captured.
            if p.p_new_model > 0 && rand(nrng) < p.p_new_model
                best = minimum(m.σ for m in mods[k])
                push!(mods[k], (id = 1000 * k + length(mods[k]) + n, σ = max(p.scale_min * p.model_σ0, best * exp(p.improve_drift + p.improve_σ * randn(nrng))), rec = [0.0, 0.0]))
                length(mods[k]) > 4 && deleteat!(mods[k], argmin([lo(m.rec) + (m.σ == best ? Inf : 0.0) for m in mods[k]]))
            end
            mc = p.model_capture
            live_cap = mc !== nothing && k == mc.domain && mc.decision <= n < mc.decision + mc.duration
            if mc !== nothing && n == mc.decision
                cap_id[] = mods[mc.domain][argmax([lo(m.rec) for m in mods[mc.domain]])].id
            end
            published = [(live_cap && m.id == cap_id[]) ? 1.0 : sign(truth + m.σ * randn(nrng)) for m in mods[k]]
            pub(j) = (j in p.colluders && defect) ? 1.0 : sign(signal[j])  # what a person publishes
            wm0 = [lo(m.rec) for m in mods[k]]
            ranked = sortperm(reputation[:, k]; rev = true)
            reading = zeros(na); wsum, wmod = 0.0, 0.0
            for i in 1:na
                # Understanding trickles down and across (8.44): a voter weighs a source only if its
                # record is at least as good as the voter's own, or, rarely, for novel input.
                mine = lo(person_rec[i, k])
                heard(w) = (w >= mine || rand(nrng) < p.p_novel) ? w : 0.0
                own = max(mine, 0.1)  # one's own reading counts, at least a little
                # The social network's information handling (L133 IH: SourceVerify by Re(Dn))
                # surfaces the domain's most reputable sources; without it, a voter hears its contacts.
                srcs = p.info_handling ? [j for j in ranked if j != i][1:min(p.n_contacts, na - 1)] : contacts[i]
                wc = [heard(lo(person_rec[j, k])) for j in srcs]
                wm = heard.(wm0)
                reading[i] = own * sign(signal[i]) + sum(wc .* pub.(srcs); init = 0.0) + sum(wm .* published)
                wsum += own + sum(wc) + sum(wm); wmod += sum(wm)
            end
            wm = wm0
            push!(model_weight, wsum > 0 ? wmod / wsum : 0.0)
            if mc !== nothing && cap_id[] > 0 && k == mc.domain  # the captured model's share of the models' weight (0 once dropped)
                c = findfirst(m -> m.id == cap_id[], mods[k])
                push!(cap_trace, c === nothing ? 0.0 : wm[c] / max(sum(wm), 1e-12))
            end
            own_pub = pub.(1:na)
            signal = reading
        end
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
        push!(right_now, decided == sign(truth)); push!(hidden_flag, !apparent)
        push!(max_share, maximum(held) / total); push!(max_single, maximum(w) / total)
        isempty(p.colluders) || push!(bloc_expertise, sum(relative_reputation(rep)[p.colluders]))
        # Afterwards, the decision's optimality may become apparent: each vote is then credited or
        # debited by the weight it cast, and enters its voter's audited record.
        if revealed
            for i in 1:na
                delegated[i] && continue
                record_vote!(i, k, vote(i) == sign(truth), held[i], total)
            end
            if p.deliberation
                for i in 1:na  # source tracking: what each person published, its own reading
                    note!(person_rec[i, k], own_pub[i] == sign(truth))
                end
                for (m, x) in zip(mods[k], published)
                    note!(m.rec, x == sign(truth))
                end
            end
        end
        # AdvAp (L160): where the bloc defected unseen, each member may weigh revealing it. The
        # reward exceeds its share of the bloc's gain (`advap_reward_ref`); it reveals when the
        # reward beats that share and its loyalty, by its own noisy judgement (8.31). Established
        # (`p_trace`), the revelation is repaired in full: the bloc's votes are struck from every
        # falsified decision since the last revelation and each decision recounted; each falsified
        # vote is debited as wrong, except the revealer's; the rest of the bloc is charged.
        if p.advap && !isempty(p.colluders) && defect && !revealed
            push!(falsified, (n = n, k = k, truth = truth, held = copy(held), votes = [vote(i) for i in 1:na],
                              delegated = copy(delegated), total = total))
            for i in p.colluders
                rand(vrng) < p.p_weigh || continue
                gain = p.collusion_gain * length(falsified)
                reward = advap_reward(gain, gain * length(p.colluders); share = p.adv_share, floor = p.adv_floor)
                reward - gain - p.loyalty + choice_noise(vrng, caps[i, k]) > 0 || continue
                rand(vrng) < p.p_trace || break  # examined, not established: the bloc carries on
                adv.established[] += 1
                adv.rewards[] += reward; adv.gain_forgone[] += gain
                adv.liability[] += advap_liability(reward; audit_cost = p.audit_cost)
                for d in falsified
                    honest = sum(d.held[j] * d.votes[j] for j in 1:na if !d.delegated[j] && !(j in p.colluders); init = 0.0)
                    fixed = (honest == 0 ? 1.0 : sign(honest)) == sign(d.truth)
                    adv.recounted[] += fixed != right_now[d.n]
                    right_now[d.n] = fixed
                    for j in p.colluders
                        (j == i || d.delegated[j]) && continue
                        record_vote!(j, d.k, false, d.held[j], d.total)
                    end
                end
                empty!(falsified)
                break
            end
        end
    end
    after_all, after_hidden = count(right_now), count(right_now .& hidden_flag)
    (correct = correct / p.decisions, max_share = max_share, max_single = max_single, bloc_expertise = bloc_expertise,
     correct_apparent = tally_apparent[1] / max(tally_apparent[2], 1), correct_hidden = tally_hidden[1] / max(tally_hidden[2], 1),
     welfare = welfare / p.decisions, correct_after = after_all / p.decisions, novelty_paid = novelty_paid,
     chosen_share = chosen_share, correct_trace = correct_trace, share_when_right = share_when_right, share_when_wrong = share_when_wrong,
     correct_after_hidden = after_hidden / max(tally_hidden[2], 1),
     advap_established = adv.established[], advap_rewards = adv.rewards[], advap_liability = adv.liability[],
     advap_gain_forgone = adv.gain_forgone[], advap_recounted = adv.recounted[], final_trace = right_now,
     model_weight = model_weight, best_model_σ = [minimum(m.σ for m in mods[k]) for k in 1:nd],
     captured_weight_start = isempty(cap_trace) ? NaN : mean(cap_trace[1:min(10, end)]),
     captured_weight_end = isempty(cap_trace) ? NaN : mean(cap_trace[max(1, end - 9):end]))
end
