# 10-year coupled economy vs status quo with author ruling 8.136 active
# (`converge_init = true`, `legacy_funder = true`, `shadow = true`).
#
# Pre-registered predictions (COORDINATION.md §2a, 2026-11-15, before running):
#   - P5 (confidence 0.6): the 10-year `floor_u` difference (`:bf_8136` minus `:status_quo`)
#     becomes significant at `z >= 3.0` (Student-t inflated).
#   - P6 (confidence 0.7): the early dip in the first two years (steps 1..24) shrinks relative
#     to baseline `:bf_base` (and `:status_quo`).
#   - If P5 fails: inspect the year-by-year trajectory (Years 1..10) to locate where Benefuture
#     falls behind (do not tune).
#
# Run:
#   julia --project=sim sim/battery/ten_year_8136.jl --workers=7

using BenefutureSim, Statistics, Random, Printf, Dates, Serialization

ENV["BF_WORLD_ONLY"] = "1"
include(joinpath(@__DIR__, "long_horizon.jl"))

const COMMIT = readchomp(`git rev-parse --short HEAD`)
out_md(tag::AbstractString) = joinpath(@__DIR__, "results", isempty(tag) ? "ten_year_8136.md" : "ten_year_8136_$(tag).md")
out_csv(tag::AbstractString) = joinpath(@__DIR__, "results", isempty(tag) ? "ten_year_8136.csv" : "ten_year_8136_$(tag).csv")

const STEPS = 120
const EPOCH = 24
const M5_DEC = 120
const TARGET_SE = 1.5   # stop when t-inflated SE of paired floor_u diff <= 1.5 (min..max)
const MIN_SEEDS = 16
const MAX_SEEDS = 64

function with_econ_over(p::M3cParams, over::Dict{Symbol, Any})
    M3cParams((get(over, f, getfield(p, f)) for f in fieldnames(M3cParams))...)
end

function extract_summary(tr)
    sp = tr.success
    fu0, fh0, mu0, mh0 = tr.floor_u[1], tr.floor_h[1], tr.median_u[1], tr.median_h[1]
    yr_fu = Float64[tr.floor_u[12y + 1] - fu0 for y in 1:10]
    yr_fh = Float64[tr.floor_h[12y + 1] - fh0 for y in 1:10]
    yr_mu = Float64[tr.median_u[12y + 1] - mu0 for y in 1:10]
    early_fu = tr.floor_u[1:25] .- fu0
    early_fh = tr.floor_h[1:25] .- fh0
    (
        floor_u = sp.floor_u,
        floor_h = sp.floor_h,
        median_u = sp.median_u,
        median_h = sp.median_h,
        worst_drop = sp.worst_drop,
        gov_acc = tr.gov_acc,
        early_dip_u = max(0.0, -minimum(early_fu)),
        early_dip_h = max(0.0, -minimum(early_fh)),
        early_worst_drop = maximum(tr.worst_drop[1:25]),
        yr2_fu = early_fu[end],
        yr2_fh = early_fh[end],
        yr_fu = yr_fu,
        yr_fh = yr_fh,
        yr_mu = yr_mu,
        converged = tr.converged,
        converge_step = tr.converge_step,
        legacy_executed = tr.legacy_executed,
        shadow_promoted = tr.shadow_promoted,
    )
end

function eval_seed(seed::Integer)
    out = NamedTuple[]
    for stress in (:stressed, :unstressed)
        w_bf = world(seed; arm = :bf, stress = stress, steps = STEPS, decisions = M5_DEC)
        w_sq = world(seed; arm = :status_quo, stress = stress, steps = STEPS, decisions = M5_DEC)
        e_8136  = with_econ_over(w_bf.econ, Dict{Symbol, Any}(:converge_init => true, :legacy_funder => true))
        e_bf50  = with_econ_over(w_bf.econ, Dict{Symbol, Any}(:legacy_funder => true))
        e_sq50  = with_econ_over(w_sq.econ, Dict{Symbol, Any}(:legacy_funder => true))
        tr_8136 = run_coupled(e_8136, w_bf.gov; seed = seed, epoch = EPOCH,
                              coupled = true, m5_decisions = M5_DEC, continuous = true, shadow = true)
        tr_base = run_coupled(w_bf.econ, w_bf.gov; seed = seed, epoch = EPOCH,
                              coupled = true, m5_decisions = M5_DEC, continuous = true, shadow = false)
        tr_sq   = run_coupled(w_sq.econ, w_sq.gov; seed = seed, epoch = EPOCH,
                              coupled = true, m5_decisions = M5_DEC, continuous = true, shadow = false)
        tr_bf50 = run_coupled(e_bf50, w_bf.gov; seed = seed, epoch = EPOCH,
                              coupled = true, m5_decisions = M5_DEC, continuous = true, shadow = true)
        tr_sq50 = run_coupled(e_sq50, w_sq.gov; seed = seed, epoch = EPOCH,
                              coupled = true, m5_decisions = M5_DEC, continuous = true, shadow = false)
        push!(out, (stress = stress, bf_8136 = extract_summary(tr_8136),
                    bf_base = extract_summary(tr_base), sq = extract_summary(tr_sq),
                    bf_leg50 = extract_summary(tr_bf50), sq_leg50 = extract_summary(tr_sq50)))
    end
    (stressed = out[1], unstressed = out[2])
end

function run_worker_entry()
    seed = parse(Int, ARGS[2])
    out_path = ARGS[3]
    res = eval_seed(seed)
    tmp = out_path * ".tmp"
    open(tmp, "w") do io
        serialize(io, res)
    end
    mv(tmp, out_path; force = true)
    exit(0)
end

function map_workers(seeds, workers::Int)
    workers <= 1 && return [eval_seed(s) for s in seeds]
    dir = mktempdir()
    script = abspath(@__FILE__)
    proj = abspath(joinpath(@__DIR__, ".."))
    julia = Base.julia_cmd()[1]
    res = Vector{Any}(undef, length(seeds))
    next_i = 1
    active = Tuple{Int, Base.Process, String}[]
    try
        while next_i <= length(seeds) || !isempty(active)
            while next_i <= length(seeds) && length(active) < workers
                s = seeds[next_i]
                out_p = joinpath(dir, "seed_$(s).jls")
                cmd = `$julia --startup-file=no --project=$proj $script --worker $s $out_p`
                proc = run(cmd; wait = false)
                push!(active, (next_i, proc, out_p))
                next_i += 1
            end
            idx = findfirst(a -> process_exited(a[2]), active)
            if idx === nothing
                sleep(0.1)
                continue
            end
            i, proc, out_p = popat!(active, idx)
            success(proc) || error("worker failed on seed $(seeds[i]) (exit $(proc.exitcode))")
            res[i] = open(deserialize, out_p)
            rm(out_p; force = true)
        end
    finally
        for (_, proc, _) in active
            process_running(proc) && kill(proc)
        end
        rm(dir; recursive = true, force = true)
    end
    res
end

function paired_stats(a::AbstractVector{<:Real}, b::AbstractVector{<:Real}; z::Real = 3.0)
    mask = isfinite.(a) .& isfinite.(b)
    aa = Float64.(a[mask])
    bb = Float64.(b[mask])
    if length(aa) < 2
        return (n = length(aa), mean_a = isempty(aa) ? NaN : mean(aa), mean_b = isempty(bb) ? NaN : mean(bb),
                diff = NaN, se = NaN, se_t = Inf, z = 0.0, z_req = NaN, ci_lo = NaN, ci_hi = NaN,
                sig_up = false, sig_dn = false, sig = "n<2")
    end
    d = aa .- bb
    up = paired_effect(d; z = z, direction = :up)
    dn = paired_effect(d; z = z, direction = :down)
    n = up.n
    inf = BenefutureSim.t_inflation(n - 1)
    se = up.se
    zval = se > 0 ? up.mean / se : 0.0
    sig = up.significant ? "yes (+)" : dn.significant ? "yes (-)" : "no"
    ci_lo = up.mean - z * inf * se
    ci_hi = up.mean + z * inf * se
    (n = n, mean_a = mean(aa), mean_b = mean(bb), diff = up.mean, se = se, se_t = se * inf,
     z = zval, z_req = z * inf, ci_lo = ci_lo, ci_hi = ci_hi, sig_up = up.significant,
     sig_dn = dn.significant, sig = sig)
end

function write_report(rows, elapsed_min; min_seeds = MIN_SEEDS, max_seeds = MAX_SEEDS, stopped_early = false, tag::AbstractString = "")
    s_stress = [r.stressed for r in rows]
    s_unstress = [r.unstressed for r in rows]
    n = length(rows)

    csv_rows = String["group,metric,comparison,n,mean_a,mean_b,diff,se,z,z_req,ci_lo,ci_hi,sig_z3"]
    md = IOBuffer()
    println(md, "# 10-Year Coupled Economy with Author Ruling 8.136 On")
    println(md)
    @printf(md, "- **Build**: commit `%s`. Horizon: `%d` steps (`10` years), `epoch = %d` (`2` years), `m5_decisions = %d`, `continuous = true`.\n",
            COMMIT, STEPS, EPOCH, M5_DEC)
    @printf(md, "- **Seeds**: `1:%d` paired seeds (`min = %d`, `max = %d`, stopping when t-inflated SE of `floor_u(bf_8136 - sq) <= %.2f` in both `:stressed` and `:unstressed`; stopped_early = `%s`). Run time: `%.1f` minutes.\n",
            n, min_seeds, max_seeds, TARGET_SE, string(stopped_early), elapsed_min)
    println(md, "- **Arms**: `:bf_8136` (`:bf` + `converge_init = true`, `legacy_funder = true`, `shadow = true`), `:bf_base` (`long_horizon.jl` default `:bf`), `:status_quo` (`long_horizon.jl` default `:status_quo`), plus warmup-matched controls `:bf_leg50` (`:bf` + `init_steps = 50`, `legacy_funder = true`, `shadow = true`) and `:sq_leg50` (`:status_quo` + `init_steps = 50`, `legacy_funder = true`).")
    println(md, "- **Significance Bar**: `z = 3.0` Student-t inflated (two-sided reported as `yes (+)` / `yes (-)`, 99.7% Student-t CI `[ci_lo, ci_hi]`).")
    println(md)
    println(md, "## Pre-registered Predictions (stated before running)")
    println(md, "- **P5 (confidence 0.6)**: The 10-year `floor_u` difference (`:bf_8136` minus `:status_quo`) becomes significant at `z >= 3` (`z * t_inflation`).")
    println(md, "- **P6 (confidence 0.7)**: The early dip in the first two years (`steps 1..24`) shrinks under `:bf_8136` relative to `:bf_base` (and `:status_quo`).")
    println(md, "- **P8 (confidence 0.85, active-leaf unblocked)**: With `domain_converged` gating on active known leaves (`m3c.jl`), `:bf_8136` exits the `0/64` sparse-focus deadlock and converges on a majority (`> 50%`) of seeds before step 120.")
    println(md, "- **P9 (confidence 0.55, live graduation)**: Dynamic graduation around `converge_step` preserves the Y1–2 early-dip reduction (`< bf_base`) while finishing higher or indistinguishable vs warmup-matched `:sq_leg50` over 10 years.")
    println(md, "- **Diagnostic on failure**: If P5 fails, inspect the year-by-year trajectory (`Years 1..10`) to identify where Benefuture diverges (no tuning).")
    println(md)

    # 8.136 activation diagnostics
    println(md, "## 8.136 Activation & Diagnostics (`:bf_8136` and `:bf_leg50`)")
    for (slabel, arr) in (("Stressed", s_stress), ("Unstressed", s_unstress))
        conv_n = count(x -> x.bf_8136.converged, arr)
        csteps = [x.bf_8136.converge_step for x in arr if x.bf_8136.converged]
        leg_n = mean(x.bf_8136.legacy_executed for x in arr)
        sh_n = count(x -> x.bf_8136.shadow_promoted, arr)
        leg50_bf = mean(x.bf_leg50.legacy_executed for x in arr)
        sh50_bf = count(x -> x.bf_leg50.shadow_promoted, arr)
        leg50_sq = mean(x.sq_leg50.legacy_executed for x in arr)
        @printf(md, "- **%s `:bf_8136`**: converged `%d / %d` (mean `converge_step = %.1f`), mean `legacy_executed = %.1f`, `shadow_promoted = %d / %d`.\n",
                slabel, conv_n, n, isempty(csteps) ? NaN : mean(csteps), leg_n, sh_n, n)
        @printf(md, "- **%s `:bf_leg50` vs `:sq_leg50`**: mean `legacy_executed = %.1f` vs `%.1f` (`init_steps = 50`), `:bf_leg50` `shadow_promoted = %d / %d`.\n",
                slabel, leg50_bf, leg50_sq, sh50_bf, n)
    end
    println(md)

    metrics_10yr = [
        (:floor_u,    "Floor U (`floor_u`)",       "%.3f"),
        (:floor_h,    "Floor H (`floor_h`)",       "%.3f"),
        (:median_u,   "Median U (`median_u`)",     "%.3f"),
        (:median_h,   "Median H (`median_h`)",     "%.3f"),
        (:worst_drop, "Worst drop (`worst_drop`)", "%.3f"),
        (:gov_acc,    "Governance acc (`gov_acc`)", "%.4f"),
    ]
    comps = [
        ("bf8136_vs_sq",       ":bf_8136 vs :status_quo", r -> r.bf_8136,  r -> r.sq),
        ("bf8136_vs_bfbase",   ":bf_8136 vs :bf_base",    r -> r.bf_8136,  r -> r.bf_base),
        ("bfbase_vs_sq",       ":bf_base vs :status_quo", r -> r.bf_base,  r -> r.sq),
        ("bfleg50_vs_sqleg50", ":bf_leg50 vs :sq_leg50",  r -> r.bf_leg50, r -> r.sq_leg50),
        ("bf8136_vs_sqleg50",  ":bf_8136 vs :sq_leg50",   r -> r.bf_8136,  r -> r.sq_leg50),
    ]

    for (slabel, arr) in (("Stressed", s_stress), ("Unstressed", s_unstress))
        @printf(md, "## 10-Year Endpoint Comparisons — %s (`1:%d` seeds)\n\n", slabel, n)
        for (ckey, clabel, ga, gb) in comps
            @printf(md, "### %s (%s)\n\n", clabel, slabel)
            println(md, "| Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |")
            println(md, "|---|---|---|---|---|---|---|")
            for (mkey, mlabel, fmt) in metrics_10yr
                va = Float64[getfield(ga(r), mkey) for r in arr]
                vb = Float64[getfield(gb(r), mkey) for r in arr]
                st = paired_stats(va, vb; z = 3.0)
                @printf(md, "| %s | %.3f | %.3f | %+.3f ± %.3f | %+.2f (%.2f) | [%+.3f, %+.3f] | %s |\n",
                        mlabel, st.mean_a, st.mean_b, st.diff, st.se, st.z, st.z_req, st.ci_lo, st.ci_hi, st.sig)
                push!(csv_rows, @sprintf("endpoint_%s,%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.4f,%.4f,%.6f,%.6f,%s",
                                         lowercase(slabel), string(mkey), ckey, st.n, st.mean_a, st.mean_b, st.diff,
                                         st.se, st.z, st.z_req, st.ci_lo, st.ci_hi, st.sig))
            end
            println(md)
        end
    end

    # P6 Early-dip metrics (first two years: steps 1..24)
    early_metrics = [
        (:early_dip_u,      "Early floor U dip (`max(0, u0 - min u[1:24])`)"),
        (:early_dip_h,      "Early floor H dip (`max(0, h0 - min h[1:24])`)"),
        (:early_worst_drop, "Early worst single-being drop (`max worst_drop[1:24]`)"),
        (:yr2_fu,           "Year-2 net Floor U (`u[24] - u0`)"),
        (:yr2_fh,           "Year-2 net Floor H (`h[24] - h0`)"),
    ]
    println(md, "## P6: Early-Dip Comparisons (First Two Years, `steps 1..24`)\n")
    for (slabel, arr) in (("Stressed", s_stress), ("Unstressed", s_unstress))
        for (ckey, clabel, ga, gb) in comps[[1, 2, 4, 5]]
            @printf(md, "### %s — %s\n\n", clabel, slabel)
            println(md, "| Early Metric | Mean A | Mean B | Paired Diff ± SE | `z` (req `z*t`) | 99.7% t-CI | Sig (`z>=3`) |")
            println(md, "|---|---|---|---|---|---|---|")
            for (mkey, mlabel) in early_metrics
                va = Float64[getfield(ga(r), mkey) for r in arr]
                vb = Float64[getfield(gb(r), mkey) for r in arr]
                st = paired_stats(va, vb; z = 3.0)
                @printf(md, "| %s | %.3f | %.3f | %+.3f ± %.3f | %+.2f (%.2f) | [%+.3f, %+.3f] | %s |\n",
                        mlabel, st.mean_a, st.mean_b, st.diff, st.se, st.z, st.z_req, st.ci_lo, st.ci_hi, st.sig)
                push!(csv_rows, @sprintf("early_%s,%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.4f,%.4f,%.6f,%.6f,%s",
                                         lowercase(slabel), string(mkey), ckey, st.n, st.mean_a, st.mean_b, st.diff,
                                         st.se, st.z, st.z_req, st.ci_lo, st.ci_hi, st.sig))
            end
            println(md)
        end
    end

    # Year-by-year trajectory diagnostic (Years 1..10)
    println(md, "## Year-by-Year Floor U Trajectory (`Years 1..10`, Cumulative Growth & Annual Δ)\n")
    for (slabel, arr) in (("Stressed", s_stress), ("Unstressed", s_unstress))
        @printf(md, "### %s — `:bf_8136` vs `:status_quo` (and `:bf_base`)\n\n", slabel)
        println(md, "| Year (Step) | `:bf_8136` Cum | `:bf_base` Cum | `:sq` Cum | `8136 − SQ` Cum ± SE (`z`) | Annual Δ `8136` | Annual Δ `SQ` | Annual Δ `8136 − SQ` ± SE (`z`) |")
        println(md, "|---|---|---|---|---|---|---|---|")
        for y in 1:10
            c8136 = Float64[r.bf_8136.yr_fu[y] for r in arr]
            cbase = Float64[r.bf_base.yr_fu[y] for r in arr]
            csq   = Float64[r.sq.yr_fu[y] for r in arr]
            d8136 = y == 1 ? c8136 : Float64[r.bf_8136.yr_fu[y] - r.bf_8136.yr_fu[y - 1] for r in arr]
            dsq   = y == 1 ? csq   : Float64[r.sq.yr_fu[y] - r.sq.yr_fu[y - 1] for r in arr]
            sc = paired_stats(c8136, csq; z = 3.0)
            sd = paired_stats(d8136, dsq; z = 3.0)
            @printf(md, "| Y%d (%d) | %.2f | %.2f | %.2f | %+.2f ± %.2f (%+.2f) | %+.2f | %+.2f | %+.2f ± %.2f (%+.2f) |\n",
                    y, 12y, sc.mean_a, mean(cbase), sc.mean_b, sc.diff, sc.se, sc.z,
                    sd.mean_a, sd.mean_b, sd.diff, sd.se, sd.z)
            push!(csv_rows, @sprintf("traj_cum_%s,year_%02d_floor_u,bf8136_vs_sq,%d,%.6f,%.6f,%.6f,%.6f,%.4f,%.4f,%.6f,%.6f,%s",
                                     lowercase(slabel), y, sc.n, sc.mean_a, sc.mean_b, sc.diff, sc.se, sc.z, sc.z_req, sc.ci_lo, sc.ci_hi, sc.sig))
            push!(csv_rows, @sprintf("traj_ann_%s,year_%02d_dfloor_u,bf8136_vs_sq,%d,%.6f,%.6f,%.6f,%.6f,%.4f,%.4f,%.6f,%.6f,%s",
                                     lowercase(slabel), y, sd.n, sd.mean_a, sd.mean_b, sd.diff, sd.se, sd.z, sd.z_req, sc.ci_lo, sd.ci_hi, sd.sig))
        end
        println(md)
        @printf(md, "### %s — Warmup-Matched `:bf_leg50` vs `:sq_leg50` (`init_steps = 50`, `legacy_funder = true`)\n\n", slabel)
        println(md, "| Year (Step) | `:bf_leg50` Cum | `:sq_leg50` Cum | `bf_leg50 − sq_leg50` Cum ± SE (`z`) | Annual Δ `bf_leg50` | Annual Δ `sq_leg50` | Annual Δ Diff ± SE (`z`) |")
        println(md, "|---|---|---|---|---|---|---|")
        for y in 1:10
            ca = Float64[r.bf_leg50.yr_fu[y] for r in arr]
            cb = Float64[r.sq_leg50.yr_fu[y] for r in arr]
            da = y == 1 ? ca : Float64[r.bf_leg50.yr_fu[y] - r.bf_leg50.yr_fu[y - 1] for r in arr]
            db = y == 1 ? cb : Float64[r.sq_leg50.yr_fu[y] - r.sq_leg50.yr_fu[y - 1] for r in arr]
            sc = paired_stats(ca, cb; z = 3.0)
            sd = paired_stats(da, db; z = 3.0)
            @printf(md, "| Y%d (%d) | %.2f | %.2f | %+.2f ± %.2f (%+.2f) | %+.2f | %+.2f | %+.2f ± %.2f (%+.2f) |\n",
                    y, 12y, sc.mean_a, sc.mean_b, sc.diff, sc.se, sc.z,
                    sd.mean_a, sd.mean_b, sd.diff, sd.se, sd.z)
            push!(csv_rows, @sprintf("traj_cum_%s,year_%02d_floor_u,bfleg50_vs_sqleg50,%d,%.6f,%.6f,%.6f,%.6f,%.4f,%.4f,%.6f,%.6f,%s",
                                     lowercase(slabel), y, sc.n, sc.mean_a, sc.mean_b, sc.diff, sc.se, sc.z, sc.z_req, sc.ci_lo, sc.ci_hi, sc.sig))
            push!(csv_rows, @sprintf("traj_ann_%s,year_%02d_dfloor_u,bfleg50_vs_sqleg50,%d,%.6f,%.6f,%.6f,%.6f,%.4f,%.4f,%.6f,%.6f,%s",
                                     lowercase(slabel), y, sd.n, sd.mean_a, sd.mean_b, sd.diff, sd.se, sd.z, sd.z_req, sd.ci_lo, sd.ci_hi, sd.sig))
        end
        println(md)
    end

    open(out_md(tag), "w") do io; write(io, String(take!(md))); end
    open(out_csv(tag), "w") do io; foreach(r -> println(io, r), csv_rows); end
end

function main()
    workers = 7
    min_s, max_s = MIN_SEEDS, MAX_SEEDS
    tag = ""
    i = 1
    while i <= length(ARGS)
        if ARGS[i] == "--workers" && i < length(ARGS); workers = parse(Int, ARGS[i+1]); i += 2
        elseif startswith(ARGS[i], "--workers="); workers = parse(Int, split(ARGS[i], "=", limit = 2)[2]); i += 1
        elseif ARGS[i] == "--max" && i < length(ARGS); max_s = parse(Int, ARGS[i+1]); i += 2
        elseif startswith(ARGS[i], "--max="); max_s = parse(Int, split(ARGS[i], "=", limit = 2)[2]); i += 1
        elseif ARGS[i] == "--min" && i < length(ARGS); min_s = parse(Int, ARGS[i+1]); i += 2
        elseif startswith(ARGS[i], "--min="); min_s = parse(Int, split(ARGS[i], "=", limit = 2)[2]); i += 1
        elseif ARGS[i] == "--tag" && i < length(ARGS); tag = ARGS[i+1]; i += 2
        elseif startswith(ARGS[i], "--tag="); tag = split(ARGS[i], "=", limit = 2)[2]; i += 1
        else; i += 1
        end
    end

    t0 = time()
    all_rows = Any[]
    stopped_early = false
    next_seed = 1
    first_batch = min(max_s, max(min_s, workers * ((min_s + workers - 1) ÷ workers)))
    if first_batch > 0
        append!(all_rows, map_workers(collect(next_seed:first_batch), workers))
        next_seed = first_batch + 1
    end

    while true
        n = length(all_rows)
        st_s = paired_stats([r.stressed.bf_8136.floor_u for r in all_rows], [r.stressed.sq.floor_u for r in all_rows])
        st_u = paired_stats([r.unstressed.bf_8136.floor_u for r in all_rows], [r.unstressed.sq.floor_u for r in all_rows])
        write_report(all_rows, (time() - t0) / 60; min_seeds = min_s, max_seeds = max_s, stopped_early = false, tag = tag)
        @printf("[n=%d] stressed diff=%.3f ± %.3f (t-SE=%.3f, z=%.2f); unstressed diff=%.3f ± %.3f (t-SE=%.3f, z=%.2f)\n",
                n, st_s.diff, st_s.se, st_s.se_t, st_s.z, st_u.diff, st_u.se, st_u.se_t, st_u.z)
        flush(stdout)
        if n >= min_s && st_s.se_t <= TARGET_SE && st_u.se_t <= TARGET_SE
            stopped_early = true
            break
        end
        next_seed > max_s && break
        batch_end = min(max_s, next_seed + max(workers, 1) - 1)
        append!(all_rows, map_workers(collect(next_seed:batch_end), workers))
        next_seed = batch_end + 1
    end
    write_report(all_rows, (time() - t0) / 60; min_seeds = min_s, max_seeds = max_s, stopped_early = stopped_early, tag = tag)
    println("Done in $(round((time() - t0) / 60; digits = 1)) min -> $(out_md(tag))")
end

if !isempty(ARGS) && ARGS[1] == "--worker"
    run_worker_entry()
else
    main()
end

