# Governed-threshold perturbation battery (plan: sensitivity map, later optimisation; author 2026-11-06, ruling 8.164).
# Run: julia -t auto --project=sim sim/battery/thresholds.jl [--world=economy|active] [--grid=standard|wide] [--workers=N] [--arms=N] [--max=N] [--steps=N]
# One threshold at a time is scaled across SCALES, everything else at its default, in the economy
# battery's world (or `--world=active`, which switches on model churn `p_new_model > 0` with pool >= ratchet_k,
# novel domain formation, binding `budget = true`, and a continuous deceiver mix per docs/PLAN.md).
# Each arm is paired with the default on the same seeds; readings track BOTH outputs (the Goal's L74
# success pattern + deceivers' advantage) AND mechanism touches (`takeovers`, `formations`, `leaf_bars`,
# `advap_audits`, `advap_established`, `advap_reports`, `lane_executed`, `explored`) per author ruling 8.164
# to separate `local_optimum` vs `one_sided_cliff`/`tradeoff_frontier` vs `inconsequential` (untouched).
# Design (2026-11-14, after six screen candidates all failed to replicate on fresh seeds): (1) seeds by
# precision per arm (`seeds_until_stable` on the paired floor-u difference, tolerance TOL, MIN_SEEDS to
# MAX_SEEDS), not a fixed six; (2) every verdict at z = 3, Student-t inflated (`paired_effect`); (3) two
# stages: stage 1 screens on seeds 1.., a screen-candidate is then re-measured on the disjoint block
# CONFIRM_FIRST.. (same precision rule, z = 3, default re-run on the same fresh seeds) and is flagged
# only if the confirm stage is also a candidate. The default arm's readings are cached per seed and
# shared, so its seeds are common random numbers; for "no effect" arms, the achievable equivalence
# margin (`equivalent` at z = 3) at that sample's precision is recorded.
using BenefutureSim, Statistics, Random, Printf, Serialization
include(joinpath(@__DIR__, "..", "test", "legacy.jl"))
argval(name, default) = (i = findfirst(a -> startswith(a, "--$name="), ARGS); i === nothing ? default : parse(Int, split(ARGS[i], "=")[2]))
argstr(name, default) = (i = findfirst(a -> startswith(a, "--$name="), ARGS); i === nothing ? default : String(split(ARGS[i], "="; limit = 2)[2]))
const STEPS = argval("steps", 300)
const MIN_SEEDS = argval("min", 6)
const MAX_SEEDS = argval("max", 24)
const MAX_ARMS = argval("arms", typemax(Int))
const WORKERS = argval("workers", 1)
const WORLD = argstr("world", "economy")
const GRID = argstr("grid", "standard")
const BASE_SEED_SINGLE = argval("base-seed", 0)
const ARM_IDX_SINGLE = argval("arm-idx", 0)
const BASE_FILE = argstr("base-file", "")
const OUT_JLS = argstr("out-jls", "")
const TOL = 1.5                 # standard error (t-inflated) of the paired floor-u difference, in floor-u points; z = 3 then detects ~4.5
const Z = 3.0
const SCREEN_SEEDS = collect(1:MAX_SEEDS)
const CONFIRM_FIRST = 1001
const CONFIRM_SEEDS = collect(CONFIRM_FIRST:CONFIRM_FIRST + MAX_SEEDS - 1)
const BUILD = readchomp(`git rev-parse --short HEAD`)   # read at start: HEAD may move while it runs
const SCALES = GRID == "wide" ? [0.1, 0.25, 0.5, 2.0, 5.0, 10.0] : [0.5, 0.75, 1.5, 2.0]
# (field, kind): :real scales; :int scales and rounds; :prob scales and clamps below 1.
const THRESHOLDS = [(:threshold, :prob), (:coarse_threshold, :prob), (:model_z, :real), (:max_credence, :cred),
                    (:ratchet_growth, :real), (:adv_z, :real), (:acc_halflife, :real), (:ratchet_horizon, :real),
                    (:actor_min_records, :int), (:adv_min_records, :int), (:pattern_attention, :real), (:min_records, :int)]
const DEFAULTS = let m = M3cParams(ToyParams(n = 20, steps = 10, plans = 2), [DomainAgent([0.5, 0, 0, 0], [1.0, 0, 0, 0], 0.2)], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02)
    Dict(f => getproperty(m, f) for (f, _) in THRESHOLDS)
end
value(f, kind, s) = (d = DEFAULTS[f]; kind == :int ? max(1, round(Int, d * s)) : kind == :prob ? clamp(d * s, 0.05, 0.995) :
                     kind == :cred ? clamp(1 - (1 - d) / s, 0.51, 0.9999) : d * s)   # credence cap: scales the gap to 1
function world(over::Dict{Symbol,Any})
    if WORLD == "active"
        skills = draw_skills(Xoshiro(20261031), 8, 5, [1, 3, 5]; median = 0.6)
        agents = [DomainAgent(skills[a, :], [0.4, 0, 0.4, 0, 0.2], 0.3) for a in 1:8]
        return M3cParams(ToyParams(n = 80, steps = STEPS, plans = 10), agents, [1, 1, 2, 2, 1], Bool[true, true, true, true, false];
                         λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, p_upstream = 0.5,
                         guardians = [1, 2, 3, 4, 1], diligence = fill(0.8, 8), p_foresee = 1.0, repair_efficiency = 0.5,
                         deceit = [0, 0, 0, 0, 0, 0.2, 0.4, 0.7], advap = true, marker_σ = 0.35, σ_leaf = 0.6,
                         bias_σ = 0.2, cost_σ = 0.18, p_new_model = 0.15, pool_max = 5, ratchet_k = 3,
                         takeover_records = 20, form_count = 15, budget = true, endowment = 4.5, cost_per_touch = 0.75,
                         LEGACY..., over...)
    end
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
    decs, hons = WORLD == "active" ? (6:8, 1:5) : (7:8, 1:6)
    adv = (mean(standing(i) for i in decs) - mean(standing(i) for i in hons)) / (tr.endowed / 8)
    (floor_u = sp.floor_u, floor_h = sp.floor_h, median_u = sp.median_u, median_h = sp.median_h, harm = sp.worst_drop, adv = adv,
     takeovers = Float64(tr.takeovers), formations = Float64(length(tr.formations)),
     bars = Float64(sum(tr.leaf_bars)), audits = Float64(tr.advap_audits),
     established = Float64(tr.advap_established), reports = Float64(tr.advap_reports),
     lane = Float64(tr.lane_executed), explored = Float64(tr.explored))
end
const KEYS = (:floor_u, :floor_h, :median_u, :median_h, :harm, :adv)
const TOUCH_KEYS = (:takeovers, :formations, :bars, :audits, :established, :reports, :lane, :explored)
const BASE = isfile(BASE_FILE) ? deserialize(BASE_FILE) : Dict{Int,Any}()   # default arm's readings by seed, shared by every arm
base_reading(s) = get!(() -> reading(Dict{Symbol,Any}(), s), BASE, s)
# One stage: seeds by precision on the paired floor-u difference; returns seeds used, touch telemetry, per-reading effects, achievable equivalence margin, verdict.
function stage(over, seeds)
    arm = Dict{Int,Any}()
    r = seeds_until_stable(s -> (arm[s] = reading(over, s); arm[s].floor_u - base_reading(s).floor_u);
                           tol = TOL, min_seeds = MIN_SEEDS, max_seeds = MAX_SEEDS, seeds = seeds)
    cells = String[]; good = 0; bad = 0
    du = [arm[s].floor_u - base_reading(s).floor_u for s in r.seeds]
    pe0 = paired_effect(du; z = Z)
    eq_margin = abs(pe0.mean) + pe0.z * pe0.se
    @assert equivalent(du; margin = eq_margin + 1e-9, z = Z).equivalent
    for k in KEYS
        d = [getfield(arm[s], k) - getfield(base_reading(s), k) for s in r.seeds]
        pe = paired_effect(d; z = Z, direction = :up); pn = paired_effect(d; z = Z, direction = :down)
        mark = pe.significant ? "+" : pn.significant ? "−" : ""
        better = k in (:harm, :adv) ? pn.significant : pe.significant
        worse = k in (:harm, :adv) ? pe.significant : pn.significant
        good += better; bad += worse
        push!(cells, @sprintf("%.2f%s", mean(d), mark))
    end
    max_out = maximum(maximum(abs(getfield(arm[s], k) - getfield(base_reading(s), k)) for k in KEYS) for s in r.seeds)
    top_touch = (diff = 0.0, name = "")
    for tk in TOUCH_KEYS
        td = maximum(abs(getfield(arm[s], tk) - getfield(base_reading(s), tk)) for s in r.seeds)
        td > top_touch.diff && (top_touch = (diff = td, name = string(tk)))
    end
    touched = top_touch.diff > 0 || max_out > 1e-9
    touch_str = touched ? (top_touch.diff > 0 ? @sprintf("yes (%s %.0f)", top_touch.name, top_touch.diff) : @sprintf("yes (out %.2g)", max_out)) : "NONE (0)"
    verdict = !touched ? "inconsequential" :
              (good > 0 && bad > 0) ? "tradeoff" :
              bad > 0 ? "worse" :
              good > 0 ? "candidate" : "no effect"
    (n = r.n, stable = r.stable, cells = cells, eq_margin = eq_margin, touched = touched, touch_str = touch_str,
     good = good, bad = bad, verdict = verdict)
end
const EXTRA_WIDE = GRID == "wide" ? [(:max_credence, 0.6), (:max_credence, 0.75), (:ratchet_growth, 0.0), (:pattern_attention, 0.0), (:min_records, 0.0)] : Tuple{Symbol,Float64}[]
# Replication (BF_ARMS="field=value,..."): only the named arms.
const ALL_ARMS = haskey(ENV, "BF_ARMS") ?
    [(Symbol(split(a, "=")[1]), parse(Float64, split(a, "=")[2])) for a in split(ENV["BF_ARMS"], ",")] :
    vcat([(f, (kind == :int ? Float64(value(f, kind, sc)) : value(f, kind, sc))) for (f, kind) in THRESHOLDS for sc in SCALES], EXTRA_WIDE)
const ARMS = first(unique(filter(((f, v),) -> (DEFAULTS[f] isa Integer ? round(Int, v) : v) != DEFAULTS[f], ALL_ARMS)), MAX_ARMS)

function run_arm_row(idx)
    f, v0 = ARMS[idx]
    v = DEFAULTS[f] isa Integer ? round(Int, v0) : v0
    sc = round(v0 / DEFAULTS[f]; digits = 3)
    s1 = stage(Dict{Symbol,Any}(f => v), SCREEN_SEEDS)
    s2 = s1.verdict == "candidate" ? stage(Dict{Symbol,Any}(f => v), CONFIRM_SEEDS) : nothing
    final = s1.verdict == "candidate" ? (s2.verdict == "candidate" ? "FLAGGED" : "screen only (not confirmed: $(s2.verdict))") : s1.verdict
    eff_verdict = s2 === nothing ? s1.verdict : s2.verdict
    c2 = s2 === nothing ? "–" : join(s2.cells, " / ") * " ($(s2.verdict))"
    eq_col = (s1.verdict == "no effect" || s1.verdict == "inconsequential") ? @sprintf("±%.2f", s1.eq_margin) : "–"
    dir = v < DEFAULTS[f] ? :low : :high
    row = "| `$f` | $(sc)× → $(round(v; sigdigits = 3)) | $(s1.touch_str) | $(s1.n)$(s1.stable ? "" : "*") | " * join(s1.cells, " | ") *
          " | $eq_col | $(s1.verdict) | " * (s2 === nothing ? "–" : "$(s2.n)$(s2.stable ? "" : "*")") * " | $c2 | $final |"
    (field = f, val = Float64(v), dir = dir, touched = s1.touched, verdict = eff_verdict, final = final,
     row = row, flagged = final == "FLAGGED" ? 1 : 0)
end

function classify_threshold(f, recs)
    sub = filter(r -> r.field == f, recs)
    isempty(sub) && return "–"
    any(r -> r.final == "FLAGGED", sub) && return "candidate_improvement"
    all(r -> !r.touched, sub) && return "inconsequential (never touches system)"
    lows = filter(r -> r.dir == :low, sub)
    highs = filter(r -> r.dir == :high, sub)
    low_bad = any(r -> r.verdict in ("worse", "tradeoff"), lows)
    high_bad = any(r -> r.verdict in ("worse", "tradeoff"), highs)
    low_pure_worse = any(r -> r.verdict == "worse", lows)
    high_pure_worse = any(r -> r.verdict == "worse", highs)
    has_tradeoff = any(r -> r.verdict == "tradeoff", sub)
    if low_pure_worse && high_pure_worse && !has_tradeoff
        return "local_optimum (both directions degrade)"
    elseif low_bad && high_bad
        return has_tradeoff ? "local_optimum / tradeoff_frontier (both sides bind)" : "local_optimum (both directions degrade)"
    elseif low_bad || high_bad
        side = low_bad ? "low" : "high"
        other_untouched = low_bad ? all(r -> !r.touched, highs) : all(r -> !r.touched, lows)
        return other_untouched ? "one_sided_cliff ($(side) binds; opposite side untouched)" : "one_sided_cliff / tradeoff ($(side) binds)"
    else
        return "inconclusive (touches system, n.s. at z=3)"
    end
end

if BASE_SEED_SINGLE > 0
    serialize(OUT_JLS, reading(Dict{Symbol,Any}(), BASE_SEED_SINGLE))
elseif ARM_IDX_SINGLE > 0
    serialize(OUT_JLS, run_arm_row(ARM_IDX_SINGLE))
else
    t0 = time()
    prog_path = joinpath(@__DIR__, "state", "thresholds_$(WORLD)_$(GRID).progress")
    pt = progress_tracker(prog_path, "thresholds ($(WORLD)/$(GRID))", length(ARMS); interval = 300.0)
    done_cnt = Threads.Atomic{Int}(0)
    results = if WORKERS > 1
        proj = dirname(@__DIR__)
        mktempdir() do tmp
            asyncmap(SCREEN_SEEDS; ntasks = WORKERS) do s
                p = joinpath(tmp, "base_$s.jls")
                run(`$(Base.julia_cmd()) --project=$(proj) $(@__FILE__) --world=$(WORLD) --steps=$(STEPS) --min=$(MIN_SEEDS) --max=$(MAX_SEEDS) --base-seed=$(s) --out-jls=$(p)`)
                BASE[s] = deserialize(p)
            end
            base_path = joinpath(tmp, "base.jls")
            serialize(base_path, BASE)
            asyncmap(eachindex(ARMS); ntasks = WORKERS) do idx
                p = joinpath(tmp, "arm_$idx.jls")
                cmd = `$(Base.julia_cmd()) --project=$(proj) $(@__FILE__) --world=$(WORLD) --grid=$(GRID) --steps=$(STEPS) --min=$(MIN_SEEDS) --max=$(MAX_SEEDS) --arms=$(MAX_ARMS) --base-file=$(base_path) --arm-idx=$(idx) --out-jls=$(p)`
                run(cmd)
                res = deserialize(p)
                c = Threads.atomic_add!(done_cnt, 1) + 1
                progress_tick!(pt, c, "$(res.field)=$(round(res.val; sigdigits = 3)) -> $(res.final)")
                println(res.row); flush(stdout)
                res
            end
        end
    else
        map(eachindex(ARMS)) do idx
            res = run_arm_row(idx)
            progress_tick!(pt, idx, "$(res.field)=$(round(res.val; sigdigits = 3)) -> $(res.final)")
            println(res.row); flush(stdout)
            res
        end
    end
    progress_finish!(pt, "wrote thresholds output")
    rows = [r.row for r in results]
    global flagged = sum(r -> r.flagged, results)
    fname = haskey(ENV, "BF_ARMS") ? "thresholds_replication.md" :
            GRID == "wide" ? (WORLD == "active" ? "thresholds_wide.md" : "thresholds_wide_$(WORLD).md") :
            WORLD == "active" ? "thresholds_active.md" : "thresholds.md"
    out = joinpath(@__DIR__, "results", fname)
    open(out, "w") do io
        println(io, "# Governed-threshold perturbation battery$(WORLD == "active" ? " (active world)" : "")$(GRID == "wide" ? " (wide grid, 8.164)" : "")\n")
        println(io, "Build: commit $(BUILD). World: $(WORLD). Grid: $(GRID). $(STEPS) steps; run time $(round((time() - t0) / 60; digits = 1)) minutes; $(length(ARMS)) distinct arms, $(flagged) flagged.\n")
        println(io, "Seeds and bars: seeds by precision per arm (stop when the t-inflated standard error of the paired floor-u difference is at most $(TOL), $(MIN_SEEDS) to $(MAX_SEEDS) seeds; * = cap reached without that precision); stage 1 screen on seeds 1..; every verdict at z = $(Z), Student-t inflated. Two-stage rule: a screen candidate is re-measured on the disjoint fresh seeds $(CONFIRM_FIRST).. (default re-run on them) and is FLAGGED only if the confirmation is also a candidate. For no-effect / inconsequential arms, `Equiv ±Δ` states the smallest achievable floor-u equivalence bound (`equivalent` at z = $(Z)). `Touch` checks whether internal mechanism counters or outputs moved on any seed vs default (8.164).\n")
        world_desc = WORLD == "active" ?
            "World (active): economy battery + model churn (`p_new_model = 0.15`, `pool_max = 5 >= ratchet_k = 3`, `takeover_records = 20`), novel leaf formation (`form_count = 15`), binding budgets (`budget = true`, `endowment = 4.5`, `cost_per_touch = 0.75`), and a graded deceiver mix (`[0..0, 0.2, 0.4, 0.7]`)." :
            "World: the economy battery's, noise at moderate severity, two deceivers at full size, AdvAp on."
        println(io, "$world_desc Each cell: mean paired difference from the default (arm − default); + / − significant at z = $(Z). Harm and the deceivers' advantage are better when lower. Candidate = some reading better and none worse; tradeoff = some reading better and another worse. Stage 2 cells: floor u / floor h / median u / median h / harm / deceivers' advantage.\n")
        println(io, "## Per-threshold classification (Author Ruling 8.164)\n")
        println(io, "| Threshold | Default | Touched arms | Worse/tradeoff low | Worse/tradeoff high | Classification |")
        println(io, "|---|---|---|---|---|---|")
        for (f, _) in THRESHOLDS
            sub = filter(r -> r.field == f, results)
            isempty(sub) && continue
            ntouch = count(r -> r.touched, sub)
            nlow = count(r -> r.dir == :low && r.verdict in ("worse", "tradeoff"), sub)
            nhigh = count(r -> r.dir == :high && r.verdict in ("worse", "tradeoff"), sub)
            println(io, "| `$f` | $(DEFAULTS[f]) | $(ntouch) / $(length(sub)) | $nlow | $nhigh | $(classify_threshold(f, results)) |")
        end
        println(io, "\n## Per-arm results\n")
        println(io, "| Threshold | Setting | Touch | Seeds | Floor u | Floor h | Median u | Median h | Harm peak | Deceivers' advantage | Equiv ±Δ (floor u, z=3) | Screen | Confirm seeds | Confirm cells | Result |")
        println(io, "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
        foreach(r -> println(io, r), rows)
    end
    println("wrote ", out)
end
