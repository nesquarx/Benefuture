# Battery methods (sim/src/methods.jl): PRIM failure boxes, Sobol indices, active learning of the
# failure boundary, seed counts by variance stability, the cross-entropy attack search, and the
# success pattern's continuous margin. Tested on synthetic functions whose answers are known.
# Evaluation tooling, not rules.

@testset "Methods: success-pattern margin" begin
    clean = (floor_u = 10.0, floor_h = 8.0, median_u = 12.0, median_h = 9.0, peak_u = 20.0, worst_drop = 2.0)
    m = pattern_margin(clean, clean; growth = 0.25, harm = 3.0)
    @test m.margin ≈ 1.0 && all(v ≈ 1.0 for v in values(m.slacks))
    # Exactly at the criterion: floors at a quarter of the clean world's growth, harm at three times.
    edge = (floor_u = 2.5, floor_h = 2.0, median_u = 3.0, median_h = 2.25, peak_u = 0.0, worst_drop = 6.0)
    @test abs(pattern_margin(edge, clean; growth = 0.25, harm = 3.0).margin) < 1e-12
    # The weakest criterion sets the margin, and failing any one makes it negative.
    bad = merge(clean, (floor_h = 0.0,))
    mb = pattern_margin(bad, clean; growth = 0.25, harm = 3.0)
    @test mb.margin < 0 && mb.slacks.floor_h == mb.margin
    @test pattern_margin(merge(clean, (worst_drop = 7.0,)), clean; growth = 0.25, harm = 3.0).margin < 0
    @test pattern_margin(merge(clean, (peak_u = -1.0,)), clean; growth = 0.25, harm = 3.0).margin < 0
    # The clean world must grow and harm a little for the scales to mean anything.
    @test_throws ArgumentError pattern_margin(clean, merge(clean, (floor_u = 0.0,)); growth = 0.25, harm = 3.0)
    @test_throws ArgumentError pattern_margin(clean, clean; growth = 1.0, harm = 3.0)
    @test_throws ArgumentError pattern_margin(clean, clean; growth = 0.25, harm = 1.0)
end

@testset "Methods: PRIM acceptance (a planted failure box)" begin
    rng = Xoshiro(11)
    X = rand(rng, 2000, 5)
    planted(x) = x[1] > 0.7 && x[3] < 0.3
    y = [planted(X[i, :]) ⊻ (rand(rng) < 0.03) for i in 1:2000]  # 3% label noise
    b = prim(X, y)
    @test sort(b.restricted) == [1, 3]
    @test isapprox(b.lower[1], 0.7; atol = 0.05) && isapprox(b.upper[3], 0.3; atol = 0.05)
    # With label noise the planted box itself covers only part of the failures; PRIM's box covers most of that.
    inplanted = [planted(X[i, :]) for i in 1:2000]
    @test b.density > 0.9 && b.coverage > 0.85 * sum(y[inplanted]) / sum(y)
    @test 0 < b.support < 0.2 && b.n == count(i -> in_box(b, X[i, :]), 1:2000)
    @test length(b.trajectory) >= 2 && issorted([t.support for t in b.trajectory]; rev = true)
    # Readable boxes: one clause per restricted factor.
    s = describe_box(b, ["a", "b", "c", "d", "e"])
    @test occursin(r"a ≥ 0\.(6|7)\d*", s) && occursin(r"c ≤ 0\.(2|3)\d*", s) && !occursin("b ", s) && occursin(" and ", s)
    # Two planted boxes are both found by covering, the second after the first's points are removed.
    two(x) = (x[1] > 0.8 && x[2] > 0.8) || (x[4] < 0.15)
    y2 = [two(X[i, :]) for i in 1:2000]
    bs = prim_boxes(X, y2; nboxes = 3)
    @test length(bs) >= 2
    found = Set(Tuple(sort(bb.restricted)) for bb in bs[1:2])
    @test (4,) in found && (1, 2) in found
    @test sum(bb.coverage for bb in bs) <= 1 + 1e-9
end

@testset "Methods: PRIM adversarial and edge cases" begin
    rng = Xoshiro(12)
    X = rand(rng, 200, 3)
    # No failures: no boxes, and the single-box call says so rather than inventing one.
    @test isempty(prim_boxes(X, falses(200)))
    @test_throws ArgumentError prim(X, falses(200))
    @test_throws ArgumentError prim(X, trues(199))                  # sizes must match
    @test_throws ArgumentError prim(X, rand(rng, Bool, 200); α = 0.0)
    @test_throws ArgumentError prim(fill(NaN, 10, 2), trues(10))
    # Failure everywhere: the box is the whole space, restricting nothing.
    ball = prim(X, trues(200))
    @test isempty(ball.restricted) && ball.density == 1 && ball.coverage == 1
    # Pure noise: whatever box is found holds no more failure than chance plus noise allows,
    # and covering stops once boxes no longer beat the base rate.
    yn = rand(rng, 200) .< 0.3
    @test length(prim_boxes(X, yn; nboxes = 5)) <= 5
    # Tied (discrete) severities: peeling never removes nothing, and terminates.
    Xd = Float64.(rand(rng, 0:2, 300, 2))
    yd = [Xd[i, 1] == 2 for i in 1:300]
    bd = prim(Xd, yd)
    @test bd.lower[1] == 2 && bd.density == 1
end

@testset "Methods: Sobol acceptance (Ishigami)" begin
    # Ishigami (a = 7, b = 0.1) on [-π, π]³: first-order 0.314, 0.442, 0; total 0.558, 0.442, 0.244.
    ishigami(u) = (x = -π .+ 2π .* u; sin(x[1]) + 7sin(x[2])^2 + 0.1x[3]^4 * sin(x[1]))
    s = sobol_indices(ishigami, 3; N = 4096, rng = Xoshiro(13))
    @test all(isapprox.(s.S1[1, :], [0.3139, 0.4424, 0.0]; atol = 0.05))
    @test all(isapprox.(s.ST[1, :], [0.5576, 0.4424, 0.2437]; atol = 0.05))
    @test s.evaluations == 4096 * 5
    # Bootstrap intervals cover the known values.
    @test all(s.S1_lo[1, :] .- 0.02 .<= [0.3139, 0.4424, 0.0] .<= s.S1_hi[1, :] .+ 0.02)
    # Vector outputs: one row of indices per output. An additive function has S1 = ST.
    lin(u) = [u[1] + 2u[2], u[3]]
    v = sobol_indices(lin, 3; N = 2048, rng = Xoshiro(14))
    @test size(v.S1) == (2, 3)
    @test all(isapprox.(v.S1[1, :], [0.2, 0.8, 0.0]; atol = 0.05)) && all(isapprox.(v.ST[1, :], [0.2, 0.8, 0.0]; atol = 0.05))
    @test isapprox(v.S1[2, 3], 1.0; atol = 0.05)
end

@testset "Methods: Sobol adversarial and edge cases" begin
    # A constant output depends on no factor: indices zero, flagged, not NaN.
    c = sobol_indices(u -> 1.0, 2; N = 64, rng = Xoshiro(15))
    @test all(iszero, c.S1) && all(iszero, c.ST) && c.V[1] == 0
    @test_throws ArgumentError sobol_indices(u -> 1.0, 0; N = 64, rng = Xoshiro(15))
    @test_throws ArgumentError sobol_indices(u -> 1.0, 2; N = 1, rng = Xoshiro(15))
    @test_throws ArgumentError sobol_indices(u -> NaN, 2; N = 8, rng = Xoshiro(15))
    # A pure interaction (x₁ x₂ centred): no first-order effect, all of it in the totals.
    inter(u) = (u[1] - 0.5) * (u[2] - 0.5)
    s = sobol_indices(inter, 2; N = 4096, rng = Xoshiro(16))
    @test all(abs.(s.S1[1, :]) .< 0.05) && all(isapprox.(s.ST[1, :], 1.0; atol = 0.08))
end

@testset "Methods: active learning acceptance (a known boundary)" begin
    # Margin 1 − s₁ − s₂² (fails below 0) on a Gaussian-ish pool, with a noisy oracle.
    pool = gaussian_hypercube(Xoshiro(17), 1500, 2; μ = 0.6, σ = 0.35)
    truth = [1 - pool[i, 1] - pool[i, 2]^2 < 0 for i in 1:size(pool, 1)]
    err(r) = mean(r.predicted_fail .!= truth)
    # One run against one random design is a coin flip of the noise; compare over replicates.
    reps = map(1:6) do r
        noise = Xoshiro(100 + r)
        f(x) = 1 - x[1] - x[2]^2 + 0.05randn(noise)
        al = active_boundary(f, pool; rng = Xoshiro(200 + r), n_init = 8, budget = 30)
        al20 = active_boundary(f, pool; rng = Xoshiro(200 + r), n_init = 8, budget = 20)
        rnd = random_boundary(f, pool; rng = Xoshiro(200 + r), budget = 30)
        (al = al, al20 = al20, rnd = rnd)
    end
    @test all(r.al.evaluations <= 30 && r.rnd.evaluations == 30 for r in reps)
    e_al, e_al20, e_rnd = (mean(err(getfield(r, s)) for r in reps) for s in (:al, :al20, :rnd))
    @test e_al < 0.03 && e_al < e_rnd
    # It reaches the random design's accuracy at 30 runs with fewer runs of its own.
    @test e_al20 <= e_rnd
    @test all(isapprox(r.al.p_fail, mean(truth); atol = 0.03) for r in reps)
    # Points chosen after the initial design lie near the boundary.
    later = reps[1].al.X[(8 + 1):end, :]
    @test median([abs(1 - later[i, 1] - later[i, 2]^2) for i in 1:size(later, 1)]) < 0.25
end

@testset "Methods: active learning adversarial and edge cases" begin
    pool = rand(Xoshiro(20), 300, 2)
    # No boundary in the pool: it stops early and predicts no failure.
    r = active_boundary(x -> 1.0 + 0.01x[1], pool; rng = Xoshiro(21), n_init = 6, budget = 30)
    @test r.p_fail == 0 && r.evaluations < 30
    # A binary (±1) oracle still locates a boundary, as a smoothed classifier.
    truth = [pool[i, 1] > 0.5 for i in 1:300]
    rb = active_boundary(x -> x[1] > 0.5 ? -1.0 : 1.0, pool; rng = Xoshiro(22), n_init = 6, budget = 25)
    @test mean(rb.predicted_fail .!= truth) < 0.08
    @test_throws ArgumentError active_boundary(x -> 1.0, pool; rng = Xoshiro(21), n_init = 10, budget = 5)
    @test_throws ArgumentError active_boundary(x -> 1.0, zeros(0, 2); rng = Xoshiro(21), n_init = 2, budget = 5)
    @test_throws ArgumentError active_boundary(x -> NaN, pool; rng = Xoshiro(21), n_init = 2, budget = 5)
end

@testset "Methods: seed counts by variance stability" begin
    # A reading that does not vary needs only the minimum.
    c = seeds_until_stable(seed -> 2.0; tol = 0.1, min_seeds = 3, max_seeds = 10)
    @test c.n == 3 && c.mean == 2.0 && c.se == 0 && c.seeds == 1:3
    # A noisy reading (σ = 1) needs about (1/tol)² seeds before its standard error falls below tol.
    noisy(seed) = randn(Xoshiro(seed))
    r = seeds_until_stable(noisy; tol = 0.25, min_seeds = 3, max_seeds = 100)
    @test r.se <= 0.25 && 8 <= r.n <= 40 && r.stable
    # The cap binds and says so.
    capped = seeds_until_stable(noisy; tol = 0.01, min_seeds = 3, max_seeds = 6)
    @test capped.n == 6 && !capped.stable
    # Fixed seed order: the same call repeats exactly.
    @test seeds_until_stable(noisy; tol = 0.25, min_seeds = 3, max_seeds = 100).mean == r.mean
    @test_throws ArgumentError seeds_until_stable(noisy; tol = 0.0, min_seeds = 3, max_seeds = 6)
    @test_throws ArgumentError seeds_until_stable(noisy; tol = 0.1, min_seeds = 1, max_seeds = 6)
    @test_throws ArgumentError seeds_until_stable(noisy; tol = 0.1, min_seeds = 7, max_seeds = 6)
    @test_throws ArgumentError seeds_until_stable(seed -> NaN; tol = 0.1, min_seeds = 2, max_seeds = 6)
end

@testset "Methods: cross-entropy search" begin
    c = [0.2, 0.9, 0.4, 0.7]
    sphere(θ) = sum(abs2, θ .- c)
    r = cross_entropy_search(sphere, 4; rng = Xoshiro(23), population = 12, iterations = 8)
    @test r.evaluations == 96 && length(r.history) == 8
    @test r.value < 0.01 && maximum(abs.(r.θ .- c)) < 0.1
    @test all(0 .<= r.θ .<= 1)
    # Better than random search on the same budget.
    rr = Xoshiro(23)
    @test r.value < minimum(sphere(rand(rr, 4)) for _ in 1:96)
    # A noisy objective (common seeds unavailable) still lands near the optimum.
    nz = Xoshiro(24)
    rn = cross_entropy_search(θ -> sphere(θ) + 0.01randn(nz), 4; rng = Xoshiro(25), population = 16, iterations = 8)
    @test maximum(abs.(rn.θ .- c)) < 0.15
    # An optimum on the boundary of the cube is reached, not stopped short of.
    rb = cross_entropy_search(θ -> -sum(θ), 3; rng = Xoshiro(26), population = 10, iterations = 8)
    @test all(rb.θ .> 0.95)
    @test_throws ArgumentError cross_entropy_search(sphere, 4; rng = Xoshiro(23), population = 1, iterations = 3)
    @test_throws ArgumentError cross_entropy_search(sphere, 4; rng = Xoshiro(23), population = 8, iterations = 3, elite = 1.0)
    @test_throws ArgumentError cross_entropy_search(θ -> NaN, 2; rng = Xoshiro(23), population = 4, iterations = 2)
end

@testset "Methods: battery integration (synthetic reading)" begin
    # A synthetic battery: margin 1 − s₁ − s₂² over three factors, readings averaged over seeds by
    # variance stability; the results are written to a scratch directory, never to sim/battery/results.
    names = ["a", "b", "c"]
    reading(sev) = (r = seeds_until_stable(seed -> 1 - sev[1] - sev[2]^2 + 0.02randn(Xoshiro(seed)); tol = 0.02, min_seeds = 2, max_seeds = 6);
                    (outputs = [r.mean, 1 - sev[1]], n = r.n))
    rng = Xoshiro(30)
    pool = gaussian_hypercube(rng, 400, 3; μ = 0.6, σ = 0.3)
    m = battery_methods(reading, names; rng, outputs = ["margin", "first"], pool, sobol_n = 64, sobol_top = 1.0, active_budget = 25)
    @test m.sobol.ST[1, 3] < 0.05 && m.sobol.ST[1, 1] > 0.3 && m.sobol.ST[2, 1] > 0.9
    @test length(m.seeds_sobol) == 64 * 5 && all(2 .<= m.seeds_sobol .<= 6)
    @test m.active.evaluations <= 25 && length(m.seeds_active) == m.active.evaluations
    @test !isempty(m.active_boxes) && 3 ∉ m.active_boxes[1].restricted
    # Screening with the battery keeps its points, so PRIM can box its failures.
    bt = battery(s -> 1 - s[1] - s[2]^2 > 0, names; rng, rays = 4, screen_n = 60, tmax = 2.0, tol = 0.05)
    @test size(bt.screening.X) == (60, 3)
    dir = mktempdir()
    write_results("synthetic", bt, names; clean = NaN, minutes = 0.0, commit = "test", dir)
    write_methods("synthetic", m, names; reading_note = "test readings", screen_fail_rate = bt.screening.fail_rate, minutes = 0.0, dir)
    md = read(joinpath(dir, "synthetic.md"), String)
    for h in ("## Limits along one factor", "## Failure boxes (PRIM over the screened worlds)", "### Variance-based sensitivity",
              "### Active learning of the failure boundary", "Failure boxes (PRIM over the surrogate's verdict")
        @test occursin(h, md)
    end
    @test isfile(joinpath(dir, "synthetic_sobol.csv")) && isfile(joinpath(dir, "synthetic_active.csv"))
    @test countlines(joinpath(dir, "synthetic_sobol.csv")) == 1 + 2 * 3
    # Skipped methods write nothing of theirs.
    m0 = battery_methods(reading, names; rng, outputs = ["margin", "first"], pool, sobol_n = 0, sobol_top = 1.0, active_budget = 0)
    @test m0.sobol === nothing && m0.active === nothing && isempty(m0.active_boxes)
    @test_throws ArgumentError battery_methods(reading, names; rng, outputs = ["margin"], pool = pool[:, 1:2], sobol_n = 0, sobol_top = 1.0, active_budget = 0)
end
