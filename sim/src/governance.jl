# Governance rules (L113 BfDm, L114 LqdBfDm), computed by the Lean reference (`Voting_weight_ref`,
# `accumulate_capped_ref`; `Governance.Democracy`, `Governance.Incentives`).

"""
    voting_weight(base, expertise_weight, shares, reps, impact_weight, impact; optional_below) -> (weight, optional)

A vote's weight (L113): base + expertise weight × Σ share × reputation over the decision's domain
profile + impact weight × impact; voting is optional below the threshold.
"""
function voting_weight(base::Real, expertise_weight::Real, shares, reps, impact_weight::Real, impact::Real;
                       optional_below::Real)
    check(profile_valid(shares) && length(reps) == length(shares) && all(isfinite, reps), "a decision profile and one reputation per domain")
    check(all(x -> isfinite(x) && x >= 0, (base, expertise_weight, impact_weight, impact, optional_below)), "weights non-negative")
    w = ccall(sym(:bf_voting_weight), Float64, (Float64, Float64, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64),
              base, expertise_weight, floatarray(shares), floatarray(reps), impact_weight, impact, optional_below)
    opt = ccall(sym(:bf_vote_optional), UInt8, (Float64, Float64, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64),
                base, expertise_weight, floatarray(shares), floatarray(reps), impact_weight, impact, optional_below) == 1
    w, opt
end

"Capped delegation (L114): a delegate accepts each further weight only while its total is under the cap."
function accumulate_capped(cap::Real, current::Real, weights)
    check(all(isfinite, (cap, current)) && all(w -> isfinite(w) && w >= 0, weights), "finite cap and non-negative weights")
    ccall(sym(:bf_accumulate_capped), Float64, (Float64, Float64, Ptr{Cvoid}), cap, current, floatarray(weights))
end

"Domain-relative expertise ([R] 8.22.1; L113): reputations as shares of the domain's total (summing to 1), for vote weights only (8.48)."
function relative_reputation(reps)
    check(all(r -> isfinite(r) && r >= 0, reps), "reputations must be non-negative")
    lean_floats(ccall(sym(:bf_relative_reputation), Ptr{Cvoid}, (Ptr{Cvoid},), floatarray(reps)))
end
