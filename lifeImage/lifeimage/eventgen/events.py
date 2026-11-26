"""Event kinds of the probe world and their rows in the library's contract format.

Memberships are preformatted over existing coarse domains (form, content, outcome, setting; each relation sums to 1); a fine
domain is named only where one is unambiguous (`FINE`, kept when the fine card exists). Rows are validated by the library's
own `validate_row`. Magnitudes are prototype values, not measurements.
"""
import datetime as dt
import re
from functools import lru_cache

from ..generators.common import BASEMAP_VERSION, validate_row


def _m(f, c, o, s):
    return {k: v for k, v in (("form", f), ("content", c), ("outcome", o), ("setting", s)) if v}


KINDS = {  # key: (memberships, relation, magnitude)
    "born": (_m({"c.birth_of_child": 1}, {"c.pregnancy_birth": 1}, {"c.family_ties": 1}, {"c.medical_care": 1}), "impacted", 0.3),
    "preschool": (_m({"c.early_childhood_education": 1}, {"c.early_childhood_education": 1}, {"c.children_play": 1}, {"c.early_childhood_education": 1}), "impacted", 0.2),
    "school_start": (_m({"c.school_education": 1}, {"c.school_education": .6, "c.basic_skills": .4}, {"c.school_education": 1}, {"c.school_education": 1}), "impacted", 0.3),
    "primary_complete": (_m({"c.school_education": 1}, {"c.school_education": .5, "c.exams_assessment": .5}, {"c.school_education": 1}, {"c.school_education": 1}), "impacted", 0.4),
    "secondary_start": (_m({"c.school_education": 1}, {"c.school_education": 1}, {"c.school_education": 1}, {"c.school_education": 1}), "impacted", 0.3),
    "secondary_complete": (_m({"c.exams_assessment": 1}, {"c.school_education": .5, "c.exams_assessment": .5}, {"c.school_education": 1}, {"c.school_education": 1}), "impacted", 0.5),
    "tertiary_start": (_m({"c.higher_education": 1}, {"c.higher_education": 1}, {"c.higher_education": 1}, {"c.higher_education": 1}), "impacted", 0.4),
    "tertiary_complete": (_m({"c.higher_education": 1}, {"c.higher_education": 1}, {"c.higher_education": 1}, {"c.higher_education": 1}), "impacted", 0.6),
    "school_dropout": (_m({"c.school_education": 1}, {"c.school_education": 1}, {"c.school_education": 1}, {"c.school_education": 1}), "impacted", 0.3),
    "marriage": (_m({"c.marriage_wedding": 1}, {"c.marriage_cohabitation": 1}, {"c.family_ties": 1}, {"c.family_rituals": 1}), "structural", 0.6),
    "birth_of_child": (_m({"c.birth_of_child": 1}, {"c.pregnancy_birth": .4, "c.parenting_young_children": .6}, {"c.family_ties": 1}, {"c.medical_care": 1}), "causal", 0.8),
    "fatherhood": (_m({"c.birth_of_child": 1}, {"c.parenting_young_children": 1}, {"c.family_ties": 1}, {"c.medical_care": 1}), "causal", 0.6),
    "pregnancy": (_m({"c.pregnancy_birth": 1}, {"c.pregnancy_birth": 1}, {"c.family_ties": 1}, {"c.medical_care": 1}), "causal", 0.7),
    "divorce": (_m({"c.divorce": 1}, {"c.divorce": 1}, {"c.family_ties": 1}, {"c.legal_system": 1}), "structural", 0.6),
    "death": (_m({"c.death_dying": 1}, {"c.death_dying": 1}, {"c.bereavement": 1}, {"c.medical_care": 1}), "impacted", 1.0),
}
NEGATIVE = frozenset({"school_dropout", "divorce", "death"})  # events recorded on the negative channel (rare harm is recorded)
FINE = {"born": {}, "preschool": {"c.early_childhood_education": "f.preschool"},
        "marriage": {"c.marriage_cohabitation": "f.marriage", "c.marriage_wedding": "f.wedding"},
        "birth_of_child": {"c.birth_of_child": "f.childbirth"}, "pregnancy": {"c.pregnancy_birth": "f.pregnancy"},
        "divorce": {"c.divorce": "f.divorce"}, "death": {"c.death_dying": "f.death"}}


@lru_cache(maxsize=1)
def _fine_ids():
    try:
        from ..fine.cards import load_fine
        return frozenset(c["id"] for c in load_fine())
    except Exception:  # fine cards unreadable: stay coarse (rows remain valid)
        return frozenset()


def memberships(key):
    fine = {c: f for c, f in FINE.get(key, {}).items() if f in _fine_ids()}
    acc = {}
    for rel, w in KINDS[key][0].items():
        for d, x in w.items():
            d = fine.get(d, d)
            acc[(d, rel)] = acc.get((d, rel), 0.0) + x
    out = [{"domain": d, "rel": rel, "weight": round(x, 6)} for (d, rel), x in acc.items()]
    for rel in {m["rel"] for m in out}:   # rounding must not move a relation's total off 1
        group = [m for m in out if m["rel"] == rel]
        group[-1]["weight"] = round(1 - sum(m["weight"] for m in group[:-1]), 6)
    return out


def valid_time(birth, age):
    return (birth + dt.timedelta(days=round(age * 365.25))).isoformat()


_VALID_TIME = re.compile(r"^\d{4}(-\d{2}(-\d{2})?)?$")
_TEMPLATES = {}     # (key, region) -> the row's fixed part, validated once by the full contract check


def make_row(entity, region, key, birth, age, event_id):
    """A library-format row. Everything but entity, times and span is fixed by (key, region): that part is validated once by the full
    contract check (`validate_row`, on a row with placeholder entity, times and span), and each row then checks its own entity, time and
    span against the schema's rules for them, which gives the same verdicts as validating every row in full."""
    t = valid_time(birth, age)
    base = _TEMPLATES.get((key, region))
    if base is None:
        base = {"relation": KINDS[key][1], "memberships": memberships(key), "basemap_version": BASEMAP_VERSION,
                "channel": "negative" if key in NEGATIVE else "positive", "sign": -1 if key in NEGATIVE else 1, "entity_kind": "person", "revoked": False,
                "magnitude": KINDS[key][2], "tier": "attested", "confidence": 0.8, "production": "consumed", "context": {"jurisdiction": region}}
        validate_row({**base, "entity": "person:x", "valid_time": "2000-01-01", "record_time": "2000-01-01", "provenance": {"source": f"synthetic-eventgen:{region}", "span": "s"}})
        _TEMPLATES[(key, region)] = base
    if not (isinstance(entity, str) and entity and isinstance(event_id, str) and _VALID_TIME.match(t)):
        validate_row({**base, "entity": entity, "valid_time": t, "record_time": t, "provenance": {"source": f"synthetic-eventgen:{region}", "span": event_id}})
    return {"entity": entity, **{k: (dict(v) if isinstance(v, dict) else [dict(m) for m in v] if k == "memberships" else v) for k, v in base.items()},
            "valid_time": t, "record_time": t, "provenance": {"source": f"synthetic-eventgen:{region}", "span": event_id}}
