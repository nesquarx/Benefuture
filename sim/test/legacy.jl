# The world before calibration (docs/CALIBRATION.md): the limiting case of mild noise, kept for tests
# that isolate one mechanism or pin a designed scenario (a domain whose leaf model just qualifies, an
# exact world). Defaults are the realistic world (`CALIBRATED`, sim/src/calibration.jl); a test passes
# `LEGACY...` to say its world is controlled, never to hide a property that fails under realism.
const LEGACY = (marker_σ = 0.05, σ_leaf = 0.15, σ_branch = 0.3, σ_coarse = 0.45, classify_σ = 0.03, spread = 0.03,
                p_side = 0.0, hazard_heavy = false, hazard_σ = 0.2)
