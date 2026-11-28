# Bridge to the Lean reference library: the rules live in `BenefutureReference` and are called
# through its C exports (`BenefutureReference/Export.lean`). The shared library is rebuilt only
# when the hash of the Lean sources differs from the hash stamped beside it, so loading the
# package never re-runs Lake when the rules are unchanged.

using Libdl, SHA

const REPO = normpath(joinpath(@__DIR__, "..", ".."))
const SO_EXT = Sys.isapple() ? ".dylib" : ".so"
const LIBFILE = joinpath(REPO, ".lake", "build", "lib", "libBenefuture_BenefutureReference" * SO_EXT)
const STAMP = LIBFILE * ".sha256"
const LIB = Ref{Ptr{Cvoid}}(C_NULL)
const SYMS = Ref(Dict{Symbol,Ptr{Cvoid}}())
const SYMS_LOCK = ReentrantLock()

# Opt-in call tracing (BF_TRACE_CALLS=path): every `@lccall` Lean call logs its name, inputs and outputs
# (Float64 as hex bit patterns, FloatArrays element-wise), and `trace_mark` writes step markers with state
# hashes, to the file. Diagnostic only: when the variable is unset the only cost is one `TRACE_CALLS[]` read
# per call and no behaviour changes (probe hash identical with and without; see tools/determinism).
const TRACE_CALLS = Ref(false)
const TRACE_IO = Ref{Union{IO,Nothing}}(nothing)
const TRACE_SEQ = Ref(0)

function trace_init()
    path = get(ENV, "BF_TRACE_CALLS", "")
    TRACE_CALLS[] = false
    if !isempty(path)
        TRACE_IO[] = open(path, "w")
        TRACE_SEQ[] = 0
        TRACE_CALLS[] = true
        atexit(() -> (io = TRACE_IO[]; io === nothing || (flush(io); close(io); TRACE_IO[] = nothing; TRACE_CALLS[] = false)))
    end
    nothing
end

trace_hex(x::Float64) = string(reinterpret(UInt64, x), base = 16, pad = 16)
trace_hex(x::Integer) = string(x)
trace_hex(x::Ptr) = x == C_NULL ? "null" : (UInt(x) & 1) == 1 ? "box" * string(UInt(x)) : "[" * join(trace_hex.(lean_floats_peek(x)), ",") * "]"
trace_hex(x) = string(x)

# Non-destructive read of a FloatArray: lean_floats releases one reference, so take an extra one first.
lean_floats_peek(a::Ptr{Cvoid}) = lean_floats(lean_inc!(a))

trace_ins(args...) = map(trace_hex, args)

function trace_call(name, ins, out)
    io = TRACE_IO[]; io === nothing && return nothing
    TRACE_SEQ[] += 1
    println(io, "C ", TRACE_SEQ[], " ", name, " in=", join(ins, ";"), " out=", trace_hex(out))
    nothing
end

"Generator state, for trace marks."
rngsig(r::DetRNG) = UInt64[r.s0, r.s1, r.s2, r.s3, UInt64(r.has_spare), reinterpret(UInt64, r.spare)]
rngsig(r::Random.AbstractRNG) = UInt64[getfield(r, i) for i in 1:fieldcount(typeof(r))]

"Step marker with a state hash: `tag`, then the values hashed (Float64 arrays by bit pattern)."
function trace_mark(tag, vals...)
    TRACE_CALLS[] || return nothing
    io = TRACE_IO[]; io === nothing && return nothing
    part(v) = v isa AbstractArray ? join(map(x -> x isa AbstractFloat ? trace_hex(Float64(x)) : string(x), vec(v)), ",") : v isa AbstractFloat ? trace_hex(Float64(v)) : string(v)
    ps = [part(v) for v in vals]
    h(x) = bytes2hex(SHA.sha256(x))[1:12]
    println(io, "S ", tag, " ", h(join(ps, ";")), " parts=", join(h.(ps), ","))
    nothing
end

"`ccall` for a Lean export, traced when BF_TRACE_CALLS is set: `@lccall(sym(:f), RT, (T...), args...)`."
macro lccall(f, rt, types, args...)
    name = f isa Expr && f.head === :call && f.args[1] === :sym && f.args[2] isa QuoteNode ? string(f.args[2].value) : string(f)
    tmps = [gensym(:a) for _ in args]
    out = gensym(:r); ins = gensym(:ins)
    esc(quote
        if TRACE_CALLS[]
            $([:($t = $a) for (t, a) in zip(tmps, args)]...)
            $ins = trace_ins($(tmps...))
            $out = ccall($f, $rt, $types, $(tmps...))
            trace_call($name, $ins, $out)
            $out
        else
            ccall($f, $rt, $types, $(args...))
        end
    end)
end

function tool(name)
    path = Sys.which(name)
    path === nothing || return path
    fallback = joinpath(homedir(), ".elan", "bin", name)
    isfile(fallback) && return fallback
    error("`$name` not found; run tools/setup/toolchains.sh")
end

function lean_sources()
    dir = joinpath(REPO, "BenefutureReference")
    files = ["BenefutureReference.lean", "lean-toolchain", "lakefile.toml"]
    append!(files, sort!([joinpath("BenefutureReference", f) for f in readdir(dir) if endswith(f, ".lean")]))
    files
end

function source_hash()
    ctx = SHA.SHA256_CTX()
    for f in lean_sources()
        SHA.update!(ctx, Vector{UInt8}(f))
        SHA.update!(ctx, read(joinpath(REPO, f)))
    end
    bytes2hex(SHA.digest!(ctx))
end

"""
    ensure_lean_lib() -> Symbol

`:fresh` when the shared library matches the current Lean sources, otherwise builds it with Lake
and returns `:built`.
"""
function ensure_lean_lib()
    h = source_hash()
    isfile(LIBFILE) && isfile(STAMP) && read(STAMP, String) == h && return :fresh
    run(Cmd(`$(tool("lake")) build BenefutureReference:shared`; dir = REPO))
    write(STAMP, h)
    :built
end

function load_lean_lib()
    ensure_lean_lib()
    prefix = strip(read(Cmd(`$(tool("lean")) --print-prefix`; dir = REPO), String))
    runtime = joinpath(prefix, "lib", "lean")
    for name in ("libleanshared_2", "libleanshared_1", "libleanshared", "libInit_shared", "libLake_shared")
        p = joinpath(runtime, name * SO_EXT)
        isfile(p) && Libdl.dlopen(p, Libdl.RTLD_GLOBAL)
    end
    leanshared = Libdl.dlopen(joinpath(runtime, "libleanshared" * SO_EXT), Libdl.RTLD_GLOBAL)
    ccall(Libdl.dlsym(leanshared, :lean_initialize_runtime_module), Cvoid, ())
    LIB[] = Libdl.dlopen(LIBFILE, Libdl.RTLD_GLOBAL)
    # Second argument is Lean's IO world token, the boxed unit.
    ccall(Libdl.dlsym(LIB[], :initialize_Benefuture_BenefutureReference), Ptr{Cvoid},
          (UInt8, Ptr{Cvoid}), 1, Ptr{Cvoid}(1))
    lock(SYMS_LOCK) do
        SYMS[] = Dict{Symbol,Ptr{Cvoid}}()
    end
    trace_init()
    nothing
end

function sym(name::Symbol)
    p = get(SYMS[], name, C_NULL)
    p != C_NULL && return p
    lock(SYMS_LOCK) do
        d = copy(SYMS[])
        p2 = get!(() -> Libdl.dlsym(LIB[], name), d, name)
        SYMS[] = d
        return p2
    end
end

"Build a Lean `FloatArray`; ownership passes to the Lean call that receives it."
function floatarray(xs)
    n = length(xs)
    a = ccall(sym(:bf_fa_mk), Ptr{Cvoid}, (Csize_t,), n)
    if n > 0 && unsafe_load(Ptr{Csize_t}(a + 16)) >= n && unsafe_load(Ptr{Csize_t}(a + 8)) == 0
        # Bulk fill: write the doubles into the reserved buffer and set `m_size` (same bytes as n pushes
        # that never reallocate; layout as in `lean_floats`).
        p = Ptr{Float64}(a + 24)
        i = 0
        for x in xs
            unsafe_store!(p, Float64(x), (i += 1))
        end
        unsafe_store!(Ptr{Csize_t}(a + 8), Csize_t(i))
        i == n || error("floatarray: length changed during fill")
        return a
    end
    p_push = sym(:bf_fa_push)
    for x in xs
        a = ccall(p_push, Ptr{Cvoid}, (Ptr{Cvoid}, Float64), a, Float64(x))
    end
    a
end

lean_det_exp(x::Real) = @lccall(sym(:bf_det_exp), Float64, (Float64,), Float64(x))
lean_det_log(x::Real) = @lccall(sym(:bf_det_log), Float64, (Float64,), Float64(x))
lean_det_log1p(x::Real) = @lccall(sym(:bf_det_log1p), Float64, (Float64,), Float64(x))
lean_det_pow(x::Real, y::Real) = @lccall(sym(:bf_det_pow), Float64, (Float64, Float64), Float64(x), Float64(y))
