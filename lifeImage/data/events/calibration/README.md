# Calibration table (aggregates only)

`aggregates_v1.jsonl` holds one published aggregate per row (rate, share or mean for a quantity, age band, sex, region and year) with its source,
URL, licence class, confidence, source statement and event snippets (`lifeimage/eventgen/calibration.py` describes the schema and checks it).
Sources: World Bank WDI API (CC BY 4.0), UN WPP 2024 (fertility by age, demographic indicators; CC BY 3.0 IGO believed, terms page not fetched),
ILOSTAT modelled labour participation (licence `unread`), Eurostat divorce indicators (CC BY 4.0). Rebuilt by `tools/eventgen_fetch.py`.
Region strata: seven countries (KEN IND DEU BRA USA CHN EGY), seven World Bank regions and the world; missing strata are left missing and degrade loudly.
Not filled: time-use shares from ATUS and HETUS (BLS returned 403; HETUS tables not fetched) and victimisation survey tables beyond the WDI partner-violence series.
