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

# The debatable escape (L157 SigThGv: Debatable → LqdBfDm; author rulings 8.26.3, 8.38.2): a
# proposal beyond the freedom range is tried on a share of the scope for a limited time, and
# adopted only if it beats the incumbent by the significance rule, its gains exceed its harms, and
# it caused no irreparable harm (Lean `escape_accept_ref`).
@testset "Debatable escape: acceptance rule" begin
    better = (means = [1.0, 2.0], ses = [0.1, 0.1])
    @test escape_accept(better.means, better.ses; gains = 10.0, harms = 3.0, irreparable = 0, z = 2.0)
    # Gains not above harms, any irreparable harm, or no significant improvement: rejected.
    @test !escape_accept(better.means, better.ses; gains = 3.0, harms = 3.0, irreparable = 0, z = 2.0)
    @test !escape_accept(better.means, better.ses; gains = 10.0, harms = 3.0, irreparable = 1, z = 2.0)
    @test !escape_accept([1.0, 1.1], [0.1, 0.1]; gains = 10.0, harms = 3.0, irreparable = 0, z = 2.0)
    @test !escape_accept([1.0, 0.5], [0.1, 0.1]; gains = 10.0, harms = 3.0, irreparable = 0, z = 2.0)
    @test_throws ArgumentError escape_accept([1.0], [0.1]; gains = 1.0, harms = 0.0, irreparable = 0, z = 2.0)
    @test_throws ArgumentError escape_accept(better.means, better.ses; gains = -1.0, harms = 0.0, irreparable = 0, z = 2.0)
    @test_throws ArgumentError escape_accept(better.means, better.ses; gains = 1.0, harms = 0.0, irreparable = -1, z = 2.0)
end
