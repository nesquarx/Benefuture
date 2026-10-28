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

# Outcome-first causal distribution (author rulings, BACKPROPAGATION 8.16, 8.17, 8.18). An action
# may build on a recent output of another agent in its domain. Each being an action touches is an
# outcome: its assessed change in V (understanding and happiness together). Contributors (the actor,
# the agent whose output it carried, co-funders) share each outcome Shapley-style over coalition
# values estimated by the causal-explanation model: V of the summed effects of the coalition's
# members, the actor's own effect requiring the coalition to fund it. Positive shares are paid and
# negative shares penalised. When the causal assessment is not confident enough, shares come from
# traversing the transaction substrate instead (L95).
const Tsmooth = ToyParams(n = 80, steps = 200, plans = 10, spread = 0.05)
makers() = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:3]
passers() = [DomainAgent([0.0, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:3]
cdp(agents; kw...) = M3cParams(Tsmooth, agents, [1, 1, 2, 2], trues(4); λpos = 0.02, λneg = 0.05, transactions = true,
                               causal_distribution = true, p_upstream = 1.0, kw...)

@testset "Causal distribution: acceptance" begin
    # Intermediaries who add nothing to the outputs they pass on earn almost nothing; the makers
    # upstream are paid for what their outputs carried.
    tr = run_m3c(cdp([makers(); passers()]); seed = 1)
    @test sum(tr.upstream_pos[1:3]) > 0
    @test abs(sum(tr.credit_pos[4:6] .+ tr.credit_neg[4:6])) < 0.1 * sum(tr.upstream_pos[1:3])
    # Every outcome is fully distributed: the shares sum to the measured value, with nothing left over.
    @test abs(tr.interaction) < 1e-6 * sum(abs, [m.measured for m in tr.memory])
    # Conservation and recount, as before.
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) - sum(tr.reinvested)
    @test all(recount(tr) .≈ (tr.h_pos_own, tr.h_neg_own, tr.relevance_own))
    @test tr == run_m3c(cdp([makers(); passers()]); seed = 1)
    # Without confidence in the causal assessment, the traversal fallback shares the outcomes.
    tr = run_m3c(cdp([makers(); passers()]; attribution_σ = 2.0); seed = 1)
    @test tr.fallback_outcomes > 0 && tr.assessed_outcomes == 0
end

@testset "Causal distribution: adversarial and edge cases" begin
    # A bad output is penalised downstream: good agents building on it carry its losses back to it.
    bad = [DomainAgent([-0.3, 0, 0, 0], [1.0, 0, 0, 0], 0.0)]
    tr = run_m3c(cdp([makers(); makers()[1:1]; bad]); seed = 2)
    @test tr.upstream_neg[5] < 0 && tr.upstream_pos[5] == 0
    # Co-funders whose money was needed share the credit of StandCoin work.
    tr = run_m3c(m3c(work = [1], threshold = 0.99, novel_threshold = 0.99, endowment = 2.0, transactions = true,
                     causal_distribution = true); seed = 1)
    @test tr.cofunder_credit > 0
    # Attribution noise leaves the books balanced.
    tr = run_m3c(cdp([makers(); bad]; p_upstream = 0.5, attribution_σ = 0.3); seed = 3)
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) - sum(tr.reinvested)
    @test_throws ArgumentError m3c(p_upstream = 1.5)
    @test_throws ArgumentError m3c(cc_threshold = 1.5)
end
