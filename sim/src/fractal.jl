# ---- The unified world, phase B: fractal governance and economy per emergent cluster (author ruling 8.174, 8.50, 8.150, 8.42.3) ----
#
# Every cluster at every level of the nested hierarchy read from measured interaction (phase A, `cluster_hierarchy`) is an entity running
# the same rules: it decides the decisions whose impact lies within it (the Lean subsidiarity rule `deciding_scope`, on the impact measured
# per cluster), from its own noisy view of the decision (8.50: each member reads it with its own error, the cluster tallies the readings
# weighted by the impact each member bears), spends from its own reserve (one currency; a child's allowance is a share of its parent's, so
# a cluster cannot spend beyond its parent's bound), and, for decisions whose impact is uncertain, its sibling clusters are offered a novelty
# bonus (the M5 rule, 8.42.3: depart when your own reading comes within the bonus less the conviction margin of the alternative) scaled by the
# Lean `divergence_weight` (rises with uncertainty, falls with severity). Outcomes are measured per cluster and recorded per decision class;
# when the records settle the comparison (Lean `select_candidate` at z, on the contrast between options tried in the same period, which
# cancels the period's shock, or on each option against the known baseline) every cluster converges on the better option.
# Glue and world model only: the rules (scope, divergence weight, significance) are Lean calls; the tally is a sum of readings.
# Toy assumptions named: hard partitions (overlapping membership is supported by impact weights, not yet emergent), one decision class
# per decision, a common period shock that confounds comparisons across time, a shared misconception `bias` per class (8.42.3 monoculture),
# reserves that grow and shrink by outcomes at a fixed `mint_rate`.

# using Random, Statistics provided selectively by BenefutureSim

"""
    FractalParams

World (decisions): `decisions` over `classes` recurring classes (round-robin), each class with a `severity` (the harm scale: the right
option gains it, the wrong option loses it), a shared `bias` of the society's view (the consensus reads the truth times 1 + bias; a wrong
consensus has bias below -1), the members' `view_σ` (noise of each member's reading, relative), `spill`
(the share of a decision's impact that falls outside its origin cluster), `shock_σ` (a period's common shock to outcomes, relative),
`obs_σ` (a member's measurement noise, relative). Governed thresholds: `share_min` (subsidiarity), `bonus_max` and `conviction` (novelty
bonus and the margin a cluster's own reading must come within), `severity_slope`, `trial_z`, `budget_frac` (the share of a parent's reserve
delegated to its children, so the sum of children stays within the parent), `min_records`. World: `reserve` (the root's currency),
`mint_rate` (currency minted per unit of positive outcome, burnt per unit of negative).
"""
Base.@kwdef struct FractalParams
    decisions::Int = 60
    severity::Vector{Float64} = [0.2, 0.2, 0.2]
    bias::Vector{Float64} = [-1.4, 0.0, -1.4]
    view_σ::Float64 = 0.8
    spill::Float64 = 0.6
    shock_σ::Float64 = 1.0
    obs_σ::Float64 = 1.0
    share_min::Float64 = 0.8
    bonus_max::Float64 = 1.5
    conviction::Float64 = 0.5
    severity_slope::Float64 = 2.0
    trial_z::Float64 = 2.0
    budget_frac::Float64 = 0.5
    min_records::Int = 3
    reserve::Float64 = 200.0
    mint_rate::Float64 = 0.2
    divergent::Bool = true       # false: the society decides every decision as one (the limiting case, phase A's single choice)
    scoped::Bool = true          # false: every decision goes to the root
    origin::Union{Nothing,Int} = nothing   # fixed origin member (tests); otherwise drawn per decision
end

"The world's draws, one set per seed, shared by every arm (common random numbers): truth of each class, origins, period shocks, readings, outcome noise."
function fractal_world(n::Integer, p::FractalParams; seed::Integer)
    rng = det_rng(seed, :fractal_world)
    K = length(p.severity)
    (τ = [rand(rng) < 0.5 ? 1 : -1 for _ in 1:K], origin = [rand(rng, 1:n) for _ in 1:p.decisions], shock = randn(rng, p.decisions),
     eps = randn(rng, p.decisions, n), eta = randn(rng, p.decisions, n), order = [randperm(rng, 64) for _ in 1:p.decisions])
end

"What a class's records say: +1 or -1 when one option is significantly the better (Lean `select_candidate` at `z`), 0 while unsettled."
function fractal_verdict(paired::Vector{Float64}, absolute::Dict{Int,Vector{Float64}}; z::Real, min_records::Integer)
    se(x) = length(x) < 2 ? 1e12 : max(std(x), 1e-9) / sqrt(length(x))
    better(xm, xs, ym, ys, k) = select_candidate([ym, xm], [ys, xs]; z = z * t_inflation(k - 1)) == 2   # Student-t inflated for few records, as `paired_effect`
    if length(paired) >= min_records   # contrast, option +1 minus option -1, on decisions where both were tried in the same period
        m, s = mean(paired), se(paired)
        better(m, s, 0.0, 0.0, length(paired)) && return 1
        better(-m, s, 0.0, 0.0, length(paired)) && return -1
    end
    for o in (1, -1)   # each option against the known baseline (the value of staying put is zero), confounded by the period's shock
        x = absolute[o]; length(x) >= min_records || continue
        better(mean(x), se(x), 0.0, 0.0, length(x)) && return o
        better(-mean(x), se(x), 0.0, 0.0, length(x)) && return -o
    end
    0
end

"""
    run_fractal(levels, p; seed = 1, world = nothing) -> NamedTuple

Run `p.decisions` decisions on the nested `levels` (finest first; the labels of `cluster_levels`, or `cluster_hierarchy(...).partitions`
entries; the all-in-one root is appended when absent). Returns per decision the deciding level and cluster, the measured spillover,
uncertainty, divergence weight, the clusters that departed, the verdict; the clusters' reserves; the per-being outcomes (`welfare`,
`harm_peak` the deepest single-being drawdown, `floor`, `median`); the ledger (`minted`, `burnt`, `balances`) and `degraded` entries.
"""
function run_fractal(levels, p::FractalParams; seed::Integer = 1, world = nothing)
    labs = [collect(Int, l isa NamedTuple ? l.labels : l) for l in levels]
    n = length(labs[1]); check(all(l -> length(l) == n, labs), "fractal: every level labels the same members")
    maximum(labs[end]) == 1 && minimum(labs[end]) == 1 || push!(labs, ones(Int, n))   # the root
    L = length(labs)
    K = length(p.severity)
    check(K >= 1 && length(p.bias) == K && p.decisions >= 1 && 0 <= p.budget_frac <= 1 && 0 <= p.spill <= 1, "fractal: parameters")
    W = world === nothing ? fractal_world(n, p; seed) : world
    members(l, c) = findall(==(c), labs[l])
    # the account tree (one currency): a node is (level, label); the root holds the reserve and delegates `budget_frac` of its balance, by size share, to each child
    bal = Dict{Tuple{Int,Int},Float64}(); alloc = Dict{Tuple{Int,Int},Float64}(); parent = Dict{Tuple{Int,Int},Tuple{Int,Int}}()
    for l in 1:L, c in unique(labs[l]); bal[(l, c)] = 0.0; end
    bal[(L, 1)] = p.reserve; alloc[(L, 1)] = p.reserve
    for l in (L - 1):-1:1, c in unique(labs[l])
        m = members(l, c); pc = labs[l + 1][m[1]]; pn = (l + 1, pc)
        parent[(l, c)] = pn
        a = p.budget_frac * (length(m) / count(==(pc), labs[l + 1])) * alloc[pn]
        alloc[(l, c)] = a; bal[(l, c)] = a; bal[pn] -= a
    end
    minted = 0.0; burnt = 0.0; spent = Dict(k => 0.0 for k in keys(bal)); degraded = NamedTuple[]
    hist = [Dict(1 => Float64[], -1 => Float64[]) for _ in 1:K]; paired = [Float64[] for _ in 1:K]
    cum = zeros(n); peak = zeros(n); drawdown = zeros(n); welfare_total = 0.0
    decs = NamedTuple[]
    for t in 1:p.decisions
        c = 1 + (t - 1) % K; m_c = p.severity[c]; τ = W.τ[c]
        o = p.origin === nothing ? W.origin[t] : p.origin
        # measured impact per member: the origin's finest cluster bears 1 - spill, the rest share the spillover
        home = members(1, labs[1][o]); a = fill(p.spill / max(1, n - length(home)), n); a[home] .= (1 - p.spill) / length(home)
        length(home) == n && (a .= 1 / n)
        shares = [sum(a[members(l, labs[l][o])]) for l in 1:L]
        lvl = p.scoped ? deciding_scope(shares, trues(L); share_min = p.share_min) : L
        dnode = (lvl, labs[lvl][o]); D = members(lvl, labs[lvl][o])
        reading = [m_c * (τ * (1 + p.bias[c]) + p.view_σ * W.eps[t, i]) for i in 1:n]   # each member's own noisy view
        verdict = fractal_verdict(paired[c], hist[c]; z = p.trial_z, min_records = p.min_records)
        aD = a[D]; sD = sum(aD)
        wD = sD > 0 ? aD ./ sD : fill(1 / length(D), length(D))
        d = verdict != 0 ? verdict : (sum(wD .* reading[D]) >= 0 ? 1 : -1)   # the cluster's own tally, impact-weighted within it
        pos = sum(wD[reading[D] .> 0]); u = verdict != 0 ? 0.0 : 2 * min(pos, 1 - pos)   # measured disagreement; settled records leave nothing to learn
        w = (p.divergent && lvl > 1) ? divergence_weight(u, m_c; severity_slope = p.severity_slope) : 0.0
        opt = fill(d, n); departed = Int[]
        if w > 0
            b = w * p.bonus_max
            kids = unique(labs[lvl - 1][D])
            for k in kids[sortperm(W.order[t][1:length(kids)])]
                mk = members(lvl - 1, k); mk = [i for i in mk if i in D]; ak = a[mk]; sum(ak) > 0 || continue
                rk = sum(ak .* reading[mk]) / sum(ak) / m_c              # the sibling's own view, in units of severity
                d * rk < b - p.conviction || continue
                pay = b * m_c * length(mk); kn = (lvl - 1, k)
                if bal[dnode] < pay                                       # the parent's reserve is the bound: no departure it cannot subsidise
                    push!(degraded, (step = t, mechanism = :novelty_bonus, substitute = :no_departure, reason = :reserve_exhausted, cluster = dnode))
                    continue
                end
                bal[dnode] -= pay; bal[kn] += pay; spent[dnode] += pay
                opt[mk] .= -d; push!(departed, k)
            end
        end
        # outcomes: per-being realised value (impact intensity times the option's value), observed with the period's shock and noise
        val = [n * a[i] * opt[i] * τ * m_c for i in 1:n]
        obs(i) = opt[i] * τ * m_c + m_c * p.shock_σ * W.shock[t] + m_c * p.obs_σ * W.eta[t, i]
        taken = Dict(1 => findall(==(1), opt), -1 => findall(==(-1), opt))
        obsmean = Dict(o2 => (isempty(taken[o2]) ? NaN : mean(obs(i) for i in taken[o2])) for o2 in (1, -1))
        for o2 in (1, -1); isnan(obsmean[o2]) || push!(hist[c][o2], obsmean[o2] / m_c); end
        isnan(obsmean[1]) || isnan(obsmean[-1]) || push!(paired[c], (obsmean[1] - obsmean[-1]) / m_c)
        for i in 1:n; cum[i] += val[i]; peak[i] = max(peak[i], cum[i]); drawdown[i] = max(drawdown[i], peak[i] - cum[i]); end
        welfare_total += sum(val) / n
        # the clusters' reserves follow the outcomes they bear: positive outcomes mint, negative burn (capped at the balance, loudly)
        for c1 in unique(labs[1])
            v = p.mint_rate * sum(val[members(1, c1)]); kn = (1, c1)
            if v >= 0; bal[kn] += v; minted += v
            else
                cut = min(-v, bal[kn]); bal[kn] -= cut; burnt += cut
                cut < -v && push!(degraded, (step = t, mechanism = :outcome_burn, substitute = :burn_to_balance, reason = :balance_exhausted, cluster = kn))
            end
        end
        push!(decs, (t = t, class = c, level = lvl, cluster = dnode, origin = o, spillover = 1 - shares[1], impact_in_scope = shares[lvl], uncertainty = u,
                     weight = w, departed = departed, option = d, verdict = verdict, right = d == τ, share_departed = count(==(-d), opt) / n,
                     harm_share = count(i -> opt[i] != τ, 1:n) / n))
    end
    sorted = sort(cum)
    (decisions = decs, levels = labs, balances = bal, allocations = alloc, parents = parent, spent = spent, minted = minted, burnt = burnt, reserve = p.reserve,
     degraded = degraded, welfare = welfare_total, per_being = cum, harm_peak = maximum(drawdown), floor = minimum(cum), median = median(cum),
     right_share = mean(d.right for d in decs), world = W)
end

"The last epoch's nested clusters of a unified run (`run_coupled(...; unified = UnifiedParams())`), as the levels `run_fractal` takes (finest first)."
unified_fractal_levels(report) = [l.labels for l in report.epochs[end].levels]

"Phase B on a unified run's last measured clusters: the fractal decisions on the trust network's emergent hierarchy."
unified_fractal(report, p::FractalParams = FractalParams(); seed::Integer = 1) = run_fractal(unified_fractal_levels(report), p; seed)
