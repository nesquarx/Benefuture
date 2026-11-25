# Helpers shared by test files, so each file runs alone as well as in the suite.

# Every ordering of 1:n (n >= 1), each as a vector.
function all_perms(n)
    n == 1 && return [[1]]
    [insert!(copy(q), j, n) for q in all_perms(n - 1) for j in 1:n]
end

# The restraint-by-panel world (ruling 8.170; probes and the heavy check share it): a small M3c world in which
# dangerous proposers (qualifying crime pattern) are referred, innocents are falsely accused at a world rate, a
# panel of judicial experts of varying skill votes on guilt with confidence, and enforcing entities execute.
# Needs BenefutureSim, `legacy.jl` (LEGACY) loaded. Returns the trace and the outcome measures.
const RESTRAINT_JUDGES = [0.3, 0.5, 0.8, 0.5, 0.4, 0.6, 0.7, 0.5]   # evidence-reading noise per expert (skills vary)
function restraint_world(seed::Int; audit = true, kappa = 1.0, acc = 0.9, bias = Float64[], cluster = Int[], accuse = 0.03,
                         excess = Float64[], challenge = 0.0, budget = 1, cap = 2, panel = 5, judges = RESTRAINT_JUDGES, acq = false, acq_rate = 0.25)
    agr = vcat([DomainAgent([0.7, 0.6], [0.7, 0.3], 0.0)], [DomainAgent([0.6, 0.6], [0.5, 0.5], 0.0) for _ in 1:3])
    p = M3cParams(ToyParams(n = 30, steps = 80, plans = 6), agr, [1, 1], trues(2);
                  λpos = 0.05, λneg = 0.02, transactions = true, causal_distribution = true,
                  guardians = [1, 2], p_informed = 1.0, diligence = [0.0, 1.0, 1.0, 1.0],
                  p_hazard = 0.35, hazard_share = 0.25, hazard_size = 1.0, repair_efficiency = 1.0,
                  endowment = 50.0, sanction_escalate = true, sanction_pattern_min = 3,
                  sanction_restraint_decay = 0.6, sanction_min_share = 0.1, LEGACY...,
                  judges = judges, judge_bias = bias, judge_cluster = cluster, panel_size = panel, false_accusation_rate = accuse,
                  enforcer_excess = excess, restraint_challenge = challenge, restraint_recursion_budget = budget,
                  restraint_audit = audit, restraint_kappa = kappa, restraint_audit_acc = acc, restraint_audit_cap = cap,
                  acquittal_audit = acq, acquittal_audit_rate = acq_rate)
    tr = run_m3c(p; seed = seed)
    (tr = tr, false_eff = Float64(tr.false_restraints_effective), true_eff = Float64(tr.justified_restraints_effective),
     just_rate = tr.justified_restraints_effective / max(1, tr.justified_restraints + tr.restraint_missed),
     ratio = tr.false_restraints_effective / max(1, tr.justified_restraints_effective))
end
