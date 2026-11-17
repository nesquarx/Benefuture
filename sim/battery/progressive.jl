# Progressive-Complexity Battery (`docs/PLAN.md` L67; Author rulings 8.23, 8.136).
# Run: julia --project=sim sim/battery/progressive.jl --workers=7 --seeds=1:16
#
# Pre-stated hypotheses (before measuring, paired per seed at Student-t z = 3.0):
#   - P_rem_log: Every capability removal loudly logs its coarser fallback in `degraded` (100% / high rate).
#   - P_rem_order: Leaf+parent removal (StandCoin route) degrades `dip_u` / `floor_u` more severely than leaf-only
#     fallback to parent, and combined removals degrade `floor_u` / `deceivers' advantage` sharply.
#   - P_add_promote: Better additions (model class, finer measurement, viable domain, admissible rule in shadow)
#     promote on convergence (`8.136`), whereas worse additions (model class, noisy measurement, noisy domain,
#     over-optimistic rule) promote in `0 / N` seeds while the intact economy runs unharmed.

using BenefutureSim, Statistics, Random, Printf, Serialization

include(joinpath(@__DIR__, "..", "test", "legacy.jl"))

function parse_cli(args = ARGS)
    workers = 1
    seeds = collect(1:16)
    z = 3.0
    for i in eachindex(args)
        a = args[i]
        if a == "--workers" && i < length(args); workers = parse(Int, args[i + 1])
        elseif startswith(a, "--workers="); workers = parse(Int, split(a, "=", limit = 2)[2])
        elseif a == "--seeds" && i < length(args)
            v = args[i + 1]
            seeds = collect(contains(v, ":") ? let p = split(v, ":"); parse(Int, p[1]):parse(Int, p[2]) end : 1:parse(Int, v))
        elseif startswith(a, "--seeds=")
            v = split(a, "=", limit = 2)[2]
            seeds = collect(contains(v, ":") ? let p = split(v, ":"); parse(Int, p[1]):parse(Int, p[2]) end : 1:parse(Int, v))
        elseif startswith(a, "--z="); z = parse(Float64, split(a, "=", limit = 2)[2])
        end
    end
    (workers = workers, seeds = seeds, z = z)
end

const CLI = isempty(ARGS) || ARGS[1] == "--worker" ? (workers = 1, seeds = collect(1:16), z = 3.0) : parse_cli(ARGS)
const BUILD = current_commit()
const EV_STEP = 81
const EV_DUR = 60

function removal_world(sq::Bool; events = Shock[], σ_leaf = 0.45, marker_σ = 0.3,
                       threshold = 0.78, coarse_threshold = 0.65, cost_per_touch = 0.12)
    skills = draw_skills(Xoshiro(20261117), 8, 4, [1, 2, 3]; median = 0.6)
    agents = [DomainAgent(skills[a, :], [0.5, 0.25, 0.25, 0.0], 0.25) for a in 1:8]
    deceit = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5]
    ww = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.05]
    inst = sq ? (vigilance = 0.001, cost_σ = 0.3, memory_loss = 0.1, p_false_trace = 0.05, p_informed = 0.6, dil = 0.4, advap = false) :
                (vigilance = 0.1, cost_σ = 0.05, memory_loss = 0.0, p_false_trace = 0.005, p_informed = 0.95, dil = 0.95, advap = true)
    M3cParams(ToyParams(n = 80, steps = 240, plans = 10), agents, [1, 1, 2, 2], [true, true, true, false];
              λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
              init_steps = 40, min_records = 10, takeover_records = 15, model_z = 2.0,
              threshold = threshold, coarse_threshold = coarse_threshold, cost_per_touch = cost_per_touch,
              σ_leaf = σ_leaf, marker_σ = marker_σ, p_new_model = 0.05,
              chain_attrib = [1.0, 0.7], chain_mode = :domain, chain_spot = 0.2,
              guardians = [1, 2, 3, 4], diligence = fill(inst.dil, 8), p_informed = inst.p_informed,
              p_hazard = 0.03, repair_efficiency = 0.5, deceit = deceit, whitewash = ww,
              bind_quorum = 2, bind_clusters = 3, bind_weighted = true,
              advap = inst.advap, vigilance = inst.vigilance, cost_σ = inst.cost_σ,
              memory_loss = inst.memory_loss, p_false_trace = inst.p_false_trace,
              events = events)
end

function run_removal_seed(seed::Int)
    base_int = run_m3c(removal_world(false); seed)
    base_sq = run_m3c(removal_world(true); seed)
    cap_ev = shock(:capture; step = EV_STEP + 4, duration = 50, size = 2.5, target = 1)
    cap_int = run_m3c(removal_world(false; events = [cap_ev]); seed)

    specs = [
        (key = :leaf_removed,          label = "Leaf models removed -> parent",    events = [shock(:remove_leaf_models; step = EV_STEP, duration = EV_DUR, target = 1)], key_match = "leaf domain pricing", ref = base_int),
        (key = :leaf_parent_standcoin, label = "Leaf + parent removed -> StandCoin", events = [shock(:remove_leaf_models; step = EV_STEP, duration = EV_DUR, target = 0), shock(:remove_parent_models; step = EV_STEP, duration = EV_DUR, target = 0)], key_match = "StandCoin", ref = base_int),
        (key = :pool_to_one,           label = "Model pool capped to 1 (w/ capture)", events = [cap_ev, shock(:cap_pool_one; step = EV_STEP, duration = EV_DUR, target = 0)], key_match = "model pool", ref = cap_int),
        (key = :chains_to_one,         label = "Measurement chains reduced to 1",  events = [shock(:single_chain; step = EV_STEP, duration = EV_DUR)], key_match = "single chain", ref = base_int),
        (key = :advap_off,             label = "AdvAp disabled mid-run",           events = [shock(:disable_advap; step = EV_STEP, duration = EV_DUR)], key_match = "AdvAp", ref = base_int),
        (key = :binding_lost,          label = "Identity binding lost mid-run",    events = [shock(:lose_binding; step = EV_STEP, duration = EV_DUR)], key_match = "identity binding", ref = base_int),
        (key = :legacy_only,           label = "Legacy institutions only mid-run", events = [shock(:legacy_only; step = EV_STEP, duration = EV_DUR)], key_match = "legacy institutions only", ref = base_int),
        (key = :combined_removal,      label = "Combined (leaf + chain + AdvAp + bind)", events = [shock(:remove_leaf_models; step = EV_STEP, duration = EV_DUR, target = 1), shock(:single_chain; step = EV_STEP, duration = EV_DUR), shock(:disable_advap; step = EV_STEP, duration = EV_DUR), shock(:lose_binding; step = EV_STEP, duration = EV_DUR)], key_match = "single chain", ref = base_int),
    ]

    rem_out = Dict{Symbol,Any}()
    sq_fu = base_sq.floor_u[end] - base_sq.floor_u[41]
    for sp in specs
        tr = run_m3c(removal_world(false; events = sp.events); seed)
        pm = progressive_metrics(tr, sp.ref; event_step = EV_STEP)
        fu_gain = tr.floor_u[end] - tr.floor_u[41]
        logged = any(k -> occursin(sp.key_match, k), keys(tr.degraded))
        rem_out[sp.key] = (dip_u = pm.dip_u, dip_h = pm.dip_h, end_diff_u = pm.end_diff_u,
                           rec_time = Float64(pm.recovery_time), recovered = pm.recovery_step > 0,
                           vs_sq_u = fu_gain - sq_fu, logged = logged, label = sp.label)
    end

    # Coupled governance freeze (vs active coupled shadow baseline):
    ag_g = [DomainAgent([0.6, 0.0], [1.0, 0.0], 0.0) for _ in 1:8]
    par_timid = copy(bootstrap_params()); par_timid[1] = 0.25; par_timid[2] = 0.20; par_timid[3] = 0.15; par_timid[4] = 0.05; par_timid[6] = 1.05; par_timid[7] = 50.0; par_timid[8] = 1.0
    gov(tr) = M5Params(tr, 1:1; decisions = 1, p_delegate = 0.2)
    ec_gov_base = M3cParams(ToyParams(n = 40, steps = 280, plans = 6), ag_g, [1, 1], [true, false];
                            λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                            init_steps = 5, min_records = 8, threshold = 0.70, model_z = 2.0, endowment = 20.0,
                            converge_init = true, legacy_funder = true)
    ec_gov_frz = M3cParams(ToyParams(n = 40, steps = 280, plans = 6), ag_g, [1, 1], [true, false];
                           λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                           init_steps = 5, min_records = 8, threshold = 0.70, model_z = 2.0, endowment = 20.0,
                           converge_init = true, legacy_funder = true,
                           events = [shock(:freeze_governance; step = 81, duration = 200)])
    rc_act = run_coupled(ec_gov_base, gov; seed, epoch = 40, continuous = true, incumbent_pv = par_timid, candidate_pv = bootstrap_params(), candidate_prediction = 0.0, candidate_eta = 2, shadow = true, add_rule_epoch = 3)
    rc_frz = run_coupled(ec_gov_frz,  gov; seed, epoch = 40, continuous = true, incumbent_pv = par_timid, candidate_pv = bootstrap_params(), candidate_prediction = 0.0, candidate_eta = 2, shadow = true, add_rule_epoch = 3)
    ec_gov_sq = M3cParams(ToyParams(n = 40, steps = 280, plans = 6), ag_g, [1, 1], [true, false];
                          λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                          init_steps = 5, min_records = 8, threshold = 0.70, model_z = 2.0, endowment = 20.0,
                          advap = false, vigilance = 0.001, cost_σ = 0.3, memory_loss = 0.1, diligence = fill(0.4, 8), p_informed = 0.6)
    r_gov_sq = run_m3c(ec_gov_sq; seed)
    pm_frz = progressive_metrics(rc_frz, rc_act; event_step = 81)
    rem_out[:gov_frozen] = (dip_u = pm_frz.dip_u, dip_h = pm_frz.dip_h, end_diff_u = pm_frz.end_diff_u,
                            rec_time = Float64(pm_frz.recovery_time), recovered = pm_frz.recovery_step > 0,
                            vs_sq_u = rc_frz.success.floor_u - (r_gov_sq.floor_u[end] - r_gov_sq.floor_u[1]),
                            logged = any(k -> occursin("governance", k), keys(rc_frz.degraded)),
                            label = "Governance frozen mid-run (coupled)")

    # Capability additions (8.136 score-only entry -> convergence promotion):
    ag_m = [DomainAgent([0.35, 0.35], [1.0, 0.0], 0.0) for _ in 1:8]
    ag_d = [DomainAgent([0.6, 0.6], [1.0, 0.0], 0.0) for _ in 1:8]
    T240 = ToyParams(n = 80, steps = 240, plans = 10)
    T200 = ToyParams(n = 80, steps = 200, plans = 10)
    mkw = (λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, init_steps = 50, min_records = 10, takeover_records = 20, model_z = 2.0, acc_halflife = 25.0, threshold = 0.65, coarse_threshold = 0.65, σ_leaf = 0.85, marker_σ = 0.3, bias_σ = 0.0, σ_branch = 0.85, σ_coarse = 0.9)
    fkw = (λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, init_steps = 50, min_records = 10, takeover_records = 15, model_z = 2.0, threshold = 0.65, coarse_threshold = 0.65, σ_leaf = 0.35, marker_σ = 0.5, σ_branch = 0.5, σ_coarse = 0.6)
    dkw = (λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, init_steps = 50, min_records = 10, takeover_records = 15, model_z = 2.0, threshold = 0.75, σ_leaf = 0.2, marker_σ = 0.2, σ_branch = 0.4, σ_coarse = 0.6)

    m_base = run_m3c(M3cParams(T240, ag_m, [1, 1], [true, false]; mkw...); seed)
    m_sq   = run_m3c(M3cParams(T240, ag_m, [1, 1], [true, false]; mkw..., advap = false, vigilance = 0.001, cost_σ = 0.3, memory_loss = 0.1, diligence = fill(0.4, 8), p_informed = 0.6); seed)
    m_good = run_m3c(M3cParams(T240, ag_m, [1, 1], [true, false]; mkw..., events = [shock(:add_model_class; step = 55, size = 0.1, target = 1)]); seed)
    m_bad  = run_m3c(M3cParams(T240, ag_m, [1, 1], [true, false]; mkw..., events = [shock(:add_model_class; step = 55, size = 4.0, target = 1)]); seed)

    f_base = run_m3c(M3cParams(T200, ag_d, [1, 1], [true, false]; fkw...); seed)
    f_sq   = run_m3c(M3cParams(T200, ag_d, [1, 1], [true, false]; fkw..., advap = false, vigilance = 0.001, cost_σ = 0.3, memory_loss = 0.1, diligence = fill(0.4, 8), p_informed = 0.6); seed)
    f_good = run_m3c(M3cParams(T200, ag_d, [1, 1], [true, false]; fkw..., events = [shock(:add_finer_measurement; step = 55, size = 0.1)]); seed)
    f_bad  = run_m3c(M3cParams(T200, ag_d, [1, 1], [true, false]; fkw..., events = [shock(:add_finer_measurement; step = 55, size = 4.0)]); seed)

    d_base = run_m3c(M3cParams(T200, ag_d, [1, 1], [true, false]; dkw...); seed)
    d_sq   = run_m3c(M3cParams(T200, ag_d, [1, 1], [true, false]; dkw..., advap = false, vigilance = 0.001, cost_σ = 0.3, memory_loss = 0.1, diligence = fill(0.4, 8), p_informed = 0.6); seed)
    d_good = run_m3c(M3cParams(T200, ag_d, [1, 1], [true, false]; dkw..., events = [shock(:add_domain; step = 55, target = 2, share = 0.5, size = 1.0)]); seed)
    d_bad  = run_m3c(M3cParams(T200, ag_d, [1, 1], [true, false]; dkw..., events = [shock(:add_domain; step = 55, target = 2, share = 0.5, size = 10.0)]); seed)

    bad_pv = copy(bootstrap_params()); bad_pv[6] = 1.9; bad_pv[7] = 1.1; bad_pv[8] = 0.0
    rc_none = run_coupled(ec_gov_base, gov; seed, epoch = 40, continuous = true, incumbent_pv = par_timid, shadow = true)
    rc_bad  = run_coupled(ec_gov_base, gov; seed, epoch = 40, continuous = true, incumbent_pv = par_timid, candidate_pv = bad_pv, candidate_threshold = 0.5, candidate_track_window = 0, candidate_prediction = 40.0, candidate_eta = 2, candidate_vs_incumbent = true, shadow = true, add_rule_epoch = 3)

    add_entry(tr, ref, sqr, from_step, label) = (
        promoted = tr.added_capabilities[1].promoted,
        ptime = Float64(tr.added_capabilities[1].promotion_time),
        vs_intact_u = (tr.floor_u[end] - ref.floor_u[end]),
        vs_sq_u = (tr.floor_u[end] - tr.floor_u[from_step]) - (sqr.floor_u[end] - sqr.floor_u[from_step]),
        label = label,
    )
    add_out = Dict{Symbol,Any}(
        :add_better_model => add_entry(m_good, m_base, m_sq, 51, "Model class: better (`0.1×`)"),
        :add_worse_model  => add_entry(m_bad,  m_base, m_sq, 51, "Model class: worse (`4.0×`)"),
        :add_finer_meas   => add_entry(f_good, f_base, f_sq, 51, "Finer measurement (`0.1×`)"),
        :add_worse_meas   => add_entry(f_bad,  f_base, f_sq, 51, "Noisier measurement (`4.0×`)"),
        :add_good_domain  => add_entry(d_good, d_base, d_sq, 51, "New domain: viable (`1.0×`)"),
        :add_noisy_domain => add_entry(d_bad,  d_base, d_sq, 51, "New domain: noisy (`10.0×`)"),
        :add_better_rule  => (promoted = rc_act.shadow_promoted, ptime = Float64(rc_act.promotion_time), vs_intact_u = rc_act.success.floor_u - rc_none.success.floor_u, vs_sq_u = rc_act.success.floor_u - (r_gov_sq.floor_u[end] - r_gov_sq.floor_u[1]), label = "New rule: better (`shadow 8.136`)"),
        :add_worse_rule   => (promoted = rc_bad.shadow_promoted, ptime = Float64(rc_bad.promotion_time), vs_intact_u = rc_bad.success.floor_u - rc_none.success.floor_u, vs_sq_u = rc_bad.success.floor_u - (r_gov_sq.floor_u[end] - r_gov_sq.floor_u[1]), label = "New rule: worse/over-optimistic"),
    )
    (removals = rem_out, additions = add_out)
end

if !isempty(ARGS) && ARGS[1] == "--worker"
    s = parse(Int, split(ARGS[findfirst(a -> startswith(a, "--seed="), ARGS)], "=")[2])
    out_p = split(ARGS[findfirst(a -> startswith(a, "--out="), ARGS)], "="; limit = 2)[2]
    serialize(out_p, run_removal_seed(s))
else
    function run_main()
        t0 = time()
        mkpath(joinpath(@__DIR__, "results"))
        mkpath(joinpath(@__DIR__, "state"))
        seeds = CLI.seeds
        n = length(seeds)
        pt = progress_tracker(joinpath(@__DIR__, "state", "progressive.progress"), "progressive", n; interval = 300.0)
        results = if CLI.workers <= 1
            [begin r = run_removal_seed(s); progress_tick!(pt, i, "seed=$s"); r end for (i, s) in enumerate(seeds)]
        else
            dir = mktempdir()
            script = abspath(@__FILE__)
            proj = abspath(joinpath(@__DIR__, ".."))
            julia = Base.julia_cmd()[1]
            out = Vector{Any}(undef, n)
            done_n = 0
            next_i = 1
            active = Tuple{Int, Base.Process, String}[]
            try
                while next_i <= n || !isempty(active)
                    while next_i <= n && length(active) < CLI.workers
                        i = next_i; s = seeds[i]; next_i += 1
                        out_p = joinpath(dir, "s_$(s).jls")
                        cmd = `$julia --project=$proj $script --worker --seed=$s --out=$out_p`
                        push!(active, (i, run(pipeline(cmd; stdout = devnull, stderr = devnull); wait = false), out_p))
                    end
                    sleep(0.25)
                    still = Tuple{Int, Base.Process, String}[]
                    for (i, p, out_p) in active
                        if process_exited(p)
                            p.exitcode == 0 || error("progressive worker failed on seed $(seeds[i])")
                            out[i] = deserialize(out_p)
                            done_n += 1
                            progress_tick!(pt, done_n, "seed=$(seeds[i])")
                        else
                            push!(still, (i, p, out_p))
                        end
                    end
                    active = still
                end
            finally
                rm(dir; recursive = true, force = true)
            end
            out
        end
        progress_finish!(pt, "completed")
        elapsed = (time() - t0) / 60

        rem_order = [:leaf_removed, :leaf_parent_standcoin, :pool_to_one, :chains_to_one, :advap_off, :gov_frozen, :binding_lost, :legacy_only, :combined_removal]
        add_order = [:add_better_model, :add_worse_model, :add_finer_meas, :add_worse_meas, :add_good_domain, :add_noisy_domain, :add_better_rule, :add_worse_rule]

        csv_rows = ["section,arm,n_seeds,metric,mean,se,z_raw,significant_z3,rate_or_prop"]
        md = IOBuffer()
        println(md, "# Progressive-Complexity Battery Report (`docs/PLAN.md` L67; `z = $(CLI.z)`, Student-t inflated)")
        @printf(md, "\n- **Commit**: `%s` · **Seeds**: `1:%d` (`n = %d`) · **Runtime**: `%.1f min` · **Workers**: `%d`\n\n",
                BUILD, maximum(seeds), n, elapsed, CLI.workers)

        println(md, "## 1. Capability Removals (Step `81`, Duration `60`, Paired vs Intact & Matched Status-Quo Arm)")
        println(md, "| Removal Arm | `degraded` Logged (`rate`, Wilson lo) | `dip_u` vs Intact (`z_raw`, `z>=3`) | `end_diff_u` vs Intact | Recovery (steps / `recovered`) | `floor_u` vs SQ (`z_raw`, `z>=3`) |")
        println(md, "|---|---|---|---|---|---|")
        for k in rem_order
            xs = [r.removals[k] for r in results]
            lbl = xs[1].label
            n_log = count(x -> x.logged, xs)
            pi_log = proportion_interval(n_log, n)
            pdip = paired_effect([x.dip_u for x in xs]; z = CLI.z, direction = :down)
            pend = paired_effect([x.end_diff_u for x in xs]; z = CLI.z)
            psq = paired_effect([x.vs_sq_u for x in xs]; z = CLI.z)
            psq_sig = psq.significant || paired_effect([x.vs_sq_u for x in xs]; z = CLI.z, direction = :down).significant
            n_rec = count(x -> x.recovered, xs)
            recs = [x.rec_time for x in xs if x.recovered]
            rec_s = isempty(recs) ? "—" : @sprintf("%.1f", mean(recs))
            @printf(md, "| %s | `%d/%d` (`%.2f`) | %.2f ± %.2f (`%.2f`, %s) | %.2f ± %.2f | %s (`%d/%d`) | %+.2f ± %.2f (`%.2f`, %s) |\n",
                    lbl, n_log, n, pi_log.lo, pdip.mean, pdip.se, pdip.mean / max(pdip.se, 1e-12), pdip.significant ? "yes" : "no",
                    pend.mean, pend.se, rec_s, n_rec, n, psq.mean, psq.se, psq.mean / max(psq.se, 1e-12), psq_sig ? "yes" : "no")
            push!(csv_rows, @sprintf("removal,%s,%d,dip_u,%.6f,%.6f,%.3f,%s,%.4f", k, n, pdip.mean, pdip.se, pdip.mean / max(pdip.se, 1e-12), pdip.significant, n_log / n))
            push!(csv_rows, @sprintf("removal,%s,%d,vs_sq_u,%.6f,%.6f,%.3f,%s,%.4f", k, n, psq.mean, psq.se, psq.mean / max(psq.se, 1e-12), psq_sig, n_rec / n))
        end
        println(md)

        println(md, "## 2. Capability Additions (`8.136` Score-Only Entry -> Convergence Promotion)")
        println(md, "| Addition Arm | Promoted (`rate`, Wilson lo) | Mean Promotion Time | `floor_u` vs Intact (`z_raw`, `z>=3`) | `floor_u` vs SQ (`z_raw`, `z>=3`) |")
        println(md, "|---|---|---|---|---|")
        for k in add_order
            xs = [r.additions[k] for r in results]
            lbl = xs[1].label
            np = count(x -> x.promoted, xs)
            pip = proportion_interval(np, n)
            pts = [x.ptime for x in xs if x.promoted]
            pt_s = isempty(pts) ? "—" : @sprintf("%.1f", mean(pts))
            pint = paired_effect([x.vs_intact_u for x in xs]; z = CLI.z)
            pint_sig = pint.significant || paired_effect([x.vs_intact_u for x in xs]; z = CLI.z, direction = :down).significant
            psq = paired_effect([x.vs_sq_u for x in xs]; z = CLI.z)
            psq_sig = psq.significant || paired_effect([x.vs_sq_u for x in xs]; z = CLI.z, direction = :down).significant
            @printf(md, "| %s | `%d/%d` (`%.2f`) | %s | %+.2f ± %.2f (`%.2f`, %s) | %+.2f ± %.2f (`%.2f`, %s) |\n",
                    lbl, np, n, pip.lo, pt_s, pint.mean, pint.se, pint.mean / max(pint.se, 1e-12), pint_sig ? "yes" : "no",
                    psq.mean, psq.se, psq.mean / max(psq.se, 1e-12), psq_sig ? "yes" : "no")
            push!(csv_rows, @sprintf("addition,%s,%d,vs_intact_u,%.6f,%.6f,%.3f,%s,%.4f", k, n, pint.mean, pint.se, pint.mean / max(pint.se, 1e-12), pint_sig, np / n))
            push!(csv_rows, @sprintf("addition,%s,%d,vs_sq_u,%.6f,%.6f,%.3f,%s,%.4f", k, n, psq.mean, psq.se, psq.mean / max(psq.se, 1e-12), psq_sig, np / n))
        end

        write(joinpath(@__DIR__, "results", "progressive.md"), String(take!(md)))
        write(joinpath(@__DIR__, "results", "progressive.csv"), join(csv_rows, "\n") * "\n")
        println("Progressive-complexity battery finished in $(round(elapsed; digits = 1)) min -> sim/battery/results/progressive.{md,csv}")
    end
    run_main()
end
