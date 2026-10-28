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
