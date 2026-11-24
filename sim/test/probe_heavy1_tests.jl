# Heavy mechanism probes 1 of 3 (full tier: nightly and workflow_dispatch; not in BF_TIER=fast). Moved verbatim from
# probe_tests.jl because each took over 30 s (author: "make sure probes are fast"); claims and bounds unchanged.
# Run all three: julia --project=sim sim/test/probes_heavy.jl. Each has a fast "Smoke:" version at the end of probe_tests.jl
# (docs/BACKPROPAGATION.md, probe speed); the statistical claims stay here.
using Random, Statistics

isdefined(@__MODULE__, Symbol("@timed_testset")) || include(joinpath(@__DIR__, "probe_timing.jl"))


# Spike D2: Empirical-Bayes credence (`eb_credence`, L84, `8.58-c`) eliminates extremist takeover
# dominance on `ext_world` without stalling under heavy-tailed side harm (`calibrated_tests.jl`).
@timed_testset "Probe: Spike D2 Empirical-Bayes credence (eb_credence) closes extremist takeover dominance without heavy-tail stalls (8.58-c, L84) (P49)" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    ext_world(; kw...) = M3cParams(ToyParams(n = 80, steps = 400, plans = 10),
        [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.3) for _ in 1:8],
        [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
        LEGACY..., σ_leaf = 0.45, σ_branch = 0.6, σ_coarse = 0.75, p_new_model = 0.05,
        improve_drift = 0.0, improve_σ = 0.0, p_extremist = 0.5, extremise = 0.5, credence_rule = :normal, kw...)

    ts_n = [run_m3c(ext_world(credence_rule = :normal); seed) for seed in 1:16]
    ts_eb = [run_m3c(ext_world(credence_rule = :eb); seed) for seed in 1:16]
    ext_n, tot_n = sum(tr.takeovers_extreme for tr in ts_n), sum(tr.takeovers for tr in ts_n)
    ext_eb, tot_eb = sum(tr.takeovers_extreme for tr in ts_eb), sum(tr.takeovers for tr in ts_eb)
    @test tot_n > 0 && proportion_interval(ext_n, tot_n).lo > 0.5   # red: :normal lets extremists dominate takeovers
    ext_eb_lo = tot_eb > 0 ? proportion_interval(ext_eb, tot_eb).lo : 0.0
    @test !(ext_eb_lo > 0.5)
    @test ext_eb < ext_n ÷ 2
    @test mean(mean(tr.leaf_accuracy[[1, 3]]) for tr in ts_eb) >=
          mean(mean(tr.leaf_accuracy[[1, 3]]) for tr in ts_n) - 0.01

    hon_n = [run_m3c(ext_world(credence_rule = :normal, p_extremist = 0.0); seed) for seed in 1:2]
    hon_eb = [run_m3c(ext_world(credence_rule = :eb, p_extremist = 0.0); seed) for seed in 1:2]
    mid_n = [r for tr in hon_n for j in (1, 3) for r in tr.leaf_records[j] if 0.5 <= r.credence < 0.9]
    mid_eb = [r for tr in hon_eb for j in (1, 3) for r in tr.leaf_records[j] if 0.5 <= r.credence < 0.9]
    gap_n = mean(r.outcome for r in mid_n) - mean(r.credence for r in mid_n)
    gap_eb = mean(r.outcome for r in mid_eb) - mean(r.credence for r in mid_eb)
    @test gap_n > 0.1                                             # red: honest :normal credences underconfident mid-range
    @test abs(gap_eb) < abs(gap_n) && abs(gap_eb) < 0.1           # green: empirical prior closes mid-range underconfidence

    skills = draw_skills(Xoshiro(20261031), 8, 4, [1, 3]; median = 0.6)
    agents = [DomainAgent(skills[a, :], [0.5, 0, 0.5, 0], CALIBRATED.sloppiness) for a in 1:8]
    ht_world(rule) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10), agents, [1, 1, 2, 2], trues(4);
        λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, p_upstream = 0.5,
        guardians = [1, 2, 3, 4], diligence = fill(0.95, 8), p_foresee = 1.0, repair_efficiency = 0.5,
        advap = true, marker_σ = 0.1, bias_σ = 0.1, classify_σ = 0.05, spread = 0.05, cost_σ = 0.05,
        regen_σ = 0.3, attribution_σ = 0.1, p_hazard = 0.05, p_informed = 0.95, vigilance = 0.1,
        p_false_trace = 0.005, p_side = 0.01 + 0.09 * 0.6, credence_rule = rule)
    ht_seeds = 1:64   # 32 left the binary stalled-indicator contrast at the edge of z = 3 (Linux CI failed it); 64 gives it the power
    ht_nrm = [run_m3c(ht_world(:normal); seed) for seed in ht_seeds]
    ht_eb = [run_m3c(ht_world(:eb); seed) for seed in ht_seeds]
    growth(tr) = success_pattern(tr; from = 51).floor_u
    stalled(tr) = tr.lane_halted > 500 && minimum(tr.leaf_accuracy[[1, 3]]) < 0.75
    @test paired_effect(growth.(ht_eb) .- growth.(ht_nrm); z = 3.0).significant
    @test paired_effect(Float64.(getfield.(ht_nrm, :lane_halted)) .- Float64.(getfield.(ht_eb, :lane_halted)); z = 3.0).significant
    @test paired_effect(Float64.(stalled.(ht_nrm)) .- Float64.(stalled.(ht_eb)); z = 3.0).significant
    @test proportion_interval(count(!stalled, ht_eb), length(ht_seeds)).lo > 0.70
    @test proportion_interval(count(t -> t.lane_halted <= 20, ht_eb), length(ht_seeds)).lo > 0.60
end


# IH in the candidate-adoption vote (`run_coupled`, `ih_vote`; WORLD_COVERAGE step 1 follow-up). A harmful candidate (`bad_pv`, no
# track-record correction) is on offer every epoch with honest readings centred below zero (`candidate_merit = -1`); half the voters are
# colluding liars who always vote adopt and republish that as their reading, voters defer to what they hear (the limiting case where
# lies bite, 8.63). Uncoupled, so the vote is the only gate. Baseline (IH off, voters alone): the candidate is adopted in every epoch
# and the Goal pattern (floor_u + floor_h) is lower; with IH on, the vote reads through M5's deliberation (sources weighed by live
# records from `m5_decisions`, tags counted once, tag audit) and adoption falls. Arms share seeds; the count is `seeds_until_stable`'s.
@timed_testset "Probe: IH in the adoption vote lowers harmful adoption without costing the Goal pattern (run_coupled ih_vote)" begin
    ag = [DomainAgent([k == l ? (r == 1 ? -0.9 : 0.1 + 0.4 * (r - 1) / 11) : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
          for k in 1:4 for r in 1:12]
    dec = [r == 1 ? 1.5 : 0.0 for k in 1:4 for r in 1:12]
    econ = M3cParams(ToyParams(n = 60, steps = 150, plans = 8), ag, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                     transactions = true, causal_distribution = true, init_steps = 50, deceit = dec, track_window = 20,
                     actor_min_records = 10, advap = true, vigilance = 0.2, p_trace = 0.9, repair_efficiency = 0.8, credence_rule = :record)
    liars = collect(1:2:48)
    D = (advice_stay = 0.0, advice_avg = 0.0, advice_defer = 1.0)
    bad_pv = copy(bootstrap_params()); bad_pv[6] = 1.9; bad_pv[7] = 1.1; bad_pv[8] = 0.0
    function arm(on, seed)
        gov(tr) = M5Params(tr, 1:4; decisions = 1, signal_σ = 20.0, colluders = liars, stealth = true, loyalty = 2.0, p_delegate = 0.2,
                           (on ? (deliberation = true, source_tags = true, tag_audit = true, tag_liars = liars, ih_vote = true, D...) : (;))...)
        r = run_coupled(econ, gov; seed, epoch = 25, coupled = false, m5_decisions = 600,
                        candidate_pv = bad_pv, candidate_track_window = 0, candidate_merit = -1.0)
        (adopt = mean(r.adopted_candidate), goal = r.success.floor_u + r.success.floor_h)
    end
    runs = Dict{Int,Any}()
    both(seed) = get!(runs, seed) do; (arm(false, seed), arm(true, seed)); end
    drop = seeds_until_stable(seed -> (o = both(seed)[1].adopt - both(seed)[2].adopt; o); tol = 0.08, min_seeds = 8, max_seeds = 12)   # min 8: the Goal claim below needs its own power, the adoption drop alone stabilises at 4 seeds on Linux
    @info "IH adoption vote: seeds used" n = drop.n stable = drop.stable adoption_drop = (drop.mean, drop.se)
    # counterexample: with IH off a harmful candidate is adopted in every epoch
    @test all(both(s)[1].adopt == 1.0 for s in drop.seeds)
    # acceptance: IH lowers harmful adoption (z = 2, paired seeds) ...
    @test paired_effect(drop.values; direction = :up).significant
    # ... and the Goal pattern is no worse: the loss (off - on) stays below 3 units (one-sided: a gain is welcome; measured on Linux over 10 seeds
    # +2.9 +- 1.1, per-seed differences from -1.5 to +7; the author's 6-seed run read +2.4 +- 1.1). The seed count follows the adoption drop's precision,
    # which settled at 4 seeds on Linux, where the Goal difference (+0.8 +- 1.3, upper bound 3.5) is too imprecise to show the claim: the claim held,
    # the test was under-powered, so the floor of 8 seeds is the fix (upper bound 0.1 at 8 seeds), not a looser margin.
    goal = [both(s)[2].goal - both(s)[1].goal for s in drop.seeds]
    @info "IH adoption vote: Goal pattern difference (on - off)" goal mean = mean(goal) se = std(goal) / sqrt(length(goal))
    @test equivalent(-goal; margin = 3.0, side = :upper).equivalent
end


# Information handling in the composed world (`L134` IH, 8.44-8.45, 8.167a; WORLD_COVERAGE step 1, P51). Twelve voters in each of
# four domains, half of them colluding liars whose readings are republished with falsified tags, voters deferring to what they hear
# (the limiting case where lies bite, 8.63). Arms on the same seeds: voters alone (IH off), hearing without handling (no weights by
# record, no tags), and IH (record-weighted ContentionMap, tags counted once, AdvAp's tag audit). Truth levels are not assigned here:
# the Lean reference has no classifier (only the chain rule), so IH weighs sources by their records and tags alone (gap, 8.167a).
@timed_testset "Probe: IH (record-weighted sources, tags, audit) resists a lying source that sways unhandled hearing (P51)" begin
    m3 = run_m3c(M3cParams(ToyParams(n = 40, steps = 100, plans = 6),
                           [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 11 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:12], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    liars = collect(1:2:48)
    D = (advice_stay = 0.0, advice_avg = 0.0, advice_defer = 1.0)
    C = (colluders = liars, stealth = true, loyalty = 2.0)
    seeds = 1:8
    arm(; kw...) = [run_m5(M5Params(m3, 1:4; decisions = 600, signal_σ = 20.0, kw...); seed).correct for seed in seeds]
    off = arm(; C...)
    unhandled = arm(; deliberation = true, info_handling = false, tag_liars = liars, D..., C...)
    ih = arm(; deliberation = true, source_tags = true, tag_liars = liars, D..., C...)
    # counterexample: hearing without handling lets the lying source sway votes (worse than voting alone)
    @test paired_effect(off .- unhandled; direction = :up).significant
    # acceptance: IH decides better than both (+0.019 vs off z 3.2, +0.045 vs unhandled z 7.3 over 8 seeds)
    @test paired_effect(ih .- off; direction = :up).significant
    @test paired_effect(ih .- unhandled; direction = :up).significant
    # with realistic advice taking IH costs nothing (equivalent to voting alone within 0.03)
    real = arm(; deliberation = true, source_tags = true, tag_liars = liars, C...)
    @test equivalent(real .- off; margin = 0.03).equivalent
    # live records: sources start weighed by the record an earlier epoch accumulated, not blind
    first = run_m5(M5Params(m3, 1:4; decisions = 600, signal_σ = 20.0, deliberation = true, source_tags = true, tag_liars = liars, D..., C...); seed = 1)
    early(r) = mean(r.correct_trace[1:150])
    blind = [early(run_m5(M5Params(m3, 1:4; decisions = 250, signal_σ = 20.0, deliberation = true, source_tags = true, tag_liars = liars, D..., C...); seed)) for seed in 2:13]
    informed = [early(run_m5(M5Params(m3, 1:4; decisions = 250, signal_σ = 20.0, deliberation = true, source_tags = true, tag_liars = liars, D..., C...); seed, records = first.records)) for seed in 2:13]
    @test paired_effect(informed .- blind; direction = :up).significant
    @test_throws ArgumentError run_m5(M5Params(m3, 1:4; deliberation = true); seed = 1, records = [[0.0, 0.0]])
end


@timed_testset "Probe: M3c repair_credit (8.26.1), accolade_counterfactual (8.26.2), and fork_family (B27) (P46)" begin
    skills = [0.8 0.0 0.0 0.0; 0.7 0.0 0.0 0.0; 0.6 0.0 0.0 0.0; 0.5 0.0 0.0 0.0;
              0.0 0.6 0.0 0.0; 0.0 0.5 0.0 0.0; 0.8 0.0 0.0 0.0]
    agents = [DomainAgent(skills[i, :], i <= 4 || i == 7 ? [1.0, 0.0, 0.0, 0.0] : [0.0, 1.0, 0.0, 0.0],
                          i == 2 ? 0.35 : 0.0) for i in 1:7]
    p_rep(; repair_credit = false, accolade_counterfactual = false) =
        M3cParams(ToyParams(n = 40, steps = 80, plans = 6), agents[1:6], [1, 1, 2, 2], trues(4);
                  λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                  p_upstream = 0.6, guardians = [1, 1, 5, 5], diligence = fill(0.95, 6),
                  p_hazard = 0.25, hazard_size = 2.0, repair_efficiency = 0.5,
                  repair_credit, accolade_counterfactual)
    p46_seeds = 1:32
    off = [run_m3c(p_rep(); seed) for seed in p46_seeds]
    on_rep = [run_m3c(p_rep(repair_credit = true); seed) for seed in p46_seeds]
    on_both = [run_m3c(p_rep(repair_credit = true, accolade_counterfactual = true); seed) for seed in p46_seeds]
    @test all(tr -> tr.repair_actions == 0 && tr.repair_credited == 0.0 && tr.accolades_suppressed == 0, off)
    @test all(tr -> tr.repair_actions > 0 && tr.repair_credited > 0.0, on_rep)
    rep_diffs = [sum(r.relevance_leaf[1, :]) + sum(r.h_pos_own[1, :]) - (sum(o.relevance_leaf[1, :]) + sum(o.h_pos_own[1, :]))
                 for (o, r) in zip(off, on_rep)]
    # Repair credit fires rarely in this 80-step world (a hazard must hit a guarded lane and be repaired), so the paired
    # difference is zero in most seeds and heavy-tailed in the rest; a mean test is under-powered (32 seeds: :eb +6.01 +- 3.54,
    # :record +1.32 +- 0.56, neither significant at z = 3). The claim is the sign: crediting repair never lowers a repairer's
    # relevance (no seed negative) and raises it where it fires (7 of 32 under :eb, 5 under :record; all-positive among
    # the nonzero ones has sign-test p <= 2^-6 = 0.016).
    @test count(<(0.0), rep_diffs) == 0
    # How often it fires is platform- and gate-dependent (positives: 4/32 before the 8.165 gate and 6/32 after on this Linux machine, 3/32 on CI
    # Linux, Julia 1.13.4), so only its existence is asserted; the sign claim above is the portable one.
    @test count(>(0.0), rep_diffs) >= 1
    @test proportion_interval(count(>=(0.0), rep_diffs), length(p46_seeds)).lo > 0.8
    @test any(tr -> tr.accolades_suppressed > 0, on_both)
    @test proportion_interval(count(((o, b),) -> b.accolades_suppressed > 0 || b.accolade_credit <= o.accolade_credit + 1e-9,
                                    zip(off, on_both)), length(p46_seeds)).lo > 0.7

    # Dynamic p.forks (`fork_family` pooling in M3c credits_for): forked family completes safely under `:split`
    # and pooling bound identities neutralizes multi-identity harm splitting (`+0.267 -> 0.0`) on convex `V`.
    p_fk = M3cParams(ToyParams(n = 40, steps = 60, plans = 6), agents, [1, 1, 2, 2], trues(4);
                     λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                     p_upstream = 0.5, forks = [(10, 1, 7, 0.5)], fork_rule = :split)
    tr_fk = run_m3c(p_fk; seed = 2)
    @test all(isfinite, tr_fk.balance) && (tr_fk.upstream_pos[7] + tr_fk.upstream_neg[7] >= 0.0 || sum(tr_fk.balance[7, :]) != 0.0)
    V_nl(x) = sign(x) * abs(x)^1.5
    v_harm(mask) = V_nl(((mask & 1 != 0) ? -1.0 : 0.0) + ((mask & 2 != 0) ? 1.5 : 0.0) + ((mask & 4 != 0) ? -1.0 : 0.0))
    raw = shapley_shares(v_harm, 3; rng = Xoshiro(1))
    pooled = bound_shapley_shares(v_harm, [1, 2, 1]; rng = Xoshiro(1))
    honest = shapley_shares(m -> V_nl(((m & 1 != 0) ? -2.0 : 0.0) + ((m & 2 != 0) ? 1.5 : 0.0)), 2; rng = Xoshiro(1))
    @test (raw[1] + raw[3]) > honest[1] + 0.25
    @test pooled[1] + pooled[3] ≈ honest[1] && pooled[2] ≈ honest[2]
end


# ==============================================================================
# Probe: understanding as its equation, with models taught whole (8.98, ruling 8.109)
# ==============================================================================
# Hypotheses (6 seeds, paired): (a) no crossed wires: every model a being holds at the end is a bundle
# (base spread with complexity) that existed, never one model's accuracy with another's simplicity
# (structural); (b) teaching raises floor growth of understanding (z = 3); (c) teachable breakthroughs
# spread lower complexity (mean complexity lower than when every breakthrough stays tacit, z = 3);
# (d) practice alone (no teaching) raises median understanding (z = 3). Measured (8 seeds): floor growth
# +0.59 with teaching; complexity −0.044; practice +0.024.
@timed_testset "Probe: understanding as its equation, models taught whole (8.109)" begin
    seeds = 1:6
    fg(t) = t.floor_u[end] - t.floor_u[1]
    base = [run_m7_traits(seed = s) for s in seeds]
    @test all(t -> all(x -> x in t.bundles, t.final_bundles), base)
    @test paired_effect(fg.(base) .- fg.([run_m7_traits(seed = s, ε = 0.0) for s in seeds]); z = 3.0).significant
    tacit = [run_m7_traits(seed = s, p_teachable = 0.0) for s in seeds]
    @test paired_effect([a.mean_cy[end] - b.mean_cy[end] for (a, b) in zip(base, tacit)]; z = 3.0, direction = :down).significant
    pr = [run_m7_traits(seed = s, ε = 0.0) for s in seeds]; nopr = [run_m7_traits(seed = s, ε = 0.0, practice_gain = 0.0) for s in seeds]
    @test paired_effect([a.median_u[end] - b.median_u[end] for (a, b) in zip(pr, nopr)]; z = 3.0).significant
    # (e) Measured view and learners' reports in this world: a third overclaiming explanation by 0.4 cut
    # floor growth (measured 0.62 → 0.47); reports audit every overclaimer, no honest one (measured: 20
    # of 20, none false, every seed), and recover the loss (0.615).
    oc = [b % 3 == 0 ? 0.4 : 0.0 for b in 1:60]
    open_ = [run_m7_traits(seed = s, overclaim = oc) for s in seeds]
    rep = [run_m7_traits(seed = s, overclaim = oc, reports = true) for s in seeds]
    @test paired_effect(fg.(base) .- fg.(open_); z = 3.0).significant
    @test paired_effect(fg.(rep) .- fg.(open_); z = 3.0).significant
    @test all(t -> all(b -> t.audited[b] == (oc[b] > 0), 1:60), rep)
end

probe_total("heavy 1")
