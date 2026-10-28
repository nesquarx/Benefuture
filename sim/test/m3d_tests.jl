# Toy model M3d: from proposals chosen by G to transactions. Every proposal is a transaction: each
# relevant currency's model quotes it (TP_Gen, L86); G screens it against the state plus the
# predicted effects of the transactions already accepted this step; it executes if its proposer
# can pay; the composed quotes are logged with it (L89, L145).

m3d(; work = [1, 3], kw...) = m3c(; work, transactions = true, kw...)

@testset "M3d: acceptance" begin
    # Many transactions a step, where G alone chose one.
    tr = run_m3c(m3d(); seed = 1)
    g = run_m3c(m3c(work = [1, 3]); seed = 1)
    per_step = [count(==(s), tr.chosen_step) for s in unique(tr.chosen_step)]
    @test maximum(per_step) > 1 && length(tr.chosen_step) > 2 * length(g.chosen_step)
    # With exact models and markers, sequential screening keeps every floor from falling.
    exact = m3d(σ_leaf = 0.0, σ_branch = 0.0, σ_coarse = 0.0)
    tr = run_m3c(exact; seed = 2)
    @test floors_rise(tr) && length(tr.chosen_step) > 0
    # Every executed transaction is logged with the quotes composed for it, a partition of unity.
    tr = run_m3c(m3d(); seed = 3)
    @test length(tr.memory) == length(tr.chosen_step) + tr.lane_executed + tr.init_executed
    @test all(m -> profile_valid(m.priced), tr.memory)
    # Without transactions M3c is unchanged.
    @test run_m3c(m3c(work = [1, 3], transactions = false); seed = 1) == g
end

@testset "M3d: adversarial and edge cases" begin
    # A harmful agent's transactions are screened out, however many it proposes.
    agents = [DomainAgent([-0.8, 0.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0], 0.0) for _ in 1:4]
    tr = run_m3c(M3cParams(T3c, agents, [1, 1, 2, 2], trues(4); λpos = 0.02, λneg = 0.05, transactions = true); seed = 4)
    @test count(>(50), tr.chosen_step) <= 2  # after the 50-step score-only start
end
