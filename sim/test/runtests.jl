using BenefutureSim
using JSON
using Test
using Statistics

const VECTORS = joinpath(@__DIR__, "..", "..", "spec", "vectors")
vectors(name) = JSON.parsefile(joinpath(VECTORS, name * ".json"))

# Parameters used to generate spec/vectors/synergy.json (Main.lean).
const SY = (λ = 1.0, κ = 0.5, qp = 1.1, qm = 1.5)
sy(pos, neg) = net_synergy(pos, neg; SY...)

@testset "Synergy: acceptance (spec/vectors/synergy.json)" begin
    v = vectors("synergy")
    pair = [(10.0, 1.0), (5.0, 0.5)]
    @test sy(pair, []) ≈ v["synergy_positive"] atol = 1e-6
    @test sy([], pair) ≈ v["synergy_negative"] atol = 1e-6
    @test sy([(10.0, 1.0)], [(10.0, 1.0)]) ≈ v["synergy_equal_cancellation"] atol = 1e-6
    @test sy([], []) == v["synergy_zero"]
    @test sy([(10.0, 1.0)], []) ≈ v["synergy_single"] atol = 1e-6
    @test squashed_synergy(10.0; ν = 1.0, h = 5.0) ≈ v["squashed_synergy_pos"] atol = 1e-6
    @test squashed_synergy(-10.0; ν = 1.0, h = 5.0) ≈ v["squashed_synergy_neg"] atol = 1e-6
    @test squashed_synergy(0.0; ν = 1.0, h = 5.0) == v["squashed_synergy_zero"]
end

@testset "Synergy: adversarial and edge cases" begin
    # Superadditive in gains: two co-occurring gains score more than apart.
    @test sy([(10.0, 1.0), (5.0, 0.5)], []) > sy([(10.0, 1.0)], []) + sy([(5.0, 0.5)], [])
    # Gains and losses are mirror images when exponents and items match.
    @test net_synergy([(3.0, 1.0)], []; λ = 0.5, κ = 1.0, qp = 1.5, qm = 1.5) ≈
          -net_synergy([], [(3.0, 1.0)]; λ = 0.5, κ = 1.0, qp = 1.5, qm = 1.5)
    # Equal gain and loss nets below zero when λ > 0 (Lean: equal_gains_and_losses_are_negative).
    @test sy([(4.0, 1.0)], [(4.0, 1.0)]) < 0
    # Zero weights contribute nothing.
    @test sy([(10.0, 0.0)], []) == 0.0
    # Invalid inputs are rejected, not silently scored.
    @test_throws ArgumentError sy([(-1.0, 1.0)], [])
    @test_throws ArgumentError sy([(1.0, -1.0)], [])
    @test_throws ArgumentError sy([(NaN, 1.0)], [])
    @test_throws ArgumentError sy([(Inf, 1.0)], [])
    @test_throws ArgumentError net_synergy([(1.0, 1.0)], []; λ = -0.1, κ = 0.5, qp = 1.1, qm = 1.5)
    @test_throws ArgumentError net_synergy([(1.0, 1.0)], []; λ = 1.0, κ = 0.5, qp = 0.0, qm = 1.5)
    # Squashed synergy: odd, bounded in (-1, 1), monotone.
    for s in (0.1, 1.0, 7.5, 1e6)
        @test squashed_synergy(-s; ν = 1.0, h = 5.0) == -squashed_synergy(s; ν = 1.0, h = 5.0)
        @test -1 < squashed_synergy(s; ν = 2.0, h = 5.0) < 1
    end
    @test squashed_synergy(2.0; ν = 1.0, h = 5.0) < squashed_synergy(3.0; ν = 1.0, h = 5.0)
    @test_throws ArgumentError squashed_synergy(1.0; ν = 0.0, h = 5.0)
    @test_throws ArgumentError squashed_synergy(1.0; ν = 1.0, h = -1.0)
    @test_throws ArgumentError squashed_synergy(NaN; ν = 1.0, h = 5.0)
end

include("value_tests.jl")
include("goal_tests.jl")
include("m0_tests.jl")
include("m1_tests.jl")
include("analysis_tests.jl")
include("economy_tests.jl")
include("m2_tests.jl")
include("domain_tests.jl")
include("m3_tests.jl")
include("m3b_tests.jl")
include("m3c_tests.jl")
