# Synergy operators, pseudocode L13–L14, computed by the Lean reference (`phi_ref`, `Sy_ref`,
# `Sy_hat_ref`). Items are (magnitude, weight) pairs with magnitude = |x| on its side.
# The guards here are the bridge's input contract, not rules: invalid inputs throw rather than
# reach the reference, which would return a plausible-looking but meaningless value.

check(cond, msg) = cond || throw(ArgumentError(msg))

function check_items(items)
    for (a, w) in items
        check(isfinite(a) && isfinite(w), "item ($a, $w) must be finite")
        check(a >= 0 && w >= 0, "item ($a, $w) must have non-negative magnitude and weight")
    end
end

mags(items) = [Float64(a) for (a, _) in items]
weights(items) = [Float64(w) for (_, w) in items]

"""
    phi(items, q, κ)

Synergy potential of one side: `Σ wᵢ aᵢ^q + κ √(Σ_{i<j} wᵢ wⱼ (aᵢ aⱼ)^q)`.
"""
function phi(items, q::Real, κ::Real)
    check_items(items)
    ccall(sym(:bf_phi), Float64, (Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64),
          floatarray(mags(items)), floatarray(weights(items)), q, κ)
end

"""
    net_synergy(pos, neg; λ, κ, qp, qm)

`Sy = Φ₊ − Φ₋ − λ Φ₊Φ₋ / (Φ₊ + Φ₋)`, and 0 when both sides are empty or weightless.
"""
function net_synergy(pos, neg; λ::Real, κ::Real, qp::Real, qm::Real)
    check(all(isfinite, (λ, κ, qp, qm)), "parameters must be finite")
    check(λ >= 0 && κ >= 0, "λ and κ must be non-negative")
    check(qp > 0 && qm > 0, "exponents must be positive")
    check_items(pos)
    check_items(neg)
    ccall(sym(:bf_sy), Float64,
          (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64, Float64),
          floatarray(mags(pos)), floatarray(weights(pos)), floatarray(mags(neg)), floatarray(weights(neg)),
          λ, κ, qp, qm)
end

"""
    squashed_synergy(s; ν, h)

`Ŝy(s) = sgn(s) |s|^ν / (|s|^ν + h^ν)`: odd, bounded in (−1, 1) for h > 0.
"""
function squashed_synergy(s::Real; ν::Real, h::Real)
    check(isfinite(s) && isfinite(ν) && isfinite(h), "inputs must be finite")
    check(ν > 0, "ν must be positive")
    check(h >= 0, "h must be non-negative")
    ccall(sym(:bf_sy_hat), Float64, (Float64, Float64, Float64), s, ν, h)
end
