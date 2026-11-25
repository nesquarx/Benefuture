# Public figures from Wikidata

Fetched from Wikidata (CC0 1.0, https://www.wikidata.org/wiki/Wikidata:Licensing) by `tools/gen_public.py` using `lifeimage/sources/wikidata.py`; retrieved 2026-11-24. All figures are deceased (LI.15: public figures' records may be kept). Spouses and children are not read.

Per figure: `<slug>.rows.jsonl` (contract rows, tier attested, entity `wikidata:<QID>`), `<slug>.trace.jsonl` (aligned line by line: property, label, QID, `mapped`, `fallback`, `date` stated or inferred, whether the statement carried a reference), `<slug>.json` (metadata). `fixtures/` holds the recorded, trimmed API responses: `python3 tools/gen_public.py --offline` rebuilds every file from them without the network.

Mapping to the seed domains is by label matching (`RULES` in `wikidata.py`); a label that matches no rule keeps a property-level fallback domain (`s.work`, `s.learning`, `s.public`, `s.social`) and `mapped: false`, so a later pass (or the models) can map it. A statement with no date is dated from the figure's earliest dated statement and flagged `date: inferred` (confidence x 0.85). Confidence is 0.85 for a referenced statement, 0.6 for an unreferenced one. Magnitudes are prototype values.

| figure | QID | lived | shape | rows | unmapped | inferred dates | by property |
|---|---|---|---|---|---|---|---|
| Marie Curie | Q7186 | 1867-1934 | scientist: two Nobel prizes, professorship, laboratory employer, many memberships | 45 | 16 | 23 | P106 3, P108 3, P166 17, P39 1, P463 14, P69 6, P800 1 |
| Nelson Mandela | Q8023 | 1918-2013 | statesman and lawyer: offices, activism, awards, degrees | 106 | 47 | 42 | P106 7, P166 89, P39 3, P463 2, P69 4, P800 1 |
| Frida Kahlo | Q5588 | 1907-1954 | painter: dated works; Wikidata holds few other statements (a thin record) | 3 | 0 | 1 | P106 1, P800 2 |
| Wangari Muta Maathai | Q46795 | 1940-2011 | environmental activist and politician: offices, Nobel peace prize, academic posts | 35 | 16 | 15 | P106 5, P108 1, P166 17, P39 2, P463 2, P69 6, P800 2 |
| Johann Sebastian Bach | Q1339 | 1685-1750 | composer: court and church employers, many works | 45 | 14 | 31 | P106 11, P108 6, P39 2, P69 1, P800 25 |
| Florence Nightingale | Q37103 | 1820-1910 | nurse, reformer and statistician: care, reform, memberships | 10 | 2 | 7 | P106 6, P166 3, P463 1 |
| Srinivasa Ramanujan | Q83163 | 1887-1920 | mathematician: a thin record | 35 | 25 | 27 | P106 2, P108 2, P166 2, P463 1, P69 5, P800 23 |
| Jesse Owens | Q52651 | 1913-1980 | athlete: Olympic awards, little else | 17 | 6 | 12 | P106 6, P166 7, P463 1, P69 3 |
| Toni Morrison | Q72334 | 1931-2019 | novelist and professor: dated works, awards | 61 | 28 | 18 | P106 10, P108 1, P166 32, P39 1, P463 3, P69 3, P800 11 |
| Hedy Lamarr | Q49034 | 1914-2000 | actress and inventor: two careers | 19 | 7 | 10 | P106 9, P166 4, P800 6 |

Property codes: P106 occupation, P69 educated at, P39 position held, P166 award received, P800 notable work, P108 employer, P463 member of.
