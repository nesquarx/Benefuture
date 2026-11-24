# Heavy mechanism probes 2 of 3 (full tier: nightly and workflow_dispatch; not in BF_TIER=fast). Moved verbatim from
# probe_tests.jl because each took over 30 s (author: "make sure probes are fast"); claims and bounds unchanged.
# Run all three: julia --project=sim sim/test/probes_heavy.jl. Each still needs a fast smoke version in
# probe_tests.jl (docs/BACKPROPAGATION.md, probe speed).
using Random, Statistics

isdefined(@__MODULE__, Symbol("@timed_testset")) || include(joinpath(@__DIR__, "probe_timing.jl"))


@timed_testset "Probe: progressive capability additions promote better and reject worse (PLAN.md L67, 8.136)" begin
    # Mixed-outcome domain (skill = 0.35, σ_leaf = 0.85) with long enough decay horizon (`acc_halflife = 25.0`)
    # cleanly separates a sharper model class (`size = 0.1`) from coarse noise (`8.136` score-only promotion),
    # while a worse model class (`size = 4.0`) never promotes.
    ag_m = [DomainAgent([0.35, 0.35], [1.0, 0.0], 0.0) for _ in 1:8]
    ag_d = [DomainAgent([0.6, 0.6], [1.0, 0.0], 0.0) for _ in 1:8]
    T = ToyParams(n = 80, steps = 200, plans = 10)
    T_m = ToyParams(n = 80, steps = 240, plans = 10)
    m_kw = (λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
            init_steps = 50, min_records = 10, takeover_records = 20, model_z = 2.0,
            acc_halflife = 25.0, threshold = 0.65, coarse_threshold = 0.65,
            σ_leaf = 0.85, marker_σ = 0.3, bias_σ = 0.0, σ_branch = 0.85, σ_coarse = 0.9)
    # The :record arms are the tuned reference (this world: 24-28/32 promoted by platform, Wilson lo 0.64-0.715, 32 seeds); the :eb arms
    # (the default) must match them, since under :eb model comparison reads raw records, not the claims' shrunk credence (8.165; 30/32, lo 0.795).
    p_good_m = M3cParams(T_m, ag_m, [1, 1], [true, false]; m_kw..., credence_rule = :record,
                         events = [shock(:add_model_class; step = 55, size = 0.1, target = 1)])
    p_bad_m  = M3cParams(T_m, ag_m, [1, 1], [true, false]; m_kw..., credence_rule = :record,
                         events = [shock(:add_model_class; step = 55, size = 4.0, target = 1)])
    p_good_m_eb = M3cParams(T_m, ag_m, [1, 1], [true, false]; m_kw..., credence_rule = :eb,
                            events = [shock(:add_model_class; step = 55, size = 0.1, target = 1)])
    p_bad_m_eb  = M3cParams(T_m, ag_m, [1, 1], [true, false]; m_kw..., credence_rule = :eb,
                            events = [shock(:add_model_class; step = 55, size = 4.0, target = 1)])
    f_kw = (λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
            init_steps = 50, min_records = 10, takeover_records = 15, model_z = 2.0,
            threshold = 0.65, coarse_threshold = 0.65, σ_leaf = 0.35, marker_σ = 0.5, σ_branch = 0.5, σ_coarse = 0.6)
    p_good_f = M3cParams(T_m, ag_d, [1, 1], [true, false]; f_kw...,
                         events = [shock(:add_finer_measurement; step = 55, size = 0.1)])
    p_bad_f  = M3cParams(T_m, ag_d, [1, 1], [true, false]; f_kw...,
                         events = [shock(:add_finer_measurement; step = 55, size = 4.0)])
    d_kw = (λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
            init_steps = 50, min_records = 10, takeover_records = 15, model_z = 3.0,
            threshold = 0.75, σ_leaf = 0.2, marker_σ = 0.2, σ_branch = 0.4, σ_coarse = 0.6)
    p_good_d = M3cParams(T, ag_d, [1, 1], [true, false]; d_kw...,
                         events = [shock(:add_domain; step = 55, target = 2, share = 0.5, size = 1.0)])
    p_bad_d  = M3cParams(T, ag_d, [1, 1], [true, false]; d_kw...,
                         events = [shock(:add_domain; step = 55, target = 2, share = 0.5, size = 10.0)])

    seeds_add = 1:32
    r_gm = [run_m3c(p_good_m; seed = s) for s in seeds_add]
    r_bm = [run_m3c(p_bad_m;  seed = s) for s in seeds_add]
    r_gm_eb = [run_m3c(p_good_m_eb; seed = s) for s in seeds_add]
    r_bm_eb = [run_m3c(p_bad_m_eb;  seed = s) for s in seeds_add]
    r_gf = [run_m3c(p_good_f; seed = s) for s in seeds_add]
    r_bf = [run_m3c(p_bad_f;  seed = s) for s in seeds_add]
    r_gd = [run_m3c(p_good_d; seed = s) for s in seeds_add]
    r_bd = [run_m3c(p_bad_d;  seed = s) for s in seeds_add]

    # Portable claim (CI Linux gave lo 0.64 where this machine gave 0.72): the better class promotes in a clear majority, and far more often than the worse one.
    @test proportion_interval(count(r -> r.added_capabilities[1].promoted, r_gm), length(seeds_add)).lo > 0.5
    @test all(r -> !r.added_capabilities[1].promoted, r_bm)
    # :eb (default): predictors are compared on their raw records (BACKPROPAGATION 8.165), so the credence rule for claims does not mute the
    # sharper class's edge (before: 16/32, lo 0.333); the worse class is still never promoted.
    @test all(r -> !r.added_capabilities[1].promoted, r_bm_eb)
    @test proportion_interval(count(r -> r.added_capabilities[1].promoted, r_gm_eb), length(seeds_add)).lo > 0.5
    @test paired_effect([b.top_scale[1] - g.top_scale[1] for (g, b) in zip(r_gm, r_bm)]; z = 3.0, direction = :up).significant
    @test proportion_interval(count(r -> r.added_capabilities[1].promoted && r.eff_marker_σ < p_good_f.marker_σ, r_gf), length(seeds_add)).lo > 0.7
    @test all(r -> !r.added_capabilities[1].promoted && r.eff_marker_σ == p_bad_f.marker_σ, r_bf)
    @test proportion_interval(count(r -> r.added_capabilities[1].promoted, r_gd), length(seeds_add)).lo > 0.7
    @test proportion_interval(count(r -> !r.added_capabilities[1].promoted, r_bd), length(seeds_add)).lo > 0.8

    # Coupled mid-run rule addition (add_rule_epoch = 3, shadow = true) vs baseline:
    par_timid = copy(bootstrap_params())
    par_timid[1] = 0.25; par_timid[2] = 0.20; par_timid[3] = 0.15; par_timid[4] = 0.05
    par_timid[6] = 1.05; par_timid[7] = 50.0; par_timid[8] = 1.0
    gov(tr) = M5Params(tr, 1:1; decisions = 1, p_delegate = 0.2)
    econ_rule = M3cParams(ToyParams(n = 40, steps = 280, plans = 6), ag_d, [1, 1], [true, false];
                          λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                          init_steps = 5, min_records = 8, threshold = 0.70, model_z = 2.0, endowment = 20.0,
                          converge_init = true, legacy_funder = true)
    rc_none = [run_coupled(econ_rule, gov; seed = s, epoch = 40, continuous = true,
                           incumbent_pv = par_timid, shadow = true) for s in 1:8]
    rc_add  = [run_coupled(econ_rule, gov; seed = s, epoch = 40, continuous = true,
                           incumbent_pv = par_timid, candidate_pv = bootstrap_params(),
                           candidate_prediction = 0.0, candidate_eta = 2, shadow = true, add_rule_epoch = 3) for s in 1:8]
    # a regime over seeds (single seeds are runner-fragile): the share promoted at epoch 5 or later, with its interval
    @test proportion_interval(count(r -> r.shadow_promoted && r.promotion_epoch >= 5 && r.promotion_time >= 2, rc_add), length(rc_add)).lo > 0.5
    @test paired_effect([a.success.floor_u - b.success.floor_u for (a, b) in zip(rc_add, rc_none)]; z = 3.0, direction = :up).significant
end


@timed_testset "Probe: priority weights are meta understanding, sharpened by meta-level research (8.131 continued)" begin
    # Traits world with three things of priority 1, 0.3 and 0.1. Hypotheses (24 paired seeds, 200 steps, z = 2 (t-inflated, the default bar), smallest
    # effect 0.02 on the 0-1+ scale; about 75 s): (a) red baseline: steering practice, research and lessons by a noisy
    # estimate of the priorities (log-normal error 1.5) lowers the floor of understanding (measured on the true
    # priorities) against steering by the truth; (b) meta-level research that halves the estimate's error (chance 5% a
    # step) raises it back toward the truth. Per-seed effects are heavy-tailed (0.00 to 0.24), so 8 seeds at z = 2 sat
    # near the bar and moved with the platform. Measured (Linux): 24 seeds, truth less noisy +0.049 ± 0.014 (z 3.4); meta-research less noisy +0.043 ± 0.013
    # (z 3.4); 40 seeds +0.042 ± 0.011 and +0.038 ± 0.009 (z 4.0). A z = 3 bar would need about 40 seeds (6 minutes), too slow for a probe.
    using Statistics
    floor_at(σ, mr) = [run_m7_traits(seed = s, things = [1.0, 0.3, 0.1], m = 6, steps = 200, weight_σ = σ, meta_research = mr).floor_u[end] for s in 1:24]
    truth, noisy, meta = floor_at(0.0, 0.0), floor_at(1.5, 0.0), floor_at(1.5, 0.05)
    @test paired_effect(truth .- noisy; z = 2.0).significant && mean(truth .- noisy) > 0.02
    @test paired_effect(meta .- noisy; z = 2.0).significant && mean(meta .- noisy) > 0.02
end


# 8.70 / 8.149 / L18 (M5 TN cluster weighted identity binding): compromised TN clusters force
# unweighted count-rule sybil `:per_identity` forks and capture M5 votes (`bind_weighted = false`);
# weighted class-balanced binding zeroes compromised clusters' say once revealed, blocks sybils,
# and defeats pooled easy-majority newcomer camouflage (`1:16` paired seeds, z = 3.0).
@timed_testset "Probe: M5 weighted TN identity binding defeats compromised clusters and newcomer camouflage (8.70)" begin
    w14 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                            [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                             for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    p14(bw) = M5Params(w14, 1:4; decisions = 250, colluders = [1], fork_copies = 150, fork_rule = :per_identity,
                       bind_quorum = 2, bind_clusters = 3, bind_compromised = [1, 2],
                       bind_quorum_weight = 0.5, bind_weighted = bw, p_reveal = 0.1, attest_min_records = 5)
    unw = [run_m5(p14(false); seed = s) for s in 1:16]
    wgt = [run_m5(p14(true);  seed = s) for s in 1:16]
    @test all(r -> r.sybil_forks_blocked == 0 && r.sybil_forks_admitted > 1000, unw)
    @test all(r -> r.attestation_skill[1] < 0 && r.attestation_skill[2] < 0 && r.attestation_skill[3] > 0 &&
                   r.sybil_forks_blocked > r.sybil_forks_admitted, wgt)
    @test paired_effect([a.correct - b.correct for (a, b) in zip(wgt, unw)]; z = 3.0).significant
    @test paired_effect([Float64(b.sybil_forks_admitted - a.sybil_forks_admitted) for (a, b) in zip(wgt, unw)]; z = 3.0).significant

    p15(pooled) = M5Params(w14, 1:4; decisions = 500, colluders = 1:35, fork_copies = 3, fork_rule = :per_identity,
                           bind_quorum = 2, bind_clusters = 5, bind_compromised = [1, 2],
                           bind_quorum_weight = 1.0, bind_weighted = true, attest_pooled = pooled,
                           p_newcomer = 0.9, p_reveal = 0.05, p_sybil_attempt = 0.002, attest_min_records = 5)
    pol = [run_m5(p15(true);  seed = s) for s in 1:32]
    bal = [run_m5(p15(false); seed = s) for s in 1:32]
    @test all(r -> r.attestation_skill[1] > 0 && r.attestation_skill[2] > 0, pol)
    @test all(r -> r.attestation_skill[1] < 0 && r.attestation_skill[2] < 0 && all(r.attestation_skill[3:5] .> 0), bal)
    @test paired_effect([a.correct - b.correct for (a, b) in zip(bal, pol)]; z = 3.0).significant
    @test paired_effect([Float64(b.sybil_forks_admitted - a.sybil_forks_admitted) for (a, b) in zip(bal, pol)]; z = 3.0).significant
    @test mean(r.newcomers_admitted / max(1, r.newcomers_admitted + r.newcomers_refused) for r in bal) >= 0.85
end


@timed_testset "Probe: a candidate is eligible only if its prediction beats the incumbent's record and is judged against its own prediction (8.134 refinement)" begin
    # Re-measured on warmed-up world (`init_steps = 50` + warm-up guard, seeds 1:16):
    # Pre-measurement predictions (53a47c0):
    #   P1 (0.7): harmful L3.2 candidate lowers final floor_u + floor_h vs no candidate, and old ETA 1 no longer beats refinement (`lo`).
    #   P2 (0.8): under `candidate_vs_incumbent`, honest-low (-5) is never adopted and matches `none` within a margin of 5.
    #   P3 (0.8): dishonest-high (10) is adopted, misses at ETA 3, is rejected, with the miss recorded in `prediction_record`.
    #   P4 (0.6): refinement arms' final floors are not significantly below the old rule's (`old`).
    # Metric: `success.floor_u + success.floor_h` of the final run, paired on seeds 1:16. Smallest effect that matters: 5 units.
    # MEASURED (macOS, init_steps = 50 + warm-up guard, seeds 1:16, mean +- se): none 46.29 +- 2.73; old (ETA 1) 33.23 +- 1.10;
    # honest-low (lo) 45.38 +- 2.57; dishonest-high (hi) 23.68 +- 1.12.
    # Outcomes vs P1-P4: P1 HELD (`old - none = -13.07 +- 2.58`, `z = -5.06`; `lo - old = +12.15 +- 2.65`, `z = +4.58`).
    # P2 HELD (`lo` adopted 0/16; `lo - none = -0.91 +- 1.17`, 95% CI `[-3.45, +1.62]`, equivalent within `+-5.0`).
    # P3 HELD (`hi` adopted at epoch 2, rejected at epoch 5 with `calibration == 0.0` in 16/16).
    # P4 SPLIT: `lo` beats `old` (`+12.15, z = +4.58`), whereas `hi` falls below `old` (`old - hi = +9.55 +- 1.27, z = +7.52`) during its 3-epoch ETA.
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
    dL, dON, dLO, dAH = Float64[], Float64[], Float64[], Float64[]
    for s in 1:32
        # Hold incumbent fixed (`add_rule_epoch > n_epochs`) so the no-candidate arm doesn't sample random `gov_δ` perturbations.
        none = run_coupled(econ, gov; seed = s, epoch = 25, continuous = true, add_rule_epoch = 999)
        old = run_coupled(econ, gov; seed = s, epoch = 25, kw...)
        lo = run_coupled(econ, gov; seed = s, epoch = 25, kw..., candidate_prediction = -5.0, candidate_eta = 3, candidate_vs_incumbent = true)
        hi = run_coupled(econ, gov; seed = s, epoch = 25, kw..., candidate_prediction = 10.0, candidate_eta = 3, candidate_vs_incumbent = true)
        @test !none.adopted_candidate[1] && !old.adopted_candidate[1] && !lo.adopted_candidate[1] && !hi.adopted_candidate[1]
        @test !any(lo.adopted_candidate) && isempty(lo.prediction_record) && isnan(lo.prediction_calibration)
        @test any(hi.adopted_candidate) && hi.rejected && hi.rejected_epoch >= 5
        @test length(hi.prediction_record) == 1 && !hi.prediction_record[1].on_track && hi.prediction_calibration == 0.0
        @test hi.prediction_record[1].measured < hi.prediction_record[1].predicted
        push!(dL, tot(lo) - tot(none)); push!(dON, tot(none) - tot(old))
        push!(dLO, tot(lo) - tot(old)); push!(dAH, tot(old) - tot(hi))
    end
    @test paired_effect(dON; z = 3.0, direction = :up).significant     # P1a: old harms warmed-up world vs none (-13.1, z = -5.06)
    @test paired_effect(dLO; z = 3.0, direction = :up).significant     # P1b & P4(lo): lo beats old (+12.2, z = +4.58)
    @test equivalent(dL; margin = 5.0, side = :both).equivalent        # P2: lo matches none within +-5 (-0.91, CI [-3.45, +1.62])
    @test paired_effect(dAH; z = 3.0, direction = :up).significant     # P4(hi): old still exceeds hi miss (+9.55, z = +7.52)
    @test_throws ArgumentError run_coupled(econ, gov; seed = 1, epoch = 25, continuous = true, candidate_vs_incumbent = true)
end


# ==============================================================================
# Probe: harm read through competing measurement chains (8.107)
# ==============================================================================
# Hypothesis: an incumbent chain that counts only half of each loss (last-symptom counting) hides harm
# when its output is consumed alone (measured value above true, the red baseline: harm goes unburned);
# consuming the measurement domain's reading instead (a second chain of another paradigm, divergence
# audits on the shared observable, chains scored against audits) reads outcomes without bias (no harm
# hidden, none double counted: within 0.2 of zero), demotes the under-attributing chain in every seed,
# and then audits only at the spot rate kept while one independent chain remains (under 10% in all). Counterexample: two honest chains are
# never demoted. Measured (3 seeds): bias +3.4 single, −0.01 to −0.03 domain; demoted after 5–11 audits.
@timed_testset "Probe: harm read through competing measurement chains (8.107)" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    ag = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.2) for _ in 1:6]
    w(; kw...) = M3cParams(ToyParams(n = 60, steps = 100, plans = 8), ag, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                           transactions = true, causal_distribution = true, p_side = 0.1, LEGACY..., kw...)
    # Portable restatement (8.138; per-seed "all" claims over 2–3 seeds did not hold on another platform): 8 seeds per arm
    # (16 for honest pairs), about 2 minutes. Regimes are proportions with their Wilson interval (z = 2); biases are paired
    # effects or equivalences at z = 3. Same hypotheses and directions as stated above, with the following metrics and bars.
    # (a) effect: the single incumbent's mean bias is above 0 (z = 3), smallest effect 0.5. Measured +3.25 ± 0.05.
    # (b) equivalence: the domain's mean bias is within ±0.2 of zero (z = 3). Measured +0.01 ± 0.007.
    # (c) regime: the half-counting incumbent is demoted and the honest second chain is not: lower bound above 0.5
    #     (measured 28/32 on ARM64, lo = 0.715); once the lone honest chain stays active (`!chain_demoted[2]`),
    #     spot audits as a share of steps stay under 0.16 (equivalence, upper side, z = 3; measured 0.113, hi = 0.123).
    # (d) regime, UNSUPPORTED AS "never": two honest chains are not demoted in 15 of 16 seeds (seed 4 demoted one); the
    #     claim is a false-demotion rate, asserted as interval upper bound below 0.35 (measured 1 of 16, 0.01–0.29).
    #     Honest pairs are never taken for copies (0 of 16).
    S, S16, S24, S32 = 1:8, 1:16, 1:24, 1:32
    single = [run_m3c(w(chain_attrib = [0.5]); seed) for seed in S]
    domain = [run_m3c(w(chain_attrib = [0.5, 1.0], chain_mode = :domain); seed) for seed in S32]
    honest = [run_m3c(w(chain_attrib = [1.0, 1.0], chain_mode = :domain); seed) for seed in S32]
    @test paired_effect([mean(t.chain_bias) for t in single]; z = 3.0).significant && mean(mean(t.chain_bias) for t in single) > 0.5   # harm hidden
    @test equivalent([mean(t.chain_bias) for t in domain]; margin = 0.2, z = 3.0).equivalent                  # read at its true size
    @test proportion_interval(count(t -> t.chain_demoted == [true, false], domain), length(S32)).lo > 0.5
    @test equivalent([t.chain_audits / length(t.chain_bias) for t in domain if !t.chain_demoted[2]]; margin = 0.16, z = 3.0, side = :upper).equivalent   # demotion, then spot audits at 10% on the one chain left
    @test proportion_interval(count(t -> any(t.chain_demoted), honest), length(honest)).hi < 0.35
    # A wrong majority (two agreeing chains counting half) against a right minority: audits weigh the
    # shared observable, not votes, so both majority chains are demoted. Regime, 8 seeds: both demoted and the
    # right one kept in 7 of 8 (seed 3 demoted all three); bar: lower bound above 0.5.
    majority = [run_m3c(w(chain_attrib = [0.5, 0.5, 1.0], chain_mode = :domain); seed) for seed in S]
    @test proportion_interval(count(t -> t.chain_demoted == [true, true, false], majority), length(S)).lo > 0.5
    # A subtle bias (10% of each loss) is caught too, later. Regime, 8 seeds: biased chain demoted, honest one kept in 8 of 8.
    subtle = [run_m3c(w(chain_attrib = [1.0, 0.9], chain_mode = :domain); seed) for seed in S]
    @test proportion_interval(count(t -> t.chain_demoted == [false, true], subtle), length(S)).lo > 0.5
    # A fake second paradigm: the biased chain plus an undeclared copy of it agree, so nothing diverges
    # and, undetected, the harm stays hidden (measured +3.05 to +3.45 in 8 seeds). Agreement far closer than
    # independent noise allows exposes the copy; with one independent chain left the domain degrades
    # loudly to spot audits, which demote the biased chain (copy found and incumbent demoted in 8 of 8 seeds),
    # and the bias falls to 0.3–1.8 (the rest accrues before detection): effect, undetected less detected above 0
    # at z = 3 and detected mean below 60% of undetected; honest pairs are never taken for copies (0 of 16).
    undetected = [run_m3c(w(chain_attrib = [0.5, 0.5], chain_copy = [0, 1], chain_mode = :domain, chain_detect = false); seed) for seed in S]
    detected = [run_m3c(w(chain_attrib = [0.5, 0.5], chain_copy = [0, 1], chain_mode = :domain); seed) for seed in S]
    @test paired_effect([mean(t.chain_bias) for t in undetected]; z = 3.0).significant && mean(mean(t.chain_bias) for t in undetected) > 2.5
    @test proportion_interval(count(t -> t.chain_copied == [false, true] && t.chain_demoted[1], detected), length(S)).lo > 0.5
    ub, db = [mean(t.chain_bias) for t in undetected], [mean(t.chain_bias) for t in detected]
    @test paired_effect(ub .- db; z = 3.0).significant && mean(db) < 0.6 * mean(ub)
    @test proportion_interval(count(t -> any(t.chain_copied), honest), length(honest)).hi < 0.35
    # Looking agreeable (8.107): a second chain reporting 60% of the incumbent's reading in place of its own stays
    # too close to diverge quickly and too far for the variance test to take it for a copy. Its errors on audited
    # outcomes are shared with the incumbent's, so the shared-error rule (Lean `coerror_copy_ref`) folds it as a copy
    # and the incumbent is demoted (20 of 24 measured on ARM64); hidden bias still accrues first (+0.43 to +1.64 per outcome, against
    # +0.7 to +1.7 without the rule: not a significant reduction). Spot audits even when chains agree
    # (5%) did not shorten it and once demoted an honest chain, so they stay off.
    # An honest chain left alone after the incumbent's demotion carries a non-zero false-demotion rate: its spot-audit
    # test is re-run at every audit, so the bar grows with the looks (Lean `sequential_significant_ref`); over 32 seeds
    # the lone honest chain stays active in 28/32 on ARM64 (Wilson lo = 0.715, bar 0.6).
    lone = [t.chain_demoted[2] for t in domain]
    @test proportion_interval(count(!, lone), length(lone)).lo > 0.6
    agreeable = [run_m3c(w(chain_attrib = [0.5, 1.0], chain_mode = :domain, chain_shade = [0.0, 0.6]); seed) for seed in S24]
    # With the sequential bar (Lean `sequential_significant_ref`) at 10% spot audits over 24 seeds, effect:
    # bias above 0.2 at z = 3 (0.78 ± 0.10 on ARM64, z = 3.17); regime: incumbent demoted and the second folded as a copy
    # (20/24 on ARM64, Wilson lo = 0.637 > 0.5).
    @test paired_effect([mean(t.chain_bias) - 0.2 for t in agreeable]; z = 3.0).significant
    @test proportion_interval(count(t -> t.chain_demoted[1] && t.chain_copied[2], agreeable), length(S24)).lo > 0.5
end


# 8.133, 8.153 & 8.155 (L83 `Δ↑(U, H) / ↓(Cost + Audit)`): RA estimating domain, cross-domain allocation,
# commons reserve provisioning for progressive-complexity fallbacks, and contraction of baseline pricing & spending.
@timed_testset "Probe: RA estimating domain allocation (L83; 8.133, 8.153, 8.155)" begin
    # High-yield low-audit domain (leaf 1) vs lower-yield high-audit domain (leaf 2) under scarce budgeted capacity.
    # RA estimates Δ(U,H)/(Cost+Audit) online (`ra_unit_value`, `ra_audit_per_step`), reallocates scarce capacity
    # (`ra_alloc_weight`), and lifts understanding floor at z >= 3.0 (`1:16` paired seeds).
    ag10 = [DomainAgent([0.9, 0.15], [0.5, 0.5], 0.0) for _ in 1:6]
    p10(ra_on, aud1) = M3cParams(ToyParams(n = 30, steps = 160, plans = 12), ag10, [1, 1], trues(2);
                                  λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                                  init_steps = 20, budget = true, endowment = 100.0, capacity = 50.0, regen = 0.25,
                                  cost_per_touch = 0.2, ra_domain = true, ra_alloc_weight = ra_on ? 1.0 : 0.0,
                                  ra_audit_per_step = [aud1, 4.0], LEGACY...)
    off10 = [run_m3c(p10(false, 0.0); seed = s) for s in 1:16]
    on10  = [run_m3c(p10(true,  0.0); seed = s) for s in 1:16]
    hi10  = [run_m3c(p10(true, 10.0); seed = s) for s in 1:16]
    @test paired_effect([r.ra_unit_value[1] - r.ra_unit_value[2] for r in on10]; z = 3.0).significant
    @test paired_effect([a.ra_unit_value[1] - b.ra_unit_value[1] for (a, b) in zip(on10, hi10)]; z = 3.0).significant
    @test all(r -> r.ra_audit_costs > 0 && r.ra_alloc[1] > r.ra_alloc[2], on10)
    @test paired_effect([count(==(1), a.true_leaf) / length(a.true_leaf) - count(==(1), b.true_leaf) / length(b.true_leaf)
                         for (a, b) in zip(on10, off10)]; z = 3.0).significant
    @test paired_effect([success_pattern(a; from = 21).floor_u - success_pattern(b; from = 21).floor_u
                         for (a, b) in zip(on10, off10)]; z = 3.0).significant
    @test paired_effect([sum(a.valued_measured) - sum(b.valued_measured) for (a, b) in zip(on10, off10)]; z = 3.0).significant
end


# ==============================================================================
# Probe: repeated deception meets an escalating ratchet (8.91, Brief L2.2)
# ==============================================================================
@timed_testset "Probe: repeated deception meets an escalating ratchet (8.91)" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    selected_act(tr, a) = count(==(a), tr.exec_agent)
    peers_act(tr) = mean(selected_act(tr, a) for a in 1:5)

    ww_params = ToyParams(n = 80, steps = 200, plans = 10)
    agents = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6]
    # On-off cycles: bad phases at 26..50, 76..100, 126..150; deceit stops from step 151
    bad_events = [shock(:breakthrough; step = 26, duration = 25, size = -1.0, target = 6),
                  shock(:breakthrough; step = 76, duration = 25, size = -1.0, target = 6),
                  shock(:breakthrough; step = 126, duration = 25, size = -1.0, target = 6)]

    p_onoff = M3cParams(ww_params, agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                        transactions = true, causal_distribution = true, deceit = [0, 0, 0, 0, 0, 1.0],
                        events = bad_events, on_off = 25, advap = true, LEGACY...)
    p_honest = M3cParams(ww_params, agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                         transactions = true, causal_distribution = true, deceit = Float64[],
                         events = bad_events, on_off = 25, advap = true, LEGACY...)

    runs_onoff = [run_m3c(p_onoff; seed = s) for s in 1:2]
    runs_honest = [run_m3c(p_honest; seed = s) for s in 1:2]

    # The deceiver's upfront credence per executed action (escrow paid upfront over the plan's value;
    # upfront = share × credence × value), by phase.
    function phase_cred(tr, w)
        i = [k for k in eachindex(tr.exec_agent) if tr.exec_agent[k] == 6 && tr.exec_step[k] in w && tr.exec_pred[k] > 0]
        isempty(i) ? NaN : mean(tr.exec_upfront[i] ./ tr.exec_pred[i])
    end
    # (i) Author ruling on 8.91: discovered deception is permanent and escrow rises exponentially in its
    # count, so the upfront credence falls from the second bad phase to the third, and stays down after
    # the deceiver stops (measured: seed 1 0.40, 0.31, then 0.17; seed 2 0.49, 0.25, 0.18 at growth 0.5).
    # Against the flat ledger ratchet (growth 0) on the same seeds, the escalating one leaves the deceiver a
    # lower upfront credence in the third bad phase (a comparison, portable across platforms; single-seed
    # trajectories are not).
    flat = [run_m3c(M3cParams(ww_params, agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true,
                              causal_distribution = true, deceit = [0, 0, 0, 0, 0, 1.0], events = bad_events, on_off = 25,
                              advap = true, ratchet_growth = 0.0, LEGACY...); seed = s) for s in 1:2]
    @test all(phase_cred(runs_onoff[s], 126:150) < phase_cred(flat[s], 126:150) for s in 1:2)
    @test all(phase_cred(tr, 126:150) < phase_cred(tr, 76:100) && phase_cred(tr, 151:200) < phase_cred(tr, 76:100) for tr in runs_onoff)
    @test all(tr.deceptions[6] >= 1 for tr in runs_onoff)
    # (ii) Peers' activity: measurement discounts an established deception's outcomes (author ruling on
    # 8.91), so the fooled records no longer drag the domain's model below its bar and the currency stays
    # up for everyone (seed 1: 194 against 197 honest; 79 before the discount).
    @test all(peers_act(runs_onoff[s]) >= 0.8 * peers_act(runs_honest[s]) for s in 1:2)

    # Counterexample (iv): honest agent with high variance (skill 0.6, sloppiness high 0.5, no deceit)
    agents_iv = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], a == 6 ? 0.5 : 0.0) for a in 1:6]
    p_iv = M3cParams(ww_params, agents_iv, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                     transactions = true, causal_distribution = true, deceit = Float64[],
                     advap = true, LEGACY...)
    tr_iv = [run_m3c(p_iv; seed = s) for s in 1:2]
    # High variance honest agent remains actively selected (> 150 actions over 200 steps)
    @test all(selected_act(t, 6) > 150 for t in tr_iv)
    @test all(t.deceptions[6] == 0 for t in tr_iv)   # bad luck is never established as deception

    # Counterexample (v): honest agent with isolated mistakes (single transient breakthrough shock, no deceit)
    events_v = [shock(:breakthrough; step = 50, duration = 10, size = -1.0, target = 6)]
    p_v = M3cParams(ww_params, agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                    transactions = true, causal_distribution = true, deceit = Float64[],
                    events = events_v, advap = true, LEGACY...)
    tr_v = [run_m3c(p_v; seed = s) for s in 1:2]
    # Isolated mistakes agent remains actively selected (> 140 actions over 200 steps)
    @test all(selected_act(t, 6) > 140 for t in tr_v)
    @test all(t.deceptions[6] == 0 for t in tr_v)    # nor are isolated honest mistakes

    # Counterexample (vi): agent that deceived then stopped returns to active participation
    @test all(selected_act(tr, 6) > 25 for tr in runs_onoff)
end


# ==============================================================================
# Probe: understanding aggregates across things by priority (ruling 8.117)
# ==============================================================================
# Hypotheses (6 seeds): (a) with two things weighted by predicted long-term contribution (1.0 and 0.1),
# effort follows priority: the high-priority thing's understanding grows more (z = 3; measured 0.57 vs 0.41);
# (b) opening new things (novelty weight) costs no peak understanding when effort is allocated by goal
# weight (equivalent to the closed world within 0.1; measured 0.90 vs 0.91 at 240 steps).
@timed_testset "Probe: understanding aggregates across things by priority (8.117)" begin
    seeds = 1:6
    a = [run_m7_traits(seed = s, things = [1.0, 0.1]) for s in seeds]
    @test paired_effect([t.thing_gain[1] - t.thing_gain[2] for t in a]; z = 3.0).significant
    op = [run_m7_traits(seed = s, max_new_things = 4, p_new_thing = 0.3, steps = 240) for s in seeds]
    cl = [run_m7_traits(seed = s, steps = 240) for s in seeds]
    @test all(t -> t.new_things == 4, op)
    @test equivalent([o.peak_u[end] - c.peak_u[end] for (o, c) in zip(op, cl)]; margin = 0.1).equivalent   # measured −0.01, interval ±0.05
end


@timed_testset "Probe: Di_N_Balance raises novelty bonus on monoculture, bounds false triggers, and penalizes fake novelty (L159; 8.140, 8.147)" begin
    # Hypotheses (32 paired seeds for M5 diversity, 16 paired seeds for outcome-settled fake novelty):
    # 1. Trigger fires & restores (8.147): when monoculture (wrong consensus under zero `novelty_bonus`
    #    at conviction = 2.4, p_apparent = 0.4) locks decisions, Di_N_Balance detects low variety and raises `novelty_bonus`
    #    (0.0 -> 0.9), increasing alternative take-up (`chosen_share`) and restoring `correct_after_hidden`
    #    and overall `correct_after` (z = 3; 9.2σ–24.6σ across 8 tested `m3_div` seeds).
    # 2. Noise-made false trigger costs bounded amount: on an already right consensus (`colluders = Int[]`),
    #    raising `novelty_bonus` keeps `correct_after` within ±0.02 (z = 3; worst bound ±0.0105 across 8 `m3_div` seeds).
    # 3. Gamed trigger pays less than honesty (8.140): manufacturing worthless/harmful "novel" plans
    #    (skill = -0.3) instead of honest work (skill = 0.6) yields strictly lower standing (z = 3).
    m3_div = run_m3c(M3cParams(ToyParams(n = 30, steps = 80, plans = 6),
                               [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 7 : 0.0 for l in 1:4],
                                            [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:8],
                               [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    bloc = unique(vcat([sortperm(m3_div.relevance_leaf[:, d]; rev = true)[1:4] for d in 1:4]...))
    S32 = 1:32
    S16 = 1:16
    mono_lo = [run_m5(M5Params(m3_div, 1:4; decisions = 300, colluders = bloc, p_delegate = 0.8, p_apparent = 0.4,
                               stealth = true, diversity = true, novelty_bonus = 0.0, conviction = 2.4); seed = s) for s in S32]
    mono_hi = [run_m5(M5Params(m3_div, 1:4; decisions = 300, colluders = bloc, p_delegate = 0.8, p_apparent = 0.4,
                               stealth = true, diversity = true, novelty_bonus = 0.9, conviction = 2.4); seed = s) for s in S32]
    @test paired_effect([mean(h.chosen_share) - mean(l.chosen_share) for (h, l) in zip(mono_hi, mono_lo)];
                        z = 3.0, direction = :up).significant
    @test paired_effect([h.correct_after_hidden - l.correct_after_hidden for (h, l) in zip(mono_hi, mono_lo)];
                        z = 3.0, direction = :up).significant
    @test paired_effect([h.correct_after - l.correct_after for (h, l) in zip(mono_hi, mono_lo)];
                        z = 3.0, direction = :up).significant

    calm_lo = [run_m5(M5Params(m3_div, 1:4; decisions = 300, p_delegate = 0.8,
                               diversity = true, novelty_bonus = 0.0, conviction = 2.4); seed = s) for s in S32]
    calm_hi = [run_m5(M5Params(m3_div, 1:4; decisions = 300, p_delegate = 0.8,
                               diversity = true, novelty_bonus = 0.9, conviction = 2.4); seed = s) for s in S32]
    @test equivalent([h.correct_after - l.correct_after for (h, l) in zip(calm_hi, calm_lo)];
                     margin = 0.02, z = 3.0, side = :both).equivalent

    # Case 3: Manufactured novelty (harmful agent claiming novelty under outcome settlement) pays less than honest twin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    ag_honest = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6]
    ag_fake   = [[DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:5];
                  DomainAgent([-0.3, 0, 0, 0], [1.0, 0, 0, 0], 0.0)]
    cfg_n(ag) = M3cParams(ToyParams(n = 30, steps = 120, plans = 6), ag, [1, 1, 2, 2], trues(4);
                          λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                          explore_share = 0.2, advap = true, LEGACY...)
    stand(tr, a) = sum(tr.balance[a, :]) + tr.overflow_agent[a]
    hn_runs = [run_m3c(cfg_n(ag_honest); seed = s) for s in S16]
    fk_runs = [run_m3c(cfg_n(ag_fake);   seed = s) for s in S16]
    @test paired_effect([stand(f, 6) - stand(h, 6) for (f, h) in zip(fk_runs, hn_runs)];
                        z = 3.0, direction = :down).significant
end

probe_total("heavy 2")
