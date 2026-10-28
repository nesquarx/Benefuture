# Domain rules (L22, L101; Ontology.Domain, Ontology.Reputation): partition of unity, attribution
# of an action to leaf domains, and sign-dependent relevance decay.

@testset "Domain rules: acceptance" begin
    @test profile_valid([0.5, 0.3, 0.2])
    @test profile_valid([1.0])
    # Attribution: share × causal contribution × contribution, per domain, positive and negative apart.
    pos, neg = attribute([0.5, 0.5, 0.0], 0.8, 10.0, 2.0)
    @test pos ≈ [4.0, 4.0, 0.0]
    @test neg ≈ [0.8, 0.8, 0.0]
    # Relevance: gains and losses decay at their own rates; the sign picks the rate.
    @test decay_rate_for(3.0; λpos = 0.01, λneg = 0.05) == 0.01
    @test decay_rate_for(-3.0; λpos = 0.01, λneg = 0.05) == 0.05
    @test decay_rate_for(0.0; λpos = 0.01, λneg = 0.05) == 0.01
end

@testset "Domain rules: adversarial and edge cases" begin
    # Partition of unity: no gerrymandering by over-labelling, no negative shares.
    @test !profile_valid([0.6, 0.6])
    @test !profile_valid([1.2, -0.2])
    @test !profile_valid(Float64[])
    # Conservation: attributed amounts sum to the whole, whatever the profile.
    shares = [0.1, 0.2, 0.3, 0.4]
    pos, neg = attribute(shares, 1.0, 7.0, 3.0)
    @test sum(pos) ≈ 7.0 && sum(neg) ≈ 3.0
    # No causal contribution, no reputation.
    pos, neg = attribute(shares, 0.0, 7.0, 3.0)
    @test all(iszero, pos) && all(iszero, neg)
    @test_throws ArgumentError attribute([0.6, 0.6], 1.0, 1.0, 0.0)
    @test_throws ArgumentError attribute([1.0], 1.5, 1.0, 0.0)
    @test_throws ArgumentError attribute([1.0], 0.5, -1.0, 0.0)
end
