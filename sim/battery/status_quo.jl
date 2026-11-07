# Status-quo baseline for governance (CLAUDE.md: figures produced by today's institutions form a
# status-quo arm, never a default). Run: julia --project=sim sim/battery/status_quo.jl [--seeds=1:8]
# The same worlds and seeds (the governance battery's population and factors, at severities 0, 0.5, 1),
# decided two ways: Benefuture (expertise-weighted liquid democracy, capped audited delegation, reporting
# rewarded) and the status-quo arm (one person one vote, no delegation, no reward for revealing a bloc).
# Reading: the share of the last half of decisions right; paired difference per world, z = 2.
using BenefutureSim, Statistics, Random, Printf
seeds_arg = something(findfirst(a -> startswith(a, "--seeds="), ARGS), 0)
const SEEDS = seeds_arg == 0 ? (1:8) : eval(Meta.parse(split(ARGS[seeds_arg], "=")[2]))
const DECISIONS = 800
const BUILD = readchomp(`git rev-parse --short HEAD`)
ladder(r) = 0.25 * exp(0.4 * normal_quantile((r - 0.5) / 25))
m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                       [DomainAgent([k == l ? ladder(r) : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4])
                        for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
top(f) = unique(vcat([sortperm(m3.relevance_leaf[:, d]; rev = true)[1:round(Int, f * 25)] for d in 1:4]...))
world(s) = Dict{Symbol,Any}(:signal_σ => 2 + 4s, :ability_spread => 0.5 + s, :p_apparent => clamp(0.7 - 0.6s, 0, 1),
                            :local_σ => 1 + 3s, :colluders => top(clamp(0.5s, 0, 1)), :loyalty => 10s)
acc(tr) = mean(tr.final_trace[(DECISIONS ÷ 2 + 1):end])
rows = String[]
t0 = time()
for s in (0.0, 0.5, 1.0)
    w = world(s)
    bf = [acc(run_m5(M5Params(m3, 1:4; decisions = DECISIONS, stealth = true, advap = true, p_delegate = 0.4s, w...); seed)) for seed in SEEDS]
    sq = [acc(run_m5(M5Params(m3, 1:4; decisions = DECISIONS, stealth = true, advap = false, p_delegate = 0.0, expertise_weight = 0.0, w...); seed)) for seed in SEEDS]
    pe = paired_effect(bf .- sq; z = 2.0)
    push!(rows, @sprintf("| %.1f | %.3f | %.3f | %+.3f ± %.3f | %s |", s, mean(bf), mean(sq), pe.mean, pe.se, pe.significant ? "Benefuture better" : paired_effect(bf .- sq; z = 2.0, direction = :down).significant ? "status quo better" : "no difference shown"))
    println(rows[end]); flush(stdout)
end
open(joinpath(@__DIR__, "results", "status_quo.md"), "w") do io
    println(io, "# Status-quo baseline: governance\n\nBuild: commit $(BUILD). Seeds $(SEEDS); $(DECISIONS) decisions; run time $(round((time() - t0) / 60; digits = 1)) minutes.\n")
    println(io, "Same population, worlds and seeds. Benefuture: expertise-weighted liquid democracy, capped audited delegation (0.4 × severity), reporting rewarded. Status quo: one person one vote, no delegation, no reward for revealing a bloc. Reading: share of the last half of decisions right. Severity 0 is a mildly imperfect world, 1 the realistic bad end (signal noise, ability scatter, hidden outcomes, local noise, a colluding bloc of top experts, loyalty).\n")
    println(io, "| Severity | Benefuture | Status quo | Difference (paired) | Verdict at z = 2 |\n|---|---|---|---|---|")
    foreach(r -> println(io, r), rows)
end
