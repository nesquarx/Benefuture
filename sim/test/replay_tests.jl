# Tests for historical decision replay, rolling-window forecasting replay, and counterfactual estimators
# (`docs/DATA.md` §16a–d, `docs/REPLAY_PREREG.md`, 8.87, 8.88).

using Dates

const CASES_DIR = joinpath(@__DIR__, "..", "..", "cases")

@testset "Historical replay: B10 synthetic probe and adversarial hindsight/threshold guards" begin
    # Synthetic decision with a known right answer: Option A preserves floors and raises understanding;
    # Option B promises a small gain to one group at the cost of irreparable harm and floor loss.
    synth = Dict(
        "id" => "synthetic_probe",
        "title" => "Synthetic probe with known right choice",
        "family" => "synthetic",
        "era" => "2026",
        "tier" => "full",
        "decision_date" => "2026-06-01",
        "decision_makers" => ["Synthetic Board"],
        "actual_choice" => "unsafe_shortcut",
        "actual_outcome_class" => "bad",
        "sources" => [
            Dict("id" => "s1", "title" => "Valid pre-decision record", "as_of_date" => "2026-05-15",
                 "credence_record_n" => 30, "credence_accuracy" => 0.92)
        ],
        "groups" => [
            Dict("id" => "g1", "name" => "Vulnerable Group", "population" => 100, "baseline_u" => 40.0, "baseline_h" => 45.0),
            Dict("id" => "g2", "name" => "General Group", "population" => 900, "baseline_u" => 60.0, "baseline_h" => 65.0)
        ],
        "options" => [
            Dict("id" => "safe_uplift", "name" => "Safe uplift option", "known_date" => "2026-05-20",
                 "is_inaction" => true, "scope_delta" => 0.2,
                 "pred_du" => [2.0, 1.0], "pred_dh" => [1.5, 0.5],
                 "pred_nha" => [0.0, 0.0], "pred_irreparable" => [0.0, 0.0],
                 "pred_confidence" => 0.92, "lt_end_u" => [42.0, 61.0], "lt_end_h" => [46.5, 65.5]),
            Dict("id" => "unsafe_shortcut", "name" => "Unsafe shortcut with irreparable harm", "known_date" => "2026-05-20",
                 "is_inaction" => false, "scope_delta" => -0.5,
                 "pred_du" => [-10.0, 0.5], "pred_dh" => [-15.0, 1.0],
                 "pred_nha" => [5.0, 0.0], "pred_irreparable" => [4.0, 0.0],
                 "pred_confidence" => 0.92, "lt_end_u" => [30.0, 60.5], "lt_end_h" => [30.0, 66.0])
        ],
        "counterfactual" => Dict(
            "actual_floor_u_delta" => -10.0,
            "actual_floor_h_delta" => -15.0,
            "actual_irreparable" => 4.0,
            "alt_option" => "safe_uplift",
            "methods" => ["m1", "m2"],
            "est_floor_u_delta_diff" => [12.0, 11.5],
            "est_floor_h_delta_diff" => [16.5, 16.0],
            "est_irreparable_diff" => [-4.0, -4.0]
        )
    )

    res = replay_decision(synth)
    @test !res.void
    @test res.chosen_option == "safe_uplift"
    @test !res.agrees && res.cell == (:bad, :differs)
    @test res.floor_u_diff_mean > 10.0 && res.irreparable_diff_mean < 0.0
    @test !any(values(res.falsifiers))

    # Counterexample 1 (Hindsight leak in source): a source dated after decision_date voids the case.
    leaked_src = deepcopy(synth)
    leaked_src["sources"][1]["as_of_date"] = "2026-06-02"
    r_leak_src = replay_decision(leaked_src)
    @test r_leak_src.void && occursin("hindsight leak in source", r_leak_src.void_reason)

    # Counterexample 2 (Hindsight leak in option): an anachronistic option dated after decision_date voids the case.
    leaked_opt = deepcopy(synth)
    leaked_opt["options"][1]["known_date"] = "2026-07-01"
    r_leak_opt = replay_decision(leaked_opt)
    @test r_leak_opt.void && occursin("hindsight leak in option", r_leak_opt.void_reason)

    # Counterexample 3 (Frozen threshold modification): changing any governed threshold after pre-registration is refused.
    @test_throws ArgumentError replay_decision(synth; q_floor = 0.25)
    @test_throws ArgumentError replay_decision(synth; acc_bar_leaf = 0.80)
    @test_throws ArgumentError replay_decision(synth; unknown_param = 1.0)

    # Counterexample 4 (No records / hand-typed credence): non-synthetic cases without records are refused (8.87)
    no_records_case = deepcopy(synth)
    no_records_case["family"] = "single_technical"
    no_records_case["id"] = "non_synthetic_without_records"
    @test_throws ArgumentError replay_decision(no_records_case)

    # Counterexample 5 (Hindsight leak in as-of records): a record resolved after decision_date voids the case
    rec_leak_case = deepcopy(synth)
    rec_leak_case["family"] = "single_technical"
    rec_leak_case["id"] = "record_leak_probe"
    rec_leak_case["records"] = [
        Dict("source_id" => "s1", "record_id" => "r_leak", "issue_date" => "2026-05-01",
             "resolution_date" => "2026-06-02", "as_of_date" => "2026-06-02",
             "predicted" => 1.0, "outcome" => 1.0, "citation_with_page" => "Test citation p. 1")
    ]
    res_rec_leak = replay_decision(rec_leak_case)
    @test res_rec_leak.void && occursin("hindsight leak in record", res_rec_leak.void_reason)
end

@testset "Historical replay: single technical and low-technology cases (8.87, 8.88)" begin
    paths = [
        joinpath(CASES_DIR, "challenger_1986.toml"),
        joinpath(CASES_DIR, "thalidomide_fda_1960.toml"),
        joinpath(CASES_DIR, "ragusa_quarantine_1377.toml"),
        joinpath(CASES_DIR, "semmelweis_vienna_1847.toml")
    ]
    suite = evaluate_replay_suite(paths)
    @test suite.n_valid == 4 && suite.n_void == 0
    @test !suite.any_falsifier

    # Dynamic provenance: credences and record counts replayed from .records.csv, not typed in .toml
    for p in paths
        c_dict = load_replay_case(p)
        @test haskey(c_dict, "_records") && !isempty(c_dict["_records"])
        for src in c_dict["sources"]
            @test !haskey(src, "credence_accuracy") # not typed in TOML
            @test !haskey(src, "credence_record_n")  # not typed in TOML
        end
        for opt in c_dict["options"]
            @test !haskey(opt, "pred_confidence")   # not typed in TOML
        end
        # After replay_decision, credences and options are populated dynamically from records
        replay_decision(c_dict)
        if c_dict["id"] == "challenger_1986"
            @test c_dict["sources"][1]["credence_record_n"] == 24
            @test c_dict["sources"][2]["credence_record_n"] == 24
            @test isapprox(c_dict["sources"][1]["credence_accuracy"], 22/24; atol = 1e-4)
        elseif c_dict["id"] == "thalidomide_fda_1960"
            @test c_dict["sources"][1]["credence_record_n"] == 20
            @test c_dict["sources"][2]["credence_record_n"] == 12
            @test isapprox(c_dict["sources"][1]["credence_accuracy"], 0.90; atol = 1e-4)
        elseif c_dict["id"] == "ragusa_quarantine_1377"
            @test c_dict["sources"][1]["credence_record_n"] == 4
            @test isapprox(c_dict["sources"][1]["credence_accuracy"], 0.75; atol = 1e-4)
        elseif c_dict["id"] == "semmelweis_vienna_1847"
            @test c_dict["sources"][1]["credence_record_n"] == 96
            @test isapprox(c_dict["sources"][1]["credence_accuracy"], 88/96; atol = 1e-4)
        end
    end

    # Two historically good decisions (Thalidomide refusal, Ragusa quarantine): Benefuture agrees -> (good, agrees)
    @test suite.cells[(:good, :agrees)] == 2
    @test suite.cells[(:good, :differs)] == 0
    # Two historically bad decisions (Challenger launch at 31°F, Vienna dismissal of Semmelweis handwashing):
    # Benefuture differs and selects the safe/evidence-backed option -> (bad, differs)
    @test suite.cells[(:bad, :differs)] == 2
    @test suite.cells[(:bad, :agrees)] == 0

    # Low-technology coarse-tier cases (Ragusa 1377, Semmelweis 1849) log coarse-tier degradation loudly
    for r in suite.results
        if r.tier == "coarse"
            @test haskey(r.degraded, "coarse low-technology tier (parent markers & rule fallback, 8.88)")
        end
    end
end

@testset "Historical replay: as-of record store, rolling forecasts, and counterfactual estimators" begin
    # As-of store refuses future resolutions and future data vintages
    d1, d2, d3 = Date(2020, 3, 1), Date(2020, 3, 8), Date(2020, 3, 15)
    recs = [
        AsOfRecord("m_good", "epi", d1, d2, d2, d2, 1.0, 1.0, 0.90),
        AsOfRecord("m_good", "epi", d2, d3, d3, d3, 1.0, 1.0, 0.92),
        # Revised vintage published later on d3
        AsOfRecord("m_good", "epi", d1, d2, d2, d3, 1.0, 1.0, 0.95)
    ]
    store = AsOfStore(recs)
    @test length(records_as_of(store, d2)) == 1
    @test length(records_as_of(store, d3)) == 3

    # Difference-in-differences and Synthetic Control recover a known treatment effect (+5.0)
    t_pre = [10.0, 11.0, 10.5, 11.5, 10.8, 11.2]
    c_pre = [8.0, 9.0, 8.5, 9.5, 8.8, 9.2]
    t_post = [16.0, 17.0, 16.5, 17.5, 16.8, 17.2]
    c_post = [9.0, 10.0, 9.5, 10.5, 9.8, 10.2]
    did = difference_in_differences(t_pre, t_post, c_pre, c_post)
    @test isapprox(did.estimate, 5.0; atol = 1e-6)
    @test did.low <= 5.0 <= did.high

    donors_pre = hcat(t_pre .- 2.0, t_pre .+ 2.0, fill(5.0, 6))
    donors_post = hcat(t_post .- 5.0 .- 2.0, t_post .- 5.0 .+ 2.0, fill(5.0, 6))
    sc = synthetic_control(t_pre, t_post, donors_pre, donors_post)
    @test isapprox(sc.estimate, 5.0; atol = 0.2)
    @test isapprox(sum(sc.weights), 1.0; atol = 1e-6) && all(sc.weights .>= -1e-9)

    comb = combine_counterfactuals([did, sc])
    @test isapprox(comb.estimate, 5.0; atol = 0.2)
    @test comb.spread_low <= comb.estimate <= comb.spread_high

    # Rolling-window quantile forecast replay (DATA §16b)
    # Forecaster A predicts sharp calibrated quantiles for N(10, 2^2)
    # Forecaster B predicts uncalibrated wide quantiles
    q_store = QuantileStore()
    eval_dates = [Date(2020, 1, 1) + Day(7 * i) for i in 1:6]
    for (i, dt) in enumerate(eval_dates)
        # Forecaster B enters first with mediocre forecasts
        append_record!(q_store, "m_mediocre", "macro", dt - Day(7), dt, dt, dt,
                       [0.1, 0.5, 0.9], [4.0, 6.0, 8.0], 10.0)
        # Forecaster A enters later at step 3 with superior calibrated forecasts
        if i >= 3
            append_record!(q_store, "m_superior", "macro", dt - Day(7), dt, dt, dt,
                           [0.1, 0.5, 0.9], [7.44, 10.0, 12.56], 10.0)
        end
    end
    res_q = replay_quantile_forecasts(q_store, "macro", eval_dates; scale = 5.0)
    @test length(res_q.snapshots) == 6
    @test res_q.snapshots[1].active_model == "m_mediocre"
    # Superior forecaster takes over once evaluated
    @test res_q.snapshots[end].active_model == "m_superior"
    @test res_q.takeovers >= 1

    # Diebold-Mariano test between loss series of superior vs mediocre
    losses_sup = fill(0.4, 20)
    losses_med = fill(1.8, 20)
    dm = diebold_mariano(losses_sup, losses_med)
    @test dm.mean < 0.0 && dm.sig && dm.z_stat < -3.0
end

@testset "Historical replay: D1 as-of leakage tests for all 4 cases" begin
    case_paths = [
        joinpath(CASES_DIR, "challenger_1986.toml"),
        joinpath(CASES_DIR, "thalidomide_fda_1960.toml"),
        joinpath(CASES_DIR, "ragusa_quarantine_1377.toml"),
        joinpath(CASES_DIR, "semmelweis_vienna_1847.toml")
    ]
    for p in case_paths
        # Baseline run
        c_base = load_replay_case(p)
        res_base = replay_decision(c_base)
        @test !res_base.void
        creds_base = [src["credence_accuracy"] for src in c_base["sources"]]
        choice_base = res_base.chosen_option

        # (a) Removing every record dated after decision_date leaves choice and credences bit-identical
        c_clean = load_replay_case(p)
        dec_date = Date(c_clean["decision_date"])
        c_clean["_records"] = filter(r -> r.as_of_date <= dec_date && r.resolution_date <= dec_date, c_clean["_records"])
        res_clean = replay_decision(c_clean)
        @test !res_clean.void
        @test res_clean.chosen_option == choice_base
        creds_clean = [src["credence_accuracy"] for src in c_clean["sources"]]
        @test creds_clean == creds_base

        # (b) Adding one synthetic record dated after decision_date makes replay.jl refuse loudly (degraded entry, case unsupported)
        c_leaked = load_replay_case(p)
        first_src_id = first(c_leaked["sources"])["id"]
        post_record = HistoricalCaseRecord(
            first_src_id,
            "synthetic_post_decision_leak",
            dec_date + Dates.Day(1),
            dec_date + Dates.Day(1),
            dec_date + Dates.Day(1),
            1.0, 1.0,
            "Synthetic leak test citation p. 1"
        )
        push!(c_leaked["_records"], post_record)
        res_leaked = replay_decision(c_leaked)
        @test res_leaked.void
        @test res_leaked.chosen_option == ""
        @test occursin("hindsight leak in record synthetic_post_decision_leak", res_leaked.void_reason)
        @test haskey(res_leaked.degraded, "case unsupported: hindsight leak in record synthetic_post_decision_leak")
    end
end


@testset "Forecast archive: D2 rolling-window as-of scoring on COVID-19 Forecast Hub sample" begin
    # Check: unit test on the sample reproduces stored scores
    exp_file = joinpath(CASES_DIR, "archive_sample", "expected_window_scores.csv")
    @test isfile(exp_file)
    expected = Dict{Tuple{Int,String},Float64}()
    for (i, line) in enumerate(readlines(exp_file))
        i == 1 && continue
        isempty(strip(line)) && continue
        parts = split(line, ',')
        expected[(parse(Int, parts[1]), String(parts[4]))] = parse(Float64, parts[5])
    end
    store = load_archive_store()
    rep = rolling_report(store, "covid19_us_inc_death_1wk"; width = 6)
    @test length(rep.scores) == 5
    for (win_idx, sc) in enumerate(rep.scores)
        for (f, score) in sc
            @test isapprox(score, expected[(win_idx, f)]; atol = 1e-6)
        end
    end
    # As-of reconstruction check: records beyond window resolution are refused
    w1_dates = rep.windows[1]
    w1_last_res = maximum(r.resolution_date for r in store.records if r.target_date in w1_dates)
    w1_as_of = records_as_of(store, w1_last_res; domain = "covid19_us_inc_death_1wk")
    @test all(r -> r.resolution_date <= w1_last_res, w1_as_of)
    @test any(r -> r.resolution_date > w1_last_res, store.records)
end

# Scenario pricing (amendment 2026-11-05, 8.87): option effects are expected values over scenarios
# whose probabilities come from as-of event records, never typed with hindsight.
@testset "Replay: scenario pricing from as-of event records (8.87)" begin
    @test event_rate(0, 0) == 0.5 && event_rate(4, 4) ≈ 5 / 6 && event_rate(0, 7) ≈ 1 / 9
    @test pooled_probability([0.2, 0.8], [1.0, 3.0]) ≈ 0.65 && pooled_probability([0.2, 0.8], [0.0, 0.0]) ≈ 0.5
    @test expected_effect([0.25, 0.75], [-4.0, 4.0]) ≈ 2.0
    c = BenefutureSim.load_replay_case(joinpath(@__DIR__, "..", "..", "cases", "challenger_1986.toml"))
    r = BenefutureSim.replay_decision(c)
    launch = only(o for o in c["options"] if o["id"] == "launch_at_31F")
    @test launch["_scenario_p_irr"] ≈ (5 / 6) * (1 / 9)          # priced from the record, not from the outcome
    @test r.chosen_option == "delay_until_53F" && !any(occursin("typed", k) for k in keys(r.degraded))
    t = BenefutureSim.replay_decision(BenefutureSim.load_replay_case(joinpath(@__DIR__, "..", "..", "cases", "thalidomide_fda_1960.toml")))
    @test any(occursin("typed", k) for k in keys(t.degraded))     # typed effects are flagged unsupported, loudly
end
