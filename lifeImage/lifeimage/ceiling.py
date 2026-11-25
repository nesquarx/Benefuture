"""Identification ceiling: how well can archetype and calibration be read at each level of the pipeline?

Three levels of one population, the same labels and the same leave-one-out protocol:

* raw rows: the truth rows of a persona summarised per coarse domain and channel (counts, magnitudes), tier and production
  shares, and age (`raw_features`);
* image levels: every coarse slice's solid and claimed channel levels and saturation as the image encodes them
  (`level_features`), optionally with the fine ring;
* summary features: the pre-registered features (`characterise.identification_names`).

Classifiers: nearest centroid (the battery's), and multinomial logistic regression with an L2 penalty whose strength is
chosen by nested cross-validation inside every training fold (`nested_lr_predict`). Invariants: a held-out persona is never
seen by any fit, standardisation or tuning step (`loo_predict` hands the model only the other rows); the inner folds of the
tuning are cut from the training rows alone, so the tuning can never read the held-out rows or labels (`select_c`).
numpy only; deterministic (no random numbers: folds are by position within the class, the optimiser is deterministic).
"""
import math

import numpy as np

from . import levels as lv
from .characterise import wilson
from .fine.cards import coarsen_rows

CHANNELS = ("positive", "negative", "prediction")
TIERS = ("claimed", "attested", "measured")
C_GRID = (1e-4, 1e-3, 1e-2, 1e-1, 1.0, 10.0)
INNER_FOLDS = 4
AGE_FEATURES = ("age", "recent_share", "span_years")


# ---------- standardisation ----------

def standardise_fit(X):
    """(mean, sd) per column from the rows given, ignoring NaN; a constant column has sd 1."""
    X = np.asarray(X, dtype=float)
    ok = ~np.isnan(X)
    n = ok.sum(axis=0)
    s = np.where(ok, X, 0.0).sum(axis=0)
    mu = np.divide(s, n, out=np.zeros(X.shape[1]), where=n > 0)
    dev = np.where(ok, X - mu, 0.0)
    sd = np.sqrt(np.divide((dev ** 2).sum(axis=0), n, out=np.zeros(X.shape[1]), where=n > 0))
    return mu, np.where(sd > 1e-12, sd, 1.0)


def standardise_apply(X, mu, sd):
    X = np.asarray(X, dtype=float)
    return (np.where(np.isnan(X), mu, X) - mu) / sd


# ---------- classifiers ----------

def nearest_centroid_predict(Xtr, ytr, Xte):
    """Class of the nearest centroid of the training fold in its own standardised space; ties go to the first class in sorted order."""
    mu, sd = standardise_fit(Xtr)
    Z, Zt = standardise_apply(Xtr, mu, sd), standardise_apply(Xte, mu, sd)
    classes = sorted(set(ytr))
    ya = np.array(ytr, dtype=object)
    cent = np.array([Z[ya == c].mean(axis=0) for c in classes])
    d = ((Zt[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2)
    return [classes[k] for k in d.argmin(axis=1)]


def _softmax(S):
    S = S - S.max(axis=1, keepdims=True)
    E = np.exp(S)
    return E / E.sum(axis=1, keepdims=True)


def _lbfgs(f, x0, iters=300, m=10, gtol=1e-6):
    """Minimise f (returns value and gradient) from x0: L-BFGS two-loop recursion, Armijo backtracking. Deterministic."""
    x = x0.copy()
    v, g = f(x)
    hist = []
    for _ in range(iters):
        if np.abs(g).max() < gtol:
            break
        q = g.copy()
        alphas = []
        for s, y, rho in reversed(hist):
            a = rho * s.dot(q)
            alphas.append(a)
            q -= a * y
        if hist:
            s, y, _ = hist[-1]
            q *= s.dot(y) / y.dot(y)
        for (s, y, rho), a in zip(hist, reversed(alphas)):
            q += s * (a - rho * y.dot(q))
        d = -q
        slope = g.dot(d)
        if slope >= 0:
            d, slope, hist = -g, -g.dot(g), []
        t = 1.0 if hist else min(1.0, 1.0 / max(np.abs(g).max(), 1e-12))
        while True:
            xn = x + t * d
            vn, gn = f(xn)
            if vn <= v + 1e-4 * t * slope or t < 1e-12:
                break
            t *= 0.5
        s, y = xn - x, gn - g
        sy = s.dot(y)
        if sy > 1e-12:
            hist.append((s, y, 1.0 / sy))
            hist = hist[-m:]
        if abs(v - vn) < 1e-12 * max(1.0, abs(v)):
            x, v, g = xn, vn, gn
            break
        x, v, g = xn, vn, gn
    return x


class LogisticModel:
    """Multinomial logistic regression, loss sum of cross-entropies + ||W||^2 / (2 C), bias unpenalised. Features are
    standardised on the training rows and rotated onto their singular vectors (exact for an L2 penalty), which caps the
    dimension at the number of training rows."""

    def __init__(self, Xtr, ytr, C):
        self.mu, self.sd = standardise_fit(Xtr)
        Z = standardise_apply(Xtr, self.mu, self.sd)
        _, s, vt = np.linalg.svd(Z, full_matrices=False)
        self.V = vt[s > 1e-10 * max(s.max(), 1e-300)].T if len(s) else np.zeros((Z.shape[1], 0))
        T = Z @ self.V
        self.classes = sorted(set(ytr))
        idx = {c: k for k, c in enumerate(self.classes)}
        n, r = T.shape
        K = len(self.classes)
        Y = np.zeros((n, K))
        Y[np.arange(n), [idx[c] for c in ytr]] = 1.0
        lam = 1.0 / C

        def f(theta):
            W, b = theta[:r * K].reshape(r, K), theta[r * K:]
            P = _softmax(T @ W + b)
            loss = -np.log(np.clip(P[Y > 0], 1e-300, None)).sum() + 0.5 * lam * (W ** 2).sum()
            D = P - Y
            return loss, np.concatenate([(T.T @ D + lam * W).ravel(), D.sum(axis=0)])

        th = _lbfgs(f, np.zeros(r * K + K))
        self.W, self.b = th[:r * K].reshape(r, K), th[r * K:]

    def proba(self, X):
        return _softmax((standardise_apply(X, self.mu, self.sd) @ self.V) @ self.W + self.b)

    def predict(self, X):
        return [self.classes[k] for k in self.proba(X).argmax(axis=1)]


def inner_folds(y, k=INNER_FOLDS):
    """Stratified deterministic folds: fold of a row = its rank among the rows of its class, mod k."""
    seen, fold = {}, []
    for c in y:
        seen[c] = seen.get(c, -1) + 1
        fold.append(seen[c] % k)
    return fold


def select_c(Xtr, ytr, grid=C_GRID, k=INNER_FOLDS):
    """The penalty (of `grid`) with the lowest cross-validated log-loss over the training rows alone; ties to the smaller C.
    Returns (C, {C: log-loss})."""
    Xtr = np.asarray(Xtr, dtype=float)
    fold = np.array(inner_folds(list(ytr), k))
    ya = np.array(ytr, dtype=object)
    scores = {}
    for C in grid:
        tot = 0.0
        for q in range(k):
            va, tr = fold == q, fold != q
            m = LogisticModel(Xtr[tr], list(ya[tr]), C)
            P = m.proba(Xtr[va])
            col = {c: j for j, c in enumerate(m.classes)}
            tot += -sum(math.log(max(P[i, col[c]], 1e-300)) for i, c in enumerate(ya[va]) if c in col)
        scores[C] = tot / len(ytr)
    return min(grid, key=lambda C: (scores[C], C)), scores


def nested_lr_predict(Xtr, ytr, Xte, grid=C_GRID, k=INNER_FOLDS):
    """Tune C on the training rows by inner cross-validation, refit on all of them, predict the test rows: (predictions, C)."""
    C, _ = select_c(Xtr, ytr, grid, k)
    return LogisticModel(np.asarray(Xtr, dtype=float), list(ytr), C).predict(Xte), C


def loo_predict(X, y, fit_predict):
    """Leave one out: for each row i, `fit_predict(X_train, y_train, X_i)` sees only the other rows. Returns the predictions
    (and, when fit_predict returns (predictions, info), the infos)."""
    X = np.asarray(X, dtype=float)
    preds, infos = [], []
    for i in range(len(y)):
        tr = [j for j in range(len(y)) if j != i]
        out = fit_predict(X[tr], [y[j] for j in tr], X[i:i + 1])
        if isinstance(out, tuple):
            out, info = out
            infos.append(info)
        preds.append(out[0])
    return preds, infos


def centroid_loo(X, y):
    return loo_predict(X, y, nearest_centroid_predict)[0]


def logistic_loo(X, y, grid=C_GRID, k=INNER_FOLDS):
    return loo_predict(X, y, lambda a, b, c: nested_lr_predict(a, b, c, grid, k))


# ---------- scoring ----------

def accuracy(y, preds):
    correct = sum(p == t for p, t in zip(preds, y))
    classes = sorted(set(y))
    return {"correct": correct, "n": len(y), "accuracy": correct / len(y) if y else 0.0, "wilson": wilson(correct, len(y)),
            "chance": 1 / len(classes), "majority": max(y.count(c) for c in classes) / len(y)}


def confusion(y, preds, classes):
    """Matrix [truth][predicted] of counts."""
    ix = {c: i for i, c in enumerate(classes)}
    m = [[0] * len(classes) for _ in classes]
    for t, p in zip(y, preds):
        m[ix[t]][ix[p]] += 1
    return m


def recalls(m, classes):
    return {c: (m[i][i] / sum(m[i]) if sum(m[i]) else 0.0) for i, c in enumerate(classes)}


def top_confusions(m, classes, n=5):
    """Unordered pairs by total confusions both ways: [(a, b, a taken for b, b taken for a)], largest first."""
    pairs = [(classes[i], classes[j], m[i][j], m[j][i]) for i in range(len(classes)) for j in range(i + 1, len(classes)) if m[i][j] + m[j][i]]
    return sorted(pairs, key=lambda p: (-(p[2] + p[3]), p[0], p[1]))[:n]


def sign_test(a, b):
    """(only a right, only b right, exact two-sided p) over paired correctness flags."""
    x = sum(1 for p, q in zip(a, b) if p and not q)
    y = sum(1 for p, q in zip(a, b) if q and not p)
    n = x + y
    if n == 0:
        return x, y, 1.0
    return x, y, min(1.0, 2 * sum(math.comb(n, k) for k in range(min(x, y) + 1)) / 2 ** n)


# ---------- feature builders ----------

def raw_features(entities, rows_by_id, asof_by_id, fine_cards=()):
    """(names, X) from each entity's rows read at the coarse level: per coarse domain and channel the number of rows naming it and
    their summed magnitude; per channel the row count; tier shares and mean magnitude and confidence per tier; the produced
    share; the mean prediction minus demonstrated magnitude over domains with both; and (AGE_FEATURES) age, the share of rows
    in the last five years and the evidence span in years. Domains are those named by any entity (no labels read)."""
    per = []
    for e in entities:
        rows = coarsen_rows(rows_by_id[e["id"]], list(fine_cards)) if fine_cards else rows_by_id[e["id"]]
        per.append((e, [r for r in rows if not r["revoked"] and r["channel"] in CHANNELS]))
    doms = sorted({m["domain"] for _, rs in per for r in rs for m in r["memberships"]})
    names = [f"count:{c}:{d}" for c in CHANNELS for d in doms] + [f"mag:{c}:{d}" for c in CHANNELS for d in doms]
    names += [f"n_rows:{c}" for c in CHANNELS] + [f"share:{t}" for t in TIERS] + [f"mean_mag:{t}" for t in TIERS]
    names += [f"mean_conf:{t}" for t in TIERS] + ["share_produced", "pred_minus_demonstrated"] + list(AGE_FEATURES)
    nan = float("nan")
    X = np.full((len(per), len(names)), nan)
    for k, (e, rs) in enumerate(per):
        v = dict.fromkeys(names, 0.0)
        pred, demo = {}, {}
        for r in rs:
            for d in {m["domain"] for m in r["memberships"]}:
                v[f"count:{r['channel']}:{d}"] += 1
                v[f"mag:{r['channel']}:{d}"] += r["magnitude"]
                if r["channel"] == "prediction":
                    pred.setdefault(d, []).append(r["magnitude"])
                elif r["channel"] == "positive" and r["tier"] != "claimed":
                    demo.setdefault(d, []).append(r["magnitude"])
        for c in CHANNELS:
            v[f"n_rows:{c}"] = sum(r["channel"] == c for r in rs)
        n = len(rs)
        for t in TIERS:
            sel = [r for r in rs if r["tier"] == t]
            v[f"share:{t}"] = len(sel) / n if n else 0.0
            v[f"mean_mag:{t}"] = sum(r["magnitude"] for r in sel) / len(sel) if sel else nan
            v[f"mean_conf:{t}"] = sum(r["confidence"] for r in sel) / len(sel) if sel else nan
        v["share_produced"] = sum(r.get("production") == "produced" for r in rs) / n if n else 0.0
        both = [d for d in pred if d in demo]
        v["pred_minus_demonstrated"] = (sum(sum(pred[d]) / len(pred[d]) - sum(demo[d]) / len(demo[d]) for d in both) / len(both)) if both else nan
        asof = lv.parse_time(asof_by_id[e["id"]]).toordinal()
        ts = [lv.parse_time(r["valid_time"]).toordinal() for r in rs]
        v["age"] = float(e["age"])
        v["recent_share"] = sum(asof - t <= 5 * 365.25 for t in ts) / n if n else 0.0
        v["span_years"] = (asof - min(ts)) / 365.25 if ts else 0.0
        X[k] = [v[nm] for nm in names]
    return names, X


def level_features(states, fine=False):
    """(names, X): per slice of the coarse rings (and, with `fine`, the fine ring) the solid red, green, blue levels, the claimed
    (grain) levels and the saturation, exactly what the renderer draws from."""
    base = [s for s in states[0].slices if fine or s.ring != "fine"]
    names = [f"{s.id}:{k}" for s in base for k in ("sr", "sg", "sb", "cr", "cg", "cb", "sat")]
    X = np.zeros((len(states), len(names)))
    for k, st in enumerate(states):
        by = {s.id: s for s in st.slices}
        row = []
        for s in base:
            t = by[s.id]
            row += [*t.solid, *t.claimed, t.sat]
        X[k] = row
    return names, X


def summary_features(records, names):
    from .characterise import _vector
    return np.array([_vector(r, names) for r in records], dtype=float)


def drop_columns(names, X, drop):
    keep = [i for i, n in enumerate(names) if n not in drop]
    return [names[i] for i in keep], X[:, keep]
