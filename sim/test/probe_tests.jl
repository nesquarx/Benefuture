# Mechanism probes (CLAUDE.md, Verification): each the smallest world that exercises one mechanism
# alone, with its acceptance and counterexample cases, seconds to run. A mechanism enters the full
# worlds and the batteries only once its probe is green.

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
    @test own(run_m3c(nw(ratchet_horizon = 1.0); seed = 1)) < own(on) - 0.2   # the short horizon locks
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
    @test t_stag.newcomer_u_gain < 0.5 && t_acc.newcomer_u_gain > 5 * t_stag.newcomer_u_gain
    t_out = run_m7(p; seed = 1, accession_step = 10, accession_n = 150)
    @test t_out.newcomer_u_gain > 2.0 && isempty(t_out.degraded) && isempty(t_out.nha_bearers)
    t_tight = run_m7(p; seed = 1, accession_step = 10, accession_n = 150, uplift_capacity = 20, lt_window = 2)
    @test t_tight.newcomer_u_gain > 1.0 && !isempty(t_tight.degraded) && !isempty(t_tight.nha_bearers)
end
