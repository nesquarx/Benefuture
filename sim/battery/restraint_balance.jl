# Balance sweep of the restraint-liability weight kappa (author ruling 8.169, L120/L121): audited false
# restraint is liable to the overeager enforcing entity; the balance between deterring false restraint
# and not chilling justified restraint is found here. Prediction (lead, confidence 0.5): false restraints
# near zero at moderate kappa, restraint audits 5-15% of audit spend, U-shaped total harm in kappa.
# Runs in about a minute (0.25 s per seed), so no progress snapshot is needed (CLAUDE.md, 5-minute rule).
# julia --project=sim sim/battery/restraint_balance.jl
using BenefutureSim, Random, Statistics
include(joinpath(@__DIR__, "..", "test", "legacy.jl"))

const AG = vcat([DomainAgent([0.7, 0.6], [0.7, 0.3], 0.0)], [DomainAgent([0.6, 0.6], [0.5, 0.5], 0.0) for _ in 1:3])
const EAGER = [0.0, 0.0, 0.3, 0.3]   # two precise and two overeager enforcing entities (world property)
const SEEDS = 1:24

function arm(audit, kappa, seed; eager = EAGER)
    p = M3cParams(ToyParams(n = 30, steps = 80, plans = 6), AG, [1, 1], trues(2);
                  λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                  guardians = [1, 2], p_informed = 1.0, diligence = [0.0, 1.0, 1.0, 1.0],
                  p_hazard = 0.35, hazard_share = 0.25, hazard_size = 1.0, repair_efficiency = 1.0,
                  endowment = 50.0, sanction_escalate = true, sanction_pattern_min = 3,
                  sanction_restraint_decay = 0.6, sanction_min_share = 0.1, LEGACY...,
                  enforcer_eager = eager, restraint_audit = audit, restraint_kappa = kappa)
    tr = run_m3c(p; seed = seed)
    sp = success_pattern(tr; from = 20)
    missed_harm = tr.restraint_missed * 1.0                 # one hazard unit per dangerous proposer left unrestrained by chill
    (false_eff = tr.false_restraints_effective, just_eff = tr.justified_restraints_effective,
     just_rate = tr.justified_restraints_effective / max(1, tr.justified_restraints + tr.restraint_missed),
     missed = tr.restraint_missed, audits = tr.restraint_audits, audit_cost = tr.restraint_audit_cost,
     liability = tr.restraint_liability, false_harm = tr.false_restraint_harm, missed_harm = missed_harm,
     total_harm = tr.false_restraint_harm + missed_harm + tr.restraint_audit_cost, floor_u = sp.floor_u)
end

function sweep(kappas = [0.0, 0.1, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0])
    rows = NamedTuple[]
    free = [arm(false, 0.0, s) for s in SEEDS]
    push!(rows, (label = "unaudited", kappa = NaN, runs = free))
    for k in kappas
        push!(rows, (label = "audited", kappa = k, runs = [arm(true, k, s) for s in SEEDS]))
    end
    rows
end

function report(rows, io = stdout)
    m(r, f) = mean(getfield.(r.runs, f))
    println(io, "seeds ", first(SEEDS), ":", last(SEEDS), " (", length(SEEDS), ", paired); eager = ", EAGER)
    println(io, "arm        kappa  false_eff just_eff just_rate missed audits audit_cost false_harm total_harm floor_u")
    for r in rows
        println(io, rpad(r.label, 10), " ", rpad(isnan(r.kappa) ? "-" : string(r.kappa), 6),
                join([lpad(string(round(m(r, f), digits = 2)), 10) for f in (:false_eff, :just_eff, :just_rate, :missed, :audits, :audit_cost, :false_harm, :total_harm, :floor_u)]))
    end
    aud = filter(r -> r.label == "audited", rows)
    best = aud[argmin([m(r, :total_harm) for r in aud])]
    println(io, "kappa minimising total harm (false-restraint harm + chilled-restraint harm + audit cost): ", best.kappa)
    free = first(rows)
    d(f) = [getfield(a, f) - getfield(b, f) for (a, b) in zip(best.runs, free.runs)]
    println(io, "best vs unaudited, paired mean (se): ",
            join(["$f " * string(round(mean(d(f)), digits = 2)) * " (" * string(round(std(d(f)) / sqrt(length(SEEDS)), digits = 2)) * ")" for f in (:false_eff, :just_rate, :floor_u)], "; "))
end

if abspath(PROGRAM_FILE) == @__FILE__
    rows = sweep()
    report(rows)
    out = joinpath(@__DIR__, "results", "restraint_balance.txt")
    open(out, "w") do io
        println(io, "commit ", strip(read(`git -C $(@__DIR__) rev-parse --short HEAD`, String)), " (plus uncommitted at run time)")
        report(rows, io)
    end
end
