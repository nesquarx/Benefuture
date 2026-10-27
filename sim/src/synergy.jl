# Synergy operators, pseudocode L13–L14; mirror `Sy_ref` and `Sy_hat_ref` in BenefutureReference.
# Items are (magnitude, weight) pairs with magnitude = |x| on its side (gain or loss).
# Invalid inputs throw rather than score: a negative or non-finite magnitude, weight or
# parameter would otherwise produce a plausible-looking but meaningless value.

const Item = Tuple{<:Real,<:Real}

check(cond, msg) = cond || throw(ArgumentError(msg))

function check_items(items)
    for (a, w) in items
        check(isfinite(a) && isfinite(w), "item ($a, $w) must be finite")
        check(a >= 0 && w >= 0, "item ($a, $w) must have non-negative magnitude and weight")
    end
end

"""
    phi(items, q, κ)

Synergy potential of one side: `Σ wᵢ aᵢ^q + κ √(Σ_{i<j} wᵢ wⱼ (aᵢ aⱼ)^q)`.
"""
function phi(items, q::Real, κ::Real)
    check_items(items)
    linear = sum((w * a^q for (a, w) in items); init = 0.0)
    cross = 0.0
    for i in eachindex(items), j in eachindex(items)
        i < j || continue
        (a1, w1), (a2, w2) = items[i], items[j]
        cross += w1 * w2 * (a1 * a2)^q
    end
    linear + κ * sqrt(cross)
end

"""
    net_synergy(pos, neg; λ, κ, qp, qm)

`Sy = Φ₊ − Φ₋ − λ Φ₊Φ₋ / (Φ₊ + Φ₋)`, and 0 when both sides are empty or weightless.
"""
function net_synergy(pos, neg; λ::Real, κ::Real, qp::Real, qm::Real)
    check(all(isfinite, (λ, κ, qp, qm)), "parameters must be finite")
    check(λ >= 0 && κ >= 0, "λ and κ must be non-negative")
    check(qp > 0 && qm > 0, "exponents must be positive")
    p, m = phi(pos, qp, κ), phi(neg, qm, κ)
    total = p + m
    total == 0 ? 0.0 : p - m - λ * p * m / total
end

"""
    squashed_synergy(s; ν, h)

`Ŝy(s) = sgn(s) |s|^ν / (|s|^ν + h^ν)`: odd, bounded in (−1, 1) for h > 0.
"""
function squashed_synergy(s::Real; ν::Real, h::Real)
    check(isfinite(s) && isfinite(ν) && isfinite(h), "inputs must be finite")
    check(ν > 0, "ν must be positive")
    check(h >= 0, "h must be non-negative")
    s == 0 && return 0.0
    num = abs(s)^ν
    sign(s) * num / (num + h^ν)
end
