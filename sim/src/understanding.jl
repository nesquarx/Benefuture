# Understanding defined by its equation over hidden traits (proposal 8.98; pseudocode L31).
# A being's true pragmatic understanding of a thing is the equation (Lean `pragmatic_understanding_ref`)
# on its hidden traits; its measured understanding is the same equation on what can be observed: a finite
# record of scored predictions, audited claims of causal explanation, its model's description, and a noisy
# reading of map fit. Measurement error is the gap. Toy stage: one thing, fixed items, no learning.

"""
Hidden traits of a being's model of one thing, per item i (a situation-outcome pair that matters):
`wt` P(X|T)·P(i|T,X)·Impact(i); `q` the true probability of the outcome; `acuity` the spread of the
being's credence about `q` (lower knows better); `ce` causal explanation; `cy` complexity; and the map fit.
"""
struct UTraits
    map_fit::Float64
    wt::Vector{Float64}
    q::Vector{Float64}
    acuity::Vector{Float64}
    ce::Vector{Float64}
    cy::Vector{Float64}
end

# The being's honest credence on one event; an overconfident report extremises it (k > 1).
credence_draw(rng, q, s) = clamp(q + s * randn(rng), 0.01, 0.99)
extremise(c, k) = c^k / (c^k + (1 - c)^k)

"""
    understanding_truth_and_measure(tr, rng; n_records, extremise_k = 1.0, overclaim = 0.0,
                                    audit_rate = 1.0, σ_audit = 0.05, σ_map = 0.05, n_truth = 4000, th = 0.0)

True understanding: the equation on the hidden traits, with each item's accuracy the being's expected
accuracy net of irreducible uncertainty (8.103) on its honest credences (estimated on `n_truth` events, the limit of a long record).
Measured: the equation on outputs: accuracy from `n_records` scored reports per item (reports extremised by
`extremise_k`, the overconfidence gaming); causal explanation as claimed (true + `overclaim`) unless the
item is audited (probability `audit_rate`, reading true + noise `σ_audit`); complexity exactly (the model's
description is an output); map fit with noise `σ_map`. Returns `(truth, measured)`.
"""
function understanding_truth_and_measure(tr::UTraits, rng; n_records::Integer, extremise_k::Real = 1.0,
                                         overclaim::Real = 0.0, audit_rate::Real = 1.0, σ_audit::Real = 0.05,
                                         σ_map::Real = 0.05, n_truth::Integer = 4000, th::Real = 0.0)
    check(n_records >= 1 && extremise_k >= 1 && 0 <= audit_rate <= 1 && σ_audit >= 0 && σ_map >= 0, "valid measurement settings")
    m = length(tr.wt)
    acc_true = zeros(m); acc_meas = zeros(m); ce_meas = zeros(m)
    for i in 1:m
        c = [credence_draw(rng, tr.q[i], tr.acuity[i]) for _ in 1:n_truth]
        o = [Float64(rand(rng) < tr.q[i]) for _ in 1:n_truth]
        acc_true[i] = relative_accuracy(c, o)   # net of irreducible uncertainty (8.103)
        cr = [extremise(credence_draw(rng, tr.q[i], tr.acuity[i]), extremise_k) for _ in 1:n_records]
        orr = [Float64(rand(rng) < tr.q[i]) for _ in 1:n_records]
        acc_meas[i] = relative_accuracy(cr, orr)
        ce_meas[i] = rand(rng) < audit_rate ? clamp(tr.ce[i] + σ_audit * randn(rng), 0, 1) : clamp(tr.ce[i] + overclaim, 0, 1)
    end
    truth = pragmatic_understanding(tr.map_fit, tr.wt, tr.ce, acc_true, tr.cy; th = th)
    measured = pragmatic_understanding(clamp(tr.map_fit + σ_map * randn(rng), 0, 1), tr.wt, ce_meas, acc_meas, tr.cy; th = th)
    (truth = truth, measured = measured)
end

"A random being's traits for one thing with `m` items (world draw for probes)."
function random_utraits(rng, m::Integer)
    w = rand(rng, m); w ./= sum(w)
    UTraits(0.5 + 0.4 * rand(rng), w, 0.1 .+ 0.8 .* rand(rng, m), 0.02 .+ 0.2 .* rand(rng, m),
            0.3 .+ 0.6 .* rand(rng, m), 0.4 .* rand(rng, m))
end

"""
    understanding_ratios(traits, rng; kw...) -> Vector

Each being's measured over true understanding (8.98), for M7's measured view (`run_m7(...; claim_ratio)`):
the keywords are those of `understanding_truth_and_measure`, and `overclaim` may be one value per being.
"""
function understanding_ratios(traits::AbstractVector{UTraits}, rng; overclaim = 0.0, kw...)
    oc = overclaim isa AbstractVector ? overclaim : fill(Float64(overclaim), length(traits))
    [(r = understanding_truth_and_measure(t, rng; overclaim = oc[b], kw...); r.truth > 0 ? r.measured / r.truth : 1.0) for (b, t) in enumerate(traits)]
end

# --- M7 traits mode: understanding as its equation (8.98, ruling 8.109) ---------------------------------
# Each being holds, per item of one thing, a model (the base spread of its credences and its complexity,
# a bundle that is taught whole), a causal explanation, and practice (sharpening its own acuity, never
# taught). Its understanding is the pragmatic equation (Lean `pragmatic_understanding_ref`) on these,
# with each item's accuracy the expected accuracy net of irreducible uncertainty, 1 − s_eff²/0.25, where
# s_eff = base spread × exp(−practice). Toy stage: one thing, fixed weights, happiness not modelled,
# entities choose by a noisy view of predicted gains rather than the full Lean G.

"Expected accuracy net of irreducible uncertainty for credence spread `s` (8.103): 1 − s²/0.25, floored at 0."
expected_relative_accuracy(s) = max(0.0, 1 - s^2 / 0.25)

# Gamma(k, 1) draw (Marsaglia–Tsang; k < 1 by the boost U^(1/k)), for Beta-distributed dispositions without a dependency.
function _gamma(rng, k::Real)
    k < 1 && return _gamma(rng, k + 1) * rand(rng)^(1 / k)
    d = k - 1 / 3; c = 1 / sqrt(9d)
    while true
        x = randn(rng); v = (1 + c * x)^3
        v > 0 && log(rand(rng)) < x^2 / 2 + d - d * v + d * log(v) && return d * v
    end
end

"""
    run_m7_traits(; n, m, steps, seed, ε, practice_gain, research_share, p_research, p_teachable,
                  p_act, class, view_σ, reception_σ) -> NamedTuple

Teaching (one to many) moves each learner, item by item, to the teacher's teachable model bundle when it
is better than its own (with chance ε × reception), and its explanation toward the teacher's; practice
lowers one item's effective spread; research may find a better bundle on one item (lower spread or lower
complexity, a breakthrough) and deeper explanation, teachable with chance `p_teachable`, else tacit.
Records the floor (10th percentile), median and peak of understanding, and every bundle that ever
existed (`bundles`), so crossed wires can be checked.
"""
function run_m7_traits(; n::Integer = 60, m::Integer = 5, steps::Integer = 120, seed::Integer = 1, ε::Real = 0.3,
                       practice_gain::Real = 0.02, research_share::Real = 0.1, p_research::Real = 0.05,
                       p_teachable::Real = 0.5, p_act::Real = 0.3, class::Integer = 5, view_σ::Real = 0.02,
                       reception_σ::Real = 0.5, breakthrough::Real = 0.3, overclaim = 0.0, reports::Bool = false,
                       report_z::Real = 3.0, report_min::Integer = 5, things = [1.0], max_new_things::Integer = 0,
                       p_new_thing::Real = 0.0, novelty_weight::Real = 0.2,
                       weight_σ::Real = 0.0, meta_research::Real = 0.0, per_being::Bool = false, meta_share::Real = 0.0, weight_shared::Real = 0.0, meta_domain::Bool = false, meta_uptake::Real = 0.3, uptake_conc::Real = 1.5, uptake_σ::Real = 1.0, meta_noise::Real = 0.0, meta_meas_σ::Real = 0.0, meta_th::Real = 1.0)
    check(!isempty(things) && all(>=(0), things) && max_new_things >= 0 && 0 <= p_new_thing <= 1 && novelty_weight >= 0, "valid things")
    check(n >= 2 && m >= 1 && steps >= 1 && 0 <= ε <= 1 && practice_gain >= 0 && 0 <= research_share < 1 &&
          0 <= p_research <= 1 && 0 <= p_teachable <= 1 && 0 <= p_act <= 1 && class >= 1 && view_σ >= 0, "valid traits world")
    rng = Xoshiro(seed); rrng = Xoshiro(hash((seed, :research))); vrng = Xoshiro(hash((seed, :views)))
    # Things (ruling 8.117): understanding aggregates across things by their priority (their predicted
    # long-term contribution to the goals), each thing's pragmatic understanding weighted by it; research may
    # open a new thing (a slot of `m` items, held at low traits), weighted for novelty.
    mt = m                                         # items per thing
    T = length(things) + max_new_things
    W = vcat(Float64.(things), fill(Float64(novelty_weight), max_new_things))
    active = vcat(trues(length(things)), falses(max_new_things))
    m = mt * T
    thing_of = [cld(i, mt) for i in 1:m]
    wl = rand(rng, m); for t in 1:T; r = ((t - 1) * mt + 1):(t * mt); wl[r] ./= sum(wl[r]); end
    # Priority weights as meta understanding (8.131 continued): society steers practice, research and lessons by its
    # estimate of each thing's contribution to the goals (log-normal error `weight_σ`, own stream); meta-level research
    # (chance `meta_research` per step) halves the estimate's log-error. Understanding is still measured on the truth.
    wrng = Xoshiro(hash((seed, :weights))); werr = weight_σ .* randn(wrng, length(W))
    gw() = [active[thing_of[i]] ? W[thing_of[i]] * exp(werr[thing_of[i]]) * wl[i] : 0.0 for i in 1:m]   # each item's estimated weight toward the goals now
    # Per-being estimates (8.131 continued): each being steers by its own estimate; a researcher spends a share
    # `meta_share` of its research on the priorities (halving its own estimate's error and passing it to one other
    # being) instead of on objects, so meta-research competes for effort.
    # `weight_shared` is the share of variance common to all beings (a culture's shared misjudgement of priorities).
    werrb = per_being ? weight_σ .* (sqrt(weight_shared) .* repeat(randn(wrng, 1, length(W)), n) .+ sqrt(1 - weight_shared) .* randn(wrng, n, length(W))) : zeros(0, 0)
    gwb(e) = per_being ? [active[thing_of[i]] ? W[thing_of[i]] * exp(werrb[e, thing_of[i]]) * wl[i] : 0.0 for i in 1:m] : wt
    # Meta-research as its own domain (8.132): its outcomes publish a policy-level estimate of priorities (`pol`, the
    # log-errors the published record still carries, starting as the beings' mean); each step a being takes the published
    # estimate partly (`meta_uptake` of the gap: education, never ideal), so individual and policy priorities improve together.
    # Uptake (8.132, author): heavy noise, an outcome of each being's disposition and moment, never governed. Dispositions
    # are Beta with mean `meta_uptake` and concentration `uptake_conc` (low: wide spread); each step adds log-normal noise.
    urng = Xoshiro(hash((seed, :uptake))); mrng = Xoshiro(hash((seed, :meta)))
    meta_rec = Tuple{Float64, Float64}[]; meta_adopt = Ref(0); meta_wrong = Ref(0)
    upk = [begin x = _gamma(urng, meta_uptake * uptake_conc); x / (x + _gamma(urng, (1 - meta_uptake) * uptake_conc)) end for _ in 1:n]
    pol = per_being && meta_domain ? vec(sum(werrb, dims = 1)) ./ n : Float64[]
    gwp() = [active[thing_of[i]] ? W[thing_of[i]] * exp(pol[thing_of[i]]) * wl[i] : 0.0 for i in 1:m]   # items' weights under the published priorities
    wt = gw()
    ms = 0.1 .+ 0.35 .* rand(rng, n, m)          # base spread of each being's model, per item
    mc = 0.1 .+ 0.6 .* rand(rng, n, m)           # its complexity
    ce = 0.2 .+ 0.5 .* rand(rng, n, m)           # causal explanation
    for i in 1:m; active[thing_of[i]] || (ms[:, i] .= 0.45; mc[:, i] .= 0.7; ce[:, i] .= 0.05); end
    ts, tc, tce = copy(ms), copy(mc), copy(ce)    # the teachable parts (research gains may be tacit)
    pr = zeros(n, m)                              # practice
    # Measured view (8.104 in this world): a being's claimed explanation is its own plus `overclaim`
    # until a founded report audits it (8.105: learners' shortfalls against everyone's).
    oc = overclaim isa AbstractVector ? collect(Float64, overclaim) : fill(Float64(overclaim), n)
    audited = falses(n); shortfall = [Float64[] for _ in 1:n]; audits = Ref(0)
    claimed(b, i) = audited[b] ? tce[b, i] : min(1.0, tce[b, i] + oc[b])
    bundles = Set{Tuple{Float64,Float64}}((ms[b, i], mc[b, i]) for b in 1:n, i in 1:m)
    agg(cev, b) = sum((W[t] * pragmatic_understanding(1.0, wl[r], cev[r], [expected_relative_accuracy(ms[b, i] * exp(-pr[b, i])) for i in r], mc[b, r])
                       for t in 1:T if active[t] for r in (((t - 1) * mt + 1):(t * mt),)); init = 0.0)
    Um(b) = agg([audited[b] ? ce[b, i] : min(1.0, ce[b, i] + oc[b]) for i in 1:m], b)
    U(b) = agg(ce[b, :], b)
    bval(s, c) = expected_relative_accuracy(s) * (1 - c)   # a bundle's worth, before practice
    tr = (floor_u = Float64[], median_u = Float64[], peak_u = Float64[], mean_cy = Float64[], lessons = Ref(0), breakthroughs = Ref(0), new_things = Ref(0))
    rec!() = (u = [U(b) for b in 1:n]; push!(tr.floor_u, floor_quantile(u, 0.1)); push!(tr.median_u, median(u));
              push!(tr.peak_u, maximum(u)); push!(tr.mean_cy, mean(mc)))
    thing_u(b, t) = (r = ((t - 1) * mt + 1):(t * mt); pragmatic_understanding(1.0, wl[r], ce[b, r], [expected_relative_accuracy(ms[b, i] * exp(-pr[b, i])) for i in r], mc[b, r]))
    thing_u0 = [mean(thing_u(b, t) for b in 1:n) for t in 1:T]
    rec!()
    for _ in 1:steps
        u = [U(b) for b in 1:n]
        if meta_research > 0 && rand(wrng) < meta_research   # meta-level research sharpens the estimate of priorities
            werr .*= 0.5; wt .= gw()
        end
        researching = rand(rrng, n) .< research_share
        if per_being && meta_domain
            for b in 1:n          # uptake is an outcome, not a rule: each being's own disposition, noisy every step
                u = clamp(upk[b] * exp(uptake_σ * randn(urng) - uptake_σ^2 / 2), 0.0, 1.0)
                werrb[b, :] .+= u .* (pol .- werrb[b, :])
            end
        end
        for b in findall(researching)
            if per_being && rand(wrng) < meta_share
                if meta_domain
                    # The meta domain is a leaf with its own record (8.132): an outcome is a noisy proposal (`meta_noise`),
                    # its gain measured with error (`meta_meas_σ`); the published priorities adopt it only past the
                    # significance bar (`meta_th` measurement errors, L48), as any leaf's claim would be.
                    prop = pol .* 0.5 .+ meta_noise .* randn(mrng, length(pol))
                    gain = sum(abs, pol) - sum(abs, prop); seen = gain + meta_meas_σ * randn(mrng)
                    push!(meta_rec, (gain, seen))
                    if meta_meas_σ == 0 || seen > meta_th * meta_meas_σ
                        pol .= prop; meta_adopt[] += 1; gain < 0 && (meta_wrong[] += 1)
                    end
                else
                    werrb[b, :] .*= 0.5; o = rand(wrng, 1:n); werrb[o, :] .= werrb[b, :]
                end
                continue
            end
            rand(rrng) < p_research || continue
            if p_new_thing > 0 && !all(active) && rand(rrng) < p_new_thing
                t = findfirst(!, active); active[t] = true; wt .= gw()   # a new thing opens (novelty weight)
                i = (t - 1) * mt + rand(rrng, 1:mt); tr.new_things[] += 1
            else
                wb = meta_domain && per_being ? gwp() : gwb(b); i = pick(rrng, wb ./ sum(wb))   # with a meta domain, research funding follows the published (policy) priorities        # research goes where it counts toward the goals (8.117), as the researcher sees it
            end
            s2, c2 = rand(rrng) < 0.5 ? (ms[b, i] * (1 - breakthrough), mc[b, i]) : (ms[b, i], mc[b, i] * (1 - breakthrough))
            ms[b, i], mc[b, i] = s2, c2; push!(bundles, (s2, c2))
            ce[b, i] += breakthrough * (1 - ce[b, i])
            tr.breakthroughs[] += 1
            if rand(rrng) < p_teachable
                ts[b, i], tc[b, i], tce[b, i] = s2, c2, ce[b, i]
            end
        end
        for e in 1:n
            (researching[e] || rand(rng) >= p_act) && continue
            we = gwb(e)
            view = [Um(b) for b in 1:n] .+ view_σ .* randn(vrng, n)
            below = [b for b in 1:n if b != e && view[b] < view[e]]
            # Predicted gain of a lesson to a class against practising one item oneself (on the view).
            learners = isempty(below) ? Int[] : below[randperm(rng, length(below))[1:min(class, length(below))]]
            lesson_gain = sum((sum(we[i] * (max(0.0, bval(ts[e, i], tc[e, i]) - bval(ms[l, i], mc[l, i])) * ce[l, i] +
                                        max(0.0, claimed(e, i) - ce[l, i]) * bval(ms[l, i], mc[l, i])) for i in 1:m) for l in learners); init = 0.0) * ε   # models and (claimed) explanation both
            # practice's predicted gain: the equation's change from sharpening one's best item
            practice_gain_pred = maximum(we[i] * ce[e, i] * (1 - mc[e, i]) * (expected_relative_accuracy(ms[e, i] * exp(-pr[e, i] - practice_gain)) - expected_relative_accuracy(ms[e, i] * exp(-pr[e, i]))) for i in 1:m)
            if lesson_gain > practice_gain_pred
                tr.lessons[] += 1
                for l in learners
                    r = exp(reception_σ * randn(rng) - reception_σ^2 / 2)
                    pred = sum(we[i] * min(1.0, ε * r) * max(0.0, claimed(e, i) - ce[l, i]) for i in 1:m)
                    real = sum(we[i] * min(1.0, ε * r) * max(0.0, tce[e, i] - ce[l, i]) for i in 1:m)
                    reports && push!(shortfall[e], pred - real)
                    for i in 1:m
                        if bval(ts[e, i], tc[e, i]) > bval(ms[l, i], mc[l, i]) && rand(rng) < min(1.0, ε * r)
                            ms[l, i], mc[l, i] = ts[e, i], tc[e, i]          # the model, taught whole (8.109)
                            ts[l, i], tc[l, i] = ts[e, i], tc[e, i]
                        end
                        ce[l, i] += min(1.0, ε * r) * max(0.0, tce[e, i] - ce[l, i]); tce[l, i] = max(tce[l, i], ce[l, i])
                    end
                end
            else
                # practice: one's own acuity, never taught, on the item where it adds most toward the goals (8.117)
                i = argmax([we[k] * ce[e, k] * (1 - mc[e, k]) * (expected_relative_accuracy(ms[e, k] * exp(-pr[e, k] - practice_gain)) - expected_relative_accuracy(ms[e, k] * exp(-pr[e, k]))) for k in 1:m])
                pr[e, i] += practice_gain
            end
        end
        if reports
            for e in 1:n
                x = shortfall[e]; (audited[e] || length(x) < report_min) && continue
                rest = vcat((shortfall[k] for k in 1:n if k != e)...); length(rest) >= 2 || continue
                z = (mean(x) - mean(rest)) / sqrt(var(x) / length(x) + var(rest) / length(rest) + 1e-24)
                z > report_z && (audited[e] = true; audits[] += 1)
            end
        end
        rec!()
    end
    (; tr..., audits = audits[], audited = copy(audited), lessons = tr.lessons[], breakthroughs = tr.breakthroughs[], new_things = tr.new_things[], thing_gain = [mean(thing_u(b, t) for b in 1:n) for t in 1:T] .- thing_u0, bundles = bundles,
       final_bundles = [(ms[b, i], mc[b, i]) for b in 1:n, i in 1:m], practice = pr,
       meta_record = meta_rec, meta_adopted = meta_adopt[], meta_wrong = meta_wrong[])
end
