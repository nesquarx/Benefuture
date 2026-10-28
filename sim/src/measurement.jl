# Metric-model scoring and adoption (L49), computed by the Lean reference
# (`mm_score_ref`, `mm_adopt_ref`).

"""
    mm_score(pred, obs)

Accuracy of a metric model: minus the mean squared error of its predictions against
observations; 0 is perfect, and 0 when there is nothing to score.
"""
function mm_score(pred, obs)
    check(length(pred) == length(obs), "predictions and observations must pair up")
    check(all(isfinite, pred) && all(isfinite, obs), "entries must be finite")
    ccall(sym(:bf_mm_score), Float64, (Ptr{Cvoid}, Ptr{Cvoid}), floatarray(pred), floatarray(obs))
end

"""
    mm_adopt(scores) -> Int

Index (1-based) of the metric model adopted: the first of highest score.
"""
function mm_adopt(scores)
    check(!isempty(scores), "there must be at least one model")
    check(all(isfinite, scores), "scores must be finite")
    Int(ccall(sym(:bf_mm_adopt), UInt64, (Ptr{Cvoid},), floatarray(scores))) + 1
end
