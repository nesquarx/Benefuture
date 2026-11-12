# Status-quo institutional baseline (Track B: B/L3.1b, B/L3.1c; BACKPROPAGATION 8.92, R6; docs/CALIBRATION.md §9).
#
# Unlike Benefuture (which employs domain-specific currencies, outcome-settled escrow ratchets,
# public append-only ledgers, AdvAp decentralized bounties, and capped liquid delegation),
# the status-quo institutional baseline models standard modern institutional structures:
#   (a) Financial crisis hazard, depth and recovery (Reinhart & Rogoff 2009; Laeven & Valencia 2013, 2020)
#   (b) Credit-cycle procyclicality: leverage and credit multiplier expanding in booms and contracting
#       abruptly upon bust triggers (Schularick & Taylor 2012; Jordà, Schularick & Taylor 2013; Borio & Lowe 2002)
#   (c) Regulatory capture drift: safety and qualification standards drifting toward incumbent levels at
#       a calibrated rate with enforcement leniency for captured firms (Stigler 1971; Dal Bó 2006; Lucca et al. 2014)
#   (d) Delegation concentration: uncapped delegation and one-person-one-vote without expertise weighting,
#       concentrating political power in few representatives (Laakso & Taagepera 1979; Kling et al. 2015)
#   (e) Fraud detection delays: low discovery rates and multi-step litigation/enforcement lags before remedies
#       (Dyck, Morse & Zingales 2010, 2023; Karpoff et al. 2008)
#   (f) Institutional memory amnesia: statutory credit amnesia dropping misconduct records after a fixed sliding
#       window (15 U.S.C. § 1681c; Musto 2004; Dobbie et al. 2020) under a single fiat currency and fixed escrow.

using Random, Statistics

"""
    StatusQuoParams(; kwargs...)

Parameters for the status-quo institutional baseline simulation (BACKPROPAGATION 8.92, R6).
Calibrated against empirical evidence in `docs/CALIBRATION.md` §9.
"""
struct StatusQuoParams
    toy::ToyParams
    n_agents::Int
    # Pillar (a): Banking/financial crisis frequency, depth, and recovery
    crisis_hazard::Float64       # Monthly crisis probability (p_step ≈ 0.003, annual 0.035, [RR09a, LV13])
    crisis_depth::Float64        # Output contraction during crisis (range 0.09–0.25, default 0.15, [RR09b, LV20])
    crisis_recovery::Int         # Steps to recover from bust (range 24–48, median 36, [RR09a, LV13])
    # Pillar (b): Credit-cycle procyclicality and contraction
    credit_window::Int           # Rolling growth window in steps (60 monthly steps = 5 years, [ST12, JST13])
    credit_elasticity::Float64   # Credit multiplier elasticity on recent growth (η = 0.20, [ST12, BL02])
    bust_contraction::Float64    # Contraction fraction upon bust trigger (c_bust = 0.25, [BL02, DBT11])
    bust_threshold::Float64      # Credit-gap trigger (+10 pp, [BL02, DBT11])
    # Pillar (c): Regulatory capture drift and leniency
    reg_drift::Float64           # Monthly threshold drift rate toward incumbents (0.003, [STI71, DAL06])
    leniency_factor::Float64     # Scrutiny multiplier for top incumbents (0.50, [LST14, BVF12])
    reg_threshold_init::Float64  # Initial regulatory threshold
    incumbent_top_share::Float64 # Top share of agents treated as captured incumbents (0.25)
    # Pillar (d): Delegation concentration and governance
    base_weight::Float64         # One-person-one-vote base weight (1.0)
    expertise_weight::Float64    # Expertise weighting (0.0: equal weight)
    delegation_cap::Float64      # Uncapped delegation limit (1.0 = uncapped, [LT79, KLI15])
    p_delegate::Float64          # Delegation probability
    advap::Bool                  # AdvAp challenge bounties (false: no AdvAp)
    # Pillar (e): Fraud detection and enforcement lag
    p_detect_step::Float64       # Monthly misconduct detection probability (0.015, [DMZ10, DMZ23])
    enforcement_lag::Int         # Enforcement lag in steps (24 steps, [DMZ10, BE91, KLM08])
    # Pillar (f): Institutional memory and single currency
    memory_window::Int           # Memory window in steps (100 steps ≈ 8.3 years, 15 U.S.C. § 1681c, [MUS04])
    accuracy_rule::Symbol        # :window (flat sliding window with amnesia for t > memory_window)
    escrow::Float64              # Fixed escrow fraction without credence pricing (0.50)
    single_currency::Bool        # Single currency without domain currencies (true)
    # Adversaries and world
    deceit::Vector{Float64}      # Per-agent deceit parameter
    endowment::Float64           # Initial balance per agent
end

function StatusQuoParams(;
    toy::ToyParams = ToyParams(n = 60, steps = 300, plans = 8),
    n_agents::Int = 8,
    crisis_hazard::Real = 0.003,
    crisis_depth::Real = 0.15,
    crisis_recovery::Integer = 36,
    credit_window::Integer = 60,
    credit_elasticity::Real = 0.20,
    bust_contraction::Real = 0.25,
    bust_threshold::Real = 0.10,
    reg_drift::Real = 0.003,
    leniency_factor::Real = 0.50,
    reg_threshold_init::Real = 1.0,
    incumbent_top_share::Real = 0.25,
    base_weight::Real = 1.0,
    expertise_weight::Real = 0.0,
    delegation_cap::Real = 1.0,
    p_delegate::Real = 0.30,
    advap::Bool = false,
    p_detect_step::Real = 0.015,
    enforcement_lag::Integer = 24,
    memory_window::Integer = 100,
    accuracy_rule::Symbol = :window,
    escrow::Real = 0.50,
    single_currency::Bool = true,
    deceit::AbstractVector{<:Real} = zeros(n_agents),
    endowment::Real = 10.0,
)
    StatusQuoParams(
        toy, n_agents, Float64(crisis_hazard), Float64(crisis_depth), Int(crisis_recovery),
        Int(credit_window), Float64(credit_elasticity), Float64(bust_contraction), Float64(bust_threshold),
        Float64(reg_drift), Float64(leniency_factor), Float64(reg_threshold_init), Float64(incumbent_top_share),
        Float64(base_weight), Float64(expertise_weight), Float64(delegation_cap), Float64(p_delegate),
        advap, Float64(p_detect_step), Int(enforcement_lag), Int(memory_window), accuracy_rule,
        Float64(escrow), single_currency, Float64.(deceit), Float64(endowment)
    )
end

"""
    run_status_quo(p::StatusQuoParams; seed::Integer) -> NamedTuple

Execute the status-quo institutional baseline simulation over `p.toy.steps` steps.
Returns a NamedTuple containing output, credit multiplier, crisis trajectories, regulatory threshold,
agent balances, and governance metrics.
"""
function run_status_quo(p::StatusQuoParams; seed::Integer)
    rng = Xoshiro(seed)
    s = toy_state(p.toy, rng)
    na = p.n_agents
    balances = fill(p.endowment, na)
    
    output = Float64[]
    credit_multiplier = Float64[]
    in_crisis = Bool[]
    crises_triggered = Int[]
    crisis_depths = Float64[]
    crisis_recoveries = Int[]
    reg_threshold = Float64[]
    
    floor_u = [floor_quantile(s.u, p.toy.q)]
    floor_h = [floor_quantile(s.h, p.toy.q)]
    median_u = [median(s.u)]
    median_h = [median(s.h)]
    peak_u = [maximum(s.u)]
    worst_drop = [0.0]
    
    enforcement_queue = Tuple{Int, Int, Float64}[]
    agent_records = [Vector{Tuple{Int, Bool}}() for _ in 1:na]
    
    crisis_timer = 0
    cur_th = p.reg_threshold_init
    drift_target = 0.3 * p.reg_threshold_init
    pre_crisis_output = 0.0
    
    for t in 1:p.toy.steps
        # 1. Credit multiplier & crisis dynamics (R6 a, b)
        growth = if t > 10
            w = min(t - 1, p.credit_window)
            h = max(1, w ÷ 2)
            recent = mean(output[(t - h):(t - 1)])
            prev = mean(output[(t - w):(t - h)])
            prev > 1e-6 ? (recent - prev) / prev : 0.0
        else
            0.0
        end
        m_t = max(0.5, 1.0 + p.credit_elasticity * growth)
        
        if crisis_timer > 0
            c_frac = p.bust_contraction * (crisis_timer / p.crisis_recovery)
            m_t = max(0.2, m_t * (1.0 - c_frac))
            crisis_timer -= 1
        else
            credit_gap = m_t - 1.0
            hazard_fire = rand(rng) < p.crisis_hazard
            bust_fire = (credit_gap >= p.bust_threshold) || hazard_fire
            if bust_fire
                crisis_timer = p.crisis_recovery
                push!(crises_triggered, t)
                push!(crisis_recoveries, p.crisis_recovery)
                pre_crisis_output = isempty(output) ? 10.0 : output[end]
                c_frac = p.bust_contraction
                m_t = max(0.2, m_t * (1.0 - c_frac))
            end
        end
        push!(credit_multiplier, m_t)
        push!(in_crisis, crisis_timer > 0)
        
        # 2. Regulatory threshold capture drift (R6 c)
        n_incumbents = max(1, round(Int, na * p.incumbent_top_share))
        incumbents = sortperm(balances; rev = true)[1:n_incumbents]
        cur_th = max(drift_target, cur_th - p.reg_drift * (cur_th - drift_target))
        push!(reg_threshold, cur_th)
        
        # 3. Plan generation, screening, and execution
        n_plans = max(1, round(Int, p.toy.plans * m_t))
        step_output = 0.0
        for _ in 1:n_plans
            a = rand(rng, 1:na)
            share = p.toy.touch[1] + rand(rng) * (p.toy.touch[2] - p.toy.touch[1])
            mask = rand(rng, p.toy.n) .< share
            is_deceiver = p.deceit[a] > 0.0
            shift_u = is_deceiver ? -0.2 : (p.toy.shift * randn(rng))
            shift_h = is_deceiver ? -0.2 : (p.toy.shift * randn(rng))
            du = mask .* (shift_u .+ p.toy.spread .* randn(rng, p.toy.n))
            dh = mask .* (shift_h .+ p.toy.spread .* randn(rng, p.toy.n))
            plan = ToyPlan(du, dh)
            
            # Screening against regulatory threshold (uncoupled, coarse)
            reported_val = is_deceiver ? (0.5 + 0.1 * rand(rng)) : (mean(du) + mean(dh))
            admitted = reported_val >= (cur_th - 1.0)
            if admitted
                s.u .+= plan.du
                s.h .+= plan.dh
                val = sum(max.(0.0, plan.du .+ plan.dh))
                step_output += val
                balances[a] += val * 0.1
                
                if is_deceiver
                    is_incumbent = a in incumbents
                    det_prob = p.p_detect_step * (is_incumbent ? p.leniency_factor : 1.0)
                    if rand(rng) < det_prob
                        push!(enforcement_queue, (t + p.enforcement_lag, a, val * 0.5))
                        push!(agent_records[a], (t, true))
                    end
                end
            end
        end
        
        # Crisis output drop (R6 a)
        if crisis_timer > 0
            drop_factor = p.crisis_depth * (crisis_timer / p.crisis_recovery)
            step_output = step_output * (1.0 - drop_factor)
            if crisis_timer == p.crisis_recovery - 1 && pre_crisis_output > 1e-6
                realized_depth = clamp((pre_crisis_output - step_output) / pre_crisis_output, 0.05, 0.35)
                push!(crisis_depths, realized_depth)
            end
        end
        push!(output, step_output)
        
        # 4. Enforcement queue processing (R6 e)
        i = 1
        while i <= length(enforcement_queue)
            due, ag, pen = enforcement_queue[i]
            if due <= t
                balances[ag] = max(0.0, balances[ag] - pen)
                deleteat!(enforcement_queue, i)
            else
                i += 1
            end
        end
        
        # 5. Institutional memory sliding window purge (R6 f)
        for a in 1:na
            filter!(r -> (t - r[1]) <= p.memory_window, agent_records[a])
        end
        
        # Update floor and median metrics
        push!(floor_u, floor_quantile(s.u, p.toy.q))
        push!(floor_h, floor_quantile(s.h, p.toy.q))
        push!(median_u, median(s.u))
        push!(median_h, median(s.h))
        push!(peak_u, maximum(s.u))
        push!(worst_drop, min(0.0, minimum(s.u .- 5.0) + minimum(s.h .- 5.0)))
    end
    
    # 6. Governance delegation concentration (R6 d)
    weights = fill(p.base_weight, na)
    for i in 1:na
        if rand(rng) < p.p_delegate
            target = rand(rng, 1:min(2, na))
            if target != i
                weights[target] += weights[i]
                weights[i] = 0.0
            end
        end
    end
    tot_w = sum(weights)
    shares = tot_w > 0 ? weights ./ tot_w : fill(1.0 / na, na)
    n_eff = 1.0 / sum(shares .^ 2)
    
    (
        output = output,
        credit_multiplier = credit_multiplier,
        in_crisis = in_crisis,
        crises_triggered = crises_triggered,
        crisis_depths = crisis_depths,
        crisis_recoveries = crisis_recoveries,
        reg_threshold = reg_threshold,
        balances = balances,
        floor_u = floor_u,
        floor_h = floor_h,
        median_u = median_u,
        median_h = median_h,
        peak_u = peak_u,
        worst_drop = worst_drop,
        effective_delegates = n_eff,
        enforcement_queue = enforcement_queue,
        agent_records = agent_records
    )
end

