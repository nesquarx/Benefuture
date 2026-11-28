# Determinism variants (2026-11-28, Linux x86_64 Xeon host, Julia 1.13, 4 cores)

`tools/determinism/variants.sh` runs `trace_probe.jl` (seed 4, worlds m3d and p60 plus the Lean sweep) and `gp_probe.jl`
under each variant and requires identical hashes. All variants gave trace `de7950a486a46ce3`, Lean sweep `c41026be6680b7c1`,
GP `dfb69e5fea607205`:

native; `-C generic`; `-C znver4`; `-C icelake-server`; `JULIA_NUM_THREADS=4`; `OPENBLAS_NUM_THREADS` 1 and 4;
fresh compile cache (new first `JULIA_DEPOT_PATH` entry, BenefutureSim precompiled from scratch).

Red baseline before this change (LAPACK `cholesky` and BLAS triangular solves in `gp_fit`/`gp_predict`): the GP hash was
`4ad2101538131be0` with one BLAS thread and `b8daf2b0868f096a` with four, identical across `-C` targets on this host.
Replaced by `det_cholesky`, `det_forward_solve`, `det_back_solve`, `det_matvec` (fixed order).

Limits: the host runs one CPU model, so `-C` targets test code generation, not other silicon; macOS arm64 is covered by the CI
matrix in `.github/workflows/determinism.yml`, which now also checks the GP hash and sets `OPENBLAS_NUM_THREADS`.
