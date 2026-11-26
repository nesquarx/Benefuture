"""LI.66: the seriation order is the basemap's coarse ring order (a new basemap version); the axes layout stays reproducible.

Red baseline (on the code before adoption): the default basemap's field ring order was the axes-angle order, not the
seriation order, so the ring still showed the outliers the seriation removes (arts and religion beside mathematics and
statistics; housing among agriculture).
"""
import json
from pathlib import Path

import pytest

from lifeimage import governed
from lifeimage import layout_migration as lm
from lifeimage import seriation as sr
from lifeimage.render import basemap as bmod

ROOT = Path(__file__).resolve().parent.parent


def field_order(bm):
    return [i for i, _ in sorted(((i, s.start) for i, s in bm.slices.items() if s.ring == "field"), key=lambda t: t[1])]


def seriation_order():
    return json.loads((ROOT / "data/coarse/seriation_v0.json").read_text())["ring_order"]["C"]


@pytest.fixture(scope="module")
def default():
    return bmod.build_v0(log=[])


@pytest.fixture(scope="module")
def axes():
    return bmod.build_v0(layout="axes_v0", log=[])


def test_default_ring_order_is_the_seriation_order(default):
    assert field_order(default) == seriation_order()


def test_default_ring_has_no_named_outliers(default):
    assert not any(sr.named_outliers(field_order(default)).values())


def test_new_version_id_and_old_one_stay_distinct(default, axes):
    assert default.version == "0.0.0-draft+seriation_v0"
    assert axes.version == "0.0.0-draft"


def test_axes_layout_is_still_reproducible_and_is_the_axes_order(axes):
    ship = json.loads((ROOT / "data/coarse/seriation_v0.json").read_text())["ring_order"]["A"]
    assert field_order(axes) == ship


def test_sectors_and_domain_set_unchanged_by_the_layout(default, axes):
    assert set(default.slices) == set(axes.slices) and set(default.fine) == set(axes.fine)
    secs = lambda b: {i: (s.start, s.width) for i, s in b.slices.items() if s.ring == "sector"}
    assert secs(default) == secs(axes)
    assert {i: s.width for i, s in default.slices.items()} == {i: s.width for i, s in axes.slices.items()}  # widths follow pressure either way


def test_fine_domains_stay_inside_their_parent_arc(default):
    for s in default.fine.values():
        p = default.slices[s.parent]
        assert (s.start - p.start) % 360 <= p.width + 1e-6


def test_axes_angle_is_the_axes_not_the_slot(default, axes):
    assert {i: s.axes_angle for i, s in default.slices.items()} == {i: s.axes_angle for i, s in axes.slices.items()}


def test_unknown_layout_is_refused():
    with pytest.raises(ValueError):
        bmod.build_v0(layout="no_such_layout", log=[])


def test_pinned_layout_file_matches_the_arm_it_was_adopted_from():
    pin = json.loads((ROOT / "data/coarse/layout_seriation_v0.json").read_text())
    arm = json.loads((ROOT / "data/coarse/seriation_v0.json").read_text())
    assert pin["order"] == arm["order"] and pin["angles"] == arm["angles"]


# ---- migration record and the LI.25 stability exception (LI.66) ----

def test_migration_record_matches_a_recomputation(default, axes):
    rec = json.loads((ROOT / "data/coarse/layout_migration_seriation_v0.json").read_text())
    fresh = lm.migration(axes, default)
    assert rec["fields"] == fresh["fields"]
    assert rec["stats"] == fresh["stats"]
    assert rec["from"] == "0.0.0-draft" and rec["to"] == "0.0.0-draft+seriation_v0"


def test_stability_targets_are_exceeded_and_the_exception_is_recorded_not_loosened(default, axes):
    rec = lm.migration(axes, default)
    new = rec["stats_vs_axes_angle"]["new"]
    guard = governed.governed("layout_sim.shift_max")
    assert (lm.TARGET_MEAN, lm.TARGET_P95, guard) == (25.0, 60.0, 120.0)  # the LI.25 targets and the guard, unchanged
    limits = {"mean": lm.TARGET_MEAN, "p95": lm.TARGET_P95, "max": guard}
    over = {m for m, t in limits.items() if new[m] > t}
    assert {"mean", "p95"} <= over, "if the adoption meets the targets, drop the exception"
    ex = rec["exceptions"]
    assert all(e["ref"] == "LI.66" and e["status"] == "deferred to the placement clean-up" for e in ex)
    assert {e["metric"] for e in ex} == over  # every exceeded limit is listed, none silently
    assert new["max"] <= guard + 3.0  # the guard held on the slots; tiling by pressure widths adds a few degrees (seriation_v0.json: 122.8)


def test_stability_matches_the_arm_s_report(default):
    arm = json.loads((ROOT / "data/coarse/seriation_v0.json").read_text())["arms"]["C"]["stability"]
    new = lm.migration(bmod.build_v0(layout="axes_v0", log=[]), default)["stats_vs_axes_angle"]["new"]
    assert new["mean"] == pytest.approx(arm["mean_shift"], abs=0.01) and new["max"] == pytest.approx(arm["max_shift"], abs=0.01)


def test_exception_is_loud_as_a_degraded_entry(default, axes):
    log = []
    lm.record_exceptions(lm.migration(axes, default), log)
    assert log and all(r["mechanism"] == "layout_stability" and "LI.66" in r["reason"] for r in log)


def test_every_field_shift_is_listed(default, axes):
    rec = lm.migration(axes, default)
    fields = [i for i, s in default.slices.items() if s.ring == "field"]
    assert set(rec["fields"]) == set(fields)
    for i, row in rec["fields"].items():
        assert row["new"] == pytest.approx(default.slices[i].angle % 360, abs=1e-3)
        assert row["old"] == pytest.approx(axes.slices[i].angle % 360, abs=1e-3)
