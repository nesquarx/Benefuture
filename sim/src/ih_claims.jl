# ---- IH world, step 2a (WORLD_COVERAGE step 2; author rulings 8.167a, 8.168) ----

"""
    ih_truth_level(outputs, weights, mem_score, provable, cap_unprovable) -> Float64

Truth level from the information-handling categoriser (`L134` `Categorize`; Lean `ih_truth_level_ref`).
Provable claims: consensus of experts' outputs weighted by record, scaled by the class's `Mem` score.
Unprovable claims: the same, capped at `cap_unprovable`. Always within [0.01, 0.99].
"""
function ih_truth_level(outputs, weights, mem_score::Real, provable::Bool, cap_unprovable::Real)
    check(length(outputs) == length(weights) && all(isfinite, outputs) && all(isfinite, weights) &&
          isfinite(mem_score) && isfinite(cap_unprovable), "finite outputs, weights, mem_score and cap")
    ccall(sym(:bf_ih_truth_level), Float64, (Ptr{Cvoid}, Ptr{Cvoid}, Float64, UInt8, Float64),
          floatarray(outputs), floatarray(weights), Float64(mem_score), UInt8(provable ? 1 : 0), Float64(cap_unprovable))
end

Base.@kwdef struct IhClaimsParams
    experts::Int = 8
    steps::Int = 30
    claims_per_step::Int = 4
    frac_provable::Float64 = 0.5
    classifier::Bool = true              # false: every claim is treated as provable, no record (the unhandled control)
    cap_unprovable::Float64 = 0.35       # governed threshold
    expert_σ::Float64 = 0.15             # noise of an expert's output (own stream)
    frac_biased::Float64 = 1 / 3         # share of experts following the shared bias even on checkable claims
    bias_strength::Float64 = 0.8         # shared bias on claims nobody can check (echo / ideology)
    infra_step::Int = 0                  # > 0: at this step unprovable claims become provable (8.168)
    seed::Int = 1
end

"""
    run_ih_claims(p::IhClaimsParams)

One population of experts over a stream of claims. A provable claim has a checkable outcome (side `t = ±1`) that
records learn from; an unprovable claim has a side nobody can observe, and experts share a bias on it, so their
consensus is confident and uninformative. Society acts with weight `Tr_lvl` toward the consensus side. Reports
decision accuracy on provable claims, the harm weight put on the wrong side of unprovable claims (sum and peak)
and the weighted payoff of all decisions. Reuses `count_once`-free path: experts are independent here, hops are
step 2b (network, M5, M3c).
"""
function run_ih_claims(p::IhClaimsParams)
    rng_t = Xoshiro(hash((p.seed, :truth))); rng_e = Xoshiro(hash((p.seed, :expert_noise)))
    rng_s = Xoshiro(hash((p.seed, :skill)))
    skill = [e <= round(Int, p.frac_biased * p.experts) ? 0.0 : 0.3 + 0.5 * rand(rng_s) for e in 1:p.experts]   # a third are uninformed: they follow the shared bias even where the claim is checkable
    hit = zeros(p.experts); seen = zeros(p.experts)
    chit = 0.0; cseen = 0.0
    acc = Float64[]; harm = 0.0; peak = 0.0; pay = 0.0; w_unprov = Float64[]
    for step in 1:p.steps
        for _ in 1:p.claims_per_step
            t = rand(rng_t) < 0.5 ? 1.0 : -1.0
            observable = rand(rng_t) < p.frac_provable || (p.infra_step > 0 && step >= p.infra_step)
            bias = rand(rng_t) < 0.5 ? 1.0 : -1.0
            out = [clamp(0.5 + 0.5 * (observable && skill[e] > 0 ? t * skill[e] : p.bias_strength * bias) + p.expert_σ * randn(rng_e), 0.01, 0.99)
                   for e in 1:p.experts]
            wts = ones(p.experts)
            if p.classifier
                wts = [max(2 * ((hit[e] + 1) / (seen[e] + 2)) - 1, 0.02) for e in 1:p.experts]
                lvl = ih_truth_level(out, wts, (chit + 1) / (cseen + 2), observable, p.cap_unprovable)
            else
                lvl = ih_truth_level(out, ones(p.experts), 1.0, true, p.cap_unprovable)
            end
            m = sum(wts .* out) / sum(wts)       # the consensus the level is computed from
            side = m >= 0.5 ? 1.0 : -1.0
            pay += lvl * side * t
            if observable
                push!(acc, side == t ? 1.0 : 0.0)
                for e in 1:p.experts
                    seen[e] += 1; hit[e] += (out[e] >= 0.5 ? 1.0 : -1.0) == t ? 1.0 : 0.0
                end
                cseen += 1; chit += side == t ? 1.0 : 0.0
            else
                push!(w_unprov, lvl)
                if side != t; harm += lvl; peak = max(peak, lvl); end
            end
        end
    end
    (accuracy = isempty(acc) ? 0.0 : mean(acc), harm = harm, harm_peak = peak, payoff = pay,
     mean_unprovable_weight = isempty(w_unprov) ? 0.0 : mean(w_unprov))
end
