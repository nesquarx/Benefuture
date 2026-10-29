# Failure-boundary battery for the economy (M3c world). Run: julia --project=sim sim/battery/economy.jl
# Severity 0 is the clean world; 1 the top of each factor's explored range (sim/README.md, Noise);
# rays run to 2. Convergence (an evaluation criterion, not a rule): over the seeds' majority,
# floor growth on understanding after the score-only start is at least `GROWTH` of the clean
# world's, and deceivers end no richer than `GAIN` × honest agents' mean.
using BenefutureSim, Statistics, Random, Printf

const STEPS, SEEDS, GROWTH, GAIN = 300, 1:2, 0.25, 1.1
const FACTORS = [
    # noise
    ("markers", (s, kw) -> (kw[:marker_σ] = 0.5s)),
    ("model error", (s, kw) -> (kw[:σ_leaf] = 0.3 + 1.7s; kw[:σ_branch] = 0.5 + 1.5s; kw[:σ_coarse] = 0.75 + 1.25s)),
    ("model bias", (s, kw) -> (kw[:bias_σ] = 0.5s)),
    ("classification", (s, kw) -> (kw[:classify_σ] = 0.03 + 0.12s; kw[:spread] = 0.03 + 0.12s)),
    ("execution", (s, kw) -> (kw[:sloppiness] = 2s)),
    ("accounting", (s, kw) -> (kw[:cost_σ] = 0.5s; kw[:regen_σ] = 1.0s)),
    ("memory loss", (s, kw) -> (kw[:memory_loss] = min(0.2s, 1.0))),
    ("attribution", (s, kw) -> (kw[:attribution_σ] = 0.5s)),
    ("hazards", (s, kw) -> (kw[:p_hazard] = min(0.5s, 1.0); kw[:p_informed] = max(1 - 0.7s, 0.0); kw[:dil] = max(1 - 0.7s, 0.0))),
    # attacks
    ("deceit", (s, kw) -> (kw[:deceit_size] = 2s)),
    ("outage", (s, kw) -> (kw[:outage] = round(Int, 100s))),
    ("capture", (s, kw) -> (kw[:capture] = 3s)),
    ("side harm", (s, kw) -> (kw[:p_side] = min(0.3s, 1.0))),
]
names = first.(FACTORS)

function world(sev)
    kw = Dict{Symbol,Any}()
    for ((_, set!), s) in zip(FACTORS, sev)
        set!(s, kw)
    end
    sl = pop!(kw, :sloppiness, 0.0); dil = pop!(kw, :dil, 1.0)
    d = pop!(kw, :deceit_size, 0.0); out = pop!(kw, :outage, 0); cap = pop!(kw, :capture, 0.0)
    agents = [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], sl) for _ in 1:8]
    events = Shock[]
    out > 0 && push!(events, shock(:outage; step = 100, duration = out))
    cap > 0 && push!(events, shock(:capture; step = 100, duration = 150, size = cap, target = 1))
    M3cParams(ToyParams(n = 80, steps = STEPS, plans = 10), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
              transactions = true, causal_distribution = true, p_upstream = 0.5, guardians = [1, 2, 3, 4],
              diligence = fill(dil, 8), p_foresee = 1.0, repair_efficiency = 0.5, deceit = [0, 0, 0, 0, 0, 0, d, d],
              events, kw...)
end
gain(tr) = tr.floor_u[end] - tr.floor_u[51]
const CLEAN = mean(gain(run_m3c(world(zeros(length(FACTORS))); seed)) for seed in SEEDS)
function converges(sev)
    ok = map(SEEDS) do seed
        tr = run_m3c(world(clamp.(sev, 0, Inf)); seed)
        rich(k) = sum(tr.balance[k, :])
        gain(tr) >= GROWTH * CLEAN && mean(rich.(7:8)) <= GAIN * max(mean(rich.(1:6)), 1e-9)
    end
    count(ok) > length(SEEDS) / 2
end

rng = Xoshiro(20261029)
budget = (rays = parse(Int, get(ENV, "BF_RAYS", "16")), screen_n = parse(Int, get(ENV, "BF_SCREEN", "64")))
t0 = time()
bt = battery(converges, names; rng, rays = budget.rays, screen_n = budget.screen_n, tmax = 2.0, tol = 0.06, grid = 6)
write_results("economy", bt, names; clean = CLEAN, minutes = (time() - t0) / 60)
