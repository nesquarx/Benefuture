# Failure-boundary battery for the economy (M3c world). Run: julia --project=sim sim/battery/economy.jl
# Severity 0 is the least realistic noise and no attack; 1 the realistic top of each range (sim/README.md, Noise);
# rays run to 2. Convergence (an evaluation criterion, not a rule): by the seeds' vote (three, or
# five where the three disagree),
# floor growth on understanding after the score-only start is at least `GROWTH` of the clean
# world's, and deceit and laundering (when present) do not pay: the attackers' wealth relative to
# the honest agents' rises by no more than `GAIN` over the same world and seed with the attackers
# honest. (Against one honest agent alone, honest agents' own ±10% spread failed near-clean worlds.)
using BenefutureSim, Statistics, Random, Printf

const STEPS, SEEDS, MORE, GROWTH, GAIN = 300, 1:3, 4:5, 0.25, 1.1
const FACTORS = [
    # noise: severity 0 is the least realistic noise, 1 the realistic top (the edge of a functional
    # domain, where established models fall to about coarse accuracy; sim/README.md, Noise)
    ("markers", (s, kw) -> (kw[:marker_σ] = 0.02 + 0.18s)),
    ("model error", (s, kw) -> (kw[:σ_leaf] = 0.05 + 0.4s; kw[:σ_branch] = 0.2 + 0.4s; kw[:σ_coarse] = 0.35 + 0.4s)),
    ("model bias", (s, kw) -> (kw[:bias_σ] = 0.2s)),
    ("classification", (s, kw) -> (kw[:classify_σ] = 0.03 + 0.07s; kw[:spread] = 0.03 + 0.07s)),
    ("execution", (s, kw) -> (kw[:sloppiness] = 0.6s)),
    ("accounting", (s, kw) -> (kw[:cost_σ] = 0.3s; kw[:regen_σ] = 0.5s)),
    ("memory loss", (s, kw) -> (kw[:memory_loss] = min(0.1s, 1.0))),
    ("attribution", (s, kw) -> (kw[:attribution_σ] = 0.3s)),
    ("hazards", (s, kw) -> (kw[:p_hazard] = min(0.3s, 1.0); kw[:p_informed] = max(1 - 0.4s, 0.0); kw[:dil] = max(1 - 0.3s, 0.0))),
    # attacks
    ("deceit", (s, kw) -> (kw[:deceit_size] = 2s)),
    ("outage", (s, kw) -> (kw[:outage] = round(Int, 100s))),
    ("capture", (s, kw) -> (kw[:capture] = 3s)),
    ("side harm", (s, kw) -> (kw[:p_side] = min(0.2s, 1.0))),
    ("laundering", (s, kw) -> (kw[:launder_chance] = min(0.5s, 1.0))),
]
names = first.(FACTORS)

function world(sev)
    kw = Dict{Symbol,Any}()
    for ((_, set!), s) in zip(FACTORS, sev)
        set!(s, kw)
    end
    sl = pop!(kw, :sloppiness, 0.0); dil = pop!(kw, :dil, 1.0)
    d = pop!(kw, :deceit_size, 0.0); out = pop!(kw, :outage, 0); cap = pop!(kw, :capture, 0.0)
    lc = pop!(kw, :launder_chance, 0.0)
    agents = [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], sl) for _ in 1:8]
    events = Shock[]
    out > 0 && push!(events, shock(:outage; step = 100, duration = out))
    cap > 0 && push!(events, shock(:capture; step = 100, duration = 150, size = cap, target = 1))
    M3cParams(ToyParams(n = 80, steps = STEPS, plans = 10), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
              transactions = true, causal_distribution = true, p_upstream = 0.5, guardians = [1, 2, 3, 4],
              diligence = fill(dil, 8), p_foresee = 1.0, repair_efficiency = 0.5, deceit = [0, 0, 0, 0, 0, 0, d, d], launder = [0, 0, 0, 0, 0, lc, 0, 0],
              events, kw...)
end
gain(tr) = tr.floor_u[end] - tr.floor_u[51]
const CLEAN = mean(gain(run_m3c(world(zeros(length(FACTORS))); seed)) for seed in SEEDS)
function converges(sev)
    # Three seeds; where they disagree (near the boundary), two more, and the majority of five.
    one(seed) = begin
        tr = run_m3c(world(clamp.(sev, 0, Inf)); seed)
        attacked = sev[10] > 0 || sev[14] > 0
        honest = attacked ? run_m3c(world(clamp.([sev[1:9]; 0; sev[11:13]; 0], 0, Inf)); seed) : tr
        # Wealth of agents `k` relative to the honest agents 1-5 (guardians' hazard costs cancel
        # between the two runs).
        rel(t, k) = mean(sum(t.balance[i, :]) for i in k) / mean(sum(t.balance[i, :]) for i in 1:5)
        pays(k) = rel(tr, k) > GAIN * rel(honest, k)
        honest_enough = (sev[10] <= 0 || !pays(7:8)) && (sev[14] <= 0 || !pays(6:6))
        gain(tr) >= GROWTH * CLEAN && honest_enough
    end
    votes = [one(seed) for seed in SEEDS]
    (all(votes) || !any(votes)) && return all(votes)
    append!(votes, [one(seed) for seed in MORE])
    count(votes) > length(votes) / 2
end

rng = Xoshiro(20261029)
budget = (rays = parse(Int, get(ENV, "BF_RAYS", "16")), screen_n = parse(Int, get(ENV, "BF_SCREEN", "64")))
t0, commit = time(), current_commit()  # the code this run tests
bt = battery(converges, names; rng, rays = budget.rays, screen_n = budget.screen_n, tmax = 2.0, tol = 0.06, grid = 6)
write_results("economy", bt, names; clean = CLEAN, minutes = (time() - t0) / 60, commit)
