#!/usr/bin/env python3
"""Rebuild the event-generator calibration table from open aggregate sources (World Bank WDI API, UN WPP indicators and
fertility-by-age files, ILOSTAT modelled labour participation, Eurostat divorce indicators).

    python3 tools/eventgen_fetch.py [--work DIR]

Raw downloads stay in --work (default: a temporary directory outside the repository); only aggregates (one value per
stratum, with a one-line source statement) are written to data/events/calibration/. Strata missing at a source are left
missing: the generator degrades loudly instead (calibration.Table.lookup). Aggregates only, never microdata (LI.61, LI.64).
"""
import argparse
import csv
import gzip
import json
import sys
import tempfile
import urllib.request
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import dataclasses  # noqa: E402
import re  # noqa: E402

from lifeimage.eventgen.calibration import CAL_DIR, Param, Table, dump_params  # noqa: E402

TODAY = date.today().isoformat()
COUNTRIES = ["KEN", "IND", "DEU", "BRA", "USA", "CHN", "EGY"]
REGION_CODES = ["SSF", "SAS", "ECS", "LCN", "NAC", "EAS", "MEA"]
STRATA = COUNTRIES + REGION_CODES + ["WLD"]
MIN_YEAR = 2005
WPP = "https://population.un.org/wpp/assets/Excel%20Files/1_Indicator%20(Standard)/CSV_FILES/"
UA = {"User-Agent": "lifeimage-eventgen/0.1 (research calibration)"}

# (indicator, quantity, field, unit, sex, age_band, confidence, note)
WB = [
    ("SE.PRE.ENRR", "education.preprimary_gross_enrolment", "c.early_childhood_education", "% gross", "all", "3-5", "medium", "UIS via WDI; gross ratio can exceed 100"),
    ("SE.PRM.AGES", "education.primary_entry_age", "c.school_education", "years", "all", "all", "high", "official entrance age (UIS)"),
    ("SE.PRM.DURS", "education.primary_duration", "c.school_education", "years", "all", "all", "high", "official duration (UIS)"),
    ("SE.SEC.DURS", "education.secondary_duration", "c.school_education", "years", "all", "all", "high", "official total duration (UIS)"),
    ("SE.PRM.NENR", "education.primary_net_enrolment", "c.school_education", "% net", "all", "primary age", "medium", "UIS via WDI"),
    ("SE.PRM.NENR.FE", "education.primary_net_enrolment", "c.school_education", "% net", "f", "primary age", "medium", "UIS via WDI"),
    ("SE.PRM.NENR.MA", "education.primary_net_enrolment", "c.school_education", "% net", "m", "primary age", "medium", "UIS via WDI"),
    ("SE.PRM.CMPT.ZS", "education.primary_completion", "c.school_education", "% of cohort", "all", "last-grade age", "medium", "gross intake ratio to last grade; can exceed 100 through over-age pupils"),
    ("SE.PRM.CMPT.FE.ZS", "education.primary_completion", "c.school_education", "% of cohort", "f", "last-grade age", "medium", "as above"),
    ("SE.PRM.CMPT.MA.ZS", "education.primary_completion", "c.school_education", "% of cohort", "m", "last-grade age", "medium", "as above"),
    ("SE.SEC.PROG.ZS", "education.progression_to_secondary", "c.exams_assessment", "% of primary completers", "all", "all", "medium", "transition after the primary leaving examination in many systems; UIS via WDI"),
    ("SE.SEC.CMPT.LO.ZS", "education.lower_secondary_completion", "c.school_education", "% of cohort", "all", "last-grade age", "medium", "UIS via WDI"),
    ("SE.TER.ENRR", "education.tertiary_gross_enrolment", "c.higher_education", "% gross", "all", "5 years after secondary", "medium", "UIS via WDI"),
    ("SE.TER.CUAT.BA.ZS", "education.tertiary_bachelor_attainment", "c.higher_education", "% of population 25+", "all", "25+", "medium", "completed bachelor's or equivalent"),
    ("SE.ADT.LITR.ZS", "education.adult_literacy", "c.basic_skills", "% of population 15+", "all", "15+", "medium", ""),
    ("SE.ADT.1524.LT.ZS", "education.youth_literacy", "c.basic_skills", "% of population 15-24", "all", "15-24", "medium", ""),
    ("SE.SEC.ENRL.VO.ZS", "education.vocational_share_secondary", "c.vocational_training", "% of secondary pupils", "all", "secondary", "medium", ""),
    ("SP.DYN.SMAM.FE", "family.age_first_marriage", "c.marriage_cohabitation", "years", "f", "all", "medium", "singulate mean age at first marriage (UN Population Division via WDI)"),
    ("SP.DYN.SMAM.MA", "family.age_first_marriage", "c.marriage_cohabitation", "years", "m", "all", "medium", "singulate mean age at first marriage (UN Population Division via WDI)"),
    ("SP.M18.2024.FE.ZS", "family.married_by_18", "c.marriage_wedding", "% of women 20-24", "f", "20-24", "medium", "DHS, MICS and other household surveys via WDI"),
    ("SP.M15.2024.FE.ZS", "family.married_by_15", "c.marriage_wedding", "% of women 20-24", "f", "20-24", "medium", "DHS, MICS and other household surveys via WDI"),
    ("SP.DYN.CONU.ZS", "family.contraceptive_prevalence", "c.reproduction_fertility", "% of women 15-49", "f", "15-49", "medium", "any method; household surveys via WDI"),
    ("SP.DYN.TFRT.IN", "fertility.tfr", "c.birth_of_child", "births per woman", "f", "15-49", "high", "WPP-based via WDI"),
    ("SH.STA.BRTC.ZS", "health.skilled_birth_attendance", "c.pregnancy_birth", "% of births", "f", "all", "medium", "household surveys via WDI"),
    ("SH.STA.MMRT", "health.maternal_mortality_ratio", "c.pregnancy_birth", "per 100000 live births", "f", "all", "medium", "modelled estimate"),
    ("SP.DYN.IMRT.IN", "mortality.infant", "c.death_dying", "per 1000 live births", "all", "0", "high", "UN IGME via WDI"),
    ("SH.DYN.MORT", "mortality.under5", "c.death_dying", "per 1000 live births", "all", "0-4", "high", "UN IGME via WDI"),
    ("SP.DYN.LE00.IN", "mortality.life_expectancy", "c.ageing_body", "years", "all", "0", "high", "UN WPP via WDI"),
    ("SH.DYN.NCOM.ZS", "health.ncd_mortality_30_70", "c.serious_illness", "% probability of dying 30-70", "all", "30-70", "medium", "WHO modelled estimate"),
    ("SH.STA.TRAF.P5", "health.road_traffic_deaths", "c.accident_injury", "per 100000 population", "all", "all", "medium", "WHO modelled estimate"),
    ("SH.IMM.MEAS", "health.measles_immunisation", "c.preventive_health", "% of children 12-23 months", "all", "12-23 months", "high", "WHO and UNICEF"),
    ("SH.STA.STNT.ZS", "health.stunting_under5", "c.nutrition_diet", "% of children under 5", "all", "0-4", "medium", "survey-based modelled estimate"),
    ("SN.ITK.DEFC.ZS", "health.undernourishment", "c.eating_drinking", "% of population", "all", "all", "medium", "FAO prevalence of undernourishment"),
    ("SH.STA.HYGN.ZS", "health.basic_handwashing", "c.hygiene_grooming", "% of population", "all", "all", "medium", "WHO and UNICEF JMP"),
    ("SH.MED.PHYS.ZS", "health.physicians", "c.medical_care", "per 1000 people", "all", "all", "medium", "WHO; supply of care"),
    ("SH.STA.SUIC.FE.P5", "harm.suicide_mortality", "c.self_harm_suicide", "per 100000 population", "f", "all", "medium", "WHO age-standardised"),
    ("SH.STA.SUIC.MA.P5", "harm.suicide_mortality", "c.self_harm_suicide", "per 100000 population", "m", "all", "medium", "WHO age-standardised"),
    ("VC.IHR.PSRC.P5", "harm.homicide", "c.violence_assault", "per 100000 population", "all", "all", "medium", "UNODC"),
    ("SG.VAW.1549.ZS", "harm.partner_violence_12m", "c.domestic_abuse", "% of ever-partnered women 15-49", "f", "15-49", "medium", "population surveys; physical and/or sexual, last 12 months"),
    ("SL.UEM.TOTL.ZS", "work.unemployment", "c.job_search", "% of labour force", "all", "15+", "medium", "ILO modelled estimate"),
    ("SL.UEM.1524.ZS", "work.youth_unemployment", "c.employment_transition", "% of labour force 15-24", "all", "15-24", "medium", "ILO modelled estimate"),
    ("SL.EMP.SELF.ZS", "work.self_employment", "c.entrepreneurship", "% of employment", "all", "15+", "medium", "ILO modelled estimate"),
    ("SL.AGR.EMPL.ZS", "work.agriculture_employment", "c.agri_forestry_fishing_work", "% of employment", "all", "15+", "medium", "ILO modelled estimate"),
    ("SI.POV.DDAY", "money.extreme_poverty", "c.poverty_scarcity", "% of population", "all", "all", "medium", "World Bank PIP, international poverty line"),
    ("FX.OWN.TOTL.ZS", "money.account_ownership", "c.banking_payments", "% of adults 15+", "all", "15+", "medium", "Global Findex"),
    ("SM.POP.TOTL.ZS", "mobility.migrant_stock", "c.migration", "% of population", "all", "all", "medium", "international migrant stock (UN DESA)"),
    ("IT.NET.USER.ZS", "tech.internet_use", "c.digital_tool_use", "% of population", "all", "all", "medium", "ITU"),
    ("IT.CEL.SETS.P2", "tech.mobile_subscriptions", "c.subscriptions_telecom", "per 100 people", "all", "all", "medium", "ITU"),
    ("SG.GEN.PARL.ZS", "civic.women_in_parliament", "c.political_participation", "% of seats", "f", "all", "medium", "IPU"),
    ("EG.ELC.ACCS.ZS", "home.electricity_access", "c.home_energy_utilities", "% of population", "all", "all", "medium", "World Bank and WHO"),
    ("SG.TIM.UWRK.FE", "time.unpaid_domestic_care_share", "c.cleaning_laundry", "% of 24-hour day", "f", "15+", "medium", "time-use surveys; domestic work and care combined; regional aggregates only"),
    ("SG.TIM.UWRK.MA", "time.unpaid_domestic_care_share", "c.cleaning_laundry", "% of 24-hour day", "m", "15+", "medium", "time-use surveys; domestic work and care combined; regional aggregates only"),
]


PLACES = {"KEN": "Kenya", "IND": "India", "DEU": "Germany", "BRA": "Brazil", "USA": "the United States", "CHN": "China", "EGY": "Egypt",
          "SSF": "Sub-Saharan Africa", "SAS": "South Asia", "ECS": "Europe and Central Asia", "LCN": "Latin America and the Caribbean",
          "NAC": "North America", "EAS": "East Asia and Pacific", "MEA": "the Middle East and North Africa", "WLD": "the world"}
# Event phrasings of each quantity's definition: (action, outcome or None). The actor is built from the stratum. These are
# de-identified paraphrases of what the indicator counts (a survey or register item phrased as an event), not cases.
EV = {
    "education.preprimary_gross_enrolment": ("started attending a pre-primary programme", "began formal learning before primary school"),
    "education.primary_entry_age": ("entered the first grade of primary school at the official entry age", None),
    "education.primary_duration": ("went through every grade of primary school in turn", None),
    "education.secondary_duration": ("spent the full official length of secondary school in class", None),
    "education.primary_net_enrolment": ("was enrolled in primary school at the age that grade is meant for", None),
    "education.primary_completion": ("reached and finished the last grade of primary school", "held a primary school completion"),
    "education.progression_to_secondary": ("moved on from primary to secondary school", "began lower secondary education"),
    "education.lower_secondary_completion": ("finished the last grade of lower secondary school", "held a lower secondary completion"),
    "education.tertiary_gross_enrolment": ("enrolled in a university or other tertiary course after secondary school", None),
    "education.tertiary_bachelor_attainment": ("completed a bachelor's degree or equivalent", "held a tertiary qualification in adulthood"),
    "education.adult_literacy": ("could read and write a short simple statement about everyday life", "counted as literate"),
    "education.youth_literacy": ("could read and write a short simple statement about everyday life", "counted as literate"),
    "education.vocational_share_secondary": ("followed a vocational programme in secondary school", None),
    "family.age_first_marriage": ("entered a first marriage", "ended single life at about this age"),
    "family.married_by_18": ("married before turning 18", "left the single, school-age life early"),
    "family.married_by_15": ("married before turning 15", "left the single, school-age life early"),
    "family.contraceptive_prevalence": ("used a method to avoid pregnancy", "postponed or limited childbearing"),
    "fertility.tfr": ("gave birth to children over the reproductive years", "ended with a completed family size"),
    "fertility.asfr": ("gave birth to a child", "became a parent or added to the family"),
    "fertility.mean_age_childbearing": ("gave birth to a child", "became a parent at about this age"),
    "fertility.sex_ratio_at_birth": ("was born", "was recorded as a boy or a girl at birth"),
    "health.skilled_birth_attendance": ("gave birth with a doctor, nurse or midwife present", "delivered under skilled care"),
    "health.maternal_mortality_ratio": ("died of causes linked to pregnancy or childbirth", "left a newborn without its mother"),
    "mortality.infant": ("died in the first year of life", None),
    "mortality.under5": ("died before the fifth birthday", None),
    "mortality.under5_wpp": ("died before the fifth birthday", None),
    "mortality.life_expectancy": ("lived to an old age", None),
    "mortality.life_expectancy_wpp": ("lived to an old age", None),
    "mortality.prob_death_0_40": ("died before the age of 40", None),
    "health.ncd_mortality_30_70": ("died between 30 and 70 of heart disease, cancer, diabetes or chronic lung disease", None),
    "health.road_traffic_deaths": ("died in a road traffic crash", None),
    "health.measles_immunisation": ("received a measles vaccination in the second year of life", "was protected against measles"),
    "health.stunting_under5": ("grew far less than expected for age through chronic undernutrition", "was recorded as stunted"),
    "health.undernourishment": ("went without enough food to meet energy needs over a year", None),
    "health.basic_handwashing": ("washed hands with soap and water at home", None),
    "health.physicians": ("consulted a physician about a health problem", None),
    "harm.suicide_mortality": ("died by suicide", None),
    "harm.homicide": ("was killed in an intentional homicide", None),
    "harm.partner_violence_12m": ("was physically or sexually attacked by a partner in the past year", "reported the violence to an interviewer"),
    "work.unemployment": ("was without work, available and looking for a job", None),
    "work.youth_unemployment": ("was without work, available and looking for a first job", None),
    "work.self_employment": ("worked for themselves rather than for an employer", None),
    "work.agriculture_employment": ("worked in farming, forestry or fishing", None),
    "work.labour_force_participation": ("was in work or looking for work during the week", None),
    "money.extreme_poverty": ("lived on less than the international poverty line per day", None),
    "money.account_ownership": ("opened and used a bank or mobile-money account", "gained access to formal payments"),
    "mobility.migrant_stock": ("moved to live in another country", "became part of the migrant population there"),
    "tech.internet_use": ("used the internet in the past three months", None),
    "tech.mobile_subscriptions": ("took out a mobile phone subscription", None),
    "civic.women_in_parliament": ("won a seat in the national parliament", "sat in the legislature"),
    "home.electricity_access": ("lived in a home connected to electricity", None),
    "time.unpaid_domestic_care_share": ("spent part of each day on unpaid housework and care for family", None),
    "family.crude_divorce_rate": ("divorced after a marriage", "ended the marriage in court"),
    "family.divorces_per_100_marriages": ("divorced after a marriage", "ended the marriage in court"),
}


def event_snippet(p):
    """One de-identified event record for a Param: actor from its stratum, the quantity's event phrasing, its domain tag."""
    if p.quantity not in EV:
        return None
    action, outcome = EV[p.quantity]
    who = {"f": "woman", "m": "man", "all": "person"}[p.sex]
    band = f" aged {p.age_band}" if re.fullmatch(r"\d+(-\d+|\+)", p.age_band) else ""
    where = PLACES[p.region]
    actor = f"A {who}{band} " + ("in " + where if where != "the world" else "anywhere in the world")
    return {"actor": actor, "action": action, "outcome": outcome, "domains": [p.field], "source_id": p.source_id,
            "locator": p.snippet_locator, "sanitization": "paraphrase of what the indicator counts; no individual record, name or place below country"}


def get(url, tries=3):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
                return r.read()
        except Exception:
            if i == tries - 1:
                raise


def getfile(url, path):
    if not path.exists():
        path.write_bytes(get(url))
    return path


def wb_params():
    out, miss = [], []
    for ind, quantity, field, unit, sex, band, conf, note in WB:
        url = f"https://api.worldbank.org/v2/country/{';'.join(STRATA)}/indicator/{ind}?format=json&mrnev=1&per_page=200"
        try:
            data = json.loads(get(url))
        except Exception:
            miss.append(ind)
            continue
        rows = data[1] if isinstance(data, list) and len(data) > 1 and data[1] else []
        n = 0
        for r in rows:
            code = r["countryiso3code"] or ""
            if code == "WLD" or code in STRATA:
                pass
            if code not in STRATA or r["value"] is None or int(r["date"]) < MIN_YEAR:
                continue
            region = code
            snippet = f'{r["indicator"]["value"]}, {r["country"]["value"]}, {r["date"]}: {r["value"]:g}'
            out.append(Param(field=field, quantity=quantity, value=float(r["value"]), unit=unit, age_band=band, sex=sex, region=region,
                             year=int(r["date"]), source_id="WB-WDI", source_url=f"https://data.worldbank.org/indicator/{ind}",
                             licence="open", confidence=conf, notes=note, source_statement=snippet,
                             snippet_locator=f"World Bank WDI indicator {ind} (API v2, most recent value)", retrieved=TODAY))
            n += 1
        if n == 0:
            miss.append(ind)
    return out, miss


def wpp_params(work):
    out = []
    loc = {"World": "WLD"}
    fert = getfile(WPP + "WPP2024_Fertility_by_Age5.csv.gz", work / "wpp_fert.csv.gz")
    with gzip.open(fert, "rt", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            if r["Time"] != "2023" or r["Variant"] != "Medium":
                continue
            code = r["ISO3_code"] or loc.get(r["Location"])
            if code not in STRATA or r["AgeGrp"] == "10-14":
                continue
            out.append(Param(field="c.birth_of_child", quantity="fertility.asfr", value=float(r["ASFR"]), unit="births per 1000 women per year",
                             age_band=r["AgeGrp"], sex="f", region=code, year=2023, source_id="UN-WPP2024",
                             source_url="https://population.un.org/wpp/downloads?folder=Standard%20Projections&group=CSV%20format",
                             licence="open", confidence="medium", notes="WPP medium variant estimate for 2023 (model-based)",
                             source_statement=f'Age-specific fertility rate (births per 1,000 women), {r["Location"]}, {r["AgeGrp"]}, 2023: {float(r["ASFR"]):g}',
                             snippet_locator="WPP2024_Fertility_by_Age5.csv column ASFR", retrieved=TODAY))
    ind = getfile(WPP + "WPP2024_Demographic_Indicators_Medium.csv.gz", work / "wpp_ind.csv.gz")
    cols = [("MAC", "fertility.mean_age_childbearing", "c.birth_of_child", "years", "f", "15-49", "Mean age of childbearing (years)"),
            ("SRB", "fertility.sex_ratio_at_birth", "c.pregnancy_birth", "male births per 100 female", "all", "0", "Sex ratio at birth (male births per 100 female births)"),
            ("Q5", "mortality.under5_wpp", "c.death_dying", "deaths per 1000 births", "all", "0-4", "Under-five mortality (deaths under age 5 per 1,000 live births)"),
            ("Q0040Male", "mortality.prob_death_0_40", "c.death_dying", "per 1000", "m", "0-40", "Probability of dying between birth and exact age 40, male (per 1,000)"),
            ("Q0040Female", "mortality.prob_death_0_40", "c.death_dying", "per 1000", "f", "0-40", "Probability of dying between birth and exact age 40, female (per 1,000)"),
            ("LExMale", "mortality.life_expectancy_wpp", "c.death_dying", "years", "m", "0", "Male life expectancy at birth (years)"),
            ("LExFemale", "mortality.life_expectancy_wpp", "c.death_dying", "years", "f", "0", "Female life expectancy at birth (years)")]
    with gzip.open(ind, "rt", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            if r["Time"] != "2023":
                continue
            code = r["ISO3_code"] or loc.get(r["Location"])
            if code not in STRATA:
                continue
            for col, q, field, unit, sex, band, label in cols:
                v = float(r[col])
                out.append(Param(field=field, quantity=q, value=v, unit=unit, age_band=band, sex=sex, region=code, year=2023,
                                 source_id="UN-WPP2024", source_url="https://population.un.org/wpp/downloads?folder=Standard%20Projections&group=CSV%20format",
                                 licence="open", confidence="medium", notes="WPP medium variant estimate for 2023 (model-based)",
                                 source_statement=f'{label}, {r["Location"]}, 2023: {v:g}',
                                 snippet_locator=f"WPP2024_Demographic_Indicators_Medium.csv column {col}", retrieved=TODAY))
    return out


def ilo_params(work):
    path = getfile("https://rplumber.ilo.org/data/indicator/?id=EAP_2WAP_SEX_AGE_RT_A&lang=en&format=.csv", work / "ilo_lfpr.csv")
    sexes = {"SEX_F": "f", "SEX_M": "m"}
    bands = {"AGE_AGGREGATE_Y15-24": "15-24", "AGE_AGGREGATE_Y25-54": "25-54", "AGE_AGGREGATE_Y55-64": "55-64", "AGE_AGGREGATE_YGE65": "65+"}
    out = []
    with open(path, encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            code = "WLD" if r["ref_area"] == "X01" else r["ref_area"]
            if r["time"] != "2023" or code not in STRATA or r["sex"] not in sexes or r["classif1"] not in bands or not r["obs_value"]:
                continue
            v = float(r["obs_value"])
            out.append(Param(field="c.employment_job", quantity="work.labour_force_participation", value=v, unit="% of population in band",
                             age_band=bands[r["classif1"]], sex=sexes[r["sex"]], region=code, year=2023, source_id="ILOSTAT-modelled",
                             source_url="https://ilostat.ilo.org/data/", licence="unread", confidence="medium",
                             notes="ILO modelled estimates, indicator EAP_2WAP_SEX_AGE_RT; licence terms page not readable (403 in the scout), believed CC BY 4.0",
                             source_statement=f'Labour force participation rate by sex and age (%), {r["ref_area"]}, {bands[r["classif1"]]}, {sexes[r["sex"]]}, 2023: {v:g}',
                             snippet_locator="ILOSTAT indicator EAP_2WAP_SEX_AGE_RT_A (bulk csv row)", retrieved=TODAY))
    return out


def eurostat_params():
    out = []
    for ind, q, unit, label in (("GDIVRT", "family.crude_divorce_rate", "per 1000 population", "Crude divorce rate"),
                                ("DIVMARPCT", "family.divorces_per_100_marriages", "per 100 marriages", "Divorces per 100 marriages")):
        url = f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/demo_ndivind?format=JSON&geo=DE&indic_de={ind}&sinceTimePeriod=2018"
        d = json.loads(get(url))
        times = d["dimension"]["time"]["category"]["index"]
        vals = {int(k): v for k, v in d["value"].items()}
        if not vals:
            continue
        i = max(vals)
        year = [t for t, ix in times.items() if ix == i][0]
        out.append(Param(field="c.divorce", quantity=q, value=float(vals[i]), unit=unit, age_band="all", sex="all", region="DEU", year=int(year),
                         source_id="Eurostat-demo_ndivind", source_url="https://ec.europa.eu/eurostat/databrowser/view/demo_ndivind/default/table",
                         licence="open", confidence="high", notes="national registration data; Germany only in this table",
                         source_statement=f"{label}, Germany, {year}: {vals[i]:g}", snippet_locator=f"Eurostat demo_ndivind indic_de={ind} geo=DE",
                         retrieved=TODAY))
    return out


def regions():
    d = json.loads(get("https://api.worldbank.org/v2/country?format=json&per_page=400"))[1]
    return {c["id"]: c["region"]["id"] for c in d if c["region"]["value"] != "Aggregates"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=None)
    a = ap.parse_args()
    work = Path(a.work or tempfile.mkdtemp(prefix="eventgen_fetch_"))
    work.mkdir(parents=True, exist_ok=True)
    wb, miss = wb_params()
    params = wb + wpp_params(work) + ilo_params(work) + eurostat_params()
    params = [dataclasses.replace(p, event_snippets=[e] if (e := event_snippet(p)) else [],
                                  snippet_missing="" if p.quantity in EV else "no event phrasing written for this quantity") for p in params]
    Table(params)  # validates and rejects duplicate keys
    CAL_DIR.mkdir(parents=True, exist_ok=True)
    dump_params(params, CAL_DIR / "aggregates_v1.jsonl")
    reg = regions()
    (CAL_DIR / "regions.json").write_text(json.dumps(reg, sort_keys=True, indent=0), encoding="utf-8")
    print(f"{len(params)} params, {len({p.field for p in params})} field families; WB indicators with no usable value: {miss}")


if __name__ == "__main__":
    main()
