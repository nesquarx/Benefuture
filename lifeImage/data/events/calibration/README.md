# Calibration table (aggregates only)

`aggregates_v1.jsonl` holds one published aggregate per row (rate, share or mean for a quantity, age band, sex, region and year) with its source,
URL, licence class, confidence, source statement and event snippets (`lifeimage/eventgen/calibration.py` describes the schema and checks it).
Sources: World Bank WDI API (CC BY 4.0), UN WPP 2024 (fertility by age, demographic indicators; CC BY 3.0 IGO believed, terms page not fetched),
ILOSTAT modelled labour participation (licence `unread`), Eurostat divorce indicators (CC BY 4.0). Rebuilt by `tools/eventgen_fetch.py`.
Region strata: seven countries (KEN IND DEU BRA USA CHN EGY), seven World Bank regions and the world; missing strata are left missing and degrade loudly.

`aggregates_v2_domains.jsonl` (rebuilt by `tools/eventgen_fetch_domains.py`, 2065 rows) adds the domain Params of increment 3: Eurostat (HETUS time use `tus_00age` 2000/2010 by sex and
age band for 38 activities, disability `hlth_silc_20`, doctor visits and physical activity from EHIS, informal care `ilc_ats18`, cultural, sport and voluntary participation
`ilc_scp03`/`ilc_scp19`, job tenure `lfsa_egad`, long-term unemployment `une_ltu_a`, police-recorded offences `crim_off_cat`, suspects and convictions `crim_just_sex`, births by the mother's
marital status `demo_fagec`; CC BY 4.0), India's national time-use survey 2019 (MoSPI report, Statements 9 and 10, all-India rural plus urban, 9 activity groups; text extracted with
pdftotext), WDI (diabetes, HIV, tuberculosis, industry and services employment), voter turnout (V-Dem via Our World in Data, CC BY / CC BY-SA), and one WHO fact-sheet statistic
(disability prevalence; statistic only, non-commercial page). The `ECS` stratum of a Eurostat series is the unweighted mean of the countries the series covers (named in the Param's notes;
Germany is kept as a country). Strata a source lacks stay missing (Kenya and India have no Eurostat series).
Not filled: ATUS (BLS returned 403 on every route tried: the `tus` tables, the PDF tables and the index page), religious attendance (no aggregate retrievable by API; the generator
uses a governed default, recorded as degraded), OECD Family Database SF2.4 and DHS STATcompiler first-birth-before-marriage aggregates (no usable indicator; see BACKPROPAGATION P.EG3.2).
