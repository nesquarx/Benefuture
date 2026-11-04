# Writes cases/archive_sample/expected_window_scores.csv and prints the D2 report.
# Run: julia --project=sim tools/data/archive_report.jl
using BenefutureSim
const S = BenefutureSim
store = S.load_archive_store()
rep = S.rolling_report(store, "covid19_us_inc_death_1wk"; width = 6)
out = joinpath(S.ARCHIVE_DIR, "expected_window_scores.csv")
open(out, "w") do io
    println(io, "window,first_target,last_target,forecaster,score")
    for (i, sc) in enumerate(rep.scores), f in sort(collect(keys(sc)))
        println(io, i, ",", first(rep.windows[i]), ",", last(rep.windows[i]), ",", f, ",", sc[f])
    end
end
for (i, sc) in enumerate(rep.scores)
    println("window $i ($(first(rep.windows[i])) .. $(last(rep.windows[i]))), n=$(length(sc))")
    for f in sort(collect(keys(sc)); by = k -> -sc[k])
        println("   ", rpad(f, 24), round(sc[f]; digits = 4))
    end
end
println("consecutive-window Spearman: ", round.(rep.consecutive_rank_corr; digits = 3))
println("L  mean_rho  n")
for (L, c, n) in rep.length_curve
    println(L, "  ", round(c; digits = 3), "  ", n)
end
