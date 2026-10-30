# Toy model M7, first rung: deaths (conjecture A36: sacrificial trade-offs are never chosen). G's
# floors are taken over the beings present at decision time, a life a plan would end keeping its
# place at the bottom (Lean `removal_cannot_raise_floor`, `removal_cannot_raise_quantile_floor`;
# here one threshold below the lowest level, a toy convention). Freedom is a subgoal, reported per
# plan, not a filter on G (SPEC_DIVERGENCES §8.8 [R]): it should emerge from V's convex harm weights.
# Finding 8.47 (awaiting the author): in this toy neither G's quantile floor nor V with the deaths
# classed as irreparable harm stops a plan that removes the two worst-off and lifts everyone else;
# only the literal minimum, and Freedom as reported, mark it.

function irreparable_value(du, dh, p, irreparable)
    tier = irreparable ? 1 : 4  # irreparable first, passing fourth, in the harm schedule (L61)
    tiers = [(i == tier ? abs(min(du, 0)) + abs(min(dh, 0)) : 0.0, w) for (i, w) in enumerate(HARM_SCHEDULE)]
    value_on_being(du, dh, 0.0; harm_wt = harm_weight(tiers; λ = p.gp.λ), p.gp...)
end

@testset "M7 deaths: what blocks a sacrificial trade-off (finding 8.47)" begin
    p = ToyParams(n = 50, plans = 2)
    rng = Xoshiro(7)
    for trial in 1:20
        s = toy_state(p, rng)
        worst = sortperm(s.u .+ s.h)[1:2]
        bottom = min(minimum(s.u), minimum(s.h)) - p.th
        others = setdiff(1:p.n, worst)
        du, dh = fill(3.0, p.n), fill(3.0, p.n)
        du[worst] .= bottom .- s.u[worst]; dh[worst] .= bottom .- s.h[worst]
        sacrifice = ToyPlan(du, dh)
        uplift = ToyPlan([b in others[1:10] ? 0.3 : 0.0 for b in 1:p.n], [b in others[1:10] ? 0.3 : 0.0 for b in 1:p.n])
        # Floors over the decision-time population, the dead at the bottom, still rise, and G takes it.
        @test floor_quantile(s.u .+ du, p.q) > floor_quantile(s.u, p.q)
        @test choose(s, [sacrifice, uplift], p) == 2
        # With the deaths valued as irreparable harm, its total value is still positive.
        @test sum(irreparable_value(du[b], dh[b], p, b in worst) for b in 1:p.n) > 0
        # Freedom, reported per plan, marks it impermissible, and the uplift not.
        @test !fr_permissible(2.0, 0.0, 0.0, 0.0, 0.0; confidence = 0.95) && fr_permissible(0.0, 0.0, 0.0, 0.0, 0.0; confidence = 0.95)
    end
    # The literal minimum does stay down: the dead at the bottom keep it there.
    s = toy_state(p, Xoshiro(1))
    worst = argmin(s.u)
    du = fill(3.0, p.n); du[worst] = minimum(s.u) - p.th - s.u[worst]
    @test minimum(s.u .+ du) < minimum(s.u)
    @test_throws ArgumentError fr_permissible(-1.0, 0.0, 0.0, 0.0, 0.0; confidence = 0.5)
end

# M7, second rung: teaching (understanding is shared, not moved; Lean `u_sharing_gain_nonneg`;
# conjecture B17, frontier compounding). Teaching is one to many and happens at any level: a teacher
# anywhere raises a class below it towards its teachable level, each learner by `ε` × its own
# reception (varying), the teacher keeping all of its own. G chooses among lessons and ordinary
# plans as in M0; research is spending (third rung).
@testset "M7 teaching: lessons spread understanding and feed research" begin
    p = ToyParams(n = 100, steps = 300, plans = 10)
    seeds = 1:4
    none = [run_m7(p; seed, ε = 0.0, research_share = 0.1) for seed in seeds]
    taught = [run_m7(p; seed, ε = 0.3, research_share = 0.1) for seed in seeds]
    # A lesson, one to many: it never lowers the teacher, raises no learner above the teacher, and
    # reception varies by learner.
    lesson = teaching_plan([0.0, 2.0, 5.0], 3, [1, 2], 0.5)
    @test lesson.du == [2.5, 1.5, 0.0] && all(lesson.du .>= 0)
    @test teaching_plan([0.0, 2.0, 5.0], 3, [1, 2], 0.5; reception = [0.2, 5.0]).du == [0.5, 3.0, 0.0]
    # With research as spending (a tenth of time), teaching raises the floor and median of
    # understanding and the peak too: more beings near the frontier make research succeed more often.
    sp(ts, f) = mean(getfield(success_pattern(t), f) for t in ts)
    @test sp(taught, :floor_u) > sp(none, :floor_u) && sp(taught, :median_u) > sp(none, :median_u)
    @test sp(taught, :peak_u) > sp(none, :peak_u)
    @test_throws ArgumentError run_m7(p; seed = 1, ε = 1.5)
end

# M7, third rung: research as spending (author). A governed share `research_share` of beings' time
# goes to research each step, taking those beings from ordinary work and lessons and drawing on the
# commons; each attempt succeeds with a very noisy chance rising with the researcher's understanding
# (relative to the frontier) and its novelty, and a success lands beyond the peak, teachable or tacit
# (`p_teachable`). Ordinary work may pass the peak by in-job innovation, rarely, near the top only.
@testset "M7 research as spending" begin
    p = ToyParams(n = 100, steps = 300, plans = 10)
    # A teacher passes on only its teachable understanding; tacit gains stay with it.
    @test teaching_plan([0.0, 2.0, 5.0], 3, [1, 2], 1.0; tacit = 2.0).du == [3.0, 1.0, 0.0]
    shares = (0.0, 0.1, 0.8)
    runs = Dict(r => [run_m7(p; seed, ε = 0.3, research_share = r) for seed in 1:4] for r in shares)
    peak(r) = mean(success_pattern(t).peak_u for t in runs[r])
    floor(r) = mean(success_pattern(t).floor_u for t in runs[r])
    # Research moves the frontier; too much of it takes from uplift.
    @test peak(0.1) > peak(0.0)
    @test floor(0.8) < floor(0.1)
    @test all(t.research_spent > 0 for t in runs[0.1]) && all(t.research_spent == 0 for t in runs[0.0])
    @test_throws ArgumentError run_m7(p; seed = 1, ε = 0.3, research_share = 1.5)
end

# G per entity (author ruling 8.50): every entity runs its own messy approximation of G. Each acting
# entity reads the world through its own noisy view (`view_σ`), predicts its options with its own
# error (`pred_σ`) and chooses among them by the Lean rules; many act each step, concurrently. A single
# global G choosing one plan a step is the limiting case (`central = true`).
@testset "M7 G per entity" begin
    p = ToyParams(n = 100, steps = 300, plans = 10)
    tr = run_m7(p; seed = 1, ε = 0.3)
    @test mean(tr.actions) > 1  # many entities act each step
    @test isequal(run_m7(p; seed = 1, ε = 0.3), tr)
    central = run_m7(p; seed = 1, ε = 0.3, central = true)
    @test all(central.actions .<= 1)
    # Messy inputs: with views and predictions exact, floors fall less often than with messy ones.
    exact = [run_m7(p; seed, ε = 0.3, view_σ = 0.0, pred_σ = 0.0) for seed in 1:3]
    messy = [run_m7(p; seed, ε = 0.3, view_σ = 1.0, pred_σ = 1.0) for seed in 1:3]
    @test mean(success_pattern(t).floor_u_falls for t in messy) > mean(success_pattern(t).floor_u_falls for t in exact)
    @test_throws ArgumentError run_m7(p; seed = 1, ε = 0.3, p_act = 1.5)
end
