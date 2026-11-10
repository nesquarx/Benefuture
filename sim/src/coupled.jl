# Coupled economy and governance (L3.2; L113 BfDm, L114 LqdBfDm, L157 SigThGv, L74 Goal).
#
# Steps an M3c economy in epochs of `epoch` steps. At each epoch end:
# (a) governance decides on the economy's governed thresholds through the existing M4 path
#     (SigThGv perturbation candidates) with voters weighted by their reputation from the
#     economy's records so far (`voting_weight`, `relative_reputation`, `accumulate_capped`,
#     `audited_out`), and the adopted thresholds apply to the next epoch;
# (b) when `coupled = true`, each decision resolves by the economy's measured outcome over the
#     next epoch (`success_pattern`) and feeds voters' records (`vote_reputation`) and candidate
#     evaluation (`select_candidate`); when `coupled = false` (uncoupled), governance never sees
#     the economy's measured outcomes, so a harmful threshold candidate on offer cannot be
#     rejected by outcomes.

using Random, Statistics

const COUPLED_GOV_FIELDS = [1, 2, 3, 6, 7, 8]

function _with_param_vector(t::ToyParams, v::AbstractVector{<:Real})
    ToyParams(n = t.n, steps = t.steps, plans = t.plans, q = t.q, th = t.th, touch = t.touch,
              shift = t.shift, spread = t.spread,
              gp = (α = v[1], β = v[2], γ = v[3], λ = v[8], qp = v[6], qm = v[7]))
end

function _with_econ_epoch(p::M3cParams, pv::AbstractVector{<:Real}, epoch_steps::Integer;
                          threshold::Union{Nothing,Real} = nothing,
                          track_window::Union{Nothing,Integer} = nothing,
                          init_steps::Integer = p.init_steps)
    t = _with_param_vector(p.toy, pv)
    t_ep = ToyParams(n = t.n, steps = epoch_steps, plans = t.plans, q = t.q, th = t.th,
                     touch = t.touch, shift = t.shift, spread = t.spread, gp = t.gp)
    th = threshold === nothing ? p.threshold : Float64(threshold)
    tw = track_window === nothing ? p.track_window : Int(track_window)
    # Copy every field, overriding these four: positional lists break whenever M3cParams gains a field.
    over = Dict{Symbol,Any}(:toy => t_ep, :threshold => th, :track_window => tw, :init_steps => Int(init_steps))
    M3cParams((get(over, f, getfield(p, f)) for f in fieldnames(M3cParams))...)
end

"""
    run_coupled(econ, gov; seed, epoch = 25, coupled = true, candidate_pv = nothing, candidate_threshold = nothing, candidate_track_window = nothing) -> NamedTuple

Step the M3c economy `econ` in epochs of `epoch` steps (default 25), coupled to M5 liquid-democracy
governance (`gov`, an `M5Params` or a builder `tr -> M5Params`). At each epoch end:
(a) governance decides on the economy's governed thresholds through the M4 path (`perturb`,
    `admissible`) with voters weighted by their reputation from the economy's records so far
    (`voting_weight`, `relative_reputation`, `accumulate_capped`, `audited_out`), and the adopted
    thresholds apply to the next epoch;
(b) when `coupled = true`, each decision resolves by the economy's measured outcome over the next
    epoch (`success_pattern`), feeding voters' records (`vote_reputation`) and rejecting candidates
    whose measured outcome degrades the floors (`select_candidate`). When `coupled = false`,
    governance never observes the economy's outcomes.
"""
function run_coupled(econ::M3cParams, gov; seed::Integer, epoch::Integer = 25,
                     coupled::Bool = true,
                     candidate_pv::Union{Nothing,AbstractVector{<:Real}} = nothing,
                     candidate_threshold::Union{Nothing,Real} = nothing,
                     candidate_track_window::Union{Nothing,Integer} = nothing)
    check(epoch >= 1 && econ.toy.steps >= epoch, "epoch must be positive and within total steps")
    n_epochs = econ.toy.steps ÷ epoch
    check(n_epochs >= 1, "at least one epoch required")

    na = length(econ.agents)
    nd = count(econ.known)
    grng = Xoshiro(hash((seed, :coupled_gov)))
    arng = Xoshiro(hash((seed, :coupled_ability)))
    crng = Xoshiro(hash((seed, :coupled_choice)))

    pv_inc = bootstrap_params()
    pv_cur = copy(pv_inc)
    th_inc = econ.threshold
    th_cur = th_inc
    tw_inc = econ.track_window
    tw_cur = tw_inc

    # Accumulate continuous floor/median/peak trajectories across epochs.
    s0 = toy_state(econ.toy, Xoshiro(seed))
    floor_u = [floor_quantile(s0.u, econ.toy.q)]
    floor_h = [floor_quantile(s0.h, econ.toy.q)]
    median_u = [median(s0.u)]
    median_h = [median(s0.h)]
    peak_u = [maximum(s0.u)]
    worst_drop = [0.0]

    reputation = zeros(na, nd)
    record = [Bool[] for _ in 1:na, _ in 1:nd]
    params_trace = [copy(pv_cur)]
    thresholds_trace = [th_cur]
    track_windows_trace = [tw_cur]
    adopted_candidate = Bool[]
    epoch_outcomes = NamedTuple[]
    rejected = false
    rejected_epoch = 0
    cand_scores = Float64[]
    inc_scores = Float64[]

    # Pending decision from the end of epoch e-1 to be resolved by epoch e's measured outcome.
    pending_vote = nothing

    for ep in 1:n_epochs
        ep_init = ep == 1 ? min(econ.init_steps, epoch ÷ 2) : 0
        p_ep = _with_econ_epoch(econ, pv_cur, epoch; threshold = th_cur, track_window = tw_cur, init_steps = ep_init)
        tr_ep = run_m3c(p_ep; seed = Int(hash((seed, :epoch, ep)) & 0x7fffffff))

        # Stitch step-by-step deltas onto the running state trace.
        du_fl = diff(tr_ep.floor_u)
        dh_fl = diff(tr_ep.floor_h)
        du_md = diff(tr_ep.median_u)
        dh_md = diff(tr_ep.median_h)
        du_pk = diff(tr_ep.peak_u)
        for s in 1:epoch
            push!(floor_u, floor_u[end] + du_fl[s])
            push!(floor_h, floor_h[end] + dh_fl[s])
            push!(median_u, median_u[end] + du_md[s])
            push!(median_h, median_h[end] + dh_md[s])
            push!(peak_u, peak_u[end] + du_pk[s])
            push!(worst_drop, tr_ep.worst_drop[s + 1])
        end

        sp = success_pattern(tr_ep; from = max(1, ep_init + 1))
        push!(epoch_outcomes, sp)
        outcome_val = sp.floor_u + sp.floor_h

        # Accumulate economy reputation from the epoch's records, decayed across epochs.
        rate_g = decay_rate_for(1.0; λpos = econ.λpos, λneg = econ.λneg)
        reputation .= reputation_decay.(reputation, Float64(epoch); rate = rate_g) .+ tr_ep.relevance_leaf[:, 1:nd]

        # Build M5 parameters for this epoch using the accumulated economy reputation.
        gp = gov isa M5Params ? gov : gov(tr_ep)

        # (b) Resolve the previous epoch's governance decision by the economy's measured outcome.
        if coupled && pending_vote !== nothing
            # A candidate succeeds only if the economy's floors did not fall and it did not underperform the incumbent.
            floors_held = sp.floor_u >= -1e-9 && sp.floor_h >= -1e-9 && outcome_val >= (isempty(inc_scores) ? 0.0 : mean(inc_scores) - 0.5)
            if pending_vote.chose_cand
                push!(cand_scores, outcome_val)
            else
                push!(inc_scores, outcome_val)
            end
            right_side = floors_held ? 1.0 : -1.0
            scale_k = max(sum(max.(reputation[:, pending_vote.k], 0.0)) / na, 1e-6)
            for i in 1:na
                pending_vote.delegated[i] && continue
                right_i = pending_vote.votes[i] == right_side
                reputation[i, pending_vote.k] += vote_reputation(right_i, gp.vote_value, scale_k, na, pending_vote.held[i], pending_vote.total)
                push!(record[i, pending_vote.k], right_i)
                length(record[i, pending_vote.k]) > max(gp.audit_window, 1) && popfirst!(record[i, pending_vote.k])
            end
            # If the candidate degraded the floors or failed `select_candidate` against the incumbent, reject it.
            if pending_vote.chose_cand && !floors_held
                ms = [isempty(inc_scores) ? 1.0 : mean(inc_scores), mean(cand_scores)]
                ses = [length(inc_scores) < 2 ? 0.1 : std(inc_scores) / sqrt(length(inc_scores)),
                       length(cand_scores) < 2 ? 0.1 : std(cand_scores) / sqrt(length(cand_scores))]
                if select_candidate(ms, ses; z = econ.gov_z) == 1
                    rejected = true
                    rejected_epoch == 0 && (rejected_epoch = ep)
                    pv_cur = copy(pv_inc)
                    th_cur = th_inc
                    tw_cur = tw_inc
                end
            end
        else
            push!(inc_scores, outcome_val)
        end

        # (a) At epoch end, governance decides on the next epoch's governed thresholds.
        k = gp.domains[rand(grng, 1:length(gp.domains))]
        rep_k = max.(reputation[:, k], 0.0)
        if sum(rep_k) <= 0
            rep_k .= 1.0
        end
        expertise = gp.relative_expertise ? relative_reputation(rep_k) : rep_k
        w = [voting_weight(gp.base, gp.expertise_weight, [1.0], [expertise[i]], gp.impact_weight, gp.focus[i, k];
                           optional_below = gp.optional_below)[1] for i in 1:na]
        total = sum(w)
        held = copy(w)
        delegated, received = falses(na), falses(na)
        out_of_audit(j, dom) = gp.audit_window > 0 && audited_out(count(record[j, dom]), length(record[j, dom]);
                                                                  min_records = gp.audit_min_records, threshold = gp.audit_threshold)
        for i in randperm(grng, na)
            (received[i] || gp.focus[i, k] >= gp.impact_threshold || rand(grng) >= gp.p_delegate) && continue
            for j in sortperm(rep_k; rev = true)
                (j == i || delegated[j] || rep_k[j] <= rep_k[i] || out_of_audit(j, k)) && continue
                after = accumulate_capped(gp.cap * total, held[j], [w[i]])
                if after > held[j]
                    held[j] = after; held[i] -= w[i]; delegated[i] = true; received[j] = true
                    break
                end
            end
        end

        # Form the perturbation candidate through M4 (`perturb`).
        cand_pv = if candidate_pv !== nothing
            perturb(pv_inc, candidate_pv, COUPLED_GOV_FIELDS; δ = max(econ.gov_δ, maximum(abs.(candidate_pv .- pv_inc))))
        else
            c = copy(pv_cur)
            for f in COUPLED_GOV_FIELDS
                c[f] += econ.gov_δ * (2 * rand(grng) - 1)
            end
            perturb(pv_cur, c, COUPLED_GOV_FIELDS; δ = econ.gov_δ)
        end
        cand_th = candidate_threshold === nothing ? th_inc : Float64(candidate_threshold)
        cand_tw = candidate_track_window === nothing ? tw_inc : Int(candidate_track_window)

        # Voters receive noisy signals; once coupled outcome evidence shows the candidate failed, voters' signals reflect that record.
        caps = ability_caps(arng, max.(gp.skills, 0.0); base = gp.signal_σ, gain = gp.skill_gain, spread = gp.ability_spread)
        has_offer = candidate_pv !== nothing || candidate_threshold !== nothing || candidate_track_window !== nothing
        prior_signal = if coupled && rejected
            -2.0
        elseif has_offer
            1.0
        else
            0.0
        end
        votes = [begin
            s_i = prior_signal + gp.camp_bias[i] + choice_noise(crng, caps[i, k])
            (i in gp.colluders) ? 1.0 : (s_i >= 0 ? 1.0 : -1.0)
        end for i in 1:na]
        tally = sum((held[i] * votes[i] for i in 1:na if !delegated[i]); init = 0.0)
        chose_cand = tally > 0 && !(coupled && rejected)

        if chose_cand
            pv_cur = copy(cand_pv)
            th_cur = cand_th
            tw_cur = cand_tw
        else
            pv_cur = copy(pv_inc)
            th_cur = th_inc
            tw_cur = tw_inc
        end
        push!(adopted_candidate, chose_cand)
        push!(params_trace, copy(pv_cur))
        push!(thresholds_trace, th_cur)
        push!(track_windows_trace, tw_cur)
        pending_vote = (k = k, held = held, delegated = delegated, total = total, votes = votes, chose_cand = chose_cand)
    end

    full_tr = (floor_u = floor_u, floor_h = floor_h, median_u = median_u, median_h = median_h,
               peak_u = peak_u, worst_drop = worst_drop)
    (floor_u = floor_u, floor_h = floor_h, median_u = median_u, median_h = median_h,
     peak_u = peak_u, worst_drop = worst_drop,
     success = success_pattern(full_tr; from = 1),
     epoch_outcomes = epoch_outcomes,
     params = params_trace,
     thresholds = thresholds_trace,
     track_windows = track_windows_trace,
     adopted_candidate = adopted_candidate,
     rejected = rejected,
     rejected_epoch = rejected_epoch,
     reputation = reputation,
     records = record)
end
