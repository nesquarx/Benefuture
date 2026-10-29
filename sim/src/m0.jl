# Toy model M0: the oversimplified first rung of the model ladder.
#
# World (this file): a fixed population with levels of understanding (u) and happiness (h); each
# step offers a menu of random plans, each touching a random share of beings; measurement is
# perfect, so assessed changes are the true changes in units of the threshold; every loss counts
# as passing harm. Rules (Lean, through the bridge): value on a being, harm weight, floors and
# G's choice. Novelty, reality's scope and the distribution term D are absent here.

using Random, Statistics

"Parameters of M0. `q` is the floor quantile, `th` the threshold of significance."
struct ToyParams
    n::Int
    steps::Int
    plans::Int
    q::Float64
    th::Float64
    touch::Tuple{Float64,Float64}
    shift::Float64
    spread::Float64
    gp::NamedTuple{(:α, :β, :γ, :λ, :qp, :qm),NTuple{6,Float64}}
end

function ToyParams(; n = 200, steps = 100, plans = 20, q = 0.1, th = 1.0, touch = (0.05, 0.3),
                   shift = 0.5, spread = 1.0, gp = (α = 0.8, β = 0.6, γ = 0.4, λ = 0.5, qp = 1.1, qm = 1.5))
    check(n >= 1, "n must be at least 1")
    check(steps >= 0 && plans >= 0, "steps and plans must be non-negative")
    check(0 <= q <= 1, "q must lie in [0, 1]")
    check(th > 0, "threshold must be positive")
    check(0 <= touch[1] <= touch[2] <= 1, "touch must be an interval within [0, 1]")
    check(shift >= 0 && spread >= 0, "shift and spread must be non-negative")
    ToyParams(n, steps, plans, q, th, touch, shift, spread, NamedTuple{(:α, :β, :γ, :λ, :qp, :qm)}(Float64.(values(gp))))
end

mutable struct ToyState
    u::Vector{Float64}
    h::Vector{Float64}
end

toy_state(p::ToyParams, rng::AbstractRNG) = ToyState(5 .+ randn(rng, p.n), 5 .+ randn(rng, p.n))
toy_state(p::ToyParams; seed) = toy_state(p, Xoshiro(seed))

"A plan's change to every being's understanding and happiness."
struct ToyPlan
    du::Vector{Float64}
    dh::Vector{Float64}
end

function random_plan(rng::AbstractRNG, p::ToyParams)
    share = p.touch[1] + rand(rng) * (p.touch[2] - p.touch[1])
    mask = rand(rng, p.n) .< share
    μu, μh = p.shift * randn(rng), p.shift * randn(rng)
    ToyPlan(mask .* (μu .+ p.spread .* randn(rng, p.n)), mask .* (μh .+ p.spread .* randn(rng, p.n)))
end

"V on one being of assessed changes `du`, `dh` (in units of the threshold); every loss is passing harm."
function being_value(du::Real, dh::Real, p::ToyParams)
    passing = 4  # tier index of passing harm in HARM_SCHEDULE
    tiers = [(i == passing ? abs(min(du, 0)) + abs(min(dh, 0)) : 0.0, w) for (i, w) in enumerate(HARM_SCHEDULE)]
    value_on_being(du, dh, 0.0; harm_wt = harm_weight(tiers; λ = p.gp.λ), p.gp...)
end

"Σ V over the beings a plan touches; in M0 every loss is passing harm."
function plan_value(plan::ToyPlan, p::ToyParams)
    total = 0.0
    for b in eachindex(plan.du)
        du, dh = plan.du[b] / p.th, plan.dh[b] / p.th
        du == 0 && dh == 0 && continue
        total += being_value(du, dh, p)
    end
    total
end

"""
    assessed_value(du, dh, p)

An outcome on one being: its understanding and happiness changes assessed against not acting
(As, L48, ex post: measured less counterfactual, here no change, over the threshold) and valued
together with V, so their synergy stays in the outcome.
"""
function assessed_value(du::Real, dh::Real, p::ToyParams)
    du == 0 && dh == 0 && return 0.0
    being_value(assess(0.0, 0.0, du; t = 1.0, t0 = 0.0, th = p.th), assess(0.0, 0.0, dh; t = 1.0, t0 = 0.0, th = p.th), p)
end

"""
    choose(state, plans, p) -> Int

G over inaction and `plans`: 1 for inaction, k + 1 for `plans[k]`.
"""
function choose(s::ToyState, plans, p::ToyParams; harms = nothing)
    for plan in plans
        check(length(plan.du) == length(s.u) && length(plan.dh) == length(s.h), "plan must cover every being")
    end
    # Freedom first (L135): with each plan's predicted harm by kind, (irreparable, irreversible,
    # long-term, passing, time loss, confidence), an impermissible plan never reaches G.
    if harms !== nothing
        check(length(harms) == length(plans), "one harm classification per plan")
        ok = [fr_permissible(h[1:5]...; confidence = h[6]) for h in harms]
        keep = findall(ok)
        i = choose(s, plans[keep], p)
        return i == 1 ? 1 : keep[i - 1] + 1
    end
    fu, fh, pu = floor_quantile(s.u, p.q), floor_quantile(s.h, p.q), maximum(s.u)
    values = [0.0; [plan_value(plan, p) for plan in plans]]
    d_min_u = [0.0; [floor_quantile(s.u .+ plan.du, p.q) - fu for plan in plans]]
    d_min_h = [0.0; [floor_quantile(s.h .+ plan.dh, p.q) - fh for plan in plans]]
    d_max_u = [0.0; [maximum(s.u .+ plan.du) - pu for plan in plans]]
    i = g_choose(values, zeros(length(values)), d_min_u, d_min_h, d_max_u)
    i === nothing && error("inaction must always be admissible")
    i
end

"""
    run_m0(p; seed) -> NamedTuple

Run M0 for `p.steps` steps. Level series have `steps + 1` entries; `chosen` and `value` one per step.
"""
function run_m0(p::ToyParams; seed)
    rng = Xoshiro(seed)
    s = toy_state(p, rng)
    tr = (floor_u = Float64[], floor_h = Float64[], median_u = Float64[], median_h = Float64[],
          mean_h = Float64[], peak_u = Float64[], chosen = Int[], value = Float64[])
    record!() = begin
        push!(tr.floor_u, floor_quantile(s.u, p.q)); push!(tr.floor_h, floor_quantile(s.h, p.q))
        push!(tr.median_u, median(s.u)); push!(tr.median_h, median(s.h))
        push!(tr.mean_h, mean(s.h)); push!(tr.peak_u, maximum(s.u))
    end
    record!()
    for _ in 1:p.steps
        plans = [random_plan(rng, p) for _ in 1:p.plans]
        i = choose(s, plans, p)
        push!(tr.chosen, i)
        push!(tr.value, i == 1 ? 0.0 : plan_value(plans[i - 1], p))
        if i > 1
            s.u .+= plans[i - 1].du
            s.h .+= plans[i - 1].dh
        end
        record!()
    end
    tr
end

"Conj_FloorsRise over a trace: across every window of length w, neither floor falls."
floors_rise(tr; w::Int = 1) =
    all(tr.floor_u[t] <= tr.floor_u[t + w] && tr.floor_h[t] <= tr.floor_h[t + w] for t in 1:(length(tr.floor_u) - w))
