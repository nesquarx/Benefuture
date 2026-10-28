# Metric model scoring and adoption (L49, accuracy only), and toy model M1: measurement through
# competing metric models with bias and noise, scored against established markers.

@testset "Metric models: scoring and adoption" begin
    @test mm_score([1.0, 2.0], [1.0, 2.0]) == 0.0              # perfect prediction scores best
    @test mm_score([1.0, 2.0], [2.0, 4.0]) == -2.5             # minus the mean squared error
    @test mm_score(Float64[], Float64[]) == 0.0
    @test mm_score([0.0], [1.0]) > mm_score([0.0], [2.0])
    @test mm_adopt([-3.0, -0.5, -1.0]) == 2
    @test mm_adopt([-1.0, -1.0]) == 1                          # ties go to the first
    @test_throws ArgumentError mm_score([1.0], [1.0, 2.0])
    @test_throws ArgumentError mm_score([NaN], [1.0])
    @test_throws ArgumentError mm_adopt(Float64[])
end

const T0 = ToyParams(n = 60, steps = 40, plans = 12)
perfect(k = 1) = [MetricModel(0.0, 0.0) for _ in 1:k]

@testset "M1: acceptance" begin
    # Perfect models and exact markers reproduce M0 exactly.
    m0 = run_m0(T0; seed = 7)
    m1 = run_m1(M1Params(T0, perfect(2), 0.0, 5); seed = 7)
    @test m1.chosen == m0.chosen
    @test m1.floor_u == m0.floor_u && m1.floor_h == m0.floor_h
    @test m1 == run_m1(M1Params(T0, perfect(2), 0.0, 5); seed = 7)
    # Competition settles on the most accurate model (Conj_MMCompetitionConverges).
    models = [MetricModel(0.0, 2.0), MetricModel(0.0, 1.0), MetricModel(0.0, 0.1)]
    tr = run_m1(M1Params(ToyParams(n = 60, steps = 60, plans = 12), models, 0.05, 10); seed = 3)
    @test tr.adopted[end] == 3
    @test tr.best_score[end] - tr.adopted_score[end] < 1e-12
    @test length(tr.floor_u) == length(tr.obs_floor_u) == 61 && length(tr.adopted) == 60
end

@testset "M1: adversarial and edge cases" begin
    # A precise but biased model loses to an unbiased one of equal noise.
    models = [MetricModel(1.5, 0.3), MetricModel(0.0, 0.3)]
    tr = run_m1(M1Params(ToyParams(n = 60, steps = 40, plans = 12), models, 0.05, 10); seed = 5)
    @test tr.adopted[end] == 2
    # The floor guarantee rests on measurement: with noisy models the latent floor can fall.
    noisy = M1Params(ToyParams(n = 60, steps = 40, plans = 12), [MetricModel(0.0, 3.0)], 0.5, 5)
    @test any(!floors_rise(run_m1(noisy; seed = s)) for s in 1:5)
    @test_throws ArgumentError MetricModel(0.0, -1.0)
    @test_throws ArgumentError M1Params(T0, MetricModel[], 0.0, 5)
    @test_throws ArgumentError M1Params(T0, perfect(1), -0.1, 5)
    @test_throws ArgumentError M1Params(T0, perfect(1), 0.0, 0)
end

@testset "M1: runs fast enough to iterate" begin
    p = M1Params(ToyParams(n = 1000, steps = 100, plans = 20), [MetricModel(0.2, 1.0), MetricModel(0.0, 0.5), MetricModel(0.0, 0.2)], 0.1, 10)
    run_m1(M1Params(ToyParams(n = 20, steps = 2, plans = 2), perfect(1), 0.0, 2); seed = 1)
    @test (@elapsed run_m1(p; seed = 1)) < 90
end
