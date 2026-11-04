# L3.1: arms of the long-horizon world differ only in mechanism fields.
using Test, BenefutureSim
withenv("BF_WORLD_ONLY" => "1") do
    include(joinpath(@__DIR__, "..", "battery", "long_horizon.jl"))
end
@testset "world: bf vs status_quo differ only in mechanisms" begin
    for seed in 1:2, stress in (:stressed, :unstressed)
        a = world(seed; arm = :bf, stress = stress, steps = 100, decisions = 50)
        b = world(seed; arm = :status_quo, stress = stress, steps = 100, decisions = 50)
        for f in fieldnames(M3cParams)
            f in Main.ECON_MECHANISM_FIELDS && continue
            @test getfield(a.econ, f) == getfield(b.econ, f)
        end
        @test any(f -> getfield(a.econ, f) != getfield(b.econ, f), Main.ECON_MECHANISM_FIELDS)
        @test a.econ.accuracy_rule == :decay && b.econ.accuracy_rule == :window
        @test !b.econ.advap && b.econ.ratchet_k == 0 && b.econ.credence_rule == :normal
        @test any(s -> s.kind == :breakthrough, a.econ.events)
        @test any(s -> s.kind == :breakthrough, b.econ.events)
        ta = run_m3c(a.econ; seed); ga = a.gov(ta); gb = b.gov(ta)
        for f in fieldnames(M5Params)
            f in Main.GOV_MECHANISM_FIELDS && continue
            @test getfield(ga, f) == getfield(gb, f)
        end
        @test ga.advap && !gb.advap
        @test all(x.sloppiness == CALIBRATED.sloppiness for x in a.econ.agents)
    end
    # stress arms: same world apart from catastrophes, outages, capture
    s = world(1; stress = :stressed).econ; u = world(1; stress = :unstressed).econ
    @test s.p_hazard == u.p_hazard && s.p_side == u.p_side && s.deceit == u.deceit
    @test count(e -> e.kind == :breakthrough, s.events) == count(e -> e.kind == :breakthrough, u.events) == 3
    @test length(s.events) > length(u.events)
end
