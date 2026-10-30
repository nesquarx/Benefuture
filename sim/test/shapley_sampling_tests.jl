# Shapley by permutation sampling (Castro, Gómez & Tejada 2009; Lean `shapley_sampled_ref`,
# `shapley_sample_count_ref`; spec `Proposed.ShapleySampling`). A contributor's share is the mean,
# over sampled orderings of the contributors, of its marginal contribution to those before it.
# With m = ⌈ln(2n/δ) / (2ε²)⌉ orderings, Hoeffding's inequality and a union bound give, with
# probability at least 1 − δ, every share within ε · rᵢ of the exact one, rᵢ being the range of
# contributor i's marginal contributions. Exact Shapley is used up to `SHAPLEY_EXACT_MAX`
# contributors and sampling beyond.

# Test oracle (independent of the Lean reference): the range of each contributor's marginals.
function marginal_ranges(v, n)
    lo, hi = fill(Inf, n), fill(-Inf, n)
    for i in 1:n, m in 0:(2^n - 1)
        m & (1 << (i - 1)) != 0 && continue
        d = v[(m | (1 << (i - 1))) + 1] - v[m + 1]
        lo[i] = min(lo[i], d); hi[i] = max(hi[i], d)
    end
    hi .- lo
end

# Orderings (columns of 1-based indices) and the coalition values along each, from a value oracle.
function along(val, perms)
    n, m = size(perms)
    vals = zeros(n + 1, m)
    for k in 1:m
        mask = 0
        vals[1, k] = val(0)
        for p in 1:n
            mask |= 1 << (perms[p, k] - 1)
            vals[p + 1, k] = val(mask)
        end
    end
    vals
end

function all_perms(n)
    n == 1 && return [[1]]
    [insert!(copy(q), j, n) for q in all_perms(n - 1) for j in 1:n]
end

@testset "Shapley sampling: acceptance" begin
    # Enumerating every ordering recovers exact Shapley.
    for seed in 1:10
        r = Xoshiro(seed)
        n = rand(r, 1:5)
        g = randn(r, 2^n)
        P = reduce(hcat, all_perms(n))
        @test shapley_sampled(P, along(mask -> g[mask + 1], P)) ≈ shapley(g) atol = 1e-12
    end
    # The governed sample count: ⌈ln(2n/δ) / (2ε²)⌉.
    @test shapley_sample_count(10; ε = 0.05, δ = 0.05) == ceil(Int, log(2 * 10 / 0.05) / (2 * 0.05^2))
    @test shapley_sample_count(20; ε = 0.05, δ = 0.01) > shapley_sample_count(10; ε = 0.05, δ = 0.01)
    @test shapley_sample_count(10; ε = 0.025, δ = 0.05) > shapley_sample_count(10; ε = 0.05, δ = 0.05)
    # Agreement with exact Shapley within the stated bound ε · rᵢ, on random games small enough to
    # enumerate (δ = 1e-3 per game; seeds fixed).
    for seed in 1:20
        r = Xoshiro(100 + seed)
        n = rand(r, 2:8)
        g = randn(r, 2^n)
        φ = shapley(g)
        ψ = shapley_shares(mask -> g[mask + 1], n; rng = Xoshiro(seed), exact_max = 0, ε = 0.05, δ = 1e-3)
        @test all(abs.(ψ .- φ) .<= 0.05 .* marginal_ranges(g, n) .+ 1e-12)
    end
    # Efficiency holds for every sample, not only on average (Lean: shapley_sampled_efficient):
    # sampling error moves currency between contributors, never mints or destroys it.
    r = Xoshiro(7)
    g = randn(r, 2^6)
    P = reduce(hcat, [randperm(r, 6) for _ in 1:5])
    @test sum(shapley_sampled(P, along(mask -> g[mask + 1], P))) ≈ g[end] - g[1]
    # Up to the exact cap the shares are exact; beyond it they are sampled.
    @test shapley_shares(mask -> g[mask + 1], 6; rng = Xoshiro(1)) == shapley(g)
end

@testset "Shapley sampling: scaling beyond the exact cap" begin
    # 20 contributors with pairwise interactions: v(S) = Σ wᵢ + Σ_{i<j ∈ S} cᵢⱼ, whose Shapley
    # share is wᵢ + Σⱼ cᵢⱼ / 2. Exact Shapley would need 2^20 coalition values.
    n = 20
    r = Xoshiro(3)
    w, c = randn(r, n), randn(r, n, n) ./ n
    c = (c .+ c') ./ 2
    val(mask) = sum(w[i] + sum((c[i, j] for j in (i + 1):n if mask & (1 << (j - 1)) != 0); init = 0.0)
                    for i in 1:n if mask & (1 << (i - 1)) != 0; init = 0.0)
    truth = [w[i] + sum(c[i, j] for j in 1:n if j != i) / 2 for i in 1:n]
    ψ = shapley_shares(val, n; rng = Xoshiro(4), ε = 0.05, δ = 0.01)
    # rᵢ ≤ Σⱼ |cᵢⱼ| bounds each contributor's marginal range.
    @test all(abs.(ψ .- truth) .<= 0.05 .* [sum(abs, c[i, :]) - abs(c[i, i]) for i in 1:n])
    @test sum(ψ) ≈ val(2^n - 1)
    # Additive contributions are recovered exactly: every ordering gives the same marginals.
    @test shapley_shares(mask -> sum((w[i] for i in 1:n if mask & (1 << (i - 1)) != 0); init = 0.0), n;
                         rng = Xoshiro(5)) ≈ w
    # A symmetric majority game (v = 1 once more than half have acted): each gets 1/n within ε.
    maj(mask) = count_ones(mask) > n ÷ 2 ? 1.0 : 0.0
    @test all(abs.(shapley_shares(maj, n; rng = Xoshiro(6), ε = 0.05, δ = 0.01) .- 1 / n) .<= 0.05)
    # A contributor who changes nothing gets exactly nothing, however the sample falls.
    @test shapley_shares(mask -> maj(mask & ~1), n; rng = Xoshiro(8))[1] == 0
end

@testset "Shapley sampling: adversarial and edge cases" begin
    P = [1 2; 2 1]
    V = [0.0 0.0; 1.0 1.0; 2.0 2.0]
    @test shapley_sampled(P, V) ≈ [1.0, 1.0]
    @test_throws ArgumentError shapley_sampled([1 1; 2 1], V)              # a repeated index
    @test_throws ArgumentError shapley_sampled([1 3; 2 1], V)              # an index out of range
    @test_throws ArgumentError shapley_sampled(P, V[1:2, :])               # wrong number of values
    @test_throws ArgumentError shapley_sampled(P, [0.0 0.0; NaN 1.0; 2.0 2.0])
    @test_throws ArgumentError shapley_sampled(zeros(Int, 2, 0), zeros(3, 0))  # no ordering sampled
    @test_throws ArgumentError shapley_sample_count(10; ε = 0.0, δ = 0.05)
    @test_throws ArgumentError shapley_sample_count(10; ε = 1.5, δ = 0.05)
    @test_throws ArgumentError shapley_sample_count(10; ε = 0.05, δ = 1.0)
    @test_throws ArgumentError shapley_sample_count(0; ε = 0.05, δ = 0.05)
    @test_throws ArgumentError shapley_shares(m -> 0.0, 63; rng = Xoshiro(1))   # masks are 62-bit
    @test_throws ArgumentError shapley_shares(m -> NaN, 12; rng = Xoshiro(1))
    @test shapley_shares(m -> 1.0, 0; rng = Xoshiro(1)) == Float64[]
end

# False-name manipulation (Aziz, Bachrach, Elkind & Paterson 2011): one contributor forks into
# several identities. The bound Benefuture needs is that forking never raises the forks' total
# share above the original contributor's share.
@testset "False names: forks against the no-gain bound" begin
    # Additive effects: forking is neutral (each fork's share is its own effect).
    e = [3.0, 1.0, 2.0]
    add(es) = mask -> sum((es[i] for i in eachindex(es) if mask & (1 << (i - 1)) != 0); init = 0.0)
    orig = shapley_shares(add(e), 3; rng = Xoshiro(1))[1]
    forked = shapley_shares(add([1.0, 2.0, 1.0, 2.0]), 4; rng = Xoshiro(1))
    @test sum(forked[1:2]) ≈ orig
    # Monotone games: the forks' total never exceeds the whole outcome, v(N) − v(∅).
    # The m3c funding game (actor 1's effect counts only if the coalition can fund it; pledgers'
    # pledges are their weights): a pledger whose pledge is indispensable, split into k
    # indispensable pieces, takes k/(k+1) of the outcome alongside the actor instead of 1/2.
    function funding(pledges; own = 0.2, need = 0.2 + sum(pledges), E = 1.0)
        mask -> (isodd(mask) && own + sum((pledges[k] for k in eachindex(pledges) if mask & (1 << k) != 0); init = 0.0) >= need - 1e-9) ? E : 0.0
    end
    one = shapley_shares(funding([0.6]), 2; rng = Xoshiro(1))
    @test one ≈ [0.5, 0.5]
    for k in 2:4
        fk = shapley_shares(funding(fill(0.6 / k, k); need = 0.8), k + 1; rng = Xoshiro(1))
        @test sum(fk[2:end]) ≈ k / (k + 1)
        @test sum(fk[2:end]) <= 1.0                 # the bound that holds: never more than the whole
        @test sum(fk[2:end]) > one[2]               # the bound that fails: forking pays (8.57-a)
    end
    # Diminishing returns (a concave valuation of summed effects) also reward forking, mildly.
    conc(es) = mask -> sqrt(add(es)(mask))
    base = shapley_shares(conc([1.0, 1.0]), 2; rng = Xoshiro(1))[1]
    split = shapley_shares(conc([0.5, 0.5, 1.0]), 3; rng = Xoshiro(1))
    @test sum(split[1:2]) > base
    # Increasing returns (convex) penalise it.
    conv(es) = mask -> add(es)(mask)^2
    @test sum(shapley_shares(conv([0.5, 0.5, 1.0]), 3; rng = Xoshiro(1))[1:2]) <
          shapley_shares(conv([1.0, 1.0]), 2; rng = Xoshiro(1))[1]
end
