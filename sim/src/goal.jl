# Goal G's floors and choice (L74), computed by the Lean reference
# (`floor_quantile_ref`, `g_choose_ref`).

"""
    floor_quantile(levels, q)

Floor of a population: the lower nearest-rank q-quantile; 0 for an empty population.
"""
function floor_quantile(levels, q::Real)
    check(all(isfinite, levels), "levels must be finite")
    check(isfinite(q) && 0 <= q <= 1, "q must lie in [0, 1]")
    ccall(sym(:bf_floor_quantile), Float64, (Ptr{Cvoid}, Float64), floatarray(levels), q)
end

"""
    g_choose(values, d_scope, d_min_u, d_min_h, d_max_u) -> Union{Int,Nothing}

Index (1-based) of the admissible plan of highest value, first on ties; a plan is admissible
when, against not acting, none of reality's scope, the floors of U and H, or the peak of U falls.
`nothing` when no plan is admissible.
"""
function g_choose(values, d_scope, d_min_u, d_min_h, d_max_u)
    cols = (values, d_scope, d_min_u, d_min_h, d_max_u)
    check(allequal(length.(cols)), "all columns must have one entry per plan")
    check(all(c -> all(isfinite, c), cols), "entries must be finite")
    a = map(floatarray, cols)
    i = ccall(sym(:bf_g_choose), UInt64, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
              a[1], a[2], a[3], a[4], a[5])
    i == length(values) ? nothing : Int(i) + 1
end

"""
    g_choose_dist(u0, h0, plan_draws; q = 0.05, scope_deltas = zeros(length(plan_draws)),
                  weights = nothing, worst_floor = true, harm_wt = 1.0, α = 0.8, β = 0.5,
                  λ = 1.0, κ = 0.5, qp = 1.1, qm = 1.5) -> Union{Int,Nothing}

Goal choice `G` (`L74`) over empirical outcome distributions `D`: each plan supplies scenario
`(du, dh)` vectors (optionally weighted by `weights`). Aggregates expected synergistic value
`E_D[α·Sy(ΔU) + β·Sy(ΔH)]` (`signed_synergy`, Lean `bf_sy_signed`) alongside worst-case (or
expected) floor/peak deltas (`floor_quantile`, Lean `bf_floor_quantile`) via `g_choose`.
"""
function g_choose_dist(u0, h0, plan_draws; q::Real = 0.05,
                       scope_deltas = zeros(length(plan_draws)),
                       weights = nothing, worst_floor::Bool = true,
                       harm_wt::Real = 1.0, α::Real = 0.8, β::Real = 0.5,
                       λ::Real = 1.0, κ::Real = 0.5, qp::Real = 1.1, qm::Real = 1.5)
    check(!isempty(u0) && length(u0) == length(h0) && all(isfinite, u0) && all(isfinite, h0),
          "non-empty equal-length finite baselines")
    check(length(plan_draws) == length(scope_deltas) && all(isfinite, scope_deltas),
          "one finite scope delta per plan")
    m = length(plan_draws)
    m == 0 && return nothing
    fu0, fh0, pu0 = floor_quantile(u0, q), floor_quantile(h0, q), maximum(u0)
    vals, dmin_u, dmin_h, dmax_u = zeros(m), zeros(m), zeros(m), zeros(m)
    for k in 1:m
        draws = plan_draws[k]
        nd = length(draws)
        check(nd >= 1, "each plan needs at least one outcome draw in its distribution D")
        ws = weights === nothing ? fill(1.0 / nd, nd) : collect(Float64, weights[k])
        check(length(ws) == nd && all(w -> isfinite(w) && w >= 0, ws) && sum(ws) > 0,
              "scenario weights must be finite, non-negative, and sum > 0")
        ws ./= sum(ws)
        ev, dfu, dfh, dpu = 0.0, Float64[], Float64[], Float64[]
        for (s_idx, (du, dh)) in enumerate(draws)
            check(length(du) == length(u0) && length(dh) == length(h0) &&
                  all(isfinite, du) && all(isfinite, dh), "draw dimensions must match baseline")
            u1, h1 = Float64.(u0) .+ Float64.(du), Float64.(h0) .+ Float64.(dh)
            vu = signed_synergy([(Float64(x), 1.0, Float64(harm_wt)) for x in du]; λ, κ, qp, qm)
            vh = signed_synergy([(Float64(x), 1.0, Float64(harm_wt)) for x in dh]; λ, κ, qp, qm)
            ev += ws[s_idx] * (α * vu + β * vh)
            push!(dfu, floor_quantile(u1, q) - fu0)
            push!(dfh, floor_quantile(h1, q) - fh0)
            push!(dpu, maximum(u1) - pu0)
        end
        vals[k] = ev
        dmin_u[k] = worst_floor ? minimum(dfu) : sum(ws .* dfu)
        dmin_h[k] = worst_floor ? minimum(dfh) : sum(ws .* dfh)
        dmax_u[k] = worst_floor ? minimum(dpu) : sum(ws .* dpu)
    end
    g_choose(vals, scope_deltas, dmin_u, dmin_h, dmax_u)
end
