# Event source scout: datasets and models for large synthetic life-course event sets

Scouted 2026-11-25 (Life Image, branch `claude/inspiring-cannon-uxvdxq`). Scout only: nothing was downloaded into the repository, no LLM runner batches were used.

## 0. Brief, rulings and goal

Rulings that frame this scout. LI.61 (author, relayed by the lead): event-generation datasets are never shipped; everything here is internal calibration, and the library consumes events either preformatted or categorised by an agent. The LI.17, LI.19, LI.56 and LI.57 shipping rules (permissive attribution or public domain only; no ShareAlike, NoDerivatives or NonCommercial; ICATUS and COICOP calibration-only) therefore do not decide classes here; they stay in force for anything that would enter the basemap. The data constraints still hold: anonymised or synthetic data only, no identities saved except public figures (LI.15), no real underage person identified, posts never saved except derived de-identified features. The direction for this scout is global and multilingual, not US/UK-centred, and it includes social-media research data.

**Classes (replacing SHIP/CALIBRATION).**
- USABLE: the terms allow our internal research use (open, registration, or a data-use agreement we could plausibly sign as a non-profit research project).
- COSTLY: access needs an institutional agreement, an approval programme, a paid licence or an enclave; the row says what it takes.
- EXCLUDED: the terms forbid this use outright.

Non-commercial-only terms (ESS, WVS, GGP, SHARE, WHO, IHME) are USABLE on the reading that Life Image is a non-profit research project; the author should confirm that reading once. Terms that ban AI tools or model training on the rows (SHARE, SOEP, Add Health's AI/LLM policy, Reddit derivative models, Stack Exchange since 2024, Mastodon.social) are binding in a way the older scout never met: they allow code-run parameter fitting by a named user and forbid an agent reading rows, or training on them. The pipeline in section 6 is built to respect that (statistics are fitted by code; agents see only synthetic events and derived aggregates).

**Goal of the synthesis (author).** A calibration dataset and a generator that produce realistic events, as text (a first-person post, a diary line, a record) or preformatted (fields, memberships), covering essentially any part of the circle, re-targetable as the domains keep being refined (fine domains added or split without rebuilding). Generator and verifier are trained adversarially against each other: the generator proposes events for a target domain mix and life stage; a verifier calibrated on real-world sources (panels, rates, social posts) judges real-world-ness, and its judgements feed back to the generator. Section 6 proposes this concretely.

**Lead's prediction, final form (confidence 0.5).** At least 15 usable sources across every life stage, with at least one usable source per world region (Sub-Saharan Africa, MENA, South Asia, East Asia and Pacific, Latin America, Europe and Central Asia, North America) for education, work and family; at least 80% of the 247 coarse fields reachable from usable sources; panels give real sequences for education, work and family while hobbies, social and harm mostly come as rates; at least 5 usable social-media sources with research terms covering at least 3 non-English languages. Judged in section 8.

**How licence evidence was read.** Words in quotation marks were read on the page named (fetched) or in a search summary of that page (via search); where a page returned 403 or 404, or only a recollection exists, the row says so. Licences move; the author confirms each source before ingestion. Confidence is in the reading, not in the source's quality.

**Method note on coverage.** Field reach in section 4 is computed from a sector-level mapping (each source reaches named groups of the 247 fields), which overstates. It is therefore audited on a random sample of 30 fields judged by hand.

Legend. Granularity: P panel or event sequences; I individual records or diaries; A aggregate rates; T text; M model or tool. Stages: B birth and early health, C childhood and school, Y youth transitions, A adult, O later life. Domains: E education, W work, F family, H health, K harm, V social and civic, L leisure.


## 1. Source register (80 entries: 68 usable, 10 costly, 2 excluded)


### 1.1 Multi-country harmonised surveys and regional panels (global core)

| ID | Source | Terms (words and evidence) | Class | Granularity | Stages | Regions | Languages; multilingual instruments | Reaches | Conf. |
|---|---|---|---|---|---|---|---|---|---|
| DHS | DHS Program (https://dhsprogram.com) | Registration required; data used only for the registered study, not passed on without written consent, publications sent to DHS. https://dhsprogram.com/data/terms-of-use.cfm (read via search summary; direct fetch returned 403). | USABLE | panel / event sequences | BCYAO | SSA MENA SA EAP LAC ECA | English, French, Spanish plus national-language fieldwork; yes (national languages) | FAM, HEALTH, EDU, MOB; domains EWFHK | medium |
| MICS | UNICEF MICS (https://mics.unicef.org/surveys; IPUMS MICS https://mics.ipums.org) | Free registration, UNICEF reviews each request; access "solely for research purposes"; redistribution questions go to UNICEF. https://mics.ipums.org/mics/register.shtml (via search summary). | USABLE | panel / event sequences | BCYAO | SSA MENA SA EAP LAC ECA | questionnaires in national languages (list not verified); yes (not verified) | FAM, HEALTH, EDU, CRIME; domains EWFHK | medium |
| YL | Young Lives (UK Data Service, https://www.younglives.org.uk/data) | Registration with UKDS and confidentiality agreement; location data and some teacher data withheld; Vietnam absent from round 7. https://www.younglives.org.uk/data (via search). | USABLE | panel / event sequences | BCYA | SSA SA EAP LAC | Amharic, Oromiffa, Tigrinya, Telugu, Spanish, Quechua, Vietnamese (not verified); yes (not verified) | EDU, WORK, FAM, HEALTH, CRIME, SOC; domains EWFHKV | medium |
| GGP | Generations and Gender Programme (https://www.ggp-i.org/data-access) | "free for non-commercial use, and micro data requires registering ... and signing the relevant data agreement"; no re-identification. https://ggp-i.org/data-access (via search). | USABLE | panel / event sequences | YAO | ECA EAP LAC | national languages on the GGP Colectica portal; yes | FAM, WORK, HOME, MOB, SOC; domains FW | medium |
| SHARE | SHARE (https://share-eric.eu/data/data-access) | Individual registration, signed User Statement; research only, commercial use prohibited, no third parties, "AI tools" listed among prohibited recipients. https://share-eric.eu/data/data-access/conditions-of-use (via search). Code-run parameter fitting by a named user is the compatible use; agent reading of rows is not. | USABLE | panel / event sequences | AO | ECA | all survey languages (28 EU states plus Israel); yes | FAM, HEALTH, WORK, HOME, CIVIC, SOC, MOB; domains FWHK | medium |
| ESS | European Social Survey (https://europeansocialsurvey.org) | Data CC BY-NC-SA 4.0, documentation CC BY-SA 4.0; free after short DataPortal registration for non-commercial use. https://europeansocialsurvey.org/node/58 (via search). | USABLE | individual records or diaries | YAO | ECA | about 30 languages; yes | CIVIC, SOC, MEAN, CRIME, HEALTH; domains VKF | medium |
| WVS | World Values Survey (https://www.worldvaluessurvey.org/AJDownloadLicense.jsp) | "available without restrictions" provided non-profit use, citation sent to the WVS Association, no redistribution; registration. https://www.worldvaluessurvey.org/AJDownloadLicense.jsp (via search). | USABLE | individual records or diaries | YAO | SSA MENA SA EAP LAC ECA NA | English master, translated into every language spoken by 15% or more of the population; yes | MEAN, CIVIC, SOC, FAM; domains VF | medium |
| ISSP | ISSP (https://issp.org/data-download/archive/; GESIS https://gesis.org/en/issp) | Free download after simple registration for scientific use; commercial use not permitted for most GESIS data. https://gesis.org/en/issp (via search). | USABLE | individual records or diaries | YAO | SSA SA EAP LAC ECA NA | national languages (not enumerated); yes | WORK, FAM, MEAN, CIVIC, LEIS, HEALTH, SOC; domains WFVL | medium |
| AFRO | Afrobarometer (https://www.afrobarometer.org/data/data-usage-and-access-policy/) | Data free but copyrighted, specific citation required; geocoded and early-access data need an application. https://www.afrobarometer.org/data/data-usage-and-access-policy/ (via search). | USABLE | individual records or diaries | YAO | SSA | dozens of local languages (not verified); yes (not verified) | CIVIC, CRIME, MEAN, WORK, MONEY; domains VK | medium |
| ARAB | Arab Barometer (https://www.arabbarometer.org) | Data download free of charge; publications copyrighted, reprint by permission (https://www.arabbarometer.org/policies/, via search). | USABLE | individual records or diaries | YAO | MENA | Arabic, English, French; yes | CIVIC, MEAN, FAM, WORK, CRIME; domains VK | low |
| LATINO | Latinobarometro (https://www.latinobarometro.org) | The one licence found is a university-specific agreement excluding commercial purposes (https://ecollections.library.yale.edu/Latinobarometro.pdf); public terms not read. | USABLE | individual records or diaries | YAO | LAC | Spanish, Portuguese; yes (not verified) | CIVIC, CRIME, MEAN, WORK; domains VK | low |
| ABAR | Asian Barometer / Global Barometer (https://www.asianbarometer.org) | Terms not found; read before use. | USABLE | individual records or diaries | YAO | EAP SA | national languages; yes (not verified) | CIVIC, MEAN, CRIME, WORK; domains VK | low |
| GALLUP | Gallup World Poll (https://www.gallup.com/analytics/318875/global-research.aspx) | Commercial licence, academic access via institutions; terms not fetched. Rows would need a paid or institutional licence. | COSTLY | individual records or diaries | YAO | SSA MENA SA EAP LAC ECA NA | 140+ countries, 100+ languages (recollection); yes | WORK, HEALTH, CIVIC, SOC, CRIME, MONEY; domains WKVH | low |
| IPUMSI | IPUMS International, IPUMS DHS/MICS/PMA/USA/CPS/Time Use (https://www.ipums.org/about/terms) | "You will not redistribute the data without permission"; International and PMA bar "any commercial or income-generating venture"; each team member licensed (fetched https://www.ipums.org/about/terms). | USABLE | individual records or diaries | BCYAO | SSA MENA SA EAP LAC ECA NA | documentation English, Spanish, French; partly | FAM, EDU, WORK, MOB, HEALTH, HOME; domains EWFMOB | high |
| LSMS | World Bank LSMS-ISA and Microdata Library panels (https://microdata.worldbank.org) | Per-dataset public-use licence, registration, citation (https://microdata.worldbank.org, not read per dataset). | USABLE | panel / event sequences | CYAO | SSA SA LAC EAP ECA | English plus local-language questionnaires (not verified); yes (not verified) | WORK, EDU, FAM, HEALTH, MOB, MONEY, DIS, NAT; domains EWFHK | medium |
| SWTS | ILO School-to-Work Transition Surveys (https://www.ilo.org/surveys) | ILO microdata catalogue; terms not read. | USABLE | panel / event sequences | Y | SSA MENA SA EAP LAC ECA | English, French, Spanish, national; yes (not verified) | EDU, WORK, FAM, OCC; domains EW | low |
| ERF | ERF OAMDI: Egypt, Jordan, Tunisia labour market panels (https://www.erfdataportal.com) | Open-access microdata portal, registration; terms not read. | USABLE | panel / event sequences | YAO | MENA | Arabic questionnaires, English documentation; yes (not verified) | WORK, EDU, FAM, MOB, OCC; domains EWF | low |
| GAGE | GAGE adolescent panels (https://www.gage.odi.org) | UKDS-hosted, registration; terms not read. Real minors, anonymised (LI.15). | USABLE | panel / event sequences | CY | SSA SA MENA | Arabic, Amharic, Bangla, Nepali, others (recollection); yes (not verified) | EDU, FAM, HEALTH, CRIME, SOC; domains EFHK | low |
| GSHS | WHO/CDC GSHS and HBSC (https://www.who.int/teams/noncommunicable-diseases/surveillance/systems-tools/global-school-based-student-health-survey; https://hbsc.org) | GSHS public datasets; HBSC through application to its data bank (C). Terms not read. | USABLE | individual records or diaries | CY | SSA MENA SA EAP LAC ECA NA | national languages, WHO six languages for instruments; yes | HEALTH, CRIME, SOC, EDU, LEIS; domains EKHV | low |
| GKO | Global Kids Online / EU Kids Online (https://www.unicef.org/innocenti/projects/global-kids-online) | Open data per country (recollection); terms not read. | USABLE | individual records or diaries | CY | SSA MENA SA EAP LAC ECA | multiple; yes (not verified) | SOC, CRIME, LEIS, SCI; domains VK | low |
| VACS | Violence Against Children and Youth Surveys (CDC/Together for Girls) | Datasets by request (recollection); terms not read. | USABLE | individual records or diaries | YA | SSA SA EAP LAC | national languages; yes | CRIME; domains K | low |

### 1.2 National and regional panels outside the US and UK

| ID | Source | Terms (words and evidence) | Class | Granularity | Stages | Regions | Languages; multilingual instruments | Reaches | Conf. |
|---|---|---|---|---|---|---|---|---|---|
| CHARLS | CHARLS (https://charls.pku.edu.cn/en) | Sign up, accept agreement, request per dataset; "free for research", identifiers stripped (via search, g2aging.org). | USABLE | panel / event sequences | OA | EAP | Chinese, English documentation; partly | HEALTH, FAM, WORK, HOME, MONEY; domains FHW | medium |
| CFPS | China Family Panel Studies (https://www.isss.pku.edu.cn/cfps/en) | DUA: cite, no redistribution, academic or policy research only, notify publications; restricted geocodes at approved sites (via search). | USABLE | panel / event sequences | BCYAO | EAP | Chinese, English documentation; partly | FAM, EDU, WORK, HEALTH, CRIME, SOC, LEIS, MONEY; domains EWFHK | medium |
| IFLS | Indonesia Family Life Survey (https://www.rand.org/health/surveys/FLS/IFLS.html) | Registration; no identification attempts, no redistribution, citations sent to RAND; restricted community coordinates separate (via search). | USABLE | panel / event sequences | CYAO | EAP | Indonesian, English; partly | FAM, EDU, WORK, HEALTH, MOB, MONEY; domains FEWH | medium |
| IHDS | India Human Development Survey and LASI (https://www.ihds.umd.edu; https://www.iipsindia.ac.in/lasi) | IHDS via ICPSR, LASI via registration; terms not read. | USABLE | panel / event sequences | YAO | SA | Hindi, English, regional (not verified); yes (not verified) | FAM, EDU, WORK, HEALTH, HOME, MONEY; domains EWFH | low |
| MEX | MxFLS, MHAS (Mexico) and Chile EPS | Open registration (recollection); terms not read. | USABLE | panel / event sequences | YAO | LAC | Spanish; yes | FAM, WORK, HEALTH, MOB, MONEY; domains EWFH | low |
| NIDS | South Africa NIDS and Time Use Survey via DataFirst (https://www.datafirst.uct.ac.za) | Registration, per-dataset licence; terms not read. | USABLE | panel / event sequences | CYAO | SSA | English, Afrikaans, isiZulu, others (not verified); partly | FAM, WORK, EDU, HEALTH, HOME, MONEY; domains EWFH | low |
| KLIPS | Korea KLIPS, KLoSA (https://www.kli.re.kr/klips_eng) | Download from the Korea Labor Institute; access procedure not verified (official source not reached). | USABLE | panel / event sequences | YAO | EAP | Korean questionnaires; English documentation partial; partly | WORK, FAM, EDU, MONEY, HOME; domains EWF | low |
| JHPS | Japan JHPS/KHPS Keio Panel (https://www.pdrc.keio.ac.jp/en) | "provides microdata for nonprofit and academic purposes only", free, project registration in its Data Management System (2020 manual, via search). | USABLE | panel / event sequences | YAO | EAP | Japanese, English documentation; partly | FAM, WORK, HEALTH, HOME, MONEY; domains EWF | medium |
| BRPNAD | Brazil PNAD Continua and IBGE microdata (https://www.ibge.gov.br) | Free download from IBGE FTP; explicit licence not found (via search). | USABLE | individual records or diaries | CYAO | LAC | Portuguese; no | WORK, EDU, FAM, HOME, MOB, MONEY; domains EWFMOB | low |
| RLMS | Russia RLMS-HSE and EBRD Life in Transition Survey (https://www.hse.ru/en/rlms) | Free registration (recollection); terms not read. | USABLE | panel / event sequences | YAO | ECA | Russian and national languages; yes (not verified) | WORK, FAM, HEALTH, MONEY, EDU, CIVIC; domains EWFH | low |
| SOEP | SOEP (https://www.diw.de/en/diw_02.c.238223.en/soep_conditions.html) | Signed data distribution contract, research institution only, project-bound, named users, free; commercial use only to a very limited extent for a fee; "use of SOEP data in AI applications ... is not permitted" (via search of diw.de). | COSTLY | panel / event sequences | BCYAO | ECA | German, English documentation; partly | FAM, EDU, WORK, HEALTH, HOME, MONEY, MOB, CIVIC, SOC, LEIS, MEAN; domains EWFHK | medium |
| HILDA | HILDA and LSAC (https://dss.gov.au/long-term-research/accessing-our-datasets) | Approved researchers from government, academic or non-profit bodies, ADA Dataverse request plus signed Confidentiality Deed Poll; no commercial emails (via search). | COSTLY | panel / event sequences | BCYAO | EAP | English; no | FAM, EDU, WORK, HEALTH, HOME, MONEY, CIVIC, SOC, LEIS; domains EWFHK | medium |
| CNEF | Cross-National Equivalent File (https://cnef.ehe.osu.edu) | Each country subset approved separately by its data manager; PSID-CNEF open, SOEP via DIW contract, HILDA by permission (via search, DIW access procedures). | COSTLY | panel / event sequences | AO | NA ECA EAP | English variables; no | WORK, FAM, MONEY, EDU; domains WEF | medium |
| TRAM | TraMineR sequence datasets mvad, biofam (CRAN) | GPL package data; internal use only. | USABLE | panel / event sequences | YAO | ECA | English; no | EDU, WORK, FAM; domains EWF | medium |

### 1.3 US and UK panels, cohorts and diaries

| ID | Source | Terms (words and evidence) | Class | Granularity | Stages | Regions | Languages; multilingual instruments | Reaches | Conf. |
|---|---|---|---|---|---|---|---|---|---|
| UKHLS | UKDS panels: Understanding Society, MCS, BCS70, NCDS, Next Steps, ELSA (https://ukdataservice.ac.uk/conditions) | Safeguarded tier: register and accept the End User Licence; special licence and special conditions tiers above it; commercial wording of the EUL not read (via search). | USABLE | panel / event sequences | BCYAO | ECA | English (some Welsh); no | FAM, EDU, WORK, HEALTH, HOME, MONEY, CIVIC, SOC, LEIS, CRIME, MOB, MEAN; domains EWFHKVL | medium |
| ADDH | Add Health public-use and restricted-use (https://addhealth.cpc.unc.edu/data) | Public-use: DUA, "solely for statistical analyses", AI/LLM policy, no distribution; restricted-use needs a Secure Research Workspace or home-institution contract and bars linkage (via search). Public-use is U, restricted is C. | USABLE | panel / event sequences | CYA | NA | English; no | EDU, FAM, HEALTH, CRIME, SOC, SCI; domains EFHKV | medium |
| PSID | PSID, NLSY79/97, HRS (US panels) | Free registration (recollection); nlsinfo.org terms page returned 404, PSID and HRS terms not fetched. Read before use. | USABLE | panel / event sequences | BCYAO | NA | English, Spanish partial; no | FAM, EDU, WORK, HEALTH, HOME, MONEY, MOB, CIVIC, OCC; domains EWFHVL | low |
| MTUS | Multinational Time Use Study (https://www.timeuse.org/mtus) | Free, individual application; "no selling or profiting from distributing" any element; no passing on without permission; IPUMS MTUS-X: register, subset only for journals (via search). | USABLE | individual records or diaries | CYAO | NA ECA EAP SSA LAC | English harmonisation, 25+ countries; no | HOME, LEIS, SOC, WORK, FAM, HEALTH; domains L | medium |
| HETUS | Eurostat HETUS microdata plus national time-use surveys beyond US/UK (INSEE, Destatis, StatCan, India NSO 2019, Japan e-Stat, Korea, China 2018, South Africa 2010, Mexico ENUT) | HETUS scientific-use files only for universities and certified research centres, confidentiality declaration; round 2010 for about 17 to 18 countries; 2020 round not before 2027 (via search of Eurostat). Tables are CC BY 4.0 (see EUROSTAT). | COSTLY | individual records or diaries | CYAO | ECA EAP SA SSA LAC NA | national languages; partly | HOME, LEIS, SOC, WORK, FAM, HEALTH; domains L | medium |
| ATUS | BLS American Time Use Survey (https://www.bls.gov/tus/data.htm) | BLS content "in the public domain, except for previously copyrighted photographs and illustrations" (https://www.bls.gov/opub/copyright-information.htm, fetched). | USABLE | individual records or diaries | CYAO | NA | English, Spanish; no | HOME, LEIS, SOC, WORK, FAM, HEALTH, CIVIC, MEAN; domains L | high |

### 1.4 Statistics and aggregate rates

| ID | Source | Terms (words and evidence) | Class | Granularity | Stages | Regions | Languages; multilingual instruments | Reaches | Conf. |
|---|---|---|---|---|---|---|---|---|---|
| BLS | BLS CPS, JOLTS, Consumer Expenditure; O*NET (https://www.onetcenter.org/license_db.html) | BLS public domain (fetched); O*NET "licensed under a Creative Commons Attribution 4.0 International License" (fetched). | USABLE | aggregate rates | YAO | NA | English; O*NET Spanish; no | WORK, OCC, MONEY, EDU; domains WE | high |
| CENSUS | US Census ACS, PUMS, SIPP, LEHD; SSA tables | US government work, use for statistics only, no identification (https://www.census.gov/data/developers/about/terms-of-service.html, fetched for the API). | USABLE | individual records or diaries | BCYAO | NA | English, Spanish; no | FAM, EDU, WORK, MOB, HOME, MONEY, CIVIC; domains EWFMOB | medium |
| NCHS | NCHS NSFG, NHANES, NHIS, NVSS, CDC milestones and growth charts (https://www.cdc.gov/other/agencymaterials.html) | "Most of the information on the CDC ... websites is not subject to copyright"; four conditions (attribute, no endorsement, no change, free on agency site). NCHS DUA: "statistical reporting and analysis only", no linkage (https://www.cdc.gov/nchs/data_access/restrictions.htm, fetched). | USABLE | individual records or diaries | BCYAO | NA | English, Spanish; no | FAM, HEALTH, CRIME; domains HFK | high |
| CRIMEUS | BJS NCVS, FBI NIBRS, CDC YRBS, NISVS, NCANDS, NHTSA FARS, OpenFEMA | US government works; BJS and FBI pages not fetched (403); NIBRS codes ruled public domain in LI.56. | USABLE | aggregate rates | CYAO | NA | English; no | CRIME, WAR, MOB, DIS; domains K | medium |
| NCES | NCES NAEP, ECLS, IPEDS, College Scorecard | US government publications; copyright page fetched but did not state it; read before use. | USABLE | aggregate rates | BCY | NA | English; no | EDU, OCC; domains E | low |
| ONS | UK ONS: Census 2021, LFS, vital statistics, CSEW; Sport England Active Lives; DCMS Taking Part (https://www.ons.gov.uk/help/termsandconditions) | ONS: "All content is available under the Open Government Licence v3.0" except third-party items (fetched). Active Lives page states no licence (fetched). | USABLE | aggregate rates | BCYAO | ECA | English; no | FAM, WORK, MOB, HOME, CRIME, LEIS, CIVIC, SOC, HEALTH; domains EWFHKL | high |
| EUROSTAT | Eurostat database (https://ec.europa.eu/eurostat/web/main/help/copyright-notice) | "licensed under the Creative Commons Attribution 4.0 International licence"; commercial reuse authorised with source; exceptions for third-party data (fetched). | USABLE | aggregate rates | BCYAO | ECA | English, French, German (database), national languages in metadata; partly | FAM, EDU, WORK, HOME, HEALTH, CRIME, LEIS, CIVIC, SOC, MOB, MONEY; domains EWFHKVL | high |
| WB | World Bank Open Data and gender statistics (https://datacatalog.worldbank.org/public-licenses) | "licenses datasets under the Creative Commons Attribution 4.0 International license"; microdata under a separate research licence (fetched). | USABLE | aggregate rates | BCYAO | SSA MENA SA EAP LAC ECA NA | English, French, Spanish, Arabic, Chinese; yes | FAM, EDU, WORK, HEALTH, MONEY; domains EWFH | high |
| ILOSTAT | ILOSTAT (https://ilostat.ilo.org) | Terms page returned 403; ILO open data licence believed CC BY 4.0, not verified. | USABLE | aggregate rates | YAO | SSA MENA SA EAP LAC ECA NA | English, French, Spanish; yes | WORK, OCC, MONEY, CIVIC; domains W | low |
| UIS | UNESCO UIS (https://uis.unesco.org/terms-and-conditions) | "Creative Commons Attribution-ShareAlike 3.0 IGO" on the terms page; data browser names CC BY-SA 4.0 (via search). | USABLE | aggregate rates | CYA | SSA MENA SA EAP LAC ECA NA | English, French, Spanish; yes | EDU, SCI; domains E | medium |
| UNDESA | UN DESA World Population Prospects, UNICEF data, UNHCR Refugee Data, IOM portal | Licences believed CC BY 3.0 IGO and CC BY 4.0, not fetched. | USABLE | aggregate rates | BCYAO | SSA MENA SA EAP LAC ECA NA | English, French, Spanish; yes | FAM, HEALTH, MOB, WAR, EDU; domains FHEW | low |
| OECD | OECD: PISA, TALIS, Education at a Glance, Family Database, Time Use (https://www.oecd.org) | Terms page returned 403; PISA public-use microdata free (recollection). | USABLE | aggregate rates | CYAO | ECA NA EAP LAC MENA SSA SA | PISA instruments in 90+ languages (recollection); yes | EDU, FAM, WORK, SOC, LEIS, SCI; domains EWFL | low |
| IEA | IEA TIMSS, PIRLS, ICCS, ICILS (https://www.iea.nl/data-tools/repository) | "accessing IEA Public Use Data does not require requesting permission"; restricted items non-commercial (via search). Students are minors; anonymised, aggregate use only. | USABLE | individual records or diaries | C | SSA MENA SA EAP LAC ECA NA | national languages, 50+ systems; yes | EDU, CIVIC, SCI, SOC; domains E | medium |
| UNODC | UNODC data portal; ICVS (https://dataunodc.un.org/node/651) | Data "free of charge and may be copied freely ... provided that UNODC is cited"; victimisation microdata under a separate Declaration, requests via the survey office (via search). ICVS terms not found. | USABLE | aggregate rates | YAO | SSA MENA SA EAP LAC ECA NA | English, French, Spanish; yes | CRIME, WAR; domains K | medium |
| UCDP | UCDP, ACLED, Global Terrorism Database, EM-DAT | UCDP "licensed under CC BY 4.0" (fetched https://ucdp.uu.se/downloads/); ACLED, GTD, EM-DAT non-commercial, not read. | USABLE | aggregate rates | YAO | SSA MENA SA EAP LAC ECA | English; no | WAR, CRIME, DIS; domains K | medium |
| OWID | Our World in Data (https://ourworldindata.org/faqs) | "Data produced by us falls under our permissive CC BY license"; third-party data keeps its provider licence (fetched). | USABLE | aggregate rates | BCYAO | SSA MENA SA EAP LAC ECA NA | English; no | FAM, HEALTH, EDU, WORK, CRIME; domains EWFHK | high |
| GBDWHO | WHO GHO and WHO Motor Development windows; GBD (IHME); HMD and HFD; WHO SAGE | WHO and IHME terms are non-commercial (recollection, not fetched); HMD/HFD registration. Not shipped, so NC and SA do not bind internal use. | USABLE | aggregate rates | BCYAO | SSA MENA SA EAP LAC ECA NA | English, UN languages; partly | HEALTH, FAM, CRIME; domains H | low |

### 1.5 Biography, ontology and multilingual text

| ID | Source | Terms (words and evidence) | Class | Granularity | Stages | Regions | Languages; multilingual instruments | Reaches | Conf. |
|---|---|---|---|---|---|---|---|---|---|
| WIKIDATA | Wikidata public-figure careers (https://www.wikidata.org/wiki/Wikidata:Licensing) | CC0 for structured data (earlier scout, not re-fetched). Public figures only (LI.15). | USABLE | panel / event sequences | BCYAO | SSA MENA SA EAP LAC ECA NA | labels in hundreds of languages (count not verified); yes | EDU, OCC, FAM, CIVIC, LEIS, WAR, MEAN, CRIME, MOB; domains EWFVL | medium |
| WIKIBIO | Multilingual Wikipedia biographies of public figures (Wikipedia text under CC BY-SA) | Text CC BY-SA 4.0; with nothing shipped (LI.61) ShareAlike does not bind internal use. Used as multilingual categorisation test text, public figures only. | USABLE | text | BCYAO | SSA MENA SA EAP LAC ECA NA | 300+ language editions (recollection); yes | EDU, OCC, FAM, CIVIC, LEIS, WAR, MEAN, CRIME, MOB; domains EWFVL | medium |
| ORCID | ORCID public data file and OpenAlex (https://info.orcid.org/documentation/integration-guide/working-with-bulk-data/) | OpenAlex CC0 (LI.17). ORCID page shows a CC0 badge; the Public Data File Use Policy was not read. Individuals, aggregate transitions only. | USABLE | panel / event sequences | YAO | SSA MENA SA EAP LAC ECA NA | multilingual names; partly | EDU, OCC, SCI, MOB; domains EW | low |
| ESCO | ESCO and ISCO-08 (CC BY 4.0, LI.17) | CC BY 4.0 as confirmed in LI.17. | USABLE | text | YAO | SSA MENA SA EAP LAC ECA NA | ESCO in 28 languages (lead statement), ISCO in UN languages; yes | OCC, WORK, SCI; domains W | high |
| MINION | Multilingual event-detection corpora MINION and MEE (https://arxiv.org/abs/2211.05958, https://arxiv.org/abs/2211.05955) | Research datasets; licences not read. Used only to test event-category extraction across languages, not for life-course content. | USABLE | text | A | ECA EAP SA LAC | 8 languages each (English, Spanish, Portuguese, Polish, Turkish, Hindi, Korean, Japanese among them); yes | SOC; domains K | low |

### 1.6 Generators, engines and models

| ID | Source | Terms (words and evidence) | Class | Granularity | Stages | Regions | Languages; multilingual instruments | Reaches | Conf. |
|---|---|---|---|---|---|---|---|---|---|
| SYNTHEA | Synthea (https://github.com/synthetichealth/synthea) | Apache License 2.0, copyright The MITRE Corporation (fetched). | USABLE | model / tool | BCYAO | NA | English; no | HEALTH, FAM; domains H | high |
| SOCSIM | Demographic microsimulators: SOCSIM, SimPaths, openM++ | Open-source; licences not read. | USABLE | model / tool | BCYAO | NA ECA | English; no | FAM; domains F | low |
| XLMT | XLM-T / TweetNLP multilingual Twitter models and corpora (https://github.com/cardiffnlp/xlm-t) | Repository defers to each dataset licence and Twitter regulations (via search); model licences not read. Candidate verifier encoder. | USABLE | model / tool | YAO | NA ECA EAP LAC MENA | 30+ languages (198M tweets, 2018 to 2020); yes | SOC; domains V | low |

### 1.7 Social media and web text (section 5 has the detail)

| ID | Source | Terms (words and evidence) | Class | Granularity | Stages | Regions | Languages; multilingual instruments | Reaches | Conf. |
|---|---|---|---|---|---|---|---|---|---|
| BSKY | Bluesky firehose / Jetstream (https://docs.bsky.app/blog/jetstream; ToS https://www.bsky.social/about/support/tos) | Open public stream; ToS reportedly restricts automated access to provided interfaces, the stream is one; Jetstream announcement lists research as a poor fit; datasets on Hugging Face state "subject to Bluesky's Terms of Service"; an Indiana University catalogue entry notes the data holds personal identifiers (via search, not read at source). | USABLE | text | YAO | NA ECA EAP LAC | English, Japanese, Portuguese, German, Spanish, others (recollection); no | FAM, EDU, WORK, SOC, LEIS, MEAN, HEALTH; domains VLFWE | low |
| MASTO | Mastodon / fediverse public timelines (per-instance terms) | No universal terms; each instance sets its own, some forbid scraping or research; mastodon.social terms "prohibit the scraping of user data for ... archival or large language model training" (via search). Use only instances whose terms allow it. | USABLE | text | YAO | NA ECA EAP LAC | English, Japanese, German, French, others; no | FAM, EDU, WORK, SOC, LEIS, MEAN; domains VLF | medium |
| REDDITR | Reddit for Researchers programme (https://www.reddit.com/r/reddit4researchers) | Approval programme; non-commercial; paraphrased: no redistribution of data or derivatives "such as models trained on it", credit Reddit (via search, wording to be read at source). Pushshift successor Arctic Shift is secondhand and outside the programme. | COSTLY | text | YAO | NA ECA EAP LAC | mostly English; Spanish, Portuguese, German, others in national subreddits; no | FAM, EDU, WORK, SOC, LEIS, MEAN, HEALTH, CRIME; domains VLFWEK | low |
| XTW | X (Twitter) API | Official page still advertises free non-commercial academic access; third parties report paid usage-based tiers only; status unclear (https://developer.x.com/en/developer-terms/commercial-terms, via search). Treat as costly. | COSTLY | text | YAO | NA ECA EAP LAC MENA | many (Japanese, Spanish, Arabic, Portuguese, Turkish heavy); no | FAM, EDU, WORK, SOC, LEIS, MEAN; domains VLFWE | low |
| YT | YouTube Researcher Program (https://research.youtube.com/policies/terms) | Accredited non-profit degree-granting institution only; available in Taiwan, Thailand, Tunisia, UAE, UK, US, Vietnam; Program ToS plus API ToS (via search). | COSTLY | text | YAO | MENA EAP ECA NA | many; yes | FAM, EDU, WORK, SOC, LEIS, MEAN; domains VL | medium |
| TIKTOK | TikTok Research API | Eligibility restricted to approved researchers in some regions; terms not found in search. | COSTLY | text | YAO | NA ECA | many; yes | FAM, EDU, WORK, SOC, LEIS, MEAN; domains VL | low |
| SE | Stack Exchange data dump (https://archive.org/details/stackexchange) | Contributions CC BY-SA (2.5/3.0/4.0 by date); since 2024 the dump licence reportedly excludes commercial use, distribution and LLM training (Archive Team wiki and DevClass, via search). Internal statistics only; no model training on the text. | USABLE | text | YAO | NA ECA LAC EAP | English plus Russian, Portuguese, Spanish and Japanese sites; no | FAM, WORK, EDU, HOME, MONEY, MOB, HEALTH, CRIME, SOC; domains WFEV | medium |
| CONVO | ConvoKit corpora incl. WikiConv, Wikipedia Talk Pages (https://convokit.cornell.edu/datasets.html) | Wikipedia Talk Pages corpus "governed by the CC BY license v4.0"; Reddit corpus licence not found (via search). | USABLE | text | YAO | NA ECA EAP LAC | WikiConv in several languages; others English; partly | SOC, CRIME, CIVIC; domains VK | medium |
| LIFEEV | Life-event detection datasets: PsyEvent (Reddit, ACL 2025), crowdsourced tweets (2,241), SIGIR 2019 lifelog tweets, LED dialogs (https://aclanthology.org/2025.acl-long.345/) | PsyEvent: 7,965 labelled sentences, 12 categories, 127 events, built on SMHD Reddit data (which carries its own DUA); tweets released as ids. Licences not verified. | USABLE | text | YAO | NA | English; no | FAM, EDU, WORK, HEALTH, SOC, MEAN, MOB, CRIME; domains EWFHKV | low |
| CC | Common Crawl (https://commoncrawl.org/terms-of-use) | Terms of Use (updated 2024-03-07): no illegal use, respect crawled sites' terms, no republishing or resale (via search); underlying pages copyrighted. Blogs, forums and personal pages carry first-person events; raw text discarded after feature extraction. | USABLE | text | CYAO | SSA MENA SA EAP LAC ECA NA | 100+ languages; yes | FAM, EDU, WORK, SOC, LEIS, MEAN, HEALTH, MONEY, MOB, CRIME, CIVIC; domains EWFVLHK | medium |
| YELP | Yelp Open Dataset (https://www.yelp.com/dataset) | Dataset User Agreement; described as for personal, educational and academic use (via search, agreement not opened). | USABLE | text | AO | NA | English mostly; no | MONEY, LEIS, MOB; domains L | low |
| WEIBO | Weibo, VK, LINE, Telegram research corpora (non-English platforms) | No research terms found for any; platform APIs restricted. Listed as an open gap, not a plan. | COSTLY | text | YAO | EAP ECA | Chinese, Russian, Japanese; yes | FAM, EDU, WORK, SOC, LEIS, MEAN; domains VL | low |

### 1.8 Excluded

| ID | Source | Terms (words and evidence) | Class | Granularity | Stages | Regions | Languages; multilingual instruments | Reaches | Conf. |
|---|---|---|---|---|---|---|---|---|---|
| XINSTR | Proprietary developmental instruments: Bayley-III, Denver II, Ages and Stages, AAP Bright Futures text | Copyrighted instruments; use CDC and WHO published ages instead. | EXCLUDED | aggregate rates | B | NA | English; no | none; domains H | medium |
| XGEO | Services that forbid redistribution of derived rows by contract: IMDb datasets, social-media APIs (Strava, X, Reddit) and commercial panels | Terms bar research reuse or require paid licences; not read individually. Listed so nobody builds on them. | EXCLUDED | individual records or diaries | AO | NA | many; no | none; domains L | low |

Reading the "Reaches" column: field groups are `FAM` family and care, `HEALTH`, `EDU`, `WORK`, `OCC` occupations, `CRIME` harms, `WAR` conflict and justice, `CIVIC`, `SOC` social, `LEIS` leisure and media, `MEAN` belief and rites, `HOME`, `MOB` mobility and migration, `MONEY`, `DIS` disasters, `SCI` science and technology fields, `NAT` nature. How a source drives the generator follows its granularity: panels give transition hazards and age-of-onset curves and real event sequences; individual records and diaries give prevalence by age and activity transition matrices; aggregates give rate curves by age, sex and region; text gives verifier training and categorisation tests; models give the state machine.

Access types, in brief. Open download: World Bank, Eurostat, UCDP, OWID, UNODC portal, IEA public use, BLS and Census tables, ONS. Registration with agreement: DHS, MICS, ESS, WVS, ISSP, GGP, SHARE, CHARLS, CFPS, IFLS, UKDS panels, Young Lives, Add Health public-use, MTUS, IPUMS. Institutional agreement: SOEP, HILDA, HETUS microdata, CNEF per country, Add Health restricted, Reddit for Researchers, YouTube Researcher Program. Paid or opaque: Gallup World Poll, X API, TikTok.

## 2. Coverage by life stage (usable and costly sources)

Individual-level (panel, record, diary) usable sources are listed first, aggregate-only after; costly sources last. Life stage columns use the stage codes of each source.

| Life stage | Usable, individual or sequences | Usable, aggregates | Usable, text or models | Costly |
|---|---|---|---|---|
| Birth and early health (0-5) | 10: DHS MICS YL IPUMSI CFPS UKHLS PSID CENSUS NCHS WIKIDATA | 7: NCES ONS EUROSTAT WB UNDESA OWID GBDWHO | 3: WIKIBIO SYNTHEA SOCSIM | 2: SOEP HILDA |
| Childhood and school (6-14) | 21: DHS MICS YL IPUMSI LSMS GAGE CFPS IFLS NIDS BRPNAD UKHLS ADDH PSID GSHS GKO MTUS ATUS CENSUS NCHS IEA WIKIDATA | 10: CRIMEUS NCES ONS EUROSTAT WB UIS UNDESA OECD OWID GBDWHO | 4: WIKIBIO SYNTHEA SOCSIM CC | 3: SOEP HILDA HETUS |
| Youth: training, first jobs (15-24) | 38: DHS MICS YL GGP ESS WVS ISSP AFRO ARAB LATINO ABAR IPUMSI LSMS SWTS ERF GAGE CFPS IFLS IHDS MEX NIDS KLIPS JHPS BRPNAD UKHLS ADDH PSID GSHS GKO VACS MTUS ATUS CENSUS NCHS WIKIDATA ORCID TRAM RLMS | 14: BLS CRIMEUS NCES ONS EUROSTAT WB ILOSTAT UIS UNDESA OECD UNODC UCDP OWID GBDWHO | 11: WIKIBIO ESCO SYNTHEA SOCSIM BSKY MASTO SE CONVO LIFEEV XLMT CC | 9: GALLUP SOEP HILDA HETUS REDDITR XTW WEIBO YT TIKTOK |
| Adult work and family (25-64) | 36: DHS MICS YL GGP SHARE ESS WVS ISSP AFRO ARAB LATINO ABAR IPUMSI LSMS ERF CHARLS CFPS IFLS IHDS MEX NIDS KLIPS JHPS BRPNAD UKHLS ADDH PSID VACS MTUS ATUS CENSUS NCHS WIKIDATA ORCID TRAM RLMS | 13: BLS CRIMEUS ONS EUROSTAT WB ILOSTAT UIS UNDESA OECD UNODC UCDP OWID GBDWHO | 13: WIKIBIO ESCO MINION SYNTHEA SOCSIM BSKY MASTO SE CONVO LIFEEV XLMT CC YELP | 10: GALLUP SOEP HILDA CNEF HETUS REDDITR XTW WEIBO YT TIKTOK |
| Later life, retirement, death (65+) | 33: DHS MICS GGP SHARE ESS WVS ISSP AFRO ARAB LATINO ABAR IPUMSI LSMS ERF CHARLS CFPS IFLS IHDS MEX NIDS KLIPS JHPS BRPNAD UKHLS PSID MTUS ATUS CENSUS NCHS WIKIDATA ORCID TRAM RLMS | 12: BLS CRIMEUS ONS EUROSTAT WB ILOSTAT UNDESA OECD UNODC UCDP OWID GBDWHO | 12: WIKIBIO ESCO SYNTHEA SOCSIM BSKY MASTO SE CONVO LIFEEV XLMT CC YELP | 10: GALLUP SOEP HILDA CNEF HETUS REDDITR XTW WEIBO YT TIKTOK |

Reading: every stage has at least ten usable individual-level sources. The thin spots are inside the stages. Birth and early health (0-5) leans on DHS, MICS, Young Lives, CFPS, CDC milestones and Synthea; there are no usable event-level sequences for hobbies, play or social life before age 6 except MICS early-childhood items and ATUS diaries from age 15. Schooling and academic assessment in the global south is aggregate (PISA, TIMSS, UIS) plus Young Lives, MICS, LSMS and DHS. Youth transitions rest on ILO school-to-work surveys, CFPS, Young Lives, Add Health, Understanding Society and the cohorts. Later life is well served (SHARE, CHARLS, HRS, ELSA, LASI, IFLS) but SHARE and Add Health clauses bar agent reading. Death and bereavement are rates (WPP, NCHS, HMD) plus widowhood fields in panels and a demographic microsimulator.

## 3. Coverage by world region (usable sources; individual-level + aggregate)

Cells are `n individual + m aggregate` usable sources in the register carrying that domain for the region. The count is of sources, not of countries inside them, and it counts any source that lists the region, so it flatters regions served by one country of a multi-country source.

| Region | Education | Work | Family | Health | Harm | Social, civic | Leisure, culture | Region-specific individual-level sources |
|---|---|---|---|---|---|---|---|---|
| Sub-Saharan Africa | 12+7 | 10+8 | 10+6 | 7+5 | 9+4 | 7+2 | 3+3 | AFRO NIDS |
| Middle East and North Africa | 10+7 | 7+8 | 7+6 | 4+5 | 6+4 | 5+2 | 1+3 | ARAB ERF |
| South Asia | 12+7 | 10+8 | 10+6 | 7+5 | 9+5 | 7+2 | 2+3 | IHDS |
| East Asia and Pacific | 14+9 | 15+10 | 14+9 | 8+5 | 9+6 | 7+6 | 3+5 | CHARLS CFPS IFLS KLIPS JHPS |
| Latin America and Caribbean | 12+9 | 12+10 | 11+9 | 6+5 | 8+6 | 7+6 | 3+5 | LATINO MEX BRPNAD |
| Europe and Central Asia | 12+11 | 13+12 | 13+11 | 7+7 | 8+8 | 7+7 | 4+7 | SHARE ESS UKHLS TRAM RLMS |
| North America | 8+12 | 6+12 | 8+10 | 4+6 | 3+6 | 6+7 | 5+6 | ADDH PSID ATUS CENSUS NCHS |

Reading. Every region has usable individual-level sources for education, work and family (the prediction's regional clause holds on the register's face), but the depth differs sharply, and the region-specific column shows who is carried by single-country panels. Weakest coverage:
1. **MENA**: no usable multi-wave panel beyond the ERF labour-market panels (Egypt, Jordan, Tunisia), GAGE adolescent panels (partly MENA) and Arab Barometer attitudes; DHS and MICS cover only some countries; Gallup is costly. Leisure, social life and harms are rates only.
2. **Sub-Saharan Africa**: strong on family, health and child outcomes (DHS, MICS, LSMS, Young Lives, NIDS) but weak on adult leisure, social and civic sequences (Afrobarometer is attitudes) and on vocational careers beyond household surveys.
3. **Central Asia and Eastern Europe within ECA**: ECA depth is Western Europe (SHARE, GGP, ESS, SOEP, HETUS); the east rests on RLMS, GGP partly, DHS Central Asia and MICS.
4. **Oceania and Pacific Islands within EAP**: HILDA and LSAC are costly and Australian; Pacific Islands appear only through DHS and MICS rounds.
5. **South Asia**: IHDS and LASI terms were not read; the rest is DHS, MICS, Young Lives (India) and aggregates.
North America is the best covered and also the one the older scout over-relied on; the plan below caps its weight in priors.

## 4. Coarse-field coverage

Mapping upper bounds (sector-level mapping, 247 fields):

| Reach | Fields | Share |
|---|---|---|
| From usable sources | 235 | 95% |
| From usable plus costly | 235 | 95% |
| From usable individual-level sources (panels, records, diaries) | 235 | 95% |
| From usable non-text sources (adds aggregates) | 235 | 95% |

Costly sources add depth, not breadth: no field is reached only by a costly source on this mapping. Fields the mapping does not reach at all (12): academic_dishonesty, alternative_medicine, counselling_therapy, eating_drinking, family_rituals, hygiene_grooming, mediation_dispute_resolution, mentoring_peer_support, misinformation_defamation, public_administration, self_reflection, urban_planning.

**Sample audit (the honest number).** The mapping gives a whole sector to any source that touches it, so 30 fields were drawn at random (seed 61) and judged by hand for what a usable source really supplies: D direct (age or region rates or events for that very field), P partial (a proxy, a related field, or text only), N none. Result: 21 D, 8 P, 1 N, so direct reach is about 70% (Wilson 95% interval about 52% to 83%, roughly 130 to 205 fields of 247), direct plus partial about 97%, none about 3% (self_reflection in the sample; this agrees with the roughly 12 unmapped fields above). Partial fields in the sample: mutual_aid, celebrations, coming_of_age, manufacturing, funeral_mourning, history_science, biotechnology, linguistics_literature. Direct fields in the sample: border_migration_admin, research_training, theft_property_crime, bereavement, children_play, spirituality, occupational_safety, preventive_health, road_safety, performing_arts, clothing_footwear, commuting, sport_spectating, neighbours_community, outdoor_recreation, hygiene_grooming, horticulture_farming, partnership_romance, volunteering, music_making, medical_care.

Pattern: the family, health, work, schooling, mobility, consumption and harm sectors are direct; science and engineering knowledge fields, rites, mourning, self-reflection, mentoring, mediation and etiquette are partial or none and need the text sources and the agent-authored fine domains.

## 5. Social media and web text for research (direction 3)

Use in the pipeline: calibrate the verifier on real first-person event mentions and on real posting patterns, and recover event rates by age cohort where the platform gives age signals. Nothing is stored as posts: a de-identified feature record per post (event category, domain tags, life-stage cue, tense, language, month, no text, no handle, no URL, no names, no usernames, no media) is the only thing kept, extracted in a local run, with minors detected by cue and dropped before feature extraction. Public figures are the only identifiable exception (LI.15), and only from their public biography, never their social accounts.

| ID | Terms for research use | Class | Languages and regions | First-person events recoverable | Privacy handling required |
|---|---|---|---|---|---|
| BSKY | Open firehose and Jetstream; ToS reportedly limits automated access to provided interfaces; community datasets say they are subject to the ToS; research flagged as a poor fit by Bluesky; terms to be read at source | USABLE | English, Japanese, Portuguese, German, Spanish; NA, ECA, EAP, LAC | job and study announcements, moves, partnerships, bereavement, illness mentions, hobbies and sport, public-figure career news | Posts carry personal identifiers; features only, redact handles, drop minors, keep no text |
| MASTO | Per-instance terms; some forbid scraping or research; mastodon.social bars archival and LLM training | USABLE | English, Japanese, German, French; NA, ECA, EAP | same as Bluesky, skewed to technical and activist communities | Pick instances whose terms allow research; features only; honour deletions |
| REDDITR | Approval programme, non-commercial, no redistribution of data or derivatives such as trained models (paraphrase, read at source) | COSTLY | English plus national subreddits in Spanish, Portuguese, German; NA, ECA, LAC | long first-person narratives: relationships, divorce, job loss, illness, bereavement, harassment, mental health; the richest first-person source | Pseudonymous but re-identifiable; programme rules; features only; no model training on posts |
| XTW | Official page advertises free non-commercial academic access, third parties report paid tiers only | COSTLY | very many languages; global | short life-event announcements (the 2,241-tweet life-event set came from here) | Same; costly in practice |
| YT | Researcher Program for accredited non-profit institutions in seven listed countries | COSTLY | many languages | video metadata and comments: hobbies, sport, family vlogs (minors common: exclude) | High risk of minors; exclude family content; metadata features only |
| TIKTOK | Research API for approved researchers in some regions; terms not found | COSTLY | many languages | short hobby and trend content; weak first-person events | Minors common; likely unusable under LI.15 |
| SE | Content CC BY-SA; dump licence reportedly restricted since 2024 against commercial use, distribution and LLM training | USABLE | English, Russian, Portuguese, Spanish, Japanese sites | situations in questions: parenting, workplace, personal finance, law, travel, moving, relationships; usernames are public | Features only; internal statistics; no training on text |
| CONVO | Wikipedia Talk Pages corpus CC BY 4.0; Reddit corpus licence not found | USABLE | WikiConv several languages; English | conflict and harassment exchanges (conflict_interpersonal, online_harassment) | Public edit names; strip names; features only |
| LIFEEV | Papers and tweet-id lists; PsyEvent built on SMHD Reddit data with its own DUA; licences not verified | USABLE | English | labelled personal life events: 12 categories, 127 events (PsyEvent); marriage, graduation, job, bereavement (tweets) | Fetching tweets by id recreates real posts: keep labels and taxonomies, not text |
| XLMT | Defers to dataset licences and Twitter rules | USABLE | 30+ languages | none directly; encoder and benchmark for multilingual social text | Model only; no posts kept |
| CC | Terms of Use: no illegal use, respect crawled sites' terms, no republishing or resale | USABLE | 100+ languages; global | first-person events in blogs, forums, personal pages, local news; broadest language and region coverage | Run extraction at source, discard text; filter minors and non-public figures; features only |
| YELP | Dataset User Agreement for personal, educational and academic use (not opened) | USABLE | English; NA | weak: dining, travel, shopping visits | Business reviews; features only |
| WEIBO | No research terms found for Weibo, VK, LINE or Telegram | COSTLY | Chinese, Russian, Japanese | would add East Asian and Russian first-person events | Open gap; no plan |

Count: 8 usable social or web-text sources (BSKY, MASTO, SE, CONVO, LIFEEV, XLMT, CC, YELP); of these, BSKY, MASTO, SE, CONVO, XLMT and CC reach non-English languages (Japanese, Portuguese, German, Spanish, French, Russian, Chinese and Arabic via CC and XLM-T). Reliability is low for most because terms were read through search summaries and several platforms moved terms in 2024 and 2025; Reddit, X, YouTube and TikTok are costly. No usable source gives age directly: age cues come from text ("my 40th") and are noisy, so social data calibrates event type, wording and language, not age-specific rates. Event coverage is biased to the young, online, urban and English, Japanese and Portuguese speakers, and to dramatic events; it never replaces panel rates.

## 6. Recommended architecture: adversarial generator and verifier

### 6.1 Shape

```
        priors (rates, sequences)                real-world references
 DHS MICS LSMS panels CHARLS SOEP-class   panels + diaries     real text features
 WPP HMD ILOSTAT UIS Eurostat ...        (held-out folds)     (Reddit, CC, SE, Wikidata bios)
            |                                   |                      |
            v                                   v                      v
   +------------------+   events (fields or text)   +-----------------------------+
   | Generator G      | --------------------------> | Verifier V (several heads)  |
   | state machines   |                             |  rate head, sequence head,  |
   | per domain +     | <-------------------------- |  demographic head, text head|
   | text renderer    |   judgement + reasons       +-----------------------------+
   +------------------+                                       ^
            ^                                                 |
            +---- Life Image classifier tags each event ------+
                  with fine domains (new fines inherit)
```

### 6.2 Generator

- Core: a Synthea-style state machine per domain family (health, schooling, work, family, civic, leisure, harm), with age-conditioned hazard rates and transition tables, drawing on independent random streams per (seed, mechanism) as `lifeimage/generators/life.py` already does. Synthea (Apache-2.0) supplies the health modules and the module format; a demographic microsimulation in the SOCSIM style (age-specific fertility, marriage, divorce, mortality rates from UN World Population Prospects) supplies kinship, partnership, parenthood and bereavement so family events are consistent across a household; ATUS, MTUS and HETUS diaries supply daily-activity transition matrices for leisure, home and social events.
- Priors come from rates, not from rows. Each rate is a `Param` in `lifeimage/generators/params.py` form (default, low, high, unit, source, confidence), now with region and sex strata and a calibration source ID from section 1.
- Rendering: events leave as preformatted records (fields and memberships; the existing contract rows) or as text (first-person post, diary line, record) written by an agent from the structured event and a style card per language and platform. The text renderer never sees real posts; it sees the structured event, a register, a language and a length.
- Retargeting: a target is a domain mix and life stage, expressed over fine-domain ids. Events carry no hard-coded domain: each is tagged by the Life Image classifier (the same one used on real text), so adding or splitting a fine domain changes tags, not generators. A new fine inherits its parent coarse field's rate until probes supply its own (rate shrinkage to the parent, as `fine_pick` does for membership).

### 6.3 Verifier

Four heads, each trained or checked on real data and judged separately:
1. Rate head: compares the generated population's event rates by age band, sex and region with calibration rates (DHS, MICS, ILOSTAT, WPP, Eurostat, ONS and others). Metric: distribution distance (Wasserstein or total variation) per domain and stratum, with the paired-seed significance rule of the project (z = 2 default, 3 for claims entering README).
2. Sequence head: scores event order and timing against real panels and event histories (ages at first event, spells, durations): a transition-likelihood model fitted on held-out folds of CFPS, CHARLS, IFLS, UKHLS, Young Lives, LSMS, DHS birth histories, Wikidata careers and ORCID transitions, plus hard constraints (no schooling after death, no divorce before marriage, no birth before age of menarche).
3. Demographic head: consistency of a persona with its stated country, cohort, sex, education and occupation (ISCO/ESCO), including a probe that tries to read the country from the events and flags contradictions.
4. Text head: a multilingual encoder (XLM-T class) fine-tuned to separate real first-person life-event sentences (PsyEvent, the tweet life-event set, Reddit for Researchers where approved, Common Crawl features, Wikipedia biography sentences) from generated ones, using only derived features or short windows that are not stored.

### 6.4 The adversarial loop

- Generator proposes batches for a target (domain mix, life stage, region, language). The verifier returns per-head scores and the reason codes (which rate or transition was off). The generator's update is parametric, not weight training: rate and transition parameters move within their `Param` ranges toward the verifier (a calibration loop), and the text renderer's style cards and prompts are revised from the text head's reasons. This keeps the generator inspectable and the mechanisms probe-testable.
- The verifier is retrained on fresh generator output against held-out real references each round, so it keeps up with the generator.
- Stopping rule: stop when the held-out discriminator accuracy is within a stated margin of chance (equivalence test, never mere non-significance: for example 0.50 plus or minus 0.05 with the margin shown detectable), the rate head is within the margin on every stratum with enough real data, and the sequence head's mean log-likelihood gap to real is within its margin.

### 6.5 Mode collapse and leakage

- Mode collapse: track coverage of the domain-by-age-by-region grid and entropy of event types per persona; require every cell above a floor to appear in proportion to its calibration rate; add a diversity term (pairwise distance between personas of the same target) to the verifier's judgement; resample from the priors, not from earlier generator output, each round, so there is no self-feeding loop.
- Memorised real posts: real text is never inputs to the generator or its renderer. The text head is trained inside a local run on features and short windows; after training, near-duplicate checks (n-gram overlap and embedding nearest neighbour, threshold governed) between generated text and the real reference are run on a held-out sample and logged; any hit above threshold is deleted and the style card that caused it is revised. Real references live outside the repository; only fitted parameters, thresholds and aggregate scores are committed. Sources whose terms bar model training on the data (Reddit, Stack Exchange, SHARE, SOEP) feed only the rate and sequence statistics computed by code, never a trained text model.
- Identity: generated personas are synthetic by construction; a check searches generated names and events for matches with the public-figure list and with any panel record's rare combinations (k-anonymity style on the derived features) before use.

### 6.6 Verification metrics (what the tests assert)

| Metric | Target | Source of the reference |
|---|---|---|
| Rate match by age band, sex and region for each fine-domain family | within margin; paired seeds; z = 2 (3 for README claims) | DHS, MICS, WPP, ILOSTAT, Eurostat, ONS, BLS, UIS, UNODC |
| Sequence plausibility (ages at first events, spells, order) | mean log-likelihood gap to real within margin; zero hard-constraint violations | CFPS, CHARLS, IFLS, UKHLS, LSMS, Young Lives, DHS histories, Wikidata, ORCID |
| Held-out discriminator accuracy (text and record) | equivalent to 0.5 within a stated margin, margin shown detectable | real-feature sets, held-out folds |
| Coverage and diversity | every grid cell above floor present in calibrated proportion; no collapse | the target mix itself |
| Leakage | zero near-duplicates above threshold with any real reference | logged check |
| Cross-language parity | verifier accuracy and rate fit per language within margin of English | multilingual references (section 7) |
| Agent and human spot checks | sampled and scored on realism and category fit; disagreements logged | blind mix of synthetic and de-identified real features |

### 6.7 Retargeting under refinement

New or split fine domains: (1) the classifier tags existing generated events and calibration features with the new fine ids; (2) rates for the new fine are inherited from the parent and then re-estimated from tagged calibration features where counts allow; (3) probes (mechanism probe first, per the project rule) show the new fine's events appear at the target rate; (4) no regeneration of untouched domains. The calibration store is therefore a table of (fine id, stratum, rate, source, confidence) plus tagged feature counts, not a baked dataset.

## 7. Languages

| Language group | Sources with instruments, text or labels in it | Note |
|---|---|---|
| English | nearly all | the default master language of most instruments; over-weighted |
| Spanish | DHS, MICS, IPUMS, Latinobarometro, MxFLS and MHAS, ISSP, Eurostat (partly), Census, Stack Exchange (es), WVS, Wikipedia, Bluesky | strong across LAC and the US |
| French | DHS, MICS, ILOSTAT, WB, Eurostat, UIS, Afrobarometer, Arab Barometer, GGP, Stack Exchange (via English site only), Wikipedia, Mastodon | covers francophone SSA, Maghreb and Europe |
| Portuguese | Latinobarometro, PNAD, Stack Exchange (pt), Bluesky, WVS, Wikipedia | Brazil is the only large Lusophone panel-like source |
| Arabic | Arab Barometer, ERF panels, WB, GAGE, WVS, Wikidata | MENA text events are thin |
| Chinese | CHARLS, CFPS (questionnaires), WVS, ISSP (Taiwan, China), Wikipedia | social text unavailable on usable terms (Weibo open gap) |
| Japanese | JHPS/KHPS, JGSS, Bluesky, Mastodon, Stack Exchange (ja), X (costly), Wikipedia | the best non-English social text |
| Korean | KLIPS, KLoSA, WVS, MEE | questionnaire access to be confirmed |
| Hindi and South Asian languages | IHDS and LASI (not verified), MICS India, Young Lives (Telugu), MEE (Hindi), WVS | thinnest event-text coverage relative to population |
| Russian | RLMS, LiTS, Stack Exchange (ru), WVS, Wikipedia | VK corpus not found |
| German | SOEP (costly), ESS, SHARE, Mastodon, Bluesky | strong |
| Indonesian, Vietnamese, Amharic, Swahili and other national languages | IFLS, Young Lives, LSMS and DHS questionnaires, Afrobarometer, MICS | questionnaires exist; no usable social text |
| Occupation and skill names | ESCO (28 languages, lead statement), ISCO (UN languages), Wikidata labels in many languages | a ready multilingual vocabulary for categorisation tests |
| Event descriptions for agent categorisation tests | MINION and MEE (8 languages each), Wikipedia biographies, PsyEvent (English) | no corpus of everyday life-event text exists in many languages; the test set will be agent-authored and flagged AI-written |

## 8. Gaps, ordering, first steps and the prediction

### 8.1 Gaps

1. **Hobbies, culture, sport and play as sequences.** Only diaries (ATUS, MTUS, HETUS) and participation rates exist; no usable panel records when people take up and drop hobbies. Wikidata careers (sport, music, arts) cover only notable people.
2. **Social engagement and online life.** Rates from ESS, ISSP, WVS, barometers and Global Kids Online; text from social platforms; no individual sequences, and age is not observable in posts.
3. **Harm in the global south.** Victimisation by age is strong in the US, UK and Europe; elsewhere it is DHS domestic-violence modules, VACS, UNODC aggregates and Afrobarometer victimisation items; offending rates by age are missing outside police statistics.
4. **Non-English social text and event corpora** (Chinese, Hindi, Arabic, Russian, Indonesian, Swahili).
5. **Regions in section 3** (MENA, Central Asia and Eastern Europe, Pacific, panels in Sub-Saharan Africa beyond household surveys).
6. **Terms I could not read** (OECD, ILOSTAT, BJS, NLSY, PSID, KLIPS, IHDS, MxFLS, Asian Barometer, Latinobarometro public terms, ORCID use policy, Yelp agreement, Active Lives licence).
7. **Real age signals in social data**; use only to calibrate type and wording.

### 8.2 Ingestion order

1. Demographic and rate backbone: UN WPP, ILOSTAT, UIS, World Bank, Eurostat, ONS, Census and BLS tables, UNODC, UCDP (open, no registration; all regions).
2. Event-sequence backbone from panels with the simplest terms: DHS birth histories and MICS (registration), Young Lives, LSMS, CHARLS, CFPS, IFLS, UKDS cohorts, Wikidata careers and ORCID transitions.
3. Diaries and daily life: ATUS, MTUS, HETUS tables, national time-use surveys.
4. Beliefs, civic and social rates: WVS, ESS, ISSP, barometers.
5. Text references: Wikipedia and Wikidata biographies, PsyEvent, Common Crawl features, Stack Exchange and Bluesky features (after terms are read at source).
6. Costly sources only where a gap needs them: SOEP, HILDA, HETUS microdata, Reddit for Researchers.

### 8.3 First three concrete steps

1. **Calibration table schema and rate backbone.** Define the calibration store (fine id, stratum by age band, sex and region, rate, unit, source id, confidence, licence class and evidence URL) in `lifeImage/data/events/`, and fill the first 30 coarse-field families from the open aggregate sources (WPP, ILOSTAT, UIS, Eurostat, ONS, WHO/UNODC) with a red test that fails when a rate is missing a source or a region stratum.
2. **State-machine probe for family and schooling events.** Build one probe world (a few hundred synthetic persons, a few decades) with a SOCSIM-style family machine and a schooling machine driven by WPP and UIS rates, with acceptance and counterexample cases, and the rate head of the verifier as its first check. This is the smallest mechanism that exercises generator, verifier and retargeting together.
3. **Terms-reading and registration pass.** Read at source the terms of the twelve unread sources in gap 6, register for DHS, MICS, ESS, WVS, ISSP and Young Lives (all registration-only), and have the author confirm the non-commercial reading and the AI-use clauses (SHARE, SOEP, Add Health, Reddit, Stack Exchange), since those decide which sources feed code-only statistics and which can feed a text verifier.

### 8.4 Prediction judged

Prediction (confidence 0.5): at least 15 usable sources across every life stage; one usable source per region for education, work and family; at least 80% of 247 fields reachable from usable sources; panels give sequences for education, work and family while hobbies, social and harm come as rates; at least 5 usable social sources covering at least 3 non-English languages.


- At least 15 usable sources across every life stage: **held on the register, short on the strict reading** (68 usable in the register; at least ten individual-level per stage). Only ten had their terms fetched at the source (BLS, O*NET, ONS, Eurostat, World Bank, UCDP, OWID, IPUMS, Synthea, NCHS/CDC); counting only those the claim fails at 10, so it rests on terms read through search summaries for the rest, to be confirmed in the terms pass (step 3).
- One usable source per region for education, work and family: **held on the register**, **weakly for MENA, Central Asia, the Pacific and Sub-Saharan Africa**, where one or two single-country or attitudinal sources carry the claim.
- At least 80% of fields reachable from usable sources: **held for reach** (mapping 95%, sample audit direct plus partial about 97%) but **not for direct reach** (about 70%, interval 52% to 83%); most of the shortfall is science and engineering knowledge fields, rites and mourning, and self-reflection, which need the fine domains and text rather than rates.
- Panels give sequences for education, work, family; hobbies, social, harm come as rates: **held**. Diaries give a partial sequence for leisure; no panel gives hobby take-up and drop; harms outside the US, UK and Europe come from survey modules and aggregates.
- At least 5 usable social sources covering at least 3 non-English languages: **held nominally** (eight usable; non-English: Japanese, Portuguese, German, Spanish, Russian, French through Bluesky, Mastodon, Stack Exchange, ConvoKit, XLM-T, Common Crawl), with low confidence: terms were read through search summaries, several platforms changed terms in 2024 and 2025, and no usable source gives age or Chinese, Hindi or Arabic text.
- Net: the prediction held on its counts and failed on depth in the places named. The earlier prediction (60% from SHIP, aggregates dominate vocation and social) is superseded by LI.61; the finding that aggregates dominate non-US coverage and a generator must chain them stands.
