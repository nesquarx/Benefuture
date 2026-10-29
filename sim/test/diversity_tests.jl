# The split trial (author rulings 8.30, 8.22.3; L158 Di_N_Balance): options tried side by side on
# shares of a scope (locales, domains), each unit's outcome measured with noise, compared by the
# Lean significance rule (`select_candidate`). Reusable wherever alternatives are tried: decisions
# (M5), debatable thresholds (M4), the pre-N sample.

@testset "Split trial: acceptance" begin
    r = Xoshiro(1)
    # A large difference over many units: the better alternative wins, significantly.
    t = split_trial(r, [0.0, 1.0], [0.5, 0.5]; units = 100, σ = 1.0, z = 2.0)
    @test t.winner == 2 && t.significant
    # The incumbent better: it stays, and the trial says so significantly.
    t = split_trial(r, [1.0, 0.0], [0.9, 0.1]; units = 200, σ = 1.0, z = 2.0)
    @test t.winner == 1 && t.significant
    # No difference: rarely significant.
    @test count(split_trial(r, [0.0, 0.0], [0.9, 0.1]; units = 100, σ = 1.0, z = 2.0).significant for _ in 1:200) < 20
end

@testset "Split trial: adversarial and edge cases" begin
    r = Xoshiro(2)
    # Too few units on a side to compare: nothing is significant.
    @test !split_trial(r, [0.0, 5.0], [0.99, 0.01]; units = 50, σ = 1.0, z = 2.0).significant
    @test_throws ArgumentError split_trial(r, [0.0, 1.0], [0.6, 0.6]; units = 10, σ = 1.0, z = 2.0)
    @test_throws ArgumentError split_trial(r, [0.0, 1.0], [0.5]; units = 10, σ = 1.0, z = 2.0)
    @test_throws ArgumentError split_trial(r, [0.0, 1.0], [0.5, 0.5]; units = 10, σ = -1.0, z = 2.0)
end
