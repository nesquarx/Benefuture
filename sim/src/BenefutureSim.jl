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
export running_mean, settling_step, ci_halfwidth, success_pattern, pattern_margin
export prim, prim_boxes, in_box, describe_box, sobol_indices, active_boundary, random_boundary, seeds_until_stable, paired_effect, equivalent, proportion_interval, cross_entropy_search
export escrow_split, reputation_decay, resource_cost, transaction_price, supply_delta, competition_efficiency, settlement, cc_share, carry_fee, cause_settlement, shapley, shapley_sampled, shapley_sample_count, shapley_shares, cc_assessed, traversal_shares, is_crime, advap_reward, advap_liability, report_penalty, ratchet_credence, persistence, overstatement_significance, escalated_credence, PARAM_FIELDS, bootstrap_params, admissible, perturb, select_candidate, gauge_radius, escape_accept, explore_pick, binding_admits, binding_admits_weighted, class_balanced_skill, ehr_expected_response, self_report_payout, caught_charge, caught_reward, false_report_charge, event_rate, pooled_probability, expected_effect, repeat_escrow_credence, pragmatic_understanding, relative_accuracy, chains_acyclic, pooled_reading, chains_diverge, lt_offset_admissible, env_health_blocked, UTraits, understanding_truth_and_measure, random_utraits, understanding_ratios, run_m7_traits
export spearman, Agent, M2Params, run_m2
export profile_valid, attribute, decay_rate_for, classify, accumulation_threshold, overflow
export projection_membership, classify_network, fallback_network, aggregate_at_parent, subsethood
export membership_rolling, accuracy, credence, credence_accuracy, record_credence, decayed_record_credence, decayed_rms, choice_skill, ratchet_bar, decay_halflife, decayed_accuracy, decayed_mean_se, currency_eligible, relative_bar, scarcity_cost, pinball_loss, quantile_score
export voting_weight, accumulate_capped, relative_reputation, vote_reputation, audited_out, source_weight, heard, heard_weights, neg_share, credence_score, M5Params, run_m5
export count_once, tagged_reading, tags_falsified, undisclosed_echo, echo_influence
export split_trial, ability_caps, choice_noise, latin_hypercube, normal_quantile, gaussian_hypercube, ray_boundary, screen, battery, write_results, current_commit, cached, code_hash, battery_methods, write_methods
export CALIBRATED, draw_skills, lognormal_mean1, pareto_median1
export run_m7, teaching_plan
export foreclosed, life_value, optimistic_average, birth_level, shortfall, birth_escrow, accession_admissible, Newborn, PopPlan, pop_value, pop_choose, run_births
export DomainAgent, M3Params, run_m3, M3bParams, run_m3b, M3cParams, run_m3c, recount, Shock, shock
export difference_in_differences, synthetic_control, combine_counterfactuals, AsOfRecord, AsOfStore, append_record!, records_as_of, replay_forecasts, diebold_mariano, load_replay_case, load_case_records, HistoricalCaseRecord, replay_decision, evaluate_replay_suite, replay_baselines, replay_scores, replay_sensitivity, QuantileForecastRecord, QuantileStore, replay_quantile_forecasts, load_archive_store, window_scores, rolling_report

include("lean.jl")
include("calibration.jl")
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
include("methods.jl")
include("diversity.jl")
include("m5.jl")
include("m7.jl")
include("counterfactual.jl")
include("replay.jl")
include("forecast_archive.jl")
include("understanding.jl")

function __init__()
    load_lean_lib()
    load_harm_schedule!()
end

end
