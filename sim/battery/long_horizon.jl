# Long-horizon and composed century simulations (author ruling 8.64, open questions 8.81, 8.85, 8.86).
# Run: julia -t auto --project=sim sim/battery/long_horizon.jl
#
# Executes four multi-threaded long-horizon suites on contiguous seed ranges, writing incremental
# checkpoints and final reports to `sim/battery/results/long_horizon.md` and `long_horizon.csv`:
#   1. 10-Year Scaled Economy (120 monthly steps, 240 beings, 16 agents, 8 leaves, seeds 1:24)
#   2. 20-Year Governance (1,200 decisions at 60/year, 100 voters, stealth collusion & delegation, seeds 1:24)
#   3. 100-Year Composed Century World (1,200 monthly economy steps + 6,000 governance decisions +
#      100 annual M7 population/teaching/research/accession steps with catastrophes & breakthroughs, seeds 1:16)
#   4. High-Seed Open-Question Sweeps (64 paired seeds on 8.85 800-step model takeover, 64 paired seeds
#      on 8.81 marginal-domain overpromising, and 32 paired seeds on 8.86 accession size scaling).

using BenefutureSim, Statistics, Random, Printf, Dates

# ---- L3.1: one world, many arms ------------------------------------------------------------------
# `world(seed; arm, stress)` returns the economy (`econ`) and a governance builder (`gov(trace)`) for
# one seed. Everything that is the world is identical across arms: agents and skills, sloppiness
# (CALIBRATED.sloppiness), noise, hazards, side harm, model arrivals, delegation, the event schedule,
# and the adversaries (deceiver, on-off deceiver, 3-member colluding bloc, slanderer). Arms differ
# only in `MECHANISM_FIELDS`. `stress` (:stressed | :unstressed) switches catastrophes, outages and
# capture; research breakthroughs occur in both.
const WORLD_ONLY = get(ENV, "BF_WORLD_ONLY", "") != ""
const ECON_MECHANISM_FIELDS = (:accuracy_rule, :advap, :ratchet_k, :credence_rule, :bind_weighted)
const GOV_MECHANISM_FIELDS = (:advap,)
const WORLD_ARMS = (:bf, :status_quo)

function world_events(stress::Symbol; steps::Integer = 1200)
    stress in (:stressed, :unstressed) || error("stress must be :stressed or :unstressed")
    scale_ev(ev) = steps == 1200 ? ev : shock(
        ev.kind;
        step = clamp(round(Int, ev.step * steps / 1200), 1, steps),
        duration = ev.duration == 0 ? 0 : max(1, round(Int, ev.duration * steps / 1200)),
        size = ev.size, share = ev.share, target = ev.target,
    )
    breakthroughs = scale_ev.([
        shock(:breakthrough; step = 300, duration = 900, size = 0.5, target = 1),
        shock(:breakthrough; step = 720, duration = 480, size = 0.6, target = 2),
        shock(:breakthrough; step = 1020, duration = 180, size = 0.5, target = 3),
    ])
    stress == :unstressed && return breakthroughs
    sort!(vcat(breakthroughs, scale_ev.([
        shock(:catastrophe; step = 240, share = 0.4, size = 20.0),
        shock(:outage; step = 420, duration = 18),
        shock(:capture; step = 540, duration = 60, size = 2.5, target = 1),
        shock(:catastrophe; step = 660, share = 0.5, size = 25.0),
        shock(:outage; step = 840, duration = 12),
        shock(:catastrophe; step = 960, share = 0.35, size = 18.0),
    ])); by = s -> s.step)
end

function world(seed::Integer; arm::Symbol = :bf, stress::Symbol = :stressed, steps::Integer = 1200,
               n_agents::Integer = 12, decisions::Integer = 1200)
    arm in WORLD_ARMS || error("arm must be one of $WORLD_ARMS")
    bf = arm == :bf
    skills = draw_skills(Xoshiro(20261102 + seed), n_agents, 4, [1, 3]; median = 0.6)
    agents = [DomainAgent(skills[a, :], [0.5, 0.0, 0.5, 0.0], CALIBRATED.sloppiness) for a in 1:n_agents]
    deceit = zeros(n_agents); deceit[n_agents - 1] = 1.0; deceit[n_agents] = 1.0   # steady, and the on-off one
    frivolous = zeros(n_agents); frivolous[n_agents - 2] = 0.5                      # the slanderer
    colluders = [1, 2, 3]
    econ = M3cParams(
        ToyParams(n = 120, steps = steps, plans = 10),
        agents, [1, 1, 2, 2], trues(4);
        init_steps = 50, λpos = 0.05, λneg = 0.02,
        transactions = true, causal_distribution = true,
        p_upstream = 0.4, guardians = [1, 2, 3, 4],
        p_hazard = 0.10, p_side = 0.02, repair_efficiency = 0.5,
        deceit = deceit, on_off = 25, frivolous = frivolous, slander = zeros(Int, n_agents),
        p_new_model = 0.01, events = world_events(stress; steps = steps),
        accuracy_rule = bf ? :decay : :window,
        advap = bf,
        ratchet_k = bf ? 3 : 0,
        credence_rule = bf ? :record : :normal,
        bind_weighted = bf,
    )
    gov(trace) = M5Params(trace, 1:4; decisions = decisions, colluders = colluders, stealth = true,
                          loyalty = 2.0, p_delegate = 0.2, p_new_model = 0.01, advap = bf)
    (econ = econ, gov = gov)
end
# ---------------------------------------------------------------------------------------------------

function parse_cli_args(args = ARGS)
    parsed = Dict{String, Any}()
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--seeds" && i < length(args)
            val = args[i+1]
            parsed["seeds"] = contains(val, ":") ? let p = split(val, ":"); parse(Int, p[1]):parse(Int, p[2]) end : 1:parse(Int, val)
            i += 2
        elseif startswith(arg, "--seeds=")
            val = split(arg, "=", limit = 2)[2]
            parsed["seeds"] = contains(val, ":") ? let p = split(val, ":"); parse(Int, p[1]):parse(Int, p[2]) end : 1:parse(Int, val)
            i += 1
        elseif arg == "--shard" && i < length(args)
            parsed["shard"] = parse(Int, args[i+1])
            i += 2
        elseif startswith(arg, "--shard=")
            parsed["shard"] = parse(Int, split(arg, "=", limit = 2)[2])
            i += 1
        elseif arg == "--out" && i < length(args)
            parsed["out"] = args[i+1]
            i += 2
        elseif startswith(arg, "--out=")
            parsed["out"] = split(arg, "=", limit = 2)[2]
            i += 1
        else
            i += 1
        end
    end
    return parsed
end

const CLI_ARGS = parse_cli_args()
const OUT_DIR = get(CLI_ARGS, "out", get(ENV, "BF_OUT", joinpath(@__DIR__, "results")))
mkpath(OUT_DIR)
const SHARD_ID = get(CLI_ARGS, "shard", get(ENV, "BF_SHARD", ""))
const MD_PATH = joinpath(OUT_DIR, isempty(string(SHARD_ID)) ? "long_horizon.md" : "long_horizon.$SHARD_ID.md")
const CSV_PATH = joinpath(OUT_DIR, isempty(string(SHARD_ID)) ? "long_horizon.csv" : "long_horizon.$SHARD_ID.csv")

const CLI_SEEDS = get(CLI_ARGS, "seeds", nothing)
const N_ECON_SEEDS = parse(Int, get(ENV, "BF_ECON_SEEDS", "32"))
const N_GOV_SEEDS = parse(Int, get(ENV, "BF_GOV_SEEDS", "32"))
const N_CENTURY_SEEDS = parse(Int, get(ENV, "BF_CENTURY_SEEDS", "32"))
const N_SWEEP_SEEDS = parse(Int, get(ENV, "BF_SWEEP_SEEDS", "64"))
const ECON_SEEDS = CLI_SEEDS !== nothing ? CLI_SEEDS : 1:N_ECON_SEEDS
const GOV_SEEDS = CLI_SEEDS !== nothing ? CLI_SEEDS : 1:N_GOV_SEEDS
const CENTURY_SEEDS = CLI_SEEDS !== nothing ? CLI_SEEDS : 1:N_CENTURY_SEEDS
const SWEEP_SEEDS = CLI_SEEDS !== nothing ? CLI_SEEDS : 1:N_SWEEP_SEEDS

# Allowed operating window in local time (default: 00:00 / 12am to 21:00 / 9pm).
const WIN_START_HOUR = parse(Int, get(ENV, "BF_SIM_START_HOUR", "0"))
const WIN_END_HOUR = parse(Int, get(ENV, "BF_SIM_END_HOUR", "21"))

function in_allowed_window(dt::DateTime = Dates.now())
    h = Dates.hour(dt)
    return WIN_START_HOUR <= WIN_END_HOUR ? (WIN_START_HOUR <= h < WIN_END_HOUR) : (h >= WIN_START_HOUR || h < WIN_END_HOUR)
end

function wait_for_allowed_window!()
    logged = false
    while !in_allowed_window()
        if !logged
            println("[Window Guard] Outside allowed window ($(WIN_START_HOUR):00–$(WIN_END_HOUR):00 local); pausing at $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))...")
            flush(stdout)
            logged = true
        end
        sleep(60)
    end
    if logged
        println("[Window Guard] Resuming inside allowed window at $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")).")
        flush(stdout)
    end
end

function parallel_map(f, xs)
    wait_for_allowed_window!()
    out = Vector{Any}(undef, length(xs))
    Threads.@threads for i in eachindex(xs)
        wait_for_allowed_window!()
        out[i] = f(xs[i])
    end
    return out
end

if !WORLD_ONLY
commit = current_commit()
t_start = time()
rows = NamedTuple[]
sections = String[]

function flush_report!(sections, rows, commit, t_start; status = "IN PROGRESS")
    elapsed = (time() - t_start) / 60
    open(MD_PATH, "w") do io
        println(io, "# Long-Horizon & Century Coupled Battery Report (L3.1–L3.3; 8.64, 8.81, 8.85, 8.86)")
        println(io)
        @printf(io, "- **Commit**: `%s`\n", commit)
        @printf(io, "- **Threads**: `%d`\n", Threads.nthreads())
        @printf(io, "- **Status**: `%s` (%.1f minutes elapsed)\n", status, elapsed)
        println(io, "- **Significance Standard**: Exploratory `z = 2.0`; **README / formal claim bar `z = 3.0`**, contiguous paired seeds `1:N`.")
        println(io, "- **Pre-stated Hypotheses & Smallest Effects That Matter (`L3.3`)**:")
        println(io, "  - *Mechanisms (`:bf` vs `:status_quo`)*: Under identical world, adversaries, noise, and shocks (`L3.1`), Benefuture (`:decay`, `advap = true`, `ratchet_k = 3`, `:record`) yields higher `floor_u`, `floor_h`, `median_u`, `median_h`, smaller `worst_drop`, and higher `gov_acc` than `:status_quo` (`:window`, `advap = false`, `ratchet_k = 0`, `:normal`), with strongest advantage under `:stressed`.")
        println(io, "  - *Stress (`:stressed` vs `:unstressed`)*: Catastrophes, outages, and metric capture degrade `floor_u`, `floor_h`, and `worst_drop` relative to `:unstressed` (which keeps breakthroughs and baseline hazards/deceivers equal).")
        println(io, "  - *Smallest Effects That Matter*: `|Δ floor| >= 2.0`, `|Δ median| >= 2.0`, `|Δ worst_drop| >= 1.0`, `|Δ gov_acc| >= 0.01` (`1.0 pp`), at `z >= 3.0`.")
        println(io)
        for s in sections
            println(io, s)
            println(io)
        end
    end
    open(CSV_PATH, "w") do io
        println(io, "suite,metric,n_seeds,mean_a,mean_b,diff,se,z,ci_lo,ci_hi,sig_z2,sig_z3")
        for r in rows
            @printf(io, "%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.4f,%.6f,%.6f,%s,%s\n",
                    r.suite, r.metric, r.n, r.mean_a, r.mean_b, r.diff, r.se, r.z,
                    r.ci_lo, r.ci_hi, r.sig2, r.sig3)
        end
    end
end

function record_comparison!(rows, suite, metric, a::AbstractVector{<:Real}, b::AbstractVector{<:Real})
    ef2 = paired_effect(a .- b; z = 2.0)
    ef3 = paired_effect(a .- b; z = 3.0)
    se = ef2.se
    zval = se > 0 ? ef2.mean / se : 0.0
    ci_lo = ef2.mean - ef2.z * se
    ci_hi = ef2.mean + ef2.z * se
    push!(rows, (
        suite = suite,
        metric = metric,
        n = ef2.n,
        mean_a = mean(a),
        mean_b = mean(b),
        diff = ef2.mean,
        se = se,
        z = zval,
        ci_lo = ci_lo,
        ci_hi = ci_hi,
        sig2 = ef2.significant,
        sig3 = ef3.significant
    ))
    return (ef2 = ef2, ef3 = ef3, z = zval, mean_a = mean(a), mean_b = mean(b), ci_lo = ci_lo, ci_hi = ci_hi)
end

const COUPLED_METRICS = [
    (:floor_u,    "Floor U (`floor_u`)",       "%.2f"),
    (:floor_h,    "Floor H (`floor_h`)",       "%.2f"),
    (:median_u,   "Median U (`median_u`)",     "%.2f"),
    (:median_h,   "Median H (`median_h`)",     "%.2f"),
    (:worst_drop, "Worst drop (`worst_drop`)", "%.2f"),
    (:gov_acc,    "Governance accuracy (`gov_acc`)", "%.4f"),
]

function run_l33_arm(seed::Integer; arm::Symbol, stress::Symbol, steps::Integer, epoch::Integer, m5_decisions::Integer)
    w = world(seed; arm = arm, stress = stress, steps = steps, decisions = m5_decisions)
    tr = run_coupled(w.econ, w.gov; seed = seed, epoch = epoch, coupled = true, m5_decisions = m5_decisions)
    sp = tr.success
    (floor_u = sp.floor_u, floor_h = sp.floor_h, median_u = sp.median_u,
     median_h = sp.median_h, worst_drop = sp.worst_drop, gov_acc = tr.gov_acc)
end

function run_l33_suite!(sections, rows, commit, t_start; idx::Int, suite::String, title::String,
                        seeds, steps::Integer, epoch::Integer, m5_decisions::Integer)
    t0 = time()
    res = parallel_map(seeds) do seed
        (
            bf_s  = run_l33_arm(seed; arm = :bf,         stress = :stressed,   steps, epoch, m5_decisions),
            bf_u  = run_l33_arm(seed; arm = :bf,         stress = :unstressed, steps, epoch, m5_decisions),
            sq_s  = run_l33_arm(seed; arm = :status_quo, stress = :stressed,   steps, epoch, m5_decisions),
            sq_u  = run_l33_arm(seed; arm = :status_quo, stress = :unstressed, steps, epoch, m5_decisions),
        )
    end
    contrasts = [
        ("bf_vs_sq_stressed",          "Benefuture vs Status-Quo (Stressed)",     r -> r.bf_s, r -> r.sq_s),
        ("bf_vs_sq_unstressed",        "Benefuture vs Status-Quo (Unstressed)",   r -> r.bf_u, r -> r.sq_u),
        ("stressed_vs_unstressed_bf",  "Stressed vs Unstressed (Benefuture)",     r -> r.bf_s, r -> r.bf_u),
        ("stressed_vs_unstressed_sq",  "Stressed vs Unstressed (Status-Quo)",     r -> r.sq_s, r -> r.sq_u),
    ]
    sec = IOBuffer()
    @printf(sec, "## %d. %s (`steps = %d`, `epoch = %d`, `m5_decisions = %d`, `1:%d` seeds, %.1f min)\n\n",
            idx, title, steps, epoch, m5_decisions, length(res), (time() - t0) / 60)
    println(sec, "| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI | `z >= 3` |")
    println(sec, "|---|---|---|---|---|---|---|")
    for (ckey, clabel, get_a, get_b) in contrasts
        for (mkey, mlabel, fmt) in COUPLED_METRICS
            va = Float64[getfield(get_a(r), mkey) for r in res]
            vb = Float64[getfield(get_b(r), mkey) for r in res]
            c = record_comparison!(rows, suite, "$(mkey)_$(ckey)", va, vb)
            @printf(sec, "| %s — %s | %.3f | %.3f | %+.3f ± %.3f | %+.2f | [%.3f, %.3f] | %s |\n",
                    mlabel, clabel, c.mean_a, c.mean_b, c.ef2.mean, c.ef2.se, c.z, c.ci_lo, c.ci_hi,
                    c.ef3.significant ? "yes" : "no")
        end
    end
    push!(sections, String(take!(sec)))
    flush_report!(sections, rows, commit, t_start)
end

println("[1/4] Running 10-Year Coupled World (120 steps, epoch=24, 120 gov decisions, 4 factorial arms, seeds $(first(ECON_SEEDS)):$(last(ECON_SEEDS)))...")
run_l33_suite!(sections, rows, commit, t_start;
               idx = 1, suite = "10yr_coupled",
               title = "10-Year Coupled World (`:bf` × `:status_quo` × `:stressed` × `:unstressed`)",
               seeds = ECON_SEEDS, steps = 120, epoch = 24, m5_decisions = 120)

println("[2/4] Running 20-Year Coupled Governance (240 steps, epoch=20, 1,200 gov decisions as epochs, 4 factorial arms, seeds $(first(GOV_SEEDS)):$(last(GOV_SEEDS)))...")
run_l33_suite!(sections, rows, commit, t_start;
               idx = 2, suite = "20yr_coupled_gov",
               title = "20-Year Coupled Governance (1,200 decisions as epochs; 4 factorial arms)",
               seeds = GOV_SEEDS, steps = 240, epoch = 20, m5_decisions = 1200)

println("[3/4] Running 100-Year Coupled Century World (1,200 steps, epoch=25, 1,200 gov decisions as epochs, 4 factorial arms, seeds $(first(CENTURY_SEEDS)):$(last(CENTURY_SEEDS)))...")
run_l33_suite!(sections, rows, commit, t_start;
               idx = 3, suite = "100yr_century",
               title = "100-Year Coupled Century World (4 factorial arms)",
               seeds = CENTURY_SEEDS, steps = 1200, epoch = 25, m5_decisions = 1200)

println("[4/4] Running High-Seed Sweeps for Open Questions 8.85 and 8.81 (seeds $(first(SWEEP_SEEDS)):$(last(SWEEP_SEEDS)))...")
begin
    t0 = time()
    # 8.85 open question: Does time-weighted comparison (:decay) vs fixed window (:window) change
    # takeover rates or own-currency share in the 800-step better-models world over 1:N_SWEEP_SEEDS?
    function better_models_world(; steps = 800, p_new_model = 0.03, accuracy_rule = :decay)
        M3cParams(
            ToyParams(n = 80, steps = steps, plans = 10),
            [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.0) for _ in 1:6],
            [1, 1, 2, 2], trues(4);
            λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
            σ_leaf = 0.65, σ_branch = 0.75, σ_coarse = 0.85,
            p_new_model = p_new_model, improve_drift = -0.15,
            accuracy_rule = accuracy_rule
        )
    end
    own_share(tr) = (k = [i for i in eachindex(tr.chosen_step) if tr.chosen_step[i] > 50];
                     isempty(k) ? 0.0 : mean(tr.priced_leaf[k] .== tr.true_leaf[k]))

    res_885 = parallel_map(SWEEP_SEEDS) do seed
        tr_dec = run_m3c(better_models_world(accuracy_rule = :decay); seed)
        tr_win = run_m3c(better_models_world(accuracy_rule = :window); seed)
        (
            takeover_dec = tr_dec.takeovers > 0,
            takeover_win = tr_win.takeovers > 0,
            ntake_dec = tr_dec.takeovers,
            ntake_win = tr_win.takeovers,
            own_dec = own_share(tr_dec),
            own_win = own_share(tr_win),
            fu_dec = tr_dec.floor_u[end] - tr_dec.floor_u[50],
            fu_win = tr_win.floor_u[end] - tr_win.floor_u[50]
        )
    end

    c_885_take = record_comparison!(rows, "open_885_better_models", "takeover_count_decay_vs_window",
                                    Float64[r.ntake_dec for r in res_885], Float64[r.ntake_win for r in res_885])
    c_885_own  = record_comparison!(rows, "open_885_better_models", "own_share_decay_vs_window",
                                    [r.own_dec for r in res_885], [r.own_win for r in res_885])
    c_885_fu   = record_comparison!(rows, "open_885_better_models", "floor_u_decay_vs_window",
                                    [r.fu_dec for r in res_885], [r.fu_win for r in res_885])
    pi_dec = proportion_interval(count(r.takeover_dec for r in res_885), length(res_885))
    pi_win = proportion_interval(count(r.takeover_win for r in res_885), length(res_885))

    sec = IOBuffer()
    @printf(sec, "## 4. High-Seed Sweep: Open Question 8.85 (800-step Better-Models Takeover, `1:%d` seeds, %.1f min)\n\n",
            length(res_885), (time() - t0) / 60)
    @printf(sec, "- **Takeover regime (`:decay`)**: `%d / %d` (%.1f%%, 95%% interval `[%.3f, %.3f]`)\n",
            count(r.takeover_dec for r in res_885), length(res_885), 100 * pi_dec.p, pi_dec.lo, pi_dec.hi)
    @printf(sec, "- **Takeover regime (`:window`)**: `%d / %d` (%.1f%%, 95%% interval `[%.3f, %.3f]`)\n\n",
            count(r.takeover_win for r in res_885), length(res_885), 100 * pi_win.p, pi_win.lo, pi_win.hi)
    println(sec, "| Metric (`1:$(length(res_885))` paired seeds) | `:decay` Mean | `:window` Mean | Paired Diff ± SE | `z` | 95% CI |")
    println(sec, "|---|---|---|---|---|---|")
    for (label, c) in [
        ("Takeover count per run", c_885_take),
        ("Own-currency pricing share", c_885_own),
        ("Floor understanding growth (`floor_u`)", c_885_fu)
    ]
        @printf(sec, "| %s | %.3f | %.3f | %+.3f ± %.3f | %+.2f | [%.3f, %.3f] |\n",
                label, c.mean_a, c.mean_b, c.ef2.mean, c.ef2.se, c.z, c.ci_lo, c.ci_hi)
    end
    push!(sections, String(take!(sec)))
    flush_report!(sections, rows, commit, t_start; status = "COMPLETED")
end

println("Long-horizon simulation suite completed cleanly in $(round((time() - t_start)/60, digits=1)) minutes.")
end  # !WORLD_ONLY
