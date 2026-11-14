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
    @test decay_rate_for(3.0; λpos = 0.05, λneg = 0.01) == 0.05
    @test decay_rate_for(-3.0; λpos = 0.05, λneg = 0.01) == 0.01
    @test decay_rate_for(0.0; λpos = 0.05, λneg = 0.01) == 0.05
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
# the unspecialized currency, flagged for adjudication. Overflow (L103): a balance above its
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

# The domain network (Ontology.Domain [R]: leaves hold shares, parents are fuzzy sets of leaves;
# Proposed.DomainHierarchy [P]: μ from memory; BACKPROPAGATION 8.3, 8.4, 8.8). Shares are laid out
# as leaves, then parent residuals, then the root (StandCoin). Network below: parents A, B; leaves
# 1, 2 in A, leaf 3 in B and weakly (0.3) in A.
const MU = [1.0 1.0 0.3; 0.0 0.0 1.0]
@testset "Domain network: acceptance" begin
    @test projection_membership([1.0, 0.3, 0.5], [1.0, 0.0, 0.0]) ≈ 1.0
    @test projection_membership([0.1, 0.3, 0.5], [0.0, 1.0, 0.0]) ≈ 0.3
    # Descends from a matched parent to its matching member leaf.
    s = classify_network([1.0, 0.0], [0.1, 0.9, 1.5], MU; parent_threshold = 0.5, μ_min = 0.2, leaf_threshold = 0.4, temperature = 0.01)
    @test s ≈ [1, 0, 0, 0, 0, 0] atol = 1e-12
    # No member leaf matches: stuck at the parent; no parent matches: at the root.
    @test classify_network([1.0, 0.0], [0.9, 0.9, 1.5], MU; parent_threshold = 0.5, μ_min = 0.2, leaf_threshold = 0.4, temperature = 0.01) ≈ [0, 0, 0, 1, 0, 0]
    @test classify_network([0.1, 0.0], [0.1, 0.9, 1.5], MU; parent_threshold = 0.5, μ_min = 0.2, leaf_threshold = 0.4, temperature = 0.01) ≈ [0, 0, 0, 0, 0, 1]
    # A weak member (μ 0.3 ≥ μ_min) is a candidate under A too.
    @test classify_network([1.0, 0.0], [0.9, 0.9, 0.1], MU; parent_threshold = 0.5, μ_min = 0.2, leaf_threshold = 0.4, temperature = 0.01)[3] ≈ 1
    # Fallback: an ineligible leaf's share goes to its eligible parents by μ.
    @test fallback_network(MU, [true, true, false], [true, true], [0, 0, 1.0, 0, 0, 0]) ≈ [0, 0, 0, 0.3 / 1.3, 1 / 1.3, 0]
    @test fallback_network(MU, [false, true, true], [false, true], [1.0, 0, 0, 0, 0, 0]) ≈ [0, 0, 0, 0, 0, 1]
    # Aggregates at parents, subsethood from memory, and overlap degrees as a long-term rolling average.
    @test aggregate_at_parent(MU[1, :], [2.0, 3.0, 10.0]) ≈ 8.0
    @test subsethood([1.0, 1.0, 0.0], [0.3, 0.3, 1.0], ones(3)) ≈ 0.3
    @test membership_rolling(0.5, 1.0, 0.3; rate = 0.1) ≈ 0.48
    # Accuracy and eligibility; a novel domain needs its score-only records first.
    @test accuracy(-0.25) ≈ 1 / 1.5
    @test currency_eligible(0.7, 0; novel = false, threshold = 0.6, novel_threshold = 0.55, min_records = 10, novel_floor = 0.55)
    @test !currency_eligible(0.7, 5; novel = true, threshold = 0.6, novel_threshold = 0.55, min_records = 10, novel_floor = 0.55)
    @test currency_eligible(0.57, 10; novel = true, threshold = 0.6, novel_threshold = 0.55, min_records = 10, novel_floor = 0.55)
    # The status bar relative to the alternative (author ruling 8.41): a leaf model must match the
    # accuracy of the qualified currency its work would otherwise fall to, up to the established bar,
    # never below the coarse bar.
    @test relative_bar(0.9, 0.75, 0.8) ≈ 0.8 && relative_bar(0.9, 0.75, 0.95) ≈ 0.9 && relative_bar(0.9, 0.75, 0.6) ≈ 0.75
    @test_throws ArgumentError relative_bar(0.9, 0.95, 0.8)
    @test_throws ArgumentError relative_bar(0.9, 0.75, NaN)
    # Credence and accuracy (author rulings 8.35, 8.36): a model's credence that an action's
    # assessed value is positive, from its prediction and its own uncertainty; accuracy is the
    # quality of credences, 1 − Brier / Brier of random guessing (0.25): 0 is random, 1 perfect.
    @test credence(0.0, 1.0) ≈ 0.5 && isapprox(credence(2.0, 1.0), 0.97725; atol = 1e-4)
    # Truth levels never reach 1 (8.33): credence is capped by the governed `cap`.
    @test credence(1.0, 0.0; cap = 0.99) == 0.99 && credence(-1.0, 0.0; cap = 0.99) ≈ 0.01 && credence(9.0, 1.0; cap = 0.99) == 0.99
    @test isapprox(credence(-2.0, 1.0), 0.02275; atol = 1e-4) && credence(1.0, Inf) ≈ 0.5
    @test credence_accuracy([1.0, 1.0, 0.0], [1.0, 1.0, 0.0]) ≈ 1.0
    @test credence_accuracy([0.5, 0.5], [1.0, 0.0]) ≈ 0.0
    @test credence_accuracy([0.75, 0.25], [1.0, 0.0]) ≈ 0.75
    @test scarcity_cost(2.0, 100.0, 100.0; floor_share = 0.001) ≈ 2.0
    @test scarcity_cost(2.0, 50.0, 100.0; floor_share = 0.001) ≈ 4.0
end

@testset "Domain network: adversarial and edge cases" begin
    # Shares are always a partition of unity, and fallback never loses any.
    for (pm, ld) in (([1.0, 1.0], [0.1, 0.1, 0.1]), ([0.0, 0.0], [9.0, 9.0, 9.0]), ([0.6, 0.5], [0.39, 0.4, 0.41]))
        s = classify_network(pm, ld, MU; parent_threshold = 0.5, μ_min = 0.2, leaf_threshold = 0.4, temperature = 0.05)
        @test profile_valid(s)
        @test profile_valid(fallback_network(MU, [false, true, false], [true, false], s))
    end
    # A novel domain's threshold never drops below 0.55, however it is set (8.35: that floor is for
    # discovering what has no precedent).
    @test !currency_eligible(0.54, 100; novel = true, threshold = 0.9, novel_threshold = 0.3, min_records = 10, novel_floor = 0.55)
    # Worse than random guessing scores 0, not below; no record, no accuracy.
    @test credence_accuracy([0.0], [1.0]) == 0.0 && credence_accuracy(Float64[], Float64[]) == 0.0
    @test_throws ArgumentError credence_accuracy([1.2], [1.0])
    @test_throws ArgumentError credence(1.0, -1.0)
    @test_throws ArgumentError credence(1.0, 1.0; cap = 0.4)
    # Membership is clamped to [0, 1]; a leaf with no new action keeps its degree (domains do not fade),
    # and one action moves a degree by at most the rate.
    @test projection_membership([-1.0, 0.0], [1.0, 0.0]) == 0 && projection_membership([3.0, 0.0], [1.0, 0.0]) == 1
    @test subsethood(zeros(3), ones(3), ones(3)) == 0 && membership_rolling(0.4, 0.0, 0.9; rate = 0.1) == 0.4
    @test abs(membership_rolling(0.9, 1.0, 0.0; rate = 0.02) - 0.9) <= 0.02 && 0 <= membership_rolling(0.0, 1.0, 0.0; rate = 1.0) <= 1
    @test isfinite(scarcity_cost(1.0, 0.0, 100.0; floor_share = 0.001)) && scarcity_cost(1.0, 0.0, 100.0; floor_share = 0.001) > 100
    @test_throws ArgumentError classify_network([1.0], [0.1, 0.2], MU; parent_threshold = 0.5, μ_min = 0.2, leaf_threshold = 0.4, temperature = 0.01)
    @test_throws ArgumentError classify_network([1.0, 0.0], [0.1, 0.2, 0.3], MU; parent_threshold = 0.0, μ_min = 0.2, leaf_threshold = 0.4, temperature = 0.01)
    @test_throws ArgumentError fallback_network(MU, [true], [true, true], zeros(6))
    @test_throws ArgumentError accuracy(0.5)
    @test_throws ArgumentError scarcity_cost(1.0, 10.0, 0.0; floor_share = 0.001)
end

# Credence from the record ([P], finding 8.58-c and the side-harm boundary): the share of the
# model's past value errors below its prediction (the true value is the prediction less the error),
# ties counting half, within [1 − cap, cap]; the normal credence over the RMS error is the limiting
# case of normal errors.
@testset "Record credence: acceptance" begin
    @test record_credence(0.5, [0.1, 0.2, 0.3, 0.7, 0.9]) ≈ 0.6
    @test record_credence(0.3, [0.1, 0.3, 0.5, 0.7]) ≈ 0.375          # a tie counts half
    @test record_credence(9.0, [0.1, 0.2]; cap = 0.99) == 0.99 && record_credence(-9.0, [0.1, 0.2]; cap = 0.99) ≈ 0.01
    @test record_credence(1.0, Float64[]) == 0.5                        # no record: a coin toss
    errs = 0.7 .* randn(Xoshiro(3), 20_000)                             # normal errors: the old rule's case
    @test all(abs(record_credence(v, errs) - credence(v, 0.7)) < 0.01 for v in (-1.0, -0.3, 0.0, 0.4, 1.2))
end
@testset "Record credence: adversarial and edge cases" begin
    base = collect(range(-1, 1; length = 99))
    hit = [base; 300.0]                                                 # one heavy-tailed side effect
    @test abs(record_credence(0.5, hit) - record_credence(0.5, base)) <= 1 / 99
    rms(e) = sqrt(sum(abs2, e) / length(e))
    @test credence(0.5, rms(base)) > 0.75 && credence(0.5, rms(hit)) < 0.52   # counterexample: the RMS rule collapses to a coin toss
    @test issorted([record_credence(v, base) for v in -2:0.1:2])        # monotone in the prediction
    @test_throws ArgumentError record_credence(NaN, base)
    @test_throws ArgumentError record_credence(0.0, [0.1, Inf])
    @test_throws ArgumentError record_credence(0.0, base; cap = 0.4)
end

# Author ruling 8.23: every component consuming a model, measurement, or record names its simpler
# fallback, and when a leaf model drops below eligibility bar, pricing falls back to parent models
# and logs the degradation loudly.
@testset "Component fallbacks (8.23)" begin
    @test length(COMPONENT_FALLBACKS) == 10
    @test all(x -> !isempty(string(x.component)) && !isempty(x.primary) && !isempty(x.condition) && !isempty(x.fallback), COMPONENT_FALLBACKS)
    @test :leaf_pricing in first.(COMPONENT_FALLBACKS) && :model_challenger in first.(COMPONENT_FALLBACKS)
    toy = ToyParams(; n = 30, steps = 120, plans = 4)
    ag = [DomainAgent([0.8, 0.2], [0.5, 0.5], 0.1), DomainAgent([0.2, 0.8], [0.5, 0.5], 0.1)]
    tr = run_m3c(M3cParams(toy, ag, [1, 1], [true, true]; λpos = 0.05, λneg = 0.02,
                           events = [shock(:capture; step = 60, duration = 60, size = 15.0, target = 1)]); seed = 1)
    @test any(occursin("eligible parent model by μ", k) for k in keys(tr.degraded))
end
