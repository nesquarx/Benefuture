# Fresh-Seed z = 3.0 Replications of Open Small Effects (docs/PLAN.md item 2; 8.90, collusion residual, M3c/M7 scale).
# Uses OS subprocesses (`--workers=N`) so Lean FFI (libbfref.dylib) is never shared across OS threads.
# Writes periodic 5-minute progress snapshots to `sim/battery/state/open_replications.progress`.
# Run: julia --project=sim sim/battery/open_replications.jl [--workers=8]

using BenefutureSim, Statistics, Random, Printf, Serialization

argval(name, default) = (i = findfirst(a -> startswith(a, "--$name="), ARGS); i === nothing ? default : parse(Int, split(ARGS[i], "=")[2]))
argstr(name, default) = (i = findfirst(a -> startswith(a, "--$name="), ARGS); i === nothing ? default : String(split(ARGS[i], "="; limit = 2)[2]))

const WORKERS = argval("workers", 1)
const SUITE_SINGLE = argstr("suite", "")
const SEED_SINGLE = argval("seed", 0)
const OUT_JLS = argstr("out-jls", "")
const Z = 3.0

# 1. R1: M5 Sparse Specialists Scaling (8.90, CLAIMS.md, 32 fresh seeds 201:232)
function m5_sparse_pair(n_voters::Int, decisions::Int; alpha::Real = 0.3, c::Real = 1.5, misconception_σ::Real = 1.5)
    rng = Xoshiro(7000 + n_voters)
    k_spec = max(1, round(Int, c * n_voters^alpha))
    raw = draw_skills(rng, n_voters, 4, [1, 2, 3, 4]; median = 0.8, log_sd = 0.3)
    skills = zeros(n_voters, 4)
    focus = fill(0.1, n_voters, 4)
    for d in 1:4
        for i in (k_spec * (d - 1) + 1):min(n_voters, k_spec * d)
            skills[i, d] = raw[i, d]
            focus[i, d] = 0.7
        end
    end
    for i in 1:n_voters
        focus[i, :] ./= sum(focus[i, :])
    end
    reputation = fill(0.1, n_voters, 4) .+ 5.0 .* skills
    m3_stub = (relevance_leaf = reputation, agents = [DomainAgent(skills[i, :], focus[i, :], 0.2) for i in 1:n_voters])
    p_bf = M5Params(m3_stub, 1:4; decisions = decisions, signal_σ = 2.0, skill_gain = 5.0,
                    p_delegate = 0.6, cap = 0.15, impact_threshold = 0.5, expertise_weight = 10.0,
                    vote_value = 1.0, misconception_σ = misconception_σ)
    p_eq = M5Params(m3_stub, 1:4; decisions = decisions, signal_σ = 2.0, skill_gain = 5.0,
                    expertise_weight = 0.0, impact_weight = 0.0, p_delegate = 0.0,
                    vote_value = 0.0, misconception_σ = misconception_σ)
    (bf = p_bf, eq = p_eq, k_spec = k_spec)
end

const R1_NV = (12, 48, 120, 240)
function run_r1(seed)
    nt = Dict{Int, NamedTuple{(:bf, :eq, :gain), Tuple{Float64, Float64, Float64}}}()
    for nv in R1_NV
        pair = m5_sparse_pair(nv, 300)
        b = mean(run_m5(pair.bf; seed).correct_trace[151:300])
        e = mean(run_m5(pair.eq; seed).correct_trace[151:300])
        nt[nv] = (bf = b, eq = e, gain = b - e)
    end
    nt
end

# 2. R2: 20-year M5 Collusion Residual vs Collusion-Free (CLAIMS.md, 64 fresh seeds 201:264)
const R2_M3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                                [DomainAgent([k == l ? 0.25 * exp(0.4 * normal_quantile((r - 0.5) / 25)) : 0.0 for l in 1:4],
                                             [k == l ? 1.0 : 0.0 for l in 1:4])
                                 for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4);
                                λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
const R2_TOP = unique(vcat([sortperm(R2_M3.relevance_leaf[:, d]; rev = true)[1:4] for d in 1:4]...))

function run_r2(seed)
    common = (decisions = 1200, signal_σ = 4.0, ability_spread = 0.8, p_apparent = 0.4, local_σ = 2.0,
              p_delegate = 0.25, stealth = true, loyalty = 2.0)
    p_no_adv = M5Params(R2_M3, 1:4; colluders = R2_TOP, advap = false, common...)
    p_adv    = M5Params(R2_M3, 1:4; colluders = R2_TOP, advap = true,  common...)
    p_clean  = M5Params(R2_M3, 1:4; colluders = Int[],  advap = true,  common...)
    no_adv = mean(run_m5(p_no_adv; seed).final_trace[601:1200])
    adv    = mean(run_m5(p_adv;    seed).final_trace[601:1200])
    clean  = mean(run_m5(p_clean;  seed).final_trace[601:1200])
    (no_adv = no_adv, adv = adv, clean = clean)
end

# 3. R3: M3c Population Scale Effect (convergence.jl config, 32 fresh seeds 101:132)
function make_m3c_scale(n_beings::Int, n_agents::Int; steps::Int = 150)
    rng = Xoshiro(5000 + n_beings)
    skills = draw_skills(rng, n_agents, 4, [1, 3]; median = 0.6, log_sd = 0.4)
    agents = [DomainAgent(skills[a, :], [0.5, 0.0, 0.5, 0.0], CALIBRATED.sloppiness) for a in 1:n_agents]
    plans = max(10, round(Int, 10 * n_beings / 80))
    M3cParams(
        ToyParams(n = n_beings, steps = steps, plans = plans),
        agents, [1, 1, 2, 2], trues(4);
        λpos = 0.05, λneg = 0.02, init_steps = 50,
        transactions = true, causal_distribution = true, p_upstream = 0.4,
        guardians = collect(1:min(4, n_agents)), diligence = fill(0.8, n_agents),
        p_hazard = 0.05, repair_efficiency = 0.5, advap = true,
        credence_rule = :record, accuracy_rule = :decay
    )
end

const R3_GRID = ((40, 6), (80, 8), (160, 12), (240, 16))
function run_r3(seed)
    Dict(n_b => begin
        tr = run_m3c(make_m3c_scale(n_b, n_a); seed)
        (fu = tr.floor_u[end] - tr.floor_u[51], mu = tr.median_u[end] - tr.median_u[51])
    end for (n_b, n_a) in R3_GRID)
end

# 4. R4: M7 Traits-Mode Population Scale Effect (convergence.jl config, 32 fresh seeds 101:132)
const R4_GRID = (20, 100, 300, 500)
function run_r4(seed)
    Dict(np => begin
        t_lo, t_hi = min(1.0, 5.0 / np), min(1.0, 30.0 / np)
        tr = run_m7(ToyParams(n = np, steps = 80, plans = 10, touch = (t_lo, t_hi)); seed,
                    teacher_cv = 0.5, reception_σ = 0.5, novelty_min = 0.2,
                    research_share = 0.1, action_scale = 0.05, class = 10, central = false)
        (fu = tr.floor_u[end] - tr.floor_u[1], mu = tr.median_u[end] - tr.median_u[1])
    end for np in R4_GRID)
end

if !isempty(SUITE_SINGLE) && SEED_SINGLE > 0
    val = SUITE_SINGLE == "r1" ? run_r1(SEED_SINGLE) :
          SUITE_SINGLE == "r2" ? run_r2(SEED_SINGLE) :
          SUITE_SINGLE == "r3" ? run_r3(SEED_SINGLE) :
          SUITE_SINGLE == "r4" ? run_r4(SEED_SINGLE) : error("Unknown suite: $SUITE_SINGLE")
    serialize(OUT_JLS, val)
else
    t0 = time()
    commit = current_commit()
    prog_path = joinpath(@__DIR__, "state", "open_replications.progress")
    mkpath(dirname(prog_path))
    R1_SEEDS = collect(201:232)
    R2_SEEDS = collect(201:264)
    R3_SEEDS = collect(101:132)
    R4_SEEDS = collect(101:132)
    total_units = length(R1_SEEDS) + length(R2_SEEDS) + length(R3_SEEDS) + length(R4_SEEDS)
    pt = progress_tracker(prog_path, "open_replications", total_units; interval = 300.0)
    done_cnt = Threads.Atomic{Int}(0)

    function parallel_suite(suite::String, seeds::Vector{Int})
        WORKERS <= 1 && return [let v = suite == "r1" ? run_r1(s) : suite == "r2" ? run_r2(s) : suite == "r3" ? run_r3(s) : run_r4(s)
                                    n = Threads.atomic_add!(done_cnt, 1) + 1
                                    progress_tick!(pt, n, "$(suite) seed $(s)")
                                    v
                                end for s in seeds]
        tmpdir = mktempdir()
        results = Vector{Any}(undef, length(seeds))
        next_i = Threads.Atomic{Int}(1)
        script = @__FILE__
        proj = joinpath(@__DIR__, "..")
        @sync for _ in 1:min(WORKERS, length(seeds))
            Threads.@spawn while true
                i = Threads.atomic_add!(next_i, 1)
                i > length(seeds) && break
                s = seeds[i]
                out = joinpath(tmpdir, "$(suite)_$(s).jls")
                Base.run(`$(Base.julia_cmd()) --project=$proj $script --suite=$suite --seed=$s --out-jls=$out`)
                results[i] = deserialize(out)
                n = Threads.atomic_add!(done_cnt, 1) + 1
                progress_tick!(pt, n, "$(suite) seed $(s)")
            end
        end
        rm(tmpdir; recursive = true, force = true)
        results
    end

    println("Running open_replications (workers=$WORKERS, total units=$total_units)...")
    flush(stdout)
    r1 = parallel_suite("r1", R1_SEEDS)
    r2 = parallel_suite("r2", R2_SEEDS)
    r3 = parallel_suite("r3", R3_SEEDS)
    r4 = parallel_suite("r4", R4_SEEDS)
    progress_finish!(pt, "completed")
    elapsed = (time() - t0) / 60

    fmt_pe(xs; z = Z) = begin
        pe = paired_effect(xs; z = z)
        @sprintf("%+.4f ± %.4f | %.2f | %s", pe.mean, pe.se, pe.mean / max(pe.se, 1e-12), pe.significant ? "yes" : "no")
    end

    csv_rows = String[]
    push!(csv_rows, "suite,comparison,n,mean,se,z_raw,significant_z3")
    function log_csv!(suite, comp, xs)
        pe = paired_effect(xs; z = Z)
        zr = pe.se > 0 ? pe.mean / pe.se : 0.0
        push!(csv_rows, @sprintf("%s,%s,%d,%.6f,%.6f,%.3f,%s", suite, comp, pe.n, pe.mean, pe.se, zr, pe.significant))
        pe
    end

    md = IOBuffer()
    println(md, "# Open Small-Effect Fresh-Seed Replications (`z = 3.0`, Student-t inflated)")
    @printf(md, "\n- **Commit**: `%s` · **Runtime**: `%.1f min` · **Workers**: `%d`\n\n", commit, elapsed, WORKERS)

    println(md, "## 1. M5 Sparse Specialists (`8.90`, `32` fresh seeds `201:232`, `decisions = 300`, `misconception_σ = 1.5`)")
    println(md, "| Voters (`k_spec`) | `:bf` Mean | `:eq` Mean | Paired Gain (`bf - eq`) ± SE | `z_raw` | `z >= 3` |")
    println(md, "|---|---|---|---|---|---|")
    for nv in R1_NV
        k_spec = max(1, round(Int, 1.5 * nv^0.3))
        bf_v = [r[nv].bf for r in r1]
        eq_v = [r[nv].eq for r in r1]
        g_v  = [r[nv].gain for r in r1]
        pe = log_csv!("R1_sparse", "gain_nv_$nv", g_v)
        @printf(md, "| `%d` (`k=%d`) | %.4f | %.4f | %+.4f ± %.4f | %.2f | %s |\n",
                nv, k_spec, mean(bf_v), mean(eq_v), pe.mean, pe.se, pe.mean / max(pe.se, 1e-12), pe.significant ? "yes" : "no")
    end
    pe_r1_growth = log_csv!("R1_sparse", "growth_240_minus_12", [r[240].gain - r[12].gain for r in r1])
    @printf(md, "\n- **Growth (`gain(240) - gain(12)`)**: `%+.4f ± %.4f` (`z_raw = %.2f`, `z >= 3`: `%s`).\n\n",
            pe_r1_growth.mean, pe_r1_growth.se, pe_r1_growth.mean / max(pe_r1_growth.se, 1e-12), pe_r1_growth.significant ? "yes" : "no")

    println(md, "## 2. 20-Year M5 Collusion Residual (`64` fresh seeds `201:264`, `100` voters, `1,200` decisions)")
    println(md, "| Comparison | Mean A | Mean B | Paired Diff ± SE | `z_raw` | `z >= 3` | Equiv `±0.005` |")
    println(md, "|---|---|---|---|---|---|---|")
    no_adv_v = [r.no_adv for r in r2]; adv_v = [r.adv for r in r2]; clean_v = [r.clean for r in r2]
    for (lbl, va, vb, key) in [
        ("AdvAp recovery (`:collude_advap - :collude_noadvap`)", adv_v, no_adv_v, "advap_recovery"),
        ("Residual cost (`:collude_advap - :clean_advap`)", adv_v, clean_v, "collusion_residual"),
    ]
        d = va .- vb
        pe = log_csv!("R2_collusion_residual", key, d)
        eq = equivalent(d; margin = 0.005, z = Z)
        @printf(md, "| %s | %.4f | %.4f | %+.4f ± %.4f | %.2f | %s | %s |\n",
                lbl, mean(va), mean(vb), pe.mean, pe.se, pe.mean / max(pe.se, 1e-12),
                pe.significant ? "yes" : "no", eq.equivalent ? "yes" : "no")
    end
    println(md)

    println(md, "## 3. M3c Population Scale Effect (`32` fresh seeds `101:132`, `steps = 150`, proportional `plans`)")
    println(md, "| `(n, agents)` | Mean `floor_u` gain | Mean `median_u` gain | `floor_u / n` | vs `(40, 6)` Paired `floor_u` ± SE | `z_raw` | `z >= 3` |")
    println(md, "|---|---|---|---|---|---|---|")
    base_r3 = [r[40].fu for r in r3]
    for (n_b, n_a) in R3_GRID
        fu = [r[n_b].fu for r in r3]
        mu = [r[n_b].mu for r in r3]
        if n_b == 40
            @printf(md, "| `(%d, %d)` | %.2f | %.2f | %.3f | baseline | – | – |\n", n_b, n_a, mean(fu), mean(mu), mean(fu) / n_b)
        else
            pe = log_csv!("R3_m3c_scale", "floor_u_$(n_b)_vs_40", fu .- base_r3)
            @printf(md, "| `(%d, %d)` | %.2f | %.2f | %.3f | %+.2f ± %.2f | %.2f | %s |\n",
                    n_b, n_a, mean(fu), mean(mu), mean(fu) / n_b, pe.mean, pe.se, pe.mean / max(pe.se, 1e-12), pe.significant ? "yes" : "no")
        end
    end
    pe_r3_per = log_csv!("R3_m3c_scale", "per_being_240_vs_40", [r[240].fu / 240.0 - r[40].fu / 40.0 for r in r3])
    @printf(md, "\n- **Per-being `floor_u / n` (`240 vs 40`)**: `%+.4f ± %.4f` (`z_raw = %.2f`, `z >= 3`: `%s`).\n\n",
            pe_r3_per.mean, pe_r3_per.se, pe_r3_per.mean / max(pe_r3_per.se, 1e-12), pe_r3_per.significant ? "yes" : "no")

    println(md, "## 4. M7 Traits-Mode Population Scale Effect (`32` fresh seeds `101:132`, `steps = 80`)")
    println(md, "| `n` beings | Mean `floor_u` gain | Mean `median_u` gain | vs `n = 20` Paired `floor_u` ± SE | `z_raw` | `z >= 3` |")
    println(md, "|---|---|---|---|---|---|")
    base_r4 = [r[20].fu for r in r4]
    for np in R4_GRID
        fu = [r[np].fu for r in r4]
        mu = [r[np].mu for r in r4]
        if np == 20
            @printf(md, "| `%d` | %.2f | %.2f | baseline | – | – |\n", np, mean(fu), mean(mu))
        else
            pe = log_csv!("R4_m7_scale", "floor_u_$(np)_vs_20", fu .- base_r4)
            @printf(md, "| `%d` | %.2f | %.2f | %+.2f ± %.2f | %.2f | %s |\n",
                    np, mean(fu), mean(mu), pe.mean, pe.se, pe.mean / max(pe.se, 1e-12), pe.significant ? "yes" : "no")
        end
    end

    write(joinpath(@__DIR__, "results", "open_replications.md"), String(take!(md)))
    write(joinpath(@__DIR__, "results", "open_replications.csv"), join(csv_rows, "\n") * "\n")
    println("Open replications finished in $(round(elapsed; digits = 1)) min -> sim/battery/results/open_replications.{md,csv}")
end

