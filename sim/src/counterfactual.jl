# Competing counterfactual outcome estimators for historical decision replay (`docs/DATA.md` §16a, §16d B8).
# Each estimator returns an interval and a pre-period fit score (`truth_level`), never a bare point.
# Where competing methods disagree, `combine_counterfactuals` reports both the credence-weighted
# combination and the full cross-method spread (`spread_low`, `spread_high`).

t_Factor(df::Integer, z::Real = 2.0) = z * t_inflation(max(1, df))
t_Factor(df::Real, z::Real = 2.0) = t_Factor(round(Int, df), z)
const t_factor = t_Factor

"""
    difference_in_differences(treated_pre, treated_post, control_pre, control_post; z = 2.0)

Difference-in-differences counterfactual estimate of the treatment effect on the treated unit,
with Student-t inflated standard error from pre- and post-intervention fluctuations and a
pre-period parallel-trends fit score (`truth_level`).
"""
function difference_in_differences(treated_pre::AbstractVector{<:Real},
                                   treated_post::AbstractVector{<:Real},
                                   control_pre::AbstractVector{<:Real},
                                   control_post::AbstractVector{<:Real};
                                   z::Real = 2.0)
    check(!isempty(treated_pre) && !isempty(treated_post) &&
          length(treated_pre) == length(control_pre) &&
          length(treated_post) == length(control_post),
          "pre and post series must be non-empty and matched in length")
    pre_gaps = Float64.(treated_pre) .- Float64.(control_pre)
    post_gaps = Float64.(treated_post) .- Float64.(control_post)
    pre_mean = mean(pre_gaps)
    effs = post_gaps .- pre_mean
    est = mean(effs)
    # Variance combines post-period variation and pre-period baseline uncertainty
    se_pre = length(pre_gaps) > 1 ? std(pre_gaps) / sqrt(length(pre_gaps)) : 0.0
    se_post = length(effs) > 1 ? std(effs) / sqrt(length(effs)) : 0.0
    se = hypot(se_pre, se_post)
    df = max(1, length(pre_gaps) + length(effs) - 2)
    hw = t_Factor(df, z) * se
    # Parallel trends pre-fit: drift in pre_gaps relative to scale
    scale = max(std(Float64.(control_pre); corrected = false), 1.0)
    pre_rmse = length(pre_gaps) > 1 ? std(pre_gaps) : 0.0
    truth_level = clamp(1.0 / (1.0 + pre_rmse / scale), 0.01, 0.99)
    return (
        method = :difference_in_differences,
        estimate = est,
        se = se,
        low = est - hw,
        high = est + hw,
        truth_level = truth_level
    )
end

"""
    synthetic_control(treated_pre, treated_post, donors_pre, donors_post; z = 2.0, iters = 400)

Abadie, Diamond & Hainmueller (2010) synthetic control estimator. Finds simplex weights `w >= 0`,
`sum(w) == 1` over donor columns of `donors_pre` (`T_pre × J`) that minimise pre-intervention
mean squared error against `treated_pre` via Frank–Wolfe conditional gradient steps, then scores
the pre-period fit (`truth_level`) and estimates post-intervention counterfactual differences
with donor-leave-one-out / jackknife intervals.
"""
function synthetic_control(treated_pre::AbstractVector{<:Real},
                           treated_post::AbstractVector{<:Real},
                           donors_pre::AbstractMatrix{<:Real},
                           donors_post::AbstractMatrix{<:Real};
                           z::Real = 2.0,
                           iters::Int = 400)
    t_pre, n_donors = size(donors_pre)
    t_post, n_donors_post = size(donors_post)
    check(t_pre == length(treated_pre) && t_post == length(treated_post) &&
          n_donors == n_donors_post && n_donors >= 1,
          "donor matrices must match treated pre/post lengths and have at least one donor")
    y_pre = Float64.(treated_pre)
    y_post = Float64.(treated_post)
    X_pre = Float64.(donors_pre)
    X_post = Float64.(donors_post)

    function fit_simplex(X, y)
        m = size(X, 2)
        w = fill(1.0 / m, m)
        for k in 1:iters
            resid = X * w .- y
            grad = X' * resid
            j_min = argmin(grad)
            γ = 2.0 / (k + 2.0)
            w .*= (1.0 - γ)
            w[j_min] += γ
        end
        return w
    end

    w = fit_simplex(X_pre, y_pre)
    synth_pre = X_pre * w
    synth_post = X_post * w
    gaps_post = y_post .- synth_post
    est = mean(gaps_post)

    pre_rmse = sqrt(mean((y_pre .- synth_pre) .^ 2))
    scale = max(std(y_pre; corrected = false), 1.0)
    truth_level = clamp(1.0 / (1.0 + pre_rmse / scale), 0.01, 0.99)

    # Leave-one-donor-out jackknife + post-period variation for interval
    jack = Float64[]
    if n_donors >= 2
        for j in 1:n_donors
            keep = [i for i in 1:n_donors if i != j]
            wj = fit_simplex(X_pre[:, keep], y_pre)
            push!(jack, mean(y_post .- X_post[:, keep] * wj))
        end
    end
    se_jack = length(jack) > 1 ? std(jack) : 0.0
    se_time = length(gaps_post) > 1 ? std(gaps_post) / sqrt(length(gaps_post)) : pre_rmse
    se = hypot(se_jack, se_time)
    df = max(1, t_post + n_donors - 2)
    hw = t_Factor(df, z) * se

    return (
        method = :synthetic_control,
        estimate = est,
        se = se,
        low = est - hw,
        high = est + hw,
        truth_level = truth_level,
        weights = w
    )
end

"""
    combine_counterfactuals(estimates)

Combines competing counterfactual estimates weighted by their `truth_level` (credence from pre-period
fit), while preserving the full cross-method disagreement spread (`spread_low`, `spread_high`) per
`docs/DATA.md` §16a.
"""
function combine_counterfactuals(estimates::AbstractVector)
    check(!isempty(estimates), "at least one counterfactual estimate is required")
    ws = [max(Float64(e.truth_level), 1e-6) for e in estimates]
    sw = sum(ws)
    combined = sum(ws[i] * Float64(estimates[i].estimate) for i in eachindex(estimates)) / sw
    spread_low = minimum(Float64(e.low) for e in estimates)
    spread_high = maximum(Float64(e.high) for e in estimates)
    method_min = minimum(Float64(e.estimate) for e in estimates)
    method_max = maximum(Float64(e.estimate) for e in estimates)
    return (
        estimate = combined,
        spread_low = spread_low,
        spread_high = spread_high,
        method_spread = method_max - method_min,
        truth_level = sw / length(estimates),
        n_methods = length(estimates)
    )
end

