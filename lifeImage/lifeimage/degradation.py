"""Progressive degradation, loudly: when a mechanism falls back to a coarser substitute, the substitution is recorded
(step or item, mechanism, substitute, reason) and warned once per mechanism, never silent.

Callers pass their own `log` list; without one the record goes to the module's DEGRADED list.
"""
import warnings

DEGRADED = []
_WARNED = set()


def record_degradation(step, mechanism, substitute, reason, log=None):
    rec = {"step": step, "mechanism": mechanism, "substitute": substitute, "reason": reason}
    (DEGRADED if log is None else log).append(rec)
    if mechanism not in _WARNED:
        _WARNED.add(mechanism)
        warnings.warn(f"degraded: {mechanism} used {substitute} ({reason})", RuntimeWarning, stacklevel=3)
    return rec


def reset_warned():
    _WARNED.clear()
