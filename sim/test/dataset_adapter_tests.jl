using Test
using BenefutureSim
using Random
using Statistics

@testset "Task E2: Real-world dataset adapters and empirical validations" begin
    emp = BenefutureSim.load_empirical_calibration()

    @testset "Priority 1: Model pools (COVID-19 Forecast Hub & M4 cross-check)" begin
        mp = emp.model_pool
        @test mp.n_targets >= 25 && mp.n_teams >= 8 && mp.n_arrivals >= 2
        @test 0.05 < mp.p_new_model < 0.5
        @test mp.improve_drift > 0.1 && mp.improve_σ > 0.3
        @test 0.05 < mp.scale_min < 0.3
        @test 0.01 < mp.pinball_median_norm < 0.2
        @test 0.1 < mp.point_error_sd_norm < 0.5
        @test mp.n_learn >= 4.0

        mv = emp.model_validation
        @test mv.best_model_turnover > 0.5
        @test mv.ensemble_vs_median_ratio < 0.92
        @test mv.train_test_spearman > 0.0

        m4 = emp.m4
        @test m4.n_series >= 50
        @test 0.8 < m4.rel_error_median < 1.1
        @test 0.7 < m4.scale_min < 0.9
        @test 0.1 < m4.improve_σ < 0.6

        # Empirical adapter parameters plug directly into existing m3c -> m5 world builders.
        m3p = BenefutureSim.M3cParams(
            BenefutureSim.ToyParams(n = 40, steps = 20, plans = 4),
            [BenefutureSim.DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], BenefutureSim.CALIBRATED.sloppiness) for _ in 1:6],
            [1, 1, 2, 2], trues(4);
            λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, bind_weighted = true,
            p_new_model = mp.p_new_model, improve_drift = mp.improve_drift,
            improve_σ = mp.improve_σ, scale_min = mp.scale_min)
        w_m3 = BenefutureSim.run_m3c(m3p; seed = 1)
        @test length(w_m3.floor_u) == 21 && isfinite(w_m3.floor_u[end])
        w_m5 = BenefutureSim.run_m5(BenefutureSim.M5Params(
            w_m3, 1:4;
            decisions = 20, p_new_model = mp.p_new_model,
            improve_drift = mp.improve_drift, improve_σ = mp.improve_σ, scale_min = mp.scale_min); seed = 1)
        @test isfinite(w_m5.correct) && all(isfinite, w_m5.best_model_σ)
    end

    @testset "Priority 2: Stack Exchange domain network, skill heterogeneity & no-halo validation" begin
        dn = emp.domains
        @test dn.sites == ["cs", "economics", "stats"]
        @test length(dn.tags) == 12
        @test size(dn.μ) == (12, 3)
        @test all(x -> 0.0 <= x <= 1.0, dn.μ)
        @test all(i -> isapprox(sum(dn.μ[i, :]), 1.0; atol = 1e-9), 1:12)
        @test dn.tag_cooccurrence ≈ dn.tag_cooccurrence'
        @test 0.1 < dn.new_tag_rate < 0.95 && dn.n_total_tags >= 200

        sk = emp.skills
        @test sk.n_users >= 300 && sk.n_multi_users >= 50
        @test sk.skill_log_sd > BenefutureSim.CALIBRATED.skill_log_sd + 0.15
        @test sk.n_learn >= 2.0
        @test abs(sk.sampled_skill_log_sd - sk.skill_log_sd) < 0.15

        rv = emp.reputation_validation
        @test rv.n_multi_answer_users >= 50
        @test rv.within_site_spearman > 0.35
        @test rv.within_site_decay_spearman.hl_5 > 0.35
        @test rv.n_high_rep_accounts >= 100
        @test rv.no_halo_floor_share > 0.85
        @test rv.median_max_min_rep_ratio > 20.0
        @test rv.within_site_spearman > rv.stats_econ_rep.spearman + 0.10

        mktempdir() do tmp
            xml_path = joinpath(tmp, "Tags.xml")
            write(xml_path, """
            <?xml version="1.0" encoding="utf-8"?>
            <tags>
              <row Id="1" TagName="regression" Count="15000" />
              <row Id="2" TagName="bayesian" Count="9200" />
            </tags>
            """)
            parsed_tags = BenefutureSim.parse_stackexchange_tags_xml(xml_path)
            @test length(parsed_tags) == 2
            @test parsed_tags[1] == (tag = "regression", count = 15000)
        end
    end

    @testset "Priority 3: Wikipedia edit/revert audit & Geiger-Halfaker bot-outage validation" begin
        au = emp.audit
        @test au.n_edits == 8000 && au.n_reverted >= 50
        @test 0.002 < au.deception_base_rate < 0.1
        @test au.persistent_deception_rate <= au.deception_base_rate
        @test 0.01 < au.p_false_trace < 0.4
        @test 0.0 < au.vigilance < 1.0
        @test au.lag_median_sec < au.lag_p90_sec

        ou = emp.outage
        @test ou.n_bot_reverts >= 3 && ou.n_human_reverts >= 50
        @test ou.bot_lag_median_sec * 4 < ou.human_lag_median_sec
        @test ou.human_lag_median_sec > ou.all_lag_median_sec
        @test ou.human_lag_mean_sec > ou.all_lag_mean_sec
        @test ou.outage_vigilance < ou.baseline_vigilance
        @test ou.human_catch_share > 0.5
        @test ou.human_within_1hr_share > 0.8

        # Empirical audit + pool rates plug cleanly into m3c realistic runner.
        w_m3 = BenefutureSim.run_m3c(BenefutureSim.M3cParams(
            BenefutureSim.ToyParams(n = 40, steps = 20, plans = 4),
            [BenefutureSim.DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], BenefutureSim.CALIBRATED.sloppiness) for _ in 1:6],
            [1, 1, 2, 2], trues(4);
            λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true, bind_weighted = true,
            p_new_model = emp.model_pool.p_new_model,
            improve_drift = emp.model_pool.improve_drift,
            improve_σ = emp.model_pool.improve_σ,
            scale_min = emp.model_pool.scale_min,
            vigilance = au.vigilance,
            p_false_trace = au.p_false_trace); seed = 1)
        @test length(w_m3.floor_u) == 21 && isfinite(w_m3.floor_u[end])

        # MediaWiki history TSV alias schema support
        mktempdir() do tmp
            tsv_path = joinpath(tmp, "mw_history.tsv")
            write(tsv_path, join([
                "revision_is_identity_reverted\trevision_seconds_to_identity_revert\tevent_user_is_bot_by_historical\twas_re_reverted",
                "true\t5\ttrue\tfalse",
                "true\t120\tfalse\tfalse",
                "true\t240\tfalse\ttrue",
                "false\t\tfalse\tfalse",
            ], "\n"))
            mw_rows = BenefutureSim.load_wikipedia_reverts(tsv_path)
            @test length(mw_rows) == 4
            mw_au = BenefutureSim.calibrate_wikipedia_audit(mw_rows)
            mw_ou = BenefutureSim.validate_wikipedia_outage(mw_rows)
            @test mw_au.n_reverted == 3 && isapprox(mw_au.p_false_trace, 1 / 3; atol = 1e-12)
            @test mw_ou.human_lag_median_sec > mw_ou.bot_lag_median_sec
        end
    end

    @testset "Dataset adapter input validation guards" begin
        @test_throws ArgumentError BenefutureSim.calibrate_model_pool(BenefutureSim.QuantileStore())
        @test_throws ArgumentError BenefutureSim.validate_model_pool(BenefutureSim.load_archive_store(); train_frac = 1.0)
        @test_throws ArgumentError BenefutureSim.calibrate_m4_errors(joinpath(BenefutureSim.CALIBRATION_SAMPLE_DIR, "nonexistent.csv"))
        @test_throws ArgumentError BenefutureSim.load_wikipedia_reverts(joinpath(BenefutureSim.CALIBRATION_SAMPLE_DIR, "nonexistent.csv"))
        @test_throws ArgumentError BenefutureSim.parse_stackexchange_tags_xml(joinpath(BenefutureSim.CALIBRATION_SAMPLE_DIR, "nonexistent.xml"))
    end
end

