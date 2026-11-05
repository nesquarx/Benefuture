# Generates docs/REPLAY_PREREG.md §2 (frozen governed thresholds) from the code, so the pre-registered
# table can never diverge from the rules the replay runs. Usage:
#   julia --project=sim tools/data/prereg_thresholds.jl > /tmp/table.md
# Rows whose value has no source in the code are printed as UNSOURCED and must be resolved before replay.
using BenefutureSim
bp = NamedTuple{PARAM_FIELDS}(Tuple(bootstrap_params()))
m3c = M3cParams(ToyParams(n = 20, steps = 10, plans = 2), [DomainAgent([0.5, 0, 0, 0], [1.0, 0, 0, 0], 0.2)], [1, 1, 2, 2], trues(4); λpos = 0.05, λneg = 0.02)
m5 = M5Params((relevance_leaf = zeros(4, 4), agents = [DomainAgent([0.5, 0, 0, 0], [1.0, 0, 0, 0], 0.2)]), 1:4)
tp = ToyParams()
rows = [
    ("Floor quantile", "q", tp.q, "ToyParams default (sim/src/m0.jl)"),
    ("Ha_wt synergy κ", "kappa_harm", bp.kappa_harm, "bootstrap_params_ref (ParamSpace.lean)"),
    ("Ha_wt exponent q", "q_harm", bp.q_harm, "bootstrap_params_ref"),
    ("Harm schedule (L61)", "HARM_SCHEDULE", Tuple(HARM_SCHEDULE), "value.jl / harmSchedule_ref"),
    ("Fr confidence bar", "fr_thConf", bp.fr_thConf, "bootstrap_params_ref"),
    ("Fr high-harm bar", "fr_thHigh", bp.fr_thHigh, "bootstrap_params_ref"),
    ("Fr severity multipliers", "sev_*", (bp.sev_irreparable, bp.sev_irreversible, bp.sev_longterm, bp.sev_passing, bp.sev_timeLoss), "bootstrap_params_ref"),
    ("Leaf status bar", "threshold", m3c.threshold, "M3cParams default"),
    ("Coarse / parent bar", "coarse_threshold", m3c.coarse_threshold, "M3cParams default"),
    ("Novel-domain floor", "novel_floor", m3c.novel_floor, "M3cParams default (8.35)"),
    ("Credence cap", "max_credence", m3c.max_credence, "M3cParams default"),
    ("Model significance z", "model_z", m3c.model_z, "M3cParams default"),
    ("Ratchet horizon multiple", "ratchet_horizon", m3c.ratchet_horizon, "M3cParams default (8.84, 8.85)"),
    ("Accuracy half-life at reference rate", "acc_halflife", m3c.acc_halflife, "M3cParams default (8.85)"),
    ("Reference transaction rate", "acc_rate_ref", m3c.acc_rate_ref, "M3cParams default (8.85)"),
    ("Half-life rate mute", "acc_mute", m3c.acc_mute, "M3cParams default (8.85)"),
    ("Delegation cap", "cap", m5.cap, "M5Params default (L114)"),
    ("Participation impact bar", "impact_threshold", m5.impact_threshold, "M5Params default (8.46)"),
    ("Long-term window (accession, 8.86)", "lt_window", 100, "pop_value / pop_choose signature default (sim/src/m7.jl)"),
]
println("| Parameter | Field | Value | Source |")
println("|---|---|---|---|")
for (name, field, v, src) in rows
    println("| ", name, " | `", field, "` | ", v, " | ", src, " |")
end
