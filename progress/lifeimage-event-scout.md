# lifeimage-event-scout (DONE)
Goal: lifeImage/data/events/EVENT_SOURCE_SCOUT.md - scout of datasets/models for large realistic synthetic life-course event sets (SHIP/CALIBRATION/EXCLUDED), synthesis, architecture, first 3 steps. Nothing downloaded.
RULING LI.61 (author, relayed): event-generation datasets are never shipped; all internal calibration. Classes now: USABLE (terms allow internal research use: open/registration/DUA we could sign), COSTLY (institutional agreement/enclave; say what it takes), EXCLUDED (terms forbid). Panels/sequences first-class. Metric: fields reachable from usable, and from usable+costly.
DIRECTION (author, relayed): global + multilingual, not US/UK-centric. Per source: countries/regions, languages, multilingual questionnaires? Synthesis: region x life-stage table, languages table, weakest regions. Regions: SSA, MENA, South Asia, East Asia&Pacific, Latin America, Europe&Central Asia, North America. Multilingual: Wikidata labels, ESCO 28 langs, event-text corpora for categorisation tests.
Prediction (current, conf 0.5): >=15 usable sources across every life stage, >=1 usable source per world region for education, work, family; >=80% of 247 fields reachable from usable sources; panels give sequences for education/work/family, hobbies/social/harm mostly rates.
Earlier prediction (superseded): 15 sources, 60% SHIP, aggregates chain, conf 0.55.
Licence evidence fetched so far (2026-11-25): Synthea Apache-2.0 (github LICENSE); CDC agencymaterials page public domain w/ 4 conditions; BLS copyright public domain; O*NET CC BY 4.0; ONS OGL v3; World Bank CC BY 4.0 default; Eurostat CC BY 4.0; UCDP CC BY 4.0; OWID CC BY 4.0 own data; IPUMS no redistribution, International/PMA bar commercial; MTUS restricted; DHS registration no passing on; NCHS DUA stat only no linkage; ORCID CC0 badge. 403s: OECD, DHS direct, ILOSTAT, BJS, NLSY (404), ONS-OGL page, synthea downloads (503).
Scratch: coverage mapping script in scratchpad cov.py (to be redone with new classes).
Generator input form: lifeimage/generators/params.py Param(name, default, low, high, unit, source, confidence) + mechanisms m_* in life.py (education, work, family, care, home, health, leisure, faith, civic, consumption, harm).
Decisions: licence words fetched from primary pages 2026-11-25; unverified ones marked.
Done: read CLAUDE.md, LI.17/19/54/56/57, generator shape.
Next: web-verify licences (Synthea, CDC milestones, NHANES/NCES/ACS/BLS/O*NET public domain; ONS OGL; OECD; World Bank; IPUMS; MTUS; Wikidata; DHS; NCVS), write doc, commit, push.
Resume: git pull; read this note; write lifeImage/data/events/EVENT_SOURCE_SCOUT.md
Files: lifeImage/data/events/EVENT_SOURCE_SCOUT.md, this note.
UPDATE: social-media direction + GAN outcome goal (author) received; registry written at scratchpad src.py (77+ sources); field-coverage macro mapping gives upper bound 95%; sample audit of 30 fields (seed 61): 21 direct, 8 partial, 1 none (70%/97%). Next: generate doc from src.py (script build.py in scratchpad), commit, push, mark DONE.

DONE 2026-11-26: EVENT_SOURCE_SCOUT.md written (80 sources: 68 usable, 10 costly, 2 excluded; sections 0-8 incl. social media, GAN architecture, first 3 steps, prediction judged). Source registry script lives in scratchpad only; doc is the artefact. Resume: nothing pending beyond author terms pass.
