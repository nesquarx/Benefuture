# Priority-tier probe world (author ruling 8.129): the smallest world where valuing by tiers decides something.
# Each step a chooser picks one programme by its expected value per being; effects are typed by tier:
#   research   - with chance `p_paradigm` a breakthrough (the researcher's understanding rises past the frontier:
#                peak; novelty paradigm), else an incremental gain (median; novelty incremental); half teachable;
#   teach      - the `class` beings furthest behind gain a share `ε` of the gap to the best teachable level
#                (teachable; floor when the lowest rises);
#   entertain  - raw happiness `joy` for everyone, adapting back toward baseline (happiness peak tier; novelty trivial);
#   practice   - one being gains tacit, non-transferable understanding `drill` (peak when it passes the best, else median).
# Tier positions (author, 2026-11-08): understanding's peak, median and floor are positions on the global curve
# (understanding is comparable); happiness tiers are global where comparable and personal where not, so the
# entertainment programme's raw happiness is the peak (sensory) kind for each being, read personally.
# Toy assumptions named: one global chooser (a limiting case of G per entity, 8.50); expected effects known up to
# noise `pred_σ`; happiness adapts with retention `h_retention` per step. Objects approximated: L57–L60 tiers, L63 V.

"""
    run_programmes(; seed, tiered = true, n = 20, steps = 100, ...) -> (u, h, picks, trace)

Runs the programme world. `tiered = false` values each programme by the scalar sums of its effects (the
collapsed reading); `true` values the same effects through `tiered_value`.
"""
function run_programmes(; seed::Integer, tiered::Bool = true, n::Integer = 20, steps::Integer = 100,
                        p_paradigm::Real = 0.1, leap::Real = 2.0, increment::Real = 0.2, ε::Real = 0.2, class::Integer = 5,
                        joy::Real = 0.3, h_retention::Real = 0.3, drill::Real = 0.5, pred_σ::Real = 0.1)
    check(n >= class >= 1 && steps >= 1 && 0 <= p_paradigm <= 1 && 0 < ε <= 1 && 0 <= h_retention <= 1 && pred_σ >= 0 &&
          all(x -> isfinite(x) && x >= 0, (leap, increment, joy, drill)), "valid programme world")
    rng = Xoshiro(seed); prng = Xoshiro(hash((seed, :predictions))); erng = Xoshiro(hash((seed, :effects)))
    u = 1.0 .+ rand(rng, n); h0 = 50.0; h = fill(h0, n); teachable = u ./ 2
    bp = NamedTuple{PARAM_FIELDS}(Tuple(bootstrap_params()))
    kw = (harm_wt = 1.0, α = bp.alpha, β = bp.beta, γ = bp.gamma, λ = bp.lambda, qp = bp.q_plus, qm = bp.q_minus)
    names = (:research, :teach, :entertain, :practice)
    picks = Symbol[]
    # Expected tier vectors per programme (understanding, happiness, novelty), summed over beings.
    function expected(prog)
        U = zeros(6); H = zeros(6); N = zeros(6)
        if prog == :research
            U[1] += p_paradigm * leap; U[2] += (p_paradigm * leap + (1 - p_paradigm) * increment) / 2
            U[4] += (1 - p_paradigm) * increment; N[1] += p_paradigm; N[4] += 1 - p_paradigm
        elseif prog == :teach
            best = maximum(teachable); low = partialsortperm(u, 1:class)
            g = sum(ε * max(0.0, best - teachable[b]) for b in low)
            U[2] += g; U[5] += ε * max(0.0, best - teachable[low[1]])
        elseif prog == :entertain
            H[6] += joy * n; N[6] += 1.0
        else
            # Tiers of understanding are positions on the global curve (author, 2026-11-08): a gain is peak only
            # where it carries the being past the best; a random being passes it with this share.
            pk = count(b -> u[b] + drill > maximum(u), 1:n) / n
            U[1] += pk * drill; U[4] += (1 - pk) * drill
        end
        U, H, N
    end
    for t in 1:steps
        vals = map(names) do prog
            U, H, N = expected(prog)
            U = U .* exp(pred_σ * randn(prng)); H = H .* exp(pred_σ * randn(prng))
            tiered ? tiered_value(U, H, N; kw...) : value_on_being(sum(U), sum(H), sum(N); kw...)
        end
        prog = names[argmax(vals)]; push!(picks, prog)
        h .= h0 .+ h_retention .* (h .- h0)
        if prog == :research
            r = rand(erng, 1:n)
            gain = rand(erng) < p_paradigm ? (maximum(u) - u[r]) + leap : increment
            u[r] += gain; teachable[r] += gain / 2
        elseif prog == :teach
            best = maximum(teachable)
            for b in partialsortperm(u, 1:class)
                g = ε * max(0.0, best - teachable[b]); u[b] += g; teachable[b] += g
            end
        elseif prog == :entertain
            h .+= joy
        else
            u[rand(erng, 1:n)] += drill
        end
    end
    (u = u, h = h, picks = picks, trace = Dict{String,Int}(string(k) => count(==(k), picks) for k in names))
end
