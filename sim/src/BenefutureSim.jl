"""
    BenefutureSim

Agent-based simulation of the Benefuture specification. Operators mirror the Lean reference
library (`BenefutureReference`) and are checked against its test vectors in `spec/vectors/`.
"""
module BenefutureSim

export phi, net_synergy, squashed_synergy

include("synergy.jl")

end
