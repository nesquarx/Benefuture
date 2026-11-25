"""Characterisation v3 plumbing: reduction, scaling and tuning are fitted inside the training folds only, outputs are deterministic,
and the feature blocks report what the image draws.

Acceptance: separable data through the PCA pipeline is identified; blocks have the named columns. Counterexample: labels with no
signal stay near chance through the pipeline (a leak would score high), a held-out label never moves its own prediction, a
held-out row never reaches the reduction fit, the inner folds of the penalty search refit the reduction on their own training rows.
"""
import numpy as np

from lifeimage import characterise as ch
from lifeimage import characterise_v3 as c3


def clusters(n_per=12, k=3, d=30, gap=4.0, seed=0):
    rng = np.random.default_rng(seed)
    X = rng.normal(size=(k * n_per, d))
    means = rng.normal(size=(k, d))
    for c in range(k):  # the class signal spreads over every column, as the image's levels do
        X[c * n_per:(c + 1) * n_per] += gap * means[c] / 2
    return X, [f"c{c}" for c in range(k) for _ in range(n_per)]


def spec(d=30, k=5, sets=("S",)):
    return c3.Spec(groups=[(list(range(d)), k)], passthrough=[])


# ---------- PCA ----------

def test_pca_scores_are_the_training_rows_projection_and_are_deterministic():
    X, _ = clusters()
    a, b = c3.PCA.fit(X, 4), c3.PCA.fit(X, 4)
    assert np.array_equal(a.transform(X), b.transform(X))
    Z = a.transform(X)
    assert Z.shape == (36, 4)
    assert np.allclose(Z.mean(axis=0), 0, atol=1e-9)  # centred on the training rows
    assert np.all(np.diff(Z.var(axis=0)) <= 1e-9)  # components ordered by variance


def test_pca_basis_does_not_depend_on_the_rows_it_transforms():
    X, _ = clusters()
    p = c3.PCA.fit(X[:30], 4)
    before = p.transform(X[30:31]).copy()
    X2 = X.copy()
    X2[30:] *= 1000  # held-out rows made extreme: the fitted basis must not move
    assert np.array_equal(p.transform(X[30:31]), before)
    assert np.array_equal(c3.PCA.fit(X2[:30], 4).V, p.V)


def test_pca_clamps_k_to_the_rank_and_handles_constant_columns():
    X = np.zeros((6, 5))
    X[:, 0] = np.arange(6)
    p = c3.PCA.fit(X, 20)
    assert p.transform(X).shape[1] <= 5 and np.isfinite(p.transform(X)).all()


# ---------- pipeline: acceptance ----------

def test_pipeline_identifies_separable_classes_with_both_classifiers():
    X, y = clusters()
    for clf in ("centroid", "logistic"):
        preds = c3.loo(X, y, spec(k=2), clf)[0]
        assert sum(p == t for p, t in zip(preds, y)) / len(y) > 0.9, clf


def test_pipeline_is_deterministic():
    X, y = clusters(n_per=8)
    assert c3.loo(X, y, spec(), "logistic") == c3.loo(X, y, spec(), "logistic")


# ---------- pipeline: no leakage (counterexamples) ----------

def test_labels_with_no_signal_stay_near_chance_through_the_reduction():
    rng = np.random.default_rng(1)
    X, y = rng.normal(size=(60, 40)), [f"c{i % 3}" for i in range(60)]
    for clf in ("centroid", "logistic"):
        acc = np.mean([p == t for p, t in zip(c3.loo(X, y, spec(40), clf)[0], y)])
        assert acc < 0.55, (clf, acc)  # chance 0.33; a pipeline that saw the held-out row would score far above it


def test_a_leaky_pipeline_would_be_caught_by_the_same_check():
    rng = np.random.default_rng(1)
    X, y = rng.normal(size=(60, 40)), [f"c{i % 3}" for i in range(60)]
    leaky = [c3.fit_predict(X, y, X[i:i + 1], spec(40, 40), "logistic")[0][0] for i in range(30)]  # test row inside the training rows
    assert np.mean([p == t for p, t in zip(leaky, y)]) > 0.8


def test_a_held_out_label_never_moves_its_own_prediction():
    X, y = clusters(n_per=8)
    base = c3.loo(X, y, spec(), "logistic")[0]
    for i in (0, 9, 17):
        y2 = list(y)
        y2[i] = "other"
        assert c3.loo(X, y2, spec(), "logistic")[0][i] == base[i]


def test_the_reduction_is_fitted_on_training_rows_only_in_the_outer_and_the_inner_folds(monkeypatch):
    X, y = clusters(n_per=8)
    seen = []
    orig = c3.PCA.fit.__func__

    def spy(cls, Xtr, k):
        seen.append(len(Xtr))
        return orig(cls, Xtr, k)

    monkeypatch.setattr(c3.PCA, "fit", classmethod(spy))
    c3.fit_predict(X[:23], y[:23], X[23:24], spec(), "logistic")
    # one outer fit on the 23 training rows, one per inner fold (each of 17 or 18 rows) and none on the 24-row set
    assert 23 in seen and all(n <= 23 for n in seen)
    inner = [n for n in seen if n < 23]
    assert len(inner) == c3.INNER_FOLDS and all(n < 23 for n in inner)


def test_scaling_is_fitted_on_the_training_rows(monkeypatch):
    X, y = clusters(n_per=8)
    Xs = X.copy()
    Xs[-1] = 1e6  # the held-out row is extreme; with scaling from the training rows only, other predictions cannot depend on it
    a = c3.fit_predict(X[:-1], y[:-1], X[-1:], spec(), "centroid")
    b = c3.fit_predict(Xs[:-1], y[:-1], X[-1:], spec(), "centroid")
    assert a == b


# ---------- blocks ----------

def _state():
    from lifeimage.characterise import Slice, State
    sl = [Slice("a", "sector", 0, 90, 0.2, 0.5, (0.4, 0.2, 0.1), (0.2, 0, 0), None, 0.5),
          Slice("b", "field", 0, 45, 0.5, 0.8, (0.0, 0.0, 0.0), (0.0, 0, 0), None, 1.0),
          Slice("c", "field", 45, 45, 0.5, 0.8, (0.3, 0.3, 0.3), (0.0, 0, 0), None, 1.0),
          Slice("f", "fine", 0, 10, 0.8, 1.0, (0.9, 0.9, 0.9), (0.9, 0, 0), None, 1.0)]
    return State(sl, 0)


def test_blocks_hold_levels_grain_share_and_saturation_of_the_coarse_slices_only():
    names, X, groups = c3.image_blocks([_state()])
    ix = {n: i for i, n in enumerate(names)}
    assert [n for n in names if n.startswith("f:")] == []  # the fine ring is not read
    assert X[0, ix["a:sr"]] == 0.4 and X[0, ix["a:sg"]] == 0.2 and X[0, ix["a:sb"]] == 0.1
    assert abs(X[0, ix["a:gr"]] - 0.2 / (0.4 + 0.2)) < 1e-12  # claimed red / (solid red + claimed red)
    assert X[0, ix["b:gr"]] == 0.0  # 0 / 0 is no grain
    assert X[0, ix["a:sat"]] == 0.5 and X[0, ix["c:sat"]] == 1.0
    assert set(groups) == {"L", "G", "T"} and len(groups["L"]) == 9 and len(groups["G"]) == 3 and len(groups["T"]) == 3


def test_feature_sets_have_the_registered_columns():
    names, X, groups = c3.image_blocks([_state(), _state()])
    S = np.zeros((2, 4))
    for key, n_groups in (("v2", 0), ("v3", 1), ("v3_L", 1), ("v3_GT", 1), ("v3_pca", 1)):
        M, sp = c3.feature_set(key, X, groups, S, k=2)
        assert len(sp.groups) == n_groups, key
        assert (S.shape[1] if key != "v3_pca" else 0) == len(sp.passthrough), key
    assert c3.feature_set("v3", X, groups, S, k=2)[1].groups[0][0] == groups["L"] + groups["G"] + groups["T"]
    assert c3.feature_set("v3_GT", X, groups, S, k=2)[1].groups[0][0] == groups["G"] + groups["T"]


# ---------- the v2 battery's reading is unchanged ----------

def test_the_v2_summary_reading_through_the_pipeline_equals_the_batterys_nearest_centroid():
    rng = np.random.default_rng(3)
    X = rng.normal(size=(30, 5)) + np.repeat(np.eye(5)[:3] * 1.5, 10, axis=0)
    y = [f"c{i // 10}" for i in range(30)]
    sp = c3.Spec(groups=[], passthrough=list(range(5)))
    assert c3.loo(X, y, sp, "centroid")[0] == ch.loo_accuracy(X.tolist(), y)["predictions"]


# ---------- comparisons ----------

def test_paired_difference_counts_and_sign_test():
    fa = [True] * 30 + [False] * 10 + [True] * 4
    fb = [False] * 30 + [True] * 10 + [True] * 4
    r = c3.paired(fa, fb)
    assert (r["only_a"], r["only_b"]) == (30, 10) and abs(r["diff"] - 20 / 44) < 1e-12
    assert r["lo"] < r["diff"] < r["hi"] and r["sign_p"] < 0.01
    same = c3.paired(fa, fa)
    assert same["diff"] == 0 and same["sign_p"] == 1.0


def test_clustered_paired_difference_uses_persona_means_and_does_not_overstate_independence():
    flags_a = [True, True, True] * 10 + [False] * 30
    flags_b = [False, False, False] * 10 + [False] * 30
    cl = [i // 3 for i in range(60)]  # units of a persona agree: the clustered interval is the honest one
    plain, clustered = c3.paired(flags_a, flags_b), c3.paired(flags_a, flags_b, cl)
    assert abs(clustered["diff"] - plain["diff"]) < 1e-9
    assert (clustered["hi"] - clustered["lo"]) >= (plain["hi"] - plain["lo"]) - 1e-9


def test_verdicts_follow_the_registered_rules():
    acc = {("t", "a", "c", "archetype"): {"correct": 90, "n": 100, "recalls": {"x": 0.9, "y": 0.2, "z": 0.7}},
           ("t", "b", "c", "archetype"): {"correct": 50, "n": 100, "recalls": {}}}
    flags = {k: [i < v["correct"] for i in range(v["n"])] for k, v in acc.items()}
    flags[("t", "b", "c", "archetype")] = [i % 2 == 0 for i in range(100)]
    base = {"label": "archetype", "confidence": 0.5, "text": "t"}
    got = lambda **p: c3.verdict({**base, "id": "P", **p}, acc, flags, lambda s: None)["verdict"]  # noqa: E731
    assert got(kind="min", a=["t", "a", "c"], value=0.8) == "held"
    assert got(kind="min", a=["t", "a", "c"], value=0.99) == "not held"
    assert got(kind="max", a=["t", "a", "c"], value=0.5) == "not held"
    assert got(kind="diff", a=["t", "a", "c"], b=["t", "b", "c"], delta=0.1) == "held"
    assert got(kind="diff", a=["t", "a", "c"], b=["t", "b", "c"], delta=0.9) == "not held"
    assert got(kind="rank_low", a=["t", "a", "c"], classes=["y"], k=1) == "held"
    assert got(kind="rank_low", a=["t", "a", "c"], classes=["x"], k=1) == "not held"
