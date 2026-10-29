# Toy model M6: malicious and gaming agents (CLAUDE.md, Gaming; author rulings 8.24.4, 8.26). Each
# exploit is tested against the native mechanisms before any defence is built; a failure is a
# finding, screened and reported, not patched.
# - Overpromising: an agent whose plans fool every metric model upward (`deceit`, a world
#   property). Escrow (L86) pays upfront only accuracy × prediction and settles against the measured
#   outcome, so the deceit is clawed back; models price each actor's actions by its track record
#   (author ruling 8.29), and mistakes decay slower than wins.
# - Relay farming: agents who add nothing and carry others' outputs to collect accolades. The drain
#   is bounded by the governed accolade rate; ruling 8.26.2 (held) removes it where the carrying
#   would have happened anyway.

six(; skill = 0.3, deceit = Float64[], steps = 300, λneg = 0.02, kw...) =
    M3cParams(ToyParams(n = 80, steps = steps, plans = 10), [DomainAgent([skill, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6],
              [1, 1, 2, 2], trues(4); λpos = 0.05, λneg, transactions = true, causal_distribution = true, deceit, kw...)
fooled = [0, 0, 0, 0, 0, 1.0]

@testset "M6 overpromising: acceptance" begin
    # Deceit does not pay (BACKPROPAGATION 8.28, 8.29). Models price each actor by its track record,
    # so the liar's prices return to honest levels: it acts about as often as honestly, collects about
    # what its outcomes are worth upfront, and ends no richer on average; its peers' prices are not
    # touched. Mistakes decaying slower than wins leave its churn no reputation to bank.
    seeds = 1:6
    honest = [run_m3c(six(); seed) for seed in seeds]
    liar = [run_m3c(six(deceit = fooled); seed) for seed in seeds]
    acts(tr) = count(==(6), tr.chosen_agent)
    @test mean(sum(l.balance[6, :]) for l in liar) <= 1.05 * mean(sum(h.balance[6, :]) for h in honest)
    @test mean(acts.(liar)) <= 1.2 * mean(acts.(honest))
    @test all(l.upfront[6] < l.settled_value[6] for l in liar)
    @test mean(sum(l.upfront[1:5]) for l in liar) ≈ mean(sum(h.upfront[1:5]) for h in honest) rtol = 0.1
    @test all(sum(l.balance) - l.endowed ≈ sum(l.valued_measured) - sum(l.costs) - sum(l.lane_costs) - sum(l.reinvested) for l in liar)
    # Without the track record the liar acts twice as often and is paid upfront far beyond its
    # outcomes, which escrow claws back; the fooled models lose accuracy for everyone.
    blind_models = run_m3c(six(deceit = fooled, track_window = 0); seed = 1)
    @test acts(blind_models) > 1.8 * acts(honest[1]) && blind_models.upfront[6] > 5 * blind_models.settled_value[6]
    @test blind_models.leaf_accuracy[1] < liar[1].leaf_accuracy[1] - 0.05
end

@testset "M6 overpromising: adversarial and edge cases" begin
    # One finite deceit per agent; none at all changes nothing.
    @test_throws ArgumentError six(deceit = [0, 0, 0, 0, 0])
    @test_throws ArgumentError six(deceit = [0, 0, 0, 0, 0, NaN])
    @test run_m3c(six(deceit = zeros(6)); seed = 1) == run_m3c(six(); seed = 1)
    @test_throws ArgumentError six(track_window = -1)
end

@testset "M6 relay farming" begin
    makers = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:3]
    relays = [DomainAgent([0.0, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:3]
    p(rate) = M3cParams(ToyParams(n = 80, steps = 200, plans = 10, spread = 0.05), [makers; relays], [1, 1, 2, 2], trues(4);
                        λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, p_upstream = 1.0, accolade_rate = rate)
    tr = run_m3c(p(0.05); seed = 1)
    # The drain is bounded by the governed accolade rate on what the makers' outputs carried.
    @test tr.accolade_credit <= 0.05 * (sum(tr.upstream_pos) + tr.accolade_credit) + 1e-6
    @test run_m3c(p(0.0); seed = 1).accolade_credit == 0
end

# Colluding voters (M5 world): a bloc that votes one fixed side whatever its signal, chosen in the
# worst case as the most reputable experts of each domain. Normalised expertise, impact weight and
# the delegation cap should keep a minority bloc from capturing decisions at any scale.
@testset "M6 colluding voters" begin
    world(n_per) = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                                     [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / max(n_per - 1, 1) : 0.0 for l in 1:4],
                                                  [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:n_per],
                                     [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    w = world(25)
    top(frac) = unique(vcat([sortperm(w.relevance_leaf[:, d]; rev = true)[1:round(Int, frac * 25)] for d in 1:4]...))
    honest = run_m5(M5Params(w, 1:4; decisions = 400); seed = 1)
    bloc = run_m5(M5Params(w, 1:4; decisions = 400, colluders = top(0.2)); seed = 1)
    @test bloc.correct > 0.8 && bloc.correct < honest.correct
    # With delegation, the bloc gathers no more than the cap allows.
    deleg = run_m5(M5Params(w, 1:4; decisions = 400, colluders = top(0.2), p_delegate = 0.8); seed = 1)
    @test deleg.correct > 0.8 && maximum(deleg.max_share) <= 0.05 + maximum(deleg.max_single) + 1e-9
    @test_throws ArgumentError M5Params(w, 1:4; colluders = [999])
    # Votes are outputs (author ruling 8.29): once a decision's outcome becomes apparent, each vote
    # earns or costs reputation in its domain by the weight it cast; delegations are audited and
    # retracted from delegates whose recent apparent votes fall short (L114). Against a bloc of the
    # top 30% with delegation, accuracy recovers and the bloc's share of expertise falls.
    bloc30 = top(0.3)
    static = run_m5(M5Params(w, 1:4; decisions = 800, colluders = bloc30, p_delegate = 0.8, vote_value = 0.0, audit_window = 0); seed = 1)
    live = run_m5(M5Params(w, 1:4; decisions = 800, colluders = bloc30, p_delegate = 0.8); seed = 1)
    @test live.correct > static.correct + 0.1
    @test live.bloc_expertise[end] < live.bloc_expertise[1] / 2
    # Honest experts lose nothing by it: without a bloc, accuracy holds.
    @test run_m5(M5Params(w, 1:4; decisions = 800, p_delegate = 0.8); seed = 1).correct > 0.95
    @test_throws ArgumentError M5Params(w, 1:4; p_apparent = 1.5)
    @test_throws ArgumentError M5Params(w, 1:4; audit_threshold = -0.1)
end
