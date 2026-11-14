# Anti-Corruption (L160) measured claim (BACKPROPAGATION 8.142): every known attack pays less than
# honesty. Runs paired seeds across the M6 attack suite (economy + M5 collusion + Shapley sybil),
# recording (attacker's payoff less honest payoff on the same seeds, t-inflated interval, seeds)
# judged by `paired_effect`. Any attack whose paired payoff significantly exceeds honesty (:up) is
# flagged [OPEN]; no new mechanism is added here.
#
# Run: arch -arm64 julia --project=sim sim/battery/attack_payoffs.jl --workers 7
using BenefutureSim, Statistics, Printf

include(joinpath(@__DIR__, "..", "test", "legacy.jl"))

function parse_cli_args(args = ARGS)
    parsed = Dict{String, Any}()
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--seeds" && i < length(args)
            val = args[i + 1]
            parsed["seeds"] = contains(val, ":") ? let p = split(val, ":"); parse(Int, p[1]):parse(Int, p[2]) end : 1:parse(Int, val)
            i += 2
        elseif startswith(arg, "--seeds=")
            val = split(arg, "=", limit = 2)[2]
            parsed["seeds"] = contains(val, ":") ? let p = split(val, ":"); parse(Int, p[1]):parse(Int, p[2]) end : 1:parse(Int, val)
            i += 1
        elseif arg == "--out" && i < length(args)
            parsed["out"] = args[i + 1]
            i += 2
        elseif startswith(arg, "--out=")
            parsed["out"] = split(arg, "=", limit = 2)[2]
            i += 1
        elseif arg == "--case" && i < length(args)
            parsed["case"] = parse(Int, args[i + 1])
            i += 2
        elseif startswith(arg, "--case=")
            parsed["case"] = parse(Int, split(arg, "=", limit = 2)[2])
            i += 1
        elseif arg == "--workers" && i < length(args)
            parsed["workers"] = parse(Int, args[i + 1])
            i += 2
        elseif startswith(arg, "--workers=")
            parsed["workers"] = parse(Int, split(arg, "=", limit = 2)[2])
            i += 1
        else
            i += 1
        end
    end
    return parsed
end

const CLI_ARGS = parse_cli_args()
const SEEDS = collect(get(CLI_ARGS, "seeds", 1:16))
const OUT = get(CLI_ARGS, "out", get(ENV, "BF_OUT", joinpath(@__DIR__, "results")))
const SINGLE_CASE = get(CLI_ARGS, "case", 0)
const WORKERS = get(CLI_ARGS, "workers", 1)

standing(tr, a) = sum(tr.balance[a, :]) + tr.overflow_agent[a]
mean_standing(tr, ks) = mean(standing(tr, a) for a in ks)

# --- Scenario builders (matching sim/test/m6_tests.jl, m6_attacks_tests.jl, attack_tests.jl) ----
fooled_agent6 = [0.0, 0.0, 0.0, 0.0, 0.0, 1.0]
sixty(; kw...) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10),
                           [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6],
                           [1, 1, 2, 2], trues(4);
                           λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                           advap = true, LEGACY..., kw...)

eight_launder(; launder = Float64[], kw...) =
    M3cParams(ToyParams(n = 80, steps = 300, plans = 10),
              [DomainAgent([0.3, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:8],
              [1, 1, 2, 2], trues(4);
              λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
              repair_efficiency = 0.5, launder, kw...)

frozen_world(attack; p_trace = 0.5) = let bloc = [6, 7, 8], per(x) = [i in bloc ? x : 0.0 for i in 1:8]
    M3cParams(ToyParams(n = 80, steps = 300, plans = 10),
              [DomainAgent([l in (1, 3) ? 0.6 : 0.0 for l in 1:4], [0.5, 0, 0.5, 0], 0.0) for _ in 1:8],
              [1, 1, 2, 2], trues(4);
              λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
              p_upstream = 0.5, guardians = [1, 2, 3, 4], p_foresee = 1.0, repair_efficiency = 0.5,
              advap = true, p_trace,
              deceit = per(attack ? 0.924 : 0.0), launder = per(attack ? 0.828 : 0.0), frivolous = per(attack ? 0.044 : 0.0))
end

ww_world(; kw...) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10),
                              [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6],
                              [1, 1, 2, 2], trues(4);
                              λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                              LEGACY..., kw...)

const ONOFF_EVENTS = [shock(:breakthrough; step = s, duration = 25, size = -1.0, target = 6) for s in 26:50:300]

slander_world(; kw...) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10),
                                   [DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:6],
                                   [1, 1, 2, 2], trues(4);
                                   λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                                   advap = true, kw...)

harmful_dm(skill6) = M3cParams(ToyParams(n = 80, steps = 300, plans = 10),
                               [[DomainAgent([0.6, 0, 0, 0], [1.0, 0, 0, 0], 0.0) for _ in 1:5];
                                DomainAgent([skill6, 0, 0, 0], [1.0, 0, 0, 0], 0.0)],
                               [1, 1, 2, 2], trues(4);
                               λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                               explore_share = 0.2, LEGACY...)

collude_world(; model_collude) = M3cParams(ToyParams(; n = 50, steps = 260, plans = 8),
                                           [DomainAgent([0.5, 0.5], [0.5, 0.5], 0.1) for _ in 1:6],
                                           [1, 1], [true, true];
                                           λpos = 0.05, λneg = 0.02, transactions = true, accuracy_rule = :window,
                                           p_new_model = 0.2, improve_drift = -0.4, improve_σ = 0.1,
                                           takeover_records = 5, min_records = 5, pool_max = 8,
                                           events = [shock(:capture; step = 10, duration = 20, size = 5.0, target = 1)],
                                           model_collude, model_collude_bias = 5.0, collude_actors = [1],
                                           track_window = 20, credence_rule = :record, advap = true)

profile_world(; profile_gamers) = M3cParams(ToyParams(; n = 60, steps = 200, plans = 8),
                                            [DomainAgent([0.25, 0.8], [1.0, 0.0], 3.0),
                                             DomainAgent([0.8, 0.8], [0.0, 1.0], 0.05),
                                             DomainAgent([0.8, 0.8], [0.0, 1.0], 0.05),
                                             DomainAgent([0.8, 0.8], [0.0, 1.0], 0.05)],
                                            [1, 1], [true, true];
                                            λpos = 0.05, λneg = 0.02, transactions = true,
                                            profile_mode = :measured, profile_gamers)

const M5_BASE = run_m3c(M3cParams(ToyParams(n = 80, steps = 200, plans = 10),
                                  [DomainAgent([k == l ? 0.1 + 0.4 * (r - 1) / 24 : 0.0 for l in 1:4],
                                               [k == l ? 1.0 : 0.0 for l in 1:4], 0.0) for k in 1:4 for r in 1:25],
                                  [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02, transactions = true); seed = 1)
const M5_BLOC30 = unique(vcat([sortperm(M5_BASE.relevance_leaf[:, d]; rev = true)[1:round(Int, 0.3 * 25)] for d in 1:4]...))

function m5_reputation_delta(; seed, advap)
    r = run_m5(M5Params(M5_BASE, 1:4; decisions = 800, colluders = M5_BLOC30, p_delegate = 0.8,
                        stealth = true, diversity = true, advap); seed)
    r.bloc_expertise[end] - r.bloc_expertise[1]
end

function sybil_harm_split_delta()
    V(x) = sign(x) * abs(x)^1.5
    game(effs) = [V(sum((effs[k] for k in eachindex(effs) if mask & (1 << (k - 1)) != 0); init = 0.0))
                  for mask in 0:(2^length(effs) - 1)]
    φ_split = shapley(game([-1.0, -1.0, 1.5]))
    φ_honest = shapley(game([-2.0, 1.5]))
    (φ_split[1] + φ_split[2]) - φ_honest[1]
end

# --- Evaluation -----------------------------------------------------------------------------
function paired_row(name, unit, fn, seeds)
    # Run serially inside each process: `run_m3c` takes a global lock around Lean `ccall`,
    # so OS processes (`--workers N`) scale linearly without lock contention.
    ds = Float64[fn(s) for s in seeds]
    pe_up = paired_effect(ds; z = 2.0, direction = :up)
    pe_dn = paired_effect(ds; z = 2.0, direction = :down)
    lo = pe_up.mean - pe_up.z * pe_up.se
    hi = pe_up.mean + pe_up.z * pe_up.se
    verdict = pe_up.significant ? "[OPEN] attack pays" :
              pe_dn.significant ? "attack costs" :
              "no significant gain"
    (name = name, unit = unit, mean = pe_up.mean, se = pe_up.se, lo = lo, hi = hi, n = pe_up.n, verdict = verdict)
end

const CASES = [
    ("Overpromising (AdvAp + clawback)", "standing", s -> standing(run_m3c(sixty(deceit = fooled_agent6); seed = s), 6) - standing(run_m3c(sixty(); seed = s), 6)),
    ("Overpromising (track record, no AdvAp)", "standing", s -> standing(run_m3c(sixty(advap = false, deceit = fooled_agent6); seed = s), 6) - standing(run_m3c(sixty(advap = false); seed = s), 6)),
    ("Decision market (harmful proposals, explore=0.2)", "standing", s -> standing(run_m3c(harmful_dm(-0.5); seed = s), 6) - standing(run_m3c(harmful_dm(0.6); seed = s), 6)),
    ("Frozen worst economy attack (bloc, default p_trace=0.5)", "bloc mean standing", s -> mean_standing(run_m3c(frozen_world(true; p_trace = 0.5); seed = s), 6:8) - mean_standing(run_m3c(frozen_world(false; p_trace = 0.5); seed = s), 6:8)),
    ("Frozen worst economy attack (untraced, p_trace=0.0)", "bloc mean standing", s -> mean_standing(run_m3c(frozen_world(true; p_trace = 0.0); seed = s), 6:8) - mean_standing(run_m3c(frozen_world(false; p_trace = 0.0); seed = s), 6:8)),
    ("Laundering (traced, p_trace=1.0)", "standing", s -> standing(run_m3c(eight_launder(launder = [zeros(7); 0.5], p_trace = 1.0); seed = s), 8) - standing(run_m3c(eight_launder(p_trace = 1.0); seed = s), 8)),
    ("Laundering (untraced, p_trace=0.0)", "standing", s -> standing(run_m3c(eight_launder(launder = [zeros(7); 0.5], p_trace = 0.0); seed = s), 8) - standing(run_m3c(eight_launder(p_trace = 0.0); seed = s), 8)),
    ("On-off oscillation (AdvAp + 8.91 clawback)", "standing", s -> standing(run_m3c(ww_world(deceit = fooled_agent6, events = ONOFF_EVENTS, on_off = 25, advap = true); seed = s), 6) - standing(run_m3c(ww_world(advap = true); seed = s), 6)),
    ("Slandering (frivolous=1.0 on peer, AdvAp)", "standing", s -> standing(run_m3c(slander_world(frivolous = [1.0, 0, 0, 0, 0, 0], slander = [2, 0, 0, 0, 0, 0]); seed = s), 1) - standing(run_m3c(slander_world(); seed = s), 1)),
    ("Whitewashing (3 clusters, weighted binding)", "standing", s -> standing(run_m3c(ww_world(deceit = fooled_agent6, whitewash = [0, 0, 0, 0, 0, 0.05], bind_weighted = true); seed = s), 6) - standing(run_m3c(ww_world(bind_weighted = true); seed = s), 6)),
    ("Whitewashing + compromised clusters (2/3, weighted)", "standing", s -> standing(run_m3c(ww_world(deceit = fooled_agent6, whitewash = [0, 0, 0, 0, 0, 0.05], bind_compromised = [1, 2], p_reveal = 0.05, bind_weighted = true); seed = s), 6) - standing(run_m3c(ww_world(bind_compromised = [1, 2], p_reveal = 0.05, bind_weighted = true); seed = s), 6)),
    ("Model collusion (track_window=20, AdvAp)", "standing", s -> standing(run_m3c(collude_world(model_collude = 1.0); seed = s), 1) - standing(run_m3c(collude_world(model_collude = 0.0); seed = s), 1)),
    ("Profile gaming (:measured routing)", "standing", s -> standing(run_m3c(profile_world(profile_gamers = [2, 0, 0, 0]); seed = s), 1) - standing(run_m3c(profile_world(profile_gamers = zeros(Int, 4)); seed = s), 1)),
    ("M5 stealthy voter collusion (AdvAp + diversity)", "bloc rep share delta", s -> m5_reputation_delta(; seed = s, advap = true)),
]

function row_tsv_path(k)
    joinpath(OUT, ".attack_case_$(k).tsv")
end

function run_worker_case(k)
    mkpath(OUT)
    name, unit, fn = CASES[k]
    t_case = time()
    r = paired_row(name, unit, fn, SEEDS)
    open(row_tsv_path(k), "w") do io
        println(io, join([r.name, r.unit, string(r.mean), string(r.se), string(r.lo), string(r.hi), string(r.n), r.verdict], '\t'))
    end
    @printf("  [%2d/%2d] %s -> %+.2f ± %.2f [%+.2f, %+.2f] (%s, %.1fs)\n",
            k, length(CASES), r.name, r.mean, r.se, r.lo, r.hi, r.verdict, time() - t_case)
    flush(stdout)
    r
end

function parse_row_tsv(path)
    fields = split(chomp(read(path, String)), '\t')
    (name = String(fields[1]), unit = String(fields[2]),
     mean = parse(Float64, fields[3]), se = parse(Float64, fields[4]),
     lo = parse(Float64, fields[5]), hi = parse(Float64, fields[6]),
     n = parse(Int, fields[7]), verdict = String(fields[8]))
end

t0 = time()
if 1 <= SINGLE_CASE <= length(CASES)
    run_worker_case(SINGLE_CASE)
else
    mkpath(OUT)
    rows = if WORKERS > 1
        seeds_arg = "$(first(SEEDS)):$(last(SEEDS))"
        proj = dirname(@__DIR__)
        asyncmap(eachindex(CASES); ntasks = WORKERS) do k
            cmd = `$(Base.julia_cmd()) --project=$(proj) $(@__FILE__) --case=$(k) --seeds=$(seeds_arg) --out=$(OUT)`
            run(cmd)
            r = parse_row_tsv(row_tsv_path(k))
            rm(row_tsv_path(k); force = true)
            r
        end
    else
        [run_worker_case(k) for k in eachindex(CASES)]
    end
    sybil_d = sybil_harm_split_delta()
    elapsed = time() - t0

    outpath = joinpath(OUT, "attack_payoffs.md")
    open(outpath, "w") do io
        println(io, "# Anti-Corruption (L160) attack-payoff table (8.142)\n")
        println(io, "Build: commit `", current_commit(), "` (working tree may carry uncommitted edits). Runtime: ", @sprintf("%.1f s", elapsed), ", seeds: `", first(SEEDS), ":", last(SEEDS), "` (", length(SEEDS), " paired seeds).\n")
        println(io, "Measured claim: every known attack pays less than honesty on the same seeds, judged by `paired_effect` (`z = 2` with Student-t inflation). An attack whose paired difference (`attacker payoff − honest baseline`) is significantly positive (`direction = :up`) is flagged **[OPEN]**.\n")
        println(io, "| Attack | Unit | Mean Δ (attack − honest) | t-inflated interval (z = 2) | Seeds | Verdict |")
        println(io, "|---|---|---|---|---|---|")
        for r in rows
            println(io, @sprintf("| %s | %s | %+.2f ± %.2f | [%+.2f, %+.2f] | %d | %s |",
                                 r.name, r.unit, r.mean, r.se, r.lo, r.hi, r.n, r.verdict))
        end
        println(io, @sprintf("| Sybil harm split (-2 split beside +1.5 co-contributor, rule level, 8.58-e) | Shapley credit Δ | %+.3f | deterministic (no noise) | rule | [OPEN] attack pays unless identity-bound |", sybil_d))
    end
    println("Wrote ", outpath, " in ", round(elapsed; digits = 1), "s")
end

