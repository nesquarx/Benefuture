# Escrow (L84), reputation decay (L101), resource cost and pricing (L82, L83, L86, L99), computed by
# the Lean reference (`Escrow_split_ref`, `Rep_decay_ref`, `resource_cost_ref`,
# `transaction_price_ref`, `supply_delta_ref`, `competition_efficiency_ref`).

using Random

probability(p) = check(isfinite(p) && 0 <= p <= 1, "probability must lie in [0, 1]")

"""
    escrow_split(nominal, p_win) -> (upfront, hold)

Probabilistic escrow: pay `p_win` of the nominal value upfront and hold the rest for settlement.
"""
function escrow_split(nominal::Real, p_win::Real)
    check(isfinite(nominal), "nominal value must be finite")
    probability(p_win)
    (ccall(sym(:bf_escrow_upfront), Float64, (Float64, Float64), nominal, p_win),
     ccall(sym(:bf_escrow_hold), Float64, (Float64, Float64), nominal, p_win))
end

"""
    reputation_decay(score, dt; rate)

Reputation's relevance after `dt` without new contribution, decaying continuously at `rate`.
"""
function reputation_decay(score::Real, dt::Real; rate::Real)
    check(all(isfinite, (score, dt, rate)), "inputs must be finite")
    check(dt >= 0 && rate >= 0, "elapsed time and rate must be non-negative")
    ccall(sym(:bf_rep_decay), Float64, (Float64, Float64, Float64), score, dt, rate)
end

"""
    resource_cost(physical; compute, network, time, compute_cost, network_cost, time_cost)

Resources an action consumes: physical `(quantity, unit cost)` pairs, plus compute, network and
time at their unit costs; infrastructure is a resource, not a fee.
"""
function resource_cost(physical; compute::Real, network::Real, time::Real,
                       compute_cost::Real, network_cost::Real, time_cost::Real)
    check_items(physical)
    xs = (compute, network, time, compute_cost, network_cost, time_cost)
    check(all(isfinite, xs) && all(>=(0), xs), "resource amounts and costs must be non-negative")
    ccall(sym(:bf_resource_cost), Float64,
          (Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64, Float64, Float64, Float64),
          floatarray(mags(physical)), floatarray(weights(physical)),
          compute, network, time, compute_cost, network_cost, time_cost)
end

"Price of a transaction: resource cost less the credit expected with confidence `p_win`."
function transaction_price(cost::Real, credit::Real, p_win::Real)
    check(isfinite(cost) && isfinite(credit), "cost and credit must be finite")
    probability(p_win)
    ccall(sym(:bf_transaction_price), Float64, (Float64, Float64, Float64), cost, credit, p_win)
end

"Change in currency supply: measured good less resource cost less harm."
function supply_delta(good::Real, cost::Real, harm::Real)
    check(all(isfinite, (good, cost, harm)), "inputs must be finite")
    ccall(sym(:bf_supply_delta), Float64, (Float64, Float64, Float64), good, cost, harm)
end

"A currency's efficiency: value generated per resource and time consumed."
function competition_efficiency(dV::Real, cost::Real, dt::Real)
    check(all(isfinite, (dV, cost, dt)), "inputs must be finite")
    check(cost + dt > 0, "resource and time consumed must be positive")
    ccall(sym(:bf_competition_efficiency), Float64, (Float64, Float64, Float64), dV, cost, dt)
end

"""
    settlement(measured, upfront)

Settlement of escrow: the measured value less what was paid upfront; negative is a clawback.
"""
function settlement(measured::Real, upfront::Real)
    check(isfinite(measured) && isfinite(upfront), "inputs must be finite")
    ccall(sym(:bf_settlement), Float64, (Float64, Float64), measured, upfront)
end

"A contributor's share of one side of an outcome: its part over the side's total, in [0, 1]."
function cc_share(part::Real, side_total::Real)
    check(isfinite(part) && isfinite(side_total) && side_total != 0, "side total must be finite and non-zero")
    check(sign(part) * sign(side_total) >= 0, "a part lies on its side's sign")
    ccall(sym(:bf_cc_share), Float64, (Float64, Float64), part, side_total)
end

"Causal distribution: contribution × outcome, net of escrow already paid upfront."
function cause_settlement(cc::Real, total::Real, upfront::Real)
    check(isfinite(total) && isfinite(upfront) && 0 <= cc <= 1, "contribution in [0, 1], amounts finite")
    ccall(sym(:bf_cause_settlement), Float64, (Float64, Float64, Float64), cc, total, upfront)
end

"""
    carry_fee(maker_pos, contracted; accolade_rate, contract_share) -> fee

What carrying another's output on earns out of the maker's positive share (Lean `carry_fee_ref`):
an accolade outside contract, the contracted share under contract; nothing out of a loss.
"""
function carry_fee(maker_pos::Real, contracted::Bool; accolade_rate::Real, contract_share::Real)
    check(isfinite(maker_pos) && 0 <= accolade_rate <= 1 && 0 <= contract_share <= 1, "rates in [0, 1], share finite")
    ccall(sym(:bf_carry_fee), Float64, (Float64, Float64, Float64, UInt8), maker_pos, accolade_rate, contract_share, contracted)
end

"""
    shapley(v) -> shares

Shapley shares of an outcome among n contributors, from coalition values indexed by bitmask:
`v[m + 1]` is the assessed outcome had only the contributors in m acted.
"""
function shapley(v)
    n = round(Int, log2(length(v)))
    check(length(v) >= 1 && 2^n == length(v) && all(isfinite, v), "one finite value per coalition (2^n of them)")
    n == 0 && return Float64[]
    lean_floats(ccall(sym(:bf_shapley), Ptr{Cvoid}, (Csize_t, Ptr{Cvoid}), n, floatarray(v)))
end

# Governed thresholds for Shapley shares (sim/README.md, Governed thresholds): exact up to
# `SHAPLEY_EXACT_MAX` contributors (2^n coalition values), sampled beyond, with orderings enough
# that every share lies within `SHAPLEY_ε` × its marginal range of the exact share with
# probability at least 1 − `SHAPLEY_δ`.
const SHAPLEY_EXACT_MAX = 10
const SHAPLEY_ε = 0.05
const SHAPLEY_δ = 0.05

"""
    shapley_sampled(perms, vals) -> shares

Shapley shares by permutation sampling (Lean `shapley_sampled_ref`): `perms` is n × m, each column
an ordering of 1:n; `vals` is (n + 1) × m, the coalition values along each ordering (the empty
coalition first). Shares sum to v(all) − v(none) on every sample.
"""
function shapley_sampled(perms::AbstractMatrix{<:Integer}, vals::AbstractMatrix{<:Real})
    n, m = size(perms)
    check(m >= 1 && size(vals) == (n + 1, m) && all(isfinite, vals), "at least one ordering and n + 1 finite values along each")
    check(all(k -> sort(perms[:, k]) == 1:n, 1:m), "each column an ordering of 1:n")
    n == 0 && return Float64[]
    lean_floats(ccall(sym(:bf_shapley_sampled), Ptr{Cvoid}, (Csize_t, Csize_t, Ptr{Cvoid}, Ptr{Cvoid}),
                      n, m, floatarray(vec(perms) .- 1), floatarray(vec(vals))))
end

"Orderings to sample for Shapley shares among n contributors (Lean `shapley_sample_count_ref`): ⌈ln(2n/δ) / (2ε²)⌉."
function shapley_sample_count(n::Integer; ε::Real, δ::Real)
    check(n >= 1 && isfinite(ε) && 0 < ε < 1 && isfinite(δ) && 0 < δ < 1, "n positive, ε and δ in (0, 1)")
    Int(ccall(sym(:bf_shapley_sample_count), Csize_t, (Csize_t, Float64, Float64), n, ε, δ))
end

"""
    shapley_shares(val, n; rng, exact_max, ε, δ) -> shares

Shapley shares among n contributors from a coalition-value oracle `val(mask)` (bit i − 1 of
`mask` set when contributor i acts): exact (`shapley`) up to `exact_max` contributors, sampled
(`shapley_sampled`, orderings drawn from `rng`) beyond.
"""
function shapley_shares(val, n::Integer; rng::AbstractRNG, exact_max::Integer = SHAPLEY_EXACT_MAX,
                        ε::Real = SHAPLEY_ε, δ::Real = SHAPLEY_δ)
    check(0 <= n <= 62, "at most 62 contributors (coalitions are 62-bit masks)")
    n == 0 && return Float64[]
    n <= exact_max && return shapley([val(mask) for mask in 0:(2^n - 1)])
    m = shapley_sample_count(n; ε, δ)
    perms = reduce(hcat, [randperm(rng, n) for _ in 1:m])
    vals = zeros(n + 1, m)
    for k in 1:m
        mask = 0
        vals[1, k] = val(0)
        for p in 1:n
            mask |= 1 << (perms[p, k] - 1)
            vals[p + 1, k] = val(mask)
        end
    end
    shapley_sampled(perms, vals)
end

"Whether contributions come from the causal assessment (confident enough) rather than traversal (L94)."
function cc_assessed(confidence::Real; threshold::Real)
    check(all(x -> isfinite(x) && 0 <= x <= 1, (confidence, threshold)), "confidence and threshold in [0, 1]")
    ccall(sym(:bf_cc_assessed), UInt8, (Float64, Float64), confidence, threshold) == 1
end

"Fallback shares by traversal (L95): net contributions weighted by decay^degree of separation, normalised."
function traversal_shares(net_contribution, degree; decay::Real)
    check(length(net_contribution) == length(degree) && all(x -> isfinite(x) && x >= 0, net_contribution) &&
          all(d -> isfinite(d) && d >= 0, degree), "one non-negative contribution and degree per link")
    check(isfinite(decay) && 0 < decay <= 1, "decay in (0, 1]")
    lean_floats(ccall(sym(:bf_traversal_shares), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Float64),
                      floatarray(net_contribution), floatarray(degree), decay))
end

"Crime (L115): harm through informed volition or informed inaction against a committed action; else accident."
is_crime(informed::Bool, volition::Bool, breached_duty::Bool) =
    ccall(sym(:bf_is_crime), UInt8, (UInt8, UInt8, UInt8), informed, volition, breached_duty) == 1

# The governed parameter space (`Systems.ParamSpace` [R]; L157 SigThGv), in the order of `ParamVector`.
const PARAM_FIELDS = (:alpha, :beta, :gamma, :delta, :kappa, :q_plus, :q_minus, :lambda, :kappa_value, :kappa_harm,
                      :q_harm, :nu, :h_param, :lambda_plus, :lambda_minus, :th_sig, :th_gov, :fr_thConf, :fr_thHigh,
                      :sev_irreparable, :sev_irreversible, :sev_longterm, :sev_passing, :sev_timeLoss, :h_window,
                      :deleg_cap, :ehr_margin, :dist_weight)

"The bootstrap parameter vector (`bootstrapParams`)."
function bootstrap_params()
    check(ccall(sym(:bf_param_count), Csize_t, (Ptr{Cvoid},), C_NULL) == length(PARAM_FIELDS), "field lists must agree")
    lean_floats(ccall(sym(:bf_bootstrap_params), Ptr{Cvoid}, (Ptr{Cvoid},), C_NULL))
end

"Whether a parameter vector is admissible: the ranges and joint constraints the proofs rely on."
function admissible(v)
    length(v) == length(PARAM_FIELDS) && all(isfinite, v) || return false
    ccall(sym(:bf_admissible), UInt8, (Ptr{Cvoid},), floatarray(v)) == 1
end

"""
    select_candidate(means, ses; z) -> index

Adaptation as experimental design (Lean `select_candidate_ref`): the incumbent is first; shift to
the best candidate only if it beats the incumbent by `z` combined standard errors (1-based).
"""
function select_candidate(means, ses; z::Real)
    check(length(means) == length(ses) >= 1 && all(isfinite, means) && all(x -> isfinite(x) && x >= 0, ses),
          "one finite mean and non-negative standard error per candidate")
    check(isfinite(z) && z >= 0, "z non-negative")
    Int(ccall(sym(:bf_select_candidate), Csize_t, (Ptr{Cvoid}, Ptr{Cvoid}, Float64), floatarray(means), floatarray(ses), z)) + 1
end

"""
    explore_pick(u, share, n) -> index

Full support where predictions are scored (Lean `explore_pick_ref`; Chen, Kash, Ruberry & Shnayder
2014): given a uniform draw `u`, the exploration share and the `n` proposals not carried out, the
1-based index of the one carried out anyway, or 0; each has chance `share / n`.
"""
function explore_pick(u::Real, share::Real, n::Integer)
    check(isfinite(u) && 0 <= u <= 1 && isfinite(share) && 0 <= share <= 1, "draw and share in [0, 1]")
    check(n >= 0, "count non-negative")
    Int(ccall(sym(:bf_explore_pick), Csize_t, (Float64, Float64, Csize_t), u, share, n))
end

"""
    binding_admits(confidences, threshold; quorum) -> Bool

Identity binding (Lean `binding_admits_ref`; Technology Network): an identity is admitted as bound to
a distinct entity only when at least `quorum` clusters' confidences reach `threshold`.
"""
function binding_admits(confidences, threshold::Real; quorum::Integer)
    check(all(c -> isfinite(c) && 0 <= c <= 1, confidences) && isfinite(threshold) && 0 <= threshold <= 1,
          "confidences and threshold in [0, 1]")
    check(quorum >= 0, "quorum non-negative")
    ccall(sym(:bf_binding_admits), UInt8, (Ptr{Cvoid}, Float64, Csize_t), floatarray(confidences), threshold, quorum) == 1
end

"""
    self_report_payout(n, e, bonus), caught_charge(clawback, bonus, audit_cost), caught_reward(clawback, n, bonus)

The reporter's schedule (Lean `self_report_payout_ref`, `caught_charge_ref`, `caught_reward_ref`;
author ruling 8.76): a self-reporter nets one exploit plus the bonus whatever it exploited before; an
exploiter caught by someone else is charged every exploit, the reporter's bonus and the audit; the
reporter is paid one exploit per exploiter plus the bonus.
"""
function self_report_payout(n::Real, e::Real, bonus::Real)
    check(isfinite(n) && n >= 0 && isfinite(e) && e >= 0 && isfinite(bonus) && bonus >= 0, "exploits, gain and bonus non-negative")
    ccall(sym(:bf_self_report_payout), Float64, (Float64, Float64, Float64), n, e, bonus)
end
"Justice for a detected false report (Lean `false_report_charge_ref`; 8.82): the harm caused, the reward received and the audit."
function false_report_charge(harm::Real, reward::Real, audit_cost::Real)
    check(all(x -> isfinite(x) && x >= 0, (harm, reward, audit_cost)), "harm, reward and audit non-negative")
    ccall(sym(:bf_false_report_charge), Float64, (Float64, Float64, Float64), harm, reward, audit_cost)
end
function caught_charge(clawback::Real, bonus::Real, audit_cost::Real)
    check(all(x -> isfinite(x) && x >= 0, (clawback, bonus, audit_cost)), "clawback, bonus and audit non-negative")
    ccall(sym(:bf_caught_charge), Float64, (Float64, Float64, Float64), clawback, bonus, audit_cost)
end
function caught_reward(clawback::Real, n::Real, bonus::Real)
    check(all(x -> isfinite(x) && x >= 0, (clawback, n, bonus)), "clawback, exploits and bonus non-negative")
    ccall(sym(:bf_caught_reward), Float64, (Float64, Float64, Float64), clawback, n, bonus)
end

"""
    ehr_expected_response(h, re_pos, re_neg; alpha, delta, margin) -> response

External harm response (Lean `ehr_expected_response_ref`; L117, `Governance.ExternalHarm` [R]): to a
harm `h` by an external aggressor, forgive with chance min(1, α·Re₊), overreact by `margin` with chance
min(1 − p_F, δ·Re₋), otherwise respond in proportion; the expected response is
h · (1 − p_F + margin · p_O).
"""
function ehr_expected_response(h::Real, re_pos::Real, re_neg::Real; alpha::Real, delta::Real, margin::Real)
    check(all(x -> isfinite(x) && x >= 0, (h, re_pos, re_neg, alpha, delta, margin)), "harm, ledgers, weights and margin non-negative")
    ccall(sym(:bf_ehr_expected_response), Float64, (Float64, Float64, Float64, Float64, Float64, Float64), alpha, delta, margin, h, re_pos, re_neg)
end

"""
    class_balanced_skill(credences, outcomes) -> skill

Attestation skill read on each side (Lean `class_balanced_skill_ref`; [P], B2): skill against a coin
toss over real entities and over false identities separately, the worse side kept.
"""
function class_balanced_skill(credences, outcomes)
    check(length(credences) == length(outcomes), "one credence per outcome")
    check(all(c -> 0 <= c <= 1, credences) && all(o -> o in (0, 1), outcomes), "credences in [0, 1], outcomes 0 or 1")
    ccall(sym(:bf_class_balanced_skill), Float64, (Ptr{Cvoid}, Ptr{Cvoid}),
          floatarray(collect(Float64, credences)), floatarray(collect(Float64, outcomes)))
end

"""
    binding_admits_weighted(confidences, weights, threshold, quorum_weight) -> Bool

Identity binding weighted by attestation record (Lean `binding_admits_weighted_ref`; [P], B2): each
cluster's say is its attestation skill clipped to [0, 1]; admitted when the clusters reaching
`threshold` weigh at least `quorum_weight`.
"""
function binding_admits_weighted(confidences, weights, threshold::Real, quorum_weight::Real)
    check(length(confidences) == length(weights), "one weight per cluster")
    check(all(c -> isfinite(c) && 0 <= c <= 1, confidences) && all(isfinite, weights) && 0 <= threshold <= 1 && quorum_weight >= 0,
          "confidences and threshold in [0, 1], finite weights, quorum weight non-negative")
    ccall(sym(:bf_binding_admits_weighted), UInt8, (Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64),
          floatarray(collect(Float64, confidences)), floatarray(collect(Float64, weights)), threshold, quorum_weight) == 1
end

"Gauging the freedom range (Lean `gauge_radius_ref`): harm within the radius shrinks it by `factor`, none widens it."
function gauge_radius(δ::Real, harmed::Bool; factor::Real)
    check(isfinite(δ) && δ > 0 && isfinite(factor) && factor > 1, "radius positive, factor above 1")
    ccall(sym(:bf_gauge_radius), Float64, (Float64, UInt8, Float64), δ, harmed, factor)
end

"Controlled perturbation: `cand` if admissible and within δ of `cur` in every governed field, else `cur`."
function perturb(cur, cand, fields; δ::Real)
    check(length(cur) == length(cand) == length(PARAM_FIELDS) && all(isfinite, cand), "two full parameter vectors")
    check(all(i -> 1 <= i <= length(PARAM_FIELDS), fields) && isfinite(δ) && δ >= 0, "fields in range, δ non-negative")
    lean_floats(ccall(sym(:bf_perturb_step), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Float64),
                      floatarray(cur), floatarray(cand), floatarray(Float64.(fields) .- 1), δ))
end

"""
    advap_reward(exploit_gain, prevented_harm; share, floor) -> reward

The reward for revealing successful gaming (AdvAp, L160; Lean `advap_reward_ref`): the exploit's
gain to a single entity plus `share` of the harm the revelation prevents, at least `floor`.
"""
function advap_reward(exploit_gain::Real, prevented_harm::Real; share::Real, floor::Real)
    check(isfinite(exploit_gain) && isfinite(prevented_harm), "gain and harm finite")
    check(isfinite(share) && share >= 0 && isfinite(floor) && floor >= 0, "share and floor finite, non-negative")
    ccall(sym(:bf_advap_reward), Float64, (Float64, Float64, Float64, Float64), exploit_gain, prevented_harm, share, floor)
end

"What an established exploit's causal chain is charged: the reward and the audit (Lean `advap_liability_ref`)."
function advap_liability(reward::Real; audit_cost::Real)
    check(isfinite(reward) && isfinite(audit_cost) && audit_cost >= 0, "reward finite, audit cost finite, non-negative")
    ccall(sym(:bf_advap_liability), Float64, (Float64, Float64), reward, audit_cost)
end

"""
    report_penalty(unfounded, threshold; audit_cost) -> penalty

What an unfounded report costs its reporter (Lean `report_penalty_ref`): nothing in good faith,
its audit once the reporter's unfounded reports in the window exceed `threshold`.
"""
function report_penalty(unfounded::Integer, threshold::Real; audit_cost::Real)
    check(unfounded >= 0 && isfinite(threshold) && threshold >= 0, "count and threshold non-negative")
    check(isfinite(audit_cost) && audit_cost >= 0, "audit cost finite, non-negative")
    ccall(sym(:bf_report_penalty), Float64, (Float64, Float64, Float64), unfounded, threshold, audit_cost)
end

"""
    escape_accept(means, ses; gains, harms, irreparable, z) -> Bool

The debatable escape's acceptance (Lean `escape_accept_ref`; L157; author rulings 8.26.3, 8.38.2):
the proposal (index 2; the incumbent first) beats the incumbent by `z` standard errors, its gains
exceed its harms where tried, and it caused no irreparable harm.
"""
function escape_accept(means, ses; gains::Real, harms::Real, irreparable::Integer, z::Real)
    check(length(means) == length(ses) == 2 && all(isfinite, means) && all(s -> isfinite(s) && s >= 0, ses), "incumbent and proposal: finite means, standard errors")
    check(isfinite(gains) && gains >= 0 && isfinite(harms) && harms >= 0 && irreparable >= 0, "gains, harms and irreparable count non-negative")
    check(isfinite(z) && z >= 0, "z non-negative")
    ccall(sym(:bf_escape_accept), UInt8, (Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64, Float64),
          floatarray(Float64.(means)), floatarray(Float64.(ses)), gains, harms, irreparable, z) == 1
end

"""
    ratchet_credence(credence, neg_share) -> credence

Escrow credence for an actor whose reputation ledgers (L101) show a negative share `neg_share`:
pulled towards a coin toss in proportion (Lean `ratchet_credence_ref`; L84; 8.42.1).
"""
function ratchet_credence(credence::Real, neg_share::Real)
    check(0 <= credence <= 1 && 0 <= neg_share <= 1, "credence and negative share in [0, 1]")
    ccall(sym(:bf_ratchet_credence), Float64, (Float64, Float64), credence, neg_share)
end

"""
    persistence(significance; z) -> Int

Consecutive trailing audit intervals whose overstatement significance (t-inflated standard errors,
oldest first) exceeds `z`; a non-deceptive interval resets it (Lean `persistence_ref`; 8.91).
"""
function persistence(significance; z::Real = 2.0)
    check(all(isfinite, significance) && isfinite(z), "significances and z finite")
    Int(ccall(sym(:bf_persistence), UInt32, (Ptr{Cvoid}, Float64), floatarray(Float64.(significance)), z))
end

"""
    overstatement_significance(errors) -> Float64

One interval's signed errors (quoted minus measured): their mean over its t-inflated standard error.
"""
function overstatement_significance(errors)
    n = length(errors)
    n < 2 && return 0.0
    m = sum(errors) / n
    s = sqrt(sum(e -> (e - m)^2, errors) / (n - 1) / n) * t_inflation(n - 1)
    s > 0 ? m / s : (m > 0 ? Inf : 0.0)
end

"""
    escalated_credence(credence, neg_share, persistence; growth = 0.5, cap = 4.0) -> credence

`ratchet_credence` with the distance from a coin toss further divided by `(1 + growth)^persistence`,
the factor at most `cap` (Lean `escalated_credence_ref`; 8.91).
"""
function escalated_credence(credence::Real, neg_share::Real, persistence::Integer; growth::Real = 0.5, cap::Real = 4.0)
    check(0 <= credence <= 1 && 0 <= neg_share <= 1, "credence and negative share in [0, 1]")
    check(persistence >= 0 && isfinite(growth) && growth > 0 && isfinite(cap) && cap >= 1, "persistence non-negative, growth positive, cap at least 1")
    ccall(sym(:bf_escalated_credence), Float64, (Float64, Float64, Float64, Float64, Float64), credence, neg_share, persistence, growth, cap)
end

"Event probability from an as-of record of `k` occurrences in `n` trials, Laplace-smoothed (Lean `event_rate_ref`; 8.87)."
function event_rate(k::Real, n::Real)
    check(0 <= k <= n && isfinite(n), "0 ≤ k ≤ n")
    ccall(sym(:bf_event_rate), Float64, (Float64, Float64), k, n)
end

"Sources' probabilities pooled by their record weights (Lean `pooled_probability_ref`; 8.87)."
function pooled_probability(probs, weights)
    check(length(probs) == length(weights) && all(p -> 0 <= p <= 1, probs) && all(>=(0), weights), "one weight ≥ 0 per probability in [0, 1]")
    ccall(sym(:bf_pooled_probability), Float64, (Ptr{Cvoid}, Ptr{Cvoid}), floatarray(collect(Float64, probs)), floatarray(collect(Float64, weights)))
end

"An option's expected effect over its scenarios (Lean `expected_effect_ref`; 8.87)."
function expected_effect(probs, effects)
    check(length(probs) == length(effects) && all(isfinite, effects), "one effect per probability")
    ccall(sym(:bf_expected_effect), Float64, (Ptr{Cvoid}, Ptr{Cvoid}), floatarray(collect(Float64, probs)), floatarray(collect(Float64, effects)))
end

"Escrow credence after `repeats` discovered deceptions (Lean `repeat_escrow_credence_ref`; author ruling on 8.91)."
function repeat_escrow_credence(credence::Real, neg_share::Real, repeats::Integer; growth::Real, floor::Real)
    check(0 <= credence <= 1 && 0 <= neg_share <= 1 && repeats >= 0 && growth >= 0 && 0 < floor <= 0.5, "credence, share in [0, 1]; repeats ≥ 0; growth ≥ 0; floor in (0, 0.5]")
    ccall(sym(:bf_repeat_escrow_credence), Float64, (Float64, Float64, Csize_t, Float64, Float64), credence, neg_share, repeats, growth, floor)
end

"""
    pragmatic_understanding(map_fit, wt, ce, acc, cy; th = 0.0)

Pragmatic understanding of a thing by a model (L31, Lean `pragmatic_understanding_ref`; proposal 8.98):
map fit × the weighted mean of causal explanation × prediction accuracy × (1 − complexity) over the items
whose weight P(X|T)·P(i|T,X)·Impact(i) reaches `th`.
"""
function pragmatic_understanding(map_fit::Real, wt, ce, acc, cy; th::Real = 0.0)
    check(length(wt) == length(ce) == length(acc) == length(cy), "one weight, explanation, accuracy and complexity per item")
    check(0 <= map_fit <= 1 && all(x -> 0 <= x <= 1, ce) && all(x -> 0 <= x <= 1, acc) && all(x -> 0 <= x <= 1, cy) && all(>=(0), wt),
          "map fit, explanation, accuracy and complexity in [0, 1]; weights non-negative")
    f(x) = floatarray(collect(Float64, x))
    ccall(sym(:bf_pragmatic_understanding), Float64, (Float64, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Float64),
          Float64(map_fit), f(wt), f(ce), f(acc), f(cy), Float64(th))
end

"Prediction accuracy net of irreducible uncertainty (Lean `relative_accuracy_ref`; author ruling 8.103)."
function relative_accuracy(credences, outcomes)
    check(length(credences) == length(outcomes) && all(c -> 0 <= c <= 1, credences) && all(o -> o in (0, 1), outcomes),
          "one credence in [0, 1] per outcome of 0 or 1")
    ccall(sym(:bf_relative_accuracy), Float64, (Ptr{Cvoid}, Ptr{Cvoid}), floatarray(collect(Float64, credences)), floatarray(collect(Float64, outcomes)))
end
