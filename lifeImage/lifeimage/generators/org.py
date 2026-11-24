"""Organisation generator: small entities (a cafe, a charity, a software firm, a farm, a clinic, a sports club) with
prospectus-like text and ground-truth rows.

Events are the organisation's milestones and measured activity; rows per tier follow the persona generator's rules
(claimed: the prospectus says it; attested: a register or inspector records it; measured: a ledger, till or monitor
log). A prospectus boasts, so organisations mention more of their events than persons do (parameter below). Rare harm
(an incident) is recorded on the negative channel with an option set.
"""
import datetime as dt
from dataclasses import dataclass, field

from . import catalogue as C
from .common import BASEMAP_VERSION, CITIES, COUNTRIES, STREETS, clip, pick, stream
from .life import _conf, _day, _membership_weights, fmt, mi, parse_date, ym
from .params import Param, resolve

GENERATOR_VERSION = 1
KINDS = ["cafe", "charity", "software_firm", "farm", "clinic", "sports_club"]

ORG_PARAMS = {
    "org_claim_mention": Param("org_claim_mention", 0.65, 0.2, 0.95, "share of events", "assumption (a prospectus boasts: most milestones are written down)", "low"),
    "org_p_attested": Param("org_p_attested", 0.7, 0.3, 0.95, "share of registered events", "assumption (registers, inspections and filings reach the dataset)", "low"),
    "org_p_logged": Param("org_p_logged", 0.85, 0.4, 1.0, "share of organisations", "assumption (small organisations keep a till, ledger or monitor)", "low"),
    "org_p_harm_per_year": Param("org_p_harm_per_year", 0.04, 0.005, 0.12, "per organisation year", "assumption (a recorded culpable incident is rare)", "low"),
}


def m(f=None, c=None, o=None, s=None):
    return C.m(f, c, o, s)


def T(key, d, mem, sched, mag=.4, record="inf", src="", logsrc="", slots=None, anchor=False, claim=1.0, pattern="make", options=(), harm=0):
    return C.Tpl(key, "org", d, mem, pattern, "causal", mag, record, src, logsrc, None, None, slots or {}, 0, 120, (), anchor, None, options, harm, claim) , sched


# sched: "start" | ("once", lo_frac, hi_frac, probability) | ("yearly", p)
COMMON = [
    T("founded", "was founded in {city}", m({"c.entrepreneurship": 1}, {"c.entrepreneurship": 1}, {"c.neighbours_community": 1}, {"c.neighbours_community": 1}), "start", .6, "formal", "business-register", anchor=True),
    T("premises", "moved into {premises}", m({"c.rent_mortgage": 1}, {"c.housing_search": .5, "c.rent_mortgage": .5}, {"c.urban_planning": 1}, {"c.neighbours_community": 1}), ("once", .1, .6, .8), .3, "formal", "lease-record", slots={"premises": ["a converted shop on the high street", "a unit near the station", "a former chapel hall", "a barn at the edge of town"]}),
    T("accounts", "filed accounts showing {outcome}", m({"c.finance_accounting": 1}, {"c.finance_accounting": .6, "c.taxation_compliance": .4}, {"c.public_administration": 1}, {"c.government_services": 1}), ("yearly", .35), .2, "formal", "annual-filing", slots={"outcome": ["a small surplus", "a modest profit", "break-even", "steady turnover"]}, claim=.6),
    T("hire", "took on {n} new staff", m({"c.employment_job": 1}, {"c.employment_job": .6, "c.workplace_relations": .4}, {"c.employment_job": 1}, {"c.employment_job": 1}), ("yearly", .25), .35, "formal", "payroll-record", slots={"n": ["two", "three", "four", "five"]}),
    T("community", "supported the {what}", m({"c.community_groups": 1}, {"c.neighbours_community": .6, "c.volunteering": .4}, {"c.neighbours_community": 1}, {"c.neighbours_community": 1}), ("yearly", .2), .3, "inf", slots={"what": ["local school fair", "street party", "winter coat drive", "neighbourhood clean-up", "town carnival"]}, claim=1.3),
    T("sustainability", "{what}", m({"c.environmental_stewardship": 1}, {"c.waste_recycling": .5, "c.environmental_stewardship": .5}, {"c.environmental_stewardship": 1}, {"c.neighbours_community": 1}), ("yearly", .12), .25, "inf", slots={"what": ["cut our waste by a third", "switched to renewable electricity", "stopped single-use packaging", "planted a hedgerow"]}, claim=1.3),
]
KIND_TPL = {
    "cafe": [
        T("opening", "opened to the public", m({"c.hospitality_work": 1}, {"c.restaurants_dining": .5, "c.cooking": .5}, {"c.neighbours_community": 1}, {"c.restaurants_dining": 1}), ("once", 0, .05, 1.0), .5, "inf", claim=1.5),
        T("customers", "served about {n} customers a week", m({"c.customer_service": 1}, {"c.restaurants_dining": .6, "c.eating_drinking": .4}, {"c.eating_drinking": 1}, {"c.restaurants_dining": 1}), ("yearly", .5), .45, "log", logsrc="till-log", slots={"n": ["400", "800", "1,200", "2,000"]}, claim=1.1),
        T("hygiene", "earned a top food hygiene rating", m({"c.cooking": 1}, {"c.occupational_safety": .5, "c.nutrition_diet": .5}, {"c.preventive_health": 1}, {"c.restaurants_dining": 1}), ("once", .2, .9, .8), .35, "formal", "food-hygiene-register", claim=1.5),
        T("sourcing", "began buying from local {what}", m({"c.food_purchasing": 1}, {"c.food_purchasing": .6, "c.horticulture_farming": .4}, {"c.neighbours_community": 1}, {"c.food_purchasing": 1}), ("once", .1, .8, .7), .3, "inf", slots={"what": ["bakers and growers", "dairies", "roasters", "farms"]}),
        T("training", "trained our baristas in {what}", m({"c.vocational_training": 1}, {"c.hospitality_work": .6, "c.cooking": .4}, {"c.vocational_training": 1}, {"c.restaurants_dining": 1}), ("yearly", .15), .25, "formal", "training-record", slots={"what": ["latte art", "food allergens", "customer care"]}),
        T("food_incident", "had a customer complaint about {what}", m({"c.negligence_recklessness": 1}, {"c.occupational_safety": .5, "c.negligence_recklessness": .5}, {"c.physical_health": 1}, {"c.restaurants_dining": 1}), ("yearly", "harm"), .3, "formal", "inspection-report", slots={"what": ["undeclared nuts", "a cold chain failure", "a mislabelled allergen"]}, pattern="harm", harm=2, claim=.1,
          options=(("checked the allergen list", 0), ("asked the supplier to confirm", 1), ("served as usual", 2))),
    ],
    "charity": [
        T("registered", "was registered as a charity", m({"c.civil_society_advocacy": 1}, {"c.charity_giving": .5, "c.civil_society_advocacy": .5}, {"c.neighbours_community": 1}, {"c.government_services": 1}), ("once", 0, .1, 1.0), .5, "formal", "charity-register", anchor=True, claim=1.5),
        T("meals", "distributed about {n} meals a month", m({"c.charity_giving": 1}, {"c.poverty_scarcity": .5, "c.food_purchasing": .5}, {"c.nutrition_diet": 1}, {"c.neighbours_community": 1}), ("yearly", .5), .55, "log", logsrc="distribution-log", slots={"n": ["300", "800", "1,500", "3,000"]}, claim=1.2),
        T("volunteers", "recruited {n} regular volunteers", m({"c.volunteering": 1}, {"c.volunteering": .6, "c.community_groups": .4}, {"c.neighbours_community": 1}, {"c.civil_society_advocacy": 1}), ("yearly", .3), .4, "inf", slots={"n": ["ten", "twenty", "forty"]}, claim=1.4),
        T("audit", "had its accounts independently examined", m({"c.finance_accounting": 1}, {"c.finance_accounting": .5, "c.taxation_compliance": .5}, {"c.civil_society_advocacy": 1}, {"c.government_services": 1}), ("yearly", .3), .3, "formal", "charity-commission-filing", claim=1.5),
        T("partnership", "partnered with {who}", m({"c.civil_society_advocacy": 1}, {"c.mutual_aid": .5, "c.welfare_benefits": .5}, {"c.neighbours_community": 1}, {"c.civil_society_advocacy": 1}), ("yearly", .15), .35, "inf", slots={"who": ["the primary school", "the health centre", "the council housing team", "two local churches"]}),
        T("safeguarding", "had a lapse in {what}", m({"c.negligence_recklessness": 1}, {"c.stalking_privacy": .5, "c.negligence_recklessness": .5}, {"c.mental_health": 1}, {"c.civil_society_advocacy": 1}), ("yearly", "harm"), .3, "formal", "regulator-report", slots={"what": ["volunteer vetting", "record keeping", "data protection"]}, pattern="harm", harm=1, claim=.1,
          options=(("checked the references", 0), ("asked a trustee to review", 0), ("skipped the check", 1))),
    ],
    "software_firm": [
        T("launch", "launched {what}", m({"c.software_development": 1}, {"c.software_development": .6, "c.digital_tool_use": .4}, {"c.digital_tool_use": 1}, {"c.software_development": 1}), ("yearly", .3), .6, "inf", slots={"what": ["our scheduling product", "version two of the platform", "a mobile app for customers", "an analytics dashboard"]}, claim=1.4),
        T("uptime", "kept uptime above {pct}", m({"c.it_operations": 1}, {"c.it_operations": .6, "c.software_development": .4}, {"c.digital_tool_use": 1}, {"c.software_development": 1}), ("yearly", .5), .45, "log", logsrc="uptime-monitor", slots={"pct": ["99.5%", "99.9%", "99.95%"]}, claim=1.2),
        T("security_cert", "passed {what}", m({"c.cybersecurity": 1}, {"c.cybersecurity": .6, "c.it_operations": .4}, {"c.cybersecurity": 1}, {"c.software_development": 1}), ("once", .3, .9, .8), .4, "formal", "certification-register", slots={"what": ["a security certification audit", "an information security audit"]}, claim=1.5),
        T("open_source", "released {what} as open source", m({"c.software_development": 1}, {"c.software_development": .6, "c.computer_science": .4}, {"c.software_development": 1}, {"c.software_development": 1}), ("yearly", .12), .4, "log", logsrc="repo-log", slots={"what": ["our parsing library", "a testing tool", "the data connector"]}, claim=1.1),
        T("customers_won", "signed {n} new business customers", m({"c.sales_marketing": 1}, {"c.sales_marketing": .6, "c.business_administration": .4}, {"c.entrepreneurship": 1}, {"c.software_development": 1}), ("yearly", .35), .4, "log", logsrc="crm-log", slots={"n": ["five", "twelve", "twenty"]}, claim=1.3),
        T("outage", "suffered {what}", m({"c.negligence_recklessness": 1}, {"c.cybersecurity": .5, "c.it_operations": .5}, {"c.digital_tool_use": 1}, {"c.software_development": 1}), ("yearly", "harm"), .3, "log", logsrc="uptime-monitor", slots={"what": ["a six-hour outage", "a data exposure affecting customers", "a bad release that lost orders"]}, pattern="harm", harm=2, claim=.1,
          options=(("staged the release", 0), ("tested on a copy", 1), ("shipped on Friday evening", 2))),
    ],
    "farm": [
        T("harvest", "harvested {what}", m({"c.horticulture_farming": 1}, {"c.horticulture_farming": .6, "c.agricultural_science": .4}, {"c.food_purchasing": 1}, {"c.agri_forestry_fishing_work": 1}), ("yearly", .6), .5, "log", logsrc="yield-ledger", slots={"what": ["a record crop of apples", "forty tonnes of potatoes", "a good barley crop despite the dry spring", "twelve hundred litres of honey"]}, claim=1.1),
        T("herd", "grew the herd to {n} animals", m({"c.animal_care_husbandry": 1}, {"c.animal_care_husbandry": 1}, {"c.food_purchasing": 1}, {"c.agri_forestry_fishing_work": 1}), ("yearly", .2), .4, "log", logsrc="herd-register", slots={"n": ["sixty", "ninety", "a hundred and forty"]}),
        T("organic", "was certified {what}", m({"c.horticulture_farming": 1}, {"c.environmental_stewardship": .6, "c.horticulture_farming": .4}, {"c.environmental_stewardship": 1}, {"c.agri_forestry_fishing_work": 1}), ("once", .3, .9, .7), .4, "formal", "certification-register", slots={"what": ["organic", "free-range", "pasture-fed"]}, claim=1.5),
        T("farm_shop", "opened a farm shop", m({"c.retail_work": 1}, {"c.food_purchasing": .6, "c.retail_shopping": .4}, {"c.neighbours_community": 1}, {"c.agri_forestry_fishing_work": 1}), ("once", .3, .8, .6), .35, "inf", claim=1.4),
        T("apprentice", "trained {n} apprentices", m({"c.vocational_training": 1}, {"c.agri_forestry_fishing_work": .6, "c.vocational_training": .4}, {"c.vocational_training": 1}, {"c.agri_forestry_fishing_work": 1}), ("yearly", .15), .35, "formal", "training-record", slots={"n": ["one", "two", "three"]}),
        T("runoff", "had a slurry runoff into {what}", m({"c.environmental_harm": 1}, {"c.environmental_harm": .6, "c.animal_care_husbandry": .4}, {"c.environmental_stewardship": 1}, {"c.agri_forestry_fishing_work": 1}), ("yearly", "harm"), .3, "formal", "environment-agency-report", slots={"what": ["a stream", "a drainage ditch", "a neighbour's field"]}, pattern="harm", harm=2, claim=.1,
          options=(("emptied the tank in time", 0), ("hired a contractor", 1), ("left it a week", 2))),
    ],
    "clinic": [
        T("opening", "opened as a family practice", m({"c.healthcare_work": 1}, {"c.medical_care": .6, "c.preventive_health": .4}, {"c.physical_health": 1}, {"c.medical_care": 1}), ("once", 0, .05, 1.0), .6, "inf", claim=1.4),
        T("patients", "saw about {n} patients a month", m({"c.medical_care": 1}, {"c.medical_care": .6, "c.physical_health": .4}, {"c.physical_health": 1}, {"c.medical_care": 1}), ("yearly", .5), .6, "log", logsrc="ehr-log", slots={"n": ["900", "1,500", "2,400"]}, claim=1.1),
        T("accredit", "was accredited after an inspection", m({"c.healthcare_work": 1}, {"c.medical_care": .5, "c.occupational_safety": .5}, {"c.physical_health": 1}, {"c.medical_care": 1}), ("yearly", .2), .4, "formal", "regulator-inspection", claim=1.5),
        T("vaccination_drive", "ran a {what} drive", m({"c.preventive_health": 1}, {"c.preventive_health": 1}, {"c.public_health_science": 1}, {"c.medical_care": 1}), ("yearly", .2), .5, "log", logsrc="ehr-log", slots={"what": ["flu vaccination", "childhood vaccination catch-up", "blood pressure screening"]}, claim=1.3),
        T("staff_training", "trained staff in {what}", m({"c.vocational_training": 1}, {"c.healthcare_work": .6, "c.preventive_health": .4}, {"c.vocational_training": 1}, {"c.medical_care": 1}), ("yearly", .2), .3, "formal", "training-record", slots={"what": ["resuscitation", "mental health first aid", "infection control"]}),
        T("misdiagnosis", "had an incident where {what}", m({"c.negligence_recklessness": 1}, {"c.medical_care": .5, "c.negligence_recklessness": .5}, {"c.physical_health": 1}, {"c.medical_care": 1}), ("yearly", "harm"), .35, "formal", "regulator-report", slots={"what": ["a referral was delayed", "a prescription was wrong", "a result was missed"]}, pattern="harm", harm=2, claim=.1,
          options=(("double-checked the record", 0), ("asked a colleague to review", 1), ("went with the first reading", 2))),
    ],
    "sports_club": [
        T("opening", "started with {n} members", m({"c.sport_participation": 1}, {"c.sport_participation": .6, "c.community_groups": .4}, {"c.neighbours_community": 1}, {"c.sport_participation": 1}), ("once", 0, .05, 1.0), .45, "inf", slots={"n": ["twelve", "thirty", "forty"]}, claim=1.4),
        T("members", "grew to {n} members", m({"c.sport_participation": 1}, {"c.sport_participation": .5, "c.community_groups": .5}, {"c.exercise_fitness": 1}, {"c.sport_participation": 1}), ("yearly", .4), .45, "log", logsrc="membership-ledger", slots={"n": ["120", "250", "400"]}, claim=1.2),
        T("league", "won the {what}", m({"c.sport_participation": 1}, {"c.sport_participation": .6, "c.sport_spectating": .4}, {"c.sport_participation": 1}, {"c.sport_participation": 1}), ("yearly", .15), .45, "formal", "league-record", slots={"what": ["county league", "regional cup", "youth league", "promotion playoff"]}, claim=1.5),
        T("youth", "started a youth programme with {n} children", m({"c.children_play": 1}, {"c.children_play": .5, "c.sport_participation": .5}, {"c.exercise_fitness": 1}, {"c.sport_participation": 1}), ("once", .1, .7, .8), .5, "inf", slots={"n": ["twenty", "fifty", "eighty"]}, claim=1.4),
        T("ground", "renovated the {what}", m({"c.civil_engineering": 1}, {"c.home_repair_diy": .5, "c.sport_participation": .5}, {"c.neighbours_community": 1}, {"c.sport_participation": 1}), ("yearly", .1), .3, "inf", slots={"what": ["clubhouse", "pitch drainage", "changing rooms", "floodlights"]}),
        T("injury_incident", "had an injury caused by {what}", m({"c.accident_injury": 1}, {"c.accident_injury": .5, "c.negligence_recklessness": .5}, {"c.physical_health": 1}, {"c.sport_participation": 1}), ("yearly", "harm"), .3, "formal", "insurer-report", slots={"what": ["a waterlogged pitch", "a faulty goalpost", "an unlit car park"]}, pattern="harm", harm=2, claim=.1,
          options=(("cancelled the match", 0), ("moved to a safe pitch", 1), ("played on", 2))),
    ],
}
OT = {t[0].key: t[0] for ts in [COMMON, *KIND_TPL.values()] for t in ts}


def name_for(kind, R):
    a = pick(R, ["Copper", "Juniper", "Little", "Harbour", "Maple", "Foxglove", "Bramble", "Willow", "Lantern", "Saffron"])
    b = pick(R, ["Kettle", "Bean", "Table", "Oven", "Spoon", "Door", "Gate", "Field", "Lane", "Orchard"])
    place = pick(R, CITIES)
    return {"cafe": f"The {a} {b} Cafe", "charity": f"{place} {pick(R, ['Food Bank', 'Neighbours Trust', 'Open Doors', 'Community Pantry'])}",
            "software_firm": f"{a}{b} Software Ltd", "farm": f"{a} {b} Farm", "clinic": f"{place} Family Clinic",
            "sports_club": f"{place} {pick(R, ['Rovers', 'Wanderers', 'Athletic', 'United'])} Sports Club"}[kind]


@dataclass
class Org:
    id: str
    seed: int
    kind: str
    name: str
    founded: int
    as_of: str
    city: str
    country: str
    staff: int
    contact: dict
    events: list = field(default_factory=list)
    rows: list = field(default_factory=list)
    text: str = ""
    params: dict = field(default_factory=dict)

    @property
    def entity(self):
        return f"org:{self.id}"

    @property
    def truth_rows(self):
        return [r for r in self.rows if r["tier"] == "claimed"]

    def meta(self):
        return {"id": self.id, "entity": self.entity, "kind": "organisation", "org_kind": self.kind, "seed": self.seed, "generator_version": GENERATOR_VERSION,
                "name": self.name, "founded": self.founded, "as_of": self.as_of, "city": self.city, "country": self.country, "staff": self.staff,
                "contact": self.contact, "synthetic": True}


def generate_org(seed, kind="cafe", as_of="2026-11-24", oid=None, params=None):
    """One organisation: events, rows, a prospectus text. Deterministic in (seed, kind, as_of, params)."""
    if kind not in KINDS:
        raise ValueError(f"unknown organisation kind {kind!r}; known: {KINDS}")
    P = resolve(params)
    Q = {k: (params or {}).get(k, v.default) for k, v in ORG_PARAMS.items()}
    for k, v in (params or {}).items():
        if k in ORG_PARAMS and not ORG_PARAMS[k].low <= v <= ORG_PARAMS[k].high:
            raise ValueError(f"{k}={v!r} outside its range")
    oid = oid or f"o{seed:04d}"
    ao = parse_date(as_of)
    R = stream(seed, f"org-{kind}")
    name = name_for(kind, R)
    years = R.randint(6, 30)
    founded = ao.year - years
    city = pick(R, CITIES)
    country = pick(R, COUNTRIES)
    staff = R.choice([3, 5, 8, 12, 20, 35])
    contact = {"email": f"hello@{name.split()[0].lower().replace(chr(39), '')}.example.org", "phone": f"(415) 555-0{R.randint(100, 199)}",
               "address": f"{R.randint(1, 90)} {pick(R, STREETS)} Street, {city}"}
    org = Org(oid, seed, kind, name, founded, as_of, city, country, staff, contact, params=dict(params or {}))
    birth_mi, asof_mi = mi(founded, R.randint(1, 12)), mi(ao.year, ao.month)
    raw = []
    R_e = stream(seed, "org-events")
    for t, sched in [*COMMON, *KIND_TPL[kind]]:
        def add(age_years):
            i = birth_mi + int(round(age_years * 12))
            if birth_mi <= i <= asof_mi:
                d = {"city": city}
                for slot, opts in t.slots.items():
                    d[slot] = pick(R_e, opts)
                raw.append({"tpl": t, "mi": i, "detail": d})
        life_years = (asof_mi - birth_mi) / 12
        if sched == "start":
            add(0.0)
        elif sched[0] == "once":
            if R_e.random() < sched[3]:
                add(life_years * R_e.uniform(sched[1], sched[2]))
        else:
            p = Q["org_p_harm_per_year"] if sched[1] == "harm" else sched[1]
            for y in range(int(life_years) + 1):
                if y >= 1 and R_e.random() < p:
                    add(y + R_e.random())
    if not any(e["tpl"].logsrc and e["tpl"].pattern != "harm" for e in raw):  # a draw with no logged activity: its main log is kept once
        t, _ = next(x for x in KIND_TPL[kind] if x[0].logsrc and x[0].pattern != "harm")
        raw.append({"tpl": t, "mi": max(birth_mi, asof_mi - 6), "detail": {"city": city, **{k: o[0] for k, o in t.slots.items()}}})
    raw.sort(key=lambda e: (e["mi"], e["tpl"].key))
    R_t = stream(seed, "org-tiers")
    log_srcs = sorted({e["tpl"].logsrc for e in raw if e["tpl"].logsrc})
    adopt = {src: R_t.random() < Q["org_p_logged"] for src in log_srcs}
    main = next(e["tpl"].logsrc for e in raw if e["tpl"].logsrc and e["tpl"].pattern != "harm")
    adopt[main] = True  # the organisation keeps at least its main log
    decided = []
    for e in raw:
        t = e["tpl"]
        tiers = []
        if t.src and R_t.random() < Q["org_p_attested"]:
            tiers.append("attested")
        if t.logsrc and adopt.get(t.logsrc) and R_t.random() < P["p_log_capture"]:
            tiers.append("measured")
        if R_t.random() < clip(Q["org_claim_mention"] * t.claim, 0, 0.97):
            tiers.append("claimed")
        if not tiers and t.anchor:
            tiers.append("attested")
        decided.append(tiers)
    pool = [n for n, ts in enumerate(decided) if "claimed" not in ts and raw[n]["tpl"].pattern != "harm"]
    R_t.shuffle(pool)
    while sum("claimed" in ts for ts in decided) < 6 and pool:
        decided[pool.pop()].append("claimed")
    if not any("measured" in ts for ts in decided):
        n = next(n for n, e in enumerate(raw) if e["tpl"].logsrc == main and e["tpl"].pattern != "harm")
        decided[n].append("measured")
    # --- prospectus text ---
    lines = [f"{org.name}", f"Prospectus of {org.name}, {city}, {country}", f"Contact: {contact['email']} | {contact['phone']} | {contact['address']}", "",
             "About us", f"{org.name} is a small {kind.replace('_', ' ')} with about {staff} people, founded in {founded}.", "", "Our history"]
    where = {}
    events = []
    for n, (e, ts) in enumerate(zip(raw, decided)):
        t = e["tpl"]
        phrase = fmt(t.d, e["detail"])
        ev = {"id": f"{oid}-e{n:03d}", "key": t.key, "area": "org", "valid_time": ym(e["mi"]), "label": phrase, "phrase": None,
              "detail": {k: v for k, v in e["detail"].items() if isinstance(v, (str, int, float, bool))}, "tiers": [], "rows": []}
        events.append(ev)
        if "claimed" in ts and t.pattern != "harm":
            lines.append(f"In {e['mi'] // 12} the {kind.replace('_', ' ')} {phrase}.")
            where[n] = len(lines)
            ev["phrase"] = phrase
        elif "claimed" in ts:  # a confession in the risk section, later
            pass
    lines += ["", "Risks and incidents"]
    for n, (e, ts) in enumerate(zip(raw, decided)):
        if "claimed" in ts and raw[n]["tpl"].pattern == "harm":
            phrase = events[n]["label"]
            lines.append(f"In {e['mi'] // 12} we {phrase}.")
            where[n] = len(lines)
            events[n]["phrase"] = phrase
    if lines[-1] == "Risks and incidents":
        lines.append("We have had no recorded incident that we consider material.")
    lines += ["", "Governance", f"The organisation is run by a small board and reports to its {'members' if kind in ('charity', 'sports_club') else 'owners'} once a year."]
    org.text = "\n".join(lines) + "\n"
    # --- rows ---
    R_r = stream(seed, "org-rows")
    ctx = {"jurisdiction": country}
    rows = []
    for n, (e, ts) in enumerate(zip(raw, decided)):
        t = e["tpl"]
        mem = _membership_weights(t, e["detail"])
        harm = t.pattern == "harm"
        mag = t.mag * R_r.uniform(0.8, 1.2)
        years_ago = (asof_mi - e["mi"]) / 12
        for tier in ("claimed", "attested", "measured"):
            if tier not in ts:
                continue
            row = {"entity": org.entity, "relation": "causal", "memberships": mem, "basemap_version": BASEMAP_VERSION, "channel": "negative" if harm else "positive",
                   "sign": -1 if harm else 1, "entity_kind": "organisation", "revoked": False}
            if harm:
                row["option_set"] = [{"alternative": a, "harm": h} for a, h in t.options]
            if tier == "claimed":
                vt = str(e["mi"] // 12)
                row.update(tier="claimed", magnitude=round(mag * 1.1, 4), valid_time=vt, record_time=ao.isoformat(),
                           confidence=_conf(R_r, P, "claimed", "conf_claimed", years_ago), provenance={"source": f"prospectus:{oid}", "span": f"L{where[n]}"})
            elif tier == "attested":
                rt_i = min(e["mi"] + R_r.randint(0, 6), asof_mi)
                vt = _day(R_r, e["mi"], ao).isoformat()
                row.update(tier="attested", magnitude=round(mag, 4), valid_time=vt, record_time=ym(rt_i) if rt_i > e["mi"] else vt, context=ctx,
                           confidence=_conf(R_r, P, "attested", "conf_attested"), provenance={"source": f"{t.src}:{oid}", "span": f"ev:{events[n]['id']}"})
            else:
                day = _day(R_r, e["mi"], ao)
                row.update(tier="measured", magnitude=round(mag * R_r.uniform(0.9, 1.1), 4), valid_time=day.isoformat(), record_time=f"{day.isoformat()}T12:00Z",
                           confidence=_conf(R_r, P, "measured", "conf_measured"), provenance={"source": f"{t.logsrc}:{oid}", "span": f"ev:{events[n]['id']}"})
            events[n]["rows"].append(len(rows))
            events[n]["tiers"].append(tier)
            rows.append(row)
    org.events, org.rows = events, rows
    return org
