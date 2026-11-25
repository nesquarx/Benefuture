"""The version 2 pre-registration: the signatures file is hash-pinned and matches its markdown twin, version 1's
archetype and pooled signatures are carried unchanged, and calibration is stated per domain where claims exist."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
V2 = ROOT / "data/gold/characterisation_signatures_v2.json"
V1 = ROOT / "data/gold/characterisation_signatures_v1.json"
# the sha256 of the pre-registered signatures as committed before any v2 render
SIGS_SHA_V2 = "116302bbe4746000e89c8b2900d676b466f0b14fefe194c9f299dd3a7fd5aca1"


def test_v2_signatures_json_was_not_edited_after_registration_and_lists_the_ids_of_its_markdown_twin():
    raw = V2.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == SIGS_SHA_V2
    data = json.loads(raw)
    md = (ROOT / "data/gold/characterisation_signatures_v2.md").read_text(encoding="utf-8")
    ids = [s["id"] for s in data["signatures"]] + [s["id"] for s in data["identification"]]
    assert len(ids) == len(set(ids)) >= 30
    for i in ids:
        assert f"| {i} |" in md, i
    assert all(s["confidence"] in ("low", "medium", "high") for s in data["signatures"] + data["identification"])


def test_v1_archetype_and_pooled_signatures_are_carried_unchanged_for_comparison():
    v1 = {s["id"]: s for s in json.loads(V1.read_text(encoding="utf-8"))["signatures"]}
    v2 = {s["id"]: s for s in json.loads(V2.read_text(encoding="utf-8"))["signatures"]}
    carried = [i for i in v1 if i[0] in "AG"]
    assert len(carried) == 19
    for i in carried:
        assert v2[i] == v1[i], i


def test_calibration_is_stated_per_domain_over_claimed_slices_and_the_predicted_accuracies_are_stated():
    data = json.loads(V2.read_text(encoding="utf-8"))
    k = [s for s in data["signatures"] if s["id"].startswith("K")]
    assert len(k) >= 10
    per_domain = {"claim_gap", "claim_gap_abs", "grain_green_share", "mean_claimed_level", "overclaim_share", "underclaim_share",
                  "claim_gap_low_green", "claim_gap_high_green"}
    assert all(s.get("feature", s.get("a")) in per_domain for s in k)
    ident = {(s["set"], s["label"], s["bound"]) for s in data["identification"]}
    assert ("extended / new", "archetype", "min") in ident and ("extended / new", "calibration", "min") in ident
    assert {s["set"] for s in data["identification"]} >= {"extended / new", "extended / legacy"}
