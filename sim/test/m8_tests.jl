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
    finite = run_m8(M8Params(mode = :finite_no_legacy, seed = 7))
    bf = run_m8(M8Params(mode = :bf, seed = 7))
    @test one_shot.defect_rate > bf.defect_rate
    @test finite.eol_excess > bf.eol_excess
end

