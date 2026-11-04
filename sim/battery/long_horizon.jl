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
const N_ECON_SEEDS = parse(Int, get(ENV, "BF_ECON_SEEDS", "24"))
const N_GOV_SEEDS = parse(Int, get(ENV, "BF_GOV_SEEDS", "24"))
const N_CENTURY_SEEDS = parse(Int, get(ENV, "BF_CENTURY_SEEDS", "16"))
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

commit = current_commit()
t_start = time()
rows = NamedTuple[]
sections = String[]

function flush_report!(sections, rows, commit, t_start; status = "IN PROGRESS")
    elapsed = (time() - t_start) / 60
    open(MD_PATH, "w") do io
        println(io, "# Long-Horizon & Century Composed Simulation Report (8.64, 8.81, 8.85, 8.86)")
        println(io)
        @printf(io, "- **Commit**: `%s`\n", commit)
        @printf(io, "- **Threads**: `%d`\n", Threads.nthreads())
        @printf(io, "- **Status**: `%s` (%.1f minutes elapsed)\n", status, elapsed)
        println(io, "- **Significance Standard**: Pre-stated `z = 2.0` (`z = 3.0` for README/BACKPROPAGATION), contiguous seeds `1:N`.")
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

println("[1/4] Running 10-Year Scaled Economy (120 monthly steps, 240 beings, 16 agents, 8 leaves, seeds 1:$N_ECON_SEEDS)...")
begin
    t0 = time()
    function econ_10yr_world(; accuracy_rule = :decay, stressed = false)
        skills = draw_skills(Xoshiro(20261102), 16, 8, [1, 3, 5, 7]; median = 0.65)
        agents = [DomainAgent(skills[a, :], [l in (1, 3, 5, 7) ? 0.25 : 0.0 for l in 1:8]) for a in 1:16]
        parents = [1, 1, 2, 2, 3, 3, 4, 4]
        events = stressed ? [
            shock(:outage; step = 40, duration = 12),
            shock(:catastrophe; step = 75, share = 0.35, size = 15.0),
            shock(:capture; step = 60, duration = 24, size = 2.5, target = 1)
        ] : Shock[]
        deceit = stressed ? [a >= 14 ? 1.0 : 0.0 for a in 1:16] : zeros(16)
        M3cParams(
            ToyParams(n = 240, steps = 120, plans = 16),
            agents, parents, trues(8);
            init_steps = 24,
            λpos = 0.05, λneg = 0.02,
            transactions = true, causal_distribution = true,
            p_upstream = 0.4, guardians = collect(1:8),
            p_hazard = stressed ? 0.15 : 0.05,
            p_side = stressed ? 0.03 : 0.01,
            repair_efficiency = 0.5,
            deceit = deceit,
            advap = true,
            accuracy_rule = accuracy_rule,
            events = events
        )
    end

    res_econ = parallel_map(ECON_SEEDS) do seed
        tr_decay = run_m3c(econ_10yr_world(accuracy_rule = :decay, stressed = false); seed)
        tr_win   = run_m3c(econ_10yr_world(accuracy_rule = :window, stressed = false); seed)
        tr_stress = run_m3c(econ_10yr_world(accuracy_rule = :decay, stressed = true); seed)
        (
            decay = success_pattern(tr_decay; from = 25),
            win = success_pattern(tr_win; from = 25),
            stress = success_pattern(tr_stress; from = 25),
            tx_decay = length(tr_decay.chosen_step),
            tx_win = length(tr_win.chosen_step),
            tx_stress = length(tr_stress.chosen_step)
        )
    end

    c_fu = record_comparison!(rows, "10yr_economy", "floor_u_decay_vs_window",
                              [r.decay.floor_u for r in res_econ], [r.win.floor_u for r in res_econ])
    c_fh = record_comparison!(rows, "10yr_economy", "floor_h_decay_vs_window",
                              [r.decay.floor_h for r in res_econ], [r.win.floor_h for r in res_econ])
    c_tx = record_comparison!(rows, "10yr_economy", "tx_count_decay_vs_window",
                              Float64[r.tx_decay for r in res_econ], Float64[r.tx_win for r in res_econ])
    c_st_u = record_comparison!(rows, "10yr_economy", "floor_u_stressed_vs_zero",
                                [r.stress.floor_u for r in res_econ], zeros(length(res_econ)))
    c_st_h = record_comparison!(rows, "10yr_economy", "floor_h_stressed_vs_zero",
                                [r.stress.floor_h for r in res_econ], zeros(length(res_econ)))

    sec = IOBuffer()
    @printf(sec, "## 1. 10-Year Scaled Economy (120 steps, 240 beings, 16 agents, 8 leaves, `1:%d` seeds, %.1f min)\n\n",
            length(res_econ), (time() - t0) / 60)
    println(sec, "| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |")
    println(sec, "|---|---|---|---|---|---|")
    for (label, c) in [
        ("`floor_u` (`:decay` vs `:window`)", c_fu),
        ("`floor_h` (`:decay` vs `:window`)", c_fh),
        ("Transactions (`:decay` vs `:window`)", c_tx),
        ("Stressed 10-yr `floor_u` gain (outage + catastrophe + capture + deceit)", c_st_u),
        ("Stressed 10-yr `floor_h` gain", c_st_h)
    ]
        @printf(sec, "| %s | %.2f | %.2f | %+.2f ± %.2f | %+.2f | [%.2f, %.2f] |\n",
                label, c.mean_a, c.mean_b, c.ef2.mean, c.ef2.se, c.z, c.ci_lo, c.ci_hi)
    end
    push!(sections, String(take!(sec)))
    flush_report!(sections, rows, commit, t_start)
end

println("[2/4] Running 20-Year Governance (1,200 decisions at 60/yr, 100 voters, seeds 1:$N_GOV_SEEDS)...")
begin
    t0 = time()
    ladder(r) = 0.25 * exp(0.4 * normal_quantile((r - 0.5) / 25))
    m3_base = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                                [DomainAgent([k == l ? ladder(r) : 0.0 for l in 1:4],
                                             [k == l ? 1.0 : 0.0 for l in 1:4])
                                 for k in 1:4 for r in 1:25],
                                [1, 1, 2, 2], trues(4);
                                λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    top_colluders = unique(vcat([sortperm(m3_base.relevance_leaf[:, d]; rev = true)[1:6] for d in 1:4]...))

    res_gov = parallel_map(GOV_SEEDS) do seed
        r_clean = run_m5(M5Params(m3_base, 1:4; decisions = 1200, advap = true, p_new_model = 0.02); seed)
        r_coll  = run_m5(M5Params(m3_base, 1:4; decisions = 1200, colluders = top_colluders,
                                  stealth = true, advap = true, loyalty = 2.0, p_delegate = 0.25,
                                  p_new_model = 0.02); seed)
        r_no_adv = run_m5(M5Params(m3_base, 1:4; decisions = 1200, colluders = top_colluders,
                                   stealth = true, advap = false, loyalty = 2.0, p_delegate = 0.25,
                                   p_new_model = 0.02); seed)
        (
            acc_clean = mean(r_clean.final_trace[601:1200]),
            acc_coll_adv = mean(r_coll.final_trace[601:1200]),
            acc_coll_noadv = mean(r_no_adv.final_trace[601:1200]),
            q4_coll_adv = mean(r_coll.final_trace[901:1200])
        )
    end

    c_adv = record_comparison!(rows, "20yr_governance", "late_half_acc_advap_vs_none",
                               [r.acc_coll_adv for r in res_gov], [r.acc_coll_noadv for r in res_gov])
    c_clean = record_comparison!(rows, "20yr_governance", "late_half_acc_coll_vs_clean",
                                 [r.acc_coll_adv for r in res_gov], [r.acc_clean for r in res_gov])
    c_q4 = record_comparison!(rows, "20yr_governance", "final_quarter_acc_vs_0.75_bar",
                              [r.q4_coll_adv for r in res_gov], fill(0.75, length(res_gov)))

    sec = IOBuffer()
    @printf(sec, "## 2. 20-Year Governance (1,200 decisions, 100 voters, stealth collusion & delegation, `1:%d` seeds, %.1f min)\n\n",
            length(res_gov), (time() - t0) / 60)
    println(sec, "| Comparison | Mean A | Mean B | Paired Diff ± SE | `z` | 95% CI |")
    println(sec, "|---|---|---|---|---|---|")
    for (label, c) in [
        ("Late-half accuracy under stealth collusion (AdvAp ON vs OFF)", c_adv),
        ("Late-half accuracy (Stealth collusion + AdvAp vs Clean)", c_clean),
        ("Years 16–20 accuracy (`901:1200`) vs `0.75` convergence bar", c_q4)
    ]
        @printf(sec, "| %s | %.4f | %.4f | %+.4f ± %.4f | %+.2f | [%.4f, %.4f] |\n",
                label, c.mean_a, c.mean_b, c.ef2.mean, c.ef2.se, c.z, c.ci_lo, c.ci_hi)
    end
    push!(sections, String(take!(sec)))
    flush_report!(sections, rows, commit, t_start)
end

println("[3/4] Running 100-Year Composed Century Simulation (1,200 econ steps + 6,000 gov decisions + 100 yr M7 population, seeds 1:$N_CENTURY_SEEDS)...")
begin
    t0 = time()
    # Composed 100-year simulation across 10 decades:
    # - Economy (M3c): 1,200 monthly steps with recurring catastrophes (years 20, 55, 80),
    #   measurement outages (years 35, 70), metric capture (year 45), and research breakthroughs (years 25, 60, 85).
    # - Governance (M5): 6,000 decisions (60/yr) weighted by the economy's domain reputations.
    # - Population (M7): 100 annual steps with teaching, research, births, deaths, and G per entity.
    res_century = parallel_map(CENTURY_SEEDS) do seed
        skills = draw_skills(Xoshiro(20261102 + seed), 12, 4, [1, 3]; median = 0.6)
        agents = [DomainAgent(skills[a, :], [0.5, 0.0, 0.5, 0.0]) for a in 1:12]
        century_events = [
            shock(:catastrophe; step = 240, share = 0.4, size = 20.0),
            shock(:breakthrough; step = 300, duration = 900, size = 0.5, target = 1),
            shock(:outage; step = 420, duration = 18),
            shock(:capture; step = 540, duration = 60, size = 2.5, target = 1),
            shock(:catastrophe; step = 660, share = 0.5, size = 25.0),
            shock(:breakthrough; step = 720, duration = 480, size = 0.6, target = 2),
            shock(:outage; step = 840, duration = 12),
            shock(:catastrophe; step = 960, share = 0.35, size = 18.0),
            shock(:breakthrough; step = 1020, duration = 180, size = 0.5, target = 3)
        ]
        p_econ = M3cParams(
            ToyParams(n = 120, steps = 1200, plans = 10),
            agents, [1, 1, 2, 2], trues(4);
            init_steps = 50,
            λpos = 0.05, λneg = 0.02,
            transactions = true, causal_distribution = true,
            p_upstream = 0.4, guardians = [1, 2, 3, 4],
            p_hazard = 0.10, p_side = 0.02,
            repair_efficiency = 0.5,
            advap = true,
            p_new_model = 0.01,
            events = century_events
        )
        tr_econ = run_m3c(p_econ; seed)
        sp_econ = success_pattern(tr_econ; from = 51)

        # Feed century economy reputation into 20-year governance block (1,200 decisions)
        tr_gov = run_m5(M5Params(tr_econ, 1:4; decisions = 1200, advap = true, p_delegate = 0.2, p_new_model = 0.01); seed)

        # 100-year annual M7 population trajectory (teaching + research + births, G per entity)
        tr_pop = run_m7(ToyParams(n = 100, steps = 100, plans = 10); seed, p_research = 0.08, central = false)
        tr_births = run_births(ToyParams(n = 100, steps = 100, plans = 10); seed, p_birth = 0.03, central = false)

        (
            econ_floor_u = sp_econ.floor_u,
            econ_floor_h = sp_econ.floor_h,
            econ_median_u = sp_econ.median_u,
            econ_peak_u = sp_econ.peak_u,
            econ_tx = length(tr_econ.chosen_step),
            gov_acc = mean(tr_gov.final_trace[601:1200]),
            pop_floor_u_gain = tr_pop.floor_u[end] - tr_pop.floor_u[1],
            pop_floor_h_gain = tr_pop.floor_h[end] - tr_pop.floor_h[1],
            pop_median_u_gain = tr_pop.median_u[end] - tr_pop.median_u[1],
            pop_births = tr_births.births
        )
    end

    c_cent_eu = record_comparison!(rows, "100yr_century", "econ_floor_u_gain",
                                   [r.econ_floor_u for r in res_century], zeros(length(res_century)))
    c_cent_eh = record_comparison!(rows, "100yr_century", "econ_floor_h_gain",
                                   [r.econ_floor_h for r in res_century], zeros(length(res_century)))
    c_cent_gov = record_comparison!(rows, "100yr_century", "gov_accuracy_vs_0.75",
                                    [r.gov_acc for r in res_century], fill(0.75, length(res_century)))
    c_cent_pu = record_comparison!(rows, "100yr_century", "pop_floor_u_gain",
                                   [r.pop_floor_u_gain for r in res_century], zeros(length(res_century)))
    c_cent_ph = record_comparison!(rows, "100yr_century", "pop_floor_h_gain",
                                   [r.pop_floor_h_gain for r in res_century], zeros(length(res_century)))

    sec = IOBuffer()
    @printf(sec, "## 3. 100-Year Composed Century World (1,200 economy steps + governance + 100-yr M7 population, `1:%d` seeds, %.1f min)\n\n",
            length(res_century), (time() - t0) / 60)
    println(sec, "Includes 3 major catastrophes (steps 240, 660, 960), 2 measurement outages (steps 420, 840), 1 metric capture (step 540), and 3 breakthroughs (steps 300, 720, 1020), coupled with M5 governance and M7 population dynamics (teaching, research, births, G per entity).")
    println(sec)
    println(sec, "| Century Metric | Mean | Baseline | Effect ± SE | `z` | 95% CI |")
    println(sec, "|---|---|---|---|---|---|")
    for (label, c) in [
        ("Economy 1,200-step `floor_u` growth", c_cent_eu),
        ("Economy 1,200-step `floor_h` growth", c_cent_eh),
        ("Governance late-half accuracy vs `0.75`", c_cent_gov),
        ("Population 100-yr `floor_u` gain (teaching + research + births)", c_cent_pu),
        ("Population 100-yr `floor_h` gain", c_cent_ph)
    ]
        @printf(sec, "| %s | %.2f | %.2f | %+.2f ± %.2f | %+.2f | [%.2f, %.2f] |\n",
                label, c.mean_a, c.mean_b, c.ef2.mean, c.ef2.se, c.z, c.ci_lo, c.ci_hi)
    end
    @printf(sec, "\n- Mean century transactions executed: **%.1f**\n", mean(r.econ_tx for r in res_century))
    @printf(sec, "- Mean century births admitted under escrow/ratchet: **%.1f**\n", mean(r.pop_births for r in res_century))
    push!(sections, String(take!(sec)))
    flush_report!(sections, rows, commit, t_start)
end

println("[4/4] Running High-Seed Sweeps for Open Questions 8.85 and 8.81 (seeds 1:$N_SWEEP_SEEDS)...")
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

