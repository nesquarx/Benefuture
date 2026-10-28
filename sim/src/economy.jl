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

"Controlled perturbation: `cand` if admissible and within δ of `cur` in every governed field, else `cur`."
function perturb(cur, cand, fields; δ::Real)
    check(length(cur) == length(cand) == length(PARAM_FIELDS) && all(isfinite, cand), "two full parameter vectors")
    check(all(i -> 1 <= i <= length(PARAM_FIELDS), fields) && isfinite(δ) && δ >= 0, "fields in range, δ non-negative")
    lean_floats(ccall(sym(:bf_perturb_step), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Float64),
                      floatarray(cur), floatarray(cand), floatarray(Float64.(fields) .- 1), δ))
end
