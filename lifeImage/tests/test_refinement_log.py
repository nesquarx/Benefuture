"""LI.68: plausible domains are logged as refinement candidates (unjudged, near the floor, disputed); they never enter memberships."""
import json
from pathlib import Path

import pytest

import lifeimage.membership_wide as mw
from lifeimage.governed import membership_fit_floor

ROOT = Path(__file__).resolve().parent.parent
RELS = mw.RELS
REPORTS = {3: ROOT / "data/gold/membership_wide_calibration_report.json", 4: ROOT / "data/gold/membership_wide_calibration_report_v4.json"}
LOG = ROOT / "data/refinement/candidates_v1.jsonl"


@pytest.fixture(autouse=True)
def refinement_dir(tmp_path, monkeypatch):
    """Judge and ingest write their refinement log under this directory (never the real one)."""
    d = tmp_path / "refinement"
    monkeypatch.setattr(mw, "REFINEMENT_DIR", d, raising=False)
    return d


def _ans(lists, rejected=("c.zzz", 2), version=3):
    types, ranks = {}, {}
    for rel in RELS:
        ds = lists.get(rel)
        if ds is None:
            types[rel], ranks[rel] = None, None
            continue
        n = len(ds)
        w = [n - i for i in range(n)]
        t = sum(w)
        types[rel] = {d: x / t for d, x in zip(ds, w)}
        ranks[rel] = {"listed": [{"domain": d, "fit": 9 - i} for i, d in enumerate(ds)], "rejected": {"domain": rejected[0], "fit": rejected[1]}}
    return {"types": types, "ranks": ranks, "prompt_version": version, "model": "m"}


def _controls():
    return [{"id": "cal.s", "group": "single", "text": "t", "fair": {"form": ["c.a"]}, "bad": {"form": ["c.x"]}}]


def _by(form0, form1, rej=("c.near", 3), version=3):
    return {"cal.s": {0: ("t", _ans({"form": form0}, rej, version)), 1: ("t", _ans({"form": form1}, rej, version))}}


def _read(d):
    p = Path(d) / "candidates_v1.jsonl"
    return [json.loads(l) for l in p.read_text().splitlines()] if p.exists() else []


def test_baseline_the_current_judge_and_ingest_log_nothing(refinement_dir):
    # unjudged c.q, disputed c.q, near-floor c.near (fit 3, floor 4) are all present; the outcome wanted is a log, the current code writes none
    mw.calibration_report(_controls(), _by(["c.a", "c.q"], ["c.a"]))
    assert hasattr(mw, "log_calibration")  # the judge's entry point that logs
    mw.log_calibration(_controls(), _by(["c.a", "c.q"], ["c.a"]), 3)
    assert (refinement_dir / "candidates_v1.jsonl").exists() and (refinement_dir / "summary_v1.json").exists()


def test_sources_unjudged_near_floor_disputed(refinement_dir):
    mw.log_calibration(_controls(), _by(["c.a", "c.q"], ["c.a"]), 3)
    got = {(r["source"], r["domain"], r["variant"]) for r in _read(refinement_dir)}
    assert ("unjudged", "c.q", 0) in got and ("disputed", "c.q", 0) in got
    assert ("near_floor", "c.near", 0) in got and ("near_floor", "c.near", 1) in got
    assert not any(d in ("c.a", "c.x") for _, d, _ in got)  # gold-judged domains are not candidates


def test_near_floor_uses_the_versions_floor(refinement_dir):
    assert (membership_fit_floor(3), membership_fit_floor(4)) == (4, 5)
    mw.log_calibration(_controls(), _by(["c.a"], ["c.a"], ("c.n3", 3)), 3)
    mw.log_calibration(_controls(), _by(["c.a"], ["c.a"], ("c.n4", 4), 4), 4)
    rows = _read(refinement_dir)
    assert {(r["domain"], r["prompt_version"]) for r in rows if r["source"] == "near_floor"} == {("c.n3", 3), ("c.n4", 4)}
    mw.log_calibration(_controls(), _by(["c.a"], ["c.a"], ("c.old", 3), 4), 4)  # fit 3 is two below the v4 floor: not near
    assert "c.old" not in {r["domain"] for r in _read(refinement_dir)}


def test_the_log_is_append_safe_deduplicated_and_ordered(refinement_dir):
    for _ in range(2):
        mw.log_calibration(_controls(), _by(["c.a", "c.q"], ["c.a"]), 3)
    rows = _read(refinement_dir)
    keys = [(r["item"], r["relation"], r["domain"], r["source"], r["prompt_version"], r["variant"]) for r in rows]
    assert len(keys) == len(set(keys)) and keys == sorted(keys)
    assert {"item", "item_hash", "relation", "domain", "fit", "prompt_version", "variant", "source", "listed"} <= set(rows[0])


def test_the_summary_counts_domains_sources_and_pairs(refinement_dir):
    mw.log_calibration(_controls(), _by(["c.a", "c.q"], ["c.a"]), 3)
    s = json.loads((refinement_dir / "summary_v1.json").read_text())
    assert s["domains"]["c.q"]["by_source"] == {"disputed": 1, "unjudged": 1} and s["domains"]["c.q"]["appearances"] == 2
    assert {"candidate": "c.q", "listed": "c.a", "count": 1} in s["pairs"]
    assert {"candidate": "c.near", "listed": "c.a", "count": 2} in s["pairs"]


def _write_pairs(tmp_path, lists_by_variant, rej=("c.zzz", 2)):
    items = [{"id": "kind.cooking", "text": "A person cooked a meal."}]
    pairs = []
    for v in (0, 1):
        batch = mw.build_wide_batches(items, mw.DEFAULT_PACK.read_text(encoding="utf-8"))[(v, 0)]
        bp, ap = tmp_path / f"b{v}.jsonl", tmp_path / f"a{v}.jsonl"
        bp.write_text("\n".join(batch) + "\n")
        t = json.loads(batch[1])
        a = _ans(lists_by_variant[v], rej)
        ap.write_text(json.dumps({"task_id": t["task_id"], "task_type": t["task_type"], "input_hash": t["input_hash"], "variant": v,
                                  "model": json.loads(batch[0])["model"], "prompt_version": 3, "verdict": "membership", "reason": "r",
                                  "types": a["types"], "ranks": a["ranks"], "other": None}) + "\n")
        pairs.append((bp, ap))
    return pairs


def test_ingest_logs_disputed_and_near_floor_and_candidates_never_enter_memberships(tmp_path, refinement_dir):
    pairs = _write_pairs(tmp_path, {0: {"form": ["c.cooking", "c.nutrition_diet"]}, 1: {"form": ["c.cooking"]}}, ("c.food_purchasing", 3))
    rows = mw.ingest(pairs, tmp_path / "t.jsonl", tmp_path / "e.jsonl")
    cand = _read(refinement_dir)
    assert {(r["source"], r["domain"]) for r in cand} == {("disputed", "c.nutrition_diet"), ("near_floor", "c.food_purchasing")}
    assert {r["item"] for r in cand} == {"kind.cooking"}
    members = set(rows[0]["memberships"]["form"])
    assert members == {"c.cooking"} and not members & {r["domain"] for r in cand}
    # run again: the log does not grow
    mw.ingest(pairs, tmp_path / "t.jsonl", tmp_path / "e.jsonl")
    assert len(_read(refinement_dir)) == len(cand)


@pytest.mark.parametrize("version", [3, 4])
def test_every_unjudged_secondary_of_the_calibration_report_is_in_the_committed_log(version):
    rep = json.loads(REPORTS[version].read_text())
    logged = {(r["item"], r["variant"], r["relation"], r["domain"]) for r in map(json.loads, LOG.read_text().splitlines())
              if r["source"] == "unjudged" and r["prompt_version"] == version}
    wanted = {tuple(x) for x in rep["unjudged_secondary"]}
    assert len(wanted) == (59 if version == 3 else 55)
    assert wanted == logged


def test_the_committed_log_has_near_floor_rows_at_the_versions_floor_and_a_summary():
    rows = [json.loads(l) for l in LOG.read_text().splitlines()]
    for v in (3, 4):
        nf = [r for r in rows if r["source"] == "near_floor" and r["prompt_version"] == v]
        assert nf and {r["fit"] for r in nf} == {membership_fit_floor(v) - 1}
    s = json.loads((ROOT / "data/refinement/summary_v1.json").read_text())
    assert s["records"] == len(rows)
