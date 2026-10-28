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
export ToyParams, ToyState, ToyPlan, toy_state, choose, run_m0, floors_rise
export mm_score, mm_adopt, MetricModel, M1Params, run_m1
export running_mean, settling_step, ci_halfwidth

include("lean.jl")
include("synergy.jl")
include("value.jl")
include("goal.jl")
include("measurement.jl")
include("m0.jl")
include("m1.jl")
include("analysis.jl")

function __init__()
    load_lean_lib()
    load_harm_schedule!()
end

end
