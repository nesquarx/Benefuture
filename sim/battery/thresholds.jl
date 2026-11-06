# Governed-threshold perturbation battery (plan: sensitivity map, later optimisation; author 2026-11-06).
# Run: julia -t auto --project=sim sim/battery/thresholds.jl [--seeds=1:6]
# One threshold at a time is scaled by each factor in SCALES, everything else at its default, in the
# economy battery's world at a moderate stress (noise severity 0.5, two deceivers at full size, AdvAp on).
# Each arm is paired with the default on the same seeds; readings: the Goal's success pattern (L74:
# floors and medians of understanding and happiness, harm's peak) and the deceivers' advantage over
# honest agents in endowments. An effect counts at z = 2 (`paired_effect`); a direction that improves
# the pattern without raising harm or the deceivers' advantage is a candidate for the author, never a
# default change (thresholds are governed; an optimum must replicate on fresh seeds first).
using BenefutureSim, Statistics, Random, Printf
include(joinpath(@__DIR__, "..", "test", "legacy.jl"))
seeds_arg = something(findfirst(a -> startswith(a, "--seeds="), ARGS), 0)
const SEEDS = seeds_arg == 0 ? (1:6) : eval(Meta.parse(split(ARGS[seeds_arg], "=")[2]))
const STEPS = 300
const BUILD = readchomp(`git rev-parse --short HEAD`)   # read at start: HEAD may move while it runs
const SCALES = [0.5, 0.75, 1.5, 2.0]
# (field, kind): :real scales; :int scales and rounds; :prob scales and clamps below 1.
const THRESHOLDS = [(:threshold, :prob), (:coarse_threshold, :prob), (:model_z, :real), (:max_credence, :cred),
                    (:ratchet_growth, :real), (:adv_z, :real), (:acc_halflife, :real), (:ratchet_horizon, :real),
                    (:actor_min_records, :int), (:adv_min_records, :int), (:pattern_attention, :real), (:min_records, :int)]
const DEFAULTS = let m = M3cParams(ToyParams(n = 20, steps = 10, plans = 2), [DomainAgent([0.5, 0, 0, 0], [1.0, 0, 0, 0], 0.2)], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02)
    Dict(f => getproperty(m, f) for (f, _) in THRESHOLDS)
end
value(f, kind, s) = (d = DEFAULTS[f]; kind == :int ? max(1, round(Int, d * s)) : kind == :prob ? min(d * s, 0.99) :
                     kind == :cred ? clamp(1 - (1 - d) / s, 0.5, 0.999) : d * s)   # credence cap: scales the gap to 1
function world(over::Dict{Symbol,Any})
    skills = draw_skills(Xoshiro(20261031), 8, 4, [1, 3]; median = 0.6)
    agents = [DomainAgent(skills[a, :], [0.5, 0, 0.5, 0], 0.3) for a in 1:8]
    M3cParams(ToyParams(n = 80, steps = STEPS, plans = 10), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
              transactions = true, causal_distribution = true, p_upstream = 0.5, guardians = [1, 2, 3, 4],
              diligence = fill(0.8, 8), p_foresee = 1.0, repair_efficiency = 0.5, deceit = [0, 0, 0, 0, 0, 0, 1.0, 1.0],
              advap = true, marker_σ = 0.35, σ_leaf = 0.6, bias_σ = 0.2, cost_σ = 0.18, LEGACY..., over...)
end
function reading(over, seed)
    tr = run_m3c(world(over); seed)
    sp = success_pattern(tr; from = 51)
    standing(i) = sum(tr.balance[i, :]) + tr.overflow_agent[i]
    adv = (mean(standing(i) for i in 7:8) - mean(standing(i) for i in 1:6)) / (tr.endowed / 8)
    (floor_u = sp.floor_u, floor_h = sp.floor_h, median_u = sp.median_u, median_h = sp.median_h, harm = sp.worst_drop, adv = adv)
end
base = [reading(Dict{Symbol,Any}(), s) for s in SEEDS]
keys_ = (:floor_u, :floor_h, :median_u, :median_h, :harm, :adv)
rows = String[]
t0 = time()
# Replication (BF_ARMS="field=value,..."): only the named arms, on the given (fresh) seeds.
const ARMS = haskey(ENV, "BF_ARMS") ?
    [(Symbol(split(a, "=")[1]), parse(Float64, split(a, "=")[2])) for a in split(ENV["BF_ARMS"], ",")] :
    [(f, (kind == :int ? Float64(value(f, kind, sc)) : value(f, kind, sc))) for (f, kind) in THRESHOLDS for sc in SCALES]
for (f, v0) in ARMS
    v = DEFAULTS[f] isa Integer ? round(Int, v0) : v0
    sc = round(v0 / DEFAULTS[f]; digits = 3)
    arm = [reading(Dict{Symbol,Any}(f => v), s) for s in SEEDS]
    cells = String[]; good = 0; bad = 0
    for k in keys_
        d = [getfield(a, k) - getfield(b, k) for (a, b) in zip(arm, base)]
        pe = paired_effect(d; z = 2.0, direction = :up); pn = paired_effect(d; z = 2.0, direction = :down)
        mark = pe.significant ? "+" : pn.significant ? "−" : ""
        better = k in (:harm, :adv) ? pn.significant : pe.significant
        worse = k in (:harm, :adv) ? pe.significant : pn.significant
        good += better; bad += worse
        push!(cells, @sprintf("%.2f%s", mean(d), mark))
    end
    verdict = bad > 0 ? "worse" : good > 0 ? "candidate" : "no effect"
    push!(rows, "| `$f` | $(sc)× → $(round(v; sigdigits = 3)) | " * join(cells, " | ") * " | $verdict |")
    println(rows[end]); flush(stdout)
end
out = joinpath(@__DIR__, "results", haskey(ENV, "BF_ARMS") ? "thresholds_replication.md" : "thresholds.md")
open(out, "w") do io
    println(io, "# Governed-threshold perturbation battery\n")
    println(io, "Build: commit $(BUILD). Seeds $(SEEDS); $(STEPS) steps; run time $(round((time() - t0) / 60; digits = 1)) minutes.")
    println(io, "World: the economy battery's, noise at moderate severity, two deceivers at full size, AdvAp on. Each cell: mean paired difference from the default (arm − default); + / − significant at z = 2. Harm and the deceivers' advantage are better when lower. 'candidate' = some reading better and none worse: for the author, after replication on fresh seeds.\n")
    println(io, "| Threshold | Setting | Floor u | Floor h | Median u | Median h | Harm peak | Deceivers' advantage | Verdict |")
    println(io, "|---|---|---|---|---|---|---|---|---|")
    foreach(r -> println(io, r), rows)
end
println("wrote ", out)
