# Toy model M7, first rung: deaths (conjecture A36: sacrificial trade-offs are never chosen). G's
# floors are taken over the beings present at decision time, a life a plan would end keeping its
# place at the bottom (Lean `removal_cannot_raise_floor`, `removal_cannot_raise_quantile_floor`;
# here one threshold below the lowest level, a toy convention). That blocks raising the literal
# minimum by removal, but not G's quantile floor (finding 8.47): removing fewer beings than the
# quantile's rank, while lifting everyone else, raises it. What blocks the sacrifice is Freedom
# (L135; Lean `fr_permissible_ref`): a death is irreparable harm, and established irreparable harm is
# impermissible, however much value the plan offers others.

@testset "M7 deaths: Freedom blocks sacrificial trade-offs; floors alone do not" begin
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
        # Floors over the decision-time population, the dead at the bottom, still rise: G alone
        # would take the sacrifice (finding 8.47).
        @test floor_quantile(s.u .+ du, p.q) > floor_quantile(s.u, p.q)
        @test choose(s, [sacrifice, uplift], p) == 2
        # With its deaths classed as irreparable harm, predicted with confidence, Freedom screens it
        # out; the uplift, passing no harm, stays.
        harms = [(2.0, 0.0, 0.0, 0.0, 0.0, 0.95), (0.0, 0.0, 0.0, 0.0, 0.0, 0.95)]
        @test choose(s, [sacrifice, uplift], p; harms) != 2
        # Even a doubtful prediction of a death is too much expected harm.
        @test !fr_permissible(1.0, 0.0, 0.0, 0.0, 0.0; confidence = 0.1)
    end
    # The literal minimum does block it: the dead at the bottom keep the minimum down.
    s = toy_state(p, Xoshiro(1))
    worst = argmin(s.u)
    du = fill(3.0, p.n); du[worst] = minimum(s.u) - p.th - s.u[worst]
    @test minimum(s.u .+ du) < minimum(s.u)
    @test_throws ArgumentError fr_permissible(-1.0, 0.0, 0.0, 0.0, 0.0; confidence = 0.5)
    @test_throws ArgumentError choose(s, [ToyPlan(zeros(p.n), zeros(p.n))], p; harms = [])
end
