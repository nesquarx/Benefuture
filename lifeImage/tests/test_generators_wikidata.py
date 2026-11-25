"""Wikidata fetcher: statements become attested-tier rows mapped to seed domains by label; unmapped rows are kept
with a flag. No test touches the network (a fake `fetch` stands in, and recorded figures are checked on disk)."""
import json
import re
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import pytest

from lifeimage.generators.common import ROOT, padded, seed_ids, validate_row
from lifeimage.sources import wikidata


def tv(t):
    return {"type": "time", "value": {"time": t[0], "precision": t[1]}}


def claim(prop, target=None, qualifiers=None, refs=True, time=None):
    snak = {"snaktype": "value", "property": prop}
    if target:
        snak["datavalue"] = {"type": "wikibase-entityid", "value": {"id": target}}
    else:
        snak["datavalue"] = tv(time)
    c = {"mainsnak": snak, "qualifiers": {}, "rank": "normal", "id": f"{prop}-{target or time[0]}"}
    for qp, t in (qualifiers or {}).items():
        c["qualifiers"][qp] = [{"snaktype": "value", "property": qp, "datavalue": tv(t)}]
    if refs:
        c["references"] = [{"snaks": {"P248": [{}]}}]
    return c


def ent(qid, label, claims=None, desc=""):
    return {"id": qid, "labels": {"en": {"language": "en", "value": label}}, "descriptions": {"en": {"language": "en", "value": desc}},
            "claims": claims or {}}


def T(y, m=None, d=None):
    """(Wikidata time string, precision): 9 year, 10 month, 11 day."""
    return f"+{y}-{m or '01'}-{d or '01'}T00:00:00Z", 9 if m is None else 10 if d is None else 11
WORLD = {e["id"]: e for e in [
    ent("Q100", "Test Physicist", {
        "P31": [claim("P31", "Q5")], "P569": [claim("P569", time=T(1900))], "P570": [claim("P570", time=T(1970))],
        "P106": [claim("P106", "Q200"), claim("P106", "Q206", refs=False)],
        "P69": [claim("P69", "Q201", {"P580": T(1918), "P582": T(1922)})],
        "P39": [claim("P39", "Q202", {"P580": T(1946, "03"), "P582": T(1950)})],
        "P166": [claim("P166", "Q203", {"P585": T(1930, "12", "10")})],
        "P800": [claim("P800", "Q204")]}, "physicist and minister"),
    ent("Q200", "physicist"), ent("Q206", "xylotomist"), ent("Q201", "University of Testing"),
    ent("Q202", "Minister of Education"), ent("Q203", "Nobel Prize in Physics"),
    ent("Q204", "On Testing", {"P31": [claim("P31", "Q205")], "P577": [claim("P577", time=T(1925, "06"))]}),
    ent("Q205", "scholarly article"), ent("Q5", "human"),
    ent("Q300", "Living Person", {"P31": [claim("P31", "Q5")], "P569": [claim("P569", time=T(1980))]}),
]}


def fake_fetch(url):
    q = parse_qs(urlparse(url).query)
    if q.get("action") == ["wbsearchentities"]:
        return {"search": [{"id": "Q100", "label": "Test Physicist"}]}
    ids = q["ids"][0].split("|")
    return {"entities": {i: WORLD[i] for i in ids if i in WORLD}, "success": 1}


DOMAINS = sorted(seed_ids())


def test_figure_statements_carry_dates_labels_and_references():
    f = wikidata.build_figure("Q100", fake_fetch)
    assert f["label"] == "Test Physicist" and f["birth"] == "1900" and f["death"] == "1970"
    by = {(s["property"], s["label"]): s for s in f["statements"]}
    assert by[("P69", "University of Testing")]["start"] == "1918" and by[("P69", "University of Testing")]["end"] == "1922"
    assert by[("P39", "Minister of Education")]["start"] == "1946-03"
    assert by[("P166", "Nobel Prize in Physics")]["point"] == "1930-12-10"
    assert by[("P800", "On Testing")]["point"] == "1925-06" and by[("P800", "On Testing")]["instance_of"] == ["scholarly article"]
    assert by[("P106", "physicist")]["referenced"] is True and by[("P106", "xylotomist")]["referenced"] is False


def test_rows_are_attested_valid_and_dated_and_unmapped_are_flagged():
    f = wikidata.build_figure("Q100", fake_fetch)
    rows, trace = wikidata.to_rows(f, DOMAINS)
    assert len(rows) == len(trace) >= 6
    for r, t in zip(rows, trace):
        validate_row(r)
        assert r["tier"] == "attested" and r["entity"] == "wikidata:Q100" and r["entity_kind"] == "person"
        assert r["confidence"] < 1 and r["provenance"]["source"].startswith("wikidata:Q100")
        assert padded(r["valid_time"]) <= padded(r["record_time"])
        assert {m["domain"] for m in r["memberships"]} <= set(DOMAINS)
        assert t["mapped"] in (True, False) and t["label"] and t["property"]
    tr = {t["label"]: (r, t) for r, t in zip(rows, trace)}
    assert tr["physicist"][1]["mapped"] and any(m["domain"] == "c.physics" for m in tr["physicist"][0]["memberships"])
    r, t = tr["xylotomist"]
    assert t["mapped"] is False and t["fallback"] and r["memberships"][0]["domain"] == "s.work"
    assert tr["Nobel Prize in Physics"][0]["valid_time"] == "1930-12-10"
    assert tr["Minister of Education"][0]["valid_time"] == "1946-03"
    assert tr["University of Testing"][0]["valid_time"] == "1918"
    assert tr["On Testing"][0]["valid_time"] == "1925-06"
    # undated occupation: dated from the earliest dated statement, flagged, with lowered confidence
    assert tr["physicist"][1]["date"] == "inferred" and tr["physicist"][0]["valid_time"] == "1918"
    assert tr["Nobel Prize in Physics"][1]["date"] == "stated"
    assert tr["physicist"][0]["confidence"] > tr["xylotomist"][0]["confidence"]


def test_a_label_held_only_as_multilingual_is_read():
    WORLD["Q101"] = ent("Q101", "x", {"P31": [claim("P31", "Q5")], "P570": [claim("P570", time=T(1950))], "P106": [claim("P106", "Q200")]})
    WORLD["Q101"]["labels"] = {"mul": {"language": "mul", "value": "Same Everywhere"}}
    try:
        f = wikidata.build_figure("Q101", fake_fetch)
    finally:
        del WORLD["Q101"]
    assert f["label"] == "Same Everywhere"


def test_a_living_unlisted_person_is_refused():
    with pytest.raises(ValueError):
        wikidata.build_figure("Q300", fake_fetch, require_public=True)


def test_map_domain_by_label_and_unmapped_falls_back_to_the_property_domain():
    ds, ok = wikidata.map_domain("P106", "composer", [], DOMAINS)
    assert ok and ds[0][0] == "c.music_making" and abs(sum(w for _, w in ds) - 1) < 1e-9
    ds, ok = wikidata.map_domain("P800", "Starry Night", ["painting"], DOMAINS)
    assert ok and ds[0][0] == "c.visual_arts"
    ds, ok = wikidata.map_domain("P39", "President of Testland", [], DOMAINS)
    assert ok and ds[0][0].startswith("c.") and "public" in ds[0][0] or ds[0][0] in ("c.public_administration", "c.political_participation")
    ds, ok = wikidata.map_domain("P106", "xylotomist", [], DOMAINS)
    assert not ok and ds == [("s.work", 1.0)]
    ds, ok = wikidata.map_domain("P69", "Some Obscure Establishment", [], DOMAINS)
    assert not ok and ds == [("s.learning", 1.0)]


def test_recorded_fixtures_replay_without_the_network(tmp_path):
    calls = []

    def live(url):
        calls.append(url)
        return fake_fetch(url)

    rec = wikidata.RecordingFetcher(live, tmp_path)
    a = wikidata.build_figure("Q100", rec)
    n = len(calls)
    assert n >= 2 and list(tmp_path.glob("*.json"))
    replay = wikidata.FixtureFetcher(tmp_path)
    assert wikidata.build_figure("Q100", replay) == a
    with pytest.raises(KeyError):
        replay("https://www.wikidata.org/w/api.php?action=wbgetentities&ids=Q999&format=json")


def test_recorded_fixtures_are_trimmed_and_small():
    fx = ROOT / "data/public/fixtures"
    files = list(fx.glob("*.json"))
    assert files, "recorded fixtures are shipped"
    assert sum(f.stat().st_size for f in files) < 6_000_000


# ---- the fetched public figures ----
PUBLIC = ROOT / "data/public"


def test_about_ten_public_figures_of_different_shapes_are_kept():
    figs = sorted(PUBLIC.glob("*.rows.jsonl"))
    assert 8 <= len(figs) <= 14
    shapes = set()
    for f in figs:
        rows = [json.loads(l) for l in f.read_text().splitlines()]
        trace = [json.loads(l) for l in f.with_name(f.name.replace(".rows.", ".trace.")).read_text().splitlines()]
        assert len(rows) == len(trace) >= 3  # a thin record is a shape too
        for r in rows:
            validate_row(r)
            assert r["tier"] == "attested"
        shapes.add(frozenset(t["property"] for t in trace))
        meta = json.loads(f.with_name(f.name.replace(".rows.jsonl", ".json")).read_text())
        assert meta["death"] or meta["public_reason"], "deceased or a stated reason"
    assert len(shapes) >= 5, "figures have different shapes (property mixes)"
    assert (PUBLIC / "README.md").exists()
