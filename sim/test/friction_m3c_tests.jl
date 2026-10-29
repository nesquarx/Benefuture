# Convergence under heavy friction in the economy (author ruling 8.31; M3c world): every noise source
# at the top of its realistic range in `sim/README.md` (Noise). Finding 8.32 (the eligibility gate
# switched all pricing off at once) is settled by rulings 8.35-8.36: accuracy is the quality of
# credences, thresholds are status, and realistic friction degrades pricing rather than stopping it.

fr_agents(sl) = [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], sl) for _ in 1:8]
fr(; sl = 0.0, kw...) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10), fr_agents(sl), [1, 1, 2, 2], trues(4);
                                  λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, kw...)
# Every noise source at the top of its realistic range (sim/README.md, Noise): the edge of a
# functional domain, where established models fall to about coarse accuracy.
const FRICTION = (marker_σ = 0.2, bias_σ = 0.2, classify_σ = 0.1, spread = 0.1, cost_σ = 0.3, regen_σ = 0.5,
                  memory_loss = 0.1, participation = 0.6, attribution_σ = 0.3, remeasure_σ = 0.5, p_hazard = 0.3,
                  guardians = [1, 2, 3, 4], p_informed = 0.6, diligence = fill(0.7, 8), repair_efficiency = 0.5,
                  p_side = 0.2, p_upstream = 0.5)
const MODELS_TOP = (σ_leaf = 0.45, σ_branch = 0.6, σ_coarse = 0.75)
fr_gain(tr) = tr.floor_u[end] - tr.floor_u[51]

@testset "M3c: convergence under heavy friction" begin
    clean = mean(fr_gain(run_m3c(fr(); seed)) for seed in 1:3)
    # Every source but model error at the top of its realistic range: floors still rise, more slowly.
    heavy = [run_m3c(fr(; FRICTION...); seed) for seed in 1:3]
    @test mean(fr_gain.(heavy)) > 0.2 * clean && all(tr -> length(tr.chosen_step) > 0, heavy)
    # Everything at its top, model error and execution noise included: degraded, not collapsed.
    # Accuracy is the quality of credences, not adjusted for noise (8.36), so it falls to about the
    # coarse level and pricing thins out rather than stopping.
    all_top = [run_m3c(fr(; FRICTION..., MODELS_TOP..., sl = 0.6); seed) for seed in 1:3]
    @test mean(fr_gain.(all_top)) > 0.1 * clean && all(tr -> length(tr.chosen_step) > 0, all_top)
    # Far beyond a functional domain, no model backs a currency and the work goes to StandCoin, as
    # ruled (8.35: permissiveness is a race to the bottom).
    poor = run_m3c(fr(; σ_leaf = 2.0, σ_branch = 2.0, σ_coarse = 2.0); seed = 1)
    @test isempty(poor.chosen_step) && poor.lane_executed > 0
end
