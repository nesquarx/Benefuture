# Adversarial adaptation (AdvAp, L160; Adversarial adaptation article; Lean
# `Governance.Adversarial`): revealing successful gaming pays more than exploiting it, the reward and
# the audit are charged down the exploit's causal chain, and good-faith reports cost nothing unless
# they form a frivolous pattern. Rules in the Lean reference (`BenefutureReference.Adversarial`).

@testset "AdvAp rules: acceptance" begin
    # The reward is the exploit's gain plus a share of the harm the revelation prevents, at least a floor.
    @test advap_reward(5.0, 30.0; share = 0.1, floor = 1.0) ≈ 8.0
    @test advap_reward(5.0, 3.0; share = 0.1, floor = 1.0) ≈ 6.0
    for g in (0.0, 1.0, 100.0), h in (0.0, 5.0, 1e3)
        r = advap_reward(g, h; share = 0.1, floor = 1.0)
        # Revelation dominates exploitation (`revelation_strictly_dominates`).
        @test r > g
        # Planting a flaw to report it never pays (`anti_cobra_effect_no_bounty_farming`).
        @test advap_liability(r; audit_cost = 2.0) - r >= 0
    end
    # Good-faith reports that prove unfounded cost nothing; past a pattern, each is charged its audit.
    @test report_penalty(5, 5; audit_cost = 2.0) == 0
    @test report_penalty(6, 5; audit_cost = 2.0) == 2.0
end

@testset "AdvAp rules: adversarial and edge cases" begin
    # Losses are not gains, and harm is not negative.
    @test advap_reward(-5.0, -30.0; share = 0.1, floor = 1.0) ≈ 1.0
    @test advap_reward(0.0, 0.0; share = 0.1, floor = 0.0) == 0.0
    @test_throws ArgumentError advap_reward(NaN, 1.0; share = 0.1, floor = 1.0)
    @test_throws ArgumentError advap_reward(1.0, 1.0; share = -0.1, floor = 1.0)
    @test_throws ArgumentError advap_reward(1.0, 1.0; share = 0.1, floor = -1.0)
    @test_throws ArgumentError advap_liability(1.0; audit_cost = -1.0)
    @test_throws ArgumentError report_penalty(-1, 5; audit_cost = 1.0)
    @test_throws ArgumentError report_penalty(1, 5; audit_cost = Inf)
end
