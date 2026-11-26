"""Calibration table: a Param missing source, URL, stratum, confidence or snippet fails; duplicates fail; the committed table is valid."""
import dataclasses
import warnings

import pytest

from lifeimage.eventgen import calibration as cal
from lifeimage.generators.common import seed_ids


def EV(**over):
    e = dict(actor="A woman aged 20-24 in Kenya", action="gave birth to a child", outcome="became a parent", timescale="life transition", domains=["c.birth_of_child"],
             source_id="WPP2024", locator="WPP2024_Fertility_by_Age5 ASFR", sanitization="paraphrase; no individual record")
    e.update(over)
    return e


def P(**over):
    base = dict(field="c.birth_of_child", quantity="fertility.asfr", value=100.0, unit="per 1000 women", age_band="20-24", sex="f",
                region="KEN", year=2023, source_id="WPP2024", source_url="https://population.un.org/wpp/", licence="open",
                confidence="medium", source_statement="Age-specific fertility rate, 20-24, Kenya, 2023: 100", event_snippets=[EV()], snippet_locator="WPP2024_Fertility_by_Age5 ASFR",
                retrieved="2026-11-26")
    base.update(over)
    return cal.Param(**base)


@pytest.mark.parametrize("bad", [dict(source_id=""), dict(source_url=""), dict(source_url="population.un.org"), dict(region=""), dict(region="Kenya"),
                                 dict(confidence=""), dict(confidence="certain"), dict(licence="free"), dict(age_band=""), dict(sex="x"),
                                 dict(value=float("nan")), dict(field="c.nonexistent")])
def test_incomplete_params_fail(bad):
    with pytest.raises(cal.CalibrationError):
        cal.Table([P(**bad)], seed_ids())


def test_source_statement_and_snippet_rules():
    with pytest.raises(cal.CalibrationError):
        cal.Table([P(source_statement="", event_snippets=[])])                       # nothing, no reason
    with pytest.raises(cal.CalibrationError):
        cal.Table([P(event_snippets=[])])                                            # no event snippet, no reason
    cal.Table([P(event_snippets=[], snippet_missing="no event phrasing written")])
    with pytest.raises(cal.CalibrationError):
        cal.Table([P(source_statement="", snippet_missing="page 403")])              # reason given but confidence not low
    cal.Table([P(source_statement="", snippet_missing="page 403", confidence="low")])
    with pytest.raises(cal.CalibrationError):
        cal.Table([P(source_statement="x" * 500)])                                   # a page, not a quotation
    with pytest.raises(cal.CalibrationError):
        cal.Table([P(retrieved="")])


@pytest.mark.parametrize("bad", [dict(actor=""), dict(action=""), dict(timescale=""), dict(timescale="sometime"), dict(domains=[]), dict(domains=["fertility"]), dict(locator=""),
                                 dict(sanitization=""), dict(actor="A woman called Maria Lopez in Kenya"),
                                 dict(outcome="She later met John Smith"), dict(action="x" * 500)])
def test_bad_event_snippets_fail(bad):
    with pytest.raises(cal.CalibrationError):
        cal.Table([P(event_snippets=[EV(**bad)])], figures=frozenset())


def test_public_figures_may_be_named_and_places_may_appear():
    cal.Table([P(event_snippets=[EV(actor="Angela Merkel in Germany", action="left office")])], figures=frozenset({"Angela Merkel"}))
    with pytest.raises(cal.CalibrationError):
        cal.Table([P(event_snippets=[EV(actor="Angela Merkel in Germany", action="left office")])], figures=frozenset())
    cal.Table([P(event_snippets=[EV(actor="A woman in Sub-Saharan Africa", action="left school to marry")])], figures=frozenset())


def test_duplicate_keys_fail():
    with pytest.raises(cal.CalibrationError):
        cal.Table([P(), P(value=101.0, year=2022)])
    cal.Table([P(), P(age_band="25-29")])


def test_lookup_falls_back_loudly_and_never_stalls():
    t = cal.Table([P(region="WLD"), P(region="SSF", value=120.0)])
    regions = {"KEN": "SSF", "DEU": "ECS"}
    with warnings.catch_warnings(record=True) as w:
        warnings.simplefilter("always")
        assert t.lookup("fertility.asfr", "20-24", "f", "KEN", regions).value == 120.0
        assert t.lookup("fertility.asfr", "20-24", "f", "DEU", regions).value == 100.0
        assert t.lookup("fertility.asfr", "20-24", "f", "FRA", regions).value == 100.0
        assert t.lookup("nothing.here", "all", "all", "FRA", regions) is None
    assert [d["substitute"] for d in t.degraded] == ["SSF", "WLD", "WLD", "none"]
    assert len(w) == 3                                              # one warning per kind: region, world, none
    assert all({"step", "mechanism", "substitute", "reason"} <= set(d) for d in t.degraded)


def test_committed_table_is_valid_and_covers_families():
    t = cal.load_table(field_ids=seed_ids())
    fams = {p.field for p in t.params}
    assert len(fams) >= 30, sorted(fams)
    assert all(p.source_url.startswith("http") for p in t.params)
    assert {p.region_kind for p in t.params} == {"country", "region", "world"}
    assert {f.name for f in dataclasses.fields(cal.Param)} >= {"source_statement", "event_snippets", "snippet_locator", "retrieved", "snippet_missing"}


def test_committed_table_has_transitions_and_short_term_actions():
    t = cal.load_table(field_ids=seed_ids())
    scales = {e["timescale"] for p in t.params for e in p.event_snippets}
    assert "life transition" in scales and {"minutes/hours", "day"} & scales
    assert all(p.event_snippets or p.snippet_missing for p in t.params)
