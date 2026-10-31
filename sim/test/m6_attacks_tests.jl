# M6 attacks from the state of the art (docs/SOTA.md items 5, 7 and 10's Goodhart probe). Each is
# tested against the native mechanisms first; what they do not cover is a finding (BACKPROPAGATION
# 8.58-a onwards), and a fix is a Lean reference rule with a governed threshold.
# - The decision-market gap (Chen, Kash, Ruberry & Shnayder 2014): when predictions select which
#   plans are carried out and only what is carried out is scored, a model can misreport on the plans
#   its predictions keep out, unseen. Full support (`explore_share`, Lean `explore_pick_ref`) closes it.
# - Extremised forecasts under rank-based selection (Witkowski et al. 2023): picking the best of
#   several challengers on few records rewards overconfidence even under a proper score. A challenger
#   competes only once its record spans `takeover_records`.
# - Reputation attacks (Hoffman, Zage & Nita-Rotaru 2009; Cheng & Friedman 2005): whitewashing
#   against identity binding (Lean `binding_admits_ref`), on-off oscillation against ledger asymmetry,
#   slandering against AdvAp's audit, sybils against causal distribution's conservation.
# - Goodhart overoptimisation (Gao, Schulman & Hilton 2023; Manheim & Garrabrant 2018): the gap
#   between the proxy G optimises (predicted value) and the true value as optimisation pressure rises.
isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))  # the controlled world (limiting case)


# One domain of six agents at skill 0.6 (the leaf model qualifies); agent 6's plans are good, but
# every model understates them by 2 per being touched (negative `deceit`: a misreport against it).
# (At 1 per being the domain's own noise eventually gets one of its plans selected, around step 100,
# and the track record then corrects the misreport: noise is accidental exploration.)
dm(; deceit = [0, 0, 0, 0, 0, -2.0], steps = 300, kw...) =
    M3cParams(ToyParams(n = 80, steps = steps, plans = 10), [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6],
              [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, deceit, LEGACY..., kw...)
acted(tr, a) = count(==(a), tr.chosen_agent)      # carried out, explored or selected
selected(tr, a) = count(==(a), tr.exec_agent)     # selected by G

@testset "Decision market: rules (Lean reference)" begin
    # Full support: below the share, every one of the n plans is reachable, each with chance share/n.
    @test explore_pick(0.5, 0.1, 4) == 0 && explore_pick(0.1, 0.1, 4) == 0
    @test [explore_pick(u, 0.2, 4) for u in (0.0, 0.049, 0.05, 0.1, 0.16, 0.199)] == [1, 1, 2, 3, 4, 4]
    rng = Xoshiro(7)
    picks = [explore_pick(rand(rng), 0.2, 5) for _ in 1:50_000]
    @test all(abs(mean(picks .== k) - 0.04) < 0.005 for k in 1:5) && abs(mean(picks .== 0) - 0.8) < 0.01
    @test explore_pick(0.0, 0.2, 0) == 0 && explore_pick(0.0, 0.0, 5) == 0 && explore_pick(0.999, 1.0, 3) == 3
    @test_throws ArgumentError explore_pick(1.5, 0.1, 3)
    @test_throws ArgumentError explore_pick(0.5, -0.1, 3)
    @test_throws ArgumentError explore_pick(0.5, 0.1, -1)
    @test_throws ArgumentError explore_pick(NaN, 0.1, 3)
end

@testset "Decision market: acceptance" begin
    seeds = 1:3
    hidden = [run_m3c(dm(); seed) for seed in seeds]
    full = [run_m3c(dm(explore_share = 0.05); seed) for seed in seeds]
    # Without full support the misreport is never scored: agent 6's plans are never carried out, and
    # no model holds a single record on it.
    @test all(acted(tr, 6) == 0 && tr.explored == 0 for tr in hidden)
    @test all(!any(r.actor == 6 for r in tr.leaf_records[1]) for tr in hidden)
    # With full support it is caught: explored plans are scored, the models' track record on agent 6
    # learns the understatement (8.29) and corrects it, and G then selects its plans on their merits.
    @test all(tr.explored > 0 for tr in full)
    @test all(selected(tr, 6) > 0 for tr in full)
    @test all(any(r.actor == 6 for r in tr.leaf_records[1]) for tr in full)
    @test mean(selected(tr, 6) for tr in full) > 0.25 * mean(mean(selected(tr, a) for a in 1:5) for tr in full)
    # Exploring costs the Goal little where nothing is misreported (the whole success pattern).
    honest = [run_m3c(dm(deceit = Float64[]); seed) for seed in seeds]
    explored = [run_m3c(dm(deceit = Float64[], explore_share = 0.05); seed) for seed in seeds]
    sp(trs) = [success_pattern(tr; from = 51) for tr in trs]
    @test mean(s.floor_u for s in sp(explored)) > 0.9 * mean(s.floor_u for s in sp(honest))
    @test mean(s.median_u for s in sp(explored)) > 0.9 * mean(s.median_u for s in sp(honest))
    @test mean(s.floor_u_falls for s in sp(explored)) <= mean(s.floor_u_falls for s in sp(honest)) + 0.05
end

@testset "Decision market: adversarial and edge cases" begin
    # No exploration changes nothing.
    @test run_m3c(dm(explore_share = 0.0); seed = 1) == run_m3c(dm(); seed = 1)
    @test_throws ArgumentError dm(explore_share = 1.5)
    @test_throws ArgumentError dm(explore_share = -0.1)
    # Gaming: proposing harmful work in the hope it is explored does not pay. The explored work is paid
    # at its full resource cost by its proposer and its measured harm is the proposer's (agent 6 at
    # skill -0.5, predicted honestly).
    bad = M3cParams(ToyParams(n = 80, steps = 300, plans = 10),
                    [[DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:5]; DomainAgent([-0.5, 0, 0, 0], [1.0, 0, 0, 0], 0.0)],
                    [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, explore_share = 0.2, LEGACY...)
    tr = run_m3c(bad; seed = 1)
    @test tr.explored > 0 && tr.credit_neg[6] < 0
    @test sum(tr.balance[6, :]) < minimum(sum(tr.balance[a, :]) for a in 1:5)
    # The books balance with explored work paid at resource cost.
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) - sum(tr.reinvested)
end

# A rule-level contest of equal-skill models, honest or extremising (stating a fraction `k` of its
# uncertainty), each scored by the proper per-record credence score (`credence_score_ref`); the
# incumbent first, the best challenger taking over only by `select_candidate_ref`.
function contest(rng; k, nchal = 8, records = 100, z = 2.0)
    v = 0.3 .+ randn(rng, records)
    out = Float64.(v .+ 0.05 .* randn(rng, records) .> 0)
    scores(sh) = [credence_score(credence(v[i] + 0.5 * randn(rng), 0.5 * sh), out[i]) for i in 1:records]
    S = [[scores(1.0) for _ in 1:nchal]; [scores(k)]]   # incumbent, honest challengers, the extremiser last
    select_candidate(mean.(S), [std(x) / sqrt(records) for x in S]; z)
end
takeover_rates(rng; k, records, n = 4000, nchal = 8) =
    (r = [contest(rng; k, nchal, records) for _ in 1:n]; (ext = mean(r .== nchal + 1), honest = mean(2 .<= r .<= nchal) / (nchal - 1)))

@testset "Extremised forecasts: rules" begin
    rng = Xoshiro(11)
    # On few records the best-of-several pick rewards overconfidence, proper score or not (Witkowski
    # et al. 2023)...
    few = takeover_rates(rng; k = 0.5, records = 10)
    @test few.ext > 1.5 * few.honest
    # ...on a full window it does not.
    full = takeover_rates(rng; k = 0.5, records = 100)
    @test full.ext < full.honest + 0.01
end

# Eight agents in two leaves; new models arriving as often as in `models_tests.jl`, of the incumbent's
# skill exactly (no drift, no scatter), half of them extremising.
ext_world(; kw...) = M3cParams(ToyParams(n = 80, steps = 400, plans = 10),
    [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.3) for _ in 1:8], [1, 1, 2, 2], trues(4);
    λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, LEGACY..., σ_leaf = 0.45, σ_branch = 0.6, σ_coarse = 0.75,
    p_new_model = 0.05, improve_drift = 0.0, improve_σ = 0.0, p_extremist = 0.5, extremise = 0.5, kw...)

@testset "Extremised forecasts: in the economy" begin
    seeds = 1:3
    short = [run_m3c(ext_world(takeover_records = 10); seed) for seed in seeds]
    native = [run_m3c(ext_world(); seed) for seed in seeds]
    # Here challengers clear a full window before any beats the incumbent significantly: the
    # takeover-record bar changes nothing, and no honest equal ever takes over.
    @test [tr.takeovers for tr in native] == [tr.takeovers for tr in short]
    @test sum(tr.takeovers - tr.takeovers_extreme for tr in native) == 0
    # Finding (8.58-c): the takeovers there are, are extremists'. Not the rank rule: honest credences
    # (`credence_ref`, predicted value over the record's RMS error, no prior) are underconfident in a
    # domain whose outcomes are mostly positive, so a model stating half its uncertainty is better
    # calibrated and the proper score rightly prefers it.
    @test sum(tr.takeovers_extreme for tr in native) >= 1
    honest = [run_m3c(ext_world(p_extremist = 0.0); seed) for seed in 1:2]
    mid = [r for tr in honest for j in (1, 3) for r in tr.leaf_records[j] if 0.5 <= r.credence < 0.9]
    @test mean(r.outcome for r in mid) > mean(r.credence for r in mid) + 0.1
    # Edge cases: no extremists, nothing changes; ranges are checked.
    @test all(tr.takeovers_extreme == 0 && tr.arrivals_extreme == 0 for tr in honest)
    @test run_m3c(ext_world(p_extremist = 0.0, extremise = 0.3); seed = 1) == honest[1]
    @test_throws ArgumentError ext_world(p_extremist = 1.5)
    @test_throws ArgumentError ext_world(extremise = 0.0)
    @test_throws ArgumentError ext_world(takeover_records = 0)
end

@testset "Identity binding: rules (Lean reference)" begin
    # An identity is admitted as a distinct entity only when at least `quorum` clusters' confidences
    # reach the threshold (Technology Network: methods from at least two clusters).
    @test binding_admits([0.9, 0.9, 0.1], 0.5; quorum = 2) && !binding_admits([0.9, 0.1, 0.1], 0.5; quorum = 2)
    @test binding_admits([0.5, 0.5], 0.5; quorum = 2)
    @test binding_admits(Float64[], 0.5; quorum = 0) && !binding_admits(Float64[], 0.5; quorum = 1)
    @test_throws ArgumentError binding_admits([1.5], 0.5; quorum = 1)
    @test_throws ArgumentError binding_admits([0.5], NaN; quorum = 1)
    @test_throws ArgumentError binding_admits([0.5], 0.5; quorum = -1)
end

# A liar (deceit 1.0) in a qualifying domain (skill 0.6) that takes a new identity whenever it can
# (whitewashing: chance 0.05 a step), resetting the track record models price it by (8.29), its
# ledgers and its audit record.
ww(; kw...) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10), [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6],
                        [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                        deceit = [0, 0, 0, 0, 0, 1.0], LEGACY..., kw...)
whitewasher = [0, 0, 0, 0, 0, 0.05]

@testset "Whitewashing against identity binding" begin
    seeds = 1:3
    plain = [run_m3c(ww(); seed) for seed in seeds]
    bound = [run_m3c(ww(whitewash = whitewasher); seed) for seed in seeds]
    unbound = [run_m3c(ww(whitewash = whitewasher, bind_quorum = 0); seed) for seed in seeds]
    acc(tr) = tr.leaf_accuracy[1]
    # Bound: nearly every attempt is linked back to its entity, and the domain's model fares as without.
    @test all(tr.identities_linked > 5 * tr.identities_admitted for tr in bound)
    @test mean(acc.(bound)) > mean(acc.(plain)) - 0.02
    # Unbound: every attempt succeeds; each fresh identity fools the models in full again, and the
    # domain's model is worse for it.
    @test all(tr.identities_admitted > 5 && tr.identities_linked == 0 for tr in unbound)
    @test mean(acc.(unbound)) < mean(acc.(bound)) - 0.01
    # The recount honours identities: a new identity's ledgers hold only what it did.
    hp, hn, rel = recount(unbound[1])
    @test hp ≈ unbound[1].h_pos_own && hn ≈ unbound[1].h_neg_own
    # Edge cases: no whitewashing, nothing changes; ranges are checked.
    @test run_m3c(ww(whitewash = zeros(6)); seed = 1) == run_m3c(ww(); seed = 1)
    @test_throws ArgumentError ww(whitewash = [0.1])
    @test_throws ArgumentError ww(whitewash = [0, 0, 0, 0, 0, 1.5])
    @test_throws ArgumentError ww(bind_miss = 1.5)
    @test_throws ArgumentError ww(bind_quorum = -1)
    @test_throws ArgumentError ww(on_off = -1)
end

@testset "On-off oscillation: ledger asymmetry (rules)" begin
    # A record alternating equal gains and losses: with losses decaying slower than gains (λ₋ < λ₊,
    # 8.29) the rolling net after the cycles is negative; with equal rates the good phase restores it.
    rg(λp, λn) = decay_rate_for(1.0; λpos = λp, λneg = λn), decay_rate_for(-1.0; λpos = λp, λneg = λn)
    function net(λp, λn; cycles = 5, phase = 20)
        g, l = rg(λp, λn)
        T = 2 * cycles * phase
        sum(reputation_decay(1.0, T - t; rate = g) for c in 0:(cycles - 1) for t in (2c * phase + phase + 1):(2c * phase + 2phase)) -
            sum(reputation_decay(1.0, T - t; rate = l) for c in 0:(cycles - 1) for t in (2c * phase + 1):(2c * phase + phase))
    end
    @test net(0.05, 0.02) < net(0.05, 0.05)
    @test net(0.05, 0.02) < 0 < net(0.05, 0.05)
end

# On-off in the economy: an agent alternates 25-step phases of honest good work (skill 0.6) and
# harmful work (skill -0.4, a setback of 1.0) passed off by deceit 1.0 (`on_off`), which the 20-action
# track record has forgotten by each bad phase.
onoff_events = [shock(:breakthrough; step = s, duration = 25, size = -1.0, target = 6) for s in 26:50:300]
onoff(; kw...) = ww(; events = onoff_events, on_off = 25, kw...)

@testset "On-off oscillation in the economy" begin
    seeds = 1:3
    peers(tr) = mean(selected(tr, a) for a in 1:5)
    honest = [run_m3c(ww(deceit = Float64[]); seed) for seed in seeds]
    constant = [run_m3c(onoff(on_off = 0); seed) for seed in seeds]
    onoffs = [run_m3c(onoff(); seed) for seed in seeds]
    audited = [run_m3c(onoff(advap = true); seed) for seed in seeds]
    # The ledgers keep the pattern: entries never decay (8.42.4), so the attacker's negative share
    # stands above every peer's at the end of a good phase.
    ns(tr, a) = neg_share(sum(tr.h_pos_own[a, :]), sum(tr.h_neg_own[a, :]))
    @test all(ns(tr, 6) > maximum(ns(tr, a) for a in 1:5) for tr in onoffs)
    # Constant deceit is learnt by the track record (8.29): the bad phases' harm is predicted honestly
    # and rejected, and the peers work as in an honest world.
    @test mean(peers.(constant)) > 0.9 * mean(peers.(honest))
    # Finding (8.58-d): deceiving only in alternate phases defeats the 20-action track record. Each
    # bad phase fools the models afresh, the leaf model falls below its status bar and the domain's
    # currency goes down for everyone (8.37's mechanism, now in a capable domain).
    harm(tr) = [sum(min(x, 0.0) for (i, x) in enumerate(tr.exec_true) if tr.exec_agent[i] == 6 && s <= tr.exec_step[i] < s + 25; init = 0.0)
                for s in 26:50:300]
    @test all(count(<(0), harm(tr)) >= 2 for tr in onoffs)
    @test mean(peers.(onoffs)) < 0.3 * mean(peers.(constant))
    # AdvAp establishes the deception, but its repair, estimated from all the actor's records, honest
    # phases included, understates the overstatement and does not restore the domain.
    @test all(tr.advap_established > 0 for tr in audited)
    @test mean(peers.(audited)) < 0.3 * mean(peers.(constant))
end

@testset "Slandering against AdvAp's audit" begin
    # Agent 1 reports agent 2 every step whatever the record (false negative reports). Audits test the
    # record, not the report: the victim is never convicted, loses nothing, and the slanderer pays the
    # audits past the frivolous pattern.
    sl(; kw...) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10), [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6],
                            [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                            advap = true, kw...)
    calm = run_m3c(sl(); seed = 1)
    slandered = run_m3c(sl(frivolous = [1.0, 0, 0, 0, 0, 0], slander = [2, 0, 0, 0, 0, 0]); seed = 1)
    @test slandered.advap_reports >= 250 && slandered.advap_established == calm.advap_established == 0
    @test abs(sum(slandered.balance[2, :]) - sum(calm.balance[2, :])) < 0.1 * abs(sum(calm.balance[2, :]))
    @test slandered.advap_penalties > 0.9 * (slandered.advap_reports - calm.advap_reports - 5 * 3) * 1.0
    @test sum(slandered.balance[1, :]) < sum(calm.balance[1, :])
    # Counterexample: without the frivolous-pattern charge the slanderer floods audits at the
    # commons' cost and pays nothing.
    free = run_m3c(sl(frivolous = [1.0, 0, 0, 0, 0, 0], slander = [2, 0, 0, 0, 0, 0], frivolous_threshold = 1e9); seed = 1)
    @test free.advap_penalties == 0 && free.advap_audits >= 250
    @test_throws ArgumentError sl(slander = [7, 0, 0, 0, 0, 0])
    @test_throws ArgumentError sl(slander = [1, 0, 0, 0, 0, 0])
    @test_throws ArgumentError sl(slander = [2])
end

@testset "Sybils against causal distribution" begin
    # Credit comes only from measured outcomes and is shared by Shapley value (`shapley_ref`): a sybil
    # adding nothing gets nothing (null player), and the total credited is the outcome's value
    # however contributors split into identities (efficiency).
    V(x) = sign(x) * abs(x)^1.5   # superadditive, as assessed value is (synergy, L11-L14)
    game(effs) = [V(sum((effs[k] for k in eachindex(effs) if mask & (1 << (k - 1)) != 0); init = 0.0)) for mask in 0:(2^length(effs) - 1)]
    @test shapley([mask & 1 != 0 ? V(2.0) : 0.0 for mask in 0:7]) ≈ [V(2.0), 0, 0]
    @test sum(shapley(game([1.0, 1.0, 1.5]))) ≈ V(3.5)
    # False-name manipulation (Aziz et al. 2011), against a co-contributor of 1.5. Splitting a gain of
    # 2 across two identities lowers the splitter's share: it does not pay.
    cluster(effs) = (φ = shapley(game(effs)); φ[1] + φ[2])
    @test cluster([1.0, 1.0, 1.5]) < shapley(game([2.0, 1.5]))[1]
    # Finding (8.58-e): splitting a harm of 2 the same way lightens the splitter's penalty (about
    # 11%) and shrinks the co-contributor's positive share: Shapley shares are not false-name-proof
    # where an outcome mixes gains and harms, so identity binding, not the share rule, must stop it.
    @test cluster([-1.0, -1.0, 1.5]) > 1.05 * shapley(game([-2.0, 1.5]))[1]
end

# Goodhart: one domain, four honest agents (skill 0.3) and two whose harmful work (skill -0.2) is
# passed off by deceit 0.8; G picks the best predicted of `plans` proposals each step (best-of-n, the
# menu rung), so pressure on the proxy rises with n.
gh(n; kw...) = M3cParams(ToyParams(n = 80, steps = 300, plans = n),
                         [[DomainAgent([0.3, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:4]; [DomainAgent([-0.2, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:2]],
                         [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, causal_distribution = true, deceit = [0, 0, 0, 0, 0.8, 0.8], kw...)
gap(tr) = (k = [i for i in eachindex(tr.exec_pred) if tr.exec_step[i] > 50]; mean(tr.exec_pred[k] .- tr.exec_true[k]))
truth(tr) = (k = [i for i in eachindex(tr.exec_pred) if tr.exec_step[i] > 50]; mean(tr.exec_true[k]))

@testset "Goodhart overoptimisation curve" begin
    seeds, ns = 1:3, (2, 8, 32)
    bare = Dict(n => [run_m3c(gh(n; track_window = 0); seed) for seed in seeds] for n in ns)
    native = Dict(n => [run_m3c(gh(n; advap = true, p_new_model = 0.05); seed) for seed in seeds] for n in ns)
    g(d, n) = mean(gap.(d[n])); v(d, n) = mean(truth.(d[n]))
    # Counterexample (one model, no track record, no AdvAp): the gap grows with pressure and the true
    # value of what is chosen falls (overoptimisation).
    @test g(bare, 32) > g(bare, 2) + 1.0
    @test v(bare, 32) < v(bare, 8)
    # Native (track record, competing models, AdvAp): the gap stays bounded, a fraction of the bare
    # world's, and pressure buys true value.
    @test g(native, 32) < g(native, 2) + 0.5 * (g(bare, 32) - g(bare, 2))
    @test g(native, 32) < 0.5 * g(bare, 32)
    @test v(native, 32) > v(native, 2)
    # Judged by the whole success pattern, the native world at high pressure does no worse than at low.
    sp(n) = mean(success_pattern(tr; from = 51).floor_u for tr in native[n])
    @test sp(32) >= sp(2) - 1e-9
end
