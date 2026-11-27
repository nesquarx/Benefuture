# Determinism probe (red test: asserts the outcome, bit-identical traces across environments).
# Usage: julia [-t N] [--check-bounds=yes] --project=sim tools/determinism/trace_probe.jl OUT.json [seeds=1,2]
# Writes JSON: environment, and for each world and seed, every trace quantity as {n, hash, bits}
# (bits as hex of the Float64 pattern, full for short quantities, so compare.py can name the first
# divergent step and value), plus a Lean-call sweep recording raw inputs and outputs of each ccall.
using BenefutureSim, JSON, SHA, Random, Libdl
const BS = BenefutureSim

hexf(x::Float64) = string(reinterpret(UInt64, x), base = 16, pad = 16)
hexf(x::Integer) = string(x)
hexf(x::Bool) = x ? "1" : "0"
hexf(x::Symbol) = String(x)
hexf(x::AbstractString) = String(x)

function flat!(out, x, path)
    if x isa Number || x isa Symbol || x isa AbstractString
        out[path] = [hexf(x isa Float32 ? Float64(x) : x)]
    elseif x isa AbstractArray && eltype(x) <: Union{Number,Bool}
        out[path] = hexf.(vec(eltype(x) <: AbstractFloat ? Float64.(x) : x))   # column-major: steps are the last axis
        size(x, 1) > 0 && ndims(x) == 2 && (out[path*"#cols"] = [string(size(x, 2))])
    elseif x isa AbstractArray
        for (i, e) in enumerate(x); flat!(out, e, "$path[$i]"); end
    elseif x isa Tuple
        for (i, e) in enumerate(x); flat!(out, e, "$path[$i]"); end
    elseif x isa NamedTuple
        for k in keys(x); flat!(out, x[k], "$path.$k"); end
    elseif x isa AbstractDict
        for k in sort!(collect(keys(x)); by = string); flat!(out, x[k], "$path{$k}"); end
    elseif x isa Ref
        flat!(out, x[], path)
    elseif x !== nothing && !(x isa Function) && isstructtype(typeof(x)) && fieldcount(typeof(x)) > 0
        for f in fieldnames(typeof(x)); flat!(out, getfield(x, f), "$path.$f"); end
    end
    out
end

function summarise(tr)
    out = flat!(Dict{String,Vector{String}}(), tr, "")
    Dict(k => Dict("n" => length(v), "hash" => bytes2hex(sha256(join(v, ","))), "bits" => v) for (k, v) in out)
end

# --- worlds -------------------------------------------------------------------------------------
function m3c(; hidden = Int[], work = [1], n_agents = 6, skill = 0.6, steps = 200, kw...)   # as sim/test/m3c_tests.jl
    leaf_parent = [1, 1, 2, 2, hidden...]; nl = length(leaf_parent)
    agents = [DomainAgent([l in work ? skill : 0.0 for l in 1:nl], [l in work ? 1 / length(work) : 0.0 for l in 1:nl], 0.0) for _ in 1:n_agents]
    M3cParams(ToyParams(n = 80, steps = steps, plans = 10), agents, leaf_parent, [trues(4); falses(length(hidden))]; λpos = 0.05, λneg = 0.02, kw...)
end
world_m3d(seed) = run_m3c(m3c(work = [1, 3], transactions = true); seed)

function world_p60(seed)   # as sim/test/probe_tests.jl, P60, binding on
    agents = [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 11 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:12]
    na, nn, ns = 48, 6, 12
    deceit = zeros(na); deceit[(na - ns + 1):na] .= 0.924
    econ = M3cParams(ToyParams(n = 30, steps = 75, plans = 6), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true,
                     causal_distribution = true, init_steps = 10, guardians = [1, 13, 25, 37], diligence = fill(0.9, na), deceit = deceit, overflow_base = 10.0)
    gov(tr) = M5Params(tr, 1:4; decisions = 1, deliberation = true, info_handling = true, source_tags = true, ih_vote = true, p_delegate = 0.2)
    up = UnifiedParams(liar_community = 1, identity = IdentityParams(newcomers = nn, sybils = ns, binding = true), economy = true, fractal = FractalParams())
    run_coupled(econ, gov; seed, epoch = 25, coupled = false, continuous = true, m5_decisions = 30, unified = up)
end

# --- Lean-heavy sweep: fixed inputs, raw inputs and outputs of each ccall ---------------------------
function lean_sweep()
    calls = Vector{Any}()
    rec(name, ins, outs) = push!(calls, Dict("call" => name, "in" => hexf.(Float64.(ins)), "out" => hexf.(Float64.(outs))))
    rng = Xoshiro(7)
    for i in 1:40
        s = rand(rng, 4); s ./= sum(s)
        for (pos, neg) in ((1.1, 1.5), (0.7, 2.3))
            a = BS.attribute(s, 1.0, pos, neg); rec("attribute", [s; 1.0; pos; neg], [a[1]; a[2]])
        end
        d = 3 .* rand(rng, 5)
        for (thr, T) in ((0.8, 0.3), (2.0, 1.0))
            rec("classify", [d; thr; T], BS.classify(d, threshold = thr, temperature = T))
        end
        sg = 4 * randn(rng); rec("decay_rate_for", [sg, 0.05, 0.02], [BS.decay_rate_for(sg; λpos = 0.05, λneg = 0.02)])
        rec("accumulation_threshold", [1.0, 0.5, 20 * rand(rng)], [BS.accumulation_threshold(1.0, 0.5, 20 * rand(Xoshiro(i)))])
    end
    # Julia-side numerics that depend on the host: libm-backed pow, SIMD sums, exp/log
    for n in (4, 8, 16, 31, 32, 64, 200)
        y = randn(Xoshiro(n), n); rec("jl_sum", [n], [sum(y), sum(abs2, y), sum(y .* y)])
    end
    xs = [0.001, 0.37, 1.7, 12.5, 55.5]
    rec("jl_exp_log_pow", xs, vcat(exp.(xs), log.(xs), xs .^ 0.37, xs .^ 2.5, log1p.(xs)))
    calls
end

function main()
    out = ARGS[1]
    seeds = length(ARGS) >= 2 ? parse.(Int, split(ARGS[2], ",")) : [1, 2]
    env = Dict("julia" => string(VERSION), "threads" => Threads.nthreads(), "os" => string(Sys.KERNEL), "arch" => string(Sys.ARCH),
               "cpu" => Sys.CPU_NAME, "check_bounds" => Int(Base.JLOptions().check_bounds), "opt" => Int(Base.JLOptions().opt_level),
               "blas" => string(BS.LinearAlgebra.BLAS.get_config().loaded_libs), "lean_lib_sha" => (isfile(BS.STAMP) ? strip(read(BS.STAMP, String)) : ""))
    res = Dict{String,Any}("env" => env, "worlds" => Dict{String,Any}())
    for (name, f) in (("m3d", world_m3d), ("p60", world_p60)), s in seeds
        @info "running" name s
        res["worlds"]["$name/seed$s"] = summarise(f(s))
    end
    res["lean_sweep"] = lean_sweep()
    open(out, "w") do io; JSON.print(io, res); end
    h = bytes2hex(sha256(join((k * ":" * join(sort(collect(v), by = first) .|> p -> p[1] * p[2]["hash"], ";") for (k, v) in sort(collect(res["worlds"]), by = first)), "|")))
    println("probe_hash ", h[1:16], " lean_sweep ", bytes2hex(sha256(JSON.json(res["lean_sweep"])))[1:16], " ", env["julia"], " t", env["threads"], " cb", env["check_bounds"])
end
main()
