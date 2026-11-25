"""Parsers and crawlers for the public classifications (no network: injected fetchers, recorded text)."""
import json

from lifeimage.fine.sources import LICENCES, crawl_esco, parse_icatus, parse_openalex_subfields

ICATUS = """\
C. Complete classification

Major
division Division     Group   Activity
1                             Employment and related activities
            11                Employment in corporations, government and non-profit institutions
                       110    Employment in corporations, government and non-profit institutions
            13                Employment in households and household enterprises to provide services
                       131    Vending and trading of goods in household enterprises
                       132    Providing paid repair, installation, maintenance and disposal services
                              in households and household enterprises
20   International Classification of Activities for Time-Use Statistics 2016

      Major
      division Division    Group    Activity
                       139    Other activities related to employment in households
                              and household enterprises providing services
            15                Training and studies in relation to employment
                       150    Training and studies in relation to employment
D. Explanatory notes
      1              Employment and related activities
            999   Must not be read: after the classification
"""


def test_icatus_groups_with_wrapped_labels_and_no_page_furniture():
    rows = parse_icatus(ICATUS)
    by = {r["code"]: r for r in rows}
    assert by["132"]["label"] == ("Providing paid repair, installation, maintenance and disposal services "
                                  "in households and household enterprises")
    assert by["139"]["label"].endswith("providing services")
    assert not any("International Classification" in r["label"] for r in rows)
    assert "999" not in by  # nothing after the classification section
    assert by["131"]["broader"] == "Employment in households and household enterprises to provide services"
    assert "1" not in by  # major divisions are coarse, not candidates


def test_icatus_footnotes_never_reach_a_label():
    text = """C. Complete classification
            83              Sports participation and exercise, and related activities
                     831    Participating in sports
                     832    Exercising
                                                                                                            36
            84              Mass media use36                                                                     The collection of the contex-
                                                                                                                 tual variable "Using an ICT
                     841    Reading for leisure
D. Explanatory notes
"""
    by = {r["code"]: r["label"] for r in parse_icatus(text)}
    assert by["832"] == "Exercising"
    assert by["84"] == "Mass media use"
    assert by["841"] == "Reading for leisure"


def test_icatus_licence_is_recorded_as_restricted():
    assert LICENCES["icatus"]["status"] == "restricted"
    assert LICENCES["wikidata"]["status"] == "verified" and "CC0" in LICENCES["wikidata"]["licence"]
    for name, lic in LICENCES.items():
        assert lic["status"] in {"verified", "unverified", "restricted"}, name


def test_openalex_subfields_keep_label_description_aliases_and_field():
    raw = [{"id": "https://openalex.org/subfields/3106", "display_name": "Nuclear and High Energy Physics",
            "description": "physics of elementary particles", "display_name_alternatives": ["HEP"],
            "field": {"id": "https://openalex.org/fields/31", "display_name": "Physics and Astronomy"},
            "domain": {"display_name": "Physical Sciences"}, "topics": [{"display_name": "x"}] * 50}]
    (r,) = parse_openalex_subfields(raw)
    assert r == {"code": "3106", "label": "Nuclear and High Energy Physics", "aliases": ["HEP"],
                 "description": "physics of elementary particles", "broader": "Physics and Astronomy"}


def test_esco_crawl_follows_narrower_links_to_the_depth_and_no_further():
    tree = {"r": ["a", "b"], "a": ["a1"], "b": [], "a1": ["a11"], "a11": []}

    def fetch(url):
        uri = url.split("uri=")[1].split("&")[0]
        return {"uri": uri, "title": f"T {uri}", "code": uri.upper(), "preferredLabel": {"en": f"T {uri}"},
                "alternativeLabel": {"en": ["alt"]}, "description": {"en": {"literal": "d"}},
                "_links": {"narrowerConcept": [{"uri": n} for n in tree[uri]],
                           "broaderConcept": [{"uri": "p"}]}}

    rows = crawl_esco(fetch, "concept", "r", max_depth=2)
    assert [(r["code"], r["depth"]) for r in rows] == [("R", 0), ("A", 1), ("A1", 2), ("B", 1)]
    assert "A11" not in {r["code"] for r in rows}
    assert crawl_esco(fetch, "concept", "r", max_depth=0)[0]["code"] == "R"
    json.dumps(rows)
