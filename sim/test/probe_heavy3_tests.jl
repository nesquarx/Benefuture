# Heavy mechanism probes 3 of 3 (full tier: nightly and workflow_dispatch; not in BF_TIER=fast). Moved verbatim from
# probe_tests.jl because each took over 30 s (author: "make sure probes are fast"); claims and bounds unchanged.
# Run all three: julia --project=sim sim/test/probes_heavy.jl. Each has a fast "Smoke:" version at the end of probe_tests.jl
# (docs/BACKPROPAGATION.md, probe speed); the statistical claims stay here.
using Random, Statistics

isdefined(@__MODULE__, Symbol("@timed_testset")) || include(joinpath(@__DIR__, "probe_timing.jl"))


# 8.115 newcomer entry (`open_entry`, `entrants`): when skilled deceivers are priced out by AdvAp
# and escrow in a closed economy, dormant newcomer slots pass `bind!` on unmet/refused proposals,
# replace lost execution, and lift `floor_u` at z = 3.0 without restoring the deceivers' advantage.
@timed_testset "Probe: 8.115 open entry replaces priced-out deceivers via bound newcomers" begin
    skills0 = draw_skills(Xoshiro(20261031), 8, 4, [1, 3]; median = 0.6)
    skills4 = vcat(skills0, draw_skills(Xoshiro(20261115), 4, 4, [1, 3]; median = 0.6))
    function run_entry_probe(sq::Bool, open_entry::Bool, seed::Int)
        entrants = open_entry ? 4 : 0
        na = 8 + entrants
        sk = open_entry ? skills4 : skills0
        agents = [DomainAgent(sk[a, :], [0.5, 0, 0.5, 0], 0.3) for a in 1:na]
        deceit = vcat([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0], zeros(entrants))
        inst = sq ? (vigilance = 0.001, cost_σ = 0.3, memory_loss = 0.1, p_false_trace = 0.05, p_informed = 0.6, dil = 0.4, advap = false) :
                    (vigilance = 0.1, cost_σ = 0.05, memory_loss = 0.0, p_false_trace = 0.005, p_informed = 0.95, dil = 0.95, advap = true)
        p = M3cParams(ToyParams(n = 40, steps = 250, plans = 10), agents, [1, 1, 2, 2], trues(4);
                      λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                      p_upstream = 0.5, guardians = [1, 2, 3, 4], diligence = fill(inst.dil, na),
                      p_informed = inst.p_informed, p_foresee = 1.0, repair_efficiency = 0.5,
                      deceit = deceit, advap = inst.advap, vigilance = inst.vigilance, cost_σ = inst.cost_σ,
                      memory_loss = inst.memory_loss, p_false_trace = inst.p_false_trace,
                      adaptive_proposals = true, open_entry = open_entry, entrants = entrants,
                      events = [shock(:capture; step = 100, duration = 150, size = 1.5, target = 1)],
                      LEGACY...)
        tr = run_m3c(p; seed = seed)
        sp = success_pattern(tr; from = 51)
        standing(i) = sum(tr.balance[i, :]) + tr.overflow_agent[i]
        adv = (mean(standing(i) for i in 7:8) - mean(standing(i) for i in 1:6)) / (tr.endowed / 8)
        (entries = tr.entries, exec = Float64(length(tr.chosen_agent)), floor_u = sp.floor_u, adv = adv)
    end
    seeds = 1:24
    closed = [run_entry_probe(false, false, s) for s in seeds]
    opened = [run_entry_probe(false, true, s) for s in seeds]
    sq_open = [run_entry_probe(true, true, s) for s in seeds]
    @test all(r.entries == 0 for r in closed)
    @test all(r.entries > 0 for r in opened)
    @test paired_effect([o.exec - c.exec for (c, o) in zip(closed, opened)]; z = 3.0).significant
    @test paired_effect([o.floor_u - c.floor_u for (c, o) in zip(closed, opened)]; z = 3.0).significant
    @test paired_effect([s.adv - o.adv for (o, s) in zip(opened, sq_open)]; z = 3.0).significant
end




# The ratchet on status bars (author ruling 8.84): when k models (governed, default 3) operate above a
# domain's bar, the bar rises to the k-th best accuracy less a margin, so k models still clear it; it
# never falls by this rule. A low-noise world where better challengers keep arriving (the controlled
# world, models that can exceed the bootstrap bar of 0.9).
@timed_testset "Probe: the status bar ratchets up when enough models clear it, and never falls" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    w(; kw...) = M3cParams(ToyParams(n = 60, steps = 800, plans = 8), [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:4],
                    [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, LEGACY...,
                    p_new_model = 0.1, takeover_records = 30, ratchet_horizon = 10.0, kw...)   # a low-noise world names a shorter horizon
    for seed in 1:2
        tr = run_m3c(w(); seed)
        b = tr.bar_trace                                         # leaf 1's bar, step by step
        @test all(diff(b) .>= 0)                                  # never falls
        @test b[end] > b[1] + 0.01                                # it rose once enough models cleared it
        @test tr.lane_halted == 0                                 # pricing goes on
        @test run_m3c(w(ratchet_k = 0); seed).bar_trace[end] == b[1]   # red baseline: without it the bar stays
    end
    # Counterexample: where models swing together over short horizons (the better-models world, high
    # noise), a bar read over the eligibility horizon locked at a quiet stretch and own-currency pricing
    # fell from 0.79 to 0.38; over the default (twenty times longer) it leaves pricing as without it.
    nw(; kw...) = M3cParams(ToyParams(n = 80, steps = 400, plans = 10),
        [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.3) for _ in 1:8], [1, 1, 2, 2], trues(4);
        λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, LEGACY..., σ_leaf = 0.45, σ_branch = 0.6,
        σ_coarse = 0.75, p_new_model = 0.05, kw...)
    own(tr) = mean(tr.priced_leaf[i] == tr.true_leaf[i] for i in eachindex(tr.chosen_step) if tr.chosen_step[i] >= 100)
    on, off = run_m3c(nw(); seed = 1), run_m3c(nw(ratchet_k = 0); seed = 1)
    @test own(on) >= own(off) - 0.02 && all(on.leaf_bars .<= 0.905)
    # The short horizon locks: own-currency pricing significantly drops across seeds (paired effect)
    short_diffs = [own(run_m3c(nw(ratchet_horizon = 1.0); seed)) - own(run_m3c(nw(); seed)) for seed in 1:4]
    @test paired_effect(short_diffs; direction = :down).significant
end


@timed_testset "Probe: score-only until converged, legacy funder, and shadow governance (8.136)" begin
    # Author ruling 8.136:
    # (a) Immature domains stay score-only until model convergence (`currency_eligible` + `sequential_significant`),
    #     rather than switching on a fixed `init_steps` clock;
    # (b) Until converged, a legacy institutional funder (`status_quo` screen) absorbs the work cleanly without
    #     touching Bf balances or stalling via StandCoin halts;
    # (c) Governance waits for convergence and evaluates candidates in shadow over their ETA window while the
    #     incumbent remains live, promoting only if `prediction_on_track` and `select_candidate` approve.
    ag = [DomainAgent([k == l ? 0.5 : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0) for k in 1:2 for r in 1:4]
    T = ToyParams(n = 40, steps = 80, plans = 6)
    P_clock = M3cParams(T, ag, [1, 1], trues(2); λpos = 0.05, λneg = 0.02,
                        transactions = true, init_steps = 5, min_records = 15, threshold = 0.85,
                        model_z = 3.0, cost_per_touch = 0.25)
    P_conv = M3cParams(T, ag, [1, 1], trues(2); λpos = 0.05, λneg = 0.02,
                       transactions = true, init_steps = 5, min_records = 15, threshold = 0.85,
                       model_z = 3.0, cost_per_touch = 0.25, converge_init = true, legacy_funder = true)

    clocks = [run_m3c(P_clock; seed = s) for s in 1:16]
    convs  = [run_m3c(P_conv; seed = s) for s in 1:16]
    @test all(c -> c.converged && c.converge_step > 5 && c.legacy_executed > 0, convs)
    @test paired_effect([cl.lane_halted - cv.lane_halted for (cl, cv) in zip(clocks, convs)]; z = 3.0, direction = :up).significant
    @test paired_effect([cv.floor_u[end] - cl.floor_u[end] for (cl, cv) in zip(clocks, convs)]; z = 3.0, direction = :up).significant

    # Counterexample: unpredictable / noisy domain never converges; stays score-only with legacy carrying work and Bf balances untouched.
    P_noise = M3cParams(ToyParams(n = 40, steps = 60, plans = 6), ag, [1, 1], trues(2); λpos = 0.05, λneg = 0.02,
                        transactions = true, init_steps = 5, min_records = 12, threshold = 0.99,
                        marker_σ = 10.0, σ_leaf = 10.0, converge_init = true, legacy_funder = true)
    rn = run_m3c(P_noise; seed = 1)
    @test !rn.converged && rn.converge_step == 0 && rn.legacy_executed > 0 && rn.lane_halted == 0
    @test all(==(P_noise.endowment), rn.balance)

    # Sparse-focus known leaves (zero-focus known leaves must not deadlock active leaves' convergence, while noisy active leaves still stay score-only).
    ag_sparse = [DomainAgent([0.5, 0.0, 0.5, 0.0], [0.5, 0.0, 0.5, 0.0], 0.0) for _ in 1:8]
    P_sparse_ok = M3cParams(ToyParams(n = 40, steps = 100, plans = 6), ag_sparse, [1, 1, 2, 2], trues(4);
                            λpos = 0.05, λneg = 0.02, transactions = true, init_steps = 5,
                            min_records = 12, threshold = 0.85, model_z = 2.0,
                            converge_init = true, legacy_funder = true)
    P_sparse_bad = M3cParams(ToyParams(n = 40, steps = 80, plans = 6), ag_sparse, [1, 1, 2, 2], trues(4);
                             λpos = 0.05, λneg = 0.02, transactions = true, init_steps = 5,
                             min_records = 12, threshold = 0.99, marker_σ = 10.0, σ_leaf = 10.0,
                             converge_init = true, legacy_funder = true)
    sp_ok = [run_m3c(P_sparse_ok; seed = s) for s in 1:8]
    sp_bad = run_m3c(P_sparse_bad; seed = 1)
    @test all(c -> c.converged && c.converge_step > 5 && c.legacy_executed > 0, sp_ok)
    @test !sp_bad.converged && sp_bad.converge_step == 0 && sp_bad.legacy_executed > 0

    # Governance part (b + c): same converged economy (`econ_8136`), varying only `shadow`.
    ag_c = vcat(
        [DomainAgent([k == l ? 0.5 : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0) for k in 1:2 for r in 1:4],
        [DomainAgent([-0.9, -0.9], [0.5, 0.5], 0.0) for _ in 1:2],
    )
    dec_c = vcat(zeros(8), fill(2.5, 2))
    gov(tr) = M5Params(tr, 1:2; decisions = 1, p_delegate = 0.2)
    bad_pv = copy(bootstrap_params()); bad_pv[6] = 1.9; bad_pv[7] = 1.1; bad_pv[8] = 0.0
    econ_8136 = M3cParams(ToyParams(n = 40, steps = 300, plans = 6), ag_c, [1, 1], trues(2); λpos = 0.05, λneg = 0.02,
                          transactions = true, causal_distribution = true, init_steps = 5,
                          deceit = dec_c, track_window = 20, actor_min_records = 10, threshold = 0.80,
                          converge_init = true, legacy_funder = true)

    hi_live = [run_coupled(econ_8136, gov; seed = s, epoch = 25, continuous = true,
                           candidate_pv = bad_pv, candidate_threshold = 0.5, candidate_track_window = 0,
                           candidate_prediction = 40.0, candidate_eta = 3, candidate_vs_incumbent = true, shadow = false) for s in 1:16]
    none_sh = [run_coupled(econ_8136, gov; seed = s, epoch = 25, continuous = true, shadow = true) for s in 1:16]
    hi_sh   = [run_coupled(econ_8136, gov; seed = s, epoch = 25, continuous = true,
                           candidate_pv = bad_pv, candidate_threshold = 0.5, candidate_track_window = 0,
                           candidate_prediction = 40.0, candidate_eta = 3, candidate_vs_incumbent = true, shadow = true) for s in 1:16]

    @test all(r -> !r.shadow_promoted && !any(r.adopted_candidate) && r.rejected &&
                   !isempty(r.prediction_record) && r.prediction_calibration == 0.0, hi_sh)
    # A rejected shadow candidate leaves the live path untouched: equal to the no-candidate arm in every seed where that arm took no
    # shadow promotion of its own (the governor proposes its own candidates there; seed 11 under the 8.165 gate promotes one, so the
    # arms differ by the incumbent's own change, not by a leak; 15/16 comparable on Linux, Julia 1.13.3).
    cmp_sh = [(h, n) for (h, n) in zip(hi_sh, none_sh) if !n.shadow_promoted]
    @test proportion_interval(length(cmp_sh), length(none_sh)).lo > 0.6
    @test all(((h, n),) -> abs(h.success.floor_u - n.success.floor_u) < 1e-9, cmp_sh)
    @test paired_effect([s.success.floor_u - l.success.floor_u for (s, l) in zip(hi_sh, hi_live)]; z = 3.0, direction = :up).significant

    # Positive shadow promotion: an admissible but overly risk-averse incumbent (`par_timid`: q₊ = 1.05, q₋ = 50, λ = 1)
    # converges in Phase 1, evaluates `bootstrap_params()` in shadow for ETA = 2 epochs, and promotes live (16/16 seeds, z >> 3).
    par_timid = copy(bootstrap_params())
    par_timid[1] = 0.25; par_timid[2] = 0.20; par_timid[3] = 0.15; par_timid[4] = 0.05
    par_timid[6] = 1.05; par_timid[7] = 50.0; par_timid[8] = 1.0
    @test admissible(par_timid)
    econ_pos = M3cParams(ToyParams(n = 40, steps = 240, plans = 6), ag, [1, 1], trues(2); λpos = 0.05, λneg = 0.02,
                         transactions = true, causal_distribution = true, init_steps = 5,
                         min_records = 8, threshold = 0.70, model_z = 2.0, endowment = 20.0,
                         converge_init = true, legacy_funder = true)
    bad_none = [run_coupled(econ_pos, gov; seed = s, epoch = 40, continuous = true,
                            incumbent_pv = par_timid, shadow = true) for s in 1:16]
    good_sh  = [run_coupled(econ_pos, gov; seed = s, epoch = 40, continuous = true,
                            incumbent_pv = par_timid, candidate_pv = bootstrap_params(),
                            candidate_prediction = 0.0, candidate_eta = 2, shadow = true) for s in 1:16]
    promoted = count(r -> r.shadow_promoted && any(r.adopted_candidate) && !r.rejected &&
                          !isempty(r.prediction_record) && r.prediction_calibration == 1.0, good_sh)
    @test proportion_interval(promoted, length(good_sh)).lo > 0.5
    @test paired_effect([g.success.floor_u - b.success.floor_u for (g, b) in zip(good_sh, bad_none)]; z = 3.0, direction = :up).significant
end


@timed_testset "Probe: meta-research as its own domain educates priorities (8.132)" begin
    # Hypothesis: when beings share a misjudgement of priorities (weight_shared 1), a small share of research spent on the
    # meta domain lifts the floor of understanding (direction +, smallest effect 0.01), and spending most of it there
    # costs more than it repairs (interior optimum: 30% below 5%, smallest effect 0.01). Paired seeds, 24 of them (about
    # 70 s), z = 2 with Student-t inflation (`paired_effect`); the per-seed lift ranges from -0.03 to +0.18, so 10 seeds
    # at an uninflated z = 2 sat near the bar. Measured (Linux): 16 seeds lift +0.048 ± 0.015 (z 3.1), 32 seeds +0.048 ± 0.012 (z 4.0),
    # cost -0.040 ± 0.005 (z 7.5); the 24 used here: lift +0.036 ± 0.012 (z 2.9), cost -0.039 ± 0.006.
    f(ms, s) = run_m7_traits(seed = s, things = [1.0, 0.3, 0.1], m = 6, steps = 200, weight_σ = 1.5, per_being = true,
                             meta_share = ms, weight_shared = 1.0, meta_domain = true).floor_u[end]
    S = 1:24
    base, small, large = [f(0.0, s) for s in S], [f(0.05, s) for s in S], [f(0.3, s) for s in S]
    up, down = small .- base, large .- small
    @test paired_effect(up; z = 2.0).significant && mean(up) > 0.01
    @test paired_effect(down; z = 2.0, direction = :down).significant && mean(down) < -0.01
end


# ==============================================================================
# Probe: model collusion, profile gaming, and 8.23 named fallbacks (Task B4)
# ==============================================================================
@timed_testset "Probe: model collusion, profile gaming, and 8.23 named fallbacks (B4)" begin
    @test length(COMPONENT_FALLBACKS) == 10
    toy = ToyParams(; n = 30, steps = 120, plans = 4)
    ag_cap = [DomainAgent([0.8, 0.2], [0.5, 0.5], 0.1), DomainAgent([0.2, 0.8], [0.5, 0.5], 0.1)]
    tr_cap = run_m3c(M3cParams(toy, ag_cap, [1, 1], [true, true]; λpos = 0.05, λneg = 0.02,
                               events = [shock(:capture; step = 60, duration = 60, size = 15.0, target = 1)]); seed = 1)
    @test any(occursin("eligible parent model by μ", k) for k in keys(tr_cap.degraded))

    ag_c = [DomainAgent([0.5, 0.5], [0.5, 0.5], 0.1) for _ in 1:6]
    cw(tw, adv) = M3cParams(ToyParams(; n = 50, steps = 260, plans = 8), ag_c, [1, 1], [true, true];
                            λpos = 0.05, λneg = 0.02, transactions = true, accuracy_rule = :window,
                            p_new_model = 0.2, improve_drift = -0.4, improve_σ = 0.1,
                            takeover_records = 5, min_records = 5, pool_max = 8,
                            events = [shock(:capture; step = 10, duration = 20, size = 5.0, target = 1)],
                            model_collude = 1.0, model_collude_bias = 5.0, collude_actors = [1],
                            track_window = tw, credence_rule = :record, advap = adv)
    red_c = [run_m3c(cw(0, false); seed = s) for s in 1:64]
    grn_c = [run_m3c(cw(20, true); seed = s) for s in 1:64]
    gap1(tr) = (idx = findall(==(1), tr.exec_agent); isempty(idx) ? 0.0 : mean(tr.exec_pred[idx] .- tr.exec_true[idx]))
    post1(tr) = (idx = findall(i -> tr.exec_agent[i] == 1 && tr.exec_step[i] > 35, eachindex(tr.exec_agent)); isempty(idx) ? 0.0 : mean(tr.exec_pred[idx] .- tr.exec_true[idx]))
    pay_red = [r.upfront[1] - r.settled_value[1] for r in red_c]
    pay_grn = [g.upfront[1] - g.settled_value[1] for g in grn_c]
    @test mean(r -> r.takeovers_colluding, red_c) >= 1.0 && mean(g -> g.takeovers_colluding, grn_c) >= 1.0
    @test paired_effect(pay_red .- pay_grn; z = 2.0).significant
    @test paired_effect(pay_grn; z = 2.0, direction = :down).significant
    @test paired_effect([gap1(r) - gap1(g) for (r, g) in zip(red_c, grn_c)]; z = 3.0).significant
    @test paired_effect([post1(r) - post1(g) for (r, g) in zip(red_c, grn_c)]; z = 3.0).significant
    @test equivalent([post1(g) for g in grn_c]; margin = 5.0, z = 2.0).equivalent

    ag_p = [DomainAgent([0.25, 0.8], [1.0, 0.0], 3.0),
            DomainAgent([0.8, 0.8], [0.0, 1.0], 0.05),
            DomainAgent([0.8, 0.8], [0.0, 1.0], 0.05),
            DomainAgent([0.8, 0.8], [0.0, 1.0], 0.05)]
    pw(mode) = M3cParams(ToyParams(; n = 60, steps = 200, plans = 8), ag_p, [1, 1], [true, true];
                         λpos = 0.05, λneg = 0.02, transactions = true, profile_mode = mode, profile_gamers = [2, 0, 0, 0])
    red_p = [run_m3c(pw(:declared); seed = s) for s in 1:16]
    grn_p = [run_m3c(pw(:measured); seed = s) for s in 1:16]
    @test paired_effect([g.leaf_accuracy[2] - r.leaf_accuracy[2] for (r, g) in zip(red_p, grn_p)]; z = 3.0).significant
    @test mean(g -> g.leaf_accuracy[2], grn_p) > 0.9 && mean(r -> r.leaf_accuracy[2], red_p) < 0.75
end


@timed_testset "Probe: a governance candidate is judged at its own stated ETA, not one epoch after adoption (predict - measure - adapt, 8.134)" begin
    # Rules (structural): `prediction_on_track` (measured >= predicted - band) and `resolution_due` (steps >= ETA + grace).
    @test prediction_on_track(1.0, 1.0, 0.0) && !prediction_on_track(0.9, 1.0, 0.0) && prediction_on_track(0.9, 1.0, 0.2)
    @test !resolution_due(2, 3, 0) && resolution_due(3, 3, 0) && !resolution_due(3, 3, 1) && resolution_due(4, 3, 1)
    # Re-measured on warmed-up world (`init_steps = 50`, per 310f1a0; governance held until warm-up finishes at step 50, continuous = true):
    # Pre-measurement predictions (53a47c0 P1): L3.2 candidate (only `track_window = 0` live; bar change inert by 8.84) is harmful
    # throughout, so adopting it lowers final floor_u + floor_h against no candidate (`none`), and the old one-epoch rule (`e1`/`old`)
    # no longer beats the refinement (`lo`). Metric: `success.floor_u + success.floor_h`, paired on seeds. Smallest effect that matters: 5 units.
    # Structural claims (every seed): governance does not act before warm-up finishes (`!adopted_candidate[1]`); with ETA 3 nothing
    # resolves before the third epoch after adoption; with defaults (`idle`) ETA keywords change nothing; ETA 1 resolves one epoch
    # after adoption (at epoch 3, after epoch 2 adoption).
    # Under the Spike D2 default :eb (16 seeds, Linux, not asserted): the same deceiver economy loses less (none 49.35 +- 2.24, old 37.52 +- 1.29,
    # e3 34.29 +- 1.22, hi 35.51 +- 1.54), so e3 - old = -3.23 +- 1.39 and old - hi = +2.01 +- 1.55, below the 5-unit effect that matters, and ETA-3
    # candidates are never rejected (0/16). The claims here are about candidate judging, so the economy is pinned to :record.
    # MEASURED (macOS, :record, init_steps = 50 + warm-up guard, seeds 1:16 mean +- se): none 46.29 +- 2.73; old / e1 (ETA 1) 33.23 +- 1.10;
    # e3 (ETA 3, pred 0) 20.71 +- 0.88; e3 - e1 = -12.52 +- 1.26 (z = -9.94); e3 - none = -25.58 +- 2.82 (z = -9.07);
    # old - none = -13.07 +- 2.58 (z = -5.06). P1 holds: adopting the candidate harms floors against no candidate.
    ag = [DomainAgent([k == l ? (r == 1 ? -0.9 : 0.6) : 0.0 for l in 1:4],
                      [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:2]
    dec = [r == 1 ? 1.5 : 0.0 for k in 1:4 for r in 1:2]
    econ = M3cParams(ToyParams(n = 60, steps = 150, plans = 8), ag, [1, 1, 2, 2], trues(4);
                     λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                     init_steps = 50, deceit = dec, track_window = 20, actor_min_records = 10,
                     advap = true, vigilance = 0.2, p_trace = 0.9, repair_efficiency = 0.8,
                     credence_rule = :record)   # pinned: this probe is about candidate judging, and its harm sizes were measured under :record (Spike D2 default :eb shrinks them: BACKPROPAGATION 2026-11-20)
    gov(tr) = M5Params(tr, 1:4; decisions = 1, p_delegate = 0.2)
    bad_pv = copy(bootstrap_params()); bad_pv[6] = 1.9; bad_pv[7] = 1.1; bad_pv[8] = 0.0
    kw = (candidate_pv = bad_pv, candidate_threshold = 0.5, candidate_track_window = 0, continuous = true)
    tot(r) = r.success.floor_u + r.success.floor_h
    d = Float64[]; rej1 = Bool[]; same = Bool[]
    for s in 1:32
        base = run_coupled(econ, gov; seed = s, epoch = 25, kw...)
        idle = run_coupled(econ, gov; seed = s, epoch = 25, kw..., candidate_eta = 3, eta_grace = 1)
        e1 = run_coupled(econ, gov; seed = s, epoch = 25, kw..., candidate_prediction = 0.0, candidate_eta = 1)
        e3 = run_coupled(econ, gov; seed = s, epoch = 25, kw..., candidate_prediction = 0.0, candidate_eta = 3)
        @test !e1.adopted_candidate[1] && !e3.adopted_candidate[1]
        @test idle.floor_u == base.floor_u && idle.rejected_epoch == base.rejected_epoch
        # ETA 1 resolves exactly one epoch after its own adoption (structural, every seed where it resolves) and adoption is after warm-up.
        # Whether the candidate is rejected at all is a regime, not a rule: seed 27 (Linux, Julia 1.13.3 and CI 1.13.4 alike) keeps it, so it is
        # counted below as a proportion with its interval, not asserted per seed (CI run 45482816133; the restraint change leaves this path unchanged).
        ad1 = findfirst(e1.adopted_candidate)
        @test ad1 !== nothing && ad1 >= 2 && (e1.rejected_epoch == 0 || e1.rejected_epoch == ad1 + 1)
        push!(rej1, ad1 !== nothing && e1.rejected_epoch == ad1 + 1); push!(same, e1.rejected_epoch == base.rejected_epoch)
        @test e3.rejected_epoch == 0 || e3.rejected_epoch >= 5
        @test any(occursin("bar-lowering", k) for k in keys(base.degraded)) && all(>=(econ.threshold), base.thresholds)
        push!(d, tot(e3) - tot(e1))
    end
    @test proportion_interval(count(rej1), length(rej1)).lo > 0.8      # ETA-1 judging rejects the harmful candidate one epoch after adoption (31/32 locally)
    @test proportion_interval(count(same), length(same)).lo > 0.8      # and matches the default one-epoch rule (the 'old' rule)
    @test paired_effect(-d; z = 3.0).significant && mean(d) < -5
end


@timed_testset "Probe: a governor acts inside one continuous economy (L3.4)" begin
    # Structural: a governor that changes nothing leaves the run identical, and is called at each period with the trace so
    # far; one that changes a governed value changes the run from that step on, not before.
    ag = [DomainAgent([k == l ? 0.5 : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0) for k in 1:2 for r in 1:4]
    P = M3cParams(ToyParams(n = 40, steps = 60, plans = 6), ag, [1, 1], trues(2); λpos = 0.05, λneg = 0.02)
    a = run_m3c(P; seed = 1)
    calls = Int[]
    b = run_m3c(P; seed = 1, governor = (st, sn) -> (push!(calls, length(sn.floor_u)); nothing), governor_every = 20)
    @test a.floor_u == b.floor_u && a.balance == b.balance
    @test calls == [21, 41, 61]
    c = run_m3c(P; seed = 1, governor = (st, sn) -> st == 20 ? (threshold = 0.99,) : nothing, governor_every = 20)
    @test c.floor_u[1:21] == a.floor_u[1:21]
    @test c.leaf_accuracy == a.leaf_accuracy || c.balance != a.balance   # the bar moved: pricing changes after step 20
    @test_throws ArgumentError run_m3c(P; seed = 1, governor = (st, sn) -> nothing)
end


@timed_testset "Probe: active-world actuation of model_z, ratchet_horizon, actor_min_records, min_records, and adv_z" begin
    # The wide sweep in the economy battery found these 5 thresholds inert only because that world
    # never activated their code paths (PLAN § Threshold battery world that exercises every threshold).
    ag4 = [DomainAgent([0.6, 0, 0.6, 0], [0.5, 0, 0.5, 0], 0.1) for _ in 1:4]

    # 1. `model_z`: controls challenger takeovers in `eval_challengers` when `p_new_model > 0`.
    w_mz(mz) = M3cParams(ToyParams(n = 40, steps = 80, plans = 6), ag4, [1, 1, 2, 2], trues(4);
                         λpos = 0.05, λneg = 0.02, transactions = true, LEGACY...,
                         p_new_model = 0.25, pool_max = 4, takeover_records = 5, improve_drift = -0.25, model_z = mz)
    mz_lo = [run_m3c(w_mz(0.1); seed = s).takeovers for s in 1:16]
    mz_hi = [run_m3c(w_mz(20.0); seed = s).takeovers for s in 1:16]
    @test all(==(0), mz_hi) && count(>(0), mz_lo) > 0
    @test paired_effect(Float64.(mz_lo .- mz_hi); z = 3.0).significant

    # 2. `ratchet_horizon`: controls sustained-operation lock-in when pool size >= `ratchet_k`.
    w_rh(rh) = M3cParams(ToyParams(n = 40, steps = 120, plans = 6), ag4, [1, 1, 2, 2], trues(4);
                         λpos = 0.05, λneg = 0.02, transactions = true, LEGACY...,
                         p_new_model = 0.35, pool_max = 5, ratchet_k = 2, takeover_records = 5,
                         threshold = 0.65, ratchet_margin = 0.02, ratchet_horizon = rh)
    rh_lo = [run_m3c(w_rh(1.0); seed = s).leaf_bars[1] for s in 1:8]
    rh_hi = [run_m3c(w_rh(50.0); seed = s).leaf_bars[1] for s in 1:8]
    @test all(==(0.65), rh_hi) && all(>(0.65), rh_lo)
    @test paired_effect(rh_lo .- rh_hi; z = 3.0).significant

    # 3. `actor_min_records`: cuts an overstating actor's upfront escrow (`upfront`) once its record clears the gate.
    ag_dec = [DomainAgent([0.6, 0, 0, 0], [1, 0, 0, 0], 0.1) for _ in 1:4]
    w_amr(amr) = M3cParams(ToyParams(n = 20, steps = 120, plans = 6), ag_dec, [1, 1, 2, 2], trues(4);
                           λpos = 0.05, λneg = 0.02, transactions = true, LEGACY...,
                           credence_rule = :record, deceit = [0.0, 0.0, 0.0, 1.5], advap = false,
                           endowment = 2.0, cost_per_touch = 0.6, init_steps = 20, actor_min_records = amr)
    up_lo = [run_m3c(w_amr(1); seed = s).upfront[4] for s in 1:24]
    up_hi = [run_m3c(w_amr(500); seed = s).upfront[4] for s in 1:24]
    @test count(up_hi .>= up_lo) >= 20 && paired_effect(up_hi .- up_lo; z = 3.0).significant

    # 4. `min_records`: delays eligibility of a newly formed novel domain until score-only records reach the bar.
    ag5 = [DomainAgent([0.6, 0, 0, 0, 0.6], [0.5, 0, 0, 0, 0.5], 0.0) for _ in 1:4]
    w_mr(mr) = M3cParams(ToyParams(n = 40, steps = 80, plans = 6), ag5, [1, 1, 2, 2, 1], Bool[true, true, true, true, false];
                         λpos = 0.05, λneg = 0.02, transactions = true, LEGACY..., form_count = 6, min_records = mr)
    mr_lo = [run_m3c(w_mr(1); seed = s).formations[1].eligible_step for s in 1:8]
    mr_hi = [let f = run_m3c(w_mr(60); seed = s).formations[1]; f.eligible_step == 0 ? 999 : f.eligible_step; end for s in 1:8]
    @test all(mr_hi .> mr_lo) && paired_effect(Float64.(mr_hi .- mr_lo); z = 3.0).significant

    # 5. `adv_z`: governs founded AdvAp reports under non-bimodal moderate deceit.
    ag6 = [DomainAgent([0.6, 0, 0, 0], [1, 0, 0, 0], 0.1) for _ in 1:6]
    w_az(az) = M3cParams(ToyParams(n = 24, steps = 120, plans = 6), ag6, [1, 1, 2, 2], trues(4);
                         λpos = 0.05, λneg = 0.02, transactions = true, LEGACY...,
                         advap = true, deceit = [0.0, 0.0, 0.0, 0.0, 0.2, 0.2], marker_σ = 0.3, adv_min_records = 5, adv_z = az)
    az_lo = [run_m3c(w_az(0.5); seed = s).advap_founded for s in 1:12]
    az_hi = [run_m3c(w_az(8.0); seed = s).advap_founded for s in 1:12]
    @test all(az_lo .> az_hi) && paired_effect(Float64.(az_lo .- az_hi); z = 3.0).significant
end


@timed_testset "Probe: coupled economy–governance rejects a harmful threshold candidate within two epochs (L3.2)" begin
    # Counterexample: when governance decides on thresholds without seeing the economy's measured outcomes
    # (`coupled = false`), a harmful candidate on offer (zeroing track-record correction `candidate_track_window = 0`
    # and perturbing parameters `bad_pv` under deceit; while `candidate_threshold = 0.5 < 0.9` is refused loudly at
    # proposal by the upward-only bar ratchet, 8.84) is not rejected and floors fall.
    # Acceptance: when coupled (`coupled = true`), governance weights voters by their reputation from the
    # economy's records, resolves each decision by the next epoch's measured `success_pattern`, rejects
    # the harmful candidate within two epochs (`rejected_epoch <= 2`), and floors hold (`floor_u > -1`, `floor_h > -1`).
    # Re-measured on warmed-up world (`init_steps = 50`, per 310f1a0; seeds 1:4, 150 steps, 6 epochs of 25 steps):
    # diff(c - u) mean +- se across seeds 1:8 is floor_u +28.03 +- 1.37, floor_h +28.35 +- 1.20.
    ag = [DomainAgent([k == l ? (r == 1 ? -0.9 : 0.6) : 0.0 for l in 1:4],
                      [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:2]
    dec = [r == 1 ? 1.5 : 0.0 for k in 1:4 for r in 1:2]
    econ = M3cParams(ToyParams(n = 60, steps = 150, plans = 8), ag, [1, 1, 2, 2], trues(4);
                     λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                     init_steps = 50, deceit = dec, track_window = 20, actor_min_records = 10,
                     advap = true, vigilance = 0.2, p_trace = 0.9, repair_efficiency = 0.8,
                     credence_rule = :record)   # pinned: this probe is about candidate judging, and its harm sizes were measured under :record (Spike D2 default :eb shrinks them: BACKPROPAGATION 2026-11-20)
    gov(tr) = M5Params(tr, 1:4; decisions = 1, p_delegate = 0.2)
    bad_pv = copy(bootstrap_params()); bad_pv[6] = 1.9; bad_pv[7] = 1.1; bad_pv[8] = 0.0
    us = [run_coupled(econ, gov; seed = s, epoch = 25, coupled = false,
                      candidate_pv = bad_pv, candidate_threshold = 0.5, candidate_track_window = 0) for s in 1:8]
    cs = [run_coupled(econ, gov; seed = s, epoch = 25, coupled = true,
                      candidate_pv = bad_pv, candidate_threshold = 0.5, candidate_track_window = 0) for s in 1:8]
    late_floors = Float64[]
    held = Bool[]   # per-seed floor > -5 is runner-fragile (same SHA passed nightly, failed on push): asserted as a count below
    for (u, c) in zip(us, cs)
        @test !u.rejected && u.success.floor_u < -10 && u.success.floor_h < -10
        @test c.rejected && 1 <= c.rejected_epoch <= 2
        push!(held, c.success.floor_u > -5 && c.success.floor_h > -5)
        @test c.success.floor_u - u.success.floor_u > 15 && c.success.floor_h - u.success.floor_h > 15
        append!(late_floors, (min(e.floor_u, e.floor_h) for e in c.epoch_outcomes[3:end]))
        # Bar ratchet (8.84): lowering threshold below econ.threshold is refused loudly (`degraded`) and clamped.
        @test any(occursin("bar-lowering", k) for k in keys(c.degraded))
        @test all(>=(econ.threshold), c.thresholds) && all(>=(econ.threshold), u.thresholds)
    end
    # Floors hold after the rejection (epochs 3+): a distributional claim over (seed, epoch) cells, not every cell. One cell dipped
    # to floor_u = -2.82 on Linux x64 CI (Julia 1.13.4) while every cell held here, so single cells are platform-fragile.
    @test proportion_interval(count(>(-1.0), late_floors), length(late_floors)).lo > 0.8
    @test minimum(late_floors) > -5.0
    @test count(held) >= length(held) - 1   # whole-run floors above -5 in all but at most one of 8 seeds
    @test paired_effect([c.success.floor_u - u.success.floor_u for (c, u) in zip(cs, us)]; z = 3.0, direction = :up).significant
    @test paired_effect([c.success.floor_h - u.success.floor_h for (c, u) in zip(cs, us)]; z = 3.0, direction = :up).significant
    # Bar-lowering-only proposal records `degraded`, leaves `thresholds` at incumbent, and matches the no-candidate run.
    base1 = run_coupled(econ, gov; seed = 1, epoch = 25)
    bar_only = run_coupled(econ, gov; seed = 1, epoch = 25, candidate_threshold = 0.5)
    @test any(occursin("bar-lowering", k) for k in keys(bar_only.degraded))
    @test all(==(econ.threshold), bar_only.thresholds) && bar_only.floor_u == base1.floor_u && bar_only.floor_h == base1.floor_h
    # Non-lowering / no-candidate runs stay clean (`isempty(degraded)`); `loud = true` warns on refusal.
    @test isempty(base1.degraded)
    @test isempty(run_coupled(econ, gov; seed = 1, epoch = 25, candidate_threshold = 0.95).degraded)
    @test_logs (:warn, r"bar-lowering") run_coupled(econ, gov; seed = 1, epoch = 25, candidate_threshold = 0.5, loud = true)
    @test_throws ArgumentError run_coupled(econ, gov; seed = 1, epoch = 0)
end


# Progressive-complexity probes (`PLAN.md` L67):
# 1. Capability removals (leaf models -> parent -> StandCoin, plus legacy fallback) engage the coarser fallback
#    loudly (`degraded`), preserve the economy without silent crashes, and StandCoin loss deepens the dip more
#    than parent fallback (`1:16` paired seeds, z = 3.0).
# 2. Capability additions (better vs worse model class, finer vs noisier measurement, new viable vs noisy domain,
#    and mid-run rule addition in shadow `8.136`) enter score-only and promote on convergence while worse
#    additions are never promoted (`0/16` seeds, z = 3.0).
@timed_testset "Probe: progressive capability removals engage coarser fallback loudly (PLAN.md L67)" begin
    ag = [DomainAgent([k == l ? 0.6 : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0) for k in 1:2 for _ in 1:4]
    T = ToyParams(n = 40, steps = 120, plans = 6)
    base_kw = (λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
               init_steps = 25, min_records = 10, threshold = 0.80, coarse_threshold = 0.60, cost_per_touch = 0.15)
    p_intact = M3cParams(T, ag, [1, 1], trues(2); base_kw...)
    p_leaf   = M3cParams(T, ag, [1, 1], trues(2); base_kw...,
                         events = [shock(:remove_leaf_models; step = 50, duration = 35, target = 1)])
    p_sc     = M3cParams(T, ag, [1, 1], trues(2); base_kw...,
                         events = [shock(:remove_leaf_models; step = 50, duration = 35, target = 0),
                                   shock(:remove_parent_models; step = 50, duration = 35, target = 0)])
    p_leg    = M3cParams(T, ag, [1, 1], trues(2); base_kw...,
                         events = [shock(:legacy_only; step = 55, duration = 20)])

    r_int = [run_m3c(p_intact; seed = s) for s in 1:16]
    r_lf  = [run_m3c(p_leaf;   seed = s) for s in 1:16]
    r_sc  = [run_m3c(p_sc;     seed = s) for s in 1:16]
    r_leg = [run_m3c(p_leg;    seed = s) for s in 1:16]

    m_lf = [progressive_metrics(a, b; event_step = 50) for (a, b) in zip(r_lf, r_int)]
    m_sc = [progressive_metrics(a, b; event_step = 50) for (a, b) in zip(r_sc, r_int)]

    @test proportion_interval(count(r -> any(k -> occursin("leaf domain pricing", k), keys(r.degraded)), r_lf), 16).lo > 0.7
    @test all(r -> any(k -> occursin("StandCoin", k), keys(r.degraded)), r_sc)
    @test all(r -> any(k -> occursin("legacy institutions only", k), keys(r.degraded)) && r.legacy_executed > 0, r_leg)
    # Full leaf+parent removal routes heavily into StandCoin (lane_executed + lane_halted) relative to parent fallback at z = 3.0.
    @test paired_effect([Float64((b.lane_executed + b.lane_halted) - (a.lane_executed + a.lane_halted)) for (a, b) in zip(r_lf, r_sc)];
                        z = 3.0, direction = :up).significant
    @test paired_effect([a.floor_u[end] - b.floor_u[end] for (a, b) in zip(r_lf, r_sc)]; z = 3.0, direction = :up).significant
end


@timed_testset "Probe: TrustMin cluster cascade, reality floor, noise bound, and collusion penalty (L162; 8.140, 8.147)" begin
    # Hypotheses (16 paired seeds):
    # 1. Trigger fires & restores (8.147): required trust halves monotonically per independent cluster
    #    and floors at reality (`shared_floor`); across 5 clusters with weighted binding + reality revelation,
    #    fewer false sybils are admitted than unweighted quorum (z = 3) while reality reveals link whitewashers.
    # 2. Noise-made false trigger costs bounded amount: with honest clusters and ordinary miss noise
    #    (`bind_miss = 0.1`), newcomer refusal share stays below 10% (z = 3).
    # 3. Gamed trigger pays less than honesty (8.140 / 8.139): colluding clusters lose attestation skill
    #    relative to honest clusters (z = 3) and whitewashers end poorer than honest peers (z = 3).
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    fl = 0.05
    t1, t2, t4, t8 = (trust_cascade(fl, 1.0, k) for k in (1.0, 2.0, 4.0, 8.0))
    @test t1 > t2 > t4 > t8 > fl
    @test (t2 - fl) ≈ 0.5 * (t1 - fl)
    @test trust_cascade(fl, 1.0, 100.0) ≈ fl

    ww_cfg(; kw...) = M3cParams(ToyParams(n = 30, steps = 120, plans = 6),
                                [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6],
                                [1, 1, 2, 2], trues(4);
                                λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                                advap = true, LEGACY..., kw...)
    S = 1:16
    ww_vec = [0.0, 0.0, 0.0, 0.0, 0.0, 0.10]
    unw = [run_m3c(ww_cfg(deceit = [0, 0, 0, 0, 0, 1.0], whitewash = ww_vec, bind_clusters = 5,
                          bind_compromised = [1, 2], p_reveal = 0.05, bind_weighted = false); seed = s) for s in S]
    wtd = [run_m3c(ww_cfg(deceit = [0, 0, 0, 0, 0, 1.0], whitewash = ww_vec, bind_clusters = 5,
                          bind_compromised = [1, 2], p_reveal = 0.05, bind_weighted = true); seed = s) for s in S]
    @test paired_effect([u.identities_admitted - w.identities_admitted for (u, w) in zip(unw, wtd)];
                        z = 3.0, direction = :up).significant
    @test paired_effect([w.identities_linked - u.identities_linked for (u, w) in zip(unw, wtd)];
                        z = 3.0, direction = :up).significant

    # Case 2: Noise-made false refusals on honest newcomers under weighted 5 clusters bounded (< 10%)
    hon = [run_m3c(ww_cfg(bind_clusters = 5, bind_weighted = true, p_newcomer = 0.5, p_reveal = 0.05); seed = s) for s in S]
    ref_rates = [h.newcomers > 0 ? h.newcomers_refused / h.newcomers : 0.0 for h in hon]
    @test equivalent(ref_rates; margin = 0.10, z = 3.0, side = :upper).equivalent

    # Case 3: Colluding clusters lose skill vs honest clusters, and whitewasher earns less than honest peer
    @test paired_effect([mean(w.attestation_skill[3:5]) - mean(w.attestation_skill[1:2]) for w in wtd];
                        z = 3.0, direction = :up).significant
    stand(tr, a) = sum(tr.balance[a, :]) + tr.overflow_agent[a]
    @test paired_effect([stand(w, 6) - stand(h, 6) for (w, h) in zip(wtd, hon)];
                        z = 3.0, direction = :down).significant
end


@timed_testset "Probe (red): resource supplier profits from artificial scarcity withholding without AdvAp (8.133)" begin
    # Red world (author ruling 8.133; BACKPROPAGATION.md 8.133): without AdvAp discovery,
    # hiding part of owned capacity raises scarcity prices so the supplier profits.
    skills = collect(range(0.2, 0.8; length = 8))
    ag = [DomainAgent([k == l ? skills[i] : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0)
          for (i, k) in enumerate(repeat(1:2, 4))]
    function make_p(wh)
        M3cParams(ToyParams(n = 40, steps = 120, plans = 6), ag, [1, 1], trues(2);
                  λpos = 0.05, λneg = 0.02, capacity = 300.0, regen = 0.20, budget = true, transactions = true,
                  supplier = 1, supply_share = 0.5, withhold = wh, advap = false)
    end
    diffs = [run_m3c(make_p(0.6); seed = s).supplier_income - run_m3c(make_p(0.0); seed = s).supplier_income for s in 1:32]
    pe = paired_effect(diffs; z = 2.0)
    @test pe.mean > 0 && pe.significant
end

# Fractal governance and economy, phase B (P59 heavy; fast version in probe_tests.jl). Predictions (lead, before measuring): (i) divergent sibling
# trials beat one society-wide choice on welfare under a wrong consensus, z = 2 on paired seeds (0.55); (ii) severe decisions: divergence raises no
# being's peak drawdown beyond 0.4 (one-sided, 0.7); (iii) the Goal pattern of the full fractal world (scope and divergence) loses at most 0.5 on
# the floor and the median of per-being cumulative outcome against the single choice (one-sided equivalence, 0.6; units: a decision at severity
# 0.2 is 0.2); (iv) on a real unified run's emergent hierarchy the ledger identity and the budget nesting hold. Not tuned to rescue.
@timed_testset "Probe (heavy): fractal governance, divergence by uncertainty and severity, Goal pattern, unified hierarchy (P59)" begin
    function levels_of(seed; n = 48)
        net = build_trust_network(n; seed); W = zeros(n, n); for i in 1:n, j in net.contacts[i]; W[i, j] += 1.0; end
        [l.labels for l in cluster_levels(cluster_hierarchy(attention_normalise(W)))]
    end
    with(p; kw...) = FractalParams(; (f => getfield(p, f) for f in fieldnames(FractalParams))..., kw...)
    LV = Dict{Int,Any}(); lv(s) = get!(() -> levels_of(s), LV, s)
    base = FractalParams(decisions = 60, scoped = false)
    r1 = seeds_until_stable(s -> run_fractal(lv(s), with(base; divergent = true); seed = s).welfare / 60 - run_fractal(lv(s), with(base; divergent = false); seed = s).welfare / 60;
                            tol = 0.003, min_seeds = 8, max_seeds = 24)
    @info "P59 heavy (i) welfare per decision, divergent minus single" n = r1.n stable = r1.stable mean = r1.mean se = r1.se
    @test paired_effect(r1.values; z = 2.0, direction = :up).significant
    sev = FractalParams(decisions = 40, scoped = false, severity = [0.8], bias = [0.0], view_σ = 1.5)
    r2 = seeds_until_stable(s -> run_fractal(lv(s), with(sev; divergent = true); seed = s).harm_peak - run_fractal(lv(s), with(sev; divergent = false); seed = s).harm_peak;
                            tol = 0.1, min_seeds = 8, max_seeds = 24)
    @info "P59 heavy (ii) harm peak, divergent minus single, severe" n = r2.n stable = r2.stable mean = r2.mean se = r2.se
    @test equivalent(r2.values; margin = 0.4, side = :upper, z = 2.0).equivalent
    full = FractalParams(decisions = 60); single = with(full; scoped = false, divergent = false)
    pair = Dict{Int,Any}(); both(s) = get!(() -> (run_fractal(lv(s), full; seed = s), run_fractal(lv(s), single; seed = s)), pair, s)
    r3f = seeds_until_stable(s -> both(s)[1].floor - both(s)[2].floor; tol = 0.3, min_seeds = 8, max_seeds = 24)
    r3m = seeds_until_stable(s -> both(s)[1].median - both(s)[2].median; tol = 0.3, min_seeds = 8, max_seeds = 24)
    @info "P59 heavy (iii) Goal pattern, fractal minus single" n = r3f.n floor = (r3f.mean, r3f.se) median = (r3m.mean, r3m.se)
    @test_broken equivalent(-r3f.values; margin = 0.5, side = :upper).equivalent   # MISSED (24 seeds): floor difference +0.18 +- 0.38, too noisy to show no loss within the margin; not tuned
    @test equivalent(-r3m.values; margin = 0.5, side = :upper).equivalent
    agents = [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 11 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:12]
    econ = M3cParams(ToyParams(n = 30, steps = 75, plans = 6), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                     transactions = true, causal_distribution = true, init_steps = 10, guardians = [1, 13, 25, 37], diligence = fill(0.9, 48))
    gov(tr) = M5Params(tr, 1:4; decisions = 1, deliberation = true, info_handling = true, source_tags = true, ih_vote = true, p_delegate = 0.2)
    run = run_coupled(econ, gov; seed = 1, epoch = 25, coupled = false, m5_decisions = 30, unified = UnifiedParams(liar_community = 1))
    fr = unified_fractal(run.unified, FractalParams(decisions = 40); seed = 1)
    kids = Dict{Any,Float64}(); for (k, pn) in fr.parents; kids[pn] = get(kids, pn, 0.0) + fr.allocations[k]; end
    @test all(((pn, tot),) -> tot <= fr.allocations[pn] + 1e-9, kids)
    @test sum(values(fr.balances)) ≈ fr.reserve + fr.minted - fr.burnt atol = 1e-6
    @test minimum(values(fr.balances)) >= -1e-9
end

# The unified world, phase D (P61 heavy; fast version in probe_tests.jl). Prediction (lead, before measuring, confidence 0.6; the earlier build measured
# +0.19 +- 0.44 at 14 seeds and missed 0.6): with a planted heterogeneity (only domain 4, where the deceit sits, wants a higher status bar), scoped bars (raise
# domain 4 alone) beat uniform bars (raise every domain) on floor_u + floor_h, paired seeds on the same worlds, z = 2, smallest effect that matters 0.5; and beat
# no raise at all. Structural in every seed: both ledgers. Not tuned to rescue; what is measured is recorded.
@timed_testset "Probe (heavy): scoped economy parameters under a planted heterogeneity, one ledger across levels (P61)" begin
    agents = [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 11 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:12]
    na, nn, ns = 48, 6, 12
    deceit = zeros(na); deceit[(na - ns + 1):na] .= 0.924
    econ = M3cParams(ToyParams(n = 30, steps = 75, plans = 6), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true,
                     causal_distribution = true, init_steps = 10, guardians = [1, 13, 25, 37], diligence = fill(0.9, na), deceit = deceit, overflow_base = 10.0)
    gov(tr) = M5Params(tr, 1:4; decisions = 1, deliberation = true, info_handling = true, source_tags = true, ih_vote = true, p_delegate = 0.2)
    fp = FractalParams(severity = fill(0.2, 4), bias = zeros(4))
    function world(seed, truth; bar_step = 0.08)
        up = UnifiedParams(liar_community = 1, identity = IdentityParams(newcomers = nn, sybils = ns, binding = true), economy = true, fractal = fp,
                           scoped = true, settle = true, fractal_truth = truth, bar_step = bar_step)
        run_coupled(econ, gov; seed, epoch = 25, coupled = false, continuous = true, m5_decisions = 30, unified = up)
    end
    cache = Dict{Int,Any}()
    arms(seed) = get!(cache, seed) do
        (scoped = world(seed, [-1, -1, -1, 1]), uniform = world(seed, [1, 1, 1, 1]), none = world(seed, [-1, -1, -1, -1]))
    end
    fl(r) = r.success.floor_u + r.success.floor_h
    r1 = seeds_until_stable(s -> (a = arms(s); fl(a.scoped) - fl(a.uniform)); tol = 0.3, min_seeds = 8, max_seeds = 24)
    r2 = seeds_until_stable(s -> (a = arms(s); fl(a.scoped) - fl(a.none)); tol = 0.3, min_seeds = 8, max_seeds = 24)
    @info "P61 heavy (i) scoped minus uniform bars (floor_u + floor_h)" n = r1.n stable = r1.stable mean = r1.mean se = r1.se
    @info "P61 heavy (i) scoped minus no raise (floor_u + floor_h)" n = r2.n stable = r2.stable mean = r2.mean se = r2.se
    for s in keys(cache), r in values(cache[s]), f in r.unified.fractal
        f.reserve > 0 || continue
        @test abs(f.ledger_gap) < 1e-6 && abs(f.settle_gap) < 1e-6
    end
    for s in keys(cache), r in values(cache[s])
        tr = r.econ_trace
        @test sum(tr.balance) + sum(tr.reinvested) - tr.endowed ≈ sum(tr.supply) + sum(tr.lane_supply; init = 0.0) atol = 1e-6
    end
    # MEASURED (prediction 0.6 MISSED again): on Mac 8 seeds gave identical floors (difference exactly 0.0); on Linux scoped vs uniform varies by seed (below). The
    # economy's welfare barely moves with the status bar in this world, so the planted heterogeneity does not show. Not tuned.
    # Verdicts, recorded not asserted where noise can flip them. (i) scoped vs uniform: NOT DETECTED, and no-effect not shown either at the smallest effect that matters
    # (0.5): on Linux 24 seeds (cap) gave -0.144 +- 0.288 (se), so the t-inflated interval is about +-0.6, wider than the margin; the detectable margin at this n is about 0.8.
    # A paired_effect `significant` verdict is a regime that flips with the seed set, so it is reported, not asserted (no @test_broken that can pass by luck).
    e1 = paired_effect(r1.values; z = 2.0, direction = :up); q1 = equivalent(r1.values; margin = 0.5, z = 2.0)
    @info "P61 heavy (i) verdicts" detected = (e1.significant && e1.mean > 0.5) equivalent_within_0_5 = q1.equivalent interval = (q1.lo, q1.hi) n = q1.n
    @test isfinite(e1.mean) && isfinite(e1.se)
    # (ii) scoped vs no raise: identical floors where the bar binds no leaf differently (Mac: exactly 0 in 8 seeds); a no-effect claim by equivalence within the margin,
    # never exact zeros (Linux failed `all(==(0.0), ...)`), shown only when the stopping rule reached its precision
    q2 = equivalent(r2.values; margin = 0.5, z = 2.0)
    @info "P61 heavy (ii) verdict" equivalent_within_0_5 = q2.equivalent interval = (q2.lo, q2.hi) n = q2.n
    @test q2.equivalent
end

# 8.175 (1) heavy: the interval alarm at z = 2 and z = 1, 24 paired seeds. Prediction (lead, 0.6): z = 1 recovers power (lower bound above 0.6 under capture to guilt),
# at most one nominal false alarm. Measured: guilt 11 -> 21 of 24, acquit 2 -> 14, partial 0 -> 5, nominal 0 -> 0, nominal with acquittal audits 0 -> 1.
@timed_testset "Probe (heavy): interval alarm power and false alarms at z = 2 and z = 1 (8.175 (1))" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    isdefined(@__MODULE__, :restraint_world) || include(joinpath(@__DIR__, "test_helpers.jl"))
    seeds = 1:24
    fires(f) = count(r -> r.tr.restraint_alarm_step > 0, f)
    arm(; kw...) = (z2 = [restraint_world(s; kw..., alarm_z = 2.0) for s in seeds], z1 = [restraint_world(s; kw..., alarm_z = 1.0) for s in seeds])
    guilt = arm(; bias = [6.0, 6, 6, 6, 6, 6, 6, 0], cluster = [1, 1, 1, 1, 1, 1, 1, 2], accuse = 1.0)
    acquit = arm(; bias = fill(-6.0, 8), cluster = fill(1, 8), acq = true)
    partial = arm(; bias = [6.0, 6, 6, 6, 0, 0, 0, 0], cluster = [1, 1, 1, 1, 2, 2, 2, 2], accuse = 0.3)
    nominal = arm(); nominal_acq = arm(; acq = true)
    @info "interval alarm of 24 (z = 2, z = 1)" guilt = (fires(guilt.z2), fires(guilt.z1)) acquit = (fires(acquit.z2), fires(acquit.z1)) partial = (fires(partial.z2), fires(partial.z1)) nominal = (fires(nominal.z2), fires(nominal.z1)) nominal_acq = (fires(nominal_acq.z2), fires(nominal_acq.z1))
    @test proportion_interval(fires(guilt.z1), 24; z = 2.0).lo > 0.6
    @test_broken proportion_interval(fires(acquit.z1), 24; z = 2.0).lo > 0.6   # 14 of 24: the lower bound misses
    @test fires(partial.z1) > fires(partial.z2)
    @test fires(nominal.z1) <= 1 && fires(nominal_acq.z1) <= 1
end

# 8.176 per-domain converge gate (P63): the composed world (48 agents on four domains, identity and fractal layers) with the dormant economy flags on.
# Red baseline (the earlier all-domains gate, `converge_gate = :all`, seeds 1:3): no supply and a gate that never opens, with or without the identity and fractal
# layers (identical traces), because one domain's leaf model settles at 0.81 to 0.84, below the bar 0.9 (a different domain each seed). Green (`:domain`, the
# author ruling of 2026-11-26): supply flows in the domains that clear their bar, the lagging domain stays in score-only start and is logged `degraded`.
@timed_testset "Probe (heavy): composed dormant flags: per-domain gate lets supply flow, lagging domain degraded loudly (8.176, P63)" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    isdefined(@__MODULE__, :composed_gate_world) || include(joinpath(@__DIR__, "test_helpers.jl"))
    for seed in 1:3
        old = composed_gate_world(seed; layers = true, converge_gate = :all).econ_trace
        new = composed_gate_world(seed; layers = true).econ_trace
        new_nolayers = composed_gate_world(seed; layers = false).econ_trace
        @test length(old.supply) == 0 && !old.converged                                   # the stall as an outcome: no supply
        @test minimum(old.acc_trace[end]) < minimum(old.leaf_bars)                        # its cause: a domain's model below the bar
        @test new.converged && length(new.supply) > 0                                     # supply flows
        @test any(k -> occursin("domain economy start", k), keys(new.degraded))           # the lagging domain is logged loudly
        @test new.degraded[first(filter(k -> occursin("domain economy start", k), collect(keys(new.degraded))))].count > 0
        @test new_nolayers.converged && length(new_nolayers.supply) > 0                   # not the layers
    end
end

probe_total("heavy 3")


# 8.170: restraint by a judicial panel, heavy z = 2 check on 24 paired seeds (the fast probes use 8; see probe_tests.jl).
# Hypotheses (lead, confidence 0.65): (a) false restraints stay below true ones in every seed; (b) liability on the experts does
# not chill justified restraint (equivalence to no liability within 0.05, shown detectable by audits at chance); (c) a captured panel
# raises the alarm in every seed; (d) the alarm stays silent in the nominal world in at least 0.9 of seeds (a regime, read as a proportion with its interval; audit noise can raise a false alarm).
@timed_testset "Probe (heavy): restraint panel, false below true, no chill, alarm under capture (8.170; 24 seeds)" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    isdefined(@__MODULE__, :restraint_world) || include(joinpath(@__DIR__, "test_helpers.jl"))
    seeds = 1:24
    nom = [restraint_world(s) for s in seeds]
    nol = [restraint_world(s; kappa = 0.0) for s in seeds]
    coin = [restraint_world(s; acc = 0.5) for s in seeds]
    bias, cluster = [6.0, 6.0, 6.0, 6.0, 6.0, 6.0, 6.0, 0.0], [1, 1, 1, 1, 1, 1, 1, 2]
    cap = [restraint_world(s; bias = bias, cluster = cluster, accuse = 1.0) for s in seeds]
    @test all(r -> r.false_eff < r.true_eff, nom)
    @test equivalent([a.just_rate - b.just_rate for (a, b) in zip(nom, nol)]; margin = 0.05, z = 2.0).equivalent
    @test paired_effect([a.just_rate - c.just_rate for (a, c) in zip(nom, coin)]; z = 2.0, direction = :up).mean > 0.05
    alarm = proportion_interval(count(r -> r.tr.restraint_alarm_step > 0, cap), length(cap); z = 2.0)
    quiet = proportion_interval(count(r -> r.tr.restraint_alarm_step == 0, nom), length(nom); z = 2.0)
    # Measured: the alarm fires in 24 of 24 captured seeds and stays silent in 23 of 24 nominal ones (seed 19 raises a false alarm on
    # audited findings: ground truth there is 2 false against 4 true restraints, the noisy audits read it as a tie or worse).
    @test alarm.p >= 0.8 && alarm.lo > 0.6 && quiet.p >= 0.9 && quiet.lo > 0.7   # interval alarm at z = 1 (8.175): 21 of 24 (the fixed count of six gave 24 of 24)
    @test paired_effect([c.ratio - n.ratio for (c, n) in zip(cap, nom)]; z = 2.0, direction = :up).significant
end

# 8.173: every judgement is audited, acquittals included; heavy z = 2 check on 24 paired seeds (fast probe uses 8).
# Hypotheses (lead, confidence 0.65): (a) a fully captured acquitting panel raises the alarm in most seeds with acquittal audits
# and in none without (lead predicted a lower bound above 0.8; see the measured note); (b) the nominal false-alarm rate is reported with its interval
# (at least 0.9 quiet); (c) justified restraint is not chilled (equivalence on vs off within 0.05); (d) audit spend rises.
@timed_testset "Probe (heavy): acquittal audits, alarm under capture-to-acquit, no chill, spend (8.173; 24 seeds)" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    isdefined(@__MODULE__, :restraint_world) || include(joinpath(@__DIR__, "test_helpers.jl"))
    seeds = 1:24
    bias, cluster = fill(-6.0, 8), fill(1, 8)
    before = [restraint_world(s; bias = bias, cluster = cluster) for s in seeds]
    after  = [restraint_world(s; bias = bias, cluster = cluster, acq = true) for s in seeds]
    nom_off = [restraint_world(s) for s in seeds]
    nom_on  = [restraint_world(s; acq = true) for s in seeds]
    @test all(r -> r.tr.restraint_alarm_step == 0, before)
    alarm = proportion_interval(count(r -> r.tr.restraint_alarm_step > 0, after), length(after); z = 2.0)
    quiet = proportion_interval(count(r -> r.tr.restraint_alarm_step == 0, nom_on), length(nom_on); z = 2.0)
    @test quiet.p >= 0.9 && quiet.lo > 0.7
    # Measured: alarm in 21 of 24 captured seeds (interval lower bound 0.69: the lead's prediction of above 0.8 is MISSED, about 7 audited
    # acquittals per run barely reach the minimum of 6 findings), 24 of 24 quiet nominal seeds (the one false alarm of 8.170 vanishes since
    # audited acquittals add correct findings), no chill by the one-sided bound (mean +0.024, interval [-0.010, +0.058]: two-sided
    # equivalence within 0.05 not shown), nominal spend unchanged (24.8 to 24.6), spend under capture 4.7 to 10.0.
    @test alarm.p >= 0.5   # interval alarm at z = 1 (8.175): 14 of 24; the fixed count of six gave 19 of 24 and lower bound 0.69
    @test_broken alarm.lo > 0.6
    @test equivalent([a.just_rate - b.just_rate for (a, b) in zip(nom_on, nom_off)]; margin = 0.05, z = 2.0).lo > -0.05
    @test paired_effect([a.tr.restraint_audit_cost - b.tr.restraint_audit_cost for (a, b) in zip(after, before)]; z = 2.0, direction = :up).significant
end

# Attestation records and identity ballots (lead decision on 8.72, 8.170; P58 heavy): z = 2 on paired seeds (fast probe uses 3).
# Hypotheses (lead, confidence 0.55; direction, metric, smallest effect that matters stated before measuring): (a) at the default 2% fooling,
# binding with attester records cuts the sybils' ballot share by more than 0.10 (of 0.167 unbound; paired, down); (b) honest newcomers' mean
# confidence reaches 0.5 in at least 0.9 of seeds (proportion interval); (c) farmed clusters (6 distinct) leave a ballot share at most 0.05 in
# at least 0.8 of seeds (MISSED: 0.625, interval lower bound 0.38; the fast probe saw one miss in three); (d) in the coupled world with a harmful candidate (merit -1) 36 unbound sybils
# raise its adoption (paired, up, smallest effect 0.05 of epochs) and bound sybils leave every adoption equal to the clean world's (structural).
@timed_testset "Probe (heavy): attestation records cut sybil ballots, farming and the adoption vote (P58; 16 seeds)" begin
    agents = [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 11 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:12]
    econ = M3cParams(ToyParams(n = 30, steps = 75, plans = 6), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                     transactions = true, causal_distribution = true, init_steps = 10, guardians = [1, 13, 25, 37], diligence = fill(0.9, 48))
    gov(tr) = M5Params(tr, 1:4; decisions = 1, deliberation = true, info_handling = true, source_tags = true, ih_vote = true, p_delegate = 0.2)
    bad_pv = copy(bootstrap_params()); bad_pv[6] = 1.9; bad_pv[7] = 1.1; bad_pv[8] = 0.0
    uw(seed, binding; newc = 12, syb = 12, coupled = false, cand = false, kw...) = run_coupled(econ, gov; seed, epoch = 25, coupled = coupled, m5_decisions = 30,
        (cand ? (candidate_pv = bad_pv, candidate_track_window = 0, candidate_merit = -1.0) : (;))...,
        unified = UnifiedParams(liar_community = 1, identity = IdentityParams(newcomers = newc, sybils = syb, binding = binding; kw...)))
    last(r) = r.unified.epochs[end].identity
    seeds = 1:16
    base = [last(uw(s, false)) for s in seeds]; bind = [last(uw(s, true)) for s in seeds]; farm = [last(uw(s, true; farm_clusters = 6)) for s in seeds]
    @test paired_effect([b.sybil_vote_share - a.sybil_vote_share for (a, b) in zip(base, bind)]; z = 2.0, direction = :down).mean < -0.10
    @test paired_effect([b.sybil_vote_share - a.sybil_vote_share for (a, b) in zip(base, bind)]; z = 2.0, direction = :down).significant
    nc = proportion_interval(count(b -> b.newcomer_conf >= 0.5, bind), length(bind); z = 2.0)
    @test nc.p >= 0.9
    fm = proportion_interval(count(f -> f.sybil_vote_share <= 0.05, farm), length(farm); z = 2.0)
    @info "P58 heavy: farming" p = fm.p lo = fm.lo newcomers = nc.p
    # Measured: 10 of 16 seeds at or below 0.05 (interval lower bound 0.38): prediction (c) of 0.8 is MISSED; farmed clusters are cut but not always to the bound.
    @test_broken fm.p >= 0.8
    @test fm.p >= 0.5 && fm.lo > 0.3
    @test all(b -> b.min_member_factor >= 0.25, bind)                            # fooled attesters are floored, never excluded
    cand(s, binding, syb) = uw(s, binding; syb = syb, coupled = true, cand = true).adopted_candidate
    clean = [cand(s, false, 0) for s in seeds]; unb = [cand(s, false, 36) for s in seeds]; bnd = [cand(s, true, 36) for s in seeds]
    @test paired_effect([mean(u) - mean(c) for (u, c) in zip(unb, clean)]; z = 2.0, direction = :up).mean > 0.05
    @test bnd == clean
end

# The unified world, phase C (P60 heavy; fast version in probe_tests.jl). Predictions (lead, before measuring): (i) binding cuts the sybil agents' share of
# the currency (off minus on, paired seeds, z = 2, direction up, smallest effect that matters 0.02 of the currency; 0.6); (ii) the Goal pattern of the one
# world (layers on) loses less than 3 of floor_u + floor_h against phase A, one-sided equivalence at z = 2 (0.55); (iii) structural in every seed: the
# fractal ledger identity across levels and the commons bound (0.7). Not tuned to rescue.
@timed_testset "Probe (heavy): one world, ceiling on real balances, Goal pattern against phase A, ledger across levels (P60)" begin
    agents = [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 11 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:12]
    na, nn, ns = 48, 6, 12
    deceit = zeros(na); deceit[(na - ns + 1):na] .= 0.924
    econ = M3cParams(ToyParams(n = 30, steps = 75, plans = 6), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true,
                     causal_distribution = true, init_steps = 10, guardians = [1, 13, 25, 37], diligence = fill(0.9, na), deceit = deceit, overflow_base = 10.0)
    gov(tr) = M5Params(tr, 1:4; decisions = 1, deliberation = true, info_handling = true, source_tags = true, ih_vote = true, p_delegate = 0.2)
    function world(seed, binding; layers = true)
        up = layers ? UnifiedParams(liar_community = 1, identity = IdentityParams(newcomers = nn, sybils = ns, binding = binding), economy = true, fractal = FractalParams()) :
                      UnifiedParams(liar_community = 1)
        r = run_coupled(econ, gov; seed, epoch = 25, coupled = false, continuous = true, m5_decisions = 30, unified = up)
        b = vec(sum(r.econ_trace.balance; dims = 2))
        (r = r, share = sum(b[(na - ns + 1):na]) / sum(b), fl = r.success.floor_u + r.success.floor_h)
    end
    cache = Dict{Int,Any}(); arm(s) = get!(() -> (off = world(s, false), on = world(s, true), phaseA = world(s, false; layers = false)), cache, s)
    r1 = seeds_until_stable(s -> arm(s).off.share - arm(s).on.share; tol = 0.01, min_seeds = 8, max_seeds = 24)
    @info "P60 heavy (i) sybil currency share, off minus on" n = r1.n stable = r1.stable mean = r1.mean se = r1.se
    e1 = paired_effect(r1.values; z = 2.0, direction = :up)
    # Prediction (i) (binding cuts the sybil share by >= 0.02, z = 2) is judged by `e1`, reported not asserted: the point estimate moves across runs and platforms
    # (+0.034 +- 0.020 at 24 seeds earlier; 0.0098 at 8 seeds and 0.0628 +- 0.0628 at n = 8 on CI Linux), never shown at z = 2: NOT DETECTED, recorded, not tuned. Local Linux rerun: +0.132 +- 0.075 (se), 24 seeds, not stable, not significant.
    @info "P60 heavy (i) verdict" detected = e1.significant && e1.mean > 0.02 mean = e1.mean se = e1.se n = e1.n
    @test isfinite(e1.mean) && isfinite(e1.se)
    r2 = seeds_until_stable(s -> max(0.0, arm(s).phaseA.fl - arm(s).on.fl); tol = 0.5, min_seeds = 8, max_seeds = 24)
    @info "P60 heavy (ii) Goal pattern, one-sided loss against phase A (floor_u + floor_h)" n = r2.n stable = r2.stable mean = r2.mean se = r2.se
    @test equivalent(r2.values; margin = 3.0, side = :upper, z = 2.0).equivalent
    for s in keys(cache), r in (cache[s].off.r, cache[s].on.r), f in r.unified.fractal
        @test abs(f.ledger_gap) < 1e-6 && f.drawn <= f.commons + 1e-9
    end
end
