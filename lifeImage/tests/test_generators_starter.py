"""The starter set on disk: 40 personas over eight archetypes and ages 8-85, six organisations, texts with their
ground truth, a summary. Red first: before generation the directory is missing and every test fails."""
import gzip
import importlib.util
import json
import re
import subprocess
from collections import Counter

import pytest

from lifeimage.generators.common import ROOT, seed_ids, validate_row

SYN = ROOT / "data" / "synthetic"


def jl(name):
    f = SYN / name
    raw = gzip.open(f, "rt", encoding="utf-8").read() if name.endswith(".gz") else f.read_text(encoding="utf-8")
    return [json.loads(l) for l in raw.splitlines() if l.strip()]


def test_forty_personas_over_archetypes_and_ages_and_six_organisations():
    ps, os_ = jl("personas.jsonl"), jl("orgs.jsonl")
    assert len(ps) == 40 and len(os_) == 6
    assert Counter(p["archetype"] for p in ps) == {a: 5 for a in ("student", "shift_worker", "carer", "small_business_owner", "researcher", "retiree", "career_changer", "generalist")}
    ages = [p["age"] for p in ps]
    assert min(ages) == 8 and max(ages) == 85 and sum(a < 18 for a in ages) >= 3 and sum(a >= 70 for a in ages) >= 6
    assert {p["calibration"] for p in ps} == {"over", "under", "well"}
    assert {o["org_kind"] for o in os_} == {"cafe", "charity", "software_firm", "farm", "clinic", "sports_club"}
    assert all(p["synthetic"] for p in ps + os_)


def test_every_stored_row_meets_the_contract_and_belongs_to_a_listed_entity():
    ids = seed_ids()
    ents = {p["entity"] for p in jl("personas.jsonl")} | {o["entity"] for o in jl("orgs.jsonl")}
    n = 0
    for name in ("rows.jsonl", "org_rows.jsonl"):
        for r in jl(name):
            validate_row(r)
            assert r["entity"] in ents and r["confidence"] < 1 and {m["domain"] for m in r["memberships"]} <= ids
            n += 1
    assert n > 4000


def test_texts_and_truth_resolve_line_by_line():
    ps = jl("personas.jsonl")
    rows = jl("rows.jsonl")
    ents = jl("events.jsonl.gz")
    by_ent = {}
    for r in rows:
        by_ent.setdefault(r["entity"], []).append(r)
    ev_by = {}
    for e in ents:
        ev_by.setdefault(e["entity"], []).append(e)
    for p in ps:
        texts = {k: (SYN / "texts" / f"{p['id']}.{k}.txt").read_text(encoding="utf-8").splitlines() for k in ("resume", "self", "diary")}
        truth = [json.loads(l) for l in (SYN / "truth" / f"{p['id']}.jsonl").read_text(encoding="utf-8").splitlines()]
        mine = by_ent[p["entity"]]
        assert truth == [r for r in mine if r["tier"] == "claimed"]
        owned = {i: e for e in ev_by.get(p["entity"], []) for i in e["rows"]}
        for i, r in enumerate(mine):
            if r["tier"] != "claimed":
                continue
            kind, _ = r["provenance"]["source"].split(":")
            line = texts[kind][int(r["provenance"]["span"][1:]) - 1]
            if i in owned:
                assert owned[i]["phrase"] in line


def test_organisation_prospectuses_resolve():
    orgs = {o["entity"]: o for o in jl("orgs.jsonl")}
    ev = jl("org_events.jsonl.gz")
    rows = jl("org_rows.jsonl")
    for ent, o in orgs.items():
        text = (SYN / "texts" / f"{o['id']}.prospectus.txt").read_text(encoding="utf-8").splitlines()
        mine = [r for r in rows if r["entity"] == ent]
        owned = {i: e for e in ev if e["entity"] == ent for i in e["rows"]}
        assert any(r["tier"] == "claimed" for r in mine)
        for i, r in enumerate(mine):
            if r["tier"] == "claimed":
                assert owned[i]["phrase"] in text[int(r["provenance"]["span"][1:]) - 1]


def test_contact_details_are_fictional_only():
    text = "".join(f.read_text(encoding="utf-8") for f in (SYN / "texts").glob("*.txt"))
    emails = set(re.findall(r"[\w.+'-]+@[\w.-]+", text))
    assert emails and all(e.endswith(".example.org") or e.endswith("@example.org") for e in emails)
    phones = set(re.findall(r"\(\d{3}\) \d{3}-\d{4}", text))
    assert phones and all(p[6:12] == "555-01" for p in phones)


def test_summary_table_lists_every_entity_with_the_requested_columns():
    s = (SYN / "SUMMARY.md").read_text(encoding="utf-8")
    for col in ("positive", "prediction", "negative", "claimed", "attested", "measured", "domains", "calibration"):
        assert col in s
    assert len(re.findall(r"^\| p\d{3} \|", s, re.M)) == 40 and len(re.findall(r"^\| o\d{3} \|", s, re.M)) == 6


def test_the_set_is_reproducible_byte_for_byte():
    spec = importlib.util.spec_from_file_location("gen_starter", ROOT / "tools" / "gen_starter.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    files = mod.build()
    for k, v in files.items():
        want = v if isinstance(v, bytes) else v.encode("utf-8")
        assert (SYN / k).read_bytes() == want, k


def test_raw_inputs_folder_is_ignored_by_git():
    r = subprocess.run(["git", "check-ignore", "-q", "lifeImage/data/ephemeral/anything.txt"], cwd=ROOT.parent, capture_output=True)
    assert r.returncode == 0
