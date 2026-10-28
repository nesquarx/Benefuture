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

# Classification (L22, Domain: causal grounding, external classification): currency metric models
# match an action's measured causal signature to the domains'; with no match it goes to StandCoin,
# the unspecialized currency, flagged for adjudication. Overflow (L100): a balance above its
# accumulation threshold is reinvested in its domain.
@testset "Classification and overflow: acceptance" begin
    # Profile over D domains plus StandCoin last; the nearest matched domain weighs most.
    w = classify([0.1, 0.3, 2.0]; threshold = 0.5, temperature = 0.1)
    @test length(w) == 4 && profile_valid(w)
    @test w[1] > w[2] > 0 && w[3] == 0 && w[4] == 0
    @test w[1] / w[2] ≈ exp((0.3^2 - 0.1^2) / 0.1)
    @test classify([2.0, 3.0]; threshold = 0.5, temperature = 0.1) == [0.0, 0.0, 1.0]
    @test accumulation_threshold(50.0, 0.5, 40.0) ≈ 70.0
    @test accumulation_threshold(50.0, 0.5, -40.0) ≈ 50.0
    @test overflow(80.0, 70.0) ≈ 10.0
    @test overflow(60.0, 70.0) == 0.0
end

@testset "Classification and overflow: adversarial and edge cases" begin
    # A distant match never underflows into StandCoin: the nearest matched domain anchors the scale.
    w = classify([0.49, 0.495]; threshold = 0.5, temperature = 1e-6)
    @test w[3] == 0 && profile_valid(w)
    # Exactly at the threshold still matches.
    @test classify([0.5]; threshold = 0.5, temperature = 0.1) == [1.0, 0.0]
    @test_throws ArgumentError classify(Float64[]; threshold = 0.5, temperature = 0.1)
    @test_throws ArgumentError classify([0.1]; threshold = 0.5, temperature = 0.0)
    @test_throws ArgumentError classify([-0.1]; threshold = 0.5, temperature = 0.1)
    @test_throws ArgumentError accumulation_threshold(-1.0, 0.5, 0.0)
    @test_throws ArgumentError overflow(NaN, 1.0)
end
