# The failure-boundary battery (sim/src/battery.jl): randomized search for the combinations of noise
# and attack beyond which the framework stops converging. Tested here on synthetic oracles whose
# boundaries are known; the batteries themselves run from sim/battery/.

@testset "Battery: acceptance on synthetic oracles" begin
    rng = Xoshiro(1)
    # Latin hypercube: every factor's range is covered once per stratum.
    X = latin_hypercube(rng, 50, 3)
    @test size(X) == (50, 3) && all(0 .<= X .<= 1)
    @test all(sort(floor.(Int, X[:, k] .* 50)) == 0:49 for k in 1:3)
    # A known boundary: converges iff s₁ + s₂² < 1 (factor 3 irrelevant).
    oracle(s) = s[1] + s[2]^2 < 1
    b = ray_boundary(oracle, [1.0, 0.0, 0.0]; tmax = 2.0, tol = 1e-3)
    @test isapprox(b.t, 1.0; atol = 2e-3) && b.monotone
    b = ray_boundary(oracle, [0.0, 1.0, 0.0]; tmax = 2.0, tol = 1e-3)
    @test b.t ≈ 1.0 atol = 2e-3
    d = [1.0, 1.0, 0.0] ./ sqrt(2)
    b = ray_boundary(oracle, d; tmax = 2.0, tol = 1e-3)
    @test oracle(d .* (b.t - 0.01)) && !oracle(d .* (b.t + 0.01))
    @test ray_boundary(oracle, [0.0, 0.0, 1.0]; tmax = 2.0, tol = 1e-3).t == Inf  # never fails
    # Screening ranks the factors that matter above the one that does not.
    r = screen(oracle, latin_hypercube(rng, 400, 3))
    @test r.importance[3] < r.importance[1] && r.importance[3] < r.importance[2]
    # The battery: per-factor limits and boundary points on random rays.
    bt = battery(oracle, ["a", "b", "c"]; rng, rays = 20, screen_n = 200, tmax = 2.0, tol = 1e-2)
    @test isapprox(bt.limits["a"], 1.0; atol = 0.02) && bt.limits["c"] == Inf
    @test length(bt.boundary) == 20 && all(p -> !oracle(p.point .* 1.02), filter(p -> isfinite(p.t), bt.boundary))
    # Screening is scaled to where the rays found the boundary, so it straddles it rather than
    # landing wholly beyond (or short of) it.
    far(s) = sum(s) < 0.3
    sc = battery(far, ["a", "b", "c", "d", "e"]; rng, rays = 12, screen_n = 200, tmax = 2.0, tol = 1e-2).screening
    @test 0.2 < sc.fail_rate < 0.8
end

@testset "Battery: adversarial and edge cases" begin
    rng = Xoshiro(2)
    # A non-monotone ray (fails, then converges again further out) is flagged, not hidden.
    wavy(s) = !(0.4 < s[1] < 0.6)
    b = ray_boundary(wavy, [1.0]; tmax = 1.0, tol = 1e-3, grid = 20)
    @test isapprox(b.t, 0.4; atol = 0.06) && !b.monotone
    # A world failing at the clean point has boundary zero.
    @test ray_boundary(s -> false, [1.0, 0.0]; tmax = 1.0, tol = 1e-3).t == 0.0
    # A stochastic oracle: majority over seeds; the boundary is located within the noise.
    noisy(s) = s[1] + 0.05 * randn(rng) < 0.5
    maj(s) = count(_ -> noisy(s), 1:15) > 7
    @test ray_boundary(maj, [1.0]; tmax = 1.0, tol = 1e-3).t ≈ 0.5 atol = 0.05
    @test_throws ArgumentError latin_hypercube(rng, 0, 2)
    @test_throws ArgumentError ray_boundary(oracle -> true, [0.0, 0.0]; tmax = 1.0, tol = 1e-3)
end
