# Differential, property-based tests between the Lean exports and the Julia input guards (Cedar
# style: generated inputs, an independent oracle). For each rule: inputs are drawn from a mix of
# valid values and hostile ones (NaN, ±Inf, negatives, out-of-range); the wrapper's guard must
# accept exactly the inputs in the rule's documented domain (written here independently of the
# guard), and on every accepted input the Lean export must agree with a test-only oracle within
# tolerance. Test oracles are deliberately independent transcriptions of the Lean docstrings; the
# simulation itself never computes rules in Julia.

const HOSTILE = (NaN, Inf, -Inf, -1.0, -1e-9, 0.0, 1e-300, 1.0, 1.5, 1e12)
hostile(r) = rand(r) < 0.3 ? rand(r, HOSTILE) : (rand(r) < 0.5 ? rand(r) : 10 * randn(r))

# Outcome of calling the wrapper: `:rejected` on ArgumentError, else its value.
function attempt(f)
    try
        f()
    catch e
        e isa ArgumentError || rethrow()
        :rejected
    end
end

# The guard accepts exactly the domain, and accepted outputs match the oracle.
function differential(name, gen, domain, wrapper, oracle; trials = 400, seed = 1, atol = 1e-9, rtol = 1e-9)
    r = Xoshiro(hash((seed, name)))
    mismatched_guard, mismatched_value = 0, 0
    for _ in 1:trials
        x = gen(r)
        out = attempt(() -> wrapper(x...))
        if domain(x...)
            out === :rejected && (mismatched_guard += 1; continue)
            isapprox(out, oracle(x...); atol, rtol) || (mismatched_value += 1)
        else
            out === :rejected || (mismatched_guard += 1)
        end
    end
    (guard = mismatched_guard, value = mismatched_value)
end

fin(xs...) = all(isfinite, xs)

@testset "Differential: Lean exports against independent oracles, through the guards" begin
    @test differential(:settlement, r -> (hostile(r), hostile(r)), fin, settlement, (m, u) -> m - u) == (guard = 0, value = 0)
    @test differential(:supply_delta, r -> (hostile(r), hostile(r), hostile(r)), fin, supply_delta,
                       (g, c, h) -> g - c - h) == (guard = 0, value = 0)
    @test differential(:competition_efficiency, r -> (hostile(r), hostile(r), hostile(r)),
                       (v, c, t) -> fin(v, c, t) && c + t > 0, competition_efficiency,
                       (v, c, t) -> v / (c + t)) == (guard = 0, value = 0)
    @test differential(:cc_share, r -> (hostile(r), hostile(r)),
                       (p, s) -> fin(p, s) && s != 0 && sign(p) * sign(s) >= 0, cc_share,
                       (p, s) -> clamp(p / s, 0.0, 1.0)) == (guard = 0, value = 0)
    @test differential(:cause_settlement, r -> (hostile(r), hostile(r), hostile(r)),
                       (cc, t, u) -> fin(cc, t, u) && 0 <= cc <= 1, cause_settlement,
                       (cc, t, u) -> cc * t - u) == (guard = 0, value = 0)
    @test differential(:ratchet_credence, r -> (hostile(r), hostile(r)),
                       (c, n) -> fin(c, n) && 0 <= c <= 1 && 0 <= n <= 1, ratchet_credence,
                       (c, n) -> 0.5 + (c - 0.5) * (1 - n)) == (guard = 0, value = 0)
    @test differential(:advap_reward, r -> (hostile(r), hostile(r), hostile(r), hostile(r)),
                       (g, h, s, f) -> fin(g, h, s, f) && s >= 0 && f >= 0,
                       (g, h, s, f) -> advap_reward(g, h; share = s, floor = f),
                       (g, h, s, f) -> max(0, g) + max(f, s * max(0, h))) == (guard = 0, value = 0)
    @test differential(:carry_fee, r -> (hostile(r), rand(r, Bool), hostile(r), hostile(r)),
                       (m, k, a, s) -> isfinite(m) && 0 <= a <= 1 && 0 <= s <= 1,
                       (m, k, a, s) -> carry_fee(m, k; accolade_rate = a, contract_share = s),
                       (m, k, a, s) -> m <= 0 ? 0.0 : (k ? s : a) * m) == (guard = 0, value = 0)
    # Capped delegation (L114): accept each further weight only while the total is under the cap.
    capped(cap, cur, ws) = foldl((c, w) -> c < cap ? c + w : c, ws; init = cur)
    @test differential(:accumulate_capped, r -> (hostile(r), hostile(r), [hostile(r) for _ in 1:rand(r, 0:5)]),
                       (c, u, ws) -> fin(c, u) && all(w -> isfinite(w) && w >= 0, ws), accumulate_capped,
                       capped) == (guard = 0, value = 0)
    # Fallback traversal (L95): netC · decay^degree, normalised; nothing when nothing contributed.
    function trav(c, d, δ)
        w = c .* δ .^ d
        sum(w) <= 0 ? zero(w) : w ./ sum(w)
    end
    @test differential(:traversal_shares,
                       r -> (k = rand(r, 1:4); ([hostile(r) for _ in 1:k], [abs(hostile(r)) for _ in 1:(k + (rand(r) < 0.1))], hostile(r))),
                       (c, d, δ) -> length(c) == length(d) && all(x -> isfinite(x) && x >= 0, c) &&
                                    all(x -> isfinite(x) && x >= 0, d) && isfinite(δ) && 0 < δ <= 1,
                       (c, d, δ) -> traversal_shares(c, d; decay = δ), trav) == (guard = 0, value = 0)
    # Shapley, exact: the weighted sum over coalitions, against the mean over all orderings.
    function shapley_by_orderings(v)
        n = round(Int, log2(length(v)))
        φ = zeros(n)
        orders = n == 0 ? [Int[]] : all_perms(n)
        for o in orders
            mask = 0
            for i in o
                φ[i] += v[(mask | (1 << (i - 1))) + 1] - v[mask + 1]
                mask |= 1 << (i - 1)
            end
        end
        φ ./ length(orders)
    end
    @test differential(:shapley, r -> (k = rand(r, 0:5); ([rand(r) < 0.05 ? hostile(r) : randn(r) for _ in 1:(2^k + (rand(r) < 0.1))],)),
                       v -> length(v) >= 1 && ispow2(length(v)) && all(isfinite, v), shapley,
                       shapley_by_orderings; trials = 200) == (guard = 0, value = 0)
    # Shapley, sampled: an independent mean of marginals along the given orderings.
    function sampled_oracle(P, V)
        n, m = size(P)
        φ = zeros(n)
        for k in 1:m, p in 1:n
            φ[P[p, k]] += V[p + 1, k] - V[p, k]
        end
        φ ./ m
    end
    gen_sampled(r) = begin
        n, m = rand(r, 1:6), rand(r, 0:4)
        P = reduce(hcat, [randperm(r, n) for _ in 1:m]; init = zeros(Int, n, 0))
        rand(r) < 0.1 && m > 0 && (P[rand(r, 1:n), rand(r, 1:m)] = rand(r, 0:(n + 1)))
        V = [rand(r) < 0.03 ? hostile(r) : randn(r) for _ in 1:(n + 1 + (rand(r) < 0.05)), _ in 1:m]
        (P, V)
    end
    @test differential(:shapley_sampled, gen_sampled,
                       (P, V) -> size(P, 2) >= 1 && size(V) == (size(P, 1) + 1, size(P, 2)) && all(isfinite, V) &&
                                 all(k -> sort(P[:, k]) == 1:size(P, 1), 1:size(P, 2)),
                       shapley_sampled, sampled_oracle) == (guard = 0, value = 0)
    @test differential(:accident_split, r -> (hostile(r), hostile(r)),
                       (h, c) -> fin(h, c) && h >= 0 && c >= 0,
                       (h, c) -> collect(accident_split(h, c)),
                       (h, c) -> [min(h, c), h - min(h, c)]) == (guard = 0, value = 0)
    @test differential(:sanction_escrow_credence,
                       r -> (rand(r) < 0.1 ? hostile(r) : rand(r), rand(r) < 0.1 ? hostile(r) : rand(r),
                             rand(r, -2:5), rand(r, -2:10), rand(r, -1:5), rand(r) < 0.1 ? hostile(r) : 2.5 * rand(r),
                             rand(r) < 0.1 ? hostile(r) : 0.6 * rand(r)),
                       (c, ns, d, ne, pm, g, fl) -> fin(c, ns, g, fl) && 0 <= c <= 1 && 0 <= ns <= 1 &&
                                                     d >= 0 && ne >= 0 && pm >= 0 && g >= 0 && 0 < fl <= 0.5,
                       (c, ns, d, ne, pm, g, fl) -> sanction_escrow_credence(c, ns, d, ne, pm; growth = g, floor = fl),
                       (c, ns, d, ne, pm, g, fl) -> begin
                           esc = d + ((pm == 0 || ne < pm) ? 0 : ne - pm + 1)
                           max(fl, (0.5 + (c - 0.5) * (1 - ns)) / (1 + g)^esc)
                       end) == (guard = 0, value = 0)
    @test differential(:rehabilitate_restraint,
                       r -> (rand(r) < 0.1 ? hostile(r) : 2.0 * rand(r), rand(r, -2:10), rand(r, -1:5),
                             rand(r) < 0.1 ? hostile(r) : 1.2 * rand(r), rand(r) < 0.1 ? hostile(r) : 1.2 * rand(r)),
                       (b, ce, pm, dec, ms) -> fin(b, dec, ms) && b >= 0 && ce >= 0 && pm >= 0 &&
                                               0 <= dec <= 1 && 0 <= ms <= b,
                       (b, ce, pm, dec, ms) -> rehabilitate_restraint(b, ce, pm; decay = dec, min_share = ms),
                       (b, ce, pm, dec, ms) -> begin
                           esc = (pm == 0 || ce < pm) ? 0 : ce - pm + 1
                           esc == 0 ? b : max(ms, b * dec^esc)
                       end) == (guard = 0, value = 0)
    @test differential(:ra_value_per_cost,
                       r -> (rand(r) < 0.1 ? hostile(r) : 20 * rand(r) - 5, rand(r) < 0.1 ? hostile(r) : 5 * rand(r) - 0.5,
                             rand(r) < 0.1 ? hostile(r) : 3 * rand(r) - 0.5, rand(r) < 0.1 ? hostile(r) : 2 * rand(r)),
                       (mg, rc, ac, fb) -> fin(mg, rc, ac, fb),
                       (mg, rc, ac, fb) -> ra_value_per_cost(mg, rc; audit_cost = ac, fallback = fb),
                       (mg, rc, ac, fb) -> (tc = rc + max(0.0, ac); tc > 0 ? mg / tc : fb)) == (guard = 0, value = 0)
    @test differential(:ra_commons_reserve,
                       r -> (rand(r) < 0.1 ? hostile(r) : 10 * rand(r) - 1, rand(r) < 0.1 ? hostile(r) : 2 * rand(r) - 0.2,
                             rand(r) < 0.1 ? hostile(r) : 8 * rand(r) - 1),
                       (en, fr, hz) -> fin(en, fr, hz),
                       (en, fr, hz) -> ra_commons_reserve(en, fr; horizon = hz),
                       (en, fr, hz) -> max(0.0, en) * max(0.0, fr) * max(0.0, hz)) == (guard = 0, value = 0)
    @test differential(:ra_contraction_factor,
                       r -> (rand(r) < 0.1 ? hostile(r) : 10 * rand(r), rand(r) < 0.1 ? hostile(r) : 6 * rand(r) - 0.5,
                             rand(r) < 0.1 ? hostile(r) : rand(r), rand(r) < 0.1 ? hostile(r) : rand(r)),
                       (cl, cap, rt, ms) -> fin(cl, cap, rt, ms) && 0 <= rt <= 1 && 0 <= ms <= 1,
                       (cl, cap, rt, ms) -> ra_contraction_factor(cl, cap; rate = rt, min_scale = ms),
                       (cl, cap, rt, ms) -> (cl <= cap || cap <= 0) ? 1.0 : max(ms, 1.0 - rt * min(1.0, (cl - cap) / cap))) == (guard = 0, value = 0)
end
