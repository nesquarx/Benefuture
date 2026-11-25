"""Bradley-Terry positions from pairwise comparisons, with ties (Davidson) and a small ridge prior.

A comparison is (i, j, outcome), outcome "a" (i is further), "b" (j is further) or "tie". Each field gets a
log-strength theta, read as its position on the axis, and a standard error from the curvature at the optimum. The
three outcomes follow a softmax over the logits theta_i, theta_j and eta + (theta_i + theta_j) / 2, where
nu = exp(eta) is the tie propensity, estimated from the data. The ridge prior on theta keeps fields never beaten (or
only tied) finite and the Hessian invertible. Both presentation orders of a pair enter as separate comparisons, so a
bias toward the first slot adds one win to each side and cancels.
"""
import math
import random
from collections import Counter
from dataclasses import dataclass

import numpy as np

OUTCOMES = ("a", "b", "tie")
RIDGE = 0.1  # prior precision on each theta (prior sd about 3 log-units)
ETA_RIDGE = 0.25  # weak prior on log nu, so data without ties gives a finite tie rate


@dataclass
class BTFit:
    theta: dict
    se: dict
    nu: float
    comparisons: int


def fit_bt(comparisons, ids=None, ridge=RIDGE, max_iter=100):
    comparisons = list(comparisons)
    names = sorted(set(ids or ()) | {x for c in comparisons for x in c[:2]})
    index = {k: n for n, k in enumerate(names)}
    n = len(names)
    counts = Counter()
    for i, j, o in comparisons:
        if o not in OUTCOMES:
            raise ValueError(f"unknown outcome {o!r}")
        counts[(index[i], index[j], OUTCOMES.index(o))] += 1
    groups = {}
    for (i, j, o), c in counts.items():
        groups.setdefault((i, j), [0, 0, 0])[o] += c
    ii = np.array([g[0] for g in groups], dtype=int)
    jj = np.array([g[1] for g in groups], dtype=int)
    cnt = np.array(list(groups.values()), dtype=float).reshape(-1, 3)
    prec = np.concatenate([np.full(n, ridge), [ETA_RIDGE]])

    def logits(p):
        th, eta = p[:n], p[n]
        return np.stack([th[ii], th[jj], eta + 0.5 * (th[ii] + th[jj])], axis=1)

    def probs(p):
        l = logits(p)
        e = np.exp(l - l.max(axis=1, keepdims=True))
        return e / e.sum(axis=1, keepdims=True), l

    def objective(p):
        pr, l = probs(p)
        lse = np.log(np.exp(l - l.max(axis=1, keepdims=True)).sum(axis=1)) + l.max(axis=1)
        return float((cnt * (l - lse[:, None])).sum() - 0.5 * (prec * p * p).sum())

    def grad_hess(p):
        pr, _ = probs(p)
        tot = cnt.sum(axis=1)
        g_l = cnt - tot[:, None] * pr  # d loglik / d logits
        # logit -> parameter maps: a: theta_i; b: theta_j; tie: eta + (theta_i + theta_j) / 2
        g = np.zeros(n + 1)
        np.add.at(g, ii, g_l[:, 0] + 0.5 * g_l[:, 2])
        np.add.at(g, jj, g_l[:, 1] + 0.5 * g_l[:, 2])
        g[n] = g_l[:, 2].sum()
        h = np.zeros((n + 1, n + 1))
        for m in range(len(ii)):
            P = pr[m]
            C = tot[m] * (np.diag(P) - np.outer(P, P))  # minus the Hessian wrt logits
            idx = np.array([ii[m], jj[m], n])
            A = np.zeros((3, 3))  # rows: logits; columns: theta_i, theta_j, eta
            A[0, 0] = A[1, 1] = 1.0
            A[2, 0] = A[2, 1] = 0.5
            A[2, 2] = 1.0
            h_small = A.T @ C @ A
            if ii[m] == jj[m]:
                raise ValueError("a field cannot be compared with itself")
            h[np.ix_(idx, idx)] += h_small
        return g - prec * p, h + np.diag(prec)

    p = np.zeros(n + 1)
    f = objective(p)
    for _ in range(max_iter):
        g, h = grad_hess(p)
        step = np.linalg.solve(h, g)
        t = 1.0
        while t > 1e-6:
            q = p + t * step
            fq = objective(q)
            if fq >= f - 1e-12:
                break
            t *= 0.5
        else:
            break
        done = np.abs(q - p).max() < 1e-9
        p, f = q, fq
        if done:
            break
    _, h = grad_hess(p)
    cov = np.linalg.inv(h)[:n, :n]
    # Positions are relative (a common shift changes nothing), so the standard error is that of theta_k minus the mean.
    row = cov.mean(axis=1)
    var = np.diag(cov) - 2 * row + cov.mean()
    return BTFit({k: float(p[index[k]]) for k in names}, {k: float(math.sqrt(max(var[index[k]], 1e-12))) for k in names},
                 float(math.exp(p[n])), len(comparisons))


def rescale(positions, se):
    """Centre on the mean and divide by the largest absolute position, so positions lie in [-1, 1]; se scale with them."""
    mean = sum(positions.values()) / len(positions)
    top = max(abs(v - mean) for v in positions.values()) or 1.0
    return {k: (v - mean) / top for k, v in positions.items()}, {k: s / top for k, s in se.items()}


def _ranks(x):
    order = sorted(range(len(x)), key=lambda i: x[i])
    r = [0.0] * len(x)
    i = 0
    while i < len(order):
        j = i
        while j + 1 < len(order) and x[order[j + 1]] == x[order[i]]:
            j += 1
        for k in range(i, j + 1):
            r[order[k]] = (i + j) / 2 + 1
        i = j + 1
    return r


def spearman(x, y):
    """Spearman rank correlation with average ranks for ties; 0 when either side is constant."""
    rx, ry = _ranks(list(x)), _ranks(list(y))
    mx, my = sum(rx) / len(rx), sum(ry) / len(ry)
    sxy = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    sxx, syy = sum((a - mx) ** 2 for a in rx), sum((b - my) ** 2 for b in ry)
    return sxy / math.sqrt(sxx * syy) if sxx > 0 and syy > 0 else 0.0


def split_half_reliability(comparisons, seed=0, ids=None):
    """Spearman between the positions fitted on two random halves of the comparisons (same fields in both)."""
    comps = list(comparisons)
    names = sorted(set(ids or ()) | {x for c in comps for x in c[:2]})
    random.Random(seed).shuffle(comps)
    half = len(comps) // 2
    f1, f2 = fit_bt(comps[:half], ids=names), fit_bt(comps[half:], ids=names)
    return spearman([f1.theta[k] for k in names], [f2.theta[k] for k in names])
