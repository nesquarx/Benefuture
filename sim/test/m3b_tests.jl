# Toy model M3b: profiles measured, not declared. Each domain has a causal signature; a plan's
# causal vector lies near the signature of the domain it works in, or far from all of them when
# the scenario is new. Currency metric models classify the measured vector (StandCoin and an
# adjudication flag when nothing matches); prices, payments and reputation follow that profile;
# plans an agent cannot afford in some domain leave the menu; overflow is reinvested.

const W3b = M1Params(ToyParams(n = 80, steps = 150, plans = 10), [MetricModel(0.0, 0.0)], 0.0, 10)
m3b(agents; kw...) = M3bParams(W3b, agents; kw...)

@testset "M3b: acceptance" begin
    # One domain, no novelty, no cost, no overflow: floors reproduce M2 and balances M2's plus the endowment.
    skills = collect(range(-0.3, 0.6; length = 12))
    m2 = run_m2(M2Params(W3b, [Agent(s, 0.0) for s in skills], 0.02); seed = 4)
    tr = run_m3b(m3b([DomainAgent([s], [1.0], 0.0) for s in skills]; λpos = 0.02, λneg = 0.02,
                     endowment = 1e9, cost_per_touch = 0.0, overflow_base = Inf); seed = 4)
    @test tr.floor_u == m2.floor_u
    @test tr.relevance[:, 1] ≈ m2.reputation
    @test tr.balance[:, 1] .- 1e9 ≈ m2.balance atol = 1e-3
    # Measured profiles: a generalist skilled in domain 2 only earns relevance there, whatever
    # domains it also works in.
    D = 3
    agents = [DomainAgent([d == 2 ? 0.6 : 0.0 for d in 1:D], fill(1 / D, D), 0.0) for _ in 1:6]
    tr = run_m3b(m3b(agents; λpos = 0.05, λneg = 0.02); seed = 2)
    @test all(argmax(tr.relevance[a, 1:D]) == 2 for a in eachindex(agents))
    # Conservation: balances move by measured value less resource cost, less what overflowed.
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.measured) - sum(tr.costs) - sum(tr.reinvested)
    @test vec(sum(tr.h_pos .- tr.h_neg; dims = 2)) ≈ tr.measured
    @test tr == run_m3b(m3b(agents; λpos = 0.05, λneg = 0.02); seed = 2)
end

@testset "M3b: adversarial and edge cases" begin
    # Declaring a profile buys nothing: an agent's focus only says where it works; reputation
    # follows where its effects are classified.
    D = 2
    honest = [DomainAgent([0.6, 0.0], [1.0, 0.0], 0.0) for _ in 1:4]
    tr = run_m3b(m3b(honest; λpos = 0.05, λneg = 0.02, classify_σ = 0.0); seed = 1)
    @test all(iszero, tr.h_pos[:, 2]) && all(iszero, tr.balance[:, 2] .- tr.endowment)
    # New scenarios go to StandCoin and are flagged for adjudication.
    tr = run_m3b(m3b(honest; λpos = 0.05, λneg = 0.02, novelty = 1.0); seed = 1)
    @test !isempty(tr.flagged) && all(iszero, tr.h_pos[:, 1:D]) && sum(tr.h_pos[:, D + 1]) > 0
    # Prices: without funds in a domain, costly plans leave the menu.
    tr = run_m3b(m3b(honest; λpos = 0.05, λneg = 0.02, endowment = 0.0, cost_per_touch = 100.0); seed = 1)
    @test all(==(0), tr.chosen_agent) && all(iszero, tr.balance)
    # Overflow keeps every balance at or under its threshold and reinvests the excess in its domain.
    tr = run_m3b(m3b(honest; λpos = 0.05, λneg = 0.02, endowment = 0.0, overflow_base = 1.0, overflow_factor = 0.0); seed = 1)
    @test all(tr.balance .<= 1.0 + 1e-9) && tr.reinvested[1] > 0 && tr.reinvested[2] == 0
    @test_throws ArgumentError m3b(honest; λpos = 0.05, λneg = 0.02, novelty = 1.5)
    @test_throws ArgumentError m3b(honest; λpos = 0.05, λneg = 0.02, endowment = -1.0)
end

@testset "M3b: runs fast enough to iterate" begin
    D = 5
    agents = [DomainAgent([i == d ? 0.6 : 0.0 for i in 1:D], fill(1 / D, D), 0.5) for d in 1:D for _ in 1:10]
    p = M3bParams(M1Params(ToyParams(n = 200, steps = 300, plans = 20), [MetricModel(0.0, 0.5), MetricModel(0.0, 0.2)], 0.1, 10),
                  agents; λpos = 0.05, λneg = 0.02, novelty = 0.05)
    run_m3b(m3b(agents[1:2]; λpos = 0.05, λneg = 0.02); seed = 1)
    @test (@elapsed run_m3b(p; seed = 1)) < 90
end
