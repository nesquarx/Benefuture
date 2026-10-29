# Convergence under heavy friction in the economy (author ruling 8.31; M3c world): every noise source
# at the top of its range in `sim/README.md` (Noise). FINDING (BACKPROPAGATION 8.32): compounded
# friction pushes model accuracy below the currency-eligibility threshold, every currency stops
# pricing at once, and only the StandCoin lane runs; kept as a `@test_broken` requirement.

fr_agents(sl) = [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], sl) for _ in 1:8]
fr(; sl = 0.0, kw...) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10), fr_agents(sl), [1, 1, 2, 2], trues(4);
                                  λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, kw...)
const FRICTION = (marker_σ = 0.5, bias_σ = 0.5, classify_σ = 0.15, spread = 0.15, cost_σ = 0.5, regen_σ = 1.0,
                  memory_loss = 0.2, participation = 0.3, attribution_σ = 0.5, remeasure_σ = 1.0, p_hazard = 0.5,
                  guardians = [1, 2, 3, 4], p_informed = 0.3, diligence = fill(0.3, 8), repair_efficiency = 0.5,
                  p_side = 0.2, p_upstream = 0.5)
fr_gain(tr) = tr.floor_u[end] - tr.floor_u[51]

@testset "M3c: convergence under heavy friction" begin
    clean = mean(fr_gain(run_m3c(fr(); seed)) for seed in 1:3)
    # Every source but model error and execution noise at the top of its range: floors still rise,
    # more slowly.
    heavy = [run_m3c(fr(; FRICTION...); seed) for seed in 1:3]
    @test mean(fr_gain.(heavy)) > 0.2 * clean && all(tr -> length(tr.chosen_step) > 0, heavy)
    # With moderate model error added, accuracy falls below the eligibility threshold and pricing
    # stops: a cliff, not a degradation (8.32).
    cliff = [run_m3c(fr(; FRICTION..., σ_leaf = 1.0, σ_branch = 1.0, σ_coarse = 1.0); seed) for seed in 1:3]
    @test_broken mean(fr_gain.(cliff)) > 0.1 * clean
end
