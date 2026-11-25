# Differential, property-based tests between the Lean exports and the Julia input guards (Cedar
# style: generated inputs, an independent oracle). For each rule: inputs are drawn from a mix of
# valid values and hostile ones (NaN, ±Inf, negatives, out-of-range); the wrapper's guard must
# accept exactly the inputs in the rule's documented domain (written here independently of the
# guard), and on every accepted input the Lean export must agree with a test-only oracle within
# tolerance. Test oracles are deliberately independent transcriptions of the Lean docstrings; the
# simulation itself never computes rules in Julia.

include("test_helpers.jl")   # all_perms (also used by shapley_sampling_tests.jl), so this file runs alone

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
    @test differential(:restraint_audit_prob,
                       r -> (rand(r) < 0.1 ? hostile(r) : 2.0 * rand(r), rand(r) < 0.1 ? hostile(r) : 20.0 * rand(r),
                             rand(r) < 0.1 ? hostile(r) : 10.0 * rand(r) + 0.1, rand(r) < 0.1 ? hostile(r) : 3.0 * rand(r) + 0.05,
                             rand(r) < 0.1 ? hostile(r) : 1.2 * rand(r)),
                       (sv, du, ds, bar, fl) -> fin(sv, du, ds, bar, fl) && sv >= 0 && du >= 0 && ds > 0 && bar > 0 && 0 <= fl <= 1,
                       (sv, du, ds, bar, fl) -> restraint_audit_prob(sv, du, bar; duration_scale = ds, floor = fl),
                       (sv, du, ds, bar, fl) -> min(1.0, fl + (1 - fl) * (sv * (1 + du / ds) / bar))) == (guard = 0, value = 0)
    @test differential(:false_restraint_liability,
                       r -> (rand(r, Bool), rand(r) < 0.1 ? hostile(r) : 4.0 * rand(r), rand(r) < 0.1 ? hostile(r) : 4.0 * rand(r)),
                       (up, k, c) -> fin(k, c) && k >= 0 && c >= 0,
                       (up, k, c) -> false_restraint_liability(up, k, c),
                       (up, k, c) -> up ? 0.0 : k * c) == (guard = 0, value = 0)
    @test differential(:credence_restraint_liability,
                       r -> (rand(r) < 0.1 ? hostile(r) : rand(r), rand(r) < 0.1 ? hostile(r) : 4.0 * rand(r), rand(r) < 0.1 ? hostile(r) : 4.0 * rand(r)),
                       (q, k, c) -> fin(q, k, c) && 0 <= q <= 1 && k >= 0 && c >= 0,
                       (q, k, c) -> credence_restraint_liability(q, k, c),
                       (q, k, c) -> k * c * clamp(2q - 1, 0.0, 1.0)) == (guard = 0, value = 0)
    @test differential(:restraint_balance_flawed,
                       r -> (rand(r, 0:20), rand(r, 0:20), rand(r, 0:20), rand(r) < 0.1 ? hostile(r) : 3.0 * rand(r)),
                       (m, f, t, q) -> fin(q) && q >= 0,
                       (m, f, t, q) -> restraint_balance_flawed(m, f, t; ratio = q),
                       (m, f, t, q) -> m <= f + t && q * t <= f) == (guard = 0, value = 0)
    @test differential(:panel_voice,
                       r -> (rand(r) < 0.1 ? hostile(r) : 3 * rand(r), rand(r) < 0.1 ? hostile(r) : 3 * rand(r), rand(r) < 0.5),
                       (w, u, m) -> fin(w, u) && w >= 0 && u >= 0,
                       (w, u, m) -> panel_voice(w, u, m),
                       (w, u, m) -> m ? w * max(1.0, u) : w) == (guard = 0, value = 0)
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
    @test differential(:responsibility_factor,
                       r -> (rand(r, Bool), rand(r, Bool), rand(r, Bool),
                             rand(r) < 0.1 ? hostile(r) : 1.5 * rand(r) - 0.25,
                             rand(r) < 0.1 ? hostile(r) : 3.0 * rand(r) - 0.25,
                             rand(r) < 0.1 ? hostile(r) : 1.5 * rand(r) - 0.25),
                       (act, inf, duty, cf, sev, acc) -> fin(cf, sev, acc),
                       (act, inf, duty, cf, sev, acc) -> responsibility_factor(act, inf, duty, cf; severity_scale = sev, accident_factor = acc),
                       (act, inf, duty, cf, sev, acc) -> begin
                           rw = (!act && !duty) ? 0.0 : (inf ? 1.0 : clamp(acc, 0.0, 1.0))
                           rw * clamp(cf, 0.0, 1.0) * max(0.0, sev)
                       end) == (guard = 0, value = 0)
    @test differential(:binding_admits_weighted,
                       r -> begin
                           k = rand(r, 0:6)
                           confs = [rand(r) < 0.05 ? hostile(r) : 1.2 * rand(r) - 0.1 for _ in 1:k]
                           weights = [rand(r) < 0.05 ? hostile(r) : 3.0 * rand(r) - 1.5 for _ in 1:k]
                           th = rand(r) < 0.05 ? hostile(r) : 1.2 * rand(r) - 0.1
                           qw = rand(r) < 0.05 ? hostile(r) : 4.0 * rand(r) - 0.2
                           (confs, weights, th, qw)
                       end,
                       (confs, weights, th, qw) -> all(c -> isfinite(c) && 0 <= c <= 1, confs) && all(isfinite, weights) && isfinite(th) && 0 <= th <= 1 && isfinite(qw) && qw >= 0,
                       binding_admits_weighted,
                       (confs, weights, th, qw) -> sum((clamp(w, 0.0, 1.0) for (c, w) in zip(confs, weights) if c >= th); init = 0.0) >= qw) == (guard = 0, value = 0)
    @test differential(:deciding_scope,
                       r -> begin
                           n = rand(r, 1:6)
                           shares = [rand(r) < 0.05 ? hostile(r) : 1.4 * rand(r) - 0.2 for _ in 1:n]
                           wh = rand(r, Bool, n)
                           smin = rand(r) < 0.05 ? hostile(r) : 1.2 * rand(r) - 0.1
                           (shares, wh, smin)
                       end,
                       (shares, wh, smin) -> !isempty(shares) && length(shares) == length(wh) && all(isfinite, shares) && isfinite(smin),
                       (shares, wh, smin) -> deciding_scope(shares, wh; share_min = smin),
                       (shares, wh, smin) -> begin
                           n = length(shares)
                           idx = findfirst(i -> wh[i] && shares[i] >= smin, 1:(n - 1))
                           idx === nothing ? n : idx
                       end) == (guard = 0, value = 0)
    @test differential(:extended_self_feedback,
                       r -> begin
                           k = rand(r, 0:6)
                           c = [rand(r) < 0.05 ? hostile(r) : 2.0 * rand(r) - 0.5 for _ in 1:k]
                           d = [rand(r) < 0.05 ? hostile(r) : 10.0 * randn(r) for _ in 1:k]
                           (c, d)
                       end,
                       (c, d) -> length(c) == length(d) && all(isfinite, c) && all(isfinite, d),
                       extended_self_feedback,
                       (c, d) -> sum(clamp(ci, 0.0, 1.0) * di for (ci, di) in zip(c, d); init = 0.0)) == (guard = 0, value = 0)
    @test differential(:propagated_liability,
                       r -> begin
                           k = rand(r, 0:5)
                           h = rand(r) < 0.1 ? hostile(r) : 8.0 * rand(r) - 2.0
                           cs = [rand(r) < 0.05 ? hostile(r) : 1.5 * rand(r) - 0.25 for _ in 1:k]
                           (h, cs)
                       end,
                       (h, cs) -> isfinite(h) && all(isfinite, cs),
                       propagated_liability,
                       (h, cs) -> h <= 0 ? 0.0 : h * prod(clamp(c, 0.0, 1.0) for c in cs; init = 1.0)) == (guard = 0, value = 0)
    @test differential(:end_of_horizon_score,
                       r -> begin
                           k = rand(r, 0:4)
                           own = rand(r) < 0.05 ? hostile(r) : 6.0 * randn(r)
                           alive = rand(r, Bool)
                           c = [rand(r) < 0.05 ? hostile(r) : 1.5 * rand(r) - 0.25 for _ in 1:k]
                           d = [rand(r) < 0.05 ? hostile(r) : 8.0 * randn(r) for _ in 1:k]
                           csh = rand(r) < 0.05 ? hostile(r) : 1.5 * rand(r) - 0.25
                           do_ = rand(r) < 0.05 ? hostile(r) : 6.0 * randn(r)
                           ish = rand(r) < 0.05 ? hostile(r) : 1.5 * rand(r) - 0.25
                           ig = rand(r) < 0.05 ? hostile(r) : 6.0 * randn(r)
                           (own, alive, c, d, csh, do_, ish, ig)
                       end,
                       (own, alive, c, d, csh, do_, ish, ig) -> isfinite(own) && length(c) == length(d) &&
                           all(isfinite, c) && all(isfinite, d) && all(isfinite, (csh, do_, ish, ig)),
                       (own, alive, c, d, csh, do_, ish, ig) -> end_of_horizon_score(own, alive, c, d;
                           causal_share = csh, delayed_outcome = do_,
                           ideological_share = ish, ideological_gain = ig),
                       (own, alive, c, d, csh, do_, ish, ig) -> (alive ? own : 0.0) +
                           sum(clamp(ci, 0.0, 1.0) * di for (ci, di) in zip(c, d); init = 0.0) +
                           max(0.0, csh) * do_ + max(0.0, ish) * ig) == (guard = 0, value = 0)
    @test differential(:end_of_horizon_predicted_score,
                       r -> begin
                           k = rand(r, 0:4)
                           imm = rand(r) < 0.05 ? hostile(r) : 6.0 * randn(r)
                           fut = rand(r) < 0.05 ? hostile(r) : 6.0 * randn(r)
                           alive_out = rand(r, Bool)
                           c = [rand(r) < 0.05 ? hostile(r) : 1.5 * rand(r) - 0.25 for _ in 1:k]
                           d = [rand(r) < 0.05 ? hostile(r) : 8.0 * randn(r) for _ in 1:k]
                           csh = rand(r) < 0.05 ? hostile(r) : 1.5 * rand(r) - 0.25
                           do_ = rand(r) < 0.05 ? hostile(r) : 6.0 * randn(r)
                           ish = rand(r) < 0.05 ? hostile(r) : 1.5 * rand(r) - 0.25
                           ig = rand(r) < 0.05 ? hostile(r) : 6.0 * randn(r)
                           (imm, fut, alive_out, c, d, csh, do_, ish, ig)
                       end,
                       (imm, fut, alive_out, c, d, csh, do_, ish, ig) -> isfinite(imm) && isfinite(fut) &&
                           length(c) == length(d) && all(isfinite, c) && all(isfinite, d) &&
                           all(isfinite, (csh, do_, ish, ig)),
                       (imm, fut, alive_out, c, d, csh, do_, ish, ig) -> end_of_horizon_predicted_score(
                           imm, fut, alive_out, c, d; causal_share = csh, delayed_outcome = do_,
                           ideological_share = ish, ideological_gain = ig),
                       (imm, fut, alive_out, c, d, csh, do_, ish, ig) -> imm + (alive_out ? fut : 0.0) +
                           sum(clamp(ci, 0.0, 1.0) * di for (ci, di) in zip(c, d); init = 0.0) +
                           max(0.0, csh) * do_ + max(0.0, ish) * ig) == (guard = 0, value = 0)
    @test differential(:ihz_access_risk,
                       r -> (hostile(r), hostile(r), hostile(r)),
                       (clr, req, harm) -> all(isfinite, (clr, req, harm)),
                       (clr, req, harm) -> ihz_access_risk(clr, req; potential_harm = harm),
                       (clr, req, harm) -> clr >= req ? 0.0 : max(0.0, harm)) == (guard = 0, value = 0)
    @test differential(:art_success_score,
                       r -> begin
                           k = rand(r, 0:5)
                           p = [rand(r) < 0.05 ? hostile(r) : 2.0 * rand(r) - 0.5 for _ in 1:k]
                           q = [rand(r) < 0.05 ? hostile(r) : 2.0 * rand(r) - 0.5 for _ in 1:k]
                           (p, q)
                       end,
                       (p, q) -> length(p) == length(q) && all(isfinite, p) && all(isfinite, q),
                       art_success_score,
                       (p, q) -> max(0.0, 1.0 - sum(abs(pi - qi) for (pi, qi) in zip(p, q); init = 0.0) / 2.0)) == (guard = 0, value = 0)
    @test differential(:art_surplus_value,
                       r -> (hostile(r), hostile(r)),
                       (u, nov) -> isfinite(u) && isfinite(nov),
                       art_surplus_value,
                       (u, nov) -> max(0.0, u) + max(0.0, nov)) == (guard = 0, value = 0)
    @test differential(:chain_truth_level,
                       r -> begin
                           k = rand(r, 0:5)
                           b = rand(r) < 0.1 ? hostile(r) : 1.5 * rand(r) - 0.25
                           hs = [rand(r) < 0.05 ? hostile(r) : 1.5 * rand(r) - 0.25 for _ in 1:k]
                           (b, hs)
                       end,
                       (b, hs) -> isfinite(b) && all(isfinite, hs),
                       chain_truth_level,
                       (b, hs) -> clamp(b, 0.0, 1.0) * prod(clamp(h, 0.0, 1.0) for h in hs; init = 1.0)) == (guard = 0, value = 0)
    @test differential(:contention_map,
                       r -> begin
                           k = rand(r, 0:6)
                           reps = [rand(r) < 0.05 ? hostile(r) : (rand(r) < 0.2 ? 1.0 : 5.0 * randn(r)) for _ in 1:k]
                           self = rand(r, -1:(k + 1))
                           (reps, self)
                       end,
                       (reps, self) -> all(isfinite, reps) && 0 <= self <= length(reps),
                       (reps, self) -> Float64.(contention_map(reps; self = self)),
                       (reps, self) -> Float64.(filter(!=(self), sortperm(reps; rev = true)))) == (guard = 0, value = 0)
    @test differential(:advap_recount_correct,
                       r -> begin
                           k = rand(r, 1:6)
                           h = [rand(r) < 0.05 ? hostile(r) : 3.0 * rand(r) for _ in 1:k]
                           v = [rand(r) < 0.5 ? 1.0 : -1.0 for _ in 1:k]
                           act = [rand(r, Bool) ? 1.0 : 0.0 for _ in 1:k]
                           tr = rand(r) < 0.05 ? hostile(r) : (rand(r) < 0.5 ? 1.2 : -1.2)
                           (h, v, act, tr)
                       end,
                       (h, v, act, tr) -> length(h) == length(v) == length(act) &&
                           all(isfinite, h) && all(isfinite, v) && isfinite(tr),
                       (h, v, act, tr) -> advap_recount_correct(h, v, act, tr),
                       (h, v, act, tr) -> begin
                           hon = sum(h[j] * v[j] for j in eachindex(h) if act[j] != 0.0; init = 0.0)
                           (hon == 0 ? 1.0 : sign(hon)) == sign(tr)
                       end) == (guard = 0, value = 0)
    @test differential(:tail_floor,
                       r -> begin
                           k = rand(r, 0:6)
                           ref = rand(r) < 0.05 ? hostile(r) : 4.0 * randn(r)
                           xs = [rand(r) < 0.05 ? hostile(r) : (isfinite(ref) ? ref : 0.0) + (rand(r) < 0.5 ? 5.0 * rand(r) : 6.0 * randn(r)) for _ in 1:k]
                           q = rand(r) < 0.05 ? hostile(r) : (rand(r) < 0.2 ? (rand(r) < 0.5 ? 0.0 : 1.0) : 1.4 * rand(r) - 0.2)
                           (xs, q, ref)
                       end,
                       (xs, q, ref) -> all(isfinite, xs) && isfinite(q) && 0 <= q <= 1 && isfinite(ref),
                       (xs, q, ref) -> tail_floor(xs, q; ref),
                       (xs, q, ref) -> begin
                           isempty(xs) && return 0.0
                           any(<(ref), xs) && return ref + sum(min(0.0, x - ref) for x in xs)
                           s = sort(collect(Float64, xs))
                           m = max(1, min(ceil(Int, clamp(q, 0.0, 1.0) * length(s)), length(s)))
                           mean(s[1:m])
                       end) == (guard = 0, value = 0)
    @test differential(:eb_credence,
                       r -> (rand(r) < 0.05 ? hostile(r) : 6.0 * randn(r),
                             rand(r) < 0.05 ? hostile(r) : 4.0 * rand(r) - 0.2,
                             rand(r) < 0.05 ? hostile(r) : 6.0 * randn(r),
                             rand(r) < 0.05 ? hostile(r) : 4.0 * rand(r) - 0.2,
                             rand(r) < 0.05 ? hostile(r) : 0.4 + 0.7 * rand(r)),
                       (pr, ev, pm, pv, cp) -> all(isfinite, (pr, ev, pm, pv, cp)) && ev >= 0 && pv >= 0 && 0.5 <= cp <= 1,
                       (pr, ev, pm, pv, cp) -> eb_credence(pr, ev, pm, pv; cap = cp),
                       (pr, ev, pm, pv, cp) -> begin
                           w = pv <= 0 ? 0.0 : (ev <= 0 ? 1.0 : pv / (pv + ev))
                           pm_post = w * pr + (1 - w) * pm
                           pv_post = (pv <= 0 || ev <= 0) ? 0.0 : pv * ev / (pv + ev)
                           credence(pm_post, sqrt(pv_post); cap = cp)
                       end) == (guard = 0, value = 0)
    @test differential(:g_choose_lexical_fr,
                       r -> begin
                           k = rand(r, 0:6)
                           vals = [rand(r) < 0.05 ? hostile(r) : 5.0 * randn(r) for _ in 1:k]
                           dsc = [rand(r) < 0.05 ? hostile(r) : (rand(r, Bool) ? 0.0 : 2.0 * randn(r)) for _ in 1:k]
                           dmu = [rand(r) < 0.05 ? hostile(r) : (rand(r, Bool) ? 0.0 : 2.0 * randn(r)) for _ in 1:k]
                           dmh = [rand(r) < 0.05 ? hostile(r) : (rand(r, Bool) ? 0.0 : 2.0 * randn(r)) for _ in 1:k]
                           dpu = [rand(r) < 0.05 ? hostile(r) : (rand(r, Bool) ? 0.0 : 2.0 * randn(r)) for _ in 1:k]
                           frok = rand(r, Bool, k)
                           if rand(r) < 0.05 && k > 0
                               dsc = dsc[1:max(0, k - 1)]
                           end
                           (vals, dsc, dmu, dmh, dpu, frok)
                       end,
                       (vals, dsc, dmu, dmh, dpu, frok) -> allequal(length.((vals, dsc, dmu, dmh, dpu, frok))) &&
                           all(c -> all(isfinite, c), (vals, dsc, dmu, dmh, dpu)),
                       (vals, dsc, dmu, dmh, dpu, frok) -> begin
                           i, deg = g_choose_lexical_fr(vals, dsc, dmu, dmh, dpu, frok)
                           [i === nothing ? 0.0 : Float64(i), deg ? 1.0 : 0.0]
                       end,
                       (vals, dsc, dmu, dmh, dpu, frok) -> begin
                           adm = [dsc[i] >= 0 && dmu[i] >= 0 && dmh[i] >= 0 && dpu[i] >= 0 for i in eachindex(vals)]
                           s1 = [i for i in eachindex(vals) if adm[i] && frok[i]]
                           if !isempty(s1)
                               best = s1[argmax([vals[i] for i in s1])]
                               [Float64(best), 0.0]
                           else
                               s2 = [i for i in eachindex(vals) if adm[i]]
                               best = isempty(s2) ? 0.0 : Float64(s2[argmax([vals[i] for i in s2])])
                               [best, 1.0]
                           end
                       end) == (guard = 0, value = 0)
end
