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
export ToyParams, ToyState, ToyPlan, toy_state, choose, run_m0, floors_rise, assessed_value
export mm_score, mm_adopt, MetricModel, M1Params, run_m1
export running_mean, settling_step, ci_halfwidth
export escrow_split, reputation_decay, resource_cost, transaction_price, supply_delta, competition_efficiency, settlement, cc_share, carry_fee, cause_settlement, shapley, cc_assessed, traversal_shares, is_crime, PARAM_FIELDS, bootstrap_params, admissible, perturb, select_candidate, gauge_radius
export spearman, Agent, M2Params, run_m2
export profile_valid, attribute, decay_rate_for, classify, accumulation_threshold, overflow
export projection_membership, classify_network, fallback_network, aggregate_at_parent, subsethood
export membership_rolling, accuracy, currency_eligible, scarcity_cost
export voting_weight, accumulate_capped, relative_reputation, M5Params, run_m5
export split_trial
export DomainAgent, M3Params, run_m3, M3bParams, run_m3b, M3cParams, run_m3c, recount, Shock, shock

include("lean.jl")
include("synergy.jl")
include("value.jl")
include("goal.jl")
include("measurement.jl")
include("economy.jl")
include("domains.jl")
include("m0.jl")
include("m1.jl")
include("analysis.jl")
include("m2.jl")
include("m3.jl")
include("m3b.jl")
include("m3c.jl")
include("governance.jl")
include("diversity.jl")
include("m5.jl")

function __init__()
    load_lean_lib()
    load_harm_schedule!()
end

end
