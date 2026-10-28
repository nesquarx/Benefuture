# Toy model M3e: a world that moves on its own (author rulings, BACKPROPAGATION 8.15, 8.17).
# Hazards arise in domains and harm beings unless prevented. A guardian bound by contract (a law
# once communicated counts) is committed to prevent hazards in its domain when informed; not
# acting is assessed against that committed action, so its harm falls to the guardian: a crime if
# informed (L115: Informed(Volition ∨ Inaction)), an accident if not; penalties fund repair either
# way. Unguarded hazards have no contributor: a bystander is not penalised. Actions may create
# hazards as side effects: direct harm, a crime if foreseen, an accident if not, repaired either way.

hz(guardians; agents = [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:4], kw...) =
    M3cParams(ToyParams(n = 80, steps = 150, plans = 10), agents, [1, 1, 2, 2], trues(4); λpos = 0.02, λneg = 0.05,
              transactions = true, causal_distribution = true, p_hazard = 0.5, guardians, kw...)

@testset "Crime rule (Lean reference)" begin
    @test is_crime(true, true, false) && is_crime(true, false, true)
    @test !is_crime(false, true, true) && !is_crime(true, false, false)
end

@testset "M3e: acceptance" begin
    # A diligent, informed guardian prevents every hazard in its domains.
    tr = run_m3c(hz([1, 1, 1, 1]; p_informed = 1.0); seed = 1)
    @test tr.hazards > 0 && tr.prevented == tr.hazards && tr.crimes == 0 && tr.accidents == 0
    # Preventing is paid as duty well done (author ruling 8.22): a duty payment, and nothing else.
    # Its basis is the harm avoided, at the governed duty rate; it never takes the value saved.
    @test tr.duty_paid > 0 && tr.duty_paid ≈ 0.05 * tr.prevented_value && tr.duty_paid < tr.prevented_value
    # A prevention that shocks the beings it protects is clawed back from the guardian.
    shocked = run_m3c(hz([1, 1, 1, 1]; p_informed = 1.0, p_shock = 1.0, shock_size = 0.2); seed = 1)
    @test shocked.shocks > 0 && shocked.credit_neg[1] < 0
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
    # The books balance: penalties for hazards are destroyed (or fund repair), nothing else moves.
    tr = run_m3c(hz([1, 2, 3, 4]; p_informed = 0.5, diligence = [0.5, 0.5, 0.5, 0.5]); seed = 4)
    @test sum(tr.balance) - tr.endowed ≈ sum(tr.valued_measured) - sum(tr.costs) - sum(tr.lane_costs) -
                                       sum(tr.reinvested) - tr.hazard_debits + tr.duty_paid
    @test all(recount(tr) .≈ (tr.h_pos_own, tr.h_neg_own, tr.relevance_own))
    @test_throws ArgumentError hz([1, 1]; p_informed = 1.0)
    @test_throws ArgumentError hz([9, 1, 1, 1])
    @test_throws ArgumentError hz([1, 1, 1, 1]; repair_efficiency = 1.5)
end
