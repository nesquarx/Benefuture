# Historical decisions replayed as-of and rolling-window forecasting replay (`docs/DATA.md` §16a–d, 8.87, 8.88).
# Pre-registration and frozen thresholds: `docs/REPLAY_PREREG.md`.

const Dates = Base.require(Base.PkgId(Base.UUID("ade2ca70-3891-5945-98fb-dc099432e06a"), "Dates"))
using .Dates
const TOML = Base.require(Base.PkgId(Base.UUID("fa267f1f-6049-4f14-aa54-33bafae1ed76"), "TOML"))

# Default governed thresholds from ParamSpace and M3c/M5 defaults (8.87)
const _DEFAULT_FROZEN_THRESHOLDS = (
    q_floor = 0.10,
    epsilon_tie = 1e-9,
    kappa_harm = 0.5,
    q_harm = 1.5,
    fr_thConf = 0.90,
    fr_thHigh = 1.00,
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
    lt_window = 100
)

const _FROZEN_REPLAY_THRESHOLDS_REF = Ref(_DEFAULT_FROZEN_THRESHOLDS)

"Dynamically reads and caches governed thresholds from `bootstrap_params()` and M3c/M5 defaults."
function get_frozen_replay_thresholds()
    try
        bp = NamedTuple{PARAM_FIELDS}(Tuple(bootstrap_params()))
        m3c_f = M3cParams(ToyParams(n=20, steps=10, plans=2), [DomainAgent([0.5,0,0,0],[1.0,0,0,0],0.2)], [1,1,2,2], trues(4); λpos=0.05, λneg=0.02)
        m5_f = M5Params((relevance_leaf=zeros(4,4), agents=[DomainAgent([0.5,0,0,0],[1.0,0,0,0],0.2)]), 1:4)
        _FROZEN_REPLAY_THRESHOLDS_REF[] = (
            q_floor = 0.10,
            epsilon_tie = 1e-9,
            kappa_harm = bp.kappa_harm,
            q_harm = bp.q_harm,
            fr_thConf = bp.fr_thConf,
            fr_thHigh = bp.fr_thHigh,
            escape_horizon = 5,
            escape_catastrophic = 10.0,
            acc_bar_leaf = m3c_f.threshold,
            acc_bar_parent = m3c_f.coarse_threshold,
            credence_cap = m3c_f.max_credence,
            model_z = m3c_f.model_z,
            ratchet_multiple = round(Int, m3c_f.ratchet_horizon),
            h_ref = m3c_f.acc_halflife,
            r_ref = m3c_f.acc_rate_ref,
            decay_beta = m3c_f.acc_mute,
            voting_cap = m5_f.cap,
            impact_threshold = 0.50,
            min_skill_record = 20,
            lt_window = 100
        )
    catch e
        # Progressive degradation, loudly (CLAUDE.md): fall back to the canonical defaults, never silently.
        @warn "replay: governed thresholds not read from the code; using canonical defaults" exception = e maxlog = 1
    end
    return _FROZEN_REPLAY_THRESHOLDS_REF[]
end

"Frozen governed thresholds from `docs/REPLAY_PREREG.md` §2 and `bootstrap_params()`. Modifying any of these in a replay is refused."
const FROZEN_REPLAY_THRESHOLDS = _DEFAULT_FROZEN_THRESHOLDS

"""
    check_frozen_thresholds(; kw...)

Verifies that no caller overrides any pre-registered governed threshold in `FROZEN_REPLAY_THRESHOLDS`.
Throws an `ArgumentError` if any governed threshold is altered after pre-registration (`docs/DATA.md` §16d B1, B10).
"""
function check_frozen_thresholds(; kw...)
    th = get_frozen_replay_thresholds()
    for (k, v) in kw
        if hasproperty(th, k)
            frozen = getproperty(th, k)
            v == frozen || throw(ArgumentError("frozen governed threshold `$k = $frozen` cannot be modified in replay (got `$v`)"))
        else
            throw(ArgumentError("unknown threshold override `$k` in replay"))
        end
    end
    return th
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
            m_val, se_val = decayed_mean_se(scores, ages, hl_days)
            push!(f_names, f)
            push!(accs, acc)
            push!(means, m_val)
            push!(ses, se_val)
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

"A single time-indexed quantile forecast record (`docs/DATA.md` §16b, B4)."
struct QuantileForecastRecord
    forecaster::String
    domain::String
    issue_date::Date
    target_date::Date
    resolution_date::Date
    vintage_date::Date
    quantiles::Vector{Float64}
    predictions::Vector{Float64}
    outcome::Float64
end

"Time-indexed quantile forecast store that refuses look-ahead (`docs/DATA.md` §16b, §16d B3)."
struct QuantileStore
    records::Vector{QuantileForecastRecord}
end
QuantileStore() = QuantileStore(QuantileForecastRecord[])

function append_record!(store::QuantileStore, rec::QuantileForecastRecord)
    push!(store.records, rec)
    return store
end

function append_record!(store::QuantileStore, forecaster::String, domain::String,
                        issue_date::Date, target_date::Date, resolution_date::Date, vintage_date::Date,
                        quantiles::AbstractVector{<:Real}, predictions::AbstractVector{<:Real}, outcome::Real)
    rec = QuantileForecastRecord(forecaster, domain, issue_date, target_date, resolution_date, vintage_date,
                                 Float64.(quantiles), Float64.(predictions), Float64(outcome))
    push!(store.records, rec)
    return store
end

function records_as_of(store::QuantileStore, as_of::Date; domain = nothing, forecaster = nothing)
    out = QuantileForecastRecord[]
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
    replay_quantile_forecasts(store::QuantileStore, domain::String, eval_dates::AbstractVector{Date};
                              scale = 10.0, beta = FROZEN_REPLAY_THRESHOLDS.decay_beta)

Walks `store` forward across `eval_dates` for `domain` evaluating continuous/quantile forecasts
(e.g., FluSight, COVID Hub, economic surveys) using Lean reference `quantile_score_ref`
and `pinball_loss_ref` (`docs/DATA.md` §16b, §16d B5).
"""
function replay_quantile_forecasts(store::QuantileStore, domain::String, eval_dates::AbstractVector{Date};
                                   scale::Real = 10.0, beta::Real = FROZEN_REPLAY_THRESHOLDS.decay_beta)
    th = get_frozen_replay_thresholds()
    all_forecasters = unique([r.forecaster for r in store.records if r.domain == domain])
    active_model = isempty(all_forecasters) ? "" : first(all_forecasters)
    takeovers = 0
    degraded = Dict{String,Int}()
    snapshots = NamedTuple[]

    for (step_idx, dt) in enumerate(eval_dates)
        avail = records_as_of(store, dt; domain = domain)
        step_days = step_idx > 1 ? max(1.0, Float64(Dates.value(dt - eval_dates[step_idx - 1]))) : 7.0
        recent_n = count(r -> Dates.value(dt - r.resolution_date) <= step_days, avail)
        hl_steps = decay_halflife(max(Float64(recent_n), 0.1);
                                  ref_rate = th.r_ref, ref_halflife = th.h_ref, mute = beta)
        hl_days = hl_steps * step_days

        scores = Float64[]
        means = Float64[]
        ses = Float64[]
        f_names = String[]

        for f in all_forecasters
            recs = [r for r in avail if r.forecaster == f]
            isempty(recs) && continue
            last_res = maximum(r.resolution_date for r in recs)
            if Dates.value(dt - last_res) > 2 * step_days
                degraded["missing quantile submission ($f)"] = get(degraded, "missing quantile submission ($f)", 0) + 1
            end
            ages = [max(0.0, Float64(Dates.value(dt - r.resolution_date))) for r in recs]
            
            # Per-record pinball losses
            rec_losses = [mean([pinball_loss(r.quantiles[i], r.predictions[i], r.outcome) for i in eachindex(r.quantiles)]) for r in recs]
            m_loss, se_loss = decayed_mean_se(rec_losses, ages, hl_days)
            # Higher score is better: negative loss converted to [0, 1] quantile score
            all_qs = vcat([r.quantiles for r in recs]...)
            all_preds = vcat([r.predictions for r in recs]...)
            all_outs = vcat([fill(r.outcome, length(r.quantiles)) for r in recs]...)
            sc = quantile_score(all_qs, all_preds, all_outs, scale)

            push!(f_names, f)
            push!(scores, sc)
            # select_candidate picks best by negative loss / score
            push!(means, -m_loss)
            push!(ses, se_loss)
        end

        if !isempty(f_names)
            inc_idx = findfirst(==(active_model), f_names)
            if inc_idx === nothing
                inc_idx = 1
                active_model = f_names[1]
            elseif inc_idx != 1
                perm = [inc_idx; [i for i in eachindex(f_names) if i != inc_idx]]
                f_names = f_names[perm]
                scores = scores[perm]
                means = means[perm]
                ses = ses[perm]
            end
            chosen_idx = select_candidate(means, ses; z = th.model_z)
            if chosen_idx != 1
                active_model = f_names[chosen_idx]
                takeovers += 1
            end
        end

        push!(snapshots, (
            date = dt,
            active_model = active_model,
            takeovers = takeovers,
            n_records = length(avail)
        ))
    end
    return (snapshots = snapshots, takeovers = takeovers, degraded = degraded)
end

"Single historical observation/forecast record (`docs/DATA.md` §16b, §16d B3)."
struct HistoricalCaseRecord
    source_id::String
    record_id::String
    issue_date::Date
    resolution_date::Date
    as_of_date::Date
    predicted::Float64
    outcome::Float64
    citation::String
end

"""
    load_case_events(path, as_of) -> Dict(event => (occurrences, trials))

As-of event counts for scenario pricing (8.87): rows `event,trial_id,date,occurred,citation_with_page`;
only trials dated on or before `as_of` count.
"""
function load_case_events(path::AbstractString, as_of::Date)
    counts = Dict{String,Tuple{Int,Int}}()
    lines = readlines(path)
    for l in lines[2:end]
        isempty(strip(l)) && continue
        f = split(l, ',')
        Date(f[3]) <= as_of || continue
        k, n = get(counts, String(f[1]), (0, 0))
        counts[String(f[1])] = (k + (parse(Float64, f[4]) > 0 ? 1 : 0), n + 1)
    end
    counts
end

function load_case_records(csv_path::AbstractString)
    isfile(csv_path) || return HistoricalCaseRecord[]
    recs = HistoricalCaseRecord[]
    lines = readlines(csv_path)
    isempty(lines) && return recs
    for line in lines[2:end]
        s = strip(line)
        isempty(s) && continue
        parts = split(s, ",")
        length(parts) >= 8 || continue
        src_id = String(strip(parts[1]))
        rec_id = String(strip(parts[2]))
        iss_d = Date(strip(parts[3]))
        res_d = Date(strip(parts[4]))
        as_of_d = Date(strip(parts[5]))
        pred = parse(Float64, strip(parts[6]))
        outc = parse(Float64, strip(parts[7]))
        cit = String(strip(join(parts[8:end], ","), ['"', ' ']))
        push!(recs, HistoricalCaseRecord(src_id, rec_id, iss_d, res_d, as_of_d, pred, outc, cit))
    end
    return recs
end

"Load a historical replay case from a `.toml` file with companion as-of records (`docs/DATA.md` §16d B2, B3)."
function load_replay_case(path::AbstractString)
    d = TOML.parsefile(path)
    d["_file_path"] = String(path)
    rec_path = replace(path, r"\.toml$" => ".records.csv")
    if isfile(rec_path)
        d["_records"] = load_case_records(rec_path)
    end
    ev_path = replace(path, r"\.toml$" => ".events.csv")
    isfile(ev_path) && (d["_events_path"] = String(ev_path))
    return d
end

"""
    replay_decision(case_dict::AbstractDict; thresholds...)

Executes Benefuture's decision replay (`docs/DATA.md` §16a, §16d B6, B7, B9) on `case_dict`:
1. Verifies frozen thresholds (`check_frozen_thresholds(; thresholds...)`).
2. Enforces provenance & hindsight guard: credences must come from replayed records as-of,
   never entered by hand (`docs/DATA.md` §16a, finding 8.87). Every source's `as_of_date`,
   every option's `known_date`, and every record's `as_of_date` must be `<= decision_date`;
   otherwise the case is marked `void = true`.
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
    case_id = String(get(case_dict, "id", ""))
    family = String(get(case_dict, "family", ""))
    degraded = Dict{String,Int}()

    # 1. As-of record provenance & calculation (8.87: credences come from replayed records as-of, never entered by hand)
    records = get(case_dict, "_records", nothing)
    if records === nothing && haskey(case_dict, "records")
        records = case_dict["records"]
    elseif records === nothing && haskey(case_dict, "_file_path")
        rec_path = replace(case_dict["_file_path"], r"\.toml$" => ".records.csv")
        if isfile(rec_path)
            records = load_case_records(rec_path)
        end
    elseif records === nothing && !isempty(case_id)
        std_rec = joinpath(@__DIR__, "..", "..", "cases", "$case_id.records.csv")
        if isfile(std_rec)
            records = load_case_records(std_rec)
        end
    end

    if records === nothing || isempty(records)
        if family != "synthetic"
            throw(ArgumentError("Case $case_id has no as-of records; credences come from replayed records as-of, never entered by hand (docs/DATA.md §16a, finding 8.87)"))
        end
    else
        # 1a. Record Hindsight Guard (Falsifier F4 / B9)
        for r in records
            r_as_of = r isa HistoricalCaseRecord ? r.as_of_date : Date(r["as_of_date"])
            r_res = r isa HistoricalCaseRecord ? r.resolution_date : Date(r["resolution_date"])
            r_id = r isa HistoricalCaseRecord ? r.record_id : r["record_id"]
            if r_as_of > dec_date || r_res > dec_date
                degraded["case unsupported: hindsight leak in record $r_id"] = 1
                return (
                    id = case_id,
                    title = String(get(case_dict, "title", case_id)),
                    tier = tier,
                    void = true,
                    void_reason = "hindsight leak in record $r_id: as_of_date $r_as_of or resolution_date $r_res > decision_date $dec_date",
                    chosen_option = "",
                    actual_choice = case_dict["actual_choice"],
                    agrees = false,
                    outcome_class = Symbol(get(case_dict, "actual_outcome_class", "bad")),
                    cell = (:void, :void),
                    floor_u_diff_mean = 0.0,
                    floor_u_diff_spread = (0.0, 0.0),
                    floor_h_diff_mean = 0.0,
                    floor_h_diff_spread = (0.0, 0.0),
                    irreparable_diff_mean = 0.0,
                    falsifiers = (F1 = false, F2 = false, F3 = false, F4 = true),
                    degraded = degraded
                )
            end
        end

        # 1b. Replay source credences from available records as-of dec_date
        sources = get(case_dict, "sources", [])
        src_map = Dict{String,Float64}()
        for src in sources
            s_id = src["id"]
            s_recs = [r for r in records if (r isa HistoricalCaseRecord ? r.source_id : r["source_id"]) == s_id && (r isa HistoricalCaseRecord ? r.as_of_date : Date(r["as_of_date"])) <= dec_date]
            if isempty(s_recs)
                throw(ArgumentError("Source $s_id in case $case_id has no historical records as-of $dec_date; credences come from replayed records, never entered by hand"))
            end
            n_rec = length(s_recs)
            src["credence_record_n"] = n_rec
            preds = [r isa HistoricalCaseRecord ? r.predicted : Float64(r["predicted"]) for r in s_recs]
            outs = [r isa HistoricalCaseRecord ? r.outcome : Float64(r["outcome"]) for r in s_recs]
            acc = count(preds .== outs) / n_rec
            src["credence_accuracy"] = acc
            src_map[s_id] = acc
        end

        # 1c. Replay option confidences from backing source credences
        for opt in get(case_dict, "options", [])
            if haskey(opt, "source")
                s_id = opt["source"]
                if haskey(src_map, s_id)
                    opt["pred_confidence"] = src_map[s_id]
                end
            elseif haskey(opt, "sources")
                s_ids = opt["sources"]
                matched = [src_map[sid] for sid in s_ids if haskey(src_map, sid)]
                if !isempty(matched)
                    opt["pred_confidence"] = mean(matched)
                end
            elseif length(sources) == 1
                opt["pred_confidence"] = first(values(src_map))
            elseif !isempty(src_map)
                opt["pred_confidence"] = mean(values(src_map))
            end
        end
    end

    # 1. Hindsight Guard (Falsifier F4 / B9)
    for src in get(case_dict, "sources", [])
        src_date = Date(src["as_of_date"])
        if src_date > dec_date
            degraded["case unsupported: hindsight leak in source $(src["id"])"] = 1
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
            degraded["case unsupported: hindsight leak in option $(opt["id"])"] = 1
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

    # Scenario pricing (amendment 2026-11-05, 8.87): an option's effects are expected values over the
    # scenarios known as of the decision, each scenario's probability the product of its chained events'
    # Laplace rates (`event_rate_ref`) from the as-of events file. Typed effects are hindsight-prone:
    # still computed, but the case is marked unsupported, loudly.
    events = haskey(case_dict, "_events_path") ? load_case_events(case_dict["_events_path"], dec_date) : Dict{String,Tuple{Int,Int}}()
    hindsight_typed = false
    
    for opt in options
        if haskey(opt, "scenarios")
            ps = Float64[]; dus = Vector{Float64}[]; dhs = Vector{Float64}[]; nhas = Vector{Float64}[]; irrs = Vector{Float64}[]
            for sc in opt["scenarios"]
                p_s = 1.0
                for ev in sc["p_chain"]
                    haskey(events, ev) || throw(ArgumentError("case $(case_dict["id"]): event $ev has no as-of records"))
                    k, n = events[ev]
                    p_s *= event_rate(k, n)
                end
                get(sc, "complement", false) && (p_s = max(0.0, 1.0 - sum(ps)))   # the remaining mass (the nominal outcome)
                push!(ps, p_s)
                z = zeros(n_groups)
                push!(dus, Float64.(get(sc, "du", z))); push!(dhs, Float64.(get(sc, "dh", z)))
                push!(nhas, Float64.(get(sc, "nha", z))); push!(irrs, Float64.(get(sc, "irreparable", z)))
            end
            # D5 equal-weight baseline: every known scenario weighted alike, the as-of record ignored.
            get(case_dict, "_scenario_weights", "rates") == "equal" && (ps = fill(1.0 / length(ps), length(ps)))
            opt["pred_du"] = [expected_effect(ps, getindex.(dus, g)) for g in 1:n_groups]
            opt["pred_dh"] = [expected_effect(ps, getindex.(dhs, g)) for g in 1:n_groups]
            opt["pred_nha"] = [expected_effect(ps, getindex.(nhas, g)) for g in 1:n_groups]
            opt["_scenario_irr"] = isempty(irrs) ? zeros(n_groups) : irrs[argmax([sum(x) * q for (x, q) in zip(irrs, ps)])]
            opt["_scenario_p_irr"] = isempty(ps) ? 0.0 : maximum([sum(x) > 0 ? q : 0.0 for (x, q) in zip(irrs, ps)])
            opt["pred_irreparable"] = [expected_effect(ps, getindex.(irrs, g)) for g in 1:n_groups]
        else
            hindsight_typed = true
        end
    end
    hindsight_typed && (degraded["case unsupported: option effects typed, not priced from as-of scenarios (amendment 2026-11-05)"] = 1)
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
        # Compute credence/confidence from as-of historical observation record if provided (8.87)
        conf = if haskey(opt, "record_errors") && !isempty(opt["record_errors"])
            errs = Float64.(opt["record_errors"])
            ages = haskey(opt, "record_ages") ? Float64.(opt["record_ages"]) : fill(1.0, length(errs))
            decayed_record_credence(0.0, errs, ages, th.h_ref; cap = th.credence_cap)
        elseif haskey(opt, "past_credences") && haskey(opt, "past_outcomes") && !isempty(opt["past_credences"])
            creds = Float64.(opt["past_credences"])
            outs = Float64.(opt["past_outcomes"])
            ages = haskey(opt, "past_ages") ? Float64.(opt["past_ages"]) : fill(1.0, length(creds))
            decayed_accuracy(creds, outs, ages, th.h_ref)
        else
            Float64(get(opt, "pred_confidence", 0.8))
        end
        u_after = base_u .+ du
        h_after = base_h .+ dh
        lt_u = Float64.(get(opt, "lt_end_u", u_after))
        lt_h = Float64.(get(opt, "lt_end_h", h_after))

        # Freedom gate (L135) on irreparable and passing harms
        total_irr = sum(irr)
        total_nha = sum(nha)
        # The freedom gate is per being (L135): the probability that a member of some group suffers
        # irreparable harm, expected irreparable harms over the group's population. Inaction is judged the
        # same way (author ruling on 8.47, 2026-11-06): where inaction risks irreparable harm and the
        # decider is informed (every scenario-priced option is informed: its risk comes from the as-of
        # record), allowing it counts as doing it.
        fr_ok[i] = if haskey(opt, "pred_irreparable") && all(o -> haskey(o, "scenarios"), options)
            risk = maximum(irr[g] / pops[g] for g in 1:n_groups)
            risk <= 0 || fr_permissible(1.0, 0.0, 0.0, 0.0, 0.0; confidence = min(1.0, risk))
        else
            fr_permissible(total_irr, 0.0, 0.0, total_nha, 0.0; confidence = conf)
        end

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
    replay_baselines(case_dict) -> NamedTuple of option ids

The D5 comparison rules (`docs/REPLAY_PREREG.md` §5b), on the same as-of priced options as Benefuture:
`actual` (the institution's choice), `status_quo` (the case's inaction option), `min_deaths` (fewest
expected irreparable harms, nothing else counted), `mean_welfare` (largest population-weighted mean change
of understanding plus happiness: no floors, no harm weighting, no freedom gate) and `equal_weight`
(Benefuture's own rule with every known scenario weighted alike, testing whether the as-of rates matter).
Ties go to the status quo. Only scenario-priced cases have baselines; others return `nothing`.
"""
function replay_baselines(case_dict::AbstractDict)
    opts = case_dict["options"]
    all(o -> haskey(o, "scenarios"), opts) || return nothing
    c = deepcopy(case_dict)
    replay_decision(c)                                  # prices the options from the as-of record
    o = c["options"]
    pops = [Float64(g["population"]) for g in c["groups"]]
    w = pops ./ sum(pops)
    sq = something(findfirst(x -> get(x, "is_inaction", false), o), 1)
    pick(score) = (s = [score(x) for x in o]; best = maximum(s); s[sq] >= best - 1e-12 ? sq : argmax(s))
    min_deaths = pick(x -> -sum(Float64.(x["pred_irreparable"])))
    mean_welfare = pick(x -> sum(w .* (Float64.(x["pred_du"]) .+ Float64.(x["pred_dh"]))))
    e = deepcopy(case_dict); e["_scenario_weights"] = "equal"
    (actual = String(case_dict["actual_choice"]), status_quo = String(o[sq]["id"]),
     min_deaths = String(o[min_deaths]["id"]), mean_welfare = String(o[mean_welfare]["id"]),
     equal_weight = replay_decision(e).chosen_option)
end

"""
    replay_scores(results, baselines) -> Dict(rule => (k, n, interval))

Scores each rule on the cases with a settled outcome class: on a good decision a rule is right when it
chooses what the institution chose; on a bad one, when it chooses otherwise. Unclear cases are not scored.
Intervals by `proportion_interval` (z = 2). Unpriced or void cases are left out.
"""
function replay_scores(results, baselines)
    rules = (:benefuture, :actual, :status_quo, :min_deaths, :mean_welfare, :equal_weight)
    out = Dict{Symbol,Any}()
    for rule in rules
        k = 0; n = 0
        for (r, b) in zip(results, baselines)
            (r.void || b === nothing || r.outcome_class ∉ (:good, :bad)) && continue
            choice = rule == :benefuture ? r.chosen_option : getfield(b, rule)
            right = r.outcome_class == :good ? choice == r.actual_choice : choice != r.actual_choice
            k += right; n += 1
        end
        out[rule] = (k = k, n = n, interval = n > 0 ? proportion_interval(k, n) : nothing)
    end
    out
end

"""
    evaluate_replay_suite(case_paths::AbstractVector{<:AbstractString})

Evaluates a collection of historical case `.toml` files, returning the four-cell counts and
proportion intervals (`docs/DATA.md` §16d B9) and verifying that zero falsifiers fired.
"""
function evaluate_replay_suite(case_paths::AbstractVector{<:AbstractString})
    results = [replay_decision(load_replay_case(p)) for p in case_paths]
    baselines = [replay_baselines(load_replay_case(p)) for p in case_paths]
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
        any_falsifier = any_falsifier,
        baselines = baselines,
        scores = replay_scores(results, baselines)
    )
end

