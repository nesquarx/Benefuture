# Governed-threshold perturbation battery (plan: sensitivity map, later optimisation; author 2026-11-06).
# Run: julia -t auto --project=sim sim/battery/thresholds.jl [--arms=N (first N arms)] [--max=N] [--steps=N]
# One threshold at a time is scaled by each factor in SCALES, everything else at its default, in the
# economy battery's world at a moderate stress (noise severity 0.5, two deceivers at full size, AdvAp on).
# Each arm is paired with the default on the same seeds; readings: the Goal's success pattern (L74:
# floors and medians of understanding and happiness, harm's peak) and the deceivers' advantage over
# honest agents in endowments.
# Design (2026-11-14, after six screen candidates all failed to replicate on fresh seeds): (1) seeds by
# precision per arm (`seeds_until_stable` on the paired floor-u difference, tolerance TOL, MIN_SEEDS to
# MAX_SEEDS), not a fixed six; (2) every verdict at z = 3, Student-t inflated (`paired_effect`); (3) two
# stages: stage 1 screens on seeds 1.., a screen-candidate is then re-measured on the disjoint block
# CONFIRM_FIRST.. (same precision rule, z = 3, default re-run on the same fresh seeds) and is flagged
# only if the confirm stage is also a candidate. The default arm's readings are cached per seed and
# shared, so its seeds are common random numbers; a bad default draw still shifts stage 1, which is why
# stage 2 exists. Duplicate settings (identical value, or equal to the default) are run once.
# Prediction (2026-11-14, confidence 0.7): none of the current settings is flagged; a few may pass the
# screen, none the confirmation. Run cost: roughly 40 distinct arms x 6-24 seeds x ~19 s: 2.5-5 hours.
# A threshold direction that improves the pattern without raising harm or the deceivers' advantage is a
# candidate for the author, never a default change (thresholds are governed).
using BenefutureSim, Statistics, Random, Printf
include(joinpath(@__DIR__, "..", "test", "legacy.jl"))
argval(name, default) = (i = findfirst(a -> startswith(a, "--$name="), ARGS); i === nothing ? default : parse(Int, split(ARGS[i], "=")[2]))
const STEPS = argval("steps", 300)
const MIN_SEEDS = argval("min", 6)
const MAX_SEEDS = argval("max", 24)
const MAX_ARMS = argval("arms", typemax(Int))
const TOL = 1.5                 # standard error (t-inflated) of the paired floor-u difference, in floor-u points; z = 3 then detects ~4.5
const Z = 3.0
const SCREEN_SEEDS = collect(1:MAX_SEEDS)
const CONFIRM_FIRST = 1001
const CONFIRM_SEEDS = collect(CONFIRM_FIRST:CONFIRM_FIRST + MAX_SEEDS - 1)
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
const KEYS = (:floor_u, :floor_h, :median_u, :median_h, :harm, :adv)
const BASE = Dict{Int,Any}()   # default arm's readings by seed, shared by every arm (computed once)
base_reading(s) = get!(() -> reading(Dict{Symbol,Any}(), s), BASE, s)
# One stage: seeds by precision on the paired floor-u difference; returns seeds used, per-reading effects, verdict.
function stage(over, seeds)
    arm = Dict{Int,Any}()
    r = seeds_until_stable(s -> (arm[s] = reading(over, s); arm[s].floor_u - base_reading(s).floor_u);
                           tol = TOL, min_seeds = MIN_SEEDS, max_seeds = MAX_SEEDS, seeds = seeds)
    cells = String[]; good = 0; bad = 0
    for k in KEYS
        d = [getfield(arm[s], k) - getfield(base_reading(s), k) for s in r.seeds]
        pe = paired_effect(d; z = Z, direction = :up); pn = paired_effect(d; z = Z, direction = :down)
        mark = pe.significant ? "+" : pn.significant ? "−" : ""
        better = k in (:harm, :adv) ? pn.significant : pe.significant
        worse = k in (:harm, :adv) ? pe.significant : pn.significant
        good += better; bad += worse
        push!(cells, @sprintf("%.2f%s", mean(d), mark))
    end
    (n = r.n, stable = r.stable, cells = cells, verdict = bad > 0 ? "worse" : good > 0 ? "candidate" : "no effect")
end
rows = String[]
t0 = time()
# Replication (BF_ARMS="field=value,..."): only the named arms.
const ALL_ARMS = haskey(ENV, "BF_ARMS") ?
    [(Symbol(split(a, "=")[1]), parse(Float64, split(a, "=")[2])) for a in split(ENV["BF_ARMS"], ",")] :
    [(f, (kind == :int ? Float64(value(f, kind, sc)) : value(f, kind, sc))) for (f, kind) in THRESHOLDS for sc in SCALES]
const ARMS = first(unique(filter(((f, v),) -> (DEFAULTS[f] isa Integer ? round(Int, v) : v) != DEFAULTS[f], ALL_ARMS)), MAX_ARMS)
global flagged = 0
for (f, v0) in ARMS
    v = DEFAULTS[f] isa Integer ? round(Int, v0) : v0
    sc = round(v0 / DEFAULTS[f]; digits = 3)
    s1 = stage(Dict{Symbol,Any}(f => v), SCREEN_SEEDS)
    s2 = s1.verdict == "candidate" ? stage(Dict{Symbol,Any}(f => v), CONFIRM_SEEDS) : nothing
    final = s1.verdict == "candidate" ? (s2.verdict == "candidate" ? "FLAGGED" : "screen only (not confirmed: $(s2.verdict))") : s1.verdict
    global flagged += final == "FLAGGED"
    c2 = s2 === nothing ? "–" : join(s2.cells, " / ") * " ($(s2.verdict))"
    push!(rows, "| `$f` | $(sc)× → $(round(v; sigdigits = 3)) | $(s1.n)$(s1.stable ? "" : "*") | " * join(s1.cells, " | ") * " | $(s1.verdict) | " *
                (s2 === nothing ? "–" : "$(s2.n)$(s2.stable ? "" : "*")") * " | $c2 | $final |")
    println(rows[end]); flush(stdout)
end
out = joinpath(@__DIR__, "results", haskey(ENV, "BF_ARMS") ? "thresholds_replication.md" : "thresholds.md")
open(out, "w") do io
    println(io, "# Governed-threshold perturbation battery\n")
    println(io, "Build: commit $(BUILD). $(STEPS) steps; run time $(round((time() - t0) / 60; digits = 1)) minutes; $(length(ARMS)) distinct arms, $(flagged) flagged.\n")
    println(io, "Seeds and bars: seeds by precision per arm (stop when the t-inflated standard error of the paired floor-u difference is at most $(TOL), $(MIN_SEEDS) to $(MAX_SEEDS) seeds; * = cap reached without that precision); stage 1 screen on seeds 1..; every verdict at z = $(Z), Student-t inflated. Two-stage rule: a screen candidate is re-measured on the disjoint fresh seeds $(CONFIRM_FIRST).. (default re-run on them) and is FLAGGED only if the confirmation is also a candidate.\n")
    println(io, "World: the economy battery's, noise at moderate severity, two deceivers at full size, AdvAp on. Each cell: mean paired difference from the default (arm − default); + / − significant at z = $(Z). Harm and the deceivers' advantage are better when lower. Candidate = some reading better and none worse. Stage 2 cells: floor u / floor h / median u / median h / harm / deceivers' advantage.\n")
    println(io, "| Threshold | Setting | Seeds | Floor u | Floor h | Median u | Median h | Harm peak | Deceivers' advantage | Screen | Confirm seeds | Confirm cells | Result |")
    println(io, "|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    foreach(r -> println(io, r), rows)
end
println("wrote ", out)
