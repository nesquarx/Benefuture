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
