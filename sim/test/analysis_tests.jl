# Trace analysis: running means, settling steps and between-seed spread.

@testset "Analysis: acceptance" begin
    @test running_mean([1.0, 3.0, 5.0]) == [1.0, 2.0, 3.0]
    # The running mean of a constant series settles at once.
    @test settling_step(fill(2.0, 10); tol = 0.01) == 1
    # A series that jumps late settles only after the jump has been averaged in enough.
    xs = [zeros(50); ones(50)]
    s = settling_step(xs; tol = 0.05)
    @test 90 <= s <= 100
    # Spread across seeds: the half-width of a 95% interval for the mean.
    @test ci_halfwidth([1.0, 1.0, 1.0]) == 0.0
    @test ci_halfwidth([0.0, 2.0]) ≈ 1.96 * 1.0 atol = 1e-12
    @test spearman([1.0, 2.0, 3.0], [10.0, 40.0, 90.0]) ≈ 1.0
    @test spearman([1.0, 2.0, 3.0], [3.0, 2.0, 1.0]) ≈ -1.0
end

@testset "Analysis: adversarial and edge cases" begin
    @test running_mean(Float64[]) == Float64[]
    @test_throws ArgumentError settling_step(Float64[]; tol = 0.1)
    @test_throws ArgumentError settling_step([1.0]; tol = -0.1)
    @test_throws ArgumentError settling_step([NaN, 1.0]; tol = 0.1)
    @test_throws ArgumentError ci_halfwidth([1.0])
    # Settling is judged on the running mean, so a single late spike does not unsettle a long series.
    xs = [ones(999); 10.0]
    @test settling_step(xs; tol = 0.05) == 1
    # A final mean of zero needs an absolute tolerance to settle before the end.
    @test settling_step([1.0, -1.0, 0.0, 0.0]; tol = 0.1, atol = 0.6) == 2
end

@testset "Goal success pattern (L74)" begin
    # Floors and medians of U and H, the peak of U, how often each fell, and harm's peak.
    tr = (floor_u = [0.0, 1.0, 0.5, 2.0], floor_h = [0.0, 1.0, 2.0, 3.0], median_u = [1.0, 2.0, 3.0, 4.0],
          median_h = [1.0, 1.0, 1.0, 2.0], peak_u = [5.0, 6.0, 5.5, 7.0], worst_drop = [0.0, 0.5, 2.0, 0.1])
    sp = success_pattern(tr)
    @test sp.floor_u == 2.0 && sp.median_h == 1.0 && sp.peak_u == 2.0 && sp.worst_drop == 2.0
    @test sp.peak_u_falls ≈ 1 / 3 && sp.floor_u_falls ≈ 1 / 3 && sp.floor_h_falls == 0.0
    @test success_pattern(tr; from = 3).floor_u == 1.5
    @test_throws ArgumentError success_pattern(tr; from = 4)
end

@testset "SimTrace and Conj_* checks (`Benefuture/Systems/Conjectures.lean`)" begin
    pv = bootstrap_params()
    pv2 = copy(pv); pv2[1] += 0.005
    tr_good = SimTrace(
        params = [pv, pv2, pv2],
        min_u = [1.0, 1.5, 2.2],
        min_h = [1.0, 1.4, 2.0],
        median_u = [2.0, 2.5, 3.1],
        median_h = [2.0, 2.4, 3.0],
        aggregate_value = [1.2, 1.5],
        reality_scope = [10.0, 10.5, 11.0],
        adversary_share = 0.2,
        adopted_mm_accuracy = [0.70, 0.88, 0.91],
        best_mm_accuracy = [0.85, 0.90, 0.92],
        latent_obs_gap = [0.40, 0.30, 0.20],
        exploit_payoff = [1.0, 0.5, 0.0],
        reveal_payoff = [2.5, 2.0, 1.5],
        predicted_min_u_gain = [0.5, 0.7],
        realised_min_u_gain = [0.48, 0.68],
        max_delegate_share = [0.04, 0.05, 0.05],
        mean_h = [2.0, 2.3, 2.7],
    )
    @test conj_mm_competition_converges(tr_good; ε = 0.05, from_step = 2)
    @test conj_goodhart_reduction(tr_good; w = 1)
    @test conj_gaming_resistance(tr_good)
    @test conj_adversarial_robustness(tr_good; f_star = 0.5)
    @test conj_min_tracks_prediction(tr_good; η = 0.1)
    @test conj_floors_rise(tr_good; w = 1)
    @test conj_no_repugnant_drift(tr_good; w = 1, ε = 0.05)
    @test conj_param_stability(tr_good; ε = 0.02, from_step = 1)
    @test conj_delegation_dispersed(tr_good; margin = 0.01)

    # Counterexamples: each conjecture rejects a violating trace
    tr_bad = SimTrace(
        params = [pv, (p3 = copy(pv); p3[1] += 0.25; p3)],
        min_u = [2.0, 1.0],
        min_h = [2.0, 1.0],
        aggregate_value = [-0.5],
        reality_scope = [10.0, 9.0],
        adversary_share = 0.2,
        adopted_mm_accuracy = [0.50, 0.50],
        best_mm_accuracy = [0.90, 0.90],
        latent_obs_gap = [0.20, 0.50],
        exploit_payoff = [5.0],
        reveal_payoff = [1.0],
        predicted_min_u_gain = [1.0],
        realised_min_u_gain = [0.0],
        max_delegate_share = [0.40, 0.40],
        mean_h = [3.0, 2.0],
    )
    @test !conj_mm_competition_converges(tr_bad; ε = 0.05, from_step = 1)
    @test !conj_goodhart_reduction(tr_bad; w = 1)
    @test !conj_gaming_resistance(tr_bad)
    @test !conj_adversarial_robustness(tr_bad; f_star = 0.5)
    @test !conj_min_tracks_prediction(tr_bad; η = 0.1)
    @test !conj_floors_rise(tr_bad; w = 1)
    @test !conj_no_repugnant_drift(tr_bad; w = 1, ε = 0.05)
    @test !conj_param_stability(tr_bad; ε = 0.02, from_step = 1)
    @test !conj_delegation_dispersed(tr_bad; margin = 0.01)
end
