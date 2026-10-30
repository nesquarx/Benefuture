# Toy model M7, second rung: teaching (understanding is shared, not moved; conjecture B17).
#
# World (this file): research raises one frontier being's understanding by `research_gain`, and only
# research extends the frontier (ordinary plans are capped at the current peak);
# teaching raises learners towards a teacher's level by a share `ε` of the gap, the teacher keeping
# all of its own. G chooses among research, teaching and ordinary plans by the Lean rules (`choose`).

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
Benefuture spends on research) research instead of working: the ordinary plans and lessons on offer
shrink in proportion, and each attempt costs `research_cost` from the commons. An attempt by being b
succeeds with a very noisy chance, `p_research` × (u_b / peak)² × novelty_b × log-normal(`research_σ`)
(novelty a per-being trait, world), and raises b by a log-normal `research_gain` (new understanding
beyond the frontier only where it passes the peak); the work done by the rest scales with their
share of time; the gain
is teachable with chance `p_teachable`, else tacit (it stays with b). Lessons (`lessons`, one to many,
teachers at any level, reception varying with `reception_σ`) pass on teachers' teachable understanding.
Ordinary work carries no one past the peak, except by in-job innovation: a chance `p_innovate` ×
((u_b − median) / (peak − median))⁴, near the top only. G chooses among ordinary plans and lessons by
the Lean rules. Records the Goal's success pattern, the top decile's share, research spending and
breakthroughs.
"""
function run_m7(p::ToyParams; seed, ε::Real, research_share::Real = 0.1, research_gain::Real = 2.0, research_σ::Real = 1.0,
                p_research::Real = 0.05, p_teachable::Real = 0.5, research_cost::Real = 1.0, p_innovate::Real = 0.01,
                class::Integer = 10, lessons::Integer = 3, reception_σ::Real = 0.5, central::Bool = false,
                p_act::Real = 0.2, action_scale::Real = 0.05, view_σ::Real = 0.2, pred_σ::Real = 0.2, options::Integer = 3)
    check(0 <= ε <= 1 && 0 <= research_share < 1 && all(x -> isfinite(x) && x >= 0, (research_gain, research_σ, research_cost, reception_σ)) &&
          0 <= p_research <= 1 && 0 <= p_teachable <= 1 && 0 <= p_innovate <= 1 && class >= 1 && lessons >= 0 &&
          0 <= p_act <= 1 && all(x -> isfinite(x) && x >= 0, (action_scale, view_σ, pred_σ)) && options >= 1,
          "shares and chances in [0, 1] (research share below 1), gains, scatters and cost non-negative, class positive")
    rng = Xoshiro(seed)
    trng, rrng = Xoshiro(hash((seed, :reception))), Xoshiro(hash((seed, :research)))
    vrng = Xoshiro(hash((seed, :views)))  # entities' views and predictions
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
                    push!(opts, teaching_plan(s.u, e, learners, ε; reception = exp.(reception_σ .* randn(trng, length(learners))),
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
            push!(taught, teaching_plan(s.u, teacher, learners, ε; reception = exp.(reception_σ .* randn(trng, length(learners))),
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
