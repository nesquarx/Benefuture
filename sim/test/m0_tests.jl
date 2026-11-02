# Toy model M0: a fixed population, random plan menus, perfect measurement, G choosing.

const P0 = ToyParams(n = 60, steps = 40, plans = 12)

@testset "M0: acceptance" begin
    tr = run_m0(P0; seed = 7)
    @test tr == run_m0(P0; seed = 7)                      # deterministic for a seed
    @test length(tr.floor_u) == P0.steps + 1
    @test length(tr.chosen) == P0.steps
    @test floors_rise(tr; w = 1)                          # Conj_FloorsRise, exact in M0
    @test all(diff(tr.peak_u) .>= 0)                      # the peak of U never falls
    @test all(tr.value .>= 0)                             # inaction is always available
    @test any(tr.chosen .> 1)                             # and something better is sometimes found
    still = run_m0(ToyParams(n = 10, steps = 5, plans = 0); seed = 1)
    @test all(==(1), still.chosen)
    @test allequal(still.mean_h)
end

@testset "M0: adversarial and edge cases" begin
    s = toy_state(ToyParams(n = 5, steps = 1, plans = 0); seed = 3)
    worst = argmin(s.h)
    # A plan raising everyone's happiness a lot but lowering the worst-off is vetoed by the floor.
    dh = fill(10.0, 5); dh[worst] = -0.5
    lift_but_hurt = ToyPlan(zeros(5), dh)
    @test choose(s, [lift_but_hurt], ToyParams(n = 5, steps = 1, plans = 1, q = 0.0)) == 1
    # A plan lowering the peak of understanding is vetoed however much happiness it gives.
    # (The peak is the population's maximum: raising another being past it would not lower it.)
    top = argmax(s.u)
    du = zeros(5); du[top] = -1.0
    @test maximum(s.u .+ du) < maximum(s.u)
    @test choose(s, [ToyPlan(du, fill(5.0, 5))], ToyParams(n = 5, steps = 1, plans = 1, q = 0.0)) == 1
    # A plan that helps everyone is chosen over inaction.
    @test choose(s, [ToyPlan(fill(0.5, 5), fill(0.5, 5))], ToyParams(n = 5, steps = 1, plans = 1)) == 2
    @test_throws ArgumentError ToyParams(n = 0)
    @test_throws ArgumentError ToyParams(steps = -1)
    @test_throws ArgumentError ToyParams(q = 1.5)
    @test_throws ArgumentError ToyParams(th = 0.0)
    @test_throws ArgumentError choose(s, [ToyPlan(zeros(4), zeros(4))], ToyParams(n = 5, steps = 1, plans = 1))
end

@testset "M0: runs fast enough to iterate" begin
    p = ToyParams(n = 1000, steps = 100, plans = 20)
    run_m0(ToyParams(n = 20, steps = 2, plans = 2); seed = 1)  # compile
    @test (@elapsed run_m0(p; seed = 1)) < 60
end

@testset "D1 & M0 ghosts: G per entity and governed Ha_wt / Fr" begin
    # Governed harm_weight defaults to bootstrap_params() and accepts overrides
    bp = bootstrap_params()
    tiers = [(1.0, 1.0), (2.0, 0.5)]
    w_default = harm_weight(tiers; λ = 0.5)
    @test w_default == harm_weight(tiers; λ = 0.5, κ = bp[10], q = bp[11])
    w_override = harm_weight(tiers; λ = 0.5, κ = 1.0, q = 2.0)
    @test w_override != w_default
    @test w_override >= 1.0
    @test_throws ArgumentError harm_weight(tiers; λ = 0.5, κ = -0.1)
    @test_throws ArgumentError harm_weight(tiers; λ = 0.5, q = 0.5)

    # Governed fr_permissible defaults to bootstrap_params() and accepts overrides
    @test fr_permissible(0.0, 0.0, 0.0, 0.5, 0.1; confidence = 0.8)
    @test !fr_permissible(0.0, 0.0, 0.0, 2.0, 0.0; confidence = 0.8)
    @test fr_permissible(0.0, 0.0, 0.0, 2.0, 0.0; confidence = 0.8, th_high = 5.0)
    @test_throws ArgumentError fr_permissible(0.0, 0.0, 0.0, 0.0, 0.0; confidence = 0.5, th_conf = 0.0)
    @test_throws ArgumentError fr_permissible(0.0, 0.0, 0.0, 0.0, 0.0; confidence = 0.5, th_high = 0.0)
    @test_throws ArgumentError fr_permissible(0.0, 0.0, 0.0, 0.0, 0.0; confidence = 0.5, severities = [1.0, 2.0])

    # Distributed choice (central = false): runs multiple actions per step and raises floors
    tr_dist = run_m0(P0; seed = 7, central = false)
    @test any(tr_dist.chosen .> 1)
    @test tr_dist.floor_u[end] > tr_dist.floor_u[1]
    @test tr_dist.floor_h[end] > tr_dist.floor_h[1]
    @test length(tr_dist.floor_u) == P0.steps + 1
    @test length(tr_dist.chosen) == P0.steps
end
