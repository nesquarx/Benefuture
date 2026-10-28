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
