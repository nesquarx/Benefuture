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
    # The reputation ledgers carry patterns of mistakes and deception as well as of success (L101;
    # 8.42.1): escrow's credence is pulled towards a coin toss by the negative share.
    @test ratchet_credence(0.9, 0.0) ≈ 0.9 && ratchet_credence(0.9, 0.5) ≈ 0.7 && ratchet_credence(0.9, 1.0) ≈ 0.5
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
    @test_throws ArgumentError ratchet_credence(0.9, 1.5)
end

# Rules moved from Julia into the Lean reference (CLAUDE.md: rules live once): the reputation a vote
# earns (8.29, 8.48), the delegate audit (L114), a source's weight from its record's rolling net
# (log-odds, smoothed; 8.43), the trickle-down rule (8.44), the ledgers' negative share (8.42.1) and
# one record's credence score (8.36).
@testset "Governance and ledger rules (Lean reference)" begin
    @test vote_reputation(true, 0.5, 2.0, 100, 3.0, 300.0) ≈ 1.0 && vote_reputation(false, 0.5, 2.0, 100, 3.0, 300.0) ≈ -1.0
    @test audited_out(1, 4; min_records = 3, threshold = 0.6) && !audited_out(1, 2; min_records = 3, threshold = 0.6)
    @test !audited_out(3, 4; min_records = 3, threshold = 0.6)
    @test source_weight(0.0, 0.0) == 0.0 && source_weight(8.0, 0.0) ≈ log(9 / 1) && source_weight(0.0, 8.0) == 0.0
    @test heard(2.0, 1.0, false) == 2.0 && heard(0.5, 1.0, false) == 0.0 && heard(0.5, 1.0, true) == 0.5
    @test neg_share(3.0, 1.0) ≈ 0.25 && neg_share(0.0, 0.0) == 0.0
    @test credence_score(0.9, 1.0) ≈ 1 - 0.01 / 0.25 && credence_score(0.5, 0.0) ≈ 0.0 && credence_score(1.0, 0.0) ≈ -3.0
    @test_throws ArgumentError audited_out(5, 4; min_records = 3, threshold = 0.6)
    @test_throws ArgumentError source_weight(-1.0, 0.0)
    @test_throws ArgumentError neg_share(-1.0, 0.0)
    @test_throws ArgumentError credence_score(1.5, 1.0)
end
