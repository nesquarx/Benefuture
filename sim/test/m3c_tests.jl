# Toy model M3c: M3b on the domain network. Leaves hold shares; parents are fuzzy sets of leaves
# whose degrees μ are learnt from memory. Classification descends from matched parents to member
# leaves; pricing falls back from ineligible currencies to eligible parents by μ, else to StandCoin,
# which predicts no value: work only it would take is priced at full resource cost and goes ahead
# if the proposer, with co-funding experts, can pay. Clustered blockages form novel leaves, which
# price only after a score-only phase at their (lower, never below 0.5) threshold.

const T3c = ToyParams(n = 80, steps = 200, plans = 10)
# Two parents of two known leaves each; `hidden` adds true leaves missing from the network (their
# primary parent, or 0 for a new top-level domain). Agents work only in the leaves listed.
function m3c(; hidden = Int[], work = [1], n_agents = 6, skill = 0.6, kw...)
    leaf_parent = [1, 1, 2, 2, hidden...]
    nl = length(leaf_parent)
    agents = [DomainAgent([l in work ? skill : 0.0 for l in 1:nl], [l in work ? 1 / length(work) : 0.0 for l in 1:nl], 0.0)
              for _ in 1:n_agents]
    M3cParams(T3c, agents, leaf_parent, [trues(4); falses(length(hidden))]; λpos = 0.02, λneg = 0.05, kw...)
end

@testset "M3c: acceptance" begin
    # A complete network: plans reach their true leaf; nothing forms; StandCoin pays no value.
    tr = run_m3c(m3c(work = [1, 3]); seed = 1)
    @test mean(tr.stop_leaf .== tr.true_leaf) > 0.95
    @test isempty(tr.formations)
    @test all(tr.balance[:, end] .<= tr.endowment + 1e-9)
    # A parent's reputation aggregates its member leaves' by μ, plus what stuck at it.
    for a in axes(tr.relevance_leaf, 1), p in axes(tr.μ, 1)
        @test tr.relevance_parent[a, p] ≈ aggregate_at_parent(tr.μ[p, :], tr.relevance_leaf[a, :]) + tr.relevance_resid[a, p]
    end
    # Incremental reputation equals a recount from memory; currency is conserved.
    @test all(recount(tr) .≈ (tr.h_pos_own, tr.h_neg_own, tr.relevance_own))
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) - sum(tr.reinvested)
    @test tr == run_m3c(m3c(work = [1, 3]); seed = 1)
    # Overlap: leaf 3 belongs to parent 2 and weakly (0.3) to parent 1; memory keeps both degrees.
    tr = run_m3c(m3c(work = [3], overlaps = [(3, 1, 0.3)]); seed = 2)
    @test tr.μ[2, 3] ≈ 1 atol = 0.05
    @test tr.μ[1, 3] ≈ 0.3 atol = 0.05
    # A hidden leaf under parent 1: blockages form a novel leaf there; it is scored but prices
    # nothing until it qualifies, then classifies and prices the hidden work.
    tr = run_m3c(m3c(hidden = [1], work = [1, 5]); seed = 2)
    @test length(tr.formations) == 1
    f = tr.formations[1]
    @test argmax(tr.μ[:, f.leaf]) == 1 && f.nearest_leaf == 5
    @test f.eligible_step > f.step
    @test !any(tr.priced_leaf[tr.chosen_step .< f.eligible_step] .== f.leaf)
    after = (tr.true_leaf .== 5) .& (tr.chosen_step .> f.eligible_step + 30)
    @test mean(tr.stop_leaf[after] .== f.leaf) > 0.9 && any(tr.priced_leaf[after] .== f.leaf)
end

@testset "M3c: adversarial and edge cases" begin
    # Without formation, work in the hidden leaf earns its parent's reputation, never a leaf's.
    tr = run_m3c(m3c(hidden = [1], work = [5], form_count = 10^6); seed = 2)
    @test isempty(tr.formations)
    @test all(iszero, tr.relevance_leaf) && all(tr.relevance_resid[:, 1] .> 0)
    # Work no qualified currency can value goes to StandCoin at full resource cost, but is still
    # screened by G on the best available (score-only) model: a harmful agent's work almost
    # never passes, and what passes is measured beneficial; unfunded work halts.
    harmful = m3c(work = [1], skill = -0.8, threshold = 0.99, novel_threshold = 0.99)
    tr = run_m3c(harmful; seed = 3)
    @test tr.lane_screened_out > 0.99 * (tr.lane_screened_out + tr.lane_executed + tr.lane_halted)
    @test all(>=(0), tr.lane_measured)
    tr = run_m3c(m3c(work = [1], threshold = 0.99, novel_threshold = 0.99, endowment = 0.0); seed = 3)
    @test tr.lane_executed == 0 && tr.lane_halted > 0
    # No currency qualifies: everything falls to StandCoin, and experts with reputation in the
    # work's parent co-fund it once proposers run short.
    tr = run_m3c(m3c(work = [1], threshold = 0.99, novel_threshold = 0.99, endowment = 2.0); seed = 1)
    @test isempty(tr.chosen_step) && tr.lane_executed > 0 && tr.cofunded > 0
    @test all(tr.balance[:, end] .>= -1e-9)
    # Scarcity: a small resource capacity raises the cost per touched being.
    cheap = run_m3c(m3c(work = [1], capacity = 1e6); seed = 1)
    dear = run_m3c(m3c(work = [1], capacity = 400.0); seed = 1)
    @test mean(dear.costs ./ dear.touched) > mean(cheap.costs ./ cheap.touched)
    # Every extra noise source at once: the books still balance and runs still repeat exactly.
    noisy = m3c(hidden = [1], work = [1, 5], marker_σ = 0.2, classify_σ = 0.08, bias_σ = 0.3, cost_σ = 0.3, regen_σ = 0.5,
                memory_loss = 0.1, participation = 0.5)
    tr = run_m3c(noisy; seed = 4)
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) - sum(tr.reinvested)
    @test tr == run_m3c(noisy; seed = 4)
    @test_throws ArgumentError m3c(memory_loss = 1.5)
    @test_throws ArgumentError m3c(parent_threshold = 0.0)
    @test_throws ArgumentError M3cParams(T3c, [DomainAgent([0.6], [1.0], 0.0)], [1, 1], trues(2); λpos = 0.02, λneg = 0.05)
    @test_throws ArgumentError m3c(form_count = 0)
    @test_throws ArgumentError m3c(overlaps = [(9, 1, 0.3)])
end

@testset "M3c: runs fast enough to iterate" begin
    leaf_parent = [[b for b in 1:3 for _ in 1:4]; [1, 2]]
    nl = length(leaf_parent)
    agents = [DomainAgent([l == k ? 0.6 : 0.0 for l in 1:nl], [l == k ? 1.0 : 0.0 for l in 1:nl], 0.5) for k in 1:nl for _ in 1:3]
    p = M3cParams(ToyParams(n = 200, steps = 300, plans = 20), agents, leaf_parent, [trues(12); falses(2)];
                  λpos = 0.02, λneg = 0.05, marker_σ = 0.1, overlaps = [(4, 2, 0.3), (8, 3, 0.3)])
    run_m3c(m3c(); seed = 1)
    @test (@elapsed run_m3c(p; seed = 1)) < 90
end
