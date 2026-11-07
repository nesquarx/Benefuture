# Replay every E5 case on the current code and append one log row per case to docs/E5_RUNS.md
# (REPLAY_PREREG §8, lifecycle: every run logged, none replaced). Run: julia --project=sim tools/e5/rerun.jl
using BenefutureSim, Dates
root = joinpath(@__DIR__, "..", "..")
h = readchomp(Cmd(`bash -c "cat sim/src/replay.jl BenefutureReference/*.lean | sha256sum | cut -c1-16"`; dir = root))
commit = readchomp(Cmd(`git rev-parse --short HEAD`; dir = root))
log = joinpath(root, "docs", "E5_RUNS.md")
isfile(log) || write(log, "# E5 run log\n\nOne row per case per run (REPLAY_PREREG §8, lifecycle); rows are appended, never edited.\n\n| Date | Commit | Code hash | Case | Suggestion | Rule-set battery | Magnitude flips |\n|---|---|---|---|---|---|---|\n")
for f in sort(filter(x -> endswith(x, ".toml"), readdir(joinpath(root, "cases", "e5"); join = true)))
    c = load_replay_case(f)
    ch = replace(replay_decision(load_replay_case(f)).chosen_option, r"\+compensated$" => " (compensated)")
    b = replay_rule_battery(load_replay_case(f))
    top = join(["$(k) $(round(Int, 100v))%" for (k, v) in sort(collect(b.shares); by = x -> -x[2])], ", ")
    n = length(replay_sensitivity(load_replay_case(f)))
    open(log, "a") do io
        println(io, "| $(today()) | $commit | $h | $(c["id"]) | $ch | $top | $n |")
    end
    println(c["id"], ": ", ch, " | ", top, " | flips ", n)
end
