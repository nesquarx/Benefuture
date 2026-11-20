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
        "parents": [],
        "neighbours": [],
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
