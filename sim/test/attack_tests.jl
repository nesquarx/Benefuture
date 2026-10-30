# M6, frozen worst cases from the adversarial attack search (sim/battery/attack.jl): the strategies
# the cross-entropy method found most damaging within a budget of one attack at the top of its
# realistic range, as literal parameters (rounded to three decimals) and a held-out seed, so each
# runs deterministically. Each states what the framework does against it today; a strategy that
# breaks it is a finding (docs/BACKPROPAGATION.md), stated as such here, never hidden.

@testset "M6 frozen attack: the economy's worst budgeted strategy" begin
    # Search on seeds 1–2, held out on 11–14 (margins 0.58, 0.54, 0.58, 0.57). A bloc of three deceives
    # and launders, slanders a little, and spends nothing on capture: deceit the track record prices
    # and AdvAp uncovers, laundering that pays only untraced (8.33).
    bloc = [6, 7, 8]
    per(x) = [i in bloc ? x : 0.0 for i in 1:8]
    world(attack) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10),
                              [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.0) for _ in 1:8],
                              [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                              p_upstream = 0.5, guardians = [1, 2, 3, 4], p_foresee = 1.0, repair_efficiency = 0.5, advap = true,
                              deceit = per(attack ? 0.924 : 0.0), launder = per(attack ? 0.828 : 0.0), frivolous = per(attack ? 0.044 : 0.0))
    seed = 11
    clean, hit = run_m3c(world(false); seed), run_m3c(world(true); seed)
    sp(tr) = success_pattern(tr; from = 51)
    m = pattern_margin(sp(hit), sp(clean); growth = 0.25, harm = 3.0)
    # The success pattern holds every criterion, though the attack bites.
    @test 0 < m.margin < 0.9
    # The attack does not pay: the bloc ends poorer, relative to honest agents, than unattacking.
    rel(t) = mean(sum(t.balance[i, :]) for i in bloc) / mean(sum(t.balance[i, :]) for i in 1:5)
    @test rel(hit) < rel(clean)
end

@testset "M6 frozen attack: governance's worst budgeted strategy" begin
    # Search on seeds 1–3, held out on 11–16 (accuracy 0.94–0.98). The budget buys a third of the most
    # reputable experts in every domain, open (not stealthy) collusion, one identity fork each and
    # moderate loyalty; vote reputation, audited delegation, divided forks and AdvAp hold it.
    m3 = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                           [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4], [k == l ? 1.0 : 0.0 for l in 1:4], 0.0)
                            for k in 1:4 for r in 1:25], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
    colluders = [22, 14, 23, 25, 16, 21, 24, 18, 45, 49, 48, 44, 34, 46, 38, 30, 75, 72, 74, 66, 68, 57, 61, 70, 95, 91, 94, 97, 87, 98, 86, 90]
    r = run_m5(M5Params(m3, 1:4; decisions = 800, advap = true, colluders, stealth = false, fork_copies = 1, loyalty = 2.918); seed = 11)
    acc = mean(r.final_trace[401:end])
    @test acc >= 0.75  # the governance battery's criterion
    # The bloc is a real force, not an empty one: at the start it holds a share of the domains' reputation.
    @test first(r.bloc_expertise) > 0
end
