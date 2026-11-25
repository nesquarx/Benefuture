"""The version 3 pre-registration: the signatures file is hash-pinned and matches its markdown twin; version 2 stays as it was."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
V3 = ROOT / "data/gold/characterisation_signatures_v3.json"
V2 = ROOT / "data/gold/characterisation_signatures_v2.json"
# the sha256 of the pre-registered signatures as committed before any v3 measurement
SIGS_SHA_V3 = "0933216521d0cc6bb15dfc04af69e75a39ff228f7526f70a6eb82981b9fb64ef"
SIGS_SHA_V2 = "116302bbe4746000e89c8b2900d676b466f0b14fefe194c9f299dd3a7fd5aca1"


def test_v3_signatures_json_was_not_edited_after_registration_and_lists_the_ids_of_its_markdown_twin():
    raw = V3.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == SIGS_SHA_V3
    data = json.loads(raw)
    md = (ROOT / "data/gold/characterisation_signatures_v3.md").read_text(encoding="utf-8")
    ids = [p["id"] for p in data["predictions"]]
    assert len(ids) == len(set(ids)) >= 15
    for p in data["predictions"]:
        assert f"| {p['id']} |" in md and 0 < p["confidence"] < 1
        assert p["kind"] in ("min", "max", "diff", "rank_low")
        assert ("value" in p) or ("delta" in p) or ("k" in p)


def test_v2_signatures_are_kept_unchanged():
    assert hashlib.sha256(V2.read_bytes()).hexdigest() == SIGS_SHA_V2


def test_the_registration_names_the_three_populations_and_both_labels():
    data = json.loads(V3.read_text(encoding="utf-8"))
    assert set(data["sets"]) == {"truth", "legacy", "extracted"}
    assert {p["label"] for p in data["predictions"]} == {"archetype", "calibration"}
    used = {s for p in data["predictions"] for s in (p["a"][0], *(p["b"][:1] if "b" in p else []))}
    assert used == set(data["sets"])


def test_the_committed_v3_report_evaluates_exactly_the_registered_predictions_and_renders_deterministically():
    import subprocess
    import sys
    rep = json.loads((ROOT / "data/gold/characterisation_v3_report.json").read_text(encoding="utf-8"))
    reg = json.loads(V3.read_text(encoding="utf-8"))["predictions"]
    assert [v["id"] for v in rep["verdicts"]] == [p["id"] for p in reg]
    assert all(v["confidence"] == p["confidence"] and v["text"] == p["text"] for v, p in zip(rep["verdicts"], reg))
    md = ROOT / "data/gold/characterisation_v3_report.md"
    before = md.read_bytes()
    subprocess.run([sys.executable, str(ROOT / "tools/characterise_v3.py"), "--render-only"], check=True, capture_output=True)
    assert md.read_bytes() == before
