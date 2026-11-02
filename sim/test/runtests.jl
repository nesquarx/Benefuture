using BenefutureSim
using JSON
using Test
using Random
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

include("legacy.jl")
# Every file runs even when an earlier one fails: a failure must never hide the files after it (author:
# silent failures cannot be fixed). The run fails at the end, naming each failing file.
failed = String[]
for f in ["value_tests.jl", "goal_tests.jl", "m0_tests.jl", "m1_tests.jl", "analysis_tests.jl", "economy_tests.jl", "m2_tests.jl", "domain_tests.jl", "shapley_tests.jl", "shapley_sampling_tests.jl", "differential_tests.jl", "m3_tests.jl", "m3b_tests.jl", "m3c_tests.jl", "m3d_tests.jl", "m3e_tests.jl", "m3f_tests.jl", "friction_tests.jl", "diversity_tests.jl", "advap_tests.jl", "m6_tests.jl", "attack_tests.jl", "friction_m3c_tests.jl", "models_tests.jl", "m6_attacks_tests.jl", "battery_tests.jl", "methods_tests.jl", "m4_tests.jl", "m5_tests.jl", "m7_tests.jl", "calibrated_tests.jl", "probe_tests.jl", "replay_tests.jl"]
    try
        @testset "$f" begin include(f) end
    catch
        push!(failed, f)
    end
end
isempty(failed) || error("test files failed: " * join(failed, ", "))
