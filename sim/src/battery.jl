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
    screen(oracle, X) -> (fails, fail_rate, importance, pairs)

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
    (fails = fails, fail_rate = mean(fails), importance = importance, pairs = pairs)
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
    # Screen where the boundary lies: scale the hypercube so its typical point (norm √(k/3)) sits at
    # the median boundary the rays found, so the sample straddles it.
    ts = [b.t for b in boundary if isfinite(b.t)]
    scale = isempty(ts) ? 1.0 : clamp(median(ts) / sqrt(k / 3), 0.01, 1.0)
    (limits = limits, boundary = boundary, screen_scale = scale,
     screening = screen_n > 0 ? screen(oracle, scale .* latin_hypercube(rng, screen_n, k)) : nothing)
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
    write_results(label, bt, names; clean, minutes, commit)

Write a battery's results to `sim/battery/results/<label>.csv` (one row per ray: kind, direction,
boundary severity, monotone) and `<label>.md` (limits, failure rate, factor importance, the
strongest interactions, and the boundary points nearest the clean world).
"""
function write_results(label, bt, names; clean, minutes, commit = current_commit())
    dir = joinpath(@__DIR__, "..", "battery", "results")
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
    end
end
