# Assessment (L48), signed synergy (L13), harm weight (L61) and value on a being (L73);
# mirror `As_ref`, `Sy_signed_ref`, `HaWt_ref` and `V_ref` in BenefutureReference.

"Priority weights of the harm tiers, irreparable first (`harmSchedule_ref`)."
const HARM_SCHEDULE = [0.9, 0.7, 0.45, 0.15, 0.08, 0.04, 0.01]

"""
    assess(predicted, counter, measured; t, t0, th)

`As = ((t ≤ t0 ? predicted : measured) − counter) / th`: the action against not acting, in units
of the context's threshold of significance. Before or at t0 only the prediction exists.
"""
function assess(predicted::Real, counter::Real, measured::Real; t::Real, t0::Real, th::Real)
    check(all(isfinite, (predicted, counter, measured, t, t0, th)), "inputs must be finite")
    check(th > 0, "threshold of significance must be positive")
    ((t > t0 ? measured : predicted) - counter) / th
end

"""
    signed_synergy(items; λ, κ, qp, qm)

Sy over signed items `(x, w₊, w₋)`: gains enter Φ₊ with w₊, losses enter Φ₋ with |x| and w₋.
"""
function signed_synergy(items; λ::Real, κ::Real, qp::Real, qm::Real)
    for (x, _, _) in items
        check(isfinite(x), "item value $x must be finite")
    end
    pos = [(x, wp) for (x, wp, _) in items if x > 0]
    neg = [(-x, wn) for (x, _, wn) in items if x < 0]
    net_synergy(pos, neg; λ, κ, qp, qm)
end

"""
    harm_weight(tiers; λ)

`Ha_wt = 1 + Sy_{κ=½, q=1.5}(tiers)` over `(severity, priority weight)` pairs; 1 when there is no
harm, rising with severity.
"""
harm_weight(tiers; λ::Real) = 1.0 + net_synergy(tiers, []; λ, κ = 0.5, qp = 1.5, qm = 1.5)

"""
    value_on_being(u, h, n; harm_wt, α, β, γ, λ, qp, qm)

`V = Sy_{κ=2}([(U, α, Ha_wt), (H, β, α·Ha_wt), (N, γ, γ)])` over assessed changes: gains weigh by
priority, losses by priority scaled by the harm weight.
"""
function value_on_being(u::Real, h::Real, n::Real; harm_wt::Real,
                        α::Real, β::Real, γ::Real, λ::Real, qp::Real, qm::Real)
    check(isfinite(harm_wt) && harm_wt >= 1, "harm weight must be at least 1")
    check(1 > α > β > γ > 0, "priorities must satisfy 1 > α > β > γ > 0")
    signed_synergy([(u, α, harm_wt), (h, β, α * harm_wt), (n, γ, γ)]; λ, κ = 2.0, qp, qm)
end
