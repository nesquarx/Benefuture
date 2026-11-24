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

# ---- IH world, step 2b (WORLD_COVERAGE step 2; author rulings 8.166-8.168): one shared network ----

"Copy `p` overriding the named fields (every field is copied, so a new field never breaks a positional list)."
_with_fields(p::T, over::Dict{Symbol,Any}) where {T} = T((get(over, f, getfield(p, f)) for f in fieldnames(T))...)

Base.@kwdef struct IhWorldParams
    m3::Any                              # an M3c run: the society (agents, reputations) the claims circulate in
    econ::Any                            # the M3cParams of the economy that receives the hazard inputs
    domains::Vector{Int} = [1, 2, 3, 4]
    steps::Int = 12
    claims_per_step::Int = 4
    frac_provable::Float64 = 0.5
    ih::Bool = true                      # false: the unhandled control (no categoriser, no record weights, no tags, M8 untagged)
    connected::Bool = true               # false: voters decide alone, the worlds share no network (limiting case)
    cap_unprovable::Float64 = 0.35       # governed threshold (the same as `IhClaimsParams`)
    liar_stride::Int = 3                 # every third person is a colluder (a biased expert) publishing the shared bias
    n_experts::Int = 8                   # the claim's experts: the domain's top by reputation
    signal_σ::Float64 = 2.0
    advice_stay::Float64 = 0.20          # as `M5Params` default; defer is the shared network's measured adoption of an echoed rumour
    infra_step::Int = 0                  # > 0: at this step unprovable claims become provable (8.168)
    p_side_scale::Float64 = 0.3          # world: chance of an accidental hazard per unit of uninoculated access risk
    extremist_frac::Float64 = 0.0        # share of people who publish the ideology with full confidence whatever the evidence (8.166; 0 = none)
    reframe::Float64 = 0.5               # world: chance a claim is framed as unfalsifiable by the extremists (8.168), before infrastructure makes it checkable
    ext_conf::Float64 = 0.99             # an extremist's stated confidence
    unprovable_to_econ::Float64 = 1.0    # glue: weight of the wrong-side weight on unprovable claims added to the economy's side-effect chance (0 = off)
    seed::Int = 1
end

"""
    run_ih_world(p::IhWorldParams)

Step 2b of the world composition: the claim stream of `run_ih_claims` on the network of the M5 society.
- One network: `n` = the society's size and the colluders (every `liar_stride`-th person) are shared by
  `run_m8_truth` (echoed rumour forwarders), M5 (colluding sources, whose readings are republished) and the experts.
- M8 truth -> M5: the network's measured adoption of an echoed rumour (`false_adoption`) is the share of voters who defer
  to what they hear (`advice_defer`, 8.63), so an untagged network defers more.
- M5 -> claims: each claim is one M5 decision on the claim (readings after deliberation, records carried claim to
  claim, a record only where the outcome is checkable); the domain's top experts' readings, weighed by their records, go
  through `ih_truth_level` with the claim's provable flag. The unhandled control reads every consensus as fact.
- M8 IHz -> M3c: accidental hazard harm under the gate becomes the economy's side-effect chance `p_side`; decision
  accuracy on checkable claims becomes the chance a guardian learns of a hazard in time `p_informed`.
- Extremists (`extremist_frac`, 8.166): people who publish the shared ideology at full confidence whatever the evidence. They join the colluding
  bloc (M5 spreads them by deliberation, tags and weighs them by record as any colluder), among the claim's experts they state `ext_conf`, and
  they frame a checkable claim as unfalsifiable with chance `reframe` (8.168). Speech is never sanctioned: the bound comes from the cap on
  unprovable claims and the record weights. `ext_influence` is the truth level times the extremists' weighted share of the consensus.
- Wrong-side weight on unprovable claims -> M3c (`unprovable_to_econ`): the mean weight acted on the wrong side adds to the accidental-hazard
  risk behind `p_side` (glue: no rule, an existing input).
Reports the claim measures of `run_ih_claims` and the economy's trace with its `success_pattern`.
"""
function run_ih_world(p::IhWorldParams)
    m3 = p.m3; na = length(m3.agents); nd = size(m3.relevance_leaf, 2)
    liars = collect(1:p.liar_stride:na)
    extremists = p.extremist_frac > 0 ? [i for i in 1:na if i % max(2, round(Int, 1 / p.extremist_frac)) == 2 && !(i in liars)] : Int[]
    bloc = sort(union(liars, extremists))   # extremists are one more fixed-side bloc on the network: M5 spreads, tags and weighs them as it does the colluders
    rng_x = Xoshiro(hash((p.seed, :extremist)))   # own stream, drawn only where extremists exist
    # the shared network's two M8 measurements (one n, one set of colluders)
    t8 = run_m8_truth(M8TruthParams(n = na, steps = 4, echo_copies = length(liars), mode = p.ih ? :bf_truth : :untagged_naive, seed = p.seed))
    z8 = run_m8_ihz(M8IhzParams(n = na, steps = 8, attacker_frac = length(liars) / na, mode = p.ih ? :gated_ihz : :open_ungated, seed = p.seed))
    defer = clamp(t8.false_adoption, 0.0, 1 - p.advice_stay)
    base = M5Params(m3, p.domains; decisions = 1, signal_σ = p.signal_σ, deliberation = p.connected, info_handling = p.ih,
                    source_tags = p.ih && p.connected, tag_liars = p.connected ? bloc : Int[], colluders = bloc, stealth = false,
                    diversity = false, advice_stay = p.advice_stay, advice_avg = 1 - p.advice_stay - defer, advice_defer = defer)
    rng_t = Xoshiro(hash((p.seed, :truth))); rng_d = Xoshiro(hash((p.seed, :domain)))
    rec = [[0.0, 0.0] for _ in 1:na, _ in 1:nd]
    chit = 0.0; cseen = 0.0; acc = Float64[]; harm = 0.0; peak = 0.0; pay = 0.0; w_unprov = Float64[]; swayed = Float64[]
    infl = Float64[]; infl_unprov = Float64[]; wrong_unprov = Float64[]
    for step in 1:p.steps, c in 1:p.claims_per_step
        k = p.domains[rand(rng_d, 1:length(p.domains))]
        t = rand(rng_t) < 0.5 ? 1.0 : -1.0
        observable = rand(rng_t) < p.frac_provable || (p.infra_step > 0 && step >= p.infra_step)
        bias = rand(rng_t) < 0.5 ? 1.0 : -1.0
        # extremists frame the claim as unfalsifiable where they can (not once infrastructure exists to check it)
        !isempty(extremists) && observable && !(p.infra_step > 0 && step >= p.infra_step) && rand(rng_x) < p.reframe && (observable = false)
        # in the bias frame +1 is the shared bias's side; an unfalsifiable claim is perceived as the bias side by everyone
        T = observable ? t * bias : 1.0
        over = Dict{Symbol,Any}(:p_apparent => observable ? 1.0 : 0.0, :domains => [k])
        r = run_m5(_with_fields(base, over); seed = Int(hash((p.seed, :claim, step, c)) & 0x7fffffff), records = rec, truths = [T])
        rec = r.records
        experts = sortperm(m3.relevance_leaf[:, k]; rev = true)[1:min(p.n_experts, na)]
        out = [e in extremists ? clamp(0.5 + 0.5 * p.ext_conf * bias, 0.01, 0.99) : clamp(0.5 + 0.45 * bias * sign(r.last_signal[e]), 0.01, 0.99) for e in experts]
        push!(swayed, isempty(r.minds_changed) ? 0.0 : r.minds_changed[end])
        if p.ih
            wts = [max(source_weight(rec[e, k][1], rec[e, k][2]), 0.02) for e in experts]
            lvl = ih_truth_level(out, wts, (chit + 1) / (cseen + 2), observable, p.cap_unprovable)
        else
            wts = ones(length(experts))
            lvl = ih_truth_level(out, wts, 1.0, true, p.cap_unprovable)
        end
        side = sum(wts .* out) / sum(wts) >= 0.5 ? 1.0 : -1.0
        pay += lvl * side * t
        ext_share = sum(wts[i] for (i, e) in enumerate(experts) if e in extremists; init = 0.0) / sum(wts)
        push!(infl, lvl * ext_share)   # the weight society puts on what extremists carry in this claim's consensus
        if observable
            push!(acc, side == t ? 1.0 : 0.0); cseen += 1; chit += side == t ? 1.0 : 0.0
        else
            push!(w_unprov, lvl); push!(infl_unprov, lvl * ext_share)
            push!(wrong_unprov, side != t ? lvl : 0.0)
            side != t && (harm += lvl; peak = max(peak, lvl))
        end
    end
    accuracy = isempty(acc) ? 0.0 : mean(acc)
    n_legit = na - length(liars)
    wrong_u = isempty(wrong_unprov) ? 0.0 : mean(wrong_unprov)   # mean weight acted on the wrong side of unprovable claims: more side-effect hazard in the economy
    risk = z8.accidental_harm / max(1, n_legit * 8 * 0.5 * M8IhzParams().hazard_harm)
    econ = _with_fields(p.econ, Dict{Symbol,Any}(:p_informed => clamp(accuracy, 0.05, 0.99),
                                                  :p_side => clamp(p.p_side_scale * (risk + p.unprovable_to_econ * wrong_u), 0.0, 1.0)))
    tr = run_m3c(econ; seed = p.seed)
    (accuracy = accuracy, harm = harm, harm_peak = peak, payoff = pay,
     mean_unprovable_weight = isempty(w_unprov) ? 0.0 : mean(w_unprov), swayed = mean(swayed),
     ext_influence = isempty(infl) ? 0.0 : mean(infl), ext_influence_unprovable_peak = isempty(infl_unprov) ? 0.0 : maximum(infl_unprov),
     wrong_unprovable_weight = wrong_u, n_extremists = length(extremists),
     false_adoption = t8.false_adoption, accidental_harm = z8.accidental_harm, p_informed = clamp(accuracy, 0.05, 0.99),
     tr = tr, pattern = success_pattern(tr))
end
