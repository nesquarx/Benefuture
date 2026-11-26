"""Age at first marriage: the distribution the generator draws from and the sequence head derives its targets from.

One truncated normal (lower bound 15) with the mean age of the stratum's singulate mean (`family.age_first_marriage`) and the governed spread, or, where the
stratum's own share married by 18 (`family.married_by_18`, household surveys) is higher than one normal spread gives, a two-component mixture: an early
component (truncated normal, governed mean and sd) with weight w, and a main component whose location is solved so the mixture's mean stays the stratum's
mean age. The weight w is solved so the share of women married before 18 equals the Param's value (as a share of those who ever marry). Without that Param,
or when one normal already reaches it, w = 0 and the distribution is the single normal. A normal spread too narrow for early marriage cannot reproduce a
heavy early tail at the right mean; the mixture can, and is judged against the same statistic as before.
"""
import bisect
from functools import lru_cache
from statistics import NormalDist

_N = NormalDist()
LO = 15.0


def trunc_mean(mu, sd, lo=LO):
    a = (lo - mu) / sd
    return mu + sd * _N.pdf(a) / (1 - _N.cdf(a))


def trunc_cdf(x, mu, sd, lo=LO):
    if x <= lo:
        return 0.0
    a = _N.cdf((lo - mu) / sd)
    return (_N.cdf((x - mu) / sd) - a) / (1 - a)


def solve_mu(mean, sd, lo=LO):
    """Location mu such that a normal(mu, sd) truncated below at lo has the given mean (bisection; mean > lo)."""
    a, b = mean - 10 * sd, mean
    for _ in range(80):
        m = (a + b) / 2
        a, b = (m, b) if trunc_mean(m, sd, lo) < mean else (a, m)
    return (a + b) / 2


class MarriageModel:
    """cdf and ppf of the age at first marriage among those who ever marry."""

    def __init__(self, mean, sd, p_early=None, early_mean=16.5, early_sd=1.5, cutoff=18.0):
        self.mean, self.sd, self.cutoff = mean, sd, cutoff
        self.mu_single = solve_mu(mean, sd)
        self.w, self.mu_main = 0.0, self.mu_single
        self.single_p_early = trunc_cdf(cutoff, self.mu_single, sd)
        self.early = (early_mean, early_sd)
        if p_early is not None and p_early > self.single_p_early + 1e-9 and 0 < p_early < 1:
            self._solve(p_early)
        xs = [LO + 0.02 * i for i in range(int((95 - LO) / 0.02) + 1)]
        self._xs, self._cdf = xs, [self.cdf(x) for x in xs]

    def _main_mu(self, w):
        m_e = trunc_mean(*self.early)
        return solve_mu((self.mean - w * m_e) / (1 - w), self.sd) if w < 1 else self.mu_single

    def _p_early(self, w):
        return w * trunc_cdf(self.cutoff, *self.early) + (1 - w) * trunc_cdf(self.cutoff, self._main_mu(w), self.sd)

    def _solve(self, target):
        lo, hi = 0.0, 0.95
        if self._p_early(hi) < target:
            self.w = hi   # target beyond reach of the early component: the closest the mixture gets (the head will flag it)
        else:
            for _ in range(50):
                m = (lo + hi) / 2
                lo, hi = (m, hi) if self._p_early(m) < target else (lo, m)
            self.w = (lo + hi) / 2
        self.mu_main = self._main_mu(self.w)

    def cdf(self, x):
        main = trunc_cdf(x, self.mu_main, self.sd)
        return main if self.w == 0 else self.w * trunc_cdf(x, *self.early) + (1 - self.w) * main

    def ppf(self, u):
        i = bisect.bisect_left(self._cdf, u)
        if i <= 0:
            return self._xs[0]
        if i >= len(self._xs):
            return self._xs[-1]
        c0, c1 = self._cdf[i - 1], self._cdf[i]
        f = (u - c0) / (c1 - c0) if c1 > c0 else 0.0
        return self._xs[i - 1] + 0.02 * f


@lru_cache(maxsize=256)
def model(mean, sd, p_early=None, early_mean=16.5, early_sd=1.5, cutoff=18.0):
    return MarriageModel(mean, sd, p_early, early_mean, early_sd, cutoff)
