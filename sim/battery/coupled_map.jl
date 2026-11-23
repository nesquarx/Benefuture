# Continuous-Coupled Break-Even + 8.115 Open-Entry & 8.164 Governed-Threshold Map (PLAN.md item 2; OPEN_PROBLEMS lines 38-39).
# Uses OS subprocesses (`--workers=N`) so Lean FFI (libbfref.dylib) is never shared across OS threads.
# Writes periodic 5-minute progress snapshots to `sim/battery/state/coupled_map.progress`.
# Run: julia --project=sim sim/battery/coupled_map.jl [--workers=8]

ENV["BF_WORLD_ONLY"] = "1"
include(joinpath(@__DIR__, "long_horizon.jl"))
using Serialization

const CM_WORKERS = parse(Int, something(let i = findfirst(a -> startswith(a, "--workers="), ARGS); i === nothing ? "1" : split(ARGS[i], "=")[2] end))
const CM_TASK = let i = findfirst(a -> startswith(a, "--task="), ARGS); i === nothing ? "" : String(split(ARGS[i], "="; limit = 2)[2]) end
const CM_SEED = let i = findfirst(a -> startswith(a, "--seed="), ARGS); i === nothing ? 0 : parse(Int, split(ARGS[i], "=")[2]) end
const CM_OUT  = let i = findfirst(a -> startswith(a, "--out-jls="), ARGS); i === nothing ? "" : String(split(ARGS[i], "="; limit = 2)[2]) end
const CM_STEPS = let i = findfirst(a -> startswith(a, "--steps="), ARGS); i === nothing ? 120 : parse(Int, split(ARGS[i], "=")[2]) end
const CM_ARM_IDX = let i = findfirst(a -> startswith(a, "--arm-idx="), ARGS); i === nothing ? 0 : parse(Int, split(ARGS[i], "=")[2]) end
const Z_CM = 3.0

function coupled_world(seed::Integer; arm::Symbol = :bf, steps::Integer = 120, open_entry::Bool = false,
                       entrants::Integer = 0, adaptive_proposals::Bool = false, p_new_model::Real = 0.01,
                       over::Dict{Symbol,Any} = Dict{Symbol,Any}(), ih::Bool = arm == :bf)
    bf = arm == :bf
    skills0 = draw_skills(Xoshiro(20261102 + seed), 12, 4, [1, 3]; median = 0.6)
    skills = entrants > 0 ? vcat(skills0, draw_skills(Xoshiro(20261115 + seed), entrants, 4, [1, 3]; median = 0.6)) : skills0
    na = 12 + entrants
    agents = [DomainAgent(skills[a, :], [0.5, 0.0, 0.5, 0.0], CALIBRATED.sloppiness) for a in 1:na]
    deceit = zeros(na); deceit[11] = 1.0; deceit[12] = 1.0
    frivolous = zeros(na); frivolous[10] = 0.5
    colluders = [1, 2, 3]
    econ = M3cParams(
        ToyParams(n = 120, steps = steps, plans = 10),
        agents, [1, 1, 2, 2], trues(4);
        init_steps = 50, λpos = 0.05, λneg = 0.02,
        transactions = true, causal_distribution = true,
        p_upstream = 0.4, guardians = [1, 2, 3, 4],
        p_hazard = 0.10, p_side = 0.02, repair_efficiency = 0.5,
        deceit = deceit, on_off = 25, frivolous = frivolous, slander = zeros(Int, na),
        p_new_model = Float64(p_new_model), events = world_events(:stressed; steps = steps),
        accuracy_rule = bf ? :decay : :window,
        advap = bf,
        ratchet_k = bf ? 3 : 0,
        credence_rule = bf ? :eb : :normal,
        bind_weighted = bf,
        open_entry = open_entry,
        entrants = entrants,
        adaptive_proposals = adaptive_proposals,
        over...
    )
    gov(trace) = M5Params(trace, 1:4; decisions = 60, colluders = colluders, stealth = true,
                          loyalty = 2.0, p_delegate = 0.2, p_new_model = Float64(p_new_model), advap = bf, ih_flags(ih)...)
    (econ = econ, gov = gov)
end

function run_cm_breakeven(steps::Integer, seed::Integer)
    m5_dec = max(60, steps ÷ 2)
    function eval_arm(; arm::Symbol, oe::Bool = false, ent::Int = 0, adap::Bool = false)
        w = coupled_world(seed; arm = arm, steps = steps, open_entry = oe, entrants = ent, adaptive_proposals = adap)
        res = run_coupled(w.econ, w.gov; seed = seed, epoch = 24, coupled = true, m5_decisions = m5_dec, continuous = true)
        sp = res.success
        et = res.econ_trace
        (floor_u = sp.floor_u, floor_h = sp.floor_h, median_u = sp.median_u, median_h = sp.median_h,
         worst_drop = sp.worst_drop, gov_acc = res.gov_acc, entries = Float64(et.entries))
    end
    (
        bf_closed = eval_arm(; arm = :bf),
        bf_open   = eval_arm(; arm = :bf, oe = true, ent = 8, adap = true),
        sq_closed = eval_arm(; arm = :status_quo),
    )
end

const CM_THRESH_ARMS = [
    (:ratchet_horizon, 5.0), (:ratchet_horizon, 40.0), (:ratchet_horizon, 100.0),
    (:model_z, 1.0), (:model_z, 4.0), (:model_z, 10.0),
    (:acc_halflife, 1.75), (:acc_halflife, 28.0),
    (:threshold, 0.45), (:threshold, 0.99),
    (:adv_z, 1.5), (:adv_z, 6.0),
    (:pattern_attention, 2.25), (:pattern_attention, 45.0),
    (:adv_min_records, 1), (:adv_min_records, 25),
    (:min_records, 1), (:min_records, 50),
]

function eval_coupled_threshold(over::Dict{Symbol,Any}, seed::Integer)
    w = coupled_world(seed; arm = :bf, steps = 600, p_new_model = 0.05, over = over)
    res = run_coupled(w.econ, w.gov; seed = seed, epoch = 25, coupled = true, m5_decisions = 60, continuous = true)
    sp = res.success
    et = res.econ_trace
    standing(i) = sum(et.balance[i, :]) + et.overflow_agent[i]
    adv = (mean(standing(i) for i in 11:12) - mean(standing(i) for i in 1:10)) / (et.endowed / 12)
    (floor_u = sp.floor_u, floor_h = sp.floor_h, median_u = sp.median_u, harm = sp.worst_drop,
     gov_acc = res.gov_acc, adv = adv,
     takeovers = Float64(et.takeovers), audits = Float64(et.advap_audits),
     established = Float64(et.advap_established), bars = Float64(sum(et.leaf_bars)),
     lane = Float64(et.lane_executed))
end

if CM_TASK == "breakeven"
    serialize(CM_OUT, run_cm_breakeven(CM_STEPS, CM_SEED))
elseif CM_TASK == "thresh_base"
    serialize(CM_OUT, eval_coupled_threshold(Dict{Symbol,Any}(), CM_SEED))
elseif CM_TASK == "thresh_arm"
    f, v = CM_THRESH_ARMS[CM_ARM_IDX]
    serialize(CM_OUT, eval_coupled_threshold(Dict{Symbol,Any}(f => v), CM_SEED))
else
    function run_main()
        t0 = time()
        commit = current_commit()
        prog_path = joinpath(@__DIR__, "state", "coupled_map.progress")
        mkpath(dirname(prog_path))
        HORIZONS = [120, 240, 360, 480, 600]
        BE_SEEDS = collect(1:24)
        TH_SEEDS = collect(1:16)
        total_units = length(HORIZONS) * length(BE_SEEDS) + (1 + length(CM_THRESH_ARMS)) * length(TH_SEEDS)
        pt = progress_tracker(prog_path, "coupled_map", total_units; interval = 300.0)
        done_cnt = Threads.Atomic{Int}(0)

        function spawn_jobs(jobs)
            tmpdir = mktempdir()
            outs = Vector{Any}(undef, length(jobs))
            next_i = Threads.Atomic{Int}(1)
            script = @__FILE__
            proj = joinpath(@__DIR__, "..")
            @sync for _ in 1:min(CM_WORKERS, length(jobs))
                Threads.@spawn while true
                    i = Threads.atomic_add!(next_i, 1)
                    i > length(jobs) && break
                    job = jobs[i]
                    out = joinpath(tmpdir, "job_$i.jls")
                    cmd = Cmd(vcat(Base.julia_cmd().exec, ["--project=$proj", script, job.args..., "--out-jls=$out"]))
                    Base.run(cmd)
                    outs[i] = deserialize(out)
                    n = Threads.atomic_add!(done_cnt, 1) + 1
                    progress_tick!(pt, n, job.label)
                end
            end
            rm(tmpdir; recursive = true, force = true)
            outs
        end

        println("Running coupled_map (workers=$CM_WORKERS, total units=$total_units)...")
        flush(stdout)

        be_jobs = [(args = ["--task=breakeven", "--steps=$h", "--seed=$s"], label = "breakeven h=$h s=$s")
                   for h in HORIZONS for s in BE_SEEDS]
        be_flat = spawn_jobs(be_jobs)
        be_res = Dict{Int,Vector{Any}}(h => Any[] for h in HORIZONS)
        idx = 0
        for h in HORIZONS, _ in BE_SEEDS
            idx += 1
            push!(be_res[h], be_flat[idx])
        end

        th_base_jobs = [(args = ["--task=thresh_base", "--seed=$s"], label = "thresh base s=$s") for s in TH_SEEDS]
        th_base = spawn_jobs(th_base_jobs)

        th_arm_jobs = [(args = ["--task=thresh_arm", "--arm-idx=$ai", "--seed=$s"], label = "thresh arm=$ai s=$s")
                       for ai in eachindex(CM_THRESH_ARMS) for s in TH_SEEDS]
        th_flat = spawn_jobs(th_arm_jobs)
        th_res = [Any[] for _ in eachindex(CM_THRESH_ARMS)]
        idx = 0
        for ai in eachindex(CM_THRESH_ARMS), _ in TH_SEEDS
            idx += 1
            push!(th_res[ai], th_flat[idx])
        end

        progress_finish!(pt, "completed")
        elapsed = (time() - t0) / 60

        csv_rows = ["section,item,comparison,n,mean_diff,se,z_raw,significant_z3,extra"]
        md = IOBuffer()
        println(md, "# Continuous-Coupled Break-Even & Threshold Map (`z = 3.0`, Student-t inflated)")
        @printf(md, "\n- **Commit**: `%s` · **Runtime**: `%.1f min` · **Workers**: `%d`\n\n", commit, elapsed, CM_WORKERS)

        println(md, "## 1. Coupled Break-Even & Open-Entry Horizons (`10yr..50yr`, `1:24` seeds, `:stressed`, `epoch = 24`)")
        println(md, "| Horizon (`steps`) | Arm Pair | `floor_u` Δ ± SE (`z_raw`, `z>=3`) | `floor_h` Δ ± SE (`z_raw`, `z>=3`) | `median_u` Δ ± SE | `gov_acc` Δ ± SE | `entries` (`bf_open`) |")
        println(md, "|---|---|---|---|---|---|---|")
        for h in HORIZONS
            rs = be_res[h]
            for (lbl, get_a, get_b, key) in [
                ("`:bf_closed - :sq_closed`", r -> r.bf_closed, r -> r.sq_closed, "closed_vs_sq"),
                ("`:bf_open - :sq_closed`",   r -> r.bf_open,   r -> r.sq_closed, "open_vs_sq"),
            ]
                du = [get_a(r).floor_u - get_b(r).floor_u for r in rs]
                dh = [get_a(r).floor_h - get_b(r).floor_h for r in rs]
                dm = [get_a(r).median_u - get_b(r).median_u for r in rs]
                dg = [get_a(r).gov_acc - get_b(r).gov_acc for r in rs]
                pu = paired_effect(du; z = Z_CM); ph = paired_effect(dh; z = Z_CM)
                pm = paired_effect(dm; z = Z_CM); pg = paired_effect(dg; z = Z_CM)
                zu = pu.mean / max(pu.se, 1e-12); zh = ph.mean / max(ph.se, 1e-12)
                ent_m = mean(r.bf_open.entries for r in rs)
                @printf(md, "| `%d` (`%dyr`) | %s | %+.2f ± %.2f (`%.2f`, %s) | %+.2f ± %.2f (`%.2f`, %s) | %+.2f ± %.2f | %+.4f ± %.4f | %.2f |\n",
                        h, h ÷ 12, lbl, pu.mean, pu.se, zu, pu.significant ? "yes" : "no",
                        ph.mean, ph.se, zh, ph.significant ? "yes" : "no",
                        pm.mean, pm.se, pg.mean, pg.se, ent_m)
                push!(csv_rows, @sprintf("breakeven,h_%d,%s_floor_u,%d,%.6f,%.6f,%.3f,%s,entries=%.2f",
                                         h, key, pu.n, pu.mean, pu.se, zu, pu.significant, ent_m))
                push!(csv_rows, @sprintf("breakeven,h_%d,%s_floor_h,%d,%.6f,%.6f,%.3f,%s,entries=%.2f",
                                         h, key, ph.n, ph.mean, ph.se, zh, ph.significant, ent_m))
            end
        end
        println(md)

        println(md, "## 2. Composed 50-Year Coupled Governed-Threshold Map (`600` steps, `epoch = 25`, `1:16` seeds, `8.164` touch check)")
        println(md, "| Threshold | Setting | Touch | `floor_u` Δ | `floor_h` Δ | `median_u` Δ | `harm` Δ | `adv` Δ | Verdict |")
        println(md, "|---|---|---|---|---|---|---|---|---|")
        TOUCH_CM = (:takeovers, :audits, :established, :bars, :lane)
        KEYS_CM = (:floor_u, :floor_h, :median_u, :harm, :adv)
        for (ai, (f, v)) in enumerate(CM_THRESH_ARMS)
            rs = th_res[ai]
            top_t = (diff = 0.0, name = "")
            for tk in TOUCH_CM
                td = maximum(abs(getfield(rs[i], tk) - getfield(th_base[i], tk)) for i in eachindex(TH_SEEDS))
                td > top_t.diff && (top_t = (diff = td, name = string(tk)))
            end
            max_out = maximum(maximum(abs(getfield(rs[i], k) - getfield(th_base[i], k)) for k in KEYS_CM) for i in eachindex(TH_SEEDS))
            touched = top_t.diff > 0 || max_out > 1e-9
            touch_s = touched ? (top_t.diff > 0 ? @sprintf("yes (%s %.0f)", top_t.name, top_t.diff) : @sprintf("yes (out %.2g)", max_out)) : "NONE (0)"
            good = 0; bad = 0; cells = String[]
            for k in KEYS_CM
                d = [getfield(rs[i], k) - getfield(th_base[i], k) for i in eachindex(TH_SEEDS)]
                pp = paired_effect(d; z = Z_CM, direction = :up)
                pn = paired_effect(d; z = Z_CM, direction = :down)
                mark = pp.significant ? "+" : pn.significant ? "−" : ""
                better = k in (:harm, :adv) ? pn.significant : pp.significant
                worse  = k in (:harm, :adv) ? pp.significant : pn.significant
                good += better; bad += worse
                push!(cells, @sprintf("%.2f%s", pp.mean, mark))
                k in (:floor_u, :adv) && push!(csv_rows, @sprintf("thresholds,%s_%g,%s,%d,%.6f,%.6f,%.3f,%s,touched=%s",
                                                                   f, Float64(v), k, pp.n, pp.mean, pp.se, pp.mean / max(pp.se, 1e-12),
                                                                   pp.significant || pn.significant, touched))
            end
            verdict = !touched ? "inconsequential" :
                      (good > 0 && bad > 0) ? "tradeoff" :
                      bad > 0 ? "worse" :
                      good > 0 ? "candidate" : "no effect"
            @printf(md, "| `%s` | `%g` | %s | %s | %s | %s | %s | %s | %s |\n",
                    f, Float64(v), touch_s, cells[1], cells[2], cells[3], cells[4], cells[5], verdict)
        end

        write(joinpath(@__DIR__, "results", "coupled_map.md"), String(take!(md)))
        write(joinpath(@__DIR__, "results", "coupled_map.csv"), join(csv_rows, "\n") * "\n")
        println("Coupled break-even & threshold map finished in $(round(elapsed; digits = 1)) min -> sim/battery/results/coupled_map.{md,csv}")
    end
    run_main()
end

