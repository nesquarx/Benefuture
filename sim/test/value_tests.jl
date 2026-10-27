# Assessment (L48), signed synergy (L13), harm weight (L61) and value on a being (L73).

# Default governed parameters used to generate spec/vectors/value.json (Main.lean).
const GP = (α = 0.8, β = 0.6, γ = 0.4, λ = 0.5, qp = 1.1, qm = 1.5)

@testset "Assessment: acceptance (spec/vectors/assessment.json)" begin
    v = vectors("assessment")
    i = v["inputs"]
    args = (i["predicted"], i["counter"], i["measured"])
    @test assess(args...; t = 15.0, t0 = i["t0"], th = i["th_cx"]) ≈ v["assessment_ex_post_t15"] atol = 1e-6
    @test assess(args...; t = 5.0, t0 = i["t0"], th = i["th_cx"]) ≈ v["assessment_ex_ante_t5"] atol = 1e-6
end

@testset "Assessment: adversarial and edge cases" begin
    # At t = t0 the action has not yet happened: prediction, not measurement.
    @test assess(10.0, 2.0, 7.5; t = 10.0, t0 = 10.0, th = 2.0) == 4.0
    # Not acting assesses to zero.
    @test assess(3.0, 3.0, 3.0; t = 15.0, t0 = 10.0, th = 1.0) == 0.0
    @test_throws ArgumentError assess(1.0, 0.0, 1.0; t = 1.0, t0 = 0.0, th = 0.0)
    @test_throws ArgumentError assess(1.0, 0.0, 1.0; t = 1.0, t0 = 0.0, th = -1.0)
    @test_throws ArgumentError assess(NaN, 0.0, 1.0; t = 1.0, t0 = 0.0, th = 1.0)
end

@testset "Value: acceptance (spec/vectors/value.json)" begin
    v = vectors("value")
    tiers = collect(zip(Float64.(v["harm_tier_magnitudes"]), Float64.(v["harm_schedule"])))
    @test Float64.(v["harm_schedule"]) == HARM_SCHEDULE
    w = harm_weight(tiers; λ = GP.λ)
    @test w ≈ v["harm_weight"] atol = 1e-6
    val(u, w) = value_on_being(u, 1.5, 1.2; harm_wt = w, GP...)
    @test val(2.0, w) ≈ v["value_all_gains"] atol = 1e-6
    @test val(-2.0, w) ≈ v["value_u_loss"] atol = 1e-6
    @test val(-2.0, 1.0) ≈ v["value_u_loss_unit_harm_weight"] atol = 1e-6
end

@testset "Value: adversarial and edge cases" begin
    # No harm means a harm weight of exactly one.
    @test harm_weight([(0.0, 0.9), (0.0, 0.7)]; λ = 0.5) == 1.0
    # More severe harm weighs losses more.
    @test harm_weight([(2.0, 0.9)]; λ = 0.5) > harm_weight([(1.0, 0.9)]; λ = 0.5)
    # A heavier harm weight makes the same loss count more.
    lo = value_on_being(-2.0, 0.0, 0.0; harm_wt = 1.0, GP...)
    hi = value_on_being(-2.0, 0.0, 0.0; harm_wt = 3.0, GP...)
    @test hi < lo < 0
    # Understanding outweighs happiness: an equal gain in U is worth more than in H.
    @test value_on_being(1.0, 0.0, 0.0; harm_wt = 1.0, GP...) >
          value_on_being(0.0, 1.0, 0.0; harm_wt = 1.0, GP...)
    # Nothing changes, nothing is valued.
    @test value_on_being(0.0, 0.0, 0.0; harm_wt = 1.0, GP...) == 0.0
    # Signed synergy splits gains and losses by sign.
    @test signed_synergy([(2.0, 1.0, 5.0)]; λ = 0.5, κ = 2.0, qp = 1.1, qm = 1.5) ≈
          net_synergy([(2.0, 1.0)], []; λ = 0.5, κ = 2.0, qp = 1.1, qm = 1.5)
    @test signed_synergy([(-2.0, 1.0, 5.0)]; λ = 0.5, κ = 2.0, qp = 1.1, qm = 1.5) ≈
          net_synergy([], [(2.0, 5.0)]; λ = 0.5, κ = 2.0, qp = 1.1, qm = 1.5)
    @test_throws ArgumentError harm_weight([(-1.0, 0.9)]; λ = 0.5)
    @test_throws ArgumentError value_on_being(1.0, 0.0, 0.0; harm_wt = 0.5, GP...)
    @test_throws ArgumentError value_on_being(NaN, 0.0, 0.0; harm_wt = 1.0, GP...)
end
