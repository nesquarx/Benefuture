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

"The reputation a vote earns once its outcome is apparent (Lean `vote_reputation_ref`; 8.29, 8.48)."
function vote_reputation(right::Bool, value::Real, scale::Real, voters::Integer, held::Real, total::Real)
    check(all(isfinite, (value, scale, held, total)) && total > 0 && voters >= 1 && held >= 0, "finite inputs, positive total and voters")
    ccall(sym(:bf_vote_reputation), Float64, (UInt8, Float64, Float64, Float64, Float64, Float64), right, value, scale, voters, held, total)
end

"Whether a delegate is audited out (Lean `audited_out_ref`; L114)."
function audited_out(rights::Integer, records::Integer; min_records::Integer, threshold::Real)
    check(0 <= rights <= records && min_records >= 1 && 0 <= threshold <= 1, "rights within records, positive minimum, threshold in [0, 1]")
    ccall(sym(:bf_audited_out), UInt8, (Float64, Float64, Float64, Float64), rights, records, min_records, threshold) == 1
end

"A source's weight in deliberation from its record's rolling net (Lean `source_weight_ref`; 8.43)."
function source_weight(rights::Real, wrongs::Real)
    check(isfinite(rights) && isfinite(wrongs) && rights >= 0 && wrongs >= 0, "rights and wrongs non-negative")
    ccall(sym(:bf_source_weight), Float64, (Float64, Float64), rights, wrongs)
end

"A source's weight as heard by a listener (Lean `heard_ref`; 8.44): down and across, up only for novel input."
heard(source::Real, own::Real, novel::Bool) = ccall(sym(:bf_heard), Float64, (Float64, Float64, UInt8), source, own, novel)

"The ledgers' negative share (Lean `neg_share_ref`; 8.42.1)."
function neg_share(gains::Real, losses::Real)
    check(isfinite(gains) && isfinite(losses) && gains >= 0 && losses >= 0, "gains and losses non-negative")
    ccall(sym(:bf_neg_share), Float64, (Float64, Float64), gains, losses)
end

"One record's credence score, unclipped (Lean `credence_score_ref`; 8.36)."
function credence_score(credence::Real, outcome::Real)
    check(0 <= credence <= 1 && 0 <= outcome <= 1, "credence and outcome in [0, 1]")
    ccall(sym(:bf_credence_score), Float64, (Float64, Float64), credence, outcome)
end
