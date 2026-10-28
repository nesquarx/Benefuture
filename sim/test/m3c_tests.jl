# Toy model M3c: M3b on a domain tree. Classification descends the tree; a plan stuck at a branch
# is priced by the nearest eligible ancestor; one stuck at the root (StandCoin, which predicts no
# value) leaves the menu as a novelty signal. Repeated blockages at a node form a new subdomain,
# whose model is scored on predictions alone until eligible; reputation is recounted from memory.

const T3c = ToyParams(n = 80, steps = 200, plans = 10)
# Two branches of two known leaves each; `hidden` adds true leaves missing from the initial tree
# (branch index, or 0 for a new top-level domain). Agents work only in the leaves listed.
function m3c(; hidden = Int[], work = [1], n_agents = 6, skill = 0.6, kw...)
    leaf_branch = [1, 1, 2, 2, hidden...]
    nl = length(leaf_branch)
    agents = [DomainAgent([l in work ? skill : 0.0 for l in 1:nl], [l in work ? 1 / length(work) : 0.0 for l in 1:nl], 0.0)
              for _ in 1:n_agents]
    M3cParams(T3c, agents, leaf_branch, [trues(4); falses(length(hidden))]; λpos = 0.02, λneg = 0.05, kw...)
end

@testset "M3c: acceptance" begin
    # A complete tree: plans reach their true leaf; nothing forms; StandCoin pays no value.
    tr = run_m3c(m3c(work = [1, 3]); seed = 1)
    @test mean(tr.stop_node .== tr.leaf_node[tr.true_leaf]) > 0.95
    @test isempty(tr.formations)
    @test all(tr.balance[:, 1] .<= tr.endowment + 1e-9)
    # Subtree sums: a branch's total is its own plus its leaves'; a leaf's is its own.
    for a in axes(tr.relevance_own, 1)
        @test tr.relevance[a, :] ≈ subtree_sum(tr.parents, tr.relevance_own[a, :])
    end
    # Incremental reputation equals a recount from memory.
    @test all(recount(tr) .≈ (tr.h_pos_own, tr.h_neg_own, tr.relevance_own))
    # Currency moves by measured value in valued shares, less resource cost, less overflow.
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.reinvested)
    @test tr == run_m3c(m3c(work = [1, 3]); seed = 1)
    # A hidden leaf under branch 1: plans stick at the branch until blockages form a subdomain
    # there, near the hidden leaf; its model qualifies, and later plans stop and are priced at it.
    tr = run_m3c(m3c(hidden = [1], work = [5]); seed = 2)
    @test length(tr.formations) == 1
    f = tr.formations[1]
    @test f.parent == tr.branch_node[1] && f.nearest_leaf == 5
    after = tr.chosen_step .> f.step + 30
    @test mean(tr.stop_node[after] .== f.node) > 0.9
    @test any(tr.priced_node[after] .== f.node)
    # A hidden top-level domain: stuck at the root, never chosen until a top-level domain forms.
    tr = run_m3c(m3c(hidden = [0], work = [5]); seed = 3)
    @test length(tr.formations) == 1 && tr.formations[1].parent == 1
    @test all(tr.chosen_step .> tr.formations[1].step)
    @test tr.root_blocked > 0
end

@testset "M3c: adversarial and edge cases" begin
    # Without enough blockages nothing forms, and work in the hidden leaf earns the branch's
    # reputation, never a leaf's.
    tr = run_m3c(m3c(hidden = [1], work = [5], form_count = 10^6); seed = 2)
    @test isempty(tr.formations)
    @test all(iszero, tr.relevance_own[:, tr.leaf_node[1:4]]) && all(tr.relevance[:, tr.branch_node[1]] .> 0)
    # A subdomain's reputation never includes its parent's.
    @test all(iszero, tr.relevance[:, tr.leaf_node[1:2]])
    # StandCoin never pays for value.
    tr = run_m3c(m3c(hidden = [0], work = [5]); seed = 3)
    @test all(tr.balance[:, 1] .<= tr.endowment + 1e-9)
    # Scarcity: a small resource capacity raises the cost per touched being.
    cheap = run_m3c(m3c(work = [1], capacity = 1e6); seed = 1)
    dear = run_m3c(m3c(work = [1], capacity = 400.0); seed = 1)
    @test mean(dear.costs ./ dear.touched) > mean(cheap.costs ./ cheap.touched)
    @test_throws ArgumentError m3c(thresholds = [0.8])
    @test_throws ArgumentError M3cParams(T3c, [DomainAgent([0.6], [1.0], 0.0)], [1, 1], trues(2); λpos = 0.02, λneg = 0.05)
    @test_throws ArgumentError m3c(form_count = 0)
end

@testset "M3c: runs fast enough to iterate" begin
    leaf_branch = [b for b in 1:3 for _ in 1:4]
    append!(leaf_branch, [1, 2, 0])
    nl = length(leaf_branch)
    agents = [DomainAgent([l == k ? 0.6 : 0.0 for l in 1:nl], [l == k ? 1.0 : 0.0 for l in 1:nl], 0.5) for k in 1:nl for _ in 1:3]
    p = M3cParams(ToyParams(n = 200, steps = 300, plans = 20), agents, leaf_branch, [trues(12); falses(3)];
                  λpos = 0.02, λneg = 0.05, marker_σ = 0.1)
    run_m3c(m3c(); seed = 1)
    @test (@elapsed run_m3c(p; seed = 1)) < 90
end
