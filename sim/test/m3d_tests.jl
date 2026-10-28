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

# Causal distribution over transaction trees (author ruling, BACKPROPAGATION 8.14). An action may
# build on a recent output of another agent in its domain; its outcome is split into constituent
# parts (each being, understanding or happiness, each contributor), each part's side decided by its
# assessment against not acting (As, L48); positive parts pay their contributors, negative parts
# penalise theirs (L94), a contribution's share lying in [0, 1] on its own side (L93).
const Tsmooth = ToyParams(n = 80, steps = 200, plans = 10, spread = 0.05)

@testset "Causal distribution: acceptance" begin
    # Parts by assessment: A adds 1 and B 0.5 to being 1, C takes 1 from being 2.
    z = zeros(Tsmooth.n)
    A, B, C = ToyPlan(setindex!(copy(z), 1.0, 1), copy(z)), ToyPlan(setindex!(copy(z), 0.5, 1), copy(z)), ToyPlan(setindex!(copy(z), -1.0, 2), copy(z))
    (ap, an), (bp, bn), (cp, cn) = assessed_parts(A, Tsmooth), assessed_parts(B, Tsmooth), assessed_parts(C, Tsmooth)
    @test ap > bp > 0 && an == 0 && bn == 0 && cp == 0 && cn < 0
    @test assessed_parts(ToyPlan(copy(z), copy(z)), Tsmooth) == (0.0, 0.0)
    # A wholly positive outcome is not split: its parts carry its whole value, synergy included.
    both = ToyPlan(setindex!(copy(z), 1.0, 1), setindex!(copy(z), 1.0, 1))
    @test assessed_parts(both, Tsmooth)[1] ≈ BenefutureSim.plan_value(both, Tsmooth) && assessed_parts(both, Tsmooth)[2] == 0
    @test cc_share(2.0, 8.0) ≈ 0.25 && cc_share(-3.0, -6.0) ≈ 0.5 && cause_settlement(0.25, 8.0, 0.5) ≈ 1.5
    # Pass-through: agents who add nothing to the outputs they build on earn almost nothing; the
    # makers upstream are paid for what the outputs carried.
    makers = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:3]
    passers = [DomainAgent([0.0, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:3]
    p = M3cParams(Tsmooth, [makers; passers], [1, 1, 2, 2], trues(4); λpos = 0.02, λneg = 0.05, transactions = true,
                  cd_parts = true, p_upstream = 1.0)
    tr = run_m3c(p; seed = 1)
    @test sum(tr.upstream_pos[1:3]) > 0
    @test abs(sum(tr.credit_pos[4:6] .+ tr.credit_neg[4:6])) < 0.1 * sum(tr.upstream_pos[1:3])
    # Conservation: currency moves by the parts paid out, less costs and overflow; reputation
    # recounted from memory equals the incremental count.
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) - sum(tr.reinvested)
    @test all(recount(tr) .≈ (tr.h_pos_own, tr.h_neg_own, tr.relevance_own))
    @test tr == run_m3c(p; seed = 1)
end

@testset "Causal distribution: adversarial and edge cases" begin
    # A bad output is penalised downstream: good agents building on it carry its losses back to it.
    good = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:4]
    bad = [DomainAgent([-0.3, 0, 0, 0], [1.0, 0, 0, 0], 0.0)]
    tr = run_m3c(M3cParams(Tsmooth, [good; bad], [1, 1, 2, 2], trues(4); λpos = 0.02, λneg = 0.05, transactions = true,
                           cd_parts = true, p_upstream = 1.0); seed = 2)
    @test tr.upstream_neg[5] < 0 && tr.upstream_pos[5] == 0
    # Co-funders of StandCoin work share its credit (reputation; no currency can value it).
    tr = run_m3c(m3c(work = [1], threshold = 0.99, novel_threshold = 0.99, endowment = 2.0, transactions = true, cd_parts = true); seed = 1)
    @test tr.cofunder_credit > 0
    # Attribution noise leaves the books balanced.
    tr = run_m3c(M3cParams(Tsmooth, [good; bad], [1, 1, 2, 2], trues(4); λpos = 0.02, λneg = 0.05, transactions = true,
                           cd_parts = true, p_upstream = 0.5, attribution_σ = 0.3); seed = 3)
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) - sum(tr.reinvested)
    @test_throws ArgumentError cc_share(1.0, 0.0)
    @test_throws ArgumentError m3c(p_upstream = 1.5)
end
