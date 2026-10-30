# The failure-boundary battery: a randomized search for the combinations of noise and attack beyond
# which the framework stops converging. An oracle takes a vector of severities (0 is the clean world;
# 1 the top of each factor's explored range; beyond 1, further) and answers whether the world built
# from it converges. Screening by a Latin hypercube ranks the factors and their pairs; rays from the
# clean point, along each axis and in random directions, are searched by bisection for the severity
# where convergence fails, giving per-factor limits and points on the failure surface. Rays on
# which convergence returns further out are flagged as non-monotone. Evaluation tooling, not rules.

using Printf

"`n` points in [0, 1]^`k`, each factor's range cut into `n` strata sampled once each."
function latin_hypercube(rng::AbstractRNG, n::Integer, k::Integer)
    check(n >= 1 && k >= 1, "at least one point and one factor")
    X = zeros(n, k)
    for j in 1:k
        X[:, j] = (randperm(rng, n) .- 1 .+ rand(rng, n)) ./ n
    end
    X
end

"""
    normal_quantile(p) -> z

The standard normal quantile by Acklam's rational approximation (relative error about 1e-9): fast,
for stratified Gaussian sampling. Evaluation tooling, not a rule.
"""
function normal_quantile(p::Real)
    check(0 < p < 1, "probability in (0, 1)")
    a = (-3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2, 1.383577518672690e2, -3.066479806614716e1, 2.506628277459239)
    b = (-5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2, 6.680131188771972e1, -1.328068155288572e1)
    c = (-7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838, -2.549732539343734, 4.374664141464968, 2.938163982698783)
    d = (7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996, 3.754408661907416)
    p == 0.5 && return 0.0
    if p < 0.02425
        q = sqrt(-2log(p))
        return (((((c[1]q + c[2])q + c[3])q + c[4])q + c[5])q + c[6]) / ((((d[1]q + d[2])q + d[3])q + d[4])q + 1)
    elseif p > 1 - 0.02425
        q = sqrt(-2log(1 - p))
        return -(((((c[1]q + c[2])q + c[3])q + c[4])q + c[5])q + c[6]) / ((((d[1]q + d[2])q + d[3])q + d[4])q + 1)
    end
    q = p - 0.5; r = q^2
    (((((a[1]r + a[2])r + a[3])r + a[4])r + a[5])r + a[6])q / (((((b[1]r + b[2])r + b[3])r + b[4])r + b[5])r + 1)
end

"""
    gaussian_hypercube(rng, n, k; μ, σ) -> n × k severities

Stratified Gaussian sampling: a Latin hypercube pushed through `normal_quantile`, centred on `μ` with
spread `σ`, floored at 0. Typical worlds dominate; extremes stay rare but present.
"""
gaussian_hypercube(rng::AbstractRNG, n::Integer, k::Integer; μ::Real, σ::Real) =
    max.(0.0, μ .+ σ .* normal_quantile.(latin_hypercube(rng, n, k)))

"""
    ray_boundary(oracle, direction; tmax, tol, grid = 8) -> (t, monotone)

The severity `t` along `direction` (points `t × direction`) where `oracle` first fails: a coarse
grid on (0, `tmax`] brackets it, bisection to `tol` locates it. `t` is 0 if the clean point fails
and `Inf` if no grid point fails; `monotone` is false if the oracle converges again beyond `t`.
"""
function ray_boundary(oracle, direction; tmax::Real, tol::Real, grid::Integer = 8)
    check(any(!iszero, direction) && all(isfinite, direction), "a non-zero direction")
    check(tmax > 0 && tol > 0 && grid >= 1, "positive range, tolerance and grid")
    at(t) = oracle(t .* direction)
    at(0.0) || return (t = 0.0, monotone = true)
    ts = collect(range(0, tmax; length = grid + 1))[2:end]
    ok = [at(t) for t in ts]
    i = findfirst(!, ok)
    i === nothing && return (t = Inf, monotone = true)
    lo, hi = i == 1 ? 0.0 : ts[i - 1], ts[i]
    while hi - lo > tol
        mid = (lo + hi) / 2
        at(mid) ? (lo = mid) : (hi = mid)
    end
    (t = (lo + hi) / 2, monotone = !any(ok[(i + 1):end]))
end

"""
    screen(oracle, X) -> (fails, fail_rate, importance, pairs, X)

Evaluate `oracle` on the rows of `X`. A factor's importance is how much higher its severity runs
in failing worlds than in converging ones; a pair's interaction is the failure rate where both are
high (above their medians) beyond what each alone adds.
"""
function screen(oracle, X::AbstractMatrix)
    n, k = size(X)
    fails = [!oracle(X[i, :]) for i in 1:n]
    rate(m) = any(m) ? mean(fails[m]) : NaN
    importance = [any(fails) && !all(fails) ? mean(X[fails, j]) - mean(X[.!fails, j]) : 0.0 for j in 1:k]
    pairs = Dict{Tuple{Int,Int},Float64}()
    hi = [X[:, j] .> median(X[:, j]) for j in 1:k]  # split at each factor's median, whatever the scale
    for a in 1:k, b in (a + 1):k
        hh = rate(hi[a] .& hi[b]); hl = rate(hi[a] .& .!hi[b])
        lh = rate(.!hi[a] .& hi[b]); ll = rate(.!hi[a] .& .!hi[b])
        pairs[(a, b)] = any(isnan, (hh, hl, lh, ll)) ? 0.0 : hh - hl - lh + ll
    end
    (fails = fails, fail_rate = mean(fails), importance = importance, pairs = pairs, X = Matrix{Float64}(X))
end

"""
    battery(oracle, names; rng, rays, screen_n, tmax, tol, grid = 8) -> (limits, boundary, screening)

Per-factor limits (`limits[name]`: the severity along that axis alone where convergence fails),
`rays` boundary points in random directions of the positive orthant, and a screening of `screen_n`
Latin-hypercube worlds, scaled (`screen_scale`) to straddle the boundary the rays found.
"""
function battery(oracle, names; rng::AbstractRNG, rays::Integer, screen_n::Integer, tmax::Real, tol::Real, grid::Integer = 8)
    k = length(names)
    axis(j) = Float64.((1:k) .== j)
    limits = Dict(names[j] => ray_boundary(oracle, axis(j); tmax, tol, grid).t for j in 1:k)
    boundary = map(1:rays) do _
        d = abs.(randn(rng, k)); d ./= sqrt(sum(abs2, d))
        b = ray_boundary(oracle, d; tmax, tol, grid)
        (direction = d, t = b.t, point = isfinite(b.t) ? b.t .* d : fill(Inf, k), monotone = b.monotone)
    end
    # Screen where the boundary lies, Gaussian-ish: severities centred on the scale that puts a typical
    # point (norm about √(k/3)) at the median boundary the rays found, so the sample straddles it.
    ts = [b.t for b in boundary if isfinite(b.t)]
    scale = isempty(ts) ? 1.0 : clamp(median(ts) / sqrt(k / 3), 0.01, 1.0)
    (limits = limits, boundary = boundary, screen_scale = scale,
     screening = screen_n > 0 ? screen(oracle, scale .* gaussian_hypercube(rng, screen_n, k; μ = 0.5, σ = 0.25)) : nothing)
end

"The commit checked out now; batteries read it when they start, so results name the code they ran."
function current_commit()
    try
        readchomp(`git -C $(@__DIR__) rev-parse --short HEAD`)
    catch
        "unknown"
    end
end

"""
    write_results(label, bt, names; clean, minutes, commit, dir = sim/battery/results)

Write a battery's results to `<dir>/<label>.csv` (one row per ray: kind, direction,
boundary severity, monotone) and `<label>.md` (limits, failure rate, factor importance, the
strongest interactions, the boundary points nearest the clean world, and PRIM failure boxes over
the screened worlds).
"""
function write_results(label, bt, names; clean, minutes, commit = current_commit(), dir = joinpath(@__DIR__, "..", "battery", "results"))
    mkpath(dir)
    open(joinpath(dir, label * ".csv"), "w") do io
        println(io, "# commit ", commit)
        println(io, join(["kind"; names; "t"; "monotone"], ","))
        for (j, n) in enumerate(names)
            println(io, join(["axis"; [k == j ? "1" : "0" for k in eachindex(names)]; string(bt.limits[n]); "true"], ","))
        end
        for b in bt.boundary
            println(io, join(["ray"; [@sprintf("%.3f", x) for x in b.direction]; string(b.t); string(b.monotone)], ","))
        end
    end
    sc = bt.screening
    order = sortperm(sc.importance; rev = true)
    pairs = sort(collect(sc.pairs); by = x -> -abs(x[2]))
    near = sort(filter(b -> isfinite(b.t), bt.boundary); by = b -> b.t)
    open(joinpath(dir, label * ".md"), "w") do io
        println(io, "# Failure-boundary battery: ", label, "\n")
        println(io, "Build: commit ", commit, " (with any uncommitted changes at the time).\n")
        isnan(clean) || println(io, @sprintf("Clean world's floor growth: %.1f. ", clean))
        println(io, @sprintf("Run time %.1f minutes; %d random rays; %d screened worlds (severities up to %.2f), %.0f%% failing.\n",
                             minutes, length(bt.boundary), length(sc.fails), bt.screen_scale, 100 * sc.fail_rate))
        println(io, "## Limits along one factor (severity 1 = top of the explored range)\n")
        println(io, "| Factor | Fails beyond |\n|---|---|")
        for n in names
            println(io, "| ", n, " | ", isfinite(bt.limits[n]) ? @sprintf("%.2f", bt.limits[n]) : "not within 2", " |")
        end
        println(io, "\n## Importance in screening (mean severity in failing worlds less in converging ones)\n")
        println(io, "| Factor | Importance |\n|---|---|")
        for j in order
            println(io, "| ", names[j], " | ", @sprintf("%.3f", sc.importance[j]), " |")
        end
        println(io, "\n## Strongest interactions (failure rate when both are high, beyond each alone)\n")
        println(io, "| Pair | Interaction |\n|---|---|")
        for ((a, b), v) in pairs[1:min(8, length(pairs))]
            println(io, "| ", names[a], " × ", names[b], " | ", @sprintf("%+.3f", v), " |")
        end
        println(io, "\n## Nearest failures on random rays (severity per factor at the boundary)\n")
        println(io, "| t | ", join(names, " | "), " | monotone |\n|", repeat("---|", length(names) + 2))
        for b in near[1:min(8, length(near))]
            println(io, "| ", @sprintf("%.2f", b.t), " | ", join([@sprintf("%.2f", x) for x in b.point], " | "), " | ", b.monotone, " |")
        end
        nm = count(b -> !b.monotone, bt.boundary)
        println(io, "\nNon-monotone rays (converging again beyond the boundary): ", nm, " of ", length(bt.boundary), ".")
        write_boxes(io, prim_boxes(sc.X, sc.fails; min_support = max(0.05, 3 / length(sc.fails))), names, length(sc.fails);
                    title = "Failure boxes (PRIM over the screened worlds)")
    end
end

"Readable PRIM boxes, one line each: the restricted severities, then how many worlds, how densely failing, what share of failures."
function write_boxes(io, boxes, names, npoints; title)
    println(io, "\n## ", title, "\n")
    if isempty(boxes)
        println(io, "No failing world, so no box.")
        return
    end
    println(io, "Each box: the severities where failure concentrates (Friedman & Fisher 1999; restrictions that do not ",
            "raise the failure density beyond noise are trimmed); its worlds, the share of them failing, and its share of all failures.\n")
    for (i, b) in enumerate(boxes)
        println(io, i, ". ", describe_box(b, names), @sprintf(": %d of %d worlds, %.0f%% failing, %.0f%% of failures.",
                                                          b.n, npoints, 100b.density, 100b.coverage))
    end
end

"""
    battery_methods(reading, names; rng, outputs, pool, sobol_n, sobol_top, active_budget, n_init = 10) -> results

The battery's continuous methods. `reading(sev)` returns `(outputs, n)`: the success pattern's
continuous readings at severities `sev` (`outputs[1]` the margin, negative where the world fails),
averaged over `n` seeds chosen by variance stability. Sobol indices of every output over severities
uniform in [0, `sobol_top`] (`sobol_n` rows; 0 skips), and active learning of the margin's zero over
the candidate worlds `pool` (`active_budget` evaluations; 0 skips), with PRIM boxes of the
surrogate's verdict on the pool. Seeds used per evaluation are kept for each method.
"""
function battery_methods(reading, names; rng::AbstractRNG, outputs, pool, sobol_n::Integer, sobol_top::Real,
                         active_budget::Integer, n_init::Integer = 10)
    k = length(names)
    check(size(pool, 2) == k && sobol_top > 0, "a pool over the factors; a positive Sobol range")
    seeds_sobol, seeds_active = Int[], Int[]
    take(sev, log) = (r = reading(sev); push!(log, r.n); Float64.(r.outputs))
    sob = sobol_n > 0 ? sobol_indices(u -> take(sobol_top .* u, seeds_sobol), k; N = sobol_n, rng) : nothing
    act = active_budget > 0 ? active_boundary(x -> take(x, seeds_active)[1], pool; rng, n_init = min(n_init, active_budget),
                                              budget = active_budget) : nothing
    boxes = act === nothing || !any(act.predicted_fail) ? [] :
            prim_boxes(pool, act.predicted_fail; min_support = max(0.05, 3 / size(pool, 1)))
    (sobol = sob, active = act, active_boxes = boxes, pool = pool, outputs = collect(outputs), sobol_top = sobol_top,
     seeds_sobol = seeds_sobol, seeds_active = seeds_active)
end

"""
    write_methods(label, m, names; seed_rule, screen_fail_rate, minutes, dir = sim/battery/results)

Append the continuous methods' results (`battery_methods`) to `<dir>/<label>.md`, after
what `write_results` wrote, and write `<label>_sobol.csv` and `<label>_active.csv`.
"""
function write_methods(label, m, names; seed_rule, screen_fail_rate, minutes, dir = joinpath(@__DIR__, "..", "battery", "results"))
    mkpath(dir)
    seedline(v) = isempty(v) ? "" : @sprintf(" Seeds per world: mean %.1f, %d of %d worlds at the cap.", mean(v), count(==(maximum(v)), v), length(v))
    open(joinpath(dir, label * ".md"), "a") do io
        println(io, @sprintf("\n## Continuous methods (run time %.1f minutes)\n", minutes))
        println(io, "Readings are the success pattern's continuous margin (each criterion scaled so the clean world ",
                "reads 1 and the criterion's edge 0; the margin is the weakest), averaged over seeds 1, 2, … until ", seed_rule, ".")
        if m.sobol !== nothing
            s = m.sobol
            println(io, @sprintf("\n### Variance-based sensitivity (Sobol indices; severities uniform in [0, %.2f])\n", m.sobol_top))
            println(io, @sprintf("Saltelli et al. (2010) design, %d evaluations; 95%% bootstrap intervals. ", s.evaluations),
                    "S1: the share of the reading's variance a factor explains alone; ST: with all its interactions. ",
                    "ST well above S1 marks a factor acting through interactions; variance the seeds add is in no factor's S1.",
                    seedline(m.seeds_sobol), "\n")
            println(io, "| Factor | S1 (margin) | ST (margin) | ", join(["ST " * o for o in m.outputs[2:end]], " | "), " |")
            println(io, "|", repeat("---|", 3 + length(m.outputs) - 1))
            for j in sortperm(s.ST[1, :]; rev = true)
                println(io, "| ", names[j], " | ", @sprintf("%.2f [%.2f, %.2f]", s.S1[1, j], s.S1_lo[1, j], s.S1_hi[1, j]), " | ",
                        @sprintf("%.2f [%.2f, %.2f]", s.ST[1, j], s.ST_lo[1, j], s.ST_hi[1, j]), " | ",
                        join([@sprintf("%.2f", s.ST[o, j]) for o in 2:length(m.outputs)], " | "), " |")
            end
            println(io, @sprintf("\nSum of first-order indices (margin): %.2f; variance of the margin: %.3g.", sum(s.S1[1, :]), s.V[1]))
            open(joinpath(dir, label * "_sobol.csv"), "w") do c
                println(c, "output,factor,S1,S1_lo,S1_hi,ST,ST_lo,ST_hi")
                for o in eachindex(m.outputs), j in eachindex(names)
                    println(c, join([m.outputs[o], names[j], (@sprintf("%.4f", x) for x in (s.S1[o, j], s.S1_lo[o, j], s.S1_hi[o, j], s.ST[o, j], s.ST_lo[o, j], s.ST_hi[o, j]))...], ","))
                end
            end
        end
        if m.active !== nothing
            a = m.active
            println(io, "\n### Active learning of the failure boundary (AK-MCS)\n")
            println(io, @sprintf("A Gaussian-process surrogate of the margin chose %d of %d candidate worlds (drawn as the screening's), ",
                                 a.evaluations, size(m.pool, 1)),
                    "each where its sign was least certain (Echard, Gayton & Lemaire 2011). ",
                    @sprintf("Estimated failing share of the candidates: %.1f%% (screening: %.1f%%).", 100a.p_fail, 100screen_fail_rate),
                    seedline(m.seeds_active))
            write_boxes(io, m.active_boxes, names, size(m.pool, 1); title = "Failure boxes (PRIM over the surrogate's verdict on the candidates)")
            println(io, "\nEvaluated worlds nearest the boundary (smallest |margin|):\n")
            println(io, "| margin | ", join(names, " | "), " |\n|", repeat("---|", length(names) + 1))
            for i in sortperm(abs.(a.y))[1:min(8, length(a.y))]
                println(io, "| ", @sprintf("%+.2f", a.y[i]), " | ", join([@sprintf("%.2f", x) for x in a.X[i, :]], " | "), " |")
            end
            open(joinpath(dir, label * "_active.csv"), "w") do c
                println(c, join([names; "margin"], ","))
                for i in eachindex(a.y)
                    println(c, join([[@sprintf("%.4f", x) for x in a.X[i, :]]; @sprintf("%.4f", a.y[i])], ","))
                end
            end
        end
    end
end
