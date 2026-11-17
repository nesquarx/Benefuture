# Population Scale Suite up to n = 10,000 Beings / Voters (docs/PLAN.md item 2).
# Uses OS subprocesses (`--workers=N`) so Lean FFI (libbfref.dylib) is never shared across OS threads.
# Writes periodic 5-minute progress snapshots to `sim/battery/state/scale_10k.progress`.
# Run: julia --project=sim sim/battery/scale_10k.jl [--workers=8]

using BenefutureSim, Statistics, Random, Printf, Serialization

argval(name, default) = (i = findfirst(a -> startswith(a, "--$name="), ARGS); i === nothing ? default : parse(Int, split(ARGS[i], "=")[2]))
argstr(name, default) = (i = findfirst(a -> startswith(a, "--$name="), ARGS); i === nothing ? default : String(split(ARGS[i], "="; limit = 2)[2]))

const WORKERS = argval("workers", 1)
const TASK = argstr("task", "")
const SEED = argval("seed", 0)
const POP = argval("pop", 80)
const OUT_JLS = argstr("out-jls", "")
const Z = 3.0

function run_m3c_pop(n_beings::Int, seed::Int)
    t0 = time()
    skills = draw_skills(Xoshiro(5000 + n_beings), 8, 4, [1, 3]; median = 0.6, log_sd = 0.4)
    agents = [DomainAgent(skills[a, :], [0.5, 0.0, 0.5, 0.0], CALIBRATED.sloppiness) for a in 1:8]
    p = M3cParams(
        ToyParams(n = n_beings, steps = 100, plans = 10),
        agents, [1, 1, 2, 2], trues(4);
        λpos = 0.05, λneg = 0.02, init_steps = 40,
        transactions = true, causal_distribution = true, p_upstream = 0.4,
        guardians = [1, 2, 3, 4], diligence = fill(0.8, 8),
        p_hazard = 0.05, repair_efficiency = 0.5, advap = true,
        credence_rule = :record, accuracy_rule = :decay
    )
    tr = run_m3c(p; seed = seed)
    sp = success_pattern(tr; from = 41)
    (fu = tr.floor_u[end] - tr.floor_u[41], fh = tr.floor_h[end] - tr.floor_h[41],
     mu = tr.median_u[end] - tr.median_u[41], harm = sp.worst_drop, sec = time() - t0)
end

function run_m5_pop(nv::Int, seed::Int)
    t0 = time()
    rng = Xoshiro(7000 + nv)
    k = max(1, round(Int, 1.5 * nv^0.3))
    raw = draw_skills(rng, nv, 4, [1, 2, 3, 4]; median = 0.8, log_sd = 0.3)
    skills = zeros(nv, 4); focus = fill(0.1, nv, 4)
    for d in 1:4, i in (k * (d - 1) + 1):min(nv, k * d)
        skills[i, d] = raw[i, d]; focus[i, d] = 0.7
    end
    for i in 1:nv; focus[i, :] ./= sum(focus[i, :]); end
    rep = fill(0.1, nv, 4) .+ 5.0 .* skills
    m3 = (relevance_leaf = rep, agents = [DomainAgent(skills[i, :], focus[i, :], 0.2) for i in 1:nv])
    p_bf = M5Params(m3, 1:4; decisions = 120, signal_σ = 2.0, skill_gain = 5.0,
                    p_delegate = 0.6, cap = 0.15, impact_threshold = 0.5, expertise_weight = 10.0,
                    vote_value = 1.0, misconception_σ = 1.5)
    p_eq = M5Params(m3, 1:4; decisions = 120, signal_σ = 2.0, skill_gain = 5.0,
                    expertise_weight = 0.0, impact_weight = 0.0, p_delegate = 0.0,
                    vote_value = 0.0, misconception_σ = 1.5)
    t_bf0 = time(); bf = mean(run_m5(p_bf; seed = seed).correct_trace[61:120]); sec_bf = time() - t_bf0
    t_eq0 = time(); eq = mean(run_m5(p_eq; seed = seed).correct_trace[61:120]); sec_eq = time() - t_eq0
    (bf = bf, eq = eq, gain = bf - eq, sec_bf = sec_bf, sec_eq = sec_eq, sec = time() - t0)
end

if TASK == "m3c"
    serialize(OUT_JLS, run_m3c_pop(POP, SEED))
elseif TASK == "m5"
    serialize(OUT_JLS, run_m5_pop(POP, SEED))
else
    function run_main()
        t0 = time()
        commit = current_commit()
        prog_path = joinpath(@__DIR__, "state", "scale_10k.progress")
        mkpath(dirname(prog_path))
        POPS = [80, 1000, 10000]
        M3C_SEEDS = collect(101:116)
        M5_SEEDS = collect(201:216)
        total_units = length(POPS) * (length(M3C_SEEDS) + length(M5_SEEDS))
        pt = progress_tracker(prog_path, "scale_10k", total_units; interval = 300.0)
        done_cnt = Threads.Atomic{Int}(0)

        function spawn_jobs(jobs)
            tmpdir = mktempdir()
            outs = Vector{Any}(undef, length(jobs))
            next_i = Threads.Atomic{Int}(1)
            script = @__FILE__
            proj = joinpath(@__DIR__, "..")
            @sync for _ in 1:min(WORKERS, length(jobs))
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

        println("Running scale_10k (workers=$WORKERS, total units=$total_units)...")
        flush(stdout)
        m3c_jobs = [(args = ["--task=m3c", "--pop=$n", "--seed=$s"], label = "m3c n=$n s=$s") for n in POPS for s in M3C_SEEDS]
        m3c_flat = spawn_jobs(m3c_jobs)
        m5_jobs = [(args = ["--task=m5", "--pop=$n", "--seed=$s"], label = "m5 nv=$n s=$s") for n in POPS for s in M5_SEEDS]
        m5_flat = spawn_jobs(m5_jobs)
        progress_finish!(pt, "completed")
        elapsed = (time() - t0) / 60

        csv_rows = ["rung,n,n_seeds,metric,mean,se,z_raw,significant_z3,sec_per_seed"]
        md = IOBuffer()
        println(md, "# 10^4-Being Population Scale Report (`z = 3.0`, Student-t inflated)")
        @printf(md, "\n- **Commit**: `%s` · **Runtime**: `%.1f min` · **Workers**: `%d`\n\n", commit, elapsed, WORKERS)

        println(md, "## 1. M3c Economy Scaling (`n = 80 -> 10,000`, `16` seeds `101:116`, `steps = 100`, `init_steps = 40`, `8` agents)")
        println(md, "| `n` beings | `floor_u` gain ± SE (`z_raw`, `z>=3`) | `floor_h` gain ± SE | `median_u` gain | `worst_drop` | `sec / seed` |")
        println(md, "|---|---|---|---|---|---|")
        for (pi, n) in enumerate(POPS)
            sub = m3c_flat[(pi - 1) * length(M3C_SEEDS) + 1 : pi * length(M3C_SEEDS)]
            fu = [r.fu for r in sub]; fh = [r.fh for r in sub]; mu = [r.mu for r in sub]
            pu = paired_effect(fu; z = Z); ph = paired_effect(fh; z = Z)
            sec_m = mean(r.sec for r in sub)
            @printf(md, "| `%d` | %.2f ± %.2f (`%.2f`, %s) | %.2f ± %.2f | %.2f | %.2f | %.1f |\n",
                    n, pu.mean, pu.se, pu.mean / max(pu.se, 1e-12), pu.significant ? "yes" : "no",
                    ph.mean, ph.se, mean(mu), mean(r.harm for r in sub), sec_m)
            push!(csv_rows, @sprintf("M3c,%d,%d,floor_u_gain,%.6f,%.6f,%.3f,%s,%.2f",
                                     n, pu.n, pu.mean, pu.se, pu.mean / max(pu.se, 1e-12), pu.significant, sec_m))
        end
        println(md)

        println(md, "## 2. M5 Sparse Specialists Scaling (`nv = 80 -> 10,000`, `16` seeds `201:216`, `decisions = 120`, `misconception_σ = 1.5`)")
        println(md, "| `nv` voters (`k_spec`) | `:bf` Mean | `:eq` Mean | Paired Gain (`bf - eq`) ± SE | `z_raw` | `z >= 3` | `sec / seed` |")
        println(md, "|---|---|---|---|---|---|---|")
        for (pi, nv) in enumerate(POPS)
            sub = m5_flat[(pi - 1) * length(M5_SEEDS) + 1 : pi * length(M5_SEEDS)]
            k = max(1, round(Int, 1.5 * nv^0.3))
            g = [r.gain for r in sub]
            pg = paired_effect(g; z = Z)
            sec_m = mean(r.sec for r in sub)
            @printf(md, "| `%d` (`k=%d`) | %.4f | %.4f | %+.4f ± %.4f | %.2f | %s | %.1f |\n",
                    nv, k, mean(r.bf for r in sub), mean(r.eq for r in sub),
                    pg.mean, pg.se, pg.mean / max(pg.se, 1e-12), pg.significant ? "yes" : "no", sec_m)
            push!(csv_rows, @sprintf("M5_sparse,%d,%d,wisdom_gain,%.6f,%.6f,%.3f,%s,%.2f",
                                     nv, pg.n, pg.mean, pg.se, pg.mean / max(pg.se, 1e-12), pg.significant, sec_m))
        end

        write(joinpath(@__DIR__, "results", "scale_10k.md"), String(take!(md)))
        write(joinpath(@__DIR__, "results", "scale_10k.csv"), join(csv_rows, "\n") * "\n")
        println("10^4-being population scale suite finished in $(round(elapsed; digits = 1)) min -> sim/battery/results/scale_10k.{md,csv}")
    end
    run_main()
end

