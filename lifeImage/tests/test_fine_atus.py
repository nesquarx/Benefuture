"""The American Time Use Survey lexicon as a licence-clean life-activity source: parse, licence, new-only pool, batches,
and the merge of its answers alongside the first fine set (judged by outcome: which fields gain children)."""
import importlib.util
import json
from pathlib import Path

import pytest

from lifeimage.fine.parent import build_fine_batches, write_fine_batches
from lifeimage.fine import pool as pool_mod
from lifeimage.fine import sources as src

from conftest import link, make_card
from test_fine_parent import answers_for

ROOT = Path(__file__).resolve().parent.parent

LEXICON = """\
American Time Use
  Survey Activity Lexicon
ATUS 2025 Lexicon
Major Categories        2nd-tier              3rd-tier
  01     Personal Care
                   01   Sleeping
                                   01         Sleeping
                                   02         Sleeplessness
                                   99         Sleeping, n.e.c.*
                   05   Personal Care Emergencies
                                   01         Personal Emergencies
                   99   Personal Care, n.e.c.*
                                   99         Personal care, n.e.c.*
                                                                                       2
  02     Household Activities
                   01   Housework
                                   04         Storing interior hh items, inc. food
                                   99     Housework, n.e.c.*
                   02   Food & Drink Prep., Presentation, & Clean-up
                                   01     Food and drink preparation
                                   03     Kitchen and food clean-up
  04     Caring for & Helping Nonhousehold Members
                   04   Caring for Nonhousehold Adults
                                   04     Obtaining medical and care services for nonhh adult
                                   05     Waiting associated with caring for nonhh adults
  18     Traveling
                   01   Travel Related to Personal Care
                                   01     Travel related to personal care
  50     Data Codes
                   01       Unable to Code
                                       01         Insufficient detail in verbatim
"""


def by_code(rows):
    return {r["code"]: r for r in rows}


def test_the_licence_is_recorded_as_read_on_the_primary_page():
    L = src.LICENCES["atus"]
    assert L["status"] == "verified" and "public domain" in L["licence"].lower()
    assert L["evidence"].startswith("https://www.bls.gov/")


def test_tiers_become_candidates_and_residual_waiting_travel_and_data_codes_do_not():
    rows = by_code(src.parse_atus_lexicon(LEXICON))
    assert rows["01"]["label"] == "Personal Care" and rows["01"]["depth"] == 1
    assert rows["0101"]["label"] == "Sleeping" and rows["0101"]["broader"] == "Personal Care"
    assert rows["010102"]["label"] == "Sleeplessness" and rows["010102"]["broader"] == "Sleeping"
    assert rows["020104"]["label"] == "Storing interior household items, including food"  # abbreviations spelled out
    assert rows["040404"]["label"] == "Obtaining medical and care services for non-household adult"
    for code in ("010199", "010599", "019999", "020199", "040405", "18", "1801", "180101", "50", "5001", "500101"):
        assert code not in rows, code  # n.e.c., waiting, travel (a context, not an activity) and data codes
    assert not any("n.e.c" in r["label"] or r["label"].endswith("*") or "Waiting" in r["label"] for r in rows.values())
    assert all(r["description"].startswith("ATUS 2025") for r in rows.values())


def test_page_numbers_and_headers_never_become_rows():
    rows = src.parse_atus_lexicon(LEXICON)
    assert not any(r["label"].isdigit() or "Lexicon" in r["label"] for r in rows)


def test_a_lexicon_with_no_activities_fails_loudly():
    with pytest.raises(ValueError, match="no activity"):
        src.parse_atus_lexicon("nothing here\n")


def existing(*labels):
    return [{"id": f"f.{l.lower().replace(' ', '_')}", "label": l, "aliases": [], "description": "", "kinds": ["activity"],
             "broader_in_source": [], "sources": [{"source": "esco_skills", "code": "x", "label": l, "licence_status": "unverified"}]}
            for l in labels]


def test_new_candidates_exclude_what_the_coarse_or_the_first_pool_already_hold():
    rows = src.parse_atus_lexicon(LEXICON)
    coarse = [make_card("c.sleeping", label="Sleeping", links=[], axes=None)]
    first = existing("Kitchen and food clean-up")
    cands, rep = pool_mod.new_candidates(rows, first, coarse)
    labels = {c["label"] for c in cands}
    assert "Sleeping" not in labels and "Kitchen and food clean-up" not in labels
    assert "Sleeplessness" in labels and "Food and drink preparation" in labels
    reasons = {d["label"]: d["reason"] for d in rep["dropped"]}
    assert "coarse" in reasons["Sleeping"] and "existing candidate" in reasons["Kitchen and food clean-up"]
    assert all(c["id"].startswith("f.") and c["sources"][0]["source"] == "atus" for c in cands)
    assert len({c["id"] for c in cands}) == len(cands)
    assert not {c["id"] for c in cands} & {c["id"] for c in first}
    assert rep["raw"] == len(rows) and rep["raw"] == len(cands) + len(rep["dropped"]) + rep["merged"]
    assert all(c["sources"][0]["licence_status"] == "verified" for c in cands)


def coarse_cards():
    out = [make_card("s.a", label="Sector a", links=[], axes=None)]
    out += [make_card(f"c.f{i}", label=f"Field {i}", description=f"d{i}", links=[link("s.a")], axes=None, basemap_version="2027.0")
            for i in range(5)]
    return out


def atus_cands(n):
    return [{"id": f"f.atus_{i:03d}", "label": f"Activity {i}", "aliases": [], "description": f"ATUS 2025 x {i}", "kinds": ["activity"],
             "broader_in_source": ["Housework"],
             "sources": [{"source": "atus", "code": f"{i:04d}", "label": f"Activity {i}", "licence_status": "verified"}]}
            for i in range(n)]


def base_cands():
    return [{"id": f"f.base_{i:03d}", "label": f"Base {i}", "aliases": [], "description": "", "kinds": ["discipline"],
             "broader_in_source": [], "sources": [{"source": "openalex", "code": str(i), "label": f"Base {i}", "licence_status": "unverified"}]}
            for i in range(3)]


def test_batches_for_the_new_candidates_are_tagged_two_variants_at_most_fifty(tmp_path):
    prompts = tmp_path / "p"
    prompts.mkdir()
    (prompts / "fine_parent.v1.md").write_text("# Task: fine_parent\nJudge each card on its own.\n")
    b = build_fine_batches(atus_cands(120), coarse_cards(), model="haiku-runner", prompts_dir=prompts, k=2)
    paths = write_fine_batches(b, tmp_path / "out", tag="atus")
    names = sorted(p.name for p in paths)
    assert names == [f"fine_parent.v1.atus.var{v}.part{n}.jsonl" for v in (0, 1) for n in (0, 1, 2)]
    assert all(len(p.read_text().splitlines()) - 1 <= 50 for p in paths)
    untagged = write_fine_batches(b, tmp_path / "out2")
    assert untagged[0].name == "fine_parent.v1.var0.part0.jsonl"  # existing naming unchanged


def load_tool():
    spec = importlib.util.spec_from_file_location("fine_apply", ROOT / "tools" / "fine_apply.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def make_world(tmp_path):
    prompts = tmp_path / "p"
    prompts.mkdir()
    (prompts / "fine_parent.v1.md").write_text("# Task: fine_parent\nJudge each card on its own.\n")
    cs = coarse_cards()
    (tmp_path / "coarse.jsonl").write_text("".join(json.dumps(c) + "\n" for c in cs))
    out = {}
    for name, cands, k in (("base", base_cands(), 3), ("atus", atus_cands(4), 2)):
        (tmp_path / f"{name}.jsonl").write_text("".join(json.dumps(c) + "\n" for c in cands))
        b = build_fine_batches(cands, cs, model="haiku-runner", prompts_dir=prompts, k=k)
        answers = {}
        for (v, part), lines in sorted(b.items()):
            parent = "c.f0" if name == "base" else "c.f3"
            f = tmp_path / f"{name}.var{v}.part{part}.answers.jsonl"
            f.write_text("\n".join(answers_for(lines, lambda t, p=parent: {"verdict": "upstream", "weights": {p: 1.0}})) + "\n")
            answers.setdefault(v, []).append(f)
        out[name] = answers
    return prompts, out


def run(tmp_path, prompts, base, atus):
    tool = load_tool()
    return tool.apply(candidates=tmp_path / "base.jsonl", coarse=tmp_path / "coarse.jsonl", answers=base, out=tmp_path / "fine.jsonl",
                      summary=tmp_path / "summary.json", escalation_log=None, cache=None, prompts_dir=prompts,
                      extra=[(tmp_path / "atus.jsonl", atus)])


def test_atus_answers_merge_alongside_the_first_set_and_the_childless_fields_are_reported(tmp_path):
    prompts, ans = make_world(tmp_path)
    s = run(tmp_path, prompts, ans["base"], ans["atus"])
    cards = [json.loads(l) for l in (tmp_path / "fine.jsonl").read_text().splitlines()]
    assert len(cards) == 3 + 4 and s["candidates"] == 7
    assert {c["anchors"][0]["source"] for c in cards} == {"openalex", "atus"}
    assert s["children_per_coarse"] == {"c.f0": 3, "c.f3": 4}
    assert s["fields_without_children"] == ["c.f1", "c.f2", "c.f4"]
    assert s["gained_children"]["fields"] == ["c.f3"] and s["gained_children"]["before_without_children"] == 4
    assert s["gained_children"]["after_without_children"] == 3
    assert s["sets"] == {"base": 3, "atus": 4}


def test_a_set_with_no_answers_yet_is_skipped_loudly_not_scored_as_nothing(tmp_path):
    prompts, ans = make_world(tmp_path)
    s = run(tmp_path, prompts, ans["base"], {})
    assert s["candidates"] == 3 and s["children_per_coarse"] == {"c.f0": 3}
    assert s["pending_sets"] == ["atus"] and s["sets"] == {"base": 3}


# ---------- the committed data ----------

def read(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def test_the_committed_new_candidates_restate_nothing_and_reach_the_childless_life_fields():
    from lifeimage.fine.normalise import dedupe_key
    new = read(ROOT / "data/fine/candidates_atus_v0.jsonl")
    first = read(ROOT / "data/fine/candidates_v0.jsonl")
    coarse = read(ROOT / "data/coarse/seed_v2.jsonl")
    held = {dedupe_key(l) for c in coarse for l in [c["label"], *(a["text"] for a in c["aliases"])]}
    held |= {dedupe_key(l) for c in first for l in [c["label"], *c.get("aliases", [])]}
    assert len(new) >= 250
    assert not [c["label"] for c in new if dedupe_key(c["label"]) in held]
    assert len({c["id"] for c in new}) == len(new) and not {c["id"] for c in new} & {c["id"] for c in first}
    assert all(s["source"] == "atus" and s["licence_status"] == "verified" for c in new for s in c["sources"])
    assert not [c["label"] for c in new if "n.e.c" in c["label"] or c["label"].lower().startswith(("waiting", "travel"))]
    under = {b for c in new for b in c["broader_in_source"]}
    for must in ("Housework", "Caring For & Helping HH Children", "Relaxing and Leisure", "Sleeping", "Animals and Pets"):
        assert must in under, must


def test_the_failure_of_the_download_is_recorded_not_hidden():
    net = json.loads((ROOT / "data/fine/sources/network.json").read_text())["atus"]
    assert net["status"] == "fetched" and net["url"].startswith("https://www.bls.gov/tus/lexicons/") and "403" in net["note"]
