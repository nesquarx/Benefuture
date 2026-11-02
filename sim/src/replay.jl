# Historical decisions replayed as-of and rolling-window forecasting replay (`docs/DATA.md` §16a–d, 8.87, 8.88).
# Pre-registration and frozen thresholds: `docs/REPLAY_PREREG.md`.

const Dates = Base.require(Base.PkgId(Base.UUID("ade2ca70-3891-5945-98fb-dc099432e06a"), "Dates"))
using .Dates
const TOML = Base.require(Base.PkgId(Base.UUID("fa267f1f-6049-4f14-aa54-33bafae1ed76"), "TOML"))

"Frozen governed thresholds from `docs/REPLAY_PREREG.md` §2. Modifying any of these in a replay is refused."
const FROZEN_REPLAY_THRESHOLDS = (
    q_floor = 0.10,
    epsilon_tie = 1e-9,
    kappa_harm = 0.5,
    q_harm = 1.5,
    fr_thConf = 0.90,
    fr_thHigh = 0.70,
    escape_horizon = 5,
    escape_catastrophic = 10.0,
    acc_bar_leaf = 0.90,
    acc_bar_parent = 0.75,
    credence_cap = 0.99,
    model_z = 2.0,
    ratchet_multiple = 20,
    h_ref = 7.0,
    r_ref = 5.0,
    decay_beta = 0.5,
    voting_cap = 0.05,
    impact_threshold = 0.50,
    min_skill_record = 20,
    lt_window = 50
)

"""
    check_frozen_thresholds(; kw...)

Verifies that no caller overrides any pre-registered governed threshold in `FROZEN_REPLAY_THRESHOLDS`.
Throws an `ArgumentError` if any governed threshold is altered after pre-registration (`docs/DATA.md` §16d B1, B10).
"""
function check_frozen_thresholds(; kw...)
    for (k, v) in kw
        if hasproperty(FROZEN_REPLAY_THRESHOLDS, k)
            frozen = getproperty(FROZEN_REPLAY_THRESHOLDS, k)
            v == frozen || throw(ArgumentError("frozen governed threshold `$k = $frozen` cannot be modified in replay (got `$v`)"))
        else
            throw(ArgumentError("unknown threshold override `$k` in replay"))
        end
    end
    return FROZEN_REPLAY_THRESHOLDS
end

"A single time-indexed forecast record in the as-of record store (`docs/DATA.md` §16d B3)."
struct AsOfRecord
    forecaster::String
    domain::String
    issue_date::Date
    target_date::Date
    resolution_date::Date
    vintage_date::Date
    predicted::Float64
    outcome::Float64
    credence::Float64
end

"Time-indexed forecast store that refuses look-ahead (`docs/DATA.md` §16d B3)."
struct AsOfStore
    records::Vector{AsOfRecord}
end
AsOfStore() = AsOfStore(AsOfRecord[])

"""
    append_record!(store::AsOfStore, record::AsOfRecord)
    append_record!(store::AsOfStore, forecaster, domain, issue_date, target_date, resolution_date, vintage_date, predicted, outcome, credence)

Appends a forecast record to `store` (append-only invariant).
"""
function append_record!(store::AsOfStore, record::AsOfRecord)
    push!(store.records, record)
    return store
end

function append_record!(store::AsOfStore, forecaster::String, domain::String,
                        issue_date::Date, target_date::Date, resolution_date::Date, vintage_date::Date,
                        predicted::Real, outcome::Real, credence::Real)
    rec = AsOfRecord(forecaster, domain, issue_date, target_date, resolution_date, vintage_date,
                     Float64(predicted), Float64(outcome), Float64(credence))
    push!(store.records, rec)
    return store
end

"""
    records_as_of(store::AsOfStore, as_of::Date; domain = nothing, forecaster = nothing)

Returns all records in `store` whose `issue_date`, `resolution_date`, and `vintage_date` are all
at or before `as_of`. No future resolutions or post-`as_of` data vintages can leak into the query.
"""
function records_as_of(store::AsOfStore, as_of::Date;
                       domain::Union{Nothing,String} = nothing,
                       forecaster::Union{Nothing,String} = nothing)
    out = AsOfRecord[]
    for r in store.records
        r.issue_date <= as_of || continue
        r.resolution_date <= as_of || continue
        r.vintage_date <= as_of || continue
        (domain === nothing || r.domain == domain) || continue
        (forecaster === nothing || r.forecaster == forecaster) || continue
        push!(out, r)
    end
    return out
end

"""
    diebold_mariano(losses_a, losses_b; lag = 1, z = 2.0)

Diebold & Mariano (1995) / Giacomini & White (2006) autocorrelation-robust paired test on loss
differentials `d_t = losses_a[t] - losses_b[t]` with Newey–West Bartlett kernel of bandwidth `lag`.
Negative `mean` indicates `a` has lower loss than `b`.
"""
function diebold_mariano(losses_a::AbstractVector{<:Real}, losses_b::AbstractVector{<:Real};
                         lag::Int = 1, z::Real = 2.0)
    n = length(losses_a)
    check(n == length(losses_b) && n >= 3, "loss series must have equal length >= 3")
    d = Float64.(losses_a) .- Float64.(losses_b)
    m = mean(d)
    u = d .- m
    γ0 = sum(u .^ 2) / n
    lvar = γ0
    for k in 1:min(lag, n - 1)
        w = 1.0 - k / (lag + 1.0)
        γk = sum(u[(k + 1):n] .* u[1:(n - k)]) / n
        lvar += 2.0 * w * γk
    end
    se = sqrt(max(lvar, 1e-18) / n)
    t_z = t_Factor(n - 1, z)
    return (
        mean = m,
        se = se,
        z_stat = m / se,
        low = m - t_z * se,
        high = m + t_z * se,
        sig = abs(m) > t_z * se,
        n = n
    )
end

"""
    replay_forecasts(store::AsOfStore, domain::String, eval_dates::AbstractVector{Date};
                     beta = FROZEN_REPLAY_THRESHOLDS.decay_beta)

Walks `store` forward across `eval_dates` for `domain` using Benefuture's measurement rules
(`decay_halflife`, `decayed_accuracy`, `decayed_mean_se`, `select_candidate`, `ratchet_bar`)
without look-ahead or survivorship bias (`docs/DATA.md` §16b, §16d B5).
"""
function replay_forecasts(store::AsOfStore, domain::String, eval_dates::AbstractVector{Date};
                          beta::Real = FROZEN_REPLAY_THRESHOLDS.decay_beta)
    th = FROZEN_REPLAY_THRESHOLDS
    all_forecasters = unique([r.forecaster for r in store.records if r.domain == domain])
    active_model = isempty(all_forecasters) ? "" : first(all_forecasters)
    bar = th.acc_bar_leaf
    takeovers = 0
    degraded = Dict{String,Int}()
    snapshots = NamedTuple[]

    for (step_idx, dt) in enumerate(eval_dates)
        avail = records_as_of(store, dt; domain = domain)
        # Estimate transaction rate (records per step window)
        step_days = step_idx > 1 ? max(1.0, Float64(Dates.value(dt - eval_dates[step_idx - 1]))) : 7.0
        recent_n = count(r -> Dates.value(dt - r.resolution_date) <= step_days, avail)
        hl_steps = decay_halflife(max(Float64(recent_n), 0.1);
                                  ref_rate = th.r_ref, ref_halflife = th.h_ref, mute = beta)
        hl_days = hl_steps * step_days

        accs = Float64[]
        means = Float64[]
        ses = Float64[]
        f_names = String[]
        for f in all_forecasters
            recs = [r for r in avail if r.forecaster == f]
            isempty(recs) && continue
            # Check if forecaster stopped submitting despite having entered earlier
            last_res = maximum(r.resolution_date for r in recs)
            if Dates.value(dt - last_res) > 2 * step_days
                degraded["missing forecast submission ($f)"] = get(degraded, "missing forecast submission ($f)", 0) + 1
            end
            ages = [max(0.0, Float64(Dates.value(dt - r.resolution_date))) for r in recs]
            creds = [r.credence for r in recs]
            outs = [r.outcome >= 0.0 ? 1.0 : 0.0 for r in recs]
            scores = [credence_score(creds[i], outs[i]) for i in eachindex(recs)]
            acc = decayed_accuracy(creds, outs, ages, hl_days)
            ms = decayed_mean_se(scores, ages, hl_days)
            push!(f_names, f)
            push!(accs, acc)
            push!(means, ms.mean)
            push!(ses, ms.se)
        end

        if !isempty(f_names)
            # Order with active_model first (incumbent index 1) for select_candidate
            inc_idx = findfirst(==(active_model), f_names)
            if inc_idx === nothing
                inc_idx = 1
                active_model = f_names[1]
            elseif inc_idx != 1
                perm = [inc_idx; [i for i in eachindex(f_names) if i != inc_idx]]
                f_names = f_names[perm]
                accs = accs[perm]
                means = means[perm]
                ses = ses[perm]
            end
            chosen_idx = select_candidate(means, ses; z = th.model_z)
            if chosen_idx != 1
                active_model = f_names[chosen_idx]
                takeovers += 1
            end
            bar = ratchet_bar(accs, bar; k = 2, margin = 0.02)
        end

        push!(snapshots, (
            date = dt,
            active_model = active_model,
            bar = bar,
            takeovers = takeovers,
            n_records = length(avail)
        ))
    end
    return (snapshots = snapshots, takeovers = takeovers, bar = bar, degraded = degraded)
end

"Load a historical replay case from a `.toml` file (`docs/DATA.md` §16d B2)."
load_replay_case(path::AbstractString) = TOML.parsefile(path)

"""
    replay_decision(case_dict::AbstractDict; thresholds...)

Executes Benefuture's decision replay (`docs/DATA.md` §16a, §16d B6, B7, B9) on `case_dict`:
1. Verifies frozen thresholds (`check_frozen_thresholds(; thresholds...)`).
2. Enforces the hindsight guard: every source's `as_of_date` and every option's `known_date` must be
   `<= decision_date`; otherwise the case is marked `void = true`.
3. Evaluates every option across affected groups using the Lean reference rules (`value_on_being`,
   `harm_weight`, `floor_quantile`, `g_choose`, `fr_permissible`), checking the strong per-group
   long-term trajectory constraint over `lt` (8.86) and logging any coarse-tier or weak-reading
   fallback in `degraded`.
4. Compares Benefuture's choice with `actual_choice`, classifies the case into the four-cell matrix,
   evaluates competing counterfactual estimates, and checks Falsifiers F1–F4.
"""
function replay_decision(case_dict::AbstractDict; thresholds...)
    th = check_frozen_thresholds(; thresholds...)
    dec_date = Date(case_dict["decision_date"])
    tier = get(case_dict, "tier", "full")
    degraded = Dict{String,Int}()

    # 1. Hindsight Guard (Falsifier F4 / B9)
    for src in get(case_dict, "sources", [])
        src_date = Date(src["as_of_date"])
        if src_date > dec_date
            return (
                id = case_dict["id"],
                void = true,
                void_reason = "hindsight leak in source $(src["id"]): as_of_date $src_date > decision_date $dec_date",
                chosen_option = "",
                actual_choice = case_dict["actual_choice"],
                agrees = false,
                cell = (:void, :void),
                degraded = degraded
            )
        end
    end

    options = case_dict["options"]
    for opt in options
        k_date = Date(opt["known_date"])
        if k_date > dec_date
            return (
                id = case_dict["id"],
                void = true,
                void_reason = "hindsight leak in option $(opt["id"]): known_date $k_date > decision_date $dec_date",
                chosen_option = "",
                actual_choice = case_dict["actual_choice"],
                agrees = false,
                cell = (:void, :void),
                degraded = degraded
            )
        end
    end

    if tier == "coarse"
        degraded["coarse low-technology tier (parent markers & rule fallback, 8.88)"] = 1
    end

    groups = case_dict["groups"]
    n_groups = length(groups)
    base_u = [Float64(g["baseline_u"]) for g in groups]
    base_h = [Float64(g["baseline_h"]) for g in groups]
    pops = [Float64(g["population"]) for g in groups]

    # Find inaction baseline option (or first option with is_inaction = true)
    idle_idx = findfirst(o -> get(o, "is_inaction", false), options)
    idle_idx === nothing && (idle_idx = 1)
    idle_opt = options[idle_idx]

    idle_u = base_u .+ Float64.(idle_opt["pred_du"])
    idle_h = base_h .+ Float64.(idle_opt["pred_dh"])
    idle_lt_u = Float64.(get(idle_opt, "lt_end_u", idle_u))
    idle_lt_h = Float64.(get(idle_opt, "lt_end_h", idle_h))
    idle_min_u = floor_quantile(idle_u, th.q_floor)
    idle_min_h = floor_quantile(idle_h, th.q_floor)
    idle_max_u = maximum(idle_u)

    n_opts = length(options)
    opt_values = zeros(n_opts)
    d_scope = zeros(n_opts)
    d_min_u = zeros(n_opts)
    d_min_h = zeros(n_opts)
    d_max_u = zeros(n_opts)
    strong_ok = falses(n_opts)
    fr_ok = falses(n_opts)

    bp = NamedTuple{PARAM_FIELDS}(Tuple(bootstrap_params()))
    for (i, opt) in enumerate(options)
        du = Float64.(opt["pred_du"])
        dh = Float64.(opt["pred_dh"])
        nha = Float64.(opt["pred_nha"])
        irr = Float64.(opt["pred_irreparable"])
        conf = Float64(get(opt, "pred_confidence", 0.8))
        u_after = base_u .+ du
        h_after = base_h .+ dh
        lt_u = Float64.(get(opt, "lt_end_u", u_after))
        lt_h = Float64.(get(opt, "lt_end_h", h_after))

        # Freedom gate (L135) on irreparable and passing harms
        total_irr = sum(irr)
        total_nha = sum(nha)
        fr_ok[i] = fr_permissible(total_irr, 0.0, 0.0, total_nha, 0.0; confidence = conf)

        # Value per group weighted by group population share
        v_tot = 0.0
        for g in 1:n_groups
            tiers = Tuple{Float64,Float64}[]
            irr[g] > 0 && push!(tiers, (irr[g], HARM_SCHEDULE[1]))
            nha[g] > 0 && push!(tiers, (nha[g], HARM_SCHEDULE[4]))
            hw = isempty(tiers) ? 1.0 : harm_weight(tiers; λ = bp.lambda)
            vg = value_on_being(du[g] - Float64(idle_opt["pred_du"][g]),
                                dh[g] - Float64(idle_opt["pred_dh"][g]),
                                0.0;
                                harm_wt = hw,
                                α = bp.alpha, β = bp.beta, γ = bp.gamma,
                                λ = bp.lambda, qp = bp.q_plus, qm = bp.q_minus)
            v_tot += (pops[g] / sum(pops)) * vg
        end
        # Irreparable harm when Fr is violated penalises the option heavily
        if !fr_ok[i] && total_irr > 0
            v_tot -= 1000.0 * total_irr * conf
        end
        opt_values[i] = v_tot

        d_scope[i] = Float64(opt["scope_delta"]) - Float64(idle_opt["scope_delta"]) + th.epsilon_tie
        d_min_u[i] = floor_quantile(u_after, th.q_floor) - idle_min_u + th.epsilon_tie
        d_min_h[i] = floor_quantile(h_after, th.q_floor) - idle_min_h + th.epsilon_tie
        d_max_u[i] = maximum(u_after) - idle_max_u + th.epsilon_tie

        # Strong per-group long-term trajectory check (8.86) and no unexcused irreparable harm
        strong_ok[i] = all(lt_u .+ th.epsilon_tie .>= idle_lt_u) &&
                       all(lt_h .+ th.epsilon_tie .>= idle_lt_h) &&
                       total_irr == 0.0
    end

    # Filter by strong reading first; fall back to weak reading with loud degradation if none qualifies
    d_scope_strong = [strong_ok[i] ? d_scope[i] : -1.0 for i in 1:n_opts]
    chosen_idx = g_choose(opt_values, d_scope_strong, d_min_u, d_min_h, d_max_u)
    if chosen_idx === nothing
        degraded["accession/group strong trajectory reading → weak floor reading (8.86)"] = 1
        chosen_idx = g_choose(opt_values, d_scope, d_min_u, d_min_h, d_max_u)
    end
    chosen_idx === nothing && (chosen_idx = idle_idx)

    chosen_opt = options[chosen_idx]
    chosen_id = String(chosen_opt["id"])
    actual_id = String(case_dict["actual_choice"])
    agrees = chosen_id == actual_id
    outcome_sym = Symbol(case_dict["actual_outcome_class"])
    agree_sym = agrees ? :agrees : :differs

    # Counterfactual difference along the vector success pattern
    cf = case_dict["counterfactual"]
    fu_diffs = Float64.(cf["est_floor_u_delta_diff"])
    fh_diffs = Float64.(cf["est_floor_h_delta_diff"])
    irr_diffs = Float64.(cf["est_irreparable_diff"])

    chosen_irr = sum(Float64.(chosen_opt["pred_irreparable"]))
    f1_violated = chosen_irr > 0.0 && any(sum(Float64.(o["pred_irreparable"])) == 0.0 for o in options)
    f2_violated = (outcome_sym == :good && !agrees && mean(fu_diffs) < 0.0)
    f3_violated = (tier == "coarse" && outcome_sym == :good && !agrees)

    return (
        id = String(case_dict["id"]),
        title = String(case_dict["title"]),
        tier = tier,
        void = false,
        void_reason = "",
        chosen_option = chosen_id,
        actual_choice = actual_id,
        agrees = agrees,
        outcome_class = outcome_sym,
        cell = (outcome_sym, agree_sym),
        floor_u_diff_mean = agrees ? 0.0 : mean(fu_diffs),
        floor_u_diff_spread = agrees ? (0.0, 0.0) : (minimum(fu_diffs), maximum(fu_diffs)),
        floor_h_diff_mean = agrees ? 0.0 : mean(fh_diffs),
        floor_h_diff_spread = agrees ? (0.0, 0.0) : (minimum(fh_diffs), maximum(fh_diffs)),
        irreparable_diff_mean = agrees ? 0.0 : mean(irr_diffs),
        falsifiers = (F1 = f1_violated, F2 = f2_violated, F3 = f3_violated, F4 = false),
        degraded = degraded
    )
end

"""
    evaluate_replay_suite(case_paths::AbstractVector{<:AbstractString})

Evaluates a collection of historical case `.toml` files, returning the four-cell counts and
proportion intervals (`docs/DATA.md` §16d B9) and verifying that zero falsifiers fired.
"""
function evaluate_replay_suite(case_paths::AbstractVector{<:AbstractString})
    results = [replay_decision(load_replay_case(p)) for p in case_paths]
    valid = [r for r in results if !r.void]
    n = length(valid)
    cells = Dict(
        (:good, :agrees) => count(r -> r.cell == (:good, :agrees), valid),
        (:good, :differs) => count(r -> r.cell == (:good, :differs), valid),
        (:bad, :agrees) => count(r -> r.cell == (:bad, :agrees), valid),
        (:bad, :differs) => count(r -> r.cell == (:bad, :differs), valid)
    )
    any_falsifier = any(r -> r.falsifiers.F1 || r.falsifiers.F2 || r.falsifiers.F3 || r.falsifiers.F4, valid)
    return (
        results = results,
        n_valid = n,
        n_void = count(r -> r.void, results),
        cells = cells,
        any_falsifier = any_falsifier
    )
end

