"""Relational events (LI.65): every generated or extracted event is a bundle of the four relation layers, never a bare row.

An event record carries
- layer A: `memberships` over domains (form, content, outcome, setting; each relation sums to 1), the outcome memberships naming
  the counterfactual and the model or statement it comes from (LI.42);
- layer B: `participants`, one record per entity involved in the library's participation format (id, contribution, production,
  responsibility by freedom computed from contribution and the option set, impact per affected party, acting_for,
  under_agreement, informed, option_set); a missing option set takes the governed default and is logged as degraded (LI.40);
  `rows`, one evidence row per participant in the contract-v2 row format;
- layer D: `links` to other events of the same life (part_of, causes, re_description, concurrent), `from` -> `to` as in the
  library's events task (part -> whole, cause -> effect);
- metadata (LI.42): `valid_time`, `record_time`, `place`, `span` {start, end}.

Reuses, never copies: `validate_row` (rows), `validate_participation_answer` v2 (layer B), `responsibility_from_freedom`
(responsibility), `LINK_TYPES` and `SYMMETRIC` of the events battery (layer D), `validate_entity` (entities).

Reconciliation (BACKPROPAGATION BP.11, BP.12): the contract still labels each row with one of causal, structural, communicative,
impacted; here a participant's row is `causal` when it contributes at least 0.3, `structural` for an organisation, `impacted`
otherwise. The participation record's own contribution and responsibility carry the finer reading; the label is kept only as far as
the contract requires. The row's production enum has no `both`: a participant that both consumes and produces is `produced` in the
row and `both` in the participation record.
"""
import datetime as dt
import json
import re

from ..degradation import record_degradation
from ..events import LINK_TYPES, SYMMETRIC
from ..generators.common import seed_ids, validate_row
from ..governed import governed
from ..participation import validate_participation_answer
from ..responsibility import responsibility_from_freedom
from ..validate import ValidationError, validate_entity
from . import events as ev

A_RELS = ("form", "content", "outcome", "setting")
ORDER = ("born", "preschool", "school_start", "primary_complete", "secondary_start", "secondary_complete", "tertiary_start", "tertiary_complete",
         "school_dropout", "marriage", "divorce", "pregnancy", "birth_of_child", "fatherhood", "death")
LEVEL = {"preschool": "early_childhood", "school_start": "primary", "primary_complete": "primary", "secondary_start": "secondary",
         "secondary_complete": "secondary", "tertiary_start": "tertiary", "tertiary_complete": "tertiary", "school_dropout": "school"}
QUANTITY = {"born": "fertility.sex_ratio_at_birth", "preschool": "education.preprimary_gross_enrolment", "school_start": "education.primary_net_enrolment",
            "primary_complete": "education.primary_completion", "secondary_start": "education.progression_to_secondary",
            "secondary_complete": "education.lower_secondary_completion", "tertiary_start": "education.tertiary_gross_enrolment",
            "tertiary_complete": "education.tertiary_bachelor_attainment", "school_dropout": "education.primary_completion",
            "marriage": "family.age_first_marriage", "divorce": "family.divorces_per_100_marriages", "pregnancy": "fertility.asfr",
            "birth_of_child": "fertility.asfr", "fatherhood": "fertility.asfr", "death": "mortality.prob_death_0_40"}
COURSE = {"born": "the person is not born in this stratum's birth cohort", "preschool": "the child stays at home until primary entry age",
          "school_start": "the child does not enter primary school", "primary_complete": "the pupil leaves before the last grade",
          "secondary_start": "the pupil does not progress to secondary school", "secondary_complete": "the student leaves before completing lower secondary",
          "tertiary_start": "the graduate does not enter tertiary education", "tertiary_complete": "the student does not complete the degree",
          "school_dropout": "the pupil stays enrolled to the end of the level", "marriage": "the person stays unmarried at this age",
          "divorce": "the couple stays married", "pregnancy": "the woman does not conceive in this year",
          "birth_of_child": "no birth to this woman in this year", "fatherhood": "no birth to the man's spouse in this year",
          "death": "the person survives the year"}
HARM = {"school_dropout": 1, "divorce": 1, "death": 3}  # harm of the outcome produced, 0-3 (marriage under the age of majority: 1)
ALT = {"marriage": ("remain unmarried", 0), "divorce": ("remain married", 1), "school_dropout": ("remain enrolled", 0)}
# (role, contribution, production, impacts [(affected role, sign, magnitude)], who it acts for)
SPECS = {
    "born": [("self", 0, "consumed", []), ("mother", .6, "produced", [("self", 1, 3)]), ("health", .4, "produced", [("self", 1, 2), ("mother", 1, 1)])],
    "preschool": [("self", .3, "both", [("self", 1, 1)]), ("school", .5, "produced", [("self", 1, 2)]), ("parent", .2, "produced", [("self", 1, 1)])],
    "school_start": [("self", .3, "both", [("self", 1, 2)]), ("school", .5, "produced", [("self", 1, 2)]), ("parent", .2, "produced", [("self", 1, 1)])],
    "secondary_start": [("self", .3, "both", [("self", 1, 2)]), ("school", .5, "produced", [("self", 1, 2)]), ("parent", .2, "produced", [("self", 1, 1)])],
    "tertiary_start": [("self", .5, "both", [("self", 1, 2)]), ("school", .5, "produced", [("self", 1, 2)])],
    "primary_complete": [("self", .5, "both", [("self", 1, 2)]), ("school", .5, "produced", [("self", 1, 2)])],
    "secondary_complete": [("self", .5, "both", [("self", 1, 2)]), ("school", .5, "produced", [("self", 1, 2)])],
    "tertiary_complete": [("self", .5, "both", [("self", 1, 3)]), ("school", .5, "produced", [("self", 1, 3)])],
    "school_dropout": [("self", .6, "produced", [("self", -1, 1)]), ("parent", .3, "produced", [("self", -1, 1)]), ("school", .1, "produced", [("self", -1, 1)])],
    "marriage": [("self", .4, "both", [("spouse", 1, 2)]), ("spouse", .4, "both", [("self", 1, 2)]),
                 ("registry", .2, "produced", [("self", 1, 1), ("spouse", 1, 1)])],
    "divorce": [("self", .45, "produced", [("spouse", -1, 1)]), ("spouse", .45, "produced", [("self", -1, 1)]), ("court", .1, "produced", [])],
    "pregnancy": [("self", .7, "both", [("child", 1, 2)]), ("other_parent", .1, "produced", [("self", 1, 1)]),
                  ("health", .2, "produced", [("self", 1, 1), ("child", 1, 1)]), ("child", 0, "consumed", [])],
    "birth_of_child": [("self", .5, "produced", [("child", 1, 3)]), ("other_parent", .2, "produced", [("child", 1, 2)]),
                       ("health", .3, "produced", [("child", 1, 2), ("self", 1, 1)]), ("child", 0, "consumed", [])],
    "fatherhood": [("self", .2, "produced", [("child", 1, 2)]), ("mother", .5, "produced", [("child", 1, 3)]),
                   ("health", .3, "produced", [("child", 1, 2)]), ("child", 0, "consumed", [])],
    "death": [("self", 0, None, [("family", -1, 2)]), ("family", 0, None, [])],
}
LABEL = {"self": "the person", "mother": "the mother", "parent": "a parent", "spouse": "the spouse", "other_parent": "the other parent",
         "child": "the child", "school": "the school", "health": "the health service", "registry": "the civil registry", "court": "the family court",
         "family": "the family"}
CONF = {"causal": 0.8, "part_of": 0.95, "concurrent": 0.5, "causes_marriage": 0.6}
_ISO = re.compile(r"^\d{4}(-\d{2}(-\d{2})?)?$")


# ---- entities ----
def entity_id(role, p, n, region, kind, other_parent):
    pid = p.pid
    if role == "self":
        return f"person:{pid}"
    if role == "other_parent":
        return other_parent
    if role == "school":
        return f"school:{region}:{LEVEL[kind]}"
    if role in ("health", "registry", "court"):
        return f"agency:{region}:{ {'health': 'health_service', 'registry': 'civil_registry', 'court': 'family_court'}[role] }"
    if role == "child":
        return f"child:{pid}:{n}"
    return f"{role}:{pid}"


def entity_kind(eid):
    return "organisation" if eid.startswith(("school:", "agency:")) else "person"


def entities(events_by_person):
    """{id, kind} of every entity named by the events, once each, validated."""
    seen = {}
    for evs in events_by_person.values():
        for e in evs:
            for pt in e["participants"]:
                seen[pt["id"]] = entity_kind(pt["id"])
    return [validate_entity({"id": i, "kind": k}) for i, k in sorted(seen.items())]


# ---- layer A ----
def counterfactual(kind, region):
    return {"course": COURSE[kind], "source": f"model:eventgen:{QUANTITY[kind]}@{region}"}


def _with_counterfactual(mems, cf):
    return [dict(m, counterfactual=cf) if m["rel"] == "outcome" else dict(m) for m in mems]


# ---- the person's events ----
def person_events(world, p, light=False):
    """The relational events of a person in time order, with their links; degradations go to `world.relational_degraded`."""
    log = world.relational_degraded
    birth = _birth()
    preg_len, horizon, minor = governed("eventgen.pregnancy_years"), governed("eventgen.horizon_age"), governed("eventgen.minor_age")
    marriage = next((a for k, a in p.events if k == "marriage"), None)
    divorce = next((a for k, a in p.events if k == "divorce"), None)
    births = sorted(a for k, a in p.events if k == "birth_of_child")
    raw = []   # (kind, start age, end age, child index)
    for k, a in p.events:
        child = births.index(a) + 1 if k == "birth_of_child" else 0
        end = divorce if (k == "marriage" and divorce is not None) else (p.death if p.death is not None else float(horizon)) if k == "marriage" else a
        raw.append((k, a, end, child))
        if k == "birth_of_child":
            raw.append(("pregnancy", a - preg_len, a, child))
    raw.sort(key=lambda e: (e[1], ORDER.index(e[0])))
    events = []
    fathered = 0
    for n, (kind, age, end, child) in enumerate(raw):
        if kind == "fatherhood":
            fathered += 1
            child = fathered
        married_now = marriage is not None and marriage <= age + 1e-9 and (divorce is None or age < divorce)
        other = f"spouse:{p.pid}" if married_now else f"partner:{p.pid}:{child}"
        events.append(_event(p, kind, age, end, f"ev:{p.pid}-{n:02d}", child, other, minor, log, birth, light))
    _link(events, raw, marriage, world.noise["nonmarital_birth_relative_hazard"])
    return events


def _birth():
    from .world import BIRTH_DATE
    return BIRTH_DATE


def _event(p, kind, age, end, eid, child, other, minor, log, birth, light=False):
    region = p.region
    t = ev.valid_time(birth, age)
    mems = _with_counterfactual(ev.memberships(kind), counterfactual(kind, region))
    adult = age >= minor
    if light:   # times, kinds, spans and links only (the sequence head); participants and rows are built and validated in full mode
        return {"id": eid, "kind": kind, "place": region, "valid_time": t, "record_time": t, "span": {"start": t, "end": ev.valid_time(birth, end)},
                "memberships": mems, "participants": [], "roles": {}, "rows": [], "links": []}
    specs = [s for s in SPECS[kind] if not (s[0] == "parent" and adult)]
    total = sum(s[1] for s in specs)
    ids = {s[0]: entity_id(s[0], p, child, region, kind, other) for s in specs}
    if kind == "fatherhood":
        ids["mother"] = f"spouse:{p.pid}"
    harm = HARM.get(kind, 1 if kind == "marriage" and not adult else 0)
    entries, rows, roles = [], [], {}
    for role, c, prod, imps in specs:
        pid = ids[role]
        contrib = c / total if total else 0.0
        option = _option_set(kind, role, adult)
        resp = responsibility_from_freedom(contrib, option, harm, log=log, item=eid)
        impact = [{"party": ids[tr], "sign": sg, "magnitude": mg} for tr, sg, mg in imps if tr in ids]
        entry = {"id": pid, "contribution": contrib, "responsibility": resp, "impact": impact,
                 "acting_for": ids["self"] if role == "parent" else None, "under_agreement": _agreement(kind, role),
                 "informed": _informed(kind, role), "volition": None, "volition_record": None, "production": prod, "option_set": option}
        entries.append(entry)
        roles[pid] = role
        rows.append(_row(kind, role, entry, mems, region, t, eid))
    event = {"id": eid, "kind": kind, "statement": _statement(kind, p, age), "place": region, "valid_time": t, "record_time": t,
             "span": {"start": t, "end": ev.valid_time(birth, end)}, "memberships": mems, "participants": entries, "roles": roles, "rows": rows, "links": []}
    return validate_event(event)


def _option_set(kind, role, adult):
    """The alternatives open to the participant: modelled for a free adult act, missing (None, logged by the responsibility rule) where the
    act is by a minor or the other party of a divorce, whose freedom the generator does not model."""
    if kind == "death" or role in ("child", "family"):
        return []
    if (role == "self" and not adult and kind in ("marriage", "school_dropout")) or (role == "spouse" and kind == "divorce"):
        return None
    alt, h = ALT.get(kind, ("decline to take part", 0))
    return [{"alternative": alt, "harm": h}]


def _agreement(kind, role):
    if kind == "marriage":
        return "marriage registration law" if role == "registry" else "marriage contract"
    if kind == "divorce":
        return "divorce law" if role == "court" else "marriage contract being dissolved"
    if kind in LEVEL and role in ("self", "school", "parent"):
        return "school enrolment terms"
    return None


def _informed(kind, role):
    if kind == "marriage" and role in ("self", "spouse"):
        return "the terms of the marriage contract"
    if kind in LEVEL and role == "parent":
        return "the school's enrolment terms"
    return None


def _row(kind, role, entry, mems, region, t, eid):
    eidn = entry["id"]
    rel = ev.KINDS[kind][1] if role == "self" else "structural" if entity_kind(eidn) == "organisation" else "causal" if entry["contribution"] >= 0.3 else "impacted"
    neg = kind in ev.NEGATIVE
    row = {"entity": eidn, "relation": rel, "memberships": [dict(m) for m in mems], "basemap_version": ev.BASEMAP_VERSION,
           "channel": "negative" if neg else "positive", "sign": -1 if neg else 1, "entity_kind": entity_kind(eidn), "revoked": False,
           "magnitude": ev.KINDS[kind][2], "valid_time": t, "record_time": t, "tier": "attested", "confidence": 0.8,
           "context": {"jurisdiction": region}, "provenance": {"source": f"synthetic-eventgen:{region}", "span": eid}}
    if entry["production"] is not None:
        row["production"] = "consumed" if entry["production"] == "consumed" else "produced"
    if entry["option_set"] is not None:
        row["option_set"] = entry["option_set"]
    return row


def _statement(kind, p, age):
    who = "woman" if p.sex == "f" else "man"
    text = {"born": f"A {who} was born in {p.region}", "preschool": f"A child in {p.region} started preschool", "school_start": f"A child in {p.region} started primary school",
            "primary_complete": f"A pupil in {p.region} completed primary school", "secondary_start": f"A pupil in {p.region} started secondary school",
            "secondary_complete": f"A student in {p.region} completed lower secondary school", "tertiary_start": f"A student in {p.region} started tertiary education",
            "tertiary_complete": f"A student in {p.region} completed a tertiary degree", "school_dropout": f"A pupil in {p.region} left school before completing the level",
            "marriage": f"A {who} in {p.region} married", "divorce": f"A {who} in {p.region} divorced", "pregnancy": f"A woman in {p.region} became pregnant",
            "birth_of_child": f"A woman in {p.region} gave birth to a child", "fatherhood": f"A man in {p.region} became a father", "death": f"A {who} in {p.region} died"}[kind]
    return f"{text} at age {age:.1f}."


# ---- layer D ----
def _link(events, raw, marriage, nonmarital_hazard):
    by = {}
    for e, r in zip(events, raw):
        by.setdefault(r[0], []).append(e)
    first = lambda k: (by.get(k) or [None])[0]  # noqa: E731

    def add(src, dst, typ, conf):
        src["links"].append({"from": src["id"], "to": dst["id"], "type": typ, "confidence": conf})
    for a, b in (("primary_complete", "secondary_start"), ("secondary_complete", "tertiary_start")):
        if first(a) and first(b):
            add(first(a), first(b), "causes", CONF["causal"])   # progression: the level completed is the condition of the next (UIS progression Param)
    mar = first("marriage")
    if mar:
        if first("divorce"):
            add(first("divorce"), mar, "part_of", CONF["part_of"])
        r = nonmarital_hazard
        child = first("birth_of_child") or first("fatherhood")
        if child and r < 1:   # the model raises the birth hazard on marriage: a causal reading is supported
            tm = dt.date.fromisoformat(mar["valid_time"])
            tc = dt.date.fromisoformat(child["valid_time"])
            if tm <= tc <= tm + dt.timedelta(days=365.25 * governed("eventgen.marriage_birth_link_years")):
                add(mar, child, "causes", CONF["causes_marriage"])
    for b in by.get("birth_of_child", []):
        pregs = [g for g in by.get("pregnancy", []) if g["span"]["end"] == b["valid_time"]]
        if pregs:
            add(b, pregs[0], "part_of", CONF["part_of"])
    drop = first("school_dropout")
    if drop and mar:   # no source here supports early marriage causing dropout in the model: only the temporal reading
        if _overlap(drop, mar, governed("eventgen.concurrent_window_years")):
            add(drop, mar, "concurrent", CONF["concurrent"])


def _d(iso):
    return dt.date.fromisoformat(iso if len(iso) == 10 else iso + ("-01" * (3 - 1 - iso.count("-"))))


def _overlap(a, b, window):
    pad = dt.timedelta(days=365.25 * window)
    return _d(a["span"]["start"]) - pad <= _d(b["span"]["end"]) and _d(b["span"]["start"]) - pad <= _d(a["span"]["end"])


def validate_links(events):
    """Temporal and structural rules of layer D over one life's events: known endpoints, no self link, known type; causes: the effect does not
    precede the cause; part_of: the part's span lies inside the whole's span; concurrent: the spans overlap within the window;
    re_description: same valid time."""
    byid = {e["id"]: e for e in events}
    window = governed("eventgen.concurrent_window_years")
    for e in events:
        for l in e["links"]:
            if l["from"] != e["id"] or l["to"] not in byid or l["to"] == l["from"]:
                raise ValidationError(f"{e['id']}: link {l} names an unknown or identical event")
            if l["type"] not in LINK_TYPES:
                raise ValidationError(f"{e['id']}: link type {l['type']!r} not in {LINK_TYPES}")
            if not 0 < l["confidence"] < 1:
                raise ValidationError(f"{e['id']}: link confidence must be in (0, 1)")
            x, y = e, byid[l["to"]]
            if l["type"] == "causes" and _d(y["valid_time"]) < _d(x["valid_time"]):
                raise ValidationError(f"{x['id']} causes {y['id']} but the effect ({y['valid_time']}) precedes the cause ({x['valid_time']})")
            if l["type"] == "part_of" and not (_d(y["span"]["start"]) <= _d(x["span"]["start"]) and _d(x["span"]["end"]) <= _d(y["span"]["end"])):
                raise ValidationError(f"{x['id']} is part_of {y['id']} but its span {x['span']} lies outside {y['span']}")
            if l["type"] == "concurrent" and not _overlap(x, y, window):
                raise ValidationError(f"{x['id']} and {y['id']} are linked concurrent but their spans do not overlap")
            if l["type"] == "re_description" and x["valid_time"] != y["valid_time"]:
                raise ValidationError(f"{x['id']} and {y['id']} are one occurrence but have different valid times")
    return events


_ROW_OK = set()


def validate_row_cached(row, strict=False):
    """`validate_row` (the library's contract check) run once per distinct row structure: a row's schema and membership checks do not depend on
    its entity, times or provenance span, which are checked here directly (non-blank entity, ISO times, text span). `strict` validates every row."""
    if strict:
        return validate_row(row)
    if not isinstance(row.get("entity"), str) or not row["entity"].strip() or not _ISO.match(str(row.get("valid_time"))) or not _ISO.match(str(row.get("record_time"))) \
            or not isinstance(row.get("provenance", {}).get("span"), str):
        return validate_row(row)   # malformed in a fast-path field: the full check raises the library's own error
    key = json.dumps({**row, "entity": "x", "valid_time": "2000-01-01", "record_time": "2000-01-01", "provenance": {"source": row["provenance"]["source"], "span": ""}}, sort_keys=True)
    if key not in _ROW_OK:
        validate_row(row)
        _ROW_OK.add(key)
    return row


# ---- validation of one event (all layers) ----
def check_core(memberships, participants, roles, valid_time, record_time, span, place, rows=None, ids=None):
    """Layers A and B and the metadata of one event or snippet form; raises ValidationError."""
    ids = seed_ids() if ids is None else ids
    for f, v in (("valid_time", valid_time), ("record_time", record_time)):
        if not isinstance(v, str) or not _ISO.match(v):
            raise ValidationError(f"{f} missing or malformed: {v!r}")
    if not isinstance(span, dict) or not span.get("start") or not span.get("end") or span["end"] < span["start"] or span["start"] != valid_time:
        raise ValidationError(f"span must run from the valid time to a later or equal end, not {span!r}")
    if not isinstance(place, str) or not place.strip():
        raise ValidationError("place missing")
    if not memberships:
        raise ValidationError("layer A: no memberships")
    by = {}
    for m in memberships:
        if m["rel"] not in A_RELS:
            raise ValidationError(f"layer A: relation {m['rel']!r} not in {A_RELS}")
        if m["domain"] not in ids and not m["domain"].startswith("f."):
            raise ValidationError(f"layer A: unknown domain {m['domain']!r}")
        by.setdefault(m["rel"], []).append(m)
        cf = m.get("counterfactual")
        if m["rel"] == "outcome" and (not cf or not str(cf.get("course", "")).strip() or not str(cf.get("source", "")).startswith(("model:", "stated", "implied"))):
            raise ValidationError(f"layer A: outcome membership {m['domain']} lacks a counterfactual naming its model or statement")
    for rel in A_RELS:
        w = sum(m["weight"] for m in by.get(rel, []))
        if abs(w - 1) > 1e-6:
            raise ValidationError(f"layer A: {rel} memberships sum to {w}, not 1")
    if not participants:
        raise ValidationError("layer B: no participant records")
    listed = [{"id": e["id"], "label": roles.get(e["id"], e["id"])} for e in participants]
    validate_participation_answer({"verdict": "participation", "participants": participants}, listed, version=2)
    for e in participants:
        if e["contribution"] > 0 and e["responsibility"] <= 0:
            raise ValidationError(f"layer B: {e['id']} contributes but carries no responsibility")
        if e["contribution"] == 0 and e["responsibility"] != 0:
            raise ValidationError(f"layer B: {e['id']} contributes nothing but carries responsibility")
    if rows is not None:
        if sorted(r["entity"] for r in rows) != sorted(e["id"] for e in participants):
            raise ValidationError("rows and participant records name different entities")
        for r in rows:
            validate_row_cached(r)
    return True


def validate_event(e):
    check_core(e["memberships"], e["participants"], e["roles"], e.get("valid_time"), e.get("record_time"), e.get("span"), e.get("place"), e["rows"])
    return e


# ---- event snippets of the calibration table ----
NEGATIVE_PREFIX = ("harm.", "mortality.", "health.maternal", "health.undernourishment", "health.stunting", "health.road", "money.extreme", "work.unemployment",
                   "work.youth_unemployment", "family.married_by", "family.crude_divorce")


def _weights(domains):
    n = len(domains)
    w = [round(1 / n, 9)] * (n - 1)
    return w + [round(1 - sum(w), 9)]


def relational_form(snippet, quantity, year, region, value, unit, source_id=None):
    """The extracted relational form of an event snippet: actor -> a participation record, action -> an event with layer A memberships
    over the snippet's domains, outcome -> outcome membership with a counterfactual naming the source's indicator, links (none: a snippet
    is one event). The free-text snippet stays as it is; its valid time is the reference year of the indicator."""
    domains = list(snippet["domains"])
    cf = {"course": f"the outcome does not occur; the baseline is the stratum's {quantity} of {value:g} {unit}", "source": f"model:{source_id or snippet['source_id']}:{quantity}"}
    mems = [{"domain": d, "rel": rel, "weight": w, **({"counterfactual": cf} if rel == "outcome" else {})}
            for rel in A_RELS for d, w in zip(domains, _weights(domains))]
    sign = -1 if quantity.startswith(NEGATIVE_PREFIX) else 1
    actor = "actor:" + re.sub(r"[^a-z0-9]+", "-", snippet["actor"].lower()).strip("-")[:40]
    log = []
    resp = responsibility_from_freedom(1.0, None, 0 if sign == 1 else 1, log=log, item=f"snippet:{quantity}:{region}")
    entry = {"id": actor, "contribution": 1.0, "responsibility": resp, "impact": [{"party": actor, "sign": sign, "magnitude": 1}], "acting_for": None,
             "under_agreement": None, "informed": None, "volition": None, "volition_record": None, "production": "produced", "option_set": None}
    t = str(year)
    return {"event": {"memberships": mems, "valid_time": t, "record_time": t, "span": {"start": t, "end": t}, "place": region},
            "participants": [entry], "roles": {actor: "actor"}, "links": [], "degraded": log}


def validate_relational_snippet(rel):
    if not isinstance(rel, dict) or not isinstance(rel.get("event"), dict):
        raise ValidationError("event snippet lacks its relational form")
    e = rel["event"]
    check_core(e.get("memberships"), rel.get("participants"), rel.get("roles") or {}, e.get("valid_time"), e.get("record_time"), e.get("span"), e.get("place"))
    return rel


def relationalise_params(params):
    """Params whose event snippets carry the relational form (derived from the snippet and its Param)."""
    import dataclasses
    out = []
    for p in params:
        sn = [dict(s, relational=relational_form({k: v for k, v in s.items() if k != "relational"}, p.quantity, p.year, p.region, p.value, p.unit, p.source_id))
              for s in p.event_snippets]
        out.append(dataclasses.replace(p, event_snippets=sn))
    return out
