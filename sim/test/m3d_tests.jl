# Toy model M3d: from proposals chosen by G to transactions. Every proposal is a transaction: each
# relevant currency's model quotes it (TP_Gen, L86); G screens it against the state plus the
# predicted effects of the transactions already accepted this step; it executes if its proposer
# can pay; the composed quotes are logged with it (L89, L145).
isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))  # the controlled world (limiting case)


m3d(; work = [1, 3], kw...) = m3c(; work, transactions = true, kw...)

@testset "M3d: acceptance" begin
    # Many transactions a step, where G alone chose one: in every seed. How many in all depends on whether
    # the domains' currencies qualify, which is bistable under the calibrated noise (8.65): over seeds 1-5
    # on Linux four reach about seven times the menu's count and one (seed 4) stalls at 1.9; a 1-ULP libm
    # difference moves single seeds between the regimes across platforms, so the count is read over seeds.
    runs = [(run_m3c(m3d(); seed), run_m3c(m3c(work = [1, 3]); seed)) for seed in 1:5]
    @test all(maximum(count(==(s), tr.chosen_step) for s in unique(tr.chosen_step)) > 1 for (tr, _) in runs)
    # Stated before measuring: concurrency at least doubles the work done (an effect on the log of
    # transactions over twice the menu's count, paired by seed).
    @test paired_effect([log(length(tr.chosen_step) / (2 * length(g.chosen_step))) for (tr, g) in runs]).significant
    g = runs[1][2]  # the menu rung's run at seed 1, compared below
    # Limiting case (8.33: no real world is exact): with exact models, markers and accounting,
    # sequential screening keeps every floor from falling.
    exact = m3d(σ_leaf = 0.0, σ_branch = 0.0, σ_coarse = 0.0, marker_σ = 0.0, bias_σ = 0.0, cost_σ = 0.0, regen_σ = 0.0,
                attribution_σ = 0.0, p_side = 0.0)
    tr = run_m3c(exact; seed = 2)
    @test floors_rise(tr) && length(tr.chosen_step) > 0
    # Every executed transaction is logged with the quotes composed for it, a partition of unity;
    # with records lost on the way (2% by default), memory holds the rest.
    tr = run_m3c(m3d(memory_loss = 0.0); seed = 3)
    @test length(tr.memory) == length(tr.chosen_step) + tr.lane_executed + tr.init_executed
    lossy = run_m3c(m3d(); seed = 3)
    @test 0.9 * (length(lossy.chosen_step) + lossy.lane_executed + lossy.init_executed) < length(lossy.memory) <
          length(lossy.chosen_step) + lossy.lane_executed + lossy.init_executed
    @test all(m -> profile_valid(m.priced), tr.memory)
    # Without transactions M3c is unchanged.
    @test run_m3c(m3c(work = [1, 3], transactions = false); seed = 1) == g
end

@testset "M3d: adversarial and edge cases" begin
    # A harmful agent's transactions are screened out, however many it proposes.
    agents = [DomainAgent([-0.8, 0.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0], 0.0) for _ in 1:4]
    tr = run_m3c(M3cParams(T3c, agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 4)
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
cdp(agents; kw...) = M3cParams(Tsmooth, agents, [1, 1, 2, 2], trues(4); LEGACY..., λpos = 0.05, λneg = 0.02, transactions = true,
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
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) + sum(tr.lane_supply; init = 0.0) - sum(tr.reinvested)  # lane supply: its cost and harm burnt (8.67)
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
    # (Attribution is imperfect by default, so a sliver of credit can stray its way; losses dominate.)
    @test tr.upstream_neg[5] < 0 && tr.upstream_pos[5] < 0.01 * abs(tr.upstream_neg[5])
    # Co-funders whose money was needed share the credit of StandCoin work.
    tr = run_m3c(m3c(work = [1], threshold = 1.0, novel_threshold = 1.0, coarse_threshold = 1.0, endowment = 2.0, transactions = true,
                     causal_distribution = true); seed = 1)
    @test tr.cofunder_credit > 0
    # Attribution noise leaves the books balanced.
    tr = run_m3c(cdp([makers(); bad]; p_upstream = 0.5, attribution_σ = 0.3); seed = 3)
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) + sum(tr.lane_supply; init = 0.0) - sum(tr.reinvested)  # lane supply: its cost and harm burnt (8.67)
    @test_throws ArgumentError m3c(p_upstream = 1.5)
    @test_throws ArgumentError m3c(cc_threshold = 1.5)
end

# Contribution types (author ruling, BACKPROPAGATION 8.22; L96: CD ∝ CC + N_CCtype). Carrying another
# agent's output on, outside any contract, is a communicative contribution and earns an accolade, a
# minor share of what the output carried; under contract it is paid as the contracted share, as
# completion of the contract, not as contribution. Losses stay with whoever caused them.
@testset "Contribution types: acceptance" begin
    # (A controlled world: the claim is about the shares, with markers as exact as they were.)
    free = run_m3c(cdp([makers(); passers()]; accolade_rate = 0.05, p_contracted = 0.0, LEGACY...); seed = 1)
    @test free.accolade_credit > 0 && free.contract_credit == 0
    # Carriers' net credit is about their accolades (noise in measurement and attribution moves
    # credit both ways), far below what the makers earn.
    net = sum(free.credit_pos[4:6] .+ free.credit_neg[4:6])
    @test isapprox(net, free.accolade_credit; rtol = 0.4) && net < 0.1 * sum(free.upstream_pos[1:3])
    hired = run_m3c(cdp([makers(); passers()]; contract_share = 0.2, p_contracted = 1.0, LEGACY...); seed = 1)
    @test hired.contract_credit > 0 && hired.accolade_credit == 0
    @test sum(hired.credit_pos[4:6]) > sum(free.credit_pos[4:6])
    for tr in (free, hired)
        @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) + sum(tr.lane_supply; init = 0.0) - sum(tr.reinvested)  # lane supply: its cost and harm burnt (8.67)
    end
end

@testset "Contribution types: adversarial and edge cases" begin
    # A carrier never takes a share of a loss it did not cause: bad outputs stay with their maker.
    bad = [DomainAgent([-0.3, 0, 0, 0], [1.0, 0, 0, 0], 0.0)]
    tr = run_m3c(cdp([makers(); bad]; p_contracted = 1.0); seed = 2)
    @test tr.upstream_neg[4] < 0
    @test_throws ArgumentError m3c(accolade_rate = 1.5)
    @test_throws ArgumentError m3c(contract_share = -0.1)
end

@testset "Contribution-type rules (Lean reference)" begin
    @test carry_fee(2.0, false; accolade_rate = 0.05, contract_share = 0.2) ≈ 0.1
    @test carry_fee(2.0, true; accolade_rate = 0.05, contract_share = 0.2) ≈ 0.4
    @test carry_fee(-1.0, true; accolade_rate = 0.05, contract_share = 0.2) == 0  # no fee out of a loss
    @test_throws ArgumentError carry_fee(1.0, false; accolade_rate = 1.5, contract_share = 0.2)
end

@testset "Deep transaction trees (L95)" begin
    Ts_deep = ToyParams(n = 30, steps = 200, plans = 6, spread = 0.05)
    ag_deep = [DomainAgent([0.6], [1.0], 0.0), DomainAgent([0.6], [1.0], 0.0), DomainAgent([0.0], [1.0], 0.0)]

    tr_sh = run_m3c(M3cParams(Ts_deep, ag_deep, [1], trues(1); LEGACY..., λpos = 0.05, λneg = 0.02,
                              transactions = true, causal_distribution = true, p_upstream = 1.0, upstream_depth = 3); seed = 42)
    @test tr_sh.max_upstream_degree == 3
    @test tr_sh.upstream_pos_by_degree[1] > tr_sh.upstream_pos_by_degree[2] > tr_sh.upstream_pos_by_degree[3] > 0

    tr_fb25 = run_m3c(M3cParams(Ts_deep, ag_deep, [1], trues(1); LEGACY..., λpos = 0.05, λneg = 0.02,
                                transactions = true, causal_distribution = true, p_upstream = 1.0, upstream_depth = 3,
                                attribution_σ = 2.0, traversal_decay = 0.25); seed = 42)
    tr_fb75 = run_m3c(M3cParams(Ts_deep, ag_deep, [1], trues(1); LEGACY..., λpos = 0.05, λneg = 0.02,
                                transactions = true, causal_distribution = true, p_upstream = 1.0, upstream_depth = 3,
                                attribution_σ = 2.0, traversal_decay = 0.75); seed = 42)
    @test tr_fb25.fallback_outcomes > 0 && tr_fb25.max_upstream_degree == 3
    @test tr_fb75.upstream_pos_by_degree[2] > tr_fb25.upstream_pos_by_degree[2] > 0
    @test tr_fb75.upstream_pos_by_degree[3] > tr_fb25.upstream_pos_by_degree[3] > 0
    @test_throws ArgumentError m3c(upstream_depth = 0)
end

@testset "Open log as universal source of truth (Step 5)" begin
    Ts_log = ToyParams(n = 30, steps = 200, plans = 6, spread = 0.05)
    ag_log = [DomainAgent([0.6], [1.0], 0.0), DomainAgent([0.6], [1.0], 0.0), DomainAgent([0.0], [1.0], 0.0)]
    ag_form = [DomainAgent([0.6, 0.4, 0.4], [0.4, 0.3, 0.3], 0.0) for _ in 1:3]

    runs = [
        run_m3c(M3cParams(Ts_log, ag_log, [1], trues(1); LEGACY..., λpos = 0.05, λneg = 0.02, memory_loss = 0.0,
                          transactions = true, causal_distribution = true, p_upstream = 1.0, upstream_depth = 3,
                          p_new_model = 0.1, takeover_records = 5, min_records = 5); seed = 42),
        run_m3c(M3cParams(ToyParams(n = 30, steps = 160, plans = 6), ag_form, [1, 1, 2], [true, true, false];
                          LEGACY..., λpos = 0.05, λneg = 0.02, memory_loss = 0.0, form_count = 4, form_radius = 1.5, max_new = 3,
                          transactions = true, causal_distribution = true, p_upstream = 1.0, upstream_depth = 3); seed = 9),
        run_m3c(M3cParams(Ts_log, ag_log, [1], trues(1); LEGACY..., λpos = 0.05, λneg = 0.02, memory_loss = 0.0,
                          events = [shock(:outage; step = 40, duration = 20)],
                          transactions = true, causal_distribution = true, p_upstream = 1.0, upstream_depth = 2); seed = 11),
        run_m3c(M3cParams(Ts_log, ag_log, [1], trues(1); LEGACY..., λpos = 0.05, λneg = 0.02, memory_loss = 0.0,
                          advap = true, p_new_model = 0.1, takeover_records = 5, min_records = 5,
                          deceit = [0.4, 0.0, 0.0], accuracy_rule = :decay); seed = 7),
        run_m3c(M3cParams(Ts_log, ag_log, [1], trues(1); LEGACY..., λpos = 0.05, λneg = 0.02, memory_loss = 0.0,
                          advap = true, p_new_model = 0.1, takeover_records = 5, min_records = 5,
                          deceit = [0.4, 0.0, 0.0], accuracy_rule = :window); seed = 7),
    ]
    for tr in runs
        hp, hn, rel = recount(tr)
        @test isapprox(hp, tr.h_pos_own; atol = 1e-10)
        @test isapprox(hn, tr.h_neg_own; atol = 1e-10)
        @test isapprox(rel, tr.relevance_own; atol = 1e-10)
        @test isapprox(recount_μ(tr), tr.μ; atol = 1e-10)
        @test isapprox(recount_models(tr).leaf_accuracy, tr.leaf_accuracy; atol = 1e-10)
        rcc = recount_cc(tr)
        @test isapprox(rcc.credit_pos, tr.credit_pos; atol = 1e-10)
        @test isapprox(rcc.credit_neg, tr.credit_neg; atol = 1e-10)
        @test isapprox(rcc.upstream_pos, tr.upstream_pos; atol = 1e-10)
        @test isapprox(rcc.upstream_neg, tr.upstream_neg; atol = 1e-10)
        @test isapprox(rcc.upstream_pos_by_degree, tr.upstream_pos_by_degree; atol = 1e-10)
        @test isapprox(rcc.upstream_neg_by_degree, tr.upstream_neg_by_degree; atol = 1e-10)
    end
end
