# Calibrated world defaults (docs/CALIBRATION.md; author note 8.63, ruling 8.33).
#
# Invariant figures (human or physical nature) are defaults at the mildly imperfect end of their
# realistic range; where the table gives a distribution shape it is a world option, on by default,
# with the old shape kept as a limiting case. Institution-dependent figures (vigilance, diligence,
# `p_trace`, delegation, research share, deceit prevalence, ...) are never defaults here: they are
# swept by the batteries. Governed thresholds are not touched. Every figure is listed with its
# source in `sim/README.md` (Noise).

using Random

"""
The calibrated defaults, one place (`docs/CALIBRATION.md` section in the comments). The old values
are the limiting cases that tests pass explicitly: `marker_σ` 0.05, `σ_leaf`/`σ_branch`/`σ_coarse`
0.15/0.3/0.45, `sloppiness` 0, `classify_σ`/`spread` 0.03, `p_side` 0, `hazard_σ` 0.2 (Gaussian
scatter, one size for every event), `signal_σ` 1, `ε` 0.3, `reception_σ` 0.5 (not mean-one), no
teacher spread.
"""
const CALIBRATED = (
    marker_σ = 0.3,        # understanding by tests, reliability about 0.9 (3.1); happiness by single items is 0.6
    σ_leaf = 0.3,          # established model, natural-science predictability (3.3); social science 0.7
    σ_branch = 0.6,        # (3.3)
    σ_coarse = 0.85,       # coarse models carry little beyond the base rate (3.3)
    bias_σ = 0.1,          # overconfidence bias 0.1-0.3, low end (3.3); unchanged
    sloppiness = 0.25,     # intention-behaviour gap of individuals (3.2)
    classify_σ = 0.05,     # coding noise: misclassification 10-25% (3.1), low end
    spread = 0.05,         # the same, as scatter of causal signatures
    p_side = 0.01,         # side effects, simple domain; complex domains 0.05-0.1 (3.9)
    hazard_σ = 1.0,        # scatter of one event's harm across beings, as a CV (3.9)
    hazard_α = 2.0,        # Pareto exponent of event size, thin end of 1.5-2 (3.9)
    hazard_cap = 20.0,     # largest event, in medians (the toy's catastrophes are of this order)
    skill_log_sd = 0.3,    # log-normal skill, low end of 0.3-0.5 (3.2)
    signal_σ = 2.0,        # non-experts: p = 0.69, low end of σ 2-4 (3.2)
    ε = 0.2,               # a course closes 0.1-0.2 of the lead, per year (3.7)
    reception_σ = 0.8,     # learners' gains, log-SD (3.7)
    teacher_cv = 0.5,      # teachers' effect multiplier, CV 0.4-0.6 (3.7)
)

const SLOPPINESS = CALIBRATED.sloppiness

"Log-normal draws of mean 1 and coefficient of variation `cv` (0: exactly 1)."
function lognormal_mean1(rng::AbstractRNG, cv::Real, n::Integer)
    check(isfinite(cv) && cv >= 0 && n >= 0, "cv and count non-negative")
    cv == 0 && return ones(n)
    s2 = log1p(cv^2)
    exp.(sqrt(s2) .* randn(rng, n) .- s2 / 2)
end

"One Pareto draw of tail exponent `α` and median 1, capped at `cap` (event sizes; 3.9)."
function pareto_median1(rng::AbstractRNG, α::Real, cap::Real)
    check(isfinite(α) && α > 0 && cap >= 1, "exponent positive, cap at least the median")
    min(cap, 2.0^(-1 / α) * (1 - rand(rng))^(-1 / α))
end

"""
    draw_skills(rng, n, nd, skilled; median = 0.6, log_sd = CALIBRATED.skill_log_sd, tail = nothing)

Skills of `n` agents over `nd` domains, as an `n × nd` matrix: the domains in `skilled` (booleans or
indices) get a log-normal skill around `median` (output per person is not bell-shaped; 3.2), the
others 0. With `tail = α` a Pareto tail of exponent α (research and creative output) replaces the
log-normal. `log_sd = 0` is the limiting case of identical agents.
"""
function draw_skills(rng::AbstractRNG, n::Integer, nd::Integer, skilled; median::Real = 0.6,
                     log_sd::Real = CALIBRATED.skill_log_sd, tail = nothing)
    check(n >= 1 && nd >= 1 && isfinite(median) && isfinite(log_sd) && log_sd >= 0, "agents and domains positive, median finite, log-SD non-negative")
    on = skilled isa AbstractVector{Bool} ? skilled : [d in skilled for d in 1:nd]
    check(length(on) == nd, "one flag per domain")
    [on[d] ? (tail === nothing ? median * exp(log_sd * randn(rng)) : median * pareto_median1(rng, tail, Inf)) : 0.0 for _ in 1:n, d in 1:nd]
end
