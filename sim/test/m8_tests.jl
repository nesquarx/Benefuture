using BenefutureSim
using Test
using Statistics

@testset "M8 rules: extended-self feedback, propagated liability & end-of-horizon score" begin
    # 1. Extended-self feedback (`Morality.lean`, L136):
    @test extended_self_feedback(Float64[], Float64[]) == 0.0
    @test extended_self_feedback([0.0, -0.4], [-5.0, -2.0]) == 0.0
    @test extended_self_feedback([0.5, 1.5], [-4.0, -2.0]) ≈ -4.0   # 0.5*(-4) + 1.0*(-2)
    @test extended_self_feedback([0.25, 0.75], [8.0, -4.0]) ≈ -1.0
    @test_throws ArgumentError extended_self_feedback([0.5], [1.0, 2.0])
    @test_throws ArgumentError extended_self_feedback([NaN], [1.0])
    @test_throws ArgumentError extended_self_feedback([0.5], [Inf])

    # 2. Multi-hop propagated influence liability (`Entity.lean`, L8, 7.14):
    @test propagated_liability(0.0, [0.8, 0.8]) == 0.0
    @test propagated_liability(-5.0, [0.8, 0.8]) == 0.0
    @test propagated_liability(10.0, Float64[]) ≈ 10.0
    @test propagated_liability(10.0, [0.5, 0.5]) ≈ 2.5
    @test propagated_liability(10.0, [1.5, 0.4, -0.2]) == 0.0
    @test propagated_liability(10.0, [0.5, 0.6, 0.5]) < propagated_liability(10.0, [0.5, 0.6])
    @test_throws ArgumentError propagated_liability(NaN, [0.5])
    @test_throws ArgumentError propagated_liability(10.0, [0.5, Inf])

    # 3. End-of-horizon consequential score (`B25`, `7.12`):
    alive_s = end_of_horizon_score(5.0, true, [0.5], [-4.0];
                                   causal_share = 0.5, delayed_outcome = 6.0,
                                   ideological_share = 0.25, ideological_gain = 4.0)
    dead_s = end_of_horizon_score(5.0, false, [0.5], [-4.0];
                                  causal_share = 0.5, delayed_outcome = 6.0,
                                  ideological_share = 0.25, ideological_gain = 4.0)
    @test alive_s ≈ 7.0
    @test dead_s ≈ 2.0
    # After lifespan ends, direct ownRemaining cannot rescue defection harm across extended self
    @test end_of_horizon_score(999.0, false, [0.5], [-6.0];
                               causal_share = 0.5, delayed_outcome = -2.0,
                               ideological_share = 0.3, ideological_gain = -1.0) ≈ -4.3
    @test_throws ArgumentError end_of_horizon_score(NaN, true, [0.5], [1.0])
    @test_throws ArgumentError end_of_horizon_score(1.0, true, [0.5], [1.0, 2.0])

    # 4. Prediction-time horizon & extended self past predicted death (`7.12`, `B25`):
    # `immediate_own` stays at choice time; predicted `future_own` drops when `alive_at_outcome = false`,
    # while extended-self harm predicted on community after death still lowers score strictly below `immediate_own`.
    pred_dead_ext = end_of_horizon_predicted_score(2.0, 5.0, false, [0.6], [-5.0])
    pred_alive_ext = end_of_horizon_predicted_score(2.0, 5.0, true, [0.6], [-5.0])
    @test pred_dead_ext ≈ -1.0
    @test pred_dead_ext < 2.0
    @test pred_alive_ext ≈ 4.0
    @test end_of_horizon_predicted_score(2.0, 99.0, false, [0.6], [-5.0]) ≈ pred_dead_ext
    @test_throws ArgumentError end_of_horizon_predicted_score(NaN, 1.0, false, [0.5], [1.0])
    @test_throws ArgumentError end_of_horizon_predicted_score(1.0, 1.0, false, [0.5], [1.0, 2.0])

    # 5. InfoHazard access risk (`L127`, `B21`):
    @test ihz_access_risk(1.0, 1.0; potential_harm = 5.0) == 0.0
    @test ihz_access_risk(1.5, 1.0; potential_harm = 5.0) == 0.0
    @test ihz_access_risk(0.8, 1.0; potential_harm = 5.0) ≈ 5.0
    @test ihz_access_risk(0.8, 1.0; potential_harm = -2.0) == 0.0
    @test_throws ArgumentError ihz_access_risk(NaN, 1.0; potential_harm = 5.0)
    @test_throws ArgumentError ihz_access_risk(0.5, 1.0; potential_harm = Inf)

    # 6. Art reception match & surplus value (`7.13`, `L126-L127`):
    @test art_success_score([0.45, 0.10, 0.45], [0.45, 0.10, 0.45]) ≈ 1.0
    @test art_success_score([0.45, 0.10, 0.45], [0.0, 1.0, 0.0]) ≈ 0.10
    @test art_success_score([1.0, 0.0], [0.0, 1.0]) == 0.0
    @test art_surplus_value(0.8, 0.6) ≈ 1.4
    @test art_surplus_value(-0.5, 0.6) ≈ 0.6
    @test_throws ArgumentError art_success_score([0.5], [0.5, 0.5])
    @test_throws ArgumentError art_success_score([NaN], [1.0])
    @test_throws ArgumentError art_surplus_value(NaN, 0.5)
end

@testset "M8 world invariants: B25 zero financial inheritance, posthumous attribution & power dispersion" begin
    # Exact zero property inheritance even across 200 steps (5 generations per slot)
    tr = run_m8(M8Params(steps = 200, lifespan = 30, mode = :bf, seed = 42))
    @test tr.inherited_wealth == 0.0
    @test tr.posthumous_cd_events > 20
    @test tr.posthumous_re_updates == tr.posthumous_cd_events
    @test tr.overflow_total > 0.0

    # Pure structural response to coupling removal & finite-horizon truncation
    one_shot = run_m8(M8Params(mode = :one_shot, seed = 7))
    ext_only = run_m8(M8Params(mode = :extended_only, seed = 7))
    finite = run_m8(M8Params(mode = :finite_no_legacy, seed = 7))
    bf = run_m8(M8Params(mode = :bf, seed = 7))
    @test one_shot.defect_rate > bf.defect_rate
    @test finite.eol_excess > bf.eol_excess
    @test finite.eol_excess > ext_only.eol_excess

    # IHz gating eliminates uninoculated exposure risk without censoring legitimate research
    gated = run_m8_ihz(M8IhzParams(mode = :gated_ihz, seed = 7))
    open_u = run_m8_ihz(M8IhzParams(mode = :open_ungated, seed = 7))
    cens = run_m8_ihz(M8IhzParams(mode = :censored, seed = 7))
    @test gated.accidental_harm == 0.0
    @test open_u.accidental_harm > 0.0
    @test cens.useful_access == 0.0
    @test gated.useful_access > cens.useful_access

    # Art spread separation & Di_N cultural monoculture escape
    art = run_m8_art(M8ArtParams(seed = 7))
    @test art.dist_open > art.dist_blank
    @test art.orig_surplus > art.prop_surplus
    @test art.orig_surplus > art.forg_surplus
    c_mono = run_m8_culture(M8CultureParams(mode = :no_diversity_bonus, seed = 7))
    c_div = run_m8_culture(M8CultureParams(mode = :bf_culture, seed = 7))
    @test c_div.monoculture_share < c_mono.monoculture_share
    @test c_div.mean_culture_value > c_mono.mean_culture_value
end

