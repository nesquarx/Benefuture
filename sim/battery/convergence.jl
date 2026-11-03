# Convergence & Population-Diversity Sizing Suite.
# Run: julia -t auto --project=sim sim/battery/convergence.jl
#
# Periodically measures how much diverse population (beings `n`, log-normal agents/voters/teachers)
# and how many steps (`steps` / `decisions`, plus burn-in) and seeds (`1:N`) each model rung requires
# for its core readings to converge well beyond noise:
#   - Running mean settling step (`settling_step(xs; tol = 0.10)`)
#   - Between-seed relative 95% CI half-width (`ci_halfwidth(x) / abs(mean(x)) <= 10%`)
#   - Signal-to-noise ratio `z = mean / se >= 3.0` (Benefuture's recorded-claim bar)
#   - Comparison against the sizes used in `sim/test/` and `sim/battery/` to ensure test suites run
#     substantially larger than the noise floor.

using BenefutureSim, Statistics, Random, Printf, Dates

const OUT_DIR = get(ENV, "BF_OUT", joinpath(@__DIR__, "results"))
mkpath(OUT_DIR)
const MD_PATH = joinpath(OUT_DIR, "convergence.md")
const CSV_PATH = joinpath(OUT_DIR, "convergence.csv")

const WIN_START_HOUR = parse(Int, get(ENV, "BF_SIM_START_HOUR", "0"))
const WIN_END_HOUR = parse(Int, get(ENV, "BF_SIM_END_HOUR", "21"))

function in_allowed_window(dt::DateTime = Dates.now())
    h = Dates.hour(dt)
    return WIN_START_HOUR <= WIN_END_HOUR ? (WIN_START_HOUR <= h < WIN_END_HOUR) : (h >= WIN_START_HOUR || h < WIN_END_HOUR)
end

function wait_for_allowed_window!()
    while !in_allowed_window()
        sleep(60)
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

rel_hw(xs) = (m = abs(mean(xs)); m > 1e-12 ? 100.0 * ci_halfwidth(xs) / m : Inf)
z_score(xs) = (se = std(xs) / sqrt(length(xs)); se > 1e-12 ? mean(xs) / se : Inf)

t_start = time()
commit = current_commit()
csv_rows = NamedTuple[]

function record_row!(rung, axis, param_val, steps_val, n_seeds, metric, vals; settle_med = NaN, settle_max = NaN)
    m = mean(vals)
    se = std(vals) / sqrt(length(vals))
    rhw = rel_hw(vals)
    z = z_score(vals)
    push!(csv_rows, (
        rung = rung, axis = axis, param = param_val, steps = steps_val, n_seeds = n_seeds,
        metric = metric, mean = m, se = se, rel_hw_pct = rhw, z = z,
        settle_med = settle_med, settle_max = settle_max
    ))
    return (mean = m, se = se, rhw = rhw, z = z, settle_med = settle_med, settle_max = settle_max)
end

println("=== Running Convergence & Population-Diversity Sizing Suite on commit $commit ===")

# ---------------------------------------------------------------------------
# 1. M1: Step-length settling & population-size convergence under model noise
# ---------------------------------------------------------------------------
println("[1/4] Measuring M1 step-settling and population-size convergence...")
m1_models = [MetricModel(0.0, 0.25), MetricModel(0.2, 0.35), MetricModel(0.0, 0.60)]
m1_seeds = 1:10

m1_long = parallel_map(m1_seeds) do seed
    p = M1Params(ToyParams(n = 200, steps = 1000, plans = 20), m1_models, 0.1, 20)
    run_m1(p; seed, central = true)
end

m1_settle_act = [settling_step(Float64.(tr.chosen .> 1); tol = 0.10) for tr in m1_long]
m1_settle_fu  = [settling_step(diff(tr.floor_u); tol = 0.10) for tr in m1_long]
m1_settle_fh  = [settling_step(diff(tr.floor_h); tol = 0.10) for tr in m1_long]
m1_settle_fall = [settling_step(Float64.(diff(tr.floor_u) .< -1e-12); tol = 0.15, atol = 0.01) for tr in m1_long]

m1_step_grid = [50, 100, 200, 300, 500, 1000]
m1_step_stats = map(m1_step_grid) do st
    fu_gains = [tr.floor_u[st + 1] - tr.floor_u[1] for tr in m1_long]
    fh_gains = [tr.floor_h[st + 1] - tr.floor_h[1] for tr in m1_long]
    r_u = record_row!("M1", "steps", 200, st, length(m1_seeds), "floor_u_gain", fu_gains;
                      settle_med = median(m1_settle_fu), settle_max = maximum(m1_settle_fu))
    r_h = record_row!("M1", "steps", 200, st, length(m1_seeds), "floor_h_gain", fh_gains;
                      settle_med = median(m1_settle_fh), settle_max = maximum(m1_settle_fh))
    (steps = st, u = r_u, h = r_h)
end

m1_pop_grid = [15, 30, 60, 100, 200, 400]
m1_pop_stats = map(m1_pop_grid) do n_pop
    trs = parallel_map(m1_seeds) do seed
        p = M1Params(ToyParams(n = n_pop, steps = 200, plans = 15), m1_models, 0.1, 20)
        run_m1(p; seed, central = false)
    end
    fu_gains = [tr.floor_u[end] - tr.floor_u[1] for tr in trs]
    settle_u = [settling_step(diff(tr.floor_u); tol = 0.10) for tr in trs]
    r_u = record_row!("M1_distributed", "population_n", n_pop, 200, length(m1_seeds), "floor_u_gain", fu_gains;
                      settle_med = median(settle_u), settle_max = maximum(settle_u))
    (n = n_pop, u = r_u)
end

# ---------------------------------------------------------------------------
# 2. M3c: Diverse Agent & Being Population + Step Convergence (Calibrated)
# ---------------------------------------------------------------------------
println("[2/4] Measuring M3c economy convergence across diverse agent/being populations and steps...")
m3c_seeds = 1:10

function make_m3c_world(n_beings::Int, n_agents::Int, steps::Int)
    skills = draw_skills(Xoshiro(20261102 + n_agents), n_agents, 4, [1, 3]; median = 0.6, log_sd = CALIBRATED.skill_log_sd)
    agents = [DomainAgent(skills[a, :], [0.5, 0.0, 0.5, 0.0], CALIBRATED.sloppiness) for a in 1:n_agents]
    M3cParams(
        ToyParams(n = n_beings, steps = steps, plans = 10),
        agents, [1, 1, 2, 2], trues(4);
        init_steps = 50, λpos = 0.05, λneg = 0.02,
        transactions = true, causal_distribution = true,
        p_upstream = 0.4, guardians = [1, 2, 3, 4],
        p_hazard = 0.05, repair_efficiency = 0.5, advap = true,
        credence_rule = :record, accuracy_rule = :decay
    )
end

m3c_long = parallel_map(m3c_seeds) do seed
    run_m3c(make_m3c_world(80, 8, 600); seed)
end
m3c_settle_fu = [50 + settling_step(diff(tr.floor_u[51:end]); tol = 0.10) for tr in m3c_long]
m3c_settle_fh = [50 + settling_step(diff(tr.floor_h[51:end]); tol = 0.10) for tr in m3c_long]

m3c_step_grid = [100, 150, 250, 300, 450, 600]
m3c_step_stats = map(m3c_step_grid) do st
    fu_gains = [tr.floor_u[st + 1] - tr.floor_u[51] for tr in m3c_long]
    fh_gains = [tr.floor_h[st + 1] - tr.floor_h[51] for tr in m3c_long]
    r_u = record_row!("M3c_calibrated", "steps", 80, st, length(m3c_seeds), "post_init_floor_u_gain", fu_gains;
                      settle_med = median(m3c_settle_fu), settle_max = maximum(m3c_settle_fu))
    r_h = record_row!("M3c_calibrated", "steps", 80, st, length(m3c_seeds), "post_init_floor_h_gain", fh_gains;
                      settle_med = median(m3c_settle_fh), settle_max = maximum(m3c_settle_fh))
    (steps = st, u = r_u, h = r_h)
end

m3c_pop_grid = [(20, 4), (40, 6), (80, 8), (120, 12), (200, 16)]
m3c_pop_stats = map(m3c_pop_grid) do (n_b, n_a)
    trs = parallel_map(m3c_seeds) do seed
        run_m3c(make_m3c_world(n_b, n_a, 300); seed)
    end
    fu_gains = [tr.floor_u[end] - tr.floor_u[51] for tr in trs]
    settle_u = [50 + settling_step(diff(tr.floor_u[51:end]); tol = 0.10) for tr in trs]
    r_u = record_row!("M3c_calibrated", "diverse_pop_n_agents", n_b, 300, length(m3c_seeds), "post_init_floor_u_gain", fu_gains;
                      settle_med = median(settle_u), settle_max = maximum(settle_u))
    (n_beings = n_b, n_agents = n_a, u = r_u)
end

# ---------------------------------------------------------------------------
# 3. M5: Voter Diversity (`n_voters`) & Decision Horizon (`decisions`)
# ---------------------------------------------------------------------------
println("[3/4] Measuring M5 governance convergence across diverse voter populations and decision horizons...")
m5_seeds = 1:12

function make_m5_world(n_voters::Int, decisions::Int)
    per_dom = max(2, div(n_voters, 4))
    ladder(r) = 0.25 * exp(0.4 * normal_quantile((r - 0.5) / per_dom))
    agents = [DomainAgent([k == l ? ladder(r) : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4])
              for k in 1:4 for r in 1:per_dom]
    m3 = run_m3c(M3cParams(ToyParams(n = 60, steps = 120, plans = 8), agents, [1, 1, 2, 2], trues(4);
                           λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    M5Params(m3, 1:4; decisions = decisions, signal_σ = 2.0, ability_spread = 0.5,
             p_delegate = 0.2, advap = true)
end

m5_base_600 = make_m5_world(60, 800)
m5_long = parallel_map(m5_seeds) do seed
    run_m5(m5_base_600; seed)
end
m5_settle_acc = [settling_step(tr.final_trace; tol = 0.03) for tr in m5_long]

m5_dec_grid = [50, 100, 200, 300, 500, 800]
m5_dec_stats = map(m5_dec_grid) do ndec
    accs = [mean(tr.final_trace[1:ndec]) for tr in m5_long]
    gains = [mean(tr.final_trace[1:ndec]) - mean(tr.equal_trace[1:ndec]) for tr in m5_long]
    r_acc = record_row!("M5_governance", "decisions", 60, ndec, length(m5_seeds), "decision_accuracy", accs;
                        settle_med = median(m5_settle_acc), settle_max = maximum(m5_settle_acc))
    r_gain = record_row!("M5_governance", "decisions", 60, ndec, length(m5_seeds), "wisdom_gain_over_equal", gains;
                         settle_med = median(m5_settle_acc), settle_max = maximum(m5_settle_acc))
    (decisions = ndec, acc = r_acc, gain = r_gain)
end

m5_voter_grid = [12, 24, 40, 60, 100]
m5_voter_stats = map(m5_voter_grid) do nv
    wp = make_m5_world(nv, 300)
    trs = parallel_map(m5_seeds) do seed
        run_m5(wp; seed)
    end
    accs = [mean(tr.final_trace[151:300]) for tr in trs]
    gains = [mean(tr.final_trace[151:300]) - mean(tr.equal_trace[151:300]) for tr in trs]
    settle_a = [settling_step(tr.final_trace; tol = 0.03) for tr in trs]
    r_acc = record_row!("M5_governance", "diverse_voters", nv, 300, length(m5_seeds), "late_accuracy", accs;
                        settle_med = median(settle_a), settle_max = maximum(settle_a))
    r_gain = record_row!("M5_governance", "diverse_voters", nv, 300, length(m5_seeds), "late_wisdom_gain", gains;
                         settle_med = median(settle_a), settle_max = maximum(settle_a))
    (voters = nv, acc = r_acc, gain = r_gain)
end

# ---------------------------------------------------------------------------
# 4. M7: Diverse Population (Teacher/Learner/Novelty Diversity) & Steps
# ---------------------------------------------------------------------------
println("[4/4] Measuring M7 population convergence across diverse beings and steps...")
m7_seeds = 1:10

m7_long = parallel_map(m7_seeds) do seed
    run_m7(ToyParams(n = 100, steps = 200, plans = 10); seed,
           teacher_cv = 0.5, reception_σ = 0.5, novelty_min = 0.2, p_research = 0.1, central = false)
end
m7_settle_fu = [settling_step(diff(tr.floor_u); tol = 0.10) for tr in m7_long]
m7_settle_mu = [settling_step(diff(tr.median_u); tol = 0.10) for tr in m7_long]

m7_step_grid = [25, 50, 80, 120, 200]
m7_step_stats = map(m7_step_grid) do st
    fu_gains = [tr.floor_u[st + 1] - tr.floor_u[1] for tr in m7_long]
    mu_gains = [tr.median_u[st + 1] - tr.median_u[1] for tr in m7_long]
    r_fu = record_row!("M7_diverse_pop", "steps", 100, st, length(m7_seeds), "floor_u_gain", fu_gains;
                       settle_med = median(m7_settle_fu), settle_max = maximum(m7_settle_fu))
    r_mu = record_row!("M7_diverse_pop", "steps", 100, st, length(m7_seeds), "median_u_gain", mu_gains;
                       settle_med = median(m7_settle_mu), settle_max = maximum(m7_settle_mu))
    (steps = st, fu = r_fu, mu = r_mu)
end

m7_pop_grid = [20, 40, 60, 100, 160, 240]
m7_pop_stats = map(m7_pop_grid) do np
    trs = parallel_map(m7_seeds) do seed
        run_m7(ToyParams(n = np, steps = 100, plans = 10); seed,
               teacher_cv = 0.5, reception_σ = 0.5, novelty_min = 0.2, p_research = 0.1, central = false)
    end
    fu_gains = [tr.floor_u[end] - tr.floor_u[1] for tr in trs]
    settle_u = [settling_step(diff(tr.floor_u); tol = 0.10) for tr in trs]
    r_fu = record_row!("M7_diverse_pop", "diverse_beings_n", np, 100, length(m7_seeds), "floor_u_gain", fu_gains;
                       settle_med = median(settle_u), settle_max = maximum(settle_u))
    (n = np, fu = r_fu)
end

# ---------------------------------------------------------------------------
# Write Markdown and CSV Reports
# ---------------------------------------------------------------------------
elapsed_min = (time() - t_start) / 60

open(CSV_PATH, "w") do io
    println(io, "rung,axis,param,steps,n_seeds,metric,mean,se,rel_hw_pct,z,settle_med,settle_max")
    for r in csv_rows
        @printf(io, "%s,%s,%d,%d,%d,%s,%.6f,%.6f,%.3f,%.3f,%.1f,%.1f\n",
                r.rung, r.axis, r.param, r.steps, r.n_seeds, r.metric,
                r.mean, r.se, r.rel_hw_pct, r.z, r.settle_med, r.settle_max)
    end
end

open(MD_PATH, "w") do io
    println(io, "# Convergence & Population-Diversity Sizing Report")
    println(io)
    @printf(io, "- **Commit**: `%s`\n", commit)
    @printf(io, "- **Runtime**: `%.2f` minutes (`%d` threads)\n", elapsed_min, Threads.nthreads())
    println(io, "- **Convergence Criteria**: Running-mean settling within `10%` (`3%` for M5 accuracy), between-seed relative 95% CI half-width `<= 10%`, and signal-to-noise `z = mean / se >= 3.0`.")
    println(io)

    println(io, "## 1. M1 Metric Competition & Distributed Choice (`seeds = 1:10`)")
    @printf(io, "- **Step-rate settling (`tol = 10%%` over 1,000 steps)**: action rate median step **%.0f** (worst **%d**), `floor_u` rate median **%.0f** (worst **%d**), `floor_h` rate median **%.0f** (worst **%d**), rare floor falls median **%.0f** (worst **%d**).\n\n",
            median(m1_settle_act), maximum(m1_settle_act),
            median(m1_settle_fu), maximum(m1_settle_fu),
            median(m1_settle_fh), maximum(m1_settle_fh),
            median(m1_settle_fall), maximum(m1_settle_fall))
    println(io, "| Horizon (`steps`, `n = 200`) | `floor_u` Mean ± SE | Rel 95% Half-Width | `z` (`mean/se`) | `floor_h` Rel 95% Half-Width |")
    println(io, "|---|---|---|---|---|")
    for s in m1_step_stats
        @printf(io, "| `%d` | %.2f ± %.2f | %.1f%% | %.1f | %.1f%% |\n",
                s.steps, s.u.mean, s.u.se, s.u.rhw, s.u.z, s.h.rhw)
    end
    println(io)
    println(io, "| Diverse Population (`n`, distributed G, `200` steps) | `floor_u` Mean ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Settling Step (med / max) |")
    println(io, "|---|---|---|---|---|")
    for s in m1_pop_stats
        @printf(io, "| `%d` | %.2f ± %.2f | %.1f%% | %.1f | %.0f / %.0f |\n",
                s.n, s.u.mean, s.u.se, s.u.rhw, s.u.z, s.u.settle_med, s.u.settle_max)
    end
    println(io)

    println(io, "## 2. M3c Calibrated Realistic Economy (`seeds = 1:10`, Log-Normal Agent Skills)")
    @printf(io, "- **Post-bootstrap (`>50`) growth-rate settling (`tol = 10%%` over 600 steps)**: `floor_u` median step **%.0f** (worst **%d**), `floor_h` median step **%.0f** (worst **%d**).\n\n",
            median(m3c_settle_fu), maximum(m3c_settle_fu),
            median(m3c_settle_fh), maximum(m3c_settle_fh))
    println(io, "| Total Steps (`50` init + active, `n = 80`, `8` agents) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | `floor_h` Rel 95% Half-Width |")
    println(io, "|---|---|---|---|---|")
    for s in m3c_step_stats
        @printf(io, "| `%d` (`%d` active) | %.2f ± %.2f | %.1f%% | %.1f | %.1f%% |\n",
                s.steps, s.steps - 50, s.u.mean, s.u.se, s.u.rhw, s.u.z, s.h.rhw)
    end
    println(io)
    println(io, "| Diverse Population (`n` beings, `n_agents` log-normal, `300` steps) | Post-Init `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Settling Step (med / max) |")
    println(io, "|---|---|---|---|---|")
    for s in m3c_pop_stats
        @printf(io, "| `n = %d`, `agents = %d` | %.2f ± %.2f | %.1f%% | %.1f | %.0f / %.0f |\n",
                s.n_beings, s.n_agents, s.u.mean, s.u.se, s.u.rhw, s.u.z, s.u.settle_med, s.u.settle_max)
    end
    println(io)

    println(io, "## 3. M5 Governance with Diverse Voter Skills & Ability Caps (`seeds = 1:12`)")
    @printf(io, "- **Accuracy running-mean settling (`tol = 3%%` over 800 decisions)**: median decision **%.0f** (worst **%d**).\n\n",
            median(m5_settle_acc), maximum(m5_settle_acc))
    println(io, "| Decisions (`n_voters = 60`) | Accuracy Mean ± SE | Acc 95% Half-Width | Wisdom Gain vs Equal ± SE | Wisdom Gain `z` |")
    println(io, "|---|---|---|---|---|")
    for s in m5_dec_stats
        @printf(io, "| `%d` | %.4f ± %.4f | %.2f%% | %+.4f ± %.4f | %+.2f |\n",
                s.decisions, s.acc.mean, s.acc.se, s.acc.rhw, s.gain.mean, s.gain.se, s.gain.z)
    end
    println(io)
    println(io, "| Diverse Voters (`n_voters`, `300` decisions) | Late Accuracy Mean ± SE | Acc 95% Half-Width | Wisdom Gain vs Equal ± SE | Wisdom Gain `z` |")
    println(io, "|---|---|---|---|---|")
    for s in m5_voter_stats
        @printf(io, "| `%d` voters | %.4f ± %.4f | %.2f%% | %+.4f ± %.4f | %+.2f |\n",
                s.voters, s.acc.mean, s.acc.se, s.acc.rhw, s.gain.mean, s.gain.se, s.gain.z)
    end
    println(io)

    println(io, "## 4. M7 Population with Diverse Teachers, Learners & Novelty (`seeds = 1:10`, Distributed G)")
    @printf(io, "- **Step-rate settling (`tol = 10%%` over 200 steps)**: `floor_u` median step **%.0f** (worst **%d**), `median_u` median step **%.0f** (worst **%d**).\n\n",
            median(m7_settle_fu), maximum(m7_settle_fu),
            median(m7_settle_mu), maximum(m7_settle_mu))
    println(io, "| Steps (`n = 100`) | `floor_u` Gain ± SE | `floor_u` Rel 95% Half-Width | `floor_u` `z` | `median_u` Rel 95% Half-Width |")
    println(io, "|---|---|---|---|---|")
    for s in m7_step_stats
        @printf(io, "| `%d` | %.2f ± %.2f | %.1f%% | %.1f | %.1f%% |\n",
                s.steps, s.fu.mean, s.fu.se, s.fu.rhw, s.fu.z, s.mu.rhw)
    end
    println(io)
    println(io, "| Diverse Beings (`n`, `teacher_cv = 0.5`, `reception_σ = 0.5`, `100` steps) | `floor_u` Gain ± SE | Rel 95% Half-Width | `z` (`mean/se`) | Settling Step (med / max) |")
    println(io, "|---|---|---|---|---|")
    for s in m7_pop_stats
        @printf(io, "| `n = %d` | %.2f ± %.2f | %.1f%% | %.1f | %.0f / %.0f |\n",
                s.n, s.fu.mean, s.fu.se, s.fu.rhw, s.fu.z, s.fu.settle_med, s.fu.settle_max)
    end
end

println("Convergence report written to $MD_PATH and $CSV_PATH in $(round(elapsed_min, digits=2)) min.")
