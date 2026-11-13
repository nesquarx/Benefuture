# Empirical dataset adapters and out-of-sample validations (Task E2; docs/DATA.md Prioritised plan #1-3):
#   1. Model pools: COVID-19 Forecast Hub (`QuantileStore`) + M4 relative-error cross-check.
#   2. Domain reputation: Stack Exchange answers + cross-site profiles (+ Tags.xml parser).
#   3. Audit and repair: English Wikipedia mainspace edit/revert latency + Geiger-Halfaker bot outage.
#
# All parameters are derived directly from data tables or `QuantileStore` records rather than
# hardcoded toy constants; invalid, empty, or malformed inputs raise `ArgumentError` via `check`.

const CALIBRATION_SAMPLE_DIR = joinpath(@__DIR__, "..", "..", "cases", "calibration_sample")

function _split_delim_line(line::AbstractString, delim::Char)
    fields = String[]
    buf = IOBuffer()
    in_quotes = false
    i = firstindex(line)
    last = lastindex(line)
    while i <= last
        c = line[i]
        if c == '"'
            if in_quotes
                nxt = nextind(line, i)
                if nxt <= last && line[nxt] == '"'
                    write(buf, '"')
                    i = nextind(line, nxt)
                    continue
                else
                    in_quotes = false
                end
            else
                in_quotes = true
            end
        elseif c == delim && !in_quotes
            push!(fields, String(take!(buf)))
        else
            write(buf, c)
        end
        i = nextind(line, i)
    end
    push!(fields, String(take!(buf)))
    fields
end

function _read_table_rows(path::AbstractString; delim::Char = ',')
    check(isfile(path), "dataset file does not exist: $path")
    lines = filter(l -> !isempty(strip(l)), readlines(path))
    check(length(lines) >= 2, "dataset file must have header and at least one data row: $path")
    header = strip.(_split_delim_line(lines[1], delim))
    check(!isempty(header) && all(!isempty, header), "invalid header in dataset file: $path")
    rows = Dict{String,String}[]
    for l in lines[2:end]
        vals = _split_delim_line(l, delim)
        check(length(vals) == length(header), "row width mismatch in $path")
        push!(rows, Dict{String,String}(zip(header, vals)))
    end
    rows
end

function _quantile_linear(xs::AbstractVector{<:Real}, q::Real)
    check(!isempty(xs) && all(isfinite, xs) && 0 <= q <= 1, "non-empty finite vector and q in [0, 1]")
    s = sort(Float64.(xs))
    length(s) == 1 && return s[1]
    pos = 1 + q * (length(s) - 1)
    lo = floor(Int, pos)
    hi = ceil(Int, pos)
    w = pos - lo
    (1 - w) * s[lo] + w * s[hi]
end

function _parse_opt_float(s::AbstractString)
    st = strip(s)
    isempty(st) || lowercase(st) in ("na", "nan", "null", "none") ? nothing : parse(Float64, st)
end

function _parse_bool_flag(s::AbstractString)
    st = lowercase(strip(s))
    st in ("1", "true", "t", "yes") && return true
    st in ("0", "false", "f", "no", "") && return false
    check(false, "unrecognized boolean flag: $s")
end

function _extract_site_host(url_or_name::AbstractString)
    s = strip(url_or_name)
    s = replace(s, r"^https?://" => "")
    s = first(split(s, '/'))
    isempty(s) ? "" : lowercase(first(split(s, '.')))
end

_mean_pinball(rec::QuantileForecastRecord) =
    mean(pinball_loss(q, p, rec.outcome) for (q, p) in zip(rec.quantiles, rec.predictions))

function _point_prediction(rec::QuantileForecastRecord)
    _, idx = findmin(abs.(rec.quantiles .- 0.5))
    rec.predictions[idx]
end

# ---------------------------------------------------------------------------
# Priority 1: Model pools (COVID-19 Forecast Hub & M4 relative-error check)
# ---------------------------------------------------------------------------

function _detect_ensemble_name(forecasters::Vector{String}, ensemble_name)
    ensemble_name !== nothing && return String(ensemble_name)
    matches = filter(f -> occursin("ensemble", lowercase(f)), forecasters)
    isempty(matches) ? nothing : first(sort(matches))
end

"""
    calibrate_model_pool(store::QuantileStore; domain = nothing, ensemble_name = nothing, scale = nothing)

Derive empirical model-pool dynamics (`p_new_model`, `improve_drift`, `improve_σ`, `scale_min`,
normalized leaf error spread, and cumulative settling `n_learn`) from resolved `QuantileStore`
records (`docs/DATA.md` Prioritised plan #1, `docs/CALIBRATION.md` §3.3 & §5).
"""
function calibrate_model_pool(store::QuantileStore; domain = nothing, ensemble_name = nothing, scale = nothing)
    recs = [r for r in store.records if r.outcome !== nothing && (domain === nothing || r.domain == domain)]
    check(!isempty(recs), "no resolved QuantileForecastRecord entries matched")

    dates = sort(unique([r.target_date for r in recs]))
    check(length(dates) >= 2, "at least two resolved target dates are required")

    all_forecasters = sort(unique([r.forecaster for r in recs]))
    ens = _detect_ensemble_name(all_forecasters, ensemble_name)
    teams = filter(f -> ens === nothing || f != ens, all_forecasters)
    check(!isempty(teams), "at least one non-ensemble forecasting team is required")

    y_by_date = Dict(d => Float64(first(r.outcome for r in recs if r.target_date == d)) for d in dates)
    ys = [y_by_date[d] for d in dates]
    outcome_std = std(ys)
    outcome_iqr = _quantile_linear(ys, 0.75) - _quantile_linear(ys, 0.25)
    scale_used = scale === nothing ? max(outcome_std, outcome_iqr, 1e-9) : Float64(scale)
    check(isfinite(scale_used) && scale_used > 0, "positive finite scale required")

    # Group mean pinball & normalized point error by (team, target_date)
    by_td = Dict{Tuple{String,Date},Float64}()
    team_pinballs = Float64[]
    point_errs_norm = Float64[]
    first_date = Dict{String,Date}()
    for r in recs
        r.forecaster in teams || continue
        pl = _mean_pinball(r)
        by_td[(r.forecaster, r.target_date)] = pl
        push!(team_pinballs, pl)
        push!(point_errs_norm, (_point_prediction(r) - r.outcome) / scale_used)
        fd = get(first_date, r.forecaster, r.target_date)
        first_date[r.forecaster] = min(fd, r.target_date)
    end

    ens_by_date = Dict{Date,Float64}()
    if ens !== nothing
        for r in recs
            r.forecaster == ens || continue
            ens_by_date[r.target_date] = _mean_pinball(r)
        end
    end

    # Contemporaneous reference loss per date (ensemble when present, else pool median).
    ref_by_date = Dict{Date,Float64}()
    for d in dates
        if haskey(ens_by_date, d)
            ref_by_date[d] = ens_by_date[d]
        else
            day_vals = [by_td[(t, d)] for t in teams if haskey(by_td, (t, d))]
            ref_by_date[d] = isempty(day_vals) ? NaN : _quantile_linear(day_vals, 0.5)
        end
    end

    ratios_vs_ref = Float64[]
    team_series = Dict{String,Vector{Float64}}(t => Float64[] for t in teams)
    for d in dates, t in teams
        haskey(by_td, (t, d)) && isfinite(get(ref_by_date, d, NaN)) || continue
        ratio = by_td[(t, d)] / max(ref_by_date[d], 1e-9)
        push!(ratios_vs_ref, ratio)
        push!(team_series[t], ratio)
    end
    check(!isempty(ratios_vs_ref), "no matched team-to-reference pairs found")

    # Sequential challenger vs prior best team across dates t >= 2
    challenger_ratios = Float64[]
    for idx in 2:length(dates)
        prev_dates = dates[1:(idx - 1)]
        cur_d = dates[idx]
        cum_scores = [(t, mean([by_td[(t, pd)] for pd in prev_dates if haskey(by_td, (t, pd))]))
                      for t in teams if any(pd -> haskey(by_td, (t, pd)), prev_dates)]
        isempty(cum_scores) && continue
        incumbent = first(sort(cum_scores; by = last))[1]
        haskey(by_td, (incumbent, cur_d)) || continue
        inc_loss = max(by_td[(incumbent, cur_d)], 1e-9)
        for t in teams
            t == incumbent || !haskey(by_td, (t, cur_d)) && continue
            push!(challenger_ratios, by_td[(t, cur_d)] / inc_loss)
        end
    end

    n_arrivals = count(t -> first_date[t] > dates[1], teams)
    p_new_model = clamp(n_arrivals / max(1, length(dates) - 1), 0.0, 1.0)
    log_ref = log.(max.(ratios_vs_ref, 1e-6))
    log_chal = isempty(challenger_ratios) ? log_ref : log.(max.(challenger_ratios, 1e-6))

    settle_steps = Float64[]
    for t in teams
        s = team_series[t]
        length(s) >= 4 && push!(settle_steps, Float64(settling_step(s; tol = 0.15, atol = 0.05 * mean(s))))
    end
    n_learn_est = isempty(settle_steps) ? Float64(length(dates)) : _quantile_linear(settle_steps, 0.5)

    (n_records = length(recs), n_targets = length(dates), n_teams = length(teams), n_arrivals = n_arrivals,
     ensemble = ens, scale = scale_used, outcome_std = outcome_std, outcome_iqr = outcome_iqr,
     p_new_model = p_new_model,
     arrival_rate_per_team_step = n_arrivals / max(1, length(teams) * (length(dates) - 1)),
     improve_drift = mean(log_ref), improve_σ = length(log_ref) >= 2 ? std(log_ref) : 0.0,
     challenger_drift = mean(log_chal), challenger_σ = length(log_chal) >= 2 ? std(log_chal) : 0.0,
     scale_min = clamp(minimum(ratios_vs_ref), 1e-6, 1.0),
     pinball_median_norm = _quantile_linear(team_pinballs, 0.5) / scale_used,
     pinball_iqr_norm = (_quantile_linear(team_pinballs, 0.75) - _quantile_linear(team_pinballs, 0.25)) / scale_used,
     point_error_sd_norm = length(point_errs_norm) >= 2 ? std(point_errs_norm) : 0.0,
     point_error_iqr_norm = _quantile_linear(point_errs_norm, 0.75) - _quantile_linear(point_errs_norm, 0.25),
     n_learn = n_learn_est)
end

"""
    validate_model_pool(store::QuantileStore; domain = nothing, ensemble_name = nothing, train_frac = 0.5)

Held-out temporal validation on `QuantileStore`: measures consecutive weekly best-model turnover,
train-best vs test-best rank persistence (`spearman`), and test-window ensemble accuracy against
both the median single team and the ex-ante training-period best team.
"""
function validate_model_pool(store::QuantileStore; domain = nothing, ensemble_name = nothing, train_frac::Real = 0.5)
    check(0 < train_frac < 1, "train_frac must lie strictly in (0, 1)")
    recs = [r for r in store.records if r.outcome !== nothing && (domain === nothing || r.domain == domain)]
    check(!isempty(recs), "no resolved QuantileForecastRecord entries matched")

    dates = sort(unique([r.target_date for r in recs]))
    check(length(dates) >= 4, "at least four target dates required for train/test split")
    split_idx = clamp(round(Int, train_frac * length(dates)), 2, length(dates) - 2)
    train_dates = Set(dates[1:split_idx])
    test_dates = dates[(split_idx + 1):end]
    test_set = Set(test_dates)

    all_forecasters = sort(unique([r.forecaster for r in recs]))
    ens = _detect_ensemble_name(all_forecasters, ensemble_name)
    teams = filter(f -> ens === nothing || f != ens, all_forecasters)
    check(length(teams) >= 2, "at least two competing teams required")

    by_td = Dict{Tuple{String,Date},Float64}()
    ens_test = Float64[]
    for r in recs
        pl = _mean_pinball(r)
        if r.forecaster == ens && r.target_date in test_set
            push!(ens_test, pl)
        elseif r.forecaster in teams
            by_td[(r.forecaster, r.target_date)] = pl
        end
    end

    train_means = Dict{String,Float64}()
    test_means = Dict{String,Float64}()
    for t in teams
        tr = [by_td[(t, d)] for d in dates[1:split_idx] if haskey(by_td, (t, d))]
        te = [by_td[(t, d)] for d in test_dates if haskey(by_td, (t, d))]
        !isempty(tr) && (train_means[t] = mean(tr))
        !isempty(te) && (test_means[t] = mean(te))
    end
    check(!isempty(train_means) && !isempty(test_means), "missing team records in train or test split")

    train_best_team = first(sort(collect(train_means); by = last))[1]
    test_best_team = first(sort(collect(test_means); by = last))[1]

    # Weekly winner sequence on held-out test dates
    weekly_best = String[]
    for d in test_dates
        day_teams = [(t, by_td[(t, d)]) for t in teams if haskey(by_td, (t, d))]
        !isempty(day_teams) && push!(weekly_best, first(sort(day_teams; by = last))[1])
    end
    turnover = length(weekly_best) >= 2 ?
        mean(weekly_best[i] != weekly_best[i - 1] for i in 2:length(weekly_best)) : 0.0

    median_single_test = _quantile_linear(collect(values(test_means)), 0.5)
    oracle_best_test = minimum(values(test_means))
    train_best_test = get(test_means, train_best_team, NaN)
    ens_loss_test = isempty(ens_test) ? NaN : mean(ens_test)

    shared = sort(collect(intersect(keys(train_means), keys(test_means))))
    rho = length(shared) >= 2 ? spearman([train_means[t] for t in shared], [test_means[t] for t in shared]) : NaN

    (n_train_dates = split_idx, n_test_dates = length(test_dates), n_shared_teams = length(shared),
     train_best_team = train_best_team, test_best_team = test_best_team,
     best_changed = train_best_team != test_best_team, best_model_turnover = turnover,
     ensemble_pinball_test = ens_loss_test, median_single_pinball_test = median_single_test,
     train_best_pinball_test = train_best_test, oracle_best_pinball_test = oracle_best_test,
     ensemble_vs_median_ratio = isfinite(ens_loss_test) ? ens_loss_test / median_single_test : NaN,
     ensemble_vs_train_best_ratio = (isfinite(ens_loss_test) && isfinite(train_best_test)) ? ens_loss_test / train_best_test : NaN,
     train_test_spearman = rho)
end

"""
    calibrate_m4_errors(path::AbstractString)

Cross-check log-relative error dispersion (`improve_drift`, `improve_σ`, `scale_min`) on an M4-style
summary table containing `ratio`, or paired `(error, benchmark_error)` / `(smape, naive_smape)` /
`(mase, naive_mase)` columns (`docs/DATA.md` Prioritised plan #1).
"""
function calibrate_m4_errors(path::AbstractString; delim::Char = endswith(lowercase(path), ".tsv") ? '\t' : ',')
    rows = _read_table_rows(path; delim = delim)
    hdr = Set(keys(first(rows)))
    ratios = Float64[]
    if "ratio" in hdr
        for r in rows
            v = _parse_opt_float(r["ratio"])
            v !== nothing && v > 0 && push!(ratios, v)
        end
    else
        pairs = [("error", "benchmark_error"), ("error", "naive_error"), ("smape", "naive_smape"), ("mase", "naive_mase")]
        hit = findfirst(p -> p[1] in hdr && p[2] in hdr, pairs)
        check(hit !== nothing, "M4 CSV must provide `ratio` or paired error & benchmark columns")
        num_col, den_col = pairs[hit]
        for r in rows
            num = _parse_opt_float(r[num_col])
            den = _parse_opt_float(r[den_col])
            num !== nothing && den !== nothing && num > 0 && den > 0 && push!(ratios, num / den)
        end
    end
    check(!isempty(ratios), "no valid positive error ratios found in M4 table")
    log_r = log.(ratios)
    (n_series = length(ratios), rel_error_median = _quantile_linear(ratios, 0.5),
     improve_drift = mean(log_r), improve_σ = length(log_r) >= 2 ? std(log_r) : 0.0,
     scale_min = clamp(minimum(ratios), 1e-6, 1.0))
end

# ---------------------------------------------------------------------------
# Priority 2: Domain reputation (Stack Exchange answers & cross-site profiles)
# ---------------------------------------------------------------------------

"""
    parse_stackexchange_tags_xml(path::AbstractString) -> Vector{NamedTuple}

Parse tag frequencies from a Stack Exchange `Tags.xml` dump (`TagName` and `Count` attributes).
"""
function parse_stackexchange_tags_xml(path::AbstractString)
    check(isfile(path), "Tags.xml path does not exist: $path")
    out = NamedTuple{(:tag, :count),Tuple{String,Int}}[]
    for line in eachline(path)
        occursin("<row", line) || continue
        m_name = match(r"TagName=\"([^\"]+)\"", line)
        m_cnt = match(r"Count=\"([0-9]+)\"", line)
        m_name === nothing || m_cnt === nothing && continue
        push!(out, (tag = String(m_name.captures[1]), count = parse(Int, m_cnt.captures[1])))
    end
    check(!isempty(out), "no <row TagName=... Count=... /> entries parsed from $path")
    sort!(out; by = x -> -x.count)
    out
end

"""
    load_stackexchange_sample(dir::AbstractString = CALIBRATION_SAMPLE_DIR) -> NamedTuple

Load pinned Stack Exchange answers (`stackexchange_answers.csv`) and cross-site user reputations
(`stackexchange_cross_site.csv`) from `dir`.
"""
function load_stackexchange_sample(dir::AbstractString = CALIBRATION_SAMPLE_DIR)
    ans = _read_table_rows(joinpath(dir, "stackexchange_answers.csv"))
    cs = _read_table_rows(joinpath(dir, "stackexchange_cross_site.csv"))
    for k in ("site", "question_id", "answer_id", "user_id", "creation_date", "score", "is_accepted", "tags")
        check(haskey(first(ans), k), "stackexchange_answers.csv missing column `$k`")
    end
    for k in ("account_id", "site", "site_url", "reputation", "answer_count")
        check(haskey(first(cs), k), "stackexchange_cross_site.csv missing column `$k`")
    end
    (answers = ans, cross_site = cs)
end

function _split_tags(raw::AbstractString)
    s = strip(raw)
    isempty(s) && return String[]
    if startswith(s, "<")
        return [String(m.captures[1]) for m in eachmatch(r"<([^>]+)>", s)]
    end
    [String(strip(t)) for t in split(s, '|') if !isempty(strip(t))]
end

"""
    stackexchange_domain_network(answers; top_tags = 12) -> NamedTuple

Build a two-tier domain network from Stack Exchange answers: sites are parent domains, top `top_tags`
tags are leaf domains, `μ` is leaf-in-parent fuzzy subsethood (`count(tag & site) / count(tag)`),
`tag_cooccurrence` is leaf Jaccard overlap across questions, and `new_tag_rate` is the share of
second-half distinct tags unseen in the chronological first half (`docs/DATA.md` Prioritised plan #2).
"""
function stackexchange_domain_network(answers::Vector{Dict{String,String}}; top_tags::Integer = 12)
    check(!isempty(answers) && top_tags >= 2, "non-empty answers and top_tags >= 2 required")
    sites = sort(unique([String(strip(r["site"])) for r in answers]))
    site_idx = Dict(s => j for (j, s) in enumerate(sites))

    tag_counts = Dict{String,Int}()
    parsed = Vector{Tuple{Int,Int,Int,Vector{String}}}(undef, length(answers))
    for (i, r) in enumerate(answers)
        ts = unique(_split_tags(r["tags"]))
        cdate = parse(Int, r["creation_date"])
        qid = parse(Int, r["question_id"])
        for t in ts
            tag_counts[t] = get(tag_counts, t, 0) + 1
        end
        parsed[i] = (cdate, site_idx[strip(r["site"])], qid, ts)
    end
    check(!isempty(tag_counts), "no tags found in Stack Exchange answers")

    k = min(Int(top_tags), length(tag_counts))
    top = first.(sort(collect(tag_counts); by = x -> (-x.second, x.first))[1:k])
    t_idx = Dict(t => i for (i, t) in enumerate(top))

    μ_counts = zeros(Float64, k, length(sites))
    tag_qsets = [Set{Tuple{Int,Int}}() for _ in 1:k]
    for (_, s_i, qid, ts) in parsed
        for t in ts
            haskey(t_idx, t) || continue
            ti = t_idx[t]
            μ_counts[ti, s_i] += 1.0
            push!(tag_qsets[ti], (s_i, qid))
        end
    end
    row_sums = sum(μ_counts; dims = 2)
    μ = zeros(Float64, k, length(sites))
    for i in 1:k
        row_sums[i] > 0 && (μ[i, :] .= μ_counts[i, :] ./ row_sums[i])
    end

    cooc = zeros(Float64, k, k)
    for i in 1:k, j in i:k
        u = length(union(tag_qsets[i], tag_qsets[j]))
        val = u > 0 ? length(intersect(tag_qsets[i], tag_qsets[j])) / u : 0.0
        cooc[i, j] = cooc[j, i] = val
    end

    # Tag formation / novelty rate across chronological split
    sort!(parsed; by = x -> x[1])
    mid = clamp(fld(length(parsed), 2), 1, length(parsed) - 1)
    first_tags = Set{String}()
    second_tags = Set{String}()
    for idx in 1:mid
        union!(first_tags, parsed[idx][4])
    end
    for idx in (mid + 1):length(parsed)
        union!(second_tags, parsed[idx][4])
    end
    new_tag_rate = isempty(second_tags) ? 0.0 : length(setdiff(second_tags, first_tags)) / length(second_tags)

    (sites = sites, tags = top, μ = μ, tag_cooccurrence = cooc,
     n_total_tags = length(tag_counts), new_tag_rate = new_tag_rate)
end

"""
    calibrate_stackexchange_skills(answers; rng = MersenneTwister(1)) -> NamedTuple

Calibrate per-domain log-normal skill heterogeneity `(median, log_sd)` and user record stabilization
threshold `n_learn` from settled answer scores and acceptances, and sample matching `draw_skills`.
"""
function calibrate_stackexchange_skills(answers::Vector{Dict{String,String}}; rng::AbstractRNG = MersenneTwister(1))
    check(!isempty(answers), "non-empty Stack Exchange answers required")
    sites = sort(unique([String(strip(r["site"])) for r in answers]))
    by_site_user = Dict{Tuple{String,String},Vector{Tuple{Int,Float64}}}()
    for r in answers
        s = strip(r["site"])
        u = strip(r["user_id"])
        q = max(0, parse(Int, r["score"])) + 2.0 * parse(Int, r["is_accepted"]) + 1.0
        cdate = parse(Int, r["creation_date"])
        push!(get!(by_site_user, (s, u), Tuple{Int,Float64}[]), (cdate, q))
    end

    site_params = Dict{String,NamedTuple{(:median, :log_sd, :n_users),Tuple{Float64,Float64,Int}}}()
    norm_logs = Float64[]
    multi_norm_logs = Float64[]
    by_rank = Dict{Int,Vector{Float64}}()
    for s in sites
        u_means = Float64[]
        u_multi = Float64[]
        for ((site_k, _), entries) in by_site_user
            site_k == s || continue
            sort!(entries; by = first)
            qs = last.(entries)
            m = mean(qs)
            push!(u_means, m)
            length(qs) >= 2 && push!(u_multi, m)
        end
        check(!isempty(u_means), "site `$s` has no user answers")
        med = _quantile_linear(u_means, 0.5)
        logs = log.(u_means ./ max(med, 1e-9))
        append!(norm_logs, logs)
        append!(multi_norm_logs, log.(u_multi ./ max(med, 1e-9)))
        site_params[s] = (median = med, log_sd = length(logs) >= 2 ? std(logs) : 0.0, n_users = length(u_means))
        # Track normalized cumulative quality error across chronological answer ranks
        for ((site_k, _), entries) in by_site_user
            site_k == s && length(entries) >= 4 || continue
            sort!(entries; by = first)
            qs = last.(entries) ./ max(med, 1e-9)
            rm = running_mean(qs)
            for k in eachindex(rm)
                push!(get!(by_rank, k, Float64[]), abs(rm[k] - rm[end]))
            end
        end
    end

    skill_log_sd = length(norm_logs) >= 2 ? std(norm_logs) : 0.0
    multi_log_sd = length(multi_norm_logs) >= 2 ? std(multi_norm_logs) : skill_log_sd
    ranks_sorted = sort(collect(keys(by_rank)))
    n_learn_est = if length(ranks_sorted) >= 3
        err_curve = [mean(by_rank[k]) for k in ranks_sorted]
        # Cumulative deviation settles below tol=0.25 or running step where spread drops below half initial
        hit = findfirst(i -> err_curve[i] <= 0.5 * err_curve[1], 1:length(err_curve))
        hit === nothing ? Float64(ranks_sorted[end]) : Float64(ranks_sorted[hit])
    else
        Float64(CALIBRATED.skill_log_sd > 0 ? 4 : 1)
    end

    pooled_med = _quantile_linear([site_params[s].median for s in sites], 0.5)
    drawn = draw_skills(rng, max(50, length(norm_logs)), length(sites), trues(length(sites));
                        median = pooled_med, log_sd = skill_log_sd)

    (sites = site_params, pooled_median = pooled_med, skill_log_sd = skill_log_sd,
     multi_answer_log_sd = multi_log_sd, n_users = length(norm_logs),
     n_multi_users = length(multi_norm_logs), n_learn = n_learn_est,
     sampled_skill_median = _quantile_linear(vec(drawn), 0.5),
     sampled_skill_log_sd = std(log.(vec(drawn))))
end

"""
    validate_stackexchange_reputation(answers, cross_site; half_lives = (1.0, 5.0, 20.0)) -> NamedTuple

Validate two domain-reputation properties on Stack Exchange data:
1. Within-site historical record tracking (early user quality predicts held-out late user quality,
   and relevance decay over rank improves or modulates prediction across `half_lives`).
2. No-halo isolation across domains (`domains.jl`): multi-site accounts with high reputation
   (`>= 1000`) on one site predominantly remain near the cold-start floor (`<= 101`) on other sites.
"""
function validate_stackexchange_reputation(answers::Vector{Dict{String,String}},
                                         cross_site::Vector{Dict{String,String}};
                                         half_lives::Tuple = (1.0, 5.0, 20.0))
    check(!isempty(answers) && !isempty(cross_site), "non-empty answers and cross_site tables required")

    by_user = Dict{Tuple{String,String},Vector{Tuple{Int,Float64}}}()
    for r in answers
        s = strip(r["site"])
        u = strip(r["user_id"])
        q = max(0, parse(Int, r["score"])) + 2.0 * parse(Int, r["is_accepted"]) + 1.0
        cdate = parse(Int, r["creation_date"])
        push!(get!(by_user, (s, u), Tuple{Int,Float64}[]), (cdate, q))
    end

    early_flat = Float64[]
    late_vals = Float64[]
    early_decayed = Dict(hl => Float64[] for hl in half_lives)
    for entries in values(by_user)
        length(entries) >= 2 || continue
        sort!(entries; by = first)
        mid = fld(length(entries), 2)
        eh = [x[2] for x in entries[1:mid]]
        lh = [x[2] for x in entries[(mid + 1):end]]
        push!(early_flat, mean(eh))
        push!(late_vals, mean(lh))
        for hl in half_lives
            w = [exp(-(mid - i) * log(2.0) / hl) for i in 1:mid]
            push!(early_decayed[hl], sum(w .* eh) / sum(w))
        end
    end
    check(length(early_flat) >= 5, "at least 5 multi-answer users needed for within-site validation")
    within_rho = spearman(early_flat, late_vals)
    decay_rhos = NamedTuple{Tuple(Symbol("hl_", Int(round(hl))) for hl in half_lives)}(
        Tuple(spearman(early_decayed[hl], late_vals) for hl in half_lives))

    # Cross-site reputation distribution per account
    by_account = Dict{String,Dict{String,Int}}()
    for r in cross_site
        aid = strip(r["account_id"])
        isempty(aid) && continue
        host = _extract_site_host(r["site_url"])
        isempty(host) && (host = lowercase(strip(r["site"])))
        rep = parse(Int, r["reputation"])
        d = get!(by_account, aid, Dict{String,Int}())
        d[host] = max(get(d, host, 0), rep)
    end

    multi_accounts = [d for d in values(by_account) if length(d) >= 2]
    high_accounts = [d for d in multi_accounts if maximum(values(d)) >= 1000]
    check(!isempty(high_accounts), "no multi-site high-reputation (>= 1000) accounts found")
    no_halo_floor_share = mean(minimum(values(d)) <= 101 for d in high_accounts)
    max_to_min_ratios = [maximum(values(d)) / max(minimum(values(d)), 1) for d in high_accounts]

    # Compare rank correlation on stats vs economics (related) and stackoverflow vs stats (cold-start skew)
    pair_corr(a, b) = begin
        xs = Float64[]; ys = Float64[]
        for d in multi_accounts
            haskey(d, a) && haskey(d, b) || continue
            push!(xs, log1p(d[a])); push!(ys, log1p(d[b]))
        end
        length(xs) >= 10 ? (n = length(xs), spearman = spearman(xs, ys)) : (n = length(xs), spearman = NaN)
    end

    (n_multi_answer_users = length(early_flat), within_site_spearman = within_rho,
     within_site_decay_spearman = decay_rhos, n_multi_site_accounts = length(multi_accounts),
     n_high_rep_accounts = length(high_accounts), no_halo_floor_share = no_halo_floor_share,
     median_max_min_rep_ratio = _quantile_linear(max_to_min_ratios, 0.5),
     stats_econ_rep = pair_corr("stats", "economics"),
     so_stats_rep = pair_corr("stackoverflow", "stats"))
end

# ---------------------------------------------------------------------------
# Priority 3: Wikipedia audit/revert history & Geiger-Halfaker outage validation
# ---------------------------------------------------------------------------

function _pick_col(hdr::Set{String}, candidates::Tuple{Vararg{String}})
    for c in candidates
        c in hdr && return c
    end
    nothing
end

"""
    load_wikipedia_reverts(path::AbstractString = joinpath(CALIBRATION_SAMPLE_DIR, "wikipedia_reverts_sample.csv"))

Load English Wikipedia edit/revert records (accepting both the compact CSV schema produced by
`tools/data/fetch_wikipedia_reverts.py` and standard MediaWiki history dump column aliases).
"""
function load_wikipedia_reverts(path::AbstractString = joinpath(CALIBRATION_SAMPLE_DIR, "wikipedia_reverts_sample.csv"))
    delim = endswith(lowercase(path), ".tsv") ? '\t' : ','
    rows = _read_table_rows(path; delim = delim)
    hdr = Set(keys(first(rows)))
    c_rev = _pick_col(hdr, ("is_reverted", "revision_is_identity_reverted"))
    c_delay = _pick_col(hdr, ("revert_delay_sec", "revision_seconds_to_identity_revert"))
    c_bot = _pick_col(hdr, ("reverter_is_bot", "revert_user_is_bot", "event_user_is_bot_by_historical"))
    c_undone = _pick_col(hdr, ("revert_was_undone", "was_re_reverted"))
    check(c_rev !== nothing && c_delay !== nothing, "Wikipedia revert table missing revert flag or delay column")

    out = NamedTuple{(:is_reverted, :delay_sec, :reverter_is_bot, :revert_was_undone),
                     Tuple{Bool,Union{Float64,Nothing},Union{Bool,Nothing},Bool}}[]
    for r in rows
        is_rev = _parse_bool_flag(r[c_rev])
        delay = _parse_opt_float(r[c_delay])
        rbot = c_bot === nothing || isempty(strip(r[c_bot])) ? nothing : _parse_bool_flag(r[c_bot])
        undone = c_undone === nothing ? false : _parse_bool_flag(r[c_undone])
        push!(out, (is_reverted = is_rev, delay_sec = delay, reverter_is_bot = rbot, revert_was_undone = undone))
    end
    out
end

"""
    calibrate_wikipedia_audit(rows; step_minutes = 1.0) -> NamedTuple

Fit empirical audit parameters from Wikipedia edit/revert rows: `deception_base_rate` (reverted share),
`persistent_deception_rate`, `p_false_trace` (share of reverts themselves undone), revert detection
latency quantiles (seconds), `vigilance` per step (`step_minutes`), and within-step catch fraction.
"""
function calibrate_wikipedia_audit(rows::AbstractVector; step_minutes::Real = 1.0)
    check(!isempty(rows) && isfinite(step_minutes) && step_minutes > 0, "non-empty rows and positive step_minutes required")
    n_edits = length(rows)
    revs = [r for r in rows if r.is_reverted]
    check(!isempty(revs), "at least one reverted edit is required")
    n_undone = count(r -> r.revert_was_undone, revs)
    delays = Float64[r.delay_sec for r in revs if r.delay_sec !== nothing && r.delay_sec >= 0]
    check(!isempty(delays), "no non-negative revert delays available")

    step_sec = Float64(step_minutes) * 60.0
    lag_mean = mean(delays)
    (n_edits = n_edits, n_reverted = length(revs), n_undone = n_undone,
     deception_base_rate = length(revs) / n_edits,
     persistent_deception_rate = (length(revs) - n_undone) / n_edits,
     p_false_trace = n_undone / length(revs),
     lag_median_sec = _quantile_linear(delays, 0.5),
     lag_mean_sec = lag_mean,
     lag_p90_sec = _quantile_linear(delays, 0.9),
     vigilance = clamp(step_sec / max(lag_mean, 1e-6), 0.0, 1.0),
     fast_detect_share = mean(delays .<= step_sec))
end

"""
    validate_wikipedia_outage(rows; step_minutes = 10.0) -> NamedTuple

Reproduce the Geiger-Halfaker (2013) bot-outage comparison on Wikipedia revert data (`docs/DATA.md` §9,
Plan #3): removing fast automated reverters (`reverter_is_bot == false` human-only counterfactual)
slows median/mean detection latency and reduces per-step vigilance while human editors still catch the
majority of vandalism/reverted edits.
"""
function validate_wikipedia_outage(rows::AbstractVector; step_minutes::Real = 1.0)
    check(!isempty(rows) && isfinite(step_minutes) && step_minutes > 0, "non-empty rows and positive step_minutes required")
    revs = [r for r in rows if r.is_reverted && r.delay_sec !== nothing && r.delay_sec >= 0]
    check(!isempty(revs), "no resolved reverted edits found")
    human = [r for r in revs if r.reverter_is_bot === false]
    bots = [r for r in revs if r.reverter_is_bot === true]
    check(!isempty(human), "no human-reverted edits found for outage counterfactual")

    all_d = Float64[r.delay_sec for r in revs]
    hum_d = Float64[r.delay_sec for r in human]
    bot_d = Float64[r.delay_sec for r in bots]
    step_sec = Float64(step_minutes) * 60.0

    all_mean = mean(all_d)
    hum_mean = mean(hum_d)
    (n_reverted = length(revs), n_bot_reverts = length(bot_d), n_human_reverts = length(hum_d),
     human_catch_share = length(hum_d) / length(revs),
     all_lag_median_sec = _quantile_linear(all_d, 0.5), all_lag_mean_sec = all_mean,
     human_lag_median_sec = _quantile_linear(hum_d, 0.5), human_lag_mean_sec = hum_mean,
     bot_lag_median_sec = isempty(bot_d) ? NaN : _quantile_linear(bot_d, 0.5),
     outage_delay_multiplier = hum_mean / max(all_mean, 1e-9),
     baseline_vigilance = clamp(step_sec / max(all_mean, 1e-6), 0.0, 1.0),
     outage_vigilance = clamp(step_sec / max(hum_mean, 1e-6), 0.0, 1.0),
     human_within_1hr_share = mean(hum_d .<= 3600.0))
end

"""
    load_empirical_calibration(; archive_dir = ARCHIVE_DIR, sample_dir = CALIBRATION_SAMPLE_DIR) -> NamedTuple

Load and calibrate all three Task E2 empirical sources (`cases/archive_sample` and
`cases/calibration_sample`) into one structured calibration & validation summary.
"""
function load_empirical_calibration(; archive_dir::AbstractString = ARCHIVE_DIR,
                                    sample_dir::AbstractString = CALIBRATION_SAMPLE_DIR)
    store = load_archive_store(archive_dir)
    se = load_stackexchange_sample(sample_dir)
    wp = load_wikipedia_reverts(joinpath(sample_dir, "wikipedia_reverts_sample.csv"))
    (model_pool = calibrate_model_pool(store),
     model_validation = validate_model_pool(store),
     m4 = calibrate_m4_errors(joinpath(sample_dir, "m4_methods_benchmark.csv")),
     domains = stackexchange_domain_network(se.answers),
     skills = calibrate_stackexchange_skills(se.answers),
     reputation_validation = validate_stackexchange_reputation(se.answers, se.cross_site),
     audit = calibrate_wikipedia_audit(wp),
     outage = validate_wikipedia_outage(wp))
end
