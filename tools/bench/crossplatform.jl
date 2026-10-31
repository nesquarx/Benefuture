# Cross-platform determinism check: the M3d acceptance world (sim/test/m3d_tests.jl), seed 1. Compare the printed values across machines.
using BenefutureSim, Statistics, Test
include(joinpath(pwd(), "sim/test/legacy.jl"))
src = read("sim/test/m3c_tests.jl", String)
i = findfirst("m3c(; hidden", src); j = findnext("\nend", src, first(i)); include_string(Main, "function " * src[first(i):last(j)])
tr = run_m3c(m3c(; work = [1, 3], transactions = true); seed = 1); g = run_m3c(m3c(work = [1, 3]); seed = 1)
println("tx chosen ", length(tr.chosen_step), " lane ", tr.lane_executed, " halted ", tr.lane_halted, " menu ", length(g.chosen_step), " degraded ", tr.degraded)
println("credence(2,1)=", repr(credence(2.0, 1.0)), " floor_u[end]=", repr(tr.floor_u[end]), " floor_u[50]=", repr(tr.floor_u[50]))
