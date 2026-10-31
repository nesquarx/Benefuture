# Failure-boundary battery for the economy (M3c world). Run: julia --project=sim sim/battery/economy.jl
# Ranges follow docs/CALIBRATION.md section 7. Severity 0 is a mildly imperfect realistic world: the
# low end of an invariant factor's range (8.33), the Benefuture-plausible value of an institution-
# dependent one (vigilance, diligence, accounting, audit errors); 1 the realistic bad end, or the
# status quo for an institution-dependent factor; rays run to 2 (stress beyond the range). No attack at 0.
# AdvAp (L160) is on, its frictions factors;
# rays run to 2. Convergence (an evaluation criterion, not a rule): the Goal's success pattern (L74)
# after the score-only start, by the seeds' vote: the floors and medians of understanding and
# happiness each grow by at least `GROWTH` of the clean world's, the peak of understanding ends no
# lower than it began, and the deepest single-being drop stays within `HARM` × the clean world's; and
# deceit and laundering (when present) do not pay. An attack pays when the attackers' wealth
# relative to the honest agents, over the same world and seed with the attackers honest, averages
# above `GAIN` across the seeds and its lower bound (mean less two standard errors) is above 1.
# Three seeds, five where the vote splits or the attack test is ambiguous. (Per-seed tests against
# one honest agent failed near-clean worlds: one agent's wealth spreads about ±10% across seeds.)
using BenefutureSim, Statistics, Random, Printf

const STEPS, SEEDS, MORE, GROWTH, GAIN, HARM = 300, 1:3, 4:5, 0.25, 1.1, 3.0
const FACTORS = [
    # noise (classes in sim/README.md, Noise)
    ("markers", (s, kw) -> (kw[:marker_σ] = 0.1 + 0.5s)),          # mixed: registries 0.1 to self-reports 0.6
    ("model error", (s, kw) -> (kw[:σ_leaf] = 0.3 + 0.6s; kw[:σ_branch] = 0.6 + 0.35s; kw[:σ_coarse] = 0.85 + 0.15s)),  # mixed: natural to social science
    ("model bias", (s, kw) -> (kw[:bias_σ] = 0.1 + 0.2s)),         # mixed: overconfidence 0.1 to 0.3
    ("classification", (s, kw) -> (kw[:classify_σ] = 0.05 + 0.15s; kw[:spread] = 0.05 + 0.15s)),  # invariant: coding noise
    ("execution", (s, kw) -> (kw[:sloppiness] = 0.1 + 0.4s)),      # mixed: individuals' intention-behaviour gap
    ("accounting", (s, kw) -> (kw[:cost_σ] = 0.05 + 0.25s)),       # institution-dependent: audited ledgers to status quo
    ("commons", (s, kw) -> (kw[:regen_σ] = 0.3 + 0.5s)),           # invariant: recruitment variability
    ("memory loss", (s, kw) -> (kw[:memory_loss] = min(0.1s, 1.0))),  # institution-dependent
    ("attribution", (s, kw) -> (kw[:attribution_σ] = 0.1 + 0.3s)), # mixed
    # invariant: hazards arise (tail shape is the world's default); institution-dependent: guardians informed and diligent
    ("hazards", (s, kw) -> (kw[:p_hazard] = min(0.05 + 0.25s, 1.0))),
    ("guardians", (s, kw) -> (kw[:p_informed] = clamp(0.95 - 0.35s, 0.0, 1.0); kw[:dil] = clamp(0.95 - 0.55s, 0.0, 1.0))),
    # attacks
    ("deceit", (s, kw) -> (kw[:deceit_size] = 2s)),
    ("outage", (s, kw) -> (kw[:outage] = round(Int, 100s))),
    ("capture", (s, kw) -> (kw[:capture] = 3s)),
    ("side harm", (s, kw) -> (kw[:p_side] = min(0.01 + 0.09s, 1.0))),  # mixed: simple to complex domains
    ("laundering", (s, kw) -> (kw[:launder_chance] = min(0.5s, 1.0))),
    # AdvAp's frictions: readers who seldom read the log (institution-dependent: 0.1 plausible, 0.001 passive status quo),
    # examinations that convict the innocent (mixed)
    ("inattention", (s, kw) -> (kw[:vigilance] = max(0.1 - 0.099s, 0.0))),
    ("audit errors", (s, kw) -> (kw[:p_false_trace] = min(0.005 + 0.045s, 1.0))),
]
names = first.(FACTORS)

function world(sev)
    kw = Dict{Symbol,Any}()
    for ((_, set!), s) in zip(FACTORS, sev)
        set!(s, kw)
    end
    sl = pop!(kw, :sloppiness, CALIBRATED.sloppiness); dil = pop!(kw, :dil, 0.95)
    d = pop!(kw, :deceit_size, 0.0); out = pop!(kw, :outage, 0); cap = pop!(kw, :capture, 0.0)
    lc = pop!(kw, :launder_chance, 0.0)
    # skills log-normal around 0.6 in the two worked domains (calibrated shape, a fixed population: the same eight people in every world)
    skills = draw_skills(Xoshiro(20261031), 8, 4, [1, 3]; median = 0.6)
    agents = [DomainAgent(skills[a, :], [0.5, 0, 0.5, 0], sl) for a in 1:8]
    events = Shock[]
    out > 0 && push!(events, shock(:outage; step = 100, duration = out))
    cap > 0 && push!(events, shock(:capture; step = 100, duration = 150, size = cap, target = 1))
    M3cParams(ToyParams(n = 80, steps = STEPS, plans = 10), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
              transactions = true, causal_distribution = true, p_upstream = 0.5, guardians = [1, 2, 3, 4],
              diligence = fill(dil, 8), p_foresee = 1.0, repair_efficiency = 0.5, deceit = [0, 0, 0, 0, 0, 0, d, d], launder = [0, 0, 0, 0, 0, lc, 0, 0],
              advap = true,
              events, kw...)
end
pattern(tr) = success_pattern(tr; from = 51)
const CLEAN = let ps = [pattern(run_m3c(world(zeros(length(FACTORS))); seed)) for seed in SEEDS]
    (; (f => mean(getfield(p, f) for p in ps) for f in (:floor_u, :floor_h, :median_u, :median_h, :peak_u, :worst_drop))...)
end
function grows(tr)
    sp = pattern(tr)
    all(getfield(sp, f) >= GROWTH * getfield(CLEAN, f) for f in (:floor_u, :floor_h, :median_u, :median_h)) &&
        sp.peak_u >= 0 && sp.worst_drop <= HARM * CLEAN.worst_drop
end
function converges(sev)
    attacks = [(findfirst(==("deceit"), names), 7:8), (findfirst(==("laundering"), names), 6:6)]  # (factor, attacking agents)
    # Wealth of agents `k` relative to the honest agents 1-5 (guardians' hazard costs cancel
    # between the two runs).
    rel(t, k) = mean(sum(t.balance[i, :]) for i in k) / mean(sum(t.balance[i, :]) for i in 1:5)
    one(seed) = begin
        tr = run_m3c(world(clamp.(sev, 0, Inf)); seed)
        hs = copy(sev); for (f, _) in attacks; hs[f] = 0; end
        honest = any(sev[f] > 0 for (f, _) in attacks) ? run_m3c(world(clamp.(hs, 0, Inf)); seed) : tr
        (grows = grows(tr), ratios = [rel(tr, k) / rel(honest, k) for (_, k) in attacks])
    end
    pays(r) = mean(r) > GAIN && mean(r) - 2std(r) / sqrt(length(r)) > 1
    unsure(r) = (mean(r) > GAIN) != (mean(r) - 2std(r) / sqrt(length(r)) > 1)
    out = [one(seed) for seed in SEEDS]
    ratios(j) = [o.ratios[j] for o in out]
    split = !(all(o.grows for o in out) || !any(o.grows for o in out))
    if split || any(sev[f] > 0 && unsure(ratios(j)) for (j, (f, _)) in enumerate(attacks))
        append!(out, [one(seed) for seed in MORE])
    end
    count(o.grows for o in out) > length(out) / 2 && !any(sev[f] > 0 && pays(ratios(j)) for (j, (f, _)) in enumerate(attacks))
end

rng = Xoshiro(20261029)
budget = (rays = parse(Int, get(ENV, "BF_RAYS", "16")), screen_n = parse(Int, get(ENV, "BF_SCREEN", "64")))
t0, commit = time(), current_commit()  # the code this run tests
bt = battery(converges, names; rng, rays = budget.rays, screen_n = budget.screen_n, tmax = 2.0, tol = 0.06, grid = 6)
const OUT = get(ENV, "BF_OUT", joinpath(@__DIR__, "results"))  # a scratch directory for trial runs
write_results("economy", bt, names; clean = CLEAN.floor_u, minutes = (time() - t0) / 60, commit, dir = OUT)

# Continuous methods (sim/src/methods.jl), on their own random stream after the outputs above, so
# those repeat exactly. Readings: the success pattern's margin and its criteria's slacks, averaged
# over seeds until the margin's standard error is within SE_TOL (between SEED_MIN and SEED_MAX seeds).
# The margin covers the success pattern only; whether an attack pays stays with the binary oracle.
const SE_TOL, SEED_MIN, SEED_MAX = 0.1, 3, 8
const OUTPUTS = ["margin", "floor_u", "floor_h", "median_u", "median_h", "peak_u", "worst_drop"]
function reading(sev)
    per = Dict{Int,Vector{Float64}}()
    r = seeds_until_stable(; tol = SE_TOL, min_seeds = SEED_MIN, max_seeds = SEED_MAX) do seed
        m = pattern_margin(pattern(run_m3c(world(clamp.(sev, 0, Inf)); seed)), CLEAN; growth = GROWTH, harm = HARM)
        per[seed] = [m.margin; collect(values(m.slacks))]
        m.margin
    end
    (outputs = vec(mean(reduce(hcat, [per[s] for s in r.seeds]); dims = 2)), n = r.n)
end
mrng = Xoshiro(20261030)
mbudget = (sobol = parse(Int, get(ENV, "BF_SOBOL", "16")), active = parse(Int, get(ENV, "BF_ACTIVE", "40")),
           top = parse(Float64, get(ENV, "BF_SOBOL_TOP", "1.0")))
if mbudget.sobol > 0 || mbudget.active > 0
    t1 = time()
    pool = bt.screen_scale .* gaussian_hypercube(mrng, 2000, length(names); μ = 0.5, σ = 0.25)
    m = battery_methods(reading, names; rng = mrng, outputs = OUTPUTS, pool, sobol_n = mbudget.sobol, sobol_top = mbudget.top,
                        active_budget = mbudget.active)
    write_methods("economy", m, names; reading_note = "Readings: the success pattern's continuous margin (each criterion scaled so the clean world reads 1 and the criterion's edge 0; the margin is the weakest) and each criterion's slack, averaged over seeds 1, 2, … until the margin's standard error (Student-t inflated) is within $SE_TOL ($SEED_MIN to $SEED_MAX seeds).",
                  screen_fail_rate = bt.screening.fail_rate, minutes = (time() - t1) / 60, dir = OUT)
end
