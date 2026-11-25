"""Second gap candidate set (`gap2`, LI.19/LI.54/LI.56): fine candidates for the nine coarse fields that still have no fine
child as main parent after the first gap set. Same sources, fetchers and rules as `gap.py` (class names of openly licensed
classifications, never records), with roots chosen for these fields only; the merged `gap` set is not touched.
Roots were resolved by searching Wikidata for the field's own words (2026-11-25). Rows carry `target`, a trace only."""
from . import gap

FIELDS = ["counselling_therapy", "cybersecurity", "environmental_harm", "hospitality_hosting", "medication_adherence",
          "parenting_adolescents", "reproduction_fertility", "self_provisioning", "weather_climate_adaptation"]
CAP = 20  # the lead asks 8-20 per field

WIKIDATA_ROOTS = {
    "counselling_therapy": ["Q4390239", "Q183257", "Q205398", "Q837393", "Q179661"],  # counseling, psychotherapy, social work, group therapy, therapy
    "cybersecurity": ["Q3510521", "Q189900", "Q4071928", "Q631425", "Q14001", "Q141090"],  # computer/information security, cyberattack, vulnerability, malware, encryption
    "environmental_harm": ["Q1156265", "Q58734", "Q183129", "Q131123", "Q34577", "Q169940", "Q1134541"],  # environmental crime, pollution, water/air, poaching, deforestation, dumping
    "hospitality_hosting": ["Q815825", "Q1495452", "Q27686", "Q18089644"],  # hospitality, hospitality industry, hotel, guest
    "medication_adherence": ["Q67144513", "Q12140", "Q701216", "Q718753"],  # adherence, medication, pharmacotherapy, drug interaction
    "parenting_adolescents": ["Q131774", "Q2353731", "Q1217379", "Q11943008"],  # adolescence, parenting (education), raising a child, adolescent psychology
    "reproduction_fertility": ["Q179399", "Q25862", "Q122224", "Q1280670", "Q28693", "Q964401", "Q1981388"],  # infertility, ART, contraception, family planning, miscarriage, fertility, reproductive health
    "self_provisioning": ["Q2787508", "Q1572679", "Q59095998", "Q124946", "Q2991771", "Q173514", "Q38695", "Q36963", "Q14373"],  # subsistence, household production, gardening, foraging, preservation, cooking, hunting, fishing
    "weather_climate_adaptation": ["Q260607", "Q11663", "Q1277161", "Q125928"],  # adaptation, weather, extreme weather, climate change
}
# Wikidata subclasses that are off-topic for the field they were reached from (a leaf of another domain, a person, a work)
SKIP_LABELS = set()

LCSH_ROOTS = {
    "counselling_therapy": ["Counseling", "Psychotherapy"],
    "cybersecurity": ["Computer security", "Data protection"],
    "environmental_harm": ["Pollution", "Environmental degradation", "Hazardous wastes"],
    "hospitality_hosting": ["Hospitality", "Entertaining", "Hotels"],
    "medication_adherence": ["Self-medication", "Drugs"],
    "parenting_adolescents": ["Parenting", "Teenagers", "Adolescence"],
    "reproduction_fertility": ["Birth control", "Infertility", "Human reproductive technology"],
    "self_provisioning": ["Self-reliant living", "Home economics", "Gardening", "Food--Preservation"],
    "weather_climate_adaptation": ["Weather", "Climatic changes", "Natural disasters"],
}
EUROVOC_ROOTS = {}  # concept ids are not resolvable by label here; none typed from memory
DOID_ROOTS = {"reproduction_fertility": [("female reproductive system disease", 1), ("male reproductive system disease", 1)]}
MONDO_ROOTS = {}  # MONDO has no term named "infertility"; mental disorders are conditions, not counselling; none used
GETTY_ROOTS = {}


def fetch_all(fetch_api, fetch):
    """{source: (rows, errors)} for every gap2 source."""
    out = {}
    rows, dropped, errors = gap.fetch_wikidata_gap_api(fetch_api, roots=WIKIDATA_ROOTS, cap=CAP)
    out["wikidata"] = ([r for r in rows if r["label"] not in SKIP_LABELS], errors)
    out["lcsh"] = gap.fetch_lcsh_gap(fetch, roots=LCSH_ROOTS, cap=6)
    return out
