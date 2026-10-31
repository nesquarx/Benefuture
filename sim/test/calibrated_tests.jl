# Calibrated world defaults (docs/CALIBRATION.md; author note 8.63, ruling 8.33). Invariant figures are
# defaults at the mildly imperfect end of their realistic range, with the old exact worlds kept as
# limiting cases (`LEGACY`, test/legacy.jl). Acceptance: the defaults are the calibrated ones, the
# distribution shapes are what the table says, and the realistic world behaves as measured.
# Counterexamples: what holds in the exact world is shown to fail under realism, so the limiting case
# is not mistaken for the default.
isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))  # the controlled world (limiting case)

realistic(; steps = 300, skill = 0.6, sloppiness = CALIBRATED.sloppiness, kw...) =
    M3cParams(ToyParams(n = 80, steps = steps, plans = 10), [DomainAgent([skill, 0, 0, 0], [1.0, 0, 0, 0], sloppiness) for _ in 1:6],
              [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, kw...)

@testset "Calibration: the defaults are the calibrated ones" begin
    p = realistic(steps = 20)
    @test p.marker_σ == CALIBRATED.marker_σ == 0.3 && p.bias_σ == CALIBRATED.bias_σ
    @test (p.σ_leaf, p.σ_branch, p.σ_coarse) == (CALIBRATED.σ_leaf, CALIBRATED.σ_branch, CALIBRATED.σ_coarse)
    @test p.σ_leaf < p.σ_branch < p.σ_coarse  # predictability of the domain: leaf best, coarse about the base rate
    @test (p.classify_σ, p.spread) == (CALIBRATED.classify_σ, CALIBRATED.spread)
    @test p.p_side == CALIBRATED.p_side > 0
    @test p.hazard_heavy && p.hazard_α == CALIBRATED.hazard_α && p.hazard_σ == CALIBRATED.hazard_σ
    # An agent not given an execution noise carries plans out as individuals do (the intention-behaviour gap).
    @test all(a -> a.sloppiness == CALIBRATED.sloppiness == 0.25, p.agents) && Agent(0.5).sloppiness == CALIBRATED.sloppiness
    # Institution-dependent figures are not defaults here: no hazards arise unless a world sets them, and
    # guardians' diligence and information, vigilance and the trace chance keep their governed or placeholder values.
    @test p.p_hazard == 0.0 && p.p_informed == 0.8 && p.vigilance == 0.05 && p.p_trace == 0.5
    # M5: non-experts' signal noise; M7: a course's share of the lead.
    m3 = run_m3c(realistic(steps = 30); seed = 1)
    @test M5Params(m3, 1:4).signal_σ == CALIBRATED.signal_σ == 2.0
    t = ToyParams(n = 60, steps = 30, plans = 5)
    @test run_m7(t; seed = 1) == run_m7(t; seed = 1, ε = CALIBRATED.ε) && run_m7(t; seed = 1) != run_m7(t; seed = 1, ε = 0.3)
end

@testset "Calibration: distribution shapes" begin
    rng = Xoshiro(2026)
    # Log-normal of mean 1 and the stated coefficient of variation; exactly 1 as the limiting case.
    x = lognormal_mean1(rng, 0.5, 400_000)
    @test isapprox(mean(x), 1; atol = 0.01) && isapprox(std(x) / mean(x), 0.5; atol = 0.02) && mean(x) > median(x)
    @test lognormal_mean1(rng, 0.0, 5) == ones(5)
    # Pareto event sizes: median 1, tail P(X > 2) = 2^(-α) / 2, capped.
    for α in (1.5, 2.0)
        s = [pareto_median1(rng, α, Inf) for _ in 1:400_000]
        @test isapprox(median(s), 1; atol = 0.01) && isapprox(mean(s .> 2), 0.5 * 2.0^(-α); atol = 0.003) && minimum(s) >= 2.0^(-1 / α) - 1e-12
    end
    @test all(pareto_median1(rng, 1.5, 20.0) <= 20.0 for _ in 1:10_000)
    @test_throws ArgumentError pareto_median1(rng, 0.0, 20.0)
    @test_throws ArgumentError pareto_median1(rng, 2.0, 0.5)
    # Skills: log-normal in the domains an agent works in, none elsewhere; identical agents are the limiting case.
    sk = draw_skills(rng, 20_000, 4, [1, 3]; median = 0.6, log_sd = 0.3)
    @test all(sk[:, [2, 4]] .== 0) && isapprox(median(sk[:, 1]), 0.6; atol = 0.01) && isapprox(std(log.(sk[:, 3])), 0.3; atol = 0.01)
    @test mean(sk[:, 1]) > median(sk[:, 1])  # right-skewed, not a bell
    @test allequal(draw_skills(rng, 5, 2, [1, 2]; log_sd = 0.0)[:, 1])
    tail = draw_skills(rng, 20_000, 1, [1]; median = 1.0, tail = 2.0)
    @test maximum(tail) > 10 * median(tail) > 0 && maximum(sk[:, 1]) < 10 * median(sk[:, 1])
    @test_throws ArgumentError draw_skills(rng, 0, 2, [1])
    @test_throws ArgumentError draw_skills(rng, 3, 2, [true])
end

@testset "Calibration: heavy-tailed hazards deepen harm's peak (acceptance) and the Gaussian world is the limiting case" begin
    # Same median size (1) and rate, no guardians (the commons insure): the success pattern's harm peak
    # (the deepest single-being drop) is several times deeper when event sizes are Pareto.
    peak(kw) = mean(success_pattern(run_m3c(realistic(; p_hazard = 0.2, kw...); seed); from = 51).worst_drop for seed in 1:4)
    heavy, thin = peak(()), peak((hazard_heavy = false, hazard_σ = 0.2))
    @test heavy > 2 * thin
    # An explicit catastrophe keeps its stated size (the tail applies to random events only).
    cat = shock(:catastrophe; step = 100, share = 0.5, size = 30.0)
    hit = run_m3c(realistic(events = [cat]); seed = 1)
    @test hit.floor_u[102] < hit.floor_u[100] - 10
end

@testset "Calibration: what holds in the exact world fails under realism (counterexamples)" begin
    exact = (σ_leaf = 0.0, σ_branch = 0.0, σ_coarse = 0.0, marker_σ = 0.0, bias_σ = 0.0, cost_σ = 0.0, regen_σ = 0.0, attribution_σ = 0.0, p_side = 0.0, sloppiness = 0.0)
    flat(kw) = [run_m3c(realistic(; kw...); seed) for seed in 1:3]
    # No floor ever falls with exact models, markers and accounting and no side harm ...
    @test all(floors_rise, flat(exact))
    # ... and with the calibrated defaults (noisy markers and models, side harm, imperfect execution) it does.
    @test count(floors_rise, flat(NamedTuple())) <= 1
    # Floors still grow overall: realism degrades the economy, it does not stop it.
    @test all(tr -> tr.floor_u[end] > tr.floor_u[51], flat(NamedTuple()))
end

@testset "Calibration: a guardian's prevention earns from its skill, read over seeds under realistic defaults" begin
    # Assessed against the committed action, averted harm is no output: what a prevention earns is its
    # action's measured outputs, so it rises with the guardian's skill (seed by seed the total is noisy,
    # and a single skilled guardian's can be negative under noisy markers and heavy hazards).
    guard(skill) = mean(run_m3c(realistic(; steps = 150, skill, p_hazard = 0.5, guardians = [1, 1, 1, 1], p_informed = 1.0,
                                          diligence = ones(6)); seed).prevention_measured for seed in 1:6)
    skilled, none, harmful = guard(0.6), guard(0.0), guard(-0.3)
    @test skilled > none > harmful
end
