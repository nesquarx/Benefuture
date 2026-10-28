# Toy model M3b: M3 with profiles measured rather than declared, prices, and balance overflow.
#
# World (this file): each of D domains has a causal signature (a unit vector). An agent's focus
# is only where it works: each plan works in one domain drawn from it, and its causal signature
# lies near that domain's (spread `spread`), or, with chance `novelty`, far from every domain (a
# new scenario). The plan's mean effect is the agent's skill in its domain (mean skill when new).
# Currency metric models measure the signature with noise `classify_σ` and assign the profile:
# domains within `threshold` share it by closeness; with no match it goes to StandCoin, the
# unspecialized currency (column D + 1), and is flagged for adjudication. The price in each
# currency is its share of resource cost less the escrow upfront (L86); a plan whose positive
# price an agent cannot pay from its balance in some currency leaves the menu, since nothing
# crosses between currencies. Payment, settlement and reputation follow the measured profile.
# After each step a balance above its accumulation threshold overflows into reinvestment in its
# domain (L100). Thresholds are approximate until governance sets them (M5). Rules (Lean):
# everything in M3, plus classification, transaction price, accumulation threshold and overflow.

"M3b parameters: M3's, plus classification, endowment, resource cost and overflow."
struct M3bParams
    world::M1Params
    agents::Vector{DomainAgent}
    λpos::Float64
    λneg::Float64
    novelty::Float64
    spread::Float64
    classify_σ::Float64
    threshold::Float64
    temperature::Float64
    endowment::Float64
    cost_per_touch::Float64
    overflow_base::Float64
    overflow_factor::Float64
end

function M3bParams(world::M1Params, agents; λpos::Real, λneg::Real, novelty::Real = 0.0, spread::Real = 0.1,
                   classify_σ::Real = 0.05, threshold::Real = 0.5, temperature::Real = 0.1, endowment::Real = 5.0,
                   cost_per_touch::Real = 0.01, overflow_base::Real = 50.0, overflow_factor::Real = 0.5)
    m3 = M3Params(world, agents, λpos, λneg)  # shared checks on agents and decay rates
    probability(novelty)
    check(all(x -> isfinite(x) && x >= 0, (spread, classify_σ, threshold, endowment, cost_per_touch, overflow_factor)),
          "spreads, threshold, endowment, cost and overflow factor must be non-negative")
    check(isfinite(temperature) && temperature > 0, "temperature must be positive")
    check(!isnan(overflow_base) && overflow_base >= 0, "overflow base must be non-negative")
    M3bParams(world, m3.agents, λpos, λneg, novelty, spread, classify_σ, threshold, temperature, endowment,
              cost_per_touch, overflow_base, overflow_factor)
end

ndomains(p::M3bParams) = length(p.agents[1].skills)

"A domain drawn from a focus (a partition of unity)."
pick(rng::AbstractRNG, focus) = something(findfirst(>=(rand(rng)), cumsum(focus)), length(focus))

"""
    run_m3b(p; seed) -> NamedTuple

Run M3b. Matrices are agents × currencies (D domains, then StandCoin). Per chosen plan: `costs`,
`domains` (true domain, 0 when new) and `classified` (largest share of the measured profile);
`flagged` lists the steps whose chosen plan went to StandCoin for adjudication.
"""
function run_m3b(p::M3bParams; seed)
    w, t = p.world, p.world.toy
    rng, mrng = Xoshiro(seed), Xoshiro(hash((seed, :measurement)))
    drng, crng = Xoshiro(hash((seed, :domain))), Xoshiro(hash((seed, :classification)))
    s = toy_state(t, rng)
    k, na, nd = length(w.models), length(p.agents), ndomains(p)
    nc = nd + 1
    signatures = [Float64.((1:nd) .== d) for d in 1:nd]
    novel = fill(-1 / sqrt(nd), nd)
    history = [Float64[] for _ in 1:k]
    rolling() = [isempty(h) ? 0.0 : mean(@view h[max(1, end - w.window + 1):end]) for h in history]
    adopted = mm_adopt(rolling())
    rate_gain, rate_loss = decay_rate_for(1.0; λpos = p.λpos, λneg = p.λneg), decay_rate_for(-1.0; λpos = p.λpos, λneg = p.λneg)
    rel_gain, rel_loss = zeros(na, nc), zeros(na, nc)
    tr = (floor_u = Float64[], floor_h = Float64[], chosen_agent = Int[],
          h_pos = zeros(na, nc), h_neg = zeros(na, nc), relevance = zeros(na, nc), balance = fill(p.endowment, na, nc),
          endowment = p.endowment, endowed = p.endowment * na * nc, paid = zeros(na), measured = zeros(na),
          costs = Float64[], domains = Int[], classified = Int[], flagged = Int[], reinvested = zeros(nc))
    record!() = (push!(tr.floor_u, floor_quantile(s.u, t.q)); push!(tr.floor_h, floor_quantile(s.h, t.q)))
    record!()
    obs = ToyState(observe(mrng, s.u, w.marker_σ), observe(mrng, s.h, w.marker_σ))
    for step in 1:t.steps
        proposers = rand(rng, 1:na, t.plans)
        doms = [rand(drng) < p.novelty ? 0 : pick(drng, p.agents[a].focus) for a in proposers]
        plans = [plan_with_mean(rng, d == 0 ? mean(p.agents[a].skills) : p.agents[a].skills[d], t) for (a, d) in zip(proposers, doms)]
        causal = [(d == 0 ? novel : signatures[d]) .+ p.spread .* randn(drng, nd) for d in doms]
        preds = [[predict(mrng, m, plan) for plan in plans] for m in w.models]
        confidence = 1 / (1 + sqrt(-rolling()[adopted]))
        profiles = map(causal) do c
            seen_c = c .+ p.classify_σ .* randn(crng, nd)
            classify([sqrt(sum(abs2, seen_c .- σ)) for σ in signatures]; threshold = p.threshold, temperature = p.temperature)
        end
        costs = [p.cost_per_touch * count(touched(plan)) for plan in plans]
        values = [plan_value(pred, t) for pred in preds[adopted]]
        prices = [transaction_price(c, v, confidence) for (c, v) in zip(costs, values)]
        feasible = [j for j in eachindex(plans)
                    if prices[j] <= 0 || all(profiles[j][c] * prices[j] <= tr.balance[proposers[j], c] for c in 1:nc)]
        f = choose(obs, preds[adopted][feasible], t)
        i = f == 1 ? 1 : feasible[f - 1] + 1
        rel_gain .= reputation_decay.(rel_gain, 1.0; rate = rate_gain)
        rel_loss .= reputation_decay.(rel_loss, 1.0; rate = rate_loss)
        if i == 1
            push!(tr.chosen_agent, 0)
        else
            j = i - 1
            a, plan, pred, prof = proposers[j], plans[j], preds[adopted][j], profiles[j]
            push!(tr.chosen_agent, a); push!(tr.costs, costs[j]); push!(tr.domains, doms[j])
            push!(tr.classified, argmax(prof))
            prof[nc] == 1 && push!(tr.flagged, step)
            upfront, _ = escrow_split(values[j], confidence)
            tr.balance[a, :] .-= split_signed(prof, prices[j])[1]
            done = carried_out(rng, p.agents[a].sloppiness, plan)
            seen = observed_plan(mrng, done, w.marker_σ)
            measured = plan_value(seen, t)
            settled = settlement(measured, upfront)
            tr.balance[a, :] .+= split_signed(prof, settled)[1]
            tr.paid[a] += upfront + settled
            net, pos, neg = split_signed(prof, measured)
            tr.h_pos[a, :] .+= pos
            tr.h_neg[a, :] .+= neg
            (measured >= 0 ? rel_gain : rel_loss)[a, :] .+= net
            tr.measured[a] += measured
            mask = touched(plan)
            realised = [seen.du[mask]; seen.dh[mask]]
            for m in 1:k
                pm = preds[m][j]
                push!(history[m], mm_score([pm.du[mask]; pm.dh[mask]], realised))
            end
            s.u .+= done.du
            s.h .+= done.dh
        end
        for a in 1:na, c in 1:nc
            excess = overflow(tr.balance[a, c], accumulation_threshold(p.overflow_base, p.overflow_factor, rel_gain[a, c] + rel_loss[a, c]))
            tr.balance[a, c] -= excess
            tr.reinvested[c] += excess
        end
        adopted = mm_adopt(rolling())
        obs = ToyState(observe(mrng, s.u, w.marker_σ), observe(mrng, s.h, w.marker_σ))
        record!()
    end
    tr.relevance .= rel_gain .+ rel_loss
    tr
end
