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
        # replay_decision prices a copy (credences populated from records) and returns it; the input stays as loaded
        c_dict = replay_decision(c_dict).case
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
        creds_base = [src["credence_accuracy"] for src in res_base.case["sources"]]
        choice_base = res_base.chosen_option

        # (a) Removing every record dated after decision_date leaves choice and credences bit-identical
        c_clean = load_replay_case(p)
        dec_date = Date(c_clean["decision_date"])
        c_clean["_records"] = filter(r -> r.as_of_date <= dec_date && r.resolution_date <= dec_date, c_clean["_records"])
        res_clean = replay_decision(c_clean)
        @test !res_clean.void
        @test res_clean.chosen_option == choice_base
        creds_clean = [src["credence_accuracy"] for src in res_clean.case["sources"]]
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
    launch = only(o for o in r.case["options"] if o["id"] == "launch_at_31F")
    @test launch["_scenario_p_irr"] ≈ (5 / 6) * (1 / 9)          # priced from the record, not from the outcome
    @test r.chosen_option == "delay_until_53F" && !any(occursin("typed", k) for k in keys(r.degraded))
    t = BenefutureSim.replay_decision(BenefutureSim.load_replay_case(joinpath(@__DIR__, "..", "..", "cases", "thalidomide_fda_1960.toml")))
    @test any(occursin("typed", k) for k in keys(t.degraded))     # typed effects are flagged unsupported, loudly
end

@testset "Replay: D5 baselines on the same as-of priced options (§5b)" begin
    cases = filter(f -> endswith(f, ".toml") && occursin("primary_or_held_out = \"primary\"", read(f, String)), readdir(CASES_DIR; join = true))
    s = evaluate_replay_suite(cases)
    priced = [(r, b) for (r, b) in zip(s.results, s.baselines) if b !== nothing]
    @test length(priced) == 9
    for (r, b) in priced
        @test b.actual == r.actual_choice
        @test replace(b.equal_weight, r"\+compensated$" => "") in [String(o["id"]) for o in load_replay_case(joinpath(CASES_DIR, r.id * ".toml"))["options"]]
    end
    # Rates matter: weighting the known scenarios alike flips famine codes back to the status quo.
    fc = only(b for (r, b) in priced if r.id == "famine_codes_1880")
    @test fc.equal_weight == fc.status_quo != fc.actual
    # Scored on settled outcomes only; the institutions score their good decisions by construction.
    @test s.scores[:benefuture].n == s.scores[:min_deaths].n == count(((r, b),) -> r.outcome_class in (:good, :bad), priced)
    @test s.scores[:actual].k == count(((r, b),) -> r.outcome_class == :good, priced)
end

@testset "Replay: held-out set, first replay under the frozen code (§4.4)" begin
    ids = ["snow_broad_street_1854", "printing_press_europe_1470", "leaded_petrol_phaseout_1973",
           "bengal_famine_relief_1943", "no_child_left_behind_2002", "volcker_disinflation_1979"]
    s = evaluate_replay_suite([joinpath(CASES_DIR, i * ".toml") for i in ids])
    @test s.n_void == 0
    ch = Dict(r.id => r.chosen_option for r in s.results)
    # First replay (8.99, code a9c71a592e1e592e): 3/5, the strong per-group reading vetoing the printing
    # press and the lead phase-down. Second replay (8.100, compensated reforms priced; not out of sample):
    # the compensated printing privilege passes; the lead phase-down still fails, since its gain is
    # children's understanding, which cannot repay adults' and refiners' happiness losses.
    @test ch["printing_press_europe_1470"] == "grant_privileges_to_master_printers+compensated"
    # Third replay (8.116: understanding gains offset happiness costs over the long-term projection, compensation
    # financed first by value minted on understanding gains, floors judged the same way): the compensated
    # pool-average lead phase-down passes; not out of sample.
    @test ch["leaded_petrol_phaseout_1973"] == "phase_down_total_pool_average_1975_1979+compensated"
    # Sixth replay (8.126: only the generational share of understanding loss, 0.1 by default, is irreparable):
    # Volcker back to reserve targeting, 5 of 5 (at a uniform 0.5, 8.125, it had moved to incomes policy).
    @test ch["volcker_disinflation_1979"] == "reserve_targeting"
    @test (s.scores[:benefuture].k, s.scores[:benefuture].n) == (5, 5)
    @test (s.scores[:mean_welfare].k, s.scores[:min_deaths].k) == (4, 2)
end

@testset "Replay: sensitivity readout, which judged magnitude flips the choice (8.113)" begin
    robust = ["challenger_1986", "famine_codes_1880", "semmelweis_vienna_1847", "bengal_denial_1942"]
    for id in robust
        @test isempty(replay_sensitivity(load_replay_case(joinpath(CASES_DIR, id * ".toml"))))
    end
    # With 8.116 Montreal is robust; Volcker stays contested: it chooses reserve targeting, and doubling the
    # recession costs to cyclical workers flips it to incomes policy (8.126).
    @test isempty(replay_sensitivity(load_replay_case(joinpath(CASES_DIR, "montreal_protocol_1987.toml"))))
    v = replay_sensitivity(load_replay_case(joinpath(CASES_DIR, "volcker_disinflation_1979.toml")))
    @test !isempty(v) && all(x -> x.chosen == "incomes_policy", v)
    @test replay_sensitivity(load_replay_case(joinpath(CASES_DIR, "ragusa_quarantine_1377.toml"))) === nothing
end

@testset "Replay: rule-set battery, coarse to fine (8.119)" begin
    b = replay_rule_battery(load_replay_case(joinpath(CASES_DIR, "montreal_protocol_1987.toml")))
    @test length(b.configs) == 17 && b.shares["adopt_cfc_phase_down"] == 1.0   # robust across every rule set
    l = replay_rule_battery(load_replay_case(joinpath(CASES_DIR, "leaded_petrol_phaseout_1973.toml")))
    @test l.choices[2] == "status_quo_lead_free_availability_only" && l.choices[5] == "phase_down_total_pool_average_1975_1979"   # rule-dependent
    # The default (no overrides) is the full rule set.
    @test l.choices[5] == replace(replay_decision(load_replay_case(joinpath(CASES_DIR, "leaded_petrol_phaseout_1973.toml"))).chosen_option, r"\+compensated$" => "")
end

@testset "Replay: school closures rule either way with duration and remote learning (8.125)" begin
    f = joinpath(CASES_DIR, "school_closures_2020.toml")
    # A close call (8.126): across the rule battery neither option holds 60%.
    b = replay_rule_battery(load_replay_case(f))
    @test maximum(values(b.shares)) < 0.6
    c = load_replay_case(f)
    o = c["options"][findfirst(x -> x["id"] == "close_with_remote_learning", c["options"])]
    for sc in o["scenarios"]; haskey(sc, "du") && (sc["du"] = [-0.3, 0.0]); end       # remote keeping 90% of instruction
    @test replace(replay_decision(c).chosen_option, r"\+compensated$" => "") == "close_with_remote_learning"
end

@testset "Replay: when the blocks exclude every option, the least-excess option is chosen, never inaction by default" begin
    # DDT 1972 with the phase-down's residual harm halved: the environmental block (least: phase-down) excludes
    # cancellation, the irreparable block (least: cancellation) excludes the phase-down, and both exclude keeping
    # DDT. Keeping it, blocked under both, must not win by default (8.47, 8.124).
    c = load_replay_case(joinpath(@__DIR__, "..", "..", "cases", "ddt_ban_1972.toml"))
    c["options"][3]["scenarios"][1]["dh"] = [-0.00175, 0.0]
    r = replay_decision(c)
    @test r.chosen_option != "keep_registration"
    @test any(occursin("every option blocked", k) for k in keys(r.degraded))
end

@testset "Replay: credences are stable to the seed (draws by precision, not habit)" begin
    # FOMC January 2027 is a near tie; with a habitual 40 draws the cut share moved 13 points between seeds 1 and 2.
    c = load_replay_case(joinpath(@__DIR__, "..", "..", "cases", "e5", "fomc_january_2027.toml"))
    a = replay_credence(c; seed = 1); b = replay_credence(c; seed = 2)
    @test all(abs(get(a, k, 0.0) - get(b, k, 0.0)) <= 0.06 for k in union(keys(a), keys(b)))
end

@testset "Replay: environmental health harm counts deaths (a death takes understanding and happiness to zero)" begin
    # German phase-out 2011, irreparable block switched off so the environmental block acts alone: give keeping the
    # fleet an accident that kills 100 thousand with no happiness loss, and give the other options no accident.
    # Counting only u and h losses, keeping the fleet looked harmless and was chosen; with deaths it is the
    # largest environmental harm and is blocked.
    c = load_replay_case(joinpath(@__DIR__, "..", "..", "cases", "german_nuclear_phaseout_2011.toml"))
    c["_rule_overrides"] = Dict{String,Any}("irreparable" => false)
    for o in c["options"], sc in o["scenarios"]
        occursin("accident", sc["name"]) || continue
        sc["dh"] = [0.0]; sc["irreparable"] = [o["id"] == "keep_2010_extension" ? 100.0 : 0.0]
    end
    @test replay_decision(c).chosen_option != "keep_2010_extension"
end

@testset "Replay: when every option is blocked, trolley rules: least net expected harm, all harms counted (8.127)" begin
    # Sri Lanka 2021: every option is blocked, and the overnight ban's expected yield collapse (farm happiness -3
    # at 0.8) is neither environmental nor large in deaths, so weighing only the blocks' excesses chose the ban
    # though its total expected harm is several times the phased transition's.
    c = load_replay_case(joinpath(@__DIR__, "..", "..", "cases", "sri_lanka_fertiliser_ban_2021.toml"))
    r = replay_decision(c)
    @test any(occursin("every option blocked", k) for k in keys(r.degraded))
    @test replace(r.chosen_option, r"\+compensated$" => "") != "ban_imports_now"
end

@testset "Replay: a decision leaves its case unchanged, so later readings are not contaminated" begin
    # Head Start 1965: computing the decision first added compensated variants and overwrote priced fields in
    # the case, and the rule battery read afterwards reported 94% for no programme, against 16 of 17 rule sets
    # choosing Head Start on a fresh copy.
    f = joinpath(@__DIR__, "..", "..", "cases", "head_start_1965.toml")
    fresh = replay_rule_battery(load_replay_case(f)).shares
    c = load_replay_case(f); replay_decision(c)
    @test replay_rule_battery(c).shares == fresh
end

@testset "Replay: contrast cases are checked for equal size before replay (8.129)" begin
    # Tobacco 1964 was built to avert equal expected deaths but, as built, does not (about 56 against 80 thousand
    # among the acting options), so size could decide; the checker must refuse it. NSF 1950 (no deaths at stake) passes.
    d = joinpath(@__DIR__, "..", "..", "cases")
    @test !contrast_check(load_replay_case(joinpath(d, "tobacco_control_1964.toml")); tol = 0.1).ok
    @test contrast_check(load_replay_case(joinpath(d, "nsf_basic_research_1950.toml")); tol = 0.1).ok
end

@testset "Replay: a ban on a chosen risk yields to pricing it (Freedom; ruling 8.46)" begin
    # Prohibition 1919: national prohibition bans a chosen risk while local option with high licence taxes prices
    # it; per the Freedom article (a chosen risk is priced, not prohibited) and 8.46 (laws protect only against
    # outcomes beyond the freedom harm boundary), the ban must not be chosen while the pricing option is unblocked.
    c = load_replay_case(joinpath(@__DIR__, "..", "..", "cases", "prohibition_1919.toml"))
    # Open question for the author (8.130): the pricing option is itself blocked by the policy-level irreparable rule
    # (more expected deaths, mostly heavy drinkers dying of a chosen risk), so the freedom rule does not bite. Whether
    # deaths from a freely chosen risk count in that block is unruled; marked broken until it is.
    @test_broken replace(replay_decision(c).chosen_option, r"\+compensated$" => "") != "national_prohibition"
end

@testset "Replay: base rates count trials that would have been recorded had they gone the other way" begin
    # Swine flu 1976: the pandemic base rate came from recorded strains only (3 pandemics in 4 trials), but as of
    # 1976 sporadic human swine-influenza infections that never spread had also been reported; a case declaring
    # them (`[unrecorded_trials]`, with sources) must have them counted as non-occurrences.
    c = load_replay_case(joinpath(@__DIR__, "..", "..", "cases", "swine_flu_vaccination_1976.toml"))
    c["unrecorded_trials"] = Dict{String,Any}("novel_strain_outbreak_became_pandemic" => 3)
    o = only(x for x in replay_decision(c).case["options"] if x["id"] == "do_nothing")
    @test o["pred_irreparable"][1] ≈ event_rate(3, 7) * 70.0
end

@testset "Replay: an exact tie on value is reported, not broken silently by option order" begin
    # LWCF 1964 under the collapsed scalar reading: parks and the cash rebate tie exactly, and the choice followed
    # option order without a word.
    c = load_replay_case(joinpath(@__DIR__, "..", "..", "cases", "land_water_conservation_fund_1964.toml"))
    c["_rule_overrides"] = Dict{String,Any}("tiers" => false)
    @test any(occursin("tie", k) for k in keys(replay_decision(c).degraded))
end
