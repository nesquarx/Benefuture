"""
    BenefutureSim

Agent-based simulation of the Benefuture specification. The rules are computed by the Lean
reference library (`BenefutureReference`) through its C exports; this package supplies the world
the rules act on. Rules are checked against the test vectors in `spec/vectors/`.
"""
module BenefutureSim

export phi, net_synergy, squashed_synergy
export HARM_SCHEDULE, assess, signed_synergy, harm_weight, value_on_being, fr_permissible
export floor_quantile, g_choose
export ToyParams, ToyState, ToyPlan, toy_state, choose, run_m0, floors_rise, assessed_value
export mm_score, mm_adopt, MetricModel, M1Params, run_m1
export running_mean, settling_step, ci_halfwidth, success_pattern
export escrow_split, reputation_decay, resource_cost, transaction_price, supply_delta, competition_efficiency, settlement, cc_share, carry_fee, cause_settlement, shapley, shapley_sampled, shapley_sample_count, shapley_shares, cc_assessed, traversal_shares, is_crime, advap_reward, advap_liability, report_penalty, ratchet_credence, PARAM_FIELDS, bootstrap_params, admissible, perturb, select_candidate, gauge_radius, escape_accept
export spearman, Agent, M2Params, run_m2
export profile_valid, attribute, decay_rate_for, classify, accumulation_threshold, overflow
export projection_membership, classify_network, fallback_network, aggregate_at_parent, subsethood
export membership_rolling, accuracy, credence, credence_accuracy, currency_eligible, relative_bar, scarcity_cost
export voting_weight, accumulate_capped, relative_reputation, vote_reputation, audited_out, source_weight, heard, neg_share, credence_score, M5Params, run_m5
export split_trial, ability_caps, choice_noise, latin_hypercube, normal_quantile, gaussian_hypercube, ray_boundary, screen, battery, write_results, current_commit
export run_m7, teaching_plan
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
include("friction.jl")
include("battery.jl")
include("diversity.jl")
include("m5.jl")
include("m7.jl")

function __init__()
    load_lean_lib()
    load_harm_schedule!()
end

end
