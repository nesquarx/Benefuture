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
