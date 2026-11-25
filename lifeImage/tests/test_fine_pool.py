"""The candidate pool: every source accounted for, nothing silently lost, no duplicate of a coarse domain."""
import json
from collections import Counter
from pathlib import Path

import pytest

from lifeimage.fine.normalise import dedupe_key
from lifeimage.fine.pool import candidates_from_answers, candidates_from_wikidata, load_pool

ROOT = Path(__file__).resolve().parent.parent
FINE = ROOT / "data" / "fine"


def read(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def unmapped_labels():
    rows = [r for p in sorted((ROOT / "data/public").glob("*.trace.jsonl")) for r in read(p)]
    return [r for r in rows if not r["mapped"]]


def test_every_unmapped_wikidata_label_is_a_candidate_or_a_logged_drop():
    un = unmapped_labels()
    assert len(un) == 161
    cands, dropped = candidates_from_wikidata(ROOT / "data/public")
    accounted = sum(c["evidence_count"] for c in cands) + len(dropped)
    assert accounted == len(un), (accounted, len(un))
    assert all(d["reason"] for d in dropped)
    assert all(d["source"] == "wikidata" and d["label"] for d in dropped)


def test_named_instances_are_dropped_not_made_into_domains():
    cands, dropped = candidates_from_wikidata(ROOT / "data/public")
    labels = {dedupe_key(c["label"]) for c in cands}
    # An award or work with only a generic class is an instance (evidence), never a fine domain.
    assert dedupe_key("award") not in labels
    assert all("Nobel" not in c["label"] for c in cands)
    assert any(d["reason"] == "instance with no domain-level class" for d in dropped)
    # a class of award or work is kept, with the instance labels as examples
    lit = [c for c in cands if dedupe_key(c["label"]) == dedupe_key("literary award")]
    assert lit and lit[0]["examples"] and lit[0]["evidence_count"] >= 11


def test_occupations_keep_their_own_label():
    cands, _ = candidates_from_wikidata(ROOT / "data/public")
    assert "harpsichordist" in {c["label"] for c in cands}
    assert {c["label"]: c["evidence_count"] for c in cands}["autobiographer"] == 2


def test_answers_source_reads_only_a_stated_missing_domain():
    cands = candidates_from_answers(ROOT / "data/answers")
    assert all(c["sources"][0]["source"] == "answers" for c in cands)
    assert "podcast listening as media consumption" in {c["label"] for c in cands}
    # relation-vocabulary complaints and scenario notes are not domains
    assert not any("vocabulary" in c["label"] or "omission" in c["label"] for c in cands)


@pytest.fixture(scope="module")
def pool():
    return load_pool(FINE / "candidates_v0.jsonl")


def test_pool_size_is_a_few_hundred(pool):
    assert 300 <= len(pool) <= 800, len(pool)


def test_pool_has_no_duplicates_after_normalisation(pool):
    keys = Counter(dedupe_key(c["label"]) for c in pool)
    assert [k for k, n in keys.items() if n > 1] == []
    ids = Counter(c["id"] for c in pool)
    assert [k for k, n in ids.items() if n > 1] == []


def test_no_candidate_restates_a_coarse_domain(pool):
    coarse = read(ROOT / "data/coarse/seed_v2.jsonl")
    ckeys = {dedupe_key(c["label"]) for c in coarse} | {dedupe_key(a["text"]) for c in coarse for a in c["aliases"]}
    assert [c["label"] for c in pool if dedupe_key(c["label"]) in ckeys] == []


def test_every_candidate_names_source_and_licence_status(pool):
    for c in pool:
        assert c["sources"], c["id"]
        for s in c["sources"]:
            assert s["source"] and s["code"] is not None and s["licence_status"] in {"verified", "unverified", "restricted"}
        assert c["id"].startswith("f.")
        assert c["kinds"] and c["label"].strip()


def test_pool_covers_each_available_source(pool):
    seen = {s["source"] for c in pool for s in c["sources"]}
    assert {"wikidata", "answers"} <= seen
    assert len(seen) >= 4  # at least two public classifications besides a and b


def test_pool_report_accounts_for_every_raw_item():
    rep = json.loads((FINE / "pool_report.json").read_text())
    raw = sum(v["raw"] for v in rep["by_source"].values())
    pool = len(read(FINE / "candidates_v0.jsonl"))
    assert raw == pool + rep["merged"] + len(rep["dropped"])
    assert rep["network"]["blocked"] is not None
