# Mechanism probes (CLAUDE.md, Verification): each the smallest world that exercises one mechanism
# alone, with its acceptance and counterexample cases, seconds to run. A mechanism enters the full
# worlds and the batteries only once its probe is green.

# Credence from the record (8.66, [P]): one heavy-tailed outcome in a model's record.
@testset "Probe: credence from the record survives one heavy-tailed outcome" begin
    rng = Xoshiro(1)
    errs = 0.3 .* randn(rng, 99)                  # a calibrated model's recent errors
    hit = [errs; 300.0]                           # one side effect three hundred times the spread
    rms(e) = sqrt(mean(abs2, e))
    @test credence(0.5, rms(errs)) > 0.9 && credence(0.5, rms(hit)) < 0.51      # counterexample: a coin toss
    @test record_credence(0.5, hit) > 0.9                                      # acceptance: barely moved
    @test abs(record_credence(0.5, hit) - record_credence(0.5, errs)) <= 1 / 99
end
