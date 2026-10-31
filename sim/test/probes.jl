# Mechanism probes alone (CLAUDE.md, Verification): julia --project=sim sim/test/probes.jl
# The smallest worlds that show one mechanism working, seconds per case, before it enters the
# iterated ecosystem; the full suite (`Pkg.test()`) includes them too.
using BenefutureSim, Test, Random, Statistics
include(joinpath(@__DIR__, "probe_tests.jl"))
