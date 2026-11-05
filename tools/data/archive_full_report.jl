# Full-archive version of the D2 report: rolling-window quantile scores (Lean `quantile_score_ref`)
# and the stability of forecaster rankings, with intervals. Data come from
#   python3 tools/data/fetch_covid19_forecast_hub.py --start 2020-06-01 --weeks 140 --out <dir>
# Run: julia --project=sim tools/data/archive_full_report.jl <dir> [width]
using BenefutureSim, Statistics
const S = BenefutureSim
dir = ARGS[1]; width = length(ARGS) > 1 ? parse(Int, ARGS[2]) : 6
store = S.load_archive_store(dir)
rep = S.rolling_report(store, "covid19_us_inc_death_1wk"; width)
ρ = filter(isfinite, rep.consecutive_rank_corr)
e = paired_effect(ρ)   # mean and t-inflated interval of consecutive-window rank correlations
println("windows: ", length(rep.windows), "  width: ", width, " weeks  forecasters per window: ", round(mean(length.(rep.scores)); digits = 1))
println("consecutive-window Spearman: n = ", length(ρ), "  mean = ", round(e.mean; digits = 3), " ± ", round(e.se; digits = 3),
        "  interval ", round(e.mean - e.z * e.se; digits = 3), " .. ", round(e.mean + e.z * e.se; digits = 3))
println("share of consecutive windows with rho > 0: ", proportion_interval(count(>(0), ρ), length(ρ)))
println("L  mean_rho  n")
for (L, c, n) in rep.length_curve
    println(L, "  ", round(c; digits = 3), "  ", n)
end
