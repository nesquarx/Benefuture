"""Fine candidates for the coarse fields that have no fine child, from openly licensed trees (LI.19, LI.54, LI.56).

Each source gives groups, not leaves: the top one or two levels below a root chosen for a field, ranked by how well known
the class is (Wikidata sitelinks, Disease Ontology and MONDO descendant counts), at most `FIELD_CAP` per field and source
(the covered fields have 5.2 fine children on average; a cap of 8 keeps a field from outweighing its neighbours).
Every row carries `target`, the empty field its root was chosen for: a trace for coverage, never a parent (the parent
task decides that). Rows are class names of classifications, never individual records.
"""
import re
from collections import defaultdict

FIELD_CAP = 8
MIN_SITELINKS = 8  # a class known in fewer than eight Wikipedias is a leaf term or a local one

# empty coarse field -> Wikidata roots (QIDs resolved by exact English label, 2026-11-25); subclasses to depth 2
WIKIDATA_ROOTS = {
    "theft_property_crime": ["Q2727213", "Q857984", "Q329425", "Q53706", "Q6160"],
    "violence_assault": ["Q1520311", "Q365680", "Q132821"],
    "sexual_violence": ["Q5801919", "Q43414", "Q47092"],
    "fraud_deception": ["Q28813", "Q7023752", "Q1332286"],
    "corruption": ["Q366", "Q187436"],
    "cybercrime": ["Q29137", "Q4071928", "Q14001"],
    "online_harassment": ["Q494348"],
    "bullying_harassment": ["Q240126", "Q3240539", "Q2273650", "Q751722"],
    "harassment_discrimination": ["Q653347", "Q169207", "Q8461", "Q93200"],
    "drug_crime": ["Q844924"],
    "negligence_recklessness": ["Q160070", "Q11640551"],
    "misinformation_defamation": ["Q191783", "Q189656", "Q13579947", "Q7281"],
    "extremism_terrorism": ["Q7283", "Q466439", "Q3399774"],
    "exploitation_trafficking": ["Q181784", "Q8463"],
    "academic_dishonesty": ["Q1348417", "Q164666"],
    "stalking_privacy": ["Q163942", "Q334401", "Q8354932"],
    "self_harm_suicide": ["Q10737"],
    "war_experience": ["Q198", "Q350604", "Q135010"],
    "domestic_abuse": ["Q156537"],
    "child_abuse_neglect": ["Q167191"],
    "medication_adherence": ["Q12140", "Q1761396"],
    "sexuality": ["Q154136", "Q17888", "Q2990606"],
    "disability_adaptation": ["Q12131", "Q688498", "Q555097"],
    "personal_appearance": ["Q327496", "Q131207", "Q3675172"],
    "parenting_adolescents": ["Q1217379"],
    "eldercare": ["Q437458", "Q6672123", "Q837142"],
    "partnership_romance": ["Q654810", "Q376596"],
    "marriage_cohabitation": ["Q49800", "Q8445"],
    "family_ties": ["Q171318", "Q8436"],
    "family_rituals": ["Q47223", "Q3001563"],
    "housing_search": ["Q1247867", "Q157171"],
    "friendship": ["Q491"],
    "neighbours_community": ["Q177634"],
    "conflict_interpersonal": ["Q180684", "Q467033"],
    "reconciliation": ["Q378529", "Q13197791"],
    "loneliness_isolation": ["Q223270", "Q1778765"],
    "reputation_gossip": ["Q877546", "Q854648", "Q878352"],
    "etiquette_norms": ["Q188907", "Q205665"],
    "cultural_identity": ["Q1368367", "Q1880695"],
    "youth_culture": ["Q8059289", "Q264965"],
    "inclusion_discrimination": ["Q169207", "Q3149923"],
    "voting_elections": ["Q40231", "Q189760"],
    "political_participation": ["Q2101513", "Q273120", "Q847301", "Q7278"],
    "civil_society_advocacy": ["Q2509280", "Q79913", "Q203764", "Q187117"],
    "labour_organising": ["Q208701", "Q178790", "Q49776"],
    "spirituality": ["Q168796", "Q108458", "Q341045"],
    "ethical_choice": ["Q192568", "Q538733", "Q48324"],
    "life_purpose": ["Q223675"],
    "rites_of_passage": ["Q1131696"],
    "video_gaming": ["Q659563", "Q300920", "Q7889"],
    "social_media": ["Q202833", "Q3220391", "Q6576792"],
    "festivals_events": ["Q132241", "Q288514", "Q182832"],
    "nightlife": ["Q1594437", "Q622425", "Q187456"],
    "restaurants_dining": ["Q11707", "Q41958"],
    "clothing_footwear": ["Q11460", "Q161928"],
    "saving_investing": ["Q4290", "Q156223", "Q100348459"],
    "borrowing_debt": ["Q189539", "Q3196867", "Q182076"],
    "insurance_risk": ["Q43183"],
    "income_earning": ["Q1527264", "Q1351807"],
    "gifts_exchange": ["Q184303", "Q484830", "Q2233575"],
    "online_commerce": ["Q484847", "Q3390477"],
    "reuse_repair": ["Q2144962"],
    "subscriptions_telecom": ["Q4054833", "Q3467747"],
    "poverty_scarcity": ["Q10294", "Q165947", "Q112206305"],
    "commuting": ["Q48442"],
    "public_transport": ["Q178512", "Q334166"],
    "road_safety": ["Q1147899", "Q9687"],
    "moving_relocation": ["Q2918584", "Q177626"],
    "border_migration_admin": ["Q170404", "Q131288"],
    "wildlife_conservation": ["Q766328", "Q20113959", "Q641498"],
    "environmental_stewardship": ["Q219416", "Q2855609", "Q132580"],
    "weather_climate_adaptation": ["Q260607"],
    "early_childhood_education": ["Q1472221", "Q1076052"],
    "exams_assessment": ["Q4530596", "Q2585724", "Q3244907"],
    "maker_tinkering": ["Q2947235", "Q26384"],
    "entrepreneurship": ["Q3908516", "Q129238", "Q1005490"],
    "employment_transition": ["Q282049", "Q41171"],
    "job_loss": ["Q1462531", "Q9213592", "Q41171"],
    "death_dying": ["Q4", "Q100159"],
    "bereavement": ["Q1026040", "Q750652"],
    "funeral_mourning": ["Q201676", "Q331055"],
    "serious_illness": ["Q12078"],
    "accident_injury": ["Q193078", "Q171558"],
    "disaster_experience": ["Q3839081", "Q8065"],
    "migration": ["Q177626", "Q131572", "Q131288"],
    "marriage_wedding": ["Q49836"],
    "divorce": ["Q93190"],
    "coming_of_age": ["Q681737"],
    "retirement": ["Q946865"],
    "identity_change": ["Q208099", "Q2343619"],
    "folk_belief": ["Q133182", "Q1043197", "Q1068640", "Q34362"],
    "birth_of_child": ["Q34581", "Q11995"],
    "pregnancy_birth": ["Q34581", "Q11995"],
}

SPARQL = "https://query.wikidata.org/sparql?format=json&query="
_QUERY = """SELECT ?c ?l ?n ?d ?k WHERE {{
  {{ BIND(wd:{root} AS ?c) BIND(0 AS ?k) }}
  UNION {{ ?c wdt:P279 wd:{root} . BIND(1 AS ?k) }}
  UNION {{ ?c wdt:P279/wdt:P279 wd:{root} . BIND(2 AS ?k) }}
  ?c wikibase:sitelinks ?n . ?c rdfs:label ?l . FILTER(lang(?l) = "en")
  OPTIONAL {{ ?c schema:description ?d . FILTER(lang(?d) = "en") }} }}"""


def wikidata_query(root):
    return _QUERY.format(root=root)


def _qid(binding):
    return binding["c"]["value"].rsplit("/", 1)[-1]


def wikidata_rows(bindings, field, root_label, depth_of, min_sitelinks=MIN_SITELINKS):
    """(rows, dropped): class rows of one root's SPARQL bindings, best depth per class kept; a name (a capital letter
    inside the label), an unlabelled class (the label is its own QID) and a class known in too few wikis are dropped,
    each with its reason."""
    rows, dropped, seen = [], [], set()
    for bd in sorted(bindings, key=lambda x: (-int(x["n"]["value"]), _qid(x))):
        qid, label, n = _qid(bd), bd["l"]["value"].strip(), int(bd["n"]["value"])
        if qid in seen:
            continue
        seen.add(qid)
        if re.fullmatch(r"[QP]\d+", label):
            dropped.append({"label": label, "reason": "no English label"})
        elif re.search(r"[A-Z]", label[1:]) and not label.isupper():
            dropped.append({"label": label, "reason": "proper name (capital letter inside)"})
        elif n < min_sitelinks:
            dropped.append({"label": label, "reason": f"fewer sitelinks than {min_sitelinks}"})
        else:
            rows.append({"code": qid, "label": label, "aliases": [], "description": (bd.get("d") or {}).get("value", ""),
                         "broader": root_label, "depth": depth_of.get(qid, 1), "sitelinks": n, "target": field})
    return rows, dropped


def cap_per_field(rows, cap=FIELD_CAP):
    """At most `cap` rows per target field, the best known first (sitelinks, then shallower, then label)."""
    by = defaultdict(list)
    for r in rows:
        by[r["target"]].append(r)
    out = []
    for t in sorted(by):
        out += sorted(by[t], key=lambda r: (-r.get("sitelinks", r.get("descendants", 0)), r.get("depth", 1), r["label"], r["code"]))[:cap]
    return out


def fetch_wikidata_gap(fetch, roots=WIKIDATA_ROOTS, cap=FIELD_CAP):
    """(rows, dropped, errors): per field, the union of its roots' classes (depth 0 to 2), capped. A root that fails is
    recorded in errors and the rest continue."""
    import urllib.parse
    rows, dropped, errors, cache = [], [], [], {}
    for field in sorted(roots):
        mine = []
        for root in roots[field]:
            if root not in cache:
                try:
                    bds = fetch(SPARQL + urllib.parse.quote(wikidata_query(root)))["results"]["bindings"]
                except Exception as e:  # noqa: BLE001 - recorded, never silent
                    errors.append({"root": root, "field": field, "error": f"{type(e).__name__}: {e}"[:200]})
                    cache[root] = None
                    continue
                cache[root] = bds
            if cache[root] is None:
                continue
            bds = cache[root]
            depth_of = {_qid(b): int(b["k"]["value"]) for b in sorted(bds, key=lambda b: -int(b["k"]["value"]))}
            label = next((b["l"]["value"] for b in bds if _qid(b) == root), root)
            got, drp = wikidata_rows(bds, field, label, depth_of)
            mine += [dict(r, broader="" if r["code"] == root else r["broader"]) for r in got]
            dropped += [dict(d, field=field) for d in drp]
        seen, uniq = set(), []
        for r in mine:
            if r["code"] not in seen:
                seen.add(r["code"])
                uniq.append(r)
        rows += cap_per_field(uniq, cap)
    return rows, dropped, errors


# ---------- OBO ontologies: Disease Ontology (CC0), MONDO (CC BY 4.0) ----------

def parse_obo(text):
    """{id: {name, parents, definition, synonyms}} of the non-obsolete [Term] stanzas."""
    terms, cur = {}, None
    for line in text.splitlines():
        if line.startswith("["):
            cur = {"parents": [], "synonyms": [], "definition": "", "obsolete": False} if line.strip() == "[Term]" else None
            continue
        if cur is None or ": " not in line:
            continue
        key, val = line.split(": ", 1)
        if key == "id":
            cur["id"] = val.strip()
        elif key == "name":
            cur["name"] = val.strip()
        elif key == "is_a":
            cur["parents"].append(val.split("!")[0].strip())
        elif key == "def":
            m = re.match(r'"(.*?)(?<!\\)"', val)
            cur["definition"] = m.group(1) if m else ""
        elif key == "synonym":
            m = re.match(r'"(.*?)(?<!\\)"\s+(EXACT|RELATED|NARROW|BROAD)', val)
            if m and m.group(2) == "EXACT":
                cur["synonyms"].append(m.group(1))
        elif key == "is_obsolete" and val.strip() == "true":
            cur["obsolete"] = True
        if "id" in cur and cur["id"] not in terms and "name" in cur:
            terms[cur["id"]] = cur
    return {i: t for i, t in terms.items() if not t["obsolete"]}


def obo_rows(terms, root_name, depth, field):
    """Descendants of the term named `root_name` down to `depth` (the root is the group's name, not a row), each with the
    count of its own descendants (how general it is)."""
    ids = [i for i, t in terms.items() if t["name"] == root_name]
    if not ids:
        raise ValueError(f"no term named {root_name!r}")
    kids = defaultdict(list)
    for i, t in terms.items():
        for p in t["parents"]:
            kids[p].append(i)

    def below(i, _unused=None):
        seen, stack = set(), [i]
        while stack:
            for k in kids[stack.pop()]:
                if k not in seen and k != i:
                    seen.add(k)
                    stack.append(k)
        return seen

    rows, level, seen = [], ids, set(ids)
    for d in range(1, depth + 1):
        nxt = []
        for p in level:
            for k in sorted(kids[p]):
                if k in seen:
                    continue
                seen.add(k)
                nxt.append(k)
                t = terms[k]
                rows.append({"code": k, "label": t["name"], "aliases": t["synonyms"][:5], "description": t["definition"][:300],
                             "broader": terms[p]["name"], "depth": d, "descendants": len(below(k)), "target": field})
        level = nxt
    return rows


# ---------- O*NET (CC BY 4.0): intermediate work activities picked by keyword ----------

ONET_KEYWORDS = {
    "entrepreneurship": [r"business or (?:organizational|marketing)", r"business plans", r"business strategies"],
    "saving_investing": [r"financial matters", r"financial transactions", r"manage budgets"],
    "employment_transition": [r"recruiting or hiring", r"\bcareer"],
    "labour_organising": [r"negotiate contracts", r"labor (?:union|relations|disputes)"],
}


def onet_rows(csv_text, keywords=ONET_KEYWORDS, cap=5):
    """Intermediate work activities (IWA) of the `gwas_to_iwas.csv` file whose names match a field's keywords; the broader
    class is the generalised work activity. A row per (field, activity), at most `cap` per field."""
    import csv
    import io
    out = defaultdict(list)
    for r in csv.DictReader(io.StringIO(csv_text)):
        name = r["IWA Element Name"].strip().rstrip(".")
        for field, pats in keywords.items():
            if any(re.search(p, name, re.I) for p in pats):
                out[field].append({"code": r["IWA Element ID"], "label": name, "aliases": [], "description": "",
                                   "broader": r["GWA Element Name"], "depth": 2, "target": field})
    return [x for f in sorted(out) for x in sorted(out[f], key=lambda x: x["code"])[:cap]]


DOID_ROOTS = {  # field -> [(term name, depth)]
    "serious_illness": [("cancer", 1), ("heart disease", 1), ("disease of anatomical entity", 1)],
    "disability_adaptation": [("sensory system disease", 2), ("musculoskeletal system disease", 1), ("intellectual disability", 1)],
    "sexuality": [("sexual dysfunction", 1)],
}
MONDO_ROOTS = {
    "accident_injury": [("injury", 2), ("poisoning", 1), ("burn", 1)],
    "pregnancy_birth": [("pregnancy disorder", 1), ("puerperal disorder", 1)],
    "birth_of_child": [("pregnancy disorder", 1), ("puerperal disorder", 1)],
    "sexuality": [("sexual disorder", 1)],
    "serious_illness": [("infectious disease", 1)],
}
OBO_CAP = 6
MIN_DESCENDANTS = 2  # a group has members of its own; a term with fewer is a leaf (a rare disorder, one named garment)


def obo_gap_rows(terms, roots, cap=OBO_CAP, min_descendants=MIN_DESCENDANTS):
    rows = []
    for field in sorted(roots):
        got = [r for name, depth in roots[field] for r in obo_rows(terms, name, depth, field) if r["descendants"] >= min_descendants]
        seen, uniq = set(), []
        for r in got:
            if r["code"] not in seen:
                seen.add(r["code"])
                uniq.append(r)
        rows += cap_per_field(uniq, cap)
    return rows


# ---------- Getty AAT (ODC-By 1.0) ----------

GETTY_SPARQL = "https://vocab.getty.edu/sparql.json?query="
GETTY_ROOTS = {  # field -> [(AAT id, depth, include the root itself)]
    "rites_of_passage": [("300054754", 1, False), ("300065284", 1, False)],
    "family_rituals": [("300065284", 1, False), ("300073472", 1, False)],
    "festivals_events": [("300073472", 1, False), ("300054754", 1, False)],
    "clothing_footwear": [("300266639", 1, False), ("300209280", 1, False)],
    "personal_appearance": [("300262903", 1, False), ("300236306", 0, True)],
    "video_gaming": [("300069657", 1, False)],
    "reuse_repair": [("300053737", 1, False)],
}
GETTY_CAP = 6
_GETTY_QUERY = """SELECT ?c ?l ?rl (COUNT(?k) AS ?n) WHERE {{
  ?c gvp:broaderPreferred aat:{root} ; gvp:prefLabelGVP/xl:literalForm ?l .
  aat:{root} gvp:prefLabelGVP/xl:literalForm ?rl .
  OPTIONAL {{ ?k gvp:broaderPreferred ?c }} FILTER(lang(?l) = "en" && lang(?rl) = "en") }} GROUP BY ?c ?l ?rl"""


def getty_rows(bindings, field):
    """Class rows from Getty bindings; guide terms (`<...>`) and temporary lists are not concepts."""
    out, seen = [], set()
    for b in bindings:
        label = b["l"]["value"].strip()
        code = "aat:" + b["c"]["value"].rsplit("/", 1)[-1]
        if code in seen or label.startswith("<") or "temporary alphabetical" in label:
            continue
        seen.add(code)
        out.append({"code": code, "label": label, "aliases": [], "description": "", "broader": b["rl"]["value"], "depth": 1,
                    "descendants": int(b["n"]["value"]), "target": field})
    return out


def fetch_getty_gap(fetch, roots=GETTY_ROOTS, cap=GETTY_CAP, min_descendants=MIN_DESCENDANTS):
    import urllib.parse
    rows, errors = [], []
    for field in sorted(roots):
        got = []
        for root, depth, include_root in roots[field]:
            if include_root:
                q = ("SELECT ?c ?l ?rl (COUNT(?k) AS ?n) WHERE { BIND(aat:%s AS ?c) ?c gvp:prefLabelGVP/xl:literalForm ?l . "
                     "BIND(?l AS ?rl) OPTIONAL { ?k gvp:broaderPreferred ?c } FILTER(lang(?l) = \"en\") } GROUP BY ?c ?l ?rl" % root)
            else:
                q = _GETTY_QUERY.format(root=root)
            try:
                got += getty_rows(fetch(GETTY_SPARQL + urllib.parse.quote(q))["results"]["bindings"], field)
            except Exception as e:  # noqa: BLE001
                errors.append({"root": root, "field": field, "error": f"{type(e).__name__}: {e}"[:200]})
        seen, uniq = set(), []
        for r in got:
            if r["code"] not in seen and r["descendants"] >= min_descendants:
                seen.add(r["code"])
                uniq.append(r)
        rows += cap_per_field(uniq, cap)
    return rows, errors


# ---------- EuroVoc (CC BY 4.0), narrower concepts of chosen concepts ----------

EUROVOC_SPARQL = "https://publications.europa.eu/webapi/rdf/sparql?default-graph-uri=&query="
EUROVOC_ROOTS = {  # field -> EuroVoc concept ids
    "voting_elections": ["695", "4367", "5097", "1953"],
    "political_participation": ["2269", "3900", "49"],
    "political_discourse": ["1282", "4436"],
    "labour_organising": ["3575"],
    "border_migration_admin": ["185", "2867", "2509"],
    "migration": ["1909"],
    "family_ties": ["965", "2239"],
    "marriage_cohabitation": ["1818"],
    "extremism_terrorism": ["4452", "4730"],
    "theft_property_crime": ["3944"],
    "violence_assault": ["3943", "4728"],
    "insurance_risk": ["3151"],
    "poverty_scarcity": ["2281"],
    "exams_assessment": ["925"],
}
EUROVOC_CAP = 5
_EUROVOC_QUERY = """PREFIX skos:<http://www.w3.org/2004/02/skos/core#>
SELECT ?c ?l ?rl (COUNT(?g) AS ?n) WHERE {{ <http://eurovoc.europa.eu/{root}> skos:prefLabel ?rl ; skos:narrower ?c .
  ?c skos:prefLabel ?l . OPTIONAL {{ ?c skos:narrower ?g }} FILTER(lang(?l) = "en" && lang(?rl) = "en") }} GROUP BY ?c ?l ?rl"""


def fetch_eurovoc_gap(fetch, roots=EUROVOC_ROOTS, cap=EUROVOC_CAP):
    import urllib.parse
    rows, errors = [], []
    for field in sorted(roots):
        got, seen = [], set()
        for root in roots[field]:
            try:
                bds = fetch(EUROVOC_SPARQL + urllib.parse.quote(_EUROVOC_QUERY.format(root=root)))["results"]["bindings"]
            except Exception as e:  # noqa: BLE001
                errors.append({"root": root, "field": field, "error": f"{type(e).__name__}: {e}"[:200]})
                continue
            for b in bds:
                code = "eurovoc:" + b["c"]["value"].rsplit("/", 1)[-1]
                if code not in seen:
                    seen.add(code)
                    got.append({"code": code, "label": b["l"]["value"].strip(), "aliases": [], "description": "",
                                "broader": b["rl"]["value"], "depth": 1, "descendants": int(b["n"]["value"]), "target": field})
        rows += cap_per_field(got, cap)
    return rows, errors


# ---------- LCSH (US public domain, LI.56): narrower authorities of chosen headings ----------

LCSH_URL = "https://id.loc.gov/authorities/subjects/label/{label}.json"
LCSH_ROOTS = {}  # field -> [LCSH headings]; filled for the fields the other sources left empty
LCSH_CAP = 6
_NARROWER = "http://www.loc.gov/mads/rdf/v1#hasNarrowerAuthority"
_ALABEL = "http://www.loc.gov/mads/rdf/v1#authoritativeLabel"


def lcsh_rows(graph, field):
    """Narrower headings of the authority named in a `label/<heading>.json` response; subdivided strings (`--`) are
    not topics. The most general first (fewest words, then label), the oldest-established heading standing for it."""
    by = {n["@id"]: n for n in graph}
    out = []
    for n in graph:
        if _NARROWER not in n or _ALABEL not in n:
            continue
        root = n[_ALABEL][0]["@value"]
        for x in n[_NARROWER]:
            t = by.get(x["@id"])
            label = t[_ALABEL][0]["@value"] if t and _ALABEL in t else ""
            if label and "--" not in label:
                out.append({"code": x["@id"].rsplit("/", 1)[-1], "label": label, "aliases": [], "description": "", "broader": root,
                            "depth": 1, "descendants": 0, "target": field})
    return out


def fetch_lcsh_gap(fetch, roots=None, cap=LCSH_CAP):
    import urllib.parse
    roots = LCSH_ROOTS if roots is None else roots
    rows, errors = [], []
    for field in sorted(roots):
        got, seen = [], set()
        for heading in roots[field]:
            try:
                for r in lcsh_rows(fetch(LCSH_URL.format(label=urllib.parse.quote(heading))), field):
                    if r["code"] not in seen:
                        seen.add(r["code"])
                        got.append(r)
            except Exception as e:  # noqa: BLE001
                errors.append({"root": heading, "field": field, "error": f"{type(e).__name__}: {e}"[:200]})
        rows += sorted(got, key=lambda r: (len(r["label"].split()), r["label"]))[:cap]
    return rows, errors


# ---------- BLS Consumer Expenditure categories (US public domain, LI.56) ----------

CEX_URL = "https://www.bls.gov/cex/tables/calendar-year/mean-item-share-average-standard-error/cu-size-2025.xlsx"
CEX_TARGETS = {  # category label pattern -> consumption fields it informs
    r"^Food away from home$": ["restaurants_dining"],
    r"^(Apparel and services|Footwear)$": ["clothing_footwear"],
    r"^Personal care products and services$": ["personal_appearance"],
    r"^(Personal insurance and pensions|Life and other personal insurance|Health insurance)$": ["insurance_risk"],
    r"^(Personal insurance and pensions|Interest, dividends, rental income)": ["saving_investing"],
    r"^(Retirement, pensions, and Social Security|Social Security, private and government retirement)$": ["retirement", "saving_investing"],
    r"^Cash contributions$": ["gifts_exchange"],
    r"^Shelter$": ["housing_search"],
    r"^Fees and admissions$": ["festivals_events"],
    r"^Public and other transportation$": ["public_transport"],
    r"^(Wages and salaries|Self-employment income)$": ["income_earning"],
    r"^Self-employment income$": ["entrepreneurship"],
    r"^Public assistance": ["poverty_scarcity"],
    r"^Unemployment and workers": ["job_loss"],
}


def cex_rows(items):
    """Rows from the item column of a CE mean-item-share table, `items` = [(indent, label)] in sheet order: the groups
    (indent 2) and subgroups (indent 4) of 'Average annual expenditures', each given to the fields its pattern names.
    Statistic rows (Mean, Share, SE, RSE) and totals are skipped."""
    rows, start, parent = [], False, ""
    for indent, label in items:
        label = re.sub(r"\s+[a-z]/\s*$", "", label.strip())
        if label == "Average annual expenditures":
            start = True
            continue
        if not start or label in {"Mean", "Share", "SE", "RSE"} or indent not in (2, 4):
            continue
        if indent == 2:
            parent = label
        for pat, fields in CEX_TARGETS.items():
            if re.search(pat, label):
                rows += [{"code": f"cex:{label}", "label": label, "aliases": [], "description": "", "broader": parent if indent == 4 else "",
                          "depth": indent // 2, "descendants": 0, "target": f} for f in fields]
    return rows
