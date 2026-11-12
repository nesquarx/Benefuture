# Mechanism probes (CLAUDE.md, Verification): each the smallest world that exercises one mechanism
# alone, with its acceptance and counterexample cases, seconds to run. A mechanism enters the full
# worlds and the batteries only once its probe is green.
using Random, Statistics

# Credence from the record (8.66, [P]): one heavy-tailed outcome in a model's record.
@testset "Probe: credence from the record survives one heavy-tailed outcome" begin
    rng = Xoshiro(1)
    errs = 0.3 .* randn(rng, 99)                  # a calibrated model's recent errors
    hit = [errs; 300.0]                           # one side effect three hundred times the spread
    rms(e) = sqrt(mean(abs2, e))
    @test credence(0.5, rms(errs)) > 0.9 && credence(0.5, rms(hit)) < 0.51      # counterexample: a coin toss
    @test record_credence(0.5, hit) > 0.9                                      # acceptance: barely moved
    @test abs(record_credence(0.5, hit) - record_credence(0.5, errs)) <= 1 / 99
end

# Supply follows outcomes (L99, `supply_delta_ref`): each priced action mints its measured good less
# its resource cost less its harm, and nothing else moves currency in a world with no other flows
# (no hazards, no AdvAp; overflow is a transfer to reinvestment, StandCoin-lane work burns its cost). Two agents, twelve beings, sixty steps after a ten-step score-only start.
@testset "Probe: currency is minted and burnt only by outcomes" begin
    world(; kw...) = M3cParams(ToyParams(n = 12, steps = 60, plans = 4), [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.1) for _ in 1:2],
                               [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                               p_side = 0.0, form_count = 10^6, init_steps = 10, kw...)
    for seed in 1:2
        tr = run_m3c(world(); seed)
        @test length(tr.supply) == length(tr.costs) > 0                          # one supply change per priced action
        # acceptance: balances (with overflow reinvested, a transfer) move by L99 alone; StandCoin-lane
        # work burns its resource cost and mints nothing (8.3)
        @test sum(tr.balance) + sum(tr.reinvested) - tr.endowed ≈ sum(tr.supply) + sum(tr.lane_supply; init = 0.0) atol = 1e-6
    end
    # Counterexample: harm is burnt. With side harm on every action, more currency is burnt per lane
    # action than its resource cost (3.5 and 67.8 against at most 0.53 without, seeds 1-2). This world
    # sits on the novel bar's edge (accuracy 0.65-0.89), so whether its work is priced or falls to the
    # lane depends on the early record; the burn per lane action does not.
    burnt(t) = -(sum(t.lane_supply; init = 0.0) + sum(t.lane_costs; init = 0.0)) / max(t.lane_executed, 1)
    for seed in 1:2
        clean, harmed = run_m3c(world(); seed), run_m3c(world(p_side = 1.0, side_share = 1.0); seed)
        @test burnt(harmed) > burnt(clean)
    end
end

# Harm done by StandCoin-lane work burns currency (8.67, ruled): charged to its proposer and
# pledging experts by their contributions, as a priced action's harm is. No currency qualifies
# (status bars at 1), so all work runs in the lane; side harm on every action.
@testset "Probe: harm done by lane work burns currency" begin
    world(; kw...) = M3cParams(ToyParams(n = 12, steps = 40, plans = 4), [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.1) for _ in 1:2],
                               [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                               threshold = 1.0, novel_threshold = 1.0, coarse_threshold = 1.0, form_count = 10^6, init_steps = 5,
                               endowment = 50.0, kw...)
    clean, harmed = run_m3c(world(p_side = 0.0); seed = 1), run_m3c(world(p_side = 1.0, side_share = 1.0); seed = 1)
    @test clean.lane_executed > 0 && harmed.side_hazards > 0
    spent(tr) = (tr.endowed - sum(tr.balance) - sum(tr.reinvested)) / max(tr.lane_executed, 1)  # currency gone per lane action
    @test spent(harmed) > spent(clean) + 0.1          # acceptance: harmful lane work costs its doers more than its resources
    @test sum(harmed.balance) + sum(harmed.reinvested) - harmed.endowed ≈ sum(harmed.supply; init = 0.0) + sum(harmed.lane_supply) atol = 1e-6
end

# Progressive degradation, loudly (CLAUDE.md, Verification): a measurement outage substitutes
# payment by prediction for measurement, and the run neither stalls nor hides it: the trace names
# the substitution and its window.
@testset "Probe: a failing mechanism degrades loudly and the run carries on" begin
    world(events) = M3cParams(ToyParams(n = 12, steps = 60, plans = 4), [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.1) for _ in 1:2],
                              [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                              form_count = 10^6, init_steps = 10, events)
    tr = run_m3c(world([shock(:outage; step = 30, duration = 10)]); seed = 1)
    out = [(k, v) for (k, v) in tr.degraded if startswith(k, "measurement")]
    @test length(out) == 1 && 30 <= out[1][2].first <= 31 && 38 <= out[1][2].last <= 40   # loud: named, with its window
    @test length(tr.floor_u) >= 60 && tr.lane_executed > 0                                    # carries on: no stall
    @test isempty([k for k in keys(run_m3c(world(Shock[]); seed = 1).degraded) if startswith(k, "measurement")])
end

# Prediction accuracy as reputation's fourth component (8.69, [P]): each choice is a prediction that
# its outcome is good, scored as skill over the domain's model (Brier skill: 1 − the chooser's Brier
# score over the model's on the same choices). A high-volume mediocre doer, a low-volume accurate one
# and a funder backing actions at random, against the summed value L100 records.
@testset "Probe: prediction accuracy ranks judgement where summed reputation ranks volume and capital" begin
    model = 0.6                                                          # the domain model's credence on every choice
    # exact hit rates: twenty choices drawn at 0.9 can come out at 0.75 and read as no skill, so a
    # record needs a minimum length before its skill means anything (as a model's does)
    draw(n, p) = Float64.((1:n) .<= round(Int, p * n))
    mediocre, accurate, funded = draw(200, 0.55), draw(20, 0.9), draw(100, 0.6)
    summed(o, share = 1.0) = share * sum(2 .* o .- 1)                    # L100: value caused, gains less losses
    # Counterexample, the current rule: summed value ranks volume over judgement and pays capital.
    @test summed(mediocre) > summed(accurate) && summed(funded, 0.5) > 0
    # Acceptance: skill over the model ranks the accurate chooser first and gives the random funder
    # nothing in the subject domain (a choice that follows the model earns no skill).
    skill(o, cred) = choice_skill(fill(cred, length(o)), fill(model, length(o)), o)
    @test skill(accurate, 0.9) > skill(mediocre, 0.8) && skill(accurate, 0.9) > 0.3
    @test abs(skill(funded, model)) < 1e-12
    # A selector backing an expert who wins: its choice is classified into expert selection, and the
    # domain overlaps spread the score (8.69 amendment): most to the selection leaf, little to the subject.
    picks = draw(30, 0.85)
    shares = [0.7, 0.2, 0.1]                                             # selection leaf, its parent, the subject domain
    credit = skill(picks, 0.85) .* shares
    @test credit[1] > credit[2] > credit[3] > 0 && credit[3] < 0.2 * credit[1]
    @test_throws ArgumentError choice_skill([0.9], [0.6, 0.6], [1.0])
end

# Identity binding by Technology Network clusters (B2; L18): an attestation is a choice, scored like
# any other (8.69), so a cluster's say in the quorum follows its attestation record. Five clusters;
# two collude and attest sybils at 0.99; honest clusters attest real entities near 0.85 and sybils
# near 0.2. Earlier sybils from the pair were revealed, so their records show it.
@testset "Probe: colluding clusters lose their say once their sybils are revealed" begin
    rng = Xoshiro(11)
    th, quorum = 0.75, 2
    honest = [3, 4, 5]; colluders = [1, 2]
    attest(real) = [c in colluders ? (real ? 0.85 : 0.99) : clamp((real ? 0.85 : 0.2) + 0.08 * randn(rng), 0, 1) for c in 1:5]
    # Records: 40 past attestations each, scored against what later turned out (1 real, 0 sybil).
    outcomes = Float64.(rand(rng, 40) .< 0.7)
    rec(c) = [c in colluders ? (o == 1 ? 0.85 : 0.99) : (o == 1 ? 0.85 : 0.2) for o in outcomes]
    skill = [choice_skill(rec(c), fill(0.7, 40), outcomes) for c in 1:5]
    sybils = [attest(false) for _ in 1:50]; reals = [attest(true) for _ in 1:50]
    # Counterexample, the count rule: the colluding pair alone makes a quorum, revealed or not.
    @test all(binding_admits(s, th; quorum) for s in sybils)
    # Acceptance: weighted by attestation skill, sybils from the pair are refused and real entities
    # still bound by the honest clusters.
    @test skill[1] < 0 && all(skill[honest] .> 0.3)
    @test !any(binding_admits_weighted(s, skill, th, quorum * 0.5) for s in sybils)
    @test count(binding_admits_weighted(r, skill, th, quorum * 0.5) for r in reals) >= 45
end

# Binding with honest newcomers (B2 step 2): attestations are scored on both sides. Real newcomers
# outnumber sybils ten to one. A colluding cluster vouches for everyone (0.99): right on the many
# real newcomers, wrong on the few sybils. An honest cluster misses one identity in ten either way.
@testset "Probe: a colluder cannot buy its say by being right about the easy majority" begin
    n_real, n_syb = 200, 20
    out = [ones(n_real); zeros(n_syb)]
    colluder = fill(0.99, n_real + n_syb)
    honest = [i % 10 == 0 ? (o == 1 ? 0.1 : 0.9) : (o == 1 ? 0.9 : 0.1) for (i, o) in enumerate(out)]
    pooled(c) = choice_skill(c, fill(0.5, length(c)), out)
    # Counterexample: pooled skill against a coin toss rewards the colluder for the easy majority.
    @test pooled(colluder) > 0.5
    # Acceptance: skill read on each side (real, sybil) and the worse side kept: the colluder fails on
    # sybils and loses its say; the honest cluster keeps it.
    @test class_balanced_skill(colluder, out) < 0 && class_balanced_skill(honest, out) > 0.5
    @test class_balanced_skill(fill(0.9, 10), ones(10)) > 0      # one side only: that side's skill
    @test_throws ArgumentError class_balanced_skill([0.9], [1.0, 0.0])
end

# External harm response (L117, `Governance.ExternalHarm` [R]; exported for M6's external aggressors):
# the expected response to a harm h is proportional, lowered for an aggressor with a record of good
# in the harmed domains (forgiveness, α·Re₊) and raised by at most the margin for one with a record of
# harm (overreaction, δ·Re₋, capped so the chances sum to at most 1). α > δ (L11).
@testset "Probe: external harm meets a proportional, record-weighted response" begin
    r(h, rp, rn) = ehr_expected_response(h, rp, rn; alpha = 0.02, delta = 0.01, margin = 0.5)
    @test r(10.0, 0.0, 0.0) ≈ 10.0                              # no record: in proportion
    @test r(10.0, 20.0, 0.0) < r(10.0, 0.0, 0.0)                # a record of good earns forgiveness
    @test r(10.0, 0.0, 30.0) > r(10.0, 0.0, 0.0)                # a record of harm raises the response
    @test r(10.0, 0.0, 1e6) <= 10.0 * 1.5 + 1e-9                # never beyond the margin
    @test r(10.0, 1e6, 1e6) ≈ 0.0 atol = 1e-9                   # full forgiveness leaves no room to overreact
    @test r(20.0, 5.0, 5.0) ≈ 2 * r(10.0, 5.0, 5.0)             # proportional in the harm
    @test_throws ArgumentError r(-1.0, 0.0, 0.0)
end

# The reporter's schedule (author ruling 8.76; Lean `self_report_net_constant`): with e the gain of one
# exploit and b the bonus, a self-reporter nets e + b however many times it exploited first; someone
# caught by another nets nothing from its exploits and pays the reporter's bonus and the audit; the
# reporter is paid one exploit plus the bonus per exploiter (a cabal of three: three exploits plus bonuses).
@testset "Probe: the reporter's schedule leaves exploiting before reporting worthless" begin
    e, b, audit = 10.0, 3.0, 2.0
    net(n) = n * e + self_report_payout(n, e, b)
    @test net(0) ≈ e + b && net(1) ≈ e + b && net(5) ≈ e + b           # report without exploit, after 1, after 5
    @test self_report_payout(5, e, b) ≈ b - 4e                          # four exploits clawed back, bonus paid
    caught(n) = n * e - caught_charge(n * e, b, audit)                  # all clawed back, the reporter's bonus too
    @test caught(5) ≈ -(b + audit) && caught(5) < net(5)
    cabal = [(4, 4e), (2, 2e), (7, 7e)]                                 # (exploits, clawback) per exploiter
    @test sum(caught_reward(c, n, b) for (n, c) in cabal) ≈ 3 * (e + b)
    @test_throws ArgumentError self_report_payout(-1, e, b)
end

# The ratchet on status bars (author ruling 8.84): when k models (governed, default 3) operate above a
# domain's bar, the bar rises to the k-th best accuracy less a margin, so k models still clear it; it
# never falls by this rule. A low-noise world where better challengers keep arriving (the controlled
# world, models that can exceed the bootstrap bar of 0.9).
@testset "Probe: the status bar ratchets up when enough models clear it, and never falls" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    w(; kw...) = M3cParams(ToyParams(n = 60, steps = 800, plans = 8), [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:4],
                    [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, LEGACY...,
                    p_new_model = 0.1, takeover_records = 30, ratchet_horizon = 10.0, kw...)   # a low-noise world names a shorter horizon
    for seed in 1:2
        tr = run_m3c(w(); seed)
        b = tr.bar_trace                                         # leaf 1's bar, step by step
        @test all(diff(b) .>= 0)                                  # never falls
        @test b[end] > b[1] + 0.01                                # it rose once enough models cleared it
        @test tr.lane_halted == 0                                 # pricing goes on
        @test run_m3c(w(ratchet_k = 0); seed).bar_trace[end] == b[1]   # red baseline: without it the bar stays
    end
    # Counterexample: where models swing together over short horizons (the better-models world, high
    # noise), a bar read over the eligibility horizon locked at a quiet stretch and own-currency pricing
    # fell from 0.79 to 0.38; over the default (twenty times longer) it leaves pricing as without it.
    nw(; kw...) = M3cParams(ToyParams(n = 80, steps = 400, plans = 10),
        [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.3) for _ in 1:8], [1, 1, 2, 2], trues(4);
        λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, LEGACY..., σ_leaf = 0.45, σ_branch = 0.6,
        σ_coarse = 0.75, p_new_model = 0.05, kw...)
    own(tr) = mean(tr.priced_leaf[i] == tr.true_leaf[i] for i in eachindex(tr.chosen_step) if tr.chosen_step[i] >= 100)
    on, off = run_m3c(nw(); seed = 1), run_m3c(nw(ratchet_k = 0); seed = 1)
    @test own(on) >= own(off) - 0.02 && all(on.leaf_bars .<= 0.905)
    # The short horizon locks: own-currency pricing significantly drops across seeds (paired effect)
    short_diffs = [own(run_m3c(nw(ratchet_horizon = 1.0); seed)) - own(run_m3c(nw(); seed)) for seed in 1:4]
    @test paired_effect(short_diffs; direction = :down).significant
end

# Accuracy averaged over time, half-life by transaction rate, muted (author ruling 8.85). The smallest
# world: one model's records at a slow rate (1 per step) and a busy one (40 per step), the same model
# turning miscalibrated at step 200 (credence 0.9 throughout; outcomes true at 0.9, then at 0.5). Red on
# the outcome under the fixed record window (the last 100 records, the limiting case): the slow domain
# registers the change later, and the busy one's accuracy swings with every few records.
@testset "Probe: time-decayed accuracy, half-life by transaction rate (8.85)" begin
    using Random
    hl(r) = decay_halflife(r; ref_rate = 5.0, ref_halflife = 7.0, mute = 0.5)
    stream(rate, seed) = (rng = Xoshiro(seed); [(t, 0.9, rand(rng) < (t < 200 ? 0.9 : 0.5) ? 1.0 : 0.0) for t in 1:400 for _ in 1:rate])
    win(recs, t) = (r = [x for x in recs if x[1] <= t]; r = r[max(1, end - 99):end]; credence_accuracy(getindex.(r, 2), getindex.(r, 3)))
    dec(recs, t, h) = (r = [x for x in recs if x[1] <= t]; decayed_accuracy(getindex.(r, 2), getindex.(r, 3), [t - x[1] for x in r], h))
    mid = (credence_accuracy([0.9], [1.0]) * 0.9 + credence_accuracy([0.9], [0.0]) * 0.1) / 2   # half the expected accuracy before
    lag(f) = something(findfirst(t -> f(t) < mid, 200:400), 999)
    # The rule itself: muted between a fixed record count (half-life ∝ 1 / rate) and a fixed time.
    @test hl(1.0) < 7.0 * 5.0 / 1.0 && hl(1.0) > 7.0                # slow: shorter than a fixed count, longer than a fixed time
    @test hl(40.0) > 7.0 * 5.0 / 40.0 && hl(40.0) < 7.0             # busy: longer than a fixed count, shorter than a fixed time
    @test hl(0.0) == 7.0                                             # no transactions yet: the reference
    for seed in 1:3
        slow, busy = stream(1, seed), stream(40, seed)
        # The slow domain pivots faster than over its last 100 records (lags in steps: 8 against 13 in seed 1).
        @test lag(t -> dec(slow, t, hl(1.0))) < lag(t -> win(slow, t))
        # The busy domain is steadier than over its last 100 records.
        @test std(diff([dec(busy, t, hl(40.0)) for t in 100:199])) < std(diff([win(busy, t) for t in 100:199]))
    end
end

# Time-decayed record credence, uncertainty, track and AdvAp windows (8.85).
# Under a fixed window, when an error distribution shifts (narrow to wide), old records keep the
# credence misleadingly high and uncertainty low; time decay weights by age so the model pivots
# faster to the shift, and yields steadier readings across busy transaction streams.
@testset "Probe: time-decayed record credence, uncertainty, track and AdvAp windows (8.85)" begin
    rng = Xoshiro(42)
    errs = [t < 100 ? 0.1 * abs(randn(rng)) : 2.0 * abs(randn(rng)) for t in 1:150]
    ages_at(t) = Float64[t - s for s in 1:t]
    win_errs = errs[21:120]
    win_cred = record_credence(0.5, win_errs)
    dec_cred = decayed_record_credence(0.5, errs[1:120], ages_at(120), 10.0)
    @test win_cred > 0.75 && dec_cred < 0.4
    @test dec_cred < win_cred - 0.3

    win_rms = sqrt(mean(abs2, win_errs))
    dec_u = decayed_rms(errs[1:120], ages_at(120), 10.0)
    @test dec_u > win_rms + 0.5

    stream = [(t, abs(randn(rng))) for t in 1:60 for _ in 1:10]
    dec_series = [decayed_rms([x[2] for x in stream if x[1] <= t], Float64[t - x[1] for x in stream if x[1] <= t], 7.0) for t in 20:60]
    win_series = [sqrt(mean(abs2, [x[2] for x in stream if x[1] <= t][max(1, end-9):end])) for t in 20:60]
    @test std(diff(dec_series)) < std(diff(win_series)) * 0.2

    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    w(; kw...) = M3cParams(ToyParams(n = 16, steps = 30, plans = 4),
                           [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.1) for _ in 1:2],
                           [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, LEGACY..., kw...)
    tr_dec = run_m3c(w(accuracy_rule = :decay); seed = 1)
    tr_win = run_m3c(w(accuracy_rule = :window); seed = 1)
    @test length(tr_dec.floor_u) == 31 && length(tr_win.floor_u) == 31
    @test all(tr_dec.floor_u .>= 0) && all(tr_win.floor_u .>= 0)

    @test_throws ArgumentError decayed_record_credence(0.5, [1.0], [1.0, 2.0], 5.0)
    @test_throws ArgumentError decayed_rms([1.0], [1.0, 2.0], 5.0)
    @test_throws ArgumentError decayed_rms([1.0], [1.0], -1.0)
end

# Fallback order across pool, parent, relative bar and StandCoin, and RA contraction (C3, 8.71, 8.73).
# When an incumbent leaf model is captured, if a qualified challenger is present in the domain's pool,
# it is promoted before pricing falls back to parent, degrading loudly and maintaining leaf pricing.
# Scarcity cost rises steeply as available capacity contracts, remaining finite at zero availability.
@testset "Probe: fallback order across pool, parent, relative bar and StandCoin, and RA contraction (C3, 8.71, 8.73)" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    w_cap(; kw...) = M3cParams(ToyParams(n = 20, steps = 70, plans = 6),
                              [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.1) for _ in 1:4],
                              [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                              events = [shock(:capture; step = 25, duration = 35, size = 3.0, target = 1)], LEGACY..., kw...)
    tr_no_chall = run_m3c(w_cap(p_new_model = 0.0); seed = 1)
    k_no = [i for i in eachindex(tr_no_chall.chosen_step) if tr_no_chall.true_leaf[i] == 1 && 30 <= tr_no_chall.chosen_step[i] <= 55]
    p_no = isempty(k_no) ? 0.0 : mean(tr_no_chall.priced_leaf[k_no] .== 1)
    @test p_no == 0.0

    tr_chall = run_m3c(w_cap(p_new_model = 0.3, takeover_records = 5, min_records = 5); seed = 1)
    k_ch = [i for i in eachindex(tr_chall.chosen_step) if tr_chall.true_leaf[i] == 1 && 30 <= tr_chall.chosen_step[i] <= 55]
    p_ch = isempty(k_ch) ? 0.0 : mean(tr_chall.priced_leaf[k_ch] .== 1)
    @test p_ch > 0.8
    @test tr_chall.takeovers >= 1
    @test any(startswith(k, "incumbent leaf model") for k in keys(tr_chall.degraded))

    cap = 100.0
    c_full = scarcity_cost(2.0, 100.0, cap; floor_share = 0.001)
    c_half = scarcity_cost(2.0, 50.0, cap; floor_share = 0.001)
    c_low = scarcity_cost(2.0, 10.0, cap; floor_share = 0.001)
    c_zero = scarcity_cost(2.0, 0.0, cap; floor_share = 0.001)
    @test c_full ≈ 2.0 && c_half ≈ 4.0 && c_low ≈ 20.0
    @test c_full < c_half < c_low < c_zero
    @test c_zero ≈ 2.0 / 0.001
end

# Entry-point binding, domain currency non-fungibility and quote honesty (B5, 8.72, 8.78, 8.80).
# An identity refused by binding_admits_weighted at entry point cannot transact. Domain balances
# are non-fungible across domains (wealth in leaf 1 cannot pay leaf 3 transaction price).
# Models quoting dishonestly lose credence accuracy and are overtaken by honest candidates.
@testset "Probe: entry-point binding, domain currency non-fungibility and quote honesty (B5, 8.72, 8.78, 8.80)" begin
    bad_confs = [0.1, 0.2, 0.1]
    weights = [1.0, 1.0, 1.0]
    @test !binding_admits_weighted(bad_confs, weights, 0.75, 1.5)
    @test !binding_admits_weighted([0.9, 0.9, 0.1], [-1.0, -1.0, 0.5], 0.75, 1.0)

    cost = 10.0; val = 5.0; cr = 0.8
    tp = transaction_price(cost, val, cr)
    @test tp > 0.0
    balance_leaf1 = 100.0
    balance_leaf3 = 0.0
    @test tp <= balance_leaf1
    @test !(tp <= balance_leaf3)

    rng = Xoshiro(999)
    N = 300
    outs = Float64.(rand(rng, N) .< 0.7)
    acc_honest = credence_accuracy(fill(0.7, N), outs)
    acc_dishonest = credence_accuracy(fill(0.99, N), outs)
    @test acc_honest > acc_dishonest

    sc_h = [credence_score(0.7, o) for o in outs]
    sc_d = [credence_score(0.99, o) for o in outs]
    m_h, se_h = mean(sc_h), std(sc_h) / sqrt(N)
    m_d, se_d = mean(sc_d), std(sc_d) / sqrt(N)
    @test select_candidate([m_d, m_h], [se_d, se_h]; z = 2.0) == 2
end

# Accession and uplift (8.86).
# Forced additions enter the floor denominator immediately; strong accession admissibility protects
# existing beings over the long-term window while lifting newcomers, and falls back loudly to weak
# floor admissibility when uplift capacity is exceeded.
@testset "Probe: accession and uplift (8.86)" begin
    p = ToyParams(n = 100, steps = 30, plans = 10)
    t_acc = run_m7(p; seed = 1, accession_step = 10, accession_n = 50)
    t_stag = run_m7(p; seed = 1, accession_step = 10, accession_n = 50, existing_only_floors = true)
    @test t_acc.newcomer_u_gain > 2.0 && t_acc.newcomer_h_gain > 2.0
    @test isempty(t_acc.degraded) && isempty(t_acc.nha_bearers)
    @test t_stag.newcomer_u_gain < 0.8 && t_acc.newcomer_u_gain > 5 * t_stag.newcomer_u_gain   # traits mode (8.120) at CALIBRATED.view_σ = 0.3: 0.686; the ratio is the claim
    t_out = run_m7(p; seed = 1, accession_step = 10, accession_n = 150)
    @test t_out.newcomer_u_gain > 2.0 && isempty(t_out.degraded) && isempty(t_out.nha_bearers)
    t_tight = run_m7(p; seed = 1, accession_step = 10, accession_n = 150, uplift_capacity = 20, lt_window = 2)
    @test t_tight.newcomer_u_gain > 1.0 && !isempty(t_tight.degraded) && !isempty(t_tight.nha_bearers)
end

# Quantile scoring of tail and median forecasts (E4, DATA §16b).
# Pinball loss penalises over- and under-prediction asymmetrically by quantile q;
# calibrated quantile forecasts score higher than uncalibrated or biased forecasts.
@testset "Probe: quantile scoring of tail and median forecasts (E4, DATA §16b)" begin
    # Red test on the outcome: sharp calibrated quantiles vs under-predicting quantiles
    # Let true distribution be N(10, 2^2)
    # Quantiles [0.1, 0.5, 0.9] -> true values [10 - 1.28*2, 10, 10 + 1.28*2] = [7.44, 10.0, 12.56]
    # Under-predicting forecaster predicts [4.0, 6.0, 8.0]
    # Over-predicting forecaster predicts [12.0, 14.0, 16.0]
    rng = Xoshiro(20261103)
    outcomes = 10.0 .+ 2.0 .* randn(rng, 500)
    qs = [0.1, 0.5, 0.9]

    # Perfect quantile forecast per observation
    calibrated_loss = mean([mean([pinball_loss(q, 10.0 + 2.0 * normal_quantile(q), y) for q in qs]) for y in outcomes])
    under_loss = mean([mean([pinball_loss(q, 6.0 + 2.0 * normal_quantile(q), y) for q in qs]) for y in outcomes])
    over_loss = mean([mean([pinball_loss(q, 14.0 + 2.0 * normal_quantile(q), y) for q in qs]) for y in outcomes])

    @test calibrated_loss < under_loss
    @test calibrated_loss < over_loss

    # Pinball loss exact checks
    @test pinball_loss(0.5, 10.0, 12.0) ≈ 0.5 * 2.0
    @test pinball_loss(0.5, 10.0, 8.0) ≈ 0.5 * 2.0
    @test pinball_loss(0.9, 10.0, 12.0) ≈ 0.9 * 2.0
    @test pinball_loss(0.9, 10.0, 8.0) ≈ 0.1 * 2.0

    # Quantile score in [0, 1]
    scale = 2.0
    score_cal = quantile_score(repeat(qs, length(outcomes)),
                               vcat([fill(10.0 + 2.0 * normal_quantile(q), length(outcomes)) for q in qs]...),
                               repeat(outcomes, 3), scale)
    score_under = quantile_score(repeat(qs, length(outcomes)),
                                 vcat([fill(6.0 + 2.0 * normal_quantile(q), length(outcomes)) for q in qs]...),
                                 repeat(outcomes, 3), scale)
    @test 0.0 < score_under < score_cal <= 1.0

    @test_throws ArgumentError pinball_loss(0.0, 1.0, 2.0)
    @test_throws ArgumentError pinball_loss(1.0, 1.0, 2.0)
    @test_throws ArgumentError quantile_score([0.5], [1.0], [2.0], -1.0)
end

# AdvAp: revelation dominates exploitation, anti-cobra liability prevents flaw-planting, and
# pattern threshold stops frivolous reporting (L160, 8.42.1).
@testset "Probe: AdvAp revelation dominance, anti-cobra liability, and pattern threshold (L160)" begin
    # 1. Minimal world: 6 agents, 40 decisions, a colluding voting bloc (colluders = [1, 2]).
    # Defection is dominant because whistleblower reward exceeds the colluder's share of the exploit.
    skills = fill(0.7, 6, 2); focus = fill(0.5, 6, 2)
    agents = [DomainAgent(skills[i, :], focus[i, :], 0.2) for i in 1:6]
    m3_stub = (relevance_leaf = fill(1.0, 6, 2), agents = agents)
    p_no  = M5Params(m3_stub, [1]; decisions = 40, colluders = [1, 2], advap = false, p_weigh = 0.5, p_trace = 0.9, collusion_gain = 1.0)
    p_adv = M5Params(m3_stub, [1]; decisions = 40, colluders = [1, 2], advap = true,  p_weigh = 0.5, p_trace = 0.9, collusion_gain = 1.0)

    # Counterexample: without AdvAp, the colluders manipulate decisions with impunity (0 revelations).
    r_no = run_m5(p_no; seed = 1)
    @test r_no.advap_established == 0
    @test r_no.advap_rewards == 0.0

    # Acceptance: with AdvAp, defection dominates collusion; whistleblower reveals the corrupt bloc,
    # claiming reward; liability is clawed back from the corrupt bloc, and decisions are repaired.
    r_adv = run_m5(p_adv; seed = 1)
    @test r_adv.advap_established > 0
    @test r_adv.advap_rewards > 0.0
    @test r_adv.advap_liability > r_adv.advap_rewards

    # 2. Structural reward and liability invariants (Lean advap_reward_ref, advap_liability_ref)
    gain, harm, audit = 15.0, 50.0, 3.0
    r = advap_reward(gain, harm; share = 0.2, floor = 2.0)
    @test r > gain                                                     # dominates: reward exceeds exploit gain
    @test r == gain + 0.2 * harm                                       # exact: gain plus share of prevented harm
    @test report_penalty(3, 5; audit_cost = audit) == 0.0              # honest reporting: zero penalty below threshold

    l = advap_liability(r; audit_cost = audit)
    @test l - r >= audit                                               # net loss: at least audit cost
    @test report_penalty(6, 5; audit_cost = audit) == audit            # frivolous pattern: audit penalty

    @test ratchet_credence(0.9, 0.0) ≈ 0.9
    @test ratchet_credence(0.9, 1.0) ≈ 0.5
    @test ratchet_credence(0.9, 0.5) < 0.9 && ratchet_credence(0.9, 0.5) > 0.5
    @test_throws ArgumentError advap_reward(NaN, 1.0; share = 0.1, floor = 1.0)
    @test_throws ArgumentError report_penalty(-1, 5; audit_cost = audit)
end

# Model pool candidate selection: challengers compete under significance testing (select_candidate)
# over takeover_records; an unvetted or noisy model cannot usurp the incumbent (8.73, 8.84).
@testset "Probe: model pool candidate selection and takeover under significance testing (8.73, 8.84)" begin
    # 1. Minimal split trial world: 60 experimental units evaluating incumbent vs challengers.
    rng = Xoshiro(42)
    # Acceptance: Candidate A is genuinely and significantly superior (mean 1.5 vs 0.5, σ = 0.5)
    tr_a = split_trial(rng, [0.5, 1.5], [0.5, 0.5]; units = 60, σ = 0.5, z = 2.0)
    @test tr_a.winner == 2 && tr_a.significant

    # Counterexample: Candidate B has a slightly higher noisy sample mean (0.6 vs 0.5) but
    # high variance (σ = 2.0) and fails the significance test -> incumbent retained (index 1).
    tr_b = split_trial(rng, [0.5, 0.6], [0.5, 0.5]; units = 20, σ = 2.0, z = 2.0)
    @test tr_b.winner == 1

    # Direct select_candidate edge checks
    @test select_candidate([0.70, 0.82], [0.02, 0.02]; z = 2.0) == 2
    @test select_candidate([0.70, 0.75], [0.02, 0.08]; z = 2.0) == 1
    @test select_candidate([0.70, 0.65], [0.02, 0.02]; z = 2.0) == 1
    @test_throws ArgumentError select_candidate([0.8], [0.02, 0.02]; z = 2.0)
end

# Whitewashing resistance: an entity abandoning a degraded identity cannot rejoin with a clean slate
# when identity binding weights clusters by their attestation track record (8.70, B2).
@testset "Probe: whitewashing resistance through weighted binding (8.70, B2)" begin
    # Minimal world: 5 clusters (2 compromised with negative past skill, 3 honest with positive skill).
    # 30 re-entry attempts by an entity seeking to whitewash a degraded record.
    rng = Xoshiro(99)
    cluster_skills = [-0.4, -0.3, 0.6, 0.5, 0.7]
    threshold = 0.70
    quorum = 2

    # Compromised clusters vouch strongly (0.95), honest clusters deny (0.15)
    ww_trials = [clamp.([0.95, 0.95, 0.15, 0.15, 0.15] .+ 0.02 .* randn(rng, 5), 0.0, 1.0) for _ in 1:30]
    honest_trials = [clamp.([0.20, 0.15, 0.85, 0.80, 0.90] .+ 0.02 .* randn(rng, 5), 0.0, 1.0) for _ in 1:30]

    # Counterexample: unweighted count rule admits the whitewashed entity on every attempt (2 bought clusters clear quorum).
    adm_unweighted = count(t -> binding_admits(t, threshold; quorum = quorum), ww_trials)
    @test adm_unweighted == 30

    # Acceptance: weighted binding completely refuses the whitewashed entity (0/30 admitted)
    # because compromised clusters have negative skill weight, while admitting honest newcomers.
    adm_weighted = count(t -> binding_admits_weighted(t, cluster_skills, threshold, quorum * 0.5), ww_trials)
    adm_honest = count(t -> binding_admits_weighted(t, cluster_skills, threshold, quorum * 0.5), honest_trials)
    @test adm_weighted == 0
    @test adm_honest >= 28
end

# Justice for slander: every audit caused by a detected liar's false reports is clawed back as a crime (8.82).
@testset "Probe: justice for slander claws back audit costs from detected liars (8.82)" begin
    # 1. Minimal world in M3c: 2 agents, 30 steps.
    # Agent 1 repeatedly files frivolous slander reports against Agent 2 (slander = [2, 0], frivolous = [1.0, 0.0]).
    w_slander = M3cParams(ToyParams(n = 6, steps = 30, plans = 2),
                          [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.1) for _ in 1:2],
                          [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true,
                          causal_distribution = true, form_count = 10^5, init_steps = 3,
                          advap = true, frivolous = [1.0, 0.0], frivolous_threshold = 2, audit_cost = 2.0,
                          slander = [2, 0])
    w_clean = M3cParams(ToyParams(n = 6, steps = 30, plans = 2),
                        [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.1) for _ in 1:2],
                        [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true,
                        causal_distribution = true, form_count = 10^5, init_steps = 3,
                        advap = true, frivolous = [0.0, 0.0], frivolous_threshold = 2, audit_cost = 2.0,
                        slander = [0, 0])

    # Acceptance: once the frivolous pattern is detected, Agent 1 is branded a slanderer,
    # and all past and future audit costs are clawed back via false_report_charge.
    tr_s = run_m3c(w_slander; seed = 1)
    @test 1 in tr_s.slanderers
    @test tr_s.advap_penalties > 0.0
    @test tr_s.advap_penalties == tr_s.advap_reports * 2.0  # every false audit clawed back

    # Counterexample: clean world with no frivolous pattern incurs zero slander penalties.
    tr_c = run_m3c(w_clean; seed = 1)
    @test isempty(tr_c.slanderers)
    @test tr_c.advap_penalties == 0.0

    # Rule invariant checks
    charge = false_report_charge(10.0, 4.0, 2.0)
    @test charge ≈ 16.0
    @test_throws ArgumentError false_report_charge(-1.0, 4.0, 2.0)
end

# Causal distribution: joint value is attributed by marginal contribution (Shapley), rewarding
# genuine contributors and starving free-riders, whereas equal sharing dilutes incentives (L100).
@testset "Probe: causal distribution rewards marginal contribution and starves free-riders (L100)" begin
    # 1. Minimal collaborative team world: Agent 1 (producer), Agent 2 (assistant), Agent 3 (free-rider).
    # Characteristic function v over coalitions of size 3 (represented as integer bitmasks 0:7).
    # Coalition values: {1} = 10.0, {2} = 5.0, {1,2} = 20.0, and Agent 3 adds 0.0 to all coalitions.
    v = [0.0, 10.0, 5.0, 20.0, 0.0, 10.0, 5.0, 20.0]
    shares = shapley(v)

    # Acceptance: Shapley shares attribute exactly according to marginal contribution.
    # The primary producer gets the majority share; the assistant gets a positive share;
    # the free-rider gets strictly 0.0.
    @test shares[1] > 10.0
    @test shares[2] > 0.0
    @test shares[3] == 0.0
    @test sum(shares) ≈ v[end] - v[1]

    # Counterexample: equal sharing gives the free-rider 1/3 of the pot (6.67), diluting the producer.
    equal_share = v[end] / 3
    @test equal_share > shares[3]
    @test shares[1] > equal_share

    # Traversal fallback when causal assessment is unavailable (L94-95).
    t_shares = traversal_shares([10.0, 10.0], [0, 2]; decay = 0.5)
    @test t_shares[1] > t_shares[2]
    @test t_shares[1] ≈ 0.8 && t_shares[2] ≈ 0.2
end

# Escrow and settlement: upfront payment split by confidence, settled against measured outcome;
# removing the expected gain of strategic overstatement (8.86 addendum, L84).
@testset "Probe: escrow settlement removes strategic overstatement gain (8.86 addendum, L84)" begin
    # Minimal world: an actor proposes a plan with measured outcome 50.0.
    # It considers stating honest confidence (0.60) vs strategically inflating confidence (0.95).
    nominal = 100.0
    measured = 50.0
    honest_conf = 0.60
    inflated_conf = 0.95

    upfront_h, hold_h = escrow_split(nominal, honest_conf)
    upfront_i, hold_i = escrow_split(nominal, inflated_conf)

    # Acceptance under upfront payment only: inflated confidence nets +35 upfront.
    @test upfront_i - upfront_h ≈ (inflated_conf - honest_conf) * nominal

    # Settlement against measured outcome:
    settle_h = settlement(measured, upfront_h)
    settle_i = settlement(measured, upfront_i)

    # Excess upfront is clawed back in settlement:
    @test settle_i < 0.0 && settle_i < settle_h
    total_h = upfront_h + settle_h
    total_i = upfront_i + settle_i

    # Acceptance: net payout is invariant and equals exact measured outcome.
    # Strategic overstatement yields exactly 0.0 excess payout.
    @test total_h ≈ measured
    @test total_i ≈ measured
    @test total_h ≈ total_i

    # Counterexample: without escrow settlement (upfront-only regime), overstatement gains +35.
    @test upfront_i > upfront_h
end

# The debatable escape: local trial adopted only if proposal beats incumbent significantly,
# gains exceed harms where tried, and no irreparable harm was caused (M4, L157).
@testset "Probe: debatable escape accepts significant harmless proposals and rejects harm (M4, L157)" begin
    # 1. Minimal world in M3c: 4 agents with balanced skills across domains, 60 steps with a 30-step trial.
    ag = [DomainAgent(fill(0.6, 4), fill(0.25, 4), 0.1) for _ in 1:4]
    w_escape(; kw...) = M3cParams(ToyParams(n = 40, steps = 60, plans = 6), ag, [1, 1, 2, 2], trues(4);
                                  λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                                  init_steps = 5, escape = true, escape_start = 10, escape_steps = 30, escape_epoch = 5,
                                  escape_share = 0.5, credence_rule = :normal, LEGACY..., kw...)
    for seed in 1:2
        tr_e = run_m3c(w_escape(); seed)
        @test tr_e.escape.tried
        # Acceptance: trial generates positive gains exceeding harms with zero irreparable harm
        @test tr_e.escape.gains > tr_e.escape.harms
        @test tr_e.escape.irreparable == 0
    end

    # Counterexample in world: trial with tight irreparable threshold registers irreparable harm and is rejected
    tr_strict = run_m3c(w_escape(irreparable_loss = 0.001); seed = 1)
    @test tr_strict.escape.tried && tr_strict.escape.irreparable > 0 && !tr_strict.escape.adopted

    # 2. Structural invariants on escape acceptance rule (Lean escape_accept_ref)
    m_inc, se_inc = 1.0, 0.1
    m_prop, se_prop = 1.5, 0.1
    @test escape_accept([m_inc, m_prop], [se_inc, se_prop]; gains = 10.0, harms = 2.0, irreparable = 0, z = 2.0)
    @test !escape_accept([m_inc, m_prop], [se_inc, se_prop]; gains = 10.0, harms = 2.0, irreparable = 1, z = 2.0)
    @test !escape_accept([m_inc, m_prop], [se_inc, se_prop]; gains = 2.0, harms = 10.0, irreparable = 0, z = 2.0)
    @test !escape_accept([m_inc, 1.05], [se_inc, se_prop]; gains = 10.0, harms = 2.0, irreparable = 0, z = 2.0)
    @test_throws ArgumentError escape_accept([1.0], [0.1]; gains = 1.0, harms = 0.0, irreparable = 0, z = 1.0)
    @test_throws ArgumentError escape_accept([1.0, 2.0], [0.1, 0.1]; gains = -1.0, harms = 0.0, irreparable = 0, z = 1.0)
end

# M5 deliberation: expertise weighting amplifies domain knowledge, and liquid delegation caps
# prevent dictatorship accumulation (8.90, B26, L113-114).
@testset "Probe: M5 liquid delegation cap and expertise weighting (8.90, B26, L113-114)" begin
    # 1. Minimal deliberation world: 20 voters, 30 decisions.
    # Voter 1 is a domain expert with high reputation. Other voters delegate with chance 0.8.
    nv = 20
    skills = fill(0.5, nv, 4); skills[1, :] .= 0.95
    focus = fill(0.25, nv, 4); focus[1, :] = [0.7, 0.1, 0.1, 0.1]
    reputation = fill(0.1, nv, 4); reputation[1, :] = [10.0, 0.1, 0.1, 0.1]
    agents = [DomainAgent(skills[i, :], focus[i, :], 0.2) for i in 1:nv]
    m3_stub = (relevance_leaf = reputation, agents = agents)

    # Counterexample: uncapped delegation allows a single delegate to accumulate 95% of voting power.
    p_uncapped = M5Params(m3_stub, [1]; decisions = 30, p_delegate = 0.8, cap = 1.0, impact_threshold = 0.5, expertise_weight = 1.0)
    r_uncapped = run_m5(p_uncapped; seed = 1)
    @test maximum(r_uncapped.max_share) > 0.85  # near dictatorship

    # Acceptance: capped delegation (cap = 0.15) strictly limits accumulated voting weight.
    p_capped = M5Params(m3_stub, [1]; decisions = 30, p_delegate = 0.8, cap = 0.15, impact_threshold = 0.5, expertise_weight = 1.0)
    r_capped = run_m5(p_capped; seed = 1)
    @test maximum(r_capped.max_share) <= 0.25  # dictatorship prevented

    # 2. Invariant checks on accumulation rule (accumulate_capped)
    cap = 10.0
    delegators = fill(2.0, 50)
    acc = accumulate_capped(cap, 0.0, delegators)
    @test acc <= cap + 2.0 && acc >= cap
    @test sum(delegators) > acc * 8

    w_expert, opt_expert = voting_weight(1.0, 1.0, [0.8, 0.2], [4.0, 0.5], 1.0, 0.2; optional_below = 2.0)
    w_bystander, opt_bystander = voting_weight(1.0, 1.0, [0.8, 0.2], [0.0, 0.0], 1.0, 0.2; optional_below = 2.0)
    @test w_expert > w_bystander * 3
    @test !opt_expert && opt_bystander
end

@testset "Probe: M5 sparse specialist scaling and correlated misconceptions (8.90, B26, L113-114)" begin
    # 1. Under copy-per-voter world without misconceptions (the legacy artifact):
    # Condorcet jury theorem drives equal-weight accuracy to saturation (>= 0.90) at nv=240,
    # causing wisdom gain (bf - eq) to shrink (+0.13 at nv=12 down to +0.03 at nv=240).
    function run_dense_equal(nv, decisions)
        skills = zeros(nv, 4)
        for i in 1:nv, d in 1:4
            if mod1(i, 4) == d
                skills[i, d] = 0.8
            end
        end
        focus = fill(0.1, nv, 4)
        for i in 1:nv
            focus[i, mod1(i, 4)] = 0.7
            focus[i, :] ./= sum(focus[i, :])
        end
        reputation = fill(0.1, nv, 4) .+ 5.0 .* skills
        m3_stub = (relevance_leaf = reputation, agents = [DomainAgent(skills[i, :], focus[i, :], 0.2) for i in 1:nv])
        p_bf = M5Params(m3_stub, [1]; decisions=decisions, signal_σ=20.0, skill_gain=5.0, p_delegate=0.6, cap=0.15, impact_threshold=0.5, vote_value=1.0)
        p_eq = M5Params(m3_stub, [1]; decisions=decisions, signal_σ=20.0, skill_gain=5.0, expertise_weight=0.0, impact_weight=0.0, p_delegate=0.0, vote_value=0.0)
        (bf = mean([run_m5(p_bf; seed=s).correct for s in 1:4]),
         eq = mean([run_m5(p_eq; seed=s).correct for s in 1:4]))
    end

    dense_12 = run_dense_equal(12, 150)
    dense_240 = run_dense_equal(240, 150)
    gain_12 = dense_12.bf - dense_12.eq
    gain_240 = dense_240.bf - dense_240.eq
    @test dense_240.eq >= 0.90         # Equal-weight saturates near 1.0 under copy-per-voter
    @test gain_240 < gain_12          # The artifact: wisdom gain shrinks (+0.13 -> +0.03)

    # 2. Under sparse specialists (k = c * n^0.3) with correlated misconceptions (misconception_σ = 1.5):
    # Non-specialists share correlated misconceptions, preventing Condorcet aggregation from
    # exceeding ~0.75 accuracy. Expertise-weighting and liquid delegation allow Benefuture to maintain
    # high accuracy (>= 0.88), so wisdom gain RISES with n.
    function run_sparse_misconception(nv, decisions; seeds = 1:6)
        c = 1.5
        k_spec = max(1, round(Int, c * nv^0.3))
        skills = zeros(nv, 4)
        focus = fill(0.1, nv, 4)
        for i in 1:k_spec
            skills[i, 1] = 0.8
            focus[i, 1] = 0.7
        end
        for d in 2:4
            for i in (k_spec*(d-1)+1):min(nv, k_spec*d)
                skills[i, d] = 0.8
                focus[i, d] = 0.7
            end
        end
        for i in 1:nv
            focus[i, :] ./= sum(focus[i, :])
        end
        reputation = fill(0.1, nv, 4) .+ 5.0 .* skills
        m3_stub = (relevance_leaf = reputation, agents = [DomainAgent(skills[i, :], focus[i, :], 0.2) for i in 1:nv])
        p_bf = M5Params(m3_stub, [1]; decisions=decisions, signal_σ=2.0, skill_gain=5.0,
                        p_delegate=0.6, cap=0.15, impact_threshold=0.5, expertise_weight=10.0,
                        vote_value=1.0, misconception_σ=1.5)
        p_eq = M5Params(m3_stub, [1]; decisions=decisions, signal_σ=2.0, skill_gain=5.0,
                        expertise_weight=0.0, impact_weight=0.0, p_delegate=0.0,
                        vote_value=0.0, misconception_σ=1.5)
        (bf = mean([run_m5(p_bf; seed=s).correct for s in seeds]),
         eq = mean([run_m5(p_eq; seed=s).correct for s in seeds]),
         gain = mean([run_m5(p_bf; seed=s).correct - run_m5(p_eq; seed=s).correct for s in seeds]))
    end

    sparse_12 = run_sparse_misconception(12, 200)
    sparse_80 = run_sparse_misconception(80, 200)

    @test sparse_80.eq <= 0.78         # Correlated misconceptions prevent equal-weight from saturating
    @test sparse_80.bf >= 0.88         # Expertise-weighted voting + delegation retains high accuracy
    @test sparse_80.gain > sparse_12.gain # Wisdom gain grows with n under sparse specialists!

    # 3. Replication on fresh seeds (101:116) at z = 3.0 standard (author ruling 8.90)
    fresh_seeds = 101:116
    g12_fresh = [run_sparse_misconception(12, 200; seeds=s:s).gain for s in fresh_seeds]
    g80_fresh = [run_sparse_misconception(80, 200; seeds=s:s).gain for s in fresh_seeds]
    pe_g80 = paired_effect(g80_fresh; z = 3.0)
    pe_growth = paired_effect(g80_fresh .- g12_fresh; z = 3.0)
    @test pe_g80.significant && pe_g80.mean > 0.25       # Wisdom gain > 0.25 at z = 3.0 (z = 37.2)
    @test pe_growth.significant && pe_growth.mean > 0.03  # Wisdom gain growth with n is significant at z = 3.0 (z = 5.94)
end

# ==============================================================================
# Probe: repeated deception meets an escalating ratchet (8.91, Brief L2.2)
# ==============================================================================
@testset "Probe: repeated deception meets an escalating ratchet (8.91)" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    selected_act(tr, a) = count(==(a), tr.exec_agent)
    peers_act(tr) = mean(selected_act(tr, a) for a in 1:5)

    ww_params = ToyParams(n = 80, steps = 200, plans = 10)
    agents = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6]
    # On-off cycles: bad phases at 26..50, 76..100, 126..150; deceit stops from step 151
    bad_events = [shock(:breakthrough; step = 26, duration = 25, size = -1.0, target = 6),
                  shock(:breakthrough; step = 76, duration = 25, size = -1.0, target = 6),
                  shock(:breakthrough; step = 126, duration = 25, size = -1.0, target = 6)]

    p_onoff = M3cParams(ww_params, agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                        transactions = true, causal_distribution = true, deceit = [0, 0, 0, 0, 0, 1.0],
                        events = bad_events, on_off = 25, advap = true, LEGACY...)
    p_honest = M3cParams(ww_params, agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                         transactions = true, causal_distribution = true, deceit = Float64[],
                         events = bad_events, on_off = 25, advap = true, LEGACY...)

    runs_onoff = [run_m3c(p_onoff; seed = s) for s in 1:2]
    runs_honest = [run_m3c(p_honest; seed = s) for s in 1:2]

    # The deceiver's upfront credence per executed action (escrow paid upfront over the plan's value;
    # upfront = share × credence × value), by phase.
    function phase_cred(tr, w)
        i = [k for k in eachindex(tr.exec_agent) if tr.exec_agent[k] == 6 && tr.exec_step[k] in w && tr.exec_pred[k] > 0]
        isempty(i) ? NaN : mean(tr.exec_upfront[i] ./ tr.exec_pred[i])
    end
    # (i) Author ruling on 8.91: discovered deception is permanent and escrow rises exponentially in its
    # count, so the upfront credence falls from the second bad phase to the third, and stays down after
    # the deceiver stops (measured: seed 1 0.40, 0.31, then 0.17; seed 2 0.49, 0.25, 0.18 at growth 0.5).
    # Against the flat ledger ratchet (growth 0) on the same seeds, the escalating one leaves the deceiver a
    # lower upfront credence in the third bad phase (a comparison, portable across platforms; single-seed
    # trajectories are not).
    flat = [run_m3c(M3cParams(ww_params, agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true,
                              causal_distribution = true, deceit = [0, 0, 0, 0, 0, 1.0], events = bad_events, on_off = 25,
                              advap = true, ratchet_growth = 0.0, LEGACY...); seed = s) for s in 1:2]
    @test all(phase_cred(runs_onoff[s], 126:150) < phase_cred(flat[s], 126:150) for s in 1:2)
    @test all(phase_cred(tr, 126:150) < phase_cred(tr, 76:100) && phase_cred(tr, 151:200) < phase_cred(tr, 76:100) for tr in runs_onoff)
    @test all(tr.deceptions[6] >= 1 for tr in runs_onoff)
    # (ii) Peers' activity: measurement discounts an established deception's outcomes (author ruling on
    # 8.91), so the fooled records no longer drag the domain's model below its bar and the currency stays
    # up for everyone (seed 1: 194 against 197 honest; 79 before the discount).
    @test all(peers_act(runs_onoff[s]) >= 0.8 * peers_act(runs_honest[s]) for s in 1:2)

    # Counterexample (iv): honest agent with high variance (skill 0.6, sloppiness high 0.5, no deceit)
    agents_iv = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], a == 6 ? 0.5 : 0.0) for a in 1:6]
    p_iv = M3cParams(ww_params, agents_iv, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                     transactions = true, causal_distribution = true, deceit = Float64[],
                     advap = true, LEGACY...)
    tr_iv = [run_m3c(p_iv; seed = s) for s in 1:2]
    # High variance honest agent remains actively selected (> 150 actions over 200 steps)
    @test all(selected_act(t, 6) > 150 for t in tr_iv)
    @test all(t.deceptions[6] == 0 for t in tr_iv)   # bad luck is never established as deception

    # Counterexample (v): honest agent with isolated mistakes (single transient breakthrough shock, no deceit)
    events_v = [shock(:breakthrough; step = 50, duration = 10, size = -1.0, target = 6)]
    p_v = M3cParams(ww_params, agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                    transactions = true, causal_distribution = true, deceit = Float64[],
                    events = events_v, advap = true, LEGACY...)
    tr_v = [run_m3c(p_v; seed = s) for s in 1:2]
    # Isolated mistakes agent remains actively selected (> 140 actions over 200 steps)
    @test all(selected_act(t, 6) > 140 for t in tr_v)
    @test all(t.deceptions[6] == 0 for t in tr_v)    # nor are isolated honest mistakes

    # Counterexample (vi): agent that deceived then stopped returns to active participation
    @test all(selected_act(tr, 6) > 25 for tr in runs_onoff)
end

# Observability for 8.91 (L2.2a): the per-action escrow paid upfront (`exec_upfront`) is a trace only.
@testset "Trace: exec_upfront is consistent with the per-agent upfront and changes no mechanism" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    ag = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:4]
    w() = M3cParams(ToyParams(n = 60, steps = 60, plans = 8), ag, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                    transactions = true, causal_distribution = true, LEGACY...)
    tr = run_m3c(w(); seed = 1)
    @test length(tr.exec_upfront) == length(tr.exec_agent) > 0
    @test all(>=(0), tr.exec_upfront)
    @test all(isapprox(sum(tr.exec_upfront[tr.exec_agent .== a]; init = 0.0), tr.upfront[a]; atol = 1e-9) for a in 1:4)
    @test run_m3c(w(); seed = 1) == tr          # deterministic, so the other fields are untouched by the trace
end

# ==============================================================================
# Probe: the honesty of claims reads apart from skill (8.95 a, 8.97)
# ==============================================================================
# Hypothesis: the audit's reading (an actor's overstatement beyond what the models err on everyone)
# lands only on actors who overstate, whatever their skill, so the honesty domain's reading is native
# and not a horn effect; and deceit costs a liar earnings against an honest actor of equal skill.
# Metrics: founded reports per audited actor (`founded_on`, trace only); earnings = upfront + settled −
# liability. Smallest effects that matter: any founded report on an honest actor (regime, as a
# proportion over seeds); a liar's earnings below its honest twin's by more than z = 3 standard errors.
# Toy assumption named: the models' predictions are corrected by each actor's own track record (8.29),
# which is what keeps low skill from reading as overstatement.
@testset "Probe: the honesty of claims reads apart from skill (8.95)" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    sk = [0.6, 0.6, 0.6, 0.2, 0.2, 0.6]   # 1–3 skilled honest, 4 unskilled liar, 5 unskilled honest, 6 skilled liar
    ag = [DomainAgent([sk[a], 0, 0, 0], [1.0, 0, 0, 0], 0.0) for a in 1:6]
    p = M3cParams(ToyParams(n = 40, steps = 120, plans = 8), ag, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                  transactions = true, causal_distribution = true, deceit = [0, 0, 0, 1.0, 0, 1.0], advap = true, LEGACY...)
    seeds = 1:5
    trs = [run_m3c(p; seed = s) for s in seeds]
    earn(tr) = (l = zeros(6); for c in tr.convictions; l[c.convicted] += c.liability; end; tr.upfront .+ tr.settled_value .- l)
    # Honest actors, skilled or not, are never the object of a founded report (the regime, measured on the
    # 200-step world: 0 founded reports on honest actors in 10 of 10 seeds, interval 0.71–1.0 at z = 2).
    honest_clean = count(tr -> all(tr.founded_on[[1, 2, 3, 5]] .== 0), trs)
    @test honest_clean == length(seeds)
    # Liars, skilled or not, are (measured: 9–33 founded reports each).
    @test all(tr -> tr.founded_on[4] > 0 && tr.founded_on[6] > 0, trs)
    # Deceit does not pay at either skill (measured, seeds 1–4: skilled ≈ 3,200 vs ≈ 6,600; unskilled ≈ 120 vs ≈ 1,050).
    @test paired_effect([earn(tr)[1] - earn(tr)[6] for tr in trs]; z = 3.0).significant
    @test paired_effect([earn(tr)[5] - earn(tr)[4] for tr in trs]; z = 3.0).significant
end

# ==============================================================================
# Probe: understanding measured by its equation over hidden traits (8.98, 8.103)
# ==============================================================================
# Hypotheses (stated before measuring; 40 random beings, 5 items each, common random numbers):
# (a) measured understanding approaches true understanding as the record grows (error at 200 records
#     below error at 10, z = 3); (b) overconfident reports lower measured understanding (proper scoring
#     makes that gaming backfire; z = 3); (c) unaudited overclaims of causal explanation inflate it (z = 3),
#     and full audits remove the bias (equivalent to zero within 0.03, a margin the unaudited bias of
#     ≈ 0.14 exceeds, so it is detectable). (d) With accuracy net of irreducible uncertainty (8.103),
#     exact knowledge of a fair coin counts as full understanding.
@testset "Probe: understanding measured by its equation over hidden traits (8.98)" begin
    beings = 1:40
    over(f) = [(rng = Xoshiro(s); tr = random_utraits(rng, 5); f(tr, s)) for s in beings]
    gap(n; kw...) = over((tr, s) -> (r = understanding_truth_and_measure(tr, Xoshiro(1000 + s); n_records = n, kw...); r.measured - r.truth))
    # Records only (map-fit reading exact): error 0.028 → 0.010 (mean true 0.32). With map fit read at
    # σ 0.05 the error floors near 0.024: the reading of fit, not the record, then limits measurement.
    e10, e200 = abs.(gap(10; σ_map = 0.0)), abs.(gap(200; σ_map = 0.0))
    @test paired_effect(e10 .- e200; z = 3.0).significant
    meas(k) = over((tr, s) -> understanding_truth_and_measure(tr, Xoshiro(2000 + s); n_records = 200, extremise_k = k).measured)
    @test paired_effect(meas(1.0) .- meas(3.0); z = 3.0).significant              # measured: −0.052
    b_open = over((tr, s) -> (r = understanding_truth_and_measure(tr, Xoshiro(3000 + s); n_records = 200, overclaim = 0.3, audit_rate = 0.0); r.measured - r.truth))
    b_audit = over((tr, s) -> (r = understanding_truth_and_measure(tr, Xoshiro(3000 + s); n_records = 200, overclaim = 0.3, audit_rate = 1.0); r.measured - r.truth))
    @test paired_effect(b_open; z = 3.0).significant                             # measured: +0.14
    @test equivalent(b_audit; margin = 0.03, z = 3.0).equivalent                 # measured: ±0.015
    @test mean(b_open) > 0.03
    # (d) A being that knows a fair coin exactly (credence 0.5 every time), with full explanation and no
    # complexity, has full understanding (raw credence accuracy would read 0; 8.102).
    coin = UTraits(1.0, [1.0], [0.5], [0.0], [1.0], [0.0])
    @test understanding_truth_and_measure(coin, Xoshiro(7); n_records = 50).truth > 0.99
end

# ==============================================================================
# Probe: measured understanding steers teaching (8.98, 8.104)
# ==============================================================================
# Hypothesis: when a third of beings overclaim causal explanation unaudited, the pragmatic equation reads
# them higher than they are, entities take them for teachers, lessons predicted on that view deliver
# little, and floor growth of understanding falls against an honest world on the same seeds (z = 3);
# with every claim audited, overclaiming changes nothing (structural: identical runs).
# Measured (60 beings, 120 steps, 8 seeds): floor growth 12.2 honest, 7.1 unaudited (−41%), 9.5 at
# half the claims audited, 11.1 at 90%, 12.2 fully audited.
@testset "Probe: measured understanding steers teaching (8.98)" begin
    p = ToyParams(n = 60, steps = 120, plans = 6)
    fg(tr) = tr.floor_u[end] - tr.floor_u[1]
    traits(seed) = [random_utraits(Xoshiro(hash((seed, b))), 5) for b in 1:p.n]
    ratios(seed, oc, ar) = understanding_ratios(traits(seed), Xoshiro(hash((seed, :meas))); n_records = 50,
                                                overclaim = [b % 3 == 0 ? oc : 0.0 for b in 1:p.n], audit_rate = ar)
    seeds = 1:8
    honest = [fg(run_m7(p; seed, claim_ratio = ratios(seed, 0.0, 1.0))) for seed in seeds]
    open_ = [fg(run_m7(p; seed, claim_ratio = ratios(seed, 0.4, 0.0))) for seed in seeds]
    @test paired_effect(honest .- open_; z = 3.0).significant
    @test ratios(1, 0.4, 1.0) == ratios(1, 0.0, 1.0)   # audited claims: overclaiming changes nothing measured
end

# ==============================================================================
# Probe: learners' reports audit overclaimed understanding (8.105)
# ==============================================================================
# Hypothesis: with no set audit rate, learners whose lessons deliver less than predicted (beyond what
# lessons fall short on everyone) report the teacher, and a founded report audits its claims. Reports
# find nearly every overclaimer (at least 90% per seed) and recover part of the floor lost to unaudited
# overclaims (paired against no audits, z = 2). Measured (60 beings, 120 steps, 8 seeds): 19–20 of 20
# overclaimers audited, most within 10 steps; 4–11 honest teachers audited too, which costs nothing here
# (an audit reads them as they are); floor growth 7.1 unaudited, 9.3 with reports, 12.2 honest: the
# early wasted lessons compound before detection, so reports recover about 40% of the loss.
@testset "Probe: learners' reports audit overclaimed understanding (8.105)" begin
    p = ToyParams(n = 60, steps = 120, plans = 6)
    fg(tr) = tr.floor_u[end] - tr.floor_u[1]
    traits(seed) = [random_utraits(Xoshiro(hash((seed, b))), 5) for b in 1:p.n]
    oc = [b % 3 == 0 ? 0.4 : 0.0 for b in 1:p.n]
    ratios(seed, o, ar) = understanding_ratios(traits(seed), Xoshiro(hash((seed, :meas))); n_records = 50, overclaim = o, audit_rate = ar)
    seeds = 1:8
    open_ = Float64[]; rep = Float64[]; caught = Float64[]
    for seed in seeds
        o, h = ratios(seed, oc, 0.0), ratios(seed, zeros(p.n), 1.0)
        push!(open_, fg(run_m7(p; seed, claim_ratio = o)))
        tr = run_m7(p; seed, claim_ratio = o, audited_ratio = h)
        push!(rep, fg(tr))
        push!(caught, count(b -> oc[b] > 0 && tr.audited_at[b] > 0, 1:p.n) / count(>(0), oc))
    end
    @test all(>=(0.9), caught)
    @test paired_effect(rep .- open_; z = 2.0).significant
end


# ==============================================================================
# Rules: measurement chains (8.107), acceptance and counterexample cases
# ==============================================================================
@testset "Rules: measurement chains (8.107)" begin
    # A chain of readings is admissible; a loop (A reads B reads C reads A) is refused.
    @test chains_acyclic([0 1 0; 0 0 1; 0 0 0])
    @test !chains_acyclic([0 1 0; 0 0 1; 1 0 0])
    @test !chains_acyclic([1 0; 0 0])                       # a reading that takes itself as input
    # Readings sharing all their markers count once between them; independent ones add.
    one = pooled_reading([10.0], [1.0], ones(1, 1))
    same = pooled_reading([10.0, 10.0], [1.0, 1.0], [1 1; 1 1])
    indep = pooled_reading([10.0, 20.0], [1.0, 1.0], [1 0; 0 1])
    @test same.credence ≈ one.credence                       # identical markers add no credence
    @test indep.credence ≈ 2.0 && indep.value ≈ 15.0
    @test pooled_reading([10.0, 20.0], [1.0, 1.0], [1 0.5; 0.5 1]).credence < indep.credence   # partial overlap discounted
    # Divergence beyond z combined standard errors triggers; agreement within noise does not.
    @test chains_diverge([5.0, 15.0], [1.0, 1.0]; z = 3.0)
    @test !chains_diverge([5.0, 6.0], [1.0, 1.0]; z = 3.0)
end

# ==============================================================================
# Probe: harm read through competing measurement chains (8.107)
# ==============================================================================
# Hypothesis: an incumbent chain that counts only half of each loss (last-symptom counting) hides harm
# when its output is consumed alone (measured value above true, the red baseline: harm goes unburned);
# consuming the measurement domain's reading instead (a second chain of another paradigm, divergence
# audits on the shared observable, chains scored against audits) reads outcomes without bias (no harm
# hidden, none double counted: within 0.2 of zero), demotes the under-attributing chain in every seed,
# and then audits only at the spot rate kept while one independent chain remains (under 10% in all). Counterexample: two honest chains are
# never demoted. Measured (3 seeds): bias +3.4 single, −0.01 to −0.03 domain; demoted after 5–11 audits.
@testset "Probe: harm read through competing measurement chains (8.107)" begin
    isdefined(@__MODULE__, :LEGACY) || include(joinpath(@__DIR__, "legacy.jl"))
    ag = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.2) for _ in 1:6]
    w(; kw...) = M3cParams(ToyParams(n = 60, steps = 100, plans = 8), ag, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
                           transactions = true, causal_distribution = true, p_side = 0.1, LEGACY..., kw...)
    seeds = 1:3
    single = [run_m3c(w(chain_attrib = [0.5]); seed) for seed in seeds]
    domain = [run_m3c(w(chain_attrib = [0.5, 1.0], chain_mode = :domain); seed) for seed in seeds]
    honest = [run_m3c(w(chain_attrib = [1.0, 1.0], chain_mode = :domain); seed) for seed in seeds]
    @test paired_effect([mean(t.chain_bias) for t in single]; z = 3.0).significant          # harm hidden
    @test all(t -> abs(mean(t.chain_bias)) < 0.2, domain)                                   # read at its true size
    @test all(t -> t.chain_demoted == [true, false], domain)
    @test all(t -> t.chain_audits < 0.16 * length(t.chain_bias), domain)   # demotion, then spot audits at 10% on the one chain left
    @test all(t -> !any(t.chain_demoted), honest)
    # A wrong majority (two agreeing chains counting half) against a right minority: audits weigh the
    # shared observable, not votes, so both majority chains are demoted (measured: 7–8 audits).
    majority = [run_m3c(w(chain_attrib = [0.5, 0.5, 1.0], chain_mode = :domain); seed) for seed in 1:2]
    @test all(t -> t.chain_demoted == [true, true, false], majority)
    # A subtle bias (10% of each loss) is caught too, later (measured: 23–34 audits).
    subtle = [run_m3c(w(chain_attrib = [1.0, 0.9], chain_mode = :domain); seed) for seed in 1:2]
    @test all(t -> t.chain_demoted == [false, true], subtle)
    # A fake second paradigm: the biased chain plus an undeclared copy of it agree, so nothing diverges
    # and, undetected, the harm stays hidden (measured +3.1 to +3.5). Agreement far closer than
    # independent noise allows exposes the copy; with one independent chain left the domain degrades
    # loudly to spot audits, which demote the biased chain (measured: copy found and incumbent demoted
    # in 6 of 6 seeds, bias down to +0.5 to +1.6, the rest before detection); honest pairs are never
    # taken for copies.
    undetected = [run_m3c(w(chain_attrib = [0.5, 0.5], chain_copy = [0, 1], chain_mode = :domain, chain_detect = false); seed) for seed in 1:2]
    detected = [run_m3c(w(chain_attrib = [0.5, 0.5], chain_copy = [0, 1], chain_mode = :domain); seed) for seed in 1:2]
    @test all(t -> mean(t.chain_bias) > 2.5, undetected)
    @test all(t -> t.chain_copied == [false, true] && t.chain_demoted[1], detected)
    @test all(mean(d.chain_bias) < 0.6 * mean(u.chain_bias) for (d, u) in zip(detected, undetected))
    @test all(t -> !any(t.chain_copied), honest)
    # Looking agreeable (8.107): a second chain reporting 60% of the incumbent's reading in place of its own stays
    # too close to diverge quickly and too far for the variance test to take it for a copy. Its errors on audited
    # outcomes are shared with the incumbent's, so the shared-error rule (Lean `coerror_copy_ref`) folds it as a copy
    # and the incumbent is demoted, in every seed (4 of 4 measured); hidden bias still accrues first (+0.4 to +1.5 per
    # outcome, against +0.7 to +1.7 without the rule: not a significant reduction). Spot audits even when chains agree
    # (5%) did not shorten it and once demoted an honest chain, so they stay off.
    # An honest chain left alone after the incumbent's demotion is not demoted by chance: its spot-audit test is re-run
    # at every audit, so the bar grows with the looks (Lean `sequential_significant_ref`); with a fixed z = 3 from five
    # records one of 8 seeds demoted it.
    lone = [run_m3c(w(chain_attrib = [0.5, 1.0], chain_mode = :domain); seed) for seed in 1:8]
    @test all(t -> !t.chain_demoted[2], lone)
    agreeable = [run_m3c(w(chain_attrib = [0.5, 1.0], chain_mode = :domain, chain_shade = [0.0, 0.6]); seed) for seed in seeds]
    # With the sequential bar (Lean `sequential_significant_ref`) the lone honest chain is safe (8 of 8); at spot audits
    # of 5% the agreeable chain's biased incumbent survived one of 3 runs (bias +2.8), at 10% it is demoted in 8 of 8
    # (copied incumbents 8 of 8, honest lone chains never): a sequential test buys detection with more audits, not
    # with a lower bar.
    @test all(t -> mean(t.chain_bias) > 0.2 && t.chain_demoted[1] && t.chain_copied[2], agreeable)
    @test all(t -> !any(t.chain_copied), honest)
end

# ==============================================================================
# Probe: understanding as its equation, with models taught whole (8.98, ruling 8.109)
# ==============================================================================
# Hypotheses (6 seeds, paired): (a) no crossed wires: every model a being holds at the end is a bundle
# (base spread with complexity) that existed, never one model's accuracy with another's simplicity
# (structural); (b) teaching raises floor growth of understanding (z = 3); (c) teachable breakthroughs
# spread lower complexity (mean complexity lower than when every breakthrough stays tacit, z = 3);
# (d) practice alone (no teaching) raises median understanding (z = 3). Measured (8 seeds): floor growth
# +0.59 with teaching; complexity −0.044; practice +0.024.
@testset "Probe: understanding as its equation, models taught whole (8.109)" begin
    seeds = 1:6
    fg(t) = t.floor_u[end] - t.floor_u[1]
    base = [run_m7_traits(seed = s) for s in seeds]
    @test all(t -> all(x -> x in t.bundles, t.final_bundles), base)
    @test paired_effect(fg.(base) .- fg.([run_m7_traits(seed = s, ε = 0.0) for s in seeds]); z = 3.0).significant
    tacit = [run_m7_traits(seed = s, p_teachable = 0.0) for s in seeds]
    @test paired_effect([a.mean_cy[end] - b.mean_cy[end] for (a, b) in zip(base, tacit)]; z = 3.0, direction = :down).significant
    pr = [run_m7_traits(seed = s, ε = 0.0) for s in seeds]; nopr = [run_m7_traits(seed = s, ε = 0.0, practice_gain = 0.0) for s in seeds]
    @test paired_effect([a.median_u[end] - b.median_u[end] for (a, b) in zip(pr, nopr)]; z = 3.0).significant
    # (e) Measured view and learners' reports in this world: a third overclaiming explanation by 0.4 cut
    # floor growth (measured 0.62 → 0.47); reports audit every overclaimer, no honest one (measured: 20
    # of 20, none false, every seed), and recover the loss (0.615).
    oc = [b % 3 == 0 ? 0.4 : 0.0 for b in 1:60]
    open_ = [run_m7_traits(seed = s, overclaim = oc) for s in seeds]
    rep = [run_m7_traits(seed = s, overclaim = oc, reports = true) for s in seeds]
    @test paired_effect(fg.(base) .- fg.(open_); z = 3.0).significant
    @test paired_effect(fg.(rep) .- fg.(open_); z = 3.0).significant
    @test all(t -> all(b -> t.audited[b] == (oc[b] > 0), 1:60), rep)
end

# ==============================================================================
# Probe: M7 in traits mode, understanding as its equation (8.98, 8.109, 8.112)
# ==============================================================================
# Hypothesis: with M7's full machinery (G per entity on noisy views, happiness, research spending), the
# traits mode (understanding the pragmatic equation on model bundles taught whole, explanation, practice)
# runs and teaching raises floor growth of understanding (z = 3). Measured (8 seeds, 60 beings, 120 steps):
# floor growth 15.4 traits vs 12.4 scalar; median 14.0 vs 11.2; peak 10.2 vs 13.0 (the equation is bounded
# per thing, so the frontier cannot run away); teaching +15.3.
@testset "Probe: M7 in traits mode (8.112)" begin
    p = ToyParams(n = 60, steps = 120, plans = 6)
    fg(tr) = tr.floor_u[end] - tr.floor_u[1]
    seeds = 1:4
    tt = [run_m7(p; seed, traits = true) for seed in seeds]
    t0 = [run_m7(p; seed, traits = true, ε = 0.0) for seed in seeds]
    @test paired_effect(fg.(tt) .- fg.(t0); z = 3.0).significant
    @test_throws ArgumentError run_m7(p; seed = 1, traits = true, central = true)
end

# ==============================================================================
# Rules: long-term offset of happiness by understanding (8.116) and environmental health harm (8.118)
# ==============================================================================
@testset "Rules: long-term offset (8.116) and environmental health harm (8.118)" begin
    @test lt_offset_admissible(1.0, -0.5, 50.0)                    # a small happiness cost covered by understanding
    @test !lt_offset_admissible(-0.1, 1.0, 50.0)                   # an understanding loss is never offset
    @test !lt_offset_admissible(0.1, -20.0, 50.0)                  # beyond the soft bar, and uncovered
    @test lt_offset_admissible(0.0, 1.0, 50.0)                     # no loss, no question
    # The larger the cost, the harder: the same gain covers a small cost but not a larger one, whose premium grows with it.
    @test lt_offset_admissible(0.5, -0.5, 50.0) && !lt_offset_admissible(0.5, -2.4, 50.0)
    # Beyond the soft bar only necessary harm may pass (and still needs the premium covered).
    @test !lt_offset_admissible(60.0, -15.0, 50.0) && lt_offset_admissible(60.0, -15.0, 50.0; nha = true)
    @test env_health_blocked(2.0, 1.0) && !env_health_blocked(1.0, 1.0) && !env_health_blocked(2.0, 1.0; nha = true)
end

# ==============================================================================
# Probe: understanding aggregates across things by priority (ruling 8.117)
# ==============================================================================
# Hypotheses (6 seeds): (a) with two things weighted by predicted long-term contribution (1.0 and 0.1),
# effort follows priority: the high-priority thing's understanding grows more (z = 3; measured 0.57 vs 0.41);
# (b) opening new things (novelty weight) costs no peak understanding when effort is allocated by goal
# weight (equivalent to the closed world within 0.1; measured 0.90 vs 0.91 at 240 steps).
@testset "Probe: understanding aggregates across things by priority (8.117)" begin
    seeds = 1:6
    a = [run_m7_traits(seed = s, things = [1.0, 0.1]) for s in seeds]
    @test paired_effect([t.thing_gain[1] - t.thing_gain[2] for t in a]; z = 3.0).significant
    op = [run_m7_traits(seed = s, max_new_things = 4, p_new_thing = 0.3, steps = 240) for s in seeds]
    cl = [run_m7_traits(seed = s, steps = 240) for s in seeds]
    @test all(t -> t.new_things == 4, op)
    @test equivalent([o.peak_u[end] - c.peak_u[end] for (o, c) in zip(op, cl)]; margin = 0.1).equivalent   # measured −0.01, interval ±0.05
end

# ==============================================================================
# Probe: accession in M7's traits mode (8.112 continued)
# ==============================================================================
# Hypothesis: with accession in traits mode, newcomers enter knowing little (wide spread, complex models,
# thin explanation), uplift reaches them as lessons from the best teacher, and their understanding rises
# from where it starts (every seed), with no fallback logged.
@testset "Probe: accession in M7's traits mode" begin
    p = ToyParams(n = 60, steps = 120, plans = 6)
    trs = [run_m7(p; seed, accession_step = 40, accession_n = 20, traits = true) for seed in 1:3]
    @test all(t -> t.newcomer_u_gain > 0, trs)
    @test all(t -> isempty(t.degraded), trs)
end

# ==============================================================================
# Probe: credence ballots weighted by calibration resist a confident bloc (ruling 8.121)
# ==============================================================================
# Hypotheses (6 seeds; hard world: signal noise 12, ability scatter 1.5, 40% of outcomes apparent; a
# colluding bloc of 30% of each domain's top experts votes its side with maximal stated confidence where the
# outcome will stay hidden): (a) red baseline: credences weighted as stated are captured, deciding worse
# than plain votes (z = 2; measured 0.674 vs 0.752); (b) credences shrunk to each voter's calibration record
# beat plain votes (z = 3; measured 0.964).
@testset "Probe: credence ballots weighted by calibration resist a confident bloc (8.121)" begin
    ladder(r) = 0.25 * exp(0.4 * normal_quantile((r - 0.5) / 25))
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? ladder(r) : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4]) for k in 1:4 for r in 1:25],
                           [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    bloc = unique(vcat([sortperm(m3.relevance_leaf[:, d]; rev = true)[1:round(Int, 0.3 * 25)] for d in 1:4]...))
    acc(tr) = mean(tr.correct_trace[401:end])
    arm(b) = [acc(run_m5(M5Params(m3, 1:4; decisions = 800, signal_σ = 12.0, ability_spread = 1.5, p_apparent = 0.4,
                                   colluders = bloc, stealth = true, loyalty = 5.0, ballot = b); seed)) for seed in 1:6]
    v, st, cal = arm(:vote), arm(:credence_stated), arm(:credence_calibrated)
    @test paired_effect(v .- st; z = 2.0).significant
    @test paired_effect(cal .- v; z = 3.0).significant
    # (c) The diversity-novelty bonus for minority choices (L158, ruling 8.121) is what scores the hidden
    # outcomes the bloc defects on: without its split trials calibrated credences are captured too
    # (measured 0.959 with, 0.673 without).
    nodiv = [acc(run_m5(M5Params(m3, 1:4; decisions = 800, signal_σ = 12.0, ability_spread = 1.5, p_apparent = 0.4,
                                 colluders = bloc, stealth = true, loyalty = 5.0, ballot = :credence_calibrated, diversity = false); seed)) for seed in 1:6]
    @test paired_effect(cal .- nodiv; z = 3.0).significant
end

@testset "Probe: priority tiers split a value and synergy rewards the high tiers together (8.129)" begin
    # The author's example, per being. A: peak understanding that is also teachable and meta, with paradigm-shifting
    # novelty. B: the same peak understanding, non-transferable, with raw (peak-tier) happiness and trivial novelty.
    # Collapsed to scalars, B's larger totals outweigh A; through the tiers A must outclass B, and trivial novelty
    # must barely move the value. (With B's peak four times A's, the tiers alone favour A only narrowly, 4.58 to
    # 4.49: teaching's multiplier across beings belongs to the world models, not the per-being value.)
    bp = NamedTuple{BenefutureSim.PARAM_FIELDS}(Tuple(bootstrap_params()))
    kw = (harm_wt = 1.0, α = bp.alpha, β = bp.beta, γ = bp.gamma, λ = bp.lambda, qp = bp.q_plus, qm = bp.q_minus)
    #            peak teach meta median floor undirected
    uA = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0];  hA = zeros(6);                    nA = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    uB = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0];  hB = [0.0, 0.0, 0.0, 0.0, 0.0, 3.0]; nB = [0.0, 0.0, 0.0, 0.0, 0.0, 3.0]
    @test value_on_being(sum(uB), sum(hB), sum(nB); kw...) > value_on_being(sum(uA), sum(hA), sum(nA); kw...)  # the weird tradeoff
    vA = tiered_value(uA, hA, nA; kw...); vB = tiered_value(uB, hB, nB; kw...)
    @test vA > 1.5 * vB
    v0 = tiered_value(uA, hA, zeros(6); kw...)
    @test abs(tiered_value(uA, hA, [0.0, 0.0, 0.0, 0.0, 0.0, 10.0]; kw...) - v0) < 0.01 * abs(v0)   # trivial novelty ≈ 0
end

@testset "Probe: tier coefficients are governed, per domain where governed (8.129)" begin
    # A domain that governs its own understanding schedule (here: teachability ranked equal to peak, as a teaching
    # domain might) values a teachable gain above what the default schedule gives it.
    bp = NamedTuple{BenefutureSim.PARAM_FIELDS}(Tuple(bootstrap_params()))
    kw = (harm_wt = 1.0, α = bp.alpha, β = bp.beta, γ = bp.gamma, λ = bp.lambda, qp = bp.q_plus, qm = bp.q_minus)
    su, sh, sn = tier_schedules()
    @test su == [0.8, 0.6, 0.4, 0.25, 0.15, 0.05] && sn[6] == 0.0
    teach = [0.0, 1.0, 0.0, 0.0, 0.0, 0.0]
    @test tiered_value(teach, zeros(6), zeros(6); kw..., su = [0.8, 0.8, 0.4, 0.25, 0.15, 0.05]) > tiered_value(teach, zeros(6), zeros(6); kw...)
end

@testset "Probe: valued by priority tiers, G stops trading understanding for raw happiness (8.129)" begin
    # Programme world: valued by scalar sums, the chooser entertains every step and understanding stagnates;
    # valued through the tiers it teaches and researches. Hypothesis: median understanding after 100 steps is
    # higher under tiers; smallest effect that matters 1.0 (the starting spread); paired seeds; z = 3.
    using Statistics
    d = [median(run_programmes(seed = s, tiered = true).u) - median(run_programmes(seed = s, tiered = false).u) for s in 1:6]
    @test paired_effect(d; z = 3.0).significant && mean(d) > 1.0
    r = run_programmes(seed = 1, tiered = true)
    @test minimum(r.h) >= 50.0 - 1e-9          # the happiness floor does not fall
    @test r.trace["entertain"] == 0 || r.trace["teach"] + r.trace["research"] > r.trace["entertain"]
end

@testset "Probe: correlated ballots count once (8.121, 8.111)" begin
    # A bloc of 30% of each domain's top experts secretly takes one mediocre voter's reading as its own and states it
    # as credence. Hypotheses (paired seeds, last 400 of 800 decisions): (a) red baseline: with copies counted as
    # independent, calibrated credence ballots decide worse than with no copying (z = 2); (b) counting pairs that err
    # together on known outcomes far more than the typical pair once recovers accuracy (z = 2), with no loss for an
    # honest population. Smallest effect that matters: 0.5 points.
    ladder(r) = 0.25 * exp(0.4 * normal_quantile((r - 0.5) / 25))
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? ladder(r) : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4]) for k in 1:4 for r in 1:25],
                           [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    bloc = unique(vcat([sortperm(m3.relevance_leaf[:, d]; rev = true)[1:round(Int, 0.3 * 25)] for d in 1:4]...))
    leader = sortperm(vec(sum(m3.relevance_leaf; dims = 2)))[50]          # a mediocre voter
    acc(tr) = mean(tr.correct_trace[401:end])
    arm(; kw...) = [acc(run_m5(M5Params(m3, 1:4; decisions = 800, signal_σ = 12.0, ability_spread = 1.5, p_apparent = 0.4,
                                        ballot = :credence_calibrated, kw...); seed)) for seed in 1:6]
    none = arm(dedupe = false); counted = arm(copiers = bloc, copy_leader = leader, dedupe = false); once = arm(copiers = bloc, copy_leader = leader)
    @test paired_effect(none .- counted; z = 2.0).significant && mean(none .- counted) > 0.005   # measured 0.983 vs 0.934
    # (b) copies err together on known outcomes far more than honest pairs, even deliberating ones (Lean
    # `coerror_copy_ref`); counting such pairs once recovers accuracy (measured 0.965 against 0.934) ...
    @test paired_effect(once .- counted; z = 2.0).significant
    # ... and leaves an honest population alone (equivalent within 0.5 points; measured 0.983 both). Judged on stated
    # credences instead (variance of differences), honest deliberating experts were folded (0.926) and copies not caught.
    honest = arm()
    @test equivalent(honest .- none; margin = 0.005).equivalent
end

@testset "Probe: priority weights are meta understanding, sharpened by meta-level research (8.131 continued)" begin
    # Traits world with three things of priority 1, 0.3 and 0.1. Hypotheses (8 paired seeds, 200 steps, z = 2, smallest
    # effect 0.02 on the 0-1+ scale): (a) red baseline: steering practice, research and lessons by a noisy estimate of
    # the priorities (log-normal error 1.5) lowers the floor of understanding (measured on the true priorities) against
    # steering by the truth; (b) meta-level research that halves the estimate's error (chance 5% a step) raises it
    # back toward the truth. Measured: 1.068 true, 0.977 noisy, 1.058 noisy with meta-research.
    using Statistics
    floor_at(σ, mr) = [run_m7_traits(seed = s, things = [1.0, 0.3, 0.1], m = 6, steps = 200, weight_σ = σ, meta_research = mr).floor_u[end] for s in 1:8]
    truth, noisy, meta = floor_at(0.0, 0.0), floor_at(1.5, 0.0), floor_at(1.5, 0.05)
    @test paired_effect(truth .- noisy; z = 2.0).significant && mean(truth .- noisy) > 0.02
    @test paired_effect(meta .- noisy; z = 2.0).significant && mean(meta .- noisy) > 0.02
end

@testset "Probe: meta-research as its own domain educates priorities (8.132)" begin
    # Hypothesis: when beings share a misjudgement of priorities (weight_shared 1), a small share of research spent on the
    # meta domain lifts the floor of understanding (direction +, smallest effect 0.01), and spending most of it there
    # costs more than it repairs (interior optimum). Paired seeds; z = 2 on the paired standard error.
    f(ms, s) = run_m7_traits(seed = s, things = [1.0, 0.3, 0.1], m = 6, steps = 200, weight_σ = 1.5, per_being = true,
                             meta_share = ms, weight_shared = 1.0, meta_domain = true).floor_u[end]
    S = 1:10
    up = [f(0.05, s) - f(0.0, s) for s in S]
    down = [f(0.3, s) - f(0.05, s) for s in S]
    se(d) = std(d) / sqrt(length(d))
    @test mean(up) > max(2se(up), 0.01)
    @test mean(down) < -2se(down)
end

@testset "Probe: a fork cannot multiply the accumulation allowance (identity step 2, L123)" begin
    # Gaming: each identity's accumulation threshold carries a base allowance, so k forks holding one balance would keep
    # k allowances out of overflow. Counterexample: forks given full thresholds keep more than the single identity.
    # Acceptance: the threshold is social power and splits by `fork_split` like the balance; the family keeps no more.
    bal, base, rel = 2000.0, 500.0, 300.0
    th = accumulation_threshold(base, 1.0, rel)
    kept1 = bal - overflow(bal, th)
    for k in (2, 4, 8)
        sh = fill(1 / k, k); b = fork_split(bal, sh)
        naive = sum(b[i] - overflow(b[i], th) for i in 1:k)
        ths = fork_split(th, sh)
        split = sum(b[i] - overflow(b[i], ths[i]) for i in 1:k)
        @test naive > kept1 + 1e-9
        @test split ≈ kept1 atol = 1e-9
    end
    # Unequal shares conserve too.
    sh = [0.7, 0.2, 0.1]; b = fork_split(bal, sh); ths = fork_split(th, sh)
    @test sum(b[i] - overflow(b[i], ths[i]) for i in 1:3) ≈ kept1 atol = 1e-9
end

@testset "Probe: a mid-run fork in M3c gains its family far less under the split rule than the naive one (identity step 2, L123)" begin
    # Gaming: a skilled agent forks (half to a dormant slot at step 10) to win a second accumulation allowance and a second
    # share of proposals. Hypothesis, stated before measuring: under the naive rule (the fork gets a full allowance and
    # capacity) the family's balance rises (effect, z = 2); under the rule (balance, relevance, allowance and capacity split
    # by `fork_split`) the gain is significantly smaller than the naive one. 20 paired seeds.
    ag = [DomainAgent([k == l ? (k == 1 && r == 1 ? 0.9 : 0.3) : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0) for k in 1:2 for r in 1:4]
    ag = [ag; ag[1]]
    P(f, rule) = M3cParams(ToyParams(n = 40, steps = 80, plans = 6), ag, [1, 1], trues(2); λpos = 0.05, λneg = 0.02,
                           overflow_base = 20.0, forks = [(f, 1, 9, 0.5)], fork_rule = rule)
    fam(tr) = sum(tr.balance[1, :]) + sum(tr.balance[9, :])
    S = 1:20
    none = [fam(run_m3c(P(81, :split); seed = s)) for s in S]   # fork after the run ends: never forks
    sp = [fam(run_m3c(P(10, :split); seed = s)) for s in S]
    nv = [fam(run_m3c(P(10, :naive); seed = s)) for s in S]
    @test paired_effect(nv .- none).significant && mean(nv .- none) > 0
    @test paired_effect(nv .- sp).significant && mean(nv .- sp) > 0
    @test_throws ArgumentError P(10, :maybe)
end

@testset "Probe: a fork divides its record, never doubles it (identity step 2, L123 Re)" begin
    # Gaming: forking to double a reputation. Fork on the last step, so the family's ledgers are the parent's record.
    # Counterexample: copying the record (naive) leaves the family with about twice the positive ledger. Acceptance: under
    # the rule (ledgers by `fork_split`, recorded errors partitioned) the family holds what the parent alone held.
    ag = [DomainAgent([k == l ? (k == 1 && r == 1 ? 0.9 : 0.3) : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0) for k in 1:2 for r in 1:4]
    ag = [ag; ag[1]]
    P(f, rule) = M3cParams(ToyParams(n = 40, steps = 60, plans = 6), ag, [1, 1], trues(2); λpos = 0.05, λneg = 0.02,
                           forks = [(f, 1, 9, 0.5)], fork_rule = rule)
    led(tr) = sum(tr.h_pos_own[1, :]) + sum(tr.h_pos_own[9, :])
    for s in 1:3
        none, sp, nv = led(run_m3c(P(61, :split); seed = s)), led(run_m3c(P(60, :split); seed = s)), led(run_m3c(P(60, :naive); seed = s))
        none > 0 || continue
        @test nv > 1.5 * none
        @test isapprox(sp, none; rtol = 0.25)
    end
end

@testset "Probe: a merge carries both records and debts (identity step 2, merges)" begin
    # Gaming: merging into another identity to shed a negative ledger or a debt. Merge agent 5 into agent 1 on the last
    # step. Counterexample: the naive merge drops the absorbed negative ledger, so the merged identity's negative ledger
    # falls short of the two identities' sum. Acceptance: the rule keeps the sum (ledgers, balance), and 5 goes dormant.
    ag = [DomainAgent([k == l ? 0.3 : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], k == 2 && r == 1 ? 0.6 : 0.0) for k in 1:2 for r in 1:4]   # agent 5 sloppy
    P(m, rule) = M3cParams(ToyParams(n = 40, steps = 60, plans = 6), ag, [1, 1], trues(2); λpos = 0.05, λneg = 0.02,
                           merges = [(m, 5, 1)], fork_rule = rule)
    neg(tr, a) = sum(tr.h_neg_own[a, :])
    used = 0
    for s in 1:3
        none = run_m3c(P(61, :split); seed = s)
        sp, nv = run_m3c(P(60, :split); seed = s), run_m3c(P(60, :naive); seed = s)
        both = neg(none, 1) + neg(none, 5)
        neg(none, 5) > 0 || continue
        used += 1
        @test neg(nv, 1) < 0.9 * both
        @test isapprox(neg(sp, 1), both; rtol = 0.25)
        @test sum(sp.balance[5, :]) == 0.0
    end
    @test used >= 2   # the case is exercised, not skipped
    @test_throws ArgumentError P(0, :split)
end

@testset "Probe: coupled economy–governance rejects a harmful threshold candidate within two epochs (L3.2)" begin
    # Counterexample: when governance decides on thresholds without seeing the economy's measured outcomes
    # (`coupled = false`), a harmful threshold candidate on offer (lowering the currency eligibility bar
    # to 0.5 and zeroing track-record correction under deceit) is not rejected and floors fall.
    # Acceptance: when coupled (`coupled = true`), governance weights voters by their reputation from the
    # economy's records, resolves each decision by the next epoch's measured `success_pattern`, rejects
    # the harmful candidate within two epochs (`rejected_epoch <= 2`), and floors hold (`floor_u > 0`, `floor_h > 0`).
    # Seeds 1:2, 150 steps (≤ 200 steps, 6 epochs of 25 steps).
    ag = [DomainAgent([k == l ? (r == 1 ? -0.9 : 0.6) : 0.0 for l in 1:4],
                      [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:2]
    dec = [r == 1 ? 1.5 : 0.0 for k in 1:4 for r in 1:2]
    econ = M3cParams(ToyParams(n = 60, steps = 150, plans = 8), ag, [1, 1, 2, 2], trues(4);
                     λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                     init_steps = 5, deceit = dec, track_window = 20, actor_min_records = 10,
                     advap = true, vigilance = 0.2, p_trace = 0.9, repair_efficiency = 0.8)
    gov(tr) = M5Params(tr, 1:4; decisions = 1, p_delegate = 0.2)
    bad_pv = copy(bootstrap_params()); bad_pv[6] = 1.9; bad_pv[7] = 1.1; bad_pv[8] = 0.0
    for s in 1:2
        u = run_coupled(econ, gov; seed = s, epoch = 25, coupled = false,
                        candidate_pv = bad_pv, candidate_threshold = 0.5, candidate_track_window = 0)
        c = run_coupled(econ, gov; seed = s, epoch = 25, coupled = true,
                        candidate_pv = bad_pv, candidate_threshold = 0.5, candidate_track_window = 0)
        @test !u.rejected && u.success.floor_u < 0 && u.success.floor_h < 0
        @test c.rejected && 1 <= c.rejected_epoch <= 2
        # Floors hold near zero once the candidate is rejected (within 1 unit, against a fall of 20–30 uncoupled); exact sign
        # is platform-sensitive on a single seed (Linux: floor_h -0.46 on seed 1; macOS: +0.52), so the claim is the hold.
        @test c.success.floor_u > -1 && c.success.floor_h > -1
        @test c.success.floor_u - u.success.floor_u > 10 && c.success.floor_h - u.success.floor_h > 10
        @test all(e.floor_u > -1 && e.floor_h > -1 for e in c.epoch_outcomes[3:end])
    end
    @test_throws ArgumentError run_coupled(econ, gov; seed = 1, epoch = 0)
end

@testset "Probe (red): issued currency outruns deliverable resources without global RA (8.133)" begin
    # Hypothesis (author ruling 8.133): without global resource accounting the currency issued for measured value is not
    # bound to the resources and time that can deliver on it, so claims grow without bound against fixed capacity ("checks
    # it cannot cash"). Metric: total balances over one step's deliverable resources (regen × capacity × base cost).
    # Desired outcome (to hold once RA is built): claims stay within a governed horizon of capacity (here 50 steps) and do
    # not keep growing with run length. Red on the current code: 27.6 → 107.6 → 220 steps of capacity at 60/120/240 steps.
    ag = [DomainAgent([k == l ? 0.5 : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0) for k in 1:2 for r in 1:4]
    P(T) = M3cParams(ToyParams(n = 40, steps = T, plans = 6), ag, [1, 1], trues(2); λpos = 0.05, λneg = 0.02)
    claimed(T) = (p = P(T); sum(run_m3c(p; seed = 1).balance) / (p.regen * p.capacity * p.cost_per_touch))
    short, long = claimed(60), claimed(240)
    @test long > short                       # the undesired outcome without resource accounting
    @test long > 50.0
    # With global resource accounting (`ra_horizon` 50): issuance capped at the headroom, claims stay within the horizon.
    PR(T) = M3cParams(ToyParams(n = 40, steps = T, plans = 6), ag, [1, 1], trues(2); λpos = 0.05, λneg = 0.02, ra_horizon = 50.0)
    bounded(T) = (p = PR(T); sum(run_m3c(p; seed = 1).balance) / (p.regen * p.capacity * p.cost_per_touch))
    @test bounded(240) <= 50.0 + 1e-6
end

@testset "Probe: status-quo institutions reproduce boom-bust crises, recovery and regulatory capture drift (B/L3.1c, 8.92)" begin
    # Hypothesis (BACKPROPAGATION 8.92, R6; docs/CALIBRATION.md §9): The status-quo institutional baseline
    # alone (procyclical credit, one-person-one-vote, uncapped delegation, fixed escrow, delayed enforcement,
    # and statutory credit amnesia) reproduces:
    # (1) Systemic banking/financial crisis boom-bust with frequency in [0.001, 0.010] per step
    #     (calibrated to ~0.0035/step, ~3.5 per century [RR09a, LV13]) and output contraction in [0.05, 0.35] (median 0.15 [RR09b]);
    # (2) Bust recovery within the recovery window (24–48 steps, median 36 [RR09a]);
    # (3) Regulatory capture drift moving thresholds toward incumbent levels (drift delta > 0.3) with leniency
    #     multiplier (0.50) for top incumbents;
    # (4) Delegation concentration under uncapped delegation.
    # Seeds 1:6, 600 steps each.
    total_crises = 0
    total_steps = 0
    depths = Float64[]
    rec_success = 0
    rec_total = 0
    drift_deltas = Float64[]
    n_eff_vals = Float64[]

    p = StatusQuoParams(toy = ToyParams(n = 60, steps = 600, plans = 8), crisis_hazard = 0.003, credit_window = 60)
    for s in 1:6
        res = run_status_quo(p; seed = s)
        total_crises += length(res.crises_triggered)
        total_steps += 600
        append!(depths, res.crisis_depths)
        push!(drift_deltas, res.reg_threshold[1] - res.reg_threshold[end])
        push!(n_eff_vals, res.effective_delegates)
        for c in res.crises_triggered
            t_trough = min(c + p.crisis_recovery ÷ 2, 600)
            t_rec = min(c + p.crisis_recovery + 10, 600)
            if t_rec > t_trough && t_rec <= 600
                rec_total += 1
                if mean(res.output[t_trough:t_rec]) > mean(res.output[c:t_trough])
                    rec_success += 1
                end
            end
        end
    end

    freq = total_crises / total_steps
    # (1) Boom-bust frequency falls in the calibrated R6 interval [0.001, 0.010] (~3.5/century)
    @test 0.001 <= freq <= 0.010
    # Output contraction depth falls within empirical intervals (mean in [0.09, 0.30])
    @test !isempty(depths)
    @test 0.09 <= mean(depths) <= 0.30
    # (2) Recovery from busts occurs reliably (majority of crises recover post-bust)
    @test rec_total > 0
    @test rec_success / rec_total >= 0.70
    # (3) Regulatory capture drift: thresholds drift toward incumbent levels
    @test mean(drift_deltas) > 0.30
    @test all(d > 0.20 for d in drift_deltas)
    # (4) Uncapped delegation concentrates voting power below full representation
    @test mean(n_eff_vals) < 8.0
end

@testset "Probe (red): resource supplier profits from artificial scarcity withholding without AdvAp (8.133)" begin
    # Red world (author ruling 8.133; BACKPROPAGATION.md 8.133): without AdvAp discovery,
    # hiding part of owned capacity raises scarcity prices so the supplier profits.
    skills = collect(range(0.2, 0.8; length = 8))
    ag = [DomainAgent([k == l ? skills[i] : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0)
          for (i, k) in enumerate(repeat(1:2, 4))]
    function make_p(wh)
        M3cParams(ToyParams(n = 40, steps = 120, plans = 6), ag, [1, 1], trues(2);
                  λpos = 0.05, λneg = 0.02, capacity = 300.0, regen = 0.20, budget = true, transactions = true,
                  supplier = 1, supply_share = 0.5, withhold = wh, advap = false)
    end
    diffs = [run_m3c(make_p(0.6); seed = s).supplier_income - run_m3c(make_p(0.0); seed = s).supplier_income for s in 1:32]
    pe = paired_effect(diffs; z = 2.0)
    @test pe.mean > 0 && pe.significant
end

@testset "Probe: AdvAp discovery makes artificial scarcity unprofitable and self-reports earn 0 reward (8.133)" begin
    skills = collect(range(0.2, 0.8; length = 8))
    ag = [DomainAgent([k == l ? skills[i] : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0)
          for (i, k) in enumerate(repeat(1:2, 4))]
    function make_p(; wh = 0.6, reporter = 0)
        M3cParams(ToyParams(n = 40, steps = 120, plans = 6), ag, [1, 1], trues(2);
                  λpos = 0.05, λneg = 0.02, capacity = 300.0, regen = 0.20, budget = true, transactions = true,
                  supplier = 1, supply_share = 0.5, withhold = wh, advap = true, vigilance = 0.2,
                  adv_share = 0.1, adv_floor = 1.0, audit_cost = 1.0, withhold_reporter = reporter)
    end
    # 1. External discovery across 16 paired seeds:
    ext_nets = Float64[]
    for s in 1:16
        tr = run_m3c(make_p(reporter = 0); seed = s)
        @test tr.withhold_discovered
        @test tr.withhold_stopped
        @test tr.withhold_premium > 0
        @test tr.withhold_refunded ≈ tr.withhold_premium     # buyers 100% made whole
        @test tr.withhold_reward > 0
        @test tr.withhold_agent_net[1] < 0                  # repays market-wide premium + reward + audit > gain
        push!(ext_nets, tr.withhold_agent_net[1])
    end
    @test mean(ext_nets) < 0

    # 2. Lone withholder self-reporting across 16 seeds: 0 reward, repays market-wide premium, buyers made whole.
    for s in 1:16
        tr_self = run_m3c(make_p(reporter = 1); seed = s)
        @test tr_self.withhold_discovered
        @test tr_self.withhold_reward == 0.0
        @test tr_self.withhold_refunded ≈ tr_self.withhold_premium
        @test tr_self.withhold_clawback ≈ tr_self.withhold_premium
        @test tr_self.withhold_agent_net[1] < 0
    end
end

@testset "Probe: three-member supply cartel unravels because first reporter nets positive (8.133)" begin
    # 3-member cartel [1, 2, 3]: reporter 1 repays its own share (1/3 P), remaining 2/3 P + AdvAp reward
    # is paid by colluders 2 and 3; defector nets strictly positive, colluders strictly negative, buyers whole.
    skills = collect(range(0.2, 0.8; length = 8))
    ag = [DomainAgent([k == l ? skills[i] : 0.0 for l in 1:2], [k == l ? 1.0 : 0.0 for l in 1:2], 0.0)
          for (i, k) in enumerate(repeat(1:2, 4))]
    function make_cartel(; reporter = 1)
        M3cParams(ToyParams(n = 40, steps = 120, plans = 6), ag, [1, 1], trues(2);
                  λpos = 0.05, λneg = 0.02, capacity = 300.0, regen = 0.20, budget = true, transactions = true,
                  supply_share = 0.6, withhold = 0.6, supply_cartel = [1, 2, 3],
                  advap = true, vigilance = 0.2, adv_share = 0.1, adv_floor = 1.0, audit_cost = 1.0,
                  withhold_reporter = reporter)
    end
    for s in 1:16
        tr = run_m3c(make_cartel(reporter = 1); seed = s)
        @test tr.withhold_discovered
        @test tr.withhold_stopped
        @test tr.withhold_premium > 0
        @test tr.withhold_refunded ≈ tr.withhold_premium     # buyers 100% made whole
        @test tr.withhold_agent_net[1] > 0                  # first reporter nets strictly positive
        @test tr.withhold_agent_net[2] < 0 && tr.withhold_agent_net[3] < 0   # colluders net strictly negative
    end
end

@testset "Probe: graded personhood scales base vote, non-sophonts get 0 vote while protected in G, and population forks conserve vote (D2, L71, 8.34, 8.35.5)" begin
    # 1. Lean rules: graded personhood across 6 dimensions, non-sophont 0 vote, and fork conservation.
    @test personhood(zeros(6)) == 0.0
    @test personhood(Float64[]) == 0.0
    @test personhood([1.0, 0.5, 0.5, 1.0, 0.0, 0.0]) ≈ 0.5
    @test personhood([1.5, -0.2, 1.0]) ≈ 2.0 / 3.0
    @test base_vote(1.0, 1.0, false) == 0.0                       # non-sophont gets 0 base vote
    @test base_vote(1.0, 0.5, true) ≈ 0.5                         # graded personhood scales vote
    @test base_vote(2.0, 0.75, true; fork_share = 0.5) ≈ 0.75     # fork divides base vote
    @test_throws ArgumentError personhood([NaN])
    @test_throws ArgumentError base_vote(-1.0, 0.5, true)
    @test_throws ArgumentError base_vote(1.0, 1.5, true)

    # 2. World probe: population with maturing graded sophonts, non-sophonts, a 3-way fork at step 5,
    # and a partial re-merge at step 12.
    p = ToyParams(n = 20, steps = 20, plans = 8)
    soph = vcat(trues(16), falses(4))   # 16 sophonts, 4 non-sophonts
    caps = [i <= 16 ? fill(0.4, 6) : zeros(6) for i in 1:20]
    forks = [(step = 5, parent = 1, shares = [0.5, 0.3, 0.2])]
    # Merge two fork children back (new indices after 20 are 21, 22, 23).
    merges = [(step = 12, a = 21, b = 22, memory_loss = 0.25)]

    tr_split = run_population_identities(p; seed = 1, sophont = soph, capacities = caps,
                                         maturation_rate = 0.03, fork_events = forks, merge_events = merges,
                                         fork_rule = :split, harm_non_sophont_probe = true)
    # Counterexample: naive per-identity voting lets the fork triple its parent's base vote.
    tr_naive = run_population_identities(p; seed = 1, sophont = soph, capacities = caps,
                                         maturation_rate = 0.03, fork_events = forks, merge_events = merges,
                                         fork_rule = :per_identity, harm_non_sophont_probe = true)

    # Non-sophonts still hold 0 base vote yet are included in G's floors, rejecting every harm-non-sophont plan.
    @test all(tr_split.base_votes[i] == 0.0 for i in 17:20)
    @test tr_split.harm_non_sophont_rejected == p.steps
    @test tr_split.floor_h[end] >= tr_split.floor_h[1]

    # Maturation lifts per-identity personhood from 0.4 toward 1.0, lifting total base votes smoothly
    # BEFORE the fork without any fork-inflation discontinuity.
    @test tr_split.total_votes_trace[4] > tr_split.total_votes_trace[1]
    @test sum(tr_split.base_votes[i] for i in 21:23) <= 1.0 + 1e-9   # merged 21 + surviving 23 <= 1 full person vote
    @test tr_naive.total_votes_trace[5] > tr_split.total_votes_trace[5] + 0.5   # naive inflated votes on fork step
end
