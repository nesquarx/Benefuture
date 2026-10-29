# Imperfect agents (author ruling 8.31): each person's choices in a domain carry noise up to a
# ceiling drawn once per person and domain, noisily inverse to their expertise there (a general
# reflection of personal abilities); each choice draws its noise up to that ceiling.

@testset "Choice noise: acceptance" begin
    r = Xoshiro(1)
    expertise = repeat(collect(range(0.0, 1.0; length = 200)), 1, 3)
    caps = ability_caps(r, expertise; base = 1.0, gain = 2.0, spread = 0.5)
    # Inverse to expertise on average, but noisily: persons differ at the same expertise.
    @test mean(caps[151:200, :]) < mean(caps[1:50, :]) / 2
    @test std(caps[1:50, 1] ./ exp.(-2.0 .* expertise[1:50, 1])) > 0.1
    # Each choice's noise is drawn up to the ceiling: never larger in spread than the ceiling.
    draws = [choice_noise(r, 0.8) for _ in 1:20000]
    @test std(draws) < 0.8 && std(draws) > 0.3
end

@testset "Choice noise: adversarial and edge cases" begin
    r = Xoshiro(2)
    @test all(==(0.0), ability_caps(r, zeros(3, 2); base = 0.0, gain = 1.0, spread = 0.5))
    @test ability_caps(r, ones(2, 2); base = 1.0, gain = 0.0, spread = 0.0) == ones(2, 2)
    @test choice_noise(r, 0.0) == 0.0
    @test_throws ArgumentError ability_caps(r, ones(2, 2); base = -1.0, gain = 1.0, spread = 0.5)
    @test_throws ArgumentError choice_noise(r, -0.1)
end
