# Cross-platform deterministic numerics layer for BenefutureSim.
# Loaded first inside `module BenefutureSim` (before `lean.jl` and model files) so that:
#   1. All RNG streams (`DetRNG`, shadowed `Xoshiro`, `stream_seed`, `stream_int_seed`) use explicit
#      splitmix64 + Xoshiro256++ + Marsaglia polar `randn` with UTF-8 deterministic tag hashing
#      (invariant across Julia versions, platforms, and thread counts).
#   2. Software transcendentals (`det_exp`, `det_log_dd`, `det_log`, `det_log1p`, `det_log2`,
#      `det_pow`, `det_hypot`) are bit-identical to `BenefutureReference/FloatDet.lean`.
#   3. Left-to-right sequential reductions (`sum`, `mean`, `var`, `std`, `dot`, `cor`) and
#      explicit matrix-vector loops (`det_matvec`, `det_matvec_t`) eliminate SIMD vector-width
#      and BLAS reordering drift across SSE2, AVX2, Apple M1 NEON, and `-C generic`.

const POS_INF_F = reinterpret(Float64, 0x7ff0000000000000)
const NEG_INF_F = reinterpret(Float64, 0xfff0000000000000)
const NAN_F     = reinterpret(Float64, 0x7ff8000000000000)

const _FD_LN2_HI   = reinterpret(Float64, 0x3fe62e42fee00000)
const _FD_LN2_LO   = reinterpret(Float64, 0x3dea39ef35793c76)
const _FD_INV_LN2  = reinterpret(Float64, 0x3ff71547652b82fe)
const _FD_LN2_H26  = reinterpret(Float64, 0x3fe62e42f8000000)
const _FD_LN2_L26  = reinterpret(Float64, 0x3e4be8e7bcd5e4f2)
const _FD_LN2_FULL = reinterpret(Float64, 0x3fe62e42fefa39ef)
const _FD_INVLN2_H = reinterpret(Float64, 0x3ff7154760000000)
const _FD_INVLN2_L = reinterpret(Float64, 0x3e54ae0bf85ddf44)
const _FD_TWO54    = reinterpret(Float64, 0x4350000000000000)
const _FD_SUB2M512 = reinterpret(Float64, 0x1ff0000000000000)

const _FD_EXP_P1 = reinterpret(Float64, 0x3fc555555555553e)
const _FD_EXP_P2 = reinterpret(Float64, 0xbf66c16c16bebd93)
const _FD_EXP_P3 = reinterpret(Float64, 0x3f11566aaf25de2c)
const _FD_EXP_P4 = reinterpret(Float64, 0xbebbbd41c5d26bf1)
const _FD_EXP_P5 = reinterpret(Float64, 0x3e66376972bea4d0)

const _FD_LG1 = reinterpret(Float64, 0x3fe5555555555593)
const _FD_LG2 = reinterpret(Float64, 0x3fd999999997fa04)
const _FD_LG3 = reinterpret(Float64, 0x3fd2492494229359)
const _FD_LG4 = reinterpret(Float64, 0x3fcc71c51d8e78af)
const _FD_LG5 = reinterpret(Float64, 0x3fc7466496cb03de)
const _FD_LG6 = reinterpret(Float64, 0x3fc39a09d078c69f)
const _FD_LG7 = reinterpret(Float64, 0x3fc2f112df3e5244)

@inline _pow2_norm(k::Int64) = reinterpret(Float64, UInt64(k + Int64(1023)) << 52)
@inline _det_abs(x::Float64) = reinterpret(Float64, reinterpret(UInt64, x) & 0x7fffffffffffffff)

@inline function _ldexp_step(m::Float64, e::Int64)
    e == 0 && return m, Int64(0)
    if e > 0
        s = e > 1023 ? Int64(1023) : e
        return m * _pow2_norm(s), e - s
    else
        e >= -1022 && return m * _pow2_norm(e), Int64(0)
        _det_abs(m) >= 1.0 && return m * _pow2_norm(Int64(-1022)), e + Int64(1022)
        _det_abs(m) < _FD_SUB2M512 && return m * 0.0, Int64(0)
        return m * _pow2_norm(Int64(-510)), e + Int64(510)
    end
end

"Scale `x` by `2^e` using exact IEEE-754 binary64 power-of-2 multiplications."
function det_ldexp(x::Float64, e::Int64)
    (x == 0.0 || isnan(x) || isinf(x) || e == 0) && return x
    e0 = e > 2200 ? Int64(2200) : (e < -2200 ? Int64(-2200) : e)
    (-1022 <= e0 && e0 <= 1023) && return x * _pow2_norm(e0)
    m1, e1 = _ldexp_step(x, e0)
    m2, e2 = _ldexp_step(m1, e1)
    m3, _  = _ldexp_step(m2, e2)
    return m3
end

@inline function _fd_scale2(y::Float64, k::Int64)
    if k >= -1021 && k <= 1023
        return y * _pow2_norm(k)
    elseif k > 1023
        s = k > 1535 ? Int64(1535) : k
        return (y * _pow2_norm(Int64(512))) * _pow2_norm(s - Int64(512))
    elseif k < -1075
        return 0.0
    else
        return (y * _pow2_norm(Int64(-512))) * _pow2_norm(k + Int64(512))
    end
end

@inline function _fd_exp_kernel(hi::Float64, lo::Float64, k::Int64)
    r = hi - lo
    t = r * r
    c = r - t * (_FD_EXP_P1 + t * (_FD_EXP_P2 + t * (_FD_EXP_P3 + t * (_FD_EXP_P4 + t * _FD_EXP_P5))))
    y = 1.0 - ((lo - (r * c) / (2.0 - c)) - hi)
    return _fd_scale2(y, k)
end

@inline function _fd_exp2_dd(xhi::Float64, xlo::Float64)
    isnan(xhi) && return xhi
    xhi >= 1024.0 && return POS_INF_F
    xhi <= -1075.0 && return 0.0
    kf = floor(xhi + 0.5)
    k = unsafe_trunc(Int64, kf)
    dx = xhi - kf
    f = dx + xlo
    f == 0.0 && return _fd_scale2(1.0, k)
    fh = reinterpret(Float64, reinterpret(UInt64, f) & 0xfffffffff8000000)
    fl = (dx - fh) + xlo
    return _fd_exp_kernel(fh * _FD_LN2_H26, -(fl * _FD_LN2_FULL + fh * _FD_LN2_L26), k)
end

"Deterministic `exp(x)` bit-identical to `FloatDet.det_exp`."
function det_exp(x::Float64)
    isnan(x) && return x
    x >= reinterpret(Float64, 0x40862e42fefa39ef) && return POS_INF_F
    x <= reinterpret(Float64, 0xc0874910d52d3052) && return 0.0
    _det_abs(x) < reinterpret(Float64, 0x3e30000000000000) && return 1.0 + x
    kf = floor(x * _FD_INV_LN2 + 0.5)
    k = unsafe_trunc(Int64, kf)
    return _fd_exp_kernel(x - kf * _FD_LN2_HI, kf * _FD_LN2_LO, k)
end
det_exp(x::Real) = det_exp(Float64(x))

@inline function _det_log_pos_add(x::Float64, extra::Float64)
    u0 = reinterpret(UInt64, x)
    biased = u0 >>> 52
    u = biased == 0 ? reinterpret(UInt64, x * _FD_TWO54) : u0
    k0 = Int64(u >>> 52) - (biased == 0 ? Int64(1077) : Int64(1023))
    frac = u & 0x000fffffffffffff
    m0 = reinterpret(Float64, frac | 0x3ff0000000000000)
    hi = frac >= 0x0006a09e667f3bcd
    m = hi ? m0 * 0.5 : m0
    k = hi ? k0 + Int64(1) : k0
    f = m - 1.0
    s = f / (2.0 + f)
    z = s * s
    w = z * z
    t1 = w * (_FD_LG2 + w * (_FD_LG4 + w * _FD_LG6))
    t2 = z * (_FD_LG1 + w * (_FD_LG3 + w * (_FD_LG5 + w * _FD_LG7)))
    hfsq = 0.5 * f * f
    dk = Float64(k)
    return dk * _FD_LN2_HI - ((hfsq - (s * (hfsq + (t2 + t1)) + (dk * _FD_LN2_LO + extra))) - f)
end

"Deterministic natural logarithm `(hi, 0.0)` wrapper."
det_log_dd(x::Float64) = (det_log(x), 0.0)

"Deterministic `log(x)` bit-identical to `FloatDet.det_log`."
function det_log(x::Float64)
    isnan(x) && return x
    x < 0.0 && return NAN_F
    x == 0.0 && return NEG_INF_F
    isinf(x) && return POS_INF_F
    x == 1.0 && return 0.0
    return _det_log_pos_add(x, 0.0)
end
det_log(x::Real) = det_log(Float64(x))

"Deterministic `log(1 + x)` bit-identical to `FloatDet.det_log1p`."
function det_log1p(x::Float64)
    isnan(x) && return x
    x < -1.0 && return NAN_F
    x == -1.0 && return NEG_INF_F
    isinf(x) && return POS_INF_F
    x == 0.0 && return x
    ax = _det_abs(x)
    if ax < reinterpret(Float64, 0x3fd2bec333018866)
        s = x / (2.0 + x)
        z = s * s
        w = z * z
        t1 = w * (_FD_LG2 + w * (_FD_LG4 + w * _FD_LG6))
        t2 = z * (_FD_LG1 + w * (_FD_LG3 + w * (_FD_LG5 + w * _FD_LG7)))
        hfsq = 0.5 * x * x
        return x - (hfsq - s * (hfsq + (t2 + t1)))
    elseif x > reinterpret(Float64, 0x4b24e1878814c9ce)
        return det_log(x)
    else
        u = 1.0 + x
        c = ax <= 1.0 ? x - (u - 1.0) : 1.0 - (u - x)
        return _det_log_pos_add(u, c / u)
    end
end
det_log1p(x::Real) = det_log1p(Float64(x))

@inline function _det_log2_dd(x::Float64)
    u0 = reinterpret(UInt64, x)
    biased = u0 >>> 52
    u = biased == 0 ? reinterpret(UInt64, x * _FD_TWO54) : u0
    k0 = Int64(u >>> 52) - (biased == 0 ? Int64(1077) : Int64(1023))
    frac = u & 0x000fffffffffffff
    m0 = reinterpret(Float64, frac | 0x3ff0000000000000)
    hi = frac >= 0x0006a09e667f3bcd
    m = hi ? m0 * 0.5 : m0
    exp_k = hi ? k0 + Int64(1) : k0
    f = m - 1.0
    tf = 2.0 + f
    s = f / tf
    s2 = s * s
    s4 = s2 * s2
    t1 = s4 * (_FD_LG2 + s4 * (_FD_LG4 + s4 * _FD_LG6))
    t2 = s2 * (_FD_LG1 + s4 * (_FD_LG3 + s4 * (_FD_LG5 + s4 * _FD_LG7)))
    r_poly = t2 + t1
    sh = reinterpret(Float64, reinterpret(UInt64, s) & 0xfffffffff8000000)
    th = reinterpret(Float64, reinterpret(UInt64, tf) & 0xfffffffff8000000)
    tl = f - (th - 2.0)
    sl = (f - sh * th - sh * tl) / tf
    uh = 2.0 * sh
    ul = 2.0 * sl + s * r_poly
    lh = uh * _FD_INVLN2_H
    ll = ul * _FD_INVLN2_H + (uh + ul) * _FD_INVLN2_L
    dk = Float64(exp_k)
    tot_h = dk + lh
    comp = _det_abs(dk) >= _det_abs(lh) ? (dk - tot_h) + lh : (lh - tot_h) + dk
    tot_l = ll + comp
    return tot_h, tot_l
end

"Deterministic `log2(x)` from double-double FDLIBM reduction."
function det_log2(x::Float64)
    (isnan(x) || x <= 0.0 || isinf(x)) && return det_log(x)
    x == 1.0 && return 0.0
    h, l = _det_log2_dd(x)
    return h + l
end
det_log2(x::Real) = det_log2(Float64(x))

"Deterministic `x^y` bit-identical to `FloatDet.det_pow`."
function det_pow(x::Float64, y::Float64)
    y == 0.0 && return 1.0
    isnan(x) && return NAN_F
    isnan(y) && return (x == 1.0 ? 1.0 : NAN_F)
    x == 1.0 && return 1.0
    y == 1.0 && return x
    y == 2.0 && return x * x
    y == -1.0 && return 1.0 / x
    y == 0.5 && x >= 0.0 && return sqrt(x == 0.0 ? 0.0 : x)
    x == 2.0 && return _fd_exp2_dd(y, 0.0)
    if isinf(y)
        ax = _det_abs(x)
        ax == 1.0 && return 1.0
        return (ax > 1.0) == (y > 0.0) ? POS_INF_F : 0.0
    end
    yi = trunc(y)
    is_int = y == yi
    ayi = _det_abs(yi)
    is_odd = is_int && ayi < 9007199254740992.0 && ((unsafe_trunc(UInt64, ayi) & 1) != 0)
    if x == 0.0
        if y > 0.0
            return (is_odd && signbit(x)) ? -0.0 : 0.0
        else
            return (is_odd && signbit(x)) ? NEG_INF_F : POS_INF_F
        end
    end
    if isinf(x)
        if x > 0.0
            return y > 0.0 ? POS_INF_F : 0.0
        elseif y > 0.0
            return is_odd ? NEG_INF_F : POS_INF_F
        else
            return is_odd ? -0.0 : 0.0
        end
    end
    (x < 0.0 && !is_int) && return NAN_F
    sgn = (x < 0.0 && is_odd) ? -1.0 : 1.0
    ax = _det_abs(x)
    ax == 1.0 && return sgn
    if _det_abs(y) > 1.0e20
        return (ax > 1.0) == (y > 0.0) ? POS_INF_F : 0.0
    end
    lh, ll = _det_log2_dd(ax)
    yh = reinterpret(Float64, reinterpret(UInt64, y) & 0xfffffffff8000000)
    yl = y - yh
    lhh = reinterpret(Float64, reinterpret(UInt64, lh) & 0xfffffffff8000000)
    lhl = (lh - lhh) + ll
    ph = yh * lhh
    pl = yh * lhl + yl * lh + yl * ll
    sh = ph + pl
    sl = (ph - sh) + pl
    res = _fd_exp2_dd(sh, sl)
    return sgn < 0.0 ? -res : res
end
det_pow(x::Real, y::Real) = det_pow(Float64(x), Float64(y))

"Deterministic `hypot(x, y)` without libm variance."
function det_hypot(x::Float64, y::Float64)
    (isinf(x) || isinf(y)) && return POS_INF_F
    (isnan(x) || isnan(y)) && return NAN_F
    ax = _det_abs(x); ay = _det_abs(y)
    if ax < ay
        ax, ay = ay, ax
    end
    ax == 0.0 && return 0.0
    r = ay / ax
    return ax * sqrt(1.0 + r * r)
end
det_hypot(x::Real, y::Real) = det_hypot(Float64(x), Float64(y))

# Module-local shadows so unqualified calls in `sim/src/` route through `det_*` without Base piracy.
exp(x::Real) = det_exp(Float64(x))
log(x::Real) = det_log(Float64(x))
log(b::Real, x::Real) = det_log(Float64(x)) / det_log(Float64(b))
log1p(x::Real) = det_log1p(Float64(x))
log2(x::Real) = det_log2(Float64(x))
hypot(x::Real, y::Real) = det_hypot(Float64(x), Float64(y))

# --- Deterministic RNG & Stream Hashing ------------------------------------------------------

@inline function _splitmix64(x::UInt64)
    z = x + 0x9e3779b97f4a7c15
    z = (z ⊻ (z >>> 30)) * 0xbf58476d1ce4e5b9
    z = (z ⊻ (z >>> 27)) * 0x94d049bb133111eb
    return z ⊻ (z >>> 31)
end

const _FNV_OFFSET = 0xcbf29ce484222325
const _FNV_PRIME  = 0x00000100000001b3

@inline _fnv_byte(h::UInt64, b::UInt8) = (h ⊻ UInt64(b)) * _FNV_PRIME

@inline function _fnv_u64(h::UInt64, x::UInt64)
    for k in 0:7
        h = _fnv_byte(h, UInt8((x >>> (8 * k)) & 0xff))
    end
    return h
end

function _feed_seed(h::UInt64, x::Symbol)
    h = _fnv_byte(h, 0x53)
    for b in codeunits(String(x))
        h = _fnv_byte(h, b)
    end
    return _fnv_byte(h, 0xff)
end

function _feed_seed(h::UInt64, x::AbstractString)
    h = _fnv_byte(h, 0x54)
    for b in codeunits(String(x))
        h = _fnv_byte(h, b)
    end
    return _fnv_byte(h, 0xff)
end

_feed_seed(h::UInt64, x::Bool) = _fnv_byte(_fnv_byte(h, 0x42), UInt8(x))
_feed_seed(h::UInt64, x::Integer) = _fnv_u64(_fnv_byte(h, 0x49), x % UInt64)
_feed_seed(h::UInt64, x::AbstractFloat) = _fnv_u64(_fnv_byte(h, 0x46), reinterpret(UInt64, Float64(x)))

function _feed_seed(h::UInt64, x::Tuple)
    h = _fnv_u64(_fnv_byte(h, 0x50), UInt64(length(x)))
    for el in x
        h = _feed_seed(h, el)
    end
    return h
end

function _feed_seed(h::UInt64, x::AbstractArray)
    h = _fnv_u64(_fnv_byte(h, 0x41), UInt64(length(x)))
    for el in x
        h = _feed_seed(h, el)
    end
    return h
end

function _feed_seed(h::UInt64, x)
    x === nothing && return _fnv_byte(h, 0x4e)
    T = typeof(x)
    if isstructtype(T) && nfields(x) > 0
        h = _fnv_byte(h, 0x55)
        for f in fieldnames(T)
            h = _feed_seed(h, f)
            h = _feed_seed(h, getfield(x, f))
        end
        return h
    end
    error("stream_seed: no deterministic encoding for $(T); add a `_feed_seed` method (Base.hash is not stable across Julia versions)")
end

"Deterministic 64-bit stream seed over integers, symbols, strings, tuples, bools, and floats (invariant across Julia versions)."
function stream_seed(parts...)
    h = _FNV_OFFSET
    for p in parts
        h = _feed_seed(h, p)
    end
    return _splitmix64(h)
end

"Deterministic positive 31-bit integer seed (replaces `Int(hash(...) & 0x7fffffff)`)."
stream_int_seed(parts...) = Int(stream_seed(parts...) & UInt64(0x7fffffff))

"""
    DetRNG(seed)

Deterministic Xoshiro256++ RNG with SplitMix64 seeding and Marsaglia polar `randn` (independent of
Julia runtime ziggurat/hash changes across versions).
"""
mutable struct DetRNG <: AbstractRNG
    s0::UInt64
    s1::UInt64
    s2::UInt64
    s3::UInt64
    has_spare::Bool
    spare::Float64
end

function _seed_state(u::UInt64)
    z0 = u
    s0 = _splitmix64(z0); z1 = z0 + 0x9e3779b97f4a7c15
    s1 = _splitmix64(z1); z2 = z1 + 0x9e3779b97f4a7c15
    s2 = _splitmix64(z2); z3 = z2 + 0x9e3779b97f4a7c15
    s3 = _splitmix64(z3)
    return s0, s1, s2, s3
end

DetRNG(seed::Integer) = DetRNG(_seed_state(seed % UInt64)..., false, 0.0)
DetRNG(a, b, rest...) = DetRNG(stream_seed(a, b, rest...))
DetRNG(t::Tuple) = DetRNG(stream_seed(t))
DetRNG(s::Union{Symbol,AbstractString}) = DetRNG(stream_seed(s))

const Xoshiro = DetRNG

"Construct a deterministic sub-stream `DetRNG` from `(seed, tag...)`."
det_rng(seed::Integer) = DetRNG(seed)
det_rng(parts...) = DetRNG(stream_seed(parts...))

Base.copy(r::DetRNG) = DetRNG(r.s0, r.s1, r.s2, r.s3, r.has_spare, r.spare)

function Random.seed!(r::DetRNG, seed::Integer)
    r.s0, r.s1, r.s2, r.s3 = _seed_state(seed % UInt64)
    r.has_spare = false
    r.spare = 0.0
    return r
end

@inline function _next_u64!(r::DetRNG)
    res = bitrotate(r.s0 + r.s3, 23) + r.s0
    t = r.s1 << 17
    r.s2 ⊻= r.s0
    r.s3 ⊻= r.s1
    r.s1 ⊻= r.s2
    r.s0 ⊻= r.s3
    r.s2 ⊻= t
    r.s3 = bitrotate(r.s3, 45)
    return res
end

@inline Base.rand(r::DetRNG, ::Type{UInt64}) = _next_u64!(r)
@inline Base.rand(r::DetRNG, ::Type{Float64}) = Float64(_next_u64!(r) >>> 11) * 0x1.0p-53
@inline Base.rand(r::DetRNG, ::Type{Bool}) = (_next_u64!(r) >>> 63) == UInt64(1)
@inline Base.rand(r::DetRNG) = rand(r, Float64)
@inline Base.rand(r::DetRNG, ::Random.SamplerType{Float64}) = rand(r, Float64)
@inline Base.rand(r::DetRNG, ::Random.SamplerType{UInt64}) = _next_u64!(r)
@inline Base.rand(r::DetRNG, ::Random.SamplerType{Bool}) = rand(r, Bool)

@inline function _rand_below(r::DetRNG, n::Int)
    n <= 1 && return 0
    m = UInt64(n)
    x = _next_u64!(r)
    p = widen(x) * widen(m)
    l = UInt64(p & 0xffffffffffffffff)
    if l < m
        t = (UInt64(0) - m) % m
        while l < t
            x = _next_u64!(r)
            p = widen(x) * widen(m)
            l = UInt64(p & 0xffffffffffffffff)
        end
    end
    return Int(p >>> 64)
end

function Base.rand(r::DetRNG, a::AbstractUnitRange{<:Integer})
    isempty(a) && throw(ArgumentError("collection must be non-empty"))
    return a[firstindex(a) + _rand_below(r, length(a))]
end

function Base.rand(r::DetRNG, c::Union{AbstractVector,Tuple})
    isempty(c) && throw(ArgumentError("collection must be non-empty"))
    return c[firstindex(c) + _rand_below(r, length(c))]
end

function Base.rand(r::DetRNG, c::Union{AbstractVector,Tuple}, n::Integer)
    isempty(c) && throw(ArgumentError("collection must be non-empty"))
    fi = firstindex(c)
    len = length(c)
    return [c[fi + _rand_below(r, len)] for _ in 1:n]
end

function Base.rand(r::DetRNG, d1::Integer, dims::Integer...)
    A = Array{Float64}(undef, d1, dims...)
    for i in eachindex(A)
        A[i] = rand(r, Float64)
    end
    return A
end

function Base.rand(r::DetRNG, ::Type{T}, d1::Integer, dims::Integer...) where {T<:Union{Float64,Bool,UInt64}}
    A = Array{T}(undef, d1, dims...)
    for i in eachindex(A)
        A[i] = rand(r, T)
    end
    return A
end

function Base.randn(r::DetRNG)
    if r.has_spare
        r.has_spare = false
        return r.spare
    end
    while true
        u = 2.0 * rand(r, Float64) - 1.0
        v = 2.0 * rand(r, Float64) - 1.0
        s = u * u + v * v
        if 0.0 < s < 1.0
            mul = sqrt(-2.0 * det_log(s) / s)
            r.has_spare = true
            r.spare = v * mul
            return u * mul
        end
    end
end
Base.randn(r::DetRNG, ::Type{Float64}) = randn(r)

function Base.randn(r::DetRNG, d1::Integer, dims::Integer...)
    A = Array{Float64}(undef, d1, dims...)
    for i in eachindex(A)
        A[i] = randn(r)
    end
    return A
end

function Base.randn(r::DetRNG, ::Type{Float64}, d1::Integer, dims::Integer...)
    A = Array{Float64}(undef, d1, dims...)
    for i in eachindex(A)
        A[i] = randn(r)
    end
    return A
end

function _randperm_impl!(r::DetRNG, a::AbstractVector{<:Integer})
    n = length(a)
    for i in 1:n
        a[i] = i
    end
    for i in 1:(n - 1)
        j = i + _rand_below(r, n - i + 1)
        a[i], a[j] = a[j], a[i]
    end
    return a
end
Random.randperm!(r::DetRNG, a::Array{<:Integer}) = _randperm_impl!(r, a)
Random.randperm!(r::DetRNG, a::AbstractVector{<:Integer}) = _randperm_impl!(r, a)
Random.randperm(r::DetRNG, n::Integer) = _randperm_impl!(r, Vector{Int}(undef, n))

function _shuffle_impl!(r::DetRNG, a::AbstractArray)
    fi = firstindex(a)
    n = length(a)
    for i in 0:(n - 2)
        j = i + _rand_below(r, n - i)
        a[fi + i], a[fi + j] = a[fi + j], a[fi + i]
    end
    return a
end
Random.shuffle!(r::DetRNG, a::Array) = _shuffle_impl!(r, a)
Random.shuffle!(r::DetRNG, a::AbstractArray) = _shuffle_impl!(r, a)
Random.shuffle!(r::DetRNG, a::AbstractVector) = _shuffle_impl!(r, a)
Random.shuffle(r::DetRNG, a::AbstractArray) = _shuffle_impl!(r, copy(a))
Random.shuffle(r::DetRNG, a::AbstractVector) = _shuffle_impl!(r, copy(a))

# --- Deterministic Ordered Reductions & Linear Loops -----------------------------------------

function _empty_sum(f, itr)
    T = eltype(itr)
    if T === Bool && f === identity
        return 0
    elseif f !== identity && isconcretetype(T)
        RT = Base.promote_op(f, T)
        RT === Bool && return 0
        (RT <: Number && isconcretetype(RT)) && return zero(RT)
    elseif T <: Number && isconcretetype(T)
        return zero(T)
    end
    return 0.0
end

function _sum_itr(f, itr, init)
    if init !== nothing
        acc = init
        for x in itr
            acc = acc + f(x)
        end
        return acc
    end
    it = iterate(itr)
    it === nothing && return _empty_sum(f, itr)
    val, st = it
    first_v = f(val)
    acc = first_v isa Bool ? Int(first_v) : (first_v isa AbstractArray ? copy(first_v) : first_v)
    while (it = iterate(itr, st)) !== nothing
        val, st = it
        acc = acc + f(val)
    end
    return acc
end

function _sum_dims(f, A::AbstractArray, dims, init)
    ridx = Base.reduced_indices(A, dims)
    first_acc = init !== nothing ? init : _empty_sum(f, A)
    T = typeof(first_acc)
    out = fill(T === Bool ? 0 : first_acc, ridx)
    if init === nothing && isempty(A)
        return out
    end
    first_touched = init !== nothing ? trues(size(out)) : falses(size(out))
    dset = dims isa Integer ? (dims,) : Tuple(dims)
    for I in CartesianIndices(A)
        J = CartesianIndex(ntuple(k -> (k in dset ? first(ridx[k]) : I[k]), ndims(A)))
        v = f(A[I])
        if !first_touched[J]
            out[J] = v isa Bool ? Int(v) : v
            first_touched[J] = true
        else
            out[J] = out[J] + v
        end
    end
    return out
end

"Deterministic left-to-right sum (no SIMD tree reordering)."
det_sum(itr; init = nothing) = _sum_itr(identity, itr, init)
det_sum(f, itr; init = nothing) = _sum_itr(f, itr, init)
det_sum(A::AbstractArray; dims = nothing, init = nothing) =
    dims === nothing ? _sum_itr(identity, A, init) : _sum_dims(identity, A, dims, init)
det_sum(f, A::AbstractArray; dims = nothing, init = nothing) =
    dims === nothing ? _sum_itr(f, A, init) : _sum_dims(f, A, dims, init)

function _slice_count(A::AbstractArray, dims)
    dset = dims isa Integer ? (dims,) : Tuple(dims)
    n = 1
    for d in dset
        1 <= d <= ndims(A) && (n *= size(A, d))
    end
    return n
end

"Deterministic left-to-right mean."
det_mean(itr) = _sum_itr(identity, itr, nothing) / length(itr)
det_mean(f, itr) = _sum_itr(f, itr, nothing) / length(itr)
det_mean(A::AbstractArray; dims = nothing) =
    dims === nothing ? _sum_itr(identity, A, nothing) / length(A) :
                       _sum_dims(identity, A, dims, nothing) ./ _slice_count(A, dims)
det_mean(f, A::AbstractArray; dims = nothing) =
    dims === nothing ? _sum_itr(f, A, nothing) / length(A) :
                       _sum_dims(f, A, dims, nothing) ./ _slice_count(A, dims)

"Deterministic left-to-right variance."
function det_var(itr; corrected::Bool = true, mean = nothing)
    n = length(itr)
    m = mean === nothing ? det_mean(itr) : mean
    dof = corrected ? n - 1 : n
    dof <= 0 && return 0.0 / 0.0
    ss = 0.0
    for x in itr
        d = Float64(x) - Float64(m)
        ss += d * d
    end
    return ss / dof
end

function det_var(A::AbstractArray; corrected::Bool = true, mean = nothing, dims = nothing)
    dims === nothing && return det_var((x for x in A); corrected = corrected, mean = mean)
    m = mean === nothing ? det_mean(A; dims = dims) : mean
    n = _slice_count(A, dims)
    dof = corrected ? n - 1 : n
    ridx = Base.reduced_indices(A, dims)
    out = zeros(Float64, ridx)
    dof <= 0 && (fill!(out, 0.0 / 0.0); return out)
    dset = dims isa Integer ? (dims,) : Tuple(dims)
    for I in CartesianIndices(A)
        J = CartesianIndex(ntuple(k -> (k in dset ? first(ridx[k]) : I[k]), ndims(A)))
        d = Float64(A[I]) - Float64(m[J])
        out[J] += d * d
    end
    out ./= dof
    return out
end

"Deterministic left-to-right standard deviation."
det_std(x; corrected::Bool = true, mean = nothing) = sqrt(det_var(x; corrected = corrected, mean = mean))
det_std(A::AbstractArray; corrected::Bool = true, mean = nothing, dims = nothing) =
    dims === nothing ? sqrt(det_var(A; corrected = corrected, mean = mean)) :
                       sqrt.(det_var(A; corrected = corrected, mean = mean, dims = dims))

"Deterministic left-to-right inner product (no SIMD / BLAS reordering)."
function det_dot(x, y)
    length(x) == length(y) || throw(DimensionMismatch("dot length mismatch"))
    s = 0.0
    for (a, b) in zip(x, y)
        s += Float64(a) * Float64(b)
    end
    return s
end

"Deterministic left-to-right Pearson correlation."
function det_cor(x, y)
    length(x) == length(y) || throw(DimensionMismatch("cor length mismatch"))
    mx = det_mean(x); my = det_mean(y)
    sxx = 0.0; syy = 0.0; sxy = 0.0
    for (xi, yi) in zip(x, y)
        dx = Float64(xi) - mx
        dy = Float64(yi) - my
        sxx += dx * dx
        syy += dy * dy
        sxy += dx * dy
    end
    (sxx == 0.0 || syy == 0.0) && return 0.0 / 0.0
    return clamp(sxy / sqrt(sxx * syy), -1.0, 1.0)
end

function det_matvec(A::AbstractMatrix, x::AbstractVector)
    m, n = size(A)
    length(x) == n || throw(DimensionMismatch("matrix-vector length mismatch"))
    out = Vector{Float64}(undef, m)
    for i in 1:m
        s = 0.0
        for j in 1:n
            s += Float64(A[i, j]) * Float64(x[j])
        end
        out[i] = s
    end
    return out
end

function det_matvec_t(A::AbstractMatrix, y::AbstractVector)
    m, n = size(A)
    length(y) == m || throw(DimensionMismatch("transpose matrix-vector length mismatch"))
    out = Vector{Float64}(undef, n)
    for j in 1:n
        s = 0.0
        for i in 1:m
            s += Float64(A[i, j]) * Float64(y[i])
        end
        out[j] = s
    end
    return out
end

"Lower Cholesky factor of a symmetric matrix (reads the lower triangle), fixed row-major order, left-to-right sums; `nothing` if not positive definite."
function det_cholesky(K::AbstractMatrix)
    n = size(K, 1)
    size(K, 2) == n || throw(DimensionMismatch("det_cholesky needs a square matrix"))
    L = zeros(Float64, n, n)
    for i in 1:n
        for j in 1:i
            s = Float64(K[i, j])
            for k in 1:(j - 1)
                s -= L[i, k] * L[j, k]
            end
            if i == j
                (s > 0.0 && isfinite(s)) || return nothing
                L[i, i] = sqrt(s)
            else
                L[i, j] = s / L[j, j]
            end
        end
    end
    return L
end

"Solve L x = b for lower-triangular L (forward substitution, fixed order)."
function det_forward_solve(L::AbstractMatrix, b::AbstractVector)
    n = length(b)
    x = Vector{Float64}(undef, n)
    for i in 1:n
        s = Float64(b[i])
        for k in 1:(i - 1)
            s -= L[i, k] * x[k]
        end
        x[i] = s / L[i, i]
    end
    return x
end

"Solve L' x = b for lower-triangular L (back substitution, fixed order)."
function det_back_solve(L::AbstractMatrix, b::AbstractVector)
    n = length(b)
    x = Vector{Float64}(undef, n)
    for i in n:-1:1
        s = Float64(b[i])
        for k in (i + 1):n
            s -= L[k, i] * x[k]
        end
        x[i] = s / L[i, i]
    end
    return x
end

"Left-to-right running sum (explicit loop; the contract is the order, not the Base implementation)."
function det_cumsum(xs::AbstractVector)
    out = Vector{Float64}(undef, length(xs))
    acc = 0.0
    for i in eachindex(xs)
        acc += Float64(xs[i])
        out[i] = acc
    end
    return out
end

# Module-local shadows for reductions in `BenefutureSim`
sum(args...; kw...) = det_sum(args...; kw...)
mean(args...; kw...) = det_mean(args...; kw...)
var(args...; kw...) = det_var(args...; kw...)
std(args...; kw...) = det_std(args...; kw...)
dot(x, y) = det_dot(x, y)
cor(x, y) = det_cor(x, y)
