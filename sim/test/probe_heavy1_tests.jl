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

    hon_n = [run_m3c(ext_world(credence_rule = :normal, p_extremist = 0.0); seed) for seed in 1:8]
    hon_eb = [run_m3c(ext_world(credence_rule = :eb, p_extremist = 0.0); seed) for seed in 1:8]
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
    blind = [early(run_m5(M5Params(m3, 1:4; decisions = 250, signal_σ = 20.0, deliberation = true, source_tags = true, tag_liars = liars, D..., C...); seed)) for seed in 2:49]
    informed = [early(run_m5(M5Params(m3, 1:4; decisions = 250, signal_σ = 20.0, deliberation = true, source_tags = true, tag_liars = liars, D..., C...); seed, records = first.records)) for seed in 2:49]
    honest_w = mean(source_weight(first.records[i, k][1], first.records[i, k][2]) for k in 1:4 for i in (12 * (k - 1) + 1):(12 * k) if !(i in liars))
    liar_w = mean(source_weight(first.records[i, k][1], first.records[i, k][2]) for k in 1:4 for i in (12 * (k - 1) + 1):(12 * k) if i in liars)
    @test honest_w > liar_w
    @test informed != blind
    @test_broken paired_effect(informed .- blind; direction = :up).significant   # NOT DETECTED (8.81): +0.0012 ± 0.0049 over N = 48 seeds; signal_σ = 20.0, stealth = true, λpos = 0.05 > λneg = 0.02 leave top stealth liars positive and blind catches up within 150 decisions
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

# The composed IH world (P53; fast smoke in probe_tests.jl): the significance, equivalence and Goal-pattern claims over many seeds.
# Predictions stated before measuring (lead: effect detected, confidence 0.5): in the regime where lies bite (noisy voters, 8.63's
# limiting case) IH raises decision accuracy by at least 0.05 at z = 3; in the default regime (accurate voters) accuracy sits at a
# ceiling and is not lowered by more than 0.05 (one-sided); weighted payoff and the economy's floor of understanding lose less than 3.
@timed_testset "Probe: composed IH world, accuracy gain where lies bite, no loss at the ceiling, Goal pattern guards (P53 heavy)" begin
    econ = M3cParams(ToyParams(n = 30, steps = 25, plans = 6),
                     [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 11 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                      for k in 1:4 for r in 1:12], [1, 1, 2, 2], trues(4);
                     λpos = 0.05, λneg = 0.02, transactions = true, p_hazard = 0.2, hazard_size = 2.0,
                     guardians = [1, 13, 25, 37], diligence = fill(0.9, 48))
    m3 = run_m3c(econ; seed = 1)
    world(ih, seed; kw...) = run_ih_world(IhWorldParams(; m3, econ, ih, seed, steps = 12, kw...))
    seeds = 1:16
    arms = [(world(true, s; signal_σ = 20.0), world(false, s; signal_σ = 20.0)) for s in seeds]
    acc = [a.accuracy - b.accuracy for (a, b) in arms]
    @info "P53 accuracy gain, noisy voters" n = length(acc) gain = (mean(acc), std(acc) / sqrt(length(acc)))
    @test paired_effect(acc; z = 3.0, direction = :up).significant && mean(acc) >= 0.05
    dflt = [world(true, s).accuracy - world(false, s).accuracy for s in seeds]
    @info "P53 accuracy difference, default voters" mean = mean(dflt) se = std(dflt) / sqrt(length(dflt))
    @test equivalent(-dflt; margin = 0.05, side = :upper).equivalent
    @test equivalent(-[a.payoff - b.payoff for (a, b) in arms]; margin = 3.0, side = :upper).equivalent
    @test equivalent(-[a.pattern.floor_u - b.pattern.floor_u for (a, b) in arms]; margin = 3.0, side = :upper).equivalent
    # harm's peak (deepest single-being drop; a loss is a larger drop): one-sided, same margin
    wd = [a.pattern.worst_drop - b.pattern.worst_drop for (a, b) in arms]
    @info "P53 worst_drop difference (on - off)" mean = mean(wd) se = std(wd) / sqrt(length(wd))
    @test equivalent(wd; margin = 3.0, side = :upper).equivalent
end

# Ideological extremists on the IH world (P54; fast smoke in probe_tests.jl). Regimes and predictions stated before measuring (lead:
# spread reduced with IH, confidence 0.6; Goal effect may be small). Regimes: (a) default voters (signal_sigma 2), (b) noisy voters
# (signal_sigma 20, 8.63's limiting case); extremist share 0.25, reframe chance 0.5. Claims, direction, metric, smallest effect that matters:
# (1) IH lowers the extremists' influence (truth level x their weighted share of the consensus), at least 0.05, z = 2, both regimes;
# (2) IH lowers the minds swayed (control less IH), at least 0.02, z = 2, both regimes (confidence 0.5: the liar bloc already sways);
# (3) the wrong-side weight on unprovable claims falls with IH, at least 0.05, z = 2; (4) Goal pattern (floor of understanding, harm's
# peak) one-sided loss of IH vs control below 3 (equivalence); structural: unprovable influence under IH within the cap in every seed.
# Seeds by precision (seeds_until_stable, tol 0.01, 4 to 16 seeds), count reported. All results are reported whichever way they fall.
@timed_testset "Probe: extremists on the IH world, spread and influence bounded, Goal pattern guards (P54 heavy)" begin
    econ = M3cParams(ToyParams(n = 30, steps = 25, plans = 6),
                     [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 11 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                      for k in 1:4 for r in 1:12], [1, 1, 2, 2], trues(4);
                     λpos = 0.05, λneg = 0.02, transactions = true, p_hazard = 0.2, hazard_size = 2.0,
                     guardians = [1, 13, 25, 37], diligence = fill(0.9, 48))
    m3 = run_m3c(econ; seed = 1)
    world(ih, seed; kw...) = run_ih_world(IhWorldParams(; m3, econ, ih, seed, steps = 12, extremist_frac = 0.25, kw...))
    for (name, kw) in (("default voters", (;)), ("noisy voters", (signal_σ = 20.0,)))
        cache = Dict{Int,Any}()
        arms(s) = get!(cache, s) do; (world(false, s; kw...), world(true, s; kw...)); end
        r = seeds_until_stable(s -> (a = arms(s); a[1].ext_influence - a[2].ext_influence); tol = 0.01, min_seeds = 4, max_seeds = 16)
        S = r.seeds; A = [arms(s) for s in S]
        @info "P54 extremist influence, control less IH ($name)" n = r.n stable = r.stable effect = (r.mean, r.se)
        @test paired_effect(r.values; z = 2.0, direction = :up).significant && r.mean >= 0.05
        sw = [a[1].swayed - a[2].swayed for a in A]
        @info "P54 minds swayed, control less IH ($name)" n = length(sw) effect = (mean(sw), std(sw) / sqrt(length(sw)))
        @test paired_effect(sw; z = 2.0, direction = :up).significant && mean(sw) >= 0.02
        wr = [a[1].wrong_unprovable_weight - a[2].wrong_unprovable_weight for a in A]
        @info "P54 wrong-side weight on unprovable claims, control less IH ($name)" n = length(wr) effect = (mean(wr), std(wr) / sqrt(length(wr)))
        @test paired_effect(wr; z = 2.0, direction = :up).significant && mean(wr) >= 0.05
        @test all(a[2].ext_influence_unprovable_peak <= 0.99 * 0.35 + 1e-12 for a in A)    # structural, every seed
        # the Goal pattern is noisy (harm's peak especially): its seeds are added until its own precision is reached (tol 1.0, up to 16)
        rg = seeds_until_stable(s -> (a = arms(s); a[2].pattern.worst_drop - a[1].pattern.worst_drop); tol = 1.0, min_seeds = 4, max_seeds = 16)
        G = [arms(s) for s in rg.seeds]
        @info "P54 Goal pattern ($name)" n = rg.n stable = rg.stable floor_u = mean(a[2].pattern.floor_u - a[1].pattern.floor_u for a in G) worst_drop = (rg.mean, rg.se)
        @test all(a[2].ext_influence_unprovable_peak <= 0.99 * 0.35 + 1e-12 for a in G)
        @test equivalent(-[a[2].pattern.floor_u - a[1].pattern.floor_u for a in G]; margin = 3.0, side = :upper).equivalent
        @test equivalent(rg.values; margin = 3.0, side = :upper).equivalent
    end
end

# P-BB heavy: the birth baseline's shortfall effect at z = 2 with seeds added by precision, and the Goal pattern's
# one-sided loss below 3 (8.167b; fast version `Probe: birth baseline income ...` in probe_tests.jl).
@timed_testset "Probe: birth baseline income, shortfall effect and Goal pattern (heavy: 8.167b)" begin
    p = ToyParams(n = 30, steps = 60, plans = 6)
    kw = (; p_birth = 0.25, window = 10, income = 1.0)
    runs = Dict{Int,Any}()
    both(s) = get!(runs, s) do; (run_population_world(p; seed = s, kw..., birth_baseline = false), run_population_world(p; seed = s, kw..., birth_baseline = true)); end
    ps(r) = mean(r.grad_short[r.grad_poor])
    eff = seeds_until_stable(s -> ps(both(s)[1]) - ps(both(s)[2]); tol = 0.15, min_seeds = 6, max_seeds = 16)
    @info "P-BB heavy: seeds used" n = eff.n stable = eff.stable effect = (eff.mean, eff.se)
    @test paired_effect(eff.values; z = 2.0, direction = :up).significant
    @test eff.mean > 0.5
    P = [(success_pattern(both(s)[1]), success_pattern(both(s)[2])) for s in eff.seeds]
    for k in (:floor_u, :floor_h, :median_u, :median_h)
        @test equivalent([getfield(o, k) - getfield(n, k) for (o, n) in P]; margin = 3.0, side = :upper).equivalent   # loss (off - on) below 3, one-sided
    end
    @test equivalent([n.worst_drop - o.worst_drop for (o, n) in P]; margin = 3.0, side = :upper).equivalent
end

# The unified world, phase A (P56 heavy; fast version in probe_tests.jl). Predictions (lead, before measuring): clusters recover the planted
# communities in at least 80% of seeds at the last epoch (0.7); the lie's reach follows the one network (z = 2, paired); the Goal pattern's
# one-sided loss of the unified world against the coupled world alone is below 3 (0.6; the unified economy takes its hazard inputs from the
# claims on the network, a deliberate difference, not tuned to rescue). Seed counts follow precision (`seeds_until_stable`).
@timed_testset "Probe: unified world, clusters recover planted communities, the lie follows the network, Goal pattern guard (P56 heavy)" begin
    agents = [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 11 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:12]
    econ = M3cParams(ToyParams(n = 30, steps = 75, plans = 6), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                     transactions = true, causal_distribution = true, init_steps = 10, guardians = [1, 13, 25, 37], diligence = fill(0.9, 48))
    gov(tr) = M5Params(tr, 1:4; decisions = 1, deliberation = true, info_handling = true, source_tags = true, ih_vote = true, p_delegate = 0.2)
    m3 = run_m3c(econ; seed = 1)
    function reach(seed)
        net = build_trust_network(48; seed); liars = [i for i in 1:48 if net.planted[i] == 1][1:8]; h = filter(i -> !(i in liars), 1:48)
        kw = (; m3, econ, ih = false, seed, steps = 8, liars_override = liars, run_economy = false, signal_σ = 6.0, claims_per_step = 10)
        lc = [count(in(liars), net.contacts[i]) for i in h]
        cor(lc, run_ih_world(IhWorldParams(; kw..., network = net, rounds = 2)).voter_led_astray[h]) - cor(lc, run_ih_world(IhWorldParams(; kw...)).voter_led_astray[h])
    end
    r = seeds_until_stable(reach; tol = 0.06, min_seeds = 12, max_seeds = 24)
    @info "P56 lie reach, unified minus separate (corr)" n = r.n stable = r.stable mean = r.mean se = r.se
    @test paired_effect(r.values; direction = :up).significant
    runs = Dict{Int,Any}()
    both(seed) = get!(runs, seed) do
        (run_coupled(econ, gov; seed, epoch = 25, coupled = false, m5_decisions = 30),
         run_coupled(econ, gov; seed, epoch = 25, coupled = false, m5_decisions = 30, unified = UnifiedParams(liar_community = 1)))
    end
    g = seeds_until_stable(seed -> (o = both(seed); (o[2].success.floor_u + o[2].success.floor_h) - (o[1].success.floor_u + o[1].success.floor_h)); tol = 1.0, min_seeds = 16, max_seeds = 32)
    @info "P56 Goal pattern difference (unified - coupled alone)" n = g.n stable = g.stable mean = g.mean se = g.se
    @test equivalent(-g.values; margin = 3.0, side = :upper).equivalent
    rec = [both(s)[2].unified.epochs[end].agreement > 0.6 for s in g.seeds]
    pi = proportion_interval(count(rec), length(rec))
    @info "P56 cluster recovery at the last epoch" n = length(rec) k = count(rec) interval = (pi.lo, pi.hi)
    @test pi.lo > 0.6
end

probe_total("heavy 1")
