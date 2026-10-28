# Bridge to the Lean reference library: the rules live in `BenefutureReference` and are called
# through its C exports (`BenefutureReference/Export.lean`). The shared library is rebuilt only
# when the hash of the Lean sources differs from the hash stamped beside it, so loading the
# package never re-runs Lake when the rules are unchanged.

using Libdl, SHA

const REPO = normpath(joinpath(@__DIR__, "..", ".."))
const LIBFILE = joinpath(REPO, ".lake", "build", "lib", "libBenefuture_BenefutureReference.so")
const STAMP = LIBFILE * ".sha256"
const LIB = Ref{Ptr{Cvoid}}(C_NULL)
const SYMS = Dict{Symbol,Ptr{Cvoid}}()

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
    leanshared = Libdl.dlopen(joinpath(runtime, "libleanshared.so"), Libdl.RTLD_GLOBAL)
    Libdl.dlopen(joinpath(runtime, "libInit_shared.so"), Libdl.RTLD_GLOBAL)
    ccall(Libdl.dlsym(leanshared, :lean_initialize_runtime_module), Cvoid, ())
    LIB[] = Libdl.dlopen(LIBFILE, Libdl.RTLD_GLOBAL)
    # Second argument is Lean's IO world token, the boxed unit.
    ccall(Libdl.dlsym(LIB[], :initialize_Benefuture_BenefutureReference), Ptr{Cvoid},
          (UInt8, Ptr{Cvoid}), 1, Ptr{Cvoid}(1))
    empty!(SYMS)
    nothing
end

sym(name::Symbol) = get!(() -> Libdl.dlsym(LIB[], name), SYMS, name)

"Build a Lean `FloatArray`; ownership passes to the Lean call that receives it."
function floatarray(xs)
    a = ccall(sym(:bf_fa_mk), Ptr{Cvoid}, (Csize_t,), length(xs))
    for x in xs
        a = ccall(sym(:bf_fa_push), Ptr{Cvoid}, (Ptr{Cvoid}, Float64), a, Float64(x))
    end
    a
end
