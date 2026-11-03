# Better models over time (author guidance 8.42.2; L82: currencies backed by the top models whose
# accuracy clears the bar, competing; L49 adoption). Causal discovery is not simulated: the
# simulation assumes, openly, that new models keep arriving in each domain (`p_new_model`), better on
# average (`improve_drift`) but noisy (`improve_σ`) and never perfect (`scale_min`, 8.33). Every model
# in a domain's pool is scored on every logged action there (the open log; a challenger needs no
# deployment to build its record), and a challenger takes over the currency only when it beats the
# incumbent by the significance rule (`select_candidate_ref`, `model_z`). A model that slips, a
# captured one, is overtaken the same way.
using Statistics
isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))  # the controlled world (limiting case)


pool_world(; sl = 0.3, kw...) = M3cParams(ToyParams(n = 80, steps = 400, plans = 10),
    [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], sl) for _ in 1:8], [1, 1, 2, 2], trues(4);
    λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, LEGACY..., σ_leaf = 0.45, σ_branch = 0.6, σ_coarse = 0.75, kw...)  # a controlled world
growth(tr) = tr.floor_u[end] - tr.floor_u[51]

@testset "Better models: acceptance" begin
    seeds = 1:12
    static = [run_m3c(pool_world(); seed) for seed in seeds]
    better = [run_m3c(pool_world(p_new_model = 0.05); seed) for seed in seeds]
    # Challengers arrive and take over, so a working domain's backing model ends better than the
    # bootstrap's: a regime, since a challenger must win by the significance rule (`model_z`). Stated:
    # in most seeds (interval above a half). Unsupported under time-decayed accuracy (8.85), so not
    # asserted: 16 of 24 seeds, interval 0.46–0.82 (under the fixed record window 10 of 12; the two do
    # not differ significantly at these counts). No model is ever perfect (structural, every seed).
    @test all(all(>=(0.1 - 1e-12), b.top_scale) for b in better)
    # Stated before measuring (CLAUDE.md significance testing): floors lose no more than 5% of their
    # growth (equivalence, one-sided). Holds at 8, 12 and 16 seeds.
    @test equivalent(growth.(static) .- growth.(better); margin = 0.05 * mean(growth.(static)), side = :upper).equivalent
    # Unsupported, so not asserted: that better models raise the working leaves' final accuracy
    # (+0.007 ± 0.020 over 16 paired seeds) or the share their own currencies price (+0.037 ± 0.020,
    # 1.85 standard errors against 2.17). The models' ceiling here is the world's noise (8.84: a perfect
    # model scores well under 1), so a better model takes over with little measured accuracy to gain.
    seeds = 1:3
    # A model that slips is overtaken: a capture of the model backing leaf 1 is outlived by a
    # challenger, which keeps the leaf's currency pricing through the capture.
    cap = [shock(:capture; step = 150, duration = 200, size = 3.0, target = 1)]
    held(tr) = (k = [i for i in eachindex(tr.chosen_step) if tr.true_leaf[i] == 1 && 200 <= tr.chosen_step[i] < 350];
                isempty(k) ? 0.0 : mean(tr.priced_leaf[k] .== 1))
    captured = [run_m3c(pool_world(events = cap); seed) for seed in seeds]
    overtaken = [run_m3c(pool_world(events = cap, p_new_model = 0.05); seed) for seed in seeds]
    # An effect (significance rule): +0.79 ± 0.05 over 3 seeds, stable at 6 and 8 (+0.79 ± 0.04).
    @test paired_effect(held.(overtaken) .- held.(captured)).significant
end

@testset "Better models: adversarial and edge cases" begin
    # No new models: nothing changes.
    @test run_m3c(pool_world(p_new_model = 0.0); seed = 1) == run_m3c(pool_world(); seed = 1)
    # Where new models arrive worse on average, only the rare better one takes over: no domain ends
    # backed by a worse model than the bootstrap's. The run repeats.
    worse = [run_m3c(pool_world(p_new_model = 0.05, improve_drift = 0.3); seed) for seed in 1:4]
    @test all(all(w.top_scale .<= 1 + 1e-12) for w in worse)
    worse = worse[1]
    @test worse == run_m3c(pool_world(p_new_model = 0.05, improve_drift = 0.3); seed = 1)
    @test_throws ArgumentError pool_world(p_new_model = 1.5)
    @test_throws ArgumentError pool_world(scale_min = 0.0)
    @test_throws ArgumentError pool_world(pool_max = 0)
end
