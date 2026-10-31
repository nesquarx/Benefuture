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
    # Counterexample: harm is burnt. Side harm on every action lowers supply against the same world without it.
    clean, harmed = run_m3c(world(); seed = 1), run_m3c(world(p_side = 1.0, side_share = 1.0); seed = 1)
    @test sum(harmed.supply) < sum(clean.supply)
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
