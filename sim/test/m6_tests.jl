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
    # so the liar's prices return to honest levels: it acts no more than honestly, collects no more
    # upfront than its outcomes are worth, and ends no richer on average. Mistakes decaying slower
    # than wins leave its churn no reputation to bank.
    seeds = 1:6
    honest = [run_m3c(six(); seed) for seed in seeds]
    liar = [run_m3c(six(deceit = fooled); seed) for seed in seeds]
    acts(tr) = count(==(6), tr.chosen_agent)
    @test mean(sum(l.balance[6, :]) for l in liar) <= 1.05 * mean(sum(h.balance[6, :]) for h in honest)
    @test mean(acts.(liar)) <= 1.2 * mean(acts.(honest))
    @test all(l.upfront[6] < l.settled_value[6] for l in liar)
    @test all(sum(l.balance) - l.endowed ≈ sum(l.valued_measured) - sum(l.costs) - sum(l.lane_costs) - sum(l.reinvested) for l in liar)
    # Under status thresholds (8.35) a deceiver degrades the shared model's accuracy, and with it
    # the domain's currency status (BACKPROPAGATION 8.37). With the track record the domain mostly
    # keeps status; peers lose part of their activity, not all of it.
    peers(tr) = sum(count(==(k), tr.chosen_agent) for k in 1:5)
    @test mean(peers.(liar)) > 0.5 * mean(peers.(honest))
    # Without the track record the deceiver cannot profit (it barely acts), but it takes the domain's
    # status down with it: a denial of service on everyone, an open finding.
    untracked = [run_m3c(six(deceit = fooled, track_window = 0); seed) for seed in 1:3]
    @test mean(acts.(untracked)) < 0.2 * mean(acts.(honest[1:3]))
    @test mean(peers.(untracked)) < 0.1 * mean(peers.(honest[1:3]))
    @test mean(u.leaf_accuracy[1] for u in untracked) < mean(l.leaf_accuracy[1] for l in liar[1:3]) - 0.3
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
    # A stealthy bloc defects only where the outcome will not become apparent (worst case: it knows
    # in advance). Vote reputation cannot see it: the bloc keeps its expertise and the damage falls on
    # hidden decisions. An open problem by the author's account (8.29.3); diversity at scale,
    # deliberation, AdvAp and anti-corruption are the defences still to model.
    seeds = 1:4
    stealthy = [run_m5(M5Params(w, 1:4; decisions = 800, colluders = bloc30, p_delegate = 0.8, stealth = true, diversity = false); seed) for seed in seeds]
    @test mean(r.bloc_expertise[end] for r in stealthy) > mean(r.bloc_expertise[1] for r in stealthy) / 2
    @test mean(r.correct_apparent for r in stealthy) > 0.95 && mean(r.correct_hidden for r in stealthy) < mean(r.correct_apparent for r in stealthy) - 0.15
    # Diversity (8.30; L158): the option not chosen stays available, subsidised by a novelty bonus,
    # and locales take it up by their own reading past a conviction margin; no one is assigned to it.
    # When the split trial settles the comparison the decision's optimality becomes apparent, which
    # the bloc cannot foresee, and an alternative proved better is adopted (the stochastic escape).
    # The bloc's expertise falls a little; hidden decisions are mostly corrected.
    diverse = [run_m5(M5Params(w, 1:4; decisions = 800, colluders = bloc30, p_delegate = 0.8, stealth = true); seed) for seed in seeds]
    @test mean(r.bloc_expertise[end] for r in diverse) < mean(r.bloc_expertise[end] for r in stealthy)
    @test mean(r.correct_after_hidden for r in diverse) > mean(r.correct_hidden for r in stealthy) + 0.08
    @test mean(r.correct_after for r in diverse) > mean(r.correct for r in stealthy)
    @test all(r.correct_after == r.correct for r in stealthy)  # no trial, nothing corrected
    # Locales choose: few depart from a right decision, many from a wrong one.
    @test all(0 < mean(r.chosen_share) < 0.5 && r.novelty_paid > 0 for r in diverse)
    @test mean(mean(r.share_when_wrong) for r in diverse) > 3 * mean(mean(r.share_when_right) for r in diverse)
    # Without a bloc, adopting significant trial winners costs at most a little (false switches at
    # the governed z).
    calm = [run_m5(M5Params(w, 1:4; decisions = 800, p_delegate = 0.8); seed) for seed in seeds]
    @test mean(r.correct_after for r in calm) >= mean(r.correct for r in calm) - 0.02
    @test_throws ArgumentError M5Params(w, 1:4; novelty_bonus = -0.5)
    @test_throws ArgumentError M5Params(w, 1:4; p_apparent = 1.5)
    @test_throws ArgumentError M5Params(w, 1:4; audit_threshold = -0.1)
end

# Harm passed off as unassigned: a launderer's actions save resource cost by dumping harm on beings
# outside what the action measurably touches (`launder`, a world property). The harm surfaces with
# no apparent cause and is examined like an outage (8.30.1): traced (`p_trace`), a crime penalised
# through causal distribution; untraced, insured through the commons.
@testset "M6 laundering" begin
    eight(; launder = Float64[], kw...) =
        M3cParams(ToyParams(n = 80, steps = 300, plans = 10), [DomainAgent([0.3, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:8],
                  [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                  repair_efficiency = 0.5, launder, kw...)
    dirty = [zeros(7); 0.5]
    honest = run_m3c(eight(); seed = 1)
    traced = run_m3c(eight(launder = dirty, p_trace = 1.0); seed = 1)
    @test traced.laundered > 0 && traced.laundered_traced == traced.laundered
    @test sum(traced.balance[8, :]) < sum(honest.balance[8, :]) && traced.credit_neg[8] < honest.credit_neg[8]
    untraced = run_m3c(eight(launder = dirty, p_trace = 0.0); seed = 1)
    @test untraced.laundered_traced == 0 && untraced.unattributed > 0
    for tr in (traced, untraced)
        @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) -
                                            sum(tr.reinvested) - tr.hazard_debits + tr.prevention_measured
    end
    @test_throws ArgumentError eight(launder = [0.5])
    @test_throws ArgumentError eight(launder = [zeros(7); 1.5])
end

# Identity forks (L122: Fork splits social power; Being: near-identical patterns are a domain
# pattern, not identities). A forker that votes one side splits into copies voting alike. If the
# base vote weight is part of the social power a fork divides, forking gains nothing; if each
# identity gets its own base vote, copies multiply it (a sybil attack). [OPEN] which the corpus
# means; both are measured.
@testset "M6 identity forks" begin
    w = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                          [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                           for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    forker = 1
    divided = run_m5(M5Params(w, 1:4; decisions = 400, colluders = [forker], fork_copies = 200, fork_rule = :divided); seed = 1)
    plain = run_m5(M5Params(w, 1:4; decisions = 400, colluders = [forker]); seed = 1)
    sybil = run_m5(M5Params(w, 1:4; decisions = 400, colluders = [forker], fork_copies = 200, fork_rule = :per_identity); seed = 1)
    @test divided.correct ≈ plain.correct atol = 0.01           # dividing social power: forking gains nothing
    @test sybil.correct < plain.correct - 0.1                   # a base vote per identity: copies capture
    @test_throws ArgumentError M5Params(w, 1:4; fork_rule = :maybe)
    @test_throws ArgumentError M5Params(w, 1:4; fork_copies = -1)
end
