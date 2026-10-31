# Toy model M3: M2 with domains.
#
# World (this file): D leaf domains. An agent has a skill in each domain and works under a fixed
# domain profile (its focus); its plans' mean effect is the focus-weighted skill. Payment (escrow
# upfront plus settlement) is attributed to the agent's per-domain currency balances by the
# profile; measured contribution is attributed to its per-domain reputation: history (hPos, hNeg,
# never decaying) and relevance (gains decaying at λpos, losses at λneg). Nothing crosses between
# domains. With one domain M3 reproduces M2. Rules (Lean): everything in M2, plus profile
# validity, attribution and the decay rate by sign. The agent is the plan's sole contributor
# (causal contribution 1); several contributors per plan come later.

"An agent with a skill per domain, a domain profile it works under, and execution noise."
struct DomainAgent
    skills::Vector{Float64}
    focus::Vector{Float64}
    sloppiness::Float64
    function DomainAgent(skills, focus, sloppiness::Real)
        check(length(skills) == length(focus), "one skill per domain of the profile")
        check(all(isfinite, skills), "skills must be finite")
        check(profile_valid(focus), "focus must be a partition of unity")
        check(isfinite(sloppiness) && sloppiness >= 0, "sloppiness must be non-negative")
        new(Float64.(skills), Float64.(focus), sloppiness)
    end
end
# Without a stated execution noise an agent carries a plan out as individuals do (the intention-behaviour gap; calibrated default).
DomainAgent(skills, focus) = DomainAgent(skills, focus, SLOPPINESS)

Base.:(==)(a::DomainAgent, b::DomainAgent) = a.skills == b.skills && a.focus == b.focus && a.sloppiness == b.sloppiness
Base.hash(a::DomainAgent, h::UInt) = hash((a.skills, a.focus, a.sloppiness), h)

"M3 parameters: the M1 world, the agents, and relevance decay rates for gains and losses."
struct M3Params
    world::M1Params
    agents::Vector{DomainAgent}
    λpos::Float64
    λneg::Float64
    function M3Params(world::M1Params, agents, λpos::Real, λneg::Real)
        check(!isempty(agents), "there must be at least one agent")
        check(allequal(length(a.skills) for a in agents), "all agents must share the same domains")
        check(all(isfinite, (λpos, λneg)) && λpos >= 0 && λneg >= 0, "decay rates must be non-negative")
        # Mistakes decay slower than wins (author ruling 8.29); equal rates only as the reduction to M2.
        check(λneg <= λpos, "losses must decay no faster than gains")
        new(world, collect(DomainAgent, agents), λpos, λneg)
    end
end

ndomains(p::M3Params) = length(p.agents[1].skills)

"Split a signed amount over a profile: attribute its positive or negative part, per domain."
function split_signed(focus, amount)
    pos, neg = attribute(focus, 1.0, max(amount, 0.0), max(-amount, 0.0))
    pos .- neg, pos, neg
end

"""
    run_m3(p; seed) -> NamedTuple

Run M3. Matrices are agents × domains: `h_pos`, `h_neg`, `relevance`, `balance`; `paid` and
`measured` are per-agent totals.
"""
function run_m3(p::M3Params; seed)
    w, t = p.world, p.world.toy
    rng, mrng = Xoshiro(seed), Xoshiro(hash((seed, :measurement)))
    s = toy_state(t, rng)
    k, na, nd = length(w.models), length(p.agents), ndomains(p)
    history = [Float64[] for _ in 1:k]
    rolling() = [isempty(h) ? 0.0 : mean(@view h[max(1, end - w.window + 1):end]) for h in history]
    adopted = mm_adopt(rolling())
    rate_gain, rate_loss = decay_rate_for(1.0; λpos = p.λpos, λneg = p.λneg), decay_rate_for(-1.0; λpos = p.λpos, λneg = p.λneg)
    rel_gain, rel_loss = zeros(na, nd), zeros(na, nd)
    tr = (floor_u = Float64[], floor_h = Float64[], chosen_agent = Int[],
          h_pos = zeros(na, nd), h_neg = zeros(na, nd), relevance = zeros(na, nd), balance = zeros(na, nd),
          paid = zeros(na), measured = zeros(na), upfronts = Float64[], settlements = Float64[])
    record!() = (push!(tr.floor_u, floor_quantile(s.u, t.q)); push!(tr.floor_h, floor_quantile(s.h, t.q)))
    record!()
    obs = ToyState(observe(mrng, s.u, w.marker_σ), observe(mrng, s.h, w.marker_σ))
    for _ in 1:t.steps
        proposers = rand(rng, 1:na, t.plans)
        plans = [plan_with_mean(rng, sum(p.agents[a].focus .* p.agents[a].skills), t) for a in proposers]
        preds = [[predict(mrng, m, plan) for plan in plans] for m in w.models]
        i = choose(obs, preds[adopted], t)
        rel_gain .= reputation_decay.(rel_gain, 1.0; rate = rate_gain)
        rel_loss .= reputation_decay.(rel_loss, 1.0; rate = rate_loss)
        if i == 1
            push!(tr.chosen_agent, 0)
        else
            a, plan, pred = proposers[i - 1], plans[i - 1], preds[adopted][i - 1]
            agent = p.agents[a]
            push!(tr.chosen_agent, a)
            confidence = accuracy(rolling()[adopted])
            upfront, _ = escrow_split(plan_value(pred, t), confidence)
            done = carried_out(rng, agent.sloppiness, plan)
            seen = observed_plan(mrng, done, w.marker_σ)
            measured = plan_value(seen, t)
            settled = settlement(measured, upfront)
            push!(tr.upfronts, upfront); push!(tr.settlements, settled)
            net_pay, _, _ = split_signed(agent.focus, upfront + settled)
            tr.balance[a, :] .+= net_pay
            tr.paid[a] += upfront + settled
            net, pos, neg = split_signed(agent.focus, measured)
            tr.h_pos[a, :] .+= pos
            tr.h_neg[a, :] .+= neg
            (measured >= 0 ? rel_gain : rel_loss)[a, :] .+= net
            tr.measured[a] += measured
            mask = touched(plan)
            realised = [seen.du[mask]; seen.dh[mask]]
            for j in 1:k
                pj = preds[j][i - 1]
                push!(history[j], mm_score([pj.du[mask]; pj.dh[mask]], realised))
            end
            s.u .+= done.du
            s.h .+= done.dh
        end
        adopted = mm_adopt(rolling())
        obs = ToyState(observe(mrng, s.u, w.marker_σ), observe(mrng, s.h, w.marker_σ))
        record!()
    end
    tr.relevance .= rel_gain .+ rel_loss
    tr
end
