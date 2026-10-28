# Shapley shares of an outcome (Benefuture currency: "approximates shapley-esque mechanisms";
# BACKPROPAGATION 8.17). Coalition values are indexed by bitmask: v[m + 1] is the assessed outcome
# had only the contributors in m acted.

@testset "Shapley: acceptance" begin
    # Overdetermination: either cause alone suffices; each gets half.
    @test shapley([0.0, 1.0, 1.0, 1.0]) ≈ [0.5, 0.5]
    # Additive contributions are returned as they are.
    @test shapley([0.0, 2.0, 3.0, 5.0]) ≈ [2.0, 3.0]
    # A destroyer working against the others has a negative share.
    v = [0.0, 10.0, 5.0, 15.0, -10.0, 0.0, -5.0, 5.0]   # A adds 10, B adds 5, C takes 10
    @test shapley(v) ≈ [10.0, 5.0, -10.0]
    # Efficiency, checked numerically: shares sum to v(all) − v(none), on random games.
    for seed in 1:20
        r = Xoshiro(seed)
        n = rand(r, 1:5)
        g = randn(r, 2^n)
        @test sum(shapley(g)) ≈ g[end] - g[1]
    end
end

@testset "Shapley: adversarial and edge cases" begin
    # A null contributor gets nothing, however the others interact.
    @test shapley([0.0, 0.0, 3.0, 3.0])[1] == 0
    @test shapley([7.0]) == Float64[]
    @test_throws ArgumentError shapley([0.0, 1.0, 2.0])
    @test_throws ArgumentError shapley([0.0, NaN])
end

# The confidence gate and the traversal fallback (L94–95): when the causal assessment is not
# confident enough, contributions come from traversing the transaction substrate, each link's net
# contribution weighted down by its degree of separation and normalised.
@testset "Fallback traversal: acceptance" begin
    @test cc_assessed(0.7; threshold = 0.6) && !cc_assessed(0.5; threshold = 0.6)
    @test traversal_shares([2.0, 1.0], [0, 1]; decay = 0.5) ≈ [0.8, 0.2]
    s = traversal_shares([1.0, 1.0, 1.0], [0, 1, 2]; decay = 0.5)
    @test sum(s) ≈ 1 && s[1] > s[2] > s[3]
end

@testset "Fallback traversal: adversarial and edge cases" begin
    # No net contribution anywhere: nothing to share out.
    @test traversal_shares([0.0, 0.0], [0, 1]; decay = 0.5) == [0.0, 0.0]
    # Links that add nothing get nothing.
    @test traversal_shares([3.0, 0.0], [1, 0]; decay = 0.5) ≈ [1.0, 0.0]
    @test_throws ArgumentError traversal_shares([1.0], [0, 1]; decay = 0.5)
    @test_throws ArgumentError traversal_shares([1.0], [0]; decay = 1.5)
    @test_throws ArgumentError traversal_shares([-1.0], [0]; decay = 0.5)
end
