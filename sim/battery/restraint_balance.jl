# Balance sweep of restraint by a judicial panel (author ruling 8.170, L115/L117/L120/L121): restraint is the last-resort
# verdict of Justice; the liability of a false restraint falls on the experts who voted for it, by their stated confidence;
# enforcement executes and is liable only for excess; audits read verdict quality and execution fidelity. Reports, per arm,
# the false/true ratio of effective restraints, the justified share standing, audit spend, harms and the alarm.
# Prediction (lead, confidence 0.65): chilling largely disappears (justified share >= 0.9 of no liability), false/true << 1
# nominally, the alarm fires under capture. Runs in about a minute (0.25 s per run), so no progress snapshot is needed.
# julia --project=sim sim/battery/restraint_balance.jl
using BenefutureSim, Random, Statistics
include(joinpath(@__DIR__, "..", "test", "legacy.jl"))
include(joinpath(@__DIR__, "..", "test", "test_helpers.jl"))

const SEEDS = 1:24
const BIAS, CLUSTER = [6.0, 6.0, 6.0, 6.0, 6.0, 6.0, 6.0, 0.0], [1, 1, 1, 1, 1, 1, 1, 2]
const EXCESS = [0.0, 0.0, 1.0, 1.0]

# Each arm is (label, keyword arguments of `restraint_world`); kappa sweeps the liability weight on the experts.
function arms(kappas = [0.0, 0.5, 1.0, 2.0, 4.0])
    out = Tuple{String,Any}[("no audit", (audit = false,))]
    for k in kappas
        push!(out, ("nominal kappa $k", (kappa = k,)))
    end
    push!(out, ("audit at chance", (acc = 0.5,)), ("nominal + excess", (excess = EXCESS,)), ("excess, no audit", (excess = EXCESS, audit = false)),
          ("captured panel", (bias = BIAS, cluster = CLUSTER, accuse = 1.0)), ("captured, no audit", (bias = BIAS, cluster = CLUSTER, accuse = 1.0, audit = false)))
    out
end

function sweep(; arms = arms())
    [(label = l, kw = kw, runs = [restraint_world(s; kw...) for s in SEEDS]) for (l, kw) in arms]
end

function report(rows, io = stdout)
    m(r, f) = mean(f.(r.runs))
    println(io, "seeds ", first(SEEDS), ":", last(SEEDS), " (", length(SEEDS), ", paired); panel of 5 from 8 experts; false accusation 0.03 (nominal), 1.0 (captured)")
    println(io, rpad("arm", 22), "false_eff true_eff f/t    standing audit_spend expert_liab enf_liab excess_harm false_harm alarm_seeds floor_u")
    for r in rows
        fh(x) = x.tr.false_restraint_harm
        println(io, rpad(r.label, 22),
                join([lpad(string(round(m(r, f), digits = 2)), 9) for f in (x -> x.false_eff, x -> x.true_eff, x -> x.ratio, x -> x.just_rate,
                                                                               x -> x.tr.restraint_audit_cost, x -> x.tr.judge_liability,
                                                                               x -> sum(x.tr.enforcer_liability), x -> x.tr.excess_harm, fh)]),
                lpad(string(count(x -> x.tr.restraint_alarm_step > 0, r.runs), "/", length(r.runs)), 12),
                lpad(string(round(m(r, x -> success_pattern(x.tr; from = 20).floor_u), digits = 2)), 8))
    end
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
