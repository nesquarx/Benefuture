# Escrow (L84), reputation decay (L101), resource cost and pricing (L82, L83, L86, L99).

@testset "Economy rules: acceptance (spec/vectors)" begin
    e = vectors("escrow")
    @test all(escrow_split(1000.0, 0.7) .≈ (e["case_70_win"]["upfront"], e["case_70_win"]["hold"]))
    @test all(escrow_split(500.0, 0.5) .≈ (e["case_50_win"]["upfront"], e["case_50_win"]["hold"]))
    r = vectors("reputation")
    @test reputation_decay(100.0, 10.0; rate = 0.05) ≈ r["decay_step1"] atol = 1e-6
    @test reputation_decay(reputation_decay(100.0, 10.0; rate = 0.05), 10.0; rate = 0.05) ≈ r["decay_step2"] atol = 1e-6
    @test reputation_decay(100.0, 20.0; rate = 0.05) ≈ r["decay_direct_20"] atol = 1e-6
    p = vectors("pricing")
    phys = [(2.0, 10.0), (1.0, 5.0)]
    light = resource_cost(phys; compute = 1.0, network = 1.0, time = 1.0, compute_cost = 2.0, network_cost = 1.0, time_cost = 3.0)
    heavy = resource_cost(phys; compute = 50.0, network = 1.0, time = 1.0, compute_cost = 2.0, network_cost = 1.0, time_cost = 3.0)
    @test light ≈ p["resource_cost_compute_1"] atol = 1e-6
    @test heavy ≈ p["resource_cost_compute_50"] atol = 1e-6
    @test transaction_price(light, 40.0, 0.8) ≈ p["price_light_credit_40_p_0_8"] atol = 1e-6
    @test transaction_price(heavy, 40.0, 0.8) ≈ p["price_heavy_credit_40_p_0_8"] atol = 1e-6
    @test transaction_price(light, 40.0, 0.0) ≈ p["price_unmodelled_light"] atol = 1e-6
    @test supply_delta(0.0, light, 0.0) ≈ p["supply_delta_no_good_light"] atol = 1e-6
    @test competition_efficiency(100.0, light, 1.0) ≈ p["efficiency_light_dV_100_dt_1"] atol = 1e-6
    @test competition_efficiency(100.0, heavy, 1.0) ≈ p["efficiency_heavy_dV_100_dt_1"] atol = 1e-6
end

@testset "Economy rules: adversarial and edge cases" begin
    # Escrow conserves the nominal amount and pays nothing upfront without confidence.
    for (v, pw) in ((10.0, 0.0), (10.0, 1.0), (-4.0, 0.3))
        up, hold = escrow_split(v, pw)
        @test up + hold ≈ v
    end
    @test escrow_split(10.0, 0.0)[1] == 0.0
    @test_throws ArgumentError escrow_split(10.0, 1.2)
    @test_throws ArgumentError escrow_split(NaN, 0.5)
    # Decay never raises reputation, is the identity at zero elapsed time, and composes.
    @test reputation_decay(50.0, 0.0; rate = 0.1) == 50.0
    @test reputation_decay(50.0, 3.0; rate = 0.1) < 50.0
    @test reputation_decay(reputation_decay(50.0, 1.0; rate = 0.1), 2.0; rate = 0.1) ≈ reputation_decay(50.0, 3.0; rate = 0.1)
    @test_throws ArgumentError reputation_decay(50.0, -1.0; rate = 0.1)
    @test_throws ArgumentError reputation_decay(50.0, 1.0; rate = -0.1)
    # More confidence in the credit lowers the price; heavier compute raises it.
    @test transaction_price(30.0, 40.0, 0.9) < transaction_price(30.0, 40.0, 0.5)
    @test_throws ArgumentError transaction_price(30.0, 40.0, 1.5)
    @test_throws ArgumentError competition_efficiency(1.0, 0.0, 0.0)
    @test_throws ArgumentError resource_cost([(-1.0, 2.0)]; compute = 1.0, network = 1.0, time = 1.0, compute_cost = 1.0, network_cost = 1.0, time_cost = 1.0)
end
