# Status-quo baseline for the economy (8.114 / 8.115 closed vs adaptive vs open entry).
# Run: julia --project=sim sim/battery/status_quo_economy.jl --workers=7 --seeds=1:24
#
# Pre-registered prediction (P7, COORDINATION.md §2a, 2026-11-15):
#   - P7 (confidence 0.7): With open newcomer entry taking unmet demand (`open_entry = true`,
#     `entrants = 8`), Benefuture's -10% `floor_u` disadvantage against status-quo institutions
#     in the closed 8-agent economy disappears (`no difference shown` or `Benefuture better`),
#     while Benefuture still cuts `deceivers' advantage` sharply (`z >= 3.0`).
#
# Same Benefuture economy, worlds and seeds, with its institution-dependent factors at Benefuture-
# plausible values (economy battery severity 0) or at today's (severity 1: readers who seldom read the
# log, unaudited ledgers, ill-informed and less diligent guardians, audit errors, memory loss) and
# AdvAp off. Not a market economy without domain currencies (not modelled): it isolates what the
# institutions add.

using BenefutureSim, Statistics, Random, Printf, Serialization

include(joinpath(@__DIR__, "..", "test", "legacy.jl"))

function parse_cli(args = ARGS)
    workers = 1
    seeds = 1:24
    z = 3.0
    mode = :all
    for i in eachindex(args)
        a = args[i]
        if a == "--workers" && i < length(args); workers = parse(Int, args[i + 1])
        elseif startswith(a, "--workers="); workers = parse(Int, split(a, "=", limit = 2)[2])
        elseif a == "--seeds" && i < length(args)
            v = args[i + 1]
            seeds = contains(v, ":") ? let p = split(v, ":"); parse(Int, p[1]):parse(Int, p[2]) end : 1:parse(Int, v)
        elseif startswith(a, "--seeds=")
            v = split(a, "=", limit = 2)[2]
            seeds = contains(v, ":") ? let p = split(v, ":"); parse(Int, p[1]):parse(Int, p[2]) end : 1:parse(Int, v)
        elseif startswith(a, "--z="); z = parse(Float64, split(a, "=", limit = 2)[2])
        elseif startswith(a, "--mode="); mode = Symbol(split(a, "=", limit = 2)[2])
        end
    end
    (workers = workers, seeds = collect(seeds), z = z, mode = mode)
end

const CLI = isempty(ARGS) || ARGS[1] == "--worker" ? (workers = 1, seeds = collect(1:24), z = 3.0, mode = :all) : parse_cli(ARGS)
const BUILD = readchomp(`git rev-parse --short HEAD`)

function world(sq::Bool; adaptive::Bool = false, open_entry::Bool = false, entrants::Int = 0)
    skills0 = draw_skills(Xoshiro(20261031), 8, 4, [1, 3]; median = 0.6)
    skills = entrants > 0 ? vcat(skills0, draw_skills(Xoshiro(20261115), entrants, 4, [1, 3]; median = 0.6)) : skills0
    na = 8 + entrants
    agents = [DomainAgent(skills[a, :], [0.5, 0, 0.5, 0], 0.3) for a in 1:na]
    deceit = vcat([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0], zeros(entrants))
    inst = sq ? (vigilance = 0.001, cost_σ = 0.3, memory_loss = 0.1, p_false_trace = 0.05, p_informed = 0.6, dil = 0.4, advap = false) :
                (vigilance = 0.1, cost_σ = 0.05, memory_loss = 0.0, p_false_trace = 0.005, p_informed = 0.95, dil = 0.95, advap = true)
    M3cParams(ToyParams(n = 80, steps = 300, plans = 10), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
              transactions = true, causal_distribution = true, p_upstream = 0.5, guardians = [1, 2, 3, 4],
              diligence = fill(inst.dil, na), p_informed = inst.p_informed, p_foresee = 1.0, repair_efficiency = 0.5,
              deceit = deceit, advap = inst.advap, vigilance = inst.vigilance, cost_σ = inst.cost_σ,
              memory_loss = inst.memory_loss, p_false_trace = inst.p_false_trace, marker_σ = 0.35, σ_leaf = 0.6, bias_σ = 0.2,
              adaptive_proposals = adaptive, open_entry = open_entry, entrants = entrants,
              events = [shock(:capture; step = 100, duration = 150, size = 1.5, target = 1)], LEGACY...)
end

function reading(sq::Bool, seed::Int; adaptive::Bool = false, open_entry::Bool = false, entrants::Int = 0)
    tr = run_m3c(world(sq; adaptive, open_entry, entrants); seed)
    sp = success_pattern(tr; from = 51)
    standing(i) = sum(tr.balance[i, :]) + tr.overflow_agent[i]
    (floor_u = sp.floor_u, floor_h = sp.floor_h, median_u = sp.median_u, median_h = sp.median_h, harm = sp.worst_drop,
     adv = (mean(standing(i) for i in 7:8) - mean(standing(i) for i in 1:6)) / (tr.endowed / 8),
     exec = Float64(length(tr.chosen_agent)), entries = Float64(tr.entries))
end

function eval_seed(seed::Int, modes)
    Dict(m.key => (bf = reading(false, seed; m.kw...), sq = reading(true, seed; m.kw...)) for m in modes)
end

function map_workers(seeds, modes, workers::Int)
    workers <= 1 && return [eval_seed(s, modes) for s in seeds]
    dir = mktempdir()
    script = abspath(@__FILE__)
    proj = abspath(joinpath(@__DIR__, ".."))
    julia = Base.julia_cmd()[1]
    res = Vector{Any}(undef, length(seeds))
    pt = progress_tracker(joinpath(@__DIR__, "state", "status_quo_economy.progress"), "status_quo_economy", length(seeds); interval = 300.0)
    done_n = 0
    next_i = 1
    active = Tuple{Int, Base.Process, String}[]
    try
        while next_i <= length(seeds) || !isempty(active)
            while next_i <= length(seeds) && length(active) < workers
                s = seeds[next_i]
                out_p = joinpath(dir, "s_$(s).jls")
                mstr = join(string.(getfield.(modes, :key)), ",")
                proc = run(`$julia --startup-file=no --project=$proj $script --worker $s $mstr $out_p`; wait = false)
                push!(active, (next_i, proc, out_p))
                next_i += 1
            end
            idx = findfirst(a -> process_exited(a[2]), active)
            if idx === nothing
                sleep(0.05)
                continue
            end
            i, proc, out_p = popat!(active, idx)
            success(proc) || error("worker failed on seed $(seeds[i])")
            res[i] = open(deserialize, out_p)
            rm(out_p; force = true)
            done_n += 1
            progress_tick!(pt, done_n, "seed $(seeds[i]) done")
        end
    finally
        progress_finish!(pt, done_n == length(seeds) ? "completed" : "stopped early")
        for (_, proc, _) in active
            process_running(proc) && kill(proc)
        end
        rm(dir; recursive = true, force = true)
    end
    res
end

const ALL_MODES = [
    (key = :closed,   label = "Closed 8-agent economy (`adaptive_proposals = false`, `open_entry = false`)",
     kw = (adaptive = false, open_entry = false, entrants = 0)),
    (key = :adaptive, label = "Adaptive proposals only (`adaptive_proposals = true`, `open_entry = false`)",
     kw = (adaptive = true, open_entry = false, entrants = 0)),
    (key = :entry,    label = "Open newcomer entry (`adaptive_proposals = true`, `open_entry = true`, `entrants = 8`)",
     kw = (adaptive = true, open_entry = true, entrants = 8)),
]

if !isempty(ARGS) && ARGS[1] == "--worker"
    seed = parse(Int, ARGS[2])
    mkeys = Symbol.(split(ARGS[3], ","))
    out_p = ARGS[4]
    sel = [m for m in ALL_MODES if m.key in mkeys]
    res = eval_seed(seed, sel)
    tmp = out_p * ".tmp"
    open(tmp, "w") do io
        serialize(io, res)
    end
    mv(tmp, out_p; force = true)
    exit(0)
end

sel_modes = CLI.mode == :all ? ALL_MODES : [m for m in ALL_MODES if m.key == CLI.mode]
t0 = time()
all_res = map_workers(CLI.seeds, sel_modes, CLI.workers)
elapsed = round((time() - t0) / 60; digits = 1)
z = CLI.z
n = length(CLI.seeds)
inf = BenefutureSim.t_inflation(n - 1)

out_path = joinpath(@__DIR__, "results", "status_quo_economy_entry.md")
open(out_path, "w") do io
    println(io, "# Status-quo baseline: economy institutions (8.115 closed vs adaptive vs open entry)")
    println(io)
    @printf(io, "Build: commit `%s`. Seeds `%d:%d` (`n = %d`); `300` steps; `z = %.1f` (Student-t inflated, required `|z_raw| >= %.2f`); run time `%.1f` minutes (`%d` workers).\n\n",
            BUILD, first(CLI.seeds), last(CLI.seeds), n, z, z * inf, elapsed, CLI.workers)
    println(io, "Pre-registered P7 (confidence 0.7, COORDINATION.md §2a): with open newcomer entry taking unmet demand (`open_entry = true`, `entrants = 8`), Benefuture's -10% `floor_u` disadvantage against status-quo institutions disappears while cutting `deceivers' advantage` sharply (`z >= 3.0`).\n")
    println(io, "Same Benefuture economy, world and seeds; institutions at Benefuture-plausible values with AdvAp (`severity = 0`), or at today's status-quo values without it. Dormant entrant slots share identical world skill distribution (`median = 0.6`, `deceit = 0.0`) and must pass existing cluster identity binding (`bind!`) to enter on unmet proposals.\n")

    for m in sel_modes
        bf = [r[m.key].bf for r in all_res]
        sq = [r[m.key].sq for r in all_res]
        println(io, "## $(m.label)\n")
        @printf(io, "Mean executed plans: `:bf` = `%.1f`, `:sq` = `%.1f`; Mean newcomers admitted (`entries`): `:bf` = `%.2f`, `:sq` = `%.2f`.\n\n",
                mean(x.exec for x in bf), mean(x.exec for x in sq), mean(x.entries for x in bf), mean(x.entries for x in sq))
        println(io, "| Reading | Benefuture | Status quo | Paired diff ± SE (`z_raw`) | Equiv ±Δ (`z=$(Int(round(z)))`) | Verdict at z = $(Int(round(z))) |")
        println(io, "|---|---|---|---|---|---|")
        for (k, name, better_low) in ((:floor_u, "Floor of understanding", false), (:floor_h, "Floor of happiness", false),
                                      (:median_u, "Median of understanding", false), (:median_h, "Median of happiness", false),
                                      (:harm, "Harm's peak", true), (:adv, "Deceivers' advantage (endowments)", true))
            d = Float64[getfield(a, k) - getfield(b, k) for (a, b) in zip(bf, sq)]
            up = paired_effect(d; z = z, direction = :up)
            dn = paired_effect(d; z = z, direction = :down)
            zraw = up.se > 0 ? up.mean / up.se : 0.0
            v = up.significant ? (better_low ? "status quo better" : "Benefuture better") :
                dn.significant ? (better_low ? "Benefuture better" : "status quo better") : "no difference shown"
            eq = (up.significant || dn.significant) ? "–" : @sprintf("±%.2f", abs(up.mean) + z * inf * up.se)
            line = @sprintf("| %s | %.2f | %.2f | %+.2f ± %.2f (`%+.2f`) | %s | %s |",
                            name, mean(getfield.(bf, k)), mean(getfield.(sq, k)), up.mean, up.se, zraw, eq, v)
            println(io, line)
            println("[$(m.key)] ", line)
        end
        println(io)
    end
end
println("Done in $(elapsed) min -> $out_path")
