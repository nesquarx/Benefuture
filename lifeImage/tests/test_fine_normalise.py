"""Mechanical deduplication of candidate labels: what must merge, what must stay apart."""
import pytest

from lifeimage.fine.normalise import dedupe_key, merge_candidates


def cand(label, source="openalex", **kw):
    return {"label": label, "aliases": [], "description": "", "kinds": ["discipline"],
            "sources": [{"source": source, "code": label, "label": label, "licence_status": "unverified"}],
            "broader_in_source": [], **kw}


@pytest.mark.parametrize("a, b", [
    ("Nurses", "nurse"),
    ("Midwifery & Nursing", "nursing and midwifery"),
    ("Cafe Culture", "Café culture"),
    ("Statistics (applied)", "statistics"),
    ("The Law of the Sea", "law sea"),
    ("Physical-education teachers", "physical education teacher"),
])
def test_same_domain_different_spelling_is_one_candidate(a, b):
    assert dedupe_key(a) == dedupe_key(b)
    out, _ = merge_candidates([cand(a), cand(b, source="esco_isco")])
    assert len(out) == 1
    assert {s["source"] for s in out[0]["sources"]} == {"openalex", "esco_isco"}


@pytest.mark.parametrize("a, b", [
    ("Mathematical physics", "Physics and mathematics"),  # different scope
    ("Economics", "Economic history"),
    ("Statistics", "Statisticians"),  # field of study vs occupation, different words
    ("Analysis", "Analysi"),  # words ending in 'is' are not plurals
    ("Physics", "Physic"),
    ("Law enforcement", "Law"),
])
def test_different_domains_stay_apart(a, b):
    out, _ = merge_candidates([cand(a), cand(b)])
    assert len(out) == 2, (a, b, dedupe_key(a), dedupe_key(b))


def test_physics_and_mathematics_keep_their_s():
    assert "mathematic" in dedupe_key("Mathematics") and "physic" in dedupe_key("Physics")


def test_merge_keeps_aliases_and_the_first_source_label_as_canonical():
    out, report = merge_candidates([cand("nursing and midwifery", source="esco_isco"), cand("Midwifery & Nursing")],
                                   source_order=["openalex", "esco_isco"])
    (c,) = out
    assert c["label"] == "Midwifery & Nursing"  # openalex outranks esco_isco in the source order
    assert [a for a in c["aliases"]] == ["nursing and midwifery"]
    assert report["merged"] == 1


def test_residual_categories_are_dropped_loudly_not_silently():
    out, report = merge_candidates([cand("Other services, not elsewhere classified"), cand("Other activities related to employment"),
                                    cand("Plumbers")])
    assert [c["label"] for c in out] == ["Plumbers"]
    assert {d["reason"] for d in report["dropped"]} == {"residual category"}
    assert len(report["dropped"]) == 2


def test_merge_is_independent_of_input_order():
    items = [cand("Nurses"), cand("nurse", source="esco_isco"), cand("Plumbers"), cand("Economics")]
    a, _ = merge_candidates(items)
    b, _ = merge_candidates(list(reversed(items)))
    assert a == b
