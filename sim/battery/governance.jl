# Failure-boundary battery for governance (M5 world). Run: julia --project=sim sim/battery/governance.jl
# Severity 0 is the clean world; 1 the top of each factor's explored range; rays run to 2.
# Convergence (an evaluation criterion, not a rule): over the seeds' majority, the share of the last
# half of decisions right in the end (after split trials and AdvAp's recounts) is at least
# `ACCURACY`. Colluders are the most reputable experts of each domain, stealthy (defecting only where
# outcomes stay hidden): the worst case. AdvAp (L160) is on; loyalty to the bloc is a factor.
using BenefutureSim, Statistics, Random, Printf

const SEEDS, ACCURACY, DECISIONS = 1:3, 0.75, 800
m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                       [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                        for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
top(f) = unique(vcat([sortperm(m3.relevance_leaf[:, d]; rev = true)[1:round(Int, f * 25)] for d in 1:4]...))
const FACTORS = [
    ("signal noise", (s, kw) -> (kw[:signal_σ] = 1 + 39s)),
    ("ability scatter", (s, kw) -> (kw[:ability_spread] = 1.5s)),
    ("hidden outcomes", (s, kw) -> (kw[:p_apparent] = clamp(0.9 - 0.8s, 0.0, 1.0))),
    ("local noise", (s, kw) -> (kw[:local_σ] = 1 + 3s)),
    ("collusion", (s, kw) -> (kw[:colluders] = top(clamp(0.5s, 0.0, 1.0)))),
    ("delegation", (s, kw) -> (kw[:p_delegate] = clamp(s, 0.0, 1.0))),
    ("loyalty", (s, kw) -> (kw[:loyalty] = 10s)),
]
names = first.(FACTORS)
function converges(sev)
    ok = map(SEEDS) do seed
        kw = Dict{Symbol,Any}()
        for ((_, set!), s) in zip(FACTORS, clamp.(sev, 0, Inf))
            set!(s, kw)
        end
        r = run_m5(M5Params(m3, 1:4; decisions = DECISIONS, stealth = true, advap = true, kw...); seed)
        mean(r.final_trace[(DECISIONS ÷ 2 + 1):end]) >= ACCURACY
    end
    count(ok) > length(SEEDS) / 2
end

rng = Xoshiro(20261029)
budget = (rays = parse(Int, get(ENV, "BF_RAYS", "24")), screen_n = parse(Int, get(ENV, "BF_SCREEN", "128")))
t0, commit = time(), current_commit()  # the code this run tests
bt = battery(converges, names; rng, rays = budget.rays, screen_n = budget.screen_n, tmax = 2.0, tol = 0.03, grid = 8)
const OUT = get(ENV, "BF_OUT", joinpath(@__DIR__, "results"))  # a scratch directory for trial runs
write_results("governance", bt, names; clean = NaN, minutes = (time() - t0) / 60, commit, dir = OUT)

# Continuous methods (sim/src/methods.jl), on their own random stream after the outputs above, so
# those repeat exactly. Reading: the share of the last half of decisions right, less `ACCURACY` (the
# margin), averaged over seeds until its standard error is within SE_TOL (SEED_MIN to SEED_MAX seeds).
const SE_TOL, SEED_MIN, SEED_MAX = 0.02, 3, 8
function reading(sev)
    kw = Dict{Symbol,Any}()
    for ((_, set!), s) in zip(FACTORS, clamp.(sev, 0, Inf))
        set!(s, kw)
    end
    r = seeds_until_stable(; tol = SE_TOL, min_seeds = SEED_MIN, max_seeds = SEED_MAX) do seed
        tr = run_m5(M5Params(m3, 1:4; decisions = DECISIONS, stealth = true, advap = true, kw...); seed)
        mean(tr.final_trace[(DECISIONS ÷ 2 + 1):end]) - ACCURACY
    end
    (outputs = [r.mean], n = r.n)
end
mrng = Xoshiro(20261030)
mbudget = (sobol = parse(Int, get(ENV, "BF_SOBOL", "64")), active = parse(Int, get(ENV, "BF_ACTIVE", "60")),
           top = parse(Float64, get(ENV, "BF_SOBOL_TOP", "1.0")))
if mbudget.sobol > 0 || mbudget.active > 0
    t1 = time()
    pool = bt.screen_scale .* gaussian_hypercube(mrng, 2000, length(names); μ = 0.5, σ = 0.25)
    m = battery_methods(reading, names; rng = mrng, outputs = ["margin"], pool, sobol_n = mbudget.sobol, sobol_top = mbudget.top,
                        active_budget = mbudget.active)
    write_methods("governance", m, names; reading_note = "Readings: the share of the last half of decisions right, less $ACCURACY (the margin), averaged over seeds 1, 2, … until its standard error (Student-t inflated) is within $SE_TOL ($SEED_MIN to $SEED_MAX seeds).",
                  screen_fail_rate = bt.screening.fail_rate, minutes = (time() - t1) / 60, dir = OUT)
end
