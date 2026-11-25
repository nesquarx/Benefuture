"""LI.19: ICATUS is internal calibration only; no shipped file carries an ICATUS anchor or source."""
import json
from pathlib import Path

import pytest

from lifeimage.fine.calibration import (CALIBRATION_ICATUS, icatus_anchors, split_icatus_anchors)

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"


def _gitignored():
    lines = [l.strip() for l in (ROOT / ".gitignore").read_text().splitlines() if l.strip() and not l.startswith(("#", "!"))]
    return lines


def _shipped_json(path):
    rel = path.relative_to(ROOT).as_posix()
    return not any(rel == g or rel.startswith(g.rstrip("/") + "/") for g in _gitignored() if "*" not in g)


def _icatus_in(obj):
    """True when an anchor or source entry of a card names icatus."""
    if isinstance(obj, dict):
        if str(obj.get("source", "")).lower() == "icatus":
            return True
        return any(_icatus_in(v) for v in obj.values())
    if isinstance(obj, list):
        return any(_icatus_in(v) for v in obj)
    return False


def test_no_shipped_card_file_carries_an_icatus_anchor_or_source():
    bad = []
    for p in sorted(DATA.rglob("*.jsonl")):
        if p.relative_to(ROOT).parts[:2] in {("data", "answers"), ("data", "batches")} or not _shipped_json(p):
            continue
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if line.strip() and _icatus_in(json.loads(line)):
                bad.append(f"{p.relative_to(ROOT)}:{n}")
    assert not bad, f"ICATUS content in shipped files: {bad[:5]} ... ({len(bad)})"


def test_calibration_file_is_gitignored():
    assert "data/calibration/" in _gitignored()


def test_split_moves_icatus_anchors_and_keeps_the_others(tmp_path):
    f = tmp_path / "seed.jsonl"
    rows = [{"id": "c.a", "anchors": [{"source": "icatus", "code": "09", "label": "Self-care"},
                                       {"source": "isco08", "code": "5", "label": "Services"}]},
            {"id": "c.b", "anchors": [{"source": "openalex", "code": "1", "label": "x"}]}]
    f.write_text("".join(json.dumps(r) + "\n" for r in rows))
    out = tmp_path / "cal.jsonl"
    moved = split_icatus_anchors([f], out)
    assert moved == 1
    kept = [json.loads(l) for l in f.read_text().splitlines()]
    assert [a["source"] for a in kept[0]["anchors"]] == ["isco08"] and kept[1] == rows[1]
    cal = [json.loads(l) for l in out.read_text().splitlines()]
    assert cal == [{"id": "c.a", "anchors": [{"source": "icatus", "code": "09", "label": "Self-care"}]}]
    assert split_icatus_anchors([f], out) == 0  # idempotent: a second pass moves nothing and keeps the file
    assert [json.loads(l) for l in out.read_text().splitlines()] == cal


def test_absent_calibration_file_degrades_loudly(tmp_path):
    log = []
    with pytest.warns(RuntimeWarning, match="icatus"):
        got = icatus_anchors(tmp_path / "missing.jsonl", log=log)
    assert got == {} and log and log[0]["mechanism"] == "icatus calibration anchors"


def test_present_calibration_file_is_read(tmp_path):
    p = tmp_path / "cal.jsonl"
    p.write_text(json.dumps({"id": "c.a", "anchors": [{"source": "icatus", "code": "09", "label": "x"}]}) + "\n")
    assert icatus_anchors(p, log=[])["c.a"][0]["code"] == "09"
