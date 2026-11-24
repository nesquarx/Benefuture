"""Public-figure fetcher prototype: Wikidata (CC0) statements about deceased or clearly public people become
attested-tier evidence rows mapped to the seed domains by label matching.

Statements used: occupation (P106), educated at (P69), position held (P39), award received (P166), notable work
(P800), employer (P108), member of (P463), with start (P580), end (P582) and point-in-time (P585) qualifiers, and the
work's publication date (P577) or inception (P571). Spouses and children are left out on purpose (they are often
private persons). A statement with no date is dated from the person's earliest dated statement and flagged
(`date: inferred`); a statement whose label matches no domain keeps a property-level fallback domain and is flagged
(`mapped: false`) so a later pass can map it. A referenced statement carries more confidence than an unreferenced one.

Network access goes through an injected `fetch(url) -> dict`; `RecordingFetcher` stores trimmed responses so a figure
can be replayed offline with `FixtureFetcher`. Requests carry a generic client name, never personal details.
"""
import hashlib
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://www.wikidata.org/w/api.php"
USER_AGENT = "lifeimage-prototype/0.1 (research prototype; open-data fetcher)"
DEFAULT_RETRIEVED = "2026-11-24"
USED_PROPS = ("P31", "P569", "P570", "P106", "P69", "P39", "P166", "P800", "P108", "P463", "P577", "P571")
STATEMENT_PROPS = {"P106": "occupation", "P69": "educated at", "P39": "position held", "P166": "award received", "P800": "notable work",
                   "P108": "employer", "P463": "member of"}
FALLBACK = {"P106": "s.work", "P69": "s.learning", "P39": "s.public", "P166": "s.work", "P800": "s.work", "P108": "s.work", "P463": "s.social"}
MAGNITUDE = {"P106": .5, "P69": .6, "P39": .8, "P166": .7, "P800": .8, "P108": .5, "P463": .3}
RELATION = {"P106": "causal", "P69": "impacted", "P39": "causal", "P166": "causal", "P800": "causal", "P108": "causal", "P463": "structural"}
CONF_REFERENCED, CONF_UNREFERENCED, CONF_INFERRED_FACTOR = 0.85, 0.6, 0.85


# ---------- fetching ----------
def http_fetch(url, retries=7, pause=1.0):
    """GET a JSON document politely (generic client name, back-off on 429 and 5xx)."""
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=40) as r:
                data = json.loads(r.read().decode("utf-8"))
            time.sleep(pause)
            return data
        except urllib.error.HTTPError as e:
            last = e
            if e.code not in (429, 500, 502, 503, 504):
                raise
            wait = e.headers.get("Retry-After") if e.headers else None
            time.sleep(min(90, float(wait)) if wait and wait.isdigit() else min(60, 2 ** attempt * 3))
        except (urllib.error.URLError, TimeoutError) as e:
            last = e
            time.sleep(2 ** attempt)
    raise last


def _key(url):
    return hashlib.sha256(url.encode()).hexdigest()[:20]


def trim(response):
    """A wbgetentities response reduced to what this module reads: English labels and descriptions, the used claims."""
    if "entities" not in response:
        return response
    out = {"entities": {}, "success": response.get("success", 1)}
    for qid, e in response["entities"].items():
        claims = {p: cs for p, cs in e.get("claims", {}).items() if p in USED_PROPS}
        slim = {}
        for p, cs in claims.items():
            slim[p] = [{"mainsnak": {k: c["mainsnak"].get(k) for k in ("snaktype", "property", "datavalue") if c["mainsnak"].get(k) is not None},
                        "qualifiers": {qp: [{k: q.get(k) for k in ("snaktype", "property", "datavalue") if q.get(k) is not None} for q in qs]
                                       for qp, qs in c.get("qualifiers", {}).items() if qp in ("P580", "P582", "P585")},
                        "rank": c.get("rank", "normal"), "id": c.get("id"), **({"references": [{"snaks": {}}]} if c.get("references") else {})} for c in cs]
        out["entities"][qid] = {"id": qid, "labels": {k: v for k, v in e.get("labels", {}).items() if k in ("en", "mul")},
                                "descriptions": {k: v for k, v in e.get("descriptions", {}).items() if k == "en"}, "claims": slim}
    return out


class RecordingFetcher:
    """Wraps a live `fetch`, saving each trimmed response under its URL's hash (a recorded fixture) and reusing it."""

    def __init__(self, fetch, directory):
        self.fetch, self.dir = fetch, Path(directory)
        self.dir.mkdir(parents=True, exist_ok=True)

    def __call__(self, url):
        f = self.dir / f"{_key(url)}.json"
        if f.exists():
            return json.loads(f.read_text(encoding="utf-8"))["response"]
        resp = trim(self.fetch(url))
        f.write_text(json.dumps({"url": url, "response": resp}, sort_keys=True, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        return resp


class FixtureFetcher:
    """Replays recorded responses; a URL that was never recorded raises KeyError (no network is ever tried)."""

    def __init__(self, directory):
        self.dir = Path(directory)

    def __call__(self, url):
        f = self.dir / f"{_key(url)}.json"
        if not f.exists():
            raise KeyError(f"no recorded fixture for {url}")
        return json.loads(f.read_text(encoding="utf-8"))["response"]


def entities_url(ids):
    return f"{API}?action=wbgetentities&ids={'|'.join(ids)}&props=labels|descriptions|claims&languages=en|mul&format=json"


def search_url(name):
    return f"{API}?action=wbsearchentities&search={urllib.parse.quote(name)}&language=en&type=item&limit=5&format=json"


def search(name, fetch):
    """[(qid, label, description)] candidates for a name."""
    return [(h["id"], h.get("label", ""), h.get("description", "")) for h in fetch(search_url(name)).get("search", [])]


def get_entities(ids, fetch):
    out = {}
    ids = sorted(set(ids))
    for i in range(0, len(ids), 50):
        out.update(fetch(entities_url(ids[i:i + 50]))["entities"])
    return out


# ---------- reading statements ----------
def _label(e):
    """English label, else the multilingual one (Wikidata's `mul`, used for names the same in every language), else the id."""
    labels = e.get("labels", {})
    return (labels.get("en") or labels.get("mul") or {}).get("value", e.get("id", ""))


def _time(snak):
    """'YYYY', 'YYYY-MM' or 'YYYY-MM-DD' from a time snak by its precision; None for no value or years before 1."""
    if not snak or snak.get("snaktype", "value") != "value" or "datavalue" not in snak:
        return None
    v = snak["datavalue"]["value"]
    m = re.match(r"^([+-])(\d{1,})-(\d{2})-(\d{2})T", v["time"])
    if not m or m.group(1) == "-" or int(m.group(2)) < 1:
        return None
    y, mo, d = f"{int(m.group(2)):04d}", m.group(3), m.group(4)
    p = v.get("precision", 9)
    if p >= 11 and mo != "00" and d != "00":
        return f"{y}-{mo}-{d}"
    if p == 10 and mo != "00":
        return f"{y}-{mo}"
    return y


def _target(snak):
    if not snak or snak.get("snaktype", "value") != "value" or "datavalue" not in snak:
        return None
    v = snak["datavalue"]
    return v["value"]["id"] if v["type"] == "wikibase-entityid" else None


def _qual(claim, prop):
    for q in claim.get("qualifiers", {}).get(prop, []):
        t = _time(q)
        if t:
            return t
    return None


def _first_time(entity, prop):
    for c in entity.get("claims", {}).get(prop, []):
        t = _time(c["mainsnak"])
        if t:
            return t
    return None


def build_figure(qid, fetch, retrieved=DEFAULT_RETRIEVED, require_public=False, public_reason=None):
    """The figure's statements with labels and dates. With `require_public`, a person with no death date needs a
    stated `public_reason` (clearly public figures only)."""
    ents = get_entities([qid], fetch)
    if qid not in ents:
        raise ValueError(f"{qid} not found")
    e = ents[qid]
    claims = e.get("claims", {})
    if "Q5" not in {_target(c["mainsnak"]) for c in claims.get("P31", [])}:
        raise ValueError(f"{qid} is not a human")
    death = _first_time(e, "P570")
    if require_public and not death and not public_reason:
        raise ValueError(f"{qid} has no death date and no stated public reason: refused (public figures only)")
    raw = []
    for prop in STATEMENT_PROPS:
        for c in claims.get(prop, []):
            if c.get("rank") == "deprecated":
                continue
            t = _target(c["mainsnak"])
            if t:
                raw.append((prop, t, c))
    targets = ents.copy()
    targets.update(get_entities([t for _, t, _ in raw if t not in targets], fetch))
    inst_ids = [_target(c["mainsnak"]) for _, t, _ in raw for c in targets.get(t, {}).get("claims", {}).get("P31", [])]
    inst = get_entities([i for i in inst_ids if i and i not in targets], fetch) if inst_ids else {}
    statements = []
    for prop, t, c in raw:
        te = targets.get(t, {"id": t})
        s = {"property": prop, "kind": STATEMENT_PROPS[prop], "qid": t, "label": _label(te), "start": _qual(c, "P580"), "end": _qual(c, "P582"),
             "point": _qual(c, "P585"), "referenced": bool(c.get("references")),
             "instance_of": [_label({**inst.get(_target(x["mainsnak"]), targets.get(_target(x["mainsnak"]), {"id": _target(x["mainsnak"])}))}) for x in te.get("claims", {}).get("P31", []) if _target(x["mainsnak"])]}
        if prop == "P800":
            s["point"] = s["point"] or _first_time(te, "P577") or _first_time(te, "P571")
        statements.append(s)
    return {"qid": qid, "label": _label(e), "description": (e.get("descriptions", {}).get("en") or {}).get("value", ""), "birth": _first_time(e, "P569"),
            "death": death, "public_reason": public_reason, "retrieved": retrieved, "statements": statements}


# ---------- label matching ----------
def _r(pattern, *doms, props=None):
    ws = [1.0 / len(doms)] * len(doms)
    return re.compile(pattern, re.I), [(d, w) for d, w in zip(doms, ws)], props


INSTITUTION = ("P69", "P108", "P463")
RULES = [
    # prizes first: their labels name the field
    _r(r"nobel prize in physics|physics prize", "c.physics", props=("P166",)),
    _r(r"nobel prize in chemistry", "c.chemistry", props=("P166",)),
    _r(r"physiology or medicine|medicine prize", "c.medicine_science", props=("P166",)),
    _r(r"nobel prize in literature|literature prize|booker|pulitzer prize for fiction", "c.creative_writing", props=("P166",)),
    _r(r"peace prize", "c.human_rights", props=("P166",)),
    _r(r"economic sciences|economics prize", "c.economics", props=("P166",)),
    _r(r"olympic|medal of honor|medal for|world champion", "c.sport_participation", props=("P166",)),
    _r(r"grammy|academy award for best (?:actor|actress|film|director)|oscar", "c.film_tv_video", props=("P166",)),
    _r(r"fellow of the royal society|royal society", "c.science_research_work", props=("P166", "P463")),
    _r(r"presidential medal of freedom|order of|legion of honour|knight|dame|honorary doctorate|honorary degree", "c.public_administration", props=("P166",)),
    # institutions
    _r(r"university|college|institute of technology|polytechnic|sorbonne|conservatoire|conservatory", "c.higher_education", props=INSTITUTION),
    _r(r"hospital|clinic|infirmary|health service", "c.medical_care", props=INSTITUTION),
    _r(r"academy of sciences|national academy|royal society|learned society|institute|laborator|observatory|research", "c.science_research_work", props=INSTITUTION),
    _r(r"school|gymnasium|lyceum|lycée|grammar|seminary|academy", "c.school_education", props=("P69",)),
    _r(r"church|mosque|temple|synagogue|diocese|cathedral|abbey|monastery|congregation", "c.religious_community", props=INSTITUTION),
    _r(r"orchestra|choir|opera house|philharmonic", "c.music_making", props=INSTITUTION),
    _r(r"theat(?:re|er)|dance company|ballet", "c.performing_arts", props=INSTITUTION),
    _r(r"museum|gallery", "c.cultural_visits", props=INSTITUTION),
    _r(r"party|congress|parliament|senate|assembly|government|ministry|council|cabinet|committee|union of", "c.political_participation", props=INSTITUTION),
    _r(r"army|navy|air force|regiment|military", "c.military_defence", props=INSTITUTION),
    _r(r"bank|exchange|treasury", "c.banking_payments", props=INSTITUTION),
    _r(r"film|studio|pictures|broadcasting|television", "c.film_tv_video", props=INSTITUTION),
    _r(r"foundation|charity|trust|society for|red cross|nongovernmental|ngo|movement|league|association|club", "c.civil_society_advocacy", props=INSTITUTION),
    _r(r"newspaper|magazine|press|publishing", "c.media_publishing", props=INSTITUTION),
    # positions
    _r(r"president|prime minister|premier|minister|chancellor|senator|congress(?:man|woman)|member of (?:parliament|the)|mp\b|mayor|governor|secretary of state|ambassador|diplomat|councillor|speaker", "c.public_administration", "c.political_participation", props=("P39",)),
    _r(r"professor|chair of|lecturer|dean|rector|fellow", "c.higher_education", props=("P39",)),
    _r(r"bishop|pope|archbishop|imam|rabbi|priest|abbot|cardinal|minister of religion", "c.religious_community", props=("P39",)),
    _r(r"judge|justice|chief justice|magistrate", "c.legal_system", props=("P39",)),
    _r(r"chairman|chair|director|chief executive|ceo|board|head of|leader|founder|secretary", "c.management_executive", props=("P39",)),
    # works by what they are
    _r(r"painting|drawing|sculpture|fresco|mural|print\b|portrait|self-portrait|artwork|work of art", "c.visual_arts", props=("P800",)),
    _r(r"symphony|sonata|concerto|cantata|opera|oratorio|mass in|passion|fugue|suite|variations|musical composition|song|album|single|ballet", "c.music_making", props=("P800",)),
    _r(r"scholarly article|scientific article|academic journal article|journal article|thesis|scientific publication|paper", "c.science_research_work", props=("P800",)),
    _r(r"film|motion picture|television", "c.film_tv_video", props=("P800",)),
    _r(r"play\b|drama|musical theatre", "c.performing_arts", props=("P800",)),
    _r(r"novel|book|poem|poetry|short story|essay|autobiography|memoir|collection of|literary work|written work|treatise|manuscript|non-fiction", "c.creative_writing", props=("P800",)),
    _r(r"invention|machine|engine|device|patent|software|algorithm", "c.maker_tinkering", props=("P800",)),
    # occupations
    _r(r"physicist|physics", "c.physics", props=("P106",)),
    _r(r"chemist|chemistry", "c.chemistry", props=("P106",)),
    _r(r"biologist|geneticist|botanist|zoologist|naturalist|biochemist|physiologist|microbiologist|life scien", "c.life_sciences", props=("P106",)),
    _r(r"mathematician|mathematics|number theor", "c.mathematics", props=("P106",)),
    _r(r"statistician|statistics|data scientist", "c.statistics_data", props=("P106",)),
    _r(r"astronom|astrophysic|cosmolog", "c.astronomy_space", props=("P106",)),
    _r(r"astronaut|cosmonaut", "c.astronomy_space", props=("P106",)),
    _r(r"geolog|geograph|earth scien|meteorolog", "c.earth_sciences", props=("P106",)),
    _r(r"economist", "c.economics", props=("P106",)),
    _r(r"psycholog|psychiatr", "c.psychology", props=("P106",)),
    _r(r"sociolog", "c.sociology", props=("P106",)),
    _r(r"anthropolog|ethnolog|archaeolog", "c.anthropology", props=("P106",)),
    _r(r"historian", "c.history_science", props=("P106",)),
    _r(r"philosoph|theologian", "c.philosophical_inquiry", props=("P106",)),
    _r(r"linguist|philolog|translator|lexicograph", "c.linguistics_literature", props=("P106",)),
    _r(r"computer scientist|programmer|software|computer", "c.software_development", "c.computer_science", props=("P106",)),
    _r(r"inventor", "c.maker_tinkering", "c.mechanical_engineering", props=("P106",)),
    _r(r"civil engineer|architect(?:ural)? engineer", "c.civil_engineering", props=("P106",)),
    _r(r"electrical engineer", "c.electrical_engineering", props=("P106",)),
    _r(r"engineer", "c.mechanical_engineering", props=("P106",)),
    _r(r"architect", "c.visual_arts", "c.civil_engineering", props=("P106",)),
    _r(r"physician|doctor|surgeon|medical|pharmacist|midwife|dentist", "c.healthcare_work", "c.medicine_science", props=("P106",)),
    _r(r"nurse|nursing", "c.healthcare_work", props=("P106",)),
    _r(r"social worker|humanitarian|philanthropist|charity", "c.therapy_social_work", "c.charity_giving", props=("P106",)),
    _r(r"environmentalist|conservationist|ecolog|forester", "c.environmental_stewardship", props=("P106",)),
    _r(r"activist|suffragist|abolitionist|civil rights|human rights|campaigner|reformer|feminist", "c.civil_society_advocacy", "c.human_rights", props=("P106",)),
    _r(r"trade unionist|labour leader|union leader", "c.labour_organising", props=("P106",)),
    _r(r"politician|statesm[ae]n|president|prime minister|diplomat|ambassador|revolutionary|head of state|monarch|ruler", "c.public_administration", "c.political_participation", props=("P106",)),
    _r(r"lawyer|attorney|barrister|solicitor|jurist|legal", "c.legal_profession", props=("P106",)),
    _r(r"judge", "c.legal_system", props=("P106",)),
    _r(r"composer|songwriter|conductor|musician|singer|pianist|violinist|organist|guitarist|drummer|cellist|vocalist|music", "c.music_making", props=("P106",)),
    _r(r"painter|sculptor|illustrator|artist|photographer|printmaker|draughtsman|designer", "c.visual_arts", props=("P106",)),
    _r(r"journalist|reporter|correspondent|columnist", "c.journalism", props=("P106",)),
    _r(r"editor|publisher", "c.media_publishing", props=("P106",)),
    _r(r"writer|novelist|poet|author|playwright|essayist|memoirist|dramatist|screenwriter", "c.creative_writing", props=("P106",)),
    _r(r"film director|film producer|cinematograph|filmmaker", "c.film_tv_video", props=("P106",)),
    _r(r"actor|actress|dancer|comedian|performer|theatre", "c.performing_arts", "c.film_tv_video", props=("P106",)),
    _r(r"athlete|sprinter|runner|footballer|boxer|swimmer|olympic|sportsperson|cyclist|gymnast|long jumper|jumper|tennis|player|coach", "c.sport_participation", props=("P106",)),
    _r(r"soldier|military|general\b|admiral|officer|commander|warrior|army|navy", "c.military_defence", props=("P106",)),
    _r(r"pilot|aviator", "c.air_travel", props=("P106",)),
    _r(r"explorer|traveller|navigator|mountaineer|adventurer", "c.tourism_travel", "c.outdoor_recreation", props=("P106",)),
    _r(r"priest|monk|nun|cleric|imam|rabbi|pastor|preacher|missionary|mystic|saint|religious", "c.religious_community", props=("P106",)),
    _r(r"businessperson|entrepreneur|industrialist|merchant|business|tycoon|manufactur", "c.entrepreneurship", props=("P106",)),
    _r(r"banker|financier|investor|accountant", "c.finance_accounting", props=("P106",)),
    _r(r"farmer|agronom|gardener|horticultur", "c.horticulture_farming", props=("P106",)),
    _r(r"chef|cook|baker", "c.cooking", props=("P106",)),
    _r(r"university teacher|professor|lecturer|academic", "c.higher_education", "c.teaching_profession", props=("P106",)),
    _r(r"teacher|educator|pedagog|tutor", "c.teaching_profession", props=("P106",)),
    _r(r"craftsperson|craftsman|carpenter|blacksmith|tailor|weaver", "c.skilled_trades", props=("P106",)),
]


def map_domain(prop, label, instance_labels, domain_ids):
    """([(domain, weight)], mapped): weights sum to 1. The first rule whose pattern matches the label and the work's
    instance-of labels (and whose property list admits `prop`) wins; no match returns the property's fallback domain
    and mapped=False. Rules naming a domain not in `domain_ids` are skipped."""
    text = " ; ".join([label, *instance_labels])
    for rx, doms, props in RULES:
        if props and prop not in props:
            continue
        if rx.search(text) and all(d in domain_ids for d, _ in doms):
            return list(doms), True
    return [(FALLBACK[prop], 1.0)], False


# ---------- rows ----------
def _memberships(prop, doms):
    ds = {d: w for d, w in doms}
    layout = {"P106": ("form", "content"), "P69": ("content", "setting"), "P39": ("form", "content"), "P166": ("content", "outcome"),
              "P800": ("form", "content", "outcome"), "P108": ("setting", "content"), "P463": ("setting", "content")}[prop]
    return [{"domain": d, "rel": rel, "weight": round(w, 6)} for rel in layout for d, w in ds.items()]


def to_rows(figure, domain_ids, basemap_version="0.0.0-draft"):
    """(rows, trace): contract rows (attested tier) and an aligned trace of how each was made (property, label, qid,
    mapped, fallback, date stated or inferred)."""
    from ..generators.common import padded  # local import: the sources package stays importable alone
    qid, retrieved = figure["qid"], figure["retrieved"]
    dated = []
    for s in figure["statements"]:
        d = s["point"] or s["start"] or s["end"]
        if d:
            dated.append(d)
    earliest = min(dated, key=padded) if dated else None
    rows, trace = [], []
    for s in figure["statements"]:
        d = s["point"] or s["start"] or s["end"]
        how = "stated"
        if not d:
            d, how = earliest, "inferred"
        if d is None or padded(d) > padded(retrieved):
            continue  # no date to anchor the row, or a date in the future
        doms, mapped = map_domain(s["property"], s["label"], s.get("instance_of", []), domain_ids)
        conf = CONF_REFERENCED if s["referenced"] else CONF_UNREFERENCED
        if how == "inferred":
            conf *= CONF_INFERRED_FACTOR
        rows.append({"entity": f"wikidata:{qid}", "relation": RELATION[s["property"]], "memberships": _memberships(s["property"], doms),
                     "basemap_version": basemap_version, "channel": "positive", "sign": 1, "magnitude": MAGNITUDE[s["property"]], "valid_time": d,
                     "record_time": retrieved, "entity_kind": "person", "tier": "attested", "confidence": round(conf, 3),
                     "provenance": {"source": f"wikidata:{qid}", "span": f"{s['property']}>{s['qid']}"}, "revoked": False})
        trace.append({"property": s["property"], "kind": s["kind"], "label": s["label"], "qid": s["qid"], "mapped": mapped,
                      "fallback": not mapped, "date": how, "referenced": s["referenced"], "instance_of": s.get("instance_of", [])})
    return rows, trace
