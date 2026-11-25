"""Characterisation v3: blind identification from the image's levels, grain and tier together.

The feature set of `data/gold/characterisation_signatures_v3.md` (registered before any measurement): per coarse slice the solid
red, green and blue levels (block L), the red grain share (G) and the saturation of the solid layer, the tier (T), reduced by PCA,
plus the v2 summary features (S) passed through. The reduction is unsupervised and is fitted on training rows only: in every outer
training fold, and again in every inner fold of the penalty search (`fit_predict`, `select_c`); scaling is fitted there too. The
held-out row is transformed with what the training rows gave and never contributes to any fit. Classifiers are the identification
ceiling's (`ceiling.nearest_centroid_predict`, `ceiling.LogisticModel` with a nested penalty search). numpy only; deterministic.

`paired`, `verdict` and `evaluate` decide the registered predictions: accuracy bounds as the battery's, paired differences of
correct flags with a normal interval (clustered by persona for the extracted set, Student-t), exact sign tests, rankings by
observed recall.
"""
import math
from dataclasses import dataclass, field

import numpy as np

from . import ceiling as ce
from . import characterise as ch

INNER_FOLDS = ce.INNER_FOLDS
C_GRID = ce.C_GRID
FEATURE_SETS = ("v2", "v3", "v3_L", "v3_GT", "v3_pca", "v3_k10", "v3_k40")
CLASSIFIERS = ("centroid", "logistic")


# ---------- reduction ----------

class PCA:
    """Principal components of the columns standardised with the fitting rows' mean and sd (a constant column has sd 1). The top
    k right singular vectors (k clamped to the rank), each signed so its largest absolute loading is positive."""

    def __init__(self, mu, sd, V):
        self.mu, self.sd, self.V = mu, sd, V

    @classmethod
    def fit(cls, X, k):
        X = np.asarray(X, dtype=float)
        mu, sd = ce.standardise_fit(X)
        Z = ce.standardise_apply(X, mu, sd)
        _, s, vt = np.linalg.svd(Z, full_matrices=False)
        rank = int((s > 1e-10 * max(s.max(), 1e-300)).sum()) if len(s) else 0
        V = vt[:min(k, rank)].T
        if V.size:
            top = np.abs(V).argmax(axis=0)
            V = V * np.where(V[top, np.arange(V.shape[1])] < 0, -1.0, 1.0)
        return cls(mu, sd, V)

    def transform(self, X):
        return ce.standardise_apply(X, self.mu, self.sd) @ self.V


@dataclass
class Spec:
    """Which columns of a matrix are reduced (groups: [(columns, k)], each group its own PCA) and which pass through unreduced."""
    groups: list = field(default_factory=list)
    passthrough: list = field(default_factory=list)


def _fit_reducers(Xtr, spec):
    return [PCA.fit(Xtr[:, cols], k) for cols, k in spec.groups]


def _apply(reducers, spec, X):
    parts = [p.transform(X[:, cols]) for p, (cols, _) in zip(reducers, spec.groups)]
    parts.append(np.asarray(X, dtype=float)[:, spec.passthrough])
    return np.hstack(parts)


# ---------- classifiers through the reduction ----------

def select_c(Xtr, ytr, spec, grid=C_GRID, k=INNER_FOLDS):
    """The penalty with the lowest cross-validated log-loss over the training rows alone; the reduction is refitted on each inner
    fold's own training rows. Ties to the smaller C."""
    Xtr = np.asarray(Xtr, dtype=float)
    ya = np.array(ytr, dtype=object)
    fold = np.array(ce.inner_folds(list(ytr), k))
    tot = dict.fromkeys(grid, 0.0)
    for q in range(k):
        va, tr = fold == q, fold != q
        red = _fit_reducers(Xtr[tr], spec)
        Ztr, Zva = _apply(red, spec, Xtr[tr]), _apply(red, spec, Xtr[va])
        for C in grid:
            m = ce.LogisticModel(Ztr, list(ya[tr]), C)
            P = m.proba(Zva)
            col = {c: j for j, c in enumerate(m.classes)}
            tot[C] += -sum(math.log(max(P[i, col[c]], 1e-300)) for i, c in enumerate(ya[va]) if c in col)
    return min(grid, key=lambda C: (tot[C] / len(ytr), C))


def fit_predict(Xtr, ytr, Xte, spec, clf):
    """(predictions of the rows Xte, info): reduction, scaling and (logistic) penalty search all fitted on (Xtr, ytr) alone."""
    Xtr, Xte = np.asarray(Xtr, dtype=float), np.asarray(Xte, dtype=float)
    if clf == "logistic":
        C = select_c(Xtr, ytr, spec)
    red = _fit_reducers(Xtr, spec)
    Ztr, Zte = _apply(red, spec, Xtr), _apply(red, spec, Xte)
    if clf == "centroid":
        return ce.nearest_centroid_predict(Ztr, ytr, Zte), None
    return ce.LogisticModel(Ztr, list(ytr), C).predict(Zte), C


def loo(X, y, spec, clf):
    """(predictions, chosen penalties) leaving each row out in turn; the other rows are all a fit sees."""
    X = np.asarray(X, dtype=float)
    preds, info = [], []
    for i in range(len(y)):
        tr = [j for j in range(len(y)) if j != i]
        p, c = fit_predict(X[tr], [y[j] for j in tr], X[i:i + 1], spec, clf)
        preds.append(p[0])
        info.append(c)
    return preds, info


# ---------- feature blocks ----------

def image_blocks(states):
    """(names, X, groups): per coarse slice (the fine ring is not read) the solid red, green, blue levels (L), the red grain share
    claimed / (solid red + claimed red), 0 where both are 0 (G), and the solid layer's saturation (T); `groups` maps L, G, T to column indices."""
    base = [s for s in states[0].slices if s.ring != "fine"]
    names = [f"{s.id}:{k}" for s in base for k in ("sr", "sg", "sb")] + [f"{s.id}:gr" for s in base] + [f"{s.id}:sat" for s in base]
    n = len(base)
    X = np.zeros((len(states), len(names)))
    for k, st in enumerate(states):
        by = {s.id: s for s in st.slices}
        sl = [by[s.id] for s in base]
        X[k, :3 * n] = [v for s in sl for v in s.solid]
        X[k, 3 * n:4 * n] = [s.claimed[0] / (s.solid[0] + s.claimed[0]) if s.solid[0] + s.claimed[0] > 0 else 0.0 for s in sl]
        X[k, 4 * n:] = [s.sat for s in sl]
    groups = {"L": list(range(3 * n)), "G": list(range(3 * n, 4 * n)), "T": list(range(4 * n, 5 * n))}
    return names, X, groups


def feature_set(key, X, groups, S, k=20):
    """(matrix, Spec) of a registered feature set; `X` is the image block matrix, `S` the summary features."""
    if key == "v2":
        return np.asarray(S, dtype=float), Spec([], list(range(S.shape[1])))
    kk = {"v3_k10": 10, "v3_k40": 40}.get(key, k)
    cols = {"v3": groups["L"] + groups["G"] + groups["T"], "v3_k10": groups["L"] + groups["G"] + groups["T"],
            "v3_k40": groups["L"] + groups["G"] + groups["T"], "v3_pca": groups["L"] + groups["G"] + groups["T"],
            "v3_L": groups["L"], "v3_GT": groups["G"] + groups["T"]}[key]
    if key == "v3_pca":
        return np.asarray(X, dtype=float), Spec([(cols, kk)], [])
    M = np.hstack([X, np.asarray(S, dtype=float)])
    return M, Spec([(cols, kk)], list(range(X.shape[1], M.shape[1])))


# ---------- comparisons and verdicts ----------

def _tail(x, y):
    n = x + y
    return 1.0 if n == 0 else min(1.0, 2 * sum(math.comb(n, i) for i in range(min(x, y) + 1)) / 2 ** n)


def paired(fa, fb, clusters=None):
    """Paired difference of two lists of correct flags over the same units: {diff, lo, hi, only_a, only_b, sign_p}. With `clusters`
    (the cluster index of each unit), the difference is the mean of cluster means, the interval Student-t over the clusters and the
    sign test on the sign of each cluster's mean difference."""
    d = [int(a) - int(b) for a, b in zip(fa, fb)]
    if clusters is None:
        n = len(d)
        x, y = d.count(1), d.count(-1)
        diff = (x - y) / n
        se = math.sqrt(max(0.0, (x + y) - (x - y) ** 2 / n)) / n
        lo, hi = diff - 1.96 * se, diff + 1.96 * se
        return {"diff": diff, "lo": lo, "hi": hi, "only_a": x, "only_b": y, "sign_p": _tail(x, y)}
    cl = {}
    for c, v in zip(clusters, d):
        cl.setdefault(c, []).append(v)
    m = [sum(v) / len(v) for _, v in sorted(cl.items())]
    n = len(m)
    diff = sum(m) / n
    sd = math.sqrt(sum((v - diff) ** 2 for v in m) / (n - 1)) if n > 1 else 0.0
    half = ch.t_crit(n - 1) * sd / math.sqrt(n)
    x, y = sum(v > 1e-12 for v in m), sum(v < -1e-12 for v in m)
    return {"diff": diff, "lo": diff - half, "hi": diff + half, "only_a": x, "only_b": y, "sign_p": _tail(x, y)}


def verdict(p, acc, flags, clusters_of):
    """The verdict of registered prediction `p`. `acc[(set, fset, clf, label)]` is {correct, n, recalls, ...}; `flags` the same keys'
    correct flags; `clusters_of(set)` the cluster indices of a set's units (None when units are independent)."""
    lab, kind = p["label"], p["kind"]
    key = lambda t: (t[0], t[1], t[2], lab)  # noqa: E731
    base = {"id": p["id"], "label": lab, "kind": kind, "confidence": p["confidence"], "text": p["text"]}
    if kind in ("min", "max"):
        a = acc[key(p["a"])]
        return {**base, **ch.identification_verdict(kind, p["value"], a["correct"], a["n"])}
    if kind == "diff":
        sa, sb = p["a"][0], p["b"][0]
        r = paired(flags[key(p["a"])], flags[key(p["b"])], clusters_of(sa) if sa == sb else None)
        d = p["delta"]
        v = "held" if r["diff"] >= d and r["lo"] > 0 else "not held" if r["hi"] < d else "inconclusive"
        return {**base, **r, "delta": d, "verdict": v}
    rec = acc[key(p["a"])]["recalls"]
    order = sorted(rec, key=lambda c: (rec[c], c))
    got = order[:p["k"]]
    return {**base, "verdict": "held" if set(got) & set(p["classes"]) else "not held", "observed": got, "recalls": rec}
