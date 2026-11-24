"""
    BenefutureSim

Agent-based simulation of the Benefuture specification. The rules are computed by the Lean
reference library (`BenefutureReference`) through its C exports; this package supplies the world
the rules act on. Rules are checked against the test vectors in `spec/vectors/`.
"""
module BenefutureSim

export phi, net_synergy, squashed_synergy
export tiered_value, tier_schedules, run_programmes, meta_multiplier
export HARM_SCHEDULE, assess, signed_synergy, harm_weight, value_on_being, fr_permissible
export floor_quantile, tail_floor, g_choose, g_choose_lexical_fr, g_choose_dist
export ToyParams, ToyState, ToyPlan, toy_state, choose, run_m0, floors_rise, assessed_value
export mm_score, mm_adopt, MetricModel, M1Params, run_m1
export running_mean, settling_step, ci_halfwidth, success_pattern, pattern_margin, progressive_metrics, SimTrace, build_sim_trace, conj_mm_competition_converges, conj_goodhart_reduction, conj_gaming_resistance, conj_adversarial_robustness, conj_min_tracks_prediction, conj_floors_rise, conj_no_repugnant_drift, conj_param_stability, conj_delegation_dispersed
export prim, prim_boxes, in_box, describe_box, sobol_indices, active_boundary, random_boundary, seeds_until_stable, paired_effect, equivalent, proportion_interval, cross_entropy_search
export escrow_split, reputation_decay, resource_cost, transaction_price, supply_delta, competition_efficiency, settlement, cc_share, carry_fee, cause_settlement, shapley, shapley_sampled, shapley_sample_count, shapley_shares, bound_shapley_shares, cc_assessed, traversal_shares, is_crime, accident_split, sanction_escrow_credence, rehabilitate_restraint, responsibility_factor, advap_reward, advap_liability, advap_recount_correct, report_penalty, ratchet_credence, persistence, overstatement_significance, escalated_credence, PARAM_FIELDS, bootstrap_params, admissible, perturb, deciding_scope, select_candidate, gauge_radius, escape_accept, explore_pick, binding_admits, binding_admits_weighted, class_balanced_skill, ehr_expected_response, self_report_payout, caught_charge, caught_reward, false_report_charge, event_rate, pooled_probability, expected_effect, repeat_escrow_credence, pragmatic_understanding, relative_accuracy, chains_acyclic, pooled_reading, chains_diverge, lt_offset_admissible, env_health_blocked, irreparable_blocked, irreparable_equivalent, cfd_ballot_weight, copies, coerror_copy, sequential_significant, fork_split, UTraits, understanding_truth_and_measure, random_utraits, understanding_ratios, run_m7_traits
export spearman, Agent, M2Params, run_m2
export prediction_on_track, resolution_due, issuance_headroom, deliverable_value, ra_value_per_cost, ra_commons_reserve, ra_contraction_factor, withhold_charge, withhold_reward, effective_independent_judges, trust_cascade, profile_valid, attribute, decay_rate_for, classify, accumulation_threshold, overflow
export projection_membership, classify_network, fallback_network, aggregate_at_parent, subsethood, COMPONENT_FALLBACKS
export membership_rolling, accuracy, credence, credence_accuracy, record_credence, decayed_record_credence, decayed_rms, eb_credence, choice_skill, ratchet_bar, decay_halflife, decayed_accuracy, decayed_mean_se, currency_eligible, relative_bar, scarcity_cost, pinball_loss, quantile_score
export voting_weight, voting_weight_sy, counted_impact, accumulate_capped, relative_reputation, vote_reputation, audited_out, source_weight, heard, heard_weights, contention_map, neg_share, credence_score, M5Params, run_m5
export count_once, tagged_reading, tags_falsified, undisclosed_echo, echo_influence
export split_trial, ability_caps, choice_noise, latin_hypercube, normal_quantile, gaussian_hypercube, ray_boundary, screen, battery, write_results, current_commit, cached, code_hash, battery_methods, write_methods, ProgressTracker, progress_tracker, progress_tick!, progress_finish!
export CALIBRATED, draw_skills, lognormal_mean1, pareto_median1
export run_m7, teaching_plan, personhood, base_vote, run_population_identities, run_population_world
export ih_truth_level, IhClaimsParams, run_ih_claims, IhWorldParams, run_ih_world, extended_self_feedback, propagated_liability, end_of_horizon_score, end_of_horizon_predicted_score, ihz_access_risk, art_success_score, art_surplus_value, chain_truth_level, M8Params, run_m8, M8IhzParams, run_m8_ihz, M8ArtParams, run_m8_art, M8CultureParams, run_m8_culture, M8TruthParams, run_m8_truth, M8ArtConfoundParams, run_m8_art_confounders, M8EhrParams, run_m8_ehr, M8EnforcementParams, run_m8_enforcement
export foreclosed, life_value, optimistic_average, birth_level, shortfall, birth_escrow, birth_accrued_escrow, pending_escrow_loss, accession_admissible, Newborn, PopPlan, pop_value, pop_choose, run_births
export DomainAgent, M3Params, run_m3, M3bParams, run_m3b, M3cParams, run_m3c, recount, recount_μ, recount_models, recount_cc, Shock, shock, run_coupled, StatusQuoParams, run_status_quo
export difference_in_differences, synthetic_control, combine_counterfactuals, AsOfRecord, AsOfStore, append_record!, records_as_of, replay_forecasts, diebold_mariano, load_replay_case, load_case_records, HistoricalCaseRecord, replay_decision, evaluate_replay_suite, replay_baselines, replay_scores, replay_sensitivity, replay_rule_battery, replay_credence, replay_credence_stats, contrast_check, QuantileForecastRecord, QuantileStore, replay_quantile_forecasts, load_archive_store, window_scores, rolling_report

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
include("coupled.jl")
include("status_quo.jl")
include("m7.jl")
include("m8.jl")
include("ih_claims.jl")
include("programmes.jl")
include("counterfactual.jl")
include("replay.jl")
include("forecast_archive.jl")
include("dataset_adapters.jl")
include("understanding.jl")

function __init__()
    load_lean_lib()
    load_harm_schedule!()
end

end
