# Heavy mechanism probes alone (full tier): julia --project=sim sim/test/probes_heavy.jl
using BenefutureSim, Test, Random, Statistics
for k in 1:3
    include(joinpath(@__DIR__, "probe_heavy$(k)_tests.jl"))
end
