"""Migration between basemap layouts (LI.25 stability, LI.66): per-field angle change old -> new and the stability report.

A layout change moves slice angles and no domain id, so the id migration table (`migration.py`) between the two versions is
identity and a levels file migrates by relabelling its version (`render.tiles.migrate_levels` with an empty table). What
changes is where each field sits; this module records that field by field.

Stability (LI.25): the mean and 95th-percentile shift of the field slice centres from their axes angles, and the maximum
against the guard (`layout_sim.shift_max`); `stats` also gives the old -> new shift of the centres. The targets below come from the pre-registered predictions (`data/gold/layout_sim_predictions.md`,
"Stability"); they are targets of the design, not governed values. Where an adoption exceeds them the exception is recorded in
the migration file and as a loud `layout_stability` degraded entry, tied to the ruling that allows it, never loosened here.
"""
import json
import math
from pathlib import Path

import numpy as np

from .degradation import record_degradation
from .governed import governed
from .layout import circ_diff

TARGET_MEAN = 25.0  # degrees: LI.25 stability target (predictions, Stability)
TARGET_P95 = 60.0  # degrees: LI.25 stability target
ROOT = Path(__file__).resolve().parent.parent
RULING = "LI.66"
DEFERRED = "deferred to the placement clean-up"


def _stats(d):
    d = np.array(d, dtype=float)
    return {"mean": round(float(d.mean()), 4), "p95": round(float(np.percentile(d, 95)), 4), "max": round(float(d.max()), 4), "n": int(d.size)}


def migration(old, new, ruling=RULING):
    """The record of moving from basemap `old` to `new`: per-field old and new centre angles and the shift between them,
    shift statistics per ring, and the exceptions to the stability targets."""
    fields = {}
    for i, sl in sorted(new.slices.items()):
        if sl.ring == "field" and i in old.slices:
            o = old.slices[i]
            fields[i] = {"old": round(o.angle % 360, 4), "new": round(sl.angle % 360, 4), "shift": round(circ_diff(sl.angle, o.angle), 4)}
    stats = {}
    for ring in ("field", "sector", "fine"):
        get = (lambda b: b.fine) if ring == "fine" else (lambda b, r=ring: {i: s for i, s in b.slices.items() if s.ring == r})
        stats[ring] = _stats([circ_diff(s.angle, get(old)[i].angle) for i, s in get(new).items() if i in get(old)])
    # LI.25 stability is the drift of the slice centre from the axes angle (as the predictions and the seriation arm measure it)
    axes_shift = {name: _stats([circ_diff(s.angle, s.axes_angle) for s in b.slices.values() if s.ring == "field"])
                  for name, b in (("old", old), ("new", new))}
    f = axes_shift["new"]
    guard = governed("layout_sim.shift_max")
    exceptions = [{"metric": m, "value": f[m], "target": t, "ref": ruling, "status": DEFERRED,
                   "reason": f"the seriation lambda trades stability for adjacency; the {m} shift of {f[m]:.1f} degrees from the axes angle exceeds the "
                             f"{'LI.25 target' if m != 'max' else 'guard (layout_sim.shift_max)'} of {t:g}, accepted by the author in {ruling} "
                             f"and refined in the placement clean-up"}
                  for m, t in (("mean", TARGET_MEAN), ("p95", TARGET_P95), ("max", guard)) if f[m] > t + 1e-9]
    return {"from": old.version, "to": new.version, "ids": "unchanged (identity id migration table)",
            "targets": {"mean": TARGET_MEAN, "p95": TARGET_P95, "max": guard},
            "stats": stats, "stats_vs_axes_angle": axes_shift, "exceptions": exceptions, "fields": fields}


def record_exceptions(rec, log=None):
    """One loud `degraded` entry per exceeded stability target (see `degradation`)."""
    return [record_degradation(f"layout {rec['from']} -> {rec['to']}", "layout_stability",
                               f"{e['metric']} shift {e['value']:.1f} accepted above target {e['target']:g}", f"{e['ref']}: {e['reason']}", log)
            for e in rec["exceptions"]]


def write(rec, path):
    Path(path).write_text(json.dumps(rec, sort_keys=True, indent=1) + "\n", encoding="utf-8")
