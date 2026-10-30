# Adversarial attack search: attacker strategies, not only severities, optimised by the cross-entropy
# method (sim/src/methods.jl) to drive the Goal's success pattern down. Run:
#   julia --project=sim sim/battery/attack.jl
# Each attacker holds a fixed budget (`BUDGET`: 1 is one attack at the top of its realistic range) and
# chooses how to spend it. A strategy is a point θ in [0, 1]^m decoded below; the search minimises the
# success pattern's margin (`pattern_margin`: 1 the unattacked world, below 0 a failed criterion)
# averaged over fixed seeds (common random numbers), then checks the worst strategy on held-out seeds.
# Worlds are mildly imperfect (default noise, 8.33) with AdvAp on. Every worst case is printed as
# literal parameters to freeze as a deterministic M6 test (sim/test/attack_tests.jl). Evaluation
# tooling, not rules.
using BenefutureSim, Statistics, Random, Printf

const BUDGET = parse(Float64, get(ENV, "BF_ATTACK_BUDGET", "1.0"))
const POP, ITERS = parse(Int, get(ENV, "BF_ATTACK_POP", "8")), parse(Int, get(ENV, "BF_ATTACK_ITERS", "4"))
const OUT = get(ENV, "BF_OUT", joinpath(@__DIR__, "results"))
const GROWTH, HARM, STEPS = 0.25, 3.0, 300
lerp(a, b, t) = a + (b - a) * t
pick(n, t) = 1 + min(n - 1, floor(Int, n * t))
"Largest c in [0, 1] with cost(c) ≤ budget (cost increasing in c)."
function within_budget(cost, budget)
    cost(1.0) <= budget && return 1.0
    lo, hi = 0.0, 1.0
    for _ in 1:40
        mid = (lo + hi) / 2
        cost(mid) <= budget ? (lo = mid) : (hi = mid)
    end
    lo
end

# --- The economy (M3c) ----------------------------------------------------------------------
# θ: bloc size (1–4 of the 8 agents), deceit, laundering, slander (reports whatever the record),
# capture of a leaf's models (size, target leaf, start, total duration, on-off windows at 50% duty).
# Cost: (bloc / 4) × (deceit/2 + laundering + slander) + (capture size / 3) × (duration / 150).
function m3c_strategy(θ)
    b = pick(4, θ[1])
    raw = (deceit = 2θ[2], launder = θ[3], frivolous = θ[4], capture = 3θ[5])
    target, start, dur, windows = pick(4, θ[6]), round(Int, lerp(51, 280, θ[7])), round(Int, lerp(10, 150, θ[8])), pick(4, θ[9])
    cost(c) = b / 4 * c * (raw.deceit / 2 + raw.launder + raw.frivolous) + c * raw.capture / 3 * dur / 150
    c = within_budget(cost, BUDGET)
    w = max(1, dur ÷ windows)
    starts = [start + 2w * (i - 1) for i in 1:windows if start + 2w * (i - 1) <= STEPS]
    (bloc = collect((9 - b):8), deceit = c * raw.deceit, launder = c * raw.launder, frivolous = c * raw.frivolous,
     capture = c * raw.capture, target = target, windows = [(s, min(w, STEPS - s + 1)) for s in starts])
end
function m3c_world(st)
    agents = [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.0) for _ in 1:8]
    per(x) = [i in st.bloc ? x : 0.0 for i in 1:8]
    events = st.capture > 0 ? [shock(:capture; step = s, duration = d, size = st.capture, target = st.target) for (s, d) in st.windows] : Shock[]
    M3cParams(ToyParams(n = 80, steps = STEPS, plans = 10), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
              transactions = true, causal_distribution = true, p_upstream = 0.5, guardians = [1, 2, 3, 4], p_foresee = 1.0,
              repair_efficiency = 0.5, advap = true, deceit = per(st.deceit), launder = per(st.launder), frivolous = per(st.frivolous), events)
end
const NOATTACK = (bloc = Int[], deceit = 0.0, launder = 0.0, frivolous = 0.0, capture = 0.0, target = 1, windows = Tuple{Int,Int}[])
pattern(tr) = success_pattern(tr; from = 51)
const CLEAN_RUNS = Dict(seed => run_m3c(m3c_world(NOATTACK); seed) for seed in [1:3; 11:14])
const CLEAN = let ps = [pattern(CLEAN_RUNS[s]) for s in 1:3]
    (; (f => mean(getfield(p, f) for p in ps) for f in (:floor_u, :floor_h, :median_u, :median_h, :peak_u, :worst_drop))...)
end
"Margin and the bloc's wealth relative to honest agents, over the unattacked run of the same seed."
function m3c_eval(st, seeds)
    rel(t, k) = mean(sum(t.balance[i, :]) for i in k) / mean(sum(t.balance[i, :]) for i in setdiff(1:8, k))
    rs = map(seeds) do seed
        tr = run_m3c(m3c_world(st); seed)
        (margin = pattern_margin(pattern(tr), CLEAN; growth = GROWTH, harm = HARM).margin,
         gain = isempty(st.bloc) ? 1.0 : rel(tr, st.bloc) / rel(CLEAN_RUNS[seed], st.bloc))
    end
    (margin = mean(r.margin for r in rs), gain = mean(r.gain for r in rs), margins = [r.margin for r in rs])
end

# --- Governance (M5) ------------------------------------------------------------------------
# θ: bloc share of each targeted domain's most reputable experts (up to half), a target domain or
# all four, stealth (defect only where outcomes stay hidden), identity forks per member (0–3),
# loyalty (what revealing costs a member in its own eyes, 0–10).
# Cost: share/0.5 × (domains targeted / 4) × (1 + forks/3 + loyalty/10): members are what the budget buys.
const M3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                             [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                              for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
const DECISIONS, ACCURACY = 800, 0.75
topk(d, n) = n == 0 ? Int[] : sortperm(M3.relevance_leaf[:, d]; rev = true)[1:n]
function m5_strategy(θ)
    raw = (share = 0.5θ[1], forks = 3θ[5], loyalty = 10θ[6])
    domains = θ[3] > 0.5 ? collect(1:4) : [pick(4, θ[2])]
    cost(c) = c * raw.share / 0.5 * length(domains) / 4 * (1 + c * raw.forks / 3 + c * raw.loyalty / 10)
    c = within_budget(cost, BUDGET)
    n = round(Int, c * raw.share * 25)
    (colluders = unique(vcat([topk(d, n) for d in domains]...)), domains = domains, stealth = θ[4] > 0.5,
     fork_copies = round(Int, c * raw.forks), loyalty = c * raw.loyalty)
end
function m5_eval(st, seeds)
    accs = map(seeds) do seed
        r = run_m5(M5Params(M3, 1:4; decisions = DECISIONS, advap = true, colluders = st.colluders, stealth = st.stealth,
                            fork_copies = st.fork_copies, loyalty = st.loyalty); seed)
        mean(r.final_trace[(DECISIONS ÷ 2 + 1):end])
    end
    (margin = mean(accs) - ACCURACY, accuracy = mean(accs), accuracies = accs)
end

# --- Search ---------------------------------------------------------------------------------
results = []
for (label, m, decode, evaluate, search_seeds, check_seeds) in
        (("economy (M3c)", 9, m3c_strategy, m3c_eval, 1:2, 11:14), ("governance (M5)", 6, m5_strategy, m5_eval, 1:3, 11:16))
    t0 = time()
    r = cross_entropy_search(θ -> evaluate(decode(θ), search_seeds).margin, m; rng = Xoshiro(20261031), population = POP, iterations = ITERS)
    st = decode(r.θ)
    held = evaluate(st, check_seeds)
    push!(results, (label = label, strategy = st, θ = r.θ, search = r.value, held = held, history = r.history, minutes = (time() - t0) / 60))
    println(label, ": ", st, "\n  search margin ", r.value, "; held-out ", held)
end

mkpath(OUT)
open(joinpath(OUT, "attack.md"), "w") do io
    println(io, "# Adversarial attack search\n")
    println(io, "Build: commit ", current_commit(), " (with any uncommitted changes at the time).\n")
    println(io, "Attacker strategies optimised by the cross-entropy method (population $POP, $ITERS iterations) to minimise ",
            "the success pattern's margin (1: the unattacked world; below 0: a criterion failed), within a budget of ",
            "$BUDGET (one attack at the top of its realistic range). Search on fixed seeds; the worst strategy re-checked on held-out seeds.\n")
    for r in results
        println(io, "## ", r.label, @sprintf(" (%.1f minutes)\n", r.minutes))
        println(io, "Worst strategy: `", r.strategy, "`.\n")
        println(io, @sprintf("Margin on the search seeds %.3f; on held-out seeds %.3f (per seed: %s).",
                             r.search, r.held.margin, join([@sprintf("%.2f", x) for x in (hasproperty(r.held, :margins) ? r.held.margins : r.held.accuracies)], ", ")),
                hasproperty(r.held, :gain) ? @sprintf(" Bloc's wealth relative to honest agents, over the unattacked run: %.2f.", r.held.gain) : "",
                r.held.margin < 0 ? " **The framework fails this attack.**" : " The framework holds.")
        println(io, "\nBest margin by iteration: ", join([@sprintf("%.3f", h.best) for h in r.history], ", "), ".\n")
    end
end
