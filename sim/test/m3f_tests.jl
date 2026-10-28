# Catastrophes and black swans (author rulings, BACKPROPAGATION 8.22.4, 8.23; L142 Af, L150
# Harm_Intv, L154 Progressive). Shocks are world events. Benefuture must keep acting through each,
# falling back to simpler means where a capability is lost, and recover when it returns:
# - a measurement outage: no markers, so settlement falls back to escrow's prediction-based upfront
#   (L86), G screens on the last observation, and actions are logged unmeasured;
# - a catastrophe: one large hazard;
# - metric capture: a leaf's model turns biased; scoring costs it eligibility and pricing falls back
#   to its parents (L82, fallback by μ);
# - a breakthrough: an agent's skill jumps, and its work is put to use.

base(; steps = 300, kw...) = M3cParams(ToyParams(n = 80, steps = steps, plans = 10),
                                       [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.0) for _ in 1:6],
                                       [1, 1, 2, 2], trues(4); λpos = 0.02, λneg = 0.05, transactions = true,
                                       causal_distribution = true, kw...)
balanced(tr) = sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) -
                                               sum(tr.reinvested) - tr.hazard_debits + tr.prevention_measured

@testset "Black swans: acceptance" begin
    # Measurement outage: work goes on, paid by prediction; nothing is measured, credited or
    # scored while it lasts; measurement resumes after.
    tr = run_m3c(base(events = [shock(:outage; step = 100, duration = 50)]); seed = 1)
    during = [m for m in tr.memory if 100 <= m.step < 150]
    @test !isempty(during) && all(m -> isnan(m.measured) && isempty(m.credits), during)
    @test any(m -> m.step >= 150 && !isnan(m.measured), tr.memory)
    @test count(s -> 100 <= s < 150, tr.chosen_step) > 0 && balanced(tr)
    @test tr.floor_u[151] >= tr.floor_u[100]  # degraded, not collapsed
    # Catastrophe: one hazard harming half the beings by about 40 steps of floor growth; the floor
    # drops and recovers; the administration, repairing from the commons at resource cost, restores
    # it at once.
    cat = shock(:catastrophe; step = 150, share = 0.5, size = 30.0)
    hit = run_m3c(base(events = [cat]); seed = 1)
    @test hit.floor_u[152] < hit.floor_u[150] - 10 && hit.floor_u[end] > hit.floor_u[150]
    insured = run_m3c(base(events = [cat], repair_efficiency = 1.0, overflow_base = 5.0, overflow_factor = 0.0); seed = 1)
    @test insured.insured > 0 && insured.floor_u[152] >= insured.floor_u[150] && insured.floor_u[200] > hit.floor_u[200] + 10
    # Metric capture: leaf 1's model turns biased; it loses eligibility and its work is priced by
    # its parent; when the capture ends it qualifies again.
    tr = run_m3c(base(steps = 400, events = [shock(:capture; step = 100, duration = 150, size = 3.0, target = 1)]); seed = 1)
    share_at(r) = (k = [i for i in eachindex(tr.chosen_step) if tr.true_leaf[i] == 1 && tr.chosen_step[i] in r];
                   mean(tr.priced_leaf[k] .== 1))
    @test share_at(150:249) < share_at(51:99) - 0.3 && share_at(300:400) > share_at(150:249) + 0.3
    # Breakthrough: agent 1's skill rises by 1 everywhere it works; its measured outcomes rise.
    tr = run_m3c(base(events = [shock(:breakthrough; step = 150, duration = 150, size = 1.0, target = 1)]); seed = 1)
    mine(r) = mean(m.measured for m in tr.memory if m.agent == 1 && m.step in r)
    @test mine(150:300) > mine(51:149) + 1
end

@testset "Black swans: adversarial and edge cases" begin
    # An outage for the whole run after the start: nothing crashes, nothing is credited, the books balance.
    tr = run_m3c(base(events = [shock(:outage; step = 51, duration = 250)]); seed = 2)
    @test balanced(tr)
    @test all(m -> isnan(m.measured) && isempty(m.credits), filter(m -> m.step >= 51, tr.memory))
    @test isequal(tr, run_m3c(base(events = [shock(:outage; step = 51, duration = 250)]); seed = 2))
    @test_throws ArgumentError shock(:meteor; step = 10)
    @test_throws ArgumentError shock(:outage; step = 10, duration = 0)
    @test_throws ArgumentError base(events = [shock(:capture; step = 10, size = 1.0, target = 9)])
end
