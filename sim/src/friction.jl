# Imperfect agents (author ruling 8.31). A person's choices in a domain carry noise up to a ceiling
# drawn once per person and domain: `base` × exp(−`gain` × expertise), scattered log-normally by
# `spread` (a general reflection of personal abilities, inverse to expertise only on average). Each
# choice draws its noise up to that ceiling. World model, not a rule; reusable wherever agents
# choose (votes, locales, co-funding, guardians).

"Per person and domain ceilings on choice noise, noisily inverse to `expertise` (persons × domains)."
function ability_caps(rng::AbstractRNG, expertise::AbstractMatrix; base::Real, gain::Real, spread::Real)
    check(all(x -> isfinite(x) && x >= 0, (base, gain, spread)) && all(isfinite, expertise), "base, gain and spread non-negative")
    base .* exp.(-gain .* expertise) .* exp.(spread .* randn(rng, size(expertise)))
end

"One choice's noise: a normal draw scaled by a uniform fraction of the person's ceiling `cap`."
function choice_noise(rng::AbstractRNG, cap::Real)
    check(isfinite(cap) && cap >= 0, "ceiling non-negative")
    cap * rand(rng) * randn(rng)
end
