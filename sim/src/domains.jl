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

# Arrays returned by Lean (`bf_fa_size`, `bf_fa_get`, `bf_fa_drop`).

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
    lock(SYMS_LOCK) do
        n = ccall(sym(:bf_fa_size), Csize_t, (Ptr{Cvoid},), lean_inc!(a))
        xs = [ccall(sym(:bf_fa_get), Float64, (Ptr{Cvoid}, Csize_t), lean_inc!(a), i) for i in 0:(Int(n) - 1)]
        ccall(sym(:bf_fa_drop), UInt8, (Ptr{Cvoid},), a)
        xs
    end
end

# The domain network (Ontology.Domain [R]: leaves hold shares, parents are fuzzy sets of leaves
# with degrees μ, a parents × leaves matrix; BACKPROPAGATION 8.3, 8.4, 8.8). Shares are laid out
# as leaves, then parent residuals, then the root (StandCoin).

rowmajor(μ::AbstractMatrix) = vec(permutedims(μ))

"An action's membership in a parent: its signature's projection on the parent's, clamped to [0, 1]."
function projection_membership(sig, parent)
    check(length(sig) == length(parent) && all(isfinite, sig) && all(isfinite, parent), "signatures must match in length")
    ccall(sym(:bf_projection_membership), Float64, (Ptr{Cvoid}, Ptr{Cvoid}), floatarray(sig), floatarray(parent))
end

"""
    credence(predicted, uncertainty) -> probability

A model's credence that an action's assessed value is positive (Lean `credence_ref`; L84): its
predicted value over its own uncertainty, through the normal distribution function, within
[1 − `cap`, `cap`] (truth levels never reach 1; `cap` is a governed threshold).
"""
function credence(predicted::Real, uncertainty::Real; cap::Real = 0.99)
    check(isfinite(predicted) && !isnan(uncertainty) && uncertainty >= 0, "finite prediction, non-negative uncertainty")
    check(0.5 <= cap <= 1, "credence cap in [0.5, 1]")
    ccall(sym(:bf_credence), Float64, (Float64, Float64, Float64), predicted, uncertainty, cap)
end

"""
    decay_halflife(rate; ref_rate, ref_halflife, mute) -> steps

The half-life over which a domain's accuracy is averaged (Lean `decay_halflife_ref`; author ruling
8.85): `ref_halflife * (ref_rate / rate)^mute`; the reference with no transactions yet.
"""
function decay_halflife(rate::Real; ref_rate::Real, ref_halflife::Real, mute::Real)
    check(isfinite(rate) && rate >= 0 && ref_rate > 0 && ref_halflife > 0 && 0 <= mute <= 1, "rate ≥ 0, positive references, mute in [0, 1]")
    ccall(sym(:bf_decay_halflife), Float64, (Float64, Float64, Float64, Float64), rate, ref_rate, ref_halflife, mute)
end

"""
    decayed_accuracy(credences, outcomes, ages, h) -> accuracy

Accuracy as the quality of credences, each record weighted by 2^(−age/h) (Lean `decayed_accuracy_ref`; 8.85).
"""
function decayed_accuracy(credences, outcomes, ages, h::Real)
    check(length(credences) == length(outcomes) == length(ages) && h > 0, "one credence, outcome and age per record; positive half-life")
    ccall(sym(:bf_decayed_accuracy), Float64, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Float64),
          floatarray(collect(Float64, credences)), floatarray(collect(Float64, outcomes)), floatarray(collect(Float64, ages)), h)
end

"""
    decayed_mean_se(xs, ages, h) -> (mean, se)

Age-weighted mean and its standard error over the effective number of records (Lean `decayed_mean_se_ref`; 8.85).
"""
function decayed_mean_se(xs, ages, h::Real)
    check(length(xs) == length(ages) && h > 0, "one age per value; positive half-life")
    r = lean_floats(ccall(sym(:bf_decayed_mean_se), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Float64),
                          floatarray(collect(Float64, xs)), floatarray(collect(Float64, ages)), h))
    (r[1], r[2])
end

"""
    ratchet_bar(accuracies, bar; k, margin) -> bar

The ratchet on a domain's status bar (Lean `ratchet_bar_ref`; author ruling 8.84): when at least `k`
models clear the bar it rises to the `k`-th best accuracy less `margin`; it never falls.
"""
function ratchet_bar(accuracies, bar::Real; k::Integer, margin::Real)
    check(all(isfinite, accuracies) && 0 <= bar <= 1 && k >= 0 && 0 <= margin <= 1, "finite accuracies, bar and margin in [0, 1], k ≥ 0")
    ccall(sym(:bf_ratchet_bar), Float64, (Ptr{Cvoid}, Float64, Csize_t, Float64), floatarray(collect(Float64, accuracies)), bar, k, margin)
end

"""
    record_credence(predicted, errors; cap = 0.99) -> probability

A model's credence from its record (Lean `record_credence_ref`; [P], finding 8.58-c): the share of
its past value errors below its prediction, ties counting half, within [1 − `cap`, `cap`]; no record
is a coin toss. The normal `credence` over the errors' spread is its limiting case.
"""
function record_credence(predicted::Real, errors; cap::Real = 0.99)
    check(isfinite(predicted) && all(isfinite, errors), "a finite prediction and finite errors")
    check(0.5 <= cap <= 1, "credence cap in [0.5, 1]")
    ccall(sym(:bf_record_credence), Float64, (Float64, Ptr{Cvoid}, Float64), predicted, floatarray(collect(Float64, errors)), cap)
end

"""
    decayed_record_credence(predicted, errors, ages, h; cap = 0.99) -> probability

Time-decayed record credence (Lean `decayed_record_credence_ref`; 8.85, 8.58-c): age-weighted share
of past value errors below `predicted` under half-life `h`, within [1 − `cap`, `cap`].
"""
function decayed_record_credence(predicted::Real, errors, ages, h::Real; cap::Real = 0.99)
    check(isfinite(predicted) && length(errors) == length(ages) && all(isfinite, errors) && all(isfinite, ages) && h > 0,
          "finite prediction, matching errors and ages, positive half-life")
    check(0.5 <= cap <= 1, "credence cap in [0.5, 1]")
    ccall(sym(:bf_decayed_record_credence), Float64, (Float64, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64),
          predicted, floatarray(collect(Float64, errors)), floatarray(collect(Float64, ages)), h, cap)
end

"""
    decayed_rms(errors, ages, h) -> rms

Time-decayed root mean square of `errors` under half-life `h` (Lean `decayed_rms_ref`; 8.85).
"""
function decayed_rms(errors, ages, h::Real)
    check(length(errors) == length(ages) && all(isfinite, errors) && all(isfinite, ages) && h > 0,
          "matching finite errors and ages, positive half-life")
    ccall(sym(:bf_decayed_rms), Float64, (Ptr{Cvoid}, Ptr{Cvoid}, Float64),
          floatarray(collect(Float64, errors)), floatarray(collect(Float64, ages)), h)
end

"""
    choice_skill(credences, model_credences, outcomes) -> skill

A chooser's prediction skill over the domain's model (Lean `choice_skill_ref`; [P], 8.69): each
choice a prediction that its outcome (1 or 0) is good, scored 1 − Brier(chooser) / Brier(model);
0 for following the model, at most 1.
"""
function choice_skill(credences, model_credences, outcomes)
    check(length(credences) == length(model_credences) == length(outcomes), "one credence, model credence and outcome per choice")
    check(all(c -> 0 <= c <= 1, credences) && all(c -> 0 <= c <= 1, model_credences) && all(o -> o in (0, 1), outcomes),
          "credences in [0, 1], outcomes 0 or 1")
    ccall(sym(:bf_choice_skill), Float64, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
          floatarray(collect(Float64, credences)), floatarray(collect(Float64, model_credences)), floatarray(collect(Float64, outcomes)))
end

"""
    credence_accuracy(credences, outcomes) -> accuracy in [0, 1]

Accuracy as the quality of credences (Lean `credence_accuracy_ref`): 1 − Brier / 0.25; 0 is random
guessing, 1 perfect; outcomes are 1 (assessed value positive) or 0.
"""
function credence_accuracy(credences, outcomes)
    check(length(credences) == length(outcomes) && all(c -> 0 <= c <= 1, credences) && all(o -> o in (0, 1), outcomes),
          "one credence in [0, 1] per outcome of 0 or 1")
    ccall(sym(:bf_credence_accuracy), Float64, (Ptr{Cvoid}, Ptr{Cvoid}), floatarray(credences), floatarray(outcomes))
end

"""
    classify_network(parent_mem, leaf_dists, μ; parent_threshold, μ_min, leaf_threshold, temperature)

An action's shares by descent: matched parents (membership ≥ `parent_threshold`), their member
leaves (μ ≥ `μ_min`) by closeness, the remainder stuck at the matched parents, or at the root.
"""
function classify_network(parent_mem, leaf_dists, μ::AbstractMatrix; parent_threshold::Real, μ_min::Real,
                          leaf_threshold::Real, temperature::Real)
    check(size(μ) == (length(parent_mem), length(leaf_dists)), "μ must be parents × leaves")
    check(all(m -> isfinite(m) && 0 <= m <= 1, parent_mem) && all(m -> isfinite(m) && 0 <= m <= 1, μ), "memberships lie in [0, 1]")
    check(all(d -> isfinite(d) && d >= 0, leaf_dists), "distances must be non-negative")
    check(0 < parent_threshold <= 1 && 0 <= μ_min <= 1 && isfinite(leaf_threshold) && leaf_threshold >= 0 &&
          isfinite(temperature) && temperature > 0, "thresholds in range and temperature positive")
    lean_floats(ccall(sym(:bf_classify_network), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64, Float64),
                      floatarray(parent_mem), floatarray(leaf_dists), floatarray(rowmajor(μ)),
                      parent_threshold, μ_min, leaf_threshold, temperature))
end

"Shares moved from ineligible currencies: leaves to eligible parents by μ, otherwise to the root."
function fallback_network(μ::AbstractMatrix, leaf_ok, parent_ok, shares)
    np, nl = size(μ)
    check(length(leaf_ok) == nl && length(parent_ok) == np && length(shares) == nl + np + 1, "one flag per node, one share per slot")
    check(profile_valid(shares), "shares must be a partition of unity")
    lean_floats(ccall(sym(:bf_fallback_network), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
                      floatarray(rowmajor(μ)), floatarray(Float64.(leaf_ok)), floatarray(Float64.(parent_ok)), floatarray(shares)))
end

"An amount aggregated at a parent: Σ μ(leaf) × amount(leaf)."
function aggregate_at_parent(μ_row, amounts)
    check(length(μ_row) == length(amounts) && all(isfinite, amounts), "one amount per leaf")
    ccall(sym(:bf_aggregate_at_parent), Float64, (Ptr{Cvoid}, Ptr{Cvoid}), floatarray(μ_row), floatarray(amounts))
end

"Fuzzy subsethood of x in y over remembered actions, weighted by causal evidence `ce`."
function subsethood(mx, my, ce)
    check(length(mx) == length(my) == length(ce) && all(>=(0), mx) && all(>=(0), my) && all(>=(0), ce), "non-negative memberships")
    ccall(sym(:bf_subsethood), Float64, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), floatarray(mx), floatarray(my), floatarray(ce))
end

"An overlap degree moved by one logged action: a long-term rolling average; no action, no change."
function membership_rolling(μ::Real, m_leaf::Real, m_parent::Real; rate::Real)
    check(all(x -> isfinite(x) && 0 <= x <= 1, (μ, m_leaf, m_parent, rate)), "degrees, memberships and rate lie in [0, 1]")
    ccall(sym(:bf_membership_rolling), Float64, (Float64, Float64, Float64, Float64), μ, m_leaf, m_parent, rate)
end

"A model's accuracy in [0, 1] from its score (negative mean squared error); also its escrow confidence."
function accuracy(score::Real)
    check(isfinite(score) && score <= 0, "a score is a negative mean squared error")
    ccall(sym(:bf_accuracy), Float64, (Float64,), score)
end

"Whether a domain's model may back its currency (novel domains: after `min_records`, never below `novel_floor`, 8.35; governed)."
function currency_eligible(acc::Real, records::Integer; novel::Bool, threshold::Real, novel_threshold::Real, min_records::Integer, novel_floor::Real)
    check(isfinite(acc) && 0 <= acc <= 1 && records >= 0 && min_records >= 0 && 0 <= novel_floor <= 1, "accuracy and floor in [0, 1], counts non-negative")
    ccall(sym(:bf_currency_eligible), UInt8, (Float64, Float64, Float64, UInt8, Float64, Float64, Float64),
          acc, records, min_records, novel, threshold, novel_threshold, novel_floor) == 1
end

"Resource cost per unit by availability: `base` × capacity / available, what remains floored at `floor_share` of capacity (governed): exhaustion dear but finite."
function scarcity_cost(base::Real, available::Real, capacity::Real; floor_share::Real)
    check(isfinite(base) && base >= 0 && isfinite(available) && available >= 0 && isfinite(capacity) && capacity > 0 && 0 < floor_share <= 1,
          "base and availability must be non-negative, capacity positive, floor share in (0, 1]")
    ccall(sym(:bf_scarcity_cost), Float64, (Float64, Float64, Float64, Float64), base, available, capacity, floor_share)
end

"""
    relative_bar(established, coarse, alternative) -> bar

A leaf model's status bar relative to the alternative its work would fall to (Lean
`relative_bar_ref`; author ruling 8.41): the alternative's accuracy, up to the established bar,
never below the coarse bar.
"""
function relative_bar(established::Real, coarse::Real, alternative::Real)
    check(all(isfinite, (established, coarse, alternative)) && 0 < coarse <= established <= 1, "bars finite, 0 < coarse ≤ established ≤ 1")
    ccall(sym(:bf_relative_bar), Float64, (Float64, Float64, Float64), established, coarse, alternative)
end

function report_penalty(unfounded::Real, threshold::Real; audit_cost::Real)
    check(unfounded >= 0 && isfinite(threshold) && threshold >= 0, "count and threshold non-negative")
    check(isfinite(audit_cost) && audit_cost >= 0, "audit cost finite, non-negative")
    ccall(sym(:bf_report_penalty), Float64, (Float64, Float64, Float64), unfounded, threshold, audit_cost)
end
