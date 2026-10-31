# Quick simulation benchmark, to compare machines and agents (COORDINATION.md, Benchmarks).
# Run: julia --project=sim tools/bench/bench.jl [label]
# Prints one Markdown table row. Each case runs once to compile, then is timed on its second run.
using BenefutureSim, Printf, Random, Statistics

label = isempty(ARGS) ? gethostname() : ARGS[1]
t_load = @elapsed nothing
timed(f) = (f(); @elapsed f())
m3c() = run_m3c(M3cParams(ToyParams(n = 80, steps = 300, plans = 10),
                          [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], CALIBRATED.sloppiness) for _ in 1:8], [1, 1, 2, 2], trues(4);
                          λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true); seed = 1)
m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                       [DomainAgent([k == l ? 0.1 + 0.1 * r : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                        for k in 1:4 for r in 1:5], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
m5() = run_m5(M5Params(m3, 1:4; decisions = 400); seed = 1)
m7() = run_m7(ToyParams(n = 100, steps = 300, plans = 10); seed = 1, ε = 0.3)
t3, t5, t7 = timed(m3c), timed(m5), timed(m7)
load = try first(split(read("/proc/loadavg", String))) catch; "?" end
@printf("| %s | %s | %d | %d | %s | %.2f | %.2f | %.2f |\n", label, Sys.CPU_NAME, Sys.CPU_THREADS, Threads.nthreads(), load, t3, t5, t7)
