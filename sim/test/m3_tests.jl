# Toy model M3: domains. Agents with per-domain skills work under a domain profile; payment,
# currency balances and reputation are attributed per domain and never cross between domains.

const W3 = M1Params(ToyParams(n = 80, steps = 150, plans = 10), [MetricModel(0.0, 0.0)], 0.0, 10)
specialist(d, D; skill = 0.6, focus = 0.8, sloppiness = 0.0) =
    DomainAgent([i == d ? skill : 0.0 for i in 1:D], [i == d ? focus : (1 - focus) / (D - 1) for i in 1:D], sloppiness)

@testset "M3: acceptance" begin
    # One domain reproduces M2 exactly.
    skills = collect(range(-0.3, 0.6; length = 12))
    m2 = run_m2(M2Params(W3, [Agent(s, 0.0) for s in skills], 0.02); seed = 4)
    m3 = run_m3(M3Params(W3, [DomainAgent([s], [1.0], 0.0) for s in skills], 0.02, 0.02); seed = 4)
    @test m3.floor_u == m2.floor_u
    @test m3.relevance[:, 1] ≈ m2.reputation
    @test m3.balance[:, 1] ≈ m2.balance
    # Specialists earn their reputation in their own domain.
    D = 3
    agents = [specialist(d, D) for d in 1:D for _ in 1:4]
    tr = run_m3(M3Params(W3, agents, 0.02, 0.02); seed = 2)
    @test all(argmax(tr.relevance[a, :]) == (a - 1) ÷ 4 + 1 for a in eachindex(agents) if any(!iszero, tr.relevance[a, :]))
    # Conservation: per-domain balances sum to what was paid; per-domain history to what was measured.
    @test vec(sum(tr.balance; dims = 2)) ≈ tr.paid
    @test vec(sum(tr.h_pos .- tr.h_neg; dims = 2)) ≈ tr.measured
    @test tr == run_m3(M3Params(W3, agents, 0.02, 0.02); seed = 2)
end

@testset "M3: adversarial and edge cases" begin
    # No halo: a domain outside an agent's profile receives nothing.
    pure = [DomainAgent([0.6, 0.0], [1.0, 0.0], 0.0), DomainAgent([0.0, 0.6], [0.0, 1.0], 0.0)]
    tr = run_m3(M3Params(W3, pure, 0.02, 0.02); seed = 1)
    @test tr.h_pos[1, 2] == 0 && tr.h_neg[1, 2] == 0 && tr.relevance[1, 2] == 0 && tr.balance[1, 2] == 0
    @test tr.h_pos[2, 1] == 0 && tr.relevance[2, 1] == 0 && tr.balance[2, 1] == 0
    # A harmful specialist, when chosen through prediction noise, accrues negative history in its domain only.
    noisy = M1Params(ToyParams(n = 80, steps = 300, plans = 6), [MetricModel(0.0, 1.5)], 0.0, 10)
    tr = run_m3(M3Params(noisy, [DomainAgent([-0.8, 0.0], [1.0, 0.0], 0.0), DomainAgent([0.0, 0.5], [0.0, 1.0], 0.0)], 0.02, 0.05); seed = 3)
    @test tr.h_neg[1, 1] > 0 && tr.h_neg[1, 2] == 0
    @test_throws ArgumentError DomainAgent([0.1, 0.2], [0.7, 0.7], 0.0)
    @test_throws ArgumentError DomainAgent([0.1], [0.5, 0.5], 0.0)
    @test_throws ArgumentError M3Params(W3, [DomainAgent([0.1], [1.0], 0.0), DomainAgent([0.1, 0.2], [0.5, 0.5], 0.0)], 0.02, 0.02)
    @test_throws ArgumentError M3Params(W3, [DomainAgent([0.1], [1.0], 0.0)], -0.1, 0.02)
end

@testset "M3: runs fast enough to iterate" begin
    D = 5
    agents = [specialist(d, D; sloppiness = 0.5) for d in 1:D for _ in 1:10]
    p = M3Params(M1Params(ToyParams(n = 200, steps = 300, plans = 20), [MetricModel(0.0, 0.5), MetricModel(0.0, 0.2)], 0.1, 10), agents, 0.02, 0.05)
    run_m3(M3Params(W3, agents[1:2], 0.02, 0.02); seed = 1)
    @test (@elapsed run_m3(p; seed = 1)) < 90
end
