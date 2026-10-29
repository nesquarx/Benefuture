# Assessment (L48), signed synergy (L13), harm weight (L61) and value on a being (L73),
# computed by the Lean reference (`As_ref`, `Sy_signed_ref`, `HaWt_ref`, `V_ref`).

"Priority weights of the harm tiers, irreparable first, read from `harmSchedule_ref` at load."
const HARM_SCHEDULE = Float64[]

function load_harm_schedule!()
    n = ccall(sym(:bf_harm_schedule_len), Csize_t, (Ptr{Cvoid},), Ptr{Cvoid}(1))
    empty!(HARM_SCHEDULE)
    for i in 0:(n - 1)
        push!(HARM_SCHEDULE, ccall(sym(:bf_harm_schedule_at), Float64, (Csize_t,), i))
    end
end

"""
    assess(predicted, counter, measured; t, t0, th)

`As = ((t ≤ t0 ? predicted : measured) − counter) / th`: the action against not acting, in units
of the context's threshold of significance. Before or at t0 only the prediction exists.
"""
function assess(predicted::Real, counter::Real, measured::Real; t::Real, t0::Real, th::Real)
    check(all(isfinite, (predicted, counter, measured, t, t0, th)), "inputs must be finite")
    check(th > 0, "threshold of significance must be positive")
    ccall(sym(:bf_as), Float64, (Float64, Float64, Float64, Float64, Float64, Float64),
          predicted, counter, measured, t, t0, th)
end

"""
    signed_synergy(items; λ, κ, qp, qm)

Sy over signed items `(x, w₊, w₋)`: gains enter Φ₊ with w₊, losses enter Φ₋ with |x| and w₋.
"""
function signed_synergy(items; λ::Real, κ::Real, qp::Real, qm::Real)
    for (x, wp, wn) in items
        all(isfinite, (x, wp, wn)) || throw(ArgumentError("item ($x, $wp, $wn) must be finite"))
        wp >= 0 && wn >= 0 || throw(ArgumentError("item ($x, $wp, $wn) must have non-negative weights"))
    end
    check(all(isfinite, (λ, κ, qp, qm)), "parameters must be finite")
    check(λ >= 0 && κ >= 0 && qp > 0 && qm > 0, "λ, κ non-negative and exponents positive")
    ccall(sym(:bf_sy_signed), Float64,
          (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64, Float64),
          floatarray([x for (x, _, _) in items]), floatarray([w for (_, w, _) in items]),
          floatarray([w for (_, _, w) in items]), λ, κ, qp, qm)
end

"""
    harm_weight(tiers; λ)

`Ha_wt = 1 + Sy_{κ=½, q=1.5}(tiers)` over `(severity, priority weight)` pairs; 1 when there is no
harm, rising with severity.
"""
function harm_weight(tiers; λ::Real)
    check_items(tiers)
    check(isfinite(λ) && λ >= 0, "λ must be finite and non-negative")
    ccall(sym(:bf_ha_wt), Float64, (Ptr{Cvoid}, Ptr{Cvoid}, Float64),
          floatarray(mags(tiers)), floatarray(weights(tiers)), λ)
end

"""
    value_on_being(u, h, n; harm_wt, α, β, γ, λ, qp, qm)

`V = Sy_{κ=2}([(U, α, Ha_wt), (H, β, α·Ha_wt), (N, γ, γ)])` over assessed changes: gains weigh by
priority, losses by priority scaled by the harm weight.
"""
function value_on_being(u::Real, h::Real, n::Real; harm_wt::Real,
                        α::Real, β::Real, γ::Real, λ::Real, qp::Real, qm::Real)
    check(all(isfinite, (u, h, n, λ, qp, qm)), "inputs must be finite")
    check(isfinite(harm_wt) && harm_wt >= 1, "harm weight must be at least 1")
    check(1 > α > β > γ > 0, "priorities must satisfy 1 > α > β > γ > 0")
    check(λ >= 0 && qp > 0 && qm > 0, "λ non-negative and exponents positive")
    ccall(sym(:bf_v), Float64,
          (Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64),
          u, h, n, α, β, γ, harm_wt, λ, qp, qm)
end

"""
    fr_permissible(irreparable, irreversible, longterm, passing, time_loss; confidence) -> Bool

The freedom gate on an action's predicted harm by kind (L135; Lean `fr_permissible_ref`): established
harm (predicted with confidence 0.9 or more, long-term or worse) is impermissible, and so is harm
whose confidence times severity is too high.
"""
function fr_permissible(irreparable::Real, irreversible::Real, longterm::Real, passing::Real, time_loss::Real; confidence::Real)
    check(all(x -> isfinite(x) && x >= 0, (irreparable, irreversible, longterm, passing, time_loss)) && 0 <= confidence <= 1,
          "harm amounts non-negative, confidence in [0, 1]")
    ccall(sym(:bf_fr_permissible), UInt8, (Float64, Float64, Float64, Float64, Float64, Float64),
          irreparable, irreversible, longterm, passing, time_loss, confidence) == 1
end
