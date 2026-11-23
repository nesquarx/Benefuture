import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest


def make_card(id="d.test", **over):
    card = {
        "id": id,
        "label": "Test domain",
        "aliases": [{"text": "Testing", "lang": "en"}],
        "description": "A domain used in tests.",
        "level": "coarse",
        "anchors": [{"source": "wikidata", "code": "Q1", "label": "test"}],
        "links": [],
        "axes": {"abstract_tangible": 0.5, "personal_global": -0.25},
        "radius": None,
        "arc": None,
        "status": "provisional",
        "successors": [],
        "basemap_version": "2027.0",
        "provenance": {"label": {"source": "wikidata", "confidence": 0.9}},
    }
    card.update(over)
    return card


@pytest.fixture
def card():
    return make_card


def link(id, rel="upstream", weight=1.0, **extra):
    return {"id": id, "rel": rel, "weight": weight, **extra}


def membership(domain, rel="content", weight=1.0):
    return {"domain": domain, "rel": rel, "weight": weight}


def make_row(**over):
    row = {
        "entity": "person:1",
        "relation": "causal",
        "memberships": [membership("a")],
        "basemap_version": "2027.0",
        "channel": "positive",
        "sign": 1,
        "magnitude": 1.0,
        "valid_time": "2020-05",
        "record_time": "2020-05",
        "tier": "claimed",
        "confidence": 0.4,
        "provenance": {"source": "resume.pdf", "span": "p1:l3-l5"},
        "revoked": False,
    }
    row.update(over)
    return row
