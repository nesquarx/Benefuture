# Toy model M5: governance by weighted liquid democracy (L113 BfDm, L114 LqdBfDm). Decisions arise in
# domains; each agent's signal of the right option is sharper the more skilled it is there (a toy
# assumption); votes are weighted by base + expertise × domain reputation + impact (L113), voting
# optional below a threshold; an agent may delegate its vote in a domain to a higher-reputation
# agent while that agent's accumulated weight is under the cap, unless the delegator is heavily
# impacted (L114). Reputations come from an M3c run.

@testset "Voting rules (Lean reference): acceptance against the spec vectors" begin
    v = vectors("democracy")
    w, opt = voting_weight(1.0, 1.0, [0.6, 0.4], [4.0, 1.0], 1.0, 0.5; optional_below = 2.0)
    @test w ≈ v["voting_weight_expert"]["weight"] && opt == v["voting_weight_expert"]["vote_optional"]
    w, opt = voting_weight(1.0, 1.0, [0.6, 0.4], [0.0, 0.0], 1.0, 0.0; optional_below = 2.0)
    @test w ≈ v["voting_weight_bystander"]["weight"] && opt == v["voting_weight_bystander"]["vote_optional"]
    @test accumulate_capped(100.0, 0.0, fill(10.0, 30)) ≈ vectors("population")["delegation_capped_cap100_w10x30"]
end

@testset "Voting rules (Lean reference): adversarial and edge cases" begin
    # Domain-relative expertise (Government, discussion): reputations as shares of the domain's total.
    @test relative_reputation([3.0, 1.0, 0.0]) ≈ [0.75, 0.25, 0.0] && relative_reputation([0.0, 0.0]) == [0.0, 0.0]
    @test_throws ArgumentError relative_reputation([-1.0, 2.0])
    # However many delegate, a delegate never exceeds the cap plus one delegator's weight.
    @test accumulate_capped(5.0, 0.0, fill(3.0, 1000)) < 5.0 + 3.0
    @test_throws ArgumentError voting_weight(1.0, 1.0, [0.7, 0.7], [1.0, 1.0], 0.0, 0.0; optional_below = 1.0)
end

@testset "M5: acceptance" begin
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? 0.1 + 0.1 * r : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:5], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    # Expertise weighting decides better than one agent, one vote, when reputation tracks skill.
    # (Over seeds, where judgement is hard enough to separate them: with easy signals both are near
    # perfect.)
    eq = mean(run_m5(M5Params(m3, 1:4; expertise_weight = 0.0, decisions = 400, signal_σ = 6.0); seed).correct for seed in 1:4)
    bf = mean(run_m5(M5Params(m3, 1:4; decisions = 400, signal_σ = 6.0); seed).correct for seed in 1:4)
    @test bf > eq
    # Delegation under the cap: no delegate ever holds more than the cap plus one delegator's weight.
    dl = run_m5(M5Params(m3, 1:4; decisions = 200, p_delegate = 0.8, cap = 0.1); seed = 2)
    @test all(dl.max_share .<= 0.1 .+ dl.max_single .+ 1e-12)
    @test isequal(run_m5(M5Params(m3, 1:4; decisions = 50); seed = 3), run_m5(M5Params(m3, 1:4; decisions = 50); seed = 3))
    # Relative expertise keeps expertise from concentrating weight: no voter holds most of it.
    rel = run_m5(M5Params(m3, 1:4; decisions = 200); seed = 1)
    raw = run_m5(M5Params(m3, 1:4; decisions = 200, relative_expertise = false); seed = 1)
    @test mean(rel.max_share) < mean(raw.max_share)
end

@testset "M5: scalability (author ruling 8.22)" begin
    # LqdBfDm works at every scale: a household of five decides about as well as a polity of a
    # hundred, and normalised expertise keeps any one voter from dominating either.
    world(n_per) = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                                     [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / max(n_per - 1, 1) : 0.0 for l in 1:4],
                                                  [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:n_per],
                                     [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    small = run_m5(M5Params(world(2), 1:4; decisions = 400, expertise_weight = 5.0); seed = 1)   # 8 agents
    large = run_m5(M5Params(world(25), 1:4; decisions = 400, expertise_weight = 5.0); seed = 1)  # 100 agents
    @test small.correct > 0.9 && large.correct > 0.9
    @test mean(large.max_share) < 0.5 && mean(small.max_share) < 0.6
end

@testset "M5: convergence under heavy friction (author ruling 8.31)" begin
    # Epistemic antifragility: start from wrong priors (in each domain the least skilled hold the
    # most reputation) under heavy friction (signal noise 40, each voter's ceiling scattered by a
    # factor of e around the expertise trend, outcomes apparent only 40% of the time). Vote
    # reputation re-sorts the voters: decisions start worse and converge to where true priors stand.
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? 0.1 + 0.1 * r : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:5], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    inverted = copy(m3.relevance_leaf)
    for d in 1:4
        idx = [5(d - 1) + r for r in 1:5]
        inverted[idx, d] = reverse(sort(inverted[idx, d]))
    end
    heavy(rep, seed) = run_m5(M5Params(m3, 1:4; decisions = 2000, signal_σ = 40.0, ability_spread = 1.0, p_apparent = 0.4,
                                       diversity = false, reputation = rep); seed)
    truth_runs = [heavy(nothing, seed) for seed in 1:16]
    wrong_runs = [heavy(inverted, seed) for seed in 1:16]
    window(runs, r) = mean(mean(tr.correct_trace[r]) for tr in runs)
    @test window(wrong_runs, 1:100) < window(wrong_runs, 1601:2000) - 0.01
    @test window(wrong_runs, 1601:2000) > window(truth_runs, 1601:2000) - 0.01
end

@testset "M5: adversarial and edge cases" begin
    # Specialists in each domain; the others, unaffected by a domain's decisions, may delegate to them.
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? 0.1 + 0.1 * r : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:5], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    # Without a cap, delegation concentrates weight; the cap prevents it.
    uncapped = run_m5(M5Params(m3, 1:4; decisions = 100, p_delegate = 1.0, cap = 1.0); seed = 1)
    capped = run_m5(M5Params(m3, 1:4; decisions = 100, p_delegate = 1.0, cap = 0.2); seed = 1)
    @test maximum(uncapped.max_share) > maximum(capped.max_share)
    @test_throws ArgumentError M5Params(m3, 1:4; cap = 0.0)
end

# Clean deliberation (Government: proposals carry truth-level tagging and source tracking; author
# guidance 8.42.2: models take over prediction in governance). Before voting each voter hears its own
# reading, a few contacts' (`n_contacts`, a social network) and the domain's models' published
# predictions, and weighs each source by its audited record (votes and published predictions on
# decisions whose outcome became apparent: source tracking scores what each source published, a
# person's own reading), by log-odds of its record's accuracy (Nitzan and Paroush, 1982: the optimal
# weights for independent binary judges). Models do not vote; new ones are assumed to keep arriving,
# better on average (as in the economy, 8.42.2).
@testset "M5 clean deliberation and better models" begin
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    hard(; kw...) = M5Params(m3, 1:4; decisions = 1200, signal_σ = 20.0, kw...)  # hard decisions (8.31)
    seeds = 1:3
    alone = [run_m5(hard(); seed) for seed in seeds]
    talk = [run_m5(hard(deliberation = true); seed) for seed in seeds]
    models = [run_m5(hard(deliberation = true, p_new_model = 0.02); seed) for seed in seeds]
    late(r) = mean(r.correct_trace[801:end])
    # Better models take over prediction: their share of the weight in voters' readings grows.
    @test all(mean(r.model_weight[801:end]) > mean(r.model_weight[1:400]) for r in models)
    # Finding 8.43: the votes stop being independent. Every voter weighs the same shared sources,
    # so errors correlate and the decision tends to those sources' own accuracy; a crowd of
    # independent experts aggregates better than any source weaker than its aggregate. Hearing
    # contacts costs a little, hearing models weaker than the crowd costs more.
    @test mean(late.(talk)) < mean(late.(alone)) && mean(late.(models)) < mean(late.(talk))
    # A model that slips loses its weight: a capture making the best model of domain 1 publish one
    # side costs it its record.
    slip = [run_m5(hard(deliberation = true, p_new_model = 0.02, model_capture = (decision = 600, duration = 300, domain = 1)); seed) for seed in seeds]
    @test mean(r.captured_weight_start for r in slip) > 0.2 && all(r.captured_weight_end < 0.05 for r in slip)
    # No deliberation, nothing changes; guards.
    @test isequal(run_m5(hard(deliberation = false, p_new_model = 0.0); seed = 1), run_m5(hard(); seed = 1))
    @test_throws ArgumentError hard(deliberation = true, n_contacts = -1)
    @test_throws ArgumentError hard(deliberation = true, p_new_model = 2.0)
end
