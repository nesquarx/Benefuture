"""Identification ceiling plumbing: the classifiers must not see what they predict, tuning must not read the test fold,
and the summaries of rows and images must report what they hold.

Acceptance: separable data is identified, the nearest centroid agrees with the battery's `loo_accuracy`, rows and levels map
to the features named. Counterexample: labels with no signal stay near chance (a leak would score high), a held-out row never
reaches a fit, a held-out label never moves the tuned penalty.
"""
import math

import numpy as np
import pytest

from lifeimage import ceiling as ce
from lifeimage import characterise as ch


def clusters(n_per=12, k=3, d=6, gap=4.0, seed=0):
    rng = np.random.default_rng(seed)
    X = np.vstack([rng.normal(size=(n_per, d)) + gap * np.eye(d)[c % d] for c in range(k)])
    return X, [f"c{c}" for c in range(k) for _ in range(n_per)]


def noise(n=60, k=3, d=20, seed=1):
    rng = np.random.default_rng(seed)
    return rng.normal(size=(n, d)), [f"c{i % k}" for i in range(n)]


# ---------- classifiers: acceptance ----------

def test_nearest_centroid_matches_the_batterys_leave_one_out():
    rng = np.random.default_rng(3)
    X = rng.normal(size=(30, 5)) + np.repeat(np.eye(5)[:3] * 1.5, 10, axis=0)
    X[4, 2] = np.nan
    X[17, 0] = np.nan
    y = [f"c{i // 10}" for i in range(30)]
    assert ce.centroid_loo(X, y) == ch.loo_accuracy(X.tolist(), y)["predictions"]


def test_logistic_with_nested_tuning_identifies_separable_classes():
    X, y = clusters()
    preds, cs = ce.logistic_loo(X, y)
    assert ce.accuracy(y, preds)["accuracy"] >= 0.9
    assert all(c in ce.C_GRID for c in cs)


def test_logistic_is_deterministic():
    X, y = clusters(n_per=8)
    assert ce.logistic_loo(X, y) == ce.logistic_loo(X, y)


def test_logistic_fits_more_columns_than_rows():
    rng = np.random.default_rng(5)
    X = rng.normal(size=(24, 60))
    y = [f"c{i // 8}" for i in range(24)]
    X[:, :3] += 6.0 * np.repeat(np.eye(3), 8, axis=0)
    preds, _ = ce.logistic_loo(X, y)
    assert ce.accuracy(y, preds)["accuracy"] >= 0.6  # chance 1/3


# ---------- classifiers: counterexamples ----------

@pytest.mark.parametrize("run", [ce.centroid_loo, lambda X, y: ce.logistic_loo(X, y)[0]])
def test_labels_without_signal_stay_near_chance(run):
    X, y = noise()
    assert ce.accuracy(y, run(X, y))["accuracy"] <= 0.5  # chance 1/3; a leak of the held-out row would give 1.0


def test_the_held_out_row_never_reaches_a_fit():
    X, y = clusters(n_per=5)
    X = np.hstack([X, np.arange(len(y), dtype=float)[:, None]])  # a unique id column
    seen = []

    def spy(Xtr, ytr, Xte):
        seen.append((set(Xtr[:, -1]), Xte[0, -1], len(ytr)))
        return ce.nearest_centroid_predict(Xtr, ytr, Xte)

    ce.loo_predict(X, y, spy)
    assert len(seen) == len(y)
    assert all(held not in train and n == len(y) - 1 for train, held, n in seen)


def test_nested_tuning_and_every_fit_in_it_see_training_rows_only(monkeypatch):
    X, y = clusters(n_per=6)
    X = np.hstack([X, np.arange(len(y), dtype=float)[:, None]])
    held = 7
    tr = [j for j in range(len(y)) if j != held]
    fitted = []
    real = ce.LogisticModel

    class Spy(real):
        def __init__(self, Xtr, ytr, C):
            fitted.append(set(np.asarray(Xtr)[:, -1]))
            super().__init__(Xtr, ytr, C)

    monkeypatch.setattr(ce, "LogisticModel", Spy)
    ce.nested_lr_predict(X[tr], [y[j] for j in tr], X[held:held + 1])
    assert len(fitted) == len(ce.C_GRID) * ce.INNER_FOLDS + 1
    assert all(held not in ids for ids in fitted)
    assert all(ids <= set(tr) for ids in fitted)


def test_the_tuned_penalty_does_not_depend_on_the_test_row_or_its_label():
    X, y = noise(n=40, d=10)
    tr = list(range(1, 40))
    a = ce.nested_lr_predict(X[tr], [y[j] for j in tr], X[:1])[1]
    X2 = X.copy()
    X2[0] = 50.0
    b = ce.nested_lr_predict(X2[tr], [y[j] for j in tr], X2[:1])[1]
    assert a == b
    y2 = list(y)
    y2[0] = "other"  # the held-out label is not even an input of the nested call
    assert ce.select_c(X[tr], [y2[j] for j in tr])[0] == ce.select_c(X[tr], [y[j] for j in tr])[0]


def test_inner_folds_are_stratified_and_complete():
    y = ["a"] * 8 + ["b"] * 4 + ["c"] * 4
    f = ce.inner_folds(y, 4)
    for c in "abc":
        assert sorted({f[i] for i, v in enumerate(y) if v == c}) == [0, 1, 2, 3]
    assert f == ce.inner_folds(y, 4)


def test_a_dimension_with_no_variance_or_with_missing_values_does_not_break_a_fit():
    X, y = clusters(n_per=6)
    X = np.hstack([X, np.zeros((len(y), 1)), np.full((len(y), 1), np.nan)])
    assert all(p in set(y) for p in ce.logistic_loo(X, y)[0])
    assert all(p in set(y) for p in ce.centroid_loo(X, y))


# ---------- scoring ----------

def test_confusion_recall_and_top_pairs():
    y = ["a", "a", "b", "b", "c", "c"]
    p = ["a", "b", "a", "b", "b", "c"]
    m = ce.confusion(y, p, ["a", "b", "c"])
    assert m == [[1, 1, 0], [1, 1, 0], [0, 1, 1]]
    assert sum(map(sum, m)) == len(y)
    assert ce.recalls(m, ["a", "b", "c"]) == {"a": 0.5, "b": 0.5, "c": 0.5}
    assert ce.top_confusions(m, ["a", "b", "c"])[0] == ("a", "b", 1, 1)


def test_accuracy_carries_wilson_chance_and_majority():
    r = ce.accuracy(["a", "a", "b", "b"], ["a", "b", "b", "b"])
    assert r["accuracy"] == 0.75 and r["chance"] == 0.5 and r["majority"] == 0.5
    assert r["wilson"][0] < 0.75 < r["wilson"][1]


def test_sign_test_is_exact():
    assert ce.sign_test([1, 1, 0, 0], [1, 1, 0, 0]) == (0, 0, 1.0)
    x, y, p = ce.sign_test([1] * 8 + [0] * 8, [0] * 8 + [0] * 8)
    assert (x, y) == (8, 0) and p == pytest.approx(2 / 256)


# ---------- feature builders ----------

def row(ch_, tier, dom, mag, t="2026-01-01", prod="produced", conf=0.5, revoked=False):
    return {"channel": ch_, "tier": tier, "memberships": [{"domain": d, "rel": "content", "weight": 1} for d in ([dom] if isinstance(dom, str) else dom)],
            "magnitude": mag, "confidence": conf, "valid_time": t, "production": prod, "revoked": revoked}


def test_raw_features_count_and_sum_per_domain_and_channel_and_skip_revoked_rows():
    ents = [{"id": "a", "age": 30}, {"id": "b", "age": 70}]
    rows = {"a": [row("positive", "measured", "d1", 0.2), row("positive", "claimed", "d1", 0.4), row("prediction", "claimed", "d1", 0.9),
                  row("positive", "claimed", "d2", 0.1, revoked=True)],
            "b": [row("positive", "attested", ["d2", "d3"], 0.3, t="2010-01-01", prod="consumed")]}
    names, X = ce.raw_features(ents, rows, {"a": "2026-06-01", "b": "2026-06-01"})
    v = lambda i, n: X[i][names.index(n)]
    assert v(0, "count:positive:d1") == 2 and v(0, "mag:positive:d1") == pytest.approx(0.6) and v(0, "count:prediction:d1") == 1
    assert v(0, "count:positive:d2") == 0 and v(1, "count:positive:d2") == 1 and v(1, "count:positive:d3") == 1  # revoked row not counted
    assert v(0, "n_rows:positive") == 2 + 0 and v(0, "n_rows:prediction") == 1
    assert v(0, "share:claimed") == pytest.approx(2 / 3) and v(0, "share:measured") == pytest.approx(1 / 3)
    assert v(0, "pred_minus_demonstrated") == pytest.approx(0.9 - 0.2)  # demonstrated = non-claimed positive rows
    assert math.isnan(v(1, "pred_minus_demonstrated")) and math.isnan(v(1, "mean_mag:measured"))
    assert v(0, "age") == 30 and v(1, "span_years") == pytest.approx(16.4, abs=0.1) and v(1, "recent_share") == 0.0
    assert v(0, "share_produced") == 1.0 and v(1, "share_produced") == 0.0


def test_raw_features_read_fine_domains_at_the_coarse_level():
    fine = [{"id": "f.child", "level": "fine", "links": [{"rel": "upstream", "id": "c.parent", "weight": 1.0}]}]
    ents = [{"id": "a", "age": 30}]
    names, X = ce.raw_features(ents, {"a": [row("positive", "measured", "f.child", 0.2)]}, {"a": "2026-06-01"}, fine_cards=fine)
    assert "count:positive:f.child" not in names
    assert X[0][names.index("count:positive:c.parent")] == 1


def test_dropping_the_age_columns_removes_exactly_them():
    ents = [{"id": "a", "age": 30}]
    names, X = ce.raw_features(ents, {"a": [row("positive", "measured", "d1", 0.2)]}, {"a": "2026-06-01"})
    n2, X2 = ce.drop_columns(names, X, set(ce.AGE_FEATURES))
    assert set(names) - set(n2) == set(ce.AGE_FEATURES) and X2.shape[1] == len(n2)


def test_level_features_are_the_levels_the_image_draws():
    s1 = ch.Slice("a", "field", 0, 90, 0.44, 0.96, (0.1, 0.2, 0.3), (0.4, 0.0, 0.0), sat=0.85)
    s2 = ch.Slice("b", "fine", 90, 30, 0.9, 0.99, (0.5, 0.0, 0.0), (0.0, 0.0, 0.0))
    st = ch.State([s1, s2], 0)
    names, X = ce.level_features([st])
    assert names == [f"a:{k}" for k in ("sr", "sg", "sb", "cr", "cg", "cb", "sat")] and list(X[0]) == [0.1, 0.2, 0.3, 0.4, 0.0, 0.0, 0.85]
    n2, X2 = ce.level_features([st], fine=True)
    assert len(n2) == 14 and X2[0][7] == 0.5


# ---------- the tool: comparisons and verdicts ----------

def _tool():
    import importlib.util
    from pathlib import Path
    spec = importlib.util.spec_from_file_location("identification_ceiling_tool", Path(__file__).resolve().parent.parent / "tools/identification_ceiling.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_paired_difference_interval_excludes_zero_only_for_a_real_gap():
    t = _tool()
    same = t.paired([True] * 20 + [False] * 20, [True] * 20 + [False] * 20)
    assert same["diff"] == 0 and same["lo"] <= 0 <= same["hi"]
    gap = t.paired([True] * 40, [True] * 10 + [False] * 30)
    assert gap["diff"] == pytest.approx(0.75) and gap["lo"] > 0 and gap["only_a"] == 30


def test_every_prediction_names_a_level_a_label_and_a_stated_confidence():
    t = _tool()
    for p in t.PREDICTIONS:
        assert p["label"] in t.LABELS and 0 < p["conf"] < 1 and p["a"][0] in t.LEVELS and p["a"][1] in t.CLFS
    assert len({p["id"] for p in t.PREDICTIONS}) == len(t.PREDICTIONS)
