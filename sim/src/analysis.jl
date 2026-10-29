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
