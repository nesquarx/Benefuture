# Domain profiles, attribution and relevance decay (L22, L101), computed by the Lean reference
# (`profile_valid_ref`, `attribute_ref`, `decay_rate_for_ref`). Every action carries a profile
# over leaf domains; reputation and currency are kept per domain and never cross between them.

"A domain profile is valid when its shares are non-negative and sum to one."
function profile_valid(shares)
    all(isfinite, shares) || return false
    ccall(sym(:bf_profile_valid), UInt8, (Ptr{Cvoid},), floatarray(shares)) == 1
end

"""
    attribute(shares, cc, pos, neg) -> (pos_by_domain, neg_by_domain)

What an action attributes to each leaf domain: share × causal contribution × contribution, for
the positive and negative contributions separately.
"""
function attribute(shares, cc::Real, pos::Real, neg::Real)
    check(profile_valid(shares), "shares must be a partition of unity")
    check(isfinite(cc) && 0 <= cc <= 1, "causal contribution must lie in [0, 1]")
    check(isfinite(pos) && isfinite(neg) && pos >= 0 && neg >= 0, "contributions must be non-negative")
    f(s, c) = ccall(sym(:bf_attribute), Float64, (Float64, Float64, Float64), s, cc, c)
    ([f(s, pos) for s in shares], [f(s, neg) for s in shares])
end

"Rate at which a signed contribution's relevance decays: λpos for gains, λneg for losses."
function decay_rate_for(signed::Real; λpos::Real, λneg::Real)
    check(all(isfinite, (signed, λpos, λneg)) && λpos >= 0 && λneg >= 0, "rates must be finite and non-negative")
    ccall(sym(:bf_decay_rate_for), Float64, (Float64, Float64, Float64), signed, λpos, λneg)
end

"""
    classify(dists; threshold, temperature) -> profile

An action's profile as currency metric models assign it, from the distances between its measured
causal signature and each domain's: one share per domain plus StandCoin last, which takes the
whole profile when no domain is within `threshold` (a new scenario, flagged for adjudication).
"""
function classify(dists; threshold::Real, temperature::Real)
    check(!isempty(dists) && all(d -> isfinite(d) && d >= 0, dists), "distances must be non-negative")
    check(isfinite(threshold) && threshold >= 0 && isfinite(temperature) && temperature > 0,
          "threshold must be non-negative and temperature positive")
    [ccall(sym(:bf_classify_at), Float64, (Ptr{Cvoid}, Float64, Float64, Csize_t),
           floatarray(dists), threshold, temperature, i) for i in 0:length(dists)]
end

"Accumulation threshold of a domain balance: `base` plus `factor` × positive relevance."
function accumulation_threshold(base::Real, factor::Real, relevance::Real)
    check(!isnan(base) && base >= 0 && isfinite(factor) && factor >= 0 && isfinite(relevance),
          "base and factor must be non-negative, relevance finite")
    ccall(sym(:bf_accumulation_threshold), Float64, (Float64, Float64, Float64), base, factor, relevance)
end

"The part of a balance above its accumulation threshold, to be reinvested in the domain."
function overflow(balance::Real, threshold::Real)
    check(isfinite(balance) && !isnan(threshold), "balance must be finite")
    ccall(sym(:bf_overflow), Float64, (Float64, Float64), balance, threshold)
end
