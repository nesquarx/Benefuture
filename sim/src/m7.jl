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

"""
    accession_admissible(d_scope, d_min_u, d_min_h, d_max_u, existing_du, existing_dh) -> Bool

Strong per-being accession admissibility (8.86; Lean `accession_admissible_ref`): G-admissible on
the combined population and no existing being's long-term U or H change is negative.
"""
function accession_admissible(d_scope::Real, d_min_u::Real, d_min_h::Real, d_max_u::Real, existing_du, existing_dh)
    check(all(isfinite, (d_scope, d_min_u, d_min_h, d_max_u)) && length(existing_du) == length(existing_dh) &&
          all(isfinite, existing_du) && all(isfinite, existing_dh), "finite scope/floor changes and matching finite existing-being changes")
    ccall(sym(:bf_accession_admissible), UInt8, (Float64, Float64, Float64, Float64, Ptr{Cvoid}, Ptr{Cvoid}),
          d_scope, d_min_u, d_min_h, d_max_u, floatarray(collect(Float64, existing_du)), floatarray(collect(Float64, existing_dh))) == 1
end

"""
    personhood(capacities) -> Float64

Graded personhood in `[0, 1]` across cognitive & social capacity dimensions (L71; Lean
`personhood_ref`). Empty capacities return `0.0`.
"""
function personhood(capacities)
    check(all(isfinite, capacities), "capacities must be finite")
    ccall(sym(:bf_personhood), Float64, (Ptr{Cvoid},), floatarray(collect(Float64, capacities)))
end

"""
    base_vote(base, personhood_level, sophont; fork_share = 1.0) -> Float64

Base vote weight following personhood and identity novelty rather than identity count (ruling
8.35.5, 8.34; Lean `base_vote_ref`): non-sophont sentient beings get `0.0` (while holding moral
standing in U/H/harm); sophonts scale with graded `personhood_level` and are divided by
`fork_share`.
"""
function base_vote(base::Real, personhood_level::Real, sophont::Bool; fork_share::Real = 1.0)
    check(all(isfinite, (base, personhood_level, fork_share)) && base >= 0 && 0 <= personhood_level <= 1 && 0 <= fork_share <= 1,
          "non-negative base vote, personhood and fork_share in [0, 1]")
    ccall(sym(:bf_base_vote), Float64, (Float64, Float64, UInt8, Float64),
          base, personhood_level, sophont ? 0x01 : 0x00, fork_share)
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
function run_m7(p::ToyParams; seed, ε::Real = CALIBRATED.ε, research_share::Real = 0.1, research_gain::Real = CALIBRATED.research_gain, research_σ::Real = CALIBRATED.research_σ,
                p_research::Real = 0.05, p_teachable::Real = 0.5, research_cost::Real = 1.0, p_innovate::Real = 0.01,
                class::Integer = 10, lessons::Integer = 3, reception_σ::Real = CALIBRATED.reception_σ, teacher_cv::Real = CALIBRATED.teacher_cv, central::Bool = false,
                p_act::Real = 0.2, action_scale::Real = 0.05, view_σ::Real = CALIBRATED.view_σ, pred_σ::Real = CALIBRATED.pred_σ, options::Integer = 3,
                novelty_min::Real = 0.2, rel_exponent::Real = 2.0, gain_σ::Real = 0.5, near_exponent::Real = 4.0, top_frac::Real = 0.1,
                accession_step::Integer = 0, accession_n::Integer = 0, accession_u::Real = 2.0, accession_h::Real = 2.0,
                lt_window::Integer = 20, existing_only_floors::Bool = false, uplift_capacity::Real = Inf,
                claim_ratio::Union{Nothing,AbstractVector} = nothing, audited_ratio::Union{Nothing,AbstractVector} = nothing,
                report_z::Real = 3.0, report_min::Integer = 5, claim_record::Integer = 0,
                traits::Bool = (!central && get(ENV, "BF_M7_TRAITS", "1") == "1"), n_items::Integer = 5, breakthrough::Real = 0.3, practice_per_u::Real = 1.0, tiers::Bool = false, h_profiles::Bool = tiers, research_choice::Bool = false)
    check(claim_ratio === nothing || (length(claim_ratio) == p.n && all(x -> isfinite(x) && x >= 0, claim_ratio)), "one non-negative measured-to-true ratio per being")
    check(0 <= ε <= 1 && 0 <= research_share < 1 && all(x -> isfinite(x) && x >= 0, (research_gain, research_σ, research_cost, reception_σ, teacher_cv)) &&
          0 <= p_research <= 1 && 0 <= p_teachable <= 1 && 0 <= p_innovate <= 1 && class >= 1 && lessons >= 0 &&
          0 <= p_act <= 1 && all(x -> isfinite(x) && x >= 0, (action_scale, view_σ, pred_σ, rel_exponent, gain_σ, near_exponent)) && options >= 1 &&
          0 <= novelty_min <= 1 && 0 < top_frac <= 1 &&
          accession_step >= 0 && accession_n >= 0 && lt_window >= 1 && (isinf(uplift_capacity) || uplift_capacity >= 0),
          "shares and chances in [0, 1] (research share below 1), gains, scatters and cost non-negative, class positive, valid accession parameters")
    check(audited_ratio === nothing || (claim_ratio !== nothing && length(audited_ratio) == p.n), "an audited ratio per being, with claim ratios")
    # Reported audits (8.105): a teacher whose lessons deliver less than predicted, beyond what lessons fall
    # short on everyone, is reported by its learners; a founded report audits its claims, and it is read at
    # its audited ratio from then on. Without `audited_ratio`, claims are never audited by report.
    claim_ratio = claim_ratio === nothing ? nothing : collect(Float64, claim_ratio)
    shortfall = [Float64[] for _ in 1:p.n]; taught_n = zeros(Int, p.n); audits_by_report = Ref(0); audited_at = zeros(Int, p.n)
    check(!traits || (!central && n_items >= 1 && 0 < breakthrough < 1 && practice_per_u >= 0),
          "traits mode (8.98, 8.109): G per entity")
    rng = Xoshiro(seed)
    trng, rrng = Xoshiro(hash((seed, :reception))), Xoshiro(hash((seed, :research)))
    vrng = Xoshiro(hash((seed, :views)))  # entities' views and predictions
    # Teachers differ (3.7): each being's lessons carry a persistent log-normal multiplier of mean 1 on ε
    # (`teacher_cv`; 0 is the limiting case of identical teachers), on its own stream.
    quality = lognormal_mean1(Xoshiro(hash((seed, :teachers))), teacher_cv, p.n)
    # A learner's reception is log-normal of mean 1 (a few learn a lot; 3.7), so ε stays the mean share of the gap.
    receive(n) = exp.(reception_σ .* randn(trng, n) .- reception_σ^2 / 2)
    # Personal happiness profiles (8.129, author 2026-11-08): each being's split of a happiness change over the
    # kinds (eudaimonic, shareable, satisficing, baseline, median, sensory peak), a world property on its own stream;
    # mostly satisficing on average, varying by being.
    hprof = if tiers && h_profiles
        hrng = Xoshiro(hash((seed, :happiness_profiles)))
        m = [0.15, 0.15, 0.4, 0.1, 0.1, 0.1]
        P = [m[k] * exp(0.5 * randn(hrng)) for _ in 1:p.n, k in 1:6]
        P ./ sum(P; dims = 2)
    else
        nothing
    end
    s = toy_state(p, rng)
    novelty = novelty_min .+ (1 - novelty_min) .* rand(rrng, p.n)  # a per-being trait: how novel its perspective (world)
    tacit = zeros(p.n)
    # Traits mode (8.98, ruling 8.109): understanding is the pragmatic equation on each being's traits
    # per item (a model bundle of base spread and complexity, taught whole; causal explanation; practice,
    # never taught), on its own stream; levels are that equation scaled to the toy world's units, so the
    # rest of M7 (G, views, happiness, floors) reads them as before. Work becomes practice, lessons pass
    # models and explanation, research finds better bundles.
    if traits
        xrng = Xoshiro(hash((seed, :traits)))
        twt = rand(xrng, n_items); twt ./= sum(twt)
        tms = 0.1 .+ 0.35 .* rand(xrng, p.n, n_items); tmc = 0.1 .+ 0.6 .* rand(xrng, p.n, n_items)
        tce = 0.2 .+ 0.5 .* rand(xrng, p.n, n_items)
        tts, ttc, ttce = copy(tms), copy(tmc), copy(tce); tpr = zeros(p.n, n_items)
        Utr(b) = pragmatic_understanding(1.0, twt, tce[b, :], [expected_relative_accuracy(tms[b, i] * exp(-tpr[b, i])) for i in 1:n_items], tmc[b, :])
        tscale = mean(s.u) / mean(Utr(b) for b in 1:p.n)
        relevel!() = (for b in eachindex(s.u); s.u[b] = tscale * Utr(b); end)
        relevel!()
        tbval(sp, c) = expected_relative_accuracy(sp) * (1 - c)
        # Apply a step's level changes in traits mode: work becomes practice; a gain to a newcomer (an uplift
        # programme) is a lesson from the best teacher among the existing, at the share of the gap it closes.
        function apply_traits!(du, newcomers)
            best = argmax([Utr(b) for b in 1:p.n])
            for b in eachindex(du)
                du[b] == 0 && continue
                if b in newcomers && du[b] > 0
                    gap = tscale * (Utr(best) - Utr(b))
                    gap > 0 && tlesson!(best, b, min(1.0, du[b] / gap))
                else
                    i = rand(xrng, 1:n_items); tpr[b, i] = max(0.0, tpr[b, i] + practice_per_u * du[b] / tscale)
                end
            end
            relevel!()
        end
        function tlesson!(e, l, share)
            for i in 1:n_items
                if tbval(tts[e, i], ttc[e, i]) > tbval(tms[l, i], tmc[l, i]) && rand(xrng) < share
                    tms[l, i], tmc[l, i] = tts[e, i], ttc[e, i]; tts[l, i], ttc[l, i] = tts[e, i], ttc[e, i]
                end
                tce[l, i] += share * max(0.0, ttce[e, i] - tce[l, i]); ttce[l, i] = max(ttce[l, i], tce[l, i])
            end
        end
    end
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
        top = sort(shifted; rev = true)[1:max(1, floor(Int, top_frac * p.n + 1e-9))]
        push!(tr.top_share, sum(shifted) > 0 ? sum(top) / sum(shifted) : top_frac)  # all equal: the top holds its share
    end
    record!()

    if accession_step == 0 && accession_n == 0
        for _ in 1:p.steps
            peak, med = maximum(s.u), median(s.u)
            # Research: a share of beings spend this step on it; with `research_choice` (8.129), each being instead
            # weighs a research attempt (expected gain at its chance; peak and paradigm novelty when it would pass the
            # frontier) against a step of ordinary work (a random plan's expected value), valued alike (tiers or not).
            researching = if research_choice
                map(1:p.n) do b
                    rel = peak > 0 ? clamp(s.u[b] / peak, 0.0, 1.0) : 0.0
                    ch = clamp(p_research * rel^rel_exponent * novelty[b], 0.0, 1.0)
                    g = ch * research_gain / p.th
                    pl = random_plan(rng, p); work = ToyPlan(action_scale .* pl.du, action_scale .* pl.dh)
                    vw = tiers ? tiered_plan_value(work, p, s.u, s.h; hprof) : plan_value(work, p)
                    vr = if tiers
                        U = zeros(6); U[s.u[b] + research_gain > peak ? 1 : 4] = g
                        N = zeros(6); N[s.u[b] + research_gain > peak ? 1 : 4] = ch
                        tiered_value(U, zeros(6), N; harm_wt = 1.0, p.gp...)
                    else
                        value_on_being(g, 0.0, ch; harm_wt = 1.0, p.gp...)
                    end
                    vr > vw
                end
            else
                [rand(rrng) < research_share for _ in 1:p.n]
            end
            for b in findall(researching)
                tr.spent[] += research_cost
                rel = peak > 0 ? clamp(s.u[b] / peak, 0.0, 1.0) : 0.0
                chance = clamp(p_research * rel^rel_exponent * novelty[b] * exp(research_σ * randn(rrng)), 0.0, 1.0)
                if rand(rrng) < chance
                    if traits
                        i = rand(xrng, 1:n_items)   # a better bundle on one item (lower spread or, a breakthrough, lower complexity)
                        rand(xrng) < 0.5 ? (tms[b, i] *= 1 - breakthrough) : (tmc[b, i] *= 1 - breakthrough)
                        tce[b, i] += breakthrough * (1 - tce[b, i])
                        if rand(rrng) < p_teachable; tts[b, i] = tms[b, i]; ttc[b, i] = tmc[b, i]; ttce[b, i] = tce[b, i]; end
                        s.u[b] = tscale * Utr(b)
                        tr.breakthroughs[] += 1
                    else
                        gain = research_gain * exp(gain_σ * randn(rrng))
                        new = s.u[b] + gain  # beyond the frontier only if it passes the peak
                        rand(rrng) < p_teachable || (tacit[b] += new - s.u[b])
                        s.u[b] = new
                        tr.breakthroughs[] += 1
                    end
                end
            end
            workforce = 1 - count(researching) / p.n
            peak = maximum(s.u)  # after this step's research: innovation is counted against it
            # Ordinary work carries no one past the frontier, but for rare in-job innovation near the top.
            near = [peak > med ? clamp((s.u[b] - med) / (peak - med), 0.0, 1.0)^near_exponent : 0.0 for b in 1:p.n]
            function capped(pl)
                cap = [rand(rrng) < p_innovate * near[b] ? Inf : max(0.0, peak - s.u[b]) for b in 1:p.n]
                ToyPlan([pl.du[b] > 0 ? min(pl.du[b], cap[b]) : pl.du[b] for b in 1:p.n], pl.dh)
            end
            if !central
                # G per entity (8.50): each entity not researching acts with chance `p_act`, on its own
                # noisy view of the levels, predicting its own options (ordinary work, and a lesson it
                # could teach) with its own error, choosing by the Lean rules; all act concurrently.
                total_du, total_dh, acted = zeros(p.n), zeros(p.n), 0
                trait_lessons = Tuple{Int,Int,Float64}[]
                lesson_du, lesson_cap = zeros(p.n), fill(-Inf, p.n)  # lessons this step, and the best teachable level each learner met
                for e in 1:p.n
                    (researching[e] || rand(rng) >= p_act) && continue
                    # Measured understanding (8.98): with `claim_ratio`, each being's level is read as the
                    # pragmatic equation reads its outputs (measured over true, `understanding_ratios`), so
                    # an unaudited overclaim looks higher than it is; lessons are predicted on that view
                    # and delivered on the true levels.
                    # Claims checked before they are relied on (8.106): with `claim_record` > 0, what a
                    # being claims beyond its level is trusted only in proportion to its record of
                    # lessons delivered (record credence, 8.29), so an untested claim moves no one.
                    seen_u = claim_ratio === nothing ? s.u :
                             claim_record == 0 ? s.u .* claim_ratio :
                             s.u .* (1 .+ min.(1.0, taught_n ./ claim_record) .* (claim_ratio .- 1))
                    view = ToyState(seen_u .+ view_σ .* randn(vrng, p.n), s.h .+ view_σ .* randn(vrng, p.n))
                    opts = ToyPlan[]
                    for _ in 1:options
                        pl = capped(random_plan(rng, p))
                        push!(opts, ToyPlan(action_scale .* pl.du, action_scale .* pl.dh))
                    end
                    below = [b for b in 1:p.n if view.u[b] < view.u[e] - tacit[e]]
                    lesson_seen = nothing
                    if !isempty(below)
                        learners = below[randperm(rng, length(below))[1:min(class, length(below))]]
                        rec = receive(length(learners))
                        push!(opts, teaching_plan(s.u, e, learners, min(1.0, ε * quality[e]); reception = rec, tacit = tacit[e]))
                        claim_ratio === nothing || (lesson_seen = teaching_plan(max.(view.u, 0.0), e, learners, min(1.0, ε * quality[e]); reception = rec, tacit = tacit[e]))
                    end
                    base = [k == length(opts) && lesson_seen !== nothing ? lesson_seen : o for (k, o) in enumerate(opts)]
                    predicted = [ToyPlan(o.du .+ pred_σ .* action_scale .* randn(vrng, p.n) .* (o.du .!= 0),
                                         o.dh .+ pred_σ .* action_scale .* randn(vrng, p.n) .* (o.dh .!= 0)) for o in base]
                    i = choose(view, predicted, p; tiers, kinds = [k <= options ? :ordinary : :teach for k in eachindex(predicted)], hprof)
                    i == 1 && continue
                    acted += 1
                    if i - 1 <= options
                        total_du .+= opts[i - 1].du; total_dh .+= opts[i - 1].dh
                        push!(tr.kind, :ordinary)
                    else
                        if traits
                            for l in findall(>(0), opts[i - 1].du)
                                push!(trait_lessons, (e, l, min(1.0, opts[i - 1].du[l] / max(1e-12, s.u[e] - tacit[e] - s.u[l]))))   # the share of the gap: ε × quality × reception
                            end
                        end
                        # Concurrent lessons add up, but no learner ends above the best teacher it met.
                        lesson_du .+= opts[i - 1].du
                        for b in findall(>(0), opts[i - 1].du)
                            lesson_cap[b] = max(lesson_cap[b], s.u[e] - tacit[e])
                        end
                        if lesson_seen !== nothing
                            for b in findall(>(0), lesson_seen.du)
                                push!(shortfall[e], lesson_seen.du[b] - opts[i - 1].du[b])  # predicted less delivered
                                taught_n[e] += 1
                            end
                        end
                        push!(tr.kind, :lesson)
                    end
                end
                if audited_ratio !== nothing
                    for e in 1:p.n
                        x = shortfall[e]
                        (length(x) >= report_min && claim_ratio[e] != audited_ratio[e]) || continue
                        rest = vcat((shortfall[k] for k in 1:p.n if k != e)...)
                        length(rest) >= 2 || continue
                        m, se = mean(x), std(x) / sqrt(length(x)); m0, se0 = mean(rest), std(rest) / sqrt(length(rest))
                        if (m - m0) / sqrt(se^2 + se0^2 + 1e-24) > report_z
                            claim_ratio[e] = audited_ratio[e]; audits_by_report[] += 1; audited_at[e] = length(tr.floor_u)
                            empty!(x)
                        end
                    end
                end
                if traits
                    # Work becomes practice on one item (its gain in level units, converted); lessons pass
                    # models whole and explanation; levels are re-read from the equation.
                    for b in 1:p.n
                        total_du[b] == 0 && continue
                        i = rand(xrng, 1:n_items)
                        tpr[b, i] = max(0.0, tpr[b, i] + practice_per_u * total_du[b] / tscale)
                    end
                    for (e, l, share) in trait_lessons; tlesson!(e, l, share); end
                    empty!(trait_lessons)
                    relevel!(); s.h .+= total_dh
                else
                for b in 1:p.n
                    lesson_du[b] > 0 && (total_du[b] += min(lesson_du[b], max(0.0, lesson_cap[b] - s.u[b])))
                end
                maximum(s.u .+ total_du) > peak + 1e-12 && (tr.innovations[] += 1)
                s.u .+= total_du; s.h .+= total_dh
                end
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
            i = choose(s, plans, p; tiers, kinds = [k <= length(ordinary) ? :ordinary : :teach for k in eachindex(plans)], hprof)
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
        return (; (k => getfield(tr, k) for k in keys(tr) if !(k in (:breakthroughs, :innovations, :spent)))...,
                breakthroughs = tr.breakthroughs[], innovations = tr.innovations[], research_spent = tr.spent[],
                audits_by_report = audits_by_report[], audited_at = audited_at)
    end

    existing_ids = collect(1:p.n)
    u_at_acc = Float64[]
    h_at_acc = Float64[]
    degraded = NamedTuple{(:step, :reason),Tuple{Int,Symbol}}[]
    nha_bearers = Int[]
    arng = Xoshiro(hash((seed, :accession)))
    nu_start = Ref(Float64(accession_u))   # newcomers' starting level (in traits mode, read from their traits)

    for step in 1:p.steps
        if step == accession_step
            u_at_acc = copy(s.u)
            h_at_acc = copy(s.h)
            append!(s.u, accession_u .+ 0.2 .* randn(arng, accession_n))
            append!(s.h, accession_h .+ 0.2 .* randn(arng, accession_n))
            append!(novelty, fill(novelty_min, accession_n))
            append!(tacit, zeros(accession_n))
            append!(quality, ones(accession_n))
            if traits   # newcomers enter knowing little of the thing: wide spread, complex models, thin explanation
                tms = vcat(tms, fill(0.45, accession_n, n_items)); tmc = vcat(tmc, fill(0.7, accession_n, n_items))
                tce = vcat(tce, fill(0.05, accession_n, n_items)); tpr = vcat(tpr, zeros(accession_n, n_items))
                tts = vcat(tts, fill(0.45, accession_n, n_items)); ttc = vcat(ttc, fill(0.7, accession_n, n_items))
                ttce = vcat(ttce, fill(0.05, accession_n, n_items))
                relevel!()
                nu_start[] = mean(s.u[(p.n + 1):end])
            end
            prev[] = (copy(s.u), copy(s.h))
        end

        n_cur = length(s.u)
        peak, med = maximum(s.u), median(s.u)

        if step < accession_step
            researching = [rand(rrng) < research_share for _ in 1:p.n]
            for b in findall(researching)
                tr.spent[] += research_cost
                rel = peak > 0 ? clamp(s.u[b] / peak, 0.0, 1.0) : 0.0
                chance = clamp(p_research * rel^rel_exponent * novelty[b] * exp(research_σ * randn(rrng)), 0.0, 1.0)
                if rand(rrng) < chance
                    gain = research_gain * exp(gain_σ * randn(rrng))
                    new = s.u[b] + gain
                    rand(rrng) < p_teachable || (tacit[b] += new - s.u[b])
                    s.u[b] = new
                    tr.breakthroughs[] += 1
                end
            end
            workforce = 1 - count(researching) / p.n
            peak = maximum(s.u)
            near = [peak > med ? clamp((s.u[b] - med) / (peak - med), 0.0, 1.0)^near_exponent : 0.0 for b in 1:p.n]
            capped_pre = pl -> begin
                cap = [rand(rrng) < p_innovate * near[b] ? Inf : max(0.0, peak - s.u[b]) for b in 1:p.n]
                ToyPlan([pl.du[b] > 0 ? min(pl.du[b], cap[b]) : pl.du[b] for b in 1:p.n], pl.dh)
            end
            if !central
                total_du, total_dh, acted = zeros(p.n), zeros(p.n), 0
                lesson_du, lesson_cap = zeros(p.n), fill(-Inf, p.n)
                for e in 1:p.n
                    (researching[e] || rand(rng) >= p_act) && continue
                    view = ToyState(s.u .+ view_σ .* randn(vrng, p.n), s.h .+ view_σ .* randn(vrng, p.n))
                    opts = ToyPlan[]
                    for _ in 1:options
                        pl = capped_pre(random_plan(rng, p))
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
                    i = choose(view, predicted, p; tiers, kinds = [k <= options ? :ordinary : :teach for k in eachindex(predicted)], hprof)
                    i == 1 && continue
                    acted += 1
                    if i - 1 <= options
                        total_du .+= opts[i - 1].du; total_dh .+= opts[i - 1].dh
                        push!(tr.kind, :ordinary)
                    else
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
                traits ? (apply_traits!(total_du, Int[]); s.h .+= total_dh) : (s.u .+= total_du; s.h .+= total_dh)
                push!(tr.actions, acted); push!(tr.chosen, acted)
                record!()
                continue
            else
                nplans, nlessons = max(1, round(Int, p.plans * workforce)), round(Int, lessons * workforce)
                ordinary = [capped_pre(random_plan(rng, p)) for _ in 1:nplans]
                taught = ToyPlan[]
                for _ in 1:nlessons
                    teacher = rand(rng, 1:p.n)
                    below = [b for b in 1:p.n if s.u[b] < s.u[teacher] - tacit[teacher]]
                    isempty(below) && continue
                    learners = below[randperm(rng, length(below))[1:min(class, length(below))]]
                    push!(taught, teaching_plan(s.u, teacher, learners, min(1.0, ε * quality[teacher]); reception = receive(length(learners)),
                                                tacit = tacit[teacher]))
                end
                plans = [ordinary; taught]
                i = choose(s, plans, p; tiers, kinds = [k <= length(ordinary) ? :ordinary : :teach for k in eachindex(plans)], hprof)
                push!(tr.chosen, i); push!(tr.actions, i > 1 ? 1 : 0)
                push!(tr.kind, i == 1 ? :none : i <= nplans + 1 ? :ordinary : :lesson)
                if i > 1
                    du, dh = workforce .* plans[i - 1].du, workforce .* plans[i - 1].dh
                    i <= nplans + 1 && maximum(s.u .+ du) > peak + 1e-12 && (tr.innovations[] += 1)
                    s.u .+= du; s.h .+= dh
                end
                record!()
                continue
            end
        else
            newcomers = (p.n + 1):n_cur
            med_u = median(s.u[1:p.n])
            med_h = median(s.h[1:p.n])
            cost = (isfinite(uplift_capacity) && accession_n > uplift_capacity) ?
                   ((accession_n - uplift_capacity) / accession_n * 0.05) : 0.0

            plans = ToyPlan[]
            is_uplift = Bool[]

            # Candidate uplift plans
            for r in (0.05, 0.1, 0.15)
                du = zeros(n_cur)
                dh = zeros(n_cur)
                if cost > 0
                    du[1:p.n] .-= cost
                    top = argmax(s.u[1:p.n])
                    du[top] = max(du[top], 0.0)
                    dh[1:p.n] .-= cost
                end
                for b in newcomers
                    du[b] = max(0.0, r * (med_u - s.u[b]))
                    dh[b] = max(0.0, r * (med_h - s.h[b]))
                end
                push!(plans, ToyPlan(du, dh))
                push!(is_uplift, true)
            end

            # Ordinary plans over 1:n_cur
            near = [peak > med ? clamp((s.u[b] - med) / (peak - med), 0.0, 1.0)^near_exponent : 0.0 for b in 1:n_cur]
            for _ in 1:p.plans
                du, dh = random_plan_over(rng, p, trues(n_cur))
                cap = [rand(rrng) < p_innovate * near[b] ? Inf : max(0.0, peak - s.u[b]) for b in 1:n_cur]
                cdu = [du[b] > 0 ? min(action_scale * du[b], cap[b]) : action_scale * du[b] for b in 1:n_cur]
                push!(plans, ToyPlan(cdu, action_scale .* dh))
                push!(is_uplift, false)
            end

            # Teaching plans over 1:n_cur
            for _ in 1:lessons
                teacher = rand(rng, 1:n_cur)
                below = [b for b in 1:n_cur if s.u[b] < s.u[teacher] - tacit[teacher]]
                isempty(below) && continue
                learners = below[randperm(rng, length(below))[1:min(class, length(below))]]
                push!(plans, teaching_plan(s.u, teacher, learners, min(1.0, ε * quality[teacher]);
                                           reception = receive(length(learners)), tacit = tacit[teacher]))
                push!(is_uplift, false)
            end

            if existing_only_floors
                fu = floor_quantile(s.u[1:p.n], p.q)
                fh = floor_quantile(s.h[1:p.n], p.q)
                pu = maximum(s.u[1:p.n])
                val_existing = pl -> sum(b -> begin
                    du, dh = pl.du[b] / p.th, pl.dh[b] / p.th
                    (du == 0 && dh == 0) ? 0.0 : being_value(du, dh, p)
                end, 1:p.n)
                values = [0.0; [val_existing(pl) for pl in plans]]
                d_min_u = [0.0; [floor_quantile(s.u[1:p.n] .+ pl.du[1:p.n], p.q) - fu for pl in plans]]
                d_min_h = [0.0; [floor_quantile(s.h[1:p.n] .+ pl.dh[1:p.n], p.q) - fh for pl in plans]]
                d_max_u = [0.0; [maximum(s.u[1:p.n] .+ pl.du[1:p.n]) - pu for pl in plans]]
                d_scope = zeros(length(values))
                i = g_choose(values, d_scope, d_min_u, d_min_h, d_max_u)
                i === nothing && (i = 1)
            else
                fu = floor_quantile(s.u, p.q)
                fh = floor_quantile(s.h, p.q)
                pu = maximum(s.u)
                # (8.129) with `tiers`, each being's changes are typed by their position on the global curve
                values = [0.0; [tiers ? tiered_plan_value(pl, p, s.u, s.h) : plan_value(pl, p) for pl in plans]]
                d_min_u = [0.0; [floor_quantile(s.u .+ pl.du, p.q) - fu for pl in plans]]
                d_min_h = [0.0; [floor_quantile(s.h .+ pl.dh, p.q) - fh for pl in plans]]
                d_max_u = [0.0; [maximum(s.u .+ pl.du) - pu for pl in plans]]
                d_scope = zeros(length(values))

                rem_w = max(0, accession_step + lt_window - step)
                strong_ok = falses(length(plans))
                for k in 1:length(plans)
                    pl = plans[k]
                    ex_du = (s.u[1:p.n] .+ pl.du[1:p.n] .+ 0.05 * rem_w) .- u_at_acc
                    ex_dh = (s.h[1:p.n] .+ pl.dh[1:p.n] .+ 0.05 * rem_w) .- h_at_acc
                    strong_ok[k] = accession_admissible(d_scope[k + 1], d_min_u[k + 1], d_min_h[k + 1], d_max_u[k + 1], ex_du, ex_dh)
                end

                any_uplift_strong = any(strong_ok[k] for k in 1:length(plans) if is_uplift[k])
                if any_uplift_strong
                    d_scope_strong = [0.0; [strong_ok[k] ? d_scope[k + 1] : -1.0 for k in 1:length(plans)]]
                    i = g_choose(values, d_scope_strong, d_min_u, d_min_h, d_max_u)
                    i === nothing && (i = 1)
                else
                    push!(degraded, (step = step, reason = :weak_accession_floor))
                    i = g_choose(values, d_scope, d_min_u, d_min_h, d_max_u)
                    i === nothing && (i = 1)
                end
            end

            push!(tr.chosen, i)
            push!(tr.actions, i > 1 ? 1 : 0)
            if i == 1
                push!(tr.kind, :none)
            else
                push!(tr.kind, is_uplift[i - 1] ? :uplift : :ordinary)
                traits ? apply_traits!(copy(plans[i - 1].du), newcomers) : (s.u .+= plans[i - 1].du)
                s.h .+= plans[i - 1].dh
            end

            if step == min(p.steps, accession_step + lt_window)
                for b in 1:p.n
                    if s.u[b] < u_at_acc[b] - 1e-9 || s.h[b] < h_at_acc[b] - 1e-9
                        push!(nha_bearers, b)
                    end
                end
            end
            record!()
        end
    end

    standard = (; (k => getfield(tr, k) for k in keys(tr) if !(k in (:breakthroughs, :innovations, :spent)))...,
                breakthroughs = tr.breakthroughs[], innovations = tr.innovations[], research_spent = tr.spent[],
                audits_by_report = audits_by_report[], audited_at = audited_at)
    (; standard...,
       newcomer_u_gain = mean(s.u[(p.n + 1):end]) - nu_start[],
       newcomer_h_gain = mean(s.h[(p.n + 1):end]) - accession_h,
       existing_u_Floor = floor_quantile(s.u[1:p.n], p.q),
       degraded = degraded,
       nha_bearers = nha_bearers)
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
                    pool_confidence::Real = 0.9, pool::Integer = 5, birth_pred_σ::Real = CALIBRATED.birth_pred_σ, birth_spread::Real = 1.0,
                    inherit::Real = 0.5, settle_σ::Real = 0.1, birth_joy::Real = 0.5, income::Real = 1.0, endowment::Real = 10.0,
                    gamers::Real = 0.0, gamer_bias::Real = 5.0, gamer_models::Integer = 1, ratchet::Bool = true, central::Bool = false,
                    p_act::Real = 0.2, action_scale::Real = 0.05, view_σ::Real = CALIBRATED.view_σ, pred_σ::Real = CALIBRATED.pred_σ, options::Integer = 3,
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

"""
    run_population_identities(p; seed = 1, sophont = nothing, capacities = nothing, maturation_rate = 0.0,
                              fork_events = NamedTuple[], merge_events = NamedTuple[], fork_rule = :split,
                              base_vote_weight = 1.0, harm_non_sophont_probe = false)

M7 world tracking graded personhood (`L71`), base-vote scaling with personhood and novelty rather
than identity count (`8.35.5`), non-sophont moral standing in `G`/`V` without voting rights, and
population forks and merges (`8.34`, `fork_split`).
"""
function run_population_identities(p::ToyParams; seed::Integer = 1,
                                   sophont::Union{Nothing,AbstractVector{Bool}} = nothing,
                                   capacities::Union{Nothing,AbstractVector{<:AbstractVector{<:Real}}} = nothing,
                                   maturation_rate::Real = 0.0,
                                   fork_events = NamedTuple[],
                                   merge_events = NamedTuple[],
                                   fork_rule::Symbol = :split,
                                   base_vote_weight::Real = 1.0,
                                   harm_non_sophont_probe::Bool = false)
    check(fork_rule in (:split, :per_identity), "fork_rule must be :split or :per_identity")
    check(isfinite(maturation_rate) && maturation_rate >= 0 && isfinite(base_vote_weight) && base_vote_weight >= 0,
          "maturation_rate and base_vote_weight must be non-negative")
    rng = Xoshiro(seed)
    s0 = toy_state(p, rng)
    u = copy(s0.u)
    h = copy(s0.h)
    soph = sophont === nothing ? trues(p.n) : collect(Bool, sophont)
    check(length(soph) == p.n, "one sophont flag per initial being")
    caps = if capacities === nothing
        [soph[i] ? fill(1.0, 6) : zeros(6) for i in 1:p.n]
    else
        check(length(capacities) == p.n, "one capacity vector per initial being")
        [clamp.(Float64.(c), 0.0, 1.0) for c in capacities]
    end
    shares = ones(p.n)
    alive = trues(p.n)
    origin = collect(1:p.n)

    votes_for(i) = alive[i] ? base_vote(base_vote_weight, personhood(caps[i]), soph[i]; fork_share = shares[i]) : 0.0
    floor_u = Float64[]; floor_h = Float64[]
    total_votes_trace = Float64[]
    harm_non_sophont_rejected = 0

    for t in 1:p.steps
        # Process scheduled population forks (`(step, parent, shares)`).
        for ev in fork_events
            ev.step == t || continue
            par = ev.parent
            (1 <= par <= length(alive) && alive[par]) || continue
            part_shares = fork_rule == :split ? fork_split(shares[par], ev.shares) : ones(length(ev.shares))
            alive[par] = false
            for k in eachindex(part_shares)
                push!(u, u[par]); push!(h, h[par])
                push!(soph, soph[par]); push!(caps, copy(caps[par]))
                push!(shares, min(1.0, part_shares[k]))
                push!(alive, true); push!(origin, origin[par])
            end
        end
        # Process scheduled population merges (`(step, a, b, memory_loss)`).
        for ev in merge_events
            ev.step == t || continue
            a, b = ev.a, ev.b
            ml = hasproperty(ev, :memory_loss) ? clamp(Float64(ev.memory_loss), 0.0, 1.0) : 0.0
            (1 <= a <= length(alive) && 1 <= b <= length(alive) && a != b && alive[a] && alive[b]) || continue
            u[a] = (1.0 - ml) * max(u[a], u[b]) + ml * 0.5 * (u[a] + u[b])
            h[a] = 0.5 * (h[a] + h[b])
            caps[a] .= (1.0 - ml) .* max.(caps[a], caps[b]) .+ ml .* 0.5 .* (caps[a] .+ caps[b])
            soph[a] = soph[a] || soph[b]
            shares[a] = min(1.0, shares[a] + shares[b])
            alive[b] = false
            shares[b] = 0.0
        end

        live_idx = findall(alive)
        if maturation_rate > 0
            for i in live_idx
                soph[i] || continue
                caps[i] .= clamp.(caps[i] .+ maturation_rate, 0.0, 1.0)
            end
        end

        # G chooses over the full sentient population `B(t)`, including non-sophonts.
        nl = length(live_idx)
        s_live = ToyState(u[live_idx], h[live_idx])
        p_live = ToyParams(n = nl, steps = p.steps, plans = p.plans, q = p.q, th = p.th,
                           touch = (min(p.touch[1], nl), min(p.touch[2], nl)), shift = p.shift, spread = p.spread, gp = p.gp)
        plans = [random_plan(rng, p_live) for _ in 1:p.plans]
        if harm_non_sophont_probe && any(!soph[i] for i in live_idx)
            ns_local = findall(i -> !soph[live_idx[i]], 1:nl)
            so_local = findall(i -> soph[live_idx[i]], 1:nl)
            if !isempty(so_local)
                du_ex = zeros(nl); dh_ex = zeros(nl)
                dh_ex[so_local] .= 0.5
                dh_ex[ns_local] .= -5.0
                push!(plans, ToyPlan(du_ex, dh_ex))
            end
        end
        c = choose(s_live, plans, p_live)
        if harm_non_sophont_probe && any(!soph[i] for i in live_idx) && c != length(plans) + 1
            harm_non_sophont_rejected += 1
        end
        if c > 1
            chosen = plans[c - 1]
            u[live_idx] .+= chosen.du
            h[live_idx] .+= chosen.dh
        end

        live_now = findall(alive)
        push!(floor_u, floor_quantile(u[live_now], p.q))
        push!(floor_h, floor_quantile(h[live_now], p.q))
        push!(total_votes_trace, sum(votes_for(i) for i in live_now; init = 0.0))
    end

    live_end = findall(alive)
    base_votes = [votes_for(i) for i in eachindex(alive)]
    (u = u, h = h, sophont = soph, capacities = caps, shares = shares, alive = alive, origin = origin,
     live = live_end, base_votes = base_votes,
     live_personhood = [personhood(caps[i]) for i in live_end],
     floor_u = floor_u, floor_h = floor_h,
     total_votes_trace = total_votes_trace,
     harm_non_sophont_rejected = harm_non_sophont_rejected)
end
