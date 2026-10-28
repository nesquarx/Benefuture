"""
    BenefutureSim

Agent-based simulation of the Benefuture specification. The rules are computed by the Lean
reference library (`BenefutureReference`) through its C exports; this package supplies the world
the rules act on. Rules are checked against the test vectors in `spec/vectors/`.
"""
module BenefutureSim

export phi, net_synergy, squashed_synergy
export HARM_SCHEDULE, assess, signed_synergy, harm_weight, value_on_being
export floor_quantile, g_choose

include("lean.jl")
include("synergy.jl")
include("value.jl")
include("goal.jl")

function __init__()
    load_lean_lib()
    load_harm_schedule!()
end

end
