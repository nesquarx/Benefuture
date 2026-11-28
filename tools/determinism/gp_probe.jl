# GP (methods.jl gp_fit/gp_predict) bit-hash probe: prints one hash over fixed problems of several sizes.
# Usage: julia [-C generic] [-t N] --project=sim tools/determinism/gp_probe.jl   (set OPENBLAS_NUM_THREADS to vary BLAS threads)
using BenefutureSim, SHA, Random
const BS = BenefutureSim
hexf(x::Float64) = string(reinterpret(UInt64, x), base = 16, pad = 16)
function main()
    parts = String[]
    for (n, d) in ((12, 3), (40, 4), (90, 6), (160, 5))
        rng = BS.DetRNG(100 + n)
        Z = [rand(rng) for _ in 1:n, _ in 1:d]
        y = [Z[i, 1] * Z[i, 2] + 0.1 * randn(rng) for i in 1:n]
        P = [rand(rng) for _ in 1:(2n), _ in 1:d]
        gp = BS.gp_fit(Z, y)
        pr = BS.gp_predict(gp, P)
        append!(parts, hexf.(pr.μ), hexf.(pr.σ), [hexf(gp.ℓ), hexf(gp.η)])
    end
    println("gp_hash ", bytes2hex(sha256(join(parts, ",")))[1:16])
end
main()
