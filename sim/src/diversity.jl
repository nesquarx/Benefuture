# The split trial (author rulings 8.30, 8.22.3; L158 Di_N_Balance): alternatives tried side by side
# on shares of a scope (locales, domains, populations). Each unit's outcome is the option's value
# plus measurement noise; the options are compared by the Lean significance rule
# (`select_candidate_ref`). The world model is here; the comparison is the rule. Reusable wherever
# alternatives are tried: decisions (M5), debatable thresholds (M4), the pre-N sample.

"""
    split_trial(rng, values, shares; units, σ, z) -> (winner, significant, means, ses)

Option `k` (the incumbent first) is tried on `floor(units × shares[k])` units, each measuring
`values[k]` with noise `σ`. `winner` is the option the significance rule selects at `z`;
`significant` says the trial settled the comparison: an alternative won, or the incumbent beat
every alternative by `z` standard errors. A side with fewer than two units cannot be compared.
"""
function split_trial(rng::AbstractRNG, values, shares; units::Integer, σ::Real, z::Real)
    check(length(values) == length(shares) >= 2 && all(isfinite, values), "one finite value per option, at least two")
    check(all(>=(0), shares) && sum(shares) <= 1 + 1e-9, "shares non-negative, summing to at most 1")
    check(units >= 1 && isfinite(σ) && σ >= 0 && isfinite(z) && z >= 0, "units positive, noise and z non-negative")
    n = [floor(Int, units * sh) for sh in shares]
    outcomes = [values[k] .+ σ .* randn(rng, n[k]) for k in eachindex(values)]
    means = [isempty(o) ? 0.0 : mean(o) for o in outcomes]
    ses = [length(o) < 2 ? 1e12 : max(std(o), 1e-12) / sqrt(length(o)) for o in outcomes]
    winner = select_candidate(means, ses; z)
    held = all(select_candidate([means[k], means[1]], [ses[k], ses[1]]; z) == 2 for k in 2:length(values))
    (winner = winner, significant = winner != 1 || held, means = means, ses = ses)
end
