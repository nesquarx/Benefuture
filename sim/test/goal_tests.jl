# Goal G (L74) through the Lean reference: floors and choice, and the bridge's rebuild rule.

@testset "Bridge: no rebuild when Lean sources are unchanged" begin
    @test BenefutureSim.ensure_lean_lib() === :fresh
    @test HARM_SCHEDULE == [0.9, 0.7, 0.45, 0.15, 0.08, 0.04, 0.01]
end

@testset "Floor quantile: acceptance" begin
    xs = [3.0, 1.0, 2.0, 5.0, 4.0]
    @test floor_quantile(xs, 0.0) == 1.0
    @test floor_quantile(xs, 0.2) == 1.0
    @test floor_quantile(xs, 0.5) == 3.0
    @test floor_quantile(xs, 1.0) == 5.0
    @test floor_quantile([7.0], 0.1) == 7.0
end

@testset "Floor quantile: adversarial and edge cases" begin
    @test floor_quantile(Float64[], 0.1) == 0.0
    # Monotone: raising any level never lowers the floor; lowering never raises it.
    xs = [3.0, 1.0, 2.0, 5.0, 4.0]
    for i in eachindex(xs), q in (0.1, 0.5, 0.9)
        up = copy(xs); up[i] += 1.0
        down = copy(xs); down[i] = -100.0  # removal: the lost life keeps its place at the bottom
        @test floor_quantile(up, q) >= floor_quantile(xs, q)
        @test floor_quantile(down, q) <= floor_quantile(xs, q)
    end
    @test_throws ArgumentError floor_quantile([1.0, NaN], 0.5)
    @test_throws ArgumentError floor_quantile([1.0], 1.5)
end

@testset "Goal choice: acceptance" begin
    z = zeros(3)
    # Inaction alone is chosen.
    @test g_choose([0.0], [0.0], [0.0], [0.0], [0.0]) == 1
    # Highest admissible value wins.
    @test g_choose([0.0, 2.0, 5.0], z, z, z, z) == 3
    # Ties go to the first.
    @test g_choose([1.0, 1.0], zeros(2), zeros(2), zeros(2), zeros(2)) == 1
end

@testset "Goal choice: adversarial and edge cases" begin
    # A plan of greater value that lowers any floor, the peak of U, or reality's scope is not chosen.
    for k in 2:5
        d = [zeros(2) for _ in 1:4]
        d[k - 1][2] = -1e-9
        @test g_choose([0.0, 100.0], d...) == 1
    end
    # No admissible plan: no choice.
    @test g_choose([1.0], [-1.0], [0.0], [0.0], [0.0]) === nothing
    @test_throws ArgumentError g_choose([1.0, 2.0], [0.0], [0.0], [0.0], [0.0])
    @test_throws ArgumentError g_choose([NaN], [0.0], [0.0], [0.0], [0.0])
end
