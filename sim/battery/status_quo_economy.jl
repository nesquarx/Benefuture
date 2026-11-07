# Status-quo baseline for the economy (8.114 continued). Run: julia --project=sim sim/battery/status_quo_economy.jl
# The same Benefuture economy, worlds and seeds, with its institution-dependent factors at Benefuture-
# plausible values (economy battery severity 0) or at today's (severity 1: readers who seldom read the
# log, unaudited ledgers, ill-informed and less diligent guardians, audit errors, memory loss) and
# AdvAp off. Not a market economy without domain currencies (not modelled): it isolates what the
# institutions add. World: moderate noise, two deceivers, a capture attempt; the Goal's success pattern.
using BenefutureSim, Statistics, Random, Printf
include(joinpath(@__DIR__, "..", "test", "legacy.jl"))
const SEEDS = 1:8
const BUILD = readchomp(`git rev-parse --short HEAD`)
function world(sq::Bool)
    skills = draw_skills(Xoshiro(20261031), 8, 4, [1, 3]; median = 0.6)
    agents = [DomainAgent(skills[a, :], [0.5, 0, 0.5, 0], 0.3) for a in 1:8]
    inst = sq ? (vigilance = 0.001, cost_σ = 0.3, memory_loss = 0.1, p_false_trace = 0.05, p_informed = 0.6, dil = 0.4, advap = false) :
                (vigilance = 0.1, cost_σ = 0.05, memory_loss = 0.0, p_false_trace = 0.005, p_informed = 0.95, dil = 0.95, advap = true)
    M3cParams(ToyParams(n = 80, steps = 300, plans = 10), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
              transactions = true, causal_distribution = true, p_upstream = 0.5, guardians = [1, 2, 3, 4],
              diligence = fill(inst.dil, 8), p_informed = inst.p_informed, p_foresee = 1.0, repair_efficiency = 0.5,
              deceit = [0, 0, 0, 0, 0, 0, 1.0, 1.0], advap = inst.advap, vigilance = inst.vigilance, cost_σ = inst.cost_σ,
              memory_loss = inst.memory_loss, p_false_trace = inst.p_false_trace, marker_σ = 0.35, σ_leaf = 0.6, bias_σ = 0.2,
              events = [shock(:capture; step = 100, duration = 150, size = 1.5, target = 1)], LEGACY...)
end
function reading(sq, seed)
    tr = run_m3c(world(sq); seed)
    sp = success_pattern(tr; from = 51)
    standing(i) = sum(tr.balance[i, :]) + tr.overflow_agent[i]
    (floor_u = sp.floor_u, floor_h = sp.floor_h, median_u = sp.median_u, median_h = sp.median_h, harm = sp.worst_drop,
     adv = (mean(standing(i) for i in 7:8) - mean(standing(i) for i in 1:6)) / (tr.endowed / 8))
end
t0 = time()
bf = [reading(false, s) for s in SEEDS]; sq = [reading(true, s) for s in SEEDS]
rows = String[]
for (k, name, better_low) in ((:floor_u, "Floor of understanding", false), (:floor_h, "Floor of happiness", false), (:median_u, "Median of understanding", false),
                             (:median_h, "Median of happiness", false), (:harm, "Harm's peak", true), (:adv, "Deceivers' advantage (endowments)", true))
    d = [getfield(a, k) - getfield(b, k) for (a, b) in zip(bf, sq)]
    up, dn = paired_effect(d; z = 2.0), paired_effect(d; z = 2.0, direction = :down)
    v = up.significant ? (better_low ? "status quo better" : "Benefuture better") : dn.significant ? (better_low ? "Benefuture better" : "status quo better") : "no difference shown"
    push!(rows, @sprintf("| %s | %.2f | %.2f | %+.2f ± %.2f | %s |", name, mean(getfield.(bf, k)), mean(getfield.(sq, k)), up.mean, up.se, v))
    println(rows[end]); flush(stdout)
end
open(joinpath(@__DIR__, "results", "status_quo_economy.md"), "w") do io
    println(io, "# Status-quo baseline: economy institutions\n\nBuild: commit $(BUILD). Seeds $(SEEDS); 300 steps; run time $(round((time() - t0) / 60; digits = 1)) minutes.\n")
    println(io, "Same Benefuture economy, world and seeds; institutions at Benefuture-plausible values with AdvAp, or at today's values without it. Not a market economy without domain currencies. World: moderate noise, two deceivers, a capture attempt from step 100.\n")
    println(io, "| Reading | Benefuture institutions | Status-quo institutions | Difference (paired) | Verdict at z = 2 |\n|---|---|---|---|---|")
    foreach(r -> println(io, r), rows)
end
