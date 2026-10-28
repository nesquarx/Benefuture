# Toy model M2: agents propose plans; imperfect agents; escrow payment, settlement and reputation.

const W2 = M1Params(ToyParams(n = 80, steps = 150, plans = 10), [MetricModel(0.0, 0.0)], 0.0, 10)
agents(skills; sloppiness = zeros(length(skills))) = [Agent(s, e) for (s, e) in zip(skills, sloppiness)]

@testset "Settlement rule" begin
    @test settlement(10.0, 7.0) == 3.0
    @test settlement(2.0, 7.0) == -5.0      # clawback
    @test_throws ArgumentError settlement(NaN, 1.0)
end

@testset "M2: acceptance" begin
    skills = collect(range(-0.3, 0.6; length = 20))
    p = M2Params(W2, agents(skills), 0.02)
    tr = run_m2(p; seed = 2)
    @test tr == run_m2(p; seed = 2)
    # Perfect measurement and careful agents: nothing to settle, and predictions match outcomes.
    @test all(abs.(tr.settlements) .< 1e-9)
    @test maximum(abs.(tr.predicted_floor_u_change .- tr.realised_floor_u_change)) < 1e-9
    # Currency is conserved: everything paid equals the measured value of the plans chosen.
    @test sum(tr.upfronts) + sum(tr.settlements) ≈ sum(tr.measured_values)
    # Reputation comes to track skill.
    @test spearman(tr.reputation, skills) > 0.5
    @test length(tr.floor_u) == p.world.toy.steps + 1
end

@testset "M2: adversarial and edge cases" begin
    # A sloppy agent ends with less reputation than a careful one of equal skill.
    p = M2Params(M1Params(ToyParams(n = 80, steps = 300, plans = 4), [MetricModel(0.0, 0.3)], 0.05, 10),
                 agents([0.4, 0.4, 0.4, 0.4]; sloppiness = [0.0, 0.0, 2.0, 2.0]), 0.02)
    tr = run_m2(p; seed = 4)
    @test mean(tr.reputation[1:2]) > mean(tr.reputation[3:4])
    # Sloppiness shows up as settlement: clawbacks happen.
    @test any(<(0), tr.settlements)
    # A harmful agent is rarely chosen and earns no positive reputation.
    p = M2Params(W2, agents([-1.0, 0.5, 0.5]), 0.02)
    tr = run_m2(p; seed = 1)
    @test tr.reputation[1] <= 0
    @test_throws ArgumentError Agent(0.1, -1.0)
    @test_throws ArgumentError M2Params(W2, Agent[], 0.02)
    @test_throws ArgumentError M2Params(W2, agents([0.1]), -0.1)
end

@testset "M2: runs fast enough to iterate" begin
    p = M2Params(M1Params(ToyParams(n = 200, steps = 300, plans = 20), [MetricModel(0.0, 0.5), MetricModel(0.0, 0.2)], 0.1, 10),
                 agents(collect(range(-0.2, 0.6; length = 50)); sloppiness = fill(0.5, 50)), 0.02)
    run_m2(M2Params(W2, agents([0.1, 0.2]), 0.02); seed = 1)
    @test (@elapsed run_m2(p; seed = 1)) < 90
end
