#!/usr/bin/env python3
"""Build the domain calibration table (increment 3) from open aggregate sources: Eurostat (time use HETUS tus_00age, disability, doctor visits, informal
care, cultural and sport participation, voluntary activities, tenure, long-term unemployment, police-recorded offences, suspects and convictions, births by
marital status), India's national time-use survey 2019 (MoSPI report, text extracted with pdftotext), World Bank WDI (diabetes, HIV, tuberculosis),
Our World in Data voter turnout (V-Dem) and the WHO disability fact sheet.

    python3 tools/eventgen_fetch_domains.py [--work DIR]

Raw downloads stay in --work (default: a temporary directory outside the repository); only aggregates (one value per stratum with a one-line source
statement and de-identified event snippets) are written to data/events/calibration/aggregates_v2_domains.jsonl. Strata missing at a source stay missing.
The ECS stratum of Eurostat series is the unweighted mean of the countries the series covers (named in each Param's notes); Germany is kept as a country.
"""
import argparse
import csv
import io
import json
import re
import subprocess
import sys
import tempfile
import urllib.request
from collections import defaultdict
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import dataclasses  # noqa: E402

from eventgen_fetch import PLACES, STRATA  # noqa: E402
from eventgen_fetch import get as _get  # noqa: E402
from lifeimage.eventgen import catalog  # noqa: E402
from lifeimage.eventgen.calibration import CAL_DIR, Param, Table, dump_params  # noqa: E402
from lifeimage.eventgen.relational import relationalise_params  # noqa: E402

TODAY = date.today().isoformat()
ES = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/"
ES_URL = "https://ec.europa.eu/eurostat/databrowser/view/{}/default/table"
GEO3 = {"DE": "DEU", "FR": "FRA"}   # Germany kept as a country; every other Eurostat country enters only the ECS mean
SEX = {"F": "f", "M": "m", "T": "all"}
BANDS_HETUS = {"Y15-20": "15-20", "Y20-24": "20-24", "Y25-44": "25-44", "Y45-64": "45-64", "Y_GE65": "65+"}
BANDS_EHIS = {"Y15-24": "16-24", "Y25-34": "25-34", "Y35-44": "35-44", "Y45-54": "45-54", "Y55-64": "55-64", "Y65-74": "65-74", "Y_GE75": "75+"}   # the interview survey covers ages 15 and over
BANDS_HEALTH = {"Y16-24": "16-24", "Y25-34": "25-34", "Y35-44": "35-44", "Y45-54": "45-54", "Y55-64": "55-64", "Y65-74": "65-74", "Y_GE75": "75+"}
FIELD_OF_GROUP = {"employment": "c.employment_job", "own_use": "c.self_provisioning", "domestic": "c.cleaning_laundry", "caregiving": "c.parenting_young_children",
                  "volunteering": "c.volunteering", "learning": "c.school_education", "social_religious": "c.socialising", "leisure": "c.film_tv_video",
                  "personal_care": "c.sleep"}


# ---------------- helpers ----------------
CACHE = {"dir": None}


def get(url):
    """Download with a disk cache in the work directory (a rerun after a failure does not repeat finished downloads)."""
    import hashlib
    if CACHE["dir"] is None:
        return _get(url)
    f = CACHE["dir"] / hashlib.sha256(url.encode()).hexdigest()
    if not f.exists():
        f.write_bytes(_get(url))
    return f.read_bytes()


def num(v):
    """A Eurostat value: a number or an hh:mm string (time use), as a float (hours for hh:mm)."""
    if isinstance(v, str) and ":" in v:
        h, m = v.split(":")
        return int(h) + int(m) / 60 if h.strip() and m.strip() else None
    return float(v)


def jsonstat(dataset, query):
    d = json.loads(get(f"{ES}{dataset}?format=JSON&lang=en&{query}"))
    ids, sizes = d["id"], d["size"]
    cats = {k: {c: i for c, i in d["dimension"][k]["category"]["index"].items()} for k in ids}
    inv = {k: {i: c for c, i in cats[k].items()} for k in ids}
    out = []
    for flat, v in d["value"].items():
        r, idx = int(flat), {}
        for k, s in zip(reversed(ids), reversed(sizes)):
            idx[k] = inv[k][r % s]
            r //= s
        out.append((idx, v))
    return out


def latest(cells, keyfn):
    """{key: (value, year)}: the most recent year per key (key excludes time)."""
    best = {}
    for idx, v in cells:
        k, t = keyfn(idx), int(idx["time"])
        x = num(v) if v is not None else None
        if x is not None and (k not in best or t > best[k][1]):
            best[k] = (x, t)
    return best


def pooled(series):
    """series {(geo, *rest): (value, year)} -> {(region, *rest): (value, year, note)} with Germany and the ECS mean of every geo."""
    by = defaultdict(list)
    for (geo, *rest), (v, y) in series.items():
        if geo in ("EU27_2020", "EA20", "EU28", "EA19", "EU", "EA", "EEA", "EU15", "EU25", "EA18", "EA17", "EA12", "EU27_2007"):
            continue
        by[tuple(rest)].append((geo, v, y))
    out = {}
    for rest, rows in by.items():
        for geo, v, y in rows:
            if geo in GEO3 and GEO3[geo] == "DEU":
                out[("DEU", *rest)] = (v, y, f"Eurostat country value for {geo}")
        if len(rows) >= 3:
            ys = sorted(y for _, _, y in rows)
            out[("ECS", *rest)] = (sum(v for _, v, _ in rows) / len(rows), ys[-1], f"unweighted mean of {len(rows)} Eurostat countries ({', '.join(sorted(g for g, _, _ in rows))}), years {ys[0]}-{ys[-1]}")
    return out


def actor(sex, band, region):
    who = {"f": "woman", "m": "man", "all": "person"}[sex]
    b = f" aged {band}" if re.fullmatch(r"\d+(-\d+|\+)", band) else ""
    where = PLACES[region]
    return f"A {who}{b} " + ("in " + where if where != "the world" else "anywhere in the world")


def snippets(k, sex, band, region, source_id, locator, timescale=None):
    ts = timescale or k.timescale
    doms = list(dict.fromkeys(k.form + k.content))[:3]
    return [{"actor": actor(sex, band, region), "action": k.action, "outcome": k.outcome_text, "timescale": ts, "domains": doms, "source_id": source_id, "locator": locator,
             "sanitization": "paraphrase of what the indicator or activity code counts; no individual record, name or place below country"}]


def mk(k, quantity, value, unit, band, sex, region, year, source_id, url, licence, conf, notes, statement, locator, timescale=None, field=None):
    return Param(field=field or k.form[0], quantity=quantity, value=float(value), unit=unit, age_band=band, sex=sex, region=region, year=int(year), source_id=source_id,
                 source_url=url, licence=licence, confidence=conf, notes=notes, source_statement=statement[:400], snippet_locator=locator, retrieved=TODAY,
                 event_snippets=snippets(k, sex, band, region, source_id, locator, timescale))


def hhmm(x):
    """Eurostat time values come as decimal hours."""
    return float(x) * 60.0


# ---------------- time use ----------------
def hetus_params():
    out = []
    codes = {k.code: k for k in catalog.TIME if k.code}
    q = "&".join([f"acl00={c}" for c in codes] + [f"age={a}" for a in BANDS_HETUS] + ["sex=F", "sex=M", "unit=PTP_RT", "unit=TIME_SP", "unit=PTP_TIME"])
    cells = jsonstat("tus_00age", q)
    rows = latest(cells, lambda i: (i["geo"], i["acl00"], BANDS_HETUS[i["age"]], SEX[i["sex"]], i["unit"]))
    part = {(g, c, b, s): v for (g, c, b, s, u), v in rows.items() if u == "PTP_RT"}
    mins = {(g, c, b, s): v for (g, c, b, s, u), v in rows.items() if u == "PTP_TIME"}
    for name, ser, unit, qn, fmt in (("participation rate", part, "% of persons on a diary day", "time.participation.", lambda x: x),
                                     ("participation time", mins, "minutes per participant per day", "time.minutes.", hhmm)):
        pool = pooled(ser)
        for (region, code, band, sex), (v, y, note) in pool.items():
            k = codes[code]
            val = fmt(v)
            locator = f"Eurostat tus_00age acl00={code} unit={'PTP_RT' if qn.endswith('participation.') else 'PTP_TIME'}"
            st = f"HETUS {name} in {k.action}, {PLACES[region]}, {sex}, age {band}, {y}: {val:g}"
            out.append(mk(k, qn + k.key, val, unit, band, sex, region, y, "Eurostat-HETUS", ES_URL.format("tus_00age"), "open", "medium" if region == "DEU" else "low",
                          f"HETUS 2000/2010 diaries; {note}. " + ("PTP_TIME is time per participant, converted to minutes." if qn.endswith("minutes.") else ""), st, locator))
    return out


def india_params(work):
    pdf = work / "tus_india.pdf"
    if not pdf.exists():
        pdf.write_bytes(get("https://mospi.gov.in/sites/default/files/publication_reports/Report_TUS_2019_0.pdf"))
    txt = subprocess.run(["pdftotext", "-layout", str(pdf), "-"], capture_output=True, text=True, check=True).stdout
    lines = txt.splitlines()
    names = {v: k for k, v in catalog.INDIA_GROUPS.items()}
    names["Socializing and communication, community"] = "social_religious"
    names["Socializing and communication, community participation"] = "social_religious"
    num = re.compile(r"^(.*?)\s{2,}([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*$")
    pend = re.compile(r"^\s{20,}([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*$")

    def block(title, which):
        starts = [i for i, l in enumerate(lines) if l.strip().startswith(title)]
        for i in starts:
            seg = lines[i:i + 8]
            if any("rural+urban" in l for l in seg):
                sex, res, label = None, {}, None
                for l in lines[i + 3:i + 80]:
                    s = l.strip()
                    if s in ("male", "female", "person"):
                        sex = s
                        continue
                    if s.startswith("Reference:"):
                        break
                    m = pend.match(l)
                    if m and label:
                        res[(label, sex)] = tuple(float(x) for x in m.groups())
                        label = None
                        continue
                    m = num.match(l)
                    if m and sex:
                        grp = names.get(m.group(1).strip())
                        if grp:
                            res[(grp, sex)] = tuple(float(x) for x in m.groups()[1:])
                    elif s in names or re.sub(r"\s+", " ", s).startswith("Socializing and communication"):
                        label = "social_religious"
                return res
        raise RuntimeError(f"India time-use block {title!r} not found")
    part = block("Statement 9:", "p")
    mins = block("Statement 10:", "m")
    out = []
    bands = ("15-29", "15-59", "60+")
    for res, qn, unit, name in ((part, "time.group.participation.", "% of persons on a diary day", "Percentage of persons participating in a day"),
                                (mins, "time.group.minutes.", "minutes per participant per day", "Average time (minutes) in a day per participant")):
        for (grp, sx), vals in res.items():
            if sx == "person" or grp not in catalog.INDIA_GROUPS:
                continue
            sex = "f" if sx == "female" else "m"
            first = next(k for k in catalog.TIME if k.group == grp)
            for band, v in zip(bands, vals):
                locator = f"Time Use in India 2019, Statement {'9' if qn.endswith('participation.') else '10'}, rural+urban, {sx}, {catalog.INDIA_GROUPS[grp]}"
                st = f"{name} in {catalog.INDIA_GROUPS[grp]}, India, {sx}, age {band}, 2019: {v:g}"
                out.append(mk(first, qn + grp, v, unit, band, sex, "IND", 2019, "MoSPI-TUS2019",
                              "https://mospi.gov.in/sites/default/files/publication_reports/Report_TUS_2019_0.pdf", "open", "medium",
                              "National sample survey of time use 2019 (all-India, rural plus urban); the estimates consider all activities in a time slot", st, locator, field=FIELD_OF_GROUP[grp]))
    return out


# ---------------- Eurostat annual indicators ----------------
def es_family(dataset, fixed, vary, kind, qn, unit, bandmap, source_id, locator_fmt, conf="medium", scale=1.0, notes="", statement_fmt=None, years=None, sexes=("F", "M")):
    """One Eurostat series family: `fixed` query filters, a `vary` dimension (code -> value variants not needed), bands from `bandmap`."""
    q = "&".join(fixed + [f"age={a}" for a in bandmap] + [f"sex={s}" for s in sexes])
    cells = jsonstat(dataset, q)
    rows = latest(cells, lambda i: (i["geo"], BANDS_KEY(bandmap, i), SEX[i["sex"]]))
    out = []
    for (region, band, sex), (v, y, note) in pooled(rows).items():
        val = v * scale
        out.append(mk(kind, qn, val, unit, band, sex, region, y, source_id, ES_URL.format(dataset), "open", conf if region == "DEU" else "low",
                      f"{notes} {note}".strip(), (statement_fmt or "{ds} {q}, {r}, {s}, age {b}, {y}: {v:g}").format(ds=dataset, q=qn, r=PLACES[region], s=sex, b=band, y=y, v=val),
                      locator_fmt))
    return out


def BANDS_KEY(bandmap, i):
    return bandmap[i["age"]]


def eurostat_params():
    out = []
    K = catalog.BY_KEY
    ev = lambda *a, **k: out.extend(es_family(*a, **k))  # noqa: E731
    ev("hlth_silc_20", ["lev_limit=SM_SEV", "deg_urb=TOTAL", "unit=PC"], None, K["disability_onset"], "health.disability_prevalence", "% of persons", BANDS_HEALTH, "Eurostat-SILC",
       "Eurostat hlth_silc_20 lev_limit=SM_SEV deg_urb=TOTAL", notes="Self-perceived long-standing limitation in usual activities due to a health problem, some or severe (EU-SILC).")
    ev("hlth_ehis_am1e", ["duration=Y_LT1", "isco08=OC221", "isced11=TOTAL", "unit=PC"], None, K["doctor_visit"], "health.doctor_visit_12m", "% of persons", BANDS_EHIS, "Eurostat-EHIS",
       "Eurostat hlth_ehis_am1e duration=Y_LT1 isco08=OC221", notes="Last visit to a medical doctor less than one year ago (European Health Interview Survey, 2014 and 2019).")
    # informal care: sum of the three weekly-hours classes
    cells = jsonstat("ilc_ats18", "&".join(["deg_urb=TOTAL", "wstatus=POP", "unit=PC"] + [f"age={a}" for a in BANDS_HEALTH] + ["sex=F", "sex=M", "frequenc=LT10HW", "frequenc=10-19HW", "frequenc=GE20HW"]))
    sums = defaultdict(float)
    cnt = defaultdict(int)
    yrs = {}
    for idx, v in cells:
        if v is None:
            continue
        key = (idx["geo"], BANDS_HEALTH[idx["age"]], SEX[idx["sex"]])
        sums[key] += float(v)
        cnt[key] += 1
        yrs[key] = int(idx["time"])
    rows = {k: (s, yrs[k]) for k, s in sums.items() if cnt[k] == 3}
    for (region, band, sex), (v, y, note) in pooled(rows).items():
        k = K["caregiving_start"]
        out.append(mk(k, "health.informal_care_share", v, "% of persons", band, sex, region, y, "Eurostat-ilc_ats18", ES_URL.format("ilc_ats18"), "open", "medium" if region == "DEU" else "low",
                      f"Persons providing informal care or assistance at any weekly hours class (sum of three classes), 2016. {note}",
                      f"Persons providing informal care or assistance (sum of weekly-hours classes), {PLACES[region]}, {sex}, age {band}, {y}: {v:g}", "Eurostat ilc_ats18 frequenc in LT10HW,10-19HW,GE20HW"))
    for acl, key, qn in (("AC521", "cinema_visit", "leisure.cinema_12m"), ("AC522A", "live_performance", "leisure.live_performance_12m"),
                         ("AC523H", "cultural_site_visit", "leisure.cultural_site_12m"), ("AC525", "sports_event", "leisure.sports_event_12m")):
        ev("ilc_scp03", [f"acl00={acl}", "frequenc=GE1", "isced11=TOTAL", "unit=PC"], None, K[key], qn, "% of persons", BANDS_HEALTH, "Eurostat-SILC-scp",
           f"Eurostat ilc_scp03 acl00={acl} frequenc=GE1", notes="Participated at least once in the last 12 months (EU-SILC social and cultural participation module).")
    for code, key, qn, ds_notes in (("MV_AERO", "aerobic_sport", "leisure.aerobic_activity_150min", "Health-enhancing aerobic activity (at least 150 minutes a week)"),
                                    ("MV_MSC", "strength_training", "leisure.strength_2days", "Muscle-strengthening activity (at least two days a week)")):
        ev("hlth_ehis_pe9e", [f"physact={code}", "isced11=TOTAL", "unit=PC"], None, K[key], qn, "% of persons", BANDS_EHIS, "Eurostat-EHIS",
           f"Eurostat hlth_ehis_pe9e physact={code}", notes=ds_notes + " (European Health Interview Survey 2014 and 2019).")
    ev("hlth_ehis_pe3e", ["physact=MV_CYCL_GET", "isced11=TOTAL", "unit=PC"], None, K["cycling_trip"], "leisure.cycling_week", "% of persons", BANDS_EHIS, "Eurostat-EHIS",
       "Eurostat hlth_ehis_pe3e physact=MV_CYCL_GET", notes="Cycling to get to and from places (European Health Interview Survey 2014 and 2019).")
    for acl, key, qn in (("AC41A", "formal_volunteering", "civic.formal_volunteering_12m"), ("AC42A", "informal_volunteering", "civic.informal_volunteering_12m"),
                         ("AC43A", "active_citizenship", "civic.active_citizenship_12m")):
        ev("ilc_scp19", [f"acl00={acl}", "isced11=TOTAL", "unit=PC"], None, K[key], qn, "% of persons", BANDS_HEALTH, "Eurostat-SILC-scp",
           f"Eurostat ilc_scp19 acl00={acl}", notes="Participation in the last 12 months (EU-SILC social and cultural participation module).")
    return out


def no_age_series(dataset, query, keyfn):
    return pooled(latest(jsonstat(dataset, query), keyfn))


def work_and_harm_params():
    out = []
    K = catalog.BY_KEY
    # long-term unemployment share (% of unemployed)
    for (region, band, sex), (v, y, note) in no_age_series("une_ltu_a", "indic_em=LTU&age=Y15-74&sex=T&unit=PC_UNE", lambda i: (i["geo"], "all", "all")).items():
        out.append(mk(K["reemployment"], "work.long_term_unemployment_share", v, "% of the unemployed", "15-74", "all", region, y, "Eurostat-LFS", ES_URL.format("une_ltu_a"), "open",
                      "medium" if region == "DEU" else "low", f"Long-term unemployed (twelve months or more) as a share of all unemployed. {note}",
                      f"Long-term unemployment as % of unemployment, {PLACES[region]}, {y}: {v:g}", "Eurostat une_ltu_a indic_em=LTU unit=PC_UNE", timescale="weeks-months"))
    # share of employed with job tenure under 12 months
    cells = jsonstat("lfsa_egad", "duration=M0-11&unit=PC&age=Y15-24&age=Y15-64&sex=F&sex=M&sex=T")
    rows = latest(cells, lambda i: (i["geo"], {"Y15-24": "15-24", "Y15-64": "15-64"}[i["age"]], SEX[i["sex"]]))
    for (region, band, sex), (v, y, note) in pooled(rows).items():
        out.append(mk(K["job_change"], "work.new_job_share", v, "% of employed", band, sex, region, y, "Eurostat-LFS", ES_URL.format("lfsa_egad"), "open", "medium" if region == "DEU" else "low",
                      f"Employed persons whose current job began in the last 12 months (tenure 0 to 11 months). {note}",
                      f"Employed with job tenure under 12 months, {PLACES[region]}, {sex}, age {band}, {y}: {v:g}", "Eurostat lfsa_egad duration=M0-11 unit=PC"))
    # police-recorded offences per 100k
    icc = {"ICCS0502": ("theft_victim", "harm.theft_recorded_rate"), "ICCS0501": ("burglary_victim", "harm.burglary_recorded_rate"),
           "ICCS0401": ("robbery_victim", "harm.robbery_recorded_rate"), "ICCS020111": ("assault_victim", "harm.assault_recorded_rate"),
           "ICCS0301": ("sexual_violence_victim", "harm.sexual_violence_recorded_rate"), "ICCS0701": ("fraud_victim", "harm.fraud_recorded_rate")}
    d = json.loads(get(f"{ES}crim_off_cat?format=JSON&lang=en&geo=DE"))
    lab = d["dimension"]["iccs"]["category"]["label"]
    cyber = next((c for c, t in lab.items() if "computer" in t.lower()), None)
    if cyber:
        icc[cyber] = ("cyber_victim", "harm.cybercrime_recorded_rate")
    q = "&".join(f"iccs={c}" for c in icc) + "&unit=P_HTHAB"
    rows = latest(jsonstat("crim_off_cat", q), lambda i: (i["geo"], i["iccs"]))
    for (region, code), (v, y, note) in pooled(rows).items():
        key, qn = icc[code]
        out.append(mk(K[key], qn, v, "recorded offences per 100000 inhabitants per year", "all", "all", region, y, "Eurostat-crime", ES_URL.format("crim_off_cat"), "open",
                      "medium" if region == "DEU" else "low",
                      f"Police-recorded offences ({lab[code]}); recorded counts understate victimisation (not every offence is reported or recorded) and one victim can have several. {note}",
                      f"Police-recorded {lab[code].lower()}, {PLACES[region]}, {y}: {v:g} per 100000 inhabitants", f"Eurostat crim_off_cat iccs={code} unit=P_HTHAB"))
    for stat, key, qn, what in (("PER_SUSP", "suspected_offence", "harm.suspect_rate", "Suspected persons"), ("PER_CNV", "conviction", "harm.conviction_rate", "Convicted persons")):
        rows = latest(jsonstat("crim_just_sex", f"leg_stat={stat}&unit=P_HTHAB&sex=F&sex=M"), lambda i: (i["geo"], SEX[i["sex"]]))
        for (region, sex), (v, y, note) in pooled(rows).items():
            out.append(mk(K[key], qn, v, "persons per 100000 inhabitants per year", "all", sex, region, y, "Eurostat-crime", ES_URL.format("crim_just_sex"), "open",
                          "medium" if region == "DEU" else "low", f"{what} per 100000 inhabitants by sex (police and court statistics). {note}",
                          f"{what} per 100000 inhabitants, {PLACES[region]}, {sex}, {y}: {v:g}", f"Eurostat crim_just_sex leg_stat={stat} unit=P_HTHAB"))
    # births outside marriage
    d = jsonstat("demo_fagec", "age=TOTAL&indic_de=LBIRTH&indic_de=NMAR")
    tot, nm = {}, {}
    for idx, v in d:
        if v is None:
            continue
        (tot if idx["indic_de"] == "LBIRTH" else nm)[(idx["geo"], int(idx["time"]))] = float(v)
    share = {}
    for (g, t), n in nm.items():
        if (g, t) in tot and tot[(g, t)] > 0:
            share[(g, t)] = 100 * n / tot[(g, t)]
    rows = {}
    for (g, t), v in share.items():
        if g not in rows or t > rows[g][1]:
            rows[g] = (v, t)
    k = K["birth_of_child"] if "birth_of_child" in K else None
    from lifeimage.eventgen import events as evk
    for (region, *_), (v, y, note) in pooled({(g, "all"): x for g, x in rows.items()}).items():
        out.append(Param(field="c.birth_of_child", quantity="family.births_outside_marriage", value=v, unit="% of live births", age_band="all", sex="f", region=region, year=y,
                         source_id="Eurostat-demo_fagec", source_url=ES_URL.format("demo_fagec"), licence="open", confidence="medium" if region == "DEU" else "low",
                         notes=f"Live births outside marriage as a share of all live births (mother's legal marital status). {note}",
                         source_statement=f"Live births outside marriage, {PLACES[region]}, {y}: {v:.1f}% of live births",
                         snippet_locator="Eurostat demo_fagec indic_de=NMAR over LBIRTH, age=TOTAL", retrieved=TODAY,
                         event_snippets=[{"actor": f"A woman in {PLACES[region]}", "action": "gave birth to a child while not legally married", "outcome": "became a parent outside marriage",
                                          "timescale": "life transition", "domains": ["c.birth_of_child", "c.family_ties"], "source_id": "Eurostat-demo_fagec",
                                          "locator": "Eurostat demo_fagec indic_de=NMAR", "sanitization": "paraphrase of what the indicator counts; no individual record, name or place below country"}]))
    return out


# ---------------- World Bank, V-Dem and WHO ----------------
def wb_params():
    out = []
    K = catalog.BY_KEY
    for ind, qn, kind, unit, band, note in (("SH.STA.DIAB.ZS", "health.diabetes_prevalence", "chronic_condition_onset", "% of population 20-79", "20-79", "International Diabetes Federation estimate via WDI"),
                                            ("SH.DYN.AIDS.ZS", "health.hiv_prevalence", "hiv_diagnosis", "% of population 15-49", "15-49", "UNAIDS estimate via WDI"),
                                            ("SH.TBS.INCD", "health.tb_incidence", "infectious_illness", "per 100000 population per year", "all", "WHO estimate via WDI"),
                                            ("SL.IND.EMPL.ZS", "work.industry_employment", "industry_work_start", "% of employment", "15+", "ILO modelled estimate via WDI"),
                                            ("SL.SRV.EMPL.ZS", "work.services_employment", "service_work_start", "% of employment", "15+", "ILO modelled estimate via WDI")):
        url = f"https://api.worldbank.org/v2/country/{';'.join(STRATA)}/indicator/{ind}?format=json&mrnev=1&per_page=200"
        rows = json.loads(get(url))[1] or []
        for r in rows:
            code = r["countryiso3code"] or ""
            if code not in STRATA or r["value"] is None or int(r["date"]) < 2005:
                continue
            out.append(mk(K[kind], qn, r["value"], unit, band, "all", code, r["date"], "WB-WDI", f"https://data.worldbank.org/indicator/{ind}", "open", "medium", note,
                          f'{r["indicator"]["value"]}, {r["country"]["value"]}, {r["date"]}: {r["value"]:g}', f"World Bank WDI indicator {ind} (API v2, most recent value)"))
    return out


def vdem_params():
    out = []
    K = catalog.BY_KEY
    raw = get("https://ourworldindata.org/grapher/voter-turnout-of-registered-voters.csv?v=1&csvType=full&useColumnShortNames=true").decode("utf-8")
    best = {}
    for r in csv.DictReader(io.StringIO(raw)):
        if r["turnout_vdem"] and r["code"]:
            y = int(r["year"])
            if r["code"] not in best or y > best[r["code"]][1]:
                best[r["code"]] = (float(r["turnout_vdem"]), y, r["owid_region"])
    loc = "Our World in Data grapher voter-turnout-of-registered-voters (V-Dem v-dem turnout), latest election"
    for code in ("KEN", "IND", "DEU", "BRA", "USA", "EGY", "CHN"):
        if code in best:
            v, y, _ = best[code]
            out.append(mk(K["voting"], "civic.voter_turnout", v, "% of registered voters", "all", "all", code, y, "OWID-VDem", "https://ourworldindata.org/grapher/voter-turnout-of-registered-voters",
                          "open-sa", "medium", "Turnout in the latest national election recorded by V-Dem (via Our World in Data, CC BY; V-Dem data CC BY-SA 4.0).",
                          f"Voter turnout of registered voters, {PLACES[code]}, {y}: {v:g}", loc, timescale="minutes/hours"))
    eu = [(c, b) for c, b in best.items() if b[2] == "Europe"]
    if len(eu) >= 5:
        v = sum(b[0] for _, b in eu) / len(eu)
        y = max(b[1] for _, b in eu)
        out.append(mk(K["voting"], "civic.voter_turnout", v, "% of registered voters", "all", "all", "ECS", y, "OWID-VDem", "https://ourworldindata.org/grapher/voter-turnout-of-registered-voters",
                      "open-sa", "low", f"Unweighted mean of the latest turnout of {len(eu)} European countries in V-Dem (OWID region Europe) stands for the ECS stratum.",
                      f"Voter turnout of registered voters, Europe and Central Asia (mean of {len(eu)} countries), {y}: {v:.1f}", loc, timescale="minutes/hours"))
    return out


def who_params():
    html = get("https://www.who.int/news-room/fact-sheets/detail/disability-and-health").decode("utf-8", "replace")
    text = re.sub(r"<[^>]+>", " ", html)
    m = re.search(r"([\d.]+)\s*billion people[^.]{0,200}?(\d+)\s*%", text)
    if not m:
        return []
    k = catalog.BY_KEY["disability_onset"]
    pct = float(m.group(2))
    return [mk(k, "health.disability_prevalence", pct, "% of persons", "all", "all", "WLD", 2023, "WHO-disability", "https://www.who.int/news-room/fact-sheets/detail/disability-and-health",
               "non-commercial", "medium", "WHO fact sheet: share of the world population living with a significant disability (statistic only; page licence is non-commercial).",
               f"WHO fact sheet on disability and health: about {m.group(1)} billion people, {pct:g}% of the world's population, live with significant disability", "WHO fact sheet disability-and-health, key facts")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=None)
    a = ap.parse_args()
    work = Path(a.work or tempfile.mkdtemp(prefix="eventgen_fetch_domains_"))
    work.mkdir(parents=True, exist_ok=True)
    CACHE["dir"] = work
    parts = {}
    for name, fn in (("hetus", hetus_params), ("india", lambda: india_params(work)), ("eurostat", eurostat_params), ("work_harm", work_and_harm_params),
                     ("wb", wb_params), ("vdem", vdem_params), ("who", who_params)):
        try:
            parts[name] = fn()
        except Exception as exc:   # a source that cannot be read leaves its strata missing; the generator degrades loudly
            print(f"SOURCE FAILED {name}: {exc!r}", file=sys.stderr)
            parts[name] = []
    params = [p for ps in parts.values() for p in ps]
    params = relationalise_params(params)
    Table(params)   # validates and rejects duplicate keys (also against nothing else: v1 is a separate file; duplicates across files fail at load)
    dump_params(params, CAL_DIR / "aggregates_v2_domains.jsonl")
    print({k: len(v) for k, v in parts.items()}, f"{len(params)} params, quantities {len({p.quantity for p in params})}")


if __name__ == "__main__":
    main()
