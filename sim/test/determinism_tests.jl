# Cross-platform deterministic numerics regression & golden-trace guard.
# Pins exact IEEE-754 bit patterns across OSes, CPU vector widths (-C generic / AVX2 / NEON),
# Julia versions (1.11 / 1.13+), and thread counts.

using BenefutureSim, Test, SHA, Random

function _det_hexf(x::Float64)
    string(reinterpret(UInt64, x), base = 16, pad = 16)
end
_det_hexf(x::Real) = _det_hexf(Float64(x))
_det_digest(xs) = bytes2hex(sha256(join((_det_hexf(x) for x in xs), ",")))

@testset "Deterministic numerics: RNG streams, ordered reductions, transcendentals, and golden trace" begin
    @test stream_seed(4, :measurement, :epoch, 3) === 0x51e741245935d263
    @test stream_seed(4, :measurement, :epoch, 3) != stream_seed(4, :measurement, :epoch, 4)
    @test 0 <= stream_int_seed(4, :coupled_vote, 1) <= 0x7fffffff

    # DetRNG golden stream (independent of Base/Random hash and Ziggurat changes)
    ss = stream_seed(4, :measurement, :epoch, 3)
    r = DetRNG(12345)
    u = [rand(r) for _ in 1:64]
    g = [randn(r) for _ in 1:64]
    idx = Float64[rand(r, 1:17) for _ in 1:32]
    perm = Float64.(randperm(r, 16))
    shuf = Float64.(shuffle(r, collect(1:12)))
    rng_sha = bytes2hex(sha256(join(vcat([string(ss, base = 16, pad = 16)], _det_hexf.(vcat(u, g, idx, perm, shuf))), ",")))
    @test rng_sha == "ef6cf99b577c09d1288f3ee25374ffbcef1461449165648e33b2112791920b6d"

    # copy(DetRNG) preserves Marsaglia polar spare state after an odd number of randn calls
    rc = DetRNG(77)
    _ = randn(rc)
    rc_copy = copy(rc)
    @test randn(rc) === randn(rc_copy)
    @test rand(rc) === rand(rc_copy)

    # Sequential left-to-right reductions & matrix-vector kernels
    @test det_sum(Bool[]) === 0
    @test det_sum([true, false, true]) === 2
    @test det_sum(Float64[]) === 0.0
    @test det_sum([1.0 2.0; 3.0 4.0]; dims = 2) == reshape([3.0, 7.0], 2, 1)

    rr = DetRNG(99)
    v = randn(rr, 200)
    w = randn(rr, 200)
    A = randn(rr, 31, 17)
    x = randn(rr, 17)
    y = randn(rr, 31)
    red_vals = vcat([det_sum(v), det_mean(v), det_var(v), det_std(v), det_var(v; corrected = false), det_dot(v, w), det_cor(v, w)],
                    det_matvec(A, x), det_matvec_t(A, y))
    @test _det_digest(red_vals) == "dd7351d30859d2b56a0efa4719af43f6c3ecd13be4d43d2c19bed05592305962"

    # Bit-exact === parity between Julia det_* and Lean FloatDet C exports
    rt = DetRNG(42)
    vals = vcat([-Inf, -750.0, -700.0, -1.0, -0.5, -0.0, 0.0, 1e-310, 1e-16, 0.2928, 0.293, 1.0, 2.0, 55.5, 709.78, 710.0, Inf, NaN],
                [(rand(rt) - 0.5) * 200.0 for _ in 1:200])
    bit_eq(a::Float64, b::Float64) = (isnan(a) && isnan(b)) || a === b
    @test all(vals) do val
        ok = bit_eq(det_exp(val), lean_det_exp(val))
        if val >= -1.0 || isnan(val)
            ok &= bit_eq(det_log1p(val), lean_det_log1p(val))
        end
        if val >= 0.0 || isnan(val)
            ok &= bit_eq(det_log(val), lean_det_log(val))
        end
        ok
    end
    @test all([-2.0, -1.0, -0.0, 0.0, 0.37, 1.0, 1.7, 12.5, Inf]) do bx
        all([-3.0, -2.0, -0.5, 0.0, 0.37, 1.0, 2.0, 2.5, 3.0, Inf]) do py
            bit_eq(det_pow(bx, py), lean_det_pow(bx, py))
        end
    end

    # Compact golden multi-model trace across M3c, M5, M7, and continuous Unified Coupled
    agents = [DomainAgent([0.6, 0.2, 0.6, 0.2], [0.5, 0.0, 0.5, 0.0], 0.1) for _ in 1:6]
    m3_tr = run_m3c(M3cParams(ToyParams(n = 30, steps = 25, plans = 5), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 4)
    m5_tr = run_m5(M5Params(m3_tr, [1, 2]; decisions = 40, deliberation = true, info_handling = true, source_tags = true); seed = 4)
    m7_tr = run_m7(ToyParams(n = 24, steps = 20, plans = 4); seed = 4)
    econ = M3cParams(ToyParams(n = 24, steps = 30, plans = 4), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true)
    gov(tr) = M5Params(tr, 1:4; decisions = 1, deliberation = true, info_handling = true, source_tags = true, ih_vote = true)
    up = UnifiedParams(liar_community = 1, identity = IdentityParams(newcomers = 2, sybils = 2, binding = true), economy = true, fractal = FractalParams())
    c_tr = run_coupled(econ, gov; seed = 4, epoch = 15, coupled = false, continuous = true, m5_decisions = 12, unified = up)
    mod_vals = vcat(m3_tr.floor_u, m3_tr.floor_h, Float64.(m5_tr.chosen_share), [m5_tr.correct, m5_tr.welfare],
                    m7_tr.floor_u, m7_tr.median_u, c_tr.floor_u, c_tr.floor_h, [f.ledger_gap for f in c_tr.unified.fractal])
    @test _det_digest(mod_vals) == "e049651202b674f30c3fb0e0fe2ec928fb1475fbfa4e6f2059c683dd15d01c3f"
end
