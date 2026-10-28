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

# The domain tree (author ruling, BACKPROPAGATION 8.3): currency metric models descend from the
# root to a leaf; a plan stuck at a branch is priced by the nearest ancestor whose currency is
# eligible; the root (StandCoin) is always eligible but prices resource cost only. A domain's
# reputation sums its subdomains'; a subdomain's never includes its parent's. Tree used below:
# 1 root → {2, 3}; 2 → {4, 5}.
const PARENTS = [0, 1, 1, 2, 2]
@testset "Domain tree: acceptance" begin
    # Descends to the matching leaf.
    s = classify_tree(PARENTS, [0.0, 0.3, 2.0, 0.1, 1.0]; thresholds = [0.8, 0.4], temperature = 0.01)
    @test s ≈ [0, 0, 0, 1, 0] atol = 1e-12
    # Stuck at branch 2 when no child matches; at the root when no branch matches.
    @test classify_tree(PARENTS, [0.0, 0.3, 2.0, 0.9, 1.0]; thresholds = [0.8, 0.4], temperature = 0.01) ≈ [0, 1, 0, 0, 0]
    @test classify_tree(PARENTS, [0.0, 1.5, 2.0, 0.1, 0.1]; thresholds = [0.8, 0.4], temperature = 0.01) ≈ [1, 0, 0, 0, 0]
    # Thresholds are per depth: a looser leaf threshold lets the same plan reach leaf 4.
    @test classify_tree(PARENTS, [0.0, 0.3, 2.0, 0.6, 1.0]; thresholds = [0.8, 0.7], temperature = 0.01)[4] ≈ 1
    # Fallback to the nearest eligible ancestor.
    @test fallback(PARENTS, [true, true, true, false, true], [0, 0, 0, 1.0, 0]) ≈ [0, 1, 0, 0, 0]
    @test fallback(PARENTS, [true, false, true, false, true], [0, 0, 0.5, 0.5, 0]) ≈ [0.5, 0, 0.5, 0, 0]
    # Subtree sums: a domain sums its subdomains, a leaf only itself.
    @test subtree_sum(PARENTS, [1.0, 2.0, 3.0, 4.0, 5.0]) ≈ [15, 11, 3, 4, 5]
    # Resource cost by availability: full availability costs the base rate, half costs double.
    @test scarcity_cost(2.0, 100.0, 100.0) ≈ 2.0
    @test scarcity_cost(2.0, 50.0, 100.0) ≈ 4.0
end

@testset "Domain tree: adversarial and edge cases" begin
    # Whatever the distances, the stop shares are a partition of unity.
    for d in ([0.0, 0.5, 0.5, 0.2, 0.2], [0.0, 9.0, 9.0, 9.0, 9.0], [0.0, 0.79, 0.8, 0.39, 0.4])
        @test profile_valid(classify_tree(PARENTS, d; thresholds = [0.8, 0.4], temperature = 0.05))
    end
    # The root is always eligible, so nothing falls off the tree.
    @test fallback(PARENTS, [false, false, false, false, false], [0, 0.2, 0.2, 0.3, 0.3]) ≈ [1, 0, 0, 0, 0]
    # A subdomain's total never includes its parent's own reputation.
    @test subtree_sum(PARENTS, [0.0, 7.0, 0.0, 0.0, 0.0])[4:5] == [0.0, 0.0]
    # Exhausted resources cost much more but stay finite.
    @test isfinite(scarcity_cost(1.0, 0.0, 100.0)) && scarcity_cost(1.0, 0.0, 100.0) > 100
    @test_throws ArgumentError classify_tree([0, 2, 1], [0.0, 0.1, 0.1]; thresholds = [0.8], temperature = 0.1)
    @test_throws ArgumentError classify_tree(PARENTS, [0.0, 0.1]; thresholds = [0.8], temperature = 0.1)
    @test_throws ArgumentError fallback(PARENTS, [true], [1.0, 0, 0, 0, 0])
    @test_throws ArgumentError scarcity_cost(1.0, 10.0, 0.0)
end
