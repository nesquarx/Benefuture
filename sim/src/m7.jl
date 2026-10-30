# Toy model M7, second rung: teaching (understanding is shared, not moved; conjecture B17).
#
# World (this file): research raises one frontier being's understanding by `research_gain`, and only
# research extends the frontier (ordinary plans are capped at the current peak);
# teaching raises learners towards a teacher's level by a share `ε` of the gap, the teacher keeping
# all of its own. G chooses among research, teaching and ordinary plans by the Lean rules (`choose`).

"""
    teaching_plan(u, teacher, learners, ε; reception = ones) -> ToyPlan

A lesson, one to many: each learner below the teacher gains `ε` × its own `reception` of the gap to
the teacher's understanding, never passing the teacher; the teacher and everyone else are unchanged
(understanding is shared, not moved).
"""
function teaching_plan(u::AbstractVector, teacher::Integer, learners, ε::Real; reception = ones(length(learners)))
    check(0 <= ε <= 1 && 1 <= teacher <= length(u) && all(l -> 1 <= l <= length(u), learners), "ε in [0, 1], beings in range")
    check(length(reception) == length(learners) && all(r -> isfinite(r) && r >= 0, reception), "one non-negative reception per learner")
    du = zeros(length(u))
    for (l, r) in zip(learners, reception)
        l == teacher && continue
        gap = max(0.0, u[teacher] - u[l])
        du[l] = min(gap, ε * r * gap)
    end
    ToyPlan(du, zeros(length(u)))
end

"""
    run_m7(p; seed, ε, research_gain = 2.0, class = 10, lessons = 3, reception_σ = 0.5) -> NamedTuple

M0's world with research and teaching among each step's options: one research plan (a top-decile
being gains `research_gain`) and `lessons` lessons, each from a teacher at any level to a class of
up to `class` beings below it, each learner's reception drawn log-normally around 1 with scatter
`reception_σ` (world noise, its own stream). Records the Goal's success pattern and the top decile's
share of understanding (`top_share`).
"""
function run_m7(p::ToyParams; seed, ε::Real, research_gain::Real = 2.0, class::Integer = 10, lessons::Integer = 3,
                reception_σ::Real = 0.5)
    check(0 <= ε <= 1 && isfinite(research_gain) && research_gain >= 0 && class >= 1 && lessons >= 0 &&
          isfinite(reception_σ) && reception_σ >= 0, "ε in [0, 1], gain and scatter non-negative, class positive")
    rng = Xoshiro(seed)
    trng = Xoshiro(hash((seed, :reception)))
    s = toy_state(p, rng)
    tr = (floor_u = Float64[], floor_h = Float64[], median_u = Float64[], median_h = Float64[], peak_u = Float64[],
          worst_drop = Float64[], top_share = Float64[], chosen = Int[], kind = Symbol[])
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
        order = sortperm(s.u; rev = true)
        r = order[rand(rng, 1:max(1, p.n ÷ 10))]
        research = ToyPlan([b == r ? research_gain : 0.0 for b in 1:p.n], zeros(p.n))
        taught = ToyPlan[]
        for _ in 1:lessons
            teacher = rand(rng, 1:p.n)  # any level
            below = [b for b in 1:p.n if s.u[b] < s.u[teacher]]
            isempty(below) && continue
            learners = below[randperm(rng, length(below))[1:min(class, length(below))]]
            push!(taught, teaching_plan(s.u, teacher, learners, ε; reception = exp.(reception_σ .* randn(trng, length(learners)))))
        end
        # Ordinary work applies and spreads understanding but carries no one past the frontier:
        # only research extends it (a toy convention; M0's plans are level-independent).
        peak = maximum(s.u)
        ordinary = map(1:p.plans) do _
            pl = random_plan(rng, p)
            ToyPlan(min.(pl.du, max.(0.0, peak .- s.u)) .* (pl.du .> 0) .+ min.(pl.du, 0.0), pl.dh)
        end
        plans = [ordinary; research; taught]
        i = choose(s, plans, p)
        push!(tr.chosen, i)
        push!(tr.kind, i == 1 ? :none : i <= p.plans + 1 ? :ordinary : i == p.plans + 2 ? :research : :lesson)
        if i > 1
            s.u .+= plans[i - 1].du; s.h .+= plans[i - 1].dh
        end
        record!()
    end
    tr
end
