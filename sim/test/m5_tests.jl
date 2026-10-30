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
    # LqdBfDm works at every scale: a household of eight decides about as well as a polity of a
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
    # Better models take over prediction: their share of the weight in voters' readings grows, slowly
    # where they must first outdo the experts the network surfaces.
    @test mean(mean(r.model_weight[801:end]) for r in models) > mean(mean(r.model_weight[1:400]) for r in models)
    # With IH's full ContentionMap and realistic advice taking (8.63: most people move little), deliberation
    # costs nothing on these purely factual decisions; 8.45's echo cost returns only in the limiting case
    # where everyone defers, each layman recasting what it heard with a full vote (findings 8.43, 8.45).
    @test abs(mean(late.(talk)) - mean(late.(alone))) < 0.01 && mean(late.(models)) >= mean(late.(alone)) - 0.01
    defer = [run_m5(hard(deliberation = true, advice_stay = 0.0, advice_avg = 0.0, advice_defer = 1.0); seed) for seed in seeds]
    @test mean(late.(defer)) < mean(late.(alone)) - 0.01
    # A model that slips loses its weight: a capture making the best model of domain 1 publish one
    # side costs it its record.
    slip = [run_m5(hard(deliberation = true, p_new_model = 0.02, model_capture = (decision = 600, duration = 300, domain = 1)); seed) for seed in seeds]
    @test mean(r.captured_weight_start for r in slip) > 0.2 && all(r.captured_weight_end < 0.05 for r in slip)
    # No deliberation, nothing changes; guards.
    @test isequal(run_m5(hard(deliberation = false, p_new_model = 0.0); seed = 1), run_m5(hard(); seed = 1))
    @test_throws ArgumentError hard(deliberation = true, n_contacts = -1)
    @test_throws ArgumentError hard(deliberation = true, p_new_model = 2.0)
end

# Contention (author, on 8.44): experts divided, the voters listening to all and judging through the
# network's information handling (its ContentionMap surfaces the most reputable sources on each side,
# L133) and their own limited expertise, with diversity (L158) trying the option not chosen. The top
# experts of each domain split into two camps of equal standing; one camp's paradigm leans to one
# option (an honest systematic bias), so on contested questions they disagree.
@testset "M5 contention among experts" begin
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    c, bias = 1.0, zeros(100)
    for d in 1:4, (r, a) in enumerate(sortperm(m3.relevance_leaf[:, d]; rev = true)[1:10])
        iseven(r) && (bias[a] = -c)
    end
    contested(r) = mean(r.final_trace[i] for i in eachindex(r.truth_trace) if 0 < r.truth_trace[i] < c)
    run(; kw...) = [run_m5(M5Params(m3, 1:4; decisions = 1600, signal_σ = 20.0, camp_bias = bias, kw...); seed) for seed in 1:4]
    neither, trials, both = run(diversity = false), run(), run(deliberation = true)
    # Hearing both sides weighed by their records, with trials revealing outcomes, finds the
    # performant option on contested questions far more often than trials alone or neither.
    @test mean(contested.(both)) > mean(contested.(trials)) + 0.03 && mean(contested.(trials)) > mean(contested.(neither)) + 0.03
    @test_throws ArgumentError M5Params(m3, 1:4; camp_bias = [1.0])
end

# Source tags (author ruling on 8.45; L133 IH): echoes must not count information many times. Each
# reading carries the tags of the sources it came from; a listener hearing several contacts that
# repeat one source hears it once, and an echo of the listener itself is not a source. Tags inform;
# they move no weight (author ruling 8.60): every voter votes or delegates with its full expertise and
# impact weight, sources are credited as experts through their records, and models never vote.
@testset "Source tags (Lean reference): acceptance" begin
    # Count once by origin: a repeated origin carries weight only at its first occurrence.
    @test count_once([1.0, 2.0, 1.0, 3.0, 2.0], [0.5, 1.0, 0.5, 2.0, 1.0]) == [0.5, 1.0, 0.0, 2.0, 0.0]
    # A reading: own weight × own side + each distinct origin's weight × its side.
    @test tagged_reading(0.0, 1.0, 1.0, [7.0, 7.0, 8.0], [-1.0, -1.0, 1.0], [2.0, 2.0, 1.0]) ≈ 1.0 - 2.0 + 1.0
    # A tag is audited against the source's logged output (AdvAp reads the open log).
    @test tags_falsified([1.0, -1.0, 1.0], [1.0, 1.0, 1.0]) == 1 && tags_falsified([1.0], [1.0]) == 0
    # Undisclosed echo: agreement with what one heard far above what two independent judges of
    # those accuracies would show, beyond the governed margin.
    @test undisclosed_echo(100, 100, 0.85, 0.85; margin = 0.1, z = 3.0)
    @test !undisclosed_echo(78, 100, 0.9, 0.85; margin = 0.1, z = 3.0)
end

@testset "Source tags (Lean reference): adversarial and edge cases" begin
    # However often a source is repeated, it is heard once: a thousand echoes of one source weigh as one.
    @test tagged_reading(0.0, 1.0, 1.0, fill(5.0, 1000), fill(-1.0, 1000), fill(3.0, 1000)) ≈ 1.0 - 3.0
    # An echo of the listener itself is not a source.
    @test tagged_reading(9.0, 1.0, 1.0, [9.0], [1.0], [5.0]) ≈ 1.0
    # No sources, the reading is one's own.
    @test tagged_reading(0.0, 1.0, -1.0, Float64[], Float64[], Float64[]) == -1.0
    # Malformed inputs are rejected.
    @test_throws ArgumentError count_once([1.0, 2.0], [1.0])
    @test_throws ArgumentError count_once([1.0], [-1.0])
    @test_throws ArgumentError count_once([NaN], [1.0])
    @test_throws ArgumentError tagged_reading(0.0, -1.0, 1.0, [1.0], [1.0], [1.0])
    @test_throws ArgumentError tagged_reading(0.0, 1.0, 2.0, [1.0], [1.0], [1.0])  # sides are ±1 or 0
    @test_throws ArgumentError tags_falsified([1.0], [1.0, 1.0])
    @test_throws ArgumentError undisclosed_echo(5, 4, 0.9, 0.9; margin = 0.1, z = 3.0)
    @test_throws ArgumentError undisclosed_echo(5, 10, 1.2, 0.9; margin = 0.1, z = 3.0)
    # Nothing heard, nothing flagged; a coin-toss agreement is no echo.
    @test !undisclosed_echo(0, 0, 0.9, 0.9; margin = 0.1, z = 3.0) && !undisclosed_echo(50, 100, 0.5, 0.5; margin = 0.1, z = 3.0)
end

# DeMarzo, Vayanos and Zwiebel (2003, QJE, https://doi.org/10.1162/00335530360698469): persuasion bias.
# Listeners who cannot tell what their contacts' readings already contain count information heard
# along many paths many times; after T rounds of untagged updating a listener's weight on an origin
# is the number of walks of length at most T to it, so influence follows network position, not
# precision. Source tags remove the bias: each reachable origin is heard once.
@testset "SOTA #4: persuasion bias (DeMarzo–Vayanos–Zwiebel) and its removal by tags" begin
    n = 20  # agent 1 is a hub everyone hears; the rest hear the hub and their two ring neighbours
    listens = [i == 1 ? [2] : [1, mod1(i - 1, n), mod1(i + 1, n)] for i in 1:n]
    listens = [filter(!=(i), unique(l)) for (i, l) in enumerate(listens)]
    A = zeros(n, n)
    for i in 1:n, j in listens[i]
        A[i, j] = 1.0
    end
    T = 3
    untagged = echo_influence(listens, T; tagged = false)
    tagged = echo_influence(listens, T; tagged = true)
    walks = sum(A^t for t in 0:T)
    @test untagged ≈ walks  # the DVZ weights: walks of length ≤ T
    # Bias: a peripheral listener weighs the hub far above an equally precise peer it also reaches.
    @test untagged[5, 1] > 3 * untagged[5, 7]
    # Tags: every reachable origin once, the unreachable not at all.
    @test all(tagged .== (walks .> 0))
    @test tagged[5, 1] == tagged[5, 7] == 1.0
    # With equally precise signals, the tagged estimate is closer to the truth than the untagged.
    rng = Xoshiro(45)
    err(W) = mean(begin
                     x = randn(rng, n)  # signals around a truth of zero, unit noise
                     mean(((W * x) ./ vec(sum(W; dims = 2))) .^ 2)
                 end for _ in 1:4000)
    @test err(tagged) < err(untagged)
    @test_throws ArgumentError echo_influence(listens, -1; tagged = true)
    @test_throws ArgumentError echo_influence([[3]], 1; tagged = true)  # a listener hears only agents
end

@testset "M5 source tags: echoes counted once (8.45)" begin
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    hard(; kw...) = M5Params(m3, 1:4; decisions = 1200, signal_σ = 20.0, kw...)
    late(r) = mean(r.correct_trace[801:end])
    seeds = 1:3
    alone = mean(late(run_m5(hard(); seed)) for seed in seeds)
    ih = mean(late(run_m5(hard(deliberation = true); seed)) for seed in seeds)
    ih_tags = [run_m5(hard(deliberation = true, source_tags = true); seed) for seed in seeds]
    three = mean(late(run_m5(hard(deliberation = true, rounds = 3); seed)) for seed in seeds)
    three_tags = mean(late(run_m5(hard(deliberation = true, rounds = 3, source_tags = true); seed)) for seed in seeds)
    # Counting each origin once stops echoes compounding as readings pass on round after round
    # (persuasion bias): over three rounds the tagged network decides better than the untagged.
    @test three_tags > three + 0.03
    # Tags move no weight (8.60): every voter casts its full weight, the largest share cast is the
    # same as untagged, and no weight is lost.
    @test all(r.max_share == run_m5(hard(deliberation = true); seed = s).max_share for (s, r) in zip(seeds, ih_tags))
    @test all(r.weight_gap < 1e-9 for r in ih_tags)
    # Influence is inevitable (8.60): in one round tags change nothing, and laymen voting what the
    # ContentionMap's few sources said still recast those sources' information with full weight, so
    # the echo cost of 8.45 stays in the tally (finding 8.59).
    @test abs(mean(late.(ih_tags)) - ih) < 0.01
    @test mean(late.(ih_tags)) < alone - 0.03
    # Off, nothing changes.
    @test isequal(run_m5(hard(deliberation = true, source_tags = false); seed = 1), run_m5(hard(deliberation = true); seed = 1))
    @test_throws ArgumentError hard(deliberation = true, rounds = 0)
    @test_throws ArgumentError hard(source_tags = true)  # tags tag deliberation's readings
end

# Weight on advice (author note 8.63; docs/CALIBRATION.md): hearing an expert does not always change a
# mind. Per person and domain a weight w on what was heard: with sources' records visible (IH), about 20%
# stay put (w = 0), 20% average, 5% defer, the rest Beta(2, 3) between; mean about 0.37 (Soll and
# Larrick 2009; Bailey et al.; docs/CALIBRATION.md 1.4).
@testset "M5 weight on advice (8.63): acceptance" begin
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    talk(; kw...) = M5Params(m3, 1:4; decisions = 300, signal_σ = 20.0, deliberation = true, kw...)
    r = run_m5(talk(); seed = 1)
    w = r.advice_weight
    @test size(w) == (100, 4) && all(0 .<= w .<= 1)
    @test 0.15 <= mean(w .== 0) <= 0.25 && 0.32 <= mean(w) <= 0.42
    # Nobody listening, deliberation changes no mind; everyone deferring changes the most.
    stay = run_m5(talk(advice_stay = 1.0, advice_avg = 0.0, advice_defer = 0.0); seed = 1)
    defer = run_m5(talk(advice_stay = 0.0, advice_avg = 0.0, advice_defer = 1.0); seed = 1)
    @test all(==(0.0), stay.minds_changed)
    @test mean(defer.minds_changed) > mean(r.minds_changed) > 0
    # The same holds with source tags.
    stay_t = run_m5(talk(source_tags = true, advice_stay = 1.0, advice_avg = 0.0, advice_defer = 0.0); seed = 1)
    @test all(==(0.0), stay_t.minds_changed)
end

@testset "M5 weight on advice (8.63): adversarial and edge cases" begin
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 50, plans = 10),
                           [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4)); seed = 1)
    @test_throws ArgumentError M5Params(m3, [1]; advice_stay = 0.6, advice_avg = 0.5)
    @test_throws ArgumentError M5Params(m3, [1]; advice_defer = -0.1)
    @test_throws ArgumentError M5Params(m3, [1]; advice_α = 0.0)
    # A Beta-only population (no point masses) stays within [0, 1] with the Beta mean.
    p = M5Params(m3, [1]; advice_stay = 0.0, advice_avg = 0.0, advice_defer = 0.0, deliberation = true, decisions = 5)
    @test abs(mean(BenefutureSim.advice_weights(p, 4000, 1, Xoshiro(3))) - 0.4) < 0.02
end

# Gaming check: tags are outputs, auditable by AdvAp against the open log (L160). Misattribution
# (claiming a reputable source backs one's side, or slandering it) and laundering by omission
# (presenting borrowed readings as one's own, claiming independence).
@testset "M5 source tags: gaming (misattribution and laundering)" begin
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    liars = collect(1:5:100)  # twenty voters across the ranks
    talk(; kw...) = M5Params(m3, 1:4; decisions = 800, signal_σ = 20.0, deliberation = true, info_handling = false, rounds = 2, kw...)
    seeds = 1:3
    # Untagged, a liar's republished reading carries its claim, and the decisions suffer.
    plain = mean(run_m5(talk(); seed).correct for seed in seeds)
    plain_lies = mean(run_m5(talk(tag_liars = liars, tag_lie = :misattribute); seed).correct for seed in seeds)
    @test plain_lies < plain - 0.01
    # Tagged but unaudited, a listener takes a claimed side at its word, so the lie still costs
    # decisions; audited, the claim is read against the log, every falsified tag is caught and
    # debited to its maker, and the cost is mostly gone.
    honest = run_m5(talk(source_tags = true); seed = 1)
    unaudited_lies = mean(run_m5(talk(source_tags = true, tag_audit = false, tag_liars = liars, tag_lie = :misattribute); seed).correct for seed in seeds)
    audited_lies = [run_m5(talk(source_tags = true, tag_liars = liars, tag_lie = :misattribute); seed) for seed in seeds]
    @test unaudited_lies < mean(run_m5(talk(source_tags = true); seed).correct for seed in seeds) - 0.01
    @test all(r.tags_detected == r.tags_falsified > 0 for r in audited_lies)
    @test mean(r.correct for r in audited_lies) > unaudited_lies
    @test audited_lies[1].correct >= honest.correct - 0.02
    # Laundering by omission: a launderer republishes what it heard as its own and votes it with its
    # full weight. AdvAp's echo audit flags most launderers (agreement with what they heard far above
    # independence) and few honest voters; flagged, their readings are split like anyone's.
    launder = [run_m5(talk(source_tags = true, tag_liars = liars, tag_lie = :omit); seed) for seed in seeds]
    @test mean(length(r.launderers_flagged) for r in launder) >= 0.75 * length(liars)
    @test mean(r.honest_flagged for r in launder) <= 0.05 * (100 - length(liars))
    unaudited = [run_m5(talk(source_tags = true, tag_audit = false, tag_liars = liars, tag_lie = :omit); seed) for seed in seeds]
    @test all(isempty(r.launderers_flagged) for r in unaudited)
    # Unaudited, laundering pays: echoed outputs build the launderers good records, listeners weigh
    # them, and decisions suffer; the audit removes both.
    liar_acc(rs) = mean(mean(r.records[j, d][1] / sum(r.records[j, d]) for j in liars, d in 1:4) for r in rs)
    @test liar_acc(unaudited) > liar_acc(launder) + 0.1
    @test mean(r.correct for r in launder) > mean(r.correct for r in unaudited) + 0.01
    @test_throws ArgumentError talk(source_tags = true, tag_liars = [101])
    @test_throws ArgumentError talk(source_tags = true, tag_lie = :forge)
end

# SOTA #3: liquid-democracy pathologies against direct voting (`docs/SOTA.md`, Liquid democracy).
# Worlds built directly: one domain decided in, voters focused elsewhere (so free to delegate),
# reputation as given.
ld_world(skills, rep) = (agents = [DomainAgent([s, 0.0], [0.0, 1.0], 0.0) for s in skills],
                         relevance_leaf = hcat(Float64.(rep), zeros(length(rep))))

@testset "SOTA #3: liquid-democracy pathology suite" begin
    seeds = 1:6
    acc(w; kw...) = mean(run_m5(M5Params(w, [1]; decisions = 400, signal_σ = 3.0, diversity = false, kw...); seed).correct for seed in seeds)
    # Bad delegation (Kahng, Mackenzie and Procaccia 2021): many voters of modest competence all
    # delegate to one voter somewhat better than each; their direct majority beats it alone.
    n = 101
    skills = [i == 1 ? 0.25 : 0.1 + 0.05 * (i - 2) / (n - 2) for i in 1:n]
    kmp = ld_world(skills, skills)
    direct = acc(kmp)
    @test acc(kmp; p_delegate = 1.0, cap = 1.0, audit_window = 0) < direct - 0.05   # must fail: uncapped concentrates
    @test acc(kmp; p_delegate = 1.0) >= direct - 0.03                               # must achieve: the cap spreads it
    # Adversarial instance (Caragiannis and Micha 2019): reputation misleads (the least competent
    # hold the most), so delegation moves weight to the worst. Uncapped and unaudited it does far
    # worse than direct voting; capped and audited (L114), it stays near direct.
    inverted = similar(skills)
    inverted[sortperm(skills)] = reverse(sort(skills))
    misled = ld_world(skills, inverted)
    direct_m = acc(misled)
    @test acc(misled; p_delegate = 1.0, cap = 1.0, audit_window = 0) < direct_m - 0.1
    @test acc(misled; p_delegate = 1.0) >= direct_m - 0.05
    # Bribery of delegates (Alouf-Heffetz et al. 2024): the three most reputable are bought and vote
    # one side. Uncapped, buying the super-voter buys the decision until its vote reputation falls;
    # capped and audited, the bribe controls little and decisions stay near direct voting with the
    # same bribes.
    top3 = sortperm(skills; rev = true)[1:3]
    direct_b = acc(kmp; colluders = top3)
    @test acc(kmp; colluders = top3, p_delegate = 1.0, cap = 1.0, audit_window = 0) < direct_b - 0.2
    @test acc(kmp; colluders = top3, p_delegate = 1.0) >= direct_b - 0.03
    # Concentration (Kling et al. 2015: super-voters): uncapped, one voter holds most of the weight;
    # capped, none holds more than the cap plus one voter's own.
    sup = run_m5(M5Params(kmp, [1]; decisions = 100, p_delegate = 1.0, cap = 1.0, audit_window = 0, diversity = false); seed = 1)
    capd = run_m5(M5Params(kmp, [1]; decisions = 100, p_delegate = 1.0, diversity = false); seed = 1)
    @test mean(sup.max_share) > 0.5
    @test all(capd.max_share .<= 0.05 .+ capd.max_single .+ 1e-12)
    # Cycles: delegation goes only to strictly higher reputation and delegates do not pass weight on,
    # so no cycle forms and no vote is lost; with equal reputations (held equal: votes earn nothing
    # here), no one delegates.
    flat = ld_world(fill(0.2, 30), fill(1.0, 30))
    fr = run_m5(M5Params(flat, [1]; decisions = 50, p_delegate = 1.0, cap = 1.0, diversity = false, vote_value = 0.0); seed = 1)
    @test fr.max_share == fr.max_single && fr.weight_gap < 1e-9
    @test capd.weight_gap < 1e-9 && sup.weight_gap < 1e-9
end
