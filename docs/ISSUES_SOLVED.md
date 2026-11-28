# Issues solved

Each entry records a mistake once made, how it showed, its root cause, the fix, and the guard that keeps it from returning. Consult it when an issue occurs (failure, divergence, red CI, stall), not as first reading. Add an entry only once the solution is validated (red test now green, CI or cross-environment check passed); work in progress stays out (author, 2026-11-28). Rulings and source changes stay in `docs/BACKPROPAGATION.md`; this file is about failure modes of the work.

Format: **symptom** · cause · fix (commit) · guard · lesson.

## Determinism and numerics

- **P60 diverged across CI runners (acc 0.75 vs 0.41) though Julia, Lean and sums matched.** · `Xoshiro(hash((seed, :shapley, t, ...)))` hashed a struct; Julia's default struct hash includes type identity, which changes with every fresh precompile, so it looked like a CPU effect. · Content-based `stream_seed`/`det_rng` (2ed2cdc); diagnosis via `BF_TRACE_CALLS` trace (cbed8ef). · `determinism_tests.jl`; cross-OS verify in `determinism.yml`. · Never feed `Base.hash` of anything but plain bits into a seed. Suspect the build (precompile, cache) before the CPU when a divergence is large.
- **Last-bit differences across CPUs and `--check-bounds`.** · Julia `sum`/`mean`/`dot` reduction order follows SIMD width. · Sequential `det_*` reductions shadowing the Base ones (2ed2cdc). · `determinism_tests.jl`. · No library reduction in rules or world model; fixed order only.
- **`classify` differed by 1 ulp on arm64.** · clang's default `-ffp-contract=fast` fused `d*d - m*m`. · `-ffp-contract=off` in `lakefile.toml` (2ed2cdc). · Cross-OS verify. · Compiler defaults are platform-dependent; pin them.
- **Platform libm transcendentals and Julia-version `Random`.** · `exp`/`log`/`pow` bind to different libms; `randn` and seeding may change across Julia versions. · FDLIBM `FloatDet.lean` mirrored in `deterministic.jl`; DetRNG (2ed2cdc). · Golden stream and transcendental tests. · Own every numeric dependency the results rest on.
- **Probe compared only what it called.** · The first cross-environment sweep never reached the Shapley path, so it reported identical while worlds diverged. · Per-step state hashes plus a call trace. · Trace a full composed world, not just kernels. · A sweep proves only what it exercises.

## Process

- **Patch before probe.** · Fixes were proposed for divergence before the cause was located in every environment. · Withdrawn; probed here, CI and M1 first (author). · `docs/CODING_STYLE.md`. · Validate the root cause in every affected environment, then fix.
- **"Drop a bit for parity" proposal.** · Rounding to fewer bits cannot guarantee parity: values near a rounding boundary still split. · Rejected. · — · Parity needs exact, ordered operations, not lower precision.
- **Seed-fragile assertions turned CI red (P60/P61 ade2a45; 8.136, P63 dc7f087).** · Tests asserted single-seed values or 'k of 3'. · Restated distributionally (540e51e, 10be0c0). · Significance rules in `CLAUDE.md`. · Claims are proportions with intervals, effects by the z rule, no-effects by equivalence.
- **Duplicated work across agents.** · A determinism fix was briefed while the local agent had already landed it (2ed2cdc). · Pull and read `COORDINATION.md` §2a before briefing. · Session hook alerts on `COORDINATION.md` changes. · Check the registry first, every time.

## Gates and scoring

- **Unified world stalled on one lagging domain.** · The converge gate required all domains. · Per-domain gate, lagging domain score-only and logged `degraded` (8.176). · `all_domains_gate_stalls_on_lagging_domain`. · Gates open per unit, never on the worst member.
