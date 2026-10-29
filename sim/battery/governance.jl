# Failure-boundary battery for governance (M5 world). Run: julia --project=sim sim/battery/governance.jl
# Severity 0 is the clean world; 1 the top of each factor's explored range; rays run to 2.
# Convergence (an evaluation criterion, not a rule): over the seeds' majority, the share of the last
# half of decisions decided correctly (after split trials) is at least `ACCURACY`. Colluders are the
# most reputable experts of each domain, stealthy (defecting only where outcomes stay hidden): the
# worst case.
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
]
names = first.(FACTORS)
function converges(sev)
    ok = map(SEEDS) do seed
        kw = Dict{Symbol,Any}()
        for ((_, set!), s) in zip(FACTORS, clamp.(sev, 0, Inf))
            set!(s, kw)
        end
        r = run_m5(M5Params(m3, 1:4; decisions = DECISIONS, stealth = true, kw...); seed)
        mean(r.correct_trace[(DECISIONS ÷ 2 + 1):end]) >= ACCURACY
    end
    count(ok) > length(SEEDS) / 2
end

rng = Xoshiro(20261029)
budget = (rays = parse(Int, get(ENV, "BF_RAYS", "24")), screen_n = parse(Int, get(ENV, "BF_SCREEN", "128")))
t0 = time()
bt = battery(converges, names; rng, rays = budget.rays, screen_n = budget.screen_n, tmax = 2.0, tol = 0.03, grid = 8)
write_results("governance", bt, names; clean = NaN, minutes = (time() - t0) / 60)
