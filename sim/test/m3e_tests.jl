# Toy model M3e: a world that moves on its own (author rulings, BACKPROPAGATION 8.15, 8.17).
# Hazards arise in domains and harm beings unless prevented. A guardian bound by contract (a law
# once communicated counts) is committed to prevent hazards in its domain when informed; not
# acting is assessed against that committed action, so its harm falls to the guardian: a crime if
# informed (L115: Informed(Volition ∨ Inaction)), an accident if not; penalties fund repair either
# way. Unguarded hazards have no contributor: a bystander is not penalised. Actions may create
# hazards as side effects: direct harm, a crime if foreseen, an accident if not, repaired either way.

hz(guardians; agents = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:4], kw...) =
    M3cParams(ToyParams(n = 80, steps = 150, plans = 10), agents, [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02,
              transactions = true, causal_distribution = true, p_hazard = 0.5, guardians, kw...)

@testset "Crime rule (Lean reference)" begin
    @test is_crime(true, true, false) && is_crime(true, false, true)
    @test !is_crime(false, true, true) && !is_crime(true, false, false)
end

@testset "M3e: acceptance" begin
    # A diligent, informed guardian prevents every hazard in its domains.
    tr = run_m3c(hz([1, 1, 1, 1]; p_informed = 1.0); seed = 1)
    @test tr.hazards > 0 && tr.prevented == tr.hazards && tr.crimes == 0 && tr.accidents == 0
    # A prevention is no special payment (author rulings 8.22, 8.24): it is the guardian's action,
    # recorded with its measured outputs, which mint currency as any outcome does. Assessed against
    # the committed action, the averted harm is no output: a skilled guardian earns from its skill
    # alone, an unskilled one nothing, and a shock to those it protects is its own negative output.
    @test 0 < tr.prevention_records <= tr.prevented && tr.prevention_measured > 0
    @test run_m3c(hz([1, 1, 1, 1]; p_informed = 1.0, hazard_size = 5.0); seed = 1).prevention_measured == tr.prevention_measured
    shocked = run_m3c(hz([1, 1, 1, 1]; p_informed = 1.0, p_shock = 1.0, shock_size = 0.2); seed = 1)
    @test shocked.shocks > 0 && shocked.prevention_measured < tr.prevention_measured
    # An informed guardian who does not act commits a crime each time, and is penalised.
    tr = run_m3c(hz([1, 1, 1, 1]; p_informed = 1.0, diligence = [0.0, 1, 1, 1]); seed = 1)
    @test tr.crimes == tr.hazards > 0 && tr.accidents == 0 && tr.credit_neg[1] < 0
    # Uninformed, the same harm is an accident: still penalised, to fund repair.
    tr = run_m3c(hz([1, 1, 1, 1]; p_informed = 0.0); seed = 1)
    @test tr.accidents == tr.hazards > 0 && tr.crimes == 0 && tr.credit_neg[1] < 0
    # Penalties fund repair: with full repair efficiency, the harm repaired equals the harm penalised.
    tr = run_m3c(hz([1, 1, 1, 1]; p_informed = 0.0, repair_efficiency = 1.0); seed = 1)
    @test tr.repaired ≈ tr.hazard_penalties > 0
    # Created hazards: foreseen ones are crimes, unforeseen ones accidents; their actors are penalised.
    tr = run_m3c(hz(zeros(Int, 4); p_hazard = 0.0, p_side = 1.0, p_foresee = 1.0); seed = 2)
    @test tr.side_hazards > 0 && tr.crimes == tr.side_hazards && tr.accidents == 0
    tr = run_m3c(hz(zeros(Int, 4); p_hazard = 0.0, p_side = 1.0, p_foresee = 0.0); seed = 2)
    @test tr.accidents == tr.side_hazards > 0 && tr.crimes == 0
end

@testset "M3e: adversarial and edge cases" begin
    # Unguarded hazards have no contributor: harm is unattributed and no bystander is penalised.
    tr = run_m3c(hz(zeros(Int, 4)); seed = 3)
    @test tr.unattributed > 0 && tr.crimes == 0 && tr.accidents == 0 && tr.hazard_penalties == 0
    # The administration insures unassigned harm through the commons, to its capability (author
    # rulings 8.22, 8.26; L119 Liability ranks it before beings). The commons is funded by resource
    # accounting: the resource costs paid for work. Repair never draws more than it holds; with no
    # resource costs it holds nothing and nothing is repaired; balance overflow does not feed it.
    rich = run_m3c(hz(zeros(Int, 4); repair_efficiency = 1.0, overflow_base = Inf); seed = 3)
    @test rich.insured > 0 && sum(rich.reinvested) == 0 && rich.commons_spent <= sum(rich.costs) + sum(rich.lane_costs) + 1e-9
    poor = run_m3c(hz(zeros(Int, 4); repair_efficiency = 1.0, cost_per_touch = 0.0, overflow_base = 5.0, overflow_factor = 0.0); seed = 3)
    @test poor.insured == 0 && sum(poor.reinvested) > 0
    # Repair is a transaction priced like any other (L86; author ruling 8.26): resource cost less the
    # predicted good its qualified currencies credit. That pays for part of it; the commons pays
    # only the rest, and banks no surplus (an insurer must not profit from unassigned harm).
    @test rich.self_funded > 0 && rich.commons_spent < rich.repair_cost
    # The realistic case (author): mildly inaccurate models. Repair's predicted good still covers its
    # resource cost, so the commons is barely touched.
    mild = run_m3c(hz(zeros(Int, 4); repair_efficiency = 1.0, overflow_base = Inf, σ_leaf = 0.75, σ_branch = 0.9, σ_coarse = 1.0, bias_σ = 0.3); seed = 3)
    @test mild.self_funded > 0.9 * mild.repair_cost && mild.commons_spent < 0.1 * mild.repair_cost
    blind_models = run_m3c(hz(zeros(Int, 4); repair_efficiency = 1.0, overflow_base = Inf, threshold = 0.99, novel_threshold = 0.99); seed = 3)
    # With no qualified model, nothing is self-funded: all that is repaired, the commons paid for.
    @test blind_models.self_funded < 1e-9 && blind_models.insured ≈ blind_models.commons_spent > 0
    @test sum(rich.balance) - rich.endowed ≈ sum(rich.valued_measured) - sum(rich.costs) - sum(rich.lane_costs) -
                                             sum(rich.reinvested) - rich.hazard_debits + rich.prevention_measured atol = 1e-6
    # The books balance: penalties for hazards are destroyed (or fund repair), nothing else moves.
    tr = run_m3c(hz([1, 2, 3, 4]; p_informed = 0.5, diligence = [0.5, 0.5, 0.5, 0.5]); seed = 4)
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) -
                                       sum(tr.reinvested) - tr.hazard_debits + tr.prevention_measured
    @test all(recount(tr) .≈ (tr.h_pos_own, tr.h_neg_own, tr.relevance_own))
    @test_throws ArgumentError hz([1, 1]; p_informed = 1.0)
    @test_throws ArgumentError hz([9, 1, 1, 1])
    @test_throws ArgumentError hz([1, 1, 1, 1]; repair_efficiency = 1.5)
end
