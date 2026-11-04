# Rolling-window as-of scoring of a public forecast archive (CDC/UMass COVID-19 Forecast Hub);
# `docs/DATA.md` §16b (R6 persistence), Brief D2. Data: `cases/archive_sample/`, fetched by
# `tools/data/fetch_covid19_forecast_hub.py`. Scores reuse Lean `quantile_score_ref` via `quantile_score`,
# and records live in `QuantileStore` (replay.jl), so `records_as_of` refuses look-ahead.

const ARCHIVE_DIR = joinpath(@__DIR__, "..", "..", "cases", "archive_sample")
"Fixed scale for the quantile score `1/(1+mean_pinball/scale)` (deaths per week); a constant, not fitted."
const ARCHIVE_SCALE = 100.0
"Days after the target week ends before the truth counts as known (reporting lag)."
const ARCHIVE_RESOLUTION_LAG = 2

function _csv_rows(path)
    lines = readlines(path)
    header = split(lines[1], ',')
    [Dict(zip(header, split(l, ','))) for l in lines[2:end] if !isempty(strip(l))]
end

"""
    load_archive_store(dir = ARCHIVE_DIR; domain = "covid19_us_inc_death_1wk") -> QuantileStore

Builds the store: issue = forecast date, target = week end, resolution = target + lag, vintage =
resolution (the archive keeps only the final truth vintage; revisions are not reconstructed).
Outcome = sum of daily US incident deaths over the 7 days ending on the target date.
"""
function load_archive_store(dir = ARCHIVE_DIR; domain = "covid19_us_inc_death_1wk")
    truth = Dict(Date(r["date"]) => parse(Float64, r["value"]) for r in _csv_rows(joinpath(dir, "covid19_hub_us_inc_death.truth.csv")))
    groups = Dict{Tuple{String,Date,Date},Tuple{Vector{Float64},Vector{Float64}}}()
    for r in _csv_rows(joinpath(dir, "covid19_hub_us_inc_death_1wk.forecasts.csv"))
        key = (String(r["forecaster"]), Date(r["forecast_date"]), Date(r["target_end_date"]))
        q, p = get!(groups, key) do; (Float64[], Float64[]); end
        push!(q, parse(Float64, r["quantile"])); push!(p, parse(Float64, r["value"]))
    end
    store = QuantileStore()
    for ((f, fd, td), (q, p)) in sort(collect(groups); by = x -> (x[1][1], x[1][2]))
        days = [td - Day(k) for k in 0:6]
        all(d -> haskey(truth, d), days) || continue
        res = td + Day(ARCHIVE_RESOLUTION_LAG)
        append_record!(store, f, domain, fd, td, res, res, q, p, sum(truth[d] for d in days))
    end
    store
end

"""
    window_scores(store, domain, window_dates) -> Dict(forecaster => score)

Quantile score of each forecaster on the records whose target week ends on `window_dates`, using only records
known as of one day after the last resolution in the window. Forecasters missing any window week are dropped.
"""
function window_scores(store::QuantileStore, domain::String, window_dates::AbstractVector{Date})
    as_of = maximum(r.resolution_date for r in store.records if r.target_date in window_dates)
    recs = filter(r -> r.target_date in window_dates, records_as_of(store, as_of; domain = domain))
    out = Dict{String,Float64}()
    for f in unique(r.forecaster for r in recs)
        rf = [r for r in recs if r.forecaster == f]
        length(unique(r.target_date for r in rf)) == length(window_dates) || continue
        q = reduce(vcat, [r.quantiles for r in rf]); p = reduce(vcat, [r.predictions for r in rf])
        y = reduce(vcat, [fill(r.outcome, length(r.quantiles)) for r in rf])
        out[f] = quantile_score(q, p, y, ARCHIVE_SCALE)
    end
    out
end

function _rank_corr(a::Dict{String,Float64}, b::Dict{String,Float64})
    common = sort(collect(intersect(keys(a), keys(b))))
    length(common) >= 3 ? spearman([a[k] for k in common], [b[k] for k in common]) : NaN
end

"""
    rolling_report(store, domain; width = 8) -> NamedTuple

Non-overlapping consecutive windows of `width` target weeks: per-forecaster score per window, the
Spearman rank correlation between consecutive windows (R6), and a record-length curve: for each L the
mean rank correlation between the scores on L weeks and the next L weeks (all start offsets).
"""
function rolling_report(store::QuantileStore, domain::String; width::Int = 8, max_len::Int = 12)
    dates = sort(unique(r.target_date for r in store.records if r.domain == domain))
    wins = [dates[i:i+width-1] for i in 1:width:length(dates)-width+1]
    scores = [window_scores(store, domain, w) for w in wins]
    consec = [_rank_corr(scores[i], scores[i+1]) for i in 1:length(scores)-1]
    curve = Tuple{Int,Float64,Int}[]
    for L in 2:max_len
        cs = Float64[]
        for s in 1:length(dates)-2L+1
            c = _rank_corr(window_scores(store, domain, dates[s:s+L-1]), window_scores(store, domain, dates[s+L:s+2L-1]))
            isnan(c) || push!(cs, c)
        end
        isempty(cs) || push!(curve, (L, mean(cs), length(cs)))
    end
    (windows = wins, scores = scores, consecutive_rank_corr = consec, length_curve = curve)
end
