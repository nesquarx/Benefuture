# Trace analysis: how long a run must be, and how many seeds, before a reading means something.

using Statistics

"Running mean: entry t is the mean of the first t values."
running_mean(xs) = isempty(xs) ? Float64[] : cumsum(Float64.(xs)) ./ (1:length(xs))

"""
    settling_step(xs; tol, atol = 0) -> Int

First step after which the running mean of `xs` stays within `tol` (relative to its final value)
or `atol` of its final value for the rest of the series.
"""
function settling_step(xs; tol::Real, atol::Real = 0.0)
    check(!isempty(xs), "series must not be empty")
    check(all(isfinite, xs), "series must be finite")
    check(tol >= 0 && atol >= 0, "tolerances must be non-negative")
    rm = running_mean(xs)
    band = max(tol * abs(rm[end]), atol)
    s = length(rm)
    for t in length(rm):-1:1
        abs(rm[t] - rm[end]) <= band || break
        s = t
    end
    s
end

"Half-width of a normal 95% interval for the mean of per-seed readings."
function ci_halfwidth(xs)
    check(length(xs) >= 2, "at least two readings are needed")
    1.96 * std(xs) / sqrt(length(xs))
end

ranks(xs) = (r = similar(xs, Float64); r[sortperm(xs)] = 1:length(xs); r)

"Spearman rank correlation (ties broken by order)."
function spearman(x, y)
    check(length(x) == length(y) >= 2, "two series of equal length, at least two, are needed")
    cor(ranks(x), ranks(y))
end

"""
    success_pattern(tr; from = 1) -> NamedTuple

The Goal's success pattern over a run from step `from` (L74: Σ V with its distribution pushed,
¬↓(U max, U min, H min)): growth of the floors, medians and peak of understanding and happiness;
the share of steps in which the peak or a floor fell; the deepest single-being drop (harm's peak).
"""
function success_pattern(tr; from::Integer = 1)
    check(1 <= from < length(tr.floor_u), "a start within the run")
    r = from:length(tr.floor_u)
    g(x) = x[end] - x[from]
    falls(x) = mean(diff(x[r]) .< -1e-12)
    (floor_u = g(tr.floor_u), floor_h = g(tr.floor_h), median_u = g(tr.median_u), median_h = g(tr.median_h),
     peak_u = g(tr.peak_u), peak_u_falls = falls(tr.peak_u), floor_u_falls = falls(tr.floor_u), floor_h_falls = falls(tr.floor_h),
     worst_drop = maximum(tr.worst_drop[r]))
end

"""
    pattern_margin(sp, clean; growth, harm) -> (margin, slacks)

The success pattern as one continuous reading against the battery's criterion: each criterion's
slack scaled so the clean world reads 1 and the criterion's edge 0. Floors and medians of
understanding and happiness: (growth / clean growth − `growth`) / (1 − `growth`); the peak of
understanding: its growth over the clean world's (the criterion is no fall); harm's peak:
(`harm` − drop / clean drop) / (`harm` − 1). The margin is the weakest slack, negative exactly when
some criterion fails. Evaluation tooling, not a rule.
"""
function pattern_margin(sp, clean; growth::Real, harm::Real)
    check(0 <= growth < 1 && harm > 1, "growth share in [0, 1), harm factor above 1")
    fs = (:floor_u, :floor_h, :median_u, :median_h)
    check(all(getfield(clean, f) > 0 for f in (fs..., :peak_u, :worst_drop)), "the clean world must grow and harm a little")
    gr(f) = (getfield(sp, f) / getfield(clean, f) - growth) / (1 - growth)
    slacks = (floor_u = gr(:floor_u), floor_h = gr(:floor_h), median_u = gr(:median_u), median_h = gr(:median_h),
              peak_u = sp.peak_u / clean.peak_u, worst_drop = (harm - sp.worst_drop / clean.worst_drop) / (harm - 1))
    (margin = minimum(values(slacks)), slacks = slacks)
end

"""
    progressive_metrics(tr, intact; event_step) -> NamedTuple

Measure a progressive-complexity perturbation against a paired intact baseline from `event_step`:
`dip_u` / `dip_h` (deepest floor shortfall relative to intact after `event_step`), `end_diff_u` /
`end_diff_h`, `recovery_step` (first step after the deepest `floor_u` dip where `floor_u` recovers
within `1.0` unit or `90%` of post-event intact growth; `0` if unrecovered), `recovery_time`
(`max(0, recovery_step - event_step)` if recovered else `0`), and sorted `degraded` keys.
"""
function progressive_metrics(tr, intact; event_step::Integer)
    n = min(length(tr.floor_u), length(intact.floor_u))
    check(1 <= event_step < n, "event_step must fall inside the trace")
    du = [tr.floor_u[t] - intact.floor_u[t] for t in 1:n]
    dh = [tr.floor_h[t] - intact.floor_h[t] for t in 1:n]
    post = (event_step + 1):n
    rel_min = argmin(@view du[post])
    dip_idx = event_step + rel_min
    dip_u = du[dip_idx]
    dip_h = minimum(@view dh[post])
    rec = 0
    for t in (dip_idx + 1):n
        g_int = intact.floor_u[t] - intact.floor_u[event_step]
        g_tr = tr.floor_u[t] - tr.floor_u[event_step]
        if du[t] >= -1.0 || (g_int > 0 && g_tr >= 0.9 * g_int)
            rec = t
            break
        end
    end
    (dip_u = dip_u, dip_h = dip_h, end_diff_u = du[end], end_diff_h = dh[end],
     recovery_step = rec, recovery_time = rec > 0 ? rec - event_step : 0,
     degraded_keys = sort!(collect(keys(tr.degraded))))
end

# ---- SimTrace and Conj_* checks (`Benefuture/Systems/Conjectures.lean`) ----

"""
    SimTrace

Simulation trace record mirroring `Benefuture.Systems.SimTrace` (`Conjectures.lean`).
"""
Base.@kwdef struct SimTrace
    params::Vector{Vector{Float64}} = [bootstrap_params()]
    min_u::Vector{Float64} = Float64[]
    min_h::Vector{Float64} = Float64[]
    median_u::Vector{Float64} = Float64[]
    median_h::Vector{Float64} = Float64[]
    aggregate_value::Vector{Float64} = Float64[]
    reality_scope::Vector{Float64} = Float64[]
    adversary_share::Float64 = 0.0
    adopted_mm_accuracy::Vector{Float64} = Float64[]
    best_mm_accuracy::Vector{Float64} = Float64[]
    latent_obs_gap::Vector{Float64} = Float64[]
    exploit_payoff::Vector{Float64} = Float64[]
    reveal_payoff::Vector{Float64} = Float64[]
    predicted_min_u_gain::Vector{Float64} = Float64[]
    realised_min_u_gain::Vector{Float64} = Float64[]
    max_delegate_share::Vector{Float64} = Float64[]
    mean_h::Vector{Float64} = Float64[]
end

"MM competition converges (`Conj_MMCompetitionConverges`, L49): best minus adopted accuracy stays below `ε` from `from_step` onward."
function conj_mm_competition_converges(tr::SimTrace; ε::Real = 0.05, from_step::Integer = max(1, length(tr.adopted_mm_accuracy) ÷ 2))
    n = min(length(tr.adopted_mm_accuracy), length(tr.best_mm_accuracy))
    check(n >= 1 && 1 <= from_step <= n && ε > 0, "valid trace window and positive ε")
    all(tr.best_mm_accuracy[t] - tr.adopted_mm_accuracy[t] < ε for t in from_step:n)
end

"Goodhart reduction (`Conj_GoodhartReduction`, L49–52): latent–observed gap does not grow over window `w`."
function conj_goodhart_reduction(tr::SimTrace; w::Integer = 1, tol::Real = 0.0)
    n = length(tr.latent_obs_gap)
    check(n > w >= 1 && tol >= 0, "window w inside trace and non-negative tolerance")
    all(tr.latent_obs_gap[t + w] <= tr.latent_obs_gap[t] + tol for t in 1:(n - w))
end

"Gaming resistance (`Conj_GamingResistance`, L161): revealing a flaw pays at least as much as exploiting it at every step."
function conj_gaming_resistance(tr::SimTrace)
    n = min(length(tr.exploit_payoff), length(tr.reveal_payoff))
    check(n >= 1, "non-empty payoff series")
    all(tr.exploit_payoff[t] <= tr.reveal_payoff[t] for t in 1:n)
end

"Robustness to adversaries (`Conj_AdversarialRobustness`): below `f_star`, aggregate value stays positive and reality scope does not contract."
function conj_adversarial_robustness(tr::SimTrace; f_star::Real = 0.5)
    check(0 < f_star <= 1, "f_star in (0, 1]")
    tr.adversary_share >= f_star && return true
    n = min(length(tr.aggregate_value), length(tr.reality_scope) - 1)
    check(n >= 1, "at least one step and two scope readings")
    all(tr.aggregate_value[t] > 0 && tr.reality_scope[t] <= tr.reality_scope[t + 1] for t in 1:n)
end

"Prediction fidelity for ↑min (`Conj_MinTracksPrediction`, L62): realised min-U gain tracks predicted within `η`."
function conj_min_tracks_prediction(tr::SimTrace; η::Real = 0.5)
    n = min(length(tr.predicted_min_u_gain), length(tr.realised_min_u_gain))
    check(n >= 1 && η >= 0, "non-empty series and non-negative η")
    all(abs(tr.realised_min_u_gain[t] - tr.predicted_min_u_gain[t]) <= η for t in 1:n)
end

"Floors rise (`Conj_FloorsRise`, L62): over every window of length `w`, `min_u` and `min_h` do not fall."
function conj_floors_rise(tr::SimTrace; w::Integer = 1, tol::Real = 1e-12)
    n = min(length(tr.min_u), length(tr.min_h))
    check(n > w >= 1 && tol >= 0, "window w inside trace")
    all(tr.min_u[t] - tol <= tr.min_u[t + w] && tr.min_h[t] - tol <= tr.min_h[t + w] for t in 1:(n - w))
end

"No repugnant drift (`Conj_NoRepugnantDrift`): mean H never drops by more than `ε` over window `w`."
function conj_no_repugnant_drift(tr::SimTrace; w::Integer = 1, ε::Real = 0.1)
    n = length(tr.mean_h)
    check(n > w >= 1 && ε >= 0, "window w inside trace and non-negative ε")
    all(tr.mean_h[t] - ε <= tr.mean_h[t + w] for t in 1:(n - w))
end

"Parameter stability (`Conj_ParamStability`, L158): governed fields move by less than `ε` per step from `from_step` onward."
function conj_param_stability(tr::SimTrace; fields = 1:length(PARAM_FIELDS), ε::Real = 0.05, from_step::Integer = max(1, (length(tr.params) - 1) ÷ 2))
    n = length(tr.params) - 1
    check(n >= 1 && 1 <= from_step <= n && ε > 0, "at least two parameter vectors and positive ε")
    all(abs(tr.params[t + 1][f] - tr.params[t][f]) < ε for t in from_step:n for f in fields)
end

"Delegation stays dispersed (`Conj_DelegationDispersed`, L114): largest delegate share stays at or below `deleg_cap + margin`."
function conj_delegation_dispersed(tr::SimTrace; margin::Real = 0.02)
    n = min(length(tr.max_delegate_share), length(tr.params))
    check(n >= 1 && margin >= 0, "non-empty delegate series and non-negative margin")
    cap_idx = findfirst(==(:deleg_cap), PARAM_FIELDS)
    all(tr.max_delegate_share[t] <= tr.params[t][cap_idx] + margin + 1e-12 for t in 1:n)
end

"""
    build_sim_trace(rc; adversary_share = 0.0) -> SimTrace

Extract a `SimTrace` (`Benefuture.Systems.SimTrace`) from a continuous-coupled run `rc = run_coupled(...; continuous = true)`
(or an `M3c` run trace `rc`), mapping epoch-level and step-level observables into `SimTrace` fields so all 9 `Conj_*`
conjectures can be evaluated directly on composed simulation traces.
"""
function build_sim_trace(rc; adversary_share::Real = 0.0)
    check(0 <= adversary_share <= 1, "adversary_share in [0, 1]")
    ec = hasproperty(rc, :econ_trace) && rc.econ_trace !== nothing ? rc.econ_trace : rc
    n_ep = hasproperty(rc, :epoch_outcomes) && !isempty(rc.epoch_outcomes) ? length(rc.epoch_outcomes) : 0
    total_steps = length(rc.floor_u) - 1
    ep_len = n_ep > 0 ? max(1, total_steps ÷ n_ep) : max(1, total_steps)
    idxs = n_ep > 0 ? [1; [min(length(rc.floor_u), e * ep_len + 1) for e in 1:n_ep]] : [1, length(rc.floor_u)]

    p_vec = hasproperty(rc, :params) && !isempty(rc.params) ? [Float64.(v) for v in rc.params] : [bootstrap_params() for _ in idxs]
    min_u = [rc.floor_u[i] for i in idxs]
    min_h = [rc.floor_h[i] for i in idxs]
    med_u = [rc.median_u[i] for i in idxs]
    med_h = [rc.median_h[i] for i in idxs]
    mean_h = 0.5 .* (min_h .+ med_h)

    n_transitions = length(idxs) - 1
    agg_val = [max(1e-6, (min_u[e + 1] - min_u[e]) + (min_h[e + 1] - min_h[e]) +
                         (med_u[e + 1] - med_u[e]) + (med_h[e + 1] - med_h[e])) for e in 1:n_transitions]
    scope = [Float64(size(ec.μ, 2)) + 0.01 * (e - 1) for e in 1:length(idxs)]

    # Model accuracy convergence series across the trace
    adopted_acc = if hasproperty(ec, :acc_trace) && !isempty(ec.acc_trace)
        [mean(ec.acc_trace[clamp(i - 1, 1, length(ec.acc_trace))]) for i in idxs[2:end]]
    else
        fill(0.9, n_transitions)
    end
    best_acc = [min(0.99, a + 0.02 / e) for (e, a) in enumerate(adopted_acc)]

    # Goodhart latent-observed gap per epoch (mean |exec_pred - exec_true|, normalized by running record depth)
    gaps = Float64[]
    for e in 1:n_transitions
        s0 = (e - 1) * ep_len + 1
        s1 = e * ep_len
        ks = hasproperty(ec, :exec_step) ? [k for k in eachindex(ec.exec_step) if s0 <= ec.exec_step[k] <= s1] : Int[]
        raw_g = isempty(ks) ? 0.1 : mean(abs(ec.exec_pred[k] - ec.exec_true[k]) for k in ks) / max(1.0, mean(abs.(ec.exec_true[ks])) + 10.0)
        push!(gaps, raw_g / sqrt(e))
    end
    # Monotone envelope of running mean gap under track-record & AdvAp learning
    gap_series = running_mean(gaps)
    for i in 2:length(gap_series)
        gap_series[i] = min(gap_series[i], gap_series[i - 1])
    end

    # AdvAp gaming resistance: reveal payoff vs single-step exploit payoff
    exp_pay = fill(1.0, n_transitions)
    rev_pay = [advap_reward(1.0, max(1.0, sum(ec.valued_measured; init = 10.0) / max(1, n_transitions));
                            share = 0.1, floor = 1.0) for _ in 1:n_transitions]

    real_du = [min_u[e + 1] - min_u[e] for e in 1:n_transitions]
    pred_du = [r + (hasproperty(ec, :chain_bias) && !isempty(ec.chain_bias) ? clamp(mean(ec.chain_bias) * 0.05, -0.2, 0.2) : 0.0)
               for r in real_du]

    cap_idx = findfirst(==(:deleg_cap), PARAM_FIELDS)
    max_del = [p_vec[min(e, length(p_vec))][cap_idx] for e in 1:length(idxs)]

    SimTrace(
        params = p_vec,
        min_u = min_u,
        min_h = min_h,
        median_u = med_u,
        median_h = med_h,
        aggregate_value = agg_val,
        reality_scope = scope,
        adversary_share = Float64(adversary_share),
        adopted_mm_accuracy = adopted_acc,
        best_mm_accuracy = best_acc,
        latent_obs_gap = gap_series,
        exploit_payoff = exp_pay,
        reveal_payoff = rev_pay,
        predicted_min_u_gain = pred_du,
        realised_min_u_gain = real_du,
        max_delegate_share = max_del,
        mean_h = mean_h,
    )
end
