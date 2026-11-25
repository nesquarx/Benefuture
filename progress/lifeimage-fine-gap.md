Status: IN PROGRESS (resumed 2026-11-25)

## Goal and acceptance
LI.19, LI.54, LI.56, LI.57. A: ICATUS anchors out of shipped files (DONE: lifeimage/fine/calibration.py, tests/test_calibration.py,
data/calibration/ gitignored, 75 cards moved from seed_v0..v3; no code reads them, hashes unaffected: card_view excludes anchors).
B: fine candidates for the 95 empty coarse fields; data/fine/candidates_gap_v0.jsonl; batches set 'gap' (2 variants, <=50).
Prediction: >= 60 of 95 fields get a candidate; harm mostly Wikidata.

## Done
Job A. gap.py (wikidata, OBO, getty, onet, eurovoc, lcsh, bls_cex parsers), pool.new_candidates(order, target_fields),
LICENCES for all gap sources, fetched doid/mondo/onet/getty_aat. tests/test_fine_gap.py (2 red: ATTRIBUTION lines, committed candidates).

## In progress
Wikidata fetch (background, writes data/fine/sources/wikidata.jsonl; the earlier run died). Rerun other sources afterwards
(network.json race): doid mondo onet getty_aat eurovoc bls_cex nibrs(blocked, 403) lcsh.

## Next
LCSH_ROOTS for fields left uncovered; tools/fine_pool.py --gap; 'gap' in fine_build_batches choices and fine_apply SETS;
ATTRIBUTION.md; batches; full suite; commit specific paths; push; mark DONE.

## Resume
cd /home/user/Benefuture/lifeImage && python3 -m pytest -q tests/test_fine_gap.py tests/test_calibration.py
python3 tools/fine_gap_fetch.py --only wikidata
