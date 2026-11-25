"""Fine candidates for coarse fields with no fine child: licence-clean classification trees (Wikidata, Getty AAT, Disease
Ontology, MONDO, O*NET and the LI.56 sources), capped per field, deduplicated against what exists. No network: recorded
responses."""
import json
from pathlib import Path

import pytest

from lifeimage.fine import gap, pool as pool_mod, sources as src

from conftest import make_card

ROOT = Path(__file__).resolve().parent.parent


def b(qid, label, n, desc=""):
    out = {"c": {"value": f"http://www.wikidata.org/entity/{qid}"}, "l": {"value": label}, "n": {"value": str(n)}}
    if desc:
        out["d"] = {"value": desc}
    return out


def test_wikidata_rows_keep_class_labels_in_english_and_drop_names_and_obscure_classes():
    bindings = [b("Q1", "theft", 120, "taking"), b("Q2", "Theft Act 1968", 40), b("Q3", "shoplifting", 60),
                b("Q4", "rare form of theft", 2), b("Q5", "Q12345", 50), b("Q6", "pickpocketing", 3)]
    rows, dropped = gap.wikidata_rows(bindings, field="theft_property_crime", root_label="property crime",
                                      depth_of={"Q1": 0, "Q2": 1, "Q3": 1, "Q4": 2, "Q5": 1, "Q6": 2}, min_sitelinks=8)
    assert [r["label"] for r in rows] == ["theft", "shoplifting"]
    assert rows[0]["code"] == "Q1" and rows[0]["target"] == "theft_property_crime" and rows[0]["broader"] == "property crime"
    assert {d["reason"] for d in dropped} == {"proper name (capital letter inside)", "fewer sitelinks than 8", "no English label"}


def test_cap_per_field_keeps_the_best_known_and_never_exceeds_the_cap():
    rows = [{"code": f"Q{i}", "label": f"class {i:02d}", "target": "f", "sitelinks": 100 - i, "depth": 1, "broader": "r"} for i in range(20)]
    rows += [{"code": "Q99", "label": "other", "target": "g", "sitelinks": 9, "depth": 1, "broader": "r"}]
    got = gap.cap_per_field(rows, cap=8)
    f = [r for r in got if r["target"] == "f"]
    assert len(f) == 8 and [r["code"] for r in f] == [f"Q{i}" for i in range(8)]
    assert [r["code"] for r in got if r["target"] == "g"] == ["Q99"]  # a small field is not padded


OBO = """\
format-version: 1.2

[Term]
id: DOID:4
name: disease

[Term]
id: DOID:162
name: cancer
is_a: DOID:4 ! disease

[Term]
id: DOID:1612
name: breast cancer
is_a: DOID:162 ! cancer
def: "A thoracic cancer." [url:x]
synonym: "breast carcinoma" EXACT []

[Term]
id: DOID:9
name: obsolete thing
is_obsolete: true
is_a: DOID:4 ! disease

[Term]
id: DOID:77
name: mood disorder
is_a: DOID:4 ! disease
"""


def test_obo_terms_parse_and_a_subtree_gives_depth_ordered_groups_by_size():
    terms = gap.parse_obo(OBO)
    assert "DOID:9" not in terms and terms["DOID:1612"]["parents"] == ["DOID:162"]
    assert terms["DOID:1612"]["definition"] == "A thoracic cancer." and terms["DOID:1612"]["synonyms"] == ["breast carcinoma"]
    rows = gap.obo_rows(terms, root_name="disease", depth=2, field="serious_illness")
    by = {r["code"]: r for r in rows}
    assert set(by) == {"DOID:162", "DOID:1612", "DOID:77"}  # the root is the group's name, not a candidate
    assert by["DOID:162"]["depth"] == 1 and by["DOID:1612"]["depth"] == 2
    assert by["DOID:162"]["descendants"] == 1 > by["DOID:77"]["descendants"] == 0
    assert by["DOID:162"]["broader"] == "disease" and by["DOID:1612"]["broader"] == "cancer"


def test_obo_leaf_terms_are_not_groups():
    rows = gap.obo_gap_rows(gap.parse_obo(OBO), {"serious_illness": [("disease", 2)]}, min_descendants=1)
    assert [r["label"] for r in rows] == ["cancer"]  # breast cancer and mood disorder have no members of their own


def test_obo_unknown_root_fails_loudly():
    with pytest.raises(ValueError, match="no term named"):
        gap.obo_rows(gap.parse_obo(OBO), root_name="nonexistent", depth=1, field="x")


IWAS = ("GWA Element ID,GWA Element Name,IWA Element ID,IWA Element Name\n"
        "4.A.4.b.1,Coaching and Developing Others,4.A.4.b.1.a,Coach others on career development.\n"
        "4.A.4.a.4,Establishing Relationships,4.A.4.a.4.a,Negotiate with labor unions.\n"
        "4.A.1.a.1,Getting Information,4.A.1.a.1.a,Study details of artistic productions.\n")


def test_onet_work_activities_are_picked_by_field_keywords_and_lose_their_full_stop():
    rows = gap.onet_rows(IWAS, {"labour_organising": [r"labor union"], "employment_transition": [r"career"]})
    assert {(r["target"], r["label"]) for r in rows} == {("labour_organising", "Negotiate with labor unions"),
                                                         ("employment_transition", "Coach others on career development")}
    assert all(r["broader"] and r["code"].startswith("4.A.") for r in rows)


def test_cex_groups_go_to_the_consumption_fields_they_inform_and_statistic_rows_are_skipped():
    items = [(0, "Average annual expenditures"), (13, "Mean"), (2, "Food"), (4, "Food away from home"), (13, "Share"),
             (2, "Apparel and services"), (4, "Footwear"), (4, "Men and boys"), (2, "Personal insurance and pensions"),
             (2, "Income before taxes"), (4, "Self-employment income"), (4, "Unemployment and workers' compensation, x")]
    got = {(r["target"], r["label"]) for r in gap.cex_rows([(1, "Before the table"), *items])}
    assert ("restaurants_dining", "Food away from home") in got and ("clothing_footwear", "Footwear") in got
    assert {("entrepreneurship", "Self-employment income"), ("income_earning", "Self-employment income"), ("job_loss", "Unemployment and workers' compensation, x")} <= got
    assert ("insurance_risk", "Personal insurance and pensions") in got and ("saving_investing", "Personal insurance and pensions") in got
    assert not any(l in {"Food", "Mean", "Share", "Men and boys"} for _, l in got)


def test_lcsh_narrower_headings_skip_subdivided_strings():
    N, A = gap._NARROWER, gap._ALABEL
    graph = [{"@id": "http://id.loc.gov/authorities/subjects/sh1", A: [{"@value": "Etiquette"}],
              N: [{"@id": "http://id.loc.gov/authorities/subjects/sh2"}, {"@id": "http://id.loc.gov/authorities/subjects/sh3"},
                  {"@id": "http://id.loc.gov/authorities/subjects/sh4"}]},
             {"@id": "http://id.loc.gov/authorities/subjects/sh2", A: [{"@value": "Table etiquette"}]},
             {"@id": "http://id.loc.gov/authorities/subjects/sh3", A: [{"@value": "Horsemanship--Etiquette"}]},
             {"@id": "http://id.loc.gov/authorities/subjects/sh4", A: [{"@value": "Courtesy"}]}]
    rows = gap.lcsh_rows(graph, "etiquette_norms")
    assert sorted(r["label"] for r in rows) == ["Courtesy", "Table etiquette"] and {r["broader"] for r in rows} == {"Etiquette"}


def coarse():
    return [make_card("s.a", label="Sector", links=[], axes=None), make_card("c.fraud", label="Fraud and deception", links=[], axes=None)]


def test_gap_candidates_merge_sources_carry_every_target_field_and_exclude_what_exists():
    rows = [{"source": "wikidata", "code": "Q1", "label": "scam", "target": "fraud_deception", "broader": "fraud", "description": "d"},
            {"source": "wikidata", "code": "Q1", "label": "scam", "target": "online_commerce", "broader": "e-commerce", "description": "d"},
            {"source": "getty_aat", "code": "300", "label": "Scams", "target": "fraud_deception", "broader": "", "description": ""},
            {"source": "wikidata", "code": "Q2", "label": "fraud and deception", "target": "fraud_deception", "broader": ""},
            {"source": "wikidata", "code": "Q3", "label": "forgery", "target": "fraud_deception", "broader": ""}]
    existing = [{"id": "f.forgery", "label": "Forgery", "aliases": [], "description": "", "kinds": [], "broader_in_source": [], "sources": []}]
    cands, rep = pool_mod.new_candidates(rows, existing, coarse(), order=["wikidata", "getty_aat"])
    assert [c["label"] for c in cands] == ["scam"]
    c = cands[0]
    assert c["target_fields"] == ["fraud_deception", "online_commerce"]
    assert {s["source"] for s in c["sources"]} == {"wikidata", "getty_aat"} and all(s["licence_status"] == "verified" for s in c["sources"])
    reasons = {d["label"]: d["reason"] for d in rep["dropped"]}
    assert "coarse" in reasons["fraud and deception"] and "existing candidate" in reasons["forgery"]
    assert rep["raw"] == len(cands) + len(rep["dropped"]) + rep["merged"]


@pytest.mark.parametrize("name", ["wikidata", "getty_aat", "doid", "mondo", "onet", "lcsh", "nibrs", "eurovoc", "bls_cex", "r_coicop"])
def test_every_gap_source_has_a_verified_licence_with_its_evidence(name):
    L = src.LICENCES[name]
    assert L["status"] == "verified" and L["licence"] and (L["evidence"].startswith("http") or "BACKPROPAGATION LI.56" in L["evidence"])


def test_attribution_names_the_attribution_sources():
    text = (ROOT / "ATTRIBUTION.md").read_text()
    for needle in ("Getty", "Disease Ontology", "MONDO", "O*NET", "EuroVoc", "Library of Congress"):
        assert needle in text, needle


# ---------- the committed data ----------

def read(path):
    return [json.loads(l) for l in Path(path).read_text(encoding="utf-8").splitlines() if l.strip()]


def test_committed_gap_candidates_are_clean_capped_and_do_not_touch_the_earlier_sets():
    cands = read(ROOT / "data/fine/candidates_gap_v0.jsonl")
    assert cands and all(c["id"].startswith("f.") and c["target_fields"] for c in cands)
    first = {c["id"] for c in read(ROOT / "data/fine/candidates_v0.jsonl")} | {c["id"] for c in read(ROOT / "data/fine/candidates_atus_v0.jsonl")}
    assert not first & {c["id"] for c in cands} and len({c["id"] for c in cands}) == len(cands)
    assert all(s["licence_status"] == "verified" for c in cands for s in c["sources"])
    assert not any(s["source"] in ("icatus", "coicop") for c in cands for s in c["sources"])
    per = {}
    for c in cands:
        for t in c["target_fields"]:
            per[t] = per.get(t, 0) + 1
    assert max(per.values()) <= 25  # 5 to 25 candidates per field
