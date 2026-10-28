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

# The domain tree (author ruling, BACKPROPAGATION 8.3). Nodes are numbered from 1, the root
# (StandCoin); `parents[1] == 0` and every other node's parent comes before it.

function check_tree(parents)
    check(!isempty(parents) && parents[1] == 0 && all(1 <= parents[i] < i for i in 2:length(parents)),
          "parents must form a tree rooted at node 1, each parent before its children")
end

"""
Take a reference to a Lean object, as `lean_inc_ref` in `lean.h` does: the count is the first
32-bit field, positive for single-threaded objects, zero for persistent ones (never counted).
Arrays freshly returned to Julia are single-threaded; a shared (multi-threaded) one is refused.
"""
function lean_inc!(a::Ptr{Cvoid})
    rc = unsafe_load(Ptr{Int32}(a))
    rc < 0 && error("multi-threaded Lean object: not expected from a fresh result")
    rc > 0 && unsafe_store!(Ptr{Int32}(a), rc + Int32(1))
    a
end

"An array returned by Lean, read (each read consumes a reference, taken first) and released."
function lean_floats(a::Ptr{Cvoid})
    n = ccall(sym(:bf_fa_size), Csize_t, (Ptr{Cvoid},), lean_inc!(a))
    xs = [ccall(sym(:bf_fa_get), Float64, (Ptr{Cvoid}, Csize_t), lean_inc!(a), i) for i in 0:(n - 1)]
    ccall(sym(:bf_fa_drop), UInt8, (Ptr{Cvoid},), a)
    xs
end

lean_parents(parents) = floatarray([i == 1 ? 0 : parents[i] - 1 for i in eachindex(parents)])

"""
    classify_tree(parents, dists; thresholds, temperature) -> stopping shares

Classification by descent from the root: `dists[i]` is the distance from an action's measured
causal signature to node `i`'s; `thresholds[k]` matches children of nodes at depth `k - 1`.
Returns each node's share of the action where descent stopped: a leaf when recognised, a branch
when stuck there, the root when no domain recognises it.
"""
function classify_tree(parents, dists; thresholds, temperature::Real)
    check_tree(parents)
    check(length(dists) == length(parents) && all(d -> isfinite(d) && d >= 0, dists), "one non-negative distance per node")
    check(length(thresholds) >= 1 && all(t -> isfinite(t) && t >= 0, thresholds), "thresholds must be non-negative")
    check(isfinite(temperature) && temperature > 0, "temperature must be positive")
    lean_floats(ccall(sym(:bf_classify_tree), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Float64),
                      lean_parents(parents), floatarray(dists), floatarray(thresholds), temperature))
end

"Each node's share moved to its nearest eligible ancestor; the root (StandCoin) is always eligible."
function fallback(parents, eligible, shares)
    check_tree(parents)
    check(length(eligible) == length(shares) == length(parents), "one eligibility and one share per node")
    lean_floats(ccall(sym(:bf_fallback), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
                      lean_parents(parents), floatarray(Float64.(eligible)), floatarray(shares)))
end

"Each node's total over its subtree: its own amount plus all its subdomains'."
function subtree_sum(parents, own)
    check_tree(parents)
    check(length(own) == length(parents) && all(isfinite, own), "one finite amount per node")
    lean_floats(ccall(sym(:bf_subtree_sum), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}), lean_parents(parents), floatarray(own)))
end

"Resource cost per unit by availability: `base` × capacity / available, exhaustion dear but finite."
function scarcity_cost(base::Real, available::Real, capacity::Real)
    check(isfinite(base) && base >= 0 && isfinite(available) && available >= 0 && isfinite(capacity) && capacity > 0,
          "base and availability must be non-negative, capacity positive")
    ccall(sym(:bf_scarcity_cost), Float64, (Float64, Float64, Float64), base, available, capacity)
end
