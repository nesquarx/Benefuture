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

@testset "Tail floor (Spike D1): acceptance and adversarial cases" begin
    @test tail_floor(Float64[], 0.1) == 0.0
    xs = [3.0, 1.0, 2.0, 5.0, 4.0]
    @test tail_floor(xs, 0.0) == 1.0
    @test tail_floor(xs, 0.4) ≈ 1.5
    @test tail_floor(xs, 1.0) ≈ 3.0
    # Non-sadism: any negative life pulls tail_floor below 0 regardless of how many high lives exist.
    @test tail_floor([100.0, 100.0, 100.0, 100.0, -5.0, -5.0, -5.0], 0.1) ≈ -15.0
    @test tail_floor([100.0, 100.0, 1.0, 1.0, 1.0], 0.1) > 0.0
    @test tail_floor([10.0, -2.0], 0.1) ≈ -2.0
    for i in eachindex(xs), q in (0.0, 0.2, 0.5, 1.0)
        up = copy(xs); up[i] += 1.0
        down = copy(xs); down[i] = -10.0
        @test tail_floor(up, q) >= tail_floor(xs, q)
        @test tail_floor(down, q) <= tail_floor(xs, q)
    end
    @test_throws ArgumentError tail_floor([1.0, NaN], 0.5)
    @test_throws ArgumentError tail_floor([1.0], 1.5)
end

@testset "Lexical Fr goal choice (Spike D3): acceptance and adversarial cases" begin
    z = zeros(3)
    # Stage 1 blocks higher-value Fr-violator when inaction (or any Fr-permissible G-admissible plan) exists.
    @test g_choose_lexical_fr([0.0, 1000.0, 5.0], z, z, z, z, [true, false, true]) == (3, false)
    @test g_choose_lexical_fr([0.0, 1000.0], zeros(2), zeros(2), zeros(2), zeros(2), [true, false]) == (1, false)
    # Ties go to the first in Stage 1.
    @test g_choose_lexical_fr([1.0, 2.0, 2.0], z, z, z, z, [true, true, true]) == (2, false)
    # Tragic-choice / omission-catastrophe Stage 2 fallback: no plan clears Stage 1 -> falls back with degraded = true.
    @test g_choose_lexical_fr([0.0, 10.0, 5.0], z, z, z, z, [false, false, false]) == (2, true)
    # No G-admissible plan anywhere -> (nothing, true).
    @test g_choose_lexical_fr([1.0, 2.0], [-1.0, -1.0], zeros(2), zeros(2), zeros(2), [false, false]) == (nothing, true)
    # G-inadmissible Fr-permissible plan does not block fallback when no plan is both G-admissible and Fr-permissible.
    @test g_choose_lexical_fr([0.0, 10.0], [0.0, -1.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [false, true]) == (1, true)
    @test_throws ArgumentError g_choose_lexical_fr([1.0, 2.0], [0.0], [0.0], [0.0], [0.0], [true, true])
    @test_throws ArgumentError g_choose_lexical_fr([1.0], [0.0], [0.0], [0.0], [0.0], [true, true])
    @test_throws ArgumentError g_choose_lexical_fr([NaN], [0.0], [0.0], [0.0], [0.0], [true])
end
