# Toy model M7, first rung: deaths (author ruling 8.47; conjecture A36). G's floors are taken over
# the beings present at decision time, a life a plan would end keeping its place at the bottom (Lean
# `removal_cannot_raise_floor`, `removal_cannot_raise_quantile_floor`; here one threshold below the
# lowest level, a toy convention). The standard trolley rules hold (redirecting harm so that fewer die
# is acceptable), but irreparable harm is not traded against non-breakthrough gains: a life ended or
# saved against not acting is valued by its foreclosed future over the long-term window, in the
# irreparable tier, scaled by the governed breakthrough scale (Lean `foreclosed_ref`,
# `life_value_ref`; [P] reading). Freedom stays a subgoal reported per plan, not a filter on G
# (SPEC_DIVERGENCES §8.8). Whether doing and allowing differ (footbridge, organ harvest) is open: the
# plans below carry no such distinction.

@testset "M7 deaths: trolley rules, irreparable harm and the breakthrough scale (8.47)" begin
    # The rules: a death forecloses the being's levels and its predicted growth over the window; a life
    # saved counts as much as a life ended.
    @test foreclosed(5.0, 4.0; growth_u = 0.1, growth_h = 0.2, window = 100) ≈ 39.0
    @test foreclosed(-2.0, 4.0; growth_u = -1.0, growth_h = 0.0, window = 100) ≈ 4.0
    @test life_value(30.0, false; scale = 10) ≈ -10 * HARM_SCHEDULE[1] * 30.0
    @test life_value(30.0, true; scale = 10) ≈ -life_value(30.0, false; scale = 10)
    @test_throws ArgumentError foreclosed(NaN, 1.0; growth_u = 0.1, growth_h = 0.1, window = 100)
    @test_throws ArgumentError foreclosed(1.0, 1.0; growth_u = 0.1, growth_h = 0.1, window = -1)
    @test_throws ArgumentError life_value(-1.0, false; scale = 10)
    @test_throws ArgumentError life_value(1.0, false; scale = -1)

    p = ToyParams(n = 50, plans = 2)
    rng = Xoshiro(7)
    for trial in 1:20
        s = toy_state(p, rng)
        none = zeros(p.n)
        # Trolley switch: by default five die; the switch redirects the harm to one. Chosen, unless the one
        # holds the peak of understanding: G's ¬↓ U(max) then refuses it (finding 8.55).
        five, one = randperm(rng, p.n)[1:6] |> v -> (v[1:5], v[6])
        course = PopPlan(none, none; deaths = five)
        switch = PopPlan(none, none; deaths = [one])
        @test pop_value(s, switch, p; course) > 0
        @test pop_choose(s, [switch], p; course) == (one == argmax(s.u) ? 1 : 2)
        # Reversed: redirecting harm from one onto five is not chosen.
        @test pop_choose(s, [course], p; course = switch) == 1
        # The sacrificial trade: the two worst-off die, everyone else gains 3. Its quantile floor over the
        # decision-time population still rises, but it is no longer chosen; a modest uplift is.
        worst = sortperm(s.u .+ s.h)[1:2]
        others = setdiff(1:p.n, worst)
        gain = [b in others ? 3.0 : 0.0 for b in 1:p.n]
        sacrifice = PopPlan(gain, gain; deaths = worst)
        lift = [b in others[1:10] ? 0.3 : 0.0 for b in 1:p.n]
        uplift = PopPlan(lift, lift)
        bottom = minimum(s.u) - p.th
        @test floor_quantile([b in worst ? bottom : s.u[b] + gain[b] for b in 1:p.n], p.q) > floor_quantile(s.u, p.q)
        @test pop_value(s, sacrifice, p) < 0
        @test pop_choose(s, [sacrifice], p) == 1
        @test pop_choose(s, [sacrifice, uplift], p) == 3
        # Freedom, reported per plan, still marks the sacrifice impermissible.
        @test !fr_permissible(2.0, 0.0, 0.0, 0.0, 0.0; confidence = 0.95)
        # A breakthrough-scale gain (+30 to each of the rest) outweighs the two deaths at the default
        # scale (20); at a scale of 1000 it does not. The scale is governed.
        big = [b in others ? 30.0 : 0.0 for b in 1:p.n]
        breakthrough = PopPlan(big, big; deaths = worst)
        @test pop_choose(s, [breakthrough], p) == 2
        @test pop_choose(s, [breakthrough], p; scale = 1000) == 1
    end
    # The literal minimum stays down: the dead at the bottom keep it there.
    s = toy_state(p, Xoshiro(1))
    worst = argmin(s.u)
    du = fill(3.0, p.n); du[worst] = minimum(s.u) - p.th - s.u[worst]
    @test minimum(s.u .+ du) < minimum(s.u)
    # The peak holder on the side track: the switch saves four more lives and is still refused (8.55).
    s = toy_state(p, Xoshiro(4))
    top, rest = argmax(s.u), setdiff(1:p.n, argmax(s.u))
    @test pop_choose(s, [PopPlan(zeros(p.n), zeros(p.n); deaths = [top])], p; course = PopPlan(zeros(p.n), zeros(p.n); deaths = rest[1:5])) == 1
    @test_throws ArgumentError fr_permissible(-1.0, 0.0, 0.0, 0.0, 0.0; confidence = 0.5)
    # Malformed plans are rejected.
    s = toy_state(p, Xoshiro(2))
    @test_throws ArgumentError pop_choose(s, [PopPlan(zeros(3), zeros(3))], p)
    @test_throws ArgumentError pop_choose(s, [PopPlan(zeros(p.n), zeros(p.n); deaths = [p.n + 1])], p)
    @test_throws ArgumentError pop_choose(s, [PopPlan(zeros(p.n), zeros(p.n))], p; scale = -1)
end

# M7, second rung: teaching (understanding is shared, not moved; Lean `u_sharing_gain_nonneg`;
# conjecture B17, frontier compounding). Teaching is one to many and happens at any level: a teacher
# anywhere raises a class below it towards its teachable level, each learner by `ε` × its own
# reception (varying), the teacher keeping all of its own. G chooses among lessons and ordinary
# plans as in M0; research is spending (third rung).
@testset "M7 teaching: lessons spread understanding and feed research" begin
    p = ToyParams(n = 100, steps = 300, plans = 10)
    seeds = 1:4
    none = [run_m7(p; seed, ε = 0.0, research_share = 0.1) for seed in seeds]
    taught = [run_m7(p; seed, ε = 0.3, research_share = 0.1) for seed in seeds]
    # A lesson, one to many: it never lowers the teacher, raises no learner above the teacher, and
    # reception varies by learner.
    lesson = teaching_plan([0.0, 2.0, 5.0], 3, [1, 2], 0.5)
    @test lesson.du == [2.5, 1.5, 0.0] && all(lesson.du .>= 0)
    @test teaching_plan([0.0, 2.0, 5.0], 3, [1, 2], 0.5; reception = [0.2, 5.0]).du == [0.5, 3.0, 0.0]
    # With research as spending (a tenth of time), teaching raises the floor and median of
    # understanding and the peak too: more beings near the frontier make research succeed more often.
    sp(ts, f) = mean(getfield(success_pattern(t), f) for t in ts)
    @test sp(taught, :floor_u) > sp(none, :floor_u) && sp(taught, :median_u) > sp(none, :median_u)
    @test sp(taught, :peak_u) > sp(none, :peak_u)
    @test_throws ArgumentError run_m7(p; seed = 1, ε = 1.5)
end

# M7, third rung: research as spending (author). A governed share `research_share` of beings' time
# goes to research each step, taking those beings from ordinary work and lessons and drawing on the
# commons; each attempt succeeds with a very noisy chance rising with the researcher's understanding
# (relative to the frontier) and its novelty, and a success lands beyond the peak, teachable or tacit
# (`p_teachable`). Ordinary work may pass the peak by in-job innovation, rarely, near the top only.
@testset "M7 research as spending" begin
    p = ToyParams(n = 100, steps = 300, plans = 10)
    # A teacher passes on only its teachable understanding; tacit gains stay with it.
    @test teaching_plan([0.0, 2.0, 5.0], 3, [1, 2], 1.0; tacit = 2.0).du == [3.0, 1.0, 0.0]
    shares = (0.0, 0.1, 0.8)
    runs = Dict(r => [run_m7(p; seed, ε = 0.3, research_share = r) for seed in 1:4] for r in shares)
    peak(r) = mean(success_pattern(t).peak_u for t in runs[r])
    floor(r) = mean(success_pattern(t).floor_u for t in runs[r])
    # Research moves the frontier; too much of it takes from uplift.
    @test peak(0.1) > peak(0.0)
    @test floor(0.8) < floor(0.1)
    @test all(t.research_spent > 0 for t in runs[0.1]) && all(t.research_spent == 0 for t in runs[0.0])
    @test_throws ArgumentError run_m7(p; seed = 1, ε = 0.3, research_share = 1.5)
end

# G per entity (author ruling 8.50): every entity runs its own messy approximation of G. Each acting
# entity reads the world through its own noisy view (`view_σ`), predicts its options with its own
# error (`pred_σ`) and chooses among them by the Lean rules; many act each step, concurrently. A single
# global G choosing one plan a step is the limiting case (`central = true`).
@testset "M7 G per entity" begin
    p = ToyParams(n = 100, steps = 300, plans = 10)
    tr = run_m7(p; seed = 1, ε = 0.3)
    @test mean(tr.actions) > 1  # many entities act each step
    @test isequal(run_m7(p; seed = 1, ε = 0.3), tr)
    central = run_m7(p; seed = 1, ε = 0.3, central = true)
    @test all(central.actions .<= 1)
    # Messy inputs: with views and predictions exact, floors fall less often than with messy ones.
    exact = [run_m7(p; seed, ε = 0.3, view_σ = 0.0, pred_σ = 0.0) for seed in 1:3]
    messy = [run_m7(p; seed, ε = 0.3, view_σ = 1.0, pred_σ = 1.0) for seed in 1:3]
    @test mean(success_pattern(t).floor_u_falls for t in messy) > mean(success_pattern(t).floor_u_falls for t in exact)
    @test_throws ArgumentError run_m7(p; seed = 1, ε = 0.3, p_act = 1.5)
end

# M7 births (author ruling 8.52; [P] reading). Models predict a newborn's mature levels; the pool's
# optimistic average (the mean of its predictions at or above a governed quantile), accepted when the
# pool's confidence reaches a governed threshold, is the level the newborn counts at in G's floors, so
# its low initial levels do not drag the floors as a fresh low. Those causing the birth post an escrow
# sized to the predicted shortfall below the baseline over the dependency window; it settles against the
# measured shortfall like any escrow. The newborn is not among the decision-time beings whose V G sums
# (L74, B(t)); its causers' stake is. Lean `optimistic_average_ref`, `birth_level_ref`,
# `birth_escrow_ref`, `shortfall_ref`.
@testset "M7 births: rules" begin
    # Acceptance against spec/vectors/births.json (generated by Main.lean from the Lean reference).
    v = vectors("births")
    @test foreclosed(5.0, 4.0; growth_u = 0.1, growth_h = 0.2, window = 100) ≈ v["foreclosed_u5_h4_g0_1_0_2_w100"]
    @test life_value(30.0, false; scale = 20, tier_weight = 0.9) ≈ v["life_value_ended_f30_w0_9_s20"]
    @test life_value(30.0, true; scale = 20, tier_weight = 0.9) ≈ v["life_value_saved_f30_w0_9_s20"]
    @test optimistic_average([1.0, 2.0, 3.0, 4.0], 0.5) ≈ v["optimistic_average_1234_q0_5"]
    @test birth_level([1.0, 2.0, 3.0, 4.0]; q = 0.5, confidence = 0.7, threshold = 0.75, initial = 0.0) ≈ v["birth_level_unconfident"]
    @test birth_escrow(0.0, 4.0; window = 4, baseline = 2.0) ≈ v["birth_escrow_0_to_4_w4_base2"]
    @test shortfall([1.0, 2.0, 3.0], 2.5) ≈ v["shortfall_123_base2_5"]
    @test optimistic_average([1.0, 2.0, 3.0, 4.0], 0.5) ≈ 3.0
    @test optimistic_average([1.0, 2.0, 3.0, 4.0], 0.0) ≈ 2.5
    @test optimistic_average([1.0, 2.0, 3.0, 4.0], 1.0) ≈ 4.0
    @test birth_level([1.0, 2.0, 3.0, 4.0]; q = 0.5, confidence = 0.8, threshold = 0.75, initial = 0.0) ≈ 3.0
    @test birth_level([1.0, 2.0, 3.0, 4.0]; q = 0.5, confidence = 0.7, threshold = 0.75, initial = 0.0) == 0.0
    @test shortfall([1.0, 2.0, 3.0], 2.5) ≈ 2.0
    @test birth_escrow(0.0, 4.0; window = 4, baseline = 2.0) ≈ 1.0   # trajectory 1, 2, 3, 4
    @test birth_escrow(0.0, 8.0; window = 4, baseline = 2.0) == 0.0
    @test birth_escrow(0.0, 0.0; window = 4, baseline = 2.0) ≈ 8.0
    # A more optimistic prediction never asks for more escrow.
    @test birth_escrow(0.0, 6.0; window = 10, baseline = 3.0) <= birth_escrow(0.0, 5.0; window = 10, baseline = 3.0)
    # Adversarial inputs.
    @test_throws ArgumentError optimistic_average(Float64[], 0.5)
    @test_throws ArgumentError optimistic_average([1.0, NaN], 0.5)
    @test_throws ArgumentError optimistic_average([1.0], 1.5)
    @test_throws ArgumentError birth_level([1.0]; q = 0.5, confidence = 1.5, threshold = 0.75, initial = 0.0)
    @test_throws ArgumentError birth_escrow(0.0, 4.0; window = 0, baseline = 2.0)
    @test_throws ArgumentError shortfall([1.0, Inf], 2.0)
end

@testset "M7 births: G values a birth by the predicted trajectory" begin
    # 55 beings: with 50, one newborn moves the nearest-rank 10% quantile up a rank and a single fresh low
    # leaves the floor where it was (a rank artefact of small populations).
    p = ToyParams(n = 55, plans = 2)
    s = toy_state(p, Xoshiro(3))
    joy = zeros(p.n); joy[1] = 0.5  # the causer's own stake
    preds = median(s.u) .+ [-0.5, 0.0, 0.3, 0.6, 1.0]
    born = Newborn(preds, preds; confidence = 0.9)
    unsure = Newborn(preds, preds; confidence = 0.6)
    # Confident: the newborn counts at the optimistic average, the floors hold, and the birth is chosen.
    @test pop_choose(s, [PopPlan(zeros(p.n), joy; births = [born])], p) == 2
    # Not confident: it counts at its initial level, a fresh low, the floors fall, and it is not.
    @test pop_choose(s, [PopPlan(zeros(p.n), joy; births = [unsure])], p) == 1
    # The newborn's own levels do not enter ΣV (it is not among the decision-time beings).
    @test pop_value(s, PopPlan(zeros(p.n), zeros(p.n); births = [born]), p) == 0.0
    @test_throws ArgumentError Newborn(Float64[], Float64[]; confidence = 0.9)
    @test_throws ArgumentError Newborn(preds, preds; confidence = 1.2)
end

@testset "M7 births: runs, escrow and the over-optimist" begin
    p = ToyParams(n = 100, steps = 200, plans = 10)
    seeds = 1:3
    with = [run_births(p; seed) for seed in seeds]
    without = [run_births(p; seed, p_birth = 0.0) for seed in seeds]
    @test all(t.births > 0 for t in with) && all(t.population[end] > p.n for t in with)
    @test all(t.births == 0 for t in without)
    # With the pool's confidence below the threshold, newborns would count at a fresh low: none is chosen.
    @test all(run_births(p; seed, pool_confidence = 0.6).births == 0 for seed in seeds)
    # Births do not drag the floors G reads: the floor of understanding falls no more often than without.
    sp(ts, f) = mean(getfield(success_pattern(t), f) for t in ts)
    @test sp(with, :floor_u_falls) <= sp(without, :floor_u_falls) + 0.01
    @test sp(with, :floor_h_falls) <= sp(without, :floor_h_falls) + 0.01
    # Escrow settles against the measured shortfall: what was posted, plus clawbacks, less refunds, plus
    # what no one covered, is the measured shortfall.
    for t in with
        @test t.posted + t.clawback - t.refund + t.uncovered ≈ t.measured atol = 1e-6
        @test t.settled > 0
    end
    # G per entity is the default; one global G is the limiting case.
    @test mean(with[1].actions) > 1
    @test all(run_births(p; seed = 1, central = true).actions .<= 1)
    @test isequal(run_births(p; seed = 1), with[1])
    # Gaming: a causer that brings over-optimistic models into the pool (3 models, 20 too high) escrows
    # too little. Settlement claws the shortfall back (what no one covers stays under 1% of the measured
    # shortfall), and its ledger's negative share ratchets its credence towards a coin toss, below the
    # threshold, so its later births count at a fresh low; honest causers stay above it. Births chosen
    # within the first dependency window, before any settlement, escape the ratchet (finding 8.54).
    initial = 1:p.n
    gamed = [run_births(p; seed, p_birth = 0.1, gamers = 0.2, gamer_bias = 20.0, gamer_models = 3) for seed in seeds]
    loose = [run_births(p; seed, p_birth = 0.1, gamers = 0.2, gamer_bias = 20.0, gamer_models = 3, ratchet = false) for seed in seeds]
    for t in gamed
        g, h = t.gamer[initial], .!t.gamer[initial]
        made = t.births_by[initial] .> 0
        @test mean(t.confidence[initial][g .& made]) < 0.75 <= mean(t.confidence[initial][h .& made])
        @test t.uncovered < 0.01 * t.measured
    end
    # Without the ratchet, the over-optimists cause more births and escrow less of their shortfall.
    per_gamer(ts) = mean(mean(t.births_by[initial][t.gamer[initial]]) for t in ts)
    @test per_gamer(loose) > per_gamer(gamed)
    @test mean(t.clawback / t.measured for t in loose) > mean(t.clawback / t.measured for t in gamed)
    # Adversarial inputs.
    @test_throws ArgumentError run_births(p; seed = 1, q_opt = 1.5)
    @test_throws ArgumentError run_births(p; seed = 1, threshold = -0.1)
    @test_throws ArgumentError run_births(p; seed = 1, window = 0)
    @test_throws ArgumentError run_births(p; seed = 1, birth_pred_σ = -1.0)
    @test_throws ArgumentError run_births(p; seed = 1, gamers = 1.5)
end

# Population ethics (docs/SOTA.md, item 10; Arrhenius 2000). Toy assumption: level 0 is a life barely
# worth living. The success pattern reads floors and medians, not totals.
@testset "M7 births: the Repugnant and Sadistic Conclusions" begin
    p = ToyParams(n = 50, plans = 2)
    s = toy_state(p, Xoshiro(5))
    world(us, hs) = (u = [s.u; us], h = [s.h; hs])
    function pattern(w)
        tr = (floor_u = [floor_quantile(s.u, p.q), floor_quantile(w.u, p.q)], floor_h = [floor_quantile(s.h, p.q), floor_quantile(w.h, p.q)],
              median_u = [median(s.u), median(w.u)], median_h = [median(s.h), median(w.h)], peak_u = [maximum(s.u), maximum(w.u)],
              worst_drop = [0.0, 0.0])
        success_pattern(tr)
    end
    newborns(level, k) = [Newborn(fill(level, 5), fill(level, 5); confidence = 0.9) for _ in 1:k]
    stake(k) = (j = zeros(p.n); j[1:min(k, p.n)] .= 0.5 * k / min(k, p.n); j)  # causers' joy, one unit per birth
    # Repugnant Conclusion: 200 lives barely worth living (0.5) against 10 good ones (median + 1). The
    # many carry the larger total and the larger stake in ΣV, but they drag the floors, so G takes the few.
    good = median(s.u) + 1
    few, many = world(fill(good, 10), fill(good, 10)), world(fill(0.5, 200), fill(0.5, 200))
    @test sum(many.u .+ many.h) > sum(few.u .+ few.h)
    @test pattern(few).floor_u > pattern(many).floor_u && pattern(few).median_u > pattern(many).median_u
    @test pop_choose(s, [PopPlan(zeros(p.n), stake(200); births = newborns(0.5, 200)),
                         PopPlan(zeros(p.n), stake(10); births = newborns(good, 10))], p) == 3
    # Sadistic Conclusion: 3 lives not worth living (−5) against 30 lives barely worth living (1). The
    # quantile floor and the median rank the few negative lives higher: the success pattern gives up
    # non-sadism. The literal minimum would not.
    sad, mild = world(fill(-5.0, 3), fill(-5.0, 3)), world(fill(1.0, 30), fill(1.0, 30))
    @test pattern(sad).floor_u > pattern(mild).floor_u && pattern(sad).median_u > pattern(mild).median_u
    @test minimum(sad.u) < minimum(mild.u)
    # G, against not acting, admits neither addition: both lower the floors.
    @test pop_choose(s, [PopPlan(zeros(p.n), stake(3); births = newborns(-5.0, 3)),
                         PopPlan(zeros(p.n), stake(30); births = newborns(1.0, 30))], p) == 1
    # Forced to choose (the mild births happen unless redirected), G finds the sadistic addition admissible
    # (the floors rise against the course), and only the causers' stakes in ΣV decide: equal stakes tie and
    # the course stands; one more unit of stake takes the sadistic addition; a smaller one does not.
    mild_plan = PopPlan(zeros(p.n), stake(30); births = newborns(1.0, 30))
    @test pop_choose(s, [PopPlan(zeros(p.n), stake(30); births = newborns(-5.0, 3))], p; course = mild_plan) == 1
    @test pop_choose(s, [PopPlan(zeros(p.n), stake(31); births = newborns(-5.0, 3))], p; course = mild_plan) == 2
    @test pop_choose(s, [PopPlan(zeros(p.n), stake(3); births = newborns(-5.0, 3))], p; course = mild_plan) == 1
end
