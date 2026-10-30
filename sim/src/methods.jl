# Battery methods beyond the screening and the rays (sim/src/battery.jl): failure boxes by PRIM
# (Friedman & Fisher 1999), variance-based sensitivity by Saltelli's estimators (Saltelli et al.
# 2010), active learning of the failure boundary with a Gaussian-process surrogate (AK-MCS: Echard,
# Gayton & Lemaire 2011), seed counts sized by the standard error of the reading, and a
# cross-entropy search over attacker strategies. Evaluation tooling, not rules: nothing here
# decides anything inside a simulated world.

using LinearAlgebra

# --- PRIM: patient rule induction ------------------------------------------------------------

in_box(b, x) = all(b.lower[j] <= x[j] <= b.upper[j] for j in eachindex(x))
inside_rows(lo, hi, X) = [all(lo[j] <= X[i, j] <= hi[j] for j in 1:size(X, 2)) for i in 1:size(X, 1)]

function box_stats(lo, hi, X, y, total)
    m = inside_rows(lo, hi, X)
    n = count(m)
    (inside = m, n = n, support = n / length(y), density = n == 0 ? 0.0 : mean(y[m]), coverage = n == 0 ? 0.0 : sum(y[m]) / total)
end

"""
    prim(X, y; α = 0.05, min_support = 0.05, min_coverage = 0.5, paste = true, trim_z = 2) -> box

Patient rule induction (Friedman & Fisher 1999) for the region where `y` (failure: true or 1) is
densest among the rows of `X`. Peeling removes, at each step, the `α` share of the box along the one
side of the one factor that most raises the failure density of what remains, while the box keeps at
least `min_support` of the points. From the peeling trajectory, among boxes covering at least
`min_coverage` of the failures, the first whose density is within `trim_z` binomial standard errors
of the densest is kept (later peels chase noise); pasting widens its bounds while density rises;
restrictions whose removal costs less density than `trim_z` binomial standard errors are dropped,
so the box names only the factors that matter (Bryant & Lempert 2010). The box is closed:
`lower[j] ≤ x[j] ≤ upper[j]`, with ±Inf where factor `j` is unrestricted (`restricted` lists the
others). Reports `density` (failure share inside), `coverage` (share of all failures inside),
`support` (share of points inside), `n`, and the peeling `trajectory`.
"""
function prim(X::AbstractMatrix, y::AbstractVector; α::Real = 0.05, min_support::Real = 0.05, min_coverage::Real = 0.5,
              paste::Bool = true, trim_z::Real = 2.0)
    n, k = size(X)
    check(n == length(y) && n >= 2 && k >= 1, "one outcome per row, at least two rows and one factor")
    check(all(isfinite, X), "finite factor values")
    check(0 < α < 0.5 && 0 < min_support <= 1 && 0 <= min_coverage <= 1 && trim_z >= 0, "α in (0, 0.5), support and coverage shares in range")
    yf = Float64.(y)
    check(all(v -> isfinite(v) && v >= 0, yf), "outcomes non-negative (failure 1, convergence 0)")
    total = sum(yf)
    check(total > 0, "at least one failure to box")
    lo, hi = fill(-Inf, k), fill(Inf, k)
    top = maximum(yf)
    st = box_stats(lo, hi, X, yf, total)
    traj = [(lower = copy(lo), upper = copy(hi), support = st.support, density = st.density, coverage = st.coverage)]
    while st.density < top
        best = nothing
        for j in 1:k
            xs = X[st.inside, j]
            for side in (:lower, :upper)
                q = quantile(xs, side == :lower ? α : 1 - α)
                keep = side == :lower ? xs .> q : xs .< q
                any(keep) && !all(keep) || continue
                count(keep) / n >= min_support || continue
                d = mean(yf[st.inside][keep])
                nl, nh = copy(lo), copy(hi)
                side == :lower ? (nl[j] = minimum(xs[keep])) : (nh[j] = maximum(xs[keep]))
                if best === nothing || d > best.d + 1e-12 || (abs(d - best.d) <= 1e-12 && count(keep) > best.kept)
                    best = (d = d, kept = count(keep), lo = nl, hi = nh)
                end
            end
        end
        best === nothing && break
        best.d > st.density - 1e-12 || break
        lo, hi = best.lo, best.hi
        st = box_stats(lo, hi, X, yf, total)
        push!(traj, (lower = copy(lo), upper = copy(hi), support = st.support, density = st.density, coverage = st.coverage))
    end
    # Late peels chase noise: keep the first box whose density is within `trim_z` standard errors
    # of the densest box covering enough failures.
    ok = filter(t -> t.coverage >= min_coverage, traj)
    dmax = maximum(t.density for t in ok)
    se(t) = sqrt(max(t.density * (1 - t.density), 0.0) / max(t.support * n, 1))
    pick = ok[findfirst(t -> t.density >= dmax - trim_z * se(t) - 1e-12, ok)]
    lo, hi = copy(pick.lower), copy(pick.upper)
    if paste  # widen each bound by about α of the box's points while density rises
        improved = true
        while improved
            improved = false
            cur = box_stats(lo, hi, X, yf, total)
            for j in 1:k, side in (:lower, :upper)
                b = side == :lower ? lo[j] : hi[j]
                isfinite(b) || continue
                others = [all(lo[l] <= X[i, l] <= hi[l] for l in 1:k if l != j) for i in 1:n]
                cand = findall(i -> others[i] && (side == :lower ? X[i, j] < b : X[i, j] > b), 1:n)
                isempty(cand) && continue
                sort!(cand; by = i -> X[i, j], rev = side == :lower)
                take = cand[1:min(length(cand), max(1, ceil(Int, α * cur.n)))]
                nl, nh = copy(lo), copy(hi)
                side == :lower ? (nl[j] = minimum(X[take, j])) : (nh[j] = maximum(X[take, j]))
                s2 = box_stats(nl, nh, X, yf, total)
                if s2.density > cur.density + 1e-12
                    lo, hi, cur, improved = nl, nh, s2, true
                end
            end
        end
    end
    # A bound at or beyond the data's own range restricts nothing.
    for j in 1:k
        lo[j] <= minimum(X[:, j]) && (lo[j] = -Inf)
        hi[j] >= maximum(X[:, j]) && (hi[j] = Inf)
    end
    while true  # trim: drop the restriction that costs least density, while that cost is within noise
        cur = box_stats(lo, hi, X, yf, total)
        se = sqrt(max(cur.density * (1 - cur.density), 0.0) / max(cur.n, 1))
        cands = [j for j in 1:k if isfinite(lo[j]) || isfinite(hi[j])]
        isempty(cands) && break
        loss = map(cands) do j
            nl, nh = copy(lo), copy(hi); nl[j], nh[j] = -Inf, Inf
            cur.density - box_stats(nl, nh, X, yf, total).density
        end
        i = argmin(loss)
        loss[i] <= max(trim_z * se, 1e-12) || break
        lo[cands[i]], hi[cands[i]] = -Inf, Inf
    end
    st = box_stats(lo, hi, X, yf, total)
    (lower = lo, upper = hi, restricted = [j for j in 1:k if isfinite(lo[j]) || isfinite(hi[j])],
     density = st.density, coverage = st.coverage, support = st.support, n = st.n, trajectory = traj)
end

"""
    prim_boxes(X, y; nboxes = 3, kw...) -> boxes

Covering: a PRIM box, then another on the points outside it, up to `nboxes`, while each box holds
failure more densely than the points it was found among. Coverage is of all failures, so the
boxes' coverages sum to at most 1.
"""
function prim_boxes(X::AbstractMatrix, y::AbstractVector; nboxes::Integer = 3, kw...)
    check(size(X, 1) == length(y) && nboxes >= 1, "one outcome per row; at least one box")
    yf = Float64.(y)
    total = sum(yf)
    boxes = []
    total > 0 || return boxes
    active = trues(length(yf))
    for _ in 1:nboxes
        ya = yf[active]
        (sum(ya) > 0 && count(active) >= 2) || break
        b = prim(X[active, :], ya; kw...)
        if b.density <= mean(ya) + 1e-12  # no enrichment: an unrestricted box over what is left
            isempty(boxes) && b.density == 1 && push!(boxes, b)
            break
        end
        m = inside_rows(b.lower, b.upper, X) .& active
        push!(boxes, merge(b, (coverage = sum(yf[m]) / total, support = count(m) / length(yf), n = count(m))))
        active .&= .!m
    end
    boxes
end

"A box as one line: a clause per restricted factor (`a ≥ 0.7 and c ≤ 0.3`), or `anywhere`."
function describe_box(b, names; digits::Integer = 2)
    r(x) = string(round(x; digits))
    clauses = String[]
    for j in b.restricted
        l, h = b.lower[j], b.upper[j]
        push!(clauses, isfinite(l) && isfinite(h) ? "$(r(l)) ≤ $(names[j]) ≤ $(r(h))" :
                       isfinite(l) ? "$(names[j]) ≥ $(r(l))" : "$(names[j]) ≤ $(r(h))")
    end
    isempty(clauses) ? "anywhere" : join(clauses, " and ")
end

# --- Sobol indices by Saltelli's estimators ---------------------------------------------------

"""
    sobol_indices(f, k; N, rng, bootstrap = 200) -> (S1, ST, S1_lo, S1_hi, ST_lo, ST_hi, V, evaluations)

Variance-based sensitivity of `f` (from [0, 1]^`k` to a number or a vector of numbers) by the
Saltelli et al. (2010) design: two independent Latin hypercubes A and B of `N` rows and, for each
factor i, A with column i taken from B; `N(k + 2)` evaluations. First-order indices
S1ᵢ = mean(f(B)(f(A_B⁽ⁱ⁾) − f(A))) / V (Saltelli 2010) and total indices
STᵢ = mean((f(A) − f(A_B⁽ⁱ⁾))²) / 2V (Jansen 1999), V the variance over A and B. One row per output;
95% intervals by bootstrapping the rows. A constant output has variance 0 and all indices 0.
"""
function sobol_indices(f, k::Integer; N::Integer, rng::AbstractRNG, bootstrap::Integer = 200)
    check(k >= 1 && N >= 2 && bootstrap >= 0, "at least one factor and two rows")
    A, B = latin_hypercube(rng, N, k), latin_hypercube(rng, N, k)
    ev(x) = (v = f(x); vv = v isa Number ? [Float64(v)] : Float64.(collect(v)); check(all(isfinite, vv), "finite outputs"); vv)
    rows(M) = permutedims(reduce(hcat, [ev(M[i, :]) for i in 1:N]))  # N × outputs
    fA, fB = rows(A), rows(B)
    fAB = map(1:k) do j
        AB = copy(A); AB[:, j] = B[:, j]
        rows(AB)
    end
    m = size(fA, 2)
    function est(r)
        S1, ST, V = zeros(m, k), zeros(m, k), zeros(m)
        for o in 1:m
            V[o] = var(vcat(fA[r, o], fB[r, o]))
            V[o] > 1e-14 * max(1.0, mean(abs2, fA[r, o])) || (V[o] = 0.0; continue)
            for j in 1:k
                S1[o, j] = mean(fB[r, o] .* (fAB[j][r, o] .- fA[r, o])) / V[o]
                ST[o, j] = mean(abs2, fA[r, o] .- fAB[j][r, o]) / 2V[o]
            end
        end
        (S1 = S1, ST = ST, V = V)
    end
    e = est(1:N)
    boots = [est(rand(rng, 1:N, N)) for _ in 1:bootstrap]
    q(field, p) = isempty(boots) ? getfield(e, field) : [quantile([getfield(b, field)[o, j] for b in boots], p) for o in 1:m, j in 1:k]
    (S1 = e.S1, ST = e.ST, S1_lo = q(:S1, 0.025), S1_hi = q(:S1, 0.975), ST_lo = q(:ST, 0.025), ST_hi = q(:ST, 0.975),
     V = e.V, evaluations = N * (k + 2))
end

# --- Active learning of the failure boundary -------------------------------------------------

# Gaussian-process regression (squared-exponential kernel on inputs scaled to the pool's range,
# a nugget for the oracle's noise), hyperparameters by marginal likelihood over a small grid.
const GP_LENGTHS = (0.05, 0.1, 0.15, 0.25, 0.4, 0.6, 1.0, 1.5)
const GP_NUGGETS = (1e-6, 1e-4, 1e-3, 1e-2, 0.05, 0.1, 0.3)

sqdist(P, Q) = [sum(abs2, P[i, :] .- Q[j, :]) for i in 1:size(P, 1), j in 1:size(Q, 1)]

function gp_fit(Z, y)
    n = length(y)
    μ0 = mean(y)
    s = n >= 2 && std(y) > 0 ? std(y) : 1.0
    ys = (y .- μ0) ./ s
    D = sqdist(Z, Z)
    best = nothing
    for ℓ in GP_LENGTHS, η in GP_NUGGETS
        K = exp.(-D ./ (2ℓ^2)) + (η + 1e-9) * I
        C = cholesky(Symmetric(K); check = false)
        issuccess(C) || continue
        α = C \ ys
        ll = -0.5dot(ys, α) - sum(log, diag(C.L))
        (best === nothing || ll > best.ll) && (best = (ll = ll, ℓ = ℓ, η = η, C = C, α = α))
    end
    (Z = Z, μ0 = μ0, s = s, ℓ = best.ℓ, η = best.η, C = best.C, α = best.α)
end

function gp_predict(gp, P)
    Ks = exp.(-sqdist(P, gp.Z) ./ (2gp.ℓ^2))
    μ = gp.μ0 .+ gp.s .* (Ks * gp.α)
    W = gp.C.L \ permutedims(Ks)
    σ = gp.s .* sqrt.(max.(1 .- vec(sum(abs2, W; dims = 1)), 1e-12))
    (μ = μ, σ = σ)
end

function boundary_result(f_vals, idx, pool, Zp)
    gp = gp_fit(Zp[idx, :], f_vals)
    pr = gp_predict(gp, Zp)
    fail = pr.μ .< 0
    (X = pool[idx, :], y = f_vals, idx = idx, μ = pr.μ, σ = pr.σ, predicted_fail = fail, p_fail = mean(fail),
     evaluations = length(idx), length_scale = gp.ℓ, nugget = gp.η)
end

function scaled_pool(pool)
    check(size(pool, 1) >= 2 && size(pool, 2) >= 1 && all(isfinite, pool), "a finite pool of at least two candidate worlds")
    lo = minimum(pool; dims = 1); span = maximum(pool; dims = 1) .- lo
    (pool .- lo) ./ max.(span, 1e-12)
end

function evaluate_at(f, x)
    v = Float64(f(x))
    check(isfinite(v), "the oracle's margin must be finite")
    v
end

"""
    active_boundary(f, pool; rng, n_init = 10, budget = 40, stop_U = 2) -> result

AK-MCS (Echard, Gayton & Lemaire 2011) over the candidate worlds in the rows of `pool`: `f` gives a
world's margin (negative: it fails; a noisy oracle is fine, and ±1 answers serve as a smoothed
classifier). After `n_init` random candidates, a Gaussian process with a fitted nugget is refit and
the candidate whose sign it is least sure of (least U = |μ| / σ) is evaluated next, until every
unevaluated candidate has U ≥ `stop_U` or `budget` evaluations are spent. Reports the evaluated
worlds `X` and margins `y`, the surrogate's verdict on every candidate (`predicted_fail`), and the
estimated failure share of the pool (`p_fail`).
"""
function active_boundary(f, pool::AbstractMatrix; rng::AbstractRNG, n_init::Integer = 10, budget::Integer = 40, stop_U::Real = 2.0)
    Zp = scaled_pool(pool)
    n = size(pool, 1)
    check(2 <= n_init <= budget <= n && stop_U > 0, "2 ≤ initial design ≤ budget ≤ pool size; positive stopping level")
    idx = randperm(rng, n)[1:n_init]
    ys = [evaluate_at(f, pool[i, :]) for i in idx]
    while length(idx) < budget
        pr = gp_predict(gp_fit(Zp[idx, :], ys), Zp)
        U = abs.(pr.μ) ./ pr.σ
        U[idx] .= Inf
        i = argmin(U)
        U[i] >= stop_U && break
        push!(idx, i); push!(ys, evaluate_at(f, pool[i, :]))
    end
    boundary_result(ys, idx, pool, Zp)
end

"The same surrogate fitted to `budget` candidates drawn at random: the baseline active learning must beat."
function random_boundary(f, pool::AbstractMatrix; rng::AbstractRNG, budget::Integer)
    Zp = scaled_pool(pool)
    check(2 <= budget <= size(pool, 1), "2 ≤ budget ≤ pool size")
    idx = randperm(rng, size(pool, 1))[1:budget]
    boundary_result([evaluate_at(f, pool[i, :]) for i in idx], idx, pool, Zp)
end

# --- Seed counts by variance stability --------------------------------------------------------

# Student's t 97.5% quantiles for 1–30 degrees of freedom, over the normal's 1.96: a standard error
# estimated from few seeds is itself uncertain, and three close readings must not stop the count.
const T975 = (12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228, 2.201, 2.179, 2.160, 2.145, 2.131,
              2.120, 2.110, 2.101, 2.093, 2.086, 2.080, 2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048, 2.045, 2.042)
t_inflation(ν) = ν <= length(T975) ? T975[ν] / 1.96 : 1.0

"""
    seeds_until_stable(f; tol, min_seeds = 3, max_seeds = 10, seeds = 1:max_seeds) -> (mean, se, n, values, seeds, stable)

Evaluate `f(seed)` over `seeds` in order, at least `min_seeds` of them, until the standard error of
the mean, inflated by Student's t over the normal for the seeds so far (so few, close readings do
not stop the count early), falls to `tol`, or `max_seeds` are spent (`stable` says which). Seeds are fixed and taken
in order, so a reading repeats exactly and seeds are shared across worlds (common random numbers).
"""
function seeds_until_stable(f; tol::Real, min_seeds::Integer = 3, max_seeds::Integer = 10, seeds = 1:max_seeds)
    check(tol > 0 && 2 <= min_seeds <= max_seeds && length(seeds) >= max_seeds, "positive tolerance, 2 ≤ min ≤ max seeds, enough seeds")
    vals = Float64[]
    se = Inf
    for i in 1:max_seeds
        v = Float64(f(seeds[i]))
        check(isfinite(v), "readings must be finite")
        push!(vals, v)
        i >= min_seeds || continue
        se = std(vals) / sqrt(i)
        se * t_inflation(i - 1) <= tol && break
    end
    n = length(vals)
    (mean = mean(vals), se = se, n = n, values = vals, seeds = seeds[1:n], stable = se * t_inflation(n - 1) <= tol)
end

# --- Cross-entropy search ----------------------------------------------------------------------

"""
    cross_entropy_search(f, m; rng, population = 12, iterations = 6, elite = 0.25, σ0 = 0.3,
                         μ0 = fill(0.5, m), smoothing = 0.7, σ_min = 0.02) -> (θ, value, μ, history, evaluations)

Minimise `f` over [0, 1]^`m` by the cross-entropy method (Rubinstein 1999): each iteration samples
`population` points from independent normals (clamped to the cube), keeps the `elite` share with the
lowest values, and moves the normals' means and spreads toward theirs (by `smoothing`; spreads never
below `σ_min`, so the search keeps probing). Derivative-free and tolerant of a noisy `f`; with fixed
seeds inside `f` (common random numbers) it is deterministic. Returns the best point evaluated and
its value, the final mean, and per-iteration `history` (best so far, elite mean).
"""
function cross_entropy_search(f, m::Integer; rng::AbstractRNG, population::Integer = 12, iterations::Integer = 6, elite::Real = 0.25,
                              σ0::Real = 0.3, μ0 = fill(0.5, m), smoothing::Real = 0.7, σ_min::Real = 0.02)
    check(m >= 1 && population >= 2 && iterations >= 1 && 0 < elite < 1 && σ0 > 0 && 0 < smoothing <= 1 && σ_min >= 0,
          "a dimension, population of at least two, an elite share in (0, 1), positive spreads")
    check(length(μ0) == m, "one starting mean per dimension")
    ne = clamp(ceil(Int, elite * population), 1, population - 1)
    μ, σ = Float64.(collect(μ0)), fill(Float64(σ0), m)
    best_θ, best_v = copy(μ), Inf
    history = NamedTuple[]
    for it in 1:iterations
        Θ = clamp.(μ .+ σ .* randn(rng, m, population), 0.0, 1.0)
        vals = map(1:population) do p
            v = Float64(f(Θ[:, p]))
            check(isfinite(v), "the objective must be finite")
            v
        end
        o = sortperm(vals)
        vals[o[1]] < best_v && ((best_v, best_θ) = (vals[o[1]], Θ[:, o[1]]))
        E = Θ[:, o[1:ne]]
        μ = smoothing .* vec(mean(E; dims = 2)) .+ (1 - smoothing) .* μ
        σ = max.(smoothing .* (ne > 1 ? vec(std(E; dims = 2)) : zeros(m)) .+ (1 - smoothing) .* σ, σ_min)
        push!(history, (iteration = it, best = best_v, elite_mean = mean(vals[o[1:ne]])))
    end
    (θ = best_θ, value = best_v, μ = μ, history = history, evaluations = population * iterations)
end
