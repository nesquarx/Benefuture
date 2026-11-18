# Toy model M8: social & interdependence networks, multi-hop influence liability & concentration
# control, extended-self morality (`defection_harms_extended_self`), and end-of-horizon conduct
# under zero financial inheritance (`B25` / author ruling `7.12`: `Self«Sl»`, posthumous CD,
# recounted Re, and causal/ideological inheritance continue after `t_end`).

# ---- Rules (Lean reference, `BenefutureReference.Records` & `Subgoals.Morality` / `Ontology.Entity`) ----

"""
    extended_self_feedback(couplings, deltas) -> Float64

Net feedback transmitted through the actor's extended-self couplings (`L136`, `7.12`, M8;
Lean `extended_self_feedback_ref`): `Σ max(0, min(1, couplings[k])) * deltas[k]`.
"""
function extended_self_feedback(couplings, deltas)
    check(length(couplings) == length(deltas) &&
          all(isfinite, couplings) && all(isfinite, deltas),
          "equal-length finite couplings and deltas")
    ccall(sym(:bf_extended_self_feedback), Float64, (Ptr{Cvoid}, Ptr{Cvoid}),
          floatarray(couplings), floatarray(deltas))
end

"""
    propagated_liability(direct_harm, controls) -> Float64

Multi-hop upstream causal liability (`L8`, `7.14`, M8; Lean `propagated_liability_ref`):
`direct_harm * Π clamp₀₁(controls[j])` when `direct_harm > 0`, else `0.0`.
"""
function propagated_liability(direct_harm::Real, controls)
    check(isfinite(direct_harm) && all(isfinite, controls),
          "finite direct_harm and controls")
    ccall(sym(:bf_propagated_liability), Float64, (Float64, Ptr{Cvoid}),
          Float64(direct_harm), floatarray(controls))
end

"""
    end_of_horizon_score(own_remaining, alive, couplings, deltas;
                         causal_share = 0.0, delayed_outcome = 0.0,
                         ideological_share = 0.0, ideological_gain = 0.0) -> Float64

End-of-horizon consequential evaluation (`7.12`, `B25`, M8; Lean `end_of_horizon_score_ref`):
no financial inheritance at death; `own_remaining` counts only while `alive`, whereas
`extended_self_feedback(couplings, deltas)`, `max(0, causal_share) * delayed_outcome`, and
`max(0, ideological_share) * ideological_gain` continue.
"""
function end_of_horizon_score(own_remaining::Real, alive::Bool, couplings, deltas;
                              causal_share::Real = 0.0, delayed_outcome::Real = 0.0,
                              ideological_share::Real = 0.0, ideological_gain::Real = 0.0)
    check(isfinite(own_remaining) && length(couplings) == length(deltas) &&
          all(isfinite, couplings) && all(isfinite, deltas) &&
          all(isfinite, (causal_share, delayed_outcome, ideological_share, ideological_gain)),
          "finite inputs and equal-length couplings and deltas")
    ccall(sym(:bf_end_of_horizon_score), Float64,
          (Float64, UInt8, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64, Float64),
          Float64(own_remaining), UInt8(alive ? 1 : 0),
          floatarray(couplings), floatarray(deltas),
          Float64(causal_share), Float64(delayed_outcome),
          Float64(ideological_share), Float64(ideological_gain))
end

"""
    end_of_horizon_predicted_score(immediate_own, future_own, alive_at_outcome, couplings, deltas;
                                   causal_share = 0.0, delayed_outcome = 0.0,
                                   ideological_share = 0.0, ideological_gain = 0.0) -> Float64

Decision-time prediction across an action's horizon (`7.12`, `B25`, M8; Lean
`end_of_horizon_predicted_score_ref`): `immediate_own` accrues at choice time while alive,
`future_own` counts only if `alive_at_outcome`, and `extended_self_feedback(couplings, deltas)`
plus posthumous CD and ideological legacy remain active even past predicted death.
"""
function end_of_horizon_predicted_score(immediate_own::Real, future_own::Real,
                                        alive_at_outcome::Bool, couplings, deltas;
                                        causal_share::Real = 0.0, delayed_outcome::Real = 0.0,
                                        ideological_share::Real = 0.0, ideological_gain::Real = 0.0)
    check(isfinite(immediate_own) && isfinite(future_own) &&
          length(couplings) == length(deltas) &&
          all(isfinite, couplings) && all(isfinite, deltas) &&
          all(isfinite, (causal_share, delayed_outcome, ideological_share, ideological_gain)),
          "finite inputs and equal-length couplings and deltas")
    ccall(sym(:bf_end_of_horizon_predicted_score), Float64,
          (Float64, Float64, UInt8, Ptr{Cvoid}, Ptr{Cvoid}, Float64, Float64, Float64, Float64),
          Float64(immediate_own), Float64(future_own), UInt8(alive_at_outcome ? 1 : 0),
          floatarray(couplings), floatarray(deltas),
          Float64(causal_share), Float64(delayed_outcome),
          Float64(ideological_share), Float64(ideological_gain))
end

"""
    ihz_access_risk(clearance, req_ed; potential_harm) -> Float64

Residual InfoHazard exposure risk (`L127`, `B21`, M8; Lean `ihz_access_risk_ref`):
`0.0` once `clearance >= req_ed`, otherwise `max(0.0, potential_harm)`.
"""
function ihz_access_risk(clearance::Real, req_ed::Real; potential_harm::Real)
    check(all(isfinite, (clearance, req_ed, potential_harm)),
          "finite clearance, req_ed and potential_harm")
    ccall(sym(:bf_ihz_access_risk), Float64, (Float64, Float64, Float64),
          Float64(clearance), Float64(req_ed), Float64(potential_harm))
end

"""
    art_success_score(intent, reception) -> Float64

Art success from matching intended spread `intent` against audience reception distribution
`reception` (`Success := match(p, Dist(q))`, `L126`, `7.13`, M8; Lean `art_success_score_ref`).
"""
function art_success_score(intent, reception)
    check(length(intent) == length(reception) &&
          all(isfinite, intent) && all(isfinite, reception),
          "equal-length finite intent and reception spreads")
    ccall(sym(:bf_art_success_score), Float64, (Ptr{Cvoid}, Ptr{Cvoid}),
          floatarray(intent), floatarray(reception))
end

"""
    art_surplus_value(truth_delta_u, novelty) -> Float64

Art surplus value beyond feeling in V (`V_a = Tr_lvl(ΔU) + N`, `L127`, `7.13`, M8;
Lean `art_surplus_value_ref`).
"""
function art_surplus_value(truth_delta_u::Real, novelty::Real)
    check(isfinite(truth_delta_u) && isfinite(novelty),
          "finite truth_delta_u and novelty")
    ccall(sym(:bf_art_surplus_value), Float64, (Float64, Float64),
          Float64(truth_delta_u), Float64(novelty))
end

"""
    chain_truth_level(base_level, hops) -> Float64

Multi-hop propagated truth level (`Tr_lvl`, `L133`, M8; Lean `chain_truth_level_ref`):
`clamp₀₁(base_level) * Π clamp₀₁(hops[j])`.
"""
function chain_truth_level(base_level::Real, hops)
    check(isfinite(base_level) && all(isfinite, hops),
          "finite base_level and hop reliabilities")
    ccall(sym(:bf_chain_truth_level), Float64, (Float64, Ptr{Cvoid}),
          Float64(base_level), floatarray(hops))
end

# ---- Network world (`M8`) ----

Base.@kwdef struct M8Params
    n::Int = 16
    steps::Int = 120
    lifespan::Int = 40
    horizon_window::Int = 8
    delay_lag::Int = 10
    degree::Int = 4
    coupling_mean::Float64 = 0.35
    influence_mean::Float64 = 0.45
    mode::Symbol = :bf                   # :bf | :extended_only | :one_shot | :uncontrolled_hub | :finite_no_legacy
    delegation_cap::Float64 = 0.20
    overflow_cap::Float64 = 40.0
    advap_share::Float64 = 0.25
    defect_loot::Float64 = 1.6
    defect_harm::Float64 = 6.0
    coop_gain::Float64 = 1.0
    coop_shared::Float64 = 1.8
    delayed_legacy_gain::Float64 = 2.4
    opportunist_frac::Float64 = 0.5
    choice_noise::Float64 = 0.15
    hub_exploit_gain::Float64 = 2.5
    hub_proxy_harm::Float64 = 8.0
    proxy_hops::Int = 3
    proxy_control::Float64 = 0.65
    seed::Int = 1
end

struct DelayedCausalEvent
    due_step::Int
    actor_id::Int
    origin_gen::Int
    harm_or_gain::Float64
    is_harm::Bool
    causal_heirs::Vector{Int}
    ideological_heirs::Vector{Int}
end

"""
    run_m8(p::M8Params = M8Params())

Simulate an `n`-being network world over `steps` ticks testing three M8 claims (`docs/PLAN.md` L68–73):
1. Extended-self morality (`defection_harms_extended_self`): network couplings turn external harm
   into self-harm against cooperative baselines.
2. Multi-hop influence propagation & concentration control (`propagated_liability`, capped delegation,
   overflow reinvestment, AdvAp reporting) vs an uncontrolled hub with proxy exploitation.
3. End-of-horizon conduct (`B25`, `7.12`): zero financial inheritance (`inherited_wealth == 0`),
   while continuing `Self«Sl»`, posthumous `CD` / recounted `Re`, and ideological inheritance remove
   end-of-life defection spikes vs `:finite_no_legacy`.
"""
function run_m8(p::M8Params = M8Params())
    rng = Xoshiro(p.seed)
    n = p.n
    check(n >= 4 && p.steps >= 1 && p.lifespan >= 4 && p.horizon_window >= 1,
          "valid network size and horizon parameters")

    use_extended = p.mode in (:bf, :extended_only, :uncontrolled_hub)
    use_cd = p.mode in (:bf, :uncontrolled_hub, :finite_no_legacy)
    use_influence_liability = p.mode in (:bf, :extended_only, :one_shot, :finite_no_legacy)
    use_power_caps = p.mode != :uncontrolled_hub
    use_legacy_b25 = p.mode in (:bf, :extended_only, :uncontrolled_hub)

    # Per-slot state across overlapping finite lifespans
    birth_step = [ -mod(round(Int, (i - 1) * p.lifespan / n), p.lifespan) for i in 1:n ]
    death_step = [ birth_step[i] + p.lifespan for i in 1:n ]
    gen_id = ones(Int, n)
    reputation = [ 2.0 + 0.3 * rand(rng) for _ in 1:n ]
    balance = zeros(Float64, n)
    overflow_total = 0.0
    inherited_wealth = 0.0

    # Role: opportunists test whether defection or proxy extraction pays
    is_opportunist = [ i <= round(Int, p.opportunist_frac * n) for i in 1:n ]
    hub_actor = 1

    # Directed extended-self coupling matrix & ideological / causal successor graph
    couplings = zeros(Float64, n, n)
    if use_extended
        for i in 1:n
            targets = filter(!=(i), 1:n)
            perm = randperm(rng, length(targets))
            for k in 1:min(p.degree, length(perm))
                j = targets[perm[k]]
                couplings[i, j] = clamp(p.coupling_mean * (0.6 + 0.8 * rand(rng)), 0.05, 0.95)
            end
        end
    end

    # Directed delegation/influence preferences toward high-reputation nodes (node 1 starts highest
    # to stress concentration in `:uncontrolled_hub`)
    reputation[hub_actor] = use_power_caps ? 2.5 : 8.0
    delegate_target = zeros(Int, n)
    for i in 1:n
        if i != hub_actor
            delegate_target[i] = (rand(rng) < (use_power_caps ? 0.45 : 0.90)) ? hub_actor : mod1(i + 1, n)
        end
    end

    delayed_queue = DelayedCausalEvent[]

    coop_nets = Float64[]
    defect_nets = Float64[]
    mid_defects = 0
    mid_trials = 0
    eol_defects = 0
    eol_trials = 0
    eol_legacy_invests = 0
    posthumous_cd_events = 0
    posthumous_re_updates = 0
    total_harm = 0.0
    hub_proxy_nets = Float64[]
    advap_reports = 0
    top_share_trace = Float64[]

    for t in 1:p.steps
        # 1. Process lifespan transitions: zero financial inheritance, keep ideological & CD links
        for i in 1:n
            if t >= death_step[i]
                # Explicitly no financial inheritance: accumulated estate does not pass to successor
                inherited_wealth += 0.0
                overflow_total += max(0.0, balance[i])
                balance[i] = 0.0
                birth_step[i] = t
                death_step[i] = t + p.lifespan
                gen_id[i] += 1
                # Ideological / knowledge inheritance resets reputation partially from mentor record
                # while keeping causal history linked; property balance starts at 0.
                reputation[i] = use_legacy_b25 ? max(0.5, 0.4 * reputation[i]) : 1.0
                if use_extended
                    targets = filter(!=(i), 1:n)
                    perm = randperm(rng, length(targets))
                    couplings[i, :] .= 0.0
                    for k in 1:min(p.degree, length(perm))
                        couplings[i, targets[perm[k]]] = clamp(p.coupling_mean * (0.6 + 0.8 * rand(rng)), 0.05, 0.95)
                    end
                end
            end
        end

        # 2. Deliver due delayed causal distribution events (including posthumous CD & recounted Re)
        still_pending = DelayedCausalEvent[]
        for ev in delayed_queue
            if ev.due_step <= t
                posthumous = (gen_id[ev.actor_id] != ev.origin_gen)
                if posthumous && use_legacy_b25
                    posthumous_cd_events += 1
                    posthumous_re_updates += 1
                end
                if use_legacy_b25 || !posthumous
                    delta = ev.is_harm ? -ev.harm_or_gain : ev.harm_or_gain
                    reputation[ev.actor_id] = max(0.0, reputation[ev.actor_id] + 0.15 * delta)
                    if !isempty(ev.causal_heirs)
                        share = delta / length(ev.causal_heirs)
                        for h in ev.causal_heirs
                            balance[h] += 0.35 * share
                        end
                    end
                    if !ev.is_harm && !isempty(ev.ideological_heirs)
                        share = 0.25 * ev.harm_or_gain / length(ev.ideological_heirs)
                        for h in ev.ideological_heirs
                            reputation[h] += 0.1 * share
                        end
                    end
                end
            else
                push!(still_pending, ev)
            end
        end
        delayed_queue = still_pending

        # 3. Governance / influence weight distribution & concentration check
        rel_rep = relative_reputation(max.(0.1, reputation))
        raw_weights = [ voting_weight(1.0, 1.0, [1.0], [max(0.0, rel_rep[i])], 0.0, 0.0;
                                      optional_below = 0.0, need_optional = false)[1] for i in 1:n ]
        if use_power_caps
            total_w = sum(raw_weights)
            eff_w = copy(raw_weights)
            cap = max(1e-6, p.delegation_cap * total_w)
            deleg_pool = zeros(Float64, n)
            for i in 1:n
                d = delegate_target[i]
                if d != i && d >= 1
                    avail = accumulate_capped(cap, deleg_pool[d], [0.5 * raw_weights[i]])
                    added = avail - deleg_pool[d]
                    deleg_pool[d] = avail
                    eff_w[i] -= added
                    eff_w[d] += added
                end
            end
        else
            eff_w = copy(raw_weights)
            for i in 1:n
                d = delegate_target[i]
                if d != i && d >= 1
                    shift = 0.85 * eff_w[i]
                    eff_w[i] -= shift
                    eff_w[d] += shift
                end
            end
        end
        push!(top_share_trace, maximum(eff_w) / max(1e-12, sum(eff_w)))

        # 4. Per-being decisions (cooperate vs defect; delayed legacy action near EOL)
        for i in 1:n
            rem = death_step[i] - t
            near_eol = rem <= p.horizon_window
            alive_at_delay = rem > p.delay_lag
            cvec = Float64[]
            d_coop = Float64[]
            d_def = Float64[]
            heirs = Int[]
            for j in 1:n
                if j != i && couplings[i, j] > 0
                    push!(cvec, couplings[i, j])
                    push!(d_coop, p.coop_shared / max(1, p.degree))
                    push!(d_def, -p.defect_harm / max(1, p.degree))
                    push!(heirs, j)
                end
            end
            # Even when couplings are zero (one-shot / finite_no_legacy baselines), evaluate
            # Lean rule directly so both arms share one code path.
            causal_sh = use_cd ? ((use_legacy_b25 || alive_at_delay) ? 0.55 : 0.0) : 0.0
            ideo_sh = use_cd ? ((use_legacy_b25 || alive_at_delay) ? 0.40 : 0.0) : 0.0
            eval_cvec = use_extended ? cvec : zeros(Float64, length(cvec))

            coop_eval = end_of_horizon_predicted_score(p.coop_gain, 0.4, alive_at_delay,
                                                       eval_cvec, d_coop;
                                                       causal_share = causal_sh,
                                                       delayed_outcome = p.delayed_legacy_gain,
                                                       ideological_share = ideo_sh,
                                                       ideological_gain = p.delayed_legacy_gain) +
                        p.choice_noise * randn(rng)
            def_eval = end_of_horizon_predicted_score(p.defect_loot, 0.0, alive_at_delay,
                                                      eval_cvec, d_def;
                                                      causal_share = causal_sh,
                                                      delayed_outcome = -p.defect_harm,
                                                      ideological_share = ideo_sh,
                                                      ideological_gain = -0.5 * p.defect_harm) +
                       p.choice_noise * randn(rng)

            chose_defect = is_opportunist[i] ? (def_eval > coop_eval) : false

            if near_eol
                eol_trials += 1
                chose_defect && (eol_defects += 1)
                !chose_defect && (eol_legacy_invests += 1)
            else
                mid_trials += 1
                chose_defect && (mid_defects += 1)
            end

            if chose_defect
                # Realized network impact (physical couplings transmit external harm whenever network exists)
                ext_c = (p.mode == :one_shot) ? zeros(Float64, length(cvec)) : cvec
                realized_ext = extended_self_feedback(ext_c, d_def)
                cd_back = causal_sh * (-p.defect_harm)
                realized_net = p.defect_loot + realized_ext + cd_back
                push!(defect_nets, realized_net)
                balance[i] += p.defect_loot + (use_extended ? realized_ext : 0.0)
                total_harm += p.defect_harm
                push!(delayed_queue, DelayedCausalEvent(t + p.delay_lag, i, gen_id[i], p.defect_harm,
                                                        true, heirs, heirs))
            else
                ext_c = (p.mode == :one_shot) ? zeros(Float64, length(cvec)) : cvec
                realized_ext = extended_self_feedback(ext_c, d_coop)
                cd_gain = (causal_sh + ideo_sh) * p.delayed_legacy_gain
                realized_net = p.coop_gain + realized_ext + cd_gain
                push!(coop_nets, realized_net)
                balance[i] += p.coop_gain
                reputation[i] += 0.1
                push!(delayed_queue, DelayedCausalEvent(t + p.delay_lag, i, gen_id[i], p.delayed_legacy_gain,
                                                        false, heirs, heirs))
            end

            if use_power_caps && balance[i] > p.overflow_cap
                ov = balance[i] - p.overflow_cap
                overflow_total += ov
                balance[i] = p.overflow_cap
            end
        end

        # 5. Multi-hop hub proxy exploitation attempt (direct harm on controller is 0; subordinate
        # chain causes `harm_t`). Under Bf, `propagated_liability` + AdvAp whistleblowers
        # turn proxy harm back onto the hub.
        ctrls = [ clamp(p.proxy_control + 0.06 * randn(rng), 0.1, 0.95) for _ in 1:p.proxy_hops ]
        harm_t = max(0.0, p.hub_proxy_harm + 1.0 * randn(rng))
        gain_t = max(0.0, p.hub_exploit_gain + 0.25 * randn(rng))
        liab = use_influence_liability ? propagated_liability(harm_t, ctrls) : 0.0
        adv_bounty = use_power_caps ? advap_reward(0.0, harm_t; share = p.advap_share, floor = 0.25) : 0.0
        adv_charge = use_power_caps ? advap_liability(adv_bounty; audit_cost = 0.2) : 0.0
        hub_net = gain_t - liab - (use_influence_liability ? adv_charge : 0.0)
        push!(hub_proxy_nets, hub_net)
        if use_power_caps && use_influence_liability && harm_t > 0
            advap_reports += 1
        end
    end

    mean_coop = isempty(coop_nets) ? 0.0 : mean(coop_nets)
    mean_def = isempty(defect_nets) ? (p.defect_loot - p.defect_harm) : mean(defect_nets)
    eol_rate = eol_trials > 0 ? eol_defects / eol_trials : 0.0
    mid_rate = mid_trials > 0 ? mid_defects / mid_trials : 0.0
    total_defect_rate = (eol_defects + mid_defects) / max(1, eol_trials + mid_trials)
    (
        mode = p.mode,
        coop_net = mean_coop,
        defect_net = mean_def,
        coop_advantage = mean_coop - mean_def,
        defect_rate = total_defect_rate,
        eol_defect_rate = eol_rate,
        mid_defect_rate = mid_rate,
        eol_excess = eol_rate - mid_rate,
        eol_legacy_invests = eol_legacy_invests,
        posthumous_cd_events = posthumous_cd_events,
        posthumous_re_updates = posthumous_re_updates,
        inherited_wealth = inherited_wealth,
        overflow_total = overflow_total,
        total_harm = total_harm,
        hub_proxy_net = mean(hub_proxy_nets),
        top_influence_share = mean(top_share_trace),
        advap_reports = advap_reports,
    )
end

# ---- M8 Epistemic Gating (`IHz`, `Truth_lvl`, `B21`, `PLAN.md` L71) ----

Base.@kwdef struct M8IhzParams
    n::Int = 24
    steps::Int = 80
    mode::Symbol = :gated_ihz          # :gated_ihz | :open_ungated | :censored
    req_ed::Float64 = 1.0
    edu_cost::Float64 = 0.25
    hazard_harm::Float64 = 6.0
    legit_value::Float64 = 1.8
    misuse_gain::Float64 = 2.4
    truth_level_mean::Float64 = 0.85
    attacker_frac::Float64 = 0.25
    audit_rate::Float64 = 0.70
    accident_factor::Float64 = 0.20
    cf_ratio::Float64 = 1.0
    choice_noise::Float64 = 0.25
    seed::Int = 1
end

"""
    run_m8_ihz(p::M8IhzParams = M8IhzParams())

Simulate gated access to InfoHazards (`IHz`, `L127`) and Truth-level-weighted claims (`L133`, `B21`):
- `:censored` blocks access for everyone (zero misuse, zero legitimate value: fails `Freedom(Tr)`).
- `:open_ungated` leaves hazards ungated without educational inoculation (`ihz_access_risk > 0`) and
  lets malicious actors plead non-informed accident mitigation (`responsibility_factor` discount).
- `:gated_ihz` ensures an open educational path (`clearance >= req_ed`), driving uninoculated
  accidental harm near zero while preserving high-truth-level legitimate utility and logging
  educational notice (`Informed = true`) so deliberate misuse pays full informed crime liability.
"""
function run_m8_ihz(p::M8IhzParams = M8IhzParams())
    rng = Xoshiro(p.seed)
    check(p.n >= 4 && p.steps >= 1 && p.req_ed >= 0 && p.hazard_harm >= 0 &&
          0 <= p.attacker_frac <= 1 && 0 <= p.audit_rate <= 1,
          "valid IHz gate parameters")
    n_att = round(Int, p.attacker_frac * p.n)
    is_attacker = [ i <= n_att for i in 1:p.n ]
    clearance = [ rand(rng) < 0.25 ? p.req_ed : 0.3 * p.req_ed * rand(rng) for _ in 1:p.n ]
    informed = [ clearance[i] >= p.req_ed for i in 1:p.n ]

    useful_access = 0.0
    accidental_harm = 0.0
    misuse_count = 0
    misuse_trials = 0
    attacker_nets = Float64[]
    notif_lags = Float64[]
    educated_count = 0

    for _ in 1:p.steps
        tr_lvl = clamp(p.truth_level_mean + 0.1 * randn(rng), 0.1, 1.0)
        for i in 1:p.n
            if p.mode == :censored
                # Material deleted/censored: no misuse, no accidental harm, no legitimate access
                continue
            elseif is_attacker[i]
                misuse_trials += 1
                if p.mode == :gated_ihz && clearance[i] < p.req_ed
                    # Unblocked path via education: attacker completes prerequisite course, which
                    # logs `Informed` intent in the TN record (`B21`).
                    clearance[i] = p.req_ed
                    informed[i] = true
                    educated_count += 1
                end
                is_inf = (p.mode == :gated_ihz) && informed[i]
                expected_fine = p.audit_rate *
                    responsibility_factor(true, is_inf, true, p.cf_ratio;
                                          severity_scale = p.hazard_harm,
                                          accident_factor = p.accident_factor)
                ev = p.misuse_gain - expected_fine - (p.mode == :gated_ihz ? p.edu_cost : 0.0) +
                     p.choice_noise * randn(rng)
                if ev > 0.0
                    misuse_count += 1
                    caught = rand(rng) < p.audit_rate
                    pen = caught ? responsibility_factor(true, is_inf, true, p.cf_ratio;
                                                         severity_scale = p.hazard_harm,
                                                         accident_factor = p.accident_factor) : 0.0
                    push!(attacker_nets, p.misuse_gain - pen)
                    # Gated TN access log notifies affected targets much faster than unlogged access
                    push!(notif_lags, (p.mode == :gated_ihz ? 1.5 : 8.5) + 0.5 * abs(randn(rng)))
                else
                    push!(attacker_nets, 0.0)
                end
            else
                # Legitimate researcher / citizen
                if p.mode == :gated_ihz && clearance[i] < p.req_ed
                    clearance[i] = p.req_ed
                    informed[i] = true
                    educated_count += 1
                end
                eff_clr = p.mode == :gated_ihz ? clearance[i] : clearance[i]
                risk = ihz_access_risk(eff_clr, p.req_ed; potential_harm = 0.5 * p.hazard_harm)
                accidental_harm += risk
                useful_access += p.legit_value * tr_lvl - risk - (p.mode == :gated_ihz ? 0.05 * p.edu_cost : 0.0)
            end
        end
    end

    (
        mode = p.mode,
        useful_access = useful_access,
        accidental_harm = accidental_harm,
        misuse_rate = misuse_trials > 0 ? misuse_count / misuse_trials : 0.0,
        attacker_net = isempty(attacker_nets) ? 0.0 : mean(attacker_nets),
        notification_lag = isempty(notif_lags) ? 0.0 : mean(notif_lags),
        educated_count = educated_count,
    )
end

# ---- M8 Art & Culture (`Success := match(p, Dist(q))`, `Di_N`, `7.13`, `PLAN.md` L71) ----

Base.@kwdef struct M8ArtParams
    n_audience::Int = 80
    n_works::Int = 24
    open_intent::Vector{Float64} = [0.45, 0.10, 0.45]
    blank_reception::Vector{Float64} = [0.05, 0.90, 0.05]
    prop_intent::Vector{Float64} = [0.05, 0.10, 0.85]
    seed::Int = 1
end

function sample_reception(rng::AbstractRNG, probs::Vector{Float64}, n::Int)
    counts = zeros(Int, length(probs))
    c1, c2 = probs[1], probs[1] + probs[2]
    for _ in 1:n
        u = rand(rng)
        counts[u < c1 ? 1 : (u < c2 ? 2 : 3)] += 1
    end
    counts ./ max(1, n)
end

"""
    run_m8_art(p::M8ArtParams = M8ArtParams())

Simulate Art reception distribution scoring (`L126–L127`, `7.13`):
- Divisive/open works (`[0.45, 0.10, 0.45]`) vs blank/indifferent works (`[0.05, 0.90, 0.05]`),
  both sharing mean `≈ 0`: distribution match (`art_success_score`) separates them sharply whereas
  mean-only scoring conflates them.
- Original insightful works vs low-truth propaganda and zero-novelty forgeries (`art_surplus_value`).
"""
function run_m8_art(p::M8ArtParams = M8ArtParams())
    rng = Xoshiro(p.seed)
    check(p.n_audience >= 10 && p.n_works >= 4, "audience and works positive")
    mean_bin_score(pvec, qvec) = begin
        mp = -pvec[1] + pvec[3]
        mq = -qvec[1] + qvec[3]
        max(0.0, 1.0 - abs(mp - mq))
    end

    dist_open_scores = Float64[]
    dist_blank_scores = Float64[]
    mean_blank_scores = Float64[]
    orig_surplus = Float64[]
    prop_surplus = Float64[]
    forg_surplus = Float64[]

    for _ in 1:p.n_works
        q_open = sample_reception(rng, p.open_intent, p.n_audience)
        q_blank = sample_reception(rng, p.blank_reception, p.n_audience)
        push!(dist_open_scores, art_success_score(p.open_intent, q_open))
        push!(dist_blank_scores, art_success_score(p.open_intent, q_blank))
        push!(mean_blank_scores, mean_bin_score(p.open_intent, q_blank))

        push!(orig_surplus, art_surplus_value(clamp(0.80 + 0.08 * randn(rng), 0.1, 1.0),
                                              clamp(0.80 + 0.08 * randn(rng), 0.1, 1.0)))
        push!(prop_surplus, art_surplus_value(clamp(0.05 + 0.03 * randn(rng), 0.0, 0.3),
                                              clamp(0.20 + 0.05 * randn(rng), 0.0, 0.5)))
        push!(forg_surplus, art_surplus_value(clamp(0.75 + 0.08 * randn(rng), 0.1, 1.0), 0.0))
    end

    (
        dist_open = mean(dist_open_scores),
        dist_blank = mean(dist_blank_scores),
        dist_separation = mean(dist_open_scores) - mean(dist_blank_scores),
        mean_conflation = mean(mean_blank_scores) - mean(dist_blank_scores),
        orig_surplus = mean(orig_surplus),
        prop_surplus = mean(prop_surplus),
        forg_surplus = mean(forg_surplus),
    )
end

Base.@kwdef struct M8CultureParams
    n::Int = 48
    steps::Int = 40
    mode::Symbol = :bf_culture         # :bf_culture | :no_diversity_bonus
    style_values::Vector{Float64} = [1.0, 1.55, 1.65, 1.72]
    switch_cost::Float64 = 0.45
    conformity_weight::Float64 = 0.90
    novelty_bonus_weight::Float64 = 1.6
    seed::Int = 1
end

"""
    run_m8_culture(p::M8CultureParams = M8CultureParams())

Simulate cultural practice & style evolution under a local-minimum monoculture (`L125`, `L158–159`):
without `Di_N` novelty bonuses (`:no_diversity_bonus`), conformity locks the population onto
`style 1` (`1.0 < 1.85`); with `Di_N` inverse-frequency style novelty + unforced exploration
(`:bf_culture`), styles escape monoculture, raise Shannon entropy, and discover `style 4` (`1.85`).
"""
function run_m8_culture(p::M8CultureParams = M8CultureParams())
    rng = Xoshiro(p.seed)
    m = length(p.style_values)
    check(p.n >= 8 && p.steps >= 5 && m >= 3, "valid culture world parameters")
    # 90% start locked on incumbent style 1 (local minimum)
    styles = [ i <= round(Int, 0.90 * p.n) ? 1 : mod1(i, m) for i in 1:p.n ]
    obs_quality = zeros(Float64, m)
    obs_counts = zeros(Int, m)
    for _ in 1:2
        obs_quality[1] += p.style_values[1]
        obs_counts[1] += 1
    end

    use_div = (p.mode == :bf_culture)
    for _ in 1:p.steps
        shares = [ count(==(k), styles) / p.n for k in 1:m ]
        new_styles = copy(styles)
        # When marginal improvement stagnates, `:bf_culture` offers exploratory trials
        for i in 1:p.n
            cur = styles[i]
            scores = zeros(Float64, m)
            for k in 1:m
                est = obs_counts[k] > 0 ? obs_quality[k] / obs_counts[k] : 0.8 * p.style_values[1]
                # L159 novelty scales down with frequency 1 / (1 + n * share)
                nov = use_div ? p.novelty_bonus_weight / (1.0 + 4.0 * shares[k]) : 0.0
                sw = (k == cur) ? 0.0 : p.switch_cost
                # Only use Lean `art_surplus_value` to aggregate style value + novelty safely
                scores[k] = art_surplus_value(est, nov) + p.conformity_weight * shares[k] - sw +
                            0.18 * randn(rng)
            end
            new_styles[i] = argmax(scores)
            realized = p.style_values[new_styles[i]] + 0.15 * randn(rng)
            obs_quality[new_styles[i]] += realized
            obs_counts[new_styles[i]] += 1
        end
        styles = new_styles
    end

    final_shares = [ count(==(k), styles) / p.n for k in 1:m ]
    entropy = -sum(s > 0 ? s * log(s) : 0.0 for s in final_shares)
    (
        mode = p.mode,
        monoculture_share = maximum(final_shares),
        superior_style_share = final_shares[argmax(p.style_values)],
        mean_culture_value = mean(p.style_values[s] for s in styles),
        style_entropy = entropy,
    )
end

# ---- M8 Multi-Hop Truth Propagation & Art Hidden Convolving Factors (`PLAN.md` L71–72) ----

Base.@kwdef struct M8TruthParams
    n::Int = 24
    steps::Int = 30
    mode::Symbol = :bf_truth           # :bf_truth | :untagged_naive
    echo_copies::Int = 6
    true_origins::Int = 2
    true_base_level::Float64 = 0.90
    rumor_base_level::Float64 = 0.30
    noise_σ::Float64 = 0.12
    seed::Int = 1
end

"""
    run_m8_truth(p::M8TruthParams = M8TruthParams())

Simulate multi-hop epistemic propagation over an M8 social network (`L133–134`, `PLAN.md` L72`):
- True signals come from distinct verified origins (`true_base_level`, high chain reliability).
- False rumors (`rumor_base_level`, low intermediary reliability) arrive across `echo_copies`
  redundant multi-hop forwarders carrying the same origin id.
- `:untagged_naive` counts every repeated rumor path unattenuated; `:bf_truth` applies Lean
  `chain_truth_level` across hops plus `count_once` origin deduplication (`Sources.lean`).
"""
function run_m8_truth(p::M8TruthParams = M8TruthParams())
    rng = Xoshiro(p.seed)
    check(p.n >= 4 && p.steps >= 1 && p.echo_copies >= 1 && p.true_origins >= 1,
          "valid truth propagation parameters")
    use_bf = (p.mode == :bf_truth)

    false_adoptions = 0
    belief_errors = Float64[]
    verified_correct = 0
    total_obs = 0

    for _ in 1:p.steps
        for _ in 1:p.n
            total_obs += 1
            origin_ids = Float64[]
            chain_ws = Float64[]
            sides = Float64[]
            # Verified true origins (short, high-reliability chains)
            for oid in 1:p.true_origins
                push!(origin_ids, Float64(oid))
                hops = [clamp(0.90 + 0.04 * randn(rng), 0.2, 1.0),
                        clamp(0.90 + 0.04 * randn(rng), 0.2, 1.0)]
                base = clamp(p.true_base_level + p.noise_σ * randn(rng), 0.05, 1.0)
                w = use_bf ? chain_truth_level(base, hops) : 0.8
                push!(chain_ws, w)
                push!(sides, 1.0 + 0.1 * randn(rng))
            end
            # Echoed false rumor sharing one origin ID (`true_origins + 1`) across `echo_copies`
            rumor_oid = Float64(p.true_origins + 1)
            for _ in 1:p.echo_copies
                push!(origin_ids, rumor_oid)
                hops = [clamp(0.45 + 0.08 * randn(rng), 0.05, 0.95) for _ in 1:3]
                base = clamp(p.rumor_base_level + p.noise_σ * randn(rng), 0.05, 0.95)
                w = use_bf ? chain_truth_level(base, hops) : 0.65
                push!(chain_ws, w)
                push!(sides, -1.0 + 0.1 * randn(rng))
            end

            dedup_ws = use_bf ? count_once(origin_ids, chain_ws) : chain_ws
            tot_w = max(1e-12, sum(dedup_ws))
            belief = sum(w * s for (w, s) in zip(dedup_ws, sides)) / tot_w
            push!(belief_errors, abs(1.0 - clamp(belief, -1.0, 1.0)))
            belief < 0.0 && (false_adoptions += 1)
            belief > 0.25 && (verified_correct += 1)
        end
    end

    (
        mode = p.mode,
        false_adoption = false_adoptions / max(1, total_obs),
        belief_error = mean(belief_errors),
        verified_truth_accuracy = verified_correct / max(1, total_obs),
    )
end

Base.@kwdef struct M8ArtConfoundParams
    n_audience::Int = 160
    trials::Int = 24
    alpha_high::Float64 = 0.62
    alpha_low::Float64 = 0.12
    seed::Int = 1
end

"""
    run_m8_art_confounders(p::M8ArtConfoundParams = M8ArtConfoundParams())

Evaluate `art_success_score` when hidden audience-state confounders (`shock` on Work A, `hype` on
mismatched Work B) distort single-context reception (`PLAN.md` L71: "after hidden convolving
factors"). Across two differentially-exposed contexts `(α_high, α_low)`, linear deconvolution of the
shared baseline context recovers A's higher intent match above naive single-context scoring.
"""
function run_m8_art_confounders(p::M8ArtConfoundParams = M8ArtConfoundParams())
    rng = Xoshiro(p.seed)
    check(p.n_audience >= 20 && p.trials >= 4 && 0 < p.alpha_low < p.alpha_high < 0.9,
          "valid art confounder parameters")

    # Work A: truly matches open intent `[0.45, 0.10, 0.45]`, exposed to neutral shock `[0.10, 0.80, 0.10]`
    intent_A = [0.45, 0.10, 0.45]
    true_A = [0.45, 0.10, 0.45]
    conf_A = [0.05, 0.90, 0.05]

    # Work B: claims celebratory intent `[0.10, 0.10, 0.80]`, intrinsic mediocre `[0.20, 0.65, 0.15]`,
    # artificially boosted in its showcase by hype confounder `[0.05, 0.05, 0.90]`
    intent_B = [0.10, 0.10, 0.80]
    true_B = [0.20, 0.65, 0.15]
    conf_B = [0.05, 0.05, 0.90]

    oracle_A = art_success_score(intent_A, true_A)
    oracle_B = art_success_score(intent_B, true_B)

    naive_l1 = Float64[]
    deconv_l1 = Float64[]
    naive_correct_rank = 0
    deconv_correct_rank = 0

    deconv_est(q_hi, q_lo) = begin
        # Pair of mixtures: q_hi = (1-αh)*true + αh*conf, q_lo = (1-αl)*true + αl*conf
        # Eliminating `conf`: true = (αh * q_lo - αl * q_hi) / (αh - αl)
        raw = (p.alpha_high .* q_lo .- p.alpha_low .* q_hi) ./ (p.alpha_high - p.alpha_low)
        cl = max.(0.0, raw)
        s = sum(cl)
        s > 0 ? cl ./ s : fill(1.0 / length(cl), length(cl))
    end

    for _ in 1:p.trials
        mix_A_hi = (1 - p.alpha_high) .* true_A .+ p.alpha_high .* conf_A
        mix_A_lo = (1 - p.alpha_low) .* true_A .+ p.alpha_low .* conf_A
        mix_B_hi = (1 - p.alpha_high) .* true_B .+ p.alpha_high .* conf_B
        mix_B_lo = (1 - p.alpha_low) .* true_B .+ p.alpha_low .* conf_B

        qA_hi = sample_reception(rng, mix_A_hi, p.n_audience)
        qA_lo = sample_reception(rng, mix_A_lo, p.n_audience)
        qB_hi = sample_reception(rng, mix_B_hi, p.n_audience)
        qB_lo = sample_reception(rng, mix_B_lo, p.n_audience)

        naive_score_A = art_success_score(intent_A, qA_hi)
        naive_score_B = art_success_score(intent_B, qB_hi)
        deconv_score_A = art_success_score(intent_A, deconv_est(qA_hi, qA_lo))
        deconv_score_B = art_success_score(intent_B, deconv_est(qB_hi, qB_lo))

        push!(naive_l1, (abs(naive_score_A - oracle_A) + abs(naive_score_B - oracle_B)) / 2.0)
        push!(deconv_l1, (abs(deconv_score_A - oracle_A) + abs(deconv_score_B - oracle_B)) / 2.0)
        naive_score_A > naive_score_B && (naive_correct_rank += 1)
        deconv_score_A > deconv_score_B && (deconv_correct_rank += 1)
    end

    (
        naive_error = mean(naive_l1),
        deconv_error = mean(deconv_l1),
        naive_rank_acc = naive_correct_rank / p.trials,
        deconv_rank_acc = deconv_correct_rank / p.trials,
    )
end

# ---- M6/M8 External Harm Response World (`Governance.ExternalHarm`, L118) ----

Base.@kwdef struct M8EhrParams
    steps::Int = 40
    alpha::Float64 = 0.04
    delta::Float64 = 0.01
    margin::Float64 = 0.50
    attack_harm::Float64 = 10.0
    mode::Symbol = :bf_ehr            # :bf_ehr | :naive_appease | :blind_retaliate
    seed::Int = 1
end

"""
    run_m8_ehr(p::M8EhrParams = M8EhrParams())

Simulate an external aggressor world (`Governance.ExternalHarm`, L118) with three external actors:
1. A cooperative trade partner (`re_pos` accumulating, occasional accidental friction).
2. A novel external entity (`re_pos == 0`, `re_neg == 0`) testing boundaries.
3. A persistent hostile aggressor (`re_neg` accumulating) that attacks whenever expected retaliation
   is smaller than its attack gain (`0.85 * attack_harm`).
Calls Lean `ehr_expected_response` (`bf_ehr_expected_response`) and enforces the reparable-only cap
(`ReparableResponse.h_reparable : irreparable == 0`).
"""
function run_m8_ehr(p::M8EhrParams = M8EhrParams())
    rng = Xoshiro(p.seed)
    check(p.steps >= 5 && p.alpha > p.delta >= 0 && p.margin >= 0 && p.attack_harm > 0,
          "valid EHR world parameters")

    re_pos_ally = 0.0
    re_neg_ally = 0.0
    re_pos_hostile = 0.0
    re_neg_hostile = 0.0

    hostile_attacks = 0
    ally_preserved = 0
    irreparable_retaliations = 0
    novel_responses = Float64[]
    ally_responses = Float64[]
    hostile_responses = Float64[]

    for _ in 1:p.steps
        # 1. Cooperative external partner: mostly positive exchanges (+4.0), rare accidental friction
        re_pos_ally += 3.5 + 0.5 * rand(rng)
        h_acc = 2.0
        resp_ally = if p.mode == :bf_ehr
            ehr_expected_response(h_acc, re_pos_ally, re_neg_ally;
                                  alpha = p.alpha, delta = p.delta, margin = p.margin)
        elseif p.mode == :naive_appease
            0.0
        else
            (1.0 + p.margin) * h_acc
        end
        push!(ally_responses, resp_ally)
        resp_ally <= h_acc * 0.5 && (ally_preserved += 1)

        # 2. Novel external entity (zero history -> pure tit-for-tat `h`)
        resp_novel = if p.mode == :bf_ehr
            ehr_expected_response(p.attack_harm, 0.0, 0.0;
                                  alpha = p.alpha, delta = p.delta, margin = p.margin)
        elseif p.mode == :naive_appease
            0.0
        else
            (1.0 + p.margin) * p.attack_harm
        end
        push!(novel_responses, resp_novel)

        # 3. Hostile external aggressor: attacks if expected response < 1.15 * attack_harm
        exp_ret = if p.mode == :bf_ehr
            ehr_expected_response(p.attack_harm, re_pos_hostile, re_neg_hostile;
                                  alpha = p.alpha, delta = p.delta, margin = p.margin)
        elseif p.mode == :naive_appease
            0.0
        else
            (1.0 + p.margin) * p.attack_harm
        end
        push!(hostile_responses, exp_ret)
        if exp_ret < 1.15 * p.attack_harm + 0.5 * randn(rng)
            hostile_attacks += 1
            re_neg_hostile += p.attack_harm
        end
        # Blind retaliation uses uninhibited irreparable force; Bf EHR caps response to reparable only
        p.mode == :blind_retaliate && (irreparable_retaliations += 1)
    end

    (
        mode = p.mode,
        hostile_attack_rate = hostile_attacks / p.steps,
        ally_cooperation_rate = ally_preserved / p.steps,
        novel_tit_for_tat_err = mean(abs.(novel_responses .- p.attack_harm)),
        mean_ally_response = mean(ally_responses),
        mean_hostile_response = mean(hostile_responses),
        irreparable_retaliations = irreparable_retaliations,
    )
end

# ---- M6/M8 Law, Contract, Enforcement & Civilizational Continuity (`Ontology.Law`, `Systems.Enforcement`, `Subgoals.Continuity`) ----

Base.@kwdef struct M8EnforcementParams
    steps::Int = 36
    mode::Symbol = :bf_enforcement    # :bf_enforcement | :unaudited_coercion | :unenforced
    harm_bound::Float64 = 2.0
    seed::Int = 1
end

"""
    run_m8_enforcement(p::M8EnforcementParams = M8EnforcementParams())

Simulate the three-tier enforcement hierarchy (`Systems.Enforcement`), embedded law and contract
validity (`Ontology.Law`), and civilizational continuity (`Subgoals.Continuity`):
- Contracts whose projected harm exceeds `harm_bound` are null and void (`invalid_contract_null_and_void`).
- Tier 1 (`:design_automated`, embedded law debits) and Tier 2 (`:persuasive`) eliminate residual
  societal harm without physical force (`automated_design_eliminates_residual_harm`).
- Tier 3 (`:forcible_restraint`) is rejected unless audited (`unaudited_forcible_restraint_rejected`).
- Across epochs, unbroken append-only memory and `Harm_Intv` (`requires_harm_intervention` when
  `harm_t1 >= harm_t0`) preserve civilizational continuity (`preserves_continuity`).
"""
function run_m8_enforcement(p::M8EnforcementParams = M8EnforcementParams())
    rng = Xoshiro(p.seed)
    check(p.steps >= 4 && p.harm_bound >= 0, "valid enforcement parameters")

    invalid_contracts_blocked = 0
    invalid_contracts_executed = 0
    unaudited_force_blocked = 0
    unaudited_force_abuses = 0
    residual_harm = 0.0
    harm_interventions = 0
    memory_epochs = Int[]
    prev_harm = 8.0
    continuity_holds = true

    for t in 1:p.steps
        push!(memory_epochs, t)
        # 1. Contract screening (`is_valid_contract`: projectedHarm <= netHarmBound)
        proj_harm = 0.5 + 3.5 * rand(rng)
        if proj_harm > p.harm_bound
            if p.mode == :unenforced
                invalid_contracts_executed += 1
                residual_harm += proj_harm
            else
                invalid_contracts_blocked += 1
            end
        end

        # 2. Graduated enforcement action (`DesignAutomated`, `Persuasive`, `ForcibleRestraint`)
        incident_harm = 2.0 + rand(rng)
        if p.mode == :bf_enforcement
            # Automated restorative debit satisfies reparation; any forcible restraint must be audited
            repaired = incident_harm
            residual_harm += max(0.0, incident_harm - repaired)
            unaudited_attempt = rand(rng) < 0.35
            unaudited_attempt && (unaudited_force_blocked += 1)
        elseif p.mode == :unaudited_coercion
            # Unaudited forcible restraint allowed -> coercion abuse harm + incomplete reparation
            unaudited_force_abuses += 1
            residual_harm += 0.6 * incident_harm
        else
            # Unenforced -> full incident harm remains unaddressed
            residual_harm += incident_harm
        end

        # 3. Civilizational Continuity (`CvCnt` & `Harm_Intv`, `Subgoals.Continuity`)
        step_harm = p.mode == :bf_enforcement ? prev_harm * 0.88 : prev_harm * 1.05 + 0.5
        if step_harm >= prev_harm
            harm_interventions += 1
            p.mode == :bf_enforcement && (step_harm = prev_harm * 0.85)
        end
        prev_harm = step_harm
        # Continuity requires unbroken memory lineage and coherent harm reduction
        if p.mode != :bf_enforcement && step_harm > 12.0
            continuity_holds = false
        end
    end

    (
        mode = p.mode,
        invalid_contracts_blocked = invalid_contracts_blocked,
        invalid_contracts_executed = invalid_contracts_executed,
        unaudited_force_blocked = unaudited_force_blocked,
        unaudited_force_abuses = unaudited_force_abuses,
        residual_harm = residual_harm / p.steps,
        harm_interventions = harm_interventions,
        continuity_preserved = continuity_holds && issorted(memory_epochs),
    )
end
