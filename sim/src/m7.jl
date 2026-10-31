# Toy model M7: population change. Deaths and births (decisions over a changing population, rules in
# the Lean reference: `BenefutureReference/Population.lean`), teaching and research (`run_m7`), and
# births in a running world (`run_births`).
#
# World (this file): teaching is one to many, at any level, reception varying; research is spending
# (a governed share of beings' time, a very noisy chance of success, gains teachable or tacit), and
# only research extends the frontier, apart from rare in-job innovation near the top. Newborns grow
# from a low start to mature levels inherited in part from their causer, their needs covered to the
# baseline by the birth escrow. Each entity approximates G on its own noisy view and chooses among its
# own options (author ruling 8.50); a single global G choosing one plan a step is the limiting case
# (`central`).

# ---- Rules (Lean reference, `BenefutureReference.Population`) ----

"""
    foreclosed(u, h; growth_u, growth_h, window) -> Float64

A life's foreclosed future over the long-term window (8.47 [P]; Lean `foreclosed_ref`): its levels
plus the growth its models predict over `window` steps; negative levels and growth count as nothing.
"""
function foreclosed(u::Real, h::Real; growth_u::Real, growth_h::Real, window::Real)
    check(all(isfinite, (u, h, growth_u, growth_h, window)) && window >= 0, "finite levels and growth, window non-negative")
    ccall(sym(:bf_foreclosed), Float64, (Float64, Float64, Float64, Float64, Float64), u, h, growth_u, growth_h, window)
end

"""
    life_value(foreclosed, saved; scale, tier_weight = HARM_SCHEDULE[1]) -> Float64

Value on a being whose life a plan ends (`saved = false`) or saves against not acting (8.47 [P]; Lean
`life_value_ref`): ∓ `scale` × the irreparable tier's weight × its foreclosed future.
"""
function life_value(foreclosed::Real, saved::Bool; scale::Real, tier_weight::Real = HARM_SCHEDULE[1])
    check(all(x -> isfinite(x) && x >= 0, (foreclosed, scale, tier_weight)), "foreclosed future, scale and tier weight finite and non-negative")
    ccall(sym(:bf_life_value), Float64, (Float64, Float64, Float64, UInt8), foreclosed, tier_weight, scale, saved)
end

"""
    optimistic_average(preds, q) -> Float64

Mean of a model pool's predictions at or above its lower q-quantile (8.52 [P]; Lean
`optimistic_average_ref`).
"""
function optimistic_average(preds, q::Real)
    check(!isempty(preds) && all(isfinite, preds), "a non-empty pool of finite predictions")
    check(isfinite(q) && 0 <= q <= 1, "q in [0, 1]")
    ccall(sym(:bf_optimistic_average), Float64, (Ptr{Cvoid}, Float64), floatarray(preds), q)
end

"""
    birth_level(preds; q, confidence, threshold, initial) -> Float64

The level a newborn counts at in G's floors (8.52 [P]; Lean `birth_level_ref`): the optimistic
average when the pool's confidence reaches `threshold`, else its initial level.
"""
function birth_level(preds; q::Real, confidence::Real, threshold::Real, initial::Real)
    check(!isempty(preds) && all(isfinite, preds) && isfinite(initial), "a non-empty pool of finite predictions, a finite initial level")
    check(all(x -> isfinite(x) && 0 <= x <= 1, (q, confidence, threshold)), "q, confidence and threshold in [0, 1]")
    ccall(sym(:bf_birth_level), Float64, (Ptr{Cvoid}, Float64, Float64, Float64, Float64), floatarray(preds), q, confidence, threshold, initial)
end

"Shortfall of a trajectory below a baseline, Σ max(0, baseline − level) (Lean `shortfall_ref`)."
function shortfall(levels, baseline::Real)
    check(all(isfinite, levels) && isfinite(baseline), "finite levels and baseline")
    ccall(sym(:bf_shortfall), Float64, (Ptr{Cvoid}, Float64), floatarray(levels), baseline)
end

"""
    birth_escrow(initial, predicted; window, baseline) -> Float64

The birth escrow (8.52 [P]; Lean `birth_escrow_ref`): the predicted shortfall below the baseline over
the dependency window, along the line from the initial level to the predicted one.
"""
function birth_escrow(initial::Real, predicted::Real; window::Integer, baseline::Real)
    check(all(isfinite, (initial, predicted, baseline)) && window >= 1, "finite levels, window at least 1")
    ccall(sym(:bf_birth_escrow), Float64, (Float64, Float64, Csize_t, Float64), initial, predicted, window, baseline)
end

# ---- Plans over a changing population ----

"A birth a plan causes: the model pool's predictions of the newborn's mature levels and its confidence."
struct Newborn
    preds_u::Vector{Float64}
    preds_h::Vector{Float64}
    confidence::Float64
    init_u::Float64
    init_h::Float64
    function Newborn(preds_u, preds_h; confidence::Real, init_u::Real = 0.0, init_h::Real = 0.0)
        check(!isempty(preds_u) && !isempty(preds_h) && all(isfinite, preds_u) && all(isfinite, preds_h), "non-empty, finite predictions")
        check(0 <= confidence <= 1 && isfinite(init_u) && isfinite(init_h), "confidence in [0, 1], finite initial levels")
        new(Float64.(preds_u), Float64.(preds_h), Float64(confidence), Float64(init_u), Float64(init_h))
    end
end

"""
    PopPlan(du, dh; deaths = Int[], births = Newborn[])

A plan over a changing population: changes to the decision-time beings' levels, the lives it ends and
the births it causes, all against the status quo.
"""
struct PopPlan
    du::Vector{Float64}
    dh::Vector{Float64}
    deaths::Vector{Int}
    births::Vector{Newborn}
end
PopPlan(du, dh; deaths = Int[], births = Newborn[]) = PopPlan(Float64.(du), Float64.(dh), collect(Int, deaths), collect(Newborn, births))

function check_pop_plan(s::ToyState, plan::PopPlan)
    n = length(s.u)
    check(length(plan.du) == n && length(plan.dh) == n && all(isfinite, plan.du) && all(isfinite, plan.dh), "a plan covers every being, finitely")
    check(all(b -> 1 <= b <= n, plan.deaths) && allunique(plan.deaths), "deaths name distinct beings")
end

"""
    pop_value(s, plan, p; course, lt_window = 100, growth = 0.1, scale = 20) -> Float64

Σ V over the decision-time beings (L74, B(t)) of `plan` against `course` (not acting; by default no
change). A being alive in both is valued by V on the difference (every loss passing harm, as in M0); a
life one ends and the other keeps by `life_value` of its foreclosed future in the world where it
lives, its predicted growth `growth` per step over `lt_window` steps. Newborns are not decision-time
beings: their own levels enter G's floors (`pop_choose`), not ΣV; their causers' stake does.
"""
function pop_value(s::ToyState, plan::PopPlan, p::ToyParams; course::Union{Nothing,PopPlan} = nothing,
                   lt_window::Real = 100, growth::Real = 0.1, scale::Real = 20.0)
    n = length(s.u)
    course === nothing && (course = PopPlan(zeros(n), zeros(n)))
    check_pop_plan(s, plan); check_pop_plan(s, course)
    check(isfinite(scale) && scale >= 0 && isfinite(lt_window) && lt_window >= 0 && isfinite(growth), "scale and window non-negative, growth finite")
    dead_a, dead_c = Set(plan.deaths), Set(course.deaths)
    total = 0.0
    for b in 1:n
        a, c = b in dead_a, b in dead_c
        a && c && continue
        if a || c
            living = a ? course : plan
            f = foreclosed(s.u[b] + living.du[b], s.h[b] + living.dh[b]; growth_u = growth, growth_h = growth, window = lt_window)
            total += life_value(f, c; scale)
        else
            du, dh = (plan.du[b] - course.du[b]) / p.th, (plan.dh[b] - course.dh[b]) / p.th
            (du == 0 && dh == 0) || (total += being_value(du, dh, p))
        end
    end
    total
end

# Levels G's floors read in a plan's world: the decision-time beings (the dead marked NaN, placed at
# the bottom later), then each newborn at the level its pool's prediction earns (`birth_level`).
function pop_levels(s::ToyState, plan::PopPlan, q_opt::Real, threshold::Real)
    u, h = s.u .+ plan.du, s.h .+ plan.dh
    u[plan.deaths] .= NaN; h[plan.deaths] .= NaN
    for nb in plan.births
        push!(u, birth_level(nb.preds_u; q = q_opt, confidence = nb.confidence, threshold, initial = nb.init_u))
        push!(h, birth_level(nb.preds_h; q = q_opt, confidence = nb.confidence, threshold, initial = nb.init_h))
    end
    u, h
end

"""
    pop_choose(s, plans, p; course, q_opt = 0.5, threshold = 0.75, lt_window = 100, growth = 0.1, scale = 20) -> Int

G over a changing population: 1 for `course` (not acting; by default no change), k + 1 for
`plans[k]`. Values by `pop_value` against the course; admissibility by the Lean rules on the floors
and peak against the course's, over the decision-time population (the dead one threshold below the
lowest level in any world, a toy convention) plus each world's newborns at their `birth_level`.
"""
function pop_choose(s::ToyState, plans, p::ToyParams; course::Union{Nothing,PopPlan} = nothing, q_opt::Real = 0.5,
                    threshold::Real = 0.75, lt_window::Real = 100, growth::Real = 0.1, scale::Real = 20.0)
    n = length(s.u)
    course === nothing && (course = PopPlan(zeros(n), zeros(n)))
    worlds = [course; collect(PopPlan, plans)]
    foreach(w -> check_pop_plan(s, w), worlds)
    levels = [pop_levels(s, w, q_opt, threshold) for w in worlds]
    lo(i) = minimum(x for (u, h) in levels for x in (i == 1 ? u : h) if !isnan(x))
    bottom_u, bottom_h = lo(1) - p.th, lo(2) - p.th
    fl = map(levels) do (u, h)
        uu, hh = replace(u, NaN => bottom_u), replace(h, NaN => bottom_h)
        (floor_quantile(uu, p.q), floor_quantile(hh, p.q), maximum(uu))
    end
    values = [0.0; [pop_value(s, w, p; course, lt_window, growth, scale) for w in worlds[2:end]]]
    i = g_choose(values, zeros(length(worlds)), [f[1] - fl[1][1] for f in fl], [f[2] - fl[1][2] for f in fl], [f[3] - fl[1][3] for f in fl])
    i === nothing && error("not acting must always be admissible")
    i
end

"""
    teaching_plan(u, teacher, learners, ε; reception = ones) -> ToyPlan

A lesson, one to many: each learner below the teacher gains `ε` × its own `reception` of the gap to
the teacher's teachable understanding (its level less its `tacit` part), never passing it; the
teacher and everyone else are unchanged (understanding is shared, not moved).
"""
function teaching_plan(u::AbstractVector, teacher::Integer, learners, ε::Real; reception = ones(length(learners)), tacit::Real = 0.0)
    check(0 <= ε <= 1 && 1 <= teacher <= length(u) && all(l -> 1 <= l <= length(u), learners), "ε in [0, 1], beings in range")
    check(length(reception) == length(learners) && all(r -> isfinite(r) && r >= 0, reception), "one non-negative reception per learner")
    check(isfinite(tacit) && tacit >= 0, "tacit understanding non-negative")
    du = zeros(length(u))
    for (l, r) in zip(learners, reception)
        l == teacher && continue
        gap = max(0.0, u[teacher] - tacit - u[l])  # only the teacher's teachable understanding passes on
        du[l] = min(gap, ε * r * gap)
    end
    ToyPlan(du, zeros(length(u)))
end

"""
    run_m7(p; seed, ε, research_share = 0.1, ...) -> NamedTuple

M0's world with teaching and research. Each step a share `research_share` of beings (governed: what
Benefuture spends on research) research instead of working, and each attempt's `research_cost` is
tallied (`research_spent`; this world has no commons to draw it from). An attempt by being b
succeeds with a very noisy chance, `p_research` × (u_b / peak)² × novelty_b × log-normal(`research_σ`)
(novelty a per-being trait, world), and raises b by a log-normal `research_gain` (new understanding
beyond the frontier only where it passes the peak); the work done by the rest scales with their
share of time; the gain
is teachable with chance `p_teachable`, else tacit (it stays with b). Lessons (`lessons`, one to many,
teachers at any level, reception varying with `reception_σ`) pass on teachers' teachable understanding.
Ordinary work carries no one past the peak, except by in-job innovation: a chance `p_innovate` ×
((u_b − median) / (peak − median))⁴, near the top only. G chooses among ordinary plans and lessons by
the Lean rules. With G per entity (the default), each entity not researching acts with chance `p_act`,
reading the levels through its own noisy view (`view_σ`), predicting its `options` ordinary plans
(each an `action_scale` share of a plan) and a lesson it could teach (one entity's whole act) with
error `pred_σ`; all act concurrently, and concurrent lessons never lift a learner above the best
teacher it met. With `central`, one global G chooses one plan a step among `p.plans` ordinary plans
and `lessons` lessons, the work done scaled by the time left. Records the Goal's success pattern, the
top decile's share, research spending (tallied), successes (`breakthroughs`), in-job innovations,
entities acting per step (`actions`) and the kind of each action taken (`kind`).
"""
function run_m7(p::ToyParams; seed, ε::Real = CALIBRATED.ε, research_share::Real = 0.1, research_gain::Real = 2.0, research_σ::Real = 1.0,
                p_research::Real = 0.05, p_teachable::Real = 0.5, research_cost::Real = 1.0, p_innovate::Real = 0.01,
                class::Integer = 10, lessons::Integer = 3, reception_σ::Real = CALIBRATED.reception_σ, teacher_cv::Real = CALIBRATED.teacher_cv, central::Bool = false,
                p_act::Real = 0.2, action_scale::Real = 0.05, view_σ::Real = 0.2, pred_σ::Real = 0.2, options::Integer = 3)
    check(0 <= ε <= 1 && 0 <= research_share < 1 && all(x -> isfinite(x) && x >= 0, (research_gain, research_σ, research_cost, reception_σ, teacher_cv)) &&
          0 <= p_research <= 1 && 0 <= p_teachable <= 1 && 0 <= p_innovate <= 1 && class >= 1 && lessons >= 0 &&
          0 <= p_act <= 1 && all(x -> isfinite(x) && x >= 0, (action_scale, view_σ, pred_σ)) && options >= 1,
          "shares and chances in [0, 1] (research share below 1), gains, scatters and cost non-negative, class positive")
    rng = Xoshiro(seed)
    trng, rrng = Xoshiro(hash((seed, :reception))), Xoshiro(hash((seed, :research)))
    vrng = Xoshiro(hash((seed, :views)))  # entities' views and predictions
    # Teachers differ (3.7): each being's lessons carry a persistent log-normal multiplier of mean 1 on ε
    # (`teacher_cv`; 0 is the limiting case of identical teachers), on its own stream.
    quality = lognormal_mean1(Xoshiro(hash((seed, :teachers))), teacher_cv, p.n)
    # A learner's reception is log-normal of mean 1 (a few learn a lot; 3.7), so ε stays the mean share of the gap.
    receive(n) = exp.(reception_σ .* randn(trng, n) .- reception_σ^2 / 2)
    s = toy_state(p, rng)
    novelty = 0.2 .+ 0.8 .* rand(rrng, p.n)  # a per-being trait: how novel its perspective (world)
    tacit = zeros(p.n)
    tr = (floor_u = Float64[], floor_h = Float64[], median_u = Float64[], median_h = Float64[], peak_u = Float64[],
          worst_drop = Float64[], top_share = Float64[], chosen = Int[], kind = Symbol[], actions = Int[], breakthroughs = Ref(0),
          innovations = Ref(0), spent = Ref(0.0))
    prev = Ref((copy(s.u), copy(s.h)))
    function record!()
        push!(tr.floor_u, floor_quantile(s.u, p.q)); push!(tr.floor_h, floor_quantile(s.h, p.q))
        push!(tr.median_u, median(s.u)); push!(tr.median_h, median(s.h)); push!(tr.peak_u, maximum(s.u))
        pu, ph = prev[]
        push!(tr.worst_drop, max(0.0, maximum(pu .- s.u), maximum(ph .- s.h)))
        prev[] = (copy(s.u), copy(s.h))
        shifted = s.u .- minimum(s.u)  # share of understanding above the lowest level
        top = sort(shifted; rev = true)[1:max(1, p.n ÷ 10)]
        push!(tr.top_share, sum(shifted) > 0 ? sum(top) / sum(shifted) : 0.1)
    end
    record!()
    for _ in 1:p.steps
        peak, med = maximum(s.u), median(s.u)
        # Research: a share of beings spend this step on it.
        researching = [rand(rrng) < research_share for _ in 1:p.n]
        for b in findall(researching)
            tr.spent[] += research_cost
            rel = peak > 0 ? clamp(s.u[b] / peak, 0.0, 1.0) : 0.0
            chance = clamp(p_research * rel^2 * novelty[b] * exp(research_σ * randn(rrng)), 0.0, 1.0)
            if rand(rrng) < chance
                gain = research_gain * exp(0.5 * randn(rrng))
                new = s.u[b] + gain  # beyond the frontier only if it passes the peak
                rand(rrng) < p_teachable || (tacit[b] += new - s.u[b])
                s.u[b] = new
                tr.breakthroughs[] += 1
            end
        end
        workforce = 1 - count(researching) / p.n
        peak = maximum(s.u)  # after this step's research: innovation is counted against it
        # Ordinary work carries no one past the frontier, but for rare in-job innovation near the top.
        near = [peak > med ? clamp((s.u[b] - med) / (peak - med), 0.0, 1.0)^4 : 0.0 for b in 1:p.n]
        function capped(pl)
            cap = [rand(rrng) < p_innovate * near[b] ? Inf : max(0.0, peak - s.u[b]) for b in 1:p.n]
            ToyPlan([pl.du[b] > 0 ? min(pl.du[b], cap[b]) : pl.du[b] for b in 1:p.n], pl.dh)
        end
        if !central
            # G per entity (8.50): each entity not researching acts with chance `p_act`, on its own
            # noisy view of the levels, predicting its own options (ordinary work, and a lesson it
            # could teach) with its own error, choosing by the Lean rules; all act concurrently.
            total_du, total_dh, acted = zeros(p.n), zeros(p.n), 0
            lesson_du, lesson_cap = zeros(p.n), fill(-Inf, p.n)  # lessons this step, and the best teachable level each learner met
            for e in 1:p.n
                (researching[e] || rand(rng) >= p_act) && continue
                view = ToyState(s.u .+ view_σ .* randn(vrng, p.n), s.h .+ view_σ .* randn(vrng, p.n))
                opts = ToyPlan[]
                for _ in 1:options
                    pl = capped(random_plan(rng, p))
                    push!(opts, ToyPlan(action_scale .* pl.du, action_scale .* pl.dh))
                end
                below = [b for b in 1:p.n if view.u[b] < view.u[e] - tacit[e]]
                if !isempty(below)
                    learners = below[randperm(rng, length(below))[1:min(class, length(below))]]
                    push!(opts, teaching_plan(s.u, e, learners, min(1.0, ε * quality[e]); reception = receive(length(learners)),
                                              tacit = tacit[e]))
                end
                predicted = [ToyPlan(o.du .+ pred_σ .* action_scale .* randn(vrng, p.n) .* (o.du .!= 0),
                                     o.dh .+ pred_σ .* action_scale .* randn(vrng, p.n) .* (o.dh .!= 0)) for o in opts]
                i = choose(view, predicted, p)
                i == 1 && continue
                acted += 1
                if i - 1 <= options
                    total_du .+= opts[i - 1].du; total_dh .+= opts[i - 1].dh
                    push!(tr.kind, :ordinary)
                else
                    # Concurrent lessons add up, but no learner ends above the best teacher it met.
                    lesson_du .+= opts[i - 1].du
                    for b in findall(>(0), opts[i - 1].du)
                        lesson_cap[b] = max(lesson_cap[b], s.u[e] - tacit[e])
                    end
                    push!(tr.kind, :lesson)
                end
            end
            for b in 1:p.n
                lesson_du[b] > 0 && (total_du[b] += min(lesson_du[b], max(0.0, lesson_cap[b] - s.u[b])))
            end
            maximum(s.u .+ total_du) > peak + 1e-12 && (tr.innovations[] += 1)
            s.u .+= total_du; s.h .+= total_dh
            push!(tr.actions, acted); push!(tr.chosen, acted)
            record!()
            continue
        end
        nplans, nlessons = max(1, round(Int, p.plans * workforce)), round(Int, lessons * workforce)
        ordinary = [capped(random_plan(rng, p)) for _ in 1:nplans]
        taught = ToyPlan[]
        for _ in 1:nlessons
            teacher = rand(rng, 1:p.n)  # any level
            below = [b for b in 1:p.n if s.u[b] < s.u[teacher] - tacit[teacher]]
            isempty(below) && continue
            learners = below[randperm(rng, length(below))[1:min(class, length(below))]]
            push!(taught, teaching_plan(s.u, teacher, learners, min(1.0, ε * quality[teacher]); reception = receive(length(learners)),
                                        tacit = tacit[teacher]))
        end
        plans = [ordinary; taught]
        i = choose(s, plans, p)
        push!(tr.chosen, i); push!(tr.actions, i > 1 ? 1 : 0)
        push!(tr.kind, i == 1 ? :none : i <= nplans + 1 ? :ordinary : :lesson)
        if i > 1
            # The work done scales with the time left for it (`workforce`).
            du, dh = workforce .* plans[i - 1].du, workforce .* plans[i - 1].dh
            i <= nplans + 1 && maximum(s.u .+ du) > peak + 1e-12 && (tr.innovations[] += 1)
            s.u .+= du; s.h .+= dh
        end
        record!()
    end
    (; (k => getfield(tr, k) for k in keys(tr) if !(k in (:breakthroughs, :innovations, :spent)))...,
     breakthroughs = tr.breakthroughs[], innovations = tr.innovations[], research_spent = tr.spent[])
end

# A random plan over `n` beings touching only the `eligible` (M0's menu, over a changing population).
function random_plan_over(rng::AbstractRNG, p::ToyParams, eligible::AbstractVector{Bool})
    n = length(eligible)
    share = p.touch[1] + rand(rng) * (p.touch[2] - p.touch[1])
    mask = (rand(rng, n) .< share) .& eligible
    μu, μh = p.shift * randn(rng), p.shift * randn(rng)
    (mask .* (μu .+ p.spread .* randn(rng, n)), mask .* (μh .+ p.spread .* randn(rng, n)))
end

"""
    run_births(p; seed, p_birth = 0.02, window = 20, q_opt = 0.5, threshold = 0.75, ...) -> NamedTuple

M0's world with births (8.52) and G per entity (8.50). Each step every adult acts with chance `p_act`
on its own noisy view (`view_σ`), choosing by `pop_choose` among `options` ordinary plans (each an
`action_scale` share of a plan, predicted with error `pred_σ`) and, with chance `p_birth`, a birth it
could cause. A birth's true mature levels are inherited in part (`inherit`) from the causer around the
median, scattered by `birth_spread` (world); a pool of `pool` models predicts them with error
`birth_pred_σ` (a gaming causer, a share `gamers` of the initial beings, adds `gamer_models` models
`gamer_bias` too high). The pool's confidence is `pool_confidence`, ratcheted by the causer's ledger (`ratchet`:
Lean `ratchet_credence_ref` over `neg_share_ref` of its escrow settlements, the shortfall it escrowed
against the shortfall it failed to). The newborn counts in G's floors at `birth_level` (optimistic
quantile `q_opt`, confidence `threshold`) until its dependency window (`window` steps) closes, then at
its measured levels. Its causer posts `birth_escrow` against the happiness floor at birth (the
baseline) and must hold it (balances: `endowment`, `income` per step); the newborn grows linearly from
0 to its mature levels, untouched by ordinary plans while dependent (toy), its happiness kept at the
baseline by the escrow. At the window's close the measured shortfall (scattered by `settle_σ`) settles
against the escrow (`settlement`): clawed back from the causer as far as its balance goes (the rest
`uncovered`, met by the commons) or refunded. A birth raises its causer's happiness by `birth_joy`
(world). With `central`, one global G chooses one plan a step among `p.plans` ordinary plans and at
most one birth. Records the Goal's success pattern over the levels G reads, the floor of measured
understanding (`raw_floor_u`), population, births (by causer), final credences and the escrow totals
of settled births.
"""
function run_births(p::ToyParams; seed, p_birth::Real = 0.02, window::Integer = 20, q_opt::Real = 0.5, threshold::Real = 0.75,
                    pool_confidence::Real = 0.9, pool::Integer = 5, birth_pred_σ::Real = 0.5, birth_spread::Real = 1.0,
                    inherit::Real = 0.5, settle_σ::Real = 0.1, birth_joy::Real = 0.5, income::Real = 1.0, endowment::Real = 10.0,
                    gamers::Real = 0.0, gamer_bias::Real = 5.0, gamer_models::Integer = 1, ratchet::Bool = true, central::Bool = false,
                    p_act::Real = 0.2, action_scale::Real = 0.05, view_σ::Real = 0.2, pred_σ::Real = 0.2, options::Integer = 3,
                    lt_window::Real = 100, growth::Real = 0.1, scale::Real = 20.0)
    check(all(x -> isfinite(x) && 0 <= x <= 1, (p_birth, q_opt, threshold, pool_confidence, inherit, gamers, p_act)),
          "chances, shares, quantile, threshold and confidence in [0, 1]")
    check(window >= 1 && pool >= 1 && options >= 1 && gamer_models >= 0, "window, pool and options at least 1, gaming models non-negative")
    check(all(x -> isfinite(x) && x >= 0, (birth_pred_σ, birth_spread, settle_σ, birth_joy, income, endowment, gamer_bias,
                                         action_scale, view_σ, pred_σ)), "scatters, joy, income, endowment and bias non-negative")
    rng = Xoshiro(seed)
    vrng, brng = Xoshiro(hash((seed, :views))), Xoshiro(hash((seed, :births)))
    mrng, srng = Xoshiro(hash((seed, :birth_predictions))), Xoshiro(hash((seed, :settlement)))
    s = toy_state(p, rng)
    n0 = p.n
    gamer = [b <= round(Int, gamers * n0) for b in 1:n0]
    balance, gains, losses, births_by = fill(Float64(endowment), n0), zeros(n0), zeros(n0), zeros(Int, n0)
    # Dependents: birth step (0 for adults), causer, true mature levels, the level G reads, escrow,
    # baseline and the shortfall measured so far.
    born, causer = zeros(Int, n0), zeros(Int, n0)
    mature_u, mature_h, read_u = zeros(n0), zeros(n0), zeros(n0)
    posted_b, baseline_b, short_b = zeros(n0), zeros(n0), zeros(n0)
    tr = (floor_u = Float64[], floor_h = Float64[], median_u = Float64[], median_h = Float64[], peak_u = Float64[],
          worst_drop = Float64[], raw_floor_u = Float64[], population = Int[], actions = Int[],
          births = Ref(0), settled = Ref(0), posted = Ref(0.0), measured = Ref(0.0), clawback = Ref(0.0), refund = Ref(0.0),
          uncovered = Ref(0.0))
    dependent(b) = born[b] > 0
    reading() = [dependent(b) ? read_u[b] : s.u[b] for b in eachindex(s.u)]
    confidence(e) = ratchet ? ratchet_credence(pool_confidence, neg_share(gains[e], losses[e])) : pool_confidence
    prev = Ref((copy(s.u), copy(s.h)))
    function record!()
        ru = reading()
        push!(tr.floor_u, floor_quantile(ru, p.q)); push!(tr.floor_h, floor_quantile(s.h, p.q))
        push!(tr.median_u, median(ru)); push!(tr.median_h, median(s.h)); push!(tr.peak_u, maximum(ru))
        pu, ph = prev[]
        m = length(pu)  # beings present at the last record; newborns rise from their start
        push!(tr.worst_drop, max(0.0, maximum(pu .- s.u[1:m]), maximum(ph .- s.h[1:m])))
        prev[] = (copy(s.u), copy(s.h))
        push!(tr.raw_floor_u, floor_quantile(s.u, p.q)); push!(tr.population, length(s.u))
    end
    # A birth option for causer e: the newborn's true mature levels, the pool's predictions and the escrow.
    function birth_option(e)
        med_u, med_h = median(s.u), median(s.h)
        mu = med_u + inherit * (s.u[e] - med_u) + birth_spread * randn(brng)
        mh = med_h + inherit * (s.h[e] - med_h) + birth_spread * randn(brng)
        pu = mu .+ birth_pred_σ .* randn(mrng, pool)
        ph = mh .+ birth_pred_σ .* randn(mrng, pool)
        gamer[e] && (pu = [pu; fill(mu + gamer_bias, gamer_models)]; ph = [ph; fill(mh + gamer_bias, gamer_models)])
        c = confidence(e)
        nb = Newborn(pu, ph; confidence = c)
        base = floor_quantile(s.h, p.q)
        lu = birth_level(pu; q = q_opt, confidence = c, threshold, initial = 0.0)
        lh = birth_level(ph; q = q_opt, confidence = c, threshold, initial = 0.0)
        esc = birth_escrow(0.0, lh; window, baseline = base)
        balance[e] >= esc || return nothing
        (; e, nb, mu, mh, lu, esc, base)
    end
    function give_birth!(o)
        balance[o.e] -= o.esc
        births_by[o.e] += 1; tr.births[] += 1
        own_h = o.mh / window  # the first step of the trajectory from 0; the escrow keeps happiness at the baseline
        push!(s.u, o.mu / window); push!(s.h, max(own_h, o.base))
        push!(gamer, false); push!(balance, 0.0); push!(gains, 0.0); push!(losses, 0.0); push!(births_by, 0)
        push!(born, length(tr.floor_u)); push!(causer, o.e); push!(mature_u, o.mu); push!(mature_h, o.mh); push!(read_u, o.lu)
        push!(posted_b, o.esc); push!(baseline_b, o.base); push!(short_b, max(0.0, o.base - own_h))
    end
    record!()
    for t in 1:p.steps
        n = length(s.u)
        adults = [!dependent(b) for b in 1:n]
        balance[adults] .+= income
        # Dependents grow towards their mature levels; at the window's close the escrow settles.
        for d in filter(dependent, 1:n)
            age = t - born[d]  # steps since birth (the birth step is age 0): level (age + 1) / window of the mature
            own_h = mature_h[d] * (age + 1) / window
            s.u[d] = mature_u[d] * (age + 1) / window
            s.h[d] = max(own_h, baseline_b[d])
            short_b[d] += max(0.0, baseline_b[d] - own_h)
            age == window - 1 || continue
            s.h[d] = own_h  # mature: the escrow's work is done
            measured = max(0.0, short_b[d] * (1 + settle_σ * randn(srng)))
            st, c = settlement(measured, posted_b[d]), causer[d]
            if st > 0
                pay = min(st, max(0.0, balance[c]))
                balance[c] -= pay; tr.clawback[] += pay; tr.uncovered[] += st - pay
            else
                balance[c] -= st; tr.refund[] -= st
            end
            gains[c] += min(posted_b[d], measured); losses[c] += max(0.0, measured - posted_b[d])
            tr.posted[] += posted_b[d]; tr.measured[] += measured; tr.settled[] += 1
            born[d] = 0
        end
        adults = [!dependent(b) for b in 1:n]
        ru = reading()
        total_du, total_dh, acted, newborns = zeros(n), zeros(n), 0, []
        if !central
            for e in findall(adults)
                rand(rng) >= p_act && continue
                view = ToyState(ru .+ view_σ .* randn(vrng, n), s.h .+ view_σ .* randn(vrng, n))
                opts, plans = Any[], PopPlan[]
                for _ in 1:options
                    du, dh = random_plan_over(rng, p, adults)
                    du, dh = action_scale .* du, action_scale .* dh
                    push!(opts, (du, dh))
                    push!(plans, PopPlan(du .+ pred_σ .* action_scale .* randn(vrng, n) .* (du .!= 0),
                                         dh .+ pred_σ .* action_scale .* randn(vrng, n) .* (dh .!= 0)))
                end
                if rand(rng) < p_birth
                    o = birth_option(e)
                    if o !== nothing
                        joy = zeros(n); joy[e] = birth_joy
                        push!(opts, o); push!(plans, PopPlan(zeros(n), joy; births = [o.nb]))
                    end
                end
                i = pop_choose(view, plans, p; q_opt, threshold, lt_window, growth, scale)
                i == 1 && continue
                acted += 1
                o = opts[i - 1]
                if o isa Tuple
                    total_du .+= o[1]; total_dh .+= o[2]
                else
                    total_dh[o.e] += birth_joy; push!(newborns, o)
                end
            end
        else
            opts = Any[random_plan_over(rng, p, adults) for _ in 1:p.plans]
            plans = PopPlan[PopPlan(o[1], o[2]) for o in opts]
            e = rand(rng, findall(adults))
            if rand(rng) < p_birth
                o = birth_option(e)
                if o !== nothing
                    joy = zeros(n); joy[e] = birth_joy
                    push!(opts, o); push!(plans, PopPlan(zeros(n), joy; births = [o.nb]))
                end
            end
            i = pop_choose(ToyState(ru, copy(s.h)), plans, p; q_opt, threshold, lt_window, growth, scale)
            if i > 1
                acted = 1
                o = opts[i - 1]
                if o isa Tuple
                    total_du .+= o[1]; total_dh .+= o[2]
                else
                    total_dh[o.e] += birth_joy; push!(newborns, o)
                end
            end
        end
        s.u .+= total_du; s.h .+= total_dh
        foreach(give_birth!, newborns)
        push!(tr.actions, acted)
        record!()
    end
    conf = [confidence(b) for b in eachindex(s.u)]
    refs = (:births, :settled, :posted, :measured, :clawback, :refund, :uncovered)
    (; (k => getfield(tr, k) for k in keys(tr) if !(k in refs))..., (k => getfield(tr, k)[] for k in refs)...,
     births_by = births_by, gamer = gamer, confidence = conf)
end
