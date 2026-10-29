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
    # Deceit does not pay (BACKPROPAGATION 8.28, 8.29). Each model prices each actor by its track
    # record on it, and escrow settles on the measured outcome, so the liar collects no more upfront
    # than its outcomes are worth and ends, relative to its peers, as an honest agent would.
    seeds = 1:6
    honest = [run_m3c(six(); seed) for seed in seeds]
    liar = [run_m3c(six(deceit = fooled); seed) for seed in seeds]
    rel(tr) = sum(tr.balance[6, :]) / mean(sum(tr.balance[k, :]) for k in 1:5)
    @test mean(rel.(liar)) <= mean(rel.(honest)) + 0.05
    @test all(l.upfront[6] <= l.settled_value[6] for l in liar)
    @test all(sum(l.balance) - l.endowed ≈ sum(l.valued_measured) - sum(l.costs) - sum(l.lane_costs) - sum(l.reinvested) for l in liar)
    # In a marginal domain (skill 0.3, the leaf model's accuracy near its 0.9 bar) a liar fooling
    # every model can keep the domain from ever qualifying: models it has no record with yet are
    # fooled in full (BACKPROPAGATION 8.37). Here it happens in seeds 4 and 5, never honestly.
    peers(tr) = count(<(6), tr.chosen_agent)
    @test peers(liar[4]) == 0 && peers(liar[5]) == 0 && all(peers(h) > 0 for h in honest)
    # Uncovered and repaired (8.38), with readers' attention drawn by the negative pattern in the liar's
    # ledgers and in the marginal domain (8.42.1), the domain is blocked far less often.
    blocked(kw) = count(seed -> peers(run_m3c(six(; deceit = fooled, kw...); seed)) < 50, 1:12)
    @test blocked((advap = true,)) <= blocked((;)) - 2
    # Without the track record the liar takes the domain down in every seed.
    untracked = [run_m3c(six(deceit = fooled, track_window = 0); seed) for seed in 1:3]
    @test mean(peers.(untracked)) < 0.1 * mean(peers.(honest[1:3]))
end

@testset "M6 overpromising: adversarial and edge cases" begin
    # One finite deceit per agent; none at all changes nothing.
    @test_throws ArgumentError six(deceit = [0, 0, 0, 0, 0])
    @test_throws ArgumentError six(deceit = [0, 0, 0, 0, 0, NaN])
    @test run_m3c(six(deceit = zeros(6)); seed = 1) == run_m3c(six(); seed = 1)
    @test_throws ArgumentError six(track_window = -1)
end

# Adversarial adaptation (AdvAp, L160; author ruling 8.38): agents read one another's records in
# the open log and report an actor whose estimates run significantly high; an audit tests the
# record (the significance rule, `select_candidate_ref`) and examines its cause (`p_trace`). An
# established deception is repaired in full: the model records it falsified are re-scored on the
# estimate without its overstatement, and the reporter's reward and the audit are charged to the
# deceiver (`advap_reward_ref`, `advap_liability_ref`). Good-faith reports that prove unfounded cost
# nothing; past a frivolous pattern, each is charged its audit (`report_penalty_ref`).
@testset "M6 overpromising under AdvAp: acceptance" begin
    # A domain that clearly qualifies (skill 0.6), so the test reads AdvAp, not the status bar.
    sixty(; kw...) = six(; skill = 0.6, kw...)
    peers(tr) = sum(count(==(k), tr.chosen_agent) for k in 1:5)
    honest = [run_m3c(sixty(advap = true); seed) for seed in 1:3]
    liar = [run_m3c(sixty(deceit = fooled, advap = true); seed) for seed in 1:3]
    # The deception is uncovered and repaired, and the reporters are paid out of what the
    # deceiver is charged, which also covers the audits; deceit does not pay.
    @test all(l.advap_established > 0 for l in liar)
    @test all(l.advap_rewards > 0 && l.advap_liability >= l.advap_rewards for l in liar)
    rel(tr) = sum(tr.balance[6, :]) / mean(sum(tr.balance[k, :]) for k in 1:5)
    @test mean(rel.(liar)) <= mean(rel.(honest)) + 0.05
    @test mean(peers.(liar)) > 0.9 * mean(peers.(honest))
    # The books balance with AdvAp's flows.
    @test all(sum(l.balance) - l.endowed ≈ sum(l.valued_measured) - sum(l.costs) - sum(l.lane_costs) - sum(l.reinvested) + l.advap_net
              for l in liar)
    # Without the track record a liar takes the domain's currency down for everyone (8.37); repair
    # of the uncovered deception (8.38) restores much of the peers' work.
    plain = [run_m3c(sixty(deceit = fooled, track_window = 0); seed) for seed in 1:3]
    repaired = [run_m3c(sixty(deceit = fooled, track_window = 0, advap = true); seed) for seed in 1:3]
    clean = [run_m3c(sixty(track_window = 0); seed) for seed in 1:3]
    @test mean(peers.(plain)) < 0.1 * mean(peers.(clean))
    @test mean(peers.(repaired)) > 0.25 * mean(peers.(clean)) && mean(peers.(repaired)) > 5 * mean(peers.(plain))
end

@testset "M6 overpromising under AdvAp: adversarial and edge cases" begin
    # An honest world: no audit establishes a deception when examinations never err, and no honest
    # agent is charged.
    tr = run_m3c(six(skill = 0.6, advap = true, p_false_trace = 0.0); seed = 1)
    @test tr.advap_established == 0 && tr.advap_liability == 0
    @test tr == run_m3c(six(skill = 0.6, advap = true, p_false_trace = 0.0); seed = 1)
    # AdvAp off changes nothing.
    @test run_m3c(six(advap = false); seed = 1) == run_m3c(six(); seed = 1)
    # A frivolous reporter (agent 1 reports every step, whatever the record) is charged past the
    # pattern threshold and ends poorer; nobody honest is convicted.
    noisy = run_m3c(six(skill = 0.6, advap = true, p_false_trace = 0.0, frivolous = [1.0, 0, 0, 0, 0, 0]); seed = 1)
    calm = run_m3c(six(skill = 0.6, advap = true, p_false_trace = 0.0); seed = 1)
    @test noisy.advap_penalties > 0 && noisy.advap_established == 0
    @test sum(noisy.balance[1, :]) < sum(calm.balance[1, :])
    # Examination that never traces a cause establishes nothing: the track record is left to work alone.
    @test run_m3c(six(skill = 0.6, deceit = fooled, advap = true, p_trace = 0.0); seed = 1).advap_established == 0
    # Two domains, two deceivers and a capture shifting pricing between leaf and parent models: audits
    # reach records under models absent from the records since the last audit (a regression found by
    # the failure-boundary battery).
    two = M3cParams(ToyParams(n = 80, steps = 200, plans = 10), [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.3) for _ in 1:8],
                    [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, p_upstream = 0.5,
                    deceit = [0, 0, 0, 0, 0, 0, 1.0, 1.0], advap = true, events = [shock(:capture; step = 80, duration = 60, size = 3.0, target = 1)])
    @test run_m3c(two; seed = 1).advap_established > 0
    @test_throws ArgumentError six(advap = true, vigilance = 1.5)
    @test_throws ArgumentError six(advap = true, adv_z = -1.0)
    @test_throws ArgumentError six(advap = true, p_false_trace = 2.0)
    @test_throws ArgumentError six(advap = true, frivolous = [1.0])
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

# Collusion under AdvAp (L160; the manufactured prisoner's dilemma of Adversarial adaptation; 8.38):
# after each hidden defection a bloc member may weigh revealing the bloc (`p_weigh`), and reveals
# when the reward (`advap_reward_ref`, more than its share of the bloc's gain) beats that share and
# its loyalty, by its own noisy judgement (8.31). An established revelation is repaired in full: the
# bloc's falsified votes are struck from every hidden decision since the last revelation and those
# decisions recounted, and each falsified vote is debited as a wrong one; the revealer keeps its
# reputation, the rest of the bloc is charged the reward and the audit (`advap_liability_ref`).
@testset "M6 collusion under AdvAp" begin
    w = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                          [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                           for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    bloc30 = unique(vcat([sortperm(w.relevance_leaf[:, d]; rev = true)[1:round(Int, 0.3 * 25)] for d in 1:4]...))
    seeds = 1:4
    cfg(; kw...) = M5Params(w, 1:4; decisions = 800, colluders = bloc30, p_delegate = 0.8, stealth = true, diversity = false, kw...)
    stealthy = [run_m5(cfg(); seed) for seed in seeds]
    revealed = [run_m5(cfg(advap = true); seed) for seed in seeds]
    @test all(r.advap_established > 0 for r in revealed)
    # Hidden decisions swung by the bloc are recounted, and the bloc loses its expertise.
    @test mean(r.correct_after_hidden for r in revealed) > mean(r.correct_hidden for r in stealthy) + 0.1
    @test mean(r.bloc_expertise[end] for r in revealed) < mean(r.bloc_expertise[end] for r in stealthy) / 2
    # Revealing pays more than colluding; the bloc pays for it, and for the audits.
    @test all(r.advap_rewards > r.advap_gain_forgone && r.advap_liability >= r.advap_rewards for r in revealed)
    # Adversarial and edge cases. No bloc, nothing to reveal; AdvAp off changes nothing.
    @test run_m5(M5Params(w, 1:4; decisions = 400, p_delegate = 0.8, advap = true); seed = 1).advap_established == 0
    @test isequal(run_m5(cfg(advap = false); seed = 1), run_m5(cfg(); seed = 1))
    # Loyalty above the reward keeps members quiet (up to their judgement's noise); evidence that never
    # establishes the collusion changes nothing.
    loyal = run_m5(cfg(advap = true, loyalty = 1e6); seed = 1)
    @test loyal.advap_established == 0
    @test run_m5(cfg(advap = true, p_trace = 0.0); seed = 1).correct_after_hidden == stealthy[1].correct_hidden
    @test_throws ArgumentError cfg(advap = true, p_weigh = 1.5)
    @test_throws ArgumentError cfg(advap = true, loyalty = -1.0)
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
