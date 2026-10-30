# Escrow (L84), reputation decay (L101), resource cost and pricing (L82, L83, L86, L99), computed by
# the Lean reference (`Escrow_split_ref`, `Rep_decay_ref`, `resource_cost_ref`,
# `transaction_price_ref`, `supply_delta_ref`, `competition_efficiency_ref`).

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
