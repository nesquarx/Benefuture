# Toy model M4: governed thresholds (SigThGv, L157; `Systems.ParamSpace` [R]). The parameter vector
# starts at the bootstrap point; non-debatable parameters are perturbed: a candidate within δ of the
# current vector in every governed field is adopted only if admissible (`perturb_step`). Adaptation
# is experimental design (author ruling, BACKPROPAGATION 8.22): each round tries the incumbent and
# perturbed candidates within the freedom range, interleaved over epochs, observes the outcome they
# aim to improve (the floors' movement), and shifts to the best only if it beats the incumbent by
# `gov_z` standard errors (Lean `select_candidate_ref`).

@testset "Candidate selection (Lean reference)" begin
    @test select_candidate([1.0, 3.0], [0.1, 0.1]; z = 1.0) == 2
    @test select_candidate([1.0, 3.0], [2.0, 2.0]; z = 1.0) == 1      # not significant: keep the incumbent
    @test select_candidate([1.0, 2.0, 4.0, 3.0], [0.1, 0.1, 0.1, 0.1]; z = 1.0) == 3
    @test select_candidate([5.0, 2.0, 4.0], [0.1, 0.1, 0.1]; z = 0.0) == 1  # the incumbent is best
    @test_throws ArgumentError select_candidate([1.0, 2.0], [0.1]; z = 1.0)
    # Gauging the freedom range: harm found within the radius halves it, none found doubles it.
    @test gauge_radius(0.1, true; factor = 2.0) ≈ 0.05 && gauge_radius(0.1, false; factor = 2.0) ≈ 0.2
    @test_throws ArgumentError gauge_radius(0.1, true; factor = 1.0)
end

@testset "Parameter space (Lean reference): acceptance" begin
    pv = bootstrap_params()
    @test length(pv) == length(PARAM_FIELDS) && admissible(pv)
    near = copy(pv); near[1] += 0.01                       # α within δ and still below 1
    @test perturb(pv, near, [1]; δ = 0.02) == near
    far = copy(pv); far[1] += 0.05
    @test perturb(pv, far, [1]; δ = 0.02) == pv            # beyond δ: rejected
end

@testset "Parameter space (Lean reference): adversarial and edge cases" begin
    pv = bootstrap_params()
    bad = copy(pv); bad[2] = pv[1] + 0.01                  # β above α breaks L11's order
    @test !admissible(bad) && perturb(pv, bad, [2]; δ = 1.0) == pv
    @test !admissible(setindex!(copy(pv), 0.9, 6))         # q₊ must exceed 1 (L13: depth over breadth)
    # Mistakes decay slower than wins (author ruling 8.29: ledger asymmetry): λ₋ < λ₊.
    @test pv[15] < pv[14] && !admissible(setindex!(copy(pv), pv[14], 15))
    # Bounded drift, numerically: n perturbation steps move each field by at most n·δ.
    r = Xoshiro(1); cur = copy(pv)
    for _ in 1:200
        cur = perturb(cur, cur .+ 0.03 .* (2 .* rand(r, length(cur)) .- 1), [1, 2, 3, 8]; δ = 0.02)
        @test admissible(cur)
    end
    @test all(abs.(cur[[1, 2, 3, 8]] .- pv[[1, 2, 3, 8]]) .<= 200 * 0.02 + 1e-12)
    @test_throws ArgumentError perturb(pv, pv[1:3], [1]; δ = 0.02)
end

gov(; steps = 300, kw...) = M3cParams(ToyParams(n = 80, steps = steps, plans = 10), [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:4],
                         [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true, govern = true, kw...)

@testset "M4: acceptance" begin
    tr = run_m3c(gov(adapt = false); seed = 1)
    @test all(admissible, tr.params) && length(tr.params) > 2
    @test any(tr.params[k] != tr.params[1] for k in 2:length(tr.params))
    epochs = length(tr.params) - 1
    @test all(abs.(tr.params[end] .- tr.params[1]) .<= epochs * 0.02 + 1e-12)
    # Experimental design: rounds of candidates × trials epochs; every candidate admissible.
    tr = run_m3c(gov(steps = 650, gov_epoch = 25, gov_candidates = 3, gov_trials = 4); seed = 1)
    @test tr.rounds == 2 && length(tr.params) == tr.rounds + 1 && all(admissible, tr.tried)
    @test length(tr.tried) == 2 * 3 && tr.shifts <= tr.rounds
    # The freedom radius is gauged each round (8.22).
    @test length(tr.radii) == tr.rounds + 1 && all(>(0), tr.radii)
    @test tr == run_m3c(gov(steps = 650, gov_epoch = 25, gov_candidates = 3, gov_trials = 4); seed = 1)
end

@testset "M4: adversarial and edge cases" begin
    tr = run_m3c(gov(gov_δ = 0.0); seed = 2)
    @test all(==(tr.params[1]), tr.params) && tr.shifts == 0
    # Where the parameters make no measurable difference, selection does not chase noise: across
    # seeds, shifts are rare (the floor-based rule it replaces shifted half the time).
    runs = [run_m3c(gov(steps = 650, gov_epoch = 25); seed) for seed in 1:4]
    @test sum(r.shifts for r in runs) <= 2
    # Nor does gauging find harm where there is none: across seeds the radius widens.
    @test sum(log2(r.radii[end] / r.radii[1]) for r in runs) > 0
    @test_throws ArgumentError gov(gov_epoch = 0)
    @test_throws ArgumentError gov(gov_trials = 1)
    @test_throws ArgumentError gov(gov_gauge = 0.5)
end
