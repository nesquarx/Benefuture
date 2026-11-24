import pytest

from lifeimage.pressure import pressure_from_annotations, pressure_from_evidence

DOMAINS = ["c.a", "c.b", "c.c", "c.d"]


def row(*ms):
    return {"memberships": [{"domain": d, "rel": r, "weight": w} for d, r, w in ms]}


def test_pressure_is_a_distribution_over_every_listed_domain():
    p = pressure_from_evidence([row(("c.a", "content", 1.0))] * 3, DOMAINS, smoothing=0.5)
    assert set(p) == set(DOMAINS) and sum(p.values()) == pytest.approx(1.0)


def test_more_evidence_means_more_pressure_and_smoothing_keeps_empty_domains_positive():
    rows = [row(("c.a", "content", 1.0))] * 6 + [row(("c.b", "content", 1.0))] * 2
    p = pressure_from_evidence(rows, DOMAINS, smoothing=1.0)
    assert p["c.a"] > p["c.b"] > p["c.c"] > 0 and p["c.c"] == pytest.approx(p["c.d"])
    assert p["c.a"] == pytest.approx((6 + 1) / (8 + 4))  # share with additive smoothing


def test_a_row_counts_once_whatever_its_number_of_memberships_and_splits_by_weight():
    rows = [row(("c.a", "form", 0.5), ("c.b", "form", 0.5), ("c.c", "content", 1.0))]
    p = pressure_from_evidence(rows, DOMAINS, smoothing=0.0)
    assert p["c.c"] == pytest.approx(0.5) and p["c.a"] == pytest.approx(0.25) and sum(p.values()) == pytest.approx(1)


def test_no_evidence_gives_the_uniform_distribution_and_unknown_domains_are_ignored():
    assert pressure_from_evidence([], DOMAINS) == pytest.approx({d: 0.25 for d in DOMAINS})
    p = pressure_from_evidence([row(("c.zz", "content", 1.0))], DOMAINS, smoothing=1.0)
    assert p == pytest.approx({d: 0.25 for d in DOMAINS})


def test_annotations_count_each_item_once_across_types():
    items = {"1": {"form": {"c.a": 1.0}, "content": {"c.a": 0.5, "c.b": 0.5}}, "2": {"form": {"c.b": 1.0}, "outcome": None}}
    p = pressure_from_annotations(items, DOMAINS, smoothing=0.0)
    assert p["c.a"] == pytest.approx(0.75 / 2) and p["c.b"] == pytest.approx(1.25 / 2) and p["c.c"] == 0.0


def test_negative_smoothing_is_refused():
    with pytest.raises(ValueError):
        pressure_from_evidence([], DOMAINS, smoothing=-1)
