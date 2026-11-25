Status: PAUSED 2026-11-25 (agent stopped at the usage limit; WIP committed by the lead, unreviewed)

## Goal and acceptance
LI.19, LI.54, LI.56, LI.57. A: move ICATUS anchors out of shipped files into gitignored data/calibration/icatus_anchors.jsonl;
test that no committed file under data/ carries an icatus anchor. B: fine candidates for the 95 empty coarse fields from
shippable sources (Wikidata, Getty AAT, DOID, MONDO, O*NET; plus LCSH, NIBRS, NAICS, BLS CE, R-COICOP, WordNet, EuroVoc per
LI.56), fine grain, capped per field, deduped; data/fine/candidates_gap_v0.jsonl; parent batches set 'gap' (2 variants, <=50).
Prediction: >= 60 of 95 empty fields get a candidate; harm mostly from Wikidata.

## Done (from the working tree at pause; not verified by the lead)
Fetched: data/fine/sources/{doid,getty_aat,mondo,onet}.jsonl. Code: lifeimage/fine/gap.py, tools/fine_gap_fetch.py,
tests/test_fine_gap.py; edits to fine/pool.py, fine/sources.py, data/fine/sources/network.json. Last note left: preserve key
order (no sort_keys) for card files.

## Next
Check test_fine_gap.py state (red or green); finish job A (not started as far as files show); Wikidata and LI.56 sources;
candidates_gap_v0.jsonl; batches; full suite; ATTRIBUTION.md lines.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_fine_gap.py
