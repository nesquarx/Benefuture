# Source scout for the 95 coarse fields with no fine child

Scouted 2026-11-25. Scope: which coarse fields (ids `c.*` in `data/coarse/seed_v3.jsonl`) have no fine card linking to them in `data/fine/fine_v1.jsonl`, and which open sources could supply fine domains. Licence words below were read from the primary page on the date above unless marked "not re-verified"; licences move, so the author confirms before ingestion. Rule applied: shipped sources must allow commercial use, modification and redistribution (CC0, CC BY, public domain, ODC-By or similar); ND and NC are excluded. ICATUS is calibration only.

Result: 152 of 247 coarse fields have a fine child; 95 do not.

## 1. Empty fields by sector (upstream `s.*` link)

| Sector | Empty | Fields |
|---|---|---|
| s.harm Harm, crime and misconduct | 19 | theft_property_crime, violence_assault, sexual_violence, fraud_deception, corruption, cybercrime, online_harassment, bullying_harassment, harassment_discrimination, drug_crime, negligence_recklessness, misinformation_defamation, extremism_terrorism, exploitation_trafficking, academic_dishonesty, stalking_privacy, traffic_offences, self_harm_suicide, war_experience |
| s.consumption Consumption, money and property | 12 | personal_appearance, restaurants_dining, clothing_footwear, saving_investing, borrowing_debt, insurance_risk, income_earning, gifts_exchange, online_commerce, reuse_repair, subscriptions_telecom, poverty_scarcity |
| s.family Family, intimacy and care | 11 | parenting_adolescents, eldercare, partnership_romance, marriage_cohabitation, family_ties, family_rituals, domestic_abuse, child_abuse_neglect, birth_of_child, marriage_wedding, divorce |
| s.social Relationships and community | 9 | friendship, neighbours_community, conflict_interpersonal, reconciliation, loneliness_isolation, reputation_gossip, etiquette_norms, youth_culture, social_media |
| s.meaning Belief, meaning and ethics | 8 | cultural_identity, spirituality, ethical_choice, life_purpose, rites_of_passage, funeral_mourning, identity_change, folk_belief |
| s.public Governance, law and public life | 7 | inclusion_discrimination, voting_elections, political_participation, political_discourse, civil_society_advocacy, labour_organising, border_migration_admin |
| s.transitions Life events and transitions | 7 | employment_transition, death_dying, bereavement, disaster_experience, coming_of_age, retirement, job_loss |
| s.self_care Body, health and self-care | 6 | medication_adherence, sexuality, disability_adaptation, pregnancy_birth, serious_illness, accident_injury |
| s.mobility Travel, mobility and place | 5 | commuting, public_transport, road_safety, moving_relocation, migration |
| s.leisure Play, arts, sport and media | 3 | video_gaming, festivals_events, nightlife |
| s.nature Nature, animals and environment | 3 | wildlife_conservation, environmental_stewardship, weather_climate_adaptation |
| s.learning Learning and education | 2 | early_childhood_education, exams_assessment |
| s.home Home and household | 1 | housing_search |
| s.technology Technology, engineering and making | 1 | maker_tinkering |
| s.work Work, trades and enterprise | 1 | entrepreneurship |
| **Total** | **95** | |

Note: the author's list in the brief ("the arts") is not an empty sector here; only `s.leisure` has 3 empty fields (gaming, events, nightlife). Several empties are duplicates or near-duplicates of each other (marriage_cohabitation / marriage_wedding, migration / border_migration_admin / moving_relocation, online_harassment / bullying_harassment / harassment_discrimination, birth_of_child / pregnancy_birth, death_dying / bereavement / funeral_mourning, job_loss / employment_transition), so one fine domain can link to several.

## 2. Sources

Shippable: yes = meets the rule on the words read; unclear = needs the author or a closer reading; no = excluded.

| Source | Licence page (URL) | Licence words | Shippable | Fields covered | Approx classes | Access |
|---|---|---|---|---|---|---|
| Wikidata | https://www.wikidata.org/wiki/Wikidata:Licensing (not re-fetched; already in use) | CC0 for structured data | yes | any, via subclass trees from chosen roots (crime, marriage, grief, ritual, hobby, sport, festival, disaster) | thousands per root; needs pruning | SPARQL endpoint, JSON dumps; scripted: yes |
| Getty AAT | https://www.getty.edu/research/tools/vocabularies/obtain/index.html and https://vocab.getty.edu/ | "All Getty Vocabulary data is free to use under the terms of the Open Data Commons Attribution License (ODC-By) 1.0"; credit line "Contains information from the J. Paul Getty Trust, Getty Research Institute, [tool name], which is made available under the ODC Attribution License" | yes | arts and material culture: clothing_footwear (costume facet), personal_appearance, festivals_events, rites_of_passage, family_rituals, maker_tinkering, reuse_repair | ~56,000 concepts; perhaps 300-600 usable for the fields listed | SPARQL at vocab.getty.edu, bulk N-Triples/XML downloads; scripted: yes |
| MeSH (NLM) | https://www.nlm.nih.gov/databases/download/terms_and_conditions.html | "No charges, usage fees or royalties are paid to NLM for this data"; users agree to acknowledge NLM with "Courtesy of the U.S. National Library of Medicine"; redistributors "maintain the most current version of all distributed data, or make known ... that the products ... do not reflect the most current/accurate data". NLM web policy: US-government works "may be freely used or reproduced". No explicit CC grant. | unclear (likely yes; needs author confirmation of commercial and derivative reuse, and of the keep-current clause) | self_care (pregnancy_birth, serious_illness, accident_injury, disability_adaptation, medication_adherence, sexuality), loneliness_isolation, self_harm_suicide, domestic_abuse, child_abuse_neglect, sexual_violence, bereavement, war_experience (Anthropology/Psychiatry/Behavior trees F, Disaster, Wounds and Injuries C26) | ~30,000 descriptors; ~1,500 relevant | XML/RDF annual download, SPARQL and REST API at id.nlm.nih.gov; scripted: yes |
| Disease Ontology (DOID) | https://disease-ontology.org/about/ | "published from the United States under the CC0 1.0 Universal license" | yes | serious_illness, disability_adaptation, pregnancy_birth (complications), accident_injury (limited) | ~12,000 classes; ~600 usable | OBO/OWL download, GitHub, OBO PURL; scripted: yes |
| MONDO | https://github.com/monarch-initiative/mondo (README, License heading) | "CC-BY 4.0" | yes | serious_illness, disability_adaptation (rare diseases heavy; overlap with DOID) | ~25,000 classes | OWL/OBO download, PURL; scripted: yes |
| Human Phenotype Ontology (HPO) | https://hpo.jax.org/app/license (page returned 404 to scripted fetch); hp.owl header: `dcterms:license` points to that URL, "Please see license of HPO" | not read; HPO repo README only points to the licence page | unclear (author to read the page; HPO has had custom attribution terms) | disability_adaptation, serious_illness | ~19,000 phenotype terms; low value for life activity | OWL download via purl.obolibrary.org/obo/hp.owl (76 MB, fetched fine); scripted: yes |
| O*NET database (US DOL) | https://www.onetcenter.org/license_db.html | "licensed under a Creative Commons Attribution 4.0 International License"; credit "O*NET 31.0 Database and the U.S. Department of Labor, Employment and Training Administration", link licence, indicate changes | yes | work-related: entrepreneurship, employment_transition, job_loss, labour_organising (work activities, work context), commuting-adjacent items (GWA/DWA lists) | 41 generalised work activities, ~2,000 detailed work activities, ~330 intermediate | bulk text/Excel downloads at onetcenter.org/database.html; scripted: yes |
| Eurostat HETUS activity list | https://ec.europa.eu/info/legal-notice_en (Commission-wide notice; the Eurostat-specific copyright page URL tried returned 404) | "content owned by the EU on this website is licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0) licence ... unless otherwise indicated" | yes, subject to checking the HETUS guidelines document's own notice | activity-level fields: friendship, parenting, eldercare, commuting, public_transport, video_gaming, nightlife/events (HETUS 2008 codes: 10 main, ~40 two-digit, ~100+ three-digit) | ~190 codes in the three-level list | PDF guidelines at ec.europa.eu/eurostat/web/time-use-surveys; no clean machine file found; manual extraction |
| BLS ATUS lexicon | already ingested (bls.gov; public domain) | US government work | yes | already in fine_v1 | ~430 | already done |
| UNESCO Thesaurus | https://vocabularies.unesco.org/ | "Licence CC BY-SA 3.0 IGO" ("available for download in open data formats under a CC BY-SA 3.0 IGO licence") | unclear: ShareAlike is a copyleft condition and is not in the author's list; it may force the derived fine cards under SA | culture, belief, politics, education: cultural_identity, spirituality, folk_belief, voting_elections, political_participation, civil_society_advocacy, inclusion_discrimination, early_childhood_education, exams_assessment, wildlife_conservation, environmental_stewardship | ~4,400 concepts | SKOS TTL/RDF download, REST and SPARQL; scripted: yes |
| schema.org | https://schema.org/docs/terms.html | "licensed ... under the Creative Commons Attribution-ShareAlike License" (CC BY-SA 3.0) | unclear (SA); low value anyway | online_commerce, subscriptions_telecom, festivals_events (Event types) | ~800 types; ~50 relevant | JSON-LD/RDF download; scripted: yes |
| Library of Congress Subject Headings | https://id.loc.gov/techcenter/ (403 to fetch; not verified) | not read; LC states US-government works are not copyrighted, id.loc.gov historically "available free of restriction" | unclear (likely yes; confirm) | broad: friendship, etiquette, folk_belief, rites_of_passage, family, politics, crime, personal appearance | ~480,000 headings; heavy pruning | bulk download at id.loc.gov/download/, SKOS/N-Triples; scripted: yes (site blocks some agents) |
| UNODC ICCS | https://www.unodc.org/unodc/en/data-and-analysis/statistics/iccs.html ; PDF front matter | "This publication may be reproduced in whole or in part and in any form for educational or non-profit purposes without special permission ... © United Nations, March 2015. All rights reserved" | no (non-profit only); calibration use only | all 19 s.harm fields (11 level-1 sections, ~60 level-2, ~200 level-3 categories) | ~270 categories | PDF; scripted: yes |
| FBI NIBRS offence codes | https://ucr.fbi.gov/ (offence code PDF URL tried returned 404; not verified) | US-government work, public domain in the US (not re-verified on a primary page) | unclear (probably yes; confirm primary page) | theft_property_crime, violence_assault, sexual_violence, fraud_deception, drug_crime, corruption (bribery), stalking_privacy, exploitation_trafficking | ~50-60 Group A offences, ~10 Group B | PDFs / CSV on cde.ct.gov and fbi.gov; scripted: partly |
| COICOP 2018 (UN Statistics) | https://unstats.un.org/unsd/classifications/Econ/COICOP (404 to fetch; not verified) | not read; UN publications are typically "All rights reserved" | unclear | clothing_footwear, restaurants_dining, insurance_risk, subscriptions_telecom, personal_appearance, gifts_exchange, saving_investing (financial services) | 13 divisions, ~43 groups, ~120 classes | CSV/Excel on unstats.un.org; scripted: yes |
| BLS Consumer Expenditure categories | https://www.bls.gov/opub/copyright-information.htm (403 to scripted fetch; not verified) | BLS states its information is public domain unless noted (not re-read) | unclear (likely yes) | consumption fields as above | ~100 UCC categories | CSV on bls.gov/cex/; scripted: bls.gov blocks plain curl, use browser UA |
| US Census NAICS | https://www.census.gov/naics/ (403 to scripted fetch; not verified) | US-government classification, public domain (not re-read) | unclear (likely yes) | entrepreneurship, restaurants_dining, personal_appearance (services), reuse_repair (repair and maintenance sector 811) | 1,000+ 6-digit; ~100 relevant | Excel/CSV downloads; scripted: needs browser UA |
| Princeton WordNet / Open Multilingual WordNet | https://wordnet.princeton.edu/license-and-commercial-use (403) ; https://omwn.org/ lists licences per wordnet | not read (Princeton's licence is permissive, MIT-like, from memory; per-language wordnets vary) | unclear | lexical backfill only (etiquette, gossip, superstition, friendship) | 117,000 synsets; weak as domains | NLTK or GitHub release; scripted: yes |
| DBpedia | https://www.dbpedia.org/resources/ontology/ (not fetched) | not read; ontology is CC BY, extracted instance data CC BY-SA (from memory) | unclear | duplicates Wikidata | ~800 classes | SPARQL, dumps; scripted: yes |
| ICD-11 | https://icd.who.int/en/docs/icd11-license.pdf | "The Classifications are licensed under the Creative Commons Attribution-NoDerivs 3.0 IGO license"; translations need separate WHO agreement | no (ND) | would cover serious_illness, accident_injury, self_harm_suicide, pregnancy_birth | ~17,000 | API, downloads; excluded |
| ICF (WHO) | same WHO classifications licence | same CC BY-ND 3.0 IGO; WHO FAQ page URL tried returned 404 | no (ND) | would cover disability_adaptation | ~1,400 | excluded |
| SNOMED CT | https://www.snomed.org/snomed-ct/get-snomed (not fetched) | affiliate licence, restricted (from memory) | no | n/a | n/a | excluded |

Not scouted in depth: ESCO and OpenAlex (already ingested), OpenStreetMap tag lists (ODbL share-alike on database; skipped), Wikipedia category trees (CC BY-SA, skipped), Schema of LegalDocML-style legal taxonomies (EuroVoc is CC BY 4.0 per EU notice, not read, suggested for s.public; ~7,000 concepts, SPARQL and bulk download at op.europa.eu), CPC/ISIC (UN, same copyright question as COICOP).

## 3. Coverage by field group, and where there is no clean source

| Group | Cleanest source | Gap |
|---|---|---|
| Harm (19) | Wikidata crime subclass trees (CC0). NIBRS (pending confirmation) for property, violence, fraud, drugs, sexual offences | Calibrate against ICCS (not shipped). No clean source for: misinformation_defamation, negligence_recklessness, academic_dishonesty, online_harassment, stalking_privacy, extremism_terrorism, war_experience; use Wikidata classes or model-drafted domains reviewed against ICCS |
| Consumption (12) | COICOP / BLS CE / NAICS (all pending confirmation), Getty AAT for clothing and appearance | poverty_scarcity, gifts_exchange, income_earning, borrowing_debt have no clean classification; Wikidata plus drafted |
| Family (11) | HETUS (care activities), MeSH (abuse, birth), Wikidata (wedding, divorce, rituals) | partnership_romance, parenting_adolescents, family_ties: drafted |
| Social (9) | HETUS (social life), LCSH if confirmed, Wikidata | etiquette_norms, reputation_gossip, youth_culture, social_media, conflict, reconciliation: drafted |
| Meaning (8) | Wikidata (religious practice, ritual, mourning), Getty AAT (ritual objects) | life_purpose, ethical_choice, identity_change, cultural_identity: drafted |
| Public (7) | Wikidata (election, protest, trade union), EuroVoc (CC BY 4.0, unread) | border_migration_admin, political_discourse: partial |
| Transitions (7) | MeSH (death, bereavement), Wikidata (disaster types), O*NET (job loss unrelated; use Wikidata) | coming_of_age, retirement: drafted |
| Self-care (6) | DOID (CC0), MONDO (CC BY), MeSH (pending) | medication_adherence, sexuality: drafted from MeSH if cleared |
| Mobility (5) | HETUS travel codes, Wikidata (transport modes) | road_safety, moving_relocation: partial |
| Leisure (3), nature (3), learning (2), home (1), technology (1), work (1) | Wikidata (game genre, festival, sport; conservation; exam types), Getty (makers), O*NET (entrepreneurship activities) | UNESCO Thesaurus would suit nature, learning if SA is accepted |

## 4. Recommended ingestion order

1. Wikidata subclass trees (CC0, scripted, covers every empty field to some degree). Choose roots per field, cap depth and breadth, record QIDs as anchors.
2. Disease Ontology and MONDO (CC0, CC BY) for the health fields; filter to common conditions by Wikidata sitelinks count to avoid 25,000 rare diseases.
3. Getty AAT (ODC-By) for arts, clothing, ritual, making; credit line on the data card.
4. O*NET database (CC BY 4.0) for work and enterprise activities; ESCO already covers skills.
5. Eurostat HETUS list (CC BY 4.0, manual extraction) for activity-level fields of family, social and mobility.
6. Pending author confirmation: MeSH, NIBRS, NAICS, BLS CE, LCSH, EuroVoc, COICOP (probably usable); UNESCO Thesaurus and schema.org (ShareAlike); HPO (page unread).
7. Remaining gaps: model-drafted domains tagged `drafted:sonnet`, reviewed against ICATUS and ICCS as calibration only (not stored in shipped files).

## 5. Items needing the author

- MeSH: no CC grant; terms require NLM acknowledgement and "keep current or say not current". Confirm that this meets "commercial use, modification, redistribution".
- HPO licence page was not readable by script; confirm its terms.
- ShareAlike sources (UNESCO Thesaurus CC BY-SA 3.0 IGO, schema.org CC BY-SA 3.0): confirm whether SA is acceptable for the shipped basemap.
- Pages that returned 403/404 to scripted fetch (LCSH, NIBRS, NAICS, BLS CE, COICOP, Princeton WordNet, Eurostat-specific copyright page): licences stated from memory; verify in a browser.
- UNODC ICCS is non-profit only, so calibration use is right; also check that ICATUS calibration does not copy its category text into shipped cards.
