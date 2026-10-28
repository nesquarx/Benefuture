# Toy model M4: governed thresholds (SigThGv, L157; `Systems.ParamSpace` [R]). The parameter vector
# starts at the bootstrap point; non-debatable parameters are perturbed: a candidate within δ of the
# current vector in every governed field is adopted only if admissible (`perturb_step`). Adaptation
# (L52 `adapt«Ap»`; [P], BACKPROPAGATION 8.20) keeps a candidate only if the next epoch's observed
# floors move at least as well as the previous epoch's, else reverts.

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
    # Bounded drift, numerically: n perturbation steps move each field by at most n·δ.
    r = Xoshiro(1); cur = copy(pv)
    for _ in 1:200
        cur = perturb(cur, cur .+ 0.03 .* (2 .* rand(r, length(cur)) .- 1), [1, 2, 3, 8]; δ = 0.02)
        @test admissible(cur)
    end
    @test all(abs.(cur[[1, 2, 3, 8]] .- pv[[1, 2, 3, 8]]) .<= 200 * 0.02 + 1e-12)
    @test_throws ArgumentError perturb(pv, pv[1:3], [1]; δ = 0.02)
end

gov(; kw...) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10), [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:4],
                         [1, 1, 2, 2], trues(4); λpos = 0.02, λneg = 0.05, transactions = true, govern = true, kw...)

@testset "M4: acceptance" begin
    tr = run_m3c(gov(adapt = false); seed = 1)
    @test all(admissible, tr.params) && length(tr.params) > 2
    @test any(tr.params[k] != tr.params[1] for k in 2:length(tr.params))
    epochs = length(tr.params) - 1
    @test all(abs.(tr.params[end] .- tr.params[1]) .<= epochs * 0.02 + 1e-12)
    tr = run_m3c(gov(); seed = 1)
    @test all(admissible, tr.params) && tr.reverted + tr.kept == length(tr.params) - 2  # no decision on the first epoch
    @test tr == run_m3c(gov(); seed = 1)
end

@testset "M4: adversarial and edge cases" begin
    tr = run_m3c(gov(gov_δ = 0.0); seed = 2)
    @test all(==(tr.params[1]), tr.params)
    @test_throws ArgumentError gov(gov_epoch = 0)
end
