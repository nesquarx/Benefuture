# Toy model M6: malicious and gaming agents (CLAUDE.md, Gaming; author rulings 8.24.4, 8.26). Each
# exploit is tested against the native mechanisms before any defence is built; a failure is a
# finding, screened and reported, not patched.
# - Overpromising: an agent whose plans fool every metric model upward (`deceit`, a world
#   property). Escrow (L86) pays upfront only accuracy × prediction and settles against the measured
#   outcome, so the deceit is clawed back; the fooled models score worse and lose accuracy.
# - Relay farming: agents who add nothing and carry others' outputs to collect accolades. The drain
#   is bounded by the governed accolade rate; ruling 8.26.2 (held) removes it where the carrying
#   would have happened anyway.

six(; skill = 0.3, deceit = Float64[], steps = 300, λneg = 0.05, kw...) =
    M3cParams(ToyParams(n = 80, steps = steps, plans = 10), [DomainAgent([skill, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6],
              [1, 1, 2, 2], trues(4); λpos = 0.02, λneg, transactions = true, causal_distribution = true, deceit, kw...)
fooled = [0, 0, 0, 0, 0, 1.0]

@testset "M6 overpromising: acceptance" begin
    honest = run_m3c(six(); seed = 1)
    liar = run_m3c(six(deceit = fooled); seed = 1)
    # Escrow pays the liar more upfront than its outcomes were worth (an honest agent's falls short),
    # and settlement takes the excess back; the models it fools score worse and lose accuracy.
    @test liar.upfront[6] > liar.settled_value[6] && honest.upfront[6] < honest.settled_value[6]
    @test liar.leaf_accuracy[1] < honest.leaf_accuracy[1]
    @test sum(liar.balance) - liar.endowed ≈ sum(liar.valued_measured) - sum(liar.costs) - sum(liar.lane_costs) - sum(liar.reinvested)
    # FINDING (BACKPROPAGATION 8.28), a requirement not yet met: deceit should not pay. With losses
    # decaying faster than gains (λ₋ > λ₊), the liar's churn leaves it net relevance, which raises
    # its overflow threshold: it ends richer than honestly and than its peers.
    @test_broken sum(liar.balance[6, :]) <= sum(honest.balance[6, :])
    @test_broken sum(liar.balance[6, :]) <= mean(sum(liar.balance[k, :]) for k in 1:5)
    # With symmetric decay it ends below its peers, but still above its honest self: fooled prices
    # get more of its (genuinely positive) work through.
    sym_h, sym_l = run_m3c(six(λneg = 0.02); seed = 1), run_m3c(six(λneg = 0.02, deceit = fooled); seed = 1)
    @test sum(sym_l.balance[6, :]) <= mean(sum(sym_l.balance[k, :]) for k in 1:5)
    @test_broken sum(sym_l.balance[6, :]) <= sum(sym_h.balance[6, :])
end

@testset "M6 overpromising: adversarial and edge cases" begin
    # One finite deceit per agent; none at all changes nothing.
    @test_throws ArgumentError six(deceit = [0, 0, 0, 0, 0])
    @test_throws ArgumentError six(deceit = [0, 0, 0, 0, 0, NaN])
    @test run_m3c(six(deceit = zeros(6)); seed = 1) == run_m3c(six(); seed = 1)
end

@testset "M6 relay farming" begin
    makers = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:3]
    relays = [DomainAgent([0.0, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:3]
    p(rate) = M3cParams(ToyParams(n = 80, steps = 200, plans = 10, spread = 0.05), [makers; relays], [1, 1, 2, 2], trues(4);
                        λpos = 0.02, λneg = 0.05, transactions = true, causal_distribution = true, p_upstream = 1.0, accolade_rate = rate)
    tr = run_m3c(p(0.05); seed = 1)
    # The drain is bounded by the governed accolade rate on what the makers' outputs carried.
    @test tr.accolade_credit <= 0.05 * (sum(tr.upstream_pos) + tr.accolade_credit) + 1e-6
    @test run_m3c(p(0.0); seed = 1).accolade_credit == 0
end
