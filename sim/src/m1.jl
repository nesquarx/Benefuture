# Toy model M1: M0 seen through measurement.
#
# World (this file): the true levels and plans of M0 are latent. Established markers observe
# current levels and realised changes with independent noise. Competing metric models predict
# each plan's changes with their own bias and noise; G decides on the adopted model's predictions
# and the markers' view of current levels, then the true plan is applied. Each model is scored
# on the chosen plan against the markers, and the model with the best rolling score is adopted.
# Rules (Lean): value, harm weight, floors, G's choice, model scoring and adoption.
# Plans and initial levels draw from the same random stream as M0; measurement from its own, so
# perfect models and exact markers reproduce M0 exactly.

"A metric model's systematic bias and noise when predicting a plan's changes."
struct MetricModel
    bias::Float64
    σ::Float64
    function MetricModel(bias::Real, σ::Real)
        check(isfinite(bias) && isfinite(σ) && σ >= 0, "bias must be finite and σ non-negative")
        new(bias, σ)
    end
end

"M1 parameters: the M0 world, the competing models, marker noise and the scoring window."
struct M1Params
    toy::ToyParams
    models::Vector{MetricModel}
    marker_σ::Float64
    window::Int
    function M1Params(toy::ToyParams, models, marker_σ::Real, window::Int)
        check(!isempty(models), "there must be at least one metric model")
        check(isfinite(marker_σ) && marker_σ >= 0, "marker noise must be non-negative")
        check(window >= 1, "the scoring window must be at least one step")
        new(toy, collect(MetricModel, models), marker_σ, window)
    end
end

touched(plan::ToyPlan) = (plan.du .!= 0) .| (plan.dh .!= 0)

"A model's prediction of a plan: its bias and noise on the beings the plan touches."
function predict(rng::AbstractRNG, m::MetricModel, plan::ToyPlan)
    mask = touched(plan)
    n = length(mask)
    ToyPlan(mask .* (plan.du .+ m.bias .+ m.σ .* randn(rng, n)),
            mask .* (plan.dh .+ m.bias .+ m.σ .* randn(rng, n)))
end

observe(rng::AbstractRNG, xs, σ) = xs .+ σ .* randn(rng, length(xs))

"""
    run_m1(p; seed, central = true, p_act = 0.25, action_scale = 0.1, view_σ = 0.0) -> NamedTuple

Run M1. `floor_u`/`floor_h` are the true floors; `obs_floor_*` the floors the markers report.
With `central = false` (Item 2 D1), G is distributed per entity: each step each entity acts with
probability `p_act` on its own noisy view, considering scaled plans, and all chosen plans apply concurrently.
"""
function run_m1(p::M1Params; seed, central::Bool = true, p_act::Real = 0.25, action_scale::Real = 0.1, view_σ::Real = 0.0)
    check(0 <= p_act <= 1 && all(x -> isfinite(x) && x >= 0, (action_scale, view_σ)),
          "p_act in [0, 1] and scales non-negative")
    t = p.toy
    rng = Xoshiro(seed)                      # world: the same stream as M0
    mrng = Xoshiro(hash((seed, :measurement)))
    vrng = central ? nothing : Xoshiro(hash((seed, :views)))
    s = toy_state(t, rng)
    k = length(p.models)
    history = [Float64[] for _ in 1:k]
    rolling() = [isempty(h) ? 0.0 : mean(@view h[max(1, end - p.window + 1):end]) for h in history]
    adopted = mm_adopt(rolling())
    tr = (floor_u = Float64[], floor_h = Float64[], obs_floor_u = Float64[], obs_floor_h = Float64[],
          mean_h = Float64[], peak_u = Float64[], latent_obs_gap = Float64[],
          chosen = Int[], value = Float64[], adopted = Int[], adopted_score = Float64[], best_score = Float64[])
    function record!(obs)
        fu, fh = floor_quantile(s.u, t.q), floor_quantile(s.h, t.q)
        ou, oh = floor_quantile(obs.u, t.q), floor_quantile(obs.h, t.q)
        push!(tr.floor_u, fu); push!(tr.floor_h, fh); push!(tr.obs_floor_u, ou); push!(tr.obs_floor_h, oh)
        push!(tr.mean_h, mean(s.h)); push!(tr.peak_u, maximum(s.u))
        push!(tr.latent_obs_gap, max(abs(fu - ou), abs(fh - oh)))
    end
    obs = ToyState(observe(mrng, s.u, p.marker_σ), observe(mrng, s.h, p.marker_σ))
    record!(obs)
    for _ in 1:t.steps
        if central
            plans = [random_plan(rng, t) for _ in 1:t.plans]
            preds = [[predict(mrng, m, plan) for plan in plans] for m in p.models]
            i = choose(obs, preds[adopted], t)
            push!(tr.chosen, i)
            push!(tr.value, i == 1 ? 0.0 : plan_value(preds[adopted][i - 1], t))
            if i > 1
                plan = plans[i - 1]
                mask = touched(plan)
                realised = [observe(mrng, plan.du[mask], p.marker_σ); observe(mrng, plan.dh[mask], p.marker_σ)]
                for j in 1:k
                    pj = preds[j][i - 1]
                    push!(history[j], mm_score([pj.du[mask]; pj.dh[mask]], realised))
                end
                s.u .+= plan.du
                s.h .+= plan.dh
            end
        else
            total_du, total_dh, acted = zeros(t.n), zeros(t.n), 0
            n_opts = max(1, t.plans ÷ 4)
            for _ in 1:t.n
                rand(rng) < p_act || continue
                view = ToyState(obs.u .+ view_σ .* randn(vrng, t.n), obs.h .+ view_σ .* randn(vrng, t.n))
                opts = [random_plan(rng, t) for _ in 1:n_opts]
                scaled = [ToyPlan(action_scale .* pl.du, action_scale .* pl.dh) for pl in opts]
                preds = [[predict(mrng, m, plan) for plan in scaled] for m in p.models]
                i = choose(view, preds[adopted], t)
                i == 1 && continue
                acted += 1
                plan = scaled[i - 1]
                mask = touched(plan)
                realised = [observe(mrng, plan.du[mask], p.marker_σ); observe(mrng, plan.dh[mask], p.marker_σ)]
                for j in 1:k
                    pj = preds[j][i - 1]
                    push!(history[j], mm_score([pj.du[mask]; pj.dh[mask]], realised))
                end
                total_du .+= plan.du
                total_dh .+= plan.dh
            end
            s.u .+= total_du
            s.h .+= total_dh
            push!(tr.chosen, acted)
            push!(tr.value, plan_value(ToyPlan(total_du, total_dh), t))
        end
        scores = rolling()
        adopted = mm_adopt(scores)
        push!(tr.adopted, adopted); push!(tr.adopted_score, scores[adopted]); push!(tr.best_score, maximum(scores))
        obs = ToyState(observe(mrng, s.u, p.marker_σ), observe(mrng, s.h, p.marker_σ))
        record!(obs)
    end
    tr
end
